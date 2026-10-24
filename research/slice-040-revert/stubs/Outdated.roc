import Args
import Db
import Fail
import Index
import JsonDoc
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
	read = |_args| crash "todo"

	## The `wanted` and the `latest` version of one group (R-UP10, R-UP12). `current` is the URL of the header. `list` are the candidates of the repository (`Index.candidates`, any URL form and series).
	## The domain of each value is the one of `Pick.step` (rules 1 to 3): the candidates, and the header value (R-C9); a candidate that `min-release-age` or the snapshot hides is out (R-C7, `now`, `min_age`, `snapshot`); the newest version wins.
	##
	## | Value | Candidates | Ranges |
	## | --- | --- | --- |
	## | `wanted` | The group of `current` (`Index.in_group`) | `ranges` (R-C1) |
	## | `latest` | The URL form of `current`, every series | none (R-UP1) |
	##
	## `new_series` is true when the group of `latest` is not the group of `current`. A `current` that is no release URL gives `""` for both values. An empty `list` gives the version of `current` for both.
	versions : { current : Str, ranges : List(Str), list : List(Index.Candidate), now : U64, min_age : U64, snapshot : Try(U64, [None]) } -> { wanted : Str, latest : Str, new_series : Bool }
	versions = |_x| crash "todo"

	## The nightly range of the hash on the compiler list `domain` (R-PB3): `ProbeRange.found` with no askable release, so it reads facts only. An empty `domain` is `Unread`.
	range_of : { hash : Str, domain : List(Str), facts : List(Db.Fact) } -> Outdated.Range
	range_of = |_x| crash "todo"

	## The cell of the range. `<from> .. <to>`, with a `?` after an end that is not a real fact (R-PB4). No real pass: `none known`. No list: `-`.
	range_text : Outdated.Range -> Str
	range_text = |_range| crash "todo"

	## Is the row shown? `current` differs from `wanted` or from `latest`.
	behind : Outdated.Row -> Bool
	behind = |_row| crash "todo"

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
	text = |_member| crash "todo"

	## The `data` of `--json` (R-J3, R-J4, R-OUT4, R-OUT5). Keys in this order.
	##
	## | Key | Value |
	## | --- | --- |
	## | `members` | A list, one object for each member, in the order of the members: `file`, `packages`, `fixed` |
	## | `packages` | The rows that are shown: `alias`, `name`, `current`, `wanted`, `latest`, `new_series` (a flag), `nightly_range` |
	## | `fixed` | The hosts with no index (R-DI11), as the text of the member has them |
	## | `nightly_range` | An object with `state`: `range` (and `from`, `to`: `{ "id", "real" }` as `tln probe --range`), `no-pass`, or `unread` |
	data : List(Outdated.Member) -> JsonDoc
	data = |_members| crash "todo"
}
