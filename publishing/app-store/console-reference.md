# App Store Connect submission reference

Everything below is for filling in App Store Connect yourself — I can't
submit these on your behalf. The app record already exists (created
earlier for the Cast Console iTunes ID work), Apple ID `6795766128`,
bundle ID `com.dhana.amma`.

## Assets

- **Screenshots**: `screenshot-1-welcome.png`, `screenshot-2-talk.png`
  (both captured from iPhone 17 Pro Max simulator at native resolution,
  should satisfy the required 6.9"/6.7" size class — App Store Connect
  will tell you immediately on upload if a different size is needed)
- **App icon**: already set in the app itself (`AppIcon.appiconset`),
  no separate marketing icon upload needed for iOS (unlike Play Store)
- **Listing copy**: see `listing.txt` for subtitle, promotional text,
  description, keywords, category, age rating

## App Privacy ("nutrition label")

App Store Connect → your app → App Privacy. Answer based on what the
app actually does:

| Data type | Collected? | Linked to user? | Used for tracking? | Purpose |
|---|---|---|---|---|
| Audio Data (voice recordings) | Yes | Yes | No | App Functionality |
| Contact Info (parent/child names) | Yes | Yes | No | App Functionality |
| Other User Content (conversation transcripts, contact names mentioned in speech) | Yes | Yes | No | App Functionality |
| User ID (the app-generated family identifier) | Yes | Yes | No | App Functionality |
| Health and Fitness (heart rate, from a paired Apple Watch) | **Yes** | Yes | No | App Functionality — sent with each Talk interaction so Amma can gently mention it if elevated/low; optional, only if the parent connects an Apple Watch in Setup |
| Contacts (actual phone numbers) | **No** | — | — | Resolved entirely on-device via the Contacts framework, never transmitted. (v1.1 also added writing a new contact and picking one via Apple's native contact picker — still entirely on-device, nothing about a contact is ever sent to Amma's backend) |
| Precise/Coarse Location | No | — | — | Not collected |
| Financial Info, Browsing History | No | — | — | Not collected |

**Note on Health**: this is a real "Yes" answer, not a formality — `heart_rate` is included in the `/v1/interactions` request body whenever a paired Apple Watch is connected (`backend/app.py`'s `system_prompt()` uses it to let Claude mention it only if notably high/low). Answering "No" here would misrepresent the app to Apple's reviewers and to users reading the nutrition label — don't skip this one even though it's easy to miss since HealthKit was added in a later session than the rest of this doc.

Answer "No" to the tracking questions (this app doesn't track users
across other companies' apps/websites for advertising).

## App Review notes (paste into the "Notes" field for reviewers)

Reviewers may not have a "family" set up and won't understand the voice
cloning flow without context. Suggested note:

> Amma is a voice assistant a parent uses to "talk" to their child and
> get a spoken reply, optionally in the child's own cloned voice. To
> test: complete onboarding with any names, go to the Talk tab, tap the
> mic, and speak — Amma transcribes it, generates a reply via Claude,
> and speaks it back. The Voice tab lets you optionally record/upload a
> voice sample to clone (requires explicit in-app consent, can be
> skipped). The Setup tab supports casting to a Chromecast if one is on
> the network, connecting an Apple Watch for heart-rate context
> (optional), choosing a preferred calling app (WhatsApp or Phone), and
> managing on-device Contacts (view, add via the native contact picker,
> or create a new one) for the "call/message by name" voice command.
> Saying something like "call [a name in your Contacts]" triggers a
> handoff to WhatsApp or the Phone app; a Live Activity (Dynamic Island
> / Lock Screen) or, if Live Activities are unavailable, a local
> notification appears as a way back to Amma — this only fires on a
> real device with a real contact to call, so it may not trigger in the
> Simulator. No test account is needed — the app generates a local
> identifier on first launch.

## Restricted capabilities Apple may ask about

Same substance as the Play Store's restricted-permissions question,
phrased for Apple's review context if asked:

- **Microphone**: used only when the user taps to talk; recording stops
  when they tap again.
- **Contacts**: used to resolve a spoken name to a phone number
  on-device (to place a call or open a WhatsApp chat), to let the parent
  browse/add contacts in Setup, and to create a new contact if they
  choose to — numbers are never transmitted off the device.
- **Camera**: only to take a profile photo (parent, child, or a Home
  screen picture) — never used for anything else.
- **HealthKit (read-only)**: only reads heart rate from a paired Apple
  Watch, and only if the parent explicitly connects it in Setup; never
  writes to Health. Used to let Amma gently check in if it seems
  notably elevated or low — see the Health nutrition-label note above,
  since this value is sent to the backend.
- **Notifications**: requested best-effort at launch, used only for a
  "tap to return to Amma" reminder after handing off to WhatsApp/Phone
  — falls back to this only when Live Activities aren't available.
- **Local Network**: used only to discover a Chromecast/Google TV on
  the same WiFi network for the optional casting feature.

## Things only you can do

- Fill in and submit the App Store Connect listing form above
- Archive and upload a build via Xcode (Product → Archive → Distribute
  App → App Store Connect) — this needs to happen interactively since
  no "Apple Distribution" signing certificate exists yet; Xcode will
  create one automatically the first time you archive, but needs you
  signed into your Apple ID inside Xcode's own UI
  - **New since this doc was first written**: the project now has a
    second target, `AmmaWidget` (renders the Live Activity), embedded
    in the main app. It needs its own distribution provisioning too —
    expect Xcode to prompt about it (likely a "Fix Issue" style nudge,
    same pattern as the earlier HealthKit device-signing hiccup) the
    first time you archive. Let Xcode's automatic signing handle it;
    don't need to register anything by hand in the Developer portal
    unless it specifically asks.
- Consider refreshing `screenshot-1-welcome.png`/`screenshot-2-talk.png`
  — both predate several redesigns since (chat bubbles, avatar picker,
  new welcome screen). Not required for approval, but they no longer
  show the current UI.
- Submit for review
