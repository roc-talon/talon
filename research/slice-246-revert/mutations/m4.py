import sys
sys.path.insert(0, "/home/george/dev/Karakatiza666/talon/research/slice-246-revert/mutations")
from _m import edit
root = sys.argv[1]
edit(root, "worker/YankRoutes.roc", "dropping(IngestRoutes.answer!(session, 200, answered), req, answered)", "IngestRoutes.answer!(session, 200, answered)")
