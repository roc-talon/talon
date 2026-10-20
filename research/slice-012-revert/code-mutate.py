#!/usr/bin/env python3
"""Revert check of the code of slice 012 (TW12, code agent). Usage: research/slice-012-revert/code-mutate.py [id ...]   (DRY=1: only test that each pattern is found)
Each row is one small change in cli/lib that breaks one rule of the slice, and the tests that must fail, in order. The file is put back after each run.
The check at the end of the work compares `cli/` with `code-green-cli/` (a copy made before the mutations). A compile error is INVALID, not a catch.
The binaries are built once for each mutation in .work/mut/ (the removed dir is deleted by the last step of the work). Needs ROC (scripts/env.sh sets it)."""
import os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ["ROC"]
MUT = os.path.join(ROOT, ".work", "mut")

def f(n): return "cli/lib/" + n + ".roc"
PF, WH, CO, LK, RB, IN, PI, IT = f("PickFlow"), f("Why"), f("Compiler"), f("Locked"), f("ResolveBase"), f("Install"), f("Pin"), f("Intent")
GH = f("Github")

# (id, rules, file, old text, new text, tests)
VF, RN, AD = "l3:verify/vf1-verify", "l2:resolve/rs-no-compiler", "l3:add/ad1-add-entries"
M = [
    ("D1", "R-DI12", PF, "if c.missing return Err(Github.no_page_failure(f.name))", 'if c.missing and c.name == "" return Err(Github.no_page_failure(f.name))', [AD]),
    ("D2", "R-DI12", GH, 'Fail.new(Network, "the index of ${name} has no cached page', 'Fail.new(Usage, "the index of ${name} has no cached page', [AD]),
    ("D3", "R-DI12", GH, "has no cached page and --offline is set.", "has no cached page.", [AD]),
    ("T1", "R-SO2 R-EV5", CO, "Compiler.require({ id, path_roc: facts.path_roc })?", 'Compiler.require({ id: "${id}x", path_roc: facts.path_roc })?', [VF]),
    ("T2", "R-PH7", CO, "Ok(id) if !facts.frozen => {", 'Ok(id) if id == "" => {', [VF]),
    ("T3", "R-SC12", CO, "Ok((_, text)) if !text.is_empty() => if Compiler.kind(text) == Local {", 'Ok((_, text)) if !text.is_empty() => if text == "" {', [VF]),
    ("T4", "R-EV5", CO, 'name == "ROC_TOOLCHAIN"', 'name == "ROC_TOOLCHAINS"', [VF]),
    ("P1", "R-SC12 R-EC19", LK, "if !Pin.is_id(e.value) return", 'if !Pin.is_id(e.value) and e.value == "" return', [VF]),
    ("P2", "R-EC19", LK, ".fold(1, |n, b|", ".fold(2, |n, b|", [VF]),
    ("N1", "R-NS10", RB, "(_, _, Ok(b)) => (b, Config)", "(_, _, Ok(_)) => (Bool.True, Config)", [VF]),
    ("N2", "R-NS8", RB, "(Ok(b), _, _) => (b, Env)", "(Ok(_), _, _) => (Bool.True, Env)", [VF]),
    ("N3", "R-NS9 R-NS10", RB, "(_, Ok(b), _) => (b, Toml)\n\t\t\t(_, _, Ok(b)) => (b, Config)", "(_, _, Ok(b)) => (b, Config)\n\t\t\t(_, Ok(b), _) => (b, Toml)", [VF, RN]),
    ("N4", "R-NS2", PI, 'Env => "TALON_NIGHTLY"', 'Env => "TALON"', [VF, RN]),
    ("N5", "R-NS2", PI, 'Config => "nightly in config.toml"', 'Config => "config.toml"', [VF]),
    ("C1", "R-C7 R-LY4", RB, "user: loaded.config.min_release_age", "user: Err(Unset)", [VF]),
    ("C2", "R-C7", IT, 'doc,\n\t\t\t\t"min-release-age",\n\t\t\t\t|v| match v {\n\t\t\t\t\tValue.String(text) => days_of(text).map_err(|NotDays| "must be a number of days, for example \\"2d\\"")', 'doc,\n\t\t\t\t"min-age",\n\t\t\t\t|v| match v {\n\t\t\t\t\tValue.String(text) => days_of(text).map_err(|NotDays| "must be a number of days, for example \\"2d\\"")', [VF]),
    ("C3", "R-NS10", RB, "config = read_config!(fx, config_path, config_result)?", "config = read_config!(fx, config_path, if config_path == \"\" config_result else Err(NotFound))?", [VF, RN]),
    ("G1", "R-SO13 R-SO4", PI, "!Pin.admits({ req, id: facts.compiler }) => Err(", "Pin.admits({ req, id: facts.compiler }) => Err(", [RN]),
    ("G2", "R-NS3 R-NS2", PI, "if Pin.is_nightly(facts.compiler) and !facts.nightly {", "if Pin.is_nightly(facts.compiler) and facts.nightly {", [RN]),
    ("G3", "R-NS2", PI, 'Err(Fail.new(NoTuple, "the roc on PATH,', 'Err(Fail.new(Consent, "the roc on PATH,', [RN]),
    ("G4", "R-SO13", RB, "Ok(id) => if decision.pinned {", 'Ok(id) => if decision.pinned or id != "" {', [RN]),
    ("G5", "R-SO3 R-PH7", RB, "Ok(id) => if decision.pinned {", 'Ok(id) => if id == "" {', [VF, RN, "l0:pin"]),
    ("F1", "R-SO2 (frozen)", CO, "Ok(id) if !facts.frozen => {", "Ok(id) => {", [RN]),
    ("I1", "R-SO2 (install)", IN, "compiler = Install.compiler!(fx, env, opts.frozen)?", "compiler = if opts.frozen Err(NoCompiler) else Install.on_path!(fx)", [VF, "l3:add/ad1-add-entries"]),
    ("W1", "W8 (Why.find)", WH, "at = ents.find_first_index(|x| x.alias == alias and x.name == name).map_err(|_| not_in(facts.text))?", "at = ents.find_first_index(|x| x.alias == alias and x.name == name) ?? 0", ["l0:why"]),
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
