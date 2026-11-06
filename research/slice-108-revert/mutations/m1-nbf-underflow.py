# Mutation m1-nbf-underflow of the slice 108 reference: no guard for nbf < 60 (U64 underflow)
import sys, os
f = os.path.join(sys.argv[1], "lib/Oidc.roc")
s = open(f).read()
old = 'if nbf > leeway_s and ctx.now_ms'
new = 'if ctx.now_ms'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
