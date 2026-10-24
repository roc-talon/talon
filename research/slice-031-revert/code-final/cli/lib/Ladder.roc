import Closure
import Compiler
import Db
import Facts
import Fail
import Fx
import Item
import Locked
import Pin
import Probe
import Rebase
import Roots
import Start
import Temp
import Text
import UnitFlow
import Units

## The probe ladder on the one selected tuple (Resolution 4 "Probes", "Baseline check"; Design 7 R-PH9, R-PH10, R-PH13). The ladder runs in 3 rounds (slice 031, D1): round 1 is the baseline check and the unit probes
## of the packages with no fact (step 1, R-LD2, R-LD3: `UnitFlow`, `Units`), round 2 is the whole-app check of the candidate header in a temp copy, round 3 is the build (R-LD4, R-LD5). There is no build skip yet (R-BS1, R-BS2: slice 032).
## The pure decisions are here (part A). `Ladder.run!` is the command code. `--no-check` skips all of it (R-BL6, R-LF3). A ladder that fails stops the command with the blame, and `Resolve` writes nothing (R-PH10).
##
## ```mermaid
## flowchart TD
##     A["Resolve.finish!: the tuple is chosen, the edits are known, --no-check is false"] --> B["Start.run! (R-PH7, R-DL1): the compiler, or its required download, or exit 13 before any probe"]
##     B --> C["for each member that changes: copy the app dir, write the candidate header into the copy"]
##     C --> D["probes!: baseline check (project dir) and the unit probes, round 1; then the candidate check (copy), round 2"]
##     D --> E{"Ladder.baseline, UnitFlow.verdict!, Ladder.check"}
##     E -->|"stop"| X["delete the copy, failure: exit 1, 10 or 11"]
##     E -->|"pass"| F["probes!: build (copy), round 3"]
##     F --> G{"Ladder.build"}
##     G -->|"stop"| X
##     G -->|"pass"| H["delete the copy, print the lines"]
##     H --> I["Resolve.write!"]
## ```
Ladder :: [].{

	## The owner of a hash in the candidate header (the `name` is `owner/repo`, as `Vars` gives it, or the URL form when there is none). `is_platform` marks
	## the platform entry (R-LD5: a build error that no file owns blames the platform).
	## The facts of the consent rules for a compiler that is not installed (slice 025, `Start.Downloads`).
	Downloads : Start.Downloads

	Owner : { hash : Str, name : Str, version : Str, is_platform : Bool }

	## The probes of one member (a project file whose header changes), in the order of the results (R-PP3: the order of the list, never the order of the
	## ends). `first` is one round: the baseline (R-BL1: the current header, in the project dir) and the candidate check (R-BL2, R-LD4: the copy). `build` is
	## step 3 (R-LD5): in the copy, once (R-LD6). A project file that is a package or a platform has no app, so it has no build (R-LD7). `copy` is the
	## temp dir (`Roots.item(roots, TalonTmp(<16hex>))`). `dir` and `file` are the directory and the name of the project file. The output file of the build is
	## `<copy>/tln-probe.out`. Each `Spec` has the compiler `compiler`, the dir and `timeout`. Slice 023c: and the `program` and the `env` of the facts, the same for each probe of the plan (R-PX2, R-PX6).
	Plan : { first : List(Probe.Spec), build : Try(Probe.Spec, [None]) }

	plan : { compiler : Str, program : Str, env : List((Str, Str)), kind : [App, Package, Platform], dir : Str, file : Str, copy : Str, timeout : U64 } -> Plan
	plan = |facts| {
		spec = |dir, args, weight| { compiler: facts.compiler, program: facts.program, args, dir, env: facts.env, timeout: facts.timeout, weight }
		check_args = Probe.args({ command: Check, file: facts.file })
		output = Text.join(facts.copy, "tln-probe.out")
		build = match facts.kind {
			App => Ok(spec(facts.copy, Probe.args({ command: Build({ output: output }), file: facts.file }), 4))
			Package | Platform => Err(None)
		}
		{ first: [spec(facts.dir, check_args, 1), spec(facts.copy, check_args, 1)], build }
	}

	## One replacement of `--replace-dep` (R-CM11, R-LB2): `old` is the URL that the header has, `new` is the URL of the tuple. `tln verify` checks the tuple with these, so it needs no copy of the app.
	Replace : { old : Str, new : Str }

	## The probes of one member for `tln verify` (R-CM11, R-LB2): the same steps as `plan`, with no copy. The baseline and the candidate check run in the project dir `dir` (one round, in this order). The candidate and the build have
	## the arguments of `Probe.replace_args` (`--replace-dep <old> <new>` for each replacement, after the file). `tmp` is a temp dir (`Roots.item(roots, TalonTmp(<16hex>))`) that holds only the output file of the build
	## (`<tmp>/tln-probe.out`). A package or a platform has no build (R-LD7). `replace` can be empty: the candidate check then has no replacement (the tuple is the header, question Q4).
	plan_replace : { compiler : Str, program : Str, env : List((Str, Str)), kind : [App, Package, Platform], dir : Str, file : Str, tmp : Str, replace : List(Replace), timeout : U64 } -> Plan
	plan_replace = |facts| {
		spec = |args, weight| { compiler: facts.compiler, program: facts.program, args, dir: facts.dir, env: facts.env, timeout: facts.timeout, weight }
		flagged = |command| Probe.replace_args({ command, file: facts.file, replace: facts.replace })
		output = Text.join(facts.tmp, "tln-probe.out")
		build = match facts.kind {
			App => Ok(spec(flagged(Build({ output: output })), 4))
			Package | Platform => Err(None)
		}
		{ first: [spec(Probe.args({ command: Check, file: facts.file }), 1), spec(flagged(Check), 1)], build }
	}

	## The lines that the command prints for a step that passed (R-BL5: an error that both runs have is "unchanged", an error that only the baseline has
	## is "removed", both are notes and are never blamed). Texts are a proposal (TW24). `<where>` is the path for an app file, `<name> <version> <module>`
	## for a package file of a known owner, `<hash> <module>` for another package file, and `no file` for an error that has no file.
	##
	## | Step | Lines |
	## | --- | --- |
	## | check | `check: passed`, then `note: unchanged error: <where>: <title>` for each unchanged error, then `note: removed error: <where>: <title>` for each removed error |
	## | build | `build: passed` |
	Report : { lines : List(Str) }

	## The baseline (R-BL1, R-P7): `output` is the result of the check on the current header, run in `dir`. A pass is `Ok([])`, a fail is `Ok(its errors)`. Each other class
	## stops (a baseline that is not a set of errors gives no baseline, so each error would be new and the blame would be wrong, R-BL3):
	##
	## | Class | Failure | Text |
	## | --- | --- | --- |
	## | `Hang` | kind `Internal` (exit 1, R-EC1, R-P7) | `the baseline check hangs on <compiler> (no result in <timeout> s). That is a compiler fault. Fix it, or pass --no-check.` |
	## | `Crash(text)` | `Internal` | `the baseline check crashes on <compiler> (<text>). That is a compiler fault. Fix it, or pass --no-check.` |
	## | `NoFact(text)` | `Internal` | `the baseline check on <compiler> gave no result: <text>. Run the command again.` |
	## | `Fail(n)` with no error that `Probe.errors` can read (C6: the summary says `n` errors, but the output has no error report) | `Internal` | `the baseline check on <compiler> gave no result: <n> errors that tln cannot read. Run the command again.` (`1 error` for 1). An empty set would blame the wrong hash (R-BL3). |
	baseline : { output : Probe.Output, dir : Str, pkgs : Str, compiler : Str, timeout : U64 } -> Try(List(Probe.Err), Fail)
	baseline = |facts| match Probe.classify(facts.output) {
		Pass => Ok([])
		Fail(n) => match Probe.errors({ text: facts.output.stderr, dir: facts.dir, pkgs: facts.pkgs }) {
			[] => Err(unreadable("the baseline check on ${facts.compiler}", n))
			errors => Ok(errors)
		}
		Hang => Err(Fail.new(Internal, "the baseline check hangs on ${facts.compiler} (no result in ${facts.timeout.to_str()} s). That is a compiler fault. Fix it, or pass --no-check."))
		Crash(text) => Err(Fail.new(Internal, "the baseline check crashes on ${facts.compiler} (${text}). That is a compiler fault. Fix it, or pass --no-check."))
		NoFact(text) => Err(Fail.new(Internal, "the baseline check on ${facts.compiler} gave no result: ${text}. Run the command again."))
	}

	## Ladder step 2, the whole-app check of the candidate (R-LD4, R-BL5, R-P6, R-PH10). `baseline` is the result of `Ladder.baseline`. `owners` are the owners of the
	## hashes (the candidate header). `moved` are the entries that the command changes (for a fault). A candidate with no new error passes, also when the app has
	## errors (R-P6). The errors that are new (`Probe.compare`) are blamed:
	##
	## | Case | Failure | Text |
	## | --- | --- | --- |
	## | `Pass`, or `Fail` with no new error | `Ok(Report)` | (the lines of `Report`) |
	## | A new error in an app file (`App(...)`: the app is not a free variable) | kind `AppError` (exit 11, R-EC11). This wins over a blame of a hash. | `a new error in an app file: <path> (<title>); <path> (<title>). The app is not a free variable: fix it, or pass --no-check.` (only the app errors, in order) |
	## | New errors in the files of hashes (and none in app files) | kind `NoTuple` (exit 10, R-PH10, R-PH13) | `no tuple works: the whole-app check found new errors in <blame>; <blame>` |
	## | `Hang` | `NoTuple` | `no tuple works: the whole-app check hangs on <compiler> (no result in <timeout> s) with <moved>` (no ` with <moved>` when `moved` is empty) |
	## | `Crash(text)` | `NoTuple` | `no tuple works: the whole-app check crashes on <compiler> (<text>) with <moved>` (no ` with <moved>` when `moved` is empty) |
	## | `NoFact(text)` | `Internal` (exit 1) | `the whole-app check on <compiler> gave no result: <text>. Run the command again.` |
	## | `Fail(n)` with no readable error (C6) | `Internal` (exit 1) | `the whole-app check on <compiler> gave no result: <n> errors that tln cannot read. Run the command again.` (never a pass) |
	##
	## `<blame>` is `<name> <version> (<module>: <title>, <module>: <title>)` for each hash, in the order of its first new error, with its new errors in order.
	## A hash that is not in `owners` is `<hash>` in place of `<name> <version>`. `<moved>` is `<name> <version>` for each moved owner, joined with `, `.
	## A new error with no file in a check goes to the app (it is not a file of a hash).
	check : { output : Probe.Output, dir : Str, pkgs : Str, baseline : List(Probe.Err), owners : List(Owner), moved : List(Owner), compiler : Str, timeout : U64 } -> Try(Report, Fail)
	check = |facts| match Probe.classify(facts.output) {
		Pass => judge_check(facts.baseline, facts.owners, [])
		Fail(n) => match Probe.errors({ text: facts.output.stderr, dir: facts.dir, pkgs: facts.pkgs }) {
			[] => Err(unreadable("the whole-app check on ${facts.compiler}", n))
			errors => judge_check(facts.baseline, facts.owners, errors)
		}
		Hang => Err(Fail.new(NoTuple, "no tuple works: the whole-app check hangs on ${facts.compiler} (no result in ${facts.timeout.to_str()} s)${moved_text(facts.moved)}"))
		Crash(text) => Err(Fail.new(NoTuple, "no tuple works: the whole-app check crashes on ${facts.compiler} (${text})${moved_text(facts.moved)}"))
		NoFact(text) => Err(Fail.new(Internal, "the whole-app check on ${facts.compiler} gave no result: ${text}. Run the command again."))
	}

	## Ladder step 3, the build (R-LD5, R-LD6): `output` is the result of the build in the copy. `baseline` is the error set of the baseline check. The rules, in this order:
	##
	## | Case | Failure | Text |
	## | --- | --- | --- |
	## | `Pass` | `Ok({ lines: ["build: passed"] })` | |
	## | `Fail`: a new error (not in `baseline`) in an app file | `AppError` (exit 11) | as in `check` (the same text) |
	## | `Fail`: an error that has no file (a link error, a target that the platform lacks: R-LD5), and no new error in an app file | kind `NoTuple` (exit 10) | `no tuple works: the build for the host target failed on the platform <name> <version>: <title>; <title>` (the titles of the errors with no file, in order) |
	## | `Fail`: a new error in the file of a hash | `NoTuple` | `no tuple works: the build found new errors in <blame>` (`<blame>` as in `check`) |
	## | `Fail` and no new error and no error with no file (the same errors as the baseline) | `Ok({ lines: ["build: passed"] })` | |
	## | `Hang` | `NoTuple` | `no tuple works: the build hangs on <compiler> (no result in <timeout> s) on the platform <name> <version>` |
	## | `Crash(text)` | `NoTuple` | `no tuple works: the build crashes on <compiler> (<text>) on the platform <name> <version>` |
	## | `NoFact(text)` | `Internal` | `the build on <compiler> gave no result: <text>. Run the command again.` |
	## | `Fail(n)` with no readable error (C6) | `Internal` | `the build on <compiler> gave no result: <n> errors that tln cannot read. Run the command again.` (never a pass) |
	##
	## The rows 2 to 4 are in the order of the rules: a new error in an app file first, then an error with no file, then a new error in the file of a hash. `<name> <version>` of the
	## platform is the owner with `is_platform` (`the platform` alone when `owners` has none).
	build : { output : Probe.Output, dir : Str, pkgs : Str, baseline : List(Probe.Err), owners : List(Owner), compiler : Str, timeout : U64 } -> Try(Report, Fail)
	build = |facts| match Probe.classify(facts.output) {
		Pass => Ok({ lines: ["build: passed"] })
		Fail(n) => match Probe.errors({ text: facts.output.stderr, dir: facts.dir, pkgs: facts.pkgs }) {
			[] => Err(unreadable("the build on ${facts.compiler}", n))
			errors => judge_build(facts.baseline, facts.owners, errors)
		}
		Hang => Err(Fail.new(NoTuple, "no tuple works: the build hangs on ${facts.compiler} (no result in ${facts.timeout.to_str()} s) on ${platform_text(facts.owners)}"))
		Crash(text) => Err(Fail.new(NoTuple, "no tuple works: the build crashes on ${facts.compiler} (${text}) on ${platform_text(facts.owners)}"))
		NoFact(text) => Err(Fail.new(Internal, "the build on ${facts.compiler} gave no result: ${text}. Run the command again."))
	}

	## One member of `run!`: a project file whose header changes. `ops` are the edits of its header (`Locked.edit` gives the candidate text).
	Member : { file : Str, kind : [App, Package, Platform], text : Str, ops : List(Locked.Op) }

	## A member of `verify!`: a project file and its kind. The header is not read or edited (the candidate is the replacement).
	Checked : { file : Str, kind : [App, Package, Platform], text : Str }

	## Command code (part C) of `tln verify` (R-CM11, R-LB2). It is `run!` with no copy and no edit of a header. The calls for one member, in order (the L2 case `verify/vf1-flow` fixes them):
	##
	## | Step | Call |
	## | --- | --- |
	## | 0 | Once, before the first member: `Start.run!` (slice 025). It lists `<cache>/toolchains`, finds the compiler of `held` (`Compiler.find`) and, when it is not installed, applies the consent rules and the required download (R-DL1 to R-DL5, R-SO22). Then it calls `Launch.program!` (slice 024b, R-LK4) and `Launch.child_env!` (one `canonical!` call, R-PX6). A failure is returned (exit 13, R-PH7): no more call is made. The result has `downloads` (1 after a download, else 0). |
	## | 1 | `fx.random!()`, then `Temp.hex`: `tmp` is `Roots.item(roots, TalonTmp(hex))`. `fx.make_dirs!([tmp])` (the build writes its output there). |
	## | 2 | `Launch.touch!(fx, roots, { id, now })` when `installed` has `id` (R-CC9: before the compiler starts). Then `fx.probes!(plan.first)` (`plan_replace`: one round, the baseline and the candidate check, both in the dir of the member file) |
	## | 3 | `Ladder.baseline`, then `Ladder.check` with `dir` the dir of the member file for both. A failure goes to step 5. |
	## | 4 | When the plan has a build: `Launch.touch!` as in step 2, then `fx.probes!([build])`, then `Ladder.build` (`dir` is the dir of the member file). A failure goes to step 5. |
	## | 5 | `fx.delete!([tmp])`, also for a failure (R-CC2) |
	##
	## Slice 031 (R-CM11, R-LD2, R-LD3): `verify!` runs ladder step 1 too. The calls of one run, in order: after `Start.run!`, one `Facts.load!` (a `db_query` with the keys of the packages of `closures`, the candidate tuple), and for one member: `random`, `make_dirs`, round 1 (`probes!` with the baseline and the unit probes of the packages with no fact, as `run!`), `db_write` of the facts, round 2 (the candidate check), round 3 (the build, apps only). `closures` has one row for each member (`file`). `text` is the header text of the member (for the scan of the used modules). `no_probe`, the budget `probe.max`, the verdict and the failures are as for `run!`. The result `probes` is the number of probes that started.
	## The lines are printed and the notes are given as `run!` does it. The failures are the ones of `Ladder.check` and `Ladder.build`: exit 10 for a new error in a hash, exit 11 for a new error in an app file. A member is probed after the member before it passed.
	## Slice 023c: `path_roc` is the id and the file of the `roc` on `PATH` (`Install.compiler!`), `now` is the time of Talon (`request.now` of the command: `.last-use` has it).
	verify! : Fx, { roots : Roots, now : U64, path_roc : Try({ id : Str, path : Str }, [NoCompiler]), held : Str, members : List(Checked), replace : List(Replace), owners : List(Owner), moved : List(Owner), downloads : Ladder.Downloads, probe : Probe.Settings, no_probe : Bool, closures : List({ file : Str, walked : Closure.Walked }) } => Try({ notes : List(Str), downloads : U64, probes : U64 }, Fail)
	verify! = |fx, request| {
		started = Start.run!(fx, { roots: request.roots, path_roc: request.path_roc, held: request.held, downloads: request.downloads })?
		var $facts = known_facts!(fx, request.roots, request.closures, started.id)?
		var $count = 0
		var $done = no_done
		for member in request.members {
			ran = verify_member!(fx, request, { started, facts: $facts, count: $count }, member)?
			$facts = ran.facts
			$count = ran.probes
			$done = $done.append({ file: member.file, lines: ran.lines })
		}
		Ok({ notes: print_lines!(fx, $done), downloads: started.downloads, probes: $count })
	}

	## Command code (part C). Called by `Resolve.finish!` after the choice and before the write, only when a header changes and `--no-check` is false. The calls
	## for one member, in order (the L2 cases `ladder/ld-*` fix them):
	##
	## | Step | Call |
	## | --- | --- |
	## | 0 | Once, before the first member: `Start.run!` (slice 025). It lists `<cache>/toolchains`, finds the compiler of `held` (`Compiler.find`) and, when it is not installed, applies the consent rules and the required download (R-DL1 to R-DL5, R-SO22). Then it calls `Launch.program!` (slice 024b, R-LK4) and `Launch.child_env!` (one `canonical!` call, R-PX6). A failure is returned (exit 13, R-PH7): no more call is made. The result has `downloads` (1 after a download, else 0). |
	## | 1 | `fx.random!()`, then `Temp.hex`: the copy is `Roots.item(roots, TalonTmp(hex))` |
	## | 2 | `fx.copy_tree!({ from: <dir of the member file>, to: <copy>, skip: [".git"] })` (R-CC2). Question Q3 (what the copy holds). |
	## | 3 | The walk of the copy: `fx.list_dirs!` for each level of the tree (the first call has the copy), the `.roc` files in byte order. `fx.read_files!` of all of them but the project file (no call when there is none). `Rebase.files` with the glob `**/*.roc` (`from` is the dir of the member file, `to` is the copy) changes the path entries of the headers and the `import "<file>"` strings (R-LD4, R-H7). One `fx.write_atomic!`: the candidate header first (`Locked.edit({ path, text, ops })`, with the changes of `Rebase`), then each other changed file. |
	## | 4 | `Launch.touch!(fx, roots, { id, now })` when `installed` has `id` (R-CC9: before the compiler starts). Then `fx.probes!(plan.first)` (one round: baseline, candidate) |
	## | 5 | `Ladder.baseline`, then `Ladder.check`. A failure goes to step 8. |
	## | 6 | When the plan has a build: `Launch.touch!` as in step 4, then `fx.probes!([build])`, then `Ladder.build`. A failure goes to step 8. |
	## | 7 | The lines of the reports are collected |
	## | 8 | `fx.delete!([copy])` (R-CC2: a command deletes its own temp dir), also for a failure |
	##
	## Slice 031 (R-LD2, R-LD3): after `Start.run!` one `Facts.load!` (one `db_query` for the packages of all `closures`). For each member, steps 4 and 5 are 3 rounds: round 1 `probes!` with the baseline and the unit probes (`UnitFlow.first!`), one `db_write`, the verdict (`UnitFlow.verdict!`), round 2 the candidate check, round 3 the build. The result `probes` is the number of probes that started.
	## After all members passed, the command prints the lines of each member in the order of the members (stdout, a line end after each), and returns the text of each `note:` line without the prefix `note: ` (slice 007: the command puts them in `Report.Outcome.notes`). With 2 or more
	## members each line has the file path of its member in front: `<file>: check: passed`. A member is probed after the member before it passed. Each member has its own copy. `timeout` is 30 s (R-RC3, R-P5). The `pkgs` of the facts is `Roots.pkgs`.
	## Slice 023c: `path_roc` is the id and the file of the `roc` on `PATH` (`Install.compiler!`), `now` is the time of Talon (`request.now` of the command: `.last-use` has it).
	run! : Fx, { roots : Roots, now : U64, path_roc : Try({ id : Str, path : Str }, [NoCompiler]), held : Str, members : List(Member), owners : List(Owner), moved : List(Owner), downloads : Ladder.Downloads, probe : Probe.Settings, no_probe : Bool, closures : List({ file : Str, walked : Closure.Walked }) } => Try({ notes : List(Str), downloads : U64, probes : U64 }, Fail)
	run! = |fx, request| {
		started = Start.run!(fx, { roots: request.roots, path_roc: request.path_roc, held: request.held, downloads: request.downloads })?
		var $facts = known_facts!(fx, request.roots, request.closures, started.id)?
		var $count = 0
		var $done = no_done
		for member in request.members {
			ran = probe_member!(fx, request, { started, base: started, facts: $facts, count: $count }, member)?
			$facts = ran.facts
			$count = ran.probes
			$done = $done.append({ file: member.file, lines: ran.lines })
		}
		Ok({ notes: print_lines!(fx, $done), downloads: started.downloads, probes: $count })
	}

	## A member of `use!` (slice 026b, `tln roc use`): a `Member` and the compiler of its baseline check (R-BL1: the old pin of the member, or the compiler that Resolution 13 selects when it has no pin).
	UseMember : { file : Str, kind : [App, Package, Platform], text : Str, ops : List(Locked.Op), baseline : Str }

	## Command code (part C) of `tln roc use` (R-U3, R-BL1, R-BL2, R-CS1, R-WS13). It is `run!` where the baseline check of a member runs on its own compiler, `member.baseline`, and the candidate check and the build run on `held`, the new compiler.
	## The compilers must be installed: the command asked for the downloads before (R-U3: one prompt for the new compiler and the baselines), so `Start.run!` finds each of them and downloads nothing. The calls, in order (the L2 cases `roc/us1-use`, `roc/us2-workspace` fix them):
	##
	## | Step | Call |
	## | --- | --- |
	## | 0 | `Start.run!` for `held`. Then, for each member in order, `Start.run!` for its baseline when it is not `held` and was not started for an earlier member. |
	## | 1 to 8 | As `run!` for each member (copy, rebase, write of the candidate header, the first round, the build, the delete of the copy). The first round has the baseline check on `member.baseline` in the project dir, and the candidate check on `held` in the copy (one `probes!` call). |
	## | touch | Before a round: `Launch.touch!` for `held`, then for the baseline when it is another installed compiler (R-CC9) |
	##
	## `Ladder.baseline` runs with the baseline id as its `compiler`, `Ladder.check` and `Ladder.build` with `held`. The lines and the notes are as for `run!`. `owners` are the hashes of the header (for the blame of a new error). `moved` is `[]`.
	use! : Fx, { roots : Roots, now : U64, path_roc : Try({ id : Str, path : Str }, [NoCompiler]), held : Str, members : List(Ladder.UseMember), owners : List(Ladder.Owner), downloads : Ladder.Downloads, probe : Probe.Settings } => Try({ notes : List(Str), downloads : U64 }, Fail)
	use! = |fx, request| {
		started = Start.run!(fx, { roots: request.roots, path_roc: request.path_roc, held: request.held, downloads: request.downloads })?
		plain = { roots: request.roots, now: request.now, path_roc: request.path_roc, held: request.held, members: [], owners: request.owners, moved: [], downloads: request.downloads, probe: request.probe, no_probe: Bool.True, closures: [] }
		var $bases = [started]
		var $done = no_done
		for member in request.members {
			base = match $bases.find_first(|b| Pin.same_id(b.id, member.baseline)) {
				Ok(known) => known
				Err(_) => {
					fresh = Start.run!(fx, { roots: request.roots, path_roc: request.path_roc, held: member.baseline, downloads: request.downloads })?
					$bases = $bases.append(fresh)
					fresh
				}
			}
			own = { file: member.file, kind: member.kind, text: member.text, ops: member.ops }
			$done = $done.append({ file: member.file, lines: probe_member!(fx, plain, { started, base, facts: [], count: 0 }, own)?.lines })
		}
		Ok({ notes: print_lines!(fx, $done), downloads: started.downloads })
	}
}

