# 7. Naming Conventions

Naming rules for the TripToe codebase. These apply to both the mobile app and the backend unless stated otherwise.

---

## Tour Entity Terminology

TripToe has three distinct tour-related entities. Code must always be specific about which one it refers to.

| Entity | Description | Example DB Table | Example Variable |
|---|---|---|---|
| **Tour Template** | A reusable tour definition (title, duration, meeting place, timezone) | `tour_template` | `tourTemplate` |
| **Tour Session** | A specific scheduled occurrence of a tour template (date, time) | `tour_session` | `tourSession` |
| **Tour Booking** | A guest's reservation for a specific tour session | `booking` | `tourBooking` |

Never use bare "tour" in code when you mean one of these. The word "tour" alone is reserved for customer-facing UI text where the distinction doesn't matter to the user.

---

## File Naming (Mobile)

### Screen files (`app/`)

Files use **kebab-case** with the full entity name:

```
app/(guide)/
  dashboard.tsx              # GuideDashboard
  schedule.tsx               # GuideSchedule (day planner with DateStrip + SectionList)
  create-tour-template.tsx   # CreateTourTemplate
  edit-tour-template.tsx     # EditTourTemplate
  tour-sessions.tsx          # TourSessions (list)
  create-tour-session.tsx    # CreateTourSession
  tour-session-details.tsx   # TourSessionDetails

app/(guest)/
  dashboard.tsx              # GuestDashboard
  join-tour-session.tsx      # JoinTourSession
  tour-booking-details.tsx   # TourBookingDetails
```

Rules:
- The component name must match the file name in PascalCase.
- If a file is tour-related, the word "tour" must appear in the file name.
- Expo Router uses the file name as the route segment. Customer-facing tab titles are set separately in `_layout.tsx` and can use friendlier names (e.g. "Join Tour" tab label for `join-tour-session.tsx`).

### Source files (`src/`)

```
src/services/tours.ts        # All tour template, session, and booking API calls
src/services/location.ts     # Location tracking API calls
src/utils/tourUtils.ts       # TourSessionStatus type, getTourSessionStatus(), getCheckinEligibility()
src/utils/formatDate.ts      # Date/time formatting helpers
src/utils/navigationParams.ts # DRY builders for navigation params, coordinate serialization
src/utils/imagePicker.ts     # Shared image picker (camera + library) utilities
src/hooks/usePollingInterval.ts
src/hooks/useTourSessionTabs.ts
src/hooks/useQRModal.ts          # QR modal state management
src/hooks/useGuideTourSessions.ts  # Fetch tour sessions across all templates (single API call)
src/components/tour/TourSessionHeader.tsx  # Shared header (guide + guest)
src/components/tour/TourSessionStatusBadge.tsx  # Tour session status pill (wraps StatusBadge)
src/components/guide/GuideTourSessionCard.tsx  # Session card (Tour Sessions + Schedule)
src/components/guide/GuideTourTemplateCard.tsx  # Template card (My Tours)
src/components/guest/GuestTourBookingCard.tsx   # Booking card (guest My Tours)
src/components/tour/QRModal.tsx      # QR code modal
src/components/tour/DateStrip.tsx    # Horizontal date pills for schedule
src/config/location.ts       # Polling intervals, distance thresholds
src/config/tour.ts           # CHECKIN_WINDOW_MINUTES
```

---

## Function Naming

### Service functions (`src/services/`)

Pattern: `verbEntityName(entityId, ...)`

