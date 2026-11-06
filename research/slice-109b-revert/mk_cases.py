# Writes the W2 cases of slices 109 and 109b (worker/tests/cases/toolchains/): 109b adds `size` (Design Q340, R-AP80). It does not touch other areas (the seeds of other areas: research/slice-109b-revert/fix_seeds.py).
# Run once by the test agent: python3 -I mk_cases.py <repo root>. The case files are the source of truth after that.
# The expected bodies, the nightly ids, the times and the ETags are computed here with python (datetime, hashlib), not with Roc.
import json, os, sys, shutil, datetime, hashlib, re
ROOT = sys.argv[1]
T = os.path.join(ROOT, 'worker', 'tests')
J = lambda o: json.dumps(o, separators=(',', ':'))
JWKS_URL = 'https://token.actions.githubusercontent.com/.well-known/jwks'
JWKS = os.path.join('github', 'token.actions.githubusercontent.com', '.well-known', 'jwks')
API = 'https://api.github.com/repos/roc-lang/nightlies/releases/tags/'
NOW = 1767225600000
TARGETS = ["linux_arm64", "linux_x86_64", "macos_apple_silicon", "macos_x86_64", "windows_arm64", "windows_x86_64"]
MONTHS = {m: i + 1 for i, m in enumerate('January February March April May June July August September October November December'.split())}

def P(kind, detail): return {"type": f"/errors/{kind}", "detail": detail}
def ms(s): return int(datetime.datetime.strptime(s, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=datetime.timezone.utc).timestamp()) * 1000
def nid(tag):
    _, y, m, d, sha = tag.split('-')
    m = MONTHS[m] if m in MONTHS else int(m)
    return (datetime.date(int(y), m, int(d)) - datetime.date(1970, 1, 1)).days * 2**28 + int(sha, 16)

# The real releases of roc-lang/nightlies (the answer of 2026-10-22, trimmed): tag -> {published_at, assets: [(name, digest)]}.
REAL = {}
for f in ('list-page1', 'list-page2'):
    for r in json.load(open(os.path.join(ROOT, 'tests', 'fixtures', 'nightlies', f + '.json'))):
        REAL[r['tag_name']] = {'published_at': r['published_at'], 'assets': [(a['name'], a.get('digest'), a['size']) for a in r['assets']]}

MISSING = object()

def norm(assets):
    """(name, digest) gets the size 1000 + its position. (name, digest, size): size MISSING leaves the member out, any other value is written as it is."""
    return [a if len(a) == 3 else (a[0], a[1], 1000 + i) for i, a in enumerate(assets)]

def release_json(tag, published, assets, **extra):
    """A GitHub release answer: the members that GitHub sends, with the Worker-irrelevant ones (id, author, html_url, size, content_type)."""
    body = {"id": 1000, "tag_name": tag, "name": tag, "draft": False, "prerelease": False, "published_at": published,
            "html_url": f"https://github.com/roc-lang/nightlies/releases/tag/{tag}", "author": {"login": "github-actions[bot]", "id": 41898282},
            "assets": [{"id": 9000 + i, "name": n, **({} if z is MISSING else {"size": z}), "digest": d, "content_type": "application/x-gtar",
                        "browser_download_url": f"https://github.com/roc-lang/nightlies/releases/download/{tag}/{n}"} for i, (n, d, z) in enumerate(norm(assets))]}
    body.update(extra)
    return json.dumps(body, separators=(',', ':'))

def real_json(tag): return release_json(tag, REAL[tag]['published_at'], REAL[tag]['assets'])

def picked(assets):
    out = []
    for t in TARGETS:
        suf = '.zip' if t.startswith('windows_') else '.tar.gz'
        okd = lambda dg: bool(dg) and re.fullmatch(r'sha256:[0-9a-f]{64}', dg) is not None
        oks = lambda z: isinstance(z, int) and not isinstance(z, bool) and z > 0
        c = [(n, d, z) for n, d, z in norm(assets) if n.startswith(f'roc_nightly-{t}-') and n.endswith(suf) and '/' not in n and '\\' not in n and okd(d) and oks(z)]
        if len(c) == 1: out.append((t, c[0][0], c[0][1][7:], c[0][2]))
    return out

