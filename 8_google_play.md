# Google Play Store Listing

Audience: Product Manager, Dev/Ops

## Store Listing Details

### App Name
TripToe

### Short Description (80 chars max)
One app for guides and guests. Live updates, check-ins, messaging, and more

### Full Description
TripToe connects tour guides with their guests during walking and bus tours.

FOR GUESTS:
• Join a tour instantly by scanning a QR code
• Get real-time messages from your guide — meeting point changes, delays, next stops
• Share your location so your guide knows you're safe (opt-in, stops automatically when the tour ends)
• Rate and review your tour experience
• View group photos uploaded by your guide
• Tip your guide via Venmo, PayPal, or Cash App
• Browse your guide's local recommendations — restaurants, bars, sights, and more

FOR TOUR GUIDES:
• Create tours with meeting points, cover photos, and descriptions
• Schedule sessions for specific dates and times
• Track every guest's location on a live map during the tour
• Send messages to all guests or individual guests
• Upload group photos after the tour
• Collect reviews, ratings, and tips
• Share your favorite local spots with Guide's Picks

TripToe is designed for walk-up tourists. Guests can sign up and join a tour in under a minute — no complicated setup, no passwords.

### Category
Travel & Local

### Tags
tour guide, walking tour, group tour, travel, location sharing

## Required Assets

### Screenshots
Stored in `triptoe-docs/screenshots/`. Cropped to 1080x1920 (9:16) with status bar and navigation bar removed. Originals in `screenshots - Copy/`.

Recommended upload order (max 8):
1. `1_landing_page.png` — role selection
2. `2_tour_template.png` — guide tour list
3. `3_tour_sessions.png` — session scheduling
4. `4_session_details.png` — live session with map and guests
5. `4_session_map.png` — full-screen guest location map
6. `5_message_modal.png` — message all guests
7. `7_guest_tour_details.png` — guest meeting point details
8. `8_post_tour.png` — Guide's Picks post-tour

### Feature Graphic
`triptoe-docs/play-store-feature.png` — 1024x500, white background, horizontal TripToe logo with tagline.

### App Icon
`triptoe-docs/play-store-icon.png` — 512x512, resized from `triptoe-mobile/assets/icon.png`.

## Privacy & Account Deletion

Hosted on Cloudflare Workers (`restless-flower-1f1a`) with custom domain `triptoe.app`.

| Page | URL | Source |
|------|-----|--------|
| Privacy Policy | `https://triptoe.app/privacy` | `triptoe-docs/site/privacy.html` |
| Account Deletion | `https://triptoe.app/delete-account` | `triptoe-docs/site/delete-account.html` |

Deployment: `cd triptoe-docs/site && npx wrangler deploy`

### Account Deletion Flow
The deletion form at `/delete-account` POSTs to the backend endpoint `POST /api/v1/auth/request-account-deletion`. The backend sends an email to `support@triptoe.app` via Resend with the user's email, account type, and reason. No `mailto:` — the request is submitted directly.

### Data collected by TripToe:
| Data | Purpose | Retention |
|---|---|---|
| Email address | Account creation, verification codes | Until account deletion |
| Name | Display to guide/guests during tours | Until account deletion |
| Location (foreground + background) | Share guest location with guide during active tours | Not stored after tour ends |
| Device push token | Push notifications (messages, tour reminders) | Until logout or token refresh |
| Tour activity (bookings, check-ins, reviews) | Core app functionality | Until account deletion |

### Third-party services:
| Service | Purpose |
|---|---|
| Resend | Sending verification emails |
| Expo Push Service | Delivering push notifications |
| Firebase Cloud Messaging (FCM) | Android push notification delivery |
| Google OAuth | Guide authentication |
| Google Maps | Map display and navigation |

## Content Rating Questionnaire

Google Play requires a content rating. TripToe should qualify for **Everyone** (IARC).

Answers to expect:
- Violence: No
- Sexual content: No
- Language: No (user-generated messages exist but no profanity filter — may need "mild" rating)
- Controlled substances: No
- User interaction: Yes (messaging between guide and guests)
- Shares location: Yes
- Collects personal data: Yes (email, name, location)

## App Access (Test Account)

Google Play reviewers need credentials to test the app. A test bypass is hardcoded in the backend:

- **Email:** `support@triptoe.app`
- **Code:** `654321`
- **Instructions:** Tap "I'm a Guest", enter any name and email `support@triptoe.app`. On the verification code screen, enter `654321`.

This bypass is in `auth.py` — it skips sending a real verification email and accepts the fixed code for this email only. The bypass applies to all 4 guest auth endpoints: `guest_signup`, `guest_signup_verify`, `guest_request_code`, `guest_verify_code`.

## Pre-Submission Checklist

- [x] Google Play Developer account at [play.google.com/console](https://play.google.com/console)
- [x] Identity verification completed
- [x] App created in console
- [x] Privacy policy hosted at `https://triptoe.app/privacy`
- [x] Account deletion page at `https://triptoe.app/delete-account`
- [x] Screenshots cropped and ready
- [x] Feature graphic created
- [x] App icon (512x512) created
- [ ] Store listing completed (descriptions, screenshots, graphics uploaded)
- [ ] Content rating questionnaire completed
- [ ] Target audience declared
- [ ] Data safety form completed
- [ ] App category and contact details set
- [ ] App signing configured
- [ ] Release uploaded (internal testing track)
- [ ] Production rollout

## Build & Submit

```bash
cd triptoe-mobile

# Build AAB for Google Play
build.bat aab
# Output: android\app\build\outputs\bundle\release\app-release.aab

# Build APK for sideload testing
build.bat apk       # full build
build.bat apk fast  # skip prebuild (code-only changes)
```

Upload the AAB to Google Play Console → Test and release → Internal testing (or Production).
