# Mutation m6-expired-text of the slice 108b reference: an expired token gets the text of roc-jwt (Jwt.err_to_str), not the text of slice 108
import sys, os, re
f = os.path.join(sys.argv[1], "lib/Oidc.roc")
s = open(f).read()
new, n = re.subn(r'Expired\(e\) => "token claim exp is [^\n]*', 'Expired(_) => Jwt.err_to_str(err)', s, count=1)
assert n == 1, "mutation text not found"
open(f, "w").write(new)
