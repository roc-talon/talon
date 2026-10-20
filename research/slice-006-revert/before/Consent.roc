import Fail
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

	## R-NI3 (`add`, `update`, `upgrade`, `install`; Resolution 9 R-SP16, R-SP17): move a held variable. Kind `Required(["--allow-moves"])`, yes/no, the interactive
	## default is `No` (so `--yes` is not the answer of Enter, R-NM8). `moves` are the held variables that must move: `id` is the alias or the name,
	## `why` is the reason (`json 2.2.0 needs pf >= 0.26.0`).
	##
	## | Field | Text (a proposal, TW24) |
	## | --- | --- |
	## | `id` | `allow-moves` |
	## | `question` | `Move the held variable(s) <id>, <id>?` |
	## | `subject` | `moving the held variable(s) <id>, <id>` (`variable` for 1, `variables` for more) |
	## | `answer_line` | `Yes`: `moved the held variable(s) <id>, <id>`. `No`: `kept the held variable(s) <id>, <id>`. |
	##
	## `report` is one line for each move, in order: `<why>`, each with a line end (R-SP16: "names the variables that must move and why").
	move_held : List({ id : Str, why : Str }) -> { prompt : Prompt, report : Str }
	move_held = |moves| {
		what = "the held ${plural(moves.len(), "variable", "variables")} ${Str.join_with(moves.map(|m| m.id), ", ")}"
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
			report: Str.join_with(moves.map(|m| "${m.why}\n"), ""),
		}
	}

	## R-NI2 (`update -i`): a picker (R-NM7), not a prompt. In non-interactive mode it stops with a usage failure (exit 2): `update -i needs a person to pick. Name the packages: tln update X Y.`
	## (the answer column of R-NI2). `Interactive` is `Run`, `NeedsTty` is `NeedTty`, as `Prompt.picker` gives them.
	picker : Mode -> [Run, Stop(Fail), NeedTty]
	picker = |mode| match mode {
		Interactive => Run
		NeedsTty => NeedTty
		NonInteractive => Stop(Fail.new(Usage, "update -i needs a person to pick. Name the packages: tln update X Y."))
	}
}

plural : U64, Str, Str -> Str
plural = |count, one, many| if count == 1 one else many
