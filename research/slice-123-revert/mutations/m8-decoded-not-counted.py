# Q441: the decoded count is not kept between chunks (only one chunk is compared with the limit)
import sys, pathlib
p = pathlib.Path(sys.argv[1]) / "worker/lib/ArchiveRead.roc"
s = p.read_text(); old = "next = { ..state, tar, decoded: total }"
assert old in s; p.write_text(s.replace(old, "next = { ..state, tar }"))
