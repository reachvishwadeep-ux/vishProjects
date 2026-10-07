import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.auth import AuthPrincipal, require_principal
from app.connection_service import (
    consent_to_connection,
    list_connections,
    mark_connection_read,
    renew_meeting_codes,
    verify_peer_meeting_code,
    withdraw_connection_consent,
)
from app.db import get_db
from app.schemas import (
    ConnectionListResponse,
    ConnectionOut,
    MeetingCodeVerifyRequest,
)

router = APIRouter(prefix="/v1/connections", tags=["connections"])


@router.get("", response_model=ConnectionListResponse)
def connections(
    db: Session = Depends(get_db),
    principal: AuthPrincipal = Depends(require_principal),
) -> ConnectionListResponse:
    return list_connections(db, principal.account)


@router.post("/{connection_id}/read", response_model=ConnectionOut)
def read_connection(
    connection_id: uuid.UUID,
    db: Session = Depends(get_db),
    principal: AuthPrincipal = Depends(require_principal),
) -> ConnectionOut:
    return mark_connection_read(
        db,
        connection_id=connection_id,
        account=principal.account,
    )


@router.post("/{connection_id}/consent", response_model=ConnectionOut)
def consent(
    connection_id: uuid.UUID,
    db: Session = Depends(get_db),
    principal: AuthPrincipal = Depends(require_principal),
) -> ConnectionOut:
    return consent_to_connection(
        db,
        connection_id=connection_id,
        account=principal.account,
    )


@router.post(
    "/{connection_id}/withdraw-consent",
    response_model=ConnectionOut,
)
def withdraw_consent(
    connection_id: uuid.UUID,
    db: Session = Depends(get_db),
    principal: AuthPrincipal = Depends(require_principal),
) -> ConnectionOut:
    return withdraw_connection_consent(
        db,
        connection_id=connection_id,
        account=principal.account,
    )


@router.post("/{connection_id}/meeting-code/renew", response_model=ConnectionOut)
def renew_code(
    connection_id: uuid.UUID,
    db: Session = Depends(get_db),
    principal: AuthPrincipal = Depends(require_principal),
) -> ConnectionOut:
    return renew_meeting_codes(
        db,
        connection_id=connection_id,
        account=principal.account,
    )


@router.post(
    "/{connection_id}/meeting-code/verify",
    response_model=ConnectionOut,
)
def verify_code(
    connection_id: uuid.UUID,
    request: MeetingCodeVerifyRequest,
    db: Session = Depends(get_db),
    principal: AuthPrincipal = Depends(require_principal),
) -> ConnectionOut:
    return verify_peer_meeting_code(
        db,
        connection_id=connection_id,
        account=principal.account,
        code=request.code,
    )
