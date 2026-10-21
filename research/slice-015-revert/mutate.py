#!/usr/bin/env python3
import os, re, subprocess, sys, shutil
from concurrent.futures import ThreadPoolExecutor
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ["ROC"]
WORK = os.environ.get("WORK", ROOT + "/.work")
OUT = WORK + "/mut"
def f(n): return "cli/lib/" + n + ".roc"

LC, AL, AD, PF, IF, VR, RV, RF, LK = f("Locked"), f("Alias"), f("Add"), f("PickFlow"), f("InstallFlow"), f("Vars"), f("Removal"), f("RemoveFlow"), f("Lookup")
L0L, L0A, L0D, L0V, L0R, L0K = "l0:locked", "l0:alias", "l0:add", "l0:vars", "l0:removal", "l0:lookup"
RSU = "l2:resolve/rs-unmanaged"
RSF = "l2:resolve/rs-failures"
IN1 = "l2:install/in1-flow"
RM1 = "l3:remove/rm1-remove-entries"
UP1 = "l3:update/up1-update-entries"
REPL = 'if !locked.rows.any(|r| r.alias == alias) return Err(internal("${alias} is not in the header"))\n\t\t\tcheck_url(url)?'
M = [
 ("N1", "R-H3 Replace: no URL check", LC, [(REPL, "if !locked.rows.any(|r| r.alias == alias) return Err(internal(\"${alias} is not in the header\"))")], [L0L]),
 ("N2", "R-H9 Replace refuses a path row (as Set)", LC, [(REPL, "check_row(locked, alias)?\n\t\t\tcheck_url(url)?")], [L0L, RSU]),
 ("N3", "Replace: an alias that is not there", LC, [(REPL, "check_url(url)?")], [L0L]),
 ("N4", "R-CC7 spans: Replace names no entry", LC, [("Replace({ alias, .. }) => alias", "Replace({ alias: _alias, .. }) => \"\"")], [L0L]),
 ("N5", "R-AD38 --as over an unmanaged entry is taken", AL, [("if req.as_alias.is_ok() Ok(Unmanaged(alias)) else", "if req.as_alias.is_ok() refuse(Taken) else")], [L0A, RSU]),
 ("N6", "R-AD18 the default alias replaces", AL, [('if req.as_alias.is_ok() Ok(Unmanaged(alias)) else refuse(TakenBy(if row.url.contains("://") "a foreign URL" else "a path entry"))', "Ok(Unmanaged(alias))")], [L0A, RSU]),
 ("N7", "R-AD18 the kind in the text is swapped", AL, [('"a foreign URL" else "a path entry"', '"a path entry" else "a foreign URL"')], [L0A]),
 ("N8", "R-AD18 the text does not name the replace", AL, [(" Use --as <alias>, or --as ${alias} to replace that entry.", " Use --as <alias>.")], [L0A, RSU]),
 ("N9", "R-AD38 Replace writes no talon.toml key", AD, [('toml: toml_of(alias, req.selector, req.no_pin),\n\t\t\tnote: Ok("entry changes', 'toml: Err(Nothing),\n\t\t\tnote: Ok("entry changes')], [L0D]),
 ("N10", "R-AD38 R-AD32 a package over the platform entry", AD, [("Ok(old) => if old.is_platform {", "Ok(old) => if !old.is_platform {")], [L0D]),
 ("N11", "R-AD22 R-H9 add X@sel of an unmanaged entry keeps", AD, [("Err(Add.never_changes({ alias: req.alias, value: row.url }))", "Ok({ alias: req.alias, header: Keep, url: row.url, toml: Err(Nothing), note: Err(None) })")], [L0D, RSU]),
 ("N12", "R-AD21 the note names a command", AD, [('note: Ok("${req.alias}: ${row.url} is in the header") })', 'note: Ok("${req.alias}: ${row.url} is in the header\\nRun tln update ${req.alias} to move it.") })')], [L0D, RSU, IN1]),
 ("N13", "R-H9 never_changes: path and foreign swapped", AD, [('kind = if facts.value.contains("://") "a foreign URL" else "a path entry"', 'kind = if facts.value.contains("://") "a path entry" else "a foreign URL"')], [L0D, RSU, UP1]),
 ("N14", "R-H9 never_changes: no --as in the text", AD, [(" To replace it, run tln add <name> --as ${facts.alias}.", "")], [L0D, RSU, UP1]),
 ("N15", "R-H9 update X of an unmanaged entry is no refusal", PF, [("Ok(row) => return Err(Add.never_changes({ alias, value: row.value }))\n\t\t\t\t\tErr(_) => {}", "Ok(_row) => {}\n\t\t\t\t\tErr(_) => {}")], [RSU, UP1]),
 ("N16", "R-H9 slice 009 G3: only a path entry is refused", PF, [("r.alias == alias and unmanaged(r)", "r.alias == alias and r.what == Path")], [RSU]),
 ("N17", "R-H9 the lookup has no unmanaged entity", PF, [(".concat(rows.keep_if(unmanaged).map(", ".concat(rows.keep_if(|_| Bool.False).map(")], [RSU, UP1]),
 ("N18", "C25 R-AD19 --as is a lookup of a header entry", PF, [("Ok(New(name)) if !request.add.as_platform and request.add.as_alias == Err(Unset) and", "Ok(New(name)) if !request.add.as_platform and")], [RSF]),
 ("N19", "R-AD38 R-AD31 Replace edit is a Set (exit 1)", IF, [("op: if unmanaged Replace({ alias: plan.alias, url: c.url }) else Set({ alias: plan.alias, url: c.url }),", "op: Set({ alias: plan.alias, url: c.url }),")], [RSU]),
 ("N20", "R-AD38 the line names no new name", IF, [('"~ ${plan.alias}: ${from.name} -> ${f.name} ${c.version}"', '"~ ${plan.alias}: ${from.name} -> ${c.version}"')], [RSU]),
 ("N21", "R-H9 R-I5 a key of an unmanaged alias is a want", VR, [("|(_, d)| !rows.any(|r| r.alias == d.key))", "|(_, d)| !rows.any(|r| r.alias == d.key and r.what != Path and r.what != Foreign))")], [L0V, RSU]),
 ("N22", "R-RV5 no key goes with an unmanaged entry", RV, [("Ok(file) if !facts.shared => keys_of(file, facts.alias)?", "Ok(file) if !facts.shared and row.what != Path and row.what != Foreign => keys_of(file, facts.alias)?")], [L0R]),
 ("N23", "C28 R-SC6 remove: a path entry is a release", RF, [("Release(ident) => Release({ name: ident.name ?? ident.group.form, series: ident.series, version: ident.version })\n\t\t_ => Unmanaged", "Release(ident) => Release({ name: ident.name ?? ident.group.form, series: ident.series, version: ident.version })\n\t\t_ => Release({ name: r.value, series: \"0\", version: \"1.0.0\" })")], [RM1]),
 ("N24", "R-SC16 an unmanaged entry matches a selector", LK, [("(Ok(range), Ok(version)) => Ranges.admits({ ranges: [range], version })\n\t\t_ => Bool.False", "(Ok(range), Ok(version)) => Ranges.admits({ ranges: [range], version })\n\t\t_ => Bool.True")], [L0K, RM1]),
 ("N25", "R-AD21 the json entry of a kept path entry has the alias as name", PF, [("Err(_) => { alias, name: value, version: \"\", note }", "Err(_) => { alias, name: \"${alias}${value.drop_prefix(value)}\", version: \"\", note }")], [IN1]),
]
def sh(cmd, **kw):
    return subprocess.run(cmd, cwd=ROOT, env=dict(os.environ), capture_output=True, text=True, timeout=1800, **kw)
