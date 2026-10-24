app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Consent
import lib.Fail
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
	{ alias: "pf", name: "roc-lang/basic-cli", from: "0.25.0", to: "0.26.0", why: "json 2.2.0 needs pf >= 0.26.0", members: ["/w/apps/a/main.roc", "/w/apps/b/main.roc"] },
	{ alias: "json", name: "someone/roc-json", from: "2.1.0", to: "2.2.0", why: "json 2.1.0 is outside =2.2.0", members: ["/w/apps/a/main.roc"] },
]

# R-NI3 R-SP16 R-SP17 R-SP25 R-SP26 R-NM8 R-NR2 R-J5 R-EC13 (slice 017): the prompt "move a held variable". Required, the answer flag is `--allow-moves`, and the interactive default is No: so `--yes` is not
# the answer of Enter (R-NM8). Non-interactive with no `--yes`: exit code 13 and nothing is written. The report (stderr, before the question, also with no person and with `--dry-run`) has 2 lines for each move: the variable with
# its names, its old and new version and the reason (R-SP16), and the member files that the move writes (R-SP25). `details` is `error.details` of the failure with exit 13. The answer No is the failure `declined` (exit 13).
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
		(
			two.report,
			"~ pf: roc-lang/basic-cli 0.25.0 -> 0.26.0 (held): json 2.2.0 needs pf >= 0.26.0\n  writes /w/apps/a/main.roc, /w/apps/b/main.roc\n~ json: someone/roc-json 2.1.0 -> 2.2.0 (held): json 2.1.0 is outside =2.2.0\n  writes /w/apps/a/main.roc\n",
		),
		(
			two.details.render(),
			"{\"moves\":[{\"alias\":\"pf\",\"name\":\"roc-lang/basic-cli\",\"from\":\"0.25.0\",\"to\":\"0.26.0\",\"why\":\"json 2.2.0 needs pf >= 0.26.0\",\"members\":[\"/w/apps/a/main.roc\",\"/w/apps/b/main.roc\"]},{\"alias\":\"json\",\"name\":\"someone/roc-json\",\"from\":\"2.1.0\",\"to\":\"2.2.0\",\"why\":\"json 2.1.0 is outside =2.2.0\",\"members\":[\"/w/apps/a/main.roc\"]}]}",
		),
		(Fail.line(Consent.declined(moves)), "tln: error[consent]: the held variables pf, json stay. Nothing was written."),
		(Fail.line(Consent.declined(moves.take_first(1))), "tln: error[consent]: the held variable pf stays. Nothing was written."),
		(Consent.declined(moves.take_first(1)).details.map_ok(|d| d.render()) ?? "no details", one.details.render()),
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