def rows_of(tag, published, assets, first_idx):
    """The wire rows and the db rows a PUT writes."""
    pk = picked(assets)
    rows = [{"tag": tag, "target": t, "asset_name": n, "sha256": h, "size": z, "published_at": ms(published), "log_index": first_idx + i} for i, (t, n, h, z) in enumerate(pk)]
    return rows

def body_put(rows): return '{"toolchains":' + J(rows) + '}'
def body_page(rows, more): return '{"toolchains":' + J(rows) + ',"more":' + ('true' if more else 'false') + '}'
def etag(body): return '"' + hashlib.sha256(body.encode()).hexdigest()[:32] + '"'

def case(name, rules, reqs, *, tokens=True, github=None, d1=None, gh_log=None, db=None, seed=None, extra=None):
    """reqs: list of (request dict, expected dict). github: {url path under api.github.com: (body, status or None)}; the key may end in `.2`."""
    d = os.path.join(T, 'cases', 'toolchains', name)
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(os.path.join(d, 'expect'))
    def w(p, s):
        os.makedirs(os.path.dirname(os.path.join(d, p)), exist_ok=True)
        open(os.path.join(d, p), 'w').write(s)
    w('rules', ' '.join(rules) + '\n')
    w('requests.jsonl', ''.join(J(r) + '\n' for r, _ in reqs))
    w('expect/responses.jsonl', ''.join(J(e) + '\n' for _, e in reqs))
    w('expect/d1-calls', ''.join(f'{n}\n' for n in d1))
    if tokens:
        shutil.copy(os.path.join(T, 'oidc', 'settings.json'), os.path.join(d, 'settings.json'))
        w('tokens.json', json.dumps({"bot": {"base": "bot"}}, indent=1) + '\n')
        w(JWKS, open(os.path.join(T, 'oidc', 'jwks.json')).read())
    for key, (body, status) in (github or {}).items():
        p = os.path.join('github', 'api.github.com', 'repos', 'roc-lang', 'nightlies', 'releases', 'tags', key)
        w(p, body)
        if status: w(p + '.meta.json', J({"status": status}))
    if gh_log: w('expect/github.log', ''.join(f'GET {u}\n' for u in gh_log))
    if db: w('expect/db.tsv', db)
    if seed: w('seed.sql', seed)
    for p, s in (extra or {}).items(): w(p, s)

put = lambda tag, **kw: {"method": "PUT", "path": f"/v1/toolchains/{tag}", "token": "bot", **kw}
get = lambda q='', **kw: {"method": "GET", "path": "/v1/toolchains" + q, **kw}
JSONH = {"content-type": "application/json", "cache-control": "no-store"}
def ok(status, body, headers=JSONH): return {"status": status, "headers": headers, "body": body}

def tsv(rows): return ''.join('\t'.join(str(c) for c in r) + '\n' for r in rows)
def db_blocks(rows, leaves):
    out = '@ SELECT nightly, target, tag, asset_name, sha256, size, published_at, log_index FROM toolchains ORDER BY log_index\n'
    out += tsv([(nid(r['tag']), r['target'], r['tag'], r['asset_name'], r['sha256'], r['size'], r['published_at'], r['log_index']) for r in rows])
    out += '@ SELECT idx, grp, version, hash, time FROM log ORDER BY idx\n'
    out += tsv([(r['log_index'], 'roc-lang/nightlies:' + r['target'], r['tag'], 'sha256:' + r['sha256'], t) for r, t in zip(rows, leaves)])
    return out

# ---- PUT ----

# 1. A new tag (the real release nightly-2026-10-21-5349569): 201 with 5 rows, one batch (2 D1 calls: the read of the tag, the batch), 5 leaves with the time of the write
#    (not published_at). The same tag again: 200, the same body, 1 D1 call and no GitHub read.
tag1 = 'nightly-2026-10-21-5349569'
rows1 = rows_of(tag1, REAL[tag1]['published_at'], REAL[tag1]['assets'], 1)
T1 = NOW + 30000
case('pu-new-tag', ['R-AP80', 'R-AP57', 'R-MX16', 'R-AP6', 'R-PU7', 'R-PU8', 'R-PU9', 'R-SG3', 'R-SG8', 'R-RE4', 'R-IK4', 'R-AP41', 'R-CV1', 'R-CV2', 'R-CV3', 'R-CV8'],
     [(put(tag1, now=T1), ok(201, body_put(rows1))),
      (put(tag1), ok(200, body_put(rows1)))],
     github={tag1: (real_json(tag1), None)}, d1=[2, 1], gh_log=[JWKS_URL, API + tag1],
     db=db_blocks(rows1, [T1] * len(rows1)))

