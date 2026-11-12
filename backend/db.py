"""SQLite persistence. Every state transition uses BEGIN IMMEDIATE."""
import contextlib
import hashlib
import json
import secrets
import sqlite3
import time
from pathlib import Path


def dumps(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def password_hash(password, salt=None):
    salt = salt or secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 180000).hex()
    return f"{salt}:{digest}"


def password_valid(password, stored):
    return secrets.compare_digest(password_hash(password, stored.split(":")[0]), stored)


class Database:
    def __init__(self, path):
        self.path = Path(path)
        if str(self.path) == ':memory:':
            # Every transaction opens its own connection, so an in-memory database
            # would silently lose its schema between transactions.
            raise ValueError('内存数据库不受支持：每个事务使用独立连接，请改用临时文件数据库。')
        self.path.parent.mkdir(parents=True, exist_ok=True)

    @contextlib.contextmanager
    def transaction(self, write=False):
        con = sqlite3.connect(self.path, timeout=20)
        con.row_factory = sqlite3.Row
        con.execute("PRAGMA foreign_keys=ON")
        con.execute("PRAGMA busy_timeout=20000")
        try:
            if write:
                con.execute("BEGIN IMMEDIATE")
            yield con
            con.commit()
        except Exception:
            con.rollback()
            raise
        finally:
            con.close()

    def initialize(self):
        with self.transaction(True) as c:
            c.executescript("""
            PRAGMA journal_mode=WAL;
            CREATE TABLE IF NOT EXISTS elders(
              id INTEGER PRIMARY KEY,name TEXT NOT NULL,age INTEGER NOT NULL,building TEXT NOT NULL,
              contact TEXT NOT NULL,profile TEXT NOT NULL,state TEXT NOT NULL,version INTEGER DEFAULT 1);
            CREATE TABLE IF NOT EXISTS staff(
              id INTEGER PRIMARY KEY,name TEXT,skills TEXT,on_duty INTEGER DEFAULT 1,
              available INTEGER DEFAULT 1,location INTEGER,version INTEGER DEFAULT 1);
            CREATE TABLE IF NOT EXISTS users(
              username TEXT PRIMARY KEY,password TEXT,role TEXT,name TEXT,elder_id INTEGER,staff_id INTEGER);
            CREATE TABLE IF NOT EXISTS sessions(token TEXT PRIMARY KEY,username TEXT REFERENCES users(username),expires REAL);
            CREATE TABLE IF NOT EXISTS events(
              id TEXT PRIMARY KEY,elder_id INTEGER REFERENCES elders(id),kind TEXT,observed_at REAL,
              received_at REAL,actor TEXT,source TEXT,payload TEXT);
            CREATE TABLE IF NOT EXISTS incidents(
              id TEXT PRIMARY KEY,elder_id INTEGER REFERENCES elders(id),category TEXT,level INTEGER,
              title TEXT,evidence TEXT,advice TEXT,status TEXT,created REAL,updated REAL,model_version TEXT);
            CREATE UNIQUE INDEX IF NOT EXISTS one_open_incident ON incidents(elder_id,category) WHERE status='open';
            CREATE TABLE IF NOT EXISTS tasks(
              id TEXT PRIMARY KEY,incident_id TEXT UNIQUE REFERENCES incidents(id),elder_id INTEGER REFERENCES elders(id),
              level INTEGER,state TEXT,required_skill TEXT,staff_id INTEGER REFERENCES staff(id),
              created REAL,updated REAL,due REAL,overdue INTEGER DEFAULT 0,version INTEGER DEFAULT 1);
            CREATE UNIQUE INDEX IF NOT EXISTS one_active_task_per_staff ON tasks(staff_id)
              WHERE state IN ('dispatched','accepted','processing');
            CREATE TABLE IF NOT EXISTS recommendations(
              id TEXT PRIMARY KEY,task_id TEXT,staff_id INTEGER,task_version INTEGER,staff_version INTEGER,
              created REAL,eta REAL,snapshot TEXT);
            CREATE TABLE IF NOT EXISTS feedback(
              id TEXT PRIMARY KEY,task_id TEXT REFERENCES tasks(id),actor TEXT,outcome TEXT,note TEXT,created REAL);
            CREATE TABLE IF NOT EXISTS audit(
              id INTEGER PRIMARY KEY AUTOINCREMENT,actor TEXT,action TEXT,entity_id TEXT,payload TEXT,created REAL);
            CREATE TABLE IF NOT EXISTS notifications(
              id TEXT PRIMARY KEY,role TEXT,staff_id INTEGER,elder_id INTEGER,title TEXT,body TEXT,created REAL);
            CREATE TABLE IF NOT EXISTS experiments(
              id TEXT PRIMARY KEY,kind TEXT,result TEXT,created REAL);
            CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY,value TEXT);
            CREATE TABLE IF NOT EXISTS workflow_runs(
              id TEXT PRIMARY KEY,kind TEXT NOT NULL,trigger_key TEXT UNIQUE NOT NULL,
              elder_id INTEGER REFERENCES elders(id),task_id TEXT REFERENCES tasks(id),owner TEXT,
              status TEXT NOT NULL,mode TEXT NOT NULL,summary TEXT NOT NULL,snapshot TEXT NOT NULL,
              definition_version INTEGER NOT NULL DEFAULT 1,context_digest TEXT NOT NULL DEFAULT '',
              created REAL NOT NULL,updated REAL NOT NULL);
            CREATE INDEX IF NOT EXISTS workflow_task ON workflow_runs(task_id,created);
            CREATE TABLE IF NOT EXISTS workflow_nodes(
              id INTEGER PRIMARY KEY AUTOINCREMENT,run_id TEXT REFERENCES workflow_runs(id),
              node_key TEXT,name TEXT,agent TEXT,status TEXT,input TEXT,output TEXT,
              elapsed_ms REAL DEFAULT 0,mode TEXT DEFAULT 'rules',error TEXT,
              attempts INTEGER NOT NULL DEFAULT 0,started REAL NOT NULL DEFAULT 0,
              finished REAL NOT NULL DEFAULT 0,UNIQUE(run_id,node_key));
            CREATE TABLE IF NOT EXISTS workflow_exclusions(
              task_id TEXT PRIMARY KEY REFERENCES tasks(id),reason TEXT,created REAL);
            CREATE TABLE IF NOT EXISTS jobs(
              id TEXT PRIMARY KEY,kind TEXT NOT NULL,job_key TEXT NOT NULL,payload TEXT NOT NULL,
              state TEXT NOT NULL,priority INTEGER NOT NULL DEFAULT 100,run_at REAL NOT NULL,
              attempts INTEGER NOT NULL DEFAULT 0,max_attempts INTEGER NOT NULL DEFAULT 3,
              lease_until REAL NOT NULL DEFAULT 0,last_error TEXT,result TEXT,
              created REAL NOT NULL,updated REAL NOT NULL);
            CREATE UNIQUE INDEX IF NOT EXISTS one_active_job ON jobs(kind,job_key)
              WHERE state IN ('queued','running');
            CREATE INDEX IF NOT EXISTS jobs_state ON jobs(state,run_at);
            CREATE TABLE IF NOT EXISTS mcp_tokens(
              id TEXT PRIMARY KEY,token_hash TEXT UNIQUE NOT NULL,username TEXT NOT NULL,
              label TEXT NOT NULL,created REAL NOT NULL,expires REAL NOT NULL DEFAULT 0,
              last_used REAL NOT NULL DEFAULT 0,revoked INTEGER NOT NULL DEFAULT 0);
            CREATE TABLE IF NOT EXISTS assistant_sessions(
              id TEXT PRIMARY KEY,owner TEXT NOT NULL,scope_ids TEXT NOT NULL,created REAL NOT NULL,
              scope_tasks TEXT NOT NULL DEFAULT '[]');
            CREATE TABLE IF NOT EXISTS assistant_messages(
              id INTEGER PRIMARY KEY AUTOINCREMENT,session_id TEXT REFERENCES assistant_sessions(id),
              role TEXT,content TEXT,citations TEXT,mode TEXT,scope_ids TEXT,created REAL);
            INSERT OR IGNORE INTO settings VALUES('auto_dispatch','false');
            """)
            if 'scope_tasks' not in {r['name'] for r in c.execute('PRAGMA table_info(assistant_sessions)')}:
                c.execute("ALTER TABLE assistant_sessions ADD COLUMN scope_tasks TEXT NOT NULL DEFAULT '[]'")
            self._ensure_columns(c, 'workflow_runs', {
                'definition_version': 'INTEGER NOT NULL DEFAULT 1',
                'context_digest': "TEXT NOT NULL DEFAULT ''",
            })
            self._ensure_columns(c, 'workflow_nodes', {
                'attempts': 'INTEGER NOT NULL DEFAULT 0',
                'started': 'REAL NOT NULL DEFAULT 0',
                'finished': 'REAL NOT NULL DEFAULT 0',
            })
            self._migrate_agent_jobs(c)
            c.execute("INSERT INTO settings VALUES('schema_version','3') ON CONFLICT(key) DO UPDATE SET value='3'")

    @staticmethod
    def _ensure_columns(c, table, columns):
        existing = {r['name'] for r in c.execute(f'PRAGMA table_info({table})')}
        for name, kind in columns.items():
            if name not in existing:
                c.execute(f'ALTER TABLE {table} ADD COLUMN {name} {kind}')

    @staticmethod
    def _migrate_agent_jobs(c):
        if not c.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='agent_jobs'").fetchone():
            return
        now = time.time()
        rows = c.execute("SELECT j.run_id,j.state,j.lease_until,j.attempts,r.snapshot FROM agent_jobs j "
                         "JOIN workflow_runs r ON r.id=j.run_id").fetchall()
        for row in rows:
            if row['state'] == 'done':
                continue
            state = row['state'] if row['state'] in ('queued', 'running') else 'queued'
            c.execute("INSERT OR IGNORE INTO jobs(id,kind,job_key,payload,state,priority,run_at,attempts,"
                      "max_attempts,lease_until,last_error,result,created,updated) "
                      "VALUES(?,?,?,?,?,100,?,?,3,0,NULL,NULL,?,?)",
                      (f"JOB-{secrets.token_hex(12)}", 'explanation', row['run_id'],
                       dumps({'run_id': row['run_id'], 'snapshot': json.loads(row['snapshot'])}),
                       state, now, row['attempts'], now, now))
        c.execute('DROP TABLE agent_jobs')

    def seed(self):
        now = time.time()
        with self.transaction(True) as c:
            if c.execute("SELECT count(*) FROM elders").fetchone()[0]:
                return False
            names = ['王桂兰','李建国','张秀英','陈文华','刘淑珍','赵德明','周玉芳','吴志远','徐惠琴','孙福安',
                     '胡美玲','朱永康','高月娥','林振华','何秋菊','郭长青','马桂芬','罗文清','梁瑞莲','郑国祥']
            for i, name in enumerate(names, 1):
                profile = {'routine':'通常 07:00 起床，22:00 休息','checkin_hour':9,'history_days':30,
                           'activity_scale':round(.8 + i * .035, 3),'origin':'synthetic',
                           'note':'虚拟演示档案，活动基线来自合成数据'}
                state = {'online':True,'last_seen':now,'last_checkin':now,'presence':'home',
                         'presence_until':0,'last_contact':now,'unreachable':False,
                         'count15':12,'count60':48,'gap':3,'anomaly_streak':0,'anomaly':False,
                         'score':0,'evidence':[],'observed_at':now,'source':'合成演示数据'}
                c.execute("INSERT INTO elders VALUES(?,?,?,?,?,?,?,1)",
                          (i,name,69+i%17,f'{1+(i-1)//4}号楼 · {101+(i-1)%4*100}',f'演示联系人 {i:02d}',dumps(profile),dumps(state)))
            workers=[('陈晓', ['phone','visit','device'],1),('林悦',['phone','visit'],3),
                     ('赵海',['phone','device'],5),('许宁',['phone','visit'],2)]
            for i,(name,skills,loc) in enumerate(workers,1):
                c.execute("INSERT INTO staff VALUES(?,?,?,1,1,?,1)",(i,name,dumps(skills),loc))
            users=[('admin','admin','社区管理员',None,None),('family','family','王桂兰的家属',1,None),
                   ('elder','elder','王桂兰',1,None)]
            users += [(f'staff{i}','staff',w[0],None,i) for i,w in enumerate(workers,1)]
            for username,role,name,eid,sid in users:
                c.execute("INSERT INTO users VALUES(?,?,?,?,?,?)",(username,password_hash('Demo2026!'),role,name,eid,sid))
            c.execute("INSERT OR IGNORE INTO settings VALUES('schema_version','3')")
            return True


def audit(c, actor, action, entity_id, payload):
    c.execute("INSERT INTO audit(actor,action,entity_id,payload,created) VALUES(?,?,?,?,?)",
              (actor,action,entity_id,dumps(payload),time.time()))


def notify(c, title, body, role='admin', staff_id=None, elder_id=None):
    c.execute("INSERT INTO notifications VALUES(?,?,?,?,?,?,?)",
              (secrets.token_hex(12),role,staff_id,elder_id,title,body,time.time()))
