"""stdio bridge for desktop MCP clients (Claude Desktop, Codex, Cursor, ...).

Configure the client with:
  command: <project>/.venv/Scripts/python.exe
  args: ["-m", "backend.mcp_stdio"]
  env: LINAN_MCP_TOKEN=<token>, LINAN_DB=<optional database path>

Only read-only tools are exposed. The token is verified once at start-up; every
call still re-checks the caller's role and object scope against the database.
"""
import os
import sys
from pathlib import Path

from .agents import Assistant, ModelProvider
from .db import Database
from .engine import Engine
from .mcp import LinAnMcp, serve_stdio


def main(argv=None):
    token = os.getenv('LINAN_MCP_TOKEN', '').strip()
    if not token:
        sys.stderr.write('缺少 LINAN_MCP_TOKEN；请由管理员在流程中心签发 MCP 令牌。\n')
        return 2
    db_path = os.getenv('LINAN_DB') or str(Path(__file__).resolve().parents[1] / 'runtime' / 'linan.sqlite3')
    db = Database(db_path)
    db.initialize()
    engine = Engine(db)
    provider = ModelProvider()
    provider.load(db)
    assistant = Assistant(db, engine, provider)
    server = LinAnMcp(db, engine, assistant)
    with db.transaction(True) as c:
        user = server.authenticate(c, token)
    if not user:
        sys.stderr.write('MCP 令牌无效、已过期或已撤销。\n')
        return 2
    serve_stdio(server, user, sys.stdin, sys.stdout)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
