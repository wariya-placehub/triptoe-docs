# Permissions

Audience: Architect, Developer

Covers how runtime permissions are requested, denied, and recovered across all native features, for both guide and guest roles, on both Android and iOS.

## Design Principles

- **Ask only when needed.** Never prompt for a permission at app launch. Prompt at the moment the user takes an action that requires it (e.g. tapping "Start Sharing Location," opening the QR scanner, tapping "Camera" in the image picker).
- **Explain before asking.** When the OS requires a two-step permission flow (e.g. iOS foreground-then-background location), show an in-app explanation between the two system prompts so the user understands why they're being asked again.
- **Always offer recovery.** Every permission-denied alert includes an "Open Settings" button (`Linking.openSettings()`) that takes the user directly to TripToe's settings page, where all permissions are listed. The user never has to hunt through system settings.
- **Guide vs guest tone.** Guides must grant location — it's core to the product. Guests can opt out — location sharing is optional for them.

## Permissions by Feature

### Location (Foreground + Background)

**Used by:** Guide location tracking, guest location sharing

**When prompted:**
- **Guide**: automatically on first visit to an active tour session (`tour-session-details.tsx`)
- **Guest**: when they tap "Start Sharing Location" on the tour booking details screen

**Platform behavior:**

| Step | Android | iOS |
|---|---|---|
| Foreground | Single system prompt: "Allow while using the app" | Single system prompt: "Allow While Using App" |
| Background | On Android 10: included in foreground prompt. On Android 11+: separate system prompt or Settings redirect for "Allow all the time" | Always a separate system prompt for "Always." iOS forces a two-step flow — there is no way to ask for "Always" in one step. |

**The two-prompt problem (iOS and Android 11+):**

Users see two system dialogs about "location" back to back. Without context, this feels broken — they already said yes, why are they being asked again? To solve this, the app shows an in-app explanation alert between the two system prompts:

```
[System prompt 1: "Allow While Using App" — user taps Allow]
         ↓
[App alert: "One More Step — to share your location when your phone is locked,
 select 'Always' on the next screen." — user taps Continue]
         ↓
[System prompt 2: "Always" — user taps Allow]
```

If background permission is already granted (e.g. returning user), the explanation is skipped entirely.

**Guide vs guest behavior:**

| Scenario | Guide | Guest |
|---|---|---|
| Foreground denied | Alert with "Open Settings" only (no cancel) | Alert with "Open Settings" + "Cancel" |
| Explanation before background prompt | "Your guests need to see your location even when your phone is locked." Only "Continue" button (no opt-out) | "To share your location when your phone is locked..." Has "Continue" and "Not Now" |
| Background denied | Alert: "Location sharing is required for your guests to see you on the map." Only "Open Settings" (no dismiss) | Alert: "To keep sharing your location when your phone is locked..." Has "Open Settings" and "Not Now" |

The guide flow has no "Cancel," "Not Now," or dismiss options at any step. Location is required — without it, guests can't see the guide on the map, which defeats the purpose of using the app.

The guest flow always offers an opt-out. Location sharing is optional. The app still works for receiving messages, viewing tour details, checking in, and rating.

**Recovery (both roles):**

If the user previously denied the permission, the OS will not show the system prompt again. In this case, `requestForegroundPermissionsAsync()` returns `denied` immediately without showing a dialog. The app detects this and shows the "Open Settings" alert, which opens TripToe's settings page where the user can toggle Location back on.

**Implementation:** `src/utils/permissions.ts` — `requestFullLocationPermission(role)`

### Camera

**Used by:** QR code scanner (guest), image picker for cover photos / meeting place photos / profile photos (both roles)

**When prompted:**
- **QR scanner**: when the guest taps "Scan QR Code" on the Join Tour screen
- **Image picker**: when the user selects "Camera" from the image source picker

**Platform behavior:**

| | Android | iOS |
|---|---|---|
| Permission | `CAMERA` in AndroidManifest | `NSCameraUsageDescription` in Info.plist |
| Prompt | Single system prompt | Single system prompt |
| After denial | OS won't re-prompt; app shows "Open Settings" alert | OS won't re-prompt; app shows "Open Settings" alert |

Camera permission is the same for guides and guests — there's no role-specific behavior.

**Recovery:**

The denied alert says: "To take a photo, enable Camera for TripToe in Settings." with an "Open Settings" button.

**Implementation:**
- Image picker camera: `src/utils/imagePicker.ts` — `pickImageFromCamera()`
- QR scanner camera: `app/(guest)/(tabs)/book-tour-session.tsx` — `handleOpenScanner()`

