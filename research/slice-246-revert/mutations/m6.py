import sys
sys.path.insert(0, "/home/george/dev/Karakatiza666/talon/research/slice-246-revert/mutations")
from _m import edit
root = sys.argv[1]
edit(root, "worker/lib/Yank.roc", "Oidc.claim_is(Forbidden, \"event_name\", claims.event_name, \"workflow_dispatch\")", "Oidc.claim_in(Forbidden, \"event_name\", claims.event_name, [\"workflow_dispatch\", \"release\", \"push\"], \"x\")")
