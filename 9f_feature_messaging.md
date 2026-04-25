# Messaging

Audience: Developer, Product Manager

## Overview

TripToe messaging connects guides and guests before, during, and after tours. Messaging is split into two activity types -- **announcements** (one-to-many) and **direct messages** (one-to-one) -- unified under a single guide inbox.

## Activity Types

| Type | Direction | Scope | Data shape |
|---|---|---|---|
| Announcement | Guide to all guests | Session-level | `recipient_uid IS NULL` |
| Direct message | Guide to guest, or guest to guide | Guest-level thread | `recipient_uid IS NOT NULL` |

Both types share the same `message` table. The distinction is derived from `recipient_uid`, not stored separately.

## Messaging Window

All messaging is gated by a time window relative to the tour session:

- **Opens**: 48 hours before `start_at`
- **Closes**: 48 hours after `end_at`
- Constants: `MESSAGING_PRE_TOUR_HOURS` (48), `MESSAGING_POST_TOUR_HOURS` (48)

Enforcement:

| Layer | Behavior |
|---|---|
| Backend (`send_message`) | Returns 403 with absolute boundary message in the tour's timezone -- matches mobile UI wording (`Messaging opens Tue, Mar 10 - 9:30 PM` / `Messaging closed ...`) |
| Guide chat screen | Replaces composer with lock icon + "Messaging opens/closed [date time]" |
| Guest chat screen | Same as guide |
| Session details (guide) | "Send Announcement" sticky footer hidden outside window |
| Session details (guide) | Bubble icon on guest cards hidden outside window |
| Tour booking details (guest) | "Message Guide" button / sticky footer hidden outside window |
| Inbox rows | Dimmed to `opacity: 0.55` when window is closed (read-only signal, not disabled) |

All boundary checks use the shared helper `useMessagingWindow(startAt, endAt, timezone)` and its pure-function counterpart `isMessagingWindowOpen(startAt, endAt)` in `src/hooks/useMessagingWindow.ts`.

The displayed open/close times are the actual window boundaries (48h offset from tour start/end), not the tour times themselves. Times are shown in the tour's timezone.

## Guide Inbox

The guide's Inbox tab shows both activity types in one sorted list. It is the primary triage surface for in-flight conversations.

### API: `GET /messaging/inbox`

Returns an array of rows, each with `activity_type`. The backend supplies only raw session timestamps and the `needs_reply` flag on DMs; the client derives lifecycle and sorting.

**Announcement row:**
```json
{
  "activity_type": "announcement",
  "tour_session_id": 100013,
  "tour_title": "Historic Congress Avenue Walk",
  "start_at": "2026-04-23T14:00:00+00:00",
  "end_at": "2026-04-23T15:30:00+00:00",
  "timezone": "America/Chicago",
  "announcement_count": 3,
  "last_message_at": "2026-04-23T14:15:00+00:00",
  "preview": { "content": "We are starting in 5 minutes!", "sent_at": "...", "is_own_message": true }
}
```

**Direct message row:**
```json
{
  "activity_type": "direct_message",
  "tour_session_id": 100013,
  "tour_title": "Historic Congress Avenue Walk",
  "start_at": "...",
  "end_at": "...",
  "timezone": "America/Chicago",
  "guest_uid": "GUEST_SEED_001",
  "guest_name": "Emma Wilson",
  "guest_photo": null,
  "unread_count": 2,
  "needs_reply": true,
  "last_message_at": "2026-04-23T14:10:00+00:00",
  "preview": { "content": "Where should I stand?", "sent_at": "...", "is_own_message": false }
}
```

### Lifecycle (derived client-side)

The inbox no longer uses a backend-computed `state` field. Each row's lifecycle stage is computed from `start_at` / `end_at` via `getTourSessionStatus()`:

| Derived value | Source |
|---|---|
| `upcoming` / `today` | Session in the future |
| `check_in_open` / `in_progress` | Session active now |
| `completed` | Session ended |

This matches the same five `TourSessionStatus` values used elsewhere in the app. Lifecycle is orthogonal to `needs_reply` -- a completed session with an outstanding reply stays flagged.

### Filters

