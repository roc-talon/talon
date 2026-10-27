import Args
import BinRecord
import BuildSkip
import Clock
import Common
import Compiler
import ConfigToml
import Consent
import Fail
import Fx
import Help
import Launch
import Link
import Mode
import Out
import Prompt
import RocInstall
import Roots
import Setup
import SetupIo
import SetupText
import TalonUpdate
import Temp
import Text
import ToolsJson

## The command code (part C) of `tln setup` (slice 027, CLI 6.7). The pure decisions are in `Setup`, the texts are in `SetupText`, the effects of the files are in `SetupIo`.
##
## The calls of `SetupFlow.run!`, in order (the L2 cases `setup/st1-flow` and `setup/st2-copy-fallback` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `Setup.read(args)`. A failure is printed with `Common.failed!` (no `Fx` call). | R-CM18, R-FL12 |
## | 2 | `env_all!`, `Roots.from_env`, `platform!`. `Setup.bin_dir`. `Setup.names` needs the tools of step 3. | R-LY8 |
## | 3 | `read_files!` of `tools.json` (a missing file is no tool). `Setup.tool_names`. `ToolsJson.talon` on the same text: no entry is missing, an entry that is not readable is a failure (exit 19, R-TF3). | R-ST1, R-ST11, R-IS6 |
## | 4 | One `list_dirs!` call with 2 dirs: `<data bin>`, then `<bin>` (a missing dir is empty). | R-ST7 |
## | 5 | `sha256_file!` of each source that the listing of `<data bin>` has, once for each distinct source, in the order of `Setup.names`. Then `sha256_file!` of each entry that the listing of `<bin>` has as a file, in the order of `Setup.names`. `Setup.judge` for each entry. The entry `tln` with no source is a failure of kind `Environment` (question Q2). | R-ST11, R-ST6 |
## | 6 | `path_roc!`. `Setup.shadow`: the warning of R-ST3. A foreign `tln` or tool entry gets a warning, nothing is changed (R-ST6). | R-ST3, R-ST6 |
## | 7 | The `PATH` step, only when `Setup.on_path` is false: `read_files!` of the target (`GITHUB_PATH`, else the profile of `SHELL`), `Setup.github_edit` or `Setup.profile_edit`. `Keep` is done. `Write` needs the prompt of step 9. A shell that is not bash, zsh or fish has no target. | R-ST4 |
## | 8 | The completions, only when `SHELL` is bash, zsh or fish: `read_files!` of `Setup.completion_path`, then `Setup.completion` (`Keep` when the file has the same text). | R-ST5 |
## | 9 | The prompts, before any write and before any lock (R-CC3 point 5): R-NI13 when the `roc` entry is foreign (`Consent.setup_replace_roc`, the flag `--replace-roc` is `Ok(Yes)`), then R-NI14 when step 7 has a `Write` (`Consent.setup_modify_path`, the flag `--no-modify-path` is `Ok(No)`). The answer `No` to R-NI13 prints the note of R-ST2 on stderr (section 6 of the slice file). | R-NI13, R-NI14, R-ST2 |
## | 10a | The entry `talon` (slices 052 and 063), first write of step 10, only when `BuildSkip.target` knows the machine. First `TalonUpdate.setup_entry` decides on the facts of step 3 (no clock needed): `Keep` (the entry has the version and the sha256 of the running `tln`) gives no call and no line. `Put` (missing, or it differs): `Clock.now!`, then `Fx.locked!` on `Roots.item(ToolsJson)`: `read_files!` again, `setup_entry` again on that text (the sha256 is the one of step 5), one `write_atomic!` of `ToolsJson.put_talon`. | R-IS6, R-S4, R-CC1, R-CC6 |
## | 10b | Slice 078 (R-T4, R-ST11, R-ST9), after the last entry and the move of `roc`, when at least one entry was made: `Fx.locked!` on `tools.json`: `read_files!`, `BinRecord.record_all` (the name of each made entry, the sha256 of its source), one `write_atomic!` only when the text changes. | R-T4, R-ST11, R-CC6 |
## | 10 | The writes. `make_dirs!` of `<bin>` when an entry is made. `Yes` for R-NI13: `rename!` of `<bin>/roc` to `<bin>/roc.old`, then `link-system` (step 11). Each entry to make, in the order of `Setup.names`: `random!`, `hard_link!` to the temp name `<bin>/<entry>.<hex>.tmp`, else `copy_file!` to it, then `rename!` to `<bin>/<entry>` (R-CC1, R-ST7). The `PATH` target: `write_atomic!`. The completion: `write_atomic!`. | R-ST7, R-ST2, R-ST4, R-ST5 |
## | 11 | `link-system` (R-ST2, R-LK4): `Clock.now!`, then `Fx.locked!` on the item `<cache>/toolchains/link-system`, in the lock `Launch.toolchains!` (one `list_dirs!`). An item that exists is kept. Else `random!`, `write_atomic!` of `<item>.<hex>.tmp/.talon.json` (`Link.meta` with the path `<bin>/roc.old`), `rename!` of the temp dir. | R-ST2, R-LK4 |
## | 12 | The output: first the line `TalonUpdate.recorded_text` when step 10a wrote the entry, then the lines of the slice file section 6 on stdout (`Common.shown_fx`), or with `--json` the envelope with `data` on stdout and the lines on stderr. | R-OUT2, R-J3 |
SetupFlow :: [].{

	## Steps 1 to 12.
	run! : Fx, Args => I32
	run! = |fx, args| match Setup.read(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(plan) => match flow!(fx, args, plan) {
			Ok(result) => {
				print!(fx, args, result)
				0
			}
			Err(fail) => Common.failed!(fx, args, fail)
		}
	}
}

