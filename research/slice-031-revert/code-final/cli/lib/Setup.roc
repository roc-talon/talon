import Args
import Clock
import Common
import Consent
import Fail
import Fx
import JsonDoc
import Launch
import Link
import Mode
import Out
import Prompt
import Roots
import SetupIo
import SetupText
import TalonFile
import Temp
import Text

## `tln setup` (slice 027, CLI 6.7: R-CM18, R-ST1 to R-ST15, R-NI13, R-NI14, R-LY8, R-LY9; Design 6.2: R-HF7, R-HF11). Part A (pure decisions) is here, and part C (the command code) is `Setup.run!`.
## The contract is in the doc comments (tables). Texts and `data` fields are a proposal (R-OUT2, TW24): `docs/slices/027-setup.md`, section 6.
##
## What `tln setup` connects (Linux and macOS: the Windows flow is the Windows CI job, see the slice file, section 9). `<bin>` is the bin dir `<HOME>/.local/bin` (R-LY8), `<data bin>` is `<data>/bin` (R-T3):
##
## | Entry in `<bin>` | Points to | Rule |
## | --- | --- | --- |
## | `tln` | `<data bin>/tln` | R-ST13 |
## | `roc` (the launcher: `tln` runs as the proxy when its program name is `roc`, R-ST8) | `<data bin>/tln` | R-ST14 |
## | `<tool>` for each tool in `tools.json` | `<data bin>/<tool>` | R-ST15 |
##
## The calls of `Setup.run!`, in order (the L2 cases `setup/st1-flow` and `setup/st2-copy-fallback` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `Setup.read(args)`. A failure is printed with `Common.failed!` (no `Fx` call). | R-CM18, R-FL12 |
## | 2 | `env_all!`, `Roots.from_env`, `platform!`. `Setup.bin_dir`. `Setup.names` needs the tools of step 3. | R-LY8 |
## | 3 | `read_files!` of `tools.json` (a missing file is no tool). `Setup.tool_names`. | R-ST1, R-ST11 |
## | 4 | One `list_dirs!` call with 2 dirs: `<data bin>`, then `<bin>` (a missing dir is empty). | R-ST7 |
## | 5 | `sha256_file!` of each source that the listing of `<data bin>` has, once for each distinct source, in the order of `Setup.names`. Then `sha256_file!` of each entry that the listing of `<bin>` has as a file, in the order of `Setup.names`. `Setup.judge` for each entry. The entry `tln` with no source is a failure of kind `Environment` (question Q2). | R-ST11, R-ST6 |
## | 6 | `path_roc!`. `Setup.shadow`: the warning of R-ST3. A foreign `tln` or tool entry gets a warning, nothing is changed (R-ST6). | R-ST3, R-ST6 |
## | 7 | The `PATH` step, only when `Setup.on_path` is false: `read_files!` of the target (`GITHUB_PATH`, else the profile of `SHELL`), `Setup.github_edit` or `Setup.profile_edit`. `Keep` is done. `Write` needs the prompt of step 9. A shell that is not bash, zsh or fish has no target. | R-ST4 |
## | 8 | The completions, only when `SHELL` is bash, zsh or fish: `read_files!` of `Setup.completion_path`, then `Setup.completion` (`Keep` when the file has the same text). | R-ST5 |
## | 9 | The prompts, before any write and before any lock (R-CC3 point 5): R-NI13 when the `roc` entry is foreign (`Consent.setup_replace_roc`, the flag `--replace-roc` is `Ok(Yes)`), then R-NI14 when step 7 has a `Write` (`Consent.setup_modify_path`, the flag `--no-modify-path` is `Ok(No)`). The answer `No` to R-NI13 prints the note of R-ST2 on stderr (section 6 of the slice file). | R-NI13, R-NI14, R-ST2 |
## | 10 | The writes. `make_dirs!` of `<bin>` when an entry is made. `Yes` for R-NI13: `rename!` of `<bin>/roc` to `<bin>/roc.old`, then `link-system` (step 11). Each entry to make, in the order of `Setup.names`: `random!`, `hard_link!` to the temp name `<bin>/<entry>.<hex>.tmp`, else `copy_file!` to it, then `rename!` to `<bin>/<entry>` (R-CC1, R-ST7). The `PATH` target: `write_atomic!`. The completion: `write_atomic!`. | R-ST7, R-ST2, R-ST4, R-ST5 |
## | 11 | `link-system` (R-ST2, R-LK4): `Clock.now!`, then `Fx.locked!` on the item `<cache>/toolchains/link-system`, in the lock `Launch.toolchains!` (one `list_dirs!`). An item that exists is kept. Else `random!`, `write_atomic!` of `<item>.<hex>.tmp/.talon.json` (`Link.meta` with the path `<bin>/roc.old`), `rename!` of the temp dir. | R-ST2, R-LK4 |
## | 12 | The output: the lines of the slice file section 6 on stdout (`Common.shown_fx`), or with `--json` the envelope with `data` on stdout and the lines on stderr. | R-OUT2, R-J3 |
Setup :: [].{

	## The flags of one `setup` line (R-NI13: `--replace-roc`, R-NI14: `--no-modify-path`). `--yes`, `--json` and `--quiet` are in `Args`.
	Plan : { replace_roc : Bool, no_modify_path : Bool }

	## The operating system of `Fx.platform!`.
	Os : [Linux, Macos, Windows, Other(Str)]

	## One bin dir entry: its name in `<bin>` and the name of its file in `<data bin>`.
	Entry : { entry : Str, source : Str }

	## The shells that Talon knows (R-ST4).
	Shell : [Bash, Zsh, Fish]

	## R-CM18, R-NI13, R-NI14: the flags and operands of `setup`. `setup` has no operand: a word gives kind `Usage` (exit 2), `tln setup takes no operand, got <n>`.
	read : Args -> Try(Setup.Plan, Fail)
	read = |args| match args.operands {
		[] => Ok({ replace_roc: has_flag(args, "--replace-roc"), no_modify_path: has_flag(args, "--no-modify-path") })
		many => Err(Fail.new(Usage, "tln setup takes no operand, got ${many.len().to_str()}"))
	}

	## R-ST1, R-ST13, R-ST14, R-ST15: the entries of the bin dir, in this order: `tln` (the file `tln`), `roc` (the file `tln`), then one entry for each tool in the order of `tools` (the file of the same name). On Windows each
	## name has `.exe` (`tln.exe`, `roc.exe`, `<tool>.exe`). The tool `talon` has no entry of its own (its binary is `tln`, which the first two entries cover). A tool that is named `tln` or `roc`, and a name that repeats, is left out.
	names : { os : Setup.Os, tools : List(Str) } -> List(Setup.Entry)
	names = |facts| {
		ext = if facts.os == Windows ".exe" else ""
		tools = facts.tools.fold(
			[],
			|kept, tool| if ["talon", "tln", "roc"].contains(tool) or kept.contains(tool) kept else kept.append(tool),
		)
		["tln", "roc"].concat(tools).map(|name| { entry: "${name}${ext}", source: "${if name == "roc" "tln" else name}${ext}" })
	}

	## R-ST2: the name of the old `roc` in the bin dir: `roc.old` (`roc.old.exe` on Windows).
	old_roc : Setup.Os -> Str
	old_roc = |os| if os == Windows "roc.old.exe" else "roc.old"

	## R-LY8: the bin dir. Linux and macOS: `<HOME>/.local/bin`. Windows: `<USERPROFILE>\.local\bin`. A variable that is not set or is empty is kind `Environment` (exit 18): `HOME is not set`, `USERPROFILE is not set`.
	bin_dir : { os : Setup.Os, env : List((Str, Str)) } -> Try(Str, Fail)
	bin_dir = |facts| {
		value_of = |name| match facts.env.find_first(|(key, _)| key == name) {
			Ok((_, value)) if !value.is_empty() => Ok(value)
			_ => Err(Unset)
		}
		match facts.os {
			Windows => match value_of("USERPROFILE") {
				Ok(home) => Ok("${SetupText.strip_end(home, "\\")}\\.local\\bin")
				Err(Unset) => Err(Fail.new(Environment, "USERPROFILE is not set"))
			}
			_ => match value_of("HOME") {
				Ok(home) => Ok(Text.join(home, ".local/bin"))
				Err(Unset) => Err(Fail.new(Environment, "HOME is not set"))
			}
		}
	}

	## R-ST11, R-ST6, R-ST7: what to do with one entry. `source` is the file in `<data bin>`: `Missing`, or `Sha(sha256)`. `have` is the entry in `<bin>`: `Absent`, `Dir` (a directory), `Unreadable` (a file that `sha256_file!` could not read),
	## or `Sha(sha256)`. The entry is Talon's when its sha256 equals the one of its source (R-ST11).
	##
	## | `source` | `have` | Result |
	## | --- | --- | --- |
	## | `Missing` | any | `NoSource` |
	## | `Sha(s)` | `Absent` | `Make` |
	## | `Sha(s)` | `Sha(s)` (the same) | `Keep`: Talon's, up to date, nothing is written (R-ST12) |
	## | `Sha(s)` | `Sha(other)`, `Dir`, `Unreadable` | `Foreign`: Talon never overwrites it (R-ST6). For `roc` it is the prompt of R-NI13. |
	judge : { source : [Missing, Sha(Str)], have : [Absent, Dir, Unreadable, Sha(Str)] } -> [NoSource, Make, Keep, Foreign]
	judge = |facts| match (facts.source, facts.have) {
		(Missing, _) => NoSource
		(Sha(_), Absent) => Make
		(Sha(want), Sha(have)) => if want == have Keep else Foreign
		(Sha(_), _) => Foreign
	}

	## R-ST4: is `dir` one of the parts of `path` (the value of `PATH`, parts split by `:`, an empty part is left out, a `/` at the end of a part or of `dir` does not count)?
	on_path : { path : Str, dir : Str } -> Bool
	on_path = |facts| SetupText.parts_of(facts.path).contains(SetupText.clean_part(facts.dir))

	## R-ST3: a `roc` that comes before the bin dir on `PATH`. `found` is the path of each `roc` file on `PATH`, in the order of `PATH` (`Fx.path_roc!`: the path of a file is `<part of PATH>/roc`). The result is the first file whose directory is not `dir` and is a
	## part of `PATH` before the first part that is `dir`. `Err(None)` when `dir` is not a part of `PATH` (nothing comes before it: question Q3), or when no such file is found.
	shadow : { path : Str, dir : Str, found : List(Str) } -> Try(Str, [None])
	shadow = |facts| {
		dir = SetupText.clean_part(facts.dir)
		parts = SetupText.parts_of(facts.path)
		match parts.find_first_index(|part| part == dir) {
			Err(_) => Err(None)
			Ok(at) => {
				before = parts.sublist({ start: 0, len: at })
				facts.found.find_first(|file| before.contains(SetupText.clean_part(Text.dir_of(file)))).map_err(|_| None)
			}
		}
	}

	## R-ST4: the shell from the value of `SHELL` (its last path part): `bash`, `zsh` or `fish`. Any other value, and the empty text, is `Err(Unknown)` (question Q5).
	shell_of : Str -> Try(Setup.Shell, [Unknown])
	shell_of = |value| match Text.last_segment(value) {
		"bash" => Ok(Bash)
		"zsh" => Ok(Zsh)
		"fish" => Ok(Fish)
		_ => Err(Unknown)
	}

	## R-ST4: the profile of the shell: `<home>/.bashrc`, `<home>/.zshrc`, `<home>/.config/fish/conf.d/talon.fish`.
	profile : { home : Str, shell : Setup.Shell } -> Str
	profile = |facts| match facts.shell {
		Bash => Text.join(facts.home, ".bashrc")
		Zsh => Text.join(facts.home, ".zshrc")
		Fish => Text.join(facts.home, ".config/fish/conf.d/talon.fish")
	}

	## R-ST4: the one line that puts `dir` on `PATH`. It ends with the marker comment `# talon: added by tln setup`, so `tln tool rm talon` finds it (CLI 6.5). The form is a proposal (TW24):
	##
	## | Shell | Line |
	## | --- | --- |
	## | bash, zsh | `export PATH="<dir>:$PATH" # talon: added by tln setup` |
	## | fish | `fish_add_path "<dir>" # talon: added by tln setup` |
	path_line : { shell : Setup.Shell, dir : Str } -> Str
	path_line = |facts| match facts.shell {
		Fish => "fish_add_path \"${facts.dir}\" ${marker}"
		_ => "export PATH=\"${facts.dir}:\$PATH\" ${marker}"
	}

	## R-ST4, R-ST12: the new text of the profile. `existing` is the file (`Err(NotFound)`: no file). A line with the marker is in the file already: `Keep` (nothing is written, also when the line has another dir). Else `Write`: the old text, a line end when
	## the old text does not end with one, `path_line`, and a line end. No file: `path_line` and a line end.
	profile_edit : { shell : Setup.Shell, dir : Str, existing : Try(Str, [NotFound]) } -> [Keep, Write(Str)]
	profile_edit = |facts| {
		line = Setup.path_line({ shell: facts.shell, dir: facts.dir })
		match facts.existing {
			Err(NotFound) => Write("${line}\n")
			Ok(text) => if text.contains(marker) Keep else Write(SetupText.appended(text, line))
		}
	}

	## R-ST4: the new text of the file that `GITHUB_PATH` names. A line equal to `dir` is in it already: `Keep`. Else `Write`: the old text, a line end when it lacks one, `dir`, and a line end. No file: `dir` and a line end.
	github_edit : { dir : Str, existing : Try(Str, [NotFound]) } -> [Keep, Write(Str)]
	github_edit = |facts| match facts.existing {
		Err(NotFound) => Write("${facts.dir}\n")
		Ok(text) => if text.split_on("\n").contains(facts.dir) Keep else Write(SetupText.appended(text, facts.dir))
	}

	## R-ST5: the file of the completions of the shell in the user dir (a proposal, question Q6): bash `<home>/.local/share/bash-completion/completions/tln`, zsh `<home>/.local/share/zsh/site-functions/_tln`, fish `<home>/.config/fish/completions/tln.fish`.
	completion_path : { home : Str, shell : Setup.Shell } -> Str
	completion_path = |facts| match facts.shell {
		Bash => Text.join(facts.home, ".local/share/bash-completion/completions/tln")
		Zsh => Text.join(facts.home, ".local/share/zsh/site-functions/_tln")
		Fish => Text.join(facts.home, ".config/fish/completions/tln.fish")
	}

	## R-ST5: the text of the completion file of a shell (a proposal, question Q6). It completes the command words (the 21 commands of CLI 1) and the subcommands of `roc`, `tool` and `cache`. The same text each time (R-ST12: no write when the file has it).
	completion : Setup.Shell -> Str
	completion = |shell| SetupText.completion(shell)

	## R-HF11, R-ST4, R-LY9: the child that adds the bin dir to the user `Path` of Windows (`Add`), or removes exactly that entry (`Remove`, for `tln tool rm talon`). `argv` is `powershell -NoProfile -NonInteractive -Command <script>`. The dir is
	## not in the script: it is the variable `TALON_BIN_DIR` of `env`, so the script needs no quoting. The script reads the `Path` value of `HKCU\Environment` with `GetValue('Path', '', 'DoNotExpandEnvironmentNames')`, writes it back as a
	## `REG_EXPAND_SZ` (`ExpandString`) and sends `WM_SETTINGCHANGE`. It never uses `setx`. The script is the same for each dir.
	windows_path : { dir : Str, op : [Add, Remove] } -> { argv : List(Str), env : List((Str, Str)) }
	windows_path = |facts| {
		argv: ["powershell", "-NoProfile", "-NonInteractive", "-Command", SetupText.windows_script(facts.op)],
		env: [("TALON_BIN_DIR", facts.dir)],
	}

	## R-ST1, R-ST11, R-TF1, R-TF2: the names of the tools in the text of `tools.json` (question Q1: the form is a proposal). `path` is the file, for the messages. The file is read with `TalonFile.open` (`format` 1, `can_recreate` false).
	## The names are the keys of the top-level object `tools`, in the order of the text. No `tools` field: no tool.
	##
	## | Text | Result |
	## | --- | --- |
	## | `{"format":1,"tools":{"foo":{...},"bar":{...}}}` | `Ok(["foo", "bar"])` |
	## | `{"format":1}` | `Ok([])` |
	## | Not JSON, an array, no integer `format` | Kind `Input` (exit 19): `<path>: the content does not parse` |
	## | A `format` above 1 | Kind `Input`: `<path>: format <n> is newer than this tln (format 1). Run: tln tool update talon` |
	## | `tools` is not an object | Kind `Input`: `<path>: tools is not an object` |
	tool_names : { path : Str, text : Str } -> Try(List(Str), Fail)
	tool_names = |facts| match TalonFile.open({ path: facts.path, text: facts.text, newest: 1, can_recreate: Bool.False })? {
		Use(file) => match file.fields.find_first(|(key, _)| key == "tools") {
			Ok((_, JsonDoc.Obj(tools))) => Ok(tools.map(|(name, _)| name))
			Ok(_) => Err(Fail.new(Input, "${facts.path}: tools is not an object"))
			Err(_) => Ok([])
		}
		_ => Ok([])
	}

	## Steps 1 to 12.
	run! : Fx, Args => I32
	run! = |fx, args| match Setup.read(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(plan) => match flow!(fx, args, plan) {
			Ok(done) => {
				print!(fx, args, done)
				0
			}
			Err(fail) => Common.failed!(fx, args, fail)
		}
	}
}

