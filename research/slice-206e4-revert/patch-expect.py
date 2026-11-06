#!/usr/bin/env python3
"""Slice 206e4: the by-hand edits of the expect files (after `UPDATE=1` on the current code, TW21). Run once, from the repo root."""
import json, os, re, sys
C = "tests/commands/cases/"
def rd(p): return open(C + p).read()
def wr(p, t): open(C + p, "w").write(t)
def sub1(p, old, new, count=1):
    t = rd(p)
    assert t.count(old) >= 1, (p, old)
    if count == 1: assert t.count(old) == 1, (p, old, t.count(old))
    wr(p, t.replace(old, new))

def notes_json(items):
    return json.dumps(items, separators=(",", ":"))
def jn(name, t, text): return {"kind": "index-stale", "name": name, "checked_at": t, "text": text}

# ---- ap30-update-notes
J = "index: acme/json checked 3d ago"
P = "index: acme/pfx not checked since its first ingest"
n1 = [jn("acme/json", 1791799200000, J), jn("acme/pfx", None, P)]
p = "registry/ap30-update-notes/expect/"
for f in ("stdout", "stderr"):
    t = rd(p + f)
    t = t.replace("note: platform changes: acme/pfx 0.1.0 -> acme/pfx 0.1.1\ncheck: skipped\n", "note: platform changes: acme/pfx 0.1.0 -> acme/pfx 0.1.1\nnote: %s\nnote: %s\ncheck: skipped\n" % (J, P))
    wr(p + f, t)
t = rd(p + "stdout")
t = t.replace('"notes":["platform changes: acme/pfx 0.1.0 -> acme/pfx 0.1.1"],"written":[]}', '"notes":["platform changes: acme/pfx 0.1.0 -> acme/pfx 0.1.1","%s","%s"],"written":[],"index_notes":%s}' % (J, P, notes_json(n1)))
wr(p + "stdout", t)

# ---- ap30-held-move-notes
PL = "note: platform changes: acme/pfx 0.1.0 -> acme/pfx 0.1.1\n"
NOW = 1792065600000
HJ = "index: acme/json checked 2d ago"
HP = "index: acme/pfx not checked since its first ingest"
HY = "index: acme/yaml checked 12m ago"
n2 = [jn("acme/json", NOW - 2 * 86400000, HJ), jn("acme/pfx", None, HP), jn("acme/yaml", NOW - 12 * 60000, HY)]
p = "registry/ap30-held-move-notes/expect/"
for f in ("stdout", "stderr"):
    t = rd(p + f)
    assert t.count(PL) >= 1
    t = t.replace(PL, PL + "note: %s\nnote: %s\nnote: %s\n" % (HJ, HP, HY))
    wr(p + f, t)
t = rd(p + "stdout")
old = '"notes":["platform changes: acme/pfx 0.1.0 -> acme/pfx 0.1.1"],"written":[]}'
assert t.count(old) == 1
t = t.replace(old, '"notes":["platform changes: acme/pfx 0.1.0 -> acme/pfx 0.1.1","%s","%s","%s"],"written":[],"index_notes":%s}' % (HJ, HP, HY, notes_json(n2)))
wr(p + "stdout", t)

# ---- ap30-outdated-notes
p = "registry/ap30-outdated-notes/expect/"
t = rd(p + "stdout")
table = "  pf       0.1.0    0.1.1   0.1.1   none known\n"
assert t.count(table) == 2
first = t.index(table) + len(table)
t = t[:first] + "note: %s\nnote: %s\n" % (J, P) + t[first:]  # run 1 only (run 3 --quiet keeps the table, no note)
old = '"fixed":[]}]},"error":null}'
assert t.count(old) == 1
t = t.replace(old, '"fixed":[]}],"index_notes":%s},"error":null}' % notes_json(n1))
wr(p + "stdout", t)

# ---- share cases: the queue calls (written by hand from the rules, see the slice file "flow as I read it")
DB = "$HOME/.cache/roc/talon/compat.db busy_ms=5000 format=1"
SJ = "$HOME/.local/share/talon/share.json"
def rows_json(rows): return json.dumps(rows, separators=(",", ":"))
def row(h, n, r, t): return {"hash": h, "nightly": n, "result": r, "target": t}
def send_block(rows, unq, send=True, totals=True):
    out = ["db_query %s queue_rows" % DB]
    if send:
        out += ["read_files " + SJ, "clock", "http_send POST http://127.0.0.1:9/v1/compat timeout=5", "  User-Agent: tln/0.0.1", "  Content-Type: application/json",
                "  Talon-Contributor: 0123456789abcdeffedcba9876543210", "  <body> " + json.dumps({"rows": rows, "talon_version": "0.0.1"}, separators=(",", ":"), sort_keys=True)]
        if unq: out += ["db_write %s unqueue=%d" % (DB, unq)]
        if totals: out += ["clock", "lock %s nowait: held" % SJ, "read_files " + SJ, "random", "write_atomic %s.0123456789abcdef.tmp" % SJ, "spawn_all limit=1",
                           "  job - chmod 0600 %s.0123456789abcdef.tmp" % SJ, "rename %s.0123456789abcdef.tmp %s" % (SJ, SJ), "unlock " + SJ]
    return out
def split_runs(lines):
    runs = []
    for l in lines:
        if l == "args": runs.append([])
        runs[-1].append(l)
    return runs
