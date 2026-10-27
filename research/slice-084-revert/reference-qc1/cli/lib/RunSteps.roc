import Args
import Fail
import Fx
import Net
import Proxy
import RunFind
import RunPlan
import RunTools
import Roots
import ScriptsToml
import Text
import ToolsToml

## The plan and the steps of `tln run` (slice 057, moved here in slice 058): the code that `RunFlow` (one script) and `RunEachFlow` (one script in each node, R-RUN13) share. Direct style over `Fx` (TESTING.md 2.2 part C). `RunPlan` decides, this module orders the calls.
##
## | Function | Does | Rule |
## | --- | --- | --- |
## | `locate!` | The file that holds the script: `RunFind.find`, a `Need` is one `read_files!` | R-RUN12, NC4 |
## | `record_files!` | The project files to record (R-PD9, NC1) | R-PD9, R-PD16 |
## | `known_files` | The `talon.toml` files of the walk, as `RunPlan` wants them | R-RUN4, R-RUN8 |
## | `plan!` | `RunPlan.plan` before any step. A `Need(dir)` is one `read_files!` of `<dir>/talon.toml`, then the plan again | R-RUN1, R-RUN2, R-RUN4, R-RUN8, R-RUN10 |
## | `steps!` | Each step in order, a child at a time, until one gives a code that is not 0 (the code of the run, R-RUN7) or cannot start (exit 18). The program is `RunPlan.program`: `Path`, `Tool`, `Roc` (`Proxy.run!` with `derived`) or `Tln` (the function that the caller gives) | R-RUN3, R-RUN5, R-RUN6, R-RUN7, R-RUN9, R-PT9, R-PX1 |
## | `derived` | The `Fx` that a `roc` or `tln` step gets: 5 fields change (`args!`, `cwd!`, `env_all!`, `program_name!`, `exec!`), `exec!` runs in the directory of the step with the 2 variables of R-RUN9 added | R-RUN3, R-RUN6, R-RUN9 |
RunSteps :: [].{

	## What the walk gave (`Project.scan!`).
	Scan : { walk : List({ dir : Str, names : List(Str), toml : Try(Str, [None]) }), root : Try(Str, [NoWorkspace]), members : List(Str) }

	## What the steps need: the environment, the roots, the clock, the table of `[tools]` and the file that it is from.
	Ready : { env : List((Str, Str)), roots : Roots, now : U64, table : RunTools.Table, tools_file : { path : Str, text : Str } }

	## R-RUN4, R-RUN8: the files that the run knows: each directory of the walk. A file with a form that is not valid is left out (reading it again gives its failure).
	known_files : Scan -> List(RunPlan.File)
	known_files = |scan| scan.walk.keep_oks(
		|d| match d.toml {
			Err(None) => Ok({ dir: d.dir, scripts: Err(NoFile) })
			Ok(text) => match ScriptsToml.read({ path: Text.join(d.dir, "talon.toml"), text }) {
				Ok(scripts) => Ok({ dir: d.dir, scripts: Ok(scripts) })
				Err(_) => Err(Skip)
			}
		},
	)

	## Step 3 of `tln run` (R-RUN12): the file that holds the script. `walk` is the directories as `RunFind` wants them. A `Need` of `RunFind` is one `read_files!` (NC4), then the question again.
	locate! : Fx, { name : Try(Str, [None]), dirs : List(RunFind.Dir) }, Scan, List({ path : Str, exists : Bool }) => Try(RunFind.Found, Fail)
	locate! = |fx, want, scan, probes| match RunFind.find({ name: want.name, walk: want.dirs, root: scan.root, members: scan.members, probes }) {
		Ok(found) => Ok(found)
		Err(Stop(fail)) => Err(fail)
		Err(Need(paths)) => {
			answers = fx.read_files!(paths)
			more = paths.map2(
				answers,
				|path, answer| match answer {
					Err(NotFound) => { path, exists: Bool.False }
					_ => { path, exists: Bool.True }
				},
			)
			locate!(fx, want, scan, probes.concat(more))
		}
	}

	## Step 4 of `tln run` (R-PD9, NC1): the project files to record, as canonical paths. A workspace file: its member files. A standalone file: its `main.roc`, else its `talon.toml`.
	record_files! : Fx, Scan, RunFind.Found => List(Str)
	record_files! = |fx, scan, found| {
		files = match found.kind {
			Root | Member => found.members
			Standalone => {
				has_main = match scan.walk.find_first(|d| d.dir == found.dir) {
					Ok(d) => d.names.contains("main.roc")
					Err(_) => Bool.False
				}
				[Text.join(found.dir, if has_main "main.roc" else "talon.toml")]
			}
		}
		if files.is_empty() files else files.map2(fx.canonical!(files), |file, result| result ?? file)
	}

	## R-RUN1, R-RUN2, R-RUN4, R-RUN8, R-RUN10: the plan of the script `name` of the `talon.toml` in `dir`, before any step. `stop` is the stop directory of the walk (R-RUN8). A `Need(dir)` is one `read_files!` of `<dir>/talon.toml`, then the plan again.
	plan! : Fx, { name : Str, args : List(Str), dir : Str, stop : Str }, List(RunPlan.File) => Try(List(RunPlan.Flat), Fail)
	plan! = |fx, want, files| match RunPlan.plan({ start: { dir: want.dir, name: want.name }, args: want.args, stop: want.stop, files }) {
		Ok(flats) => Ok(flats)
		Err(Stop(fail)) => Err(fail)
		Err(Need(dir)) => {
			path = Text.join(dir, "talon.toml")
			file = match fx.read_files!([path]) {
				[Ok(text)] => Ok({ dir, scripts: Ok(ScriptsToml.read({ path, text })?) })
				[Err(NotFound)] => Ok({ dir, scripts: Err(NoFile) })
				_ => Err(Fail.new(Environment, "cannot read ${path}"))
			}
			plan!(fx, want, files.append(file?))
		}
	}

	## R-RUN5, R-RUN7: the steps in order, a child at a time, until one gives a code that is not 0.
	steps! : Fx, Args, { name : Str, ready : Ready }, List(RunPlan.Flat), (Fx => I32) => Try(I32, Fail)
	steps! = |fx, args, run, flats, tln| {
		keys = run.ready.table.tools.map(|e| e.key)
		var $know = no_know
		for flat in flats {
			vars = RunPlan.env({ script: run.name, dir: flat.dir })
			inner = derived(fx, { env: run.ready.env, vars, dir: flat.dir })
			code = match RunPlan.program({ words: flat.words, keys }) {
				Err(NoWords) => Ok(0)
				Ok(Roc(rest)) => Ok(Proxy.run!({ ..inner, args!: || rest, program_name!: || "roc" }))
				Ok(Tln(rest)) => Ok(tln({ ..inner, args!: || rest, program_name!: || "tln" }))
				Ok(Path(p)) => exec!(fx, flat, { program: p.program, args: p.args, vars })
				Ok(Tool(t)) => {
					known = match $know {
						Ok(k) => k
						Err(NotLoaded) => RunTools.load!(fx, run.ready.roots)?
					}
					entry = find_entry(run.ready.table.tools, t.key)?
					got = RunTools.bin!(fx, args, tool_run(run.ready), known, entry)?
					$know = Ok(got.know)
					exec!(fx, flat, { program: got.bin, args: t.args, vars })
				}
			}
			done = code?
			if done != 0 return Ok(done)
		}
		Ok(0)
	}
}

