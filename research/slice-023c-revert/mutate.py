#!/usr/bin/env python3
"""Slice 023c revert check (TW12). One small change of the private reference (research/slice-023c-revert/reference/) at a time.
Usage: mutate.py [id ...]   (no id: all). The tree must hold the reference. Each file is put back from reference/ after its mutation.
A mutation counts as caught when one of its tests fails. A mutation that does not compile is INVALID (not a catch).
Tests: l0:<unit file name> | l2:<case filter> | l3:<case filter>."""
import os, shutil, subprocess, sys, time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
REF = os.path.join(ROOT, "research/slice-023c-revert/reference")
ROC = os.environ.get("ROC", f"{ROOT}/cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
L, C, D, P, J, R = "cli/lib/Launch.roc", "cli/lib/Compiler.roc", "cli/lib/Ladder.roc", "cli/lib/Proxy.roc", "cli/RealJobs.roc", ""

# (id, file, old, new, [tests])
M = [
 ("C1", C, "match facts.installed.find_first(|name| Pin.same_id(facts.id, name)) {", "match facts.installed.find_first(|name| name == \"-\") {", ["l0:compiler", "l2:pb1-ladder"]),
 ("C2", C, "match facts.installed.find_first(|name| Pin.same_id(facts.id, name)) {", "match facts.installed.find_first(|name| name == facts.id) {", ["l0:compiler", "l2:pb1-ladder"]),
 ("C3", C, "Ok(found) if Pin.same_id(facts.id, found.id) => Ok(found.id)", "Ok(found) if found.id == facts.id => Ok(found.id)", ["l0:compiler"]),
 ("C4", C, "Err(_) => match facts.path {\n\t\t\tOk(found) if Pin.same_id(facts.id, found.id) => Ok(found.id)\n\t\t\t_ => Err(not_installed(facts.id))\n\t\t}", "Err(_) => match facts.path {\n\t\t\tOk(found) => Ok(found.id)\n\t\t\t_ => Err(not_installed(facts.id))\n\t\t}", ["l0:compiler", "l2:pb1-ladder"]),
 ("C5", C, "Fail.new(Consent, \"the compiler ${id} is not installed. Run: tln roc install ${id}.\")", "Fail.new(Consent, \"the compiler ${id} is not installed. Run: tln roc install ${id}, or set TALON_AUTO_INSTALL=yes.\")", ["l0:compiler", "l2:pb1-ladder"]),
 ("C6", C, "Fail.new(Consent, \"the compiler ${id} is not installed.", "Fail.new(Usage, \"the compiler ${id} is not installed.", ["l0:compiler"]),
 ("L1", L, "Ok(found) if found.id == run.id and !run.installed.contains(run.id) => found.path", "Ok(found) if found.id == run.id => found.path", ["l0:launch", "l2:pb1-ladder", "l3:pb1-probes"]),
 ("L2", L, "Ok(found) if found.id == run.id and !run.installed.contains(run.id) => found.path", "Ok(found) if found.id == run.id and !run.installed.contains(run.id) => \"roc\"", ["l0:launch", "l2:pb1-ladder", "l3:pb1-probes"]),
 ("L3", L, "[(\"XDG_CACHE_HOME\", clean(facts.xdg)), (\"ROC_CACHE_DIR\", clean(facts.build)), inside]", "[(\"XDG_CACHE_HOME\", clean(facts.xdg)), (\"ROC_CACHE_DIR\", clean(facts.build))]", ["l0:launch", "l2:pb1-ladder", "l3:pb1-probes"]),
 ("L4", L, "[(\"XDG_CACHE_HOME\", clean(facts.xdg)), (\"ROC_CACHE_DIR\", clean(facts.build)), inside]", "[(\"ROC_CACHE_DIR\", clean(facts.build)), (\"XDG_CACHE_HOME\", clean(facts.xdg)), inside]", ["l0:launch", "l2:pb1-ladder"]),
 ("L5", L, "canonical = if run.opted_out [] else fx.canonical!([xdg, roots.build])", "canonical = if run.opted_out [] else fx.canonical!([roots.build, xdg])", ["l2:pb1-ladder", "l3:pb1-probes"]),
 ("L6", L, "canonical = if run.opted_out [] else fx.canonical!([xdg, roots.build])", "canonical = if run.opted_out [] else fx.canonical!([xdg])", ["l2:pb1-ladder", "l3:pb1-probes"]),
 ("L7", L, "content: Launch.last_use(run.now) }", "content: Launch.last_use(run.now + 1) }", ["l2:pb1-ladder", "l3:pb1-probes"]),
 ("L8", L, "last_use = |now| \"${Clock.format_utc(now)}\\n\"", "last_use = |now| Clock.format_utc(now)", ["l0:launch", "l2:pb1-ladder"]),
 ("L9", L, "toolchains! = |fx, roots| match fx.list_dirs!([Text.join(roots.cache, \"toolchains\")]) {", "toolchains! = |fx, roots| match fx.list_dirs!([Text.join(roots.cache, \"talon\")]) {", ["l2:pb1-ladder"]),
 ("L10", L, "Roots.item(roots, ToolchainLastUse(run.id))", "Roots.item(roots, ToolchainMeta(run.id))", ["l2:pb1-ladder", "l3:pb1-probes"]),
 ("D1", D, "\ttouch!(fx, started, { roots: request.roots, now: request.now })\n\tfirst = match fx.probes!(plan.first) {\n\t\t[base, candidate] => (base, candidate)\n\t\t_ => return Err(no_answer(\"the probes\"))\n\t}\n\tbaseline = Ladder.baseline({ output: first.0, dir, pkgs, compiler, timeout })?\n\tchecked = Ladder.check({ output: first.1, dir: copy,", "\tfirst = match fx.probes!(plan.first) {\n\t\t[base, candidate] => (base, candidate)\n\t\t_ => return Err(no_answer(\"the probes\"))\n\t}\n\tbaseline = Ladder.baseline({ output: first.0, dir, pkgs, compiler, timeout })?\n\tchecked = Ladder.check({ output: first.1, dir: copy,", ["l2:pb1-ladder"]),
 ("D2", D, "Ok(spec) => match probes_touched!(fx, started, { roots: request.roots, now: request.now }, [spec]) {\n\t\t\t[output] => {\n\t\t\t\tbuilt = Ladder.build({ output, dir: copy,", "Ok(spec) => match fx.probes!([spec]) {\n\t\t\t[output] => {\n\t\t\t\tbuilt = Ladder.build({ output, dir: copy,", ["l2:pb1-ladder"]),
 ("D3", D, "Ok(spec) => match probes_touched!(fx, started, { roots: request.roots, now: request.now }, [spec]) {\n\t\t\t[output] => {\n\t\t\t\tbuilt = Ladder.build({ output, dir, pkgs,", "Ok(spec) => match fx.probes!([spec]) {\n\t\t\t[output] => {\n\t\t\t\tbuilt = Ladder.build({ output, dir, pkgs,", ["l2:pb2-verify", "l3:pb1-probes"]),
 ("D4", D, "\ttouch!(fx, started, { roots: request.roots, now: request.now })\n\tfirst = match fx.probes!(plan.first) {\n\t\t[base, candidate] => (base, candidate)\n\t\t_ => return Err(no_answer(\"the probes\"))\n\t}\n\tbaseline = Ladder.baseline({ output: first.0, dir, pkgs, compiler, timeout })?\n\tchecked = Ladder.check({ output: first.1, dir, pkgs,", "\tfirst = match fx.probes!(plan.first) {\n\t\t[base, candidate] => (base, candidate)\n\t\t_ => return Err(no_answer(\"the probes\"))\n\t}\n\tbaseline = Ladder.baseline({ output: first.0, dir, pkgs, compiler, timeout })?\n\tchecked = Ladder.check({ output: first.1, dir, pkgs,", ["l2:pb2-verify", "l3:pb1-probes"]),
 ("D5", D, "\tif started.installed.contains(started.id) {\n\t\tLaunch.touch!(fx, run.roots, { id: started.id, now: run.now })\n\t}", "\tLaunch.touch!(fx, run.roots, { id: started.id, now: run.now })", ["l2:pb1-ladder", "l2:pb2-verify"]),
 ("D6", D, "Launch.touch!(fx, run.roots, { id: started.id, now: run.now })", "Launch.touch!(fx, run.roots, { id: started.id, now: 0 })", ["l2:pb1-ladder", "l3:pb1-probes"]),
 ("D7", D, "$done = $done.append({ file: member.file, lines: verify_member!(fx, request, started, member)? })", "$done = $done.append({ file: member.file, lines: verify_member!(fx, request, match start!(fx, { roots: request.roots, path_roc: request.path_roc, held: request.held }) {\n\t\t\t\tOk(again) => again\n\t\t\t\tErr(_) => started\n\t\t\t}, member)? })", ["l2:pb2-verify"]),
 ("D8", D, "$done = $done.append({ file: member.file, lines: probe_member!(fx, request, started, member)? })", "$done = $done.append({ file: member.file, lines: probe_member!(fx, request, match start!(fx, { roots: request.roots, path_roc: request.path_roc, held: request.held }) {\n\t\t\t\tOk(again) => again\n\t\t\t\tErr(_) => started\n\t\t\t}, member)? })", ["l2:resolve/rs-workspace-shared-group", "l2:pb1-ladder"]),
 ("D9", D, "program: facts.program, args, dir, env: facts.env, timeout: facts.timeout }\n\t\tcheck_args", "program: facts.program, args, dir, env: [], timeout: facts.timeout }\n\t\tcheck_args", ["l0:ladder", "l2:pb1-ladder"]),
 ("D10", D, "program: facts.program, args, dir: facts.dir, env: facts.env, timeout: facts.timeout }", "program: \"roc\", args, dir: facts.dir, env: facts.env, timeout: facts.timeout }", ["l0:verify", "l2:pb2-verify"]),
 ("D11", D, "plan = Ladder.plan({ compiler, program: started.program, env: started.env,", "plan = Ladder.plan({ compiler: started.id, program: started.program, env: started.env,", ["l2:pb1-ladder"]),
 ("D12", D, "env = Launch.child_env!(fx, request.roots, { opted_out: Bool.False })", "env = Launch.child_env!(fx, request.roots, { opted_out: Bool.True })", ["l2:pb1-ladder", "l3:pb1-probes"]),
 ("D13", D, "installed = Launch.toolchains!(fx, request.roots)\n\tid = Compiler.require({ id: request.held, installed, path: request.path_roc })?", "installed = []\n\tid = Compiler.require({ id: request.held, installed, path: request.path_roc })?", ["l2:pb1-ladder"]),
 ("D14", D, "program: Launch.program({ roots: request.roots, id, installed, path: request.path_roc })", "program: Launch.program({ roots: request.roots, id: request.held, installed, path: request.path_roc })", ["l2:pb1-ladder"]),
 ("J1", J, "\t\t.args_str(spec.args)\n\t\t.envs_str(spec.env)", "\t\t.args_str(spec.args)", ["l3:pr1-real-fx-probes", "l3:pb1-probes"]),
 ("J2", J, "Cmd.new_str(spec.program)", "Cmd.new_str(\"roc\")", ["l3:pr1-real-fx-probes", "l3:pb1-probes"]),
 ("I1", "cli/lib/Install.roc", "else Install.on_path_file!(fx, roots)", "else Install.on_path_file!(fx, roots).map_ok(|found| { ..found, path: \"roc\" })", ["l2:rs-unmanaged", "l2:vf1-flow", "l3:pb1-probes"]),
 ("F1", "cli/lib/InstallFlow.roc", "\tif request.no_check {\n\t\tfx.out!(\"check: skipped\\n\")", "\t_ = fx.list_dirs!([request.roots.cache])\n\tif request.no_check {\n\t\tfx.out!(\"check: skipped\\n\")", ["l2:pb1-ladder"]),
 ("P1", P, "\tif !off and have.contains(id) {\n\t\tLaunch.touch!(fx, roots, { id, now })\n\t}", "\tif !off {\n\t\tLaunch.touch!(fx, roots, { id, now })\n\t}", ["l2:px1-flow"]),
]


def run(test):
    kind, name = test.split(":", 1)
    if kind == "l0":
        cmd = [ROC, "test", f"tests/unit/{name}.roc", "--no-cache"]
    elif kind == "l2":
        cmd = ["tests/commands/run.sh", name]
    else:
        cmd = ["tests/run.sh", name]
    r = subprocess.run(cmd, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    return r.returncode == 0, r.stdout


def main():
    ids = sys.argv[1:]
    for mid, rel, old, new, tests in M:
        if ids and mid not in ids:
            continue
        path = os.path.join(ROOT, rel)
        ref = os.path.join(REF, rel)
        src = open(ref if os.path.exists(ref) else path).read()
        if old not in src:
            print(f"{mid}: NOT APPLIED (old text not found)")
            continue
        open(path, "w").write(src.replace(old, new, 1))
        try:
            chk = subprocess.run([ROC, "check", "cli/main.roc"], cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            if chk.returncode != 0:
                print(f"{mid}: INVALID (does not compile)\n{chk.stdout[:400]}")
                continue
            caught = []
            for t in tests:
                ok, _ = run(t)
                if not ok:
                    caught.append(t)
            print(f"{mid}: {'CAUGHT by ' + ', '.join(caught) if caught else 'NOT CAUGHT'}  (tests: {', '.join(tests)})", flush=True)
        finally:
            open(path, "w").write(src)


main()
