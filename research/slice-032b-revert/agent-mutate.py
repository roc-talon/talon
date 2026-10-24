#!/usr/bin/env python3
# Slice 032b revert check of the code (TW12), by the code agent. One small change at a time in cli/lib, then the steps that can see it.
# The 7 changed files are copied back from code-final/ before each mutation and after it, so a kill is safe.
# Usage: python3 -I research/slice-032b-revert/agent-mutate.py [id ...]   (from the repo root; one run at a time)
# Output: research/slice-032b-revert/agent-results.md (a full run) or agent-results-part.md (some ids).
import os, subprocess, shutil, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
os.chdir(ROOT)
FINAL = 'research/slice-032b-revert/code-final/'
L = 'cli/lib/'
FILES = [L + n + '.roc' for n in ['Evidence', 'EvidenceFlow', 'Why', 'Ladder', 'UnitFlow', 'ResolveSelect', 'Ls']]
EV, EF, WH, LD, UF, RS = (L + n + '.roc' for n in ['Evidence', 'EvidenceFlow', 'Why', 'Ladder', 'UnitFlow', 'ResolveSelect'])
M = []


def m(id, rule, file, old, new, steps):
    M.append(dict(id=id, rule=rule, file=file, old=old, new=new, steps=steps))


L0 = 'l0:evidence'
# Evidence, pure part (L0 evidence)
m('e1', 'R-EF1', EV, 'f.hash == pair.hash and f.nightly == pair.compiler and f.target == "any")', 'f.hash == pair.hash and f.target == "any")', L0)
m('e2', 'R-EF1', EV, 'f.hash == pair.hash and f.nightly == pair.compiler', 'f.nightly == pair.compiler', L0)
m('e3', 'R-EF1', EV, 'f.nightly == pair.compiler and f.target == "any")', 'f.nightly == pair.compiler)', L0)
m('e4', 'R-EF3', EV, 'local.concat(hint(3, Pin, pair.pin)).concat(hint(4, Hint, pair.hint))', 'local.concat(hint(4, Hint, pair.hint)).concat(hint(3, Pin, pair.pin))', L0)
m('e6', 'R-EF1', EV, 'Ok(id) => Pin.same_id(id, compiler)', 'Ok(id) => id == compiler', L0)
m('e8', 'R-EF1', EV, '.map(|f| { rank: 1, source: Local, result: f.outcome, modules: f.modules })', '.map(|f| { rank: 1, source: Local, result: Pass, modules: f.modules })', L0)
m('e9', 'R-EF1', EV, '.map(|f| { rank: 1, source: Local, result: f.outcome, modules: f.modules })', '.map(|f| { rank: 1, source: Local, result: f.outcome, modules: [] })', L0)
m('e10', 'R-EF1', EV, 'Ok(locked) => locked.roc', 'Ok(_) => Err(NoPin)', L0)
m('e11', 'R-EF3', EV, 'block.lines.take_first(1).map(|l| line_text("*", l))', 'block.lines.take_first(1).map(|l| line_text(" ", l))', L0)
m('e12', 'R-EF3', EV, 'block.lines.drop_first(1).map(|l| line_text(" ", l))', 'block.lines.drop_first(1).map(|l| line_text("*", l))', L0)
m('e13', 'R-CM7', EV, '"    evidence on ${compiler}:\\n${', '"    evidence ${compiler}:\\n${', L0)
m('e14', 'R-UM1', EV, '"    note: ${n}\\n"', '"note: ${n}\\n"', L0)
m('e15', 'R-CM7', EV, '"fail (${Str.join_with(line.modules, ", ")})"', '"fail (${Str.join_with(line.modules, ",")})"', L0)
m('e16', 'R-CM7', EV, 'result_text = |line| if line.result == Fail and !line.modules.is_empty() {', 'result_text = |line| if line.result == Fail {', L0)
m('e18', 'R-OUT4', EV, '("winner", Flag(winner)),', '("winner", Flag(!winner)),', L0)
m('e19', 'R-OUT4', EV, 'Err(None) => Null', 'Err(None) => Text("")', L0)
m('e20', 'R-OUT4', EV, '("notes", Arr(block.notes.map(|n| Text(n)))),', '("notes", Arr([])),', L0)
m('e21', 'R-OUT4', EV, '("rank", Num(line.rank.to_i64_wrap())),', '("rank", Num(1)),', L0)
m('e22', 'R-UM1', EV, 'path != "main.roc" and !run.baseline', '!run.baseline', L0)
m('e23', 'R-UM1', EV, ' and !run.used.contains({ hash, path })', '', L0)
m('e24', 'R-P6', EV, 'and !run.baseline.any(|err| err.file == Package({ hash, path }))', '', L0)
m('e25', 'R-UM1', EV, 'and f.outcome == Fail)', 'and f.outcome != Pass)', L0)
m('e26', 'R-UM1', EV, 'f.nightly == run.nightly and f.target == "any" and f.outcome', 'f.nightly == run.nightly and f.outcome', L0)
m('e28', 'R-UM1', EV, 'path.drop_suffix(".roc") else path', 'path else path', L0)
m('e29', 'R-UM1', EV, 'Your app does not import it."', 'Your app does not use it."', L0)
# Why (L0 evidence 7, L2)
m('w1', 'R-CM7', WH, '"${Why.text(shown.found)}${Evidence.text(shown.evidence)}"', '"${Why.text(shown.found)}"', L0)
m('w2', 'R-OUT4', WH, 'Obj(fields) => Obj(fields.concat(Evidence.fields(shown.evidence)))', 'Obj(fields) => Obj(fields)', L0 + ' l2')
m('w4', 'R-CM7', WH, 'shown = found.map2(blocks, |f, evidence| { found: f, evidence })', 'shown = found.map2(blocks, |f, _| { found: f, evidence: { compiler: Err(None), lines: [], notes: [] } })', 'l2')
m('w5', 'R-TF3', WH, 'Ok(found) => match EvidenceFlow.blocks!(fx, { request: walk.request, loaded: walk.loaded }, found) {\n\t\t\t\t\tErr(fail) => Common.failed!(fx, args, fail)', 'Ok(found) => match EvidenceFlow.blocks!(fx, { request: walk.request, loaded: walk.loaded }, found) {\n\t\t\t\t\tErr(_) => 0', 'l2')
# EvidenceFlow (L2 ev1, ev2, ev3 and the old cases; L3 wy2)
m('f1', 'R-SO20', EF, '(Ok(id), _) => Ok(id)\n\t\t\t(Err(NoPin), Ok(id)) => Ok(id)', '(_, Ok(id)) => Ok(id)\n\t\t\t(Ok(id), Err(Unset)) => Ok(id)', 'l2')
m('f2', 'R-SO2', EF, 'Ok(found) => found\n\t\tErr(_) => Err(Unset)', 'Ok(_) => Err(Unset)\n\t\tErr(_) => Err(Unset)', 'l2')
m('f3', 'R-SO7', EF, 'if !$asked {', 'if Bool.True {', 'l2')
m('f4', 'R-SO7', EF, 'ResolveSelect.peek!(fx, $request, ctx.loaded)', 'ResolveSelect.peek!(fx, ctx.request, ctx.loaded)', 'l2')
m('f5', 'R-EF1', EF, 'Ok(text) => Evidence.pin_of({ path, text })', 'Ok(_) => Err(NoPin)', 'l2 l3f:why/wy2-evidence')
m('f6', 'R-EF1', EF, 'nightly: a.compiler, target: "any" }', 'nightly: a.compiler, target: "x" }', 'l2 l3f:why/wy2-evidence')
m('f7', 'E3', EF, 'hint: Err(None) })', 'hint: Ok(a.compiler) })', 'l2')
m('f8', 'E5', EF, 'l.result == Fail and !l.modules.is_empty()))', 'l.result == Fail))', 'l2')
m('f9', 'E5', EF, 'failing = active.keep_if(|a| lines_of(a).any(|l| l.source == Local and l.result == Fail and !l.modules.is_empty()))', 'failing = active', 'l2')
m('f10', 'E2', EF, 'facts = Facts.load!(fx, { roots: ctx.request.roots, keys })?', 'facts = Facts.load!(fx, { roots: ctx.request.roots, keys: keys.take_first(0) })?', 'l2')
m('f11', 'R-UM1', EF, 'walked = s.walked', 'walked = { rows: [], links: [] }', 'l2')
m('f12', 'R-UM1', EF, 'text: h.text }', 'text: h.text.drop_prefix(h.text) }', 'l2')
m('f13', 'R-UM1', EF, 'baseline: [], used: found })', 'baseline: [], used: found.take_first(0) })', 'l2')
m('f14', 'R-H4', EF, 'hash = if s.target.kind == Release Ident.of_url', 'hash = if Bool.True Ident.of_url', 'l2')
m('f15', 'R-TF3', EF, 'facts = Facts.load!(fx, { roots: ctx.request.roots, keys })?', 'facts = Facts.load!(fx, { roots: ctx.request.roots, keys }) ?? []', 'l2')
# Ladder, UnitFlow, ResolveSelect (L2 ev3, bs2, un1, un3, ev1, ev2, old cases)
C0 = 'Err(None) => Ok({ lines: checked.lines.concat(notes), probes: second.count, facts: round.facts, skipped: 0 })\n\t\tOk(spec) => {\n\t\t\tthird = build_round!(fx, ctx, { spec, count: second.count, used: verdict.used, dir: copy'
P0 = C0.replace('dir: copy', 'dir, baseline')
C0 = C0 + ', baseline'
m('l1', 'E5', LD, C0, C0.replace('checked.lines.concat(notes)', 'checked.lines'), 'l2')
m('l2', 'E5', LD, P0, P0.replace('checked.lines.concat(notes)', 'checked.lines'), 'l2')
C = 'third = build_round!(fx, ctx, { spec, count: second.count, used: verdict.used, dir: copy, baseline, owners: request.owners })?\n\t\t\tOk({ lines: checked.lines.concat(third.lines).concat(notes)'
P = C.replace('dir: copy', 'dir')
m('l3', 'E5', LD, C, C.replace('.concat(notes)', ''), 'l2')
m('l4', 'E5', LD, P, P.replace('.concat(notes)', ''), 'l2')
m('l5', 'E5', LD, C, C.replace('checked.lines.concat(third.lines).concat(notes)', 'checked.lines.concat(notes).concat(third.lines)'), 'l2')
m('l6', 'E5', LD, P, P.replace('checked.lines.concat(third.lines).concat(notes)', 'checked.lines.concat(notes).concat(third.lines)'), 'l2')
m('l7', 'E4', LD, '"note: ${Evidence.note({ path: entry.path, compiler })}"', '"${Evidence.note({ path: entry.path, compiler })}"', 'l2')
L8 = 'notes = note_lines(verdict.ignored, compiler)\n\tsecond = UnitFlow.step!(fx, ctx, { spec: candidate_spec, count: round.count })?\n\tchecked = LadderJudge.check({ output: second.output, dir: copy,'
m('l8', 'E5', LD, L8, L8.replace('verdict.ignored', '[]'), 'l2')
m('u1', 'R-UM1', UF, 'Ok(used) => Evidence.ignored({ hashes: ctx.nodes.map(|node| node.hash), facts: run.first.facts, nightly: ctx.started.id, baseline: run.baseline, used })', 'Ok(_) => []', 'l2')
m('u2', 'R-P6', UF, 'nightly: ctx.started.id, baseline: run.baseline, used })', 'nightly: ctx.started.id, baseline: [], used })', 'l2')
m('u3', 'R-UM1', UF, 'facts: run.first.facts, nightly: ctx.started.id, baseline: run.baseline, used })', 'facts: ctx.facts, nightly: ctx.started.id, baseline: run.baseline, used })', 'l2')
m('u5', 'R-UM1', UF, 'scan! = |fx, ctx| UnitFlow.scan_in!(fx, { roots: ctx.roots, member: ctx.member, walked: ctx.walked })', 'scan! = |fx, ctx| UnitFlow.scan_in!(fx, { roots: ctx.roots, member: ctx.member, walked: { rows: [], links: [] } })', 'l2')
m('s1', 'E1', RS, 'Ok(sel) => Ok(sel.id)\n\t\tErr(_) => Err(None)', 'Ok(sel) => Ok(sel.id)\n\t\tErr(_) => Ok("x")', 'l2')
m('s2', 'R-SO7', RS, 'default, path: request.compiler.map_ok(|found| found.id), installed, times })', 'default, path: Err(NoCompiler), installed, times })', 'l2')

