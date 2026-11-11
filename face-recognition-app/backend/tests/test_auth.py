import uuid
from types import SimpleNamespace

import jwt
import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app import auth
from app.db import get_db
from app.models import Account, AuditEvent, AuthSession, OtpChallenge
from app.otp_delivery import OtpDeliveryError
from app.routers import auth as auth_router


@pytest.fixture
def settings() -> SimpleNamespace:
    return SimpleNamespace(
        jwt_secret="test-jwt-secret",
        jwt_issuer="matchsnap-test",
        access_token_ttl_seconds=900,
        refresh_token_ttl_days=30,
        otp_hash_secret="test-otp-secret",
        otp_ttl_seconds=300,
        otp_resend_cooldown_seconds=60,
        otp_max_requests_per_hour=5,
        otp_max_verification_attempts=5,
        otp_delivery_mode="development",
        telnyx_api_key=None,
        telnyx_verify_profile_id=None,
        twilio_account_sid=None,
        twilio_auth_token=None,
        twilio_verify_service_sid=None,
        audit_failed_action_limit=3,
    )


@pytest.fixture
def client(monkeypatch, settings: SimpleNamespace) -> TestClient:
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    for table in (
        Account.__table__,
        OtpChallenge.__table__,
        AuthSession.__table__,
        AuditEvent.__table__,
    ):
        table.create(engine)
    session = Session(engine, expire_on_commit=False)
    monkeypatch.setattr(auth, "get_settings", lambda: settings)
    monkeypatch.setattr(auth_router, "get_settings", lambda: settings)

    app = FastAPI()
    app.include_router(auth_router.router)
    app.dependency_overrides[get_db] = lambda: session
    with TestClient(app) as test_client:
        yield test_client
    session.close()


def test_phone_number_requires_e164() -> None:
    assert auth.normalize_phone_number("+91 98765 43210") == "+919876543210"
    with pytest.raises(HTTPException):
        auth.normalize_phone_number("9876543210")


def test_otp_login_refresh_and_logout(client: TestClient) -> None:
    requested = client.post(
        "/v1/auth/otp/request",
        json={"phone_number": "+91 98765 43210"},
    )
    assert requested.status_code == 202
    challenge = requested.json()
    assert len(challenge["development_code"]) == 6

    verified = client.post(
        "/v1/auth/otp/verify",
        json={
            "challenge_id": challenge["challenge_id"],
            "phone_number": "+919876543210",
            "code": challenge["development_code"],
        },
    )
    assert verified.status_code == 200
    tokens = verified.json()
    claims = jwt.decode(
        tokens["access_token"],
        "test-jwt-secret",
        algorithms=["HS256"],
        issuer="matchsnap-test",
    )
    assert claims["sub"] == tokens["account"]["id"]

    me = client.get(
        "/v1/auth/me",
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
    )
    assert me.status_code == 200
    assert me.json()["phone_number"] == "+919876543210"

    refreshed = client.post(
        "/v1/auth/refresh",
        json={"refresh_token": tokens["refresh_token"]},
    )
    assert refreshed.status_code == 200
    rotated = refreshed.json()
    assert rotated["refresh_token"] != tokens["refresh_token"]

    reused = client.post(
        "/v1/auth/refresh",
        json={"refresh_token": tokens["refresh_token"]},
    )
    assert reused.status_code == 401

    logged_out = client.post(
        "/v1/auth/logout",
        headers={"Authorization": f"Bearer {rotated['access_token']}"},
    )
    assert logged_out.status_code == 204
    assert (
        client.get(
            "/v1/auth/me",
            headers={"Authorization": f"Bearer {rotated['access_token']}"},
        ).status_code
        == 401
    )


def test_otp_is_single_use_and_resend_is_throttled(client: TestClient) -> None:
    requested = client.post(
        "/v1/auth/otp/request",
        json={"phone_number": "+919876543210"},
    )
    challenge = requested.json()

    throttled = client.post(
        "/v1/auth/otp/request",
        json={"phone_number": "+919876543210"},
    )
    assert throttled.status_code == 429

    payload = {
        "challenge_id": challenge["challenge_id"],
        "phone_number": "+919876543210",
        "code": challenge["development_code"],
    }
    assert client.post("/v1/auth/otp/verify", json=payload).status_code == 200
    assert client.post("/v1/auth/otp/verify", json=payload).status_code == 400


def test_repeated_otp_failures_create_a_risk_alert(client: TestClient) -> None:
    requested = client.post(
        "/v1/auth/otp/request",
        json={"phone_number": "+919876543210"},
    )
    challenge = requested.json()
    payload = {
        "challenge_id": challenge["challenge_id"],
        "phone_number": "+919876543210",
        "code": "000000",
    }

    assert client.post("/v1/auth/otp/verify", json=payload).status_code == 400
    assert client.post("/v1/auth/otp/verify", json=payload).status_code == 400
    assert client.post("/v1/auth/otp/verify", json=payload).status_code == 400

    session = client.app.dependency_overrides[get_db]()
    alerts = session.query(AuditEvent).filter_by(event_type="risk_alert").all()
    assert len(alerts) == 1
    assert alerts[0].event_data["risk_type"] == "repeated_otp_verification_failures"


