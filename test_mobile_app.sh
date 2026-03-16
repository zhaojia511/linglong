#!/bin/bash

# Linglong Mobile App Test Procedure
# This script provides a reliable way to test the app without constant reinstalls

echo "=== Linglong Mobile App Test Procedure ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

cd /Users/zhaojia/linglong/mobile_app

echo -e "${YELLOW}Step 1: Cleaning previous build...${NC}"
flutter clean

echo -e "${YELLOW}Step 2: Getting dependencies...${NC}"
flutter pub get

echo -e "${YELLOW}Step 3: Building iOS app...${NC}"
flutter build ios --debug

if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed! Check the errors above.${NC}"
    exit 1
fi

echo -e "${GREEN}Build successful!${NC}"
echo ""
echo -e "${YELLOW}Step 4: Starting app with hot reload...${NC}"
echo "This will install the app on your iPhone and enable hot reload."
echo "Make sure your iPhone is connected and trusted."
echo ""
echo "Commands you can use after startup:"
echo "  r - Hot reload (fast updates)"
echo "  R - Hot restart (restarts the app)"
echo "  h - Show help"
echo "  q - Quit"
echo ""
echo "If the app crashes, check the error screen or device logs."
echo ""

flutter run --debug --hot