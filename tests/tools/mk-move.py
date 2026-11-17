#!/usr/bin/env python3
"""Writes the L2 cases of slice 251 (`tln move`) to tests/commands/cases/move/.

The expected files are written BY HAND here (from the slice file, docs/slices/251-move.md), never from a run of tln: the cases were red when they were made (TW18, TW21).
A case is a list of runs. Each step of a run (`guard`, `read`, `token`, `write`, `sleep`) adds the fake answer (numbered as FakeFx.roc counts: the n-th request of one method and URL in the whole case) and the line of calls.log in one place, so the two cannot differ.
Usage: python3 tests/tools/mk-move.py   (run it from the repo root; it replaces tests/commands/cases/move/)
"""
import json, os, shutil, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "commands", "cases", "move")
REG = "127.0.0.1%3A9"
TOK = "127.0.0.1%3A8"
GH = "127.0.0.1%3A7"
PRE = "args\nenv_all\nenv_all\nread_files $HOME/.config/talon/config.toml\n"
AUD = "http%3A%2F%2F127.0.0.1%3A9"
TOKEN_CALL = "http_send GET http://127.0.0.1:8/token?api-version=2.0&audience=" + AUD + " timeout=20\n  Authorization: bearer req1\n"
NOSTORE = ["Content-Type: application/json", "Cache-Control: no-store"]
BASE_ENV = {
    "HOME": "{w}/home",
    "CI": "true",
    "GITHUB_REPOSITORY": "acme/roc-json",
    "GITHUB_EVENT_NAME": "workflow_dispatch",
    "GITHUB_SERVER_URL": "https://github.com",
    "ACTIONS_ID_TOKEN_REQUEST_URL": "http://127.0.0.1:8/token?api-version=2.0",
    "ACTIONS_ID_TOKEN_REQUEST_TOKEN": "req1",
    "TALON_REGISTRY": "http://127.0.0.1:9",
    "TALON_GITHUB_API": "http://127.0.0.1:7",
}

def j(x):
    return json.dumps(x, separators=(",", ":"), ensure_ascii=False)

def item(name, state, successor):
    return j({"name": name, "state": state, "successor": successor, "state_at": 1767000000000, "owner_changed": None})

def releases(*items):
    return '{"releases":[],"checked":null,"repos":[' + ",".join(items) + "]}"

def problem(status, typ, detail, **extra):
    d = {"type": "/errors/" + typ, "title": "T", "status": status, "detail": detail}
    d.update(extra)
    return j(d)

def envelope_ok(data):
    return '{"schema":1,"command":"move","ok":true,"data":' + data + ',"error":null}'

def envelope_err(kind, code, message, details=None):
    err = {"kind": kind, "code": code, "message": message}
    if details is not None:
        err["details"] = details
    return '{"schema":1,"command":"move","ok":false,"data":null,"error":' + j(err) + "}"

def data(name, result, successor, offer, state):
    return j({"name": name, "result": result, "successor": successor, "offer": offer, "state": state})

def err_line(kind, msg):
    return "tln: error[%s]: %s" % (kind, msg)

REFUSED_TAIL = "Fix the names or the workflow, then run the command again."

