import Answer
import Args
import BinRecord
import Common
import Compiler
import Del
import DelFlow
import Fail
import Fx
import Help
import Item
import Link
import Manage
import Mode
import Out
import Prompt
import Roots
import Setup
import SetupIo
import TalonRemove
import TalonUpdate
import Temp
import Text
import ToolBuild
import ToolInstall
import ToolManage
import ToolsJson
import Trash

## The command `tln tool remove talon [--dry-run] [--remove-tools | --keep-all]` (slice 051, CLI 6.5 "Remove Talon": R-S5, R-RM1 to R-RM10, R-NI10, R-NR3, R-ST4, R-ST6, R-ST10, R-ST11, R-CC6, R-CC10). Direct style over `Fx` (TESTING.md 2.2 part C): `TalonRemove` decides,
## this module orders the calls. `Run.run!` calls `remove!` for `["tool", "remove"]` when `TalonRemove.is_target(args)`, else `ToolManageFlow.remove!`. The calls, in order (the L2 cases `tool/rm1-default` to `rm4-stops` and the L3 cases `tools/rm1-remove-talon`, `tools/rm2-remove-all` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `ToolManage.read(args)`, then `TalonRemove.read(args)`. A failure is printed with `Common.failed!` (no `Fx` call). | R-CM16, R-FL12 |
## | 2 | `env_all!`, `Roots.from_env`, `platform!`, `Setup.bin_dir`, one `read_files!` of `tools.json` (the tools and the entry `talon`, `TalonUpdate.current` for the version), one `list_dirs!` with 2 dirs: `<cache>/toolchains`, then the bin dir. | R-T4, R-IS6 |
## | 3 | One `read_files!` of the `.talon.json` of each compiler, in the order of the ids (no call for no compiler), for the compat ids and the links. | R-RM9, R-RM6 |
## | 4 | One `tree_info!` with `TalonRemove.asks`, then `TalonRemove.parts`: the 4 groups with their sizes. | R-RM4, R-NR2 |
## | 5 | `--dry-run`: the outcome `DryRun` with the choice of the flag (option 1 with no flag). No prompt, no more call. | R-RM4 |
## | 6 | `Mode.from_env` and `Prompt.ask!` with `TalonRemove.prompt` (the flag of `Plan.flag`, `yes`, `quiet`). `Prompt.ask!` calls `tty!` when the mode is `NeedsTty` and `ask!` for a person. With no person the answer is option 1 and the answer line goes to stderr (R-NM6). Option 4: the outcome `Cancelled`, exit 0, no more call. | R-NI10, R-RM3, R-NR3 |
## | 7 | The checks, before the first change: `sha256_file!` of the file `tln` of the data bin dir, then `SetupIo.have_of!` for the entries `tln` and `roc` of the bin dir (one `sha256_file!` for each entry that is there), `ToolManage.entry_fate` for each. Option 2: for each tool `sha256_file!` of its file and `have_of!` for its entry, `entry_fate`. | R-ST11, R-ST6 |
## | 8 | Compilers (options 1 and 2): for each compiler id in byte order, then each Zig: `Fx.locked!` (`Wait`) on `Roots.item(Toolchain(id))` (`Zig(v)`) and in it `Trash.move!` (`random!`, `rename!` to the trash name, one `delete!` of the trash dir and the compat dir). | R-RM9, R-CC10 |
## | 9 | `Fx.locked!` on `tools.json` (`Wait`, R-CC6): `read_files!` again. Option 2: Linux and macOS: one `delete!` of the entry and the file of each tool whose entry is Talon's (only the file when the entry is gone or not Talon's), then `tools.json`: the tool files first, the manifest last. Windows (slice 050d, R-ST10): one `DelFlow.rename_away!` (one `random!`) of the same files (`Del.removed`: a tool with no file is not renamed), then one `delete!` of `tools.json` alone. Options 1 and 3: `write_atomic!` of `tools.json` with no `talon` entry (`ToolsJson.drop`), when it had one. | R-RM7, R-RM8, R-CC6, R-ST6 |
## | 10 | Option 2: the `PATH` entry. Linux and macOS: one `read_files!` of the 3 profiles (`Setup.profiles`), then one `write_atomic!` with the profiles that had the marker line (`Setup.profile_strip`). Windows: one `exec!` of `Setup.windows_path` with `Remove`. | R-RM8, R-ST4, R-HF11 |
## | 11 | Talon data (options 1 and 2): one `delete!` of `<cache>/talon`, `config.toml`, `share.json`. | R-RM10 |
## | 12 | Talon, last. Linux and macOS: `delete!` of the entry `roc` (when it is Talon's), `rename!` of `roc.old` to `roc` (`TalonRemove.restores`), then `delete!` of the entry `tln` (when it is Talon's) and the file `tln` of the data bin dir, which is the last path. Windows: one `random!`, `rename!` of each file to its `.del` name (`TalonUpdate.del_moves`: `roc.exe`, `tln.exe`, then the data file), `rename!` of `roc.old.exe` to `roc.exe`, then `spawn_detached!` of `TalonRemove.cleanup_command` with the `.del` files of the tools (step 9) first, then these. | R-RM5, R-RM6, R-ST10 |
## | 13 | The warnings on stderr, the lines on stdout (`--quiet` hides them, `--json` moves them to stderr), with `--json` the envelope with `TalonRemove.data`. | R-OUT2, R-J1 to R-J4 |
## Part 051b (this module): the command code (the order of the removal, the prompt, the checks, `unix!`). `windows!` (part 051c, with `RealFx.spawn_detached!`) does the steps 10 to 12 for Windows. `unix!` does them for Linux and macOS.
TalonRemoveFlow :: [].{

	## `tln tool remove talon`.
	remove! : Fx, Args => I32
	remove! = |fx, args| match run!(fx, args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(done) => {
			print!(fx, args, done)
			0
		}
	}
}