# One entry with the verdict of `Setup.judge` (step 5).
Row : { entry : Setup.Entry, verdict : [NoSource, Make, Keep, Repair, Foreign], source_sha : Str }

# What steps 2 to 5 found.
Facts : { env : List((Str, Str)), os : Setup.Os, roots : Roots, bin : Str, data_bin : Str, home : Str, rows : List(Row), bin_names : List(Str), talon : Try(ToolsJson.Talon, [None]), target : Try(Str, [Unknown]) }

# Steps 7 and 8: what is still to write. `Pending` has the target and the new text.
PathPlan : [OnPath, Present, NoShell({ line : Str }), Pending({ target : Str, content : Str, line : Str })]

CompletionPlan : [Present, None, Pending({ path : Str, content : Str })]

# The result of the prompts (step 9).
Answers : { replace : Bool, modify : Bool }

# Steps 2 to 11.
flow! : Fx, Args, Setup.Plan => Try({ done : SetupText.Done, lead : List(Str) }, Fail)
flow! = |fx, args, plan| {
	facts = gather!(fx)?
	warn!(fx, facts)
	path = path_step!(fx, facts)?
	completion = completion_step!(fx, facts)?
	answers = ask!(fx, args, plan, { facts, path })?
	lead = record_talon!(fx, facts)?
	forms = write_entries!(fx, facts, answers.replace)?
	record_bin!(fx, facts, forms)?
	if answers.modify {
		match path {
			Pending(pending) => write_path!(fx, facts, pending)?
			_ => {}
		}
	}
	match completion {
		Pending(pending) => SetupIo.write_file!(fx, pending.path, pending.content)?
		_ => {}
	}
	chosen = default_step!(fx, args, facts)?
	done = {
		bin: facts.bin,
		roc: roc_path(facts),
		old: old_path(facts),
		entries: facts.rows.map(|row| { name: row.entry.entry, act: act_of(row, forms) }),
		moved: answers.replace,
		path: match path {
			OnPath => OnPath
			Present => Present
			NoShell(shell) => NoShell({ line: shell.line })
			Pending(pending) => if answers.modify Added({ target: pending.target }) else Declined({ target: pending.target, line: pending.line })
		},
		completion: match completion {
			Pending(pending) => Written(pending.path)
			Present => Present
			None => None
		},
		default: chosen,
	}
	Ok({ done, lead })
}

