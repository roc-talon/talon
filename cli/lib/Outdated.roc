import records.Closure as Wire
import Args
import Db
import Epochs
import Fail
import Ident
import Index
import JsonDoc
import Opts
import Pick
import Vars
import ProbeRange

## The output and the decisions of `tln outdated` (slice 040, R-CM6, R-DI1, R-DI11, R-DI12, R-PD5, R-PD9, R-PD14). It shows, for each header entry that is behind, the version that the header has (`current`), the newest release inside its range (`wanted`),
## the newest release in any series (`latest`) and the nightly range of the current release from the facts that are known (R-PB3, `ProbeRange.found`). It resolves nothing, runs no probe, downloads no archive and compiler,
## and writes no project file (header, `talon.toml`). The texts and the `data` fields are a proposal (R-OUT2, TW24).
##
## The rows of a member:
##
## | Column | Value | Rule |
## | --- | --- | --- |
## | `package` | The first alias of the group | R-WS1 |
## | `current` | The version of the first use in the header | R-C9 |
## | `wanted` | `Outdated.versions`: the newest release of the group of `current` that the ranges admit (the key of `talon.toml`, or the implied range) | R-C1, R-C6, R-C7, R-UP10 |
## | `latest` | `Outdated.versions`: the newest release of the URL form in any series, with no range. Another series: the text ends with ` (new series)` | R-UP1, R-UP12, R-UP3 |
## | `nightly range` | `Outdated.range_text` of `Outdated.range_of` for the hash of the current release | R-PB3, R-EP6, R-EP11 |
##
## A row is shown when `Outdated.behind` holds: `current` differs from `wanted` or from `latest`. An entry at its newest release has no row. A `Fixed` host (R-DI11) has no row and gives one line `Index.fixed_line`. A path entry and a foreign URL are no variable, so they are not shown.
##
##
## The command code is `OutdatedFlow.run!`. This module is the pure part (TESTING.md 2.2 part A): `read`, `versions`, `range_of`, `range_text`, `behind`, `text`, `data`.
Outdated :: [].{

	## The nightly range of a row: `Known` is the result of `ProbeRange.found` over the facts. `Unread` is no list of compilers (D is empty).
	Range : [Known(ProbeRange.Found), Unread]

	## One row of the table. The versions are `X.Y.Z`. `name` is `owner/repo`.
	Row : { alias : Str, name : Str, current : Str, wanted : Str, latest : Str, new_series : Bool, range : Outdated.Range }

	## One member: its project file, the rows that are behind, and the hosts with no index (R-DI11), in the order of the groups, with no repeat.
	Member : { file : Str, rows : List(Outdated.Row), fixed : List(Str) }

	## The operands and flags of `tln outdated`. `Opts.read` of the line is checked first (its failures: the texts of `Opts.read`, R-FL5). Then:
	##
	## | Case | Failure (kind `Usage`, exit 2) |
	## | --- | --- |
	## | One name or more | `tln outdated takes no name` |
	read : Args -> Try({}, Fail)
	read = |args| {
		_ = Opts.read(args)?
		if args.operands.is_empty() Ok({}) else Err(Fail.new(Usage, "tln outdated takes no name"))
	}

	## The `wanted` and the `latest` version of one group (R-UP10, R-UP12). `current` is the URL of the header. `list` are the candidates of the repository (`Index.candidates`, any URL form and series).
	## The domain of each value is the one of `Pick.step` (rules 1 to 3): the candidates, and the header value (R-C9); a candidate that `min-release-age` or the snapshot hides is out (R-C7, `now`, `min_age`, `snapshot`; a pattern of `exclude` lifts the age, R-C15); the newest version wins.
	##
	## | Value | Candidates | Ranges |
	## | --- | --- | --- |
	## | `wanted` | The group of `current` (`Index.in_group`) | `ranges` (R-C1) |
	## | `latest` | The URL form of `current`, every series | none (R-UP1) |
	##
	## `new_series` is true when the group of `latest` is not the group of `current`. A `current` that is no release URL gives `""` for both values. An empty `list` gives the version of `current` for both.
	versions : { current : Str, ranges : List(Str), list : List(Index.Candidate), now : U64, min_age : U64, exclude : List(Str), snapshot : Try(U64, [None]) } -> { wanted : Str, latest : Str, new_series : Bool }
	versions = |x| match Ident.of_url(x.current) {
		Err(Foreign) => { wanted: "", latest: "", new_series: Bool.False }
		Ok(current) => {
			ctx = { now: x.now, min_age: x.min_age, exclude: x.exclude, snapshot: x.snapshot, facts: [] }
			slot = |ranges, candidates| { id: "", is_platform: Bool.False, ranges, current: Ok(x.current), hold: Free, named: Err(None), candidates, files: [] }
			wanted = Pick.newest_in(slot(x.ranges, Index.in_group({ list: x.list, group: current.group })), ctx)
			latest = Pick.newest(slot([], x.list.keep_if(|c| c.ident.group.form == current.group.form)), ctx)
			{
				wanted: wanted.map_ok(|c| c.ident.version) ?? current.version,
				latest: latest.map_ok(|c| c.ident.version) ?? current.version,
				new_series: latest.map_ok(|c| c.ident.group != current.group) ?? Bool.False,
			}
		}
	}

	## The nightly range of the hash on the compiler list `domain` (R-PB3): `ProbeRange.found` with no askable release, so it reads facts only. An empty `domain` is `Unread`.
	## Slice 206e3 (R-EP15): `epochs` go to `ProbeRange.Input.epochs` (`[]` with no registry answer).
	range_of : { hash : Str, domain : List(Str), facts : List(Db.Fact), epochs : List(Epochs.Interval) } -> Outdated.Range
	range_of = |x| if x.domain.is_empty() Unread else Known(ProbeRange.found({ hash: x.hash, domain: x.domain, askable: [], facts: x.facts, epochs: x.epochs }))

	## The cell of the range. `<from> .. <to>`, with a `?` after an end that is not a real fact (R-PB4). No real pass: `none known`. No list: `-`.
	range_text : Outdated.Range -> Str
	range_text = |range| match range {
		Unread => "-"
		Known(NoPass) => "none known"
		Known(Range(ends)) => "${end_text(ends.from)} .. ${end_text(ends.to)}"
	}

	## Is the row shown? `current` differs from `wanted` or from `latest`.
	behind : Outdated.Row -> Bool
	behind = |row| row.current != row.wanted or row.current != row.latest

	## Slice 252 (Registry R-PU28, R-AP32, R-MV5; Q252-9; section 7a of docs/slices/252-successor-follow.md, a proposal, TW24): a repository whose `repos` item has a successor. `name` is the name of the row (`owner/repo`), `successor` the `successor` member of the item (the first link, not the end of a chain).
	## It is a separate list, so `Row` keeps its members.
	Moved : { name : Str, successor : Str }

	## Slice 252: the `Moved` items of the names of the rows, from the `repos` items of the answer (or of the kept copies with `--offline`). Names are compared in lower case. A name with no item or no successor has none. Each name once, in the order of `names`.
	moved_names : { names : List(Str), repos : List(Wire.Repo) } -> List(Outdated.Moved)
	moved_names = |facts| facts.names.keep_oks(
		|name| match facts.repos.find_first(|p| p.name.with_ascii_lowercased() == name.with_ascii_lowercased()) {
			Ok(item) => item.successor.map_ok(|successor| { name, successor }).map_err(|_| None)
			Err(_) => Err(None)
		},
	)

	## Slice 262b (R-CM6, B11, Design Q642): an anchor of a use: the file, the alias and the range text `=<v>`. A row of that file and alias has the cell ` (pinned)` and the member `pinned`. It is a separate list, so `Row` keeps its members.
	Pin : { file : Str, alias : Str, range : Str }

	## Slice 262b: the anchors of the variables (a range that starts with `=`), one for each use.
	pins_of : List(Vars.Var) -> List(Outdated.Pin)
	pins_of = |vars| vars.join_map(
		|v| match v.ranges.find_first(|r| r.range.starts_with("=")) {
			Ok(r) => v.uses.map(|u| { file: u.file, alias: u.alias, range: r.range })
			Err(_) => []
		},
	)

	## Slice 262b: the anchor of a row of a member file, if any.
	pin_of : Str, Outdated.Row, List(Outdated.Pin) -> Try(Str, [None])
	pin_of = |file, row, pins| pins.find_first(|p| p.file == file and p.alias == row.alias).map_ok(|p| p.range).map_err(|_| None)

	## Slice 252: the successor of the name of a row, if any.
	successor_of : Outdated.Row, List(Outdated.Moved) -> Try(Str, [None])
	successor_of = |row, moved| moved.find_first(|m| m.name.with_ascii_lowercased() == row.name.with_ascii_lowercased()).map_ok(|m| m.successor).map_err(|_| None)

	## Slice 252 (R-PU28: `tln outdated` shows `moved to <successor>` in the row of each header entry whose name has a successor): a row is shown when it is behind, or when its name has a successor.
	is_shown : Outdated.Row, List(Outdated.Moved) -> Bool
	is_shown = |row, moved| Outdated.behind(row) or Outdated.successor_of(row, moved).is_ok()

	## The text of one member (a proposal, TW24). The first line is the project file. Then the table: the header row and one row for each row, the columns padded to the longest cell and 2 spaces (the last column is not padded), 2 spaces at the start of each line.
	## No row: `  all packages are up to date`. Then one line `  <Index.fixed_line(host)>` for each host. Each line ends with a line end.
	##
	## ```text
	## /p/main.roc
	##   package  current  wanted  latest              nightly range
	##   json     2.1.0    2.2.0   3.0.2 (new series)  nightly-2026-10-09-258ab27 .. nightly-2026-10-12-2a2a2a2?
	##   fixed: example.org has no index without a registry
	## ```
	text : Outdated.Member -> Str
	text = |member| Outdated.text_moved(member, [], [])

	## Slice 252 (section 7a, a proposal): `text` with the `Moved` items. The `latest` cell of a row whose name has a successor ends with ` (moved to <successor>)`, after ` (new series)`.
	text_moved : Outdated.Member, List(Outdated.Moved), List(Outdated.Pin) -> Str
	text_moved = |member, moved, pins| {
		shown = if member.rows.is_empty() ["  all packages are up to date\n"] else table_lines(member.file, member.rows, moved, pins)
		fixed = member.fixed.map(|host| "  ${Index.fixed_line(host)}\n")
		"${member.file}\n${Str.join_with(shown.concat(fixed), "")}"
	}

	## The `data` of `--json` (R-J3, R-J4, R-OUT4, R-OUT5). Keys in this order.
	##
	## | Key | Value |
	## | --- | --- |
	## | `members` | A list, one object for each member, in the order of the members: `file`, `packages`, `fixed` |
	## | `packages` | The rows that are shown: `alias`, `name`, `current`, `wanted`, `latest`, `new_series` (a flag), `nightly_range` |
	## | `fixed` | The hosts with no index (R-DI11), as the text of the member has them |
	## | `nightly_range` | An object with `state`: `range` (and `from`, `to`: `{ "id", "real" }` as `tln probe --range`), `no-pass`, or `unread` |
	data : List(Outdated.Member) -> JsonDoc
	data = |members| Outdated.data_moved(members, [], [])

	## Slice 252 (section 7a, a proposal): `data` with the `Moved` items. The object of a package whose name has a successor has the member `successor` (a full name) after `new_series`. The other objects keep their members.
	data_moved : List(Outdated.Member), List(Outdated.Moved), List(Outdated.Pin) -> JsonDoc
	data_moved = |members, moved, pins| JsonDoc.Obj([("members", Arr(members.map(|m| member_doc(m, moved, pins))))])
}

