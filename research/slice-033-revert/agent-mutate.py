#!/usr/bin/env python3
# Slice 033 revert check of the code agent (TW12): one small change at a time in the final code, then the compile check, L0 and L1.
# The final code is in code-final/. The file is restored from there before and after each run, so a kill is safe.
# Usage: agent-mutate.py [--check] [id ...]   (no id: all). --check only counts the matches. One step at a time (one build at a time). Each step has a timeout.
import os, subprocess, sys, shutil
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
os.chdir(ROOT)
FINAL = 'research/slice-033-revert/code-final/'
E = 'cli/lib/Epochs.roc'
M = []
def m(id, rule, old, new):
    M.append(dict(id=id, rule=rule, file=E, old=old, new=new))

DOM = '{ from: r.id, to: r.id }'
m('e1', 'R-EP13', DOM, '{ from: r.id, to: "" }')
m('e2', 'R-EP4', 'partition = |domain| domain.map(', 'partition = |domain| domain.rev().map(')
m('e3', 'R-EP11', 'partition = |domain| domain.map(|r| ' + DOM + ')',
  'partition = |domain| domain.keep_if(|r| r.asset.is_ok()).map(|r| ' + DOM + ')')
m('e4', 'R-EP11', 'parts = partition(domain)', 'parts = partition(domain.rev())')
m('e5', 'R-EP10', 'units = run.facts.keep_if(', 'units = run.facts.take_first(8).keep_if(')
m('e6', 'R-EP12', 'f.target == "any"', 'f.target != "zzz"')
m('e7', 'R-EP5', 'Hang => Fault', 'Hang => Done(Pass, [])')
m('e8', 'R-EP5', 'Crash => Fault', 'Crash => Done(Fail, [])')
m('e9', 'R-EP5', 'Hang => Fault', 'Hang => Gap')
m('e10', 'R-EP5', 'Crash => Fault', 'Crash => Gap')
m('e11', 'R-EP5', 'Ok(Gap) => {', 'Ok(Gap) | Ok(Fault) => {')
m('e12', 'R-EP6', 'Fail => Done(Fail, f.modules)', 'Fail => Done(Fail, [])')
m('e13', 'R-EP6', 'ctx.places.keep_if(|p| p < r and is_code(p)).last()', 'ctx.places.keep_if(|p| p < r and is_code(p)).first()')
m('e14', 'R-EP6', 'ctx.places.keep_if(|p| p > r and is_code(p)).first()', 'ctx.places.keep_if(|p| p > r and is_code(p)).last()')
m('e15', 'R-EP6', '(Ok(x), Ok(y)) if x == y => [b, a]', '(Ok(x), Ok(y)) if x != y => [b, a]')
m('e16', 'R-EP6', '(Ok(x), Ok(y)) if x == y => [b, a]', '(Ok(_), Ok(_)) => [b, a]')
m('e17', 'R-EP6', 'is_code(p) and (group(p) == group(r) or between.contains(p))', 'is_code(p) and (group(p) == group(r) + 1000 or between.contains(p))')
m('e18', 'R-EP6', 'is_code(p) and (group(p) == group(r) or between.contains(p))', 'is_code(p) and (group(p) == group(r) or (between.contains(p) and p > 1000))')
m('e19', 'R-EP6', 'is_code(p) and (group(p) == group(r) or between.contains(p))', 'is_code(p) and (group(p) != group(r) or between.contains(p))')
m('e20', 'R-EP6', 'Ok(x) if outcomes.all(|o| o == x) =>', 'Ok(x) if outcomes.len() > 0 =>')
m('e21', 'R-EP6', 'Ok(x) if outcomes.all(|o| o == x) =>', 'Ok(x) if outcomes.all(|o| o == x) or x == Pass =>')
m('e22', 'R-EP6', 'Text.sorted_unique(sources.join_map(|p| modules_at(ctx.cells, p)))', 'sources.take_first(1).join_map(|p| modules_at(ctx.cells, p))')
m('e23', 'R-EP6', 'Text.sorted_unique(sources.join_map(|p| modules_at(ctx.cells, p)))', 'sources.rev().take_first(1).join_map(|p| modules_at(ctx.cells, p))')
m('e24', 'R-EP6', 'Text.sorted_unique(sources.join_map(|p| modules_at(ctx.cells, p)))', 'sources.join_map(|p| modules_at(ctx.cells, p))')
m('e25', 'R-EP6', 'Text.sorted_unique(sources.join_map(|p| modules_at(ctx.cells, p)))', 'Text.sorted(sources.join_map(|p| modules_at(ctx.cells, p)))')
m('e26', 'R-EP14', 'from: sources.keep_oks(', 'from: sources.rev().keep_oks(')
m('e27', 'R-EP14', 'from: sources.keep_oks(|p| ctx.ids.get(p))', 'from: sources.take_first(1).keep_oks(|p| ctx.ids.get(p))')
m('e28', 'R-EP10', 'Text.sorted_unique(units.map(|f| f.hash)).join_map(', 'Text.sorted_unique(units.map(|f| f.hash)).rev().join_map(')
m('e29', 'R-EP10', 'places.keep_oks(|r| infer_at(', 'places.rev().keep_oks(|r| infer_at(')
m('e30', 'R-EP4', '?? (spans.len() + p))', '?? 0)')
m('e31', 'R-EP4', 'id == iv.to)', 'id == iv.from)')
m('e32', 'R-EP4', 'Ok((lo, hi)) => lo <= p and p <= hi', 'Ok((lo, hi)) => lo <= p and p < hi')
m('e33', 'R-EP4', 'Ok((lo, hi)) => lo <= p and p <= hi', 'Ok((lo, hi)) => lo < p and p <= hi')
m('e35', 'R-EP4', '\t_ => Err(NotInD)\n}', '\t(Err(_), Ok(hi)) => Ok((0, hi))\n\t_ => Err(NotInD)\n}')
m('e34', 'R-EP4', '\t_ => Err(NotInD)\n}', '\t(Ok(lo), Err(_)) => Ok((lo, 99))\n\t_ => Err(NotInD)\n}')

