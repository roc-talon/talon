import Fail
import Ident
import Pin
import Project
import header.Header

## The header of a project file as the lock (Design 4.2, R-H1 to R-H8): what Talon reads from it and the span edits that it writes.
## The header text is read and edited with `roc-app-header` (`Header.parse`, `set_value`, `add_entry`, `remove_entry`). Talon never
## reprints a header and never runs `roc fmt` on it (R-H1, R-H2). Each edit changes only its own bytes: comments, order, blank lines,
## the form of the other entries and the line ends stay byte for byte.
##
## `rows` are the entries of the dependency record in source order, without the `roc:` entry (it is `roc`):
##
## | Field | Holds | Rule |
## | --- | --- | --- |
## | `alias` | The name before the `:` | |
## | `value` | The text between the quotes, as in the source | |
## | `is_platform` | The entry is `pf: platform "..."` | R-C4 |
## | `what` | `Release(ident)`: `Ident.of_url` is `Ok`. `Path`: the value has no `://` (a relative or absolute path to a `.roc` file). `Foreign`: a URL that `Ident.of_url` cannot identify (no hash, no version, 2 versions, `0.0.0`). `Path` and `Foreign` rows are the unmanaged entries: Talon never writes their value (`Set` refuses them) and changes one only as a whole, with `Remove` or `Replace` (R-H4, R-H9). | R-H4, R-H7, R-H9 |
Locked := {
	kind : [App, Package, Platform],
	rows : List(Row),
	roc : Try(Str, [NoPin]),
}.{
	is_eq : _

	Row : { alias : Str, value : Str, is_platform : Bool, what : [Release(Ident), Path, Foreign] }

	## One edit of the header (R-H1):
	##
	## | Op | Does | Rule |
	## | --- | --- | --- |
	## | `Set({ alias, url })` | Replaces the text between the quotes of the entry `alias`. Nothing else changes: `pf: platform` keeps its keyword. Only for a `Release` row: a `Path` or `Foreign` row is refused (R-H4), so a command that moves an unmanaged entry is a Talon fault, not a silent change. | R-H1, R-H4, R-AD31 |
	## | `Replace({ alias, url })` | The whole-entry replace of an unmanaged entry (R-H4, R-H9, R-AD31, R-AD38): the text between the quotes of the entry `alias` becomes `url`, and the keyword stays (`pf: platform` stays). It works for any row, also a `Release` row, but a command uses it for a `Path` or `Foreign` row only. `url` must pass R-H3. Same bytes as `Set` would write. | R-H1, R-H3, R-H4, R-H9, R-AD31, R-AD38 |
	## | `Add({ alias, url, is_platform })` | A whole new entry after the last entry (the form is the one of `Header.add_entry`) | R-H1 |
	## | `Remove(alias)` | Removes the whole entry (`Header.remove_entry`). It works for a release row, a `Path` row and a `Foreign` row: `tln remove` of an unmanaged entry is a whole-entry change that the user asked for (R-H4, R-H9, R-RV5) | R-H1, R-H4, R-H9, R-RV5 |
	## | `Pin(id)` | Sets the text of the `roc:` entry when there is one. Else adds the entry `roc: "<id>"` as the last entry. | R-H6, R-RP3 |
	Op : [Set({ alias : Str, url : Str }), Replace({ alias : Str, url : Str }), Add({ alias : Str, url : Str, is_platform : Bool }), Remove(Str), Pin(Str)]

	## Reads the header of the text. `path` is for the message. Failures are the ones of `Project.check_header` (R-PD8, R-TF5): no header is kind
	## `Usage`, `<path> has no app, package or platform header`. A header that does not parse is kind `Input`,
	## `<path>:<line>: the header is not valid`. A `roc:` pin that is not a full compiler id (R-SC12) is kind `Input` (exit 19, R-EC19): `<path>:<line>: the roc pin <text> is not a full compiler id`. A platform header gives its `packages` record. A package header is read as an app header is (R-H8): its
	## versions are minimums for the apps that use it, and Talon reads and writes them in the same way.
	read : { path : Str, text : Str } -> Try(Locked, Fail)
	read = |facts| {
		kind = Project.check_header(facts)?
		match Header.parse(facts.text) {
			Ok(header) => {
				entries = header.entries()
				roc = match entries.find_first(|e| e.name == "roc") {
					Ok(e) => {
						# R-SC12, R-EC19: a pin is a full compiler id, not a prefix.
						if !Pin.is_id(e.value) return Err(Fail.new(Input, "${facts.path}:${line_of(facts.text, e.span.start).to_str()}: the roc pin ${e.value} is not a full compiler id"))
						Ok(e.value)
					}
					Err(_) => Err(NoPin)
				}
				Ok({ kind, rows: entries.keep_if(|e| e.name != "roc").map(row_of), roc })
			}
			Err(_) => Err(Fail.new(Internal, "${facts.path}: the header changed while it was read"))
		}
	}

	## The path entries of the header: the `value` of each `Path` row, in source order. The command reads the header of each of these files
	## (relative to the project file) and adds its URL entries to the closure (R-H7). The closure walk is slice 007.
	paths : Locked -> List(Str)
	paths = |locked| locked.rows.keep_oks(|r| if r.what == Path Ok(r.value) else Err(NotPath))

	## Applies the ops in order. The result is the new text. Each failure is of kind `Internal` (exit 1): a command must never ask for it, so it is
	## a Talon fault, and nothing is written (the texts are a proposal, TW24):
	##
	## | Case | Message |
	## | --- | --- |
	## | `Set` of a `Path` or `Foreign` row (`Remove` and `Replace` are allowed: R-H9) | `<alias> is a path entry or a foreign URL: tln never changes it (R-H4)` |
	## | `Set`, `Replace`, `Add` with a URL that `Ident.of_url` does not accept | `<url> is not a release URL with a version and a hash (R-H3)` |
	## | `Set`, `Replace` or `Remove` of an alias that is not in the header | `<alias> is not in the header` |
	## | `Add` of an alias that is in the header (or `roc`) | `<alias> is already in the header` |
	## | A value that the span edit cannot write (`"`, `\`, `$`, a line break) | `<url> cannot be written to a header` |
	## | A header that does not parse | The failure of `read` |
	edit : { path : Str, text : Str, ops : List(Op) } -> Try(Str, Fail)
	edit = |facts| facts.ops.fold_try(facts.text, |text, op| apply_op(facts.path, text, op))

	## R-CC7: the text of each span that the ops change, cut from `text`, in the order of the ops: the value of the entry for `Set`, `Replace` and `Remove`
	## (`""` when the entry is not there), `""` for `Add` of a new alias, the value of the `roc:` entry for `Pin` (`""` when there is none). The command
	## gives these lists to `Guard.check_all`, once for the text that it read and once for the text that it reads again just before the write.
	spans : { text : Str, ops : List(Op) } -> List(Str)
	spans = |facts| match Header.parse(facts.text) {
		Ok(header) => facts.ops.map(|op| entry_text(header, op))
		Err(_) => facts.ops.map(|_| "")
	}
}

