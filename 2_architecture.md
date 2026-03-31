# Architecture

Audience: Architect, Tech Lead

## Overview

TripToe is composed of two codebases deployed on a single infrastructure provider:

```
triptoe-mobile (Expo / React Native)  →  triptoe-backend (Flask)  →  PostgreSQL + PostGIS
                                                                       (all hosted on Railway)
```

### Design Principles

- **Single provider** — All infrastructure runs on Railway to minimize operational complexity and cost
- **Mobile-first** — The mobile app is the only client; there is no web frontend
- **Self-contained auth** — Authentication is built into the backend (Google OAuth for guides, email verification codes for guests, JWT via flask-jwt-extended)
- **Push via Expo** — Push notifications use Expo Push Service, which abstracts APNs and FCM

## System Architecture

```mermaid
graph TB
    subgraph "Mobile Client"
        APP[Expo / React Native App]
    end

    subgraph "Railway"
        API[Flask API]
        DB[(PostgreSQL + PostGIS)]
        FILES[File Storage - Railway Volume]
    end

    subgraph "External Services"
        RESEND[Resend Email API]
        EXPO[Expo Push Service]
        APNS[Apple APNs]
        FCM[Google FCM]
    end

    APP -->|REST API + JWT| API
    API --> DB
    API --> FILES
    API -->|Send verification emails| RESEND
    API -->|Send push| EXPO
    EXPO --> APNS
    EXPO --> FCM
    APNS -->|iOS push| APP
    FCM -->|Android push| APP
    APP -->|Location updates| API
```

## Technology Stack

### Mobile Client (triptoe-mobile)

