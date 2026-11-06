#!/usr/bin/env bash
# Slice 221: makes the L2 cases tests/commands/cases/publish/pu1 to pu15 (`tln publish`; CLI R-CM13, R-PUB1 to R-PUB3; Registry R-AP8, R-AP27, R-AP34, R-TP2; CLI 3 R-E6). The expected files are written from the design readings of docs/slices/221-publish.md, not from a run of tln.
# Usage: tests/tools/mk-publish.sh        (writes the 15 case dirs)
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
exec python3 -I - "$ROOT/tests/commands/cases/publish" <<'PY'
import os, sys, shutil
base = sys.argv[1]
shutil.rmtree(base, ignore_errors=True)
H = "4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq"
H2 = "895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw"
URL = "https://github.com/acme/json/releases/download/2.1.0/%s.tar.zst" % H
REG = "http://127.0.0.1:9"
N1, N2, N3, N4 = "nightly-2026-10-12-2664a27", "nightly-2026-10-13-bbbbbbb", "nightly-2026-10-14-38a3029", "nightly-2026-10-15-0a0a0a0"
CFG = "$HOME/.config/talon/config.toml"
DB = "$HOME/.cache/roc/talon/compat.db"
GH = "https://api.github.com/repos/acme/json/releases/tags/2.1.0"
TOK = "http://127.0.0.1:8/token?api-version=2.0&audience=http%3A%2F%2F127.0.0.1%3A9"

def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)

def lines(*ls): return "\n".join(ls) + "\n"

ENV = lines("HOME={w}/home", "CI=true", "GITHUB_TOKEN=gh1", "GITHUB_REPOSITORY=acme/json", "GITHUB_REF=refs/tags/2.1.0",
            "ACTIONS_ID_TOKEN_REQUEST_URL=http://127.0.0.1:8/token?api-version=2.0", "ACTIONS_ID_TOKEN_REQUEST_TOKEN=req1", "TALON_REGISTRY=" + REG)

RELEASE = ('{"tag_name":"2.1.0","draft":false,"prerelease":false,"published_at":"2026-10-14T10:00:00Z","assets":[{"name":"%s.tar.zst","size":1234,"browser_download_url":"%s"}]}' % (H, URL))
REL_ANSWER = ('{"log_index":41,"hash":"%s","group":"github.com/acme/json/releases/download/{v}","series":"2","version":"2.1.0","url":"%s","tag":"2.1.0","roc_version":null,"repo":"acme/json","published_at":1792065600000,"yanked":false,"yank_reason":null,"withdrawn":null,"provenance":["oidc"]}' % (H, URL))

def fact(h, n, t, o, mods="", closure=""): return "fact\t%s\t%s\t%s\t%s\t%s\t%s\n" % (h, n, t, o, mods, closure)
STORE = ("format\t1\n" + fact(H, N3, "any", "fail", "Foo.roc") + fact(H, N1, "any", "pass") + fact(H, N4, "any", "crash") + fact(H, N2, "any", "hang")
         + fact(H, N1, "linux_x86_64", "pass", "", "abc") + fact(H, N2, "x64musl", "pass") + fact(H2, N1, "any", "pass"))
BODY4 = ('{"compat":[{"error_digest":null,"nightly":"%s","result":"pass","target":"any"},{"error_digest":null,"nightly":"%s","result":"hang","target":"any"},'
         '{"error_digest":null,"nightly":"%s","result":"fail","target":"any"},{"error_digest":null,"nightly":"%s","result":"crash","target":"any"}],"url":"%s"}' % (N1, N2, N3, N4, URL))
BODY0 = '{"url":"%s"}' % URL

def meta(status, extra=(), body=True):
    return lines("status %d" % status, *(["header Content-Type: application/json"] if body else []), "header Cache-Control: no-store", *extra)

