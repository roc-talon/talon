# Test vectors for the slice 108b rows of worker/tests/unit/OidcTest.roc. Computed apart from any Roc code: python3 -I vectors.py
import base64, json, importlib.util, sys, os
def b64u(b): return base64.urlsafe_b64encode(b).rstrip(b'=').decode()
def j(o): return json.dumps(o, separators=(',', ':'))
here = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(here, '..', '..', 'slice-108-revert', 'vectors', 'jwt_vectors.py')).read()
full = eval(src[src.index('full = {') + 7: src.index('}\nhdr') + 1])
print("AUDLIST", b64u(j({**full, "aud": ["https://registry.example"]}).encode()))
print("EXPFRAC", b64u(j({**full, "exp": 1767225900.5}).encode()))
print("CRIT", b64u(j({"alg": "RS256", "kid": "kid-1", "crit": ["b64"], "b64": False}).encode()))
print("NOTYP", b64u(j({"alg": "RS256", "kid": "kid-1"}).encode()))
# A P-256 point: 32-byte coordinates (any bytes: roc-jwt checks the length only, K2).
print("ECX", b64u(bytes(range(32))), "ECY", b64u(bytes(range(32, 64))))
