# Readiness Cloud Sync Spec

**Date:** 2026-05-06  
**Status:** Ready for implementation  
**Relates to:** `docs/superpowers/specs/2026-05-06-hrv-readiness-recording-history.md`

---

## Problem

The mobile sync button (`SyncService.syncAll`) pushes and pulls training sessions but ignores readiness measurements entirely. The web app's Readiness History page reads from the `readiness_measurements` Supabase table, which is always empty because nothing writes to it from the mobile app.

---

## Goal

Add readiness measurements to the existing sync flow so that after tapping sync:

- Local unsynced readiness measurements are uploaded to Supabase.
- Cloud readiness records are pulled down to local Hive storage.

No new UI is required. The sync button should handle both training sessions and readiness transparently.

---

## Current State

| Layer | Training sessions | Readiness measurements |
|---|---|---|
| Local storage | Hive box `training_sessions` | Hive box `readiness_measurements` |
| `synced` flag tracked | ✅ | ✅ (field exists, never acted on) |
| `SupabaseRepository` method | `upsertTrainingSession` | ❌ missing |
| Sync-up in `SyncService` | ✅ via `syncAllUnsyncedSessions` | ❌ missing |
| Sync-down in `DatabaseService` | ✅ via `syncDownFromCloud` | ❌ missing |
| Web app reads from Supabase | ✅ | ✅ (but table always empty) |

The Supabase table `readiness_measurements` already exists with the correct schema (migration `003_readiness_measurements.sql`).

---

## Field Mapping

| `ReadinessMeasurement` (Dart) | `readiness_measurements` (Supabase) |
|---|---|
| `id` | `id` |
| `personId` | `person_id` |
| `deviceId` | `device_id` |
| `measuredAt` | `measured_at` |
| `durationSec` | `duration_sec` |
| `rrIntervals` | `rr_intervals` (jsonb array) |
| `rmssd` | `rmssd` |
| `sdnn` | `sdnn` |
| `pnn50` | `pnn50` |
| `meanRR` | `mean_rr` |
| `sd1` | `sd1` |
| `sd2` | `sd2` |
| `restingHR` | `resting_hr` |
| `qualityPct` | `quality_pct` |
| `readinessPct` | `readiness_pct` |
| `feelingScore` | `feeling` |
| _(auth user)_ | `user_id` |

---

## Required Changes

### 1. `SupabaseRepository` — two new methods

**`upsertReadinessMeasurement`**  
Insert or update one readiness record. Uses `id` as conflict target so repeated syncs are idempotent.

**`fetchReadinessMeasurements`**  
Fetch all readiness records for the authenticated user, ordered by `measured_at` descending.

### 2. `HrvService` — sync-up helper

Add `syncAllUnsyncedReadiness(SupabaseRepository repo)`:
- Load all local `ReadinessMeasurement` records where `synced == false`.
- Call `repo.upsertReadinessMeasurement(...)` for each.
- On success, overwrite the Hive entry with `synced: true`.
- Errors per-record should be logged and skipped (same pattern as training sessions).

### 3. `HrvService` — sync-down helper

Add `syncDownReadinessFromCloud(SupabaseRepository repo)`:
- Call `repo.fetchReadinessMeasurements()`.
- For each remote record, check if a local record with the same `id` already exists.
- If missing, insert locally with `synced: true`.
- Do not overwrite existing local records (local wins on conflict).

### 4. `SyncService._syncOnLogin` — wire it in

After the existing `db.syncDownFromCloud(_repo)` / `db.syncAllUnsyncedSessions(_repo)` calls, add:

```
await hrv.syncDownReadinessFromCloud(_repo);
await hrv.syncAllUnsyncedReadiness(_repo);
```

`HrvService.instance` is accessible the same way `DatabaseService.instance` is used.

---

## Behaviour Spec

| Scenario | Expected result |
|---|---|
| Offline sync attempt | Skip silently; local records stay `synced: false` |
| Record already on cloud (same id) | Upsert is idempotent; no duplicate |
| Cloud record not in local Hive | Inserted locally as `synced: true` |
| Sync failure mid-batch | Completed records are marked synced; failed records retry on next sync |
| Not authenticated | Entire sync is skipped (existing guard in `SyncService`) |

---

## Out of Scope

- Conflict resolution when the same record differs locally and remotely (local wins for now).
- Deleting cloud records from the mobile app.
- Syncing `DailyHrvSnapshot` (session-derived HRV) — only dedicated readiness measurements.
- Any UI changes.

---

## Acceptance Criteria

1. After tapping sync, all local readiness measurements with `synced: false` appear in the Supabase `readiness_measurements` table.
2. After sync, those records are updated to `synced: true` locally.
3. Cloud records created on another device (or directly in Supabase) appear in local Hive after sync-down.
4. The web app Readiness History page shows the synced measurements without any additional changes.
5. A repeated sync does not create duplicate rows in Supabase.
