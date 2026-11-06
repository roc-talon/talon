# Makes the W2 cases of slice 110 (worker/tests/cases/closure/). The expected answers are written here from the design
# (Registry R-AP17, R-AP49, R-AP29, R-AP32, R-MX16, R-RE13, Resolution 4) with python, not from the Roc or the SQL code.
import json, os, sys, shutil
sys.path.insert(0, os.path.dirname(__file__))
from ids import b58, name_id, nightly_id, key, stored_signed
ROOT = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'worker', 'tests', 'cases', 'closure')
J = lambda x: json.dumps(x, separators=(',', ':'))
NOW = 1767225600000  # the default clock of the runner, 2026-01-01T00:00:00Z
HDR = {'content-type': 'application/json', 'cache-control': 'no-store'}

def write(case, seed, requests, responses, calls, rules):
    d = os.path.join(ROOT, case); shutil.rmtree(d, ignore_errors=True); os.makedirs(os.path.join(d, 'expect'))
    if seed: open(os.path.join(d, 'seed.sql'), 'w').write(seed)
    open(os.path.join(d, 'requests.jsonl'), 'w').write(''.join(J(r) + '\n' for r in requests))
    open(os.path.join(d, 'expect', 'responses.jsonl'), 'w').write(''.join(J(r) + '\n' for r in responses))
    open(os.path.join(d, 'expect', 'd1-calls'), 'w').write(''.join(f'{c}\n' for c in calls))
    open(os.path.join(d, 'rules'), 'w').write(rules + '\n')

class Seed:
    def __init__(self): self.s = []; self.idx = 0
    def add(self, x): self.s.append(x)
    def leaf(self, grp, version, hsh):
        self.idx += 1; self.add(f"INSERT INTO log (idx, grp, version, hash, time) VALUES ({self.idx}, '{grp}', '{version}', '{hsh}', 1767139200000);"); return self.idx
    def text(self, note): return f'-- Made by research/slice-110-revert/gen/gen_w2.py. {note}\n' + '\n'.join(self.s) + '\n'

def q(x): return 'NULL' if x is None else (f"'{x}'" if isinstance(x, str) else str(x))
H = lambda b: bytes([b] * 32)

# ---------------- ap17-answer ----------------
S = Seed()
GA, GB, GE, GG, GR = ('github.com/o/a/releases/download/{v}/', 'github.com/o/b/releases/download/{v}/', 'github.com/o/e/releases/download/{v}/', 'example.com/g/{v}/', 'github.com/o/r/releases/download/{v}/')
forms = [GA, GB, GE, GG, GR]
repos = ['o/a', 'o/b', 'o/b2', 'o/e', 'o/r']
art = {'A': 0x0A, 'A2': 0x1A, 'B': 0x0B, 'C': 0x0C, 'E': 0x0E, 'F': 0x0F, 'G': 0x47, 'X99': 0x63, 'R12': 0x31, 'R13': 0x32, 'R14': 0x33}
aid = {k: name_id(1, H(v)) for k, v in art.items()}
bh = {k: b58(H(v)) for k, v in art.items()}
fid = {g: name_id(2, g.encode()) for g in forms}
rid = {r: name_id(3, r.encode()) for r in repos}
vals = [f"({aid[k]}, 1, X'{H(v).hex()}')" for k, v in art.items()] + [f"({fid[g]}, 2, '{g}')" for g in forms] + [f"({rid[r]}, 3, '{r}')" for r in repos]
S.add('INSERT INTO names (id, kind, value) VALUES\n  ' + ',\n  '.join(vals) + ';')
arts = {'A': (1, '["A"]', None, None, 10), 'A2': (1, '["A"]', None, None, 11), 'B': (1, '["B"]', None, 'nightly-2026-01-01-0000001', 20), 'C': (2, '["Pf"]', None, None, 30),
        'E': (1, '["E"]', None, None, 50), 'F': (1, '[]', None, None, 60), 'G': (0, '[]', 'C', None, 70), 'R12': (1, '[]', None, None, 1), 'R13': (1, '[]', None, None, 1), 'R14': (1, '[]', None, None, 1)}
for k, (kind, ex, pf, pin, size) in arts.items():
    S.add(f"INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES ({aid[k]}, {kind}, '{ex}', {aid[pf] if pf else 'NULL'}, {q(pin)}, {size});")