# R-PB4: an end that is no real fact has a `?`.
end_text : ProbeRange.End -> Str
end_text = |end| if end.real end.id else "${end.id}?"

# The header row and one row for each row, the first 4 columns padded to the longest cell and 2 spaces.
table_lines : Str, List(Outdated.Row), List(Outdated.Moved), List(Outdated.Pin) -> List(Str)
table_lines = |file, rows, moved, pins| {
	head = { alias: "package", current: "current", wanted: "wanted", latest: "latest", range: "nightly range" }
	latest_cell = |r| {
		series = if r.new_series "${r.latest} (new series)" else r.latest
		match Outdated.successor_of(r, moved) {
			Ok(successor) => "${series} (moved to ${successor})"
			Err(None) => series
		}
	}
	cells = [head].concat(rows.map(|r| { alias: r.alias, current: r.current, wanted: if Outdated.pin_of(file, r, pins).is_ok() "${r.wanted} (pinned)" else r.wanted, latest: latest_cell(r), range: Outdated.range_text(r.range) }))
	widths = {
		alias: widest(cells.map(|c| c.alias)),
		current: widest(cells.map(|c| c.current)),
		wanted: widest(cells.map(|c| c.wanted)),
		latest: widest(cells.map(|c| c.latest)),
	}
	cells.map(|c| "  ${pad(c.alias, widths.alias)}${pad(c.current, widths.current)}${pad(c.wanted, widths.wanted)}${pad(c.latest, widths.latest)}${c.range}\n")
}

