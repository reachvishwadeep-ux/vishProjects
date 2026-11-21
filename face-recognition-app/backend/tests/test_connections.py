import uuid
from datetime import UTC, datetime
from types import SimpleNamespace

import pytest
from fastapi import HTTPException

from app import connection_service
from app.models import (
    Account,
    AccountNotification,
    AuditEvent,
    CaseAccount,
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
    monkeypatch.setattr(
        connection_service,
        "record_repeated_failure_risk",
        lambda *args, **kwargs: None,
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


def test_new_match_audit_links_both_photos_and_matching_source(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    missing_account_id = uuid.uuid4()
    found_account_id = uuid.uuid4()
    match = CaseMatch(
        id=uuid.uuid4(),
        missing_case_id=uuid.uuid4(),
        found_case_id=uuid.uuid4(),
        missing_face_id=uuid.uuid4(),
        found_face_id=uuid.uuid4(),
        score=0.84,
        decision="match",
        model_tag="buffalo_l",
    )
    connection_id = uuid.uuid4()
    monkeypatch.setattr(
        connection_service,
        "get_settings",
        lambda: SimpleNamespace(match_alert_sms_enabled=True),
    )

    class MatchDb:
        def __init__(self) -> None:
            self.events: list[AuditEvent] = []

        def get(self, model: type[object], object_id: uuid.UUID) -> object | None:
            if model is CaseAccount and object_id == match.missing_case_id:
                return CaseAccount(
                    case_id=match.missing_case_id,
                    account_id=missing_account_id,
                )
            if model is CaseAccount and object_id == match.found_case_id:
                return CaseAccount(
                    case_id=match.found_case_id,
                    account_id=found_account_id,
                )
            return None

        def scalar(self, statement: object) -> uuid.UUID:
            return connection_id

        def execute(self, statement: object) -> None:
            return None

        def add(self, value: AuditEvent) -> None:
            self.events.append(value)

    db = MatchDb()

    alerts = connection_service.ensure_connection_for_match(
        db,
        match,
        source="reconciliation",
    )

    event = db.events[0]
    assert event.event_type == "case_match_confirmed"
    assert event.event_data["missing_face_id"] == str(match.missing_face_id)
    assert event.event_data["found_face_id"] == str(match.found_face_id)
    assert event.event_data["source"] == "reconciliation"
    assert {(alert.connection_id, alert.account_id) for alert in alerts} == {
        (connection_id, missing_account_id),
        (connection_id, found_account_id),
    }


def test_existing_connection_does_not_send_duplicate_sms_alerts(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    missing_account_id = uuid.uuid4()
    found_account_id = uuid.uuid4()
    match = CaseMatch(
        id=uuid.uuid4(),
        missing_case_id=uuid.uuid4(),
        found_case_id=uuid.uuid4(),
        missing_face_id=uuid.uuid4(),
        found_face_id=uuid.uuid4(),
        score=0.84,
        decision="match",
        model_tag="buffalo_l",
    )
    connection_id = uuid.uuid4()
    sent_events = [
        AuditEvent(
            account_id=account_id,
            event_type="match_sms_pending",
            event_data={"connection_id": str(connection_id)},
        )
        for account_id in (missing_account_id, found_account_id)
    ] + [
        AuditEvent(
            account_id=account_id,
            event_type="match_sms_sent",
            event_data={"connection_id": str(connection_id)},
        )
        for account_id in (missing_account_id, found_account_id)
    ]
    monkeypatch.setattr(
        connection_service,
        "get_settings",
        lambda: SimpleNamespace(match_alert_sms_enabled=True),
    )

    class ExistingConnectionDb:
        def __init__(self) -> None:
            self.scalar_calls = 0
            self.events: list[AuditEvent] = []

        def get(self, model: type[object], object_id: uuid.UUID) -> object | None:
            if model is CaseAccount and object_id == match.missing_case_id:
                return CaseAccount(
                    case_id=match.missing_case_id,
                    account_id=missing_account_id,
                )
            if model is CaseAccount and object_id == match.found_case_id:
                return CaseAccount(
                    case_id=match.found_case_id,
                    account_id=found_account_id,
                )
            return None

        def scalar(self, statement: object) -> uuid.UUID | None:
            self.scalar_calls += 1
            return None if self.scalar_calls == 1 else connection_id

        def execute(self, statement: object) -> None:
            return None

        def scalars(self, statement: object) -> SimpleNamespace:
            return SimpleNamespace(all=lambda: sent_events)

        def add(self, value: AuditEvent) -> None:
            self.events.append(value)

    db = ExistingConnectionDb()

    alerts = connection_service.ensure_connection_for_match(
        db,
        match,
        source="reconciliation",
    )

    assert alerts == []
    assert db.events == []


def test_failed_match_sms_is_retried_during_reconciliation(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    missing_account_id = uuid.uuid4()
    found_account_id = uuid.uuid4()
    match = CaseMatch(
        id=uuid.uuid4(),
        missing_case_id=uuid.uuid4(),
        found_case_id=uuid.uuid4(),
        missing_face_id=uuid.uuid4(),
        found_face_id=uuid.uuid4(),
        score=0.84,
        decision="match",
        model_tag="buffalo_l",
    )
    connection_id = uuid.uuid4()
    pending_events = [
        AuditEvent(
            account_id=account_id,
            event_type="match_sms_pending",
            event_data={"connection_id": str(connection_id)},
        )
        for account_id in (missing_account_id, found_account_id)
    ]
    pending_events.append(
        AuditEvent(
            account_id=missing_account_id,
            event_type="match_sms_delivery_failed",
            event_data={"connection_id": str(connection_id)},
        )
    )
    monkeypatch.setattr(
        connection_service,
        "get_settings",
        lambda: SimpleNamespace(match_alert_sms_enabled=True),
    )

    class RetryDb:
        def __init__(self) -> None:
            self.scalar_calls = 0

        def get(self, model: type[object], object_id: uuid.UUID) -> object | None:
            if model is CaseAccount and object_id == match.missing_case_id:
                return CaseAccount(
                    case_id=match.missing_case_id,
                    account_id=missing_account_id,
                )
            if model is CaseAccount and object_id == match.found_case_id:
                return CaseAccount(
                    case_id=match.found_case_id,
                    account_id=found_account_id,
                )
            return None

        def scalar(self, statement: object) -> uuid.UUID | None:
            self.scalar_calls += 1
            return None if self.scalar_calls == 1 else connection_id

        def execute(self, statement: object) -> None:
            return None

        def scalars(self, statement: object) -> SimpleNamespace:
            return SimpleNamespace(all=lambda: pending_events)

        def add(self, value: AuditEvent) -> None:
            return None

    alerts = connection_service.ensure_connection_for_match(
        RetryDb(),
        match,
        source="reconciliation",
    )

    assert {alert.account_id for alert in alerts} == {
        missing_account_id,
        found_account_id,
    }


def test_match_sms_alerts_remain_disabled_by_default(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    class DisabledDb:
        def get(self, model: type[object], object_id: uuid.UUID) -> object:
            raise AssertionError("disabled alerts must not load account data")

        def commit(self) -> None:
            raise AssertionError("disabled alerts must not create audit data")

    monkeypatch.setattr(
        connection_service,
        "get_settings",
        lambda: SimpleNamespace(match_alert_sms_enabled=False),
    )

    connection_service.send_match_sms_alerts(
        DisabledDb(),
        [
            connection_service.MatchSmsAlert(
                connection_id=uuid.uuid4(),
                account_id=uuid.uuid4(),
            )
        ],
    )


def test_match_sms_alerts_are_idempotent_and_privacy_safe(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    connection_id = uuid.uuid4()
    accounts = [
        Account(
            id=uuid.uuid4(),
            phone_number="+919000000001",
            is_active=True,
        ),
        Account(
            id=uuid.uuid4(),
            phone_number="+919000000002",
            is_active=True,
        ),
    ]
    sent: list[tuple[str, str]] = []

    class AlertDb:
        def __init__(self) -> None:
            self.events: list[AuditEvent] = []
            self.commits = 0

        def get(self, model: type[object], object_id: uuid.UUID) -> object | None:
            if model is Account:
                return next(
                    (account for account in accounts if account.id == object_id),
                    None,
                )
            return None

        def add(self, value: AuditEvent) -> None:
            self.events.append(value)

        def commit(self) -> None:
            self.commits += 1

    monkeypatch.setattr(
        connection_service,
        "get_settings",
        lambda: SimpleNamespace(match_alert_sms_enabled=True),
    )

    def send(phone_number: str, *, idempotency_key: str, settings: object) -> str:
        sent.append((phone_number, idempotency_key))
        return f"provider-{len(sent)}"

    monkeypatch.setattr(connection_service, "send_telnyx_match_alert", send)
    db = AlertDb()
    alerts = [
        connection_service.MatchSmsAlert(
            connection_id=connection_id,
            account_id=account.id,
        )
        for account in accounts
    ]

    connection_service.send_match_sms_alerts(db, alerts)

    assert sent == [
        (
            accounts[0].phone_number,
            str(
                uuid.uuid5(
                    uuid.NAMESPACE_URL,
                    f"reunitenow:match-alert:{connection_id}:{accounts[0].id}",
                )
            ),
        ),
        (
            accounts[1].phone_number,
            str(
                uuid.uuid5(
                    uuid.NAMESPACE_URL,
                    f"reunitenow:match-alert:{connection_id}:{accounts[1].id}",
                )
            ),
        ),
    ]
    assert [event.event_type for event in db.events] == [
        "match_sms_sent",
        "match_sms_sent",
    ]
    assert all("phone" not in str(event.event_data).lower() for event in db.events)
    assert db.commits == 1


def test_match_sms_failure_does_not_block_other_alerts(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    connection_id = uuid.uuid4()
    accounts = [
        Account(
            id=uuid.uuid4(),
            phone_number="+919000000001",
            is_active=True,
        ),
        Account(
            id=uuid.uuid4(),
            phone_number="+919000000002",
            is_active=True,
        ),
    ]

    class AlertDb:
        def __init__(self) -> None:
            self.events: list[AuditEvent] = []

        def get(self, model: type[object], object_id: uuid.UUID) -> object | None:
            if model is Account:
                return next(
                    (account for account in accounts if account.id == object_id),
                    None,
                )
            return None

        def add(self, value: AuditEvent) -> None:
            self.events.append(value)

        def commit(self) -> None:
            return None

    monkeypatch.setattr(
        connection_service,
        "get_settings",
        lambda: SimpleNamespace(match_alert_sms_enabled=True),
    )
    calls = 0

    def send(phone_number: str, *, idempotency_key: str, settings: object) -> str:
        nonlocal calls
        calls += 1
        if calls == 1:
            raise connection_service.MatchAlertDeliveryError("provider failure")
        return "provider-success"

    monkeypatch.setattr(connection_service, "send_telnyx_match_alert", send)
    db = AlertDb()

    connection_service.send_match_sms_alerts(
        db,
        [
            connection_service.MatchSmsAlert(
                connection_id=connection_id,
                account_id=account.id,
            )
            for account in accounts
        ],
    )

    assert calls == 2
    assert [event.event_type for event in db.events] == [
        "match_sms_delivery_failed",
        "match_sms_sent",
    ]


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


def test_connection_ids_map_each_matched_case_for_the_participant() -> None:
    submitted_case_id = uuid.uuid4()
    found_case_id = uuid.uuid4()
    other_missing_case_id = uuid.uuid4()
    first_connection_id = uuid.uuid4()
    second_connection_id = uuid.uuid4()

    class RowsDb:
        def execute(self, statement: object) -> SimpleNamespace:
            return SimpleNamespace(
                all=lambda: [
                    (submitted_case_id, found_case_id, first_connection_id),
                    (other_missing_case_id, submitted_case_id, second_connection_id),
                ]
            )

    assert connection_service.connection_ids_for_case(
        RowsDb(),
        case_id=submitted_case_id,
        account_id=uuid.uuid4(),
    ) == {
        found_case_id: first_connection_id,
        other_missing_case_id: second_connection_id,
    }
