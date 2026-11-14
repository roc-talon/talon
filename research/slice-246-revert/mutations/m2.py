import sys
sys.path.insert(0, "/home/george/dev/Karakatiza666/talon/research/slice-246-revert/mutations")
from _m import edit
root = sys.argv[1]
edit(root, "worker/lib/Yank.roc", "Author => Refuse(Problem.new(Forbidden, \"the release is yanked by the operator: only the operator can remove this yank\"))", "Author => Change")
