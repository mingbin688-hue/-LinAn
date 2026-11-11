import concurrent.futures
import json
import time
import pytest
from fastapi.testclient import TestClient
from backend.api import create_app
from backend.db import dumps
from backend.ml import ModelRegistry, PersonalModel, synthetic_windows
from backend.scheduler import assign


@pytest.fixture
def env(tmp_path):
    app=create_app(tmp_path/'test.sqlite3',demo=False,background=False)
    client=TestClient(app)
    def headers(name='admin'):
        result=client.post('/api/auth/login',json={'username':name,'password':'Demo2026!'})
        assert result.status_code==200
        return {'Authorization':'Bearer '+result.json()['token']}
    return app,client,headers


def event(client,h,eid=1,kind='sos',**extra):
    result=client.post('/api/events',headers=h,json={'elder_id':eid,'kind':kind,**extra})
    assert result.status_code==200,result.text
    return result.json()


def recs(c,h):
    r=c.post('/api/dispatch/recommend',headers=h)
    assert r.status_code==200,r.text
    return r.json()['recommendations']


def test_authentication_and_scoping(env):
    app,c,h=env
    assert c.get('/api/elders').status_code==401
    assert c.get('/api/elders',headers={'Authorization':'Bearer fake'}).status_code==401
    family=h('family')
    assert len(c.get('/api/elders',headers=family).json())==1
    assert c.get('/api/elders/2',headers=family).status_code==403
    assert c.get('/api/tasks',headers=family).status_code==403
    assert c.post('/api/demo/scenario',headers=family,json={'scenario':'story'}).status_code==403
    assert c.post('/api/events',headers=family,json={'elder_id':2,'kind':'sos'}).status_code==403
    assert c.post('/api/events',headers=family,json={'elder_id':1,'kind':'data_offline'}).status_code==403
    staff=h('staff1')
    assert c.get('/api/elders',headers=staff).json()==[]
    assert c.get('/api/feedback/export',headers=staff).status_code==403


def test_event_dedup_and_emergency_not_downgraded(env):
    app,c,h=env;admin=h();family=h('family')
    event(c,family,id='same-event')
    assert event(c,family,id='same-event')['duplicate']
    event(c,family,kind='safe');event(c,family,kind='away',payload={'hours':4})
    incidents=c.get('/api/incidents',headers=admin).json()
    assert len(incidents)==1 and incidents[0]['level']==3
    assert len(c.get('/api/tasks',headers=admin).json())==1
    assert c.post('/api/events',headers=admin,json={'id':'same-event','elder_id':2,'kind':'sos'}).status_code==409


def test_unknown_data_is_not_normal_and_sos_is_retained(env):
    app,c,h=env;admin=h()
    event(c,admin,kind='data_offline');event(c,admin,kind='sos')
    elder=c.get('/api/elders/1',headers=admin).json()
    assert elder['data_unknown'] and elder['level']==3
    assert {i['category'] for i in c.get('/api/incidents',headers=admin).json()}=={'safety','data'}


def test_historical_input_does_not_overwrite_state(env):
    app,c,h=env;admin=h()
    event(c,admin,kind='data_offline')
    result=event(c,admin,kind='data_online',observed_at=time.time()-86400)
    assert result['historical']
    assert not c.get('/api/elders/1',headers=admin).json()['state']['online']


@pytest.mark.parametrize('payload',[{'count15':-1,'count60':2,'gap':0},{'count15':3,'count60':2,'gap':0},{'count15':1}])
def test_invalid_activity_inputs(env,payload):
    _,c,h=env
    assert c.post('/api/events',headers=h(),json={'elder_id':1,'kind':'activity','payload':payload}).status_code==422


def test_stale_staff_recommendation_is_rejected(env):
    app,c,h=env;admin=h();event(c,admin)
    rec=recs(c,admin)[0]
    r=c.put('/api/staff/'+str(rec['staff_id']),headers=admin,json={'available':False,'on_duty':True,'location':1})
    assert r.status_code==200
    r=c.post('/api/dispatch/confirm',headers=admin,json={'recommendation_id':rec['id']})
    assert r.status_code==409
    assert c.get('/api/tasks',headers=admin).json()[0]['state']=='pending'


def test_risk_escalation_invalidates_recommendation(env):
    app,c,h=env;admin=h()
    event(c,admin,kind='contact');rec=recs(c,admin)[0];event(c,admin,kind='sos')
    assert c.post('/api/dispatch/confirm',headers=admin,json={'recommendation_id':rec['id']}).status_code==409
    assert len(c.get('/api/tasks',headers=admin).json())==1


