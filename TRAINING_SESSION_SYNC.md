# Training Session Cloud Sync Implementation

## Overview
Implemented automatic cloud synchronization of training sessions from the mobile app to Supabase after a training session is completed and saved locally. This enables data analysis on the backend and provides users with cloud-based session history.

## Architecture

### Components Modified

#### 1. **SupabaseRepository** (`mobile_app/lib/services/supabase_repository.dart`)
Added two new methods for session synchronization:

**`upsertTrainingSession()`**
- Uploads a complete training session to Supabase
- Parameters:
  - Session metadata (id, personId, title, trainingType)
  - Timestamps (startTime, endTime)
  - Heart rate statistics (avgHeartRate, maxHeartRate, minHeartRate)
  - Caloric burn estimate
  - Complete heart rate data array
  - Optional RR intervals for HRV analysis
  - Session notes
- Uses Supabase `upsert` operation for idempotent writes
- Marks session as `synced = true` in cloud

**`getUnsyncedSessions()`**
- Queries Supabase for sessions not yet synced
- Returns list of unsynced sessions from cloud (useful for offline scenarios)
- Helps identify sessions that need synchronization

#### 2. **DatabaseService** (`mobile_app/lib/services/database_service.dart`)
Added two new methods for local-to-cloud synchronization:

**`syncSessionToCloud(TrainingSession session, SupabaseRepository repo)`**
- Orchestrates the sync of a single completed session
- Process:
  1. Validates session is complete (has endTime)
  2. Prepares heart rate data in JSON format
  3. Calls SupabaseRepository.upsertTrainingSession()
  4. Updates local session's `synced` flag
  5. Returns success/failure status
- Handles errors gracefully with debug logging

**`syncAllUnsyncedSessions(SupabaseRepository repo)`**
- Bulk sync all unsynced sessions
- Useful for:
  - Offline-first scenarios
  - Background sync operations
  - Periodic sync tasks
- Returns count of successfully synced sessions

#### 3. **DashboardScreen** (`mobile_app/lib/screens/dashboard_screen.dart`)
Enhanced training session workflow with automatic sync:

**New State Variable**
- `_isSyncing`: Boolean flag to prevent concurrent sync operations

**Updated `_stopRecording()` Method**
- After session is saved locally, triggers cloud sync
- Displays "syncing to cloud..." message to user
- Handles sync in background without blocking UI

**New `_syncSessionToCloud()` Method**
- Manages sync operation lifecycle
- Shows user-friendly feedback:
  - Success: Green snackbar "Session synced to cloud successfully"
  - Failure: Orange snackbar indicating local save succeeded but cloud sync failed
  - Error: Orange snackbar with error details
