#!/usr/bin/env python3
"""Revert check of slice 034 (TW12), by the test agent. Each mutation is a small change of the private reference
(research/slice-034-revert/reference/{Domain,Solver}.roc). One at a time: the changed text goes to packages/resolve/<file> (a copy over the file),
`roc check packages/resolve/main.roc` (0 errors and 0 warnings needed), then the 2 L0 files and the L1 step. At the end the stubs are copied back.
Usage: mutate.py [id ...]   (no id: all)   Result lines: <id> <what> L0=caught|MISSED L1=caught|MISSED
"""
import os, subprocess, sys, shutil

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
REFDIR = os.path.join(ROOT, "research/slice-034-revert/reference")
DSTDIR = os.path.join(ROOT, "packages/resolve")
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, ROC=ROC)
TIMEOUT = int(os.environ.get("MUT_TIMEOUT", "40"))

# (id, file, what, old, new). `old` must occur exactly once in the reference file.
M = [
    ("d01", "Domain.roc", "Highest and Lowest swapped", "Before => if strategy == Highest After else Before\n\tAfter => if strategy == Highest Before else After", "Before => if strategy == Highest Before else After\n\tAfter => if strategy == Highest After else Before"),
    ("d02", "Domain.roc", "a tie is in the reverse byte order", "Same => bytes(a.id.to_utf8(), b.id.to_utf8(), 0)", "Same => bytes(b.id.to_utf8(), a.id.to_utf8(), 0)"),
    ("d02b", "Domain.roc", "a tie keeps the order of the input", "Same => bytes(a.id.to_utf8(), b.id.to_utf8(), 0)", "Same => if a.id == b.id Same else Same"),
    ("d03", "Domain.roc", "ranges: any instead of all", "q.ranges.all(|text| in_range(text, v))", "(q.ranges.is_empty() or q.ranges.any(|text| in_range(text, v)))"),
    ("d04", "Domain.roc", "a yanked release is a value", "(!c.yanked and !hidden(q, c))", "!hidden(q, c)"),
    ("d05", "Domain.roc", "the header value is hidden when yanked", "exempt(c) or (!c.yanked and !hidden(q, c))", "!c.yanked and (exempt(c) or !hidden(q, c))"),
    ("d06", "Domain.roc", "young: >= (a release exactly min_age old is hidden)", "c.published_at + q.rules.min_age > q.rules.now", "c.published_at + q.rules.min_age >= q.rules.now"),
    ("d07", "Domain.roc", "young: not applied", "young = c.published_at + q.rules.min_age > q.rules.now", "young = c.published_at + q.rules.min_age + 1000000 > q.rules.now + 2000000"),
    ("d08", "Domain.roc", "late: >= (a release at the snapshot time is hidden)", "Ok(time) => c.published_at > time", "Ok(time) => c.published_at >= time"),
    ("d09", "Domain.roc", "snapshot ignored", "Ok(time) => c.published_at > time", "Ok(_) => Bool.False"),
    ("d10", "Domain.roc", "the header value is hidden when too young or late", "exempt(c) or (!c.yanked and !hidden(q, c))", "(exempt(c) and !hidden(q, c)) or (!c.yanked and !hidden(q, c))"),
    ("d12", "Domain.roc", "a named version is hidden when too young", "!named and (young or late)", "!(named and q.rules.min_age > 1000000000) and (young or late)"),
    ("d13", "Domain.roc", "a named version is a value when yanked", "exempt(c) or (!c.yanked and !hidden(q, c))", "exempt(c) or (q.named == Ok(c.version)) or (!c.yanked and !hidden(q, c))"),
    ("d14", "Domain.roc", "the header value is not added when the list lacks it", "Ok(c) => if q.candidates.any(|x| x.id == c.id) q.candidates else q.candidates.append({ id: c.id, version: c.version, published_at: 0, yanked: Bool.False })", "Ok(_) => q.candidates"),
    ("d15", "Domain.roc", "a range does not exclude the header value", "admitted = parsed.keep_if(|(_, v)| q.ranges.all(|text| in_range(text, v)))", "admitted = parsed.keep_if(|(c, v)| (q.current.map_ok(|cur| cur.id == c.id) == Ok(Bool.True)) or q.ranges.all(|text| in_range(text, v)))"),
    ("d16", "Domain.roc", "the version order reads the minor and patch only", "match va.order_relative_to(vb) {", "match Semver.new(0, va.minor(), va.patch()).order_relative_to(Semver.new(0, vb.minor(), vb.patch())) {"),
    ("s01", "Solver.roc", "a Package slot takes an App release", "(kind == Package and f.kind == Package)", "(kind == Package and f.kind != Platform)"),
    ("s02", "Solver.roc", "a Platform slot takes an App release", "(kind == Platform and f.kind == Platform)", "(kind == Platform and f.kind != Package)"),
    ("s03", "Solver.roc", "the kind of a fact is read only for App", "Ok(f) => (kind == Package and f.kind == Package) or (kind == Platform and f.kind == Platform)", "Ok(f) => (kind == Package or kind == Platform) and f.kind != App"),
    ("s04", "Solver.roc", "a release with no fact is not fit", "Err(_) => Bool.True\n}\n\nindexes", "Err(_) => Bool.False\n}\n\nindexes"),
    ("s05", "Solver.roc", "dep: > (the limit itself is no value)", "Before => Bool.False\n\t\t_ => Bool.True", "Before => Bool.False\n\t\tSame => Bool.False\n\t\tAfter => Bool.True"),
    ("s06", "Solver.roc", "a dep on the own group is read", "|(k, vk)| k != i and vk.group == dep.group", "|(k, vk)| vk.group == dep.group and k >= 0"),
    ("s07", "Solver.roc", "a dep names the slot name, not the group", "k != i and vk.group == dep.group", "k != i and vk.name == dep.group"),
    ("s08", "Solver.roc", "the platform of a platform slot release is read (no skip for its own slot)", "(Ok(url), [p]) => if p == i [] else match vars.get(p) {", "(Ok(url), [p]) => if p > 99 [] else match vars.get(p) {"),
    ("s09", "Solver.roc", "the platform check holds with 2 platform slots (the first one)", "(Ok(url), [p]) =>", "(Ok(url), [p, ..]) =>"),
    ("s10", "Solver.roc", "a platform that is no value does not exclude", "(Ok(url), [p]) => if p == i [] else match vars.get(p) {\n\t\t\tOk(pv) => one_inc(", "(Ok(url), [p]) => if p == i [] else match vars.get(p) {\n\t\t\tOk(pv) => if !pv.vals.any(|c| c.id == url) [] else one_inc("),
    ("s11", "Solver.roc", "a dep limit is not read when it is above all values", "Ok(need) => vars.map_with_index", "Ok(need) => if need.major() > 1 [] else vars.map_with_index"),
    ("s12", "Solver.roc", "the decision takes the worst value", "(ps.get(v) ?? []).first() ?? 0", "(ps.get(v) ?? []).last() ?? 0"),
    ("s13", "Solver.roc", "learn only the last decision (unsound)", "search(incs.append(decisions.map(|d| { v: d.v, set: [d.at] })), init, decisions.drop_last(1))", "search(incs.append(decisions.take_last(1).map(|d| { v: d.v, set: [d.at] })), init, decisions.drop_last(1))"),
    ("s14", "Solver.roc", "Need names all chosen ids", "Need(missing.map(|c| Header(c.id)))", "Need(chosen.map(|c| Header(c.id)))"),
    ("s15", "Solver.roc", "Need names the first missing id only", "Need(missing.map(|c| Header(c.id)))", "Need(missing.take_first(1).map(|c| Header(c.id)))"),
    ("s16", "Solver.roc", "Done with one missing fact", "if missing.is_empty() Done(chosen)", "if missing.len() < 2 Done(chosen)"),
    ("s17", "Solver.roc", "Need in the reverse order", "Need(missing.map(|c| Header(c.id)))", "Need(missing.rev().map(|c| Header(c.id)))"),
    ("s18", "Solver.roc", "a Contra term does not stop a unit propagation", "if classes.any(|(_, c)| c == Contra) {", "if classes.len() > 99 {"),
    ("s20", "Solver.roc", "a conflict with an unknown name applies without that term", "Err(_) => []\n\t},\n)\n\nlit_of", "Err(_) => one_inc(terms.keep_oks(|t| lit_of(vars, t)))\n\t},\n)\n\nlit_of"),
    ("s21", "Solver.roc", "the sign of a term is swapped", "t.ids.contains(c.id) == (t.sign == In)", "t.ids.contains(c.id) == (t.sign == NotIn)"),
    ("s22", "Solver.roc", "the version of a chosen is the id", "Ok(c) => { name: v.name, id: c.id, version: c.version }", "Ok(c) => { name: v.name, id: c.id, version: c.id }"),
    ("s23", "Solver.roc", "the strategy is ignored", "rules: req.rules })", "rules: { ..req.rules, strategy: Highest } })"),
    ("s24", "Solver.roc", "the header value is not passed to the domain", "current: slot.current, named: slot.named, rules", "current: Err(None), named: slot.named, rules"),
    ("s25", "Solver.roc", "the ranges are not passed to the domain", "ranges: slot.ranges, current", "ranges: [], current"),
    ("s26", "Solver.roc", "the rules are not the request rules (min_age 0)", "rules: req.rules })", "rules: { ..req.rules, min_age: 0 } })"),
    ("s27", "Solver.roc", "the named version is not passed", "current: slot.current, named: slot.named, rules", "current: slot.current, named: Err(None), rules"),
    ("s28", "Solver.roc", "a fact for another release is read (first fact wins)", "kind_fits : [Package, Platform], List(Solver.Fact), Str -> Bool\nkind_fits = |kind, facts, id| match facts.find_first(|f| f.id == id) {", "kind_fits : [Package, Platform], List(Solver.Fact), Str -> Bool\nkind_fits = |kind, facts, id| match facts.find_first(|f| f.id != id) {"),
    ("s29", "Solver.roc", "the facts of a release that is not chosen are not read (only the first value of a variable)", "v.vals.map_with_index(|c, j| (j, c)).join_map(", "v.vals.map_with_index(|c, j| (j, c)).take_first(1).join_map("),
    ("s30", "Solver.roc", "the conflicts of the caller are not read", "incs = conflict_incs(vars, req.conflicts).concat(", "incs = conflict_incs(vars, []).concat("),
    ("s31", "Solver.roc", "the deps are not read", "by_platform.concat(by_dep)", "by_platform.concat(by_dep.take_first(0))"),
    ("s32", "Solver.roc", "the platform is not read", "by_platform.concat(by_dep)", "by_dep.concat(by_platform.take_first(0))"),
    ("s33", "Solver.roc", "the terms of one variable are not joined (last wins)", "kept.map_with_index(|k, m| if m == n { v: k.v, set: k.set.keep_if(|x| lit.set.contains(x)) } else k)", "kept.map_with_index(|k, m| if m == n lit else k)"),
    ("s34", "Solver.roc", "(equivalent, kept to show it) a term with no value still gives an incompatibility: the term is Contra for each state", "if joined.any(|l| l.set.is_empty()) [] else [joined]", "[joined]"),
]


