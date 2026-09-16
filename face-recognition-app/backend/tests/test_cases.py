import uuid
from types import SimpleNamespace

import cv2
import numpy as np
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app import case_service
from app import storage
from app.db import get_db
from app.face_engine import DetectedFace
from app.routers import cases
from app.schemas import (
    CaseCandidate,
    CaseSearchResult,
    CaseType,
    QualityReport,
)


def _quality() -> QualityReport:
    return QualityReport(
        face_pixels=180,
        det_score=0.99,
        blur_variance=160,
        yaw_degrees=2,
        score=0.94,
        passed=True,
        reasons=[],
    )


def _detected_face() -> DetectedFace:
    return DetectedFace(
        embedding=np.ones(512, dtype=np.float32),
        bbox=(10, 10, 190, 190),
        det_score=0.99,
        quality=_quality(),
    )


def test_opposite_repositories_are_explicit() -> None:
    assert case_service.opposite_case_type(CaseType.missing) == CaseType.found
    assert case_service.opposite_case_type(CaseType.found) == CaseType.missing


def test_decisions_use_configured_review_and_match_bands() -> None:
    assert case_service.decide_case_match(None) == "no_match"
    assert case_service.decide_case_match(0.31) == "no_match"
    assert case_service.decide_case_match(0.35) == "review"
    assert case_service.decide_case_match(0.50) == "match"


def test_presigned_urls_use_the_public_object_store_endpoint(monkeypatch) -> None:
    settings = SimpleNamespace(
        s3_bucket="faces",
        presign_ttl_seconds=3600,
        s3_endpoint_url="http://minio:9000",
        s3_public_endpoint_url="http://10.0.2.2:9000",
        s3_access_key="minioadmin",
        s3_secret_key="minioadmin",
        s3_region="us-east-1",
    )
    monkeypatch.setattr(storage, "get_settings", lambda: settings)

    url = storage.ObjectStore().presigned_url("cases/example/photo.jpg")

    assert url.startswith("http://10.0.2.2:9000/faces/cases/example/photo.jpg?")


def test_submission_contract_passes_missing_role_to_remote_case_service(
    monkeypatch,
) -> None:
    submitted_case_id = uuid.uuid4()
    candidate_case_id = uuid.uuid4()
    captured_case_types: list[CaseType] = []

    class FakeEngine:
        def detect_all(self, image: np.ndarray) -> list[DetectedFace]:
            assert image.shape == (16, 16, 3)
            return [_detected_face()]

    def fake_create_case(
        db: object,
        *,
        case_type: CaseType,
        subject_label: str,
        image_bytes: bytes,
        face: DetectedFace,
        content_type: str,
    ) -> tuple[SimpleNamespace, SimpleNamespace]:
        captured_case_types.append(case_type)
        assert db is fake_db
        assert subject_label == "Test submission"
        assert image_bytes.startswith(b"\xff\xd8")
        assert face.det_score == 0.99
        assert content_type == "image/jpeg"
        return (
            SimpleNamespace(
                id=submitted_case_id,
                case_type=case_type.value,
                subject_label=subject_label,
            ),
            SimpleNamespace(id=uuid.uuid4()),
        )

    def fake_search(
        db: object,
        *,
        case: SimpleNamespace,
        face: SimpleNamespace,
        embedding: np.ndarray,
        top_k: int,
    ) -> CaseSearchResult:
        assert db is fake_db
        assert case.id == submitted_case_id
        assert face.id is not None
        assert embedding.shape == (512,)
        assert top_k == 5
        return CaseSearchResult(
            decision="match",
            threshold=0.42,
            results=[
                CaseCandidate(
                    case_id=candidate_case_id,
                    subject_label="Found person submission",
                    score=0.86,
                    image_url="https://images.example.com/candidate.jpg",
                )
            ],
        )

    fake_db = object()
    app = FastAPI()
    app.include_router(cases.router)
    app.dependency_overrides[get_db] = lambda: fake_db
    monkeypatch.setattr(cases, "get_engine", lambda: FakeEngine())
    monkeypatch.setattr(cases, "create_case", fake_create_case)
    monkeypatch.setattr(cases, "search_opposite_cases", fake_search)

    image = np.zeros((16, 16, 3), dtype=np.uint8)
    _, encoded = cv2.imencode(".jpg", image)
    response = TestClient(app).post(
        "/v1/cases",
        data={
            "case_type": "missing",
            "subject_label": "Test submission",
        },
        files={"image": ("person.jpg", encoded.tobytes(), "image/jpeg")},
    )

    assert response.status_code == 201
    assert response.json()["case_id"] == str(submitted_case_id)
    assert response.json()["match"]["results"][0]["case_id"] == str(candidate_case_id)
    assert captured_case_types == [CaseType.missing]


def test_submission_rejects_multiple_faces(monkeypatch) -> None:
    class FakeEngine:
        def detect_all(self, image: np.ndarray) -> list[DetectedFace]:
            return [_detected_face(), _detected_face()]

    fake_db = object()
    app = FastAPI()
    app.include_router(cases.router)
    app.dependency_overrides[get_db] = lambda: fake_db
    monkeypatch.setattr(cases, "get_engine", lambda: FakeEngine())

    image = np.zeros((16, 16, 3), dtype=np.uint8)
    _, encoded = cv2.imencode(".jpg", image)
    response = TestClient(app).post(
        "/v1/cases",
        data={"case_type": "found"},
        files={"image": ("group.jpg", encoded.tobytes(), "image/jpeg")},
    )

    assert response.status_code == 422
    assert response.json()["detail"].startswith("multiple faces detected")
