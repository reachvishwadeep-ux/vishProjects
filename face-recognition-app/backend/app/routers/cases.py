import uuid

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.auth import require_principal
from app.case_service import create_case, delete_case, list_case_matches, search_opposite_cases
from app.db import get_db
from app.face_engine import get_engine
from app.images import decode_image, encode_jpeg
from app.models import CaseRecord
from app.schemas import (
    CaseMatchesResponse,
    CaseOut,
    CaseSubmissionResponse,
    CaseType,
)

router = APIRouter(
    prefix="/v1/cases",
    tags=["cases"],
    dependencies=[Depends(require_principal)],
)


@router.post("", response_model=CaseSubmissionResponse, status_code=status.HTTP_201_CREATED)
def submit_case(
    image: UploadFile = File(...),
    case_type: CaseType = Form(...),
    subject_label: str = Form("Photo submission"),
    top_k: int = Form(5),
    force: bool = Form(False),
    db: Session = Depends(get_db),
) -> CaseSubmissionResponse:
    decoded = decode_image(image.file.read())
    detected_faces = get_engine().detect_all(decoded)
    if not detected_faces:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="no face detected",
        )
    if len(detected_faces) > 1:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="multiple faces detected; upload a photo with one primary person",
        )
    detected = detected_faces[0]
    if not detected.quality.passed and not force:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "error": "photo quality too low for recognition",
                "reasons": detected.quality.reasons,
            },
        )

    case, face = create_case(
        db,
        case_type=case_type,
        subject_label=subject_label,
        image_bytes=encode_jpeg(decoded),
        face=detected,
        content_type="image/jpeg",
    )
    match = search_opposite_cases(
        db,
        case=case,
        face=face,
        embedding=detected.embedding,
        top_k=min(max(top_k, 1), 20),
    )
    return CaseSubmissionResponse(
        case_id=case.id,
        case_type=case_type,
        subject_label=case.subject_label,
        quality=detected.quality,
        match=match,
    )


@router.get("/{case_id}", response_model=CaseOut)
def get_case(case_id: uuid.UUID, db: Session = Depends(get_db)) -> CaseOut:
    case = _get_case(db, case_id)
    return CaseOut(
        id=case.id,
        case_type=CaseType(case.case_type),
        subject_label=case.subject_label,
        status=case.status,
        created_at=case.created_at,
    )


@router.get("/{case_id}/matches", response_model=CaseMatchesResponse)
def get_case_matches(
    case_id: uuid.UUID,
    db: Session = Depends(get_db),
) -> CaseMatchesResponse:
    return list_case_matches(db, _get_case(db, case_id))


@router.delete("/{case_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_case(case_id: uuid.UUID, db: Session = Depends(get_db)) -> None:
    delete_case(db, _get_case(db, case_id))


def _get_case(db: Session, case_id: uuid.UUID) -> CaseRecord:
    case = db.get(CaseRecord, case_id)
    if case is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="case not found",
        )
    return case