```typescript
// Tour templates
getTourTemplates()
getTourTemplate(tourTemplateId)
createTourTemplate(tourData)
updateTourTemplate(tourTemplateId, tourData)
deleteTourTemplate(tourTemplateId)

// Tour sessions
getTourSessions(tourTemplateId)
getTourSession(tourSessionId)
createTourSession(sessionData)
updateTourSession(tourSessionId, sessionData)
deleteTourSession(tourSessionId)
getTourSessionGuests(tourSessionId)
getTourQRCode(tourSessionId)

// Bookings
bookTourByQR(qrData)
bookTourByCode(tourSessionId)
cancelBooking(bookingId)
getMyBookings()

// Guide aggregate
getGuideUpcomingTourSessions()   // All upcoming sessions with template data

// Check-ins
checkIn(tourSessionId, locationSharingEnabled)

// Location
updateLocation(tourSessionId, latitude, longitude, accuracy)
getTourLocations(tourSessionId)
updateGuideLocation(tourSessionId, latitude, longitude, accuracy)
getGuideLocation(tourSessionId)
```

Rules:
- Parameters that are IDs must include the entity name: `tourTemplateId`, `tourSessionId`, `bookingId`. Never use bare `id`, `sessionId`, or `tourId`.
- Data parameters use typed interfaces: `TourTemplateRequest`, `TourSessionCreateRequest`, `TourSessionUpdateRequest`.
- Response variables use descriptive names: `toursResponse`, `sessionResponse`, `bookingsResponse`, `guideLocationResponse`. Never use bare `data` or `result`.

---

## Variable Naming

### State variables

State names should reflect the entity they hold:

```typescript
// Guide dashboard
const [tourTemplates, setTourTemplates] = useState(...)

// Tour sessions list
const [tourTemplate, setTourTemplate] = useState(...)
const [tourSessions, setTourSessions] = useState(...)

// Guest dashboard
const [bookings, setBookings] = useState(...)

// Guest booking details
const [tourBooking, setTourBooking] = useState(...)
```

### Timezone

Always use `timezone` (never `tz`, `sessionTz`, or `tourTz`):

```typescript
const timezone = tourTemplate?.timezone || 'UTC';
const tourTimezone = session.tour?.timezone || 'UTC';
```

Use `tourTimezone` when you need to distinguish from other timezone variables in scope.

### FlatList render parameters

Use entity-specific names via destructuring, never bare `item`:

```typescript
// Guide dashboard
renderItem={({ item: template }) => ...}

// Tour sessions list
renderItem={({ item: session }) => ...}

// Session details guest list
renderItem={({ item: guest }) => ...}

// Guest dashboard
renderItem={({ item: booking }) => ...}
```

### Callback functions

Screen-level data loaders should describe what they load:

```typescript
loadTourTemplates()         // not loadData
loadTemplateAndSessions()   // not loadData
loadBookingDetails()        // not loadTour
refreshBookingStatus()      // not refreshTourStatus
loadGuests()
fetchLocations()
fetchGuideLocation()
```

---

## Customer-Facing Text vs Code

Customer-facing UI text (button labels, tab titles, alerts, headings) can use simplified language:

| Code Name | UI Label |
|---|---|
| `create-tour-template.tsx` | "Create Tour" |
| `join-tour-session.tsx` | "Join Tour" |
| `tour-booking-details.tsx` | "Tour Details" |
| `tour-session-details.tsx` | "Session Details" |

The tab title in `_layout.tsx` controls what the customer sees. The file name controls what developers see. These are intentionally different.

---

## Backend Conventions

### API endpoints

```
/tours                           # Tour templates (list, create)
/tours/<tour_template_id>        # Tour template (get, update, delete)
/tours/<tour_template_id>/sessions  # Sessions for a template
/tour-sessions/<tour_session_id>    # Tour session (get, update, delete)
/tour-sessions/<tour_session_id>/guests
/tour-sessions/<tour_session_id>/qr
/tour-sessions/<tour_session_id>/locations
/guides/upcoming-sessions        # All upcoming sessions (JOIN query)
/bookings/qr-scan
/bookings/<tour_booking_id>
/checkins
/location/update
/location/guide/update
/location/guide/<tour_session_id>
```

### Database tables

Tables use **snake_case** singular: `tour_template`, `tour_session`, `tour_booking`, `tour_checkin`.

Primary key columns include the table name: `tour_template_id`, `tour_session_id`, `tour_booking_id`, `tour_checkin_id`.
