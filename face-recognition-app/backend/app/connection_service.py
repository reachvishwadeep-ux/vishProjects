import uuid
from dataclasses import dataclass
from datetime import UTC, datetime

from fastapi import HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.audit_service import (
    record_event,
    record_repeated_failure_risk,
    record_risk_alert,
)
from app.config import get_settings
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
from app.push_delivery import (
    InvalidPushFidError,
    PushDeliveryError,
    send_firebase_match_alert,
)
from app.schemas import (
    ConnectionListResponse,
    ConnectionOut,
    ConnectionRole,
    MatchHistoryListResponse,
    MatchHistoryOut,
    MatchHistoryRole,
)
from app.storage import get_store


@dataclass(frozen=True)
class MatchPushAlert:
    connection_id: uuid.UUID
    account_id: uuid.UUID
    installation_id: uuid.UUID


def ensure_connection_for_match(
    db: Session,
    match: CaseMatch,
    *,
    source: str,
) -> list[MatchPushAlert]:
    if match.decision != "match":
        return []
    missing_owner = db.get(CaseAccount, match.missing_case_id)
    found_owner = db.get(CaseAccount, match.found_case_id)
    if missing_owner is None or found_owner is None:
        return []
    if missing_owner.account_id == found_owner.account_id:
        record_risk_alert(
            db,
            risk_type="same_account_cross_role_match",
            severity="high",
            account_id=missing_owner.account_id,
            data={
                "match_id": str(match.id),
                "missing_case_id": str(match.missing_case_id),
                "found_case_id": str(match.found_case_id),
            },
        )
        return []
    missing_account = db.get(Account, missing_owner.account_id)
    found_account = db.get(Account, found_owner.account_id)
    contact_sharing_ready = (
        missing_account is not None
        and missing_account.contact_sharing_consented_at is not None
        and found_account is not None
        and found_account.contact_sharing_consented_at is not None
    )

    connection_id = db.scalar(
        insert(MatchConnection)
        .values(
            case_match_id=match.id,
            missing_account_id=missing_owner.account_id,
            found_account_id=found_owner.account_id,
            status=("connected" if contact_sharing_ready else "pending_contact_consent"),
        )
        .on_conflict_do_nothing(index_elements=[MatchConnection.case_match_id])
        .returning(MatchConnection.id)
    )
    connection_created = connection_id is not None
    if connection_id is None:
        connection_id = db.scalar(
            select(MatchConnection.id).where(MatchConnection.case_match_id == match.id)
        )
    if connection_id is None:
        return []
    account_ids = (missing_owner.account_id, found_owner.account_id)
    if connection_created:
        record_event(
            db,
            "case_match_confirmed",
            data={
                "match_id": str(match.id),
                "connection_id": str(connection_id),
                "missing_case_id": str(match.missing_case_id),
                "found_case_id": str(match.found_case_id),
                "missing_face_id": str(match.missing_face_id),
                "found_face_id": str(match.found_face_id),
                "score": match.score,
                "decision": match.decision,
                "model_tag": match.model_tag,
                "source": source,
            },
        )
        if get_settings().push_notifications_enabled:
            installations = db.scalars(
                select(AppInstallation).where(
                    AppInstallation.account_id.in_(account_ids),
                    AppInstallation.is_active.is_(True),
                    AppInstallation.push_enabled.is_(True),
                    AppInstallation.push_fid.is_not(None),
                )
            ).all()
            for installation in installations:
                record_event(
                    db,
                    "match_push_pending",
                    account_id=installation.account_id,
                    data={
                        "connection_id": str(connection_id),
                        "installation_id": str(installation.id),
                    },
                )

    for account_id in account_ids:
        db.execute(
            insert(AccountNotification)
            .values(
                account_id=account_id,
                connection_id=connection_id,
                event_type="match_found",
            )
            .on_conflict_do_nothing(constraint="account_notification_event_key")
        )
    if not get_settings().push_notifications_enabled:
        return []
    if connection_created:
        return [
            MatchPushAlert(
                connection_id=connection_id,
                account_id=installation.account_id,
                installation_id=installation.id,
            )
            for installation in installations
            if installation.account_id is not None
        ]
    return _pending_match_push_alerts(db, connection_id, account_ids)


