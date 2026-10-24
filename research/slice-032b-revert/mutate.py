#!/usr/bin/env python3
# Slice 032b revert check (TW12): one small change at a time in the private reference, run the steps that can see it, write the result.
# Usage: mutate.py [--check] [id ...]   (no id: all). Run with the reference in the tree (swap.sh ref). One step at a time (one test run at a time).
import os, subprocess, sys, shutil
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
os.chdir(ROOT)
REF = 'research/slice-032b-revert/reference/'
L = 'cli/lib/'
EV, EF, WH, LD, UF, RS = L+'Evidence.roc', L+'EvidenceFlow.roc', L+'Why.roc', L+'Ladder.roc', L+'UnitFlow.roc', L+'ResolveSelect.roc'
M = []
def m(id, rule, file, old, new, steps):
    M.append(dict(id=id, rule=rule, file=file, old=old, new=new, steps=steps))
L0 = 'l0:evidence'
# Evidence (pure): of_pair
m('e1', 'R-EF1', EV, 'row.nightly == facts.compiler and row.target == "any") {', 'row.target == "any") {', L0)
m('e2', 'R-EF1', EV, 'row.hash == facts.hash and row.nightly == facts.compiler', 'row.nightly == facts.compiler', L0)
m('e3', 'R-EF1', EV, 'row.nightly == facts.compiler and row.target == "any"', 'row.nightly == facts.compiler', L0)
m('e4', 'R-EF1', EV, 'Pin.same_id(id, facts.compiler) [{ rank: 3', 'id == facts.compiler [{ rank: 3', L0)
m('e5', 'R-EF1', EV, 'if Pin.same_id(id, facts.compiler) [{ rank: 3', 'if Bool.True [{ rank: 3', L0)
m('e6', 'R-EF1', EV, 'Pin.same_id(id, facts.compiler) [{ rank: 4', 'id == facts.compiler [{ rank: 4', L0)
m('e7', 'R-EF1', EV, 'if Pin.same_id(id, facts.compiler) [{ rank: 4', 'if Bool.True [{ rank: 4', L0)
m('e8', 'R-EF3', EV, 'local.concat(pin).concat(hint)', 'pin.concat(local).concat(hint)', L0)
m('e9', 'R-EF3', EV, 'local.concat(pin).concat(hint)', 'local.concat(hint).concat(pin)', L0)
m('e10', 'R-EF1', EV, 'result: row.outcome, modules: row.modules }]', 'result: Pass, modules: row.modules }]', L0)
m('e11', 'R-EF1', EV, 'result: row.outcome, modules: row.modules }]', 'result: row.outcome, modules: [] }]', L0)
m('e12', 'R-EF1', EV, 'Ok(locked) => locked.roc', 'Ok(_) => Err(NoPin)', L0)
# text
m('e13', 'R-EF3', EV, 'if i == 0 "*" else " "', '"*"', L0)
m('e14', 'R-CM7', EV, 'header = "    evidence on ${compiler}:\\n"', 'header = "    evidence ${compiler}:\\n"', L0)
m('e15', 'R-CM7', EV, 'Err(None) => ""', 'Err(None) => "    evidence on none:\\n"', L0)
m('e16', 'R-UM1', EV, '"    note: ${n}\\n"', '"note: ${n}\\n"', L0)
m('e17', 'R-CM7', EV, 'Str.join_with(line.modules, ", ")', 'Str.join_with(line.modules, ",")', L0)
m('e18', 'R-CM7', EV, 'if line.modules.is_empty() "fail" else', 'if line.modules.is_empty() "fail ()" else', L0)
m('e19', 'R-EF1', EV, 'Hint => "roc-version"', 'Hint => "hint"', L0)
m('e20', 'R-OUT4', EV, '("winner", Flag(i == 0))', '("winner", Flag(Bool.True))', L0)
m('e21', 'R-OUT4', EV, 'Err(None) => Null', 'Err(None) => Text("")', L0)
m('e22', 'R-OUT4', EV, '("notes", Arr(block.notes.map(|n| Text(n)))),', '("notes", Arr([])),', L0)
m('e23', 'R-OUT4', EV, '("rank", Num(line.rank.to_i64_wrap())),', '("rank", Num(1)),', L0)
# ignored, note
m('e24', 'R-UM1', EV, 'path != "main.roc" and ', '', L0)
m('e25', 'R-UM1', EV, '!facts.used.contains({ hash, path }) and ', '', L0)
m('e26', 'R-UM1', EV, ' and !facts.baseline.any(|err| err.file == Package({ hash, path }))', '', L0)
m('e27', 'R-UM1', EV, 'Ok(row) => if row.outcome == Fail {', 'Ok(row) => if row.outcome != Pass {', L0)
m('e28', 'R-UM1', EV, 'row.nightly == facts.nightly and row.target == "any"', 'row.nightly == facts.nightly', L0)
m('e29', 'R-UM1', EV, 'row.hash == hash and row.nightly == facts.nightly', 'row.hash == hash', L0)
m('e30', 'R-UM1', EV, 'path.drop_suffix(".roc")', 'path', L0)
m('e31', 'R-UM1', EV, 'Your app does not import it."', 'Your app does not use it."', L0)
# Why
m('w1', 'R-CM7', WH, '"${Why.text(shown.found)}${Evidence.text(shown.evidence)}"', '"${Why.text(shown.found)}"', L0)
m('w2', 'R-OUT4', WH, 'member_pairs(shown.found).concat(Evidence.fields(shown.evidence))', 'member_pairs(shown.found)', L0)
m('w3', 'R-OUT4', WH, 'member_pairs(shown.found).concat(Evidence.fields(shown.evidence))', 'Evidence.fields(shown.evidence).concat(member_pairs(shown.found))', L0)
m('w4', 'R-CM7', WH, 'Ok(blocks) => {', 'Ok(_) => {', 'l2')  # placeholder (see w4 below)
M.pop()
m('w4', 'R-CM7', WH, 'shown = found.map2(blocks, |f, evidence| { found: f, evidence })', 'shown = found.map2(blocks, |f, _| { found: f, evidence: { compiler: Err(None), lines: [], notes: [] } })', 'l2')
# EvidenceFlow (L2 ev1, ev2, ev3 and the old cases)
m('f1', 'R-SO20', EF, '(Ok(text), _) => Ok(text)\n\t\t\t\t\t(_, Ok(text)) => Ok(text)', '(_, Ok(text)) => Ok(text)\n\t\t\t\t\t(Ok(text), _) => Ok(text)', 'l2')
m('f2', 'R-SO2', EF, '\t\t\t\t\t(_, Ok(text)) => Ok(text)\n', '', 'l2')
m('f3', 'R-SO7', EF, 'ResolveSelect.peek!(fx, { ..request, compiler: path }, ctx.loaded)', 'match path {\n\t\t\t\t\t\t\tOk(_) => Err(None)\n\t\t\t\t\t\t\tErr(_) => Err(None)\n\t\t\t\t\t\t}', 'l2')
m('f4', 'R-EF1', EF, 'Ok((_, Ok(text))) => Evidence.pin_of({ path, text })', 'Ok((_, Ok(_))) => Err(NoPin)', 'l2')
m('f5', 'R-EF1', EF, 'nightly: w.compiler, target: "any" }', 'nightly: w.compiler, target: "x" }', 'l2')
m('f4b', 'R-EF1', EF, 'Ok((_, Ok(text))) => Evidence.pin_of({ path, text })', 'Ok((_, Ok(_))) => Err(NoPin)', 'l3f:why/wy2-evidence')
m('f5b', 'R-EF1', EF, 'nightly: w.compiler, target: "any" }', 'nightly: w.compiler, target: "x" }', 'l3f:why/wy2-evidence')
m('f6', 'E3', EF, 'hint: Err(None) })', 'hint: Ok(w.compiler) })', 'l2')
m('f7', 'E5', EF, 'failing = block.lines.any(|line| line.source == Local and line.result == Fail and !line.modules.is_empty())', 'failing = Bool.True', 'l2')
m('f8', 'E5', EF, 'failing = block.lines.any(|line| line.source == Local and line.result == Fail and !line.modules.is_empty())', 'failing = block.lines.any(|line| line.source == Local and line.result == Fail)', 'l2')
m('f9', 'E2', EF, 'facts = Facts.load!(fx, { roots: request.roots, keys })?', 'facts = Facts.load!(fx, { roots: request.roots, keys: keys.take_first(0) })?', 'l2')
m('f10', 'R-UM1', EF, 'walked: one.walked })', 'walked: { rows: [], links: [] } })', 'l2')
m('f11', 'R-UM1', EF, 'member: { file: one.file, kind, text }', 'member: { file: one.file, kind, text: text.drop_prefix(text) }', 'l2')
m('f12', 'R-UM1', EF, 'Evidence.ignored({ hashes: [hash], facts, nightly: compiler, baseline: [], used })', 'Evidence.ignored({ hashes: [hash], facts, nightly: compiler, baseline: [], used: used.take_first(0) })', 'l2')
m('f13', 'E1', EF, 'Err(_) => Err(None)\n\t\t}\n\t\thash_of', 'Err(_) => Ok("nightly-2026-10-14-38a3029")\n\t\t}\n\t\thash_of', 'l2')
m('f15', 'R-H4', EF, 'Ok(ident) => if row.kind == Release Ok(ident.hash) else Err(NoHash)', 'Ok(ident) => Ok(ident.hash)', 'l2')
# Ladder, UnitFlow, ResolveSelect
m('l1', 'E5', LD, 'Err(None) => Ok({ lines: checked.lines.concat(notes), probes: second.count, facts: round.facts, skipped: 0 })\n\t\tOk(spec) => {\n\t\t\tthird = build_round!(fx, ctx, { spec, count: second.count, used: verdict.used, dir: copy', 'Err(None) => Ok({ lines: checked.lines, probes: second.count, facts: round.facts, skipped: 0 })\n\t\tOk(spec) => {\n\t\t\tthird = build_round!(fx, ctx, { spec, count: second.count, used: verdict.used, dir: copy', 'l2')
m('l2', 'E5', LD, 'Err(None) => Ok({ lines: checked.lines.concat(notes), probes: second.count, facts: round.facts, skipped: 0 })\n\t\tOk(spec) => {\n\t\t\tthird = build_round!(fx, ctx, { spec, count: second.count, used: verdict.used, dir, baseline', 'Err(None) => Ok({ lines: checked.lines, probes: second.count, facts: round.facts, skipped: 0 })\n\t\tOk(spec) => {\n\t\t\tthird = build_round!(fx, ctx, { spec, count: second.count, used: verdict.used, dir, baseline', 'l2')
C = 'third = build_round!(fx, ctx, { spec, count: second.count, used: verdict.used, dir: copy, baseline, owners: request.owners })?\n\t\t\tOk({ lines: checked.lines.concat(third.lines).concat(notes)'
P = 'third = build_round!(fx, ctx, { spec, count: second.count, used: verdict.used, dir, baseline, owners: request.owners })?\n\t\t\tOk({ lines: checked.lines.concat(third.lines).concat(notes)'
m('l3', 'E5', LD, C, C.replace('.concat(notes)', ''), 'l2')
m('l4', 'E5', LD, P, P.replace('.concat(notes)', ''), 'l2')
m('l6', 'E5', LD, C, C.replace('checked.lines.concat(third.lines).concat(notes)', 'checked.lines.concat(notes).concat(third.lines)'), 'l2')
m('l7', 'E5', LD, P, P.replace('checked.lines.concat(third.lines).concat(notes)', 'checked.lines.concat(notes).concat(third.lines)'), 'l2')
m('l5', 'E4', LD, 'ignored.map(|one| "note: ${Evidence.note({ path: one.path, compiler })}")', 'ignored.map(|one| "${Evidence.note({ path: one.path, compiler })}")', 'l2')
m('u1', 'R-UM1', UF, 'Ok(used) => Evidence.ignored({ hashes: ctx.nodes.map(|node| node.hash), facts: run.first.facts, nightly: ctx.started.id, baseline: run.baseline, used })', 'Ok(_) => []', 'l2')
m('u2', 'R-P6', UF, 'nightly: ctx.started.id, baseline: run.baseline, used })', 'nightly: ctx.started.id, baseline: [], used })', 'l2')
m('u3', 'R-UM1', UF, 'hashes: ctx.nodes.map(|node| node.hash), facts: run.first.facts', 'hashes: ctx.nodes.map(|node| node.hash), facts: ctx.facts', 'l2')
m('s1', 'E1', RS, 'Ok(sel) => Ok(sel.id)\n\t\tErr(_) => Err(None)', 'Ok(sel) => Ok(sel.id)\n\t\tErr(_) => Ok("x")', 'l2')
m('s2', 'R-SO7', RS, 'default, path: request.compiler.map_ok(|found| found.id), installed, times })\n}', 'default, path: Err(NoCompiler), installed, times })\n}', 'l2')

