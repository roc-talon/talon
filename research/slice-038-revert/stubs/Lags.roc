import Db
import Pick
import Release
import Vars

## The pure decisions of `tln upgrade` that follow the pick (slice 038, Resolution 10): the variables that did not get their newest release (R-UP2), and the keys of `talon.toml` that move with a version (R-UP5).
## Split from `Upgrade` so that `PickFlow` can call it: `Upgrade` imports `Resolve`, which imports `PickFlow`.
Lags :: [].{

	## One free variable that did not get its newest release (R-UP2). `alias` is the first alias of the slot, `newest` and `got` are versions. `why` is the first reason, by the table of `of`.
	Lag : { alias : Str, newest : Str, got : Str, why : Str }

	## R-UP2: the free variables (`hold: Free`) whose chosen release is not the newest release of their domain, in the order of the slots. The domain is the one of `Pick.step` (R-C6, R-C7, R-C9: a young release is no candidate, the header value stays),
	## and in `upgrade` it has no range (R-UP1). `facts` are the headers that the command read, `checks` and `used` are the facts of the probe rounds for the held compiler `compiler` (`Err(None)`: no probe).
	## The newest release `n` of the slot `a`, the chosen release `c`, and the reason, the first that holds in this order (the text is a proposal, TW24):
	##
	## | # | Reason | `why` |
	## | --- | --- | --- |
	## | 1 | The db has a real row of `n` on the compiler that touches the app: a hang, a crash, a fail with no module, a fail with `main.roc`, or a fail with a module that `used` lists for `n` (R-UM1, R-EP7) | `fails the unit check on <compiler>`, `hangs the unit check on <compiler>`, `crashes the unit check on <compiler>` |
	## | 2 | The header of `n` names a platform URL that is not the chosen URL of the platform slot (R-C3). `n` is a package. | `needs <alias of the platform slot> <version of the platform that it names>` |
	## | 3 | The header of `n` has a dep in the group of another slot, with a version above the chosen version of that slot (R-C2). The first such dep, in the order of the header, then of the slots. | `needs <alias of that slot> >= <dep version>` |
	## | 4 | `n` is a platform, and the header of a chosen package names another platform URL (R-C3). The first such slot. | `<alias of that slot> <its chosen version> needs <alias of n> <version of the platform that it names>` |
	## | 5 | None of these | `it does not fit the closure of the tuple` |
	##
	## A release with no header fact skips the reasons 2 and 3.
	of : Input -> List(Lags.Lag)
	of = |_x| crash "todo"

	## The text of a lag, for the line `note: <text>` (a proposal, TW24): `<alias> <newest> is not used, <got> is chosen: <why>`.
	note : Lags.Lag -> Str
	note = |_x| crash "todo"

	## R-UP5: the keys of `talon.toml` that move with a version. A move is a use of a moved variable (`file` is the member file, `alias` its header alias, `version` the new version). For each move whose member has the key `alias` in `[dependencies]`:
	## `Ranges.rewrite` of its range. A key that is not there gets no pair (Talon adds no key and does not create the file). A range that admits the version, and a range with no form (`Err(NoForm)`), get no pair (the second gets a note: `Lags.stuck`).
	## The value keeps the name of a value in the form `<name>@<range>` (R-I2). A key of `[overrides]` is not read (question Q3). One pair for each (file, key), in the order of the moves.
	rewrites : { members : List(Vars.Member), moves : List({ file : Str, alias : Str, version : Str }) } -> List({ path : Str, key : Str, value : Str })
	rewrites = |_x| crash "todo"

	## Q1 (b) of slice 038: the notes for the keys that stay. A key of `[dependencies]` of a moved alias whose range has no form (`Ranges.rewrite` is `Err(NoForm)`) and does not admit the new version.
	## The text (TW24): `talon.toml: <key>: the range does not admit <version>, change it by hand`. One note for each (file, key), in the order of the moves. A key that is not there, and a range that admits the version, give no note.
	stuck : { members : List(Vars.Member), moves : List({ file : Str, alias : Str, version : Str }) } -> List(Str)
	stuck = |_x| crash "todo"

	## Q6 (a) of slice 038: the value that a key of `[dependencies]` has now, in the form of `Lags.rewrites` (`<name>@<range>` or `<range>`), for `(was "<old>")` on the line of the key. `Err(None)` when the file has no such key.
	was : { members : List(Vars.Member), path : Str, key : Str } -> Try(Str, [None])
	was = |_x| crash "todo"
}

Input : {
	slots : List(Pick.Slot),
	chosen : List(Pick.Chosen),
	facts : List({ url : Str, release : Release }),
	now : U64,
	min_age : U64,
	snapshot : Try(U64, [None]),
	compiler : Try(Str, [None]),
	checks : List(Db.Fact),
	used : List({ id : Str, modules : List(Str) }),
}
