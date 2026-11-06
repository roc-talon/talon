#!/usr/bin/env bash
# Slice 219: makes the L2 cases tests/commands/cases/share/sh23 to sh29 (`tln share login`, CLI R-SH7, R-SH10, R-SH12). The expected files are written from the design readings of docs/slices/219-share-login.md, not from a run of tln.
# Usage: tests/tools/mk-share-login.sh        (writes the 7 case dirs)
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
exec python3 -I - "$ROOT/tests/commands/cases/share" <<'PY'
import os, sys, subprocess, shutil, tempfile
base = sys.argv[1]
ID = "0123456789abcdeffedcba9876543210"
CID = "Ov23li2sxWgMaAvjaUbQ"
GRANT = "urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Adevice_code"
CFG = "$HOME/.config/talon/config.toml"
SJ = "$HOME/.local/share/talon/share.json"
TMP = SJ + ".0123456789abcdef.tmp"
J = "home/.local/share/talon/share.json"
REG = "http://127.0.0.1:9"
GH = "http://127.0.0.1:8"
JWT_EXP = "2026-11-14T12:00:00Z"   # expires_at 1794657600000 ms
JWT_EXP2 = "2026-11-26T02:10:00Z"  # expires_at 1795659000000 ms

INTRO = ["A login ties this machine to your GitHub account.",
         "The results that this machine sent before move to the account, and the next ones count for it.",
         "The registry keeps them until you run `tln share forget`, or until their compiler is 12 months old. Then it keeps only the totals."]
def code_lines(web): return ["Open %s/login/device" % web, "Enter the code: WDJB-MJHT", "Talon waits until you approve the code in GitHub."]
SHOWN = lambda web: INTRO + code_lines(web)

def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)

def doc(sent=7, counted=5, first=2, token=None, exp=None, account=None):
    t = lambda v: "null" if v is None else '"%s"' % v
    acc = "null" if account is None else '{"id":%d,"login":"%s"}' % account
    return ('{"format":1,"id":"%s","sent":%d,"counted":%d,"first":%d,"first_sent_at":"2026-10-01T10:00:00Z","last_sent_at":"2026-10-02T11:30:00Z","token":%s,"token_expires_at":%s,"account":%s}\n'
            % (ID, sent, counted, first, t(token), t(exp), acc))

def tdiff(label, before, after):
    d = tempfile.mkdtemp()
    a, b = os.path.join(d, "a"), os.path.join(d, "b")
    write(a, before); write(b, after)
    r = subprocess.run(["diff", "-u", "--label", label, "--label", label, a, b], capture_output=True, text=True)
    shutil.rmtree(d)
    return r.stdout

def route(case, host, path, n, status, body, extra=(), requires=None):
    d = os.path.join(base, case, "fx/http", host, os.path.dirname(path))
    name = os.path.basename(path)
    suffix = "" if n == 1 else ".%d" % n
    write(os.path.join(d, name + ".POST" + suffix), body)
    meta = (["status %d" % status] if status else []) + ["header Content-Type: application/json"] + list(extra)
    meta += requires
    write(os.path.join(d, name + ".POST%s.meta" % suffix), "\n".join(meta) + "\n")

GH_REQ = ["require accept: application/json", "require user-agent: tln/0.0.1", "require content-type: application/x-www-form-urlencoded", "require-none authorization", "require-none talon-contributor"]
def reg_req(i=None): return ["require content-type: application/json", "require talon-contributor: " + (i or ID), "require-none authorization", "require user-agent: tln/0.0.1"]

def gh_code(case, host, n, interval=0, expires=900, status=200, body=None, extra=()):
    iv = "" if interval is None else ',"interval":%d' % interval
    b = body if body is not None else '{"device_code":"DC1","user_code":"WDJB-MJHT","verification_uri":"https://github.com/login/device","expires_in":%d%s}' % (expires, iv)
    route(case, host, "login/device/code", n, status, b, extra, GH_REQ)
def gh_poll(case, host, n, body, status=200, extra=()):
    route(case, host, "login/oauth/access_token", n, status, body, extra, GH_REQ)
def tok(case, host, n, status, body, extra=(), i=None):
    route(case, host, "v1/tokens", n, status, body, extra, reg_req(i))
