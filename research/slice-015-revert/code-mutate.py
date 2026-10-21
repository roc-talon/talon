#!/usr/bin/env python3
import os, re, subprocess, sys, shutil
from concurrent.futures import ThreadPoolExecutor
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ["ROC"]
WORK = os.environ.get("WORK", ROOT + "/.work")
OUT = WORK + "/mut"
def f(n): return "cli/lib/" + n + ".roc"

LC, AL, AD, PF, IF, RB = f("Locked"), f("Alias"), f("Add"), f("PickFlow"), f("InstallFlow"), f("ResolveBase")
L0L, L0A, L0D, L0V, L0R, L0K = "l0:locked", "l0:alias", "l0:add", "l0:vars", "l0:removal", "l0:lookup"
RSU = "l2:resolve/rs-unmanaged"
RSF = "l2:resolve/rs-failures"
IN1 = "l2:install/in1-flow"
RM1 = "l3:remove/rm1-remove-entries"
UP1 = "l3:update/up1-update-entries"
REPL = 'if !locked.rows.any(|r| r.alias == alias) return Err(internal("${alias} is not in the header"))\n\t\t\tcheck_url(url)?'
M = [
 ("C1", "R-H3 Replace: no URL check", LC, [(REPL, "if !locked.rows.any(|r| r.alias == alias) return Err(internal(\"${alias} is not in the header\"))")], [L0L]),
 ("C2", "R-H9 Replace refuses a path row (as Set)", LC, [(REPL, "check_row(locked, alias)?\n\t\t\tcheck_url(url)?")], [L0L, RSU]),
 ("C3", "Replace: an alias that is not there", LC, [(REPL, "check_url(url)?")], [L0L]),
 ("C4", "R-AD38 --as over an unmanaged entry is taken", AL, [("if req.as_alias.is_ok() Ok(Unmanaged(alias)) else", "if req.as_alias.is_ok() refuse(Taken) else")], [L0A, RSU]),
 ("C5", "R-AD18 the default alias replaces", AL, [("Ok(kind) => if req.as_alias.is_ok() Ok(Unmanaged(alias)) else Err(", "Ok(kind) => if kind != \"\" Ok(Unmanaged(alias)) else Err(")], [L0A, RSU]),
 ("C6", "R-AD18 the kind in the text is swapped", AL, [('Ok("a foreign URL") else Ok("a path entry")', 'Ok("a path entry") else Ok("a foreign URL")')], [L0A]),
 ("C7", "R-AD18 the text does not name the replace", AL, [(", or --as ${alias} to replace that entry.", ".")], [L0A, RSU]),
 ("C8", "R-AD38 Replace writes no talon.toml key", AD, [('toml: toml_of(alias, req.selector, req.no_pin),\n\t\t\tnote: Ok("entry changes', 'toml: Err(Nothing),\n\t\t\tnote: Ok("entry changes')], [L0D]),
 ("C9", "R-AD38 R-AD32 a package over the platform entry", AD, [("Ok(old) => if old.is_platform {", "Ok(old) => if !old.is_platform {")], [L0D]),
 ("C10", "R-AD22 R-H9 add X@sel of an unmanaged entry keeps", AD, [("Err(Add.never_changes({ alias: req.alias, value: row.url }))", "Ok({ alias: req.alias, header: Keep, url: row.url, toml: Err(Nothing), note: Err(None) })")], [L0D, RSU]),
 ("C11", "R-AD21 the note names a command", AD, [('note: Ok("${req.alias}: ${row.url} is in the header") })', 'note: Ok("${req.alias}: ${row.url} is in the header\\nRun tln update ${req.alias} to move it.") })')], [L0D, RSU, IN1]),
 ("C12", "R-H9 never_changes: path and foreign swapped", AD, [('if value.contains("://") "a foreign URL" else "a path entry"', 'if value.contains("://") "a path entry" else "a foreign URL"')], [L0D, RSU, UP1]),
 ("C13", "R-H9 never_changes: no --as in the text", AD, [(" To replace it, run tln add <name> --as ${facts.alias}.", "")], [L0D, RSU, UP1]),
 ("C14", "R-AD38 the note of a replace is not the entry note", AD, [('note: Ok("entry changes: ${old.url}', 'note: Ok("entry moves: ${old.url}')], [L0D, RSU]),
 ("C15", "R-H4 decide_alias: no row is unmanaged", AD, [("Err(Foreign) => Bool.True\n}", "Err(Foreign) => Bool.False\n}")], [L0D, RSU]),
 ("C16", "R-H9 update X of an unmanaged entry is no refusal", PF, [("Lookup.Existing({ alias: a, name: \"\", .. }) if request.command == Update => return", "Lookup.Existing({ alias: a, name: \"\", .. }) if request.command == Install => return")], [RSU, UP1]),
 ("C17", "R-H9 slice 009 G3: only a path entry is an entity", PF, [("Release(_) => Err(NotUnmanaged)", "Release(_) | Foreign => Err(NotUnmanaged)")], [RSU]),
 ("C18", "R-H9 the lookup has no unmanaged entity", PF, [("\t\tmembers.join_map(\n", "\t\tmembers.keep_if(|_| Bool.False).join_map(\n")], [RSU, UP1]),
 ("C19", "R-AD21 the json entry of a kept path entry has the alias as name", PF, [("Err(_) => { alias, name: plan.url,", "Err(_) => { alias, name: alias,")], [IN1]),
 ("C20", "Q1 R-AD38 R-I3 the pick ignores the key of the replaced alias", PF, [("replaced_key_range(loaded, current, key) ?? \"*\"", "replaced_key_range(loaded, current, \"\") ?? \"*\"")], [RSU]),
 ("C27", "R-SL5 Q1 latest is a selector for the key range", PF, [("Ok(Latest) | Err(None) => replaced_key_range", "Err(None) => replaced_key_range")], [RSU]),
 ("C21", "Q1 R-AD38 R-I3 the key of [overrides] is ignored", PF, [("t.intent.deps.concat(t.intent.overrides).find_first", "t.intent.deps.find_first")], [RSU]),
 ("C22", "R-AD38 R-AD31 Replace edit is a Set (exit 1)", IF, [("op: Replace({ alias, url: new.url }),", "op: Set({ alias, url: new.url }),")], [RSU]),
 ("C23", "R-AD38 the line names no old value", IF, [('line: "~ ${alias}: ${old} -> ${new.name} ${new.version}",', 'line: "~ ${alias}: ${new.name} ${new.version}",')], [RSU]),
 ("C24", "R-AD31 the flow replaces the first platform row, not the alias", IF, [("Replace => match acc.header.find_first(|r| r.alias == plan.alias) {", "Replace => match acc.header.find_first(|r| r.is_platform) {")], [RSU]),
 ("C25", "R-AD38 the json of a replace has no old value", IF, [("did: Moved({ alias, from: { name: old, version: \"\" },", "did: Moved({ alias, from: { name: \"\", version: \"\" },")], [RSU]),
 ("C26", "R-AL2 entries_after ignores Replace", RB, [("Replace({ alias, url }) => rows.map(|r| if r.alias == alias { ..r, value: url } else r)", "Replace(_) => rows")], [RSU]),
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