class Case:
    def __init__(self, name, rules, env=None, drop_env=()):
        self.name = name
        self.rules = rules
        self.env = dict(BASE_ENV)
        if env:
            self.env.update(env)
        for k in drop_env:
            self.env.pop(k, None)
        self.files = {}      # path under fx/http -> text
        self.counts = {}     # (method, host, path) -> n
        self.commands = []
        self.calls = ""
        self.stdout = ""
        self.stderr = ""
        self.tree = {}       # home path -> content
        self.known = set()   # repos with a kept public answer

    # ---- fake answers
    def answer(self, method, host, path, body, status=200, headers=NOSTORE, requires=(), timeout=False):
        key = (method, host, path)
        n = self.counts.get(key, 0) + 1
        self.counts[key] = n
        base = "%s/%s" % (host, path)
        suffix = "" if method == "GET" else "." + method
        if n > 1:
            suffix += ".%d" % n
        meta = []
        if timeout:
            meta.append("error timeout")
        else:
            meta.append("status %d" % status)
            meta += ["header " + h for h in headers]
        meta += list(requires)
        self.files[base + suffix] = "" if timeout else body
        self.files[base + suffix + ".meta"] = "\n".join(meta) + "\n"

    # ---- the steps of a run
    def run(self, command):
        self.commands.append(command)
        self.calls += PRE
        self.stdout += "== %s\n" % command
        self._open = True

    def guard(self, name, status=200, body=None, private=False):
        o, r = name.split("/")
        path = "$HOME/.cache/roc/talon/index/github/%s/%s/repo.json" % (o, r)
        self.calls += "read_files " + path + "\n"
        if name in self.known:
            return
        if body is None:
            body = '{"id":1,"full_name":"%s","private":%s,"fork":false}' % (name, "true" if private else "false")
        self.answer("GET", GH, "repos/%s/%s" % (o, r), body, status=status, headers=["Content-Type: application/json"], requires=["require-none authorization"])
        self.calls += "http_get http://127.0.0.1:7/repos/%s/%s\n  User-Agent: tln/0.0.1\n" % (o, r)
        if status == 200 and not private:
            self.calls += "write_atomic " + path + "\n"
            self.known.add(name)
            self.tree["home/.cache/roc/talon/index/github/%s/%s/repo.json" % (o, r)] = body

    def read(self, old, status=200, body=None):
        o, r = old.split("/")
        self.answer("GET", REG, "v1/packages/%s/%s/releases" % (o, r), body, status=status,
                    requires=["require user-agent: tln/0.0.1", "require cache-control: no-cache", "require-none authorization"])
        self.calls += "http_get http://127.0.0.1:9/v1/packages/%s/%s/releases\n  User-Agent: tln/0.0.1\n  Cache-Control: no-cache\n" % (o, r)

    def token(self, jwt="jwt1", status=200, body=None):
        if body is None:
            body = '{"count":1,"value":"%s"}' % jwt
        self.answer("GET", TOK, "token", body, status=status, requires=["require authorization: bearer req1"])
        self.calls += TOKEN_CALL

    def write(self, method, old, status=None, body=None, jwt="jwt1", sent=None, headers=NOSTORE, timeout=False):
        """One request of the write. `sent` is the request body (PUT) that calls.log shows."""
        o, r = old.split("/")
        reqs = ["require authorization: Bearer " + jwt, "require user-agent: tln/0.0.1"]
        if method == "PUT":
            reqs.append("require content-type: application/json")
        else:
            reqs.append("require-none content-type")
        self.answer(method, REG, "v1/packages/%s/%s/successor" % (o, r), body, status=status or 0, headers=headers, requires=reqs, timeout=timeout)
        self.calls += "http_send %s http://127.0.0.1:9/v1/packages/%s/%s/successor timeout=20\n  User-Agent: tln/0.0.1\n" % (method, o, r)
        if method == "PUT":
            self.calls += "  Content-Type: application/json\n"
        self.calls += "  Authorization: Bearer %s\n" % jwt
        if method == "PUT":
            self.calls += "  <body> {\"name\":\"%s\"}\n" % sent

    def sleep(self, ms):
        self.calls += "sleep %d\n" % ms

    def out(self, text):
        self.stdout += text + "\n"

    def fail(self, code, kind=None, msg=None):
        if kind is not None:
            self.stderr += err_line(kind, msg) + "\n"
        self.stdout += "exit %d\n" % code

    def ok(self):
        self.stdout += "exit 0\n"

    # ---- output
    def write_all(self):
        d = os.path.join(ROOT, self.name)
        for p, text in [("entry", "commands\n"), ("rules", self.rules.strip() + "\n"),
                        ("fx/commands", "\n".join(self.commands) + "\n"),
                        ("fx/env", "\n".join("%s=%s" % kv for kv in self.env.items()) + "\n"),
                        ("expect/calls.log", self.calls), ("expect/stdout", self.stdout)]:
            self._put(d, p, text)
        if self.stderr:
            self._put(d, "expect/stderr", self.stderr)
        for p, text in self.files.items():
            self._put(d, "fx/http/" + p, text)
        if self.tree:
            diff = ""
            for path in sorted(self.tree):
                body = self.tree[path]
                diff += "--- %s\n+++ %s\n@@ -0,0 +1 @@\n+%s\n\\ No newline at end of file\n" % (path, path, body)
            self._put(d, "expect/tree.diff", diff)

    @staticmethod
    def _put(d, p, text):
        path = os.path.join(d, p)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(text)

MOVED_LINE = "moved: olddev/json to acme/roc-json. Users see it in tln outdated, and follow it with tln update <alias>."
OFFERED_LINE = "offered: olddev/json to acme/roc-json. To accept, run tln move olddev/json in a workflow_dispatch job of acme/roc-json."
REMOVED_LINE = "removed: the successor of olddev/json"
SAME_LINE = "unchanged: olddev/json has the successor acme/roc-json already"
NONE_LINE = "unchanged: olddev/json has no successor"
NEW = "acme/roc-json"
OLD = "olddev/json"
MOVED_ITEM = item(OLD, "moved", NEW)
ACTIVE_ITEM = item(OLD, "active", None)
JOB_OLD = {"GITHUB_REPOSITORY": OLD}
GONE_SUCC = "env:GITHUB_REPOSITORY=" + OLD

