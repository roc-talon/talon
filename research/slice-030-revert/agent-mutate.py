#!/usr/bin/env python3
"""Revert check of the code of slice 030 part a (TW12). Small mutations of the code agent, one at a time, filtered runs only (no full sweep, no parallel roc builds).

The final code is in research/slice-030-revert/code-final/. Each mutation: put code-final into cli/, change one small thing, `roc check cli/main.roc`, then run the layers in order.
The first failing layer ends the run (caught). A layer over its timeout counts as caught (a loop). At the end code-final is put back and compared.
Layers: l0 = tests/unit/db.roc and facts.roc, l2 = tests/commands/run.sh db/, l3 = tests/run.sh fx/db (builds tln, fxprobe and flowprobe).
Usage (repo root): python3 -I research/slice-030-revert/agent-mutate.py [id ...]   (no id: all). Rows are appended to agent-results.md.
"""
import os, shutil, subprocess, sys, filecmp

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
WORKD = ROOT + "/.work/agentmut030"
ENV = dict(os.environ, XDG_CACHE_HOME=WORKD + "/cache", ROC_CACHE_DIR=WORKD + "/cache/roc", ROC=ROC, WORK=WORKD, CASE_TIMEOUT="30", JOBS="4")
FINAL = os.path.join(ROOT, "research/slice-030-revert/code-final")
FILES = ["cli/lib/Db.roc", "cli/lib/Facts.roc", "cli/RealDb.roc"]
TIMEOUT = {"l0": 120, "l2": 300, "l3": 600}
DB, FA, RD = FILES