# The lines of each member, one `fx.out!` call for each line. With 2 or more members each line has the file of its member. It gives the text of each `note:` line.
print_lines! : Fx, List({ file : Str, lines : List(Str) }) => List(Str)
print_lines! = |fx, done| {
	var $notes = no_lines
	for member in done {
		for line in member.lines {
			prefix = if done.len() >= 2 "${member.file}: " else ""
			fx.out!("${prefix}${line}\n")
			if line.starts_with("note: ") {
				$notes = $notes.append("${prefix}${line.drop_prefix("note: ")}")
			}
		}
	}
	$notes
}

no_done : List({ file : Str, lines : List(Str) })
no_done = []

# C6: a failed probe whose errors Talon cannot read is no fact. An empty set would blame the wrong hash (R-BL3).
unreadable : Str, U64 -> Fail
unreadable = |what, n| {
	count = if n == 1 "1 error" else "${n.to_str()} errors"
	Fail.new(Internal, "${what} gave no result: ${count} that tln cannot read. Run the command again.")
}

no_lines : List(Str)
no_lines = []

Pair : { started : Start.Started, base : Start.Started, facts : List(Db.Fact), count : U64 }

Ran : { lines : List(Str), probes : U64, facts : List(Db.Fact) }

Request : { roots : Roots, now : U64, path_roc : Try({ id : Str, path : Str }, [NoCompiler]), held : Str, members : List(Ladder.Member), owners : List(Ladder.Owner), moved : List(Ladder.Owner), downloads : Ladder.Downloads, probe : Probe.Settings, no_probe : Bool, closures : List({ file : Str, walked : Closure.Walked }) }

