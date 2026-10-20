#!/usr/bin/env python3
"""Revert check of slice 005 (TW12): break the code of each rule in one small way, run the tests that should catch it,
put the file back. Usage: research/slice-005-revert/revert.py [id-filter ...]. Writes the table to stdout.
A compile error of a mutation is reported as INVALID (it is not a catch).
Each file has a list of tests that run in order. The first one that fails is the catch."""
import os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ.get("ROC", f"{ROOT}/cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")

L2 = "l2:resolve/"
TESTS = {
    "Ranges": ["l0:ranges", "l0:vars", "l0:pin", L2],
    "Release": ["l0:pick", L2],
    "Pin": ["l0:pin", L2],
    "Locked": ["l0:locked", L2],
    "Intent": ["l0:intent", L2],
    "Vars": ["l0:vars", L2],
    "Pick": ["l0:pick", L2],
    "Frozen": ["l0:frozen", L2],
    "Resolve": [L2],
}

# (rule ids, module, old text, new text)
M = [
    ("R-I4 implied lower bound", "Ranges", '">=${version}, <${next_series(v)}"', '"<${next_series(v)}"'),
    ("R-I4 series below 1.0", "Ranges", 'if v.major() >= 1 ', 'if v.major() >= 0 '),
    ("R-C1 all ranges admit", "Ranges", 'facts.ranges.all(', 'facts.ranges.any('),
    ("R-TF4 range check", "Ranges", 'Ok(_) => Ok({})\n\t\tErr(_) => Err(BadRange)', 'Ok(_) => Err(BadRange)\n\t\tErr(_) => Ok({})'),
    ("R-C4 platform kind", "Release", 'Platform(_) => Platform', 'Platform(_) => Package'),
    ("R-C3 pf entry of a platform", "Release", 'Ok(e) if kind != Platform => Ok(e.value)', 'Ok(e) => Ok(e.value)'),
    ("R-C2 deps without roc", "Release", '!e.is_platform and e.name != "roc"', '!e.is_platform'),
    ("R-DI7 no header kind", "Release", 'Err(NoHeader) => Err(Fail.new(Input,', 'Err(NoHeader) => Err(Fail.new(Usage,'),
    ("R-NS7 any", "Pin", 'Ok(Any)', 'Ok(Exactly("*"))'),
    ("R-NS7 at least", "Pin", 'AtLeast(a) => at_least(a, facts.id)', 'AtLeast(a) => facts.id == a'),
    ("R-NS7 exactly", "Pin", 'Exactly(a) => facts.id == a', 'Exactly(a) => Bool.True'),
    ("R-NS7 semver range has no nightly", "Pin", 'Semver(range) => !Pin.is_nightly(facts.id) and ', 'Semver(range) => '),
    ("R-WS4 differing pins", "Pin", 'if texts.len() >= 2 {', 'if texts.len() >= 3 {'),
    ("R-RP1 member with a pin", "Pin", 'm.pin == Err(NoPin) and m.changes', 'm.changes'),
    ("R-RP3 write only for a change", "Pin", 'm.pin == Err(NoPin) and m.changes', 'm.pin == Err(NoPin)'),
    ("R-H6 no_check writes no pin", "Pin", 'can_write = !facts.no_check', 'can_write = Bool.True'),
    ("R-SP1 held pin", "Pin", '[one] => Ok(one)', '[one] => facts.compiler'),
    ("R-NS5 nightly with the switch off", "Pin", '(Pin.is_nightly(pin) and !facts.nightly)', 'Bool.False'),
    ("R-RP2 follow text", "Pin", '${range}. ${follow}")', '${range}.")'),
    ("R-RP2 failure kind", "Pin", 'Fail.new(NoTuple, "the roc pin ${facts.pin} is outside', 'Fail.new(Usage, "the roc pin ${facts.pin} is outside'),
    ("R-NS7 same date order", "Pin", '(Ok(a), Ok(b)) => !is_before(b, a)', '(Ok(a), Ok(b)) => is_before(a, b)'),
    ("Q9 release bound", "Pin", 'is_release(bound) and is_release(id) and', 'Bool.True and'),
    ("R-H4 path row", "Locked", 'if e.value.contains("://") Foreign else Path', 'Foreign'),
    ("R-RP1 pin entry name", "Locked", 'entries.find_first(|e| e.name == "roc")', 'entries.find_first(|e| e.name == "pin")'),
    ("R-H4 rows without roc", "Locked", 'entries.keep_if(|e| e.name != "roc")', 'entries'),
    ("R-H4 never edit a path row", "Locked", '_ => Err(internal("${alias} is a path entry or a foreign URL: tln never changes it (R-H4)"))', '_ => Ok({})'),
    ("R-H3 URL with a hash", "Locked", 'Err(Foreign) => Err(internal("${url} is not a release URL with a version and a hash (R-H3)"))', 'Err(Foreign) => Ok({})'),
    ("R-H1 add of a present alias", "Locked", 'if present(alias) return', 'if Bool.False return'),
    ("R-H6 set the pin", "Locked", 'Ok(_) => written(id, Header.set_value(text, "roc", id))', 'Ok(_) => Ok(text)'),
    ("R-CC7 spans", "Locked", 'facts.ops.map(|op| entry_text(header, op))', 'facts.ops.map(|_| "")'),
    ("R-CC7 span of the pin", "Locked", 'Pin(_) => "roc"', 'Pin(_) => "pin"'),
    ("R-H7 path entries", "Locked", 'if r.what == Path Ok', 'if r.what == Foreign Ok'),
    ("R-I2 split at the first @", "Intent", 'text.split_first("@")', 'text.split_last("@")'),
    ("R-C7 days", "Intent", 'n * 86400', 'n * 3600'),
    ("R-NS9 nightly", "Intent", 'Value.Boolean(b) => Ok(b)', 'Value.Boolean(b) => Ok(!b)'),
    ("R-WS5 member tables", "Intent", 'role == Member and !dependency_tables', 'role == Root and !dependency_tables'),
    ("R-TF4 unknown table", "Intent", 'message: "unknown table [${name}]"', 'message: "unknown table ${name}"'),
    ("R-DT3 log snapshot kind", "Intent", 'Ok(Log(n)) => Err(Fail.new(Usage,', 'Ok(Log(n)) => Err(Fail.new(Input,'),
    ("R-DT4 time snapshot", "Intent", 'Ok(Time(seconds)) => Ok(Ok(seconds))', 'Ok(Time(seconds)) => Ok(Err(None))'),
    ("R-PD6 up to the root", "Intent", 'if dir == root or dir.is_empty() next', 'if dir.is_empty() next'),
    ("R-VA6 lowest", "Intent", 'Value.String("lowest") => Ok(Lowest)', 'Value.String("lowest") => Ok(Highest)'),
    ("R-AD25 same value", "Intent", 'Ok(Value.String(old)) if old == w.value => Ok(doc)', 'Ok(Value.String(old)) if Bool.False => Ok(doc)'),
    ("R-AD26 insert", "Intent", 'Err(NotFound) => Toml.insert(doc, ["dependencies", w.key]', 'Err(NotFound) => Toml.replace(doc, ["dependencies", w.key]'),
    ("R-CC7 toml spans", "Intent", 'Ok(value) => Value.print(value)', 'Ok(_) => ""'),
    ("R-EC19 line of bad TOML", "Intent", 'Err(TomlErr(e)) => Err(Fail.new(Input, "${facts.path}:${e.line.to_str()}: not valid TOML"))\n\t\tOk(doc) => {\n\t\t\tscan', 'Err(TomlErr(e)) => Err(Fail.new(Input, "${facts.path}:1: not valid TOML"))\n\t\tOk(doc) => {\n\t\t\tscan'),
    ("R-OV1 overrides table", "Intent", 'overrides = read_deps(doc, "overrides")', 'overrides = read_deps(doc, "dependencies")'),
    ("R-I2 range check message", "Intent", "is not a version range\" })", "is not a range\" })"),
    ("R-WS1 group of a variable", "Vars", 'uses.keep_if(|u| u.group == group)', 'uses.keep_if(|u| u.group.form == group.form)'),
    ("R-VA6 platforms last", "Vars", 'firsts.keep_if(|u| !u.is_platform).concat(firsts.keep_if(|u| u.is_platform))', 'firsts'),
    ("R-I3 key range", "Vars", 't.intent.deps.find_first(|d| d.key == u.alias)', 't.intent.deps.find_first(|d| d.key == "x")'),
    ("R-OV1 override range", "Vars", 't.intent.overrides.find_first(|d| d.key == u.alias)', 't.intent.overrides.find_first(|d| d.key == "x")'),
    ("R-I4 implied range", "Vars", 'Ranges.implied(u.version) ?? "*"', '"*"'),
    ("R-WS2 ranges of all uses", "Vars", 'uses.fold([], |found, u| add_range(found, range_of(members, u)))', 'uses.take_first(1).fold([], |found, u| add_range(found, range_of(members, u)))'),
    ("R-VA6 priority", "Vars", 'front.concat(vars.keep_if(|v| !front.contains(v)))', 'vars'),
    ("R-WS6 two members", "Vars", 'f.want.members.len() >= 2', 'f.want.members.len() >= 3'),
    ("R-I8 stale range", "Vars", 'Ranges.admits({ ranges: [range], version: ident.version })', 'Bool.True'),
    ("R-AD6 short name", "Vars", 'Ok(n) => if n.contains("/") Ok(n) else Err(Short(n))', 'Ok(n) => Ok(n)'),
    ("R-WS8 alias of 2 groups", "Vars", '[(i, _)] => Ok(found.append(i))', '[(i, _), ..] => Ok(found.append(i))'),
    ("R-SP20 outside", "Vars", 'variable.uses.any(|u| !Ranges.admits', 'variable.uses.all(|u| !Ranges.admits'),
    ("R-SP2 indexed only", "Vars", 'free = indexed and (all or is_named)', 'free = all or is_named'),
    ("R-SP3 named", "Vars", 'free = indexed and (all or is_named)', 'free = indexed and all'),
    ("R-SP5 any series", "Vars", 'any_series: Bool.True, note }', 'any_series: Bool.False, note }'),
    ("R-DI11 fixed note", "Vars", 'Fixed(host) => Ok(Index.fixed_line(host))', 'Fixed(_) => Err(None)'),
    ("R-SP19 install holds", "Vars", 'Install => { variable, free: outside_range(variable)', 'Install => { variable, free: Bool.False'),
    ("R-SP14 picker", "Vars", 'vars.keep_if(|v| v.host == Indexed).keep_oks', 'vars.keep_oks'),
    ("R-C1 range of a slot", "Pick", 'all.keep_if(|c| Ranges.admits({ ranges: slot.ranges, version: c.ident.version }))', 'all'),
    ("R-C7 age", "Pick", 'c.published_at + facts.min_age > facts.now', 'Bool.False'),
    ("R-C7 age boundary", "Pick", 'c.published_at + facts.min_age > facts.now', 'c.published_at + facts.min_age >= facts.now'),
    ("R-DT4 snapshot", "Pick", 'Ok(time) => c.published_at > time', 'Ok(_) => Bool.False'),
    ("R-DT4 snapshot boundary", "Pick", 'Ok(time) => c.published_at > time', 'Ok(time) => c.published_at >= time'),
    ("R-C9 header value is never hidden", "Pick", 'exempt = slot.current == Ok(c.url) or slot.named', 'exempt = slot.named'),
    ("R-C7 named version is never hidden", "Pick", 'exempt = slot.current == Ok(c.url) or slot.named == Ok(c.ident.version)', 'exempt = slot.current == Ok(c.url)'),
    ("R-C4 kind of a package", "Pick", 'else release.kind == Package', 'else Bool.True'),
    ("R-DT2 sorted candidates", "Pick", 'slot.candidates.sort_with(|a, b| Text.compare(a.url, b.url))', 'slot.candidates'),
    ("R-C2 newer dependency", "Pick", 'ident.group == y.ident.group and is_newer(', 'Bool.False and is_newer('),
    ("R-C3 platform of a package", "Pick", 'ctx.single_platform and !x.is_platform', 'Bool.False and !x.is_platform'),
    ("R-C9 current is a candidate", "Pick", 'Ok(c) if !listed.any(|x| x.url == c.url) => listed.append(c)', 'Ok(c) if Bool.False => listed.append(c)'),
    ("R-SP1 held slot", "Pick", 'all = if slot.free {', 'all = if Bool.True {'),
    ("R-PH10 counts", "Pick", 'outside = total - d.in_range.len()', 'outside = 0'),
    ("R-C7 note days", "Pick", 'days = |seconds| (seconds // 86400).to_str()', 'days = |seconds| (seconds // 3600).to_str()'),
    ("R-PH10 failure kind", "Pick", 'Fail.new(NoTuple, "no tuple works: ${slot.id} has no release that satisfies', 'Fail.new(Usage, "no tuple works: ${slot.id} has no release that satisfies'),
    ("R-C9 change", "Pick", 'change: if slot.current == Ok(c.url) Keep else Move(old)', 'change: Keep'),
    ("R-LF1 wants", "Frozen", '.concat(facts.wants.map(want_finding))', ''),
    ("R-SP20 free only", "Frozen", 'scoped.keep_if(|s| s.free).join_map(', 'scoped.join_map('),
    ("R-EC14 frozen kind", "Frozen", 'Fail.new(Frozen, "the header does not satisfy', 'Fail.new(Usage, "the header does not satisfy'),
    ("R-LF1 joined findings", "Frozen", 'Str.join_with(findings, "; ")', 'Str.join_with(findings, ", ")'),
    ("R-NS5 frozen nightly", "Frozen", 'if !facts.nightly and Pin.is_nightly(pin) {', 'if Bool.False {'),
    ("R-I8 stale finding", "Frozen", 'which the header names \\"${alias}\\""', 'which the header names ${alias}"'),
    ("R-SP18 install takes no names", "Resolve", 'for text in (if request.command == Update request.names else [])', 'for text in request.names'),
    ("R-LF1 frozen hash check", "Resolve", '_ = read_releases!(fx, request, urls, Bool.False)?', '_ = urls'),
    ("Q3 no compiler", "Resolve", 'Err(NoCompiler) => Err(Fail.new(Environment, "cannot select a compiler: there is no roc on PATH that Talon can identify, and the header has no roc pin"))', 'Err(NoCompiler) => Ok({})'),
    ("Q3 kind", "Resolve", 'Err(NoCompiler) => Err(Fail.new(Environment,', 'Err(NoCompiler) => Err(Fail.new(Usage,'),
    ("Q3 names roc", "Resolve", 'there is no roc on PATH that Talon can identify, and the header has no roc pin', 'no compiler can be selected'),
    ("Q2 platform key", "Resolve", 'platform_wants(input.want_slots, all)?', 'platform_wants([], all)?'),
    ("R-RP2 outside pin", "Resolve", 'check_pin(loaded.intent, settings, decision)?', '_ = decision'),
    ("R-DT3 snapshot", "Resolve", 'snapshot = Intent.direct_snapshot(loaded.intent.resolution.snapshot)?', 'snapshot = Err(None)'),
    ("R-I8 stale warning", "Resolve", 'the key \\"${w.key}\\" names ${w.name ?? w.key}', 'the key \\"${w.key}\\" is ${w.name ?? w.key}'),
    ("R-AD6 short name", "Resolve", 'Err(Short(text)) => return Err(short_failure(w.from, text))', 'Err(Short(_)) => {}'),
    ("R-H1 set only changed uses", "Resolve", '.keep_if(|u| u.url != c.url)\n\t.map(|u| { file: u.file, op: Set', '.map(|u| { file: u.file, op: Set'),
    ("R-RP3 pin with a change", "Resolve", 'changes: changes.any(|e| e.file == m.file)', 'changes: Bool.False'),
    ("R-NS8 nightly default", "Resolve", 'intent.toolchain.nightly ?? Bool.True', 'intent.toolchain.nightly ?? Bool.False'),
    ("R-C7 default age", "Resolve", 'intent.resolution.min_release_age ?? 172800', 'intent.resolution.min_release_age ?? 0'),
    ("R-VA6 default strategy", "Resolve", 'intent.resolution.strategy ?? Highest', 'intent.resolution.strategy ?? Lowest'),
    ("R-CC7 talon.toml first", "Resolve", 'paths = header_files.concat(toml_files)', 'paths = toml_files.concat(header_files)'),
    ("R-I5 add the key", "Resolve", 'Insert => Ok([{ file, op: Add({ alias: plan.alias, url: c.url, is_platform: Bool.False }), line: "+ ${plan.alias}: ${name} ${c.version}" }])', 'Insert => Ok([])'),
    ("R-WS7 wants", "Resolve", 'wants = live_wants!(fx, built.wants)?', 'wants = []'),
    ("R-SP1 held variable index", "Resolve", 'free_names = scoped.keep_if(|s| s.free).keep_oks', 'free_names = scoped.keep_oks'),
    ("R-AD22 selector in talon.toml", "Resolve", 'selector: Ok(p.selector), no_pin', 'selector: Err(None), no_pin'),
    ("R-AD26 new talon.toml", "Resolve", 'Text.join(Text.dir_of(u.file), "talon.toml")', 'Text.join(Text.dir_of(u.file), "x.toml")'),
    ("R-AD22 selector range", "Resolve", 'Exact(version) => Ok("=${version}")', 'Exact(version) => Ok(version)'),
    ("R-SP5 selector series", "Resolve", 'Exact(version) if s.any_series => Ok(version)', 'Exact(version) => Ok(version)'),
    ("R-C9 highest use", "Resolve", 'if a.order_relative_to(b) == After u else best', 'if a.order_relative_to(b) == Before u else best'),
    ("R-LF2 no write", "Resolve", 'if request.frozen {\n\t\t\tfrozen!(fx, request, loaded, built, decision)', 'if request.frozen and request.offline {\n\t\t\tfrozen!(fx, request, loaded, built, decision)'),
    ("R-CC7 nothing to change", "Resolve", 'if changed.is_empty() {', 'if changed.len() > 100 {'),
    ("R-PD6 talon.toml candidates", "Resolve", 'candidates = files.map(|f| Intent.paths({ member: f, root }))', 'candidates = files.map(|f| [Text.join(Text.dir_of(f), "talon.toml")])'),
    ("R-WS5 root role", "Resolve", 'Ok(_) => if t.path == root_toml Root else Member', 'Ok(_) => Root'),
]