def mk(case, rules, runs, stdout, stderr="", exit_="0\n", calls=(), store=STORE, env=ENV, routes=None, release=True, token=True, files=None):
    d = os.path.join(base, case)
    write(d + "/entry", "commands\n")
    write(d + "/rules", rules + "\n")
    write(d + "/fx/commands", lines(*runs))
    write(d + "/fx/env", env)
    if store is not None:
        write(d + "/given/home/.cache/roc/talon/compat.tsv", store)
    if release:
        r = d + "/fx/http/api.github.com/repos/acme/json/releases/tags/2.1.0"
        write(r, RELEASE)
        write(r + ".meta", meta(200, ["require authorization: Bearer gh1", "require user-agent: tln/0.0.1"]))
    if token:
        r = d + "/fx/http/127.0.0.1%3A8/token"
        write(r, '{"count":1,"value":"jwt1"}')
        write(r + ".meta", meta(200, ["require authorization: bearer req1"]))
    for (path, text, m) in (routes or []):
        r = d + "/fx/http/" + path
        write(r, text)
        write(r + ".meta", m)
    for (rel, text) in (files or {}).items():
        write(d + "/" + rel, text)
    write(d + "/expect/stdout", stdout)
    write(d + "/expect/stderr", stderr)
    write(d + "/expect/exit", exit_)
    write(d + "/expect/calls.log", lines(*calls))
    write(d + "/expect/tree.diff", "")

POSTH = ["require user-agent: tln/0.0.1", "require content-type: application/json", "require-none talon-contributor"]
def post_route(n, status, body, auth="jwt1", extra=(), has_body=True):
    name = "127.0.0.1%3A9/v1/releases.POST" + ("" if n == 1 else ".%d" % n)
    return (name, body, meta(status, ["require authorization: Bearer " + auth] + POSTH + list(extra), has_body))

PRE = ["args", "env_all", "env_all", "read_files " + CFG]
def gh(): return ["http_get " + GH, "  User-Agent: tln/0.0.1", "  Authorization: Bearer gh1"]
def facts_of(): return ["db_query %s busy_ms=5000 format=1 facts_of=%s" % (DB, H)]
def tokget(): return ["http_send GET %s timeout=20" % TOK, "  Authorization: bearer req1"]
def post(body, jwt="jwt1"):
    return ["http_send POST %s/v1/releases timeout=20" % REG, "  User-Agent: tln/0.0.1", "  Content-Type: application/json", "  Authorization: Bearer " + jwt, "  <body> " + body]
def full(body, jwt="jwt1"): return PRE + gh() + facts_of() + tokget() + post(body, jwt)
OKLINE = "published acme/json 2.1.0: %s, 4 facts sent\n" % H

# pu1: 201, then 200 for the same label, then --json.
data = '{"schema":1,"command":"publish","ok":true,"data":{"publish":{"repository":"acme/json","tag":"2.1.0","hash":"%s","created":true,"facts":4}},"error":null}\n' % H
mk("pu1-publish-ok", "R-CM13 R-PB5 R-PU2 R-PU5 R-TP2 R-TP17 R-AP8 R-AP26 R-AP71 R-OUT2 R-OUT4 R-J1 (slice 221): `tln publish` in a job for the tag 2.1.0 of acme/json, registry http://127.0.0.1:9 (TALON_REGISTRY). Calls in order: the release of the tag (GITHUB_TOKEN as Authorization), the facts of the hash, the OIDC token (audience = the base URL, header `Authorization: bearer`), the POST with `Authorization: Bearer <JWT>` and the body {compat, url}. The 4 unit checks of the hash go (pass, hang, fail, crash: sorted by nightly, error_digest null); the build row, the x64musl row and the facts of another hash do not. Run 1: 201 (new). Run 2: 200 (the same label). Run 3: --json.",
   ["publish", "publish", "publish --json"],
   "== publish\n" + OKLINE + "exit 0\n== publish\nacme/json 2.1.0 is published already: %s, 4 facts sent\nexit 0\n== publish --json\n" % H + data + "exit 0\n",
   calls=full(BODY4) + full(BODY4) + full(BODY4),
   routes=[post_route(1, 201, REL_ANSWER, extra=["header Location: /v1/artifacts/" + H]), post_route(2, 200, REL_ANSWER)])

# pu2: no fact of the hash.
mk("pu2-no-facts", "R-PUB3 R-PB5 R-PU5 R-AP71 (slice 221): compat.db has only a fact of another hash. The body has no `compat` member, the warning of R-PUB3 is on stderr (before the token request), the exit code is 0.",
   ["publish"], "== publish\npublished acme/json 2.1.0: %s, no facts sent\nexit 0\n" % H,
   stderr="warning: no probe facts for %s: run tln probe --range <bundle file> before tln publish\n" % H,
   calls=full(BODY0), store="format\t1\n" + fact(H2, N1, "any", "pass"),
   routes=[post_route(1, 201, REL_ANSWER)])