# The end of the line that Talon adds to a profile (CLI 6.5 finds the line with it).
marker = "# talon: added by tln setup"

# One entry with the verdict of `Setup.judge` (step 5).
Row : { entry : Setup.Entry, verdict : [NoSource, Make, Keep, Foreign] }

# What steps 2 to 5 found.
Facts : { env : List((Str, Str)), os : Setup.Os, roots : Roots, bin : Str, data_bin : Str, home : Str, rows : List(Row), bin_names : List(Str) }

# Steps 7 and 8: what is still to write. `Pending` has the target and the new text.
PathPlan : [OnPath, Present, NoShell({ line : Str }), Pending({ target : Str, content : Str, line : Str })]

CompletionPlan : [Present, None, Pending({ path : Str, content : Str })]

# The result of the prompts (step 9).
Answers : { replace : Bool, modify : Bool }

# Steps 2 to 11.
flow! : Fx, Args, Setup.Plan => Try(SetupText.Done, Fail)
flow! = |fx, args, plan| {
	facts = gather!(fx)?
	warn!(fx, facts)
	path = path_step!(fx, facts)?
	completion = completion_step!(fx, facts)?
	answers = ask!(fx, args, plan, { facts, path })?
	forms = write_entries!(fx, facts, answers.replace)?
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
	Ok({
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
	})
}

