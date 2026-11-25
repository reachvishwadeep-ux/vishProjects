import uuid
from datetime import UTC, datetime
from types import SimpleNamespace

import pytest
from fastapi import HTTPException

from app import connection_service
from app.models import (
    Account,
    AccountNotification,
    AppInstallation,
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


class MatchHistoryDb:
    def __init__(
        self,
        objects: list[object],
        matches: list[CaseMatch],
        connection: MatchConnection | None = None,
    ) -> None:
        self.objects = {
            (type(value), getattr(value, "id", getattr(value, "case_id", None))): value
            for value in objects
        }
        self.matches = matches
        self.connection = connection

    def get(self, model: type[object], object_id: uuid.UUID) -> object | None:
        return self.objects.get((model, object_id))

    def scalars(self, statement: object) -> SimpleNamespace:
        return SimpleNamespace(all=lambda: self.matches)

    def scalar(self, statement: object) -> MatchConnection | None:
        return self.connection


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


def test_match_history_includes_same_account_matches_without_connections(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    account_id = uuid.uuid4()
    missing_case = CaseRecord(
        id=uuid.uuid4(),
        case_type="missing",
        subject_label="Earlier missing report",
        status="active",
    )
    found_case = CaseRecord(
        id=uuid.uuid4(),
        case_type="found",
        subject_label="Recent found report",
        status="active",
    )
    found_face = CaseFace(
        id=uuid.uuid4(),
        case_id=found_case.id,
        case_type="found",
        image_key="found-history.jpg",
        bbox=[0, 0, 10, 10],
        det_score=0.9,
        model_tag="test",
        embedding=[0.0] * 512,
    )
    created_at = datetime.now(UTC)
    match = CaseMatch(
        id=uuid.uuid4(),
        missing_case_id=missing_case.id,
        found_case_id=found_case.id,
        missing_face_id=uuid.uuid4(),
        found_face_id=found_face.id,
        score=0.78,
        decision="match",
        model_tag="test",
        created_at=created_at,
        updated_at=created_at,
    )
    db = MatchHistoryDb(
        [
            CaseAccount(case_id=missing_case.id, account_id=account_id),
            CaseAccount(case_id=found_case.id, account_id=account_id),
            missing_case,
            found_case,
            found_face,
        ],
        [match],
    )
    monkeypatch.setattr(connection_service, "get_store", lambda: FakeStore())

    response = connection_service.list_match_history(
        db,
        Account(id=account_id, phone_number="+919000000001", is_active=True),
    )

    assert len(response.results) == 1
    result = response.results[0]
    assert result.role.value == "both"
    assert result.same_account is True
    assert result.connection_id is None
    assert result.missing_subject_label == "Earlier missing report"
    assert result.found_subject_label == "Recent found report"
    assert result.image_url == "https://images.example.com/found-history.jpg"


def test_match_history_links_cross_account_secure_connection(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    missing_account_id = uuid.uuid4()
    found_account_id = uuid.uuid4()
    missing_case = CaseRecord(
        id=uuid.uuid4(),
        case_type="missing",
        subject_label="Missing report",
        status="active",
    )
    found_case = CaseRecord(
        id=uuid.uuid4(),
        case_type="found",
        subject_label="Found report",
        status="active",
    )
    found_face = CaseFace(
        id=uuid.uuid4(),
        case_id=found_case.id,
        case_type="found",
        image_key="found-peer.jpg",
        bbox=[0, 0, 10, 10],
        det_score=0.9,
        model_tag="test",
        embedding=[0.0] * 512,
    )
    created_at = datetime.now(UTC)
    match = CaseMatch(
        id=uuid.uuid4(),
        missing_case_id=missing_case.id,
        found_case_id=found_case.id,
        missing_face_id=uuid.uuid4(),
        found_face_id=found_face.id,
        score=0.82,
        decision="match",
        model_tag="test",
        created_at=created_at,
        updated_at=created_at,
    )
    connection = MatchConnection(
        id=uuid.uuid4(),
        case_match_id=match.id,
        missing_account_id=missing_account_id,
        found_account_id=found_account_id,
        status="pending_consent",
        created_at=created_at,
    )
    db = MatchHistoryDb(
        [
            CaseAccount(
                case_id=missing_case.id,
                account_id=missing_account_id,
            ),
            CaseAccount(
                case_id=found_case.id,
                account_id=found_account_id,
            ),
            missing_case,
            found_case,
            found_face,
        ],
        [match],
        connection,
    )
    monkeypatch.setattr(connection_service, "get_store", lambda: FakeStore())

    response = connection_service.list_match_history(
        db,
        Account(
            id=missing_account_id,
            phone_number="+919000000001",
            is_active=True,
        ),
    )

    result = response.results[0]
    assert result.role.value == "missing"
    assert result.same_account is False
    assert result.connection_id == connection.id
    assert result.connection_status == "pending_consent"


def test_mutual_consent_connects_without_meeting_codes(
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

    found_connected = connection_service.consent_to_connection(
        db,
        connection_id=connection.id,
        account=found_account,
    )
    missing_connected = connection_service.consent_to_connection(
        db,
        connection_id=connection.id,
        account=missing_account,
    )

    assert found_connected.status == "connected"
    assert missing_connected.status == "connected"
    assert found_connected.meeting_code is None
    assert missing_connected.meeting_code is None
    assert found_connected.meeting_code_expires_at is None
    assert connection.meeting_nonce is None
    assert connection.meeting_code_expires_at is None


def test_phone_number_is_exposed_only_after_both_accounts_accept_sharing(
    connection_fixture: tuple[FakeDb, Account, Account, MatchConnection],
) -> None:
    db, missing_account, found_account, connection = connection_fixture

    private = connection_service._connection_out(
        db,
        connection,
        missing_account.id,
    )
    assert private.other_phone_number is None
    assert private.my_contact_sharing_consented is False
    assert private.other_contact_sharing_consented is False

    missing_account.contact_sharing_consented_at = datetime.now(UTC)
    one_sided = connection_service._connection_out(
        db,
        connection,
        missing_account.id,
    )
    assert one_sided.other_phone_number is None
    assert one_sided.my_contact_sharing_consented is True
    assert one_sided.other_contact_sharing_consented is False

    found_account.contact_sharing_consented_at = datetime.now(UTC)
    connection.status = "connected"
    shared = connection_service._connection_out(
        db,
        connection,
        missing_account.id,
    )
    assert shared.other_phone_number == found_account.phone_number
    assert shared.my_contact_sharing_consented is True
    assert shared.other_contact_sharing_consented is True


def test_meeting_code_renewal_is_disabled(
    connection_fixture: tuple[FakeDb, Account, Account, MatchConnection],
) -> None:
    db, missing_account, _, connection = connection_fixture

    with pytest.raises(HTTPException) as error:
        connection_service.renew_meeting_codes(
            db,
            connection_id=connection.id,
            account=missing_account,
        )

    assert error.value.status_code == 410
    assert error.value.detail == "meeting-code verification is no longer available"


def test_meeting_code_verification_is_disabled(
    connection_fixture: tuple[FakeDb, Account, Account, MatchConnection],
) -> None:
    db, missing_account, _, connection = connection_fixture

    with pytest.raises(HTTPException) as error:
        connection_service.verify_peer_meeting_code(
            db,
            connection_id=connection.id,
            account=missing_account,
            code="999999",
        )

    assert error.value.status_code == 410
    assert error.value.detail == "meeting-code verification is no longer available"


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
        lambda: SimpleNamespace(push_notifications_enabled=False),
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
    assert alerts == []


def test_new_match_queues_push_for_active_installations(
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
    installations = [
        AppInstallation(
            id=uuid.uuid4(),
            account_id=account_id,
            platform="ios",
            app_version="1.0.0",
            build_number="3",
            push_fid=f"fid-{account_id}",
            push_enabled=True,
            is_active=True,
        )
        for account_id in (missing_account_id, found_account_id)
    ]
    monkeypatch.setattr(
        connection_service,
        "get_settings",
        lambda: SimpleNamespace(push_notifications_enabled=True),
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

        def scalars(self, statement: object) -> SimpleNamespace:
            return SimpleNamespace(all=lambda: installations)

        def add(self, value: AuditEvent) -> None:
            self.events.append(value)

    db = MatchDb()

    alerts = connection_service.ensure_connection_for_match(
        db,
        match,
        source="reconciliation",
    )

    assert {alert.installation_id for alert in alerts} == {
        installation.id for installation in installations
    }
    pending = [event for event in db.events if event.event_type == "match_push_pending"]
    assert len(pending) == 2
    assert all(
        installation.push_fid not in str(event.event_data)
        for event in pending
        for installation in installations
    )


def test_existing_connection_does_not_duplicate_sent_push(
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
    installation_ids = (uuid.uuid4(), uuid.uuid4())
    completed_events = [
        AuditEvent(
            account_id=account_id,
            event_type="match_push_pending",
            event_data={
                "connection_id": str(connection_id),
                "installation_id": str(installation_id),
            },
        )
        for account_id, installation_id in zip(
            (missing_account_id, found_account_id),
            installation_ids,
            strict=True,
        )
    ] + [
        AuditEvent(
            account_id=account_id,
            event_type="match_push_sent",
            event_data={
                "connection_id": str(connection_id),
                "installation_id": str(installation_id),
            },
        )
        for account_id, installation_id in zip(
            (missing_account_id, found_account_id),
            installation_ids,
            strict=True,
        )
    ]
    monkeypatch.setattr(
        connection_service,
        "get_settings",
        lambda: SimpleNamespace(push_notifications_enabled=True),
    )

    class ExistingConnectionDb:
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
            return SimpleNamespace(all=lambda: completed_events)

        def add(self, value: AuditEvent) -> None:
            return None

    alerts = connection_service.ensure_connection_for_match(
        ExistingConnectionDb(),
        match,
        source="reconciliation",
    )

    assert alerts == []


def test_failed_match_push_is_retried_during_reconciliation(
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
    installation_id = uuid.uuid4()
    pending_events = [
        AuditEvent(
            account_id=missing_account_id,
            event_type="match_push_pending",
            event_data={
                "connection_id": str(connection_id),
                "installation_id": str(installation_id),
            },
        ),
        AuditEvent(
            account_id=missing_account_id,
            event_type="match_push_delivery_failed",
            event_data={
                "connection_id": str(connection_id),
                "installation_id": str(installation_id),
            },
        ),
    ]

    monkeypatch.setattr(
        connection_service,
        "get_settings",
        lambda: SimpleNamespace(push_notifications_enabled=True),
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

    assert alerts == [
        connection_service.MatchPushAlert(
            connection_id=connection_id,
            account_id=missing_account_id,
            installation_id=installation_id,
        )
    ]


def test_match_push_alerts_remain_disabled_by_default(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    class DisabledDb:
        def get(self, model: type[object], object_id: uuid.UUID) -> object:
            raise AssertionError("disabled alerts must not load installation data")

        def commit(self) -> None:
            raise AssertionError("disabled alerts must not create audit data")

    monkeypatch.setattr(
        connection_service,
        "get_settings",
        lambda: SimpleNamespace(push_notifications_enabled=False),
    )

    connection_service.send_match_push_alerts(
        DisabledDb(),
        [
            connection_service.MatchPushAlert(
                connection_id=uuid.uuid4(),
                account_id=uuid.uuid4(),
                installation_id=uuid.uuid4(),
            )
        ],
    )


def test_match_push_success_and_invalid_fid_are_audited_safely(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    connection_id = uuid.uuid4()
    account_id = uuid.uuid4()
    installations = [
        AppInstallation(
            id=uuid.uuid4(),
            account_id=account_id,
            platform="ios",
            app_version="1.0.0",
            build_number="3",
            push_fid="valid-fid",
            push_enabled=True,
            is_active=True,
        ),
        AppInstallation(
            id=uuid.uuid4(),
            account_id=account_id,
            platform="android",
            app_version="1.0.0",
            build_number="3",
            push_fid="invalid-fid",
            push_enabled=True,
            is_active=True,
        ),
    ]
    sent: list[tuple[str, str]] = []

    class AlertDb:
        def __init__(self) -> None:
            self.events: list[AuditEvent] = []
            self.commits = 0

        def get(self, model: type[object], object_id: uuid.UUID) -> object | None:
            if model is AppInstallation:
                return next(
                    (
                        installation
                        for installation in installations
                        if installation.id == object_id
                    ),
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
        lambda: SimpleNamespace(push_notifications_enabled=True),
    )

    def send(fid: str, *, connection_id: str, settings: object) -> str:
        sent.append((fid, connection_id))
        if fid == "invalid-fid":
            raise connection_service.InvalidPushFidError("invalid")
        return "provider-success"

    monkeypatch.setattr(connection_service, "send_firebase_match_alert", send)
    db = AlertDb()

    connection_service.send_match_push_alerts(
        db,
        [
            connection_service.MatchPushAlert(
                connection_id=connection_id,
                account_id=account_id,
                installation_id=installation.id,
            )
            for installation in installations
        ],
    )

    assert sent == [
        ("valid-fid", str(connection_id)),
        ("invalid-fid", str(connection_id)),
    ]
    assert [event.event_type for event in db.events] == [
        "match_push_sent",
        "match_push_delivery_skipped",
    ]
    assert all(
        installation.push_fid not in str(event.event_data)
        for event in db.events
        for installation in installations
        if installation.push_fid
    )
    assert installations[1].push_fid is None
    assert installations[1].push_enabled is False
    assert db.commits == 1


def test_match_push_failure_does_not_block_other_installations(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    connection_id = uuid.uuid4()
    account_id = uuid.uuid4()
    installations = [
        AppInstallation(
            id=uuid.uuid4(),
            account_id=account_id,
            platform="ios",
            app_version="1.0.0",
            build_number="3",
            push_fid="temporary-failure",
            push_enabled=True,
            is_active=True,
        ),
        AppInstallation(
            id=uuid.uuid4(),
            account_id=account_id,
            platform="android",
            app_version="1.0.0",
            build_number="3",
            push_fid="success",
            push_enabled=True,
            is_active=True,
        ),
    ]

    class AlertDb:
        def __init__(self) -> None:
            self.events: list[AuditEvent] = []

        def get(self, model: type[object], object_id: uuid.UUID) -> object | None:
            if model is AppInstallation:
                return next(
                    (
                        installation
                        for installation in installations
                        if installation.id == object_id
                    ),
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
        lambda: SimpleNamespace(push_notifications_enabled=True),
    )

    def send(fid: str, *, connection_id: str, settings: object) -> str:
        if fid == "temporary-failure":
            raise connection_service.PushDeliveryError("provider failure")
        return "provider-success"

    monkeypatch.setattr(connection_service, "send_firebase_match_alert", send)
    db = AlertDb()

    connection_service.send_match_push_alerts(
        db,
        [
            connection_service.MatchPushAlert(
                connection_id=connection_id,
                account_id=account_id,
                installation_id=installation.id,
            )
            for installation in installations
        ],
    )

    assert [event.event_type for event in db.events] == [
        "match_push_delivery_failed",
        "match_push_sent",
    ]
    assert installations[0].push_enabled is True


def test_withdrawing_consent_disconnects_the_parties(
    connection_fixture: tuple[FakeDb, Account, Account, MatchConnection],
) -> None:
    db, missing_account, found_account, connection = connection_fixture
    missing_account.contact_sharing_consented_at = datetime.now(UTC)
    found_account.contact_sharing_consented_at = datetime.now(UTC)
    connection_service.consent_to_connection(
        db,
        connection_id=connection.id,
        account=missing_account,
    )
    connected = connection_service.consent_to_connection(
        db,
        connection_id=connection.id,
        account=found_account,
    )
    assert connected.other_phone_number == missing_account.phone_number

    withdrawn = connection_service.withdraw_connection_consent(
        db,
        connection_id=connection.id,
        account=missing_account,
    )

    assert withdrawn.status == "pending_consent"
    assert withdrawn.my_consented is False
    assert withdrawn.other_consented is True
    assert withdrawn.other_phone_number is None
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
