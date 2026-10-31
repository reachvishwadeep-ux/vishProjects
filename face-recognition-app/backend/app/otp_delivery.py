from typing import Protocol

from twilio.base.exceptions import TwilioException, TwilioRestException
from twilio.rest import Client


class TwilioSettings(Protocol):
    twilio_account_sid: str | None
    twilio_auth_token: str | None
    twilio_verify_service_sid: str | None


class OtpDeliveryError(RuntimeError):
    pass


def send_twilio_verification(
    phone_number: str,
    settings: TwilioSettings,
) -> str:
    client, service_sid = _twilio_client(settings)
    try:
        verification = client.verify.v2.services(service_sid).verifications.create(
            to=phone_number, channel="sms"
        )
    except TwilioException as exc:
        raise OtpDeliveryError("Twilio Verify could not send the OTP") from exc

    if verification.status != "pending" or not verification.sid:
        raise OtpDeliveryError("Twilio Verify did not accept the OTP request")
    return str(verification.sid)


def check_twilio_verification(
    phone_number: str,
    code: str,
    settings: TwilioSettings,
) -> bool:
    client, service_sid = _twilio_client(settings)
    try:
        verification = client.verify.v2.services(service_sid).verification_checks.create(
            to=phone_number, code=code
        )
    except TwilioException as exc:
        if isinstance(exc, TwilioRestException) and exc.status == 404:
            return False
        raise OtpDeliveryError("Twilio Verify could not check the OTP") from exc
    return verification.status == "approved"


def _twilio_client(settings: TwilioSettings) -> tuple[Client, str]:
    if not (
        settings.twilio_account_sid
        and settings.twilio_auth_token
        and settings.twilio_verify_service_sid
    ):
        raise OtpDeliveryError("Twilio Verify is not configured")
    return (
        Client(settings.twilio_account_sid, settings.twilio_auth_token),
        settings.twilio_verify_service_sid,
    )
