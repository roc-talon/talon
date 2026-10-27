import Facts
import Fail
import Fx
import Item
import Launch
import Probe
import Roots
import ToolCompiler
import ToolInstall

## Option 2 of the prompt R-NI8: try the installed compiler releases (slice 047, CLI 6.4: R-T17 to R-T21, R-PP2, R-PP3). Command code, direct style over `Fx`. `ToolCompiler` decides, this module orders the calls. The calls, in order
## (the L2 cases `tool/ti3-compiler` and `ti4-nothing` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | No id: `Failed([])`, no call. Else one `Launch.toolchains!` (one `list_dirs!`). For each id in order: `Launch.program!`, then `Launch.touch!` (the id is in `ids`, so it is installed). Then one `Launch.child_env!`. | R-PX6, R-CC9 |
## | 2 | One `probes!` with the pool 12 (the default of `probe.slots`) and one `ToolCompiler.check_spec` for each id, in the order of `ids`: the checks run in one round, at the same time. The result is read in the order of the list (R-PP3). | R-T18, R-PP2, R-PP3 |
## | 3 | `Probe.classify` and `Probe.errors` of each result. One `Facts.save!` with `ToolCompiler.check_row` of each result that has a row (`Replace`): one `db_write!` for the round. | R-T21, R-PP4 |
## | 4 | For each id in order whose check passed, until a build passes: the build of the caller (`build`, the attempt of `ToolFlow`: its header line, `roc build`, no `--target`). One `Facts.save!` with `ToolCompiler.build_row` (no row with no platform hash). | R-T19, R-T21 |
## | 5 | A build that does not pass: `ToolCompiler.tried_of` with the stage `Build`. A check that does not pass: the same with the stage `Check`, in the order of the ids. The result is `Passed` with the first build that passed, else `Failed` with all the failed releases. | R-T19, R-T20 |
##
## `first` of `build` is true for the first build of the command (the caller prints the platform line only then, R-SE8). Each attempt has its own temp dir (`random!`): a failed attempt deletes it, the passed one is kept for the install (`ToolFlow`).
ToolTry :: [].{

	## What option 2 gave. `Passed`: the release `id` built the app, `layout` is the attempt (the output is in `layout.output`). `Failed`: no release built it (an empty list for no release).
	Result : [Passed({ id : Str, layout : ToolInstall.Layout }), Failed(List(ToolCompiler.Tried))]

	## Steps 1 to 5. `ids` are the `ToolCompiler.candidates` (in the order of R-T17). `Err(fail)` is the failure of a call (`Launch.program!`, `Facts.save!` with `TooNew`: exit 19, or a failed build call of the caller).
	installed! : Fx, ToolCompiler.Run, { ids : List(Str), build : { id : Str, first : Bool } => Try(ToolCompiler.Attempt, Fail) } => Try(ToolTry.Result, Fail)
	installed! = |fx, run, tries| if tries.ids.is_empty() {
		Ok(Failed([]))
	} else {
		checks = checked!(fx, run, tries.ids)?
		var $first = Bool.True
		var $tried = []
		var $found = Nobody
		for one in checks {
			if one.passed {
				attempt = (tries.build)({ id: one.id, first: $first })?
				$first = Bool.False
				save_build!(fx, run, { id: one.id, attempt })?
				match attempt.class {
					Pass => {
						$found = Somebody({ id: one.id, layout: attempt.layout })
						break
					}
					class => {
						$tried = $tried.append(ToolCompiler.tried_of({ id: one.id, stage: Build, class, errors: attempt.errors }))
					}
				}
			} else {
				$tried = $tried.append(one.tried)
			}
		}
		match $found {
			Somebody(done) => Ok(Passed(done))
			Nobody => Ok(Failed($tried))
		}
	}
}

# Steps 1 to 3: the programs, the one round of checks, the rows of the checks. A result has its id, `passed` (the check passed) and `tried` (the record of a check that did not pass).
checked! : Fx, ToolCompiler.Run, List(Str) => Try(List({ id : Str, passed : Bool, tried : ToolCompiler.Tried }), Fail)
checked! = |fx, run, ids| {
	installed = Launch.toolchains!(fx, run.roots)
	var $specs = []
	dir = Roots.item(run.roots, Item.Package(run.bundle))
	for id in ids {
		program = Launch.program!(fx, { roots: run.roots, id, installed, path: Err(NoCompiler) })?
		Launch.touch!(fx, run.roots, { id, now: run.now })
		$specs = $specs.append({ id, program })
	}
	env = Launch.child_env!(fx, run.roots, { opted_out: Bool.False })
	outs = fx.probes!({ pool: 12, specs: $specs.map(|s| ToolCompiler.check_spec({ id: s.id, program: s.program, env, dir, timeout: run.timeout })) })
	var $rows = []
	var $checks = []
	var $at = 0
	for id in ids {
		out = match outs.get($at) {
			Ok(found) => found
			Err(_) => return Err(Fail.new(Internal, "probes! gave no result for ${id}"))
		}
		$at = $at + 1
		class = Probe.classify(out)
		errors = Probe.errors({ text: out.stderr, dir, pkgs: run.roots.pkgs })
		match ToolCompiler.check_row({ bundle: run.bundle, id, target: run.target, class, errors }) {
			Ok(row) => {
				$rows = $rows.append(row)
			}
			Err(NoFact) => {}
		}
		passed = match class {
			Pass => Bool.True
			_ => Bool.False
		}
		$checks = $checks.append({ id, passed, tried: ToolCompiler.tried_of({ id, stage: Check, class, errors }) })
	}
	_ = Facts.save!(fx, { roots: run.roots, rows: $rows, existing: Replace })?
	Ok($checks)
}

# Step 4: the row of one build (no row with no platform hash).
save_build! : Fx, ToolCompiler.Run, { id : Str, attempt : ToolCompiler.Attempt } => Try({}, Fail)
save_build! = |fx, run, built| match ToolCompiler.build_row({ pf: run.pf, id: built.id, target: run.target, digest: ToolCompiler.digest({ bundle: run.bundle, hashes: run.hashes }), class: built.attempt.class, errors: built.attempt.errors }) {
	Ok(row) => {
		_ = Facts.save!(fx, { roots: run.roots, rows: [row], existing: Replace })?
		Ok({})
	}
	Err(_) => Ok({})
}
