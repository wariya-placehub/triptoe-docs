# Location Tracking Follow-ups

## Status: Open
## Priority: Mixed (see each item)
## Affects: Guide + Guest location sharing

This file tracks known location tracking concerns that are not yet addressed. Items are grouped by whether they've been **observed** in real testing or are **theoretical / speculative**.

---

## Observed (real, seen in production testing)

These have concrete evidence behind them from testing on 2026-04-10. They should be addressed in a deliberate future pass.

### 1. No retry on fetch failures — High priority

**Evidence:** During a live tour session on 2026-04-10, the guide's task showed ~50% fetch failure rate with `[TypeError: Network request failed]` alternating with successful sends. Failures recovered on their own after a few minutes. Suspected cause: Railway connection reuse going stale, or cold-scaling after an idle period.

**Current behavior:** A failed fetch in the task callback is silently caught. The next scheduled callback (~15 seconds later) tries fresh from scratch. The dropped location is lost.

**Cost:** Effective tracking cadence halves during a failure window. Over minutes this can look like the user is frozen on the map.

**Fix sketch:** Single immediate retry on `TypeError: Network request failed`. Do not retry on 4xx or 410. ~10-15 lines in `backgroundLocation.ts` inside the task callback.

### 2. Burst suppression race causing duplicate records — Low priority

**Evidence:** Observed on 2026-04-10 post-layout-sync deployment. The guest task fired #1 Sent and #2 Sent 11ms apart on initial startup, because both callbacks passed the `_lastForwardedAt < BURST_SUPPRESSION_INTERNAL_WORKAROUND_MS` check before either updated the timestamp.

**Current behavior:** `_lastForwardedAt` is only set inside the `if (response.ok)` branch, *after* the fetch. Concurrent callbacks can race past the gate.

**Cost:** An extra duplicate location row in the DB per burst, with near-identical lat/lng. Zero user-visible impact. Wastes a tiny amount of DB storage and bandwidth.

**Fix sketch:** Set `_lastForwardedAt = now` *before* the fetch, and reset it to the previous value on fetch failure (so failed sends don't poison the window). 2-line change.

### 3. Guest sync 60-second restart churn — Medium priority

**Evidence:** Every tick of `syncGuestLocationTracking` in `_layout.tsx` unconditionally calls `startBackgroundLocationUpdates`. The guest's BG-LOC counter resets to #1 every 60 seconds. Each restart causes ~130ms of tracking interruption and a fresh FLP re-registration (with its own risk of an initial-fix burst being suppressed).

**Why it's this way:** Guest sync can't trust `isLocationSharingActive` as a "task is healthy" signal — `adb install -r` leaves the task registered while the native foreground service is dead. Unconditional restart is the self-healing escape hatch.

**Cost:** Battery drain from foreground service churn. Brief gaps in tracking every minute. Counter resets make debug logs harder to read.

**Fix sketch:** Add a module-level `_lastSuccessfulSendAt` timestamp in `backgroundLocation.ts`. Extend `isLocationSharingActive` with a liveness check: return `false` if `Date.now() - _lastSuccessfulSendAt > 30_000` even when `isTaskRegisteredAsync` is true. Then `syncGuestLocationTracking` can safely gate on the (now trustworthy) `isLocationSharingActive` and skip restart when healthy. The zombie-task case is still caught because the liveness check fails.

---

## Theoretical / speculative

These came up during code review but have not been observed as real problems. They are noted so a future developer evaluating a related change has context, not because they're known to affect users.

### 4. iOS has never been tested

All location tracking work has been validated against Android's Fused Location Provider and expo-task-manager's Android implementation. iOS uses Core Location, `allowsBackgroundLocationUpdates`, `pausesLocationUpdatesAutomatically`, and a different background-task lifecycle. Most of the Android-specific fixes in `backgroundLocation.ts` (burst suppression, deferred 410 stop) do not directly apply to iOS, but may be necessary in different forms.

**Blockers before iOS launch:** real iPhone testing, App Store review notes justifying background location, Info.plist usage strings. See `ios-support.md`.

### 5. Multiple overlapping active sessions

Both `syncGuideLocationTracking` and `syncGuestLocationTracking` take the first element of their active-session list and ignore the rest. What happens when a guide has two concurrent tours, or when a guest has two overlapping bookings, is undefined. The second is silently ignored. No UI surfaces this conflict.

**Not known to occur in practice.** Would require explicit scheduling of overlapping tours.

### 6. Cancelled tours return 404, not 410

The deferred 410 stop handles the case where a tour naturally ends. But if a guide deletes a tour session while the guest is still tracking it, the next location update hits a 404 (not 410) — because the session row no longer exists. The current code logs `[BG-LOC #N] API error 404: ...` as a warning but does not stop the task. The task keeps sending until something else (layout sync, tour end) cleans up.

**Fix sketch:** Treat 404 the same as 410 for the deferred-stop path.

### 7. `ACTIVE_LOCATION_THRESHOLD_MINUTES = 5` may be too aggressive for indoor segments

Backend filters location reads by `recorded_at >= now - 5 minutes`. Any indoor segment (subway, parking garage, building interior) longer than 5 minutes will make a user "disappear" from the map even though the app is still actively tracking. For urban walking tours with no indoor segments this is fine; for tours that include indoor portions it may cause avoidable "where did everyone go?" UX.

**No real-world data yet.** Worth revisiting after actual tours reveal the pattern.

### 8. `getTourSessionStatus` trusts device clock

Status (`upcoming`, `check_in_open`, `in_progress`, `completed`) is computed client-side from `Date.now()`. A phone with wrong system time would misjudge whether the tour is active, which controls when the sync helpers start and stop tracking. The backend already gates writes via its own clock (410 on ended sessions), so server-side damage is limited, but the client could start tracking too early or too late.

### 9. Sync polling interval is a magic number

`_layout.tsx` uses a hardcoded `60_000` for both guide and guest sync intervals. Should probably be a named constant in `constants.ts` (e.g., `LOCATION_SYNC_INTERVAL_SECONDS = 60`). Cosmetic only.

### 10. Noop sync ticks produce no log output

When `syncGuideLocationTracking` / `syncGuestLocationTracking` fire and decide there's nothing to do, they return silently. This makes it hard to verify from adb logcat that the sync is still ticking. A `[GUEST-SYNC] tick (noop)` line once per minute would help debugging but clutter production logs. Accept as-is.

### 11. No dedup on backend location inserts

If the burst race (item 2) or a future retry (item 1) sends the same lat/lng twice within a second, the backend happily inserts two rows. Dedup on `(uid, tour_session_id, recorded_at truncated to second)` would make the data cleaner. Very low priority — no storage or perf concern at current scale.

---

## Recommended order of work

1. **Item 1 (fetch retry)** — concrete bug, observed, cheap fix
2. **Item 3 (heartbeat-based skip)** — cleans up ongoing churn, enables item 3's fix to land cleanly
3. **Item 2 (burst race)** — 2-line fix, do it opportunistically when touching `backgroundLocation.ts`
4. **Item 6 (404 handling)** — concrete gap, not yet observed but trivial to fix
5. **Item 4 (iOS)** — big scope, separate project
6. Everything else — revisit only when specific evidence appears
