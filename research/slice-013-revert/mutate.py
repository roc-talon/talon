#!/usr/bin/env python3
"""Revert check of the tests of slice 013 (TW12, test agent). Usage: research/slice-013-revert/mutate.py [id ...]   (DRY=1: only test that each pattern is found)
It needs a reference implementation of the slice in `cli/` (the code of the code agent, or a private copy that has the minimum code). The test agent used a private
reference, and deleted it: the patterns below are the lines of that reference. Each row is one small change of the code in `cli/lib` that breaks the rule of a
new test, and the tests that must fail. All tests of a row run (no stop at the first catch). `cli/` is put back after each row. A compile error is INVALID.
Needs ROC (scripts/env.sh sets it). The binaries are built once for each row, in `$WORK/mut/`."""
import os, re, subprocess, sys, shutil
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ["ROC"]
WORK = os.environ.get("WORK", ROOT + "/.work")
OUT = WORK + "/mut"


def f(n): return "cli/lib/" + n + ".roc"
PIN, RB, INS, IF, RF = f("Pin"), f("ResolveBase"), f("Install"), f("InstallFlow"), f("RemoveFlow")

L0 = "l0:pin"
LD = "l2:ladder/ld-no-check-refuse"
RSF = "l2:resolve/rs-failures"
VF = "l3:verify/vf1-verify"
UP = "l3:update/up1-update-entries"
RM = "l3:remove/rm2-workspace"
IN = "l3:install/in1-workspace-frozen-rename"

NOTE = "(Ok(p), Ok(t), Lock) if t != p => Ok(Pin.toolchain_note({ pin: p, toolchain: t }))"
VERIFY = "(Ok(p), Ok(t), Verify) if t != p => (Ok(t), Env)\n\t\t\t\t(Ok(p), _, _) => (Ok(p), Pin)"
SELECT = "\t\tOk({ toolchain, path_roc })"
EAGER = "\t\tmatch toolchain {\n\t\t\tOk(id) if !frozen => {\n\t\t\t\tCompiler.require({ id, path_roc })?\n\t\t\t\tOk({ toolchain, path_roc })\n\t\t\t}\n\t\t\t_ => Ok({ toolchain, path_roc })\n\t\t}"
EAGER_FROZEN = "\t\tmatch toolchain {\n\t\t\tOk(id) => {\n\t\t\t\tCompiler.require({ id, path_roc })?\n\t\t\t\tOk({ toolchain, path_roc })\n\t\t\t}\n\t\t\t_ => Ok({ toolchain, path_roc })\n\t\t}"

# (id, rules, file, old text, new text, tests)
M = [
    ("N1", "R-SO20", PIN, NOTE, "(Ok(p), Ok(t), Lock) if t != p => Err(None)", [L0, LD, UP, RM]),
    ("N2", "R-SO20 R-SP1", PIN, VERIFY, "(Ok(p), Ok(t), _) if t != p => (Ok(t), Env)\n\t\t\t\t(Ok(p), _, _) => (Ok(p), Pin)", [L0, LD, UP, RM]),
    ("V1", "R-SO21", PIN, VERIFY, "(Ok(p), _, _) => (Ok(p), Pin)", [L0, VF]),
    ("E1", "R-SO19", PIN, "(Err(NoPin), Ok(t), _) => (Ok(t), Env)", "(Err(NoPin), Ok(_), _) => (facts.compiler, Path)", [L0, VF]),
    # G5: the install flow gates the roc on PATH also when the header has a pin (a gate of the pin itself is no bug: `outside` has checked it).
    ("G5", "R-SO19 G5", IF, "ResolveBase.check_pin(loaded, settings, decision, Lock)?", "ResolveBase.check_pin(loaded, settings, { ..decision, held: if decision.pinned request.compiler else decision.held, held_from: if decision.pinned Path else decision.held_from }, Lock)?", [LD]),
    ("NS4", "R-NS4 R-SO21", RB, "Env => if role == Verify {", "Env => if role == Verify and role == Lock {", [VF]),
    ("X1", "R-SO19", PIN, 'Err(Fail.new(NoTuple, "the compiler ${facts.compiler} from ROC_TOOLCHAIN is outside', 'Err(Fail.new(Consent, "the compiler ${facts.compiler} from ROC_TOOLCHAIN is outside', [L0, VF]),
    ("X2", "R-SO19", PIN, "if Pin.is_nightly(facts.compiler) and !facts.nightly {", "if Pin.is_nightly(facts.compiler) and !facts.nightly and !env {", [L0]),
    ("S1", "R-SO22 R-H6", PIN, "can_write = !facts.no_check", "can_write = !facts.no_check or facts.toolchain.is_ok()", [L0, LD]),
    ("C1", "R-SO22 R-PH7", INS, SELECT, EAGER, [VF, UP]),
    ("C2", "R-SO22 R-LF1", INS, SELECT, EAGER_FROZEN, [IN]),
    ("R1", "R-RP2 R-SO17", IF, "ResolveBase.check_pin(loaded, settings, decision, Lock)?", "if request.command == Install {\n\t\tResolveBase.check_pin(loaded, settings, decision, Lock)?\n\t}", [RSF]),
    ("R2", "R-RP2", RF, "ResolveBase.check_pin(loaded, settings, decision, Lock)?", "if !decision.pinned ResolveBase.check_pin(loaded, settings, decision, Lock)?", [RM]),
    ("R3", "R-RP2 Q37", RF, "ResolveBase.check_pin(loaded, settings, decision, Lock)?", "if !skip_check ResolveBase.check_pin(loaded, settings, decision, Lock)?", [RM]),
    ("N3", "R-NS9 R-NS10", RB, "(_, Ok(b), _) => (b, Toml)\n\t\t\t(_, _, Ok(b)) => (b, Config)", "(_, _, Ok(b)) => (b, Config)\n\t\t\t(_, Ok(b), _) => (b, Toml)", [VF]),
    ("W1", "R-SO19 R-SO20 R-SO21", INS, "toolchain = Compiler.toolchain_of(env)?", "_ = Compiler.toolchain_of(env)?\n\t\ttoolchain = Err(Unset)", [UP, VF, RM]),
    ("P1", "R-SO20", PIN, NOTE, "(Ok(p), Ok(t), Lock) => Ok(Pin.toolchain_note({ pin: p, toolchain: t }))", [L0]),
    ("P2", "R-SO20 R-SO21", PIN, NOTE, "(Ok(p), Ok(t), _) if t != p => Ok(Pin.toolchain_note({ pin: p, toolchain: t }))", [L0]),
    ("O1", "R-SO21 R-RP2", PIN, "outside: outside_pin(texts, { req: facts.req, nightly: facts.nightly })", "outside: if facts.role == Verify and facts.toolchain.is_ok() Err(None) else outside_pin(texts, { req: facts.req, nightly: facts.nightly })", [L0]),
]


