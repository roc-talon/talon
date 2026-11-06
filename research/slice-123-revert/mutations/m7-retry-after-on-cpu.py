# The app gives retry-after on the cpu answer (R-AP82: only oom and shed have it, the shim adds it)
import sys, pathlib
p = pathlib.Path(sys.argv[1]) / "worker/main.roc"
s = p.read_text(); old = 'trap_cpu = trap_problem(503, "/errors/busy", "Busy", "the request used its CPU budget", [])'
assert old in s; p.write_text(s.replace(old, 'trap_cpu = trap_problem(503, "/errors/busy", "Busy", "the request used its CPU budget", [{ name: "retry-after", value: "1" }])'))
