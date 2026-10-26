import Args
import Clock
import Fail
import JsonDoc
import Locked
import ManageUpdate
import ManageUse
import Pin
import Text
import toml.Toml
import toml.Value

## The pure decisions of `tln roc list`, `tln roc default` and `tln roc remove` (slice 024, CLI 6.6, R-CS2, R-RR1 to R-RR3). The commands are in `RocManage`. Texts and `data` fields are a proposal (R-OUT2, TW24).
##
## | Command | What the pure part decides |
## | --- | --- |
## | `roc list` (`ls`) | The rows, the table, the `data` |
## | `roc default <ref>` | The operand, the edit of `default-roc` in `config.toml`, the text, the `data` |
## | `roc remove <id>` (`rm`) | The operand, the next default (R-RR1), the projects that pin the compiler (R-RR2), the compat id to remove (R-GC3), the trash name (R-CC10), the text, the `data` |
Manage :: [].{

	## The text of a file that `Fx.read_files!` gave: the text, or the reason.
	Read : Try(Str, [NotFound, Denied, Other(Str)])

	## One row of `roc list`. `installed_at` is the time of `.talon.json` (`installed_at`), `last_use` is the time of `.last-use` (R-CC9). A missing file, text that does not parse and a bad time give `Err(Unknown)`.
	Row : {
		id : Str,
		kind : [Nightly, Release, Git, Link, Copy],
		installed_at : Try(U64, [Unknown]),
		last_use : Try(U64, [Unknown]),
		is_default : Bool,
	}

	## Slice 071 (R-R15): where a `git-*` build came from. `id` is the toolchain id, `repo` is the `repo` field of its `.talon.json` as it is (the URL `https://github.com/<owner>/<repo>`, R-R1), `ref` is the `ref` field (the text the user typed: a branch, a tag or a sha).
	Origin : { id : Str, repo : Str, ref : Str }

	## R-CC9 (shared by `roc list` and `cache gc`): the 2 results of each id (`.talon.json`, then `.last-use`), in one list of `Fx.read_files!` results (2 for each id, in the order of `ids`).
	found_of : List(Str), List(Manage.Read) -> List({ id : Str, meta : Manage.Read, last_use : Manage.Read })
	found_of = |ids, reads| ids.map2(
		reads.chunks_of(2),
		|id, pair| match pair {
			[meta, last_use] => { id, meta, last_use }
			_ => { id, meta: Err(NotFound), last_use: Err(NotFound) }
		},
	)

	## R-LY1: the kind of an installed id. A name that starts with `git-`, `link-` or `copy-` is that kind. A nightly tag (`Pin.is_nightly`) is `Nightly`. Any other id of `Compiler.installed` is a `Release`.
	kind_of : Str -> [Nightly, Release, Git, Link, Copy]
	kind_of = |id| if id.starts_with("git-") {
		Git
	} else if id.starts_with("link-") {
		Link
	} else if id.starts_with("copy-") {
		Copy
	} else if Pin.is_nightly(id) {
		Nightly
	} else {
		Release
	}

	## The word of a kind in the table and in `--json`: `nightly`, `release`, `git`, `link`, `copy`.
	kind_text : [Nightly, Release, Git, Link, Copy] -> Str
	kind_text = |kind| match kind {
		Nightly => "nightly"
		Release => "release"
		Git => "git"
		Link => "link"
		Copy => "copy"
	}

	## R-CM15, R-CM19: the operand of `roc default` and `roc remove`: one text, as typed. No operand and 2 or more are failures of kind `Usage` (exit 2). The text names the long form of the command, also when the user typed `rm`:
	##
	## | Verb | No operand | 2 or more |
	## | --- | --- | --- |
	## | `Default` | `tln roc default needs one compiler: a full id, a prefix or @latest` | `tln roc default takes one compiler, got <n>` |
	## | `Remove` | `tln roc remove needs one compiler: a full id or a prefix of an installed compiler` | `tln roc remove takes one compiler, got <n>` |
	read : { args : Args, verb : [Default, Remove] } -> Try(Str, Fail)
	read = |facts| {
		word = match facts.verb {
			Default => "default"
			Remove => "remove"
		}
		need = match facts.verb {
			Default => "a full id, a prefix or @latest"
			Remove => "a full id or a prefix of an installed compiler"
		}
		match facts.args.operands {
			[one] => Ok(one)
			[] => Err(Fail.new(Usage, "tln roc ${word} needs one compiler: ${need}"))
			many => Err(Fail.new(Usage, "tln roc ${word} takes one compiler, got ${many.len().to_str()}"))
		}
	}

	## R-CM15 (question Q1 of the slice file): `roc list` takes no operand. 1 or more is a failure of kind `Usage`: `tln roc list takes no operand, got <n>`. The text names the long form (R-CM19).
	read_list : Args -> Try({}, Fail)
	read_list = |args| match args.operands {
		[] => Ok({})
		many => Err(Fail.new(Usage, "tln roc list takes no operand, got ${many.len().to_str()}"))
	}

	## R-LY1, R-CC9: the rows of `roc list`, in the order of `found` (the caller gives the ids in `Compiler.installed` order). `meta` is the text of `toolchains/<id>/.talon.json`, `last_use` is the text of `.last-use`.
	## `installed_at` is the text field `installed_at` of the JSON object (`Clock.parse_utc`). `last_use` is the trimmed text of the file (`Clock.parse_utc`). `is_default` is `Pin.same_id` of `default` and the id.
	rows : { found : List({ id : Str, meta : Manage.Read, last_use : Manage.Read }), default : Try(Str, [Unset]) } -> List(Manage.Row)
	rows = |facts| facts.found.map(
		|item| {
			id: item.id,
			kind: Manage.kind_of(item.id),
			installed_at: time_of(item.meta, "installed_at"),
			last_use: last_use_of(item.last_use),
			is_default: match facts.default {
				Ok(default) => Pin.same_id(default, item.id)
				Err(Unset) => Bool.False
			},
		},
	)

	## Slice 071, R-R15, R-R1: the origins of the items of `found`, in the order of `found`. An item gives one `Origin` only when its id is of the kind `Git` (`Manage.kind_of`) and its `meta` is a JSON object with a text `repo` and a text `ref`. The two texts are as they are in the file (no change; an empty text is a text).
	## An item of another kind, a `meta` that is not readable, and a `meta` that lacks `repo` or `ref` or has a field that is not a text, gives nothing (the list is shorter). The rows find their origin by `id` (`ls_report`, `ls_data`), never by position.
	origins : List({ id : Str, meta : Manage.Read, last_use : Manage.Read }) -> List(Manage.Origin)
	origins = |_found| crash "todo: slice 071"

	## R-OUT2 (a proposal): the table of `roc list`. The streams:
	##
	## | Case | stdout | stderr |
	## | --- | --- | --- |
	## | No row | `no compiler is installed. Run: tln roc install @latest` | |
	## | Rows | The header and one line for each row, in the order of `rows`. The columns are `ID`, `KIND`, `INSTALLED`, `LAST USE`, each padded to its widest cell and separated by 2 spaces. The first 2 characters are `* ` for the default and 2 spaces for the others. A time is the date (`YYYY-MM-DD`), an unknown time is `-`. No trailing spaces. | |
	## | A default that is not in `rows` | the table as above | `warning: the default compiler <id> is not installed` |
	##
	## Slice 071 (R-R15, proposal): `origins` is the result of `Manage.origins`. A row takes the origin with the same `id` (the first one, if two have it); an origin whose id is not a row is ignored. When at least one row has an origin, the table has a fifth column
	## `SOURCE` (so `LAST USE` is padded as the other columns): `owner/repo@ref` for a row with an origin, `-` for the other rows. `owner/repo` is the `repo` URL without the start `https://github.com/` when the URL has that start and then exactly 2 non-empty parts
	## (no more `/`); any other `repo` text shows in full. With no row that has an origin the table is as before (no column). The warning and the empty case do not change.
	##
	## Each element is one line with its `\n`.
	ls_report : { rows : List(Manage.Row), origins : List(Manage.Origin), default : Try(Str, [Unset]) } -> { stdout : List(Str), stderr : List(Str) }
	ls_report = |facts| {
		warning = match facts.default {
			Ok(id) if !facts.rows.any(|r| r.is_default) => ["warning: the default compiler ${id} is not installed\n"]
			_ => []
		}
		if facts.rows.is_empty() {
			{ stdout: ["no compiler is installed. Run: tln roc install @latest\n"], stderr: warning }
		} else {
			{ stdout: table(facts.rows), stderr: warning }
		}
	}

	## R-J3, R-J4, R-OUT4 (a proposal): the `data` of `roc list --json`, the keys in this order: `default` (the id of `default` as text, or `null`), `compilers` (an array, one object for each row, in the order of `rows`).
	## The keys of a row: `id`, `kind`, `installed_at` (`Clock.format_utc` or `null`), `last_use` (the same), `default` (true for the default).
	##
	## Slice 071 (R-R15, R-OUT4, proposal): the row of a `git` kind has 2 more keys after `default`: `repo` and `ref`, the texts of its `Manage.Origin` as they are (the stored URL, raw), or `null` for both when no origin has its id. A row of another kind has no such key.
	ls_data : { rows : List(Manage.Row), origins : List(Manage.Origin), default : Try(Str, [Unset]) } -> JsonDoc
	ls_data = |facts| JsonDoc.Obj([
		("default", text_or_null(facts.default.map_err(|Unset| None))),
		("compilers", JsonDoc.Arr(facts.rows.map(row_doc))),
	])

	## R-CS2, R-CC6, R-LY1, R-CC7: the edit of `config.toml` that makes `id` the global default. `text` is the file (the empty text when it does not exist). `id` is a full id.
	##
	## | The key `default-roc` | `edit` | `previous` |
	## | --- | --- | --- |
	## | A text, equal to `id` | `Same` (no write) | `Ok(<the text>)` |
	## | A text, another value | `Set(<new text>)`: the value is replaced by the span edit of `roc-toml` (`Toml.replace`): every other byte stays | `Ok(<the old text>)` |
	## | Not there | `Set(<new text>)`: the line `default-roc = "<id>"` is added (`Toml.insert`), the empty text gives the one line and a line end | `Err(Unset)` |
	## | Not a text | A failure of kind `Input` (exit 19): `<path>: default-roc is not a text` | |
	##
	## A text that is not TOML is a failure of kind `Input` (exit 19): `<path>:<line>: not valid TOML` (as `Intent.read_config`).
	default_set : { path : Str, text : Str, id : Str } -> Try({ previous : Try(Str, [Unset]), edit : [Same, Set(Str)] }, Fail)
	default_set = |facts| {
		doc = parse_toml(facts.path, facts.text)?
		match Toml.get(doc, ["default-roc"]) {
			Ok(Value.String(old)) if old == facts.id => Ok({ previous: Ok(old), edit: Same })
			Ok(Value.String(old)) => match Toml.replace(doc, ["default-roc"], Value.String(facts.id)) {
				Ok(done) => Ok({ previous: Ok(old), edit: Set(done.to_str()) })
				Err(NoEntry) => Err(cannot_write(facts.path))
			}
			Ok(_) => Err(Fail.new(Input, "${facts.path}: default-roc is not a text"))
			Err(NotFound) => match Toml.insert(doc, ["default-roc"], Value.String(facts.id)) {
				Ok(done) => Ok({ previous: Err(Unset), edit: Set(done.to_str()) })
				Err(_) => Err(cannot_write(facts.path))
			}
		}
	}

	## R-RR1, R-CC6: the edit of `config.toml` that unsets the global default (no compiler is left to take it): the line `default-roc` is removed (`Toml.remove`), every other byte stays. No key: `Same`. A text that is not TOML:
	## a failure of kind `Input` as for `default_set`.
	default_unset : { path : Str, text : Str } -> Try([Same, Set(Str)], Fail)
	default_unset = |facts| {
		doc = parse_toml(facts.path, facts.text)?
		match Toml.remove(doc, ["default-roc"]) {
			Ok(done) => Ok(Set(done.to_str()))
			Err(NoEntry) => Ok(Same)
		}
	}

	## R-RR1, R-NS3, R-NS6: the compiler that takes the global default when the default `removed` goes. The newest by `Pin.order` (with `times`) of the ids in `installed` except `removed`, that are a release, or a nightly when `nightly`
	## (the `nightly` switch) is true. Review (G2): the order is `Pin.order` with `times`, as rank 4: a release with a date in `times` is ordered by its date, so a release newer than every nightly wins. A `git-`, `link-` or `copy-` id is never chosen (R-NS6: chosen by name only). None: `Err(None)` and the default is not set.
	next_default : { installed : List(Str), removed : Str, nightly : Bool, times : List({ id : Str, published_at : U64 }) } -> Try(Str, [None])
	next_default = |facts| {
		allowed = |id| id != facts.removed and match Manage.kind_of(id) {
			Nightly => facts.nightly
			Release => Bool.True
			_ => Bool.False
		}
		newest = |best, id| if Pin.order({ a: id, b: best, times: facts.times }) == After id else best
		match facts.installed.keep_if(allowed) {
			[first, .. as rest] => Ok(rest.fold(first, newest))
			[] => Err(None)
		}
	}

	## R-RR2, R-PD9, R-PD13: the known projects that pin the compiler `id`. `projects` are the paths of `projects.json` and the text that `Fx.read_files!` gave for each. A project pins `id` when the `roc:` entry of its header is `Pin.same_id` with `id`
	## (the other tag form of a nightly counts). A file that is missing or cannot be read, a header that does not parse and a header with no `roc:` entry pin nothing. The result is the paths in byte order.
	pinned_by : { id : Str, projects : List({ path : Str, text : Manage.Read }) } -> List(Str)
	pinned_by = |facts| {
		pins = |project| match project.text {
			Ok(text) => match Locked.read({ path: project.path, text }) {
				Ok(locked) => match locked.roc {
					Ok(pin) => Pin.same_id(pin, facts.id)
					Err(NoPin) => Bool.False
				}
				Err(_) => Bool.False
			}
			Err(_) => Bool.False
		}
		Text.sorted(facts.projects.keep_if(pins).map(|project| project.path))
	}

	## R-GC3: the compat id that `.talon.json` records (the text field `compat`). A missing file, text that is not JSON, a missing field and `null` give `Err(None)`: no `compat-<id>/` dir is removed.
	compat_of : Manage.Read -> Try(Str, [None])
	compat_of = |meta| match field_of(meta, "compat") {
		Ok(Text(id)) => Ok(id)
		_ => Err(None)
	}

	## R-CC10: the name of the trash dir of a removed compiler: `<item>.<hex>.trash` (`Temp` has the form: `Temp.old` finds it, R-GC6). `hex` is `Temp.hex(Fx.random!())`.
	trash_name : { item : Str, hex : Str } -> Str
	trash_name = |facts| "${facts.item}.${facts.hex}.trash"

	## R-CS2, R-OUT2 (a proposal): the lines of `roc default` on stdout. `installed` is true when this run downloaded the compiler. Each element is one line with its `\n`:
	##
	## | Case | Lines |
	## | --- | --- |
	## | `installed` | `installed <id>` first |
	## | `Set` | `<id> is now the default compiler` |
	## | `Same` | `<id> is already the default compiler` |
	default_report : { id : Str, installed : Bool, edit : [Same, Set] } -> List(Str)
	default_report = |facts| {
		now = match facts.edit {
			Set => "${facts.id} is now the default compiler\n"
			Same => "${facts.id} is already the default compiler\n"
		}
		if facts.installed ["installed ${facts.id}\n", now] else [now]
	}

	## R-J3, R-J4, R-OUT4 (a proposal): the `data` of `roc default --json`, the keys in this order: `id`, `previous` (the old default as text, or `null`), `changed` (true when `default-roc` was written), `installed` (true when this run downloaded the compiler).
	default_data : { id : Str, previous : Try(Str, [Unset]), edit : [Same, Set], installed : Bool } -> JsonDoc
	default_data = |facts| JsonDoc.Obj([
		("id", JsonDoc.Text(facts.id)),
		("previous", text_or_null(facts.previous.map_err(|Unset| None))),
		("changed", JsonDoc.Flag(facts.edit == Set)),
		("installed", JsonDoc.Flag(facts.installed)),
	])

	## R-RR1, R-RR2, R-OUT2 (a proposal): the lines of `roc remove` on stdout, in this order. Each element is one line with its `\n`:
	##
	## | Line | When |
	## | --- | --- |
	## | `removed <id>` | always |
	## | `the default compiler is now <next>` | `was_default` and `next` is `Ok` (R-RR1) |
	## | `no default compiler is set now` | `was_default` and `next` is `Err(None)` (R-RR1) |
	## | `known projects that pin <id> (the proxy installs it again when one runs):`, then `  <path>` for each project | `projects` is not empty (R-RR2) |
	remove_report : { id : Str, was_default : Bool, next : Try(Str, [None]), projects : List(Str) } -> List(Str)
	remove_report = |facts| {
		moved = if facts.was_default {
			match facts.next {
				Ok(next) => ["the default compiler is now ${next}\n"]
				Err(None) => ["no default compiler is set now\n"]
			}
		} else {
			[]
		}
		pinned = if facts.projects.is_empty() {
			[]
		} else {
			["known projects that pin ${facts.id} (the proxy installs it again when one runs):\n"].concat(facts.projects.map(|path| "  ${path}\n"))
		}
		["removed ${facts.id}\n"].concat(moved).concat(pinned)
	}

	## R-J3, R-J4, R-OUT4 (a proposal): the `data` of `roc remove --json`, the keys in this order: `id`, `path` (the dir that was removed), `was_default` (true), `default` (the default after the command as text, or `null`), `projects` (an array of paths).
	remove_data : { id : Str, item : Str, was_default : Bool, default : Try(Str, [None]), projects : List(Str) } -> JsonDoc
	remove_data = |facts| JsonDoc.Obj([
		("id", JsonDoc.Text(facts.id)),
		("path", JsonDoc.Text(facts.item)),
		("was_default", JsonDoc.Flag(facts.was_default)),
		("default", text_or_null(facts.default)),
		("projects", JsonDoc.Arr(facts.projects.map(|path| JsonDoc.Text(path)))),
	])

	## R-RU2 (slice 026): does `roc update` move the global default to the new compiler? `default` is `default-roc` of `config.toml` before the command. Only the kind of the id decides (`kind_of`):
	##
	## | `default` | Result |
	## | --- | --- |
	## | Not set (`Err(Unset)`) | `Move` |
	## | A nightly or a release | `Move` |
	## | `git-*`, `link-*` or `copy-*` | `Stay` (R-RU2, R-NS6: Talon never picks a local build by itself, and never takes the default from one) |
	update_move : { default : Try(Str, [Unset]) } -> [Move, Stay]
	update_move = |facts| match facts.default {
		Err(Unset) => Move
		Ok(id) => match Manage.kind_of(id) {
			Git | Link | Copy => Stay
			Nightly | Release => Move
		}
	}

	# Split to `ManageUpdate` and `ManageUse` (slice 036b3). A unit test calls these names.
	read_update = ManageUpdate.read_update
	update_data = ManageUpdate.update_data
	update_report = ManageUpdate.update_report
	read_use = ManageUse.read_use
	use_data = ManageUse.use_data
	use_note = ManageUse.use_note
	use_pinnable = ManageUse.use_pinnable
	use_plan = ManageUse.use_plan
	use_report = ManageUse.use_report
}