def _pending_match_push_alerts(
    db: Session,
    connection_id: uuid.UUID,
    account_ids: tuple[uuid.UUID, uuid.UUID],
) -> list[MatchPushAlert]:
    events = db.scalars(
        select(AuditEvent).where(
            AuditEvent.account_id.in_(account_ids),
            AuditEvent.event_type.in_(
                (
                    "match_push_pending",
                    "match_push_sent",
                    "match_push_delivery_skipped",
                )
            ),
        )
    ).all()
    pending_installations = {
        (event.account_id, event.event_data.get("installation_id"))
        for event in events
        if event.event_type == "match_push_pending"
        and event.event_data.get("connection_id") == str(connection_id)
        and event.event_data.get("installation_id")
    }
    completed_installations = {
        (event.account_id, event.event_data.get("installation_id"))
        for event in events
        if event.event_type in {"match_push_sent", "match_push_delivery_skipped"}
        and event.event_data.get("connection_id") == str(connection_id)
        and event.event_data.get("installation_id")
    }
    return [
        MatchPushAlert(
            connection_id=connection_id,
            account_id=account_id,
            installation_id=uuid.UUID(installation_id),
        )
        for account_id, installation_id in pending_installations
        if (account_id, installation_id) not in completed_installations
        and account_id is not None
        and isinstance(installation_id, str)
    ]


def send_match_push_alerts(
    db: Session,
    alerts: list[MatchPushAlert],
) -> None:
    settings = get_settings()
    if not settings.push_notifications_enabled or not alerts:
        return

    for alert in alerts:
        installation = db.get(AppInstallation, alert.installation_id)
        if (
            installation is None
            or installation.account_id != alert.account_id
            or not installation.is_active
            or not installation.push_enabled
            or not installation.push_fid
        ):
            record_event(
                db,
                "match_push_delivery_skipped",
                account_id=alert.account_id,
                data={
                    "connection_id": str(alert.connection_id),
                    "installation_id": str(alert.installation_id),
                    "reason": "inactive_or_missing_installation",
                },
            )
            continue
        try:
            provider_message_id = send_firebase_match_alert(
                installation.push_fid,
                connection_id=str(alert.connection_id),
                settings=settings,
            )
        except InvalidPushFidError:
            installation.push_fid = None
            installation.push_enabled = False
            installation.push_fid_updated_at = datetime.now(UTC)
            record_event(
                db,
                "match_push_delivery_skipped",
                account_id=alert.account_id,
                data={
                    "connection_id": str(alert.connection_id),
                    "installation_id": str(alert.installation_id),
                    "reason": "invalid_fid",
                },
            )
            continue
        except PushDeliveryError:
            record_event(
                db,
                "match_push_delivery_failed",
                account_id=alert.account_id,
                data={
                    "connection_id": str(alert.connection_id),
                    "installation_id": str(alert.installation_id),
                    "provider": "firebase",
                },
            )
            continue
        record_event(
            db,
            "match_push_sent",
            account_id=alert.account_id,
            data={
                "connection_id": str(alert.connection_id),
                "installation_id": str(alert.installation_id),
                "provider": "firebase",
                "provider_message_id": provider_message_id,
            },
        )
    db.commit()


def connection_ids_for_case(
    db: Session,
    *,
    case_id: uuid.UUID,
    account_id: uuid.UUID,
) -> dict[uuid.UUID, uuid.UUID]:
    rows = db.execute(
        select(CaseMatch.missing_case_id, CaseMatch.found_case_id, MatchConnection.id)
        .join(MatchConnection, MatchConnection.case_match_id == CaseMatch.id)
        .where(
            or_(CaseMatch.missing_case_id == case_id, CaseMatch.found_case_id == case_id),
            or_(
                MatchConnection.missing_account_id == account_id,
                MatchConnection.found_account_id == account_id,
            ),
        )
    ).all()
    return {
        (found_case_id if missing_case_id == case_id else missing_case_id): connection_id
        for missing_case_id, found_case_id, connection_id in rows
    }


def list_connections(
    db: Session,
    account: Account,
) -> ConnectionListResponse:
    connections = db.scalars(
        select(MatchConnection)
        .where(
            or_(
                MatchConnection.missing_account_id == account.id,
                MatchConnection.found_account_id == account.id,
            )
        )
        .order_by(MatchConnection.created_at.desc())
    ).all()
    return ConnectionListResponse(
        results=[_connection_out(db, connection, account.id) for connection in connections]
    )


