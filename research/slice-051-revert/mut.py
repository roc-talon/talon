#!/usr/bin/env python3
"""One mutation of the reference: python3 mut.py <id> ... Puts the reference in (restore.sh reference), applies the mutation (one exact replace, in the live file), runs l0 (all), l2 `tool/rm` and l3 `tools/rm1-remove-talon`, `tools/rm2-remove-all`, then puts the reference back.
Prints one line for each id: the id, and for each layer 'killed' (a test failed) or 'SURVIVED'. The log is in mut-<id>.log."""
import subprocess, sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
T = os.path.abspath(os.path.join(HERE, "../.."))
M = {
 "m1-tools-go-in-option-3": ("cli/lib/TalonRemove.roc", "Tools => facts.choice == WithTools", "Tools => facts.choice != Default"),
 "m2-data-tln-not-last": ("cli/lib/TalonRemoveFlow.roc", "delete_all!(fx, (if fates.tln == Remove [tln] else []).append(Text.join(facts.data_bin, TalonRemove.file(facts.os))))?", "delete_all!(fx, [Text.join(facts.data_bin, TalonRemove.file(facts.os))].concat(if fates.tln == Remove [tln] else []))?"),
 "m3-roc-old-over-foreign-roc": ("cli/lib/TalonRemove.roc", "restores = |facts| facts.old and facts.roc != Keep", "restores = |facts| facts.old"),
 "m4-foreign-tln-deleted": ("cli/lib/TalonRemoveFlow.roc", "delete_all!(fx, (if fates.tln == Remove [tln] else [])", "delete_all!(fx, [tln]"),
 "m6-compat-dir-kept": ("cli/lib/TalonRemoveFlow.roc", "fx.locked!(item, || Trash.move!(fx, facts.roots, { item, compat: chain.compat }))?", "fx.locked!(item, || Trash.move!(fx, facts.roots, { item, compat: Err(None) }))?"),
 "m7-data-deleted-in-option-3": ("cli/lib/TalonRemoveFlow.roc", "if goes(Data) {", "if goes(Data) or choice == TalonOnly {"),
 "m9-foreign-tool-entry-deleted": ("cli/lib/TalonRemoveFlow.roc", "\t\t\t\tKeep => {\n\t\t\t\t\t$gone = $gone.append(data)\n\t\t\t\t\t$kept = $kept.append(entry)", "\t\t\t\tKeep => {\n\t\t\t\t\t$gone = $gone.append(entry).append(data)\n\t\t\t\t\t$kept = $kept.append(entry)"),
 "m10-windows-del-order": ("cli/lib/TalonRemoveFlow.roc", "files = (if fates.roc == Remove [roc] else []).concat(if fates.tln == Remove [tln] else []).concat(if fates.data [data] else [])", "files = (if fates.data [data] else []).concat(if fates.roc == Remove [roc] else []).concat(if fates.tln == Remove [tln] else [])"),
 "m11-tools-json-no-lock": ("cli/lib/TalonRemoveFlow.roc", "tool_kept = fx.locked!(facts.tools_file, || manifest!(fx, facts, fates, choice))?", "tool_kept = manifest!(fx, facts, fates, choice)?"),
 "m12-stuck-not-reported": ("cli/lib/TalonRemoveFlow.roc", "Err(NotStarted(_)) => dels", "Err(NotStarted(_)) => []"),
 "m13-kept-path-stale-after-move": ("cli/lib/TalonRemove.roc", "Ok(move) if move.from == target => move.to", "Ok(move) if move.from == \"\" => move.to"),
 "m14-report-size-left-aligned": ("cli/lib/TalonRemove.roc", "\t\t\t\t[2],\n\t\t\t).map(", "\t\t\t\t[],\n\t\t\t).map("),
 "m15-screen-size-left-aligned": ("cli/lib/TalonRemove.roc", "table(rows, [2]).map(", "table(rows, []).map("),
}
for mid in sys.argv[1:]:
    f, old, new = M[mid]
    subprocess.run([os.path.join(HERE, "restore.sh"), "reference"], check=True)
    p = os.path.join(T, f)
    s = open(p).read()
    assert s.count(old) == 1, f"{mid}: old text found {s.count(old)} times"
    open(p, "w").write(s.replace(old, new))
    res = {}
    log = open(os.path.join(HERE, f"mut-{mid}.log"), "w")
    try:
        for name, cmd in [("l0", ["scripts/test.sh", "l0"]), ("l2", ["tests/commands/run.sh", "tool/rm"]), ("l3", ["tests/run.sh", "tools/rm1-remove-talon", "tools/rm2-remove-all"])]:
            r = subprocess.run(cmd, cwd=T, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            log.write(f"=== {name} exit {r.returncode}\n{r.stdout}\n")
            bad = ("unused" in r.stdout or "known at compile time" in r.stdout or "WARNING" in r.stdout or "duplicate definition" in r.stdout)
            res[name] = ("INVALID(warning)" if bad else "killed") if r.returncode != 0 else "SURVIVED"
    finally:
        subprocess.run([os.path.join(HERE, "restore.sh"), "reference"], check=True)
    print(mid, res, flush=True)