def edit_calls(p, per_run):
    """per_run: a function (index, run lines) -> run lines."""
    lines = rd(p).split("\n")
    assert lines[-1] == ""
    runs = split_runs(lines[:-1])
    new = []
    for i, r in enumerate(runs): new += per_run(i, r)
    wr(p, "\n".join(new) + "\n")
def after(r, needle, add):
    idx = [i for i, l in enumerate(r) if l == needle]
    assert len(idx) == 1, (needle, idx)
    return r[:idx[0] + 1] + add + r[idx[0] + 1:]
HA = row("HA", "nightly-2026-10-14-38a3029", "pass", "any")
PARSER = row("EiSZVhEG7h44iRLspsGTX5NRmJbz4fHktH4XcpRqFyjt", "nightly-2026-10-14-38a3029", "pass", "any")
PLAT = row("9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK", "nightly-2026-10-14-38a3029", "pass", "any")
FACTS2 = "db_write %s facts=2 existing=replace" % DB
ENQ = ["db_query %s pinned=1" % DB, "clock", "db_write %s queue=2 cap=10000" % DB]

# ---- sh49-update-share
p = "share/sh49-update-share/expect/"
def f49(i, r):
    if i == 0: return after(r, FACTS2, ENQ) + send_block([HA, PARSER, PLAT], 3)
    return r + send_block([], 0, send=False)
edit_calls(p + "calls.log", f49)
Q = "home/.cache/roc/talon/share_queue.tsv"
wr(p + "tree.diff", rd(p + "tree.diff") + """--- home/.cache/roc/talon/share_queue.tsv
+++ home/.cache/roc/talon/share_queue.tsv
@@ -1 +0,0 @@
-1\tHA\tnightly-2026-10-14-38a3029\tany\tpass\t0.0.1\t2026-10-19T10:00:00Z
--- home/.local/share/talon/share.json
+++ home/.local/share/talon/share.json
@@ -1 +1 @@
-{"format":1,"id":"0123456789abcdeffedcba9876543210","sent":0,"counted":0,"first":0,"first_sent_at":null,"last_sent_at":null,"token":null,"token_expires_at":null,"account":null}
+{"format":1,"id":"0123456789abcdeffedcba9876543210","sent":3,"counted":3,"first":2,"first_sent_at":"2026-10-20T12:00:00Z","last_sent_at":"2026-10-20T12:00:00Z","token":null,"token_expires_at":null,"account":null}
""")

# ---- sh50-update-share-off
p = "share/sh50-update-share-off/expect/"
def f50(i, r):
    if i == 2: return r + send_block([HA], 1)
    return r
edit_calls(p + "calls.log", f50)
wr(p + "tree.diff", rd(p + "tree.diff") + """--- home/.cache/roc/talon/share_queue.tsv
+++ home/.cache/roc/talon/share_queue.tsv
@@ -1 +0,0 @@
-1\tHA\tnightly-2026-10-14-38a3029\tany\tpass\t0.0.1\t2026-10-19T10:00:00Z
--- home/.local/share/talon/share.json
+++ home/.local/share/talon/share.json
@@ -1 +1 @@
-{"format":1,"id":"0123456789abcdeffedcba9876543210","sent":0,"counted":0,"first":0,"first_sent_at":null,"last_sent_at":null,"token":null,"token_expires_at":null,"account":null}
+{"format":1,"id":"0123456789abcdeffedcba9876543210","sent":1,"counted":1,"first":1,"first_sent_at":"2026-10-20T12:00:00Z","last_sent_at":"2026-10-20T12:00:00Z","token":null,"token_expires_at":null,"account":null}
""")

# ---- sh51-send-*: one run, a 503 answer: the rows stay (no unqueue, no totals write)
for short in ("install", "verify", "upgrade", "outdated", "why"):
    p = "share/sh51-send-%s/expect/" % short
    edit_calls(p + "calls.log", lambda i, r: r + send_block([HA], 0, totals=False))

# ---- round 2 (Design Q533 to Q540)
# ap30-update-error-notes: the note after the error text on stderr (both runs), none in the --json error object
p = "registry/ap30-update-error-notes/expect/"
ERR = "tln: error[no_tuple]: no tuple works: the releases of json, yaml, pf do not fit together (R-C2, R-C3)\n"
t = rd(p + "stderr")
assert t == ERR * 2
wr(p + "stderr", (ERR + "note: index: acme/yaml checked 12m ago\n") * 2)
# sh57-send-after-error: exit 10, the send still runs (503: the row stays)
edit_calls("share/sh57-send-after-error/expect/calls.log", lambda i, r: r + send_block([HA], 0, totals=False))
# sh52-update-share-header: as sh49 run 1 (the headers are read once, by R-DI7; the queue step adds no read, Q535)
p = "share/sh52-update-share-header/expect/"
edit_calls(p + "calls.log", lambda i, r: after(r, FACTS2, ENQ) + send_block([HA, PARSER, PLAT], 3))
wr(p + "tree.diff", rd(p + "tree.diff") + rd("share/sh49-update-share/expect/tree.diff").split("--- home/.cache/roc/talon/share_queue.tsv")[1].join(["--- home/.cache/roc/talon/share_queue.tsv", ""]))

# ---- round 3 (Q541): sh58-send-upgrade-roc: index notes, then the send (503)
p = "share/sh58-send-upgrade-roc/expect/"
t = rd(p + "stdout")
assert t.count("check: passed\n") == 1
wr(p + "stdout", t.replace("check: passed\n", "note: %s\nnote: %s\ncheck: passed\n" % (J, P)))
edit_calls(p + "calls.log", lambda i, r: r + send_block([HA], 0, totals=False))
