# Developer Quickstart

Audience: Developer

Follow these steps in order. Each step builds on the previous one.

## 1. Install Prerequisites

Install the following before proceeding:

- **Python 3.11+** — [python.org/downloads](https://www.python.org/downloads/)
- **Node.js 18+** — [nodejs.org](https://nodejs.org/)
- **PostgreSQL 15+** — [postgresql.org/download](https://www.postgresql.org/download/) (includes pgAdmin)
- **Android Studio** — [developer.android.com/studio](https://developer.android.com/studio)
- **Git** — [git-scm.com](https://git-scm.com/)

## 2. Set Up Android Environment

Android Studio installs the Android SDK and a bundled JDK. Two environment variables must be set so that build tools can find them.

Open PowerShell and run:

```powershell
# Set permanently (takes effect in new terminals)
[System.Environment]::SetEnvironmentVariable("ANDROID_HOME", "C:\Users\<your-username>\AppData\Local\Android\Sdk", "User")
[System.Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\Program Files\Android\Android Studio\jbr", "User")

# Set for current terminal session immediately
$env:ANDROID_HOME = "C:\Users\<your-username>\AppData\Local\Android\Sdk"
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
```

Replace `<your-username>` with your Windows username.

### Create an Android Emulator

1. Open Android Studio
2. From the Welcome screen, click **More Actions** > **Virtual Device Manager**
3. If a device already exists (e.g. "Medium Phone API 36.1"), you can use it — skip to step 7
4. Click **Create Virtual Device**
5. Pick a phone (e.g. Pixel 7), click Next
6. Download a system image (e.g. API 34 or latest), click Next, then **Finish**
7. Click the play button (triangle) next to the device to start the emulator
8. Wait until the Android home screen appears before continuing

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
| TripToe Web | Web application | `GOOGLE_CLIENT_ID` in backend `.env` and `EXPO_PUBLIC_GOOGLE_CLIENT_ID` in mobile `.env` | Same for dev and prod |
| TripToe Android Debug | Android | Auto-selected during local development | SHA-1 from `debug.keystore` |
| TripToe Android Prod | Android | Auto-selected in app store builds | SHA-1 from EAS production keystore (create later) |
| TripToe iOS | iOS | Auto-selected on iOS devices | Create if building for iOS |

**For iOS**, create an OAuth client with application type **iOS** and bundle ID `com.triptoe.mobile`. The same iOS client works for both dev and prod.

## 5. Set Up the Backend

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
CORS_ORIGINS=*
```

Replace `yourpassword` with the password you set for the `postgres` user when you installed PostgreSQL. For `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`, use the Web client credentials from step 4.

## 6. Set Up the Mobile App

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

## 7. Run the App

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

## 8. Test the App

### Guest Flow
1. Open the app on the emulator
2. Tap "I'm a Guest"
3. Sign up with name and email
4. Scan a tour QR code to book
5. Check in and share location during the tour

### Guide Flow
1. Tap "I'm a Tour Guide"
2. Sign in with Google
3. Create a tour from the "Create Tour" tab (set title, duration, meeting place, timezone)
4. From "My Tours" tab, tap a tour to see its details
5. Tap "+ Schedule" to schedule a specific date/time for the tour
6. View and manage scheduled tours from the tour details screen

### Returning Guest
1. Tap "I'm a Guest" > "Already have an account? Sign in"
2. Enter your email
3. Enter the 6-digit code sent to your email
4. View booked tours on the dashboard

## 9. Common Issues

| Issue | Solution |
|-------|----------|
| `adb` is not recognized | Set `ANDROID_HOME` environment variable — see step 2 |
| `JAVA_HOME is not set` | Set `JAVA_HOME` to `C:\Program Files\Android\Android Studio\jbr` — see step 2 |
| `No emulators could be started` | Start the emulator from Android Studio Virtual Device Manager first |
| `adb device offline` | The emulator is still booting — wait for the Android home screen, then try again |
| `npm install` fails with peer dependency errors | Use `npm install --legacy-peer-deps` |
| `react-dom/client could not be found` | Run `npm install react-dom --legacy-peer-deps` |
| Backend can't connect to DB | Check `DATABASE_URL` in `.env` — ensure PostgreSQL is running and the `triptoe` database exists |
| Mobile app can't reach backend | If using a physical device, replace `localhost` with your computer's IP in `EXPO_PUBLIC_API_URL` |
| Google Sign-In fails | Verify `GOOGLE_CLIENT_ID` matches in both `.env` files and that the Android OAuth client is created with the correct SHA-1 |
| Emulator window too tall / off-screen | Press `Ctrl+Down` to resize the emulator window to fit your screen |
| `babel-preset-expo` not found during build | Run `npm install babel-preset-expo --legacy-peer-deps` and clear Gradle cache with `rm -rf android/.gradle` |

For production deployment, see [Deployment Guide](4_deployment_guide.md).
