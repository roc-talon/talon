#!/usr/bin/env python3
"""Revert check of the CODE of slice 009 (TW12, code agent). Usage: research/slice-009-revert/code-mutate.py [id ...]   (DRY=1: only test that each pattern is found)
Each row is one small change of the code in cli/lib and the tests that must fail. A compile error is INVALID, not a catch.
The `old` texts match the code of the repository. The file is put back after each run. Needs ROC (scripts/env.sh sets it). Output is a table."""
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
    # Update.read, Verify.read (l0:update)
    ("U1", "R-FL13", UP, 'if given("--frozen") {', 'if Bool.False {', [A]),
    ("U2", "R-NR4 Q1", UP, 'if given("-i") and !opts.names.is_empty() {', 'if given("-i") and Bool.False {', [A]),
    ("U3", "R-SP4", UP, 'Ok({ opts, pick: given("-i") })', 'Ok({ opts, pick: Bool.False })', [A]),
    ("V1", "R-FL14", VF, 'if given("--frozen") {', 'if Bool.False {', [A]),
    ("V2", "R-FL14", VF, 'if given("--dry-run") {', 'if Bool.False {', [A]),
    ("V3", "Q6", VF, 'if !opts.names.is_empty() {', 'if Bool.False {', [A]),
    ("V4", "R-FL14 order", VF, 'opts = Opts.read({ ..args, options: args.options.keep_if(|(name, _)| name != "--frozen") })?', 'opts = Opts.read(args)?', [A]),
    # Picker (l0:picker)
    ("K1", "R-SP14", PK, 'item.alias.count_utf8_bytes() else most) + 2', 'item.alias.count_utf8_bytes() else most) + 1', [B]),
    ("K2", "R-SP14", PK, '"  ${(i + 1).to_str()}) ', '"  ${i.to_str()}) ', [B]),
    ("K3", "Q2", PK, '.replace_each(",", " ")', '', [B]),
    ("K4", "Q2", PK, 'items.get(n.minus_wrap(1))', 'items.get(n)', [B]),
    ("K5", "Q2", PK, 'match items.find_first(|item| item.alias == word) {', 'match items.find_first(|item| item.alias.starts_with(word)) {', [B]),
    ("K6", "R-SP11", PK, 'Ok(facts.items.keep_if(|item| picked.contains(item.alias)).map(|item| item.alias))', 'Ok(picked)', [B]),
    # Probe, Ladder.plan_replace (l0:verify)
    ("R1", "R-CM11", PR, '["--replace-dep", r.old, r.new]', '["--replace-dep", r.new, r.old]', [C]),
    ("R2", "R-CM11", PR, '["--replace-dep", r.old, r.new]', '["--replace", r.old, r.new]', [C]),
    ("P1", "R-LB2", LD, 'spec(flagged(Check))]', 'spec(Probe.args({ command: Check, file: facts.file }))]', [C]),
    ("P2", "R-LB2", LD, 'App => Ok(spec(flagged(Build({ output: output }))))', 'App => Ok(spec(Probe.args({ command: Build({ output: output }), file: facts.file })))', [C]),
    ("P3", "R-LD7", LD, 'Package | Platform => Err(None)\n\t\t}\n\t\t{ first: [spec(Probe.args', 'Package => Ok(spec(flagged(Check)))\n\t\t\tPlatform => Err(None)\n\t\t}\n\t\t{ first: [spec(Probe.args', [C]),
    ("P4", "R-LD6", LD, 'output = Text.join(facts.tmp, "tln-probe.out")', 'output = Text.join(facts.dir, "tln-probe.out")', [C]),
    # Add (l0:add)
    ("N1", "R-SE7", AD, '"platform changes: ${facts.from.name} ${facts.from.version} -> ${facts.to.name} ${facts.to.version}"', '"platform change: ${facts.from.name} ${facts.from.version} -> ${facts.to.name} ${facts.to.version}"', [D]),
    ("N2", "R-SL12", AD, 'close => " Close versions:', 'close => "Close versions:', [D]),
    # Ladder.verify! (l2:verify)
    ("L1", "R-CC2", LD, 'result = probe_in_place!(fx, request, member, tmp)\n\t_ = fx.delete!([tmp])', 'result = probe_in_place!(fx, request, member, tmp)', [L2V]),
    ("L2", "R-LD6", LD, 'match fx.make_dirs!([tmp]) {\n\t\tOk(_) => {}\n\t\tErr(_) => return Err(Fail.new(Environment, "cannot make ${tmp}"))\n\t}\n', '', [L2V]),
    ("L3", "R-BL1", LD, 'Ladder.check({ output: first.1, dir, pkgs', 'Ladder.check({ output: first.0, dir, pkgs', [L2V]),
    ("L4", "R-PH7", LD, 'Compiler.require({ id: request.held, path_roc: request.path_roc })?\n\t\tvar $done = no_done\n\t\tfor member in request.members {\n\t\t\t$done = $done.append({ file: member.file, lines: verify_member!', 'var $done = no_done\n\t\tfor member in request.members {\n\t\t\t$done = $done.append({ file: member.file, lines: verify_member!', [L2V]),
    ("L5", "R-LD7", LD, 'built = Ladder.build({ output, dir, pkgs, baseline, owners: request.owners, compiler, timeout })?\n\t\t\t\tOk(checked.lines.concat(built.lines))\n\t\t\t}\n\t\t\t_ => Err(no_answer("the build"))\n\t\t}\n\t}\n}\n\nno_answer', 'built = Ladder.build({ output, dir, pkgs, baseline, owners: request.owners, compiler, timeout })?\n\t\t\t\tOk(checked.lines.concat(built.lines.take_first(0)))\n\t\t\t}\n\t\t\t_ => Err(no_answer("the build"))\n\t\t}\n\t}\n}\n\nno_answer', [L2V]),
    # Resolve: update changes U1 to U4
    ("F1", "R-I5 Q3", RS, 'Err(None) => if request.command == Install {', 'Err(None) => if request.command == Install or request.command == Update {', [L2U, L3U]),
    ("F2", "R-SE7", RS, '\tplatform_notes = moved_platform_notes(scoped, var_chosen)\n\tfor note in platform_notes {\n\t\tfx.out!("note: ${note}\\n")\n\t}\n', '\tplatform_notes = moved_platform_notes(scoped, var_chosen)\n', [L2U, L3U, "l2:resolve/rs-update-scope"]),
    ("F3", "R-SE7", RS, '.keep_if(|(s, _)| s.variable.is_platform)', '.keep_if(|(s, _)| !s.variable.is_platform)', [L2U, L3U]),
    ("F4", "R-SE7 R-J4", RS, 'notes: pick_notes.concat(platform_notes).concat(plan.notes).concat(ran.notes),', 'notes: pick_notes.concat(plan.notes).concat(ran.notes),', [L3U]),
    ("F5", "R-SE7", RS, '.fold(no_names, |found, text| if found.contains(text) found else found.append(text))\n\n# R-I5', '.fold(no_names, |found, text| found.append(text))\n\n# R-I5', [L3U, L2V, L2U]),
    ("F6", "R-SL12 Q5", RS, 'Add.close_note({ selector: Ok(p.selector), versions })', 'Add.close_note({ selector: Ok(p.selector), versions: versions.take_first(0) })', [L3U, "l2:resolve/rs-failures", "l2:resolve/rs-new-toml"]),
    ("F7", "R-SL12 Q5", RS, 'versions = match facts.found.find_first(|c| c.name == name) {\n\t\t\t\t\tOk(c) => c.list.map(|x| x.ident.version)', 'versions = match facts.found.find_first(|c| c.name == name) {\n\t\t\t\t\tOk(c) => c.list.map(|x| x.ident.version).take_first(2)', ["l2:resolve/rs-failures"]),
    ("F8", "R-H4 Q8", RS, 'r.alias == ref.name and r.what == Path', 'r.alias == ref.name and r.what == Foreign', [L3U]),
    ("F9", "R-SP14", RS, 'Ok(u) => Ok({ alias, name: v.name ?? v.group.form, version: u.version })', 'Ok(u) => Ok({ alias, name: v.name ?? v.group.form, version: "${u.version}x" })', [L2U]),
    # Resolve: verify!
    ("F10", "R-RP2", RS, '\t\tcheck_pin(start.loaded.intent, settings, start.decision)?\n\t\tsnapshot = snapshot_of(request, start.loaded.intent)?\n\t\tpicked', '\t\tsnapshot = snapshot_of(request, start.loaded.intent)?\n\t\tpicked', [L2V, L3V]),
    ("F11", "R-CM11", RS, '.keep_if(|u| u.url != c.url and files.contains(u.file))', '.keep_if(|u| files.contains(u.file))', [L2V, L3V]),
    ("F12", "R-CM11", RS, '.fold(no_replace, |found, r| if found.contains(r) found else found.append(r))', '.fold(no_replace, |found, r| found.append(r))', [L2V, L3V]),
    ("F13", "R-LF3", RS, 'ran = if request.no_check {\n\t\tfx.out!("check: skipped\\n")\n\t\t{ probes: 0', 'ran = if request.no_check and request.dry_run {\n\t\tfx.out!("check: skipped\\n")\n\t\t{ probes: 0', [L3V]),
    ("F14", "R-LD7", RS, 'probes: checked.fold(0, |total, m| total + if m.kind == App 3 else 2),', 'probes: checked.fold(0, |total, m| total + if m.kind != App 3 else 2),', [L3V, L2V]),
    ("F15", "R-CM11", RS, 'notes: pick_notes.concat(platform_notes).concat(ran.notes),\n\t\twritten: [],', 'notes: pick_notes.concat(platform_notes).concat(ran.notes),\n\t\twritten: files,', [L3V]),
    ("F16", "R-OUT2", RS, '\t\tif edits.any(|e| e.file == file) {\n\t\t\tfx.out!("${file}\\n")', '\t\tif edits.any(|e| e.file == file) or files.contains(file) {\n\t\t\tfx.out!("${file}\\n")', [L2V, L3V]),
    ("F17", "R-LD7", RS, 'build: if checked.any(|m| m.kind == App) Passed else NotRun,', 'build: Passed,', [L3V, L2V]),
    # Update.run!
    ("W1", "R-NM7", UP, 'Err(EndOfInput) => Err(Consent.no_person)', 'Err(EndOfInput) => Ok([])', [L2U]),
    ("W2", "R-SP4", UP, 'fx.err!(Picker.text(items))', 'fx.out!(Picker.text(items))', [L2U]),
    ("W3", "Q2", UP, 'Err(Invalid) => ask_again!(fx, items)', 'Err(Invalid) => Ok([])', [L2U]),
    ("W4", "Q2", UP, 'if pick and names.is_empty() {', 'if !pick and names.is_empty() {', [L2U]),
    ("W5", "R-NI2", UP, 'shown.out!("nothing picked\\n")', '{}', [L2U]),
    ("W6", "R-PD9", UP, 'files: Install.canonical_files!(fx, start.project)', 'files: []', [L2U]),
    ("W7", "R-CM4", UP, 'command: Update,\n\tnames,', 'command: Install,\n\tnames,', [L2U, L3U]),
    ("W8", "R-AD28", UP, 'add: { as_platform: Bool.False, as_alias: Err(Unset), no_pin: opts.no_pin }', 'add: { as_platform: Bool.False, as_alias: Err(Unset), no_pin: Bool.False }', [L3U]),
    ("W9", "R-DT5", UP, 'shown.out!("${Report.resolved_line({ at: outcome.at, probes: outcome.probes })}\\n")', '{}', [L2U, L3U]),
    ("W10", "R-CM19", UP, 'fx.out!(Out.json_ok({ command: args.typed, data: Report.data(outcome) }))', 'fx.out!(Out.json_ok({ command: "update", data: Report.data(outcome) }))', [L3U]),
    ("W11", "R-HF1", UP, 'NeedTty => match Consent.picker(Mode.with_tty(mode, fx.tty!())) {', 'NeedTty => match Consent.picker(Mode.with_tty(mode, { stdin: Bool.True, stderr: Bool.True })) {', [L2U]),
    ("W12", "R-SO7", UP, 'compiler = Install.on_path!(fx)', 'compiler = Err(NoCompiler)', [L2U, L3U]),
    ("W13", "R-NM7", UP, 'if items.is_empty() Ok([]) else ask_names!(fx, items)', 'ask_names!(fx, items)', [L2U]),
    # Verify.run!
    ("X1", "R-CM11", VF, 'shown.out!("verified: the tuple passes. Nothing was written.\\n")', '{}', [L2V, L3V]),
    ("X2", "R-J3", VF, 'fx.out!(Out.json_ok({ command: args.typed, data: Report.data(outcome) }))', 'fx.out!(Out.json_ok({ command: "update", data: Report.data(outcome) }))', [L3V]),
    ("X3", "R-CM11", VF, 'dry_run: Bool.False,', 'dry_run: Bool.True,', [L2V, L3V]),
    ("X4", "R-LB4", VF, 'strategy: opts.strategy,', 'strategy: Err(Unset),', [L3V]),
    ("X5", "R-PD9", VF, 'files: Install.canonical_files!(fx, start.project)', 'files: []', [L2V]),
    ("X6", "R-SO7", VF, 'compiler = Install.on_path!(fx)', 'compiler = Err(NoCompiler)', [L2V, L3V]),
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
