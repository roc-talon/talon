import Consent
import Fail
import Fx
import OracleBase
import Probe
import ResolveBase
import RocInstall

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
	step! = |fx, request, round, state| {
		wanted = round.pairs.map(|p| p.nightly).keep_if(|id| state.open.contains(id)).fold([], |found, id| if found.contains(id) found else found.append(id))
		if wanted.is_empty() return Ok({ state, pairs: round.pairs })
		cap = round.settings.max_toolchains
		left = if cap > state.tried cap - state.tried else 0
		plan = Consent.optional_round({ ids: wanted, installed: [], left, sizes: round.sizes })
		# R-LF4: a dry run answers No, so the opt-in is ignored.
		want = Consent.optional_want({ count: plan.fetch.len(), mode: request.prompt.mode, yes: !request.dry_run and request.prompt.yes, flag: if request.dry_run Err(NoFlag) else request.downloads.probe })
		match want {
			Nothing => Ok(left_out(round, state, { gone: state.open, dropped: state.dropped + plan.dropped.len() }))
			Skip => {
				every = Consent.optional_round({ ids: state.open, installed: [], left, sizes: round.sizes })
				fx.err!("${Consent.optional_skipped({ count: every.fetch.len(), size: every.size })}\n")
				Ok(left_out(round, state, { gone: state.open, dropped: state.dropped }))
			}
			Download => {
				got = fetch!(fx, request, plan.fetch, state)
				open = state.open.keep_if(|id| !plan.fetch.any(|f| f.id == id) and !plan.dropped.contains(id))
				next = { open, got: got.have, tried: got.tried, downloads: got.downloads, dropped: state.dropped + plan.dropped.len() }
				Ok({ state: next, pairs: round.pairs.keep_if(|p| !got.failed.contains(p.nightly) and !plan.dropped.contains(p.nightly)) })
			}
		}
	}
}

# The compilers of `gone` leave the search, and so do the pairs on them.
left_out : PickOptional.Round, PickOptional.State, { gone : List(Str), dropped : U64 } -> PickOptional.Stepped
left_out = |round, state, out| {
	state: { ..state, open: state.open.keep_if(|id| !out.gone.contains(id)), dropped: out.dropped },
	pairs: round.pairs.keep_if(|p| !out.gone.contains(p.nightly)),
}

# R-NI4, R-DL5, R-DL6, R-P3: the downloads of one round, in order. A failure is a warning: the compiler has no fact and is not asked again. A failed try counts for the cap.
fetch! : Fx, ResolveBase.Request, List({ id : Str, size : U64 }), PickOptional.State => { have : List(Str), failed : List(Str), tried : U64, downloads : U64 }
fetch! = |fx, request, list, state| {
	var $have = state.got
	var $failed = []
	var $tried = state.tried
	var $downloads = state.downloads
	for item in list {
		match RocInstall.fetch_optional!(fx, { id: item.id, env: request.downloads.env, offline: request.offline }) {
			Ok(Present) => {
				$have = $have.append(item.id)
			}
			Ok(Installed) => {
				$have = $have.append(item.id)
				$tried = $tried + 1
				$downloads = $downloads + 1
			}
			Err(fail) => {
				fx.err!("${Consent.optional_failed({ id: item.id, text: fail.message })}\n")
				$failed = $failed.append(item.id)
				$tried = $tried + 1
			}
		}
	}
	{ have: $have, failed: $failed, tried: $tried, downloads: $downloads }
}