| Chip | Matches | Notes |
|---|---|---|
| All | Everything | Default landing view |
| Reply | DMs where `needs_reply === true` | Cross-cuts lifecycle |
| Live | `in_progress` OR `check_in_open` | Sessions happening now |
| Upcoming | `upcoming` OR `today` | Sessions ahead, not yet live |

Completed sessions surface only under **All** and **Reply**. No dedicated Completed tab -- they are reviewed via the session details screen.

### Sorting

Always sorted by `last_message_at` desc (newest message first), both server-side and client-side. The user has no toggle.

Backend returns rows pre-sorted by `last_message_at` desc as a stable default. Mobile re-sorts after filtering to the same key.

A user-selectable Tour Date sort was prototyped and removed because the inbox is fundamentally a message-triage surface, and the Schedule tab already provides date-ordered session browsing. Mixing the two sort axes added complexity without clear value.

### Row Layout

Each row is structured as `avatar | content column | right-side column (20px)`:

- **Line 1**: tour title / guest name (truncates with `flex-1 mr-2`) + relative timestamp
- **Line 2**: tour title (DM rows only) OR session date (announcement rows)
- **Line 3**: session date (DM rows only)
- **Preview line**: `You: {content}` for outgoing messages; bare `{content}` for incoming guest messages
- **Right-side column**: 20px reserved on every row to keep timestamps aligned across row types. Houses the unread badge on DM rows; empty spacer on announcement rows.

Unread DM rows: bold name, accent-colored timestamp, filled badge.
Read DM rows: medium name, muted timestamp, no badge (empty 20px column still reserved).
Messaging-closed rows: entire row at `opacity: 0.55`, dimming uniform across content and badge.

### Unread Semantics

- **DMs**: `unread_count` tracks guest messages the guide has not read (via `MessageReadReceipt`).
- **Announcements**: no unread tracking. The row preview shows the latest announcement content (with `You: ` prefix) instead of a count; `announcement_count` is still returned by the API but unused by the current UI.

## Session Messages Feed

`app/(guide)/tour-session-messages.tsx` (title: "Messages") is the per-session message feed shown during live sessions and again from the post-tour Messages tab.

### Entry Points

| From | Navigation |
|---|---|
| Session details sticky footer "Messages (N)" button | `router.push` (live sessions) |
| Session details "Messages" tab in post-tour tab bar | Renders via `MessagesTab` component using the same shared feed component |

### Layout

The feed mixes:

- **Conversation cards**: one card per consecutive run of DMs with the same guest. Card chrome: `colors.surface` fill + `colors.border` outline + rounded-xl. Header shows guest avatar + name. Inside, each message renders as a flat row with a direction icon (`return-down-forward-outline` for guide replies), message content, and per-message timestamp. Footer: `Message {Guest} >` action routing to the direct chat thread.
- **Announcement rows**: rendered inline as `MessageRow` bubbles. Break conversation clusters when interleaved chronologically.

Clustering logic lives in `src/components/messaging/MessageFeed.tsx`:

- `buildMessageFeed(messages, guests): MessageFeedItem[]` -- pure builder
- `MessageFeedItemView` -- default component that renders a single item (announcement row OR conversation card)

Both `tour-session-messages.tsx` and `MessagesTab.tsx` use this shared component so live and post-tour views look identical.

### Announcements Shortcut

The native stack header has a `headerRight` pill with a megaphone icon labelled "Announcements" that routes to the chat screen in announcement-only mode. This is the entry point for composing or reviewing broadcasts.

### Polling

`useFocusPolling(fetchMessages, MESSAGE_POLL_INTERVAL_SECONDS, !!tour_session_id)` keeps data fresh while the screen is focused. Polling pauses on blur.

## Chat Screen

### Guide Chat (`app/(guide)/chat.tsx`)

Operates in two modes based on the `guest_uid` route param:

| Mode | Param | Messages shown | Composer | Empty state |
|---|---|---|---|---|
| Announcement | No `guest_uid` | Broadcasts only (`announcements_only=true`) | "Announce to group..." | "No announcements yet" |
| Direct message | With `guest_uid` | Thread between guide and that guest (`conversation_guest_uid`) | "Message [name]..." | "No messages with [name]" |

