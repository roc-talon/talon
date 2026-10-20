#!/usr/bin/env python3
"""Revert check of the 12 gap rows (slice 005 K1). Usage: research/slice-006-gap/mutate.py [row-number ...]
Each row has one small mutation of the code and the test that must fail. A compile error is INVALID, not a catch.
The file is put back after each run. Output is a table."""
import os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ["ROC"]

# (row, rule, module, old text, new text, tests)
M = [
    (1, "Q9", "Pin", 'is_release(bound) and is_release(id) and', '', ["l0:pin"]),
    (2, "R-I2", "Intent", 'text.split_first("@")', 'text.split_last("@")', ["l0:intent"]),
    (3, "R-OV1", "Vars", 't.intent.overrides.find_first(|d| d.key == u.alias)', 't.intent.overrides.find_first(|d| d.key == "x")', ["l0:vars"]),
    (4, "R-C7", "Pick", 'c.published_at + facts.min_age > facts.now', 'c.published_at + facts.min_age >= facts.now', ["l0:pick"]),
    (5, "R-DT4", "Pick", 'Ok(time) => c.published_at > time', 'Ok(time) => c.published_at >= time', ["l0:pick"]),
    (6, "R-DT2", "Pick", 'slot.candidates.sort_with(|a, b| Text.compare(a.url, b.url))', 'slot.candidates', ["l0:pick"]),
    (7, "R-SP18", "Resolve", 'for text in (if request.command == Update request.names else [])', 'for text in request.names', ["l2:resolve/rs-install-names"]),
    (8, "R-I8", "Resolve", 'the key \\"${w.key}\\" names ${w.name ?? w.key}', 'the key \\"${w.key}\\" is ${w.name ?? w.key}', ["l2:resolve/rs-stale-key"]),
    (9, "R-AD26 Q1", "Resolve", 'Text.join(Text.dir_of(u.file), "talon.toml")', 'Text.join(Text.dir_of(u.file), "talon.tml")', ["l2:resolve/rs-new-toml"]),
    (10, "R-AD22", "Resolve", 'Exact(version) => Ok("=${version}")', 'Exact(version) => Ok(version)', ["l2:resolve/rs-new-toml"]),
    (11, "R-C9", "Resolve", 'if a.order_relative_to(b) == After u else best', 'if a.order_relative_to(b) == Before u else best', ["l2:resolve/rs-highest-use"]),
    (12, "R-WS5", "Resolve", 'Ok(_) => if t.path == root_toml Root else Member', 'Ok(_) => Root', ["l2:resolve/rs-member-root-table"]),
]


def run(test):
    kind, what = test.split(":")
    if kind == "l0":
        cmd = [ROC, "test", f"tests/unit/{what}.roc", "--no-cache"]
    else:
        cmd = ["tests/commands/run.sh", what]
    p = subprocess.run(cmd, cwd=ROOT, env=dict(os.environ), capture_output=True, text=True, timeout=900)
    return p.returncode, p.stdout + p.stderr


def main():
    flt = sys.argv[1:]
    print("| Row | Rule | Mutation | Result |\n| --- | --- | --- | --- |")
    for row, ids, mod, old, new, tests in M:
        if flt and str(row) not in flt:
            continue
        path = f"{ROOT}/cli/lib/{mod}.roc"
        text = open(path).read()
        if old not in text:
            print(f"| {row} | {ids} | {mod}: pattern not found | INVALID |", flush=True)
            continue
        open(path, "w").write(text.replace(old, new, 1))
        result = "NOT CAUGHT"
        try:
            for test in tests:
                rc, out = run(test)
                compile_error = re.search(r"[1-9][0-9]* (compiler )?error", out) is not None or "Compilation failed" in out or "build of" in out
                if rc != 0 and compile_error:
                    result = "INVALID (compile error)"
                    print(out[-1500:], file=sys.stderr)
                    break
                if rc != 0:
                    names = re.findall(r"^FAIL (\S+)", out, re.M)
                    result = f"caught by {test}" + (f" ({', '.join(names)})" if names else "")
                    if os.environ.get("SHOW"):
                        print(f"--- row {row}\n" + "\n".join(l[:200] for l in out.splitlines()[:14]), file=sys.stderr)
                    break
        finally:
            open(path, "w").write(text)
        short = old[:50].replace("\n", " ").replace("|", "/").strip()
        print(f"| {row} | {ids} | {mod}: `{short}` | {result} |", flush=True)


main()
