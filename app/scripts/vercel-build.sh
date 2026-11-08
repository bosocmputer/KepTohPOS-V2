#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v flutter >/dev/null 2>&1; then
  if [ ! -d "$HOME/flutter" ]; then
    echo "Installing Flutter SDK (stable)..."
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
  fi
  export PATH="$HOME/flutter/bin:$PATH"
fi

flutter --version
flutter config --enable-web

cd "$APP_DIR"
flutter pub get
# Mock data unless this environment explicitly opts in to the real backend.
DEFINES=()
if [ "${POS_BACKEND:-}" = "supabase" ]; then
  DEFINES+=(
    "--dart-define=POS_BACKEND=supabase"
    "--dart-define=SUPABASE_URL=${SUPABASE_URL:?SUPABASE_URL is required}"
    "--dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY is required}"
  )
fi
# Cloudflare Turnstile site key (public); empty leaves captcha off.
if [ -n "${CAPTCHA_SITE_KEY:-}" ]; then
  DEFINES+=("--dart-define=CAPTCHA_SITE_KEY=${CAPTCHA_SITE_KEY}")
  echo "Captcha: on"
else
  echo "Captcha: off (CAPTCHA_SITE_KEY not set)"
fi

flutter build web --release ${DEFINES[@]+"${DEFINES[@]}"}
bash scripts/build_sw.sh
