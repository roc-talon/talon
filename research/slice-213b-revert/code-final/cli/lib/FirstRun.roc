import Answer
import Mode
import Net
import Prompt
import Share

## The first-run sharing prompt, the pure part (slice 214, CLI 1 R-SH11, CLI 4 R-NI16, R-NM12). The calls are in `FirstRunFlow`.
##
## When `share` is not set in `config.toml`, the first command that runs in interactive mode asks R-NI16 before its work. The decision is in 3 steps, so that a run that
## needs no more facts stops early and makes no more `Fx` call: `of_command` needs the arguments only, `gate` needs the environment, `need` needs `config.toml`.
FirstRun :: [].{

	## Why a command does not ask.
	##
	## | Tag | Case | Rule |
	## | --- | --- | --- |
	## | `Command` | `tln share` and its words, `tln setup` | R-SH11 table rows 1 and 2 |
	## | `NonInteractive` | The mode is non-interactive by `--json`, `CI`, `DEBIAN_FRONTEND`, `NONINTERACTIVE` or `TALON_INTERACTIVE=0` (`Mode.from_env`). Talon uses the answer No and writes nothing. | R-NM1, R-NM2, R-NM12 |
	## | `DoNotTrack` | Condition 4 of R-SH2 is false (`DO_NOT_TRACK`, R-EV26) | R-SH11 table row 5 |
	## | `Ci` | Condition 5 of R-SH2 is false. Only with `TALON_INTERACTIVE=1`: else `NonInteractive` comes first. | R-SH11 table row 5 |
	## | `Set` | `share` is `true` or `false` in `config.toml`: Talon asks once | R-SH11 |
	## | `Direct` | Condition 2 of R-SH2 is false: the registry is `direct` | R-SH11 table row 5 |
	## | `Asked` | The variable `TALON_SHARE_ASKED` is `1` (slice 213b): a `tln` of this process tree asked already | R-SH11, R-EV29, Design Q215 |
	Why : [Command, NonInteractive, DoNotTrack, Ci, Set, Direct, Asked]

	## Step 0, pure, from the arguments only, before any `Fx` call: `tln share` (any further word) and `tln setup` give `Skip(Command)` (R-SH11 table rows 1 and 2). Else `Check`.
	## So these commands make no call for the prompt, and their `calls.log` does not change. `command` is `Args.command`.
	of_command : List(Str) -> [Skip(FirstRun.Why), Check]
	of_command = |command| match command {
		["share", ..] | ["setup"] => Skip(Command)
		_ => Check
	}

	## Step 1, pure, from the environment and `--json`. The first match in this order gives `Skip`. Else `NeedTty`.
	##
	## | # | Check | Gives |
	## | --- | --- | --- |
	## | 1 | `Mode.from_env({ env, json })` is `NonInteractive` | `Skip(NonInteractive)` |
	## | 2 | `Share.state` of the environment: the condition `DO_NOT_TRACK` is false (R-EV26: set, not empty, not `0`) | `Skip(DoNotTrack)` |
	## | 3 | `Share.state` of the environment: the condition `CI` is false (`true` or `1`, any case, R-SH2 row 5) | `Skip(Ci)` |
	##
	## Slice 213b (R-SH11, R-EV29, Design Q215): a 4th check gives `Skip(Asked)` when the env has `TALON_SHARE_ASKED` with the value `1` (exactly). The place of this check among the others is not fixed: no test has an env where 2 checks are true. A value other than `1` is the open question Q2 of slice 213b: no test.
	##
	## `--offline` (condition 3 of R-SH2) is not a case: R-SH11 does not list it, so a run with `--offline` asks. `TALON_REGISTRY` is not read here (step 2 reads the registry).
	gate : { env : List((Str, Str)), json : Bool } -> [Skip(FirstRun.Why), NeedTty]
	gate = |facts| if Mode.from_env({ env: Dict.from_list(facts.env), json: facts.json }) == NonInteractive {
		Skip(NonInteractive)
	} else {
		# Only the conditions 4 and 5 of R-SH2 are read: the other facts are fixed to true.
		state = Share.state({ share: Ok(Bool.True), registry: Url("-"), offline: Bool.False, env: facts.env })
		match state {
			Off(DoNotTrack) => Skip(DoNotTrack)
			Off(Ci) => Skip(Ci)
			_ => if List.contains(facts.env, ("TALON_SHARE_ASKED", "1")) Skip(Asked) else NeedTty
		}
	}

	## Slice 213b (R-SH11, R-EV29): the env of a child process, and of the `Fx` that the command gets, after a `tln` asked or saw `TALON_SHARE_ASKED=1`. The name `TALON_SHARE_ASKED` is set to `1`:
	## an entry with this name (any value) is removed, and `("TALON_SHARE_ASKED", "1")` is added at the end. The other entries keep their order. So the name is there once.
	child_env : List((Str, Str)) -> List((Str, Str))
	child_env = |env| List.append(List.keep_if(env, |entry| entry.0 != "TALON_SHARE_ASKED"), ("TALON_SHARE_ASKED", "1"))

	## Step 2, pure, after the terminal test and the read of `config.toml`: `share` is the key `share` (`Share.setting`), `registry` is the registry of the run (`Net.registry`).
	## `share` set (`Ok(_)`, true or false) gives `Skip(Set)`. Else a `Direct` registry gives `Skip(Direct)`. Else `Ask`.
	need : { share : Try(Bool, [Unset]), registry : Net.Registry } -> [Skip(FirstRun.Why), Ask]
	need = |facts| match facts.share {
		Ok(_) => Skip(Set)
		Err(Unset) => if facts.registry == Direct Skip(Direct) else Ask
	}

	## What Talon writes after `Prompt.ask!` (R-SH11, R-NM12). The command passed the mode `Interactive`, so a returned mode that is `NonInteractive` means the end of input
	## (`Prompt.ask!` gives No and the mode `NonInteractive`): `Nothing`, `share` stays not set. Else `Yes` gives `Write(true)` and `No` gives `Write(false)`.
	## Any other answer is `Nothing`.
	written : { answer : Answer, mode : Mode } -> [Write(Bool), Nothing]
	written = |facts| if facts.mode == NonInteractive {
		Nothing
	} else {
		match facts.answer {
			Yes => Write(Bool.True)
			No => Write(Bool.False)
			Option(_) => Nothing
		}
	}

	## R-NI16 (proposal, TW24): the prompt. Kind `Consent`, yes/no, default No, no answer flag.
	##
	## | Field | Value |
	## | --- | --- |
	## | `id` | `share` |
	## | `kind` | `Consent` |
	## | `shape` | `YesNo` |
	## | `default` | `No` |
	## | `subject` | `sharing probe results` |
	## | `question` | the 6 lines below, joined with a line end |
	## | `answer_line` | `Yes`: `sharing: on`. `No`: `sharing: off`. (A Consent prompt with no flag never shows it: R-NM12.) |
	##
	## The text of `Prompt.text` is the question, a space, `[y/N]` and a space. The question lines:
	##
	## ```
	## Talon can share the results of its probes with the registry.
	## For a public package it sends the hash of the package, the compiler, the target, the Talon version and the result (pass, fail or crash). It sends no code, no path and no error text.
	## The registry keeps each result with a random id of this machine until you run tln share forget, or until its compiler is 12 months old.
	## Reading compatibility data does not need sharing.
	## You can turn sharing off at any time with tln share off.
	## Share the probe results of public packages?
	## ```
	prompt : {} -> Prompt
	prompt = |_none| {
		id: "share",
		kind: Consent,
		shape: YesNo,
		default: No,
		question: Str.join_with(
			[
				"Talon can share the results of its probes with the registry.",
				"For a public package it sends the hash of the package, the compiler, the target, the Talon version and the result (pass, fail or crash). It sends no code, no path and no error text.",
				"The registry keeps each result with a random id of this machine until you run tln share forget, or until its compiler is 12 months old.",
				"Reading compatibility data does not need sharing.",
				"You can turn sharing off at any time with tln share off.",
				"Share the probe results of public packages?",
			],
			"\n",
		),
		subject: "sharing probe results",
		answer_line: |answer| if answer == Yes "sharing: on" else "sharing: off",
	}
}
