# HRV Readiness Recording & History Spec

**Date:** 2026-05-06
**Status:** Proposed

---

## Problem

The app can take a dedicated readiness measurement from the readiness screen and persist a local HRV snapshot, but it does not yet provide a complete recording workflow comparable to training session history.

Current gaps:

- Measurements are saved locally through `HrvService.saveReadinessSnapshot()`, but there is no dedicated readiness history screen.
- The local snapshot model is too thin for readiness-specific review. It stores RMSSD/SDNN/resting HR/sample count only, and drops measurement context such as `deviceId`, duration, feeling score, readiness percentage, and quality score.
- The app has a Supabase migration for `readiness_measurements`, but no repository methods or sync flow currently write to or read from that table.
- Local storage mixes session-derived HRV snapshots and dedicated readiness measurements in one box with no explicit type discriminator.

Result: readiness measurements are technically saved, but they are not surfaced, auditable, or synced like training session history.

---

## Goals

- Record each dedicated readiness measurement as a first-class artifact.
- Let coaches review readiness history per athlete, similar to training history.
- Preserve enough metadata to interpret the measurement later.
- Sync readiness measurements to Supabase for backup and multi-device access.
- Distinguish dedicated readiness measurements from session-derived HRV snapshots.

## Non-Goals

- Replacing the current readiness score algorithm.
- Building advanced readiness analytics beyond a practical history view.
- Adding medical claims or diagnosis features.

---

## Current State

### Implemented

- A readiness measurement UI exists in `mobile_app/lib/screens/readiness_screen.dart`.
- Saving a result calls `HrvService.saveReadinessSnapshot()`.
- Local snapshots are persisted in Hive box `hrv_snapshots`.
- A Supabase schema exists in `supabase/migrations/003_readiness_measurements.sql`.

### Missing

- Dedicated local model for readiness measurements.
- Readiness history list/detail UI.
- Filtering, trend review, and deletion flow for readiness entries.
- Supabase repository methods for readiness measurement CRUD/sync.
- Sync-up and sync-down integration alongside training sessions.
- Explicit linkage between a saved measurement and its source metadata.

---

## User Stories

- As a coach, I can review an athlete's recent readiness measurements in chronological order.
- As a coach, I can open a measurement and see the values and context that explain why readiness was high or low.
- As a coach, I can compare today's readiness with the athlete's baseline and recent trend.
- As a coach, I can trust that saved readiness measurements sync to the cloud like training sessions.
- As a coach, I can distinguish a deliberate morning readiness test from HRV captured during a training session.

---

## Product Requirements

### 1. Dedicated readiness record model

Create a dedicated model for persisted readiness measurements instead of reusing the generic daily HRV snapshot.

Required fields:

- `id`
- `personId`
- `deviceId`
- `measuredAt`
- `durationSec`
- `rrIntervals` or a compact persisted representation if raw storage is considered acceptable
- `rmssd`
- `sdnn`
- `pnn50`
- `meanRR`
- `sd1`
- `sd2`
- `restingHr`
- `qualityPct`
- `readinessPct`
- `feelingScore`
- `sourceType` with values such as `dedicated_readiness` and `session_hrv`
- `synced`

Notes:

- If raw RR intervals are too large for local history needs, store them only in Supabase and keep derived metrics locally. This tradeoff should be decided explicitly.
- The current `DailyHrvSnapshot` model can remain for baseline calculations temporarily, but the product direction should move to a readiness-specific entity.

### 2. Save flow

When a coach taps save on the readiness results screen:

- Persist a dedicated readiness measurement record locally.
- Mark it `synced: false`.
- Recompute readiness against the current baseline and save the displayed result with the record.
- Preserve the athlete-selected feeling score, if provided.
- Preserve measurement duration used by the screen.

If saving fails, show an error and do not dismiss the screen silently.

### 3. Readiness history UI

Add a readiness history surface that mirrors the practical usability of training history.

Minimum UX:

