import uuid
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app import audit_service
from app.auth import AuthPrincipal, require_principal
from app.db import get_db
from app.models import Account, AppInstallation, AuditEvent, CaseAccount, CaseRecord
from app.routers import audit
from app.schemas import InstallationRequest


def _settings() -> SimpleNamespace:
    return SimpleNamespace(
        audit_admin_key="test-audit-admin-key",
        audit_upload_burst_limit=2,
        audit_failed_action_limit=3,
        audit_max_installations_per_account=1,
        audit_retention_days=365,
        audit_installation_inactivity_days=365,
    )


def _session() -> Session:
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    for table in (
        Account.__table__,
        AppInstallation.__table__,
        AuditEvent.__table__,
        CaseRecord.__table__,
        CaseAccount.__table__,
    ):
        table.create(engine)
    return Session(engine, expire_on_commit=False)


def test_installation_registration_is_idempotent_and_can_bind_to_account(
    monkeypatch,
) -> None:
    session = _session()
    account = Account(phone_number="+919876543210")
    session.add(account)
    session.commit()
    monkeypatch.setattr(audit_service, "get_settings", _settings)
    request = InstallationRequest(
        installation_id=uuid.uuid4(),
        platform="android",
        app_version="1.0.0",
        build_number="1",
    )

    audit_service.register_installation(session, request)
    audit_service.register_installation(session, request)
    installation = audit_service.register_installation(
        session,
        request,
        account=account,
    )

    registrations = session.scalars(
        select(AuditEvent).where(AuditEvent.event_type == "app_installation_registered")
    ).all()
    assert len(registrations) == 1
    assert installation.account_id == account.id
    assert installation.last_authenticated_at is not None
    session.close()


def test_case_upload_records_role_and_generates_explainable_risk_alerts(
    monkeypatch,
) -> None:
    session = _session()
    account = Account(phone_number="+919876543210")
    session.add(account)
    session.flush()
    missing_case = CaseRecord(
        case_type="missing",
        subject_label="Missing",
        status="active",
    )
    found_case = CaseRecord(
        case_type="found",
        subject_label="Found",
        status="active",
    )
    session.add_all([missing_case, found_case])
    session.flush()
    session.add_all(
        [
            CaseAccount(case_id=missing_case.id, account_id=account.id),
            CaseAccount(case_id=found_case.id, account_id=account.id),
        ]
    )
    session.commit()
    monkeypatch.setattr(audit_service, "get_settings", _settings)

    audit_service.record_case_upload(
        session,
        account_id=account.id,
        case_id=found_case.id,
        face_id=uuid.uuid4(),
        case_type="found",
        quality_score=0.91,
        forced=False,
        match_decision="review",
        installation_id=None,
    )

    uploaded = session.scalar(select(AuditEvent).where(AuditEvent.event_type == "case_uploaded"))
    alerts = session.scalars(select(AuditEvent).where(AuditEvent.event_type == "risk_alert")).all()
    assert uploaded is not None
    assert uploaded.event_data["case_type"] == "found"
    assert {alert.event_data["risk_type"] for alert in alerts} == {
        "upload_burst",
        "mixed_missing_and_found_roles",
    }
    session.close()


def test_audit_review_requires_separate_admin_key(monkeypatch) -> None:
    session = _session()
    account = Account(phone_number="+919876543210")
    session.add(account)
    session.commit()
    audit_service.record_event(
        session,
        "case_uploaded",
        account_id=account.id,
        data={"case_type": "missing"},
    )
    session.commit()
    monkeypatch.setattr(audit_service, "get_settings", _settings)

    app = FastAPI()
    app.include_router(audit.router)
    app.dependency_overrides[get_db] = lambda: session
    app.dependency_overrides[require_principal] = lambda: AuthPrincipal(
        account=account,
        session=SimpleNamespace(),
    )
    client = TestClient(app)

    assert client.get("/v1/audit/events").status_code == 401
    response = client.get(
        "/v1/audit/events",
        headers={"X-Audit-Admin-Key": "test-audit-admin-key"},
    )

    assert response.status_code == 200
    assert response.json()["results"][0]["account_phone"] == "+91********10"
    assert response.json()["results"][0]["event_data"]["case_type"] == "missing"
    session.close()


def test_retention_deletes_old_events_and_deactivates_stale_installations(
    monkeypatch,
) -> None:
    session = _session()
    now = datetime(2026, 10, 1, tzinfo=UTC)
    session.add(
        AppInstallation(
            id=uuid.uuid4(),
            platform="android",
            app_version="1.0.0",
            build_number="1",
            first_seen_at=now - timedelta(days=500),
            last_seen_at=now - timedelta(days=400),
            is_active=True,
        )
    )
    session.add(
        AuditEvent(
            event_type="case_uploaded",
            event_data={},
            created_at=now - timedelta(days=400),
        )
    )
    session.commit()
    monkeypatch.setattr(audit_service, "get_settings", _settings)

    result = audit_service.apply_audit_retention(session, now=now)

    installation = session.scalar(select(AppInstallation))
    assert result == {"deleted_events": 1, "deactivated_installations": 1}
    assert installation is not None
    assert installation.is_active is False
    assert session.scalar(select(AuditEvent)) is None
    session.close()
