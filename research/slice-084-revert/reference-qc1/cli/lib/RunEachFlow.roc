import Args
import Common
import Fail
import Fx
import Known
import Out
import RunCmd
import RunEach
import RunPlan
import RunSteps
import RunTools
import Roots
import ScriptsToml
import Text

## The command `tln run --each [<name>] [--keep-going] [-- <args>]` (slice 058, CLI 1: R-CM24, R-RUN13, R-RUN10, R-EA1 to R-EA8, R-PD9, R-RUN7, R-RUN9). Direct style over `Fx` (TESTING.md 2.2 part C): `RunEach` decides, this module orders the calls.
## `RunFlow.flow!` calls `run!` after `Project.scan!` when the line has `--each`. The command resolves nothing and writes no project file (R-RUN16). Its one write is `projects.json` (R-PD9).
##
## The calls, in order (the L2 case `run/rn4-each` fixes them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | The workspace root of the walk (R-PD3). None: failure of kind `Usage` (exit 2). | R-RUN13 |
## | 2 | One `read_files!` of `RunEach.paths` (the `talon.toml` candidates of the member files: a missing file is no file), then `RunEach.nodes`. No path: no call. | R-EA1, NC4 |
## | 3 | `RunEach.standalone`: when the nearest `talon.toml` of the walk is neither the root nor a node, the start directory is in a standalone project (NC2, NC5, R-PD5): the workspace has no effect, failure of kind `Usage` (exit 2), nothing is recorded. | R-RUN13, NC5 |
## | 4 | R-PD9: `canonical!` of all the member files of the root (one call, a path that fails stays as it is), then `Known.record!`. It runs also when a later step fails. | R-PD9, R-PT14 |
## | 5 | `RunTools.table` of the root file (the `[tools]` of the workspace, R-RUN3), the warnings of it on stderr. | R-RUN3 |
## | 5b | One `read_files!` of `RunEach.header_paths` (the member files of the nodes), then `RunEach.edges` and `RunEach.order`. A failure of them is exit 19 (a header with no or a bad header: exit 2) before the first step (R-EA5). No path: no call. | R-EA2, R-EA3, R-EA5 |
## | 6 | No name: stdout `RunEach.list_text`, or with `--json` `Out.json_ok` with `RunEach.list_data` (R-EA8). Nothing runs. | R-EA8 |
## | 7 | A name: `ScriptsToml.read` of each node (the first bad form is exit 19), the nodes that have the script (in the order of `RunEach.order`), then `RunSteps.plan!` for each of them with the args of `--` (R-RUN10) before any step runs. No node has the script: kind `Usage` (exit 2, question Q2 of the slice file). | R-RUN13, R-RUN1, R-RUN2, R-RUN4, R-RUN8, R-RUN10 |
## | 8 | For each node in order: `skipped` (with `--keep-going`: a line `skipped <node> (after <failed node>)` on stderr), else the line `running <node>` on stderr and `RunSteps.steps!`. A code that is not 0, or a failure of a step (exit 18 and the others, `Common.failed!`), fails the node. Without `--keep-going` the command stops with that code. With it, the run goes on and ends with the code of the first failure. | R-EA7, R-RUN7, R-RUN9 |
RunEachFlow :: [].{

	## What the caller has: the environment, the roots, the clock, and the walk.
	Start : { env : List((Str, Str)), roots : Roots, now : U64, scan : RunSteps.Scan }

	## Steps 1 to 8. The exit code of the run.
	run! : Fx, Args, RunCmd.Cmd, RunEachFlow.Start, (Fx => I32) => Try(I32, Fail)
	run! = |fx, args, cmd, start, tln| match start.scan.root {
		Err(NoWorkspace) => Err(Fail.new(Usage, "tln run --each needs a workspace: no talon.toml with [workspace] on the walk. Checked: ${Str.join_with(start.scan.walk.map(|d| d.dir), ", ")}."))
		Ok(root) => from_root!(fx, args, cmd, start, tln, root)
	}
}

# What the run knows once the nodes are read: the root, the nodes, the edges and the order, and what the steps need.
Space : { root : Str, nodes : List(RunEach.Node), links : List(RunEach.Edge), order : List(Str), ready : RunSteps.Ready }

# Steps 2 to 5b.
from_root! : Fx, Args, RunCmd.Cmd, RunEachFlow.Start, (Fx => I32), Str => Try(I32, Fail)
from_root! = |fx, args, cmd, start, tln, root| {
	members = start.scan.members
	found = read_nodes!(fx, root, members)?
	toml_dirs = start.scan.walk.keep_oks(
		|d| match d.toml {
			Ok(_) => Ok(d.dir)
			Err(None) => Err(NoToml)
		},
	)
	match RunEach.standalone({ toml_dirs, root, nodes: found.map(|n| n.dir) }) {
		Ok(dir) => return Err(Fail.new(Usage, "tln run --each needs a workspace: ${dir}/talon.toml is a standalone project (no member file of a workspace is in it) and the walk stops there."))
		Err(None) => {}
	}
	canonical = if members.is_empty() [] else members.map2(fx.canonical!(members), |file, result| result ?? file)
	Known.record!(fx, { roots: start.roots, files: canonical, now: start.now })?
	tools_path = Text.join(root, "talon.toml")
	tools_text = match start.scan.walk.find_first(|d| d.dir == root) {
		Ok(d) => d.toml ?? ""
		Err(_) => ""
	}
	table = RunTools.table({ path: tools_path, text: tools_text })?
	for w in table.warnings {
		fx.err!("warning: ${w}\n")
	}
	headers = read_headers!(fx, found)?
	links = RunEach.edges({ nodes: found, headers })?
	order = RunEach.order({ nodes: found.map(|n| n.dir), edges: links, root })?
	ready = { env: start.env, roots: start.roots, now: start.now, table, tools_file: { path: tools_path, text: tools_text } }
	space = { root, nodes: found, links, order, ready }
	match cmd.name {
		Err(None) => list!(fx, args, space)
		Ok(name) => run_nodes!(fx, args, { name, cmd, start, space }, tln)
	}
}

