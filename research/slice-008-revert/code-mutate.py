#!/usr/bin/env python3
"""Revert check of the code of slice 008 (TW12), made by the code agent. Usage: research/slice-008-revert/code-mutate.py [id ...]   (DRY=1: only test that each pattern is found)
Each row is one small change of the real code in cli/lib/ and the tests that must fail. A compile error or a warning is INVALID, not a catch.
The file is put back after each run. Needs ROC (scripts/env.sh sets it). Output is a table.
L0 rows run `roc test` of one file. L2 and L3 rows build the test app and `tln` into $WORK/mut/ and run the cases `remove/`."""
import os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ["ROC"]
WORK = os.environ.get("WORK", ROOT + "/.work")
MUT = WORK + "/mut"

L = "cli/lib/"
SC, RM, IN, RP, LK, RS, RV, IS, LD, RU = [L + n + ".roc" for n in ["Scan", "Removal", "Intent", "Report", "Locked", "Resolve", "Remove", "Install", "Ladder", "Run"]]
L2, L3 = "l2:remove/", "l3:remove/"

# (id, rules, file, old text, new text, tests)
M = [
    # Scan (l0:scan)
    ("S1", "R-RV2 Q5", SC, "Text.resolve(facts.project_dir, name.drop_prefix(\"/\"))", "Text.resolve(Text.dir_of(facts.file), name.drop_prefix(\"/\"))", ["l0:scan"]),
    ("S3", "R-LD7", SC, "App => [facts.file]", "App => []", ["l0:scan"]),
    ("S5", "R-RV2", SC, "Package(found) if found == alias", "Package(found) if found.starts_with(alias)", ["l0:scan"]),
    ("S6", "R-RV2", SC, " or facts.seen.contains(file)", "", ["l0:scan"]),
    ("S8", "R-RV2", SC, "if found.contains(file) or", "if", ["l0:scan"]),
    ("S9", "R-RV2", SC, "text: line.trim_end()", "text: line", ["l0:scan"]),
    ("S10", "R-RV2", SC, ".get(i.line - 1)", ".get(i.line)", ["l0:scan"]),
    # Removal (l0:removal)
    ("M1", "Q3", RM, "Ok(file) if !facts.shared =>", "Ok(file) =>", ["l0:removal"]),
    ("M2", "R-FL13", RM, "if read.frozen {", "if read.frozen and !read.names.is_empty() {", ["l0:removal"]),
    ("M3", "Q2", RM, "if read.names.is_empty() {", "if read.names.len() > 50 {", ["l0:removal"]),
    ("M5", "R-RV3", RM, "if row.is_platform {", 'if row.alias == "pf" {', ["l0:removal"]),
    ("M6", "R-RV5", RM, "Path => Path(row.value)", "Path => Foreign(row.value)", ["l0:removal"]),
    ("M8", "R-RV4", RM, '".talon/patches/${facts.alias}/"', '".talon/patches/${facts.alias}"', ["l0:removal"]),
    ("M10", "R-RV4", RM, "keys.any(|k| k.table == Patch)", "keys.any(|k| k.table == Overrides)", ["l0:removal"]),
    # Intent (l0:intent)
    ("I1", "R-CM3", IN, "Err(NoEntry) => Err(Fail.new(Internal, \"${path}: the key '${k.key}' is not there\"))", "Err(NoEntry) => Ok(doc)", ["l0:intent"]),
    ("I2", "R-OV1", IN, 'Overrides => "overrides"', 'Overrides => "dependencies"', ["l0:intent"]),
    ("I3", "R-CC7", IN, "Toml.get(doc, [Intent.table_name(k.table), k.key])", 'Toml.get(doc, ["dependencies", k.key])', ["l0:intent"]),
    # Report, Locked, Ladder (l0)
    ("P1", "R-OUT4", RP, '("removed", Arr(o.removed.map(removed_doc))),', '("removed", Arr([])),', ["l0:report"]),
    ("P3", "R-OUT4", RP, "version = match r.version {\n\t\tOk(v) => Text(v)\n\t\tErr(None) => Null", 'version = match r.version {\n\t\tOk(v) => Text(v)\n\t\tErr(None) => Text("")', ["l0:report"]),
    ("K1", "R-RV5", LK, 'if !locked.rows.any(|r| r.alias == alias) return Err(internal("${alias} is not in the header"))', "check_row(locked, alias)?", ["l0:locked"]),
    ("G1", "G1", LD, 'moved_text = |owners| if owners.is_empty() ""', 'moved_text = |owners| if owners.len() > 99 ""', ["l0:ladder"]),
    # Resolve.remove! (L3, L2)
    ("F1", "R-RV2", RS, "if !imported.is_empty() and !facts.force return", "if !imported.is_empty() return", [L3]),
    ("F2", "Q4", RS, "skip_check = request.no_check or forced", "skip_check = request.no_check or facts.force or forced", [L3]),
    ("F3", "R-RV2", RS, "skip_check = request.no_check or forced", "skip_check = request.no_check or (forced and request.frozen)", [L3]),
    ("F4", "Q3", RS, "m.file != member.file and ", "m.file == member.file and ", [L3]),
    ("F6", "R-CC1", RS, "paths = toml_paths.concat([facts.file])", "paths = [facts.file].concat(toml_paths)", [L2]),
    ("F8", "R-RV1", RS, ". tln remove moves no other entry. Pass --no-check to remove ", ". Pass --no-check to remove ", [L2]),
    ("F11", "R-LD7", RS, "probes: if member.locked.kind == App 3 else 2", "probes: 3", [L2]),
    ("F13", "R-RV5", RS, "Path(path) => { alias, kind: Path,", "Path(path) => { alias, kind: Foreign,", [L3]),
    ("F16", "R-RP3", RS, "no_check: skip_check,\n\t\t})?", "no_check: Bool.True,\n\t\t})?", [L3]),
    ("F19", "R-RV2", RS, "$seen = seen\n", "$seen = [member.file]\n", [L2]),
    ("F20", "R-CC7", RS, "spans_now: spans(f.now)", "spans_now: spans(read)", [L2]),
    ("F23", "R-RV1", RS, "if fail.kind == NoTuple {", "if fail.kind == Internal {", [L2]),
    # Remove.run! and the helpers of Install (L3, L2)
    ("C1", "R-WS12", RV, "Install.check_member(Bool.True, start.project)?", "Install.check_member(Bool.False, start.project)?", [L3]),
    ("C2", "R-J3", RV, "fx.out!(Out.json_ok({ command: args.typed,", 'fx.out!(Out.json_ok({ command: "remove",', [L3]),
    ("C6", "R-CM3", RV, "{ names: opts.names, force: opts.force },", "{ names: opts.names, force: Bool.False },", [L3]),
    ("C8", "R-SO7", RV, "compiler = Install.on_path!(fx)", "compiler = Err(NoCompiler)", [L2]),
    ("C9", "R-FL4", IS, "if args.quiet {\n\t\t{ ..fx, out!: |_text| {} }", "if args.quiet and args.offline {\n\t\t{ ..fx, out!: |_text| {} }", [L3]),
    ("W1", "R-CM3", RU, 'args.command == ["remove"]', 'args.command == ["removex"]', [L3]),
]


