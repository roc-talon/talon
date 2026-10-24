#!/usr/bin/env python3
"""Revert check of the code of slice 023 (TW12, filtered runs only, no full sweep).

For each mutation: all files are first put back from code-final/ (so a kill is safe), then one small change in one file, a `roc check`,
then only the tests that should catch it. The first test that fails ends the run of that mutation (CAUGHT). A test that runs longer than the
timeout counts as CAUGHT (a loop). At the end all files are put back and compared with code-final/.

Usage: python3 -I research/slice-023-revert/code-mutate.py [id ...]     (from the repo root)
Output: one line for each mutation: id, CAUGHT or NOT CAUGHT, the test that failed. Last line: SAME or DIFFERENT.
"""
import os, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FINAL = os.path.join(ROOT, "research/slice-023-revert/code-final")
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))
TIMEOUT = {"l0": 120, "l2": 300, "l3": 300, "sh": 600}
FILES = ["cli/lib/Proxy.roc", "cli/lib/Known.roc", "cli/lib/Install.roc", "cli/lib/Project.roc", "cli/lib/Compiler.roc", "cli/RealFx.roc", "scripts/test.sh"]
P, K, I, J, C, X, S = FILES
L0P = ["l0:proxy"]
L2 = ["l2:proxy/px1-flow"]
L3 = ["l3:compilers/px1-proxy"]
L3F = ["l3:fx/px1-real-fx-exec"]
L0C = ["l0:compiler"]
# Each list ends with the layers that may also catch it, so a test gap shows as "caught by l2" and not as "not caught".
M = [
    ("P1", P, [('base == "roc" or base == "roc.exe"', 'base == "roc"')], L0P + L3, "R-ST8: roc.exe is not the proxy"),
    ("P3", P, [('if first.starts_with("+") and first != "+" =>', 'if first.starts_with("+") =>')], L0P + L2, "R-SO1: a + alone is an id"),
    ("P4", P, [('{ argument: Ok(first.drop_prefix("+")), rest }', '{ argument: Ok(first.drop_prefix("+")), rest: [first].concat(rest) }')], L0P + L2 + L3, "R-PX3: the +id stays in the arguments"),
    ("P6", P, [(' and !arg.contains("://")', '')], L0P + L2, "R-SO8: a URL that ends in .roc is a file"),
    ("P7", P, [('!arg.starts_with("-") and ', '')], L0P + L2, "R-SO8: an option that ends in .roc is a file"),
    ("P9", P, [('Ok("run") => args.drop_first(1).any(|arg| !arg.starts_with("-"))', 'Ok("run") => Bool.True')], L0P + L2, "R-SO8: run with no source has no file"),
    ("P10", P, [('env.contains(("TALON_PROXY", "0"))', 'env.contains(("TALON_PROXY", "1"))')], L0P + L2 + L3, "R-PX7: the other value opts out"),
    ("P12", P, [('(Err(Unset), Err(Unset), Ok(pin)) =>', '(_, _, Ok(pin)) =>')], L0P + L2, "R-SO1: the pin beats rank 1 and 2"),
    ("P13", P, [('Pin.same_id(pin, id))', 'pin == id)')], L0P + L2, "R-CV1: only the same text is the pin"),
    ("P14", P, [('Ok(on_path) if Pin.same_id(pin, on_path) =>', 'Ok(on_path) if on_path == pin =>')], L0P + L2, "R-CV1, R-SO10: the other form of the id on PATH"),
    ("P15", P, [(' and !run.installed.contains(run.id)', '')], L0P + L2, "R-PX2: the file on PATH wins over the managed copy"),
    ("P17", P, [('Text.resolve("/", dir.path)', 'dir.path')], L0P + L3, "R-PX6: a .. reaches roc"),
    ("P18", P, [('"${Clock.format_utc(now)}\\n"', 'Clock.format_utc(now)')], L0P + L2, "R-CC9: no line end in .last-use"),
    ("G1", P, [('argv: [program].concat(split.rest)', 'argv: [program]')], L2 + L3, "R-PX3: the arguments are dropped"),
    ("G2", P, [('if !off and installed.contains(chosen.id) {', 'if off and installed.contains(chosen.id) {')], L2 + L3, "R-CC9: no .last-use"),
    ("G4", P, [('_ => if Proxy.in_proxy(env) Err(NoCompiler) else Install.on_path_file!(fx, roots)', '_ => Install.on_path_file!(fx, roots)')], L2 + L3, "R-EV17: TALON_IN_PROXY is ignored"),
    ("G5", P, [('sel.state == Installed and sel.rank != Range =>', 'sel.state == Installed =>')], L2, "R-SO4: rank 4 does not look at PATH"),
    ("G6", P, [('Ok(sel) if sel.state == Installed and sel.rank != Range =>', 'Ok(sel) if sel.rank != Range =>')], L2, "R-SO10: a missing pin does not look at PATH"),
    ("G7", P, [('files: project_files(found), now })?', 'files: [], now })?')], L2 + L3, "R-PD10: the project is not recorded"),
    ("G9", P, [('canonical = if off [] else fx.canonical!(', 'canonical = fx.canonical!(')], L2 + L3, "R-PX7: canonical in an opted out run"),
    ("G10", P, [('Err(NoneInRange) => return Err(Compiler.failure(NoneInRange(loaded.req_text)))', 'Err(NoneInRange) => return Err(Compiler.failure(NoCompiler))')], L2, "R-SO13: NoneInRange is NoCompiler"),
    ("G12", P, [('Ok(code) => Ok(code)', 'Ok(_) => Ok(0)')], L2 + L3, "R-E1: the exit code of the child is lost"),
    ("G13", P, [('argument: split.argument,', 'argument: Err(Unset),')], L2 + L3, "R-SO1: rank 1 is ignored"),
    ("G14", P, [('Ok(ws) => [Text.join(ws.root, "talon.toml")]', 'Ok(_) => []')], L2, "R-PD6: the root talon.toml of a workspace is not read"),
    ("G16", P, [('Ok(typed) if !run.skip =>', 'Ok(typed) =>')], L2, "R-PD7: the project is searched in an early opted out run"),
    ("R26", P, [('Project.find_loose!(fx, { start: run.cwd, file: Ok(typed), home })', 'Project.find!(fx, { start: run.cwd, file: Ok(typed), home }).map_ok(|p| { project: p, header: Ok({}) })')], L2, "R-TF5: a bad header stops the project"),
    ("R27", J, [('Ok({ project, header: Project.check_header({ path, text }).map_ok(|_| {}) })', 'Ok({ project: { ..project, toml: Err(NoToml) }, header: Project.check_header({ path, text }).map_ok(|_| {}) })')], L2, "R-TF5: the talon.toml is lost with a bad header"),
    ("K1", K, [('record_with!(fx, facts, After(86400))', 'record_with!(fx, facts, Always)')], L2, "R-PD10: always write"),
    ("I1", I, [('hit = |file| entries.any(|e| e.path == file.path and e.size == file.size and e.mtime == file.mtime and e.id == Id(id))', 'hit = |_file| entries.any(|e| e.id == Id(id))')], L3 + L2, "R-SO9: the path of a cache hit is the first file"),
    ("I2", I, [('finished.id.map_ok(|id| { id, path: file.path })', 'finished.id.map_ok(|id| { id, path: "" })')], L2 + L3, "R-SO9: the path of a run of roc version is lost"),
    ("C1", C, [('if Pin.is_id(text) or is_named_build(text) {', 'if Pin.is_id(text) {')], L0C, "R-NS6: a named build is refused"),
    ("C2", C, [(' and !name.contains("/") and', ' and')], L0C, "R-NS6: a / in the name"),
    ("C3", C, [('["git-", "link-", "copy-"].any(|prefix| text.starts_with(prefix) and is_safe_name', '["git-", "link-"].any(|prefix| text.starts_with(prefix) and is_safe_name')], L0C, "R-NS6: no copy-"),
    ("X1", X, [('Signaled(signal) => Ok(128 + signal)', 'Signaled(signal) => Ok(signal)')], L3F + L3, "R-E1: the signal code"),
    ("X2", X, [('.envs_str(run.env)', '')], L3F + L3, "R-HF6: no added variables"),
    ("X3", X, [('Ok(name) => name.display()', 'Ok(_) => "tln"')], L3F + L3, "R-HF9: the program name"),
]


