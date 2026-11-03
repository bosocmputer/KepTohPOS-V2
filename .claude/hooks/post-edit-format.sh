#!/usr/bin/env bash
# Dual-Mode Hook (Claude Code + Antigravity): จัด Format อัตโนมัติตามภาษา (JS/TS, Go, Flutter/Dart, Python, Rust) + บันทึก Auto-Checkpoint
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 0
INPUT=$(cat)

if echo "$INPUT" | grep -q '"toolCall"'; then
  MODE="antigravity"
  FILE_PATH=$(echo "$INPUT" | grep -o '"Path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"Path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
else
  MODE="claude"
  FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
fi

if [ -n "$FILE_PATH" ]; then
  echo "last_agent=$MODE | last_edited_file=$FILE_PATH | updated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" > .agent-last-state.log
fi

if [ -f "$FILE_PATH" ]; then
  if [[ "$FILE_PATH" =~ \.(ts|tsx|js|jsx|json)$ ]] && [ -f "node_modules/.bin/prettier" ]; then
    npx prettier --write "$FILE_PATH" >/dev/null 2>&1
  elif [[ "$FILE_PATH" =~ \.go$ ]] && command -v gofmt >/dev/null 2>&1; then
    gofmt -w "$FILE_PATH" >/dev/null 2>&1
  elif [[ "$FILE_PATH" =~ \.dart$ ]] && command -v dart >/dev/null 2>&1; then
    dart format "$FILE_PATH" >/dev/null 2>&1
  elif [[ "$FILE_PATH" =~ \.py$ ]] && command -v ruff >/dev/null 2>&1; then
    ruff format "$FILE_PATH" >/dev/null 2>&1
  elif [[ "$FILE_PATH" =~ \.rs$ ]] && command -v rustfmt >/dev/null 2>&1; then
    rustfmt "$FILE_PATH" >/dev/null 2>&1
  fi
fi

if [ "$MODE" = "antigravity" ]; then
  printf '{}\n'
fi
exit 0
