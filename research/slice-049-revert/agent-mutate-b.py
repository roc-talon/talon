#!/usr/bin/env python3
"""Revert check of slice 049 part 049b (code agent). Run from the repo root.

Each mutation breaks the code in one small way, runs the layer that must see it, and puts the file back.
  l0  scripts/test.sh l0: caught when a failing test appears that the baseline does not have
      (baseline: XCacheTest 10 at line 319, a 049c test)
  l2  scripts/test.sh l2: caught when a case fails that the baseline does not have (baseline: gc/gc4-x, 049c)
Results go to research/slice-049-revert/agent-results-b.md.
"""
import re, subprocess

R = "research/slice-049-revert"
BASE_L0 = {"XCacheTest.roc:319"}
BASE_L2 = {"gc/gc4-x"}

# (name, layer, file, [(old, new), ...])
MUTANTS = [
    ("1 tie rule: an entry wins over an installed tool of the same version", "l0", "cli/lib/XCache.roc",
     [("if compare(c.version, have.version) == After Ok(c) else kept", "if compare(c.version, have.version) != Before Ok(c) else kept")]),
    ("2 selector: a selector matches any version online", "l0", "cli/lib/XCache.roc",
     [("Online(o) => version == o.first", "Online(_) => Bool.True")]),
    ("3 R-B3: the winner needs not be a candidate of the list", "l0", "cli/lib/XCache.roc",
     [("if o.listed.contains(win.version) win.found else NoMatch", "win.found")]),
    ("4 offline: a range or latest matches any build", "l0", "cli/lib/XCache.roc",
     [("			_ => Bool.False\n		}\n	}\n}\n\n# The order of two versions", "			_ => Bool.True\n		}\n	}\n}\n\n# The order of two versions")]),
    ("5 versions compare as text (1.9.0 is above 1.10.0)", "l0", "cli/lib/XCache.roc",
     [("(Ok(x), Ok(y)) => x.order_relative_to(y)", "(Ok(_), Ok(_)) => Text.compare(a, b)")]),
    ("6 D4: the sha256 of the entry is checked after the move", "l2", "cli/lib/XTake.roc",
     [('''	binary = XCacheIo.bin_of({ found: run.hit, os: facts.os })
	match fx.sha256_file!(binary) {
		Ok(sha) if sha == entry.sha256 => {}
		Ok(_) => return Err(Fail.new(Integrity, "${binary} does not match the sha256 of its manifest (${entry.sha256}). tln did not install it."))
		Err(err) => return Err(Fail.new(Environment, "cannot read ${binary}: ${Str.inspect(err)}"))
	}
	how_to = XCache.take_how({ project_uses: used_by_project(run.hit) })
	place!(fx, run.layout, { binary, how: how_to })?
''', '''	binary = XCacheIo.bin_of({ found: run.hit, os: facts.os })
	how_to = XCache.take_how({ project_uses: used_by_project(run.hit) })
	place!(fx, run.layout, { binary, how: how_to })?
	match fx.sha256_file!(binary) {
		Ok(sha) if sha == entry.sha256 => {}
		Ok(_) => return Err(Fail.new(Integrity, "${binary} does not match the sha256 of its manifest (${entry.sha256}). tln did not install it."))
		Err(err) => return Err(Fail.new(Environment, "cannot read ${binary}: ${Str.inspect(err)}"))
	}
''')]),
    ("7 NC3: a project uses every entry (the take-over copies and keeps the entry)", "l2", "cli/lib/XTake.roc",
     [("used_by_project = |hit| held_hashes.contains(hit.entry.bundle)", "used_by_project = |_hit| Bool.True")]),
    ("8 a run of a cached entry does not write last_run", "l2", "cli/lib/XCacheIo.roc",
     [("touch! = |fx, found, last_run| SetupIo.write_file!(fx, XCache.manifest_of(found.dir), XCache.manifest_text({ ..found.entry, last_run }))", "touch! = |_fx, _found, _last_run| Ok({})")]),
    ("9 offline with no flag and no person runs the entry (the prompt answer is ignored)", "l2", "cli/lib/XFlow.roc",
     [("				_ => Err(XCmd.declined({ via: Run, key, version }))", "				_ => run_binary!(fx, plan, XCacheIo.bin_of({ found: hit, os: facts.os }))")]),
]


def sh(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)


def l0():
    sh("scripts/test.sh l0")
    log = open(".work/logs/l0.log").read()
    return set(re.findall(r"tests/unit/((?:XCacheTest|XCmdTest)\.roc:\d+):\d+", log))


def l2():
    sh("scripts/test.sh l2")
    log = open(".work/logs/l2.log").read()
    return set(re.findall(r"^FAIL (\S+)", log, re.M))


def main():
    rows = [("0 baseline (no mutation)", "l0", "equal" if l0() == BASE_L0 else "DIFFERENT"),
            ("0 baseline (no mutation)", "l2", "equal" if l2() == BASE_L2 else "DIFFERENT")]
    for name, layer, path, pairs in MUTANTS:
        orig = open(path).read()
        s = orig
        ok = True
        for old, new in pairs:
            if s.count(old) != 1:
                ok = False
            s = s.replace(old, new)
        if not ok:
            rows.append((name, layer, "MUTATION DID NOT APPLY"))
            continue
        open(path, "w").write(s)
        try:
            got = l0() if layer == "l0" else l2()
            extra = sorted(got - (BASE_L0 if layer == "l0" else BASE_L2))
            rows.append((name, layer, "caught by " + ", ".join(extra) if extra else "NOT CAUGHT"))
        finally:
            open(path, "w").write(orig)
    with open(R + "/agent-results-b.md", "w") as f:
        f.write("# Revert check 049b (code agent)\n\n| Mutation | Layer | Result |\n| --- | --- | --- |\n")
        for r in rows:
            f.write("| %s | %s | %s |\n" % r)
    print(open(R + "/agent-results-b.md").read())


main()
