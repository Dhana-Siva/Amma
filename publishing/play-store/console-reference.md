# Play Console submission reference

Everything below is for filling in the Play Console forms yourself — I can't
submit these on your behalf, but this should make it fast.

## App bundle to upload

`android/app/build/outputs/bundle/release/app-release.aab`
(rebuild first with `./gradlew bundleRelease` if you've made any code changes
since this was generated)

## Store listing

- **App name**: Amma Appa Arugil - AAA
- **Short description**: see `listing.txt`
- **Full description**: see `listing.txt`
- **App icon**: `icon-512x512.png`
- **Feature graphic**: `feature-graphic-1024x500.png`
- **Screenshots**: `screenshot-1-talk.png`, `screenshot-2-voice.png`, `screenshot-3-devices.png`
- **Privacy policy URL**: https://dhana-siva.github.io/amma-cast-receiver/privacy.html
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

Play Console will ask you to justify these two — copy/adapt as needed:

**READ_CONTACTS**: "The app lets a user ask a voice assistant to call or
message a specific person by name (e.g. 'call my son'). The app looks up
that person's phone number in the device's own Contacts to place the
call/message — phone numbers are never transmitted off the device."

**CALL_PHONE**: "When the user asks the voice assistant to call a
specific contact, the app places the call directly rather than just
opening the dialer, since the target users are elderly/low
phone-literacy and an extra manual step to confirm the call is a real
usability barrier for them."

## Things only you can do

- Create the Google Play Developer account ($25 one-time, ID verification)
- Fill in and submit the actual Play Console forms above
- Upload the AAB and screenshots
- Submit for review
