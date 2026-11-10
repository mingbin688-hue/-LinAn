"""Reproducible benchmarks; no clinical labels or clinical efficacy claims."""
import copy
import json
import math
from pathlib import Path
import numpy as np
from .ml import PersonalModel, synthetic_windows
from .scheduler import assign, eta


def activity_experiment(rows,origin='synthetic',seed=42):
    if len(rows)<14*96:
        raise ValueError('至少需要14天的15分钟窗口，建议30天以上')
    # Split at day boundaries BEFORE fitting baselines or selecting thresholds.
    days=len(rows)//96
    a=int(days*.6)*96;b=int(days*.8)*96
    train,val,test=rows[:a],rows[a:b],rows[b:]
    model=PersonalModel(train,val)
    raw=model.predict_many(test)
    rng=np.random.default_rng(seed)
    altered=copy.deepcopy(test)
    # Non-overlapping one-hour inactivity perturbations in waking hours.
    candidates=[i for i in range(4,len(test)-5) if 9<=test[i]['slot']/4<=19]
    rng.shuffle(candidates)
    starts=[]
    for i in candidates:
        if all(abs(i-j)>12 for j in starts):
            starts.append(i)
        if len(starts)>=min(40,max(5,len(test)//96)):
            break
    mask=np.zeros(len(test),dtype=bool)
    for start in starts:
        mask[start:start+4]=True
        for r in altered[start:start+4]:
            r['count15']=0
    previous=list(test[:0])
    for i,r in enumerate(altered):
        prior=(test[max(0,i-3):i] if i<3 else altered[i-3:i])
        r['count60']=sum(p['count15'] for p in prior)+r['count15']
        if mask[i]:
            r['gap']=(altered[i-1]['gap'] if i else 0)+15
    scored=model.predict_many(altered)
    pred=model.flags(altered)
    base=np.array([r['gap']>=60 and r['count15']==0 for r in altered])
    base_original=np.array([r['gap']>=60 and r['count15']==0 for r in test])
    def metrics(prediction,original):
        delays=[]
        for start in starts:
            hits=np.flatnonzero(prediction[start:start+4])
            if len(hits):
                delays.append((int(hits[0])+1)*15)
        return {'original_alarm_rate':round(float(np.mean(original)),4),
                'injected_window_recall':round(float(np.mean(prediction[mask])),4),
                'injected_episode_recall':round(len(delays)/len(starts),4) if starts else 0,
                'mean_detection_delay_minutes':round(float(np.mean(delays)),2) if delays else None,
                'detected_episodes':len(delays),'total_injected_episodes':len(starts)}
    return {'origin':origin,'split':{'train':len(train),'validation':len(val),'test':len(test)},
            'seed':seed,'threshold':model.threshold,
            'range':{'train_end':train[-1]['timestamp'],'validation_start':val[0]['timestamp'],
                     'validation_end':val[-1]['timestamp'],'test_start':test[0]['timestamp']},
            'baseline':metrics(base,base_original),'personalized':metrics(pred,model.flags(test)),
            'interpretation':'原始数据报警率不等同误报率；召回率仅针对注入的一小时无活动情景；未检出事件不进入延迟均值，应结合事件召回率阅读。',
            'perturbation':'测试段白天不重叠一小时活动置零；重算因果滚动特征；未注入训练或验证集',
            'model':'IsolationForest 80 trees, seed=42; validation score quantile=.98; OR training-slot inactivity q90 (minimum 30 minutes)',
            'evaluation_stage':'开发评估：开发阶段已查看测试段初测结果；正式效果结论仍需未接触数据独立验证'}


def scheduling_experiment(seed=42):
    rng=np.random.default_rng(seed)
    workers=[{'id':i+1,'name':str(i+1),'skills':['phone','visit'] if i!=2 else ['phone','device'],
              'on_duty':True,'available':True,'location':i+1,'busy':False} for i in range(4)]
    initial=[{'id':f'S{i:02d}','elder_id':i+1,'level':int(rng.choice([1,2,3])),
              'required_skill':'visit' if i%3 else 'phone','created':float(i)} for i in range(20)]
    def simulate(method):
        pending=copy.deepcopy(initial);free={w['id']:0.0 for w in workers};now=20.;records=[];violations=0
        while pending:
            available=[{**w,'busy':free[w['id']]>now} for w in workers]
            if method=='optimized':
                matches=assign(pending,available)
            else:
                matches=[];used=set()
                for t in sorted(pending,key=lambda x:x['created']):
                    eligible=[w for w in available if not w['busy'] and w['id'] not in used and t['required_skill'] in w['skills']]
                    if eligible:
                        w=min(eligible,key=lambda w:eta(w,t));used.add(w['id'])
                        matches.append({'task_id':t['id'],'staff_id':w['id'],'eta':eta(w,t)})
            if not matches:
                next_free=[v for v in free.values() if v>now]
                if not next_free:
                    break
                now=min(next_free);continue
            for m in matches:
                t=next(t for t in pending if t['id']==m['task_id']);w=workers[m['staff_id']-1]
                violations+=int(free[w['id']]>now or t['required_skill'] not in w['skills'])
                arrival=now+m['eta'];response=arrival-t['created']
                records.append({'level':t['level'],'response':response,'arrival':arrival,'id':t['id']})
                free[w['id']]=arrival+12;pending.remove(t)
        urgent=[r for r in records if r['level']==3]
        response=[r['response'] for r in records]
        return {'mean_response_minutes':round(float(np.mean(response)),2),'p95_response_minutes':round(float(np.quantile(response,.95)),2),
                'urgent_covered_within_30_minutes':round(sum(r['response']<=30 for r in urgent)/len(urgent),4) if urgent else 1,
                'urgent_mean_response_minutes':round(float(np.mean([r['response'] for r in urgent])),2) if urgent else 0,
                'constraint_violations':violations,'completed':len(records),'unassigned':len(pending)}
    return {'origin':'synthetic','seed':seed,'tasks':20,'workers':4,'service_minutes':12,'baseline':simulate('fifo'),
            'optimized':simulate('optimized'),'interpretation':'固定仿真时间矩阵；30分钟是实验比较窗口，不是现实服务承诺。高优先级任务优先可能增加低优先级任务等待。'}


def run_all():
    result={'activity':activity_experiment(synthetic_windows(60),origin='synthetic'),
            'scheduling':scheduling_experiment(),'data_notice':'活动与调度分别验证；默认演示均为合成数据。'}
    real=Path(__file__).resolve().parents[1]/'data'/'casas_experiment.json'
    if real.exists():
        result['casas']=json.loads(real.read_text(encoding='utf-8'))
    return result
