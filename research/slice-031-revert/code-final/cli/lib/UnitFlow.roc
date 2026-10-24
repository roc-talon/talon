import Closure
import Db
import Facts
import Fail
import Fx
import Launch
import Probe
import Roots
import Scan
import Start
import Text
import Units
import Uses
import header.Header

## Command code (part C) of ladder step 1, the unit probes (slice 031, R-LD2, R-LD3, R-UM1, R-AL4, R-PP2 to R-PP4, R-P5). `Ladder.run!` and `Ladder.verify!` call it for each member. The pure decisions are in `Units` and `Uses`.
## The calls of the three rounds of one member, in order (the L2 cases `probe/un1-units` to `un3-verify-units` fix them):
##
## | Function | Calls | Rule |
## | --- | --- | --- |
## | `first!` | `Units.missing`, `Units.budget`, `.last-use`, round 1: `probes!` with the baseline and the unit probes. Then `Units.results` and one `db_write` (`Facts.save!`, Replace) | R-AL4, R-PP2, R-PP4, R-P5 |
## | `verdict!` | The first output with no fact, `Units.suspects`, the scan (one `read_files!` for each level), `Units.judge`, the budget cut | R-P3, R-UM1, R-LD2 |
## | `step!` | The budget check, `.last-use`, round 2 or 3: `probes!` with one probe | R-P5, R-LD4, R-LD5 |
UnitFlow :: [].{

	## What a member needs for ladder step 1. `started` runs the candidate. `base` runs the baseline (the same as `started`, except for `roc use`). `held` is the compiler id for the messages. `facts` are the facts that the command knows (the query, and the rounds before).
	## `nodes` are the packages of the closure of the member (`Units.nodes`). `walked` is that closure (the scan reads its links). `member` is the project file: for the scan, its kind, its file and its text.
	Ctx : {
		roots : Roots,
		now : U64,
		started : Start.Started,
		base : Start.Started,
		held : Str,
		probe : Probe.Settings,
		no_probe : Bool,
		member : { file : Str, kind : [App, Package, Platform], text : Str },
		walked : Closure.Walked,
		nodes : List(Units.Node),
		facts : List(Db.Fact),
	}

	## The result of round 1. `baseline` is the output of the baseline check. `count` is the number of probes that this command started, with this round. `facts` are the facts after this round. `failure` is the first unit probe with no fact.
	## `left` is the number of unit probes that the budget cut.
	First : { baseline : Probe.Output, count : U64, facts : List(Db.Fact), failure : Try(Fail, [None]), left : U64 }

	## `.last-use` of the compilers (R-CC9: before a round starts), then the probes of the round. The compiler of the candidate is touched first, then the baseline compiler when it is another one (slice 026b).
	probes! : Fx, { roots : Roots, now : U64, pool : U64, started : Start.Started, base : Start.Started, specs : List(Probe.Spec) } => List(Probe.Output)
	probes! = |fx, run| {
		if run.started.installed.contains(run.started.id) {
			Launch.touch!(fx, run.roots, { id: run.started.id, now: run.now })
		}
		if run.base.id != run.started.id and run.base.installed.contains(run.base.id) {
			Launch.touch!(fx, run.roots, { id: run.base.id, now: run.now })
		}
		fx.probes!({ pool: run.pool, specs: run.specs })
	}

	## Round 1 (R-PP2): the baseline check and the unit probes of the packages with no fact (R-AL4), in one `probes!` call (order: the baseline, then the nodes). `--no-probe` runs no unit probe (R-LF2). The budget (R-P5, R-PP4) cuts the unit
	## probes to what is left after the baseline. When no baseline fits, `Units.spent` is the failure and no probe starts. The facts of the round are written before the verdict (R-PP4, D4). `baseline` is the spec of the baseline check, `count` is the number of probes that started before.
	first! : Fx, UnitFlow.Ctx, { baseline : Probe.Spec, count : U64 } => Try(UnitFlow.First, Fail)
	first! = |fx, ctx, run| {
		pkgs = ctx.roots.pkgs
		wanted = if ctx.no_probe [] else Units.missing({ nodes: ctx.nodes, facts: ctx.facts, nightly: ctx.started.id })
		budget = match Units.budget({ max: ctx.probe.max, started: run.count, fixed: 1, wanted: wanted.len() }) {
			Ok(done) => done
			Err(Spent) => return Err(Units.spent({ max: ctx.probe.max, left: 0 }))
		}
		nodes = wanted.take_first(budget.run)
		unit_specs = Units.specs({ nodes, compiler: ctx.started.id, program: ctx.started.program, env: ctx.started.env, pkgs, timeout: ctx.probe.timeout })
		outputs = UnitFlow.probes!(fx, { roots: ctx.roots, now: ctx.now, pool: ctx.probe.slots, started: ctx.started, base: ctx.base, specs: [run.baseline].concat(unit_specs) })
		if outputs.len() != 1 + nodes.len() return Err(Fail.new(Internal, "the probes gave no result for each probe"))
		results = Units.results({ nodes, outputs: outputs.drop_first(1), nightly: ctx.started.id, compiler: ctx.held, pkgs })
		_ = Facts.save!(fx, { roots: ctx.roots, rows: results.facts, existing: Replace })?
		Ok({
			baseline: outputs.first() ?? { ended: NotStarted("not run"), stdout: "", stderr: "" },
			count: run.count + 1 + nodes.len(),
			facts: ctx.facts.concat(results.facts),
			failure: results.failure,
			left: wanted.len() - nodes.len(),
		})
	}

	## The verdict of round 1 (R-LD2, R-LD3, R-UM1, R-P5), after `Ladder.baseline` passed. In order: a unit probe with no fact is a failure (R-P3). The scan of the used modules runs only when `Units.suspects` finds a node (D6). `Units.judge` blames the tuple (exit 10).
	## Then a cut of the budget is exit 12 (the facts are saved, so the next run goes on). `baseline` is the error set of the baseline check.
	verdict! : Fx, UnitFlow.Ctx, { first : UnitFlow.First, baseline : List(Probe.Err) } => Try({}, Fail)
	verdict! = |fx, ctx, run| {
		match run.first.failure {
			Ok(fail) => return Err(fail)
			Err(None) => {}
		}
		suspects = Units.suspects({ nodes: ctx.nodes, facts: run.first.facts, nightly: ctx.started.id, baseline: run.baseline })
		used = if suspects.is_empty() [] else UnitFlow.scan!(fx, ctx)
		Units.judge({ nodes: ctx.nodes, facts: run.first.facts, nightly: ctx.started.id, compiler: ctx.held, baseline: run.baseline, used })?
		if run.first.left > 0 {
			Err(Units.spent({ max: ctx.probe.max, left: run.first.left }))
		} else {
			Ok({})
		}
	}

	## Round 2 and round 3 (R-LD4, R-LD5): one probe. It needs a probe left in `probe.max` (R-P5: exit 12). `count` is the number of probes that started before. The result has the output and the new count.
	step! : Fx, UnitFlow.Ctx, { spec : Probe.Spec, count : U64 } => Try({ output : Probe.Output, count : U64 }, Fail)
	step! = |fx, ctx, run| {
		match Units.budget({ max: ctx.probe.max, started: run.count, fixed: 1, wanted: 0 }) {
			Ok(_) => {}
			Err(Spent) => return Err(Units.spent({ max: ctx.probe.max, left: 0 }))
		}
		match UnitFlow.probes!(fx, { roots: ctx.roots, now: ctx.now, pool: ctx.probe.slots, started: ctx.started, base: ctx.base, specs: [run.spec] }) {
			[output] => Ok({ output, count: run.count + 1 })
			_ => Err(Fail.new(Internal, "the probes gave no result for each probe"))
		}
	}

	## The files that `paths` name and that can be read, with their text, in the order of the paths. One `read_files!` call, none when there is no path. A file that cannot be read is left out (question Q7 of slice 008).
	texts! : Fx, List(Str) => List(Scan.Source)
	texts! = |fx, paths| if paths.is_empty() {
		[]
	} else {
		paths.map2(fx.read_files!(paths), |path, result| (path, result)).keep_oks(|(path, result)| result.map_ok(|text| { path, text }))
	}

	## The scan of the used modules (R-UM1, R-LD7): the modules of packages that the app imports, level by level (one `texts!` call for each level). An app starts at its project file. A package or a platform starts at the modules that its header
	## exposes (`Scan.roots`). The result has no repeat, in the order of the first use.
	scan! : Fx, UnitFlow.Ctx => List({ hash : Str, path : Str })
	scan! = |fx, ctx| {
		file = ctx.member.file
		project_dir = Text.dir_of(file)
		edges = Uses.edges(ctx.walked)
		is_app = ctx.member.kind == App
		exposed = match Header.parse(ctx.member.text) {
			Ok(header) => header.exposed()
			Err(_) => []
		}
		roots = Scan.roots({ kind: ctx.member.kind, file, exposed })
		var $sources = if is_app [{ owner: App, path: file, text: ctx.member.text }] else []
		var $todo = if is_app [] else roots.keep_if(|path| path != file).map(|path| { owner: App, path })
		var $seen = [file]
		var $used = []
		while !$sources.is_empty() or !$todo.is_empty() {
			todo = $todo
			read = UnitFlow.texts!(fx, todo.map(|t| t.path))
			fresh = read.keep_oks(|source| todo.find_first(|t| t.path == source.path).map_ok(|t| { owner: t.owner, path: source.path, text: source.text }))
			seen = $seen.concat(todo.map(|t| t.path))
			level = Uses.level({ project_dir, pkgs: ctx.roots.pkgs, edges, sources: $sources.concat(fresh), seen })
			$used = level.used.fold($used, |found, row| if found.contains(row) found else found.append(row))
			$seen = seen
			$sources = []
			$todo = level.next
		}
		$used
	}
}
