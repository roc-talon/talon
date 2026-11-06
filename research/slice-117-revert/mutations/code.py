# TW12 revert check of the real code of slice 117 (worker/lib/Login.roc, worker/LoginRoutes.roc, worker/lib/Client.roc). The mutations edit the BUILD COPY only (ref.sh with NOREF=1), never worker/.
# Usage: NOREF=1 ROC_MUT=<name> MUTATE_PY=mutations/code.py ./ref.sh all account
import sys, os
name = os.environ['ROC_MUT']; w = sys.argv[1]
def edit(f, old, new):
    p = os.path.join(w, f); s = open(p).read()
    if s.count(old) != 1: sys.exit(f'mutation {name}: "{old[:70]}" occurs {s.count(old)} times in {f}')
    open(p, 'w').write(s.replace(old, new, 1))
L = 'lib/Login.roc'; R = 'LoginRoutes.roc'
LIMIT = '''		match limit!(req)? {
			Limited => return Ok(limited_response())
			Pass => {}
		}
'''
M = {
  'none': lambda: None,
  # Q301: exp and iat have a leeway of 60 s.
  'leeway-0': lambda: edit(L, 'leeway_s: 60,', 'leeway_s: 0,'),
  # R-CT9: iat equal to tokens_after is good (compare in ms).
  'revoked-le': lambda: edit(L, 'x.iat_ms < x.tokens_after', 'x.iat_ms <= x.tokens_after'),
  # Q307: a new account row has tokens_after = now.
  'tokens-after-zero': lambda: edit(L, '"VALUES (CAST(?1 AS INTEGER), ?2, ?3, ?3, ?3)",', '"VALUES (CAST(?1 AS INTEGER), ?2, 0, ?3, ?3)",'),
  # Q307: a later login never changes tokens_after.
  'login-resets-tokens-after': lambda: edit(L, 'DO UPDATE SET login = excluded.login, last_time', 'DO UPDATE SET login = excluded.login, tokens_after = excluded.tokens_after, last_time'),
  # Q302: the login move takes the larger last_time.
  'move-last-time-keep': lambda: edit(L, 'last_time = MAX(contributor_totals.last_time, excluded.last_time)', 'last_time = contributor_totals.last_time'),
  # Q302: the tracker takes the larger of the rows and the totals.
  'tracker-last-time-rows-only': lambda: edit(L, 'COALESCE(MAX(agg.last_time, t.last_time), agg.last_time, t.last_time) AS last_time', 'agg.last_time AS last_time'),
  # Q304: only GitHub 401 is "the token is refused"; 403 and 429 are 502.
  'github-403-refused': lambda: edit(L, 'if status == 401 {', 'if status == 401 or status == 403 or status == 429 {'),
  # Q308: the account form of the delete checks the token before the limit.
  'limit-before-proof': lambda: edit(R, '\t\tproof = proof!(token)?\n' + LIMIT, LIMIT + '\t\tproof = proof!(token)?\n'),
  # Q300: the kid of the token is the kid of TOKEN_KEY.
  'kid-unchecked': lambda: edit(L, 'Ok(found) if found != kid =>', 'Ok(found) if Bool.False =>'),
  # Q182: DELETE /v1/contributors/me is a write route (MIN_TLN_WRITE).
  'is-write-no-deleteme': lambda: edit('lib/Client.roc', 'PostTokens | DeleteTokens | DeleteMe => Bool.True', 'PostTokens | DeleteTokens => Bool.True'),
}
M[name]()