# R-NI5 R-DL1 R-DL3 R-DL5 R-NM5 R-NM6 R-NM8 R-NR2 (slice 023b): the prompt "download the compiler that a run needs" of the `roc` proxy. Required, with the answer flags of R-NI5 (`Prompt.decide` adds `--yes`), and the interactive default is Yes for the
# proxy (R-DL3). The answer of `TALON_AUTO_INSTALL=yes` is the flag `Ok(Yes)`. The question names the compiler, the rank that chose it, the count and the size (R-DL1).
expect {
	id = "nightly-2026-10-14-38a3029"
	prompt = Consent.proxy_download({ id, source: "the roc: entry of the header", size: 73861067 })
	small = Consent.proxy_download({ id, source: "roc +${id}", size: 453 })
	rows = [
		("no person, no flag: stop", decide(prompt, NonInteractive, Bool.False, Err(NoFlag)), "stop Consent the download of ${id} needs consent. Pass --allow-downloads or TALON_AUTO_INSTALL=yes or --yes."),
		("--yes", decide(prompt, NonInteractive, Bool.True, Err(NoFlag)), "use Yes"),
		("TALON_AUTO_INSTALL=yes", decide(prompt, NonInteractive, Bool.False, Ok(Yes)), "use Yes"),
		("TALON_AUTO_INSTALL=yes with a person", decide(prompt, Interactive, Bool.False, Ok(Yes)), "use Yes"),
		("a person", decide(prompt, Interactive, Bool.False, Err(NoFlag)), "ask"),
		("not known yet", decide(prompt, NeedsTty, Bool.False, Err(NoFlag)), "need-tty"),
	]
	bad_rows = rows.keep_if(|(_, got, want)| got != want).map(|(name, got, _)| (name, got))
	dbg bad_rows
	texts = [
		(prompt.id, "proxy-download"),
		(Prompt.text(prompt), "${id} (the roc: entry of the header) is not installed. Download 1 compiler, 73.9 MB? [Y/n] "),
		(Prompt.text(small), "${id} (roc +${id}) is not installed. Download 1 compiler, 453 B? [Y/n] "),
		((prompt.answer_line)(Yes), "downloading ${id} (73.9 MB)"),
		((prompt.answer_line)(No), "no download of ${id}"),
		(prompt.subject, "the download of ${id}"),
	]
	bad_texts = texts.keep_if(|(got, want)| got != want).map(|(got, want)| (got, want))
	dbg bad_texts
	replies = [
		(Prompt.reply(prompt, ""), Ok(Yes)),
		(Prompt.reply(prompt, "n"), Ok(No)),
		(Prompt.reply(prompt, "Y"), Ok(Yes)),
	]
	bad_replies = replies.keep_if(|(got, want)| got != want).map(|(got, want)| (got, want))
	dbg bad_replies
	bad_rows == [] and bad_texts == [] and bad_replies == []
}

# R-EV6 R-DL5 R-DL9 R-DL10 (slice 023b, moved here in slice 025): `TALON_AUTO_INSTALL`. `ask` and no variable give `Ask` (the default), `yes` gives `Yes`, `no` gives `No`. Any other text counts as not set, so it gives `Ask`,
# also the empty text and another letter case (the answer of the user for `TALON_NIGHTLY`, `docs/slices/ANSWERS.md`). The `roc` proxy and the commands that resolve read it with the same function.
expect {
	auto = |env| Consent.auto_install(env)
	set_to = |text| [("HOME", "/h"), ("TALON_AUTO_INSTALL", text), ("PATH", "/bin")]
	rows = [
		("not set", auto([("HOME", "/h")]), Ask),
		("no variable at all", auto([]), Ask),
		("ask", auto(set_to("ask")), Ask),
		("yes", auto(set_to("yes")), Yes),
		("no", auto(set_to("no")), No),
		("the other variables are not read", auto([("TALON_PROXY", "yes"), ("TALON_AUTO_INSTALL", "no")]), No),
		("true counts as not set", auto(set_to("true")), Ask),
		("1 counts as not set", auto(set_to("1")), Ask),
		("another letter case counts as not set", auto(set_to("YES")), Ask),
		("the empty text counts as not set", auto(set_to("")), Ask),
		("a word with a space counts as not set", auto(set_to("no thanks")), Ask),
	]
	bad_rows = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad_rows
	bad_rows == []
}

