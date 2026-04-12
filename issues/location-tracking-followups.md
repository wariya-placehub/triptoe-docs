# Location Tracking Follow-ups

## Status: Items 1, 2, 3 resolved 2026-04-10 / 2026-04-11 overnight. "Tracking stopped" oscillation resolved 2026-04-11. Mysterious counter reset still open (low priority, cosmetic). Guest "1 send then silence" zombie on `2A291FDH200DX4` still open (needs device-level investigation, not another code layer).
## Priority: Mixed (see each item)
## Affects: Guide + Guest location sharing

This file tracks known location tracking concerns that are not yet addressed. Items are grouped by whether they've been **observed** in real testing or are **theoretical / speculative**.

---

## Observed (real, seen in production testing)

These have concrete evidence behind them from testing on 2026-04-10. They should be addressed in a deliberate future pass.

### 1. No retry on fetch failures — ✅ Resolved 2026-04-11 overnight

**Evidence before:** During live tour sessions on 2026-04-10, the guide's task intermittently showed `[TypeError: Network request failed]` alternating with successful sends. Failures recovered on their own after a few minutes. Suspected cause: Railway connection reuse going stale, or cold-scaling after an idle period.

**Before the fix:** A failed fetch in the task callback was silently caught by the outer handler. The next scheduled callback (~15 seconds later) tried fresh from scratch. The dropped location was lost. Effective tracking cadence halved during failure windows.

**Resolution:** Added `fetchLocationUpdateWithRetry` in `backgroundLocation.ts`. One immediate retry on `TypeError: Network request failed`. Does not retry on 4xx, 5xx, or 410 (server made a decision; retrying would be wasted work or harmful). Returns `null` when both attempts throw so the task callback drops the update and waits for the next tick.

Three new log lines for observability:

- `[BG-LOC #N] Fetch failed, retrying once`
- `[BG-LOC #N] Retry succeeded`
- `[BG-LOC #N] Retry also failed, giving up until next callback`

**Verified on both paths:**
- **Scenario A (retry succeeds):** caught a natural transient failure on the first callback of a fresh guide process (2026-04-11 00:54 logs — fetch failed, retry succeeded 419ms later, record landed).
- **Scenario B (both fail):** deliberate 50-second outage induced via `adb shell svc wifi disable` + `svc data disable`. Every outage callback logged both the retry attempt and the giving-up line. Recovery was clean — first successful send 7 seconds after network restored. As a bonus, the heartbeat-driven layout sync correctly treated the prolonged silence as a staleness signal and restarted the task partway through the outage, without user-visible impact.

**Commit:** triptoe-mobile `3071f04` "Add single-retry on TypeError from the location update fetch"

### 2. Burst suppression race causing duplicate records — ✅ Resolved 2026-04-11 overnight

**Evidence before:** Observed on 2026-04-10 post-layout-sync deployment. The guest task fired `[BG-LOC #1] Sent` and `[BG-LOC #2] Sent` 11ms apart on initial startup because both callbacks passed the `_lastForwardedAt < BURST_SUPPRESSION_INTERNAL_WORKAROUND_MS` check before either updated the timestamp.

**Resolution:** `_lastForwardedAt = now` is now assigned synchronously the instant after the check passes, before any `await`. Any concurrent callback that runs during the first fetch sees the updated timestamp and gets correctly suppressed at its own check. The earlier "only consume on success" logic was effectively a no-op because the task's time interval (15s) is already greater than the suppression window (10s), so failed sends don't block the next legitimate retry regardless.

**Verified:** After the fix, no two `Sent` log lines appear within milliseconds of each other. Every successful send is cleanly separated by ~14-15 seconds.

**Commit:** triptoe-mobile `2c3037e` "Claim burst-suppression window synchronously before any await"

### 3. Guest sync 60-second restart churn — ✅ Resolved 2026-04-10 evening

**Evidence before:** Every tick of `syncGuestLocationTracking` in `_layout.tsx` unconditionally called `startBackgroundLocationUpdates`. The guest's BG-LOC counter reset to #1 every 60 seconds. Each restart caused ~130ms of tracking interruption.

