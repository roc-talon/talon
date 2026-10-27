import Closure
import Db
import Facts
import Fail
import Ident
import Probe
import Text

## Ladder step 1: the unit probes (Resolution 4 "Probes" R-LD2, R-LD3, R-UM1; Resolution 5 R-AL4; Design 7 R-PH9). Part A (pure). `Ladder.run!` is the command code: it asks for the facts, runs the probes of this module,
## stores the facts and judges them (slice 031). A unit probe is `roc check main.roc` in the dir of one package of the closure of the candidate (`<cache>/packages/<hash>/`), with the compiler that runs the ladder.
## It is the same probe for a package (R-LD2) and for the platform (R-LD3). Only the text of the blame is different.
##
## ```mermaid
## flowchart TD
##     A["Units.nodes: the packages of the closure of the candidate"] --> B["Facts.load!: one query for the keys (R-EF1)"]
##     B --> C["Units.missing: the nodes with no fact (R-AL4)"]
##     C --> D["Units.budget: how many may start (R-P5, R-PP4)"]
##     D --> E["probes!: the baseline and the unit probes, one round (R-PP2, R-PP3)"]
##     E --> F["Units.results: the facts (R-P2, R-P3, R-P4)"]
##     F --> G["Facts.save! (Replace): one write for the round (R-PP4)"]
##     G --> H{"Units.suspects: a fail that the baseline does not explain?"}
##     H -->|"yes"| I["the scan of the used modules (Uses, R-UM1)"]
##     H -->|"no"| J["Units.judge"]
##     I --> J
##     J -->|"blame"| X["NoTuple, exit 10"]
##     J -->|"ok"| K["step 2: the check of the candidate"]
## ```
Units :: [].{

	## One package of the closure: `hash` is the hash of its URL (the dir name in `packages/`), `name` is `Closure.Row.name`, `version` is `Closure.Row.version`. `is_platform` marks the platform (R-LD3).
	Node : { hash : Str, name : Str, version : Str, is_platform : Bool }

	## The packages of the closures, one `Node` for each `Release` row (`Closure.Walked.rows`), in the order of the rows. A `Path` row and a `Foreign` row have no hash and give no node: a path
	## file is part of the app (R-LD7). A hash that 2 closures have (2 members) is one node, at its first place. The hash is `Ident.of_url` of the id of the row.
	nodes : List(Closure.Walked) -> List(Node)
	nodes = |closures| closures
		.join_map(|walked| walked.rows.keep_oks(node_of))
		.fold([], |found, node| if found.any(|seen| seen.hash == node.hash) found else found.append(node))

	## The keys of `compat.db` for the nodes (R-EF1, R-P4): `{ hash, nightly, target: "any" }` for each node (a check has the target `any`), in the order of the nodes. `nightly` is the id of the compiler that runs
	## the ladder (`Start.Started.id`: R-NS12, a release is a compiler id in the same fact).
	keys : { nodes : List(Node), nightly : Str } -> List(Db.Key)
	keys = |facts| facts.nodes.map(|node| { hash: node.hash, nightly: facts.nightly, target: "any" })

	## The nodes that have no fact in `facts` for `nightly` and the target `any` (R-AL4: "for each pair (hash, roc) with no fact, run a unit probe"), in the order of `nodes`. A fact of another compiler is no fact.
	missing : { nodes : List(Node), nightly : Str, facts : List(Db.Fact) } -> List(Node)
	missing = |facts| facts.nodes.keep_if(|node| fact_of(facts.facts, node, facts.nightly) == Err(None))

	## The unit probes of the nodes, in the order of the nodes (R-PP3). Each spec: `compiler`, `program`, `env` and `timeout` of the facts, `args` `["check", "main.roc"]` (`Probe.args`), `dir` is `<pkgs>/<hash>` (`Text.join`),
	## `weight` is `Probe.weight(Check)` (R-PP6). The working dir is the package dir, so a report names a module as `Yaml.roc` (the measured output of the pinned roc, `tests/fixtures/check/out/unit-fail.stderr`). An absolute path is
	## cut at the left by roc when it is long, so Talon never gives one.
	specs : { nodes : List(Node), compiler : Str, program : Str, env : List((Str, Str)), pkgs : Str, timeout : U64 } -> List(Probe.Spec)
	specs = |facts| facts.nodes.map(
		|node| {
			compiler: facts.compiler,
			program: facts.program,
			args: Probe.args({ command: Check, file: "main.roc" }),
			dir: Text.join(facts.pkgs, node.hash),
			env: facts.env,
			timeout: facts.timeout,
			weight: Probe.weight(Check),
		},
	)

	## The budget of one round (R-P5, R-PP4: each probe that starts counts against `probe.max`). `started` is the number of probes that this command started before the round, `fixed` is the number of probes of the round that
	## must run (the baseline: 1), `wanted` is the number of unit probes that the round wants. The result:
	##
	## | Case | Result |
	## | --- | --- |
	## | `max - started` (0 when `started` is above `max`) is less than `fixed` | `Err(Spent)`: no probe of the round starts |
	## | `wanted` fits in what is left after `fixed` | `Ok({ run: wanted, cut: Bool.False })` |
	## | Else | `Ok({ run: <what is left after fixed>, cut: Bool.True })`: the first `run` unit probes start, in the order of the list |
	budget : { max : U64, started : U64, fixed : U64, wanted : U64 } -> Try({ run : U64, cut : Bool }, [Spent])
	budget = |facts| {
		left = if facts.max > facts.started facts.max - facts.started else 0
		if left < facts.fixed {
			Err(Spent)
		} else {
			room = left - facts.fixed
			if facts.wanted <= room Ok({ run: facts.wanted, cut: Bool.False }) else Ok({ run: room, cut: Bool.True })
		}
	}

	## The facts of the outputs of the unit probes (`outputs` are in the order of `nodes`, R-PP3). One `Db.Fact` for each probe that gives a fact (`Facts.of_probe`: the target `any`, the class, the failing modules of this hash, no closure).
	## `Probe.errors` reads the stderr with `dir` `<pkgs>/<hash>` and `pkgs`. A warning is a pass (R-P2). A hang and a crash are facts (R-P3: a fault of the compiler). A download error and a signal from outside (SIGKILL, SIGTERM, SIGINT, SIGHUP)
	## and a probe that did not start give no fact (R-P3). The first of them is `failure`, kind `Internal` (exit 1): `the unit check of <label> on <compiler> gave no result: <text>. Run the command again.` (`<text>` is the text of `Probe.Class.NoFact`;
	## `<label>` is `<name> <version>`, or `the platform <name> <version>`). The other nodes keep their facts: the command stores them first.
	results : { nodes : List(Node), outputs : List(Probe.Output), nightly : Str, compiler : Str, pkgs : Str } -> { facts : List(Db.Fact), failure : Try(Fail, [None]) }
	results = |facts| {
		rows = facts.nodes.map2(facts.outputs, |node, output| (node, Probe.classify(output), output))
		made = rows.map(|(node, class, output)| (node, class, Facts.of_probe({ hash: node.hash, nightly: facts.nightly, host: "", command: Check, class, errors: Probe.errors({ text: output.stderr, dir: Text.join(facts.pkgs, node.hash), pkgs: facts.pkgs }), closure: "" })))
		first = made.find_first(|(_, _, fact)| fact.is_err())
		{
			facts: made.keep_oks(|(_, _, fact)| fact),
			failure: match first {
				Ok((node, NoFact(text), _)) => Ok(Fail.new(Internal, "the unit check of ${label(node)} on ${facts.compiler} gave no result: ${text}. Run the command again."))
				_ => Err(None)
			},
		}
	}

	## The nodes for which the scan of the used modules is needed (R-UM1): the node has a `Fail` fact for `nightly` with at least one module, and at least one of its modules is not in the `baseline` errors (an error of the
	## baseline in `Package({ hash, path })` with the same hash and module explains that module: it is not new, R-P6, R-LD4). A node with a `Pass` fact, a fault, no fact or a `Fail` fact with no module needs no scan. In the order of `nodes`.
	suspects : { nodes : List(Node), facts : List(Db.Fact), nightly : Str, baseline : List(Probe.Err) } -> List(Node)
	suspects = |facts| facts.nodes.keep_if(|node| !new_modules(node, fact_of(facts.facts, node, facts.nightly), facts.baseline).is_empty())

	## The verdict on the facts of the nodes (R-LD2, R-LD3, R-UM1, R-P6, question Q1 of slice 031). `used` are the used modules that `Uses` found: a module is `{ hash, path }` with `path` relative to the package dir (`Yaml.roc`).
	## `main.roc` is used by every node (roc reads the header of each package of the closure). For each node in order, with its fact for `nightly` and the target `any`:
	##
	## | Fact | Blame |
	## | --- | --- |
	## | none (the node was not probed: `--no-probe`, or the budget) or `Pass` | none |
	## | `Hang` | `<label> (hangs)` |
	## | `Crash` | `<label> (crashes)` (R-EP7: a fault is a fail of the tuple for the release) |
	## | `Fail` with no module (R-UM1, Q4 of slice 030: an empty set is a hard fail) | `<label> (no module is named)` |
	## | `Fail` with modules | `<label> (<module>, <module>)`: the modules that are used, and that the `baseline` does not explain (the same rule as `suspects`), in the order of the fact (sorted). None left: no blame (the unit fail is ignored, the whole-app check decides). |
	##
	## `<label>` is `<name> <version>`, or `the platform <name> <version>` for the platform. The result is `Ok({})` when nothing is blamed, else `Err` of kind `NoTuple` (exit 10, R-PH10, R-PH13):
	## `no tuple works: the unit check on <compiler> fails for <blame>; <blame>` (the blames in the order of the nodes). It is `Fail.of_tuple` with the hash of each blamed node (slice 036b).
	judge : { nodes : List(Node), facts : List(Db.Fact), nightly : Str, compiler : Str, baseline : List(Probe.Err), used : List({ hash : Str, path : Str }) } -> Try({}, Fail)
	judge = |facts| {
		rows = facts.nodes.keep_oks(|node| blame_of(node, fact_of(facts.facts, node, facts.nightly), { baseline: facts.baseline, used: facts.used }).map_ok(|text| (node.hash, text)))
		if rows.is_empty() {
			Ok({})
		} else {
			Err(Fail.of_tuple("no tuple works: the unit check on ${facts.compiler} fails for ${Str.join_with(rows.map(|(_, text)| text), "; ")}", rows.map(|(hash, _)| hash)))
		}
	}

	## The failure of a spent budget (R-P5, R-UP7, R-EC12: kind `Budget`, exit 12). `max` is `probe.max`. `left` is the number of unit probes that did not run (0 when a probe that must run could not start).
	##
	## | `left` | Message (a proposal, TW24) |
	## | --- | --- |
	## | 0 | `the probe budget is spent: probe.max is <max>. Set probe.max higher.` |
	## | `n` | `the probe budget is spent: probe.max is <max> and <n> unit checks did not run. Run the command again to go on (the facts are saved), or set probe.max higher.` (`1 unit check` for 1) |
	spent : { max : U64, left : U64 } -> Fail
	spent = |facts| {
		base = "the probe budget is spent: probe.max is ${facts.max.to_str()}"
		text = match facts.left {
			0 => "${base}. Set probe.max higher."
			1 => "${base} and 1 unit check did not run. Run the command again to go on (the facts are saved), or set probe.max higher."
			n => "${base} and ${n.to_str()} unit checks did not run. Run the command again to go on (the facts are saved), or set probe.max higher."
		}
		Fail.new(Budget, text)
	}
}

