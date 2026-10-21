#!/usr/bin/env python3
import os, re, subprocess, sys, shutil
from concurrent.futures import ThreadPoolExecutor
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ["ROC"]
WORK = os.environ.get("WORK", ROOT + "/.work")
OUT = WORK + "/mut"
def f(n): return "cli/lib/" + n + ".roc"

PK, PF, IF, VF, RB = f("Pick"), f("PickFlow"), f("InstallFlow"), f("VerifyFlow"), f("ResolveBase")
L0C = "l0:pickclosure"
RSU = "l2:resolve/rs-unmanaged"
IN1 = "l2:install/in1-flow"
CL2 = "l2:closure/cl2-chain"
CL1 = "l2:closure/cl1-flow"
M = [
 ("S1", "R-AL9 R-H7 the path files are no nodes of the closure", PK, [("nodes: facts.facts.map(|f| node_of(f)).concat(facts.paths),", "nodes: facts.facts.map(|f| node_of(f)),")], [L0C, CL2]),
 ("S2", "R-AL9 the entries that no slot owns are no roots", PK, [("entries: slot_entries.concat(m.entries),", "entries: slot_entries,")], [L0C, CL2]),
 ("S3", "R-AL9 a problem of the closure is no conflict of the tuple", PK, [("conflict = results.any(", "conflict = Bool.False and results.any(")], [L0C]),
 ("S4", "R-AL8 R-DT2 the step asks for no node that it lacks", PK, [("	{ conflict, need }\n}", "	{ conflict, need: need.keep_if(|id| id.contains(\"://\")) }\n}")], [L0C]),
 ("S5", "R-AL9 the need list has repeats", PK, [(".fold([], |ids, id| if ids.contains(id) ids else ids.append(id))\n\t{ conflict, need }", ".fold([], |ids, id| ids.append(id))\n\t{ conflict, need }")], [L0C]),
 ("F1", "R-AL8 the pick gets no path entries", PF, [("pick_loop!(fx, request, { ..input, unmanaged }, prepared.facts, [])", "pick_loop!(fx, request, { ..input, unmanaged: unmanaged.keep_if(|_| Bool.False) }, prepared.facts, [])")], [CL2, RSU, IN1]),
 ("F2", "R-AD38 R-AL9 an entry that the run replaces is still a root", PF, [(" and !fresh_keys.contains(r.alias)", " and !(fresh_keys.contains(r.alias) and Bool.False)")], [RSU, IN1]),
 ("F3", "R-AL8 the walk does not get the path files that the pick read", IF, [("known: ResolveBase.known_nodes(facts.known).concat(facts.paths) },", "known: ResolveBase.known_nodes(facts.known) },")], [CL2, IN1, RSU]),
 ("F4", "R-AL8 verify: the walk does not get the path files that the pick read", VF, [("known: ResolveBase.known_nodes(facts.known).concat(facts.paths),", "known: ResolveBase.known_nodes(facts.known),")], [CL2]),
 ("C3", "C3 --platform over a path platform reads the key of pf, not of its alias", PF, [('.map_ok(|r| r.alias) ?? "pf")', '.map_ok(|_| "pf") ?? "pf")')], [RSU]),
 ("C21", "C21 the key of [overrides] is ignored", PF, [("t.intent.deps.concat(t.intent.overrides).find_first", "t.intent.deps.find_first")], [RSU]),
 ("C25", "C25 the json of a replace has no old value", IF, [("did: Moved({ alias, from: { name: old, version: \"\" },", "did: Moved({ alias, from: { name: \"\", version: \"\" },")], [IN1]),
 ("C27", "C27 latest is a selector for the key range", PF, [("Ok(Latest) | Err(None) => replaced_key_range", "Err(None) => replaced_key_range")], [RSU]),
 ("N1", "R-FE1 R-AL8 the level reads the path files apart", RB, [("files = ids.map(|id| ResolveBase.main_of(request.roots, id))\n\t\ttexts = fx.read_files!(files)", "files = ids.map(|id| ResolveBase.main_of(request.roots, id))\n\t\t_ = fx.read_files!([])\n\t\ttexts = fx.read_files!(files)")], [CL2, RSU]),
]
def sh(cmd, **kw):
    return subprocess.run(cmd, cwd=ROOT, env=dict(os.environ), capture_output=True, text=True, timeout=1800, **kw)
def build(name, main):
    p = sh([ROC, "build", main, "--output=" + OUT + "/" + name])
    return p.returncode, p.stdout + p.stderr
def run_all(tests):
    shutil.rmtree(OUT, ignore_errors=True)
    os.makedirs(OUT + "/bin")
    needs_l2 = any(t.startswith("l2:") for t in tests)
    needs_l3 = any(t.startswith("l3:") for t in tests)
    jobs = []
    with ThreadPoolExecutor(max_workers=4) as ex:
        if needs_l2: jobs.append(("l2", ex.submit(build, "l2", "tests/commands/main.roc")))
        if needs_l3: jobs.append(("tln", ex.submit(build, "bin/tln", "cli/main.roc")))
        for name, j in jobs:
            rc, out = j.result()
            if rc != 0: return [("build " + name, 1, "Compilation failed\n" + out[-1500:])]
    results = []
    for t in tests:
        kind, what = t.split(":")
        if kind == "l0": cmd = [ROC, "test", f"tests/unit/{what}.roc", "--no-cache"]
        elif kind == "l2":
            cmd = ["tests/commands/run.sh", what]; os.environ["L2BIN"] = OUT + "/l2"
        else:
            cmd = ["tests/run.sh", what]; os.environ["TLN"] = OUT + "/bin/tln"
        p = sh(cmd)
        results.append((t, p.returncode, p.stdout + p.stderr))
    return results
def main():
    flt = sys.argv[1:]
    dry = os.environ.get("DRY") == "1"
    print("| Id | Rules | Mutation | Result |\n| --- | --- | --- | --- |")
    for mid, ids, rel, pairs, tests in M:
        if flt and mid not in flt: continue
        path = f"{ROOT}/{rel}"
        text = open(path).read()
        short = pairs[0][0][:50].replace("\n", " ").replace("\t", " ").replace("|", "/").strip()
        if any(o not in text for o, _ in pairs):
            print(f"| {mid} | {ids} | `{short}`: pattern not found | INVALID |", flush=True); continue
        if dry:
            print(f"| {mid} | {ids} | `{short}` found | |", flush=True); continue
        new = text
        for o, n in pairs: new = new.replace(o, n, 1)
        open(path, "w").write(new)
        try: results = run_all(tests)
        finally: open(path, "w").write(text)
        def broke(rc, out):
            return rc != 0 and (re.search(r"^\s*[1-9][0-9]* compiler errors?", out, re.M) or "Compilation failed" in out or re.search(r"^build of .* failed", out, re.M))
        bad = [out[-800:] for _, rc, out in results if broke(rc, out)]
        if bad:
            print(bad[0], file=sys.stderr)
            print(f"| {mid} | {ids} | `{short}` | INVALID (compile error) |", flush=True); continue
        caught = [t for t, rc, _ in results if rc != 0]
        missed = [t for t, rc, _ in results if rc == 0]
        result = ("caught by " + ", ".join(caught)) if caught else "NOT CAUGHT"
        if caught and missed: result += " (not by " + ", ".join(missed) + ")"
        print(f"| {mid} | {ids} | `{short}` | {result} |", flush=True)
    shutil.rmtree(OUT, ignore_errors=True)
main()
