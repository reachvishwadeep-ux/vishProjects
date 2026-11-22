from types import SimpleNamespace

import pytest

from app import push_delivery


def test_firebase_match_alert_contains_only_safe_copy(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    captured: dict[str, object] = {}
    firebase_app = object()
    monkeypatch.setattr(
        push_delivery,
        "_firebase_app",
        lambda settings: firebase_app,
    )

    def send(message: object, *, app: object) -> str:
        captured["message"] = message
        captured["app"] = app
        return "firebase-message-123"

    monkeypatch.setattr(push_delivery.messaging, "send", send)

    message_id = push_delivery.send_firebase_match_alert(
        "firebase-installation-id",
        connection_id="connection-123",
        settings=SimpleNamespace(firebase_service_account_json="{}"),
    )

    message = captured["message"]
    assert message_id == "firebase-message-123"
    assert captured["app"] is firebase_app
    assert message.fid == "firebase-installation-id"
    assert message.notification.title == "ReuniteNow"
    assert message.notification.body == "Potential match—open ReuniteNow."
    assert message.data == {
        "type": "potential_match",
        "connection_id": "connection-123",
    }
    assert "score" not in message.data
    assert "phone" not in message.data
    assert "meeting" not in message.data


def test_firebase_credentials_are_required() -> None:
    with pytest.raises(
        push_delivery.PushDeliveryError,
        match="not configured",
    ):
        push_delivery._firebase_app(SimpleNamespace(firebase_service_account_json=None))