# 2. Releases whose asset names have another date and sha than the tag (R-CV2), one with the month as a name (R-CV1). 6 hosts each (windows_arm64 too).
tag2a, tag2b = 'nightly-2025-October-25-c3487d2', 'nightly-2026-February-10-c95f04d'
rows2a = rows_of(tag2a, REAL[tag2a]['published_at'], REAL[tag2a]['assets'], 1)
rows2b = rows_of(tag2b, REAL[tag2b]['published_at'], REAL[tag2b]['assets'], 1 + len(rows2a))
case('pu-odd-sha-names', ['R-AP80', 'R-MX16', 'R-AP6', 'R-PU8', 'R-PU9', 'R-SG3', 'R-IK4', 'R-CV1', 'R-CV2', 'R-CV3', 'R-CV8'],
     [(put(tag2a), ok(201, body_put(rows2a))),
      (put(tag2b), ok(201, body_put(rows2b)))],
     github={tag2a: (real_json(tag2a), None), tag2b: (real_json(tag2b), None)}, d1=[2, 2], gh_log=[JWKS_URL, API + tag2a, API + tag2b],
     db=db_blocks(rows2a + rows2b, [NOW] * (len(rows2a) + len(rows2b))))

# 3. The asset rules (R-CV2) on one release: one asset for a host gives a row. Two assets for a host, a name with a `/`, and `.tar.gz` for Windows give none.
#    The sha256 comes from `digest`, and the body of the request (a made-up sha256) is not read (R-PU8).
tag3 = 'nightly-2026-10-22-1a2b3c4'
d = lambda c: 'sha256:' + c * 64
assets3 = [
    ('echo.wasm.zst', d('1')), ('playground.wasm', d('2')),
    ('roc_nightly-linux_arm64-2026-10-22-1a2b3c4.tar.gz', d('a')),
    ('roc_nightly-linux_x86_64-2026-10-22-1a2b3c4.tar.gz', d('b')),
    ('roc_nightly-linux_x86_64-2026-10-21-5349569.tar.gz', d('c')),
    ('roc_nightly-macos_apple_silicon-2026-10-22-1a2b3c4.tar.gz', d('d')),
    ('roc_nightly-macos_x86_64-2026-10-22-1/a.tar.gz', d('e')),
    ('roc_nightly-source-2026-10-22-1a2b3c4.tar.gz', d('f')), ('roc_nightly-source-2026-10-22-1a2b3c4.zip', d('0')),
    ('roc_nightly-windows_arm64-2026-10-22-1a2b3c4.zip', d('5')),
    ('roc_nightly-windows_x86_64-2026-10-22-1a2b3c4.tar.gz', d('6')),
]
rows3 = rows_of(tag3, '2026-10-22T15:00:00Z', assets3, 1)
assert [r['target'] for r in rows3] == ['linux_arm64', 'macos_apple_silicon', 'windows_arm64'], rows3
case('pu-asset-rules', ['R-AP80', 'R-AP6', 'R-PU8', 'R-PU9', 'R-CV2', 'R-CV3', 'R-CV8', 'R-SG3'],
     [(put(tag3, headers={"content-type": "application/json"}, json={"sha256": "ff" * 32, "tag": "other"}), ok(201, body_put(rows3)))],
     github={tag3: (release_json(tag3, '2026-10-22T15:00:00Z', assets3), None)}, d1=[2], gh_log=[JWKS_URL, API + tag3],
     db=db_blocks(rows3, [NOW] * 3))

# 4. A later other digest and other sizes keep the recorded row, also its size (R-PU10, R-AP80). The tag has rows: the second PUT reads D1 once, makes no GitHub call, and answers with the recorded rows.
tag4 = 'nightly-2026-09-01-db83307'
rows4 = rows_of(tag4, REAL[tag4]['published_at'], REAL[tag4]['assets'], 1)
changed = [(n, (d('9') if dg and n.startswith('roc_nightly-') else dg), z + 1) for n, dg, z in REAL[tag4]['assets']]
case('pu-digest-kept', ['R-AP80', 'R-AP57', 'R-AP6', 'R-PU9', 'R-PU10', 'R-CV3', 'R-AP41'],
     [(put(tag4), ok(201, body_put(rows4))),
      (put(tag4), ok(200, body_put(rows4)))],
     github={tag4: (real_json(tag4), None), tag4 + '.2': (release_json(tag4, REAL[tag4]['published_at'], changed), None)},
     d1=[2, 1], gh_log=[JWKS_URL, API + tag4], db=db_blocks(rows4, [NOW] * len(rows4)))

