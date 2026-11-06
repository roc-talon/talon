import sys, pathlib
p = pathlib.Path(sys.argv[1]) / 'worker/Archive.roc'
s = p.read_text(); old = '$feeding = more and $state.reading()'
assert old in s, "mutation text not found"
p.write_text(s.replace(old, '$feeding = Bool.False', 1))
