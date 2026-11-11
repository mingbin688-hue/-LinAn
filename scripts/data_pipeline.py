"""Download official CASAS archive, extract Aruba only, create causal windows and report."""
import argparse
import bisect
import csv
from datetime import datetime
import hashlib
import json
from pathlib import Path
import sys
import zipfile
import requests

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from backend.ml import TZ, slot_at
from backend.experiments import activity_experiment

URL='https://zenodo.org/api/records/17180309/files/new_labeled_data.zip/content'


def download():
    raw=ROOT/'data'/'raw';raw.mkdir(parents=True,exist_ok=True)
    dest=raw/'casas-official.zip'
    if not dest.exists():
        partial=dest.with_suffix('.part')
        with requests.get(URL,stream=True,timeout=(20,90)) as response:
            response.raise_for_status()
            with partial.open('wb') as f:
                for block in response.iter_content(1024*1024):
                    f.write(block)
        partial.replace(dest)
    with zipfile.ZipFile(dest) as archive:
        candidates=[n for n in archive.namelist() if 'aruba' in n.lower() and not n.endswith('/')]
        if not candidates:
            raise RuntimeError('官方归档未包含Aruba数据，请使用 --input 指定本地原始数据')
        print('Aruba files:',candidates)
        # Pick the largest Aruba data file, never extract untrusted archive paths.
        chosen=max(candidates,key=lambda n:archive.getinfo(n).file_size)
        output=raw/'aruba.txt'
        with archive.open(chosen) as src,output.open('wb') as dst:
            import shutil
            shutil.copyfileobj(src,dst)
    manifest={'url':URL,'source':'CASAS / WSU, Zenodo record 17180309','archive_member':chosen,
              'doi':'10.5281/zenodo.17180309','license':'CC-BY-4.0',
              'attribution':'Cook, Diane; Crandall, Aaron; Thomas, Brian (2025), CASAS Smart Home dataset',
              'archive_sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),
              'input_sha256':hashlib.sha256(output.read_bytes()).hexdigest(),
              'time_policy':'保留采集地墙上时间计算时段；TZ仅提供稳定时间轴，不声称采集时区为上海'}
    (ROOT/'data'/'source_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    return output


def windows(path):
    times=[];invalid=0;line_count=0
    with Path(path).open(encoding='utf-8',errors='replace') as f:
        for line in f:
            line_count+=1
            fields=line.strip().split()
            if len(fields)<4:
                invalid+=1;continue
            try:
                stamp=datetime.fromisoformat(fields[0]+'T'+fields[1]).replace(tzinfo=TZ).timestamp()
            except ValueError:
                invalid+=1;continue
            if fields[2].startswith('M') and fields[3].upper() in ('ON','1'):
                times.append(stamp)
    times.sort()
    if not times:
        raise ValueError('未找到有效运动传感器ON事件。要求：日期 时间 Mxxx ON [可选活动标签]')
    start=int(times[0]//86400)*86400  # Align below at local midnight to preserve whole-day splits.
    first=datetime.fromtimestamp(times[0],TZ).replace(hour=0,minute=0,second=0,microsecond=0).timestamp()
    last=datetime.fromtimestamp(times[-1],TZ).replace(hour=0,minute=0,second=0,microsecond=0).timestamp()
    rows=[]
    for end in range(int(first+86400+900),int(last),900):
        hi=bisect.bisect_right(times,end)
        a=bisect.bisect_right(times,end-900);b=bisect.bisect_right(times,end-3600)
        gap=(end-times[hi-1])/60 if hi else 1440
        rows.append({'timestamp':end,'count15':hi-a,'count60':hi-b,'gap':gap,'slot':slot_at(end)})
    # Keep complete midnight-aligned blocks of 96 windows.
    rows=rows[:len(rows)//96*96]
    return rows,{'lines':line_count,'unparsed_lines':invalid,'motion_on_events':len(times)}


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--input',type=Path)
    args=parser.parse_args()
    source=args.input or download()
    rows,quality=windows(source)
    out=ROOT/'data';out.mkdir(exist_ok=True)
    with (out/'aruba_windows.csv').open('w',newline='',encoding='utf-8') as f:
        writer=csv.DictWriter(f,fieldnames=['timestamp','count15','count60','gap','slot']);writer.writeheader();writer.writerows(rows)
    report=activity_experiment(rows,'CASAS Aruba official single-resident data')
    report['quality']=quality
    (out/'casas_experiment.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False,indent=2))


if __name__=='__main__':
    main()