# id, rule, file, old text, new text, layers in order
M = [
    ("D01", "R-P4", DB, 'Hang => "hang"', 'Hang => "hung"', "l0"),
    ("D02", "R-P4", DB, '"crash" => Ok(Crash)', '"crash" => Ok(Hang)', "l0"),
    ("D03", "R-CV6", DB, '"registry" => Ok(Registry)', '"registry" => Ok(GithubDigest)', "l0"),
    ("D04", "R-P4", DB, "Text.sorted_unique(modules)", "modules", "l0"),
    ("D05", "R-P4", DB, "Text.sorted_unique(modules)", "Text.sorted(modules)", "l0"),
    ("D06", "R-P4", DB, "if text.is_empty() [] else text.split_on", "if text.len() > 100000 [] else text.split_on", "l0"),
    ("D07", "R-PK7", DB, "Db.modules_text(fact.modules), fact.closure]", "fact.closure, Db.modules_text(fact.modules)]", "l0"),
    ("D08", "R-PK7", DB, "Err(BadWord) => Err(BadLine)\n\t\t}\n\t\t_ => Err(BadLine)", "Err(BadWord) => Ok(Pinned({ tag, target, sha256, source: GithubDigest }))\n\t\t}\n\t\t_ => Err(BadLine)", "l0"),
    ("D09", "R-PK7", DB, "store.facts.sort_with(fact_order)", "store.facts", "l0"),
    ("D10", "R-PK7", DB, "store.pinned.sort_with(pinned_order)", "store.pinned", "l0"),
    ("D11", "R-PK7", DB, '"${text}${line}\\n"', '"${text}${line}"', "l0"),
    ("D12", "R-TF1", DB, "if text.is_empty() {\n\t\t\tOk({ format: 0, facts: [], pinned: [] })", "if text.is_empty() {\n\t\t\tErr(BadLine)", "l0"),
    ("D13", "R-TF3", DB, "TooNew(found) => Stop(\n\t\t\tFail.new(Input,", "TooNew(found) => Stop(\n\t\t\tFail.new(Usage,", "l0"),
    ("D14", "R-TF3", DB, " Run: tln tool update talon\"", '"', "l0"),
    ("D15", "R-CC8", DB, 'Write => "compat.db is busy: the facts of this command are not saved"\n\t\t\t\tRead => "compat.db is busy: Talon goes on with no saved facts"', 'Read => "compat.db is busy: the facts of this command are not saved"\n\t\t\t\tWrite => "compat.db is busy: Talon goes on with no saved facts"', "l0"),
    ("D16", "R-CC8", DB, 'Warn("cannot use ${facts.path} (${reason})', 'Warn("cannot use compat.db (${reason})', "l0"),
    ("D17", "R-TF1", DB, "format = 1", "format = 2", "l0"),
    ("D18", "R-CC8", DB, "busy_ms = 5000", "busy_ms = 3000", "l0"),
    ("D19", "R-PK7", DB, "\t|> then_by(Text.compare(a.target, b.target))\n\npinned_order", "\npinned_order", "l0"),
    ("F01", "R-P4", FA, 'Check => "any"\n\t\t\tBuild(_) => facts.host', 'Check => facts.host\n\t\t\tBuild(_) => facts.host', "l0"),
    ("F02", "R-P4", FA, "Build(_) => facts.closure", 'Build(_) => ""', "l0"),
    ("F03", "R-P3", FA, "NoFact(_) => Err(NoFact)", 'NoFact(_) => row(Crash, [], "")', "l0"),
    ("F04", "R-P4", FA, "if found.hash == hash Ok(found.path)", "if found.hash != hash Ok(found.path)", "l0"),
    ("F05", "R-P4", FA, "failing_modules = |hash, errors| Text.sorted_unique(", "failing_modules = |hash, errors| Text.sorted(", "l0"),
    ("F06", "R-PP4", FA, 'Hang => row(Hang, [], "")', 'Hang => row(Crash, [], "")', "l0"),
    ("F07", "R-P4", FA, 'Fail(_) => row(Fail, failing_modules(facts.hash, facts.errors), "")', "Fail(_) => row(Fail, failing_modules(facts.hash, facts.errors), closure)", "l0"),
    ("F08", "R-EF1", FA, "({ hash: row.hash, nightly: row.nightly, target: row.target }, row)", '({ hash: row.hash, nightly: row.nightly, target: "any" }, row)', "l0"),
    ("F09", "R-CV6", FA, "row.tag == facts.listed.tag and row.target == facts.listed.target", "row.tag == facts.listed.tag", "l0"),
    ("F10", "R-CV6", FA, "if first.sha256 == facts.listed.sha256 Same", "if first == facts.listed Same", "l0"),
    ("F11", "R-CV6", FA, "Fail.new(\n\t\t\tIntegrity,", "Fail.new(\n\t\t\tUsage,", "l0"),
    ("F12", "R-CV6", FA, "first seen ${first.sha256} (${Db.source_word(first.source)}), now ${now.sha256} (${Db.source_word(now.source)})", "first seen ${now.sha256} (${Db.source_word(now.source)}), now ${first.sha256} (${Db.source_word(first.source)})", "l0"),
    ("F13", "R-EF1", FA, "if run.keys.is_empty() {", "if run.keys.len() > 1000 {", "l2"),
    ("F14", "R-CC8", FA, "if run.rows.is_empty() {", "if run.rows.len() > 1000 {", "l2"),
    ("F15", "R-CC8", FA, "what: Read, path: open.path }) {\n\t\t\t\t\tOk(_) => Ok([])\n\t\t\t\t\tErr(fail) => Err(fail)\n\t\t\t\t}\n\t\t\t}\n\t\t}\n\t}\n\n\t## One round", "what: Read, path: open.path }) {\n\t\t\t\t\tOk(_) => Err(Fail.new(Environment, \"x\"))\n\t\t\t\t\tErr(fail) => Err(fail)\n\t\t\t\t}\n\t\t\t}\n\t\t}\n\t}\n\n\t## One round", "l2"),
    ("F16", "R-CC8", FA, "Ok(_) => Ok(Kept)", "Ok(_) => Ok(Saved)", "l2"),
    ("F17", "R-CC8", FA, "existing: run.existing }", "existing: Replace }", "l2"),
    ("F18", "R-CV6", FA, "fx.db_write!(open, Pinned([run.listed]))", "fx.db_write!(open, Pinned([]))", "l2"),
    ("F19", "R-CV6", FA, "Same => Ok(Same)", "Same => match fx.db_write!(open, Pinned([run.listed])) {\n\t\t\t\t_ => Ok(Same)\n\t\t\t}", "l2"),
    ("F20", "R-CC8", FA, "busy_ms: Db.busy_ms, format: Db.format }", "busy_ms: 1000, format: Db.format }", "l2"),
    ("F21", "R-EF1", FA, "Roots.item(roots, CompatDb)", "Roots.item(roots, Index)", "l2"),
    ("F22", "R-CC8", FA, 'fx.err!("warning: ${text}\\n")', 'fx.out!("warning: ${text}\\n")', "l2"),
    ("F23", "R-TF3", FA, "Stop(fail) => Err(fail)\n\tWarn(text)", "Stop(_) => Ok({})\n\tWarn(text)", "l2"),
    ("F24", "R-CV6", FA, "Changed(change) => Err(Facts.changed_fail(change))", "Changed(_) => Ok(Same)", "l2"),
    ("F25", "R-CC8", FA, 'fx.err!("warning: ${text}\\n")', 'fx.err!("${text}\\n")', "l2"),
    ("X01", "R-CC8", RD, '"busy_timeout=${U64.to_str(open.busy_ms)}"', '"busy_timeout=0"', "l3"),
    ("X02", "R-CC8", RD, '"journal_mode=WAL"', '"journal_mode=DELETE"', "l3"),
    ("X03", "R-TF3", RD, "if version > open.format {", "if version > open.format + 100 {", "l3"),
    ("X04", "R-TF3", RD, "if version > open.format {", "if version >= open.format {", "l3"),
    ("X05", "R-TF1", RD, '"PRAGMA user_version=${U64.to_str(open.format)}"', '"PRAGMA user_version=0"', "l3"),
    ("X06", "R-TF2", RD, ["Replace => \"ON CONFLICT(hash, nightly, target) DO UPDATE SET outcome = excluded.outcome, modules = excluded.modules, closure = excluded.closure\"", "exec!(path, \"INSERT INTO facts (hash"], ["Replace => \"\"", "exec!(path, \"INSERT OR REPLACE INTO facts (hash"], "l3"),
    ("X07", "R-CV6", RD, "INSERT INTO pinned (tag, target, sha256, source) VALUES ${marks} ON CONFLICT DO NOTHING", "INSERT OR REPLACE INTO pinned (tag, target, sha256, source) VALUES ${marks}", "l3"),
    ("X08", "R-CC8", RD, 'Keep => "ON CONFLICT DO NOTHING"', 'Keep => "ON CONFLICT(hash, nightly, target) DO UPDATE SET outcome = excluded.outcome, modules = excluded.modules, closure = excluded.closure"', "l3"),
    ("X09", "R-CC8", RD, "Ok(Bool.False) => Ok(empty_answer(query))", "Ok(Bool.False) => read_rows!(open, query)", "l3"),
    ("X10", "R-CC8", RD, "Path.create_all!(Path.utf8(dir))", 'Path.create_all!(Path.utf8("/"))', "l3"),
    ("X11", "R-TF1", RD, "if version == 0 create!(open)", "if version == 99 create!(open)", "l3"),
    ("X12", "R-CC8", RD, "SqliteErr(Busy, _) => Busy", 'SqliteErr(Busy, _) => Failed("busy")', "l3"),
    ("X13", "R-P4", RD, '" OR ")\n\t\tbindings = keys.map_with_index(|key, i| fact_key_bindings', '" AND ")\n\t\tbindings = keys.map_with_index(|key, i| fact_key_bindings', "l3"),
    ("X14", "R-P4", RD, 'text(":m${n}", Db.modules_text(row.modules))', 'text(":m${n}", Str.join_with(row.modules, ","))', "l3"),
    ("X15", "R-TF2", RD, "SELECT hash, nightly, target, outcome, modules, closure FROM facts", "SELECT hash, nightly, target, outcome, modules FROM facts", "l3"),
    ("X16", "R-TF3", RD, "Ok(found) => {\n\t\t\t\tversion =", 'Ok(found) => {\n\t\t\t\t_ = pragma_str!(path, "journal_mode=WAL", "journal_mode")\n\t\t\t\tversion =', "l3"),
    ("X17", "R-CC8", RD, "\tpath = Path.utf8(open.path)\n\tmatch pragma_int!(path, \"busy_timeout", "\tpath = Path.utf8(open.path)\n\t_ = pragma_str!(path, \"journal_mode=WAL\", \"journal_mode\")\n\tmatch pragma_int!(path, \"busy_timeout", "l3"),
    ("X18", "R-CV6", RD, '" OR ")\n\t\tbindings = keys.map_with_index(|key, i| [text', '" AND ")\n\t\tbindings = keys.map_with_index(|key, i| [text', "l3"),
    ("X19", "R-TF1", RD, '\t\t\t\t"COMMIT",\n', "", "l3"),
    ("X20", "R-CC8", RD, "closure = excluded.closure", "closure = closure", "l3"),
    ("X21", "R-P4", RD, "modules = excluded.modules, ", "", "l3"),
    ("X22", "R-CV6", RD, 'text(":o${n}", Db.source_word(row.source))', 'text(":o${n}", Db.source_word(Registry))', "l3"),
    ("X23", "R-CC8", RD, "Facts({ rows, existing: _ }) => rows.is_empty()", "Facts({ rows, existing: _ }) => rows.len() > 1000", "l3"),
    ("X24", "R-EF1", RD, "Facts(keys) => keys.is_empty()", "Facts(keys) => keys.len() > 1000", "l3"),
    ("X25", "R-CC8", RD, "SqliteErr(Locked, _) => Busy", 'SqliteErr(Locked, _) => Failed("locked")', "l3"),
]


