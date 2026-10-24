#!/usr/bin/env python3
# Slice 031 revert check (TW12): one change at a time in the private reference, run the steps that can see it, write the result.
# Usage: mutate.py [id ...]   (no id: all)   Run with the reference in the tree (swap.sh ref). Steps run one after the other (one scripts/test.sh at a time).
import os, subprocess, sys, shutil
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
os.chdir(ROOT)
REF = 'research/slice-032-revert/reference/'
L = 'cli/lib/'
M = []
STEPS = {'UnitFlow.roc': 'l2', 'InstallFlow.roc': 'l2', 'BuildSkip.roc': 'l0:buildskip', 'BuildFlow.roc': 'l2', 'Ladder.roc': 'l2', 'Probe.roc': 'l0:probe l0:units', 'Opts.roc': 'l0:opts l3f:update/up2', 'Intent.roc': 'l0:intent', 'ResolveBase.roc': 'l2', 'Units.roc': 'l0:units', 'Uses.roc': 'l0:uses', 'Ladder.roc': 'l2', 'RealJobs.roc': 'l3f:fx/pl1', 'RemoveFlow.roc': 'l2', 'VerifyFlow.roc': 'l2'}
def m(id, rule, file, old, new, steps=None):
    steps = steps or STEPS[os.path.basename(file)]
    M.append(dict(id=id, rule=rule, file=file, old=old, new=new, steps=steps))


