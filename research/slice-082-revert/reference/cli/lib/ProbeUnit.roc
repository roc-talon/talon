import Db
import Facts
import Fail
import Fx
import Item
import Probe
import Roots
import Start
import Temp
import Text
import UnitFlow
import Units

## The probes of `tln probe` with no `--range` (slice 037, R-PB2, R-PB7, R-P4, R-LD2, R-LD3, R-LD7). Command code over `Fx`. The compiler is the one that `Start.run!` started. The facts and the budget are not the business of `ProbeCmd`.
ProbeUnit :: [].{

	## What a probe needs: the roots, the time, the started compiler and the settings (`timeout` and `slots`).
	Run : { roots : Roots, now : U64, started : Start.Started, probe : Probe.Settings }

	## The end of a probe for the output (`ProbeCmd.Done`).
	Done : { class : Probe.Class, errors : List(Probe.Err) }

	## R-PB2: one unit check of a package (`roc check main.roc` in `<pkgs>/<hash>/`), the fact is written with `existing=replace` (R-P4: a known fact is probed again). A probe with no fact (R-P3) is the failure `Units.results` gives (kind `Internal`, exit 1).
	node! : Fx, ProbeUnit.Run, Units.Node => Try(Db.Fact, Fail)
	node! = |fx, run, node| {
		specs = Units.specs({ nodes: [node], compiler: run.started.id, program: run.started.program, env: run.started.env, pkgs: run.roots.pkgs, timeout: run.probe.timeout })
		outputs = UnitFlow.probes!(fx, { roots: run.roots, now: run.now, pool: run.probe.slots, started: run.started, base: run.started, specs })
		results = Units.results({ nodes: [node], outputs, nightly: run.started.id, compiler: run.started.id, pkgs: run.roots.pkgs })
		_ = Facts.save!(fx, { roots: run.roots, rows: results.facts, existing: Replace })?
		match results.failure {
			Ok(fail) => Err(fail)
			Err(None) => results.facts.first().map_err(|_| Fail.new(Internal, "the probes gave no result for each probe"))
		}
	}

	## R-PB2, R-PB7, R-LD7: ladder steps 2 and 3 on the project file with no baseline: the check, then the build of an app (a package or a platform has no build, and a check that did not pass has none). The result is in memory, no fact is written.
	## The build writes its output in `<cache>/talon/tmp/<hex>/tln-probe.out`, and the dir is deleted after (R-CC2). `probes` is the number of probes that started.
	project! : Fx, ProbeUnit.Run, { file : Str, kind : [App, Package, Platform] } => Try({ check : ProbeUnit.Done, build : Try(ProbeUnit.Done, [NotRun]), probes : U64 }, Fail)
	project! = |fx, run, target| {
		dir = Text.dir_of(target.file)
		name = Text.last_segment(target.file)
		check = one!(fx, run, { dir, name, command: Check, what: "check" })?
		passed = match check.class {
			Pass => Bool.True
			_ => Bool.False
		}
		if passed and target.kind == App {
			tmp = Roots.item(run.roots, Item.TalonTmp(Temp.hex(fx.random!())))
			built = match fx.make_dirs!([tmp]) {
				Ok(_) => one!(fx, run, { dir, name, command: Build({ output: Text.join(tmp, "tln-probe.out") }), what: "build" })
				Err(_) => Err(Fail.new(Environment, "cannot make the temp dir ${tmp}"))
			}
			_ = fx.delete!([tmp])
			Ok({ check, build: Ok(built?), probes: 2 })
		} else {
			Ok({ check, build: Err(NotRun), probes: 1 })
		}
	}
}

# One probe in the project dir: the class and the errors. No fact is a failure of the command (R-P3).
one! : Fx, ProbeUnit.Run, { dir : Str, name : Str, command : Probe.Command, what : Str } => Try(ProbeUnit.Done, Fail)
one! = |fx, run, step| {
	spec = {
		compiler: run.started.id,
		program: run.started.program,
		args: Probe.args({ command: step.command, file: step.name }),
		dir: step.dir,
		env: run.started.env,
		timeout: run.probe.timeout,
		weight: Probe.weight(step.command),
	}
	outputs = UnitFlow.probes!(fx, { roots: run.roots, now: run.now, pool: run.probe.slots, started: run.started, base: run.started, specs: [spec] })
	match outputs {
		[output] => match Probe.classify(output) {
			NoFact(text) => Err(Fail.new(Internal, "the ${step.what} of ${Text.join(step.dir, step.name)} on ${run.started.id} gave no result: ${text}. Run the command again."))
			class => Ok({ class, errors: Probe.errors({ text: output.stderr, dir: step.dir, pkgs: run.roots.pkgs }) })
		}
		_ => Err(Fail.new(Internal, "the probes gave no result for each probe"))
	}
}
