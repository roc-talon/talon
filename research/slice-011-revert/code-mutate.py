#!/usr/bin/env python3
"""Revert check of the CODE of slice 011 (TW12, code agent). Usage: research/slice-011-revert/code-mutate.py [id ...]   (DRY=1: only test that each pattern is found)
Each row is one small change of the new code in cli/lib and the tests that must fail, in order. A compile error or a warning is INVALID, not a catch.
The `old` texts match the code of the repository. The file is put back after each run. Needs ROC (scripts/env.sh sets it). Output is a table."""
import os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ["ROC"]

def f(n): return "cli/lib/" + n + ".roc"
WY, PK, LS, LI, RN = f("Why"), f("Pick"), f("Ls"), f("Listing"), f("Run")
A, B = "l0:why", "l0:pickclosure"
L2 = "l2:closure/cl2-chain"
L3 = "l3:why/wy1-why"
L3L = "l3:list/ls1-list"

# (id, rules, file, old text, new text, tests)
M = [
    # Why: the pure part (l0:why)
    ("W1", "R-CM7 R-EC2", WY, "[name] => Ok({ name: name })", "[name, ..] => Ok({ name: name })", [A]),
    ("W2", "R-FL5", WY, "_ = Opts.read(args)?", "_ = {}", [A]),
    ("W3", "R-SC6", WY, 'alias: if r.direct r.alias else "",', "alias: r.alias,", [A]),
    ("W4", "R-SC15", WY, "o.series != r.series", "o.series == r.series", [A]),
    ("W5", "R-SC14", WY, '"platform (${row.alias})"', '"direct (${row.alias})"', [A]),
    ("W6", "R-SC14", WY, '"via ${row.via ?? ""}"', '"via ${row.alias}"', [A]),
    ("W7", "R-SC15", WY, "x.alias == e.alias and x.name == e.name", "x.alias == e.alias", [A]),
    ("W8", "R-SC8", WY, "'${name}' is not in the project", "'${name}' is unknown", [A]),
    ("W9", "R-CM7", WY, "if l.to == target {", "if l.to != target {", [A]),
    ("W10", "R-H7", WY, "} else if seen.contains(l.to) {", '} else if seen.contains("none") {', [A]),
    ("W11", "R-H7", WY, 'Path => "${step.alias} (path)"', "Path => step.alias", [A]),
    ("W12", "R-CM7", WY, "walked.links.keep_if(|l| l.from == from)", "walked.links.rev().keep_if(|l| l.from == from)", [A]),
    ("W13", "R-C2", WY, '"raised from ${version}"', '"raised ${version}"', [A]),
    ("W14", "R-CM7", WY, 'if row.direct ["direct"] else []', 'if !row.direct ["direct"] else []', [A]),
    ("W15", "R-PH12", WY, 'if row.kind == Release "${row.name} ${row.version}" else row.name', "row.name", [A]),
    ("W16", "R-OUT4", WY, '("package", Listing.object_of(found.target))', '("pkg", Listing.object_of(found.target))', [A]),
    ("W17", "R-OUT5", WY, '("paths", Arr(Why.paths', '("routes", Arr(Why.paths', [A]),
    ("W18", "R-J4", WY, 'Path => "path"', 'Path => "release"', [A]),
    ("W19", "R-OUT4", LI, "object_of = |row| package_doc(row)", "object_of = |row| JsonDoc.Null", [A]),
    # Why.run! and answers (l3, l2)
    ("R1", "R-E4", WY, "if !block.is_empty() fx.err!(block)", "if block.is_empty() fx.err!(block)", [L3]),
    ("R2", "R-J1", WY, "if args.json {", "if !args.json {", [L3]),
    ("R3", "Q24", WY, "Ls.walk!(fx, args, Bool.False)", "Ls.walk!(fx, args, Bool.True)", [L3]),
    ("R4", "Q23", WY, "if found.is_empty() {", "if found.len() > 99 {", [L3]),
    ("R5", "R-CM7", RN, 'args.command == ["why"]', 'args.command == ["wy"]', [L3]),
    ("R6", "R-C8", LS, "if notes {", "if !notes {", [L3L, L3]),
    ("R7", "R-C8", LS, "walk!(fx, args, Bool.True)", "walk!(fx, args, Bool.False)", [L3L]),
    # Pick.step: R-C2 over the full closure (l0:pickclosure)
    ("P1", "R-C2", PK, "[] => if closure_of(ctx, picked).conflict Err(NoFit) else Ok(picked)", "[] => Ok(picked)", [B]),
    ("P2", "R-C2", PK, "is_newer(e.version, r.version)", "is_newer(r.version, e.version)", [B]),
    ("P3", "R-C8", PK, "roots.any(|r| r.group == e.group and is_newer", "roots.any(|r| r.group.form == e.group.form and is_newer", [B]),
    ("P4", "R-C2", PK, "Ok(w) if is_newer(e.version, w.version) => acc.set(i, e) ?? acc", "Ok(w) if is_newer(w.version, e.version) => acc.set(i, e) ?? acc", [B]),
    ("P5", "R-C2", PK, "below = settle_below(ctx, roots, [], 20)", "below = settle_below(ctx, roots, [], 0)", [B]),
    ("P6", "R-FE1", PK, "missing = picked.map(|p| p.c.url).concat(below).keep_if", "missing = below.concat(picked.map(|p| p.c.url)).keep_if", [B]),
    ("P7", "R-FE1", PK, "missing = picked.map(|p| p.c.url).concat(below).keep_if", "missing = picked.map(|p| p.c.url).concat(below.keep_if(|u| u == \"\")).keep_if", [B]),
    ("P8", "R-OV1", PK, "add_below = |roots, acc, e| if roots.any(|r| r.group == e.group) {", "add_below = |roots, acc, e| if roots.any(|r| r.url == e.url) {", [B]),
    ("P9", "R-DT2", PK, "Ok(release) => release.deps.keep_oks(", "Ok(release) => release.deps.rev().keep_oks(", [B]),
    ("P10", "R-C2", PK, "wrong_platform or release.deps.any(|dep| needs_newer(dep, y.c))", "wrong_platform", [B]),
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
