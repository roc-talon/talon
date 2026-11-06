#!/usr/bin/env bash
# Slice 221 and 222: makes the L2 cases tests/commands/cases/publish/pu1 to pu24 (`tln publish`; CLI R-CM13, R-PUB1 to R-PUB3; Registry R-AP8, R-AP27, R-AP34, R-TP2; CLI 3 R-E6). The expected files are written from the design readings of docs/slices/221-publish.md, not from a run of tln.
# Slice 222 (R-PU39): after the facts and before the token request each run that gets so far reads the releases of the group (idx()) and, with no earlier release, writes NOTE to stderr. A case that has `index=False` stops before (usage stops, no release, newer compat.db).
# Usage: tests/tools/mk-publish.sh        (writes the 24 case dirs)
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
exec python3 -I - "$ROOT/tests/commands/cases/publish" <<'PY'
import os, sys, shutil
base = sys.argv[1]
BAKED = ["pu17-no-compiler", "pu18-pin-installed", "pu19-bump-less", "pu20-bump-pass", "pu21-bump-failed", "pu22-bump-unreadable", "pu23-bump-timeout", "pu25-pin-download", "pu28-pin-download-default-set", "pu29-range-download"]
# The expect/ dir of a baked case stays (it came from a reference run and was read, slice 222). All else is made again.
for name in (os.listdir(base) if os.path.isdir(base) else []):
    d = os.path.join(base, name)
    if name in BAKED:
        for sub in os.listdir(d):
            if sub != "expect":
                shutil.rmtree(os.path.join(d, sub), ignore_errors=True) if os.path.isdir(os.path.join(d, sub)) else os.remove(os.path.join(d, sub))
    else:
        shutil.rmtree(d, ignore_errors=True)
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

GROUP_Q = "github.com%252Facme%252Fjson%252Freleases%252Fdownload%252F%257Bv%257D%252F"
GROUP_URL = REG + "/v1/releases?group=github.com%2Facme%2Fjson%2Freleases%2Fdownload%2F%7Bv%7D%2F"
EMPTY_GROUP = '{"releases":[],"checked":null,"repos":[]}'
NOTE = "note: no earlier release of github.com/acme/json/releases/download/{v}/ before 2.1.0: roc bump did not run\n"
def idx(): return ["http_get " + GROUP_URL, "  User-Agent: tln/0.0.1", "  Cache-Control: no-cache"]

def meta(status, extra=(), body=True):
    return lines("status %d" % status, *(["header Content-Type: application/json"] if body else []), "header Cache-Control: no-store", *extra)

def mk(case, rules, runs, stdout, stderr="", exit_="0\n", calls=(), store=STORE, env=ENV, routes=None, release=True, token=True, files=None, index=True, group_body=None, group_status=200, baked=False):
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
    if index:
        r = d + "/fx/http/127.0.0.1%3A9/v1/releases%3Fgroup=" + GROUP_Q
        write(r, group_body or EMPTY_GROUP)
        write(r + ".meta", meta(group_status, ["require user-agent: tln/0.0.1", "require cache-control: no-cache", "require-none authorization"]))
    for (path, text, m) in (routes or []):
        r = d + "/fx/http/" + path
        write(r, text)
        write(r + ".meta", m)
    for (rel, text) in (files or {}).items():
        write(d + "/" + rel, text)
    if baked:
        return
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
def full(body, jwt="jwt1"): return PRE + gh() + facts_of() + idx() + tokget() + post(body, jwt)
OKLINE = "published acme/json 2.1.0: %s, 4 facts sent\n" % H

# pu1: 201, then 200 for the same label, then --json.
data = '{"schema":1,"command":"publish","ok":true,"data":{"publish":{"repository":"acme/json","tag":"2.1.0","hash":"%s","created":true,"facts":4}},"error":null}\n' % H
mk("pu1-publish-ok", "R-CM13 R-PB5 R-PU2 R-PU5 R-TP2 R-TP17 R-AP8 R-AP26 R-AP71 R-OUT2 R-OUT4 R-J1 (slice 221): `tln publish` in a job for the tag 2.1.0 of acme/json, registry http://127.0.0.1:9 (TALON_REGISTRY). Calls in order: the release of the tag (GITHUB_TOKEN as Authorization), the facts of the hash, the OIDC token (audience = the base URL, header `Authorization: bearer`), the POST with `Authorization: Bearer <JWT>` and the body {compat, url}. The 4 unit checks of the hash go (pass, hang, fail, crash: sorted by nightly, error_digest null); the build row, the x64musl row and the facts of another hash do not. Run 1: 201 (new). Run 2: 200 (the same label). Run 3: --json.",
   ["publish", "publish", "publish --json"],
   "== publish\n" + OKLINE + "exit 0\n== publish\nacme/json 2.1.0 is published already: %s, 4 facts sent\nexit 0\n== publish --json\n" % H + data + "exit 0\n",
   stderr=NOTE * 3,
   calls=full(BODY4) + full(BODY4) + full(BODY4),
   routes=[post_route(1, 201, REL_ANSWER, extra=["header Location: /v1/artifacts/" + H]), post_route(2, 200, REL_ANSWER)])

