import Fail
import JsonDoc
import ScriptsToml
import Text

## The decisions of `tln run` that need no `Fx` (slice 057, CLI 1: R-RUN3, R-RUN4, R-RUN6, R-RUN7, R-RUN8, R-RUN9, R-RUN10, R-RUN11). Part A (pure, TESTING.md 2.2). `RunFlow` calls these functions and orders the calls.
##
## | Function | Decides | Rule |
## | --- | --- | --- |
## | `plan` | The flat list of steps of a script: `@<name>` expanded, a cycle and a missing name refused, the words of each step, the directory of each step, the args of `--` on the last step | R-RUN2, R-RUN4, R-RUN8, R-RUN10 |
## | `program` | What the first word of a step is: `roc`, `tln`, a `[tools]` key, a `.roc` script, or a program of `PATH` | R-RUN3, R-RUN6 |
## | `env` | The 2 variables that a step gets | R-RUN9 |
## | `list_text`, `list_data`, `path_note` | The list of `tln run` with no name, `--json` of it, the note for a key that is also on `PATH` | R-RUN11 |
## | `start_failed` | The failure of a step that cannot start | R-RUN7 |
RunPlan :: [].{

	## One `talon.toml` that the run knows: its directory (absolute), and its scripts (`Err(NoFile)`: the directory has no `talon.toml`).
	File : { dir : Str, scripts : Try(List(ScriptsToml.Script), [NoFile]) }

	## One step to run. `dir` is its working directory (absolute, R-RUN8). `words` are the words of the command line with the args of `--` (R-RUN10) after them. `text` is the step as written. `owner` is the name of the script that holds the step (for the messages). `ok_exit` are the codes of its `ok-exit` (R-RUN18, `[]`: none).
	Flat : { dir : Str, words : List(Str), text : Str, owner : Str, ok_exit : List(U8) }

	## What `plan` needs: the script `start.name` of the `talon.toml` in `start.dir` (the file that R-RUN12 found), the words after `--`, the stop directory of the walk (R-RUN8: an `in` directory must be inside it), and the files that are known.
	Want : { start : { dir : Str, name : Str }, args : List(Str), stop : Str, files : List(RunPlan.File) }

	## R-RUN2, R-RUN4, R-RUN8, R-RUN10: the steps of the script in order, as a flat list (each `@<name>` replaced by the steps of that script, in the `talon.toml` of its directory), before any step runs. `Err(Need(<dir>))`: the file in `<dir>` is not in `files`
	## (an `in` step with `@<name>` needs the `talon.toml` of that directory): the caller reads it and calls again. `Err(Stop(fail))` has the kind `Input` (exit 19). The texts are proposals (TW24):
	##
	## | Case | Message |
	## | --- | --- |
	## | A word that is shell syntax, or a quote that is not closed (R-RUN2) | `<file>: script <owner>: the step '<text>' has the word '<word>': a step is one command; use 2 steps, or a .roc script` and for a quote `<file>: script <owner>: the step '<text>' has a quote that is not closed` |
	## | A step with no word (R-RUN2) | `<file>: script <owner>: the step '<text>' has no command` |
	## | `@<name>` of a script that the file has not (R-RUN4), or an `in` directory with no `talon.toml` or with no such script (R-RUN8) | `<file>: script <owner>: the step '<text>' names the script '<name>', and <file of the script> has no such script`, or for a directory with no file `..., and <dir> has no talon.toml` |
	## | A cycle (R-RUN4) | `scripts call themselves: <name> -> <name> -> <name>` (each script of the cycle, the first one again at the end; a script of another directory is `<name> (<dir>)`) |
	## | An `in` directory outside the stop directory (R-RUN8) | `<file>: script <owner>: the step '<text>' has the directory '<dir>', which is outside the repository (<stop>)` |
	##
	## `<file>` is `<dir of the script>/talon.toml`. The args of `--` go to the last step of the script, and when that step is `@<name>` to the last step of that script, and so on (R-RUN10). A step that is not the last gets none.
	plan : RunPlan.Want -> Try(List(RunPlan.Flat), [Need(Str), Stop(Fail)])
	plan = |want| expand({ stop: want.stop, files: want.files, start_dir: want.start.dir }, want.start.dir, want.start.name, want.args, [])

	## What the first word of a step is (R-RUN3, R-RUN6). `keys` are the keys of the `[tools]` table of the run.
	##
	## | First word | Result |
	## | --- | --- |
	## | `roc` | `Roc(<the other words>)`: the proxy of this `tln` runs them (R-RUN3 point 1) |
	## | `tln` | `Tln(<the other words>)`: this `tln` runs them |
	## | A key of `[tools]` (R-RUN3 point 2) | `Tool({ key, args })` |
	## | A word that ends with `.roc` (R-RUN6) | `Roc([<the word>, "--", <the other words>])`: `roc <file> -- <other words>`, always with the `--` |
	## | Any other word (R-RUN3 point 3) | `Path({ program, args })`: the program is looked for on `PATH` |
	##
	## The order is this one. A key named `roc` or `tln` is shadowed by the first 2 rows, and a key with the form `x.roc` is a tool.
	program : { words : List(Str), keys : List(Str) } -> Try([Roc(List(Str)), Tln(List(Str)), Tool({ key : Str, args : List(Str) }), Path({ program : Str, args : List(Str) })], [NoWords])
	program = |facts| match facts.words {
		[] => Err(NoWords)
		[first, .. as rest] => if first == "roc" {
			Ok(Roc(rest))
		} else if first == "tln" {
			Ok(Tln(rest))
		} else if facts.keys.contains(first) {
			Ok(Tool({ key: first, args: rest }))
		} else if first.ends_with(".roc") {
			Ok(Roc([first, "--"].concat(rest)))
		} else {
			Ok(Path({ program: first, args: rest }))
		}
	}

	## R-RUN9: the variables that a step gets in addition to the environment of `tln run`: `TALON_SCRIPT` (the script that the user named) and `TALON_SCRIPT_DIR` (the absolute working directory of the step), in this order. No other variable.
	env : { script : Str, dir : Str } -> List((Str, Str))
	env = |facts| [("TALON_SCRIPT", facts.script), ("TALON_SCRIPT_DIR", facts.dir)]

	## R-RUN7, R-EC18: a step that cannot start (the program is not on `PATH`, or the system refuses): a failure of kind `Environment` (exit 18). A proposal (TW24): `script <owner>: the step '<text>' cannot start '<program>': <text of the system>`.
	start_failed : { owner : Str, text : Str, program : Str, why : Str } -> Fail
	start_failed = |facts| Fail.new(Environment, "script ${facts.owner}: the step '${facts.text}' cannot start '${facts.program}': ${facts.why}")

	## Slice 087 (R-RUN5, R-RUN7, R-RUN18, R-RUN19): the end of one step. `words` are the words of the step (`Flat.words`), `text` is the step as the messages show it (`Flat.text`), `ok_exit` the codes of its `ok-exit` (`[]`: none), `ended` how the child ended.
	##
	## | Field | Value |
	## | --- | --- |
	## | `pass` | `Exited(0)`, or `Exited(c)` with `c` in `ok_exit`. `Signaled(_)` and a code below 0 or above 255 are never a pass. |
	## | `code` | The code of the step: `c` for `Exited(c)`, `128 + n` for `Signaled(n)` (R-RUN7). |
	## | `note` | A pass with a code that is not 0: `tln: note: step "<text>" exited with <code>; this is accepted as success by the ok-exit of the step` (R-RUN18). A failure with code 2, no `ok-exit`, the first word `roc` and the next word, after an optional `+<id>` (R-SC11), `check`, `build` or `test`: the hint of R-RUN19. Else `Err(None)`. No line end. |
	step_end : { words : List(Str), text : Str, ok_exit : List(U8), ended : [Exited(I32), Signaled(I32)] } -> { pass : Bool, code : I32, note : Try(Str, [None]) }
	step_end = |facts| {
		(code, pass) = match facts.ended {
			Exited(c) => (c, c == 0 or (c >= 0 and c <= 255 and facts.ok_exit.contains(c.to_u8_wrap())))
			Signaled(n) => (128 + n, Bool.False)
		}
		note =
			if pass and code != 0 {
				Ok("tln: note: step \"${facts.text}\" exited with ${code.to_str()}; this is accepted as success by the ok-exit of the step")
			} else if facts.ended == Exited(2) and !pass and facts.ok_exit.is_empty() and roc_warns(facts.words) {
				Ok("tln: note: roc exits with 2 when it finds warnings and no errors; to accept them in this step, use { run = \"...\", ok-exit = [2] } (R-RUN18)")
			} else {
				Err(None)
			}
		{ pass, code, note }
	}

	## R-RUN11: the list of `tln run` with no name (a proposal, TW24). The line `scripts of <file>`, then for each script (in the order that is given) its name and a colon, and each step, 2 spaces in. A line end after each line.
	list_text : { file : Str, scripts : List(ScriptsToml.Script) } -> Str
	list_text = |facts| facts.scripts.fold(
		"scripts of ${facts.file}\n",
		|text, script| "${text}${script.name}:\n${Str.join_with(script.steps.map(|step| "  ${ScriptsToml.step_text(step)}${ok_text(step)}\n"), "")}",
	)

	## R-RUN11, R-J3: the `data` of `--json` with no name: `{ "file": <file>, "scripts": [ { "name": <name>, "steps": [<step text>, ...] }, ... ] }` (the shape is given by the design, the text of a step is a proposal: `ScriptsToml.step_text`).
	list_data : { file : Str, scripts : List(ScriptsToml.Script) } -> JsonDoc
	list_data = |facts| JsonDoc.Obj([
		("file", JsonDoc.Text(facts.file)),
		(
			"scripts",
			JsonDoc.Arr(
				facts.scripts.map(
					|script| JsonDoc.Obj([
						("name", JsonDoc.Text(script.name)),
						("steps", JsonDoc.Arr(script.steps.map(step_data))),
					]),
				),
			),
		),
	])

	## R-RUN11 (decision Q-S15 (b)): the note for a `[tools]` key that is also a program on `PATH` (a proposal, TW24): `the tool key '<key>' is also a program on PATH: inside tln run the key wins (R-RUN3)`. The caller prints it as `note: <text>` on stderr.
	path_note : Str -> Str
	path_note = |key| "the tool key '${key}' is also a program on PATH: inside tln run the key wins (R-RUN3)"
}

