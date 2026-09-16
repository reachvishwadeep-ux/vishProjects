"""Remote missing/found repository matching."""

from __future__ import annotations

import uuid
from dataclasses import dataclass

import numpy as np
from sqlalchemy import or_, select, text
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.config import get_settings
from app.face_engine import DetectedFace, get_engine
from app.models import CaseFace, CaseMatch, CaseRecord
from app.schemas import CaseCandidate, CaseMatchesResponse, CaseSearchResult, CaseType
from app.storage import get_store


@dataclass(frozen=True)
class CaseHit:
    case_id: uuid.UUID
    face_id: uuid.UUID
    subject_label: str
    image_key: str
    score: float


def opposite_case_type(case_type: CaseType) -> CaseType:
    return CaseType.found if case_type == CaseType.missing else CaseType.missing


def decide_case_match(score: float | None) -> str:
    settings = get_settings()
    if score is None or score < settings.review_threshold:
        return "no_match"
    if score < settings.match_threshold:
        return "review"
    return "match"


def create_case(
    db: Session,
    *,
    case_type: CaseType,
    subject_label: str,
    image_bytes: bytes,
    face: DetectedFace,
    content_type: str,
) -> tuple[CaseRecord, CaseFace]:
    case = CaseRecord(
        case_type=case_type.value,
        subject_label=subject_label.strip() or "Photo submission",
        status="active",
    )
    db.add(case)
    db.flush()

    store = get_store()
    key = f"cases/{case.id}/{uuid.uuid4()}.jpg"
    store.put(key, image_bytes, content_type=content_type)

    case_face = CaseFace(
        case_id=case.id,
        case_type=case_type.value,
        image_key=key,
        bbox=list(face.bbox),
        det_score=face.det_score,
        quality=face.quality.score,
        model_tag=get_engine().model_tag,
        embedding=face.embedding.tolist(),
    )
    db.add(case_face)
    db.commit()
    db.refresh(case)
    db.refresh(case_face)
    return case, case_face


def search_opposite_cases(
    db: Session,
    *,
    case: CaseRecord,
    face: CaseFace,
    embedding: np.ndarray,
    top_k: int,
) -> CaseSearchResult:
    target_type = opposite_case_type(CaseType(case.case_type))
    engine = get_engine()
    store = get_store()

    rows = db.execute(
        text(
            """
            SELECT cf.id AS face_id, cf.case_id, c.subject_label, cf.image_key,
                   1 - (cf.embedding <=> CAST(:query AS vector)) AS score
            FROM case_face cf
            JOIN case_record c ON c.id = cf.case_id
            WHERE cf.model_tag = :model_tag
              AND cf.case_type = :target_type
              AND c.status = 'active'
            ORDER BY cf.embedding <=> CAST(:query AS vector)
            LIMIT :limit
            """
        ),
        {
            "query": _to_vector_literal(embedding),
            "model_tag": engine.model_tag,
            "target_type": target_type.value,
            "limit": top_k * 5,
        },
    ).mappings()

    best_by_case: dict[uuid.UUID, CaseHit] = {}
    for row in rows:
        hit = CaseHit(
            case_id=row["case_id"],
            face_id=row["face_id"],
            subject_label=row["subject_label"],
            image_key=row["image_key"],
            score=float(row["score"]),
        )
        existing = best_by_case.get(hit.case_id)
        if existing is None or hit.score > existing.score:
            best_by_case[hit.case_id] = hit

    hits = sorted(best_by_case.values(), key=lambda item: item.score, reverse=True)[:top_k]
    decision = decide_case_match(hits[0].score if hits else None)
    _persist_candidates(db, case=case, face=face, hits=hits)
    review_threshold = get_settings().review_threshold
    reviewable_hits = [hit for hit in hits if hit.score >= review_threshold]

    return CaseSearchResult(
        decision=decision,
        threshold=get_settings().match_threshold,
        results=[
            CaseCandidate(
                case_id=hit.case_id,
                subject_label=hit.subject_label,
                score=hit.score,
                image_url=store.presigned_url(hit.image_key),
            )
            for hit in reviewable_hits
        ],
    )


def list_case_matches(db: Session, case: CaseRecord) -> CaseMatchesResponse:
    matches = db.scalars(
        select(CaseMatch)
        .where(
            or_(
                CaseMatch.missing_case_id == case.id,
                CaseMatch.found_case_id == case.id,
            )
        )
        .order_by(CaseMatch.score.desc())
    ).all()
    store = get_store()
    results: list[CaseCandidate] = []
    for match in matches:
        requested_is_missing = match.missing_case_id == case.id
        other_case_id = match.found_case_id if requested_is_missing else match.missing_case_id
        other_face_id = match.found_face_id if requested_is_missing else match.missing_face_id
        other_case = db.get(CaseRecord, other_case_id)
        other_face = db.get(CaseFace, other_face_id)
        if other_case is None or other_face is None or other_case.status != "active":
            continue
        results.append(
            CaseCandidate(
                case_id=other_case.id,
                subject_label=other_case.subject_label,
                score=match.score,
                image_url=store.presigned_url(other_face.image_key),
            )
        )
    return CaseMatchesResponse(case_id=case.id, results=results)


def delete_case(db: Session, case: CaseRecord) -> None:
    keys = [face.image_key for face in case.faces]
    db.delete(case)
    db.commit()
    get_store().delete(keys)


def _persist_candidates(
    db: Session,
    *,
    case: CaseRecord,
    face: CaseFace,
    hits: list[CaseHit],
) -> None:
    settings = get_settings()
    for hit in hits:
        if hit.score < settings.review_threshold:
            continue
        if case.case_type == CaseType.missing.value:
            missing_case_id = case.id
            found_case_id = hit.case_id
            missing_face_id = face.id
            found_face_id = hit.face_id
        else:
            missing_case_id = hit.case_id
            found_case_id = case.id
            missing_face_id = hit.face_id
            found_face_id = face.id

        statement = insert(CaseMatch).values(
            missing_case_id=missing_case_id,
            found_case_id=found_case_id,
            missing_face_id=missing_face_id,
            found_face_id=found_face_id,
            score=hit.score,
            decision=decide_case_match(hit.score),
            model_tag=get_engine().model_tag,
        )
        statement = statement.on_conflict_do_update(
            constraint="case_match_pair_model_key",
            set_={
                "missing_face_id": missing_face_id,
                "found_face_id": found_face_id,
                "score": hit.score,
                "decision": decide_case_match(hit.score),
                "updated_at": text("now()"),
            },
            where=CaseMatch.score < hit.score,
        )
        db.execute(statement)
    db.commit()


def _to_vector_literal(embedding: np.ndarray) -> str:
    return "[" + ",".join(f"{value:.8f}" for value in np.asarray(embedding, dtype=np.float32)) + "]"