# Step 13 (R-ST16, slice 072a), after the writes: the first default compiler. The calls, in order (the L2 case `setup/st8-first-default` fixes them):
#
# | # | Does | Rule |
# | --- | --- | --- |
# | 13a | `RocInstall.read_config!`: one `read_files!` of `config.toml` (a missing file is the empty text). `default-roc` is set: `Kept(id)`, no more call, no line. | R-ST16 |
# | 13a2 | Not set (slice 080, R-ST16, R-SO24): `Launch.toolchains!` (one `list_dirs!`) and `Compiler.newest_installed`. `Ok(id)`: `RocInstall.first_default!`, the result is `Repaired(id)`. No download. `Err(None)`: step 13b. | R-ST16 |
# | 13b | Not set and nothing installed: `RocInstall.latest!` with `args.offline` (the calls of its doc). `Unread(why)`: one line on stderr, `SetupText.unread_note(why)` (no `--quiet` hides it), the result is `Unread(why)`, setup does not fail. | R-ST16, R-CV1 |
# | 13c | `Ok(id)`: `RocInstall.first_default!` (the lock of `config.toml`, two reads, `write_atomic!`, unlock: as `tln roc install`). The result is `Set(id)`. No download, no `spawn_all!`, no toolchains dir. | R-ST16, R-SO15 |
default_step! : Fx, Args, Facts => Try(SetupText.Default, Fail)
default_step! = |fx, args, facts| {
	config = RocInstall.read_config!(fx, facts.roots)?
	match config.default_roc {
		Ok(id) => Ok(Kept(id))
		Err(Unset) => match Compiler.newest_installed({ installed: Launch.toolchains!(fx, facts.roots), times: [] }) {
			Ok(id) => {
				_ = RocInstall.first_default!(fx, facts.roots, id)?
				Ok(Repaired(id))
			}
			Err(None) => latest_default!(fx, args, facts, config)
		}
	}
}

# Step 13b and 13c: nothing is installed, so the latest compiler of the channel is the first default (no download).
latest_default! : Fx, Args, Facts, ConfigToml.Config => Try(SetupText.Default, Fail)
latest_default! = |fx, args, facts, config| match RocInstall.latest!(fx, { env: facts.env, offline: args.offline, config })? {
	Err(Unread(why)) => {
		fx.err!(SetupText.unread_note(why))
		Ok(Unread(why))
	}
	Ok(latest) => {
		# R-C16 (slice 084): the note of a young compiler that only a pattern kept, before the default is written.
		RocInstall.print_note!(fx, args.quiet, latest.note)
		match RocInstall.first_default!(fx, facts.roots, latest.id)? {
			Set => Ok(Set(latest.id))
			Kept => Ok(Kept(latest.id))
		}
	}
}

# Step 10b (slice 078): the record of the entries that were made, in the lock of `tools.json`. The file is read again (R-CC6). A missing file or the same text gives no write.
record_bin! : Fx, Facts, List((Str, [HardLink, Copy])) => Try({}, Fail)
record_bin! = |fx, facts, forms| {
	made = facts.rows.keep_if(|row| forms.any(|(name, _)| name == row.entry.entry)).map(|row| { entry: row.entry.entry, sha256: row.source_sha })
	if made.is_empty() return Ok({})
	path = Roots.item(facts.roots, ToolsJson)
	fx.locked!(
		path,
		|| {
			text = SetupIo.read_text!(fx, path)?
			after = BinRecord.record_all({ path, text, made })?
			if text == Ok(after) or text == Err(NotFound) Ok({}) else SetupIo.write_file!(fx, path, after)
		},
	)
}