def mv1():
    c = Case("mv1-set", """
R-CM22 R-MV1 R-MV3 R-MV4 R-MV5 R-AP31 R-AP32 R-OUT2 R-OUT4 R-J1 R-IK2 R-TP2 R-TP17 (slice 251): `tln move <old>` in a job of the new name (J is not the old name): the request is a PUT with {"name": J}. Order of the calls: the privacy guard of the SUCCESSOR J only (repo.json read, GitHub read, write; the old name olddev/json has no GitHub fixture, so a guard call for it would give 404 and fail the run: R-MV3), the R-AP1 read of the old name (fresh, Cache-Control: no-cache, Q251-4), the OIDC token, the PUT.
Run 1: 201 is `moved`. Run 2: 200 and the read already had this successor: `unchanged` (Q251-4). Run 3: --to equal to the job is the same request, 200 with another old successor: `moved`, with --json (the data of the catalog row move). Run 4: names with upper case: the URL and the body are lower case (R-IK2), the guard file is known (one read_files, no request). The job has no GITHUB_REF. No file is written except the kept public answer of the guard (R-MV5). No stderr line in an exit-0 run.
""")
    c.run("move olddev/json")
    c.guard(NEW); c.read(OLD, body=releases(ACTIVE_ITEM)); c.token()
    c.write("PUT", OLD, 201, MOVED_ITEM, sent=NEW)
    c.out(MOVED_LINE); c.ok()
    c.run("move olddev/json")
    c.guard(NEW); c.read(OLD, body=releases(MOVED_ITEM)); c.token()
    c.write("PUT", OLD, 200, MOVED_ITEM, sent=NEW)
    c.out(SAME_LINE); c.ok()
    c.run("move olddev/json --to acme/roc-json --json")
    c.guard(NEW); c.read(OLD, body=releases(item(OLD, "moved", "third/lib"))); c.token()
    c.write("PUT", OLD, 200, MOVED_ITEM, sent=NEW)
    c.out(envelope_ok(data(OLD, "moved", NEW, None, "moved"))); c.ok()
    c.run("move OldDev/Json env:GITHUB_REPOSITORY=Acme/Roc-JSON")
    c.guard(NEW); c.read(OLD, body=releases(ACTIVE_ITEM)); c.token()
    c.write("PUT", OLD, 201, MOVED_ITEM, sent=NEW)
    c.out(MOVED_LINE); c.ok()
    return c

def mv2():
    c = Case("mv2-offer", """
R-CM22 R-MV1 R-MV3 R-MV4 R-AP31 R-AP32 R-TP15 R-OUT2 R-OUT4 R-J1 (slice 251): `tln move <old> --to <new>` in a job of the old name: the request is a PUT with {"name": <new>} and the answer is 202, an offer. The guard checks the SUCCESSOR <new> only (the job repository is the old name and is not checked). There is no R-AP1 read (an offer has no `unchanged`, Q251-4), then the token, then the PUT. The answer item is the old name, still active, with no successor.
Run 1: the offer text of the catalog. Run 2: the same offer again (the registry answers 202 with no write: R-TP15) with --json: `offer` is the new name, `successor` null, `state` active. The text and the data do not change for a repeated offer. No stderr line in an exit-0 run.
""", env=JOB_OLD)
    c.run("move olddev/json --to acme/roc-json")
    c.guard(NEW); c.token()
    c.write("PUT", OLD, 202, ACTIVE_ITEM, sent=NEW)
    c.out(OFFERED_LINE); c.ok()
    c.run("move olddev/json --to acme/roc-json --json")
    c.guard(NEW); c.token()
    c.write("PUT", OLD, 202, ACTIVE_ITEM, sent=NEW)
    c.out(envelope_ok(data(OLD, "offered", None, NEW, "active"))); c.ok()
    return c

def mv3():
    c = Case("mv3-undo", """
R-CM22 R-MV1 R-MV2 R-MV3 R-MV4 R-AP31 R-OUT2 R-OUT4 R-J1 (slice 251): `tln move <old> --undo` is a DELETE with no body and no Content-Type. No privacy guard at all: there is no successor in the request (R-MV3, Q251-5). The R-AP1 read comes first (Q251-4).
Run 1 (job of the old name): the read shows a successor, 200: `removed`. Run 2: the read shows none, 200: `unchanged`. Run 3 (job of the SUCCESSOR, with --json): the job is the successor in the read, so the check of Q251-6 passes: `removed`. No stderr line in an exit-0 run.
""", env=JOB_OLD)
    c.run("move olddev/json --undo")
    c.read(OLD, body=releases(MOVED_ITEM)); c.token()
    c.write("DELETE", OLD, 200, ACTIVE_ITEM)
    c.out(REMOVED_LINE); c.ok()
    c.run("move olddev/json --undo")
    c.read(OLD, body=releases(ACTIVE_ITEM)); c.token()
    c.write("DELETE", OLD, 200, ACTIVE_ITEM)
    c.out(NONE_LINE); c.ok()
    c.run("move olddev/json --undo --json env:GITHUB_REPOSITORY=acme/roc-json")
    c.read(OLD, body=releases(MOVED_ITEM)); c.token()
    c.write("DELETE", OLD, 200, ACTIVE_ITEM)
    c.out(envelope_ok(data(OLD, "removed", None, None, "active"))); c.ok()
    return c