# pu3: the stops before any request, in the order of R-PUB4 item 1.
D = "tln publish needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml."
RUN = "tln publish runs in a GitHub Actions job."
BRANCH = "GITHUB_REF is refs/heads/main, not a tag. The job must run on a tag: tln publish registers the release of the tag."
PERM = "tln publish needs an OIDC token, and ACTIONS_ID_TOKEN_REQUEST_URL is not set. In a GitHub Actions job, set permissions: id-token: write."
runs3 = [
  ("publish --registry direct", 2, "usage", D),
  ("publish --registry direct --offline", 2, "usage", D),
  ("publish --offline", 15, "network", "tln publish needs the network: --offline sends no request"),
  ("publish extra --offline", 15, "network", "tln publish needs the network: --offline sends no request"),
  ("publish extra", 2, "usage", "tln publish takes no argument: 'extra'"),
  ("publish extra env:GITHUB_REPOSITORY=", 2, "usage", "tln publish takes no argument: 'extra'"),
  ("publish env:GITHUB_REPOSITORY=", 2, "usage", "GITHUB_REPOSITORY is not set or is empty. " + RUN),
  ("publish env:GITHUB_REPOSITORY=acme/json/x", 2, "usage", "GITHUB_REPOSITORY is acme/json/x, not of the form owner/repo."),
  ("publish env:GITHUB_REF=refs/heads/main", 2, "usage", BRANCH),
  ("publish env:GITHUB_REF=refs/heads/main env:ACTIONS_ID_TOKEN_REQUEST_URL=", 2, "usage", BRANCH),
  ("publish env:ACTIONS_ID_TOKEN_REQUEST_URL=", 2, "usage", PERM),
]
mk("pu3-usage-stops", "R-EC2 R-PUB1 R-PUB4 R-AP27 R-TP2 R-FL5 (slice 221, Design Q507, Q508, Q512): each stop has no request, and the calls of each run end after the read of config.toml. The order of R-PUB4 item 1: direct (exit 2) before --offline (exit 15) before an operand (exit 2) before the repository (empty, not owner/repo) and the ref (a branch) before the OIDC variables (the message names id-token: write). The release route is not there: no run reaches it (the missing permission stops before the release read).",
   [r[0] for r in runs3],
   "".join("== %s\nexit %d\n" % (r[0], r[1]) for r in runs3),
   stderr=lines(*["tln: error[%s]: %s" % (r[2], r[3]) for r in runs3]),
   exit_="0\n", calls=PRE * len(runs3), release=False, token=False)

# pu4: no release for the tag.
mk("pu4-no-release", "R-PUB2 R-EC2 R-AP27 (slice 221): the API answers 404 for the tag: exit 2, the message names the case. The calls end after the release request: no facts query, no token request, no registry request.",
   ["publish"], "== publish\nexit 2\n",
   stderr="tln: error[usage]: acme/json has no release for the tag 2.1.0. Create the release and upload the package first, then run tln publish.\n",
   calls=PRE + gh(), release=False, token=False)

# pu5: a newer compat.db.
mk("pu5-compat-too-new", "R-TF3 R-PB5 (slice 221): compat.db has format 2 (this tln writes 1): exit 19 (input) before the token request and any registry request.",
   ["publish"], "== publish\nexit 19\n",
   stderr="tln: error[input]: %s has format 2. This tln writes format 1. Run: tln tool update talon\n" % DB.replace("$HOME", "$HOME"),
   calls=PRE + gh() + facts_of(), store="format\t2\n" + fact(H, N1, "any", "pass"),
   routes=[post_route(1, 201, REL_ANSWER)], token=True)

# pu6: the schedule of R-AP34, 4 sends, the token is fetched once.
busy = '{"type":"/errors/busy","title":"T","status":503,"detail":"D"}'
rl = '{"type":"/errors/rate-limited","title":"T","status":429,"detail":"D"}'
mk("pu6-retries", "R-AP34 R-AP82 R-DA9 R-TP2 (slice 221): the request is sent again after 429, 503 and no answer: the waits are the Retry-After of the first answer (7 s), then 8 s and 30 s (the schedule, no header). The 4th request gets 201. The OIDC token is fetched once (a new one is for a 401 only). `sleep` is a call of the fake Fx.",
   ["publish"], "== publish\n" + OKLINE + "exit 0\n",
   calls=PRE + gh() + facts_of() + tokget() + post(BODY4) + ["sleep 7000"] + post(BODY4)[0:0] + post(BODY4) + ["sleep 8000"] + post(BODY4) + ["sleep 30000"] + post(BODY4),
   routes=[post_route(1, 429, rl, extra=["header Retry-After: 7"]), post_route(2, 503, busy),
           ("127.0.0.1%3A9/v1/releases.POST.3", "", lines("error timeout", *(["require authorization: Bearer jwt1"] + POSTH))),
           post_route(4, 201, REL_ANSWER)])

