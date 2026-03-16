#!/usr/bin/env bash
set -euo pipefail

# Android emulator one-time setup (macOS)
# Usage: bash tools/setup_android_emulator.sh
# - Installs SDK components (API 34 x86_64 image by default)
# - Creates an AVD named Pixel_6_API_34 if missing
# Note: For Apple Silicon, see the variables in the CONFIG section below.

# CONFIG
SDK_ROOT="$HOME/Library/Android/sdk"
API_LEVEL=34
IMAGE_FLAVOR="google_apis"
IMAGE_ABI="x86_64"           # On Apple Silicon, set IMAGE_ABI="arm64-v8a" and update build-tools to 35.x/arm image
BUILD_TOOLS_VERSION="34.0.0" # Apple Silicon + API35: set to 35.0.0 if installed
AVD_NAME="Pixel_6_API_${API_LEVEL}"
DEVICE_DEF="pixel_6"

set -x

# Ensure directories
mkdir -p "$SDK_ROOT"

# Export PATH for this script run (add to shell profile separately)
export ANDROID_HOME="$SDK_ROOT"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

# Ensure cmdline-tools are present
if [ ! -d "$ANDROID_HOME/cmdline-tools/latest" ]; then
  echo "cmdline-tools 'latest' not found. Install via Android Studio or brew:"
  echo "  brew install --cask android-commandlinetools"
  exit 1
fi

# Install required packages
sdkmanager --install \
  "platform-tools" \
  "emulator" \
  "platforms;android-${API_LEVEL}" \
  "system-images;android-${API_LEVEL};${IMAGE_FLAVOR};${IMAGE_ABI}" \
  "build-tools;${BUILD_TOOLS_VERSION}"

# Accept licenses
yes | sdkmanager --licenses > /dev/null

# Create AVD if missing
if avdmanager list avd | grep -q "Name: ${AVD_NAME}"; then
  echo "AVD ${AVD_NAME} already exists.";
else
  avdmanager create avd -n "${AVD_NAME}" -k "system-images;android-${API_LEVEL};${IMAGE_FLAVOR};${IMAGE_ABI}" -d "${DEVICE_DEF}" --force
  echo "Created AVD ${AVD_NAME}."
fi

echo "\nDone. To run the emulator:"
echo "  emulator -avd ${AVD_NAME} -dns-server 8.8.8.8"
echo "Then run the app with hot reload:" 
echo "  flutter devices   # find emulator ID (e.g., emulator-5554)" 
echo "  flutter run -d emulator-5554"
