# Writes the W2 cases of slice 108 (worker/tests/cases/oidc/). Run once by the test agent: python3 -I mk_cases.py <worker/tests dir>. The case files are the source of truth after that.
import json, os, sys, shutil
T = sys.argv[1]
J = lambda o: json.dumps(o, separators=(',', ':'))
JWKS_URL = 'https://token.actions.githubusercontent.com/.well-known/jwks'
JWKS = os.path.join('github', 'token.actions.githubusercontent.com', '.well-known', 'jwks')
TAG = '/v1/toolchains/nightly-2026-10-31-f7bef6b'
P = lambda kind, detail: {"type": f"/errors/{kind}", "detail": detail}
INTERNAL = {"status": 500, "problem": P("internal", "the Worker failed to handle the request")}
def u(detail): return {"status": 401, "problem": P("unauthenticated", detail)}
def f(detail): return {"status": 403, "problem": P("forbidden", detail)}
def up(detail): return {"status": 502, "problem": P("upstream", detail)}

def case(name, rules, tokens, reqs, gets, jwks=None, extra_files=None):
    d = os.path.join(T, 'cases', 'oidc', name)
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(os.path.join(d, 'expect'))
    w = lambda p, s: (os.makedirs(os.path.dirname(os.path.join(d, p)), exist_ok=True), open(os.path.join(d, p), 'w').write(s))
    w('rules', '\n'.join(rules) + '\n')
    shutil.copy(os.path.join(T, 'oidc', 'settings.json'), os.path.join(d, 'settings.json'))
    if tokens: w('tokens.json', json.dumps(tokens, indent=1) + '\n')
    w('requests.jsonl', ''.join(J(r) + '\n' for r, _ in reqs))
    w('expect/responses.jsonl', ''.join(J(e) + '\n' for _, e in reqs))
    w('expect/d1-calls', '0\n' * len(reqs))
    if gets: w('expect/github.log', f'GET {JWKS_URL}\n' * gets)
    if jwks is not False: w(JWKS, open(os.path.join(T, 'oidc', 'jwks.json')).read())
    for p, s in (extra_files or {}).items(): w(p, s)

put = lambda tok=None, **kw: {"method": "PUT", "path": TAG, **({"token": tok} if tok else {}), **kw}

# 1. A good bot token passes the check (the stub handler of the route then gives 500 until slice 109). The JWKS is read once (Memo).
case('tp7-bot-token-pass', ['R-TP3', 'R-TP7', 'R-AP6', 'R-AP21', 'R-AP26', 'R-AP48', 'R-AP41', 'R-MX15'],
     {"bot": {"base": "bot"}, "dispatch": {"base": "bot", "claims": {"event_name": "workflow_dispatch"}}},
     [(put('bot'), INTERNAL),
      (put('dispatch'), INTERNAL),
      (put(), u("the request has no Authorization header: this route needs a GitHub OIDC token")),
      ({"method": "GET", "path": TAG, "token": "bot"}, {"status": 405, "headers": {"allow": "PUT"}, "problem": P("method-not-allowed", f"GET is not allowed on {TAG}")}),
      (put('bot'), INTERNAL)],
     gets=1)

# 2. A bad form is refused before any JWKS read: no outbound request.
case('tp3-token-form', ['R-TP3', 'R-AP26', 'R-AP21'],
     {"hs256": {"base": "bot", "alg": "HS256"}, "none": {"base": "bot", "alg": "none"}, "noalg": {"base": "bot", "alg": None},
      "nokid": {"base": "bot", "kid": None}, "two": {"raw": "abc.def"}, "array": {"raw": "WzEsMl0.WzEsMl0.AQID"}},
     [(put(headers={"authorization": "Basic dXNlcjpwYXNz"}), u('the Authorization header must be "Bearer <token>"')),
      (put(headers={"authorization": "Bearer "}), u('the Authorization header must be "Bearer <token>"')),
      (put('two'), u("the token is not a valid JWT")),
      (put('array'), u("the token is not a valid JWT")),
      (put('hs256'), u('the token alg is "HS256", expected "RS256"')),
      (put('none'), u('the token alg is "none", expected "RS256"')),
      (put('noalg'), u("the token alg is missing")),
      (put('nokid'), u("the token kid is missing"))],
     gets=0, jwks=False)

# 3. Signatures, and a kid that is not in the JWKS (Q108-1, R-TP16): a read again only when the kept copy is older than 60 s, else 401 at once.
T0 = 1767225600000
case('tp3-signature-and-kid', ['R-TP3', 'R-TP16', 'R-AP21'],
     {"sig": {"base": "bot", "tamper": "signature"}, "payload": {"base": "bot", "tamper": "payload"},
      "k2": {"base": "bot", "key": "k2"}, "kid9": {"base": "bot", "kid": "kid-9"}, "bot": {"base": "bot"}},
     [(put('sig'), u("the token signature is not valid")),
      (put('payload'), u("the token signature is not valid")),
      (put('k2'), u("the token signature is not valid")),
      (put('kid9'), u('the token kid "kid-9" is not in the GitHub JWKS')),
      (put('bot'), INTERNAL),
      (put('kid9', now=T0 + 60000), u('the token kid "kid-9" is not in the GitHub JWKS')),
      (put('kid9', now=T0 + 60001), u('the token kid "kid-9" is not in the GitHub JWKS')),
      (put('kid9', now=T0 + 60002), u('the token kid "kid-9" is not in the GitHub JWKS')),
      (put('bot', now=T0 + 60002), INTERNAL)],
     gets=2)

