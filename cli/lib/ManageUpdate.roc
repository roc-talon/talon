import Args
import Channel
import Fail
import JsonDoc
import Pin
import Toolchain

## The pure texts of `tln roc update` (slice 036b3: split from `Manage`). `Manage.update_move` stays in `Manage`, because it uses `Manage.kind_of`. Texts and `data` fields are a proposal (R-OUT2, TW24).
ManageUpdate :: [].{

	## R-CM15, R-CM19 (slice 026): `roc update` takes no operand. 1 or more is a failure of kind `Usage` (exit 2): `tln roc update takes no operand, got <n>`. The text names the long form, also for `up`.
	read_update : Args -> Try({}, Fail)
	read_update = |args| match args.operands {
		[] => Ok({})
		many => Err(Fail.new(Usage, "tln roc update takes no operand, got ${many.len().to_str()}"))
	}

	## Slice 243 (R-CH15, R-CM15, R-CM19, R-CH3): the operand of `roc update`: none, or one channel name. The word `nightly` is a name. A text that R-CH3 refuses is a failure of kind `Usage` (exit 2) with the text of `tln roc channel add`: `<text> is not a channel name. A name is a-z, 0-9 and -, starts with a letter, has 2 to 24 characters and does not end with -.` (a reserved word has its own text there: `<text> is a reserved channel name`).
	## 2 or more operands: `tln roc update takes at most one channel name, got <n>`. Whether the table exists is not decided here.
	update_name : Args -> Try(Try(Str, [NoName]), Fail)
	update_name = |args| match args.operands {
		[] => Ok(Err(NoName))
		[one] => if one == "nightly" {
			Ok(Ok(one))
		} else {
			match Channel.name_check(one) {
				Ok({}) => Ok(Ok(one))
				Err(BadName) => Err(Fail.new(Usage, not_a_name(one)))
				# A build id (`nightly-2026-10-14-38a3029`) is no name at all, so it has the text of a bad name.
				Err(Reserved) => if Channel.parse_id(one).is_ok() Err(Fail.new(Usage, not_a_name(one))) else Err(Fail.new(Usage, "${one} is a reserved channel name"))
			}
		}
		many => Err(Fail.new(Usage, "tln roc update takes at most one channel name, got ${many.len().to_str()}"))
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
	##
	## Slice 243 (R-CH15, Design Q619 U1): `Stay(default)` has 3 texts, by the id `default`. A user-channel build: `note: the default compiler <default> is a build of the channel <name>, so it stays. To change it, run: tln roc default <id>` (`<name>` is the channel of `default`).
	## A nightly or a release (the new `id` is a user build): `note: the default compiler <default> is not a build of the channel <name>, so it stays. To change it, run: tln roc default <id>` (`<name>` is the channel of `id`). `NoDefault` (no default is set, `id` is a user build):
	## `note: no default compiler is set, and <id> is a build of the channel <name>, so it is not made the default. To use it, run: tln roc default <id>`.
	update_report : { id : Str, installed : Bool, default : [Set, Moved(Str), Stay(Str), Same, NoDefault], compat : Try(Str, [Unknown, Several(List(Str))]) } -> { stdout : List(Str), stderr : List(Str) }
	update_report = |facts| {
		first = if facts.installed "installed ${facts.id}\n" else "${facts.id} is the newest\n"
		after = match facts.default {
			Set => ["${facts.id} is now the default compiler\n"]
			Moved(old) => ["the default compiler moved from ${old} to ${facts.id}\n"]
			Stay(kept) => [stay_note(facts.id, kept)]
			NoDefault => ["note: no default compiler is set, and ${facts.id} is a build of the channel ${channel_of(facts.id)}, so it is not made the default. To use it, run: tln roc default ${facts.id}\n"]
			Same => []
		}
		warnings = if facts.installed Toolchain.report({ id: facts.id, how: Installed, default: Kept, compat: facts.compat }).stderr else []
		{ stdout: [first].concat(after), stderr: warnings }
	}

	## Slice 262b (R-RU5, Q262-6, stub of the test agent): the project hint of `roc update`. `file` is the project file, `pin` its header `roc:` pin, `other` is true when a source of
	## priority 2, 4 or 5 (ROC_TOOLCHAIN, `[toolchain] roc`, `.roc-version`) selects for the project, `default` is what the command did to the global default, `id` the new compiler.
	## `uses`: `Pin` (a header pin), `New` (no pin, no other source, the default is now `id`), `Other`. `line` is line A or line B with its `note: ` prefix and a line end, or `Err(None)`.
	project_hint : { file : Str, pin : Try(Str, [NoPin]), other : Bool, default : [Set, Moved(Str), Stay(Str), Same, NoDefault], id : Str } -> { uses : [Pin, New, Other], line : Try(Str, [None]) }
	project_hint = |facts| match facts.pin {
		Ok(pin) => {
			line = if pin == facts.id {
				Err(None)
			} else {
				Ok("note: the project ${facts.file} pins ${pin}, so it stays on that compiler. To move it with a check, run: tln upgrade roc\n")
			}
			{ uses: Pin, line }
		}
		Err(NoPin) => if facts.other {
			{ uses: Other, line: Err(None) }
		} else {
			match facts.default {
				Set | Moved(_) | Same => { uses: New, line: Ok("note: the project ${facts.file} has no roc: pin, so it uses ${facts.id} now, with no check. To check it and pin it, run: tln roc use ${facts.id}\n") }
				Stay(_) | NoDefault => { uses: Other, line: Err(None) }
			}
		}
	}

	## R-J3, R-J4, R-OUT4 (slice 026, a proposal): the `data` of `roc update --json`, the keys in this order: `id` (the newest compiler), `path` (its install dir), `installed` (true when this run downloaded it),
	## `previous` (the default before the command as text, or `null`), `changed` (true when `default-roc` was written, also the first default of R-SO15).
	update_data : { id : Str, item : Str, installed : Bool, previous : Try(Str, [Unset]), changed : Bool } -> JsonDoc
	update_data = |facts| JsonDoc.Obj(base_fields(facts))

	## Slice 262b (R-RU5, R-J3, Q262-6, R6): `update_data` and the member `project` after `changed`: `{"file", "pin", "uses"}` (`uses` is `pin`, `new` or `other`), or `null` when there is no project.
	update_data_project : { id : Str, item : Str, installed : Bool, previous : Try(Str, [Unset]), changed : Bool }, Try({ file : Str, pin : Try(Str, [NoPin]), uses : [Pin, New, Other] }, [None]) -> JsonDoc
	update_data_project = |facts, project| {
		doc = match project {
			Ok(p) => JsonDoc.Obj([
				("file", JsonDoc.Text(p.file)),
				("pin", text_of(p.pin.map_err(|NoPin| None))),
				(
					"uses",
					JsonDoc.Text(
						match p.uses {
							Pin => "pin"
							New => "new"
							Other => "other"
						},
					),
				),
			])
			Err(None) => JsonDoc.Null
		}
		JsonDoc.Obj(base_fields(facts).append(("project", doc)))
	}
}

text_of : Try(Str, [None]) -> JsonDoc
text_of = |id| match id {
	Ok(text) => JsonDoc.Text(text)
	Err(None) => JsonDoc.Null
}

# The channel name of a user-channel id (read from the right). Another id gives the empty text.
channel_of : Str -> Str
channel_of = |id| match Channel.user_parts(id) {
	Ok(parts) => parts.name
	Err(_) => ""
}

# R-RU2, R-CH15: the note of a default that stays.
stay_note : Str, Str -> Str
stay_note = |id, kept| if Channel.user_parts(kept).is_ok() {
	"note: the default compiler ${kept} is a build of the channel ${channel_of(kept)}, so it stays. To change it, run: tln roc default ${id}\n"
} else if Pin.is_id(kept) {
	"note: the default compiler ${kept} is not a build of the channel ${channel_of(id)}, so it stays. To change it, run: tln roc default ${id}\n"
} else {
	"note: the default compiler ${kept} is a git, link or copy build, so it stays. To change it, run: tln roc default ${id}\n"
}

not_a_name : Str -> Str
not_a_name = |text| "${text} is not a channel name. A name is a-z, 0-9 and -, starts with a letter, has 2 to 24 characters and does not end with -."

base_fields : { id : Str, item : Str, installed : Bool, previous : Try(Str, [Unset]), changed : Bool } -> List((Str, JsonDoc))
base_fields = |facts| [
	("id", JsonDoc.Text(facts.id)),
	("path", JsonDoc.Text(facts.item)),
	("installed", JsonDoc.Flag(facts.installed)),
	("previous", text_of(facts.previous.map_err(|Unset| None))),
	("changed", JsonDoc.Flag(facts.changed)),
]
