# Location Tracking

Audience: Architect, Developer

Companion to [2_architecture.md](2_architecture.md). Covers how guide and guest location sharing works end-to-end, including the two-mode tracking architecture, auto-start, boot resume, map display, and privacy.

## Overview

Guide and guest use different tracking modes based on their role and permission level:

- **Guide with "Always" permission:** Background location task via `startLocationUpdatesAsync`. Survives phone locking, app switching, phone calls.
- **Guide with "While Using" permission:** Foreground watcher via `watchPositionAsync`. Tracks while the app is open, pauses when backgrounded.
- **Guest:** Always uses the foreground watcher. No background permission required.

Both modes use a shared `forwardLocationUpdate()` helper for the actual API send, ensuring consistent retry logic, throttling, 410 handling, and heartbeat updates.

### Why two modes?

The original design had a single tracking path — background location task requiring "Always" permission. If the user only granted "While Using", the app got zero tracking, even while the user was actively looking at it. This matches how Uber handles driver tracking: background when "Always" is granted, foreground fallback when only "While Using" is available. Riders (guests in TripToe) only need foreground.

## How It Works

### Guest

1. Guest checks into a tour session (check-in does **not** auto-start location sharing)
2. Guest explicitly taps "Start Sharing Location" once to opt in — this sets `location_sharing_enabled=true` on their check-in record
3. App requests **foreground location permission only** — no "One More Step" background prompt
4. `startForegroundLocationUpdates(tourSessionId, 'guest')` begins sending to `POST /location/update` via `forwardLocationUpdate()`
5. The guest's layout-level sync (`syncGuestLocationTracking`) keeps tracking alive on every 60-second tick, on app foreground, and on layout mount — independent of which screen the guest is on
6. Guest taps "Stop Sharing" or the tour ends → tracking stops
7. Sharing preference is **sticky**: `location_sharing_enabled` on the booking's check-in survives across app restarts. On the next app launch, the layout-level sync reads it from `/guests/my-bookings` and auto-starts tracking without the guest having to tap anything.

**Guest tracking pauses when the app is backgrounded** (phone locked, app switched). This is acceptable — guests are tourists with the app open. Updates resume when the guest returns to the app.

### Guide

1. Root layout (`_layout.tsx`) calls `syncGuideLocationTracking()` from `guideLocationSync.ts` on mount, every 60 seconds, and on app foreground via `AppState`
2. The sync helper reads active sessions from `useActiveTourStore`, checks permission silently (no prompt), and calls `ensureTrackingActive()`
3. `ensureTrackingActive()` selects the tracking mode:
   - Background permission granted → `startBackgroundLocationUpdates()` (background task with foreground service)
   - Only foreground permission → `startForegroundLocationUpdates()` (foreground watcher)
4. Permission prompt is triggered from `tour-session-details.tsx` on first visit to an active session
5. Tracking stops when no active sessions remain or on logout

### Mode Selection and Transitions

`ensureTrackingActive()` in `locationSync.ts` handles mode selection, upgrade, and downgrade:

```
Guide opens active session
  → Check permissions
  → Background granted?
      YES → Start background task
      NO  → Foreground granted?
            YES → Start foreground watcher
            NO  → No tracking (banner shows)
```

**Upgrade:** If a guide grants "Always" in Settings while the foreground watcher is running, the next sync cycle detects `isForegroundOnlyTracking() === true` and `bg === 'granted'`, tears down the foreground watcher, and starts the background task.

**Downgrade:** If a guide revokes "Always" to "While Using" in Settings, the next sync cycle detects `!isForegroundOnlyTracking()` and `bg !== 'granted'`, stops the background task, and starts the foreground watcher. Note: Android does not immediately kill a running foreground service when permission is downgraded — the sync must explicitly stop it.

**Zombie cleanup:** If a background task is registered but `isLocationSharingActive()` returns false (stale heartbeat) and background permission is not granted, the sync kills the zombie and starts the foreground watcher.

### Why Guide Tracking Is Screen-Independent

