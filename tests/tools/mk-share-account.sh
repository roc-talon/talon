#!/usr/bin/env bash
# Slice 220: makes the L2 cases tests/commands/cases/share/sh33 to sh48 and updates the 3 --json lines of sh3 (`tln share logout`, `forget`, and the account part of `tln share`; CLI R-SH8, R-SH9, R-SH10). The expected files are written from the design readings of docs/slices/220-share-logout-forget.md, not from a run of tln.
# Usage: tests/tools/mk-share-account.sh        (writes the 16 case dirs)
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
exec python3 -I - "$ROOT/tests/commands/cases/share" <<'PY'
import os, sys, subprocess, shutil, tempfile
base = sys.argv[1]
ID = "0123456789abcdeffedcba9876543210"
NEWID = "0123456789abcdef0123456789abcdef"
JWT = "eyJ.jwt.sig"
CFG = "$HOME/.config/talon/config.toml"
SJ = "$HOME/.local/share/talon/share.json"
DB = "$HOME/.cache/roc/talon/compat.db"
TMP = SJ + ".0123456789abcdef.tmp"
J = "home/.local/share/talon/share.json"
REG = "http://127.0.0.1:9"
HOST = "127.0.0.1%3A9"
LIVE = "2026-11-14T12:00:00Z"     # after the fake clock (1792065600 = 2026-10-15T12:00:00Z)
PAST = "2026-10-01T10:00:00Z"     # before the fake clock

def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)

def doc(token=None, exp=None, account=None, id_=ID, sent=7, counted=5, first=2, times=True):
    t = lambda v: "null" if v is None else '"%s"' % v
    acc = "null" if account is None else '{"id":%d,"login":"%s"}' % account
    fs = t("2026-10-01T10:00:00Z" if times else None)
    ls = t("2026-10-02T11:30:00Z" if times else None)
    return ('{"format":1,"id":"%s","sent":%d,"counted":%d,"first":%d,"first_sent_at":%s,"last_sent_at":%s,"token":%s,"token_expires_at":%s,"account":%s}\n'
            % (id_, sent, counted, first, fs, ls, t(token), t(exp), acc))
LOGGED = lambda exp=LIVE: doc(token=JWT, exp=exp, account=(583231, "octocat"))
OUT = doc()
FORGOTTEN = doc(id_=NEWID, sent=0, counted=0, first=0, times=False)

def tdiff(label, before, after):
    d = tempfile.mkdtemp()
    a, b = os.path.join(d, "a"), os.path.join(d, "b")
    write(a, before); write(b, after)
    r = subprocess.run(["diff", "-u", "--label", label, "--label", label, a, b], capture_output=True, text=True)
    shutil.rmtree(d)
    return r.stdout

def route(case, path, method, status, body, requires, extra=(), n=1):
    d = os.path.join(base, case, "fx/http", HOST, os.path.dirname(path))
    name = os.path.basename(path)
    suffix = ("" if method == "GET" else "." + method) + ("" if n == 1 else ".%d" % n)
    write(os.path.join(d, name + suffix), body)
    meta = (["status %d" % status] if status else []) + (["header Content-Type: application/json"] if body else []) + ["header Cache-Control: no-store"] + list(extra) + requires
    write(os.path.join(d, name + suffix + ".meta"), "\n".join(meta) + "\n")

BEARER = ["require user-agent: tln/0.0.1", "require authorization: Bearer " + JWT, "require-none talon-contributor", "require-none content-type"]
MACHINE = ["require user-agent: tln/0.0.1", "require talon-contributor: " + ID, "require-none authorization", "require-none content-type"]
def problem(t, status): return '{"type":"/errors/%s","title":"T","status":%d,"detail":"D"}' % (t, status)

def head(): return ["args", "env_all", "read_files " + CFG]
def req_log(method, path, who):
    return ["http_send %s %s%s timeout=20" % (method, REG, path), "  User-Agent: tln/0.0.1", "  " + who]
