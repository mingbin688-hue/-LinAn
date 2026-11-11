"""Causal window features and reproducible per-resident anomaly models."""
import math
import csv
from pathlib import Path
from datetime import datetime, timezone, timedelta
import numpy as np
from sklearn.ensemble import IsolationForest

MODEL_VERSION = 'iforest-personal-v1'
TZ = timezone(timedelta(hours=8))


def slot_at(timestamp):
    dt = datetime.fromtimestamp(timestamp, TZ)
    return dt.hour * 4 + dt.minute // 15


def expected_count(slot, scale=1):
    h = slot / 4
    return max(.15, (1.1 if h < 6 or h >= 22 else 8 + 8*math.exp(-((h-8)/1.7)**2)
                     + 5*math.exp(-((h-18)/2)**2)) * scale)


def synthetic_windows(days=60, scale=1, seed=42):
    rng = np.random.default_rng(seed)
    start = datetime(2025,1,1,tzinfo=TZ).timestamp()
    rows=[]
    for i in range(days*96):
        slot=i%96
        count=int(rng.poisson(expected_count(slot,scale)))
        # Consistent causal trailing counts, rather than independently drawn feature columns.
        recent=[r['count15'] for r in rows[-3:]]
        prev_gap=rows[-1]['gap'] if rows else 0
        gap=float(rng.uniform(0,12)) if count else prev_gap+15
        rows.append({'timestamp':start+i*900,'count15':count,'count60':sum(recent)+count,
                     'gap':gap,'slot':slot})
    return rows


def vector(row, baseline):
    slot=row.get('slot',slot_at(row['timestamp']))
    typical=max(.2,float(baseline[slot]))
    return [row['count15']/typical,row['count60']/max(1,typical*4),
            math.log1p(row['gap']),math.sin(slot*2*math.pi/96),math.cos(slot*2*math.pi/96)]


class PersonalModel:
    def __init__(self, train, validation):
        self.baseline=np.array([np.mean([r['count15'] for r in train if r.get('slot',slot_at(r['timestamp']))==s])
                                if any(r.get('slot',slot_at(r['timestamp']))==s for r in train) else 1 for s in range(96)])
        self.model=IsolationForest(n_estimators=80,random_state=42,contamination='auto',n_jobs=1)
        self.model.fit(np.array([vector(r,self.baseline) for r in train]))
        self.reference=-self.model.score_samples(np.array([vector(r,self.baseline) for r in validation]))
        self.threshold=float(np.quantile(self.reference,.98))
        self.idle_limits=np.array([max(30,float(np.quantile(
            [r['gap'] for r in train if min(abs(r.get('slot',slot_at(r['timestamp']))-s),96-abs(r.get('slot',slot_at(r['timestamp']))-s))<=4],.9))) for s in range(96)])

    def predict_many(self,rows):
        return -self.model.score_samples(np.array([vector(r,self.baseline) for r in rows]))

    def flags(self,rows):
        raw=self.predict_many(rows)
        baseline=np.array([r['gap']>self.idle_limits[r.get('slot',slot_at(r['timestamp']))]
                           and r['count15']<=max(0,self.baseline[r.get('slot',slot_at(r['timestamp']))]*.1) for r in rows])
        return (raw>self.threshold)|baseline

    def evaluate(self,row):
        raw=float(self.predict_many([row])[0])
        percentile=float(np.mean(self.reference <= raw)*100)
        typical=round(float(self.baseline[row.get('slot',slot_at(row['timestamp']))]),1)
        idle_limit=float(self.idle_limits[row.get('slot',slot_at(row['timestamp']))])
        baseline_flag=row['gap']>idle_limit and row['count15']<=max(0,typical*.1)
        return {'anomaly':bool(raw>self.threshold or baseline_flag),'score':round(percentile,1),'raw_score':round(raw,5),
                'threshold':round(self.threshold,5),'expected15':typical,
                'evidence':[f"近15分钟活动 {row['count15']} 次；个人同时间段基线约 {typical} 次",
                            f"距上次活动 {row['gap']:.0f} 分钟；异常分数分位 {percentile:.1f}",
                            f'个人同时间段历史无活动时长90分位阈值 {idle_limit:.0f} 分钟（下限30分钟）']}


class ModelRegistry:
    def __init__(self):
        self.models={}

    def evaluate(self,elder_id,profile,state,at):
        if profile.get('history_days',0)<14:
            return {'anomaly':False,'score':0,'evidence':['历史不足14天，基线学习中；保留人工上报与报平安规则']}
        key=(elder_id,profile.get('activity_scale',1),profile.get('origin','synthetic'))
        if key not in self.models:
            if profile.get('origin') in ('manual-demo','accumulated-activity-windows'):
                return {'anomaly':False,'score':0,'evidence':['有效活动窗口尚不足以建立个人模型，继续学习；保留人工上报规则']}
            if profile.get('origin')=='CASAS Aruba replay':
                file=Path(__file__).resolve().parents[1]/'data'/'aruba_windows.csv'
                if not file.exists():
                    return {'anomaly':False,'score':0,'evidence':['公开数据模型未准备；保留人工核实与报平安规则']}
                with file.open(encoding='utf-8') as f:
                    rows=[{k:float(v) if k!='slot' else int(v) for k,v in r.items()} for r in csv.DictReader(f)]
                days=len(rows)//96;a=int(days*.6)*96;b=int(days*.8)*96
                self.models[key]=PersonalModel(rows[:a],rows[a:b])
            else:
                rows=synthetic_windows(40,key[1],42+elder_id)
                cut=int(len(rows)*.75)
                self.models[key]=PersonalModel(rows[:cut],rows[cut:])
        result=self.models[key].evaluate({'timestamp':state.get('model_timestamp',at),'count15':state['count15'],
                                         'count60':state['count60'],'gap':state['gap']})
        result['evidence'].append(f"基线来源：{profile.get('origin','synthetic')}；分位分数不代表疾病概率")
        return result
