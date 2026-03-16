# BLE Heart Rate Sensor Troubleshooting Guide

## Common Issue: Sensor Not Found After Disconnect

### Problem Description
After connecting to a heart rate sensor and then disconnecting it, the sensor may not appear in subsequent scans. This is a common BLE behavior where the device needs time to restart its advertising beacon.

### Root Cause
1. **BLE devices need time** to restart advertising after disconnect
2. **Bluetooth stack caching** - OS may still consider device "connected"
3. **Scan state not properly reset** between operations
4. **Incomplete cleanup** of BLE subscriptions and connections

### Solution (Fixed in v1.0.0+)
The app now properly handles disconnection and scanning:

#### Automatic Fixes
- **500ms delay** after disconnect to allow device to restart advertising
- **Proper subscription cleanup** before disconnecting
- **Scan state reset** - stops old scans before starting new ones
- **300ms Bluetooth stack reset delay** before new scan
- **Device state reset** (heart rate, RR intervals cleared)

#### User Steps
1. **Scan** for sensors using the scan button
2. **Connect** to your heart rate sensor
3. **Use** the sensor during training
4. **Disconnect** from the sensor when done
5. **Wait 1-2 seconds** before scanning again
6. **Scan again** - the sensor should now appear in the list

### Best Practices

#### For Best Results
- Wait at least **2 seconds** after disconnecting before scanning
- If sensor still doesn't appear, try:
  - Move closer to the sensor (within 5 meters)
  - Check that sensor is powered on and advertising (LED should blink)
  - Toggle Bluetooth OFF/ON on your phone
  - Restart the sensor device

#### Known Limitations
- **Multiple rapid scans** may overwhelm the Bluetooth stack
- **Very old BLE devices** may take longer to restart advertising (3-5 seconds)
- **Low battery** in sensor can cause delayed advertising

### Technical Details

#### BLE Connection Lifecycle
```
[Advertising] → [Scan] → [Connect] → [Discover Services] → [Subscribe to Notifications]
     ↑                                                              ↓
     └─────────── [Disconnect + Cleanup] ← [Unsubscribe] ←────────┘
```

#### Cleanup Sequence on Disconnect
1. Cancel heart rate notification subscription
2. Cancel connection state subscription  
3. Disconnect from BLE device
4. Wait 500ms for device to reset
5. Clear device state (heart rate, RR intervals)
6. Remove from connected devices list
7. Update persistent storage

#### Scan Sequence
1. Stop any existing scan
2. Cancel old scan subscriptions
3. Wait 300ms for Bluetooth stack reset
4. Clear old discovered devices
5. Start new scan with Heart Rate Service filter (UUID: 180D)
6. Listen for scan results for 15 seconds
7. Auto-stop scan after timeout

### Error Messages

| Error | Meaning | Solution |
|-------|---------|----------|
| "Bluetooth permissions not granted" | App needs Bluetooth permissions | Enable in Settings → Apps → Linglong → Permissions |
| "Bluetooth is disabled" | Bluetooth is turned off | Enable Bluetooth in device settings |
| "Failed to scan" | Scan operation failed | Try restarting Bluetooth or the app |
| Device shows as "Unknown Device" | Device name not advertising | This is normal, connect and it will show proper name |

### Debugging Tips

#### Enable Debug Logging
1. Connect device to computer
2. Run: `adb logcat | grep flutter`
3. Look for messages like:
   - "Discovered device: [ID]"
   - "Disconnected from device: [ID]"
   - "Subscribed to heart rate notifications"

#### Force Disconnect All Devices
If devices are stuck in connected state:
1. Go to Profile → Sync Settings
2. Use "Disconnect All" option (if available)
3. Or restart the app
4. Or toggle Bluetooth OFF/ON on phone

### Updates & Changelog

#### v1.0.0 (January 2026)
- ✅ Fixed: Sensors not appearing after disconnect
- ✅ Added: Proper cleanup sequence on disconnect
- ✅ Added: Scan state reset before new scan
- ✅ Added: Delays for BLE stack reset
- ✅ Improved: Debug logging for troubleshooting

---

**Need Help?** Check the main documentation at `/docs/` or report issues on GitHub.
