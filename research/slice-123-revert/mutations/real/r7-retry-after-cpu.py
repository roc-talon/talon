import sys, pathlib
p = pathlib.Path(sys.argv[1]) / 'worker/main.roc'
s = p.read_text(); old = 'headers: [{ name: "content-type", value: "application/problem+json" }, { name: "cache-control", value: "no-store" }],'
assert old in s, "mutation text not found"
p.write_text(s.replace(old, 'headers: [{ name: "content-type", value: "application/problem+json" }, { name: "cache-control", value: "no-store" }].concat(if (cause == Cpu) [{ name: "retry-after", value: "1" }] else []),', 1))
