#!/usr/bin/env bash
# Slice 217: makes the L2 cases tests/commands/cases/probe/ps1 to ps12 (`tln probe --share`, R-PB6). The expected files are written from the design readings of the slice file (docs/slices/217-probe-share.md), not from a run of tln.
# Usage: tests/tools/mk-probe-share.sh        (writes the case dirs; run it again after a change of the rows)
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
exec python3 -I - "$ROOT/tests/commands/cases/probe" <<'PY'
import os, sys, subprocess, shutil, tempfile
base = sys.argv[1]
ID = "0123456789abcdeffedcba9876543210"
ID2 = "0123456789abcdef0123456789abcdef"
NOW = "2026-10-15T12:00:00Z"  # the fake clock 1792065600
V = "0.0.1"                   # Help.version: the User-Agent and talon_version
DB = "$HOME/.cache/roc/talon/compat.db"
SJ = "$HOME/.local/share/talon/share.json"
TMP = SJ + ".0123456789abcdef.tmp"
J = "home/.local/share/talon/share.json"
N_OLD = "nightly-2026-10-12-2664a27"
N_NEW = "nightly-2026-10-14-38a3029"
N_X = "nightly-2026-10-10-aaaaaaa"   # not recorded
N_H = "nightly-2026-10-13-bbbbbbb"   # a hang

def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)

def doc(sent=0, counted=0, first=0, at=None, id=ID):
    t = "null" if at is None else '"%s"' % at
    return '{"format":1,"id":"%s","sent":%d,"counted":%d,"first":%d,"first_sent_at":%s,"last_sent_at":%s,"token":null,"token_expires_at":null,"account":null}\n' % (id, sent, counted, first, t, t)

def tdiff(label, before, after):
    d = tempfile.mkdtemp()
    a, b = os.path.join(d, "a"), os.path.join(d, "b")
    write(a, before); write(b, after)
    r = subprocess.run(["diff", "-u", "--label", label, "--label", label, a, b], capture_output=True, text=True)
    shutil.rmtree(d)
    return r.stdout

def pins(tags):
    return "".join("pinned\t%s\tlinux_x86_64\t%s\tgithub-digest\n" % (t, "a" * 64) for t in tags)

def compat(facts, tags=None):
    return "format\t1\n" + facts + pins([N_OLD, N_NEW, N_H] if tags is None else tags) + "pinned\t%s\twindows_x86_64\t%s\tgithub-digest\n" % (N_X, "b" * 64)

def closure_route(case, art_hash="HQ", kind="package", n=1):
    d = os.path.join(base, case, "fx/http/127.0.0.1%3A9/v1")
    suffix = "" if n == 1 else ".%d" % n
    art = '{"hash":"%s","kind":"%s","exposed":[],"platform_hash":null,"roc_pin":null,"size":10,"deps":[],"target_names":[]}' % (art_hash, kind)
    write(os.path.join(d, "closure.POST" + suffix), '{"artifacts":[%s],"releases":[],"epochs":[],"runs":[],"nearest":[],"hints":[],"log_size":40,"unknown":[],"checked":[],"repos":[]}' % art)
    write(os.path.join(d, "closure.POST%s.meta" % suffix), "status 200\nheader Content-Type: application/json\nheader Cache-Control: no-store\nrequire content-type: application/json\nrequire-none authorization\n")

def closure_log(h, frm=None, to=None):
    comp = '"compilers":{"from":"%s","to":"%s"},' % (frm, to) if frm else ""
    return ["http_send POST http://127.0.0.1:9/v1/closure timeout=20", "  User-Agent: tln/%s" % V, "  Content-Type: application/json",
            '  <body> {%s"groups":[],"hashes":["%s"]}' % (comp, h)]

def platform_pinned(k): return ["platform", "db_query %s busy_ms=5000 format=1 pinned=%d" % (DB, k)]

def fact(h, n, t, o, closure="", modules=""):
    return "fact\t%s\t%s\t%s\t%s\t%s\t%s\n" % (h, n, t, o, modules, closure)

def body(rows):
    items = ",".join('{"hash":"%s","nightly":"%s","result":"%s","target":"%s"}' % r for r in rows)
    return '{"rows":[%s],"talon_version":"%s"}' % (items, V)

def send_log(rows, cid=ID):
    return ["http_send POST http://127.0.0.1:9/v1/compat timeout=20",
            "  User-Agent: tln/%s" % V, "  Content-Type: application/json", "  Talon-Contributor: %s" % cid,
            "  <body> " + body(rows)]

TOTALS = ["clock", "lock %s nowait: held" % SJ, "read_files %s" % SJ, "random", "write_atomic %s" % TMP, "spawn_all limit=1", "  job - chmod 0600 %s" % TMP,
          "rename %s %s" % (TMP, SJ), "unlock %s" % SJ]
