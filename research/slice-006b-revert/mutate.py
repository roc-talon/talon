#!/usr/bin/env python3
"""Revert check of slice 006b (TW12). Usage: research/slice-006b-revert/mutate.py [id ...]   (DRY=1: only test that each pattern is found)
Each row is one small change of the private reference implementation and the tests that must fail. A compile error is INVALID, not a catch.
The reference implementation was deleted after the run, so the `old` texts do not match the code of the repository any more: this file and results.md are
the record of the check. The file is put back after each run. L2 rows build the test app first (about 55 s). Needs ROC (scripts/env.sh sets it)."""
import os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ["ROC"]
WORK = os.environ["WORK"]

PR, RB, LD, RS = "cli/lib/Probe.roc", "cli/lib/Rebase.roc", "cli/lib/Ladder.roc", "cli/lib/Resolve.roc"
FL = "l2:install/in1-flow"

# (id, rules, file, old text, new text, tests)
M = [
    ("P1", "Q1 R-RC4", PR, "is_fault_exit = |code| code == 139", "is_fault_exit = |code| code > 128 and is_fault(code - 128)", ["l0:probe"]),
    ("G1", "Q4", RB, "[42, .. as rest] => any_cut(rest, p, 0, until_slash(p))", "[42, .. as rest] => any_cut(rest, p, 0, p.len())", ["l0:rebase"]),
    ("G2", "Q4", RB, "matches(rest, p) or starts(p)", "starts(p)", ["l0:rebase"]),
    ("G3", "Q4", RB, "[63, .. as rest] => match p {\n\t\t[c, .. as more] => c != 47 and matches(rest, more)", "[63, .. as rest] => match p {\n\t\t[_c, .. as more] => matches(rest, more)", ["l0:rebase"]),
    ("G4", "Q4", RB, "[] => p.is_empty()", "[] => Bool.True", ["l0:rebase"]),
    ("T1", "R-LD4", RB, "} else if !leaves(facts) {", "} else if Bool.False {", ["l0:rebase", FL]),
    ("T2", "R-LD4", RB, 'target.starts_with("${facts.from}/")', "target.starts_with(facts.from)", ["l0:rebase"]),
    ("T3", "R-LD4", RB, '"${facts.to}${target.drop_prefix(facts.from)}"', "target", ["l0:rebase"]),
    ("T4", "R-LD4", RB, "if facts.path.starts_with(\"/\") {\n\t\t\tfacts.path", "if facts.path.starts_with(\"/\") {\n\t\t\ttarget", ["l0:rebase"]),
    ("T5", "R-LD4", RB, '".." => (d - 1, out or d - 1 < 0)', '".." => (d - 1, out or d - 1 < -1)', ["l0:rebase"]),
    ("T6", "R-LD4", RB, 'depth = Text.resolve(facts.file_dir, facts.file_dir).drop_prefix(facts.from).split_on("/").keep_if(|s| s != "").len().to_i64_wrap()', "depth = 0", ["l0:rebase"]),
    ("F1", "R-LD4", RB, "facts.files.keep_if(|f| Rebase.glob_match({ glob: facts.glob, path: f.path })).keep_oks(", "facts.files.keep_oks(", ["l0:rebase"]),
    ("F2", "R-H1", RB, "if text == f.text Err(Same) else Ok({ path: f.path, text })", "Ok({ path: f.path, text })", ["l0:rebase"]),
    ("F3", "R-H1", RB, "Path => {", "_ => {", ["l0:rebase"]),
    ("F4", "R-LD4", RB, 'if Text.dir_of(f.path) == "" facts.from else "${facts.from}/${Text.dir_of(f.path)}"', "facts.from", ["l0:rebase"]),
    ("E1", "R-LD4 Q1", RB, 'if line.starts_with("import \\"") {', 'if line.contains("import \\"") {', ["l0:rebase"]),
    ("E2", "R-LD4 Q1", RB, "[file, .. as after] => \"import \\\"${Rebase.path({ path: file, file_dir: facts.file_dir, from: facts.from, to: facts.to })}", "[file, .. as after] => \"import \\\"${file}", ["l0:rebase"]),
    ("E3", "R-LD4 Q1", RB, "path: file, file_dir: facts.file_dir,", "path: file, file_dir: facts.from,", ["l0:rebase"]),
    ("E4", "R-LD4 Q1", RB, "text = Rebase.embeds({ text: headed, file_dir, from: facts.from, to: facts.to })", "text = headed", ["l0:rebase"]),
    ("E5", "R-LD4 Q1", RB, "text = Rebase.embeds({ text: headed,", "text = Rebase.embeds({ text: f.text,", ["l0:rebase"]),
    ("E6", "R-H1 Q1", RB, '${Str.join_with(after, "\\"")}', "", ["l0:rebase"]),
    ("W1", "R-LD4 Q1", LD, "$dirs = $next", "$dirs = []", [FL]),
    ("W2", "R-LD4 Q1", LD, 'glob: "**/*.roc"', 'glob: "*.roc"', [FL]),
    ("W3", "R-LD4 Q1", LD, "others = roc_files.keep_if(|r| r != file)", "others = roc_files", [FL]),
    ("W4", "R-LD4 Q1", LD, ".concat(changed.keep_if(|f| f.path != file).map(|f| { path: Text.join(copy, f.path), content: f.text }))", "", [FL]),
    ("W5", "R-LD4 Q1", LD, "Ok(Text.sorted($found))", "Ok($found)", [FL]),
    ("W6", "R-LD4 Q4", LD, "from: dir, to: copy })", 'from: "${dir}/x", to: copy })', [FL]),
    ("W7", "R-LD4 Q1", LD, "read = if others.is_empty() [] else fx.read_files!", "read = fx.read_files!", [FL, "l2:ladder/ld-ladder-flow"]),
    ("C2", "D6 C2", RS, "=> list.fold(c0, |best, c| if c.published_at > best.published_at c else best)", "=> c0", [FL]),
    ("M1", "R-LF3 R-BL6", RS, "Ok({ probes: 0, check: Skipped, build: Skipped, notes: [] })", "Ok({ probes: 0, check: Passed, build: Skipped, notes: [] })", [FL]),
    ("M2", "R-LF3 R-BL6", RS, "Ok({ probes: 0, check: Skipped, build: Skipped, notes: [] })", "Ok({ probes: 0, check: Skipped, build: Passed, notes: [] })", [FL]),
]


def run(test):
    kind, what = test.split(":")
    if kind == "l0":
        cmd = [ROC, "test", f"tests/unit/{what}.roc", "--no-cache"]
    elif kind == "l2":
        b = subprocess.run([ROC, "build", "tests/commands/main.roc", f"--output={WORK}/bin/l2"], cwd=ROOT, capture_output=True, text=True, timeout=900)
        if b.returncode != 0:
            return b.returncode, "Compilation failed\n" + b.stdout + b.stderr
        cmd = ["tests/commands/run.sh", what]
        os.environ["L2BIN"] = f"{WORK}/bin/l2"
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
                compile_error = re.search(r"^\s*[1-9][0-9]* compiler errors?", out, re.M) is not None or "Compilation failed" in out
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
