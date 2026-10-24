#!/usr/bin/env python3
"""Revert check of the code of slice 022 (TW12, filtered runs only, no full sweep).

For each mutation: all files are first put back from code-final/ (so a kill is safe), then one small change in one file, a `roc check`,
then only the tests that should catch it. The first test that fails ends the run of that mutation (CAUGHT). A test that runs longer than the
timeout counts as CAUGHT (a loop). At the end all files are put back and compared with code-final/.

Usage: python3 -I research/slice-022-revert/code-mutate.py [id ...]     (from the repo root)
Output: one line for each mutation: id, CAUGHT or NOT CAUGHT, the test that failed. Last line: SAME or DIFFERENT.
"""
import os, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FINAL = os.path.join(ROOT, "research/slice-022-revert/code-final")
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))
TIMEOUT = {"l0": 120, "l2": 300, "l3": 300, "sh": 600}
FILES = ["cli/lib/Compiler.roc", "cli/lib/Pin.roc", "cli/lib/ResolveBase.roc", "cli/lib/Toolchain.roc", "cli/lib/RocInstall.roc",
         "cli/lib/Intent.roc", "cli/lib/Project.roc", "scripts/test.sh"]
C, P, R, T, O, I, J, S = FILES
L0C = ["l0:compiler"]
L0P = ["l0:pin"]
L2R = ["l2:roc/so1-ranks resolve/rs-no-compiler"]
L3R = ["l3:compilers/so2-ranks"]