# Steps 1 to 8 of `run!` for one member. The copy is deleted also after a failure (R-CC2).
probe_member! : Fx, Request, Pair, Ladder.Member => Try(Ran, Fail)
probe_member! = |fx, request, pair, member| {
	copy = Roots.item(request.roots, Item.TalonTmp(Temp.hex(fx.random!())))
	result = probe_in_copy!(fx, request, pair, member, copy)
	_ = fx.delete!([copy])
	result
}

probe_in_copy! : Fx, Request, Pair, Ladder.Member, Str => Try(Ran, Fail)
probe_in_copy! = |fx, request, pair, member, copy| {
	started = pair.started
	base = pair.base
	dir = Text.dir_of(member.file)
	file = Text.last_segment(member.file)
	match fx.copy_tree!({ from: dir, to: copy, skip: [".git"] }) {
		Ok(_) => {}
		Err(_) => return Err(Fail.new(Environment, "cannot copy ${dir} to ${copy}"))
	}
	writes = rebased_files!(fx, member, { dir, file, copy })?
	match fx.write_atomic!(writes) {
		Ok(_) => {}
		Err(failed) => return Err(Fail.new(Environment, "cannot write ${failed.path}"))
	}
	compiler = request.held
	pkgs = request.roots.pkgs
	timeout = request.probe.timeout
	candidate_plan = Ladder.plan({ compiler, program: started.program, env: started.env, kind: member.kind, dir, file, copy, timeout })
	(baseline_spec, candidate_spec) = match candidate_plan.first {
		[before, after] => (before, after)
		_ => return Err(no_answer("the plan"))
	}
	# Slice 026b: the baseline check runs on its own compiler. For `run!` it is the compiler of the candidate (`base` is `started`).
	other = base.id != started.id
	first_spec = if other { ..baseline_spec, compiler: base.id, program: base.program, env: base.env } else baseline_spec
	ctx = unit_ctx({ roots: request.roots, now: request.now, held: compiler, probe: request.probe, no_probe: request.no_probe, closures: request.closures }, pair, { file: member.file, kind: member.kind, text: member.text })
	round = UnitFlow.first!(fx, ctx, { baseline: first_spec, count: pair.count })?
	baseline = Ladder.baseline({ output: round.baseline, dir, pkgs, compiler: if other base.id else compiler, timeout })?
	UnitFlow.verdict!(fx, ctx, { first: round, baseline })?
	second = UnitFlow.step!(fx, ctx, { spec: candidate_spec, count: round.count })?
	checked = Ladder.check({ output: second.output, dir: copy, pkgs, baseline, owners: request.owners, moved: request.moved, compiler, timeout })?
	match candidate_plan.build {
		Err(None) => Ok({ lines: checked.lines, probes: second.count, facts: round.facts })
		Ok(spec) => {
			third = UnitFlow.step!(fx, ctx, { spec, count: second.count })?
			built = Ladder.build({ output: third.output, dir: copy, pkgs, baseline, owners: request.owners, compiler, timeout })?
			Ok({ lines: checked.lines.concat(built.lines), probes: third.count, facts: round.facts })
		}
	}
}

