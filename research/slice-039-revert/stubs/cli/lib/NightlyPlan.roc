import Nightlies
import Pin

## The free nightly of `tln upgrade` (slice 039, Resolution 9 and 10: R-SP8, R-SP9, R-SP12, R-SP13, R-UP1, R-UP6, R-UP12, R-UP13). Pure (TESTING.md 2.2, part A).
## `NightlyFlow` is the command code that uses it. This module is separate from `Upgrade` because `Upgrade` imports `Resolve`, which imports `PickFlow` (as `Lags`).
NightlyPlan :: [].{

	## R-SP6 to R-SP9, R-UP12, R-UP13: what the names of `tln upgrade` free. `names` are the operands as typed (slice 038 gives the failure for a selector first).
	##
	## | Names | `who` | `nightly` | Rule |
	## | --- | --- | --- | --- |
	## | none | `All` | `Free` | R-SP6, R-UP12 |
	## | only `roc` | `None` (all packages are held) | `Free` | R-SP8, R-UP13 |
	## | `X [Y...]` | `Named([X, Y...])` | `Held` | R-SP7, R-UP13 |
	## | `X [Y...] roc` | `Named([X, Y...])` (without `roc`) | `Free` | R-SP9, R-UP13 |
	##
	## The names keep their order. `roc` twice is `roc` once.
	scope : List(Str) -> { who : [All, Named(List(Str)), None], nightly : [Free, Held] }
	scope = |_names| crash "todo: slice 039"

	## R-UP6, R-SP12, R-UP1, R-C7, R-NS3, R-C9: the compilers of a free nightly. `releases` is the list of the host (`Nightlies.list!`), `req` and `nightly` are the range `[toolchain] roc` and the switch,
	## `min_age` and `snapshot` hide new compilers (R-C7). `held` is the compiler H that the header holds now (the pin, else the selected compiler). `installed` are the ids that can run now: the dirs of `<cache>/toolchains`
	## and the id of the `roc` on `PATH`.
	##
	## | Field | Value |
	## | --- | --- |
	## | `newest` | The newest allowed compiler N (`Toolchain.range_pick`): the one download that the command names (R-UP6). `Err(NoneKnown)` when none is allowed |
	## | `askable` | The compilers that the search may probe on: the allowed compilers that are not older than H (`Pin.order`) and are installed or are N, and H itself (R-C9: it stays in the domain). In the order of `releases` |
	## | `domain` | D: the ids of `releases` (the order of the list), for the checks and the inferred facts (R-EP11) |
	##
	## An installed compiler that is not allowed (too new for `min-release-age`, outside the range, the switch is off) is not askable: Talon selects it by itself here (R-NS3). A compiler older than H is not askable: `upgrade` moves up.
	pick : { releases : List(Nightlies.Release), req : Pin.Req, now : U64, min_age : U64, snapshot : Try(U64, [None]), nightly : Bool, held : Str, installed : List(Str) } -> { newest : Try(Str, [NoneKnown]), askable : List(Str), domain : List(Str) }
	pick = |_f| crash "todo: slice 039"

	## R-WS4, R-RP1 (slice 039, Q3 answer): members with different `roc:` pins. `Pin.decide` fails for them and its text names `tln upgrade roc` as the fix, so a free nightly accepts them. `members` are the rows that `Pin.decide` gets.
	## `differ` is true when `free` is true and 2 or more different pin texts are in the members. Then every member that has a pin gets the newest pin (`Pin.order`, no times: a tie of 2 nightlies of one day is the byte order of the text) in the rows,
	## so `Pin.decide` gives no failure and `held` (H) is the newest pin. Nobody moves down. With `differ` false the rows are the same.
	unify : { members : List({ file : Str, pin : Try(Str, [NoPin]), changes : Bool }), free : Bool } -> { members : List({ file : Str, pin : Try(Str, [NoPin]), changes : Bool }), differ : Bool }
	unify = |_f| crash "todo: slice 039"

	## R-RP1, R-SP12: the compiler that the command writes as the new pin, or `Err(Same)` when no pin changes. `free` is true when the nightly is free (`scope`), `held` is H, `nightly` is the compiler of the tuple (`Oracle.Free.Done`).
	## `unify` is `unify(...).differ`: the members have different pins, so the result is written to each member that does not have it, also when it is H.
	## A held nightly, a run with no compiler, and a tuple on H (the other tag form of H too, R-CV1: `Pin.same_id`) give `Err(Same)`, except with `unify`.
	moved_to : { free : Bool, unify : Bool, held : Try(Str, [NoCompiler]), nightly : Try(Str, [None]) } -> Try(Str, [Same])
	moved_to = |_f| crash "todo: slice 039"

	## R-RP1, R-RP3, R-OUT2 (TW24): the line of the pin edit of one member. `old` is its `roc:` entry text (`Err(NoPin)` for none). The new id `id` is the new pin:
	## `~ roc: <old> -> <id>` for a member with a pin, `+ roc: <id>` for a member with no pin (the line of slice 013, R-RP3). `Err(Same)` when the member has the pin already (the same id or the other tag form of it): no edit.
	pin_line : { old : Try(Str, [NoPin]), id : Str } -> Try(Str, [Same])
	pin_line = |_f| crash "todo: slice 039"
}
