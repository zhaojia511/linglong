# Mobile Emulator Setup (macOS)

This guide gives a repeatable, low-friction setup to run the Flutter app on Android Emulator (and iOS Simulator) without re-install hassles.

## One-time install

### Android (recommended for fastest loop)
1) Install Android SDK command-line tools (via Android Studio or `brew install --cask android-commandlinetools`).
2) Set env vars (add to shell profile):
```
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
```
3) Install required packages:
```
sdkmanager --install "platform-tools" "emulator" "platforms;android-34" "system-images;android-34;google_apis;x86_64" "build-tools;34.0.0"
```
4) Accept licenses:
```
sdkmanager --licenses
```
5) Create a standard AVD (Pixel 6, API 34):
```
avdmanager create avd -n Pixel_6_API_34 -k "system-images;android-34;google_apis;x86_64" -d pixel_6
```

### iOS (optional)
- Install Xcode from App Store.
- Run once to accept licenses; install Command Line Tools in Xcode preferences.
- Ensure a simulator exists (Xcode creates one by default). You can create more via Xcode > Settings > Platforms > iOS.

## Daily workflow

### Start emulator (Android)
```
emulator -avd Pixel_6_API_34 -netdelay none -netspeed full -dns-server 8.8.8.8
```
Tip: add alias `alias fe='emulator -avd Pixel_6_API_34 -dns-server 8.8.8.8'`.

### Run app with hot reload
```
flutter run -d emulator-5554  # use `flutter devices` to confirm ID
```
- Press `r` in the Flutter console for hot reload; `R` for hot restart.
- The same process reuses the installed app; no reinstall each run.

### iOS Simulator
```
open -a Simulator
flutter run -d "iPhone 15"   # or any listed by `flutter devices`
```

## Helpful commands
- List emulators: `flutter emulators`
- Create via Flutter (alternate): `flutter emulators --create --name Pixel_6_API_34`
- List devices: `flutter devices`
- Kill a stuck daemon: `flutter daemon --shutdown`
- Clean build caches (if needed): `flutter clean`

## Troubleshooting
- If `sdkmanager` not found: verify `cmdline-tools/latest/bin` in PATH.
- If emulator fails with HAXM/Hypervisor errors: ensure macOS virtualization enabled; on Apple Silicon, use ARM images (`google_apis_playstore;arm64-v8a`).
- If `emulator-5554` changes: re-run `flutter devices` and update the `-d` target.
- iOS signing errors: open `ios/Runner.xcworkspace` in Xcode and set a valid Team for development; then rerun `flutter run`.

## Why this avoids reinstall pain
- `flutter run` with a running emulator reuses the installed app and only pushes incremental code via hot reload.
- Reinstallation only occurs when the app ID or native dependencies change; hot reload/hot restart cover most Dart/UI changes.
