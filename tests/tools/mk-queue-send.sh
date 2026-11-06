#!/usr/bin/env bash
# Slice 216: makes the L2 cases tests/commands/cases/share/sh11 to sh16 (the send of the share queue, R-SH4). The expected files are written from the design readings of the slice file, not from a run of tln.
# Usage: tests/tools/mk-queue-send.sh        (writes the 6 case dirs; run it again after a change of the rows)
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
exec python3 -I - "$ROOT/tests/commands/cases/share" <<'PY'
import os, sys, subprocess, shutil, tempfile
base = sys.argv[1]
ID = "0123456789abcdeffedcba9876543210"
NOW = "2026-10-15T12:00:00Z"  # the fake clock 1792065600
DB = "$HOME/.cache/roc/talon/compat.db"
SJ = "$HOME/.local/share/talon/share.json"
TMP = SJ + ".0123456789abcdef.tmp"
Q = "home/.cache/roc/talon/share_queue.tsv"
J = "home/.local/share/talon/share.json"

def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)

def doc(sent=0, counted=0, first=0, at=None):
    t = "null" if at is None else '"%s"' % at
    return '{"format":1,"id":"%s","sent":%d,"counted":%d,"first":%d,"first_sent_at":%s,"last_sent_at":%s,"token":null,"token_expires_at":null,"account":null}\n' % (ID, sent, counted, first, t, t)

def qline(seq, r):
    return "\t".join([str(seq)] + list(r)) + "\n"

def body(rows, version="0.9.0"):
    items = ",".join('{"hash":"%s","nightly":"%s","result":"%s","target":"%s"}' % (h, n, res, t) for (h, n, t, res, v, at) in rows)
    return '{"rows":[%s],"talon_version":"%s"}' % (items, version)

def tdiff(label, before, after):
    d = tempfile.mkdtemp()
    a, b = os.path.join(d, "a"), os.path.join(d, "b")
    write(a, before); write(b, after)
    r = subprocess.run(["diff", "-u", "--label", label, "--label", label, a, b], capture_output=True, text=True)
    shutil.rmtree(d)
    return r.stdout

def send_log(rows, timeout=5, version="0.9.0"):
    return ["http_send POST http://127.0.0.1:9/v1/compat timeout=%d" % timeout,
            "  User-Agent: tln/%s" % version, "  Content-Type: application/json", "  Talon-Contributor: %s" % ID,
            "  <body> " + body(rows, version)]

TOTALS = ["clock", "lock %s nowait: held" % SJ, "read_files %s" % SJ, "random", "write_atomic %s" % TMP, "spawn_all limit=1", "  job - chmod 0600 %s" % TMP,
          "rename %s %s" % (TMP, SJ), "unlock %s" % SJ]
HEAD = ["env_all", "db_query %s busy_ms=5000 format=1 queue_rows" % DB]
ID_READ = ["read_files %s" % SJ]
def unq(n): return "db_write %s busy_ms=5000 format=1 unqueue=%d" % (DB, n)

def route(case, n, status, body_text, extra=(), cid=None):
    cid = cid or ID
    d = os.path.join(base, case, "fx/http/127.0.0.1%3A9/v1")
    suffix = "" if n == 1 else ".%d" % n
    write(os.path.join(d, "compat.POST" + suffix), body_text)
    meta = ["status %d" % status] if status else []
    meta += ["header Content-Type: application/json", "header Cache-Control: no-store"] + list(extra)
    meta += ["require content-type: application/json", "require talon-contributor: " + cid, "require-none authorization", "require user-agent: tln/0.9.0"]
    write(os.path.join(d, "compat.POST%s.meta" % suffix), "\n".join(meta) + "\n")

def case(name, comment, runs, given_rows, expect_log, expect_stdout, final_queue, final_doc, stderr="", given_doc=None):
    gdoc = doc() if given_doc is None else given_doc
    c = os.path.join(base, name)
    if os.path.isdir(c):
        shutil.rmtree(c)
    write(c + "/entry", "db\n")
    write(c + "/fx/runs", comment + "\n" + "\n".join(runs) + "\n")
    write(c + "/fx/jobs", "chmod\t0\t-\t-\t-\n")
    write(c + "/given/home/.cache/roc/talon/compat.tsv", "format\t1\n")
    qtext = "".join(qline(i + 1, r) for i, r in enumerate(given_rows))
    write(c + "/given/home/.cache/roc/talon/share_queue.tsv", qtext)
    if gdoc != "":
        write(c + "/given/home/.local/share/talon/share.json", gdoc)
    write(c + "/expect/exit", "0\n")
    write(c + "/expect/stdout", expect_stdout)
    write(c + "/expect/calls.log", "\n".join(expect_log) + "\n")
    if stderr:
        write(c + "/expect/stderr", stderr)
    td = ""
    if final_queue is not None:
        td += tdiff(Q, qtext, "".join(qline(s, r) for s, r in final_queue))
    if final_doc is not None:
        td += tdiff(J, gdoc, final_doc)
    write(c + "/expect/tree.diff", td)
    return c

