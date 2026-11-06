# Mutation m2-exp-boundary of the slice 108 reference: exp refused only after exp + 60 s, not at it
import sys, os
f = os.path.join(sys.argv[1], "lib/Oidc.roc")
s = open(f).read()
old = 'ctx.now_ms >= (exp + leeway_s)'
new = 'ctx.now_ms > (exp + leeway_s)'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
