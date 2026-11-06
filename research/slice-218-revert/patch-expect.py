#!/usr/bin/env python3
"""Slice 218, test agent. Patches the expected files of the L2 cases `share/sh70` to `sh75` by hand to the readings of docs/slices/218-smoke-builds.md.
The baseline of each case (the current code, no smoke build) came from `UPDATE=1`; this script inserts the smoke lines (TW21). Run once from the repo root, after the baseline."""
import json, os, re, sys

ROOT = "tests/commands/cases/share"
DB = "$HOME/.cache/roc/talon/compat.db"
TMP = "$HOME/.cache/roc/talon/tmp/0123456789abcdef"
NT = "nightly-2026-10-14-38a3029"
PF = "9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK"
OPEN = f"{DB} busy_ms=5000 format=1"
ENV = "    env XDG_CACHE_HOME=$HOME/.cache ROC_CACHE_DIR=$HOME/.cache/roc TALON_IN_PROXY=1"

pre = [f"db_query {OPEN} smoke=1", "platform", f"db_query {OPEN} pinned=1"]
build = ["random", f"make_dirs {TMP}", f"write_atomic {TMP}/main.roc", "probes 1",
         f"  probe {TMP} {NT} /fake/bin/roc build --target=x64musl main.roc --output={TMP}/tln-probe.out --no-cache timeout=7", ENV]
write = [f"db_write {OPEN} smoke=1"]
queue = ["platform", f"db_query {OPEN} pinned=1", "clock", f"db_write {OPEN} queue=1 cap=10000"]
queue_none = ["platform", f"db_query {OPEN} pinned=1", "clock"]
delete = f"delete {TMP}"

BLOCK = {
    "pass": pre + build + write + [delete] + queue,
    "pass2": pre + build + write + [delete] + queue,
    "fail": pre + build + write + [delete] + queue,
    "machine": pre + build + [delete],
    "hang": pre + build + write + [delete] + queue_none,
    "done": pre,
    "bot": pre,
}

def runs_of(lines):
    out, cur = [], None
    for l in lines:
        if l == "args":
            cur = []
            out.append(cur)
        cur.append(l)
    return out

def send_block_of_A():
    """The send of run 1 of sh70 (after its patch): from `db_query queue_rows` to the last `unlock`."""
    lines = open(f"{ROOT}/sh70-smoke-build/expect/calls.log").read().split("\n")[:-1]
    run1 = runs_of(lines)[0]
    i = run1.index(f"db_query {OPEN} queue_rows")
    return run1[i:]

def patch_calls(case, kinds, row_result=None):
    p = f"{ROOT}/{case}/expect/calls.log"
    lines = open(p).read().split("\n")
    assert lines[-1] == ""
    lines = lines[:-1]
    runs = runs_of(lines)
    assert len(runs) == len(kinds), (case, len(runs), kinds)
    out = []
    for run, kind in zip(runs, kinds):
        i = run.index(delete)
        block = BLOCK[kind]
        # The delete of the main temp dir stays where it is; the smoke block comes after it. The blocks that have their own delete drop it from the block.
        extra = [l for l in block if l != delete] if delete in block else block
        run = run[: i + 1] + extra + run[i + 1 :]
        if kind in ("pass", "fail", "pass2"):
            # the smoke temp dir is deleted after the smoke row is written: the block has `delete` after `write`
            j = run.index(f"db_write {OPEN} smoke=1")
            run = run[: j + 1] + [delete] + run[j + 1 :]
        if kind == "machine":
            run = run  # no smoke write: the delete of the smoke temp dir follows the probe
            j = max(k for k, l in enumerate(run) if l.startswith("    env XDG_CACHE_HOME") )
            run = run[: j + 1] + [delete] + run[j + 1 :]
        if kind == "hang":
            j = run.index(f"db_write {OPEN} smoke=1")
            run = run[: j + 1] + [delete] + run[j + 1 :]
        if kind == "pass2":
            # run 2 of sh74: the queue has the new smoke row only, so the send is the one of sh70 run 1 with a body of 1 row
            i = max(k for k, l in enumerate(run) if l == f"db_query {OPEN} queue_rows")
            send = send_block_of_A()
            body = '  <body> {"rows":[{"hash":"%s","nightly":"%s","result":"pass","target":"x64musl"}],"talon_version":"0.0.1"}' % (PF, NT)
            send = [body if l.startswith("  <body> ") else l.replace("unqueue=4", "unqueue=1") for l in send]
            run = run[:i] + send
        out += run
    text = "\n".join(out) + "\n"
    if row_result:
        old = '{"hash":"HA","nightly":"%s","result":"pass","target":"any"}' % NT
        a = re.search(r'<body> \{"rows":\[(.*)\],"talon_version"', text)
        assert a, case
        rows = a.group(1)
        new_row = '{"hash":"%s","nightly":"%s","result":"%s","target":"x64musl"}' % (PF, NT, row_result)
        text = text.replace(rows, rows + "," + new_row, 1)
        text = text.replace("unqueue=3", "unqueue=4", 1)
    open(p, "w").write(text)

