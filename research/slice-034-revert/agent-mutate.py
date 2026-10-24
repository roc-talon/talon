#!/usr/bin/env python3
"""Revert check of slice 034 by the code agent (TW12). Each mutation is a small change of the final code
(research/slice-034-revert/code-final/packages/resolve/{Domain,Solver}.roc). One at a time: the code-final copy goes over packages/resolve/
at the start of each mutation, then the changed text goes over one file. `roc check` (0 errors, 0 warnings), then the 2 L0 files,
then the l1 step only when L0 does not catch it. A run that does not end is stopped by the timeout and counts as caught (the search must end).
Usage: agent-mutate.py [id ...]   (no id: all)   L0ONLY=1 skips l1.
"""
import os, subprocess, sys, shutil

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FINAL = os.path.join(ROOT, "research/slice-034-revert/code-final/packages/resolve")
DST = os.path.join(ROOT, "packages/resolve")
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, ROC=ROC)
T0 = int(os.environ.get("MUT_TIMEOUT", "30"))
T1 = int(os.environ.get("MUT_TIMEOUT_L1", "100"))
FILES = ("Domain.roc", "Solver.roc")

# (id, file, what, old, new). `old` must occur exactly once in the final file.
M = [
    ("m01", "Domain.roc", "Highest and Lowest swapped", "Before => if strategy == Highest After else Before\n\tAfter => if strategy == Highest Before else After", "Before => if strategy == Highest Before else After\n\tAfter => if strategy == Highest After else Before"),
    ("m02", "Domain.roc", "a tie is in the reverse byte order", "Same => bytes(a.id.to_utf8(), b.id.to_utf8())", "Same => bytes(b.id.to_utf8(), a.id.to_utf8())"),
    ("m04", "Domain.roc", "ranges: any in place of all", "admits = |ranges, v| ranges.all(", "admits = |ranges, v| ranges.is_empty() or ranges.any("),
    ("m05", "Domain.roc", "a yanked release is a value", "(is_header(q, c) or (!c.yanked and !hidden(q, c)))", "(is_header(q, c) or !hidden(q, c))"),
    ("m07", "Domain.roc", "young: >= (exactly min_age old is hidden)", "c.published_at + q.rules.min_age > q.rules.now", "c.published_at + q.rules.min_age >= q.rules.now"),
    ("m08", "Domain.roc", "young: not applied", "c.published_at + q.rules.min_age > q.rules.now", "c.published_at + q.rules.min_age > q.rules.now + 1000000000000"),
    ("m09", "Domain.roc", "late: >= (a release at the snapshot time is hidden)", "Ok(time) => c.published_at > time", "Ok(time) => c.published_at >= time"),
    ("m10", "Domain.roc", "snapshot ignored", "Ok(time) => c.published_at > time", "Ok(_) => Bool.False"),
    ("m11", "Domain.roc", "the header value is hidden when young or late", "(is_header(q, c) or (!c.yanked and !hidden(q, c)))", "((is_header(q, c) and !hidden(q, c)) or (!c.yanked and !hidden(q, c)))"),
    ("m12", "Domain.roc", "the header value is not added when the list lacks it", "q.candidates else q.candidates.append({ id: cur.id, version: cur.version, published_at: 0, yanked: Bool.False })", "q.candidates else q.candidates.take_first(99)"),
    ("m13", "Domain.roc", "a range does not exclude the header value", "admits(q.ranges, v) and (", "(is_header(q, c) or admits(q.ranges, v)) and ("),
    ("m14", "Domain.roc", "a named version is never exempt", "Ok(version) => version == c.version", "Ok(version) => version == \"0\""),
    ("m15", "Domain.roc", "a named version that is yanked is a value", "(is_header(q, c) or (!c.yanked and !hidden(q, c)))", "(is_header(q, c) or (q.named.map_ok(|n| n == c.version) ?? Bool.False) or (!c.yanked and !hidden(q, c)))"),
    ("m16", "Domain.roc", "a named version is exempt from the age only (not the snapshot)", "!named and (c.published_at + q.rules.min_age > q.rules.now or late)", "(!named and c.published_at + q.rules.min_age > q.rules.now) or late"),
    ("m17", "Domain.roc", "the version order reads the minor and patch only", "match va.order_relative_to(vb) {", "match Semver.new(0, va.minor(), va.patch()).order_relative_to(Semver.new(0, vb.minor(), vb.patch())) {"),
    ("m18", "Solver.roc", "a Package slot takes an App release", "(Package, Package) => Bool.True", "(Package, App) => Bool.True\n\t\t(Package, Package) => Bool.True"),
    ("m20", "Solver.roc", "a release with no fact is not fit", "\tErr(_) => Bool.True\n}", "\tErr(_) => Bool.False\n}"),
    ("m21", "Solver.roc", "dep: the limit itself is no value", "x.ver.order_relative_to(need) == Before", "x.ver.order_relative_to(need) != After"),
    ("m22", "Solver.roc", "a dep on the own group is read", "k != i and other.group == dep.group", "other.group == dep.group and k >= 0"),
    ("m24", "Solver.roc", "a limit above all values is not read", "if below.is_empty() Err(NoLimit)", "if below.is_empty() or below.len() == other.vals.len() Err(NoLimit)"),
    ("m25", "Solver.roc", "the deps are not read", "dep_incs(vars, i, p, f).concat(", "dep_incs(vars, i, p, f).take_first(0).concat("),
    ("m26", "Solver.roc", "the platform is not read", ".concat(pf_incs(vars, plats, i, p, f))", ".concat(pf_incs(vars, plats, i, p, f).take_first(0))"),
    ("m27", "Solver.roc", "the platform check holds with 2 platform slots (the first)", "(Ok(url), [pl]) =>", "(Ok(url), [pl, ..]) =>"),
    ("m28", "Solver.roc", "the release of the platform slot is checked against its own pf", "if pl == i or others.is_empty()", "if others.is_empty()"),
    ("m29", "Solver.roc", "the platform check has the wrong sense", "others = places(pv, |x| x.c.id != url)", "others = places(pv, |x| x.c.id == url)"),
    ("m30", "Solver.roc", "the decision takes the worst value", "(state.get(v) ?? []).first() ?? 0", "(state.get(v) ?? []).last() ?? 0"),
    ("m31", "Solver.roc", "learn only the last decision (unsound)", "decisions.take_first(c.depth).map(", "decisions.take_first(c.depth).take_last(1).map("),
    ("m32", "Solver.roc", "go back to the same decisions (no end)", "init, decisions.take_first(c.depth - 1))", "init, decisions.take_first(c.depth))"),
    ("m34", "Solver.roc", "the depth of a clash is one too low", "staged(k + 1, propagate", "staged(k, propagate"),
    ("m35", "Solver.roc", "the conflicts of the caller are not read", "conflict_incs(vars, req.conflicts)", "conflict_incs(vars, [])"),
    ("m36", "Solver.roc", "the sign of a term is swapped", "== (t.sign == In)", "== (t.sign == NotIn)"),
    ("m37", "Solver.roc", "a conflict with an unknown name applies without that term", "match terms.map_try(|t| lit_of(vars, t)) {", "match terms.keep_if(|t| vars.any(|x| x.name == t.name)).map_try(|t| lit_of(vars, t)) {"),
    ("m38", "Solver.roc", "the terms of one variable are not joined (the last wins)", "if k == j { v: a.v, set: a.set.keep_if(|x| l.set.contains(x)) } else a)", "if k == j l else a)"),
    ("m39", "Solver.roc", "a term with no value still gives an incompatibility", "if joined.any(|l| l.set.is_empty()) Err(Never) else Ok(joined)", "Ok(joined)"),
    ("m40", "Solver.roc", "unit propagation off (no end)", "Moved(next) => propagate(incs, next)", "Moved(_) => Stable(state)"),
    ("m41", "Solver.roc", "a false term does not stop a unit propagation", "if classes.any(|(_, c)| c == Contra) {", "if classes.len() > 99 {"),
    ("m42", "Solver.roc", "all terms true is no clash", "[] => Stuck(inc.map(|l| l.v))", "[] => Quiet"),
    ("m43", "Solver.roc", "a term is true when one place is in the set", "if s.all(|x| l.set.contains(x)) {", "if s.any(|x| l.set.contains(x)) {"),
    ("m45", "Solver.roc", "Need names all chosen ids", "picked.keep_if(|(_, c)| !facts.contains(c.id))", "picked.keep_if(|(_, c)| !facts.contains(c.id) or c.id != \"\")"),
    ("m46", "Solver.roc", "Need names the first missing id only", "Need(missing.map(|id| Header(id)))", "Need(missing.take_first(1).map(|id| Header(id)))"),
    ("m47", "Solver.roc", "Done with one fact missing", "if missing.is_empty() {", "if missing.len() < 2 {"),
    ("m48", "Solver.roc", "Need in the reverse order", "Need(missing.map(|id| Header(id)))", "Need(missing.rev().map(|id| Header(id)))"),
    ("m49", "Solver.roc", "Need names a release twice", "if acc.contains(id) acc else acc.append(id)", "acc.append(id)"),
    ("m51", "Solver.roc", "the strategy is ignored", "var_of(req.rules, facts, slot)", "var_of({ ..req.rules, strategy: Highest }, facts, slot)"),
    ("m52", "Solver.roc", "the header value is not passed to the domain", "current: slot.current, named", "current: Err(None), named"),
    ("m53", "Solver.roc", "the ranges are not passed to the domain", "ranges: slot.ranges, current", "ranges: [], current"),
    ("m54", "Solver.roc", "the named version is not passed", "named: slot.named, rules })", "named: Err(None), rules })"),
    ("m56", "Solver.roc", "the names of a Fail are the other slots", "keep_if(|(_, i)| at.contains(i))", "keep_if(|(_, i)| !at.contains(i))"),
]


