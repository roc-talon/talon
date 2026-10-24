import Fail
import Fx
import OracleBase
import Probe
import ResolveBase

## The optional compiler downloads of the oracle loop of a free nightly (slice 039b: R-NI4, R-DL1, R-DL2, R-DL4, R-DL5, R-DL6, R-UP6, R-P3, R-P5, R-LF4). Command code (TESTING.md 2.2, part C).
## The decisions are the pure `Consent.optional_*` functions of slice 037c. The fetch of one compiler is the one of `ProbeSearch` (`RocInstall.offer!`, the answer line, `RocInstall.install_offer!`): the code agent moves it into a shared function, so that
## `ProbeSearch` and this module do not each have a copy.
##
## The oracle loop (`PickLoop.run!`) asks the step for the compilers that the header may use: the installed ones, N, H (`NightlyPlan.pick`) and the optional ones that are still open (`NightlyPlan.optional`, `State.open`).
## A `Pairs` round that has a pair on an open compiler calls `step!` before the probes. `step!` runs after the budget check `Units.budget` of the round (R-P5: a download is for a probe that can start, so `Round.pairs` are the
## pairs that the budget lets start). The rows, in this order. `wanted` are the open compilers of `Round.pairs`, in the order of the pairs. `plan` is `Consent.optional_round` over `wanted` with `left` = `probe.max-toolchains` less `State.tried`.
##
## | # | Case | What `step!` does | Rule |
## | --- | --- | --- | --- |
## | 1 | `wanted` is empty | Nothing: `Stepped.pairs` are `Round.pairs`, `State` is the same | |
## | 2 | `Consent.optional_want` is `Nothing` (`plan.fetch` is empty: the cap is 0 or spent) | No line. All open compilers leave the search (`open` is empty). `dropped` grows by `plan.dropped.len()`. The pairs on a compiler that is not installed are not in `Stepped.pairs` | R-DL6 |
## | 3 | `Skip` (no opt-in) | One line on stderr: `Consent.optional_skipped` for ALL open compilers, with `Consent.optional_round` over `State.open` and the same `left` (count `fetch.len()`, size `size`). No prompt, no `tty!` call. All open compilers leave the search, so the line shows once for the run. The pairs on them are not in `Stepped.pairs` | R-DL4, R-NI4 |
## | 4 | `Download` (opt-in) | For each id of `plan.fetch` in order: `RocInstall.offer!`, `fx.err!` of `Consent.optional_line`, `RocInstall.install_offer!`. A failure (of the offer or of the install) is `fx.err!` of `Consent.optional_failed`: the compiler has no fact (R-P3), leaves the search, and counts for the cap. The ids of `plan.dropped` leave the search and grow `dropped`. A compiler that is installed after `offer!` (`Present`) is no download | R-NI4, R-DL6, R-P3 |
##
## The opt-in is `request.downloads.probe` (`--probe-downloads`) or `request.prompt.yes` (`--yes`). `--allow-downloads` and `TALON_AUTO_INSTALL` do not answer an optional download (R-DL5). `request.dry_run` answers No (R-LF4): the opt-in is ignored.
## `State.got` are the compilers that this command installed for the search (the loop adds them to the installed list of the probe rounds). `State.downloads` counts the compilers that were installed (`data.downloads`). `State.tried` counts the tries, also the failed ones.
PickOptional :: [].{

	## `open` are the optional compilers that the search may still ask (`NightlyPlan.optional.ids` at the start of the command). `got` are the compilers that this command installed. `tried`, `downloads` and `dropped` are the counts of the doc above.
	State : { open : List(Str), got : List(Str), tried : U64, downloads : U64, dropped : U64 }

	## `settings` has the cap `probe.max-toolchains`. `sizes` are `NightlyPlan.optional.sizes`. `pairs` are the pairs of the round that the budget lets start.
	Round : { settings : Probe.Settings, sizes : List({ id : Str, size : U64 }), pairs : List(OracleBase.Pair) }

	## `pairs` are the pairs to probe now (`Round.pairs` without the pairs on a compiler that left the search). `state` is the new state.
	Stepped : { state : PickOptional.State, pairs : List(OracleBase.Pair) }

	step! : Fx, ResolveBase.Request, PickOptional.Round, PickOptional.State => Try(PickOptional.Stepped, Fail)
	step! = |_fx, _request, _round, _state| crash "todo: slice 039b"
}
