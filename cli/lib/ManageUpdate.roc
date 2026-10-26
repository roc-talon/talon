import Args
import Fail
import JsonDoc
import Toolchain

## The pure texts of `tln roc update` (slice 036b3: split from `Manage`). `Manage.update_move` stays in `Manage`, because it uses `Manage.kind_of`. Texts and `data` fields are a proposal (R-OUT2, TW24).
ManageUpdate :: [].{

	## R-CM15, R-CM19 (slice 026): `roc update` takes no operand. 1 or more is a failure of kind `Usage` (exit 2): `tln roc update takes no operand, got <n>`. The text names the long form, also for `up`.
	read_update : Args -> Try({}, Fail)
	read_update = |args| match args.operands {
		[] => Ok({})
		many => Err(Fail.new(Usage, "tln roc update takes no operand, got ${many.len().to_str()}"))
	}

	## R-RU1, R-RU2, R-OUT2 (slice 026, a proposal, answer Q1 of the review): the lines of `roc update`. `installed` is true when this run downloaded `id`. `default` is what the command did to the global default:
	## `Set` (no default was set: `update` set it, R-SO15), `Moved(old)`, `Stay(default)` (a local build is the default: R-RU2) or `Same` (the default is `id` already).
	## `compat` is the answer of the compat check of the install (`Toolchain.report`). It is shown only when `installed` is true (no install, no check). Each element is one line with its `\n`. The first line is `installed <id>` or `<id> is the newest`, then the lines of `default`:
	##
	## | `default` | Line or lines after the first line |
	## | --- | --- |
	## | `Set` | `<id> is now the default compiler` |
	## | `Moved(old)` | `the default compiler moved from <old> to <id>` |
	## | `Stay(default)` | `note: the default compiler <default> is a git, link or copy build, so it stays. To change it, run: tln roc default <id>` |
	## | `Same` | none |
	update_report : { id : Str, installed : Bool, default : [Set, Moved(Str), Stay(Str), Same], compat : Try(Str, [Unknown, Several(List(Str))]) } -> { stdout : List(Str), stderr : List(Str) }
	update_report = |facts| {
		first = if facts.installed "installed ${facts.id}\n" else "${facts.id} is the newest\n"
		after = match facts.default {
			Set => ["${facts.id} is now the default compiler\n"]
			Moved(old) => ["the default compiler moved from ${old} to ${facts.id}\n"]
			Stay(kept) => ["note: the default compiler ${kept} is a git, link or copy build, so it stays. To change it, run: tln roc default ${facts.id}\n"]
			Same => []
		}
		warnings = if facts.installed Toolchain.report({ id: facts.id, how: Installed, default: Kept, compat: facts.compat }).stderr else []
		{ stdout: [first].concat(after), stderr: warnings }
	}

	## R-J3, R-J4, R-OUT4 (slice 026, a proposal): the `data` of `roc update --json`, the keys in this order: `id` (the newest compiler), `path` (its install dir), `installed` (true when this run downloaded it),
	## `previous` (the default before the command as text, or `null`), `changed` (true when `default-roc` was written, also the first default of R-SO15).
	update_data : { id : Str, item : Str, installed : Bool, previous : Try(Str, [Unset]), changed : Bool } -> JsonDoc
	update_data = |facts| JsonDoc.Obj([
		("id", JsonDoc.Text(facts.id)),
		("path", JsonDoc.Text(facts.item)),
		("installed", JsonDoc.Flag(facts.installed)),
		("previous", text_of(facts.previous.map_err(|Unset| None))),
		("changed", JsonDoc.Flag(facts.changed)),
	])
}

text_of : Try(Str, [None]) -> JsonDoc
text_of = |id| match id {
	Ok(text) => JsonDoc.Text(text)
	Err(None) => JsonDoc.Null
}
