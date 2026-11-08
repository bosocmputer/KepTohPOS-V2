#!/usr/bin/env bash
# Dual-Mode Real-Time Telemetry Tracker & Live Workspace Scanner (Zero-Hardcode)
# สแกนไฟล์จริงจากดิสก์ (.claude/ & .agents/) + ดักจับการทำงานจริงของ Claude Code และ Antigravity ลง .claude/.telemetry.json
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 0

TELEMETRY_FILE="$PROJECT_ROOT/.claude/.telemetry.json"
mkdir -p "$PROJECT_ROOT/.claude"

MODE_TYPE="cli"
HOOK_STAGE="unknown"
RAW_STDIN=""

if [ "${1:-}" = "--hook-stdin" ]; then
  MODE_TYPE="stdin"
  HOOK_STAGE="${2:-unknown}"
  RAW_STDIN=$(cat)
  if echo "$RAW_STDIN" | grep -qE '"(conversationId|toolCall|invocationNum|executionNum)"'; then
    ENGINE="antigravity"
  else
    ENGINE="claude"
  fi
else
  ENGINE="claude"
  NODE="core"
  STATUS="working"
  DETAIL=""
  FILE_TOUCHED=""
  STRIKE=""
  MODEL_ARG=""
  SKILL_ARG=""
  CMD_ARG=""
  RULE_ARG=""
  HOOK_ARG=""
  PROMPT_ARG=""
  DIFF_ARG=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --engine)  ENGINE="${2:-claude}"; shift 2 ;;
      --node)    NODE="${2:-core}"; shift 2 ;;
      --status)  STATUS="${2:-working}"; shift 2 ;;
      --detail)  DETAIL="${2:-}"; shift 2 ;;
      --file)    FILE_TOUCHED="${2:-}"; shift 2 ;;
      --strike)  STRIKE="${2:-}"; shift 2 ;;
      --model)   MODEL_ARG="${2:-}"; shift 2 ;;
      --skill)   SKILL_ARG="${2:-}"; shift 2 ;;
      --command) CMD_ARG="${2:-}"; shift 2 ;;
      --rule)    RULE_ARG="${2:-}"; shift 2 ;;
      --hook)    HOOK_ARG="${2:-}"; shift 2 ;;
      --prompt)  PROMPT_ARG="${2:-}"; shift 2 ;;
      --diff)    DIFF_ARG="${2:-}"; shift 2 ;;
      *) shift ;;
    esac
  done
fi

if command -v python3 >/dev/null 2>&1; then
  python3 - "$PROJECT_ROOT" "$TELEMETRY_FILE" "$MODE_TYPE" "$HOOK_STAGE" "$ENGINE" "${NODE:-core}" "${STATUS:-working}" "${DETAIL:-}" "${FILE_TOUCHED:-}" "${STRIKE:-}" "${MODEL_ARG:-}" "${SKILL_ARG:-}" "${CMD_ARG:-}" "${RULE_ARG:-}" "${HOOK_ARG:-}" "${PROMPT_ARG:-}" "${DIFF_ARG:-}" "$RAW_STDIN" <<'PYEOF' 2>/dev/null || true
import sys, os, re, glob, json, time, subprocess
from datetime import datetime, timezone

(
    project_root,
    t_file,
    mode_type,
    stage,
    engine,
    node,
    status,
    detail,
    file_touched,
    strike,
    model_arg,
    skill_arg,
    cmd_arg,
    rule_arg,
    hook_arg,
    prompt_arg,
    diff_arg,
    raw_in,
) = sys.argv[1:19]

def parse_frontmatter_and_body(text):
    meta = {}
    body = text
    if text.startswith("---\n"):
        end = text.find("\n---", 4)
        if end != -1:
            fm_raw = text[4:end]
            body = text[end + 4:].lstrip()
            for line in fm_raw.splitlines():
                if ":" in line and not line.startswith(" ") and not line.startswith("-"):
                    k, v = line.split(":", 1)
                    meta[k.strip()] = v.strip().strip('"').strip("'")
    title = ""
    for line in body.splitlines():
        s = line.strip()
        if s.startswith("# "):
            title = s[2:].strip()
            break
    return meta, title, body

def infer_desk_for_file(rel_path, meta, title, text):
    low = (rel_path + " " + title + " " + str(meta.get("description", ""))).lower()
    m = str(meta.get("model", "")).lower()
    if m == "opus":
        return "core"
    if m == "haiku" or "explorer" in rel_path or "tech-stack" in rel_path:
        return "explorer"
    if "debug" in rel_path or "fix.md" in rel_path or "/fix" in low or "loop-circuit" in rel_path or "2-strike" in low:
        return "debugger"
    if "review" in rel_path or "verify" in rel_path or "verification" in rel_path or "testing-and-api" in rel_path or "webapp-testing" in rel_path:
        return "reviewer"
    impl_keywords = (
        "implementer", "threejs", "db-migration", "ui-anti-slop", "code-simplicity",
        "post-edit", "flutter", "react", "nextjs", "nestjs", "golang", "python",
        "rust", "postgres", "tailwind", "frontend-design", "unslop", "pdf", "docx",
        "xlsx", "pptx", "mcp-builder", "claude-api",
    )
    if any(k in rel_path.lower() or k in low for k in impl_keywords):
        return "implementer"
    return "core"

FRIENDLY_THAI_LABELS = {
    "flutter-expert": "ผู้เชี่ยวชาญ Flutter 3+ & Dart (State, GoRouter, Widget & Performance)",
    "react-expert": "ผู้เชี่ยวชาญ React 19 & Server/Client Components",
    "nextjs-developer": "ผู้เชี่ยวชาญ Next.js App Router & Full-Stack Web",
    "nestjs-expert": "ผู้เชี่ยวชาญ NestJS, DI, Guards & Clean API",
    "golang-pro": "ผู้เชี่ยวชาญ Go (Goroutines, Channels & Microservices)",
    "python-pro": "ผู้เชี่ยวชาญ Python ยุคใหม่, Type Hints & Asyncio",
    "rust-engineer": "ผู้เชี่ยวชาญ Rust (Ownership, Lifetimes & Tokio)",
    "postgres-pro": "ผู้เชี่ยวชาญ PostgreSQL, Indexing & Query Tuning",
    "tailwind-expert": "ผู้เชี่ยวชาญ Tailwind CSS & Design Tokens",
    "frontend-design": "ออกแบบ UI ระดับ Production ไร้กลิ่นอาย AI (Anthropic Official)",
    "webapp-testing": "ทดสอบหน้าเว็บจริงด้วย Playwright & Reconnaissance (Anthropic Official)",
    "mcp-builder": "สร้าง MCP Server เชื่อมต่อระบบภายนอก (Anthropic Official)",
    "claude-api": "พัฒนาแอปด้วย Claude API & Anthropic SDK (Anthropic Official)",
    "pdf": "สร้าง อ่าน และจัดการไฟล์เอกสาร PDF อัตโนมัติ (Anthropic Official)",
    "docx": "สร้างและแก้ไขเอกสาร Word .docx อัตโนมัติ (Anthropic Official)",
    "xlsx": "สร้างตารางและสูตรคำนวณ Excel .xlsx อัตโนมัติ (Anthropic Official)",
    "pptx": "สร้างสไลด์นำเสนอ PowerPoint .pptx อัตโนมัติ (Anthropic Official)",
    "unslop": "สแกนและล้าง AI UI Slop ครบ 9 ด้าน (heydamir/unslop)",
    "ui-anti-slop": "กฎออกแบบ UI สะอาดไร้กลิ่นอาย AI (unslop + frontend-design + Three.js)",
    "security-audit": "ตรวจความปลอดภัยเชิงลึกไร้ False-Positive (Cloudflare Security Gate)",
    "/security-audit": "สั่งรัน Security Audit แยก Confirmed vs Needs Validation (Cloudflare)",
}