N = "nightly-2026-10-14-38a3029"
N2 = "nightly-2026-10-12-2664a27"

# sh11: one request, 3 rows, a 201 answer.
rows = [("HA", N, "any", "pass", "0.9.0", "2026-11-03T10:00:00Z"), ("HB", N, "linux_x86_64", "fail", "0.9.0", "2026-11-03T10:01:00Z"), ("HC", N2, "any", "crash", "0.9.0", "2026-11-03T10:02:00Z")]
case("sh11-send-one", "# R-SH4, R-SH5, R-SH6, R-AP10, R-CT1, R-CT2: 3 rows of the running version go in one POST /v1/compat with Talon-Contributor (the id of share.json) and no Authorization. A 201 answer: the rows leave, and share.json gets sent 3, counted 3, first 2.",
     ["queue-send 0.9.0"], rows,
     HEAD + ID_READ + ["clock"] + send_log(rows) + [unq(3)] + TOTALS,
     "== queue-send 0.9.0\n  done\n", [], doc(3, 3, 2, NOW))
route("sh11-send-one", 1, 201, '{"written":3,"first":2,"skipped":[]}')

# sh12: 1001 rows, 2 requests of 500, the row 1001 waits.
big = [("h%d" % i, "n", "any", "pass", "0.9.0", "t") for i in range(1, 1002)]
log = HEAD + ID_READ + ["clock"] + send_log(big[:500]) + [unq(500), "clock"] + send_log(big[500:1000]) + [unq(500)] + TOTALS
case("sh12-send-limits", "# R-SH4: 1001 rows. At most 2 requests of 500 rows, the oldest first (rows 1 to 500, then 501 to 1000). Row 1001 waits for a later command. Each request has the timeout 5 (the fake clock does not move). The totals add both answers: sent 1000, counted 900, first 400.",
     ["queue-send 0.9.0"], big, log, "== queue-send 0.9.0\n  done\n", [(1001, big[1000])], doc(1000, 900, 400, NOW))
route("sh12-send-limits", 1, 201, '{"written":500,"first":300,"skipped":[]}')
route("sh12-send-limits", 2, 201, '{"written":400,"first":100,"skipped":[{"row":0,"reason":"unknown-hash"}]}')

# sh13: rows of another version leave with no send.
r13 = [("OLD1", N, "any", "pass", "0.8.0", "t"), ("HB", N, "any", "pass", "0.9.0", "t"), ("OLD3", N, "any", "fail", "0.8.0", "t"), ("HD", N, "any", "crash", "0.9.0", "t")]
mine = [r13[1], r13[3]]
log = (HEAD + [unq(2)] + ID_READ + ["clock"] + send_log(mine) + [unq(2)] + TOTALS
       + HEAD
       + ["db_write %s busy_ms=5000 format=1 queue=1 cap=10000" % DB]
       + HEAD + [unq(1)])
case("sh13-send-version", "# R-SH4, R-TF7: run 1: the rows 1 and 3 are of tln 0.8.0: they leave with no send (one Unqueue, before the request); rows 2 and 4 are sent. Run 2: the queue is empty, only the query. Run 3: a row of 0.8.0 only: it leaves, share.json is not read, no request.",
     ["queue-send 0.9.0", "queue-send 0.9.0", "queue-add 10000 X,n,any,pass,0.8.0,t", "queue-send 0.9.0"], r13, log,
     "== queue-send 0.9.0\n  done\n== queue-send 0.9.0\n  done\n== queue-add 10000 X,n,any,pass,0.8.0,t\n  Queued\n== queue-send 0.9.0\n  done\n", [], doc(2, 2, 2, NOW))
route("sh13-send-version", 1, 201, '{"written":2,"first":2,"skipped":[]}')

