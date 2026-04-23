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
| Backend (`send_message`) | Returns 403 with window boundary info |
| Guide chat screen | Replaces composer with lock icon + "Messaging opens/closed [date time]" |
| Guest chat screen | Same as guide |
| Session details | "Send Announcement" button hidden outside window |
| Session details | `openChat()` returns early if window closed |

The displayed open/close times are the actual window boundaries (48h offset from tour start/end), not the tour times themselves. Times are shown in the tour's timezone.

## Guide Inbox

The guide's Inbox tab shows both activity types in one sorted list.

### API: `GET /messaging/inbox`

Returns an array of rows, each with `activity_type`:

**Announcement row:**
```json
{
  "activity_type": "announcement",
  "tour_session_id": 100013,
  "tour_title": "Historic Congress Avenue Walk",
  "start_at": "2026-04-23T14:00:00+00:00",
  "end_at": "2026-04-23T15:30:00+00:00",
  "timezone": "America/Chicago",
  "state": "active",
  "announcement_count": 3,
  "last_activity_at": "2026-04-23T14:15:00+00:00",
  "preview": { "content": "We are starting in 5 minutes!", "sent_at": "..." }
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
  "state": "needs_reply",
  "guest_uid": "GUEST_SEED_001",
  "guest_name": "Emma Wilson",
  "guest_photo": null,
  "unread_count": 2,
  "needs_reply": true,
  "last_activity_at": "2026-04-23T14:10:00+00:00",
  "preview": { "content": "Where should I stand?", "sent_at": "...", "is_own_message": false }
}
```

### Sorting

1. DMs with `needs_reply` first
2. All rows by `last_activity_at` descending

### Filters

| Chip | Shows |
|---|---|
| All | Everything |
| Reply | DMs where `needs_reply` is true |
| Live | Rows where session is active |
| Upcoming | Rows where session hasn't started |
| Recent | Rows where session is completed |

### Unread Semantics

- **DMs**: `unread_count` tracks guest messages the guide hasn't read (via `MessageReadReceipt`)
- **Announcements**: no unread tracking -- shows `announcement_count` and latest preview only

## Chat Screen

### Guide Chat (`app/(guide)/chat.tsx`)

Operates in two modes based on the `guest_uid` route param:

| Mode | Param | Messages shown | Composer | Empty state |
|---|---|---|---|---|
| Announcement | No `guest_uid` | Broadcasts only (`announcements_only=true`) | "Announce to group..." | "No announcements yet" |
| Direct message | With `guest_uid` | Thread between guide and that guest (`conversation_guest_uid`) | "Message [name]..." | "No messages with [name]" |

Quick messages (reusable presets) appear as horizontal chips above the composer when the input is empty.

### Guest Chat (`app/(guest)/chat.tsx`)

Shows all messages visible to the guest (announcements + direct messages to/from the guest). The guest's composer sends directly to the guide (`recipient_uid` is always the guide).

### Session Metadata Fetch

When the chat screen is opened via notification deep link (without `start_at`/`end_at` params), it fetches session metadata from `getTourSession()` to populate the header and messaging window check. This prevents a permissive fallback where the composer would be enabled without knowing the window boundaries.

## Message API

### Endpoints

| Endpoint | Purpose |
|---|---|
| `GET /tour-sessions/<id>/messages` | All messages (mixed activity), or direct thread if `guest_uid` param provided |
| `GET /tour-sessions/<id>/announcements` | Broadcasts only (guide-only) |

### `GET /tour-sessions/<id>/messages` Query Params

| Param | Effect |
|---|---|
| `guest_uid` | Direct thread: messages between guide and that guest only (announcements excluded) |
| (none) | All messages (used by session details for mixed activity preview) |

Guests always see: announcements + messages to them + messages they sent (enforced server-side).

### `GET /tour-sessions/<id>/announcements`

Guide-only. Returns announcements (`recipient_uid IS NULL`) for the announcement chat thread.

### Permission Checks

| Endpoint | Guide | Guest |
|---|---|---|
| `POST /messages` (send) | Must own session; if direct, recipient must be booked | Must have booking |
| `GET /messages` | Must own session | Must have booking |
| `PUT /messages/<id>/read` | Must own session | Must have booking, message must be visible to guest |

## MessageRow Component

`src/components/messaging/MessageRow.tsx` renders messages with visual distinction:

| Message type | Visual treatment |
|---|---|
| Outgoing announcement | "Announcement" pill badge with megaphone icon, distinct bubble color (`announcementBg`) |
| Outgoing direct | "To [name]" label |
| Incoming (from guest) | Guest avatar + name (in mixed-context views), hidden in 1:1 chat via `hideAvatar` |

The "Reply privately" affordance appears as a pill button below incoming guest messages (when `onReply` is provided). On session details, tapping it navigates to the direct chat thread.

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
| Guide | No (announcement) | Session details with auto_open_messages |
| Guest | -- | Guest chat screen (fetches session metadata on mount) |

## Quick Messages

Guides can create reusable message presets (`GET/POST/PUT/DELETE /messaging/quick-messages`) with drag-to-reorder support (`PUT /messaging/quick-messages/reorder`).

Quick messages appear in two places:
- **Chat screen**: horizontal chip row above the composer (visible when input is empty)
- **Chat screen composer**: horizontal chip row above the input (visible when input is empty)

Tapping a chip fills the text input so the guide can review/edit before sending.

## Keyboard Layout (Android)

`KeyboardProvider` from `react-native-keyboard-controller` sets `adjustNothing` at runtime, overriding `softwareKeyboardLayoutMode: "resize"` from `app.json`. The chat screen handles this with:

1. **`KeyboardStickyView`** wraps the composer -- moves it above the keyboard
2. **Dynamic footer spacer** (`keyboardHeight` when open, `0` when closed) -- makes the FlatList content scrollable past the keyboard
3. **Scroll-to-bottom** via `Keyboard.addListener('keyboardDidShow')` with 100ms + 300ms delayed calls

This is the same pattern on both guide and guest chat screens.

## Data Model

All messaging data lives in the `message` schema:

| Table | Purpose |
|---|---|
| `message` | All messages (announcements + DMs), soft-delete via `is_deleted` |
| `message_read_receipt` | Per-user read tracking |
| `quick_message` | Guide's reusable message presets with `sort_order` |
| `messaging_consent` | Guest messaging preferences (not currently used in UI) |
| `blocked_communication` | Block list (not currently used in UI) |
