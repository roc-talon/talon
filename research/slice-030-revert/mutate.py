#!/usr/bin/env python3
"""Revert check of the tests of slice 030 (TW12) against the private reference. Filtered runs only, one after another (no full sweep, no parallel roc builds).

For each mutation: put the reference (research/slice-030-revert/reference) into cli/, change one small thing, `roc check cli/main.roc`, then run the layers of the mutation in order.
The first layer that fails ends the run of that mutation (caught). A layer over its timeout counts as caught (a loop). At the end the reference is put back (and swap.sh stub puts the stubs).
Layers: l0 = tests/unit/db.roc and facts.roc, l2 = tests/commands/run.sh db/, l3 = tests/run.sh db (builds tln, fxprobe and flowprobe), st = tests/selftest.sh (runner changes).
Runner changes (ids R..): the test files tests/run.sh, tests/lib.sh and tests/tools/dumpdb.py are changed and put back from a copy that the script takes at the start.

Usage (from the repo root): python3 -I research/slice-030-revert/mutate.py [id ...]   (no id: all)
"""
import os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
WORKD = ROOT + "/.work/mut030"
ENV = dict(os.environ, XDG_CACHE_HOME=WORKD + "/cache", ROC_CACHE_DIR=WORKD + "/cache/roc", ROC=ROC, WORK=WORKD, CASE_TIMEOUT="30", JOBS="4")
REF = os.path.join(ROOT, "research/slice-030-revert/reference")
FILES = ["cli/lib/Db.roc", "cli/lib/Facts.roc", "cli/RealDb.roc"]
INFRA = ["tests/run.sh", "tests/lib.sh", "tests/tools/dumpdb.py"]
TIMEOUT = {"l0": 120, "l2": 300, "l3": 600, "st": 600}
DB, FA, RD = FILES
RUN, LIB, DUMP = INFRA