# pu2: no fact of the hash.
mk("pu2-no-facts", "R-PUB3 R-PB5 R-PU5 R-AP71 (slice 221): compat.db has only a fact of another hash. The body has no `compat` member, the warning of R-PUB3 is on stderr (before the token request), the exit code is 0.",
   ["publish"], "== publish\npublished acme/json 2.1.0: %s, no facts sent\nexit 0\n" % H,
   stderr="warning: no probe facts for %s: run tln probe --range <bundle file> before tln publish\n" % H + NOTE,
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
   exit_="0\n", calls=PRE * len(runs3), release=False, token=False, index=False)

# pu4: no release for the tag.
mk("pu4-no-release", "R-PUB2 R-EC2 R-AP27 (slice 221): the API answers 404 for the tag: exit 2, the message names the case. The calls end after the release request: no facts query, no token request, no registry request.",
   ["publish"], "== publish\nexit 2\n",
   stderr="tln: error[usage]: acme/json has no release for the tag 2.1.0. Create the release and upload the package first, then run tln publish.\n",
   calls=PRE + gh(), release=False, token=False, index=False)

# pu5: a newer compat.db.
mk("pu5-compat-too-new", "R-TF3 R-PB5 (slice 221): compat.db has format 2 (this tln writes 1): exit 19 (input) before the token request and any registry request.",
   ["publish"], "== publish\nexit 19\n",
   stderr="tln: error[input]: %s has format 2. This tln writes format 1. Run: tln tool update talon\n" % DB.replace("$HOME", "$HOME"),
   calls=PRE + gh() + facts_of(), store="format\t2\n" + fact(H, N1, "any", "pass"),
   routes=[post_route(1, 201, REL_ANSWER)], token=True, index=False)

# pu6: the schedule of R-AP34, 4 sends, the token is fetched once.
busy = '{"type":"/errors/busy","title":"T","status":503,"detail":"D"}'
rl = '{"type":"/errors/rate-limited","title":"T","status":429,"detail":"D"}'
mk("pu6-retries", "R-AP34 R-AP82 R-DA9 R-TP2 (slice 221): the request is sent again after 429, 503 and no answer: the waits are the Retry-After of the first answer (7 s), then 8 s and 30 s (the schedule, no header). The 4th request gets 201. The OIDC token is fetched once (a new one is for a 401 only). `sleep` is a call of the fake Fx.",
   ["publish"], "== publish\n" + OKLINE + "exit 0\n",
   stderr=NOTE,
   calls=PRE + gh() + facts_of() + idx() + tokget() + post(BODY4) + ["sleep 7000"] + post(BODY4)[0:0] + post(BODY4) + ["sleep 8000"] + post(BODY4) + ["sleep 30000"] + post(BODY4),
   routes=[post_route(1, 429, rl, extra=["header Retry-After: 7"]), post_route(2, 503, busy),
           ("127.0.0.1%3A9/v1/releases.POST.3", "", lines("error timeout", *(["require authorization: Bearer jwt1"] + POSTH))),
           post_route(4, 201, REL_ANSWER)])

# pu7: 4 times 502.
up = '{"type":"/errors/upstream","title":"T","status":502,"detail":"D"}'
mk("pu7-retries-exhausted", "R-AP34 R-AP22 R-E6 R-J7 (slice 221): 502 for each of the 4 requests (the first and 3 more), with waits of 2 s, 8 s and 30 s. Exit 15 (network), the text of the CLI 3 example: `the registry answered 502 (/errors/upstream) 4 times. Try again later.`",
   ["publish"], "== publish\nexit 15\n",
   stderr=NOTE + "tln: error[network]: the registry answered 502 (/errors/upstream) 4 times. Try again later.\n",
   calls=PRE + gh() + facts_of() + idx() + tokget() + post(BODY4) + ["sleep 2000"] + post(BODY4) + ["sleep 8000"] + post(BODY4) + ["sleep 30000"] + post(BODY4),
   routes=[post_route(1, 502, up)])

