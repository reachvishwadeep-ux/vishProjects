import hashlib
import hmac
import re
import secrets
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.config import get_settings
from app.db import get_db
from app.models import Account, AuditEvent, AuthSession, OtpChallenge
from app.schemas import AccountOut, TokenResponse

PHONE_PATTERN = re.compile(r"^\+[1-9]\d{7,14}$")
bearer_scheme = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class AuthPrincipal:
    account: Account
    session: AuthSession


def normalize_phone_number(value: str) -> str:
    normalized = re.sub(r"[\s()-]", "", value.strip())
    if not PHONE_PATTERN.fullmatch(normalized):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="phone number must use international E.164 format, for example +919876543210",
        )
    return normalized


def create_otp_challenge(db: Session, phone_number: str) -> tuple[OtpChallenge, str]:
    settings = get_settings()
    if settings.otp_delivery_mode != "development":
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="SMS delivery is not configured",
        )

    now = datetime.now(UTC)
    hour_ago = now - timedelta(hours=1)
    request_count = db.scalar(
        select(func.count(OtpChallenge.id)).where(
            OtpChallenge.phone_number == phone_number,
            OtpChallenge.created_at >= hour_ago,
        )
    )
    if request_count is not None and request_count >= settings.otp_max_requests_per_hour:
        _audit(db, "otp_request_rate_limited", phone_number=phone_number)
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="too many OTP requests; try again later",
        )

    latest = db.scalar(
        select(OtpChallenge)
        .where(OtpChallenge.phone_number == phone_number)
        .order_by(OtpChallenge.created_at.desc())
        .limit(1)
    )
    if (
        latest is not None
        and latest.created_at is not None
        and _as_utc(latest.created_at)
        > now - timedelta(seconds=settings.otp_resend_cooldown_seconds)
    ):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="wait before requesting another OTP",
        )

    challenge_id = uuid.uuid4()
    code = f"{secrets.randbelow(1_000_000):06d}"
    challenge = OtpChallenge(
        id=challenge_id,
        phone_number=phone_number,
        code_hash=_otp_hash(challenge_id, phone_number, code),
        expires_at=now + timedelta(seconds=settings.otp_ttl_seconds),
    )
    db.add(challenge)
    _audit(db, "otp_requested", phone_number=phone_number)
    db.commit()
    return challenge, code


def verify_otp(
    db: Session,
    *,
    challenge_id: uuid.UUID,
    phone_number: str,
    code: str,
) -> TokenResponse:
    settings = get_settings()
    challenge = db.get(OtpChallenge, challenge_id)
    now = datetime.now(UTC)
    if challenge is None or challenge.phone_number != phone_number:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="invalid OTP challenge",
        )
    if challenge.consumed_at is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="OTP has already been used",
        )
    if _as_utc(challenge.expires_at) <= now:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="OTP has expired",
        )
    if challenge.attempts >= settings.otp_max_verification_attempts:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="too many verification attempts",
        )

    challenge.attempts += 1
    expected = _otp_hash(challenge.id, phone_number, code.strip())
    if not hmac.compare_digest(challenge.code_hash, expected):
        _audit(db, "otp_verification_failed", phone_number=phone_number)
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="incorrect OTP",
        )

    challenge.consumed_at = now
    account = db.scalar(select(Account).where(Account.phone_number == phone_number))
    if account is None:
        account = Account(phone_number=phone_number)
        db.add(account)
        db.flush()
    if not account.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="account is disabled",
        )
    account.last_login_at = now
    auth_session, refresh_token = _new_session(db, account, now)
    _audit(db, "otp_verified", account=account)
    db.commit()
    return _token_response(account, auth_session, refresh_token, now)


