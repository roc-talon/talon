import Args
import Clock
import Common
import Fail
import Fx
import Known
import Net
import Out
import Project
import Proxy
import RunCmd
import RunEachFlow
import RunFind
import RunPlan
import RunTools
import Roots
import ScriptsToml
import Text
import ToolsToml

## The command `tln run [<name>] [-- <args>]` (slice 057, CLI 1: R-CM24, R-RUN1 to R-RUN12, R-RUN14 to R-RUN17, R-HK1, R-PD9, R-PD16, R-PT8 to R-PT10, R-SE17). Direct style over `Fx` (TESTING.md 2.2 part C): `RunCmd`, `ScriptsToml`, `RunFind` and `RunPlan` decide, this module orders the calls.
## `Run.tln!` calls `run!` for the command `["run"]`, with itself as the function that runs a `tln` step. The command resolves nothing, fetches nothing and writes no project file (R-RUN16). Its one write is `projects.json` (R-PD9). Its one fetch is the build of a project tool that has no binary (R-PT9, `RunTools`).
## No other command reads `[scripts]` (R-RUN15, R-HK1).
##
## The calls, in order (the L2 cases `run/rn1-scripts`, `run/rn2-words`, `run/rn3-tools` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `RunCmd.read(args)`. A failure is printed with `Common.failed!` (no `Fx` call). | R-RUN10, R-FL1 |
## | 2 | `env_all!`, `Roots.from_env` (exit 18 for a bad `HOME`), `Clock.now!` (`clock!`, `TALON_NOW`), `cwd!`. | R-EV13, R-EV22 |
## | 3 | `Project.scan!`: `list_dirs!` of each directory of the walk, one `read_files!` of the `talon.toml` files, the `list_dirs!` of the members of the root. Then `RunFind.find` with the scripts of each file (`ScriptsToml.read_table`). On `Need(paths)`: one `read_files!` of the paths (a `NotFound` is "no file"), then `find` again. | R-RUN12, R-PD2, R-PD3 |
## | 4 | R-PD9: the files to record are, for a `Root` file all member files, for a `Member` file the member files of its node, for a `Standalone` file the `main.roc` of its directory when the directory has one, else the `talon.toml` itself (NC1). `canonical!` of them (one call, a path that fails stays as it is), then `Known.record!`. No file: no call. It runs also when a later step fails. | R-PD9, R-PD16, R-PT14 |
## | 5 | No name: the list. `RunTools.table` of the file of `[tools]` (`RunFind.Found.tools_dir`), the warnings of it on stderr, one `programs!` of the keys when there are some, the note `RunPlan.path_note` on stderr for each key that is on `PATH`. stdout: `RunPlan.list_text`, or with `--json` `Out.json_ok` with `RunPlan.list_data`. | R-RUN11 |
## | 6 | A name: `RunTools.table` (warnings on stderr). `RunPlan.plan` before any step. On `Need(dir)`: one `read_files!` of `<dir>/talon.toml`, `ScriptsToml.read_table` (an issue is exit 19, a missing file is `NoFile`), `plan` again. A failure of `plan` is its `Fail` (exit 19). | R-RUN1, R-RUN2, R-RUN4, R-RUN8, R-RUN10 |
## | 7 | Each step in order, a child at a time, until one gives a code that is not 0 (the code of the run, R-RUN7) or `NotStarted` (`RunPlan.start_failed`, exit 18). The program is `RunPlan.program`: `Path`: `exec_in!` of `[<program>] ++ <args>` in the directory of the step with `RunPlan.env`. `Tool`: `RunTools.load!` (once for the run) and `RunTools.bin!`, then `exec_in!` of `[<binary>] ++ <args>` the same way. | R-RUN3, R-RUN5, R-RUN7, R-RUN9, R-PT9 |
## | 7 `roc` | `Roc(args)`: `Proxy.run!` with a `Fx` that has `args!` = `args`, `cwd!` = the directory of the step, `env_all!` = the environment of step 2 and the variables of R-RUN9, `program_name!` = `roc`, and `exec!` = `exec_in!` in the directory of the step with the variables of R-RUN9 added. So the step gets the compiler that the proxy selects (R-RUN3, R-PX1), also when `tln setup` did not run. The derived `Fx` makes no call for these 5 fields: its calls are those of the proxy. | R-RUN3, R-RUN6, R-PX1 |
## | 7 `tln` | `Tln(args)`: the function `tln!` of `Run` with the same derived `Fx`, but `program_name!` = `tln`. | R-RUN3 |
## Slice 058: with `--each` (`cmd.each`), `flow!` calls `RunEachFlow.run!` right after `Project.scan!` (before the search for the script, R-RUN12 does not apply to `--each`). That module needs the plan and the steps of this module (`plan!`, `steps!`, `derived`, `exec!`, `find_entry`, `tool_run`, `known_files`):
## move them to a new module (for example `RunSteps`) that both import, so that no module imports a module that imports it and each module stays under 490 lines.
RunFlow :: [].{

	## Steps 1 to 7. The exit code of the run.
	run! : Fx, Args, (Fx => I32) => I32
	run! = |fx, args, tln| match RunCmd.read(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(cmd) => match flow!(fx, args, cmd, tln) {
			Ok(code) => code
			Err(fail) => Common.failed!(fx, args, fail)
		}
	}
}

# What the walk gave (`Project.scan!`).
Scan : { walk : List({ dir : Str, names : List(Str), toml : Try(Str, [None]) }), root : Try(Str, [NoWorkspace]), members : List(Str) }

