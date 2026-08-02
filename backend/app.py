import json
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

YOUTUBE_API_KEY = os.environ.get("YOUTUBE_API_KEY")
YOUTUBE_SEARCH_URL = "https://www.googleapis.com/youtube/v3/search"
# Premade ElevenLabs voice ("Rachel") used until the family clones their own
# via the Voice tab, so replies are spoken from first use instead of only
# after voice setup is complete.
DEFAULT_VOICE_ID = os.environ.get("ELEVENLABS_DEFAULT_VOICE_ID", "21m00Tcm4TlvDq8ikWAM")

DATA_DIR = Path(os.environ.get("AMMA_DATA_DIR", Path(__file__).parent))

MEDIA_DIR = DATA_DIR / "media"
MEDIA_DIR.mkdir(parents=True, exist_ok=True)
app.mount("/media", StaticFiles(directory=MEDIA_DIR), name="media")

# Serves cast_receiver.html — the custom Cast SDK receiver page the
# Chromecast loads and displays when Amma casts a video (see project plan:
# the reverse-engineered YouTube Lounge/DIAL approach was tested against a
# real Chromecast and confirmed broken, so casting goes through Google's
# official Cast SDK to this page instead).
STATIC_DIR = Path(__file__).parent / "static"
app.mount("/cast", StaticFiles(directory=STATIC_DIR), name="cast")

# Per-family state, kept in memory and mirrored to a JSON file on every write
# so a backend restart doesn't lose voice clones, consent, or family setup.
# Fine for a single-instance MVP; move to a real database before this needs
# to run on more than one box or handle concurrent writers.
conversations: dict[str, list[dict]] = defaultdict(list)
families: dict[str, dict] = {}

STATE_FILE = DATA_DIR / "state.json"


def load_state() -> None:
    if not STATE_FILE.exists():
        return
    try:
        data = json.loads(STATE_FILE.read_text())
    except (json.JSONDecodeError, OSError):
        return
    families.update(data.get("families", {}))
    for family_id, history in data.get("conversations", {}).items():
        conversations[family_id] = history


def save_state() -> None:
    STATE_FILE.write_text(json.dumps({"families": families, "conversations": conversations}))


load_state()


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
    parent_name: str | None = None
    child_name: str | None = None
    language: str = "en"
    child_phone_number: str | None = None


class VoiceSelectRequest(BaseModel):
    family_id: str
    voice_id: str


# A small curated set of ElevenLabs premade voices offered as a default,
# no-cloning-needed alternative to recording/uploading the child's actual
# voice — picking one just points the family at an existing public voice,
# no consent or ElevenLabs voice-creation call needed.
VOICE_PRESETS = [
    {"voice_id": "CwhRBWXzGAHq8TQ4Fs17", "name": "Roger", "description": "Laid-back, casual"},
    {"voice_id": "onwK4e9ZLuTAKqWW03F9", "name": "Daniel", "description": "Steady, broadcaster"},
    {"voice_id": "JBFqnCBsd6RMkjVDRZzb", "name": "George", "description": "Warm storyteller"},
    {"voice_id": "EXAVITQu4vr4xnSDxMaL", "name": "Sarah", "description": "Mature, reassuring"},
    {"voice_id": "cgSgspJ2msm6clMCkdW9", "name": "Jessica", "description": "Playful, bright"},
    {"voice_id": "Xb7hH8MSUJpSbSDYk0k2", "name": "Alice", "description": "Clear, engaging"},
]


LANGUAGE_INSTRUCTIONS = {
    "ta": (
        "Reply in casual, everyday spoken Tamil (Chennai-style), written in Tamil "
        "script — not formal or literary Tamil (no எழுத்துத் தமிழ், no textbook "
        "phrasing). Mix in common English words the way people actually text "
        "(e.g. \"call\", \"message\", \"okay\"), use casual particles like pa/ma/da, "
        "contractions, and the odd emoji, exactly like the sample chats you'd "
        "text a parent, not like a translated document."
    ),
    "en": (
        "Reply in casual, everyday English texting style — contractions, casual "
        "filler words, the odd emoji, like a real text message, not a formal or "
        "polished sentence."
    ),
}