# What the run found out before the first change (steps 2 to 4).
Scene : {
	env : List((Str, Str)),
	roots : Roots,
	os : Setup.Os,
	bin : Str,
	tools_file : Str,
	tools : List(ToolsJson.Tool),
	records : List((Str, Str)),
	version : Str,
	listed : List({ name : Str, is_dir : Bool }),
	ids : List(Str),
	zigs : List(Str),
	metas : List(Manage.Read),
	asks : List(TalonRemove.Ask),
	parts : List(TalonRemove.Part),
}

Fate : [Remove, Gone, Keep]

# The checks of step 7: `old` is true when `roc.old` is in the bin dir. The fate of each bin dir entry (R-ST6, R-ST11). A tool row has the sha256 of its data file (`old`, slice 050d: `NotFound` when the file is not there).
Check : { old : Bool, tln : Fate, roc : Fate, tools : List({ key : Str, file : Str, old : Try(Str, [NotFound]), fate : Fate }) }

# The choice and the checks: what the last steps need.
Plan : { choice : TalonRemove.Choice, check : Check }

# What the steps 10 to 12 did.
Tail : { back : Try({ from : Str, to : Str }, [None]), path : List([Profile(Str), UserPath(Str)]), stuck : List(Str) }

# Steps 1 to 12.
run! : Fx, Args => Try(TalonRemove.Done, Fail)
run! = |fx, args| {
	_ = ToolManage.read(args)?
	plan = TalonRemove.read(args)?
	scene = scene!(fx)?
	base : TalonRemove.Done
	base = { outcome: Removed, version: scene.version, choice: Default, parts: scene.parts, stays: [], back: Err(None), path: [], kept: [], stuck: [] }
	if plan.dry_run {
		Ok({ ..base, outcome: DryRun, choice: flag_choice(plan.flag) })
	} else {
		prompt = TalonRemove.prompt({ version: scene.version, parts: scene.parts })
		mode = Mode.from_env({ env: Dict.from_list(scene.env), json: args.json })
		asked = Prompt.ask!(fx, prompt, { mode, yes: args.yes, quiet: args.quiet, flag: plan.flag })?
		match TalonRemove.choice_of(asked.answer) {
			Err(Cancel) => Ok({ ..base, outcome: Cancelled })
			Ok(choice) => carry_out!(fx, scene, choice, base)
		}
	}
}

