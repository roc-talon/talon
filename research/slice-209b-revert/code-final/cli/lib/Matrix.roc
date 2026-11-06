import records.Closure as Wire
import Db
import Epochs
import Nightlies
import PinOrder
import Ident
import resolve.Solver

## The registry evidence of a closure answer (slice 209; Resolution 3 R-EF1 ranks 2 and 6, R-EF3; Resolution 4 R-EP2, R-EP3, R-EP4, R-EP6, R-EP15; Registry 4.1 R-AP17, R-AP19, R-AP58; Resolution 4 R-SM6; Design R-SE5). Part A (pure).
## `Matrix` (R-EP15) is the registry data that the epochs read: the `epochs` of the closure answer. The `runs` and `nearest` of the answer are the rank 2 facts (R-EP12). The `hints` are rank 6: they only order the search (R-SE5), they are never a fact.
##
## | Part | Value | Rule |
## | --- | --- | --- |
## | D | The compilers of the command, in R-NS1 order (`Nightlies.order`), as `Epochs` reads them | R-EP11 |
## | A compiler tag of the answer in D | The release of D that is `PinOrder.same_id` with it (R-CV1) | R-CV1 |
## | An interval `[from, to]` of the answer (a run, an epoch) | Each release `c` of D with `from` <= `c` <= `to` in R-NS1 order (`PinOrder.order_of` with the `published_at` of D). An end that D does not have (a hidden compiler, R-AP19) is placed by that order too, so the interval holds only the compilers that the client knows | R-AP17, R-AP19 |
## | `error_digest` | `Err(None)` for `null`, `Ok("")` for an empty text: 2 different digests (R-AP58) | R-AP58 |
##
## Design Q393 (Resolution R-EF3): a rank 2 `fail` has an unknown set of failing modules (the wire has only an `error_digest`). An unknown set touches each module that the app uses, and such a fail does not decide alone, as an inferred fact (R-EP8): `unknown_sets` marks its check. The tests do not read `modules` of a registry fact in `real`.
Matrix :: [].{

	## One registry row on one compiler, before the precedence of R-EF3. `nightly` is the compiler: a release id of D for a run, the tag of the answer for a `nearest` row.
	Row : { hash : Str, nightly : Str, target : Str, source : [Bot, Author], result : [Pass, Fail, Hang, Crash], error_digest : Try(Str, [None]) }

	## The rank 6 hint of one pair (R-EF3): `Pass` when `pass_count` > `fail_count` + `crash_count`, `Fail` when `fail_count` + `crash_count` > `pass_count`. The counts as the answer has them.
	Shared : { result : [Pass, Fail], pass_count : U64, fail_count : U64, crash_count : U64 }

	## R-AP17, R-AP19, R-AP58, R-SM6: the rows of `runs` and `nearest`.
	##
	## | # | Rule |
	## | --- | --- |
	## | 1 | A run gives one row for each release of D in its interval, in the order of D, with the `id` of the release of D as `nightly`. A run with no release of D in it gives none |
	## | 2 | A `nearest` row gives one row, with its `nightly` as the answer has it |
	## | 3 | The order: the runs in the order of the answer, then the `nearest` rows in the order of the answer |
	## | 4 | `hash`, `target`, `source`, `result` and `error_digest` are those of the item. Each target (a smoke row of a host target too, R-SM6) |
	rows : { runs : List(Wire.Run), nearest : List(Wire.Nearest), domain : List(Nightlies.Release) } -> List(Matrix.Row)
	rows = |run| {
		times = run.domain.map(|r| { id: r.id, published_at: r.published_at })
		inside = |r, from, to| PinOrder.order_of(from, r.id, times) != After and PinOrder.order_of(r.id, to, times) != After
		of_run = |x| run.domain
			.keep_if(|r| inside(r, x.from, x.to))
			.map(|r| { hash: x.hash, nightly: r.id, target: x.target, source: x.source, result: x.result, error_digest: x.error_digest })
		near = run.nearest.map(|x| { hash: x.hash, nightly: x.nightly, target: x.target, source: x.source, result: x.result, error_digest: x.error_digest })
		run.runs.join_map(of_run).concat(near)
	}

	## R-EF1, R-EF3, R-EP12: the real facts of rank 1 and rank 2 of the command.
	##
	## | # | Rule |
	## | --- | --- |
	## | 1 | Each row of `local` (rank 1, `compat.db`) as it is, first, in its order |
	## | 2 | Then one fact for each key (`hash`, `nightly`, `target`) of `rows` that `local` does not have (a rank 1 row wins over rank 2: the `nightly` of a key is compared with `PinOrder.same_id`, so the 2 tag forms of one release are one key, R-CV1), in the order of the first row of the key |
	## | 3 | For a key with a `bot` row and an `author` row: the `bot` row (R-EF3), also when the `author` row comes first |
	## | 4 | The fact: `outcome` is the `result`, `closure` is `""`. `modules` are not fixed by the tests: the oracle reads the set of a rank 2 `fail` through `unknown_sets` (Q393) |
	real : { local : List(Db.Fact), rows : List(Matrix.Row) } -> List(Db.Fact)
	real = |x| {
		same = |a, b| a.hash == b.hash and a.target == b.target and PinOrder.same_id(a.nightly, b.nightly)
		fresh = x.rows.keep_if(|r| !x.local.any(|f| same(f, r)))
		keys = fresh.fold([], |found, r| if found.any(|k| same(k, r)) found else found.append(r))
		reg = keys.map(
			|k| {
				pick = winner(fresh.keep_if(|r| same(r, k))) ?? k
				{ hash: pick.hash, nightly: pick.nightly, target: pick.target, outcome: pick.result, modules: [], closure: "" }
			},
		)
		x.local.concat(reg)
	}

	## R-EP2, R-EP3, R-EP4, R-EP13, R-EP15: the epochs of D with the matrix, a partition of D in the order of D.
	##
	## | # | Rule |
	## | --- | --- |
	## | 1 | Only the epochs of the answer with the target `any` (R-MX4: epochs use unit checks only) |
	## | 2 | An epoch of the answer holds the releases of D in its interval. Each transition in it is covered and not a boundary of case (a) of R-EP3 (R-EP2) |
	## | 3 | Case (b) of R-EP3, only inside an epoch of the answer: the transition (r0, r1) of 2 adjacent releases of D is a boundary when 2 or more hashes have a code result (`Pass` or `Fail`, R-EP1) on both in `facts` (target `any`) and the 2 results of the hash are different. A fault is not compared (R-EP5). A boundary splits the epoch |
	## | 4 | A transition between 2 epochs of the answer is a boundary or not covered: 2 epochs are never joined (R-EP3) |
	## | 5 | A release of D that no epoch of the answer holds is an epoch of its own (R-EP4) |
	## | 6 | No epoch of the answer (no registry): `Epochs.partition` (R-EP15) |
	intervals : { domain : List(Nightlies.Release), epochs : List(Wire.Epoch), facts : List(Db.Fact) } -> List(Epochs.Interval)
	intervals = |x| {
		times = x.domain.map(|r| { id: r.id, published_at: r.published_at })
		spans = x.epochs.keep_if(|e| e.target == "any")
		ids = x.domain.map(|r| r.id)
		inside = |id, e| PinOrder.order_of(e.from, id, times) != After and PinOrder.order_of(id, e.to, times) != After
		group = |p, id| match spans.find_first_index(|e| inside(id, e)) {
			Ok(g) => Epoch(g)
			Err(_) => Own(p)
		}
		units = x.facts.keep_if(|f| f.target == "any")
		hashes = units.fold([], |found, f| if found.contains(f.hash) found else found.append(f.hash))
		code = |hash, id| match units.find_first(|f| f.hash == hash and f.nightly == id) {
			Ok(f) if f.outcome == Pass or f.outcome == Fail => Ok(f.outcome)
			_ => Err(NoCode)
		}
		changed = |a, b| hashes.keep_if(
			|h| match (code(h, a), code(h, b)) {
				(Ok(ra), Ok(rb)) => ra != rb
				_ => Bool.False
			},
		).len()
		joins = |cur, id, g| cur.group == g and (
			match g {
				Epoch(_) => changed(cur.to, id) < 2
				Own(_) => Bool.False
			}
		)
		end = ids.map_with_index(|id, p| (id, group(p, id))).fold(
			{ done: [], open: Err(None) },
			|acc, (id, g)| match acc.open {
				Ok(cur) => if joins(cur, id, g) {
					{ done: acc.done, open: Ok({ from: cur.from, to: id, group: g }) }
				} else {
					{ done: acc.done.append({ from: cur.from, to: cur.to }), open: Ok({ from: id, to: id, group: g }) }
				}
				Err(None) => { done: acc.done, open: Ok({ from: id, to: id, group: g }) }
			},
		)
		close(end)
	}

	## R-EP10 with the matrix (R-EP15): `intervals`, and `Epochs.infer` with them. With no epoch of the answer it is `Epochs.epochs(domain, facts)`.
	found : { domain : List(Nightlies.Release), epochs : List(Wire.Epoch), facts : List(Db.Fact) } -> Epochs.Found
	found = |x| {
		parts = Matrix.intervals(x)
		{ epochs: parts, inferred: Epochs.infer({ domain: x.domain, epochs: parts, facts: x.facts }) }
	}

	## R-EF1 rank 6, R-EF3, R-SE5: the hint of a pair from the `hints` of the answer: the first row with the `hash`, the `target` and a `nightly` that is `PinOrder.same_id` with the given one. Equal counts, or no row: `Err(None)`.
	shared : { hints : List(Wire.Hint), hash : Str, nightly : Str, target : Str } -> Try(Matrix.Shared, [None])
	shared = |x| match x.hints.find_first(|h| h.hash == x.hash and h.target == x.target and PinOrder.same_id(h.nightly, x.nightly)) {
		Ok(h) => {
			bad = h.fail_count + h.crash_count
			counts = { pass_count: h.pass_count, fail_count: h.fail_count, crash_count: h.crash_count }
			if h.pass_count > bad {
				Ok({ result: Pass, pass_count: counts.pass_count, fail_count: counts.fail_count, crash_count: counts.crash_count })
			} else if bad > h.pass_count {
				Ok({ result: Fail, pass_count: counts.pass_count, fail_count: counts.fail_count, crash_count: counts.crash_count })
			} else {
				Err(None)
			}
		}
		Err(_) => Err(None)
	}

	## Design Q393, Resolution R-EF3, R-EP8, R-UM1, R-EP7: the checks of the oracle (`OracleDomain.checks`) with the rank 2 `fail`s marked. A check whose key (the hash of its release URL `id`, `nightly` by `PinOrder.same_id` (R-CV1), the target `any`) has no row in `local` (rank 1), and whose fact of
	## rank 2 (after the precedence of `real`: a `bot` row wins) is a `fail` of `rows`, becomes `source: Inferred` with `modules: []` (an unknown set: it touches each used module, and it never decides alone, so the step asks for the local unit probe).
	## Every other check stays as it is: a rank 2 `pass`, a rank 2 `hang` or `crash`, a rank 1 row, an inferred fact, the assumed pass. The order of the checks stays.
	unknown_sets : { checks : List(Solver.Check), local : List(Db.Fact), rows : List(Matrix.Row) } -> List(Solver.Check)
	unknown_sets = |x| x.checks.map(
		|c| match (c.source, Ident.of_url(c.id)) {
			(Real, Ok(ident)) => {
				hash = ident.hash
				ranked = x.local.any(|f| f.hash == hash and f.target == "any" and PinOrder.same_id(f.nightly, c.nightly))
				reg = winner(x.rows.keep_if(|r| r.hash == hash and r.target == "any" and PinOrder.same_id(r.nightly, c.nightly)))
				match reg {
					Ok(r) if !ranked and r.result == Fail => { id: c.id, nightly: c.nightly, outcome: c.outcome, modules: [], source: Inferred }
					_ => c
				}
			}
			_ => c
		},
	)

	## Slice 209b (R-SM6, R-EF3, Q558): the `bot` smoke `fail` or `crash` of the key (platform `hash`, `nightly`, real `target`) in `rows`, for ladder step 3.
	## The first row of the key (the `nightly` by `PinOrder.same_id`, R-CV1; the `target` must be equal, so a unit row of the target `any` is no smoke row) after the precedence of R-EF3 (a `bot` row wins over an `author` row): `Ok(row)` when it is a `bot` row with the result `Fail` or `Crash` (a `crash` is a fail with the interval [r, r] of a fault).
	## `Err(None)`: no row, an `author` row only, a `Pass`, a `Hang` (it can come from a slow machine: step 3 builds), another hash, nightly or target.
	smoke_fail : { rows : List(Matrix.Row), hash : Str, nightly : Str, target : Str } -> Try(Matrix.Row, [None])
	smoke_fail = |x| {
		of_key = x.rows.keep_if(|r| r.hash == x.hash and r.target == x.target and PinOrder.same_id(r.nightly, x.nightly))
		match winner(of_key) {
			Ok(r) if r.source == Bot and (r.result == Fail or r.result == Crash) => Ok(r)
			_ => Err(None)
		}
	}

	## Slice 209b (R-SM6, R-EP7, Design Q557, Q558): the checks that step 3 gives to the next search after it dropped the tuple for a smoke fail. For each compiler of `rows` (the first row of each compiler by `PinOrder.same_id`, in the order of `rows`) that has a `bot` smoke row of (`hash`, `target`)
	## after R-EF3 with the result `Fail` or `Crash` (the rule of `smoke_fail`): one check `{ id, nightly: the nightly of that row, outcome: Fail or Crash, modules: [], source: Real }`. `id` is the release URL of the platform. A real fail with no module touches each module (R-UM1) and decides alone, so R-EP7 learns the interval; a crash is a fault ([r, r]).
	## A compiler whose row is a `pass`, a `hang` or an `author` row only, a row of another hash or target, and the unit target `any` give no check.
	smoke_checks : { rows : List(Matrix.Row), id : Str, hash : Str, target : Str } -> List(Solver.Check)
	smoke_checks = |x| {
		of_key = x.rows.keep_if(|r| r.hash == x.hash and r.target == x.target)
		firsts = of_key.fold([], |seen, r| if seen.any(|k| PinOrder.same_id(k.nightly, r.nightly)) seen else seen.append(r))
		firsts.keep_oks(
			|k| match Matrix.smoke_fail({ rows: of_key, hash: x.hash, nightly: k.nightly, target: x.target }) {
				Ok(r) => Ok({ id: x.id, nightly: r.nightly, outcome: if r.result == Crash Crash else Fail, modules: [], source: Real })
				Err(_) => Err(None)
			},
		)
	}

	## Slice 206e3b (R-EF1 rank 2, R-EF3, R-EP12, Q393): the rank 2 facts of the `keys` from the `runs` and `nearest` of an answer on `domain` (`Matrix.rows`), for the keys that `local` (rank 1) does not have (`Matrix.real`: rank 1 wins, a `bot` row wins).
	## `facts` are the rank 2 facts that are no `fail`: they are real checks. A rank 2 `fail` has an unknown set of modules (Q393): it is no check row, but an inferred fact with no module (`unknown`), so it never decides alone (R-EP8) and the pair is probed. `fails` are the rank 2 `fail` facts for the epochs (R-EP6).
	rank2 : { answer : Wire.Answer, domain : List(Nightlies.Release), local : List(Db.Fact), keys : List(Db.Key) } -> { facts : List(Db.Fact), fails : List(Db.Fact), unknown : List(Epochs.Inferred) }
	rank2 = |x| {
		wanted = |r| x.keys.any(|k| k.hash == r.hash and k.target == r.target and PinOrder.same_id(k.nightly, r.nightly))
		from_answer = Matrix.rows({ runs: x.answer.runs, nearest: x.answer.nearest, domain: x.domain }).keep_if(wanted)
		reg = Matrix.real({ local: x.local, rows: from_answer }).drop_first(x.local.len())
		fails = reg.keep_if(|f| f.outcome == Fail)
		{ facts: reg.keep_if(|f| f.outcome != Fail), fails, unknown: fails.map(|f| { hash: f.hash, nightly: f.nightly, outcome: Fail, modules: [], from: [] }) }
	}
}

# R-EF3: the row that wins among the rows of one key: the first `bot` row, else the first row.
winner : List(Matrix.Row) -> Try(Matrix.Row, [None])
winner = |rows| match rows.find_first(|r| r.source == Bot) {
	Ok(r) => Ok(r)
	Err(_) => rows.first().map_err(|_| None)
}

# The intervals of `Matrix.intervals`: the closed ones and the open one.
close : { done : List({ from : Str, to : Str }), open : Try({ from : Str, to : Str, group : [Epoch(U64), Own(U64)] }, [None]) } -> List({ from : Str, to : Str })
close = |acc| match acc.open {
	Ok(cur) => acc.done.append({ from: cur.from, to: cur.to })
	Err(None) => acc.done
}
