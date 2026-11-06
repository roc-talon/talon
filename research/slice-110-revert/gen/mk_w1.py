# Makes the fixed W1 cases c2-closure-cte and c3-order-window of slice 110 (setup.sql, requests.json). The expected rows are written by hand
# here from the design (Registry R-AP17, R-AP18, R-AP28, R-AP32, R-AP29, R-MX16, R-RE13, R-RE19, R-IK2, R-IK5), not from the SQL.
import json, os
ROOT = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'sql', 'tests', 'cases', 'closure')
T63 = 1 << 63
def stored(key): return key - T63  # key XOR 2^63 as a signed integer, for a key below 2^63
def vkey(M, m, p): return (M << 48) | (m << 32) | (p << 16) | 0xFFFF
def hx(b): return ('%02X' % b) * 32
I64MIN, I64MAX = -(1 << 63), (1 << 63) - 1

# ---- c2: the closure CTE, the records, unknown, checked, repos, log_size ----
G = 9007199254740993  # 2^53 + 1 (R-IK2: exact in a JSON parameter)
art = {'A': 1, 'B': 2, 'C': 3, 'D': 4, 'E': 5, 'F': 6, 'A2': 7, 'G': G, 'X99': 99, 'Z': 8}
byte = {'A': 1, 'B': 2, 'C': 3, 'D': 4, 'E': 5, 'F': 6, 'A2': 7, 'G': 0x47, 'X99': 0x63, 'Z': 0x5A}
forms = {100: 'github.com/o/a/releases/download/{v}/', 200: 'github.com/o/e/releases/download/{v}/', 300: 'github.com/o/b/releases/download/{v}/', 400: 'example.com/g/{v}/', 600: 'github.com/o/z/releases/download/{v}/'}
repos = {501: 'o/a', 502: 'o/b', 503: 'o/e', 504: 'o/b2', 505: 'o/z'}
s = []
for k, i in art.items(): s.append(f"INSERT INTO names VALUES ({i}, 1, x'{hx(byte[k])}');")
for i, v in forms.items(): s.append(f"INSERT INTO names VALUES ({i}, 2, '{v}');")
for i, v in repos.items(): s.append(f"INSERT INTO names VALUES ({i}, 3, '{v}');")
arts = [('A', 1, '["A"]', None, None, 10), ('B', 1, '["B"]', None, 'nightly-2026-01-01-0000001', 20), ('C', 2, '["Pf"]', None, None, 30),
        ('D', 1, '[]', None, None, 40), ('E', 1, '[]', None, None, 50), ('F', 1, '[]', None, None, 60), ('A2', 1, '[]', None, None, 70), ('G', 0, '[]', 'C', None, 80), ('Z', 1, '[]', None, None, 90)]
q = lambda x: 'NULL' if x is None else (f"'{x}'" if isinstance(x, str) else str(x))
for k, kind, ex, pf, pin, size in arts:
    s.append(f"INSERT INTO artifacts VALUES ({art[k]}, {kind}, {q(ex)}, {art[pf] if pf else 'NULL'}, {q(pin)}, {size});")
v100 = stored(vkey(1, 0, 0)); v110 = stored(vkey(1, 1, 0))
deps = [('A', 'b', 'B', 300, v100, 'https://github.com/o/b/releases/download/1.0.0/b.tar.zst'), ('A', 'c', 'C', None, None, f'https://example.com/c/{hx(3)}.tar.zst'),
        ('A', 'x', 'X99', None, None, 'https://example.com/x/x.tar.zst'), ('B', 'd', 'D', 300, v110, 'https://github.com/o/b/releases/download/1.1.0/d.tar.zst'),
        ('C', 'd', 'D', 300, v110, 'https://github.com/o/b/releases/download/1.1.0/d.tar.zst'), ('D', 'b', 'B', 300, v100, 'https://github.com/o/b/releases/download/1.0.0/b.tar.zst'),
        ('E', 'f', 'F', 200, stored(vkey(0, 4, 0)), 'https://github.com/o/e/releases/download/0.4.0/f.tar.zst'), ('F', 'e', 'E', 200, stored(vkey(0, 3, 0)), 'https://github.com/o/e/releases/download/0.3.0/e.tar.zst'),
        ('G', 'pf', 'C', None, None, f'https://example.com/c/{hx(3)}.tar.zst')]
for o, al, d, f, v, url in deps:
    s.append(f"INSERT INTO deps VALUES ({art[o]}, '{al}', {art[d]}, {q(f)}, {q(v)}, {q('' if v is not None else None)}, '{url}');")