# A `Release` row is a node. A path row and a foreign row have no hash (R-LD7).
node_of : Closure.Row -> Try(Units.Node, [NoNode])
node_of = |row| match row.kind {
	Release => match Ident.of_url(row.id) {
		Ok(ident) => Ok({ hash: ident.hash, name: row.name, version: row.version, is_platform: row.is_platform })
		Err(Foreign) => Err(NoNode)
	}
	_ => Err(NoNode)
}

# R-AL4: the fact of a node for a compiler (the target of a check is `any`).
fact_of : List(Db.Fact), Units.Node, Str -> Try(Db.Fact, [None])
fact_of = |facts, node, nightly| match facts.find_first(|fact| fact.hash == node.hash and fact.nightly == nightly and fact.target == "any") {
	Ok(fact) => Ok(fact)
	Err(_) => Err(None)
}

# `<name> <version>`, or `the platform <name> <version>` (R-LD3).
label : Units.Node -> Str
label = |node| if node.is_platform "the platform ${node.name} ${node.version}" else "${node.name} ${node.version}"

# R-P6: the modules of a fail fact that the baseline does not explain (an error of the baseline in the same hash and module).
new_modules : Units.Node, Try(Db.Fact, [None]), List(Probe.Err) -> List(Str)
new_modules = |node, found, baseline| match found {
	Ok({ outcome: Fail, modules, .. }) => modules.keep_if(|path| !baseline.any(|err| err.file == Package({ hash: node.hash, path })))
	_ => []
}

# R-UM1: the blame of one node, or none. A fail is blamed for the modules that are used.
blame_of : Units.Node, Try(Db.Fact, [None]), { baseline : List(Probe.Err), used : List({ hash : Str, path : Str }) } -> Try(Str, [None])
blame_of = |node, found, facts| match found {
	Err(None) => Err(None)
	Ok(fact) => match fact.outcome {
		Pass => Err(None)
		Hang => Ok("${label(node)} (hangs)")
		Crash => Ok("${label(node)} (crashes)")
		Fail => if fact.modules.is_empty() {
			Ok("${label(node)} (no module is named)")
		} else {
			hit = new_modules(node, found, facts.baseline).keep_if(|path| path == "main.roc" or facts.used.contains({ hash: node.hash, path }))
			if hit.is_empty() Err(None) else Ok("${label(node)} (${Str.join_with(hit, ", ")})")
		}
	}
}
