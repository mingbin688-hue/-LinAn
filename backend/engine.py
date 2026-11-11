import json
import secrets
import time
from datetime import datetime
from fastapi import HTTPException
from .db import audit, dumps, notify
from .ml import MODEL_VERSION, ModelRegistry, PersonalModel, TZ, slot_at
from .scheduler import assign
from .workflow_store import enqueue

ACTIVE_STATES=('dispatched','accepted','processing')
LEVELS={0:'状态未知',1:'关注',2:'优先',3:'紧急'}
TASK_LABELS={'pending':'待确认','dispatched':'已派单','accepted':'已接单','processing':'处理中',
             'review':'待复核','closed':'已关闭'}
SKILLS={'phone':'电话核实','visit':'上门走访','device':'设备检查'}
RULE_VERSION='risk-rules-v1'


def uid(prefix):
    return prefix+'-'+secrets.token_hex(6)


def getrow(c,table,entity):
    row=c.execute(f'SELECT * FROM {table} WHERE id=?',(entity,)).fetchone()
    if row is None:
        raise HTTPException(404,'记录不存在')
    return dict(row)


class Engine:
    def __init__(self,db):
        self.db=db
        self.models=ModelRegistry()

    def worker_list(self,c):
        workers=[]
        for row in c.execute('SELECT * FROM staff ORDER BY id'):
            w=dict(row)
            active=c.execute("SELECT id FROM tasks WHERE staff_id=? AND state IN ('dispatched','accepted','processing')",(w['id'],)).fetchone()
            w['busy']=bool(active)
            w['active_task']=active[0] if active else None
            workers.append(w)
        return workers

    def evaluate(self,c,elder_id,actor='system',reason=None,at=None):
        at=at or time.time()
        elder=getrow(c,'elders',elder_id)
        s=json.loads(elder['state'])
        p=json.loads(elder['profile'])
        presence=s.get('presence','unknown') if s.get('presence_until',0)>at else 'unknown'
        pending_check=c.execute("SELECT * FROM incidents WHERE elder_id=? AND category='safety' AND status='open' AND level=1",(elder_id,)).fetchone()
        no_response=bool(pending_check and at-pending_check['created']>=600
                         and s.get('last_contact',0)<pending_check['created'])
        if not s.get('online') or at-s.get('last_seen',0)>1800:
            self.incident(c,elder_id,'data',0,'活动数据暂不可用',
                          ['数据源离线或超过30分钟未提供约定的活动窗口','信息缺失不能推断老人当前安全'],
                          '核查数据来源，并保留人工联系渠道',actor,at)
        if reason=='sos':
            self.incident(c,elder_id,'safety',3,'老人主动求助',['收到主动求助信息','主动求助直接进入紧急人工处理'],
                          '立即联系老人并提醒社区负责人启动人工紧急处置',actor,at)
        elif reason=='need_help' or s.get('unreachable') or no_response:
            self.incident(c,elder_id,'safety',2,'需要优先联系核实',
                          ['核实请求已超过10分钟未获回应（演示规则）' if no_response else '人工报告需要帮助或核实未获回应']+s.get('evidence',[]),
                          '优先电话联系，必要时安排上门走访',actor,at)
        elif presence not in ('away','rest'):
            due=datetime.fromtimestamp(at,TZ).replace(hour=p.get('checkin_hour',9),minute=0,second=0,microsecond=0).timestamp()
            missed=s.get('last_checkin',0)<due and at>due+3600
            if reason=='missed_checkin' or missed:
                self.incident(c,elder_id,'safety',1,'未按约定报平安',
                              ['今日约定的报平安尚未收到','尚未取得外出或休息确认'],
                              '请求老人确认状态，并通知关联家属协助核实',actor,at)
            elif s.get('online') and at-s.get('last_seen',0)<=1800 and s.get('anomaly'):
                self.incident(c,elder_id,'safety',1,'活动规律出现偏离',s.get('evidence',[]),
                              '先核实当前状态；持续异常且未回应时升级处理',actor,at)

    def incident(self,c,elder_id,category,level,title,evidence,advice,actor,at):
        old=c.execute("SELECT * FROM incidents WHERE elder_id=? AND category=? AND status='open'",(elder_id,category)).fetchone()
        elder=getrow(c,'elders',elder_id)
        snapshot={'level':level,'evidence':evidence,'rule_version':RULE_VERSION,'model_version':MODEL_VERSION,
                  'input_snapshot':{'elder_id':elder_id,'profile':json.loads(elder['profile']),
                                    'state':json.loads(elder['state']),'assessed_at':at}}
        if old:
            old=dict(old)
            if level < old['level']:
                return  # Confirmed evidence cannot silently downgrade an open emergency.
            if old['evidence']==dumps(evidence) and old['level']==level and old['title']==title:
                return
            c.execute('UPDATE incidents SET level=?,title=?,evidence=?,advice=?,updated=? WHERE id=?',
                      (level,title,dumps(evidence),advice,at,old['id']))
            if level>old['level']:
                c.execute("UPDATE tasks SET level=?,required_skill=?,due=MIN(due,?),updated=?,version=version+1,overdue=0 WHERE incident_id=? AND state!='closed'",
                          (level,'visit' if level>=2 else 'phone',at+{1:1800,2:600,3:120}[level],at,old['id']))
                # Existing assignee must remain qualified after escalation.
                task=c.execute('SELECT * FROM tasks WHERE incident_id=?',(old['id'],)).fetchone()
                if task['staff_id']:
                    worker=getrow(c,'staff',task['staff_id'])
                    if task['required_skill'] not in json.loads(worker['skills']):
                        c.execute("UPDATE tasks SET state='pending',staff_id=NULL,version=version+1 WHERE id=?",(task['id'],))
                notify(c,'风险等级已升级',f'事件 {old["id"]} 已升级为{LEVELS[level]}',elder_id=elder_id)
            audit(c,actor,'risk_updated',old['id'],snapshot)
            task=c.execute('SELECT id FROM tasks WHERE incident_id=?',(old['id'],)).fetchone()
            enqueue(c,'risk',task['id'],f'risk:{old["id"]}:{at}')
            return old['id']
        iid,tid=uid('EV'),uid('TK')
        c.execute('INSERT INTO incidents VALUES(?,?,?,?,?,?,?,?,?,?,?)',
                  (iid,elder_id,category,level,title,dumps(evidence),advice,'open',at,at,MODEL_VERSION))
        c.execute('INSERT INTO tasks VALUES(?,?,?,?,?,?,?,?,?,?,0,1)',
                  (tid,iid,elder_id,level,'pending','device' if category=='data' else 'visit' if level>=2 else 'phone',
                   None,at,at,at+{0:600,1:1800,2:600,3:120}[level]))
        audit(c,actor,'risk_created',iid,snapshot)
        enqueue(c,'risk',tid,f'risk:{iid}:{at}')
        notify(c,f'{LEVELS[level]} · {title}',advice,elder_id=elder_id)
        notify(c,'有一条状态需要核实',title,role='family',elder_id=elder_id)
        notify(c,'请确认当前状态',advice,role='elder',elder_id=elder_id)
        return iid

    def ingest(self,c,actor,event):
        elder=getrow(c,'elders',event['elder_id'])
        existing=c.execute('SELECT elder_id FROM events WHERE id=?',(event['id'],)).fetchone()
        if existing:
            if existing[0]!=event['elder_id']:
                raise HTTPException(409,'事件编号已被其他记录使用')
            return {'duplicate':True,'id':event['id']}
        now=time.time()
        at=event.get('observed_at') or now
        payload=event.get('payload',{})
        kind=event['kind']
        c.execute('INSERT INTO events VALUES(?,?,?,?,?,?,?,?)',
                  (event['id'],elder['id'],kind,at,now,actor,event.get('source','人工上报'),dumps(payload)))
        s=json.loads(elder['state'])
        p=json.loads(elder['profile'])
        # Historical events remain auditable but cannot overwrite newer current state.
        if at < s.get('observed_at',0):
            audit(c,actor,'historical_event',event['id'],{'kind':kind,'observed_at':at})
            return {'duplicate':False,'historical':True,'id':event['id']}
        s['observed_at']=at
        if kind=='activity':
            s['model_timestamp']=payload.get('original_timestamp',at)
            s.update(count15=payload['count15'],count60=payload['count60'],gap=payload['gap'],online=True,last_seen=at)
            if p.get('origin') in ('manual-demo','accumulated-activity-windows'):
                # Do not invent a synthetic mature baseline for newly added residents.
                history=[]
                for record in c.execute("SELECT observed_at,payload FROM events WHERE elder_id=? AND kind='activity' AND observed_at<? ORDER BY observed_at DESC LIMIT 6000",(elder['id'],at)):
                    values=json.loads(record['payload'])
                    if all(k in values for k in ('count15','count60','gap')):
                        history.append({'timestamp':record['observed_at'],'slot':slot_at(record['observed_at']),
                                        **{k:values[k] for k in ('count15','count60','gap')}})
                history.sort(key=lambda r:r['timestamp'])
                days={datetime.fromtimestamp(r['timestamp'],TZ).date() for r in history}
                p['history_days']=len(days)
                p['baseline_ready']=len(days)>=14 and len(history)>=14*48
                if len(days)>=14 and len(history)>=14*48:
                    p['origin']='accumulated-activity-windows'
                    key=(elder['id'],p.get('activity_scale',1),p['origin'])
                    if key not in self.models.models:
                        cut=int(len(history)*.8)
                        self.models.models[key]=PersonalModel(history[:cut],history[cut:])
                c.execute('UPDATE elders SET profile=? WHERE id=?',(dumps(p),elder['id']))
            pred=self.models.evaluate(elder['id'],p,s,at)
            s.update(pred)
            s['anomaly_streak']=s.get('anomaly_streak',0)+1 if pred['anomaly'] else 0
            s['source']=event.get('source','活动窗口')
        elif kind=='safe':
            s.update(last_checkin=at,last_contact=at,unreachable=False)
        elif kind in ('away','rest','home'):
            s.update(presence=kind,presence_until=at+payload.get('hours',4)*3600,last_contact=at,unreachable=False)
        elif kind=='unreachable':
            s['unreachable']=True
        elif kind=='data_offline':
            s['online']=False
        elif kind=='data_online':
            s.update(online=True,last_seen=at)
        elif kind=='missed_checkin':
            s['last_checkin']=at-86400
        c.execute('UPDATE elders SET state=?,version=version+1 WHERE id=?',(dumps(s),elder['id']))
        audit(c,actor,'event_received',event['id'],{'kind':kind,'source':event.get('source'),'payload':payload,'observed_at':at})
        if kind=='contact':
            self.incident(c,elder['id'],'safety',1,'老人请求联系',['收到老人请求联系的上报'],'安排电话联系，了解具体需求',actor,now)
        self.evaluate(c,elder['id'],actor,kind,now)
        return {'duplicate':False,'id':event['id']}

    def tick(self,at=None):
        at=at or time.time()
        with self.db.transaction(True) as c:
            for elder in c.execute('SELECT id FROM elders').fetchall():
                self.evaluate(c,elder['id'],at=at)
            rows=c.execute("SELECT * FROM tasks WHERE state!='closed' AND overdue=0 AND due<?",(at,)).fetchall()
            for t in rows:
                c.execute('UPDATE tasks SET overdue=1 WHERE id=?',(t['id'],))
                notify(c,'任务已超时，请跟进',f'{t["id"]} 当前状态：{TASK_LABELS[t["state"]]}',elder_id=t['elder_id'])
                audit(c,'system','task_overdue',t['id'],{'state':t['state'],'due':t['due']})

    def recommendations(self,c,actor):
        tasks=[dict(r) for r in c.execute("SELECT * FROM tasks WHERE state='pending'")]
        workers=self.worker_list(c)
        matched=assign(tasks,workers)
        tasks_by={t['id']:t for t in tasks}
        workers_by={w['id']:w for w in workers}
        for m in matched:
            recid=uid('REC')
            task,worker=tasks_by[m['task_id']],workers_by[m['staff_id']]
            snapshot={'task':task,'staff':worker,'reason':m['reason'],'travel_origin':'synthetic-fixed-matrix'}
            c.execute('INSERT INTO recommendations VALUES(?,?,?,?,?,?,?,?)',
                      (recid,task['id'],worker['id'],task['version'],worker['version'],time.time(),m['eta'],dumps(snapshot)))
            m.update(id=recid,staff_name=worker['name'],task_version=task['version'],level=task['level'])
        audit(c,actor,'dispatch_recommended','batch',{'recommendations':matched,'rule_version':'lexicographic-match-v1'})
        return {'recommendations':matched,'unassigned':[t['id'] for t in tasks if t['id'] not in {m['task_id'] for m in matched}],
                'note':'未推荐任务保留待确认；预计到达时间来自仿真矩阵'}

    def confirm(self,c,actor,rec_id,staff_id=None,reason=''):
        rec=getrow(c,'recommendations',rec_id)
        if time.time()-rec['created']>300:
            raise HTTPException(409,'推荐已超过5分钟，请重新计算')
        task=getrow(c,'tasks',rec['task_id'])
        if task['state']!='pending' or task['version']!=rec['task_version']:
            raise HTTPException(409,'任务已变化，请重新获取推荐')
        chosen=staff_id or rec['staff_id']
        worker=getrow(c,'staff',chosen)
        if chosen!=rec['staff_id'] and len(reason.strip())<2:
            raise HTTPException(422,'调整人员时请填写原因')
        if chosen==rec['staff_id'] and worker['version']!=rec['staff_version']:
            raise HTTPException(409,'人员状态已变化，请重新获取推荐')
        busy=c.execute("SELECT 1 FROM tasks WHERE staff_id=? AND state IN ('dispatched','accepted','processing')",(chosen,)).fetchone()
        if not worker['on_duty'] or not worker['available'] or busy:
            raise HTTPException(409,'人员当前不在岗、不可用或已有执行任务')
        if task['required_skill'] not in json.loads(worker['skills']):
            raise HTTPException(409,'人员不具备任务所需技能')
        c.execute("UPDATE tasks SET state='dispatched',staff_id=?,updated=?,version=version+1 WHERE id=?",(chosen,time.time(),task['id']))
        audit(c,actor,'dispatch_confirmed',task['id'],{'recommendation':json.loads(rec['snapshot']),
                  'chosen_staff':chosen,'adjustment_reason':reason,'rule_version':RULE_VERSION})
        notify(c,'收到新的守护任务',task['id'],role='staff',staff_id=chosen,elder_id=task['elder_id'])
        return {'id':task['id'],'state':'dispatched'}

    def action(self,c,user,task_id,action,outcome='',note=''):
        task=getrow(c,'tasks',task_id)
        if user['role']=='staff' and task['staff_id']!=user['staff_id']:
            raise HTTPException(403,'仅任务负责人可操作')
        current=task['state']
        state=None
        if action=='accept' and current=='dispatched':
            state='accepted'
        elif action=='start' and current=='accepted':
            state='processing'
        elif action=='reject' and current in ('dispatched','accepted'):
            if len(note.strip())<2:
                raise HTTPException(422,'请填写拒单原因')
            state='pending'
        elif action=='feedback' and current in ('accepted','processing'):
            if outcome not in ('safe','needs_help','unreachable','data_issue') or len(note.strip())<2:
                raise HTTPException(422,'请选择处置结果并填写说明')
            state='review'
            c.execute('INSERT INTO feedback VALUES(?,?,?,?,?,?)',(uid('FB'),task_id,user['username'],outcome,note,time.time()))
            notify(c,'处置结果待复核',task_id,elder_id=task['elder_id'])
        elif action=='followup' and current=='review' and user['role']=='admin':
            state='pending'
        elif action=='close' and user['role']=='admin' and current!='closed':
            if current=='review':
                last=c.execute('SELECT * FROM feedback WHERE task_id=? ORDER BY created DESC LIMIT 1',(task_id,)).fetchone()
                if not last or last['outcome'] not in ('safe','data_issue'):
                    raise HTTPException(409,'尚未解决的任务需继续跟进，不能关闭')
            elif outcome not in ('safe','data_issue') or len(note.strip())<2:
                raise HTTPException(422,'直接核实关闭时需提交已确认安全或数据问题的结果及说明')
            else:
                c.execute('INSERT INTO feedback VALUES(?,?,?,?,?,?)',(uid('FB'),task_id,user['username'],outcome,note,time.time()))
            state='closed'
            c.execute("UPDATE incidents SET status='closed',updated=? WHERE id=?",(time.time(),task['incident_id']))
            elder=getrow(c,'elders',task['elder_id'])
            s=json.loads(elder['state'])
            # Resolve the underlying signal only after an explicit verification.
            if task['required_skill']=='device':
                s.update(online=True,last_seen=time.time())
            else:
                s.update(last_checkin=time.time(),last_contact=time.time(),unreachable=False,anomaly=False,anomaly_streak=0)
            c.execute('UPDATE elders SET state=?,version=version+1 WHERE id=?',(dumps(s),elder['id']))
        else:
            raise HTTPException(409,'当前状态不允许该操作')
        release=action in ('reject','followup')
        if release:
            c.execute('INSERT OR IGNORE INTO workflow_exclusions VALUES(?,?,?)',(task_id,action,time.time()))
        c.execute('UPDATE tasks SET state=?,staff_id=?,updated=?,version=version+1,due=?,overdue=0 WHERE id=?',
                  (state,None if release else task['staff_id'],time.time(),time.time()+{0:600,1:1800,2:600,3:120}[task['level']],task_id))
        audit(c,user['username'],f'task_{action}',task_id,{'before':current,'after':state,'outcome':outcome,'note':note})
        if action=='feedback':
            enqueue(c,'review',task_id,f'review:{task_id}:{task["version"]+1}')
        return {'id':task_id,'state':state}
