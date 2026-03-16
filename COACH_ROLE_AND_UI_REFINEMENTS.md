# Coach Role & Sensor Assignment + UI Refinements

## Overview
Enhanced the mobile app with coach user role, sensor-athlete assignment tracking, and refined the dashboard UI for a more compact, athlete-focused display.

## Changes Made

### 1. Person Model Enhancement (`lib/models/person.dart`)

**New Fields:**
- `role`: String field (default: 'athlete') - Supports 'athlete' or 'coach' roles
- `assignedSensorIds`: List<String> - Tracks which BLE sensors are assigned to this athlete

**New Methods:**
```dart
/// Check if a sensor is assigned to this athlete
bool hasSensorAssigned(String sensorId)

/// Assign a sensor to this athlete
void assignSensor(String sensorId)

/// Remove a sensor assignment
void removeSensor(String sensorId)
```

**Data Structure:**
```dart
Person(
  id: "athlete-1",
  name: "John",
  role: "athlete",  // New: role field
  assignedSensorIds: ["device-uuid-1"],  // New: sensor tracking
  ...
)
```

**JSON Format:**
```json
{
  "id": "athlete-1",
  "name": "John",
  "role": "athlete",
  "assignedSensorIds": ["device-uuid-1", "device-uuid-2"],
  ...
}
```

---

### 2. Dashboard UI Refinements (`lib/screens/dashboard_screen.dart`)

#### **AppBar - Narrower & Compact**
- **Before:** Full "Team Heart Rate Monitor" title, 56px default height
- **After:** "HR Monitor" (16px font), custom 48px height
- Bluetooth icon reduced to 20px size
- More space for content below

#### **Overview Card - Horizontal Layout**
- **Before:** Vertical card with centered text
- **After:** Horizontal card with "Connected" count on left, device icon on right
- More compact: 8px vertical padding
- Clear at-a-glance device count

#### **Device Cards Grid - 3 Column Layout**
- **Before:** 2 columns, 12px spacing, 1:1 aspect ratio
- **After:** 3 columns, 8px spacing, 0.95 aspect ratio
- ~40% smaller display area per card
- More athletes visible on screen

#### **Device Card Content - Minimal Display**
- **Before:** 
  - Full member number label
  - Device name
  - Battery percentage + icon
  - Stats box (Avg/Max/Min) when recording
  - HRV data implied

- **After:**
  - Compact member avatar (radius 16 instead of 20)
  - HR display only (18px font instead of 24px)
  - "M#" label (e.g., "M1", "M2" instead of "Member 1")
  - Battery percentage only (no icon)
  - **NO stats display when recording** (removed HRV/Avg/Max/Min)
  - **NO device name display**

#### **Code Removed:**
- `_buildTinyStatBox()` - unused stat display
- `_calculateAverage()` - no longer needed
- `_calculateMax()` - no longer needed
- `_calculateMin()` - no longer needed

---

## Visual Comparison

### Before Layout
```
┌─────────────────────────────────────────┐
│ Team Heart Rate Monitor           [⚡]  │ (56px height)
├─────────────────────────────────────────┤
│ Team Overview                           │
│ 2 Devices Connected                     │
├─────────────────────────────────────────┤
│  ┌──────────┬──────────┐                │
│  │ Member 1 │ Member 2 │                │
│  │  HR 75   │  HR 82   │  (2-col grid) │
│  │  Device: │  Device: │                │
│  │  Battery │  Battery │                │
│  └──────────┴──────────┘                │
└─────────────────────────────────────────┘
```

### After Layout
```
┌──────────────────────────┐
│ HR Monitor          [⚡] │ (48px height)
├──────────────────────────┤
│ Connected | 3            │ (compact)
│         [🔧]             │
├──────────────────────────┤
│ ┌──┬──┬──┐               │
│ │M1│M2│M3│               │
│ │75│82│71│  (3-col)      │
│ │ %│ %│ %│               │
│ └──┴──┴──┘               │
└──────────────────────────┘
```