MAKE = ["lock %s nowait: held" % SJ, "read_files %s" % SJ, "random", "random", "random", "write_atomic %s" % TMP, "spawn_all limit=1", "  job - chmod 0600 %s" % TMP, "rename %s %s" % (TMP, SJ), "unlock %s" % SJ]
ENV = ["env_all"]
def QUERY(h): return ["db_query %s busy_ms=5000 format=1 facts_of=%s" % (DB, h)]
ID_READ = ["read_files %s" % SJ]

def route(case, n, status, body_text, extra=(), cid=ID):
    d = os.path.join(base, case, "fx/http/127.0.0.1%3A9/v1")
    suffix = "" if n == 1 else ".%d" % n
    write(os.path.join(d, "compat.POST" + suffix), body_text)
    meta = ["status %d" % status] if status else []
    meta += ["header Content-Type: application/json", "header Cache-Control: no-store"] + list(extra)
    meta += ["require content-type: application/json", "require talon-contributor: " + cid, "require-none authorization", "require user-agent: tln/" + V]
    write(os.path.join(d, "compat.POST%s.meta" % suffix), "\n".join(meta) + "\n")

def gh(case, name, status, text):
    d = os.path.join(base, case, "fx/http/api.github.com/repos/acme")
    write(os.path.join(d, name), text)
    write(os.path.join(d, name + ".meta"), "status %d\nheader Content-Type: application/json\n" % status)

def case(name, rules, comment, runs, facts, log, stdout, stderr, doc_given, doc_final, extra_tree="", jobs="chmod\t0\t-\t-\t-\n"):
    c = os.path.join(base, name)
    if os.path.isdir(c):
        shutil.rmtree(c)
    write(c + "/entry", "probe-share\n")
    write(c + "/rules", rules + " (slice 217): " + comment + "\n")
    write(c + "/fx/runs", "\n".join(runs) + "\n")
    write(c + "/fx/jobs", jobs)
    write(c + "/given/home/.cache/roc/talon/compat.tsv", compat(facts))
    if doc_given != "":
        write(c + "/given/home/.local/share/talon/share.json", doc_given)
    write(c + "/expect/exit", "0\n")
    write(c + "/expect/stdout", stdout)
    write(c + "/expect/calls.log", "\n".join(log) + "\n")
    if stderr:
        write(c + "/expect/stderr", stderr)
    td = extra_tree
    if doc_final is not None:
        td += tdiff(J, doc_given, doc_final)
    write(c + "/expect/tree.diff", td)
    return c

REF = "HQ"
CFG = "read_files $HOME/.config/talon/config.toml"
ROW1 = [(REF, N_OLD, "pass", "any")]
Q1 = ENV + QUERY(REF) + platform_pinned(1) + closure_log(REF, N_OLD, N_OLD)
DONE0 = "  shared 0 facts of HQ: 0 counted, 0 skipped by the registry\n"
NOTSENT = "    not shared: %s any: not sent\n" % N_OLD

# ps2: the facts of one hash go out, also with sharing off (no config), CI=true and DO_NOT_TRACK=1. Old facts (no probe of this command) go. Kept back: a hang, a nightly pinned for another target only, a build.
facts = (fact(REF, N_OLD, "any", "pass") + fact(REF, N_NEW, "any", "fail", modules="Foo.roc") + fact(REF, N_X, "any", "pass") + fact(REF, N_H, "any", "hang")
         + fact(REF, N_NEW, "linux_x86_64", "pass", closure="abc") + fact("HOTHER", N_OLD, "any", "pass"))
ROWS2 = [(REF, N_OLD, "pass", "any"), (REF, N_NEW, "fail", "any")]
line = "%s env:CI=true env:DO_NOT_TRACK=1" % REF
stdout = ("== %s\n  shared 2 facts of HQ: 2 counted, 0 skipped by the registry\n"
          "    not shared: %s any: the compiler has no recorded sha256 or is not a nightly\n"
          "    not shared: %s any: a hang, or a machine error\n"
          "    not shared: %s linux_x86_64: not a unit check\n") % (line, N_X, N_H, N_NEW)
log = ENV + QUERY(REF) + platform_pinned(4) + closure_log(REF, N_OLD, N_NEW) + ID_READ + send_log(ROWS2) + TOTALS
case("ps2-share-send", "R-PB6 R-SH2 R-SH3 R-SH5 R-SH6 R-SH13 R-AP10 R-CT1 R-CT2 R-EV26 R-DA9 R-AP16",
     "`--share` sends the stored facts of one hash in one POST /v1/compat, after one POST /v1/closure (groups empty, hashes the hash, compilers from the oldest to the newest nightly of the facts that can go: here N_OLD to N_NEW, Q491). The recorded compilers are the tags with a `pinned` row for the host target `linux_x86_64` (Q492): the nightly of N_X is pinned for windows_x86_64 only, so it is not recorded. The sharing setting is not set, CI=true and DO_NOT_TRACK=1: the flag is the consent. Filter 1 does not apply (old facts). Kept back: an unrecorded compiler (filter 3), a hang (6), a build row (2). The 201 answer is added to share.json: sent 2, counted 2, first 1.",
     [line], facts, log, stdout, "", doc(), doc(2, 2, 1, NOW))
