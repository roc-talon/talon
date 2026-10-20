#!/usr/bin/env python3
"""Revert check of the code of slice 007 (TW12), by the code agent.
Usage: research/slice-007-revert/code-mutate.py [id ...]     (DRY=1: only test that each pattern is found)
Each row is one small change of the code of `cli/lib` and the tests that must fail. A compile error is INVALID, not a catch.
The file is put back after each row. At the end the script compares the dir `cli/` with the copy that BEFORE names (a dir).
The L2 app and `tln` are built for each row in `$WORK/mut/bin` (the other test apps stay as `scripts/test.sh` built them).
Needs ROC (scripts/env.sh sets it). Output is a table."""
import filecmp, os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ["ROC"]
WORK = os.environ["WORK"]
BEFORE = os.environ.get("BEFORE", "")
MUT = f"{WORK}/mut/bin"

OP, RP, AD, IN, RS, LD, IX, GU = (f"cli/lib/{n}.roc" for n in ["Opts", "Report", "Add", "Intent", "Resolve", "Ladder", "Install", "Guard"])
A1, A2, W3 = "l3:add/ad1", "l3:add/ad2", "l3:install/in1"
FL = "l2:install/in1-flow"
SK = "l2:resolve/rs-stale-key"
SA = "l2:resolve/rs-stale-key-ask"
RN = "l2:resolve/rs-install-names"

