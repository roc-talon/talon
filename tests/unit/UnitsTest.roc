import lib.Db
import lib.Fail
import lib.Probe
import lib.Units

# The real outputs of the pinned roc for a unit probe: `roc check main.roc` in the dir of a package (tests/fixtures/check/make.sh, `ONLY=unit`). A report names a module by its file name.
import "../fixtures/check/out/unit-pass.stdout" as pass_out : Str
import "../fixtures/check/out/unit-fail.stderr" as fail_err : Str
import "../fixtures/check/out/unit-fail-two.stderr" as fail_two_err : Str
import "../fixtures/check/out/unit-warn.stderr" as warn_err : Str

UnitsTest :: [].{}

nt = "nightly-2026-10-14-38a3029"

other = "nightly-2026-10-09-258ab27"

pkgs = "/h/.cache/roc/packages"

# A release URL of the fixture host. The hash is letters and digits only.
hash_of = |repo, ver| "${repo}x${ver.replace_each(".", "x")}"

u = |repo, ver| "https://github.com/acme/${repo}/releases/download/${ver}/${hash_of(repo, ver)}.tar.zst"

# A release row of `Closure.Walked`.
rel = |repo, ver, alias, is_pf| {
	id: u(repo, ver),
	kind: Release,
	alias,
	name: "acme/${repo}",
	form: "github.com/acme/${repo}/releases/download/{v}/",
	version: ver,
	series: "1",
	direct: Bool.True,
	via: Err(None),
	raised: Err(None),
	is_platform: is_pf,
}

# A row of a path entry or a foreign URL: no hash.
no_hash = |kind, id, alias| { id, kind, alias, name: id, form: "", version: "", series: "", direct: Bool.True, via: Err(None), raised: Err(None), is_platform: Bool.False }

node = |repo, ver, is_pf| { hash: hash_of(repo, ver), name: "acme/${repo}", version: ver, is_platform: is_pf }

pf = node("pf", "0.1.0", Bool.True)

json = node("json", "2.1.0", Bool.False)

parser = node("parser", "1.0.0", Bool.False)

util = node("util", "1.0.0", Bool.False)

# The spec of a unit probe (the type makes the numbers U64).
spec : Units.Node, U64 -> Probe.Spec
spec = |n, t| { compiler: nt, program: "/h/bin/roc", args: ["check", "main.roc"], dir: "${pkgs}/${n.hash}", env: [("XDG_CACHE_HOME", "/h/.cache")], timeout: t, weight: 1 }

key = |n, nightly| { hash: n.hash, nightly, target: "any" }

fact = |n, nightly, outcome, modules| { hash: n.hash, nightly, target: "any", outcome, modules, closure: "" }

