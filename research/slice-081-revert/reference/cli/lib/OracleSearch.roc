import Pick
import OracleBase
import OracleCause
import OracleDomain
import OracleRequest
import resolve.Solver

## The search of the oracle step (slice 039s: split from `Oracle`): the solver, the closure walk of a tuple, the pairs to probe, the lookups of `Off` and the scan (R-AL4, R-AL8, R-AL9, R-EP8, R-LF2, R-UM1). Pure.
OracleSearch :: [].{

	# D3: a release with no fact has an empty fact of the kind of its slot, so the tuple is the optimistic one and the closure walk can ask for the nodes below it.
	optimistic : Solver.Request, Solver.Ask -> Try(Solver.Fact, [NoHeader])
	optimistic = |req, ask| match ask {
		Header(id) => {
			holds = |slot| slot.candidates.any(|c| c.id == id) or (
				match slot.current {
					Ok(c) => c.id == id
					Err(_) => Bool.False
				}
			)
			kind = match req.slots.find_first(holds) {
				Ok(slot) => if slot.kind == Platform Platform else Package
				Err(_) => Package
			}
			Ok({ id, kind, pf: Err(None), deps: [] })
		}
		Probe(_) => Err(NoHeader)
	}

	is_header : Solver.Ask -> Bool
	is_header = |ask| match ask {
		Header(_) => Bool.True
		Probe(_) => Bool.False
	}

	# R-AL4: the pairs that the solver asks for, in its order.
	pairs_of : OracleBase.Input, List(Solver.Ask) -> List(OracleBase.Pair)
	pairs_of = |input, asks| asks.keep_oks(
		|ask| match ask {
			Probe(p) => Ok({ id: p.id, nightly: p.nightly, is_platform: OracleBase.platform_of(input, p.id) })
			Header(_) => Err(NoPair)
		},
	)

	# R-AL9, R-EP8: a problem of the closure is a conflict of the whole tuple (034 Q3), and the solver gives the next tuple. `tried` are those conflicts. The facts of the releases that the solver asked for stay in `req`: they are optimistic (D3).
	# `hint_of` is `OracleHint.hint`: a function, so that this module does not import `OracleHint` (no cycle). It runs only for a failure with a probe cause and `assume` on.
	search : OracleBase.Input, OracleBase.Compat, Bool, Solver.Request, List(Str), List(List(Solver.Term)), (OracleBase.Input, OracleBase.Compat -> Try(Str, [None])) -> OracleBase.Free
	search = |input, compat, assume, req, movable, tried, hint_of| match Solver.step_moves({ ..req, conflicts: req.conflicts.concat(tried) }, movable) {
		Fail(why) => if wants_domain(compat) and has_probe(why) Wide else Fail(OracleCause.failure(input, compat, assume, why, if assume and has_probe(why) hint_of(input, compat) else Err(None)))
		Need(asks) => if asks.any(is_header) {
			search(input, compat, assume, { ..req, facts: req.facts.concat(asks.keep_oks(|ask| optimistic(req, ask))) }, movable, tried, hint_of)
		} else {
			fetch_first(input, pairs_of(input, asks))
		}
		Done(chosen) => walked(input, compat, assume, { req, movable, tried, hint_of, nightly: chosen.find_first(|c| c.name == OracleRequest.roc_name).map_ok(|c| c.id).map_err(|_| None) }, chosen.keep_if(|c| c.name != OracleRequest.roc_name))
	}

	# R-AL8, R-AL4: the release of a pair needs its package in the cache before its probe runs (a unit probe runs in the package dir), and the header of the package is a fact of the pick. So the header of each pair release that the command has not read is a `Need`. Then the pairs.
	fetch_first : OracleBase.Input, List(OracleBase.Pair) -> OracleBase.Free
	fetch_first = |input, pairs| match pairs.keep_if(|pair| !input.facts.any(|f| f.url == pair.id)).map(|pair| pair.id) {
		[] => Pairs(pairs)
		ids => Need(ids)
	}

	# The closure walk of a tuple (R-AL9), then the lookups of `Off` (R-LF2).
	walked : OracleBase.Input, OracleBase.Compat, Bool, { req : Solver.Request, movable : List(Str), tried : List(List(Solver.Term)), hint_of : (OracleBase.Input, OracleBase.Compat -> Try(Str, [None])), nightly : Try(Str, [None]) }, List(Solver.Chosen) -> OracleBase.Free
	walked = |input, compat, assume, run, chosen| {
		on = { ..compat, compiler: run.nightly }
		verdict = Pick.closure_verdict({
			members: if input.unmanaged.is_empty() [{ file: "", entries: [] }] else input.unmanaged,
			nodes: input.facts.map(|f| Pick.node_of(f)).concat(input.paths),
			picked: input.slots.map2(chosen, |slot, c| { files: slot.files, is_platform: slot.is_platform, url: c.id }),
		})
		match verdict {
			Problem => search(input, compat, assume, run.req, run.movable, run.tried.append(chosen.map(|c| { name: c.name, ids: [c.id], sign: In })), run.hint_of)
			Fine([]) => match lookups(input, on, chosen) {
				[] => scanned(input, on, chosen)
				pairs => if wants_domain(compat) Wide else Pairs(pairs)
			}
			Fine(ids) => Need(ids)
		}
	}

	# R-UM1, R-AL5 (036 Q3): a chosen release with a fail in a module (not `main.roc`, the solver drops that one) and no scan result needs a scan. Else the tuple is done.
	scanned : OracleBase.Input, OracleBase.Compat, List(Solver.Chosen) -> OracleBase.Free
	scanned = |input, compat, chosen| {
		picked = input.slots.map2(chosen, |slot, c| chosen_of(input, slot, c))
		ids = match compat.compiler {
			Ok(nightly) => chosen
				.map(|c| c.id)
				.fold([], |found, id| if found.contains(id) found else found.append(id))
				.keep_if(|id| needs_scan(compat, nightly, id))
			Err(None) => []
		}
		if ids.is_empty() Done({ chosen: picked, nightly: compat.compiler }) else Scan({ ids, chosen: picked })
	}

	needs_scan : OracleBase.Compat, Str, Str -> Bool
	needs_scan = |compat, nightly, id| match OracleDomain.row_of(compat.checks, nightly, id) {
		Ok(f) => f.outcome == Fail and !f.modules.is_empty() and !f.modules.contains("main.roc") and !compat.used.any(|u| u.id == id)
		Err(_) => Bool.False
	}

	# R-LF2, R-EP9: with `Off` the step cannot ask for a probe. A chosen release that changes, has no row and was not looked up is a pair for the command to look up in the db. No compiler, no lookup (R-SO22).
	lookups : OracleBase.Input, OracleBase.Compat, List(Solver.Chosen) -> List(OracleBase.Pair)
	lookups = |input, compat, chosen| match (compat.compiler, compat.probes) {
		(Ok(nightly), Off) => {
			wanted = input.slots.map2(chosen, |slot, c| (slot, c.id)).keep_if(
				|(slot, url)| !OracleBase.is_current(slot, url) and OracleDomain.row_of(compat.checks, nightly, url).is_err() and !compat.looked.any(|k| k.hash == OracleDomain.hash_of(url) and k.nightly == nightly and k.target == "any"),
			)
			wanted
				.fold([], |found, (_, url)| if found.contains(url) found else found.append(url))
				.map(|url| { id: url, nightly, is_platform: OracleBase.platform_of(input, url) })
		}
		_ => []
	}

	# Slice 036c: the step asks for D (`Wide`) once, when it has a compiler and the command has not read the list.
	wants_domain : OracleBase.Compat -> Bool
	wants_domain = |compat| compat.compiler.is_ok() and (
		match compat.domain {
			Err(NotRead) => Bool.True
			Ok(_) => Bool.False
		}
	)

	has_probe : Solver.Why -> Bool
	has_probe = |why| why.steps.any(
		|step| match step.cause {
			Probe(_) => Bool.True
			_ => Bool.False
		},
	)

	chosen_of : OracleBase.Input, Pick.Slot, Solver.Chosen -> Pick.Chosen
	chosen_of = |input, slot, c| Pick.chosen_for({ slot, url: c.id, version: c.version, published_at: slot.candidates.find_first(|x| x.url == c.id).map_ok(|x| x.published_at) ?? 0, now: input.now, min_age: input.min_age })
}