# (id, rules, file, old text, new text, tests)
M = [
    # Opts (l0:opts)
    ("O1", "R-FL13", OP, 'if given("--frozen") and count > 0 {', "if Bool.False {", ["l0:opts"]),
    ("O2", "R-AD29", OP, 'if given("--platform") and count != 1 {', 'if given("--platform") and count > 1 {', ["l0:opts"]),
    ("O3", "R-FL5", OP, 'Ok(value) if value != "direct" =>', "Ok(value) if value != value =>", ["l0:opts"]),
    ("O4", "R-FL10", OP, 'Ok("lowest") => Ok(Ok(Lowest))', 'Ok("lowest") => Ok(Ok(Highest))', ["l0:opts"]),
    ("O6", "R-AD27", OP, 'no_pin: given("--no-pin"),', "no_pin: Bool.False,", ["l0:opts"]),
    ("O7", "R-NI1", OP, 'rename_keys: if given("--rename-keys") Ok(Yes) else Err(NoFlag),', "rename_keys: Err(NoFlag),", ["l0:opts"]),
    ("O10", "R-FL8", OP, 'dry_run: given("--dry-run"),', 'dry_run: given("--frozen"),', ["l0:opts"]),
    # Report (l0:report)
    ("R1", "R-DT5", RP, 'if facts.probes == 1 "1 probe"', 'if facts.probes == 0 "1 probe"', ["l0:report"]),
    ("R2", "R-OUT5", RP, '("downloads", Num(0)),', '("downloads", Num(1)),', ["l0:report"]),
    ("R3", "R-LF3", RP, "NotRun => Null", 'NotRun => Text("not run")', ["l0:report"]),
    ("R4", "R-OUT4", RP, '("snapshot", Text(o.at)),\n\t\t("probes", Num(o.probes.to_i64_wrap())),', '("probes", Num(o.probes.to_i64_wrap())),\n\t\t("snapshot", Text(o.at)),', ["l0:report"]),
    ("R5", "R-OUT4", RP, "Ok(id) => Text(id)", "Ok(_) => Null", ["l0:report"]),
    # Add (l0:add)
    ("A1", "R-SL12", AD, "_ => newest_first.take_first(3)", "_ => newest_first.take_first(2)", ["l0:add"]),
    ("A2", "R-SL12", AD, "nearest(below, above, 3)", "nearest(above, below, 3)", ["l0:add"]),
    ("A4", "Q9 R-WS12", AD, "match facts.held.find_first(|h| !Ranges.admits(", "match facts.held.find_first(|h| Ranges.admits(", ["l0:add"]),
    ("A5", "Q9 R-WS12", AD, "files = facts.held.keep_if(|h| h.version == first.version).map(|h| h.file)", "files = facts.held.map(|h| h.file)", ["l0:add"]),
    # Intent (l0:intent)
    ("I1", "R-NI1", IN, "Err(KeyExists) => Err(Fail.new(Usage,", "Err(KeyExists) => Err(Fail.new(Internal,", ["l0:intent"]),
    ("I3", "R-NI1", IN, 'Toml.rename(doc, ["dependencies", r.from], r.to)', 'Toml.rename(doc, ["overrides", r.from], r.to)', ["l0:intent"]),
    # Ladder C6 (l0:ladder)
    ("C1", "C6", LD, '[] => Err(unreadable("the baseline check on ${facts.compiler}", n))', "[] => Ok([])", ["l0:ladder"]),
    ("C2", "C6", LD, '[] => Err(unreadable("the whole-app check on ${facts.compiler}", n))', "[] => judge_check(facts.baseline, facts.owners, [])", ["l0:ladder"]),
    ("C3", "C6", LD, '[] => Err(unreadable("the build on ${facts.compiler}", n))', '[] => Ok({ lines: ["build: passed"] })', ["l0:ladder"]),
    ("C4", "C6", LD, 'count = if n == 1 "1 error" else', 'count = if n == 0 "1 error" else', ["l0:ladder"]),
    # L3 ad1: add of names (the real binary)
    ("D1", "R-LF4", RS, "touched = if request.dry_run paths else", "touched = if request.dry_run and request.frozen paths else", [A1]),
    ("D2", "Q9 R-SL5", AD, "Ok(Latest) => Bool.True", "Ok(Latest) => Bool.False", [A1]),
    ("D3", "R-SL12", RS, "Ok(c) if list.any(|x| Ranges.admits({ ranges: [f.range], version: x.ident.version })) => c", "Ok(c) => c", [A1]),
    ("D4", "R-DT5", IX, "\tif planned {", "\tif planned and opts.frozen {", [A1]),
    ("D5", "R-LF4", IX, "\tif opts.dry_run {", "\tif opts.dry_run and opts.frozen {", [A1]),
    ("D6", "R-DT5", RS, "total + if m.kind == App 3 else 2", "total + if m.kind == App 2 else 2", [A1]),
    ("D7", "R-AD21", RS, "\tfor k in kept {", "\tfor k in kept.take_first(0) {", [A1]),
    ("D8", "R-AD22", RS, "Keep => {\n\t\t\t\t\t\t$kept = $kept.append(kept_of(", "Keep | Update => {\n\t\t\t\t\t\t$kept = $kept.append(kept_of(", [A1]),
    ("D11", "R-AD25", RS, "pairs = match plan.toml {\n\t\tOk({ key, value }) => [{ path, key, value }]", "pairs = match plan.toml {\n\t\tOk({ key, value }) => [{ path, key, value }].take_first(0)", [A1]),
    ("K1", "D11", RS, "if touched.is_empty() and kept.is_empty() {", "if touched.is_empty() {", [A1]),
    ("D12", "R-H3", RS, 'Err(Unset) => if request.add.as_platform "pf" else Alias.default(name)', "Err(Unset) => Alias.default(name)", [A1, A2]),
    # L3 ad2: platform and json
    ("D14", "R-RP3 R-OUT4", RS, "[id, ..] => Ok(id)", "[_, ..] => Err(None)", [A2]),
    ("P1", "R-AD31", RS, "Ok(old) => if old.url == c.url {", 'Ok(old) => if old.url == "" {', [A2]),
    ("P2", "R-AD33", RS, "request.add.as_alias == Err(Unset) => if one.is_platform {", 'request.add.as_alias == Err(Unset) => if one.group.form == "" {', [A2]),
    ("P4", "R-J2", IX, "} else if args.json {", "} else if args.json and args.offline {", [A2]),
    ("P5", "R-FL4", IX, "shown_fx = |fx, args| if args.quiet {", "shown_fx = |fx, args| if args.quiet and args.offline {", [A2]),
    ("P6", "R-SE7", RS, "for note in plan.notes {\n\t\tfx.out!(", "for note in plan.notes {\n\t\tfx.err!(", [A2]),
    ("P7", "R-J3", IX, "fx.out!(Out.json_ok({ command: args.typed,", 'fx.out!(Out.json_ok({ command: "install",', [A2]),
    ("P9", "R-J5", IX, "if !shown.stdout.is_empty() fx.out!(shown.stdout)", "_ = shown.stdout", [A2]),
    ("M1", "R-LF3", RS, "Ok({ probes: 0, check: Skipped, build: Skipped, notes: [] })", "Ok({ probes: 0, check: Passed, build: Skipped, notes: [] })", [A1, A2]),
    # L3 in1: workspace, frozen, rename, held group
    ("W1", "R-WS12", IX, "(Ok(ws), Err(NoCurrent)) if !opts.names.is_empty() =>", "(Ok(ws), Err(NoCurrent)) if opts.frozen =>", [W3]),
    ("W2", "R-PD9", IX, "files: canonical_files!(fx, project), now })?", "files: canonical_files!(fx, project).take_first(0), now })?", [W3]),
    ("W3", "R-LF1", IX, "compiler = if opts.frozen Err(NoCompiler)", "compiler = if opts.frozen and opts.dry_run Err(NoCompiler)", [W3]),
    ("W4", "Q9", RS, "Add.check_held({ name, range: typed, held })?", "Add.check_held({ name, range: typed, held: [] })?", [W3]),
    ("W5", "R-WS12 Q9", RS, '"=${highest_version(held.map(|h| h.version))}"', "typed", [W3]),
    ("W7", "R-NM8", RS, "yes: request.prompt.yes, quiet: request.prompt.quiet, flag:", "yes: Bool.False, quiet: request.prompt.quiet, flag:", [W3]),
    # L2: the prompt and the stale key, the call order of the flow
    ("W6", "R-NI1", RS, "flag: request.prompt.rename_keys })?", "flag: Err(NoFlag) })?", [SK]),
    ("W9", "R-NI1", RS, "if done.answer == Yes {", "if done.answer == done.answer {", [SA]),
    ("W11", "R-I8", RS, "renames: renames.map(|r| { from: r.from, to: r.to }) })?", "renames: [] })?", [SK]),
    ("W14", "R-AD6", RS, "scope = if request.command == Update Scope.Project else Scope.Install", "scope = Scope.Project", [RN]),
    ("F1", "M22 R-CC2", LD, 'skip: [".git"] }) {', "skip: [] }) {", [FL]),
    ("F3", "R-CC7", GU, "files.keep_if(|f| f.read != f.now and f.spans_read != f.spans_now)", "files.keep_if(|f| f.read != f.now)", [FL]),
    ("F4", "R-CC7", RS, "Ok(text) => text\n\t\t\tErr(NotFound) => if is_header return", "Ok(_) => read\n\t\t\tErr(NotFound) => if is_header return", [FL]),
    ("F6", "R-PD9", IX, "files.map2(fx.canonical!(files), |file, result| result ?? file)", "files.map2(fx.canonical!(files), |file, _| file)", [FL]),
    ("F7", "R-SO7", IX, 'fx.programs!(["roc"])', 'fx.programs!(["rocx"])', [FL]),
]