# pu7: 4 times 502.
up = '{"type":"/errors/upstream","title":"T","status":502,"detail":"D"}'
mk("pu7-retries-exhausted", "R-AP34 R-AP22 R-E6 R-J7 (slice 221): 502 for each of the 4 requests (the first and 3 more), with waits of 2 s, 8 s and 30 s. Exit 15 (network), the text of the CLI 3 example: `the registry answered 502 (/errors/upstream) 4 times. Try again later.`",
   ["publish"], "== publish\nexit 15\n",
   stderr="tln: error[network]: the registry answered 502 (/errors/upstream) 4 times. Try again later.\n",
   calls=PRE + gh() + facts_of() + tokget() + post(BODY4) + ["sleep 2000"] + post(BODY4) + ["sleep 8000"] + post(BODY4) + ["sleep 30000"] + post(BODY4),
   routes=[post_route(1, 502, up)])

# pu8: a 401 gets a new token.
unauth = '{"type":"/errors/unauthenticated","title":"T","status":401,"detail":"D"}'
mk("pu8-renew-401", "R-AP34 R-TP2 R-AP8 (slice 221): the first request gets 401: a new OIDC token (the token request again, the fake gives jwt2 to the second) and the same request once more, with no wait. The second gets 201.",
   ["publish"], "== publish\n" + OKLINE + "exit 0\n",
   calls=PRE + gh() + facts_of() + tokget() + post(BODY4) + tokget() + post(BODY4, "jwt2"),
   routes=[post_route(1, 401, unauth), post_route(2, 201, REL_ANSWER, auth="jwt2"),
           ("127.0.0.1%3A8/token.2", '{"count":1,"value":"jwt2"}', meta(200, ["require authorization: bearer req1"]))])

# pu9: refused writes.
conflict = '{"type":"/errors/label-conflict","title":"T","status":409,"detail":"the registry has roc-lang/json 2.1.0 with another hash"}'
forb = '{"type":"/errors/forbidden","title":"T","status":403,"detail":"token claim ref is refs/heads/main, the asset URL has the tag 2.1.0"}'
mk("pu9-refused", "R-E6 R-AP22 R-AP34 R-J7 (slice 221): a refused write is exit 20 (rejected), one request each, no wait, no new token (only a 401 gets one). The texts are the first 2 lines of the CLI 3 R-E6 example: 409 label-conflict, then 403 forbidden.",
   ["publish", "publish"], "== publish\nexit 20\n== publish\nexit 20\n",
   stderr=lines("tln: error[rejected]: the registry has roc-lang/json 2.1.0 with another hash (/errors/label-conflict). The tag was released again. Release a new version.",
                "tln: error[rejected]: token claim ref is refs/heads/main, the asset URL has the tag 2.1.0 (/errors/forbidden). Run tln publish in a job for the tag."),
   calls=full(BODY4) + full(BODY4),
   routes=[post_route(1, 409, conflict), post_route(2, 403, forb)])

# pu10: flags that are read or accepted.
mk("pu10-flags", "R-PUB4 R-FL5 R-RG1 R-PD14 (slice 221, Design Q508, Q520): `--file` is accepted and has no other effect; `--registry <url>` is read (the registry is the target of the request) with no TALON_REGISTRY. Both runs publish (201).",
   ["publish --file p/main.roc", "publish --registry http://127.0.0.1:9 env:TALON_REGISTRY="],
   "== publish --file p/main.roc\n" + OKLINE + "exit 0\n== publish --registry http://127.0.0.1:9 env:TALON_REGISTRY=\n" + OKLINE + "exit 0\n",
   calls=full(BODY4) + full(BODY4),
   routes=[post_route(1, 201, REL_ANSWER)])