BEARER_LOG = "Authorization: Bearer " + JWT
MACHINE_LOG = "Talon-Contributor: " + ID
STORE = ["lock %s nowait: held" % SJ, "read_files " + SJ, "random", "write_atomic " + TMP, "spawn_all limit=1", "  job - chmod 0600 " + TMP, "rename %s %s" % (TMP, SJ), "unlock " + SJ]
STATUS_DB = ["db_query %s busy_ms=5000 format=1 queue" % DB]

def err_line(kind, msg): return "tln: error[%s]: %s\n" % (kind, msg)
def fail_json(cmd, kind, code, msg):
    return '{"schema":1,"command":"%s","ok":false,"data":null,"error":{"kind":"%s","code":%d,"message":"%s"}}\n' % (cmd, kind, code, msg)
def lines(ls): return "".join(l + "\n" for l in ls)

def case(name, comment, env, runs, given_doc, log, stdout, stderr, final_doc, status_given=False):
    c = os.path.join(base, name)
    if os.path.isdir(c):
        shutil.rmtree(c)
    write(c + "/entry", "commands\n")
    write(c + "/fx/commands", "\n".join([comment] + runs) + "\n")
    write(c + "/fx/env", "\n".join(env) + "\n")
    write(c + "/fx/jobs", "chmod\t0\t-\t-\t-\n")
    write(c + "/given/home/.cache/roc/talon/compat.tsv", "format\t1\n")
    write(c + "/given/home/.config/talon/config.toml", "share = true\n")
    if status_given:
        shutil.copy(os.path.join(base, "sh3-status/given/home/.cache/roc/talon/share_queue.tsv"), c + "/given/home/.cache/roc/talon/share_queue.tsv")
    if given_doc is not None:
        write(c + "/given/home/.local/share/talon/share.json", given_doc)
    write(c + "/expect/exit", "0\n")
    write(c + "/expect/stdout", stdout)
    write(c + "/expect/stderr", stderr)
    write(c + "/expect/calls.log", "\n".join(log) + "\n")
    write(c + "/expect/tree.diff", tdiff(J, given_doc, final_doc) if final_doc != given_doc else "")

ENV = ["HOME={w}/home", "TALON_REGISTRY=" + REG]
FORGET_TAIL = ["This machine has a new id, and its totals are 0.", "The counts that went into compat_hints stay, because they hold no id."]
LOGOUT_TEXT = "Logged out. Each token of the account stopped."

# sh33: logout with a JWT that is live. DELETE /v1/tokens with the JWT in Authorization (no Talon-Contributor), 204. Then the 3 members are null; the id, the totals and the times stay. config.toml stays.
n = "sh33-logout"
log = head() + ["read_files " + SJ, "clock"] + req_log("DELETE", "/v1/tokens", BEARER_LOG) + STORE
case(n, "# R-SH9, R-AP38, R-SH13, R-SE15: logout with a live JWT. The clock is read (a JWT past its time is not sent), then DELETE /v1/tokens with Authorization: Bearer <JWT> and no Talon-Contributor. After the 204 the file is written under its lock: token, token_expires_at and account are null; the id, the totals and the times stay. config.toml (share = true) is not changed.",
     ENV, ["share logout"], LOGGED(), log, "== share logout\n%s\nexit 0\n" % LOGOUT_TEXT, "", OUT)
route(n, "v1/tokens", "DELETE", 204, "", BEARER)

