from types import SimpleNamespace

import httpx
import pytest
from telnyx import NotFoundError, TelnyxError
from twilio.base.exceptions import TwilioRestException

from app import otp_delivery


class FakeCreateResource:
    def __init__(self, result: object | None = None, error: Exception | None = None):
        self.result = result
        self.error = error
        self.calls: list[dict[str, str]] = []

    def create(self, **kwargs: str) -> object:
        self.calls.append(kwargs)
        if self.error is not None:
            raise self.error
        return self.result


class FakeServices:
    def __init__(
        self,
        verification_result: object | None = None,
        check_result: object | None = None,
        verification_error: Exception | None = None,
        check_error: Exception | None = None,
    ):
        self.verifications = FakeCreateResource(
            verification_result,
            verification_error,
        )
        self.verification_checks = FakeCreateResource(check_result, check_error)
        self.service_sids: list[str] = []

    def __call__(self, service_sid: str) -> "FakeServices":
        self.service_sids.append(service_sid)
        return self


def settings() -> SimpleNamespace:
    return SimpleNamespace(
        telnyx_api_key="KEYtest",
        telnyx_verify_profile_id="profile-test",
        twilio_account_sid="ACtest",
        twilio_auth_token="test-token",
        twilio_verify_service_sid="VAtest",
    )


def install_client(monkeypatch, services: FakeServices) -> None:
    client = SimpleNamespace(verify=SimpleNamespace(v2=SimpleNamespace(services=services)))
    monkeypatch.setattr(
        otp_delivery,
        "Client",
        lambda account_sid, auth_token: client,
    )


class FakeTelnyxActions:
    def __init__(self, result: object | None = None, error: Exception | None = None):
        self.result = result
        self.error = error
        self.calls: list[tuple[tuple[object, ...], dict[str, object]]] = []

    def verify(self, *args: object, **kwargs: object) -> object:
        self.calls.append((args, kwargs))
        if self.error is not None:
            raise self.error
        return self.result


class FakeTelnyxVerifications:
    def __init__(
        self,
        send_result: object | None = None,
        check_result: object | None = None,
        send_error: Exception | None = None,
        check_error: Exception | None = None,
    ):
        self.send_result = send_result
        self.send_error = send_error
        self.send_calls: list[dict[str, object]] = []
        self.by_phone_number = SimpleNamespace(actions=FakeTelnyxActions(check_result, check_error))

    def trigger_sms(self, **kwargs: object) -> object:
        self.send_calls.append(kwargs)
        if self.send_error is not None:
            raise self.send_error
        return self.send_result


def install_telnyx_client(
    monkeypatch,
    verifications: FakeTelnyxVerifications,
) -> None:
    client = SimpleNamespace(verifications=verifications)
    monkeypatch.setattr(
        otp_delivery,
        "Telnyx",
        lambda api_key: client,
    )


def test_sends_and_checks_twilio_verification(monkeypatch) -> None:
    services = FakeServices(
        verification_result=SimpleNamespace(status="pending", sid="VEtest"),
        check_result=SimpleNamespace(status="approved"),
    )
    install_client(monkeypatch, services)

    verification_sid = otp_delivery.send_twilio_verification(
        "+12025550100",
        settings(),
    )
    approved = otp_delivery.check_twilio_verification(
        "+12025550100",
        "123456",
        settings(),
    )

    assert verification_sid == "VEtest"
    assert approved is True
    assert services.service_sids == ["VAtest", "VAtest"]
    assert services.verifications.calls == [{"to": "+12025550100", "channel": "sms"}]
    assert services.verification_checks.calls == [{"to": "+12025550100", "code": "123456"}]


def test_sends_and_checks_telnyx_verification(monkeypatch) -> None:
    verifications = FakeTelnyxVerifications(
        send_result=SimpleNamespace(
            data=SimpleNamespace(status="accepted", id="verification-test")
        ),
        check_result=SimpleNamespace(data=SimpleNamespace(response_code="accepted")),
    )
    install_telnyx_client(monkeypatch, verifications)

    verification_id = otp_delivery.send_telnyx_verification(
        "+12025550100",
        settings(),
    )
    approved = otp_delivery.check_telnyx_verification(
        "+12025550100",
        "123456",
        settings(),
    )

    assert verification_id == "verification-test"
    assert approved is True
    assert verifications.send_calls == [
        {
            "phone_number": "+12025550100",
            "verify_profile_id": "profile-test",
        }
    ]
    assert verifications.by_phone_number.actions.calls == [
        (
            ("+12025550100",),
            {"code": "123456", "verify_profile_id": "profile-test"},
        )
    ]


def test_missing_twilio_configuration_is_rejected() -> None:
    configured = settings()
    configured.twilio_auth_token = None

    with pytest.raises(otp_delivery.OtpDeliveryError):
        otp_delivery.send_twilio_verification("+12025550100", configured)


def test_missing_telnyx_configuration_is_rejected() -> None:
    configured = settings()
    configured.telnyx_api_key = None

    with pytest.raises(otp_delivery.OtpDeliveryError):
        otp_delivery.send_telnyx_verification("+12025550100", configured)


def test_expired_twilio_verification_is_rejected(monkeypatch) -> None:
    services = FakeServices(
        check_error=TwilioRestException(
            status=404,
            uri="/VerificationCheck",
            msg="not found",
        )
    )
    install_client(monkeypatch, services)

    assert (
        otp_delivery.check_twilio_verification(
            "+12025550100",
            "123456",
            settings(),
        )
        is False
    )


def test_expired_telnyx_verification_is_rejected(monkeypatch) -> None:
    request = httpx.Request("POST", "https://api.telnyx.com/v2/verifications")
    response = httpx.Response(404, request=request)
    verifications = FakeTelnyxVerifications(
        check_error=NotFoundError(
            "not found",
            response=response,
            body=None,
        )
    )
    install_telnyx_client(monkeypatch, verifications)

    assert (
        otp_delivery.check_telnyx_verification(
            "+12025550100",
            "123456",
            settings(),
        )
        is False
    )


def test_twilio_service_error_is_sanitized(monkeypatch) -> None:
    services = FakeServices(
        verification_error=TwilioRestException(
            status=503,
            uri="/Verifications",
            msg="provider details",
        )
    )
    install_client(monkeypatch, services)

    with pytest.raises(
        otp_delivery.OtpDeliveryError,
        match="could not send",
    ):
        otp_delivery.send_twilio_verification("+12025550100", settings())


def test_telnyx_service_error_is_sanitized(monkeypatch) -> None:
    verifications = FakeTelnyxVerifications(send_error=TelnyxError("provider details"))
    install_telnyx_client(monkeypatch, verifications)

    with pytest.raises(
        otp_delivery.OtpDeliveryError,
        match="could not send",
    ):
        otp_delivery.send_telnyx_verification("+12025550100", settings())
