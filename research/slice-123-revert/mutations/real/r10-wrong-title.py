import sys, pathlib
p = pathlib.Path(sys.argv[1]) / 'worker/lib/Problem.roc'
s = p.read_text(); old = 'Internal => "Internal error"'
assert old in s, "mutation text not found"
p.write_text(s.replace(old, 'Internal => "Internal Server Error"', 1))
