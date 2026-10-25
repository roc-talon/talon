import Args
import BuildSkip
import Clock
import Common
import Fail
import Fx
import Item
import Lookup
import Net
import Out
import Ref
import RocInstall
import Roots
import Scope
import Setup
import SetupIo
import Text
import ToolBuild
import ToolInstall
import ToolManage
import ToolsJson

## The commands `tln tool list` and `tln tool remove` (slice 048, CLI 6.4: R-CM16, R-CM19, R-T4, R-T8, R-B6, R-ST6, R-ST11, R-SC3, R-CC1, R-CC6, R-PT12). Direct style over `Fx` (TESTING.md 2.2 part C): `ToolManage` decides, this module orders the calls. `Run.run!` calls `list!` for the
## command `["tool", "list"]` and `remove!` for `["tool", "remove"]`. `machine!` is also the first step of `ToolUpdateFlow`. The calls, in order (the L2 case `tool/tm1-manage` and the L3 case `tools/ti3-tool-git` fix them):
##
## | Step | Command | Does | Rule |
## | --- | --- | --- | --- |
## | 1 | both | `ToolManage.read(args)`. A failure is printed with `Common.failed!` (no `Fx` call). | R-CM16, R-CM19 |
## | 2 | list | `env_all!`, `Roots.from_env`, one `read_files!` of `tools.json` (a missing file is no tool), `ToolsJson.manifest`. No `clock!`, no `platform!`. | R-T4 |
## | 3 | list | The table (`ToolManage.ls_report`) on stdout, or with `--json` the envelope with `ToolManage.ls_data`. `--quiet` hides nothing (the table is the answer). | R-T8, R-J1 to R-J4 |
## | 4 | remove | `env_all!`, `Roots.from_env`, `platform!` (`Setup.bin_dir`, the file name), one `read_files!` of `tools.json`, `ToolsJson.manifest`, `Lookup.find` (scope `Tool`) and `ToolManage.pick`. A failure prints its block, then the failure. No request, no `clock!`, no project file (R-PT12). | R-SC3, R-PT12 |
## | 5 | remove | The lock of `tools.json` (`Fx.locked!` on `Roots.item(ToolsJson)`, `Wait`, R-CC3) for all the changes (R-CC6): `read_files!` and `ToolsJson.manifest` again (the tool must still be there), `list_dirs!` of the bin dir, `SetupIo.have_of!` (one `sha256_file!` of the entry), `sha256_file!` of the binary of the data bin dir, `ToolManage.entry_fate`. | R-CC6, R-ST11 |
## | 6 | remove | Still under the lock: one `delete!` of `[<bin dir entry>, <data bin file>]` for `Remove`, or of `[<data bin file>]` for `Gone` and `Keep` (a path that is not there is no failure). Then `write_atomic!` of `tools.json` (`ToolsJson.drop`). The files go first and the manifest last (a stop between gives a tool in `tools.json` with no files, and `tool remove` can run again). Nothing is written in `talon/x/` (R-B6). | R-B6, R-ST6, R-CC1 |
## | 7 | remove | `Keep`: the line of `ToolManage.kept_warning` on stderr. The answer `ToolManage.remove_report` on stdout (`--quiet` hides it), or with `--json` the text on stderr and the envelope with `ToolManage.remove_data` on stdout. | R-OUT2, R-J1 to R-J4 |
ToolManageFlow :: [].{

	## `tln tool list`.
	list! : Fx, Args => I32
	list! = |fx, args| match ToolManage.read(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(_) => match listing!(fx) {
			Err(fail) => Common.failed!(fx, args, fail)
			Ok(tools) => {
				if args.json {
					fx.out!(Out.json_ok({ command: args.typed, data: ToolManage.ls_data(tools) }))
				} else {
					shown = ToolManage.ls_report(tools)
					for line in shown.stdout {
						fx.out!(line)
					}
					for line in shown.stderr {
						fx.err!(line)
					}
				}
				0
			}
		}
	}

	## `tln tool remove`.
	remove! : Fx, Args => I32
	remove! = |fx, args| match ToolManage.read(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(cmd) => match cmd.ref {
			Err(None) => Common.failed!(fx, args, Fail.new(Internal, "tool remove has no tool"))
			Ok(ref) => match removal!(fx, ref) {
				Err(fail) => Common.failed!(fx, args, fail)
				Ok(done) => {
					print!(fx, args, done)
					0
				}
			}
		}
	}

	## The machine and the manifest, for the commands that go through the tools (`remove` and `ToolUpdateFlow`): the environment, the roots, the network settings, the time, the system (`platform!`), the bin dir, the build target, `config.toml` (`min-release-age`, the probe timeout)
	## and the tools of `tools.json`. `Facts` is the base of `ToolBuild.Facts`: `name`, `key` and `file` are empty, a tool command sets them for each tool.
	machine! : Fx => Try({ facts : ToolBuild.Facts, tools : List(ToolsJson.Tool) }, Fail)
	machine! = |fx| {
		env = fx.env_all!()
		roots = Roots.from_env(env)?
		net = Net.from_env(env)
		now = Clock.now!(fx, env)?
		machine = fx.platform!()
		bin = Setup.bin_dir({ os: machine.os, env })?
		target = match BuildSkip.target(machine) {
			Ok(known) => known
			Err(Unknown) => return Err(Fail.new(Environment, "tln has no build target for this machine"))
		}
		tools_file = Roots.item(roots, Item.ToolsJson)
		tools = ToolsJson.manifest({ path: tools_file, text: SetupIo.read_text!(fx, tools_file)? })?
		config = RocInstall.read_config!(fx, roots)?
		facts = {
			env,
			roots,
			net,
			now,
			os: machine.os,
			bin,
			target,
			entries: tools.map(entry_of),
			min_age: config.min_release_age ?? 172800,
			probe_timeout: ToolBuild.probe_timeout(config),
			name: "",
			key: "",
			file: "",
		}
		Ok({ facts, tools })
	}

	## The facts of one tool: the base with the name, the key and the file name of the tool (R-ST15).
	facts_of : ToolBuild.Facts, ToolsJson.Tool -> ToolBuild.Facts
	facts_of = |base, tool| { ..base, name: tool.name, key: tool.key, file: ToolInstall.file_name({ os: base.os, key: tool.key }) }

	## The tool that the operand names (R-SC3): `Lookup.find` in the scope `Tool`, then `ToolManage.pick`. A failure of the lookup prints its block first.
	find! : Fx, { ref : Ref, tools : List(ToolsJson.Tool) } => Try(ToolsJson.Tool, Fail)
	find! = |fx, run| match Lookup.find(Scope.Tool, run.ref, ToolsJson.entities(run.tools.map(entry_of))) {
		Ok(found) => ToolManage.pick({ tools: run.tools, found })
		Err({ fail, block }) => {
			if !block.is_empty() fx.err!(block)
			Err(fail)
		}
	}
}

