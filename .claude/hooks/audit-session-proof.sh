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
import sys, os, re, glob, json, time, subprocess
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

def classify_ag_desk(sub_type, sub_role):
    comb = (str(sub_type or "") + " " + str(sub_role or "")).lower()
    if any(k in comb for k in ("explor", "research", "auditor", "scout")):
        return "explorer"
    if any(k in comb for k in ("debug", "fix", "strike")):
        return "debugger"
    if any(k in comb for k in ("review", "qa", "verif", "browser", "security")):
        return "reviewer"
    return "implementer"

def scan_ag_file(fpath):
    res = {
        "turns": 0,
        "steps": 0,
        "tokens": 0,
        "first_prompt": "",
        "is_subagent": False,
        "parent_cid": "",
        "invoke_specs": [],
        "spawned_subs": [],
        "checkpoint_subs": [],
        "browser_facts": {},
        "step_refs": {},
    }
    if not fpath:
        return res
    cand = os.path.join(os.path.dirname(fpath), "transcript.jsonl")
    use_p = cand if os.path.isfile(cand) else fpath
    if not os.path.isfile(use_p):
        return res
    try:
        has_user_explicit = False
        with open(use_p, "r", encoding="utf-8", errors="ignore") as fp:
            for idx, line in enumerate(fp):
                res["steps"] += 1
                if idx < 8:
                    if '"USER_EXPLICIT"' in line and '"USER_INPUT"' in line:
                        has_user_explicit = True
                        try:
                            uo = json.loads(line)
                            raw_c = str(uo.get("content") or "")
                            m_req = re.search(r"<USER_REQUEST>(.*?)</USER_REQUEST>", raw_c, flags=re.S)
                            txt_c = m_req.group(1) if m_req else raw_c
                            txt_c = re.sub(r"<[^>]+>.*?</[^>]+>", " ", txt_c, flags=re.S)
                            txt_c = " ".join(txt_c.split()).strip()
                            if txt_c:
                                res["first_prompt"] = txt_c[:75]
                        except Exception:
                            pass
                    elif not has_user_explicit and (('"SYSTEM_MESSAGE"' in line and "sender=" in line) or ("You are a subagent" in line)):
                        m_snd = re.search(r"(?:sender=|conversation_id is )([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})", line)
                        if m_snd:
                            res["parent_cid"] = m_snd.group(1)
                            res["is_subagent"] = True
                if '"CHECKPOINT"' in line and "Subagents" in line:
                    try:
                        co = json.loads(line)
                        raw_cp = str(co.get("content") or "")
                        for m_cp in re.finditer(
                            r'\{\s*"spec"\s*:\s*\{\s*"typeName"\s*:\s*"([^"]+)"\s*,\s*"role"\s*:\s*"([^"]+)"\s*\}\s*,\s*"result"\s*:\s*\{\s*"conversationId"\s*:\s*"([0-9a-f-]{36})"\s*,\s*"logAbsoluteUri"\s*:\s*"([^"]+)"',
                            raw_cp,
                        ):
                            st = m_cp.group(1).strip().lower()
                            sr = m_cp.group(2).strip()
                            scid = m_cp.group(3).strip()
                            suri = m_cp.group(4).strip().replace("file://", "")
                            res["checkpoint_subs"].append({
                                "cid": scid,
                                "uri": suri,
                                "type": st,
                                "model": "flash" if ("research" in st or "browser" in st) else "inherit",
                                "role": sr,
                                "desk": classify_ag_desk(st, sr),
                            })
                    except Exception:
                        pass
                if '"PLANNER_RESPONSE"' in line:
                    try:
                        obj = json.loads(line)
                        if obj.get("type") == "PLANNER_RESPONSE":
                            res["turns"] += 1
                            res["tokens"] += int(obj.get("input_tokens") or 0) + int(obj.get("cache_read_tokens") or 0) + int(obj.get("output_tokens") or 0)
                            for tc in (obj.get("tool_calls") or []):
                                if isinstance(tc, dict) and tc.get("name") == "invoke_subagent":
                                    args = tc.get("args") or {}
                                    st = str(args.get("TypeName") or "self").strip('"').lower()
                                    sm = str(args.get("Model") or ("flash" if ("research" in st or "browser" in st) else "inherit")).strip('"').lower()
                                    sr = str(args.get("Role") or st).strip('"')
                                    res["invoke_specs"].append({
                                        "type": st,
                                        "model": sm,
                                        "role": sr,
                                        "desk": classify_ag_desk(st, sr),
                                    })
                    except Exception:
                        pass
                elif "Created the following subagent:" in line:
                    m_scid = re.search(r'\\"conversationId\\"\s*:\s*\\"([0-9a-f-]{36})\\"', line) or re.search(r'"conversationId"\s*:\s*"([0-9a-f-]{36})"', line)
                    m_suri = re.search(r'\\"logAbsoluteUri\\"\s*:\s*\\"([^\\"]+)\\"', line) or re.search(r'"logAbsoluteUri"\s*:\s*"([^"]+)"', line)
                    if m_scid:
                        res["spawned_subs"].append({
                            "cid": m_scid.group(1),
                            "uri": (m_suri.group(1) if m_suri else "").replace("file://", ""),
                        })
                if "BROWSER_HOST_FACTS" in line:
                    m_bf = re.search(r"\[BROWSER_HOST_FACTS\s+subagent=([0-9a-f-]{36})\]", line)
                    if m_bf:
                        bf_cid = m_bf.group(1)
                        m_fstep = re.search(r"final_step_(\d+)\.png", line)
                        f_steps = int(m_fstep.group(1)) if m_fstep else 2
                        res["browser_facts"][bf_cid] = max(res["browser_facts"].get(bf_cid, 0), f_steps)
                if ".system_generated/steps/" in line:
                    for m_sr in re.finditer(r"\.gemini/antigravity/brain/([0-9a-f-]{36})/\.system_generated/steps/(\d+)/", line):
                        sr_cid = m_sr.group(1)
                        sr_step = int(m_sr.group(2))
                        res["step_refs"][sr_cid] = max(res["step_refs"].get(sr_cid, 0), sr_step)
    except Exception:
        pass
    return res

