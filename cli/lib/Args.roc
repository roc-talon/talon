import Fail

## The parsed command line (the words after `tln`).
##
## | Field | Holds |
## | --- | --- |
## | `command` | The long form of the command words (R-CM19): `["tool", "remove"]` for `tool rm` |
## | `typed` | The command words as typed, joined by one space: `tool rm`. The `--json` envelope uses it. |
## | `operands` | The words after the command that are not flags, in order |
## | `passthrough` | The words after a bare `--`, as they are (R-CM12: `tln x owner/app -- args`) |
## | `json`, `yes`, `offline`, `quiet`, `registry`, `file` | The global flags (R-FL1 to R-FL6) |
## | `options` | The other flags, in the order of the line: the flag with its dashes, and its value if it has one |
Args := {
	command : List(Str),
	typed : Str,
	operands : List(Str),
	passthrough : List(Str),
	json : Bool,
	yes : Bool,
	offline : Bool,
	quiet : Bool,
	registry : Try(Str, [Unset]),
	file : Try(Str, [Unset]),
	options : List((Str, Try(Str, [Unset]))),
}.{
	is_eq : _

	## Parse and check a command line. The rules are in `docs/slices/001-skeleton-and-harness.md`, section "Args rules".
	## On a failure, `fail` has the kind `Usage`. `json` is true when `--json` is anywhere before a bare `--`,
	## also after the word that failed (`tln frobnicate --json` gives an envelope). `typed` is the command words
	## as typed up to the failure ("" if none), so that `Out.fail` can print the envelope.
	parse : List(Str) -> Try(Args, { fail : Fail, json : Bool, typed : Str })
	parse = |words| {
		json = json_before_dashes(words)
		match run(words) {
			Ok(args) => Ok(args)
			Err(stop) => Err({ fail: stop.fail, json, typed: stop.typed })
		}
	}

	## Slice 262a (R-CM26): is the flag allowed for the command (the long form words, joined)? The oracle of the help text.
	allowed : Str, Str -> Bool
	allowed = |cmd, flag| allows(cmd, flag)

	## Slice 262a (R-CM26, B4): the command words of a line as `parse` finds them, in the long form (at most the command and its sub word).
	## A flag and the value of a flag that takes one are skipped. `Err(typed)`: the words as typed up to the word that is no command.
	## The words must end before a bare `--`.
	words_of : List(Str) -> Try(List(Str), Str)
	words_of = |words| command_walk([], [], words)

	## Slice 262a (R-CM19): the sub words of a command in the long form, in the order of the help (`[]` for a command with none).
	subs : Str -> List(Str)
	subs = |command| sub_words(command)

	## Slice 262a (Q262-7, R-CM27): the failure of an unknown command line. `typed` are the words from the command start up to the unknown word.
	## `json` is true when `--json` is before a bare `--` in `words`.
	unknown_stop : List(Str), List(Str) -> { fail : Fail, json : Bool, typed : Str }
	unknown_stop = |typed, words| {
		stop = unknown(typed)
		{ fail: stop.fail, json: json_before_dashes(words), typed: stop.typed }
	}

	## Slice 262a (R-CM27, Q262-1): the closest command for the typed words (the words of the command, the last one is the unknown word):
	## `[w]` at the top level, `[group, w]`, or `["roc", "channel", w]`. The answer is the long form with no `tln`.
	hint_for : List(Str) -> Try(Str, [NoHint])
	hint_for = |typed| suggest(typed)
}

run : List(Str) -> Try(Args, Stop)
run = |words| finish(walk(start, words)?)

# The state of the walk over the words. `checks` holds each flag in the order of the line,
# to test it against the command when the command is known.
State : {
	cmd : List(Str),
	typed : List(Str),
	operands : List(Str),
	passthrough : List(Str),
	checks : List(Str),
	json : Bool,
	yes : Bool,
	offline : Bool,
	quiet : Bool,
	registry : Try(Str, [Unset]),
	file : Try(Str, [Unset]),
	options : List((Str, Try(Str, [Unset]))),
}

Stop : { fail : Fail, typed : Str }

start : State
start = {
	cmd: [],
	typed: [],
	operands: [],
	passthrough: [],
	checks: [],
	json: Bool.False,
	yes: Bool.False,
	offline: Bool.False,
	quiet: Bool.False,
	registry: Err(Unset),
	file: Err(Unset),
	options: [],
}

usage_stop : List(Str), Str -> Stop
usage_stop = |typed, message| { fail: Fail.new(Usage, message), typed: Str.join_with(typed, " ") }

# A1, A9: `--json` anywhere before a bare `--`.
json_before_dashes : List(Str) -> Bool
json_before_dashes = |words| words.fold_until(
	Bool.False,
	|found, word| if (word == "--") Break(found) else Continue(found or word == "--json"),
)

