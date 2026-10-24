#!/usr/bin/env python3
"""Revert check of the code of slice 023c (TW12, filtered runs only, no full sweep).

Each mutation is one small change in one file of cli/. The file is first restored from code-final/ (a kill is safe), then changed, then `roc check`, then only the tests
that should catch it run. The first test that fails ends the run (CAUGHT). A test that runs longer than its timeout counts as CAUGHT. The file is put back after each mutation.

Usage: python3 -I research/slice-023c-revert/code-mutate.py [id ...]     (from the repo root)
Output: one line for each mutation: id, CAUGHT or NOT CAUGHT, the test that failed.
"""
import os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FINAL = os.path.join(ROOT, "research/slice-023c-revert/code-final")
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))
TIMEOUT = {"l0": 120, "l2": 300, "l3": 300}
C, L, D, P, J, I = "cli/lib/Compiler.roc", "cli/lib/Launch.roc", "cli/lib/Ladder.roc", "cli/lib/Proxy.roc", "cli/RealJobs.roc", "cli/lib/Install.roc"
T = "\t"

BUILD_COPY = "Ok(spec) => match probes_touched!(fx, { roots: request.roots, now: request.now, started, specs: [spec] }) {\n\t\t\t[output] => {\n\t\t\t\tbuilt = Ladder.build({ output, dir: copy,"
BUILD_PLACE = "Ok(spec) => match probes_touched!(fx, { roots: request.roots, now: request.now, started, specs: [spec] }) {\n\t\t\t[output] => {\n\t\t\t\tbuilt = Ladder.build({ output, dir, pkgs,"
FIRST_COPY = "copy, timeout })\n\tfirst = match probes_touched!(fx, { roots: request.roots, now: request.now, started, specs: plan.first }) {"
FIRST_PLACE = "replace: request.replace, timeout })\n\tfirst = match probes_touched!(fx, { roots: request.roots, now: request.now, started, specs: plan.first }) {"
PLAIN_COPY_BUILD = BUILD_COPY.replace("probes_touched!(fx, { roots: request.roots, now: request.now, started, specs: [spec] })", "fx.probes!([spec])")
PLAIN_PLACE_BUILD = BUILD_PLACE.replace("probes_touched!(fx, { roots: request.roots, now: request.now, started, specs: [spec] })", "fx.probes!([spec])")

