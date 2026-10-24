import Closure
import Db
import Fail
import Probe

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
	nodes = |_closures| crash "todo"

	## The keys of `compat.db` for the nodes (R-EF1, R-P4): `{ hash, nightly, target: "any" }` for each node (a check has the target `any`), in the order of the nodes. `nightly` is the id of the compiler that runs
	## the ladder (`Start.Started.id`: R-NS12, a release is a compiler id in the same fact).
	keys : { nodes : List(Node), nightly : Str } -> List(Db.Key)
	keys = |_facts| crash "todo"

	## The nodes that have no fact in `facts` for `nightly` and the target `any` (R-AL4: "for each pair (hash, roc) with no fact, run a unit probe"), in the order of `nodes`. A fact of another compiler is no fact.
	missing : { nodes : List(Node), nightly : Str, facts : List(Db.Fact) } -> List(Node)
	missing = |_facts| crash "todo"

	## The unit probes of the nodes, in the order of the nodes (R-PP3). Each spec: `compiler`, `program`, `env` and `timeout` of the facts, `args` `["check", "main.roc"]` (`Probe.args`), `dir` is `<pkgs>/<hash>` (`Text.join`),
	## `weight` is `Probe.weight(Check)` (R-PP6). The working dir is the package dir, so a report names a module as `Yaml.roc` (the measured output of the pinned roc, `tests/fixtures/check/out/unit-fail.stderr`). An absolute path is
	## cut at the left by roc when it is long, so Talon never gives one.
	specs : { nodes : List(Node), compiler : Str, program : Str, env : List((Str, Str)), pkgs : Str, timeout : U64 } -> List(Probe.Spec)
	specs = |_facts| crash "todo"

	## The budget of one round (R-P5, R-PP4: each probe that starts counts against `probe.max`). `started` is the number of probes that this command started before the round, `fixed` is the number of probes of the round that
	## must run (the baseline: 1), `wanted` is the number of unit probes that the round wants. The result:
	##
	## | Case | Result |
	## | --- | --- |
	## | `max - started` (0 when `started` is above `max`) is less than `fixed` | `Err(Spent)`: no probe of the round starts |
	## | `wanted` fits in what is left after `fixed` | `Ok({ run: wanted, cut: Bool.False })` |
	## | Else | `Ok({ run: <what is left after fixed>, cut: Bool.True })`: the first `run` unit probes start, in the order of the list |
	budget : { max : U64, started : U64, fixed : U64, wanted : U64 } -> Try({ run : U64, cut : Bool }, [Spent])
	budget = |_facts| crash "todo"

	## The facts of the outputs of the unit probes (`outputs` are in the order of `nodes`, R-PP3). One `Db.Fact` for each probe that gives a fact (`Facts.of_probe`: the target `any`, the class, the failing modules of this hash, no closure).
	## `Probe.errors` reads the stderr with `dir` `<pkgs>/<hash>` and `pkgs`. A warning is a pass (R-P2). A hang and a crash are facts (R-P3: a fault of the compiler). A download error and a signal from outside (SIGKILL, SIGTERM, SIGINT, SIGHUP)
	## and a probe that did not start give no fact (R-P3). The first of them is `failure`, kind `Internal` (exit 1): `the unit check of <label> on <compiler> gave no result: <text>. Run the command again.` (`<text>` is the text of `Probe.Class.NoFact`;
	## `<label>` is `<name> <version>`, or `the platform <name> <version>`). The other nodes keep their facts: the command stores them first.
	results : { nodes : List(Node), outputs : List(Probe.Output), nightly : Str, compiler : Str, pkgs : Str } -> { facts : List(Db.Fact), failure : Try(Fail, [None]) }
	results = |_facts| crash "todo"

	## The nodes for which the scan of the used modules is needed (R-UM1): the node has a `Fail` fact for `nightly` with at least one module, and at least one of its modules is not in the `baseline` errors (an error of the
	## baseline in `Package({ hash, path })` with the same hash and module explains that module: it is not new, R-P6, R-LD4). A node with a `Pass` fact, a fault, no fact or a `Fail` fact with no module needs no scan. In the order of `nodes`.
	suspects : { nodes : List(Node), facts : List(Db.Fact), nightly : Str, baseline : List(Probe.Err) } -> List(Node)
	suspects = |_facts| crash "todo"

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
	## `no tuple works: the unit check on <compiler> fails for <blame>; <blame>` (the blames in the order of the nodes).
	judge : { nodes : List(Node), facts : List(Db.Fact), nightly : Str, compiler : Str, baseline : List(Probe.Err), used : List({ hash : Str, path : Str }) } -> Try({}, Fail)
	judge = |_facts| crash "todo"

	## The failure of a spent budget (R-P5, R-UP7, R-EC12: kind `Budget`, exit 12). `max` is `probe.max`. `left` is the number of unit probes that did not run (0 when a probe that must run could not start).
	##
	## | `left` | Message (a proposal, TW24) |
	## | --- | --- |
	## | 0 | `the probe budget is spent: probe.max is <max>. Set probe.max higher.` |
	## | `n` | `the probe budget is spent: probe.max is <max> and <n> unit checks did not run. Run the command again to go on (the facts are saved), or set probe.max higher.` (`1 unit check` for 1) |
	spent : { max : U64, left : U64 } -> Fail
	spent = |_facts| crash "todo"
}