# sh34: forget with a JWT, --json. DELETE /v1/contributors/me with the JWT and no id. 204. The file gets a new id (2 random numbers), the 3 totals 0, the times and the account members null. share is not changed.
n = "sh34-forget-account"
log = head() + ["read_files " + SJ, "clock"] + req_log("DELETE", "/v1/contributors/me", BEARER_LOG) + ["random", "random"] + STORE
case(n, "# R-SH9, R-AP36, R-SH5, R-SH13, R-OUT4: forget --json with a live JWT: DELETE /v1/contributors/me with Authorization: Bearer <JWT> and no Talon-Contributor (the account form, Registry R-CT16 row 7). After the 204: a new id (2 random numbers), the 3 totals 0, the 2 times, token, token_expires_at and account null. config.toml (share = true) is not changed: forget does not change share.",
     ENV, ["share forget --json"], LOGGED(), log,
     '== share forget --json\n{"schema":1,"command":"share forget","ok":true,"data":{"removed":"account"},"error":null}\nexit 0\n', "", FORGOTTEN)
route(n, "v1/contributors/me", "DELETE", 204, "", BEARER)

# sh35: forget with no JWT. DELETE /v1/contributors/me with Talon-Contributor and no Authorization. Plain text: the machine form, the message about compat_hints.
n = "sh35-forget-machine"
log = head() + ["read_files " + SJ] + req_log("DELETE", "/v1/contributors/me", MACHINE_LOG) + ["random", "random"] + STORE
text = ["The registry removed the results that this machine sent before a login."] + FORGET_TAIL
case(n, "# R-SH9, R-AP36, R-SH5, R-SH13: forget with no JWT: no clock call. DELETE /v1/contributors/me with Talon-Contributor: <id> and no Authorization (the machine form). After the 204: a new id, the totals 0, the times null. The text says that the counts in compat_hints stay.",
     ENV, ["share forget"], OUT, log, "== share forget\n" + lines(text) + "exit 0\n", "", FORGOTTEN)
route(n, "v1/contributors/me", "DELETE", 204, "", MACHINE)

# sh36: R-SH10: the registry direct (no flag, no variable, no key): exit 2 (usage) after the read of config.toml: no share.json read, no request.
n = "sh36-account-direct"
def direct(c): return "tln share %s needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml." % c
case(n, "# R-SH10, R-EC2: logout and forget with the registry direct stop with exit 2 (usage). The calls end after the read of config.toml: no share.json read, no request, no write. Plain, and forget with --json.",
     ["HOME={w}/home"], ["share logout", "share forget --json"], LOGGED(), head() + head(),
     "== share logout\nexit 2\n== share forget --json\n" + fail_json("share forget", "usage", 2, direct("forget")) + "exit 2\n",
     err_line("usage", direct("logout")) + err_line("usage", direct("forget")), LOGGED())

# The status: the local lines of sh3-status, with the share.json of the case.
def local(): return ["sharing: on", "id: 01234567", "sent: 7", "counted: 5", "first: 2", "first sent: 2026-10-01T10:00:00Z", "last sent: 2026-10-02T11:30:00Z", "queued: 4"]
LOCAL_JSON = '{"on":true,"reason":null,"id":"01234567","sent":7,"counted":5,"first":2,"first_sent_at":"2026-10-01T10:00:00Z","last_sent_at":"2026-10-02T11:30:00Z","queued":4'
STATUS_HEAD = head() + ["read_files " + SJ] + STATUS_DB