# R-NI5 R-DL1 R-DL3 R-DL5 R-NM5 R-NM6 R-NM8 R-NR2 (slice 025): the prompt "download the compiler that the first probe needs" of the commands that resolve. Required, with the answer flags of R-NI5 (`Prompt.decide` adds `--yes`). The interactive default is
# No (R-DL3: the command does not name the download), so Enter is no and `--yes` is the answer of the flag. The answer of `--allow-downloads` and of `TALON_AUTO_INSTALL=yes` is the flag `Ok(Yes)`. The question names the count and the size (R-DL1).
expect {
	id = "nightly-2026-10-14-38a3029"
	prompt = Consent.command_download({ id, count: 1, size: 73861067 })
	small = Consent.command_download({ id, count: 1, size: 453 })
	many = Consent.command_download({ id, count: 2, size: 147361067 })
	rows = [
		("no person, no flag: stop", decide(prompt, NonInteractive, Bool.False, Err(NoFlag)), "stop Consent the download of ${id} needs consent. Pass --allow-downloads or TALON_AUTO_INSTALL=yes or --yes."),
		("--yes", decide(prompt, NonInteractive, Bool.True, Err(NoFlag)), "use Yes"),
		("--yes with a person: no prompt", decide(prompt, Interactive, Bool.True, Err(NoFlag)), "use Yes"),
		("--allow-downloads", decide(prompt, NonInteractive, Bool.False, Ok(Yes)), "use Yes"),
		("--allow-downloads with a person", decide(prompt, Interactive, Bool.False, Ok(Yes)), "use Yes"),
		("a person", decide(prompt, Interactive, Bool.False, Err(NoFlag)), "ask"),
		("not known yet", decide(prompt, NeedsTty, Bool.False, Err(NoFlag)), "need-tty"),
	]
	bad_rows = rows.keep_if(|(_, got, want)| got != want).map(|(name, got, _)| (name, got))
	dbg bad_rows
	texts = [
		(prompt.id, "command-download"),
		(Prompt.text(prompt), "${id} is not installed. Download 1 compiler, 73.9 MB? [y/N] "),
		(Prompt.text(small), "${id} is not installed. Download 1 compiler, 453 B? [y/N] "),
		((prompt.answer_line)(Yes), "downloading ${id} (73.9 MB)"),
		((prompt.answer_line)(No), "no download of ${id}"),
		(prompt.subject, "the download of ${id}"),
		# R-DL1: one prompt for a command, with the count and the total size of all downloads that it covers.
		(Prompt.text(many), "${id} is not installed. Download 2 compilers, 147.4 MB? [y/N] "),
		((many.answer_line)(Yes), "downloading 2 compilers (147.4 MB)"),
		((many.answer_line)(No), "no download of 2 compilers"),
		(many.id, "command-download"),
	]
	bad_texts = texts.keep_if(|(got, want)| got != want).map(|(got, want)| (got, want))
	dbg bad_texts
	replies = [
		(Prompt.reply(prompt, ""), Ok(No)),
		(Prompt.reply(prompt, "y"), Ok(Yes)),
		(Prompt.reply(prompt, "N"), Ok(No)),
	]
	bad_replies = replies.keep_if(|(got, want)| got != want).map(|(got, want)| (got, want))
	dbg bad_replies
	bad_rows == [] and bad_texts == [] and bad_replies == []
}

