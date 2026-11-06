import sys, pathlib
p = pathlib.Path(sys.argv[1]) / 'worker/ShortRoutes.roc'
s = p.read_text(); old = 'list! = |req| match Shorts.parse_query(req.query_all("short"), req.query_all("q")) {'
assert old in s, "mutation text not found"
p.write_text(s.replace(old, 'list! = |req| match Shorts.parse_query(req.query_all("short").map(|v| v.replace_each("\\u(fffd)", "%FF")), req.query_all("q")) {', 1))
