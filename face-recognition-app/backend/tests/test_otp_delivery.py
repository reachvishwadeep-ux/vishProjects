from types import SimpleNamespace

import pytest
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


def test_missing_twilio_configuration_is_rejected() -> None:
    configured = settings()
    configured.twilio_auth_token = None

    with pytest.raises(otp_delivery.OtpDeliveryError):
        otp_delivery.send_twilio_verification("+12025550100", configured)


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