# R-AL4, R-EF1: the facts of the packages of all closures for the compiler, in one query (R-CC8: a busy db is a warning and no fact).
known_facts! : Fx, Roots, List({ file : Str, walked : Closure.Walked }), Str => Try(List(Db.Fact), Fail)
known_facts! = |fx, roots, closures, nightly| Facts.load!(fx, { roots, keys: Units.keys({ nodes: Units.nodes(closures.map(|c| c.walked)), nightly }) })

# The context of ladder step 1 for one member (the closure of the member file, no closure gives no package).
unit_ctx : { roots : Roots, now : U64, held : Str, probe : Probe.Settings, no_probe : Bool, closures : List({ file : Str, walked : Closure.Walked }) }, { started : Start.Started, base : Start.Started, facts : List(Db.Fact), count : U64 }, { file : Str, kind : [App, Package, Platform], text : Str } -> UnitFlow.Ctx
unit_ctx = |request, pair, member| {
	walked = match request.closures.find_first(|c| c.file == member.file) {
		Ok(c) => c.walked
		Err(_) => { rows: [], links: [] }
	}
	{ roots: request.roots, now: request.now, started: pair.started, base: pair.base, held: request.held, probe: request.probe, no_probe: request.no_probe, member, walked, nodes: Units.nodes([walked]), facts: pair.facts }
}

