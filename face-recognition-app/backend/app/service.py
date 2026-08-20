"""Enrolment and identification, independent of the HTTP layer."""

from __future__ import annotations

import uuid

import numpy as np
from sqlalchemy import select, text
from sqlalchemy.orm import Session

from app.config import get_settings
from app.face_engine import DetectedFace, get_engine
from app.models import Face, Person, SearchLog
from app.schemas import Match, SearchResponse
from app.storage import get_store


def enroll_face(
    db: Session,
    *,
    person: Person,
    image_bytes: bytes,
    face: DetectedFace,
    content_type: str,
) -> Face:
    store = get_store()
    key = f"faces/{person.id}/{uuid.uuid4()}.jpg"
    store.put(key, image_bytes, content_type=content_type)

    row = Face(
        person_id=person.id,
        image_key=key,
        bbox=list(face.bbox),
        det_score=face.det_score,
        quality=face.quality.score,
        model_tag=get_engine().model_tag,
        embedding=face.embedding.tolist(),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def get_or_create_person(db: Session, display_name: str, consent_ref: str | None) -> Person:
    person = db.scalar(select(Person).where(Person.display_name == display_name))
    if person is None:
        person = Person(display_name=display_name, consent_ref=consent_ref)
        db.add(person)
        db.commit()
        db.refresh(person)
    elif consent_ref and not person.consent_ref:
        person.consent_ref = consent_ref
        db.commit()
    return person


def search(
    db: Session,
    embedding: np.ndarray,
    top_k: int = 5,
    *,
    log: bool = True,
) -> SearchResponse:
    """1:N identification.

    Ranks by cosine distance in Postgres (HNSW index), keeps the best face per
    person, then applies a two-level threshold so borderline hits go to human
    review instead of being reported as matches.
    """
    settings = get_settings()
    engine = get_engine()
    store = get_store()

    # Over-fetch because several rows can belong to the same person.
    rows = db.execute(
        text(
            """
            SELECT f.id AS face_id, f.person_id, p.display_name, f.image_key,
                   1 - (f.embedding <=> CAST(:query AS vector)) AS score
            FROM face f
            JOIN person p ON p.id = f.person_id
            WHERE f.model_tag = :model_tag
            ORDER BY f.embedding <=> CAST(:query AS vector)
            LIMIT :limit
            """
        ),
        {
            "query": _to_vector_literal(embedding),
            "model_tag": engine.model_tag,
            "limit": top_k * 5,
        },
    ).mappings()

    best_by_person: dict[uuid.UUID, Match] = {}
    for row in rows:
        existing = best_by_person.get(row["person_id"])
        if existing is not None and existing.score >= row["score"]:
            continue
        best_by_person[row["person_id"]] = Match(
            person_id=row["person_id"],
            display_name=row["display_name"],
            face_id=row["face_id"],
            score=float(row["score"]),
            image_url=store.presigned_url(row["image_key"]),
        )

    results = sorted(best_by_person.values(), key=lambda m: m.score, reverse=True)[:top_k]

    top_score = results[0].score if results else None
    if top_score is None:
        decision = "no_match"
    elif top_score >= settings.match_threshold:
        decision = "match"
    elif top_score >= settings.review_threshold:
        decision = "review"
    else:
        decision = "no_match"

    if log:
        db.add(
            SearchLog(
                top_score=top_score,
                matched_person_id=results[0].person_id if decision == "match" else None,
                decision=decision,
            )
        )
        db.commit()

    return SearchResponse(decision=decision, threshold=settings.match_threshold, results=results)


def _to_vector_literal(embedding: np.ndarray) -> str:
    return "[" + ",".join(f"{v:.8f}" for v in np.asarray(embedding, dtype=np.float32)) + "]"
