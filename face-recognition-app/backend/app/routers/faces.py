import uuid

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.auth import require_principal
from app.db import get_db
from app.face_engine import get_engine
from app.images import decode_image
from app.models import Face, Person
from app.schemas import EnrollResponse, FaceOut, PersonOut, SearchResponse
from app.service import enroll_face, get_or_create_person, search
from app.storage import get_store

router = APIRouter(prefix="/v1", dependencies=[Depends(require_principal)])


@router.post("/enroll", response_model=EnrollResponse, status_code=status.HTTP_201_CREATED)
def enroll(
    image: UploadFile = File(...),
    person_name: str = Form(...),
    consent_ref: str | None = Form(None),
    force: bool = Form(False),
    db: Session = Depends(get_db),
) -> EnrollResponse:
    """Add a photo to the repository.

    Rejects low-quality photos unless ``force`` is set: a bad enrolment degrades
    every future search against that person.
    """
    raw = image.file.read()
    face = get_engine().detect_primary(decode_image(raw))
    if face is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="no face detected"
        )
    if not face.quality.passed and not force:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "error": "photo quality too low for enrolment",
                "reasons": face.quality.reasons,
            },
        )

    person = get_or_create_person(db, person_name, consent_ref)
    row = enroll_face(
        db,
        person=person,
        image_bytes=raw,
        face=face,
        content_type=image.content_type or "image/jpeg",
    )
    return EnrollResponse(
        person_id=person.id,
        face_id=row.id,
        display_name=person.display_name,
        quality=face.quality,
    )


@router.post("/search", response_model=SearchResponse)
def search_endpoint(
    image: UploadFile = File(...),
    top_k: int = Form(5),
    db: Session = Depends(get_db),
) -> SearchResponse:
    face = get_engine().detect_primary(decode_image(image.file.read()))
    if face is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="no face detected"
        )
    return search(db, face.embedding, top_k=min(max(top_k, 1), 50))


@router.get("/persons", response_model=list[PersonOut])
def list_persons(limit: int = 100, offset: int = 0, db: Session = Depends(get_db)):
    people = db.scalars(
        select(Person).order_by(Person.display_name).limit(min(limit, 500)).offset(offset)
    ).all()
    return [_person_out(p) for p in people]


@router.get("/persons/{person_id}", response_model=PersonOut)
def get_person(person_id: uuid.UUID, db: Session = Depends(get_db)) -> PersonOut:
    person = db.get(Person, person_id)
    if person is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="person not found")
    return _person_out(person)


@router.delete("/persons/{person_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_person(person_id: uuid.UUID, db: Session = Depends(get_db)) -> None:
    """Purge a person's biometrics and images (GDPR / BIPA erasure request)."""
    person = db.get(Person, person_id)
    if person is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="person not found")
    keys = [face.image_key for face in person.faces]
    db.delete(person)
    db.commit()
    get_store().delete(keys)


def _person_out(person: Person) -> PersonOut:
    store = get_store()
    return PersonOut(
        id=person.id,
        display_name=person.display_name,
        consent_ref=person.consent_ref,
        faces=[
            FaceOut(
                id=face.id,
                image_url=store.presigned_url(face.image_key),
                det_score=face.det_score,
                quality=face.quality,
                model_tag=face.model_tag,
            )
            for face in _sorted_faces(person)
        ],
    )


def _sorted_faces(person: Person) -> list[Face]:
    return sorted(person.faces, key=lambda f: f.created_at)
