import Args

## The text of `tln --help` and `tln --version`, and the words that ask for them (Q7).
Help :: [].{

	## The version of `tln`. The design gives no source for it yet (question in the slice file).
	version : Str
	version = "0.0.1"

	## R-RG2, Design Q207, Q208: the built-in default registry, in the base URL form. R-RG8: it is the `AUDIENCE` of `worker/wrangler.toml`.
	default_registry : Str
	default_registry = "https://registry.roc-talon.org"

	## R-RG1, R-RG9: the text of the source of the built-in default. Only a failure with this source falls back to `direct`.
	default_source : Str
	default_source = "the built-in default"

	## What a command line asks for before it is parsed: `Help` for `--help` or `help` as the first word,
	## `Version` for `--version`. Words after a bare `--` belong to a child program (R-CM12).
	## Else `Command`.
	route : List(Str) -> [Help, Version, Command]
	route = |words| {
		own = match words.find_first_index(|word| word == "--") {
			Ok(end) => words.take_first(end)
			Err(NotFound) => words
		}
		if own.contains("--help") or own.first() == Ok("help") {
			Help
		} else if own.contains("--version") {
			Version
		} else {
			Command
		}
	}

	## Slice 262a (R-CM26): what help a command line asks for. `NoHelp`: no `--help`, `-h` or first word `help`
	## before a bare `--` (R-CM12). `General`: no command words (or `help help`). `Key(<long form key>)`: the command words, found as `Args` finds them
	## (flags and their values skipped, aliases to the long form, at most the command and its sub word). `Unknown(<typed words>)`: a word that is no command (Q262-7).
	topic : List(Str) -> [NoHelp, General, Key(Str), Unknown(Str)]
	topic = |words| {
		own = match words.find_first_index(|word| word == "--") {
			Ok(end) => words.take_first(end)
			Err(NotFound) => words
		}
		if own.contains("--help") or own.contains("-h") or own.first() == Ok("help") {
			match Args.words_of(own) {
				Ok([]) => General
				Ok(cmd) => Key(Str.join_with(cmd, " "))
				Err(typed) => Unknown(typed)
			}
		} else {
			NoHelp
		}
	}

	## Slice 262a (R-CM26): the usage text of one command key in the long form (`install`, `roc update`, `roc`),
	## by the rule of `docs/slices/262-cli-ux-fixes.md` section 6.3. Each line ends with a line end. Another text (an alias, no command): `Err(Unknown)`.
	command : Str -> Try(Str, [Unknown])
	command = |key| match group_desc(key) {
		Ok(desc) => Ok(group_text(key, desc))
		Err(_) => match spec(key) {
			Ok(one) => Ok(command_text(key, one))
			Err(_) => Err(Unknown)
		}
	}

	## The usage text (section 6.2 of the slice 262 file). It names the commands in the long form (R-CM19).
	usage : Str
	usage = Str.join_with(
		[
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
			"",
		],
		"\n",
	)
}

# ---- The per-command texts (slice 262a, section 6.3 to 6.6) ----

# The usage lines (the operands, FLAGS marks where `[flags]` goes), the description and the placeholders of one command key.
Spec : { usage : List(Str), desc : Str, args : List(Str) }