def list_match_history(
    db: Session,
    account: Account,
) -> MatchHistoryListResponse:
    owned_case_ids = (
        select(CaseAccount.case_id).where(CaseAccount.account_id == account.id).scalar_subquery()
    )
    matches = db.scalars(
        select(CaseMatch)
        .where(
            or_(
                CaseMatch.missing_case_id.in_(owned_case_ids),
                CaseMatch.found_case_id.in_(owned_case_ids),
            )
        )
        .order_by(CaseMatch.updated_at.desc(), CaseMatch.created_at.desc())
    ).all()
    results = [
        result
        for match in matches
        if (result := _match_history_out(db, match, account.id)) is not None
    ]
    return MatchHistoryListResponse(results=results)


def consent_to_connection(
    db: Session,
    *,
    connection_id: uuid.UUID,
    account: Account,
) -> ConnectionOut:
    connection = _participant_connection(db, connection_id, account.id)
    now = datetime.now(UTC)
    if account.id == connection.missing_account_id:
        connection.missing_consented_at = connection.missing_consented_at or now
    else:
        connection.found_consented_at = connection.found_consented_at or now

    if connection.missing_consented_at is not None and connection.found_consented_at is not None:
        connection.meeting_nonce = None
        connection.meeting_code_expires_at = None
        connection.missing_verified_peer_at = None
        connection.found_verified_peer_at = None
        connection.status = "connected"
    _mark_notification_read(db, connection.id, account.id, now)
    _audit(db, account, "connection_consented", connection.id)
    db.commit()
    db.refresh(connection)
    return _connection_out(db, connection, account.id)


def renew_meeting_codes(
    db: Session,
    *,
    connection_id: uuid.UUID,
    account: Account,
) -> ConnectionOut:
    _participant_connection(db, connection_id, account.id)
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="meeting-code verification is no longer available",
    )


def withdraw_connection_consent(
    db: Session,
    *,
    connection_id: uuid.UUID,
    account: Account,
) -> ConnectionOut:
    connection = _participant_connection(db, connection_id, account.id)
    if account.id == connection.missing_account_id:
        connection.missing_consented_at = None
    else:
        connection.found_consented_at = None
    connection.meeting_nonce = None
    connection.meeting_code_expires_at = None
    connection.missing_verified_peer_at = None
    connection.found_verified_peer_at = None
    connection.status = "pending_consent"
    _audit(db, account, "connection_consent_withdrawn", connection.id)
    db.commit()
    db.refresh(connection)
    return _connection_out(db, connection, account.id)


def verify_peer_meeting_code(
    db: Session,
    *,
    connection_id: uuid.UUID,
    account: Account,
    code: str,
) -> ConnectionOut:
    _participant_connection(db, connection_id, account.id)
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="meeting-code verification is no longer available",
    )


def mark_connection_read(
    db: Session,
    *,
    connection_id: uuid.UUID,
    account: Account,
) -> ConnectionOut:
    connection = _participant_connection(db, connection_id, account.id)
    _mark_notification_read(db, connection.id, account.id, datetime.now(UTC))
    db.commit()
    return _connection_out(db, connection, account.id)


def _participant_connection(
    db: Session,
    connection_id: uuid.UUID,
    account_id: uuid.UUID,
) -> MatchConnection:
    connection = db.get(MatchConnection, connection_id)
    if connection is None or account_id not in (
        connection.missing_account_id,
        connection.found_account_id,
    ):
        if connection is not None:
            record_event(
                db,
                "connection_access_rejected",
                account_id=account_id,
                data={"connection_id": str(connection_id)},
            )
            record_repeated_failure_risk(
                db,
                account_id=account_id,
                event_type="connection_access_rejected",
                risk_type="repeated_unauthorized_connection_access",
                data={"connection_id": str(connection_id)},
            )
            db.commit()
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="connection not found",
        )
    return connection


