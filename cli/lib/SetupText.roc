import JsonDoc

## The texts of `tln setup` (slice 027, split from `Setup` to keep each module short): the 3 completion files, the PowerShell script, and the output (the lines and the `--json` data).
## All are pure. The texts are the proposals of `docs/slices/027-setup.md`, section 6 (R-OUT2, TW24). The completion texts are compared byte for byte by the L2 cases.
SetupText :: [].{

	## How a bin dir entry was made.
	Form : [HardLink, Copy]

	## What happened to one entry: `Made`, `Kept` (Talon's file, up to date), `Skipped` (no source file, or a file that Talon did not write).
	Act : [Made(SetupText.Form), Kept, Skipped]

	## The `PATH` step: the bin dir is on `PATH` already, the profile has the marker line, the line was added to `target`, the answer was No (`line` is what the user adds), or the shell is unknown.
	PathResult : [OnPath, Present, Added({ target : Str }), Declined({ target : Str, line : Str }), NoShell({ line : Str })]

	## The completion file: written to the path, the same text was there, or no known shell.
	Completion : [Written(Str), Present, None]

	## Slice 072a (R-ST16): the default compiler step. `Set(id)`: setup wrote `default-roc`. `Kept(id)`: `config.toml` had one, it is not changed. `Unread(why)`: the list of compilers cannot be read (`why` is the text of the failure), setup wrote none.
	## Slice 080 (R-ST16, R-SO24 case 3): `Repaired(id)`: `config.toml` had no `default-roc` and a nightly or a release was installed, so setup writes the newest installed one (no list read, no download).
	Default : [Set(Str), Kept(Str), Repaired(Str), Unread(Str)]

	## What a run did. `roc` and `old` are the full paths of the launcher entry and of `roc.old`.
	Done : {
		bin : Str,
		roc : Str,
		old : Str,
		entries : List({ name : Str, act : SetupText.Act }),
		moved : Bool,
		path : SetupText.PathResult,
		completion : SetupText.Completion,
		default : SetupText.Default,
	}

	## The text of the completion file of a shell (R-ST5, question Q6): the 21 commands and the subcommands of `roc`, `tool` and `cache`.
	completion : [Bash, Zsh, Fish] -> Str
	completion = |shell| match shell {
		Bash => bash_text
		Zsh => zsh_text
		Fish => fish_text
	}

	## R-HF11: the PowerShell script that adds the bin dir (`Add`) to the user `Path` of Windows, or removes exactly that entry (`Remove`). The dir is in `TALON_BIN_DIR`, never in the script.
	windows_script : [Add, Remove] -> Str
	windows_script = |op| {
		change = match op {
			Add => "if (\$parts -notcontains \$dir) { \$parts = @(\$dir) + \$parts }"
			Remove => "\$parts = @(\$parts | Where-Object { \$_ -ne \$dir })"
		}
		Str.join_with(
			[
				"\$dir = \$env:TALON_BIN_DIR",
				"\$key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', \$true)",
				"\$old = \$key.GetValue('Path', '', 'DoNotExpandEnvironmentNames')",
				"\$parts = @(\$old -split ';' | Where-Object { \$_ -ne '' })",
				change,
				"\$key.SetValue('Path', (\$parts -join ';'), [Microsoft.Win32.RegistryValueKind]::ExpandString)",
				"\$key.Close()",
				"Add-Type -Namespace Talon -Name Win32 -MemberDefinition '[DllImport(\"user32.dll\", CharSet = CharSet.Auto)] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint flags, uint timeout, out UIntPtr result);'",
				"\$result = [UIntPtr]::Zero",
				"# WM_SETTINGCHANGE (0x1A) tells the open windows that the environment changed.",
				"[void][Talon.Win32]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]\$result)",
				"",
			],
			"\n",
		)
	}

	## R-OUT2: the lines on stdout, each with a line end. The made entries, the move of `roc`, the `PATH` line, the completion file, and (slice 072a, a proposal, TW24) for `Set(id)` the last line
	## `default compiler: <id> (downloaded when a command needs it)`. `Kept` and `Unread` give no line. No line and no skipped entry: `nothing to do`.
	report : SetupText.Done -> List(Str)
	report = |done| {
		made = done.entries.keep_oks(
			|e| match e.act {
				Made(form) => Ok("made ${done.bin}/${e.name} (${form_text(form)})\n")
				_ => Err(NotMade)
			},
		)
		moved = if done.moved ["moved ${done.roc} to ${done.old}, linked as link-system\n"] else []
		path = match done.path {
			Added({ target }) => ["PATH: added ${done.bin} to ${target}\n"]
			Declined({ target, line }) => ["PATH: not changed. To add ${done.bin}, put this line in ${target}: ${line}\n"]
			NoShell({ line }) => ["PATH: not changed (the shell is not bash, zsh or fish). To add ${done.bin}, put this line in your shell profile: ${line}\n"]
			_ => []
		}
		files = match done.completion {
			Written(file) => ["completions: ${file}\n"]
			_ => []
		}
		chosen = match done.default {
			Set(id) => ["default compiler: ${id} (downloaded when a command needs it)\n"]
			Repaired(id) => ["default compiler: ${id} (the newest installed compiler)\n"]
			_ => []
		}
		lines = made.concat(moved).concat(path).concat(files).concat(chosen)
		skipped = done.entries.any(|e| e.act == Skipped)
		if lines.is_empty() and !skipped ["nothing to do: the entries, the PATH line and the completions are in place\n"] else lines
	}

	## R-J3, R-OUT4: the `data` of `--json`, the keys in this order: `bin_dir`, `entries` (`name`, `action`, `form`), `roc_old`, `path`, `completion`, and (slice 072a, a proposal, TW24) `default_roc`: an object with
	## `action` (`set`, `kept` or `unread`) and `id` (the id, or null for `unread`).
	data : SetupText.Done -> JsonDoc
	data = |done| {
		entry = |e| {
			action = match e.act {
				Made(_) => "made"
				Kept => "kept"
				Skipped => "skipped"
			}
			form = match e.act {
				Made(HardLink) => JsonDoc.Text("hard-link")
				Made(Copy) => JsonDoc.Text("copy")
				_ => JsonDoc.Null
			}
			JsonDoc.Obj([("name", JsonDoc.Text(e.name)), ("action", JsonDoc.Text(action)), ("form", form)])
		}
		path = match done.path {
			OnPath => "on-path"
			Present => "present"
			Added(_) => "added"
			Declined(_) => "declined"
			NoShell(_) => "no-shell"
		}
		written = match done.completion {
			Written(_) => "written"
			Present => "present"
			None => "none"
		}
		JsonDoc.Obj([
			("bin_dir", JsonDoc.Text(done.bin)),
			("entries", JsonDoc.Arr(done.entries.map(entry))),
			("roc_old", JsonDoc.Flag(done.moved)),
			("path", JsonDoc.Text(path)),
			("completion", JsonDoc.Text(written)),
			("default_roc", default_data(done.default)),
		])
	}

	## Slice 072a (R-ST16, a proposal, TW24): the note on stderr when the list cannot be read, with its line end. `why` is the text of the failure:
	## `note: no default compiler was set, because the list of compilers cannot be read (<why>). The first command that needs a compiler picks one.`
	unread_note : Str -> Str
	unread_note = |why| "note: no default compiler was set, because the list of compilers cannot be read (${why}). The first command that needs a compiler picks one.\n"

	# The `default_roc` object of `data`.
	default_data : SetupText.Default -> JsonDoc
	default_data = |chosen| match chosen {
		Set(id) => JsonDoc.Obj([("action", JsonDoc.Text("set")), ("id", JsonDoc.Text(id))])
		Kept(id) => JsonDoc.Obj([("action", JsonDoc.Text("kept")), ("id", JsonDoc.Text(id))])
		Repaired(id) => JsonDoc.Obj([("action", JsonDoc.Text("repaired")), ("id", JsonDoc.Text(id))])
		Unread(_) => JsonDoc.Obj([("action", JsonDoc.Text("unread")), ("id", JsonDoc.Null)])
	}

	# The text without the `ch` at its end (all of them).
	strip_end : Str, Str -> Str
	strip_end = |text, ch| if text.ends_with(ch) strip_end(text.drop_suffix(ch), ch) else text

	# A part of `PATH` without the `/` at its end. A part that is only `/` stays.
	clean_part : Str -> Str
	clean_part = |part| {
		stripped = strip_end(part, "/")
		if stripped.is_empty() and !part.is_empty() "/" else stripped
	}

	# The parts of `PATH`: no empty part, no `/` at the end of a part.
	parts_of : Str -> List(Str)
	parts_of = |path| path.split_on(":").keep_if(|part| !part.is_empty()).map(clean_part)

	# The old text, a line end when it lacks one, the new line, and a line end.
	appended : Str, Str -> Str
	appended = |text, line| if text.is_empty() or text.ends_with("\n") "${text}${line}\n" else "${text}\n${line}\n"

	## The value of an environment variable, or the empty text.
	var_of : List((Str, Str)), Str -> Str
	var_of = |env, name| match env.find_first(|(key, _)| key == name) {
		Ok((_, value)) => value
		Err(_) => ""
	}
}