def test_telnyx_verify_login(
    client: TestClient,
    monkeypatch,
    settings: SimpleNamespace,
) -> None:
    settings.otp_delivery_mode = "telnyx_verify"
    settings.telnyx_api_key = "KEYtest"
    settings.telnyx_verify_profile_id = "profile-test"
    sent_to: list[str] = []
    checked: list[tuple[str, str]] = []

    def send(phone_number: str, _settings: SimpleNamespace) -> str:
        sent_to.append(phone_number)
        return "verification-test"

    def check(
        phone_number: str,
        code: str,
        _settings: SimpleNamespace,
    ) -> bool:
        checked.append((phone_number, code))
        return True

    monkeypatch.setattr(auth, "send_telnyx_verification", send)
    monkeypatch.setattr(auth, "check_telnyx_verification", check)

    requested = client.post(
        "/v1/auth/otp/request",
        json={"phone_number": "+1 202 555 0100"},
    )
    assert requested.status_code == 202
    challenge = requested.json()
    assert challenge["development_code"] is None
    assert sent_to == ["+12025550100"]

    session = client.app.dependency_overrides[get_db]()
    stored = session.get(OtpChallenge, uuid.UUID(challenge["challenge_id"]))
    assert stored.code_hash == "telnyx:verification-test"

    verified = client.post(
        "/v1/auth/otp/verify",
        json={
            "challenge_id": challenge["challenge_id"],
            "phone_number": "+12025550100",
            "code": "123456",
        },
    )
    assert verified.status_code == 200
    assert verified.json()["account"]["phone_number"] == "+12025550100"
    assert checked == [("+12025550100", "123456")]


def test_telnyx_rejected_code_is_counted(
    client: TestClient,
    monkeypatch,
    settings: SimpleNamespace,
) -> None:
    settings.otp_delivery_mode = "telnyx_verify"
    monkeypatch.setattr(
        auth,
        "send_telnyx_verification",
        lambda phone_number, configured: "verification-test",
    )
    monkeypatch.setattr(
        auth,
        "check_telnyx_verification",
        lambda phone_number, code, configured: False,
    )

    requested = client.post(
        "/v1/auth/otp/request",
        json={"phone_number": "+12025550100"},
    )
    response = client.post(
        "/v1/auth/otp/verify",
        json={
            "challenge_id": requested.json()["challenge_id"],
            "phone_number": "+12025550100",
            "code": "000000",
        },
    )
    assert response.status_code == 400

    session = client.app.dependency_overrides[get_db]()
    challenge = session.get(
        OtpChallenge,
        uuid.UUID(requested.json()["challenge_id"]),
    )
    assert challenge.attempts == 1


def test_telnyx_delivery_failure_consumes_challenge_for_rate_limiting(
    client: TestClient,
    monkeypatch,
    settings: SimpleNamespace,
) -> None:
    settings.otp_delivery_mode = "telnyx_verify"

    def fail(phone_number: str, configured: SimpleNamespace) -> str:
        raise OtpDeliveryError("provider unavailable")

    monkeypatch.setattr(auth, "send_telnyx_verification", fail)

    response = client.post(
        "/v1/auth/otp/request",
        json={"phone_number": "+12025550100"},
    )
    assert response.status_code == 503
    assert response.json()["detail"] == "OTP delivery is temporarily unavailable"

    session = client.app.dependency_overrides[get_db]()
    challenge = session.query(OtpChallenge).one()
    assert challenge.consumed_at is not None
    event = session.query(AuditEvent).filter_by(event_type="otp_delivery_failed").one()
    assert event.event_data["provider"] == "telnyx_verify"


def test_telnyx_outage_does_not_consume_attempt(
    client: TestClient,
    monkeypatch,
    settings: SimpleNamespace,
) -> None:
    settings.otp_delivery_mode = "telnyx_verify"
    monkeypatch.setattr(
        auth,
        "send_telnyx_verification",
        lambda phone_number, configured: "verification-test",
    )

    def fail(
        phone_number: str,
        code: str,
        configured: SimpleNamespace,
    ) -> bool:
        raise OtpDeliveryError("provider unavailable")

    monkeypatch.setattr(auth, "check_telnyx_verification", fail)
    requested = client.post(
        "/v1/auth/otp/request",
        json={"phone_number": "+12025550100"},
    )

    response = client.post(
        "/v1/auth/otp/verify",
        json={
            "challenge_id": requested.json()["challenge_id"],
            "phone_number": "+12025550100",
            "code": "123456",
        },
    )
    assert response.status_code == 503

    session = client.app.dependency_overrides[get_db]()
    challenge = session.get(
        OtpChallenge,
        uuid.UUID(requested.json()["challenge_id"]),
    )
    assert challenge.attempts == 0


