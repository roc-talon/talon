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
	|found, word| if word == "--" Break(found) else Continue(found or word == "--json"),
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
unknown = |typed| usage_stop(typed, "unknown command '${Str.join_with(typed, " ")}'")

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

# The verb aliases (R-CM19).
long_form : Str -> Str
long_form = |word| match word {
	"rm" => "remove"
	"ls" => "list"
	"i" | "add" => "install"
	"up" => "update"
	other => other
}

# The 21 top-level commands of CLI 1, as the long form.
top_level : Str -> Try(Str, [NotCommand])
top_level = |word| {
	long = long_form(word)
	known = ["init", "install", "remove", "update", "upgrade", "outdated", "why", "probe", "list", "patch", "verify", "x", "publish", "audit", "roc", "tool", "cache", "setup", "yank", "move", "share"]
	if known.contains(long) Ok(long) else Err(NotCommand)
}

# The second word of a command (R-CM15 to R-CM17, R-CM23).
sub_words : Str -> List(Str)
sub_words = |command| match command {
	"roc" => ["install", "link", "use", "list", "remove", "default", "update"]
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
		"--file" => one_of(["install", "remove", "update", "upgrade", "outdated", "why", "list", "patch", "probe", "verify", "audit", "publish", "roc use"])
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
		"--range" | "--share" => cmd == "probe"
		"--all" => cmd == "cache clean"
		"--force" => one_of(["remove", "roc link"])
		"--copy" => cmd == "roc link"
		"--rename-keys" => cmd == "install"
		"--allow-moves" => one_of(["install", "update", "upgrade"])
		"--probe-downloads" => resolving or one_of(["probe", "init"])
		"--allow-downloads" => resolving or one_of(["probe", "roc use", "init"])
		"--roc" | "--allow-unchecked" | "--resolve" => one_of(["tool install", "x"])
		"--remove-tools" | "--keep-all" => cmd == "tool remove"
		"--replace-roc" | "--no-modify-path" => cmd == "setup"
		"--reason" => cmd == "yank"
		"--to" => cmd == "move"
		"--undo" => one_of(["yank", "move"])
		"--ignore" => cmd == "audit"
		_ => Bool.False
	}
}