# The set that the code agent runs (about 35, one for each part of each rule). The other rows stay as spare ideas.
CHOSEN = "D02 D04 D05 D07 D09 D13 D14 D16 D18 F01 F02 F03 F04 F08 F10 F13 F14 F16 F18 F22 F23 F24 X01 X04 X05 X06 X07 X08 X09 X10 X12 X14 X16 X19 X23 X24 X13 X17".split()


def sh(cmd, timeout):
    return subprocess.run(cmd, shell=True, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=timeout)


def restore():
    for f in FILES:
        shutil.copy(os.path.join(FINAL, f), os.path.join(ROOT, f))


def prune():
    sh("bash -c '. scripts/env.sh; . tests/lib.sh; prune_roc_objects'", 60)


def run_layer(layer):
    try:
        if layer == "l0":
            r = sh(f"{ROC} test tests/unit/db.roc --no-cache", TIMEOUT["l0"])
            if r.returncode != 0:
                return True, "unit/db"
            r = sh(f"{ROC} test tests/unit/facts.roc --no-cache", TIMEOUT["l0"])
            return r.returncode != 0, "unit/facts"
        if layer == "l2":
            r = sh("tests/commands/run.sh db/", TIMEOUT["l2"])
            return r.returncode != 0, "l2 db/cc1-store"
        r = sh("tests/run.sh fx/db", TIMEOUT["l3"])
        return r.returncode != 0, "l3 fx/db"
    except subprocess.TimeoutExpired:
        return True, f"{layer} timeout"