# Second form of the changes that did not compile (an unused variable or a constant condition)
m('f3b', 'R-SO7', EF, '$asked = Bool.True', '$asked = Bool.False', 'l2')
m('f5b', 'R-EF1', EF, 'Ok(text) => Evidence.pin_of({ path, text })', 'Ok(text) => Evidence.pin_of({ path, text: text.drop_prefix(text) })', 'l2 l3f:why/wy2-evidence')
m('f11b', 'R-UM1', EF, 'walked = s.walked', 'walked = { rows: s.walked.rows, links: [] }', 'l2')
m('f14b', 'R-H4', EF, 'hash = if s.target.kind == Release Ident.of_url', 'hash = if s.target.kind != Foreign Ident.of_url', 'l2')
m('u1b', 'R-UM1', UF, 'Ok(used) => Evidence.ignored({ hashes: ctx.nodes.map(|node| node.hash), facts', 'Ok(used) => Evidence.ignored({ hashes: [], facts', 'l2')

ENV = dict(os.environ)
TIMEOUT = 900


def sh(cmd, timeout=TIMEOUT):
    pre = '. scripts/env.sh; . tests/lib.sh; OBJ_KEEP=3 prune_roc_objects; '
    try:
        p = subprocess.run(pre + cmd, shell=True, capture_output=True, text=True, env=ENV, executable='/bin/bash', timeout=timeout)
    except subprocess.TimeoutExpired:
        return 124, 'TIMEOUT'
    return p.returncode, p.stdout + p.stderr