# (id, file, old, new, [tests], what the change breaks)
M = [
    ("C1", C, "match facts.installed.find_first(|id| Pin.same_id(facts.id, id)) {", 'match facts.installed.find_first(|id| id == "-") {', ["l0:compiler", "l2:pb1-ladder"], "R-SO10: an installed id is not found"),
    ("C2", C, "match facts.installed.find_first(|id| Pin.same_id(facts.id, id)) {", "match facts.installed.find_first(|id| id == facts.id) {", ["l0:compiler"], "R-CV1: the other tag form of an installed id is not found"),
    ("C3", C, "Ok(found) if Pin.same_id(facts.id, found.id) => Ok(found.id)", "Ok(found) if found.id == facts.id => Ok(found.id)", ["l0:compiler"], "R-CV1: the id of PATH is compared as text"),
    ("C4", C, "Ok(found) if Pin.same_id(facts.id, found.id) => Ok(found.id)", "Ok(found) => Ok(found.id)", ["l0:compiler", "l2:pb1-ladder"], "R-PH7: the roc on PATH runs for any id"),
    ("C5", C, "Run: tln roc install ${id}.\")", "Run: tln roc install ${id}, or set TALON_AUTO_INSTALL=yes.\")", ["l0:compiler", "l2:pb1-ladder"], "Q3: the refusal names TALON_AUTO_INSTALL"),
    ("C6", C, 'Fail.new(Consent, "the compiler ${id} is not installed.', 'Fail.new(Usage, "the compiler ${id} is not installed.', ["l0:compiler"], "R-EC13: the refusal is not exit 13"),
    ("L1", L, "Ok(found) if found.id == run.id and !run.installed.contains(run.id) => found.path", "Ok(found) if found.id == run.id => found.path", ["l0:launch", "l2:pb1-ladder", "l3:pb1-probes"], "R-SO10: the file of PATH wins over the installed copy"),
    ("L2", L, "Ok(found) if found.id == run.id and !run.installed.contains(run.id) => found.path", 'Ok(found) if found.id == run.id and !run.installed.contains(run.id) => "roc"', ["l0:launch", "l2:pb1-ladder", "l3:pb1-probes"], "R-PX2: the name roc in place of the file"),
    ("L3", L, '("ROC_CACHE_DIR", clean(facts.build)), inside]', '("ROC_CACHE_DIR", clean(facts.build))]', ["l0:launch", "l2:pb1-ladder", "l3:pb1-probes"], "R-EV17: no TALON_IN_PROXY"),
    ("L4", L, '[("XDG_CACHE_HOME", clean(facts.xdg)), ("ROC_CACHE_DIR", clean(facts.build)), inside]', '[("ROC_CACHE_DIR", clean(facts.build)), ("XDG_CACHE_HOME", clean(facts.xdg)), inside]', ["l0:launch", "l2:pb1-ladder"], "R-PX6: the variables are in the wrong order"),
    ("L5", L, "fx.canonical!([xdg, roots.build])", "fx.canonical!([roots.build, xdg])", ["l2:pb1-ladder", "l3:pb1-probes"], "R-PX6: the canonical paths are asked in the wrong order"),
    ("L6", L, "fx.canonical!([xdg, roots.build])", "fx.canonical!([xdg])", ["l2:pb1-ladder", "l3:pb1-probes"], "R-PX6: one canonical path is not asked"),
    ("L7", L, "content: Launch.last_use(run.now) }", "content: Launch.last_use(run.now + 1) }", ["l2:pb1-ladder", "l3:pb1-probes"], "R-CC9: wrong time in .last-use"),
    ("L8", L, 'last_use = |now| "${Clock.format_utc(now)}\\n"', "last_use = |now| Clock.format_utc(now)", ["l0:launch", "l2:pb1-ladder"], "R-CC9: no line end"),
    ("L9", L, 'fx.list_dirs!([Text.join(roots.cache, "toolchains")])', 'fx.list_dirs!([Text.join(roots.cache, "talon")])', ["l2:pb1-ladder"], "R-LY1: wrong dir for the listing"),
    ("L10", L, "ToolchainLastUse(run.id)", "ToolchainMeta(run.id)", ["l2:pb1-ladder", "l3:pb1-probes"], "R-CC9: wrong item for the .last-use file"),
    ("L11", L, 'Err(Failed) => Text.resolve("/", dir.path)', "Err(Failed) => dir.path", ["l0:launch"], "R-PX6: a .. is not removed"),
    ("L12", L, "match results.get(at) {", "match results.get(at - at) {", ["l2:pb1-ladder", "l3:pb1-probes"], "R-PX6: both variables get the first canonical path"),
    ("L13", L, "canonical = if run.opted_out [] else fx.canonical!", "canonical = if !run.opted_out [] else fx.canonical!", ["l2:pb1-ladder", "l2:px1-flow"], "R-PX7: canonical! called only when opted out"),
    ("D1", D, FIRST_COPY, FIRST_COPY.replace("probes_touched!(fx, { roots: request.roots, now: request.now, started, specs: plan.first })", "fx.probes!(plan.first)"), ["l2:pb1-ladder"], "R-CC9: no .last-use before the first round of a copy"),
    ("D2", D, BUILD_COPY, PLAIN_COPY_BUILD, ["l2:pb1-ladder"], "R-CC9: no .last-use before the build of a copy"),
    ("D3", D, BUILD_PLACE, PLAIN_PLACE_BUILD, ["l2:pb2-verify", "l3:pb1-probes"], "R-CC9: no .last-use before the build of verify"),
    ("D4", D, FIRST_PLACE, FIRST_PLACE.replace("probes_touched!(fx, { roots: request.roots, now: request.now, started, specs: plan.first })", "fx.probes!(plan.first)"), ["l2:pb2-verify", "l3:pb1-probes"], "R-CC9: no .last-use before the first round of verify"),
    ("D5", D, "if run.started.installed.contains(run.started.id) {", "if run.started.id != \"\" {", ["l2:pb1-ladder", "l2:pb2-verify"], "R-CC9: .last-use for the roc on PATH"),
    ("D6", D, "{ id: run.started.id, now: run.now }", "{ id: run.started.id, now: 0 }", ["l2:pb1-ladder", "l3:pb1-probes"], "R-CC9: time 0 in .last-use"),
    ("D7", D, "program: facts.program, args, dir, env: facts.env, timeout: facts.timeout }", 'program: "roc", args, dir, env: facts.env, timeout: facts.timeout }', ["l0:ladder", "l2:pb1-ladder"], "R-PX2: plan has the name roc"),
    ("D8", D, "program: facts.program, args, dir, env: facts.env, timeout: facts.timeout }", "program: facts.program, args, dir, env: [], timeout: facts.timeout }", ["l0:ladder", "l2:pb1-ladder"], "R-PX6: plan has no env"),
    ("D9", D, "program: facts.program, args, dir: facts.dir, env: facts.env, timeout: facts.timeout }", 'program: "roc", args, dir: facts.dir, env: facts.env, timeout: facts.timeout }', ["l0:verify", "l2:pb2-verify"], "R-PX2: plan_replace has the name roc"),
    ("D10", D, "program: facts.program, args, dir: facts.dir, env: facts.env, timeout: facts.timeout }", "program: facts.program, args, dir: facts.dir, env: [], timeout: facts.timeout }", ["l0:verify", "l2:pb2-verify"], "R-PX6: plan_replace has no env"),
    ("D11", D, "program: started.program, env: started.env, kind: member.kind, dir, file, copy, timeout })", 'program: "roc", env: started.env, kind: member.kind, dir, file, copy, timeout })', ["l2:pb1-ladder"], "R-PX2: run! gives the name roc"),
    ("D12", D, "Launch.child_env!(fx, run.roots, { opted_out: Bool.False })", "Launch.child_env!(fx, run.roots, { opted_out: Bool.True })", ["l2:pb1-ladder", "l3:pb1-probes"], "R-PX6: a probe is opted out"),
    ("D13", D, "installed = Launch.toolchains!(fx, run.roots)\n\tid = ", "installed = []\n\tid = ", ["l2:pb1-ladder"], "R-SO22: no listing of toolchains"),
    ("D14", D, "program: Launch.program({ roots: run.roots, id, installed, path: run.path_roc })", "program: Launch.program({ roots: run.roots, id: run.held, installed, path: run.path_roc })", ["l2:pb1-ladder"], "R-CV1: the program of the held id, not of the id that runs"),
    ("D15", D, "compiler = request.held\n\tpkgs = request.roots.pkgs\n\tplan = Ladder.plan(", "compiler = started.id\n\tpkgs = request.roots.pkgs\n\tplan = Ladder.plan(", ["l2:pb1-ladder"], "D4a: the plan has the installed id, not the held id"),
    ("D16", D, "Compiler.require({ id: run.held, installed, path: run.path_roc })?", "Compiler.require({ id: run.held, installed: [], path: run.path_roc })?", ["l2:pb1-ladder"], "R-PH7: require does not see the installed compilers"),
    ("J1", J, "\t\t.args_str(spec.args)\n\t\t.envs_str(spec.env)", "\t\t.args_str(spec.args)", ["l3:pr1-real-fx-probes", "l3:pb1-probes"], "R-PX6: env is not set"),
    ("J2", J, "Cmd.new_str(spec.program)", 'Cmd.new_str("roc")', ["l3:pr1-real-fx-probes", "l3:pb1-probes"], "R-PX2: the name roc runs"),
    ("I1", I, "else Install.on_path_file!(fx, roots)", 'else Install.on_path_file!(fx, roots).map_ok(|found| { ..found, path: "roc" })', ["l2:rs-unmanaged", "l2:vf1-flow", "l3:pb1-probes"], "R-SO9: the file of PATH is the name roc"),
    ("P1", P, "if !off and have.contains(id) {", "if !off {", ["l2:px1-flow"], "R-CC9: .last-use for a compiler that is not installed"),
    ("P2", P, "Launch.child_env!(fx, roots, { opted_out: off })", "Launch.child_env!(fx, roots, { opted_out: Bool.False })", ["l2:px1-flow"], "R-PX7: the cache variables for an opted-out proxy"),
    ("P3", P, "Launch.program({ roots, id, installed: have, path: on_path })", "Launch.program({ roots, id, installed, path: on_path })", ["l2:px2-install"], "R-PX2: the program after an install ignores the new compiler"),
]