def system_prompt(parent_name: str | None, child_name: str | None, language: str | None, has_tools: bool) -> str:
    parent = parent_name or "your parent"
    child = child_name or "their child"
    language_instruction = LANGUAGE_INSTRUCTIONS.get(language or "en", LANGUAGE_INSTRUCTIONS["en"])
    prompt = (
        f"You are standing in for {child}, texting {parent} the way {child} would: "
        "warm, brief, casual and informal, like a real quick text between family "
        "rather than an assistant response — never stiff, never formal. Reply in "
        "1-3 short sentences. Ask a small follow-up question when it feels "
        f"natural. Never mention that you are an AI. {language_instruction}"
    )
    if has_tools:
        prompt += (
            " Only use a tool when THIS message is itself a direct, "
            "unambiguous request for that specific action — never because "
            "an earlier message in the conversation asked for one. A "
            "greeting, small talk, or a check-in like \"how are you\" or "
            "\"did you eat\" should never trigger any tool, even if you "
            "placed a call or cast something a moment ago. When in doubt, "
            "don't call a tool — just reply warmly."
            f" If {parent} is clearly asking to call or message someone directly "
            "(not just chatting), use the matching tool. If they name a specific "
            f"person other than {child} (a friend, relative, anyone else), pass "
            "that person's name as contact_name so the app can look up their "
            f"number in {parent}'s phone contacts. If they just mean {child} "
            "without naming someone else, omit contact_name. Still include a "
            "brief in-character spoken line in the same reply, like you're "
            "letting them know you're on it — and since this hands off to "
            "another app, weave in a warm, natural reminder in the same "
            "breath to tap the small Amma link at the top of the screen "
            "afterward to come back (phrased casually, like a loving nudge, "
            "never like a technical instruction). If instead they clearly "
            "want to watch or listen to something on the TV (a song, a "
            "video, a show), use cast_media with a short search query "
            "describing what they asked for. If something is already "
            "playing on the TV and they ask to stop, pause, or turn it "
            "off, use stop_cast."
            f" None of the above changes what language you reply in — your "
            "spoken reply text must still follow the language instruction "
            "given earlier in this prompt, even on a turn where you're also "
            "using a tool. The only exception is the contact_name value "
            "itself, which is always Latin/English script regardless of "
            "reply language."
        )
    return prompt


CONTACT_NAME_PARAM = {
    "type": "string",
    "description": (
        "Name of the specific person to reach, if the parent named someone. "
        "Omit to default to the child. Always give this in Latin/English "
        "script and spelling (e.g. 'Geetha', not 'கீதா'), even if you're "
        "replying in Tamil — phone contact lists are saved in Latin script, "
        "and the app matches this name against them literally."
    ),
}


def build_tools(family: dict) -> list[dict]:
    return [
        {
            "name": "place_call",
            "description": (
                "Place a voice call — including 'call/phone/ring on WhatsApp'. "
                "Use this whenever the parent wants to actually talk to someone "
                "by voice, even if they say the word WhatsApp; the app itself "
                "decides whether that's a WhatsApp call or a regular call. Only "
                "use send_whatsapp_message instead when they want a text sent, "
                "not a call placed. Their child by default, or anyone they name."
            ),
            "input_schema": {
                "type": "object",
                "properties": {"contact_name": CONTACT_NAME_PARAM},
                "required": [],
            },
        },
        {
            "name": "send_whatsapp_message",
            "description": (
                "Send a WhatsApp text message on the parent's behalf. Use only "
                "when they want to message, text, or write to someone — not "
                "when they want to call/phone/ring/speak to them (use "
                "place_call for that, even if they mention WhatsApp). Their "
                "child by default, or anyone else they name."
            ),
            "input_schema": {
                "type": "object",
                "properties": {
                    "text": {
                        "type": "string",
                        "description": "A short message body to send, written as the parent would say it.",
                    },
                    "contact_name": CONTACT_NAME_PARAM,
                },
                "required": ["text"],
            },
        },
        {
            "name": "cast_media",
            "description": (
                "Cast a video to the TV. Use when the parent asks to watch, "
                "play, or listen to something on the TV — a song, a video, "
                "a show, an artist. Not for calls or messages."
            ),
            "input_schema": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "A short search query describing what to play, phrased the way you'd search YouTube for it.",
                    },
                },
                "required": ["query"],
            },
        },
        {
            "name": "stop_cast",
            "description": (
                "Stop whatever is currently playing on the TV. Use when the "
                "parent asks to stop, pause, or turn off what's casting."
            ),
            "input_schema": {"type": "object", "properties": {}, "required": []},
        },
    ]