def mv4():
    c = Case("mv4-usage-stops", """
R-EC2 R-MV2 R-RG9 R-AP27 R-TP2 R-OUT1 (slice 251): the stops with no request, in the order of the checks (Q251-1, the order of tln yank): registry direct (2); --offline (15); the operand; the old name; --undo with --to; the value of --to; GITHUB_REPOSITORY; the checks of the names against the job (no --to in a job of the old name, the old name equal to --to, the job is neither); GITHUB_EVENT_NAME; GITHUB_SERVER_URL; the OIDC variables. Each run has the 4 first calls only (args, env_all twice, config.toml). The environment of a run is the one of the case: the job acme/roc-json, workflow_dispatch, https://github.com, both OIDC variables; `env:NAME=` changes one variable.
Runs 1 to 4: direct before offline before the operand. Runs 5 to 9: the operand and the old name. Runs 10 to 14: --undo with --to before the value of --to before the job. Runs 15 to 18: the names against the job (run 16: equal names; run 18: the names before the event). Runs 19 to 27: the event, the server URL and the OIDC variables, each unset value counts as no value (Q251-3). The last run (28): --json gives the error object on stdout.
""")
    steps = [
        ("move olddev/json --registry direct", 2, "usage", "tln move needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml."),
        ("move olddev/json --registry direct --offline", 2, "usage", "tln move needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml."),
        ("move olddev/json --offline", 15, "network", "tln move needs the network: --offline sends no request"),
        ("move --offline", 15, "network", "tln move needs the network: --offline sends no request"),
        ("move", 2, "usage", "tln move needs an old name: tln move <old-name> [--to <new-name>] [--undo]"),
        ("move olddev/json acme/x", 2, "usage", "tln move takes one old name: unexpected 'acme/x'"),
        ("move json", 2, "usage", "the old name 'json' is not a full github.com name (owner/repo)"),
        ("move gitlab.com/acme/json", 2, "usage", "the old name 'gitlab.com/acme/json' is not a full github.com name (owner/repo)"),
        ("move json --undo --to acme/x", 2, "usage", "the old name 'json' is not a full github.com name (owner/repo)"),
        ("move olddev/json --undo --to x", 2, "usage", "tln move --undo takes no --to"),
        ("move olddev/json --to x", 2, "usage", "the value of --to 'x' is not a full github.com name (owner/repo)"),
        ("move olddev/json env:GITHUB_REPOSITORY=", 2, "usage", "GITHUB_REPOSITORY is not set or is empty. tln move runs in a GitHub Actions job."),
        ("move olddev/json --to x env:GITHUB_REPOSITORY=", 2, "usage", "the value of --to 'x' is not a full github.com name (owner/repo)"),
        ("move olddev/json --undo --to acme/x env:GITHUB_REPOSITORY=", 2, "usage", "tln move --undo takes no --to"),
        ("move olddev/json env:GITHUB_REPOSITORY=olddev/json", 2, "usage", "the job repository olddev/json is the old name, so --to <new-name> is needed: tln move olddev/json --to <new-name> offers the new name"),
        ("move olddev/json --to olddev/json env:GITHUB_REPOSITORY=olddev/json", 2, "usage", "the old name and the new name are the same: olddev/json"),
        ("move olddev/json --to acme/roc-json env:GITHUB_REPOSITORY=third/lib", 2, "usage", "the job repository third/lib is neither the old name olddev/json nor the new name acme/roc-json. Run tln move in a job of olddev/json to offer the new name, or in a job of acme/roc-json to accept it."),
        ("move olddev/json --to acme/roc-json env:GITHUB_REPOSITORY=third/lib env:GITHUB_EVENT_NAME=push", 2, "usage", "the job repository third/lib is neither the old name olddev/json nor the new name acme/roc-json. Run tln move in a job of olddev/json to offer the new name, or in a job of acme/roc-json to accept it."),
        ("move olddev/json env:GITHUB_EVENT_NAME=push", 2, "usage", "tln move runs in a workflow_dispatch job: GITHUB_EVENT_NAME is push"),
        ("move olddev/json env:GITHUB_EVENT_NAME=", 2, "usage", "tln move runs in a workflow_dispatch job: GITHUB_EVENT_NAME is not set"),
        ("move olddev/json env:GITHUB_EVENT_NAME=push env:GITHUB_SERVER_URL=https://x.example", 2, "usage", "tln move runs in a workflow_dispatch job: GITHUB_EVENT_NAME is push"),
        ("move olddev/json env:GITHUB_SERVER_URL=https://github.example.com", 2, "usage", "tln move runs on github.com only: GITHUB_SERVER_URL is https://github.example.com, not https://github.com"),
        ("move olddev/json env:GITHUB_SERVER_URL=", 2, "usage", "tln move runs on github.com only: GITHUB_SERVER_URL is not set"),
        ("move olddev/json env:GITHUB_SERVER_URL=https://github.example.com env:ACTIONS_ID_TOKEN_REQUEST_URL=", 2, "usage", "tln move runs on github.com only: GITHUB_SERVER_URL is https://github.example.com, not https://github.com"),
        ("move olddev/json env:ACTIONS_ID_TOKEN_REQUEST_URL=", 2, "usage", "tln move needs an OIDC token, and ACTIONS_ID_TOKEN_REQUEST_URL is not set. In a GitHub Actions job, set permissions: id-token: write."),
        ("move olddev/json env:ACTIONS_ID_TOKEN_REQUEST_TOKEN=", 2, "usage", "tln move needs an OIDC token, and ACTIONS_ID_TOKEN_REQUEST_TOKEN is not set. In a GitHub Actions job, set permissions: id-token: write."),
        ("move olddev/json --undo env:ACTIONS_ID_TOKEN_REQUEST_URL=", 2, "usage", "tln move needs an OIDC token, and ACTIONS_ID_TOKEN_REQUEST_URL is not set. In a GitHub Actions job, set permissions: id-token: write."),
    ]
    for cmd, code, kind, msg in steps:
        c.run(cmd)
        c.fail(code, kind, msg)
    c.run("move json --json")
    c.out(envelope_err("usage", 2, "the old name 'json' is not a full github.com name (owner/repo)"))
    c.fail(2, "usage", "the old name 'json' is not a full github.com name (owner/repo)")
    return c