# What `remove!` did: the tool and the paths that it deleted and kept.
Done : { tool : ToolsJson.Tool, removed : List(Str), kept : List(Str) }

entry_of : ToolsJson.Tool -> ToolsJson.Entry
entry_of = |tool| { key: tool.key, name: tool.name, source: tool.source }

# Step 2 of `list!`: the tools of `tools.json`. No clock, no platform.
listing! : Fx => Try(List(ToolsJson.Tool), Fail)
listing! = |fx| {
	roots = Roots.from_env(fx.env_all!())?
	tools_file = Roots.item(roots, Item.ToolsJson)
	ToolsJson.manifest({ path: tools_file, text: SetupIo.read_text!(fx, tools_file)? })
}

# Steps 4 to 6 of `remove!`: the tool, then the lock and the changes.
removal! : Fx, Ref => Try(Done, Fail)
removal! = |fx, ref| {
	env = fx.env_all!()
	roots = Roots.from_env(env)?
	machine = fx.platform!()
	bin = Setup.bin_dir({ os: machine.os, env })?
	tools_file = Roots.item(roots, Item.ToolsJson)
	tools = ToolsJson.manifest({ path: tools_file, text: SetupIo.read_text!(fx, tools_file)? })?
	tool = ToolManageFlow.find!(fx, { ref, tools })?
	file = ToolInstall.file_name({ os: machine.os, key: tool.key })
	paths = { tools_file, file, entry: Text.join(bin, file), bin, data_file: Text.join(Roots.item(roots, Item.Bin), file) }
	fx.locked!(tools_file, || remove_locked!(fx, tool, paths))
}

# Steps 5 and 6, under the lock (R-CC6): the files first, `tools.json` last (D12).
remove_locked! : Fx, ToolsJson.Tool, { tools_file : Str, file : Str, entry : Str, bin : Str, data_file : Str } => Try(Done, Fail)
remove_locked! = |fx, tool, paths| {
	text = SetupIo.read_text!(fx, paths.tools_file)?
	tools = ToolsJson.manifest({ path: paths.tools_file, text })?
	still = ToolManage.pick({ tools, found: Lookup.Existing({ alias: tool.key, name: tool.name, series: "" }) })?
	listed = match fx.list_dirs!([paths.bin]) {
		[one] => SetupIo.entries_of(one, paths.bin)?
		_ => return Err(Fail.new(Internal, "list_dirs! gave no result"))
	}
	have = SetupIo.have_of!(fx, paths.bin, listed, paths.file)
	old = match fx.sha256_file!(paths.data_file) {
		Ok(sha) => Ok(sha)
		Err(NotFound) => Err(NotFound)
		Err(err) => return Err(Fail.new(Environment, "cannot read ${paths.data_file}: ${Str.inspect(err)}"))
	}
	fate = ToolManage.entry_fate({ old, have })
	updated = ToolsJson.drop({ path: paths.tools_file, text, key: still.key })?
	(gone, removed, kept) = match fate {
		Remove => ([paths.entry, paths.data_file], [paths.entry, paths.data_file], [])
		Gone => ([paths.data_file], [paths.data_file], [])
		Keep => ([paths.data_file], [paths.data_file], [paths.entry])
	}
	for result in fx.delete!(gone) {
		match result {
			Ok(_) | Err(NotFound) => {}
			Err(err) => return Err(Fail.new(Environment, "cannot delete a file of ${tool.key}: ${Str.inspect(err)}"))
		}
	}
	SetupIo.write_file!(fx, paths.tools_file, updated)?
	Ok({ tool, removed, kept })
}

# Step 7: the warning for a kept entry, the answer, the envelope with `--json`.
print! : Fx, Args, Done => {}
print! = |fx, args, done| {
	for path in done.kept {
		fx.err!("${ToolManage.kept_warning(path)}\n")
	}
	shown = Common.shown_fx(fx, args)
	shown.out!(ToolManage.remove_report(done.tool))
	if args.json {
		fx.out!(Out.json_ok({ command: args.typed, data: ToolManage.remove_data(done) }))
	}
}