# Step 10a (R-IS6, R-S4): the entry `talon`, when it is missing or differs from the running `tln`. The result is the line of the output (none when the entry stays). A machine that `BuildSkip.target` does not know gets no entry (D11, and a differing entry stays: slice 063 Q-1).
record_talon! : Fx, Facts => Try(List(Str), Fail)
record_talon! = |fx, facts| match facts.target {
	Ok(target) => match decide_talon(facts, { have: facts.talon, target, now: 0 }) {
		Keep => Ok([])
		Put(_) => {
			now = Clock.now!(fx, facts.env)?
			fx.locked!(Roots.item(facts.roots, ToolsJson), || put_talon!(fx, facts, { target, now }))
		}
	}
	Err(_) => Ok([])
}

# The decision of `TalonUpdate.setup_entry` for the entry `have` (the sha256 is the one of step 5).
decide_talon : Facts, { have : Try(ToolsJson.Talon, [None]), target : Str, now : U64 } -> [Keep, Put(ToolsJson.Talon)]
decide_talon = |facts, run| {
	sha256 = match facts.rows.first() {
		Ok(row) => row.source_sha
		Err(_) => ""
	}
	TalonUpdate.setup_entry({ have: run.have, version: Help.version, os: facts.os, target: run.target, sha256, now: run.now })
}

# In the lock: the file is read again (R-CC6) and the entry is decided on that text.
put_talon! : Fx, Facts, { target : Str, now : U64 } => Try(List(Str), Fail)
put_talon! = |fx, facts, run| {
	path = Roots.item(facts.roots, ToolsJson)
	text = SetupIo.read_text!(fx, path)?
	have = ToolsJson.talon({ path, text })?
	match decide_talon(facts, { have, target: run.target, now: run.now }) {
		Keep => Ok([])
		Put(talon) => {
			SetupIo.write_file!(fx, path, ToolsJson.put_talon({ path, text, talon })?)?
			Ok([TalonUpdate.recorded_text({ version: Help.version, path })])
		}
	}
}

roc_path : Facts -> Str
roc_path = |facts| Text.join(facts.bin, exe_name(facts.os, "roc"))

old_path : Facts -> Str
old_path = |facts| Text.join(facts.bin, Setup.old_roc(facts.os))

exe_name : Setup.Os, Str -> Str
exe_name = |os, name| if os == Windows "${name}.exe" else name

# What happened to the entry of `row`: made (it is in `forms`), kept, or skipped.
act_of : Row, List((Str, [HardLink, Copy])) -> SetupText.Act
act_of = |row, forms| match forms.find_first(|(name, _)| name == row.entry.entry) {
	Ok((_, form)) => Made(form)
	Err(_) => if row.verdict == Keep Kept else Skipped
}

# Steps 2 to 5: the facts of the run. A missing `tln` file is a failure (question Q2).
gather! : Fx => Try(Facts, Fail)
gather! = |fx| {
	env = fx.env_all!()
	machine = fx.platform!()
	roots = Roots.from_env(env)?
	bin = Setup.bin_dir({ os: machine.os, env })?
	data_bin = Roots.item(roots, Bin)
	tools_file = Roots.item(roots, ToolsJson)
	text = SetupIo.read_text!(fx, tools_file)?
	tools = match text {
		Ok(content) => Setup.tool_names({ path: tools_file, text: content })?
		Err(NotFound) => []
	}
	talon = ToolsJson.talon({ path: tools_file, text })?
	names = Setup.names({ os: machine.os, tools })
	listed = SetupIo.listings!(fx, { data_bin, bin })?
	recorded = BinRecord.read({ path: tools_file, text })?
	rows = judged!(fx, { names, bin, data_bin, listed, recorded })?
	match rows.first() {
		Ok(first) => if first.verdict == NoSource {
			return Err(Fail.new(Environment, "${Text.join(data_bin, first.entry.source)} is missing. Install Talon with its install script."))
		}
		Err(_) => {}
	}
	Ok({ env, os: machine.os, roots, bin, data_bin, home: SetupText.var_of(env, "HOME"), rows, bin_names: listed.bin.map(|e| e.name), talon, target: BuildSkip.target(machine) })
}

