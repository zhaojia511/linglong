# Linglong Mobile App Test Procedure

## Overview
This procedure provides a reliable way to test the mobile app on iPhone hardware without constant full reinstalls.

## Prerequisites
- iPhone connected via USB
- Apple Developer account with device registered
- Xcode installed and configured
- Flutter SDK installed

## Step-by-Step Test Procedure

### 1. Initial Setup (One-time)
```bash
cd /Users/zhaojia/linglong/mobile_app
flutter clean
flutter pub get
flutter build ios --debug
```

### 2. Start App with Hot Reload (For Testing)
```bash
cd /Users/zhaojia/linglong/mobile_app
flutter run --debug --hot
```

This will:
- Install the app on your iPhone
- Enable hot reload for fast code updates
- Show detailed logs in the terminal

### 3. Testing Workflow

#### When App Starts Successfully:
- App opens on iPhone
- Check console for initialization logs:
  ```
  Starting app initialization...
  Initializing Hive...
  Hive initialized successfully
  Initializing Supabase...
  Supabase initialized successfully
  Initializing DatabaseService...
  DatabaseService initialized successfully
  All initialization complete, starting app...
  ```

#### If App Crashes:
- Check the error screen on device (shows detailed error message)
- Check terminal/console for error logs
- Look for "CRITICAL ERROR during initialization" messages

#### Making Code Changes:
- Edit code in VS Code
- Save file
- In terminal running `flutter run`, press `r` for hot reload
- Or press `R` for hot restart
- Changes appear instantly on device

### 4. Common Issues & Solutions

#### Issue: App crashes immediately
**Solution**: Check the error screen for specific error message and stack trace

#### Issue: "ptrace" errors in console
**Solution**: This is normal on iOS 14+, ignore unless app doesn't start

#### Issue: "Could not call ptrace" errors
**Solution**: Normal for debug builds, app should still work

#### Issue: Long startup time
**Solution**: Wait up to 2-3 minutes for initial install, subsequent runs are faster

### 5. Quick Test Commands

```bash
# Quick rebuild and run
cd /Users/zhaojia/linglong/mobile_app
flutter run --debug --hot

# Just rebuild (if already running)
flutter build ios --debug

# Clean rebuild (if issues persist)
flutter clean && flutter pub get && flutter build ios --debug
```

### 6. Debugging Tips

- **Check Device Logs**: Use Xcode -> Window -> Devices and Simulators
- **Error Screen**: Added error display screen shows initialization failures
- **Console Logs**: All initialization steps are logged with debugPrint
- **Hot Reload**: Use `r` key during flutter run for instant updates

### 7. Expected Behavior

1. App installs on iPhone
2. Shows initialization logs in console
3. Either shows main app or error screen with details
4. Hot reload works for code changes
5. No need to reinstall for most changes

## Troubleshooting

If crashes persist:
1. Check error screen for specific error
2. Verify Supabase keys are correct
3. Check iOS permissions in Info.plist
4. Ensure device is properly registered in Apple Developer account
5. Try clean rebuild: `flutter clean && flutter pub get && flutter build ios --debug`