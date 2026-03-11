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

### 2. Create a Railway Project

1. In the Railway dashboard, click **New Project**
2. Name it `triptoe`

### 3. Provision PostgreSQL

1. Inside the project, click **New** > **Database** > **PostgreSQL**
2. Railway creates the database and injects `DATABASE_URL` into the project environment automatically
3. Enable PostGIS — open a psql connection from the Railway dashboard (or use the connection string locally) and run:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

### 4. Deploy the Backend

1. Click **New** > **GitHub Repo** and select the `triptoe-backend` repository
2. Railway detects the `Dockerfile` and builds automatically
3. Set the following environment variables in the service settings:

| Variable | Value |
|---|---|
| `FLASK_ENV` | `production` |
| `SECRET_KEY` | Generate a random string (e.g. `python -c "import secrets; print(secrets.token_hex(32))"`) |
| `JWT_SECRET_KEY` | Generate a separate random string |
| `GOOGLE_CLIENT_ID` | Your Google OAuth Web client ID |
| `GOOGLE_CLIENT_SECRET` | Your Google OAuth Web client secret |
| `CORS_ORIGINS` | `*` (or restrict to your domain) |
| `DATABASE_URL` | Already injected by Railway — do not override |

4. Railway auto-deploys on every push to the `main` branch

### 5. Attach a Volume

1. In the backend service settings, click **New** > **Volume**
2. Mount path: `/uploads`
3. This stores generated QR codes and profile photos

### 6. Generate a Public URL

1. In the backend service, go to **Settings** > **Networking**
2. Click **Generate Domain** to get a `*.up.railway.app` URL
3. Optionally, add a custom domain (e.g. `api.triptoe.com`)

### 7. Verify Deployment

```bash
curl https://your-app.up.railway.app/health
```

You should see `{"status": "healthy"}`.

## Railway Project Structure

```
Railway Project: triptoe
├── Service: triptoe-backend
│   ├── Source: GitHub (triptoe-backend repo, main branch)
│   ├── Build: Dockerfile
│   ├── Environment variables: SECRET_KEY, JWT_SECRET_KEY, GOOGLE_CLIENT_ID, ...
│   ├── Volume: /uploads
│   └── Domain: *.up.railway.app (or custom)
├── PostgreSQL
│   ├── PostGIS extension enabled
│   └── DATABASE_URL injected automatically
└── Volume: /uploads (QR codes, profile photos)
```

## Database Migrations

The initial schema is created automatically by the backend on first startup via `db.create_all()`.

For subsequent schema changes, migration scripts are stored in `triptoe-backend/migrations/` as numbered SQL files. Apply them using the Railway database connection string:

```bash
# Get the connection string from Railway dashboard > PostgreSQL > Connect
psql "postgresql://user:pass@host:port/railway" -f migrations/001_some_change.sql
psql "postgresql://user:pass@host:port/railway" -f migrations/002_another_change.sql
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

### Internal Testing

For testing before store submission:

```bash
# Build for internal distribution
eas build --platform ios --profile preview
eas build --platform android --profile preview
```

EAS provides a download link for the build that testers can install directly on their devices.

### Over-the-Air Updates

For JS-only changes (no native code changes), push updates without a new store submission:

```bash
eas update --branch production --message "Fix booking display"
```

## Deployment Flow

### Backend

```
Push to main branch
  → Railway detects change
  → Builds Docker image from Dockerfile
  → Deploys new container (zero-downtime)
  → Health check: GET /health
```

### Mobile App

```
Push to main branch
  → Run: eas build --platform all --profile production
  → Submit to App Store / Google Play
  → App Store review (1-3 days)
  → Available to users
```

For JS-only hotfixes:

```
Push to main branch
  → Run: eas update --branch production
  → Users receive update on next app launch (no store review)
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
| `CORS_ORIGINS` | No | Comma-separated allowed origins (default: `*`) |
| `UPLOAD_FOLDER` | No | Path for file storage (default: `/uploads`) |

### Mobile App (build-time)

| Variable | Description |
|---|---|
| `EXPO_PUBLIC_API_URL` | Backend URL (e.g. `https://your-app.up.railway.app`) |
| `EXPO_PUBLIC_GOOGLE_CLIENT_ID` | Google OAuth Web client ID (same as backend) |

These are baked into the app at build time via Expo's `EXPO_PUBLIC_` prefix convention.

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

## Cost Estimate

| Resource | Cost |
|---|---|
| Railway Hobby plan | $5/month (includes $5 usage credit) |
| Railway compute (low traffic) | ~$0-3/month above credit |
| Railway PostgreSQL (low traffic) | ~$0-2/month above credit |
| Apple Developer Program | $99/year |
| Google Play Developer | $25 one-time |
| Expo EAS Build (free tier) | 30 builds/month |
| Expo Push Service | Free |

For a low-traffic app, total monthly cost is approximately **$5-10/month** plus annual Apple developer fee.