def granted(exp_ms=1794657600000, login="octocat", id_=583231):
    return '{"account":{"id":%d,"login":"%s"},"expires_at":%d,"token":"eyJ.jwt.sig"}' % (id_, login, exp_ms)
TOKEN_OK = '{"access_token":"gho_test","token_type":"bearer","scope":""}'
def problem(t, status): return '{"type":"/errors/%s","title":"T","status":%d,"detail":"D"}' % (t, status)

# The calls
def head(): return ["args", "env_all", "read_files " + CFG]
def code_log(web): return ["http_send POST %s/login/device/code timeout=20" % web, "  Accept: application/json", "  User-Agent: tln/0.0.1", "  Content-Type: application/x-www-form-urlencoded", "  <body> client_id=" + CID]
def poll_log(web): return ["http_send POST %s/login/oauth/access_token timeout=20" % web, "  Accept: application/json", "  User-Agent: tln/0.0.1", "  Content-Type: application/x-www-form-urlencoded",
                           "  <body> client_id=%s&device_code=DC1&grant_type=%s" % (CID, GRANT)]
def turn(web, seconds): return ["sleep %d" % (seconds * 1000), "clock"] + poll_log(web)
def token_log(origin=REG, i=None): return ["http_send POST %s/v1/tokens timeout=20" % origin, "  User-Agent: tln/0.0.1", "  Content-Type: application/json", "  Talon-Contributor: " + (i or ID), '  <body> {"github_token":"gho_test"}']
STORE = ["lock %s nowait: held" % SJ, "read_files " + SJ, "random", "write_atomic " + TMP, "spawn_all limit=1", "  job - chmod 0600 " + TMP, "rename %s %s" % (TMP, SJ), "unlock " + SJ]
def start(web): return head() + ["read_files " + SJ] + code_log(web) + ["clock"]

def err_line(kind, msg): return "tln: error[%s]: %s\n" % (kind, msg)
def fail_json(kind, code, msg, details=""):
    return '{"schema":1,"command":"share login","ok":false,"data":null,"error":{"kind":"%s","code":%d,"message":"%s"%s}}\n' % (kind, code, msg, details)

def case(name, comment, env, runs, given_doc, given_cfg, log, stdout, stderr, final_doc):
    c = os.path.join(base, name)
    if os.path.isdir(c):
        shutil.rmtree(c)
    write(c + "/entry", "commands\n")
    write(c + "/fx/commands", comment + "\n" + "\n".join(runs) + "\n")
    write(c + "/fx/env", "\n".join(env) + "\n")
    write(c + "/fx/jobs", "chmod\t0\t-\t-\t-\n")
    write(c + "/given/home/.cache/roc/talon/compat.tsv", "format\t1\n")
    if given_doc is not None:
        write(c + "/given/home/.local/share/talon/share.json", given_doc)
    if given_cfg is not None:
        write(c + "/given/home/.config/talon/config.toml", given_cfg)
    write(c + "/expect/exit", "0\n")
    write(c + "/expect/stdout", stdout)
    write(c + "/expect/stderr", stderr)
    write(c + "/expect/calls.log", "\n".join(log) + "\n")
    write(c + "/expect/tree.diff", tdiff(J, given_doc or "", final_doc) if final_doc != given_doc else "")
    return c

ENV = ["HOME={w}/home", "TALON_REGISTRY=" + REG]
ENV_GH = ENV + ["TALON_GITHUB_WEB=" + GH]
def lines(ls): return "".join(l + "\n" for l in ls)

