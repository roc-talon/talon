import sys, pathlib
p = pathlib.Path(sys.argv[1]) / 'worker/Auth.roc'
s = p.read_text(); old = 'max_age_ms: 7_200_000'
assert old in s, "mutation text not found"
p.write_text(s.replace(old, 'max_age_ms: 3_600_000', 1))
