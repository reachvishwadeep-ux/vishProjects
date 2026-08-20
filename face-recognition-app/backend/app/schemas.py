import uuid

from pydantic import BaseModel


class QualityReport(BaseModel):
    face_pixels: int
    det_score: float
    blur_variance: float
    yaw_degrees: float
    score: float
    passed: bool
    reasons: list[str] = []


class EnrollResponse(BaseModel):
    person_id: uuid.UUID
    face_id: uuid.UUID
    display_name: str
    quality: QualityReport


class Match(BaseModel):
    person_id: uuid.UUID
    display_name: str
    face_id: uuid.UUID
    score: float
    image_url: str | None = None


class SearchResponse(BaseModel):
    decision: str  # match | review | no_match
    threshold: float
    results: list[Match]


class FaceOut(BaseModel):
    id: uuid.UUID
    image_url: str | None
    det_score: float
    quality: float | None
    model_tag: str


class PersonOut(BaseModel):
    id: uuid.UUID
    display_name: str
    consent_ref: str | None
    faces: list[FaceOut]