def sh(cmd, timeout):
    try:
        return subprocess.run(cmd, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        class R:
            returncode = 124
            stdout = "TIMEOUT"
            stderr = ""
        return R()


def restore():
    for f in FILES:
        shutil.copyfile(os.path.join(FINAL, f), os.path.join(DST, f))


def main():
    want = sys.argv[1:]
    refs = {f: open(os.path.join(FINAL, f)).read() for f in FILES}
    try:
        for mid, fname, what, old, new in M:
            if want and mid not in want:
                continue
            restore()
            ref = refs[fname]
            if ref.count(old) != 1:
                print(f"{mid} SKIP: old text occurs {ref.count(old)} times", flush=True)
                continue
            open(os.path.join(DST, fname), "w").write(ref.replace(old, new))
            chk = sh([ROC, "check", "packages/resolve/main.roc"], 60)
            if chk.returncode != 0:
                print(f"{mid} {what}: DOES NOT COMPILE\n{chk.stdout[-500:]}{chk.stderr[-300:]}", flush=True)
                continue
            l0d = sh([ROC, "test", "packages/resolve/tests/domain.roc", "--no-cache"], T0)
            l0s = sh([ROC, "test", "packages/resolve/tests/solver.roc", "--no-cache"], T0)
            if l0d.returncode == 124 or l0s.returncode == 124:
                l0 = "caught(timeout)"
            elif l0d.returncode != 0 or l0s.returncode != 0:
                l0 = "caught"
            else:
                l0 = "MISSED"
            if l0 != "MISSED" or os.environ.get("L0ONLY"):
                print(f"{mid} {what}: L0={l0}", flush=True)
                continue
            l1 = sh(["scripts/test.sh", "l1"], T1)
            r1 = "caught" if l1.returncode != 0 else "MISSED"
            line = f"{mid} {what}: L0={l0} L1={r1}"
            if l1.returncode != 0:
                msg = [x for x in l1.stdout.splitlines() if "crashed" in x or "R-" in x]
                line += "  " + (msg[0].strip()[:150] if msg else "")
            print(line, flush=True)
    finally:
        restore()


main()