**Why it was this way:** Guest sync couldn't trust `isLocationSharingActive` as a "task is healthy" signal — `adb install -r` and force-close + relaunch both leave the task registered while the native foreground service or JS-native binding is dead. Unconditional restart was the self-healing escape hatch.

**Resolution:** A related bug was reported where the guide also hit a zombie-task state after force-close + relaunch (sent 2 records then went silent while `TaskService: Handling intent` kept firing natively). Both bugs had the same root cause: `isTaskRegisteredAsync` isn't a reliable liveness signal.

Added a heartbeat-based liveness check to `isLocationSharingActive` in `backgroundLocation.ts`:

- `_taskStartedAt` — set when `startBackgroundLocationUpdates` returns
- `_lastSuccessfulSendAt` — set inside the task callback on each confirmed successful send
- `isLocationSharingActive` returns true iff registered AND session matches AND (inside startup grace OR recent successful send)

**2026-04-11 update:** `HEARTBEAT_STALE_THRESHOLD_MS` and `STARTUP_GRACE_PERIOD_MS` were later bumped from 30s to 60s when `LOCATION_UPDATE_INTERVAL_SECONDS` was raised from 15s to 30s. Both thresholds are sized at 2× the update interval so a single delayed callback doesn't trip stale.

On a fresh process both timestamps are 0, so the check returns false after force-close and forces a clean restart. During sustained normal operation the heartbeat proves liveness and both syncs correctly skip the restart.

**Result:** Both `syncGuideLocationTracking` and `syncGuestLocationTracking` now gate on `isLocationSharingActive`. Counter stays monotonic during normal operation on both roles. Verified on both phones with force-close + relaunch scenarios: task correctly restarts within 1 second of the fresh process starting.

**Commit:** triptoe-mobile `8f683e8` "Add heartbeat liveness check to isLocationSharingActive"

### NEW: Mysterious counter reset ~14-15 seconds after initial start — Low priority, needs investigation

**Evidence:** Observed repeatedly on 2026-04-10 evening and 2026-04-11 overnight testing. Specifically on the guest process but may also affect the guide. The pattern:

```
00:08:35.070 [BG-LOC #1] Sent (guest session=100037)   ← first send after layout sync start
00:08:49.542 [BG-LOC #1] Sent (guest session=100037)   ← counter reset to 1, 14.5s later
00:09:03.736 [BG-LOC #2] Sent
00:09:18.034 [BG-LOC #3] Sent
... (monotonic from here)
```

The second `[BG-LOC #1]` means `_taskCallCount = 0` was re-executed — which only happens inside `startBackgroundLocationUpdates`. But **no `[BG-LOC] Started for` log** appears between the two `#1` lines, and there's no `[GUEST-SYNC] Ensuring tracking` either. Something is either calling `startBackgroundLocationUpdates` and failing before reaching the "Started for" log at the end, or the log is being dropped somewhere.

**Impact:** Cosmetic. Records still flow at the correct 14-15 second cadence, no duplicates, no gaps. Just makes debug log reading harder because the counter renumbers once near the start.

**Hypotheses to investigate:**

1. **`Location.startLocationUpdatesAsync` throws** on the second call while the task is already running. That would hit the outer catch and log an error — but the error log doesn't appear in the grep. Could also be a path where the catch itself is silent.
2. **`tour-booking-details.tsx handleStartSharing` auto-resume path** may be firing on screen mount. That path calls `startBackgroundLocationUpdates` directly without a preceding sync log. If the user opens the booking details screen ~14 seconds after app launch, this would reset the counter. Easy to verify: log at the entry of `handleStartSharing`.
3. **Something in the React lifecycle** (screen mount, useEffect re-fire, auth restore completion) triggers an unintended second call.

**Next step:** Add a marker `console.log` at the very first line of `handleStartSharing` and at the very first line of `startBackgroundLocationUpdates`. Reproduce, check which caller is firing the second time.

**Note:** Noted as an observation, not an active bug. Tracking is functionally correct. Investigation is worth doing because the same root cause might hide a worse symptom we haven't caught yet.

### NEW: "Tracking stopped" warning pill oscillating on guide during sustained outage — ✅ Resolved 2026-04-11

**Evidence:** With the guide phone's wifi off continuously, the "Tracking stopped" pill on the map flickered on a ~60s cycle instead of staying visible.

