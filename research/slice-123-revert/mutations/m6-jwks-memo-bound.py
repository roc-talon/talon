# The JWKS Memo has the same bound as the rule (1 h): on one clock it expires at exactly 1 h, one ms before the rule
import sys, pathlib
p = pathlib.Path(sys.argv[1]) / "worker/Auth.roc"
s = p.read_text(); old = "max_age_ms: 7_200_000"
assert old in s; p.write_text(s.replace(old, "max_age_ms: 3_600_000"))
