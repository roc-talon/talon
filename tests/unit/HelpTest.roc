import lib.Args
import lib.Help

HelpTest :: [].{}

# Slice 262a (R-CM26, R-CM19, R-FL12, Design Q642, docs/slices/262-cli-ux-fixes.md section 6). The texts were made by
# research/slice-262-help/texts.py from the rule of section 6.3, so the L0 and the L2 files agree.

text_of = |lines| "${Str.join_with(lines, "\n")}\n"

general_lines = [
	"Usage: tln [flags] <command> [words]",
	"       tln help <command>    Show the usage of one command (also: tln <command> --help)",
	"",
	"Commands:",
	"  init      Make a new app or package",
	"  install   Add packages, or fetch the closure of the header (also: add, i)",
	"  remove    Remove a package (also: rm)",
	"  update    Move the packages of this project within the ranges (also: up)",
	"  upgrade   Move the packages and the compiler of this project to the newest releases",
	"  outdated  Show the current, wanted and latest versions",
	"  why       Show why a package is in the closure",
	"  probe     Probe an entry on the selected compiler",
	"  list      Show the closure (also: ls)",
	"  patch     Edit a copy of a dependency",
	"  verify    Resolve and probe, and write nothing",
	"  path      Print the directory of a header entry",
	"  run       Run a script of talon.toml",
	"  x         Build a Roc app and run it once",
	"  publish   Register a release",
	"  audit     Report yanked and changed releases",
	"  roc       Manage compilers: install, link, use, list, remove, default, update, channel",
	"  tool      Manage global tools: install, list, update, rebuild, remove",
	"  cache     Manage the cache: gc, clean, list, dir",
	"  setup     Install the roc proxy and the PATH line",
	"  yank      Yank a release",
	"  move      Set the successor of a package name",
	"  share     Show or change the sharing of probe results: on, off, login, logout, forget",
	"  help      Show this text, or the usage of one command",
	"",
	"To update tln itself, run: tln tool update talon",
	"(tln upgrade changes the project, not tln.)",
	"",
	"Flags for every command:",
	"  --json  --yes  --offline  --quiet  --registry <url|direct>  --help (-h)  --version",
	"  --file <path>  The project file, for a command that uses a project",
]

install_lines = [
	"Usage: tln install [<name>[@<sel>]...] [flags]",
	"       tln install --platform <name>[@<sel>] [flags]",
	"       tln install --tool <owner/app>[@<sel>] [flags]",
	"Also: tln add, tln i",
	"",
	"Add packages, or fetch the closure of the header.",
	"",
	"Arguments:",
	"  <name>[@<sel>]       A package: an alias, owner/repo, host/path or a short name, with an optional selector (@1.2.3, @^1.2, @latest)",
	"  <owner/app>[@<sel>]  A Roc app on GitHub, with an optional selector",
	"",
	"Flags:",
	"  --file <path>              The project file",
	"  --frozen                   Fetch the closure of the header, and change nothing (no names only)",
	"  --no-probe                 Run no probe: use only known facts",
	"  --no-check                 Do not check the result",
	"  --snapshot <log:N|time>    Hide the releases after a registry log size or a time",
	"  --strategy highest|lowest  Choose the highest or the lowest versions",
	"  --dry-run                  Show the changes, and write nothing",
	"  --slots <n>                Run at most <n> probes at the same time",
	"  --as <alias>               The alias of the new entry (one name only)",
	"  --no-pin                   With an exact version: start there, with no pin",
	"  --platform                 The name is the platform of the app",
	"  --rename-keys              Rename the stale keys of talon.toml with no prompt",
	"  --allow-moves              Move held entries with no prompt",
	"  --allow-downloads          Download the compilers that the command needs with no prompt",
	"  --tool                     Add a project tool to [tools] of talon.toml",
	"",
	"Flags for every command: --json --yes --offline --quiet --registry <url|direct> --help",
]

roc_update_lines = [
	"Usage: tln roc update [<channel>]",
	"Also: tln roc up",
	"",
	"Install the newest compiler release, and move the global default to it.",
	"",
	"Arguments:",
	"  <channel>  The name of a user channel (tln roc channel list). With none: the nightlies",
	"",
	"Flags for every command: --json --yes --offline --quiet --registry <url|direct> --help",
]

