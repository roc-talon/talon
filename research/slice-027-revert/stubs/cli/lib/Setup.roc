import Args
import Fail
import Fx

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
	read = |_x| crash "todo"

	## R-ST1, R-ST13, R-ST14, R-ST15: the entries of the bin dir, in this order: `tln` (the file `tln`), `roc` (the file `tln`), then one entry for each tool in the order of `tools` (the file of the same name). On Windows each
	## name has `.exe` (`tln.exe`, `roc.exe`, `<tool>.exe`). The tool `talon` has no entry of its own (its binary is `tln`, which the first two entries cover). A tool that is named `tln` or `roc`, and a name that repeats, is left out.
	names : { os : Setup.Os, tools : List(Str) } -> List(Setup.Entry)
	names = |_x| crash "todo"

	## R-ST2: the name of the old `roc` in the bin dir: `roc.old` (`roc.old.exe` on Windows).
	old_roc : Setup.Os -> Str
	old_roc = |_x| crash "todo"

	## R-LY8: the bin dir. Linux and macOS: `<HOME>/.local/bin`. Windows: `<USERPROFILE>\.local\bin`. A variable that is not set or is empty is kind `Environment` (exit 18): `HOME is not set`, `USERPROFILE is not set`.
	bin_dir : { os : Setup.Os, env : List((Str, Str)) } -> Try(Str, Fail)
	bin_dir = |_x| crash "todo"

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
	judge = |_x| crash "todo"

	## R-ST4: is `dir` one of the parts of `path` (the value of `PATH`, parts split by `:`, an empty part is left out, a `/` at the end of a part or of `dir` does not count)?
	on_path : { path : Str, dir : Str } -> Bool
	on_path = |_x| crash "todo"

	## R-ST3: a `roc` that comes before the bin dir on `PATH`. `found` is the path of each `roc` file on `PATH`, in the order of `PATH` (`Fx.path_roc!`: the path of a file is `<part of PATH>/roc`). The result is the first file whose directory is not `dir` and is a
	## part of `PATH` before the first part that is `dir`. `Err(None)` when `dir` is not a part of `PATH` (nothing comes before it: question Q3), or when no such file is found.
	shadow : { path : Str, dir : Str, found : List(Str) } -> Try(Str, [None])
	shadow = |_x| crash "todo"

	## R-ST4: the shell from the value of `SHELL` (its last path part): `bash`, `zsh` or `fish`. Any other value, and the empty text, is `Err(Unknown)` (question Q5).
	shell_of : Str -> Try(Setup.Shell, [Unknown])
	shell_of = |_x| crash "todo"

	## R-ST4: the profile of the shell: `<home>/.bashrc`, `<home>/.zshrc`, `<home>/.config/fish/conf.d/talon.fish`.
	profile : { home : Str, shell : Setup.Shell } -> Str
	profile = |_x| crash "todo"

	## R-ST4: the one line that puts `dir` on `PATH`. It ends with the marker comment `# talon: added by tln setup`, so `tln tool rm talon` finds it (CLI 6.5). The form is a proposal (TW24):
	##
	## | Shell | Line |
	## | --- | --- |
	## | bash, zsh | `export PATH="<dir>:$PATH" # talon: added by tln setup` |
	## | fish | `fish_add_path "<dir>" # talon: added by tln setup` |
	path_line : { shell : Setup.Shell, dir : Str } -> Str
	path_line = |_x| crash "todo"

	## R-ST4, R-ST12: the new text of the profile. `existing` is the file (`Err(NotFound)`: no file). A line with the marker is in the file already: `Keep` (nothing is written, also when the line has another dir). Else `Write`: the old text, a line end when
	## the old text does not end with one, `path_line`, and a line end. No file: `path_line` and a line end.
	profile_edit : { shell : Setup.Shell, dir : Str, existing : Try(Str, [NotFound]) } -> [Keep, Write(Str)]
	profile_edit = |_x| crash "todo"

	## R-ST4: the new text of the file that `GITHUB_PATH` names. A line equal to `dir` is in it already: `Keep`. Else `Write`: the old text, a line end when it lacks one, `dir`, and a line end. No file: `dir` and a line end.
	github_edit : { dir : Str, existing : Try(Str, [NotFound]) } -> [Keep, Write(Str)]
	github_edit = |_x| crash "todo"

	## R-ST5: the file of the completions of the shell in the user dir (a proposal, question Q6): bash `<home>/.local/share/bash-completion/completions/tln`, zsh `<home>/.local/share/zsh/site-functions/_tln`, fish `<home>/.config/fish/completions/tln.fish`.
	completion_path : { home : Str, shell : Setup.Shell } -> Str
	completion_path = |_x| crash "todo"

	## R-ST5: the text of the completion file of a shell (a proposal, question Q6). It completes the command words (the 21 commands of CLI 1) and the subcommands of `roc`, `tool` and `cache`. The same text each time (R-ST12: no write when the file has it).
	completion : Setup.Shell -> Str
	completion = |_x| crash "todo"

	## R-HF11, R-ST4, R-LY9: the child that adds the bin dir to the user `Path` of Windows (`Add`), or removes exactly that entry (`Remove`, for `tln tool rm talon`). `argv` is `powershell -NoProfile -NonInteractive -Command <script>`. The dir is
	## not in the script: it is the variable `TALON_BIN_DIR` of `env`, so the script needs no quoting. The script reads the `Path` value of `HKCU\Environment` with `GetValue('Path', '', 'DoNotExpandEnvironmentNames')`, writes it back as a
	## `REG_EXPAND_SZ` (`ExpandString`) and sends `WM_SETTINGCHANGE`. It never uses `setx`. The script is the same for each dir.
	windows_path : { dir : Str, op : [Add, Remove] } -> { argv : List(Str), env : List((Str, Str)) }
	windows_path = |_x| crash "todo"

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
	tool_names = |_x| crash "todo"

	## Steps 1 to 12.
	run! : Fx, Args => I32
	run! = |_fx, _args| crash "todo"
}
