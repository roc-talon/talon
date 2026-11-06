import sys, pathlib
p = pathlib.Path(sys.argv[1]) / "worker/lib/ArchiveRead.roc"
s = p.read_text(); old = "kind = if (entry.type_byte == '7') Other('7') else entry.kind"
assert old in s; p.write_text(s.replace(old, "kind = entry.kind"))