VerifyRequest : { roots : Roots, now : U64, path_roc : Try({ id : Str, path : Str }, [NoCompiler]), held : Str, members : List(Ladder.Checked), replace : List(Ladder.Replace), owners : List(Ladder.Owner), moved : List(Ladder.Owner), downloads : Ladder.Downloads, probe : Probe.Settings, no_probe : Bool, closures : List({ file : Str, walked : Closure.Walked }) }

# The steps 1 to 5 of `verify!` for one member. The temp dir is deleted also after a failure (R-CC2).
verify_member! : Fx, VerifyRequest, { started : Start.Started, facts : List(Db.Fact), count : U64 }, Ladder.Checked => Try(Ran, Fail)
verify_member! = |fx, request, state, member| {
	tmp = Roots.item(request.roots, Item.TalonTmp(Temp.hex(fx.random!())))
	result = probe_in_place!(fx, request, state, member, tmp)
	_ = fx.delete!([tmp])
	result
}

probe_in_place! : Fx, VerifyRequest, { started : Start.Started, facts : List(Db.Fact), count : U64 }, Ladder.Checked, Str => Try(Ran, Fail)
probe_in_place! = |fx, request, state, member, tmp| {
	started = state.started
	match fx.make_dirs!([tmp]) {
		Ok(_) => {}
		Err(_) => return Err(Fail.new(Environment, "cannot make ${tmp}"))
	}
	dir = Text.dir_of(member.file)
	compiler = request.held
	pkgs = request.roots.pkgs
	timeout = request.probe.timeout
	plan = Ladder.plan_replace({ compiler, program: started.program, env: started.env, kind: member.kind, dir, file: Text.last_segment(member.file), tmp, replace: request.replace, timeout })
	(baseline_spec, candidate_spec) = match plan.first {
		[before, after] => (before, after)
		_ => return Err(no_answer("the plan"))
	}
	ctx = unit_ctx({ roots: request.roots, now: request.now, held: compiler, probe: request.probe, no_probe: request.no_probe, closures: request.closures }, { started, base: started, facts: state.facts, count: state.count }, { file: member.file, kind: member.kind, text: member.text })
	round = UnitFlow.first!(fx, ctx, { baseline: baseline_spec, count: state.count })?
	baseline = Ladder.baseline({ output: round.baseline, dir, pkgs, compiler, timeout })?
	UnitFlow.verdict!(fx, ctx, { first: round, baseline })?
	second = UnitFlow.step!(fx, ctx, { spec: candidate_spec, count: round.count })?
	checked = Ladder.check({ output: second.output, dir, pkgs, baseline, owners: request.owners, moved: request.moved, compiler, timeout })?
	match plan.build {
		Err(None) => Ok({ lines: checked.lines, probes: second.count, facts: round.facts })
		Ok(spec) => {
			third = UnitFlow.step!(fx, ctx, { spec, count: second.count })?
			built = Ladder.build({ output: third.output, dir, pkgs, baseline, owners: request.owners, compiler, timeout })?
			Ok({ lines: checked.lines.concat(built.lines), probes: third.count, facts: round.facts })
		}
	}
}