def run(test):
    kind, what = test.split(":")
    env = dict(os.environ)
    if kind == "l0":
        cmd = [ROC, "test", f"tests/unit/{what}.roc", "--no-cache"]
    else:
        cmd = ["tests/commands/run.sh", what]
    p = subprocess.run(cmd, cwd=ROOT, env=env, capture_output=True, text=True, timeout=600)
    return p.returncode, p.stdout + p.stderr


def main():
    flt = sys.argv[1:]
    print("| Rule | Mutation | Result |\n| --- | --- | --- |")
    caught = invalid = total = 0
    for ids, mod, old, new in M:
        if flt and not any(f in ids or f == mod for f in flt):
            continue
        path = f"{ROOT}/cli/lib/{mod}.roc"
        text = open(path).read()
        if old not in text:
            print(f"| {ids} | {mod}: pattern not found | INVALID |", flush=True)
            invalid += 1
            continue
        total += 1
        open(path, "w").write(text.replace(old, new, 1))
        result = "NOT CAUGHT"
        try:
            for test in TESTS[mod]:
                rc, out = run(test)
                compile_error = re.search(r"[1-9][0-9]* (compiler )?error", out) is not None or "Compilation failed" in out or "build of" in out
                if rc != 0 and compile_error:
                    result = "INVALID (compile error)"
                    invalid += 1
                    total -= 1
                    print(out[-1500:], file=sys.stderr)
                    break
                if rc != 0:
                    names = re.findall(r"^FAIL (\S+)", out, re.M)
                    result = f"caught by {test}" + (f" ({', '.join(names)})" if names else "")
                    caught += 1
                    break
        finally:
            open(path, "w").write(text)
        short = old[:50].replace("\n", " ").replace("|", "/").strip()
        print(f"| {ids} | {mod}: `{short}` | {result} |", flush=True)
    print(f"\ncaught {caught} of {total}, invalid {invalid}")


main()
