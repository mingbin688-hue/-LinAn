"""Lexicographic task admission, then minimum ETA assignment, with hard skills/capacity."""
import json
import numpy as np
from scipy.optimize import linear_sum_assignment

# Fictional minutes between buildings 1..5; not a routing API or measured travel time.
TRAVEL = [[2,5,8,11,14],[5,2,5,8,11],[8,5,2,5,8],[11,8,5,2,5],[14,11,8,5,2]]
INF=1e9


def eta(worker,task):
    return TRAVEL[(worker['location']-1)%5][(task['elder_id']-1)//4%5]


def assign(tasks,workers):
    workers=[w for w in workers if w['on_duty'] and w['available'] and not w.get('busy')]
    ordered=sorted(tasks,key=lambda t:(-t['level'],t['created'],t['id']))
    selected=[]
    def matrix(items):
        return np.array([[eta(w,t) if t['required_skill'] in
                          (json.loads(w['skills']) if isinstance(w['skills'],str) else w['skills']) else INF
                          for w in workers] for t in items],dtype=float)
    for task in ordered:
        if len(selected)>=len(workers):
            break
        candidate=selected+[task]
        cost=matrix(candidate)
        rows,cols=linear_sum_assignment(cost)
        if len(rows)==len(candidate) and all(cost[r,c]<INF for r,c in zip(rows,cols)):
            selected=candidate
    if not selected:
        return []
    cost=matrix(selected)
    rows,cols=linear_sum_assignment(cost)
    return [{'task_id':selected[r]['id'],'staff_id':workers[c]['id'],'eta':float(cost[r,c]),
             'reason':'按紧急程度与等待时间优先覆盖；满足技能、值班、空闲约束后，最小化本批次总预计到达时间'}
            for r,c in zip(rows,cols)]