# id, rule, file, old text (or a list), new text (or a list), layers in order
M = [
    ("D01", "R-P4", DB, 'Hang => "hang"', 'Hang => "hung"', "l0"),
    ("D02", "R-P4", DB, '"crash" => Ok(Crash)', '"crash" => Ok(Hang)', "l0"),
    ("D03", "R-CV6", DB, 'Registry => "registry"', 'Registry => "registery"', "l0"),
    ("D04", "R-P4", DB, "Str.join_with(Text.sorted_unique(modules), \",\")", "Str.join_with(modules, \",\")", "l0"),
    ("D05", "R-P4", DB, "Str.join_with(Text.sorted_unique(modules), \",\")", "Str.join_with(Text.sorted(modules), \",\")", "l0"),
    ("D06", "R-P4", DB, "modules_of = |text| if text.is_empty() [] else text.split_on(\",\")", "modules_of = |text| text.split_on(\",\")", "l0"),
    ("D07", "R-PK7", DB, "${Db.modules_text(fact.modules)}\\t${fact.closure}", "${fact.closure}\\t${Db.modules_text(fact.modules)}", "l0"),
    ("D08", "R-PK7", DB, "Err(BadWord) => Err(BadLine)\n\t\t}\n\t\t_ => Err(BadLine)", "Err(BadWord) => Ok(Pinned({ tag, target, sha256, source: GithubDigest }))\n\t\t}\n\t\t_ => Err(BadLine)", "l0"),
    ("D09", "R-PK7", DB, "facts = Text.sorted(store.facts.map(Db.fact_line))", "facts = store.facts.map(Db.fact_line)", "l0"),
    ("D10", "R-PK7", DB, 'pinned = Text.sorted(store.pinned.map(Db.pinned_line))', "pinned = store.pinned.map(Db.pinned_line)", "l0"),
    ("D11", "R-PK7", DB, ".append(\"\"), \"\\n\")", ", \"\\n\")", "l0"),
    ("D12", "R-TF1", DB, "[] => Ok({ format: 0, facts: [], pinned: [] })", "[] => Err(BadLine)", "l0"),
    ("D13", "R-TF3", DB, "TooNew(n) => Stop(Fail.new(Input,", "TooNew(n) => Stop(Fail.new(Usage,", "l0"),
    ("D14", "R-TF3", DB, "This tln writes format ${Db.format.to_str()}. Run: tln tool update talon\"))", "This tln writes format ${Db.format.to_str()}.\"))", "l0"),
    ("D15", "R-CC8", DB, "Write => \"the facts of this command are not saved\"\n\t\t\tRead => \"Talon goes on with no saved facts\"", "Read => \"the facts of this command are not saved\"\n\t\t\tWrite => \"Talon goes on with no saved facts\"", "l0"),
    ("D16", "R-CC8", DB, 'Failed(text) => Warn("cannot use ${facts.path} (${text}): ${saved}.', 'Failed(text) => Warn("cannot use compat.db (${text}): ${saved}.', "l0"),
    ("D19", "Q6", DB, " Removing the file resets the stored facts and the first-seen sha256 of compilers.\")", "\")", "l0"),
    ("D20", "R-CC8", DB, 'Failed(text) => Warn("cannot use ${facts.path} (${text})', 'Failed(_) => Warn("cannot use ${facts.path}', "l0"),
    ("D17", "R-TF1", DB, "format = 1", "format = 2", "l0"),
    ("D18", "R-CC8", DB, "busy_ms = 5000", "busy_ms = 3000", "l0"),
    ("F01", "R-P4", FA, 'Check => "any"\n\t\t\tBuild(_) => facts.host', 'Check => facts.host\n\t\t\tBuild(_) => facts.host', "l0"),
    ("F02", "R-P4", FA, "Build(_) => facts.closure", 'Build(_) => ""', "l0"),
    ("F03", "R-P3", FA, "NoFact(_) => Err(NoFact)", 'NoFact(_) => row(Crash, [], "")', "l0"),
    ("F04", "R-P4", FA, "Package({ hash, path }) if hash == facts.hash => Ok(path)", "Package({ hash: _, path }) => Ok(path)", "l0"),
    ("F05", "R-P4", FA, "Text.sorted_unique(\n\t\t\t\t\tfacts.errors.keep_oks(", "(\n\t\t\t\t\tfacts.errors.keep_oks(", "l0"),
    ("F06", "R-PP4", FA, 'Hang => row(Hang, [], "")', 'Hang => row(Crash, [], "")', "l0"),
    ("F07", "R-P4", FA, "\t\t\t\t),\n\t\t\t\t\"\",\n\t\t\t)\n\t\t\tHang", "\t\t\t\t),\n\t\t\t\tfacts.closure,\n\t\t\t)\n\t\t\tHang", "l0"),
    ("F08", "R-EF1", FA, "found.insert({ hash: r.hash, nightly: r.nightly, target: r.target }, r)", 'found.insert({ hash: r.hash, nightly: r.nightly, target: "any" }, r)', "l0"),
    ("F09", "R-CV6", FA, "p.tag == facts.listed.tag and p.target == facts.listed.target", "p.tag == facts.listed.tag", "l0"),
    ("F10", "R-CV6", FA, "if first.sha256 == facts.listed.sha256 Same", "if first == facts.listed Same", "l0"),
    ("F11", "R-CV6", FA, "Fail.new(\n\t\tIntegrity,", "Fail.new(\n\t\tUsage,", "l0"),
    ("F12", "R-CV6", FA, "first seen ${facts.first.sha256} (${Db.source_word(facts.first.source)}), now ${facts.now.sha256} (${Db.source_word(facts.now.source)})", "first seen ${facts.now.sha256} (${Db.source_word(facts.now.source)}), now ${facts.first.sha256} (${Db.source_word(facts.first.source)})", "l0"),
    ("F13", "R-EF1", FA, "load! = |fx, run| if run.keys.is_empty() {", "load! = |fx, run| if Bool.False {", "l2"),
    ("F14", "R-CC8", FA, "save! = |fx, run| if run.rows.is_empty() {", "save! = |fx, run| if Bool.False {", "l2"),
    ("F15", "R-CC8", FA, "Ok(Pinned(_)) => Ok([])\n\t\t\tErr(err) => match Db.on_err({ err, what: Read, path }) {\n\t\t\t\tStop(fail) => Err(fail)\n\t\t\t\tWarn(text) => {\n\t\t\t\t\tfx.err!(\"warning: ${text}\\n\")\n\t\t\t\t\tOk([])", "Ok(Pinned(_)) => Ok([])\n\t\t\tErr(err) => match Db.on_err({ err, what: Read, path }) {\n\t\t\t\tStop(fail) => Err(fail)\n\t\t\t\tWarn(text) => {\n\t\t\t\t\tfx.err!(\"warning: ${text}\\n\")\n\t\t\t\t\tErr(Fail.new(Environment, text))", "l2"),
    ("F16", "R-CC8", FA, "Ok(Kept)", "Ok(Saved)", "l2"),
    ("F17", "R-CC8", FA, "existing: run.existing }", "existing: Replace }", "l2"),
    ("F18", "R-CV6", FA, "fx.db_write!(open, Pinned([run.listed]))", "fx.db_write!(open, Pinned([]))", "l2"),
    ("F19", "R-CV6", FA, "Same => Ok(Same)", "Same => match fx.db_write!(open, Pinned([run.listed])) {\n\t\t\t\t_ => Ok(Same)\n\t\t\t}", "l2"),
    ("F20", "R-CC8", FA, "open = { path, busy_ms: Db.busy_ms, format: Db.format }", "open = { path, busy_ms: 1000, format: Db.format }", "l2"),
    ("F21", "R-EF1", FA, "path = Roots.item(run.roots, Item.CompatDb)\n\t\tmatch fx.db_query!", "path = Roots.item(run.roots, Item.Index)\n\t\tmatch fx.db_query!", "l2"),
    ("F22", "R-CC8", FA, "Err(err) => match Db.on_err({ err, what: Write, path }) {\n\t\t\t\tStop(fail) => Err(fail)\n\t\t\t\tWarn(text) => {\n\t\t\t\t\tfx.err!(\"warning: ${text}\\n\")\n\t\t\t\t\tOk(Kept)", "Err(err) => match Db.on_err({ err, what: Write, path }) {\n\t\t\t\tStop(fail) => Err(fail)\n\t\t\t\tWarn(text) => {\n\t\t\t\t\tfx.out!(\"warning: ${text}\\n\")\n\t\t\t\t\tOk(Kept)", "l2"),
    ("F23", "R-TF3", FA, "Stop(fail) => Err(fail)\n\t\t\t\tWarn(text) => {\n\t\t\t\t\tfx.err!(\"warning: ${text}\\n\")\n\t\t\t\t\tOk(Kept)", "Stop(_) => Ok(Kept)\n\t\t\t\tWarn(text) => {\n\t\t\t\t\tfx.err!(\"warning: ${text}\\n\")\n\t\t\t\t\tOk(Kept)", "l2"),
    ("F24", "R-TF3", FA, "Changed(changed) => Err(Facts.changed_fail(changed))", "Changed(_) => Ok(Same)", "l2"),
    ("X01", "R-CC8", RD, 'query: "PRAGMA busy_timeout=${open.busy_ms.to_str()}"', 'query: "PRAGMA busy_timeout=0"', "l3"),
    ("X02", "R-CC8", RD, 'query: "PRAGMA journal_mode=WAL"', 'query: "PRAGMA journal_mode=DELETE"', "l3"),
    ("X03", "R-TF3", RD, "if version <= open.format {", "if version <= open.format + 100 {", "l3"),
    ("X04", "R-TF3", RD, "if version > open.format {\n\t\t\t\tErr(TooNew(version))\n\t\t\t} else if version == 0", "if version >= open.format {\n\t\t\t\tErr(TooNew(version))\n\t\t\t} else if version == 0", "l3"),
    ("X05", "R-TF1", RD, '"PRAGMA user_version=${open.format.to_str()}"', '"PRAGMA user_version=0"', "l3"),
    ("X06", "R-TF2", RD, [" ON CONFLICT(hash, nightly, target) DO UPDATE SET outcome = excluded.outcome, modules = excluded.modules, closure = excluded.closure", '"INSERT INTO facts (hash'], [" ", '"INSERT OR REPLACE INTO facts (hash'], "l3"),
    ("X07", "R-CV6", RD, '"INSERT INTO pinned (tag, target, sha256, source) VALUES ${Str.join_with(tuples, ", ")} ON CONFLICT DO NOTHING"', '"INSERT OR REPLACE INTO pinned (tag, target, sha256, source) VALUES ${Str.join_with(tuples, ", ")}"', "l3"),
    ("X08", "R-CC8", RD, 'Keep => " ON CONFLICT DO NOTHING"', 'Keep => " ON CONFLICT(hash, nightly, target) DO UPDATE SET outcome = excluded.outcome, modules = excluded.modules, closure = excluded.closure"', "l3"),
    ("X09", "R-CC8", RD, "if nothing or !file_exists!(open.path) {", "if nothing {", "l3"),
    ("X10", "R-CC8", RD, "match Path.create_all!(Path.utf8(parent)) {", "match Path.create_all!(Path.utf8(Str.join_with([\"/tmp\", parent.drop_prefix(parent)], \"\"))) {", "l3"),
    ("X11", "R-TF1", RD, "if version == 0 create!(open)?", "if version == 99 create!(open)?", "l3"),
    ("X12", "R-CC8", RD, "SqliteErr(Busy, _) => Busy", "SqliteErr(Busy, text) => Failed(text)", "l3"),
    ("X13", "R-P4", RD, 'Str.join_with(tests, " OR ")}", bindings, rows: fact_columns', 'Str.join_with(tests, " AND ")}", bindings, rows: fact_columns', "l3"),
    ("X14", "R-P4", RD, 'value: String(Db.modules_text(r.modules))', 'value: String(Str.join_with(r.modules, ","))', "l3"),
    ("X15", "R-TF2", RD, '"SELECT hash, nightly, target, outcome, modules, closure FROM facts WHERE ${Str.join_with(tests, " OR ")}"', '"SELECT hash, nightly, target, outcome, modules FROM facts WHERE ${Str.join_with(tests, " OR ")}"', "l3"),
    ("R01", "R-PK7", RUN, '    [ -f "$ex/facts.tsv" ] && { compare_file "compat.db rows" "$ex/facts.tsv" "$W/out/facts.tsv" >> "$report" || fail=1; }\n', "", "st"),
    ("R02", "R-CC8", LIB, "diff -rNu -x 'compat.db*' -x path-roc.json -x tmp -x '*.tmp' orig/home home", "diff -rNu -x compat.db -x path-roc.json -x tmp -x '*.tmp' orig/home home", "st"),
    ("R03", "R-CV6", DUMP, '        for r in sorted(rows(con, "SELECT tag, target, sha256, source FROM pinned")):\n            print("pinned\\t" + "\\t".join(r))\n', "", "st"),
    ("R04", "R-TF1", DUMP, 'print("format\\t%d" % con.execute("PRAGMA user_version").fetchone()[0])', 'print("format\\t1")', "st"),
    ("R05", "R-P4", DUMP, 'print("fact\\t" + "\\t".join(r))', 'print("fact\\t" + "\\t".join(r[:5]))', "st"),
    ("R06", "R-PK7", RUN, '        update_file "$ex/facts.tsv" "$W/out/facts.tsv" optional\n', "", "st"),
    ("R07", "R-PK7", DUMP, "    if not os.path.exists(path):\n        return\n", "", "st"),
]