**Cause:** The layout-level sync detects the stale heartbeat (no sends for >threshold) every 60s and restarts the task. Each restart reset `taskStartedAt = now`. `getTrackingStatus` then saw a fresh `taskStartedAt` + `lastSuccessfulSendAt === 0` and granted a new 30-second startup grace window, briefly showing `healthy`. After the grace expired it returned `stopped` again. The next layout-sync tick restarted and reset the clock. The UI flickered `stopped` → `healthy` → `stopped` → `healthy` on the same 60s cycle as the sync.

**Resolution:** Added a third timestamp, `firstStartWithoutSuccessAt`. It's set the first time a start happens while `lastSuccessfulSendAt` is still 0, preserved across subsequent restarts while the no-success chain continues, and cleared only when a send actually succeeds. `getTrackingStatus` now measures its grace window from this timestamp, so the window runs once per outage rather than once per restart. `isLocationSharingActive` continues to use `taskStartedAt` — the sync layer still wants a grace window per restart for its own reasoning.

**Commit:** See `src/services/backgroundLocation.ts` — `getTrackingStatus` and `_trackingState.firstStartWithoutSuccessAt`.

### NEW: Guest task "1 send then silence" on this specific phone — Unresolved, needs device-level investigation

**Evidence:** Observed 2026-04-11 overnight on guest phone `2A291FDH200DX4`. The background task sends exactly one record after each restart (triggered by layout sync) and then produces no further callbacks. FLP's cached-fix burst delivers one position, and subsequent scheduled 30s timer callbacks never fire. The foreground service notification remains visible — the native process is alive; the JS executor simply never receives further location events. Guide phone `4B041JEBF09348` on the same codebase, same network, shows steady periodic sends, so the codebase is not the cause.

**Operational workaround:** Full uninstall + fresh install of the guest app cleared the condition. Plain `adb install -r` did not. This suggests accumulated Android system state (TaskManager persisted registration, FLP rate-limiter bookkeeping, foreground service history) that doesn't clear across reinstalls.

**Unverified hypotheses:**

1. **FLP throttling.** Android's Fused Location Provider rate-limits listeners that rapidly re-register. The layout sync's 60s restart loop (when heartbeat is stale) may be triggering that throttle, and once throttled the subsequent scheduled callbacks don't fire. A clean uninstall clears per-app rate limit state, which would match the observed recovery.
2. **Battery optimization / app standby.** Not yet verified; the user reported a full battery but did not confirm the per-app battery-optimization setting.
3. **Device-specific OEM quirk.** The phone with the symptom and the phone without may run different Android builds.

**Why this is hard:** multiple hypothesis-driven fixes were attempted earlier on this same bug, each adding a layer of workaround (fetch retry, heartbeat, burst suppression, deferred 410, firstStartWithoutSuccessAt). None of them have been proven to address the underlying zombie cause. Further changes to `backgroundLocation.ts` should not be made without direct evidence tying the change to the observed symptom — the current code is already carrying a lot of interlocking workarounds.

**Next step:** When the symptom re-occurs, capture `dumpsys activity services com.triptoe.mobile` and `dumpsys location` output on the affected device. Compare to the healthy device. Confirm or rule out FLP throttling before touching code.

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

1. ~~**Item 3 (heartbeat-based skip)**~~ — ✅ **done 2026-04-10 evening** (also fixed guide zombie-task bug as a bonus)
2. ~~**Item 1 (fetch retry)**~~ — ✅ **done 2026-04-11 overnight** (verified on both natural and artificial failures)
3. ~~**Item 2 (burst race)**~~ — ✅ **done 2026-04-11 overnight**
4. **NEW: Mysterious counter reset** — low priority, investigate with marker logs in `handleStartSharing` and `startBackgroundLocationUpdates` entry
5. **Item 6 (404 handling)** — concrete gap, not yet observed but trivial to fix
6. **Item 4 (iOS)** — big scope, separate project
7. Everything else — revisit only when specific evidence appears

**All three original observed items (Items 1, 2, 3) are resolved.** One new observation added — noted as low priority because it's cosmetic, not functional. The theoretical items below remain unchanged.