closure_route("ps2-share-send")
route("ps2-share-send", 1, 201, '{"written":2,"first":1,"skipped":[]}')

# ps3: the privacy guard first for a github.com entry (R-RG4, R-RG6). Run 1 public, run 2 private (exit 2, no read of compat.db, no request), run 3 another host (no guard call).
facts = fact(REF, N_OLD, "any", "pass")
r1 = "%s url=https://github.com/acme/json/releases/download/2.1.0/HQ.tar.zst env:GITHUB_TOKEN=tok1" % REF
r2 = "%s url=https://github.com/acme/priv/releases/download/1.0.0/HQ.tar.zst env:GITHUB_TOKEN=tok1" % REF
r3 = "%s url=https://example.org/pkg/releases/download/1/HQ.tar.zst" % REF
GH_JSON = "$HOME/.cache/roc/talon/index/github/acme/json/repo.json"
GH_PRIV = "$HOME/.cache/roc/talon/index/github/acme/priv/repo.json"
REST = QUERY(REF) + platform_pinned(1) + closure_log(REF, N_OLD, N_OLD) + ID_READ + send_log(ROW1) + TOTALS
log = (ENV + ["read_files " + GH_JSON, "http_get https://api.github.com/repos/acme/json", "  User-Agent: tln/%s" % V, "  Authorization: Bearer tok1", "write_atomic " + GH_JSON] + REST
       + ENV + ["read_files " + GH_PRIV, "http_get https://api.github.com/repos/acme/priv", "  User-Agent: tln/%s" % V, "  Authorization: Bearer tok1"]
       + ENV + REST)
stdout = ("== %s\n  shared 1 fact of HQ: 1 counted, 0 skipped by the registry\n== %s\nexit 2\n== %s\n  shared 1 fact of HQ: 0 counted, 0 skipped by the registry\n") % (r1, r2, r3)
stderr = "tln: error[usage]: GitHub repository acme/priv is private or does not exist. Private packages are not supported.\n"
repo_json = '{"id":1,"full_name":"acme/json","private":false,"fork":false}'
tree = tdiff("home/.cache/roc/talon/index/github/acme/json/repo.json", "", repo_json)
case("ps3-share-guard", "R-PB6 R-RG4 R-RG5 R-RG6 R-EC2 R-SH6",
     "the guard runs first for a `github.com` entry (the source is the release URL of the header entry): `read_files repo.json`, `http_get` of the repository, `write_atomic` of the public answer, and only then the read of compat.db, the closure query and the request. Run 2: a private repository gives exit 2 (R-RG6) with no read of compat.db and no request. Run 3: a URL of another host needs no guard call; it gets 200 with written 0 (R-CT4).",
     [r1, r2, r3], facts, log, stdout, stderr, doc(), doc(2, 1, 1, NOW), extra_tree=tree)
gh("ps3-share-guard", "json", 200, repo_json)
gh("ps3-share-guard", "priv", 200, '{"id":2,"full_name":"acme/priv","private":true,"fork":false}')
closure_route("ps3-share-guard"); closure_route("ps3-share-guard", n=2)
route("ps3-share-guard", 1, 201, '{"written":1,"first":1,"skipped":[]}')
route("ps3-share-guard", 2, 200, '{"written":0,"first":0,"skipped":[]}')

# ps4: the answers of the one request (R-E6 for a write). 15, 15, 15, 15, 1, 20. Each run: one request, no sleep, no retry, no share.json write; the lines list the fact as not sent; then the failure.
one = Q1 + ID_READ + send_log(ROW1)
log = one * 6
fails = [("tln: error[network]: the registry answered 429 (/errors/rate-limited). Try again later.", 15),
         ("tln: error[network]: the registry is busy (503). Try again later.", 15),
         ("tln: error[network]: the registry http://127.0.0.1:9 gave no answer: no answer in 20 s. Try again later.", 15),
         ("tln: error[network]: the registry http://127.0.0.1:9 gave no answer: connection refused. Try again later.", 15),
         ("tln: error[internal]: the registry http://127.0.0.1:9 refused the request (/errors/bad-request): D. This is a fault of tln 0.0.1 or a version skew.", 1),
         ("tln: error[rejected]: D (/errors/unprocessable). Fix the release or the workflow, then run the command again.", 20)]
stdout = "".join("== %s\n%s%sexit %d\n" % (REF, DONE0, NOTSENT, code) for (_, code) in fails)
stderr = "".join(t + "\n" for (t, _) in fails)
case("ps4-share-answers", "R-PB6 R-E6 R-AP10 R-AP34 R-J7",
     "the answers of the registry for the one request (R-E6 for a write): 429 and 503 busy are exit 15, no answer (timeout, failed) is exit 15, 400 is exit 1 (internal), 422 is exit 20 (rejected). One request for each run, no `sleep`, no retry (R-AP34), share.json is not written (no 200 or 201). The lines come first and list the fact as not sent (Q498); the exit is the failure.",
     [REF] * 6, fact(REF, N_OLD, "any", "pass"), log, stdout, stderr, doc(), None)
