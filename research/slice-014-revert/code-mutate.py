#!/usr/bin/env python3
import os, re, subprocess, sys, shutil
from concurrent.futures import ThreadPoolExecutor
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ["ROC"]
WORK = os.environ.get("WORK", ROOT + "/.work")
OUT = WORK + "/mut"
def f(n): return "cli/lib/" + n + ".roc"
LK, WH, PF, RF, VR, IF = f("Lookup"), f("Why"), f("PickFlow"), f("RemoveFlow"), f("Vars"), f("InstallFlow")
LO, WY0, VA = "l0:lookup", "l0:why", "l0:vars"
UP = "l3:update/up1-update-entries"
RM = "l3:remove/rm2-workspace"
WY = "l3:why/wy1-why"
RM1 = "l2:remove/rm1-flow"
RSF = "l2:resolve/rs-failures"
M = [
 ("C1", "R-SC16 P0 bugs 1,2,3: find has no version filter", LK, [("matches = if scope == Project all.keep_if(|e| in_selector(ref, e)) else all", "matches = all")], [LO, WY0, RM1, WY]),
 ("C2", "R-SC16 an unmanaged entry matches a selector", LK, [("(Ok(range), Ok(version)) => Ranges.admits({ ranges: [range], version })\n\t\t_ => Bool.False", "(Ok(range), Ok(version)) => Ranges.admits({ ranges: [range], version })\n\t\t_ => Bool.True")], [LO, WY0, WY]),
 ("C3", "R-SC16 find_move: one match is not used", LK, [("\t\t[one] => Ok(existing(one))\n\t\t_ => match ref.selector {", "\t\t[one] if one.alias == \"zzz-none\" => Ok(existing(one))\n\t\t_ => match ref.selector {")], [LO]),
 ("C4", "R-SC16 find_move: the series filter keeps the wrong ones", LK, [("all.keep_if(|e| e.series == series)", "all.keep_if(|e| e.series != series)")], [LO, RSF]),
 ("C5", "R-AU8 alias line needs distinct aliases", LK, [('a != "" and aliases.keep_if(|b| b == a).len() == 1', 'a != ""')], [LO]),
 ("C6", "R-AU8 alias line keeps the caret", LK, [('Range(text) => text.drop_prefix("^")', "Range(text) => text")], [LO, RSF]),
 ("C7", "R-SC16 a range of series has no series", LK, [("if parts.all(is_number) {", "if parts.len() > 0 {")], [LO]),
 ("C8", "R-SC14 last line of find", LK, [('_ => Err(tie(ref.name, entities, matches, "Use a name from the list."))', '_ => Err(tie(ref.name, entities, matches, "Use the full name."))')], [LO, WY0, RM1, WY]),
 ("C9", "R-SC15 printed names use only the matches", LK, [("matches.map(|e| Lookup.printed(entities, e))", "matches.map(|e| Lookup.printed(matches, e))")], [LO]),
 ("C10", "R-WS8 build drops a fact with no alias", LK, [('repeat = fact.alias != "" and built.any(', 'repeat = built.any(')], [LO]),
 ("C11", "R-WS8 build dedups by alias only", LK, [("o.alias == entity.alias and o.name == entity.name and o.series == entity.series", "o.alias == entity.alias")], [LO, RSF]),
 ("C12", "R-SC14 note of a direct entry", LK, [('Direct => "direct (${fact.alias})"', 'Direct => ""')], [LO, WY0]),
 ("C13", "R-SC16 an unmanaged entity has a version", LK, [('Unmanaged => { alias: fact.alias, name: "", series: "", version: Err(None), note }', 'Unmanaged => { alias: fact.alias, name: "", series: "", version: Ok("1.0.0"), note }')], [LO, WY0, WY]),
 ("C14", "R-SC16 text of not in the project has no selector", LK, [('Ok(selector) => "${ref.name}@${selector_text(selector)}"', "Ok(_) => ref.name")], [LO, WY0, WY, RM1]),
 ("C15", "R-WS8 alias form takes the first entity", LK, [("by_alias = if ref.form == Bare entities.keep_if(|e| e.alias == ref.name) else []", "by_alias = if ref.form == Bare entities.keep_if(|e| e.alias == ref.name).take_first(1) else []")], [LO, RSF]),
 ("C16", "R-SC15 printed name of an unmanaged entry", LK, [('printed = |entities, entity| if entity.name == "" {\n\t\tentity.alias', 'printed = |entities, entity| if entity.name == "" {\n\t\tentity.name')], [LO]),
 ("C17", "R-SC6 install find_move: no full name form", LK, [("} else {\n\tentities.keep_if(|e| e.name == ref.name)\n}\n\n# R-AD1", "} else {\n\t[]\n}\n\n# R-AD1")], [LO]),
 ("C18", "R-SC6 row_facts: alias of a non-direct row", WH, [('{ alias: if r.direct r.alias else "", what, role }', "{ alias: r.alias, what, role }")], [WY0]),
 ("C19", "R-SC15 why row key has no series", WH, [('if r.kind == Release r.series else "")\n', '"")\n')], [WY0, WY]),
 ("C20", "R-SC14 row_facts: role of a transitive row", WH, [('Via(r.via ?? "")', "Direct")], [WY0]),
 ("C21", "R-SC6 row_facts: a path entry is a release", WH, [("Release => Release({ name: r.name, series: r.series, version: r.version })\n\t\t\t\t_ => Unmanaged", "_ => Release({ name: r.name, series: r.series, version: r.version })")], [WY0, WY]),
 ("C22", "R-SC16 update reads the name as a filter", PF, [("if request.command == Update Lookup.find_move(scope, ref, entities) else add_lookup(request, ref, entities)", "Lookup.find(scope, ref, entities)")], [RSF]),
 ("C23", "R-SC14 platform note in update", PF, [("role: if v.is_platform Platform else Direct,", "role: Direct,")], [RSF]),
 ("C24", "R-SC16 add never moves (Q1)", PF, [("entities.keep_if(|e| e.name == name).len() >= 2", "entities.keep_if(|e| e.name == name).len() >= 99")], [RSF]),
 ("C25", "R-SC16 add moves with --as (guard, no test)", PF, [("Ok(New(name)) if !request.add.as_platform and request.add.as_alias == Err(Unset) and", "Ok(New(name)) if !request.add.as_platform and")], [RSF]),
 ("C26", "R-SC15 remove has no series", RF, [("series: ident.series, version: ident.version })", 'series: "", version: ident.version })')], [RM1]),
 ("C27", "R-SC16 remove moves", RF, [("Lookup.find(Scope.Project, ref, entities)", "Lookup.find_move(Scope.Project, ref, entities)")], [RM1]),
 ("C28", "R-SC6 remove: a path entry is a release", RF, [("Release(ident) => Release({ name: ident.name ?? ident.group.form, series: ident.series, version: ident.version })\n\t\t_ => Unmanaged", "Release(ident) => Release({ name: ident.name ?? ident.group.form, series: ident.series, version: ident.version })\n\t\t_ => Release({ name: r.value, series: \"0\", version: \"1.0.0\" })")], [RM1]),
 ("C29", "R-WS8 text of Vars", VR, [('Use a name from the list."', 'Use the full name."')], [VA]),
 ("C30", "R-SO20 json note of install and update", IF, [("Ok({ ..outcome, notes: pin_notes.concat(outcome.notes) })", "Ok(outcome)")], [UP]),
 ("C31", "R-SO20 note order of install and update", IF, [("notes: pin_notes.concat(outcome.notes)", "notes: outcome.notes.concat(pin_notes)")], [UP]),
 ("C32", "R-SO20 json note of remove", RF, [("notes: pin_notes.concat(force_notes).concat(ran.notes),", "notes: force_notes.concat(ran.notes),")], [RM]),
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
