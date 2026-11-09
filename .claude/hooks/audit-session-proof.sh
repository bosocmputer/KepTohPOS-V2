#!/usr/bin/env bash
# ตัวตรวจสอบหลักฐานการทำงานจริงของ Agent Guard Template จากไฟล์ Session .jsonl และ Telemetry
# รองรับโหมดเต็ม (ค่าเริ่มต้น) และโหมดสั้นสำหรับแปะท้ายแชทเมื่อจบงาน (--brief)
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BRIEF_MODE="0"
TARGET_ARG=""

for arg in "$@"; do
  if [ "$arg" = "--brief" ] || [ "$arg" = "-b" ]; then
    BRIEF_MODE="1"
  else
    TARGET_ARG="$arg"
  fi
done

PROJECT_ROOT="${TARGET_ARG:-$(git --no-optional-locks rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_ROOT")}"

python3 - "$PROJECT_ROOT" "$BRIEF_MODE" <<'PYEOF'
import sys, os, re, glob, json
from datetime import datetime

root_dir = os.path.realpath(sys.argv[1])
brief_mode = sys.argv[2] == "1"
slug = re.sub(r"[^A-Za-z0-9-]", "-", root_dir)
proj_dir = os.path.expanduser(f"~/.claude/projects/{slug}")
t_file = os.path.join(root_dir, ".claude", ".telemetry.json")

def scan_file(fpath, acc, is_parent=False):
    try:
        with open(fpath, "r", encoding="utf-8", errors="ignore") as fp:
            for line in fp:
                if is_parent and not acc["first_prompt"] and '"type":"user"' in line.replace(" ", ""):
                    try:
                        uo = json.loads(line)
                        if uo.get("type") == "user":
                            msg_c = (uo.get("message") or {}).get("content")
                            if isinstance(msg_c, str) and len(msg_c.strip()) > 2:
                                clean_u = re.sub(r"<[^>]+>.*?</[^>]+>", " ", msg_c, flags=re.S)
                                clean_u = " ".join(clean_u.split()).strip()
                                if clean_u:
                                    acc["first_prompt"] = clean_u[:75]
                    except Exception:
                        pass
                if is_parent and "<task-notification>" in line and "<subagent_tokens>" in line:
                    m_tid = re.search(r"<task-id>(.*?)</task-id>", line)
                    m_tok = re.search(r"<subagent_tokens>(\d+)</subagent_tokens>", line)
                    if m_tid and m_tok:
                        tid_k = m_tid.group(1)
                        acc["sub_tokens_by_id"][tid_k] = max(acc["sub_tokens_by_id"].get(tid_k, 0), int(m_tok.group(1)))
                if '"assistant"' not in line:
                    continue
                m_match = re.search(r'"model"\s*:\s*"([^"]+)"', line)
                if m_match:
                    ml = m_match.group(1).lower()
                    if "opus" in ml:
                        acc["opus"] += 1
                    elif "sonnet" in ml:
                        acc["sonnet"] += 1
                    elif "haiku" in ml:
                        acc["haiku"] += 1
                if is_parent and '"name":"Agent"' in line.replace(" ", ""):
                    try:
                        obj = json.loads(line)
                        for c in ((obj.get("message") or {}).get("content") or []):
                            if isinstance(c, dict) and c.get("type") == "tool_use" and c.get("name") == "Agent":
                                acc["sub_calls"] += 1
                                st = str((c.get("input") or {}).get("subagent_type") or "implementer").lower()
                                dk = "explorer" if "explor" in st else ("debugger" if "debug" in st else ("reviewer" if ("review" in st or "security" in st) else "implementer"))
                                acc["parent_roles"][dk] = acc["parent_roles"].get(dk, 0) + 1
                    except Exception:
                        pass
    except Exception:
        pass