def patch_tree(case, rows=None, totals=None):
    p = f"{ROOT}/{case}/expect/tree.diff"
    text = open(p).read()
    if rows:
        body = "".join(f"+{r}\n" for r in rows)
        sec = f"--- home/.cache/roc/talon/smoke.tsv\n+++ home/.cache/roc/talon/smoke.tsv\n@@ -0,0 +1{'' if len(rows) == 1 else ',' + str(len(rows))} @@\n{body}"
        marker = "--- home/.local/share/talon/share.json\n"
        assert marker in text
        text = text.replace(marker, sec + marker, 1)
    if totals:
        text = text.replace('"sent":3,"counted":3,"first":2', '"sent":4,"counted":4,"first":3', 1)
    open(p, "w").write(text)

def set_written(case, written, first):
    p = f"{ROOT}/{case}/fx/http/127.0.0.1%3A9/v1/compat.POST"
    open(p, "w").write('{"written":%d,"first":%d,"skipped":[]}' % (written, first))

def line(outcome):
    return f"{PF}\t{NT}\tx64musl\t{outcome}"

which = sys.argv[1:]
if not which or "A" in which:
    set_written("sh70-smoke-build", 4, 3)
    patch_calls("sh70-smoke-build", ["pass", "done"], "pass")
    patch_tree("sh70-smoke-build", [line("pass")], True)
if not which or "B" in which:
    # round 2 (Q553): the command is `verify --no-probe`: no unit probe, so the queue has the row HA and the smoke row only
    set_written("sh71-smoke-build-skipped", 2, 1)
    patch_calls("sh71-smoke-build-skipped", ["pass"], "pass")
    q = f"{ROOT}/sh71-smoke-build-skipped/expect/calls.log"
    t = open(q).read().replace("unqueue=1", "unqueue=2")
    open(q, "w").write(t)
    patch_tree("sh71-smoke-build-skipped", [line("pass")], False)
    q = f"{ROOT}/sh71-smoke-build-skipped/expect/tree.diff"
    t = open(q).read()
    import re as _re
    t = _re.sub(r'(\+\{"format":1,"id":"[0-9a-f]+",)"sent":\d+,"counted":\d+,"first":\d+', r'\1"sent":2,"counted":2,"first":1', t, count=1)
    open(q, "w").write(t)
if not which or "C" in which:
    patch_calls("sh72-smoke-bot-row", ["bot"])
if not which or "D" in which:
    set_written("sh73-smoke-fail", 4, 3)
    patch_calls("sh73-smoke-fail", ["fail"], "fail")
    patch_tree("sh73-smoke-fail", [line("fail")], True)
if not which or "E" in which:
    patch_calls("sh74-smoke-machine-error", ["machine", "pass2"])
    patch_tree("sh74-smoke-machine-error", [line("pass")], True)
if not which or "G" in which:
    patch_calls("sh76-smoke-hang", ["hang"])
    patch_tree("sh76-smoke-hang", [line("hang")], False)

# Round 2 (Design Q549): sh78 = the world of sh60 (the tuple moves the platform), the delete of the temp dirs is denied (`fx/delete`), so the smoke `main.roc` stays and shows in tree.diff.
def patch_sh78():
    import copy
    case = "sh78-smoke-moved-platform"
    global BLOCK
    BLOCK = {k: [l.replace("timeout=7", "timeout=30") for l in v] for k, v in BLOCK.items()}
    patch_calls(case, ["pass"], "pass")
    p = f"{ROOT}/{case}/expect/tree.diff"
    text = open(p).read()
    text = text.replace('"sent":3,"counted":4,"first":3', '"sent":4,"counted":4,"first":3', 1)
    url = f"https://github.com/acme/pfx/releases/download/0.1.1/{PF}.tar.zst"
    app = ['app [main!] {', f'\tpf: platform "{url}",', '}', '', 'main! = || crash "talon smoke test"']
    sec = f"--- home/.cache/roc/talon/smoke.tsv\n+++ home/.cache/roc/talon/smoke.tsv\n@@ -0,0 +1 @@\n+{line('pass')}\n"
    sec += "--- home/.cache/roc/talon/tmp/0123456789abcdef/main.roc\n+++ home/.cache/roc/talon/tmp/0123456789abcdef/main.roc\n@@ -0,0 +1,5 @@\n" + "".join("+" + l + "\n" for l in app)
    marker = "--- home/.local/share/talon/share.json\n"
    text = text.replace(marker, sec + marker, 1)
    open(p, "w").write(text)

if "H" in which:
    patch_sh78()

# Round 3: sh79 = `update --dry-run` (the world of sh49, run 1 only) with a build step: the smoke block of sh70 (timeout 30, no config), 4 rows in the POST.
def patch_sh79():
    global BLOCK
    BLOCK = {k: [l.replace("timeout=7", "timeout=30") for l in v] for k, v in BLOCK.items()}
    patch_calls("sh79-smoke-update", ["pass"], "pass")
    patch_tree("sh79-smoke-update", [line("pass")], False)
    q = f"{ROOT}/sh79-smoke-update/expect/tree.diff"
    t = open(q).read()
    t = re.sub(r'(\+\{"format":1,"id":"[0-9a-f]+",)"sent":\d+,"counted":\d+,"first":\d+', r'\1"sent":4,"counted":4,"first":3', t, count=1)
    open(q, "w").write(t)

if "I" in which:
    patch_sh79()