Guide location tracking is driven by `useActiveTourStore` at the root layout level, not by any individual screen. The store is a Zustand store that:

- Fetches the guide's upcoming sessions via `getGuideUpcomingTourSessions(false)`
- Filters to sessions where status is `check_in_open` or `in_progress`
- Exposes `activeSessions` to the layout's auto-start effect and to dashboard/schedule for the `ActiveTourBanner`

This means the guide's location is tracked as long as the app is open (any screen) and a session is active.

### Why Guest Tracking Is Also Screen-Independent

Guest tracking used to be coupled to the booking details screen. The guest now has its own layout-level sync (`guestLocationSync.ts`), mirroring the guide architecture. On every 60-second tick, on AppState 'active', and on layout mount, `syncGuestLocationTracking()`:

1. Calls `GET /guests/my-bookings` — the backend returns `location_sharing_enabled` per booking
2. Filters for the first active booking where `checked_in` and `location_sharing_enabled` are both true
3. Calls `isLocationSharingActive(sessionId)` — if true, skips the restart
4. Otherwise calls `startForegroundLocationUpdates(sessionId, 'guest')` to start tracking
5. If no qualifying booking exists, stops tracking

### Guide Permission Banner

The guide's Session Details screen checks permission every 10 seconds and shows a banner based on the state:

| State | Banner | Color | Taps to |
|---|---|---|---|
| No foreground permission | "Location is off. Guests cannot see you on the map." | Orange (alert) | Settings |
| Foreground only, no background | "Guests cannot see you on the map when the app is in the background or the phone is locked." | Blue (info) | Settings |
| Full (background granted) | No banner | — | — |

The banner checks permission status directly — not the tracking heartbeat. This eliminates the false-positive flashing that occurred with the old heartbeat-based check (in-process state resets to zero on every process restart).

## Background Location Service (`backgroundLocation.ts`)

### Shared Location Forwarding

Both the background task and the foreground watcher call `forwardLocationUpdate()` for the actual API send. This function handles:

- **Send throttling:** Maintains the configured 30-second cadence (`SEND_THROTTLE_MS`) regardless of how fast the OS delivers location callbacks
- **Network retry:** One immediate retry on client-side network failure (TypeError "Network request failed")
- **410 handling:** Detects "tour ended" responses and triggers cleanup
- **Heartbeat updates:** Sets `lastSuccessfulSendAt` on success for the liveness check
- **Token reading:** Reads the access token from SecureStore (works in both background task and foreground watcher contexts)
- **Tracking mode tagging:** Sends `tracking_mode: 'background' | 'foreground'` in the request body for debugging

### Background Task

- Single `TaskManager` background task for guides with "Always" permission
- Uses raw `fetch()` (not Axios) because the background task runs outside React's component tree
- Shows a persistent foreground service notification (required for Android 14+)
- Updates every `LOCATION_UPDATE_INTERVAL_SECONDS` (default: 30 seconds)

### Foreground Watcher

- Uses `Location.watchPositionAsync()` — no foreground service, no notification bar icon
- Pauses automatically when app is backgrounded (OS stops delivering updates)
- Resumes when app returns to foreground
- Used by all guests and by guides who only have "While Using" permission

### Stateless Task: Read SecureStore on Every Callback

The background task holds **no module-level session or token state**. On every callback it reads the active session and the access token from `SecureStore`. This eliminates the class of bugs where cached tokens go stale after JWT refresh.

### Native Service Cleanup

On Android, `Location.stopLocationUpdatesAsync()` may not fully tear down the native `LocationTaskService` foreground service. Both `startForegroundLocationUpdates()` and `stopAllLocationUpdates()` use belt-and-suspenders cleanup:

1. Call `Location.stopLocationUpdatesAsync()`
2. Check `TaskManager.isTaskRegisteredAsync()` — if still registered, call `TaskManager.unregisterTaskAsync()`
3. Log the final registration state for debugging

### Burst Suppression

Google's Fused Location Provider dumps cached location fixes in rapid succession when a listener is first registered. The background task has a two-stage guard:

1. **Initial burst window** (`INITIAL_BURST_WINDOW_MS` = 3s): Ignores all callbacks in the first 3 seconds after task registration
2. **Send throttle** (`SEND_THROTTLE_MS` = 25s): Maintains configured cadence even if FLP delivers faster due to piggybacking on other apps

### Distance Filter Must Stay Zero

`distanceInterval` MUST be 0. Google FLP combines time and distance as AND — any non-zero value means stationary phones get zero callbacks.

### Heartbeat Liveness Check

`isLocationSharingActive()` cannot rely on `TaskManager.isTaskRegisteredAsync` alone — the registration can be a stale positive after force-close, reinstall, or OS-initiated restart. The check requires proof of liveness:

1. Task registered AND session matches AND
2. Either inside the startup grace window (60s) OR last successful send was within 60s

For the foreground watcher, `isLocationSharingActive()` returns true if the subscription exists and the session matches.

### Deferred 410 Stop

When the backend returns HTTP 410 (tour ended), calling `stopLocationUpdatesAsync` synchronously from within a task callback corrupts the JS-native task binding. The fix: clear the session from SecureStore immediately, then defer the native stop via `setTimeout(0)`.

## Scenario Matrix

| Scenario | Guide (Always) | Guide (While Using) | Guest |
|---|---|---|---|
| App in foreground | Tracking | Tracking | Tracking |
| App in background / phone locked | **Tracking** | **Pauses** | **Pauses** |
| Phone restarts during tour | Resumes via layout sync | Resumes via layout sync | Resumes via layout sync |
| App crash / OS kills app | Resumes on reopen | Resumes on reopen | Resumes on reopen |
| User on different screen | Continues | Continues | Continues |
| Phone call during tour | Continues | Pauses (resumes after) | Pauses (resumes after) |
| Tour ends while backgrounded | 410 → deferred stop | 410 → deferred stop | 410 → stop |
| Bad connection < 5 min | Still visible on map | Still visible on map | Still visible on map |
| Bad connection > 5 min | Disappears from map | Disappears from map | Disappears from map |
| Logout during active tour | Stops immediately | Stops immediately | Stops immediately |

## Backend Endpoints

### Location Updates

| Endpoint | Auth | Purpose |
|---|---|---|
| `POST /location/update` | Guest | Store guest location (lat, lng, accuracy, tracking_mode) |
| `POST /location/guide/update` | Guide | Store guide location (lat, lng, accuracy, tracking_mode) |
| `PUT /checkins/location-sharing` | Guest | Toggle `location_sharing_enabled` on the booking record |

Both update endpoints reject requests for ended sessions (HTTP 410 Gone). The `tracking_mode` field is logged server-side for debugging.

### Location Reads

| Endpoint | Auth | Purpose |
|---|---|---|
| `GET /tour-sessions/{id}/locations` | Guide | All guest locations + guide's own location + stats |
| `GET /location/guide/{id}` | Guest | Guide's location for a specific session |
| `GET /tour-sessions/{id}/sync` | Guest | Lightweight sync: guide location + guest's own location + unread count |

### Active Location Threshold

Locations are considered "active" if `recorded_at >= now - 5 minutes`. Older rows are excluded from all read endpoints.

## Map Display

Both guide and guest maps display positions by **polling the backend**:

- **Guide map** polls `GET /tour-sessions/{id}/locations` every 30 seconds while the session is active
- **Guest map** polls `GET /tour-sessions/{id}/sync` every 25 seconds while the session is active

### Guest Map

The guest's own location is shown via the native Google Maps blue dot (`showsUserLocation`) rather than a custom marker — real-time, no server round-trip needed. The guide appears as an avatar marker.

### Guide Map (Inline vs Fullscreen)

The inline map uses custom View markers with `tracksViewChanges` tuned for Android reliability:

- Guide marker: avatar image, `tracksViewChanges` based on `hasAvatar`
- Guest markers: colored dots, `tracksViewChanges={true}` (required for dynamically added markers to render on Android)
- Marker key includes `isSelected` state to force native remount on selection change
- Selected markers get higher `zIndex`