def sh(cmd, **kw):
    return subprocess.run(cmd, cwd=ROOT, env=dict(os.environ), capture_output=True, text=True, timeout=1800, **kw)


def build(name, main):
    p = sh([ROC, "build", main, "--output=" + OUT + "/" + name])
    return p.returncode, p.stdout + p.stderr


def run_all(tests):
    """Build once, then run each test. Gives the list of (test, rc, output)."""
    shutil.rmtree(OUT, ignore_errors=True)
    os.makedirs(OUT + "/bin")
    needs_l2 = any(t.startswith("l2:") for t in tests)
    needs_l3 = any(t.startswith("l3:") for t in tests)
    jobs = []
    with ThreadPoolExecutor(max_workers=4) as ex:
        if needs_l2:
            jobs.append(("l2", ex.submit(build, "l2", "tests/commands/main.roc")))
        if needs_l3:
            jobs.append(("tln", ex.submit(build, "bin/tln", "cli/main.roc")))
            jobs.append(("fxprobe", ex.submit(build, "bin/fxprobe", "cli/fxprobe.roc")))
            jobs.append(("flowprobe", ex.submit(build, "bin/flowprobe", "cli/flowprobe.roc")))
        for name, j in jobs:
            rc, out = j.result()
            if rc != 0:
                return [("build " + name, 1, "Compilation failed\n" + out[-1500:])]
    results = []
    for t in tests:
        kind, what = t.split(":")
        if kind == "l0":
            cmd = [ROC, "test", f"tests/unit/{what}.roc", "--no-cache"]
        elif kind == "l2":
            cmd = ["tests/commands/run.sh", what]
            os.environ["L2BIN"] = OUT + "/l2"
        else:
            cmd = ["tests/run.sh", what]
            os.environ["TLN"] = OUT + "/bin/tln"
        p = sh(cmd)
        results.append((t, p.returncode, p.stdout + p.stderr))
    return results


def main():
    flt = sys.argv[1:]
    dry = os.environ.get("DRY") == "1"
    print("| Id | Rules | Mutation | Result |\n| --- | --- | --- | --- |")
    for mid, ids, rel, old, new, tests in M:
        if flt and mid not in flt:
            continue
        path = f"{ROOT}/{rel}"
        text = open(path).read()
        short = old[:50].replace("\n", " ").replace("\t", " ").replace("|", "/").strip()
        if old not in text:
            print(f"| {mid} | {ids} | `{short}`: pattern not found | INVALID |", flush=True)
            continue
        if dry:
            print(f"| {mid} | {ids} | `{short}` found | |", flush=True)
            continue
        open(path, "w").write(text.replace(old, new, 1))
        try:
            results = run_all(tests)
        finally:
            open(path, "w").write(text)
        def broke(rc, out):
            return rc != 0 and (re.search(r"^\s*[1-9][0-9]* compiler errors?", out, re.M) or "Compilation failed" in out or re.search(r"^build of .* failed", out, re.M))
        bad = [out[-800:] for _, rc, out in results if broke(rc, out)]
        if bad:
            print(bad[0], file=sys.stderr)
            print(f"| {mid} | {ids} | `{short}` | INVALID (compile error) |", flush=True)
            continue
        caught = [t for t, rc, _ in results if rc != 0]
        missed = [t for t, rc, _ in results if rc == 0]
        result = ("caught by " + ", ".join(caught)) if caught else "NOT CAUGHT"
        if caught and missed:
            result += " (not by " + ", ".join(missed) + ")"
        print(f"| {mid} | {ids} | `{short}` | {result} |", flush=True)
    shutil.rmtree(OUT, ignore_errors=True)


main()