for n in range(1, 7):
    closure_route("ps4-share-answers", n=n)
route("ps4-share-answers", 1, 429, '{"type":"/errors/rate-limited","title":"T","status":429,"detail":"D"}')
route("ps4-share-answers", 2, 503, '{"type":"/errors/busy","title":"T","status":503,"detail":"D"}')
route("ps4-share-answers", 3, 0, "", ["error timeout"])
route("ps4-share-answers", 4, 0, "", ["error failed connection refused"])
route("ps4-share-answers", 5, 400, '{"type":"/errors/bad-request","title":"T","status":400,"detail":"D"}')
route("ps4-share-answers", 6, 422, '{"type":"/errors/unprocessable","title":"T","status":422,"detail":"D"}')

# ps5: 501 facts of an app hash (any target is taken): 2 requests, 500 and 1. The second gets 503: the first request got its 201, so share.json has its totals; the last fact is listed as not sent; exit 15.
rows = [("HQ", N_OLD, "pass", "t%03d" % i) for i in range(1, 502)]
facts = "".join(fact("HQ", N_OLD, r[3], "pass") for r in rows)
line = "HQ"
log = Q1 + ID_READ + send_log(rows[:500]) + send_log(rows[500:]) + TOTALS
stdout = ("== %s\n  shared 500 facts of HQ: 400 counted, 0 skipped by the registry\n    not shared: %s t501: not sent\nexit 15\n") % (line, N_OLD)
stderr = "tln: error[network]: the registry is busy (503). Try again later.\n"
case("ps5-share-batches", "R-PB6 R-AP10 R-SH6 R-SH13 R-E6",
     "501 facts are 2 requests of at most 500 rows (in order of nightly and target). The first gets 201 (written 400, first 300), the second 503 busy: the send stops, exit 15, and the fact of the second request is listed as not sent. share.json has the totals of the request that worked (sent 500, counted 400, first 300), written after the failure. No `clock` call before the requests (no budget of 5 s here).",
     [line], facts, log, stdout, stderr, doc(), doc(500, 400, 300, NOW))
closure_route("ps5-share-batches", kind="app")
route("ps5-share-batches", 1, 201, '{"written":400,"first":300,"skipped":[]}')
route("ps5-share-batches", 2, 503, '{"type":"/errors/busy","title":"T","status":503,"detail":"D"}')

# ps6: share.json is missing: it is made with a new id (the write of tln share on, Design Q213), then the request has that id.
log = Q1 + ID_READ + MAKE + send_log(ROW1, ID2) + TOTALS
stdout = "== %s\n  shared 1 fact of HQ: 1 counted, 0 skipped by the registry\n" % REF
case("ps6-share-no-share-json", "R-PB6 R-SH5 R-SH13 R-SH6",
     "no share.json: `tln probe --share` needs the id, so the file is made with a new id (the calls of `tln share on`), then the request has `Talon-Contributor: <new id>`, and the totals are written (a second write). The id is not read again.",
     [REF], fact(REF, N_OLD, "any", "pass"), log, stdout, "", "", doc(1, 1, 1, NOW, ID2))
closure_route("ps6-share-no-share-json")
route("ps6-share-no-share-json", 1, 201, '{"written":1,"first":1,"skipped":[]}', cid=ID2)

# ps7: faults of the files stop the command before the compat request (Q497): a newer compat.db (exit 19, the first db call), a share.json that does not parse (exit 19, after the closure query). No compat request, no write.
log = ENV + QUERY(REF) + Q1 + ID_READ
stdout = "== %s\nexit 19\n== %s\nexit 19\n" % (REF, REF)
stderr = ("tln: error[input]: $HOME/.cache/roc/talon/compat.db has format 2. This tln writes format 1. Run: tln tool update talon\n"
          "tln: error[input]: $HOME/.local/share/talon/share.json: the content does not parse\n")
c = case("ps7-share-file-faults", "R-PB6 R-TF3 R-SH13",
         "run 1: compat.db has a newer format (db call 1, TooNew): exit 19, the message of Db.on_err, no closure query, no request. Run 2: share.json does not parse: exit 19 with the text of ShareJson.read, no compat request, no write (Q497).",
         [REF, REF], fact(REF, N_OLD, "any", "pass"), log, stdout, stderr, "this is not json\n", None)
write(c + "/fx/db", "1: version 2\n")
closure_route("ps7-share-file-faults")

# ps10: the cap (R-PB6 (4), Q498): 10,500 facts of an app hash: exactly 20 requests of 500 rows, the other 500 facts are listed as not shared, exit 15.
rows = [("HQ", N_OLD, "pass", "t%05d" % i) for i in range(1, 10501)]
facts = "".join(fact("HQ", N_OLD, r[3], "pass") for r in rows)
log = Q1 + ID_READ
for k in range(20):
    log += send_log(rows[k * 500:(k + 1) * 500])
