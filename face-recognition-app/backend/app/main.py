import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.db import engine
from app.face_engine import get_engine
from app.routers import cases, faces
from app.storage import get_store

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Load the ONNX models once at boot so the first request isn't slow.
    get_engine()
    get_store().ensure_bucket()
    yield


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
