#!/usr/bin/env python3
"""Revert check of the code of slice 022b (TW12, filtered runs only, no full sweep).

For each mutation: all files are first put back from code-final/ (so a kill is safe), then one small change in one file, a `roc check`,
then only the tests that should catch it. The first test that fails ends the run of that mutation (CAUGHT). A test that runs longer than the
timeout counts as CAUGHT (a loop). At the end all files are put back and compared with code-final/.

Usage: python3 -I research/slice-022b-revert/code-mutate.py [id ...]     (from the repo root)
Output: one line for each mutation: id, CAUGHT or NOT CAUGHT, the test that failed. Last line: SAME or DIFFERENT.
"""
import os, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FINAL = os.path.join(ROOT, "research/slice-022b-revert/code-final")
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))
TIMEOUT = {"l0": 120, "l2": 300, "l3": 300, "sh": 600}
FILES = ["cli/lib/PathRoc.roc", "cli/lib/Install.roc", "cli/RealFiles.roc", "cli/RealFx.roc", "cli/RealBase.roc", "cli/RealLocks.roc", "cli/RealJobs.roc",
         "cli/lib/Remove.roc", "cli/lib/Verify.roc", "cli/lib/Update.roc", "cli/lib/Compiler.roc"]
P, I, F = FILES[0], FILES[1], FILES[2]
L0 = ["l0:pathroc"]
L2 = ["l2:roc/so9-launcher", "l3:compilers/so9-launcher"]
L3F = ["l3:fx/so9-real-fx-path-roc"]

