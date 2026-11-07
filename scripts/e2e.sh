#!/usr/bin/env bash
# Runs the browser end-to-end tests against the local Supabase stack.
# Needs: `supabase start` already running and chromedriver on PATH.
# Usage: scripts/e2e.sh [integration_test/<file>_test.dart ...]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

eval "$(supabase status -o env | grep -E '^(API_URL|ANON_KEY)=')"
: "${API_URL:?supabase is not running}"

chromedriver --port=4444 >/dev/null 2>&1 &
DRIVER_PID=$!
trap 'kill "$DRIVER_PID" 2>/dev/null || true' EXIT
sleep 1

cd app
TARGETS=("$@")
if [ ${#TARGETS[@]} -eq 0 ]; then
  TARGETS=(integration_test/*_test.dart)
fi

for target in "${TARGETS[@]}"; do
  echo "== $target"
  flutter drive \
    --driver=test_driver/integration_test.dart \
    --target="$target" \
    -d web-server \
    --browser-name=chrome \
    --dart-define=POS_BACKEND=supabase \
    --dart-define=SUPABASE_URL="$API_URL" \
    --dart-define=SUPABASE_ANON_KEY="$ANON_KEY"
done