s.append("INSERT INTO artifact_targets VALUES (3, 7), (3, 24);")
rel = [(1, 'A', 100, vkey(1, 0, 0), 'https://github.com/o/a/releases/download/1.0.0/a.tar.zst', 'v1.0.0', '0.1', 501, 1000, 0, None),
       (2, 'A2', 100, vkey(2, 0, 0), 'https://github.com/o/a/releases/download/2.0.0/a.tar.zst', 'v2.0.0', None, 501, 2000, 0, None),
       (3, 'E', 200, vkey(0, 3, 0), 'https://github.com/o/e/releases/download/0.3.0/e.tar.zst', '0.3.0', None, 503, 3000, 0, None),
       (4, 'B', 300, vkey(1, 0, 0), 'https://github.com/o/b/releases/download/1.0.0/b.tar.zst', '1.0.0', None, 502, 4000, 0, None),
       (5, 'D', 300, vkey(1, 1, 0), 'https://github.com/o/b/releases/download/1.1.0/d.tar.zst', '1.1.0', None, 502, 5000, 0, 'deleted'),
       (6, 'G', 400, vkey(0, 1, 0), 'https://example.com/g/0.1.0/g.tar.zst', None, None, None, 6000, 0, None),
       (7, 'F', 200, vkey(0, 4, 0), 'https://github.com/o/e/releases/download/0.4.0/f.tar.zst', '0.4.0', None, 503, 7000, 1, None),
       (8, 'Z', 600, vkey(1, 0, 0), 'https://github.com/o/z/releases/download/1.0.0/z.tar.zst', '1.0.0', None, 505, 8000, 0, None)]
for li, a, f, k, url, tag, rv, repo, pub, yanked, wd in rel:
    s.append(f"INSERT INTO releases VALUES ({li}, {f}, {stored(k)}, '', {art[a]}, {q(repo)}, '{url}', {q(tag)}, {q(rv)}, {pub}, {yanked}, {q(wd)}, {'NULL' if wd is None else 7500});")
for i in range(1, 10): s.append(f"INSERT INTO log VALUES ({i}, 'g', 'v', 'h', {i});")
s.append("INSERT INTO repo_checks VALUES (501, NULL, 1767225000000, 1767228600000, 0, 1);")
s.append("INSERT INTO repos VALUES (501, 11, 12, 0, NULL, 1000, 1000), (502, 21, 22, 2, 504, 2000, 2000);")
os.makedirs(os.path.join(ROOT, 'c2-closure-cte'), exist_ok=True)
open(os.path.join(ROOT, 'c2-closure-cte', 'setup.sql'), 'w').write('-- Made by research/slice-110-revert/gen/mk_w1.py. A diamond (A to B and C, both to D), 2 cycles (B and D, E and F), a dep that is not indexed (id 99),\n-- a platform with 2 targets, an app with its platform, a hash of 2^53 + 1 (R-IK2), 2 groups (one with series bounds).\n' + '\n'.join(s) + '\n')
groups1 = f'[{{"form":100,"lo":{stored(1 << 48)},"hi":{stored((2 << 48) - 1)}}},{{"form":200,"lo":{I64MIN},"hi":{I64MAX}}},{{"form":600,"lo":{stored(2 << 48)},"hi":{stored((3 << 48) - 1)}}}]'
hashes1 = f'[{G},12345,{G},777]'
relrow = lambda li, a, f, k, url, tag, rv, repo, pub, yanked, wd: {'log_index': li, 'hash': hx(byte[a]), 'form': forms[f], 'version': str(stored(k)), 'version_text': '', 'url': url,
    'tag': tag, 'roc_version': rv, 'repo': repos.get(repo), 'published_at': pub, 'yanked': yanked, 'withdrawn': wd}
