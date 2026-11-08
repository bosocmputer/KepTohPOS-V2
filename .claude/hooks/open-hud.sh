#!/usr/bin/env bash
# 3D Command & Monitor Center Launcher (Zero-Install Python Server + RELAY Quota Engine + Direct CLI Dispatch)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 1

export PATH="$HOME/.gemini/bin:$HOME/.local/bin:$HOME/.agents/bin:$PATH"
PORT="${1:-4317}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "❌ ต้องมี python3 ในเครื่องเพื่อรันเซิร์ฟเวอร์ 3D HUD" >&2
  exit 1
fi

# สร้างไฟล์ Telemetry เริ่มต้นหากยังไม่มี
if [ ! -f "$PROJECT_ROOT/.claude/.telemetry.json" ]; then
  bash "$PROJECT_ROOT/.claude/hooks/telemetry-tracker.sh" \
    --engine "claude" \
    --node "core" \
    --status "ready" \
    --detail "🟢 3D Command & Monitor Center Ready"
fi

python3 - "$PROJECT_ROOT" "$PORT" <<'PYEOF'
import sys, os, re, json, glob, time, shutil, socket, webbrowser, subprocess
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
from datetime import datetime, timezone
from concurrent.futures import ThreadPoolExecutor

PROJECT_ROOT = sys.argv[1]
START_PORT = int(sys.argv[2])
HUD_HTML = os.path.join(PROJECT_ROOT, ".claude", "hud", "index.html")
TELEMETRY_FILE = os.path.join(PROJECT_ROOT, ".claude", ".telemetry.json")
RELAY_QUOTA_CACHE = os.path.expanduser("~/.agents/relay-quota.cache")
LOCAL_QUOTA_CACHE = os.path.join(PROJECT_ROOT, ".claude", ".quota_cache.json")

TH_MONTHS = ["", "ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.", "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค."]

def fmt_dt_short(dt, is_weekly=False):
    if not dt:
        return "-"
    if is_weekly:
        return f"{dt.day:02d} {TH_MONTHS[dt.month]} {dt.strftime('%H:%M')}"
    return dt.strftime("%H:%M")

def check_provider_status():
    has_agy = shutil.which("agy") is not None
    agy_login = has_agy and (
        os.path.exists(os.path.expanduser("~/.gemini/jetski-standalone-oauth-token")) or
        os.path.exists(os.path.expanduser("~/.gemini/config/config.json"))
    )
    has_claude = shutil.which("claude") is not None
    claude_login = has_claude and (
        bool(os.environ.get("ANTHROPIC_API_KEY")) or
        os.path.exists(os.path.expanduser("~/.claude.json")) or
        os.path.exists(os.path.expanduser("~/.claude"))
    )
    has_codex = shutil.which("codex") is not None
    codex_login = has_codex and (
        bool(os.environ.get("OPENAI_API_KEY")) or
        os.path.exists(os.path.expanduser("~/.codex/auth.json"))
    )
    return {
        "agy": {"installed": has_agy, "loggedIn": agy_login},
        "claude": {"installed": has_claude, "loggedIn": claude_login},
        "codex": {"installed": has_codex, "loggedIn": codex_login},
    }

def load_relay_cache_file():
    vals = {}
    if os.path.exists(RELAY_QUOTA_CACHE):
        try:
            for line in open(RELAY_QUOTA_CACHE, encoding="utf-8", errors="ignore"):
                line = line.strip()
                if "=" in line and not line.startswith("#"):
                    k, v = line.split("=", 1)
                    vals[k.strip()] = v.strip().strip('"').strip("'")
        except Exception:
            pass
    return vals