# 5. GitHub answers and releases that are not candidates. Nothing is written. Each request makes 1 D1 call (the read of the tag) and 1 GitHub call.
miss = ('{"message":"Not Found","documentation_url":"https://docs.github.com/rest/releases/releases#get-a-release-by-tag-name"}', 404)
src_only = [('roc_nightly-source-2026-10-28-fffffff.tar.gz', d('1')), ('roc_nightly-source-2026-10-28-fffffff.zip', d('2')), ('echo.wasm.zst', d('3')), ('playground.wasm.zst', d('4'))]
g5 = {
    'nightly-2026-10-23-aaaaaaa': miss,
    'nightly-2026-10-24-bbbbbbb': ('{"message":"Server Error"}', 500),
    'nightly-2026-10-25-ccccccc': ('{"message":"API rate limit exceeded for 203.0.113.9.","documentation_url":"https://docs.github.com/rest/overview/rate-limits-for-the-rest-api"}', 403),
    'nightly-2026-10-26-ddddddd': ('this is not json', None),
    'nightly-2026-10-27-eeeeeee': ('{"message":"ok"}', None),
    'nightly-2025-November-03-4215483': (real_json('nightly-2025-November-03-4215483'), None),
    'nightly-2026-10-28-fffffff': (release_json('nightly-2026-10-28-fffffff', '2026-10-28T15:00:00Z', src_only), None),
    'nightly-2026-10-29-1111111': (release_json('nightly-2026-10-29-1111111', '2026-10-29T15:00:00+00:00', [('roc_nightly-linux_arm64-2026-10-29-1111111.tar.gz', 'sha256:' + 'a' * 64)]), None),
}
tags5 = list(g5)
exp5 = [
    {"status": 404, "problem": P('not-found', 'roc-lang/nightlies has no release with the tag nightly-2026-10-23-aaaaaaa')},
    {"status": 502, "problem": P('upstream', 'the GitHub release read failed with status 500')},
    {"status": 502, "problem": P('upstream', 'the GitHub release read failed with status 403')},
    {"status": 502, "problem": P('upstream', 'the GitHub release answer is not a valid release')},
    {"status": 502, "problem": P('upstream', 'the GitHub release answer is not a valid release')},
    {"status": 422, "problem": P('not-a-candidate', 'the release nightly-2025-November-03-4215483 has no compiler asset (roc_nightly-<target>-*.tar.gz, or .zip for Windows)')},
    {"status": 422, "problem": P('not-a-candidate', 'the release nightly-2026-10-28-fffffff has no compiler asset (roc_nightly-<target>-*.tar.gz, or .zip for Windows)')},
    {"status": 502, "problem": P('upstream', 'the GitHub release answer is not a valid release')},
]
case('pu-github-answers', ['R-AP57', 'R-AP6', 'R-AP21', 'R-PU8', 'R-CV2', 'R-AP41'],
     [(put(t), e) for t, e in zip(tags5, exp5)],
     github=g5, d1=[1] * len(tags5), gh_log=[JWKS_URL] + [API + t for t in tags5],
     db='@ SELECT count(*) FROM toolchains\n0\n@ SELECT count(*) FROM log\n0\n')

# 5b. R-AP57 steps 1, 4, 6: a tag with no nightly id (no D1 call, no GitHub call), a draft, a prerelease, and a release whose compiler assets all have a bad digest: 422.
good_assets = lambda t: [(f'roc_nightly-linux_arm64-{t}.tar.gz', d('a')), (f'roc_nightly-macos_x86_64-{t}.tar.gz', d('b')), ('roc_nightly-source-%s.zip' % t, d('c'))]
bad_only = [('roc_nightly-linux_arm64-2026-10-30-4444444.tar.gz', None), ('roc_nightly-linux_x86_64-2026-10-30-4444444.tar.gz', 'sha256:' + 'a' * 63),
            ('roc_nightly-macos_apple_silicon-2026-10-30-4444444.tar.gz', 'sha256:' + 'A' * 64), ('roc_nightly-windows_x86_64-2026-10-30-4444444.zip', 'sha512:' + 'a' * 64)]