The fullscreen map uses the same markers with additional name labels and a Names toggle button.

**Tapping a guest card** on the guide's session details highlights the marker but does not pan/zoom the inline map (this caused other markers to temporarily disappear during animation).

### Per-Guest Tracking Status Signal

The guide's guest list shows a colored status signal per guest:

| Color | Meaning |
|---|---|
| Green | Fresh — location received within active threshold |
| Yellow | Stale — "Location not updating" |
| Red | Lost signal |
| Gray | Not sharing |

## Logout Cleanup

On real logout (user was set, then became null): calls `stopAllLocationUpdates()` which cleans up both the background task and the foreground watcher.

## Permission Flow

See [9e_feature_permissions.md](9e_feature_permissions.md) for full details. Summary:

- **Guide:** Prompted for foreground + background on first active session visit. If background is denied, tracking falls back to foreground mode with an informational banner.
- **Guest:** Prompted for foreground only on "Start Sharing Location" tap. No background prompt, no "One More Step" dialog.
- **Layout syncs** check permissions silently (no prompt). Explicit prompts happen only on the screens above.

## Privacy

- **Guest consent**: Location is only collected after the guest explicitly taps "Start Sharing Location"
- **Guide consent**: Requires location permission grant (prompted on first active session visit)
- **Android 14+**: Requires `FOREGROUND_SERVICE_LOCATION` permission and `foregroundServiceType="location"` in the Manifest
- **Foreground service notification**: Persistent notification shown while background tracking is active (not shown for foreground-only tracking)
- **No persistent storage**: Location data rows accumulate during a session but are only queried within the active threshold window

## Debugging

```powershell
# Watch React Native JS logs
adb logcat -s ReactNativeJS
```

Key log patterns:

- `[BG-LOC] Start called (reason=..., session=...)` — background task starting
- `[BG-LOC #N] Sent (guide session=...)` — background task sent location
- `[FG-LOC] Start called (reason=..., session=...)` — foreground watcher starting
- `[FG-LOC #N] Sent (guide session=...)` — foreground watcher sent location
- `[FG-LOC] KILLING background task before foreground start` — switching from background to foreground mode
- `[GUIDE-SYNC] === SYNC CHECK ===` — detailed sync state dump (permission, mode, registration)
- `[LOC] Stopping all (reason=...)` — all tracking stopped

To verify data reaches the backend:

```sql
SELECT recorded_at, latitude, longitude
FROM guide.guide_location
WHERE tour_session_id = <id>
ORDER BY recorded_at DESC
LIMIT 10;
```

To check if the native foreground service is still running:

```powershell
adb shell dumpsys activity services com.triptoe.mobile | findstr LocationTaskService
```

## Files

| File | Role |
|---|---|
| `src/services/backgroundLocation.ts` | Background task, foreground watcher, shared `forwardLocationUpdate()`, heartbeat, start/stop |
| `src/services/locationSync.ts` | Mode selection, upgrade/downgrade, zombie cleanup (`ensureTrackingActive`) |
| `src/services/guideLocationSync.ts` | Guide reconciliation — reads active sessions, delegates to `ensureTrackingActive` |
| `src/services/guestLocationSync.ts` | Guest reconciliation — reads bookings, foreground permission only |
| `src/stores/useActiveTourStore.ts` | Zustand store: active session detection for guides |
| `src/services/location.ts` | API calls for location read/write |
| `src/utils/permissions.ts` | `requestFullLocationPermission()` — guide gets foreground + background, guest gets foreground only |
| `app/_layout.tsx` | Guide + guest sync effects, logout cleanup |
| `app/(guide)/tour-session-details.tsx` | Permission prompt, permission-based banner, tracking status display |
| `app/(guest)/tour-booking-details.tsx` | "Start Sharing" button, uses centralized `startForegroundLocationUpdates` |
| `src/components/tour/TourMapView.tsx` | Map component — inline markers with Android-specific `tracksViewChanges` tuning |
| `src/components/guest/GuestLocationSection.tsx` | Guest map — native blue dot via `showsUserLocation` |
