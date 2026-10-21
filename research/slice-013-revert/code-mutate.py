#!/usr/bin/env python3
"""Revert check of the code of slice 013 (TW12, code agent). Usage: research/slice-013-revert/code-mutate.py [id ...]   (DRY=1: only test that each pattern is found)
Each row is one small change in cli/lib that breaks one rule of the slice, and the tests that must fail, in order. The file is put back after each run.
The check at the end of the work compares `cli/` with `code-green-cli/` (a copy made before the mutations). A compile error is INVALID, not a catch.
The binaries are built once for each mutation in .work/mut/ (the dir is deleted by the last step of the work). Needs ROC (scripts/env.sh sets it)."""
import os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ["ROC"]
MUT = os.path.join(ROOT, ".work", "mut")

def f(n): return "cli/lib/" + n + ".roc"
PI, RB, INS, IF, RF, VFL, UPD, REM, VER = f("Pin"), f("ResolveBase"), f("Install"), f("InstallFlow"), f("RemoveFlow"), f("VerifyFlow"), f("Update"), f("Remove"), f("Verify")

L0 = "l0:pin"
LD = "l2:ladder/ld-no-check-refuse"
RSF = "l2:resolve/rs-failures"
VF = "l3:verify/vf1-verify"
UP = "l3:update/up1-update-entries"
RM = "l3:remove/rm2-workspace"
IN = "l3:install/in1-workspace-frozen-rename"
CHECK = "check_pin(loaded, settings, decision, Lock)?"

# (id, rules, file, old text, new text, tests)
M = [
    ("N1", "R-SO20", PI, "note: Ok(Pin.toolchain_note({ pin: p, toolchain: t }))", "note: Err(None)", [L0, LD, UP, RM]),
    ("N2", "R-SO20 R-SP1", PI, "Lock => { held: Ok(p), held_from: Pin,", "Lock => { held: Ok(t), held_from: Env,", [L0, LD, UP, RM]),
    ("V1", "R-SO21", PI, "Verify => { held: Ok(t), held_from: Env,", "Verify => { held: Ok(p), held_from: Pin,", [L0, VF]),
    ("E1", "R-SO19", PI, "(Err(NoPin), Ok(t)) => { held: Ok(t), held_from: Env,", "(Err(NoPin), Ok(_)) => { held: facts.compiler, held_from: Path,", [L0, VF]),
    ("SAME", "R-SO20", PI, "(Ok(p), Ok(t)) if t != p =>", "(Ok(p), Ok(t)) if t != p or t == p =>", [L0]),
    ("S1", "R-SO22 R-H6", PI, "can_write = !facts.no_check", "can_write = Bool.True", [L0, LD]),
    ("X1", "R-SO19", PI, "(Env, _, _) if switch_off => Err(Fail.new(NoTuple,", "(Env, _, _) if switch_off => Err(Fail.new(Consent,", [L0, VF]),
    ("X2", "R-SO19", PI, "(Env, Ok(req), Ok(text)) if !Pin.admits", "(Env, Ok(req), Ok(text)) if Pin.admits", [L0, VF]),
    ("T1", "R-SO20", PI, "is ${facts.pin}. This command keeps the pin.", "is ${facts.pin}. This command moves the pin.", [L0]),
    # G5: the install flow gates the roc on PATH also when the header has a pin (a gate of the pin itself is no bug: `outside` has checked it).
    ("G5", "R-SO19 G5", IF, CHECK, "check_pin(loaded, settings, { ..decision, held: request.compiler, held_from: if decision.held_from == Pin Path else decision.held_from }, Lock)?", [LD]),
    ("NS4", "R-NS4 R-SO21", RB, "(Env, Verify) => Ok({})", "(Env, Verify) => gate(Env)", [VF]),
    ("EL", "R-SO19", RB, "(Env, Lock) => gate(Env)", "(Env, Lock) => Ok({})", [VF]),
    ("PA", "R-SO13", RB, "(Path, _) => gate(Path)", "(Path, _) => Ok({})", ["l2:resolve/rs-no-compiler", LD]),
    ("RO", "R-SO21", RB, "\t\t\trole,\n\t\t\treq: loaded.intent.toolchain.roc,", "\t\t\trole: if request.command == Update Lock else role,\n\t\t\treq: loaded.intent.toolchain.roc,", [VF]),
    ("R1", "R-RP2 R-SO17", IF, CHECK, "check_pin(loaded, settings, { ..decision, outside: Err(None), held_from: Pin }, Lock)?", [RSF]),
    ("R2", "R-RP2", RF, CHECK, "check_pin(loaded, settings, { ..decision, outside: Err(None), held_from: Pin }, Lock)?", [RM]),
    ("R3", "R-RP2 Q37", RF, "ResolveBase." + CHECK, "if !skip_check ResolveBase." + CHECK, [RM]),
    ("WI", "R-SO19 R-SO20", INS, "toolchain = Compiler.toolchain_of(env)?", "toolchain = Err(Unset)", [VF, UP, LD]),
    ("WU", "R-SO20", UPD, "toolchain = Compiler.toolchain_of(start.env)?", "toolchain = Err(Unset)", [UP]),
    ("WR", "R-SO20", REM, "toolchain = Compiler.toolchain_of(start.env)?", "toolchain = Err(Unset)", [RM]),
    ("WV", "R-SO21", VER, "toolchain = Compiler.toolchain_of(start.env)?", "toolchain = Err(Unset)", [VF]),
    ("C1", "R-SO22 R-PH7", INS, "compiler = Install.compiler!(fx, opts.frozen)\n", "compiler = Install.compiler!(fx, opts.frozen)\n\tmatch toolchain {\n\t\tOk(id) if !opts.frozen => Compiler.require({ id, path_roc: compiler })?\n\t\t_ => {}\n\t}\n", [UP, VF]),
    ("C2", "R-SO22 R-LF1", INS, "compiler = Install.compiler!(fx, opts.frozen)\n", "compiler = Install.compiler!(fx, opts.frozen)\n\tmatch toolchain {\n\t\tOk(id) => Compiler.require({ id, path_roc: Install.on_path!(fx) })?\n\t\t_ => {}\n\t}\n", [IN]),
    ("NR", "R-SO20 (remove)", RF, "for note in ResolveBase.pin_notes(decision) {", "for note in [] {", [RM]),
    ("NI", "R-SO20 (install)", IF, "for note in ResolveBase.pin_notes(decision) {", "for note in [] {", [LD, UP]),
    ("N3", "R-NS9 R-NS10", RB, "(_, Ok(b), _) => (b, Toml)\n\t\t\t(_, _, Ok(b)) => (b, Config)", "(_, _, Ok(b)) => (b, Config)\n\t\t\t(_, Ok(b), _) => (b, Toml)", [VF]),
    ("FD", "R-SO19 R-RP3", IF, "toolchain: request.toolchain,\n\t\trole: Lock,", "toolchain: Err(Unset),\n\t\trole: Lock,", [L0, LD, UP, VF, RM, IN]),
    ("VH", "R-SO21", VFL, "held: decision.held ?? \"\"", "held: if request.compiler == Err(NoCompiler) decision.held ?? \"\" else request.compiler ?? \"\"", [VF]),
]