# What the steps need: the run, the file that holds the script, the table of `[tools]` and the plan.
Ready : { env : List((Str, Str)), roots : Roots, now : U64, scan : Scan, found : RunFind.Found, table : RunTools.Table, tools_file : { path : Str, text : Str } }

# Steps 2 to 7.
flow! : Fx, Args, RunCmd.Cmd, (Fx => I32) => Try(I32, Fail)
flow! = |fx, args, cmd, tln| {
	env = fx.env_all!()
	roots = Roots.from_env(env)?
	now = Clock.now!(fx, env)?
	home = match env.find_first(|(name, _)| name == "HOME") {
		Ok((_, dir)) => dir
		Err(_) => ""
	}
	cwd = fx.cwd!()
	scan = Project.scan!(fx, { start: cwd, home })?
	if cmd.each {
		return RunEachFlow.run!(fx, args, cmd, { env, roots, now, scan }, tln)
	}
	found = locate!(fx, cmd.name, scan, [])?
	Known.record!(fx, { roots, files: record_files!(fx, scan, found), now })?
	tools_path = Text.join(found.tools_dir, "talon.toml")
	tools_text = match scan.walk.find_first(|d| d.dir == found.tools_dir) {
		Ok(d) => d.toml ?? ""
		Err(_) => ""
	}
	table = RunTools.table({ path: tools_path, text: tools_text })?
	for w in table.warnings {
		fx.err!("warning: ${w}\n")
	}
	ready = { env, roots, now, scan, found, table, tools_file: { path: tools_path, text: tools_text } }
	match cmd.name {
		Err(None) => list!(fx, args, ready)
		Ok(name) => {
			flats = plan!(fx, { name, args: cmd.args, ready }, known_files(scan))?
			steps!(fx, args, { name, ready }, flats, tln)
		}
	}
}

# The walk as `RunFind` wants it: the script names of each file, and the first failure of the form of its `[scripts]` table (R-RUN1).
find_dirs : Scan -> List(RunFind.Dir)
find_dirs = |scan| scan.walk.map(
	|d| match d.toml {
		Err(None) => { dir: d.dir, toml: Err(None) }
		Ok(text) => match ScriptsToml.read({ path: Text.join(d.dir, "talon.toml"), text }) {
			Ok(scripts) => { dir: d.dir, toml: Ok({ names: scripts.map(|s| s.name), bad: Err(None) }) }
			Err(fail) => { dir: d.dir, toml: Ok({ names: [], bad: Ok(fail.message) }) }
		}
	},
)

# Step 3 (R-RUN12): the file that holds the script. A `Need` of `RunFind` is one `read_files!` (NC4), then the question again.
locate! : Fx, Try(Str, [None]), Scan, List({ path : Str, exists : Bool }) => Try(RunFind.Found, Fail)
locate! = |fx, name, scan, probes| match RunFind.find({ name, walk: find_dirs(scan), root: scan.root, members: scan.members, probes }) {
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
		locate!(fx, name, scan, probes.concat(more))
	}
}

# Step 4 (R-PD9, NC1): the project files to record, as canonical paths. A workspace file: its member files. A standalone file: its `main.roc`, else its `talon.toml`.
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

# The files that the run knows: each directory of the walk. A file with a form that is not valid is left out (reading it again gives its failure).
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

# Step 6 (R-RUN1, R-RUN2, R-RUN4, R-RUN8, R-RUN10): the plan before any step. A `Need(dir)` is one `read_files!` of `<dir>/talon.toml`, then the plan again.
plan! : Fx, { name : Str, args : List(Str), ready : Ready }, List(RunPlan.File) => Try(List(RunPlan.Flat), Fail)
plan! = |fx, want, files| match RunPlan.plan({ start: { dir: want.ready.found.dir, name: want.name }, args: want.args, stop: want.ready.found.stop, files }) {
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

# Step 5 (R-RUN11): the list of the file that holds the scripts, and the note for each key that is also a program on `PATH`.
list! : Fx, Args, Ready => Try(I32, Fail)
list! = |fx, args, ready| {
	file = Text.join(ready.found.dir, "talon.toml")
	text = match ready.scan.walk.find_first(|d| d.dir == ready.found.dir) {
		Ok(d) => d.toml ?? ""
		Err(_) => ""
	}
	scripts = ScriptsToml.read({ path: file, text })?
	keys = ready.table.tools.map(|e| e.key)
	if !keys.is_empty() {
		for (key, on_path) in keys.map2(fx.programs!(keys), |key, on_path| (key, on_path)) {
			if on_path fx.err!("note: ${RunPlan.path_note(key)}\n")
		}
	}
	if args.json {
		fx.out!(Out.json_ok({ command: args.typed, data: RunPlan.list_data({ file, scripts }) }))
	} else {
		fx.out!(RunPlan.list_text({ file, scripts }))
	}
	Ok(0)
}

# What no tool has been loaded yet.
no_know : Try(RunTools.Know, [NotLoaded])
no_know = Err(NotLoaded)

# Step 7 (R-RUN5, R-RUN7): the steps in order, a child at a time, until one gives a code that is not 0.
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
tool_run : Ready -> RunTools.Run
tool_run = |ready| {
	env: ready.env,
	roots: ready.roots,
	net: Net.from_env(ready.env),
	now: ready.now,
	path: ready.tools_file.path,
	text: ready.tools_file.text,
	tools: ready.table.tools,
}
