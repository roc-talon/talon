#!/usr/bin/env python3
# Slice 032 revert check, manager review round (TW12): one change at a time in the private reference, run the steps that can see it, write the result.
# Usage: mutate.py [id ...]   (no id: all)   Run with the reference in the tree (swap.sh ref). Steps run one after the other (one scripts/test.sh at a time).
import os, subprocess, sys, shutil
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
os.chdir(ROOT)
REF = 'research/slice-032-revert/reference/'
L = 'cli/lib/'
M = []
STEPS = {'UnitFlow.roc': 'l2', 'InstallFlow.roc': 'l2', 'BuildSkip.roc': 'l0:buildskip', 'BuildFlow.roc': 'l2', 'Ladder.roc': 'l2', 'Probe.roc': 'l0:probe l0:units', 'Opts.roc': 'l0:opts l3f:update/up2', 'Intent.roc': 'l0:intent', 'ResolveBase.roc': 'l2', 'Units.roc': 'l0:units', 'Uses.roc': 'l0:uses', 'Ladder.roc': 'l2', 'RealJobs.roc': 'l3f:fx/pl1', 'RemoveFlow.roc': 'l2', 'VerifyFlow.roc': 'l2', 'Facts.roc': 'l0:facts l2', 'Db.roc': 'l0:db', 'RealDb.roc': 'l3f:update/bs1', 'FakeDb.roc': 'l2'}
def m(id, rule, file, old, new, steps=None):
    steps = steps or STEPS[os.path.basename(file)]
    M.append(dict(id=id, rule=rule, file=file, old=old, new=new, steps=steps))


S = L+'BuildSkip.roc'
F = L+'BuildFlow.roc'
LD = L+'Ladder.roc'
FA = L+'Facts.roc'
DB = L+'Db.roc'
RD = 'cli/RealDb.roc'
FK = 'tests/commands/FakeDb.roc'
SAME = 'row.closure == facts.digest)\n\t\tpassed'
m('n1', 'R-BS2', S, 'blocked = same.any(|row| row.outcome != Pass)', 'blocked = Bool.False')
m('n2', 'R-BS2', S, 'blocked = same.any(|row| row.outcome != Pass)', 'blocked = same.any(|row| row.outcome == Fail)')
m('n3', 'R-BS2', S, 'row.target == facts.key.target and row.closure == facts.digest)', 'row.target == facts.key.target)')
m('n4', 'R-BS1', S, 'passed = !facts.digest.is_empty() and same.any(|row| row.outcome == Pass)', 'passed = same.any(|row| row.outcome == Pass)')
m('n5', 'R-BS2', S, 'blocked = same.any(|row| row.outcome != Pass)', 'blocked = facts.facts.any(|row| row.hash == facts.key.hash and row.nightly == facts.key.nightly and row.target == facts.key.target and row.outcome != Pass)')
m('n6', 'R-P4', FA, 'Fail(_) => row(Fail, failing_modules(facts.hash, facts.errors), closure)', 'Fail(_) => row(Fail, failing_modules(facts.hash, facts.errors), "")')
m('n7', 'R-P3', FA, 'Hang => row(Hang, [], closure)', 'Hang => row(Hang, [], "")')
m('n8', 'R-P3', FA, 'Crash(_) => row(Crash, [], closure)', 'Crash(_) => row(Crash, [], "")')
m('n9', 'R-BS2', F, 'match BuildSkip.row({ key: found.key, digest: found.digest, class, errors }) {', 'match (if class == Pass BuildSkip.row({ key: found.key, digest: found.digest, class, errors }) else Err(NoFact)) {')
m('n10', 'R-P4', F, '_ = Facts.save!(fx, { roots: ctx.roots, rows: [row], existing: Replace })?', '_ = Facts.save!(fx, { roots: ctx.roots, rows: [row], existing: Keep })?')
m('n11', 'R-BS2', LD, 'BuildFlow.after!(fx, ctx, { id: step.id, output: third.output, dir: copy, pkgs })?\n\t\t\t\tbuilt = LadderJudge.build({ output: third.output, dir: copy, pkgs, baseline, owners: request.owners, compiler, timeout })?', 'built = LadderJudge.build({ output: third.output, dir: copy, pkgs, baseline, owners: request.owners, compiler, timeout })?\n\t\t\t\tBuildFlow.after!(fx, ctx, { id: step.id, output: third.output, dir: copy, pkgs })?')
m('n12', 'R-BS2', LD, 'BuildFlow.after!(fx, ctx, { id: step.id, output: third.output, dir, pkgs })?\n\t\t\t\tbuilt = LadderJudge.build({ output: third.output, dir, pkgs, baseline, owners: request.owners, compiler, timeout })?', 'built = LadderJudge.build({ output: third.output, dir, pkgs, baseline, owners: request.owners, compiler, timeout })?\n\t\t\t\tBuildFlow.after!(fx, ctx, { id: step.id, output: third.output, dir, pkgs })?')
m('n13', 'R-P4', DB, '\t|> then_by(Text.compare(a.closure, b.closure))\n', '')
m('n14', 'R-BS2', RD, ['PRIMARY KEY (hash, nightly, target, closure)) WITHOUT ROWID', 'ON CONFLICT(hash, nightly, target, closure) DO UPDATE'], ['PRIMARY KEY (hash, nightly, target)) WITHOUT ROWID', 'ON CONFLICT(hash, nightly, target) DO UPDATE'])
m('n15', 'R-BS2', FK, 'a.target == b.target and a.closure == b.closure', 'a.target == b.target')
m('n16', 'R-P4', S, 'closure: facts.digest })', 'closure: "" })')
m('n17', 'R-ID6', S, 'host: facts.key.target,', 'host: "any",')
m('n18', 'R-P3', S, 'class: facts.class, errors', 'class: Pass, errors')
m('n19', 'R-P4', S, 'errors: facts.errors, closure', 'errors: [], closure')
M = [x for x in M if x]

