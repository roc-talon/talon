import sys
sys.path.insert(0, "/home/george/dev/Karakatiza666/talon/research/slice-246-revert/mutations")
from _m import edit
root = sys.argv[1]
edit(root, "worker/YankRoutes.roc", "COALESCE((SELECT MAX(seq) FROM yanks WHERE release = ?1), 0) + 1", "1")
