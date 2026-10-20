#!/usr/bin/env python3
"""Revert check of slice 007 (TW12). Usage: research/slice-007-revert/mutate.py [id ...]   (DRY=1: only test that each pattern is found)
Each row is one small change of the private reference implementation and the tests that must fail. A compile error is INVALID, not a catch.
The reference implementation was deleted after the run (the manager asked for it), so the `old` texts do not match the code of the repository any more:
this file and results.md are the record of the check. The file is put back after each run. Needs ROC (scripts/env.sh sets it). Output is a table."""
import os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ["ROC"]

OP, RP, AD, IN, RS, LD, IX, GU = "cli/lib/Opts.roc", "cli/lib/Report.roc", "cli/lib/Add.roc", "cli/lib/Intent.roc", "cli/lib/Resolve.roc", "cli/lib/Ladder.roc", "cli/lib/Install.roc", "cli/lib/Guard.roc"
A1, A2, W3 = "l3:add/ad1", "l3:add/ad2", "l3:install/in1"
FL = "l2:install/in1-flow"
SK = "l2:resolve/rs-stale-key"
SA = "l2:resolve/rs-stale-key-ask"
RN = "l2:resolve/rs-install-names"

# (id, rules, file, old text, new text, tests)
M = [
    # Opts (l0:opts)
    ("O1", "R-FL13", OP, 'if flag("--frozen") and !args.operands.is_empty() {', "if Bool.False {", ["l0:opts"]),
    ("O2", "R-AD29", OP, 'args.operands.len() != 1 {', "args.operands.len() > 1 {", ["l0:opts"]),
    ("O3", "R-FL5", OP, 'Ok(r) if r != "direct" =>', "Ok(r) if r != r =>", ["l0:opts"]),
    ("O4", "R-FL10", OP, 'Ok("lowest") => Ok(Lowest)', 'Ok("lowest") => Ok(Highest)', ["l0:opts"]),
    ("O5", "R-FL10", OP, 'Ok(other) => return Err(Fail.new(Usage, "--strategy must be highest or lowest, not', 'Ok(other) => return Err(Fail.new(Usage, "--strategy must be lowest or highest, not', ["l0:opts"]),
    ("O6", "R-AD27", OP, 'no_pin: flag("--no-pin"),', "no_pin: Bool.False,", ["l0:opts"]),
    ("O7", "R-NI1", OP, 'rename_keys: if flag("--rename-keys") Ok(Yes) else Err(NoFlag),', "rename_keys: Err(NoFlag),", ["l0:opts"]),
    ("O8", "R-AD28", OP, 'as_alias: value("--as"),', "as_alias: Err(Unset),", ["l0:opts"]),
    ("O9", "R-FL9", OP, 'snapshot: value("--snapshot"),', "snapshot: Err(Unset),", ["l0:opts"]),
    ("O10", "R-FL8", OP, 'dry_run: flag("--dry-run"),', 'dry_run: flag("--frozen"),', ["l0:opts"]),
    ("O11", "R-NI3", OP, 'allow_moves: if flag("--allow-moves") Ok(Yes) else Err(NoFlag),', "allow_moves: Err(NoFlag),", ["l0:opts"]),
    # Report (l0:report)
    ("R1", "R-DT5", RP, 'if facts.probes == 1 "probe" else "probes"', 'if facts.probes == 0 "probe" else "probes"', ["l0:report"]),
    ("R2", "R-OUT5", RP, '("downloads", Num(0)),', '("downloads", Num(1)),', ["l0:report"]),
    ("R3", "R-LF3", RP, "NotRun => Null", 'NotRun => Text("not run")', ["l0:report"]),
    ("R4", "R-OUT4", RP, '("snapshot", Text(o.at)),\n\t\t\t\t("probes", Num(o.probes.to_i64_wrap())),', '("probes", Num(o.probes.to_i64_wrap())),\n\t\t\t\t("snapshot", Text(o.at)),', ["l0:report"]),
    ("R5", "R-OUT4", RP, "Ok(id) => Text(id)", "Ok(_) => Null", ["l0:report"]),
    ("R6", "R-OUT4", RP, '("kept", Arr(o.kept.map(entry))),', '("kept", Arr([])),', ["l0:report"]),
    ("R7", "R-NI1", RP, '("renamed", Arr(o.renamed.map(|r| Obj([("path", Text(r.path)), ("from", Text(r.from)), ("to", Text(r.to))])))),', '("renamed", Arr([])),', ["l0:report"]),
    ("R8", "R-NI1", RP, '("from", Text(r.from)), ("to", Text(r.to))', '("from", Text(r.to)), ("to", Text(r.from))', ["l0:report"]),
    # Add (l0:add)
    ("A1", "R-SL12", AD, "_ => flip(sorted).take_first(3)", "_ => sorted.take_first(3)", ["l0:add"]),
    ("A2", "R-SL12", AD, "picked = [below.get(0), above.get(0), below.get(1), above.get(1), below.get(2), above.get(2)]", "picked = [above.get(0), below.get(0), above.get(1), below.get(1), above.get(2), below.get(2)]", ["l0:add"]),
    ("A3", "R-SL12", AD, "if close.is_empty() usage(", "if Bool.False usage(", ["l0:add"]),
    ("A4", "Q9 R-WS12", AD, "match facts.held.find_first(|h| !Ranges.admits(", "match facts.held.find_first(|h| Ranges.admits(", ["l0:add"]),
    ("A5", "Q9 R-WS12", AD, "facts.held.keep_if(|h| h.version == first.version)", "facts.held", ["l0:add"]),
    ("A6", "R-AD31", AD, "decide_platform = |req| match req.header.find_first(|row| row.is_platform) {", 'decide_platform = |req| match req.header.find_first(|row| row.alias == "pf") {', ["l0:add"]),
    ("A7", "Q9 R-EC10", AD, 'Err(Fail.new(NoTuple, "no tuple works: \'${facts.range}\'', 'Err(Fail.new(Usage, "no tuple works: \'${facts.range}\'', ["l0:add"]),
    # Intent (l0:intent)
    ("I1", "R-NI1", IN, "KeyExists => Fail.new(Usage,", "KeyExists => Fail.new(Internal,", ["l0:intent"]),
    ("I2", "R-NI1", IN, "NoEntry => Fail.new(Internal,", "NoEntry => Fail.new(Usage,", ["l0:intent"]),
    ("I3", "R-NI1", IN, 'Toml.rename(current, ["dependencies", r.from], r.to)', 'Toml.rename(current, ["overrides", r.from], r.to)', ["l0:intent"]),
    # Ladder C6 (l0:ladder)
    ("C1", "C6", LD, '[] => Err(Fail.new(Internal, "the baseline check on ${facts.compiler} gave no result: ${unreadable(n)}. Run the command again."))', "[] => Ok([])", ["l0:ladder"]),
    ("C2", "C6", LD, '[] => Err(Fail.new(Internal, "the whole-app check on ${facts.compiler} gave no result: ${unreadable(n)}. Run the command again."))', "[] => judge_check(facts.baseline, facts.owners, [])", ["l0:ladder"]),
    ("C3", "C6", LD, '[] => Err(Fail.new(Internal, "the build on ${facts.compiler} gave no result: ${unreadable(n)}. Run the command again."))', '[] => Ok({ lines: ["build: passed"] })', ["l0:ladder"]),
    ("C4", "C6", LD, 'if n == 1 "error" else "errors"', '"errors"', ["l0:ladder"]),
    # L3 ad1: add of names (the real binary)
    ("D1", "R-LF4", RS, "if request.dry_run {\n\t\tshow!", "if request.dry_run and request.frozen {\n\t\tshow!", [A1]),
    ("D2", "Q9 R-SL5", AD, "Ok(Latest) => Bool.True", "Ok(Latest) => Bool.False", [A1]),
    ("D3", "R-SL12", RS, "if !versions.any(|v| Ranges.admits", "if request.frozen and !versions.any(|v| Ranges.admits", [A1]),
    ("D4", "R-DT5", IX, 'if changed fx.out!("${Report.resolved_line({ at: outcome.at, probes: outcome.probes })}\\n")', 'if changed and opts.frozen fx.out!("${Report.resolved_line({ at: outcome.at, probes: outcome.probes })}\\n")', [A1]),
    ("D5", "R-LF4", IX, 'if outcome.dry_run fx.out!("dry run: nothing was written\\n")', 'if outcome.dry_run and outcome.at.is_empty() fx.out!("dry run: nothing was written\\n")', [A1]),
    ("D6", "R-DT5", RS, "probes: apps * 3 + (members.len() - apps) * 2", "probes: apps * 2 + (members.len() - apps) * 2", [A1]),
    ("D7", "R-AD21", RS, "for k in plan.asked.kept {\n\t\tfx.out!", "for k in plan.asked.kept.take_first(0) {\n\t\tfx.out!", [A1]),
    ("D8", "R-AD22", RS, "_ => {\n\t\t\t\t\t\t$names = $names.append(alias)", "_ => {\n\t\t\t\t\t\t$kept = $kept.append({ entry: { alias, name: r.name, version: r.version }, note: plan.note ?? \"\" })", [A1]),
    ("D9", "R-AD27", RS, "no_pin: request.add.no_pin, as_alias: request.add.as_alias, header: rows })?", "no_pin: Bool.False, as_alias: request.add.as_alias, header: rows })?", [A1]),
    ("D10", "R-AD28", RS, "as_alias: request.add.as_alias, header: rows })?", "as_alias: Err(Unset), header: rows })?", [A1]),
    ("D11", "R-AD25", RS, "\tpairs = match decided.toml {\n\t\tOk({ key, value }) => [{ path: toml_path, key, value }]", "\tpairs = match decided.toml {\n\t\tOk({ key, value }) => [{ path: toml_path, key, value }].take_first(0)", [A1]),
    ("D12", "R-H3", RS, 'key: request.add.as_alias ?? Alias.default(a.name),', 'key: Alias.default(a.name),', [A1]),
    ("D13", "R-SL10", RS, "range = match why {\n\t\t\t\t\tHeld(version) => \"=${version}\"\n\t\t\t\t\tFresh => range_text(ref.selector)", "range = match why {\n\t\t\t\t\tHeld(version) => \"=${version}\"\n\t\t\t\t\tFresh => \"*\"", [A1]),
    ("D14", "R-RP3", RS, 'info: Pinned(w.id) }))', 'info: Plain }))', [A2]),
    # L3 ad2: platform and json
    ("P1", "R-AD31", RS, "[v] => if request.add.as_platform {\n\t\t\t\t\t\tErr(Fresh)", "[v] => if request.add.as_platform and request.frozen {\n\t\t\t\t\t\tErr(Fresh)", [A2]),
    ("P2", "R-AD33", RS, "if !request.add.as_platform and is_platform return", "if request.frozen and is_platform return", [A2]),
    ("P3", "R-AD32", RS, "if request.add.as_platform and !is_platform return", "if request.frozen and !is_platform return", [A2]),
    ("P4", "R-J2", IX, "else if args.json fx.err!(text) else fx.out!(text)", "else if args.json and args.offline fx.err!(text) else fx.out!(text)", [A2]),
    ("P5", "R-FL4", IX, "if args.quiet {} else if args.json", "if args.quiet and args.offline {} else if args.json", [A2]),
    ("P6", "R-SE7", RS, 'fx.out!("note: ${line}\\n")\n\t\t\t$notes = $notes.append(line)', 'fx.err!("note: ${line}\\n")\n\t\t\t$notes = $notes.append(line)', [A2]),
    ("P7", "R-J3", IX, "if args.json fx.out!(Out.json_ok({ command: args.typed, data: Report.data(outcome) }))", "if args.json fx.out!(Out.json_ok({ command: \"install\", data: Report.data(outcome) }))", [A2]),
    ("P8", "R-OUT4", RS, "pinned: match pinned { Ok(id) => Ok(id), Err(_) => Err(None) },", "pinned: match pinned { Ok(_) => Err(None), Err(_) => Err(None) },", [A2]),
    ("P9", "R-J5", IX, "if !text.stdout.is_empty() fx.out!(text.stdout)", "{}", [A2]),
    # L3 in1: workspace, frozen, rename, held group
    ("W1", "R-WS12", IX, "if !opts.names.is_empty() and project.file == Err(NoCurrent) {", "if !opts.names.is_empty() and project.file == Err(NoCurrent) and opts.frozen {", [W3]),
    ("W2", "R-PD9", IX, "Known.record!(fx, { roots, files: known, now })?", "Known.record!(fx, { roots, files: known.take_first(0), now })?", [W3, A1]),
    ("W3", "R-LF1", IX, "compiler = if opts.frozen {", "compiler = if opts.frozen and opts.dry_run {", [W3]),
    ("W4", "Q9", RS, "Add.check_held({ name, range: range_text(ref.selector), held })?", "Add.check_held({ name, range: range_text(ref.selector), held: [] })?", [W3]),
    ("W5", "R-WS12", RS, "Err(Held(highest_version(held)))", "Err(Fresh)", [W3]),
    ("W6", "R-NI1", RS, "flag: request.prompt.rename_keys })?", "flag: Err(NoFlag) })?", [SK]),
    ("W7", "R-NM8", RS, "yes: request.prompt.yes, quiet", "yes: Bool.False, quiet", [W3]),
    ("W8", "R-NI1", RS, "fx.err!(rename.report)", "{}", [SK, W3]),
    ("W9", "R-NI1", RS, "renames = if asked.answer == Yes", "renames = if asked.answer == asked.answer", [SA]),
    ("W11", "R-I8", RS, "renames: renames.keep_if(|r| r.path == path).map(|r| { from: r.from, to: r.to }) })?", "renames: [] })?", [SK]),
    ("W12", "R-FL13", IX, "frozen: opts.frozen,", "frozen: Bool.False,", [W3]),
    ("W13", "R-NM", IX, "yes: args.yes, quiet", "yes: Bool.False, quiet", [W3]),
    ("W14", "R-AD6", RS, "scope = if request.command == Update Scope.Project else Scope.Install", "scope = Scope.Project", [RN]),
    # L2 in1-flow: the call order, the copy, the candidate header, R-CC7
    ("F1", "M22 R-CC2", LD, 'skip: [".git"] }) {', "skip: [] }) {", [FL]),
    ("F2", "M26 Q4", LD, "candidate_text(member, dir)?", "candidate_text(member, \"\")?", [FL]),
    ("F3", "R-CC7", GU, "f.read != f.now and f.spans_read != f.spans_now", "f.read != f.now", [FL]),
    ("F4", "R-CC7", RS, "Ok(text) => text\n\t\t\tErr(NotFound) => if is_header return", "Ok(_) => read\n\t\t\tErr(NotFound) => if is_header return", [FL]),
    ("F5", "R-CC7", RS, "ordered = Guard.check_all($files)?", "ordered = Guard.check_all($files.map(|f| { ..f, now: f.read, spans_now: f.spans_read }))?", [FL]),
    ("F6", "R-CC2 R-PD9", IX, "known = fx.canonical!(files).keep_oks(|r| r)", "known = files", [FL]),
    ("F7", "R-SO7", IX, 'fx.programs!(["roc"])', 'fx.programs!(["rocx"])', [FL]),
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