# pu8: a 401 gets a new token.
unauth = '{"type":"/errors/unauthenticated","title":"T","status":401,"detail":"D"}'
mk("pu8-renew-401", "R-AP34 R-TP2 R-AP8 (slice 221): the first request gets 401: a new OIDC token (the token request again, the fake gives jwt2 to the second) and the same request once more, with no wait. The second gets 201.",
   ["publish"], "== publish\n" + OKLINE + "exit 0\n",
   stderr=NOTE,
   calls=PRE + gh() + facts_of() + idx() + tokget() + post(BODY4) + tokget() + post(BODY4, "jwt2"),
   routes=[post_route(1, 401, unauth), post_route(2, 201, REL_ANSWER, auth="jwt2"),
           ("127.0.0.1%3A8/token.2", '{"count":1,"value":"jwt2"}', meta(200, ["require authorization: bearer req1"]))])

# pu9: refused writes.
conflict = '{"type":"/errors/label-conflict","title":"T","status":409,"detail":"the registry has roc-lang/json 2.1.0 with another hash"}'
forb = '{"type":"/errors/forbidden","title":"T","status":403,"detail":"token claim ref is refs/heads/main, the asset URL has the tag 2.1.0"}'
mk("pu9-refused", "R-E6 R-AP22 R-AP34 R-J7 (slice 221): a refused write is exit 20 (rejected), one request each, no wait, no new token (only a 401 gets one). The texts are the first 2 lines of the CLI 3 R-E6 example: 409 label-conflict, then 403 forbidden.",
   ["publish", "publish"], "== publish\nexit 20\n== publish\nexit 20\n",
   stderr=NOTE + "tln: error[rejected]: the registry has roc-lang/json 2.1.0 with another hash (/errors/label-conflict). The tag was released again. Release a new version.\n"
          + NOTE + "tln: error[rejected]: token claim ref is refs/heads/main, the asset URL has the tag 2.1.0 (/errors/forbidden). Run tln publish in a job for the tag.\n",
   calls=full(BODY4) + full(BODY4),
   routes=[post_route(1, 409, conflict), post_route(2, 403, forb)])

# pu10: flags that are read or accepted.
mk("pu10-flags", "R-PUB4 R-FL5 R-RG1 R-PD14 (slice 221, Design Q508, Q520): `--file` is accepted and has no other effect; `--registry <url>` is read (the registry is the target of the request) with no TALON_REGISTRY. Both runs publish (201).",
   ["publish --file p/main.roc", "publish --registry http://127.0.0.1:9 env:TALON_REGISTRY="],
   "== publish --file p/main.roc\n" + OKLINE + "exit 0\n== publish --registry http://127.0.0.1:9 env:TALON_REGISTRY=\n" + OKLINE + "exit 0\n",
   stderr=NOTE * 2,
   calls=full(BODY4) + full(BODY4),
   routes=[post_route(1, 201, REL_ANSWER)])

# pu11: the token request is refused.
mk("pu11-token-refused", "R-TP2 R-AP27 R-EC2 R-PUB4 (slice 221, Design Q515): GitHub answers 403 to the token request (the job has no id-token: write): exit 2, the message names the permission. No registry request. The token never is in a message.",
   ["publish"], "== publish\nexit 2\n",
   stderr=NOTE + "tln: error[usage]: the GitHub OIDC token request was refused (403). The job needs permissions: id-token: write.\n",
   calls=PRE + gh() + facts_of() + idx() + tokget(), token=False,
   routes=[("127.0.0.1%3A8/token", '{"message":"Forbidden"}', meta(403, ["require authorization: bearer req1"]))])

# pu12: 401 twice.
mk("pu12-renew-twice", "R-AP34 R-E6 R-PUB4 (slice 221, Design Q516): 401, a new token, 401 again: exit 20 (rejected), the detail and the words `the registry refused the new token too`. 2 token requests, 2 requests, no wait, no third request.",
   ["publish"], "== publish\nexit 20\n",
   stderr=NOTE + "tln: error[rejected]: D (/errors/unauthenticated): the registry refused the new token too.\n",
   calls=PRE + gh() + facts_of() + idx() + tokget() + post(BODY4) + tokget() + post(BODY4, "jwt2"),
   routes=[post_route(1, 401, unauth), post_route(2, 401, unauth, auth="jwt2"),
           ("127.0.0.1%3A8/token.2", '{"count":1,"value":"jwt2"}', meta(200, ["require authorization: bearer req1"]))])

