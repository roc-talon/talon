import BuildFlow
import BuildSkip
import Closure
import Compiler
import Db
import Facts
import Fail
import Fx
import Item
import LadderJudge
import LadderPlan
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
## of the packages with no fact (step 1, R-LD2, R-LD3: `UnitFlow`, `Units`), round 2 is the whole-app check of the candidate header in a temp copy, round 3 is the build (R-LD4, R-LD5). Round 3 is skipped for a recorded pass (R-BS1, R-BS2: `BuildFlow`, slice 032).
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

	## The facts of the consent rules for a compiler that is not installed (slice 025, `Start.Downloads`).
	Downloads : Start.Downloads

	## The judgment and the plans are in `LadderJudge` and `LadderPlan` (slice 031b). These names stay here for the unit tests.
	baseline = LadderJudge.baseline
	check = LadderJudge.check
	build = LadderJudge.build
	plan = LadderPlan.plan
	plan_replace = LadderPlan.plan_replace

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
	verify! : Fx, { roots : Roots, now : U64, path_roc : Try({ id : Str, path : Str }, [NoCompiler]), held : Str, members : List(Checked), replace : List(LadderPlan.Replace), owners : List(LadderJudge.Owner), moved : List(LadderJudge.Owner), downloads : Ladder.Downloads, probe : Probe.Settings, no_probe : Bool, closures : List({ file : Str, walked : Closure.Walked }) } => Try({ notes : List(Str), downloads : U64, probes : U64, skipped : U64 }, Fail)
	verify! = |fx, request| {
		started = Start.run!(fx, { roots: request.roots, path_roc: request.path_roc, held: request.held, downloads: request.downloads })?
		var $facts = known_facts!(fx, request.roots, request.closures, started.id)?
		var $count = 0
		var $skipped = 0
		var $done = no_done
		for member in request.members {
			ran = verify_member!(fx, request, { started, facts: $facts, count: $count }, member)?
			$facts = ran.facts
			$count = ran.probes
			$skipped = $skipped + ran.skipped
			$done = $done.append({ file: member.file, lines: ran.lines })
		}
		Ok({ notes: print_lines!(fx, $done), downloads: started.downloads, probes: $count, skipped: $skipped })
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
	run! : Fx, { roots : Roots, now : U64, path_roc : Try({ id : Str, path : Str }, [NoCompiler]), held : Str, members : List(Member), owners : List(LadderJudge.Owner), moved : List(LadderJudge.Owner), downloads : Ladder.Downloads, probe : Probe.Settings, no_probe : Bool, closures : List({ file : Str, walked : Closure.Walked }) } => Try({ notes : List(Str), downloads : U64, probes : U64, skipped : U64 }, Fail)
	run! = |fx, request| {
		started = Start.run!(fx, { roots: request.roots, path_roc: request.path_roc, held: request.held, downloads: request.downloads })?
		var $facts = known_facts!(fx, request.roots, request.closures, started.id)?
		var $count = 0
		var $skipped = 0
		var $done = no_done
		for member in request.members {
			ran = probe_member!(fx, request, { started, base: started, facts: $facts, count: $count }, member)?
			$facts = ran.facts
			$count = ran.probes
			$skipped = $skipped + ran.skipped
			$done = $done.append({ file: member.file, lines: ran.lines })
		}
		Ok({ notes: print_lines!(fx, $done), downloads: started.downloads, probes: $count, skipped: $skipped })
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
	use! : Fx, { roots : Roots, now : U64, path_roc : Try({ id : Str, path : Str }, [NoCompiler]), held : Str, members : List(Ladder.UseMember), owners : List(LadderJudge.Owner), downloads : Ladder.Downloads, probe : Probe.Settings } => Try({ notes : List(Str), downloads : U64 }, Fail)
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

no_lines : List(Str)
no_lines = []

Pair : { started : Start.Started, base : Start.Started, facts : List(Db.Fact), count : U64 }

Ran : { lines : List(Str), probes : U64, facts : List(Db.Fact), skipped : U64 }

Request : { roots : Roots, now : U64, path_roc : Try({ id : Str, path : Str }, [NoCompiler]), held : Str, members : List(Ladder.Member), owners : List(LadderJudge.Owner), moved : List(LadderJudge.Owner), downloads : Ladder.Downloads, probe : Probe.Settings, no_probe : Bool, closures : List({ file : Str, walked : Closure.Walked }) }

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
	candidate_plan = LadderPlan.plan({ compiler, program: started.program, env: started.env, kind: member.kind, dir, file, copy, timeout })
	(baseline_spec, candidate_spec) = match candidate_plan.first {
		[before, after] => (before, after)
		_ => return Err(no_answer("the plan"))
	}
	# Slice 026b: the baseline check runs on its own compiler. For `run!` it is the compiler of the candidate (`base` is `started`).
	other = base.id != started.id
	first_spec = if other { ..baseline_spec, compiler: base.id, program: base.program, env: base.env } else baseline_spec
	ctx = unit_ctx({ roots: request.roots, now: request.now, held: compiler, probe: request.probe, no_probe: request.no_probe, closures: request.closures }, pair, { file: member.file, kind: member.kind, text: member.text })
	round = UnitFlow.first!(fx, ctx, { baseline: first_spec, count: pair.count })?
	baseline = LadderJudge.baseline({ output: round.baseline, dir, pkgs, compiler: if other base.id else compiler, timeout })?
	verdict = UnitFlow.verdict!(fx, ctx, { first: round, baseline })?
	second = UnitFlow.step!(fx, ctx, { spec: candidate_spec, count: round.count })?
	checked = LadderJudge.check({ output: second.output, dir: copy, pkgs, baseline, owners: request.owners, moved: request.moved, compiler, timeout })?
	match candidate_plan.build {
		Err(None) => Ok({ lines: checked.lines, probes: second.count, facts: round.facts, skipped: 0 })
		Ok(spec) => {
			third = build_round!(fx, ctx, { spec, count: second.count, used: verdict.used, dir: copy, baseline, owners: request.owners })?
			Ok({ lines: checked.lines.concat(third.lines), probes: third.probes, facts: round.facts, skipped: third.skipped })
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

VerifyRequest : { roots : Roots, now : U64, path_roc : Try({ id : Str, path : Str }, [NoCompiler]), held : Str, members : List(Ladder.Checked), replace : List(LadderPlan.Replace), owners : List(LadderJudge.Owner), moved : List(LadderJudge.Owner), downloads : Ladder.Downloads, probe : Probe.Settings, no_probe : Bool, closures : List({ file : Str, walked : Closure.Walked }) }

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
	plan = LadderPlan.plan_replace({ compiler, program: started.program, env: started.env, kind: member.kind, dir, file: Text.last_segment(member.file), tmp, replace: request.replace, timeout })
	(baseline_spec, candidate_spec) = match plan.first {
		[before, after] => (before, after)
		_ => return Err(no_answer("the plan"))
	}
	ctx = unit_ctx({ roots: request.roots, now: request.now, held: compiler, probe: request.probe, no_probe: request.no_probe, closures: request.closures }, { started, base: started, facts: state.facts, count: state.count }, { file: member.file, kind: member.kind, text: member.text })
	round = UnitFlow.first!(fx, ctx, { baseline: baseline_spec, count: state.count })?
	baseline = LadderJudge.baseline({ output: round.baseline, dir, pkgs, compiler, timeout })?
	verdict = UnitFlow.verdict!(fx, ctx, { first: round, baseline })?
	second = UnitFlow.step!(fx, ctx, { spec: candidate_spec, count: round.count })?
	checked = LadderJudge.check({ output: second.output, dir, pkgs, baseline, owners: request.owners, moved: request.moved, compiler, timeout })?
	match plan.build {
		Err(None) => Ok({ lines: checked.lines, probes: second.count, facts: round.facts, skipped: 0 })
		Ok(spec) => {
			third = build_round!(fx, ctx, { spec, count: second.count, used: verdict.used, dir, baseline, owners: request.owners })?
			Ok({ lines: checked.lines.concat(third.lines), probes: third.probes, facts: round.facts, skipped: third.skipped })
		}
	}
}

# Round 3 (R-LD5, R-BS1, R-BS2): the build, or its skip. `BuildFlow.before!` decides. A build that ran is recorded before `LadderJudge.build` judges it (R-P4: a failed build is a fact too).
build_round! : Fx, UnitFlow.Ctx, { spec : Probe.Spec, count : U64, used : Try(List(BuildSkip.Used), [NotScanned]), dir : Str, baseline : List(Probe.Err), owners : List(LadderJudge.Owner) } => Try({ lines : List(Str), probes : U64, skipped : U64 }, Fail)
build_round! = |fx, ctx, run| {
	plan = BuildFlow.before!(fx, ctx, { used: run.used })?
	if plan.skip {
		Ok({ lines: [BuildSkip.skipped_line], probes: run.count, skipped: 1 })
	} else {
		pkgs = ctx.roots.pkgs
		third = UnitFlow.step!(fx, ctx, { spec: run.spec, count: run.count })?
		BuildFlow.after!(fx, ctx, { id: plan.id, output: third.output, dir: run.dir, pkgs })?
		built = LadderJudge.build({ output: third.output, dir: run.dir, pkgs, baseline: run.baseline, owners: run.owners, compiler: ctx.held, timeout: ctx.probe.timeout })?
		Ok({ lines: built.lines, probes: third.count, skipped: 0 })
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