def sh(cmd, timeout):
    try:
        p = subprocess.run(cmd, shell=True, capture_output=True, text=True, executable='/bin/bash', timeout=timeout)
        return p.returncode, p.stdout + p.stderr
    except subprocess.TimeoutExpired:
        return 124, 'TIMEOUT'

def run():
    rc, log = sh('. scripts/env.sh; $ROC check cli/lib/main.roc', 300)
    if rc != 0:
        return 'INVALID (does not compile)', log.strip().splitlines()[-1][:90] if log.strip() else ''
    rc, log = sh('. scripts/env.sh; $ROC test tests/unit/epochs.roc --no-cache', 300)
    if rc != 0:
        if 'failed' not in log and 'FAIL' not in log and 'rashed' not in log:
            return 'INVALID (test does not run)', log.strip()[-90:]
        return 'caught', 'l0 ' + next((l.strip() for l in log.splitlines() if 'failed' in l or 'FAIL' in l or 'rashed' in l), '')[:90]
    rc, log = sh('scripts/test.sh l1', 300)
    if rc != 0:
        return 'caught', 'l1 only: ' + next((l.strip() for l in log.splitlines() if 'FAILED' in l), '')[:90]
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
            res, why = run()
        finally:
            restore(path)
        out.append((x['id'], x['rule'], res, why))
        print(out[-1], flush=True)
    if check:
        print('checked', len(M), 'bad', len(out))
        return
    with open('research/slice-033-revert/agent-results%s.md' % ('-part' if want else ''), 'w') as f:
        f.write('| id | rule | result | first failing line |\n| --- | --- | --- | --- |\n')
        for r in out:
            f.write('| %s | %s | %s | %s |\n' % r)
main()