Quick messages (reusable presets) appear as horizontal chips above the composer when the input is empty.

**Tappable header**: the title + session date bar above the messages is a `TouchableOpacity` with a `chevron-forward` affordance. Tap to jump to session details. If the previous route was already session details, calls `navigation.goBack()` to avoid pushing a duplicate entry; otherwise `router.push`.

### Guest Chat (`app/(guest)/chat.tsx`)

Shows all messages visible to the guest (announcements + direct messages to/from the guest). The guest's composer sends directly to the guide (`recipient_uid` is always the guide).

### Session Metadata Fetch

When the chat screen is opened via notification deep link (without `start_at`/`end_at` params), it fetches session metadata from `getTourSession()` to populate the header and messaging window check. This prevents a permissive fallback where the composer would be enabled without knowing the window boundaries.

## Post-Tour Messaging

Within the 48h post-tour grace window, both sides retain messaging capability:

### Guide side

| Affordance | Location | Gate |
|---|---|---|
| Bubble icon on each guest row (initiate or continue DM) | Session details -> Guests tab (completed state) in `GuestsTab` | `isMessagingOpen` |
| "Send Announcement" sticky footer button | Session details sticky footer | `isMessagingOpen` |
| "Messages (N)" sticky footer button | Session details sticky footer | Hidden when `tourSessionStatus === 'completed'` (redundant with the Messages tab that appears in the completed tab bar) |
| "Message {Guest} >" link on each conversation card | Messages feed (shared component) | Always navigates; chat screen handles the window check |

### Guest side

| Affordance | Location | Gate |
|---|---|---|
| "Message Guide" sticky footer button | Tour booking details (Messages tab only, via `postTourActiveTab` state lifted from `GuestPostTourTabs`) | `tourSessionStatus === 'completed' && messagingAvailable && tourBooking.guide` |

The guest sticky footer is gated to the Messages tab (not Photos / Reviews / Picks) because it is a contextual action tied to that view.

## Message Timestamp Formatting

`formatEventTimestamp(dt, timezone)` in `src/utils/formatDate.ts`:

- If `dt` is today in the given timezone: returns time only (e.g. `9:30 PM`)
- Otherwise: returns date + time (e.g. `Tue, Mar 10 - 9:30 PM`)

Used by `MessageRow`, `MessageFeed`, and the `GuestsTab` check-in label so event timestamps across the app read naturally regardless of when they are viewed.

## Navigation Helpers

`src/utils/messageNavigation.ts` centralizes the param shape for guide message-screen navigation. All in-app pushes go through one of three helpers:

| Helper | Target route |
|---|---|
| `pushGuideDirectChat(router, meta, guest)` | `/(guide)/chat` with `guest_uid` + `guest_name` |
| `pushGuideAnnouncementThread(router, meta)` | `/(guide)/chat` (no guest -- announcement-only mode) |
| `pushGuideSessionMessages(router, meta)` | `/(guide)/tour-session-messages` |

`meta` is a `GuideSessionRouteMeta = { tour_session_id, tour_title?, timezone?, start_at?, end_at? }`. Each helper builds the param object internally so adding/removing a session-level field touches one file. Distinct from `src/utils/navigationHelpers.ts`, which routes through the dashboard's pending-destination store for cold-start / notification flows.

## Message API

### Endpoints

| Endpoint | Purpose |
|---|---|
| `GET /tour-sessions/<id>/messages` | All messages (mixed activity), or direct thread if `guest_uid` param provided |
| `GET /tour-sessions/<id>/announcements` | Broadcasts only (guide-only) |
| `GET /messaging/inbox` | Guide inbox feed (two activity types) |

### `GET /tour-sessions/<id>/messages` Query Params

| Param | Effect |
|---|---|
| `guest_uid` | Direct thread: messages between guide and that guest only (announcements excluded) |
| `announcements_only=true` | Broadcasts only |
| (none) | All messages (used by session messages feed) |

Guests always see: announcements + messages to them + messages they sent (enforced server-side).

### Permission Checks