nc = lambda tag: {"status": 422, "problem": P('not-a-candidate', f'the tag {tag} is not a nightly tag')}
case('pu-not-candidates', ['R-AP57', 'R-AP6', 'R-AP21', 'R-IK4', 'R-CV1', 'R-CV2', 'R-CV3', 'R-AP41'],
     [(put('nightly-2026-02-30-1234567'), nc('nightly-2026-02-30-1234567')),
      (put('v1.2.3'), nc('v1.2.3')),
      (put('nightly-2026-10-21-ABCDEF0'), nc('nightly-2026-10-21-ABCDEF0')),
      (put('nightly-2026-10-30-2222222'), {"status": 422, "problem": P('not-a-candidate', 'the release nightly-2026-10-30-2222222 is a draft or a prerelease')}),
      (put('nightly-2026-10-30-3333333'), {"status": 422, "problem": P('not-a-candidate', 'the release nightly-2026-10-30-3333333 is a draft or a prerelease')}),
      (put('nightly-2026-10-30-4444444'), {"status": 422, "problem": P('not-a-candidate', 'the release nightly-2026-10-30-4444444 has no compiler asset (roc_nightly-<target>-*.tar.gz, or .zip for Windows)')})],
     github={'nightly-2026-10-30-2222222': (release_json('nightly-2026-10-30-2222222', '2026-10-30T15:00:00Z', good_assets('2026-10-30-2222222'), draft=True), None),
             'nightly-2026-10-30-3333333': (release_json('nightly-2026-10-30-3333333', '2026-10-30T15:00:00Z', good_assets('2026-10-30-3333333'), prerelease=True), None),
             'nightly-2026-10-30-4444444': (release_json('nightly-2026-10-30-4444444', '2026-10-30T15:00:00Z', bad_only), None)},
     d1=[0, 0, 0, 1, 1, 1], gh_log=[JWKS_URL, API + 'nightly-2026-10-30-2222222', API + 'nightly-2026-10-30-3333333', API + 'nightly-2026-10-30-4444444'],
     db='@ SELECT count(*) FROM toolchains\n0\n@ SELECT count(*) FROM log\n0\n')

# 5c. R-AP57 step 6: an asset whose digest is missing, null, or not `sha256:` and 64 lower-case hex digits is not an asset for its host. The other hosts stay.
#     A bad asset does not count for the rule of 2 assets: the host with one bad and one good asset gets the good one.
tag5c = 'nightly-2026-10-31-5555555'
assets5c = [
    ('roc_nightly-linux_arm64-2026-10-31-5555555.tar.gz', None),
    ('roc_nightly-linux_x86_64-2026-10-31-5555555.tar.gz', 'sha256:' + 'a' * 63),
    ('roc_nightly-linux_x86_64-2026-10-30-6666666.tar.gz', d('b')),
    ('roc_nightly-macos_apple_silicon-2026-10-31-5555555.tar.gz', 'sha256:' + 'C' * 64),
    ('roc_nightly-macos_x86_64-2026-10-31-5555555.tar.gz', d('d')),
    ('roc_nightly-windows_arm64-2026-10-31-5555555.zip', 'sha512:' + 'e' * 64),
    ('roc_nightly-windows_x86_64-2026-10-31-5555555.zip', d('f')),
]
rows5c = rows_of(tag5c, '2026-10-31T12:00:00Z', assets5c, 1)
assert [r['target'] for r in rows5c] == ['linux_x86_64', 'macos_x86_64', 'windows_x86_64'], rows5c
case('pu-digest-rules', ['R-AP57', 'R-AP6', 'R-PU8', 'R-PU9', 'R-CV2', 'R-CV3', 'R-SG3'],
     [(put(tag5c), ok(201, body_put(rows5c)))],
     github={tag5c: (release_json(tag5c, '2026-10-31T12:00:00Z', assets5c), None)}, d1=[2], gh_log=[JWKS_URL, API + tag5c],
     db=db_blocks(rows5c, [NOW] * 3))

