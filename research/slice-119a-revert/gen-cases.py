#!/usr/bin/env python3
"""Writes worker/tests/cases/githubtoken/ (slice 119a). Run from the repo root. The files are plain fixtures; this script only saves the work of copying them.
The expected responses of the old routes come from the old cases (toolchains/pu-new-tag, ingest/pu4-index-kinds, hints/ct12-talon-version), not from the reference."""
import json, os, shutil, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
CASES = os.path.join(ROOT, 'worker', 'tests', 'cases')
OUT = os.path.join(CASES, 'githubtoken')
shutil.rmtree(OUT, ignore_errors=True)

UA = 'ua=talon-registry accept=application/vnd.github+json'
TOKEN_URL = 'https://api.github.com/app/installations/654321/access_tokens'
TAG = 'nightly-2026-10-21-5349569'
REL_URL = f'https://api.github.com/repos/roc-lang/nightlies/releases/tags/{TAG}'
JWKS = 'GET https://token.actions.githubusercontent.com/.well-known/jwks'
TAGS_URL = 'https://api.github.com/repos/roc-talon/talon/tags?per_page=100'
THING = 'https://github.com/acme/roc-thing/releases/download/1.2.0/7XLjywmoYDZJNNrjftyqesb2Vy3sAmsUCi2K4fYH7C2J.tar.zst'

def w(case, rel, text):
    p = os.path.join(OUT, case, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, 'w') as f:
        f.write(text if text.endswith('\n') or rel.startswith('github/') or rel.endswith('.sql') else text + '\n')

def lines(case, rel, ls):
    w(case, rel, ''.join(l + '\n' for l in ls))

def jl(case, rel, objs):
    lines(case, rel, [json.dumps(o, separators=(',', ':')) for o in objs])