def fetch_live_quotas(force=False):
    prov = check_provider_status()
    if not force and os.path.exists(LOCAL_QUOTA_CACHE):
        try:
            return json.load(open(LOCAL_QUOTA_CACHE, encoding="utf-8"))
        except Exception:
            pass

    relay_vals = load_relay_cache_file()
    if not force and relay_vals:
        res = build_quota_response_from_vals(relay_vals, prov)
        save_local_quota_cache(res)
        return res

    def fetch_agy():
        if not prov["agy"]["installed"]:
            return ""
        try:
            proc = subprocess.Popen(
                ["agy", "-p", "/usage"],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                close_fds=True,
            )
            out, _ = proc.communicate(timeout=12)
            return out.decode("utf-8", errors="ignore")
        except Exception:
            return ""

    def fetch_claude():
        if not prov["claude"]["installed"]:
            return ""
        try:
            req = b'{"type":"control_request","request_id":"1","request":{"subtype":"get_usage","skip_behaviors":true}}\n'
            proc = subprocess.Popen(
                ["claude", "-p", "--input-format", "stream-json", "--output-format", "stream-json", "--verbose"],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                close_fds=True,
            )
            out, _ = proc.communicate(input=req, timeout=12)
            return out.decode("utf-8", errors="ignore")
        except Exception:
            return ""

    with ThreadPoolExecutor(max_workers=2) as ex:
        f_agy = ex.submit(fetch_agy)
        f_claude = ex.submit(fetch_claude)
        raw_agy = f_agy.result()
        raw_claude = f_claude.result()

    vals = dict(relay_vals)
    vals["QUOTA_UPDATED_EPOCH"] = str(int(time.time()))
    vals["QUOTA_UPDATED_AT"] = datetime.now().strftime("%H:%M:%S")

    if raw_agy:
        for line in raw_agy.splitlines():
            m = re.search(
                r"^(Gemini Models|Claude and GPT models)\s+(Weekly Limit Remaining|Five Hour Limit Remaining)\s+(\d+)%\s+(\S+(?:\s+\S+)?)",
                line.strip(),
            )
            if m:
                group, win, pct, dt_str = m.group(1), m.group(2), m.group(3), m.group(4).strip()
                dt_obj = None
                try:
                    if "T" in dt_str:
                        dt_obj = datetime.fromisoformat(dt_str.replace("Z", "+00:00")).astimezone()
                    else:
                        dt_clean = re.sub(r"\s+[+-]\d+$", "", dt_str)
                        dt_obj = datetime.strptime(dt_clean, "%Y-%m-%d %H:%M")
                except Exception:
                    dt_obj = None
                is_wk = "Weekly" in win
                prefix = "AGY_GEMINI" if "Gemini" in group else "AGY_CLAUDE"
                win_key = "7D" if is_wk else "5H"
                vals[f"{prefix}_{win_key}_REM"] = pct
                vals[f"{prefix}_{win_key}_RESET"] = fmt_dt_short(dt_obj, is_weekly=is_wk)

    if raw_claude:
        for line in raw_claude.splitlines():
            if '"control_response"' in line and '"rate_limits"' in line:
                try:
                    obj = json.loads(line)
                    resp = ((obj.get("response") or {}).get("response")) or {}
                    st = resp.get("subscription_type")
                    if st:
                        vals["CLAUDE_PLAN"] = str(st).capitalize()
                    rl = resp.get("rate_limits") or {}
                    fh = rl.get("five_hour") or {}
                    sd = rl.get("seven_day") or {}
                    if fh.get("utilization") is not None:
                        rem5 = max(0, min(100, int(round(100.0 - float(fh["utilization"])))))
                        vals["CLAUDE_5H_REM"] = str(rem5)
                        if fh.get("resets_at"):
                            dt5 = datetime.fromisoformat(str(fh["resets_at"]).replace("Z", "+00:00")).astimezone()
                            vals["CLAUDE_5H_RESET"] = fmt_dt_short(dt5, is_weekly=False)
                        else:
                            vals["CLAUDE_5H_RESET"] = "พร้อมใช้"
                    if sd.get("utilization") is not None:
                        rem7 = max(0, min(100, int(round(100.0 - float(sd["utilization"])))))
                        vals["CLAUDE_7D_REM"] = str(rem7)
                        if sd.get("resets_at"):
                            dt7 = datetime.fromisoformat(str(sd["resets_at"]).replace("Z", "+00:00")).astimezone()
                            vals["CLAUDE_7D_RESET"] = fmt_dt_short(dt7, is_weekly=True)
                    break
                except Exception:
                    pass

    try:
        codex_files = sorted(glob.glob(os.path.expanduser("~/.codex/sessions/*/*/*/rollout-*.jsonl")))
        for cf in reversed(codex_files[-6:]):
            found = False
            for line in reversed(open(cf, encoding="utf-8", errors="ignore").readlines()):
                if '"rate_limits"' in line and '"token_count"' in line:
                    obj = json.loads(line)
                    rl = (obj.get("payload") or {}).get("rate_limits") or {}
                    prim = rl.get("primary") or {}
                    sec = rl.get("secondary") or {}
                    if prim.get("used_percent") is not None:
                        vals["CODEX_5H_REM"] = str(max(0, min(100, int(round(100.0 - float(prim["used_percent"]))))))
                    if sec.get("used_percent") is not None:
                        vals["CODEX_7D_REM"] = str(max(0, min(100, int(round(100.0 - float(sec["used_percent"]))))))
                    found = True
                    break
            if found:
                break
    except Exception:
        pass

    res = build_quota_response_from_vals(vals, prov)
    save_local_quota_cache(res)
    return res

