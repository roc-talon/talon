import Answer
import Fail
import JsonDoc
import Mode
import Pin
import Prompt
import Toolchain

## The three prompts of P0 (CLI 4, the table of prompts: R-NI1, R-NI2, R-NI3). Each is a value for `Prompt.ask!` (slice 001, R-NM3 to R-NM12). The answer
## flags `--rename-keys` and `--allow-moves` give the answer `Yes` with `flag: Ok(Yes)`, and `--yes` is the `yes` fact (R-NM8, R-NM10). This module has only the
## values and the texts. The commands (slice 007) call `Prompt.ask!` with them. Slices 021, 023b and 025 add the prompts of the compiler downloads (R-NI5, R-NI6).
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

	## R-NI13 (`setup`; CLI 6.7 R-ST2): replace a `roc` in the bin dir that Talon did not write. Kind `Default` (R-NM4), yes/no, the interactive default is `No`, so `--yes` is not the answer of Enter (R-NM8). The answer flag
	## `--replace-roc` is `flag: Ok(Yes)`. With no person the answer is `No`: Talon keeps the `roc` and installs no launcher. `path` is the `roc` in the bin dir, `old` is the path that it moves to (`roc.old`).
	##
	## | Field | Text (a proposal, TW24) |
	## | --- | --- |
	## | `id` | `replace-roc` |
	## | `question` | `<path> is a roc that Talon did not write. Move it to <old> and install the roc launcher?` |
	## | `subject` | `the replace of <path>` |
	## | `answer_line` | `Yes`: `moving <path> to <old>`. `No`: `keeping <path>`. |
	setup_replace_roc : { path : Str, old : Str } -> Prompt
	setup_replace_roc = |facts| Prompt.{
		id: "replace-roc",
		kind: Default,
		shape: YesNo,
		default: No,
		question: "${facts.path} is a roc that Talon did not write. Move it to ${facts.old} and install the roc launcher?",
		subject: "the replace of ${facts.path}",
		answer_line: |answer| if answer == Yes "moving ${facts.path} to ${facts.old}" else "keeping ${facts.path}",
	}

	## R-NI14 (`setup`; CLI 6.7 R-ST4): add the bin dir to `PATH`. Kind `Default`, yes/no, the interactive default is `Yes`. The answer flag `--no-modify-path` is `flag: Ok(No)`. `dir` is the bin dir, `target` is the file that gets the line
	## (the profile of the shell, or the file of `GITHUB_PATH`).
	##
	## | Field | Text (a proposal, TW24) |
	## | --- | --- |
	## | `id` | `modify-path` |
	## | `question` | `Add <dir> to PATH in <target>?` |
	## | `subject` | `the change of PATH in <target>` |
	## | `answer_line` | `Yes`: `adding <dir> to PATH in <target>`. `No`: `not adding <dir> to PATH`. |
	setup_modify_path : { dir : Str, target : Str } -> Prompt
	setup_modify_path = |facts| Prompt.{
		id: "modify-path",
		kind: Default,
		shape: YesNo,
		default: Yes,
		question: "Add ${facts.dir} to PATH in ${facts.target}?",
		subject: "the change of PATH in ${facts.target}",
		answer_line: |answer| if answer == Yes "adding ${facts.dir} to PATH in ${facts.target}" else "not adding ${facts.dir} to PATH",
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

	## R-NI6, R-DL1, R-DL3, R-DL4 (slice 021, `roc install`): download the compiler that the command names. Kind `Default` (R-NM4: no answer flag, `--yes` and non-interactive mode give `Yes`), yes/no, the
	## interactive default is `Yes` (R-DL3). `size` is the asset size (R-DA6) in bytes, as `Toolchain.size_text` writes it. The prompt names the count and the size (R-DL1, R-NR2).
	##
	## | Field | Text (a proposal, TW24) |
	## | --- | --- |
	## | `id` | `roc-install` |
	## | `question` | `Download 1 compiler, <size>: <id>?` |
	## | `subject` | `the download of <id>` |
	## | `answer_line` | `Yes`: `downloading <id> (<size>)`. `No`: `no download of <id>`. |
	roc_install : { id : Str, size : U64 } -> Prompt
	roc_install = |facts| {
		size = Toolchain.size_text(facts.size)
		Prompt.{
			id: "roc-install",
			kind: Default,
			shape: YesNo,
			default: Yes,
			question: "Download 1 compiler, ${size}: ${facts.id}?",
			subject: "the download of ${facts.id}",
			answer_line: |answer| if answer == Yes "downloading ${facts.id} (${size})" else "no download of ${facts.id}",
		}
	}

	## R-CC4 step 2: the failure when the person answers No to `roc_install`. Kind `Consent` (exit 13), `<id> is not installed. Nothing was downloaded.`
	roc_install_declined : Str -> Fail
	roc_install_declined = |id| Fail.new(Consent, "${id} is not installed. Nothing was downloaded.")

	## R-NI5, R-DL1, R-DL3, R-DL5 (slice 023b, the `roc` proxy): a required download of a compiler that the run needs and the user did not name. Kind `Required(["--allow-downloads", "TALON_AUTO_INSTALL=yes"])` (the answer flags of
	## R-NI5, `Prompt.decide` adds `--yes`), yes/no, the interactive default is `Yes` for the proxy (R-DL3). `source` is the words for the rank that chose the compiler (`roc +<id>`, `ROC_TOOLCHAIN`, `the roc: entry of the header`, `.roc-version`,
	## `the global default`). `size` is the asset size in bytes, as `Toolchain.size_text` writes it. The prompt names the count and the size (R-DL1, R-NR2). The proxy never shows the generic text of a `Stop` (it uses `Proxy.missing`, R-DL8).
	##
	## | Field | Text (a proposal, TW24) |
	## | --- | --- |
	## | `id` | `proxy-download` |
	## | `question` | `<id> (<source>) is not installed. Download 1 compiler, <size>?` |
	## | `subject` | `the download of <id>` |
	## | `answer_line` | `Yes`: `downloading <id> (<size>)`. `No`: `no download of <id>`. |
	proxy_download : { id : Str, source : Str, size : U64 } -> Prompt
	proxy_download = |facts| {
		size = Toolchain.size_text(facts.size)
		Prompt.{
			id: "proxy-download",
			kind: Required(["--allow-downloads", "TALON_AUTO_INSTALL=yes"]),
			shape: YesNo,
			default: Yes,
			question: "${facts.id} (${facts.source}) is not installed. Download 1 compiler, ${size}?",
			subject: "the download of ${facts.id}",
			answer_line: |answer| if answer == Yes "downloading ${facts.id} (${size})" else "no download of ${facts.id}",
		}
	}

	## R-NI5, R-DL1, R-DL3, R-DL5 (slice 025, `install`, `add`, `update`, `remove`, `verify`): a required download of the compiler that the first probe needs (R-SO22, R-BL3: the baseline and the
	## candidate run on one compiler, so the run has one download). Kind `Required(["--allow-downloads", "TALON_AUTO_INSTALL=yes"])` (`Prompt.decide` adds `--yes`), yes/no, the interactive default
	## is `No` (R-DL3: the command does not name the download. The proxy has `Yes`, `proxy_download`). `count` is the number of downloads the prompt covers (1 for this slice: R-DL1 says one prompt for
	## each command with the count and the total size, so a later slice that adds more downloads raises `count` and `size`, it does not add a prompt). `size` is the total in bytes, as `Toolchain.size_text` writes it (R-DL1, R-NR2).
	## `id` is the compiler of the first probe. With a `count` of 1 the texts name it, else they name the count.
	##
	## | Field | Text (a proposal, TW24) |
	## | --- | --- |
	## | `id` | `command-download` |
	## | `question` | `<id> is not installed. Download <count> compiler(s), <size>?` (`compiler` for 1, `compilers` for more) |
	## | `subject` | `the download of <id>` |
	## | `answer_line` | `Yes`: `downloading <id> (<size>)`, with a `count` other than 1: `downloading <count> compilers (<size>)`. `No`: `no download of <id>`, with a `count` other than 1: `no download of <count> compilers`. |
	command_download : { id : Str, count : U64, size : U64 } -> Prompt
	command_download = |facts| {
		size = Toolchain.size_text(facts.size)
		what = if facts.count == 1 facts.id else "${facts.count.to_str()} compilers"
		Prompt.{
			id: "command-download",
			kind: Required(["--allow-downloads", "TALON_AUTO_INSTALL=yes"]),
			shape: YesNo,
			default: No,
			question: "${facts.id} is not installed. Download ${facts.count.to_str()} ${plural(facts.count, "compiler", "compilers")}, ${size}?",
			subject: "the download of ${facts.id}",
			answer_line: |answer| if answer == Yes "downloading ${what} (${size})" else "no download of ${what}",
		}
	}

	## R-NI5, R-NI6, R-DL1, R-DL3, R-DL5, R-U2, R-U3 (slice 026b, question Q4): the one prompt of `tln roc use` when the baseline compiler of a member is not installed. It can also cover the new compiler (R-U3: "in the same prompt as the new nightly").
	## `ids` are the compilers that the prompt covers: the new compiler first (when it is missing), then each baseline compiler that is missing, with no repeat. The command uses it when a baseline compiler is missing (1 id or more). For the new compiler alone it uses `roc_install` (R-NI6).
	## Kind `Required(["--allow-downloads", "TALON_AUTO_INSTALL=yes"])` (`Prompt.decide` adds `--yes`), yes/no, the interactive default is `Yes` (review of slice 026b: `roc use` names its download, R-DL3). With no person the baseline is a download that the command does not name, so the result is the stop of R-NI5. `size` is the total in bytes (`Toolchain.size_text`).
	##
	## | Field | Text (a proposal, TW24) |
	## | --- | --- |
	## | `id` | `use-download` |
	## | `question` | `Download <n> compilers, <size>: <id>, <id>?` (`compiler` for n = 1) |
	## | `subject` | `the download of <n> compilers` |
	## | `answer_line` | `Yes`: `downloading <n> compilers (<size>)`. `No`: `no download of <n> compilers`. |
	use_download : { ids : List(Str), size : U64 } -> Prompt
	use_download = |facts| {
		size = Toolchain.size_text(facts.size)
		count = facts.ids.len()
		what = "${count.to_str()} ${plural(count, "compiler", "compilers")}"
		Prompt.{
			id: "use-download",
			kind: Required(["--allow-downloads", "TALON_AUTO_INSTALL=yes"]),
			shape: YesNo,
			default: Yes,
			question: "Download ${what}, ${size}: ${Str.join_with(facts.ids, ", ")}?",
			subject: "the download of ${what}",
			answer_line: |answer| if answer == Yes "downloading ${what} (${size})" else "no download of ${what}",
		}
	}

	## R-DL4, R-DL5 (slice 025): what a command that resolves does for a compiler that is not installed. Only `NeedsConsent` needs the list of releases (for the size in its text). `id` is the compiler that the first probe needs. `auto` is `TALON_AUTO_INSTALL`
	## (`Consent.auto_install`). `mode` is the mode of the run (`Mode.from_env`, `Mode.with_tty`). `yes` is `--yes`. `flag` is the answer flag `--allow-downloads` (`Ok(Yes)` when it is set). The first row that holds wins:
	##
	## | # | Case | Result | Rule |
	## | --- | --- | --- | --- |
	## | 1 | `id` is not a nightly tag (`Pin.is_nightly`: a release version, a prefix, `git-<sha8>`, `link-<name>`, `copy-<name>`): no source of releases is known for it (the proxy has the same rule, `Proxy.want`, Q2 of slice 023b) | `Refuse` | R-NS2 |
	## | 2 | `auto` is `No`, `flag` is not set and `yes` is false | `AutoNo`, in each mode, with no prompt and with no request. A flag on the command line (`--allow-downloads`, `--yes`) wins over the variable (flag over environment, answer Q1 of the review), so rows 3 and following hold. | R-DL5 |
	## | 3 | `auto` is `Yes`, or `flag` is `Ok(Yes)`, or `yes` is true (with `auto` not `No`) | `Install`: the answer is Yes with no prompt (the answer line, R-NM6). The run makes no `tty!` call. | R-DL5, R-NM10 |
	## | 4 | `mode` is `Interactive` | `Ask`: the prompt `command_download` (the default is No) | R-DL3 |
	## | 5 | `mode` is `NeedsTty` | `NeedTty`: the caller asks the terminal (R-HF1), then calls again with `Mode.with_tty` | R-HF1 |
	## | 6 | `mode` is `NonInteractive` | `NeedsConsent`: the run stops with exit 13. The text has the count and the size of the download (R-DL1), so the caller reads the list of releases first (`RocInstall.offer!`), then fails with `download_stop`. | R-DL4, R-NI5 |
	##
	## `Refuse` is the failure of `Compiler.require` for the same id (exit 13, `the compiler <id> is not installed. Run: tln roc install <id>.`: no download can help, R-NS2). `AutoNo` is the failure `download_refused`.
	required_want : { id : Str, auto : [Ask, Yes, No], mode : Mode, yes : Bool, flag : Try(Answer, [NoFlag]) } -> [Refuse, AutoNo, NeedsConsent, Install, Ask, NeedTty]
	required_want = |run| {
		answered = run.yes or flag_is_yes(run.flag)
		if !Pin.is_nightly(run.id) {
			Refuse
		} else if run.auto == No and !answered {
			AutoNo
		} else if run.auto == Yes or answered {
			Install
		} else {
			match run.mode {
				Interactive => Ask
				NeedsTty => NeedTty
				NonInteractive => NeedsConsent
			}
		}
	}

	## R-DL1, R-DL4, R-NI5, R-EC13, R-J5 (slice 025): the failure of a command with no person and no answer for a required download (row 6 of `required_want`). Kind `Consent` (exit 13). `count` is the number of downloads
	## and `size` is their sum in bytes (`Toolchain.size_text`). The text is the text of the design example of `--json` (CLI 3, "Example of a failure"):
	## `1 compiler download (73.9 MB) needs consent. Pass --allow-downloads or set TALON_AUTO_INSTALL=yes.` With a count other than 1: `2 compiler downloads (147.4 MB) needs consent. ...` (`download` for 1, `downloads` for more; the verb stays `needs`).
	download_stop : { count : U64, size : U64 } -> Fail
	download_stop = |facts| {
		what = "${facts.count.to_str()} compiler ${plural(facts.count, "download", "downloads")}"
		Fail.new(Consent, "${what} (${Toolchain.size_text(facts.size)}) needs consent. Pass --allow-downloads or set TALON_AUTO_INSTALL=yes.")
	}

	## R-DL5, R-DL8, R-DL10 (slice 025, answer Q4 of the review): the failure of a run with `TALON_AUTO_INSTALL=no` and no flag (row 2 of `required_want`). Kind `Consent` (exit 13). The text names the
	## three ways to get the compiler (a proposal, TW24): `the compiler <id> is not installed. TALON_AUTO_INSTALL=no refuses the download. Run: tln roc install <id>, pass --allow-downloads, or set TALON_AUTO_INSTALL=yes.`
	download_refused : Str -> Fail
	download_refused = |id| Fail.new(Consent, "the compiler ${id} is not installed. TALON_AUTO_INSTALL=no refuses the download. ${ways(id)}")

	## R-NI5, R-NM8 (slice 025, answer Q4 of the review): the failure when the person answers No to `command_download`. Kind `Consent` (exit 13), a proposal (TW24):
	## `<id> is not installed. Nothing was downloaded. Run: tln roc install <id>, pass --allow-downloads, or set TALON_AUTO_INSTALL=yes.` (`roc_install_declined` stays as it is for `roc install`.)
	command_declined : Str -> Fail
	command_declined = |id| Fail.new(Consent, "${id} is not installed. Nothing was downloaded. ${ways(id)}")

	## R-DL5, R-DL10, R-SO13 (slice 025b): does the run refuse a download before it reads the list? It is row 2 of `required_want` for a compiler whose id is not known yet (rank 4 has a range, and the id comes from the list):
	## `auto` is `No`, `yes` is false, and `flag` is not `Ok(Yes)`. A flag on the command line wins over the variable (answer Q1 of slice 025). The proxy has no flag: it gives `yes: Bool.False` and `flag: Err(NoFlag)`.
	auto_refuses : { auto : [Ask, Yes, No], yes : Bool, flag : Try(Answer, [NoFlag]) } -> Bool
	auto_refuses = |run| run.auto == No and !(run.yes or flag_is_yes(run.flag))

	## R-DL5, R-DL10, R-SO13 (slice 025b): the failure of a command that resolves, with `TALON_AUTO_INSTALL=no` and no flag, when rank 4 has a range and no installed compiler is in it (`auto_refuses`). Kind `Consent` (exit 13).
	## No request is made, so the id of the download is not known. The text names the three ways (a proposal, TW24): `no installed compiler is in [toolchain] roc (<range>). TALON_AUTO_INSTALL=no refuses the download.
	## Run: tln roc install <id> for an id in the range, pass --allow-downloads, or set TALON_AUTO_INSTALL=yes.` The proxy has no flag, so its failure is `Compiler.failure(NoneInRange)`.
	range_refused : Str -> Fail
	range_refused = |range| Fail.new(Consent, "no installed compiler is in [toolchain] roc (${range}). TALON_AUTO_INSTALL=no refuses the download. Run: tln roc install <id> for an id in the range, pass --allow-downloads, or set TALON_AUTO_INSTALL=yes.")

	## R-EV6, R-DL5 (slice 025, moved from `Proxy.auto_install`: the commands read it too): `TALON_AUTO_INSTALL`. `ask` and no variable are `Ask` (the default), `yes` is `Yes`, `no` is `No`. Any other
	## text, also the empty text and a text in another letter case, counts as not set: `Ask` (the answer of the user for `TALON_NIGHTLY`, `docs/slices/ANSWERS.md`). No failure, no warning.
	auto_install : List((Str, Str)) -> [Ask, Yes, No]
	auto_install = |env| match env.find_first(|(name, _)| name == "TALON_AUTO_INSTALL") {
		Ok((_, "yes")) => Yes
		Ok((_, "no")) => No
		_ => Ask
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

flag_is_yes : Try(Answer, [NoFlag]) -> Bool
flag_is_yes = |flag| match flag {
	Ok(Yes) => Bool.True
	_ => Bool.False
}

# The three ways to get a compiler that a command needs (R-DL4, R-DL8).
ways : Str -> Str
ways = |id| "Run: tln roc install ${id}, pass --allow-downloads, or set TALON_AUTO_INSTALL=yes."

plural : U64, Str, Str -> Str
plural = |count, one, many| if count == 1 one else many
