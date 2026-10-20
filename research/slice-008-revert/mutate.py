#!/usr/bin/env python3
"""Revert check of slice 008 (TW12). Usage: research/slice-008-revert/mutate.py [id ...]   (DRY=1: only test that each pattern is found)
Each row is one small change of the private reference implementation and the tests that must fail. A compile error is INVALID, not a catch.
The reference implementation was deleted after the run, so the `old` texts do not match the code of the repository: this file and results.md are the record of the check.
The file is put back after each run. Needs ROC (scripts/env.sh sets it). Output is a table."""
import os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ["ROC"]

SC, RM, IN, RP, LK, RS, RV = ["cli/lib/" + n + ".roc" for n in ["Scan", "Removal", "Intent", "Report", "Locked", "Resolve", "Remove"]]
L3A, L3B, L2 = "l3:remove/rm1", "l3:remove/rm2", "l2:remove/rm1-flow"

# (id, rules, file, old text, new text, tests)
M = [
    # Scan (l0:scan)
    ("S1", "R-RV2 Q5", SC, "else facts.project_dir\n", "else Text.dir_of(facts.file)\n", ["l0:scan"]),
    ("S2", "R-RV2 Q5", SC, 'facts.name.starts_with("./") or facts.name.starts_with("../")', 'facts.name.starts_with("../")', ["l0:scan"]),
    ("S3", "R-RV2 Q5", SC, 'Text.resolve(base, "${facts.name}.roc")', '"${base}/${facts.name}.roc"', ["l0:scan"]),
    ("S4", "R-LD7", SC, "App => [facts.file]", "App => facts.exposed.map(|name| Scan.local_file({ project_dir: Text.dir_of(facts.file), file: facts.file, name }))", ["l0:scan"]),
    ("S5", "R-LD7", SC, "_ => facts.exposed.map(", "_ => [facts.file].concat(facts.exposed).map(", ["l0:scan"]),
    ("S6", "R-RV2", SC, "if alias == facts.alias {", "if alias.starts_with(facts.alias) {", ["l0:scan"]),
    ("S7", "R-RV2", SC, "!facts.seen.contains(file) and ", "", ["l0:scan"]),
    ("S8", "R-RV2", SC, "!facts.sources.any(|s| s.path == file) and ", "", ["l0:scan"]),
    ("S9", "R-RV2", SC, " and !$next.contains(file) {", " {", ["l0:scan"]),
    ("S10", "R-RV2", SC, '.drop_suffix("\\r")', "", ["l0:scan"]),
    ("S11", "R-RV2", SC, "lines.get(found.line - 1)", "lines.get(found.line)", ["l0:scan"]),
    ("S12", "R-RV2", SC, "Local => {\n\t\t\t\t\t\tfile = Scan.local_file", "Local => if Bool.False {\n\t\t\t\t\t\tfile = Scan.local_file", ["l0:scan"]),
    # Removal (l0:removal)
    ("M1", "R-FL5", RM, 'Ok(value) if value != "direct" =>', 'Ok(value) if value != value =>', ["l0:removal"]),
    ("M2", "R-FL10", RM, 'if value != "highest" and value != "lowest" =>', 'if value != "highest" =>', ["l0:removal"]),
    ("M3", "R-FL13", RM, 'if given("--frozen") {', "if Bool.False {", ["l0:removal"]),
    ("M4", "Q2", RM, "if args.operands.is_empty() {", "if Bool.False {", ["l0:removal"]),
    ("M5", "R-CM3", RM, 'force: given("--force")', "force: Bool.False", ["l0:removal"]),
    ("M6", "R-LF4", RM, 'dry_run: given("--dry-run")', 'dry_run: given("--force")', ["l0:removal"]),
    ("M7", "R-LF3", RM, 'no_check: given("--no-check")', "no_check: Bool.False", ["l0:removal"]),
    ("M8", "R-RV3", RM, "Ok(row) => if row.is_platform {", "Ok(row) => if row.alias == \"pf\" {", ["l0:removal"]),
    ("M9", "R-RV5", RM, "Path => Path(row.value)\n\t\t\t\tForeign => Foreign(row.value)", "Path => Foreign(row.value)\n\t\t\t\tForeign => Path(row.value)", ["l0:removal"]),
    ("M10", "R-CM3", RM, "version: ident.version })", "version: ident.series })", ["l0:removal"]),
    ("M11", "Q3", RM, "keys = if facts.shared {", "keys = if Bool.False {", ["l0:removal"]),
    ("M12", "R-RV4", RM, '"${Text.dir_of(t.path)}/.talon/patches/${facts.alias}/"', '"${Text.dir_of(t.path)}/.talon/patches/${facts.alias}"', ["l0:removal"]),
    ("M13", "R-RV4", RM, '"${Text.dir_of(t.path)}/.talon/patches/${facts.alias}/"', '"${Text.dir_of(facts.alias)}/.talon/patches/${facts.alias}/"', ["l0:removal"]),
    ("M14", "R-OV1", RM, '[(Dependencies, "dependencies"), (Overrides, "overrides"), (Patch, "patch")]', '[(Patch, "patch"), (Overrides, "overrides"), (Dependencies, "dependencies")]', ["l0:removal"]),
    ("M15", "R-OV1", RM, '(Overrides, "overrides"), ', "", ["l0:removal"]),
    ("M16", "R-RV4", RM, "found.any(|k| k.table == Patch)", "found.any(|k| k.table == Overrides)", ["l0:removal"]),
    ("M17", "R-WS14", RM, "Err(NoToml) => Ok([])\n\t\t\t\t\tOk(t) => keys_of", "Err(NoToml) => Ok([{ table: Dependencies, key: facts.alias }])\n\t\t\t\t\tOk(t) => keys_of", ["l0:removal"]),
    ("M18", "R-RV3", RM, 'An app needs a platform. Use tln add --platform <name> to change it."))', 'An app needs a platform. Use tln add --platform to change it."))', ["l0:removal"]),
    ("M19", "R-EC2", RM, "Err(Fail.new(Usage, \"${facts.alias} is the platform", "Err(Fail.new(AppError, \"${facts.alias} is the platform", ["l0:removal"]),
    # Intent (l0:intent)
    ("I1", "R-OV1", IN, 'Overrides => "overrides"\n\tPatch => "patch"', 'Overrides => "dependencies"\n\tPatch => "patch"', ["l0:intent"]),
    ("I2", "R-RV4", IN, 'Patch => "patch"\n}\n\nremove_key', 'Patch => "overrides"\n}\n\nremove_key', ["l0:intent"]),
    ("I3", "R-CM3", IN, 'Err(NoEntry) => Err(Fail.new(Internal, "${path}: the key \'${k.key}\' is not there"))', "Err(NoEntry) => Ok(doc)", ["l0:intent"]),
    ("I4", "R-CC7", IN, "Toml.get(doc, [table_name(k.table), k.key])", 'Toml.get(doc, ["dependencies", k.key])', ["l0:intent"]),
    ("I5", "R-RV1", IN, "Ok(doc) => facts.keys.fold_try(doc, |current, k| remove_key", "Ok(doc) => facts.keys.take_first(1).fold_try(doc, |current, k| remove_key", ["l0:intent"]),
    # Report (l0:report)
    ("P1", "R-OUT4", RP, '("probes", Num(o.probes.to_i64_wrap())),\n\t\t("dry_run", Flag(o.dry_run)),', '("dry_run", Flag(o.dry_run)),\n\t\t("probes", Num(o.probes.to_i64_wrap())),', ["l0:report"]),
    ("P2", "R-OUT4", RP, 'Path => "path"', 'Path => "file"', ["l0:report"]),
    ("P3", "R-OUT4", RP, "Err(None) => Null\n\t\t\t\t\t\t\t},\n\t\t\t\t\t\t),\n\t\t\t\t\t]),", 'Err(None) => Text("")\n\t\t\t\t\t\t\t},\n\t\t\t\t\t\t),\n\t\t\t\t\t]),', ["l0:report"]),
    ("P4", "R-RV4", RP, '("patches", Arr(o.patches.map(|p| Obj([("alias", Text(p.alias)), ("dir", Text(p.dir))])))),', '("patches", Arr([])),', ["l0:report"]),
    ("P5", "R-LF3", RP, '("build", step_doc(o.build)),\n\t\t(\n\t\t\t"removed"', '("build", step_doc(o.check)),\n\t\t(\n\t\t\t"removed"', ["l0:report"]),
    ("P6", "R-OUT4", RP, '("table", Text(t.table))', '("table", Text(t.key))', ["l0:report"]),
    # Locked (l0:locked)
    ("K1", "R-RV5", LK, 'if !locked.rows.any(|r| r.alias == alias) return Err(internal("${alias} is not in the header"))', "check_row(locked, alias)?", ["l0:locked"]),
    ("K2", "R-RV5", LK, 'if !locked.rows.any(|r| r.alias == alias) return', 'if Bool.False return', ["l0:locked"]),
    # Resolve.remove! (L3, L2)
    ("F1", "R-RV2", RS, "if !hits.is_empty() and !facts.force {", "if !hits.is_empty() {", [L3A]),
    ("F2", "R-RV2", RS, "skip = request.no_check or forced", "skip = request.no_check or (forced and request.frozen)", [L3A]),
    ("F3", "Q4", RS, "skip = request.no_check or forced", "skip = request.no_check or facts.force or (forced and request.frozen)", [L3A]),
    ("F4", "Q3", RS, "loaded.members.any(|m| m.file != current and ", "loaded.members.any(|m| ", [L3A, L3B]),
    ("F5", "Q3", RS, "and m.locked.rows.any(|r| r.alias == alias))", "and m.locked.rows.any(|r| r.alias == alias) and Bool.False)", [L3B]),
    ("F6", "R-CC1", RS, "else [plan.toml_path, plan.header]", "else [plan.header, plan.toml_path]", [L2]),
    ("F7", "R-RV2", RS, "for note in force_notes {\n\t\t\tfx.out!(\"note: ${note}\\n\")\n\t\t}", "", [L3A]),
    ("F8", "R-RV1", RS, ". tln remove moves no other entry. Pass --no-check", ". Pass --no-check", [L2]),
    ("F9", "R-RV2", RS, "results = if unknown.is_empty() [] else fx.read_files!(unknown)", "results = if $pending.is_empty() [] else fx.read_files!($pending)", [L2]),
    ("F10", "R-LF4", RS, "if request.dry_run return Ok(paths)", "if request.dry_run and request.frozen return Ok(paths)", [L3A]),
    ("F11", "R-LD7", RS, "probes: if member.locked.kind == App 3 else 2", "probes: 3", [L2]),
    ("F12", "R-RV4", RS, 'fx.out!("kept: ${pt.dir} (the patch files of ${pt.alias})\\n")', 'fx.err!("kept: ${pt.dir} (the patch files of ${pt.alias})\\n")', [L3A]),
    ("F13", "R-RV5", RS, "Path(value) => { alias, kind: Path, name: value, version: Err(None) }", "Path(value) => { alias, kind: Foreign, name: value, version: Err(None) }", [L3A]),
    ("F14", "R-CM3", RS, "if !$aliases.contains(alias) {", "if $aliases.len() < 100 {", [L3A]),
    ("F15", "R-RV1", RS, "owners = rows.keep_oks(", "owners = rows.take_first(0).keep_oks(", [L2]),
    ("F16", "R-RP3", RS, "no_check: skip,\n\t\t})?\n\t\tif !skip {", "no_check: Bool.True,\n\t\t})?\n\t\tif !skip {", [L3A]),
    ("F17", "R-RV1", RS, "check: ran.check,\n\t\t\tbuild: ran.build,\n\t\t\tremoved,", "check: ran.build,\n\t\t\tbuild: ran.check,\n\t\t\tremoved,", [L3A, L2]),
    ("F18", "R-RV4", RS, "plans.keep_oks(|(alias, p)| p.patch_dir.map_ok(|dir| { alias, dir }))", "[]", [L3A]),
    ("F19", "R-RV2", RS, "$seen = $seen.concat($next)", "$seen = $seen", [L2]),
    ("F20", "R-CC7", RS, "spans_now = if is_header Locked.spans({ text: now, ops: plan.ops }) else Intent.table_spans({ text: now, keys: plan.keys })", "spans_now = spans_read", [L2]),
    # Remove.run! (L3, L2)
    ("C1", "R-WS12", RV, '(Ok(ws), Err(NoCurrent)) => Err(', '(Ok(ws), Ok(_)) => Err(', [L3B]),
    ("C2", "R-J3", RV, "command: args.typed, data: Report.remove_data(outcome)", 'command: "remove", data: Report.remove_data(outcome)', [L3A]),
    ("C3", "R-LF4", RV, 'if opts.dry_run {\n\t\t\t\t\t\tshown.out!("dry run: nothing was written\\n")', 'if opts.dry_run and args.json {\n\t\t\t\t\t\tshown.out!("dry run: nothing was written\\n")', [L3A]),
    ("C4", "R-FL4", RV, "if args.quiet {\n\t{ ..fx, out!: |_text| {} }", "if args.quiet and args.offline {\n\t{ ..fx, out!: |_text| {} }", [L3A]),
    ("C5", "R-J2", RV, "} else if args.json {\n\t{ ..fx, out!: |text| fx.err!(text) }", "} else if args.json and args.offline {\n\t{ ..fx, out!: |text| fx.err!(text) }", [L3A]),
    ("C6", "R-PD9", RV, "Known.record!(fx, { roots, files: canonical_files!(fx, project), now })?", "Known.record!(fx, { roots, files: [], now })?", [L3B, L2]),
    ("C7", "R-SO7", RV, 'fx.programs!(["roc"])', 'fx.programs!(["rocx"])', [L2]),
    ("C8", "R-LF4", RV, "dry_run: opts.dry_run,", "dry_run: Bool.False,", [L3A]),
    ("C9", "R-LF3", RV, "no_check: opts.no_check,", "no_check: Bool.False,", [L3A]),
    ("C10", "R-CM3", RV, "{ names: opts.names, force: opts.force },", "{ names: opts.names, force: Bool.False },", [L3A]),
    ("C11", "R-PD9", RV, "Err(Standalone) => match project.file {\n\t\t\tOk(file) => [file]", "Err(Standalone) => match project.file {\n\t\t\tOk(_) => []", [L3A, L2]),
    # Run (L3)
    ("W1", "R-CM3", "cli/lib/Run.roc", 'else if args.command == ["remove"] {\n\t\t\t\t\t\t\tRemove.run!(fx, args)', 'else if args.command == ["removex"] {\n\t\t\t\t\t\t\tRemove.run!(fx, args)', [L3A]),
]


def run(test):
    kind, what = test.split(":")
    if kind == "l0":
        cmd = [ROC, "test", f"tests/unit/{what}.roc", "--no-cache"]
    elif kind == "l2":
        cmd = ["tests/commands/run.sh", what]
    else:
        cmd = ["tests/run.sh", what]
    p = subprocess.run(cmd, cwd=ROOT, env=dict(os.environ), capture_output=True, text=True, timeout=900)
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
                compile_error = re.search(r"^\s*[1-9][0-9]* compiler errors?", out, re.M) is not None or "Compilation failed" in out or re.search(r"^build of .* failed", out, re.M) is not None
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