def test_twilio_verify_login(
    client: TestClient,
    monkeypatch,
    settings: SimpleNamespace,
) -> None:
    settings.otp_delivery_mode = "twilio_verify"
    settings.twilio_account_sid = "ACtest"
    settings.twilio_auth_token = "test-token"
    settings.twilio_verify_service_sid = "VAtest"
    sent_to: list[str] = []
    checked: list[tuple[str, str]] = []

    def send(phone_number: str, _settings: SimpleNamespace) -> str:
        sent_to.append(phone_number)
        return "VE1234567890"

    def check(
        phone_number: str,
        code: str,
        _settings: SimpleNamespace,
    ) -> bool:
        checked.append((phone_number, code))
        return True

    monkeypatch.setattr(auth, "send_twilio_verification", send)
    monkeypatch.setattr(auth, "check_twilio_verification", check)

    requested = client.post(
        "/v1/auth/otp/request",
        json={"phone_number": "+1 202 555 0100"},
    )
    assert requested.status_code == 202
    challenge = requested.json()
    assert challenge["development_code"] is None
    assert sent_to == ["+12025550100"]

    session = client.app.dependency_overrides[get_db]()
    stored = session.get(OtpChallenge, uuid.UUID(challenge["challenge_id"]))
    assert stored.code_hash == "twilio:VE1234567890"

    verified = client.post(
        "/v1/auth/otp/verify",
        json={
            "challenge_id": challenge["challenge_id"],
            "phone_number": "+12025550100",
            "code": "123456",
        },
    )
    assert verified.status_code == 200
    assert verified.json()["account"]["phone_number"] == "+12025550100"
    assert checked == [("+12025550100", "123456")]


def test_twilio_rejected_code_is_counted(
    client: TestClient,
    monkeypatch,
    settings: SimpleNamespace,
) -> None:
    settings.otp_delivery_mode = "twilio_verify"
    monkeypatch.setattr(
        auth,
        "send_twilio_verification",
        lambda phone_number, configured: "VE1234567890",
    )
    monkeypatch.setattr(
        auth,
        "check_twilio_verification",
        lambda phone_number, code, configured: False,
    )

    requested = client.post(
        "/v1/auth/otp/request",
        json={"phone_number": "+12025550100"},
    )
    response = client.post(
        "/v1/auth/otp/verify",
        json={
            "challenge_id": requested.json()["challenge_id"],
            "phone_number": "+12025550100",
            "code": "000000",
        },
    )
    assert response.status_code == 400

    session = client.app.dependency_overrides[get_db]()
    challenge = session.get(
        OtpChallenge,
        uuid.UUID(requested.json()["challenge_id"]),
    )
    assert challenge.attempts == 1


def test_twilio_delivery_failure_consumes_challenge_for_rate_limiting(
    client: TestClient,
    monkeypatch,
    settings: SimpleNamespace,
) -> None:
    settings.otp_delivery_mode = "twilio_verify"

    def fail(phone_number: str, configured: SimpleNamespace) -> str:
        raise OtpDeliveryError("provider unavailable")

    monkeypatch.setattr(auth, "send_twilio_verification", fail)

    response = client.post(
        "/v1/auth/otp/request",
        json={"phone_number": "+12025550100"},
    )
    assert response.status_code == 503
    assert response.json()["detail"] == "OTP delivery is temporarily unavailable"

    session = client.app.dependency_overrides[get_db]()
    challenge = session.query(OtpChallenge).one()
    assert challenge.consumed_at is not None
    events = session.query(AuditEvent).filter_by(event_type="otp_delivery_failed").all()
    assert len(events) == 1


def test_twilio_outage_does_not_consume_attempt(
    client: TestClient,
    monkeypatch,
    settings: SimpleNamespace,
) -> None:
    settings.otp_delivery_mode = "twilio_verify"
    monkeypatch.setattr(
        auth,
        "send_twilio_verification",
        lambda phone_number, configured: "VE1234567890",
    )

    def fail(
        phone_number: str,
        code: str,
        configured: SimpleNamespace,
    ) -> bool:
        raise OtpDeliveryError("provider unavailable")

    monkeypatch.setattr(auth, "check_twilio_verification", fail)
    requested = client.post(
        "/v1/auth/otp/request",
        json={"phone_number": "+12025550100"},
    )

    response = client.post(
        "/v1/auth/otp/verify",
        json={
            "challenge_id": requested.json()["challenge_id"],
            "phone_number": "+12025550100",
            "code": "123456",
        },
    )
    assert response.status_code == 503

    session = client.app.dependency_overrides[get_db]()
    challenge = session.get(
        OtpChallenge,
        uuid.UUID(requested.json()["challenge_id"]),
    )
    assert challenge.attempts == 0
