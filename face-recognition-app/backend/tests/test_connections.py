import uuid
from datetime import UTC, datetime
from types import SimpleNamespace

import pytest
from fastapi import HTTPException

from app import connection_service
from app.models import (
    Account,
    AccountNotification,
    CaseFace,
    CaseMatch,
    CaseRecord,
    MatchConnection,
)


class FakeStore:
    def presigned_url(self, key: str) -> str:
        return f"https://images.example.com/{key}"


class FakeDb:
    def __init__(
        self,
        objects: list[object],
        notification: AccountNotification,
    ) -> None:
        self.objects = {(type(value), value.id): value for value in objects}
        self.notification = notification
        self.audit_events: list[object] = []

    def get(self, model: type[object], object_id: uuid.UUID) -> object | None:
        return self.objects.get((model, object_id))

    def scalar(self, statement: object) -> AccountNotification:
        return self.notification

    def add(self, value: object) -> None:
        self.audit_events.append(value)

    def commit(self) -> None:
        return None

    def refresh(self, value: object) -> None:
        return None


@pytest.fixture
def connection_fixture(
    monkeypatch: pytest.MonkeyPatch,
) -> tuple[FakeDb, Account, Account, MatchConnection]:
    monkeypatch.setattr(
        connection_service,
        "get_settings",
        lambda: SimpleNamespace(
            meeting_code_secret="meeting-code-test-secret",
            meeting_code_ttl_seconds=900,
        ),
    )
    monkeypatch.setattr(
        connection_service,
        "get_store",
        lambda: FakeStore(),
    )
    missing_account = Account(
        id=uuid.uuid4(),
        phone_number="+919000000001",
        is_active=True,
    )
    found_account = Account(
        id=uuid.uuid4(),
        phone_number="+919000000002",
        is_active=True,
    )
    missing_case = CaseRecord(
        id=uuid.uuid4(),
        case_type="missing",
        subject_label="Missing case",
        status="active",
    )
    found_case = CaseRecord(
        id=uuid.uuid4(),
        case_type="found",
        subject_label="Found case",
        status="active",
    )
    missing_face = CaseFace(
        id=uuid.uuid4(),
        case_id=missing_case.id,
        case_type="missing",
        image_key="missing.jpg",
        bbox=[0, 0, 10, 10],
        det_score=0.9,
        model_tag="test",
        embedding=[0.0] * 512,
    )
    found_face = CaseFace(
        id=uuid.uuid4(),
        case_id=found_case.id,
        case_type="found",
        image_key="found.jpg",
        bbox=[0, 0, 10, 10],
        det_score=0.9,
        model_tag="test",
        embedding=[0.0] * 512,
    )
    match = CaseMatch(
        id=uuid.uuid4(),
        missing_case_id=missing_case.id,
        found_case_id=found_case.id,
        missing_face_id=missing_face.id,
        found_face_id=found_face.id,
        score=0.81,
        decision="match",
        model_tag="test",
    )
    connection = MatchConnection(
        id=uuid.uuid4(),
        case_match_id=match.id,
        missing_account_id=missing_account.id,
        found_account_id=found_account.id,
        status="pending_consent",
        created_at=datetime.now(UTC),
    )
    notification = AccountNotification(
        id=uuid.uuid4(),
        account_id=missing_account.id,
        connection_id=connection.id,
        event_type="match_found",
    )
    db = FakeDb(
        [
            missing_account,
            found_account,
            missing_case,
            found_case,
            missing_face,
            found_face,
            match,
            connection,
        ],
        notification,
    )
    return db, missing_account, found_account, connection


def test_mutual_consent_issues_distinct_short_lived_codes(
    connection_fixture: tuple[FakeDb, Account, Account, MatchConnection],
) -> None:
    db, missing_account, found_account, connection = connection_fixture

    missing_pending = connection_service.consent_to_connection(
        db,
        connection_id=connection.id,
        account=missing_account,
    )
    assert missing_pending.my_consented is True
    assert missing_pending.other_consented is False
    assert missing_pending.meeting_code is None

    found_ready = connection_service.consent_to_connection(
        db,
        connection_id=connection.id,
        account=found_account,
    )
    missing_ready = connection_service.consent_to_connection(
        db,
        connection_id=connection.id,
        account=missing_account,
    )

    assert found_ready.status == "ready_to_meet"
    assert found_ready.meeting_code is not None
    assert missing_ready.meeting_code is not None
    assert found_ready.meeting_code != missing_ready.meeting_code
    assert found_ready.meeting_code_expires_at is not None