def friendly_power_name(rel_path, meta, title):
    base_slug = os.path.basename(os.path.dirname(rel_path)) if rel_path.endswith("/SKILL.md") else os.path.splitext(os.path.basename(rel_path))[0]
    if base_slug in FRIENDLY_THAI_LABELS:
        return FRIENDLY_THAI_LABELS[base_slug]
    desc = str(meta.get("description", "")).strip()
    if re.match(r"^[\u0E00-\u0E7F]", desc):
        return re.sub(r"\s*\([^)]*\)", "", desc).strip()[:100]
    m_th = re.findall(r"\(([^)]*[\u0E00-\u0E7F]+[^)]*)\)", desc)
    if m_th:
        return m_th[-1].strip()
    if desc:
        return desc[:95]
    if title:
        return title[:95]
    return os.path.basename(rel_path)

def scan_workspace_catalog(root):
    patterns = [
        ("governance", ["CLAUDE.md", "AGENTS.md", "GEMINI.md", ".claude/settings.json", ".agents/hooks.json"]),
        ("agent", sorted(glob.glob(os.path.join(root, ".claude/agents/*.md")))),
        ("skill", sorted(glob.glob(os.path.join(root, ".claude/skills/*/SKILL.md")))),
        ("command", sorted(glob.glob(os.path.join(root, ".claude/commands/*.md")))),
        ("rule", sorted(glob.glob(os.path.join(root, ".claude/rules/*.md")))),
        ("hook", sorted(glob.glob(os.path.join(root, ".claude/hooks/*.sh")))),
    ]
    items = []
    files_content = {}
    for kind, p_list in patterns:
        for p in p_list:
            abs_p = p if os.path.isabs(p) else os.path.join(root, p)
            if not os.path.isfile(abs_p):
                continue
            rel_p = os.path.relpath(abs_p, root)
            try:
                raw = open(abs_p, encoding="utf-8", errors="ignore").read()
            except Exception:
                continue
            meta, title, _ = parse_frontmatter_and_body(raw)
            desk = infer_desk_for_file(rel_p, meta, title, raw)
            short_id = meta.get("name") or os.path.splitext(os.path.basename(rel_p))[0]
            if kind == "skill":
                short_id = os.path.basename(os.path.dirname(rel_p))
            elif kind == "command":
                short_id = "/" + os.path.splitext(os.path.basename(rel_p))[0]

            # ตรวจหาไฟล์คู่ขนานใน .agents/ บนดิสก์จริง
            ag_mirror = ""
            if rel_p.startswith(".claude/skills/"):
                cand = rel_p.replace(".claude/skills/", ".agents/skills/", 1)
                if os.path.isfile(os.path.join(root, cand)):
                    ag_mirror = cand
            elif rel_p.startswith(".claude/rules/"):
                cand = rel_p.replace(".claude/rules/", ".agents/rules/", 1)
                if os.path.isfile(os.path.join(root, cand)):
                    ag_mirror = cand

            # ดึงคอมเมนต์บรรทัดที่ 2 สำหรับไฟล์ .sh
            sh_desc = ""
            if kind == "hook":
                for ln in raw.splitlines()[1:4]:
                    if ln.startswith("#"):
                        sh_desc = ln.lstrip("# ").strip()
                        break

            power_label = sh_desc if sh_desc else friendly_power_name(rel_p, meta, title)
            stat = os.stat(abs_p)
            items.append({
                "id": short_id,
                "kind": kind,
                "path": rel_p,
                "agPath": ag_mirror,
                "desk": desk,
                "title": title or short_id,
                "powerLabel": power_label,
                "description": str(meta.get("description") or sh_desc or title or ""),
                "model": str(meta.get("model") or ("opus" if desk == "core" else ("haiku" if desk == "explorer" else "sonnet"))),
                "maxTurns": str(meta.get("maxTurns") or ""),
                "tools": str(meta.get("tools") or meta.get("allowed-tools") or ""),
                "disallowedTools": str(meta.get("disallowedTools") or ""),
                "sizeBytes": stat.st_size,
                "mtime": datetime.fromtimestamp(stat.st_mtime).strftime("%Y-%m-%d %H:%M"),
            })
            # เก็บเนื้อหาจริงจากดิสก์ (ยกเว้น open-hud.sh เพื่อไม่ให้ไฟล์ telemetry ใหญ่เกินจำเป็น)
            if os.path.basename(rel_p) != "open-hud.sh":
                files_content[rel_p] = raw[:16000]
                if ag_mirror:
                    files_content[ag_mirror] = raw[:16000]
    return {"scannedAt": datetime.now().strftime("%H:%M:%S"), "items": items, "files": files_content}

state = {
    "updatedAt": "",
    "updatedEpochMs": 0,
    "activeEngine": engine,
    "activeModel": "opus" if engine == "claude" else "gemini-4-argon",
    "activeNode": "core",
    "systemStatus": "ready",
    "currentTask": "รอรับคำสั่งจริงจากคุณ...",
    "currentAction": "พร้อมรับงาน",
    "liveSpeech": "สวัสดีครับเจ้านาย! พิมพ์สั่งงานด้านล่าง หรือคลิกที่ตัวละครเพื่อดูการ์ดความสามารถจริงในโปรเจกต์ได้เลยครับ",
    "liveEmotion": "idle",
    "activeCommand": "Auto-Route (CLAUDE.md)",
    "activeAgentFile": "CLAUDE.md",
    "activeSkill": "common-ground",
    "activeSkillFile": ".claude/skills/common-ground/SKILL.md",
    "activeRuleFile": ".claude/rules/execution-discipline.md",
    "activeHook": ".claude/hooks/telemetry-tracker.sh",
    "lastDiffStat": "",
    "strikeCount": 0,
    "maxStrikes": 3,
    "touchedFiles": [],
    "usedItemsHistory": [],
    "stats": {
        "claudeCalls": 0,
        "antigravityCalls": 0,
        "explorerReads": 0,
        "implementerEdits": 0,
        "verifierRuns": 0,
        "blockedCount": 0,
        "filesEdited": 0,
    },
    "events": [],
}

if os.path.exists(t_file):
    try:
        loaded = json.load(open(t_file, encoding="utf-8"))
        if isinstance(loaded, dict):
            old_stats = state["stats"].copy()
            if isinstance(loaded.get("stats"), dict):
                old_stats.update(loaded["stats"])
            state.update(loaded)
            state["stats"] = old_stats
    except Exception:
        pass

now_local = datetime.now().strftime("%H:%M:%S")
stats = state["stats"]

def clean_prompt_text(raw_p):
    if not raw_p:
        return ""
    s = str(raw_p)
    # ลบแท็กที่ IDE แนบมาอัตโนมัติ เช่น <ide_opened_file>...</ide_opened_file> หรือ <system-reminder>...</system-reminder>
    s = re.sub(r"<ide_opened_file>.*?</ide_opened_file>", " ", s, flags=re.S)
    s = re.sub(r"<ide_selection>.*?</ide_selection>", " ", s, flags=re.S)
    s = re.sub(r"<system-reminder>.*?</system-reminder>", " ", s, flags=re.S)
    s = " ".join(s.split()).strip()
    if len(s) > 150:
        s = s[:147] + "..."
    return s