# R-DL1 R-DL3 R-DL4 R-DL5 R-DL7 R-DL9 R-DL10 R-NI5 R-NM5 R-NM10 R-EV6 (slice 025, question Q1): what a command that resolves does for a compiler that is not installed. A nightly tag is downloaded when the rules allow it. The flag `--allow-downloads`,
# `--yes` and `TALON_AUTO_INSTALL=yes` give the answer Yes with no prompt and no `tty!` call. `TALON_AUTO_INSTALL=no` refuses with no prompt in each mode. With none of them: a person is asked (the default is No), the terminal is asked when that is
# not known, and a run with no person needs consent (`NeedsConsent`: exit 13, `download_stop` gives the text, so the caller reads the list first). A text that is not a nightly tag is never downloaded (as the proxy: Q2 of slice 023b), also with `yes`, and it never asks the terminal.
# `TALON_AUTO_INSTALL=no` refuses with no prompt, unless a flag on the command line (`--allow-downloads`, `--yes`) answers: flag over environment (answer Q1 of the review).
expect {
	a2 = "nightly-2026-10-09-258ab27"
	jul = "nightly-2026-July-31-123c5d7"
	show = |r| match r {
		Refuse => "refuse"
		AutoNo => "auto-no"
		Install => "install"
		Ask => "ask"
		NeedTty => "need-tty"
		NeedsConsent => "needs-consent"
	}
	want = |id, auto, mode, yes, flag| show(Consent.required_want({ id, auto, mode, yes, flag }))
	none = Err(NoFlag)
	flagged = Ok(Yes)
	stop = "needs-consent"
	nightly_rows = [
		("ask, a person", want(a2, Ask, Interactive, Bool.False, none), "ask"),
		("ask, not known yet", want(a2, Ask, NeedsTty, Bool.False, none), "need-tty"),
		("ask, no person (R-DL4)", want(a2, Ask, NonInteractive, Bool.False, none), stop),
		("--allow-downloads, no person", want(a2, Ask, NonInteractive, Bool.False, flagged), "install"),
		("--allow-downloads, a person: no prompt", want(a2, Ask, Interactive, Bool.False, flagged), "install"),
		("--allow-downloads, not known yet: no tty call", want(a2, Ask, NeedsTty, Bool.False, flagged), "install"),
		("--yes, no person (R-DL5)", want(a2, Ask, NonInteractive, Bool.True, none), "install"),
		("--yes, a person: no prompt", want(a2, Ask, Interactive, Bool.True, none), "install"),
		("--yes, not known yet: no tty call", want(a2, Ask, NeedsTty, Bool.True, none), "install"),
		("yes, no person (R-DL9)", want(a2, Yes, NonInteractive, Bool.False, none), "install"),
		("yes, a person: no prompt", want(a2, Yes, Interactive, Bool.False, none), "install"),
		("yes, not known yet: no tty call", want(a2, Yes, NeedsTty, Bool.False, none), "install"),
		("no, a person (R-DL10)", want(a2, No, Interactive, Bool.False, none), "auto-no"),
		("no, not known yet: no tty call", want(a2, No, NeedsTty, Bool.False, none), "auto-no"),
		("no, no person", want(a2, No, NonInteractive, Bool.False, none), "auto-no"),
		# A flag on the command line wins over the variable (answer Q1 of the review: flag over environment).
		("no with --allow-downloads, no person", want(a2, No, NonInteractive, Bool.False, flagged), "install"),
		("no with --allow-downloads, a person: no prompt", want(a2, No, Interactive, Bool.False, flagged), "install"),
		("no with --allow-downloads, not known yet: no tty call", want(a2, No, NeedsTty, Bool.False, flagged), "install"),
		("no with --yes, no person", want(a2, No, NonInteractive, Bool.True, none), "install"),
		("no with --yes, a person: no prompt", want(a2, No, Interactive, Bool.True, none), "install"),
		("no with --yes, not known yet: no tty call", want(a2, No, NeedsTty, Bool.True, none), "install"),
		("the July form, yes", want(jul, Yes, NonInteractive, Bool.False, none), "install"),
		("the July form, ask, a person", want(jul, Ask, Interactive, Bool.False, none), "ask"),
	]
	other_rows = [
		("a prefix, yes", want("nightly-2026-10", Yes, Interactive, Bool.False, none), "refuse"),
		("a prefix, not known yet: no tty call", want("nightly-2026-10", Ask, NeedsTty, Bool.False, none), "refuse"),
		("a link build", want("link-dev", Ask, Interactive, Bool.False, flagged), "refuse"),
		("a git build, no person", want("git-0123abcd", Yes, NonInteractive, Bool.False, none), "refuse"),
		("a copy build", want("copy-x", Ask, Interactive, Bool.True, none), "refuse"),
		("a release version", want("0.1.0", Yes, Interactive, Bool.False, none), "refuse"),
		("a release version, auto no: the P0 refusal, not the variable", want("0.1.0", No, Interactive, Bool.False, none), "refuse"),
		("the empty text", want("", Yes, Interactive, Bool.False, none), "refuse"),
	]
	bad_nightly = nightly_rows.keep_if(|(_, got, want_)| got != want_).map(|(label, got, want_)| (label, want_, got))
	bad_other = other_rows.keep_if(|(_, got, want_)| got != want_).map(|(label, got, want_)| (label, want_, got))
	dbg bad_nightly
	dbg bad_other
	bad_nightly == [] and bad_other == []
}

