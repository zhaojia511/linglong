#!/usr/bin/env bash
set -euo pipefail

# Start backend and frontend dev servers and redirect logs to logs/
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT_DIR/logs"

echo "Stopping any existing dev servers..."
pkill -f vite || true
pkill -f nodemon || true

echo "Starting backend (logs/backend.log)..."
cd "$ROOT_DIR/backend"
nohup npm run dev > "$ROOT_DIR/logs/backend.log" 2>&1 &
sleep 1

echo "Starting frontend (logs/vite.log)..."
cd "$ROOT_DIR/web_app"
# Ensure dependencies exist (fast if already installed). Non-interactive install.
npm install --no-audit --no-fund >/dev/null 2>&1 || true
nohup npm run dev > "$ROOT_DIR/logs/vite.log" 2>&1 &

echo "Dev servers start requested. Tail logs with: tail -f $ROOT_DIR/logs/*.log"