# The JSON object of a `.talon.json` text, then the field `key`. Not JSON, not an object and no field are `Err(None)`.
field_of : Manage.Read, Str -> Try(JsonDoc, [None])
field_of = |read, key| match read {
	Ok(body) => match JsonDoc.parse(body) {
		Ok(JsonDoc.Obj(pairs)) => match pairs.find_first(|(name, _)| name == key) {
			Ok((_, value)) => Ok(value)
			Err(_) => Err(None)
		}
		_ => Err(None)
	}
	Err(_) => Err(None)
}

# R-LY1: a time field of `.talon.json` (a UTC text).
time_of : Manage.Read, Str -> Try(U64, [Unknown])
time_of = |meta, key| match field_of(meta, key) {
	Ok(JsonDoc.Text(when)) => Clock.parse_utc(when).map_err(|BadTime| Unknown)
	_ => Err(Unknown)
}

# R-CC9: `.last-use` is a UTC time and a line end.
last_use_of : Manage.Read -> Try(U64, [Unknown])
last_use_of = |read| match read {
	Ok(text) => Clock.parse_utc(text.trim()).map_err(|BadTime| Unknown)
	Err(_) => Err(Unknown)
}

text_or_null : Try(Str, [None]) -> JsonDoc
text_or_null = |id| match id {
	Ok(text) => JsonDoc.Text(text)
	Err(None) => JsonDoc.Null
}