S.add(f"INSERT INTO artifact_targets (artifact, target) VALUES ({aid['C']}, 7), ({aid['C']}, 24);")
def ver(v): M, m, p = map(int, v.split('.')); return stored_signed(key(M, m, p))
def series(v): M, m, _ = map(int, v.split('.')); return str(M) if M >= 1 else f'0.{m}'
curl = f"https://example.com/c/{bh['C']}.tar.zst"
deps = [('A', 'b', 'B', GB, '1.0.0', f'https://github.com/o/b/releases/download/1.0.0/{bh["B"]}.tar.zst'), ('A', 'c', 'C', None, None, curl),
        ('A', 'x', 'X99', None, None, 'https://example.com/x/x.tar.zst'), ('E', 'f', 'F', GE, '0.4.0', f'https://github.com/o/e/releases/download/0.4.0/{bh["F"]}.tar.zst'),
        ('F', 'e', 'E', GE, '0.3.0', f'https://github.com/o/e/releases/download/0.3.0/{bh["E"]}.tar.zst'), ('G', 'pf', 'C', None, None, curl)]
for o, al, d, g, v, url in deps:
    S.add(f"INSERT INTO deps (artifact, alias, dep, form, version, version_text, url) VALUES ({aid[o]}, '{al}', {aid[d]}, {fid[g] if g else 'NULL'}, {q(ver(v)) if v else 'NULL'}, {q('' if v else None)}, '{url}');")
rel = [('A', GA, '1.0.0', 'o/a', '1.0.0', '0.1', None), ('A2', GA, '2.0.0', 'o/a', '2.0.0', None, None), ('B', GB, '1.0.0', 'o/b', '1.0.0', None, None),
       ('E', GE, '0.3.0', 'o/e', '0.3.0', None, 'deleted'), ('G', GG, '0.1.0', None, None, None, None),
       ('R12', GR, '1.2.0', 'o/r', '1.2.0', None, None), ('R13', GR, '1.3.0', 'o/r', '1.3.0', None, None), ('R14', GR, '1.4.0', 'o/r', '1.4.0', None, None)]
relwire = {}
for a, g, v, repo, tag, rv, wd in rel:
    url = f"https://{g.replace('{v}', v)}{bh[a]}.tar.zst"
    li = S.leaf(g, v, bh[a])
    pub = 1700000000000 + li * 1000
    S.add(f"INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES ({li}, {fid[g]}, {ver(v)}, '', {aid[a]}, {rid[repo] if repo else 'NULL'}, '{url}', {q(tag)}, {q(rv)}, {pub}, 0, {q(wd)}, {'NULL' if wd is None else 1767139200000});")
    relwire[a] = {'log_index': li, 'hash': bh[a], 'group': g, 'series': series(v), 'version': v, 'url': url, 'tag': tag, 'roc_version': rv, 'repo': repo, 'published_at': pub, 'yanked': False, 'yank_reason': None, 'withdrawn': wd}
S.add(f"INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES ({rid['o/a']}, 1, 2, 0, NULL, 1000, 1000), ({rid['o/b']}, 3, 4, 2, {rid['o/b2']}, 2000, 2000), ({rid['o/e']}, 5, 6, 0, NULL, 3000, 3000), ({rid['o/r']}, 7, 8, 0, NULL, 4000, 4000);")
S.add(f"INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES ({rid['o/a']}, NULL, {NOW - 3600000}, {NOW}, 0, 0);")
# Compilers (R-MX16): N0 an earlier date and the latest t; N2 and N3 one date and one t (by id); N1 the same date, a later t; N4 a later date, the earliest t.
N = {'N0': ('nightly-2025-12-31-0000009', 5000), 'N2': ('nightly-2026-01-01-0000002', 500), 'N3': ('nightly-2026-01-01-0000003', 500),
     'N1': ('nightly-2026-01-01-0000001', 1000), 'N4': ('nightly-2026-01-02-0000004', 100)}
nid = {k: nightly_id(t) for k, (t, _) in N.items()}
tag = {k: t for k, (t, _) in N.items()}
for k, (t, pub) in N.items():
    for host in (['linux_x86_64', 'macos_apple_silicon'] if k == 'N1' else ['linux_x86_64']):
        sha = 'ab' * 32
        li = S.leaf(f'roc-lang/nightlies:{host}', t, f'sha256:{sha}')
        S.add(f"INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index) VALUES ({nid[k]}, '{host}', '{t}', 'roc_nightly-{host}-x.tar.gz', '{sha}', {pub}, {li});")