def build_quota_response_from_vals(vals, prov):
    return {
        "epoch": int(time.time()),
        "updatedAt": vals.get("QUOTA_UPDATED_AT", datetime.now().strftime("%H:%M:%S")),
        "claude": {
            "installed": prov["claude"]["installed"],
            "loggedIn": prov["claude"]["loggedIn"],
            "plan": vals.get("CLAUDE_PLAN", "Pro"),
            "rem5h": vals.get("CLAUDE_5H_REM", "-"),
            "reset5h": vals.get("CLAUDE_5H_RESET", "-"),
            "rem7d": vals.get("CLAUDE_7D_REM", "-"),
            "reset7d": vals.get("CLAUDE_7D_RESET", "-"),
        },
        "agy": {
            "installed": prov["agy"]["installed"],
            "loggedIn": prov["agy"]["loggedIn"],
            "gemini5h": vals.get("AGY_GEMINI_5H_REM", "-"),
            "gemini5hReset": vals.get("AGY_GEMINI_5H_RESET", "-"),
            "gemini7d": vals.get("AGY_GEMINI_7D_REM", "-"),
            "gemini7dReset": vals.get("AGY_GEMINI_7D_RESET", "-"),
            "claude5h": vals.get("AGY_CLAUDE_5H_REM", "-"),
            "claude5hReset": vals.get("AGY_CLAUDE_5H_RESET", "-"),
            "claude7d": vals.get("AGY_CLAUDE_7D_REM", "-"),
            "claude7dReset": vals.get("AGY_CLAUDE_7D_RESET", "-"),
        },
        "codex": {
            "installed": prov["codex"]["installed"],
            "loggedIn": prov["codex"]["loggedIn"],
            "plan": vals.get("CODEX_PLAN", "Plus"),
            "rem5h": vals.get("CODEX_5H_REM", "-"),
            "reset5h": vals.get("CODEX_5H_RESET", "-"),
            "rem7d": vals.get("CODEX_7D_REM", "-"),
        },
    }

