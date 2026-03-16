# Sensor-Athlete Linking System

## Overview
The Linglong app now supports linking BLE heart rate sensors to specific athletes, enabling coaches to monitor multiple team members simultaneously with clear identification of who each sensor belongs to.

## How It Works

### 1. Data Model

**Person Model** (`models/person.dart`):
- Each athlete has an `assignedSensorIds` list (List<String>) that stores BLE device IDs
- Methods available:
  - `hasSensorAssigned(String sensorId)` - Check if athlete has a sensor
  - `assignSensor(String sensorId)` - Add sensor assignment
  - `removeSensor(String sensorId)` - Remove sensor assignment

**Training Session Model** (`models/training_session.dart`):
- Each `HeartRateData` point includes a `deviceId` field
- This creates a complete audit trail: which sensor recorded which data point

### 2. Assignment Flow

#### Step 1: Assign Sensor to Athlete
1. **Tap on any sensor card** on the dashboard
2. A dialog appears showing:
   - Current sensor name
   - Currently assigned athlete (if any)
   - List of all athletes in the team
3. **Select an athlete** from the list to assign
4. The assignment is saved immediately

#### Step 2: Visual Feedback
- **Assigned sensors** display the athlete's name at the top of the card (blue text)
- **Unassigned sensors** show "Tap to assign" (gray text)
- The athlete's name replaces the generic "M1", "M2" labels

#### Step 3: Reassignment & Unassignment
- A sensor can only be assigned to ONE athlete at a time
- Reassigning automatically removes it from the previous athlete
- Use the "Unassign" button to remove assignment without reassigning

### 3. Database Methods

**DatabaseService** (`services/database_service.dart`):

```dart
// Assign a sensor to an athlete (exclusive - removes from others)
assignSensorToAthlete(String sensorId, String athleteId)

// Remove sensor from any athlete
unassignSensor(String sensorId)

// Find which athlete has this sensor
Person? getAthleteForSensor(String sensorId)

// Get all athletes (excluding coaches)
List<Person> getAthletes()
```

### 4. Training Session Recording

When recording a training session:
- Each heart rate data point includes the `deviceId`
- You can later query which athlete's sensor recorded which data
- All connected sensors are recorded simultaneously
- The session belongs to the "current person" but includes multi-device data

### 5. Data Analysis Benefits

With sensor-athlete linking, you can:
- **Identify performance by athlete**: Filter session data by deviceId to see individual athlete metrics
- **Compare team members**: Analyze multiple athletes in the same session
- **Track equipment usage**: See which sensors are assigned to which athletes
- **Audit trail**: Complete history of sensor assignments and data attribution

## User Workflow Examples

### Scenario 1: Coach with 3 Athletes
1. Add 3 athlete profiles in "Team Members" tab
2. Connect 3 HR sensors via Bluetooth
3. Tap each sensor card and assign to corresponding athlete
4. Dashboard now shows: "John Doe", "Jane Smith", "Bob Lee" on sensor cards
5. Start training - all 3 sensors record with proper attribution

### Scenario 2: Reassigning Sensors
1. Athlete "John" is sick, "Sarah" joins instead
2. Add Sarah's profile in Team Members
3. Tap sensor showing "John Doe"
4. Select "Sarah Johnson" from athlete list
5. Sensor card now shows "Sarah Johnson"
6. John's sensor ID is automatically removed from his profile

### Scenario 3: Analyzing Past Sessions
1. Open a past training session
2. Each HR data point has a `deviceId`
3. Match `deviceId` to athlete via `assignedSensorIds`
4. Generate per-athlete reports and comparisons

## Technical Implementation

### UI Components
- **Dashboard**: Sensor cards show athlete names, tap to assign
- **Assignment Dialog**: Lists all athletes with avatars and details
- **Visual States**: 
  - Assigned: Blue bold text with athlete name
  - Unassigned: Gray text "Tap to assign"
  - Current assignment shown at top of dialog

### Data Persistence
- Assignments stored in Hive local database
- Synced to Supabase with person records
- Session data includes deviceId for each HR measurement
- No data loss on app restart

### Edge Cases Handled
- ✅ Sensor assigned to non-existent athlete: Returns null, shows unassigned
- ✅ Multiple athletes with same name: Uses unique athlete IDs
- ✅ Sensor disconnects then reconnects: Assignment persists via device ID
- ✅ No athletes created yet: Dialog shows helpful message
- ✅ Reassignment: Automatically removes from previous athlete

## Future Enhancements

Potential improvements:
- Bulk assignment mode (drag-drop sensors to athletes)
- Auto-assignment based on sensor proximity/RSSI
- Assignment history/audit log
- Sensor preference per athlete (remember favorite sensors)
- Warning when assigned sensor is not connected
- Color-coding sensors to match athlete avatars

## API Reference

### Key Methods

```dart
// In DatabaseService
await DatabaseService.instance.assignSensorToAthlete(deviceId, athleteId);
await DatabaseService.instance.unassignSensor(deviceId);
Person? athlete = DatabaseService.instance.getAthleteForSensor(deviceId);
List<Person> athletes = DatabaseService.instance.getAthletes();

// In Person Model
if (athlete.hasSensorAssigned(sensorId)) { ... }
athlete.assignSensor(sensorId);
athlete.removeSensor(sensorId);

// In Training Session
for (var hrData in session.heartRateData) {
  print('Device: ${hrData.deviceId}, HR: ${hrData.heartRate}');
  var athlete = DatabaseService.instance.getAthleteForSensor(hrData.deviceId);
  if (athlete != null) {
    print('Athlete: ${athlete.name}');
  }
}
```

## Summary

The sensor-athlete linking system provides:
- **Clear identification**: Know which sensor belongs to which athlete
- **Easy management**: Tap to assign, one-click reassignment
- **Complete data trail**: Every HR measurement includes device attribution
- **Scalable**: Works with up to 10 simultaneous sensors
- **Persistent**: Assignments saved across app restarts
- **Flexible**: Easy reassignment for different training scenarios

This enables coaches to effectively monitor and analyze team performance with professional-grade data attribution.
