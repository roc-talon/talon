app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Args

main! = |_args| Ok({})

# The error is one text: kind, `--json` as read, the command words as typed. (A record with a Bool as the
# error value made the pinned compiler crash in `roc test`, so the tests use a text.)
bad_text = |e| "${Str.inspect(e.fail.kind)} json=${Str.inspect(e.json)} typed=${e.typed}"

view = |words| match Args.parse(words) {
	Ok(a) => Ok(a)
	Err(e) => Err(bad_text(e))
}

shape = |words| match view(words) {
	Ok(a) => Ok((a.command, a.typed, a.operands))
	Err(e) => Err(e)
}

# R-CM19 R-CM20: a verb alias is the same command at every level. `command` has the long form.
# `typed` keeps the words as typed: the `--json` envelope names the command as typed (the design example
# of `tln add` has "command": "add").
expect {
	rows = [
		(["install"], Ok((["install"], "install", []))),
		(["add", "json"], Ok((["install"], "add", ["json"]))),
		(["i"], Ok((["install"], "i", []))),
		(["rm", "json"], Ok((["remove"], "rm", ["json"]))),
		(["remove", "json"], Ok((["remove"], "remove", ["json"]))),
		(["ls"], Ok((["list"], "ls", []))),
		(["up", "json"], Ok((["update"], "up", ["json"]))),
		(["update"], Ok((["update"], "update", []))),
		(["why", "parser"], Ok((["why"], "why", ["parser"]))),
		(["tool", "rm", "app"], Ok((["tool", "remove"], "tool rm", ["app"]))),
		(["tool", "ls"], Ok((["tool", "list"], "tool ls", []))),
		(["tool", "i", "owner/app"], Ok((["tool", "install"], "tool i", ["owner/app"]))),
		(["tool", "up", "app"], Ok((["tool", "update"], "tool up", ["app"]))),
		(["roc", "rm", "id"], Ok((["roc", "remove"], "roc rm", ["id"]))),
		(["roc", "i", "ref"], Ok((["roc", "install"], "roc i", ["ref"]))),
		(["roc", "up"], Ok((["roc", "update"], "roc up", []))),
		(["cache", "ls"], Ok((["cache", "list"], "cache ls", []))),
	]
	bad = rows.keep_if(|(words, want)| shape(words) != want).map(|(words, want)| (words, want, shape(words)))
	dbg bad
	bad == []
}

# R-FL1 R-FL2 R-FL3 R-FL4 R-FL6 R-CM12: the global flags work before and after the command words.
# A flag with a value takes the next word. Other flags go to `options` in the order of the line.
# Words after a bare `--` are never parsed.
expect {
	got = |words| match view(words) {
		Ok(a) => Ok((a.json, a.yes, a.offline, a.quiet, a.registry, a.file, a.operands, a.options, a.passthrough))
		Err(e) => Err(e)
	}
	none = Err(Unset)
	rows = [
		(["--json", "list"], Ok((Bool.True, Bool.False, Bool.False, Bool.False, none, none, [], [], []))),
		(["list", "--json"], Ok((Bool.True, Bool.False, Bool.False, Bool.False, none, none, [], [], []))),
		(["list", "--yes", "--offline", "--quiet"], Ok((Bool.False, Bool.True, Bool.True, Bool.True, none, none, [], [], []))),
		(["--registry", "direct", "list"], Ok((Bool.False, Bool.False, Bool.False, Bool.False, Ok("direct"), none, [], [], []))),
		(["list", "--registry", "https://r.example"], Ok((Bool.False, Bool.False, Bool.False, Bool.False, Ok("https://r.example"), none, [], [], []))),
		(["install", "json", "--file", "app/main.roc"], Ok((Bool.False, Bool.False, Bool.False, Bool.False, none, Ok("app/main.roc"), ["json"], [], []))),
		(["install", "--as", "j", "json"], Ok((Bool.False, Bool.False, Bool.False, Bool.False, none, none, ["json"], [("--as", Ok("j"))], []))),
		(["add", "--no-pin", "json@=1.0.0", "--no-check"], Ok((Bool.False, Bool.False, Bool.False, Bool.False, none, none, ["json@=1.0.0"], [("--no-pin", none), ("--no-check", none)], []))),
		(["x", "owner/app", "--", "--json", "-i"], Ok((Bool.False, Bool.False, Bool.False, Bool.False, none, none, ["owner/app"], [], ["--json", "-i"]))),
	]
	bad = rows.keep_if(|(words, want)| got(words) != want).map(|(words, want)| (words, want, got(words)))
	dbg bad
	bad == []
}