def resolve_youtube_video(query: str) -> dict | None:
    if not YOUTUBE_API_KEY:
        return None
    try:
        response = requests.get(
            YOUTUBE_SEARCH_URL,
            params={
                "key": YOUTUBE_API_KEY,
                "q": query,
                "part": "snippet",
                "type": "video",
                "maxResults": 1,
            },
            timeout=10,
        )
        if response.status_code >= 400:
            return None
        items = response.json().get("items", [])
        if not items:
            return None
        item = items[0]
        return {
            "videoId": item["id"]["videoId"],
            "title": item["snippet"]["title"],
        }
    except (requests.RequestException, KeyError):
        return None


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
        if tool_use.name == "cast_media":
            video = resolve_youtube_video(tool_use.input.get("query", ""))
            if video is None:
                reply_text = "Hmm, couldn't find that one to play — try asking a bit differently?"
            else:
                action = {
                    "id": str(uuid.uuid4()),
                    "familyId": req.family_id,
                    "intent": "castMedia",
                    "params": video,
                    "status": "pending",
                }
        elif tool_use.name == "stop_cast":
            action = {
                "id": str(uuid.uuid4()),
                "familyId": req.family_id,
                "intent": "stopCast",
                "params": {},
                "status": "pending",
            }
        else:
            contact_name = tool_use.input.get("contact_name") or None
            # A named contact is resolved on-device (its number never reaches
            # this server); otherwise fall back to the child's saved number.
            # Never emit a null value — the iOS side decodes params as
            # [String: String].
            if contact_name:
                params = {"contactName": contact_name}
            elif family.get("child_phone_number"):
                params = {"phoneNumber": family["child_phone_number"]}
            else:
                params = {}
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
    save_state()

    reply_audio_url = None
    voice_id = family.get("voice_id") or DEFAULT_VOICE_ID
    audio_bytes = synthesize_speech(voice_id, reply_text)
    if audio_bytes:
        filename = f"{uuid.uuid4()}.mp3"
        (MEDIA_DIR / filename).write_bytes(audio_bytes)
        # Railway (and most PaaS hosts) terminate TLS at the edge and proxy
        # to the container over plain HTTP, so request.url.scheme reports
        # "http" even though the public URL is https — trust the proxy's
        # X-Forwarded-Proto instead, so the reply URL doesn't get blocked by
        # iOS's ATS when it's actually https externally.
        scheme = request.headers.get("x-forwarded-proto", request.url.scheme)
        reply_audio_url = f"{scheme}://{request.url.netloc}/media/{filename}"

    return InteractionReply(reply_text=reply_text, reply_audio_url=reply_audio_url, action=action)


@app.post("/v1/family-setup")
def setup_family(req: FamilySetupRequest) -> dict:
    family = families.setdefault(req.family_id, {})
    # Names are only overwritten when provided, so a partial update (e.g. the
    # Devices tab saving just a phone number) can't blank out existing values.
    if req.parent_name:
        family["parent_name"] = req.parent_name
    if req.child_name:
        family["child_name"] = req.child_name
    family["language"] = req.language
    family["child_phone_number"] = req.child_phone_number
    save_state()
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
    save_state()
    return {
        "granted_at": family.get("voice_consent_granted_at"),
        "revoked_at": family.get("voice_consent_revoked_at"),
    }


PRESET_VOICE_IDS = {preset["voice_id"] for preset in VOICE_PRESETS}


@app.get("/v1/voice-presets")
def voice_presets() -> dict:
    return {"presets": VOICE_PRESETS}


@app.post("/v1/voice-select")
def select_voice(req: VoiceSelectRequest) -> dict:
    family = families.setdefault(req.family_id, {})

    # Free up the old cloned voice's quota slot if switching away from one
    # (never try to delete a preset — it isn't ours to delete, and doesn't
    # count against the family's custom-voice usage anyway).
    old_voice_id = family.get("voice_id")
    if old_voice_id and old_voice_id != req.voice_id and old_voice_id not in PRESET_VOICE_IDS and ELEVENLABS_API_KEY:
        try:
            requests.delete(
                f"{ELEVENLABS_BASE}/voices/{old_voice_id}",
                headers={"xi-api-key": ELEVENLABS_API_KEY},
                timeout=30,
            )
        except requests.RequestException:
            pass

    family["voice_id"] = req.voice_id
    save_state()
    return {"status": "ok"}


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

    # Delete the family's previous cloned voice now that the new one exists
    # — otherwise every re-recording eats into ElevenLabs' fixed 10-voice
    # custom-voice quota permanently. Confirmed live: repeated test
    # re-uploads across sessions silently piled up until the account hit
    # the cap and every future upload failed with a 502. Best-effort: if
    # this fails, the new voice still works, it just leaves the old one
    # behind rather than blocking the request.
    old_voice_id = family.get("voice_id")
    if old_voice_id and old_voice_id != voice_id and old_voice_id not in PRESET_VOICE_IDS:
        try:
            requests.delete(
                f"{ELEVENLABS_BASE}/voices/{old_voice_id}",
                headers={"xi-api-key": ELEVENLABS_API_KEY},
                timeout=30,
            )
        except requests.RequestException:
            pass

    family["voice_id"] = voice_id
    save_state()
    return {"voice_id": voice_id}


@app.post("/v1/transcribe")
async def transcribe_audio(audio: UploadFile = File(...)) -> dict:
    if not ELEVENLABS_API_KEY:
        raise HTTPException(status_code=503, detail="ELEVENLABS_API_KEY is not configured on the server")

    audio_bytes = await audio.read()
    response = requests.post(
        f"{ELEVENLABS_BASE}/speech-to-text",
        headers={"xi-api-key": ELEVENLABS_API_KEY},
        data={"model_id": "scribe_v1"},
        files={"file": (audio.filename or "recording.m4a", audio_bytes, audio.content_type or "audio/m4a")},
        timeout=60,
    )
    if response.status_code >= 400:
        raise HTTPException(status_code=502, detail=f"ElevenLabs transcription failed: {response.text}")

    transcript = response.json().get("text", "")
    return {"transcript": transcript}


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}
