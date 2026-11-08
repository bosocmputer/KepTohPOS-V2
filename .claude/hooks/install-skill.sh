#!/usr/bin/env bash
# Dual-Engine Sparse Skill Installer (Claude Code .claude/skills + Antigravity IDE .agents/skills)
# รองรับการดึง Skill อัตโนมัติจาก 3 คลังมาตรฐาน:
#   1. anthropics/skills (19 Official Anthropic Skills: frontend-design, webapp-testing, mcp-builder, claude-api, skill-creator, docx, pdf, pptx, xlsx, ฯลฯ)
#   2. jeffallan/claude-skills (67 Tech Stack Skills: react-expert, nestjs-expert, golang-pro, flutter-expert, ฯลฯ)
#   3. heydamir/unslop (unslop UI audit skill)
set -e
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

if [ "$#" -eq 0 ]; then
  echo "Usage: bash .claude/hooks/install-skill.sh <skill-name> [skill-name-2 ...]"
  echo "Examples:"
  echo "  • Official Anthropic Skills : bash .claude/hooks/install-skill.sh frontend-design webapp-testing mcp-builder pdf xlsx"
  echo "  • Framework/Stack Skills    : bash .claude/hooks/install-skill.sh react-expert nestjs-expert golang-pro"
  echo "  • UI Anti-Slop Audit Skill  : bash .claude/hooks/install-skill.sh unslop"
  exit 1
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p .claude/skills .agents/skills

ANTHROPIC_OFFICIAL_LIST="academy-guide algorithmic-art brand-guidelines canvas-design claude-api discernment-nudge doc-coauthoring docx frontend-design internal-comms mcp-builder pdf pptx skill-creator slack-gif-creator theme-factory web-artifacts-builder webapp-testing xlsx"

is_anthropic_skill() {
  local target="$1"
  for item in $ANTHROPIC_OFFICIAL_LIST; do
    if [ "$item" = "$target" ]; then
      return 0
    fi
  done
  return 1
}

ANTHROPIC_SKILLS=()
JEFFALLAN_SKILLS=()
INSTALL_UNSLOP=0

for SKILL in "$@"; do
  CLEAN_SKILL="${SKILL#anthropics/}"
  CLEAN_SKILL="${CLEAN_SKILL#jeffallan/}"
  if [ "$CLEAN_SKILL" = "unslop" ]; then
    INSTALL_UNSLOP=1
  elif is_anthropic_skill "$CLEAN_SKILL"; then
    ANTHROPIC_SKILLS+=("$CLEAN_SKILL")
  else
    JEFFALLAN_SKILLS+=("$CLEAN_SKILL")
  fi
done

if [ "$INSTALL_UNSLOP" -eq 1 ]; then
  echo "🎨 Fetching 'unslop' UI skill from github.com/heydamir/unslop..."
  git clone --depth 1 https://github.com/heydamir/unslop.git "$TMP_DIR/unslop" >/dev/null 2>&1
  if [ -d "$TMP_DIR/unslop/skills/unslop" ]; then
    rm -rf ".claude/skills/unslop" ".agents/skills/unslop"
    cp -R "$TMP_DIR/unslop/skills/unslop" ".claude/skills/unslop"
    cp -R "$TMP_DIR/unslop/skills/unslop" ".agents/skills/unslop"
    echo "✅ Installed 'unslop' into both .claude/skills/unslop and .agents/skills/unslop"
  elif [ -f "$TMP_DIR/unslop/SKILL.md" ]; then
    mkdir -p ".claude/skills/unslop" ".agents/skills/unslop"
    cp -R "$TMP_DIR/unslop/"* ".claude/skills/unslop/"
    cp -R "$TMP_DIR/unslop/"* ".agents/skills/unslop/"
    echo "✅ Installed 'unslop' into both .claude/skills/unslop and .agents/skills/unslop"
  fi
fi

if [ "${#ANTHROPIC_SKILLS[@]}" -gt 0 ]; then
  echo "🏛️ Fetching Official Anthropic skill(s) from github.com/anthropics/skills..."
  git clone --depth 1 --filter=blob:none --sparse https://github.com/anthropics/skills.git "$TMP_DIR/anthropic-repo" >/dev/null 2>&1

  cd "$TMP_DIR/anthropic-repo"
  SPARSE_PATHS=()
  for SKILL in "${ANTHROPIC_SKILLS[@]}"; do
    SPARSE_PATHS+=("skills/$SKILL")
  done
  git sparse-checkout set "${SPARSE_PATHS[@]}" >/dev/null 2>&1
  cd "$PROJECT_ROOT" >/dev/null

  for SKILL in "${ANTHROPIC_SKILLS[@]}"; do
    if [ -d "$TMP_DIR/anthropic-repo/skills/$SKILL" ]; then
      rm -rf ".claude/skills/$SKILL" ".agents/skills/$SKILL"
      cp -R "$TMP_DIR/anthropic-repo/skills/$SKILL" ".claude/skills/$SKILL"
      cp -R "$TMP_DIR/anthropic-repo/skills/$SKILL" ".agents/skills/$SKILL"
      echo "✅ Installed official Anthropic skill '$SKILL' into both .claude/skills/$SKILL and .agents/skills/$SKILL"
    else
      echo "⚠️ Skill '$SKILL' not found in anthropics/skills/skills/" >&2
    fi
  done
fi

if [ "${#JEFFALLAN_SKILLS[@]}" -gt 0 ]; then
  echo "📦 Fetching tech-stack skill(s) from github.com/jeffallan/claude-skills..."
  git clone --depth 1 --filter=blob:none --sparse https://github.com/jeffallan/claude-skills.git "$TMP_DIR/jeffallan-repo" >/dev/null 2>&1

  cd "$TMP_DIR/jeffallan-repo"
  SPARSE_PATHS=()
  for SKILL in "${JEFFALLAN_SKILLS[@]}"; do
    SPARSE_PATHS+=("skills/$SKILL")
  done
  git sparse-checkout set "${SPARSE_PATHS[@]}" >/dev/null 2>&1
  cd "$PROJECT_ROOT" >/dev/null

  for SKILL in "${JEFFALLAN_SKILLS[@]}"; do
    if [ -d "$TMP_DIR/jeffallan-repo/skills/$SKILL" ]; then
      rm -rf ".claude/skills/$SKILL" ".agents/skills/$SKILL"
      cp -R "$TMP_DIR/jeffallan-repo/skills/$SKILL" ".claude/skills/$SKILL"
      cp -R "$TMP_DIR/jeffallan-repo/skills/$SKILL" ".agents/skills/$SKILL"
      echo "✅ Installed '$SKILL' into both .claude/skills/$SKILL and .agents/skills/$SKILL"
    else
      echo "⚠️ Skill '$SKILL' not found in jeffallan/claude-skills/skills/ or anthropics/skills/skills/" >&2
    fi
  done
fi

# อัปเดตผังไฟล์สดใน .claude/.telemetry.json เพื่อให้หน้าจอ 3D Voxel Studio เห็นการ์ดใบใหม่ทันที
if [ -x "$PROJECT_ROOT/.claude/hooks/telemetry-tracker.sh" ]; then
  bash "$PROJECT_ROOT/.claude/hooks/telemetry-tracker.sh" \
    --engine "claude" \
    --node "explorer" \
    --status "working" \
    --skill "tech-stack-skills" \
    --hook ".claude/hooks/install-skill.sh" \
    --detail "📦 ติดตั้ง Skill เสริม ($*) ลงทั้ง .claude/skills/ และ .agents/skills/ สำเร็จ" >/dev/null 2>&1 || true
fi
