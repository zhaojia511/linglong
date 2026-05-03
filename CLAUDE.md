# Linglong - Claude Context

## Project Overview
Heart rate monitor platform for team sports coaching. Coaches monitor multiple athletes simultaneously via BLE chest strap sensors.

**Stack:**
- Mobile: Flutter (iOS primary, Android supported)
- Backend: Supabase (PostgreSQL + Auth + RPC) — no Node.js server
- Web: React/Vite → deployed to Cloudflare Pages

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

## iOS Status
- iOS project files exist (`mobile_app/ios/`)
- NOT published to App Store (TestFlight not set up)
- Must be built from source and sideloaded

## What Does NOT Exist Yet
- App Store / TestFlight distribution

## Android build notes

- Network in this dev environment has flaky TLS handshakes to Maven Central (`repo.maven.apache.org`). Use Aliyun mirrors as first-priority repos. Already configured in:
  - `mobile_app/android/settings.gradle.kts` — `pluginManagement.repositories` (for Gradle plugins)
  - `mobile_app/android/build.gradle.kts` — `allprojects.repositories` (for app/library dependencies)
- Mirrors used (in order, before `google()` / `mavenCentral()`):
  - `https://maven.aliyun.com/repository/google` (mirrors Google's Android repo)
  - `https://maven.aliyun.com/repository/public` (mirrors Maven Central)
  - `https://maven.aliyun.com/repository/gradle-plugin` (mirrors Gradle Plugin Portal)
- JDK 21 LTS required — Gradle 8.13 is incompatible with JDK 26. `JAVA_HOME` set in `~/.zshrc`.
- TLS protocol flags in `mobile_app/android/gradle.properties` (`-Dhttps.protocols=TLSv1.2,TLSv1.3 -Djdk.tls.client.protocols=TLSv1.2,TLSv1.3`) help when JVM defaults negotiate the wrong protocol.

## Agent skills

### Issue tracker

Issues live in GitHub Issues at github.com/zhaojia511/linglong. See `docs/agents/issue-tracker.md`.

### Triage labels

Default label vocabulary: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context repo: one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
