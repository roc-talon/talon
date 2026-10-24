# Compare the old and the new expect/ dir of one case. Print each line that only one side has and that is not of an allowed kind (slice 032b).
# The allowed kinds: the unit-fail note line, the same text in `data.notes`, the new reads and the db query of `why`.
import collections, os, re, sys
old, new, name = sys.argv[1:4]
note = r'^(\S+: )?note: module \S+ fails on \S+\. Your app does not import it\.$'
allowed = {
    'calls.log': {
        '+': [r'^read_files \$HOME\d*/\.cache/roc/packages/\S+/main\.roc$', r'^db_query \S+ busy_ms=5000 format=1 facts=\d+$'],
        '-': [],
    },
    'stdout': {'+': [note, r'"notes":\[[^\]]*module \S+ fails on \S+\. Your app does not import it\.'], '-': [r'"notes":\[']},
    'stderr': {'+': [note], '-': []},
}
def lines(d, f):
    p = os.path.join(d, f)
    return open(p).read().splitlines() if os.path.exists(p) else []
bad = []
for f in sorted(set(os.listdir(new)) | set(os.listdir(old))):
    a, b = lines(old, f), lines(new, f)
    if a == b:
        continue
    if f not in allowed:
        bad += [(f, '? changed')]
        continue
    ca, cb = collections.Counter(a), collections.Counter(b)
    for sign, cnt in (('+', cb - ca), ('-', ca - cb)):
        for l in cnt:
            if not any(re.search(p, l) for p in allowed[f][sign]):
                bad.append((f, sign + l))
print(name, 'OK' if not bad else 'CHECK')
for f, line in bad:
    print('  ', f, line[:300])