PRIV_TEXT = "GitHub repository %s: not found, or private. Private packages are not supported. With no token GitHub answers 404 for a private repository: set GITHUB_TOKEN or GH_TOKEN, or log in with gh (gh auth login), and run the command again."

def mv5():
    c = Case("mv5-guard", """
R-MV3 R-RG4 R-RG5 R-RG6 R-EC2 R-AP31 (slice 251): the privacy guard checks the successor only, before the first registry request (the R-AP1 read). A private successor (200 with private true) and an unknown successor (404) are exit 2 and nothing is sent to the registry. Run 1: the job acme/priv (a move: the successor is the job). Run 2: acme/gone (404). Run 3: an offer to the private acme/priv, from a job of the old name: the old name olddev/json has no GitHub fixture and is never asked (R-MV3). A refused answer is not kept, so run 3 asks again (the second answer of the same URL). The text is the no-token text of R-RG6 (the test hook TALON_GITHUB_API gives no token, R-EV19).
""")
    c.run("move olddev/json env:GITHUB_REPOSITORY=acme/priv")
    c.guard("acme/priv", private=True)
    c.fail(2, "usage", PRIV_TEXT % "acme/priv")
    c.run("move olddev/json env:GITHUB_REPOSITORY=acme/gone")
    c.guard("acme/gone", status=404, body='{"message":"Not Found"}')
    c.fail(2, "usage", PRIV_TEXT % "acme/gone")
    c.run("move olddev/json --to acme/priv env:GITHUB_REPOSITORY=olddev/json")
    c.guard("acme/priv", private=True)
    c.fail(2, "usage", PRIV_TEXT % "acme/priv")
    return c

D_FORBIDDEN = 'token claim repository_owner_id is "40": it is not the owner of olddev/json, and olddev/json has no offer for acme/roc-json'
D_MISMATCH = "the successor acme/roc-json fails the exposes check: the newest candidate of the successor does not expose the modules Encode, Decode"
D_MISSING = "no package named olddev/json has a repos row"
D_CHANGED = "the name olddev/json is bound to another GitHub account (repository id 100)"
D_STATE = 'token claim repository is "olddev/json": the old repository olddev/json is in the state moved, an offer needs the state active'
ISSUES = "https://github.com/roc-talon/talon/issues"

