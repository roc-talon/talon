# Slice 054 revert check: hand mutations of the reference (the most tricky behaviors), filtered runs only (memory: no full sweep).
# Run from the repo root with the reference in the tree (`research/slice-054-revert/swap.sh ref`): python3 -I research/slice-054-revert/mutate.py [id ...]
# Each mutation changes one file, runs the filtered tests that should catch it, and puts the file back. A mutation that no test catches is printed as OPEN.
import subprocess, sys, os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.chdir(ROOT)
ROC = os.environ.get('ROC') or f'{ROOT}/cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc'
ENV = dict(os.environ, ROC=ROC)

L0 = ('l0-3', ['bash', '-c', f'{ROC} test tests/unit/l0-3.roc --no-cache 2>&1 | tail -3 | grep -q "All (.*) tests passed"'])
L2 = ('l2 target/*', ['tests/commands/run.sh', 'target/'])
L3 = ('l3 update/tg1-wasm-platform', ['tests/run.sh', 'update/tg1-wasm-platform'])

MUTATIONS = [
    ('B1', 'glibc before musl in the host targets (R-TG1 rule 2)', 'cli/lib/BuildTarget.roc', '(Linux, X64) => ["x64musl", "x64glibc"]', '(Linux, X64) => ["x64glibc", "x64musl"]', [L0, L2]),
    ('B2', 'the one target of the platform wins over [build] target (R-TG1 rule 1)', 'cli/lib/BuildTarget.roc', 'Ok(target) => Ok(Named(target))\n\t\tErr(Unset)', 'Ok(target) => match x.found {\n\t\t\tOk([one]) => Ok(Named(one))\n\t\t\t_ => Ok(Named(target))\n\t\t}\n\t\tErr(Unset)', [L0, L2]),
    ('B3', 'inputs_dir counts as a target (R-TG1)', 'cli/lib/BuildTarget.roc', ' and word != "inputs_dir"', '', [L0]),
    ('B4', 'a key of a nested record counts as a target (R-TG1)', 'cli/lib/BuildTarget.roc', '$state == 2 and $depth == $rec and colon', '$state == 2 and $depth >= $rec and colon', [L0]),
    ('B5', 'gate looks at the first want only (R-C10, two members)', 'cli/lib/BuildTarget.roc', 'wants.any(', 'wants.sublist({ start: 0, len: 1 }).any(', [L0, L2]),
    ('B6', 'admits is true when the list lacks the target (R-C10)', 'cli/lib/BuildTarget.roc', '(Ok(target), Ok(list)) => list.contains(target)', '(Ok(_), Ok(_)) => Bool.True', [L0, L2]),
    ('B7', 'the flag --target goes at the end of the arguments (R-TG2)', 'cli/lib/LadderPlan.roc', '{ ..x.spec, args: [command, "--target=${target}"].concat(rest) }', '{ ..x.spec, args: [command].concat(rest).append("--target=${target}") }', [L0, L2, L3]),
    ('B8', 'the key of the build fact has a fixed target (R-TG2, R-P4)', 'cli/lib/BuildTarget.roc', 'Named(target) => Ok({ hash: x.pf, nightly: x.nightly, target })', 'Named(_) => Ok({ hash: x.pf, nightly: x.nightly, target: "x64musl" })', [L0, L2]),
    ('B9', 'the exit 2 of rule 5 has the kind NoTuple (R-TG1)', 'cli/lib/BuildTarget.roc', 'Err(Fail.new(Usage, "${x.file}: no build target: the platform has the targets', 'Err(Fail.new(NoTuple, "${x.file}: no build target: the platform has the targets', [L0, L2]),
    ('B10', 'a platform with no release that has the target is exit 2, not 10 (R-C10, OP10)', 'cli/lib/BuildTarget.roc', 'Fail.new(NoTuple, "no tuple works: ${x.alias} has no platform release', 'Fail.new(Usage, "no tuple works: ${x.alias} has no platform release', [L0, L2]),
    ('B11', 'the member [build] target is not given to the build (R-TG1)', 'cli/lib/BuildFlow.roc', 'BuildTarget.pick({ project: ctx.target,', 'BuildTarget.pick({ project: Err(Unset),', [L2, L3]),
    ('B12', 'the solver does not get the gate (R-C10)', 'cli/lib/PickLoop.roc', 'facts: BuildTarget.gate({ facts: state.facts, seen: probed.seen, wanted })', 'facts: state.facts', [L2, L3]),
    ('B13', 'a bad [build] target of a package file is exit 19 (R-TG4, Q3)', 'cli/lib/Intent.roc', '(App, Ok(note)) =>', '(_, Ok(note)) =>', [L0, L2]),
    # Gap rows (slice 054, after the code): these mutate the code of the code agent, not the reference (the reference is deleted).
    ('G1', 'wanted: the order of files, not of members (C5)', 'cli/lib/BuildTarget.roc', 'members = x.members.keep_if(|m| slot.files.is_empty() or slot.files.contains(m.file)).keep_oks(|m| m.target)', 'members = (if slot.files.is_empty() x.members else slot.files.join_map(|f| x.members.keep_if(|m| m.file == f))).keep_oks(|m| m.target)', [L0]),
    ('G2', 'wanted: a repeated pair is kept (C5)', 'cli/lib/BuildTarget.roc', '\n\t\t.fold([], |found, want| if found.contains(want) found else found.append(want))', '', [L0]),
    ('G3', 'no_target: the text of R-C10 when any release (not all) is gated out (C3)', 'cli/lib/PickLoop.roc', 'read(slot).all(out)', 'read(slot).any(out)', [L2]),
]

want = sys.argv[1:]
results = []
for mid, text, path, old, new, runs in MUTATIONS:
    if want and mid not in want:
        continue
    src = open(path).read()
    if src.count(old) != 1:
        print(f'{mid}: the old text is {src.count(old)} times in {path}: SKIPPED')
        results.append((mid, text, 'SKIPPED'))
        continue
    open(path, 'w').write(src.replace(old, new))
    caught = []
    try:
        built = subprocess.run(['scripts/test.sh', 'check'], env=ENV, capture_output=True, text=True)
        if built.returncode != 0:
            print(f'{mid}: DID NOT COMPILE: change the text of the mutation')
            results.append((mid, text, 'DID NOT COMPILE'))
            continue
        for name, cmd in runs:
            r = subprocess.run(cmd, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                caught.append(name)
    finally:
        open(path, 'w').write(src)
    state = 'caught by ' + ', '.join(caught) if caught else 'OPEN'
    print(f'{mid}: {text}: {state}', flush=True)
    results.append((mid, text, state))

print()
print(f'{len(results)} mutations, {sum(1 for r in results if r[2] == "OPEN")} open, {sum(1 for r in results if r[2] in ("SKIPPED", "DID NOT COMPILE"))} not run')