# pu13: compat.db busy.
mk("pu13-db-busy", "R-PUB4 R-PUB3 R-CC8 (slice 221, Design Q517): the read of compat.db is busy: one warning, then the publish with no `compat` member (and no `no probe facts` warning). Exit 0.",
   ["publish"], "== publish\n" + "published acme/json 2.1.0: %s, no facts sent\nexit 0\n" % H,
   stderr="warning: compat.db could not be read (busy): publishing with no probe facts\n" + NOTE,
   calls=full(BODY0), files={"fx/db": "1: busy\n"},
   routes=[post_route(1, 201, REL_ANSWER)])

# pu14: no queue send.
QUEUE = "1\t%s\t%s\tany\tpass\t0.0.1\t2026-10-01T00:00:00Z\n" % (H2, N1)
SJ = '{"format":1,"id":"0123456789abcdeffedcba9876543210","sent":0,"counted":0,"first":0,"first_sent_at":null,"last_sent_at":null,"token":null,"token_expires_at":null,"account":null}\n'
mk("pu14-no-queue-send", "R-SH4 R-PUB4 R-SH2 (slice 221, Design Q518): sharing is on (share = true, a registry, no CI, no DO_NOT_TRACK) and the queue has a row, but `tln publish` does not send the queue: the calls end with the publish request (no queue_rows query, no compat request). The run has CI empty, so the first-run gate reads the terminal (`tty`, a fake that is no terminal) and asks nothing.",
   ["publish env:CI="], "== publish env:CI=\n" + OKLINE + "exit 0\n",
   stderr=NOTE,
   calls=["args", "env_all", "tty", "env_all", "read_files " + CFG] + gh() + facts_of() + idx() + tokget() + post(BODY4),
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
   stderr="warning: sent 500 of 501 facts for %s: the registry takes at most 500 for a publish\n" % H + NOTE,
   calls=full(body500), store=store,
   routes=[post_route(1, 201, REL_ANSWER)])

# pu16: the answer of the group has no release that can be the previous one: the same version with another hash, a larger version, a yanked smaller one (R-PU39, R-AP13).
def grel(version, h, series, yanked):
    u = "https://github.com/acme/json/releases/download/%s/%s.tar.zst" % (version, h)
    return ('{"log_index":%d,"hash":"%s","group":"github.com/acme/json/releases/download/{v}/","series":"%s","version":"%s","url":"%s","tag":"%s","roc_version":null,"repo":"acme/json","published_at":1792065600000,'
            '"yanked":%s,"yank_reason":%s,"withdrawn":null,"provenance":["oidc"]}' % (7, h, series, version, u, version, "true" if yanked else "false", '"bad"' if yanked else "null"))
GROUP3 = '{"releases":[%s],"checked":null,"repos":[]}' % ",".join([grel("3.0.0", "3" * 43 + "a", "3", False), grel("2.1.0", H2, "2", False), grel("2.0.0", "2" * 43 + "b", "2", True)])
mk("pu16-no-previous", "R-PU39 R-AP13 (slice 222): the answer of the group (all series) has 3 releases and none can be the previous release of 2.1.0: 3.0.0 is larger, 2.1.0 is the same version (another hash), 2.0.0 is smaller but yanked. So the check gives the note of a first release, runs no roc, and the publish goes on. The exit code is 0.",
   ["publish"], "== publish\n" + OKLINE + "exit 0\n",
   stderr=NOTE, calls=full(BODY4), group_body=GROUP3,
   routes=[post_route(1, 201, REL_ANSWER)])