| Concern | Technology |
|---|---|
| Framework | Expo SDK 55 (React Native 0.83) |
| Navigation | Expo Router (file-based) with bottom tabs (Ionicons) |
| Styling | NativeWind (Tailwind CSS for React Native) |
| State management | Zustand |
| HTTP client | Axios |
| Maps | react-native-maps (Google Maps native) |
| Location | expo-location (foreground + background) |
| Timezone detection | expo-localization (device timezone auto-detect) |
| Date/time pickers | @react-native-community/datetimepicker |
| Push notifications | expo-notifications |
| QR scanning | expo-camera |
| Network images | expo-image (uses Coil on Android — does not cache failed loads unlike React Native's Fresco) |
| Secure storage | expo-secure-store (for JWT tokens) |

#### UI Component Library (`src/components/ui/`)

| Component | Purpose |
|---|---|
| `Button` | Variants: primary, secondary, ocean, danger, ghost, ghost-ocean, ghost-danger. Supports `compact` prop. |
| `Card` | Card container with consistent padding and border |
| `Input` | Styled text input |
| `LoadingScreen` | Full-screen loading spinner |
| `EmptyState` | Placeholder for empty lists |
| `TimezonePicker` | Full-screen modal with searchable IANA timezone list |
| `StatusBadge` | Generic pill badge with `label`, `color`, and `variant` (outline or filled) props. No domain knowledge — used as base for `TourSessionStatusBadge` and `CheckInBadge`. |
| `TabBar` | Segmented pill-style tab bar (used for session grouping: This Week / Upcoming / Past) |
| `StarRating` | Interactive or read-only star rating (1–5) using Ionicons |
| `PhotoModal` | Full-screen photo viewer with close button overlay |
| `CheckInBadge` | Filled green "Checked In" badge. Wraps `StatusBadge` with `variant="filled"`. |
| `InfoLine` | Icon + text line for metadata display. `type` prop: `location` (pin icon), `time` (clock icon), `tag` (tag icon). Supports optional `children` (e.g., "Map" link). |
| `ActionLink` | Small icon + text link button for card actions (Edit, Share, etc.). Props: `icon`, `label`, `onPress`, optional `color`. |

#### Tour Components (`src/components/tour/`)

Shared domain components used by both guide and guest screens.

| Component | Purpose |
|---|---|
| `TourSessionHeader` | Reusable header used on Tour Sessions (guide), Session Details (guide), and Tour Details (guest). Props: `title`, `timeInfo` (duration or datetime), `meetingPlace` (with `InfoLine` location icon and optional "Map" link when `meetingCoordinates` provided), `detail` (e.g. tour code with `InfoLine` tag icon), `description` (3-line truncated), `status` (`TourSessionStatusBadge`), `coverImageUrl` (120×120 thumbnail), `action` (e.g. Edit Session button), `onTitlePress` (makes title and thumbnail tappable). Handles map navigation internally via `Linking` API. |
| `TourSessionStatusBadge` | Maps `TourSessionStatus` to label + color, renders outline `StatusBadge`. Colors: Upcoming (ocean blue), Today (tour blue), Check-in Open (amber), In Progress (green), Completed (teal). |
| `TourTemplateForm` | Shared form for Create Tour and Edit Tour screens. Manages image state internally (cover image + meeting place photo) and reports changes via `ImageChanges` in `onSubmit`. Includes map picker, meeting place details, and optional `onDelete` prop. |
| `MapPickerModal` | Full-screen map modal for setting meeting point. Features: pin drop, drag to adjust, reverse geocoding to suggest address, forward geocoding from `initialQuery` (meeting place text). Uses `DEV_FALLBACK_REGION` from constants as last resort. |
| `QRModal` | QR code modal for both session QR and template QR. Dark theme (tourBlue background) for session, light theme (white background) for template. Shared across guide screens. |
| `DateStrip` | Horizontal scrollable date pills for the schedule tab. Auto-scrolls to active date, highlights today. |
| `GuidePicksList` | Grouped list of guide's local recommendations by category (eat, drink, see, shop, do). Shared between guide management and guest post-tour view. Accepts optional `onEdit`/`onDelete` props for guide editing mode. |
| `GuideProfileModal` | Bottom-sheet modal showing guide bio, languages, specialties. Used on guest Tour Details screen. |
| `ActiveTourBanner` | Orange/green banner for active tours (check-in open or in progress). Takes raw `startDatetime`, `endDatetime`, `timezone` and handles its own time formatting and status calculation internally. Used on guide dashboard, guide schedule, and guest dashboard. |

#### Guide Components (`src/components/guide/`)

Guide-specific components, not used by guest screens.

| Component | Purpose |
|---|---|
| `GuideTourTemplateCard` | Tour template card on My Tours dashboard. Shows title, duration, meeting place, next session date, cover image thumbnail, Edit and Share (template QR) action links. |
| `GuideTourSessionCard` | Session card used on Tour Sessions and Schedule screens. `titleMode` prop controls bold top line: `'date'` or `'tour'`. Shows time range with "Edit" link, status badge, booking/check-in counts, QR button. |
| `GuidePickModal` | Bottom-sheet modal for adding/editing a Guide's Pick (place name, category, note, map link). |
| `GuestsTab` | Guest list tab for Session Details (completed tour) |
| `MessagesTab` | Messages tab for Session Details (completed tour) |
| `PhotosTab` | Photos tab for Session Details (completed tour) |
| `ReviewsTab` | Reviews tab for Session Details (completed tour) |

#### Guest Components (`src/components/guest/`)

Guest-specific components, not used by guide screens.

| Component | Purpose |
|---|---|
| `GuestTourBookingCard` | Booking card on guest My Tours dashboard. Shows tour info with `InfoLine` icons, `TourSessionStatusBadge`, `CheckInBadge`, cover image. Day-of nudge: when tour starts within 60 minutes, shows meeting place photo and "To Meeting Point" navigation button. Accepts `now` prop for local timer-based re-evaluation. |
| `GuestUpcomingSessionCard` | Session card on the Select Session screen (after scanning template QR). Shows date, time range, booking count, and Join button. |

#### Color Theme (TripToe Design System)

| Token | Base Color | Usage |
|---|---|---|
| `tourBlue` | `#1A4B7D` | Guide primary, tab accents, branding, "Today" status badge |
| `oceanBlue` | `#82c4da` | Guest primary, tab accents, "Upcoming" status badge |
| `pinOrange` | `#FF5722` | CTAs, warnings |
| `actionGreen` | `#4CAF50` | Success, "In Progress" status badge |
| `amber` | `#d97706` | "Check-in Open" status badge |
| `teal` | `#5f9ea0` | "Completed" status badge |
| `charcoal` | `#333333` | Text, neutral |

Each color has 50–900 shades defined in `tailwind.config.js`.

#### Shared Utilities (`src/utils/`)

| Utility | Purpose |
|---|---|
| `tourUtils.ts` | `TourSessionStatus` type; `getTourSessionStatus()` — computes session status; `getCheckinEligibility()` — determines check-in button state and message; `canDeleteSession()` — checks booking count and status; `getThisWeekBounds()` — single source of truth for "This Week" tab window (today + 6 days) |
| `formatDate.ts` | `formatDate()`, `formatTime()`, `formatDateTime()`, `formatTimeRange()`, `formatDateGroupLabel()`, `formatDateWithYear()`, `formatTimeCompact()` — all display times in the tour template's timezone |
| `recurrence.ts` | `generateRecurringSessions()` — generates batch session arrays from recurrence config (daily/weekly/weekday/custom); `wallClockToUTC()` / `pickerDateToUTCISO()` — timezone-safe conversion of picker values to UTC |
| `apiError.ts` | `getApiError()` — extracts `error.response?.data?.error` with fallback |
| `confirmAction.ts` | `confirmAction()` — reusable destructive action confirmation (Alert + async try/catch) |
| `imageUrl.ts` | `getImageUrl()` — converts relative upload paths (e.g. `/uploads/tour_covers/abc.jpg`) to full URLs using `API_BASE_URL` from constants; passes through absolute URLs unchanged |
| `imagePicker.ts` | `showImagePickerAlert(title, onPick, options)` — shows Camera/Photo Library alert; `pickImageFromLibrary()` / `pickImageFromCamera()` — individual pickers. All image pickers should pass `allowsEditing` and `aspect` matching the backend crop ratio (1:1 for cover/profile, 4:3 for meeting place) |
| `navigationParams.ts` | DRY helpers for building navigation param objects: `buildEditTourTemplateParams()`, `buildTourSessionDetailsParams()`, `buildEditSessionParams()`, `serializeCoordinates()` / `deserializeCoordinates()`, `formatSessionDateTime()` |

#### Shared Hooks (`src/hooks/`)

| Hook | Purpose |
|---|---|
| `useHeaderBackButton.ts` | Adds a back arrow to the header. Uses `router.replace()` by default (for hidden tab screens) or `router.navigate()` via `method` param (for tab screens like Schedule, to trigger `useFocusEffect`) |
| `useTourSessionTabs.ts` | Groups sessions/bookings into This Week / Upcoming / Past tabs with smart sorting (ascending for future, descending for past) |
| `useTourStatus.ts` | Calculates and periodically updates the tour status (heartbeat) |
| `useQRModal.ts` | Manages QR modal state: open/close, fetch QR code, store title/date for display. Supports both session QR (`handleShowQR`) and template QR (`handleShowTemplateQR`). |
| `useGuideTourSessions.ts` | Fetches tour sessions (upcoming + optionally past) across all templates via single API call. Used by Schedule screen. |
| `useTourSessionStatus.ts` | Calculates and periodically updates the tour session status (heartbeat) |

#### Configuration

App-wide constants are centralized in `src/constants.ts`:
- `API_URL` / `API_BASE_URL` — single source of truth for backend URL (from `EXPO_PUBLIC_API_URL` env var, logs error if missing in non-dev builds)
- `DEV_FALLBACK_REGION` — default map region when device location and geocoding both fail (broad view, not production default)
- Polling intervals, distance thresholds, check-in window
- Theme colors for JS props (mirrors `tailwind.config.js` tokens)

#### Real-time Updates (Silent Polling Strategy)

To ensure the UI stays updated without jarring loading spinners, the app uses a **Silent Polling Strategy**:

- **Initial Load**: Shows `LoadingScreen` and resets component state.
- **Background Refresh**: Every 25–30 seconds, the app fetches fresh data from the API and updates state "silently."
- **Affected Screens**:
    - `tour_session_details.tsx`: Updates guest list and check-in counts.
    - `tour_booking_details.tsx`: Updates session metadata and status.
- **Auto-Termination**: Polling intervals are cleared automatically when the tour status transitions to `completed`.

#### Guest Dashboard Refresh Strategy

The guest dashboard uses a three-layer refresh approach:
- **On focus**: Fetches fresh booking data from the API when the screen gains focus (`useFocusEffect`)
- **Local timer**: A 60-second `setInterval` updates `Date.now()` to re-evaluate which tours are "starting soon" (within 60 minutes) — triggers the day-of nudge (meeting place photo + "To Meeting Point" button) with zero network cost
- **Pull-to-refresh**: Manual swipe-down to fetch fresh data from the API

#### Post-Tour Tabs

When a tour session is completed, both guide and guest detail screens switch to a tabbed layout:

| Role | Tabs (in order) |
|---|---|
| **Guide** (Session Details) | Guests, Reviews, Photos, Messages |
| **Guest** (Tour Details) | Review & Tip, Guide's Picks (conditional), Photos, Messages |

The guest's "Guide's Picks" tab only appears if the guide has picks. Default tab for guests is "Review & Tip".

#### Timezone Strategy

Three distinct timezones exist in the system: guide device, guest device, and tour template. The rules are:

- **All tour times display in the tour template's timezone** — via `toLocaleString({ timeZone: tz })` on the frontend. The session creation screen shows a "Times shown in [timezone]" label so guides know which timezone they're setting.
- **Status computation uses UTC math** — `getTourSessionStatus()` compares UTC timestamps (timezone-agnostic), except the "today" check which compares dates in the tour's timezone
- **Session creation uses wall-clock projection** — the date/time pickers return numbers in the phone's local timezone. The frontend extracts those wall-clock values (hour, minute, day) and projects them into the tour template's timezone using `wallClockToUTC()` before sending UTC ISO strings to the backend. This ensures a guide in New York scheduling a tour for 9:00 AM London time sends the correct UTC instant, not 9:00 AM New York time. Recurring session generation uses the same projection per-date to avoid DST drift.
- **API responses always include timezone offset** — the backend serializes datetimes via Python's `.isoformat()` on UTC-aware objects, producing strings like `2026-03-11T15:30:00+00:00`. JavaScript's `new Date()` parses these correctly as UTC.
- **All datetimes stored in UTC** in the database (PostgreSQL `DateTime(timezone=True)`)

#### Navigation

Both guide and guest flows use **bottom tab navigation** (Expo Router `<Tabs>`):

| Role | Tab 1 | Tab 2 | Tab 3 |
|---|---|---|---|
| Guide | My Tours (dashboard) | Schedule (day planner) | Profile |
| Guest | My Tours (dashboard) | Join Tour (QR/code) | Profile |

Non-tab screens are hidden from the tab bar with `href: null`:
- **Guide**: `tour_sessions`, `tour_session_details`, `tour_session_messages`, `create_tour_template`, `create_tour_session`, `edit_tour_template`, `quick_messages`, `guide_picks`, `tip_links`, `edit_account`, `signin`
- **Guest**: `tour_booking_details`, `join_tour_session`, `tour_session_messages`, `signin`, `signup`

#### Edit Navigation

Edit screens use a `back_to` param to return to the originating screen:

| Screen | Accessible from | Back/Save goes to |
|---|---|---|
| Edit Tour Template | My Tours (edit icon + text), Tour Sessions (tap title/thumbnail) | My Tours or Tour Sessions (based on `back_to` param) |
| Edit Session | Tour Sessions (Edit link on card), Schedule (Edit link on card), Session Details (Edit Session button) | Tour Sessions, Schedule, or Session Details (based on `back_to` param) |

Delete Tour always returns to My Tours (since the tour no longer exists). Schedule uses `router.navigate()` instead of `router.replace()` to trigger data reload via `useFocusEffect`.

#### Session Grouping (TabBar)

Both the guide's tour sessions and the guest's My Tours dashboard group sessions into three tabs:

| Tab | Contents | Sort |
|---|---|---|
| **This Week** | Sessions starting today through the next 6 days (7-day window) | Ascending (soonest first) |
| **Upcoming** | Sessions starting after this week | Ascending (soonest first) |
| **Past** | Sessions starting before today | Descending (most recent first) |

Bucketing is based on `start_datetime`, not tour status. A completed session that started today stays in "This Week" until the day ends. The default tab is the first non-empty one (This Week → Upcoming → Past). Both guide and guest use the same client-side grouping via the `useTourSessionTabs` hook, with `getThisWeekBounds()` from `tourUtils.ts` as the single source of truth for the 7-day window.

#### Guide Dashboard Sorting

Tour templates on the guide's My Tours dashboard are sorted by nearest upcoming session first. The `GET /tours` API returns a `next_session_date` field (batch-queried) and each card shows "Next: [date]" when an upcoming session exists.

### Backend (triptoe-backend)

| Concern | Technology |
|---|---|
| Framework | Flask |
| ORM | Flask-SQLAlchemy |
| Migrations | Raw SQL scripts (manually applied) |
| Database | PostgreSQL + PostGIS |
| Auth | Google OAuth (guides) + email verification code (guests) + flask-jwt-extended |
| Email | Resend (verification codes for guest signup/sign-in) |
| Push notifications | HTTP POST to Expo Push API (requires Firebase/FCM for Android delivery) |
| File storage | Railway volume (local disk) |
| CORS | Flask-CORS |
| Scheduled jobs | APScheduler (BackgroundScheduler) |
| WSGI server | Gunicorn |

### Infrastructure (Railway)

| Resource | Purpose |
|---|---|
| Web service | Flask API (deployed from Dockerfile) |
| PostgreSQL | Database with PostGIS extension |
| Volume | File storage (generated QR codes, profile photos, tour cover images, meeting place photos, tour session photos) |

## Data Model

The data model follows a **template-session pattern**: guides create reusable **Tour Templates**, then create **Tour Sessions** for specific occurrences of those tours.

### PostgreSQL Schemas

Tables are organized into five PostgreSQL schemas:

| Schema | Purpose | Tables |
|---|---|---|
| `guide` | Guide and operator data | guide, guide_pick, guide_location, operator, guide_operator_role |
| `guest` | Guest accounts and location | guest, guest_location, verification_code |
| `tour` | Tours, sessions, bookings | tour_template, tour_session, tour_booking, tour_checkin, tour_review, tour_session_photo, archived_booking |
| `message` | Messaging system | message, message_read_receipt, messaging_consent, quick_message, blocked_communication |
| `shared` | Cross-cutting concerns | device_token |

### Entity Relationship Diagram

```mermaid
erDiagram
    Operator ||--o{ TourTemplate : owns
    Operator ||--o{ GuideOperatorRole : has
    Guide ||--o{ GuideOperatorRole : has
    Guide ||--o{ GuidePick : curates
    Guide ||--o{ TourSession : leads
    TourTemplate ||--o{ TourSession : "has"
    TourSession ||--o{ TourBooking : has
    TourSession ||--o{ TourCheckin : has
    TourSession ||--o{ Message : contains
    TourSession ||--o{ MessagingConsent : has
    Guest ||--o{ TourBooking : makes
    Guest ||--o{ TourCheckin : performs
    Guest ||--o{ GuestLocation : reports
    Guest ||--o{ MessagingConsent : grants
    TourBooking ||--o{ TourCheckin : "linked to"
    GuestLocation }o--|| TourSession : "during"
    Message ||--o{ MessageReadReceipt : has
    Guide ||--o{ QuickMessage : creates
    TourBooking ||--o| TourReview : has
    TourSession ||--o{ TourReview : has
    TourSession ||--o{ TourSessionPhoto : has

    Guide {
        string guide_uid PK
        string email_address UK
        string guide_name
        string phone_number
        string google_user_id
        string tip_link
        bool is_active
    }

    Guest {
        string guest_uid PK
        string email_address UK
        string guest_name
        string phone_number
        string account_status
        bool email_verified
        string device_id
    }

    Operator {
        int operator_id PK
        string operator_name
        string operator_type
        string primary_email
        bool is_active
        bool is_verified
        jsonb branding
    }

    GuideOperatorRole {
        int id PK
        string guide_uid FK
        int operator_id FK
        string role
        bool is_primary
    }

    TourTemplate {
        int tour_template_id PK
        int operator_id FK
        string tour_title
        int duration_minutes
        string meeting_place
        point meeting_coordinates
        string timezone
        string cover_image_url
    }

    TourSession {
        int tour_session_id PK
        int tour_template_id FK
        string guide_uid FK
        datetime start_datetime
        datetime end_datetime
        bool allow_guest_messages
        jsonb qr_code_data
    }

    TourBooking {
        int tour_booking_id PK
        int tour_session_id FK
        string guest_uid FK
        datetime booked_at
    }

    TourCheckin {
        int tour_checkin_id PK
        int tour_session_id FK
        string guest_uid FK
        int tour_booking_id FK
        datetime checkin_time
        bool location_sharing_enabled
    }

    GuestLocation {
        int location_id PK
        string guest_uid FK
        int tour_session_id FK
        float latitude
        float longitude
        float accuracy
        datetime recorded_at
    }

    Message {
        int message_id PK
        int tour_session_id FK
        string sender_uid
        string sender_type
        string recipient_uid
        string message_type
        text content
        string status
    }

    MessagingConsent {
        int consent_id PK
        int tour_session_id FK
        string guest_uid FK
        bool receive_guide_messages
        bool send_to_guide
        bool share_phone_with_guide
    }

    MessageReadReceipt {
        int receipt_id PK
        int message_id FK
        string reader_uid
        string reader_type
        datetime read_at
    }

    GuidePick {
        int guide_pick_id PK
        string guide_uid FK
        string place_name
        string category
        text note
        string map_link
        int display_order
        datetime created_at
    }

    QuickMessage {
        int quick_message_id PK
        string guide_uid FK
        string quick_message_name
        text content
        datetime created_at
    }

    TourReview {
        int tour_review_id PK
        int tour_booking_id FK UK
        int tour_session_id FK
        string guest_uid FK
        int rating
        text review_text
        datetime created_at
    }

    TourSessionPhoto {
        int tour_session_photo_id PK
        int tour_session_id FK
        string photo_url
        datetime uploaded_at
    }
```

### Key Design Decisions

- **ID sequences start at 100000** — TourTemplate, TourSession, TourBooking, TourCheckin, and GuestLocation IDs start at 100000 for readability
- **PostgreSQL schemas** — Tables grouped by domain (guide, guest, tour, message, shared) for logical separation
- **PostGIS POINT type** — Meeting point coordinates stored as native PostgreSQL POINT type via a custom `PGPoint` SQLAlchemy type
- **JSONB for flexible data** — QR code data, user preferences, branding, and message metadata use JSONB columns
- **Timezone-aware datetimes** — All timestamps stored in UTC with timezone awareness; tour templates store a `timezone` field so times display in the tour's local timezone
- **Duplicate session prevention** — Backend returns 409 if a session with matching template + start + end already exists
- **Soft deletes for messages** — Messages use `is_deleted` flag rather than hard deletes
- **Archived bookings** — When a tour session is deleted, bookings are moved to an `ArchivedBooking` table rather than being lost
- **Batch session operations** — Sessions can be created in bulk via recurrence (daily/weekly/weekday/custom, up to 52 occurrences) and deleted in bulk (single, this and following, or all for a template). Batch delete skips sessions with bookings/check-ins and reports skipped IDs to the client.
- **Dependency-aware deletion** — Tour templates can only be deleted when they have no sessions; sessions can only be deleted when they have no bookings or check-ins, and cannot be deleted when in progress or completed. Session deletion must clean up all FK-dependent records: `TourCheckin`, `GuestLocation`, `GuideLocation`, `TourReview`, `TourSessionPhoto`, `TourBooking` (manual cleanup), plus `Message`, `MessagingConsent` (CASCADE), and `MessageAnalytics` (SET NULL)
- **One review per booking** — `tour_booking_id` has a unique constraint on `tour_review`, enforced at the database level
- **Image processing** — All uploaded images are server-side center-cropped and resized via a shared `_save_tour_image()` helper using Pillow. Cover images: 1:1 (400×400). Meeting place photos: 4:3 (800×600). Both converted to JPEG quality 85. The helper handles validation, old file cleanup, and directory creation.
- **Model serialization** — `GuidePick.to_dict()` and `TourSessionPhoto.to_dict()` ensure consistent JSON output across all endpoints. `_build_guide_details()` helper in `tour_sessions.py` constructs guide response dicts (with conditional picks for completed sessions).
- **Coordinate parsing** — `parse_coordinates()` in `app/utils/route_helpers.py` converts PostgreSQL POINT format to `{lat, lng}` dicts, shared across `tour_templates.py` and `tour_sessions.py`.
- **External tip payments** — Tips use an external URL (Venmo, PayPal, etc.) stored as `tip_link` on the guide profile; no in-app payment processing

## Authentication

### Auth Strategy

| User | First time | Returning |
|---|---|---|
| **Guide** | Google OAuth | Google OAuth |
| **Guest** | Name + email + 6-digit verification code | Email + 6-digit verification code |

- **Guides** authenticate exclusively via Google OAuth. No passwords to manage.
- **Guests** sign up with name and email, then verify via a 6-digit code sent to their email (expires in 10 minutes). Returning guests sign in with just their email and a new verification code. Both flows are designed for minimal friction (under 60 seconds for walk-up tourists).

### Guide Auth Flow (Google OAuth)

```mermaid
sequenceDiagram
    participant App as Mobile App
    participant API as Flask Backend
    participant Google as Google OAuth
    participant DB as PostgreSQL

    Note over App, Google: Guide Signup / Sign In
    App->>Google: Initiate OAuth (Google Sign-In)
    Google->>App: Return OAuth ID token
    App->>API: POST /auth/guide/signin {google_id_token}
    API->>Google: Verify ID token
    API->>DB: Find or create Guide by google_user_id
    API->>App: {access_token, refresh_token, user}
```

### Guest Auth Flow

```mermaid
sequenceDiagram
    participant App as Mobile App
    participant API as Flask Backend
    participant DB as PostgreSQL
    participant Email as Email Service

    Note over App, Email: Guest First-Time Signup
    App->>API: POST /auth/guest/signup {name, email}
    API->>API: Generate 6-digit code (expires in 10 min)
    API->>DB: Store code hash + expiry
    API->>Email: Send code to guest's email
    App->>API: POST /auth/guest/signup/verify {email, name, code}
    API->>DB: Verify code + create Guest record
    API->>App: {access_token, refresh_token, user}

    Note over App, Email: Returning Guest Sign In
    App->>API: POST /auth/guest/request-code {email}
    API->>DB: Lookup Guest by email
    API->>API: Generate 6-digit code (expires in 10 min)
    API->>DB: Store code hash + expiry
    API->>Email: Send code to guest's email
    App->>API: POST /auth/guest/verify-code {email, code}
    API->>DB: Verify code hash + check expiry
    API->>App: {access_token, refresh_token, user}
```

### Token Strategy

| Token | Lifetime | Storage | Purpose |
|---|---|---|---|
| Access token | 1 hour | expo-secure-store | API request authentication |
| Refresh token | 30 days | expo-secure-store | Obtain new access tokens |

- Managed by **flask-jwt-extended**
- Access tokens are JWTs containing `{uid, type, exp}`
- Refresh tokens are opaque strings stored in the database
- Axios interceptors automatically refresh expired access tokens

### Token Refresh Flow

```mermaid
sequenceDiagram
    participant App as Mobile App
    participant API as Flask Backend

    App->>API: POST /auth/refresh {refresh_token}
    API->>API: Validate refresh token
    API->>App: {access_token}
```

## Location Tracking

Both guide and guest use the same mechanism: `expo-location` background location updates via `TaskManager`. A shared `backgroundLocation.ts` service handles both user types — the only difference is which API endpoint receives the updates and when tracking starts.

### How It Works

**Guest:**
1. Guest checks into a tour session (check-in does **not** auto-start location sharing)
2. Guest explicitly taps "Start Sharing Location" to opt in
3. App requests foreground + background location permission
4. `startBackgroundLocationUpdates(tourSessionId, 'guest')` begins sending to `POST /location/update`
5. Guest taps "Stop Sharing" or the tour ends → tracking stops

**Guide:**
1. Guide opens session details while the session is active (status: `check_in_open` or `in_progress`)
2. App automatically requests foreground + background location permission
3. `startBackgroundLocationUpdates(tourSessionId, 'guide')` begins sending to `POST /location/guide/update`
4. Tracking stops when the guide leaves the screen or the session completes

### Shared Background Location Service (`backgroundLocation.ts`)

- Single `TaskManager` background task shared by both user types
- `userType` parameter determines the API endpoint (`/location/update` for guests, `/location/guide/update` for guides)
- Uses `fetch` (not Axios) because the task runs outside React
- Reads JWT from `SecureStore` for authentication
- Shows a persistent foreground service notification (required for Android 14+)
- Configurable via constants: `LOCATION_UPDATE_INTERVAL_SECONDS`, `LOCATION_UPDATE_DISTANCE_METERS`

### Map Display

Both guide and guest maps display positions by **polling the backend** — no local position state:

- **Guide map** polls `GET /tour-sessions/{session_id}/locations` which returns all guest locations + the guide's own location
- **Guest map** polls `GET /tour-sessions/{session_id}/sync` which returns the guide's location + the guest's own location

This means all map positions go through the same path: device → background task → backend → polling → map. No special handling for the phone owner's position.

### Location Data Flow

```mermaid
sequenceDiagram
    participant Guest as Guest App
    participant Guide as Guide App
    participant API as Flask API
    participant DB as PostgreSQL

    Note over Guest, Guide: Background location task (both roles)
    loop Every 15 seconds
        Guest->>API: POST /location/update {tour_session_id, lat, lng}
        API->>DB: Insert GuestLocation row
        Guide->>API: POST /location/guide/update {tour_session_id, lat, lng}
        API->>DB: Insert GuideLocation row
    end

    Note over Guide: Guide polls for all positions
    loop Every 15 seconds
        Guide->>API: GET /tour-sessions/{session_id}/locations
        API->>DB: Query latest GuestLocation + GuideLocation
        API->>Guide: {guests: [...], guide_location: {...}}
        Guide->>Guide: Update map markers
    end

    Note over Guest: Guest polls for positions
    loop Every 25 seconds
        Guest->>API: GET /tour-sessions/{session_id}/sync
        API->>DB: Query latest GuideLocation + own GuestLocation
        API->>Guest: {guide_location: {...}, my_location: {...}}
        Guest->>Guest: Update map markers
    end
```

### Privacy & Technical Requirements

- **Guest consent**: Location is only collected when the guest has explicitly tapped "Start Sharing Location"
- **Guide consent**: Location sharing starts automatically when the session is active, but requires location permission grant
- **Android 14+**: Requires `FOREGROUND_SERVICE_LOCATION` permission and `foregroundServiceType="location"` in the Manifest
- **Background access**: User must grant "Allow all the time" for background location
- **No persistent storage**: Location data is not stored after the tour session ends
- **Foreground service notification**: Persistent notification shown while tracking is active ("Sharing your location with your tour guide/guests")

## Push Notifications

### How It Works

1. On app startup, mobile app registers with Expo Push Service and receives an Expo push token
2. Token is sent to backend and stored in the `device_token` table
3. When a guide sends a message or the system triggers a notification, the backend sends a push via Expo Push API
4. Expo Push Service routes to APNs (iOS) or FCM (Android)

### Push Flow

```mermaid
sequenceDiagram
    participant App as Mobile App
    participant API as Flask API
    participant DB as PostgreSQL
    participant Expo as Expo Push Service

    Note over App, Expo: Token Registration
    App->>App: expo-notifications getExpoPushToken()
    App->>API: POST /device-token {expo_push_token}
    API->>DB: Store/update DeviceToken

    Note over App, Expo: Sending a Push
    API->>DB: Lookup guest device tokens
    API->>Expo: POST /--/api/v2/push/send {to, title, body}
    Expo-->>App: Push notification delivered
```

### DeviceToken Table

```
device_token
├── id (PK)
├── user_uid (guide_uid or guest_uid)
├── user_type ('guide' or 'guest')
├── expo_push_token (string, unique)
├── device_info (JSONB — platform, OS version)
├── is_active (boolean)
├── created_at
└── updated_at
```

## API Structure

### Route Groups

| Prefix | Purpose |
|---|---|
| `/api/v1/auth` | Signup, signin, token refresh |
| `/api/v1/tours` | Tour template CRUD, `GET /tours/<id>/sessions` (all sessions for a template), ratings aggregation, template QR generation (`GET /tour-templates/<id>/qr`), public upcoming sessions (`GET /tour-templates/<id>/upcoming-sessions`) |
| `/api/v1/tour-sessions` | Tour session CRUD (single + batch create), `DELETE /tour-sessions/batch` (this_and_following / all), session QR generation, guest locations, message history |
| `/api/v1/guides` | Guide-specific views: `GET /guides/upcoming-sessions` (all upcoming sessions with template data, single JOIN query) |
| `/api/v1/bookings` | Guest bookings (by code or QR scan) |
| `/api/v1/checkins` | Guest check-in, update location sharing preference |
| `/api/v1/location` | Guest + guide location updates, stop sharing |
| `/api/v1/reviews` | Guest review submission, guide review retrieval |
| `/api/v1/messages` | Broadcast and direct messaging |
| `/api/v1/messaging` | Quick message management (guide's reusable message presets) |
| `/api/v1/guide-picks` | Guide's Picks CRUD, reorder, and public retrieval by guide UID |
| `/api/v1/operators` | Operator management |
| `/api/v1/device-token` | Push notification token registration |

### Authentication

All endpoints except signup/signin require a valid JWT in the `Authorization: Bearer <token>` header. The backend validates the token and extracts `uid` and `type` to identify the caller.

## Deployment

### Railway Setup

```
Railway Project: triptoe
├── Service: triptoe-backend (Flask, from Dockerfile)
│   ├── Environment variables: DATABASE_URL, JWT_SECRET, etc.
│   └── Auto-deploys from GitHub main branch
├── PostgreSQL: triptoe-db
│   └── PostGIS extension enabled
└── Volume: /uploads (QR codes, tour session photos, profile photos)
```

### Backend Deployment Flow

```
Developer pushes to GitHub  →  Railway detects change  →  Builds from Dockerfile  →  Deploys new version
```

### Mobile App Distribution

The mobile app is built using Expo EAS (Expo Application Services) and distributed through the app stores. The app is not hosted on Railway — it runs natively on users' phones.

```
Developer pushes to GitHub  →  Expo EAS Build  →  App binary (.ipa / .apk)  →  Apple App Store / Google Play Store  →  User's phone
```

During development, builds can be tested via Expo Go or internal distribution before submitting to the stores.

### Environment Variables

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | PostgreSQL connection string (provided by Railway) |
| `JWT_SECRET` | Secret key for signing JWTs |
| `JWT_REFRESH_SECRET` | Secret key for signing refresh tokens |
| `ALLOWED_ORIGINS` | CORS allowed origins |

