#!/usr/bin/env python3
"""Revert check of slice 035 (TW12), test agent. Small changes of the private reference (reference/packages/resolve/Solver.roc), one at a time.
Each change is put over packages/resolve/Solver.roc, compiled with `roc check packages/resolve/main.roc` (0 errors and 0 warnings), then the 2 L0 files that run the solver (conflicts.roc, solver.roc),
then, only when L0 passes, the L1 target (build with --fuzz and 20000 runs, seed 1). A run that does not end is stopped by a timeout (a change that makes the search not end is caught).
At the end the stub (stubs/Solver.roc) is copied back over the package. Usage: mutate.py [id ...] (default: all). The log is printed; redirect it."""
import re, os, subprocess, shutil, sys, time
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
REV = os.path.join(ROOT, "research/slice-035-revert")
REF = os.path.join(REV, "reference/packages/resolve/Solver.roc")
STUB = os.path.join(REV, "stubs/Solver.roc")
DST = os.path.join(ROOT, "packages/resolve/Solver.roc")
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
SCR = "/tmp/claude-1000/-home-george-dev-Karakatiza666-talon/50006c73-0c1a-496a-8ab0-5dde076210ac/scratchpad/l1m"
ENV = dict(os.environ, ROC=ROC)

# (id, what, old text (once in the reference), new text)
M = [
    # the search and the conflict resolution
    ("c01", "the decision takes the last place of the variable", "left: [(state.get(v) ?? []).first() ?? 0]", "left: [(state.get(v) ?? []).last() ?? 0]"),
    ("c02", "the decision takes the last variable that is open", "match state.find_first_index(|s| s.len() > 1) {\n\t\t\tOk(v) => search(", "match state.map_with_index(|s, i| (s, i)).keep_if(|(s, _)| s.len() > 1).last().map_ok(|(_, i)| i) {\n\t\t\tOk(v) => search("),
    ("c03", "resolution forgets the part of the cause (the union is the term alone)", "cs = cause.lits.find_first(|x| x.v == best.v).map_ok(|x| x.set) ?? []", "cs = cause.lits.find_first(|x| x.v == best.v).map_ok(|x| x.set.take_first(0)) ?? []"),
    ("c04", "the level to go back to is the lowest level of the other satisfiers", "below = others.map(|(_, q)| at(q)).fold(0, |m, x| if x > m x else m)", "below = others.map(|(_, q)| at(q)).fold(99, |m, x| if x < m x else m) % 99"),
    ("c05", "a term that is true in each state is not dropped (normal)", "join_lits(inc.lits).keep_if(|l| !(init.get(l.v) ?? []).all(|x| l.set.contains(x))).sort_with", "join_lits(inc.lits).keep_if(|l| (init.get(l.v) ?? []).len() > 0 or Bool.True).sort_with"),
    ("c06", "2 terms of one variable are joined by union", "a.set.keep_if(|x| l.set.contains(x))", "a.set.concat(l.set.keep_if(|x| !a.set.contains(x)))"),
    ("c07", "a conflict (all terms true) is ignored by propagation", "Stuck => Break(Conflict(i))", "Stuck => Continue(Quiet)"),
    ("c08", "a satisfier at the latest level is learned at once (no resolution)", "From(ci) => if below < e.level {", "From(ci) => if below < 99 {"),
    ("c09", "the resolution step keeps the first term of the cause instead of its terms (rest of the cause lost)", ".concat(cause.lits.keep_if(|x| x.v != best.v)).append({ v: best.v, set: union })", ".append({ v: best.v, set: union })"),
    ("c10", "the new trail keeps all levels after a learn", "Learn(r) => search(r.incs, init, c.trail.keep_if(|e| e.level <= r.keep))", "Learn(r) => search(r.incs, init, c.trail.keep_if(|e| e.level <= r.keep + 1))"),
    ("c11", "the learned incompatibility is not kept (the list before the resolution)", "Learn(r) => search(r.incs, init, c.trail", "Learn(r) => search(incs, init, c.trail"),
    # the explanation
    ("w01", "the explanation has the final step only", "cone = cone_of(incs, [final], []).sort_with", "cone = [final].sort_with"),
    ("w02", "Derived names the step 0 twice", "Derived(a, b) => Derived(rank(a), rank(b))", "Derived(a, b) => Derived(rank(a) * 0, rank(b) * 0)"),
    ("w03", "the terms are NotIn", "ids: vars.get(l.v).map_ok(|vr| l.set.keep_oks(|p| vr.vals.get(p).map_ok(|x| x.c.id))) ?? [], sign: In", "ids: vars.get(l.v).map_ok(|vr| l.set.keep_oks(|p| vr.vals.get(p).map_ok(|x| x.c.id))) ?? [], sign: NotIn"),
    ("w04", "the steps are in the reverse order", "cone = cone_of(incs, [final], []).sort_with(|a, b| if a < b Before else if a > b After else Same)", "cone = cone_of(incs, [final], []).sort_with(|a, b| if a < b After else if a > b Before else Same)"),
    ("w05", "the explanation uses the first incompatibility as final", "NoTuple(r) => NoTuple(why_of(vars, r.incs, r.final))", "NoTuple(r) => NoTuple(why_of(vars, r.incs, 0))"),
    ("w06", "the given conflicts are not sorted (R-DT2)", ".keep_oks(|inc| normal(init, inc)).sort_with(|a, b| cmp_lits(a.lits, b.lits))", ".keep_oks(|inc| normal(init, inc))"),
    ("w07", "the given conflicts are sorted before they are normalized (R-DT2)", "given = conflict_lits(vars, conflicts).map(|lits| { lits, cause: Given }).keep_oks(|inc| normal(init, inc)).sort_with(|a, b| cmp_lits(a.lits, b.lits))", "given = conflict_lits(vars, conflicts).map(|lits| { lits, cause: Given }).sort_with(|a, b| cmp_lits(a.lits, b.lits)).keep_oks(|inc| normal(init, inc))"),
    ("w08", "the cause of a dep names no release", "cause: Dep({ id, group: dep.group, version: dep.version })", "cause: Dep({ id: \"x${id}\", group: dep.group, version: dep.version })"),
    ("w09", "the cause of a platform names another url", "cause: Pf({ id: f.id, pf: url })", "cause: Pf({ id: f.id, pf: f.id })"),
    ("w10", "a slot with no value names no slot", "cause: NoValue(v.name)", "cause: NoValue(\"${v.name}x\")"),
    # the probe facts (R-EP7)
    ("p01", "a fail with no module is not hard", "hits = |c| c.modules.is_empty() or c.modules.any(|m| used.contains(m))", "hits = |c| c.modules.any(|m| used.contains(m))"),
    ("p02", "each fail touches", "hits = |c| c.modules.is_empty() or c.modules.any(|m| used.contains(m))", "hits = |c| c.modules.is_empty() or c.modules.any(|m| used.contains(m)) or Bool.True"),
    ("p03", "the inferred fails count in RealOnly", "c.outcome == Fail and hits(c) and (c.source == Real or mode == All)\n\t\t\tErr(_) => Bool.False", "c.outcome == Fail and hits(c)\n\t\t\tErr(_) => Bool.False"),
    ("p04", "a fault is not an interval", "if (c.outcome == Hang or c.outcome == Crash) and c.source == Real Ok((p, p, Fault))", "if (c.outcome == Hang or c.outcome == Crash) and c.source == Real and Bool.False Ok((p, p, Fault))"),
    ("p05", "the run starts one place too early", "lo = at.keep_if(|(b, q)| q < p and !b).last().map_ok(|(_, q)| q + 1) ?? 0", "lo = at.keep_if(|(b, q)| q < p and !b).last().map_ok(|(_, q)| q) ?? 0"),
    ("p06", "the run ends one place too late", "hi = at.keep_if(|(b, q)| q > p and !b).first().map_ok(|(_, q)| q - 1) ?? (blocks.len() - 1)", "hi = at.keep_if(|(b, q)| q > p and !b).first().map_ok(|(_, q)| q) ?? (blocks.len() - 1)"),
    ("p07", "the run does not stop at a pass", "lo = at.keep_if(|(b, q)| q < p and !b).last().map_ok(|(_, q)| q + 1) ?? 0", "lo = 0"),
    ("p08", "the run is the seed alone", "(lo, hi, Fail)\n}", "(p + 0 * lo, p + 0 * hi, Fail)\n}"),
    ("p09", "the modules are not cut to the used ones", "c.modules.keep_if(|m| used.contains(m))", "c.modules"),
    ("p10", "the inferred compilers are not named", "inferred: members.keep_if(|(n, _)| cell_of(n).map_ok(|c| c.source == Inferred) ?? Bool.False).map(|(n, _)| n),", "inferred: [],"),
    ("p11", "a fault names modules", "modules: if kind == Fault [] else", "modules: if kind == Fault [\"x\"] else"),
    ("p12", "the first and last compiler of the interval are swapped", "from: run.ids.first() ?? \"\", to: run.ids.last() ?? \"\"", "from: run.ids.last() ?? \"\", to: run.ids.first() ?? \"\""),
    ("p13", "no used modules (R-UM1)", "used = compat.used.find_first(|u| u.id == h).map_ok(|u| u.modules) ?? []", "used = []"),
    ("p14", "the probe facts of a platform slot are not read", "keep_if(|(v, _)| v.kind != Compiler).join_map(\n\t\t\t|(v, i)| v.vals", "keep_if(|(v, _)| v.kind == Package).join_map(\n\t\t\t|(v, i)| v.vals"),
    # the compiler slot
    ("r01", "the compiler order follows the wrong strategy", "picked = if rules.strategy == Lowest ordered else ordered.rev()", "picked = if rules.strategy == Lowest ordered.rev() else ordered"),
    ("r02", "a candidate that is not in D is a value", "ordered = domain.keep_if(|id| slot.candidates.any(|c| c.id == id))", "ordered = slot.candidates.map(|c| c.id).concat(domain.take_first(0))"),
    ("r03", "a header fact is asked for a compiler", "releases = picked.keep_if(|(kind, _)| kind != Compiler).map(|(_, id)| id)", "releases = picked.map(|(_, id)| id)"),
    # Need, Done, Fail (R-EP8, R-EP9)
    ("n01", "Allowed: Done when A has all facts (B not read)", "[] => if places == real Done(chosen(vars, places)) else Need(needs(vars, facts, req.compat, Allowed, real))", "[] => Done(chosen(vars, places))"),
    ("n02", "Allowed: no A gives Fail", "NoTuple(_) => Need(needs(vars, facts, req.compat, Allowed, real))", "NoTuple(why) => Fail(why)"),
    ("n03", "Allowed: the Fail has the explanation of the search with inferred facts", "Allowed => match solve(vars, init, base.concat(check_incs(init, vars, req.compat, RealOnly))) {\n\t\t\t\tNoTuple(why) => Fail(why)", "Allowed => match solve(vars, init, base.concat(check_incs(init, vars, req.compat, RealOnly))) {\n\t\t\t\tNoTuple(_) => (match found {\n\t\t\t\t\tNoTuple(why) => Fail(why)\n\t\t\t\t\tFound(_) => Fail({ steps: [] })\n\t\t\t\t})"),
    ("n04", "probes before headers", "if !headers.is_empty() {\n\t\theaders.map(|id| Header(id))\n\t} else if mode == Off {\n\t\t[]\n\t} else {", "if !headers.is_empty() and mode == Off {\n\t\theaders.map(|id| Header(id))\n\t} else if mode == Off {\n\t\t[]\n\t} else {"),
    ("n05", "a pair with an inferred check has a real fact", "!compat.checks.any(|c| c.id == id and c.nightly == n and c.source == Real)", "!compat.checks.any(|c| c.id == id and c.nightly == n)"),
    ("n06", "a probe is asked twice for one release", ".fold([], |acc, id| if acc.contains(id) acc else acc.append(id)).map(|id| Probe({ id, nightly: n }))", ".map(|id| Probe({ id, nightly: n }))"),
    ("n07", "Off asks for probes", "} else if mode == Off {\n\t\t[]", "} else if mode == Off and Bool.False {\n\t\t[]"),
    ("n08", "Off: Fail from the real facts only", "Off => match found {\n\t\t\t\tNoTuple(why) => Fail(why)", "Off => match solve(vars, init, base.concat(check_incs(init, vars, req.compat, RealOnly))) {\n\t\t\t\tNoTuple(why) => Fail(why)"),
    ("n09", "the second pass asks for the pairs of A", "NoTuple(_) => Need(needs(vars, facts, req.compat, Allowed, real))", "NoTuple(_) => Need(needs(vars, facts, req.compat, Allowed, []))"),
    ("n10", "the probe names the first compiler", "nightly = picked.find_first(|(kind, _)| kind == Compiler).map_ok(|(_, id)| id)", "nightly = picked.find_first(|(kind, _)| kind == Compiler).map_ok(|(_, id)| if id == \"\" \"n1\" else \"n1\")"),
    ("n11", "the second pass is for A, not for B", "[] => if places == real Done(chosen(vars, places)) else Need(needs(vars, facts, req.compat, Allowed, real))", "[] => if places == real Done(chosen(vars, places)) else Need(needs(vars, facts, req.compat, Allowed, places))"),
    ("n12", "an unknown pair is not fit in Off (the step asks for no fact, but fails)", "Found(places) => match needs(vars, facts, req.compat, Off, places) {\n\t\t\t\t\t[] => Done(chosen(vars, places))", "Found(places) => match needs(vars, facts, req.compat, Off, places) {\n\t\t\t\t\t[] => if req.compat.checks.is_empty() and !req.compat.domain.is_empty() Fail({ steps: [] }) else Done(chosen(vars, places))"),
]

