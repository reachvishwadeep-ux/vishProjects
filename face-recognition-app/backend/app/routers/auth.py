from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.auth import (
    AuthPrincipal,
    create_otp_challenge,
    normalize_phone_number,
    refresh_session,
    require_principal,
    revoke_session,
    verify_otp,
)
from app.config import get_settings
from app.db import get_db
from app.schemas import (
    AccountOut,
    OtpRequest,
    OtpRequestResponse,
    OtpVerifyRequest,
    RefreshRequest,
    TokenResponse,
)

router = APIRouter(prefix="/v1/auth", tags=["authentication"])


@router.post(
    "/otp/request",
    response_model=OtpRequestResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
def request_otp(payload: OtpRequest, db: Session = Depends(get_db)) -> OtpRequestResponse:
    phone_number = normalize_phone_number(payload.phone_number)
    challenge, code = create_otp_challenge(db, phone_number)
    settings = get_settings()
    return OtpRequestResponse(
        challenge_id=challenge.id,
        expires_in=settings.otp_ttl_seconds,
        development_code=code if settings.otp_delivery_mode == "development" else None,
    )


@router.post("/otp/verify", response_model=TokenResponse)
def verify_otp_code(
    payload: OtpVerifyRequest,
    db: Session = Depends(get_db),
) -> TokenResponse:
    return verify_otp(
        db,
        challenge_id=payload.challenge_id,
        phone_number=normalize_phone_number(payload.phone_number),
        code=payload.code,
    )


@router.post("/refresh", response_model=TokenResponse)
def refresh(
    payload: RefreshRequest,
    db: Session = Depends(get_db),
) -> TokenResponse:
    return refresh_session(db, payload.refresh_token)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(
    principal: AuthPrincipal = Depends(require_principal),
    db: Session = Depends(get_db),
) -> None:
    revoke_session(db, principal)


@router.get("/me", response_model=AccountOut)
def me(principal: AuthPrincipal = Depends(require_principal)) -> AccountOut:
    return AccountOut(
        id=principal.account.id,
        phone_number=principal.account.phone_number,
    )