# The choice of the answer flag (option 1 with no flag), for a dry run (D5).
flag_choice : Try(Answer, [NoFlag]) -> TalonRemove.Choice
flag_choice = |flag| match flag {
	Ok(answer) => match TalonRemove.choice_of(answer) {
		Ok(choice) => choice
		Err(Cancel) => Default
	}
	Err(NoFlag) => Default
}

# Steps 2 to 4: the machine, `tools.json`, the listings, the `.talon.json` of each compiler, the sizes.
scene! : Fx => Try(Scene, Fail)
scene! = |fx| {
	env = fx.env_all!()
	roots = Roots.from_env(env)?
	machine = fx.platform!()
	bin = Setup.bin_dir({ os: machine.os, env })?
	tools_file = Roots.item(roots, Item.ToolsJson)
	text = SetupIo.read_text!(fx, tools_file)?
	tools = ToolsJson.manifest({ path: tools_file, text })?
	talon = ToolsJson.talon({ path: tools_file, text })?
	# Slice 078b (R-ST11 (2)): the record of the bin dir entries, from the text of step 2 (no new call).
	records = BinRecord.read({ path: tools_file, text })?
	toolchains = Text.join(roots.cache, "toolchains")
	(in_toolchains, listed) = match fx.list_dirs!([toolchains, bin]) {
		[first, second] => (entries_of(first, toolchains)?, SetupIo.entries_of(second, bin)?)
		_ => return Err(Fail.new(Internal, "list_dirs! gave no result"))
	}
	ids = Compiler.installed(in_toolchains)
	zigs = TalonRemove.zig_versions(in_toolchains)
	metas = if ids.is_empty() [] else fx.read_files!(ids.map(|id| Roots.item(roots, Item.ToolchainMeta(id))))
	asks = TalonRemove.asks({
		roots,
		file: TalonRemove.file(machine.os),
		tools: tools.map(|tool| ToolInstall.file_name({ os: machine.os, key: tool.key })),
		ids,
		compats: metas.keep_oks(|meta| Manage.compat_of(meta)),
		zigs,
	})
	keys = tools.map(|tool| tool.key)
	parts = TalonRemove.parts({ asks, infos: fx.tree_info!(asks.map(|ask| ask.path)), tools: keys, ids, zigs })
	version = TalonUpdate.current({ entry: talon, running: Help.version })
	Ok({ env, roots, os: machine.os, bin, tools_file, tools, records, version, listed, ids, zigs, metas, asks, parts })
}

# A listing of `toolchains/`. A dir that is not there is empty.
entries_of : Try(List({ name : Str, is_dir : Bool, mtime : U64 }), [NotFound, Denied, Other(Str)]), Str -> Try(List({ name : Str, is_dir : Bool, mtime : U64 }), Fail)
entries_of = |result, dir| match result {
	Ok(found) => Ok(found)
	Err(NotFound) => Ok([])
	Err(Denied) => Err(Fail.new(Environment, "cannot read ${dir}: permission denied"))
	Err(Other(text)) => Err(Fail.new(Environment, "cannot read ${dir}: ${text}"))
}

# Steps 7 to 12 (after the answer): the checks first, then the changes in the order of D1, Talon last.
carry_out! : Fx, Scene, TalonRemove.Choice, TalonRemove.Done => Try(TalonRemove.Done, Fail)
carry_out! = |fx, scene, choice, base| {
	check = checks!(fx, scene, choice)?
	plan = { choice, check }
	if TalonRemove.removes({ choice, group: Compilers }) remove_compilers!(fx, scene)?
	renamed = update_tools!(fx, scene, plan)?
	tail = match scene.os {
		Windows => windows!(fx, scene, plan, renamed)?
		_ => unix!(fx, scene, plan)?
	}
	kept_tools = if choice == WithTools check.tools.keep_if(|tool| tool.fate == Keep).map(|tool| Text.join(scene.bin, tool.file)) else []
	kept = [(check.tln, entry_of(scene, TalonRemove.file(scene.os))), (check.roc, entry_of(scene, roc_file(scene.os)))].keep_if(|(fate, _)| fate == Keep).map(|(_, path)| path)
	Ok({
		..base,
		choice,
		stays: if choice == TalonOnly stays_of(scene, tail.back) else [],
		back: tail.back,
		path: tail.path,
		kept: kept.concat(kept_tools),
		stuck: tail.stuck,
	})
}