is_flag : Str -> Bool
is_flag = |word| word.starts_with("-") and word.count_utf8_bytes() > 1

# The words after the command words. A bare `--` ends the walk.
walk : State, List(Str) -> Try(State, Stop)
walk = |state, words| match words {
	[] => Ok(state)
	["--", .. as rest] => Ok({ ..state, passthrough: rest })
	[word, .. as rest] => if is_flag(word) {
		flag_step(state, word, rest)
	} else {
		walk(word_step(state, word)?, rest)
	}
}

# A command word, or an operand (A2, A3, A8).
word_step : State, Str -> Try(State, Stop)
word_step = |state, word| match state.cmd {
	[] => match top_level(word) {
		Ok(long) => Ok({ ..state, cmd: [long], typed: [word] })
		Err(NotCommand) => Err(unknown(state.typed.append(word)))
	}
	[first] if !sub_words(first).is_empty() => {
		sub = long_form(word)
		if sub_words(first).contains(sub) {
			Ok({ ..state, cmd: [first, sub], typed: state.typed.append(word) })
		} else {
			Err(unknown(state.typed.append(word)))
		}
	}
	_ => Ok({ ..state, operands: state.operands.append(word) })
}

unknown : List(Str) -> Stop
unknown = |typed| {
	said = "unknown command '${Str.join_with(typed, " ")}'"
	match suggest(typed) {
		Ok(near) => usage_stop(typed, "${said} (did you mean 'tln ${near}'?)")
		Err(NoHint) => usage_stop(typed, said)
	}
}

# R-CM27, Q262-1: the candidates of a level, in the order of the general text: the long form and the other forms of each.
candidates : List(Str) -> List((Str, List(Str)))
candidates = |prefix| match prefix {
	[] => [
		("init", []),
		("install", ["add", "i"]),
		("remove", ["rm"]),
		("update", ["up"]),
		("upgrade", []),
		("outdated", []),
		("why", []),
		("probe", []),
		("list", ["ls"]),
		("patch", []),
		("verify", []),
		("path", []),
		("run", []),
		("x", []),
		("publish", []),
		("audit", []),
		("roc", []),
		("tool", []),
		("cache", []),
		("setup", []),
		("yank", []),
		("move", []),
		("share", []),
		("help", []),
	]
	["roc", "channel"] => [("add", []), ("remove", ["rm"]), ("list", ["ls"])]
	[group] => sub_words(group).map(
		|sub| (
			sub,
			match sub {
				"install" => ["add", "i"]
				"remove" => ["rm"]
				"list" => ["ls"]
				"update" => ["up"]
				_ => []
			},
		),
	)
	_ => []
}

# Q262-1: words from other tools, and the long form that they mean.
other_tools : List((Str, Str))
other_tools = [("uninstall", "remove"), ("delete", "remove"), ("upgrade", "update"), ("clear", "clean"), ("purge", "clean"), ("prune", "gc")]

# R-CM27, Q262-1: the table first, then the edit distance (limit 1 for a word of 4 letters or less, else 2). A tie: the first in the order of the help.
suggest : List(Str) -> Try(Str, [NoHint])
suggest = |typed| match typed.last() {
	Err(_) => Err(NoHint)
	Ok(word) => {
		prefix = typed.drop_last(1)
		level = candidates(prefix)
		path = |long| if (prefix.is_empty()) long else "${Str.join_with(prefix, " ")} ${long}"
		if prefix.is_empty() and word == "self" {
			Ok("tool update talon")
		} else {
			table = other_tools.find_first(|(from, to)| from == word and level.any(|(long, _)| long == to))
			match table {
				Ok((_, to)) => Ok(path(to))
				Err(_) => {
					limit = if (word.count_utf8_bytes() <= 4) 1 else 2
					bytes = word.to_utf8()
					best = level.fold(
						Err(NoHint),
						|so_far, (long, others)| {
							near = long.to_utf8()
							d = others.fold(osa(bytes, near), |m, other| least(m, osa(bytes, other.to_utf8())))
							match so_far {
								Ok((_, kept)) if kept <= d => so_far
								_ => if (d <= limit) Ok((long, d)) else so_far
							}
						},
					)
					match best {
						Ok((long, _)) => Ok(path(long))
						Err(_) => Err(NoHint)
					}
				}
			}
		}
	}
}

least : U64, U64 -> U64
least = |x, y| if (x < y) x else y

