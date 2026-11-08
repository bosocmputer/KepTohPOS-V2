#!/usr/bin/env bash
# Dual-Mode Hook (Claude Code + Antigravity): บล็อกเมื่อ AI รันคำสั่งเทสต์หรือบิลด์เดิมซ้ำเกิน 3 ครั้งในหน้าต่าง 6 คำสั่งล่าสุด
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 0
INPUT=$(cat)

if echo "$INPUT" | grep -q '"toolCall"'; then
  MODE="antigravity"
  COMMAND=$(echo "$INPUT" | grep -oE '"CommandLine"[[:space:]]*:[[:space:]]*"(\\.|[^"\\])*"' | head -1 | sed -E 's/^"CommandLine"[[:space:]]*:[[:space:]]*"//;s/"$//;s/\\"/"/g')
  DESC=$(echo "$INPUT" | grep -oE '"toolSummary"[[:space:]]*:[[:space:]]*"(\\.|[^"\\])*"' | head -1 | sed -E 's/^"toolSummary"[[:space:]]*:[[:space:]]*"//;s/"$//;s/\\"/"/g')
else
  MODE="claude"
  COMMAND=$(echo "$INPUT" | grep -oE '"command"[[:space:]]*:[[:space:]]*"(\\.|[^"\\])*"' | head -1 | sed -E 's/^"command"[[:space:]]*:[[:space:]]*"//;s/"$//;s/\\"/"/g')
  DESC=$(echo "$INPUT" | grep -oE '"description"[[:space:]]*:[[:space:]]*"(\\.|[^"\\])*"' | head -1 | sed -E 's/^"description"[[:space:]]*:[[:space:]]*"//;s/"$//;s/\\"/"/g')
fi

allow_action() {
  if [ "$MODE" = "antigravity" ]; then
    printf '{"decision":"allow"}\n'
  fi
  exit 0
}

if [ -z "$COMMAND" ]; then
  allow_action
fi

# 1) ตรวจจับการเขียน/แก้ไขไฟล์ผ่านสคริปต์ใน Bash (เช่น open(...,'w'), p='...'; open(p,'w'), cat > path <<'EOF', sed -i)
WRITE_TARGET=""
if echo "$COMMAND" | grep -qE "(open\([^)]*,[[:space:]]*['\"]w|cat[[:space:]]*>+[[:space:]]*[^[:space:]<]+|cat[[:space:]]+<<[^>]*>[[:space:]]*[^[:space:]]+|sed[[:space:]]+-i)"; then
  WRITE_TARGET=$(echo "$COMMAND" | grep -oE "[A-Za-z0-9_./-]+\.(dart|sql|ts|tsx|js|jsx|py|go|rs|sh|md|json|yaml|yml)" | head -1)
  if [ -z "$WRITE_TARGET" ]; then
    WRITE_TARGET="source-file"
  fi
  ACTION_LBL="${DESC:-แก้ไขไฟล์จริง}"
  bash "$PROJECT_ROOT/.claude/hooks/telemetry-tracker.sh" --engine "$MODE" --node "implementer" --status "working" --file "$WRITE_TARGET" --detail "✍️ $ACTION_LBL ($WRITE_TARGET)" --hook ".claude/hooks/post-edit-format.sh" >/dev/null 2>&1 || true
fi

# 2) คำสั่งอ่าน/สแกนค้นหาข้อมูล (ห้ามมี cat > หรือ sed -i เด็ดขาด)
if [ -z "$WRITE_TARGET" ] && echo "$COMMAND" | grep -qE '^([[:space:]]*cd[[:space:]]+[^;&|]+[;&]+[[:space:]]*)*(git[[:space:]]+(status|diff|log|branch|show)|ls|pwd|cat[[:space:]]+[^><-]|head|tail|sed[[:space:]]+-n|grep|rg|find|wc|awk|stat|which|echo)[[:space:]]' && ! echo "$COMMAND" | grep -qE '(^|[;&|[:space:]])(flutter[[:space:]]+(test|analyze)|dart[[:space:]]+(test|analyze)|npm[[:space:]]+(test|run)|npx[[:space:]]+(vitest|jest|tsc|playwright)|pytest|go[[:space:]]+(test|vet|build)|cargo[[:space:]]+(test|check|clippy)|supa\.sh[[:space:]]+test)'; then
  READ_DETAIL="🔍 ${DESC:-Inspecting}: $COMMAND"
  bash "$PROJECT_ROOT/.claude/hooks/telemetry-tracker.sh" --engine "$MODE" --node "explorer" --status "working" --detail "$READ_DETAIL" --hook ".claude/hooks/loop-circuit-breaker.sh" >/dev/null 2>&1 || true
  allow_action
