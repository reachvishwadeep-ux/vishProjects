import asyncio
import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from sqlalchemy import text

from app.config import get_settings
from app.db import engine, ensure_runtime_schema
from app.face_engine import get_engine
from app.models import Base
from app.reconciliation import reconciliation_loop, stop_reconciliation
from app.routers import audit, auth, cases, connections, faces
from app.storage import get_store

logger = logging.getLogger(__name__)
PRIVACY_POLICY_PATH = Path(__file__).with_name("static") / "privacy.html"


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(engine)
    ensure_runtime_schema()
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
app.include_router(auth.router)
app.include_router(connections.router)
app.include_router(audit.router)


@app.get("/health")
def health() -> dict[str, object]:
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
    return {"status": "ok", "model_tag": get_engine().model_tag}


@app.get("/privacy", include_in_schema=False, response_class=FileResponse)
def privacy_policy() -> FileResponse:
    return FileResponse(PRIVACY_POLICY_PATH, media_type="text/html")
