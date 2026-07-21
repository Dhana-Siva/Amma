import uuid
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest
from fastapi.testclient import TestClient

import app as app_module

client = TestClient(app_module.app)


@pytest.fixture(autouse=True)
def isolate_state(tmp_path, monkeypatch):
    # Every test gets its own on-disk state file so nothing here ever
    # touches the real backend/state.json used by the running app.
    monkeypatch.setattr(app_module, "STATE_FILE", tmp_path / "state.json")
    monkeypatch.setattr(app_module, "ELEVENLABS_API_KEY", "test-elevenlabs-key")


@pytest.fixture
def family_id():
    return str(uuid.uuid4())


def text_block(text):
    return SimpleNamespace(type="text", text=text)


def tool_use_block(name, input_):
    return SimpleNamespace(type="tool_use", name=name, input=input_)


def mock_claude_reply(monkeypatch, blocks):
    mock = MagicMock(return_value=SimpleNamespace(content=blocks))
    monkeypatch.setattr(app_module.client.messages, "create", mock)
    return mock


def mock_elevenlabs_tts(monkeypatch):
    captured = {}

    def fake_post(url, **kwargs):
        captured["url"] = url
        return SimpleNamespace(status_code=200, content=b"fake-mp3-bytes")

    monkeypatch.setattr(app_module.requests, "post", fake_post)
    return captured


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_build_tools_empty_without_phone_number():
    assert app_module.build_tools({}) == []
    assert app_module.build_tools({"child_phone_number": None}) == []


def test_build_tools_present_with_phone_number():
    tools = app_module.build_tools({"child_phone_number": "+15551234567"})
    assert {tool["name"] for tool in tools} == {"place_call", "send_whatsapp_message"}


def test_interaction_speaks_with_default_voice_when_no_clone(monkeypatch, family_id):
    mock_claude_reply(monkeypatch, [text_block("Hi Amma, I'm good!")])
    captured = mock_elevenlabs_tts(monkeypatch)

    response = client.post("/v1/interactions", json={"family_id": family_id, "transcript": "hi"})

    assert response.status_code == 200
    data = response.json()
    assert data["reply_text"] == "Hi Amma, I'm good!"
    assert data["reply_audio_url"] is not None
    assert data["action"] is None
    assert app_module.DEFAULT_VOICE_ID in captured["url"]


def test_interaction_uses_cloned_voice_once_set(monkeypatch, family_id):
    app_module.families[family_id] = {"voice_id": "cloned-voice-123"}
    mock_claude_reply(monkeypatch, [text_block("Hey!")])
    captured = mock_elevenlabs_tts(monkeypatch)

    client.post("/v1/interactions", json={"family_id": family_id, "transcript": "hi"})

    assert "cloned-voice-123" in captured["url"]


def test_interaction_no_audio_when_elevenlabs_not_configured(monkeypatch, family_id):
    monkeypatch.setattr(app_module, "ELEVENLABS_API_KEY", None)
    mock_claude_reply(monkeypatch, [text_block("Hello")])

    response = client.post("/v1/interactions", json={"family_id": family_id, "transcript": "hi"})

    assert response.json()["reply_audio_url"] is None


def test_interaction_no_tools_offered_without_phone_number(monkeypatch, family_id):
    create_mock = mock_claude_reply(monkeypatch, [text_block("Sure!")])
    mock_elevenlabs_tts(monkeypatch)

    client.post("/v1/interactions", json={"family_id": family_id, "transcript": "call my son"})

    _, kwargs = create_mock.call_args
    assert "tools" not in kwargs


def test_interaction_places_call(monkeypatch, family_id):
    client.post("/v1/family-setup", json={"family_id": family_id, "child_phone_number": "+15551234567"})
    mock_claude_reply(monkeypatch, [text_block("Calling now!"), tool_use_block("place_call", {})])
    mock_elevenlabs_tts(monkeypatch)

    response = client.post("/v1/interactions", json={"family_id": family_id, "transcript": "call my son"})

    action = response.json()["action"]
    assert action["intent"] == "placeCall"
    assert action["params"]["phoneNumber"] == "+15551234567"


def test_interaction_sends_whatsapp_message(monkeypatch, family_id):
    client.post("/v1/family-setup", json={"family_id": family_id, "child_phone_number": "+15551234567"})
    mock_claude_reply(monkeypatch, [tool_use_block("send_whatsapp_message", {"text": "Miss you!"})])
    mock_elevenlabs_tts(monkeypatch)

    response = client.post("/v1/interactions", json={"family_id": family_id, "transcript": "whatsapp my son"})

    data = response.json()
    action = data["action"]
    assert action["intent"] == "sendMessage"
    assert action["params"]["text"] == "Miss you!"
    assert action["params"]["phoneNumber"] == "+15551234567"
    # No text block in the reply, so it falls back to a generic in-progress line.
    assert data["reply_text"] == "Okay, doing that now."


def test_family_setup_partial_update_preserves_existing_names(family_id):
    client.post("/v1/family-setup", json={
        "family_id": family_id, "parent_name": "Amma", "child_name": "Kutty", "language": "en",
    })

    response = client.post("/v1/family-setup", json={
        "family_id": family_id, "child_phone_number": "+15559998888",
    })

    assert response.status_code == 200
    family = app_module.families[family_id]
    assert family["parent_name"] == "Amma"
    assert family["child_name"] == "Kutty"
    assert family["child_phone_number"] == "+15559998888"


def test_state_persists_across_reload(tmp_path, monkeypatch, family_id):
    state_file = tmp_path / "state.json"
    monkeypatch.setattr(app_module, "STATE_FILE", state_file)

    client.post("/v1/family-setup", json={
        "family_id": family_id, "parent_name": "Amma", "child_name": "Kutty",
        "language": "en", "child_phone_number": "+15551234567",
    })
    assert state_file.exists()

    # Simulate a backend restart: drop the in-memory copy, then reload from disk.
    del app_module.families[family_id]
    app_module.load_state()

    assert app_module.families[family_id]["child_phone_number"] == "+15551234567"


def test_consent_flow(family_id):
    response = client.post("/v1/consent", json={"family_id": family_id, "granted": True})
    assert response.status_code == 200
    assert response.json()["granted_at"] is not None
    assert response.json()["revoked_at"] is None

    response = client.post("/v1/consent", json={"family_id": family_id, "granted": False})
    assert response.json()["revoked_at"] is not None