row_of : { name : Str, value : Str, is_platform : Bool, span : { start : U64, end : U64 }, value_span : { start : U64, end : U64 } } -> Locked.Row
row_of = |e| {
	what = match Ident.of_url(e.value) {
		Ok(ident) => Release(ident)
		Err(Foreign) => if e.value.contains("://") Foreign else Path
	}
	{ alias: e.name, value: e.value, is_platform: e.is_platform, what }
}

internal : Str -> Fail
internal = |message| Fail.new(Internal, message)

# The alias that an op names, and whether it must be in the header.
alias_of : Locked.Op -> Str
alias_of = |op| match op {
	Set({ alias, .. }) => alias
	Replace({ alias, .. }) => alias
	Add({ alias, .. }) => alias
	Remove(alias) => alias
	Pin(_) => "roc"
}

# The text that the span of the op holds now (R-CC7).
entry_text : Header, Locked.Op -> Str
entry_text = |header, op| match header.entries().find_first(|e| e.name == alias_of(op)) {
	Ok(e) => e.value
	Err(_) => ""
}

# Checks of R-H3 and R-H4 for the entry of one op, on the current text.
check_row : Locked, Str -> Try({}, Fail)
check_row = |locked, alias| match locked.rows.find_first(|r| r.alias == alias) {
	Err(_) => Err(internal("${alias} is not in the header"))
	Ok(row) => match row.what {
		Release(_) => Ok({})
		_ => Err(internal("${alias} is a path entry or a foreign URL: tln never changes it (R-H4)"))
	}
}

check_url : Str -> Try({}, Fail)
check_url = |url| match Ident.of_url(url) {
	Ok(_) => Ok({})
	Err(Foreign) => Err(internal("${url} is not a release URL with a version and a hash (R-H3)"))
}

apply_op : Str, Str, Locked.Op -> Try(Str, Fail)
apply_op = |path, text, op| {
	locked = Locked.read({ path, text })?
	present = |alias| locked.rows.any(|r| r.alias == alias) or (alias == "roc" and locked.roc != Err(NoPin))
	written = |url, result| match result {
		Ok(done) => Ok(done)
		Err(BadValue) => Err(internal("${url} cannot be written to a header"))
		Err(Exists) => Err(internal("${url} is already in the header"))
		Err(NotFound) => Err(internal("${url} is not in the header"))
		Err(_) => Err(internal("${path}: the header changed while it was edited"))
	}
	match op {
		Set({ alias, url }) => {
			check_row(locked, alias)?
			check_url(url)?
			written(url, Header.set_value(text, alias, url))
		}
		Add({ alias, url, is_platform }) => {
			if present(alias) return Err(internal("${alias} is already in the header"))
			check_url(url)?
			written(url, Header.add_entry(text, { name: alias, value: url, is_platform }))
		}
		Replace(_) => crash "todo"
		Remove(alias) => {
			# R-RV5: a path row and a foreign row go too (`check_row` refuses them for `Set` only).
			if !locked.rows.any(|r| r.alias == alias) return Err(internal("${alias} is not in the header"))
			written(alias, Header.remove_entry(text, alias))
		}
		Pin(id) => match locked.roc {
			Ok(_) => written(id, Header.set_value(text, "roc", id))
			Err(NoPin) => written(id, Header.add_entry(text, { name: "roc", value: id, is_platform: Bool.False }))
		}
	}
}

# The 1-based line of the byte offset.
line_of : Str, U64 -> U64
line_of = |text, offset| text.to_utf8().take_first(offset).fold(1, |n, b| if b == '\n' n + 1 else n)
