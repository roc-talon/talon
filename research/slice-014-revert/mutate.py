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
NARROW_STAY = "\tStay => match ref.selector {\n\t\tErr(None) => matched\n\t\tOk(sel) => match range_of(sel) {"
M = [
 ("M1", "R-SC16 P0 bugs 1,2,3", LK, [("narrowed = if scope == Project narrow(how, ref, matched) else matched", "narrowed = if scope == Project and how == Move narrow(how, ref, matched) else matched")], [LO, WY0, RM1, WY]),
 ("M2", "R-SC16 unmanaged has no version", LK, [("\t\t\t\t\tErr(None) => Bool.False\n\t\t\t\t},\n\t\t\t)\n\t\t\tErr(NoRange)", "\t\t\t\t\tErr(None) => Bool.True\n\t\t\t\t},\n\t\t\t)\n\t\t\tErr(NoRange)")], [LO, WY0, WY]),
 ("M3", "R-SC16 version, not series", LK, [(NARROW_STAY, "\tStay => match ref.selector {\n\t\tErr(None) => matched\n\t\tOk(sel) => match (match series_of(sel) {\n\t\t\tOk(s) => Ok(\"^${s}\")\n\t\t\tErr(_) => range_of(sel)\n\t\t}) {")], [LO, WY0, WY]),
 ("M4", "R-SC16 moving: series filter", LK, [("Ok(series) => matched.keep_if(|e| e.series == series)", "Ok(_) => matched")], [LO, RSF]),
 ("M5", "R-SC16 moving: 1 match is used", LK, [("Move => if matched.len() <= 1 {", "Move => if matched.len() <= 0 {")], [LO]),
 ("M6", "R-SC14 no alias line", LK, [("Move => Err(tie(ref, matched, entities, alias_hint(ref, matched)))", "Move => Err(tie(ref, matched, entities, Err(None)))")], [LO, RSF]),
 ("M7", "R-SC14 alias line needs distinct aliases", LK, [('distinct = aliases.all(|a| a != "" and aliases.keep_if(|o| o == a).len() == 1)', 'distinct = aliases.all(|a| a != "")')], [LO]),
 ("M8", "R-SC16 a range of series has no series", LK, [('if text.starts_with("^") {', 'if Bool.True {'), ('digits = |p| p != "" and p.to_utf8().all(|b| b >= 48 and b <= 57)', 'digits = |p| p != ""')], [LO]),
 ("M9", "R-SC14 last line", LK, [('Err(None) => "Use a name from the list."', 'Err(None) => "Use the full name."')], [LO, WY0, RM1, RSF, WY]),
 ("M10", "R-SC15 printed over the whole scope", LK, [("Lookup.printed(scope_entities, e)", "Lookup.printed(matches, e)")], [LO]),
 ("M11", "R-WS8 build keeps repeated facts", LK, [('if e.alias != "" and found.any(|o| o.alias == e.alias and o.name == e.name and o.series == e.series) found else found.append(e)', "found.append(e)")], [LO]),
 ("M12", "R-WS8 dedup by alias only", LK, [("found.any(|o| o.alias == e.alias and o.name == e.name and o.series == e.series)", "found.any(|o| o.alias == e.alias)")], [LO, RSF]),
 ("M13", "R-SC14 note of a direct entry", LK, [('Direct => "direct (${f.alias})"', 'Direct => ""')], [LO, WY0]),
 ("M14", "R-SC16 unmanaged entity with a version", LK, [('Unmanaged => { alias: f.alias, name: "", series: "", version: Err(None), note }', 'Unmanaged => { alias: f.alias, name: "", series: "", version: Ok("1.0.0"), note }')], [LO, WY0, WY]),
 ("M15", "R-WS8 alias form takes the first entity", LK, [("Bare => entities.keep_if(|e| e.alias == ref.name)\n\t\t_ => []", "Bare => entities.keep_if(|e| e.alias == ref.name).take_first(1)\n\t\t_ => []")], [LO, RSF]),
 ("M16", "R-SC16 text of not in the project", LK, [('Ok(sel) => "${ref.name}@${sel_text(sel)}"', "Ok(_) => ref.name")], [LO, WY0, WY, RM1]),
 ("M17", "R-SC15 printed unmanaged", LK, [('if e.name == "" {\n\t\t\te.alias', 'if e.name == "" {\n\t\t\te.name')], [LO]),
 ("M18", "R-SC6 alias of a non-direct row", WH, [('row_facts = |rows| rows.map(\n\t\t|r| {\n\t\t\talias: if r.direct r.alias else "",', 'row_facts = |rows| rows.map(\n\t\t|r| {\n\t\t\talias: r.alias,')], [WY0]),
 ("M19", "R-SC15 why row key has no series", WH, [("x.alias == alias and x.name == name and x.series == series", "x.alias == alias and x.name == name and (x.series == series or Bool.True)")], [WY0, WY]),
 ("M20", "R-SC16 update reads the name as a filter", PF, [("(if request.command == Update Lookup.find_move(scope, ref, entities) else Lookup.find(scope, ref, entities))", "Lookup.find(scope, ref, entities)")], [RSF]),
 ("M21", "R-SC14 platform note in update", PF, [("role: if v.is_platform Platform else Direct,", "role: Direct,")], [RSF]),
 ("M22", "R-SC15 remove series", RF, [("series: ident.group.series, version: ident.version })", 'series: "", version: ident.version })')], [RM1]),
 ("M23", "R-SC16 remove moves", RF, [("Lookup.find(Scope.Project, ref, entities)", "Lookup.find_move(Scope.Project, ref, entities)")], [RM1]),
 ("M24", "R-WS8 text", VR, [('Use a name from the list."))', 'Use the full name."))')], [VA]),
 ("M25", "R-SO20 json note of install and update", IF, [("Ok({ ..outcome, notes: ResolveBase.pin_notes(decision).concat(outcome.notes) })", "Ok(outcome)")], [UP]),
 ("M26", "R-SO20 json note of remove", RF, [("notes: ResolveBase.pin_notes(decision).concat(force_notes).concat(ran.notes),", "notes: force_notes.concat(ran.notes),")], [RM]),
 ("M27", "R-SO20 note order", IF, [("Ok({ ..outcome, notes: ResolveBase.pin_notes(decision).concat(outcome.notes) })", "Ok({ ..outcome, notes: outcome.notes.concat(ResolveBase.pin_notes(decision)) })")], [UP]),
 ("M28", "R-WS8 transitive facts are never merged", LK, [('if e.alias != "" and found.any(', "if found.any(")], [LO]),
 ("M29", "R-SC14 note of a transitive row", WH, [('else Via(r.via ?? ""),', "else Direct,")], [WY0]),
 ("M30", "R-SC6 path entry is a release", WH, [("what: if r.kind == Release Release(", "what: if r.kind != Foreign Release(")], [WY0]),
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
