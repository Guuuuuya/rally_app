# RallyTrack

Offline-first rally social + telemetry app. Free-tier stack: Flutter + Firebase (Firestore, Auth) + Mapbox.

## Setup (one-time)

```powershell
flutter create . --platforms android,ios   # generates platform folders into this project
flutter pub get
dart pub global activate flutterfire_cli
firebase login
flutterfire configure                      # pick/create a free Firebase project (Spark plan)
flutter run --dart-define=MAPBOX_TOKEN=pk.YOUR_PUBLIC_TOKEN
```

Mapbox token: free account at mapbox.com/account → **public** token.

## Android (android/app/src/main/AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
```

Also set `minSdkVersion 24` in `android/app/build.gradle`.

## iOS (ios/Runner/Info.plist)

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>RallyTrack needs your location to show your live pin and telemetry.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Background tracking keeps your pin live while driving a stage.</string>
<key>UIBackgroundModes</key>
<array><string>location</string></array>
```

## How the pieces fit

- **Join**: anonymous sign-in → create group (4-digit pin shown) or join by pin (`codes/{code}` lookup).
- **Live map**: GPS stream (2s/10m throttle) → `groups/{groupId}/live/{uid}` upsert. Teammates listen via `livePins()`; pins grey out after 60s stale.
- **Offline**: Firestore persistence (default on mobile) queues all writes; tracker buffers points in SQLite (`sqflite`) and flushes in batches of 20 / every 30s / on reconnect (`connectivity_plus`). Timer, distance, top speed all compute locally — full functionality with zero signal.
- **Stage timer**: FAB Start/End Stage → `sessions/{id}` doc.
- **Leaderboard**: on stage end, summary fields on `sessions/{sessionId}/tracks/{uid}`; screen sorts by distance.

## Files

```
lib/
  main.dart            app entry, Firebase + Mapbox init, providers
  db.dart              Firestore service (auth, groups, live, sessions, board)
  locator.dart         permissions + GPS stream
  tracker.dart         offline timer/distance tracker + SQLite buffer + flush
  screens/
    join_screen.dart   create/join by 4-digit pin
    home_screen.dart   resolves user's group
    map_screen.dart    Mapbox map, live pins, speed/distance, stage timer
    leaderboard_screen.dart  post-drive summary
```

## Auto-updates

The app checks Firestore `config/app` on launch and prompts to install a newer APK:

```json
{ "latestVersion": "0.2.0", "apkUrl": "https://<project>.web.app/app.apk", "notes": "..." }
```

Release a new version:

```powershell
# bump `version` in pubspec.yaml first
flutter build apk --release --dart-define=MAPBOX_TOKEN=pk.YOUR_TOKEN
copy build\app\outputs\flutter-apk\app-release.apk public\app.bin   # Spark plan blocks .apk hosting
firebase deploy --only hosting
# then set `config/app`.apkUrl to https://<project>.web.app/app.bin, bump latestVersion
```

## Notes

- Firestore free tier: 50k reads / 20k writes per day. Throttle is already set (2s/10m, 20-point batches). If you scale past ~20 concurrent drivers, move live pins to Realtime Database.
- Pre-download Mapbox offline tile packs for stage areas before leaving coverage.
- `flutter analyze` to check, then run on a physical device (emulators don't do real GPS/background well).
