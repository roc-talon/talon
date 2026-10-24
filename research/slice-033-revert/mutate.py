#!/usr/bin/env python3
"""Revert check of slice 033 (TW12), by the test agent. Each mutation is a small change of the private reference
(research/slice-033-revert/reference/Epochs.roc). One at a time: put the changed text in cli/lib/Epochs.roc (a copy over the file, never a delete),
`roc check cli/main.roc`-style compile of cli/lib/main.roc (0 errors and 0 warnings needed), then the L0 file and the L1 step. At the end the reference is copied back.
Usage: mutate.py [id ...]   (no id: all)   Result lines: <id> <what> L0=caught|MISSED L1=caught|MISSED
"""
import os, subprocess, sys, shutil

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
REF = os.path.join(ROOT, "research/slice-033-revert/reference/Epochs.roc")
DST = os.path.join(ROOT, "cli/lib/Epochs.roc")
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, ROC=ROC)

PASS_ASSET = "domain.keep_if(|r| match r.asset {\n\t\t\tOk(_) => Bool.True\n\t\t\tErr(_) => Bool.False\n\t\t}).map(|r| { from: r.id, to: r.id })"

# (id, what, old, new). `old` must occur exactly once in the reference.
M = [
    ("m01", "partition: `to` is empty", "{ from: r.id, to: r.id }", "{ from: r.id, to: \"\" }"),
    ("m02", "partition: reversed order", "domain.map(|r| { from: r.id, to: r.id })", "domain.rev().map(|r| { from: r.id, to: r.id })"),
    ("m03", "partition: releases with no asset left out (R-EP11)", "domain.map(|r| { from: r.id, to: r.id })", PASS_ASSET),
    ("m04", "infer: a build row counts as a unit fact (target not read)", "f.target == \"any\"", "f.target != \"zzz\""),
    ("m05", "infer: a fault counts as a code result (fail)", "_ => Err(NoCode)\n\t\t\t\t}\n\t\t\t\tErr(_) => Err(NoCode)", "_ => Ok((Fail, []))\n\t\t\t\t}\n\t\t\t\tErr(_) => Err(NoCode)"),
    ("m06", "infer: a pair with a fault only counts as a gap", "if !mine.any(|(_, i)| i == at) {", "if !mine.any(|(f, i)| i == at and (f.outcome == Pass or f.outcome == Fail)) {"),
    ("m07", "case (b): no result after counts as a result", "Ok((ja, xa, ma)) => if xb == xa [(jb, xb, mb), (ja, xa, ma)] else []\n\t\t\t\t\t\t\tErr(_) => []", "Ok((ja, xa, ma)) => if xb == xa [(jb, xb, mb), (ja, xa, ma)] else []\n\t\t\t\t\t\t\tErr(_) => [(jb, xb, mb)]"),
    ("m08", "case (b): the farthest result before, not the nearest", "before = seen(idx.keep_if(|j| j < at)).last()", "before = seen(idx.keep_if(|j| j < at)).first()"),
    ("m09", "conflict: pass or fail both give a result (pass wins)", "if has_pass != has_fail {\n\t\t\t\t\t\tx = if has_pass Pass else Fail", "if has_pass or has_fail {\n\t\t\t\t\t\tx = if has_pass Pass else Fail"),
    ("m10", "conflict: fail wins", "if has_pass != has_fail {\n\t\t\t\t\t\tx = if has_pass Pass else Fail", "if has_pass or has_fail {\n\t\t\t\t\t\tx = if has_fail Fail else Pass"),
    ("m11", "case (a) left out", "all = same_epoch.concat(between)", "all = between.concat(same_epoch.take_first(0))"),
    ("m12", "case (b) left out", "all = same_epoch.concat(between)", "all = same_epoch.concat(between.take_first(0))"),
    ("m13", "from: the order of the cases, with repeats", "from = idx.keep_if(|j| src.any(|(jj, _, _)| jj == j)).map(|j| ids.get(j) ?? \"\")", "from = src.map(|(j, _, _)| ids.get(j) ?? \"\")"),
    ("m14", "fail: no modules", "modules = Text.sorted_unique(src.join_map(|(_, _, m)| m))", "modules = []"),
    ("m15", "fail: modules not sorted, with repeats", "modules = Text.sorted_unique(src.join_map(|(_, _, m)| m))", "modules = src.join_map(|(_, _, m)| m)"),
    ("m16", "order: the hashes in the order of the facts", "hashes = Text.sorted_unique(checks.map(|(f, _)| f.hash))", "hashes = checks.map(|(f, _)| f.hash).fold([], |a, h| if a.contains(h) a else a.append(h))"),
    ("m17", "order: the releases of a hash in reverse", "for at in idx {", "for at in idx.rev() {"),
    ("m18", "a release that no interval holds belongs to all of D", "?? (at, at)", "?? (0, 99)"),
    ("m19", "case (a): the first release of the epoch is not a source", "span.0 <= j and j <= span.1", "span.0 < j and j <= span.1"),
    ("m20", "case (b): the nearest fact (a fault too) blocks, not the nearest code result",
     "before = seen(idx.keep_if(|j| j < at)).last()",
     "before = match idx.keep_if(|j| j < at and mine.any(|(_, i)| i == j)).last() {\n\t\t\t\t\t\tOk(j) => seen([j]).first()\n\t\t\t\t\t\tErr(_) => Err(ListWasEmpty)\n\t\t\t\t\t}"),
    ("m21", "case (a): a fault in the epoch is a source (as a pass)", "Fail => Ok((Fail, f.modules))\n\t\t\t\t\t_ => Err(NoCode)", "Fail => Ok((Fail, f.modules))\n\t\t\t\t\tHang => Ok((Pass, []))\n\t\t\t\t\t_ => Err(NoCode)"),
    ("m22", "epochs: crash facts dropped before infer (a crash pair becomes a gap)", "inferred: Epochs.infer({ domain, epochs: parts, facts })", "inferred: Epochs.infer({ domain, epochs: parts, facts: facts.keep_if(|f| f.outcome != Crash) })"),
    ("m24", "fail: the modules of the first source only (Q1)", "modules = Text.sorted_unique(src.join_map(|(_, _, m)| m))", "modules = match src.first() {\n\t\t\t\t\t\t\tOk((_, _, m)) => m\n\t\t\t\t\t\t\tErr(_) => []\n\t\t\t\t\t\t}"),
    ("m25", "fail: the modules of the last source only (Q1)", "modules = Text.sorted_unique(src.join_map(|(_, _, m)| m))", "modules = match src.last() {\n\t\t\t\t\t\t\tOk((_, _, m)) => m\n\t\t\t\t\t\t\tErr(_) => []\n\t\t\t\t\t\t}"),
    ("m23", "infer reads only the first 8 facts", "checks = run.facts", "checks = run.facts.take_first(8)"),
]


