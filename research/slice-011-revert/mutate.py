#!/usr/bin/env python3
"""Revert check of slice 011 (TW12). Usage: research/slice-011-revert/mutate.py [id ...]   (DRY=1: only test that each pattern is found)
Each row is one small change of the private reference implementation and the tests that must fail, in order (the first test that fails is the catch). A compile error is INVALID, not a catch.
The reference implementation was deleted after the run, so the `old` texts do not match the code of the repository: this file and results.md are the record of the check.
The file is put back after each run. Needs ROC (scripts/env.sh sets it). Output is a table."""
import os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ["ROC"]

def f(n): return "cli/lib/" + n + ".roc"
PK, WH, CL, LS = f("Pick"), f("Why"), f("Closure"), f("Listing")
P, W, G = "l0:pickclosure", "l0:why", "l0:closuregaps"
L2P = "l2:closure/cl2"
L3W = "l3:why/"

# (id, rules, file, old text, new text, tests)
M = [
    # Pick: R-C2 over the full closure (l0:pickclosure, l2 cl2-chain)
    ("P1", "R-C2", PK, "conflict = $edges.any(|(_, i)| picked.any(|p| p.c.ident.group == i.group and is_newer(i.version, p.c.ident.version)))", "conflict = Bool.False", [P, L2P]),
    ("P2", "R-C2 R-FE1", PK, "missing: $winners.keep_if(|url| !ctx.known.contains(url))", "missing: []", [P, L2P]),
    ("P3", "R-C2 R-OV1", PK, "Ok(b) if is_newer(i.version, b.ident.version) => acc.set(k", "Ok(b) if is_newer(b.ident.version, i.version) => acc.set(k", [P]),
    ("P4", "R-C2 Q16", PK, "Ok(k) => match acc.get(k) {\n\t\t\t\t\tOk(b) if is_newer(i.version, b.ident.version) => acc.set(k, { url: d, ident: i }) ?? acc\n\t\t\t\t\t_ => acc\n\t\t\t\t}", "Ok(_) => acc.append({ url: d, ident: i })", [P]),
    ("P5", "R-C8", PK, "conflict = $edges.any(|(_, i)| picked.any(|p| p.c.ident.group == i.group and", "conflict = $edges.any(|(_, i)| picked.any(|p| p.c.ident.group.form == i.group.form and", [P]),
    ("P6", "R-C2", PK, "var $left = 20", "var $left = 0", [P, L2P]),
    ("P7", "R-C2", PK, "and is_newer(i.version, p.c.ident.version)))", "and !is_newer(p.c.ident.version, i.version)))", [P]),
    ("P8", "R-C2 R-VA6", PK, "[] => if closure_check(ctx, picked).conflict Err(NoFit) else Ok(picked)", "[] => Ok(picked)", [P, L2P]),
    ("P9", "R-C8", PK, "next = $edges.keep_if(|(_, i)| !slot_groups.contains(i.group))", "next = $edges.keep_if(|(_, i)| !slot_groups.map(|g| g.form).contains(i.group.form))", [P]),
    ("P10", "R-C2 R-DT2", PK, "missing = picked.map(|p| p.c.url).concat(deeper)", "missing = deeper.concat(picked.map(|p| p.c.url))", [P, L2P]),
    # Why: pure part
    ("W1", "R-CM7", WH, "[one] => Ok({ name: one })", "[one, ..] => Ok({ name: one })", [W, L3W]),
    ("W2", "R-SC6", WH, 'alias: if r.direct r.alias else ""', "alias: r.alias", [W, L3W]),
    ("W3", "R-SC15", WH, ".len() >= 2\n", ".len() >= 3\n", [W, L3W]),
    ("W4", "R-SC14", WH, '"platform (${r.alias})"', '"platform"', [W, L3W]),
    ("W5", "R-SC14", WH, 'Ok(a) => "via ${a}"', 'Ok(a) => "by ${a}"', [W, L3W]),
    ("W6", "R-SC14", WH, '"direct (${r.alias})"', '"direct"', [W]),
    ("W7", "R-SC1 Q7", WH, 'Lookup.New(name) => Err({ fail: Fail.new(Usage, "\'${name}\' is not in the project")', 'Lookup.New(name) => Err({ fail: Fail.new(Usage, "\'${name}\' is not a package")', [W, L3W]),
    ("W8", "R-SC1", WH, "ref = Ref.parse(facts.text, Scope.Project, Bool.False)", "ref = Ref.parse(facts.text, Scope.Install, Bool.False)", [W]),
    ("W9", "Q15", WH, 'if st.kind == Path "${st.alias} (path)" else st.alias', "if st.kind == Path st.alias else st.alias", [W, L3W]),
    ("W10", "R-PH12", WH, 'Str.join_with(p.map(|st| if st.kind == Path "${st.alias} (path)" else st.alias), " -> ")', 'Str.join_with(p.map(|st| if st.kind == Path "${st.alias} (path)" else st.alias), ", ")', [W, L3W]),
    ("W11", "R-CM9", LS, "marks_of = |row| marks_of_row(row, Bool.False)", "marks_of = |row| marks_of_row(row, Bool.True)", [W, L3W]),
    ("W12", "R-OUT4", WH, '("package", Listing.package_doc(f.target))', '("pkg", Listing.package_doc(f.target))', [W]),
    ("W13", "R-OUT4", WH, 'Foreign => "foreign"', 'Foreign => "path"', [W]),
    ("W14", "R-PH12", WH, "walked.links.keep_if(|l| l.from == from).join_map(", "walked.links.keep_if(|l| l.from == from).rev().join_map(", [W, L3W]),
    ("W15", "R-OUT4", WH, '("alias", Text(st.alias)),\n', '("alias", Text(st.id)),\n', [W]),
    ("W16", "R-CM7", WH, 'head = "${Listing.label_of(found.target)}${if marks.is_empty() "" else " (${Str.join_with(marks, "; ")})"}"', 'head = "${Listing.label_of(found.target)}"', [W, L3W]),
    # Why: command code
    ("R1", "R-PD9", WH, "files: Install.canonical_files!(fx, start.project), now: start.now })", "files: [], now: start.now })", [L3W]),
    ("R2", "R-SC14 R-E4", WH, "if !block.is_empty() fx.err!(block)", "if !block.is_empty() fx.out!(block)", [L3W]),
    ("R3", "R-J3", WH, "if args.json {", "if !args.json {", [L3W]),
    ("R4", "R-FL6", WH, "members = if named.is_empty() loaded.members else named", "members = loaded.members", [L3W]),
    ("R5", "R-EC10", WH, "closures = ResolveBase.closure!(fx, request, { members: members.map(|m| { file: m.file, entries: ResolveBase.entries_after(m, []) }), known: [] }).map_err(plain)?", "closures = []", [L3W]),
    ("R6", "R-SC1", WH, "(_, []) => match results {\n\t\t\t[(_, Err(e)), ..] => Err(e)", "(_, []) => match results {\n\t\t\t[(_, Err(e)), ..] => Err({ fail: e.fail, block: \"\" })", [L3W]),
    # Gaps of slice 010 (X4, X19)
    ("X4", "R-C2", CL, "Err(_) => settle(root, facts.nodes, [], 20)", "Err(_) => []", [G]),
    ("X19", "R-C3", CL, "{ ..r, is_pf: r.is_pf or e.is_platform, lowest }", "{ ..r, is_pf: r.is_pf, lowest }", [G]),
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
