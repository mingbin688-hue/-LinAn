"""Response shaping shared by the routers: one query per relation, not per row."""
import json


def decorated_elder(c, row):
    return decorate_elders(c, [row])[0]


def decorate_elders(c, rows):
    rows = [dict(r) for r in rows]
    by_elder = {}
    for r in c.execute("SELECT * FROM incidents WHERE status='open' ORDER BY level DESC,created DESC"):
        by_elder.setdefault(r['elder_id'], []).append(dict(r))
    for e in rows:
        e['profile'] = json.loads(e['profile'])
        e['state'] = json.loads(e['state'])
        incidents = by_elder.get(e['id'], [])
        e['level'] = max((i['level'] for i in incidents), default=-1)
        e['data_unknown'] = any(i['category'] == 'data' for i in incidents)
        e['incident_count'] = len(incidents)
        e['latest_incident'] = incidents[0]['id'] if incidents else None
    return rows


def decorated_task(c, row):
    return decorate_tasks(c, [row])[0]


def decorate_tasks(c, rows):
    """Attach elder/incident/worker context with three queries instead of three per row."""
    rows = [dict(r) for r in rows]
    elders = {r['id']: r['name'] for r in c.execute('SELECT id,name FROM elders')}
    staff = {r['id']: r['name'] for r in c.execute('SELECT id,name FROM staff')}
    incidents = {r['id']: dict(r) for r in c.execute('SELECT * FROM incidents')}
    for t in rows:
        t['elder_name'] = elders.get(t['elder_id'], '未知老人')
        incident = incidents.get(t['incident_id'])
        if incident:
            t.update(title=incident['title'], category=incident['category'],
                     evidence=json.loads(incident['evidence']), advice=incident['advice'])
        else:
            t.update(title='未关联风险事件', category='unknown', evidence=[], advice='')
        t['staff_name'] = staff.get(t['staff_id']) if t['staff_id'] else None
    return rows