def mv6():
    c = Case("mv6-refused", """
R-MV4 R-E6 R-J7 R-EC20 R-AP22 R-AP31 R-TP12 R-TP15 (slice 251): a refused write is exit 20 (rejected), with `status` and `type` in error.details. One request each, no wait, no new token (only a 401 gets one). The message is the `detail` of the registry, the type, and `Fix the names or the workflow, then run the command again.` (Q251-8, proposal).
Run 1: 403 forbidden (a successor token of another owner, no offer). Run 2: 422 successor-mismatch, the exposes check (the detail names the check and the modules). Run 3: 404 for an old name that the registry does not index, with the R-AP1 read answering 404 (the read is then `unknown` and the write goes on), with --json. Run 4: 403 repository-changed with issues_url, for a --undo, with --json: the message adds the advice of R-TP12 and the URL (Q251-8). Run 5: an offer (no R-AP1 read) refused with 403.
""")
    c.run("move olddev/json")
    c.guard(NEW); c.read(OLD, body=releases(ACTIVE_ITEM)); c.token()
    c.write("PUT", OLD, 403, problem(403, "forbidden", D_FORBIDDEN), sent=NEW)
    c.fail(20, "rejected", "%s (/errors/forbidden). %s" % (D_FORBIDDEN, REFUSED_TAIL))
    c.run("move olddev/json")
    c.guard(NEW); c.read(OLD, body=releases(ACTIVE_ITEM)); c.token()
    c.write("PUT", OLD, 422, problem(422, "successor-mismatch", D_MISMATCH), sent=NEW)
    c.fail(20, "rejected", "%s (/errors/successor-mismatch). %s" % (D_MISMATCH, REFUSED_TAIL))
    c.run("move olddev/json --json")
    c.guard(NEW); c.read(OLD, status=404, body=problem(404, "not-found", "D")); c.token()
    c.write("PUT", OLD, 404, problem(404, "not-found", D_MISSING), sent=NEW)
    c.out(envelope_err("rejected", 20, "%s (/errors/not-found). %s" % (D_MISSING, REFUSED_TAIL), {"status": 404, "type": "/errors/not-found"}))
    c.fail(20, "rejected", "%s (/errors/not-found). %s" % (D_MISSING, REFUSED_TAIL))
    c.run("move olddev/json --undo --json env:GITHUB_REPOSITORY=olddev/json")
    c.read(OLD, body=releases(MOVED_ITEM)); c.token()
    c.write("DELETE", OLD, 403, problem(403, "repository-changed", D_CHANGED, issues_url=ISSUES))
    c.out(envelope_err("rejected", 20, "%s. Only the registry operator can change this. Open an issue: %s" % (D_CHANGED, ISSUES), {"status": 403, "type": "/errors/repository-changed"}))
    c.fail(20, "rejected", "%s. Only the registry operator can change this. Open an issue: %s" % (D_CHANGED, ISSUES))
    c.run("move olddev/json --to acme/roc-json env:GITHUB_REPOSITORY=olddev/json")
    c.guard(NEW); c.token()
    c.write("PUT", OLD, 403, problem(403, "forbidden", D_STATE), sent=NEW)
    c.fail(20, "rejected", "%s (/errors/forbidden). %s" % (D_STATE, REFUSED_TAIL))
    return c

def mv7():
    c = Case("mv7-undo-holder", """
R-MV1 R-MV2 R-MV4 R-AP31 R-TP15 R-EC2 (slice 251, Q251-6): `--undo` in a job that is neither the old name nor its successor. The check needs the R-AP1 read (the successor of the old name), so it comes after the read and before the token: exit 2, no token request, no write.
Run 1: the read shows the successor acme/roc-json: the job third/lib is neither. Run 2: the read shows no successor. Run 3: the read answers 404 (the successor is unknown): the check passes, the registry decides (R-AP31): a DELETE answered 403, exit 20.
""", env={"GITHUB_REPOSITORY": "third/lib"})
    c.run("move olddev/json --undo")
    c.read(OLD, body=releases(MOVED_ITEM))
    c.fail(2, "usage", "the job repository third/lib is neither the old name olddev/json nor its successor acme/roc-json. Run tln move --undo in a job of one of them.")
    c.run("move olddev/json --undo")
    c.read(OLD, body=releases(ACTIVE_ITEM))
    c.fail(2, "usage", "the job repository third/lib is not the old name olddev/json, and olddev/json has no successor. Run tln move --undo in a job of olddev/json.")
    c.run("move olddev/json --undo")
    c.read(OLD, status=404, body=problem(404, "not-found", "D")); c.token()
    d = 'token claim repository is "third/lib": it is not olddev/json and it is not the successor of olddev/json'
    c.write("DELETE", OLD, 403, problem(403, "forbidden", d))
    c.fail(20, "rejected", "%s (/errors/forbidden). %s" % (d, REFUSED_TAIL))
    return c

def mv8():
    c = Case("mv8-token-refused", """
R-TP2 R-AP27 R-EC2 R-E6 R-MV4 (slice 251): the token request is refused (403): exit 2, the text names id-token: write; it answers 500: exit 15. No write request. The R-AP1 read comes first, the token second (as tln yank and tln publish). The runs are --undo, so there is no privacy guard.
""", env=JOB_OLD)
    c.run("move olddev/json --undo")
    c.read(OLD, body=releases(MOVED_ITEM)); c.token(status=403, body='{"message":"Forbidden"}')
    c.fail(2, "usage", "the GitHub OIDC token request was refused (403). The job needs permissions: id-token: write.")
    c.run("move olddev/json --undo")
    c.read(OLD, body=releases(MOVED_ITEM)); c.token(status=500, body='{"message":"oops"}')
    c.fail(15, "network", "the GitHub OIDC token request failed: answered 500")
    return c

