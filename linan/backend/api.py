import asyncio
import contextlib
import hashlib
import json
import logging
import os
from pathlib import Path
import secrets
import time
from typing import Literal
from contextlib import asynccontextmanager
from fastapi import FastAPI, Depends, Header, HTTPException
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field, field_validator
from .db import Database, audit, dumps, password_valid
from .engine import Engine, getrow, uid
from .agents import Assistant, ModelProvider, CATALOG, visible_ids as allowed_elder_ids
from .workflows import Workflows
from .workflow_store import run_detail

ROOT=Path(__file__).resolve().parents[1]
KINDS=Literal['activity','safe','contact','sos','away','home','rest','need_help','unreachable','data_offline','data_online','missed_checkin']


class Login(BaseModel):
    username: str = Field(min_length=1,max_length=50)
    password: str = Field(min_length=1,max_length=200)


class Event(BaseModel):
    id: str = Field(default_factory=lambda:uid('IN'),min_length=1,max_length=100)
    elder_id: int = Field(ge=1)
    kind: KINDS
    observed_at: float | None = None
    source: str = Field(default='人工上报',max_length=80)
    payload: dict = Field(default_factory=dict)

    @field_validator('observed_at')
    @classmethod
    def timestamp_valid(cls,value):
        if value is not None and (not (0<value<=time.time()+30)):
            raise ValueError('时间戳必须有效，且不能晚于当前时间30秒')
        return value

    @field_validator('payload')
    @classmethod
    def bounded_payload(cls,value):
        if len(dumps(value))>4000:
            raise ValueError('上报内容过长')
        for key in ('count15','count60','gap','original_timestamp'):
            if key in value and (not isinstance(value[key],(float,int)) or not 0<=value[key]<=(time.time()+30 if key=='original_timestamp' else 100000)):
                raise ValueError('活动数值必须为有限非负数')
        if 'hours' in value and (not isinstance(value['hours'],(int,float)) or not 0<value['hours']<=24):
            raise ValueError('状态确认有效期为0到24小时')
        return value


class Confirmation(BaseModel):
    recommendation_id: str
    staff_id: int | None = None
    reason: str = Field(default='',max_length=1000)


class Action(BaseModel):
    action: Literal['accept','start','reject','feedback','followup','close']
    outcome: str = ''
    note: str = Field(default='',max_length=2000)


class WorkerUpdate(BaseModel):
    available: bool
    on_duty: bool
    location: int = Field(ge=1,le=5)


class ElderProfile(BaseModel):
    name: str = Field(min_length=1,max_length=40)
    age: int = Field(ge=60,le=120)
    building: str = Field(min_length=1,max_length=80)
    contact: str = Field(min_length=1,max_length=80)
    routine: str = Field(default='07:00 起床，22:00 休息',max_length=300)
    checkin_hour: int = Field(default=9,ge=0,le=23)


class Scenario(BaseModel):
    scenario: Literal['story','offline','away','normal','cold_start','conflict']
    elder_id: int = Field(default=1,ge=1)


class ReplayWindow(BaseModel):
    elder_id: int = Field(ge=1)
    offset: int = Field(default=0,ge=0)


class AssistantMessage(BaseModel):
    message: str = Field(min_length=1,max_length=2000)
    session_id: str | None = Field(default=None,max_length=100)
    elder_id: int | None = Field(default=None,ge=1)
    task_id: str | None = Field(default=None,max_length=100)

    @field_validator('message')
    @classmethod
    def nonempty(cls,value):
        if not value.strip():
            raise ValueError('请输入查询内容')
        return value.strip()


class WorkflowSettings(BaseModel):
    auto_dispatch: bool


