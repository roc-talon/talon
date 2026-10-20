#!/usr/bin/env python3
"""Revert check of slice 006 (TW12). Usage: research/slice-006-revert/mutate.py [id ...]
Each row is one small change of the code and the tests that must fail. A compile error is INVALID, not a catch.
The file is put back after each run. At the end the script compares each code file with the copy in `before/`.
Needs ROC (scripts/env.sh sets it). Output is a table."""
import filecmp, os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HERE = os.path.dirname(os.path.abspath(__file__))
ROC = os.environ["ROC"]

P, C, L, R, F = "cli/lib/Probe.roc", "cli/lib/Compiler.roc", "cli/lib/Ladder.roc", "cli/lib/Resolve.roc", "cli/RealFx.roc"
LF = "l2:ladder/ld-ladder-flow"
NC = "l2:ladder/ld-no-check-refuse"
PR1 = "l3:pr1-real"

# (id, rules, file, old text, new text, tests)
M = [
    ("M01", "R-RC4", P, "[4, 6, 7, 8, 11].contains(n)", "[4, 6, 7, 8].contains(n)", ["l0:probe"]),
    ("M02", "R-RC4 Q1", P, "code > 128 and is_fault(code - 128)", "code == 139", ["l0:probe"]),
    ("M03", "R-RC1 R-P2", P, "[n, ..] => if n == 0 Pass else Fail(n)", "[n, ..] => if code == 0 Pass else Fail(n)", ["l0:probe"]),
    ("M04", "R-RC3", P, "TimedOut => Hang", 'TimedOut => NoFact("timeout")', ["l0:probe"]),
    ("M05", "R-RC2", P, "if code != 0 and headers > 0 Fail(headers)", "if headers > 99 Fail(headers)", ["l0:probe"]),
    ("M06", "R-P3", P, 'NotStarted(text) => NoFact("not started: ${text}")', "NotStarted(_) => Pass", ["l0:probe"]),
    ("M07", "R-BL4", P, "strip_positions(line).trim_end()", "line.trim_end()", ["l0:probe"]),
    ("M08", "R-BL4", P, 'and !is_caret(body.get(i + 1) ?? "")', "", ["l0:probe"]),
    ("M09", "R-BL4", P, "if full.starts_with(under_pkgs) {", 'if full.starts_with("${facts.pkgs}x") {', ["l0:probe"]),
    ("M10", "R-BL5 Q2", P, "candidate = without_repeats(facts.candidate)", "candidate = facts.candidate", ["l0:probe"]),
    ("M11", "R-PH7", C, "Ok(found) if found == facts.id => Ok({})", "Ok(found) if found == found => Ok({})", ["l0:compiler"]),
    ("M12", "R-SO11", C, "if Pin.is_nightly(id) {", 'if id.starts_with("nightly") {', ["l0:compiler"]),
    ("M13", "R-SO9", C, '!id.contains(" ")', "Bool.True", ["l0:compiler"]),
    ("M14", "R-LD7", L, "Package | Platform => Err(None)", "Package => Err(None)\n\t\t\tPlatform => Ok(spec(facts.copy, check_args))", ["l0:ladder"]),
    ("M15", "R-BL1", L, "[spec(facts.dir, check_args), spec(facts.copy, check_args)]", "[spec(facts.copy, check_args), spec(facts.copy, check_args)]", ["l0:ladder"]),
    ("M16", "R-LD5", L, "} else if !no_file.is_empty() {", "} else if Bool.False {", ["l0:ladder"]),
    ("M17", "R-EC11", L, "in_app = compared.new.keep_if(|e| !is_package(e))", "in_app = []", ["l0:ladder"]),
    ("M18", "R-P7 R-EC1", L, 'Hang => Err(Fail.new(Internal, "the baseline check hangs', 'Hang => Err(Fail.new(NoTuple, "the baseline check hangs', ["l0:ladder"]),
    ("M19", "R-BL5", L, '.concat(compared.removed.map(|e| line("removed", e)))', "", ["l0:ladder"]),
    ("M20", "R-NI3", "cli/lib/Consent.roc", "default: No,", "default: Yes,", ["l0:consent"]),
    ("M21", "R-CC2", L, "_ = fx.delete!([copy])", "_ = fx.delete!([])", [LF]),
    ("M22", "R-CC2", L, 'skip: [".git"] }) {', "skip: [] }) {", [LF]),
    ("M23", "R-PH7", L, "Compiler.require({ id: request.held, path_roc: request.path_roc })?", "Compiler.require({ id: request.held, path_roc: Ok(request.held) })?", [NC]),
    ("M24", "R-BL6", R, "if request.no_check {\n\t\tfx.out!", "if request.no_check and request.names.is_empty() {\n\t\tfx.out!", [NC]),
    ("M25", "R-AL6", R, "if !changes.is_empty() {\n\t\tladder!", "if !changes.is_empty() or request.names.len() > 0 {\n\t\tladder!", [NC]),
    ("M26", "R-LD4", L, "content: text }", 'content: "${text}${text}" }', [LF]),
    ("M27", "R-PP3", L, "if request.members.len() >= 2", "if request.members.len() >= 1", [LF]),
    ("M28", "R-PH13", R, "moved: rows.keep_if(|r| r.moved)", "moved: rows.keep_if(|r| !r.moved)", [LF]),
    ("M29", "R-LD6", L, "Ok(spec) => match fx.probes!([spec]) {", "Ok(spec) => match fx.probes!([spec, spec]) {", [LF]),
    ("L3-1", "R-CC2", F, "if !skip.contains(name) {", 'if !skip.contains("${name}x") {', [PR1]),
    ("L3-2", "R-RC3", F, "Ok(_) => if now >= entry.deadline {", "Ok(_) => if now >= entry.deadline * 2 {", [PR1]),
    ("L3-3", "R-PP3", F, "\tspecs.map_with_index(\n\t\t|_, i| match finished.find_first(|(index, _)| index == i) {\n\t\t\tOk((_, output)) => output\n\t\t\tErr(_) => { ended: NotStarted(\"not run\"), stdout: \"\", stderr: \"\" }\n\t\t},\n\t)", "\tfinished.map(|(_, output)| output)", [PR1]),
    ("L3-4", "R-CC2", F, "} else if exists!(to) {", '} else if exists!(Path.utf8("${move.to}x")) {', [PR1]),
    ("L3-5", "R-LD1", F, "\t\t.cwd(Path.utf8(spec.dir))\n", "", [PR1]),
    ("L3-6", "R-P3", F, "{ ended: NotStarted(text), stdout: \"\", stderr: \"\" }", "{ ended: Exited(0), stdout: text, stderr: \"\" }", [PR1]),
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
    print("| Id | Rules | Mutation | Result |\n| --- | --- | --- | --- |")
    for mid, ids, rel, old, new, tests in M:
        if flt and mid not in flt:
            continue
        path = f"{ROOT}/{rel}"
        text = open(path).read()
        if old not in text:
            print(f"| {mid} | {ids} | {rel}: pattern not found | INVALID |", flush=True)
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
    same = all(filecmp.cmp(f"{ROOT}/{rel}", f"{HERE}/before/{os.path.basename(rel)}", shallow=False) for rel in {m[2] for m in M} | {"cli/lib/Text.roc"})
    print("\nCode after the run equals the copy in before/:", "yes" if same else "NO")


main()
