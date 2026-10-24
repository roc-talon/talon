import Probe
import Text

## The probes of one member of the ladder (Resolution 4 "Probes"; Design 7 R-BL1, R-BL2, R-LD4 to R-LD7, R-CM11, R-LB2). Split from `Ladder` (slice 031b). `Ladder.plan` and `Ladder.plan_replace` call these functions.
LadderPlan :: [].{

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
}
