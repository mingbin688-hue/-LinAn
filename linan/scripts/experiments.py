import json
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from backend.experiments import run_all

if __name__=='__main__':
    result=run_all()
    out=ROOT/'data';out.mkdir(exist_ok=True)
    (out/'experiment_results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False,indent=2))
