# Applies the route lines of slices 115a and 115b to a copy of worker/ (reference only): `decide` gets the compat routes.
import sys
p = sys.argv[1] + '/lib/Route.roc'
s = open(p).read()
s = s.replace('decide_closure : Route.Input, Str -> Route.Decision', 'decide_closure : Route.Input, Str, Route.Id -> Route.Decision')
s = s.replace('decide_closure = |input, path| {', 'decide_closure = |input, path, id| {')
s = s.replace('Handle(PostClosure)', 'Handle(id)')
s = s.replace('["v1", "closure"] => decide_closure(input, path)', '["v1", "closure"] => decide_closure(input, path, PostClosure)\n\t\t\t["v1", "compat"] => decide_closure(input, path, PostCompat)\n\t\t\t["v1", "sweeps", tag] => decide_get(input, path, GetSweep(tag))\n\t\t\t["v1", "compat_hints"] => decide_get(input, path, GetCompatHints)\n\t\t\t["v1", "artifacts", hash, "compat"] => decide_get(input, path, GetArtifactCompat(hash))')
open(p, 'w').write(s)
p = sys.argv[1] + '/lib/main.roc'
s = open(p).read()
if 'Nullable' not in s:
    s = s.replace('Compat, CompatReads,', 'Compat, CompatReads, Nullable,', 1)
open(p, 'w').write(s)
