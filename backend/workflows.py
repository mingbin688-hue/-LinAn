"""Durable local orchestration. Rules/dispatch never wait for model generation."""
import hashlib
import json
import time
from fastapi import HTTPException
from .agents import result, ref, specialist
from .db import dumps, audit
from .workflow_store import node, run_detail


class Workflows:
    def __init__(self, db, engine, provider):
        self.db, self.engine, self.provider = db, engine, provider

    def settings(self, c):
        return {'auto_dispatch':c.execute("SELECT value FROM settings WHERE key='auto_dispatch'").fetchone()[0]=='true'}

    def _fingerprint(self,c):
        tasks = [dict(r) for r in c.execute("SELECT * FROM tasks WHERE state='pending' ORDER BY id")]
        workers = self.engine.worker_list(c)
        exclusions = [r[0] for r in c.execute('SELECT task_id FROM workflow_exclusions ORDER BY task_id')]
        data = [dict(r) for r in c.execute("SELECT id,elder_id,updated FROM incidents WHERE status='open' AND category='data' ORDER BY id")]
        # Refresh before the engine's five-minute recommendation expiry.
        return hashlib.sha256(dumps([tasks,workers,exclusions,data,self.settings(c),int(time.time()//240)]).encode()).hexdigest()

    def process(self):
        """Synchronous deterministic phase, called after commit and by the monitor."""
        with self.db.transaction(True) as c:
            now = time.time()
            # Older application databases acquire an outbox for still-active tasks too.
            from .workflow_store import enqueue
            for t in c.execute("SELECT * FROM tasks WHERE state!='closed' AND NOT EXISTS (SELECT 1 FROM workflow_runs w WHERE w.task_id=tasks.id AND w.kind='risk')").fetchall():
                enqueue(c,'risk',t['id'],'rehydrate:'+t['id'])
            fingerprint = self._fingerprint(c)
            old = c.execute("SELECT value FROM settings WHERE key='dispatch_fingerprint'").fetchone()
            recs = {}
            if not old or old[0]!=fingerprint:
                pending = c.execute("SELECT count(*) FROM tasks WHERE state='pending'").fetchone()[0]
                if pending:
                    matches = self.engine.recommendations(c,'workflow:dispatch')['recommendations']
                    recs = {m['task_id']:m for m in matches}
                    if self.settings(c)['auto_dispatch']:
                        for m in matches:
                            t = c.execute('SELECT * FROM tasks WHERE id=?',(m['task_id'],)).fetchone()
                            i = c.execute('SELECT * FROM incidents WHERE id=?',(t['incident_id'],)).fetchone()
                            blocked = c.execute('SELECT 1 FROM workflow_exclusions WHERE task_id=?',(t['id'],)).fetchone()
                            unknown = c.execute("SELECT 1 FROM incidents WHERE elder_id=? AND category='data' AND status='open'",(t['elder_id'],)).fetchone()
                            state = json.loads(c.execute('SELECT state FROM elders WHERE id=?',(t['elder_id'],)).fetchone()[0])
                            data_fresh = state.get('online') and now-state.get('last_seen',0)<=1800
                            if t['level']==1 and t['required_skill']=='phone' and i['category']=='safety' and not blocked and not unknown and data_fresh:
                                try:
                                    self.engine.confirm(c,'workflow:auto_dispatch',m['id'])
                                    audit(c,'workflow:auto_dispatch','auto_dispatch',t['id'],{'recommendation_id':m['id'],'policy':'level1-phone-v1'})
                                except HTTPException as exc:
                                    # A failed validation leaves the task pending; never bypass it.
                                    if exc.status_code not in (409,422):
                                        raise
                c.execute("INSERT INTO settings VALUES('dispatch_fingerprint',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",(self._fingerprint(c),))
            # Read valid latest recommendation snapshots when scheduling did not change.
            for row in c.execute("""SELECT r.* FROM recommendations r JOIN tasks t ON t.id=r.task_id
                    JOIN staff s ON s.id=r.staff_id WHERE t.state='pending' AND t.version=r.task_version
                    AND s.version=r.staff_version AND r.created>? ORDER BY r.created DESC""",(now-300,)):
                if row['task_id'] not in recs:
                    t = c.execute('SELECT * FROM tasks WHERE id=?',(row['task_id'],)).fetchone()
                    w = c.execute('SELECT * FROM staff WHERE id=?',(row['staff_id'],)).fetchone()
                    if t and w and t['version']==row['task_version'] and w['version']==row['staff_version'] and now-row['created']<=300:
                        recs[row['task_id']] = dict(id=row['id'],staff_id=row['staff_id'],eta=row['eta'],staff_name=w['name'])
            runs = c.execute("SELECT * FROM workflow_runs WHERE kind IN ('risk','review') AND status IN ('queued','waiting_human') ORDER BY created").fetchall()
            for run in runs:
                snapshot = json.loads(run['snapshot'])
                t = dict(c.execute('SELECT * FROM tasks WHERE id=?',(run['task_id'],)).fetchone())
                fresh = run['status']=='queued'
                context, base = specialist(snapshot,run['kind'])
                if fresh:
                    node(c,run['id'],'context','上下文整理','context','completed',{'elder_id':run['elder_id'],'source':snapshot['elder']['profile'].get('origin')},context)
                    node(c,run['id'],'assessment','风险依据' if run['kind']=='risk' else '处置反馈复核',
                         'risk' if run['kind']=='risk' else 'review','completed',{'task_id':t['id'],'version':snapshot['task']['version']},base)
                if run['kind']=='risk':
                    m = recs.get(t['id'])
                    blocked = c.execute('SELECT 1 FROM workflow_exclusions WHERE task_id=?',(t['id'],)).fetchone()
                    unknown = c.execute("SELECT 1 FROM incidents WHERE elder_id=? AND category='data' AND status='open'",(t['elder_id'],)).fetchone()
                    if t['state']!='pending':
                        auto = c.execute("SELECT 1 FROM audit WHERE action='auto_dispatch' AND entity_id=?",(t['id'],)).fetchone()
                        reason = '符合关注级电话核实规则，已自动派单' if auto else '任务已由现有业务流程推进'
                    elif blocked:
                        reason = '拒单或人工继续跟进后的任务，保留人工派单'
                    elif unknown or t['level']!=1 or t['required_skill']!='phone':
                        reason = '数据未知、优先或紧急任务，需要管理员人工确认'
                    elif not self.settings(c)['auto_dispatch']:
                        reason = '自动派单未开启，等待管理员确认'
                    elif not m:
                        reason = '暂无符合技能、在岗、空闲及优先级约束的可用人员，等待人工处理'
                    else:
                        reason = '当前数据或推荐已变化，等待重新核实与人工确认'
                    match_summary = f"建议由{m['staff_name']}处理，仿真到达 {m['eta']:.0f} 分钟" if m else '无当前可用推荐；保留待处理任务'
                    node(c,run['id'],'schedule','全量任务调度','dispatch','completed',{'task_id':t['id'],'priority':'紧急程度、等待时间优先；技能与单任务容量硬约束'},result(match_summary,base['evidence']))
                    waiting = t['state']=='pending'
                    node(c,run['id'],'confirmation','派单确认','dispatch','waiting_human' if waiting else 'completed',
                         {'auto_dispatch':self.settings(c)['auto_dispatch'],'task_state':t['state']},result(reason,base['evidence'],[reason]))
                else:
                    waiting = t['state']=='review'
                    reason = '等待管理员复核；未解决结果必须继续跟进' if waiting else '管理员已关闭或继续跟进该任务'
                    node(c,run['id'],'confirmation','人工复核','review','waiting_human' if waiting else 'completed',{'task_state':t['state']},result(reason,base['evidence'],[reason]))
                if fresh:
                    if self.provider.enabled:
                        node(c,run['id'],'explanation','生成解释','risk' if run['kind']=='risk' else 'review','queued',{'snapshot_version':snapshot['task']['version']},base)
                        c.execute('INSERT OR IGNORE INTO agent_jobs(run_id) VALUES(?)',(run['id'],))
                    else:
                        node(c,run['id'],'explanation','生成解释','risk' if run['kind']=='risk' else 'review','completed',{'snapshot_version':snapshot['task']['version']},base,error=self.provider.configuration_reason)
                    c.execute('UPDATE workflow_runs SET summary=? WHERE id=?',(base['summary'],run['id']))
                c.execute('UPDATE workflow_runs SET status=?,updated=? WHERE id=?',('waiting_human' if waiting else 'completed',now,run['id']))

    def drain(self, limit=4):
        """Lease jobs one at a time; an interrupted worker becomes retryable in 30s."""
        for _ in range(limit):
            with self.db.transaction(True) as c:
                job = c.execute("SELECT * FROM agent_jobs WHERE state='queued' OR (state='running' AND lease_until<?) ORDER BY rowid LIMIT 1",(time.time(),)).fetchone()
                if not job:
                    return
                if job['attempts']>=3:
                    fallback = result('解释生成多次中断，保留已有规则结果',mode='fallback',fallback_reason='生成重试已达上限')
                    node(c,job['run_id'],'explanation','生成解释','risk','failed',{},fallback,'fallback',fallback['fallback_reason'])
                    c.execute("UPDATE agent_jobs SET state='failed',lease_until=0 WHERE run_id=?",(job['run_id'],))
                    c.execute("UPDATE workflow_runs SET mode='fallback',updated=? WHERE id=?",(time.time(),job['run_id']))
                    continue
                lease = time.time()+30
                c.execute("UPDATE agent_jobs SET state='running',lease_until=?,attempts=attempts+1 WHERE run_id=?",(lease,job['run_id']))
                run = dict(c.execute('SELECT * FROM workflow_runs WHERE id=?',(job['run_id'],)).fetchone())
                snapshot = json.loads(run['snapshot'])
                node(c,run['id'],'explanation','生成解释','risk' if run['kind']=='risk' else 'review','running',{'snapshot_version':snapshot['task']['version']},specialist(snapshot,run['kind'])[1])
            base = specialist(snapshot,run['kind'])[1]
            started = time.perf_counter()
            answer = self.provider.generate(base,snapshot)
            with self.db.transaction(True) as c:
                current = c.execute('SELECT * FROM agent_jobs WHERE run_id=?',(run['id'],)).fetchone()
                if current['state']!='running' or current['lease_until']!=lease:
                    continue
                task = c.execute('SELECT version FROM tasks WHERE id=?',(run['task_id'],)).fetchone()
                stale = task['version']!=snapshot['task']['version']
                if stale:
                    answer = {**base,'mode':'fallback','fallback_reason':'任务版本已变化；保留历史快照解释，不作为当前操作建议'}
                node(c,run['id'],'explanation','生成解释','risk' if run['kind']=='risk' else 'review','completed',{'snapshot_version':snapshot['task']['version'],'historical':stale},answer,
                     answer['mode'],answer['fallback_reason'],(time.perf_counter()-started)*1000)
                c.execute('UPDATE workflow_runs SET summary=?,mode=?,updated=? WHERE id=?',(answer['summary'],answer['mode'],time.time(),run['id']))
                c.execute("UPDATE agent_jobs SET state='done',lease_until=0 WHERE run_id=?",(run['id'],))

    def task_runs(self,c,task_id):
        return [run_detail(c,r[0]) for r in c.execute("SELECT id FROM workflow_runs WHERE task_id=? ORDER BY created DESC LIMIT 8",(task_id,))]
