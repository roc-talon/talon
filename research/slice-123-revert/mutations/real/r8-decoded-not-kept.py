import sys, pathlib
p = pathlib.Path(sys.argv[1]) / 'worker/lib/ArchiveRead.roc'
s = p.read_text(); old = 'tar_push({ ..state, decoded: total }, bytes)'
assert old in s, "mutation text not found"
p.write_text(s.replace(old, 'tar_push(state, bytes)', 1))