# pu24: the read of the group fails (R-PU39, Design Q527, R-PUB4 item 13): run 1 gets 503, run 2 gets 200 with a body that does not decode. Each gives the note (the cause words are a proposal), no roc, the publish goes on, exit 0.
FORM = "github.com/acme/json/releases/download/{v}/"
mk("pu24-group-read-fails", "R-PU39 R-AP13 R-PUB4 (slice 222, Design Q527): the group read gets a 503 (run 1) and a body that does not decode (run 2). No retry (one group request in each run). The note names the group and the cause, no compiler is started, the publish goes on. The exit code is 0.",
   ["publish", "publish"], "== publish\n" + OKLINE + "exit 0\n== publish\nacme/json 2.1.0 is published already: %s, 4 facts sent\nexit 0\n" % H,
   stderr="note: the releases of %s could not be read (HTTP 503): roc bump did not run\n" % FORM + "note: the releases of %s could not be read (the answer does not decode): roc bump did not run\n" % FORM,
   calls=full(BODY4) + full(BODY4), group_body=busy, group_status=503,
   routes=[("127.0.0.1%3A9/v1/releases%3Fgroup=" + GROUP_Q + ".2", "not json", meta(200, ["require user-agent: tln/0.0.1", "require cache-control: no-cache", "require-none authorization"])),
           post_route(1, 201, REL_ANSWER), post_route(2, 200, REL_ANSWER)])

# pu17 to pu23 (slice 222, R-PU39, Design Q523 to Q526, R-PUB4 item 13): the group has a previous release 2.0.0, and the job has a package `p/main.roc`. Their expect/ files come from a run of a private reference (research/slice-222-revert/ref, deleted), read line by line against the design. This generator never writes or deletes them.
PREV_HASH = "2" * 43 + "b"
PREV_URL = "https://github.com/acme/json/releases/download/2.0.0/%s.tar.zst" % PREV_HASH
GROUP_PREV = '{"releases":[%s],"checked":null,"repos":[]}' % grel("2.0.0", PREV_HASH, "2", False)
ENV_B = ENV + "TALON_NOW=2026-10-22T12:00:00Z\n"
PIN = "nightly-2026-10-14-38a3029"
NEWER = "nightly-2026-10-20-5349569"
def pkg(pin): return "package [Lib] {\n\troc: \"%s\",\n}\n" % pin if pin else "package [Lib] {}\n"
def tc(*ids): return {"given/home/.cache/roc/toolchains/%s/roc" % i: "fake\n" for i in ids}
MAJOR_OUT = lines("Comparing %s (old, 2.0.0) with p/main.roc (new)..." % PREV_URL, "", "---- Greet - MAJOR ----", "", "    - Greet.hello : Str -> Str", "    + Greet.hello : Str, Str -> Str", "", "This is a MAJOR change.", "", "2.0.0 -> 3.0.0")
HEAD = lambda n: "── ✗ %s ─────────────────────────────────────────────────────────────────" % n
LESS_ERR = lines(HEAD("insufficient version bump"), "", "roc bump failed.", "", "This is a MAJOR change, so the next version must be at least 3.0.0, but --expect was 2.1.0.", "", "")
PASS_OUT = lines("Comparing %s (old, 2.0.0) with p/main.roc (new)..." % PREV_URL, "", "This is a MINOR change.", "", "2.0.0 -> 2.1.0", "", "2.1.0 satisfies the required MINOR bump.")
BAD_ERR = lines(HEAD("name not in scope"), "", "Nothing is named nope in this scope.", "", "hello = |name| nope(name)", "               ^^^^", "", HEAD("package does not compile"), "", "roc bump failed.", "", "The new package (p/main.roc) does not compile with this compiler. roc bump needs both packages to compile so their public APIs can be compared.", "", "")
def bump(case, rules, pin, installed, row, extra=None, run="publish --file p/main.roc"):
    f = {"given/project/p/main.roc": pkg(pin), "fx/probes": row[0], "fx/gitdirs": ".\n"}
    f.update(tc(*installed))
    f.update(extra or {})
    mk(case, rules, [run], "== " + run + "\n" + OKLINE + "exit 0\n", env=ENV_B, group_body=GROUP_PREV, files=f,
       routes=[post_route(1, 201, REL_ANSWER)], baked=True)
