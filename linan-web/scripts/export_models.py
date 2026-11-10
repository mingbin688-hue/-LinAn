"""Export the verified Python forests as read-only numerical trees for edge inference."""
from pathlib import Path
import csv,json,sys

ROOT=Path(__file__).resolve().parents[1]
LOCAL=ROOT.parent/'linan'
sys.path.insert(0,str(LOCAL))
from backend.ml import PersonalModel,synthetic_windows

def export(model):
    return {'baseline':model.baseline.tolist(),'idle_limits':model.idle_limits.tolist(),
            'reference':model.reference.tolist(),'threshold':model.threshold,'samples':model.model.max_samples_,
            'trees':[{'left':t.tree_.children_left.tolist(),'right':t.tree_.children_right.tolist(),
                      'feature':t.tree_.feature.tolist(),'threshold':t.tree_.threshold.tolist(),
                      'count':t.tree_.n_node_samples.tolist()} for t in model.model.estimators_]}

out=ROOT/'generated';out.mkdir(exist_ok=True)
models={}
for eid in range(1,21):
    rows=synthetic_windows(40,round(.8+eid*.035,3),42+eid);cut=int(len(rows)*.75)
    models[str(eid)]=export(PersonalModel(rows[:cut],rows[cut:]))
with (LOCAL/'data'/'aruba_windows.csv').open(encoding='utf-8') as f:
    rows=[{k:int(v) if k=='slot' else float(v) for k,v in r.items()} for r in csv.DictReader(f)]
days=len(rows)//96;a=int(days*.6)*96;b=int(days*.8)*96
models['casas']=export(PersonalModel(rows[:a],rows[a:b]))
(out/'models.json').write_text(json.dumps(models,separators=(',',':')),encoding='utf-8')
(out/'replay.json').write_text(json.dumps(rows[b:],separators=(',',':')),encoding='utf-8')
(out/'experiments.json').write_text((LOCAL/'data'/'experiment_results.json').read_text(encoding='utf-8'),encoding='utf-8')
# Cross-runtime fixtures include ordinary and extreme windows, including held-out public data.
fixtures=[]
for key in ('1','2','20','casas'):
    m=models[key]
    if key=='casas':
        model=PersonalModel(rows[:a],rows[a:b]);test=rows[b:b+12]
    else:
        data=synthetic_windows(40,round(.8+int(key)*.035,3),42+int(key));cut=int(len(data)*.75)
        model=PersonalModel(data[:cut],data[cut:]);test=data[-12:]
    for row in test+[{'timestamp':1738771200,'count15':0,'count60':0,'gap':180}]:
        p=model.evaluate(row);fixtures.append({'key':key,'row':row,'raw':p['raw_score'],'anomaly':p['anomaly']})
(out/'parity.json').write_text(json.dumps(fixtures,separators=(',',':')),encoding='utf-8')
print('Exported 20 per-resident forests + CASAS forest, public replay, reports and parity fixtures')