P = nightly_id('nightly-2026-01-01-0000005')
X, Y = 'A', 'B'
cp = [(X, 'N0', 0, 0, None), (X, 'N2', 0, 0, None), (X, 'N3', 0, 0, None), (X, 'N1', 0, 1, 'd1'), (X, 'N4', 0, 0, None), (X, 'P', 0, 1, 'dp'),
      (Y, 'N2', 1, 0, None), (Y, 'N2', 0, 2, None), (Y, 'N0', 1, 1, 'e1'), (Y, 'N1', 0, 0, None), (Y, 'N4', 1, 0, None), (Y, 'N4', 0, 3, None)]
for a, n, src, res, dg in cp:
    S.add(f"INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES ({aid[a]}, {P if n == 'P' else nid[n]}, 0, {src}, {res}, {q(dg)}, 1, {1 if src == 1 else 'NULL'});")
S.add(f"INSERT INTO transitions (nightly, target, previous, compared, changed) VALUES ({nid['N1']}, 0, {nid['N3']}, 2, 0), ({nid['N3']}, 0, {nid['N0']}, 2, 0), ({nid['N4']}, 0, {nid['N1']}, 2, 1);")
S.add(f"INSERT INTO compat_hints (artifact, nightly, target, talon_version, pass_count, fail_count, crash_count, first_time, last_time) VALUES ({aid[X]}, {nid['N3']}, 0, 1, 1, 0, 0, 1, 1), ({aid[X]}, {nid['N3']}, 0, 2, 2, 1, 0, 1, 1), ({aid[X]}, {nid['N1']}, 0, 1, 0, 0, 1, 1, 1), ({aid[X]}, {P}, 0, 1, 9, 0, 0, 1, 1);")
log_size = S.idx
srcs = ['bot', 'author']; ress = ['pass', 'fail', 'hang', 'crash']
run = lambda a, s, r, dg, f, t: {'hash': bh[a], 'target': 'any', 'source': srcs[s], 'result': ress[r], 'error_digest': dg, 'from': tag[f], 'to': tag[t]}
near = lambda a, s, r, dg, n, side: {'hash': bh[a], 'target': 'any', 'source': srcs[s], 'result': ress[r], 'error_digest': dg, 'nightly': tag[n], 'side': side}
def depw(o, al, d, g, v, url):
    grp = g if g else url.split('://', 1)[1].rsplit('/', 1)[0] + '/'
    return {'alias': al, 'hash': bh[d], 'group': grp, 'series': series(v) if v else None, 'version': v, 'url': url}
def artw(k):
    kind, ex, pf, pin, size = arts[k]
    return {'hash': bh[k], 'kind': ['app', 'package', 'platform'][kind], 'exposed': json.loads(ex), 'platform_hash': bh[pf] if pf else None, 'roc_pin': pin, 'size': size,
            'deps': sorted([depw(*d) for d in deps if d[0] == k], key=lambda x: x['alias']), 'target_names': ['arm64linux', 'x64musl'] if k == 'C' else []}
closure = sorted(['A', 'B', 'C', 'E', 'F', 'G'], key=lambda k: H(art[k]))
U = b58(H(0x77))  # a hash that is not indexed
held = {
    'artifacts': [artw(k) for k in closure],
    'releases': [relwire[k] for k in sorted(['A', 'B', 'E', 'G'], key=lambda k: relwire[k]['log_index'])],
    'epochs': [{'target': 'any', 'from': tag['N3'], 'to': tag['N1']}],
    'runs': [run(X, 0, 0, None, 'N3', 'N3'), run(X, 0, 1, 'd1', 'N1', 'N1'), run(Y, 0, 0, None, 'N1', 'N1')],
    'nearest': [near(X, 0, 0, None, 'N2', 'before'), near(X, 0, 0, None, 'N4', 'after'), near(Y, 1, 1, 'e1', 'N0', 'before')],
    'hints': [{'hash': bh[X], 'nightly': tag['N3'], 'target': 'any', 'pass_count': 3, 'fail_count': 1, 'crash_count': 0}],
    'log_size': log_size,
    'unknown': [U, 'not a hash'],
    'checked': [{'name': 'o/a', 'checked_at': NOW - 3600000, 'stale': False}, {'name': 'o/e', 'checked_at': None, 'stale': True}],
    'repos': [{'name': 'o/a', 'state': 'active', 'successor': None, 'state_at': 1000}, {'name': 'o/b', 'state': 'moved', 'successor': 'o/b2', 'state_at': 2000},
              {'name': 'o/e', 'state': 'active', 'successor': None, 'state_at': 3000}],
}
full = dict(held)
full['epochs'] = [{'target': 'any', 'from': tag['N3'], 'to': tag['N1']}]
full['runs'] = [run(X, 0, 0, None, 'N0', 'N3'), run(X, 0, 1, 'd1', 'N1', 'N1'), run(X, 0, 0, None, 'N4', 'N4'),
                run(Y, 0, 2, None, 'N2', 'N2'), run(Y, 0, 0, None, 'N1', 'N1'), run(Y, 0, 3, None, 'N4', 'N4'),
                run(Y, 1, 1, 'e1', 'N0', 'N0'), run(Y, 1, 0, None, 'N2', 'N2'), run(Y, 1, 0, None, 'N4', 'N4')]