# Step 2: one `read_files!` of `RunEach.paths` (a missing file is no file), then the nodes. No path: no call.
read_nodes! : Fx, Str, List(Str) => Try(List(RunEach.Node), Fail)
read_nodes! = |fx, root, members| {
	paths = RunEach.paths({ root, members })
	answers = if paths.is_empty() [] else fx.read_files!(paths)
	files = paths.map2(
		answers,
		|path, answer| match answer {
			Ok(text) => Ok({ path, text: Ok(text) })
			Err(NotFound) => Ok({ path, text: Err(None) })
			Err(_) => Err(Fail.new(Environment, "cannot read ${path}"))
		},
	).map_try(|file| file)?
	Ok(RunEach.nodes({ root, members, files }))
}

# Step 5b: one `read_files!` of the member files of the nodes (`RunEach.header_paths`). No path: no call.
read_headers! : Fx, List(RunEach.Node) => Try(List({ file : Str, text : Str }), Fail)
read_headers! = |fx, found| {
	paths = RunEach.header_paths(found)
	answers = if paths.is_empty() [] else fx.read_files!(paths)
	paths.map2(
		answers,
		|file, answer| match answer {
			Ok(text) => Ok({ file, text })
			Err(_) => Err(Fail.new(Environment, "cannot read ${file}"))
		},
	).map_try(|header| header)
}

# Step 6 (R-EA8): the order and the edges, as text or as `data`. Nothing runs.
list! : Fx, Args, Space => Try(I32, Fail)
list! = |fx, args, space| {
	facts = { root: space.root, order: space.order, edges: space.links }
	if args.json {
		fx.out!(Out.json_ok({ command: args.typed, data: RunEach.list_data(facts) }))
	} else {
		fx.out!(RunEach.list_text({ file: Text.join(space.root, "talon.toml"), root: space.root, order: space.order, edges: space.links }))
	}
	Ok(0)
}

# What a node has for the script: its directory and the steps (R-RUN10: the args are on the last step).
Planned : { dir : Str, flats : List(RunPlan.Flat) }

# Step 7: the form of the `[scripts]` of each node (exit 19), the nodes that have the script in order, the plan of each one before any step. No node has the script: exit 2 (question Q2 of the slice file).
plan_nodes! : Fx, { name : Str, cmd : RunCmd.Cmd, start : RunEachFlow.Start, space : Space } => Try(List(Planned), Fail)
plan_nodes! = |fx, run| {
	space = run.space
	scripts = space.nodes.map_try(|n| ScriptsToml.read({ path: Text.join(n.dir, "talon.toml"), text: n.text }).map_ok(|list| { dir: n.dir, scripts: Ok(list) }))?
	have = space.order.keep_if(|dir| scripts.any(|s| s.dir == dir and has_script(s.scripts, run.name)))
	if have.is_empty() {
		return Err(Fail.new(Usage, "no script '${run.name}' in a node of the workspace ${space.root}."))
	}
	files = scripts.concat(RunSteps.known_files(run.start.scan).keep_if(|f| !scripts.any(|s| s.dir == f.dir)))
	var $planned = no_plans
	for dir in have {
		flats = RunSteps.plan!(fx, { name: run.name, args: run.cmd.args, dir, stop: space.root }, files)?
		$planned = $planned.append({ dir, flats })
	}
	Ok($planned)
}

# Does the file have the script? (`NoFile` has none.)
has_script : Try(List(ScriptsToml.Script), [NoFile]), Str -> Bool
has_script = |scripts, name| match scripts {
	Ok(list) => list.any(|s| s.name == name)
	Err(NoFile) => Bool.False
}

no_plans : List(Planned)
no_plans = []

# Step 8: each node in order. A code that is not 0, or a failure of a step, fails the node (R-EA7).
run_nodes! : Fx, Args, { name : Str, cmd : RunCmd.Cmd, start : RunEachFlow.Start, space : Space }, (Fx => I32) => Try(I32, Fail)
run_nodes! = |fx, args, run, tln| {
	space = run.space
	planned = plan_nodes!(fx, run)?
	label = |dir| RunEach.label({ root: space.root, dir })
	var $failed = no_dirs
	var $first = 0.I32
	for node in planned {
		behind = if run.cmd.keep_going RunEach.skipped({ edges: space.links, failed: $failed, node: node.dir }) else Err(None)
		match behind {
			Ok(cause) => fx.err!("skipped ${label(node.dir)} (after ${label(cause)})\n")
			Err(None) => {
				fx.err!("running ${label(node.dir)}\n")
				code = match RunSteps.steps!(fx, args, { name: run.name, ready: space.ready }, node.flats, tln) {
					Ok(done) => done
					Err(fail) => Common.failed!(fx, args, fail)
				}
				if code != 0 {
					if !run.cmd.keep_going return Ok(code)
					$failed = $failed.append(node.dir)
					if $first == 0 {
						$first = code
					}
				}
			}
		}
	}
	Ok($first)
}

no_dirs : List(Str)
no_dirs = []