no_answer : Str -> Fail
no_answer = |what| Fail.new(Internal, "${what} gave no result for each probe")

# R-LD4, R-H7: the files to write into the copy. The candidate header comes first (the text of `Locked.edit`, in memory), then each other `.roc` file that
# `Rebase.files` changes, in byte order. The project file is not read from the copy.
rebased_files! : Fx, Ladder.Member, { dir : Str, file : Str, copy : Str } => Try(List({ path : Str, content : Str }), Fail)
rebased_files! = |fx, member, place| {
	edited = Locked.edit({ path: member.file, text: member.text, ops: member.ops })?
	others = roc_files_of!(fx, place.copy)?.keep_if(|path| path != place.file)
	texts = if others.is_empty() [] else fx.read_files!(others.map(|path| Text.join(place.copy, path)))
	files = others.map2(texts, |path, read| (path, read)).fold_try(
		[],
		|acc, (path, read)| match read {
			Ok(text) => Ok(acc.append({ path, text }))
			Err(_) => Err(Fail.new(Environment, "cannot read ${Text.join(place.copy, path)}"))
		},
	)?
	changed = Rebase.files({ files: files.append({ path: place.file, text: edited }), glob: roc_glob, from: place.dir, to: place.copy })
	header = changed.find_first(|f| f.path == place.file).map_ok(|f| f.text) ?? edited
	rest = changed.keep_if(|f| f.path != place.file)
	Ok([{ path: Text.join(place.copy, place.file), content: header }].concat(rest.map(|f| { path: Text.join(place.copy, f.path), content: f.text })))
}

