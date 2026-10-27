import lib.Answer
import lib.Mode
import lib.Prompt

PromptTest :: [].{}

mk = |kind, shape, default| Prompt.{
	id: "p",
	kind,
	shape,
	default,
	question: "Do it?",
	subject: "a thing",
	answer_line: |a| "answered ${Str.inspect(a)}",
}

yesno = |kind, default| mk(kind, YesNo, default)

options = |kind, n, default| mk(kind, Options(n), default)

# A Stop is compared by its kind and by the flags that its message names (R-NM5).
sum = |d| match d {
	Ask => "ask"
	NeedTty => "need-tty"
	Use(a) => "use ${Str.inspect(a)}"
	Stop(f) => "stop ${Str.inspect(f.kind)} ${f.message}"
}

# R-NM1 R-NM3 R-NM4 R-NM5 R-NM12 R-NR5: with no person (NonInteractive) a Default prompt gets its
# interactive default, a Consent prompt gets No, and a Required prompt stops with exit kind Consent.
# The message names each answer flag and --yes. The behavior does not depend on anything else (R-NR5).
expect {
	decide = |p| Prompt.decide(p, { mode: NonInteractive, yes: Bool.False, flag: Err(NoFlag) })
	rows = [
		(decide(yesno(Default, Yes)), "use Yes"),
		(decide(yesno(Default, No)), "use No"),
		(decide(options(Default, 3, Option(2))), "use Option(2)"),
		(decide(yesno(Consent, Yes)), "use No"),
		(decide(yesno(Required(["--allow-moves"]), No)), "stop Consent a thing needs consent. Pass --allow-moves or --yes."),
		(decide(yesno(Required(["--rename-keys", "--alt"]), Yes)), "stop Consent a thing needs consent. Pass --rename-keys or --alt or --yes."),
	]
	bad = rows.map(|(got, want)| (sum(got), want)).keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-NM8 R-NM9 R-NM10 R-NR6: --yes answers every prompt but a Consent prompt, in both modes. Yes/no gives Yes
# (also for a default No). Options give the default option. An answer flag wins over --yes.
# A Consent prompt keeps the answer No with no person, and is asked when there is a person.
expect {
	decide = |p, mode, yes, flag| Prompt.decide(p, { mode, yes, flag })
	no_flag = Err(NoFlag)
	rows = [
		(decide(yesno(Default, No), NonInteractive, Bool.True, no_flag), "use Yes"),
		(decide(yesno(Default, No), Interactive, Bool.True, no_flag), "use Yes"),
		(decide(yesno(Default, No), NeedsTty, Bool.True, no_flag), "use Yes"),
		(decide(options(Default, 2, Option(1)), NonInteractive, Bool.True, no_flag), "use Option(1)"),
		(decide(options(Required(["--roc"]), 3, Option(1)), Interactive, Bool.True, no_flag), "use Option(1)"),
		(decide(yesno(Required(["--allow-moves"]), No), NonInteractive, Bool.True, no_flag), "use Yes"),
		(decide(yesno(Consent, No), NonInteractive, Bool.True, no_flag), "use No"),
		(decide(yesno(Consent, No), Interactive, Bool.True, no_flag), "ask"),
		(decide(yesno(Required(["--allow-moves"]), Yes), NonInteractive, Bool.True, Ok(No)), "use No"),
		(decide(yesno(Required(["--allow-moves"]), Yes), NonInteractive, Bool.False, Ok(No)), "use No"),
		(decide(yesno(Required(["--allow-moves"]), No), Interactive, Bool.False, Ok(Yes)), "use Yes"),
		(decide(yesno(Required(["--allow-moves"]), No), NeedsTty, Bool.False, Ok(Yes)), "use Yes"),
	]
	bad = rows.map(|(got, want)| (sum(got), want)).keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-NM2 R-NR1 R-HF1: with a person (Interactive) the prompt is asked. When the terminal is not known yet
# (NeedsTty) and nothing else answers, the command must test the terminal first.
expect {
	decide = |p, mode| Prompt.decide(p, { mode, yes: Bool.False, flag: Err(NoFlag) })
	rows = [
		(decide(yesno(Default, Yes), Interactive), "ask"),
		(decide(yesno(Required(["--x"]), Yes), Interactive), "ask"),
		(decide(yesno(Consent, No), Interactive), "ask"),
		(decide(yesno(Default, Yes), NeedsTty), "need-tty"),
		(decide(yesno(Required(["--x"]), Yes), NeedsTty), "need-tty"),
		(decide(yesno(Consent, No), NeedsTty), "need-tty"),
	]
	bad = rows.map(|(got, want)| (sum(got), want)).keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-NM7 R-NR4 R-EC2: a picker is the whole command. With no person it stops with a usage failure.
expect {
	pick = |mode| match Prompt.picker(mode) {
		Run => "run"
		NeedTty => "need-tty"
		Stop(f) => "stop ${Str.inspect(f.kind)}"
	}
	picks = [pick(Interactive), pick(NeedsTty), pick(NonInteractive)]
	dbg picks
	picks == ["run", "need-tty", "stop Usage"]
}

# R-NR2: a prompt shows its default. Proposal (TW24): `<question> [Y/n] `, `[y/N]`, `[1-<count>, default <n>] `.
# A typed line: `y`, `yes`, `n`, `no` in any case, or the number of an option. An empty line is the default.
expect {
	reply = |p, line| Prompt.reply(p, line)
	texts = [
		Prompt.text(yesno(Default, Yes)),
		Prompt.text(yesno(Default, No)),
		Prompt.text(options(Default, 3, Option(2))),
	]
	yn = yesno(Default, No)
	op = options(Default, 3, Option(2))
	replies = [
		reply(yn, "y"),
		reply(yn, "YES"),
		reply(yn, " n "),
		reply(yn, "No"),
		reply(yn, ""),
		reply(yn, "   "),
		reply(yn, "maybe"),
		reply(yn, "1"),
		reply(op, "1"),
		reply(op, "3"),
		reply(op, ""),
		reply(op, "0"),
		reply(op, "4"),
		reply(op, "y"),
	]
	dbg (texts, replies)
	texts == ["Do it? [Y/n] ", "Do it? [y/N] ", "Do it? [1-3, default 2] "]
		and replies == [
			Ok(Yes),
			Ok(Yes),
			Ok(No),
			Ok(No),
			Ok(No),
			Ok(No),
			Err(Invalid),
			Err(Invalid),
			Ok(Option(1)),
			Ok(Option(3)),
			Ok(Option(2)),
			Err(Invalid),
			Err(Invalid),
			Err(Invalid),
		]
}