log += TOTALS
stdout = "== HQ\n  shared 10000 facts of HQ: 10000 counted, 0 skipped by the registry\n" + "".join("    not shared: %s %s: not sent\n" % (N_OLD, r[3]) for r in rows[10000:]) + "exit 15\n"
stderr = "tln: error[network]: tln probe --share sent 20 requests and stopped: 500 facts are not shared. Run it again to send the rest.\n"
case("ps10-share-cap", "R-PB6 R-AP10 R-SH6 R-E6 R-CT11",
     "10,500 facts make 21 batches of 500 rows, but the send stops at 20 requests (10,000 rows, Design Q498): all 20 get 201, the last 500 facts are listed as not shared (not sent), the exit is 15 (a send that did not finish), and share.json has the totals of the 20 requests (sent 10000, counted 10000, first 2000).",
     ["HQ"], facts, log, stdout, stderr, doc(), doc(10000, 10000, 2000, NOW))
closure_route("ps10-share-cap", kind="app")
for n in range(1, 21):
    route("ps10-share-cap", n, 201, '{"written":500,"first":100,"skipped":[]}')

# ps11: no fact passes the local filters 2, 3 and 6 (R-PB6 (5), Q495, Q503): a hang and a nightly that is pinned for another target only. No closure query, no compat request, no share.json read. Exit 0. The reasons are the filter reasons.
facts = fact(REF, N_X, "any", "pass") + fact(REF, N_H, "any", "hang")
log = ENV + QUERY(REF) + platform_pinned(2)
stdout = ("== %s\n  nothing to share\n    not shared: %s any: the compiler has no recorded sha256 or is not a nightly\n    not shared: %s any: a hang, or a machine error\n") % (REF, N_X, N_H)
case("ps11-share-nothing", "R-PB6 R-SH3 R-E7 R-OUT2",
     "no stored fact passes the local filters 2, 3 and 6: a nightly that is pinned for windows_x86_64 only (not recorded for this machine, Q492) and a hang. No closure query (nothing can go, Q503), no compat request, no read of share.json, exit 0, the line `nothing to share` and the lines of the facts that were kept back; the reasons are the filter reasons (the hang is `a hang`, not `not in an answer`).",
     [REF], facts, log, stdout, "", doc(), None)

# ps12: a failed write of the totals after a 200 (Q497): one warning on stderr, no change of the exit code (0). The chmod job of the write fails.
log = Q1 + ID_READ + send_log(ROW1) + ["clock", "lock %s nowait: held" % SJ, "read_files %s" % SJ, "random", "write_atomic %s" % TMP, "spawn_all limit=1", "  job - chmod 0600 %s" % TMP, "delete %s" % TMP, "unlock %s" % SJ]
stdout = "== %s\n  shared 1 fact of HQ: 1 counted, 0 skipped by the registry\n" % REF
stderr = "warning: the totals of share.json are not saved: cannot set the mode of $HOME/.local/share/talon/share.json: Exited(1)\n"
case("ps12-share-totals-warning", "R-PB6 R-SH6 R-CC8 R-OUT2",
     "the 201 answer comes, the write of the totals fails (the chmod job exits 1): one warning on stderr, the lines of the send, no exit line (exit 0), share.json is not changed (Q497).",
     [REF], fact(REF, N_OLD, "any", "pass"), log, stdout, stderr, doc(), None, jobs="chmod\t1\t-\t-\t-\n")
closure_route("ps12-share-totals-warning")
route("ps12-share-totals-warning", 1, 201, '{"written":1,"first":1,"skipped":[]}')

# ps13: any failed request stops the send (Q505): a 422 (exit 20) and a 400 (exit 1) to the first request. 501 facts: the second request is not sent, all 501 facts are listed as not sent, no share.json write.
rows = [("HQ", N_OLD, "pass", "t%03d" % i) for i in range(1, 502)]
facts = "".join(fact("HQ", N_OLD, r[3], "pass") for r in rows)
one = Q1 + ID_READ + send_log(rows[:500])
log = one + one
body13 = "".join("    not shared: %s %s: not sent\n" % (N_OLD, r[3]) for r in rows)
head13 = "== HQ\n  shared 0 facts of HQ: 0 counted, 0 skipped by the registry\n" + body13
stdout = head13 + "exit 20\n" + head13.replace("== HQ", "== HQ", 1) + "exit 1\n"
stderr = ("tln: error[rejected]: D (/errors/unprocessable). Fix the release or the workflow, then run the command again.\n"
          "tln: error[internal]: the registry http://127.0.0.1:9 refused the request (/errors/bad-request): D. This is a fault of tln 0.0.1 or a version skew.\n")
case("ps13-share-4xx-stops", "R-PB6 R-E6 R-AP10 R-J7",
     "any failed request stops the send, also a 4xx (Q505): run 1 the first request gets 422 (exit 20), run 2 gets 400 (exit 1). Only one request goes in each run (501 facts are 2 batches), all 501 facts are listed as not sent, share.json is not written.",
     ["HQ", "HQ"], facts, log, stdout, stderr, doc(), None)