def humanize_detail(raw_d):
    if not raw_d:
        return ""
    # แปลง literal \n ที่มาจาก JSON string ให้เป็นบรรทัดใหม่จริงก่อนประมวลผล
    s = str(raw_d).replace("\\n", "\n").replace("\\t", " ").strip()

    # ดึงรายชื่อไฟล์ที่ปรากฏในคำสั่ง (เช่น .dart, .sql, .ts ฯลฯ)
    f_matches = re.findall(r"([A-Za-z0-9_./-]+\.(?:dart|sql|ts|tsx|js|jsx|py|go|rs|sh|md|json))", s)
    uniq_f = []
    for fm in f_matches:
        bn = os.path.basename(fm)
        if bn and bn not in uniq_f:
            uniq_f.append(bn)
    files_suffix = f" ({', '.join(uniq_f[:2])})" if uniq_f else ""

    # หากมีคำอธิบายจาก tool_use.description นำหน้า (เช่น "🔍 Read shift signatures: grep -rn ...") ให้แสดงเฉพาะคำอธิบาย + ชื่อไฟล์สั้นๆ
    m_desc = re.match(r"^(🔍|🧪|✍️|⚡)\s*([^:\n]{4,85}):\s*(.+)$", s, flags=re.S)
    if m_desc:
        icon, desc_lbl, rest_cmd = m_desc.group(1), m_desc.group(2).strip(), m_desc.group(3).strip()
        if desc_lbl.lower() not in ("inspecting", "verifying", "bash"):
            return f"{icon} {desc_lbl}{files_suffix}"[:105]

    # ตรวจจับการเขียนไฟล์ผ่าน Python open(...,'w') หรือ cat > ...
    if re.search(r"(open\([^)]*,\s*['\"]w|cat\s*>+\s*\S+|sed\s+-i)", s):
        if uniq_f:
            return f"✍️ แก้ไขไฟล์จริง: {', '.join(uniq_f[:2])}"
        return "✍️ แก้ไขไฟล์โค้ดในโปรเจกต์"

    if "<<" in s or "\n" in s or "python3 -" in s:
        if uniq_f:
            if s.startswith("🧪"):
                return f"🧪 รันตรวจผลจริง{files_suffix}"
            elif s.startswith("🔍"):
                return f"🔍 สแกนโค้ด{files_suffix}"
            return f"✍️ อัปเดตและตรวจสอบโค้ด{files_suffix}"
        first_ln = s.splitlines()[0].strip()
        first_ln = re.sub(r"^(🔍 Inspecting:|🧪 Verifying:|⚡ Bash:)\s*", "", first_ln)
        s = re.sub(r"^cd\s+[^;&|]+[;&]+\s*", "", first_ln)

    # ลบ cd /path/... && ด้านหน้าเพื่อให้สั้นกระชับ
    s = re.sub(r"(🔍\s*[^:]*:\s*|🧪\s*[^:]*:\s*|⚡\s*[^:]*:\s*)cd\s+[^;&|]+[;&]+\s*", r"\1", s)
    s = " ".join(s.split())
    if len(s) > 100:
        s = s[:97] + "..."
    return s

def infer_thought_desk(txt, tool_names=None, tool_descs=None):
    low = (txt + " " + " ".join(tool_descs or [])).lower()
    t_names = set(tool_names or [])
    if any(k in low for k in ("สรุปสถานะ", "สิ่งที่ให้คุณทำ", "ขั้นตอนต่อไป", "ตั้งงานเบื้องหลัง", "ตั้งงานรอบใหม่ไว้เบื้องหลัง", "wait for stable", "wait for github")):
        return "core"
    if any(k in low for k in ("err:", "error", "504", "ยังตก", "flaky", "has no const", "removing `const`", "failed", "ไม่ผ่าน", "เทสต์ตก", "บั๊ก", "ซ่อม", "แก้ให้ผ่าน", "exception")):
        return "debugger"
    if any(k in low for k in ("ขอดู signature", "ฝั่งแอปจะอ่าน", "ขออ่าน", "ขอดู", "checking how", "ดูโครงสร้าง", "read the ", "read shift", "find ", "check billrecord", "สำรวจ")):
        return "explorer"
    if any(k in low for k in ("pgtap ผ่าน", "ci ผ่าน", "ทดสอบผ่าน", "result: pass", "e2e ทั้งชุดรัน", "รันเทสต์", "เทสต์ผ่าน", "red → green", "ยืนยันแล้ว")):
        return "reviewer"
    if "Edit" in t_names or "Write" in t_names or any(k in low for k in ("ต่อไปจะเขียน", "ต่อไปฝั่งแอปจะ", "ออกแบบหน้า", "เพิ่มปุ่ม", "สร้างไฟล์", "เขียนฝั่งแอป", "writing tests", "implement", "จะผ่านตัวกลางเดียว", "เขียนเทสต์", "เพิ่มการตรวจ", "restoring the real code", "อัปเดต", "แก้ไข")):
        return "implementer"
    if "Read" in t_names or "Grep" in t_names or "Glob" in t_names:
        return "explorer"
    return "core"

