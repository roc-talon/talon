#!/usr/bin/env python3
"""Revert check of slice 010 (TW12). Usage: research/slice-010-revert/mutate.py [id ...]   (DRY=1: only test that each pattern is found)
Each row is one small change of the private reference implementation and the tests that must fail, in order (the first test that fails is the catch). A compile error is INVALID, not a catch.
The reference implementation was deleted after the run, so the `old` texts do not match the code of the repository: this file and results.md are the record of the check.
The file is put back after each run. Needs ROC (scripts/env.sh sets it). Output is a table."""
import os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ["ROC"]

def f(n): return "cli/lib/" + n + ".roc"
CL, LS, WK, LO, RS, RL, UP, LD = f("Closure"), f("Listing"), f("Walk"), f("Ls"), f("Resolve"), f("Release"), f("Update"), f("Ladder")
A, B = "l0:closure", "l0:listing"
# L2 cases that run the walk (one build, many filters), L3 of list
L2 = "l2:closure gaps install/in1 resolve/rs-frozen resolve/rs-no-compiler resolve/rs-install-add-key"
L3 = "l3:list/"

# (id, rules, file, old text, new text, tests)
M = [
    # Closure.step: the winners, the marks, the failures (l0:closure)
    ("C1", "R-C2", CL, "Text.compare(e.target.url, cur.url) == Before\n\t\t\t\t\t} else if before(cur.version", "Text.compare(e.target.url, cur.url) == After\n\t\t\t\t\t} else if before(cur.version", [A]),
    ("C2", "R-C2", CL, "} else if before(cur.version, e.target.version) {\n\t\t\t\t\t\tBool.True", "} else if before(cur.version, e.target.version) {\n\t\t\t\t\t\tBool.False", [A]),
    ("C3", "R-CM9", CL, "raised = if before(low, sel)", "raised = if Bool.False", [A, L3]),
    ("C4", "R-CM9", CL, "direct = $heads.contains(f.group)", "direct = Bool.False", [A, L3]),
    ("C5", "R-CM9", CL, "via = if direct Err(None) else Ok(f.edge.top)", "via = if direct Err(None) else Ok(f.edge.alias)", [A, L3]),
    ("C6", "R-C3", CL, "$plat = $plat.insert(g)", "$plat = $plat", [A, L3]),
    ("C7", "R-H7 Q16", CL, "Release => facts.chosen.get(g) ?? edge.target.url", "Release => edge.target.url", [A, L2]),
    ("C8", "R-H7", CL, "dir: node_dir(selected) })", "dir: Ok(Text.dir_of(facts.file)) })", [A, L3]),
    ("C9", "R-H4", CL, "if edge.target.kind != Foreign {", "if Bool.True {", [A]),
    ("C10", "R-H7", CL, "Err(problem) => Fail(normalize(problem, facts.nodes))\n\t\t\tOk(_) =>", "Err(_) => Done({ rows: walked.rows, links: walked.links })\n\t\t\tOk(_) =>", [A, L3]),
    ("C11", "R-CM2", CL, "if !walked.unknown.is_empty() {", "if Bool.False {", [A]),
    ("C12", "R-C8", CL, "if series.len() >= 2 Ok", "if series.len() > 2 Ok", [A]),
    ("C13", "R-C8", CL, "via: if r.direct r.alias else r.via ?? r.alias", "via: r.alias", [A, L3]),
    ("C14", "R-C8", CL, "The types of the ${n} series are different types.", "The types of the ${n} series are the same.", [A, L3]),
    ("C15", "R-EC10", CL, "Fail.new(NoTuple, message)", "Fail.new(Internal, message)", [A, L3]),
    ("C16", "R-C2", CL, ", but the header names ${label(r.pinned)}", ", but header names ${label(r.pinned)}", [A, L3]),
    ("C17", "R-H7", CL, 'urls.map(label), " -> ")', 'urls.map(label), ", ")', [A]),
    ("C18", "R-CM9", CL, "$links = $links.append({ from: edge.owner, alias: edge.alias, to: selected })", "$links = $links.append({ from: edge.owner, alias: edge.alias, to: edge.target.id })", [A, L3]),
    ("C19", "R-H4", CL, "Err(Foreign) => Ok({ id: value, value, kind: Foreign,", "Err(Foreign) => Ok({ id: value, value, kind: Path,", [A, L3]),
    ("C20", "R-H7", CL, "id = Text.resolve(d, value)", "id = value", [A, L3]),
    ("C21", "R-CM9", CL, "Ok(v) => Ok(if before(edge.target.version, v) edge.target.version else v)", "Ok(v) => Ok(if before(v, edge.target.version) edge.target.version else v)", [A, L3]),
    ("C22", "R-C8", CL, 'same = releases.keep_if(|r| r.form == form)', 'same = releases.keep_if(|r| r.name == "")', [A, L3]),
    ("C23", "R-H7", CL, "Err(Release) => Err(Ignore)", "Err(Release) => Ok({ id: value, value, kind: Foreign, url: \"\", group: \"foreign:${value}\", version: (0, 0, 0) })", [A]),
    # Release.entries_of
    ("E1", "R-H7", RL, 'keep_if(|e| e.name != "roc").map(|e| { alias: e.name', 'keep_if(|e| Bool.True).map(|e| { alias: e.name', [A]),
    ("E2", "R-H7", RL, "Ok(header) => Ok(header.entries().keep_if", "Ok(header) => Ok(header.entries().keep_if(|e| !e.is_platform).keep_if", [A]),
    ("E3", "R-H7", RL, 'entries_of = |facts| match Header.parse(facts.text) {\n\t\tErr(NoHeader) => Err(Fail.new(Input, "${facts.path}: the package has', 'entries_of = |facts| match Header.parse(facts.text) {\n\t\tErr(NoHeader) => Err(Fail.new(Input, "${facts.path}: the file has', [A]),
    # Listing
    ("S1", "R-OUT2", LS, "r.alias.count_utf8_bytes() > most r.alias.count_utf8_bytes() else most) + 2", "r.alias.count_utf8_bytes() > most r.alias.count_utf8_bytes() else most) + 1", [B]),
    ("S2", "R-OUT2", LS, 'if r.kind == Release "${r.name} ${r.version}" else r.name', 'if r.kind == Release r.name else r.name', [B]),
    ("S3", "R-CM9", LS, "first.concat(raised).concat(foreign)", "first.concat(foreign).concat(raised)", [B]),
    ("S4", "R-CM9", LS, '["via ${alias}"]', '["from ${alias}"]', [B]),
    ("S5", "R-CM9", LS, '${label(r)} (shown above)\\n"', '${label(r)} (seen)\\n"', [B]),
    ("S6", "R-CM9", LS, 'tail = if ms.is_empty() "" else " (${Str.join_with(ms, "; ")})"', 'tail = if ms.is_empty() "" else " (${Str.join_with(ms, ", ")})"', [B]),
    ("S7", "R-CM9", LS, "ms = marks(r, Bool.False)", "ms = marks(r, Bool.True)", [B]),
    ("S8", "R-OUT4", LS, '("series", Arr(Closure.clashes', '("clashes", Arr(Closure.clashes', [B]),
    ("S9", "R-H4", LS, '("foreign", Flag(r.kind != Release))', '("foreign", Flag(r.kind == Path))', [B]),
    ("S10", "R-OUT4", LS, '("platform", Flag(r.is_platform))', '("platform", Flag(Bool.False))', [B]),
    ("S11", "R-OUT4", LS, "Err(Header) => Null", 'Err(Header) => Text("")', [B]),
    ("S12", "R-CM9", LS, "if !args.operands.is_empty() {", "if Bool.False {", [B]),
    ("S13", "R-CM9", LS, 'name == "--tree"', 'name == "--trees"', [B]),
    ("S14", "R-CM9", LS, 'Str.join_with(marks(r, Bool.True), "; ")', 'Str.join_with(marks(r, Bool.True), ", ")', [B]),
    # Walk
    ("W1", "R-CM2", WK, "if !urls.is_empty() {", "if !urls.is_empty() or !ids.is_empty() {", [L2]),
    ("W2", "R-FE7", WK, "offline: facts.offline,", "offline: Bool.False,", [L3]),
    ("W3", "R-H7", WK, 'urls = ids.keep_if(|id| id.contains("://"))', "urls = ids", [L2, L3]),
    ("W4", "R-EC18", WK, 'Fail.new(Environment, "cannot read ${path}")', 'Fail.new(Environment, "cannot open ${path}")', [L3]),
    ("W5", "R-EC18", WK, 'Fail.new(Environment, "cannot read ${path}")', 'Fail.new(Input, "cannot read ${path}")', [L3]),
    # W6 (the walk calls itself with `$read` and not `nodes.concat($read)`) never ends: the run hangs, so it is not a row.
    # Ls
    ("L1", "R-PD9", LO, "files: Install.canonical_files!(fx, start.project), now: start.now })?\n\tResolve.walk_members!", "files: [], now: start.now })?\n\tResolve.walk_members!", [L3]),
    ("L2", "R-C8", LO, 'fx.err!("${note}\\n")', 'fx.out!("${note}\\n")', [L3]),
    ("L3", "R-J3", LO, "if args.json {", "if !args.json {", [L3]),
    ("L4", "R-CM9", LO, "if opts.tree Listing.tree(m) else Listing.text(m)", "if !opts.tree Listing.tree(m) else Listing.text(m)", [L3]),
    ("L5", "R-C8", LO, "if found.contains(note) found else found.append(note)", "found.append(note)", [L3]),
    # Resolve: where the walk runs
    ("R1", "R-CM2", RS, "\twalk_closure!(fx, request, loaded, changes, facts.known)?\n", "", [L2]),
    ("R2", "R-CM2", RS, "\twalk_closure!(fx, request, loaded, edits, facts.known)?\n", "", [L2]),
    ("R3", "R-FL4", RS, "\twalk_closure!(fx, request, loaded, [], [])?\n", "", [L2]),
    ("R4", "R-CM2", RS, "var $nodes = known.map(|f| { id: f.url, entries: f.entries })\n\tvar $notes", "var $nodes = known.keep_if(|_| Bool.False).map(|f| { id: f.url, entries: f.entries })\n\tvar $notes", [L2]),
    ("R5", "R-AL2", RS, "Pin(_) => Bool.False\n\t\t\t\t_ => Bool.True", "Pin(_) => Bool.True\n\t\t\t\t_ => Bool.True", [L2]),
    ("R6", "R-AL2", RS, "rows = if ops.is_empty() {\n\t\t\tm.locked.rows", "rows = if ops.len() < 99 {\n\t\t\tm.locked.rows", [L2, L3]),
    ("R7", "R-FL6", RS, "members = if named.is_empty() loaded.members else named", "members = if named.len() > 99 named else loaded.members", [L2, L3]),
    ("R8", "R-C8", RS, "if !$notes.contains(note) {", "if $notes.len() < 99 {", [L2]),
    # The 4 gaps of slice 009
    ("GL4", "R-PH7", LD, "Compiler.require({ id: request.held, path_roc: request.path_roc })?\n\t\tvar $done = no_done\n\t\tfor member in request.members {\n\t\t\t$done = $done.append({ file: member.file, lines: verify_member!", "var $done = no_done\n\t\tfor member in request.members {\n\t\t\t$done = $done.append({ file: member.file, lines: verify_member!", [L2]),
    ("GF10", "R-RP2", RS, "\t\tcheck_pin(start.loaded.intent, settings, start.decision)?\n\t\tsnapshot = snapshot_of(request, start.loaded.intent)?\n\t\tpicked", "\t\tsnapshot = snapshot_of(request, start.loaded.intent)?\n\t\tpicked", [L2]),
    ("GF17", "R-LD7", RS, "build: if checked.any(|m| m.kind == App) Passed else NotRun,", "build: Passed,", [L2]),
    ("GW13", "R-NM7", UP, "if items.is_empty() Ok([]) else ask_names!(fx, items)", "ask_names!(fx, items)", [L2]),
]