spec : Str -> Try(Spec, [Unknown])
spec = |key| {
	one = |usage, desc, args| Ok({ usage, desc, args })
	match key {
		"init" => one(["[app|package] FLAGS"], "Make a new app or package", ["[app|package]"])
		"install" => one(["[<name>[@<sel>]...] FLAGS", "--platform <name>[@<sel>] FLAGS", "--tool <owner/app>[@<sel>] FLAGS"], "Add packages, or fetch the closure of the header", ["<name>[@<sel>]", "<owner/app>[@<sel>]"])
		"remove" => one(["<name>... FLAGS", "--tool <key>... FLAGS"], "Remove packages, or project tools", ["<name>", "<key>"])
		"update" => one(["[<name>[@<sel>]...] FLAGS", "-i FLAGS", "--tool [<key>...] FLAGS"], "Move the packages of this project within the ranges", ["<name>[@<sel>]", "<key>"])
		"upgrade" => one(["[<name>...] [roc] FLAGS", "--tool [<key>...] FLAGS"], "Move the packages and the compiler of this project to the newest releases", ["<name>", "[roc]", "<key>"])
		"outdated" => one([""], "Show the current, wanted and latest versions", [])
		"why" => one(["<name> FLAGS"], "Show why a package is in the closure", ["<name>"])
		"list" => one([""], "Show the closure", [])
		"patch" => one(["<alias> FLAGS"], "Edit a copy of a dependency", ["<alias>"])
		"verify" => one([""], "Resolve and probe, and write nothing", [])
		"probe" => one(["[<alias>|<bundle file>] FLAGS", "--smoke <alias>|<release URL> FLAGS [--target <target>]..."], "Probe an entry on the selected compiler", ["<alias>", "<bundle file>", "<release URL>"])
		"publish" => one([""], "Register a release (in GitHub Actions)", [])
		"audit" => one(["[--ignore <item>]... FLAGS"], "Report yanked and changed releases", ["<item>"])
		"path" => one(["<alias>"], "Print the directory of a header entry", ["<alias>"])
		"run" => one(["[<script>] FLAGS [-- <args>]", "--each [<script>] FLAGS [-- <args>]"], "Run a script of talon.toml", ["<script>", "<args>"])
		"x" => one(["<owner/app>[@<sel>] FLAGS [-- <args>]", "<key> FLAGS [-- <args>]"], "Build a Roc app and run it once", ["<owner/app>[@<sel>]", "<args>", "<key>"])
		"yank" => one(["<tag> FLAGS"], "Yank a release (in a workflow_dispatch job)", ["<tag>"])
		"move" => one(["<old-name> FLAGS"], "Set the successor of a package name (in a workflow_dispatch job)", ["<old-name>"])
		"share" => one(["[on|off|login|logout|forget]"], "Show or change the sharing of probe results", [])
		"share on" => one([""], "Turn sharing on", [])
		"share off" => one([""], "Turn sharing off", [])
		"share login" => one([""], "Log in with GitHub", [])
		"share logout" => one([""], "Log out", [])
		"share forget" => one([""], "Remove the results of this machine (or account)", [])
		"roc install" => one(["<id>|<ref> FLAGS", "--git <owner/repo@ref>|@<ref> FLAGS"], "Install a compiler: a nightly, a release or a git ref", ["<id>", "<ref>", "<owner/repo@ref>", "@<ref>"])
		"roc link" => one(["<name> <path> FLAGS"], "Use a local roc build under a name", ["<name> <path>"])
		"roc use" => one(["<ref> FLAGS"], "Check the project on a compiler and write the roc: pin of the header", ["<ref>"])
		"roc list" => one([""], "Show the installed compilers", [])
		"roc remove" => one(["<id>"], "Remove one compiler", ["<id>"])
		"roc default" => one(["<ref> FLAGS", "--git <owner/repo@ref> FLAGS"], "Set the global default compiler", ["<ref>", "<owner/repo@ref>"])
		"roc update" => one(["[<channel>]"], "Install the newest compiler release, and move the global default to it", ["<channel>"])
		"roc channel" => one(["add <name> [<URL>] FLAGS", "remove <name>", "list"], "Add, remove or list compiler channels", ["<name>", "<URL>"])
		"tool install" => one(["<owner/app>[@<sel>] FLAGS", "--git <owner/app@ref> FLAGS"], "Build a Roc app and put it on PATH", ["<owner/app>[@<sel>]", "<owner/app@ref>"])
		"tool list" => one([""], "Show the global tools", [])
		"tool update" => one(["[<tool>] FLAGS", "talon FLAGS"], "Move tools to their newest releases (talon: update tln itself)", ["<tool>"])
		"tool rebuild" => one(["[<tool>]"], "Build tools again on the default compiler", ["<tool>"])
		"tool remove" => one(["<tool> FLAGS", "talon FLAGS"], "Remove a tool (talon: remove tln)", ["<tool>"])
		"cache gc" => one([""], "Remove what no known project uses", [])
		"cache clean" => one([""], "Remove cache files on request", [])
		"cache list" => one([""], "Show the cache sizes", [])
		"cache dir" => one([""], "Print the cache directory", [])
		"setup" => one([""], "Install the roc proxy and the PATH line", [])
		_ => Err(Unknown)
	}
}

