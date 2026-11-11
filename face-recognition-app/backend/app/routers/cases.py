import uuid

from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    Header,
    HTTPException,
    UploadFile,
    status,
)
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.audit_service import (
    record_case_upload,
    record_event,
    record_repeated_failure_risk,
)
from app.auth import AuthPrincipal, require_principal
from app.case_service import (
    CasePhoto,
    combine_case_search_results,
    create_case_with_faces,
    delete_case,
    list_case_matches,
    search_opposite_cases,
)
from app.db import get_db
from app.face_engine import get_engine
from app.images import decode_image, encode_jpeg
from app.models import CaseAccount, CaseRecord
from app.schemas import (
    CaseMatchesResponse,
    CaseOut,
    CaseSubmissionResponse,
    CaseType,
)

router = APIRouter(prefix="/v1/cases", tags=["cases"])
MAX_CASE_PHOTOS = 5


@router.post("", response_model=CaseSubmissionResponse, status_code=status.HTTP_201_CREATED)
def submit_case(
    image: UploadFile | None = File(default=None),
    images: list[UploadFile] | None = File(default=None),
    case_type: CaseType = Form(...),
    subject_label: str = Form("Photo submission"),
    top_k: int = Form(5),
    force: bool = Form(False),
    installation_id: uuid.UUID | None = Header(
        default=None,
        alias="X-Installation-ID",
    ),
    db: Session = Depends(get_db),
    principal: AuthPrincipal = Depends(require_principal),
) -> CaseSubmissionResponse:
    uploads = ([image] if image is not None else []) + (images or [])
    if not uploads:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Upload between 1 and 5 photos for this person.",
        )
    if len(uploads) > MAX_CASE_PHOTOS:
        _record_upload_rejection(
            db,
            principal.account.id,
            case_type,
            "too_many_photos",
            installation_id,
        )
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "error": f"A case can contain at most {MAX_CASE_PHOTOS} photos.",
                "reasons": [
                    f"Remove {len(uploads) - MAX_CASE_PHOTOS} photo(s) and try again."
                ],
            },
        )

    prepared_photos: list[CasePhoto] = []
    for index, upload in enumerate(uploads, start=1):
        try:
            decoded = decode_image(upload.file.read())
        except HTTPException:
            _reject_photo(
                db,
                account_id=principal.account.id,
                case_type=case_type,
                reason="invalid_image",
                message=f"Photo {index} is not a valid JPG or PNG image.",
                photo_index=index,
                installation_id=installation_id,
            )
        detected_faces = get_engine().detect_all(decoded)
        if not detected_faces:
            _reject_photo(
                db,
                account_id=principal.account.id,
                case_type=case_type,
                reason="no_face",
                message=f"No clear face was detected in photo {index}.",
                photo_index=index,
                installation_id=installation_id,
                reasons=[
                    "Use a sharp, well-lit photo with the face unobstructed and facing the camera."
                ],
            )
        if len(detected_faces) > 1:
            _reject_photo(
                db,
                account_id=principal.account.id,
                case_type=case_type,
                reason="multiple_faces",
                message=f"Photo {index} contains more than one person.",
                photo_index=index,
                installation_id=installation_id,
                reasons=["Choose a photo showing only the person for this case."],
            )
        detected = detected_faces[0]
        if not detected.quality.passed and not force:
            _reject_photo(
                db,
                account_id=principal.account.id,
                case_type=case_type,
                reason="low_quality",
                message=f"Photo {index} is not clear enough for reliable matching.",
                photo_index=index,
                installation_id=installation_id,
                reasons=detected.quality.reasons,
            )
        prepared_photos.append(
            CasePhoto(
                image_bytes=encode_jpeg(decoded),
                face=detected,
            )
        )

    case, faces = create_case_with_faces(
        db,
        case_type=case_type,
        subject_label=subject_label,
        photos=prepared_photos,
        account_id=principal.account.id,
    )
    bounded_top_k = min(max(top_k, 1), 20)
    search_results = [
        search_opposite_cases(
            db,
            case=case,
            face=face,
            embedding=photo.face.embedding,
            top_k=bounded_top_k,
        )
        for face, photo in zip(faces, prepared_photos, strict=True)
    ]
    match = combine_case_search_results(search_results, top_k=bounded_top_k)
    for face, photo in zip(faces, prepared_photos, strict=True):
        record_case_upload(
            db,
            account_id=principal.account.id,
            case_id=case.id,
            face_id=face.id,
            case_type=case_type.value,
            quality_score=photo.face.quality.score,
            forced=force and not photo.face.quality.passed,
            match_decision=match.decision,
            installation_id=installation_id,
        )
    qualities = [photo.face.quality for photo in prepared_photos]
    return CaseSubmissionResponse(
        case_id=case.id,
        case_type=case_type,
        subject_label=case.subject_label,
        photo_count=len(prepared_photos),
        quality=qualities[0],
        qualities=qualities,
        match=match,
    )


@router.get("/{case_id}", response_model=CaseOut)
def get_case(
    case_id: uuid.UUID,
    db: Session = Depends(get_db),
    principal: AuthPrincipal = Depends(require_principal),
) -> CaseOut:
    case = _get_owned_case(db, case_id, principal.account.id)
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
    principal: AuthPrincipal = Depends(require_principal),
) -> CaseMatchesResponse:
    return list_case_matches(
        db,
        _get_owned_case(db, case_id, principal.account.id),
    )


@router.delete("/{case_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_case(
    case_id: uuid.UUID,
    db: Session = Depends(get_db),
    principal: AuthPrincipal = Depends(require_principal),
) -> None:
    delete_case(db, _get_owned_case(db, case_id, principal.account.id))


def _get_owned_case(
    db: Session,
    case_id: uuid.UUID,
    account_id: uuid.UUID,
) -> CaseRecord:
    case = db.scalar(
        select(CaseRecord)
        .join(CaseAccount, CaseAccount.case_id == CaseRecord.id)
        .where(
            CaseRecord.id == case_id,
            CaseAccount.account_id == account_id,
        )
    )
    if case is None:
        existing_case = db.get(CaseRecord, case_id)
        if existing_case is not None:
            record_event(
                db,
                "case_access_rejected",
                account_id=account_id,
                data={"case_id": str(case_id)},
            )
            record_repeated_failure_risk(
                db,
                account_id=account_id,
                event_type="case_access_rejected",
                risk_type="repeated_unauthorized_case_access",
                data={"case_id": str(case_id)},
            )
            db.commit()
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="case not found",
        )
    return case


def _record_upload_rejection(
    db: Session,
    account_id: uuid.UUID,
    case_type: CaseType,
    reason: str,
    installation_id: uuid.UUID | None,
) -> None:
    record_event(
        db,
        "case_upload_rejected",
        account_id=account_id,
        data={
            "case_type": case_type.value,
            "reason": reason,
            "installation_id": (str(installation_id) if installation_id is not None else None),
        },
    )
    record_repeated_failure_risk(
        db,
        account_id=account_id,
        event_type="case_upload_rejected",
        risk_type="repeated_rejected_uploads",
        data={"latest_reason": reason},
    )
    db.commit()


def _reject_photo(
    db: Session,
    *,
    account_id: uuid.UUID,
    case_type: CaseType,
    reason: str,
    message: str,
    photo_index: int,
    installation_id: uuid.UUID | None,
    reasons: list[str] | None = None,
) -> None:
    _record_upload_rejection(
        db,
        account_id,
        case_type,
        reason,
        installation_id,
    )
    raise HTTPException(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        detail={
            "error": message,
            "photo_index": photo_index,
            "reasons": reasons or [],
        },
    )
