"""Offline training; produces a reviewable artifact, never overwrites the online model."""
import argparse
import csv
import json
from pathlib import Path
import sqlite3
import sys
import joblib

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from backend.ml import PersonalModel, MODEL_VERSION


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--input',type=Path,default=ROOT/'data'/'aruba_windows.csv')
    parser.add_argument('--database',type=Path,default=ROOT/'runtime'/'linan.sqlite3')
    parser.add_argument('--output',type=Path,default=ROOT/'runtime'/'offline-model')
    args=parser.parse_args()
    with args.input.open(encoding='utf-8') as f:
        rows=[{k:int(v) if k=='slot' else float(v) for k,v in r.items()} for r in csv.DictReader(f)]
    n=len(rows)//96;a=int(n*.6)*96;b=int(n*.8)*96
    model=PersonalModel(rows[:a],rows[a:b])
    args.output.mkdir(parents=True,exist_ok=True)
    joblib.dump(model,args.output/'model.joblib')
    feedback=[]
    if args.database.exists():
        with sqlite3.connect(args.database.resolve().as_uri()+'?mode=ro',uri=True) as con:
            con.row_factory=sqlite3.Row
            feedback=[dict(r) for r in con.execute("SELECT f.*,t.elder_id,i.category,i.level FROM feedback f JOIN tasks t ON t.id=f.task_id JOIN incidents i ON i.id=t.incident_id WHERE t.state='closed'")]
    manifest={'model_version':MODEL_VERSION,'source':str(args.input),'training_windows':a,'validation_windows':b-a,
              'test_windows':len(rows)-b,'threshold':model.threshold,'reviewed_feedback_count':len(feedback),
              'deployment':'离线候选模型，未替换在线模型',
              'feedback_policy':'已关闭反馈单独供人工复盘；确认安全不自动等同原始窗口正常标签，不直接加入训练集。'}
    (args.output/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    (args.output/'reviewed_feedback.json').write_text(json.dumps(feedback,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(manifest,ensure_ascii=False,indent=2))


if __name__=='__main__':
    main()
