## The text of `tln --help` and `tln --version`, and the words that ask for them (Q7).
Help :: [].{

	## The version of `tln`. The design gives no source for it yet (question in the slice file).
	version : Str
	version = "0.0.1"

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

	## The usage text. It names the commands in the long form (R-CM19).
	usage : Str
	usage = Str.join_with(
		[
			"Usage: tln [flags] <command> [words]",
			"",
			"Commands:",
			"  init      Make a new app or package",
			"  install   Add packages, or fetch the closure of the header (also: add, i)",
			"  remove    Remove a package (also: rm)",
			"  update    Move within the ranges (also: up)",
			"  upgrade   Move to the newest releases",
			"  outdated  Show the current, wanted and latest versions",
			"  why       Show why a package is in the closure",
			"  probe     Probe an entry on the selected compiler",
			"  list      Show the closure (also: ls)",
			"  patch     Edit a copy of a dependency",
			"  verify    Resolve and probe, and write nothing",
			"  x         Build a Roc app and run it once",
			"  publish   Register a release",
			"  audit     Report yanked and changed releases",
			"  roc       Manage compilers",
			"  tool      Manage global tools",
			"  cache     Manage the cache",
			"  setup     Install the roc proxy and the PATH line",
			"  yank      Yank a release",
			"  move      Set the successor of a package name",
			"  share     Show or change the sharing of probe results",
			"  help      Show this text",
			"",
			"Flags for every command:",
			"  --json  --yes  --offline  --quiet  --registry <url|direct>  --help  --version",
			"",
		],
		"\n",
	)
}
