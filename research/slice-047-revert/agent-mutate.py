#!/usr/bin/env python3
"""MUT_CMD=<command> replaces the test command of the chosen mutation.
Revert check of slice 047 (code agent). Each mutation breaks cli/lib in one small way, runs only the test that must see it,
records the result, and puts the file back. Run from the repo root: python3 research/slice-047-revert/agent-mutate.py [number ...]
The final check: sha256sum -c research/slice-047-revert/code-final.sha256"""
import os, re, subprocess, sys

ROOT = os.getcwd()
L0 = "ROC=cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc; XDG_CACHE_HOME=$PWD/.work/cache ROC_CACHE_DIR=$PWD/.work/cache/roc $ROC test tests/unit/l0-5.roc"
L2 = "tests/commands/run.sh tool/ti3-compiler tool/ti4-nothing"
L3 = "tests/run.sh tools/ti2-tool-compiler"
C = "cli/lib/ToolCompiler.roc"
F = "cli/lib/ToolCompilerFlow.roc"
T = "cli/lib/ToolTry.roc"

# (number, what, file, [(old text, new text)], command, the test that must see it)
M = [
    (1, "the digest ignores the hashes of the header", C,
     [("facts.hashes.append(facts.bundle).map", "[facts.bundle].map")], L0, "L0 ToolCompilerTest 2"),
    (2, "the evidence key has the target `any` (not the host target)", C,
     [("key: { hash, nightly: id, target: run.target }, digest: run.digest", "key: { hash, nightly: id, target: \"any\" }, digest: run.digest")], L0, "L0 ToolCompilerTest 3"),
    (3, "D-E3: `--yes` wins over `--roc installed`", C,
     [("\t\tInstalled => TryInstalled\n\t\t_ => {", "\t\tInstalled if !run.yes => TryInstalled\n\t\t_ => {")], L0, "L0 ToolCompilerTest 5"),
    (4, "D-E3: a flag removes the evidence pass (the flag wins over the evidence)", F,
     [("keys: ToolCompiler.evidence_keys({ pf: run.pf, target: run.target, ids }) })?",
       "keys: if run.roc == Auto ToolCompiler.evidence_keys({ pf: run.pf, target: run.target, ids }) else [] })?")], L2, "L2 ti3-compiler run 6"),
    (5, "the checks run one by one (a probes! call for each release)", T,
     [("\touts = fx.probes!({ pool: 12, specs: $specs.map(|s| ToolCompiler.check_spec({ id: s.id, program: s.program, env, dir, timeout: run.timeout })) })\n",
       "\tvar $outs = []\n\tfor s in $specs {\n\t\t$outs = $outs.concat(fx.probes!({ pool: 12, specs: [ToolCompiler.check_spec({ id: s.id, program: s.program, env, dir, timeout: run.timeout })] }))\n\t}\n\touts = $outs\n")],
     L2, "L2 ti3-compiler runs 2 to 4 (probes 4), L3 step 1"),
    (6, "the builds go on after the first pass (no break)", T,
     [("\t\t\t\t\t\t$found = Somebody({ id: one.id, layout: attempt.layout })\n\t\t\t\t\t\tbreak\n", "\t\t\t\t\t\t$found = Somebody({ id: one.id, layout: attempt.layout })\n")],
     L2, "L2 ti3-compiler run 2 (D is never built)"),
    (7, "the prompt after option 2 offers option 2 again", F,
     [("size: found.size, installed: 0, tried: state.list })\n\t\t\t\t\tmatch ask!(fx, ctx, { prompt, installed: 0 })? {",
       "size: found.size, installed: ctx.ids.len(), tried: state.list })\n\t\t\t\t\tmatch ask!(fx, ctx, { prompt, installed: ctx.ids.len() })? {")],
     L2, "L2 ti3-compiler run 4"),
    (8, "no person after option 2: the failure is the cancel text, not the list of releases", F,
     [("\t\t_ => Err(ToolCompiler.all_failed({ name: ctx.run.name, version: ctx.run.version, pin: ctx.pin, tried: state.list }))",
       "\t\t_ => Err(ToolCompiler.declined(ctx.pin))")],
     L2, "L2 ti3-compiler run 3, ti4-nothing run 2"),
    (9, "the build row of a failed try is not written", T,
     [("\t\t_ = Facts.save!(fx, { roots: run.roots, rows: [row], existing: Replace })?\n\t\tOk({})",
       "\t\t_ = Facts.save!(fx, { roots: run.roots, rows: match built.attempt.class {\n\t\t\tPass => [row]\n\t\t\t_ => []\n\t\t}, existing: Replace })?\n\t\tOk({})")],
     L2, "L2 ti3-compiler runs 2, 3"),
    (10, "`tty!` is called at the start (not lazy)", F,
     [("\tmode = Mode.from_env({ env: Dict.from_list(ctx.run.env), json: ctx.args.json })\n",
       "\tmode = Mode.with_tty(Mode.from_env({ env: Dict.from_list(ctx.run.env), json: ctx.args.json }), fx.tty!())\n")],
     L2, "L2 ti3-compiler run 3, ti4-nothing run 2/3 (a tty call in calls.log)"),
    (11, "review 2 (C3): the platform line prints again for the build after a failed option 2 and a download", F,
     [("first: !state.list.any(|t| built(t))", "first: Bool.True")],
     L2, "L2 ti3-compiler run 7 (a second `platform` line in stderr)"),
]

def run(cmd):
    p = subprocess.run(cmd, shell=True, cwd=ROOT, capture_output=True, text=True, executable="/bin/bash")
    return p.returncode, p.stdout + p.stderr

def main():
    want = [int(a) for a in sys.argv[1:]]
    for num, what, path, edits, cmd, expect in M:
        if want and num not in want:
            continue
        full = os.path.join(ROOT, path)
        original = open(full).read()
        mutated = original
        for o, n in edits:
            assert mutated.count(o) == 1, f"mutation {num}: old text found {mutated.count(o)} times"
            mutated = mutated.replace(o, n, 1)
        try:
            open(full, "w").write(mutated)
            rc, out = run(os.environ.get('MUT_CMD') or cmd)
        finally:
            open(full, "w").write(original)
        fails = [l.strip() for l in out.splitlines() if l.startswith("FAIL") or "FAILED" in l or " failed" in l.lower()][:3]
        where = sorted(set(re.findall(r"ToolCompilerTest\.roc:\d+", out)))[:3]
        if where:
            fails.append("at " + ", ".join(where))
        print(f"{num}\t{'CAUGHT' if rc != 0 else 'NOT CAUGHT'}\t{what}\t(expected: {expect})\t{' | '.join(fails)}", flush=True)

main()