full['nearest'] = []
full['hints'] = [{'hash': bh[X], 'nightly': tag['N3'], 'target': 'any', 'pass_count': 3, 'fail_count': 1, 'crash_count': 0},
                 {'hash': bh[X], 'nightly': tag['N1'], 'target': 'any', 'pass_count': 0, 'fail_count': 0, 'crash_count': 1}]
groups = [{'group': GA, 'series': '1'}, {'group': GE}]
body = {'groups': groups, 'hashes': [bh['G'], U, 'not a hash'], 'compilers': {'from': tag['N3'], 'to': tag['N3']}}
extra = {'snapshot': 'log:2', 'groups': [dict(g, note='x') for g in groups], 'hashes': body['hashes'], 'compilers': dict(body['compilers'], step=1), 'unknown_member': [1]}
empty = {'artifacts': [], 'releases': [], 'epochs': [], 'runs': [], 'nearest': [], 'hints': [], 'log_size': log_size, 'unknown': [], 'checked': [], 'repos': []}
rng = {'groups': [{'group': GR, 'range': '>1.2.0, <1.4.0'}], 'hashes': [bh['R12']]}
reqs = [
  {'method': 'POST', 'path': '/v1/closure', 'json': body},
  {'method': 'POST', 'path': '/v1/closure?snapshot=log:2&x=1', 'json': extra},
  {'method': 'POST', 'path': '/v1/closure', 'json': {'groups': groups, 'hashes': body['hashes']}},
  {'method': 'POST', 'path': '/v1/closure', 'json': {'groups': [], 'hashes': []}},
  {'method': 'POST', 'path': '/v1/closure', 'json': rng},
  {'method': 'POST', 'path': '/v1/closure', 'json': {'groups': [{'group': GA, 'series': '1'}, {'group': GA, 'series': '1'}], 'hashes': [bh['A'], bh['A']]}},
  {'method': 'POST', 'path': '/v1/closure', 'json': {'groups': groups, 'hashes': body['hashes'], 'compilers': {'from': 'v1.2.3', 'to': 'nightly-2026-02-30-0000001'}}},
  {'method': 'POST', 'path': '/v1/closure', 'json': {'groups': [{'group': GR, 'range': '>=5.0.0'}], 'hashes': []}},
]
resp = [
  {'status': 200, 'headers': HDR, 'json': held},
  {'status': 200, 'headers': HDR, 'json': held},
  {'status': 200, 'headers': HDR, 'json': full},
  {'status': 200, 'headers': HDR, 'json': empty},
  {'status': 200, 'headers': HDR, 'json': {'releases': [relwire['R12'], relwire['R13']], 'checked': [{'name': 'o/r', 'checked_at': None, 'stale': True}], 'repos': [{'name': 'o/r', 'state': 'active', 'successor': None, 'state_at': 4000}], 'unknown': []}},
  {'status': 200, 'headers': HDR, 'json': {'artifacts': [artw(k) for k in sorted(['A', 'B', 'C'], key=lambda k: H(art[k]))], 'releases': [relwire['A'], relwire['B']], 'unknown': [], 'checked': [{'name': 'o/a', 'checked_at': NOW - 3600000, 'stale': False}]}},
  {'status': 200, 'headers': HDR, 'json': full},
  {'status': 200, 'headers': HDR, 'json': {'artifacts': [], 'releases': [], 'checked': [{'name': 'o/r', 'checked_at': None, 'stale': True}], 'repos': []}},
]
write('ap17-answer', S.text('The closure: a series bound (A2 2.0.0 is out), a dep with no version, a dep that is not indexed, a cycle (E, F), an app with its platform.\n'
  '-- The compilers of R-MX16 (5 nightlies, one with 2 rows) and a nightly P with compat rows and no toolchains row. The transition row of N3 names N0, not the adjacent N2.'),
  reqs, resp, [1] * len(reqs),
  'R-AP3 R-AP16 R-AP17 R-AP18 R-AP19 R-AP20 R-AP28 R-AP58 R-AP59 R-AP60 R-AP63 R-AP64 R-AP29 R-AP32 R-AP41 R-AP44 R-AP49 R-AP50 R-AP51 R-MX12 R-MX16 R-RE13 R-RE19 R-IK1 R-IK5')