# The fixed order of the flags (the order of `Args.allowed`). The global flags are not in it, `--file` is.
flag_order : List(Str)
flag_order = [
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
not_built : Str, Str -> Bool
not_built = |key, flag| (key == "x" and ["--git", "--path", "--resolve"].contains(flag)) or (key == "tool install" and flag == "--resolve")

# The flag column and the text of a flag for a command key (section 6.6).
flag_row : Str, Str -> (Str, Str)
flag_row = |key, flag| match flag {
	"--file" => ("--file <path>", "The project file")
	"--frozen" => ("--frozen", "Fetch the closure of the header, and change nothing (no names only)")
	"--no-probe" => ("--no-probe", "Run no probe: use only known facts")
	"--no-check" => ("--no-check", "Do not check the result")
	"--snapshot" => ("--snapshot <log:N|time>", "Hide the releases after a registry log size or a time")
	"--strategy" => ("--strategy highest|lowest", "Choose the highest or the lowest versions")
	"--dry-run" => if ["cache gc", "cache clean", "tool remove"].contains(key) {
		("--dry-run", "Show what would be removed, and remove nothing")
	} else {
		("--dry-run", "Show the changes, and write nothing")
	}
	"--slots" => ("--slots <n>", "Run at most <n> probes at the same time")
	"--as" => if key == "tool install" ("--as <name>", "The binary name") else ("--as <alias>", "The alias of the new entry (one name only)")
	"--no-pin" => ("--no-pin", "With an exact version: start there, with no pin")
	"--platform" => if key == "init" {
		("--platform <owner/repo>[@<version>]", "The platform of the template")
	} else {
		("--platform", "The name is the platform of the app")
	}
	"--ci" => ("--ci github|none", "The CI file to make")
	"--git" => ("--git", "The operand is a git ref")
	"--path" => ("--path <dir>", "The directory of the app in the repository")
	"--from-source" => ("--from-source", "Build tln from its source (tln tool update talon)")
	"-i" => ("-i", "Pick the packages from a list")
	"--diff" => ("--diff", "Print the patch against the original")
	"--tree" => ("--tree", "Show the closure as a tree")
	"--range" => ("--range", "Find the compiler range")
	"--share" => ("--share", "Send the facts to the registry once")
	"--smoke" => ("--smoke", "Run the smoke build of a platform")
	"--target" => ("--target <target>", "A target of the smoke build (more than once for more targets)")
	"--all" => ("--all", "Also remove packages and build caches")
	"--force" => if key == "roc link" ("--force", "Replace a copy with the same name") else ("--force", "Remove also when an app module imports it")
	"--copy" => ("--copy", "Copy the binary, not a link")
	"--rename-keys" => ("--rename-keys", "Rename the stale keys of talon.toml with no prompt")
	"--allow-moves" => ("--allow-moves", "Move held entries with no prompt")
	"--probe-downloads" => ("--probe-downloads", "Download compilers for the search with no prompt")
	"--allow-downloads" => ("--allow-downloads", "Download the compilers that the command needs with no prompt")
	"--roc" => ("--roc pinned|installed", "Which compiler builds the app")
	"--allow-unchecked" => ("--allow-unchecked", "Use a cached build that was not checked online")
	"--resolve" => ("--resolve", "Resolve the packages of the header")
	"--remove-tools" => ("--remove-tools", "Remove the tools too")
	"--keep-all" => ("--keep-all", "Keep everything (only tln goes)")
	"--replace-roc" => ("--replace-roc", "Replace a roc that tln did not write")
	"--no-modify-path" => ("--no-modify-path", "Do not add the PATH line")
	"--tag-prefix" => ("--tag-prefix <p>", "The tag prefix of the channel releases")
	"--reason" => ("--reason <text>", "The reason of the yank")
	"--to" => ("--to <new-name>", "The successor name")
	"--undo" => ("--undo", "Remove the yank (or the successor)")
	"--ignore" => ("--ignore <item>", "Ignore one finding (more than once for more)")
	"--tool" => if key == "install" {
		("--tool", "Add a project tool to [tools] of talon.toml")
	} else {
		("--tool", "The operands are project tools of [tools]")
	}
	"--each" => ("--each", "Run in each workspace directory")
	"--keep-going" => ("--keep-going", "With --each, go on after a failure")
	_ => (flag, "")
}

# The text of a placeholder (section 6.5). `roc channel` has its own words for `<name>` and `<URL>`.
arg_text : Str, Str -> Str
arg_text = |key, label| match label {
	"<name>[@<sel>]" | "<name>" => if key == "roc channel" {
		"The name of the channel: a-z, 0-9 and -, 2 to 24 characters"
	} else {
		"A package: an alias, owner/repo, host/path or a short name, with an optional selector (@1.2.3, @^1.2, @latest)"
	}
	"<alias>" => "An alias of the header"
	"<key>" => "A key of [tools] in talon.toml"
	"<owner/app>[@<sel>]" => "A Roc app on GitHub, with an optional selector"
	"<bundle file>" => "A bundle file"
	"<release URL>" => "A release URL https://.../<hash>.tar.zst"
	"<script>" => "A key of [scripts] in talon.toml"
	"<args>" => "Words that tln passes on as they are"
	"<owner/app@ref>" => "A Roc app on GitHub at a git ref (a branch, a tag or a commit)"
	"<id>" => "A compiler id (tln roc list)"
	"<ref>" => "A compiler: an id, nightly, latest, @-1 or a git ref"
	"<owner/repo@ref>" => "A git ref of a repository"
	"@<ref>" => "A git ref of roc-lang/roc"
	"<name> <path>" => "A name and the path of a roc binary"
	"<channel>" => "The name of a user channel (tln roc channel list). With none: the nightlies"
	"<URL>" => "The GitHub repository of the channel"
	"<tool>" => "A tool name"
	"<tag>" => "A release tag of this repository"
	"<old-name>" => "A full name owner/repo"
	"<item>" => "owner/repo@version:reason"
	"[app|package]" => "The template (default: app)"
	"[roc]" => "The word roc frees the compiler"
	_ => ""
}

# The other forms of a command word (R-CM19).
aliases : Str -> List(Str)
aliases = |word| match word {
	"install" => ["add", "i"]
	"remove" => ["rm"]
	"list" => ["ls"]
	"update" => ["up"]
	_ => []
}

# A block of rows: the first column is as wide as the longest plus 2 spaces, and the rows are indented by 2.
rows_block : List((Str, Str)) -> List(Str)
rows_block = |rows| {
	width = rows.fold(0, |wide, (left, _)| if left.count_utf8_bytes() > wide left.count_utf8_bytes() else wide) + 2
	rows.map(|(left, right)| "  ${left}${Str.repeat(" ", width - left.count_utf8_bytes())}${right}")
}

global_line : Str -> Str
global_line = |key| if key == "x" {
	"Flags for every command: --yes --offline --quiet --registry <url|direct> --help"
} else {
	"Flags for every command: --json --yes --offline --quiet --registry <url|direct> --help"
}

group_desc : Str -> Try(Str, [NoGroup])
group_desc = |key| match key {
	"roc" => Ok("Manage compilers")
	"tool" => Ok("Manage global tools")
	"cache" => Ok("Manage the cache")
	_ => Err(NoGroup)
}

# The text of a sub word in a group list: the description, and the other forms.
sub_line : Str -> Str
sub_line = |key| {
	desc = match spec(key) {
		Ok(one) => match key {
			"roc update" => "Install the newest compiler and move the global default"
			"tool update" => "Move tools to their newest releases, or tln itself"
			"tool remove" => "Remove a tool, or tln itself"
			_ => one.desc
		}
		Err(_) => ""
	}
	last = key.split_on(" ").last() ?? ""
	if aliases(last).is_empty() desc else "${desc} (also: ${Str.join_with(aliases(last), ", ")})"
}

group_text : Str, Str -> Str
group_text = |key, desc| {
	subs = Args.subs(key)
	lines = [
		["Usage: tln ${key} <command> [words]", "", "${desc}.", "", "Commands:"],
		rows_block(subs.map(|sub| (sub, sub_line("${key} ${sub}")))),
		["", "Run tln ${key} <command> --help for the usage of one command.", global_line(key)],
	]
	"${Str.join_with(lines.join(), "\n")}\n"
}

command_text : Str, Spec -> Str
command_text = |key, one| {
	flags = flag_order.keep_if(|flag| Args.allowed(key, flag) and !not_built(key, flag))
	has_flags = !flags.is_empty()
	marked = one.usage.any(|op| op.contains(" FLAGS"))
	usage_lines = one.usage.map_with_index(
		|op, i| {
			head = if i == 0 "Usage: " else "       "
			body = if op.contains(" FLAGS") {
				op.replace_each(" FLAGS", if has_flags " [flags]" else "")
			} else if has_flags and !marked {
				if op == "" " [flags]" else "${op} [flags]"
			} else {
				op
			}
			spaced = if body == "" "" else if body.starts_with(" ") body else " ${body}"
			"${head}tln ${key}${spaced}"
		},
	)
	words = key.split_on(" ")
	last = words.last() ?? ""
	also = if aliases(last).is_empty() {
		[]
	} else {
		front = Str.join_with(words.drop_last(1), " ")
		forms = aliases(last).map(|a| if front == "" "tln ${a}" else "tln ${front} ${a}")
		["Also: ${Str.join_with(forms, ", ")}"]
	}
	arg_block = if one.args.is_empty() {
		[]
	} else {
		["Arguments:"].concat(rows_block(one.args.map(|label| (label, arg_text(key, label))))).append("")
	}
	flag_block = if has_flags {
		["Flags:"].concat(rows_block(flags.map(|flag| flag_row(key, flag)))).append("")
	} else {
		[]
	}
	lines = usage_lines.concat(also).concat(["", "${one.desc}.", ""]).concat(arg_block).concat(flag_block).append(global_line(key))
	"${Str.join_with(lines, "\n")}\n"
}
