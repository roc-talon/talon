# Mutation m11-bot-event of the slice 108 reference: the bot accepts push
import sys, os
f = os.path.join(sys.argv[1], "lib/Oidc.roc")
s = open(f).read()
old = '["schedule", "workflow_dispatch"]'
new = '["schedule", "workflow_dispatch", "push"]'
assert old in s, "mutation text not found"
open(f, "w").write(s.replace(old, new, 1))
