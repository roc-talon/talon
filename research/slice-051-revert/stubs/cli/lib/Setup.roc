import Args
import Fail
import JsonDoc
import SetupText
import TalonFile
import Text

## `tln setup` (slice 027, CLI 6.7: R-CM18, R-ST1 to R-ST15, R-NI13, R-NI14, R-LY8, R-LY9; Design 6.2: R-HF7, R-HF11). Part A (pure decisions) is here, and part C (the command code) is `SetupFlow.run!`.
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

	## R-RM8, R-ST4: the 3 profiles that `profile` can give, one for each shell, for `tln tool remove talon --remove-tools` (the shell of the day of `tln setup` is not known): `<home>/.bashrc`, `<home>/.zshrc`, `<home>/.config/fish/conf.d/talon.fish`.
	profiles : { home : Str } -> List(Str)
	profiles = |_facts| crash "todo: slice 051a"

	## R-RM8, R-ST4: the text of a profile after the lines with the marker (`path_line`) are removed. No line has the marker: `Keep`. Else `Write`: the other lines in their order, each with its line end as before (a file that had only that line is the empty text).
	profile_strip : Str -> [Keep, Write(Str)]
	profile_strip = |_text| crash "todo: slice 051a"

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
}

# The end of the line that Talon adds to a profile (CLI 6.5 finds the line with it).
marker = "# talon: added by tln setup"

has_flag : Args, Str -> Bool
has_flag = |args, flag| args.options.any(|(name, _)| name == flag)