# sh23: the whole flow with the hook (TALON_GITHUB_WEB is in fx/env). Wait 7 s; pending; slow_down with interval 12; slow_down with no interval (12 + 5); pending; token. The registry gets the GitHub token once, with the id.
n = "sh23-login-flow"
log = start(GH) + turn(GH, 7) + turn(GH, 7) + turn(GH, 12) + turn(GH, 17) + turn(GH, 17) + token_log() + STORE
case(n, "# R-SH7, R-SH12 rows 1 to 5 and 8, R-CT8 row 1, R-AP37, R-SH5, R-SH13, R-SE15, R-EV28: the code request (client id, no scope), then the polls: the wait is 7 s (interval), pending (7), slow_down with interval 12, slow_down with no interval (12 + 5 = 17), pending (17), token. Then POST /v1/tokens at the registry with the GitHub token and the id (no Authorization). share.json gets the JWT, its expiry and the account; the id and the totals stay; the GitHub token is not in the file. config.toml (share = false) is not changed: a login does not turn sharing on. TALON_GITHUB_WEB moves only the 2 GitHub requests.",
     ENV_GH, ["share login"], doc(), "share = false\n", log,
     "== share login\nLogged in as octocat.\nexit 0\n", lines(SHOWN(GH)),
     doc(token="eyJ.jwt.sig", exp=JWT_EXP, account=(583231, "octocat")))
gh_code(n, "127.0.0.1%3A8", 1, interval=7)
gh_poll(n, "127.0.0.1%3A8", 1, '{"error":"authorization_pending","error_description":"x"}')
gh_poll(n, "127.0.0.1%3A8", 2, '{"error":"slow_down","interval":12}')
gh_poll(n, "127.0.0.1%3A8", 3, '{"error":"slow_down"}')
gh_poll(n, "127.0.0.1%3A8", 4, '{"error":"authorization_pending"}')
gh_poll(n, "127.0.0.1%3A8", 5, TOKEN_OK)
tok(n, "127.0.0.1%3A9", 1, 201, granted(), ["header Cache-Control: no-store"])

# sh24: the default GitHub host (no hook), an interval 0 (the fake wait is `sleep 0`), a token at the first poll, and a login again: the old token and account are replaced. --json: only the envelope on stdout, the text on stderr.
n = "sh24-login-default-json"
reg2 = "https://registry.example.org"
log = start("https://github.com") + turn("https://github.com", 0) + token_log(reg2) + STORE
case(n, "# R-SH7, R-SH12 row 1 and 2, R-EV28 (the default https://github.com), R-OUT2, R-OUT4, R-J2: with no hook the 2 requests go to github.com. interval 0 is used as it is (sleep 0). The token comes at the first poll. share.json had a token and an account: they are replaced (a login again, R-CT8 row 3). --json: stdout has the envelope only (the JWT is not in it), the intro and the code are on stderr.",
     ["HOME={w}/home", "TALON_REGISTRY=" + reg2], ["share login --json"], doc(token="old.jwt", exp="2026-10-20T00:00:00Z", account=(1, "old")), None, log,
     '== share login --json\n{"schema":1,"command":"share login","ok":true,"data":{"account":{"id":583231,"login":"octocat"},"token_expires_at":"%s"},"error":null}\nexit 0\n' % JWT_EXP2,
     lines(SHOWN("https://github.com")),
     doc(token="eyJ.jwt.sig", exp=JWT_EXP2, account=(583231, "octocat")))
gh_code(n, "github.com", 1, interval=0)
gh_poll(n, "github.com", 1, TOKEN_OK)
tok(n, "registry.example.org", 1, 201, granted(1795659000000), ["header Cache-Control: no-store"])

# sh25: R-SH10: the registry direct. Exit 2 (usage) before any request and before share.json is read. --json: the envelope.
n = "sh25-login-direct"
direct_msg = "tln share login needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml."
case(n, "# R-SH10, R-EC2: share login with the registry direct (the default: no flag, no variable, no key) stops with exit 2 (usage). The calls end after the read of config.toml: no share.json read, no request, no write. The same with --json and with TALON_REGISTRY=direct.",
     ["HOME={w}/home"], ["share login", "env:TALON_REGISTRY=direct share login --json"], doc(), None,
     head() + head(),
     "== share login\nexit 2\n== env:TALON_REGISTRY=direct share login --json\n" + fail_json("usage", 2, direct_msg) + "exit 2\n",
     err_line("usage", direct_msg) * 2, doc())

# sh26: declined or expired code: exit 13 (consent), share.json stays. 1: pending, then access_denied. 2: expired_token. 3: expires_in 0: the end time is reached after the first wait, so no poll is sent.
n = "sh26-login-declined"
DENIED = "the login was declined in GitHub"
EXPIRED = "the code expired before you approved it. Run tln share login again."
log = (start(GH) + turn(GH, 3) + turn(GH, 3)
       + start(GH) + turn(GH, 0)
       + start(GH) + ["sleep 0", "clock"])