# pu11: the token request is refused.
mk("pu11-token-refused", "R-TP2 R-AP27 R-EC2 R-PUB4 (slice 221, Design Q515): GitHub answers 403 to the token request (the job has no id-token: write): exit 2, the message names the permission. No registry request. The token never is in a message.",
   ["publish"], "== publish\nexit 2\n",
   stderr="tln: error[usage]: the GitHub OIDC token request was refused (403). The job needs permissions: id-token: write.\n",
   calls=PRE + gh() + facts_of() + tokget(), token=False,
   routes=[("127.0.0.1%3A8/token", '{"message":"Forbidden"}', meta(403, ["require authorization: bearer req1"]))])

# pu12: 401 twice.
mk("pu12-renew-twice", "R-AP34 R-E6 R-PUB4 (slice 221, Design Q516): 401, a new token, 401 again: exit 20 (rejected), the detail and the words `the registry refused the new token too`. 2 token requests, 2 requests, no wait, no third request.",
   ["publish"], "== publish\nexit 20\n",
   stderr="tln: error[rejected]: D (/errors/unauthenticated): the registry refused the new token too.\n",
   calls=PRE + gh() + facts_of() + tokget() + post(BODY4) + tokget() + post(BODY4, "jwt2"),
   routes=[post_route(1, 401, unauth), post_route(2, 401, unauth, auth="jwt2"),
           ("127.0.0.1%3A8/token.2", '{"count":1,"value":"jwt2"}', meta(200, ["require authorization: bearer req1"]))])

# pu13: compat.db busy.
mk("pu13-db-busy", "R-PUB4 R-PUB3 R-CC8 (slice 221, Design Q517): the read of compat.db is busy: one warning, then the publish with no `compat` member (and no `no probe facts` warning). Exit 0.",
   ["publish"], "== publish\n" + "published acme/json 2.1.0: %s, no facts sent\nexit 0\n" % H,
   stderr="warning: compat.db could not be read (busy): publishing with no probe facts\n",
   calls=full(BODY0), files={"fx/db": "1: busy\n"},
   routes=[post_route(1, 201, REL_ANSWER)])

# pu14: no queue send.
QUEUE = "1\t%s\t%s\tany\tpass\t0.0.1\t2026-10-01T00:00:00Z\n" % (H2, N1)
SJ = '{"format":1,"id":"0123456789abcdeffedcba9876543210","sent":0,"counted":0,"first":0,"first_sent_at":null,"last_sent_at":null,"token":null,"token_expires_at":null,"account":null}\n'
mk("pu14-no-queue-send", "R-SH4 R-PUB4 R-SH2 (slice 221, Design Q518): sharing is on (share = true, a registry, no CI, no DO_NOT_TRACK) and the queue has a row, but `tln publish` does not send the queue: the calls end with the publish request (no queue_rows query, no compat request). The run has CI empty, so the first-run gate reads the terminal (`tty`, a fake that is no terminal) and asks nothing.",
   ["publish env:CI="], "== publish env:CI=\n" + OKLINE + "exit 0\n",
   calls=["args", "env_all", "tty", "env_all", "read_files " + CFG] + gh() + facts_of() + tokget() + post(BODY4),
   files={"given/home/.config/talon/config.toml": "share = true\n", "given/home/.cache/roc/talon/share_queue.tsv": QUEUE, "given/home/.local/share/talon/share.json": SJ},
   routes=[post_route(1, 201, REL_ANSWER)])

# pu15: more than 500 facts.
import datetime
def night(i):
    d = datetime.date(2025, 1, 1) + datetime.timedelta(days=i)
    return "nightly-%s-%07x" % (d.isoformat(), 0x1000 + i)
tags = [night(i) for i in range(501)]
store = "format\t1\n" + "".join(fact(H, t, "any", "pass") for t in reversed(tags))
body500 = '{"compat":[' + ",".join('{"error_digest":null,"nightly":"%s","result":"pass","target":"any"}' % t for t in tags[1:]) + '],"url":"%s"}' % URL
mk("pu15-over-500", "R-PUB4 R-AP71 R-AP46 R-PU5 (slice 221, Design Q510): 501 facts of the hash: the 500 of the newest nightlies go (the oldest is dropped), sorted oldest first, one warning, exit 0.",
   ["publish"], "== publish\npublished acme/json 2.1.0: %s, 500 facts sent\nexit 0\n" % H,
   stderr="warning: sent 500 of 501 facts for %s: the registry takes at most 500 for a publish\n" % H,
   calls=full(body500), store=store,
   routes=[post_route(1, 201, REL_ANSWER)])
PY