# R-RUN19: the words are `roc`, an optional `+<id>` (R-SC11), then `check`, `build` or `test`.
roc_warns : List(Str) -> Bool
roc_warns = |words| match words {
	["roc", sel, sub, ..] if sel.starts_with("+") => is_warn_sub(sub)
	["roc", sub, ..] => is_warn_sub(sub)
	_ => Bool.False
}

is_warn_sub : Str -> Bool
is_warn_sub = |sub| sub == "check" or sub == "build" or sub == "test"

# R-RUN11: ` (ok-exit = [2, 3])` for a step with `ok-exit`, else empty.
ok_text : ScriptsToml.Step -> Str
ok_text = |step| match ScriptsToml.ok_exit(step) {
	[] => ""
	codes => " (ok-exit = [${Str.join_with(codes.map(|c| c.to_str()), ", ")}])"
}

# R-RUN11: a step with `in` or `ok-exit` is `{ run, in, ok_exit }`, another step is its text.
step_data : ScriptsToml.Step -> JsonDoc
step_data = |step| {
	obj = |run, dir, codes| JsonDoc.Obj([
		("run", JsonDoc.Text(run)),
		(
			"in",
			match dir {
				Ok(d) => JsonDoc.Text(d)
				Err(_) => JsonDoc.Null
			},
		),
		("ok_exit", JsonDoc.Arr(codes.map(|c| JsonDoc.Num(c.to_i64())))),
	])
	match step {
		Line(text) => JsonDoc.Text(text)
		In({ dir, run }) => JsonDoc.Obj([("run", JsonDoc.Text(run)), ("in", JsonDoc.Text(dir)), ("ok_exit", JsonDoc.Null)])
		Run(r) => obj(r.run, r.dir, r.ok_exit)
	}
}