# sh37: status with a live JWT: GET /v1/contributors/me with the JWT. 200: the totals of the account after the local part. The file is not written. Plain, and --json.
n = "sh37-status-account"
TRACKER = '{"account":{"id":583231,"login":"octocat"},"machines":2,"counted":9,"first":4,"agreed":3,"disagreed":1,"unconfirmed":5,"first_time":1791590400500,"last_time":1792152000000}'
acct = ["account: octocat", "account machines: 2", "account counted: 9", "account first: 4", "account agreed: 3", "account disagreed: 1", "account unconfirmed: 5", "account first sent: 2026-10-10T00:00:00Z", "account last sent: 2026-10-16T12:00:00Z"]
ACCT_JSON = '"account":{"id":583231,"login":"octocat","machines":2,"counted":9,"first":4,"agreed":3,"disagreed":1,"unconfirmed":5,"first_sent_at":"2026-10-10T00:00:00Z","last_sent_at":"2026-10-16T12:00:00Z"}'
one = STATUS_HEAD + ["clock"] + req_log("GET", "/v1/contributors/me", BEARER_LOG)
case(n, "# R-SH8, R-AP35, R-SH5, R-OUT2: share with a live JWT: after the local lines, the clock is read and GET /v1/contributors/me goes with Authorization: Bearer <JWT> (no Talon-Contributor). The answer 200 gives the login and the totals of the account. share.json is not written (no lock). Run 2: --json, the member account in data.",
     ENV, ["share", "share --json"], LOGGED(), one + one,
     "== share\n" + lines(local() + acct) + "exit 0\n== share --json\n" + '{"schema":1,"command":"share","ok":true,"data":' + LOCAL_JSON + "," + ACCT_JSON + '},"error":null}\nexit 0\n', "", LOGGED(), status_given=True)
route(n, "v1/contributors/me", "GET", 200, TRACKER, BEARER)

# sh38: status with a JWT that the registry refuses (401): the JWT is removed (the write of 213b), the line is `run tln share login`. The exit code is 0 (Design Q477). Run 2: the JWT is gone, so no clock call and no request.
n = "sh38-status-stopped"
log = STATUS_HEAD + ["clock"] + req_log("GET", "/v1/contributors/me", BEARER_LOG) + STORE + STATUS_HEAD
case(n, "# R-SH8, R-AP35, R-SH13: share with a JWT that the registry refuses (401 unauthenticated): Talon removes the JWT (token, token_expires_at and account become null, under the lock) and prints run tln share login after the local lines. Run 2: --json: the file has no token, so there is no clock call, no request; account is null and login_needed is not there (Q488).",
     ENV, ["share", "share --json"], LOGGED(), log,
     "== share\n" + lines(local() + ["run tln share login"]) + "exit 0\n== share --json\n" + '{"schema":1,"command":"share","ok":true,"data":' + LOCAL_JSON + ',"account":null},"error":null}\nexit 0\n', "", OUT, status_given=True)
route(n, "v1/contributors/me", "GET", 401, problem("unauthenticated", 401), BEARER)

# sh39: status with a JWT whose token_expires_at is before the clock: not sent. The JWT is removed as for a 401, and no request goes.
n = "sh39-status-expired"
log = STATUS_HEAD + ["clock"] + STORE
case(n, "# R-SH13, R-SH8: share --json with a JWT whose token_expires_at (2026-10-01) is before the clock (2026-10-15): Talon sends no request. It removes the JWT, as for a 401. data has account null and login_needed true (Q477, Q488).",
     ENV, ["share --json"], LOGGED(PAST), log, '== share --json\n{"schema":1,"command":"share","ok":true,"data":' + LOCAL_JSON + ',"account":null,"login_needed":true},"error":null}\nexit 0\n', "", OUT, status_given=True)

# sh40 (Q478): a JWT, and the registry is direct or --offline is set: no clock call, no request, the local lines only (sharing is off), the JWT stays.
n = "sh40-status-no-request"
def local_off(why): return ["sharing: off (%s)" % why] + local()[1:]
case(n, "# R-SH8, Q478: share with a live JWT and --offline, then with the registry direct: the status shows sharing off, sends no GET (no clock call), exit 0, the JWT stays in the file.",
     ENV, ["share --offline", "env:TALON_REGISTRY=direct share"], LOGGED(), STATUS_HEAD + STATUS_HEAD,
     "== share --offline\n" + lines(local_off("--offline is set")) + "exit 0\n== env:TALON_REGISTRY=direct share\n" + lines(local_off("the registry is direct")) + "exit 0\n", "", LOGGED(), status_given=True)