bump("pu17-no-compiler", "R-PU39 R-PUB4 (slice 222, Design Q523): the previous release exists, the package header pins %s, and that compiler is not installed (none is). No flag: the note `no API check: the compiler <pin> is not installed (pass --probe-downloads to install it)`, no download, no probe, the publish goes on, exit 0." % PIN, PIN, [], ("", ))
bump("pu18-pin-installed", "R-PU39 R-PUB4 (slice 222, Design Q523, Q524): the pin %s is installed, and a newer compiler too (the selected one). The probe of `roc bump` uses the pin: the program is the roc of the pin, in the dir of the package, the 6 words `bump --old <URL> --expect 2.1.0 <file>`. Exit 0 passes: no line." % PIN, PIN, [PIN, NEWER], ("0\tbump-pass.stdout\t-\n",), {"fx/bump-pass.stdout": PASS_OUT})
bump("pu19-bump-less", "R-PU39 R-PUB4 (slice 222, Design Q525): roc bump exits 1 with the headline `insufficient version bump`, `must be at least`, and the stdout lines (a MAJOR change, 2.0.0 -> 3.0.0): the warning, and the publish goes on (exit 0, the request is sent).", PIN, [PIN], ("1\tbump-less.stdout\tbump-less.stderr\n",), {"fx/bump-less.stdout": MAJOR_OUT, "fx/bump-less.stderr": LESS_ERR})
bump("pu20-bump-pass", "R-PU39 R-PUB4 (slice 222, Design Q523, Q525): no pin in the header: the selected compiler runs (the newest installed one: %s). Exit 0: no line." % NEWER, None, [PIN, NEWER], ("0\tbump-pass.stdout\t-\n",), {"fx/bump-pass.stdout": PASS_OUT})
bump("pu21-bump-failed", "R-PU39 R-PUB4 (slice 222, Design Q525): roc bump exits 1 because the new package does not compile (the last headline is `package does not compile`): the note with the cause, the publish goes on, exit 0.", PIN, [PIN], ("1\t-\tbump-bad.stderr\n",), {"fx/bump-bad.stderr": BAD_ERR})
bump("pu22-bump-unreadable", "R-PU39 R-PUB4 (slice 222, Design Q525: no guess): exit 1 with the headline `insufficient version bump` and `must be at least`, but the stdout has no `This is a <LEVEL> change.` and no `<old> -> <next>` line: the note (the cause is the headline), not the warning. The publish goes on, exit 0.", PIN, [PIN], ("1\t-\tbump-less.stderr\n",), {"fx/bump-less.stderr": LESS_ERR})
bump("pu23-bump-timeout", "R-PU39 R-PUB4 (slice 222, Design Q526): the probe of roc bump is cut at the limit (`probe.timeout`, 30 s): the note, the publish goes on, exit 0.", PIN, [PIN], ("timeout\t-\t-\n",))

# pu25: the pin is not installed and `--probe-downloads` is set: the compiler is downloaded (the fake jobs and the compiler list of the case probe/pd1-downloads), then the bump runs on it (Design Q523, R-PUB4 item 13). The fake files are copied from pd1. Its expect/ files come from a run of the code, read line by line.
PD1 = os.path.join(os.path.dirname(base), "probe", "pd1-downloads", "fx")
def pd1(name):
    with open(os.path.join(PD1, name)) as fh:
        return fh.read()
PIN9 = "nightly-2026-10-09-9d9d9d9"
LIST9 = "http/api.github.com/repos/roc-lang/nightlies/releases%3Fper_page=100"
bump("pu25-pin-download", "R-PU39 R-PUB4 R-NI4 R-FL12 (slice 222, Design Q523): the previous release exists, the package header pins %s, and it is not installed. With `--probe-downloads` the compiler is downloaded (the list of compilers, curl, tar, chmod: the fake jobs of probe/pd1-downloads) and the bump runs on it. Exit 0: no line." % PIN9, PIN9, [], ("0\tbump-pass.stdout\t-\n",),
     {"fx/bump-pass.stdout": PASS_OUT, "fx/jobs": pd1("jobs"), "fx/programs": pd1("programs"), "fx/" + LIST9: pd1(LIST9)},
     run="publish --file p/main.roc --probe-downloads")