def sh(cmd, **kw):
    return subprocess.run(cmd, cwd=ROOT, env=ENV, capture_output=True, text=True, **kw)


def main():
    want = sys.argv[1:]
    ref = open(REF).read()
    out = []
    try:
        for mid, what, old, new in M:
            if want and mid not in want:
                continue
            if ref.count(old) != 1:
                print(f"{mid} SKIP: old text occurs {ref.count(old)} times")
                continue
            open(DST, "w").write(ref.replace(old, new))
            chk = sh([ROC, "check", "cli/lib/main.roc"])
            if chk.returncode != 0:
                print(f"{mid} {what}: DOES NOT COMPILE\n{chk.stdout[-600:]}{chk.stderr[-300:]}")
                continue
            l0 = sh([ROC, "test", "tests/unit/epochs.roc", "--no-cache"])
            l1 = sh(["scripts/test.sh", "l1"])
            r0 = "caught" if l0.returncode != 0 else "MISSED"
            r1 = "caught" if l1.returncode != 0 else "MISSED"
            line = f"{mid} {what}: L0={r0} L1={r1}"
            if l1.returncode != 0:
                msg = [l for l in l1.stdout.splitlines() if "crashed" in l or l.startswith("[roc") or "R-EP" in l]
                line += "  " + (msg[0].strip() if msg else "")
            print(line, flush=True)
            out.append(line)
    finally:
        shutil.copyfile(REF, DST)
    same = open(DST).read() == ref
    print("reference restored:", same)


main()
