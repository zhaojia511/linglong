#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_REMOTE_URL="${TARGET_REMOTE_URL:-https://github.com/zhaojia511/linglong.git}"
TARGET_BRANCH="${1:-copilot/build-heartrate-sensor-app}"
EXPECTED_COMMIT="${2:-}"
ALLOW_DIRTY="${ALLOW_DIRTY:-0}"

cd "$ROOT_DIR"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not inside a git repository: $ROOT_DIR" >&2
  exit 1
fi

if [[ "$ALLOW_DIRTY" != "1" ]] && [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is not clean. Commit or stash changes first, or rerun with ALLOW_DIRTY=1." >&2
  exit 1
fi

CURRENT_REMOTE_URL="$(git remote get-url origin)"
if [[ "$CURRENT_REMOTE_URL" != "$TARGET_REMOTE_URL" ]]; then
  echo "Updating origin URL"
  echo "  from: $CURRENT_REMOTE_URL"
  echo "  to:   $TARGET_REMOTE_URL"
  git remote set-url origin "$TARGET_REMOTE_URL"
else
  echo "Origin URL already matches target"
fi

echo "Fetching latest refs from origin..."
git fetch origin --prune

if git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
  echo "Switching to existing local branch: $TARGET_BRANCH"
  git checkout "$TARGET_BRANCH"
else
  echo "Creating local tracking branch: $TARGET_BRANCH"
  git checkout -b "$TARGET_BRANCH" --track "origin/$TARGET_BRANCH"
fi

echo "Ensuring upstream is origin/$TARGET_BRANCH"
git branch --set-upstream-to="origin/$TARGET_BRANCH" "$TARGET_BRANCH" >/dev/null

echo "Fast-forwarding local branch..."
git pull --ff-only origin "$TARGET_BRANCH"

if [[ -n "$EXPECTED_COMMIT" ]]; then
  if git merge-base --is-ancestor "$EXPECTED_COMMIT" HEAD; then
    echo "Verified expected commit is present: $EXPECTED_COMMIT"
  else
    echo "Expected commit is not present on current branch: $EXPECTED_COMMIT" >&2
    exit 1
  fi
fi

echo
echo "Sync complete"
echo "  remote: $(git remote get-url origin)"
echo "  branch: $(git branch --show-current)"
echo "  head:   $(git rev-parse --short HEAD)"