# R-DL1 R-DL4 R-NI5 R-NM5 R-EC13 (slice 025): the stop of a run with no person and no answer for a required download. Kind Consent (exit 13). The text is the text of the design example of `--json` (CLI 3): the count, the size, the flags.
expect {
	one = Consent.download_stop({ count: 1, size: 73861067 })
	two = Consent.download_stop({ count: 2, size: 147361067 })
	small = Consent.download_stop({ count: 1, size: 453 })
	rows = [
		(Str.inspect(one.kind), "Consent"),
		(one.message, "1 compiler download (73.9 MB) needs consent. Pass --allow-downloads or set TALON_AUTO_INSTALL=yes."),
		(Str.inspect(two.kind), "Consent"),
		(two.message, "2 compiler downloads (147.4 MB) needs consent. Pass --allow-downloads or set TALON_AUTO_INSTALL=yes."),
		(small.message, "1 compiler download (453 B) needs consent. Pass --allow-downloads or set TALON_AUTO_INSTALL=yes."),
	]
	bad = rows.keep_if(|(got, want)| got != want).map(|(got, want)| (got, want))
	dbg bad
	bad == []
}

# R-DL5 R-DL8 R-DL10 R-NI5 R-NM5 R-NM8 R-EC13 (slice 025, answer Q4 of the review): the two refusals that name the way to get the compiler. Kind Consent (exit 13). The text of `TALON_AUTO_INSTALL=no` and the text of an
# interactive No both name `tln roc install <id>`, `--allow-downloads` and `TALON_AUTO_INSTALL=yes`.
expect {
	id = "nightly-2026-10-14-38a3029"
	refused = Consent.download_refused(id)
	declined = Consent.command_declined(id)
	rows = [
		(Str.inspect(refused.kind), "Consent"),
		(refused.message, "the compiler ${id} is not installed. TALON_AUTO_INSTALL=no refuses the download. Run: tln roc install ${id}, pass --allow-downloads, or set TALON_AUTO_INSTALL=yes."),
		(Str.inspect(declined.kind), "Consent"),
		(declined.message, "${id} is not installed. Nothing was downloaded. Run: tln roc install ${id}, pass --allow-downloads, or set TALON_AUTO_INSTALL=yes."),
		# `roc install` keeps its own text.
		(Consent.roc_install_declined(id).message, "${id} is not installed. Nothing was downloaded."),
	]
	bad = rows.keep_if(|(got, want)| got != want).map(|(got, want)| (got, want))
	dbg bad
	bad == []
}

# R-DL5 R-DL10 R-SO13 R-EC13 (slice 025b): rank 4 has a range and no installed compiler is in it, so the id of the download comes from the list. A run with `TALON_AUTO_INSTALL=no` and no answer flag refuses before it reads the list
# (the variable `no` wins only when no flag and no `--yes` answers: the same row as row 2 of `required_want`). The refusal names the range and the 3 ways to get a compiler. Kind Consent (exit 13).
expect {
	refuses = |auto, yes, flag| Consent.auto_refuses({ auto, yes, flag })
	range = ">=nightly-2026-10-09-258ab27"
	refused = Consent.range_refused(range)
	rows = [
		("no, no answer", refuses(No, Bool.False, Err(NoFlag)), Bool.True),
		("no, --yes (a flag wins over the variable)", refuses(No, Bool.True, Err(NoFlag)), Bool.False),
		("no, --allow-downloads", refuses(No, Bool.False, Ok(Yes)), Bool.False),
		("no, both", refuses(No, Bool.True, Ok(Yes)), Bool.False),
		("ask, no answer", refuses(Ask, Bool.False, Err(NoFlag)), Bool.False),
		("yes, no answer", refuses(Yes, Bool.False, Err(NoFlag)), Bool.False),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(name, got, want)| (name, got, want))
	dbg bad
	bad == []
		and Str.inspect(refused.kind) == "Consent"
			and refused.message == "no installed compiler is in [toolchain] roc (${range}). TALON_AUTO_INSTALL=no refuses the download. Run: tln roc install <id> for an id in the range, pass --allow-downloads, or set TALON_AUTO_INSTALL=yes."
}