roc_path : Facts -> Str
roc_path = |facts| Text.join(facts.bin, exe_name(facts.os, "roc"))

old_path : Facts -> Str
old_path = |facts| Text.join(facts.bin, Setup.old_roc(facts.os))

exe_name : Setup.Os, Str -> Str
exe_name = |os, name| if os == Windows "${name}.exe" else name

has_flag : Args, Str -> Bool
has_flag = |args, flag| args.options.any(|(name, _)| name == flag)

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
	tools = match SetupIo.read_text!(fx, tools_file)? {
		Ok(text) => Setup.tool_names({ path: tools_file, text })?
		Err(NotFound) => []
	}
	names = Setup.names({ os: machine.os, tools })
	listed = SetupIo.listings!(fx, { data_bin, bin })?
	rows = judged!(fx, { names, bin, data_bin, listed })?
	match rows.first() {
		Ok(first) => if first.verdict == NoSource {
			return Err(Fail.new(Environment, "${Text.join(data_bin, first.entry.source)} is missing. Install Talon with its install script."))
		}
		Err(_) => {}
	}
	Ok({ env, os: machine.os, roots, bin, data_bin, home: SetupText.var_of(env, "HOME"), rows, bin_names: listed.bin.map(|e| e.name) })
}

# Step 5: the sha256 of each source (once for each distinct one), then of each entry in `<bin>` that is a file. `Setup.judge` for each entry.
judged! : Fx, { names : List(Setup.Entry), bin : Str, data_bin : Str, listed : SetupIo.Listed } => Try(List(Row), Fail)
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
		$rows = $rows.append({ entry, verdict: Setup.judge({ source, have }) })
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
	todo = facts.rows.keep_if(|row| row.verdict == Make or (replace and row.entry.entry == roc))
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
print! : Fx, Args, SetupText.Done => {}
print! = |fx, args, done| {
	shown = Common.shown_fx(fx, args)
	for line in SetupText.report(done) {
		shown.out!(line)
	}
	if args.json {
		fx.out!(Out.json_ok({ command: args.typed, data: SetupText.data(done) }))
	}
}
