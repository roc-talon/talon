app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Consent
import lib.Mode
import lib.Prompt

main! = |_args| Ok({})

# A Stop is shown by its kind and its message (R-NM5).
sum = |d| match d {
	Ask => "ask"
	NeedTty => "need-tty"
	Use(a) => "use ${Str.inspect(a)}"
	Stop(f) => "stop ${Str.inspect(f.kind)} ${f.message}"
}

decide = |prompt, mode, yes, flag| sum(Prompt.decide(prompt, { mode, yes, flag }))

stale = [
	{ key: "json", name: "someone/roc-json", alias: "js" },
	{ key: "pf", name: "roc-lang/basic-cli", alias: "basic" },
]

# R-NI1 R-I8 R-NM5 R-NM8 R-NM10 R-NR2: the prompt "rename a stale key of talon.toml". It is a Required prompt with the answer flag `--rename-keys`, and the interactive default is Yes.
# With no person and no `--yes` the decision is exit code 13 (kind consent) and the message names the flag and `--yes`. The report is the text of R-I8.
expect {
	two = Consent.rename_keys(stale)
	one = Consent.rename_keys(stale.take_first(1))
	rows = [
		("no person, no flag: stop", decide(two.prompt, NonInteractive, Bool.False, Err(NoFlag)), "stop Consent 2 stale keys in talon.toml needs consent. Pass --rename-keys or --yes."),
		("one key", decide(one.prompt, NonInteractive, Bool.False, Err(NoFlag)), "stop Consent 1 stale key in talon.toml needs consent. Pass --rename-keys or --yes."),
		("--yes", decide(two.prompt, NonInteractive, Bool.True, Err(NoFlag)), "use Yes"),
		("--rename-keys", decide(two.prompt, NonInteractive, Bool.False, Ok(Yes)), "use Yes"),
		("a person", decide(two.prompt, Interactive, Bool.False, Err(NoFlag)), "ask"),
		("a person and --yes", decide(two.prompt, Interactive, Bool.True, Err(NoFlag)), "use Yes"),
		("a terminal must be tested", decide(two.prompt, NeedsTty, Bool.False, Err(NoFlag)), "need-tty"),
	]
	bad_rows = rows.keep_if(|(_, got, want)| got != want).map(|(name, got, _)| (name, got))
	dbg bad_rows

	texts = [
		(Prompt.text(two.prompt), "Rename 2 stale keys in talon.toml? [Y/n] "),
		(Prompt.text(one.prompt), "Rename 1 stale key in talon.toml? [Y/n] "),
		((two.prompt.answer_line)(Yes), "renamed 2 stale keys in talon.toml"),
		((two.prompt.answer_line)(No), "kept 2 stale keys in talon.toml"),
		((one.prompt.answer_line)(Yes), "renamed 1 stale key in talon.toml"),
		(two.prompt.id, "rename-keys"),
		(
			two.report,
			"talon.toml: key \"json\" is \"someone/roc-json\", which the header names \"js\"\ntalon.toml: key \"pf\" is \"roc-lang/basic-cli\", which the header names \"basic\"\n",
		),
	]
	bad_texts = texts.keep_if(|(got, want)| got != want).map(|(got, want)| (got, want))
	dbg bad_texts

	replies = [
		(Prompt.reply(two.prompt, ""), Ok(Yes)),
		(Prompt.reply(two.prompt, "n"), Ok(No)),
		(Prompt.reply(two.prompt, "YES"), Ok(Yes)),
	]
	bad_replies = replies.keep_if(|(got, want)| got != want).map(|(got, want)| (got, want))
	dbg bad_replies
	bad_rows == [] and bad_texts == [] and bad_replies == []
}

moves = [
	{ id: "pf", why: "json 2.2.0 needs pf >= 0.26.0" },
	{ id: "json", why: "parser 1.3.0 needs json >= 2.2.0" },
]

# R-NI3 R-SP16 R-SP17 R-NM8 R-NR2: the prompt "move a held variable". Required, the answer flag is `--allow-moves`, and the interactive default is No: so `--yes` is not
# the answer of Enter (R-NM8). Non-interactive with no `--yes`: exit code 13 and nothing is written, with the report of R-SP16 (the variables and why).
expect {
	two = Consent.move_held(moves)
	one = Consent.move_held(moves.take_first(1))
	rows = [
		("no person, no flag: stop", decide(two.prompt, NonInteractive, Bool.False, Err(NoFlag)), "stop Consent moving the held variables pf, json needs consent. Pass --allow-moves or --yes."),
		("one variable", decide(one.prompt, NonInteractive, Bool.False, Err(NoFlag)), "stop Consent moving the held variable pf needs consent. Pass --allow-moves or --yes."),
		("--yes", decide(two.prompt, NonInteractive, Bool.True, Err(NoFlag)), "use Yes"),
		("--allow-moves", decide(two.prompt, NonInteractive, Bool.False, Ok(Yes)), "use Yes"),
		("a person", decide(two.prompt, Interactive, Bool.False, Err(NoFlag)), "ask"),
		("a terminal must be tested", decide(two.prompt, NeedsTty, Bool.False, Err(NoFlag)), "need-tty"),
	]
	bad_rows = rows.keep_if(|(_, got, want)| got != want).map(|(name, got, _)| (name, got))
	dbg bad_rows

	texts = [
		(Prompt.text(two.prompt), "Move the held variables pf, json? [y/N] "),
		(Prompt.text(one.prompt), "Move the held variable pf? [y/N] "),
		((two.prompt.answer_line)(Yes), "moved the held variables pf, json"),
		((two.prompt.answer_line)(No), "kept the held variables pf, json"),
		(two.prompt.id, "allow-moves"),
		(two.report, "json 2.2.0 needs pf >= 0.26.0\nparser 1.3.0 needs json >= 2.2.0\n"),
	]
	bad_texts = texts.keep_if(|(got, want)| got != want).map(|(got, want)| (got, want))
	dbg bad_texts

	# The default is No: Enter keeps the held variables.
	replies = [
		(Prompt.reply(two.prompt, ""), Ok(No)),
		(Prompt.reply(two.prompt, "y"), Ok(Yes)),
	]
	bad_replies = replies.keep_if(|(got, want)| got != want).map(|(got, want)| (got, want))
	dbg bad_replies
	bad_rows == [] and bad_texts == [] and bad_replies == []
}

# R-NI2 R-NM7 R-SP14: `update -i` is a picker. With no person it stops with a usage failure (exit 2) and names the way without the picker.
expect {
	view = |r| match r {
		Run => "run"
		NeedTty => "need-tty"
		Stop(f) => "stop ${Str.inspect(f.kind)} ${f.message}"
	}
	rows = [
		(view(Consent.picker(Interactive)), "run"),
		(view(Consent.picker(NeedsTty)), "need-tty"),
		(view(Consent.picker(NonInteractive)), "stop Usage update -i needs a person to pick. Name the packages: tln update X Y."),
	]
	bad = rows.keep_if(|(got, want)| got != want).map(|(got, want)| (got, want))
	dbg bad
	bad == []
}
