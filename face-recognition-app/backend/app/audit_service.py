import hmac
import uuid
from datetime import UTC, datetime, timedelta

from fastapi import Header, HTTPException, status
from sqlalchemy import delete, func, select, update
from sqlalchemy.orm import Session

from app.config import get_settings
from app.models import (
    Account,
    AppInstallation,
    AuditEvent,
    CaseAccount,
    CaseRecord,
)
from app.schemas import InstallationRequest


def require_audit_admin(
    x_audit_admin_key: str | None = Header(default=None),
) -> None:
    expected = get_settings().audit_admin_key
    if (
        x_audit_admin_key is None
        or not expected
        or not hmac.compare_digest(x_audit_admin_key, expected)
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="valid audit administrator credentials are required",
        )


def record_event(
    db: Session,
    event_type: str,
    *,
    account_id: uuid.UUID | None = None,
    actor_phone_hash: str | None = None,
    data: dict[str, object] | None = None,
) -> AuditEvent:
    event = AuditEvent(
        account_id=account_id,
        actor_phone_hash=actor_phone_hash,
        event_type=event_type,
        event_data=data or {},
    )
    db.add(event)
    return event


def record_risk_alert(
    db: Session,
    *,
    risk_type: str,
    severity: str,
    account_id: uuid.UUID | None = None,
    actor_phone_hash: str | None = None,
    data: dict[str, object] | None = None,
    deduplicate_for: timedelta = timedelta(hours=24),
) -> bool:
    cutoff = datetime.now(UTC) - deduplicate_for
    recent_alerts = db.scalars(
        select(AuditEvent).where(
            AuditEvent.event_type == "risk_alert",
            AuditEvent.account_id == account_id,
            AuditEvent.actor_phone_hash == actor_phone_hash,
            AuditEvent.created_at >= cutoff,
        )
    ).all()
    if any(event.event_data.get("risk_type") == risk_type for event in recent_alerts):
        return False
    event_data = {"risk_type": risk_type, "severity": severity}
    if data:
        event_data.update(data)
    record_event(
        db,
        "risk_alert",
        account_id=account_id,
        actor_phone_hash=actor_phone_hash,
        data=event_data,
    )
    return True


def register_installation(
    db: Session,
    request: InstallationRequest,
    *,
    account: Account | None = None,
) -> AppInstallation:
    now = datetime.now(UTC)
    installation = db.get(AppInstallation, request.installation_id)
    previous_account_id = installation.account_id if installation is not None else None
    if installation is None:
        installation = AppInstallation(
            id=request.installation_id,
            platform=request.platform.value,
            app_version=request.app_version,
            build_number=request.build_number,
            first_seen_at=now,
            last_seen_at=now,
        )
        db.add(installation)
        record_event(
            db,
            "app_installation_registered",
            data={
                "installation_id": str(request.installation_id),
                "platform": request.platform.value,
                "app_version": request.app_version,
                "build_number": request.build_number,
            },
        )
    else:
        installation.platform = request.platform.value
        installation.app_version = request.app_version
        installation.build_number = request.build_number
        installation.last_seen_at = now
        installation.is_active = True

    if account is not None:
        installation.account_id = account.id
        installation.last_authenticated_at = now
        if previous_account_id != account.id:
            record_event(
                db,
                "app_installation_linked",
                account_id=account.id,
                data={
                    "installation_id": str(installation.id),
                    "previous_account_id": (
                        str(previous_account_id) if previous_account_id is not None else None
                    ),
                },
            )
            if previous_account_id is not None:
                record_risk_alert(
                    db,
                    risk_type="installation_account_changed",
                    severity="medium",
                    account_id=account.id,
                    data={
                        "installation_id": str(installation.id),
                        "previous_account_id": str(previous_account_id),
                    },
                )

        db.flush()
        installation_count = db.scalar(
            select(func.count(AppInstallation.id)).where(
                AppInstallation.account_id == account.id,
                AppInstallation.is_active.is_(True),
            )
        )
        if installation_count and (
            installation_count > get_settings().audit_max_installations_per_account
        ):
            record_risk_alert(
                db,
                risk_type="many_installations_for_account",
                severity="medium",
                account_id=account.id,
                data={"active_installation_count": installation_count},
            )

    db.commit()
    db.refresh(installation)
    return installation


