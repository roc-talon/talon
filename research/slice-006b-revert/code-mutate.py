#!/usr/bin/env python3
"""Revert check of the code of slice 006b (TW12, code agent). Usage: research/slice-006b-revert/code-mutate.py [id ...]   (DRY=1: only test that each pattern is found)
Each row is one small change of the real code and the tests that must fail. A compile error is INVALID, not a catch.
The file is put back after each run. L2 rows build the test app first (about 55 s). Needs ROC and WORK (source scripts/env.sh)."""
import os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ["ROC"]
WORK = os.environ["WORK"]

PR, RB, LD, RS = "cli/lib/Probe.roc", "cli/lib/Rebase.roc", "cli/lib/Ladder.roc", "cli/lib/Resolve.roc"
FL = "l2:install/in1-flow"

M = [
    ("P1", "R-RC4", PR, "is_fault_exit = |code| code == 139", "is_fault_exit = |code| code > 128 and is_fault(code - 128)", ["l0:probe"]),
    ("G1", "R-LD4", RB, "Ok(b) if b != 47 => glob_star(glob, path, g, i + 1)", "Ok(_) => glob_star(glob, path, g, i + 1)", ["l0:rebase"]),
    ("G2", "R-LD4", RB, "glob_at(glob, path, g + 3, i) or any_from", "any_from", ["l0:rebase"]),
    ("G3", "R-LD4", RB, "Ok(b) if b != 47 => glob_at(glob, path, g + 1, skip_char", "Ok(_) => glob_at(glob, path, g + 1, skip_char", ["l0:rebase"]),
    ("G4", "R-LD4", RB, "Err(_) => i == path.len()", "Err(_) => Bool.True", ["l0:rebase"]),
    ("T1", "R-LD4", RB, "if !leaves_above(facts.path, start) {", "if Bool.False {", ["l0:rebase", FL]),
    ("T2", "R-LD4", RB, "target.starts_with(with_slash(facts.from))", "target.starts_with(facts.from)", ["l0:rebase"]),
    ("T3", "R-LD4", RB, '"${facts.to}/${target.drop_prefix(with_slash(facts.from))}"', "target", ["l0:rebase"]),
    ("T4", "R-LD4", RB, 'if facts.path.starts_with("/") {\n\t\t\tfacts.path', 'if facts.path.starts_with("/") {\n\t\t\tText.resolve(facts.file_dir, facts.path)', ["l0:rebase"]),
    ("T6", "R-LD4", RB, "start = depth_of(facts.file_dir, facts.from)", "start = 0", ["l0:rebase"]),
    ("F1", "R-LD4", RB, "facts.files.keep_if(|f| glob_match({ glob: facts.glob, path: f.path })).keep_oks(", "facts.files.keep_oks(", ["l0:rebase"]),
    ("F2", "R-H1", RB, "if text == file.text Err(Same) else Ok({ path: file.path, text })", "Ok({ path: file.path, text })", ["l0:rebase"]),
    ("F3", "R-H1", RB, "Path => {", "_ => {", ["l0:rebase"]),
    ("F4", "R-LD4", RB, 'file_dir = if dir == "" facts.from else "${facts.from}/${dir}"', "file_dir = facts.from", ["l0:rebase"]),
    ("E1", "R-LD4", RB, "if line.starts_with(prefix) {", "if line.contains(prefix) {", ["l0:rebase"]),
    ("E2", "R-LD4", RB, "path: before, file_dir: facts.file_dir", "path: before, file_dir: facts.from", ["l0:rebase"]),
    ("E3", "R-LD4", RB, "text = Rebase.embeds({ text: edited,", "text = Rebase.embeds({ text: file.text,", ["l0:rebase"]),
    ("W1", "R-LD4", LD, "$level = Text.sorted($next)", "$level = []", [FL]),
    ("W2", "R-LD4", LD, 'roc_glob = "**/*.roc"', 'roc_glob = "*.roc"', [FL]),
    ("W3", "R-LD4", LD, ".keep_if(|path| path != place.file)\n\ttexts", ".keep_if(|_path| Bool.True)\n\ttexts", [FL]),
    ("W4", "R-LD4", LD, "rest = changed.keep_if(|f| f.path != place.file)", "rest = []", [FL]),
    ("W5", "R-LD4", LD, "Ok(Text.sorted($found))", "Ok($found)", [FL]),
    ("W6", "R-LD4", LD, "from: place.dir, to: place.copy })", 'from: "${place.dir}/x", to: place.copy })', [FL]),
    ("W7", "R-LD4", LD, "texts = if others.is_empty() [] else fx.read_files!", "texts = fx.read_files!", [FL, "l2:ladder/ld-ladder-flow"]),
    ("W8", "R-H7", LD, "?? edited", "?? \"\"", [FL]),
    ("C2", "R-AD32 R-AD33", RS, "Ok(rest.fold(first, |best, c| if c.published_at > best.published_at c else best))", "Ok(rest.fold(first, |best, _c| best))", [FL]),
    ("C3", "R-AD32 R-AD33", RS, "if c.published_at > best.published_at c else best))", "if c.published_at >= best.published_at c else best))", [FL]),
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
