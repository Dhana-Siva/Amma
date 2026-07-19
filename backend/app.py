import os
import uuid
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

import anthropic
import requests
from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

app = FastAPI()
client = anthropic.Anthropic()

MODEL = "claude-opus-4-8"
MAX_HISTORY_TURNS = 10

ELEVENLABS_API_KEY = os.environ.get("ELEVENLABS_API_KEY")
ELEVENLABS_BASE = "https://api.elevenlabs.io/v1"

MEDIA_DIR = Path(__file__).parent / "media"
MEDIA_DIR.mkdir(exist_ok=True)
app.mount("/media", StaticFiles(directory=MEDIA_DIR), name="media")

# In-memory per-family state. Fine for a single-instance MVP; move to a real
# store before this needs to survive a restart or run on more than one box.
conversations: dict[str, list[dict]] = defaultdict(list)
families: dict[str, dict] = {}


class InteractionRequest(BaseModel):
    family_id: str
    transcript: str
    channel: str = "tap"
    parent_name: str | None = None
    child_name: str | None = None


class InteractionReply(BaseModel):
    reply_text: str
    reply_audio_url: str | None = None
    action: dict | None = None


class ConsentRequest(BaseModel):
    family_id: str
    granted: bool


class FamilySetupRequest(BaseModel):
    family_id: str
    parent_name: str
    child_name: str
    language: str = "en"
    child_phone_number: str | None = None


LANGUAGE_INSTRUCTIONS = {
    "ta": "Reply only in warm, everyday spoken Tamil, written in Tamil script.",
    "en": "Reply only in English.",
}


def system_prompt(parent_name: str | None, child_name: str | None, language: str | None, has_tools: bool) -> str:
    parent = parent_name or "your parent"
    child = child_name or "their child"
    language_instruction = LANGUAGE_INSTRUCTIONS.get(language or "en", LANGUAGE_INSTRUCTIONS["en"])
    prompt = (
        f"You are standing in for {child}, texting {parent} the way {child} would: "
        "warm, brief, a little informal, like a real check-in message rather than "
        "an assistant response. Reply in 1-3 short sentences. Ask a small follow-up "
        f"question when it feels natural. Never mention that you are an AI. {language_instruction}"
    )
    if has_tools:
        prompt += (
            f" If {parent} is clearly asking to call or message {child} directly "
            "(not just chatting), use the matching tool. Still include a brief "
            "in-character spoken line in the same reply, like you're letting them "
            "know you're on it."
        )
    return prompt


def build_tools(family: dict) -> list[dict]:
    if not family.get("child_phone_number"):
        return []
    return [
        {
            "name": "place_call",
            "description": (
                "Place a phone call to the child. Use when the parent clearly asks "
                "to call, phone, or speak directly to their child."
            ),
            "input_schema": {"type": "object", "properties": {}, "required": []},
        },
        {
            "name": "send_whatsapp_message",
            "description": (
                "Send a WhatsApp message to the child on the parent's behalf. Use "
                "when the parent asks to message, text, or WhatsApp their child."
            ),
            "input_schema": {
                "type": "object",
                "properties": {
                    "text": {
                        "type": "string",
                        "description": "A short message body to send, written as the parent would say it.",
                    }
                },
                "required": ["text"],
            },
        },
    ]


def synthesize_speech(voice_id: str, text: str) -> bytes | None:
    if not ELEVENLABS_API_KEY:
        return None
    try:
        response = requests.post(
            f"{ELEVENLABS_BASE}/text-to-speech/{voice_id}",
            headers={"xi-api-key": ELEVENLABS_API_KEY, "Content-Type": "application/json"},
            json={"text": text, "model_id": "eleven_multilingual_v2"},
            timeout=30,
        )
        if response.status_code >= 400:
            return None
        return response.content
    except requests.RequestException:
        return None


