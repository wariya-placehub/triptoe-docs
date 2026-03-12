# Launch Readiness

Checklist of remaining work before production launch.

## Infrastructure
- [ ] Register a domain (e.g. triptoe.app, triptoe.io)
- [ ] Set up email service (Resend) for verification codes — requires domain
- [ ] Deploy backend to Railway
- [ ] Set up PostgreSQL on Railway
- [ ] Configure environment variables on Railway

## Backend
- [ ] Replace console-logged verification codes with real email delivery
- [ ] Set up production WSGI server (gunicorn)
- [ ] Use a longer/stronger JWT secret key (current one triggers InsecureKeyLengthWarning)
- [ ] Move database sequences to correct schemas (some still in public)
- [ ] Add profile image upload to Railway volume

## Mobile
- [ ] Test push notifications on a physical device
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
- [ ] Guide: send messages to booked guests
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
