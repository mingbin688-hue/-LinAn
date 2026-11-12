"""FastAPI dependencies: database access, current session and role guards."""
from fastapi import Depends, Header, HTTPException, Request

from . import session
from .scope import visible_ids


def database(request: Request):
    return request.app.state.db


def current_user(request: Request, authorization: str | None = Header(default=None)):
    with database(request).transaction() as c:
        return session.resolve(c, authorization)


def require_admin(user=Depends(current_user)):
    if user['role'] != 'admin':
        raise HTTPException(403, '该操作需要社区管理员权限')
    return user


def require_operator(user=Depends(current_user)):
    if user['role'] not in ('admin', 'staff'):
        raise HTTPException(403, '该操作需要社区工作人员权限')
    return user


def require_elder(c, user, elder_id):
    if elder_id not in visible_ids(c, user):
        raise HTTPException(403, '无权访问该老人记录')