# (id, file, [(old, new)], [tests], what the change breaks)
M = [
    ("P1", P, [("(Err(None), _) => Hash(file)", "(Err(None), Err(None)) => Hash(exe)\n\t\t\t(Err(None), Ok(_)) => Hash(file)")], L0, "R-SO9: tln is hashed before the file"),
    ("P3", P, [("[file, .. as rest] => if file.size != exe.size {", "[file, .. as rest] => if file.size > exe.size {")], L0, "R-SO9: a smaller file is hashed"),
    ("P4", P, [("if a == b walk(exe, rest, entries)", "if a != b walk(exe, rest, entries)")], L0, "R-SO9: equal sha256 is not the launcher"),
    ("P5", P, [("if a == b walk(exe, rest, entries)", "if a.len() == b.len() walk(exe, rest, entries)")], L0, "R-SO9: the sha256 is not compared"),
    ("P6", P, [("e.path == file.path and e.size == file.size and e.mtime == file.mtime", "e.path == file.path and e.size == file.size")], L0, "R-SO9: the key has no mtime"),
    ("P7", P, [("e.path == file.path and e.size == file.size and e.mtime == file.mtime", "e.path == file.path and e.mtime == file.mtime")], L0, "R-SO9: the key has no size"),
    ("P8", P, [("e.path == file.path and e.size == file.size and e.mtime == file.mtime", "e.size == file.size and e.mtime == file.mtime")], L0, "R-SO9: the key has no path"),
    ("P9", P, [("NotRun => Version(file)\n\t\tid => Done(usable(id))", "NotRun | NoId => Version(file)\n\t\tid => Done(usable(id))")], L0, "R-SO9: a NoId row runs again"),
    ("P10", P, [("if Compiler.kind(text) == Local Err(NoCompiler) else Ok(text)", "if Compiler.kind(text) == Local Ok(text) else Ok(text)")], L0, "R-SO11: a local build is a compiler"),
    ("P11", P, [("Err(BadVersion) => NoId", "Err(BadVersion) => NotRun")], L0, "R-SO9: a bad text leaves no run mark"),
    ("P12", P, [("if valid(e, file) change(e) else change(fresh(file))", "change(e)")], L0, "R-SO9: a row of an older file is kept"),
    ("P13", P, [("if entries.any(|e| e.path == file.path) {", "if entries.any(|e| valid(e, file)) {")], L0, "R-SO9: 2 rows for one path"),
    ("P14", P, [("{ ..e, sha256: Ok(sha256) }", "{ ..e, sha256: Ok(sha256), extra: [] }")], L0, "R-TF2: add_sha drops the unknown fields"),
    ("P15", P, [("{ ..e, id: id }", "{ ..e, id: id, extra: [] }")], L0, "R-TF2: finish drops the unknown fields"),
    ("P16", P, [("if n > 1 {", "if n > 2 {")], L0, "R-TF3: format 2 is read"),
    ("P17", P, [("Ok(Null) => Ok(NoId)", "Ok(Null) => Err(BadRow)")], L0, "D10: id null is corrupt"),
    ("P18", P, [("extra: fields.keep_if(|(name, _)| !known.contains(name))", "extra: fields.keep_if(|(name, _)| !known.contains(name)).take_first(0)")], L0, "R-TF2: read drops the row fields"),
    ("P19", P, [("extra: pairs.keep_if(|(name, _)| name != \"format\" and name != \"files\")", "extra: []")], L0, "R-TF2: read drops the top fields"),
    ("P20", P, [("known.concat(sha).concat(id).concat(e.extra)", "known.concat(id).concat(sha).concat(e.extra)")], L0, "R-TF1: the key order of a row"),
    ("P21", P, [("NoId => [(\"id\", Null)]", "NoId => []")], L0, "D10: NoId is not written"),
    ("P22", P, [("Newer => Skip", "Newer => write_now")], L0, "R-TF3: a newer file is written"),
    ("P23", P, [("Corrupt => write_now", "Corrupt => Skip")], L0, "R-TF6: a corrupt file is not made again"),
    ("P24", P, [("_ => if same_rows(facts.before, facts.after) Skip else write_now", "_ => write_now")], L0, "R-SO9: the file is written when no row changed"),
    ("P25", P, [("\t\tCorrupt => Ok(\"${facts.path}", "\t\tNewer => Ok(\"${facts.path}: newer\")\n\t\tCorrupt => Ok(\"${facts.path}")], L0, "R-TF3: a warning for a newer file"),
    ("I1", I, [("argv: [file.path, \"version\"]", "argv: [\"roc\", \"version\"]")], L2, "D5: roc version by name"),
    ("I2", I, [("_ = fx.write_atomic!([{ path: cache, content }])", "_ = content")], L2, "R-SO9: the cache is not written"),
    ("I3", I, [("[one] => one\n\t\t\t\t_ => Err(NotFound)", "[_] => Err(NotFound)\n\t\t\t\t_ => Err(NotFound)")], L2, "R-SO9: the cache is not read"),
    ("I4", I, [("Ok(text) => fx.err!(\"warning: ${text}\\n\")", "Ok(_) => {}")], L2, "R-TF6: no warning"),
    ("I5", I, [("extra: read.extra })", "extra: [] })")], L2, "R-TF2: the top fields are lost"),
    ("I6", I, [("NotStarted(_) => {}\n\t\t\t\t\t\t\t\t_ => {", "NotStarted(_) => {}\n\t\t\t\t\t\t\t\tExited(code) if code != 0 => {}\n\t\t\t\t\t\t\t\t_ => {")], L2, "N6: a failed run leaves no row"),
    ("I7", I, [("\t\tif facts.found.is_empty() return Err(NoCompiler)\n", "")], L2 + ["l2:resolve/rs-no-compiler"], "N2: the cache is read when no roc is on PATH"),
    ("I8", I, [("Err(_) => {\n\t\t\t\t\t\t\t$done = Bool.True\n\t\t\t\t\t\t}", "Err(_) => {}")], L2, "a failed hash ends the walk"),
    ("F1", F, [("runnable_file! = |text, path| match Path.canonicalize!(path) {", "runnable_file! = |text, path| match Path.absolute!(path) {")], L3F, "N3: a link is not resolved"),
    ("F2", F, [("(Ok(Bool.True), Ok(Bool.True)) => runnable_facts!(text, real)", "(Ok(Bool.True), _) => runnable_facts!(text, real)")], L3F, "N3: a file that cannot run counts"),
    ("F3", F, [("(Ok(Bool.True), Ok(Bool.True)) => runnable_facts!(text, real)", "(_, Ok(Bool.True)) => runnable_facts!(text, real)")], L3F, "N3: a directory counts"),
    ("F4", F, [("Ok({ path: text, size, mtime: (ns // 1_000_000_000).to_u64_wrap() })", "Ok({ path: text, size, mtime: (ns // 1_000_000).to_u64_wrap() })")], L3F, "N3: the mtime is not in seconds"),
    ("F5", F, [("dirs = path_var.split_on(\":\").keep_if(|dir| !dir.is_empty())", "dirs = path_var.split_on(\":\").keep_if(|dir| !dir.is_empty()).rev()")], L3F, "R-SO9: the order of PATH"),
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
            built = subprocess.run([ROC, "check", "cli/main.roc"], cwd=ROOT, env=ENV, capture_output=True, text=True)
            if built.returncode != 0:
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