- Entry point from athlete profile and/or readiness screen.
- Reverse-chronological list of saved readiness measurements.
- Each row shows athlete, timestamp, readiness state, RMSSD, resting HR, sync state.
- Empty state for athletes with no readiness measurements.
- Tap row opens a detail screen.

### 4. Readiness detail UI

Each saved measurement should expose:

- Athlete name
- Timestamp
- Device used
- Measurement duration
- Readiness percentage and zone
- RMSSD, SDNN, pNN50, mean RR, SD1, SD2
- Resting HR
- Quality percentage
- Feeling score
- Baseline used for comparison

Optional if retained in storage:

- Raw RR interval count
- Small trend sparkline over recent readiness measurements

### 5. History filters and trend review

Minimum filtering:

- Athlete
- Date range: 7 days, 28 days, 60 days, all

Minimum trend summary:

- Latest readiness
- 7-day average readiness
- Baseline RMSSD
- Count of valid measurements in the selected period

### 6. Sync behavior

Implement explicit cloud sync for readiness measurements.

Requirements:

- Add Supabase repository methods to upsert and fetch readiness measurements.
- Sync unsynced local readiness records during normal sync operations.
- Pull remote readiness records into local storage on sync-down.
- Preserve stable record IDs across local and cloud stores.
- Do not duplicate records on repeated sync.

If a cloud sync fails:

- Keep the local record.
- Leave `synced: false`.
- Surface the state in history UI similarly to training history.

### 7. Baseline/readiness calculation behavior

Baseline should prioritize dedicated readiness measurements over session-derived HRV.

Rules:

- Use only `dedicated_readiness` records for readiness baseline when enough samples exist.
- Fall back to older snapshot logic only if migration/backfill is incomplete.
- Require a minimum number of valid dedicated readiness measurements before marking the baseline as established.
- Exclude low-quality measurements from baseline calculations.

### 8. Editing and deletion

Minimum management actions:

- Delete a mistaken readiness measurement locally.
- Propagate deletion to cloud when already synced.

Editing previously recorded physiological values is out of scope. Feeling score or notes can be considered later.

---

## Data Design Notes

The existing Supabase migration already describes most of the correct readiness schema. The mobile app should align with it rather than keep a reduced local-only snapshot shape.

Recommended direction:

- Introduce a readiness measurement model in Flutter that matches the Supabase table closely.
- Keep `DailyHrvSnapshot` only as a compatibility layer if needed during migration.
- Add a source discriminator so session HRV and deliberate readiness tests are not mixed invisibly.

---

## Implementation Outline

### Mobile app

- Add readiness measurement model and local box/storage helpers.
- Update `HrvService` save/query methods to use the new model.
- Add history and detail screens.
- Add sync-state indicators.
- Update baseline/readiness calculation queries to prefer dedicated readiness data.

### Supabase integration

- Add `SupabaseRepository` methods for upsert/fetch/delete readiness measurements.
- Extend sync service or database service to include readiness upload/download.
- Map local fields to `readiness_measurements` columns.

### Migration path

- Existing local `DailyHrvSnapshot` entries created from readiness tests may be backfilled into the new structure where possible.
- Session-derived HRV snapshots should not automatically appear in readiness history unless explicitly labeled and intended.

---

## Acceptance Criteria

- Saving a readiness test creates a dedicated local record with readiness-specific metadata.
- Coaches can open a readiness history list and review past measurements per athlete.
- Coaches can open a measurement detail view and inspect the full saved context.
- Unsynced readiness records are visibly marked.
- Sync uploads local readiness records to Supabase and restores them on sync-down.
- Baseline/readiness calculations use dedicated readiness measurements when available.
- Session HRV snapshots do not silently appear as readiness history items.

---

## Open Questions

- Should raw RR intervals be stored locally, in cloud only, or both?
- Should readiness history live as a separate tab, an athlete subpage, or both?
- Should coaches be allowed to add notes to a readiness measurement?
- What minimum quality threshold should exclude a measurement from baseline calculations?

---

## Recommendation

Treat this as a feature-completeness gap, not just a UI enhancement. The recording model, history UI, and sync path should be implemented together so readiness measurements become durable, reviewable artifacts like training sessions.