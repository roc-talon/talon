#!/usr/bin/env python3
"""Revert check of the tests of slice 012 (TW12, test agent). Usage: research/slice-012-revert/mutate.py [id ...]   (DRY=1: only test that each pattern is found)
Each row is one small change of the code in cli/lib that breaks the rule of a new test or a new row, and the tests that must fail, in order.
The file is put back after each run (`cli/` is compared with `code-before-cli/` at the end). A compile error is INVALID, not a catch. Needs ROC (scripts/env.sh sets it)."""
import os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ["ROC"]

def f(n): return "cli/lib/" + n + ".roc"
PK, AR, IN, RB, VA, PF, IF, PI = f("Pick"), f("Args"), f("Install"), f("ResolveBase"), f("Vars"), f("PickFlow"), f("InstallFlow"), f("Pin")

# (id, rules, file, old text, new text, tests)
M = [
    ("P8", "R-OV1", PK, "add_below = |roots, acc, e| if roots.any(|r| r.group == e.group) {", "add_below = |roots, acc, e| if roots.any(|r| r.url == e.url) {", ["l0:pickclosure"]),
    ("P9", "R-DT2", PK, "Ok(release) => release.deps.keep_oks(", "Ok(release) => release.deps.rev().keep_oks(", ["l0:pickclosure"]),
    ("P9s", "R-DT2", PK, "Ok(release) => release.deps.keep_oks(", "Ok(release) => release.deps.sort_with(|a, b| Text.compare(a, b)).keep_oks(", ["l0:pickclosure"]),
    ("LF5", "R-LF5", AR, '"--frozen" | "--no-probe"', '"--frozen" | "--locked" | "--no-probe"', ["l3:flags/fl12"]),
    ("E1", "R-EV4", IN, 'Ok((_, "0")) | Ok((_, "false")) => Ok(Bool.False)', 'Ok((_, "0")) | Ok((_, "false")) => Err(Unset)', ["l3:verify/vf1"]),
    ("E2", "R-NS8", RB, "Ok(b) => b\n\t\t\t\tErr(Unset) => intent.toolchain.nightly ?? Bool.True", "Ok(_) => intent.toolchain.nightly ?? Bool.True\n\t\t\t\tErr(Unset) => intent.toolchain.nightly ?? Bool.True", ["l3:verify/vf1"]),
    ("O2", "R-OV2", VA, "Err(_) => match t.intent.overrides.find_first(|d| d.key == u.alias) {", 'Err(_) => match t.intent.overrides.find_first(|d| d.key == "zz") {', ["l2:ladder/ld-ladder"]),
    ("S16", "R-SO16", IF, "match fx.write_atomic!(changed.map(|e| { path: e.path, content: e.new })) {", 'match fx.write_atomic!(changed.map(|e| { path: e.path, content: e.new }).concat(changed.map(|e| { path: "${e.path.drop_suffix("main.roc")}.roc-version", content: "x" }))) {', ["l3:add/ad1|tree"]),
    ("N11", "R-NM11", PF, "_ = Add.decide({ selector: f.selector, chosen: { name: f.name, url: first.url, kind }, platform_flag: f.is_platform, no_pin: request.add.no_pin, as_alias: request.add.as_alias, header })?",
     '_ = match Add.decide({ selector: f.selector, chosen: { name: f.name, url: first.url, kind }, platform_flag: f.is_platform, no_pin: request.add.no_pin, as_alias: request.add.as_alias, header }) {\n\t\t\tOk(x) => x\n\t\t\tErr(e) => {\n\t\t\t\t_ignored = fx.ask!("go on?")\n\t\t\t\treturn Err(e)\n\t\t\t}\n\t\t}', ["l2:prompt/nm11"]),
    ("SC12", "R-SC12", PI, 'text.starts_with(">=") and is_compiler_id(bound(">="))', 'text.starts_with(">=")', ["l0:intent", "l0:pin"]),
    ("A37", "R-AD37", IN, "offline: args.offline,", "offline: Bool.False,", ["l3:add/ad1|stdout"]),
]


def run(test):
    test = test.split("|")[0]
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
                need = test.split("|")[1] if "|" in test else None
                if rc != 0 and need and not re.search(need, out):
                    continue
                if rc != 0:
                    names = re.findall(r"^FAIL (\S+)", out, re.M)
                    result = f"caught by {test}" + (f" ({', '.join(names)})" if names else "")
                    break
        finally:
            open(path, "w").write(text)
        short = old[:50].replace("\n", " ").replace("\t", " ").replace("|", "/").strip()
        print(f"| {mid} | {ids} | `{short}` | {result} |", flush=True)


main()
