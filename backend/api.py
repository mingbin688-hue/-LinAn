"""Application factory: wiring, background loops and the HTTP surface."""
import asyncio
import contextlib
import logging
import os
import time
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI

from .agents import Assistant, ModelProvider
from .db import Database
from .engine import Engine, uid
from .mcp import LinAnMcp
from .routes import assistant as assistant_routes
from .routes import core as core_routes
from .routes import elders as elder_routes
from .routes import lab as lab_routes
from .routes import ops as ops_routes
from .routes import workflows as workflow_routes
from .workflows import Workflows

ROOT = Path(__file__).resolve().parents[1]


def create_app(db_path=None, demo=True, background=True):
    db = Database(db_path or os.getenv('LINAN_DB', str(ROOT / 'runtime' / 'linan.sqlite3')))
    db.initialize()
    fresh = db.seed()
    engine = Engine(db)
    provider = ModelProvider()
    workflows = Workflows(db, engine, provider)
    assistant = Assistant(db, engine, provider)
    mcp = LinAnMcp(db, engine, assistant)

    async def monitor():
        while True:
            try:
                await asyncio.to_thread(engine.tick)
                await asyncio.to_thread(workflows.process)
            except Exception:
                logging.exception('守护状态巡检失败')
            await asyncio.sleep(5)

    async def agent_worker():
        while True:
            try:
                await asyncio.to_thread(workflows.drain)
            except Exception:
                logging.exception('Agent 后台生成失败；任务租约到期后恢复')
            await asyncio.sleep(1)

    @asynccontextmanager
    async def lifespan(app):
        task = asyncio.create_task(monitor()) if background else None
        worker = asyncio.create_task(agent_worker()) if background else None
        yield
        for running in (task, worker):
            if running:
                running.cancel()
                with contextlib.suppress(asyncio.CancelledError):
                    await running
        provider.client.close()

    app = FastAPI(title='邻安 · 社区协同守护', version='1.0.0', lifespan=lifespan)
    app.state.db = db
    app.state.engine = engine
    app.state.provider = provider
    app.state.workflows = workflows
    app.state.assistant = assistant
    app.state.mcp = mcp
    app.state.replay_cache = {}

    for module in (core_routes, elder_routes, ops_routes, lab_routes, assistant_routes, workflow_routes):
        app.include_router(module.router)

    if fresh and demo:
        with db.transaction(True) as c:
            for eid, kind in [(1, 'missed_checkin'), (2, 'activity'), (3, 'sos')]:
                engine.ingest(c, 'system', {'id': uid('SEED'), 'elder_id': eid, 'kind': kind,
                                            'observed_at': time.time(),
                                            'source': '合成演示数据',
                                            'payload': {'count15': 0, 'count60': 0, 'gap': 180}
                                            if kind == 'activity' else {}})
    workflows.process()
    return app