# R-FL12 R-FL6 R-FL7 R-FL1 R-EC2 R-E2: a flag that the command does not take is a usage failure (kind Usage).
# A command that is not known is a usage failure too. The error has `--json` as far as it was read,
# and the command words as typed. The messages are a proposal (TW24).
expect {
	usage = |json, typed| Err("Usage json=${Str.inspect(json)} typed=${typed}")
	only_kind = |words| match view(words) {
		Ok(_) => Ok({})
		Err(text) => Err(text)
	}
	rows = [
		(["frobnicate"], usage(Bool.False, "frobnicate")),
		(["--json", "frobnicate"], usage(Bool.True, "frobnicate")),
		(["frobnicate", "--json"], usage(Bool.True, "frobnicate")),
		(["tool", "frob"], usage(Bool.False, "tool frob")),
		(["list", "--frobnicate"], usage(Bool.False, "list")),
		(["list", "--json", "--frobnicate"], usage(Bool.True, "list")),
		(["list", "--strategy", "lowest"], usage(Bool.False, "list")),
		(["why", "parser", "--slots", "2"], usage(Bool.False, "why")),
		(["cache", "gc", "--file", "main.roc"], usage(Bool.False, "cache gc")),
		(["cache", "gc", "--all"], usage(Bool.False, "cache gc")),
		(["install", "--force"], usage(Bool.False, "install")),
		# R-FL12 (slice 024b, G4 of slice 024): `--copy` is a flag of `roc link` only.
		(["install", "json", "--copy"], usage(Bool.False, "install")),
		(["roc", "install", "--copy", "nightly-2026-10-09-258ab27"], usage(Bool.False, "roc install")),
		(["roc", "rm", "--copy", "link-dev"], usage(Bool.False, "roc rm")),
		(["remove", "json", "--copy"], usage(Bool.False, "remove")),
		(["roc", "link", "--copy=yes", "dev", "p"], usage(Bool.False, "roc link")),
		(["roc", "link", "--frobnicate", "dev", "p"], usage(Bool.False, "roc link")),
		(["remove", "json", "--as", "x"], usage(Bool.False, "remove")),
		(["x", "owner/app", "--json"], usage(Bool.True, "x")),
		(["--registry"], usage(Bool.False, "")),
		(["install", "--as"], usage(Bool.False, "install")),
	]
	bad = rows.keep_if(|(words, want)| only_kind(words) != want).map(|(words, want)| (words, want, only_kind(words)))
	dbg bad
	bad == []
}

# R-FL12 R-FL7 R-FL6 R-NI4 R-NI5 (slice 025: the answer flags of the download prompts): the flags that the design names for a command are accepted.
# Resolve flags: install, remove, update, upgrade, verify, and `--slots` also for probe, tool install and x.
# `--file`: the commands that use a project (R-PD14). `--dry-run` has its own meaning for cache gc and clean.
expect {
	accepted = [
		["install", "--frozen"],
		["install", "json", "--no-probe", "--dry-run", "--strategy", "highest", "--slots", "4", "--snapshot", "log:5"],
		["add", "json", "--platform", "--as", "j", "--rename-keys", "--allow-moves"],
		["remove", "json", "--force", "--no-check"],
		["rm", "json", "--file", "main.roc"],
		["update", "-i"],
		["up", "json", "--strategy", "lowest", "--no-pin", "--allow-moves"],
		["upgrade", "--strategy", "highest", "--allow-moves"],
		["verify", "--strategy", "lowest", "--slots", "2"],
		["install", "--allow-downloads", "--probe-downloads"],
		["add", "json", "--allow-downloads"],
		["update", "json", "--allow-downloads", "--probe-downloads"],
		["remove", "json", "--allow-downloads"],
		["verify", "--allow-downloads", "--probe-downloads"],
		["list", "--tree", "--file", "main.roc"],
		["ls", "--tree"],
		["why", "parser", "--file", "main.roc"],
		["probe", "--slots", "2"],
		["roc", "link", "dev", "../roc/zig-out/bin/roc"],
		["roc", "link", "--copy", "fix-1", "../roc/zig-out/bin/roc", "--json"],
		["roc", "link", "--copy", "--force", "fix-1", "p", "--yes", "--quiet"],
		["roc", "update"],
		["roc", "up", "--json", "--yes", "--offline", "--quiet"],
		["cache", "gc", "--dry-run"],
		["cache", "clean", "--all", "--dry-run"],
		["tool", "install", "owner/app", "--as", "app", "--slots", "2"],
		["--quiet", "--json", "--yes", "--offline", "--registry", "direct", "list"],
	]
	bad = accepted.keep_if(|words| Args.parse(words).is_err())
	dbg bad
	bad == []
}

# R-FL12 R-EC2: the failure message names the flag and the command in the long form (R-CM19).
expect {
	msg = |words| match Args.parse(words) {
		Ok(_) => ""
		Err(e) => e.fail.message
	}
	msgs = [
		msg(["frobnicate"]),
		msg(["tool", "frob"]),
		msg(["rm", "json", "--tree"]),
		msg(["list", "--frobnicate"]),
		msg(["cache", "gc", "--file", "main.roc"]),
		msg(["--registry"]),
		msg(["list", "--allow-downloads"]),
		msg(["roc", "install", "@latest", "--allow-downloads"]),
		msg(["cache", "gc", "--probe-downloads"]),
		msg(["roc", "update", "--file", "main.roc"]),
		msg(["roc", "up", "--allow-downloads"]),
	]
	dbg msgs
	msgs == [
		"unknown command 'frobnicate'",
		"unknown command 'tool frob'",
		"flag '--tree' is not for 'remove'",
		"flag '--frobnicate' is not for 'list'",
		"flag '--file' is not for 'cache gc'",
		"flag '--registry' needs a value",
		"flag '--allow-downloads' is not for 'list'",
		"flag '--allow-downloads' is not for 'roc install'",
		"flag '--probe-downloads' is not for 'cache gc'",
		"flag '--file' is not for 'roc update'",
		"flag '--allow-downloads' is not for 'roc update'",
	]
}