def sh(cmd, **kw):
    try:
        return subprocess.run(cmd, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=TIMEOUT, **kw)
    except subprocess.TimeoutExpired:
        class R:
            returncode = 124
            stdout = "TIMEOUT"
            stderr = ""
        return R()


def restore():
    for f in ("Domain.roc", "Solver.roc"):
        shutil.copyfile(os.path.join(REFDIR, f), os.path.join(DSTDIR, f))


def main():
    want = sys.argv[1:]
    refs = {f: open(os.path.join(REFDIR, f)).read() for f in ("Domain.roc", "Solver.roc")}
    try:
        for mid, fname, what, old, new in M:
            if want and mid not in want:
                continue
            ref = refs[fname]
            if ref.count(old) != 1:
                print(f"{mid} SKIP: old text occurs {ref.count(old)} times", flush=True)
                continue
            restore()
            open(os.path.join(DSTDIR, fname), "w").write(ref.replace(old, new))
            chk = sh([ROC, "check", "packages/resolve/main.roc"])
            if chk.returncode != 0:
                print(f"{mid} {what}: DOES NOT COMPILE\n{chk.stdout[-700:]}{chk.stderr[-300:]}", flush=True)
                continue
            l0d = sh([ROC, "test", "packages/resolve/tests/domain.roc", "--no-cache"])
            l0s = sh([ROC, "test", "packages/resolve/tests/solver.roc", "--no-cache"])
            l0 = "caught" if (l0d.returncode != 0 or l0s.returncode != 0) else "MISSED"
            if l0d.returncode == 124 or l0s.returncode == 124:
                l0 = "caught(timeout)"
            if os.environ.get("L0ONLY"):
                print(f"{mid} {what}: L0={l0}", flush=True)
                continue
            l1 = sh(["scripts/test.sh", "l1"])
            r1 = "caught" if l1.returncode != 0 else "MISSED"
            line = f"{mid} {what}: L0={l0} L1={r1}"
            if l1.returncode != 0:
                msg = [l for l in l1.stdout.splitlines() if "crashed" in l or "R-" in l]
                line += "  " + (msg[0].strip()[:150] if msg else "")
            print(line, flush=True)
    finally:
        # At the end the stubs are back in the package (the reference stays private, in reference/).
        for f in ("Domain.roc", "Solver.roc"):
            shutil.copyfile(os.path.join(ROOT, "research/slice-034-revert/stubs", f), os.path.join(DSTDIR, f))


main()
