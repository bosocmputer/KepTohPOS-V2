#!/usr/bin/env bash
# Dual-Mode SessionStart Hook (Claude Code + Antigravity): ตรวจจับงานค้างอัตโนมัติเมื่อสลับ Agent หลังโควต้าหมด
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 0
INPUT=$(cat)

if echo "$INPUT" | grep -q '"conversationId"'; then
  MODE="antigravity"
else
  MODE="claude"
fi

CHECKPOINT=""
if [ -f ".agent-last-state.log" ]; then
  CHECKPOINT=$(cat .agent-last-state.log | tr '\n' ' ')
fi

GIT_DIRTY=""
if git --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GIT_DIRTY=$(git --no-optional-locks status --short 2>/dev/null | head -n 5 | tr '\n' '; ')
fi

if [ -n "$CHECKPOINT" ] || [ -n "$GIT_DIRTY" ]; then
  bash "$PROJECT_ROOT/.claude/hooks/telemetry-tracker.sh" --engine "$MODE" --node "core" --status "ready" --detail "🔄 Auto-Handoff Ready ($MODE): พบงานค้างพร้อมลุยต่อ" --skill "auto-resume-handoff" --hook ".claude/hooks/auto-resume.sh" >/dev/null 2>&1 || true
  MSG="[AUTO-HANDOFF READY]: พบงานที่ทำค้างไว้ในโปรเจกต์ ($CHECKPOINT $GIT_DIRTY) หากผู้ใช้สั่งงานต่อ ให้ตรวจ git diff และทำต่อจากจุดเดิมทันทีโดยไม่ต้องเริ่มใหม่"
  if [ "$MODE" = "antigravity" ]; then
    printf '{"injectSteps":[{"systemMessage":{"systemMessage":"%s"}}]}\n' "$MSG"
  else
    echo "$MSG"
  fi
else
  bash "$PROJECT_ROOT/.claude/hooks/telemetry-tracker.sh" --engine "$MODE" --node "core" --status "ready" --detail "🟢 Session Started ($MODE)" --hook ".claude/hooks/auto-resume.sh" >/dev/null 2>&1 || true
  if [ "$MODE" = "antigravity" ]; then
    printf '{}\n'
  fi
fi
exit 0