def run(steps):
    for st in steps.split():
        kind, _, arg = st.partition(':')
        if kind == 'l0':
            rc, log = sh('$ROC test tests/unit/%s.roc --no-cache' % arg)
            if rc != 0:
                if rc == 124:
                    return 'caught', st + ' timeout'
                if 'failed' not in log and 'FAIL' not in log:
                    return 'INVALID (does not compile)', st + ' ' + log[:200].replace('\n', ' ')
                return 'caught', st + ' ' + next((l.strip() for l in log.splitlines() if 'failed' in l), '')[:90]
        elif kind == 'l2':
            rc, log = sh('$ROC build tests/commands/main.roc --opt=dev --output=$WORK/bin/l2 2>&1 | tail -15; test ${PIPESTATUS[0]} = 0')
            if rc != 0:
                return 'INVALID (does not compile)', 'l2 build ' + log[:200].replace('\n', ' ')
            rc, log = sh('L2BIN=$WORK/bin/l2 tests/commands/run.sh')
            if rc != 0:
                return 'caught', 'l2 ' + ', '.join(l[5:] for l in log.splitlines() if l.startswith('FAIL'))[:140]
        elif kind == 'l3f':
            rc, log = sh('tests/run.sh %s' % arg)
            if rc != 0:
                if 'FAIL' not in log:
                    return 'INVALID (does not compile)', 'l3 build'
                return 'caught', 'l3 ' + next((l for l in log.splitlines() if l.startswith('FAIL')), '')
    return 'NOT CAUGHT', ''


def restore_all():
    for f in FILES:
        shutil.copyfile(FINAL + f, f)


def main():
    want = [a for a in sys.argv[1:]]
    out = []
    for x in M:
        if want and x['id'] not in want:
            continue
        restore_all()
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
            restore_all()
        out.append((x['id'], x['rule'], res, why))
        print(out[-1], flush=True)
    sh('$ROC build tests/commands/main.roc --opt=dev --output=$WORK/bin/l2')
    name = 'agent-results-part.md' if want else 'agent-results.md'
    with open('research/slice-032b-revert/' + name, 'w') as f:
        f.write('| id | rule | result | first failing line |\n| --- | --- | --- | --- |\n')
        for r in out:
            f.write('| %s | %s | %s | %s |\n' % r)


main()
