#!/usr/bin/env python3
import os, re, subprocess, sys, shutil
from concurrent.futures import ThreadPoolExecutor
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ["ROC"]
WORK = os.environ.get("WORK", ROOT + "/.work")
OUT = WORK + "/mut"
def f(n): return "cli/lib/" + n + ".roc"

PK, PF, PL, GA, IF, VF = f("Pick"), f("PickFlow"), f("PickLoop"), f("Gather"), f("InstallFlow"), f("VerifyFlow")
L0C = "l0:pickclosure"
L0P = "l0:pick"
RSU = "l2:resolve/rs-unmanaged"
IN1 = "l2:install/in1-flow"
CL2 = "l2:closure/cl2-chain"
CL1 = "l2:closure/cl1-flow"
ADK = "l2:resolve/rs-install-add-key"
M = [
 ("P1", "R-AL9 R-H7 the path files are no nodes of the closure", PK, [("nodes: facts.facts.map(|f| Pick.node_of(f)).concat(facts.paths),", "nodes: facts.facts.map(|f| Pick.node_of(f)),")], [L0C, CL2]),
 ("P2", "R-AL9 the entries that no slot owns are no roots", PK, [("entries: slot_entries.concat(m.entries),", "entries: slot_entries,")], [L0C, CL2]),
 ("P3", "R-AL9 R-PH10 a problem of the closure is no conflict of the tuple", PK, [("Fail(_) => Bool.True\n\t\t\t_ => Bool.False", "Fail(_) => Bool.False\n\t\t\t_ => Bool.False")], [L0C, L0P]),
 ("P4", "R-AL8 R-DT2 the step asks for no path file", PK, [("Need(need) => need\n\t\t\t\t_ => []", "Need(need) => need.keep_if(|id| id.contains(\"://\"))\n\t\t\t\t_ => []")], [L0C, CL2]),
 ("P5", "R-AL9 the Need list has repeats", PK, [("Fine(ids.fold([], |found, id| if found.contains(id) found else found.append(id)))", "Fine(ids)")], [L0C, CL2, RSU]),
 ("P6", "R-AL9 no member, no check of the closure", PK, [("if facts.unmanaged.is_empty() [{ file: \"\", entries: [] }] else facts.unmanaged", "facts.unmanaged")], [L0C, L0P]),
 ("P7", "R-C3 R-AL9 the platform entry of a release is no edge", PK, [("Ok(value) => [{ alias: \"\", value, is_platform: Bool.True }]", "Ok(_) => []")], [L0C, L0P, CL2, CL1]),
 ("P8", "R-FE1 the Need order: the entries before the slot URLs", PK, [("entries: slot_entries.concat(m.entries),", "entries: m.entries.concat(slot_entries),")], [L0C, L0P]),
 ("P9", "R-C3 the slot platform mark is lost", PK, [("is_platform: p.is_platform })\n\tresults", "is_platform: Bool.False })\n\tresults")], [L0C, L0P, CL2, RSU]),
 ("P10", "R-PH10 the step is Done with a node that has no fact", PK, [("if found.need.is_empty() {", "if found.need.len() < 99 {")], [L0C, L0P]),
 ("P11", "R-AL9 only the first member is checked", PK, [("results = ctx.members.map(", "results = ctx.members.take_first(1).map(")], [L0C]),
 ("F1", "R-AL8 the pick gets no path entries", PF, [("unmanaged_of(loaded, asked, request.project.file ?? \"\"))", "unmanaged_of(loaded, asked, request.project.file ?? \"\").keep_if(|_| Bool.False))")], [CL2, RSU, IN1]),
 ("F2", "R-AD38 R-AL9 D6 an entry that the run replaces is still a root", PF, [(" and !(m.file == current and replaced.contains(r.alias))", " and !(m.file == current and replaced.contains(r.alias) and Bool.False)")], [RSU, IN1]),
 ("F2b", "R-AL9 D6 the replaced alias is dropped in every member, not only the current one", PF, [("!(m.file == current and replaced.contains(r.alias))", "!((m.file == current or m.file != current) and replaced.contains(r.alias))")], [RSU, IN1, ADK]),
 ("L1", "R-AL8 the path files of the pick are not kept", PL, [("$paths = $paths.append({ id: g.id", "$paths = paths.append({ id: g.id")], [CL2, RSU, IN1]),
 ("L2", "R-AL8 the loop gives no path files to the walk", PL, [("Done(chosen) => Ok({ chosen, facts, paths })", "Done(chosen) => Ok({ chosen, facts, paths: [] })")], [CL2, IN1, RSU]),
 ("F3", "R-AL8 the walk does not get the path files that the pick read (install, update)", IF, [("known: ResolveBase.known_nodes(facts.known).concat(facts.paths) },", "known: ResolveBase.known_nodes(facts.known) },")], [CL2, IN1, RSU]),
 ("F4", "R-AL8 the same for verify", VF, [("known: ResolveBase.known_nodes(facts.known).concat(facts.paths),", "known: ResolveBase.known_nodes(facts.known),")], [CL2]),
 ("G1", "R-FE1 R-AL8 the ids are read in 2 calls", GA, [("texts = fx.read_files!(paths)", "_ = fx.read_files!([])\n\t\ttexts = fx.read_files!(paths)")], [CL2, RSU]),
 ("G2", "R-DI7 R-AL8 no download for a release URL", GA, [("if !urls.is_empty() {", "if !urls.is_empty() and urls.len() > 99 {")], [CL2, CL1]),
 ("G3", "R-FE7 a file that cannot be read is no Environment failure", GA, [("Err(_) => return Err(Fail.new(Environment, \"cannot read ${path}\"))", "Err(_) => return Err(Fail.new(Input, \"cannot read ${path}\"))")], [CL2, CL1, RSU, IN1]),
 ("C3", "C3 --platform reads the key of pf, not of the alias of the platform entry", PF, [(".map_ok(|r| r.alias) ?? \"pf\"", ".map_ok(|_| \"pf\") ?? \"pf\"")], [RSU]),
 ("C21", "C21 the key of [overrides] is ignored", PF, [("t.intent.deps.concat(t.intent.overrides).find_first", "t.intent.deps.find_first")], [RSU]),
 ("C25", "C25 the json of a replace has no old value", IF, [("did: Moved({ alias, from: { name: old, version: \"\" },", "did: Moved({ alias, from: { name: \"\", version: \"\" },")], [IN1]),
 ("C27", "C27 latest is a selector for the key range", PF, [("Ok(Latest) | Err(None) => replaced_key_range", "Err(None) => replaced_key_range")], [RSU]),
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
