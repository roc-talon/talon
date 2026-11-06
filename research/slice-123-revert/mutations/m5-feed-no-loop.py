# The feed! loop does not call again while `more` is true: the rest of the output of the chunk is lost
import sys, pathlib
p = pathlib.Path(sys.argv[1]) / "worker/Archive.roc"
s = p.read_text(); old = "$go = part.more and $state.reading()"
assert old in s; p.write_text(s.replace(old, "$go = Bool.False"))