def refresh_session(db: Session, refresh_token: str) -> TokenResponse:
    token_hash = _token_hash(refresh_token)
    auth_session = db.scalar(
        select(AuthSession).where(AuthSession.refresh_token_hash == token_hash)
    )
    now = datetime.now(UTC)
    if (
        auth_session is None
        or auth_session.revoked_at is not None
        or _as_utc(auth_session.expires_at) <= now
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="invalid or expired refresh token",
        )
    account = db.get(Account, auth_session.account_id)
    if account is None or not account.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="account is unavailable",
        )

    rotated_token = secrets.token_urlsafe(48)
    auth_session.refresh_token_hash = _token_hash(rotated_token)
    auth_session.last_used_at = now
    _audit(db, "session_refreshed", account=account)
    db.commit()
    return _token_response(account, auth_session, rotated_token, now)


def revoke_session(db: Session, principal: AuthPrincipal) -> None:
    principal.session.revoked_at = datetime.now(UTC)
    _audit(db, "session_revoked", account=principal.account)
    db.commit()


def require_principal(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> AuthPrincipal:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise _unauthorized()
    try:
        payload = jwt.decode(
            credentials.credentials,
            get_settings().jwt_secret,
            algorithms=["HS256"],
            issuer=get_settings().jwt_issuer,
            options={"require": ["exp", "iat", "iss", "sub", "sid"]},
        )
        account_id = uuid.UUID(payload["sub"])
        session_id = uuid.UUID(payload["sid"])
    except (jwt.PyJWTError, KeyError, TypeError, ValueError):
        raise _unauthorized() from None

    auth_session = db.get(AuthSession, session_id)
    account = db.get(Account, account_id)
    now = datetime.now(UTC)
    if (
        auth_session is None
        or account is None
        or auth_session.account_id != account.id
        or auth_session.revoked_at is not None
        or _as_utc(auth_session.expires_at) <= now
        or not account.is_active
    ):
        raise _unauthorized()
    return AuthPrincipal(account=account, session=auth_session)


def _new_session(
    db: Session,
    account: Account,
    now: datetime,
) -> tuple[AuthSession, str]:
    refresh_token = secrets.token_urlsafe(48)
    auth_session = AuthSession(
        account_id=account.id,
        refresh_token_hash=_token_hash(refresh_token),
        expires_at=now + timedelta(days=get_settings().refresh_token_ttl_days),
        last_used_at=now,
    )
    db.add(auth_session)
    db.flush()
    return auth_session, refresh_token


def _token_response(
    account: Account,
    auth_session: AuthSession,
    refresh_token: str,
    now: datetime,
) -> TokenResponse:
    settings = get_settings()
    access_token = jwt.encode(
        {
            "sub": str(account.id),
            "sid": str(auth_session.id),
            "iss": settings.jwt_issuer,
            "iat": now,
            "exp": now + timedelta(seconds=settings.access_token_ttl_seconds),
        },
        settings.jwt_secret,
        algorithm="HS256",
    )
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.access_token_ttl_seconds,
        account=AccountOut(id=account.id, phone_number=account.phone_number),
    )


def _otp_hash(challenge_id: uuid.UUID, phone_number: str, code: str) -> str:
    value = f"{challenge_id}:{phone_number}:{code}".encode()
    return hmac.new(
        get_settings().otp_hash_secret.encode(),
        value,
        hashlib.sha256,
    ).hexdigest()


def _token_hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def _as_utc(value: datetime) -> datetime:
    return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)


def _phone_hash(phone_number: str) -> str:
    return hmac.new(
        get_settings().otp_hash_secret.encode(),
        phone_number.encode(),
        hashlib.sha256,
    ).hexdigest()


def _audit(
    db: Session,
    event_type: str,
    *,
    account: Account | None = None,
    phone_number: str | None = None,
) -> None:
    db.add(
        AuditEvent(
            account_id=account.id if account is not None else None,
            actor_phone_hash=_phone_hash(phone_number) if phone_number is not None else None,
            event_type=event_type,
            event_data={},
        )
    )


def _unauthorized() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="valid authentication is required",
        headers={"WWW-Authenticate": "Bearer"},
    )