widest : List(Str) -> U64
widest = |cells| cells.map(|c| c.count_utf8_bytes()).max() ?? 0

pad : Str, U64 -> Str
pad = |cell, width| cell.concat(" ".repeat(width + 2 - cell.count_utf8_bytes()))

member_doc : Outdated.Member, List(Outdated.Moved), List(Outdated.Pin) -> JsonDoc
member_doc = |member, moved, pins| JsonDoc.Obj([
	("file", Text(member.file)),
	("packages", Arr(member.rows.map(|r| row_doc(r, Outdated.pin_of(member.file, r, pins), moved)))),
	("fixed", Arr(member.fixed.map(|host| JsonDoc.Text(host)))),
])

row_doc : Outdated.Row, Try(Str, [None]), List(Outdated.Moved) -> JsonDoc
row_doc = |row, pin, moved| {
	pinned = match pin {
		Ok(range) => [("pinned", JsonDoc.Text(range))]
		Err(None) => []
	}
	successor = match Outdated.successor_of(row, moved) {
		Ok(name) => [("successor", JsonDoc.Text(name))]
		Err(None) => []
	}
	JsonDoc.Obj(
		[
			("alias", JsonDoc.Text(row.alias)),
			("name", Text(row.name)),
			("current", Text(row.current)),
			("wanted", Text(row.wanted)),
			("latest", Text(row.latest)),
			("new_series", Flag(row.new_series)),
		]
			.concat(successor)
			.concat(pinned)
			.concat([("nightly_range", range_doc(row.range))]),
	)
}

range_doc : Outdated.Range -> JsonDoc
range_doc = |range| match range {
	Unread => JsonDoc.Obj([("state", Text("unread"))])
	Known(NoPass) => JsonDoc.Obj([("state", Text("no-pass"))])
	Known(Range(ends)) => JsonDoc.Obj([("state", Text("range")), ("from", end_doc(ends.from)), ("to", end_doc(ends.to))])
}

end_doc : ProbeRange.End -> JsonDoc
end_doc = |end| JsonDoc.Obj([("id", Text(end.id)), ("real", Flag(end.real))])
