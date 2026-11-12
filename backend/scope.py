"""Role-scoped record references shared by assistants, context packs and MCP."""
from fastapi import HTTPException


def ref(kind, ident, label, **extra):
    return dict(type=kind, id=str(ident), label=label, **extra)


def visible_ids(c, user):
    """Elder ids the account may read; unknown ids are never implied by a role."""
    role = user['role']
    if role == 'admin':
        return {r[0] for r in c.execute('SELECT id FROM elders')}
    if role in ('family', 'elder'):
        return {user['elder_id']}
    return {r[0] for r in c.execute(
        "SELECT DISTINCT elder_id FROM tasks WHERE staff_id=? AND state!='closed'",
        (user['staff_id'],))}


def readable_task(c, user, tid):
    """Return a task only when the caller may read it, otherwise None."""
    row = c.execute('SELECT * FROM tasks WHERE id=?', (tid,)).fetchone()
    if not row:
        return None
    if user['role'] == 'staff':
        return dict(row) if row['staff_id'] == user['staff_id'] else None
    if user['role'] in ('family', 'elder'):
        return dict(row) if row['elder_id'] == user['elder_id'] else None
    return dict(row)


def require_elder(c, user, elder_id):
    if elder_id not in visible_ids(c, user):
        raise HTTPException(403, '无权访问该老人记录')
    return elder_id
