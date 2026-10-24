#!/usr/bin/env python3
# Slice 031 revert check of the code agent (TW12): one small change at a time in the final code, run the steps that can see it, write the result.
# The final code is in code-final/ (a copy made before the first mutation). The file of a mutation is restored from there before and after each run.
# Usage: agent-mutate.py [id ...]   (no id: all). One step at a time (one scripts/test.sh at a time). Each step has a timeout.
import os, subprocess, sys, shutil
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
os.chdir(ROOT)
FINAL = 'research/slice-031-revert/code-final/'
L = 'cli/lib/'
M = []
STEPS = {'Probe.roc': 'l0:probe', 'Opts.roc': 'l0:opts', 'Intent.roc': 'l0:intent', 'ResolveBase.roc': 'l2', 'Units.roc': 'l0:units', 'Uses.roc': 'l0:uses', 'Ladder.roc': 'l2', 'UnitFlow.roc': 'l2', 'RealJobs.roc': 'l3f:fx/pl1-probe-pool', 'RemoveFlow.roc': 'l2', 'VerifyFlow.roc': 'l2'}
def m(id, rule, file, old, new, steps=None):
    steps = steps or STEPS[os.path.basename(file)]
    M.append(dict(id=id, rule=rule, file=file, old=old, new=new, steps=steps))