# Step 5: the sha256 of each source (once for each distinct one), then of each entry in `<bin>` that is a file. `Setup.judge` for each entry.
judged! : Fx, { names : List(Setup.Entry), bin : Str, data_bin : Str, listed : SetupIo.Listed, recorded : List((Str, Str)) } => Try(List(Row), Fail)
judged! = |fx, run| {
	var $shas = []
	for entry in run.names {
		if run.listed.data.contains(entry.source) and !$shas.any(|(name, _)| name == entry.source) {
			path = Text.join(run.data_bin, entry.source)
			match fx.sha256_file!(path) {
				Ok(sha) => {
					$shas = $shas.append((entry.source, sha))
				}
				Err(NotFound) => {}
				Err(err) => return Err(Fail.new(Environment, "cannot read ${path}: ${Str.inspect(err)}"))
			}
		}
	}
	var $rows = []
	for entry in run.names {
		source = match $shas.find_first(|(name, _)| name == entry.source) {
			Ok((_, sha)) => Sha(sha)
			Err(_) => Missing
		}
		have = SetupIo.have_of!(fx, run.bin, run.listed.bin, entry.entry)
		source_sha = match source {
			Sha(sha) => sha
			Missing => ""
		}
		recorded = match run.recorded.find_first(|(name, _)| name == entry.entry.drop_suffix(".exe")) {
			Ok((_, sha)) => Ok(sha)
			Err(_) => Err(None)
		}
		$rows = $rows.append({ entry, verdict: Setup.judge_bin({ source, recorded, have }), source_sha })
	}
	Ok($rows)
}

# Step 6: the warnings on stderr (R-ST6, R-ST3, D13). `--quiet` does not hide them (D11). The foreign `roc` is the prompt of step 9.
warn! : Fx, Facts => {}
warn! = |fx, facts| {
	found = fx.path_roc!().found.map(|file| file.path)
	for row in facts.rows {
		match row.verdict {
			Foreign => {
				if row.entry.entry != exe_name(facts.os, "roc") {
					fx.err!("warning: ${Text.join(facts.bin, row.entry.entry)} is not a Talon file, so tln setup left it as it is.\n")
				}
			}
			NoSource => fx.err!("warning: ${Text.join(facts.data_bin, row.entry.source)} is missing, so tln setup made no entry for ${row.entry.entry}.\n")
			_ => {}
		}
	}
	if facts.os != Windows {
		match Setup.shadow({ path: SetupText.var_of(facts.env, "PATH"), dir: facts.bin, found }) {
			Ok(file) => fx.err!("warning: ${file} comes before ${facts.bin} on PATH, so it runs in place of the roc launcher. Talon changes nothing there.\n")
			Err(None) => {}
		}
	}
}

# Step 7: the `PATH` step (R-ST4). Windows has no file to read: the user `Path` is changed by a child.
path_step! : Fx, Facts => Try(PathPlan, Fail)
path_step! = |fx, facts| {
	if facts.os == Windows return Ok(Pending({ target: "the user Path", content: "", line: "" }))
	if Setup.on_path({ path: SetupText.var_of(facts.env, "PATH"), dir: facts.bin }) return Ok(OnPath)
	github = SetupText.var_of(facts.env, "GITHUB_PATH")
	if !github.is_empty() {
		existing = SetupIo.read_text!(fx, github)?
		return match Setup.github_edit({ dir: facts.bin, existing }) {
			Keep => Ok(Present)
			Write(content) => Ok(Pending({ target: github, content, line: facts.bin }))
		}
	}
	match Setup.shell_of(SetupText.var_of(facts.env, "SHELL")) {
		Err(Unknown) => Ok(NoShell({ line: Setup.path_line({ shell: Bash, dir: facts.bin }) }))
		Ok(shell) => {
			target = Setup.profile({ home: facts.home, shell })
			existing = SetupIo.read_text!(fx, target)?
			match Setup.profile_edit({ shell, dir: facts.bin, existing }) {
				Keep => Ok(Present)
				Write(content) => Ok(Pending({ target, content, line: Setup.path_line({ shell, dir: facts.bin }) }))
			}
		}
	}
}