for n in (1, 2):
    closure_route("ps13-share-4xx-stops", kind="app", n=n)
route("ps13-share-4xx-stops", 1, 422, '{"type":"/errors/unprocessable","title":"T","status":422,"detail":"D"}')
route("ps13-share-4xx-stops", 2, 400, '{"type":"/errors/bad-request","title":"T","status":400,"detail":"D"}')

# ps14: the send runs after a probe of exit 12 (Q506): `probe parser2 --range` of run G of probe/pc2-range (no candidate: no probe, exit 12), with a registry. The probe lines and its failure, then the share step: the guard, `facts_of` (no stored fact of the hash: no request), the line `nothing to share`. The exit stays 12.
PC2 = os.path.join(base, "pc2-range")
c = os.path.join(base, "ps14-share-after-12")
if os.path.isdir(c):
    shutil.rmtree(c)
shutil.copytree(os.path.join(PC2, "given"), os.path.join(c, "given"))
shutil.copytree(os.path.join(PC2, "fx"), os.path.join(c, "fx"))
cmd14 = "probe parser2 --range --share --file p4/main.roc"
write(c + "/entry", "commands\n")
write(c + "/fx/commands", cmd14 + "\n")
write(c + "/fx/env", open(PC2 + "/fx/env").read() + "GITHUB_TOKEN=tok1\n")
write(c + "/given/home/.config/talon/config.toml", 'registry = "http://127.0.0.1:9"\n' + open(PC2 + "/given/home/.config/talon/config.toml").read())
PH = "EiSZVhEG7h44iRLspsGTX5NRmJbz4fHktH4XcpRqFyjt"
GH_PARSER = "$HOME/.cache/roc/talon/index/github/acme/parser/repo.json"
pc2_calls = open(PC2 + "/expect/calls.log").read().split("\n")
run_g = pc2_calls[325:354]
assert run_g[0] == "args" and run_g[-1].startswith("canonical"), run_g[:1] + run_g[-1:]
NIGHT = "$HOME/.cache/roc/talon/index/github/roc-lang/nightlies"
i_pr = run_g.index("read_files $HOME/.cache/roc/talon/path-roc.json") + 1
run_g = run_g[:i_pr] + ["spawn_all limit=1", "  job - /fake/bin/roc version", "write_atomic $HOME/.cache/roc/talon/path-roc.json"] + run_g[i_pr:]
i_nr = [k for k, l in enumerate(run_g) if l.startswith("read_files " + NIGHT)][0]
run_g = run_g[:i_nr] + ["http_get https://api.github.com/repos/roc-lang/nightlies/releases?per_page=100", "  User-Agent: tln/%s" % V, "  Authorization: Bearer tok1", "write_atomic %s/1.json %s/1.meta" % (NIGHT, NIGHT)] + run_g[i_nr + 1:]
i_pq = [k for k, l in enumerate(run_g) if "format=1 pinned=10" in l][0] + 1
run_g = run_g[:i_pq] + [run_g[i_pq - 1].replace("db_query", "db_write")] + run_g[i_pq:]
log = run_g[:3] + ["env_all", CFG] + run_g[3:] + ["read_files " + GH_PARSER, "http_get https://api.github.com/repos/acme/parser", "  User-Agent: tln/%s" % V, "  Authorization: Bearer tok1", "write_atomic " + GH_PARSER,
       "db_query %s busy_ms=5000 format=1 facts_of=%s" % (DB, PH)]
parser_json = '{"id":3,"full_name":"acme/parser","private":false,"fork":false}'
gh(c.split("/")[-1], "parser", 200, parser_json)
write(c + "/expect/exit", "0\n")
write(c + "/expect/stdout", "== %s\nacme/parser 1.2.0: no release of the compiler list has a real pass\nnothing to share\nexit 12\n" % cmd14)
write(c + "/expect/stderr", "tln: error[budget]: no installed compiler gave a real pass, and no real fact exists for 10 releases of the list. Run tln roc install for more compilers.\n")
write(c + "/expect/calls.log", "\n".join(log) + "\n")
pc2_tree = open(PC2 + "/expect/tree.diff").read().split("\n")
j0 = [k for k, l in enumerate(pc2_tree) if l.startswith("--- home/.cache/roc/talon/index/github/roc-lang/nightlies/1.json")][0]
j1 = [k for k, l in enumerate(pc2_tree) if l.startswith("--- home/.cache/roc/talon/projects.json")][0]
night_diff = "\n".join(pc2_tree[j0:j1]) + "\n"
g_compat = open(PC2 + "/given/home/.cache/roc/talon/compat.tsv").read()
TAG14 = {1: "1b1b1b1", 2: "2c2c2c2", 3: "3d3d3d3", 4: "4e4e4e4", 5: "5f5f5f5", 6: "6a6a6a6", 7: "7b7b7b7", 8: "8c8c8c8", 9: "9d9d9d9", 10: "0e0e0e0"}
pinned14 = "".join("pinned\tnightly-2026-10-%02d-%s\tlinux_x86_64\t%s\tgithub-digest\n" % (d, TAG14[d], ("a" if d == 10 else str(d)) * 64) for d in range(1, 11))
write(c + "/expect/tree.diff", tdiff("home/.cache/roc/talon/compat.tsv", g_compat, g_compat + pinned14) + tdiff("home/.cache/roc/talon/index/github/acme/parser/repo.json", "", parser_json) + night_diff + tdiff("home/.cache/roc/talon/projects.json", "", '{"format":1,"projects":[{"path":"$PROJECT/p4/main.roc","last_use":1792065600}]}\n'))
write(c + "/rules", "R-PB6 R-PB4 R-EC12 R-EC2 R-RG4 (slice 217): `tln probe parser2 --range --share` with a registry: the probe stops with exit 12 (run G of probe/pc2-range: no compiler is allowed, no probe starts). The send runs after a probe of 12 (Design Q506): the guard for acme/parser, `facts_of` (the hash has no stored fact: no request), the line `nothing to share`. The exit stays 12. After another code (1, 2, 15) the share step does not run (no L2 run; the same decision).\n")