# 4. Key rotation: GitHub adds kid-2. Within 60 s of the read, kid-2 gets 401 with no read. After 60 s, one read, and kid-2 passes.
case('tp3-key-rotation', ['R-TP3', 'R-TP16'],
     {"k1": {"base": "bot"}, "k2": {"base": "bot", "key": "k2", "kid": "kid-2"}},
     [(put('k1'), INTERNAL),
      (put('k2', now=T0 + 30000), u('the token kid "kid-2" is not in the GitHub JWKS')),
      (put('k2', now=T0 + 60001), INTERNAL),
      (put('k2', now=T0 + 60002), INTERNAL),
      (put('k1', now=T0 + 60002), INTERNAL)],
     gets=2,
     extra_files={JWKS + '.2': J({"keys": [{"$key": "k1", "kid": "kid-1", "alg": "RS256", "use": "sig"}, {"$key": "k2", "kid": "kid-2", "alg": "RS256", "use": "sig"}]}) + '\n'})

# 4b. Max age (Q108-2, R-TP16): the kept JWKS is used up to 1 h after its read (case clock), then read again, also for a known kid.
#     A known kid-1 at 1 h + 1 ms reads again. The second JWKS has only kid-2, so that kid-1 token gets 401 (the new copy is 0 ms old, no second read),
#     and a kid-2 token then passes with no read.
late = {"nbf": 1767228600, "exp": 1767229500}
case('tp3-jwks-max-age', ['R-TP3', 'R-TP16'],
     {"early": {"base": "bot"}, "late1": {"base": "bot", "claims": late}, "late2": {"base": "bot", "claims": late, "key": "k2", "kid": "kid-2"}},
     [(put('early'), INTERNAL),
      (put('late1', now=T0 + 3600000), INTERNAL),
      (put('late1', now=T0 + 3600001), u('the token kid "kid-1" is not in the GitHub JWKS')),
      (put('late2', now=T0 + 3600002), INTERNAL)],
     gets=2,
     extra_files={JWKS + '.2': J({"keys": [{"$key": "k2", "kid": "kid-2", "alg": "RS256", "use": "sig"}]}) + '\n'})

# 5. The claim rows: R-TP3 rows 1 to 3 (401) and R-TP7 (403). The time of a request is `now` (ms). exp 1767225900, nbf 1767225300, leeway 60 s.
case('tp3-tp7-claims', ['R-TP3', 'R-TP7', 'R-MX5', 'R-AP21'],
     {"bot": {"base": "bot"},
      "iss": {"base": "bot", "claims": {"iss": "https://token.actions.githubusercontent.com/"}},
      "aud_slash": {"base": "bot", "claims": {"aud": "https://registry.example/"}},
      "aud_other": {"base": "bot", "claims": {"aud": "https://other.example"}},
      "no_aud": {"base": "bot", "claims": {"aud": None}},
      "repo_id": {"base": "bot", "claims": {"repository_id": "900002"}},
      "branch": {"base": "bot", "claims": {"workflow_ref": "roc-talon/talon/.github/workflows/compat-bot.yml@refs/heads/feature"}},
      "push": {"base": "bot", "claims": {"event_name": "push"}},
      "publish": {"base": "publish"}},
     [(put('iss'), u('token claim iss is "https://token.actions.githubusercontent.com/", expected "https://token.actions.githubusercontent.com"')),
      (put('aud_slash'), u('token claim aud is "https://registry.example/", expected "https://registry.example"')),
      (put('aud_other'), u('token claim aud is "https://other.example", expected "https://registry.example"')),
      (put('no_aud'), u("token claim aud is missing")),
      (put('bot', now=1767225959999), INTERNAL),
      (put('bot', now=1767225960000), u("token claim exp is 1767225900: the token expired (now is 1767225960, leeway 60 s)")),
      (put('bot', now=1767225240000), INTERNAL),
      (put('bot', now=1767225239999), u("token claim nbf is 1767225300: the token is not valid yet (now is 1767225239, leeway 60 s)")),
      (put('repo_id'), f('token claim repository_id is "900002", expected "900001"')),
      (put('branch'), f('token claim workflow_ref is "roc-talon/talon/.github/workflows/compat-bot.yml@refs/heads/feature", expected "roc-talon/talon/.github/workflows/compat-bot.yml@refs/heads/main"')),
      (put('push'), f('token claim event_name is "push", expected "schedule" or "workflow_dispatch"')),
      (put('publish'), f('token claim repository_id is "812345", expected "900001"'))],
     gets=1)

# 6. A JWKS read that fails is 502 and is not kept: status 500, then a body that is not JSON, then a good JWKS.
case('tp3-jwks-upstream', ['R-TP3', 'R-AP21'],
     {"bot": {"base": "bot"}},
     [(put('bot'), up("the GitHub JWKS read failed with status 500")),
      (put('bot'), up("the GitHub JWKS is not a valid JWKS")),
      (put('bot'), up("the GitHub JWKS is not a valid JWKS")),
      (put('bot'), INTERNAL),
      (put('bot'), INTERNAL)],
     gets=4,
     extra_files={JWKS + '.meta.json': J({"status": 500}) + '\n', JWKS + '.2': 'not json\n', JWKS + '.3': J({"keys": 1}) + '\n',
                  JWKS + '.4': open(os.path.join(T, 'oidc', 'jwks.json')).read()})
