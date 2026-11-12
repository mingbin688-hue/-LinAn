"""Session tokens, login throttling and the role guards they feed."""
import hashlib
import secrets
import time

from fastapi import HTTPException

SESSION_SECONDS = 8 * 3600
MAX_FAILURES = 10
FAILURE_WINDOW = 60
FAILURES: dict[str, list[float]] = {}


def digest(token):
    return hashlib.sha256(token.encode()).hexdigest()


def throttle(username, now=None):
    """Return the recent failures for a username, pruning stale entries first."""
    now = time.time() if now is None else now
    recent = [stamp for stamp in FAILURES.get(username, []) if now - stamp < FAILURE_WINDOW]
    if len(recent) >= MAX_FAILURES:
        raise HTTPException(429, '尝试次数较多，请稍后重试')
    if len(FAILURES) > 256:
        stale = [name for name, stamps in FAILURES.items() if not stamps or stamps[-1] < now - FAILURE_WINDOW]
        for name in stale:
            FAILURES.pop(name, None)
    return recent


def remember_failure(username, recent, now=None):
    FAILURES[username] = (recent + [time.time() if now is None else now])[-MAX_FAILURES:]


def issue(c, username, now=None):
    """Rotate the caller's session: old expired rows go, the new token lasts eight hours."""
    now = time.time() if now is None else now
    token = secrets.token_urlsafe(40)
    c.execute('DELETE FROM sessions WHERE expires<?', (now,))
    c.execute('INSERT INTO sessions VALUES(?,?,?)', (digest(token), username, now + SESSION_SECONDS))
    return token


def resolve(c, authorization):
    if not authorization or not authorization.startswith('Bearer '):
        raise HTTPException(401, '请先登录')
    row = c.execute('SELECT u.* FROM users u JOIN sessions s ON u.username=s.username '
                    'WHERE s.token=? AND s.expires>?', (digest(authorization[7:]), time.time())).fetchone()
    if not row:
        raise HTTPException(401, '登录已过期，请重新登录')
    return {key: value for key, value in dict(row).items() if key != 'password'}


def revoke(c, authorization):
    c.execute('DELETE FROM sessions WHERE token=?', (digest(authorization[7:]),))