# 5d. 109b, R-AP80, R-AP57 step 6: an asset whose `size` is missing, `null`, a number with a fraction, 0 or negative is not an asset for its host. The other hosts stay.
#     A bad asset does not count for the rule of 2 assets: the host with one bad and one good asset gets the good one. `size` 1 is good.
#     The second tag has a bad size for each host: 422. `size` is not in the leaf (the `log` rows are the same as before).
tag5d, tag5e = 'nightly-2026-11-01-7777777', 'nightly-2026-11-01-8888888'
assets5d = [
    ('roc_nightly-linux_arm64-2026-11-01-7777777.tar.gz', d('1'), MISSING),
    ('roc_nightly-linux_x86_64-2026-11-01-7777777.tar.gz', d('2'), 0),
    ('roc_nightly-linux_x86_64-2026-10-31-9999999.tar.gz', d('3'), 1),
    ('roc_nightly-macos_apple_silicon-2026-11-01-7777777.tar.gz', d('4'), None),
    ('roc_nightly-macos_x86_64-2026-11-01-7777777.tar.gz', d('5'), 12.5),
    ('roc_nightly-windows_arm64-2026-11-01-7777777.zip', d('6'), -5),
    ('roc_nightly-windows_x86_64-2026-11-01-7777777.zip', d('7'), 70319525),
    ('roc_nightly-source-2026-11-01-7777777.zip', d('8'), 55),
]
rows5d = rows_of(tag5d, '2026-11-01T12:00:00Z', assets5d, 1)
assert [(r['target'], r['size']) for r in rows5d] == [('linux_x86_64', 1), ('windows_x86_64', 70319525)], rows5d
assets5e = [(f'roc_nightly-{t}-2026-11-01-8888888' + ('.zip' if t.startswith('windows') else '.tar.gz'), d('a'), z)
            for t, z in zip(TARGETS, [MISSING, 0, None, 1.5, -1, 0])]
case('pu-size-rules', ['R-AP57', 'R-AP80', 'R-AP6', 'R-AP21', 'R-PU8', 'R-PU9', 'R-RE4', 'R-SG3', 'R-CV2'],
     [(put(tag5d), ok(201, body_put(rows5d))),
      (put(tag5e), {"status": 422, "problem": P('not-a-candidate', f'the release {tag5e} has no compiler asset (roc_nightly-<target>-*.tar.gz, or .zip for Windows)')})],
     github={tag5d: (release_json(tag5d, '2026-11-01T12:00:00Z', assets5d), None), tag5e: (release_json(tag5e, '2026-11-01T12:00:00Z', assets5e), None)},
     d1=[2, 1], gh_log=[JWKS_URL, API + tag5d, API + tag5e], db=db_blocks(rows5d, [NOW] * 2))

# 6. A tag with the id of another recorded tag (R-IK4): the other form of the same nightly. 422, 1 D1 call, no GitHub call. Another sha is another id.
tag6a, tag6b, tag6c = 'nightly-2025-October-25-c3487d2', 'nightly-2025-10-25-c3487d2', 'nightly-2025-10-25-c3487d3'
assert nid(tag6a) == nid(tag6b) != nid(tag6c)
rows6 = rows_of(tag6a, REAL[tag6a]['published_at'], REAL[tag6a]['assets'], 1)
case('pu-id-collision', ['R-AP57', 'R-AP6', 'R-IK4', 'R-AP21', 'R-AP41', 'R-CV1'],
     [(put(tag6a), ok(201, body_put(rows6))),
      (put(tag6b), {"status": 422, "problem": P('not-a-candidate', f'the tag {tag6b} has the same nightly id as the recorded tag {tag6a}')}),
      (put(tag6a), ok(200, body_put(rows6))),
      (put(tag6c), {"status": 404, "problem": P('not-found', f'roc-lang/nightlies has no release with the tag {tag6c}')})],
     github={tag6a: (real_json(tag6a), None), tag6c: miss}, d1=[2, 1, 1, 1], gh_log=[JWKS_URL, API + tag6a, API + tag6c],
     db=db_blocks(rows6, [NOW] * len(rows6)))

# ---- GET ----

TOOL_SQL = """
INSERT INTO log (idx, grp, version, hash, time) VALUES (%s);
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index) VALUES (%s);
"""
def seed_small(rows):
    out = ''
    for r in rows:
        out += "INSERT INTO log (idx, grp, version, hash, time) VALUES (%d, 'roc-lang/nightlies:%s', '%s', 'sha256:%s', 1700000000000);\n" % (r['log_index'], r['target'], r['tag'], r['sha256'])
        out += "INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index) VALUES (%d, '%s', '%s', '%s', '%s', %d, %d, %d);\n" % (nid(r['tag']), r['target'], r['tag'], r['asset_name'], r['sha256'], r['size'], r['published_at'], r['log_index'])
    return out