S = L+'BuildSkip.roc'
F = L+'BuildFlow.roc'
LD = L+'Ladder.roc'
# BuildSkip (L0 buildskip)
m('b1', 'R-BS2', S, 'Text.sorted_unique(used.map(|u| u.hash))', 'used.map(|u| u.hash).fold([], |kept, h| if kept.contains(h) kept else kept.append(h))')
m('b2', 'R-BS2', S, 'Text.sorted_unique(used.map(|u| u.hash))', 'Text.sorted(used.map(|u| u.hash))')
m('b3', 'R-BS2', S, '"${acc}${hash}\\n")', '"${acc}${hash}")')
m('b4', 'R-BS2', S, 'Text.sorted_unique(used.map(|u| u.hash)).fold("", |acc, hash| "${acc}${hash}\\n")', 'Text.sorted_unique(used.map(|u| "${u.hash}${u.path}")).fold("", |acc, hash| "${acc}${hash}\\n")')
m('b5', 'R-ID6', S, '(Linux, X64) => Ok("x64musl")', '(Linux, X64) => Ok("x64glibc")')
m('b6', 'R-ID6', S, '(Windows, X64) => Ok("x64win")', '(Windows, _) => Ok("x64win")')
m('b7', 'R-ID6', S, 'match nodes.find_first(|node| node.is_platform) {', 'match nodes.find_first(|node| !node.is_platform) {')
m('b8', 'R-ID6', S, 'Ok(name) => Ok({ hash: facts.pf, nightly: facts.nightly, target: name })', 'Ok(name) => Ok({ hash: facts.pf, nightly: "any", target: name })')
m('b9', 'R-BS1', S, 'row.outcome == Pass and row.closure == facts.digest and !row.closure.is_empty()', 'row.outcome == Pass and !row.closure.is_empty()')
m('b10', 'R-BS2', S, 'row.outcome == Pass and row.closure == facts.digest and !row.closure.is_empty()', 'row.closure == facts.digest and !row.closure.is_empty()')
m('b11', 'R-BS1', S, 'row.outcome == Pass and row.closure == facts.digest and !row.closure.is_empty()', 'row.outcome == Pass and row.closure == facts.digest')
m('b12', 'R-ID6', S, 'row.hash == facts.key.hash and row.nightly == facts.key.nightly and row.target == facts.key.target', 'row.hash == facts.key.hash and row.nightly == facts.key.nightly')
m('b13', 'R-ID6', S, 'row.hash == facts.key.hash and row.nightly == facts.key.nightly and row.target == facts.key.target', 'row.hash == facts.key.hash and row.target == facts.key.target')
m('b14', 'R-ID6', S, 'row.hash == facts.key.hash and row.nightly == facts.key.nightly and row.target == facts.key.target', 'row.nightly == facts.key.nightly and row.target == facts.key.target')
m('b15', 'R-P4', S, 'outcome: Pass, modules: [], closure: facts.digest }', 'outcome: Pass, modules: [], closure: "" }')
m('b16', 'R-P4', S, 'outcome: Pass, modules: [], closure: facts.digest }', 'outcome: Fail, modules: [], closure: facts.digest }')
m('b17', 'R-BS2', S, 'skipped_line = "build: skipped (recorded pass)"', 'skipped_line = "build: skipped"')
# BuildFlow and the wiring (L2, L3)
m('f1', 'R-LD7', F, 'match BuildSkip.pf_hash(ctx.nodes) {\n\t\tErr(NoPlatform) => Ok({ skip: Bool.False, id: Err(NoId) })', 'match BuildSkip.pf_hash(ctx.nodes.append({ hash: "x", name: "x", version: "x", is_platform: Bool.True })) {\n\t\tErr(NoPlatform) => Ok({ skip: Bool.False, id: Err(NoId) })')
m('f2', 'R-BS2', F, 'Ok(found) => found\n\t\t\t\t\t\tErr(NotScanned) => UnitFlow.scan!(fx, ctx)', 'Ok(_) => UnitFlow.scan!(fx, ctx)\n\t\t\t\t\t\tErr(NotScanned) => UnitFlow.scan!(fx, ctx)')
m('f3', 'R-BS1', F, 'Facts.load!(fx, { roots: ctx.roots, keys: [key] })?', 'Facts.load!(fx, { roots: ctx.roots, keys: [] })?')
m('f5', 'R-P4', F, 'rows: [BuildSkip.row(found)], existing: Replace', 'rows: [BuildSkip.row(found)], existing: Keep')
m('f7', 'R-ID6', F, 'BuildSkip.key({ pf, nightly: ctx.started.id, system })', 'BuildSkip.key({ pf, nightly: ctx.held, system })') if False else None
m('f11', 'R-OUT4', L+'VerifyFlow.roc', 'build: build_state(checked.keep_if(|m| m.kind == App).len(), done.skipped),', 'build: build_state(checked.keep_if(|m| m.kind == App).len(), 0),')
m('f12', 'R-EF2', F, 'match BuildSkip.pf_hash(ctx.nodes) {', 'match (if ctx.no_probe Err(NoPlatform) else BuildSkip.pf_hash(ctx.nodes)) {')
m('f13', 'R-BS2', L+'UnitFlow.roc', 'Ok({ used: scanned })', 'Ok({ used: Err(NotScanned) })')
m('f14', 'R-BS2', LD, 'BuildFlow.after!(fx, ctx, step.id)?\n\t\t\t\tOk({ lines: checked.lines.concat(built.lines), probes: third.count, facts: round.facts, skipped: 0 })\n\t\t\t}\n\t\t}\n\t}\n}\n\nno_answer', 'BuildFlow.after!(fx, ctx, Err(NoId))?\n\t\t\t\tOk({ lines: checked.lines.concat(built.lines), probes: third.count, facts: round.facts, skipped: 0 })\n\t\t\t}\n\t\t}\n\t}\n}\n\nno_answer')
m('f15', 'R-LD5', LD, 'third = UnitFlow.step!(fx, ctx, { spec, count: second.count })?\n\t\t\t\tbuilt = LadderJudge.build({ output: third.output, dir: copy, pkgs, baseline, owners: request.owners, compiler, timeout })?\n\t\t\t\tBuildFlow.after!(fx, ctx, step.id)?', 'third = UnitFlow.step!(fx, ctx, { spec, count: second.count })?\n\t\t\t\tBuildFlow.after!(fx, ctx, step.id)?\n\t\t\t\tbuilt = LadderJudge.build({ output: third.output, dir: copy, pkgs, baseline, owners: request.owners, compiler, timeout })?')
m('f16', 'R-BS2', L+'InstallFlow.roc', 'build: build_state(members.keep_if(|m| m.kind == App).len(), done.skipped),', 'build: build_state(members.keep_if(|m| m.kind == App).len(), 0),', 'l3f:update/bs1 l2')
m('f17', 'R-BS2', L+'RemoveFlow.roc', 'build: build_state(if member.locked.kind == App 1 else 0, done.skipped),', 'build: build_state(if member.locked.kind == App 1 else 0, 0),', 'l2 l3f:remove/rm1')
m('f18', 'R-ID6', F, 'ctx.started.id', 'ctx.held') if False else None
m('f19', 'R-ID6', F, 'system = fx.platform!()', 'system = { os: Linux, arch: Arm64 }')

