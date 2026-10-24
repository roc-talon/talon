#!/usr/bin/env python3
# Slice 032 revert check of the code agent (TW12): one small change at a time in the final code, run the steps that can see it, write the result.
# The final code is in code-final/ (a copy made before the first mutation). The file of a mutation is restored from there before and after each run.
# Usage: agent-mutate.py [--check] [id ...]   (no id: all). --check only counts the matches of each mutation. One step at a time (one scripts/test.sh at a time). Each step has a timeout.
import os, subprocess, sys, shutil
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
os.chdir(ROOT)
FINAL = 'research/slice-032-revert/code-final/'
L = 'cli/lib/'
S, F, LD, UF = L+'BuildSkip.roc', L+'BuildFlow.roc', L+'Ladder.roc', L+'UnitFlow.roc'
IF, RF, VF, FA, DB, RD = L+'InstallFlow.roc', L+'RemoveFlow.roc', L+'VerifyFlow.roc', L+'Facts.roc', L+'Db.roc', 'cli/RealDb.roc'
L2 = 'l2 l3f:update/bs1'
M = []
def m(id, rule, file, old, new, steps):
    M.append(dict(id=id, rule=rule, file=file, old=old, new=new, steps=steps))

# BuildSkip (pure)
m('b1', 'R-BS2', S, 'Text.sorted_unique(used.map(|one| one.hash))', 'Text.sorted(used.map(|one| one.hash))', 'l0:buildskip')
m('b2', 'R-BS2', S, 'Text.sorted_unique(used.map(|one| one.hash))', 'used.map(|one| one.hash)', 'l0:buildskip')
m('b3', 'R-BS2', S, '"${acc}${hash}\\n"', '"${acc}${hash}"', 'l0:buildskip')
m('b4', 'R-ID6', S, '(Linux, X64) => Ok("x64musl")', '(Linux, X64) => Ok("x64glibc")', 'l0:buildskip')
m('b5', 'R-ID6', S, '(Macos, Arm64) => Ok("arm64mac")', '(Macos, Arm64) => Ok("x64mac")', 'l0:buildskip')
m('b6', 'R-ID6', S, '(Windows, X64) => Ok("x64win")\n', '', 'l0:buildskip')
m('b7', 'R-ID6', S, 'nodes.find_first(|node| node.is_platform)', 'nodes.find_first(|node| !node.is_platform)', 'l0:buildskip')
m('b8', 'R-ID6', S, 'nightly: facts.nightly, target: host', 'nightly: facts.pf, target: host', 'l0:buildskip')
m('b9', 'R-NS12', S, ' and row.nightly == facts.key.nightly', '', 'l0:buildskip')
m('b10', 'R-ID6', S, 'row.hash == facts.key.hash and ', '', 'l0:buildskip')
m('b11', 'R-BS2', S, 'passed and !blocked and', 'passed and', 'l0:buildskip')
m('b12', 'R-BS1', S, ' and !facts.digest.is_empty() Skip', ' Skip', 'l0:buildskip')
m('b13', 'R-BS2', S, 'row.outcome != Pass', 'row.outcome == Fail', 'l0:buildskip')
m('b14', 'R-P4', S, 'closure: facts.digest,', 'closure: "",', 'l0:buildskip')
m('b15', 'R-ID6', S, 'host: facts.key.target,', 'host: "any",', 'l0:buildskip')
m('b16', 'R-P3', S, 'command: Build({ output: "" })', 'command: Check', 'l0:buildskip')
m('b17', 'R-BS2', S, 'skipped_line = "build: skipped (recorded pass)"', 'skipped_line = "build: skipped"', 'l0:buildskip')
m('b18', 'R-BS1', S, 'counts.skipped >= counts.apps Skipped', 'counts.skipped > 0 Skipped', L2)
m('b19', 'R-LD5', S, 'if counts.apps == 0 NotRun', 'if counts.apps == 0 Passed', L2)
# BuildFlow (command code)
m('f1', 'R-LD7', F, 'Err(NoPlatform) => return Ok(plain)', 'Err(NoPlatform) => ""', L2)
m('f2', 'R-UM1', F, 'Ok(scanned) => scanned', 'Ok(_) => UnitFlow.scan!(fx, ctx)', L2)
m('f3', 'R-BS1', F, 'keys: [key] })?', 'keys: [] })?', L2)
m('f4', 'R-BS2', F, 'BuildSkip.decide({ facts, key, digest })', 'BuildSkip.decide({ facts, key, digest: "" })', L2)
m('f5', 'R-BS1', F, 'Skip => Bool.True\n\t\t\tBuild => Bool.False', 'Skip => Bool.False\n\t\t\tBuild => Bool.False', L2)
m('f6', 'R-P4', F, 'rows: [row], existing: Replace })?', 'rows: [row], existing: Keep })?', L2)
m('f7', 'R-P3', F, 'class = Probe.classify(run.output)', 'class = Pass', L2)
m('f8', 'R-P4', F, 'text: run.output.stderr, dir: run.dir', 'text: "", dir: run.dir', L2)
m('f9', 'R-P4', F, 'dir: run.dir, pkgs: run.pkgs })\n\t\t\tmatch', 'dir: run.pkgs, pkgs: run.pkgs })\n\t\t\tmatch', L2)
m('f10', 'R-ID6', F, 'Ok({ skip, id: Ok({ key, digest }) })', 'Ok({ skip, id: Err(NoId) })', L2)
m('f11', 'R-ID6', F, 'nightly: ctx.started.id,', 'nightly: ctx.held,', L2)
# Ladder, UnitFlow
m('l1', 'R-BS2', LD, 'lines: [BuildSkip.skipped_line]', 'lines: []', L2)
m('l2', 'R-BS1', LD, 'probes: run.count, skipped: 1 })', 'probes: run.count, skipped: 0 })', L2)
m('l3', 'R-PP4', LD, 'probes: run.count, skipped: 1 })', 'probes: run.count + 1, skipped: 1 })', L2)
m('l4', 'R-BS2', LD, 'BuildFlow.after!(fx, ctx, { id: plan.id, output: third.output, dir: run.dir, pkgs })?\n\t\tbuilt = LadderJudge.build({ output: third.output, dir: run.dir, pkgs, baseline: run.baseline, owners: run.owners, compiler: ctx.held, timeout: ctx.probe.timeout })?',
  'built = LadderJudge.build({ output: third.output, dir: run.dir, pkgs, baseline: run.baseline, owners: run.owners, compiler: ctx.held, timeout: ctx.probe.timeout })?\n\t\tBuildFlow.after!(fx, ctx, { id: plan.id, output: third.output, dir: run.dir, pkgs })?', L2)
