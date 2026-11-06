# Mutation m10-seconds-not-ms of the slice 109 reference
import sys, os
f = os.path.join(sys.argv[1], 'lib/Toolchains.roc')
s = open(f).read()
old = 'Ok(((days * 86400 + h * 3600 + mi * 60 + s) * 1000))'
new = 'Ok(days * 86400 + h * 3600 + mi * 60 + s)'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