case(n, "# R-SH7, R-SH12 rows 6 and 7, R-EC13: run 1: pending, then access_denied: exit 13. Run 2: expired_token: exit 13. Run 3: expires_in 0 (the fake clock does not move): after the wait the end time is reached, exit 13 and no poll is sent. share.json is not changed and no request goes to the registry.",
     ENV_GH, ["share login", "share login", "share login"], doc(), None, log,
     "== share login\nexit 13\n== share login\nexit 13\n== share login\nexit 13\n",
     lines(SHOWN(GH)) + err_line("consent", DENIED) + lines(SHOWN(GH)) + err_line("consent", EXPIRED) + lines(SHOWN(GH)) + err_line("consent", EXPIRED), doc())
gh_code(n, "127.0.0.1%3A8", 1, interval=3)
gh_code(n, "127.0.0.1%3A8", 2, interval=0)
gh_code(n, "127.0.0.1%3A8", 3, interval=0, expires=0)
gh_poll(n, "127.0.0.1%3A8", 1, '{"error":"authorization_pending"}')
gh_poll(n, "127.0.0.1%3A8", 2, '{"error":"access_denied"}')
gh_poll(n, "127.0.0.1%3A8", 3, '{"error":"expired_token"}')

# sh27: no answer: exit 15 (network). Runs 1 to 3: the poll has no answer, a 5xx answer, a body that is not JSON. Runs 4 and 5: the registry gives 502 and no answer. Runs 6 to 8: the code request has no answer, a 503, a body that is not JSON. share.json stays.
n = "sh27-login-no-answer"
H = "127.0.0.1%3A8"
N_FAILED = "GitHub gave no answer: connection reset. Try again later."
N_TIMEOUT = "GitHub gave no answer in 20 s. Try again later."
N_5XX = "GitHub answered %d. Try again later."
N_JSON = "GitHub answered with text that is not JSON. Try again later."
R_502 = "the registry answered 502 (/errors/upstream). Try again later."
R_TIMEOUT = "the registry %s gave no answer: no answer in 20 s. Try again later." % REG
runs = ["share login"] * 9
codes = start(GH)
log = (codes + turn(GH, 0)
       + codes + turn(GH, 0)
       + codes + turn(GH, 0)
       + codes + turn(GH, 0) + token_log()
       + codes + turn(GH, 0) + token_log()
       + head() + ["read_files " + SJ] + code_log(GH) + ["clock"]
       + head() + ["read_files " + SJ] + code_log(GH) + ["clock"]
       + head() + ["read_files " + SJ] + code_log(GH) + ["clock"]
       + head() + ["read_files " + SJ] + code_log(GH) + ["clock"])
case(n, "# Run 9 (Q475, R-SH12 row 11): the code answer is JSON with no device_code: exit 15, the message names the code request. R-SH7, R-SH12 row 10, R-E6, R-EC15: exit 15 for each case that is no answer. Run 1: the poll fails (no answer). Run 2: the poll gives 500. Run 3: the poll body is not JSON. Run 4: the token request gets 502 upstream. Run 5: the token request has no answer. Run 6: the code request has no answer. Run 7: a 503. Run 8: a body that is not JSON. Each stops at once: no retry, no later request, share.json is not changed.",
     ENV_GH, runs, doc(), None, log,
     "".join("== share login\nexit 15\n" for _ in runs),
     lines(SHOWN(GH)) + err_line("network", N_FAILED) + lines(SHOWN(GH)) + err_line("network", N_5XX % 500) + lines(SHOWN(GH)) + err_line("network", N_JSON)
     + lines(SHOWN(GH)) + err_line("network", R_502) + lines(SHOWN(GH)) + err_line("network", R_TIMEOUT)
     + lines(INTRO) + err_line("network", N_TIMEOUT) + lines(INTRO) + err_line("network", N_5XX % 503) + lines(INTRO) + err_line("network", N_JSON)
     + lines(INTRO) + err_line("network", "GitHub answered the code request with no device_code. Try again later."), doc())
