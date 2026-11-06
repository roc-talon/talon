# the zstd stream is opened with a 2 MiB window (the window of real bundles)
import sys
d = sys.argv[1]
p = d + '/Archive.roc'
s = open(p).read()
old = 'z = Native.ZstdStream.open!().map_err'
new = 'z = Native.ZstdStream.open_with!({ window_limit_bytes: 2097152 }).map_err'
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