def extract_live_session_thoughts(root_dir, ag_conv_id="", active_eng="claude"):
    thoughts = []
    desk_thoughts = {}
    if active_eng == "antigravity" and ag_conv_id:
        ag_f = os.path.expanduser(f"~/.gemini/antigravity/brain/{ag_conv_id}/.system_generated/logs/transcript.jsonl")
        if os.path.isfile(ag_f):
            try:
                with open(ag_f, "rb") as fp:
                    fp.seek(0, os.SEEK_END)
                    sz = fp.tell()
                    fp.seek(max(0, sz - 650000), os.SEEK_SET)
                    raw_chunk = fp.read().decode("utf-8", errors="ignore")
                for line in raw_chunk.splitlines()[1:]:
                    if "\"PLANNER_RESPONSE\"" not in line:
                        continue
                    try:
                        obj = json.loads(line)
                    except Exception:
                        continue
                    if obj.get("type") != "PLANNER_RESPONSE":
                        continue
                    ts_raw = obj.get("created_at") or ""
                    t_str = ""
                    if ts_raw:
                        try:
                            dt = datetime.fromisoformat(ts_raw.replace("Z", "+00:00")).astimezone()
                            t_str = dt.strftime("%H:%M:%S")
                        except Exception:
                            t_str = ""
                    tcalls = obj.get("tool_calls") or []
                    t_names = [tc.get("name", "") for tc in tcalls if isinstance(tc, dict)]
                    t_descs = [str((tc.get("args") or {}).get("toolSummary") or (tc.get("args") or {}).get("Role") or "") for tc in tcalls if isinstance(tc, dict)]
                    for kind_key, k_label in (("thinking", "THOUGHT"), ("content", "REPLY")):
                        raw_txt = str(obj.get(kind_key) or "").replace("**", "").replace("`", "")
                        clean_txt = " ".join(raw_txt.split()).strip()
                        if len(clean_txt) >= 8:
                            desk = infer_thought_desk(clean_txt, t_names, t_descs)
                            item = {"time": t_str or now_local, "kind": k_label, "desk": desk, "text": clean_txt[:260]}
                            if not thoughts or thoughts[-1]["text"] != item["text"]:
                                thoughts.append(item)
                                desk_thoughts[desk] = item
                if thoughts:
                    thoughts.reverse()
                    return thoughts[:12], desk_thoughts
            except Exception:
                pass

    slug = re.sub(r"[^A-Za-z0-9-]", "-", os.path.realpath(root_dir))
    proj_dir = os.path.expanduser(f"~/.claude/projects/{slug}")
    if not os.path.isdir(proj_dir):
        return [], {}
    files = sorted(glob.glob(os.path.join(proj_dir, "*.jsonl")), key=os.path.getmtime, reverse=True)
    if not files:
        return [], {}
    latest_f = files[0]
    try:
        with open(latest_f, "rb") as fp:
            fp.seek(0, os.SEEK_END)
            sz = fp.tell()
            fp.seek(max(0, sz - 650000), os.SEEK_SET)
            raw_chunk = fp.read().decode("utf-8", errors="ignore")
    except Exception:
        return [], {}

    thoughts = []
    desk_thoughts = {}
    lines = raw_chunk.splitlines()
    if len(lines) > 1:
        lines = lines[1:]
    for line in lines:
        if "\"assistant\"" not in line:
            continue
        try:
            obj = json.loads(line)
        except Exception:
            continue
        if obj.get("type") != "assistant":
            continue
        ts_raw = obj.get("timestamp") or ""
        t_str = ""
        if ts_raw:
            try:
                dt = datetime.fromisoformat(ts_raw.replace("Z", "+00:00")).astimezone()
                t_str = dt.strftime("%H:%M:%S")
            except Exception:
                t_str = ""
        msg = obj.get("message") or {}
        contents = msg.get("content") or []
        tool_names = [c.get("name", "") for c in contents if isinstance(c, dict) and c.get("type") == "tool_use"]
        tool_descs = [str((c.get("input") or {}).get("description") or "") for c in contents if isinstance(c, dict) and c.get("type") == "tool_use"]

        for c in contents:
            if not isinstance(c, dict):
                continue
            ctype = c.get("type")
            if ctype == "tool_use" and c.get("name") == "Agent":
                inp = c.get("input") or {}
                st = str(inp.get("subagent_type") or "implementer").lower()
                sm = str(inp.get("model") or ("haiku" if "explor" in st else "sonnet")).upper()
                sdesc = str(inp.get("description") or inp.get("prompt") or "")[:180]
                s_desk = "explorer" if "explor" in st else ("debugger" if "debug" in st else ("reviewer" if "review" in st else "implementer"))
                item = {
                    "time": t_str or now_local,
                    "kind": "SUBAGENT",
                    "desk": s_desk,
                    "text": f"🤖 [Subagent จริง: {sm}] เรียก {st} — {sdesc}",
                }
                thoughts.append(item)
                desk_thoughts[s_desk] = item
            elif ctype in ("thinking", "text"):
                raw_txt = (c.get("thinking") if ctype == "thinking" else c.get("text")) or ""
                raw_txt = re.sub(r"<system-reminder>.*?</system-reminder>", " ", raw_txt, flags=re.S)
                raw_txt = re.sub(r"<ide_opened_file>.*?</ide_opened_file>", " ", raw_txt, flags=re.S)
                raw_txt = raw_txt.replace("**", "").replace("`", "")
                clean_txt = " ".join(raw_txt.split()).strip()
                if len(clean_txt) < 8 or clean_txt.startswith(("This session is being continued", "Codebase and user instructions")):
                    continue
                desk = infer_thought_desk(clean_txt, tool_names, tool_descs)
                item = {
                    "time": t_str or now_local,
                    "kind": "THOUGHT" if ctype == "thinking" else "REPLY",
                    "desk": desk,
                    "text": clean_txt[:260],
                }
                if not thoughts or thoughts[-1]["text"] != item["text"]:
                    thoughts.append(item)
                    desk_thoughts[desk] = item

    # สกัดความคิดสดจาก Subagents จริงใน <session-id>/subagents/agent-*.jsonl (ถ้ามี)
    sess_id_full = os.path.splitext(os.path.basename(latest_f))[0]
    sub_dir = os.path.join(proj_dir, sess_id_full, "subagents")
    if os.path.isdir(sub_dir):
        for sub_f in sorted(glob.glob(os.path.join(sub_dir, "agent-*.jsonl")), key=os.path.getmtime):
            meta_f = sub_f.replace(".jsonl", ".meta.json")
            s_desk = "explorer"
            if os.path.isfile(meta_f):
                try:
                    m_obj = json.load(open(meta_f, encoding="utf-8"))
                    at = str(m_obj.get("agentType") or m_obj.get("description") or "").lower()
                    if "debug" in at or "fix" in at:
                        s_desk = "debugger"
                    elif "review" in at or "security" in at or "audit" in at or "qa" in at:
                        s_desk = "reviewer"
                    elif "implement" in at or "code" in at:
                        s_desk = "implementer"
                    else:
                        s_desk = "explorer"
                except Exception:
                    pass
            try:
                with open(sub_f, "rb") as sfp:
                    sfp.seek(0, os.SEEK_END)
                    ssz = sfp.tell()
                    sfp.seek(max(0, ssz - 120000), os.SEEK_SET)
                    s_chunk = sfp.read().decode("utf-8", errors="ignore")
                for sline in s_chunk.splitlines():
                    if "\"assistant\"" not in sline:
                        continue
                    sobj = json.loads(sline)
                    if sobj.get("type") != "assistant":
                        continue
                    smsg = sobj.get("message") or {}
                    smodel = str(smsg.get("model") or "subagent").upper()
                    for sc in (smsg.get("content") or []):
                        if isinstance(sc, dict) and sc.get("type") in ("thinking", "text"):
                            stxt = " ".join(str(sc.get("thinking") or sc.get("text") or "").replace("**", "").replace("`", "").split()).strip()
                            if len(stxt) >= 8:
                                s_item = {
                                    "time": now_local,
                                    "kind": "SUBAGENT",
                                    "desk": s_desk,
                                    "text": f"🤖 [{smodel}] {stxt[:230]}",
                                }
                                desk_thoughts[s_desk] = s_item
            except Exception:
                pass

    thoughts.reverse()
    return thoughts[:12], desk_thoughts

def extract_session_proof_metrics(root_dir):
    proof = {
        "sessionId": "none",
        "opusTurns": 0,
        "sonnetTurns": 0,
        "haikuTurns": 0,
        "subagentCalls": 0,
        "subagentFiles": 0,
        "subagentByDesk": {"explorer": 0, "implementer": 0, "debugger": 0, "reviewer": 0},
        "offloadPct": 0,
    }
    slug = re.sub(r"[^A-Za-z0-9-]", "-", os.path.realpath(root_dir))
    proj_dir = os.path.expanduser(f"~/.claude/projects/{slug}")
    if not os.path.isdir(proj_dir):
        return proof
    files = sorted(glob.glob(os.path.join(proj_dir, "*.jsonl")), key=os.path.getmtime, reverse=True)
    if not files:
        return proof
    latest_f = files[0]
    sess_id_full = os.path.splitext(os.path.basename(latest_f))[0]
    proof["sessionId"] = sess_id_full[:8]

    def scan_jsonl_models(f_path, count_agents=False):
        try:
            with open(f_path, "r", encoding="utf-8", errors="ignore") as fp:
                for line in fp:
                    if "\"assistant\"" not in line:
                        continue
                    if "\"model\"" in line:
                        m_match = re.search(r'"model"\s*:\s*"([^"]+)"', line)
                        if m_match:
                            m_low = m_match.group(1).lower()
                            if "opus" in m_low:
                                proof["opusTurns"] += 1
                            elif "sonnet" in m_low:
                                proof["sonnetTurns"] += 1
                            elif "haiku" in m_low:
                                proof["haikuTurns"] += 1
                    if count_agents and "\"name\":\"Agent\"" in line.replace(" ", ""):
                        try:
                            obj = json.loads(line)
                            for c in ((obj.get("message") or {}).get("content") or []):
                                if isinstance(c, dict) and c.get("type") == "tool_use" and c.get("name") == "Agent":
                                    proof["subagentCalls"] += 1
                                    st = str((c.get("input") or {}).get("subagent_type") or "implementer").lower()
                                    d_k = "explorer" if "explor" in st else ("debugger" if "debug" in st else ("reviewer" if ("review" in st or "security" in st) else "implementer"))
                                    proof["subagentByDesk"][d_k] = proof["subagentByDesk"].get(d_k, 0) + 1
                        except Exception:
                            pass
        except Exception:
            pass

    scan_jsonl_models(latest_f, count_agents=True)
    sub_dir = os.path.join(proj_dir, sess_id_full, "subagents")
    if os.path.isdir(sub_dir):
        sub_jsonls = glob.glob(os.path.join(sub_dir, "agent-*.jsonl"))
        proof["subagentFiles"] = len(sub_jsonls)
        for sf in sub_jsonls:
            scan_jsonl_models(sf, count_agents=False)
        if proof["subagentFiles"] > proof["subagentCalls"]:
            proof["subagentCalls"] = proof["subagentFiles"]

    total_t = proof["opusTurns"] + proof["sonnetTurns"] + proof["haikuTurns"]
    if total_t > 0:
        proof["offloadPct"] = round(((proof["sonnetTurns"] + proof["haikuTurns"]) * 100.0) / total_t, 1)
    return proof