# 7. The small list: 6 rows of 2 nightlies. The first nightly gets its Windows asset late, so the rows of one tag are not next to each other in the log.
def small_row(tag, target, idx):
    date = '-'.join(tag.split('-')[1:4])
    return {"tag": tag, "target": target, "asset_name": f"roc_nightly-{target}-{date}-{tag.split('-')[4]}" + ('.zip' if target.startswith('windows') else '.tar.gz'),
            "sha256": '%064x' % idx, "size": 1000 + idx, "published_at": ms('%sT15:00:00Z' % date), "log_index": idx}
A, B = 'nightly-2026-10-20-7a8a800', 'nightly-2026-10-21-5349569'
small = [small_row(A, 'linux_arm64', 1), small_row(A, 'linux_x86_64', 2), small_row(B, 'linux_arm64', 3), small_row(A, 'windows_x86_64', 4), small_row(B, 'linux_x86_64', 5), small_row(B, 'windows_x86_64', 6)]
GETH = {"content-type": "application/json", "cache-control": "max-age=300"}
def page(rows, more=False): return {"status": 200, "headers": GETH, "body": body_page(rows, more)}
by = lambda f: [r for r in small if f(r)]
case('get-query', ['R-AP80', 'R-AP5', 'R-AP47', 'R-AP41', 'R-AP44', 'R-AP56', 'R-RE4'],
     [(get(), page(small)),
      (get('?after=0'), page(small)),
      (get('?after=3'), page(small[3:])),
      (get('?after=6'), page([])),
      (get('?after=99'), page([])),
      (get('?target=windows_x86_64'), page(by(lambda r: r['target'] == 'windows_x86_64'))),
      (get('?target=linux_x86_64&after=2'), page(by(lambda r: r['target'] == 'linux_x86_64' and r['log_index'] > 2))),
      (get('?target=macos_x86_64'), page([])),
      (get('?target='), page([])),
      (get('?target=x64musl'), page([])),
      (get('?after=1&target=Linux_x86_64'), page([])),
      (get('?after=1&unknown=1&target=linux_arm64&more=yes'), page(by(lambda r: r['target'] == 'linux_arm64' and r['log_index'] > 1)))],
     d1=[1] * 12, seed=seed_small(small), tokens=False)

# 8. A bad query is 400 before any D1 call (R-AP48 row 6). A method that is not served gets 405 with `Allow: GET`.
def bad(text): return {"status": 400, "problem": P('bad-request', f'the query parameter after must be a log index (decimal digits), got {text}')}
bad_after = ['abc', '-1', '', '1.5', '007', '00', '9223372036854775808', '18446744073709551615', '99999999999999999999']
reqs8 = [(get('?after=' + t), bad(t)) for t in bad_after]
reqs8 += [(get('?target=linux_x86_64&after=x'), bad('x'))]
reqs8 += [({"method": m, "path": "/v1/toolchains"}, {"status": 405, "headers": {"allow": "GET"}, "problem": P('method-not-allowed', f'{m} is not allowed on /v1/toolchains')}) for m in ('POST', 'PUT', 'DELETE')]
case('get-bad-query', ['R-AP5', 'R-AP56', 'R-AP21', 'R-AP41', 'R-AP48'], reqs8, d1=[0] * len(reqs8), tokens=False)