# The optimal string alignment distance: insert, delete, replace and the swap of 2 next letters each count 1.
osa : List(U8), List(U8) -> U64
osa = |a, b| {
	n = b.len()
	cell = |row, k| row.get(k) ?? 0
	var $older = List.repeat(0, n + 1)
	var $prev = [0.U64]
	for j in 1.U64..=n {
		$prev = $prev.append(j)
	}
	for i in 1.U64..=a.len() {
		ai = a.get(i - 1) ?? 0
		var $cur = [i]
		for j in 1.U64..=n {
			bj = b.get(j - 1) ?? 0
			cost = if (ai == bj) 0 else 1
			plain = least(least(cell($prev, j) + 1, cell($cur, j - 1) + 1), cell($prev, j - 1) + cost)
			swapped = if i > 1 and j > 1 and ai == (b.get(j - 2) ?? 0) and bj == (a.get(i - 2) ?? 0) {
				least(plain, cell($older, j - 2) + 1)
			} else {
				plain
			}
			$cur = $cur.append(swapped)
		}
		$older = $prev
		$prev = $cur
	}
	cell($prev, n)
}

# The command words of a line (B4): flags and their values are skipped. `help` as the first word is not a command word.
command_walk : List(Str), List(Str), List(Str) -> Try(List(Str), Str)
command_walk = |cmd, typed, words| match words {
	[] => Ok(cmd)
	[word, .. as rest] => if is_flag(word) {
		name = match word.split_first("=") {
			Ok({ before, after: _ }) if before.starts_with("--") => before
			_ => word
		}
		inline = word.starts_with("--") and word.contains("=")
		if !inline and takes_value(cmd, name) {
			match rest {
				[value, .. as after] if !is_flag(value) => command_walk(cmd, typed, after)
				_ => command_walk(cmd, typed, rest)
			}
		} else {
			command_walk(cmd, typed, rest)
		}
	} else {
		match cmd {
			[] => if word == "help" {
				command_walk(cmd, typed, rest)
			} else {
				match top_level(word) {
					Ok(long) => command_walk([long], [word], rest)
					Err(NotCommand) => Err(word)
				}
			}
			[first] if !sub_words(first).is_empty() => {
				sub = long_form(word)
				if sub_words(first).contains(sub) {
					command_walk([first, sub], typed.append(word), rest)
				} else {
					Err("${Str.join_with(typed, " ")} ${word}")
				}
			}
			_ => Ok(cmd)
		}
	}
}

# A flag and its value, if it has one (A1, A4, Q2, Q9).
flag_step : State, Str, List(Str) -> Try(State, Stop)
flag_step = |state, word, rest| {
	(name, inline) = match word.split_first("=") {
		Ok({ before, after }) if before.starts_with("--") => (before, Ok(after))
		_ => (word, Err(Unset))
	}
	if takes_value(state.cmd, name) {
		match (inline, rest) {
			(Ok(value), _) => walk(apply(state, name, Ok(value)), rest)
			(Err(Unset), [value, .. as after]) if !is_flag(value) => walk(apply(state, name, Ok(value)), after)
			_ => Err(usage_stop(state.typed, "flag '${name}' needs a value"))
		}
	} else {
		match inline {
			Ok(_) => Err(usage_stop(state.typed, "flag '${name}' takes no value"))
			Err(Unset) => walk(apply(state, name, Err(Unset)), rest)
		}
	}
}

apply : State, Str, Try(Str, [Unset]) -> State
apply = |state, name, value| {
	seen = { ..state, checks: state.checks.append(name) }
	match name {
		"--json" => { ..seen, json: Bool.True }
		"--yes" => { ..seen, yes: Bool.True }
		"--offline" => { ..seen, offline: Bool.True }
		"--quiet" => { ..seen, quiet: Bool.True }
		"--registry" => { ..seen, registry: value }
		"--file" => { ..seen, file: value }
		_ => { ..seen, options: seen.options.append((name, value)) }
	}
}

# At the end: the command is complete and each flag is allowed for it (A8, R-FL12).
finish : State -> Try(Args, Stop)
finish = |state| {
	key = Str.join_with(state.cmd, " ")
	if state.cmd.len() == 1 and needs_sub(state.cmd.first() ?? "") {
		Err(usage_stop(state.typed, "command '${key}' needs a subcommand"))
	} else {
		match state.checks.find_first(|flag| !allows(key, flag)) {
			Ok(flag) if key == "" => Err(usage_stop(state.typed, "flag '${flag}' needs a command"))
			Ok(flag) => Err(usage_stop(state.typed, "flag '${flag}' is not for '${key}'"))
			Err(_) => match repeated(state.checks) {
				Ok(flag) => Err(usage_stop(state.typed, "flag '${flag}' is given more than once"))
				Err(_) => Ok({
					command: state.cmd,
					typed: Str.join_with(state.typed, " "),
					operands: state.operands,
					passthrough: state.passthrough,
					json: state.json,
					yes: state.yes,
					offline: state.offline,
					quiet: state.quiet,
					registry: state.registry,
					file: state.file,
					options: state.options,
				})
			}
		}
	}
}