entry_of : Scene, Str -> Str
entry_of = |scene, name| Text.join(scene.bin, name)

roc_file : Setup.Os -> Str
roc_file = |os| if os == Windows "roc.exe" else "roc"

data_file : Scene, Str -> Str
data_file = |scene, name| Text.join(Roots.item(scene.roots, Item.Bin), name)

# Step 7: the sha256 of the data file `tln`, the fate of the entries `tln` and `roc`, and for option 2 of each tool.
checks! : Fx, Scene, TalonRemove.Choice => Try(Check, Fail)
checks! = |fx, scene, choice| {
	tln = TalonRemove.file(scene.os)
	old_sha = sha_of!(fx, data_file(scene, tln))?
	tln_fate = fate_of!(fx, scene, old_sha, tln)
	roc_fate = fate_of!(fx, scene, old_sha, roc_file(scene.os))
	var $tools = []
	if choice == WithTools {
		for tool in scene.tools {
			file = ToolInstall.file_name({ os: scene.os, key: tool.key })
			tool_sha = sha_of!(fx, data_file(scene, file))?
			$tools = $tools.append({ key: tool.key, file, old: tool_sha, fate: fate_of!(fx, scene, tool_sha, file) })
		}
	}
	old = scene.listed.any(|entry| entry.name == Setup.old_roc(scene.os))
	Ok({ old, tln: tln_fate, roc: roc_fate, tools: $tools })
}

sha_of! : Fx, Str => Try(Try(Str, [NotFound]), Fail)
sha_of! = |fx, path| match fx.sha256_file!(path) {
	Ok(sha) => Ok(Ok(sha))
	Err(NotFound) => Ok(Err(NotFound))
	Err(err) => Err(Fail.new(Environment, "cannot read ${path}: ${Str.inspect(err)}"))
}

fate_of! : Fx, Scene, Try(Str, [NotFound]), Str => Fate
fate_of! = |fx, scene, old, name| ToolManage.fate_bin({ old, have: SetupIo.have_of!(fx, scene.bin, scene.listed, name), recorded: ToolBuild.recorded(scene.records, name) })

# Step 8: each compiler in byte order, then each Zig, each in its own lock (R-CC10). The compat dir goes with its compiler (D7).
remove_compilers! : Fx, Scene => Try({}, Fail)
remove_compilers! = |fx, scene| {
	compilers = scene.ids.map2(scene.metas, |id, meta| { item: Roots.item(scene.roots, Item.Toolchain(id)), compat: Manage.compat_of(meta) })
	zigs = scene.zigs.map(|version| { item: Roots.item(scene.roots, Item.Zig(version)), compat: Err(None) })
	for one in compilers.concat(zigs) {
		fx.locked!(one.item, || Trash.move!(fx, scene.roots, one))?
	}
	Ok({})
}

# Step 9, in the lock of `tools.json` (R-CC6). Options 1 and 3: `tools.json` without the entry `talon`, when it had one. Option 2: the tool files, then `tools.json` (the manifest last). The result is the `.del` paths of the tool files (Windows, option 2: slice 050d, R-ST10), which the cleanup of `windows_last!` deletes. Linux and macOS: no path.
update_tools! : Fx, Scene, Plan => Try(List(Str), Fail)
update_tools! = |fx, scene, plan| fx.locked!(
	scene.tools_file,
	|| {
		text = SetupIo.read_text!(fx, scene.tools_file)?
		if plan.choice == WithTools {
			tools_removed!(fx, scene, plan.check)
		} else {
			updated = ToolsJson.drop({ path: scene.tools_file, text, key: "talon" })?
			match text {
				Ok(old) if old != updated => SetupIo.write_file!(fx, scene.tools_file, updated)?
				_ => {}
			}
			Ok([])
		}
	},
)

