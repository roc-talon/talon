import sys, pathlib
p = pathlib.Path(sys.argv[1]) / 'worker/lib/ArchiveRead.roc'
s = p.read_text(); old = '\tfeed_bytes = 65536'
assert old in s, "mutation text not found"
p.write_text(s.replace(old, '\tfeed_bytes = 4096', 1))
