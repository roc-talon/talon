# Slice 262 mutation check (TW12): the mutants. Each is a list of (file, old, new); each old text must occur exactly once in its file.
# Usage: python3 mutants.py <name> <mirror dir>   (exit 1: did not apply). python3 mutants.py --list: the names.
import sys

T = "\t"
MUTANTS = {
    # Q262-1: the table is read only after the edit distance finds nothing ("uninstall" is then 'install', distance 2).
    "m1-table-not-first": [
        ("cli/lib/Args.roc", "match table {", "match Err(NotFound) {"),
        ("cli/lib/Args.roc",
         T * 6 + "Ok((long, _)) => Ok(path(long))\n" + T * 6 + "Err(_) => Err(NoHint)\n",
         T * 6 + "Ok((long, _)) => Ok(path(long))\n" + T * 6 + "Err(_) => table.map_ok(|(_, to)| path(to)).map_err(|_| NoHint)\n"),
    ],
    # Q262-1: the limit 1 also for a word of 5 letters (off by one at the length bound).
    "m2-limit-length-off-by-one": [
        ("cli/lib/Args.roc", "limit = if word.count_utf8_bytes() <= 4 1 else 2", "limit = if word.count_utf8_bytes() <= 5 1 else 2"),
    ],
    # Q262-2: --ignore is not repeatable.
    "m3-ignore-not-repeatable": [
        ("cli/lib/Args.roc", 'if seen.contains(flag) and flag != "--ignore" and flag != "--target" {', 'if seen.contains(flag) and flag != "--target" {'),
    ],
    # Q262-9: the repeat is checked before "not for".
    "m4-repeat-before-not-for": [
        ("cli/lib/Args.roc", "match state.checks.find_first(|flag| !allows(key, flag)) {",
         "match (match repeated(state.checks) { Ok(_) => Err(NotFound), Err(_) => state.checks.find_first(|flag| !allows(key, flag)) }) {"),
    ],
    # R1: the anchor note is printed for upgrade too.
    "m5-anchor-note-for-upgrade": [
        ("cli/lib/InstallFlow.roc", "if request.command == Upgrade [] else Report.anchor_notes(", "Report.anchor_notes("),
    ],
    # D1: an anchor that comes from an override gets the held line.
    "m6-held-line-for-override": [
        ("cli/lib/Vars.roc", "and !run.overridden and !outside_range(variable)", "and !outside_range(variable)"),
    ],
    # R-CM6: the (pinned) mark also on a row with no pin whose wanted is not ahead of current.
    "m7-pinned-mark-not-behind": [
        ("cli/lib/Outdated.roc", 'wanted: if Outdated.pin_of(file, r, pins).is_ok() "${r.wanted} (pinned)"',
         'wanted: if Outdated.pin_of(file, r, pins).is_ok() or r.current == r.wanted "${r.wanted} (pinned)"'),
    ],
    # Q262-6: line B also when ROC_TOOLCHAIN (or another source of priority 2, 4, 5) selects for the project.
    "m8-line-b-with-roc-toolchain": [
        ("cli/lib/ManageUpdate.roc", "Err(NoPin) => if facts.other {", "Err(NoPin) => if facts.other and facts.id == \"\" {"),
    ],
}

if sys.argv[1] == "--list":
    print(" ".join(MUTANTS)); sys.exit(0)
name, root = sys.argv[1], sys.argv[2]
for f, old, new in MUTANTS[name]:
    p = f"{root}/{f}"; s = open(p).read()
    if s.count(old) != 1:
        print(f"{name}: '{old[:60]}' found {s.count(old)} times in {f}"); sys.exit(1)
    open(p, "w").write(s.replace(old, new))
