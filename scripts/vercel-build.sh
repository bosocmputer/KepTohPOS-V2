#!/usr/bin/env bash
# Vercel's Root Directory is "app", so it runs app/scripts/vercel-build.sh.
# This wrapper keeps one build script for a repository-root setup too.
set -euo pipefail
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/app/scripts/vercel-build.sh"
