#!/usr/bin/env python3
"""Revert check of slice 023 (TW12): small mutations of the private reference, each run with the tests that should catch it.
Usage: research/slice-023-revert/mutate.py [id ...]   (no id: all). The reference must be in cli/ (research/slice-023-revert/reference-all/).
The file is put back after each run. Result: research/slice-023-revert/results.md.
"""
import os, subprocess, sys, shutil

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
os.chdir(ROOT)
ROC = f"{ROOT}/cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"
ENV = dict(os.environ, XDG_CACHE_HOME=f"{ROOT}/.work/cache", ROC_CACHE_DIR=f"{ROOT}/.work/cache/roc", ROC=ROC)

P = "cli/lib/Proxy.roc"
# (id, file, old, new, layers) layers: l0 = tests/unit/proxy.roc, l2 = tests/commands/run.sh proxy/, l3 = tests/run.sh px1
M = [
    ("M1", P, 'base.drop_suffix(".exe") == "roc"', 'base == "roc"', "l0 l3"),
    ("M2", P, 'base = after_slash.split_on("\\\\").last() ?? after_slash', 'base = after_slash', "l0"),
    ("M3", P, 'base.drop_suffix(".exe") == "roc"', 'base.drop_suffix(".exe").starts_with("roc")', "l0"),
    ("M4", P, 'argument: Ok(first.drop_prefix("+")), rest }', 'argument: Ok(first.drop_prefix("+")), rest: args }', "l0 l3"),
    ("M5", P, 'args.find_first(|a| a.ends_with(".roc"))', 'args.find_first(|a| a.contains(".roc"))', "l0"),
    ("M6", P, '[first, ..] => if ["version", "help", "install"].contains(first) NoFile else Main', '[first, ..] => if ["help", "install"].contains(first) NoFile else Main', "l0 l2"),
    ("M7", P, '["run", _, ..] => NoFile\n', '', "l0"),
    ("M8", P, '== Ok(("TALON_PROXY", "0"))', '== Ok(("TALON_PROXY", "1"))', "l0 l2 l3"),
    ("M9", P, '== Ok(("TALON_IN_PROXY", "1"))', '!= Err(NotFound)', "l0"),
    ("M10", P, '(Err(_), Err(_), Ok(pin)) => Ok(pin)', '(Err(_), Err(_), Ok(pin)) if facts.req.is_err() => Ok(pin)', "l0 l2"),
    ("M11", P, 'match facts.installed.find_first(|i| Pin.same_id(pin, i)) {', 'match facts.installed.find_first(|i| pin == i) {', "l0 l2"),
    ("M12", P, 'Err(_) => match facts.path {\n\t\t\t\t\tOk(id) if Pin.same_id(pin, id)', 'Err(_) => match facts.path {\n\t\t\t\t\tOk(id) if Bool.True', "l0"),
    ("M14", P, 'if run.installed.contains(run.id) {', 'if run.installed.contains(run.id) and run.path.is_err() {', "l0 l2"),
    ("M15", P, '[("XDG_CACHE_HOME", resolved(facts.xdg)), ("ROC_CACHE_DIR", resolved(facts.build)), ("TALON_IN_PROXY", "1")]', '[("TALON_IN_PROXY", "1"), ("XDG_CACHE_HOME", resolved(facts.xdg)), ("ROC_CACHE_DIR", resolved(facts.build))]', "l0 l2"),
    ("M16", P, 'Err(Failed) => Text.resolve(p.path, p.path)', 'Err(Failed) => p.path', "l0"),
    ("M17", P, 'if facts.opted_out {\n\t\t\t[("TALON_IN_PROXY", "1")]', 'if Bool.False {\n\t\t\t[("TALON_IN_PROXY", "1")]', "l0 l2 l3"),
    ("M18", P, 'last_use = |now| "${Clock.format_utc(now)}\\n"', 'last_use = |now| Clock.format_utc(now)', "l0"),
    ("M19", P, ', or set TALON_AUTO_INSTALL=yes.")', '.")', "l0"),
    ("M20", P, 'start_failed = |run| Fail.new(Environment,', 'start_failed = |run| Fail.new(Internal,', "l0 l2"),
    ("R1", P, 'argv: [program].concat(split.rest)', 'argv: [program]', "l2 l3"),
    ("R2", P, 'if !opted and installed.contains(sel.id) {', 'if Bool.False {', "l2 l3"),
    ("R3", P, 'if !opted and installed.contains(sel.id) {', 'if !opted {', "l2"),
    ("R4", P, 'picked = if settled or Proxy.in_proxy(env) {', 'picked = if Proxy.in_proxy(env) {', "l2"),
    ("R5", P, 'picked = if settled or Proxy.in_proxy(env) {', 'picked = if settled {', "l2 l3"),
    ("R6", P, 'Ok(file) => Known.record_recent!(fx, { roots, files: [file], now })?', 'Ok(_) => {}', "l2 l3"),
    ("R7", "cli/lib/Known.roc", 'record_with!(fx, facts, After(86400))', 'record_with!(fx, facts, Always)', "l2"),
    ("R8", P, 'Project.find!(fx, { start: cwd, file: Ok(file), home }).map_err(|_| None)', 'Ok(Project.find!(fx, { start: cwd, file: Ok(file), home })?)', "l2"),
    ("R9", P, 'if !opted and installed.contains(sel.id) {', 'if installed.contains(sel.id) {', "l2 l3"),
    ("R10", P, 'fx.canonical!([xdg, roots.build]).map(', 'fx.canonical!([]).map(', "l2 l3"),
    ("R11", P, 'if sel.state == Missing {', 'if sel.state == Missing and Bool.False {', "l2"),
    ("R12", P, 'Ok(code) => Ok(code)\n\t\tErr(NotStarted(text))', 'Ok(_) => Ok(0)\n\t\tErr(NotStarted(text))', "l2 l3"),
    ("R13", P, 'facts = { argument: split.argument,', 'facts = { argument: Err(Unset),', "l2 l3"),
    ("R14", P, 'Ok(ws) => [{ role: Toml, path: Text.join(ws.root, "talon.toml") }]', 'Ok(_) => match project.toml {\n\t\t\t\t\tOk(path) => [{ role: Toml, path }]\n\t\t\t\t\tErr(NoToml) => []\n\t\t\t\t}', "l2"),
    ("R15", "cli/RealFx.roc", 'Signaled(signal) => Ok(128 + signal)', 'Signaled(signal) => Ok(signal)', "l3"),
    ("R16", "cli/RealFx.roc", '.envs_str(run.env)', '', "l3"),
    ("R17", "cli/RealFx.roc", '.stdin(Inherit).stdout(Inherit).stderr(Inherit)', '.stdin(Inherit).stdout(Capture).stderr(Inherit)', "l3"),
    ("R18", "cli/lib/Run.roc", 'if Proxy.is_proxy(fx.program_name!()) Proxy.run!(fx) else Run.tln!(fx)', 'Run.tln!(fx)', "l2 l3"),
    ("R19", "cli/lib/Install.roc", 'at = facts.found.find_first(|f| $entries.any(|e| e.path == f.path and e.id == Id(found)))', 'at = facts.found.first()', "l3"),
    ("R20", "cli/RealFx.roc", 'Ok(name) => name.display()', 'Ok(name) => "tln"', "l3"),
    ("R23", P, 'if !opted {\n\t\tmatch found {', 'if Bool.True {\n\t\tmatch found {', "l2"),
    ("R24", P, 'canonical = if opted {', 'canonical = if Bool.False {', "l2 l3"),
    ("R25", P, 'Err(NoneInRange) => return Err(Compiler.failure(NoneInRange(req_text)))', 'Err(NoneInRange) => return Err(Compiler.failure(NoCompiler))', "l2"),
    ("R21", P, 'now = if opted {\n\t\t0', 'now = if Bool.False {\n\t\t0', "l2"),
    ("R26", P, 'Project.find_loose!(fx, { start: cwd, file: Ok(file), home }).map_ok(|f| f.project).map_err(|_| None)', 'Project.find!(fx, { start: cwd, file: Ok(file), home }).map_err(|_| None)', "l2"),
    ("R27", "cli/lib/Project.roc", 'Ok({ project, header: Project.check_header({ path, text }).map_ok(|_| {}) })', 'Ok({ project: { ..project, toml: Err(NoToml) }, header: Project.check_header({ path, text }).map_ok(|_| {}) })', "l2"),
    ("R28", "cli/lib/Compiler.roc", 'if !(Pin.is_id(text) or is_named_build(text)) {', 'if Compiler.kind(text) == Local {', "l0c"),
    ("R29", "cli/lib/Compiler.roc", ' and !name.contains("/") and', ' and', "l0c"),
    ("R30", "cli/lib/Compiler.roc", ' and name.trim() == name and !name.contains(" ")', '', "l0c"),
    ("R31", "cli/lib/Compiler.roc", '!name.drop_prefix(prefix).is_empty()) and !name.contains("/")', 'Bool.True) and !name.contains("/")', "l0c"),
    ("R32", "cli/lib/Compiler.roc", '["git-", "link-", "copy-"].any(|prefix| name.starts_with(prefix) and !name.drop_prefix(prefix).is_empty()) and !name.contains("/")', '["git-", "link-"].any(|prefix| name.starts_with(prefix) and !name.drop_prefix(prefix).is_empty()) and !name.contains("/")', "l0c"),
    ("R22", P, 'early = split.argument.is_ok() or toolchain.is_ok()', 'early = Bool.False', "l2"),
]


