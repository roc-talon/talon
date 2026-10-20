#!/usr/bin/env python3
"""Revert check of the CODE of slice 010 (TW12, code agent). Usage: research/slice-010-revert/code-mutate.py [id ...]   (DRY=1: only test that each pattern is found)
Each row is one small change of the new code in cli/lib (the moved code of `Resolve` is not changed) and the tests that must fail, in order. A compile error or a warning is INVALID, not a catch.
The `old` texts match the code of the repository. The file is put back after each run. Needs ROC (scripts/env.sh sets it). Output is a table."""
import os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ["ROC"]

def f(n): return "cli/lib/" + n + ".roc"
CL, WK, LI, LS, RL, RB, IF, VF, RN = f("Closure"), f("Walk"), f("Listing"), f("Ls"), f("Release"), f("ResolveBase"), f("InstallFlow"), f("VerifyFlow"), f("Run")
A, B = "l0:closure", "l0:listing"
L2 = "l2:closure/cl1-flow"
L2OLD = "l2:install/in1-flow"
L2FZ = "l2:resolve/rs-frozen"
L3 = "l3:list/ls1-list"

# (id, rules, file, old text, new text, tests)
M = [
    # Closure.step and its helpers (l0:closure)
    ("X1", "R-H7", CL, "Path => if from_release {", "Path => if !from_release {", [A]),
    ("X2", "R-H7", CL, "file = Text.resolve(dir, e.value)", "file = e.value", [A]),
    ("X3", "R-ID2", CL, '"r:${group.form}#${group.series}"', '"r:${group.form}"', [A]),
    ("X4", "R-C2", CL, "Err(_) => settle(root, facts.nodes, [], 20)", "Err(_) => []", [A]),
    ("X5", "R-AL2", CL, "if !followed.needs.is_empty() {", "if followed.needs.len() > 1 {", [A]),
    ("X6", "R-EC10", CL, "Err(problem) => Fail(problem_of(problem, restore))", "Err(_) => Done({ rows: followed.rows.map(row_of), links: followed.links })", [A]),
    ("X7", "R-OV1", CL, "Ok(low) if newer(url.version(), low) => Ok(version_text(low))", "Ok(low) if newer(low, url.version()) => Ok(version_text(low))", [A]),
    ("X8", "R-OV1", CL, "(Ok(have), Ok(v)) => if newer(have, v) Ok(v) else Ok(have)", "(Ok(have), Ok(v)) => if newer(v, have) Ok(v) else Ok(have)", [A]),
    ("X9", "R-CM9", CL, "direct: q.from == Err(Header),", "direct: q.from != Err(Header),", [A]),
    ("X10", "R-CM9", CL, "from: Ok(id), top: q.top }", "from: Ok(id), top: e.alias }", [A]),
    ("X11", "R-H4", CL, "r.shape != Foreign and !facts.nodes.any", "!facts.nodes.any", [A]),
    ("X12", "R-C8", CL, "if series.len() < 2 {", "if series.len() < 3 {", [A]),
    ("X13", "R-C8", CL, 'via: if r.direct r.alias else r.via ?? "" }', "via: r.alias }", [A]),
    ("X14", "R-EC10", CL, "Fail.new(NoTuple, problem_text(problem))", "Fail.new(Internal, problem_text(problem))", [A]),
    ("X15", "R-EC10", CL, 'urls.map(label_of), " -> ")', 'urls.map(label_of), ", ")', [A]),
    ("X16", "R-EC10", CL, "RootConflict(urls) => RootConflict(Text.sorted(texts(urls)))", "RootConflict(urls) => RootConflict(texts(urls))", [A]),
    ("X17", "R-H4", CL, 'Err(Foreign) => if value.contains("://") Foreign else Path', 'Err(Foreign) => if value.contains("://") Path else Foreign', [A]),
    ("X18", "R-H7", CL, '"https://talon.path/x${code}/1.0.0/x${code}.tar.zst"', '"https://talon.path/x/1.0.0/x${code}.tar.zst"', [A]),
    ("X19", "R-C3", CL, "is_pf: r.is_pf or e.is_platform, lowest }", "is_pf: r.is_pf, lowest }", [A]),
    # Release.entries_of
    ("E1", "R-H7", RL, 'keep_if(|e| e.name != "roc").map(|e| { alias: e.name', 'keep_if(|e| e.name != "").map(|e| { alias: e.name', [A]),
    # Listing (l0:listing)
    ("S1", "R-OUT2", LI, "alias_width + 2 -", "alias_width + 1 -", [B]),
    ("S2", "R-OUT2", LI, 'if row.kind == Release "${row.name} ${row.version}" else row.name', "if row.kind == Release row.name else row.name", [B]),
    ("S3", "R-CM9", LI, 'origin.concat(raised).concat(if row.kind == Release [] else ["foreign"])', 'origin.concat(if row.kind == Release [] else ["foreign"]).concat(raised)', [B]),
    ("S4", "R-CM9", LI, "${label} (shown above)", "${label} (seen)", [B]),
    ("S5", "R-CM9", LI, "marks_of(r, Bool.False)", "marks_of(r, Bool.True)", [B]),
    ("S6", "R-OUT4", LI, '("series", Arr(Closure.clashes', '("clashes", Arr(Closure.clashes', [B]),
    ("S7", "R-H4", LI, '("foreign", Flag(row.kind != Release))', '("foreign", Flag(row.kind == Path))', [B]),
    ("S8", "R-OUT4", LI, 'Err(Header) => Null', 'Err(Header) => Text("")', [B]),
    ("S9", "R-CM9", LI, "if !args.operands.is_empty() {", "if args.operands.len() > 9 {", [B]),
    ("S10", "R-CM9", LI, 'name == "--tree"', 'name == "--trees"', [B]),
    # Walk
    ("W1", "R-CM2", WK, "if !urls.is_empty() {", "if !ids.is_empty() {", [L2OLD, L2]),
    ("W2", "R-FE7", WK, "offline: facts.offline,", "offline: Bool.False,", [L3]),
    ("W3", "R-EC18", WK, 'Err(_) => return Err(Fail.new(Environment, "cannot read ${path}"))', 'Err(_) => return Err(Fail.new(Input, "cannot read ${path}"))', [L3]),
    ("W4", "R-EC10", WK, "Fail(problem) => Err(Closure.failure(problem))", 'Fail(_) => Err(Fail.new(Internal, "closure"))', [L3]),
    ("W5", "D3", WK, "run! = |fx, facts| walk!(fx, facts, facts.known)", "run! = |fx, facts| walk!(fx, facts, [])", [L2]),
    # Ls and the wiring
    ("L1", "R-PD9", LS, "files: Install.canonical_files!(fx, start.project), now", "files: [], now", [L3]),
    ("L2", "R-J1", LS, "if args.json {", "if !args.json {", [L3]),
    ("L3", "R-CM9", LS, "if opts.tree Listing.tree(c) else Listing.text(c)", "if !opts.tree Listing.tree(c) else Listing.text(c)", [L3]),
    ("L4", "R-C8", RB, 'fx.err!("${line}\\n")', 'fx.out!("${line}\\n")', [L2, L3]),
    ("L5", "R-C8", RB, "if found.contains(line) found else found.append(line)", "found.append(line)", [L3]),
    ("L6", "R-FL6", LS, "members = if named.is_empty() loaded.members else named", "members = if named.len() > 99 named else loaded.members", [L3]),
    ("L7", "R-CM9", RN, 'args.command == ["list"]', 'args.command == ["lst"]', [L3]),
    ("R1", "R-AL2", IF, "ResolveBase.entries_after(m, changes)", "ResolveBase.entries_after(m, [])", [L2]),
    ("R2", "D3", VF, "known: ResolveBase.known_nodes(facts.known),", "known: [],", [L2]),
    ("R3", "D3", IF, "known: ResolveBase.known_nodes(facts.known) }", "known: [] }", [L2, L2OLD]),
    ("R4", "R-CM2", IF, "\tResolveBase.closure_notes!(fx, request, closures)\n\tfx.out!(\"the header", "\t_ = closures\n\tfx.out!(\"the header", [L2]),
    ("R5", "R-AL2", RB, "Set({ alias, url }) => rows.map(|r| if r.alias == alias { ..r, value: url } else r)", "Set(_) => rows", [L2]),
    ("R6", "R-AL2", RB, "Add({ alias, url, is_platform }) => rows.append({ alias, value: url, is_platform })", "Add(_) => rows", [L2, L2OLD]),
    ("R7", "D3", RB, "entries: pf.concat(f.release.deps.map(|value| { alias: \"\", value, is_platform: Bool.False })) }", "entries: pf }", [L2]),
    ("R8", "R-CM2", RB, "$nodes = run.nodes", "$nodes = $nodes", [L3]),
    ("R9", "R-FL4", RB, "if !request.prompt.quiet {", "if request.prompt.quiet {", [L2]),
    ("R10", "R-CM2", IF, "closures = ResolveBase.closure!(fx, request, { members: loaded.members.map(|m| { file: m.file, entries: ResolveBase.entries_after(m, []) }), known: [] })?", "closures = ResolveBase.closure!(fx, request, { members: [], known: [] })?", [L2FZ, L2]),
]


def run(test):
    kind, what = test.split(":")
    if kind == "l0":
        cmd = [ROC, "test", f"tests/unit/{what}.roc", "--no-cache"]
    elif kind == "l2":
        cmd = ["tests/commands/run.sh", what]
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
