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
