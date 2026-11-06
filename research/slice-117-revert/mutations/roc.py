# Roc mutations of the reference copy (slice 117). Usage: ROC_MUT=<name> python3 roc.py <worker dir>   (ref.sh: MUTATE_PY=mutations/roc.py ROC_MUT=<name> ./ref.sh w0|w2 ...)
import sys, os
name = os.environ['ROC_MUT']; w = sys.argv[1]
def edit(f, old, new, count=1):
    p = os.path.join(w, f); s = open(p).read()
    if old not in s: sys.exit(f'mutation {name}: "{old[:70]}" is not in {f}')
    open(p, 'w').write(s.replace(old, new, count))
L = 'lib/Login.roc'; R = 'LoginRoutes.roc'
LIMIT = '''			match limit!(req) {
				Ok({}) => {}
				Err(Limited) => return Ok(limited_response())
				Err(Fault(text)) => return Err(Fault(text))
			}
'''
PLIMIT = '''		match limit!(req) {
			Ok({}) => {}
			Err(Limited) => return Ok(limited_response())
			Err(Fault(text)) => return Err(Fault(text))
		}
'''
M = {
  # Q117-8: a new account row has tokens_after = now (a token from before a delete never lives again).
  'tokens-after-zero': lambda: edit(L, 'VALUES (CAST(?1 AS INTEGER), ?2, ?3, ?3, ?3)', 'VALUES (CAST(?1 AS INTEGER), ?2, 0, ?3, ?3)'),
  # R-CT9: a login never changes tokens_after of an existing row (INSERT OR REPLACE writes the whole row).
  'or-replace': lambda: edit(L, 'INSERT INTO contributors (contributor, login, tokens_after, first_time, last_time) VALUES (CAST(?1 AS INTEGER), ?2, ?3, ?3, ?3) ON CONFLICT (contributor) DO UPDATE SET login = excluded.login, last_time = excluded.last_time', 'INSERT OR REPLACE INTO contributors (contributor, login, tokens_after, first_time, last_time) VALUES (CAST(?1 AS INTEGER), ?2, ?3, ?3, ?3)'),
  # R-CT9: the kid of the token is the kid of the key.
  'kid-unchecked': lambda: edit(L, 'if got != kid {', 'if Bool.False {'),
  # Q117-2: iat is in ms (3 decimals), so a login right after a revoke in the same second works.
  'iat-whole-seconds': lambda: edit(L, '"${(ms // 1000).to_str()}.${pad}${frac}"', '"${(ms // 1000).to_str()}.000"'),
  # R-CT9: iat equal to tokens_after is good.
  'revoked-le': lambda: edit(L, 'x.iat_ms < x.tokens_after', 'x.iat_ms <= x.tokens_after'),
  # R-CT7: a revoked token deletes nothing.
  'delete-no-guard': lambda: edit(L, 'AND g.tokens_after > ?2)"\n\t\t[', 'AND g.tokens_after > ?2 + 100000000000)"\n\t\t['),
  # R-CT8 row 3: the totals of two machines: the smaller first_time.
  'totals-first-time-keep': lambda: edit(L, 'first_time = MIN(first_time, excluded.first_time)', 'first_time = first_time'),
  # R-CT10: first = no compat row from before the row (equal time is not before).
  'tracker-first-le': lambda: edit(L, 'AND c.time < p.time)', 'AND c.time <= p.time)'),
  # R-CT11, Q117-9: a token that fails its check does not use the budget (DELETE /v1/contributors/me).
  'limit-before-proof': lambda: edit(R, '\t\t\tv = verified!(jwt_text)?\n' + LIMIT, LIMIT + '\t\t\tv = verified!(jwt_text)?\n'),
  # Q302: the tracker takes last_time from the rows only.
  'totals-last-time-rows-only': lambda: edit(L, 'COALESCE(MAX(l.last_time, t.last_time), l.last_time, t.last_time) AS last_time', 'l.last_time AS last_time'),
  # Q302: the login move keeps the last_time of the account (the incoming is ignored).
  'totals-last-time-keep': lambda: edit(L, 'last_time = MAX(last_time, excluded.last_time)', 'last_time = last_time'),
  # Q302: the login move takes the last_time of the machine (not the larger).
  'totals-last-time-incoming': lambda: edit(L, 'last_time = MAX(last_time, excluded.last_time)', 'last_time = excluded.last_time'),
  # Q301: no leeway for exp and iat.
  'leeway-0': lambda: edit(L, 'leeway_s: 60,', 'leeway_s: 0,'),
  # Q308: the machine form of the delete counts before its id check (a bad id costs a request).
  'limit-before-id': lambda: (edit(R, '\t\tMachine(hex) => {\n' + LIMIT.replace('\t\t\t', '\t\t\t').rstrip('\n') + '\n', '\t\tMachine(hex) => {\n'),
      edit(R, 'delete_me! = |req| match Login.delete_proof(', 'delete_me! = |req| match (match (req.header("authorization"), req.header("talon-contributor")) {\n\t\t(Err(NotFound), Ok(_)) => limit!(req)\n\t\t_ => Ok({})\n\t}) {\n\t\tErr(Limited) => Ok(limited_response())\n\t\tErr(Fault(text)) => Err(Fault(text))\n\t\tOk({}) => delete_me_inner!(req)\n\t}\n\n\tdelete_me_inner! : Request => Try(Response, ReadRoutes.Error)\n\tdelete_me_inner! = |req| match Login.delete_proof(')),
  # R-CT11, Q117-9: the limit comes before the GitHub read.
  'limit-after-github': lambda: (edit(R, PLIMIT + '\t\tuser = fetch_user!(token)?\n', '\t\tuser = fetch_user!(token)?\n' + PLIMIT)),
}
M[name]()
