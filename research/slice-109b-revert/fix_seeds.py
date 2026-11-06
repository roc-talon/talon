# Slice 109b (Design Q340, R-AP80): the toolchains seeds of the W2 cases of other areas get the `size` column.
# size = 1000 + log_index. The bodies in the oidc expectations get "size" after "sha256". Run once from the repo root. It copies each changed file to before/.
import re, os, shutil, sys

ROOT = os.getcwd()
BEFORE = os.path.join(ROOT, 'research/slice-109b-revert/before')
changed = []

def backup(path):
    dst = os.path.join(BEFORE, path)
    if not os.path.exists(dst):
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(path, dst)

def split_top(s):
    out, cur, q, depth = [], '', False, 0
    for ch in s:
        if q:
            cur += ch
            if ch == "'": q = False
        elif ch == "'": q = True; cur += ch
        elif ch == ',' and depth == 0: out.append(cur.strip()); cur = ''
        else: cur += ch
    out.append(cur.strip())
    return out

OLD = 'INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index) VALUES ('
NEW = 'INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index) VALUES ('

def fix_sql_line(line):
    if not line.startswith(OLD): return line
    m = re.fullmatch(r'(.*?) VALUES \((.*)\);(\s*)', line, re.S)
    vals = split_top(m.group(2))
    assert len(vals) == 7, line
    vals.insert(5, str(1000 + int(vals[6])))
    return NEW[:-1] + '(' + ', '.join(vals) + ');' + m.group(3)

def seed_files():
    for dp, _, fs in os.walk('worker/tests/cases'):
        if '/toolchains' in dp + '/' and dp.startswith('worker/tests/cases/toolchains'): continue
        for f in fs:
            if f == 'seed.sql': yield os.path.join(dp, f)

for p in sorted(seed_files()):
    s = open(p).read()
    if OLD not in s: continue
    t = ''.join(fix_sql_line(l) for l in s.splitlines(keepends=True))
    assert OLD not in t
    backup(p); open(p, 'w').write(t); changed.append(p)

# the toolchain rows in the bodies of the oidc expectations (plain and backslash-escaped JSON)
pat = re.compile(r'(\\?"sha256\\?":\\?"[0-9a-f]{64}\\?",)(\\?"published_at\\?":\d+,\\?"log_index\\?":(\d+))')
def add_size(m):
    q = '\\"' if m.group(1).count('\\"') else '"'
    return m.group(1) + f'{q}size{q}:{1000 + int(m.group(3))},' + m.group(2)
for dp, _, fs in os.walk('worker/tests/cases'):
    if dp.startswith('worker/tests/cases/toolchains'): continue
    for f in fs:
        p = os.path.join(dp, f)
        if '/expect/' not in p + '/' or not f.endswith('.jsonl'): continue
        s = open(p).read()
        t = pat.sub(add_size, s)
        if t != s: backup(p); open(p, 'w').write(t); changed.append(p)
print('\n'.join(changed)); print(len(changed), 'files')