# sh14: the answers. Rows stay after 429, 503, no answer; they leave after a 422 (nothing counted) and after a 200 that skips both.
r14 = [("HA", N, "any", "pass", "0.9.0", "t"), ("HB", N, "any", "fail", "0.9.0", "t")]
one = HEAD + ID_READ + ["clock"] + send_log(r14)
log = one + one + one + one + one + [unq(2)] + ["db_write %s busy_ms=5000 format=1 queue=2 cap=10000" % DB] + one + [unq(2)] + TOTALS
spec = "queue-add 10000 HA,%s,any,pass,0.9.0,t HB,%s,any,fail,0.9.0,t" % (N, N)
case("sh14-send-answers", "# R-SH4, R-AP34, R-CT4, R-CT13, R-CT14: runs 1 to 4: a 429 (with Retry-After), a 503 busy (R-AP82, with Retry-After 1; the send does not wait), no answer (timeout), a failed request: the rows stay, one request each, no sleep, no retry, no write. Run 5: a 422: both rows leave, nothing is counted (no share.json write). Then the rows again. Run 6: a 200 that skips both rows: they leave, sent 2, counted 0, first 0.",
     ["queue-send 0.9.0"] * 5 + [spec, "queue-send 0.9.0"], r14, log,
     "".join("== queue-send 0.9.0\n  done\n" for _ in range(5)) + "== " + spec + "\n  Queued\n== queue-send 0.9.0\n  done\n", [], doc(2, 0, 0, NOW))
route("sh14-send-answers", 1, 429, '{"type":"/errors/rate-limited","status":429}', ["header Retry-After: 60"])
route("sh14-send-answers", 2, 503, '{"type":"/errors/busy","title":"Busy","status":503}', ["header Retry-After: 1"])
route("sh14-send-answers", 3, 0, "", ["error timeout"])
route("sh14-send-answers", 4, 0, "", ["error failed connection refused"])
route("sh14-send-answers", 5, 422, '{"type":"/errors/unprocessable","status":422}')
route("sh14-send-answers", 6, 200, '{"written":0,"first":0,"skipped":[{"row":0,"reason":"bot-row"},{"row":1,"reason":"unknown-hash"}]}')

# sh15: R-SH2 again before the send.
log = []
for _ in range(5):
    log += ["env_all"]
log += ["env_all", "db_query %s busy_ms=5000 format=1 queue_rows" % DB] + ID_READ + ["clock"] + send_log(r14) + [unq(2)] + TOTALS
words = ["off", "direct", "offline", "env:DO_NOT_TRACK=1", "env:CI=true"]
case("sh15-send-off", "# R-SH2, R-SH4: the 5 conditions are checked again before the send. Runs 1 to 5: share = false, no registry (direct), --offline, DO_NOT_TRACK=1, CI=true: no query, no request, the rows stay. Run 6: all true: the rows are sent.",
     ["queue-send 0.9.0 " + w for w in words] + ["queue-send 0.9.0"], r14, log,
     "".join("== queue-send 0.9.0 %s\n  done\n" % w for w in words) + "== queue-send 0.9.0\n  done\n", [], doc(2, 2, 2, NOW))
route("sh15-send-off", 1, 201, '{"written":2,"first":2,"skipped":[]}')

# sh16: a failed read of the queue ends the send, with no output.
log = (HEAD + HEAD + HEAD + HEAD + ID_READ + ["clock"] + send_log(r14) + [unq(2)] + TOTALS)
case("sh16-send-db-errors", "# R-SH4, R-CC8, R-TF3, Q453: the send never changes the output or the exit code. Run 1: the file is busy (db call 1). Run 2: SQLite fails (db call 2). Run 3: a newer format (db call 3, TooNew). All end the send: no request, nothing on stderr, exit 0. Run 4 works.",
     ["queue-send 0.9.0"] * 4, r14, log, "== queue-send 0.9.0\n  done\n" * 4, [], doc(2, 2, 2, NOW))
write(base + "/sh16-send-db-errors/fx/db", "1: busy\n2: failed the disk is full\n3: version 2\n")
route("sh16-send-db-errors", 1, 201, '{"written":2,"first":2,"skipped":[]}')

# sh17: Q452: share.json is missing: it is made with a new id (the 213b calls, the id of the fake random numbers), then the rows are sent with that id.
ID2 = "0123456789abcdef0123456789abcdef"
MAKE = ["lock %s nowait: held" % SJ, "read_files %s" % SJ, "random", "random", "random", "write_atomic %s" % TMP, "spawn_all limit=1", "  job - chmod 0600 %s" % TMP, "rename %s %s" % (TMP, SJ), "unlock %s" % SJ]
def doc2(sent=0, counted=0, first=0, at=None):
    return doc(sent, counted, first, at).replace(ID, ID2)
def send_log2(rows):
    return [l.replace(ID, ID2) for l in send_log(rows)]
log = HEAD + ID_READ + MAKE + ["clock"] + send_log2(r14) + [unq(2)] + TOTALS
case("sh17-send-no-share-json", "# R-SH4, R-SH5, R-SH13, Q452: share = true and no share.json: the file is made with a new id (the calls of tln share on), then the rows are sent with that id. The id is not read again.",
     ["queue-send 0.9.0"], r14, log, "== queue-send 0.9.0\n  done\n", [], doc2(2, 2, 2, NOW), given_doc="")