---

## UI Specifications

### AppBar
- **Title:** "HR Monitor" (16px)
- **Height:** 48px (was 56px)
- **Icon Size:** 20px (was default 24px)

### Overview Card
- **Layout:** Horizontal (Row) instead of vertical (Column)
- **Padding:** 12px horizontal, 8px vertical
- **Text:** "Connected" label + large number display

### Device Cards Grid
- **Columns:** 3 (was 2)
- **Spacing:** 8px (was 12px)
- **Aspect Ratio:** 0.95 (was 1.0)
- **Card Height:** ~5-10% smaller per card

### Device Card Content
- **Avatar Radius:** 16px (was 20px)
- **Member Label:** "M#" (was "Member #")
- **HR Font:** 18px (was 24px)
- **HR Box Padding:** 6px (was 10px)
- **Device Info:** Battery only (removed device name)
- **Stats:** Removed entirely

---

## Sensor Assignment Use Cases

### Coach Perspective (Future)
```dart
// Coach can see all team members and their assigned sensors
final athletes = dbService.getAllPersons();
for (var athlete in athletes) {
  if (athlete.role == 'athlete') {
    print('${athlete.name}: ${athlete.assignedSensorIds}');
  }
}
```

### Athlete Perspective
```dart
// Athlete profile knows which sensors are theirs
if (currentPerson.role == 'athlete') {
  final assignedSensors = currentPerson.assignedSensorIds;
  // Only show these sensors in UI
}
```

### Sensor Connection
```dart
// When connecting a sensor, optionally assign to athlete
final device = bleService.discoveredDevices[0];
currentPerson.assignSensor(device.id);
await dbService.updatePerson(currentPerson);
```

---

## Data Sync to Supabase

When syncing to cloud, athlete role and sensor assignments are included:

```json
{
  "id": "person-1",
  "name": "John",
  "role": "athlete",
  "assignedSensorIds": ["device-1", "device-2"],
  ...
}
```

This enables backend analysis to:
- Track which sensors belong to which athlete
- Validate session data against assigned sensors
- Generate athlete-specific analytics

---

## Future Enhancements

1. **Coach Role UI**
   - Separate coach login screen
   - Coach dashboard showing all athletes
   - Sensor assignment UI for coaches

2. **Sensor Management**
   - UI to manage sensor assignments
   - Rename/calibrate sensors
   - Track sensor battery history

3. **Role-Based Filtering**
   - Show only athlete's assigned sensors when athlete logged in
   - Show all team sensors when coach logged in

4. **Multi-Device Support**
   - Allow athletes to switch between multiple sensors
   - Sensor switching in UI

5. **Historical Tracking**
   - Track when sensors were assigned/unassigned
   - Audit trail for sensor management

---

## Testing

### Manual Testing
1. Create person with role = 'athlete'
2. Connect BLE sensor and assign: `person.assignSensor(device.id)`
3. Save person to local database
4. Verify card displays compactly (3 columns visible)
5. Verify HR only (no stats, no device name)
6. Sync to Supabase and check JSON includes role and assignedSensorIds

### Key Verification Points
- ✅ AppBar height reduced to 48px
- ✅ Overview card horizontal layout
- ✅ Grid shows 3 columns in landscape, still readable
- ✅ No HRV/stats displayed on cards
- ✅ Device name hidden
- ✅ Role field persists through local/cloud sync
- ✅ assignedSensorIds list tracked correctly

---

## Files Modified
1. [mobile_app/lib/models/person.dart](mobile_app/lib/models/person.dart)
2. [mobile_app/lib/screens/dashboard_screen.dart](mobile_app/lib/screens/dashboard_screen.dart)

## Backward Compatibility
- Existing Person records without role/assignedSensorIds will default to:
  - `role = 'athlete'`
  - `assignedSensorIds = []`
- No migration needed for local Hive data
- Cloud sync will add new fields automatically
