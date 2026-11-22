from concurrent.futures import ThreadPoolExecutor
from threading import Barrier, Lock
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


def test_firebase_app_initializes_once_for_concurrent_first_alerts(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    app = object()
    initialized = False
    initialize_calls = 0
    get_app_calls = 0
    state_lock = Lock()
    first_gets = Barrier(2)

    def get_app(name: str) -> object:
        nonlocal get_app_calls
        assert name == push_delivery.FIREBASE_APP_NAME
        with state_lock:
            get_app_calls += 1
            call_number = get_app_calls
            ready = initialized
        if call_number <= 2:
            first_gets.wait()
        if not ready:
            raise ValueError
        return app

    def initialize_app(credential: object, *, name: str) -> object:
        nonlocal initialize_calls, initialized
        assert credential is app
        assert name == push_delivery.FIREBASE_APP_NAME
        with state_lock:
            initialize_calls += 1
            initialized = True
        return app

    monkeypatch.setattr(push_delivery.firebase_admin, "get_app", get_app)
    monkeypatch.setattr(push_delivery.firebase_admin, "initialize_app", initialize_app)
    monkeypatch.setattr(push_delivery.credentials, "Certificate", lambda _: app)
    settings = SimpleNamespace(firebase_service_account_json="{}")

    with ThreadPoolExecutor(max_workers=2) as executor:
        results = list(executor.map(push_delivery._firebase_app, [settings, settings]))

    assert results == [app, app]
    assert initialize_calls == 1