def sh(cmd, timeout):
    try:
        return subprocess.run(cmd, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return None

# The count of the fast set: the line `# l1-runs: <n>` of the target (as scripts/test.sh reads it), else 20000.
_m = re.search(r"^# l1-runs: ([0-9]+)$", open("tests/fuzz/pubgrub.roc").read(), re.M)
RUNS = os.environ.get("L1_RUNS") or (_m.group(1) if _m else "20000")
# L1_ALL=1 runs the L1 target also for a change that L0 catches (to see what L1 alone catches at this count).
L1_ALL = os.environ.get("L1_ALL") == "1"

def l1():
    shutil.rmtree(SCR, ignore_errors=True)
    os.makedirs(SCR)
    b = sh([ROC, "build", "--fuzz", "--opt=speed", "tests/fuzz/pubgrub.roc", "--output=" + SCR + "/t"], 300)
    if b is None or b.returncode != 0:
        return "BUILD FAILED"
    try:
        r = subprocess.run([SCR + "/t", "run", "--runs=" + RUNS, "--seed=1", "--artifact-dir=" + SCR + "/art"], cwd=SCR, capture_output=True, text=True, timeout=200)
    except subprocess.TimeoutExpired:
        return "caught (timeout)"
    if r.returncode == 0:
        return "MISSED"
    lines = [l for l in (r.stdout + r.stderr).splitlines() if l.startswith("[roc crashed]")]
    return "caught: " + (lines[0][:150] if lines else "exit %d" % r.returncode)

def main():
    want = set(sys.argv[1:])
    ref = open(REF).read()
    try:
        for mid, what, old, new in M:
            if want and mid not in want:
                continue
            if ref.count(old) != 1:
                print(mid, "BAD TEXT: %d matches" % ref.count(old), flush=True)
                continue
            t0 = time.time()
            open(DST, "w").write(ref.replace(old, new))
            chk = sh([ROC, "check", "packages/resolve/main.roc"], 120)
            if chk is None or chk.returncode != 0 or "0 errors and 0 warnings" in chk.stdout and False:
                print(mid, what, "DOES NOT COMPILE", ((chk.stdout + chk.stderr)[:500] if chk else "timeout"), flush=True)
                continue
            if "warning" in chk.stdout and "0 warnings" not in chk.stdout:
                print(mid, what, "WARNING", chk.stdout[-300:], flush=True)
                continue
            res = []
            for f in ("conflicts", "solver"):
                t = sh([ROC, "test", "packages/resolve/tests/%s.roc" % f, "--no-cache"], 25)
                if t is None:
                    res.append(f + ":timeout")
                elif t.returncode != 0:
                    labels = [l for l in (t.stdout + t.stderr).splitlines() if l.startswith("[dbg] [\"")]
                    res.append(f + ":caught" + (" " + labels[0][:100] if labels else ""))
                else:
                    res.append(f + ":pass")
            caught = any("caught" in r or "timeout" in r for r in res)
            line = "%s %s | L0 %s" % (mid, what, "; ".join(res))
            if not caught or L1_ALL:
                line += " | L1 " + l1()
            print(line, "(%.0f s)" % (time.time() - t0), flush=True)
    finally:
        shutil.copyfile(STUB, DST)
        print("stub restored:", open(DST).read() == open(STUB).read(), flush=True)

main()