roc_lines = [
	"Usage: tln roc <command> [words]",
	"",
	"Manage compilers.",
	"",
	"Commands:",
	"  install  Install a compiler: a nightly, a release or a git ref (also: add, i)",
	"  link     Use a local roc build under a name",
	"  use      Check the project on a compiler and write the roc: pin of the header",
	"  list     Show the installed compilers (also: ls)",
	"  remove   Remove one compiler (also: rm)",
	"  default  Set the global default compiler",
	"  update   Install the newest compiler and move the global default (also: up)",
	"  channel  Add, remove or list compiler channels",
	"",
	"Run tln roc <command> --help for the usage of one command.",
	"Flags for every command: --json --yes --offline --quiet --registry <url|direct> --help",
]

# R-CM26 R-CM19 R-CM12 Q262-7: what help a line asks for. `--help`, `-h` or the first word `help`, before a bare `--`. The command words are found
# as `Args` finds them: a flag and its value are skipped, an alias gives the long form, the third word of `roc channel` is an operand.
# An unknown word is `Unknown` with the words as typed (the command prints the unknown-command failure, exit 2).
expect {
	rows = [
		(["--help"], General),
		(["-h"], General),
		(["help"], General),
		(["--json", "--help"], General),
		(["help", "help"], General),
		(["--help", "--version"], General),
		(["install", "--help"], Key("install")),
		(["add", "-h"], Key("install")),
		(["help", "i"], Key("install")),
		(["help", "rm"], Key("remove")),
		(["roc", "up", "-h"], Key("roc update")),
		(["help", "roc", "update"], Key("roc update")),
		(["roc", "--help"], Key("roc")),
		(["share", "--help"], Key("share")),
		(["share", "on", "-h"], Key("share on")),
		(["tool", "--help", "install"], Key("tool install")),
		(["--registry", "direct", "install", "-h"], Key("install")),
		(["--json", "install", "json", "--as", "j", "--help"], Key("install")),
		(["install", "--bogus", "--help"], Key("install")),
		(["roc", "channel", "remove", "-h"], Key("roc channel")),
		(["x", "acme/app", "--", "-h"], NoHelp),
		(["x", "acme/app", "--", "--help"], NoHelp),
		(["list"], NoHelp),
		(["--version"], NoHelp),
		(["help", "frob"], Unknown("frob")),
		(["frob", "--help"], Unknown("frob")),
		(["roc", "frob", "-h"], Unknown("roc frob")),
		(["help", "roc", "frob"], Unknown("roc frob")),
	]
	bad = rows.keep_if(|(words, want)| Help.topic(words) != want).map(|(words, want)| (words, want, Help.topic(words)))
	dbg bad
	bad == []
}

# R-CM26, UX2, UX7: the general text names `path`, `run`, the sub words of `roc` (with `channel`), `tool`, `cache` and `share`,
# the update of tln itself, `-h` and `--file` (section 6.2, approved 2026-11-23).
expect {
	dbg Help.usage
	Help.usage == text_of(general_lines)
}

# R-CM26 R-CM19: the 3 samples of section 6.3: a command, a sub command with no flag block, a group.
expect {
	got = [Help.command("install"), Help.command("roc update"), Help.command("roc")]
	want = [Ok(text_of(install_lines)), Ok(text_of(roc_update_lines)), Ok(text_of(roc_lines))]
	dbg got
	got == want
}

# R-CM26 R-CM19: a key is the long form. An alias or a word that is no command has no text.
expect {
	got = [Help.command("rm"), Help.command("add"), Help.command("frob"), Help.command(""), Help.command("roc up")]
	dbg got
	got == [Err(Unknown), Err(Unknown), Err(Unknown), Err(Unknown), Err(Unknown)]
}

# The command keys of section 6.4 (no group key).
keys = [
	"init",
	"install",
	"remove",
	"update",
	"upgrade",
	"outdated",
	"why",
	"probe",
	"list",
	"patch",
	"verify",
	"path",
	"run",
	"x",
	"publish",
	"audit",
	"yank",
	"move",
	"share",
	"share on",
	"share off",
	"share login",
	"share logout",
	"share forget",
	"roc install",
	"roc link",
	"roc use",
	"roc list",
	"roc remove",
	"roc default",
	"roc update",
	"roc channel",
	"tool install",
	"tool list",
	"tool update",
	"tool rebuild",
	"tool remove",
	"cache gc",
	"cache clean",
	"cache list",
	"cache dir",
	"setup",
]

