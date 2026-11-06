import records.Closure as Wire
import Github
import Ident
import Matrix
import OracleBase
import Pin

## The order of the unit probes of one round of the oracle loop, when the budget cuts the round (slice 068b, R-AL4, R-DI8, R-EF1 rank 4, R-EF2, R-P5). Part A (pure).
## R-AL4 says that the unit probes of the pairs with no fact run in this order: "installed nightly first, then the strongest hint". `PickLoop.probe_round!` starts only the first `room` pairs of a round when `probe.max` is smaller than the
## round (R-P5, `Units.budget` with `cut`), so only then the order decides which pairs run. Only then the loop asks for hints (R-DI8: "only when the solver needs a hint for that candidate"). A round that the budget does not cut asks for no hint.
## Slice 068b uses the hint of rank 4 only (the `.roc-version` of the release tag). The ranks 3, 5 and 6 and the rule "installed nightly first" are question Q1 of the slice file.
PairOrder :: [].{

	## The release tags of the pairs that have a hint to ask for: the pairs whose release URL is a GitHub release URL (`Github.hint_ref`), each URL once, in the order of the pairs. A pair with another URL has no tag, so no hint.
	## `id` is the release URL of the pair (the key of `order`). `PickLoop.probe_round!` calls `Github.hint!` for each one (the code agent: it keeps the answer in the cache file, R-DI8).
	asks : List(OracleBase.Pair) -> List({ id : Str, owner : Str, repo : Str, tag : Str })
	asks = |pairs| pairs.fold(
		[],
		|found, pair| match Github.hint_ref(pair.id) {
			Ok(ref) => if found.any(|a| a.id == pair.id) found else found.append({ id: pair.id, owner: ref.owner, repo: ref.repo, tag: ref.tag })
			Err(NoRef) => found
		},
	)

	## R-AL4, R-EF1 rank 4: the pairs in the order of the probes. A pair has the hint when `hints` has its release URL (`id`) with `Ok(compiler)` and `Pin.same_id(compiler, pair.nightly)` (R-CV1: the 2 tag forms of a nightly are one compiler).
	## The pairs that have the hint come first, then the others. Each group keeps the order of `pairs` (the order of the solver). A release URL that `hints` does not have, or has with `Err(None)`, has no hint.
	order : { pairs : List(OracleBase.Pair), hints : List({ id : Str, hint : Try(Str, [None]) }) } -> List(OracleBase.Pair)
	order = |x| {
		named = |pair| x.hints.any(|h| h.id == pair.id and (h.hint.map_ok(|compiler| Pin.same_id(compiler, pair.nightly)) ?? Bool.False))
		x.pairs.keep_if(named).concat(x.pairs.keep_if(|pair| !named(pair)))
	}

	## Slice 209 (R-AL4, R-EF1 ranks 4 and 6, R-EF3, R-SE5): the order with the rank 6 hints of the closure answer (`hints` of R-AP17). The rank 6 hint of a pair is `Matrix.shared` for the hash of its release URL (`Ident.of_url`), its `nightly` and the target `any`.
	##
	## | Group | Pairs |
	## | --- | --- |
	## | 1 | The pairs that have the rank 4 hint (as `order`) |
	## | 2 | Then the other pairs that have a rank 6 `Pass` hint |
	## | 3 | Then the pairs with no hint (no row, equal counts, a URL with no hash) |
	## | 4 | Then the pairs with a rank 6 `Fail` hint (Design Q395, R-AL4: the probe is likely to fail, so the other probes come first) |
	##
	## Each group keeps the order of `pairs`. A pair with a rank 4 hint is in group 1 whatever its rank 6 hint is. A hint only orders: no pair is added or dropped (R-SE5, R-EF2).
	order_shared : { pairs : List(OracleBase.Pair), hints : List({ id : Str, hint : Try(Str, [None]) }), shared : List(Wire.Hint) } -> List(OracleBase.Pair)
	order_shared = |x| {
		named = |pair| x.hints.any(|h| h.id == pair.id and (h.hint.map_ok(|compiler| Pin.same_id(compiler, pair.nightly)) ?? Bool.False))
		six = |pair| match Ident.of_url(pair.id) {
			Ok(ident) => Matrix.shared({ hints: x.shared, hash: ident.hash, nightly: pair.nightly, target: "any" }).map_ok(|h| h.result) ?? None
			Err(_) => None
		}
		rest = x.pairs.keep_if(|pair| !named(pair))
		x.pairs.keep_if(named).concat(rest.keep_if(|pair| six(pair) == Pass)).concat(rest.keep_if(|pair| six(pair) == None)).concat(rest.keep_if(|pair| six(pair) == Fail))
	}
}