# ps8 and ps9: the whole command with a registry (entry commands): `tln probe json --share`. The probe part is the run 1 of `probe/pc1-targets` (its calls, its given files); then the share step. ps8: the send works (exit 0). ps9: the compat request gets 503: the probe lines, the share lines, exit 15.
PC1 = os.path.join(base, "pc1-targets")
pc_calls = open(PC1 + "/expect/calls.log").read().split("\n")
probe_calls = pc_calls[3:31]  # after `args`, `env_all`, `tty`: the calls of run 1 up to the fact write (28 lines)
HASH = "4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq"
JURL = "https://github.com/acme/json/releases/download/2.1.0/%s.tar.zst" % HASH
CFG = "read_files $HOME/.config/talon/config.toml"
for name, ok in (("ps8-share-command", True), ("ps9-share-command-fails", False)):
    c = os.path.join(base, name)
    if os.path.isdir(c):
        shutil.rmtree(c)
    cmdline = "probe json --share --file p1/main.roc"
    write(c + "/entry", "commands\n")
    write(c + "/fx/commands", cmdline + "\n")
    for f in ("gitdirs", "path-roc", "mtimes", "jobs", "programs", "units", "probes"):
        shutil.copy(os.path.join(PC1, "fx", f), os.path.join(c, "fx", f)) if os.path.exists(os.path.join(c, "fx")) else (os.makedirs(os.path.join(c, "fx")), shutil.copy(os.path.join(PC1, "fx", f), os.path.join(c, "fx", f)))
    open(c + "/fx/jobs", "a").write("chmod\t0\t-\t-\t-\n")
    shutil.copytree(os.path.join(PC1, "fx", "pkgs"), os.path.join(c, "fx", "pkgs"))
    write(c + "/fx/env", open(PC1 + "/fx/env").read() + "GITHUB_TOKEN=tok1\n")
    shutil.copytree(os.path.join(PC1, "given"), os.path.join(c, "given"))
    write(c + "/given/home/.config/talon/config.toml", 'registry = "http://127.0.0.1:9"\n[probe]\ntimeout = 9\n')
    given_compat = open(PC1 + "/given/home/.cache/roc/talon/compat.tsv").read() + "pinned\t%s\tlinux_x86_64\t%s\tgithub-digest\n" % (N_NEW, "a" * 64)
    write(c + "/given/home/.cache/roc/talon/compat.tsv", given_compat)
    write(c + "/given/home/.local/share/talon/share.json", doc())
    # the facts after the probe: the new pass of json
    f_json = "fact\t%s\t%s\tany\tpass\t\t\n" % (HASH, N_NEW)
    parts = given_compat.split("\n")
    after_compat = parts[0] + "\n" + f_json + "\n".join(parts[1:])
    ROWJ = [(HASH, N_NEW, "pass", "any")]
    share_calls = (["read_files " + GH_JSON.replace("acme/json", "acme/json"), "http_get https://api.github.com/repos/acme/json", "  User-Agent: tln/%s" % V, "  Authorization: Bearer tok1", "write_atomic " + GH_JSON,
                    "db_query %s busy_ms=5000 format=1 facts_of=%s" % (DB, HASH)] + platform_pinned(1) + closure_log(HASH, N_NEW, N_NEW) + ID_READ + send_log(ROWJ))
    if ok:
        share_calls += TOTALS
    log = ["args", "env_all", "tty", "env_all", CFG] + probe_calls + share_calls
    unit = "unit check of acme/json 2.1.0 on %s: pass\n" % N_NEW
    if ok:
        out = "== %s\n%sshared 1 fact of acme/json 2.1.0: 1 counted, 0 skipped by the registry\nexit 0\n" % (cmdline, unit)
        err = ""
        docf = doc(1, 1, 1, NOW)
    else:
        out = "== %s\n%sshared 0 facts of acme/json 2.1.0: 0 counted, 0 skipped by the registry\n  not shared: %s any: not sent\nexit 15\n" % (cmdline, unit, N_NEW)
        err = "tln: error[network]: the registry is busy (503). Try again later.\n"
        docf = None
    write(c + "/expect/exit", "0\n")
    write(c + "/expect/stdout", out)
    if err:
        write(c + "/expect/stderr", err)
    write(c + "/expect/calls.log", "\n".join(log) + "\n")
    td = tdiff("home/.cache/roc/talon/compat.tsv", given_compat, after_compat)
    td += tdiff("home/.cache/roc/talon/index/github/acme/json/repo.json", "", repo_json)
    td += tdiff("home/.cache/roc/talon/projects.json", "", '{"format":1,"projects":[{"path":"$PROJECT/p1/main.roc","last_use":1792065600}]}\n')
    if docf:
        td += tdiff(J, doc(), docf)
    write(c + "/expect/tree.diff", td)
    write(c + "/rules", "R-PB6 R-CM8 R-PB2 R-SH2 R-SH5 R-SH6 R-RG4 R-E6 R-FL5 (slice 217): `tln probe json --share` with a registry in config.toml (the whole command, Q493). The probe is run 1 of probe/pc1-targets (the same calls and lines); the share step comes after the probe lines: the guard (acme/json), `facts_of`, `platform`, `pinned`, the closure query (compilers from the one nightly of the fact to itself), `share.json`, `POST /v1/compat`" + (", the totals. Exit 0.\n" if ok else ". The compat request gets 503: the share lines (the fact is not sent), then exit 15 (the probe was 0, so the failed send gives the code, Q493). No totals write.\n"))
    closure_route(name, art_hash=HASH)
    gh(name, "json", 200, repo_json)
    if ok:
        route(name, 1, 201, '{"written":1,"first":1,"skipped":[]}')
    else:
        route(name, 1, 503, '{"type":"/errors/busy","title":"T","status":503,"detail":"D"}')

