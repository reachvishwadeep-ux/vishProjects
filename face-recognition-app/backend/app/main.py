import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.config import get_settings
from app.db import engine
from app.face_engine import get_engine
from app.models import Base
from app.reconciliation import reconciliation_loop, stop_reconciliation
from app.routers import cases, faces
from app.storage import get_store

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(engine)
    get_engine()
    get_store().ensure_bucket()
    reconciliation_task = None
    if get_settings().reconciliation_enabled:
        reconciliation_task = asyncio.create_task(reconciliation_loop())
    try:
        yield
    finally:
        if reconciliation_task is not None:
            await stop_reconciliation(reconciliation_task)


app = FastAPI(title="Face Recognition API", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(faces.router)
app.include_router(cases.router)


@app.get("/health")
def health() -> dict[str, object]:
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
    return {"status": "ok", "model_tag": get_engine().model_tag}