- Prevents concurrent sync operations with `_isSyncing` flag
- Gracefully handles network errors

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. User starts recording (Start Training button)            │
├─────────────────────────────────────────────────────────────┤
│ 2. BLE Service collects HR data from sensors               │
├─────────────────────────────────────────────────────────────┤
│ 3. Dashboard records HR data every second                   │
├─────────────────────────────────────────────────────────────┤
│ 4. User stops recording (Stop Training button)             │
├─────────────────────────────────────────────────────────────┤
│ 5. DatabaseService.endSession()                            │
│    - Calculates stats (avg, max, min HR, calories)         │
│    - Saves to local Hive database                          │
├─────────────────────────────────────────────────────────────┤
│ 6. DashboardScreen._syncSessionToCloud()                   │
│    - Prepares session data for cloud                       │
│    - Calls SupabaseRepository.upsertTrainingSession()      │
├─────────────────────────────────────────────────────────────┤
│ 7. SupabaseRepository.upsertTrainingSession()              │
│    - Converts HR data to JSON format                       │
│    - Upserts to Supabase training_sessions table           │
│    - Sets synced = true                                    │
├─────────────────────────────────────────────────────────────┤
│ 8. DatabaseService.syncSessionToCloud()                    │
│    - Updates local session.synced = true                   │
│    - Returns success status                                │
├─────────────────────────────────────────────────────────────┤
│ 9. DashboardScreen shows sync result to user               │
└─────────────────────────────────────────────────────────────┘
```

## Sync Data Format

### Heart Rate Data (JSON Array)
```json
[
  {
    "timestamp": "2026-01-02T12:30:45.123Z",
    "heartRate": 75,
    "deviceId": "device-uuid-1"
  },
  {
    "timestamp": "2026-01-02T12:30:46.123Z",
    "heartRate": 76,
    "deviceId": "device-uuid-1"
  }
]
```

### Session in Supabase
```json
{
  "id": "session-uuid",
  "user_id": "auth-user-id",
  "person_id": "person-uuid",
  "title": "Training Session 2026-01-02 12:30",
  "training_type": "general",
  "start_time": "2026-01-02T12:30:00.000Z",
  "end_time": "2026-01-02T12:45:32.000Z",
  "duration": 892,
  "avg_heart_rate": 75,
  "max_heart_rate": 95,
  "min_heart_rate": 60,
  "calories": 150.5,
  "heart_rate_data": "[...]",
  "rr_intervals": null,
  "notes": null,
  "synced": true,
  "created_at": "2026-01-02T12:30:00.000Z",
  "updated_at": "2026-01-02T12:46:00.000Z"
}
```

## Error Handling

### Sync Failure Scenarios

**1. Network Error**
- Local session saved successfully
- User sees orange snackbar: "Session saved locally (sync failed - will retry later)"
- Session remains `synced = false` locally
- Can be retried manually or automatically

**2. Authentication Error**
- Occurs when user not logged into Supabase
- Error logged in console
- User sees error message with details
- Suggestion: User should log in first

**3. Database Constraint Error**
- Occurs if duplicate session ID
- Upsert handles this by updating existing record
- Usually transparent to user

### User Feedback

| Scenario | Message | Color | Duration |
|----------|---------|-------|----------|
| Sync Started | "Training session saved and syncing to cloud..." | Default | 2 sec |
| Sync Success | "Session synced to cloud successfully" | Green | 2 sec |
| Sync Failed | "Session saved locally (sync failed - will retry later)" | Orange | 3 sec |
| Sync Error | "Sync error: [error details]" | Orange | 3 sec |

## Offline Support

Current implementation requires network connectivity for sync. For offline-first support:

1. Sync succeeds silently if network available
2. Sync fails gracefully if offline
3. Local session marked as `synced = false`
4. Users can manually trigger bulk sync when back online

## Future Enhancements

1. **Background Sync**
   - Implement periodic sync task
   - Retry logic for failed syncs
   - Exponential backoff for retries

2. **Offline Queue**
   - Queue sessions when offline
   - Auto-sync when connection restored
   - Show sync status in UI

3. **RR Interval Sync**
   - Include HRV data in sync
   - Enable HRV analysis on backend

4. **Conflict Resolution**
   - Handle simultaneous edits
   - Merge strategies for conflicting updates

5. **Batch Operations**
   - Combine multiple session syncs
   - Reduce API calls and latency

6. **Progress Tracking**
   - Show sync progress for large sessions
   - Display upload status in real-time

## Testing Recommendations

### Unit Tests
- Test `syncSessionToCloud()` with various session states
- Mock SupabaseRepository for offline scenarios
- Verify error handling

### Integration Tests
- Connect to Supabase staging environment
- Verify session data integrity after sync
- Test concurrent sync operations

### Manual Testing
1. Start training session
2. Connect 1-2 HR sensors via BLE
3. Record for 2-3 minutes
4. Stop recording
5. Observe sync feedback messages
6. Check Supabase dashboard for new session records
7. Verify heart rate data persisted correctly

## Configuration

### Required
- Supabase project with `training_sessions` table
- User authenticated to Supabase
- Network connectivity for sync

### Optional
- Add `synced` boolean column to training_sessions table (if not exists)
- Add `rr_intervals` text column for HRV data

## API Reference

### DatabaseService.syncSessionToCloud()
```dart
Future<bool> syncSessionToCloud(
  TrainingSession session,
  SupabaseRepository supabaseRepository,
)
```
- **Returns**: `true` if sync successful, `false` otherwise

### DatabaseService.syncAllUnsyncedSessions()
```dart
Future<int> syncAllUnsyncedSessions(
  SupabaseRepository supabaseRepository,
)
```
- **Returns**: Number of sessions successfully synced

### SupabaseRepository.upsertTrainingSession()
```dart
Future<void> upsertTrainingSession({
  required String id,
  required String personId,
  required String title,
  required String trainingType,
  required DateTime startTime,
  required DateTime endTime,
  required int duration,
  required int avgHeartRate,
  required int maxHeartRate,
  required int minHeartRate,
  required double calories,
  required List<Map<String, dynamic>> heartRateData,
  String? notes,
  List<int>? rrIntervals,
})
```

## References

- [Supabase Flutter Documentation](https://supabase.io/docs/reference/flutter)
- [Hive Database Documentation](https://docs.hivedb.dev/)
- [Cloud Data Sync Patterns](https://en.wikipedia.org/wiki/Synchronization)
