#!/usr/bin/env bash
set -euo pipefail

# Resolve repository root regardless of whether Vercel Root Directory is "." or "app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if ! command -v flutter >/dev/null 2>&1; then
  if [ ! -d "$HOME/flutter" ]; then
    echo "Installing Flutter SDK (stable)..."
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
  fi
  export PATH="$HOME/flutter/bin:$PATH"
fi

flutter --version
flutter config --enable-web

cd "$REPO_ROOT/app"
flutter pub get
flutter build web --release