def run(test):
    kind, what = test.split(":")
    if kind == "l0":
        cmd = [ROC, "test", f"tests/unit/{what}.roc", "--no-cache"]
    elif kind == "l2":
        cmd = ["tests/commands/run.sh"] + what.split()
    else:
        cmd = ["tests/run.sh", what]
    p = subprocess.run(cmd, cwd=ROOT, env=dict(os.environ), capture_output=True, text=True, timeout=900)
    return p.returncode, p.stdout + p.stderr


def main():
    flt = sys.argv[1:]
    dry = os.environ.get("DRY") == "1"
    print("| Id | Rules | Mutation | Result |\n| --- | --- | --- | --- |")
    for mid, ids, rel, old, new, tests in M:
        if flt and mid not in flt:
            continue
        path = f"{ROOT}/{rel}"
        text = open(path).read()
        if old not in text:
            print(f"| {mid} | {ids} | {rel}: pattern not found | INVALID |", flush=True)
            continue
        if dry:
            print(f"| {mid} | {ids} | found | |", flush=True)
            continue
        open(path, "w").write(text.replace(old, new, 1))
        result = "NOT CAUGHT"
        try:
            for test in tests:
                rc, out = run(test)
                compile_error = re.search(r"^\s*[1-9][0-9]* compiler errors?", out, re.M) is not None or "Compilation failed" in out or re.search(r"^build of .* failed", out, re.M) is not None
                if rc != 0 and compile_error:
                    result = "INVALID (compile error)"
                    print(out[-1500:], file=sys.stderr)
                    break
                if rc != 0:
                    names = re.findall(r"^FAIL (\S+)", out, re.M)
                    result = f"caught by {test}" + (f" ({', '.join(names)})" if names else "")
                    break
        finally:
            open(path, "w").write(text)
        short = old[:50].replace("\n", " ").replace("\t", " ").replace("|", "/").strip()
        print(f"| {mid} | {ids} | `{short}` | {result} |", flush=True)


main()
