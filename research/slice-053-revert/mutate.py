"""Slice 053 revert check: one edit of one line in the copy of cli/. Usage: python3 -I mutate.py <id> <mut dir>
The ids and the rules are in docs/slices/053-p1-exit.md section 10."""
import sys

MUT = {
    "m1": ("cli/lib/CacheGc.roc", 'aged.pkgs.join_map(|dir| [dir, "${dir}.deps.json"])', "aged.pkgs.join_map(|dir| [dir])"),
    "m2": ("cli/lib/Gc.roc", '["compat-", "nightly-", "debug-"].any', '["compat-", "nightly-"].any'),
    "m3": ("cli/RealFiles.roc", "newest: files.fold(0, |top, one| if one.time > top one.time else top)", "newest: files.fold(18446744073709551615, |low, one| if one.time < low one.time else low)"),
    "m4": ("cli/RealFiles.roc", "size: files.fold(0, |sum, one| sum + one.size)", "size: files.fold(0, |sum, one| if sum == 0 one.size else sum)"),
    "m5": ("cli/lib/CacheGc.roc", "now: facts.clocks.real, span: 86400 })", "now: facts.clocks.real, span: facts.age })"),
    "m6": ("cli/lib/Explain.roc", '.concat(stops(causes).map(|s| "or ${s}"))', '.concat([])'),
    "m7": ("cli/lib/Pick.roc", "(too_young(facts.now, facts.min_age, c.published_at) or after_snapshot(facts, c))", "(too_young(facts.now, facts.min_age, c.published_at))"),
}
if sys.argv[1] == "m0":
    sys.exit(0)  # no change: the baseline
path, old, new = MUT[sys.argv[1]]
p = sys.argv[2] + "/" + path
s = open(p).read()
assert s.count(old) == 1, (sys.argv[1], s.count(old))
open(p, "w").write(s.replace(old, new))