def copy(case, rel, src):
    p = os.path.join(OUT, case, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    shutil.copy(os.path.join(CASES, src), p)

def copytree(case, rel, src):
    shutil.copytree(os.path.join(CASES, src), os.path.join(OUT, case, rel), dirs_exist_ok=True)

SETTINGS = {"AUDIENCE": "https://registry.example", "BOT_REPOSITORY_ID": "900001",
            "BOT_WORKFLOW_REF": "roc-talon/talon/.github/workflows/compat-bot.yml@refs/heads/main",
            "CONTRIBUTOR_KEY": "test-contributor-key"}

def bot_put(now, tok='bot', tag=TAG):
    return {"method": "PUT", "path": f"/v1/toolchains/{tag}", "token": tok, "now": now}

def hint(now, nightly='nightly-2026-10-29-aaaaaaa', version='0.4.1'):
    body = json.dumps({"talon_version": version, "rows": [{"hash": "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2", "nightly": nightly, "target": "any", "result": "pass"}]}, separators=(',', ':'))
    return {"method": "POST", "path": "/v1/compat", "headers": {"content-type": "application/json", "talon-contributor": "0123456789abcdef0123456789abcdef"}, "body": body, "now": now}

def ingest(now):
    return {"method": "POST", "path": "/v1/releases", "json": {"url": THING}, "now": now}

def fixtures_toolchain(case, tags=(TAG,)):
    for t in tags:
        copy(case, f'github/api.github.com/repos/roc-lang/nightlies/releases/tags/{t}', f'toolchains/pu-new-tag/github/api.github.com/repos/roc-lang/nightlies/releases/tags/{TAG}')
    copy(case, 'github/token.actions.githubusercontent.com/.well-known/jwks', 'toolchains/pu-new-tag/github/token.actions.githubusercontent.com/.well-known/jwks')

def fixtures_ingest(case):
    base = 'ingest/pu4-index-kinds/github/'
    for rel in ['api.github.com/repos/acme/roc-thing/%2F', 'api.github.com/repos/acme/roc-thing/releases/tags/1.2.0',
                'github.com/acme/roc-thing/releases/download/1.2.0/7XLjywmoYDZJNNrjftyqesb2Vy3sAmsUCi2K4fYH7C2J.tar.zst',
                'raw.githubusercontent.com/acme/roc-thing/1.2.0/.roc-version']:
        copy(case, 'github/' + rel, base + rel)

def fixtures_hint(case):
    copy(case, 'github/api.github.com/repos/roc-talon/talon/tags%3Fper_page=100', 'hints/ct12-talon-version/github/api.github.com/repos/roc-talon/talon/tags%3Fper_page=100')
    copy(case, 'seed.sql', 'hints/ct12-talon-version/seed.sql')

HINT_OK = {"status": 201, "headers": {"content-type": "application/json", "cache-control": "no-store"}, "body": "{\"written\":1,\"first\":1,\"skipped\":[]}"}
PUT_201 = {"status": 201, "headers": {"content-type": "application/json", "cache-control": "no-store"}, "json_len": {"toolchains": 5}}
PUT_200 = {"status": 200, "headers": {"content-type": "application/json", "cache-control": "no-store"}, "json_len": {"toolchains": 5}}
INGEST_201 = {"status": 201, "headers": {"content-type": "application/json"}, "headers_set": ["talon-bookmark", "location"], "json_at": {"release.hash": "7XLjywmoYDZJNNrjftyqesb2Vy3sAmsUCi2K4fYH7C2J", "release.tag": "1.2.0", "release.repo": "acme/roc-thing"}}
def up(detail): return {"status": 502, "problem": {"type": "/errors/upstream", "status": 502, "detail": detail}}
INTERNAL = {"status": 500, "problem": {"type": "/errors/internal", "status": 500, "detail": "the Worker failed to handle the request"}}
TOKENS = {"bot": {"base": "bot", "claims": {"exp": 1767240000}}}

# ---- A: the three routes of slices 109, 112 and 116a, one token for all ----
a = 'pu25-three-routes'
w(a, 'rules', 'R-PU25 R-CT12 R-WH14 R-AP57 R-AP68 R-AP9 R-AP10')
w(a, 'settings.json', json.dumps(SETTINGS))
w(a, 'tokens.json', json.dumps({"bot": {"base": "bot"}}, indent=1))
jl(a, 'requests.jsonl', [bot_put(1767225630000), ingest(1767225635000), hint(1767225640000)])
jl(a, 'expect/responses.jsonl', [PUT_201, INGEST_201, HINT_OK])
fixtures_toolchain(a); fixtures_ingest(a); fixtures_hint(a)
lines(a, 'expect/github.log', [JWKS, 'GET ' + REL_URL, 'GET https://api.github.com/repos/acme/roc-thing', 'GET https://api.github.com/repos/acme/roc-thing/releases/tags/1.2.0',
                               'GET ' + THING, 'GET https://raw.githubusercontent.com/acme/roc-thing/1.2.0/.roc-version', 'GET ' + TAGS_URL])
lines(a, 'expect/tokens.log', [f'POST {TOKEN_URL} now=1767225630 {UA}'])
lines(a, 'expect/auth.log', [f'GET {u} token=1 {UA}' for u in [REL_URL, 'https://api.github.com/repos/acme/roc-thing', 'https://api.github.com/repos/acme/roc-thing/releases/tags/1.2.0', TAGS_URL]])
w(a, 'expect/db.tsv', "@ SELECT hex(substr(n.value, 1, 1)) AS h, CAST(c.contributor AS TEXT) AS contributor, c.nightly, c.target, c.result, CAST(c.talon_version AS TEXT) AS talon_version, c.time FROM contributions c JOIN names n ON n.id = c.artifact ORDER BY n.value, c.contributor, c.nightly, c.target\n11\t-6890997442180345381\t5571556846250\t0\t0\t17180000255\t1767225640000\n")

# ---- B: the token is kept until 5 min before its end ----
b = 'pu25-token-kept'
w(b, 'rules', 'R-PU25 R-WH14 R-AP57')
w(b, 'settings.json', json.dumps(SETTINGS))
w(b, 'tokens.json', json.dumps(TOKENS, indent=1))
# A tag that has rows is answered with no GitHub read (R-PU9), so each request has its own tag.
BTAGS = [TAG, 'nightly-2026-10-22-aaaaaaa', 'nightly-2026-10-23-bbbbbbb', 'nightly-2026-10-24-ccccccc', 'nightly-2026-10-25-ddddddd']
RURL = lambda t: f'https://api.github.com/repos/roc-lang/nightlies/releases/tags/{t}'
fixtures_toolchain(b, BTAGS)
T0 = 1767225600
times = [T0 + 30, T0 + 54 * 60, T0 + 56 * 60, T0 + 86 * 60, T0 + 112 * 60]
jl(b, 'requests.jsonl', [bot_put(t * 1000, tag=g) for t, g in zip(times, BTAGS)])
jl(b, 'expect/responses.jsonl', [PUT_201] * 5)
# Token 1 is issued at T0+30 s and ends at T0+3630 s, its 5 min mark is T0+3330 s (55 min 30 s). Request 2 (54 min) keeps it, request 3 (56 min) does not: token 2, ends at T0+3360+3600 s,
# its mark is T0+6660 s (111 min). Request 4 (86 min) keeps it, request 5 (112 min) does not: token 3. The JWKS is read again at request 4 (1 h after the first read, slice 108b).
lines(b, 'expect/github.log', [JWKS, 'GET ' + RURL(BTAGS[0]), 'GET ' + RURL(BTAGS[1]), 'GET ' + RURL(BTAGS[2]), JWKS, 'GET ' + RURL(BTAGS[3]), 'GET ' + RURL(BTAGS[4])])
lines(b, 'expect/tokens.log', [f'POST {TOKEN_URL} now={times[i]} {UA}' for i in (0, 2, 4)])
lines(b, 'expect/auth.log', [f'GET {RURL(g)} token={n} {UA}' for g, n in zip(BTAGS, (1, 1, 2, 2, 3))])

# ---- C: a token request that fails, for each route ----
c = 'pu25-token-faults'
w(c, 'rules', 'R-PU25 R-CT12 R-WH14 R-AP57 R-AP68')
w(c, 'settings.json', json.dumps(SETTINGS))
w(c, 'tokens.json', json.dumps({"bot": {"base": "bot"}}, indent=1))
fixtures_toolchain(c); fixtures_ingest(c); fixtures_hint(c)
tok = 'github/api.github.com/app/installations/654321/access_tokens'
w(c, tok, '{"message":"Bad credentials"}')
w(c, tok + '.meta.json', '{"status":401}')
w(c, tok + '.2', '{"message":"Resource not accessible by integration"}')
w(c, tok + '.2.meta.json', '{"status":403}')
w(c, tok + '.3', '{"hello":"world"}')
w(c, tok + '.3.meta.json', '{"status":201}')
w(c, tok + '.4', '{"message":"Server Error"}')
w(c, tok + '.4.meta.json', '{"status":500}')
w(c, tok + '.5', '{"token":"ghs_test9","expires_at":"2026-01-01T01:00:00Z"}')
w(c, tok + '.5.meta.json', '{"status":201}')
N = 1767225600
rq = [hint((N + 1) * 1000, version='0.4.1'), bot_put((N + 2) * 1000), bot_put((N + 3) * 1000), ingest((N + 4) * 1000), bot_put((N + 5) * 1000), hint((N + 6) * 1000, nightly='nightly-2026-10-30-bbbbbbb')]
jl(c, 'requests.jsonl', rq)
jl(c, 'expect/responses.jsonl', [HINT_OK,
    up('the GitHub installation token request failed with status 403'),
    up('the GitHub installation token answer is not valid'),
    up('the GitHub installation token request failed with status 500'),
    PUT_201, HINT_OK])
lines(c, 'expect/github.log', [JWKS, 'GET ' + REL_URL, 'GET ' + TAGS_URL])
lines(c, 'expect/tokens.log', [f'POST {TOKEN_URL} now={N + i} {UA}' for i in (1, 2, 3, 4, 5)])
lines(c, 'expect/auth.log', [f'GET {REL_URL} token=9 {UA}', f'GET {TAGS_URL} token=9 {UA}'])
# The hint of request 1 gets the key 0 (the token request failed: no tag list, R-CT12, Q178). The hint of request 6 has the tag list: 0.4.1 is the key 17180000255.
w(c, 'expect/db.tsv', "@ SELECT hex(substr(n.value, 1, 1)) AS h, CAST(c.contributor AS TEXT) AS contributor, c.nightly, c.target, c.result, CAST(c.talon_version AS TEXT) AS talon_version, c.time FROM contributions c JOIN names n ON n.id = c.artifact ORDER BY n.value, c.contributor, c.nightly, c.target\n"
  f"11\t-6890997442180345381\t5571556846250\t0\t0\t0\t{(N + 1) * 1000}\n11\t-6890997442180345381\t5571843177403\t0\t0\t17180000255\t{(N + 6) * 1000}\n")

# ---- D: a missing setting ----
d = 'pu25-missing-key'
w(d, 'rules', 'R-WH14 R-PU25 R-CT12')
w(d, 'settings.json', json.dumps({**SETTINGS, "GITHUB_APP_KEY": None}))
w(d, 'tokens.json', json.dumps({"bot": {"base": "bot"}}, indent=1))
fixtures_toolchain(d); fixtures_ingest(d); fixtures_hint(d)
jl(d, 'requests.jsonl', [bot_put(1767225630000), ingest(1767225635000), hint(1767225640000)])
jl(d, 'expect/responses.jsonl', [INTERNAL, INTERNAL, HINT_OK])
lines(d, 'expect/github.log', [JWKS])
w(d, 'expect/tokens.log', '')
w(d, 'expect/auth.log', '')
w(d, 'expect/db.tsv', "@ SELECT hex(substr(n.value, 1, 1)) AS h, CAST(c.contributor AS TEXT) AS contributor, c.nightly, c.target, c.result, CAST(c.talon_version AS TEXT) AS talon_version, c.time FROM contributions c JOIN names n ON n.id = c.artifact ORDER BY n.value, c.contributor, c.nightly, c.target\n11\t-6890997442180345381\t5571556846250\t0\t0\t0\t1767225640000\n")
print('ok')
