#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Change to mobile_app directory
cd "$SCRIPT_DIR/mobile_app" || exit 1

# Run flutter with all arguments passed to this script
flutter "$@"
