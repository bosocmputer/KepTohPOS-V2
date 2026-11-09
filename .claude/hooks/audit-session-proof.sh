#!/usr/bin/env bash
# ตัวตรวจสอบหลักฐานการทำงานจริงของ Agent Guard Template จากไฟล์ Session .jsonl และ Telemetry
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_ROOT="${1:-$(git --no-optional-locks rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_ROOT")}"

python3 - "$PROJECT_ROOT" <<'PYEOF'
import sys, os, re, glob, json
from datetime import datetime

root_dir = os.path.realpath(sys.argv[1])
slug = re.sub(r"[^A-Za-z0-9-]", "-", root_dir)
proj_dir = os.path.expanduser(f"~/.claude/projects/{slug}")
t_file = os.path.join(root_dir, ".claude", ".telemetry.json")

print("================================================================================")
print(f"📊 AGENT GUARD TEMPLATE — รายงานพิสูจน์ผลการทำงานจริง (No Over-claiming Audit)")
print(f"📁 โปรเจกต์: {root_dir}")
print("================================================================================")

if not os.path.isdir(proj_dir):
    print(f"⚠️ ยังไม่พบโฟลเดอร์ประวัติแชท Claude Code ที่: {proj_dir}")
    sys.exit(0)

jsonl_files = sorted(glob.glob(os.path.join(proj_dir, "*.jsonl")), key=os.path.getmtime)
if not jsonl_files:
    print(f"⚠️ ยังไม่พบไฟล์ Session .jsonl ใน: {proj_dir}")
    sys.exit(0)

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
                                acc["sub_roles"][dk] = acc["sub_roles"].get(dk, 0) + 1
                    except Exception:
                        pass
    except Exception:
        pass

for idx, jf in enumerate(jsonl_files, 1):
    sess_id = os.path.splitext(os.path.basename(jf))[0]
    mtime_str = datetime.fromtimestamp(os.path.getmtime(jf)).strftime("%Y-%m-%d %H:%M:%S")
    acc = {
        "opus": 0,
        "sonnet": 0,
        "haiku": 0,
        "sub_calls": 0,
        "sub_roles": {"explorer": 0, "implementer": 0, "debugger": 0, "reviewer": 0},
        "first_prompt": "",
    }
    scan_file(jf, acc, is_parent=True)
    sub_dir = os.path.join(proj_dir, sess_id, "subagents")
    sub_files = glob.glob(os.path.join(sub_dir, "agent-*.jsonl")) if os.path.isdir(sub_dir) else []
    for sf in sub_files:
        scan_file(sf, acc, is_parent=False)
        meta_f = sf.replace(".jsonl", ".meta.json")
        if acc["sub_calls"] == 0 and os.path.isfile(meta_f):
            try:
                mo = json.load(open(meta_f, encoding="utf-8"))
                at = str(mo.get("agentType") or "").lower()
                dk = "explorer" if "explor" in at else ("debugger" if "debug" in at else ("reviewer" if ("review" in at or "security" in at) else "implementer"))
                acc["sub_roles"][dk] = acc["sub_roles"].get(dk, 0) + 1
            except Exception:
                pass

    opus_t, sonnet_t, haiku_t = acc["opus"], acc["sonnet"], acc["haiku"]
    tot = opus_t + sonnet_t + haiku_t
    offload_pct = round(((sonnet_t + haiku_t) * 100.0) / tot, 1) if tot > 0 else 0.0
    tag = "🔥 [แชทล่าสุด]" if idx == len(jsonl_files) else "🕓 [แชทก่อนหน้า]"
    print(f"\n{tag} Session #{sess_id[:8]} (อัปเดตล่าสุด: {mtime_str})")
    if acc["first_prompt"]:
        print(f"   • โจทย์เริ่มต้น : \"{acc['first_prompt']}\"")
    print(f"   • จำนวนรอบตอบ (Turns) รวม : {tot} รอบ")
    print(f"     ├─ 🟣 Opus   : {opus_t} รอบ ({round(opus_t*100.0/tot, 1) if tot else 0.0}%)")
    print(f"     ├─ 🔵 Sonnet : {sonnet_t} รอบ ({round(sonnet_t*100.0/tot, 1) if tot else 0.0}%)")
    print(f"     └─ 🟢 Haiku  : {haiku_t} รอบ ({round(haiku_t*100.0/tot, 1) if tot else 0.0}%)")
    print(f"   • การเรียก Subagent จริง (Agent Tool) : {max(acc['sub_calls'], len(sub_files))} ครั้ง (ไฟล์ Subagent บนดิสก์: {len(sub_files)} ไฟล์)")
    print(f"     └─ แยกตามตำแหน่ง: Explorer={acc['sub_roles']['explorer']} | Implementer={acc['sub_roles']['implementer']} | Debugger={acc['sub_roles']['debugger']} | Reviewer={acc['sub_roles']['reviewer']}")
    print(f"   • สัดส่วนงานที่แบ่งเบาจาก Opus (Offload %) : {offload_pct}%")

if os.path.isfile(t_file):
    try:
        td = json.load(open(t_file, encoding="utf-8"))
        st = td.get("stats") or {}
        print("\n--------------------------------------------------------------------------------")
        print("🛡️ สถิติการทำงานของ Hooks ป้องกันระบบล่าสุด (.claude/.telemetry.json):")
        print(f"   • สแกน/อ่านไฟล์ (Read/Grep/Glob) : {st.get('explorerReads', 0)} ครั้ง")
        print(f"   • แก้ไขไฟล์โค้ดจริง + Git Checkpoint : {st.get('filesEdited', 0)} ครั้ง")
        print(f"   • รันคำสั่งตรวจสอบเทสต์จริง (Verify) : {st.get('verifierRuns', 0)} ครั้ง")
        print(f"   • บล็อกคำสั่งอันตราย / ไฟล์ความลับ / วนลูป : {st.get('blockedCount', 0)} ครั้ง")
        print(f"   • สถานะเบรกเกอร์ 2-Strike ล่าสุด : {td.get('strikeCount', 0)}/{td.get('maxStrikes', 3)}")
    except Exception:
        pass

print("================================================================================")
PYEOF