# The fixed flag order of section 6.3 (the order of `Args.allows`). The global flags are not in it.
order = [
	"--file",
	"--frozen",
	"--no-probe",
	"--no-check",
	"--snapshot",
	"--strategy",
	"--dry-run",
	"--slots",
	"--as",
	"--no-pin",
	"--platform",
	"--ci",
	"--git",
	"--path",
	"--from-source",
	"-i",
	"--diff",
	"--tree",
	"--range",
	"--share",
	"--smoke",
	"--target",
	"--all",
	"--force",
	"--copy",
	"--rename-keys",
	"--allow-moves",
	"--probe-downloads",
	"--allow-downloads",
	"--roc",
	"--allow-unchecked",
	"--resolve",
	"--remove-tools",
	"--keep-all",
	"--replace-roc",
	"--no-modify-path",
	"--tag-prefix",
	"--reason",
	"--to",
	"--undo",
	"--ignore",
	"--tool",
	"--each",
	"--keep-going",
]

# UX16: the forms that are not built are not in the help.
not_built = |key, flag| (key == "x" and ["--git", "--path", "--resolve"].contains(flag)) or (key == "tool install" and flag == "--resolve")

# R-FL12 is the oracle: `Args.parse` takes the flag for the key (with a value word after it, which a flag with no value leaves as an operand).
allowed = |key, flag| Args.parse(key.split_on(" ").concat([flag, "v"])).is_ok()

# The first word of each line of the `Flags:` block.
flags_of = |text| {
	lines = text.split_on("\n")
	after = match lines.find_first_index(|l| l == "Flags:") {
		Ok(i) => lines.drop_first(i + 1)
		Err(_) => []
	}
	end = match after.find_first_index(|l| l == "") {
		Ok(n) => n
		Err(_) => after.len()
	}
	after.take_first(end).map(
		|l| match l.trim_start().split_first(" ") {
			Ok({ before, after: _ }) => before
			Err(_) => l.trim_start()
		},
	)
}

# R-CM26 R-FL12 UX16: for each key, the `Flags:` block lists exactly the flags that `Args` allows for it, in the fixed order,
# with no global flag and no form that is not built (no `--git`, `--path`, `--resolve` for `x`, no `--resolve` for `tool install`).
expect {
	bad = keys.keep_if(
		|key| match Help.command(key) {
			Ok(text) => flags_of(text) != order.keep_if(|f| allowed(key, f) and !not_built(key, f))
			Err(_) => Bool.True
		},
	)
	dbg bad
	bad == []
}

# R-CM26 R-FL1: each text starts with `Usage: tln <key>` and ends with the line of the global flags. `x` takes no `--json`.
expect {
	global = "Flags for every command: --json --yes --offline --quiet --registry <url|direct> --help"
	global_x = "Flags for every command: --yes --offline --quiet --registry <url|direct> --help"
	ok_text = |key, text| {
		lines = text.split_on("\n")
		last = lines.drop_last(1).last() ?? ""
		text.starts_with("Usage: tln ${key}") and text.ends_with("\n") and last == (if key == "x" global_x else global)
	}
	bad = keys.keep_if(
		|key| match Help.command(key) {
			Ok(text) => !ok_text(key, text)
			Err(_) => Bool.True
		},
	)
	dbg bad
	bad == []
}

# UX16 R-S6: `tool rebuild` does not name `talon` (R-S6: not supported); `x` names no git form.
expect {
	rebuild = Help.command("tool rebuild") ?? ""
	x = Help.command("x") ?? ""
	got = (rebuild.contains("talon"), x.contains("--git"), x.contains("--path"), x.contains("--resolve"), (Help.command("tool install") ?? "").contains("--resolve"))
	dbg got
	got == (Bool.False, Bool.False, Bool.False, Bool.False, Bool.False)
}

# R-CM26 R-CM19: a group text lists each sub word with its long form, one line each, in the order of `Args`.
expect {
	subs = [
		("tool", ["install", "list", "update", "rebuild", "remove"]),
		("cache", ["gc", "clean", "list", "dir"]),
		("roc", ["install", "link", "use", "list", "remove", "default", "update", "channel"]),
	]
	bad = subs.keep_if(
		|(group, words)| match Help.command(group) {
			Ok(text) => !text.starts_with("Usage: tln ${group} <command> [words]\n") or !words.all(|w| text.contains("\n  ${w} "))
			Err(_) => Bool.True
		},
	)
	dbg bad
	bad == []
}