ENV = dict(os.environ)
def sh(cmd):
    p = subprocess.run(cmd, shell=True, capture_output=True, text=True, env=ENV, executable='/bin/bash')
    return p.returncode, p.stdout + p.stderr

def run(steps):
    """Returns (result, first failing line). The steps run in order; the first failure ends."""
    for st in steps.split():
        kind, _, arg = st.partition(':')
        if kind == 'l0':
            rc, log = sh('. scripts/env.sh; $ROC test tests/unit/%s.roc --no-cache' % arg)
            if rc != 0:
                bad = [l for l in log.splitlines() if 'compiler error' in l and not l.strip().startswith('0')]
                if any(('ERROR' in l or '\u2717' in l) for l in log.splitlines()) and 'failed' not in log:
                    return 'INVALID (does not compile)', st
                return 'caught', st + ' ' + next((l.strip() for l in log.splitlines() if 'failed' in l or 'FAIL' in l), '')[:90]
        elif kind == 'l2':
            rc, log = sh('. scripts/env.sh; $ROC build tests/commands/main.roc --opt=dev --output=$WORK/bin/l2 2>&1 | tail -5; test ${PIPESTATUS[0]} = 0')
            if rc != 0:
                return 'INVALID (does not compile)', 'l2 build'
            rc, log = sh('. scripts/env.sh; L2BIN=$WORK/bin/l2 tests/commands/run.sh')
            if rc != 0:
                return 'caught', 'l2 ' + next((l for l in log.splitlines() if l.startswith('FAIL')), '')
        elif kind == 'l3f':
            rc, log = sh('. scripts/env.sh; tests/run.sh %s' % arg)
            if rc != 0:
                if 'FAIL' not in log:
                    return 'INVALID (does not compile)', 'l3 build'
                return 'caught', 'l3 ' + next((l for l in log.splitlines() if l.startswith('FAIL')), '')
    return 'NOT CAUGHT', ''

def main():
    want = sys.argv[1:]
    out = []
    for x in M:
        if want and x['id'] not in want:
            continue
        path = x['file']
        text = open(path).read()
        olds = x['old'] if isinstance(x['old'], list) else [x['old']]
        news = x['new'] if isinstance(x['new'], list) else [x['new']]
        if any(text.count(o) != 1 for o in olds):
            out.append((x['id'], x['rule'], 'BAD MUTATION (%s matches)' % [text.count(o) for o in olds], ''))
            print(out[-1], flush=True)
            continue
        for o, n in zip(olds, news):
            text = text.replace(o, n)
        open(path, 'w').write(text)
        try:
            res, why = run(x['steps'])
        finally:
            shutil.copyfile(REF + path, path)
        out.append((x['id'], x['rule'], res, why))
        print(out[-1], flush=True)
    sh('. scripts/env.sh; $ROC build tests/commands/main.roc --opt=dev --output=$WORK/bin/l2')
    with open('research/slice-032-revert/results-v2-%s.md' % ('part' if want else 'all'), 'w') as f:
        f.write('| id | rule | result | first failing line |\n| --- | --- | --- | --- |\n')
        for r in out:
            f.write('| %s | %s | %s | %s |\n' % r)
main()
