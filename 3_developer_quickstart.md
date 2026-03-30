# Developer Quickstart

Audience: Developer

Follow these steps in order. Each step builds on the previous one.

## 1. Install Prerequisites

Install the following before proceeding:

- **Python 3.11+** — [python.org/downloads](https://www.python.org/downloads/)
- **Node.js 18+** — [nodejs.org](https://nodejs.org/)
- **PostgreSQL 15+** — [postgresql.org/download](https://www.postgresql.org/download/) (includes pgAdmin)
- **Git** — [git-scm.com](https://git-scm.com/)

## 2. Set Up Android Emulator

Follow the [Android Emulator Setup](4_android_emulator_setup.md) guide to install the Android SDK, Java, and create emulators. Come back here after completing steps 1-6.

## 3. Create the Database

**Option A: pgAdmin (GUI)**
1. Open pgAdmin and connect to your local server
2. Right-click Databases > Create > Database
3. Set database name to `triptoe`, owner to `postgres`, click OK

**Option B: Command line**

```bash
psql -U postgres -c "CREATE DATABASE triptoe;"
```

Note your PostgreSQL password for the `postgres` user — you'll need it in step 5.

> PostGIS is not required for initial development. It will be needed later for the nearby tour discovery feature (spatial queries like "find tours within 10 miles"). When that time comes, install PostGIS on your system and run `CREATE EXTENSION IF NOT EXISTS postgis;` in the `triptoe` database.

## 4. Google OAuth Setup

Required for guide sign-in. Both the backend and mobile app use the same Client ID.

### Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click the project dropdown at the top > **New Project**
3. Name it (e.g. `triptoe`), click Create
4. Make sure the new project is selected in the dropdown

### Configure OAuth Consent Screen

5. Go to **APIs & Services** > **OAuth consent screen**
6. Select **External** user type, click Create
7. Fill in the required fields:
   - App name: `TripToe`
   - User support email: your email
   - Developer contact email: your email
8. Click **Save and Continue** through the Scopes and Test Users steps (no changes needed)
9. Click **Back to Dashboard**

### Create OAuth Client ID

10. Go to **APIs & Services** > **Credentials**
11. Click **Create Credentials** > **OAuth client ID**
12. Application type: **Web application**
13. Name: `TripToe Web` (or any name)
14. Click **Create**
15. Copy the **Client ID** and **Client Secret** — you'll need these in steps 5 and 6

### Create Android OAuth Clients

Google requires platform-specific OAuth clients for Android. The Google Sign-In library selects them automatically based on the signing key — you don't reference these Client IDs in your code or `.env` files. You just need to create them in Google Cloud Console.

You need **two** Android OAuth clients — one for development and one for production — because each uses a different signing key with a different SHA-1 fingerprint.

**Android client for development (debug):**

16. Back in **Credentials**, click **Create Credentials** > **OAuth client ID**
17. Application type: **Android**
    - Name: `TripToe Android Debug`
    - Package name: `com.triptoe.mobile`
    - SHA-1 fingerprint: run this from `triptoe-mobile/` in PowerShell to get the debug key's fingerprint:
      ```
      & "$env:JAVA_HOME\bin\keytool" -list -v -keystore android\app\debug.keystore -alias androiddebugkey -storepass android -keypass android
      ```
      Copy the `SHA1:` value from the output
18. Click **Create**

**Android client for production:**

You will create this later when you are ready to publish to the Google Play Store. The production signing key is managed by EAS Build.

19. Run `eas credentials` from `triptoe-mobile/` and select Android — it will show the production SHA-1 fingerprint
20. In Google Cloud Console, create another **Android** OAuth client:
    - Name: `TripToe Android Prod`
    - Package name: `com.triptoe.mobile`
    - SHA-1 fingerprint: use the production SHA-1 from step 19

### Summary of OAuth Clients

All clients live in the same Google Cloud project:

| Name | Type | Used in | Notes |
|---|---|---|---|
| TripToe OAuth | Web application | `GOOGLE_CLIENT_ID` in backend `.env` and `EXPO_PUBLIC_GOOGLE_CLIENT_ID` in mobile `.env` | Same for dev and prod |
| TripToe Mobile | Android | Auto-selected during builds | SHA-1 from `triptoe-release.keystore` |
| TripToe iOS | iOS | Auto-selected on iOS devices | Create if building for iOS |

**For iOS**, create an OAuth client with application type **iOS** and bundle ID `com.triptoe.mobile`. The same iOS client works for both dev and prod.

## 5. Google Maps API Key

Required for displaying maps in the app (e.g. guest locations during a tour). Uses the same Google Cloud project from step 4.

1. In Google Cloud Console, go to **APIs & Services** > **Library**
2. Search for **Maps SDK for Android** and enable it
3. Go to **Credentials** > **Create Credentials** > **API Key**
4. Name it (e.g. "TripToe"), leave restrictions as **None** for development
5. Click **Create** and copy the key

The key is configured in `triptoe-mobile/app.json` under `expo.android.config.googleMaps.apiKey`. If you need to change it, edit that value and rebuild (`npx expo prebuild --clean` then `npx expo run:android`).

Before going to production, restrict the key to **Android apps** with package name `com.triptoe.mobile`.

## 6. Set Up the Backend

```bash
cd triptoe-backend

# Create virtual environment
python -m venv venv

# Activate (choose your platform)
# Windows (PowerShell): venv\Scripts\Activate.ps1
# Windows (bash/Git Bash): source venv/Scripts/activate
# macOS/Linux: source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Create environment file
cp .env.example .env
```

Edit `.env` with your values:

```
SECRET_KEY=some-random-string
DATABASE_URL=postgresql://postgres:yourpassword@localhost:5432/triptoe
JWT_SECRET_KEY=another-random-string
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
RESEND_API_KEY=your-resend-api-key
CORS_ORIGINS=*
```

Replace `yourpassword` with the password you set for the `postgres` user when you installed PostgreSQL. For `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`, use the Web client credentials from step 4. For `RESEND_API_KEY`, sign up at [resend.com](https://resend.com) and create an API key. Without it, verification codes are logged to the backend console instead of emailed.

## 7. Set Up the Mobile App

```bash
cd triptoe-mobile

# Install dependencies
npm install --legacy-peer-deps

# Create environment file
cp .env.example .env
```

Edit `.env`:

```
EXPO_PUBLIC_API_URL=http://10.0.2.2:5000/api/v1
EXPO_PUBLIC_GOOGLE_CLIENT_ID=your-google-client-id
```

- `10.0.2.2` is the Android emulator's alias for your computer's `localhost`. If using a physical device instead, use your computer's local IP address (e.g. `192.168.x.x`).
- For `EXPO_PUBLIC_GOOGLE_CLIENT_ID`, use the same **Client ID** as `GOOGLE_CLIENT_ID` in the backend `.env` (the Web client from step 4).

### Package Version Warnings

If Expo shows warnings about package version mismatches, run:

```bash
npx expo install --fix
```

## 8. Run the App

### Start the Backend

```bash
cd triptoe-backend
python main.py
```

On first run, the backend automatically creates all database tables. Verify it's running:

```bash
curl http://localhost:5000/health
```

You should see `{"status": "healthy"}`. All API routes are under `/api/v1/`.

Leave the backend running and open a new terminal for the mobile app.

### Start the Mobile App

Make sure the Android emulator is running (from step 2) and the backend is running (above).

```bash
cd triptoe-mobile
npx expo run:android
```

The first build takes several minutes. Once complete, the app will open on the emulator. Subsequent builds are faster.

## 9. Test the App

### Guest Flow
1. Open the app on the emulator
2. Tap "I'm a Guest"
3. Sign up with name and email, then enter the 6-digit code (sent to your email via Resend, or check the backend console log if `RESEND_API_KEY` is not set)
4. Join a tour by entering the tour code or scanning a QR code
5. Check in and share location during the tour

### Guide Flow
1. Tap "I'm a Tour Guide"
2. Sign in with Google
3. From "My Tours" tab, tap "+ New Tour" to create a **Tour Template** (set title, duration, meeting place, timezone)
4. Tap a tour to see its sessions
5. Tap "+ Session" to create a **Tour Session** for a specific date/time
6. View and manage tour sessions from the tour template sessions screen
7. Tap a specific session to see the live map and guest check-ins

### Returning Guest
1. Tap "I'm a Guest" (if you've logged in before, this goes directly to sign-in)
2. Enter your email
3. Enter the 6-digit code (sent to your email via Resend, or check the backend console log if `RESEND_API_KEY` is not set)
4. View booked tour sessions on the dashboard (My Tours)

## 10. Common Issues

| Issue | Solution |
|-------|----------|
| Emulator or ADB issues | See [Android Emulator Setup — Troubleshooting](4_android_emulator_setup.md#troubleshooting) |
| `npm install` fails with peer dependency errors | Use `npm install --legacy-peer-deps` |
| `react-dom/client could not be found` | Run `npm install react-dom --legacy-peer-deps` |
| Backend can't connect to DB | Check `DATABASE_URL` in `.env` — ensure PostgreSQL is running and the `triptoe` database exists |
| Mobile app can't reach backend | If using a physical device, replace `localhost` with your computer's IP in `EXPO_PUBLIC_API_URL` |
| Google Sign-In fails | Verify `GOOGLE_CLIENT_ID` matches in both `.env` files and that the Android OAuth client is created with the correct SHA-1 |
| Emulator window too tall / off-screen | Press `Ctrl+Down` to resize the emulator window to fit your screen |
| `babel-preset-expo` not found during build | Run `npm install babel-preset-expo --legacy-peer-deps` and clear Gradle cache with `rm -rf android/.gradle` |

For production deployment, see [Deployment Guide](5_deployment_guide.md).