# Option 2: Windows renames the tool files to `.del` names (entry first, then the data file, for each tool), then deletes `tools.json` alone. Linux and macOS delete the tool files, then `tools.json`.
tools_removed! : Fx, Scene, Check => Try(List(Str), Fail)
tools_removed! = |fx, scene, check| match scene.os {
	Windows => {
		files = check.tools.join_map(|tool| Del.removed({ data_file: data_file(scene, tool.file), entry: entry_of(scene, tool.file), old: tool.old, fate: tool.fate }))
		renamed = DelFlow.rename_away!(fx, { os: scene.os, files })?
		delete_all!(fx, [scene.tools_file])?
		Ok(renamed)
	}
	_ => {
		tool_paths = check.tools.map(
			|tool| match tool.fate {
				Remove => [entry_of(scene, tool.file), data_file(scene, tool.file)]
				_ => [data_file(scene, tool.file)]
			},
		)
		delete_all!(fx, tool_paths.join().append(scene.tools_file))?
		Ok([])
	}
}

# One `delete!`. A path that is not there is no failure (D13). Another error stops the run (exit 18).
delete_all! : Fx, List(Str) => Try({}, Fail)
delete_all! = |fx, paths| {
	if paths.is_empty() return Ok({})
	for each in paths.map2(fx.delete!(paths), |path, result| { path, result }) {
		match each.result {
			Ok(_) | Err(NotFound) => {}
			Err(err) => return Err(Fail.new(Environment, "cannot delete ${each.path}: ${Str.inspect(err)}"))
		}
	}
	Ok({})
}

# Steps 10 to 12 for Linux and macOS.
unix! : Fx, Scene, Plan => Try(Tail, Fail)
unix! = |fx, scene, plan| {
	path = if plan.choice == WithTools strip_profiles!(fx, scene)? else []
	if TalonRemove.removes({ choice: plan.choice, group: Data }) delete_all!(fx, data_paths(scene))?
	back = last!(fx, scene, plan.check)?
	Ok({ back, path, stuck: [] })
}

data_paths : Scene -> List(Str)
data_paths = |scene| scene.asks.keep_if(|ask| ask.group == Data).map(|ask| ask.path)

# Step 10 (option 2): the line of `tln setup` goes from each profile that has it. One read, one write.
strip_profiles! : Fx, Scene => Try(List([Profile(Str), UserPath(Str)]), Fail)
strip_profiles! = |fx, scene| {
	home = match scene.env.find_first(|(name, _)| name == "HOME") {
		Ok((_, value)) => value
		Err(_) => ""
	}
	files = Setup.profiles({ home: home })
	var $writes = []
	for each in files.map2(fx.read_files!(files), |path, read| { path, read }) {
		match each.read {
			Ok(text) => match Setup.profile_strip(text) {
				Write(content) => {
					$writes = $writes.append({ path: each.path, content })
				}
				Keep => {}
			}
			Err(NotFound) => {}
			Err(err) => return Err(Fail.new(Environment, "cannot read ${each.path}: ${Str.inspect(err)}"))
		}
	}
	if $writes.is_empty() return Ok([])
	match fx.write_atomic!($writes) {
		Ok(_) => Ok($writes.map(|file| Profile(file.path)))
		Err(failure) => Err(Fail.new(Environment, "cannot write ${failure.path}: ${Str.inspect(failure.err)}"))
	}
}

# Step 12, Talon last: the entry `roc`, `roc.old` back to `roc`, then the entry `tln` and the file `tln` of the data bin dir (the last path).
last! : Fx, Scene, Check => Try(Try({ from : Str, to : Str }, [None]), Fail)
last! = |fx, scene, check| {
	roc = entry_of(scene, roc_file(scene.os))
	if check.roc == Remove delete_all!(fx, [roc])?
	back = move_back!(fx, scene, check)?
	tln = TalonRemove.file(scene.os)
	entry = if check.tln == Remove [entry_of(scene, tln)] else []
	delete_all!(fx, entry.append(data_file(scene, tln)))?
	Ok(back)
}

# R-RM6: `roc.old` goes back to `roc` when `TalonRemove.restores` says so. The result is the move.
move_back! : Fx, Scene, Check => Try(Try({ from : Str, to : Str }, [None]), Fail)
move_back! = |fx, scene, check| {
	roc = entry_of(scene, roc_file(scene.os))
	old = entry_of(scene, Setup.old_roc(scene.os))
	if TalonRemove.restores({ old: check.old, roc: check.roc }) {
		match fx.rename!({ from: old, to: roc }) {
			Ok(_) => Ok(Ok({ from: old, to: roc }))
			Err(err) => Err(Fail.new(Environment, "cannot move ${old} back to ${roc}: ${Str.inspect(err)}"))
		}
	} else {
		Ok(Err(None))
	}
}