def mv9():
    c = Case("mv9-renew-401", """
R-AP34 R-TP2 R-MV4 (slice 251): a 401 gets one new OIDC token and one more request, with no wait. Run 1 (a move): 401, a new token (jwt2), 201: `moved`. Run 2 (--undo): 401, a new token, 401 again: exit 20 `the registry refused the new token too`. The guard file of run 1 is the only file written.
""")
    c.run("move olddev/json")
    c.guard(NEW); c.read(OLD, body=releases(ACTIVE_ITEM)); c.token("jwt1")
    c.write("PUT", OLD, 401, problem(401, "unauthenticated", "D"), sent=NEW, jwt="jwt1")
    c.token("jwt2")
    c.write("PUT", OLD, 201, MOVED_ITEM, sent=NEW, jwt="jwt2")
    c.out(MOVED_LINE); c.ok()
    c.run("move olddev/json --undo env:GITHUB_REPOSITORY=olddev/json")
    c.read(OLD, body=releases(MOVED_ITEM)); c.token("jwt1")
    c.write("DELETE", OLD, 401, problem(401, "unauthenticated", "D"), jwt="jwt1")
    c.token("jwt2")
    c.write("DELETE", OLD, 401, problem(401, "unauthenticated", "D"), jwt="jwt2")
    c.fail(20, "rejected", "D (/errors/unauthenticated): the registry refused the new token too.")
    return c

def mv10():
    c = Case("mv10-retries", """
R-AP34 R-AP82 R-DA9 R-MV4 (slice 251): a write is sent again after a 429, a 5xx or no answer, with the waits of R-AP34. Run 1 (a move): 429 with Retry-After 7 (wait 7 s), 503 busy (8 s), no answer (30 s), then 201: `moved`. Run 2 (--undo): 502 (wait 2 s), then 200: `removed`. The R-AP1 read and the token request are not sent again.
""")
    c.run("move olddev/json")
    c.guard(NEW); c.read(OLD, body=releases(ACTIVE_ITEM)); c.token()
    c.write("PUT", OLD, 429, problem(429, "rate-limited", "D"), sent=NEW, headers=NOSTORE + ["Retry-After: 7"])
    c.sleep(7000)
    c.write("PUT", OLD, 503, problem(503, "busy", "D"), sent=NEW)
    c.sleep(8000)
    c.write("PUT", OLD, timeout=True, body="", sent=NEW)
    c.sleep(30000)
    c.write("PUT", OLD, 201, MOVED_ITEM, sent=NEW)
    c.out(MOVED_LINE); c.ok()
    c.run("move olddev/json --undo env:GITHUB_REPOSITORY=olddev/json")
    c.read(OLD, body=releases(MOVED_ITEM)); c.token()
    c.write("DELETE", OLD, 502, problem(502, "upstream", "D"))
    c.sleep(2000)
    c.write("DELETE", OLD, 200, ACTIVE_ITEM)
    c.out(REMOVED_LINE); c.ok()
    return c

def mv11():
    c = Case("mv11-retries-exhausted", """
R-AP34 R-RG9 R-AP22 R-E6 R-MV4 (slice 251): after the last try (4 requests, waits 2 s, 8 s, 30 s, or Retry-After) the stop is exit 15 with the number of requests. Run 1 (a move): 4 times no answer: `The move may be done. Run the command again.`, the URL followed by the source. Run 2 (an offer, no R-AP1 read): 4 times no answer: `The offer may be done.` Run 3 (--undo): 4 times 503 busy with Retry-After 3 (waits 3 s each): `is busy (503) after 4 requests. Try again in 3 s.`
""")
    src = "the registry http://127.0.0.1:9 (TALON_REGISTRY) gave no answer 4 times: no answer in 20 s. The %s may be done. Run the command again."
    c.run("move olddev/json")
    c.guard(NEW); c.read(OLD, body=releases(ACTIVE_ITEM)); c.token()
    for i, w in enumerate([2000, 8000, 30000, None]):
        c.write("PUT", OLD, timeout=True, body="", sent=NEW)
        if w:
            c.sleep(w)
    c.fail(15, "network", src % "move")
    c.run("move olddev/json --to acme/roc-json env:GITHUB_REPOSITORY=olddev/json")
    c.guard(NEW); c.token()
    for i, w in enumerate([2000, 8000, 30000, None]):
        c.write("PUT", OLD, timeout=True, body="", sent=NEW)
        if w:
            c.sleep(w)
    c.fail(15, "network", src % "offer")
    c.run("move olddev/json --undo env:GITHUB_REPOSITORY=olddev/json")
    c.read(OLD, body=releases(MOVED_ITEM)); c.token()
    for i in range(4):
        c.write("DELETE", OLD, 503, problem(503, "busy", "D"), headers=NOSTORE + ["Retry-After: 3"])
        if i < 3:
            c.sleep(3000)
    c.fail(15, "network", "the registry http://127.0.0.1:9 (TALON_REGISTRY) is busy (503) after 4 requests. Try again in 3 s.")
    return c

