# Launch Readiness

Checklist of remaining work before production launch.

## Infrastructure
- [x] Register domain: `triptoe.app` (Cloudflare)
- [x] Set up email service (Resend) for verification codes — domain `triptoe.app` verified, sending from `noreply@triptoe.app`
- [ ] Deploy backend to Railway
- [ ] Set up PostgreSQL on Railway
- [ ] Configure environment variables on Railway

## Backend
- [x] Replace console-logged verification codes with real email delivery (Resend)
- [ ] Set up production WSGI server (gunicorn)
- [ ] Use a longer/stronger JWT secret key (current one triggers InsecureKeyLengthWarning)
- [ ] Move database sequences to correct schemas (some still in public)
- [ ] Add profile image upload to Railway volume

## Mobile
- [x] Push notifications working on physical devices — Firebase project `triptoe-app` created, FCM credentials uploaded to Expo, `google-services.json` in mobile project, token registration on login
- [x] Pull-to-refresh on all data screens (guide + guest)
- [ ] Test Google Sign-In on a physical device
- [ ] Set up EAS Build for production builds
- [ ] App store listing (Google Play, Apple App Store)
- [x] Implement background location tracking (expo-location background mode)

## Features
- [x] Guide: edit tour template details (edit-tour screen)
- [x] Guide: edit tour session (edit button on session-details screen)
- [x] Guide/Guest: session grouping tabs (This Week / Upcoming / Past)
- [x] Guide: dashboard sorted by nearest upcoming session
- [x] Guest: location sharing is opt-in (not auto-started on check-in)
- [x] Guest: location sharing state persists across app reloads
- [x] Guest: completed tours hide location sharing and check-in buttons
- [x] Real-time Updates: Silent polling implemented for dashboards and details
- [ ] Guide: edit profile (name, languages, specialties)
- [ ] Guest: edit profile (name, notification preferences)
- [ ] Guest: receive push notification when tour session is about to start
- [x] Guest: messaging banner visible before check-in (guides can send updates like location changes or delays to all booked guests)
- [x] Guest: returning guest goes to sign-in instead of sign-up on landing page
- [x] Guide: send messages to booked guests
- [x] Guide: quick messages (reusable message presets, create/edit/delete)
- [x] Guide: multi-photo upload for completed sessions (select multiple from gallery)
- [x] Guest: push notification tap opens tour booking details
- [x] Guide: view guest ratings and reviews for completed sessions
- [x] Guide: tip link on profile (external payment URL)
- [x] Guide: Guide's Picks — curate local recommendations (eat, drink, see, shop, do) for guests
- [x] Guide/Guest: post-tour tabbed layout (Review & Tip, Guide's Picks, Photos, Messages)
- [x] Post-tour push notification nudging guests to view guide's picks (APScheduler, 30 min after tour)
- [x] Guest: submit star rating and optional review after tour ends
- [x] Guest: view group photos uploaded by guide
- [x] Guest: tip guide via external payment link
- [x] Guest: view guide location during tour (if guide shares)
- [ ] Offline support / graceful error handling for poor connectivity

## Technical Debt
- [x] Standardize naming convention (Tour Templates vs. Tour Sessions) across code and services.
- [ ] AndroidManifest.xml was manually edited to add `foregroundServiceType="location"` for background location tracking. This means `app.json` no longer fully describes the app's native needs. Investigate using a Config Plugin for expo-location to inject this automatically during `npx expo prebuild`.

## Known Issues
- [ ] Emulator needs `r` (reload) after .env changes to pick up new values
- [ ] JAVA_HOME must be set manually in new terminals (update system environment variable permanently)
- [ ] Add ANDROID_HOME and SDK paths to system PATH permanently
- [ ] Google Maps API key must be set in `app.json` (under `expo.android.config.googleMaps.apiKey`); changing it requires `npx expo prebuild --clean` + rebuild
- [ ] Android API 36 (Android 16) deep link launch via `adb am start` fails due to intent resolution restrictions — app must be opened manually on emulator