def create_app(db_path=None, demo=True, background=True):
    db=Database(db_path or os.getenv('LINAN_DB',str(ROOT/'runtime'/'linan.sqlite3')))
    db.initialize()
    fresh=db.seed()
    engine=Engine(db)
    provider=ModelProvider()
    workflows=Workflows(db,engine,provider)
    assistant=Assistant(db,engine,provider)

    async def monitor():
        while True:
            try:
                await asyncio.to_thread(engine.tick)
                await asyncio.to_thread(workflows.process)
            except Exception:
                logging.exception('守护状态巡检失败')
            await asyncio.sleep(5)

    async def agent_worker():
        while True:
            try:
                await asyncio.to_thread(workflows.drain)
            except Exception:
                logging.exception('Agent 后台生成失败；任务租约到期后恢复')
            await asyncio.sleep(1)

    @asynccontextmanager
    async def lifespan(app):
        task=asyncio.create_task(monitor()) if background else None
        worker=asyncio.create_task(agent_worker()) if background else None
        yield
        for running in (task,worker):
            if running:
                running.cancel()
                with contextlib.suppress(asyncio.CancelledError):
                    await running
        provider.client.close()

    app=FastAPI(title='邻安 · 社区协同守护',version='1.0.0',lifespan=lifespan)
    app.state.db=db
    app.state.engine=engine
    app.state.provider=provider
    app.state.workflows=workflows
    app.state.assistant=assistant
    login_failures={}
    replay_cache={}

    def user(authorization:str|None=Header(default=None)):
        if not authorization or not authorization.startswith('Bearer '):
            raise HTTPException(401,'请先登录')
        digest=hashlib.sha256(authorization[7:].encode()).hexdigest()
        with db.transaction() as c:
            row=c.execute('SELECT u.* FROM users u JOIN sessions s ON u.username=s.username WHERE s.token=? AND s.expires>?',
                          (digest,time.time())).fetchone()
            if not row:
                raise HTTPException(401,'登录已过期，请重新登录')
            return {k:v for k,v in dict(row).items() if k!='password'}

    def admin(u=Depends(user)):
        if u['role']!='admin':
            raise HTTPException(403,'该操作需要社区管理员权限')
        return u

    def operator(u=Depends(user)):
        if u['role'] not in ('admin','staff'):
            raise HTTPException(403,'该操作需要社区工作人员权限')
        return u

    def visible_ids(c,u):
        return allowed_elder_ids(c,u)

    def scope(c,u,eid):
        if eid not in visible_ids(c,u):
            raise HTTPException(403,'无权访问该老人记录')

    def decorated_elder(c,row):
        e=dict(row)
        e['profile']=json.loads(e['profile'])
        e['state']=json.loads(e['state'])
        incidents=[dict(r) for r in c.execute("SELECT * FROM incidents WHERE elder_id=? AND status='open' ORDER BY level DESC",(e['id'],))]
        e['level']=max((i['level'] for i in incidents),default=-1)
        e['data_unknown']=any(i['category']=='data' for i in incidents)
        e['incident_count']=len(incidents)
        e['latest_incident']=incidents[0]['id'] if incidents else None
        return e

    def decorated_task(c,row):
        t=dict(row)
        t['elder_name']=getrow(c,'elders',t['elder_id'])['name']
        i=getrow(c,'incidents',t['incident_id'])
        t.update(title=i['title'],category=i['category'],evidence=json.loads(i['evidence']),advice=i['advice'])
        t['staff_name']=getrow(c,'staff',t['staff_id'])['name'] if t['staff_id'] else None
        return t

    @app.get('/api/health')
    def health():
        return {'status':'ok','app':'linan-community-guard','version':'1.0.0','data_origin':'synthetic demo + optional CASAS import'}

    @app.post('/api/auth/login')
    def login(body:Login):
        recent=[t for t in login_failures.get(body.username,[]) if time.time()-t<60]
        if len(recent)>=10:
            raise HTTPException(429,'尝试次数较多，请稍后重试')
        with db.transaction(True) as c:
            row=c.execute('SELECT * FROM users WHERE username=?',(body.username,)).fetchone()
            if not row or not password_valid(body.password,row['password']):
                login_failures[body.username]=recent+[time.time()]
                raise HTTPException(401,'账号或密码不正确')
            token=secrets.token_urlsafe(40)
            c.execute('DELETE FROM sessions WHERE expires<?',(time.time(),))
            c.execute('INSERT INTO sessions VALUES(?,?,?)',(hashlib.sha256(token.encode()).hexdigest(),body.username,time.time()+28800))
            return {'token':token,'user':{k:v for k,v in dict(row).items() if k!='password'}}

    @app.post('/api/auth/logout')
    def logout(u=Depends(user),authorization:str=Header()):
        with db.transaction(True) as c:
            c.execute('DELETE FROM sessions WHERE token=?',(hashlib.sha256(authorization[7:].encode()).hexdigest(),))
        return {'ok':True}

    @app.get('/api/me')
    def me(u=Depends(user)):
        return u

    @app.get('/api/elders')
    def elders(u=Depends(user)):
        with db.transaction() as c:
            ids=visible_ids(c,u)
            return [decorated_elder(c,r) for r in c.execute('SELECT * FROM elders ORDER BY id') if r['id'] in ids]

    @app.get('/api/elders/{eid}')
    def elder_detail(eid:int,u=Depends(user)):
        with db.transaction() as c:
            scope(c,u,eid)
            e=decorated_elder(c,getrow(c,'elders',eid))
            e['events']=[dict(r) for r in c.execute('SELECT * FROM events WHERE elder_id=? ORDER BY received_at DESC LIMIT 80',(eid,))]
            for event in e['events']:
                event['payload']=json.loads(event['payload'])
            return e

    @app.post('/api/elders')
    def add_elder(body:ElderProfile,u=Depends(admin)):
        now=time.time()
        with db.transaction(True) as c:
            profile={'routine':body.routine,'checkin_hour':body.checkin_hour,'history_days':0,'activity_scale':1,
                     'origin':'manual-demo','note':'新档案尚无活动历史'}
            state={'online':False,'last_seen':0,'last_checkin':now,'observed_at':0,'presence':'unknown',
                   'count15':0,'count60':0,'gap':0,'score':0,'anomaly':False,'evidence':[],'source':'尚未接入数据'}
            cur=c.execute('INSERT INTO elders(name,age,building,contact,profile,state) VALUES(?,?,?,?,?,?)',
                          (body.name,body.age,body.building,body.contact,dumps(profile),dumps(state)))
            engine.evaluate(c,cur.lastrowid,u['username'])
            audit(c,u['username'],'elder_created',str(cur.lastrowid),body.model_dump())
            eid=cur.lastrowid
        workflows.process()
        return {'id':eid}

    @app.put('/api/elders/{eid}')
    def edit_elder(eid:int,body:ElderProfile,u=Depends(admin)):
        with db.transaction(True) as c:
            row=getrow(c,'elders',eid)
            p=json.loads(row['profile'])
            p.update(routine=body.routine,checkin_hour=body.checkin_hour)
            c.execute('UPDATE elders SET name=?,age=?,building=?,contact=?,profile=?,version=version+1 WHERE id=?',
                      (body.name,body.age,body.building,body.contact,dumps(p),eid))
            audit(c,u['username'],'elder_updated',str(eid),body.model_dump())
        return {'ok':True}

    @app.post('/api/events')
    def event(body:Event,u=Depends(user)):
        with db.transaction(True) as c:
            scope(c,u,body.elder_id)
            if u['role'] in ('elder','family') and body.kind not in ('safe','contact','sos','away','home','rest'):
                raise HTTPException(403,'当前角色不能提交此类型事件')
            if body.kind=='activity' and any(k not in body.payload for k in ('count15','count60','gap')):
                raise HTTPException(422,'活动窗口需包含count15、count60、gap')
            if body.kind=='activity' and body.payload['count60']<body.payload['count15']:
                raise HTTPException(422,'60分钟活动数不能小于15分钟活动数')
            result=engine.ingest(c,u['username'],body.model_dump())
        workflows.process()
        return result

    @app.get('/api/incidents')
    def incidents(u=Depends(user)):
        with db.transaction() as c:
            ids=visible_ids(c,u)
            results=[]
            for row in c.execute('SELECT * FROM incidents ORDER BY status DESC,level DESC,created'):
                if row['elder_id'] in ids:
                    i=dict(row)
                    i['evidence']=json.loads(i['evidence'])
                    i['elder_name']=getrow(c,'elders',i['elder_id'])['name']
                    results.append(i)
            return results

    @app.get('/api/tasks')
    def tasks(u=Depends(operator)):
        with db.transaction() as c:
            return [decorated_task(c,r) for r in c.execute('SELECT * FROM tasks ORDER BY level DESC,created')
                    if u['role']=='admin' or r['staff_id']==u['staff_id']]

    @app.get('/api/tasks/{tid}')
    def task_detail(tid:str,u=Depends(operator)):
        with db.transaction() as c:
            t=getrow(c,'tasks',tid)
            if u['role']=='staff' and t['staff_id']!=u['staff_id']:
                raise HTTPException(403,'无权访问此任务')
            result=decorated_task(c,t)
            result['feedback']=[dict(r) for r in c.execute('SELECT * FROM feedback WHERE task_id=? ORDER BY created',(tid,))]
            entities=(tid,t['incident_id'])
            result['audit']=[dict(r) for r in c.execute('SELECT * FROM audit WHERE entity_id IN (?,?) ORDER BY created',entities)]
            for r in result['audit']:
                r['payload']=json.loads(r['payload'])
            result['agent_runs']=workflows.task_runs(c,tid)
            return result

    @app.post('/api/dispatch/recommend')
    def recommend(u=Depends(admin)):
        with db.transaction(True) as c:
            return engine.recommendations(c,u['username'])

    @app.post('/api/dispatch/confirm')
    def confirm(body:Confirmation,u=Depends(admin)):
        with db.transaction(True) as c:
            result=engine.confirm(c,u['username'],body.recommendation_id,body.staff_id,body.reason)
        workflows.process()
        return result

    @app.post('/api/tasks/{tid}/action')
    def task_action(tid:str,body:Action,u=Depends(operator)):
        with db.transaction(True) as c:
            if body.action in ('followup','close') and u['role']!='admin':
                raise HTTPException(403,'复核操作需要管理员权限')
            result=engine.action(c,u,tid,body.action,body.outcome,body.note)
        workflows.process()
        return result

    @app.get('/api/staff')
    def staff(u=Depends(operator)):
        with db.transaction() as c:
            rows=engine.worker_list(c)
            for w in rows:
                w['skills']=json.loads(w['skills'])
            return rows if u['role']=='admin' else [w for w in rows if w['id']==u['staff_id']]

    @app.put('/api/staff/{sid}')
    def staff_update(sid:int,body:WorkerUpdate,u=Depends(operator)):
        if u['role']=='staff' and sid!=u['staff_id']:
            raise HTTPException(403,'只能更新自己的人员状态')
        with db.transaction(True) as c:
            getrow(c,'staff',sid)
            c.execute('UPDATE staff SET available=?,on_duty=?,location=?,version=version+1 WHERE id=?',
                      (int(body.available),int(body.on_duty),body.location,sid))
            audit(c,u['username'],'staff_updated',str(sid),body.model_dump())
        workflows.process()
        return {'ok':True}

    @app.get('/api/notifications')
    def notifications(u=Depends(user)):
        with db.transaction() as c:
            return [dict(r) for r in c.execute('SELECT * FROM notifications ORDER BY created DESC LIMIT 300')
                    if r['role']==u['role'] and (u['role']=='admin' or
                       u['role']=='staff' and r['staff_id']==u['staff_id'] or
                       u['role'] in ('family','elder') and r['elder_id']==u['elder_id'])][:30]

    @app.post('/api/demo/scenario')
    def scenario(body:Scenario,u=Depends(admin)):
        kinds={'story':[(1,'missed_checkin',{}),(2,'activity',{'count15':0,'count60':0,'gap':180}),(3,'sos',{})],
               'offline':[(body.elder_id,'data_offline',{})], 'away':[(body.elder_id,'away',{'hours':4})],
               'normal':[(body.elder_id,'safe',{})], 'conflict':[(4,'sos',{}),(5,'need_help',{}),(6,'sos',{})],
               'cold_start':[(body.elder_id,'activity',{'count15':0,'count60':0,'gap':60})]}
        with db.transaction(True) as c:
            if body.scenario=='cold_start':
                elder=getrow(c,'elders',body.elder_id)
                p=json.loads(elder['profile']);p['history_days']=3
                c.execute('UPDATE elders SET profile=? WHERE id=?',(dumps(p),body.elder_id))
            results=[engine.ingest(c,u['username'],{'id':uid('SIM'),'elder_id':eid,'kind':kind,'payload':payload,
                     'observed_at':time.time(),'source':'合成情景回放'}) for eid,kind,payload in kinds[body.scenario]]
            audit(c,u['username'],'scenario_played',body.scenario,{'origin':'synthetic','events':results})
        workflows.process()
        return {'events':results,'origin':'synthetic'}

    @app.post('/api/experiments/run')
    def run_experiment(u=Depends(admin)):
        from .experiments import run_all
        result=run_all()
        with db.transaction(True) as c:
            eid=uid('EXP')
            c.execute('INSERT INTO experiments VALUES(?,?,?,?)',(eid,'synthetic',dumps(result),time.time()))
            audit(c,u['username'],'experiment_run',eid,{'origin':'synthetic','seed':42})
        return result

    @app.post('/api/replay/window')
    def replay_window(body:ReplayWindow,u=Depends(admin)):
        import csv
        from .ml import PersonalModel
        if 'rows' not in replay_cache:
            datafile=ROOT/'data'/'aruba_windows.csv'
            if not datafile.exists():
                raise HTTPException(409,'尚未准备公开数据，请先运行 scripts/data_pipeline.py')
            with datafile.open(encoding='utf-8') as f:
                rows=[{k:(int(float(v)) if k in ('slot','count15','count60') else float(v)) for k,v in r.items()} for r in csv.DictReader(f)]
            days=len(rows)//96;a=int(days*.6)*96;b=int(days*.8)*96
            replay_cache.update(rows=rows[b:],train_days=a//96,model=PersonalModel(rows[:a],rows[a:b]))
        rows=replay_cache['rows']
        if body.offset>=len(rows):
            raise HTTPException(422,f'窗口偏移超出测试段，允许0至{len(rows)-1}')
        row=rows[body.offset]
        with db.transaction(True) as c:
            elder=getrow(c,'elders',body.elder_id)
            profile=json.loads(elder['profile']);profile.update(origin='CASAS Aruba replay',history_days=replay_cache['train_days'],baseline_ready=True)
            c.execute('UPDATE elders SET profile=? WHERE id=?',(dumps(profile),body.elder_id))
            key=(body.elder_id,profile.get('activity_scale',1),profile['origin'])
            engine.models.models[key]=replay_cache['model']
            result=engine.ingest(c,u['username'],{'id':f'CASAS-{body.elder_id}-{int(row["timestamp"])}',
                   'elder_id':body.elder_id,'kind':'activity','observed_at':time.time(),'source':'CASAS Aruba 公开数据窗口回放',
                   'payload':{'count15':row['count15'],'count60':row['count60'],'gap':row['gap'],'original_timestamp':row['timestamp']}})
        workflows.process()
        return {**result,'offset':body.offset,'total':len(rows),'original_timestamp':row['timestamp'],
                'count15':row['count15'],'gap':row['gap'],'origin':'CASAS replay in virtual profile'}

    @app.get('/api/experiments')
    def experiments(u=Depends(admin)):
        with db.transaction() as c:
            row=c.execute('SELECT * FROM experiments ORDER BY created DESC LIMIT 1').fetchone()
            return json.loads(row['result']) if row else None

    @app.get('/api/feedback/export')
    def export_feedback(u=Depends(admin)):
        with db.transaction() as c:
            return {'purpose':'已复核反馈供离线分析；不直接修改在线模型',
                    'items':[dict(r) for r in c.execute("SELECT f.*,t.elder_id FROM feedback f JOIN tasks t ON t.id=f.task_id WHERE t.state='closed' ORDER BY f.created")]}

    @app.get('/api/agents')
    def agents(u=Depends(user)):
        return {'agents':CATALOG,'mode':'llm' if provider.enabled else 'rules',
                'configured':provider.configured,'fallback_reason':provider.configuration_reason}

    @app.post('/api/assistant/messages')
    def assistant_message(body:AssistantMessage,u=Depends(user)):
        return assistant.message(u,**body.model_dump())

    @app.get('/api/assistant/sessions/{sid}')
    def assistant_session(sid:str,u=Depends(user)):
        with db.transaction() as c:
            return assistant.session(c,u,sid)

    @app.get('/api/workflows/settings')
    def workflow_settings(u=Depends(admin)):
        with db.transaction() as c:
            return workflows.settings(c)

    @app.put('/api/workflows/settings')
    def update_workflow_settings(body:WorkflowSettings,u=Depends(admin)):
        with db.transaction(True) as c:
            c.execute("UPDATE settings SET value=? WHERE key='auto_dispatch'",('true' if body.auto_dispatch else 'false',))
            audit(c,u['username'],'workflow_settings_changed','auto_dispatch',body.model_dump())
        workflows.process()
        return body.model_dump()

    @app.get('/api/workflows/runs')
    def workflow_runs(u=Depends(admin)):
        with db.transaction() as c:
            return [dict(r) for r in c.execute("SELECT id,kind,elder_id,task_id,status,mode,summary,created,updated FROM workflow_runs WHERE kind!='chat' OR owner=? ORDER BY created DESC LIMIT 200",(u['username'],))]

    @app.get('/api/workflows/runs/{rid}')
    def workflow_run(rid:str,u=Depends(admin)):
        with db.transaction() as c:
            owner=c.execute('SELECT kind,owner FROM workflow_runs WHERE id=?',(rid,)).fetchone()
            if owner and owner['kind']=='chat' and owner['owner']!=u['username']:
                raise HTTPException(403,'无权访问其他人的对话运行记录')
            value=run_detail(c,rid)
            if value is None:
                raise HTTPException(404,'工作流记录不存在')
            return value

    dist=ROOT/'frontend'/'dist'
    app.mount('/assets',StaticFiles(directory=dist/'assets',check_dir=False),name='assets')

    @app.get('/')
    def index():
        if not (dist/'index.html').exists():
            raise HTTPException(503,'请先构建前端：cd frontend && pnpm install && pnpm build')
        return FileResponse(dist/'index.html')

    if fresh and demo:
        with db.transaction(True) as c:
            for eid,kind in [(1,'missed_checkin'),(2,'activity'),(3,'sos')]:
                engine.ingest(c,'system',{'id':uid('SEED'),'elder_id':eid,'kind':kind,'observed_at':time.time(),
                                         'source':'合成演示数据','payload':{'count15':0,'count60':0,'gap':180} if kind=='activity' else {}})
    workflows.process()
    return app