# Step 8: the completion file of the shell (R-ST5).
completion_step! : Fx, Facts => Try(CompletionPlan, Fail)
completion_step! = |fx, facts| {
	if facts.os == Windows return Ok(None)
	match Setup.shell_of(SetupText.var_of(facts.env, "SHELL")) {
		Err(Unknown) => Ok(None)
		Ok(shell) => {
			path = Setup.completion_path({ home: facts.home, shell })
			want = Setup.completion(shell)
			match SetupIo.read_text!(fx, path)? {
				Ok(text) if text == want => Ok(Present)
				_ => Ok(Pending({ path, content: want }))
			}
		}
	}
}

# Step 9: the prompts. R-NI13 when `roc` is foreign, then R-NI14 when the `PATH` step has a text to write. Both come before the first write (D5).
ask! : Fx, Args, Setup.Plan, { facts : Facts, path : PathPlan } => Try(Answers, Fail)
ask! = |fx, args, plan, run| {
	facts = run.facts
	mode = Mode.from_env({ env: Dict.from_list(facts.env), json: args.json })
	roc_foreign = facts.rows.any(|row| row.entry.entry == exe_name(facts.os, "roc") and row.verdict == Foreign)
	roc_answer = if roc_foreign {
		prompt = Consent.setup_replace_roc({ path: roc_path(facts), old: old_path(facts) })
		flag = if plan.replace_roc Ok(Yes) else Err(NoFlag)
		Prompt.ask!(fx, prompt, { mode, yes: args.yes, quiet: args.quiet, flag })?
	} else {
		{ answer: No, mode }
	}
	replace = roc_foreign and roc_answer.answer == Yes
	if roc_foreign and !replace {
		fx.err!("note: ${roc_path(facts)} is not a Talon file, so no roc launcher was installed. To replace it, run: tln setup --replace-roc\n")
	}
	if replace and facts.bin_names.contains(Setup.old_roc(facts.os)) {
		return Err(Fail.new(Conflict, "${old_path(facts)} exists. Talon does not replace it. Move it away, then run tln setup --replace-roc again."))
	}
	modify = match run.path {
		Pending(pending) => {
			prompt = Consent.setup_modify_path({ dir: facts.bin, target: pending.target })
			flag = if plan.no_modify_path Ok(No) else Err(NoFlag)
			Prompt.ask!(fx, prompt, { mode: roc_answer.mode, yes: args.yes, quiet: args.quiet, flag })?.answer == Yes
		}
		_ => Bool.False
	}
	Ok({ replace, modify })
}

# Step 10: the entries. `make_dirs!` of `<bin>` when an entry is made. A replaced `roc` moves first (D15). Each entry is made in the order of `Setup.names`.
write_entries! : Fx, Facts, Bool => Try(List((Str, [HardLink, Copy])), Fail)
write_entries! = |fx, facts, replace| {
	roc = exe_name(facts.os, "roc")
	todo = facts.rows.keep_if(|row| row.verdict == Make or row.verdict == Repair or (replace and row.entry.entry == roc))
	if !todo.is_empty() {
		match fx.make_dirs!([facts.bin]) {
			Ok(_) => {}
			Err(err) => return Err(Fail.new(Environment, "cannot make ${facts.bin}: ${Str.inspect(err)}"))
		}
	}
	if replace {
		move_roc!(fx, facts)?
	}
	var $forms = []
	for row in todo {
		form = make_entry!(fx, facts, row.entry)?
		$forms = $forms.append((row.entry.entry, form))
	}
	Ok($forms)
}