| Endpoint | Guide | Guest |
|---|---|---|
| `POST /messages` (send) | Must own session; if direct, recipient must be booked | Must have booking |
| `GET /messages` | Must own session | Must have booking |
| `PUT /messages/<id>/read` | Must own session | Must have booking, message must be visible to guest |

## MessageRow Component

`src/components/messaging/MessageRow.tsx` renders individual bubbles. Used in:

- Chat screen (both guide and guest, both modes)
- Announcement items inside the session messages feed

Visual treatment:

| Message type | Treatment |
|---|---|
| Outgoing announcement | "Announcement" pill badge with megaphone icon; bubble fill `messageBg` |
| Outgoing direct | "To [name]" label above content |
| Incoming (from guest) | Attribution `senderName` + avatar in mixed-context views; `hideAvatar` suppresses the avatar column in 1:1 chat |

Timestamps use `formatEventTimestamp` (time-only today, date+time otherwise).

Note: the old `announcementBg` theme token was removed. Announcements and direct messages share the same `messageBg`; the "Announcement" badge + context (feed vs chat thread) do the disambiguation.

## Push Notifications

### Payload

| Message type | Push payload |
|---|---|
| Announcement | `{ type: 'new_message', tour_session_id, recipient_type: 'guest' }` |
| Direct message | `{ type: 'new_message', tour_session_id, recipient_type, sender_uid, sender_name, tour_booking_id? }` |

### Routing on Tap

| Recipient | Sender info present? | Navigation target |
|---|---|---|
| Guide | Yes (`sender_uid`) | Direct chat with that guest |
| Guide | No (announcement) | Session details with `auto_open_messages` param |
| Guest | -- | Guest chat screen (fetches session metadata on mount) |

## Quick Messages

Guides can create reusable message presets (`GET/POST/PUT/DELETE /messaging/quick-messages`) with drag-to-reorder support (`PUT /messaging/quick-messages/reorder`).

Quick messages appear as a horizontal chip row above the composer on the chat screen (visible when the input is empty). Tapping a chip fills the text input so the guide can review/edit before sending.

## Keyboard Layout (Android)

`KeyboardProvider` from `react-native-keyboard-controller` sets `adjustNothing` at runtime, overriding `softwareKeyboardLayoutMode: "resize"` from `app.json`. The chat screen handles this with:

1. **`KeyboardStickyView`** wraps the composer -- moves it above the keyboard
2. **Dynamic footer spacer** (`keyboardHeight` when open, `0` when closed) -- makes the FlatList content scrollable past the keyboard
3. **Scroll-to-bottom** via `Keyboard.addListener('keyboardDidShow')` with 100ms + 300ms delayed calls

This is the same pattern on both guide and guest chat screens.

## Theming

Messaging-related tokens (see `ThemeProvider.tsx`):

| Token | Light | Dark | Used for |
|---|---|---|---|
| `bg` | `#f3f4f6` | `#0f172a` | Canvas behind cards / bubbles |
| `surface` | `#ffffff` | `#1e293b` | Conversation card fill, inbox screen bg |
| `messageBg` | `#e2e8f0` | `#2d3a4d` | All message bubbles (DMs + announcements) |
| `guideAccent` | `#1A4B7D` | `#75a5cf` | Announcement badge, "Message X" link, unread pill |
| `btnPrimary` | `#1A4B7D` | `#1A4B7D` | Send Announcement (guide) |
| `btnGuideSecondary` | `#1A4B7D26` | `#75a5cf33` | Messages (tonal, paired with primary) |
| `btnOcean` | `#5eaec8` | `#5eaec8` | Message Guide (guest primary) |
| `btnGuestSecondary` | `#2678a026` | `#a5dbed33` | Reserved (no caller yet) |

## Data Model

All messaging data lives in the `message` schema:

| Table | Purpose |
|---|---|
| `message` | All messages (announcements + DMs), soft-delete via `is_deleted` |
| `message_read_receipt` | Per-user read tracking |
| `quick_message` | Guide's reusable message presets with `sort_order` |
| `messaging_consent` | Guest messaging preferences (not currently used in UI) |
| `blocked_communication` | Block list (not currently used in UI) |
