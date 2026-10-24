#!/usr/bin/env python3
"""Revert check of the code of slice 026a (TW12, filtered runs only, no full sweep).

For each mutation: the final code is restored first (copy in code-final/), then one small change in one file of cli/lib, a `roc check`, then only the tests that should catch it.
The first test that fails ends the run of that mutation (CAUGHT). A test that runs longer than its timeout counts as CAUGHT (a loop). The final code is restored after each mutation.
At the end, `cli/` is compared with code-final/.

Usage: python3 -I research/slice-026-revert/code-mutate.py [id ...]     (from the repo root)
Output: one line for each mutation: id, CAUGHT or NOT CAUGHT, the test that failed. The lines are also appended to code-results.md.
"""
import filecmp, os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FINAL = os.path.join(ROOT, "research/slice-026-revert/code-final/cli")
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))
LIB = "cli/lib/"
TIMEOUT = {"l0": 120, "l2": 300, "l3": 300}

# (id, file, [(old, new)], [tests], what the change breaks)
M = [
    ("M1", "Manage.roc", [('		many => Err(Fail.new(Usage, "tln roc update takes no operand, got ${many.len().to_str()}"))', "		_many => Ok({})")], ["l0:manage", "l2:roc/up1"], "R-CS3: an operand is accepted"),
    ("M2", "Manage.roc", [("			Git | Link | Copy => Stay\n			Nightly | Release => Move", "			Git | Copy => Stay\n			Nightly | Release | Link => Move")], ["l0:manage"], "R-RU2: a link default moves"),
    ("M3", "Manage.roc", [("		Err(Unset) => Move\n		Ok(id) => match Manage.kind_of(id) {\n			Git", "		Err(Unset) => Stay\n		Ok(id) => match Manage.kind_of(id) {\n			Git")], ["l0:manage"], "R-RU2: an unset default stays"),
    ("M4", "Manage.roc", [('else "${facts.id} is the newest\\n"', 'else "${facts.id} is up to date\\n"')], ["l0:manage", "l2:roc/up1"], "R-RU1: the text of the newest"),
    ("M5", "Manage.roc", [('Moved(old) => ["the default compiler moved from ${old} to ${facts.id}\\n"]', 'Moved(old) => ["the default compiler is now ${facts.id} (was ${old})\\n"]')], ["l0:manage", "l2:roc/up1"], "R-RU2: the text of a move"),
    ("M6", "Manage.roc", [("warnings = if facts.installed Toolchain.report", "warnings = if facts.installed or !facts.installed Toolchain.report")], ["l0:manage"], "R-RU1: the compat warning is shown with no install"),
    ("M7", "Manage.roc", [('("changed", JsonDoc.Flag(facts.changed)),', '("changed", JsonDoc.Flag(facts.installed)),')], ["l0:manage", "l2:roc/up1"], "R-J3: changed is installed"),
    ("M8", "Manage.roc", [('		("installed", JsonDoc.Flag(facts.installed)),\n		("previous", text_or_null(facts.previous.map_err(|Unset| None))),\n		("changed", JsonDoc.Flag(facts.changed)),', '		("previous", text_or_null(facts.previous.map_err(|Unset| None))),\n		("installed", JsonDoc.Flag(facts.installed)),\n		("changed", JsonDoc.Flag(facts.changed)),')], ["l0:manage", "l2:roc/up1"], "R-OUT4: the key order of update data"),
    ("M9", "RocManage.roc", [("	moved = if got.first_default {", "	moved = if got.first_default and !got.first_default {")], ["l2:roc/up1"], "R-SO15: the first default is decided again"),
    ("M10", "RocManage.roc", [("	Ok(current) if current == facts.id => Ok({ default: Same", "	Ok(current) if current != current => Ok({ default: Same")], ["l2:roc/up1"], "R-RU1: no lock-free Same when the default is the newest"),
    ("M11", "RocManage.roc", [("	Ok(current) if Manage.update_move({ default: facts.before }) == Stay =>", "	Ok(current) if current.is_empty() =>")], ["l2:roc/up1"], "R-RU2: a local build default moves"),
    ("M12", "RocManage.roc", [("(Bool.True, Ok(old)) => Moved(old)", "(Bool.True, Ok(_old)) => Set")], ["l2:roc/up1"], "R-RU2: a move is reported as a first default"),
    ("M13", "RocManage.roc", [("	before = RocInstall.read_config!(fx, roots)?.default_roc", "	before = Err(Unset)")], ["l2:roc/up1"], "R-RU2: the previous default is not read"),
    ("M14", "RocManage.roc", [("	shown = Common.shown_fx(fx, args)\n	lines = Manage.update_report", "	shown = fx\n	lines = Manage.update_report")], ["l2:roc/up1"], "R-J3: the text goes to stdout with --json"),
    ("M15", "RocManage.roc", [("	for line in lines.stderr {\n		fx.err!(line)\n	}\n	if args.json {\n		fx.out!(Out.json_ok({ command: args.typed, data: Manage.update_data", "	if args.json {\n		fx.out!(Out.json_ok({ command: args.typed, data: Manage.update_data")], ["l2:roc/up1"], "R-OUT2: the compat warning is not printed"),
    ("M16", "RocManage.roc", [('text: "@latest", installed: [] })?\n	moved', 'text: "@nightly-2026-10-14-38a3029", installed: [] })?\n	moved')], ["l2:roc/up1"], "R-RU1: update does not ask for the newest"),
    ("M17", "RocManage.roc", [("		RocInstall.ask_download!(fx, args, facts.env, { id: offer.id, size: offer.size })?\n		done =", "		done =")], ["l2:roc/up1"], "R-NI6: the download has no consent"),
    ("M18", "Toolchain.roc", [("		Ok(Step(_)) => Bool.True", "		Ok(Step(n)) if n < 0 => Bool.True")], ["l0:toolchain", "l2:roc/bs1"], "R-SL7: only a step back needs a base"),
    ("M19", "Toolchain.roc", [('needs_base = |text| text.starts_with("@") and match', "needs_base = |text| match")], ["l0:toolchain"], "R-SL7: a text with no @ needs a base"),
    ("M20", "RocInstall.roc", [("		base = if Toolchain.needs_base(run.id) {", "		base = if !run.id.is_empty() {")], ["l2:roc/bs1", "l2:roc/ri1"], "R-SL7: every operand reads a base"),
    ("M21", "RocInstall.roc", [("Nightlies.pick({ text: run.id, named: lists.named, auto: lists.auto, base })", "Nightlies.pick({ text: run.id, named: lists.named, auto: if base.is_ok() lists.auto else lists.auto, base: Err(None) })")], ["l2:roc/bs1"], "R-PD16: the base is not used"),
    ("M22", "RocInstall.roc", [("roots, installed: Compiler.installed(entries), config })?", "roots, installed: [], config })?")], ["l2:roc/bs3"], "R-NS1: no installed compiler for the base"),
    ("M23", "Base.roc", [("		found = if toolchain.is_ok() Err(NoProject) else Base.find!", "		found = if toolchain.is_ok() and toolchain.is_err() Err(NoProject) else Base.find!")], ["l2:roc/bs1", "l3:compilers/bs1"], "R-SO2: ROC_TOOLCHAIN still reads main.roc"),
    ("M24", "Base.roc", [("		(Err(Unset), Err(Unset), Ok(pin)) => Ok(pinned(pin, run.facts))", "		(Err(Unset), Err(Unset), Ok(pin)) if run.pin.is_err() => Ok(pinned(pin, run.facts))")], ["l2:roc/bs1", "l0:proxy"], "R-SO3: the header pin is not rank 3"),
    ("M25", "Base.roc", [("		Given(given) => given\n", "		Given(given) => { ..given, default_roc: Err(Unset) }\n")], ["l2:roc/bs2", "l3:compilers/bs1"], "R-SO6: the default is not the base"),
    ("M26", "Base.roc", [("			Err(NoCompiler) | Err(NoneInRange) => Ok(Err(None))", '			Err(NoCompiler) => Ok(Err(None))\n			Err(NoneInRange) => Ok(Ok("nightly-2026-10-14-38a3029"))')], ["l2:roc/bs3"], "R-SO14: a range with no compiler has a base"),
    ("M27", "Base.roc", [("		times = if loaded.req.is_ok() and !run.installed.is_empty() Base.times!(fx, run.roots, run.installed) else []", "		times = []")], ["l2:roc/bs3"], "R-NS1: no published_at for the order of the range"),
    ("M28", "Base.roc", [("			_ => if Base.in_proxy(run.env) Err(NoCompiler) else OnPath.file!(fx, run.roots)", "			_ => OnPath.file!(fx, run.roots)")], ["l0:proxy", "l2:roc/so1", "l2:proxy/"], "R-EV17: a proxy in a proxy looks at PATH"),
    ("M29", "Base.roc", [("			Ok(sel) if sel.state == Installed and sel.rank != Range => Err(NoCompiler)", "			Ok(sel) if sel.state == Installed => Err(NoCompiler)")], ["l2:roc/bs3"], "R-SO7: a range does not look at PATH"),
    ("M30", "Base.roc", [("			(_, Ok(flag)) => flag\n			_ => Bool.True\n		}\n		{\n			argument", "			(_, Ok(flag)) => flag\n			_ => Bool.False\n		}\n		{\n			argument")], ["l2:roc/so1", "l2:proxy/", "l3:compilers/bs1"], "R-NS3: the nightly switch is off with no setting"),
    ("M31", "Base.roc", [("	paths = files.concat(tomls).concat(own).concat(versions)", "	paths = files.concat(tomls).concat(versions).concat(own)")], ["l2:roc/so1", "l2:proxy/"], "R-SO3: the order of the files of one read"),
    ("M32", "Base.roc", [("		Read => [config_path]", "		Read => []")], ["l2:roc/so1", "l2:proxy/"], "R-SO6: the proxy does not read config.toml"),
    ("M33", "Pin.roc", [("		if local_build(facts.toolchain) {", "		if local_build(facts.toolchain) and facts.pin.is_empty() {")], ["l0:pin", "l2:ladder/ld-no-check-refuse"], "G2: no second form of the note"),
    ("M34", "Pin.roc", [('local_build = |id| id.starts_with("git-") or id.starts_with("link-") or id.starts_with("copy-")', 'local_build = |id| id.starts_with("git-") or id.starts_with("copy-")')], ["l0:pin", "l2:ladder/ld-no-check-refuse"], "G2: a link id has the first form"),
    ("M35", "Install.roc", [("	on_path_file! = |fx, roots| OnPath.file!(fx, roots)", "	on_path_file! = |_fx, _roots| Err(NoCompiler)")], ["l2:install/in1", "l2:roc/so1"], "R-SO9: Install does not call OnPath"),
    ("M36", "OnPath.roc", [("		if facts.found.is_empty() return Err(NoCompiler)\n", "")], ["l2:roc/so9", "l2:roc/so1", "l2:install/in1", "l3:compilers/so9", "l3:compilers/bs1"], "R-SO9: no early stop for no roc on PATH"),
]