### Photo Library

**Used by:** Image picker for cover photos / meeting place photos / profile photos (both roles)

**Platform behavior:**

| | Android | iOS |
|---|---|---|
| Permission | Not required (Android uses system file picker) | `NSPhotoLibraryUsageDescription` in Info.plist. On iOS 14+, user can grant "Selected Photos" or "All Photos" |
| Prompt | None needed | System prompt on first access |

Expo's `launchImageLibraryAsync` handles photo library permission internally. No custom permission handling needed.

### Push Notifications

**Used by:** Tour messages, booking confirmations, post-tour nudges (both roles)

**When prompted:** Automatically after sign-in (both guide and guest), triggered by `registerForPushNotifications()` in the root layout.

**Platform behavior:**

| | Android | iOS |
|---|---|---|
| Permission | Android 13+: requires `POST_NOTIFICATIONS` runtime permission. Android 12 and below: granted automatically | Always requires user permission |
| Prompt | System prompt (Android 13+) | System prompt |
| Default if not granted | Notifications silently not delivered | Notifications silently not delivered |

Push notification permission is not re-prompted if denied. The app does not currently show an "Open Settings" recovery alert for notifications — if the user denies, they simply won't receive push notifications. This is acceptable because notifications are not critical to core functionality (location sharing and messaging still work without push).

**Implementation:** `src/utils/permissions.ts` — `requestNotificationPermission()`, called by `src/services/notifications.ts` — `registerForPushNotifications()`

## app.json Permission Configuration

### iOS (`infoPlist`)

| Key | Value |
|---|---|
| `NSLocationWhenInUseUsageDescription` | "TripToe shares your live location with your tour guide and group during active tours so everyone can find each other." |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | "TripToe keeps your location updating in the background during a tour so your guide can see where you are if you fall behind the group. Tracking stops automatically when the tour ends." |
| `NSCameraUsageDescription` | "TripToe uses your camera to take cover photos for your tours and meeting places, and to scan QR codes to join tours." |
| `NSPhotoLibraryUsageDescription` | "TripToe uses your photo library to upload tour cover images, meeting place photos, and your profile photo." |
| `UIBackgroundModes` | `["location", "fetch", "remote-notification"]` |

Apple rejects apps with vague permission strings. Every string must explain the user-facing benefit.

### iOS (expo-location plugin)

```json
["expo-location", {
  "locationAlwaysAndWhenInUsePermission": "...",
  "isIosBackgroundLocationEnabled": true,
  "isAndroidBackgroundLocationEnabled": true,
  "isAndroidForegroundServiceEnabled": true
}]
```

`isIosBackgroundLocationEnabled` must be `true` or iOS background location permission will always return denied even if the user granted "Always."

### Android (`permissions`)

```
ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, ACCESS_BACKGROUND_LOCATION,
FOREGROUND_SERVICE, FOREGROUND_SERVICE_LOCATION,
POST_NOTIFICATIONS, CAMERA
```

`FOREGROUND_SERVICE_LOCATION` is required on Android 14+ for the persistent location tracking notification.

## Common User Issues

| Issue | Cause | What the app does |
|---|---|---|
| "I already said yes, why are you asking again?" | iOS/Android 11+ two-step location flow | Shows "One More Step" explanation between the two system prompts |
| "I clicked the wrong thing and now X doesn't work" | User denied a permission and OS won't re-prompt | Shows alert with "Open Settings" button linking directly to TripToe's settings page |
| "Location stopped when I locked my phone" | Background location not granted ("While Using App" only) | Shows nudge to set Location to "Always" in Settings |
| Permission prompts don't appear at all | User previously denied; OS remembers and won't re-ask | App detects this and shows "Open Settings" alert instead |

## Files

| File | Role |
|---|---|
| `src/utils/permissions.ts` | `requestFullLocationPermission(role)`, `requestForegroundLocation()`, `requestBackgroundLocation()`, `requestNotificationPermission()` |
| `src/utils/imagePicker.ts` | Camera permission handling in `pickImageFromCamera()` |
| `app/(guest)/(tabs)/book-tour-session.tsx` | QR scanner camera permission in `handleOpenScanner()` |
| `app/(guide)/tour-session-details.tsx` | Guide location permission prompt on active session visit |
| `app/(guest)/tour-booking-details.tsx` | Guest location permission prompt on "Start Sharing Location" tap |
| `app/_layout.tsx` | Push notification registration after sign-in |
