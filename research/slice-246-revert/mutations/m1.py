import sys
sys.path.insert(0, "/home/george/dev/Karakatiza666/talon/research/slice-246-revert/mutations")
from _m import edit
root = sys.argv[1]
edit(root, "worker/lib/Yank.roc", "Author => 0\n\t\tOperator => 1", "Author => 1\n\t\tOperator => 0")
