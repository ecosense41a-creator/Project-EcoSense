[README.md](https://github.com/user-attachments/files/33627524/README.md)
# EcoSense app (Flutter): Capstone 1 starter

Admin login, presence status, sensor data, event history, logout, and persistent login.
Runs on **mock data** by default, so you do not need Firebase or the hub to try it.

Built against: Flutter 3.47.6 (stable), Dart 3.13.5. Packages: `firebase_core`,
`firebase_auth`, `firebase_database`, `shared_preferences`, `intl`.

## 1. Run it (mock mode)

```bash
flutter create --platforms=android ecosense_app
cd ecosense_app
```

1. Delete the generated `test/widget_test.dart` (it references the default counter app and will not compile with ours).
2. Delete the generated `lib/` folder and copy this project's `lib/` folder in its place.
3. Add the packages (this picks the newest compatible versions for you):

```bash
flutter pub add firebase_core firebase_auth firebase_database shared_preferences intl
flutter run
```

Pick the Android emulator in VS Code (bottom-right device selector). Sign in with
**admin / ecosense123** (mock only, defined in `lib/config.dart`).

Tip: set the emulator's time zone to Asia/Manila (Settings > System > Date & time) so log times match local time.

## 2. Where each feature lives

| # | Feature | File |
|---|---------|------|
| 1 | Admin login | `screens/login_screen.dart`, `services/*_auth_service.dart` |
| 2 | Presence status (`/status`) | `screens/status_tab.dart` |
| 3 | Sensor data (`/sensors/mmwave`, `/sensors/door`) | `screens/sensors_tab.dart` |
| 4 | Event history (`/logs`, last 50) | `screens/logs_tab.dart` |
| 5 | Logout | `screens/home_shell.dart` (top-right icon) |
| 6 | Persistent login | `app.dart` (`AuthGate`) + the auth services |

Design in one sentence: screens only talk to two interfaces (`AuthService`, `DataRepository`);
each has a **mock** and a **Firebase** implementation, and `main.dart` picks one using `kUseMockData`.

Extra (not in your task list, on purpose): the app shows **"Hub offline"** when `hub_last_seen`
is older than `kHubOfflineAfterSeconds`, because a stale "Vacant" or "Occupied" is misleading.

## 3. Switching to real Firebase

1. Firebase console > Authentication > Sign-in method: enable **Email/Password**.
2. Create the admin user with the email `<username>@ecosense.example.com`
   (for username `admin`: `admin@ecosense.example.com`). The app adds the domain
   for you; change it in `kUsernameEmailDomain` if you use another.
   If your admin is currently only a record in the database, move it to Authentication first.
3. Create the Realtime Database, then:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

   Choose your project and Android. This overwrites `lib/firebase_options.dart`.
   Create the database **before** running it, so the database URL is included.
4. In `lib/config.dart` set `kUseMockData = false`.
5. Database rules: reads only for signed-in users.

```json
{
  "rules": {
    ".read": "auth != null",
    ".write": false
  }
}
```

   `".write": false` also blocks your hub. Give the hub its own write permission
   (its own account or token) instead of opening writes to everyone.

## 4. Test checklist (mock mode)

1. Wrong password shows an error. `admin` / `ecosense123` opens the home screen.
2. Persistent login: sign in, swipe the app away from recent apps, reopen it. You land on the home screen, not login.
3. Logout: tap the logout icon and confirm. You return to login. Reopen the app: still logged out.
4. Status (80-second loop): Occupied, then confidence falls, then Vacant, then an amber "Suspect" banner, then Occupied again.
5. Sensors: values change every 2 seconds. The door shows Open briefly during the suspect phase.
6. History: 8 starting entries; a new entry appears at the top when the room turns Vacant (about 58 s) and Occupied again (about 74 s).
7. Hub offline: set `kMockHubOffline = true`, restart. After about 30 s the status screen shows "Hub offline".