# ps1: the exit 2 and 15 cases of the whole command (entry commands): direct (the default, --registry direct, --json), no operand and a bundle file with a registry flag, and --offline with a registry (exit 15, Q494).
c = os.path.join(base, "ps1-share-usage")
if os.path.isdir(c):
    shutil.rmtree(c)
cmds = ["probe --share json", "probe --share json --registry direct", "probe --share json --json", "probe --share --registry http://127.0.0.1:9", "probe --share out/8FNd42oEnQP2CUSB4YWEqcsHBwCq8z26bL1Xk3PwDQ8f.tar.zst --registry http://127.0.0.1:9", "probe --share json --registry http://127.0.0.1:9 --offline"]
write(c + "/entry", "commands\n")
write(c + "/rules", "R-PB6 R-CM8 R-EC2 R-EC15 R-SH10 R-RG1 R-J5 R-FL5 (slice 217): `tln probe --share` with exit 2 (usage) or 15, before any probe or request. Runs 1 to 3: the registry is direct (the default, the flag, and with --json: the error envelope): the calls end after the read of config.toml (as `share logout`). Runs 4 and 5: a registry flag is read for `probe --share` (no P0 refusal), and the plan stops for no operand (the project file has no hash) and for a bundle file: no call after the prelude (args, env_all, tty). Run 6: `--offline` with a registry is exit 15 (Q494), with the calls of the direct stop.\n")
write(c + "/fx/commands", "\n".join(cmds) + "\n")
write(c + "/fx/env", "HOME={w}/home\n")
write(c + "/fx/jobs", "chmod\t0\t-\t-\t-\n")
write(c + "/given/home/.config/talon/config.toml", "[probe]\ntimeout = 9\n")
PRE = ["args", "env_all", "tty"]
direct = PRE + ["env_all", CFG]
json_direct = ["args", "env_all", "env_all", CFG]  # --json: the first-run prompt makes no tty call (R-SH11)
log = direct + direct + json_direct + PRE + PRE + direct
D = "tln probe --share needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml."
stdout = ("== %s\nexit 2\n== %s\nexit 2\n== %s\n{\"schema\":1,\"command\":\"probe\",\"ok\":false,\"data\":null,\"error\":{\"kind\":\"usage\",\"code\":2,\"message\":\"%s\"}}\nexit 2\n== %s\nexit 2\n== %s\nexit 2\n== %s\nexit 15\n") % (cmds[0], cmds[1], cmds[2], D, cmds[3], cmds[4], cmds[5])
stderr = ("tln: error[usage]: %s\ntln: error[usage]: %s\ntln: error[usage]: %s\n"
          "tln: error[usage]: tln probe --share needs a header alias: the project file has no hash\n"
          "tln: error[usage]: tln probe --share needs a header alias: a bundle file can be a hash before its release\n"
          "tln: error[network]: tln probe --share needs the network: --offline sends no request\n") % (D, D, D)
write(c + "/expect/exit", "0\n")
write(c + "/expect/stdout", stdout)
write(c + "/expect/stderr", stderr)
write(c + "/expect/calls.log", "\n".join(log) + "\n")
write(c + "/expect/tree.diff", "")
PY