# pu26, pu27 (Design Q542, R-PUB4 item 13): one note shape for each compiler source. The expect/ files are written by hand against the design text, not from a run of the code. The `calls.log` has no request for the list of compilers (the note says to pass the flag, so a run with no flag asks for nothing: a reading). The 2 listings of the toolchains, and the reads of `talon.toml` and of `.talon.json` for a range, are read from the code (not in the design).
def nocheck(case, rules, reason, files, toml=False, lists=2, after=()):
    f = {"given/project/p/main.roc": pkg(None), "fx/probes": "", "fx/gitdirs": ".\n"}
    f.update(files)
    mk(case, rules, ["publish --file p/main.roc"], "== publish --file p/main.roc\n" + OKLINE + "exit 0\n", env=ENV_B, group_body=GROUP_PREV, files=f,
       stderr="note: no API check: %s\n" % reason,
       calls=full(BODY4)[:len(PRE + gh() + facts_of() + idx())] + ["env_all", "clock", "cwd", "canonical $PROJECT/p/main.roc", "list_dirs $PROJECT/p", "list_dirs $PROJECT"] + (["read_files $PROJECT/p/talon.toml"] if toml else []) + ["read_files $PROJECT/p/main.roc", "path_roc",
             "read_files $PROJECT/p/main.roc $PROJECT/p/talon.toml " + CFG, ] + ["list_dirs $HOME/.cache/roc/toolchains"] * lists + list(after) + tokget() + post(BODY4),
       routes=[post_route(1, 201, REL_ANSWER)])
nocheck("pu26-default-roc-missing", "R-PU39 R-PUB4 R-SO6 (slice 222, Design Q542): the package has no pin, `config.toml` has `default-roc = N1` and N1 is not installed (nothing is). The note has the words of a pin that is not installed (the same words for a pin, ROC_TOOLCHAIN, default-roc and .roc-version), no `Consent.download_refused` text, no download, no probe. The publish goes on, exit 0.",
        "the compiler %s is not installed (pass --probe-downloads to install it)" % PIN, {"given/home/.config/talon/config.toml": "default-roc = \"%s\"\n" % PIN})
RANGE = ">=nightly-2026-10-25-0000000"
nocheck("pu27-range-none", "R-PU39 R-PUB4 R-SO6 (slice 222, Design Q542): the package has no pin, `talon.toml` has `[toolchain] roc = \"%s\"`, and the only installed compiler (%s) is out of the range. The note names the range as it is written. No download, no probe, exit 0." % (RANGE, PIN),
        "no installed compiler is in the range %s (pass --probe-downloads to install it)" % RANGE,
        dict({"given/project/p/talon.toml": "[toolchain]\nroc = \"%s\"\n" % RANGE}, **tc(PIN)), toml=True, lists=1, after=["read_files $HOME/.cache/roc/toolchains/%s/.talon.json" % PIN])

# pu28 (Design Q544 a, R-SO24): as pu25, but `config.toml` already has `default-roc`. The pin is downloaded and the check runs; `config.toml` is not changed (no `lock` and no `write_atomic` of it, no line in tree.diff). Its expect/ files came from a run of the code, read line by line.
bump("pu28-pin-download-default-set", "R-PU39 R-PUB4 R-SO24 R-SO15 (slice 222, Design Q544): the pin %s is not installed, `--probe-downloads` is set, and `config.toml` has `default-roc` (another compiler). The download runs, the bump runs on the pin, and `config.toml` is not changed (R-SO24: a set default is never changed). Exit 0." % PIN9, PIN9, [], ("0\tbump-pass.stdout\t-\n",),
     {"fx/bump-pass.stdout": PASS_OUT, "fx/jobs": pd1("jobs"), "fx/programs": pd1("programs"), "fx/" + LIST9: pd1(LIST9), "given/home/.config/talon/config.toml": "default-roc = \"%s\"\n" % PIN},
     run="publish --file p/main.roc --probe-downloads")

# pu29 (Design Q544 b, Q542, R-SO13): a range with no installed compiler, with `--probe-downloads`: the compiler list is read once and the newest compiler in the range is downloaded, then the check runs. The expect/ files are written by hand from pu25 (the id is the newest of the list inside the range), not from a run of the code: the order of the list read and of the listings is a reading.
bump("pu29-range-download", "R-PU39 R-PUB4 R-SO13 R-CV1 (slice 222, Design Q544): the package has no pin, `talon.toml` has `[toolchain] roc = \">=nightly-2026-10-09-0000000\"`, nothing is installed, and `--probe-downloads` is set. One read of the compiler list, the download of the newest compiler in the range (nightly-2026-10-10-0e0e0e0), then the bump on it. Exit 0.", None, [], ("0\tbump-pass.stdout\t-\n",),
     {"fx/bump-pass.stdout": PASS_OUT, "fx/jobs": pd1("jobs"), "fx/programs": pd1("programs"), "fx/" + LIST9: pd1(LIST9), "given/project/p/talon.toml": "[toolchain]\nroc = \">=nightly-2026-10-09-0000000\"\n"},
     run="publish --file p/main.roc --probe-downloads")
PY