# Probe.roc
m('p1', 'R-PP6', L+'Probe.roc', 'Build(_) => 4', 'Build(_) => 1')
m('p2', 'R-LY4', L+'Probe.roc', 'pick(layers.flag_slots, layers.project.slots, layers.user.slots)', 'pick(Err(Unset), layers.project.slots, layers.user.slots)')
m('p3', 'R-LY4', L+'Probe.roc', 'pick(Err(Unset), layers.project.timeout, layers.user.timeout) ?? 30', 'pick(Err(Unset), layers.user.timeout, layers.project.timeout) ?? 30')
m('p4', 'R-PP7', L+'Probe.roc', 'layers.user.slots) ?? 12', 'layers.user.slots) ?? 8')
# Opts.roc
m('o1', 'R-FL11', L+'Opts.roc', 'Ok(n) if n >= 1 =>', 'Ok(n) if n >= 0 =>')
m('o2', 'R-FL11', L+'Opts.roc', 'value_of(args, "--slots")', 'value_of(args, "--slot")')
# Intent.roc
m('i1', 'R-P5', L+'Intent.roc', 'one("timeout", 1)', 'one("timeout", 0)')
m('i2', 'R-P5', L+'Intent.roc', 'one("max", 0)', 'one("max", 1)')
m('i3', 'R-TF4', L+'Intent.roc', 'keep_if(|key| !probe_keys.contains(key))', 'keep_if(|key| probe_keys.contains(key))')
m('i4', 'R-LY4', L+'Intent.roc', 'read_probe(doc, ["probe"], "probe")', 'read_probe(doc, ["probes"], "probe")')
m('i5', 'R-P5', L+'Intent.roc', 'Value.Integer(n) if n >= 0 =>', 'Value.Integer(n) if n >= -5 =>')
# ResolveBase.roc
m('r1', 'R-LY4', L+'ResolveBase.roc', 'user: loaded.config.probe })', 'user: loaded.intent.resolution.probe })')
m('r2', 'R-FL11', L+'ResolveBase.roc', 'flag_slots: request.probe.slots,', 'flag_slots: request.probe.slots.map_ok(|_n| 12),')
# Units.roc
m('u1', 'R-LD2', L+'Units.roc', 'if found.any(|seen| seen.hash == node.hash) found else found.append(node)', 'found.append(node)')
m('u2', 'R-P4', L+'Units.roc', 'nightly: facts.nightly, target: "any" })', 'nightly: facts.nightly, target: "host" })')
m('u3', 'R-AL4', L+'Units.roc', 'fact.hash == node.hash and fact.nightly == nightly and fact.target == "any"', 'fact.hash == node.hash and fact.target == "any"')
m('u4', 'R-PP3', L+'Units.roc', 'dir: Text.join(facts.pkgs, node.hash),\n', 'dir: facts.pkgs,\n')
m('u15', 'R-P4', L+'Units.roc', 'dir: Text.join(facts.pkgs, node.hash), pkgs: facts.pkgs', 'dir: facts.pkgs, pkgs: facts.pkgs')
m('u5', 'R-P5', L+'Units.roc', 'if left < facts.fixed {', 'if left <= facts.fixed {')
m('u6', 'R-P5', L+'Units.roc', 'room = left - facts.fixed', 'room = left')
m('u7', 'R-PP4', L+'Units.roc', 'if facts.wanted <= room Ok', 'if facts.wanted < room Ok')
m('u8', 'R-P3', L+'Units.roc', 'Ok((node, NoFact(text), _)) =>', 'Ok((node, Hang, _)) =>')
m('u9', 'R-UM1', L+'Units.roc', 'path == "main.roc" or facts.used.contains', 'path != "main.roc" or facts.used.contains')
m('u10', 'R-P6', L+'Units.roc', '!baseline.any(|err| err.file == Package({ hash: node.hash, path }))', 'Bool.True')
m('u11', 'R-EP7', L+'Units.roc', 'Hang => Ok("${label(node)} (hangs)")', 'Hang => Err(None)')
m('u12', 'R-LD3', L+'Units.roc', 'if node.is_platform "the platform ${node.name} ${node.version}"', 'if !node.is_platform "the platform ${node.name} ${node.version}"')
m('u13', 'R-P2', L+'Units.roc', 'Pass => Err(None)\n\t\tHang', 'Pass => Ok("${label(node)} (no module is named)")\n\t\tHang')
m('u14', 'R-P5', L+'Units.roc', '1 => "${base} and 1 unit check', '1 => "${base} and 1 unit checks')
# Uses.roc
m('s1', 'R-UM1', L+'Uses.roc', 'Err(Header) => Ok(App)', 'Err(Header) => Err(NoHash)')
m('s2', 'R-LD7', L+'Uses.roc', 'Package(hash) => if file.starts_with("${root}/") Ok', 'Package(hash) => if !file.starts_with("${root}/") Ok')
m('s3', 'R-UM1', L+'Uses.roc', 'known = seen.contains(event.next.path) or acc.next.any(|todo| todo.path == event.next.path)', 'known = seen.contains(event.next.path)')
m('s4', 'R-UM1', L+'Uses.roc', 'edge.from == source.owner and edge.alias == alias', 'edge.alias == alias')
# UnitFlow.roc
m('f1', 'R-LF2', L+'UnitFlow.roc', 'wanted = if ctx.no_probe [] else', 'wanted = if !ctx.no_probe [] else')
m('f2', 'R-PP4', L+'UnitFlow.roc', 'fixed: 1, wanted: wanted.len()', 'fixed: 0, wanted: wanted.len()')
m('f3', 'R-PP3', L+'UnitFlow.roc', 'outputs: outputs.drop_first(1), nightly', 'outputs: outputs.drop_last(1), nightly')
m('f4', 'R-PP4', L+'UnitFlow.roc', 'existing: Replace })', 'existing: Keep })')
m('f5', 'R-P5', L+'UnitFlow.roc', 'if run.first.left > 0 {', 'if run.first.left > 100 {')
m('f6', 'R-UM1', L+'UnitFlow.roc', 'used = if suspects.is_empty() [] else UnitFlow.scan!(fx, ctx)', 'used = if suspects.is_empty() [] else UnitFlow.scan!(fx, ctx).take_first(0)')
m('f7', 'R-P3', L+'UnitFlow.roc', 'Ok(fail) => return Err(fail)\n\t\t\tErr(None) => {}', 'Ok(_) => {}\n\t\t\tErr(None) => {}')
m('f8', 'R-P5', L+'UnitFlow.roc', 'Units.budget({ max: ctx.probe.max, started: run.count, fixed: 1, wanted: 0 })', 'Units.budget({ max: ctx.probe.max, started: 0, fixed: 1, wanted: 0 })')
m('f9', 'R-PP4', L+'UnitFlow.roc', 'count: run.count + 1 + nodes.len(),', 'count: run.count + 1,')
m('f10', 'R-LD7', L+'UnitFlow.roc', 'roots.keep_if(|path| path != file).map(|path| { owner: App, path })', 'roots.keep_if(|path| path == file).map(|path| { owner: App, path })')
m('f11', 'R-UM1', L+'UnitFlow.roc', '$used = level.used.fold($used, |found, row| if found.contains(row) found else found.append(row))', '$used = level.used')
# Ladder.roc
m('l1', 'R-EF1', L+'Ladder.roc', 'Units.nodes(closures.map(|c| c.walked)), nightly })', 'Units.nodes(closures.take_first(1).map(|c| c.walked)), nightly })')
m('l2', 'R-AL4', L+'Ladder.roc', 'ran = probe_member!(fx, request, { started, base: started, facts: $facts, count: $count }, member)?\n\t\t\t$facts = ran.facts', 'ran = probe_member!(fx, request, { started, base: started, facts: $facts, count: $count }, member)?\n\t\t\t$facts = $facts')
m('l3', 'R-P5', L+'Ladder.roc', 'ran = probe_member!(fx, request, { started, base: started, facts: $facts, count: $count }, member)?\n\t\t\t$facts = ran.facts\n\t\t\t$count = ran.probes', 'ran = probe_member!(fx, request, { started, base: started, facts: $facts, count: $count }, member)?\n\t\t\t$facts = ran.facts\n\t\t\t$count = 0')
m('l4', 'R-UM1', L+'Ladder.roc', 'UnitFlow.verdict!(fx, ctx, { first: round, baseline })?\n\tsecond = UnitFlow.step!(fx, ctx, { spec: candidate_spec, count: round.count })?\n\tchecked = Ladder.check({ output: second.output, dir: copy', 'second = UnitFlow.step!(fx, ctx, { spec: candidate_spec, count: round.count })?\n\tchecked = Ladder.check({ output: second.output, dir: copy')
m('l5', 'R-LD2', L+'Ladder.roc', 'nodes: Units.nodes([walked]), facts: pair.facts }', 'nodes: [], facts: pair.facts }')
m('l6', 'R-P5', L+'Ladder.roc', 'timeout = request.probe.timeout\n\tcandidate_plan', 'timeout = 30\n\tcandidate_plan')
m('l7', 'R-LD2', L+'Ladder.roc', 'ran = verify_member!(fx, request, { started, facts: $facts, count: $count }, member)?\n\t\t\t$facts = ran.facts', 'ran = verify_member!(fx, request, { started, facts: $facts.take_first(0), count: $count }, member)?\n\t\t\t$facts = ran.facts')
m('l8', 'R-PP2', L+'Ladder.roc', 'round = UnitFlow.first!(fx, ctx, { baseline: first_spec, count: pair.count })?', 'round = UnitFlow.first!(fx, { ..ctx, no_probe: Bool.True }, { baseline: first_spec, count: pair.count })?')
m('l9', 'R-CM11', L+'Ladder.roc', 'round = UnitFlow.first!(fx, ctx, { baseline: baseline_spec, count: state.count })?', 'round = UnitFlow.first!(fx, { ..ctx, no_probe: Bool.True }, { baseline: baseline_spec, count: state.count })?')
# RealJobs.roc (L3)
m('j1', 'R-PP6', 'cli/RealJobs.roc', 'if $used + need > pool {', 'if $used + need > pool + 1 {')
m('j2', 'R-PP6', 'cli/RealJobs.roc', 'else if spec.weight > pool pool else', 'else if spec.weight > pool * 100 pool else')
m('j3', 'R-PP6', 'cli/RealJobs.roc', 'pool = if round.pool == 0 1 else round.pool', 'pool = 12')
m('j4', 'R-PP5', 'cli/RealJobs.roc', 'Ok(_) => if now >= entry.deadline {', 'Ok(_) => if now >= entry.deadline + 100000000000000 {')
m('j5', 'R-PP3', 'cli/RealJobs.roc', '$waiting = Bool.True\n\t\t\t\t\t\t} else {', '$next = $next + 1\n\t\t\t\t\t\t} else {')
m('j6', 'R-PP5', 'cli/RealJobs.roc', 'Ok([out]) => {\n\t\t\t\t\t\tentry.child.close!() |> ignore\n\t\t\t\t\t\t$used = $used - entry.need\n\t\t\t\t\t\t$done = $done.append((entry.index, probe_output(out)))', 'Ok([out]) => {\n\t\t\t\t\t\tentry.child.close!() |> ignore\n\t\t\t\t\t\t$done = $done.append((entry.index, probe_output(out)))')
# RemoveFlow.roc
m('m1', 'R-LD2', L+'RemoveFlow.roc', 'keep_if(|e| !facts.aliases.contains(e.alias))', 'keep_if(|e| facts.aliases.contains(e.alias))')
m('m2', 'R-LD2', L+'RemoveFlow.roc', 'no_probe: request.probe.no_probe, closures },', 'no_probe: request.probe.no_probe, closures: closures.take_first(0) },')
m('m3', 'R-LF3', L+'RemoveFlow.roc', 'no_probe: request.probe.no_probe, closures },', 'no_probe: Bool.False, closures },')
# the failure text of a unit probe with no fact
m('f12', 'R-PP4', L+'UnitFlow.roc', 'Ok(fail) => return Err(fail)', 'Ok(fail) => return Err(Fail.new(fail.kind, "x"))')

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
    want = sys.argv[1:]
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
        open(path, 'w').write(text.replace(x['old'], x['new']))
        try:
            res, why = run(x['steps'])
        finally:
            restore(path)
        out.append((x['id'], x['rule'], res, why))
        print(out[-1], flush=True)
    sh('. scripts/env.sh; $ROC build tests/commands/main.roc --opt=dev --output=$WORK/bin/l2')
    with open('research/slice-031-revert/agent-results%s.md' % ('-part' if want else ''), 'w') as f:
        f.write('| id | rule | result | first failing line |\n| --- | --- | --- | --- |\n')
        for r in out:
            f.write('| %s | %s | %s | %s |\n' % r)
main()
