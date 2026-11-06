# Writes the W2 case of slice 108b: worker/tests/cases/oidc/tp3-jwt-strict. python3 -I mk_case.py <worker/tests dir>
import json, os, sys, shutil, base64
T = sys.argv[1]
J = lambda o: json.dumps(o, separators=(',', ':'))
b64u = lambda b: base64.urlsafe_b64encode(b).rstrip(b'=').decode()
d = os.path.join(T, 'cases', 'oidc', 'tp3-jwt-strict')
shutil.rmtree(d, ignore_errors=True)
os.makedirs(os.path.join(d, 'expect'))
JWKS = os.path.join('github', 'token.actions.githubusercontent.com', '.well-known', 'jwks')
TAG = '/v1/toolchains/nightly-2026-10-31-f7bef6b'
bot = json.load(open(os.path.join(T, 'oidc', 'claims-bot.json')))
hdr = b64u(J({"typ": "JWT", "alg": "RS256", "kid": "kid-1"}).encode())
pay = b64u(J(bot).encode())
tokens = {
    # The signature part "Zh" is not canonical base64url (D3 of roc-jwt): 401 before any key read.
    "noncanonical": {"raw": f"{hdr}.{pay}.Zh"},
    # A token of more than 8192 bytes (the max_token_bytes of roc-jwt, Q108b-1): 401.
    "long": {"base": "bot", "claims": {"pad": "x" * 9000}},
    # An iat in the future: R-TP3 row 3 names exp and nbf only, so it passes.
    "iat_future": {"base": "bot", "claims": {"iat": 1767226600}},
    "bot": {"base": "bot"},
}
P = lambda kind, detail: {"type": f"/errors/{kind}", "detail": detail}
# A good token gets the answer of slice 109 (a recorded tag, seed.sql of oidc/tp7-bot-token-pass): 200 with 1 D1 call.
SRC = os.path.join(T, 'cases', 'oidc', 'tp7-bot-token-pass')
OK = json.loads(open(os.path.join(SRC, 'expect', 'responses.jsonl')).readline())
NOT_JWT = {"status": 401, "problem": P("unauthenticated", "the token is not a valid JWT")}
reqs = [("noncanonical", NOT_JWT), ("long", NOT_JWT), ("iat_future", OK), ("bot", OK)]
w = lambda p, s: (os.makedirs(os.path.dirname(os.path.join(d, p)) or d, exist_ok=True), open(os.path.join(d, p), 'w').write(s))
w('rules', 'R-TP3\nR-PK9\nR-AP21\nR-AP26\n')
shutil.copy(os.path.join(T, 'oidc', 'settings.json'), os.path.join(d, 'settings.json'))
w('tokens.json', json.dumps(tokens, indent=1) + '\n')
w('requests.jsonl', ''.join(J({"method": "PUT", "path": TAG, "token": t}) + '\n' for t, _ in reqs))
w('expect/responses.jsonl', ''.join(J(e) + '\n' for _, e in reqs))
w('expect/d1-calls', ''.join(('1' if e is OK else '0') + '\n' for _, e in reqs))
shutil.copy(os.path.join(SRC, 'seed.sql'), os.path.join(d, 'seed.sql'))
w('expect/github.log', 'GET https://token.actions.githubusercontent.com/.well-known/jwks\n')
w(JWKS, open(os.path.join(T, 'oidc', 'jwks.json')).read())
