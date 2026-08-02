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
| Contacts (actual phone numbers) | **No** | — | — | Resolved entirely on-device via the Contacts framework, never transmitted |
| Precise/Coarse Location | No | — | — | Not collected |
| Financial Info, Health, Browsing History | No | — | — | Not collected |

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
> skipped). The Devices tab supports casting to a Chromecast if one is
> on the network, and shows on-device Contacts for the "call/message by
> name" voice command. No test account is needed — the app generates a
> local identifier on first launch.

## Restricted capabilities Apple may ask about

Same substance as the Play Store's restricted-permissions question,
phrased for Apple's review context if asked:

- **Microphone**: used only when the user taps to talk; recording stops
  when they tap again.
- **Contacts**: used only to resolve a spoken name to a phone number
  on-device, to place a call or open a WhatsApp chat — numbers are never
  transmitted off the device.

## Things only you can do

- Fill in and submit the App Store Connect listing form above
- Archive and upload a build via Xcode (Product → Archive → Distribute
  App → App Store Connect) — this needs to happen interactively since
  no "Apple Distribution" signing certificate exists yet; Xcode will
  create one automatically the first time you archive, but needs you
  signed into your Apple ID inside Xcode's own UI
- Submit for review