def test_each_party_verifies_the_other_partys_code_once(
    connection_fixture: tuple[FakeDb, Account, Account, MatchConnection],
) -> None:
    db, missing_account, found_account, connection = connection_fixture
    connection_service.consent_to_connection(
        db,
        connection_id=connection.id,
        account=missing_account,
    )
    found_ready = connection_service.consent_to_connection(
        db,
        connection_id=connection.id,
        account=found_account,
    )
    missing_ready = connection_service.consent_to_connection(
        db,
        connection_id=connection.id,
        account=missing_account,
    )
    missing_verified = connection_service.verify_peer_meeting_code(
        db,
        connection_id=connection.id,
        account=missing_account,
        code=found_ready.meeting_code or "",
    )
    found_verified = connection_service.verify_peer_meeting_code(
        db,
        connection_id=connection.id,
        account=found_account,
        code=missing_ready.meeting_code or "",
    )

    assert missing_verified.my_verified_peer is True
    assert found_verified.status == "verified"
    assert found_verified.my_verified_peer is True
    assert found_verified.other_verified_peer is True
    assert found_verified.meeting_code is None


def test_replayed_meeting_code_is_rejected_and_audited(
    connection_fixture: tuple[FakeDb, Account, Account, MatchConnection],
) -> None:
    db, missing_account, found_account, connection = connection_fixture
    connection_service.consent_to_connection(
        db,
        connection_id=connection.id,
        account=missing_account,
    )
    connection_service.consent_to_connection(
        db,
        connection_id=connection.id,
        account=found_account,
    )
    missing_ready = connection_service.consent_to_connection(
        db,
        connection_id=connection.id,
        account=missing_account,
    )
    connection_service.verify_peer_meeting_code(
        db,
        connection_id=connection.id,
        account=found_account,
        code=missing_ready.meeting_code or "",
    )

    with pytest.raises(HTTPException) as error:
        connection_service.verify_peer_meeting_code(
            db,
            connection_id=connection.id,
            account=found_account,
            code=missing_ready.meeting_code or "",
        )

    assert error.value.status_code == 409
    assert db.audit_events[-1].event_type == "meeting_code_replay_rejected"


def test_incorrect_code_is_rejected_and_audited(
    connection_fixture: tuple[FakeDb, Account, Account, MatchConnection],
) -> None:
    db, missing_account, found_account, connection = connection_fixture
    connection_service.consent_to_connection(
        db,
        connection_id=connection.id,
        account=missing_account,
    )
    connection_service.consent_to_connection(
        db,
        connection_id=connection.id,
        account=found_account,
    )

    with pytest.raises(HTTPException) as error:
        connection_service.verify_peer_meeting_code(
            db,
            connection_id=connection.id,
            account=missing_account,
            code="999999",
        )

    assert error.value.status_code == 400
    assert db.audit_events[-1].event_type == "meeting_code_rejected"


def test_withdrawing_consent_revokes_meeting_codes(
    connection_fixture: tuple[FakeDb, Account, Account, MatchConnection],
) -> None:
    db, missing_account, found_account, connection = connection_fixture
    connection_service.consent_to_connection(
        db,
        connection_id=connection.id,
        account=missing_account,
    )
    connection_service.consent_to_connection(
        db,
        connection_id=connection.id,
        account=found_account,
    )

    withdrawn = connection_service.withdraw_connection_consent(
        db,
        connection_id=connection.id,
        account=missing_account,
    )

    assert withdrawn.status == "pending_consent"
    assert withdrawn.my_consented is False
    assert withdrawn.other_consented is True
    assert withdrawn.meeting_code is None
    assert connection.meeting_nonce is None
    assert db.audit_events[-1].event_type == "connection_consent_withdrawn"


def test_non_participant_cannot_access_connection(
    connection_fixture: tuple[FakeDb, Account, Account, MatchConnection],
) -> None:
    db, _, _, connection = connection_fixture
    stranger = Account(
        id=uuid.uuid4(),
        phone_number="+919000000003",
        is_active=True,
    )

    with pytest.raises(HTTPException) as error:
        connection_service.consent_to_connection(
            db,
            connection_id=connection.id,
            account=stranger,
        )

    assert error.value.status_code == 404