def test_skill_mismatch_override_rejected(env):
    app,c,h=env;admin=h();event(c,admin);rec=recs(c,admin)[0]
    r=c.post('/api/dispatch/confirm',headers=admin,json={'recommendation_id':rec['id'],'staff_id':3,'reason':'人工调整'})
    assert r.status_code==409


def test_concurrent_confirm_reserves_worker_once(env):
    app,c,h=env;admin=h();event(c,admin,1);event(c,admin,2)
    rr=recs(c,admin)
    chosen=rr[0]['staff_id']
    def confirm(rec):
        return c.post('/api/dispatch/confirm',headers=admin,json={'recommendation_id':rec['id'],'staff_id':chosen,'reason':'并发验证'}).status_code
    with concurrent.futures.ThreadPoolExecutor(2) as pool:
        statuses=list(pool.map(confirm,rr))
    assert sorted(statuses)==[200,409]
    with app.state.db.transaction() as con:
        assert con.execute("SELECT count(*) FROM tasks WHERE state='dispatched' AND staff_id=?",(chosen,)).fetchone()[0]==1


def test_complete_workflow_and_ownership(env):
    app,c,h=env;admin=h();event(c,admin);rec=recs(c,admin)[0]
    assert c.post('/api/dispatch/confirm',headers=admin,json={'recommendation_id':rec['id']}).status_code==200
    worker=h('staff'+str(rec['staff_id']));other=h('staff'+str(rec['staff_id']%4+1));tid=rec['task_id']
    assert c.post(f'/api/tasks/{tid}/action',headers=other,json={'action':'accept'}).status_code==403
    assert c.post(f'/api/tasks/{tid}/action',headers=worker,json={'action':'start'}).status_code==409
    for action in ('accept','start'):
        assert c.post(f'/api/tasks/{tid}/action',headers=worker,json={'action':action}).status_code==200
    assert c.post(f'/api/tasks/{tid}/action',headers=worker,json={'action':'feedback','outcome':'safe','note':'已电话联系，确认安全'}).status_code==200
    assert c.post(f'/api/tasks/{tid}/action',headers=worker,json={'action':'close'}).status_code==403
    assert c.post(f'/api/tasks/{tid}/action',headers=admin,json={'action':'close'}).status_code==200
    task=c.get(f'/api/tasks/{tid}',headers=admin).json()
    assert task['state']=='closed' and len(task['feedback'])==1
    assert len(task['audit'])>=6
    assert c.get('/api/elders/1',headers=admin).json()['level']==-1


def test_unresolved_feedback_requires_followup(env):
    _,c,h=env;admin=h();event(c,admin);rec=recs(c,admin)[0];tid=rec['task_id']
    c.post('/api/dispatch/confirm',headers=admin,json={'recommendation_id':rec['id']})
    c.post(f'/api/tasks/{tid}/action',headers=admin,json={'action':'accept'})
    c.post(f'/api/tasks/{tid}/action',headers=admin,json={'action':'feedback','outcome':'unreachable','note':'电话尚未接通'})
    assert c.post(f'/api/tasks/{tid}/action',headers=admin,json={'action':'close','outcome':'safe','note':'不能跳过核实'}).status_code==409
    assert c.post(f'/api/tasks/{tid}/action',headers=admin,json={'action':'followup'}).status_code==200
    assert c.get(f'/api/tasks/{tid}',headers=admin).json()['state']=='pending'


def test_reject_releases_capacity(env):
    _,c,h=env;admin=h();event(c,admin);rec=recs(c,admin)[0];tid=rec['task_id']
    c.post('/api/dispatch/confirm',headers=admin,json={'recommendation_id':rec['id']})
    r=c.post(f'/api/tasks/{tid}/action',headers=admin,json={'action':'reject','note':'临时无法到场'})
    assert r.status_code==200
    assert c.get(f'/api/tasks/{tid}',headers=admin).json()['staff_id'] is None
    assert len(recs(c,admin))==1


def test_persistence_overdue_idempotence(env):
    app,c,h=env;admin=h();event(c,admin)
    task=c.get('/api/tasks',headers=admin).json()[0]
    app.state.engine.tick(task['due']+1);app.state.engine.tick(task['due']+2)
    with app.state.db.transaction() as con:
        assert con.execute("SELECT count(*) FROM audit WHERE action='task_overdue' AND entity_id=?",(task['id'],)).fetchone()[0]==1
    second=create_app(app.state.db.path,demo=True,background=False);cc=TestClient(second)
    assert cc.get('/api/tasks',headers=admin).json()[0]['overdue']==1
    assert len(cc.get('/api/tasks',headers=admin).json())==1


