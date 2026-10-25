#!/usr/bin/env python3
"""One mutation of the reference: python3 mut.py <id> ... Puts the reference in (restore.sh reference), applies the mutation (one exact replace, in the live file), runs l0 (all), l2 `tool/ts` and l3 `ts1-update-talon`, then puts the reference back.
Prints one line for each id: the id, and for each layer 'killed' (a test failed) or 'SURVIVED'. The log is in mut-<id>.log."""
import subprocess, sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
T = os.path.abspath(os.path.join(HERE, "../.."))
M = {
 "m1-pick-ignores-age": ("cli/lib/TalonUpdate.roc", "old = usable.keep_if(|r| r.published_at + facts.min_age <= facts.now)", "old = usable"),
 "m2-pick-allows-downgrade": ("cli/lib/TalonUpdate.roc", "if is_after(newest.version, facts.current) Ok(Newer(newest))", "if newest.version != facts.current Ok(Newer(newest))"),
 "m3-version-order-patch-first": ("cli/lib/TalonUpdate.roc", "is_after = |a, b| after(numbers(a), numbers(b))", "is_after = |a, b| after(numbers(a).rev(), numbers(b).rev())"),
 "m4-del-moves-all-os": ("cli/lib/TalonUpdate.roc", "del_moves = |facts| if facts.os == Windows {", "del_moves = |facts| if facts.hex != \"zz\" {"),
 "m5-version-check-any-exit": ("cli/lib/TalonUpdate.roc", "Exited(0) => return Ok({})", "Exited(_) => return Ok({})"),
 "m6-talon-key-not-skipped": ("cli/lib/ToolsJson.roc", "others = |pairs| pairs.keep_if(|(key, _)| key != \"talon\")", "others = |pairs| pairs"),
 "m7-current-ignores-git-tag": ("cli/lib/TalonUpdate.roc", "Ok(version) => version\n", "Ok(_) => facts.running\n"),
 "m8-no-sha-check": ("cli/lib/TalonUpdateFlow.roc", "\tTalonUpdate.check_download({ tag: run.release.tag, name: run.asset, want, got })?", "\t_ = TalonUpdate.check_download({ tag: run.release.tag, name: run.asset, want, got })"),
 "m9-foreign-roc-replaced": ("cli/lib/TalonUpdate.roc", "make: [tln], warnings: [TalonUpdate.kept_warning(Text.join(facts.bin, roc))]", "make: [tln, roc], warnings: []"),
 "m10-temp-kept-after-failure": ("cli/lib/TalonUpdateFlow.roc", "\t_ = fx.delete!([lay.data_tmp, tmp_dir])", "\t_ = if result.is_ok() fx.delete!([lay.data_tmp, tmp_dir]) else []"),
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
        for name, cmd in [("l0", ["scripts/test.sh", "l0"]), ("l2", ["tests/commands/run.sh", "tool/ts"]), ("l3", ["tests/run.sh", "ts1-update-talon"])]:
            r = subprocess.run(cmd, cwd=T, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            log.write(f"=== {name} exit {r.returncode}\n{r.stdout}\n")
            bad = ("unused" in r.stdout or "known at compile time" in r.stdout or "WARNING" in r.stdout or "duplicate definition" in r.stdout)
            res[name] = ("INVALID(warning)" if bad else "killed") if r.returncode != 0 else "SURVIVED"
    finally:
        subprocess.run([os.path.join(HERE, "restore.sh"), "reference"], check=True)
    print(mid, res, flush=True)