# 9. The ETag, the 304 and the Cache API (R-AP54, R-AP55, Design Q96): the same mechanism as slice 106, with max-age=300. An empty list. The key is the whole URL.
empty = body_page([], False)
e = etag(empty)
inm = lambda v, **h: get(headers={"if-none-match": v, **h})
H200 = {**GETH, "etag": e}
H304 = {"etag": e, "cache-control": "max-age=300", "content-type": None}
r9 = [
    (get(), {"status": 200, "headers": H200, "body": empty}, 1),                                       # miss: D1, then the cache
    (get(), {"status": 200, "headers": H200, "body": empty}, 0),                                       # hit
    (inm(e), {"status": 304, "headers": H304, "body": ""}, 0),
    (inm('"0123456789abcdef0123456789abcdef"'), {"status": 200, "headers": H200, "body": empty}, 0),
    (inm('"nope", W/' + e), {"status": 304, "headers": H304, "body": ""}, 0),                          # weak compare, a list
    (inm('*'), {"status": 304, "headers": H304, "body": ""}, 0),
    (get(headers={"cache-control": "no-cache"}), {"status": 200, "headers": H200, "body": empty}, 1),  # bypass
    (inm(e, **{"cache-control": "No-Cache, max-age=0"}), {"status": 304, "headers": H304, "body": ""}, 1),
    (get('?after=0'), {"status": 200, "headers": H200, "body": empty}, 1),                             # another URL, another key
    (get('?after=0', headers={"cache-control": "max-age=0"}), {"status": 200, "headers": H200, "body": empty}, 0),  # max-age=0 does not bypass
]
case('get-etag-304', ['R-AP5', 'R-AP24', 'R-AP54', 'R-AP55', 'R-AP41'], [(r, x) for r, x, _ in r9], d1=[n for _, _, n in r9], tokens=False)

# 10. 2,500 rows (R-AP47): the pages from after=0 hold each row once, in log index order. The 5 rows of a nightly are 500 rows apart in the log, so a page by nightly
#     would lose or repeat rows at a page end. The edges: exactly 1000 rows left (more false), 1001 rows left (more true), the largest index, a filter.
seed10 = """-- 2,500 rows: log index i, nightly (i - 1) % 500, target block (i - 1) / 500. All text is made from i.
WITH RECURSIVE s(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM s WHERE i < 2500)
INSERT INTO log (idx, grp, version, hash, time)
SELECT i, 'roc-lang/nightlies:' || CASE (i - 1) / 500 WHEN 0 THEN 'linux_arm64' WHEN 1 THEN 'linux_x86_64' WHEN 2 THEN 'macos_apple_silicon' WHEN 3 THEN 'macos_x86_64' ELSE 'windows_x86_64' END,
  printf('nightly-2026-10-21-%07x', (i - 1) % 500), 'sha256:' || printf('%064x', i), 1700000000000 FROM s;
WITH RECURSIVE s(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM s WHERE i < 2500)
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index)
SELECT 20000 * 268435456 + (i - 1) % 500,
  CASE (i - 1) / 500 WHEN 0 THEN 'linux_arm64' WHEN 1 THEN 'linux_x86_64' WHEN 2 THEN 'macos_apple_silicon' WHEN 3 THEN 'macos_x86_64' ELSE 'windows_x86_64' END,
  printf('nightly-2026-10-21-%07x', (i - 1) % 500), 'roc_nightly-seed-' || i || '.tar.gz', printf('%064x', i), 1000 + i, 1700000000000 + ((i - 1) % 500) * 86400000, i FROM s;
"""
def pg(a, b, more, **extra):
    r = {"status": 200, "headers": GETH, "json_len": {"toolchains": b - a + 1 if b >= a else 0}, "json_at": {"more": more}}
    if b >= a: r["json_range"] = {"path": "toolchains", "field": "log_index", "from": a, "to": b}
    r["json_at"].update(extra)
    return r
first_row = {"toolchains.0.tag": "nightly-2026-10-21-0000000", "toolchains.0.target": "linux_arm64", "toolchains.0.asset_name": "roc_nightly-seed-1.tar.gz",
             "toolchains.0.sha256": '%064x' % 1, "toolchains.0.size": 1001, "toolchains.0.published_at": 1700000000000, "toolchains.0.log_index": 1, "toolchains.999.log_index": 1000}
reqs10 = [
    (get(), pg(1, 1000, True, **first_row)),
    (get('?after=1000'), pg(1001, 2000, True)),
    (get('?after=2000'), pg(2001, 2500, False)),
    (get('?after=2500'), pg(1, 0, False)),
    (get('?after=1500'), pg(1501, 2500, False)),
    (get('?after=1499'), pg(1500, 2499, True)),
    (get('?after=0&target=linux_arm64&unknown=1'), pg(1, 500, False)),
    (get('?after=499&target=macos_apple_silicon'), pg(1001, 1500, False)),
]
case('get-pages', ['R-AP80', 'R-AP5', 'R-AP47', 'R-AP41', 'R-AP44'], reqs10, d1=[1] * len(reqs10), seed=seed10, tokens=False)

print('ok')