m('l5', 'R-P4', LD, 'BuildFlow.after!(fx, ctx, { id: plan.id,', 'BuildFlow.after!(fx, ctx, { id: Err(NoId),', L2)
m('l6', 'R-UM1', LD, 'count: second.count, used: verdict.used, dir: copy', 'count: second.count, used: match verdict.used { Ok(_) => Err(NotScanned), Err(e) => Err(e) }, dir: copy', L2)
m('l7', 'R-UM1', LD, 'count: second.count, used: verdict.used, dir,', 'count: second.count, used: match verdict.used { Ok(_) => Err(NotScanned), Err(e) => Err(e) }, dir,', L2)
m('l8', 'R-BS1', LD, 'ran = verify_member!(fx, request, { started, facts: $facts, count: $count }, member)?\n\t\t\t$facts = ran.facts\n\t\t\t$count = ran.probes\n\t\t\t$skipped = $skipped + ran.skipped', 'ran = verify_member!(fx, request, { started, facts: $facts, count: $count }, member)?\n\t\t\t$facts = ran.facts\n\t\t\t$count = ran.probes\n\t\t\t$skipped = 0', L2)
m('l9', 'R-BS1', LD, 'ran = probe_member!(fx, request, { started, base: started, facts: $facts, count: $count }, member)?\n\t\t\t$facts = ran.facts\n\t\t\t$count = ran.probes\n\t\t\t$skipped = $skipped + ran.skipped', 'ran = probe_member!(fx, request, { started, base: started, facts: $facts, count: $count }, member)?\n\t\t\t$facts = ran.facts\n\t\t\t$count = ran.probes\n\t\t\t$skipped = 0', L2)
m('l10', 'R-BS1', LD, 'Ok({ lines: built.lines, probes: third.count, skipped: 0 })', 'Ok({ lines: built.lines, probes: third.count, skipped: 1 })', L2)
m('l11', 'R-P5', LD, 'timeout: ctx.probe.timeout })?\n\t\tOk({ lines: built.lines', 'timeout: 5 })?\n\t\tOk({ lines: built.lines', L2)
m('l12', 'R-UM1', UF, 'scanned = if suspects.is_empty() Err(NotScanned) else Ok(UnitFlow.scan!(fx, ctx))', 'scanned = if suspects.len() > 100 Err(NotScanned) else Ok(UnitFlow.scan!(fx, ctx))', L2)
m('l13', 'R-UM1', UF, 'used: scanned ?? [] })?', 'used: [] })?', L2)
m('l14', 'R-UM1', UF, 'Ok({ used: scanned })', 'Ok({ used: Err(NotScanned) })', L2)
# the flows
m('w1', 'R-LD5', IF, 'apps: members.count_if(|m| m.kind == App)', 'apps: members.len()', L2)
m('w2', 'R-BS1', IF, 'skipped: done.skipped', 'skipped: 0', L2)
m('w3', 'R-BS1', RF, 'skipped: done.skipped', 'skipped: 0', L2)
m('w4', 'R-BS1', VF, 'skipped: done.skipped', 'skipped: 0', L2)
m('w5', 'R-LD5', VF, 'apps: checked.count_if(|m| m.kind == App)', 'apps: checked.len()', L2)
m('w6', 'R-LD5', RF, 'apps: if member.locked.kind == App 1 else 0', 'apps: 1', L2)
# Facts, Db, RealDb
m('n1', 'R-P4', FA, 'Pass => row(Pass, [], closure)', 'Pass => row(Pass, [], "")', 'l0:facts ' + L2)
m('n2', 'R-P4', FA, 'Fail(_) => row(Fail, failing_modules(facts.hash, facts.errors), closure)', 'Fail(_) => row(Fail, failing_modules(facts.hash, facts.errors), "")', 'l0:facts')
m('n3', 'R-P3', FA, 'Hang => row(Hang, [], closure)', 'Hang => row(Hang, [], "")', 'l0:facts')
m('n4', 'R-P3', FA, 'Crash(_) => row(Crash, [], closure)', 'Crash(_) => row(Crash, [], "")', 'l0:facts')
m('n5', 'R-P4', DB, '\t|> then_by(Text.compare(a.closure, b.closure))\n', '', 'l0:db')
m('n6', 'R-P4', RD, 'PRIMARY KEY (hash, nightly, target, closure)) WITHOUT ROWID', 'PRIMARY KEY (hash, nightly, target)) WITHOUT ROWID', 'l3f:update/bs1')
m('n7', 'R-P4', RD, 'ON CONFLICT(hash, nightly, target, closure) DO UPDATE', 'ON CONFLICT(hash, nightly, target) DO UPDATE', 'l3f:update/bs1')
m('n8', 'R-P4', RD, 'DO UPDATE SET outcome = excluded.outcome, modules = excluded.modules"', 'DO UPDATE SET modules = excluded.modules"', 'l3f:update/bs1')