fi

STATE_FILE="/tmp/claude_cmd_history_$(pwd | cksum | cut -d' ' -f1).log"
# บีบอัดคำสั่งหลายบรรทัดให้เป็น 1 บรรทัดก่อนบันทึกนับลูป
ONE_LINE_CMD=$(echo "$COMMAND" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g' | cut -c1-240)
echo "$ONE_LINE_CMD" >> "$STATE_FILE"
tail -n 6 "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

REPEAT_COUNT=$(grep -Fx "$ONE_LINE_CMD" "$STATE_FILE" | wc -l | tr -d ' ')

if [ "$REPEAT_COUNT" -ge 4 ]; then
  rm -f "$STATE_FILE"
  bash "$PROJECT_ROOT/.claude/hooks/telemetry-tracker.sh" --engine "$MODE" --node "debugger" --status "blocked" --detail "🛑 Circuit Breaker Tripped (Repeat $REPEAT_COUNT): $ONE_LINE_CMD" --strike "3" --skill "root-cause-debug" --hook ".claude/hooks/loop-circuit-breaker.sh" >/dev/null 2>&1 || true
  if [ "$MODE" = "antigravity" ]; then
    printf '{"decision":"deny","reason":"🛑 [Circuit Breaker Triggered]: รันคำสั่งซ้ำเกิน 3 ครั้งแล้ว หยุดวนลูปและรายงานผู้ใช้ทันที!"}\n'
    exit 0
  else
    echo "🛑 [Circuit Breaker Triggered - loop-circuit-breaker.sh]: รันคำสั่งซ้ำเกินโควต้า (เกิน 3 ครั้งใน 6 คำสั่งล่าสุด) หยุดวนลูปและรายงานผู้ใช้ทันที!" >&2
    exit 2
  fi
elif [ "$REPEAT_COUNT" -ge 2 ]; then
  bash "$PROJECT_ROOT/.claude/hooks/telemetry-tracker.sh" --engine "$MODE" --node "debugger" --status "warning" --detail "⚠️ Repeat ($REPEAT_COUNT/3): $ONE_LINE_CMD" --strike "$((REPEAT_COUNT - 1))" --skill "root-cause-debug" --hook ".claude/hooks/loop-circuit-breaker.sh" >/dev/null 2>&1 || true
elif [ -z "$WRITE_TARGET" ]; then
  if echo "$COMMAND" | grep -qE '(^|[;&|[:space:]])(flutter[[:space:]]+(test|analyze)|dart[[:space:]]+(test|analyze)|npm[[:space:]]+(test|run[[:space:]]+(test|lint|build|check))|pnpm[[:space:]]+(test|lint|build)|yarn[[:space:]]+(test|lint|build)|npx[[:space:]]+(vitest|jest|tsc|playwright)|vitest|jest|pytest|go[[:space:]]+(test|vet|build)|cargo[[:space:]]+(test|check|clippy)|ruff[[:space:]]+check|mypy|golangci-lint|[^\n;&]*supa\.sh[[:space:]]+test|[^\n;&]*pgtap)'; then
    VERIFY_LBL="${DESC:-Verifying}"
    bash "$PROJECT_ROOT/.claude/hooks/telemetry-tracker.sh" --engine "$MODE" --node "reviewer" --status "working" --detail "🧪 $VERIFY_LBL: $COMMAND" --strike "0" --skill "verification-before-completion" --hook ".claude/hooks/loop-circuit-breaker.sh" >/dev/null 2>&1 || true
  else
    BASH_LBL="${DESC:-Bash}"
    bash "$PROJECT_ROOT/.claude/hooks/telemetry-tracker.sh" --engine "$MODE" --node "core" --status "working" --detail "⚡ $BASH_LBL: $COMMAND" --strike "0" --hook ".claude/hooks/loop-circuit-breaker.sh" >/dev/null 2>&1 || true
  fi
fi

allow_action
