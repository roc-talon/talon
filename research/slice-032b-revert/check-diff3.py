# Compare the old and the new expect/ dir of one L3 case (slice 032b). The allowed change: a `why --json` line has the 3 new keys at the end of each member.
import os, re, sys
old, new, name = sys.argv[1:4]
bad = []
for f in sorted(set(os.listdir(new)) | set(os.listdir(old))):
    p, q = os.path.join(old, f), os.path.join(new, f)
    a = open(p).read().splitlines() if os.path.exists(p) else []
    b = open(q).read().splitlines() if os.path.exists(q) else []
    if a == b:
        continue
    if f != 'stdout' or len(a) != len(b):
        bad.append((f, 'changed'))
        continue
    for x, y in zip(a, b):
        if x == y:
            continue
        stripped = re.sub(r',"compiler":(null|"[^"]*"),"evidence":\[[^\]]*\],"notes":\[[^\]]*\]\}', '}', y)
        if stripped != x:
            bad.append((f, y[:200]))
print(name, 'OK' if not bad else 'CHECK')
for f, l in bad:
    print('  ', f, l)