ENV = dict(os.environ)
def sh(cmd, timeout=600):
    p = subprocess.run(cmd, shell=True, capture_output=True, text=True, env=ENV, executable='/bin/bash', timeout=timeout)
    return p.returncode, p.stdout + p.stderr

def run(steps):
    for st in steps.split():
        kind, _, arg = st.partition(':')
        if kind == 'l0':
            rc, log = sh('. scripts/env.sh; $ROC test tests/unit/%s.roc --no-cache' % arg)
            if rc != 0:
                if 'failed' not in log and 'FAIL' not in log:
                    return 'INVALID (does not compile)', st
                return 'caught', st + ' ' + next((l.strip() for l in log.splitlines() if 'failed' in l), '')[:90]
        elif kind == 'l2':
            rc, log = sh('. scripts/env.sh; $ROC build tests/commands/main.roc --opt=dev --output=$WORK/bin/l2 2>&1 | tail -5; test ${PIPESTATUS[0]} = 0')
            if rc != 0:
                return 'INVALID (does not compile)', 'l2 build'
            rc, log = sh('. scripts/env.sh; L2BIN=$WORK/bin/l2 tests/commands/run.sh')
            if rc != 0:
                return 'caught', 'l2 ' + ', '.join(l[5:] for l in log.splitlines() if l.startswith('FAIL'))[:120]
        elif kind == 'l3f':
            rc, log = sh('. scripts/env.sh; tests/run.sh %s' % arg)
            if rc != 0:
                if 'FAIL' not in log:
                    return 'INVALID (does not compile)', 'l3 build'
                return 'caught', 'l3 ' + next((l for l in log.splitlines() if l.startswith('FAIL')), '')
    return 'NOT CAUGHT', ''

def restore(path):
    shutil.copyfile(REF + path, path)

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
    with open('research/slice-032b-revert/results%s.md' % ('-part' if want else ''), 'w') as f:
        f.write('| id | rule | result | first failing line |\n| --- | --- | --- | --- |\n')
        for r in out:
            f.write('| %s | %s | %s | %s |\n' % r)
main()