# (id, file, [(old, new)], [tests], what the change breaks)
M = [
    ("C1", C, [("(Ok(id), _, _) if !facts.has_toml =>", "(Ok(id), _, _) =>")], L0C, "R-SO5: rank 5 is used with a talon.toml"),
    ("C2", C, [("(_, _, Ok(id)) => Ok({ id, rank: Path, state: Installed })", "(_, _, Ok(id)) => Ok({ id, rank: Path, state: Missing })")], L0C, "R-SO7: the PATH roc is Missing"),
    ("C3", C, [("known = facts.installed.contains(id) or facts.path == Ok(id)", "known = facts.installed.contains(id)")], L0C, "R-SO10: the PATH id is not installed for rank 1"),
    ("C4", C, [("and (facts.nightly or !Pin.is_nightly(id))", "and Bool.True")], L0C, "R-NS3: the switch is ignored by rank 4"),
    ("C5", C, [("fits = |id| Pin.is_id(id) and Pin.admits", "fits = |id| Pin.admits")], L0C, "R-NS6: rank 4 chooses a git build"),
    ("C6", C, [("times: facts.times }) == After id else best", "times: facts.times }) == Before id else best")], L0C, "R-SO4: rank 4 chooses the oldest"),
    ("C7", C, [("Ok(id) if !facts.installed.contains(id) => [id]", "Ok(_) => []")], L0C, "R-SO10: the PATH id is no candidate of rank 4"),
    ("C8", C, [("[] => Err(NoneInRange)", "[] => Err(NoCompiler)")], L0C, "R-SO13: no candidate is NoCompiler"),
    ("C9", C, [("e.is_dir and is_compiler_dir(e.name)", "is_compiler_dir(e.name)")], L0C, "R-LY1: a file is a compiler"),
    ("C10", C, [("!name.ends_with(\".lock\") and !name.ends_with(\".tmp\") and", "!name.ends_with(\".lock\") and")], L0C, "R-LY1: a temp dir is a compiler"),
    ("C11", C, [("installed = |entries| Text.sorted(entries", "installed = |entries| (entries")], L0C, "TW2: the ids are not sorted"),
    ("C12", C, [("key == \"published_at\"", "key == \"installed_at\"")], L0C, "R-NS1: the wrong key"),
    ("C13", C, [("id = facts.text.trim()", "id = facts.text")], L0C, "R-SO5: the .roc-version text is not trimmed"),
    ("C14", C, [("(Ok(pin), Ok(id)) if !Pin.same_id(pin, id) =>", "(Ok(pin), Ok(id)) if pin != id =>")], L0C, "R-CV1: the other tag form is a disagreement"),
    ("C15", C, [("Fail.new(Environment, \"no compiler is selected.", "Fail.new(Usage, \"no compiler is selected.")], L0C, "R-SO14: the kind of NoCompiler"),
    ("C16", C, [("Fail.new(Consent, \"no installed compiler is in", "Fail.new(Network, \"no installed compiler is in")], L0C, "R-SO13: the kind of NoneInRange"),
    ("P1", P, [("(Ok(x), Ok(y)) => x == y", "(Ok(x), Ok(y)) => x.date == y.date")], L0P, "R-CV1: 2 nightlies of one date are one id"),
    ("P2", P, [("(_, _, Ok(on)) => { nightly: on, source: Config }", "(_, _, Ok(on)) => { nightly: on, source: Toml }")], L0P, "R-NS10: the source of the config switch"),
    ("P3", P, [("_ => { nightly: Bool.True, source: Default }", "_ => { nightly: Bool.False, source: Default }")], L0P, "R-NS8: the default switch is off"),
    ("P4", P, [("if !Pin.is_id(facts.compiler) or facts.held_from == Range {", "if !Pin.is_id(facts.compiler) {")], L0P, "R-SO19: the gate checks Range"),
    ("P5", P, [("if !Pin.is_id(facts.compiler) or facts.held_from == Range {", "if facts.held_from == Range {")], L0P, "R-NS6: the gate checks a git build"),
    ("P6", P, [("(Nightly, Release) => Before", "(Nightly, Release) => After")], L0P, "R-NS1: a release of the same day is older"),
    ("P6b", P, [("(Release, Nightly) => After", "(Release, Nightly) => Before")], L0P, "R-NS1: a release of the same day is older (the other order)"),
    ("P7", P, [("if x < y Before else After", "if x < y After else Before")], L0P, "R-NS1: the times are in the wrong order"),
    ("P8", P, [("(Err(_), Ok(_)) => Before", "(Err(_), Ok(_)) => After")], L0P, "R-NS1: a release with no day is the newest"),
    ("P9", P, [("Exactly(a) => Pin.same_id(a, facts.id)", "Exactly(a) => facts.id == a")], L0P, "R-CV1: Exactly takes one tag form"),
    ("P10", P, [("order_of(id, bound, times) != Before", "order_of(id, bound, times.take_first(0)) != Before")], L0P, "R-NS1: AtLeast ignores the times"),
    ("P11", P, [("{ held: facts.compiler, held_from: from, note: Err(None) }", "{ held: facts.compiler, held_from: if from == Range Path else from, note: Err(None) }")], L0P, "R-SO19: held_from is always Path"),
    ("P12", P, [("(Release, _) => by_version(a, b)", "(Release, _) => Same")], L0P, "R-NS1: 2 releases of one day are the same"),
    ("R1", R, [("has_toml = request.project.toml.is_ok()", "has_toml = Bool.False")], L2R, "R-SO5: rank 5 with a talon.toml"),
    ("R2", R, [("or default.is_ok()", "or Bool.False")], L2R, "R-SO6: no listing for rank 6"),
    ("R3", R, [("times = if req.is_ok() and !installed.is_empty() {", "times = if req.is_ok() and installed.is_empty() {")], L2R, "R-NS1: no .talon.json read"),
    ("R4", R, [("pinned = loaded.members.any(|m| m.locked.roc.is_ok())", "pinned = Bool.False")], L2R, "R-SO3: select runs with a header pin"),
    ("R5", R, [("version_file: loaded.version_file }))", "version_file: Err(None) }))")], L2R, "R-SO18: no warning"),
    ("R6", R, [("Ok(path) => [path]", "Ok(_) => []")], L2R, "R-SO5: .roc-version is not read"),
    ("R7", R, [("VersionFile => VersionFile\n\tDefault => Default", "VersionFile => Path\n\tDefault => Default")], L2R, "R-SO19: rank 5 is shown as PATH"),
    ("R8", R, [("loaded.intent.toolchain.roc_text ?? \"\"", "\"*\"")], L2R, "R-SO13: the range text"),
    ("R9", R, [("Err(NoCompiler) => Err(Compiler.failure(NoCompiler))", "Err(NoCompiler) => Err(Fail.new(Environment, \"no compiler\"))")], L2R, "R-SO14: the text of NoCompiler"),
    ("I1", I, [(" and !text.drop_prefix(prefix).is_empty())", ")")], ["l0:intent"], "R-SO6: default-roc = git- is accepted"),
    ("I2", I, [("Pin.is_id(text) or [", "Bool.True or [")], ["l0:intent"], "R-SC12: any text is a default"),
    ("J1", J, [("if d.names.contains(\".roc-version\") Ok(Text.join(d.dir, \".roc-version\")) else climb_version(above)", "if d.names.contains(\".roc-version\") Ok(Text.join(d.dir, \".roc-version\")) else climb_version(above.take_first(0))")], ["l0:project"], "R-PD2: the walk stops at the first dir"),
    ("J2", J, [("nearest_version = |walk, from| match walk {\n\t[] => Err(None)\n\t[d, .. as above] => if d.dir != from {", "nearest_version = |walk, from| match walk {\n\t[] => Err(None)\n\t[d, .. as above] => if d.dir == \"\" {")], ["l0:project"], "G4: the walk starts at the first dir"),
    ("T1", T, [("auto: if facts.nightly shown.map(|r| r.id) else []", "auto: shown.map(|r| r.id)")], ["l0:toolchain"], "R-NS3: the switch is ignored by the domain"),
    ("T2", T, [("Empty if !facts.switch.nightly =>", "Empty if facts.switch.nightly =>")], ["l0:toolchain"], "R-NS2: the failure does not name the switch"),
    ("T3", T, [("\t\t\t\t(\"published_at\", JsonDoc.Text(Clock.format_utc(facts.published_at))),\n", "")], ["l0:toolchain"], "R-LY1: no published_at"),
    ("T4", T, [("((bytes + 50) // 100)", "(bytes // 100)")], ["l0:toolchain"], "T17: the size is cut"),
    ("O1", O, [("compat, now: ctx.now, published_at: ctx.published_at })", "compat, now: ctx.now, published_at: 0 })")], ["l2:roc/ri1-flow"], "Q5: published_at is 0"),
    ("O2", O, [("min_age, nightly: switch.nightly })", "min_age, nightly: Bool.True })")], ["l3:compilers/so2-ranks"], "R-NS2: install ignores the switch"),
    ("S1", S, [("-P \"$(parallel_jobs)\" -I{} bash -c '\n        n=${1//\\//_}\n        \"$ROC\" check", "-P 1 -I{} bash -c '\n        n=${1//\\//_}\n        \"$ROC\" check")], ["sh:tests/selftest.sh"], "N1: check is serial"),
    ("S2", S, [("        echo \"^^^ roc check $f (exit $(cat \"$dir/$n.rc\"))\"\n", "")], ["sh:tests/selftest.sh"], "N1: no ^^^ line"),
]


