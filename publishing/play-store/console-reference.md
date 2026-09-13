# Play Console submission reference

Everything below is for filling in the Play Console forms yourself — I can't
submit these on your behalf, but this should make it fast.

## App bundle to upload

`android/app/build/outputs/bundle/release/app-release.aab`
(rebuild first with `./gradlew bundleRelease` if you've made any code changes
since this was generated — rebuilt 2026-09-13 to include the AI
disclosure screen below; the one on disk right now already has it)

**2026-09-13**: added an AI data-sharing disclosure step to onboarding
(`AIDisclosureContent.kt`, shown right after names, before the calling-app
picker) — Android never had one before, only the narrower voice-cloning
consent screen. This mirrors a fix already made on iOS after Apple
rejected a build for exactly this gap (Guideline 5.1.2(i)/5.1.1(i)) —
doing it proactively here since this is Android's first-ever submission
and there's no reason to invite the same issue.

## Store listing

- **App name**: Amma Appa Arugil - AAA
- **Short description**: see `listing.txt`
- **Full description**: see `listing.txt`
- **App icon**: `icon-512x512.png`
- **Feature graphic**: `feature-graphic-1024x500.png`
- **Screenshots**: `screenshot-1-talk.png`, `screenshot-2-voice.png`, `screenshot-3-devices.png`
- **Privacy policy URL**: https://dhana-siva.github.io/Amma/
  (was `amma-cast-receiver/privacy.html` — that page covered the same
  Anthropic/ElevenLabs disclosure reasonably well, but consolidated onto
  one canonical policy shared with iOS, so the two can't drift apart.
  Update this field in Play Console to match.)
- **Category**: Communication (or Lifestyle, either fits)
- **Contact email**: dhanageetha2000@gmail.com

## Content rating questionnaire

Straightforward — no violence, no user-generated public content, no
gambling, no ads. Answer "No" to everything except the data-collection
questions, which the Data Safety form below covers in detail.

## Target audience

Not designed for or targeted at children. Set target age group to 18+
adults (the actual users are parents/grandparents, not the "child" whose
voice may be cloned).

## Data Safety form

This is the one that takes real care — Google cross-checks it against your
actual permissions and can reject/suspend for mismatches. Answers based on
what the app actually does:

| Data type | Collected? | Shared? | Purpose |
|---|---|---|---|
| Voice/audio recordings | Yes | Yes (ElevenLabs — transcription, cloning, TTS) | App functionality |
| Names (parent/child) | Yes | No | App functionality |
| Contact names (not numbers) | Yes | Yes (Anthropic — reply generation) | App functionality |
| Phone numbers | **No** | — | Resolved entirely on-device via Contacts, never transmitted |
| App activity (conversation transcripts) | Yes | Yes (Anthropic) | App functionality |
| Precise/approximate location | No | — | Not collected |

- **Is data encrypted in transit?** Yes (HTTPS to Railway backend)
- **Can users request data deletion?** Yes — via the email in the privacy policy
- **Is data collection required or optional?** Voice cloning is optional/opt-in with explicit in-app consent; everything else is required for core app function

## Restricted permissions justification

Play Console will ask you to justify each of these — copy/adapt as
needed. This is a first submission for Android (unlike iOS, which has
been through several review rounds already), so nothing here has been
tested against a real reviewer yet — worth double-checking Play
Console's own wording hasn't changed by the time you fill this in.

**READ_CONTACTS**: "The app lets a user ask a voice assistant to call or
message a specific person by name (e.g. 'call my son'). The app looks up
that person's phone number in the device's own Contacts to open a
WhatsApp chat/call with them — phone numbers are never transmitted off
the device."

(`CALL_PHONE` was removed — calling now opens the contact's WhatsApp
chat directly rather than dialing, since WhatsApp calls are free
internationally and Android's WhatsApp has no call-initiation intent to
trigger automatically.)

**SYSTEM_ALERT_WINDOW ("Display over other apps")** — a Google Play
*Restricted Permission* requiring its own declaration form, separate
from the manifest permissions list, and sometimes a short screen
recording demonstrating the feature. Amma uses this for the "return to
Amma" floating bubble shown after the app hands off to WhatsApp/Phone
for a call — the iOS equivalent is a Live Activity in the Dynamic
Island. Suggested justification: "After Amma opens WhatsApp or the
Phone app to place a call the user asked for by voice, this permission
shows a small floating bubble so the user can easily return to Amma
once the call ends — it falls back to a plain notification if this
permission isn't granted." (`OverlayHelper.kt`/`OverlayService.kt`.)

**CAMERA**: used only for the optional "take a profile photo" button in
Profile setup (parent's and child's photo) — the photo is stored
locally on-device (`childPhotoPath`/equivalent in AmmaPreferences) and
is never uploaded to the backend or any third party.

## Things only you can do

- Create the Google Play Developer account ($25 one-time, ID verification)
- Fill in and submit the actual Play Console forms above
- Upload the AAB and screenshots
- Submit for review