time_json : Try(U64, [Unknown]) -> JsonDoc
time_json = |time| match time {
	Ok(seconds) => JsonDoc.Text(Clock.format_utc(seconds))
	Err(Unknown) => JsonDoc.Null
}

row_doc : Manage.Row -> JsonDoc
row_doc = |row| JsonDoc.Obj([
	("id", JsonDoc.Text(row.id)),
	("kind", JsonDoc.Text(Manage.kind_text(row.kind))),
	("installed_at", time_json(row.installed_at)),
	("last_use", time_json(row.last_use)),
	("default", JsonDoc.Flag(row.is_default)),
])

# The date of a time (`YYYY-MM-DD`), `-` for no time.
date_text : Try(U64, [Unknown]) -> Str
date_text = |time| match time {
	Ok(seconds) => Str.from_utf8_lossy(Clock.format_utc(seconds).to_utf8().sublist({ start: 0, len: 10 }))
	Err(Unknown) => "-"
}

# R-OUT2: the header and one line for each row. Each column is as wide as its widest cell, the last column has no padding.
table : List(Manage.Row) -> List(Str)
table = |rows| {
	head = { mark: "  ", id: "ID", kind: "KIND", installed: "INSTALLED", used: "LAST USE" }
	body = rows.map(
		|r| {
			mark: if r.is_default "* " else "  ",
			id: r.id,
			kind: Manage.kind_text(r.kind),
			installed: date_text(r.installed_at),
			used: date_text(r.last_use),
		},
	)
	all = [head].concat(body)
	wide = |size, text| size.max(text.count_utf8_bytes())
	id_w = all.fold(0, |size, c| wide(size, c.id))
	kind_w = all.fold(0, |size, c| wide(size, c.kind))
	installed_w = all.fold(0, |size, c| wide(size, c.installed))
	pad = |text, size| "${text}${" ".repeat(size - text.count_utf8_bytes())}"
	all.map(|c| "${c.mark}${pad(c.id, id_w)}  ${pad(c.kind, kind_w)}  ${pad(c.installed, installed_w)}  ${c.used}\n")
}

parse_toml : Str, Str -> Try(Toml, Fail)
parse_toml = |path, text| match Toml.parse(text) {
	Ok(doc) => Ok(doc)
	Err(TomlErr(e)) => Err(Fail.new(Input, "${path}:${e.line.to_str()}: not valid TOML"))
}

cannot_write : Str -> Fail
cannot_write = |path| Fail.new(Internal, "${path}: cannot write default-roc")
