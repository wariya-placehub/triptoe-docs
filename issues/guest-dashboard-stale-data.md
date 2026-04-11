# Guest Dashboard Shows Stale Tour State

## Priority: Medium
## Affects: Guest My Tours (dashboard) screen

## Problem

The guest dashboard (`app/(guest)/dashboard.tsx`) fetches bookings via `getTourBookings()` once on initial load plus on pull-to-refresh. After the initial fetch, the cached data is used to render booking cards and compute their status client-side via `getTourSessionStatus(start, end, tz)`.

Consequence: if tour state changes on the backend without the guest manually pull-to-refreshing, the dashboard shows stale data.

**Concrete scenarios:**
- A tour naturally crosses its `end_datetime` while the guest has the app open. The dashboard keeps showing an "in-progress" banner and stale start/end times until the guest pulls to refresh or navigates away and back.
- A guide edits a tour's `start_datetime` or `end_datetime` on the backend. Guests with the dashboard open don't see the update.
- A guest's check-in status changes on another device. Not reflected.

**Observed during testing (2026-04-10):** `end_datetime` for tour session 100036 was updated directly in the database to force an early end. The mobile location tracking reacted correctly (next location update returned HTTP 410, task stopped cleanly). But the guest dashboard continued showing the tour as "in-progress" with the old end time until the user pulled to refresh.

## Root Cause

No automatic refresh trigger on the dashboard beyond initial mount and pull-to-refresh. No polling, no `useFocusEffect` refetch, no timer-based re-derivation of status against `Date.now()`. The cached booking data is a snapshot from whenever the dashboard first loaded.

## Options

### Option A: `useFocusEffect` refetch (recommended)
Refetch `getTourBookings()` every time the dashboard screen gains focus. Matches the pattern already used on other tab screens (e.g., guide dashboard/schedule). Lightest-touch fix, handles all the scenarios above.

- Pro: simple, idiomatic, network cost is low (one request per tab switch)
- Con: doesn't catch state changes while the dashboard is actively focused and idle

### Option B: Local status recomputation on a timer
Keep the cached data but re-run `getTourSessionStatus` every 30 seconds against `Date.now()`. Would flip the banner from "in-progress" to "completed" without a server round trip.

- Pro: zero network cost; catches natural tour end while the user is looking at the screen
- Con: doesn't catch server-side changes to `start_datetime`, `end_datetime`, or check-in status

### Option C: Periodic polling of `/guests/my-bookings`
Poll every 30-60 seconds while the dashboard is focused.

- Pro: catches everything
- Con: heaviest; most network cost; overkill for the problem

### Option D: Combine A + B
`useFocusEffect` refetch on screen focus AND local status re-derivation on a 30s timer while focused.

- Pro: catches everything meaningful (state transitions while idle + server-side changes on return)
- Con: slightly more code than A alone

## Recommendation

**Option A first** as the minimum viable fix — it matches the existing pattern in the app and handles the most common real-world scenario (guest returns to the dashboard after navigating away). **Add Option B (local timer)** if users report "I was looking at my booking when the tour ended and the banner never updated".

## Files Affected

- `app/(guest)/dashboard.tsx` — add `useFocusEffect` refetch
- (Optional, for Option B) local `useEffect` with `setInterval` to force a re-render every 30 seconds