m('f4', 'R-BS2', F, 'digest = BuildSkip.digest(used)', 'digest = BuildSkip.digest(used.take_first(0))')
m('f6', 'R-P4', F, 'rows: [BuildSkip.row(found)], existing: Replace', 'rows: [BuildSkip.row(found)].take_first(0), existing: Replace')
SKIP = 'Ok({ lines: checked.lines.append(BuildSkip.skipped_line), probes: second.count, facts: round.facts, skipped: 1 })\n\t\t\t} else {\n\t\t\t\tthird = UnitFlow.step!(fx, ctx, { spec, count: second.count })?\n\t\t\t\tbuilt = LadderJudge.build({ output: third.output, dir'
m('f8a', 'R-PP4', LD, SKIP + ': copy,', SKIP.replace('probes: second.count,', 'probes: second.count + 1,') + ': copy,')
m('f8b', 'R-PP4', LD, SKIP + ', pkgs,', SKIP.replace('probes: second.count,', 'probes: second.count + 1,') + ', pkgs,')
m('f9a', 'R-BS1', LD, 'if step.skip {\n\t\t\t\tOk({ lines: checked.lines.append(BuildSkip.skipped_line), probes: second.count, facts: round.facts, skipped: 1 })\n\t\t\t} else {\n\t\t\t\tthird = UnitFlow.step!(fx, ctx, { spec, count: second.count })?\n\t\t\t\tbuilt = LadderJudge.build({ output: third.output, dir: copy,', 'if step.skip and ctx.no_probe {\n\t\t\t\tOk({ lines: checked.lines.append(BuildSkip.skipped_line), probes: second.count, facts: round.facts, skipped: 1 })\n\t\t\t} else {\n\t\t\t\tthird = UnitFlow.step!(fx, ctx, { spec, count: second.count })?\n\t\t\t\tbuilt = LadderJudge.build({ output: third.output, dir: copy,')
m('f9b', 'R-BS1', LD, 'if step.skip {\n\t\t\t\tOk({ lines: checked.lines.append(BuildSkip.skipped_line), probes: second.count, facts: round.facts, skipped: 1 })\n\t\t\t} else {\n\t\t\t\tthird = UnitFlow.step!(fx, ctx, { spec, count: second.count })?\n\t\t\t\tbuilt = LadderJudge.build({ output: third.output, dir, pkgs,', 'if step.skip and ctx.no_probe {\n\t\t\t\tOk({ lines: checked.lines.append(BuildSkip.skipped_line), probes: second.count, facts: round.facts, skipped: 1 })\n\t\t\t} else {\n\t\t\t\tthird = UnitFlow.step!(fx, ctx, { spec, count: second.count })?\n\t\t\t\tbuilt = LadderJudge.build({ output: third.output, dir, pkgs,')
m('f10a', 'R-BS2', LD, 'Ok({ lines: checked.lines.append(BuildSkip.skipped_line), probes: second.count, facts: round.facts, skipped: 1 })\n\t\t\t} else {\n\t\t\t\tthird = UnitFlow.step!(fx, ctx, { spec, count: second.count })?\n\t\t\t\tbuilt = LadderJudge.build({ output: third.output, dir: copy,', 'Ok({ lines: checked.lines.append("build: passed"), probes: second.count, facts: round.facts, skipped: 1 })\n\t\t\t} else {\n\t\t\t\tthird = UnitFlow.step!(fx, ctx, { spec, count: second.count })?\n\t\t\t\tbuilt = LadderJudge.build({ output: third.output, dir: copy,')
m('f10b', 'R-BS2', LD, 'Ok({ lines: checked.lines.append(BuildSkip.skipped_line), probes: second.count, facts: round.facts, skipped: 1 })\n\t\t\t} else {\n\t\t\t\tthird = UnitFlow.step!(fx, ctx, { spec, count: second.count })?\n\t\t\t\tbuilt = LadderJudge.build({ output: third.output, dir, pkgs,', 'Ok({ lines: checked.lines.append("build: passed"), probes: second.count, facts: round.facts, skipped: 1 })\n\t\t\t} else {\n\t\t\t\tthird = UnitFlow.step!(fx, ctx, { spec, count: second.count })?\n\t\t\t\tbuilt = LadderJudge.build({ output: third.output, dir, pkgs,')
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
        if text.count(x['old']) != 1:
            out.append((x['id'], x['rule'], 'BAD MUTATION (%d matches)' % text.count(x['old']), ''))
            print(out[-1], flush=True)
            continue
        open(path, 'w').write(text.replace(x['old'], x['new']))
        try:
            res, why = run(x['steps'])
        finally:
            shutil.copyfile(REF + path, path)
        out.append((x['id'], x['rule'], res, why))
        print(out[-1], flush=True)
    sh('. scripts/env.sh; $ROC build tests/commands/main.roc --opt=dev --output=$WORK/bin/l2')
    with open('research/slice-032-revert/results-%s.md' % ('part' if want else 'all'), 'w') as f:
        f.write('| id | rule | result | first failing line |\n| --- | --- | --- | --- |\n')
        for r in out:
            f.write('| %s | %s | %s | %s |\n' % r)
main()
