#!/usr/bin/env bash
# Dual-Mode Hook (Claude Code + Antigravity): บล็อกการแก้ไขไฟล์ความลับ Keystore ฐานข้อมูล หรือ Lockfile โดยตรง (รองรับ JS/TS, Go, Flutter, Python, Rust)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INPUT=$(cat)

if echo "$INPUT" | grep -q '"toolCall"'; then
  MODE="antigravity"
  FILE_PATH=$(echo "$INPUT" | grep -oE '"Path"[[:space:]]*:[[:space:]]*"(\\.|[^"\\])*"' | head -1 | sed -E 's/^"Path"[[:space:]]*:[[:space:]]*"//;s/"$//;s/\\"/"/g')
else
  MODE="claude"
  FILE_PATH=$(echo "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"(\\.|[^"\\])*"' | head -1 | sed -E 's/^"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//;s/\\"/"/g')
fi

if echo "$FILE_PATH" | grep -qE '(^|/)(\.env($|\.)|.*\.(pem|key|p12|keystore|jks|sqlite|db)$|(package-lock\.json|pnpm-lock\.yaml|yarn\.lock|bun\.lockb|go\.sum|pubspec\.lock|poetry\.lock|uv\.lock|Cargo\.lock)$)'; then
  bash "$PROJECT_ROOT/.claude/hooks/telemetry-tracker.sh" --engine "$MODE" --node "core" --status "blocked" --detail "🛡️ Blocked sensitive file: $FILE_PATH" --hook ".claude/hooks/protect-sensitive-files.sh" --rule "CLAUDE.md (Secrets Guard)" >/dev/null 2>&1 || true
  if [ "$MODE" = "antigravity" ]; then
    printf '{"decision":"deny","reason":"ไม่อนุญาตให้แก้ไขไฟล์ความลับ Keystore หรือ Lockfile โดยตรง (%s)"}\n' "$FILE_PATH"
    exit 0
  else
    echo "❌ [Hook Blocked - protect-sensitive-files.sh]: ไม่อนุญาตให้แก้ไขไฟล์ความลับ Keystore หรือ Lockfile โดยตรง ($FILE_PATH)" >&2
    exit 2
  fi
fi

# 2. Anti-Test-Tampering Guard ตอนซ่อมบั๊ก (Anthropic AI-Native SDLC Playbook Stage 4 — Play 4.1)
# หากอยู่ในโหมดซ่อมบั๊ก (activeNode == debugger หรือ strikeCount >= 1) ห้ามแอบแก้ไขไฟล์เทสต์ที่มีอยู่เดิมเพื่อให้เทสต์ผ่านหลอกๆ
if [ "${ALLOW_TEST_EDIT:-0}" != "1" ] && [ -f "$PROJECT_ROOT/$FILE_PATH" -o -f "$FILE_PATH" ]; then
  if echo "$FILE_PATH" | grep -qE '(\.(test|spec)\.(ts|tsx|js|jsx|mjs|cjs)|_test\.(go|dart|py|rs)|(^|/)test_[^/]+\.py)$'; then
    TELEMETRY_FILE="$PROJECT_ROOT/.claude/.telemetry.json"
    if [ -f "$TELEMETRY_FILE" ]; then
      IS_DEBUG_FIX=$(python3 - "$TELEMETRY_FILE" <<'PYEOF' 2>/dev/null || echo "0"
import sys, json
try:
    d = json.load(open(sys.argv[1], encoding="utf-8"))
    strike = int(d.get("strikeCount", 0) or 0)
    node = str(d.get("activeNode", ""))
    print("1" if (strike >= 1 or node == "debugger") else "0")
except Exception:
    print("0")
PYEOF
)
      if [ "$IS_DEBUG_FIX" = "1" ]; then
        bash "$PROJECT_ROOT/.claude/hooks/telemetry-tracker.sh" --engine "$MODE" --node "debugger" --status "blocked" --detail "🛡️ Anti-Test-Tampering: บล็อกการแอบแก้ไฟล์เทสต์เดิม ($FILE_PATH) ระหว่างซ่อมบั๊ก" --hook ".claude/hooks/protect-sensitive-files.sh" --rule ".claude/rules/testing-and-api.md" >/dev/null 2>&1 || true
        if [ "$MODE" = "antigravity" ]; then
          printf '{"decision":"deny","reason":"ห้ามแอบแก้ไขไฟล์เทสต์ที่มีอยู่เดิม (%s) ในระหว่างซ่อมบั๊ก ให้แก้ที่โค้ดต้นเหตุเท่านั้น (Stage 4 Anti-Test-Tampering)"}\n' "$FILE_PATH"
          exit 0
        else
          echo "❌ [Hook Blocked - protect-sensitive-files.sh]: ห้ามแอบแก้ไขไฟล์เทสต์ที่มีอยู่เดิม ($FILE_PATH) ในระหว่างซ่อมบั๊ก ให้แก้ที่โค้ดต้นเหตุเท่านั้น (Stage 4 Anti-Test-Tampering)" >&2
          exit 2
        fi
      fi
    fi
  fi
fi

if [ "$MODE" = "antigravity" ]; then
  printf '{"decision":"allow"}\n'
fi
exit 0