def record_case_upload(
    db: Session,
    *,
    account_id: uuid.UUID,
    case_id: uuid.UUID,
    face_id: uuid.UUID,
    case_type: str,
    quality_score: float | None,
    forced: bool,
    match_decision: str,
    installation_id: uuid.UUID | None,
) -> None:
    installation_is_linked = False
    if installation_id is not None:
        installation = db.get(AppInstallation, installation_id)
        installation_is_linked = installation is not None and installation.account_id == account_id
    record_event(
        db,
        "case_uploaded",
        account_id=account_id,
        data={
            "case_id": str(case_id),
            "face_id": str(face_id),
            "case_type": case_type,
            "quality_score": quality_score,
            "quality_gate_bypassed": forced,
            "match_decision": match_decision,
            "installation_id": (str(installation_id) if installation_id is not None else None),
            "installation_is_linked": installation_is_linked,
        },
    )
    if installation_id is not None and not installation_is_linked:
        record_risk_alert(
            db,
            risk_type="unlinked_installation_used_for_upload",
            severity="medium",
            account_id=account_id,
            data={"installation_id": str(installation_id), "case_id": str(case_id)},
        )
    if forced:
        record_risk_alert(
            db,
            risk_type="quality_gate_bypassed",
            severity="low",
            account_id=account_id,
            data={"case_id": str(case_id), "face_id": str(face_id)},
        )

    one_hour_ago = datetime.now(UTC) - timedelta(hours=1)
    recent_uploads = db.scalar(
        select(func.count(CaseRecord.id))
        .join(CaseAccount, CaseAccount.case_id == CaseRecord.id)
        .where(
            CaseAccount.account_id == account_id,
            CaseRecord.created_at >= one_hour_ago,
        )
    )
    if recent_uploads and recent_uploads >= get_settings().audit_upload_burst_limit:
        record_risk_alert(
            db,
            risk_type="upload_burst",
            severity="medium",
            account_id=account_id,
            data={"uploads_in_last_hour": recent_uploads},
        )

    case_types = set(
        db.scalars(
            select(CaseRecord.case_type)
            .join(CaseAccount, CaseAccount.case_id == CaseRecord.id)
            .where(CaseAccount.account_id == account_id)
        ).all()
    )
    if len(case_types) > 1:
        record_risk_alert(
            db,
            risk_type="mixed_missing_and_found_roles",
            severity="low",
            account_id=account_id,
            data={"case_types": sorted(case_types)},
        )
    db.commit()


def record_repeated_failure_risk(
    db: Session,
    *,
    account_id: uuid.UUID,
    event_type: str,
    risk_type: str,
    data: dict[str, object],
) -> None:
    db.flush()
    one_hour_ago = datetime.now(UTC) - timedelta(hours=1)
    failures = db.scalar(
        select(func.count(AuditEvent.id)).where(
            AuditEvent.account_id == account_id,
            AuditEvent.event_type == event_type,
            AuditEvent.created_at >= one_hour_ago,
        )
    )
    if failures and failures >= get_settings().audit_failed_action_limit:
        record_risk_alert(
            db,
            risk_type=risk_type,
            severity="high",
            account_id=account_id,
            data={**data, "failures_in_last_hour": failures},
        )


def mask_phone(phone_number: str | None) -> str | None:
    if phone_number is None:
        return None
    if len(phone_number) <= 4:
        return "*" * len(phone_number)
    return f"{phone_number[:3]}{'*' * (len(phone_number) - 5)}{phone_number[-2:]}"


def apply_audit_retention(db: Session, *, now: datetime | None = None) -> dict[str, int]:
    settings = get_settings()
    current_time = now or datetime.now(UTC)
    event_cutoff = current_time - timedelta(days=settings.audit_retention_days)
    installation_cutoff = current_time - timedelta(days=settings.audit_installation_inactivity_days)
    deleted_events = db.execute(
        delete(AuditEvent).where(AuditEvent.created_at < event_cutoff)
    ).rowcount
    deactivated_installations = db.execute(
        update(AppInstallation)
        .where(
            AppInstallation.last_seen_at < installation_cutoff,
            AppInstallation.is_active.is_(True),
        )
        .values(is_active=False)
    ).rowcount
    db.commit()
    return {
        "deleted_events": deleted_events or 0,
        "deactivated_installations": deactivated_installations or 0,
    }
