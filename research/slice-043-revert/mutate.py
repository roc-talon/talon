# Slice 043 revert check: 10 hand mutations of the reference (the most tricky behaviors), filtered runs only (memory: no full sweep).
# Run from the repo root with the reference in the tree (`research/slice-043-revert/swap.sh ref`): python3 -I research/slice-043-revert/mutate.py [id ...]
# Each mutation changes one file, runs the filtered tests that should catch it, and puts the file back. A mutation that no test catches is printed as OPEN.
import subprocess, sys, os, shutil

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.chdir(ROOT)
ROC = os.environ.get('ROC') or f'{ROOT}/cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc'
ENV = dict(os.environ, ROC=ROC)

L0 = ('l0', ['bash', '-c', f'{ROC} test tests/unit/l0-1.roc --no-cache 2>&1 | tail -3 | grep -q "All (.*) tests passed"'])
L0V = ('l0-vars', ['bash', '-c', f'{ROC} test tests/unit/l0-2.roc --no-cache 2>&1 | tail -3 | grep -q "All (.*) tests passed"'])
L2PA = ('l2 patch/pa2-resolve', ['tests/commands/run.sh', 'patch/pa2-resolve'])
L2PX = ('l2 proxy/px3-patch', ['tests/commands/run.sh', 'proxy/px3-patch'])
L3PX = ('l3 compilers/px3-proxy-patch', ['tests/run.sh', 'compilers/px3-proxy-patch'])

MUTATIONS = [
    ('A1', 'update holds a patched entry: it is free (R-PA4)', 'cli/lib/Vars.roc', 'free = indexed and ((all and !variable.patched) or is_named)', 'free = indexed and (all or is_named)', [L0V, L2PA]),
    ('A2', 'a patched entry is movable (R-SP23)', 'cli/lib/Vars.roc', 'movable_of = |variable, free| !free and variable.host == Indexed and !variable.patched and', 'movable_of = |variable, free| !free and variable.host == Indexed and', [L0V]),
    ('A3', 'a release on which the diff does not apply ends the command: no `again` (R-PA5)', 'cli/lib/PatchApply.roc', 'return Err(Patched.not_applied({ alias: n.need.entry.alias, name, version, hash: n.need.hash, dir: n.need.entry.dir, files }))', 'return Err(Fail.new(NoTuple, "no tuple works: the patch of ${n.need.entry.alias} does not apply to ${name} ${version}: ${Str.join_with(files, ", ")}. Edit the copy ${n.need.entry.dir}/, or remove the [patch] entry ${n.need.entry.alias}."))', [L2PA]),
    ('A4', 'the temp copy keeps a file that the diff deletes (R-PA5)', 'cli/lib/PatchApply.roc', 'Remove => Ok(Text.join(temp, d.path))', 'Remove => Err(NoRemove)', [L2PA]),
    ('A5', 'update and upgrade rebase a stale patch too (R-PA6: only tln install)', 'cli/lib/Patched.roc', 'and (url != e.url or x.install)', '', [L0]),
    ('A6', 'the proxy stops a stale patch with another exit code (R-PA6: 14)', 'cli/lib/Patched.roc', 'Proxy => Fail.new(Frozen, "stale patch', 'Proxy => Fail.new(Usage, "stale patch', [L0, L2PX, L3PX]),
    ('A7', 'the flags go after -- (R-PX5)', 'cli/lib/Patched.roc', 'Ok(parts) => parts.before.concat(flags).append("--").concat(parts.after)', 'Ok(_) => x.args.concat(flags)', [L0, L2PX, L3PX]),
    ('A8', 'the baseline check gets the pairs of the candidate (R-PA10)', 'cli/lib/Ladder.roc', 'base: member.patch.base, candidate: member.patch.candidate })', 'base: member.patch.candidate, candidate: member.patch.candidate })', [L2PA]),
    ('A9', 'the base of the entry is not set to the new hash (R-PA5)', 'cli/lib/PatchApply.roc', 'alias: r.entry.alias, entry: r.entry.path, base: r.hash }', 'alias: r.entry.alias, entry: r.entry.path, base: r.entry.base }', [L2PA]),
    ('A10', 'TALON_PROXY=0 checks and flags (R-PX7)', 'cli/lib/Proxy.roc', 'replace: if off [] else loaded.patch.replace', 'replace: loaded.patch.replace', [L2PX, L3PX]),
    ('A11', 'install --frozen does not check a stale patch (R-PA6)', 'cli/lib/InstallFlow.roc', 'if !stale.is_empty() {', 'if Bool.False and !stale.is_empty() {', [L2PA]),
    ('A12', 'verify has no pairs of patches (R-PA10)', 'cli/lib/VerifyFlow.roc', 'patch: Patched.replaces(PatchApply.entries(m)) })', 'patch: [] })', [L2PA]),
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
            open(path, 'w').write(src)
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
