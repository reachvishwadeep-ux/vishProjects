from typing import Protocol

from telnyx import Telnyx, TelnyxError

MATCH_ALERT_TEXT = "Potential match—open ReuniteNow."


class MatchAlertProviderSettings(Protocol):
    telnyx_api_key: str | None
    telnyx_match_alert_messaging_profile_id: str | None
    telnyx_match_alert_from: str | None


class MatchAlertDeliveryError(RuntimeError):
    pass


def send_telnyx_match_alert(
    phone_number: str,
    *,
    idempotency_key: str,
    settings: MatchAlertProviderSettings,
) -> str:
    if not (
        settings.telnyx_api_key
        and settings.telnyx_match_alert_messaging_profile_id
        and settings.telnyx_match_alert_from
    ):
        raise MatchAlertDeliveryError("Telnyx match alerts are not configured")

    client = Telnyx(api_key=settings.telnyx_api_key)
    try:
        response = client.messages.send(
            from_=settings.telnyx_match_alert_from,
            to=phone_number,
            text=MATCH_ALERT_TEXT,
            type="SMS",
            messaging_profile_id=settings.telnyx_match_alert_messaging_profile_id,
            idempotency_key=idempotency_key,
        )
    except TelnyxError as exc:
        raise MatchAlertDeliveryError("Telnyx could not send the match alert") from exc

    message_id = getattr(response.data, "id", None)
    if not message_id:
        raise MatchAlertDeliveryError("Telnyx did not accept the match alert")
    return str(message_id)