# What no tool has been loaded yet.
no_know : Try(RunTools.Know, [NotLoaded])
no_know = Err(NotLoaded)

# The `Fx` that a `roc` or `tln` step gets (step 7): the 5 fields of the table in the doc of this module. `exec!` runs in the directory of the step with the 2 variables added.
derived : Fx, { env : List((Str, Str)), vars : List((Str, Str)), dir : Str } -> Fx
derived = |fx, step| {
	..fx,
	args!: || [],
	cwd!: || step.dir,
	env_all!: || step.env.keep_if(|(name, _)| !step.vars.any(|(v, _)| v == name)).concat(step.vars),
	program_name!: || "roc",
	exec!: |run| fx.exec_in!({ argv: run.argv, env: run.env.concat(step.vars), cwd: step.dir }),
}

# One child in the directory of the step. A program that cannot start is exit 18.
exec! : Fx, RunPlan.Flat, { program : Str, args : List(Str), vars : List((Str, Str)) } => Try(I32, Fail)
exec! = |fx, flat, run| match fx.exec_in!({ argv: [run.program].concat(run.args), env: run.vars, cwd: flat.dir }) {
	Ok(code) => Ok(code)
	Err(NotStarted(why)) => Err(RunPlan.start_failed({ owner: flat.owner, text: flat.text, program: run.program, why }))
}

find_entry : List(ToolsToml.Entry), Str -> Try(ToolsToml.Entry, Fail)
find_entry = |tools, key| match tools.find_first(|e| e.key == key) {
	Ok(entry) => Ok(entry)
	Err(_) => Err(Fail.new(Internal, "no tool '${key}' in [tools]"))
}

# What `RunTools.bin!` needs: the run.
tool_run : RunSteps.Ready -> RunTools.Run
tool_run = |ready| {
	env: ready.env,
	roots: ready.roots,
	net: Net.from_env(ready.env),
	now: ready.now,
	path: ready.tools_file.path,
	text: ready.tools_file.text,
	tools: ready.table.tools,
}
