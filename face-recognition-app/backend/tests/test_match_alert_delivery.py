from types import SimpleNamespace

import pytest

from app import match_alert_delivery


def test_telnyx_match_alert_contains_only_safe_copy(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    sent: dict[str, object] = {}

    class FakeMessages:
        def send(self, **kwargs: object) -> SimpleNamespace:
            sent.update(kwargs)
            return SimpleNamespace(data=SimpleNamespace(id="message-123"))

    class FakeClient:
        messages = FakeMessages()

    monkeypatch.setattr(
        match_alert_delivery,
        "Telnyx",
        lambda *, api_key: FakeClient(),
    )
    settings = SimpleNamespace(
        telnyx_api_key="key",
        telnyx_match_alert_messaging_profile_id="profile",
        telnyx_match_alert_from="+12025550100",
    )

    message_id = match_alert_delivery.send_telnyx_match_alert(
        "+919000000001",
        idempotency_key="match-alert:connection:account",
        settings=settings,
    )

    assert message_id == "message-123"
    assert sent == {
        "from_": "+12025550100",
        "to": "+919000000001",
        "text": "Potential match—open ReuniteNow.",
        "type": "SMS",
        "messaging_profile_id": "profile",
        "idempotency_key": "match-alert:connection:account",
    }


def test_telnyx_match_alert_requires_messaging_configuration() -> None:
    settings = SimpleNamespace(
        telnyx_api_key="key",
        telnyx_match_alert_messaging_profile_id=None,
        telnyx_match_alert_from=None,
    )

    with pytest.raises(
        match_alert_delivery.MatchAlertDeliveryError,
        match="not configured",
    ):
        match_alert_delivery.send_telnyx_match_alert(
            "+919000000001",
            idempotency_key="match-alert:connection:account",
            settings=settings,
        )
