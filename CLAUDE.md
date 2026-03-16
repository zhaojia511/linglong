# Linglong - Claude Context

## Project Overview
Heart rate monitor platform for team sports coaching. Coaches monitor multiple athletes simultaneously via BLE chest strap sensors.

**Stack:**
- Mobile: Flutter (iOS primary, Android supported)
- Backend: Supabase (PostgreSQL + Auth + RPC) — no Node.js server
- Web: React/Vite → deployed to Cloudflare Pages

## Branches
- `main` — current combined version, most up to date
- `copilot/build-heartrate-sensor-app` — older Copilot-built branch, merged into main

Key merge commit: `5d45926` (feat: add backend, web app, mobile app with Supabase integration) — this is where sensor-to-athlete assignment was added. It is already in `main`.

## Mobile App Features (current `main`)
- **BLE chest strap HR monitoring** — connects to multiple sensors simultaneously
- **Sensor → athlete assignment** — tap sensor card on dashboard to assign to an athlete
- **Multi-athlete team session** — each sensor reads HR for its assigned athlete
- **Training session recording** — start/stop, auto-calculates stats (avg/min/max HR, calories)
- **Local persistence** — Hive (offline-first), sessions flagged `synced: false` until pushed
- **Supabase sync** — `supabase_repository.dart` pushes sessions to cloud
- **EMG device support** — separate EMG screen (display only, not saved to sessions)
- **HRV** — RR intervals captured from HR devices that support it
- **Session visualization** — `session_visualization_screen.dart`
- **Settings** — `settings_screen.dart`

## Key Mobile App Files
```
mobile_app/lib/
  models/
    person.dart          # Has: role (athlete/coach), assignedSensorIds, category, group
    hr_device.dart       # Has: rrIntervals, supportsHRV
    training_session.dart
  screens/
    dashboard_screen.dart          # Sensor assignment UI, session recording
    home_screen.dart               # Navigation, athlete list, session history
    session_visualization_screen.dart
    settings_screen.dart
    emg_screen.dart
    profile_screen.dart
    training_history_screen.dart
  services/
    ble_service.dart               # BLE device discovery/connection
    database_service.dart          # Local Hive DB + sensor assignment methods
    supabase_repository.dart       # Cloud sync
    sync_service.dart              # Supabase direct sync
    settings_service.dart
    app_initializer.dart
    emg_service.dart
  supabase/
    supabase_client.dart
```

## Sensor Assignment Flow
1. Person model has `assignedSensorIds: List<String>` (BLE device IDs)
2. `DatabaseService.assignSensorToAthlete(sensorId, athleteId)` — exclusive assignment
3. `DatabaseService.getAthleteForSensor(sensorId)` — look up who owns a sensor
4. Dashboard shows athlete name on sensor card; tap to reassign/unassign

## Sync Architecture
- Mobile → Supabase direct (via `supabase_repository.dart`)
- Web app → Supabase direct (via `web_app/src/services/api.js`)
- No Node.js backend — fully removed

## iOS Status
- iOS project files exist (`mobile_app/ios/`)
- NOT published to App Store (TestFlight not set up)
- Shows "not available" on iPhone because it must be built from source and sideloaded

## What Does NOT Exist Yet
- EMG data saved to training sessions (display only)
- App Store / TestFlight distribution