def restore():
    for f in FILES:
        with open(os.path.join(FINAL, f)) as src:
            text = src.read()
        with open(os.path.join(ROOT, f), "w") as dst:
            dst.write(text)


def run(test):
    kind, _, arg = test.partition(":")
    if kind == "l0":
        cmd = [ROC, "test", f"tests/unit/{arg}.roc", "--no-cache"]
    elif kind == "l2":
        cmd = ["tests/commands/run.sh"] + arg.split()
    elif kind == "l3":
        cmd = ["tests/run.sh"] + arg.split()
    else:
        cmd = arg.split()
    try:
        r = subprocess.run(cmd, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=TIMEOUT[kind])
    except subprocess.TimeoutExpired:
        return True, "timeout"
    return r.returncode != 0, (r.stdout + r.stderr)


def main():
    want = set(sys.argv[1:])
    for mid, fname, edits, tests, what in M:
        if want and mid not in want:
            continue
        restore()
        path = os.path.join(ROOT, fname)
        text = open(path).read()
        for old, new in edits:
            if text.count(old) != 1:
                print(f"{mid}: BAD EDIT ({text.count(old)} matches of {old[:60]!r})", flush=True)
                break
            text = text.replace(old, new)
        else:
            open(path, "w").write(text)
            built = subprocess.run([ROC, "check", "cli/lib/main.roc"], cwd=ROOT, env=ENV, capture_output=True, text=True)
            if fname != S and built.returncode != 0:
                print(f"{mid}: DID NOT COMPILE ({what}) " + built.stdout[:300].replace("\n", " "), flush=True)
                continue
            caught_by = None
            for t in tests:
                failed, _ = run(t)
                if failed:
                    caught_by = t
                    break
            print(f"{mid}: {'CAUGHT' if caught_by else 'NOT CAUGHT'} by {caught_by or '-'} ({what})", flush=True)
    restore()
    same = all(open(os.path.join(ROOT, f)).read() == open(os.path.join(FINAL, f)).read() for f in FILES)
    print("SAME as code-final" if same else "DIFFERENT from code-final")


main()
