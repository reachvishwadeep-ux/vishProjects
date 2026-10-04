"""Incremental backup matching for newly uploaded cases."""

from __future__ import annotations

import asyncio
import logging
from contextlib import suppress

import numpy as np
from sqlalchemy import and_, or_, select, text
from sqlalchemy.orm import Session

from app.case_service import find_opposite_case_hits, persist_case_hits
from app.config import get_settings
from app.db import SessionLocal, engine
from app.face_engine import get_engine
from app.models import CaseFace, CaseReconciliationState, CaseRecord
from app.schemas import CaseType

logger = logging.getLogger(__name__)

_STATE_NAME = "case-matching"
_ADVISORY_LOCK_ID = 1_537_492_115


def reconcile_pending_case_faces(db: Session) -> int:
    settings = get_settings()
    state = db.get(CaseReconciliationState, _STATE_NAME)
    if state is None:
        state = CaseReconciliationState(name=_STATE_NAME)
        db.add(state)
        db.commit()

    processed = 0
    while True:
        faces = _pending_faces(db, state)
        if not faces:
            return processed

        for face in faces:
            case = face.case
            hits = find_opposite_case_hits(
                db,
                case_type=CaseType(case.case_type),
                embedding=np.asarray(face.embedding, dtype=np.float32),
                top_k=settings.reconciliation_top_k,
            )
            persist_case_hits(db, case=case, face=face, hits=hits)
            state.last_face_created_at = face.created_at
            state.last_face_id = face.id
            db.add(state)
            db.commit()
            processed += 1


def run_reconciliation_once() -> int:
    with engine.connect() as lock_connection:
        acquired = lock_connection.scalar(
            text("SELECT pg_try_advisory_lock(:lock_id)"),
            {"lock_id": _ADVISORY_LOCK_ID},
        )
        if not acquired:
            return 0
        try:
            with SessionLocal() as db:
                return reconcile_pending_case_faces(db)
        finally:
            lock_connection.execute(
                text("SELECT pg_advisory_unlock(:lock_id)"),
                {"lock_id": _ADVISORY_LOCK_ID},
            )


async def reconciliation_loop() -> None:
    settings = get_settings()
    while True:
        try:
            processed = await asyncio.to_thread(run_reconciliation_once)
            if processed:
                logger.info("Reconciled %s newly uploaded case faces", processed)
        except asyncio.CancelledError:
            raise
        except Exception:
            logger.exception("Case reconciliation sweep failed")
        await asyncio.sleep(settings.reconciliation_interval_seconds)


async def stop_reconciliation(task: asyncio.Task[None]) -> None:
    task.cancel()
    with suppress(asyncio.CancelledError):
        await task


def _pending_faces(
    db: Session,
    state: CaseReconciliationState,
) -> list[CaseFace]:
    settings = get_settings()
    statement = (
        select(CaseFace)
        .join(CaseRecord)
        .where(
            CaseRecord.status == "active",
            CaseFace.model_tag == get_engine().model_tag,
        )
        .order_by(CaseFace.created_at, CaseFace.id)
        .limit(settings.reconciliation_batch_size)
    )
    if state.last_face_created_at is not None and state.last_face_id is not None:
        statement = statement.where(
            or_(
                CaseFace.created_at > state.last_face_created_at,
                and_(
                    CaseFace.created_at == state.last_face_created_at,
                    CaseFace.id > state.last_face_id,
                ),
            )
        )
    return list(db.scalars(statement).all())
