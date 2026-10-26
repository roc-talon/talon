#!/usr/bin/env python3
# Slice 078: for each L2 case and L3 scenario whose expected tree.diff has tools.json, list the bin dir entries that Talon made (L2: the `rename` calls onto the bin dir; L3: files of the bin dir that differ from `orig`).
import json, os, re, sys, hashlib, glob
root = os.getcwd()
def sha(p):
    return hashlib.sha256(open(p, 'rb').read()).hexdigest()
def made_l2(case_dir, w):
    log = open(f'{case_dir}/expect/calls.log').read().splitlines()
    names = []
    for l in log:
        m = re.match(r'rename \S+\.[0-9a-f]{16}\.tmp \$HOME(?:/u)?[/\\]\.local[/\\]bin[/\\]([^/\\ ]+)$', l)
        if m: names.append(m.group(1))
    return names
def made_l3(w):
    out = []
    b = f'{w}/home/.local/bin'
    if not os.path.isdir(b): return out
    for n in sorted(os.listdir(b)):
        f = f'{b}/{n}'
        o = f'{w}/orig/home/.local/bin/{n}'
        if os.path.isfile(f) and (not os.path.exists(o) or sha(f) != sha(o)): out.append(n)
    return out
kind = sys.argv[1]
base = 'tests/commands/cases' if kind == 'l2' else 'tests/scenarios'
wbase = '/tmp/talon-l2' if kind == 'l2' else '/tmp/talon-test'
for td in sorted(glob.glob(f'{base}/*/*/expect/tree.diff')):
    case_dir = td[:-len('/expect/tree.diff')]
    if 'talon/tools.json' not in open(td, errors='replace').read(): continue
    name = case_dir[len(base) + 1:].replace('/', '_')
    w = f'{wbase}/{name}'
    names = made_l2(case_dir, w) if kind == 'l2' else made_l3(w)
    tj = f'{w}/home/.local/share/talon/tools.json'
    keys = list(json.load(open(tj))['tools'].keys()) if os.path.exists(tj) else None
    print(case_dir[len(base) + 1:], 'made=', names, 'keys=', keys)