want = {
  'artifacts': [{'hash': hx(byte[k]), 'kind': kind, 'exposed_json': ex, 'platform_hash': hx(byte[pf]) if pf else None, 'roc_pin': pin, 'size': size}
                for k, kind, ex, pf, pin, size in sorted([a for a in arts if a[0] not in ('A2', 'Z')], key=lambda a: hx(byte[a[0]]))],
  'deps': [{'owner': hx(byte[o]), 'alias': al, 'hash': hx(byte[d]), 'form': forms.get(f), 'version': None if v is None else str(v), 'version_text': None if v is None else '', 'url': url}
           for o, al, d, f, v, url in deps],
  'targets': [{'owner': hx(3), 'name': 'arm64linux'}, {'owner': hx(3), 'name': 'x64musl'}],
  'releases': [relrow(*r) for r in rel if r[1] not in ('A2', 'Z')],
  'unknown': [{'idx': 1}, {'idx': 3}],
  'epochs': [], 'runs': [], 'nearest': [], 'hints': [],
  'checked': [{'name': 'o/a', 'checked_at': 1767225000000, 'app_installed': 1}, {'name': 'o/e', 'checked_at': None, 'app_installed': 0}, {'name': 'o/z', 'checked_at': None, 'app_installed': 0}],
  'repos': [{'name': 'o/a', 'state': 0, 'successor': None, 'state_at': 1000}, {'name': 'o/b', 'state': 2, 'successor': 'o/b2', 'state_at': 2000}],
  'log_size': [{'log_size': 9}],
}
reqs = [{'note': 'R-AP17 closure: the diamond and the cycles end; A2 is out of the series bounds; R-AP64: the group o/z has no release in its bounds (series 2), and checked still has o/z; G by hashes; 12345 and 777 unknown (the first index of each)', 'params': [groups1, hashes1, None, None], 'expect': want}]
empty = {k: [] for k in want}; empty['log_size'] = [{'log_size': 9}]
reqs.append({'note': 'R-AP17: no groups and no hashes give empty lists and the log size', 'params': ['[]', '[]', None, None], 'expect': empty})
only = dict(empty); only['unknown'] = [{'idx': 0}]
reqs.append({'note': 'R-AP28: a hash that is a name of a release form (kind 2) but no artifact is unknown', 'params': ['[]', '[100]', None, None], 'expect': only})
json.dump(reqs, open(os.path.join(ROOT, 'c2-closure-cte', 'requests.json'), 'w'), indent=1)

# ---- c3: the order of R-MX16, the window, the epochs, runs, nearest and hints ----
A, B, Z = 20454, 20455, 20453
nid = lambda day, sha: day * (1 << 28) + sha
N = {'N0': (Z, 9, 5000, '2025-12-31'), 'N2': (A, 2, 500, '2026-01-01'), 'N3': (A, 3, 500, '2026-01-01'), 'N1': (A, 1, 1000, '2026-01-01'), 'N4': (B, 4, 100, '2026-01-02')}
tag = {k: f'nightly-{v[3]}-{v[1]:07x}' for k, v in N.items()}
ids = {k: nid(v[0], v[1]) for k, v in N.items()}
P = nid(A, 5)
s = []
li = 0
for k, (day, sha, t, _) in N.items():
    for host in (['linux_x86_64', 'macos_apple_silicon'] if k == 'N1' else ['linux_x86_64']):
        li += 1
        s.append(f"INSERT INTO toolchains VALUES ({ids[k]}, '{host}', '{tag[k]}', 'roc_nightly-{host}.tar.gz', '{'ab' * 32}', {t}, {li});")
s.append(f"INSERT INTO names VALUES (10, 1, x'{hx(0x0A)}'), (11, 1, x'{hx(0x0B)}');")
s.append("INSERT INTO artifacts VALUES (10, 1, '[]', NULL, NULL, 1), (11, 1, '[]', NULL, NULL, 1);")
cp = [(10, 'N0', 0, 0, None), (10, 'N2', 0, 0, None), (10, 'N3', 0, 0, None), (10, 'N1', 0, 1, 'd1'), (10, 'N4', 0, 0, None), (10, 'P', 0, 1, 'dp'),
      (11, 'N2', 1, 0, None), (11, 'N2', 0, 2, None), (11, 'N0', 1, 1, 'e1'), (11, 'N1', 0, 0, None), (11, 'N4', 1, 0, None), (11, 'N4', 0, 3, None)]
for a, n, src, res, dg in cp:
    s.append(f"INSERT INTO compat VALUES ({a}, {P if n == 'P' else ids[n]}, 0, {src}, {res}, {q(dg)}, 1, {'3' if src == 1 else 'NULL'});")
