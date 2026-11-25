import uuid
from datetime import datetime
from enum import StrEnum

from pydantic import BaseModel, Field


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
    connection_id: uuid.UUID | None = None


class CaseSearchResult(BaseModel):
    decision: str
    threshold: float
    results: list[CaseCandidate]


class CaseSubmissionResponse(BaseModel):
    case_id: uuid.UUID
    case_type: CaseType
    subject_label: str
    photo_count: int
    quality: QualityReport
    qualities: list[QualityReport]
    match: CaseSearchResult


class CaseOut(BaseModel):
    id: uuid.UUID
    case_type: CaseType
    subject_label: str
    status: str
    created_at: datetime


class CasePhotoOut(BaseModel):
    id: uuid.UUID
    image_url: str
    quality: float | None
    created_at: datetime


class OwnedCaseOut(CaseOut):
    match_count: int
    match_state: str
    photos: list[CasePhotoOut]


class OwnedCaseListResponse(BaseModel):
    results: list[OwnedCaseOut]


class CaseMatchesResponse(BaseModel):
    case_id: uuid.UUID
    results: list[CaseCandidate]


class ConnectionRole(StrEnum):
    missing = "missing"
    found = "found"


class ConnectionOut(BaseModel):
    id: uuid.UUID
    role: ConnectionRole
    status: str
    my_case_id: uuid.UUID
    other_case_id: uuid.UUID
    other_subject_label: str
    score: float
    image_url: str | None = None
    my_image_url: str | None = None
    other_image_url: str | None = None
    my_consented: bool
    other_consented: bool
    my_contact_sharing_consented: bool = False
    other_contact_sharing_consented: bool = False
    other_phone_number: str | None = None
    my_verified_peer: bool
    other_verified_peer: bool
    unread: bool
    meeting_code: str | None = None
    meeting_code_expires_at: datetime | None = None
    created_at: datetime


class ConnectionListResponse(BaseModel):
    results: list[ConnectionOut]


class MatchHistoryRole(StrEnum):
    missing = "missing"
    found = "found"
    both = "both"


class MatchHistoryOut(BaseModel):
    id: uuid.UUID
    role: MatchHistoryRole
    missing_case_id: uuid.UUID
    found_case_id: uuid.UUID
    missing_subject_label: str
    found_subject_label: str
    score: float
    decision: str
    image_url: str | None = None
    same_account: bool
    connection_id: uuid.UUID | None = None
    connection_status: str | None = None
    created_at: datetime


class MatchHistoryListResponse(BaseModel):
    results: list[MatchHistoryOut]


class MeetingCodeVerifyRequest(BaseModel):
    code: str


class OtpRequest(BaseModel):
    phone_number: str


class OtpRequestResponse(BaseModel):
    challenge_id: uuid.UUID
    expires_in: int
    development_code: str | None = None


class OtpVerifyRequest(BaseModel):
    challenge_id: uuid.UUID
    phone_number: str
    code: str
    contact_sharing_consent: bool = False


class RefreshRequest(BaseModel):
    refresh_token: str


class AccountOut(BaseModel):
    id: uuid.UUID
    phone_number: str
    contact_sharing_consented: bool = False


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    account: AccountOut


class InstallationPlatform(StrEnum):
    android = "android"
    ios = "ios"


class InstallationRequest(BaseModel):
    installation_id: uuid.UUID
    platform: InstallationPlatform
    app_version: str = Field(min_length=1, max_length=32)
    build_number: str = Field(min_length=1, max_length=32)


class PushRegistrationRequest(BaseModel):
    installation_id: uuid.UUID
    fid: str | None = Field(default=None, min_length=20, max_length=255)
    enabled: bool


class InstallationOut(BaseModel):
    installation_id: uuid.UUID
    account_id: uuid.UUID | None
    account_phone: str | None
    platform: InstallationPlatform
    app_version: str
    build_number: str
    first_seen_at: datetime
    last_seen_at: datetime
    last_authenticated_at: datetime | None
    push_enabled: bool
    is_active: bool


class AuditEventOut(BaseModel):
    id: uuid.UUID
    event_type: str
    account_id: uuid.UUID | None
    account_phone: str | None
    event_data: dict[str, object]
    created_at: datetime


class AuditEventListResponse(BaseModel):
    results: list[AuditEventOut]


class InstallationListResponse(BaseModel):
    results: list[InstallationOut]


class AuditSummaryResponse(BaseModel):
    installation_registrations: int
    linked_installations: int
    accounts: int
    missing_uploads: int
    found_uploads: int
    confirmed_matches: int
    risk_alerts: int