def analyze_session(jf):
    sess_id = os.path.splitext(os.path.basename(jf))[0]
    mtime_str = datetime.fromtimestamp(os.path.getmtime(jf)).strftime("%Y-%m-%d %H:%M:%S")
    acc = {
        "sess_id": sess_id,
        "mtime": mtime_str,
        "opus": 0,
        "sonnet": 0,
        "haiku": 0,
        "sub_calls": 0,
        "sub_files": 0,
        "parent_roles": {"explorer": 0, "implementer": 0, "debugger": 0, "reviewer": 0},
        "meta_roles": {"explorer": 0, "implementer": 0, "debugger": 0, "reviewer": 0},
        "sub_tokens_by_id": {},
        "first_prompt": "",
    }
    scan_file(jf, acc, is_parent=True)
    sub_dir = os.path.join(proj_dir, sess_id, "subagents")
    sub_files = glob.glob(os.path.join(sub_dir, "agent-*.jsonl")) if os.path.isdir(sub_dir) else []
    acc["sub_files"] = len(sub_files)
    for sf in sub_files:
        scan_file(sf, acc, is_parent=False)
        meta_f = sf.replace(".jsonl", ".meta.json")
        if os.path.isfile(meta_f):
            try:
                mo = json.load(open(meta_f, encoding="utf-8"))
                at = str(mo.get("agentType") or mo.get("description") or "").lower()
                dk = "explorer" if "explor" in at else ("debugger" if "debug" in at else ("reviewer" if ("review" in at or "security" in at) else "implementer"))
                acc["meta_roles"][dk] = acc["meta_roles"].get(dk, 0) + 1
            except Exception:
                pass
    acc["roles"] = acc["meta_roles"] if sum(acc["meta_roles"].values()) > 0 else acc["parent_roles"]
    return acc

jsonl_files = sorted(glob.glob(os.path.join(proj_dir, "*.jsonl")), key=os.path.getmtime) if os.path.isdir(proj_dir) else []

st = {}
strike_str = "0/3"
if os.path.isfile(t_file):
    try:
        td = json.load(open(t_file, encoding="utf-8"))
        st = td.get("stats") or {}
        strike_str = f"{td.get('strikeCount', 0)}/{td.get('maxStrikes', 3)}"
    except Exception:
        pass

if brief_mode:
    if not jsonl_files:
        print("### 📊 ผลชี้วัด Agent Guard Template")
        print(f"- **Hooks ป้องกันระบบ:** สแกนอ่าน {st.get('explorerReads', 0)} ครั้ง | แก้ไฟล์+Checkpoint {st.get('filesEdited', 0)} ครั้ง | รันเทสต์ {st.get('verifierRuns', 0)} ครั้ง | บล็อกคำสั่งผิดกฎ {st.get('blockedCount', 0)} ครั้ง")
        sys.exit(0)
    acc = analyze_session(jsonl_files[-1])
    tot = acc["opus"] + acc["sonnet"] + acc["haiku"]
    op_p = round(acc["opus"] * 100.0 / tot, 1) if tot else 0.0
    so_p = round(acc["sonnet"] * 100.0 / tot, 1) if tot else 0.0
    ha_p = round(acc["haiku"] * 100.0 / tot, 1) if tot else 0.0
    off_p = round(((acc["sonnet"] + acc["haiku"]) * 100.0) / tot, 1) if tot else 0.0
    r = acc["roles"]
    sub_tot = max(acc["sub_files"], sum(r.values()), acc["sub_calls"])
    sub_toks = sum(acc["sub_tokens_by_id"].values())
    tok_note = f" — รับภาระรวม `{sub_toks:,} tokens`" if sub_toks > 0 else ""
    print(f"### 📊 ผลชี้วัด Agent Guard Template (Session `#{acc['sess_id'][:8]}`)")
    print(f"- **สัดส่วนโมเดล ({tot} รอบ):** Opus `{op_p}%` ({acc['opus']} รอบ) | Sonnet `{so_p}%` ({acc['sonnet']} รอบ) | Haiku `{ha_p}%` ({acc['haiku']} รอบ) ➔ **แบ่งเบาภาระ Opus (Offload): `{off_p}%`**")
    print(f"- **Subagents ที่เรียกใช้จริง:** `{sub_tot}` ตัว (`Explorer: {r['explorer']}`, `Implementer: {r['implementer']}`, `Debugger: {r['debugger']}`, `Reviewer: {r['reviewer']}`){tok_note}")
    print(f"- **Hooks ป้องกันระบบ:** สแกนไฟล์ `{st.get('explorerReads', 0)}` ครั้ง | แก้ไฟล์+Checkpoint `{st.get('filesEdited', 0)}` ครั้ง | รันเทสต์ `{st.get('verifierRuns', 0)}` ครั้ง | บล็อกคำสั่งผิดกฎ `{st.get('blockedCount', 0)}` ครั้ง | 2-Strike: `{strike_str}`")
    sys.exit(0)