@app.post("/v1/interactions", response_model=InteractionReply)
def create_interaction(req: InteractionRequest, request: Request) -> InteractionReply:
    family = families.setdefault(
        req.family_id, {"parent_name": req.parent_name, "child_name": req.child_name}
    )
    parent_name = req.parent_name or family.get("parent_name")
    child_name = req.child_name or family.get("child_name")
    family["parent_name"] = parent_name
    family["child_name"] = child_name

    history = conversations[req.family_id]
    history.append({"role": "user", "content": req.transcript})

    tools = build_tools(family)
    create_kwargs = dict(
        model=MODEL,
        max_tokens=300,
        system=system_prompt(parent_name, child_name, family.get("language"), bool(tools)),
        messages=history[-MAX_HISTORY_TURNS:],
    )
    if tools:
        create_kwargs["tools"] = tools
    response = client.messages.create(**create_kwargs)

    reply_text = next(
        (block.text for block in response.content if block.type == "text"), ""
    )
    tool_use = next(
        (block for block in response.content if block.type == "tool_use"), None
    )

    action = None
    if tool_use is not None:
        reply_text = reply_text or "Okay, doing that now."
        params = {"phoneNumber": family["child_phone_number"]}
        if tool_use.name == "send_whatsapp_message":
            intent = "sendMessage"
            params["text"] = tool_use.input.get("text", "")
        else:
            intent = "placeCall"
        action = {
            "id": str(uuid.uuid4()),
            "familyId": req.family_id,
            "intent": intent,
            "params": params,
            "status": "pending",
        }

    history.append({"role": "assistant", "content": reply_text})

    reply_audio_url = None
    voice_id = family.get("voice_id")
    if voice_id:
        audio_bytes = synthesize_speech(voice_id, reply_text)
        if audio_bytes:
            filename = f"{uuid.uuid4()}.mp3"
            (MEDIA_DIR / filename).write_bytes(audio_bytes)
            reply_audio_url = f"{request.base_url}media/{filename}"

    return InteractionReply(reply_text=reply_text, reply_audio_url=reply_audio_url, action=action)


@app.post("/v1/family-setup")
def setup_family(req: FamilySetupRequest) -> dict:
    family = families.setdefault(req.family_id, {})
    family["parent_name"] = req.parent_name
    family["child_name"] = req.child_name
    family["language"] = req.language
    family["child_phone_number"] = req.child_phone_number
    return {"status": "ok"}


@app.post("/v1/consent")
def set_consent(req: ConsentRequest) -> dict:
    family = families.setdefault(req.family_id, {})
    now = datetime.now(timezone.utc).isoformat()
    if req.granted:
        family["voice_consent_granted_at"] = now
        family["voice_consent_revoked_at"] = None
    else:
        family["voice_consent_revoked_at"] = now
    return {
        "granted_at": family.get("voice_consent_granted_at"),
        "revoked_at": family.get("voice_consent_revoked_at"),
    }


@app.post("/v1/voice-samples")
async def upload_voice_sample(family_id: str = Form(...), audio: UploadFile = File(...)) -> dict:
    family = families.setdefault(family_id, {})
    if not family.get("voice_consent_granted_at") or family.get("voice_consent_revoked_at"):
        raise HTTPException(status_code=403, detail="Voice consent has not been granted for this family")
    if not ELEVENLABS_API_KEY:
        raise HTTPException(status_code=503, detail="ELEVENLABS_API_KEY is not configured on the server")

    audio_bytes = await audio.read()
    response = requests.post(
        f"{ELEVENLABS_BASE}/voices/add",
        headers={"xi-api-key": ELEVENLABS_API_KEY},
        data={"name": f"amma-{family_id}"},
        files={"files": (audio.filename or "sample.m4a", audio_bytes, audio.content_type or "audio/m4a")},
        timeout=60,
    )
    if response.status_code >= 400:
        raise HTTPException(status_code=502, detail=f"ElevenLabs voice creation failed: {response.text}")

    voice_id = response.json()["voice_id"]
    family["voice_id"] = voice_id
    return {"voice_id": voice_id}


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}