def build(what):
    os.makedirs(MUT, exist_ok=True)
    src, out = ("cli/main.roc", MUT + "/tln") if what == "tln" else ("tests/commands/main.roc", MUT + "/l2")
    if os.path.exists(out):
        os.remove(out)
    p = subprocess.run([ROC, "build", src, f"--output={out}"], cwd=ROOT, env=dict(os.environ), capture_output=True, text=True, timeout=900)
    return p.returncode, p.stdout + p.stderr


def run(test):
    kind, what = test.split(":")
    env = dict(os.environ)
    if kind == "l0":
        cmd = [ROC, "test", f"tests/unit/{what}.roc", "--no-cache"]
    elif kind == "l2":
        rc, out = build("l2")
        if rc != 0:
            return rc, "build of l2 failed\n" + out
        env["L2BIN"] = MUT + "/l2"
        cmd = ["tests/commands/run.sh", what]
    else:
        rc, out = build("tln")
        if rc != 0:
            return rc, "build of tln failed\n" + out
        env["TLN"] = MUT + "/tln"
        cmd = ["tests/run.sh", what]
    p = subprocess.run(cmd, cwd=ROOT, env=env, capture_output=True, text=True, timeout=900)
    return p.returncode, p.stdout + p.stderr


def main():
    flt = sys.argv[1:]
    dry = os.environ.get("DRY") == "1"
    print("| Id | Rules | Mutation | Result |\n| --- | --- | --- | --- |")
    for mid, ids, rel, old, new, tests in M:
        if flt and mid not in flt:
            continue
        path = f"{ROOT}/{rel}"
        text = open(path).read()
        if old not in text:
            print(f"| {mid} | {ids} | {rel}: pattern not found | INVALID |", flush=True)
            continue
        if dry:
            print(f"| {mid} | {ids} | found | |", flush=True)
            continue
        open(path, "w").write(text.replace(old, new, 1))
        result = "NOT CAUGHT"
        try:
            for test in tests:
                rc, out = run(test)
                compile_error = re.search(r"^\s*[1-9][0-9]* compiler errors?", out, re.M) is not None or "Compilation failed" in out or re.search(r"^build of .* failed", out, re.M) is not None or re.search(r"^\s*[1-9][0-9]* errors?", out, re.M) is not None and "FAIL" not in out and "failed" not in out
                if rc != 0 and compile_error:
                    result = "INVALID (compile error)"
                    print(out[-1500:], file=sys.stderr)
                    break
                if rc != 0:
                    names = re.findall(r"^FAIL (\S+)", out, re.M)
                    result = f"caught by {test}" + (f" ({', '.join(names)})" if names else "")
                    break
        finally:
            open(path, "w").write(text)
        short = old[:50].replace("\n", " ").replace("\t", " ").replace("|", "/").strip()
        print(f"| {mid} | {ids} | `{short}` | {result} |", flush=True)


main()
