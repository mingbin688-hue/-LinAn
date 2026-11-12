"""Health, session lifecycle, identity and notifications."""
import time

from fastapi import APIRouter, Depends, Header, HTTPException, Request

from ..db import password_valid
from ..deps import current_user, database
from ..engine import RULE_VERSION
from ..ml import MODEL_VERSION
from ..schemas import Login
from .. import session

router = APIRouter()


@router.get('/')
def index():
    return {'app': 'linan-community-guard', 'version': '1.0.0', 'docs': '/docs'}


@router.get('/api/health')
def health(request: Request):
    with database(request).transaction() as c:
        schema = c.execute("SELECT value FROM settings WHERE key='schema_version'").fetchone()
    return {'status': 'ok', 'app': 'linan-community-guard', 'version': '1.0.0',
            'data_origin': 'synthetic demo + optional CASAS import',
            'rule_version': RULE_VERSION, 'model_version': MODEL_VERSION,
            'schema_version': schema[0] if schema else None}


@router.post('/api/auth/login')
def login(body: Login, request: Request):
    now = time.time()
    recent = session.throttle(body.username, now)
    with database(request).transaction(True) as c:
        row = c.execute('SELECT * FROM users WHERE username=?', (body.username,)).fetchone()
        if not row or not password_valid(body.password, row['password']):
            session.remember_failure(body.username, recent, now)
            raise HTTPException(401, '账号或密码不正确')
        token = session.issue(c, body.username, now)
        return {'token': token,
                'user': {key: value for key, value in dict(row).items() if key != 'password'}}


@router.post('/api/auth/logout')
def logout(request: Request, u=Depends(current_user), authorization: str = Header()):
    with database(request).transaction(True) as c:
        session.revoke(c, authorization)
    return {'ok': True}


@router.get('/api/me')
def me(u=Depends(current_user)):
    return u


@router.get('/api/notifications')
def notifications(request: Request, u=Depends(current_user)):
    query = 'SELECT * FROM notifications WHERE role=?'
    params = [u['role']]
    if u['role'] == 'staff':
        query += ' AND staff_id=?'
        params.append(u['staff_id'])
    elif u['role'] in ('family', 'elder'):
        query += ' AND elder_id=?'
        params.append(u['elder_id'])
    query += ' ORDER BY created DESC LIMIT 30'
    with database(request).transaction() as c:
        return [dict(r) for r in c.execute(query, params)]