s.append(f"INSERT INTO transitions VALUES ({ids['N1']}, 0, {ids['N3']}, 2, 0), ({ids['N3']}, 0, {ids['N0']}, 2, 0), ({ids['N4']}, 0, {ids['N1']}, 2, 1);")
s.append(f"INSERT INTO compat_hints VALUES (10, {ids['N3']}, 0, 1, 1, 0, 0, 1, 1), (10, {ids['N3']}, 0, 2, 2, 1, 0, 1, 1), (10, {ids['N1']}, 0, 1, 0, 0, 1, 1, 1), (10, {P}, 0, 1, 9, 0, 0, 1, 1);")
open(os.path.join(ROOT, 'c3-order-window', 'setup.sql'), 'w').write(
  '-- Made by research/slice-110-revert/gen/mk_w1.py. R-MX16 order: N0 (an earlier date, the latest t), N2 and N3 (one date, one t: by id), N1 (the same date, a later t),\n'
  '-- N4 (a later date, the earliest t). P has compat rows and no toolchains row. The transition row of N3 names N0 as previous, but N2 is adjacent:\n'
  '-- it does not make N2 to N3 flat. N1 has 2 toolchains rows.\n' + '\n'.join(s) + '\n')
X, Y = hx(0x0A), hx(0x0B)
run = lambda h, src, res, dg, f, t: {'hash': h, 'target': 'any', 'source': src, 'result': res, 'error_digest': dg, 'from': tag[f], 'to': tag[t]}
near = lambda h, src, res, dg, n, side: {'hash': h, 'target': 'any', 'source': src, 'result': res, 'error_digest': dg, 'nightly': tag[n], 'side': side}
base = {'artifacts': None, 'deps': [], 'targets': [], 'releases': [], 'unknown': [], 'checked': [], 'repos': [], 'log_size': [{'log_size': 0}]}
arts3 = [{'hash': X, 'kind': 1, 'exposed_json': '[]', 'platform_hash': None, 'roc_pin': None, 'size': 1}, {'hash': Y, 'kind': 1, 'exposed_json': '[]', 'platform_hash': None, 'roc_pin': None, 'size': 1}]
def req(note, frm, to, ep, runs, nearest, hints):
    e = dict(base); e['artifacts'] = arts3; e.update({'epochs': ep, 'runs': runs, 'nearest': nearest, 'hints': hints})
    return {'note': note, 'params': ['[]', '[10,11]', frm, to], 'expect': e}
reqs = [
  req('R-AP17 held N3: E is the epoch N3 to N1; nearest: bot over author (R-EF3), then the code results only (R-EP1)', ids['N3'], ids['N3'],
      [{'target': 'any', 'from': tag['N3'], 'to': tag['N1']}],
      [run(X, 0, 0, None, 'N3', 'N3'), run(X, 0, 1, 'd1', 'N1', 'N1'), run(Y, 0, 0, None, 'N1', 'N1')],
      [near(X, 0, 0, None, 'N2', 'before'), near(X, 0, 0, None, 'N4', 'after'), near(Y, 1, 1, 'e1', 'N0', 'before')],
      [{'hash': X, 'nightly': tag['N3'], 'target': 'any', 'pass_count': 3, 'fail_count': 1, 'crash_count': 0}]),
  req('R-AP60: a from that is no nightly of toolchains is the start of the domain; P is not in the order', P, ids['N2'], [],
      [run(X, 0, 0, None, 'N0', 'N2'), run(Y, 0, 2, None, 'N2', 'N2'), run(Y, 1, 1, 'e1', 'N0', 'N0'), run(Y, 1, 0, None, 'N2', 'N2')],
      [near(X, 0, 0, None, 'N3', 'after'), near(Y, 0, 0, None, 'N1', 'after')], []),
  req('R-AP61: from after to is an empty window', ids['N4'], ids['N2'], [], [], [], []),
  req('R-AP16: no window is all compilers; R-AP58: X passes on N0, N2, N3 with no digest: one run (IS)', None, None, [{'target': 'any', 'from': tag['N3'], 'to': tag['N1']}],
      [run(X, 0, 0, None, 'N0', 'N3'), run(X, 0, 1, 'd1', 'N1', 'N1'), run(X, 0, 0, None, 'N4', 'N4'),
       run(Y, 0, 2, None, 'N2', 'N2'), run(Y, 0, 0, None, 'N1', 'N1'), run(Y, 0, 3, None, 'N4', 'N4'),
       run(Y, 1, 1, 'e1', 'N0', 'N0'), run(Y, 1, 0, None, 'N2', 'N2'), run(Y, 1, 0, None, 'N4', 'N4')], [],
      [{'hash': X, 'nightly': tag['N3'], 'target': 'any', 'pass_count': 3, 'fail_count': 1, 'crash_count': 0},
       {'hash': X, 'nightly': tag['N1'], 'target': 'any', 'pass_count': 0, 'fail_count': 0, 'crash_count': 1}]),
]
json.dump(reqs, open(os.path.join(ROOT, 'c3-order-window', 'requests.json'), 'w'), indent=1)
print('ok')