def restore():
    """Copy code-final/ over cli/ (files that differ only)."""
    for d, _, files in os.walk(FINAL):
        for f in files:
            src = os.path.join(d, f)
            dst = os.path.join(ROOT, "cli", os.path.relpath(src, FINAL))
            if not os.path.exists(dst) or not filecmp.cmp(src, dst, shallow=False):
                shutil.copy2(src, dst)


def differs():
    out = []
    for d, _, files in os.walk(FINAL):
        for f in files:
            src = os.path.join(d, f)
            dst = os.path.join(ROOT, "cli", os.path.relpath(src, FINAL))
            if not os.path.exists(dst) or not filecmp.cmp(src, dst, shallow=False):
                out.append(dst)
    for d, _, files in os.walk(os.path.join(ROOT, "cli")):
        for f in files:
            dst = os.path.join(d, f)
            if not os.path.exists(os.path.join(FINAL, os.path.relpath(dst, os.path.join(ROOT, "cli")))):
                out.append(dst)
    return out


def run(test):
    kind, _, arg = test.partition(":")
    if kind == "l0":
        cmd = [ROC, "test", f"tests/unit/{arg}.roc", "--no-cache"]
    elif kind == "l2":
        cmd = ["tests/commands/run.sh"] + arg.split()
    else:
        cmd = ["tests/run.sh"] + arg.split()
    try:
        r = subprocess.run(cmd, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=TIMEOUT[kind])
    except subprocess.TimeoutExpired:
        return True, "timeout"
    return r.returncode != 0, (r.stdout + r.stderr)


