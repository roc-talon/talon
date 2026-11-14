import sys
sys.path.insert(0, sys.path[0])
from _m import edit
root = sys.argv[1]
for f in ["worker/ReadRoutes.roc", "worker/IngestRoutes.roc", "worker/YankRoutes.roc", "worker/sql/closure/releases.sql"]:
    edit(root, f, "ORDER BY y.seq DESC LIMIT 1) AS yank_reason", "ORDER BY y.seq ASC LIMIT 1) AS yank_reason")
