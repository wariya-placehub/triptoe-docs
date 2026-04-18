# iOS Support

## Status: Not started
## Priority: High (next major milestone after Android Play Store release)
## Affects: triptoe-mobile, triptoe-backend, infrastructure

## Goal

Ship TripToe to the Apple App Store so guides and guests with iPhones can use the same platform Android users already use today. The Android version is the reference; iOS must reach feature parity before launch.

## Constraints

- Development happens on Windows. iOS apps can only be built and submitted from macOS.
- The chosen path is **EAS Build** (Expo's hosted Mac infrastructure). This avoids buying/renting a Mac for the build pipeline. A Production tier subscription with Expo is required (or free tier with longer queue times).
- A real iPhone is still required for testing — the iOS Simulator cannot test push notifications, background location, real camera, or real GPS.

## Prerequisites

| Item | Cost | Lead time | Notes |
|---|---|---|---|
| Apple Developer Program | $99/year | 24–48h approval | Sign up at developer.apple.com/programs under legal name or business name (visible on App Store listing) |
| EAS Build subscription | ~$29/month (or free tier) | Immediate | Already using Expo, just need to enable EAS |
| Physical iPhone for testing | Variable | — | Used iPhone SE works fine; needed for QA before submission |
| App Store Connect listing | Free | — | Created after Apple Developer approval |

## iOS readiness from recent refactors

The mobile app was refactored to a **Stack-over-Tabs** navigation architecture. Auth screens (guide `signin`, guest `signin`) and detail screens are now real Stack children, not hidden tab entries. This means iOS swipe-back gestures work natively on all screens — no custom `BackHandler` overrides or `useHeaderBackButton` hooks are needed.

Guest authentication was also unified into a single `signin` flow — email + verification code creates the account on first sign-in and signs in returning guests on subsequent ones. Guest auth is *not* third-party social login, so Apple's Sign in with Apple requirement does **not** apply to the guest flow.

## Current state (baseline before iOS work begins)

- `app.json` already has a partial `ios` section: `bundleIdentifier: "com.triptoe.mobile"` plus three usage strings (`NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, `NSCameraUsageDescription`). The location strings are generic ("share it with your tour guide") and should be rewritten to emphasize the user-facing benefit before submission.
- ~~Still missing from `app.json`: `NSPhotoLibraryUsageDescription`, `UIBackgroundModes`, `buildNumber`, and the Apple sign-in entitlement.~~ **Done** — `NSPhotoLibraryUsageDescription`, `UIBackgroundModes`, `buildNumber`, and the Apple sign-in entitlement have all been added to `app.json`.
- In-app account deletion already exists in both `app/(guide)/(tabs)/account.tsx` and `app/(guest)/(tabs)/account.tsx` (required by Google Play; reusable for iOS).
- Bundle identifier is **`com.triptoe.mobile`** (matches Android `package`). This is the ID to register in the Apple Developer portal. Do not change it — it must match what Android uses for brand consistency and cannot be changed after first App Store submission.

## Architecture changes

### Authentication: add Sign in with Apple

Apple's App Store Review Guideline 4.8 requires that **any app offering third-party social login (including Google OAuth) must also offer Sign in with Apple as an equivalent option**. TripToe currently uses Google OAuth for guides, so this is mandatory — the app will be rejected without it.

**Backend changes:**
- New column on `guide` table: `apple_user_id VARCHAR UNIQUE NULL`
- New endpoint: `POST /auth/guide/signin/apple`
  - Accepts an Apple identity token from the mobile app
  - Verifies the token against Apple's public keys (`https://appleid.apple.com/auth/keys`)
  - Extracts `sub` (stable Apple user ID), email, and name (only present on first signin — must be captured then; Apple does not resend)
  - Lookup order: by `apple_user_id` first, then by `email_address` as fallback (to link Apple ID to an existing Google-authenticated guide)
  - On match: link the Apple ID to the existing Guide record, do not create a duplicate
  - On no match: create a new Guide record with Apple ID as the auth anchor
  - Returns the same JWT response shape as `/auth/guide/signin` so the mobile flow stays identical

**Mobile changes:**
- Install `expo-apple-authentication`
- Add a "Sign in with Apple" button to `app/(guide)/signin.tsx`, rendered conditionally with `Platform.OS === 'ios'`
- Call `AppleAuthentication.signInAsync()` and POST the resulting identity token to the new backend endpoint
- Store the JWT identically to Google signin

**Edge case: hidden email relay.** Apple lets users hide their real email when signing in. In that case, Apple returns a relay address like `xyz123@privaterelay.appleid.com` that forwards to the user's real inbox. This means a guide who already has a Google-authenticated TripToe account using `kit@gmail.com` and then signs in with Apple while hiding their email will end up with a second, separate Guide record. There is no way to detect that they are the same human. Best mitigation: copy explaining "Sharing your email lets you use the same account across devices" near the Apple signin button.

### Push notifications: add APNs (no code changes)

The app uses **Expo Push Service** as a middleware between the backend and the device. Expo handles delivery to FCM (Android) and APNs (iOS) transparently. The Expo push token format (`ExponentPushToken[xxxxx]`) is platform-agnostic.

**No backend code changes.** No mobile code changes. Only credential setup:

- In Apple Developer portal, create an **APNs Auth Key** (`.p8` file)
- Upload it to Expo: `eas credentials → iOS → Push Notifications → upload .p8`
- Expo automatically uses APNs to deliver pushes to iOS device tokens going forward

**Firebase stays Android-only.** Do not add an iOS app to the Firebase project. Do not add `GoogleService-Info.plist`. iOS uses APNs natively through Expo.

### `app.json` iOS configuration

Target config to merge into the existing `ios` section of `app.json`:

```json
"ios": {
  "bundleIdentifier": "com.triptoe.mobile",
  "buildNumber": "1",
  "supportsTablet": false,
  "infoPlist": {
    "NSLocationWhenInUseUsageDescription": "TripToe uses your location to share with your tour guide and group during active tours.",
    "NSLocationAlwaysAndWhenInUseUsageDescription": "TripToe uses your location in the background to keep your tour group updated during a session.",
    "NSCameraUsageDescription": "TripToe uses your camera to take cover photos for your tours and meeting places, and to scan QR codes to join tours.",
    "NSPhotoLibraryUsageDescription": "TripToe uses your photo library to upload tour cover images and meeting place photos.",
    "UIBackgroundModes": ["location", "fetch", "remote-notification"]
  },
  "entitlements": {
    "com.apple.developer.applesignin": ["Default"]
  }
}
```

Apple **rejects** apps without explicit, descriptive usage strings for every permission. Generic phrasing like "we use your location" is grounds for rejection — every string must explain the *user-facing benefit*.

### Background location justification

TripToe uses background location during active tours, which is one of Apple's most-scrutinized capabilities. Review notes must explain:

> During an active tour session, the guide's location is shared every 30 seconds with checked-in guests so the group can find each other. Location tracking starts only after the tour begins and stops automatically when the tour ends or when the user manually disables sharing. Location data is never collected outside of an active tour session.

A demonstration video of the feature in action will likely be requested. Have one ready before submission.

### In-app account deletion

Apple requires **in-app account deletion** for any app that supports account creation (App Store Review Guideline 5.1.1(v)). The triptoe.app web page is not sufficient — there must be a delete button reachable from inside the app.

This is already required by Google Play and should already exist in `app/(guide)/(tabs)/account.tsx` and `app/(guest)/(tabs)/account.tsx`. Verify before submission.

## Build and submission pipeline

### EAS Build setup

```powershell
npm install -g eas-cli
eas login
eas build:configure
```

This creates or updates `eas.json` with iOS build profiles. Let EAS manage credentials automatically — it generates and uploads signing certificates and provisioning profiles to Apple on your behalf, which is far easier than doing it manually.

### Build command

```powershell
eas build --platform ios --profile production
```

Runs on Expo's macOS infrastructure. Takes 15–30 minutes. Produces an `.ipa` file with an option to auto-submit to App Store Connect.

### Submission command

```powershell
eas submit --platform ios --latest
```

Uploads the latest build to App Store Connect, where it goes through 10–30 minutes of automated processing before appearing in TestFlight under "Internal Testing".

### TestFlight workflow

- Add yourself (and any other testers) as internal testers via Apple ID email
- Install the **TestFlight** app on the iPhone
- Install TripToe from TestFlight, test full flows end-to-end
- Iterate on builds until ready for review

## App Store Connect listing requirements

| Field | Notes |
|---|---|
| App name | "TripToe" (must match brand) |
| Subtitle | Short tagline, ≤30 chars |
| Description | Long-form, focus on guide and guest benefits |
| Keywords | Comma-separated, ≤100 chars total — research what guides search for |
| Support URL | `https://triptoe.app/support` (create this page if missing) |
| Marketing URL | `https://triptoe.app` |
| Privacy policy URL | `https://triptoe.app/privacy` (already exists) |
| App icon | 1024×1024 PNG, no transparency, no rounded corners |
| Screenshots | iPhone 6.7" (required), 6.5" (required), 5.5" (optional) — multiple per size |
| Category | Travel (primary) — consider Lifestyle as secondary |
| Age rating | Will be set via Apple's questionnaire |
| Demo account | Provide a guide login + a guest login that the reviewer can use |

## Common rejection reasons to pre-empt

1. **Missing Sign in with Apple** when offering Google OAuth — addressed by the auth changes above
2. **Vague permission strings** — each `NS*UsageDescription` must explain the user-facing benefit
3. **In-app account deletion missing** — verify before submission
4. **Background location not justified** — provide clear review notes and a demo video
5. **Demo credentials missing** — include in review notes
6. **Crash on first launch** — test on a real iPhone before submission, not just the simulator
7. **Broken links** — every URL in the listing must resolve

## Order of work

1. ~~**Apple Developer signup** ($99) — start the 24–48h approval clock~~ **Done**
2. ~~**Build Sign in with Apple** in parallel while waiting for Apple approval (backend + mobile + DB migration)~~ **Done**
3. ~~**Verify in-app account deletion** exists for guides and guests~~ **Done**
4. ~~**Configure iOS section in `app.json`** with all required permission strings and entitlements~~ **Done**
5. ~~**Set up EAS Build** and configure iOS credentials~~ **Done**
6. ~~**Generate APNs Auth Key** and upload to EAS~~ **Done** (Key ID: PY7VLSBLX5)
7. ~~**AASA file hosted** at `triptoe.app/.well-known/apple-app-site-association`~~ **Done**
8. ~~**Associated domains** added to `app.json`~~ **Done**
9. **Create App Store Connect listing** with all metadata, screenshots, and copy
10. **First EAS build → TestFlight → install on real iPhone**
11. **Test all flows end-to-end** on a physical device:
    - Universal Links (`triptoe.app/s/*` and `/t/*` open the app)
    - Push notifications (guide messages arrive on guest device)
    - Background location (sharing continues when app is backgrounded)
    - Camera (QR scan, photo uploads)
    - Apple Sign-In (guide auth)
12. **Submit for App Store review** with thorough review notes
13. **Iterate on rejections** — expect at least one rejection on the first submission

## Open questions

- Will the operator/business name on the App Store listing be a personal name or a registered business entity? Affects how the developer account is set up.
- Sign in with Apple email-relay handling: should the UI proactively warn guides that hiding their email may create a duplicate account if they later switch devices?
- Is the support URL `triptoe.app/support` going to exist before submission, or do we need a placeholder?

## Related

- [reference_infrastructure.md](../../memory/reference_infrastructure.md) — Domain, Cloudflare, Firebase, Google Play setup
- triptoe-mobile/CLAUDE.md — Mobile app architecture and conventions
- triptoe-backend/CLAUDE.md — Backend architecture and conventions