# R-LD2 R-LD3 R-AL4 R-EF1 R-NS12 R-PP3 R-PP6 R-P4 (slice 031): the nodes of a closure and the unit probes of the nodes with no fact. The nodes are the release rows of the closures (a path row and a foreign row have no hash), the
# platform is marked, 2 members share a hash once. A key has the target `any` (a check) and the compiler id. A fact of another compiler is no fact. The spec of a unit probe is `check main.roc` in the package dir, with the weight of a check.
expect {
	first = {
		rows: [rel("pf", "0.1.0", "pf", Bool.True), rel("json", "2.1.0", "json", Bool.False), no_hash(Path, "/p/lib/main.roc", "lib"), rel("parser", "1.0.0", "parser", Bool.False), no_hash(Foreign, "https://example.org/x.tar.zst", "ext")],
		links: [],
	}
	second = { rows: [rel("pf", "0.1.0", "pf", Bool.True), rel("util", "1.0.0", "util", Bool.False), rel("json", "2.1.0", "json", Bool.False)], links: [] }
	all = [pf, json, parser]
	facts = [fact(pf, nt, Pass, []), fact(json, other, Pass, []), fact(parser, nt, Fail, ["Yaml.roc"])]
	row = |label, got, want| (label, Str.inspect(got), Str.inspect(want))
	rows = [
		row("nodes of one closure: the release rows, in order", Units.nodes([first]), all),
		row("nodes of 2 closures: a shared hash once, at its first place", Units.nodes([first, second]), [pf, json, parser, util]),
		row("no closure, no node", Units.nodes([]), []),
		row("keys: the target any and the compiler", Units.keys({ nodes: all, nightly: nt }), [key(pf, nt), key(json, nt), key(parser, nt)]),
		row("missing: a fact of this compiler counts, a fact of another compiler does not", Units.missing({ nodes: all, nightly: nt, facts }), [json]),
		row("missing: the other compiler", Units.missing({ nodes: all, nightly: other, facts }), [pf, parser]),
		row("missing: no fact at all", Units.missing({ nodes: all, nightly: nt, facts: [] }), all),
		row("missing: a fact of a hash that is not a node", Units.missing({ nodes: [json], nightly: nt, facts: [fact(pf, nt, Pass, [])] }), [json]),
		row("specs: one check for each node, in order, in the package dir", Units.specs({ nodes: [json, parser], compiler: nt, program: "/h/bin/roc", env: [("XDG_CACHE_HOME", "/h/.cache")], pkgs, timeout: 30 }), [spec(json, 30), spec(parser, 30)]),
		row("specs: the timeout of the settings", Units.specs({ nodes: [pf], compiler: nt, program: "/h/bin/roc", env: [("XDG_CACHE_HOME", "/h/.cache")], pkgs, timeout: 7 }), [spec(pf, 7)]),
		row("specs: no node, no probe", Units.specs({ nodes: [], compiler: nt, program: "/h/bin/roc", env: [], pkgs, timeout: 30 }), []),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-P5 R-PP4 R-UP7 (slice 031, question Q2): the budget of one round. Each probe that starts counts. The baseline (`fixed`) must run: when `probe.max` leaves less than that, no probe starts (`Spent`).
# The unit probes fill what is left after it, in the order of the list: the first `run` start, and `cut` says that some did not.
expect {
	budget = |max, started, fixed, wanted| Units.budget({ max, started, fixed, wanted })
	rows = [
		("the default budget, 3 units", budget(100, 0, 1, 3), Ok({ run: 3, cut: Bool.False })),
		("exactly full: baseline and 4 units are 5", budget(5, 0, 1, 4), Ok({ run: 4, cut: Bool.False })),
		("one too many: 4 run, 1 is cut", budget(5, 0, 1, 5), Ok({ run: 4, cut: Bool.True })),
		("probes that started before count", budget(5, 2, 1, 3), Ok({ run: 2, cut: Bool.True })),
		("no unit wanted", budget(5, 4, 1, 0), Ok({ run: 0, cut: Bool.False })),
		("the baseline is the last probe that fits", budget(4, 3, 1, 2), Ok({ run: 0, cut: Bool.True })),
		("the baseline does not fit", budget(3, 3, 1, 0), Err(Spent)),
		("more started than the budget", budget(3, 5, 1, 2), Err(Spent)),
		("a budget of 0", budget(0, 0, 1, 0), Err(Spent)),
		("a candidate check alone, none left", budget(5, 5, 1, 0), Err(Spent)),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# The text of a result: the failure of a `Try` as its line.
view = |r| match r {
	Ok(_) => "ok"
	Err(f) => Fail.line(f)
}

# R-P2 R-P3 R-P4 R-RC1 to R-RC4 R-PP3 R-LD2 R-UM1 (slice 031): the facts of the outputs of the unit probes, in the order of the nodes. The real outputs of the pinned roc: a pass, an error in `Yaml.roc`, errors in 2 modules (sorted), warnings only
# (exit 2: R-P2, a pass). A hang and a crash are facts (R-P3). An error in the package of another hash, and an error in `main.roc`, are a fail: the first has no module of this hash, the second has the module `main.roc`.
# A signal from outside (SIGKILL) and a probe that did not start give no fact: the first of them is the failure `Internal`, with the label of the node, and the other facts stay.
expect {
	run = |nodes, ends| Units.results({ nodes, outputs: ends, nightly: nt, compiler: nt, pkgs })
	exited = |code, out, err| { ended: Exited(code), stdout: out, stderr: err }
	foreign = "── ✗ type mismatch ─────────────────────────── ../${hash_of("other", "1.0.0")}/Lib.roc:3:1\n\nThe body.\n\n── 1 error and 0 warnings ───────────────────────────── main.roc\n"
	header = "── ✗ syntax problem ─────────────────────────────── main.roc:1:1\n\nThe body.\n\n── 1 error and 0 warnings ───────────────────────────── main.roc\n"
	nodes = [node("a", "1.0.0", Bool.False), node("b", "1.0.0", Bool.False), node("c", "1.0.0", Bool.False), node("d", "1.0.0", Bool.False), pf, node("e", "1.0.0", Bool.False), node("f", "1.0.0", Bool.False), node("g", "1.0.0", Bool.False)]
	ends = [
		exited(0, pass_out, ""),
		exited(1, "", fail_err),
		exited(1, "", fail_two_err),
		exited(2, "", warn_err),
		{ ended: Signaled(11), stdout: "", stderr: "" },
		{ ended: TimedOut, stdout: "", stderr: "" },
		exited(1, "", foreign),
		exited(1, "", header),
	]
	all = run(nodes, ends)
	wanted = [
		fact(node("a", "1.0.0", Bool.False), nt, Pass, []),
		fact(node("b", "1.0.0", Bool.False), nt, Fail, ["Yaml.roc"]),
		fact(node("c", "1.0.0", Bool.False), nt, Fail, ["Parser.roc", "Yaml.roc"]),
		fact(node("d", "1.0.0", Bool.False), nt, Pass, []),
		fact(pf, nt, Crash, []),
		fact(node("e", "1.0.0", Bool.False), nt, Hang, []),
		fact(node("f", "1.0.0", Bool.False), nt, Fail, []),
		fact(node("g", "1.0.0", Bool.False), nt, Fail, ["main.roc"]),
	]
	killed = run([json, parser, util], [exited(0, pass_out, ""), { ended: Signaled(9), stdout: "", stderr: "" }, { ended: NotStarted("no such file"), stdout: "", stderr: "" }])
	unstarted = run([pf, json], [{ ended: NotStarted("cannot run"), stdout: "", stderr: "" }, exited(0, pass_out, "")])
	empty = run([], [])
	check = |label, a, b| (label, Str.inspect(a), Str.inspect(b))
	checks = [
		check("the facts of 8 outputs", all.facts, wanted),
		check("no failure when each output is a fact", all.failure.map_ok(|f| Fail.line(f)), Err(None)),
		check("a pass, SIGKILL, not started: one fact", killed.facts, [fact(json, nt, Pass, [])]),
		check("the first output with no fact is the failure", killed.failure.map_ok(|f| Fail.line(f)), Ok("tln: error[internal]: the unit check of acme/parser 1.0.0 on ${nt} gave no result: signal 9. Run the command again.")),
		check("the label of the platform", unstarted.failure.map_ok(|f| Fail.line(f)), Ok("tln: error[internal]: the unit check of the platform acme/pf 0.1.0 on ${nt} gave no result: not started: cannot run. Run the command again.")),
		check("the facts of the other nodes stay", unstarted.facts, [fact(json, nt, Pass, [])]),
		check("no node, no fact", empty.facts, []),
		check("no node, no failure", empty.failure.map_ok(|f| Fail.line(f)), Err(None)),
	]
	bad = checks.keep_if(|(_, a, b)| a != b).map(|(label, a, b)| (label, b, a))
	dbg bad
	bad == []
}

# The failing modules in a baseline and in a used list, for the verdict.
base_err = |n, path| { file: Package({ hash: n.hash, path }), title: "type mismatch", message: "a" }

app_err = { file: App("main.roc"), title: "type mismatch", message: "a" }

# R-LD2 R-LD3 R-UM1 R-P6 R-EP7 R-PH10 R-PH13 (slice 031, questions Q1 and Q4 of the slice): the verdict on the facts of the nodes. A unit fail is a hard fail only when the app uses a failing module (`used`), and when the baseline does not
# explain it (an error of the baseline in the same hash and module is not new: R-P6). `main.roc` is used by every node. A fail with no module is a hard fail (Q4 of slice 030). A hang and a crash are a fail of the tuple (R-EP7). A node with no fact
# (`--no-probe`, the budget) and a fact of another compiler are no blame. The message names each blamed node in the order of the nodes, the platform as `the platform <name> <version>`.
expect {
	nodes = [pf, json, parser, util]
	judge = |facts, baseline, used| view(Units.judge({ nodes, facts, nightly: nt, compiler: nt, baseline, used }))
	blame = |text| "tln: error[no_tuple]: no tuple works: the unit check on ${nt} fails for ${text}"
	passes = [fact(pf, nt, Pass, []), fact(json, nt, Pass, []), fact(parser, nt, Pass, []), fact(util, nt, Pass, [])]
	used_json = [{ hash: json.hash, path: "Json.roc" }]
	rows = [
		("all pass", judge(passes, [], []), "ok"),
		("a fail in a used module is blamed with the used modules only", judge([fact(json, nt, Fail, ["Json.roc", "Wire.roc"])], [], used_json), blame("acme/json 2.1.0 (Json.roc)")),
		("a fail in a module that the app does not use is ignored (R-UM1)", judge([fact(json, nt, Fail, ["Wire.roc"])], [], used_json), "ok"),
		("a fail and no used module at all is ignored", judge([fact(json, nt, Fail, ["Wire.roc"])], [], []), "ok"),
		("main.roc is used by every node", judge([fact(json, nt, Fail, ["main.roc"])], [], []), blame("acme/json 2.1.0 (main.roc)")),
		("a fail with no module is a hard fail (Q4)", judge([fact(json, nt, Fail, [])], [], []), blame("acme/json 2.1.0 (no module is named)")),
		("a hang", judge([fact(parser, nt, Hang, [])], [], []), blame("acme/parser 1.0.0 (hangs)")),
		("a crash", judge([fact(util, nt, Crash, [])], [], []), blame("acme/util 1.0.0 (crashes)")),
		(
			"2 blames in the order of the nodes: the platform first",
			judge([fact(parser, nt, Hang, []), fact(pf, nt, Fail, ["Std.roc"]), fact(json, nt, Fail, ["Json.roc"])], [], [{ hash: pf.hash, path: "Std.roc" }, { hash: json.hash, path: "Json.roc" }]),
			blame("the platform acme/pf 0.1.0 (Std.roc); acme/json 2.1.0 (Json.roc); acme/parser 1.0.0 (hangs)"),
		),
		("the baseline explains the module (R-P6)", judge([fact(json, nt, Fail, ["Json.roc"])], [base_err(json, "Json.roc")], used_json), "ok"),
		(
			"the baseline explains one module of 2: the other is blamed",
			judge([fact(json, nt, Fail, ["Json.roc", "Wire.roc"])], [base_err(json, "Json.roc")], [{ hash: json.hash, path: "Json.roc" }, { hash: json.hash, path: "Wire.roc" }]),
			blame("acme/json 2.1.0 (Wire.roc)"),
		),
		("an error of the baseline in another hash or in the app does not explain it", judge([fact(json, nt, Fail, ["Json.roc"])], [base_err(parser, "Json.roc"), base_err(json, "Wire.roc"), app_err], used_json), blame("acme/json 2.1.0 (Json.roc)")),
		("the baseline does not explain a hang", judge([fact(parser, nt, Hang, [])], [base_err(parser, "Parser.roc")], []), blame("acme/parser 1.0.0 (hangs)")),
		("no fact for a node: no blame", judge([fact(pf, nt, Pass, [])], [], []), "ok"),
		("a fact of another compiler is no fact", judge([fact(json, other, Fail, ["Json.roc"]), fact(parser, other, Hang, [])], [], used_json), "ok"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-UM1 R-P6 (slice 031): which nodes need the scan of the used modules. A node with a fail fact of this compiler that has a module that the baseline does not explain. A pass, a fault, no fact, a fail with no module (it is a hard fail with no scan),
# a fact of another compiler, and a fail that the baseline explains in full need none.
expect {
	nodes = [pf, json, parser, util]
	suspects = |facts, baseline| Units.suspects({ nodes, facts, nightly: nt, baseline })
	rows = [
		("a fail with a module", suspects([fact(json, nt, Fail, ["Json.roc"])], []), [json]),
		("the platform too, in the order of the nodes", suspects([fact(json, nt, Fail, ["Json.roc"]), fact(pf, nt, Fail, ["Std.roc"])], []), [pf, json]),
		("a pass, a hang, a crash", suspects([fact(json, nt, Pass, []), fact(parser, nt, Hang, []), fact(util, nt, Crash, [])], []), []),
		("a fail with no module needs no scan", suspects([fact(json, nt, Fail, [])], []), []),
		("no fact", suspects([], []), []),
		("another compiler", suspects([fact(json, other, Fail, ["Json.roc"])], []), []),
		("the baseline explains the whole fail", suspects([fact(json, nt, Fail, ["Json.roc", "Wire.roc"])], [base_err(json, "Json.roc"), base_err(json, "Wire.roc")]), []),
		("the baseline explains one module of 2", suspects([fact(json, nt, Fail, ["Json.roc", "Wire.roc"])], [base_err(json, "Json.roc")]), [json]),
		("the baseline of another hash does not explain it", suspects([fact(json, nt, Fail, ["Json.roc"])], [base_err(parser, "Json.roc")]), [json]),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-P5 R-UP7 R-EC12 (slice 031): the failure of a spent budget is kind `Budget` (exit 12) and names `probe.max`. With units that did not run, it says how many and that the facts are saved (the next run goes on).
expect {
	rows = [
		("no unit left over", Fail.line(Units.spent({ max: 100, left: 0 })), "tln: error[budget]: the probe budget is spent: probe.max is 100. Set probe.max higher."),
		("one unit", Fail.line(Units.spent({ max: 5, left: 1 })), "tln: error[budget]: the probe budget is spent: probe.max is 5 and 1 unit check did not run. Run the command again to go on (the facts are saved), or set probe.max higher."),
		("4 units", Fail.line(Units.spent({ max: 5, left: 4 })), "tln: error[budget]: the probe budget is spent: probe.max is 5 and 4 unit checks did not run. Run the command again to go on (the facts are saved), or set probe.max higher."),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