ENV = dict(os.environ)
def sh(cmd, timeout=900):
    try:
        p = subprocess.run(cmd, shell=True, capture_output=True, text=True, env=ENV, executable='/bin/bash', timeout=timeout)
        return p.returncode, p.stdout + p.stderr
    except subprocess.TimeoutExpired:
        return 124, 'TIMEOUT'

def run(steps):
    for st in steps.split():
        kind, _, arg = st.partition(':')
        if kind == 'l0':
            rc, log = sh('. scripts/env.sh; $ROC test tests/unit/%s.roc --no-cache' % arg)
            if rc != 0:
                if 'failed' not in log and 'FAIL' not in log:
                    return 'INVALID (does not compile)', st
                return 'caught', st + ' ' + next((l.strip() for l in log.splitlines() if 'failed' in l or 'FAIL' in l), '')[:90]
        elif kind == 'l2':
            rc, log = sh('. scripts/env.sh; $ROC build tests/commands/main.roc --opt=dev --output=$WORK/bin/l2 2>&1 | tail -5; test ${PIPESTATUS[0]} = 0')
            if rc != 0:
                return 'INVALID (does not compile)', 'l2 build'
            rc, log = sh('. scripts/env.sh; L2BIN=$WORK/bin/l2 tests/commands/run.sh')
            if rc != 0:
                return 'caught', 'l2 ' + next((l for l in log.splitlines() if l.startswith('FAIL')), 'timeout' if rc == 124 else '')
        elif kind == 'l3f':
            rc, log = sh('. scripts/env.sh; tests/run.sh %s' % arg)
            if rc != 0:
                if 'FAIL' not in log:
                    return 'INVALID (does not compile)', 'l3 build'
                return 'caught', 'l3 ' + next((l for l in log.splitlines() if l.startswith('FAIL')), '')
    return 'NOT CAUGHT', ''

def restore(path):
    shutil.copyfile(FINAL + path, path)

def main():
    args = sys.argv[1:]
    check = '--check' in args
    want = [a for a in args if a != '--check']
    out = []
    for x in M:
        if want and x['id'] not in want:
            continue
        path = x['file']
        restore(path)
        text = open(path).read()
        if text.count(x['old']) != 1:
            out.append((x['id'], x['rule'], 'BAD MUTATION (%d matches)' % text.count(x['old']), ''))
            print(out[-1], flush=True)
            continue
        if check:
            continue
        open(path, 'w').write(text.replace(x['old'], x['new']))
        try:
            res, why = run(x['steps'])
        finally:
            restore(path)
        out.append((x['id'], x['rule'], res, why))
        print(out[-1], flush=True)
    if check:
        print('checked', len(M), 'bad', len(out))
        return
    sh('. scripts/env.sh; $ROC build tests/commands/main.roc --opt=dev --output=$WORK/bin/l2')
    with open('research/slice-032-revert/agent-results%s.md' % ('-part' if want else ''), 'w') as f:
        f.write('| id | rule | result | first failing line |\n| --- | --- | --- | --- |\n')
        for r in out:
            f.write('| %s | %s | %s | %s |\n' % r)
main()