Ctx : { stop : Str, files : List(RunPlan.File), start_dir : Str }

Planned : Try(List(RunPlan.Flat), [Need(Str), Stop(Fail)])

# The script `name` of the `talon.toml` in `dir`, expanded. `stack` holds the scripts that are being expanded (a script that is in it again is a cycle, R-RUN4).
expand : Ctx, Str, Str, List(Str), List((Str, Str)) -> Planned
expand = |ctx, dir, name, args, stack| if stack.contains((dir, name)) {
	Err(Stop(cycle_fail(ctx, stack, dir, name)))
} else {
	scripts = scripts_of(ctx, dir)?
	match scripts.find_first(|s| s.name == name) {
		Ok(script) => steps_of(ctx, dir, script, script.steps, args, stack.append((dir, name)), [])
		Err(_) => Err(Stop(Fail.new(Input, "${dir}/talon.toml: has no script '${name}'")))
	}
}

# The scripts of the file in `dir`: `Need` when the file is not known yet.
scripts_of : Ctx, Str -> Try(List(ScriptsToml.Script), [Need(Str), Stop(Fail)])
scripts_of = |ctx, dir| match ctx.files.find_first(|f| f.dir == dir) {
	Err(_) => Err(Need(dir))
	Ok(file) => match file.scripts {
		Ok(scripts) => Ok(scripts)
		Err(NoFile) => Err(Stop(Fail.new(Input, "${dir} has no talon.toml")))
	}
}

