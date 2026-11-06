import sys, pathlib
p = pathlib.Path(sys.argv[1]) / "worker/lib/ArchiveRead.roc"
s = p.read_text(); old = "	feed_bytes = 65536\n"
assert old in s; p.write_text(s.replace(old, "	feed_bytes = 4096\n"))