print("================================================================================")
print(f"📊 AGENT GUARD TEMPLATE — รายงานพิสูจน์ผลการทำงานจริง (No Over-claiming Audit)")
print(f"📁 โปรเจกต์: {root_dir}")
print("================================================================================")

if not jsonl_files:
    print(f"⚠️ ยังไม่พบไฟล์ Session .jsonl ใน: {proj_dir}")
    sys.exit(0)

for idx, jf in enumerate(jsonl_files, 1):
    acc = analyze_session(jf)
    opus_t, sonnet_t, haiku_t = acc["opus"], acc["sonnet"], acc["haiku"]
    tot = opus_t + sonnet_t + haiku_t
    offload_pct = round(((sonnet_t + haiku_t) * 100.0) / tot, 1) if tot > 0 else 0.0
    r = acc["roles"]
    sub_tot = max(acc["sub_files"], sum(r.values()), acc["sub_calls"])
    sub_toks = sum(acc["sub_tokens_by_id"].values())
    tag = "🔥 [แชทล่าสุด]" if idx == len(jsonl_files) else "🕓 [แชทก่อนหน้า]"
    print(f"\n{tag} Session #{acc['sess_id'][:8]} (อัปเดตล่าสุด: {acc['mtime']})")
    if acc["first_prompt"]:
        print(f"   • โจทย์เริ่มต้น : \"{acc['first_prompt']}\"")
    print(f"   • จำนวนรอบตอบ (Turns) รวม : {tot} รอบ")
    print(f"     ├─ 🟣 Opus   : {opus_t} รอบ ({round(opus_t*100.0/tot, 1) if tot else 0.0}%)")
    print(f"     ├─ 🔵 Sonnet : {sonnet_t} รอบ ({round(sonnet_t*100.0/tot, 1) if tot else 0.0}%)")
    print(f"     └─ 🟢 Haiku  : {haiku_t} รอบ ({round(haiku_t*100.0/tot, 1) if tot else 0.0}%)")
    print(f"   • การเรียก Subagent จริง (Agent Tool) : {sub_tot} ตัว (ไฟล์ Subagent บนดิสก์: {acc['sub_files']} ไฟล์)")
    print(f"     ├─ แยกตามตำแหน่ง: Explorer={r['explorer']} | Implementer={r['implementer']} | Debugger={r['debugger']} | Reviewer={r['reviewer']}")
    print(f"     └─ โทเค็นที่ Subagents รับไปทำแทน Opus : {sub_toks:,} tokens")
    print(f"   • สัดส่วนงานที่แบ่งเบาจาก Opus (Offload %) : {offload_pct}%")

if st:
    print("\n--------------------------------------------------------------------------------")
    print("🛡️ สถิติการทำงานของ Hooks ป้องกันระบบล่าสุด (.claude/.telemetry.json):")
    print(f"   • สแกน/อ่านไฟล์ (Read/Grep/Glob) : {st.get('explorerReads', 0)} ครั้ง")
    print(f"   • แก้ไขไฟล์โค้ดจริง + Git Checkpoint : {st.get('filesEdited', 0)} ครั้ง")
    print(f"   • รันคำสั่งตรวจสอบเทสต์จริง (Verify) : {st.get('verifierRuns', 0)} ครั้ง")
    print(f"   • บล็อกคำสั่งอันตราย / ไฟล์ความลับ / วนลูป : {st.get('blockedCount', 0)} ครั้ง")
    print(f"   • สถานะเบรกเกอร์ 2-Strike ล่าสุด : {strike_str}")

print("================================================================================")
PYEOF