def restore():
    for f in FILES:
        with open(os.path.join(FINAL, f)) as src:
            text = src.read()
        with open(os.path.join(ROOT, f), "w") as dst:
            dst.write(text)


def run(test):
    kind, _, arg = test.partition(":")
    if kind == "l0":
        cmd = [ROC, "test", f"tests/unit/{arg}.roc", "--no-cache"]
    elif kind == "l2":
        cmd = ["tests/commands/run.sh"] + arg.split()
    elif kind == "l3":
        cmd = ["tests/run.sh"] + arg.split()
    else:
        cmd = arg.split()
    try:
        r = subprocess.run(cmd, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=TIMEOUT[kind])
    except subprocess.TimeoutExpired:
        return True, "timeout"
    return r.returncode != 0, (r.stdout + r.stderr)


def main():
    want = set(sys.argv[1:])
    for mid, fname, edits, tests, what in M:
        if want and mid not in want:
            continue
        restore()
        path = os.path.join(ROOT, fname)
        text = open(path).read()
        for old, new in edits:
            if text.count(old) != 1:
                print(f"{mid}: BAD EDIT ({text.count(old)} matches of {old[:60]!r})", flush=True)
                break
            text = text.replace(old, new)
        else:
            open(path, "w").write(text)
            built = subprocess.run([ROC, "check", "cli/lib/main.roc"], cwd=ROOT, env=ENV, capture_output=True, text=True)
            if fname != S and built.returncode != 0:
                print(f"{mid}: DID NOT COMPILE ({what}) " + built.stdout[:300].replace("\n", " "), flush=True)
                continue
            caught_by = None
            for t in tests:
                failed, _ = run(t)
                if failed:
                    caught_by = t
                    break
            print(f"{mid}: {'CAUGHT' if caught_by else 'NOT CAUGHT'} by {caught_by or '-'} ({what})", flush=True)
    restore()
    same = all(open(os.path.join(ROOT, f)).read() == open(os.path.join(FINAL, f)).read() for f in FILES)
    print("SAME as code-final" if same else "DIFFERENT from code-final")


main()
