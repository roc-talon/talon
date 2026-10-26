#!/usr/bin/env python3
# Slice 078: new expect/tree.diff files. The L2 and L3 runners leave the work dirs of the last run (/tmp/talon-l2/<area>_<id>, /tmp/talon-test/<area>_<id>), made by the code of slice 078 away (the stubs: no `bin` record).
# For each case whose expected tree.diff has a tools.json, this script adds the field `bin` that the new code writes (R-T4, R-ST11): for each bin dir entry that Talon made in the run, `bin.<name>` is the sha256 of the data file.
# The entries that were made: L2 from the `rename` calls of `expect/calls.log` onto the bin dir, L3 from the files of the bin dir that differ from `orig/`.
# Usage: regen.py plan|apply l2|l3 [case ...]
import json, os, re, sys, hashlib, glob, subprocess, shutil, collections
mode, kind = sys.argv[1], sys.argv[2]
only = sys.argv[3:]
base = 'tests/commands/cases' if kind == 'l2' else 'tests/scenarios'
wbase = '/tmp/talon-l2' if kind == 'l2' else '/tmp/talon-test'
def sha(p): return hashlib.sha256(open(p, 'rb').read()).hexdigest()
def render(o): return json.dumps(o, separators=(',', ':'), ensure_ascii=False)
def made_l2(case_dir):
    out = []
    for l in open(f'{case_dir}/expect/calls.log', errors='replace').read().splitlines():
        m = re.match(r'rename \S+\.[0-9a-f]{16}\.tmp \$HOME(/[^/\\ ]+)?[/\\]\.local[/\\]bin[/\\]([^/\\ ]+)$', l)
        if m: out.append(((m.group(1) or '').lstrip('/'), m.group(2)))
    return out
def made_l3(w):
    out = []
    for f in glob.glob(f'{w}/home/**/.local/bin/*', recursive=True):
        rel = os.path.relpath(f, f'{w}/home')
        pre = rel.split('.local/bin/')[0].rstrip('/')
        o = f'{w}/orig/home/{rel}'
        if os.path.isfile(f) and (not os.path.exists(o) or sha(f) != sha(o)): out.append((pre, os.path.basename(f)))
    return out
def tree_diff(w):
    r = subprocess.run(['bash', '-c', f'. scripts/env.sh; . tests/lib.sh; tree_diff {w}'], capture_output=True)
    return r.stdout
for td in sorted(glob.glob(f'{base}/*/*/expect/tree.diff')):
    case_dir = td[:-len('/expect/tree.diff')]
    rel = case_dir[len(base) + 1:]
    if only and rel not in only: continue
    w = f'{wbase}/{rel.replace("/", "_")}'
    if not os.path.isdir(w): continue
    if tree_diff(w) != open(td, 'rb').read():
        print(rel, 'SKIP: the work dir does not give the expected tree.diff (old code)'); continue
    made = made_l2(case_dir) if kind == 'l2' else made_l3(w)
    if not made: continue
    changed = []
    scratch = w
    backup = f'{w}.bak'
    shutil.rmtree(backup, ignore_errors=True)
    shutil.copytree(w, backup, symlinks=True)
    tjs = glob.glob(f'{scratch}/home/**/.local/share/talon/tools.json', recursive=True)
    pres = [os.path.relpath(t, f'{scratch}/home').split('.local/share/talon/tools.json')[0].rstrip('/') for t in tjs]
    for tj in tjs:
        text = open(tj).read()
        doc = json.loads(text, object_pairs_hook=collections.OrderedDict)
        nl = '\n' if text.endswith('\n') else ''
        assert render(doc) + nl == text, (rel, tj, 'render differs')
        pre = os.path.relpath(tj, f'{scratch}/home').split('.local/share/talon/tools.json')[0].rstrip('/')
        databin = os.path.dirname(tj) + '/bin'
        for (p, name) in made:
            if p != pre and not (p not in pres and pre == ''): continue
            stem = name[:-4] if name.endswith('.exe') else name
            key = 'talon' if stem in ('tln', 'roc') else stem
            data = f'{databin}/{"tln" if stem == "roc" else stem}{".exe" if name.endswith(".exe") else ""}'
            tools = doc.get('tools', {})
            if key not in tools or not os.path.isfile(data): continue
            tools[key].setdefault('bin', collections.OrderedDict())[stem] = sha(data)
            changed.append((os.path.relpath(tj, f'{scratch}/home'), key, stem))
        new = render(doc) + nl
        if new != text: open(tj, 'w').write(new)
    out = tree_diff(scratch)
    print(rel, 'made=', made, 'bin=', [(k, s) for (_, k, s) in changed], 'DIFF' if out != open(td, 'rb').read() else 'same')
    if mode == 'apply' and out != open(td, 'rb').read():
        open(td, 'wb').write(out)
    shutil.rmtree(w)
    shutil.move(backup, w)