# The glob of the files that the ladder rebases in the copy (Q1 of slice 006b: all `.roc` files).
roc_glob : Str
roc_glob = "**/*.roc"

# The `.roc` files of the copy, as paths relative to its root, in byte order. One `list_dirs!` call for each level of the tree (D9 of slice 006b).
roc_files_of! : Fx, Str => Try(List(Str), Fail)
roc_files_of! = |fx, copy| {
	var $level = [""]
	var $found = no_lines
	while !$level.is_empty() {
		results = fx.list_dirs!($level.map(|rel| if rel == "" copy else Text.join(copy, rel)))
		var $next = no_lines
		for (rel, result) in $level.map2(results, |rel, result| (rel, result)) {
			match result {
				Ok(entries) => for entry in entries {
					path = if rel == "" entry.name else "${rel}/${entry.name}"
					if entry.is_dir {
						$next = $next.append(path)
					} else if entry.name.ends_with(".roc") {
						$found = $found.append(path)
					}
				}
				Err(_) => return Err(Fail.new(Environment, "cannot list ${if rel == "" copy else Text.join(copy, rel)}"))
			}
		}
		$level = Text.sorted($next)
	}
	Ok(Text.sorted($found))
}

# ` with <name> <version>, ...`, or nothing when no entry moved (G1 of slice 008: `tln remove` moves none).
moved_text : List(Ladder.Owner) -> Str
moved_text = |owners| if owners.is_empty() "" else " with ${Str.join_with(owners.map(|o| "${o.name} ${o.version}"), ", ")}"