def _connection_out(
    db: Session,
    connection: MatchConnection,
    account_id: uuid.UUID,
) -> ConnectionOut:
    match = db.get(CaseMatch, connection.case_match_id)
    if match is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="match not found",
        )
    is_missing = account_id == connection.missing_account_id
    my_case_id = match.missing_case_id if is_missing else match.found_case_id
    other_case_id = match.found_case_id if is_missing else match.missing_case_id
    other_face_id = match.found_face_id if is_missing else match.missing_face_id
    other_case = db.get(CaseRecord, other_case_id)
    other_face = db.get(CaseFace, other_face_id)
    if other_case is None or other_face is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="matched case is unavailable",
        )
    notification = db.scalar(
        select(AccountNotification).where(
            AccountNotification.account_id == account_id,
            AccountNotification.connection_id == connection.id,
            AccountNotification.event_type == "match_found",
        )
    )
    my_consented = (
        connection.missing_consented_at is not None
        if is_missing
        else connection.found_consented_at is not None
    )
    other_consented = (
        connection.found_consented_at is not None
        if is_missing
        else connection.missing_consented_at is not None
    )
    my_account = db.get(Account, account_id)
    other_account_id = connection.found_account_id if is_missing else connection.missing_account_id
    other_account = db.get(Account, other_account_id)
    my_contact_sharing_consented = (
        my_account is not None and my_account.contact_sharing_consented_at is not None
    )
    other_contact_sharing_consented = (
        other_account is not None and other_account.contact_sharing_consented_at is not None
    )
    my_verified_peer = (
        connection.missing_verified_peer_at is not None
        if is_missing
        else connection.found_verified_peer_at is not None
    )
    other_verified_peer = (
        connection.found_verified_peer_at is not None
        if is_missing
        else connection.missing_verified_peer_at is not None
    )
    return ConnectionOut(
        id=connection.id,
        role=(ConnectionRole.missing if is_missing else ConnectionRole.found),
        status=connection.status,
        my_case_id=my_case_id,
        other_case_id=other_case_id,
        other_subject_label=other_case.subject_label,
        score=match.score,
        image_url=get_store().presigned_url(other_face.image_key),
        my_consented=my_consented,
        other_consented=other_consented,
        my_contact_sharing_consented=my_contact_sharing_consented,
        other_contact_sharing_consented=other_contact_sharing_consented,
        other_phone_number=(
            other_account.phone_number
            if my_contact_sharing_consented
            and other_contact_sharing_consented
            and other_account is not None
            else None
        ),
        my_verified_peer=my_verified_peer,
        other_verified_peer=other_verified_peer,
        unread=notification is not None and notification.read_at is None,
        meeting_code=None,
        meeting_code_expires_at=None,
        created_at=connection.created_at,
    )


def _match_history_out(
    db: Session,
    match: CaseMatch,
    account_id: uuid.UUID,
) -> MatchHistoryOut | None:
    missing_owner = db.get(CaseAccount, match.missing_case_id)
    found_owner = db.get(CaseAccount, match.found_case_id)
    missing_case = db.get(CaseRecord, match.missing_case_id)
    found_case = db.get(CaseRecord, match.found_case_id)
    if missing_owner is None or found_owner is None or missing_case is None or found_case is None:
        return None

    owns_missing = missing_owner.account_id == account_id
    owns_found = found_owner.account_id == account_id
    if not owns_missing and not owns_found:
        return None
    if owns_missing and owns_found:
        role = MatchHistoryRole.both
        image_face_id = match.found_face_id
    elif owns_missing:
        role = MatchHistoryRole.missing
        image_face_id = match.found_face_id
    else:
        role = MatchHistoryRole.found
        image_face_id = match.missing_face_id

    image_face = db.get(CaseFace, image_face_id)
    connection = db.scalar(select(MatchConnection).where(MatchConnection.case_match_id == match.id))
    return MatchHistoryOut(
        id=match.id,
        role=role,
        missing_case_id=match.missing_case_id,
        found_case_id=match.found_case_id,
        missing_subject_label=missing_case.subject_label,
        found_subject_label=found_case.subject_label,
        score=match.score,
        decision=match.decision,
        image_url=(
            get_store().presigned_url(image_face.image_key) if image_face is not None else None
        ),
        same_account=missing_owner.account_id == found_owner.account_id,
        connection_id=connection.id if connection is not None else None,
        connection_status=connection.status if connection is not None else None,
        created_at=match.updated_at or match.created_at,
    )


def _mark_notification_read(
    db: Session,
    connection_id: uuid.UUID,
    account_id: uuid.UUID,
    now: datetime,
) -> None:
    notification = db.scalar(
        select(AccountNotification).where(
            AccountNotification.account_id == account_id,
            AccountNotification.connection_id == connection_id,
            AccountNotification.event_type == "match_found",
        )
    )
    if notification is not None and notification.read_at is None:
        notification.read_at = now


def _audit(
    db: Session,
    account: Account,
    event_type: str,
    connection_id: uuid.UUID,
) -> None:
    db.add(
        AuditEvent(
            account_id=account.id,
            event_type=event_type,
            event_data={"connection_id": str(connection_id)},
        )
    )
