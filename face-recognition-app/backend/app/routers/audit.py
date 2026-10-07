import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.audit_service import (
    mask_phone,
    record_event,
    register_installation,
    require_audit_admin,
)
from app.auth import AuthPrincipal, require_principal
from app.db import get_db
from app.models import (
    Account,
    AppInstallation,
    AuditEvent,
    CaseMatch,
    CaseRecord,
)
from app.schemas import (
    AuditEventListResponse,
    AuditEventOut,
    AuditSummaryResponse,
    InstallationListResponse,
    InstallationOut,
    InstallationRequest,
)

router = APIRouter(prefix="/v1/audit", tags=["audit"])


@router.post(
    "/installations/register",
    response_model=InstallationOut,
    status_code=status.HTTP_201_CREATED,
)
def register_app_installation(
    request: InstallationRequest,
    db: Session = Depends(get_db),
) -> InstallationOut:
    installation = register_installation(db, request)
    return _installation_out(db, installation)


@router.post(
    "/installations/bind",
    response_model=InstallationOut,
)
def bind_app_installation(
    request: InstallationRequest,
    db: Session = Depends(get_db),
    principal: AuthPrincipal = Depends(require_principal),
) -> InstallationOut:
    installation = register_installation(db, request, account=principal.account)
    return _installation_out(db, installation)


@router.get(
    "/events",
    response_model=AuditEventListResponse,
    dependencies=[Depends(require_audit_admin)],
)
def list_audit_events(
    event_type: str | None = None,
    account_id: uuid.UUID | None = None,
    created_after: datetime | None = None,
    risk_only: bool = False,
    limit: int = Query(default=100, ge=1, le=500),
    db: Session = Depends(get_db),
) -> AuditEventListResponse:
    statement = select(AuditEvent)
    if risk_only:
        statement = statement.where(AuditEvent.event_type == "risk_alert")
    elif event_type is not None:
        statement = statement.where(AuditEvent.event_type == event_type)
    if account_id is not None:
        statement = statement.where(AuditEvent.account_id == account_id)
    if created_after is not None:
        statement = statement.where(AuditEvent.created_at >= created_after)
    events = db.scalars(statement.order_by(AuditEvent.created_at.desc()).limit(limit)).all()
    results = [_event_out(db, event) for event in events]
    record_event(
        db,
        "audit_log_viewed",
        data={
            "scope": "events",
            "event_type": event_type,
            "account_id": str(account_id) if account_id is not None else None,
            "risk_only": risk_only,
            "result_count": len(results),
        },
    )
    db.commit()
    return AuditEventListResponse(results=results)


@router.get(
    "/installations",
    response_model=InstallationListResponse,
    dependencies=[Depends(require_audit_admin)],
)
def list_installations(
    account_id: uuid.UUID | None = None,
    limit: int = Query(default=100, ge=1, le=500),
    db: Session = Depends(get_db),
) -> InstallationListResponse:
    statement = select(AppInstallation)
    if account_id is not None:
        statement = statement.where(AppInstallation.account_id == account_id)
    installations = db.scalars(
        statement.order_by(AppInstallation.last_seen_at.desc()).limit(limit)
    ).all()
    results = [_installation_out(db, installation) for installation in installations]
    record_event(
        db,
        "audit_log_viewed",
        data={"scope": "installations", "result_count": len(results)},
    )
    db.commit()
    return InstallationListResponse(results=results)


@router.get(
    "/summary",
    response_model=AuditSummaryResponse,
    dependencies=[Depends(require_audit_admin)],
)
def audit_summary(
    db: Session = Depends(get_db),
) -> AuditSummaryResponse:
    summary = AuditSummaryResponse(
        installation_registrations=db.scalar(select(func.count(AppInstallation.id))) or 0,
        linked_installations=db.scalar(
            select(func.count(AppInstallation.id)).where(AppInstallation.account_id.is_not(None))
        )
        or 0,
        accounts=db.scalar(select(func.count(Account.id))) or 0,
        missing_uploads=db.scalar(
            select(func.count(CaseRecord.id)).where(CaseRecord.case_type == "missing")
        )
        or 0,
        found_uploads=db.scalar(
            select(func.count(CaseRecord.id)).where(CaseRecord.case_type == "found")
        )
        or 0,
        confirmed_matches=db.scalar(
            select(func.count(CaseMatch.id)).where(CaseMatch.decision == "match")
        )
        or 0,
        risk_alerts=db.scalar(
            select(func.count(AuditEvent.id)).where(AuditEvent.event_type == "risk_alert")
        )
        or 0,
    )
    record_event(db, "audit_log_viewed", data={"scope": "summary"})
    db.commit()
    return summary


def _event_out(db: Session, event: AuditEvent) -> AuditEventOut:
    account = db.get(Account, event.account_id) if event.account_id is not None else None
    return AuditEventOut(
        id=event.id,
        event_type=event.event_type,
        account_id=event.account_id,
        account_phone=mask_phone(account.phone_number if account is not None else None),
        event_data=event.event_data,
        created_at=event.created_at,
    )


def _installation_out(
    db: Session,
    installation: AppInstallation,
) -> InstallationOut:
    account = (
        db.get(Account, installation.account_id) if installation.account_id is not None else None
    )
    return InstallationOut(
        installation_id=installation.id,
        account_id=installation.account_id,
        account_phone=mask_phone(account.phone_number if account is not None else None),
        platform=installation.platform,
        app_version=installation.app_version,
        build_number=installation.build_number,
        first_seen_at=installation.first_seen_at,
        last_seen_at=installation.last_seen_at,
        last_authenticated_at=installation.last_authenticated_at,
        is_active=installation.is_active,
    )