# `the platform <name> <version>`, or `the platform` when no owner is the platform.
platform_text : List(Ladder.Owner) -> Str
platform_text = |owners| match owners.find_first(|o| o.is_platform) {
	Ok(o) => "the platform ${o.name} ${o.version}"
	Err(_) => "the platform"
}

# Ladder step 2: the new errors of the candidate against the baseline (R-BL5). An error with no file goes to the app (D9).
judge_check : List(Probe.Err), List(Ladder.Owner), List(Probe.Err) -> Try(Ladder.Report, Fail)
judge_check = |baseline, owners, errors| {
	compared = Probe.compare({ baseline, candidate: errors })
	in_app = compared.new.keep_if(|e| !is_package(e))
	in_hashes = compared.new.keep_if(is_package)
	if !in_app.is_empty() {
		Err(app_error(in_app))
	} else if !in_hashes.is_empty() {
		Err(Fail.new(NoTuple, "no tuple works: the whole-app check found new errors in ${blames(in_hashes, owners)}"))
	} else {
		Ok({ lines: notes("check: passed", compared, owners) })
	}
}

# Ladder step 3. The order of the rules: an app file, an error with no file (the platform), a hash (D8).
judge_build : List(Probe.Err), List(Ladder.Owner), List(Probe.Err) -> Try(Ladder.Report, Fail)
judge_build = |baseline, owners, errors| {
	new = Probe.compare({ baseline, candidate: errors }).new
	in_app = new.keep_if(|e| e.file != NoFile and !is_package(e))
	no_file = new.keep_if(|e| e.file == NoFile)
	in_hashes = new.keep_if(is_package)
	if !in_app.is_empty() {
		Err(app_error(in_app))
	} else if !no_file.is_empty() {
		Err(Fail.new(NoTuple, "no tuple works: the build for the host target failed on ${platform_text(owners)}: ${Str.join_with(no_file.map(|e| e.title), "; ")}"))
	} else if !in_hashes.is_empty() {
		Err(Fail.new(NoTuple, "no tuple works: the build found new errors in ${blames(in_hashes, owners)}"))
	} else {
		Ok({ lines: ["build: passed"] })
	}
}

is_package : Probe.Err -> Bool
is_package = |e| match e.file {
	Package(_) => Bool.True
	_ => Bool.False
}

# R-EC11: a new error in an app file.
app_error : List(Probe.Err) -> Fail
app_error = |errors| {
	items = errors.map(
		|e| match e.file {
			App(path) => "${path} (${e.title})"
			_ => "no file (${e.title})"
		},
	)
	Fail.new(AppError, "a new error in an app file: ${Str.join_with(items, "; ")}. The app is not a free variable: fix it, or pass --no-check.")
}

hash_of : Probe.Err -> Str
hash_of = |e| match e.file {
	Package({ hash, .. }) => hash
	_ => ""
}

# `<name> <version>` of the owner of a hash, or the hash.
owner_text : List(Ladder.Owner), Str -> Str
owner_text = |owners, hash| match owners.find_first(|o| o.hash == hash) {
	Ok(o) => "${o.name} ${o.version}"
	Err(_) => hash
}

# R-PH13: `<name> <version> (<module>: <title>, ...)` for each hash, in the order of its first error.
blames : List(Probe.Err), List(Ladder.Owner) -> Str
blames = |errors, owners| {
	hashes = errors.map(hash_of).fold([], |found, hash| if found.contains(hash) found else found.append(hash))
	one = |hash| {
		items = errors.keep_if(|e| hash_of(e) == hash).map(|e| "${module_of(e)}: ${e.title}")
		"${owner_text(owners, hash)} (${Str.join_with(items, ", ")})"
	}
	Str.join_with(hashes.map(one), "; ")
}

module_of : Probe.Err -> Str
module_of = |e| match e.file {
	Package({ path, .. }) => path
	_ => ""
}

# R-BL5: the passed line, then a note for each unchanged error and for each removed error.
notes : Str, Probe.Compared, List(Ladder.Owner) -> List(Str)
notes = |first, compared, owners| {
	line = |kind, e| "note: ${kind} error: ${where_text(e, owners)}: ${e.title}"
	[first].concat(compared.unchanged.map(|e| line("unchanged", e))).concat(compared.removed.map(|e| line("removed", e)))
}

where_text : Probe.Err, List(Ladder.Owner) -> Str
where_text = |e, owners| match e.file {
	App(path) => path
	NoFile => "no file"
	Package({ hash, path }) => "${owner_text(owners, hash)} ${path}"
}
