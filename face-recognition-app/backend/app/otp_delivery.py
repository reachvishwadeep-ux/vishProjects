from typing import Protocol

from telnyx import NotFoundError, Telnyx, TelnyxError
from twilio.base.exceptions import TwilioException, TwilioRestException
from twilio.rest import Client


class OtpProviderSettings(Protocol):
    telnyx_api_key: str | None
    telnyx_verify_profile_id: str | None
    twilio_account_sid: str | None
    twilio_auth_token: str | None
    twilio_verify_service_sid: str | None


class OtpDeliveryError(RuntimeError):
    pass


def send_twilio_verification(
    phone_number: str,
    settings: OtpProviderSettings,
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
    settings: OtpProviderSettings,
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


def send_telnyx_verification(
    phone_number: str,
    settings: OtpProviderSettings,
) -> str:
    client, profile_id = _telnyx_client(settings)
    try:
        verification = client.verifications.trigger_sms(
            phone_number=phone_number,
            verify_profile_id=profile_id,
        )
    except TelnyxError as exc:
        raise OtpDeliveryError("Telnyx Verify could not send the OTP") from exc

    data = verification.data
    if data.status not in {"accepted", "pending"} or not data.id:
        raise OtpDeliveryError("Telnyx Verify did not accept the OTP request")
    return str(data.id)


def check_telnyx_verification(
    phone_number: str,
    code: str,
    settings: OtpProviderSettings,
) -> bool:
    client, profile_id = _telnyx_client(settings)
    try:
        verification = client.verifications.by_phone_number.actions.verify(
            phone_number,
            code=code,
            verify_profile_id=profile_id,
        )
    except NotFoundError:
        return False
    except TelnyxError as exc:
        raise OtpDeliveryError("Telnyx Verify could not check the OTP") from exc
    return verification.data.response_code == "accepted"


def _twilio_client(settings: OtpProviderSettings) -> tuple[Client, str]:
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


def _telnyx_client(settings: OtpProviderSettings) -> tuple[Telnyx, str]:
    if not (settings.telnyx_api_key and settings.telnyx_verify_profile_id):
        raise OtpDeliveryError("Telnyx Verify is not configured")
    return Telnyx(api_key=settings.telnyx_api_key), settings.telnyx_verify_profile_id
