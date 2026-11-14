import sys
sys.path.insert(0, "/home/george/dev/Karakatiza666/talon/research/slice-246-revert/mutations")
from _m import edit
root = sys.argv[1]
edit(root, "worker/lib/Yank.roc", "seen.repository_id == ids.repository_id or seen.owner_id == ids.owner_id", "seen.repository_id == ids.repository_id and seen.owner_id == ids.owner_id")
