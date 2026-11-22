import json
from threading import Lock
from typing import Protocol

import firebase_admin
from firebase_admin import credentials, messaging
from firebase_admin.exceptions import FirebaseError

PUSH_TITLE = "ReuniteNow"
PUSH_BODY = "Potential match—open ReuniteNow."
FIREBASE_APP_NAME = "reunitenow"
_FIREBASE_APP_LOCK = Lock()


class PushProviderSettings(Protocol):
    firebase_service_account_json: str | None


class PushDeliveryError(RuntimeError):
    pass


class InvalidPushFidError(PushDeliveryError):
    pass


def send_firebase_match_alert(
    fid: str,
    *,
    connection_id: str,
    settings: PushProviderSettings,
) -> str:
    message = messaging.Message(
        notification=messaging.Notification(
            title=PUSH_TITLE,
            body=PUSH_BODY,
        ),
        data={
            "type": "potential_match",
            "connection_id": connection_id,
        },
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(sound="default"),
        ),
        apns=messaging.APNSConfig(
            headers={"apns-priority": "10"},
            payload=messaging.APNSPayload(
                aps=messaging.Aps(sound="default"),
            ),
        ),
        fid=fid,
    )
    try:
        return messaging.send(message, app=_firebase_app(settings))
    except (messaging.UnregisteredError, messaging.SenderIdMismatchError) as exc:
        raise InvalidPushFidError("Firebase installation ID is no longer valid") from exc
    except FirebaseError as exc:
        raise PushDeliveryError("Firebase could not send the match alert") from exc


def _firebase_app(settings: PushProviderSettings) -> firebase_admin.App:
    if not settings.firebase_service_account_json:
        raise PushDeliveryError("Firebase push delivery is not configured")
    try:
        return firebase_admin.get_app(FIREBASE_APP_NAME)
    except ValueError:
        pass
    with _FIREBASE_APP_LOCK:
        try:
            return firebase_admin.get_app(FIREBASE_APP_NAME)
        except ValueError:
            pass
        try:
            service_account = json.loads(settings.firebase_service_account_json)
            credential = credentials.Certificate(service_account)
        except (json.JSONDecodeError, TypeError, ValueError) as exc:
            raise PushDeliveryError("Firebase credentials are invalid") from exc
        return firebase_admin.initialize_app(
            credential,
            name=FIREBASE_APP_NAME,
        )