def analyze_ag_session(cid, p_cached, ag_map):
    tpath = p_cached.get("transcriptPath") or os.path.expanduser(f"~/.gemini/antigravity/brain/{cid}/.system_generated/logs/transcript.jsonl")
    cand = os.path.join(os.path.dirname(tpath), "transcript.jsonl") if tpath else ""
    use_p = cand if (cand and os.path.isfile(cand)) else (tpath if (tpath and os.path.isfile(tpath)) else "")
    live = scan_ag_file(use_p) if use_p else {"turns": 0, "steps": 0, "tokens": 0, "first_prompt": "", "invoke_specs": [], "spawned_subs": [], "checkpoint_subs": [], "browser_facts": {}, "step_refs": {}}

    epoch = os.path.getmtime(use_p) if use_p else float(p_cached.get("epoch") or 0)
    mtime_str = datetime.fromtimestamp(epoch).strftime("%Y-%m-%d %H:%M:%S") if epoch > 0 else (p_cached.get("mtime") or "")
    p_turns = live["turns"] or int(p_cached.get("turns") or 0)
    p_steps = live["steps"] or int(p_cached.get("steps") or 0)
    first_p = live["first_prompt"] or p_cached.get("firstPrompt") or ""
    specs = live["invoke_specs"] if live["invoke_specs"] else (p_cached.get("invokeSpecs") or [])

    subs_dict = dict(p_cached.get("subagents") or {})
    ref_steps_map = {}

    def ingest_scanned_subs(scanned_data, fallback_specs=None):
        for cp in (scanned_data.get("checkpoint_subs") or []):
            scid = cp["cid"]
            s_entry = dict(subs_dict.get(scid) or {"cid": scid})
            if cp.get("uri") and not s_entry.get("uri"):
                s_entry["uri"] = cp["uri"]
            for k in ("type", "model", "role", "desk"):
                if cp.get(k) and not s_entry.get(k):
                    s_entry[k] = cp[k]
            subs_dict[scid] = s_entry
        use_specs = scanned_data.get("invoke_specs") or fallback_specs or []
        for idx, sp in enumerate(scanned_data.get("spawned_subs") or []):
            scid = sp["cid"]
            s_entry = dict(subs_dict.get(scid) or {"cid": scid})
            if sp.get("uri"):
                s_entry["uri"] = sp["uri"]
            if idx < len(use_specs):
                s_entry["type"] = use_specs[idx]["type"]
                s_entry["model"] = use_specs[idx]["model"]
                s_entry["role"] = use_specs[idx]["role"]
                s_entry["desk"] = use_specs[idx]["desk"]
            subs_dict[scid] = s_entry
        for bf_cid, bf_st in (scanned_data.get("browser_facts") or {}).items():
            ref_steps_map[bf_cid] = max(ref_steps_map.get(bf_cid, 0), bf_st)
        for sr_cid, sr_st in (scanned_data.get("step_refs") or {}).items():
            ref_steps_map[sr_cid] = max(ref_steps_map.get(sr_cid, 0), sr_st)

    ingest_scanned_subs(live, fallback_specs=specs)

    scanned_sub_cids = set()
    for _pass in range(2):
        for scid in list(subs_dict.keys()):
            if scid in scanned_sub_cids:
                continue
            scanned_sub_cids.add(scid)
            sinfo = dict(subs_dict[scid])
            s_uri = sinfo.get("uri") or os.path.expanduser(f"~/.gemini/antigravity/brain/{scid}/.system_generated/logs/transcript.jsonl")
            if os.path.isfile(s_uri):
                s_live = scan_ag_file(s_uri)
                if s_live["turns"] > 0:
                    sinfo["turns"] = s_live["turns"]
                    sinfo["steps"] = s_live["steps"]
                    sinfo["tokens"] = s_live["tokens"]
                subs_dict[scid] = sinfo
                ingest_scanned_subs(s_live)

    roles = {"explorer": 0, "implementer": 0, "debugger": 0, "reviewer": 0}
    if len(subs_dict) >= len(specs) and len(subs_dict) > 0:
        for scid, sinfo in subs_dict.items():
            dk = sinfo.get("desk") or classify_ag_desk(str(sinfo.get("type") or ""), str(sinfo.get("role") or ""))
            roles[dk] = roles.get(dk, 0) + 1
    else:
        for sp in specs:
            dk = sp.get("desk") or "implementer"
            roles[dk] = roles.get(dk, 0) + 1

    self_turns = 0
    flash_turns = 0
    sub_steps = 0
    sub_tokens_by_id = {}
    for scid, sinfo in subs_dict.items():
        sturns = int(sinfo.get("turns") or 0)
        ssteps = int(sinfo.get("steps") or 0)
        stoks = int(sinfo.get("tokens") or 0)
        if sturns == 0:
            ref_st = max(int(sinfo.get("refSteps") or 0), int(ref_steps_map.get(scid) or 0))
            if ref_st > 0:
                ssteps = max(ssteps, ref_st)
                sturns = max(1, (ref_st + 1) // 2)
            else:
                sturns = 1
                ssteps = max(ssteps, 1)
        stype = str(sinfo.get("type") or "").lower()
        smod = str(sinfo.get("model") or ("flash" if ("research" in stype or "browser" in stype) else "inherit")).lower()
        sinfo["turns"] = sturns
        sinfo["steps"] = ssteps
        sinfo["model"] = smod
        if not sinfo.get("desk"):
            sinfo["desk"] = classify_ag_desk(stype, str(sinfo.get("role") or ""))
        subs_dict[scid] = sinfo
        if "flash" in smod:
            flash_turns += sturns
        else:
            self_turns += sturns
        sub_steps += ssteps
        if stoks > 0:
            sub_tokens_by_id[scid] = stoks

    if subs_dict != (p_cached.get("subagents") or {}):
        p_cached["subagents"] = subs_dict
        p_cached["_dirty"] = True

    return {
        "engine": "antigravity",
        "sess_id": cid,
        "mtime": mtime_str,
        "epoch": epoch,
        "opus": p_turns,
        "sonnet": self_turns,
        "haiku": flash_turns,
        "parent_steps": p_steps,
        "sub_steps": sub_steps,
        "sub_calls": max(len(specs), len(subs_dict)),
        "sub_files": len(subs_dict),
        "roles": roles,
        "sub_tokens_by_id": sub_tokens_by_id,
        "first_prompt": first_p,
    }

jsonl_files = sorted(glob.glob(os.path.join(proj_dir, "*.jsonl")), key=os.path.getmtime) if os.path.isdir(proj_dir) else []

st = {}
strike_str = "0/3"
td = {}
if os.path.isfile(t_file):
    try:
        td = json.load(open(t_file, encoding="utf-8"))
        st = td.get("stats") or {}
        strike_str = f"{td.get('strikeCount', 0)}/{td.get('maxStrikes', 3)}"
    except Exception:
        pass

all_sessions = []
for jf in jsonl_files:
    c_acc = analyze_session(jf)
    c_acc["engine"] = "claude"
    c_acc["epoch"] = os.path.getmtime(jf)
    all_sessions.append(c_acc)

ag_map = td.get("agSessions") if isinstance(td.get("agSessions"), dict) else {}
last_cid = str(td.get("lastConversationId") or "")
last_tpath = str(td.get("lastTranscriptPath") or "")
if not ag_map and not last_cid:
    sb_cands = glob.glob(os.path.expanduser("~/.gemini/antigravity/brain/*/.system_generated/logs/transcript.jsonl"))
    if len(sb_cands) == 1:
        m_sbc = re.search(r"/brain/([0-9a-f-]{36})/", sb_cands[0])
        if m_sbc:
            last_cid = m_sbc.group(1)
            last_tpath = sb_cands[0]
if last_cid and last_cid not in ag_map and last_tpath:
    # ตรวจสอบว่าไฟล์นี้เป็น Parent หรือ Subagent
    probe = scan_ag_file(last_tpath)
    if probe.get("is_subagent") and probe.get("parent_cid"):
        p_id = probe["parent_cid"]
        p_tpath = os.path.expanduser(f"~/.gemini/antigravity/brain/{p_id}/.system_generated/logs/transcript.jsonl")
        ag_map[p_id] = {"cid": p_id, "isParent": True, "transcriptPath": p_tpath, "epoch": time.time() if "time" in sys.modules else 0, "subagents": {last_cid: {"cid": last_cid, "turns": probe["turns"], "steps": probe["steps"], "tokens": probe["tokens"]}}}
    else:
        ag_map[last_cid] = {"cid": last_cid, "isParent": True, "transcriptPath": last_tpath}

ag_dirty = False
for ag_cid, ag_info in ag_map.items():
    if isinstance(ag_info, dict) and ag_info.get("isParent", True):
        ag_acc = analyze_ag_session(ag_cid, ag_info, ag_map)
        if ag_info.pop("_dirty", False):
            ag_dirty = True
        if ag_acc["opus"] > 0 or ag_acc["sub_calls"] > 0 or ag_acc["sub_files"] > 0:
            all_sessions.append(ag_acc)

if ag_dirty and os.path.isfile(t_file):
    try:
        td["agSessions"] = ag_map
        with open(t_file, "w", encoding="utf-8") as fp_out:
            json.dump(td, fp_out, indent=2, ensure_ascii=False)
    except Exception:
        pass

all_sessions.sort(key=lambda x: x.get("epoch") or 0)

def scan_pitfalls(r_dir):
    pf_path = os.path.join(r_dir, ".claude", "rules", "project-pitfalls.md")
    rules = []
    if os.path.isfile(pf_path):
        try:
            with open(pf_path, "r", encoding="utf-8", errors="ignore") as fp:
                for ln in fp:
                    s = ln.strip()
                    if s.startswith("- **["):
                        rules.append(s[2:].strip())
        except Exception:
            pass
    added_recent = []
    for diff_cmd in (
        ["git", "--no-optional-locks", "diff", "HEAD", "--", ".claude/rules/project-pitfalls.md"],
        ["git", "--no-optional-locks", "diff", "HEAD~1", "HEAD", "--", ".claude/rules/project-pitfalls.md"],
    ):
        try:
            out = subprocess.check_output(diff_cmd, cwd=r_dir, stderr=subprocess.DEVNULL, timeout=1.5).decode("utf-8", errors="ignore")
            for ln in out.splitlines():
                if ln.startswith("+- **["):
                    added_recent.append(ln[3:].strip())
            if added_recent:
                break
        except Exception:
            pass
    def short_rule(r_txt):
        return r_txt if len(r_txt) <= 115 else r_txt[:112] + "..."
    return {
        "count": len(rules),
        "all": rules,
        "added_recent": [short_rule(x) for x in added_recent],
        "latest": short_rule(rules[-1]) if rules else "",
    }

def sync_task_state(r_dir):
    ts_path = os.path.join(r_dir, "TASK_STATE.md")
    marker = "## 🔄 Auto-Synced Git & Session State"
    branch = "main"
    head_sha = ""
    commits = []
    dirty = []
    try:
        branch = subprocess.check_output(["git", "--no-optional-locks", "rev-parse", "--abbrev-ref", "HEAD"], cwd=r_dir, stderr=subprocess.DEVNULL, timeout=1.5).decode("utf-8", errors="ignore").strip() or "main"
        head_sha = subprocess.check_output(["git", "--no-optional-locks", "rev-parse", "--short", "HEAD"], cwd=r_dir, stderr=subprocess.DEVNULL, timeout=1.5).decode("utf-8", errors="ignore").strip()
        log_out = subprocess.check_output(["git", "--no-optional-locks", "log", "--oneline", "-n", "5"], cwd=r_dir, stderr=subprocess.DEVNULL, timeout=1.5).decode("utf-8", errors="ignore").strip()
        commits = [c.strip() for c in log_out.splitlines() if c.strip()]
        st_out = subprocess.check_output(["git", "--no-optional-locks", "status", "--short"], cwd=r_dir, stderr=subprocess.DEVNULL, timeout=1.5).decode("utf-8", errors="ignore").strip()
        dirty = [d.strip() for d in st_out.splitlines() if d.strip() and not d.strip().endswith("TASK_STATE.md")][:6]
    except Exception:
        pass
    last_ckpt = ""
    ckpt_file = os.path.join(r_dir, ".agent-last-state.log")
    if os.path.isfile(ckpt_file):
        try:
            with open(ckpt_file, "r", encoding="utf-8", errors="ignore") as f:
                last_ckpt = f.read().strip().replace("\n", " ")
        except Exception:
            pass
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    auto_lines = [
        f"{marker} (Updated: {now_str})",
        f"- **Branch & HEAD:** `{branch}` (`{head_sha or 'uncommitted'}`)",
    ]
    if last_ckpt:
        auto_lines.append(f"- **Last Edit Checkpoint:** `{last_ckpt}`")
    if dirty:
        auto_lines.append(f"- **Uncommitted Changes:** `{'; '.join(dirty)}`")
    else:
        auto_lines.append("- **Working Tree:** `clean`")
    if commits:
        auto_lines.append("- **Recent Commits (`git log -n 5`):**")
        for c in commits:
            auto_lines.append(f"  - `{c}`")
    auto_block = "\n".join(auto_lines) + "\n"
    base_content = ""
    if os.path.isfile(ts_path):
        try:
            with open(ts_path, "r", encoding="utf-8", errors="ignore") as f:
                raw = f.read()
            if marker in raw:
                base_content = raw.split(marker)[0].rstrip()
            else:
                base_content = raw.rstrip()
        except Exception:
            base_content = ""
    if not base_content:
        base_content = "# Active Task Handoff State\n- **Objective:** Resume from the latest Git state and checkpoints below."
    try:
        with open(ts_path, "w", encoding="utf-8") as f:
            f.write(base_content + "\n\n" + auto_block)
    except Exception:
        pass
    return f"`{branch}@{head_sha}`" if head_sha else "`synced`"

ts_badge = sync_task_state(root_dir)
pf_info = scan_pitfalls(root_dir)
if pf_info["added_recent"]:
    pf_brief_line = f"- **ความจำ & ส่งต่องาน:** Pitfalls `{pf_info['count']}/30` (**สกัดใหม่:** {pf_info['added_recent'][-1]}) | `TASK_STATE.md`: ✅ ซิงก์อัตโนมัติ ({ts_badge})"
elif pf_info["latest"]:
    pf_brief_line = f"- **ความจำ & ส่งต่องาน:** Pitfalls `{pf_info['count']}/30` (ล่าสุด: {pf_info['latest']}) | `TASK_STATE.md`: ✅ ซิงก์อัตโนมัติ ({ts_badge})"
else:
    pf_brief_line = f"- **ความจำ & ส่งต่องาน:** Pitfalls `0/30` ข้อ | `TASK_STATE.md`: ✅ ซิงก์อัตโนมัติ ({ts_badge})"

if brief_mode:
    if not all_sessions:
        print("### 📊 ผลชี้วัด Agent Guard Template")
        print(f"- **Hooks ป้องกันระบบ:** สแกนอ่าน {st.get('explorerReads', 0)} ครั้ง | แก้ไฟล์+Checkpoint {st.get('filesEdited', 0)} ครั้ง | รันเทสต์ {st.get('verifierRuns', 0)} ครั้ง | บล็อกคำสั่งผิดกฎ {st.get('blockedCount', 0)} ครั้ง")
        print(pf_brief_line)
        sys.exit(0)
    acc = all_sessions[-1]
    eng_lbl = "Antigravity " if acc.get("engine") == "antigravity" else ""
    tot = acc["opus"] + acc["sonnet"] + acc["haiku"]
    op_p = round(acc["opus"] * 100.0 / tot, 1) if tot else 0.0
    so_p = round(acc["sonnet"] * 100.0 / tot, 1) if tot else 0.0
    ha_p = round(acc["haiku"] * 100.0 / tot, 1) if tot else 0.0
    off_p = round(((acc["sonnet"] + acc["haiku"]) * 100.0) / tot, 1) if tot else 0.0
    r = acc["roles"]
    sub_tot = max(acc["sub_files"], sum(r.values()), acc["sub_calls"])
    sub_toks = sum(acc["sub_tokens_by_id"].values())
    tok_note = f" — รับภาระรวม `{sub_toks:,} tokens`" if sub_toks > 0 else ""
    print(f"### 📊 ผลชี้วัด Agent Guard Template ({eng_lbl}Session `#{acc['sess_id'][:8]}`)")
    if acc.get("engine") == "antigravity":
        if (acc["sonnet"] + acc["haiku"]) > 0:
            print(f"- **สัดส่วนโมเดล ({tot} รอบ):** Parent (Argon/Pro) `{op_p}%` ({acc['opus']} รอบ) | Subagents (Self) `{so_p}%` ({acc['sonnet']} รอบ) | Subagents (Flash) `{ha_p}%` ({acc['haiku']} รอบ) ➔ **แบ่งเบาภาระหน้าต่างหลัก (Offload): `{off_p}%`**")
        else:
            print(f"- **รอบทำงานหน้าต่างหลัก:** Parent (Argon/Pro) `{acc['opus']} รอบ` ({acc.get('parent_steps', 0)} steps) ➔ **กระจายงานให้ Subagents `{sub_tot}` ตัว**")
    else:
        print(f"- **สัดส่วนโมเดล ({tot} รอบ):** Opus `{op_p}%` ({acc['opus']} รอบ) | Sonnet `{so_p}%` ({acc['sonnet']} รอบ) | Haiku `{ha_p}%` ({acc['haiku']} รอบ) ➔ **แบ่งเบาภาระ Opus (Offload): `{off_p}%`**")
    print(f"- **Subagents ที่เรียกใช้จริง:** `{sub_tot}` ตัว (`Explorer: {r['explorer']}`, `Implementer: {r['implementer']}`, `Debugger: {r['debugger']}`, `Reviewer: {r['reviewer']}`){tok_note}")
    print(f"- **Hooks ป้องกันระบบ:** สแกนไฟล์ `{st.get('explorerReads', 0)}` ครั้ง | แก้ไฟล์+Checkpoint `{st.get('filesEdited', 0)}` ครั้ง | รันเทสต์ `{st.get('verifierRuns', 0)}` ครั้ง | บล็อกคำสั่งผิดกฎ `{st.get('blockedCount', 0)}` ครั้ง | 2-Strike: `{strike_str}`")
    print(pf_brief_line)
    sys.exit(0)

print("================================================================================")
print(f"📊 AGENT GUARD TEMPLATE — รายงานพิสูจน์ผลการทำงานจริง (No Over-claiming Audit)")
print(f"📁 โปรเจกต์: {root_dir}")
print("================================================================================")

if not all_sessions:
    print(f"⚠️ ยังไม่พบไฟล์ Session .jsonl ใน: {proj_dir}")
    sys.exit(0)

for idx, acc in enumerate(all_sessions, 1):
    opus_t, sonnet_t, haiku_t = acc["opus"], acc["sonnet"], acc["haiku"]
    tot = opus_t + sonnet_t + haiku_t
    offload_pct = round(((sonnet_t + haiku_t) * 100.0) / tot, 1) if tot > 0 else 0.0
    r = acc["roles"]
    sub_tot = max(acc["sub_files"], sum(r.values()), acc["sub_calls"])
    sub_toks = sum(acc["sub_tokens_by_id"].values())
    tag = "🔥 [แชทล่าสุด]" if idx == len(all_sessions) else "🕓 [แชทก่อนหน้า]"
    eng_tag = "Antigravity" if acc.get("engine") == "antigravity" else "Claude Code"
    m1_lbl = "Parent (Argon/Pro)" if acc.get("engine") == "antigravity" else "Opus  "
    m2_lbl = "Subagent (Self)   " if acc.get("engine") == "antigravity" else "Sonnet"
    m3_lbl = "Subagent (Flash)  " if acc.get("engine") == "antigravity" else "Haiku "
    print(f"\n{tag} [{eng_tag}] Session #{acc['sess_id'][:8]} (อัปเดตล่าสุด: {acc['mtime']})")
    if acc["first_prompt"]:
        print(f"   • โจทย์เริ่มต้น : \"{acc['first_prompt']}\"")
    print(f"   • จำนวนรอบตอบ (Turns) รวม : {tot} รอบ")
    print(f"     ├─ 🟣 {m1_lbl} : {opus_t} รอบ ({round(opus_t*100.0/tot, 1) if tot else 0.0}%)")
    print(f"     ├─ 🔵 {m2_lbl} : {sonnet_t} รอบ ({round(sonnet_t*100.0/tot, 1) if tot else 0.0}%)")
    print(f"     └─ 🟢 {m3_lbl} : {haiku_t} รอบ ({round(haiku_t*100.0/tot, 1) if tot else 0.0}%)")
    print(f"   • การเรียก Subagent จริง : {sub_tot} ตัว (ไฟล์ Subagent: {acc['sub_files']} ไฟล์)")
    print(f"     ├─ แยกตามตำแหน่ง: Explorer={r['explorer']} | Implementer={r['implementer']} | Debugger={r['debugger']} | Reviewer={r['reviewer']}")
    print(f"     └─ โทเค็นที่ Subagents รับไปทำแทนหน้าต่างหลัก : {sub_toks:,} tokens")
    print(f"   • สัดส่วนงานที่แบ่งเบาจากหน้าต่างหลัก (Offload %) : {offload_pct}%")

if st:
    print("\n--------------------------------------------------------------------------------")
    print("🛡️ สถิติการทำงานของ Hooks ป้องกันระบบล่าสุด (.claude/.telemetry.json):")
    print(f"   • สแกน/อ่านไฟล์ (Read/Grep/Glob) : {st.get('explorerReads', 0)} ครั้ง")
    print(f"   • แก้ไขไฟล์โค้ดจริง + Git Checkpoint : {st.get('filesEdited', 0)} ครั้ง")
    print(f"   • รันคำสั่งตรวจสอบเทสต์จริง (Verify) : {st.get('verifierRuns', 0)} ครั้ง")
    print(f"   • บล็อกคำสั่งอันตราย / ไฟล์ความลับ / วนลูป : {st.get('blockedCount', 0)} ครั้ง")
    print(f"   • สถานะเบรกเกอร์ 2-Strike ล่าสุด : {strike_str}")

print("\n--------------------------------------------------------------------------------")
print(f"🧠 ความจำระยะยาวเฉพาะโปรเจกต์ (.claude/rules/project-pitfalls.md — {pf_info['count']}/30 ข้อ):")
if pf_info["added_recent"]:
    for ar in pf_info["added_recent"]:
        print(f"   ✨ [สกัดใหม่ล่าสุด] {ar}")
elif pf_info["latest"]:
    print(f"   • ล่าสุด: {pf_info['latest']}")
else:
    print("   • ยังไม่มีบทเรียนเฉพาะโปรเจกต์")

print("================================================================================")
PYEOF