# sh41 (Q479, Q424): the GET fails: no answer, 429 with Retry-After, 502. The local lines, a warning on stderr, exit 0, the JWT stays.
n = "sh41-status-get-fails"
one = STATUS_HEAD + ["clock"] + req_log("GET", "/v1/contributors/me", BEARER_LOG)
W1 = "warning: the registry %s gave no answer: no answer in 20 s. Try again later.\n" % REG
W2 = "warning: the registry answered 429 (/errors/rate-limited). Try again in 7 s.\n"
W3 = "warning: the registry answered 502 (/errors/upstream). Try again later.\n"
case(n, "# R-SH8, Q479, Q424, R-E6: share with a live JWT when the GET fails. Run 1: no answer. Run 2: 429 with Retry-After 7. Run 3: 502. Each: the local lines on stdout, a warning on stderr that names the cause, exit 0, no write, the JWT stays.",
     ENV, ["share"] * 3, LOGGED(), one * 3,
     "".join("== share\n" + lines(local()) + "exit 0\n" for _ in range(3)), W1 + W2 + W3, LOGGED(), status_given=True)
route(n, "v1/contributors/me", "GET", 0, "", BEARER, ["error timeout"], 1)
route(n, "v1/contributors/me", "GET", 429, problem("rate-limited", 429), BEARER, ["header Retry-After: 7"], 2)
route(n, "v1/contributors/me", "GET", 502, problem("upstream", 502), BEARER, [], 3)

# sh42 (Q480): logout with no JWT: no request, no write, a message, exit 0.
n = "sh42-logout-none"
case(n, "# R-SH9, Q480: logout when share.json has no JWT: no clock call, no request, no write; the text says that there is no login; exit 0. --json: data logged_out false.",
     ENV, ["share logout", "share logout --json"], OUT, (head() + ["read_files " + SJ]) * 2,
     "== share logout\nThere is no login on this machine.\nexit 0\n== share logout --json\n" + '{"schema":1,"command":"share logout","ok":true,"data":{"logged_out":false},"error":null}\nexit 0\n', "", OUT)

# sh43 (Q481): logout and the registry answers 401: the JWT is removed, exit 0.
n = "sh43-logout-stopped"
log = head() + ["read_files " + SJ, "clock"] + req_log("DELETE", "/v1/tokens", BEARER_LOG) + STORE
case(n, "# R-SH9, R-AP38, Q481: logout when the registry answers 401 (the token is already of no use): the JWT is removed under the lock, the text is the text of a logout, exit 0.",
     ENV, ["share logout"], LOGGED(), log, "== share logout\n%s\nexit 0\n" % LOGOUT_TEXT, "", OUT)
route(n, "v1/tokens", "DELETE", 401, problem("unauthenticated", 401), BEARER)

# sh44 (Q483): logout with a JWT past its time: no request, the JWT is removed, exit 0.
n = "sh44-logout-expired"
log = head() + ["read_files " + SJ, "clock"] + STORE
case(n, "# R-SH9, R-SH13, Q483: logout with a JWT whose token_expires_at (2026-10-01) is before the clock: no request; the JWT is removed under the lock; exit 0.",
     ENV, ["share logout"], LOGGED(PAST), log, "== share logout\n%s\nexit 0\n" % LOGOUT_TEXT, "", OUT)

# sh45 (Q481, Q485): forget and the registry answers 401: exit 20, nothing changes. --offline: exit 15 for forget and logout, no request.
n = "sh45-forget-stopped"
R401 = "the registry %s refused the account delete (/errors/unauthenticated): D. Run tln share login, and then tln share forget." % REG
log = head() + ["read_files " + SJ, "clock"] + req_log("DELETE", "/v1/contributors/me", BEARER_LOG) + head() + head()
case(n, "# R-SH9, R-AP36, Q481, Q485: run 1: forget with a live JWT and a 401: exit 20 (rejected), the message says to run tln share login and then tln share forget; share.json is not changed (JWT, id, totals stay). Runs 2 and 3: --offline: exit 15 for forget and for logout, no request, no change; the calls end after the read of config.toml.",
     ENV, ["share forget", "share forget --offline", "share logout --offline"], LOGGED(), log,
     "== share forget\nexit 20\n== share forget --offline\nexit 15\n== share logout --offline\nexit 15\n",
     err_line("rejected", R401) + err_line("network", "tln share forget needs the network, and --offline is set.") + err_line("network", "tln share logout needs the network, and --offline is set."), LOGGED())
