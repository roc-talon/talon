import sys
sys.path.insert(0, "/home/george/dev/Karakatiza666/talon/research/slice-246-revert/mutations")
from _m import edit
root = sys.argv[1]
edit(root, "worker/lib/Yank.roc", "Oidc.claim_is(Forbidden, \"repository_visibility\", claims.repository_visibility, \"public\")?", "Oidc.claim_is(Forbidden, \"repository_visibility\", claims.repository_visibility, \"public\")?\n\t\t\t\tOidc.claim_is(Forbidden, \"ref_type\", claims.ref_type, \"tag\")?")