def push_used_item(kind, name, path, desk, detail_txt=""):
    # ข้ามการบันทึก loop-circuit-breaker.sh ซ้ำๆ ในสถานะปกติ เพื่อไม่ให้รกหน้าประวัติ
    if kind == "HOOK" and "loop-circuit-breaker" in name and state.get("systemStatus") == "working":
        return
    clean_det = humanize_detail(detail_txt)
    hist = state.get("usedItemsHistory") or []
    entry = {
        "time": now_local,
        "kind": kind,
        "name": name,
        "path": path,
        "desk": desk,
        "detail": clean_det,
    }
    # หากมีรายการชนิดและชื่อเดียวกันอยู่ใน 4 อันดับแรก ให้ดึงขึ้นมาอัปเดตเวลาด้านบนแทนการเพิ่มซ้ำ
    for idx, existing in enumerate(hist[:4]):
        if existing.get("kind") == kind and existing.get("name") == name and existing.get("path") == path:
            hist.pop(idx)
            break
    hist.insert(0, entry)
    state["usedItemsHistory"] = hist[:20]

# ดึง git diff --shortstat จริงจากโปรเจกต์ (ใช้ --no-optional-locks เพื่อไม่ให้สร้าง .git/index.lock ชนกับ AI!)
real_git_diff = diff_arg
if not real_git_diff:
    try:
        out = subprocess.check_output(
            ["git", "--no-optional-locks", "diff", "--shortstat"],
            cwd=project_root,
            stderr=subprocess.DEVNULL,
            timeout=1.5,
        ).decode("utf-8", errors="ignore").strip()
        real_git_diff = out
    except Exception:
        real_git_diff = ""
if real_git_diff:
    state["lastDiffStat"] = real_git_diff

