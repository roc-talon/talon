#!/usr/bin/env python3
"""Revert check of slice 026 (TW12): one hand-made change at a time in the private reference, `roc check`, then only the tests that should catch it. The reference is put back after each change.
Usage: python3 research/slice-026-revert/mutate.py [id ...]   (from the repo root; needs the reference tree: swap.sh reference)
Output: research/slice-026-revert/mutate.out (one line for each change: id, result, the test that failed)."""
import subprocess, sys, os
ROOT = os.getcwd()
R = "research/slice-026-revert"
env = dict(os.environ)
env.update({"XDG_CACHE_HOME": "/tmp/claude-1000/xdg", "ROC_CACHE_DIR": "/tmp/claude-1000/roccache"})
ROC = "/home/george/dev/Karakatiza666/talon/cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"

def sh(cmd, quiet=True):
    r = subprocess.run(cmd, shell=True, cwd=ROOT, env=env, capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr

L0 = lambda f: f"{ROC} test tests/unit/{f}.roc"
L2 = lambda f: f"tests/commands/run.sh {f}"
L3 = lambda f: f"tests/run.sh {f}"

M = [
 # id, file, old, new, tests
 ("U1", "cli/lib/Manage.roc", '		many => Err(Fail.new(Usage, "tln roc update takes no operand, got ${many.len().to_str()}"))', '		_many => Ok({})', [L0("manage"), L2("roc/up1")]),
 ("U2", "cli/lib/Manage.roc", "			Git | Link | Copy => Stay", "			Git | Copy => Stay\n			Link => Move", [L0("manage"), L2("roc/up1")]),
 ("U3", "cli/lib/Manage.roc", "		Err(Unset) => Move\n		Ok(id) => match Manage.kind_of(id) {", "		Err(Unset) => Stay\n		Ok(id) => match Manage.kind_of(id) {", [L0("manage")]),
 ("U4", "cli/lib/Manage.roc", 'else "${facts.id} is the newest\\n"', 'else "${facts.id} is up to date\\n"', [L0("manage"), L2("roc/up1")]),
 ("U5", "cli/lib/Manage.roc", '["the default compiler moved from ${old} to ${facts.id}\\n"]', '["the default compiler is now ${facts.id} (was ${old})\\n"]', [L0("manage"), L2("roc/up1")]),
 ("U6", "cli/lib/Manage.roc", "stderr: warned.stderr }", "stderr: warned.stderr.take_first(0) }", [L0("manage"), L2("roc/up1")]),
 ("U7", "cli/lib/Manage.roc", '("changed", JsonDoc.Flag(facts.changed)),', '("changed", JsonDoc.Flag(facts.installed)),', [L0("manage"), L2("roc/up1")]),
 ("U8", "cli/lib/RocManage.roc", "	if already {", "	if already and got.installed {", [L2("roc/up1"), L3("compilers/ru1")]),
 ("N2", "cli/lib/RocManage.roc", "	match Manage.update_move({ default: before }) {", "	match (if got.installed Manage.update_move({ default: before }) else Stay) {", [L2("roc/up1"), L3("compilers/ru1")]),
 ("N3b", "cli/lib/RocManage.roc", "installed: got.installed, compat: got.compat, previous: before, default: moved", "installed: Bool.True, compat: got.compat, previous: before, default: moved", [L2("roc/up1")]),
 ("N4", "cli/lib/Manage.roc", "warned = if facts.installed Toolchain.report({ id: facts.id, how: Installed, default: Kept, compat: facts.compat }) else { stdout: [], stderr: [] }", "warned = Toolchain.report({ id: facts.id, how: Installed, default: Kept, compat: facts.compat })", [L0("manage")]),
 ("N5", "cli/lib/Base.roc", "			Err(NoCompiler) | Err(NoneInRange) => Ok(Err(None))", "			Err(NoCompiler) => Ok(Err(None))\n			Err(NoneInRange) => Ok(Ok(\"nightly-2026-10-14-38a3029\"))", [L2("roc/bs3")]),
 ("U9", "cli/lib/RocManage.roc", "	before = config.default_roc\n", "	before = if config.default_roc.is_ok() Err(Unset) else Err(Unset)\n", [L2("roc/up1"), L3("compilers/ru1")]),
 ("U10", "cli/lib/RocManage.roc", "	if got.first_default {\n		return Ok({ id: got.id, item, installed: Bool.True, compat: got.compat, previous: before, default: Set, changed: Bool.True })\n	}\n", "", [L2("roc/up1"), L3("compilers/ru1")]),
 ("U11", "cli/lib/RocManage.roc", "	shown = Common.shown_fx(fx, args)\n	report = Manage.update_report", "	shown = fx\n	report = Manage.update_report", [L2("roc/up1"), L3("compilers/ru1")]),
 ("U12", "cli/lib/RocManage.roc", "	for line in report.stderr {\n		fx.err!(line)\n	}\n	if args.json {\n		fx.out!(Out.json_ok({ command: args.typed, data: Manage.update_data", "	if args.json {\n		fx.out!(Out.json_ok({ command: args.typed, data: Manage.update_data", [L2("roc/up1")]),
 ("U13", "cli/lib/RocManage.roc", 'text: "@latest", installed: [] })?\n	item', 'text: "@nightly-2026-10-14-38a3029", installed: [] })?\n	item', [L2("roc/up1")]),
 ("B1", "cli/lib/Toolchain.roc", "		(Bool.True, Ok(Step(_))) => Bool.True", "		(Bool.True, Ok(Step(n))) if n < 0 => Bool.True", [L0("toolchain"), L2("roc/bs1")]),
 ("B2", "cli/lib/RocInstall.roc", "		base = if Toolchain.needs_base(run.id) Base", "		base = if !run.id.is_empty() Base", [L2("roc/bs1"), L2("roc/ri1"), L2("proxy/")]),
 ("B3", "cli/lib/Base.roc", "		early = toolchain.is_ok()\n", "		early = toolchain.is_ok() and env.is_empty()\n", [L2("roc/bs1"), L3("compilers/bs1")]),
 ("B4", "cli/lib/Base.roc", "		pin = match files {\n			[file] => pin_of(read, file, project.header)", "		pin = match files {\n			[_file] => Err(NoPin)", [L2("roc/bs1"), L3("compilers/bs1")]),
 ("B5", "cli/lib/Base.roc", "			Ok(id) => Ok(Ok(id))\n			Err(Empty)", "			Ok(_) => Ok(Err(None))\n			Err(Empty)", [L3("compilers/bs1")]),
 ("B6", "cli/lib/Base.roc", "has_toml: project.project.toml.is_ok(), version_file })", "has_toml: Bool.False, version_file })", [L3("compilers/bs1")]),
 ("B7", "cli/lib/Base.roc", "			default: facts.config.default_roc,", "			default: Err(Unset),", [L2("roc/bs2"), L3("compilers/bs1")]),
 ("B9", "cli/lib/Base.roc", "			Ok(sel) => Ok(Ok(sel.id))", '			Ok(sel) => Ok(Ok(if sel.installed sel.id else "nightly-2026-10-14-38a3029"))', [L2("roc/bs1"), L2("roc/bs2")]),
 ("B10", "cli/lib/Base.roc", "		times = if loaded.req.is_ok() and !facts.installed.is_empty() times!(fx, facts.roots, facts.installed) else []", "		times = []", [L2("roc/bs3")]),
 ("B11", "cli/lib/Base.roc", '			_ => if env.contains(("TALON_IN_PROXY", "1")) Err(NoCompiler) else OnPath.file!(fx, facts.roots)', '			_ => Err(NoCompiler)', [L2("roc/bs1")]),
 ("G1", "cli/lib/Pin.roc", "		if Pin.is_id(facts.toolchain) {", "		if !facts.toolchain.is_empty() {", [L0("pin"), L2("ladder/ld-no-check-refuse")]),
 ("G2", "cli/lib/Pin.roc", "cannot be a pin, so tln roc use does not take it. Use ROC_TOOLCHAIN or tln roc default for it.\"", "cannot be a pin, so tln roc use does not take it. Use tln roc default for it.\"", [L0("pin"), L2("ladder/ld-no-check-refuse")]),
]

only = sys.argv[1:]
out = open(f"{R}/mutate.out", "a" if only else "w")
for (mid, file, old, new, tests) in M:
    if only and mid not in only:
        continue
    sh(f"{R}/swap.sh reference")
    text = open(os.path.join(ROOT, file)).read()
    if old not in text:
        out.write(f"{mid}\tNOT-APPLIED\t{file}\n"); out.flush(); continue
    open(os.path.join(ROOT, file), "w").write(text.replace(old, new, 1))
    rc, log = sh(f"{ROC} check cli/lib/main.roc")
    if rc != 0:
        out.write(f"{mid}\tCOMPILE-ERROR\t{[l for l in log.splitlines() if l.strip()][:6]}\n"); out.flush(); continue
    result = "NOT-CAUGHT"
    for t in tests:
        rc, log = sh(t)
        if rc != 0:
            result = "caught\t" + t.replace(ROC, "roc"); break
    out.write(f"{mid}\t{result}\t{file}\n"); out.flush()
sh(f"{R}/swap.sh reference")
