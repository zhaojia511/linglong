# Linglong - Claude Context

## Project Overview
Heart rate monitor platform for team sports coaching. Coaches monitor multiple athletes simultaneously via BLE chest strap sensors.

**Stack:**
- Mobile: Flutter (iOS primary, Android supported)
- Backend: Supabase (PostgreSQL + Auth + RPC) — no Node.js server
- Web: React/Vite → deployed to Cloudflare Pages

## Branches
- `main` — current combined version, most up to date
- `copilot/build-heartrate-sensor-app` — older Copilot-built branch
- `machine2-wip` — work in progress from another session

Key merge commit: `5d45926` (feat: add backend, web app, mobile app with Supabase integration) — this is where sensor-to-athlete assignment, Supabase auth, settings, session visualization were added.

## Version Merge Status (2026-03-16)
Two versions of the mobile app were combined:
- **`5d45926` version**: Had sensor→athlete assignment, Supabase auth, settings, session visualization, HRV support
- **`main` (copilot) version**: Had EMG support, training history screen, training_session model

**Merge completed**: Features from `5d45926` restored into `main`:
- `person.dart` — restored with `role`, `assignedSensorIds`, `category`, `group`, `hasSensorAssigned()`
- `hr_device.dart` — restored with `rrIntervals`, `supportsHRV`
- Auth system ported from hootuo project (see Auth section below)

**Removed**: EMG support (`emg_screen.dart`, `emg_service.dart`) — user doesn't need it now.

## Auth System
Ported from `d:/github/hootuo` (private repo, force plate analysis app). Simplified for linglong (no org membership).

- `auth_service.dart` — Supabase email/password auth via `ChangeNotifier`
- `login_screen.dart` — email + password login UI
- `auth_gate.dart` — routes to login or app based on `AuthService` state
- `main.dart` — `AuthService` in providers, `AuthGate` wraps the app
- `settings_screen.dart` — sign-out uses `AuthService`

Supabase project URL: `https://krbobzpwgzxhnqssgwoy.supabase.co` (configured in `supabase/supabase_client.dart`)

## Mobile App Features (current `main`)
- **BLE chest strap HR monitoring** — connects to multiple sensors simultaneously
- **Sensor → athlete assignment** — tap sensor card on dashboard to assign to an athlete
- **Multi-athlete team session** — each sensor reads HR for its assigned athlete
- **Training session recording** — start/stop, auto-calculates stats (avg/min/max HR, calories)
- **Local persistence** — Hive (offline-first), sessions flagged `synced: false` until pushed
- **Supabase sync** — `supabase_repository.dart` + `sync_service.dart` push sessions to cloud
- **Auth** — email/password login via Supabase Auth
- **HRV** — RR intervals captured from HR devices that support it
- **Session visualization** — `session_visualization_screen.dart`
- **Settings** — `settings_screen.dart` (Supabase cloud sync config, sign out)
- **Profile/Team management** — `profile_screen.dart` (add/edit/delete team members, sync dialog)

## Key Mobile App Files
```
mobile_app/lib/
  models/
    person.dart          # Has: role (athlete/coach), assignedSensorIds, category, group
    hr_device.dart       # Has: rrIntervals, supportsHRV
    training_session.dart
  screens/
    auth_gate.dart                 # Routes to login or app
    login_screen.dart              # Email/password login
    dashboard_screen.dart          # Sensor assignment UI, session recording
    home_screen.dart               # Navigation, athlete list, session history
    session_visualization_screen.dart
    settings_screen.dart
    profile_screen.dart            # Team member CRUD + sync dialog
    training_history_screen.dart
  services/
    auth_service.dart              # Supabase auth (ChangeNotifier)
    ble_service.dart               # BLE device discovery/connection
    database_service.dart          # Local Hive DB + sensor assignment methods
    supabase_repository.dart       # Cloud sync
    sync_service.dart              # Supabase direct sync
    settings_service.dart
    app_initializer.dart
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

## Related Projects
- `d:/github/hootuo` — force plate analysis app (private). Auth pattern ported from there.

## iOS Status
- iOS project files exist (`mobile_app/ios/`)
- NOT published to App Store (TestFlight not set up)
- Must be built from source and sideloaded

## What Does NOT Exist Yet
- App Store / TestFlight distribution
