#!/usr/bin/env python3
"""Revert check of slice 056: each mutant changes one tricky behavior of the private reference in cli/lib, runs the filtered tests (l0 driver 8, the 8 L2 cases of the slice, the L3 scenario), then puts the reference back.
Run from the repo root: python3 research/slice-056-revert/mutants.py [name ...]. The result goes to research/slice-056-revert/mutants.log. It never runs the full sweep."""
import subprocess, sys, shutil, os
REF = "research/slice-056-revert/reference/lib"
M = [
    ("M1-cached-target", "ToolsPlan", "f.has_bin and f.entry.bundle == facts.bundle and f.entry.target == facts.target and match", "f.has_bin and f.entry.bundle == facts.bundle and match"),
    ("M2-frozen-range", "ToolsPlan", "Ok(Range(text)) => Ranges.admits({ ranges: [text], version: ident.version })", "Ok(Range(_)) => Bool.True"),
    ("M3-split-alias-key", "ToolsPlan", "both = |name| !name.contains(\"@\") and facts.keys.contains(name) and facts.aliases.contains(name)", "both = |name| name == \"never key\" and facts.keys.contains(name)"),
    ("M6-held-walk-stop", "ToolsPlan", "if has_workspace(read.text) here else here.concat(walk_hashes(rest, reads))", "here.concat(walk_hashes(rest, reads))"),
    ("M7-takeover-copy", "XTake", "project_uses: held.contains(entry.bundle)", "project_uses: held.contains(\"no such hash\")"),
    ("M8-has-file", "XCacheIo", "found.any(|e| !e.is_dir and (e.name == repo or e.name == \"${repo}.exe\"))", "found.any(|e| e.name != \"manifest.json\" or repo == \"\")"),
    ("M9-gc-package", "CacheGc", "pkgs = candidates.pkgs.keep_if(|dir| !held.contains(Text.last_segment(dir)))", "pkgs = candidates.pkgs"),
    ("M10-header-idle", "InstallFlow", "header_idle: split.header.is_empty()", "header_idle: Bool.False"),
    ("M11-snapshot-cut", "ToolsPlan", "Ok(cut) => facts.list.keep_if(|c| c.published_at <= cut)", "Ok(cut) => facts.list.keep_if(|c| c.published_at < cut)"),
    ("M14-key-taken", "ToolsFlow", "if name_of(old.ref) == ref.name {", "if name_of(old.ref) != \"\" {"),
    # review of the manager (D8, D16, Q3, Q-A, the flag of Q-A): one mutation for each change
    ("N1-dry-run-builds", "ToolsStep", "Err(None) => if ctx.dry_run {", "Err(None) => if ctx.dry_run and ctx.home == \"\" {"),
    ("N2-nothing-line", "InstallFlow", "if !step.changed and outcome.written.is_empty() and outcome.kept.is_empty() {", "if (step.changed or !step.changed) and outcome.written.is_empty() and outcome.kept.is_empty() {"),
    ("N3-no-project", "ToolsPlan", "fail.kind == Usage and fail.message.starts_with(\"no project file found. Checked:\")", "fail.kind == Usage and fail.message.starts_with(\"no project file found. Checked:\") and fail.message == \"\""),
    ("N4-compiler-stop", "ToolsPlan", "if fail.kind == Consent and fail.message.starts_with(\"the compiler \")", "if fail.kind == Consent and tail == \"\" and fail.message.starts_with(\"the compiler \")"),
    ("N5-allow-env", "ToolsPlan", "if facts.allow [(\"TALON_AUTO_INSTALL\", \"yes\")]", "if facts.allow and facts.env.is_empty() [(\"TALON_AUTO_INSTALL\", \"yes\")]"),
]
want = sys.argv[1:]
log = open("research/slice-056-revert/mutants.log", "a")


def run(cmd):
    p = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


for name, mod, old, new in M:
    if want and name not in want:
        continue
    subprocess.run("sh research/slice-056-revert/reference-on.sh > /dev/null", shell=True, check=True)
    path = f"cli/lib/{mod}.roc"
    s = open(path).read()
    assert s.count(old) == 1, (name, s.count(old))
    open(path, "w").write(s.replace(old, new))
    rc, out = run("research/slice-056-revert/chk.sh 5")
    if "No errors found" not in out:
        print(name, "DOES NOT COMPILE", out[:300])
        log.write(f"{name}: does not compile\n")
        continue
    l0 = run("research/slice-056-revert/l0.sh l0-8.roc 400")[1]
    l0_fail = "failed" in l0 and "0 failed" not in l0
    rc2, l2 = run("tests/commands/run.sh pt1-add pt2-install pt3-move gc5-project tk2-takeover tk1-takeover gc1-select gc3-caches")
    l2_fail = [l.strip() for l in l2.split("\n") if l.startswith("FAIL")]
    rc3, l3 = run("tests/run.sh ptools")
    l3_fail = [l.strip() for l in l3.split("\n") if l.startswith("FAIL")]
    line = f"{name}: l0={'caught' if l0_fail else 'MISSED'} l2={l2_fail or 'MISSED'} l3={l3_fail or 'MISSED'}"
    print(line)
    log.write(line + "\n")
    log.flush()
subprocess.run("sh research/slice-056-revert/reference-on.sh > /dev/null", shell=True, check=True)
