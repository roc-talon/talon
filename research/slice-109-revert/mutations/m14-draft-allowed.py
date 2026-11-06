# Mutation m14-draft-allowed of the slice 109 reference
import sys, os
f = os.path.join(sys.argv[1], 'lib/Toolchains.roc')
s = open(f).read()
old = 'if (release.draft or release.prerelease) {'
new = 'if (release.prerelease) {'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