# R-RUN4: `scripts call themselves: a -> b -> a`. A script of another directory than the start is `<name> (<dir>)`.
cycle_fail : Ctx, List((Str, Str)), Str, Str -> Fail
cycle_fail = |ctx, stack, dir, name| {
	from = stack.find_first_index(|e| e == (dir, name)) ?? 0
	label = |(d, n)| if d == ctx.start_dir n else "${n} (${d})"
	loop = stack.drop_first(from).append((dir, name))
	Fail.new(Input, "scripts call themselves: ${Str.join_with(loop.map(label), " -> ")}")
}

# The steps of one script in order. The args of `--` go to the last step (R-RUN10).
steps_of : Ctx, Str, ScriptsToml.Script, List(ScriptsToml.Step), List(Str), List((Str, Str)), List(RunPlan.Flat) -> Planned
steps_of = |ctx, dir, script, steps, args, stack, done| match steps {
	[] => Ok(done)
	[step, .. as rest] => {
		here = { ctx, dir, owner: script.name, step, stack }
		flats = one_step(here, if rest.is_empty() args else [])?
		steps_of(ctx, dir, script, rest, args, stack, done.concat(flats))
	}
}

Here : { ctx : Ctx, dir : Str, owner : Str, step : ScriptsToml.Step, stack : List((Str, Str)) }

# R-RUN8: an `in` step has its own directory, inside the stop directory.
one_step : Here, List(Str) -> Planned
one_step = |here, args| match here.step {
	Line(line) => run_text(here, here.dir, line, args)
	In({ dir, run }) => in_dir(here, dir, run, args)
	Run(r) => match r.dir {
		Ok(dir) => in_dir(here, dir, r.run, args)
		Err(Here) => run_text(here, here.dir, r.run, args)
	}
}

in_dir : Here, Str, Str, List(Str) -> Planned
in_dir = |here, dir, run, args| {
	target = Text.resolve(here.dir, dir)
	if inside(here.ctx.stop, target) {
		run_text(here, target, run, args)
	} else {
		Err(Stop(step_fail(here, "has the directory '${dir}', which is outside the repository (${here.ctx.stop})")))
	}
}

inside : Str, Str -> Bool
inside = |stop, dir| stop == "/" or dir == stop or dir.starts_with("${stop}/")

step_fail : Here, Str -> Fail
step_fail = |here, why| Fail.new(Input, "${here.dir}/talon.toml: script ${here.owner}: the step '${ScriptsToml.step_text(here.step)}' ${why}")

# The text of a step that runs in `target`: `@<name>` is that script of the file of `target`, else one command.
run_text : Here, Str, Str, List(Str) -> Planned
run_text = |here, target, text, args| {
	line = text.trim()
	if line.starts_with("@") {
		callee = line.drop_prefix("@")
		scripts = scripts_of_or_none(here.ctx, target)?
		match scripts {
			Err(NoFile) => Err(Stop(step_fail(here, "names the script '${callee}', and ${target} has no talon.toml")))
			Ok(list) => if list.any(|s| s.name == callee) {
				expand(here.ctx, target, callee, args, here.stack)
			} else {
				Err(Stop(step_fail(here, "names the script '${callee}', and ${target}/talon.toml has no such script")))
			}
		}
	} else {
		match ScriptsToml.words(text) {
			Err(Shell(word)) => Err(Stop(step_fail(here, "has the word '${word}': a step is one command; use 2 steps, or a .roc script")))
			Err(Unclosed) => Err(Stop(step_fail(here, "has a quote that is not closed")))
			Ok([]) => Err(Stop(step_fail(here, "has no command")))
			Ok(words) => Ok([{ dir: target, words: words.concat(args), text: ScriptsToml.step_text(here.step), owner: here.owner, ok_exit: ScriptsToml.ok_exit(here.step) }])
		}
	}
}

# The scripts of the file in `dir`, or `NoFile`; `Need` when the file is not known.
scripts_of_or_none : Ctx, Str -> Try(Try(List(ScriptsToml.Script), [NoFile]), [Need(Str)])
scripts_of_or_none = |ctx, dir| match ctx.files.find_first(|f| f.dir == dir) {
	Err(_) => Err(Need(dir))
	Ok(file) => Ok(file.scripts)
}