# R-ST2: `roc` goes to `roc.old`, then it is the compiler `link-system`.
move_roc! : Fx, Facts => Try({}, Fail)
move_roc! = |fx, facts| {
	match fx.rename!({ from: roc_path(facts), to: old_path(facts) }) {
		Ok(_) => {}
		Err(err) => return Err(Fail.new(Environment, "cannot move ${roc_path(facts)} to ${old_path(facts)}: ${Str.inspect(err)}"))
	}
	now = Clock.now!(fx, facts.env)?
	item = Roots.item(facts.roots, Toolchain("link-system"))
	fx.locked!(item, || link_item!(fx, facts, { item, now }))
}

# R-ST2, R-LK4, D6: in the lock, `link-system` is made when it is not there. One that exists stays as it is.
link_item! : Fx, Facts, { item : Str, now : U64 } => Try({}, Fail)
link_item! = |fx, facts, run| {
	if Launch.toolchains!(fx, facts.roots).contains("link-system") {
		return Ok({})
	}
	temp = Temp.name({ target: run.item, hex: Temp.hex(fx.random!()) })
	meta = Link.meta({ id: "link-system", kind: Link, path: old_path(facts), now: run.now })
	match fx.write_atomic!([{ path: Text.join(temp, ".talon.json"), content: meta }]) {
		Ok(_) => {}
		Err(failure) => return Err(SetupIo.dropped!(fx, temp, "cannot write ${failure.path}: ${Str.inspect(failure.err)}"))
	}
	match fx.rename!({ from: temp, to: run.item }) {
		Ok(_) => Ok({})
		Err(err) => Err(SetupIo.dropped!(fx, temp, "cannot make ${run.item}: ${Str.inspect(err)}"))
	}
}

# R-ST7, R-CC1: a hard link to a temp name, else a copy, then a rename.
make_entry! : Fx, Facts, Setup.Entry => Try([HardLink, Copy], Fail)
make_entry! = |fx, facts, entry| {
	target = Text.join(facts.bin, entry.entry)
	from = Text.join(facts.data_bin, entry.source)
	temp = Temp.name({ target, hex: Temp.hex(fx.random!()) })
	form = match fx.hard_link!({ from, to: temp }) {
		Ok(_) => HardLink
		Err(_) => match fx.copy_file!({ from, to: temp }) {
			Ok(_) => Copy
			Err(err) => return Err(SetupIo.dropped!(fx, temp, "cannot make ${target}: ${Str.inspect(err)}"))
		}
	}
	match fx.rename!({ from: temp, to: target }) {
		Ok(_) => Ok(form)
		Err(err) => Err(SetupIo.dropped!(fx, temp, "cannot make ${target}: ${Str.inspect(err)}"))
	}
}

# The `PATH` change. Windows runs the child of `Setup.windows_path` (R-HF11), other systems write the profile or the file of `GITHUB_PATH`.
write_path! : Fx, Facts, { target : Str, content : Str, line : Str } => Try({}, Fail)
write_path! = |fx, facts, pending| if facts.os == Windows {
	command = Setup.windows_path({ dir: facts.bin, op: Add })
	match fx.exec!({ argv: command.argv, env: command.env }) {
		Ok(code) => if code == 0 Ok({}) else Err(Fail.new(Environment, "the change of the user Path failed (exit code ${code.to_str()})"))
		Err(NotStarted(text)) => Err(Fail.new(Environment, "cannot start powershell: ${text}"))
	}
} else {
	SetupIo.write_file!(fx, pending.target, pending.content)
}

# Step 12: the lines on stdout, or with `--json` the lines on stderr and the envelope on stdout (`--quiet` hides the lines).
print! : Fx, Args, { done : SetupText.Done, lead : List(Str) } => {}
print! = |fx, args, result| {
	done = result.done
	shown = Common.shown_fx(fx, args)
	for line in result.lead {
		shown.out!("${line}\n")
	}
	for line in SetupText.report(done) {
		shown.out!(line)
	}
	if args.json {
		fx.out!(Out.json_ok({ command: args.typed, data: SetupText.data(done) }))
	}
}