def main():
    want = set(sys.argv[1:])
    report = open(os.path.join(ROOT, "research/slice-026-revert/code-results.md"), "a")
    for mid, fname, edits, tests, what in M:
        if want and mid not in want:
            continue
        restore()
        path = os.path.join(ROOT, LIB, fname)
        text = open(path).read()
        line = None
        for old, new in edits:
            if text.count(old) != 1:
                line = f"{mid}: BAD EDIT ({text.count(old)} matches of {old[:60]!r})"
                break
            text = text.replace(old, new)
        if line is None:
            open(path, "w").write(text)
            built = subprocess.run([ROC, "check", "cli/lib/main.roc"], cwd=ROOT, env=ENV, capture_output=True, text=True)
            if built.returncode != 0:
                line = f"{mid}: DID NOT COMPILE ({what}) " + (built.stdout + built.stderr)[:300].replace("\n", " ")
            else:
                caught_by = None
                for t in tests:
                    failed, _ = run(t)
                    if failed:
                        caught_by = t
                        break
                line = f"{mid}: {'CAUGHT' if caught_by else 'NOT CAUGHT'} by {caught_by or '-'} ({what})"
        restore()
        print(line, flush=True)
        report.write(line + "\n")
        report.flush()
    left = differs()
    print("cli/ equals code-final/" if not left else f"DIFFERENCES: {left}", flush=True)


main()