def mv12():
    c = Case("mv12-registry-no-answer", """
R-RG9 R-E6 R-AP1 R-AP22 R-MV4 (slice 251): the R-AP1 read of the old name gets no answer, then a 500, from a registry that a person set (TALON_REGISTRY): exit 15, the message names the URL and the source only (R-RG9: not the advice for direct, which a move cannot use). No token request, no write. The privacy guard comes first (it has its own answer, the file is then kept).
""")
    c.run("move olddev/json")
    c.guard(NEW)
    c.answer("GET", REG, "v1/packages/olddev/json/releases", "", timeout=True,
             requires=["require user-agent: tln/0.0.1", "require cache-control: no-cache", "require-none authorization"])
    c.calls += "http_get http://127.0.0.1:9/v1/packages/olddev/json/releases\n  User-Agent: tln/0.0.1\n  Cache-Control: no-cache\n"
    c.fail(15, "network", "the registry http://127.0.0.1:9 (TALON_REGISTRY) gave no answer: no answer in 20 s.")
    c.run("move olddev/json")
    c.guard(NEW)
    c.read(OLD, status=500, body=problem(500, "internal", "D"))
    c.fail(15, "network", "the registry http://127.0.0.1:9 (TALON_REGISTRY) answered 500: D.")
    return c

def mv13():
    c = Case("mv13-registry-flag", """
R-FL5 R-RG1 R-RG7 R-CM22 (slice 251): the flag --registry is read by tln move (no TALON_REGISTRY in the environment). The token audience is the registry URL of the flag.
""", drop_env=("TALON_REGISTRY",))
    c.run("move olddev/json --registry http://127.0.0.1:9")
    c.guard(NEW); c.read(OLD, body=releases(ACTIVE_ITEM)); c.token()
    c.write("PUT", OLD, 201, MOVED_ITEM, sent=NEW)
    c.out(MOVED_LINE); c.ok()
    return c

def mv14():
    c = Case("mv14-case-fold", """
R-IK2 R-MV1 R-MV3 R-AP31 R-OUT2 (slice 251, Q251-11): names with upper case. Run 1: the job Acme/OLD is the old name Acme/Old (the compare is in lower case), so `--to Acme/New` is an offer: the guard file, the URL and the body have lower case (acme/new, acme/old), and so has the output. Run 2: a move by the job Acme/NEW: the old name Acme/Old is lower case in the URL, the successor in the body, and the guard file is known (one read_files, no request).
""", env={"GITHUB_REPOSITORY": "Acme/OLD"})
    c.run("move Acme/Old --to Acme/New")
    c.guard("acme/new"); c.token()
    c.write("PUT", "acme/old", 202, item("acme/old", "active", None), sent="acme/new")
    c.out("offered: acme/old to acme/new. To accept, run tln move acme/old in a workflow_dispatch job of acme/new."); c.ok()
    c.run("move Acme/Old env:GITHUB_REPOSITORY=Acme/NEW")
    c.guard("acme/new"); c.read("acme/old", body=releases(item("acme/old", "active", None))); c.token()
    c.write("PUT", "acme/old", 201, item("acme/old", "moved", "acme/new"), sent="acme/new")
    c.out("moved: acme/old to acme/new. Users see it in tln outdated, and follow it with tln update <alias>."); c.ok()
    return c

def mv15():
    c = Case("mv15-read-not-retried", """
R-RG9 R-AP34 R-E6 R-AP1 (slice 251, Q251-9): the R-AP1 read of the old name is not sent again: one 503 is exit 15 (the message names the URL and the source, no advice for direct), with no second read, no token request and no write. The read has a second answer (200) that a retry would get: the calls.log shows no second read. Run 1 is a move, run 2 is --undo.
""")
    ok = releases(ACTIVE_ITEM)
    c.run("move olddev/json")
    c.guard(NEW); c.read(OLD, status=503, body=problem(503, "upstream", "D"))
    c.fail(15, "network", "the registry http://127.0.0.1:9 (TALON_REGISTRY) answered 503: D.")
    c.run("move olddev/json --undo env:GITHUB_REPOSITORY=olddev/json")
    c.read(OLD, status=503, body=problem(503, "upstream", "D"))
    c.fail(15, "network", "the registry http://127.0.0.1:9 (TALON_REGISTRY) answered 503: D.")
    # the answer that a second read would get (never asked)
    c.answer("GET", REG, "v1/packages/olddev/json/releases", ok, requires=["require user-agent: tln/0.0.1", "require cache-control: no-cache", "require-none authorization"])
    return c

if __name__ == "__main__":
    if os.path.isdir(ROOT):
        shutil.rmtree(ROOT)
    for build in [mv1, mv2, mv3, mv4, mv5, mv6, mv7, mv8, mv9, mv10, mv11, mv12, mv13, mv14, mv15]:
        build().write_all()
    print("wrote", ROOT)