def build(kind):
    """Builds the app of a layer into $WORK/mut/bin. Gives the compiler output on a failure, else None."""
    os.makedirs(MUT, exist_ok=True)
    if kind == "l2":
        src, out = "tests/commands/main.roc", f"{MUT}/l2"
    else:
        src, out = "cli/main.roc", f"{MUT}/tln"
        for name in ["fxprobe", "flowprobe"]:
            link = f"{MUT}/{name}"
            if not os.path.lexists(link):
                os.symlink(f"{WORK}/bin/{name}", link)
    p = subprocess.run([ROC, "build", src, f"--output={out}"], cwd=ROOT, capture_output=True, text=True, timeout=900)
    return None if p.returncode == 0 else p.stdout + p.stderr


def run(test):
    kind, what = test.split(":")
    env = dict(os.environ)
    if kind == "l0":
        cmd = [ROC, "test", f"tests/unit/{what}.roc", "--no-cache"]
    elif kind == "l2":
        env["L2BIN"] = f"{MUT}/l2"
        cmd = ["tests/commands/run.sh", what]
    else:
        env["TLN"] = f"{MUT}/tln"
        cmd = ["tests/run.sh", what]
    p = subprocess.run(cmd, cwd=ROOT, env=env, capture_output=True, text=True, timeout=900)
    return p.returncode, p.stdout + p.stderr


def judge(tests):
    built = {}
    for test in tests:
        kind = test.split(":")[0]
        if kind in ("l2", "l3") and kind not in built:
            built[kind] = build(kind)
            if built[kind] is not None:
                print(built[kind][-1500:], file=sys.stderr)
                return "INVALID (compile error)"
        rc, out = run(test)
        if rc != 0 and (re.search(r"^\s*[1-9][0-9]* compiler errors?", out, re.M) or "Compilation failed" in out):
            print(out[-1500:], file=sys.stderr)
            return "INVALID (compile error)"
        if rc != 0:
            names = re.findall(r"^FAIL (\S+)", out, re.M)
            return f"caught by {test}" + (f" ({', '.join(names)})" if names else "")
    return "NOT CAUGHT"


def same_tree(a, b):
    cmp = filecmp.dircmp(a, b)
    if cmp.left_only or cmp.right_only or cmp.diff_files or cmp.funny_files:
        return False
    return all(same_tree(f"{a}/{d}", f"{b}/{d}") for d in cmp.common_dirs)


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
        try:
            result = judge(tests)
        finally:
            open(path, "w").write(text)
        short = old[:50].replace("\n", " ").replace("\t", " ").replace("|", "/").strip()
        print(f"| {mid} | {ids} | `{short}` | {result} |", flush=True)
    if BEFORE and not dry:
        print("\nCode after the run equals the copy in BEFORE:", "yes" if same_tree(f"{ROOT}/cli", BEFORE) else "NO")


main()
