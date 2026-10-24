# Compare the old and the new expect/ dir of one case. Print each line that only one side has and that is not of an allowed kind (slice 031).
# The probes are in other rounds now, so lines move: the lines are compared as a count of each text, not as a sequence.
import collections, os, re, sys
old, new, name = sys.argv[1:4]
touch = r'^write_atomic \$HOME\d*/\.cache/roc/toolchains/\S+/\.last-use$'
stopped = r'^  probe \$HOME\d*/\.cache/roc/talon/tmp/\S+ \S+ \S+ check main\.roc timeout=\d+$'  # the candidate check does not start when the baseline fails
unit = r'^  probe \$HOME/\.cache/roc/packages/\S+ \S+ \S+ check main\.roc timeout=\d+$'
env = r'^    env XDG_CACHE_HOME=\S+ ROC_CACHE_DIR=\S+ TALON_IN_PROXY=1$'
allowed = {
    'calls.log': {
        '+': [r'^random$', r'^list_dirs \$HOME\d*/\.cache/roc/packages$', r'^read_files \$HOME\d*/\.cache/roc/packages/\S+/main\.roc( \S+)*$', r'^db_query \S+ busy_ms=5000 format=1 facts=\d+$', r'^db_write \S+ busy_ms=5000 format=1 facts=\d+ existing=replace$', r'^probes \d+( pool=\d+)?$', unit, env, touch],
        '-': [r'^probes \d+$', env, touch, stopped],
    },
    'stdout': {'+': [r'^resolved at \S+, \d+ probes$', r'\{"schema":1,.*"probes":\d+'], '-': [r'^resolved at \S+, \d+ probes$', r'\{"schema":1,.*"probes":\d+']},
    'stderr': {'+': [r'^resolved at \S+, \d+ probes$'], '-': [r'^resolved at \S+, \d+ probes$']},
}
def lines(d, f):
    p = os.path.join(d, f)
    return open(p).read().splitlines() if os.path.exists(p) else []
bad = []
for f in sorted(os.listdir(new)):
    a, b = lines(old, f), lines(new, f)
    if a == b:
        continue
    if f == 'tree.diff':
        # only the new fact file may be added
        ca, cb = collections.Counter(a), collections.Counter(b)
        extra = [l for l in (cb - ca)] 
        gone = [l for l in (ca - cb)]
        text = '\n'.join(b)
        bad += [(f, '-' + l) for l in gone if not l.startswith('@@')]
        for l in extra:
            if not ('compat.tsv' in l or l.startswith(('+format', '+fact', '@@'))):
                bad.append((f, '+' + l))
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
    print('   ', f, line[:180])
