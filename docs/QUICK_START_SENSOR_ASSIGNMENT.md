# Quick Start: Sensor-Athlete Assignment

## Setup (One Time)

### 1. Add Athletes
1. Go to **Team Members** tab (bottom navigation)
2. Tap **➕** button
3. Enter athlete details:
   - Name
   - Age
   - Gender
   - Weight/Height
4. Save
5. Repeat for each athlete

### 2. Connect Sensors
1. Go to **Dashboard** tab
2. Tap **Bluetooth** icon (top right)
3. Wait for scan to complete
4. Tap **Connect** on each sensor
5. Wait for "Connected" status

## Assign Sensors to Athletes

### Method 1: Tap the Sensor Card
1. On Dashboard, tap any connected sensor card
2. Assignment dialog appears showing:
   - Sensor name
   - Current assignment (if any)
   - List of all athletes
3. Tap the athlete's name to assign
4. Sensor card immediately updates to show athlete name

### Method 2: Reassign a Sensor
1. Tap an already-assigned sensor card
2. Dialog shows current athlete highlighted with ✓
3. Tap a different athlete to reassign
4. Sensor automatically removed from previous athlete

### Method 3: Unassign a Sensor
1. Tap an assigned sensor card
2. Tap **Unassign** button (red text, bottom left)
3. Sensor card reverts to "Tap to assign"

## Visual Indicators

### Sensor Cards on Dashboard

**Unassigned Sensor:**
```
┌─────────────────┐
│ Tap to assign   │  ← Gray text
│                 │
│    ❤ 72        │  ← Current heart rate
│    bpm         │
│                 │
│ HRM-508  🔋96% │  ← Device name & battery
└─────────────────┘
```

**Assigned Sensor:**
```
┌─────────────────┐
│ John Doe        │  ← Blue bold text (athlete name)
│                 │
│    ❤ 85        │  ← Current heart rate
│    bpm         │
│                 │
│ HRM-508  🔋96% │  ← Device name & battery
└─────────────────┘
```

### Assignment Dialog

```
┌──────────────────────────────────┐
│  Assign Sensor                   │
│                                  │
│  Sensor: HRM-508                 │  ← Current sensor
│  Currently assigned to: John Doe │
│                                  │
│  Assign to:                      │
│  ┌─────────────────────────────┐│
│  │ 🔵 John Doe        ✓        ││  ← Current assignment
│  │    25y, Male                ││
│  ├─────────────────────────────┤│
│  │ 🟢 Jane Smith               ││  ← Available athlete
│  │    23y, Female              ││
│  ├─────────────────────────────┤│
│  │ 🟠 Bob Lee                  ││
│  │    27y, Male                ││
│  └─────────────────────────────┘│
│                                  │
│  [ Unassign ]    [ Cancel ]     │
└──────────────────────────────────┘
```

## Use Cases

### Training Session Scenario

**Before Training:**
1. Connect 3 sensors
2. Assign:
   - HRM-508 → John Doe
   - HRM-510 → Jane Smith
   - Emulator → Bob Lee

**During Training:**
1. Tap **Start Training**
2. All 3 sensors record simultaneously
3. Each heart rate data point tagged with deviceId
4. Dashboard shows real-time data with athlete names

**After Training:**
1. Tap **Stop Training**
2. Session saved with complete attribution
3. Query data by athlete later:
   ```dart
   // Find John's data in session
   var johnsData = session.heartRateData
       .where((hr) => hr.deviceId == johnsSensorId);
   ```

### Quick Reassignment

**Athlete Substitution:**
1. Sarah replaces John mid-season
2. Tap sensor showing "John Doe"
3. Select "Sarah Johnson"
4. Done! Same sensor, new athlete

## Troubleshooting

### "No athletes found" in dialog
- **Cause**: No athletes created yet
- **Fix**: Go to Team Members → Add athletes

### Sensor shows "Tap to assign" after reconnect
- **Cause**: Device ID changed (rare)
- **Fix**: Reassign sensor to athlete

### Can't find athlete in list
- **Cause**: Person role set to "coach" not "athlete"
- **Fix**: Edit person → Change role to "athlete"

### Multiple sensors showing same name
- **Cause**: Multiple sensors assigned to same athlete (shouldn't happen)
- **Fix**: Unassign extras, reassign correctly

## Data Benefits

### Training Analysis
- **Per-Athlete Metrics**: Filter session data by athlete
- **Team Comparisons**: Compare athletes side-by-side
- **Historical Tracking**: Consistent athlete-device mapping
- **Multi-Session Analysis**: Track same athlete across sessions

### Cloud Sync
- Assignments sync to Supabase
- Preserved across devices
- Full audit trail
- No data loss

## Tips

1. **Consistent Naming**: Use real names for easy identification
2. **Label Sensors**: Physical labels match BLE names
3. **Pre-Assign**: Assign before training starts
4. **Check Battery**: Low battery? Reassign to fresh sensor
5. **Team Setup**: Create all athletes first, then assign

## Next Steps

- [ ] Add all team members
- [ ] Connect and test sensors
- [ ] Assign each sensor
- [ ] Run test training session
- [ ] Verify data attribution
- [ ] Start regular training tracking!