# code routes: runs 1 to 5 are good answers, 6 a timeout, 7 a 503, 8 text
for i in range(1, 6): gh_code(n, H, i, interval=0)
gh_code(n, H, 6, status=0, body="", extra=["error timeout"])
gh_code(n, H, 7, status=503, body="Service Unavailable")
gh_code(n, H, 8, body="<html>login</html>")
gh_code(n, H, 9, body='{"user_code":"WDJB-MJHT","expires_in":900}')
gh_poll(n, H, 1, "", status=0, extra=["error failed connection reset"])
gh_poll(n, H, 2, "oops", status=500)
gh_poll(n, H, 3, "<html>login</html>")
gh_poll(n, H, 4, TOKEN_OK)
gh_poll(n, H, 5, TOKEN_OK)
tok(n, "127.0.0.1%3A9", 1, 502, problem("upstream", 502))
tok(n, "127.0.0.1%3A9", 2, 0, "", ["error timeout"])

# sh28: other errors. Run 1: the code request answers device_flow_disabled: exit 1. Run 2: the poll answers incorrect_device_code: exit 1. Run 3: the registry gives 401: exit 20 (rejected). Run 4: the same with --json (error.details has status and type, R-J7). Run 5: 400: exit 1. Run 6: 429: exit 15.
n = "sh28-login-errors"
def refused(e): return "GitHub refused the login (%s). The client id or the code of tln is wrong." % e
R_401 = "the registry %s refused the login (/errors/unauthenticated): D. Run tln share login again." % REG
R_400 = "the registry %s refused the request (/errors/bad-request): D. This is a fault of tln 0.0.1 or a version skew." % REG
R_429 = "the registry answered 429 (/errors/rate-limited). Try again later."
log = (head() + ["read_files " + SJ] + code_log(GH) + ["clock"]
       + start(GH) + turn(GH, 0)
       + start(GH) + turn(GH, 0) + token_log()
       + start(GH) + turn(GH, 0) + token_log()
       + start(GH) + turn(GH, 0) + token_log()
       + start(GH) + turn(GH, 0) + token_log())
runs = ["share login", "share login", "share login", "share login --json", "share login", "share login"]
case(n, "# R-SH12 row 9, R-SH7, R-E6, R-J7, R-EC1, R-EC15, R-EC20: another error text from GitHub is exit 1 (internal) with the text in the message: run 1 at the code request (device_flow_disabled), run 2 at the poll (incorrect_device_code). The registry answers: 401 unauthenticated (GitHub refuses the token): exit 20 (run 3; run 4 with --json: error.details has status and type); 400: exit 1 (run 5); 429: exit 15 (run 6). share.json is not changed.",
     ENV_GH, runs, doc(), None, log,
     "== share login\nexit 1\n== share login\nexit 1\n== share login\nexit 20\n== share login --json\n"
     + fail_json("rejected", 20, R_401, ',"details":{"status":401,"type":"/errors/unauthenticated"}') + "exit 20\n== share login\nexit 1\n== share login\nexit 15\n",
     (lines(INTRO) + err_line("internal", refused("device_flow_disabled")) + lines(SHOWN(GH)) + err_line("internal", refused("incorrect_device_code"))
                + lines(SHOWN(GH)) + err_line("rejected", R_401) + lines(SHOWN(GH)) + err_line("rejected", R_401)
                + lines(SHOWN(GH)) + err_line("internal", R_400) + lines(SHOWN(GH)) + err_line("network", R_429)), doc())
gh_code(n, H, 1, body='{"error":"device_flow_disabled","error_description":"Device Flow must be explicitly enabled for this App"}')
for i in range(2, 7): gh_code(n, H, i, interval=0)
gh_poll(n, H, 1, '{"error":"incorrect_device_code","error_description":"x"}')
for i in range(2, 6): gh_poll(n, H, i, TOKEN_OK)
tok(n, "127.0.0.1%3A9", 1, 401, problem("unauthenticated", 401))
tok(n, "127.0.0.1%3A9", 2, 401, problem("unauthenticated", 401))
tok(n, "127.0.0.1%3A9", 3, 400, problem("bad-request", 400))
tok(n, "127.0.0.1%3A9", 4, 429, problem("rate-limited", 429))