SAVED = {}


def sh(cmd, timeout):
    return subprocess.run(cmd, shell=True, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=timeout)


def restore():
    for f in FILES:
        shutil.copy(os.path.join(REF, f), os.path.join(ROOT, f))
    for f, text in SAVED.items():
        open(os.path.join(ROOT, f), "w").write(text)


def run_layer(layer):
    """Returns (failed, text)."""
    try:
        if layer == "l0":
            r = sh(f"{ROC} test tests/unit/db.roc --no-cache", TIMEOUT["l0"])
            if r.returncode != 0:
                return True, "unit/db"
            r = sh(f"{ROC} test tests/unit/facts.roc --no-cache", TIMEOUT["l0"])
            return r.returncode != 0, "unit/facts"
        if layer == "l2":
            r = sh("tests/commands/run.sh db/", TIMEOUT["l2"])
            return r.returncode != 0, "l2 db/"
        if layer == "st":
            r = sh("tests/selftest.sh", TIMEOUT["st"])
            return r.returncode != 0, "selftest"
        r = sh("tests/run.sh fx/db", TIMEOUT["l3"])
        return r.returncode != 0, "l3 fx/db"
    except subprocess.TimeoutExpired:
        return True, f"{layer} timeout"


def main():
    want = sys.argv[1:]
    os.makedirs(WORKD, exist_ok=True)
    for f in INFRA:
        SAVED[f] = open(os.path.join(ROOT, f)).read()
    results = []
    try:
        for entry in M:
            mid, rule, name, old, new = entry[:5]
            layers = entry[5].split()
            if want and mid not in want:
                continue
            restore()
            path = os.path.join(ROOT, name)
            text = open(path).read()
            olds = old if isinstance(old, list) else [old]
            news = new if isinstance(new, list) else [new]
            if any(text.count(o) != 1 for o in olds):
                results.append((mid, rule, name, "BAD EDIT (%s matches)" % [text.count(o) for o in olds], ""))
                print(mid, "BAD EDIT", [text.count(o) for o in olds], flush=True)
                continue
            for o, n in zip(olds, news):
                text = text.replace(o, n)
            open(path, "w").write(text)
            if name.startswith("cli/"):
                check = sh(f"{ROC} check cli/main.roc", 300)
                if check.returncode != 0 or "warning" in check.stdout.lower():
                    results.append((mid, rule, name, "DID NOT COMPILE", check.stdout[:200].replace("\n", " ")))
                    print(mid, "DID NOT COMPILE", check.stdout[:300].replace("\n", " "), flush=True)
                    continue
            caught = ""
            for layer in layers:
                failed, what = run_layer(layer)
                if failed:
                    caught = what
                    break
            state = "caught" if caught else "NOT CAUGHT"
            results.append((mid, rule, name, state, caught))
            print(mid, rule, name, state, caught, flush=True)
    finally:
        restore()
    out = "results.md" if not want else "results-partial.md"
    with open(os.path.join(ROOT, "research/slice-030-revert", out), "w") as f:
        f.write("| Id | Rule | File | Result | First failing test |\n| --- | --- | --- | --- | --- |\n")
        for r in results:
            f.write("| " + " | ".join(r) + " |\n")


main()
