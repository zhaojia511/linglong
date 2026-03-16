#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
echo "Stopping vite, nodemon and node servers..."
pkill -f vite || true
pkill -f nodemon || true
pkill -f "node .*server.js" || true
echo "Stopped (if they were running)." 