if mode_type == "stdin":
    try:
        payload = json.loads(raw_in) if raw_in.strip() else {}
    except Exception:
        payload = {}

    state["activeEngine"] = engine
    if payload.get("modelName") and payload.get("modelName") != "auto":
        state["activeModel"] = str(payload["modelName"])
    if payload.get("conversationId"):
        state["lastConversationId"] = str(payload["conversationId"])

    prompt_txt = payload.get("prompt") or payload.get("lastUserInput") or ""
    if prompt_txt:
        clean_p = clean_prompt_text(prompt_txt)
        if clean_p:
            state["currentTask"] = clean_p

    if stage == "prompt":
        state["activeNode"] = "core"
        if engine == "claude" and not payload.get("modelName"):
            state["activeModel"] = "opus"
        state["systemStatus"] = "working"
        state["liveEmotion"] = "working"
        state["activeAgentFile"] = "CLAUDE.md" if engine == "claude" else "AGENTS.md"
        state["activeHook"] = ".claude/hooks/telemetry-tracker.sh (UserPromptSubmit)"

        p_low = state["currentTask"].lower()
        if "/plan" in p_low:
            state["activeCommand"] = "/plan"
            state["activeSkill"] = "common-ground"
            state["activeSkillFile"] = ".claude/skills/common-ground/SKILL.md"
            push_used_item("COMMAND", "/plan", ".claude/commands/plan.md", "core", state["currentTask"])
        elif "/common-ground" in p_low:
            state["activeCommand"] = "/common-ground"
            state["activeSkill"] = "common-ground"
            state["activeSkillFile"] = ".claude/skills/common-ground/SKILL.md"
            push_used_item("COMMAND", "/common-ground", ".claude/commands/common-ground.md", "core", state["currentTask"])
        elif "/fix" in p_low or "บั๊ก" in p_low or "พัง" in p_low or "error" in p_low:
            state["activeCommand"] = "/fix"
            state["activeSkill"] = "root-cause-debug"
            state["activeSkillFile"] = ".claude/skills/root-cause-debug/SKILL.md"
            push_used_item("SKILL", "root-cause-debug", ".claude/skills/root-cause-debug/SKILL.md", "debugger", state["currentTask"])
        elif "/security-audit" in p_low or "security audit" in p_low or "ช่องโหว่" in p_low:
            state["activeCommand"] = "/security-audit"
            state["activeSkill"] = "security-audit"
            state["activeSkillFile"] = ".claude/skills/security-audit/SKILL.md"
            push_used_item("SKILL", "security-audit", ".claude/skills/security-audit/SKILL.md", "reviewer", state["currentTask"])
        elif "/review" in p_low or "รีวิว" in p_low or "ตรวจ" in p_low:
            state["activeCommand"] = "/review"
            state["activeSkill"] = "pragmatic-review"
            state["activeSkillFile"] = ".claude/skills/pragmatic-review/SKILL.md"
            push_used_item("SKILL", "pragmatic-review", ".claude/skills/pragmatic-review/SKILL.md", "reviewer", state["currentTask"])
        elif "/verify" in p_low or "เทสต์" in p_low:
            state["activeCommand"] = "/verify"
            state["activeSkill"] = "verification-before-completion"
            state["activeSkillFile"] = ".claude/skills/verification-before-completion/SKILL.md"
            push_used_item("SKILL", "verification-before-completion", ".claude/skills/verification-before-completion/SKILL.md", "reviewer", state["currentTask"])
        elif "3d" in p_low or "three" in p_low or "voxel" in p_low or "pixel" in p_low:
            state["activeCommand"] = "Auto-Route (3D)"
            state["activeSkill"] = "threejs-expert"
            state["activeSkillFile"] = ".claude/skills/threejs-expert/SKILL.md"
            state["activeRuleFile"] = ".claude/rules/ui-anti-slop.md"
            push_used_item("SKILL", "threejs-expert", ".claude/skills/threejs-expert/SKILL.md", "implementer", state["currentTask"])
        elif "db" in p_low or "sql" in p_low or "migration" in p_low:
            state["activeCommand"] = "Auto-Route (DB)"
            state["activeSkill"] = "db-migration"
            state["activeSkillFile"] = ".claude/skills/db-migration/SKILL.md"
            push_used_item("SKILL", "db-migration", ".claude/skills/db-migration/SKILL.md", "implementer", state["currentTask"])
        else:
            state["activeCommand"] = "Auto-Route (CLAUDE.md)"
            state["activeSkill"] = "common-ground"
            state["activeSkillFile"] = ".claude/skills/common-ground/SKILL.md"

        push_used_item("PROMPT", state["currentTask"][:55], state["activeAgentFile"], "core", state["currentTask"])
        state["currentAction"] = f"👑 รับโจทย์จริง: {state['currentTask'][:80]}"
        state["liveSpeech"] = f"รับโจทย์จริงแล้วครับ: \"{state['currentTask'][:65]}\" กำลังใช้ทักษะ [{state['activeSkill']}] วางแผนงาน!"

    elif stage == "read":
        tool_name = (payload.get("toolCall") or {}).get("name") or payload.get("tool_name") or "Read"
        tool_args = (payload.get("toolCall") or {}).get("args") or payload.get("tool_input") or {}
        raw_target = str(tool_args.get("Path") or tool_args.get("file_path") or tool_args.get("pattern") or tool_args.get("Query") or "")
        rel_target = os.path.relpath(raw_target, project_root) if (raw_target and os.path.isabs(raw_target)) else raw_target
        short_target = os.path.basename(raw_target.rstrip("/")) if raw_target else "ไฟล์ในโปรเจกต์"

        state["activeHook"] = ".claude/hooks/telemetry-tracker.sh (PreToolUse:Read)"
        state["systemStatus"] = "working"
        state["liveEmotion"] = "working"
        stats["explorerReads"] = int(stats.get("explorerReads", 0)) + 1

        m_skill = re.search(r"(?:\.claude|\.agents)/skills/([^/]+)/SKILL\.md", rel_target)
        m_cmd = re.search(r"\.claude/commands/([^/]+)\.md", rel_target)
        m_agent = re.search(r"\.claude/agents/([^/]+)\.md", rel_target)
        m_rule = re.search(r"(?:\.claude|\.agents)/rules/([^/]+\.md)", rel_target)

        if m_skill:
            skill_slug = m_skill.group(1)
            state["activeSkill"] = skill_slug
            state["activeSkillFile"] = f".claude/skills/{skill_slug}/SKILL.md"
            if skill_slug in ("threejs-expert", "db-migration"):
                state["activeNode"] = "implementer"
                state["activeAgentFile"] = ".claude/agents/implementer.md"
            elif skill_slug == "root-cause-debug":
                state["activeNode"] = "debugger"
                state["activeAgentFile"] = ".claude/agents/debugger.md"
            elif skill_slug in ("pragmatic-review", "verification-before-completion", "security-audit"):
                state["activeNode"] = "reviewer"
                state["activeAgentFile"] = ".claude/agents/reviewer.md"
            else:
                state["activeNode"] = "core"
                state["activeAgentFile"] = "CLAUDE.md"
            push_used_item("SKILL", skill_slug, state["activeSkillFile"], state["activeNode"], f"Read {rel_target}")
            state["currentAction"] = f"📚 เปิดอ่าน Skill จริง: {skill_slug} ({rel_target})"
            state["liveSpeech"] = f"กำลังดึงคู่มือทักษะ [{skill_slug}] จากไฟล์ {rel_target} มาใช้ปฏิบัติงานจริงครับ!"
        elif m_cmd:
            cmd_slug = m_cmd.group(1)
            state["activeCommand"] = f"/{cmd_slug}"
            push_used_item("COMMAND", f"/{cmd_slug}", f".claude/commands/{cmd_slug}.md", state.get("activeNode", "core"), f"Read {rel_target}")
            state["currentAction"] = f"⚡ เปิดอ่านคำสั่ง Prompt: /{cmd_slug} ({rel_target})"
            state["liveSpeech"] = f"กำลังโหลดขั้นตอนจากคำสั่ง /{cmd_slug} ({rel_target}) ครับ!"
        elif m_agent:
            ag_slug = m_agent.group(1)
            if ag_slug in ("explorer", "implementer", "debugger", "reviewer"):
                state["activeNode"] = ag_slug
            state["activeAgentFile"] = f".claude/agents/{ag_slug}.md"
            push_used_item("AGENT", ag_slug, state["activeAgentFile"], state["activeNode"], f"Read {rel_target}")
            state["currentAction"] = f"🤖 โหลดโปรไฟล์พนักงาน: {ag_slug} ({rel_target})"
            state["liveSpeech"] = f"รับทราบกฎการทำงานจากไฟล์ {rel_target} พร้อมลุยงานครับ!"
        elif m_rule:
            r_name = m_rule.group(1)
            state["activeRuleFile"] = f".claude/rules/{r_name}"
            push_used_item("RULE", r_name, state["activeRuleFile"], state.get("activeNode", "core"), f"Read {rel_target}")
            state["currentAction"] = f"📏 โหลดกฎเหล็ก: {r_name} ({rel_target})"
            state["liveSpeech"] = f"กำลังตรวจสอบความถูกต้องตามกฎ {r_name} ครับ!"
        else:
            state["activeNode"] = "explorer"
            state["activeModel"] = "haiku" if engine == "claude" else state.get("activeModel", "auto")
            state["activeAgentFile"] = ".claude/agents/explorer.md"
            state["activeRuleFile"] = ".claude/rules/execution-discipline.md"
            if rel_target and not rel_target.startswith(".."):
                push_used_item("READ", short_target, rel_target, "explorer", f"{tool_name}: {rel_target}")
            state["currentAction"] = f"🔍 ฝ่ายสำรวจใช้ {tool_name} ค้นหา: {rel_target or short_target}"
            state["liveSpeech"] = f"ใช้ {tool_name} สแกนไฟล์ [{short_target}] เจอพิกัดแล้วค่ะ! ช่วยประหยัดโควต้าสมองใหญ่ไปได้อีก 1 รอบ ⚡"

    elif stage == "agent":
        t_in = payload.get("tool_input") or (payload.get("toolCall") or {}).get("args") or {}
        sub_type = str(t_in.get("subagent_type") or t_in.get("TypeName") or "implementer").strip()
        sub_role = str(t_in.get("Role") or "").strip()
        comb_low = (sub_type + " " + sub_role).lower()
        if "explor" in comb_low or "research" in comb_low or "scout" in comb_low:
            sub_desk = "explorer"
            default_m = "haiku" if engine == "claude" else "flash"
            sub_skill = "tech-stack-skills"
        elif "debug" in comb_low or "fix" in comb_low or "strike" in comb_low:
            sub_desk = "debugger"
            default_m = "sonnet" if engine == "claude" else "pro"
            sub_skill = "root-cause-debug"
        elif "review" in comb_low or "qa" in comb_low or "verif" in comb_low or "browser" in comb_low:
            sub_desk = "reviewer"
            default_m = "sonnet" if engine == "claude" else "pro"
            sub_skill = "pragmatic-review"
        else:
            sub_desk = "implementer"
            default_m = "sonnet" if engine == "claude" else "pro"
            sub_skill = "verification-before-completion"
        sub_model = str(t_in.get("model") or t_in.get("Model") or default_m).lower()
        sub_desc = humanize_detail(str(t_in.get("description") or sub_role or t_in.get("prompt") or t_in.get("Prompt") or sub_type))
        state["activeNode"] = sub_desk
        state["activeModel"] = sub_model
        state["systemStatus"] = "working"
        state["liveEmotion"] = "working"
        state["activeAgentFile"] = f".claude/agents/{sub_desk}.md"
        state["activeSkill"] = sub_skill
        state["activeSkillFile"] = f".claude/skills/{sub_skill}/SKILL.md"
        state["activeRuleFile"] = ".claude/rules/model-routing.md"
        state["activeHook"] = ".claude/hooks/telemetry-tracker.sh (Subagent Spawn)"
        state["currentAction"] = f"🤖 [Subagent จริง: {sub_model.upper()}] แตกงานให้ {sub_type}: {sub_desc}"
        state["liveSpeech"] = f"🤖 แตก Subagent จริง [{sub_type} • {sub_model.upper()}] มารับงาน [{sub_desc}] ช่วยประหยัดโควต้าหน้าต่างหลักแล้วครับ!"
        stats["subagentSpawns"] = int(stats.get("subagentSpawns", 0)) + 1
        push_used_item("SUBAGENT", f"{sub_type} ({sub_model.upper()})", state["activeAgentFile"], sub_desk, f"🤖 [Subagent จริง: {sub_model.upper()}] {sub_desc}")

    elif stage == "stop":
        term_reason = payload.get("terminationReason") or "COMPLETED"
        state["activeHook"] = ".claude/hooks/telemetry-tracker.sh (Stop)"
        if term_reason == "MAX_TOKEN_BUDGET_EXCEEDED":
            state["activeNode"] = "core"
            state["systemStatus"] = "blocked"
            state["liveEmotion"] = "blocked"
            state["activeSkill"] = "auto-resume-handoff"
            state["activeSkillFile"] = ".claude/skills/auto-resume-handoff/SKILL.md"
            state["currentAction"] = "🔴 โควต้าเต็ม (MAX_TOKEN_BUDGET_EXCEEDED) — แนะนำสลับค่าย AI!"
            state["liveSpeech"] = "โควต้าฝั่งนี้เต็มแล้วครับเจ้านาย! กดปุ่มสลับค่าย AI เพื่อรับไม้ต่อจากจุดเดิมได้ทันทีครับ 🔄"
        else:
            state["activeNode"] = state.get("liveThoughtDesk") or "core"
            state["systemStatus"] = "ready"
            state["liveEmotion"] = "verified"
            state["activeAgentFile"] = "CLAUDE.md" if engine == "claude" else "AGENTS.md"
            state["activeSkill"] = state.get("activeSkill") or "common-ground"
            state["activeSkillFile"] = f".claude/skills/{state['activeSkill']}/SKILL.md"
            state["currentAction"] = "✅ จบรอบการตอบล่าสุด (พร้อมรับคำสั่งถัดไป หรือรันงานเบื้องหลัง)"
            state["liveSpeech"] = "สรุปผลรอบนี้เรียบร้อยครับเจ้านาย! พร้อมรับคำสั่งต่อไปได้เลยครับ"

    if stage in ("prompt", "read"):
        if engine == "claude":
            stats["claudeCalls"] = int(stats.get("claudeCalls", 0)) + 1
        else:
            stats["antigravityCalls"] = int(stats.get("antigravityCalls", 0)) + 1

