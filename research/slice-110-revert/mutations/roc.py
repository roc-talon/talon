# Roc mutations of the private reference (slice 110). Usage: MUTATE_PY=mutations/roc.py ROC_MUT=<name> ref.sh ...
import os, sys
w = sys.argv[1]; name = os.environ['ROC_MUT']
M = {
  'no-held-hash': ('lib/ClosureQuery.roc', 'query.hash_texts.contains(release.hash) or ', ''),
  'digest-empty': ('lib/ClosureQuery.roc', 'error_digest: r.error_digest.map_err(|_| None)', 'error_digest: Ok(r.error_digest ?? "")'),
  'tag-400': ('lib/ClosureQuery.roc', 'Err(_) => Ok(Err(None))', 'Err(_) => Err(bad("the compiler ${tag} is not a nightly tag"))'),
  'no-range-filter': ('lib/ClosureQuery.roc', 'series_ok and range_ok', 'series_ok'),
  'unknown-no-dedupe': ('lib/ClosureQuery.roc', 'if is_unknown and !$out.contains(text) {', 'if is_unknown {'),
  'limits-after-parse': ('lib/ClosureQuery.roc', '		if req.groups.len() > group_limit {', '		_ = req.groups.map_try(group_item)?\n		if req.groups.len() > group_limit {'),
  'two-calls': ('ClosureRoute.roc', 'results = session.batch!(stmts)', '_ = session.batch!(stmts.take_first(1)).map_err(|e| Fault(Str.inspect(e)))?\n		results = session.batch!(stmts)'),
}
f, a, b = M[name]; p = os.path.join(w, f); s = open(p).read(); assert a in s, name
open(p, 'w').write(s.replace(a, b, 1))
