import asyncio
import uuid
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import cv2
import numpy as np
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app import case_service, reconciliation, storage
from app.auth import require_principal
from app.db import get_db
from app.face_engine import DetectedFace
from app.models import CaseReconciliationState
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


def test_case_submission_requires_authentication() -> None:
    app = FastAPI()
    app.include_router(cases.router)
    app.dependency_overrides[get_db] = lambda: object()

    response = TestClient(app).post("/v1/cases")

    assert response.status_code == 401
    assert response.json()["detail"] == "valid authentication is required"


def test_submission_contract_passes_missing_role_to_remote_case_service(
    monkeypatch,
) -> None:
    submitted_case_id = uuid.uuid4()
    candidate_case_id = uuid.uuid4()
    authenticated_account_id = uuid.uuid4()
    captured_case_types: list[CaseType] = []

    class FakeEngine:
        def detect_all(self, image: np.ndarray) -> list[DetectedFace]:
            assert image.shape == (16, 16, 3)
            return [_detected_face()]

    def fake_create_case_with_faces(
        db: object,
        *,
        case_type: CaseType,
        subject_label: str,
        photos: list[case_service.CasePhoto],
        account_id: uuid.UUID,
    ) -> tuple[SimpleNamespace, list[SimpleNamespace]]:
        captured_case_types.append(case_type)
        assert db is fake_db
        assert subject_label == "Test submission"
        assert len(photos) == 1
        assert photos[0].image_bytes.startswith(b"\xff\xd8")
        assert photos[0].face.det_score == 0.99
        assert photos[0].content_type == "image/jpeg"
        assert account_id == authenticated_account_id
        return (
            SimpleNamespace(
                id=submitted_case_id,
                case_type=case_type.value,
                subject_label=subject_label,
            ),
            [SimpleNamespace(id=uuid.uuid4())],
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
    app.dependency_overrides[require_principal] = lambda: SimpleNamespace(
        account=SimpleNamespace(id=authenticated_account_id)
    )
    engine = FakeEngine()
    monkeypatch.setattr(cases, "get_engine", lambda: engine)
    monkeypatch.setattr(
        cases,
        "create_case_with_faces",
        fake_create_case_with_faces,
    )
    monkeypatch.setattr(cases, "search_opposite_cases", fake_search)
    monkeypatch.setattr(cases, "record_case_upload", lambda *args, **kwargs: None)

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
    assert response.json()["photo_count"] == 1
    assert len(response.json()["qualities"]) == 1
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
    app.dependency_overrides[require_principal] = lambda: SimpleNamespace(
        account=SimpleNamespace(id=uuid.uuid4())
    )
    engine = FakeEngine()
    monkeypatch.setattr(cases, "get_engine", lambda: engine)
    monkeypatch.setattr(
        cases,
        "_record_upload_rejection",
        lambda *args, **kwargs: None,
    )

    image = np.zeros((16, 16, 3), dtype=np.uint8)
    _, encoded = cv2.imencode(".jpg", image)
    response = TestClient(app).post(
        "/v1/cases",
        data={"case_type": "found"},
        files={"image": ("group.jpg", encoded.tobytes(), "image/jpeg")},
    )

    assert response.status_code == 422
    detail = response.json()["detail"]
    assert detail["error"] == "Photo 1 contains more than one person."
    assert detail["photo_index"] == 1
    assert detail["reasons"] == [
        "Choose a photo showing only the person for this case."
    ]


def test_submission_groups_multiple_photos_under_one_case(monkeypatch) -> None:
    submitted_case_id = uuid.uuid4()
    authenticated_account_id = uuid.uuid4()
    candidate_case_id = uuid.uuid4()
    captured_photo_count = 0
    searched_face_ids: list[uuid.UUID] = []

    class FakeEngine:
        def detect_all(self, image: np.ndarray) -> list[DetectedFace]:
            return [_detected_face()]

    def fake_create_case_with_faces(
        db: object,
        *,
        case_type: CaseType,
        subject_label: str,
        photos: list[case_service.CasePhoto],
        account_id: uuid.UUID,
    ) -> tuple[SimpleNamespace, list[SimpleNamespace]]:
        nonlocal captured_photo_count
        captured_photo_count = len(photos)
        assert case_type == CaseType.found
        assert account_id == authenticated_account_id
        return (
            SimpleNamespace(
                id=submitted_case_id,
                case_type=case_type.value,
                subject_label=subject_label,
            ),
            [SimpleNamespace(id=uuid.uuid4()) for _ in photos],
        )

    def fake_search(
        db: object,
        *,
        case: SimpleNamespace,
        face: SimpleNamespace,
        embedding: np.ndarray,
        top_k: int,
    ) -> CaseSearchResult:
        searched_face_ids.append(face.id)
        score = 0.72 + (0.1 * len(searched_face_ids))
        return CaseSearchResult(
            decision="match",
            threshold=0.42,
            results=[
                CaseCandidate(
                    case_id=candidate_case_id,
                    subject_label="Missing person submission",
                    score=score,
                    image_url=f"https://images.example.com/{len(searched_face_ids)}.jpg",
                )
            ],
        )

    fake_db = object()
    app = FastAPI()
    app.include_router(cases.router)
    app.dependency_overrides[get_db] = lambda: fake_db
    app.dependency_overrides[require_principal] = lambda: SimpleNamespace(
        account=SimpleNamespace(id=authenticated_account_id)
    )
    monkeypatch.setattr(cases, "get_engine", lambda: FakeEngine())
    monkeypatch.setattr(
        cases,
        "create_case_with_faces",
        fake_create_case_with_faces,
    )
    monkeypatch.setattr(cases, "search_opposite_cases", fake_search)
    monkeypatch.setattr(cases, "record_case_upload", lambda *args, **kwargs: None)

    image = np.zeros((16, 16, 3), dtype=np.uint8)
    _, encoded = cv2.imencode(".jpg", image)
    payload = encoded.tobytes()
    response = TestClient(app).post(
        "/v1/cases",
        data={"case_type": "found"},
        files=[
            ("images", ("front.jpg", payload, "image/jpeg")),
            ("images", ("profile.jpg", payload, "image/jpeg")),
        ],
    )

    assert response.status_code == 201
    body = response.json()
    assert body["case_id"] == str(submitted_case_id)
    assert body["photo_count"] == 2
    assert len(body["qualities"]) == 2
    assert captured_photo_count == 2
    assert len(searched_face_ids) == 2
    assert len(body["match"]["results"]) == 1
    assert body["match"]["results"][0]["score"] == pytest.approx(0.92)
    assert body["match"]["results"][0]["image_url"].endswith("/2.jpg")


def test_submission_rejects_more_than_five_photos(monkeypatch) -> None:
    fake_db = object()
    app = FastAPI()
    app.include_router(cases.router)
    app.dependency_overrides[get_db] = lambda: fake_db
    app.dependency_overrides[require_principal] = lambda: SimpleNamespace(
        account=SimpleNamespace(id=uuid.uuid4())
    )
    monkeypatch.setattr(
        cases,
        "_record_upload_rejection",
        lambda *args, **kwargs: None,
    )

    image = np.zeros((16, 16, 3), dtype=np.uint8)
    _, encoded = cv2.imencode(".jpg", image)
    response = TestClient(app).post(
        "/v1/cases",
        data={"case_type": "missing"},
        files=[
            ("images", (f"photo-{index}.jpg", encoded.tobytes(), "image/jpeg"))
            for index in range(6)
        ],
    )

    assert response.status_code == 422
    assert response.json()["detail"]["error"] == (
        "A case can contain at most 5 photos."
    )


def test_submission_rejects_an_unclear_photo_with_its_position(monkeypatch) -> None:
    unclear_quality = _quality().model_copy(
        update={
            "passed": False,
            "reasons": ["image too blurry", "face too small"],
        }
    )

    class FakeEngine:
        calls = 0

        def detect_all(self, image: np.ndarray) -> list[DetectedFace]:
            self.calls += 1
            face = _detected_face()
            if self.calls == 2:
                return [
                    DetectedFace(
                        embedding=face.embedding,
                        bbox=face.bbox,
                        det_score=face.det_score,
                        quality=unclear_quality,
                    )
                ]
            return [face]

    fake_db = object()
    app = FastAPI()
    app.include_router(cases.router)
    app.dependency_overrides[get_db] = lambda: fake_db
    app.dependency_overrides[require_principal] = lambda: SimpleNamespace(
        account=SimpleNamespace(id=uuid.uuid4())
    )
    engine = FakeEngine()
    monkeypatch.setattr(cases, "get_engine", lambda: engine)
    monkeypatch.setattr(
        cases,
        "_record_upload_rejection",
        lambda *args, **kwargs: None,
    )

    image = np.zeros((16, 16, 3), dtype=np.uint8)
    _, encoded = cv2.imencode(".jpg", image)
    payload = encoded.tobytes()
    response = TestClient(app).post(
        "/v1/cases",
        data={"case_type": "missing"},
        files=[
            ("images", ("clear.jpg", payload, "image/jpeg")),
            ("images", ("blurry.jpg", payload, "image/jpeg")),
        ],
    )

    assert response.status_code == 422
    assert response.json()["detail"] == {
        "error": "Photo 2 is not clear enough for reliable matching.",
        "photo_index": 2,
        "reasons": ["image too blurry", "face too small"],
    }


def test_reconciliation_processes_new_faces_and_advances_the_cursor(
    monkeypatch,
) -> None:
    first_created_at = datetime.now(UTC)
    first_face = SimpleNamespace(
        id=uuid.uuid4(),
        created_at=first_created_at,
        embedding=np.ones(512, dtype=np.float32),
        case=SimpleNamespace(case_type="missing"),
    )
    second_face = SimpleNamespace(
        id=uuid.uuid4(),
        created_at=first_created_at + timedelta(seconds=1),
        embedding=np.ones(512, dtype=np.float32),
        case=SimpleNamespace(case_type="found"),
    )
    state_holder: dict[str, CaseReconciliationState | None] = {"state": None}
    commits: list[None] = []

    class FakeDb:
        def get(
            self,
            model: type[CaseReconciliationState],
            name: str,
        ) -> CaseReconciliationState | None:
            assert model is CaseReconciliationState
            assert name == "case-matching"
            return state_holder["state"]

        def add(self, value: CaseReconciliationState) -> None:
            if isinstance(value, CaseReconciliationState):
                state_holder["state"] = value

        def commit(self) -> None:
            commits.append(None)

    batches = iter([[first_face, second_face], []])
    searched_case_types: list[CaseType] = []
    persisted_face_ids: list[uuid.UUID] = []
    monkeypatch.setattr(
        reconciliation,
        "get_settings",
        lambda: SimpleNamespace(reconciliation_top_k=12),
    )
    monkeypatch.setattr(
        reconciliation,
        "_pending_faces",
        lambda db, state: next(batches),
    )

    def fake_find(
        db: object,
        *,
        case_type: CaseType,
        embedding: np.ndarray,
        top_k: int,
    ) -> list[case_service.CaseHit]:
        searched_case_types.append(case_type)
        assert embedding.shape == (512,)
        assert top_k == 12
        return []

    def fake_persist(
        db: object,
        *,
        case: object,
        face: object,
        hits: list[case_service.CaseHit],
    ) -> None:
        persisted_face_ids.append(face.id)
        assert hits == []

    monkeypatch.setattr(reconciliation, "find_opposite_case_hits", fake_find)
    monkeypatch.setattr(reconciliation, "persist_case_hits", fake_persist)

    processed = reconciliation.reconcile_pending_case_faces(FakeDb())

    assert processed == 2
    assert searched_case_types == [CaseType.missing, CaseType.found]
    assert persisted_face_ids == [first_face.id, second_face.id]
    assert state_holder["state"] is not None
    assert state_holder["state"].last_face_created_at == second_face.created_at
    assert state_holder["state"].last_face_id == second_face.id
    assert len(commits) == 3


def test_reconciliation_loop_runs_immediately_then_waits_15_minutes(
    monkeypatch,
) -> None:
    runs: list[None] = []
    intervals: list[int] = []

    def fake_run() -> int:
        runs.append(None)
        return 0

    async def fake_to_thread(function: object) -> int:
        return function()

    async def fake_sleep(seconds: int) -> None:
        intervals.append(seconds)
        raise asyncio.CancelledError

    monkeypatch.setattr(
        reconciliation,
        "get_settings",
        lambda: SimpleNamespace(
            reconciliation_interval_seconds=900,
        ),
    )
    monkeypatch.setattr(reconciliation, "run_reconciliation_once", fake_run)
    monkeypatch.setattr(reconciliation.asyncio, "to_thread", fake_to_thread)
    monkeypatch.setattr(reconciliation.asyncio, "sleep", fake_sleep)

    with pytest.raises(asyncio.CancelledError):
        asyncio.run(reconciliation.reconciliation_loop())

    assert len(runs) == 1
    assert intervals == [900]