def main():
    want = sys.argv[1:] or CHOSEN
    os.makedirs(WORKD, exist_ok=True)
    out = os.path.join(ROOT, "research/slice-030-revert/agent-results.md")
    if not os.path.exists(out):
        open(out, "w").write("| Id | Rule | File | Result | First failing test |\n| --- | --- | --- | --- | --- |\n")
    try:
        for mid, rule, name, old, new, layers in M:
            if want and mid not in want:
                continue
            restore()
            prune()
            path = os.path.join(ROOT, name)
            text = open(path).read()
            olds = old if isinstance(old, list) else [old]
            news = new if isinstance(new, list) else [new]
            if any(text.count(o) != 1 for o in olds):
                row = (mid, rule, name, "BAD EDIT (%s matches)" % [text.count(o) for o in olds], "")
            else:
                for o, n in zip(olds, news):
                    text = text.replace(o, n)
                open(path, "w").write(text)
                check = sh(f"{ROC} check cli/main.roc", 300)
                if check.returncode != 0 or "warning" in check.stdout.lower():
                    row = (mid, rule, name, "DID NOT COMPILE", check.stdout[:200].replace("\n", " "))
                else:
                    caught = ""
                    for layer in layers.split():
                        failed, what = run_layer(layer)
                        if failed:
                            caught = what
                            break
                    row = (mid, rule, name, "caught" if caught else "NOT CAUGHT", caught)
            print(*row, flush=True)
            open(out, "a").write("| " + " | ".join(row) + " |\n")
    finally:
        restore()
    same = all(filecmp.cmp(os.path.join(ROOT, f), os.path.join(FINAL, f), shallow=False) for f in FILES)
    print("code equals code-final:", same, flush=True)


main()