def test_cold_start_and_profile_creation(env):
    _,c,h=env;admin=h()
    result=c.post('/api/elders',headers=admin,json={'name':'新增老人','age':75,'building':'1号楼','contact':'演示家属'})
    assert result.status_code==200
    eid=result.json()['id']
    event(c,admin,eid,kind='activity',payload={'count15':0,'count60':0,'gap':180})
    elder=c.get(f'/api/elders/{eid}',headers=admin).json()
    assert elder['profile']['history_days']==0 and not elder['state']['anomaly']
    assert '基线学习中' in elder['state']['evidence'][0]
    event(c,admin,eid,kind='sos')
    assert c.get(f'/api/elders/{eid}',headers=admin).json()['level']==3


def test_matching_preserves_priority_and_scarce_skills():
    tasks=[{'id':'old','elder_id':1,'level':3,'created':0,'required_skill':'phone'},
           {'id':'new','elder_id':2,'level':3,'created':1,'required_skill':'visit'},
           {'id':'low','elder_id':3,'level':1,'created':-10,'required_skill':'phone'}]
    workers=[{'id':1,'location':1,'skills':['phone','visit'],'on_duty':True,'available':True},
             {'id':2,'location':2,'skills':['phone'],'on_duty':True,'available':True}]
    result=assign(tasks,workers)
    assert {r['task_id'] for r in result}=={'old','new'}
    assert next(r for r in result if r['task_id']=='new')['staff_id']==1
    workers[1]['available']=False
    assert assign(tasks,workers)[0]['task_id']=='old'
    workers[0]['busy']=True
    assert assign(tasks,workers)==[]


def test_model_training_and_explicit_low_data_fallback():
    rows=synthetic_windows(20);model=PersonalModel(rows[:14*96],rows[14*96:])
    result=model.evaluate({'timestamp':rows[-1]['timestamp'],'count15':0,'count60':0,'gap':10000})
    assert result['anomaly'] and result['evidence']
    registry=ModelRegistry()
    assert not registry.evaluate(1,{'history_days':3},{},time.time())['anomaly']


def test_unanswered_check_escalates_but_reply_prevents_escalation(env):
    app,c,h=env;admin=h();event(c,admin,1,kind='contact');event(c,admin,2,kind='contact')
    event(c,admin,2,kind='away',payload={'hours':4})
    app.state.engine.tick(time.time()+601)
    incidents=c.get('/api/incidents',headers=admin).json()
    assert next(i for i in incidents if i['elder_id']==1)['level']==2
    assert next(i for i in incidents if i['elder_id']==2)['level']==1


def test_casas_replay_dedup_and_model_rehydration(env):
    app,c,h=env;admin=h()
    r=c.post('/api/replay/window',headers=admin,json={'elder_id':2,'offset':0})
    assert r.status_code==200,r.text
    assert c.post('/api/replay/window',headers=admin,json={'elder_id':2,'offset':0}).json()['duplicate']
    elder=c.get('/api/elders/2',headers=admin).json()
    assert elder['profile']['origin']=='CASAS Aruba replay'
    registry=ModelRegistry()
    result=registry.evaluate(2,elder['profile'],elder['state'],time.time())
    assert any('CASAS Aruba replay' in e for e in result['evidence'])


def test_new_profile_learns_real_accumulated_history_instead_of_synthetic(env):
    app,c,h=env;admin=h()
    eid=c.post('/api/elders',headers=admin,json={'name':'窗口学习样本','age':75,'building':'1号楼','contact':'演示联系人'}).json()['id']
    rows=synthetic_windows(16)
    shift=time.time()-rows[-1]['timestamp']-900
    with app.state.db.transaction(True) as con:
        for i,r in enumerate(rows):
            stamp=r['timestamp']+shift
            con.execute('INSERT INTO events VALUES(?,?,?,?,?,?,?,?)',
                        (f'history-{i}',eid,'activity',stamp,stamp,'fixture','合成历史测试样本',dumps({k:r[k] for k in ('count15','count60','gap')})))
    event(c,admin,eid,kind='activity',payload={'count15':0,'count60':0,'gap':200})
    result=c.get(f'/api/elders/{eid}',headers=admin).json()
    assert result['profile']['origin']=='accumulated-activity-windows'
    assert result['profile']['history_days']>=14
    assert result['profile']['baseline_ready']
    assert any('accumulated-activity-windows' in e for e in result['state']['evidence'])