else:
    # โหมด CLI (เรียกจาก Hook อื่นๆ เช่น post-edit-format.sh, loop-circuit-breaker.sh, validate-bash.sh หรือปุ่มทดสอบ)
    state["activeEngine"] = engine
    state["activeNode"] = node
    state["systemStatus"] = status

    if model_arg:
        state["activeModel"] = model_arg
    elif engine == "claude":
        if node == "core":
            state["activeModel"] = "opus"
        elif node == "explorer":
            state["activeModel"] = "haiku"
        else:
            state["activeModel"] = "sonnet"
    else:
        state["activeModel"] = "gemini-4-argon"

    NODE_DEFAULTS = {
        "core": {
            "agent": "CLAUDE.md",
            "skill": "common-ground",
            "cmd": "/plan",
            "rule": ".claude/rules/execution-discipline.md",
        },
        "explorer": {
            "agent": ".claude/agents/explorer.md",
            "skill": "tech-stack-skills",
            "cmd": "/plan",
            "rule": ".claude/rules/execution-discipline.md",
        },
        "implementer": {
            "agent": ".claude/agents/implementer.md",
            "skill": "verification-before-completion",
            "cmd": "Surgical Edit",
            "rule": ".claude/rules/code-simplicity.md",
        },
        "debugger": {
            "agent": ".claude/agents/debugger.md",
            "skill": "root-cause-debug",
            "cmd": "/fix",
            "rule": ".claude/rules/testing-and-api.md",
        },
        "reviewer": {
            "agent": ".claude/agents/reviewer.md",
            "skill": "pragmatic-review",
            "cmd": "/verify",
            "rule": ".claude/rules/testing-and-api.md",
        },
    }
    nd = NODE_DEFAULTS.get(node, NODE_DEFAULTS["core"])
    state["activeAgentFile"] = nd["agent"]

    d_low = (detail or "").lower()
    installed_skills = [
        os.path.basename(os.path.dirname(p))
        for p in glob.glob(os.path.join(project_root, ".claude/skills/*/SKILL.md"))
    ]
    for sk in installed_skills:
        if not skill_arg and sk in d_low:
            skill_arg = sk
            break
    if not skill_arg:
        if "สลับค่าย" in d_low or "handoff" in d_low:
            skill_arg = "auto-resume-handoff"
        elif ".dart" in d_low or "flutter" in d_low:
            if "flutter-expert" in installed_skills:
                skill_arg = "flutter-expert"
        elif ".sql" in d_low or "migration" in d_low or "supabase" in d_low or "settle_bill" in d_low:
            skill_arg = "db-migration"
        elif "3d" in d_low or "three" in d_low or "hud" in d_low:
            skill_arg = "threejs-expert"
        elif "ซ่อม" in d_low or "เทสต์พัง" in d_low or "repeat" in d_low or "circuit" in d_low:
            skill_arg = "root-cause-debug"
        elif "ตรวจ" in d_low or "verifying" in d_low:
            skill_arg = "verification-before-completion"
        elif "สำรวจ" in d_low or "inspecting" in d_low:
            skill_arg = "tech-stack-skills"

    for cm in ("/plan", "/common-ground", "/fix", "/review", "/verify", "/handoff"):
        if not cmd_arg and cm in d_low:
            cmd_arg = cm
            break

    chosen_skill = skill_arg or nd["skill"]
    if file_touched:
        fl = file_touched.lower()
        if fl.endswith(".dart"):
            if not rule_arg:
                rule_arg = ".claude/rules/ui-anti-slop.md"
            if "flutter-expert" in installed_skills:
                chosen_skill = skill_arg or "flutter-expert"
        elif fl.endswith((".tsx", ".jsx", ".html", ".css", ".vue", ".svelte")):
            if not rule_arg:
                rule_arg = ".claude/rules/ui-anti-slop.md"
            if "hud" in fl or "three" in fl or "3d" in fl:
                chosen_skill = skill_arg or "threejs-expert"
        elif "migration" in fl or "schema" in fl or fl.endswith(".sql"):
            chosen_skill = skill_arg or "db-migration"

    clean_detail = humanize_detail(detail)
    state["activeSkill"] = chosen_skill
    state["activeSkillFile"] = f".claude/skills/{chosen_skill}/SKILL.md"
    state["activeCommand"] = cmd_arg or nd["cmd"]
    state["activeRuleFile"] = rule_arg or nd["rule"]
    if hook_arg:
        state["activeHook"] = hook_arg

    if prompt_arg:
        state["currentTask"] = clean_prompt_text(prompt_arg)
    elif clean_detail and (not state.get("currentTask") or state["currentTask"].startswith(("⚡", "🔍", "🧪", "🟢", "รอรับ"))):
        state["currentTask"] = clean_detail

    if clean_detail:
        state["currentAction"] = clean_detail

    if strike != "":
        try:
            state["strikeCount"] = int(strike)
        except Exception:
            pass

    # อัปเดตสถิติจริงตามประเภทการทำงาน
    if engine == "claude":
        stats["claudeCalls"] = int(stats.get("claudeCalls", 0)) + 1
    else:
        stats["antigravityCalls"] = int(stats.get("antigravityCalls", 0)) + 1

    if node == "explorer":
        stats["explorerReads"] = int(stats.get("explorerReads", 0)) + 1
    elif node == "implementer" or file_touched:
        stats["implementerEdits"] = int(stats.get("implementerEdits", 0)) + 1
    elif node == "reviewer":
        stats["verifierRuns"] = int(stats.get("verifierRuns", 0)) + 1

    if status == "blocked":
        stats["blockedCount"] = int(stats.get("blockedCount", 0)) + 1
        state["liveEmotion"] = "blocked"
    elif status == "warning":
        state["liveEmotion"] = "warning"
    elif status == "working":
        state["liveEmotion"] = "working"
    else:
        state["liveEmotion"] = "verified" if node == "reviewer" else "idle"

    if file_touched:
        short_f = os.path.relpath(file_touched, project_root) if os.path.isabs(file_touched) else file_touched
        if short_f.startswith(".."):
            short_f = os.path.basename(file_touched)
        touched = state.get("touchedFiles") or []
        if short_f in touched:
            touched.remove(short_f)
        touched.insert(0, short_f)
        state["touchedFiles"] = touched[:8]
        stats["filesEdited"] = int(stats.get("filesEdited", 0)) + 1
        diff_note = f" ({real_git_diff})" if real_git_diff else ""
        state["liveSpeech"] = f"แก้ไขไฟล์จริง [{short_f}]{diff_note} ตามทักษะ [{chosen_skill}] และบันทึก Checkpoint แล้วครับ ✍️"
        push_used_item("EDIT", short_f, short_f, node, f"Edited {short_f}{diff_note}")
    else:
        state["liveSpeech"] = clean_detail or f"กำลังปฏิบัติงานด้วยทักษะ [{chosen_skill}] ครับ!"

    push_used_item("SKILL", state["activeSkill"], state["activeSkillFile"], node, clean_detail or "")
    if hook_arg:
        push_used_item("HOOK", os.path.basename(hook_arg), hook_arg.split(" ")[0], node, clean_detail or "")

