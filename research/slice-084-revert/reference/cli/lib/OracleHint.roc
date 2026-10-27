import Ident
import OracleBase
import OracleRequest
import OracleSearch
import Pick

## The hint of the oracle step (slice 039s: split from `Oracle`, R-RP2, rules below). Pure.
OracleHint :: [].{

	## Slice 036c (R-RP2): the oldest nightly that works. `compat.domain` is `Ok(D)` and `compat.compiler` is H. The answer is the id of the first compiler of D (oldest first) other than H on which the same step, with that compiler held,
	## is `Done` with real facts only (rule 1), and `Err(None)` when no compiler is. It is the nightly that `tln roc use <id>` can name: on it the command would end with a tuple, by the facts that the command has.
	##
	## | # | Rule | Source |
	## | --- | --- | --- |
	## | 1 | The step on a compiler `n` is `step_probed` with `compiler: Ok(n)`, `probes: Allowed`, `inferred: []`, `conflicts: []` and the same `checks`, `used` and `domain`. Only `Done` counts: `Pairs`, `Scan`, `Fail` and `Wide` do not, and a `Need` does not (but see the header rule below). So a tuple that has a pair with no real fact on `n` does not make `n` the answer (R-EP8: an inferred fact never decides). A `Need` for a header that the command has not read is no fact about `n`: the header is taken as fit (an empty fact, D3) and the step runs again | R-EP8, R-RP2 |
	## | 2 | The header value has no assumed pass on `n` (D2 of slice 036b holds for H only): its pair on `n` needs a real row | D2 revisit |
	## | 3 | `n` is any compiler of D other than H, older or newer than H. The first in the order of D is the answer | R-RP2 "the oldest nightly" |
	## | 4 | `Err(None)` when `compat.compiler` is `Err(None)`, when `compat.domain` is `Err(NotRead)`, and when H is not in D | R-EP11 |
	hint : OracleBase.Input, OracleBase.Compat -> Try(Str, [None])
	hint = |input, compat| match (compat.compiler, compat.domain) {
		(Ok(held), Ok(d)) if d.contains(held) => d.keep_if(|n| n != held).find_first(|n| works_on(input, compat, n)).map_err(|_| None)
		_ => Err(None)
	}

	# R-RP2 rule 1: the same step on the compiler `n`, with real facts only.
	works_on : OracleBase.Input, OracleBase.Compat, Str -> Bool
	works_on = |input, compat, n| settled(input, { ..compat, compiler: Ok(n), probes: Allowed, inferred: [], conflicts: [] }, 3)

	# The step of `hint` runs on another compiler with `assume` off (D2, no explanation: `OracleCause.failure` would call `hint`, so the search gets a hint that is never called).
	step_hint : OracleBase.Input, OracleBase.Compat -> OracleBase.Free
	step_hint = |input, compat| match Pick.empty_domain(input) {
		Ok(fail) => Fail(fail)
		Err(NoFailure) => OracleSearch.search(input, compat, Bool.False, OracleRequest.request_of(input, compat, Bool.False, Err(Held)), OracleRequest.movable_of(input), [], |_, _| Err(None))
	}

	# A `Need` is no fact about the compiler: the release is taken as fit (an empty fact, D3) and the step runs again, `rounds` times at most.
	settled : OracleBase.Input, OracleBase.Compat, U64 -> Bool
	settled = |input, compat, rounds| match step_hint(input, compat) {
		Done(_) => Bool.True
		Need(ids) => rounds > 0 and settled(with_empty(input, ids), compat, rounds - 1)
		_ => Bool.False
	}

	with_empty : OracleBase.Input, List(Str) -> OracleBase.Input
	with_empty = |input, ids| {
		urls = ids.keep_if(|id| Ident.of_url(id).is_ok())
		facts = urls.map(|url| { url, release: { kind: if OracleBase.platform_of(input, url) Platform else Package, pf: Err(None), deps: [] } })
		paths = ids.keep_if(|id| Ident.of_url(id).is_err()).map(|id| { id, entries: [] })
		{ ..input, facts: input.facts.concat(facts), paths: input.paths.concat(paths) }
	}
}