def restore(rel):
    shutil.copy2(os.path.join(FINAL, rel), os.path.join(ROOT, rel))


def run(test):
    kind, _, arg = test.partition(":")
    if kind == "l0":
        cmd = [ROC, "test", f"tests/unit/{arg}.roc", "--no-cache"]
    elif kind == "l2":
        cmd = ["tests/commands/run.sh"] + arg.split()
    else:
        cmd = ["tests/run.sh"] + arg.split()
    try:
        r = subprocess.run(cmd, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=TIMEOUT[kind])
    except subprocess.TimeoutExpired:
        return True
    return r.returncode != 0


def main():
    want = set(sys.argv[1:])
    for mid, rel, old, new, tests, what in M:
        if want and mid not in want:
            continue
        restore(rel)
        path = os.path.join(ROOT, rel)
        text = open(path).read()
        if text.count(old) != 1:
            print(f"{mid}: BAD EDIT ({text.count(old)} matches of {old[:60]!r})", flush=True)
            continue
        open(path, "w").write(text.replace(old, new))
        try:
            built = subprocess.run([ROC, "check", "cli/main.roc"], cwd=ROOT, env=ENV, capture_output=True, text=True)
            if built.returncode != 0:
                print(f"{mid}: DID NOT COMPILE ({what}) " + built.stdout[:300].replace("\n", " "), flush=True)
                continue
            caught_by = next((t for t in tests if run(t)), None)
            print(f"{mid}: {'CAUGHT' if caught_by else 'NOT CAUGHT'} by {caught_by or '-'} ({what})", flush=True)
        finally:
            restore(rel)


main()
