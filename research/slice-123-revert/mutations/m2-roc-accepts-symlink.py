# The check uses the rule of Tar.roc_accepts for a symbolic link: a link with a safe target is a file (R-PU38 row 12 refuses each symbolic link)
import sys, pathlib
p = pathlib.Path(sys.argv[1]) / "worker/lib/ArchiveRead.roc"
s = p.read_text(); old = "kind = if (entry.type_byte == '7') Other('7') else entry.kind"
assert old in s
p.write_text(s.replace(old, "kind = if (entry.type_byte == '7') Other('7') else if (entry.type_byte == '2' and Tar.roc_accepts(entry) == Ok({})) File else entry.kind"))