def run(cmd):
    r = subprocess.run(cmd, shell=True, env=ENV, capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def layers_failed(layers):
    failed = []
    for layer in layers.split():
        if layer == "l0c":
            rc, out = run(f"{ROC} test tests/unit/compiler.roc --no-cache")
        elif layer == "l0":
            rc, out = run(f"{ROC} test tests/unit/proxy.roc --no-cache")
        elif layer == "l2":
            rc, out = run("tests/commands/run.sh proxy/")
        else:
            rc, out = run("tests/run.sh px1")
        if rc != 0:
            failed.append(layer)
    return failed


def main():
    want = sys.argv[1:]
    rows = []
    for (mid, path, old, new, layers) in M:
        if want and mid not in want:
            continue
        text = open(path).read()
        if old not in text:
            rows.append((mid, path, "NOT APPLIED (text not found)", ""))
            print(mid, "NOT APPLIED")
            continue
        shutil.copy(path, "/tmp/mutate.keep")
        open(path, "w").write(text.replace(old, new, 1))
        try:
            failed = layers_failed(layers)
        finally:
            shutil.copy("/tmp/mutate.keep", path)
        status = "caught by " + " ".join(failed) if failed else "NOT CAUGHT"
        rows.append((mid, path, status, layers))
        print(mid, status, flush=True)
    out = "research/slice-023-revert/results.md"
    old = {}
    if os.path.exists(out):
        for line in open(out).read().split("\n")[2:]:
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) == 4:
                old[cells[0]] = tuple(cells)
    for r in rows:
        old[r[0]] = r
    order = [m[0] for m in M]
    merged = [old[i] for i in order if i in old]
    with open(out, "w") as f:
        f.write("| Id | File | Result | Layers run |\n| --- | --- | --- | --- |\n")
        for r in merged:
            f.write("| %s | %s | %s | %s |\n" % tuple(r))
    caught = sum(1 for r in merged if r[2].startswith("caught"))
    print(f"caught {caught} of {len(merged)}")


main()
