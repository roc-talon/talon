# Compare the old and the new expect/ dir of one L3 case (slice 031). Only these changes are allowed:
#   stdout, stderr: the number of probes in `resolved at <time>, <n> probes` and in `"probes":<n>`
#   roc.log: more `check main.roc` lines (the unit probes), and no other change
import collections, os, re, sys
old, new, name = sys.argv[1:4]
def lines(d, f):
    p = os.path.join(d, f)
    return open(p).read().splitlines() if os.path.exists(p) else []
def probes_blind(l):
    return re.sub(r'(, )\d+( probes)$', r'\1N\2', re.sub(r'"probes":\d+', '"probes":N', l))
bad = []
for f in sorted(os.listdir(new)):
    a, b = lines(old, f), lines(new, f)
    if a == b:
        continue
    if f == 'facts.tsv':
        if a:
            bad.append((f, 'an old facts.tsv changed'))
    elif f == 'tree.diff':
        ca, cb = collections.Counter(a), collections.Counter(b)
        extra = [l for l in (cb - ca) if not ('compat' in l or l.startswith(('+format', '+fact', '@@')))]
        bad += [(f, '+' + l) for l in extra] + [(f, '-' + l) for l in (ca - cb) if not l.startswith('@@')]
    elif f in ('stdout', 'stderr'):
        unit = re.compile(r'^\S+ cwd=[1-9A-HJ-NP-Za-km-z]{43,44} check main\.roc n=\d+ ')
        a2 = [probes_blind(l) for l in a if l != 'check main.roc']
        b2 = [probes_blind(l) for l in b if not unit.match(l) and l != 'check main.roc']
        if a2 != b2:
            bad.append((f, 'other change than the probe count'))
    elif f == 'roc.log':
        ca, cb = collections.Counter(a), collections.Counter(b)
        for l in (ca - cb):
            bad.append((f, '-' + l))
        for l in (cb - ca):
            if l != 'check main.roc':
                bad.append((f, '+' + l))
        if [l for l in a if l != 'check main.roc'] != [l for l in b if l != 'check main.roc']:
            bad.append((f, 'the order of the other lines changed'))
    else:
        bad.append((f, '? changed'))
print(name, 'OK' if not bad else 'CHECK')
for f, line in bad:
    print('   ', f, line[:180])