# R-FL15, Q262-2: the flag whose second use comes first in the line. `--ignore` and `--target` repeat on purpose (R-AU9, R-PB10).
repeated : List(Str) -> Try(Str, [None])
repeated = |checks| {
	found = checks.fold_until(
		([], Err(None)),
		|(seen, _), flag| if seen.contains(flag) and flag != "--ignore" and flag != "--target" {
			Break((seen, Ok(flag)))
		} else {
			Continue((seen.append(flag), Err(None)))
		},
	)
	found.1
}

# The verb aliases (R-CM19).
long_form : Str -> Str
long_form = |word| match word {
	"rm" => "remove"
	"ls" => "list"
	"i" | "add" => "install"
	"up" => "update"
	other => other
}

# The top-level commands of CLI 1, as the long form (slice 055: `path`, R-CM25).
top_level : Str -> Try(Str, [NotCommand])
top_level = |word| {
	long = long_form(word)
	known = ["init", "install", "remove", "update", "upgrade", "outdated", "why", "probe", "list", "patch", "verify", "path", "run", "x", "publish", "audit", "roc", "tool", "cache", "setup", "yank", "move", "share"]
	if (known.contains(long)) Ok(long) else Err(NotCommand)
}

# The second word of a command (R-CM15 to R-CM17, R-CM23).
sub_words : Str -> List(Str)
sub_words = |command| match command {
	"roc" => ["install", "link", "use", "list", "remove", "default", "update", "channel"]
	"tool" => ["install", "list", "update", "rebuild", "remove"]
	"cache" => ["gc", "clean", "list", "dir"]
	"share" => ["on", "off", "login", "logout", "forget"]
	_ => []
}

# `share` has an optional second word. The other three need one.
needs_sub : Str -> Bool
needs_sub = |command| command == "roc" or command == "tool" or command == "cache"

# The flags with a value (A4). `--platform` has a value only for `init` (Q9).
takes_value : List(Str), Str -> Bool
takes_value = |cmd, flag| match flag {
	"--registry" | "--file" | "--as" | "--ci" | "--path" | "--roc" | "--snapshot" | "--strategy" | "--slots" | "--reason" | "--to" | "--ignore" => Bool.True
	"--target" => cmd == ["probe"]
	"--tag-prefix" => cmd == ["roc", "channel"]
	"--platform" => cmd == ["init"]
	_ => Bool.False
}

# R-FL12, R-FL6, R-FL7, R-FL1: is the flag allowed for the command (the long form words, joined)?
allows : Str, Str -> Bool
allows = |cmd, flag| {
	one_of = |cmds| cmds.contains(cmd)
	resolving = one_of(["install", "remove", "update", "upgrade", "verify"])
	match flag {
		"--json" => cmd != "x"
		"--yes" | "--offline" | "--quiet" | "--registry" => Bool.True
		"--file" => one_of(["install", "remove", "update", "upgrade", "outdated", "why", "list", "patch", "probe", "verify", "audit", "publish", "roc use", "path"])
		"--frozen" | "--no-probe" | "--no-check" | "--snapshot" | "--strategy" => resolving
		"--dry-run" => resolving or one_of(["cache gc", "cache clean", "tool remove"])
		"--slots" => resolving or one_of(["probe", "tool install", "x"])
		"--as" => one_of(["install", "tool install"])
		"--no-pin" => one_of(["install", "update"])
		"--platform" => one_of(["install", "init"])
		"--ci" => cmd == "init"
		"--git" => one_of(["tool install", "x", "roc install", "roc default"])
		"--path" => one_of(["tool install", "x"])
		"--from-source" => cmd == "tool update"
		"-i" => cmd == "update"
		"--diff" => cmd == "patch"
		"--tree" => cmd == "list"
		"--range" | "--share" | "--smoke" | "--target" => cmd == "probe"
		"--all" => cmd == "cache clean"
		"--force" => one_of(["remove", "roc link"])
		"--copy" => cmd == "roc link"
		"--rename-keys" => cmd == "install"
		"--allow-moves" => one_of(["install", "update", "upgrade"])
		"--probe-downloads" => one_of(["upgrade", "probe", "init", "publish"])
		"--allow-downloads" => resolving or one_of(["probe", "roc use", "init"])
		"--roc" | "--allow-unchecked" | "--resolve" => one_of(["tool install", "x"])
		"--remove-tools" | "--keep-all" => cmd == "tool remove"
		"--replace-roc" | "--no-modify-path" => cmd == "setup"
		"--tag-prefix" => cmd == "roc channel"
		"--reason" => cmd == "yank"
		"--to" => cmd == "move"
		"--undo" => one_of(["yank", "move"])
		"--ignore" => cmd == "audit"
		"--tool" => one_of(["install", "remove", "update", "upgrade"])
		"--each" | "--keep-going" => cmd == "run"
		_ => Bool.False
	}
}
