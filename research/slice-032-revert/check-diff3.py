# Compare the old and the new expect/ dir of one L3 case (slice 032). Only these changes are allowed:
#   stdout, stderr: `build: passed` becomes `build: skipped (recorded pass)` (also with a file prefix), `"build":"passed"` becomes `"build":"skipped"`, and the number of probes
#   roc.log: fewer `build main.roc --output=...` lines (a skipped build), and no other change
#   facts.tsv: more rows `fact <hash> <compiler> x64musl pass <digest>`, and no other change
#   tree.diff: the same rows in a compat dump, and no other change
import collections, os, re, sys
old, new, name = sys.argv[1:4]
def lines(d, f):
    p = os.path.join(d, f)
    return open(p).read().splitlines() if os.path.exists(p) else []
def blind(l):
    l = re.sub(r'(, )\d+( probes)$', r'\1N\2', re.sub(r'"probes":\d+', '"probes":N', l))
    l = l.replace('build: skipped (recorded pass)', 'build: passed').replace('"build":"skipped"', '"build":"passed"')
    return l
row = re.compile(r'^fact\t\S+\t\S+\tx64musl\tpass\t\t[0-9a-f]{64}$')
bad = []
for f in sorted(set(os.listdir(new)) | set(os.listdir(old))):
    a, b = lines(old, f), lines(new, f)
    if a == b:
        continue
    if f == 'facts.tsv':
        ca, cb = collections.Counter(a), collections.Counter(b)
        bad += [(f, '-' + l) for l in (ca - cb)]
        bad += [(f, '+' + l) for l in (cb - ca) if not row.match(l)]
    elif f == 'tree.diff':
        ca, cb = collections.Counter(a), collections.Counter(b)
        extra = [l for l in (cb - ca) if not (row.match(l[1:]) or l.startswith('@@'))]
        bad += [(f, '+' + l) for l in extra] + [(f, '-' + l) for l in (ca - cb) if not l.startswith('@@')]
    elif f in ('stdout', 'stderr'):
        if [blind(l) for l in a] != [blind(l) for l in b]:
            bad.append((f, 'other change than the build line and the probe count'))
    elif f == 'roc.log':
        ca, cb = collections.Counter(a), collections.Counter(b)
        for l in (cb - ca):
            bad.append((f, '+' + l))
        for l in (ca - cb):
            if not l.startswith('build main.roc --output='):
                bad.append((f, '-' + l))
        if [l for l in a if not l.startswith('build main.roc')] != [l for l in b if not l.startswith('build main.roc')]:
            bad.append((f, 'the order of the other lines changed'))
    else:
        bad.append((f, '? changed'))
print(name, 'OK' if not bad else 'CHECK')
for f, line in bad:
    print('   ', f, line[:180])
