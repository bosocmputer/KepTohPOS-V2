#!/usr/bin/env bash
# Fills build/web/sw.js with this build's id and the files to keep offline.
# Run after `flutter build web` from the app directory.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../build/web"
build_id="${VERCEL_GIT_COMMIT_SHA:-$(date +%s)}"
assets=$(find . -type f ! -name '*.symbols' ! -name 'sw.js' \
  ! -path './canvaskit/skwasm*' ! -name '.last_build_id' |
  sed 's|^\./||' | LC_ALL=C sort |
  awk 'BEGIN{ORS=""} {gsub(/"/, "\\\""); printf "%s\"%s\"", (NR>1?",":""), $0}')
python3 - "$build_id" "$assets" <<'PY'
import sys
build_id, assets = sys.argv[1], sys.argv[2]
p = 'sw.js'
s = open(p).read()
out = []
for line in s.splitlines():
    if '__BUILD_LINE__' in line:
        line = f"const BUILD = '{build_id}';"
    elif '__ASSETS_LINE__' in line:
        line = f"let ASSETS = [{assets}];"
    out.append(line)
open(p, 'w').write('\n'.join(out) + '\n')
PY
echo "service worker: build ${build_id}, $(echo "$assets" | tr ',' '\n' | wc -l | tr -d ' ') files"
