# Google Play Store Listing

Audience: Product Manager, Dev/Ops

## Store Listing Details

### App Name
TripToe

### Short Description (80 chars max)
Connect with your tour guide. Live location, messages, and group photos.

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

### Screenshots (minimum 2, recommended 4-8)
- [ ] Guest: tour booking details screen (shows tour info, meeting point, guide)
- [ ] Guest: live location sharing during tour
- [ ] Guest: post-tour screen (review, photos, guide's picks)
- [ ] Guide: dashboard with tour list
- [ ] Guide: session details with live map and guest locations
- [ ] Guide: compose message to guests

**Specs:** JPEG or PNG, 16:9 or 9:16, min 320px, max 3840px on any side.

### Feature Graphic
- [ ] 1024x500 banner image (displayed at top of store listing)

### App Icon
- [ ] 512x512 PNG (already configured in `app.json` — EAS uploads this automatically)

## Privacy Policy

**Required by Google Play.** Must be a publicly accessible URL.

- [ ] Host at `https://triptoe.app/privacy` (or any public URL)
- [ ] Must cover: what data is collected, how it's used, third-party services, data retention, contact info

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

## Pre-Submission Checklist

- [ ] Google Play Developer account ($25 one-time) at [play.google.com/console](https://play.google.com/console)
- [ ] Production Google OAuth Android client (SHA-1 from `eas credentials --platform android`)
- [ ] Privacy policy hosted and accessible
- [ ] Screenshots captured
- [ ] Feature graphic created
- [ ] Production build: `eas build --platform android --profile production --clear-cache`
- [ ] Submit: `eas submit --platform android`

## Build & Submit Commands

```bash
# Production build (AAB for Google Play)
eas build --platform android --profile production --clear-cache

# Submit to Google Play
eas submit --platform android

# Check build status
eas build:list --limit 1
```

The production profile builds an AAB (Android App Bundle) which can only be uploaded to Google Play — it cannot be sideloaded like the preview APK.
