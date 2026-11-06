#!/usr/bin/env python3
# Revert checks (TW12) of slice 104k against the private reference. Run from the repo root. Work.roc and Audit.roc of the package are restored (stub) at the end.
import subprocess, shutil, re
R = "research/slice-104k-revert/"
D = "packages/records/"
def rd(p): return open(p).read()
ref = {"Work": rd(R + "reference/Work.roc"), "Audit": rd(R + "reference/Audit.roc")}
keep = {k: rd(D + k + ".roc") for k in ref}
M = [
 ("M1 Work.encode leaves out sweep for none", "Work", "sweep: Nullable.write(a.sweep)", "sweep: Nullable.write(a.sweep)", "json_none_dropped"),
 ("M2 Work.decode reads a missing sweep as null", "Work", None, None, "missing_sweep_ok"),
 ("M3 Work.encode reverses missing", "Work", "missing: a.missing }", "missing: a.missing.rev() }", None),
 ("M4 Work.decode swaps log_size and members", "Work", "log_size: x.log_size, members: x.members", "log_size: x.members, members: x.log_size", None),
 ("M5 Work.decode keeps only the first missing", "Work", "missing: x.missing })", "missing: x.missing.take_first(1) })", None),
 ("M6 Audit.encode sorts the pairs by pass_count", "Audit", "Json.to_str(answer)", "Json.to_str({ pairs: answer.pairs.sort_with(|p, q| if p.pass_count > q.pass_count Before else if p.pass_count == q.pass_count Same else After) })", None),
 ("M7 Audit.decode drops the last pair", "Audit", "parsed.map_err(|e| BadJson(Str.inspect(e)))", "parsed.map_ok(|a| { pairs: a.pairs.drop_last(1) }).map_err(|e| BadJson(Str.inspect(e)))", None),
 ("M8 Audit.encode writes a space after a comma", "Audit", "Json.to_str(answer)", "Json.to_str(answer).replace_each(\",\", \", \")", None),
 ("M9 Audit.decode reads a null pairs as empty", "Audit", None, None, "audit_null"),
 ("M10 Audit.decode swaps pass_count and fail_count", "Audit", "parsed.map_err(|e| BadJson(Str.inspect(e)))", "parsed.map_ok(|a| { pairs: a.pairs.map(|p| { ..p, pass_count: p.fail_count, fail_count: p.pass_count }) }).map_err(|e| BadJson(Str.inspect(e)))", None),
]
def mutated(name, mod, old, new, kind):
    s = ref[mod]
    if kind == "json_none_dropped":
        s = s.replace("Wire : { sweep : Nullable(Work.Sweep),", "Wire : { sweep : Try(Nullable(Work.Sweep), [Missing]),")
        s = s.replace("sweep: Nullable.write(a.sweep),", "sweep: Nullable.write_opt(a.sweep),")
        s = s.replace("sweep: Nullable.read(x.sweep),", "sweep: Nullable.read_opt(x.sweep),")
        return s
    if kind == "missing_sweep_ok":
        s = s.replace("Wire : { sweep : Nullable(Work.Sweep),", "Wire : { sweep : Try(Nullable(Work.Sweep), [Missing]),")
        s = s.replace("sweep: Nullable.write(a.sweep),", "sweep: Ok(Nullable.write(a.sweep)),")
        s = s.replace("sweep: Nullable.read(x.sweep),", "sweep: Nullable.read_opt(x.sweep),")
        return s
    if kind == "audit_null":
        s = s.replace("Audit.Answer, _)\n\t\tparsed =", "AuditNull, _)\n\t\tparsed =")
        s = s.replace("\tdecode : Str", "\tAuditNull : { pairs : Nullable(List(Audit.Pair)) }\n\n\tdecode : Str")
        s = s.replace("parsed.map_err(|e| BadJson(Str.inspect(e)))", "parsed.map_ok(|a| { pairs: Nullable.read(a.pairs) ?? [] }).map_err(|e| BadJson(Str.inspect(e)))")
        return "import Nullable\n\n" + s
    if s.count(old) != 1: return None
    return s.replace(old, new)
for tag in ("nightly-2026-10-14-38a3029", "nightly-2026-10-31-f7bef6b"):
    roc = f"cloudflare-workers/.cache/nightlies/{tag}/roc"
    def run():
        r = subprocess.run([roc, "test", D + "tests/w0.roc", "--no-cache"], capture_output=True, text=True)
        return r.returncode, r.stdout + r.stderr
    for k in ref: open(D + k + ".roc", "w").write(ref[k])
    rc, out = run(); print(tag, "reference rc", rc, re.findall(r"All \((\d+)\)", out))
    for name, mod, old, new, kind in M:
        m = mutated(name, mod, old, new, kind)
        if m is None: print(name, "SKIP (no unique match)"); continue
        for k in ref: open(D + k + ".roc", "w").write(ref[k])
        open(D + mod + ".roc", "w").write(m)
        rc, out = run()
        comp = re.search(r"(\d+) compiler errors", out)
        st = "COMPILE-ERROR" if "Compilation failed" in out or (comp and comp.group(1) != "0") else ("CAUGHT" if rc else "NOT CAUGHT")
        print(f"  {name} | {st} | failed={re.findall(r'(\d+) failed', out)}")
for k in ref: open(D + k + ".roc", "w").write(keep[k])
