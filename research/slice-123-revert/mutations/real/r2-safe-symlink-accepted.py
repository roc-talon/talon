import sys, pathlib
p = pathlib.Path(sys.argv[1]) / 'worker/lib/ArchiveRead.roc'
s = p.read_text(); old = "kind = if (entry.kind == File and entry.type_byte == '7') Other('7') else entry.kind"
assert old in s, "mutation text not found"
p.write_text(s.replace(old, "kind = if (entry.kind == File and entry.type_byte == '7') Other('7') else if (entry.type_byte == '2' and Tar.roc_accepts(entry) == Ok({})) File else entry.kind", 1))