# Steps 10 to 12 for Windows: the user `Path` (option 2, D12: a failure stops the run), the Talon data, then Talon (R-RM5, R-ST10).
windows! : Fx, Scene, Plan, List(Str) => Try(Tail, Fail)
windows! = |fx, scene, plan, renamed| {
	path = if plan.choice == WithTools [UserPath(user_path!(fx, scene)?)] else []
	if TalonRemove.removes({ choice: plan.choice, group: Data }) delete_all!(fx, data_paths(scene))?
	last = windows_last!(fx, scene, plan.check, renamed)?
	Ok({ back: last.back, path, stuck: last.stuck })
}

# R-HF11: one `exec!` of `powershell` takes the bin dir out of the user `Path`. It returns the dir.
user_path! : Fx, Scene => Try(Str, Fail)
user_path! = |fx, scene| match fx.exec!(Setup.windows_path({ dir: scene.bin, op: Remove })) {
	Ok(0) => Ok(scene.bin)
	Ok(code) => Err(Fail.new(Environment, "powershell could not change the user Path: exit code ${code.to_str()}"))
	Err(NotStarted(text)) => Err(Fail.new(Environment, "cannot start powershell: ${text}"))
}

# R-RM5, R-RM6, R-ST10: `tool_files` are the `.del` paths that `update_tools!` made (option 2, the tools first). Each file of Talon is renamed to `<name>.<hex>.del` (`roc.exe`, `tln.exe`, then the data file), `roc.old.exe` goes back to `roc.exe`, and one detached `cmd.exe` deletes the `.del` files when Talon has ended.
# When it does not start, the renamed files stay (`stuck`).
windows_last! : Fx, Scene, Check, List(Str) => Try({ back : Try({ from : Str, to : Str }, [None]), stuck : List(Str) }, Fail)
windows_last! = |fx, scene, check, tool_files| {
	roc = entry_of(scene, roc_file(scene.os))
	tln = TalonRemove.file(scene.os)
	files = [(check.roc, roc), (check.tln, entry_of(scene, tln))].keep_if(|(fate, _)| fate == Remove).map(|(_, file)| file).append(data_file(scene, tln))
	hex = Temp.hex(fx.random!())
	var $renamed = tool_files
	for move in TalonUpdate.del_moves({ os: scene.os, hex, files }) {
		match fx.rename!(move) {
			Ok(_) => {
				$renamed = $renamed.append(move.to)
			}
			Err(NotFound) => {}
			Err(err) => return Err(Fail.new(Environment, "cannot rename ${move.from}: ${Str.inspect(err)}"))
		}
	}
	back = move_back!(fx, scene, check)?
	stuck = match fx.spawn_detached!(TalonRemove.cleanup_command($renamed)) {
		Ok(_) => []
		Err(NotStarted(_)) => $renamed
	}
	Ok({ back, stuck })
}

# R-RM6: each compiler that stays (option 3) with the path where it is after the move of `roc.old`.
stays_of : Scene, Try({ from : Str, to : Str }, [None]) -> List({ id : Str, path : Str })
stays_of = |scene, moved| scene.ids.map2(
	scene.metas,
	|id, meta| {
		meta_path = Roots.item(scene.roots, Item.ToolchainMeta(id))
		link = if id.starts_with("link-") Link.target({ id, path: meta_path, text: meta }).map_err(|_| None) else Err(None)
		{ id, path: TalonRemove.kept_path({ id, roc: Roots.item(scene.roots, Item.ToolchainRoc(id)), link, moved }) }
	},
)

# Step 13: the warnings on stderr, the lines on stdout (`--quiet` hides them, `--json` moves them to stderr), with `--json` the envelope.
print! : Fx, Args, TalonRemove.Done => {}
print! = |fx, args, done| {
	for line in TalonRemove.warnings(done) {
		fx.err!(line)
	}
	shown = Common.shown_fx(fx, args)
	for line in TalonRemove.report(done) {
		shown.out!(line)
	}
	if args.json {
		fx.out!(Out.json_ok({ command: args.typed, data: TalonRemove.data(done) }))
	}
}
