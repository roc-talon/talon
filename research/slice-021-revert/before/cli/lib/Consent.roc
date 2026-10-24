import Fail
import JsonDoc
import Mode
import Prompt

## The three prompts of P0 (CLI 4, the table of prompts: R-NI1, R-NI2, R-NI3). Each is a value for `Prompt.ask!` (slice 001, R-NM3 to R-NM12). The answer
## flags `--rename-keys` and `--allow-moves` give the answer `Yes` with `flag: Ok(Yes)`, and `--yes` is the `yes` fact (R-NM8, R-NM10). This module has only the
## values and the texts. The commands (slice 007) call `Prompt.ask!` with them. The other prompts of the table (R-NI4 to R-NI16) never show in P0
## (R-PH7: R-NI4, R-NI5, R-NI6 and R-NI12 need a compiler download).
Consent :: [].{

	## R-NI1 (`install`, `add`; Design 4.3 R-I8): rename a stale key of `talon.toml`. A key is stale when the header has its group under another alias.
	## Kind `Required(["--rename-keys"])`, shape yes/no, the interactive default is `Yes`. The non-interactive result with no `--yes` is exit 13 and
	## no write (`Prompt.decide` gives it).
	##
	## | Field | Text (a proposal, TW24) |
	## | --- | --- |
	## | `id` | `rename-keys` |
	## | `question` | `Rename <n> stale key(s) in talon.toml?` (`key` for 1, `keys` for more) |
	## | `subject` | `<n> stale key in talon.toml`, `<n> stale keys in talon.toml` |
	## | `answer_line` | `Yes`: `renamed <n> stale key(s) in talon.toml`. `No`: `kept <n> stale key(s) in talon.toml`. |
	##
	## `report` is the text that the command prints to stderr before it asks or stops (R-I8: "the same report"): one line for each stale key, in order,
	## `talon.toml: key "<key>" is "<name>", which the header names "<alias>"` (the text of `Frozen.check`), each with a line end.
	rename_keys : List({ key : Str, name : Str, alias : Str }) -> { prompt : Prompt, report : Str }
	rename_keys = |stale| {
		count = stale.len()
		what = "${count.to_str()} stale ${plural(count, "key", "keys")} in talon.toml"
		{
			prompt: Prompt.{
				id: "rename-keys",
				kind: Required(["--rename-keys"]),
				shape: YesNo,
				default: Yes,
				question: "Rename ${what}?",
				subject: what,
				answer_line: |answer| if answer == Yes "renamed ${what}" else "kept ${what}",
			},
			report: Str.join_with(stale.map(|s| "talon.toml: key \"${s.key}\" is \"${s.name}\", which the header names \"${s.alias}\"\n"), ""),
		}
	}

	## One held variable that the second search moves (slice 017, R-SP16, R-SP25): `alias` is the alias of its first use, `name` the full name (`Var.name`, else the URL form), `from` and `to` are versions,
	## `why` is the text of `Pick.moves`, `members` are the member files that the move writes: the files that have an entry of the group (R-SP25).
	Move : { alias : Str, name : Str, from : Str, to : Str, why : Str, members : List(Str) }

	## R-NI3 (`add`, `update`, `upgrade`, `install`; Resolution 9 R-SP16, R-SP17, R-SP26): move a held variable. Kind `Required(["--allow-moves"])`, yes/no, the interactive
	## default is `No` (so `--yes` is not the answer of Enter, R-NM8). The command asks once, after the ladder and before the write (R-SP16).
	##
	## | Field | Text (a proposal, TW24) |
	## | --- | --- |
	## | `id` | `allow-moves` |
	## | `question` | `Move the held variable(s) <alias>, <alias>?` (`variable` for 1, `variables` for more) |
	## | `subject` | `moving the held variable(s) <alias>, <alias>` |
	## | `answer_line` | `Yes`: `moved the held variable(s) <alias>, <alias>`. `No`: `kept the held variable(s) <alias>, <alias>`. |
	##
	## `report` is printed on stderr before the question, and also with no person and with `--dry-run` (R-SP17, R-SP26): 2 lines for each move, in order, each with a line end:
	## `~ <alias>: <name> <from> -> <to> (held): <why>` and `  writes <file>, <file>`.
	##
	## `details` is the `error.details` of the failure with exit code 13 (R-J5): `{ "moves": [{ "alias", "name", "from", "to", "why", "members": [<file>, ...] }] }`, the keys in this order.
	move_held : List(Consent.Move) -> { prompt : Prompt, report : Str, details : JsonDoc }
	move_held = |moves| {
		what = held_text(moves)
		{
			prompt: Prompt.{
				id: "allow-moves",
				kind: Required(["--allow-moves"]),
				shape: YesNo,
				default: No,
				question: "Move ${what}?",
				subject: "moving ${what}",
				answer_line: |answer| if answer == Yes "moved ${what}" else "kept ${what}",
			},
			report: Str.join_with(moves.map(|m| "~ ${m.alias}: ${m.name} ${m.from} -> ${m.to} (held): ${m.why}\n  writes ${Str.join_with(m.members, ", ")}\n"), ""),
			details: details_of(moves),
		}
	}

	## R-SP16, R-EC13: the failure when the person answers No (kind `Consent`, exit code 13). Text (a proposal, TW24):
	## `the held variable(s) <alias>, <alias> stay. Nothing was written.` (`variable` and `stays` for 1: `the held variable pf stays. Nothing was written.`).
	## It has the `details` of `move_held`.
	declined : List(Consent.Move) -> Fail
	declined = |moves| {
		stay = if moves.len() == 1 "stays" else "stay"
		{ ..Fail.new(Consent, "${held_text(moves)} ${stay}. Nothing was written."), details: Ok(details_of(moves)) }
	}

	## R-NI2 (`update -i`): a picker (R-NM7), not a prompt. In non-interactive mode it stops with a usage failure (exit 2): `update -i needs a person to pick. Name the packages: tln update X Y.`
	## (the answer column of R-NI2). `Interactive` is `Run`, `NeedsTty` is `NeedTty`, as `Prompt.picker` gives them.
	picker : Mode -> [Run, Stop(Fail), NeedTty]
	picker = |mode| match mode {
		Interactive => Run
		NeedsTty => NeedTty
		NonInteractive => Stop(Consent.no_person)
	}

	## The failure of a picker that has no person (R-NI2, R-NM7): the mode is `NonInteractive`, or the end of input came.
	no_person : Fail
	no_person = Fail.new(Usage, "update -i needs a person to pick. Name the packages: tln update X Y.")
}

held_text : List(Consent.Move) -> Str
held_text = |moves| "the held ${plural(moves.len(), "variable", "variables")} ${Str.join_with(moves.map(|m| m.alias), ", ")}"

# R-J5: `error.details` of a move that needs consent.
details_of : List(Consent.Move) -> JsonDoc
details_of = |moves| JsonDoc.Obj([
	(
		"moves",
		JsonDoc.Arr(
			moves.map(
				|m| JsonDoc.Obj([
					("alias", JsonDoc.Text(m.alias)),
					("name", JsonDoc.Text(m.name)),
					("from", JsonDoc.Text(m.from)),
					("to", JsonDoc.Text(m.to)),
					("why", JsonDoc.Text(m.why)),
					("members", JsonDoc.Arr(m.members.map(|f| JsonDoc.Text(f)))),
				]),
			),
		),
	),
])

plural : U64, Str, Str -> Str
plural = |count, one, many| if count == 1 one else many