# sh29: share.json does not parse: exit 19 (input) before any request (R-TF6: the id cannot be made again). --json: the envelope.
n = "sh29-login-bad-share-json"
bad = "this is not json\n"
msg = "$HOME/.local/share/talon/share.json: the content does not parse"
case(n, "# R-SH7, R-SH5, R-TF6, R-EC19: share.json does not parse: share login stops with exit 19 (input) after reading it and before the intro and any request. The file is not changed.",
     ENV_GH, ["share login", "share login --json"], bad, None,
     (head() + ["read_files " + SJ]) * 2,
     "== share login\nexit 19\n== share login --json\n" + fail_json("input", 19, msg) + "exit 19\n",
     err_line("input", msg) * 2, bad)
# sh30: no share.json (Q470, R-SH13): the file is made with a new id (the write of tln share on) after the read that finds nothing, before the intro. The new id goes in Talon-Contributor. Then the JWT is stored in the same file. Sharing stays as it was.
n = "sh30-login-no-share-json"
NEWID = "0123456789abcdef0123456789abcdef"
MAKE = ["lock %s nowait: held" % SJ, "read_files " + SJ, "random", "random", "random", "write_atomic " + TMP, "spawn_all limit=1", "  job - chmod 0600 " + TMP, "rename %s %s" % (TMP, SJ), "unlock " + SJ]
final = '{"format":1,"id":"%s","sent":0,"counted":0,"first":0,"first_sent_at":null,"last_sent_at":null,"token":"eyJ.jwt.sig","token_expires_at":"%s","account":{"id":583231,"login":"octocat"}}\n' % (NEWID, JWT_EXP)
log = head() + ["read_files " + SJ] + MAKE + code_log(GH) + ["clock"] + turn(GH, 0) + token_log(REG, NEWID) + STORE
case(n, "# Q470, R-SH7, R-SH13, R-SH5: no share.json. The first read finds nothing, the file is made under its lock with a new id (3 random numbers: the id and the temp name; chmod 0600 before the rename), before the intro. POST /v1/tokens carries that id. Then the JWT is written to the file (the second write).",
     ENV_GH, ["share login"], None, None, log,
     "== share login\nLogged in as octocat.\nexit 0\n", lines(SHOWN(GH)), final)
gh_code(n, H, 1, interval=0)
gh_poll(n, H, 1, TOKEN_OK)
tok(n, "127.0.0.1%3A9", 1, 201, granted(), ["header Cache-Control: no-store"], NEWID)

# sh31: --offline (Q476): exit 15 and no request. The calls stop after the read of config.toml, as for direct (share.json is not read or made).
n = "sh31-login-offline"
off_msg = "tln share login needs the network, and --offline is set."
case(n, "# Q476, R-EC15: share login --offline stops with exit 15 (network) and sends no request. The calls end after the read of config.toml: no share.json read, no intro. Plain and --json.",
     ENV_GH, ["share login --offline", "share login --offline --json"], doc(), None, head() + head(),
     "== share login --offline\nexit 15\n== share login --offline --json\n" + fail_json("network", 15, off_msg) + "exit 15\n",
     err_line("network", off_msg) * 2, doc())

# sh32: --quiet (Q476) does not hide the intro and the code: stderr is as without it. stdout keeps the result line.
n = "sh32-login-quiet"
log = start(GH) + turn(GH, 0) + token_log() + STORE
case(n, "# Q476, R-SH7: --quiet does not hide the intro text and the code line (the person needs the code). stdout keeps the result line. (The result line with --quiet is a proposal, R-OUT2.)",
     ENV_GH, ["share login --quiet"], doc(), None, log,
     "== share login --quiet\nLogged in as octocat.\nexit 0\n", lines(SHOWN(GH)),
     doc(token="eyJ.jwt.sig", exp=JWT_EXP, account=(583231, "octocat")))
gh_code(n, H, 1, interval=0)
gh_poll(n, H, 1, TOKEN_OK)
tok(n, "127.0.0.1%3A9", 1, 201, granted(), ["header Cache-Control: no-store"])
PY