def build(name, main):
    p = sh([ROC, "build", main, "--output=" + OUT + "/" + name])
    return p.returncode, p.stdout + p.stderr
def run_all(tests):
    shutil.rmtree(OUT, ignore_errors=True)
    os.makedirs(OUT + "/bin")
    needs_l2 = any(t.startswith("l2:") for t in tests)
    needs_l3 = any(t.startswith("l3:") for t in tests)
    jobs = []
    with ThreadPoolExecutor(max_workers=4) as ex:
        if needs_l2: jobs.append(("l2", ex.submit(build, "l2", "tests/commands/main.roc")))
        if needs_l3: jobs.append(("tln", ex.submit(build, "bin/tln", "cli/main.roc")))
        for name, j in jobs:
            rc, out = j.result()
            if rc != 0: return [("build " + name, 1, "Compilation failed\n" + out[-1500:])]
    results = []
    for t in tests:
        kind, what = t.split(":")
        if kind == "l0": cmd = [ROC, "test", f"tests/unit/{what}.roc", "--no-cache"]
        elif kind == "l2":
            cmd = ["tests/commands/run.sh", what]; os.environ["L2BIN"] = OUT + "/l2"
        else:
            cmd = ["tests/run.sh", what]; os.environ["TLN"] = OUT + "/bin/tln"
        p = sh(cmd)
        results.append((t, p.returncode, p.stdout + p.stderr))
    return results
def main():
    flt = sys.argv[1:]
    dry = os.environ.get("DRY") == "1"
    print("| Id | Rules | Mutation | Result |\n| --- | --- | --- | --- |")
    for mid, ids, rel, pairs, tests in M:
        if flt and mid not in flt: continue
        path = f"{ROOT}/{rel}"
        text = open(path).read()
        short = pairs[0][0][:50].replace("\n", " ").replace("\t", " ").replace("|", "/").strip()
        if any(o not in text for o, _ in pairs):
            print(f"| {mid} | {ids} | `{short}`: pattern not found | INVALID |", flush=True); continue
        if dry:
            print(f"| {mid} | {ids} | `{short}` found | |", flush=True); continue
        new = text
        for o, n in pairs: new = new.replace(o, n, 1)
        open(path, "w").write(new)
        try: results = run_all(tests)
        finally: open(path, "w").write(text)
        def broke(rc, out):
            return rc != 0 and (re.search(r"^\s*[1-9][0-9]* compiler errors?", out, re.M) or "Compilation failed" in out or re.search(r"^build of .* failed", out, re.M))
        bad = [out[-800:] for _, rc, out in results if broke(rc, out)]
        if bad:
            print(bad[0], file=sys.stderr)
            print(f"| {mid} | {ids} | `{short}` | INVALID (compile error) |", flush=True); continue
        caught = [t for t, rc, _ in results if rc != 0]
        missed = [t for t, rc, _ in results if rc == 0]
        result = ("caught by " + ", ".join(caught)) if caught else "NOT CAUGHT"
        if caught and missed: result += " (not by " + ", ".join(missed) + ")"
        print(f"| {mid} | {ids} | `{short}` | {result} |", flush=True)
    shutil.rmtree(OUT, ignore_errors=True)
main()