# ---------------- ap41-sixty-groups and ap46-limits ----------------
def big(n_groups, n_hashes, long=False):
    pad = 'x' * 60 if long else ''
    gs = [{'group': f'github.com/owner{i:03d}{pad}/repo{i:03d}/releases/download/{{v}}/', 'series': '1', 'range': '^1.2.3'} for i in range(n_groups)]
    hs = [b58(bytes([0xFF - (i % 200)] * 31 + [i % 256])) for i in range(n_hashes)]
    return {'groups': gs, 'hashes': hs}
b60 = big(60, 60)
want60 = {'artifacts': [], 'releases': [], 'unknown': b60['hashes'], 'log_size': 0}
reqs = [{'method': 'POST', 'path': '/v1/closure', 'json': b60}]
write('ap41-sixty-groups', None, reqs, [{'status': 200, 'headers': HDR, 'json': want60, 'json_len': {'unknown': 60}}], [1],
      'R-AP41 R-AP46 R-AP17 R-AP28 R-AP59')
b300 = big(300, 1000, long=True)
size = len(J(b300))
assert size < 262144, size
toolarge = lambda f, l: {'status': 413, 'problem': {'type': '/errors/too-large', 'title': 'Too large', 'status': 413, 'field': f, 'limit': l}}
over = {'groups': [{'group': 'g' * 900}] * 300, 'hashes': []}
assert len(J(over)) > 262144
reqs = [
  {'method': 'POST', 'path': '/v1/closure', 'json': b300},
  {'method': 'POST', 'path': '/v1/closure', 'json': big(301, 0)},
  {'method': 'POST', 'path': '/v1/closure', 'json': big(0, 1001)},
  {'method': 'POST', 'path': '/v1/closure', 'json': big(301, 1001)},
  {'method': 'POST', 'path': '/v1/closure', 'json': over},
]
resp = [{'status': 200, 'headers': HDR, 'json_len': {'unknown': 1000, 'artifacts': 0, 'releases': 0}}, toolarge('groups', 300), toolarge('hashes', 1000), toolarge('groups', 300), toolarge('body', 262144)]
write('ap46-limits', None, reqs, resp, [1, 0, 0, 0, 0], 'R-AP46 R-AP41 R-AP48 R-AP62 R-AP21')

# ---------------- ap51-bad-requests ----------------
bad = {'status': 400, 'problem': {'type': '/errors/bad-request', 'title': 'Bad request', 'status': 400}}
texts = ['not json', '[]', '{}', '{"groups":[]}', '{"hashes":[]}', '{"groups":{},"hashes":[]}', '{"groups":[{"group":null}],"hashes":[]}', '{"groups":[],"hashes":[1]}',
         J({'groups': [{'group': GA, 'series': '0'}], 'hashes': []}), J({'groups': [{'group': GA, 'range': 'abc'}], 'hashes': []}),
         J({'groups': [], 'hashes': [], 'compilers': {'from': 5}}), J({'groups': [], 'hashes': [], 'compilers': {'to': {}}})]
reqs = [{'method': 'POST', 'path': '/v1/closure', 'headers': {'content-type': 'application/json'}, 'body': t} for t in texts] + [{'method': 'POST', 'path': '/v1/closure', 'headers': {'content-type': 'application/json'}, 'body': ''}]
write('ap51-bad-requests', None, reqs, [bad] * len(reqs), [0] * len(reqs), 'R-AP51 R-AP48 R-AP62 R-AP23 R-AP16 R-AP21')
print('ok', size)
