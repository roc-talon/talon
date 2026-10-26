import Args
import Fail
import Fx
import InstallFlow
import Picker
import RemoveFlow
import Report
import ResolveBase
import ResolveLoad
import Vars
import VerifyFlow

## The resolve flow of the P0 commands that resolve, in direct style over `Fx` (TESTING.md 2.2, part C). Slice 007 builds `install` and `update` on it
## (arguments, `--json`, `--dry-run`, `add`, `remove`, the probe ladder of slice 006). This slice tests it through the L2 entry `resolve`.
Resolve :: [].{

	## One run: the alias of `ResolveBase.Request` (the type moved with the split of slice 010). `names` are the operands of `update` as typed (`json`, `json@^3`, `roc-lang/json`): `Ref.parse` and `Lookup.find` read them (slice 004).
	## `strategy` is `--strategy`. `nightly` is `TALON_NIGHTLY` (R-NS8). `compiler` is the id of the `roc` on `PATH` (R-PH8). `now` is `Clock.now`.
	Request : ResolveBase.Request

	## Slice 007: the `install` command of `Install.run!` (also `add` and `i`). The same flow as `run!` with the changes of slice 007, and the facts for `--json`.
	## `run!` is this flow too: it prints the same lines and gives `{}`. The new fields of `Request`:
	##
	## | Field | Holds |
	## | --- | --- |
	## | `snapshot` | `--snapshot` (R-FL9). A flag has priority over `[resolution] snapshot` of `talon.toml` (R-EV1). `Intent.direct_snapshot` checks it: `log:<n>` is a usage failure with `direct`. |
	## | `dry_run` | `--dry-run` (R-LF4): the probes run, the files are not written, the lines are the same and the last line is `dry run: nothing was written` |
	## | `add` | `--platform`, `--as`, `--no-pin` for the names of `install` (R-AD25 to R-AD33) |
	## | `prompt` | The facts for `Prompt.ask!` (R-NI1): the mode (`Mode.from_env`), `--yes`, `--quiet`, `--rename-keys` |
	##
	## `names` of `install` are the refs to add (slice 007, R-SP18: with names the command is `tln add`). `run!` calls `install!` and drops the outcome.
	##
	## The flow of `install!` is the flow of `run!` of slice 005 and 006 (the steps A to J) with these changes, in this order (the L3 cases `add/*` and `install/*` and the L2 cases `install/*` and `resolve/rs-*` fix them):
	##
	## | # | Step | Rule |
	## | --- | --- | --- |
	## | 1 | `--frozen`: the check of slice 005, then an `Outcome` with no change (`probes` 0, `check` and `build` `NotRun`, `at` is `now`). No index call, no write. | R-LF1 |
	## | 2 | Each name of `install` is read with `Ref.parse` (scope `Install`) and `Lookup.find`. A name that is a header alias, or a full name that has exactly one variable in the header (one repo, one entry), is an entry of the header. `Add.decide_alias` decides: no selector or `latest` is `Keep` (the `Outcome.kept` row and the note, no index call, no probe), a selector is `Update` (the named variable is free, as `update X@sel`, and `talon.toml` gets the key of `Add.decide_alias`). With `--platform` the full name is always a new entry (the platform entry is replaced, R-AD31). A full name of a platform entry without `--platform` is the failure of R-AD33. | R-AD1, R-AD2, R-AD6, R-AD20 to R-AD22, R-SL5, R-AD33 |
	## | 3 | A full name that the member does not have, and that other members hold (one variable, no entry in the current member): the new entry is a free slot of that group with its own range. The pick gives it the held version, or the second search moves the group (R-SP16, R-WS12, slice 017). | R-WS12, R-WS2 |
	## | 4 | Another full name is a new entry. `Add.decide` gives the alias, with the key `--as` or `Alias.default` for the want | R-AD8 to R-AD19, R-AD30 |
	## | 5 | A stale key of `talon.toml` (a want that `Vars` marks stale) of `install` and `add`: print `Consent.rename_keys(...).report` on stderr, then `Prompt.ask!` with `flag: request.prompt.rename_keys`. `Yes` makes a rename of the key to the alias of the header (`Intent.rename` at the write). `No` keeps the key. A failure (exit 13) stops the command before the index call. `update` keeps the warning of slice 005. | R-NI1, R-I8, R-I9 |
	## | 6 | The index of each free variable and each new name. A new name needs a candidate that the selector admits: else `Add.no_release` (usage, exit 2) before any pick. | R-SL12, R-SL3, R-SL4 |
	## | 7 | The kind of the newest candidate of a new name (the header of its package is read): `--platform` and a package is `'<name>' is not a platform`, a platform and no `--platform` is `'<name>' is a platform. Use tln add --platform <name>.` (usage, exit 2), before the pick. The pick of the new name is a slot with the range of the selector (`*` for none, `latest`). With `--platform` the platform variable of the header is not a slot. | R-AD32, R-AD33, R-C4 |
	## | 8 | The pick (`Pick.step`, slice 005). The header edits: `Add.decide` of each new name: `Insert` is a new entry (line `+ <alias>: <name> <version>`), `Replace` is the platform entry under its alias (line `~ <alias>: <name> <old> -> <new>` and the note `platform changes: ...`: the notes are printed as `note: <text>` and are `Outcome.notes`). The `talon.toml` writes are the `toml` of `Add.decide` (R-AD23 to R-AD28). | R-AD23 to R-AD31, R-SE7 |
	## | 9 | The ladder (slice 006) when a header changes, and not `--no-check`. `probes` of the `Outcome`: 3 for each app, 2 for each package or platform. `check` and `build` are `Passed`, or `Skipped` with `--no-check`, else `NotRun` (`build` is `NotRun` when no member is an app). | R-LD4, R-LD5, R-LF3 |
	## | 10 | The write (`write!`): the second read, `Guard.check_all` over the header files and the `talon.toml` files (the spans of the renamed keys are compared too), the rename after the key writes, one `write_atomic!` call. With `--dry-run` there is no read and no write: the lines of the plan are the same. "nothing to change" is printed when no file changes and no entry was kept. | R-CC7, R-LF4 |
	##
	## Slice 009 changes for `command: Update` (the L2 and L3 cases `update/*`):
	##
	## | # | Change | Rule |
	## | --- | --- | --- |
	## | U1 | A key of `talon.toml` that the header lacks is no want: `update` neither resolves it, nor reads the index for it, nor adds an entry (Q3: a bug of slice 005). `install` and `add` keep it. A stale key keeps the warning. | R-I5, R-I8 |
	## | U2 | A moved platform entry (a `Moved` edit of a variable with `is_platform`, also by `X@sel`): the note `Add.platform_note` is printed as `note: <text>` with the other notes, and is in `Outcome.notes` | R-SE7 |
	## | U3 | The pick fails because a variable with a selector has no release (`Pick.step`: `has no release that satisfies`, exit 10): the message gets `Add.close_note` at its end. The versions are the candidates of that repository. | R-SL12, Q5 |
	## | U4 | A name that is the alias of a `Path` row of the header (it is no variable): exit 2, `'<alias>' is a path entry: Talon never changes it` (the text of a name that is no alias stays `'<x>' is not in the project`) | R-H4, Q8 |
	##
	## `Outcome.written` are the files that were written (`[]` for `--dry-run` and for no change). `added`, `moved`, `pinned`, `toml` and `renamed` are the planned changes for `--dry-run` and the written changes otherwise, and empty for a run that wrote nothing. The lines of stdout: the notes of the scope, the `note:` lines, the notes of the kept entries, the lines of the ladder, then the file lines (`<path>`, `  + ...`, `  ~ ...`, `<path>: <key> = "<value>"`, `<path>: key <from> -> <to>`).
	install! : Fx, Request => Try(Report.Outcome, Fail)
	install! = |fx, request| InstallFlow.install!(fx, request)

	## Slice 056: `install!` with the tools step of `[tools]` (`InstallFlow.install_with!`). `tln install` passes its `Args`.
	install_with! : Fx, Request, Try(Args, [None]) => Try(Report.Outcome, Fail)
	install_with! = |fx, request, tools| InstallFlow.install_with!(fx, request, tools)

	## Slice 008: the flow of `remove` (`Remove.run!`, also `rm`: R-CM3, R-RV1 to R-RV5, R-WS12). It resolves nothing: no index call, no pick, no fetch, no `Vars.build`. The `Request` is the one that `install!` takes. The fields that `remove` reads are
	## `project`, `roots`, `now` (not used), `compiler`, `nightly`, `no_check` and `dry_run`. `names` of the `Request` is not used: `facts.names` are the operands of `remove`, `facts.force` is `--force`.
	## The flow changes the one current member (R-WS12). Other members are read (the key rule of step 3) and never written. The steps, in order (the L2 case `remove/rm1-flow` and the L3 cases `remove/*` fix them):
	##
	## | # | Step | Rule |
	## | --- | --- | --- |
	## | 1 | `load!`: one `read_files!` call for the member files and the `talon.toml` candidates (as `install!`) | R-PD6 |
	## | 2 | Each name: `Ref.parse` (scope `Project`), then `Lookup.find` over the entries of the header of the current member. One entity for each row: `alias`, `name` (the full name of a release, else the value of a path or foreign row), `note` (`platform (<alias>)` for the platform row). A failure is returned (its block goes to stderr first), `New(name)` is the usage failure `'<name>' is not in the project`. Names that give one entry count once. | R-SC1, R-SC6 to R-SC8 |
	## | 3 | `Removal.plan` for each entry (all names are checked before the scan, so one platform name stops the run with no other effect). `toml` is the nearest `talon.toml` of the member (path and text) or `Err(NoToml)`. `shared` is true when another member under the dir of that `talon.toml` has the alias in its header (question Q3). | R-RV3, R-RV4, R-RV5, R-WS14 |
	## | 4 | The scan: `Scan.roots` (for a package or a platform file `exposed` is `Header.exposed` of the header), then `Scan.level` for each import level until `next` is empty. A level is one `read_files!` call: the files that are not in the first read (the member file is) and are listed in `next` or `roots`. A file that cannot be read is skipped, no failure (question Q7). No call when there is no file to read. The scan runs also with `--no-check`. `Scan.level` is called once for each alias. | R-RV2, R-LD7 |
	## | 5 | A hit and no `--force`: failure of kind `AppError` (exit 11). The message lists each import line (the text is in the slice file, "Output"). Nothing is written. No ladder call. | R-RV2, R-EC11 |
	## | 6 | `Pin.decide` with `changes` true for the current member only, and `no_check` true for `--no-check` and for a forced run. `check_pin` as in `install!`, also with `--no-check` and a forced run (R-RP2 has no exception, Q37). The note of `Pin.decide` (R-SO20) is the first `note:` line, before the notes of row 7. | R-RP2, R-RP3, R-H6 |
	## | 7 | With hits (forced): the line `note: <alias> is still imported in <n> line(s). The app cannot check until you change the imports.` for each alias, on `out!`. It is in `Outcome.notes` too. | R-RV2 |
	## | 8 | The ladder, when the check runs (not `--no-check`, not a forced run): `Ladder.run!` with one member (the current member, its text, `ops`: a `Remove(alias)` for each entry, then the `Pin` of the decision), `owners` (the release rows of the header that stay, with `Ident.hash`, name and version), `moved` empty. A `NoTuple` failure has the text of the ladder, then ` tln remove moves no other entry. Pass --no-check to remove <alias>[, <alias>] anyway.` With `--no-check` the line `check: skipped` is printed and `probes` is 0. A forced run prints no check line. `probes` is 3 for an app, 2 for a package or a platform. | R-RV1, R-LD4, R-LD5, R-PH10, R-LF3 |
	## | 9 | The write: with `--dry-run` no read and no write. Else the second read (the `talon.toml` first, then the header), `Guard.check_all` (the spans of `Locked.spans` and of `Intent.table_spans`), `Locked.edit`, `Intent.remove`, and one `write_atomic!` call in the `Guard` order. | R-CC7, R-CC1, R-LF4 |
	## | 10 | The lines, on `out!`: the path of the header, `  - <alias>: <what>` for each entry, `  + roc: <id>` for a pin write, then `<talon.toml path>: - [<table>] <key>` for each key, then `kept: <dir> (the patch files of <alias>)` for each patch dir. They are printed also with `--dry-run`. | R-LF4, R-RV4 |
	##
	## `Outcome.written` is `[]` for `--dry-run` and for a failure. `removed`, `toml`, `patches` and `pinned` are the planned changes for `--dry-run`, and the written changes otherwise.
	remove! : Fx, Request, { names : List(Str), force : Bool } => Try(Report.RemoveOutcome, Fail)
	remove! = |fx, request, facts| RemoveFlow.remove!(fx, request, facts)

	## Slice 009: the free packages of `tln update -i` (R-SP4, R-SP14). `load!` (one `read_files!` call), `Vars.build`, then one `Picker.Item` for each name of `Vars.picker` (the variables that `update` with no name frees, in the order of
	## `priority`, the nightly is not in the list, R-RP1). `alias` is the first alias of the variable, `name` is the full name of the variable (`Var.name`, else the URL form), `version` is the version of its first use. No index call, no write.
	## The request is the one of `install!` (`command` is `Update`, `names` is `[]`).
	picks! : Fx, Request => Try(List(Picker.Item), Fail)
	picks! = |fx, request| {
		loaded = ResolveLoad.load!(fx, request)?
		built = Vars.build({ members: loaded.members, priority: loaded.intent.resolution.priority })?
		items = Vars.picker(built.vars).keep_oks(
			|alias| match built.vars.find_first(|v| v.uses.any(|u| u.alias == alias)) {
				Ok(v) => match v.uses.find_first(|u| u.alias == alias) {
					Ok(u) => Ok({ alias, name: v.name ?? v.group.form, version: u.version })
					Err(_) => Err(NoUse)
				}
				Err(_) => Err(NoVar)
			},
		)
		Ok(items)
	}

	## Slice 009: the flow of `tln verify` (R-CM11, R-LB2, R-FL14; `Verify.run!`). The tuple is the one that `update` with no name picks (steps 1 to 8 of `install!` with `command: Update` and `names: []`: all packages are free inside their ranges,
	## the nightly is held, R-SP2). The differences from `install!`:
	##
	## | # | Difference | Rule |
	## | --- | --- | --- |
	## | 1 | The ladder always runs (question Q4), also when no entry moves, and not with `--no-check` (then the line `check: skipped`, `probes` 0). It is `Ladder.verify!`: no copy of the app, no edit of a header. `replace` has `{ old, new }` for each header use whose URL differs from the URL of the tuple (the order of the uses, no repeat). The members are all member files of the project (`Ladder.Checked`). `probes` is 3 for an app and 2 for a package or a platform, as `install!` counts them. | R-CM11, R-LB2, R-LD7 |
	## | 2 | No write: no second read, no `Guard.check_all`, no `write_atomic!`, no pin. `Outcome.written` is `[]`, `pinned` is `Err(None)`, `dry_run` is false, `added`, `kept`, `toml` and `renamed` are empty. | R-CM11, R-H6 |
	## | 3 | The lines: the notes and the ladder lines (as `install!`), then, when an entry differs, the path of each member file and `  ~ <alias>: <name> <old> -> <new>` for each of its entries (no `+ roc:` line). No `nothing to change` line. | R-OUT2 |
	## | 4 | A stale key keeps the warning (no prompt), a key that the header lacks has no effect (as for `update`, Q3). | R-I5, R-I8 |
	##
	## `moved` of the `Outcome` has the entries that differ. A failure of the ladder is the failure of the run (exit 10 or 11, nothing was written).
	verify! : Fx, Request => Try(Report.Outcome, Fail)
	verify! = |fx, request| VerifyFlow.verify!(fx, request)

	## See the slice file 005, "The flow of `Resolve.run!`". It is `install!` with the outcome dropped.
	run! : Fx, Request => Try({}, Fail)
	run! = |fx, request| {
		_ = install!(fx, request)?
		Ok({})
	}
}