form_text : [HardLink, Copy] -> Str
form_text = |form| match form {
	HardLink => "hard link"
	Copy => "copy"
}

commands = "init install remove update upgrade outdated why probe list patch verify x publish audit roc tool cache setup yank move share"

roc_words = "install link use list remove default update"

tool_words = "install list update rebuild remove"

cache_words = "gc clean list dir"

bash_text : Str
bash_text = Str.join_with(
	[
		"# bash completion for tln. Made by tln setup.",
		"_tln() {",
		"\tlocal cur=\"\${COMP_WORDS[COMP_CWORD]}\"",
		"\tlocal words=\"\"",
		"\tif [ \"\$COMP_CWORD\" -eq 1 ]; then",
		"\t\twords=\"${commands}\"",
		"\telif [ \"\$COMP_CWORD\" -eq 2 ]; then",
		"\t\tcase \"\${COMP_WORDS[1]}\" in",
		"\t\t\troc) words=\"${roc_words}\" ;;",
		"\t\t\ttool) words=\"${tool_words}\" ;;",
		"\t\t\tcache) words=\"${cache_words}\" ;;",
		"\t\tesac",
		"\tfi",
		"\tCOMPREPLY=(\$(compgen -W \"\$words\" -- \"\$cur\"))",
		"}",
		"complete -F _tln tln",
		"",
	],
	"\n",
)

zsh_text : Str
zsh_text = Str.join_with(
	[
		"#compdef tln",
		"# zsh completion for tln. Made by tln setup.",
		"_tln() {",
		"\tif (( CURRENT == 2 )); then",
		"\t\tcompadd ${commands}",
		"\telif (( CURRENT == 3 )); then",
		"\t\tcase \$words[2] in",
		"\t\t\troc) compadd ${roc_words} ;;",
		"\t\t\ttool) compadd ${tool_words} ;;",
		"\t\t\tcache) compadd ${cache_words} ;;",
		"\t\tesac",
		"\tfi",
		"}",
		"_tln \"\$@\"",
		"",
	],
	"\n",
)

fish_text : Str
fish_text = Str.join_with(
	[
		"# fish completion for tln. Made by tln setup.",
		"complete -c tln -f",
		"complete -c tln -n '__fish_use_subcommand' -a '${commands}'",
		"complete -c tln -n '__fish_seen_subcommand_from roc' -a '${roc_words}'",
		"complete -c tln -n '__fish_seen_subcommand_from tool' -a '${tool_words}'",
		"complete -c tln -n '__fish_seen_subcommand_from cache' -a '${cache_words}'",
		"",
	],
	"\n",
)
