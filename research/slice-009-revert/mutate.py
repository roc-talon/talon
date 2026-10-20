#!/usr/bin/env python3
"""Revert check of slice 009 (TW12). Usage: research/slice-009-revert/mutate.py [id ...]   (DRY=1: only test that each pattern is found)
Each row is one small change of the private reference implementation and the tests that must fail. A compile error is INVALID, not a catch.
The reference implementation was deleted after the run, so the `old` texts do not match the code of the repository: this file and results.md are the record of the check.
The file is put back after each run. Needs ROC (scripts/env.sh sets it). Output is a table."""
import os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ["ROC"]

def f(n): return "cli/lib/" + n + ".roc"
UP, VF, PK, PR, LD, AD, RS, RN = f("Update"), f("Verify"), f("Picker"), f("Probe"), f("Ladder"), f("Add"), f("Resolve"), f("Run")
A, B, C, D = "l0:update", "l0:picker", "l0:verify", "l0:add"
L2U, L2V, L3U, L3V = "l2:update/up1-flow", "l2:verify/vf1-flow", "l3:update/up1", "l3:verify/vf1"
OLD = ["l2:resolve/rs-failures", "l2:resolve/rs-new-toml", "l2:resolve/rs-update-scope"]

# (id, rules, file, old text, new text, tests)
M = [
    # Update.read (l0:update)
    ("U1", "R-FL13", UP, 'if given("--frozen") return Err(Fail.new(Usage, "flag', 'if Bool.False return Err(Fail.new(Usage, "flag', [A]),
    ("U2", "Q1 R-NR4", UP, "if pick and !opts.names.is_empty() return", "if pick and Bool.False return", [A]),
    ("U3", "R-SP4", UP, 'pick = given("-i")', "pick = Bool.False", [A]),
    ("U5", "R-FL5", UP, "opts = Opts.read(without)?", "opts = Opts.read(args)?\n\t\t_ = without", [A]),
    ("U6", "Q1", UP, 'Usage, "update -i picks the packages: do not name packages"', 'Usage, "update -i picks packages: do not name packages"', [A]),
    # Verify.read (l0:update)
    ("V1", "R-FL14", VF, 'if given("--frozen") return Err(Fail.new(Usage, "tln verify', 'if Bool.False return Err(Fail.new(Usage, "tln verify', [A]),
    ("V2", "R-FL14", VF, 'if given("--dry-run") return', "if Bool.False return", [A]),
    ("V3", "Q6", VF, "if !opts.names.is_empty() return", "if Bool.False return", [A]),
    ("V4", "R-FL14", VF, "opts = Opts.read(without)?", "opts = Opts.read(args)?\n\t\t_ = without", [A]),
    ("V5", "R-FL14", VF, 'given("--dry-run") return Err(Fail.new(Usage, "tln verify writes nothing, so it rejects --dry-run"))', 'given("--dry-run") return Err(Fail.new(Usage, "tln verify writes nothing, so it rejects --frozen"))', [A]),
    # Picker (l0:picker)
    ("K1", "R-SP14", PK, ".count_utf8_bytes()).max() ?? 0) + 2", ".count_utf8_bytes()).max() ?? 0) + 1", [B]),
    ("K2", "R-SP14", PK, '"  ${(i + 1).to_str()}) ${item.alias}', '"  ${i.to_str()}) ${item.alias}', [B]),
    ("K3", "R-SP14", PK, '"update can move these packages:\\n${', '"update can move packages:\\n${', [B]),
    ("K4", "Q2", PK, 'facts.line.replace_each(",", " ")', "facts.line", [B]),
    ("K5", "Q2", PK, "Ok(n) => if n >= 1 and n <= items.len() {", "Ok(n) => if n >= 0 and n <= items.len() {", [B]),
    ("K6", "Q2", PK, "n >= 1 and n <= items.len() {", "n >= 1 and n < items.len() {", [B]),
    ("K7", "R-SP11", PK, "Ok(aliases) => Ok(facts.items.map(|i| i.alias).keep_if(|a| aliases.contains(a)))", "Ok(aliases) => Ok(aliases)", [B]),
    ("K8", "Q2", PK, "Ok(aliases) => Ok(facts.items.map(|i| i.alias).keep_if(|a| aliases.contains(a)))", "Ok(aliases) => Ok(facts.items.map(|i| i.alias).keep_if(|a| aliases.contains(a)).take_first(1))", [B]),
    ("K9", "Q2", PK, "Err(_) => match items.find_first(|i| i.alias == word) {", "Err(_) => match items.find_first(|i| i.alias.starts_with(word)) {", [B]),
    ("K10", "Q2", PK, 'Err(_) => Err(Invalid)\n\t\t\tOk(aliases)', 'Err(_) => Ok([])\n\t\t\tOk(aliases)', [B]),
    ("K11", "Q2", PK, 'split_on(" ").keep_if(|w| w != "")', 'split_on(" ")', [B]),
    ("K12", "R-SP14", PK, '${item.name} ${item.version}', '${item.version} ${item.name}', [B]),
    # Probe, Ladder (l0:verify)
    ("R1", "R-CM11", PR, '["--replace-dep", r.old, r.new]', '["--replace", r.old, r.new]', [C]),
    ("R2", "R-CM11", PR, '["--replace-dep", r.old, r.new]', '["--replace-dep", r.new, r.old]', [C]),
    ("R3", "R-CM11", PR, "Probe.args({ command: facts.command, file: facts.file }).concat(facts.replace.join_map(", "Probe.args({ command: facts.command, file: facts.file }).concat(facts.replace.take_first(0).join_map(", [C]),
    ("R4", "R-CM11", PR, "facts.replace.join_map(|r| [", "facts.replace.take_first(1).join_map(|r| [", [C]),
    ("P1", "R-LB2", LD, "spec(Probe.replace_args({ command: Check, file: facts.file, replace: facts.replace }))],", "spec(Probe.args({ command: Check, file: facts.file }))],", [C]),
    ("P2", "R-LB2", LD, "App => Ok(spec(Probe.replace_args({ command: Build({ output: output }), file: facts.file, replace: facts.replace })))", "App => Ok(spec(Probe.args({ command: Build({ output: output }), file: facts.file })))", [C]),
    ("P3", "R-LD7", LD, "Package | Platform => Err(None)\n\t\t}\n\t\t{\n\t\t\tfirst: [spec(Probe.args", "Package => Ok(spec(Probe.args({ command: Check, file: facts.file })))\n\t\t\tPlatform => Err(None)\n\t\t}\n\t\t{\n\t\t\tfirst: [spec(Probe.args", [C]),
    ("P4", "R-LD6", LD, 'output = Text.join(facts.tmp, "tln-probe.out")\n\t\tbuild', 'output = Text.join(facts.dir, "tln-probe.out")\n\t\tbuild', [C]),
    ("P5", "R-BL1", LD, "first: [spec(Probe.args({ command: Check, file: facts.file })), spec(Probe.replace_args", "first: [spec(Probe.replace_args({ command: Check, file: facts.file, replace: facts.replace })), spec(Probe.replace_args", [C]),
    # Add (l0:add)
    ("N1", "R-SE7", AD, 'platform changes: ${facts.from.name} ${facts.from.version} -> ${facts.to.name} ${facts.to.version}"', 'platform change: ${facts.from.name} ${facts.from.version} -> ${facts.to.name} ${facts.to.version}"', [D]),
    ("N2", "R-SE7", AD, '${facts.from.version} -> ${facts.to.name} ${facts.to.version}"\n\n\t## R-SL12 for', '${facts.from.version} -> ${facts.to.version}"\n\n\t## R-SL12 for', [D]),
    ("N3", "R-SL12", AD, '" Close versions: ${Str.join_with(close, ", ")}."', '"Close versions: ${Str.join_with(close, ", ")}."', [D]),
    ("N4", "R-SL12", AD, "close = ", "close = ", [D]) if False else ("N4", "R-SL12", AD, '\t\t[] => ""\n\t\tclose => " Close', '\t\t[] => " Close versions: none."\n\t\tclose => " Close', [D]),
    # Ladder.verify!
    ("L1", "R-CC2", LD, "\tresult = verify_in!(fx, request, member, tmp)\n\t_ = fx.delete!([tmp])", "\tresult = verify_in!(fx, request, member, tmp)", [L2V]),
    ("L2", "R-LD6", LD, "\tmatch fx.make_dirs!([tmp]) {\n\t\tOk(_) => {}\n\t\tErr(_) => return Err(Fail.new(Environment, \"cannot make ${tmp}\"))\n\t}\n", "", [L2V]),
    ("L3", "R-BL1", LD, "checked = Ladder.check({ output: first.1, dir, pkgs, baseline, owners: request.owners, moved: request.moved, compiler, timeout })?\n\tmatch plan.build {", "checked = Ladder.check({ output: first.0, dir, pkgs, baseline, owners: request.owners, moved: request.moved, compiler, timeout })?\n\tmatch plan.build {", [L2V]),
    ("L4", "R-LD7", LD, "built = Ladder.build({ output, dir, pkgs, baseline, owners: request.owners, compiler, timeout })?\n\t\t\t\tOk(checked.lines.concat(built.lines))", "built = Ladder.build({ output, dir, pkgs, baseline, owners: request.owners, compiler, timeout })?\n\t\t\t\tOk(checked.lines.concat(built.lines.take_first(0)))", [L2V]),
    ("L5", "R-PP3", LD, "plan = Ladder.plan_replace({ compiler, kind: member.kind, dir, file, tmp, replace: request.replace, timeout })\n\tfirst = match fx.probes!(plan.first) {\n\t\t[base, candidate] => (base, candidate)\n\t\t_ => return Err(no_answer(\"the probes\"))\n\t}\n\tbaseline = Ladder.baseline({ output: first.0, dir, pkgs", "plan = Ladder.plan_replace({ compiler, kind: member.kind, dir, file, tmp, replace: request.replace, timeout })\n\tfirst = match fx.probes!(plan.first) {\n\t\t[base, candidate] => (candidate, base)\n\t\t_ => return Err(no_answer(\"the probes\"))\n\t}\n\tbaseline = Ladder.baseline({ output: first.0, dir, pkgs", [L2V]),
    ("L6", "R-PH7", LD, "Compiler.require({ id: request.held, path_roc: request.path_roc })?\n\t\tvar $lines = no_lines\n\t\tvar $notes = no_lines\n\t\tfor member in request.members {\n\t\t\tfor line in verify_member!", "var $lines = no_lines\n\t\tvar $notes = no_lines\n\t\tfor member in request.members {\n\t\t\tfor line in verify_member!", [L2V]),
    # Resolve
    ("F1", "Q3 R-I5", RS, "Err(None) => if request.command == Update {\n\t\t\t\t{}", "Err(None) => if request.command == Install and Bool.False {\n\t\t\t\t{}", [L2U, L3U]),
    ("F2", "R-SE7", RS, "\tfor note in platform_notes {\n\t\tfx.out!(\"note: ${note}\\n\")\n\t}\n", "", [L2U, L3U, L2V, "l2:resolve/rs-update-scope"]),
    ("F3", "R-SE7", RS, "|(s, c)| if s.variable.is_platform {\n\t\t\t\tset_edits", "|(s, c)| if !s.variable.is_platform {\n\t\t\t\tset_edits", [L2U, L3U, "l2:resolve/rs-update-scope"]),
    ("F4", "R-SE7", RS, "notes: pick_notes.concat(platform_notes).concat(plan.notes)", "notes: pick_notes.concat(plan.notes)", [L3U]),
    ("F5", "R-SE7", RS, ".fold([], |found, text| if found.contains(text) found else found.append(text))\n\tfor note in platform_notes", ".fold([], |found, text| found.append(text))\n\tfor note in platform_notes", [L3U, L2V]),
    ("F6", "Q5 R-SL12", RS, '{ ..fail, message: "${fail.message}${Add.close_note({ selector: Ok(pick.selector), versions })}" }', '{ ..fail, message: "${fail.message}${Add.close_note({ selector: Ok(pick.selector), versions: versions.take_first(0) })}" }', [L3U] + OLD),
    ("F7", "Q5", RS, '[pick, ..] if fail.message.contains("has no release that satisfies") =>', '[pick, ..] =>', [L3U] + ["l2:resolve/rs-failures"]),
    ("F8", "Q8 R-H4", RS, "if request.command == Update and loaded.members.any(|m| m.locked.rows.any(|r| r.alias == ref.name and r.what == Path))", "if request.command == Update and loaded.members.is_empty()", [L3U]),
    ("F9", "R-SP14", RS, ".keep_if(|v| v.host == Indexed)\n\t\t\t\t.keep_oks(", ".keep_oks(", [L2U, L2V, L3U]),
    ("F10", "R-CM11", RS, "pins = if facts.verify [] else decision.writes", "pins = if facts.verify and decision.writes.is_empty() [] else decision.writes", [L2V]),
    ("F11", "R-CM11", RS, "written: if request.dry_run or done.verify [] else done.touched", "written: if request.dry_run [] else done.touched", [L3V]),
    ("F12", "R-CM11", RS, "if touched.is_empty() and kept.is_empty() and !facts.verify {", "if touched.is_empty() and kept.is_empty() {", [L2V, L3V]),
    ("F13", "R-CM11 Q4", RS, "ran = if facts.verify {\n\t\tverify_ladder!(fx, request, loaded, { scoped, chosen, decision, changes })?\n\t} else if changes.is_empty() {", "ran = if facts.verify and !changes.is_empty() {\n\t\tverify_ladder!(fx, request, loaded, { scoped, chosen, decision, changes })?\n\t} else if changes.is_empty() {", [L2V, L3V]),
    ("F14", "R-LF3", RS, "if request.no_check {\n\t\tfx.out!(\"check: skipped\\n\")\n\t\tOk({ probes: 0, check: Skipped, build: Skipped, notes: [] })\n\t} else {\n\t\tcount = facts.scoped.len()\n\t\tpairs", "if request.no_check and !request.no_check {\n\t\tfx.out!(\"check: skipped\\n\")\n\t\tOk({ probes: 0, check: Skipped, build: Skipped, notes: [] })\n\t} else {\n\t\tcount = facts.scoped.len()\n\t\tpairs", [L3V]),
    ("F15", "R-CM11", RS, "replace = pairs\n\t\t\t.join_map(|(s, c)| s.variable.uses.keep_if(|u| u.url != c.url)", "replace = pairs\n\t\t\t.join_map(|(s, c)| s.variable.uses", [L2V]),
    ("F16", "R-CM11", RS, ".fold([], |found, r| if found.any(|f| f.old == r.old and f.new == r.new) found else found.append(r))", ".fold([], |found, r| found.append(r))", [L2V, L3V]),
    ("F17", "R-LD7", RS, "probes: members.fold(0, |total, m| total + if m.kind == App 3 else 2),\n\t\t\tcheck: Passed,\n\t\t\tbuild: if members.any(|m| m.kind == App) Passed else NotRun,\n\t\t\tnotes,\n\t\t})\n\t}\n}\n\n# R-SL12", "probes: members.len() * 3,\n\t\t\tcheck: Passed,\n\t\t\tbuild: if members.any(|m| m.kind == App) Passed else NotRun,\n\t\t\tnotes,\n\t\t})\n\t}\n}\n\n# R-SL12", [L3V]),
    ("F18", "R-CM11", RS, "decision = Pin.decide({\n\t\t\tmembers: loaded.members.map(|m| { file: m.file, pin: m.locked.roc, changes: Bool.False }),\n\t\t\tcompiler: request.compiler,\n\t\t\treq: loaded.intent.toolchain.roc,\n\t\t\tnightly: settings.nightly,\n\t\t\tno_check: request.no_check,\n\t\t})?\n\t\tresolve!(fx, request, loaded, built, decision, Bool.True)", "decision = Pin.decide({\n\t\t\tmembers: loaded.members.map(|m| { file: m.file, pin: m.locked.roc, changes: Bool.False }),\n\t\t\tcompiler: request.compiler,\n\t\t\treq: loaded.intent.toolchain.roc,\n\t\t\tnightly: settings.nightly,\n\t\t\tno_check: request.no_check,\n\t\t})?\n\t\tresolve!(fx, request, loaded, built, decision, Bool.False)", [L2V]),
    # Update.run!
    ("W1", "R-NM7", UP, "json: args.json })", "json: Bool.False })", [L2U]),
    ("W2", "R-SP4", UP, "fx.err!(Picker.text(items))", "fx.out!(Picker.text(items))", [L2U]),
    ("W3", "Q2", UP, "Err(Invalid) => ask_again!(fx, items)", "Err(Invalid) => Ok([])", [L2U]),
    ("W4", "Q2", UP, "[] => return Ok(NothingPicked)", "[] => []", [L2U]),
    ("W5", "R-PD9", UP, "Known.record!(fx, { roots, files: Install.canonical_files!(fx, project), now: start.now })?", "Known.record!(fx, { roots, files: [], now: start.now })?", [L2U]),
    ("W6", "R-CM4", UP, "command: Update,\n\t\tnames,", "command: Install,\n\t\tnames,", [L2U, L3U]),
    ("W7", "R-AD28", UP, "add: { as_platform: Bool.False, as_alias: Err(Unset), no_pin: read.opts.no_pin },", "add: { as_platform: Bool.False, as_alias: Err(Unset), no_pin: Bool.False },", [L3U]),
    ("W8", "R-DT5", UP, 'shown.out!("${Report.resolved_line({ at: outcome.at, probes: outcome.probes })}\\n")', "{}", [L2U, L3U]),
    ("W9", "R-LF4", UP, 'shown.out!("dry run: nothing was written\\n")', "{}", [L3U]),
    ("W10", "R-CM19", UP, "fx.out!(Out.json_ok({ command: args.typed, data: Report.data(outcome) }))", 'fx.out!(Out.json_ok({ command: "update", data: Report.data(outcome) }))', [L3U]),
    ("W11", "R-NI2", UP, 'shown.out!("nothing picked\\n")', "{}", [L2U]),
    ("W12", "R-SO7", UP, "[] => return Ok(NothingPicked)\n\t\t\tnames => names\n\t\t}\n\t} else {\n\t\tread.opts.names\n\t}\n\tcompiler = Install.on_path!(fx)", "[] => return Ok(NothingPicked)\n\t\t\tnames => names\n\t\t}\n\t} else {\n\t\tread.opts.names\n\t}\n\tcompiler = Err(NoCompiler)", [L2U]),
    ("W13", "R-NM7", UP, 'Err(EndOfInput) => Err(Fail.new(Usage, "update -i needs a person to pick. Name the packages: tln update X Y."))', "Err(EndOfInput) => Ok([])", [L2U]),
    ("W14", "R-SP4", UP, "request([], Err(NoCompiler))", "request([], Err(NoCompiler))", []) if False else ("W14", "R-SP4", UP, "match pick_names!(fx, mode, request([], Err(NoCompiler)))? {", "match pick_names!(fx, Interactive, request([], Err(NoCompiler)))? {", [L2U, L3U]),
    # Verify.run!
    ("X1", "R-CM11", VF, 'shown.out!("verified: the tuple passes. Nothing was written.\\n")', "{}", [L2V, L3V]),
    ("X2", "R-J3", VF, "fx.out!(Out.json_ok({ command: args.typed, data: Report.data(outcome) }))", 'fx.out!(Out.json_ok({ command: "update", data: Report.data(outcome) }))', [L3V]),
    ("X3", "R-FL4", VF, "shown = Install.shown_fx(fx, args)", "shown = fx", [L3V]),
    ("X4", "R-PD9", VF, "Known.record!(fx, { roots: start.roots, files: Install.canonical_files!(fx, project), now: start.now })?", "Known.record!(fx, { roots: start.roots, files: [], now: start.now })?", [L2V]),
    ("X5", "R-CM11", VF, "dry_run: Bool.False,\n\t\t\tadd:", "dry_run: Bool.True,\n\t\t\tadd:", [L3V, L2V]),
    ("X6", "R-LB2", VF, "strategy: opts.strategy,", "strategy: Err(Unset),", [L3V]),
    ("X7", "R-SO7", VF, "compiler = Install.on_path!(fx)\n\tResolve.verify!", "compiler = Err(NoCompiler)\n\tResolve.verify!", [L2V, L3V]),
    # Run
    ("Z1", "R-CM4", RN, 'args.command == ["update"]', 'args.command == ["updatex"]', [L3U]),
    ("Z2", "R-CM11", RN, 'args.command == ["verify"]', 'args.command == ["verifyx"]', [L3V]),
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