state["sessionProof"] = extract_session_proof_metrics(project_root)
if state["sessionProof"].get("subagentCalls", 0) > int(stats.get("subagentSpawns", 0)):
    stats["subagentSpawns"] = state["sessionProof"]["subagentCalls"]
state["stats"] = stats
state["workspaceCatalog"] = scan_workspace_catalog(project_root)

# สกัดความคิดสด (Thinking & Assistant Replies) จาก Session .jsonl ของโปรเจกต์ (รองรับทั้ง Claude Code และ Antigravity)
agent_thoughts, desk_thoughts = extract_live_session_thoughts(
    project_root,
    state.get("lastConversationId", ""),
    state.get("activeEngine", "claude"),
)
if agent_thoughts:
    state["agentThoughts"] = agent_thoughts
    state["deskThoughts"] = desk_thoughts
    latest_th = agent_thoughts[0]
    state["liveThought"] = latest_th["text"]
    state["liveThoughtDesk"] = latest_th["desk"]
    if stage == "stop" or state.get("systemStatus") == "ready":
        state["activeNode"] = latest_th["desk"]
        if any(k in latest_th["text"] for k in ("ตั้งงานเบื้องหลัง", "ตั้งงานรอบใหม่ไว้เบื้องหลัง", "รันอยู่เบื้องหลัง")):
            state["currentAction"] = f"⏳ รันงานเบื้องหลังรอผล: {latest_th['text'][:75]}..."
    # หากกำลังทำงานปกติ (ไม่ได้ติดบล็อกและไม่ใช่จังหวะเพิ่งแตก Subagent) ให้แสดงความคิดของโต๊ะที่กำลังแอคทีฟบนลูกโป่งคำพูด!
    if state.get("systemStatus") != "blocked" and int(state.get("strikeCount") or 0) < 2 and stage != "agent":
        active_d = state.get("activeNode", "core")
        chosen_th = desk_thoughts.get(active_d) or latest_th
        th_for_desk = chosen_th.get("text", "")
        th_icon = "💬" if chosen_th.get("kind") == "REPLY" else "💭"
        if th_for_desk:
            state["liveSpeech"] = f"{th_icon} {th_for_desk}"

# กรองเฉพาะไฟล์ที่มีอยู่จริงบนดิสก์เท่านั้น (ป้องกันไฟล์จำลองค้างเก่า)
valid_touched = [
    f for f in (state.get("touchedFiles") or [])
    if os.path.isfile(os.path.join(project_root, f))
]
if not valid_touched:
    try:
        git_files = subprocess.check_output(
            ["git", "--no-optional-locks", "diff", "--name-only", "HEAD~1", "HEAD"],
            cwd=project_root,
            stderr=subprocess.DEVNULL,
            timeout=1.5,
        ).decode("utf-8", errors="ignore").splitlines()
        for gf in git_files:
            gf = gf.strip()
            if gf and os.path.isfile(os.path.join(project_root, gf)) and gf not in valid_touched:
                valid_touched.append(gf)
    except Exception:
        pass
state["touchedFiles"] = valid_touched[:8]

events = state.get("events") or []
events.insert(0, {
    "time": now_local,
    "engine": state["activeEngine"],
    "node": state["activeNode"],
    "status": state["systemStatus"],
    "detail": state["currentAction"],
    "skill": state.get("activeSkill", ""),
    "agentFile": state.get("activeAgentFile", ""),
})
state["events"] = events[:25]
state["updatedAt"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
state["updatedEpochMs"] = int(time.time() * 1000)

tmp = f"{t_file}.tmp.{os.getpid()}"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(state, f, ensure_ascii=False, indent=2)
os.replace(tmp, t_file)
PYEOF
fi

if [ "$MODE_TYPE" = "stdin" ] && [ "$ENGINE" = "antigravity" ]; then
  if [ "$HOOK_STAGE" = "read" ] || [ "$HOOK_STAGE" = "stop" ] || [ "$HOOK_STAGE" = "agent" ]; then
    printf '{"decision":"allow"}\n'
  elif [ "$HOOK_STAGE" = "prompt" ]; then
    printf '{"injectSteps":[{"systemMessage":{"systemMessage":"[MODEL-ROUTING AUTHORIZED]: ผู้ใช้สั่งอนุญาตให้เรียกใช้ invoke_subagent ทันทีสำหรับก้อนงานหลายขั้นตอน (สำรวจ >3 ไฟล์ ➔ TypeName=research, Model=flash, Role=Explorer | เขียนโค้ดหลายไฟล์+เทสต์ย่อย ➔ TypeName=self, Model=inherit, Role=Surgical Implementer | ซ่อมบั๊ก ➔ TypeName=self, Role=2-Strike Debugger | ทดสอบเว็บ/E2E ➔ TypeName=browser, Role=QA Verifier) เพื่อรักษา Context หน้าต่างหลัก"}}]}\n'
  else
    printf '{}\n'
  fi
elif [ "$MODE_TYPE" = "stdin" ] && [ "$ENGINE" = "claude" ] && [ "$HOOK_STAGE" = "prompt" ]; then
  echo "[MODEL-ROUTING AUTHORIZED]: ผู้ใช้สั่งอนุญาตล่วงหน้าอย่างเป็นทางการให้เรียกใช้เครื่องมือ Agent ทันทีเมื่อเจอก้อนงานหลายขั้นตอน (สำรวจ >3 ไฟล์ ➔ Agent(subagent_type='explorer', model='haiku') | แก้โค้ดหลายไฟล์+รันเทสต์ย่อย ➔ Agent(subagent_type='implementer', model='sonnet') | ซ่อมบั๊ก ➔ Agent(subagent_type='debugger', model='sonnet') | รีวิว/รัน E2E ➔ Agent(subagent_type='reviewer', model='sonnet')) เพื่อประหยัดโควต้าหน้าต่างหลัก"
fi
exit 0