route("sh17-send-no-share-json", 1, 201, '{"written":2,"first":2,"skipped":[]}', cid=ID2)

# sh18: Q457: the times of share.json come from TALON_NOW.
T9 = "2026-11-03T09:00:00Z"
log = HEAD + ID_READ + ["clock"] + send_log(r14) + [unq(2)] + TOTALS
case("sh18-send-talon-now", "# R-SH6, R-EV22, Q457: TALON_NOW fixes the times first_sent_at and last_sent_at (the clock call is still made once).",
     ["queue-send 0.9.0 env:TALON_NOW=" + T9], r14, log, "== queue-send 0.9.0 env:TALON_NOW=" + T9 + "\n  done\n", [], doc(2, 2, 2, T9))
route("sh18-send-talon-now", 1, 201, '{"written":2,"first":2,"skipped":[]}')

# sh19: Q458: 501 rows (2 batches). After a 429, a 503, a timeout the send stops (one request). After a 422 the second request goes.
b501 = [("h%d" % i, "n", "any", "pass", "0.9.0", "t") for i in range(1, 502)]
one = HEAD + ID_READ + ["clock"] + send_log(b501[:500])
log = one + one + one + one + [unq(500), "clock"] + send_log(b501[500:]) + [unq(1)] + TOTALS
case("sh19-send-stops", "# R-SH4, Q458: 501 rows make 2 batches. Runs 1 to 3: the first request gets a 429, a 503 busy, no answer: the send stops, no second request, the rows stay. Run 4: the first gets a 422 (the 500 rows leave, nothing counted), so the second request goes (row 501), a 201: sent 1.",
     ["queue-send 0.9.0"] * 4, b501, log, "== queue-send 0.9.0\n  done\n" * 4, [], doc(1, 1, 1, NOW))
route("sh19-send-stops", 1, 429, '{"type":"/errors/rate-limited","status":429}', ["header Retry-After: 60"])
route("sh19-send-stops", 2, 503, '{"type":"/errors/busy","title":"Busy","status":503}', ["header Retry-After: 1"])
route("sh19-send-stops", 3, 0, "", ["error timeout"])
route("sh19-send-stops", 4, 422, '{"type":"/errors/unprocessable","status":422}')
route("sh19-send-stops", 5, 201, '{"written":1,"first":1,"skipped":[]}')

# sh20: Q459: Unqueue fails after a 201: no totals write. The rows stay and go again.
one = HEAD[:0] + HEAD + ID_READ + ["clock"] + send_log(r14) + [unq(2)]
log = one + HEAD + ID_READ + ["clock"] + send_log(r14) + [unq(2)] + TOTALS
case("sh20-send-unqueue-fails", "# R-SH4, R-SH6, R-CT4, Q459: run 1: the 201 answer comes, the Unqueue write fails (db call 2): no totals write, the rows stay. Run 2: the rows go again, the registry says written 0 (R-CT4), the rows leave, sent 2 counted 0.",
     ["queue-send 0.9.0"] * 2, r14, log, "== queue-send 0.9.0\n  done\n" * 2, [], doc(2, 0, 0, NOW))
write(base + "/sh20-send-unqueue-fails/fx/db", "2: failed the disk is full\n")
route("sh20-send-unqueue-fails", 1, 201, '{"written":2,"first":2,"skipped":[]}')
route("sh20-send-unqueue-fails", 2, 200, '{"written":0,"first":0,"skipped":[]}')

# sh21: Q453: a share.json that does not parse ends the send, with no output.
log = HEAD + ID_READ
case("sh21-send-bad-share-json", "# R-SH4, R-SH13, Q453: a share.json that does not parse: no send, no message, exit 0. The rows stay, the file is not changed.",
     ["queue-send 0.9.0"], r14, log, "== queue-send 0.9.0\n  done\n", None, None, given_doc="this is not json\n")

# sh22: Q464: the first Unqueue fails with 2 batches: the send stops, one request, no second batch, no totals write.
log = HEAD + ID_READ + ["clock"] + send_log(b501[:500]) + [unq(500)]
case("sh22-send-unqueue-stops", "# R-SH4, Q464: 501 rows (2 batches). The first request gets a 201, its Unqueue fails (db call 2): the send stops, the second batch does not go, no totals write, the rows stay.",
     ["queue-send 0.9.0"], b501, log, "== queue-send 0.9.0\n  done\n", None, None)
write(base + "/sh22-send-unqueue-stops/fx/db", "2: failed the disk is full\n")
route("sh22-send-unqueue-stops", 1, 201, '{"written":500,"first":500,"skipped":[]}')
PY
