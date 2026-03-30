# Deployment Guide

Audience: Dev/Ops

## Overview

TripToe runs on two deployment targets:

- **Backend** — Flask API deployed to Railway (Docker container)
- **Mobile app** — Expo React Native app distributed via Apple App Store and Google Play Store

Railway is the single infrastructure provider for all server-side resources.

## Railway Setup

### 1. Create a Railway Account

1. Sign up at [railway.app](https://railway.app/) with your GitHub account
2. Activate the Hobby plan ($5/month — required for persistent deployments and custom domains)

### 2. Install Railway CLI

```bash
npm install -g @railway/cli
railway login
```

### 3. Create a Railway Project

```bash
railway init
# Select workspace, name project "triptoe"
```

### 4. Provision PostgreSQL

```bash
railway add -d postgres
```

Enable PostGIS — connect to the database and run:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

### 5. Create and Link the Backend Service

```bash
cd triptoe-backend
railway add -s triptoe-backend
railway link
# Select triptoe project > production > triptoe-backend
```

### 6. Connect Database to Backend

In the Railway dashboard, open `triptoe-backend` > **Variables** > **New Variable**:
- Name: `DATABASE_URL`
- Value: `${{Postgres.DATABASE_URL}}`

This references the Postgres service's connection string.

### 7. Set Environment Variables

In `triptoe-backend` > **Variables**, add:

| Variable | Value |
|---|---|
| `FLASK_ENV` | `production` |
| `SECRET_KEY` | Generate a random string (e.g. `python -c "import secrets; print(secrets.token_hex(32))"`) |
| `JWT_SECRET_KEY` | Generate a separate random string |
| `GOOGLE_CLIENT_ID` | Your Google OAuth Web client ID |
| `GOOGLE_CLIENT_SECRET` | Your Google OAuth Web client secret |
| `RESEND_API_KEY` | Your Resend API key (from [resend.com](https://resend.com) dashboard) |
| `CORS_ORIGINS` | `*` (or restrict to your domain) |
| `UPLOAD_FOLDER` | `/uploads` |

### 8. Attach a Volume

```bash
railway volume add -m /uploads
```

This persists uploaded files (profile photos, tour cover images, meeting place photos, session photos) across deploys.

### 9. Generate a Public URL

In the Railway dashboard, open `triptoe-backend` > **Settings** > **Networking** > **Generate Domain**.

Port: `8080` (matches the Dockerfile `EXPOSE` directive).

This gives you a URL like `https://triptoe-backend-production.up.railway.app`.

### 10. Deploy the Backend

```bash
cd triptoe-backend
railway up
```

### 11. Verify Deployment

```bash
curl https://triptoe-backend-production.up.railway.app/health
```

You should see `{"status": "healthy"}`.

## Railway Project Structure

```
Railway Project: triptoe
├── Service: triptoe-backend
│   ├── Source: CLI deploy (railway up) or GitHub (triptoe-backend repo)
│   ├── Build: Dockerfile
│   ├── Environment variables: SECRET_KEY, JWT_SECRET_KEY, GOOGLE_CLIENT_ID, ...
│   ├── Volume: /uploads (profile photos, tour covers, meeting place photos, session photos)
│   └── Domain: triptoe-backend-production.up.railway.app
├── PostgreSQL
│   ├── PostGIS extension enabled
│   └── DATABASE_URL referenced by backend via ${{Postgres.DATABASE_URL}}
└── Volume: triptoe-backend-volume mounted at /uploads
```

## Database Access

Connect to the production database via CLI (from `triptoe-backend/`):

```bash
railway connect Postgres
```

This opens a psql shell connected to the production database.

## Database Migrations

The initial schema is created automatically by the backend on first startup via `db.create_all()`.

For subsequent schema changes, migration scripts are stored in `triptoe-backend/migrations/` as numbered SQL files. Apply them via the Railway psql connection:

```bash
railway connect Postgres
# Then in the psql shell:
\i migrations/001_some_change.sql
\i migrations/002_another_change.sql
```

Or using the connection string directly:

```bash
# Get the connection string from Railway dashboard > PostgreSQL > Connect
psql "postgresql://user:pass@host:port/railway" -f migrations/001_some_change.sql
```

Always apply migrations in numbered order. Test on a local database first before running against production.

## Mobile App Distribution

The mobile app is not hosted on Railway. It is built using Expo EAS (Expo Application Services) and distributed through the app stores.

### EAS Setup

1. Install EAS CLI:

```bash
npm install -g eas-cli
eas login
```

2. Configure the project (from `triptoe-mobile/`):

```bash
eas build:configure
```

This creates an `eas.json` with build profiles.

### Release Keystore

The release keystore signs both APK and AAB builds. It lives at `triptoe-mobile/triptoe-release.keystore` (gitignored).

**How it was created:**

```bash
keytool -genkey -v \
  -keystore triptoe-release.keystore \
  -alias triptoe-alias \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass <password> \
  -keypass <password> \
  -dname "CN=TripToe, O=TripToe, L=Austin, ST=Texas, C=US"
```

Password is stored in `keystore.properties` (gitignored). Never hardcode it in docs or code.

**Get SHA-1 fingerprint:**

```bash
keytool -list -v -keystore triptoe-release.keystore -alias triptoe-alias -storepass <password>
```

**Export PEM certificate (for Google Play upload key reset):**

```bash
keytool -export -rfc -keystore triptoe-release.keystore -alias triptoe-alias -storepass <password> -file triptoe_playstore.pem
```

Passwords are stored in `triptoe-mobile/keystore.properties` (gitignored). The build script (`build.bat`) injects the signing config via `scripts/patch-signing.ps1` after `expo prebuild`.

**IMPORTANT:** Back up this keystore. If lost, you cannot update the app on Google Play — you'd have to create a new app listing.

### Google OAuth Credentials

Google Cloud Console project: `triptoe-489605`

Two OAuth credentials in **APIs & Services** → **Credentials**:

| Name | Type | Purpose |
|------|------|---------|
| **TripToe OAuth** | Web application | Client ID used in code (`EXPO_PUBLIC_GOOGLE_CLIENT_ID`). Used by both mobile app and backend. |
| **TripToe Mobile** | Android | Registers the release keystore SHA-1 + package name (`com.triptoe.mobile`) so Google allows sign-in from this app. |

When the keystore changes, update the SHA-1 in **TripToe Mobile** at Google Cloud Console.

### Building for App Stores

```bash
# iOS (requires Apple Developer account - $99/year)
eas build --platform ios --profile production

# Android (requires Google Play Developer account - $25 one-time)
eas build --platform android --profile production
```

### Submitting to Stores

```bash
# iOS — submits to App Store Connect
eas submit --platform ios

# Android — submits to Google Play Console
eas submit --platform android
```

### Internal Testing (Preview Builds)

For testing on real devices before store submission:

```bash
# Build APK for direct install on Android devices
eas build --platform android --profile preview

# iOS (requires Apple Developer account)
eas build --platform ios --profile preview
```

**Cancelling a build:**

`Ctrl+C` in the terminal only disconnects your terminal — the build keeps running on Expo's servers. To actually cancel:

```bash
eas build:list --limit 2          # find the build ID
eas build:cancel <build-id>       # cancel it
```

The free tier only allows one concurrent build. A queued build won't start until the previous one finishes or is cancelled.

**When to use `--clear-cache`:**

| Change | `--clear-cache` needed? |
|---|---|
| JS/TS code (components, screens, hooks, styles) | No |
| Added/removed a package with native code (e.g., `expo-image`) | Yes |
| Changed `app.json` (permissions, plugins, icons) | Yes |
| Changed files in `android/` or `ios/` directory | Yes |
| Changed `eas.json` build profiles | Yes |

```bash
# Example: after adding a new native package
eas build --platform android --profile preview --clear-cache
```

The `preview` profile (defined in `eas.json`) builds an APK with `"distribution": "internal"` — this means the APK can be installed directly on any Android device (sideloading). The `production` profile builds an AAB which can only be uploaded to Google Play Store.

After the build finishes (10-20 minutes on the free plan), get the APK download link:

```bash
eas build:list --limit 1
```

Copy the **Application Archive URL** (the `.apk` link). Open it on your Android phone's browser to download and install. No need to uninstall first — it overwrites the existing app.

### Over-the-Air Updates

For JS-only changes (no native code changes), push updates without a new store submission:

```bash
eas update --branch production --message "Fix booking display"
```

## Deployment Flow

### When to Rebuild What

| Change | Backend (`railway up`) | Mobile (`build.bat`) |
|---|---|---|
| Backend code (Python, Dockerfile) | Yes | No |
| Backend environment variables | No (set in Railway dashboard) | No |
| Mobile JS/TS code only | No | `build.bat apk fast` (or `eas update` OTA) |
| Mobile native code (new packages, app.json, android/) | No | `build.bat apk` (full build) or `eas build --clear-cache` |
| Mobile `.env` / `.env.production` | No | Yes (full build required) |

### Backend

```bash
cd triptoe-backend
railway up
# Builds Docker image and deploys (2-3 minutes)
# Verify: curl https://triptoe-backend-production.up.railway.app/health

# View logs:
railway logs

# Follow logs in real-time:
railway logs --follow
```

### Mobile App

**Local build (recommended — no EAS build limits):**

```bash
cd triptoe-mobile

# Build APK for testing (full build with prebuild + signing):
build.bat apk

# Build APK fast (skip prebuild, reuse cached android/ folder):
build.bat apk fast

# Build AAB for Google Play (always full build):
build.bat aab
```

- `build.bat apk` — builds a signed APK, uploads to GCS, shows QR code to scan and install
- `build.bat apk fast` — skips `expo prebuild`, reuses cached `android/` folder for faster builds when only JS/TS code changed (no `app.json`, plugin, or permission changes)
- `build.bat aab` — builds a signed AAB for upload to Google Play Console

The APK is uploaded to `gs://triptoe-apk/triptoe.apk` and downloadable at `https://storage.googleapis.com/triptoe-apk/triptoe.apk`.

Requires `gcloud` configured with a `triptoe` configuration (`wariyak@gmail.com`, project `triptoe-489605`). The script switches to the triptoe config for upload and switches back to default after.

**Signing:** All builds use the release keystore (`triptoe-release.keystore` in project root). Passwords are stored in `keystore.properties` (gitignored). The build script runs `scripts/patch-signing.ps1` after prebuild to inject the release signing config into the generated `build.gradle`.

**EAS build (cloud — 30 free builds/month):**

```
cd triptoe-mobile

# Full rebuild (native code changes, new packages):
eas build --platform android --profile preview --clear-cache

# JS-only hotfix (no native changes):
eas update --branch production --message "description of change"
```

### App Store Submission

```
# Production build (AAB for Google Play):
eas build --platform android --profile production

# Submit to Google Play:
eas submit --platform android
```

## Environment Variables Reference

### Backend (Railway)

| Variable | Required | Description |
|---|---|---|
| `FLASK_ENV` | Yes | `production` |
| `SECRET_KEY` | Yes | Flask secret key for session signing |
| `DATABASE_URL` | Auto | PostgreSQL connection string (injected by Railway) |
| `JWT_SECRET_KEY` | Yes | Secret for signing JWT access/refresh tokens |
| `GOOGLE_CLIENT_ID` | Yes | Google OAuth Web client ID |
| `GOOGLE_CLIENT_SECRET` | Yes | Google OAuth Web client secret |
| `RESEND_API_KEY` | Yes | API key from [resend.com](https://resend.com) for sending verification emails |
| `RESEND_FROM_EMAIL` | No | Sender address (default: `TripToe <noreply@triptoe.app>`) |
| `CORS_ORIGINS` | No | Comma-separated allowed origins (default: `*`) |
| `UPLOAD_FOLDER` | No | Path for file storage (default: `/uploads`) |
| `ACTIVE_LOCATION_THRESHOLD_MINUTES` | No | How recent a location must be to count as active (default: `2`) |
| `STRAGGLER_THRESHOLD_METERS` | No | Distance from guide before guest is flagged as straggler (default: `50`) |
| `DUPLICATE_CHECKIN_PREVENTION_MINUTES` | No | Window to prevent duplicate check-ins (default: `5`) |
| `CHECKIN_WINDOW_MINUTES` | No | How early before start time guests can check in (default: `30`) |
| `PAST_SESSIONS_LOOKBACK_DAYS` | No | How many days of past sessions to show (default: `7`) |
| `MESSAGING_PRE_TOUR_HOURS` | No | Hours before tour start that messaging opens (default: `48`) |
| `MESSAGING_POST_TOUR_HOURS` | No | Hours after tour end that messaging closes (default: `24`) |
| `POST_TOUR_NOTIFICATION_DELAY_MINUTES` | No | Delay after tour ends before sending post-tour notification (default: `30`) |

### Mobile App (build-time)

| Variable | Description |
|---|---|
| `EXPO_PUBLIC_API_URL` | Backend URL (e.g. `https://triptoe-backend-production.up.railway.app/api/v1`) |
| `EXPO_PUBLIC_GOOGLE_CLIENT_ID` | Google OAuth Web client ID (same as backend) |

These are baked into the app at build time via Expo's `EXPO_PUBLIC_` prefix convention.

### Firebase / FCM (push notifications)

Android push notifications require Firebase Cloud Messaging (FCM), even when using Expo Push Service. This is a one-time setup with no ongoing cost.

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com/) (project: `triptoe-app`)
2. Add an Android app with package name `com.triptoe.mobile`
3. Download `google-services.json` and place it in `triptoe-mobile/` (project root)
4. In `app.json`, under `expo.android`, add: `"googleServicesFile": "./google-services.json"`
5. In Firebase Console → Project settings → Service accounts → Generate new private key
6. Upload the key at [expo.dev](https://expo.dev) → project → Credentials → Android → FCM V1 service account key

Rebuild with `--clear-cache` after adding `google-services.json` (native dependency change).

## Monitoring

### Railway Dashboard

- **Metrics** — CPU, memory, and network usage for the backend service
- **Logs** — Real-time log streaming from the Flask app
- **Database** — Connection count, storage usage, query stats

### Health Check

The backend exposes `GET /health` which returns:

```json
{
  "status": "healthy",
  "timestamp": "2026-03-07T12:00:00+00:00",
  "service": "triptoe-backend"
}
```

Use this endpoint for uptime monitoring (e.g. UptimeRobot, Better Uptime).

## Static Site (Cloudflare Workers & Pages)

The privacy policy and account deletion pages are hosted as static HTML on Cloudflare Workers.

**Source files:** `triptoe-docs/site/`
- `index.html` → `https://triptoe.app` (landing page)
- `privacy.html` → `https://triptoe.app/privacy`
- `delete-account.html` → `https://triptoe.app/delete-account`

**Assets:** `triptoe-long.png` (logo), `screenshot-map.png` (hero image), `favicon.png`

**Worker name:** `restless-flower-1f1a` (on `wariyak.workers.dev`)
**Custom domain:** `triptoe.app`

### Updating the site

1. Edit files in `triptoe-docs/site/`
2. Deploy via CLI:

```bash
cd triptoe-docs/site
npx wrangler deploy
```

Requires Cloudflare login (`npx wrangler login`). Config is in `triptoe-docs/site/wrangler.toml`.

## Email Routing

`support@triptoe.app` forwards to `wariyak@gmail.com` via Cloudflare Email Routing. Configure at Cloudflare → `triptoe.app` → Email → Email Routing.

## Cost Estimate

| Resource | Cost |
|---|---|
| Railway Hobby plan | $5/month (includes $5 usage credit) |
| Railway compute (low traffic) | ~$0-3/month above credit |
| Railway PostgreSQL (low traffic) | ~$0-2/month above credit |
| Apple Developer Program | $99/year |
| Google Play Developer | $25 one-time |
| Expo EAS Build (free tier) | 30 builds/month |
| Resend (email) | Free tier: 100 emails/day |
| Expo Push Service | Free |

For a low-traffic app, total monthly cost is approximately **$5-10/month** plus annual Apple developer fee.