def sh(cmd, **kw):
    return subprocess.run(cmd, cwd=ROOT, env=dict(os.environ), capture_output=True, text=True, timeout=900, **kw)


def run(test):
    kind, what = test.split(":")
    os.makedirs(MUT, exist_ok=True)
    if kind == "l0":
        p = sh([ROC, "test", f"tests/unit/{what}.roc", "--no-cache"])
    elif kind == "l2":
        b = sh([ROC, "build", "tests/commands/main.roc", f"--output={MUT}/l2"])
        if b.returncode != 0:
            return b.returncode, "build of l2 failed:\n" + b.stdout + b.stderr
        env = dict(os.environ, L2BIN=f"{MUT}/l2")
        p = subprocess.run(["tests/commands/run.sh", what], cwd=ROOT, env=env, capture_output=True, text=True, timeout=900)
    else:
        b = sh([ROC, "build", "cli/main.roc", f"--output={MUT}/tln"])
        if b.returncode != 0:
            return b.returncode, "build of tln failed:\n" + b.stdout + b.stderr
        for n in ("fxprobe", "flowprobe"):
            if not os.path.exists(f"{MUT}/{n}"):
                os.symlink(f"{ROOT}/.work/bin/{n}", f"{MUT}/{n}")
        env = dict(os.environ, TLN=f"{MUT}/tln")
        p = subprocess.run(["tests/run.sh", what], cwd=ROOT, env=env, capture_output=True, text=True, timeout=900)
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
                compile_error = re.search(r"^\s*[1-9][0-9]* errors?", out, re.M) is not None or "Compilation failed" in out or re.search(r"^build of .* failed", out, re.M) is not None
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