def save_local_quota_cache(data):
    try:
        os.makedirs(os.path.dirname(LOCAL_QUOTA_CACHE), exist_ok=True)
        with open(LOCAL_QUOTA_CACHE, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
    except Exception:
        pass

class HudHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def _send_json(self, obj, code=200):
        raw = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path in ("/", "/index.html"):
            if not os.path.exists(HUD_HTML):
                self.send_error(404, "HUD HTML not found")
                return
            raw = open(HUD_HTML, "rb").read()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)
            return

        if parsed.path == "/api/telemetry":
            state = {}
            if os.path.exists(TELEMETRY_FILE):
                try:
                    state = json.load(open(TELEMETRY_FILE, encoding="utf-8"))
                except Exception:
                    state = {}
            git_dirty = []
            try:
                out = subprocess.check_output(
                    ["git", "--no-optional-locks", "status", "--short"],
                    cwd=PROJECT_ROOT,
                    stderr=subprocess.DEVNULL,
                    timeout=2,
                ).decode("utf-8", errors="ignore")
                git_dirty = [line.strip() for line in out.splitlines() if line.strip()][:8]
            except Exception:
                pass
            checkpoint = ""
            cp_file = os.path.join(PROJECT_ROOT, ".agent-last-state.log")
            if os.path.exists(cp_file):
                try:
                    checkpoint = open(cp_file, encoding="utf-8", errors="ignore").read().strip()
                except Exception:
                    pass
            state["gitDirty"] = git_dirty
            state["checkpoint"] = checkpoint
            state["projectName"] = os.path.basename(PROJECT_ROOT)
            self._send_json(state)
            return

        if parsed.path == "/api/quota":
            qs = parse_qs(parsed.query)
            force = qs.get("refresh", ["0"])[0] == "1"
            self._send_json(fetch_live_quotas(force=force))
            return

        if parsed.path == "/api/workspace-catalog":
            # สแกนไฟล์จริงจากดิสก์ผ่าน telemetry-tracker.sh แล้วส่งกลับ
            if os.path.exists(TELEMETRY_FILE):
                try:
                    st = json.load(open(TELEMETRY_FILE, encoding="utf-8"))
                    if st.get("workspaceCatalog"):
                        self._send_json(st["workspaceCatalog"])
                        return
                except Exception:
                    pass
            subprocess.run(["bash", os.path.join(PROJECT_ROOT, ".claude", "hooks", "telemetry-tracker.sh"), "--engine", "claude", "--node", "core", "--status", "ready", "--detail", "Scanned Workspace Catalog"], cwd=PROJECT_ROOT)
            try:
                st = json.load(open(TELEMETRY_FILE, encoding="utf-8"))
                self._send_json(st.get("workspaceCatalog", {"items": [], "files": {}}))
            except Exception:
                self._send_json({"items": [], "files": {}})
            return

        if parsed.path == "/api/file":
            qs = parse_qs(parsed.query)
            rel = (qs.get("path", [""])[0] or "").strip().lstrip("/")
            if not rel or ".." in rel or re.search(r"(^|/)(\.env($|\.)|.*\.(pem|key|p12|keystore|jks|sqlite|db)$)", rel):
                self._send_json({"ok": False, "error": "ไม่อนุญาตให้อ่านไฟล์นี้"}, 403)
                return
            abs_p = os.path.realpath(os.path.join(PROJECT_ROOT, rel))
            if not abs_p.startswith(os.path.realpath(PROJECT_ROOT)) or not os.path.isfile(abs_p):
                self._send_json({"ok": False, "error": f"ไม่พบไฟล์ {rel}"}, 404)
                return
            try:
                content = open(abs_p, encoding="utf-8", errors="ignore").read()[:24000]
                self._send_json({"ok": True, "path": rel, "content": content})
            except Exception as e:
                self._send_json({"ok": False, "error": str(e)}, 500)
            return

        self.send_error(404, "Not found")

    def do_POST(self):
        parsed = urlparse(self.path)
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length).decode("utf-8", errors="ignore") if length > 0 else "{}"
        try:
            data = json.loads(body)
        except Exception:
            data = {}

        if parsed.path == "/api/simulate":
            engine = data.get("engine", "claude")
            node = data.get("node", "core")
            status = data.get("status", "working")
            detail = data.get("detail") or data.get("action") or "กำลังประมวลผลตามคำสั่ง..."
            file_arg = data.get("file", "")
            strike = str(data.get("strike", ""))
            model_arg = str(data.get("model", ""))
            skill_arg = str(data.get("skill", ""))
            cmd_arg = str(data.get("command") or data.get("promptFile") or "")
            rule_arg = str(data.get("rule") or data.get("ruleFile") or "")
            hook_arg = str(data.get("hook") or data.get("hookName") or "")
            prompt_arg = str(data.get("prompt", ""))
            cmd = [
                "bash",
                os.path.join(PROJECT_ROOT, ".claude", "hooks", "telemetry-tracker.sh"),
                "--engine", engine,
                "--node", node,
                "--status", status,
                "--detail", detail,
            ]
            if file_arg:
                cmd += ["--file", file_arg]
            if strike != "":
                cmd += ["--strike", strike]
            if model_arg != "":
                cmd += ["--model", model_arg]
            if skill_arg != "":
                cmd += ["--skill", skill_arg]
            if cmd_arg != "":
                cmd += ["--command", cmd_arg]
            if rule_arg != "":
                cmd += ["--rule", rule_arg]
            if hook_arg != "":
                cmd += ["--hook", hook_arg]
            if prompt_arg != "":
                cmd += ["--prompt", prompt_arg]
            subprocess.run(cmd, cwd=PROJECT_ROOT)
            self._send_json({"ok": True})
            return

        if parsed.path == "/api/prompt":
            engine = data.get("engine", "claude")
            model = data.get("model", "sonnet")
            prompt = (data.get("prompt") or "").strip()
            cont = bool(data.get("continueSession", True))
            if not prompt:
                self._send_json({"ok": False, "error": "กรุณาพิมพ์คำสั่งก่อนกดส่ง"}, 400)
                return

            # อัปเดต Telemetry ทันทีว่าเริ่มประมวลผลคำสั่งจาก 3D HUD
            tracker = os.path.join(PROJECT_ROOT, ".claude", "hooks", "telemetry-tracker.sh")
            subprocess.run([
                "bash", tracker,
                "--engine", engine,
                "--node", "core",
                "--status", "working",
                "--detail", f"🧠 [{engine.upper()} / {model}] {prompt[:80]}",
            ], cwd=PROJECT_ROOT)

            try:
                if os.path.exists(TELEMETRY_FILE):
                    st = json.load(open(TELEMETRY_FILE, encoding="utf-8"))
                    st["currentTask"] = prompt[:140]
                    st["activeModel"] = model
                    with open(TELEMETRY_FILE, "w", encoding="utf-8") as tf:
                        json.dump(st, tf, ensure_ascii=False, indent=2)
            except Exception:
                pass

            if engine == "antigravity":
                if not shutil.which("agy"):
                    self._send_json({"ok": False, "error": "ไม่พบคำสั่ง agy ในเครื่อง"}, 400)
                    return
                cmd = ["agy"]
                if cont:
                    cmd.append("-c")
                if model and model != "auto":
                    cmd += ["--model", model]
                cmd += ["--mode", "accept-edits", "-p", prompt]
            else:
                if not shutil.which("claude"):
                    self._send_json({"ok": False, "error": "ไม่พบคำสั่ง claude ในเครื่อง"}, 400)
                    return
                cmd = ["claude"]
                if cont:
                    cmd.append("-c")
                if model and model != "auto":
                    cmd += ["--model", model]
                cmd += ["--permission-mode", "acceptEdits", "-p", prompt]

            try:
                proc = subprocess.Popen(
                    cmd,
                    cwd=PROJECT_ROOT,
                    stdin=subprocess.DEVNULL,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
                out, err = proc.communicate(timeout=300)
                out_txt = out.decode("utf-8", errors="ignore").strip()
                err_txt = err.decode("utf-8", errors="ignore").strip()
                combined = out_txt if out_txt else err_txt

                is_quota_err = bool(re.search(r"(rate_limit|quota|usage limit|429|MAX_TOKEN_BUDGET_EXCEEDED)", combined, re.I))
                if is_quota_err:
                    subprocess.run([
                        "bash", tracker,
                        "--engine", engine,
                        "--node", "core",
                        "--status", "blocked",
                        "--detail", f"🔴 โควต้า {engine} เต็ม! กดสลับค่ายบนจอ 3D เพื่อทำต่อได้ทันที",
                    ], cwd=PROJECT_ROOT)
                elif proc.returncode == 0:
                    subprocess.run([
                        "bash", tracker,
                        "--engine", engine,
                        "--node", "reviewer",
                        "--status", "ready",
                        "--detail", f"✅ [{engine.upper()}] ตอบกลับเสร็จสมบูรณ์",
                    ], cwd=PROJECT_ROOT)
                else:
                    subprocess.run([
                        "bash", tracker,
                        "--engine", engine,
                        "--node", "debugger",
                        "--status", "warning",
                        "--detail", f"⚠️ [{engine.upper()}] จบด้วย Exit Code {proc.returncode}",
                    ], cwd=PROJECT_ROOT)

                self._send_json({
                    "ok": proc.returncode == 0,
                    "engine": engine,
                    "model": model,
                    "exitCode": proc.returncode,
                    "quotaExhausted": is_quota_err,
                    "output": combined or "(ไม่มีข้อความตอบกลับ)",
                })
            except subprocess.TimeoutExpired:
                proc.kill()
                self._send_json({"ok": False, "error": "คำสั่งใช้เวลาเกิน 5 นาที (Timeout)"}, 504)
            except Exception as e:
                self._send_json({"ok": False, "error": str(e)}, 500)
            return

        self.send_error(404, "Not found")

port = START_PORT
for p in range(START_PORT, START_PORT + 10):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        if s.connect_ex(("127.0.0.1", p)) != 0:
            port = p
            break

url = f"http://127.0.0.1:{port}"
print(f"🛡️  Agent Guard 3D Command & Monitor Center running at: {url}")
print("   (กด Ctrl+C เพื่อปิดเซิร์ฟเวอร์เมื่อเลิกใช้งาน)")
try:
    webbrowser.open(url)
except Exception:
    pass

server = HTTPServer(("127.0.0.1", port), HudHandler)
try:
    server.serve_forever()
except KeyboardInterrupt:
    print("\n👋 ปิด 3D Command & Monitor Center เรียบร้อยแล้ว")
PYEOF
