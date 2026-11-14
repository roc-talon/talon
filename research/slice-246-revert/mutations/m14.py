import sys
sys.path.insert(0, "/home/george/dev/Karakatiza666/talon/research/slice-246-revert/mutations")
from _m import edit
root = sys.argv[1]
edit(root, "worker/lib/Yank.roc", "Err(NoRepo) => Err(Problem.new(Forbidden, \"the release has no GitHub repository: only the operator can yank it\"))", "Err(NoRepo) => Ok({})")