route(n, "v1/contributors/me", "DELETE", 401, problem("unauthenticated", 401), BEARER)

# sh46 (Q483): forget with a JWT past its time: exit 2, no request, nothing changes.
n = "sh46-forget-expired"
EXP = "the login has expired, so the registry cannot delete the account. Run tln share login, and then tln share forget."
case(n, "# R-SH9, R-SH13, Q483: forget with a JWT whose token_expires_at (2026-10-01) is before the clock: exit 2 (usage), no request (not the machine form), share.json is not changed; the message says to run tln share login and then tln share forget.",
     ENV, ["share forget"], LOGGED(PAST), head() + ["read_files " + SJ, "clock"], "== share forget\nexit 2\n", err_line("usage", EXP), LOGGED(PAST))

# sh47 (Q482, Q424): the DELETE fails: logout with no answer, forget with 429 (Retry-After 7) and with 502. Exit 15, share.json is not changed.
n = "sh47-delete-fails"
log = (head() + ["read_files " + SJ, "clock"] + req_log("DELETE", "/v1/tokens", BEARER_LOG)
       + head() + ["read_files " + SJ, "clock"] + req_log("DELETE", "/v1/contributors/me", BEARER_LOG)
       + head() + ["read_files " + SJ, "clock"] + req_log("DELETE", "/v1/contributors/me", BEARER_LOG))
case(n, "# R-SH9, R-AP36, R-AP38, R-E6, Q482, Q424: the DELETE fails. Run 1: logout, no answer. Run 2: forget, 429 with Retry-After 7. Run 3: forget, 502. Each: exit 15 (network), no write: the JWT, the id and the totals stay.",
     ENV, ["share logout", "share forget", "share forget"], LOGGED(), log,
     "== share logout\nexit 15\n== share forget\nexit 15\n== share forget\nexit 15\n",
     err_line("network", "the registry %s gave no answer: no answer in 20 s. Try again later." % REG) + err_line("network", "the registry answered 429 (/errors/rate-limited). Try again in 7 s.") + err_line("network", "the registry answered 502 (/errors/upstream). Try again later."), LOGGED())
route(n, "v1/tokens", "DELETE", 0, "", BEARER, ["error timeout"], 1)
route(n, "v1/contributors/me", "DELETE", 429, problem("rate-limited", 429), BEARER, ["header Retry-After: 7"], 1)
route(n, "v1/contributors/me", "DELETE", 502, problem("upstream", 502), BEARER, [], 2)

# sh48 (Q480, Q484): no share.json: forget and logout send nothing, make no file, say so, exit 0.
n = "sh48-none-file"
case(n, "# R-SH9, Q480, Q484: no share.json: forget says that there is nothing to forget, logout that there is no login. No request, no file (no lock, no random), exit 0.",
     ENV, ["share forget", "share logout"], None, (head() + ["read_files " + SJ]) * 2,
     "== share forget\nThere is nothing to forget on this machine.\nexit 0\n== share logout\nThere is no login on this machine.\nexit 0\n", "", None)

# sh3: the 3 --json lines get "account":null (Q488).
sh3 = os.path.join(base, "sh3-status/expect/stdout")
t = open(sh3).read()
if '"account":null' not in t:
    t = t.replace('"queued":4},"error"', '"queued":4,"account":null},"error"').replace('"queued":0},"error"', '"queued":0,"account":null},"error"')
    open(sh3, "w").write(t)
PY
