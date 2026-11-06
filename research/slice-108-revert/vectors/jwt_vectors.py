# Test vectors for worker/tests/unit/OidcTest.roc (slice 108). Computed apart from any Roc code: python3 jwt_vectors.py
import base64, json
def b64u(b): return base64.urlsafe_b64encode(b).rstrip(b'=').decode()
def j(o): return json.dumps(o, separators=(',', ':'))
full = {
  "jti":"j-1","sub":"repo:roc-talon/talon:ref:refs/heads/main","aud":"https://registry.example",
  "ref":"refs/heads/main","sha":"abc","repository":"roc-talon/talon","repository_owner":"roc-talon",
  "repository_owner_id":"700001","run_id":"42","run_number":"7","run_attempt":"1","repository_visibility":"public",
  "repository_id":"900001","actor_id":"500001","actor":"bot","workflow":"compat-bot","head_ref":"","base_ref":"",
  "event_name":"schedule","ref_type":"branch","workflow_ref":"roc-talon/talon/.github/workflows/compat-bot.yml@refs/heads/main",
  "workflow_sha":"abc","job_workflow_ref":"roc-talon/talon/.github/workflows/compat-bot.yml@refs/heads/main",
  "job_workflow_sha":"abc","runner_environment":"github-hosted","iss":"https://token.actions.githubusercontent.com",
  "nbf":1767225300,"exp":1767225900,"iat":1767225600}
hdr = {"alg":"RS256","kid":"kid-1","typ":"JWT","x5t":"zz"}
print("HDR", b64u(j(hdr).encode()))
print("FULL", b64u(j(full).encode()))
print("MIN", b64u(j({"iss":"https://token.actions.githubusercontent.com","exp":1767225900}).encode()))
print("BADTYPE", b64u(j({**full, "repository_id": 900001}).encode()))
print("HS256", b64u(j({"alg":"HS256","kid":"kid-1"}).encode()))
print("NONE", b64u(j({"alg":"none","kid":"kid-1"}).encode()))
print("NOALG", b64u(j({"kid":"kid-1"}).encode()))
print("NOKID", b64u(j({"alg":"RS256"}).encode()))
print("ARRAY", b64u(b'[1,2]'))
print("NOTJSON", b64u(b'hello'))
print("SIG", b64u(bytes([1,2,3])))
for t in [b'', b'f', b'fo', b'foo', b'foob', b'fooba', b'foobar', bytes([0xfb,0xff,0xbf]), bytes([0,255,128,63,64])]:
    print("B64", repr(b64u(t)), list(t))
