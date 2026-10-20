import Answer
import Fail
import Fx
import Mode
import Out

## A prompt (CLI 4). `kind` is Default (R-NM4), Required (R-NM5) with the answer flags that
## answer it alone (R-NR6), or Consent (R-NM12). `default` is the interactive default.
## `question` is the text of the interactive prompt, `subject` is a noun phrase for the failure message
## of a Required prompt ("1 stale key in talon.toml"), and `answer_line` is the text of the answer line
## that Talon prints when it answers with no prompt (R-NM6). The command gives all three.
Prompt := {
	id : Str,
	kind : [Default, Required(List(Str)), Consent],
	shape : [YesNo, Options(U64)],
	default : Answer,
	question : Str,
	subject : Str,
	answer_line : Answer -> Str,
}.{

	## What to do with a prompt (R-NM3 to R-NM12, R-NR1).
	## Order of the rules:
	##  1. `flag` is the answer flag of this prompt. When it is set, `Use(flag)`. It wins over `--yes` (R-NM10).
	##  2. `yes` and the kind is not Consent: `Use(Yes)` for a yes/no prompt, `Use(default)` for a prompt with options (R-NM8, R-NM9).
	##  3. mode `NeedsTty`: `NeedTty`. The command asks the terminal and calls again.
	##  4. mode `Interactive`: `Ask`.
	##  5. mode `NonInteractive`: Default gives `Use(default)` (R-NM4). Consent gives `Use(No)` (R-NM12).
	##     Required gives `Stop(fail)`: kind `Consent`, a message that names each answer flag and `--yes` (R-NM5).
	##     Proposal (TW24) for the message: `<subject> needs consent. Pass <flag> or <flag> or --yes.`
	##     The flags are in the order of the `Required` list, then `--yes`, joined by ` or `.
	decide : Prompt, { mode : Mode, yes : Bool, flag : Try(Answer, [NoFlag]) } -> [Ask, Use(Answer), Stop(Fail), NeedTty]
	decide = |prompt, facts| match facts.flag {
		Ok(answer) => Use(answer)
		Err(NoFlag) => decide_without_flag(prompt, facts)
	}

	## The answer in a typed line. Proposal (TW24): yes/no accepts `y`, `yes`, `n`, `no` in any
	## case. Options accepts the number of an option, from 1 to the count. An empty line
	## (after trim) is the default. Anything else is `Invalid`.
	reply : Prompt, Str -> Try(Answer, [Invalid])
	reply = |prompt, line| {
		typed = line.trim().with_ascii_lowercased()
		if typed == "" {
			Ok(prompt.default)
		} else {
			match prompt.shape {
				YesNo => match typed {
					"y" | "yes" => Ok(Yes)
					"n" | "no" => Ok(No)
					_ => Err(Invalid)
				}
				Options(count) => match U64.from_str(typed) {
					Ok(n) if n >= 1 and n <= count => Ok(Option(n))
					_ => Err(Invalid)
				}
			}
		}
	}

	## The text that `ask!` shows. It shows the default (R-NR2). Proposal (TW24):
	## yes/no: `<question> [Y/n] ` when the default is Yes, `<question> [y/N] ` when it is No.
	## Options: `<question> [1-<count>, default <n>] `.
	text : Prompt -> Str
	text = |prompt| match prompt.shape {
		YesNo => if prompt.default == Yes "${prompt.question} [Y/n] " else "${prompt.question} [y/N] "
		Options(count) => {
			default_option = match prompt.default {
				Option(n) => n
				_ => 1
			}
			"${prompt.question} [1-${count.to_str()}, default ${default_option.to_str()}] "
		}
	}

	## A picker (R-NM7) is the whole command: with no person it stops with a usage failure (exit code 2).
	picker : Mode -> [Run, Stop(Fail), NeedTty]
	picker = |mode| match mode {
		Interactive => Run
		NeedsTty => NeedTty
		NonInteractive => Stop(Fail.new(Usage, "this command is a picker and needs interactive mode"))
	}

	## Command code: ask one prompt. The caller computes the mode once (`Mode.from_env`) and passes the
	## `mode` that comes back from the last call, so `fx.tty!` runs at most once in a command (R-HF1).
	## It uses `decide`. For `NeedTty` it calls `fx.tty!`, then `Mode.with_tty`, then `decide` again.
	## For `Ask` it calls `fx.ask!(text)` once and reads the reply with `reply`: no answer line then.
	## For `Use` it prints the answer line and a newline to stderr (R-NM6, the same text in both modes).
	## `quiet` does not hide it (R-FL4). `Stop` is the `Err`. It writes no file.
	## An invalid reply asks again. The end of input gives the non-interactive answer, and the mode
	## that comes back is `NonInteractive` (Q4). A Consent prompt with no answer gets No and no answer line (Q6).
	ask! : Fx, Prompt, { mode : Mode, yes : Bool, quiet : Bool, flag : Try(Answer, [NoFlag]) } => Try({ answer : Answer, mode : Mode }, Fail)
	ask! = |fx, prompt, facts| match Prompt.decide(prompt, { mode: facts.mode, yes: facts.yes, flag: facts.flag }) {
		NeedTty => {
			mode = Mode.with_tty(facts.mode, fx.tty!())
			Prompt.ask!(fx, prompt, { ..facts, mode })
		}
		Ask => ask_person!(fx, prompt, facts)
		Use(answer) => {
			# R-NM12: a Consent prompt that nobody answered gets No, and Talon writes no answer line.
			unanswered_consent = is_consent(prompt) and facts.flag == Err(NoFlag)
			if !unanswered_consent and Out.show(facts.quiet, Answer) {
				fx.err!("${(prompt.answer_line)(answer)}\n")
			}
			Ok({ answer, mode: facts.mode })
		}
		Stop(fail) => Err(fail)
	}
}

decide_without_flag : Prompt, { mode : Mode, yes : Bool, flag : Try(Answer, [NoFlag]) } -> [Ask, Use(Answer), Stop(Fail), NeedTty]
decide_without_flag = |prompt, facts| {
	if facts.yes and !is_consent(prompt) {
		match prompt.shape {
			YesNo => Use(Yes)
			Options(_) => Use(prompt.default)
		}
	} else {
		match facts.mode {
			NeedsTty => NeedTty
			Interactive => Ask
			NonInteractive => match prompt.kind {
				Default => Use(prompt.default)
				Consent => Use(No)
				Required(flags) => Stop(
					Fail.new(Consent, "${prompt.subject} needs consent. Pass ${Str.join_with(flags.append("--yes"), " or ")}."),
				)
			}
		}
	}
}

is_consent : Prompt -> Bool
is_consent = |prompt| match prompt.kind {
	Consent => Bool.True
	_ => Bool.False
}

# Ask the person. An invalid reply asks again. The end of input gives the non-interactive answer (Q4).
ask_person! : Fx, Prompt, { mode : Mode, yes : Bool, quiet : Bool, flag : Try(Answer, [NoFlag]) } => Try({ answer : Answer, mode : Mode }, Fail)
ask_person! = |fx, prompt, facts| match fx.ask!(Prompt.text(prompt)) {
	Ok(line) => match Prompt.reply(prompt, line) {
		Ok(answer) => Ok({ answer, mode: facts.mode })
		Err(Invalid) => ask_person!(fx, prompt, facts)
	}
	Err(EndOfInput) => Prompt.ask!(fx, prompt, { mode: NonInteractive, yes: Bool.False, quiet: facts.quiet, flag: Err(NoFlag) })
}
