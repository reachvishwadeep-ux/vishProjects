import uuid
from datetime import datetime
from enum import StrEnum

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


class CaseType(StrEnum):
    missing = "missing"
    found = "found"


class CaseCandidate(BaseModel):
    case_id: uuid.UUID
    subject_label: str
    score: float
    image_url: str | None = None


class CaseSearchResult(BaseModel):
    decision: str
    threshold: float
    results: list[CaseCandidate]


class CaseSubmissionResponse(BaseModel):
    case_id: uuid.UUID
    case_type: CaseType
    subject_label: str
    quality: QualityReport
    match: CaseSearchResult


class CaseOut(BaseModel):
    id: uuid.UUID
    case_type: CaseType
    subject_label: str
    status: str
    created_at: datetime


class CaseMatchesResponse(BaseModel):
    case_id: uuid.UUID
    results: list[CaseCandidate]
