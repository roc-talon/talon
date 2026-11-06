import lib.Epochs
import lib.Ident
import lib.Matrix
import lib.Fail
import lib.PairOrder
import lib.PickMoves

MatrixTest :: [].{}

# Slice 209 (docs/slices/209-registry-evidence.md). Pure: the `epochs`, `runs`, `nearest` and `hints` of the closure answer as evidence (R-EP15, R-EF1 ranks 2 and 6, R-EF3).

# D: 5 nightlies, oldest first (R-NS1). The days are 01, 03, 05, 07, 09: a hidden compiler of the registry (not in D, R-AP19) is the day 04.
c1 = "nightly-2026-10-01-aaaaaaa"

c2 = "nightly-2026-10-03-ccccccc"

c3 = "nightly-2026-10-05-eeeeeee"

c4 = "nightly-2026-10-07-0a0a0a0"

c5 = "nightly-2026-10-09-0b0b0b0"

hidden = "nightly-2026-10-04-ddddddd"

# The other tag form of `c2` (R-CV1).
c2_long = "nightly-2026-October-03-ccccccc"

day_s = 86400

rel = |id, day| { id, published_at: 1790812800 + day * day_s, asset: Err(NoAsset) }

domain = [rel(c1, 0), rel(c2, 2), rel(c3, 4), rel(c4, 6), rel(c5, 8)]

run = |hash, target, source, result, digest, from, to| { hash, target, source, result, error_digest: digest, from, to }

near = |hash, target, source, result, digest, nightly, side| { hash, target, source, result, error_digest: digest, nightly, side }

row = |hash, nightly, target, source, result, digest| { hash, nightly, target, source, result, error_digest: digest }

rows_of = |runs, nearest| Matrix.rows({ runs, nearest, domain })

# R-AP17 R-AP19 R-AP58 R-SM6 R-CV1 R-EP15: the rows of `runs` and `nearest`. A run gives a row on each release of D in its interval (the id of D). An end that D does not have (a hidden compiler) is placed by R-NS1, so the run holds only the
# compilers that the client knows. A `nearest` row gives one row with its own `nightly`. The order: the runs, then the `nearest` rows. `error_digest` null and an empty text stay 2 values. A smoke row of a host target is a row of that target.
expect {
	pass_run = |from, to| run("H1", "any", Bot, Pass, Err(None), from, to)
	pass_row = |nightly| row("H1", nightly, "any", Bot, Pass, Err(None))
	cases = [
		("no run, no nearest", rows_of([], []), []),
		("a run of 3 compilers of D", rows_of([pass_run(c2, c4)], []), [pass_row(c2), pass_row(c3), pass_row(c4)]),
		("a run of one compiler", rows_of([pass_run(c5, c5)], []), [pass_row(c5)]),
		("R-AP19: a run from a hidden compiler holds the compilers of D after it", rows_of([pass_run(hidden, c4)], []), [pass_row(c3), pass_row(c4)]),
		("R-AP19: a run to a hidden compiler holds the compilers of D before it", rows_of([pass_run(c1, hidden)], []), [pass_row(c1), pass_row(c2)]),
		("R-AP19: a run of a hidden compiler only gives no row", rows_of([pass_run(hidden, hidden)], []), []),
		("R-CV1: the other tag form of an end is that release of D", rows_of([pass_run(c2_long, c3)], []), [pass_row(c2), pass_row(c3)]),
		(
			"author run, a fail with a digest, an empty digest, a null digest (R-AP58)",
			rows_of([run("H2", "any", Author, Fail, Ok("d9"), c1, c1), run("H3", "any", Bot, Fail, Ok(""), c1, c1), run("H4", "any", Bot, Fail, Err(None), c1, c1)], []),
			[row("H2", c1, "any", Author, Fail, Ok("d9")), row("H3", c1, "any", Bot, Fail, Ok("")), row("H4", c1, "any", Bot, Fail, Err(None))],
		),
		("R-SM6: a bot smoke row of a host target", rows_of([run("PF", "x64musl", Bot, Fail, Ok("link"), c3, c3)], []), [row("PF", c3, "x64musl", Bot, Fail, Ok("link"))]),
		("a nearest row: its own nightly", rows_of([], [near("H1", "any", Bot, Fail, Ok("d1"), "nightly-2026-09-20-0c0c0c0", Before)]), [row("H1", "nightly-2026-09-20-0c0c0c0", "any", Bot, Fail, Ok("d1"))]),
		(
			"the runs in their order, then the nearest rows",
			rows_of([pass_run(c4, c4), run("H0", "any", Bot, Hang, Err(None), c1, c1)], [near("H1", "any", Author, Pass, Err(None), c5, After)]),
			[pass_row(c4), row("H0", c1, "any", Bot, Hang, Err(None)), row("H1", c5, "any", Author, Pass, Err(None))],
		),
	]
	bad = cases.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

lfact = |hash, nightly, target, outcome| { hash, nightly, target, outcome, modules: [], closure: "" }

# The fields that the tests fix (Q1: the modules of a registry fail are not decided).
key = |facts| facts.map(|f| (f.hash, f.nightly, f.target, f.outcome, f.closure))

# R-EF1 R-EF3 R-EP12: the real facts. Rank 1 rows first, as they are. Then one fact for each key of the registry rows that rank 1 does not have. A `bot` row wins over an `author` row of the key, also when the `author` row is first.
expect {
	real = |local, rows| key(Matrix.real({ local, rows }))
	cases = [
		("nothing", real([], []), []),
		("rank 1 only, as it is", real([lfact("H1", c1, "any", Fail)], []), [("H1", c1, "any", Fail, "")]),
		("a bot row", real([], [row("H1", c1, "any", Bot, Pass, Err(None))]), [("H1", c1, "any", Pass, "")]),
		("an author row with no bot row", real([], [row("H1", c1, "any", Author, Fail, Ok("d"))]), [("H1", c1, "any", Fail, "")]),
		("rank 1 wins over rank 2", real([lfact("H1", c1, "any", Pass)], [row("H1", c1, "any", Bot, Fail, Ok("d"))]), [("H1", c1, "any", Pass, "")]),
		(
			"R-EF3: the bot row wins, at the place of the first row of the key",
			real([], [row("H1", c1, "any", Author, Pass, Err(None)), row("H2", c1, "any", Bot, Pass, Err(None)), row("H1", c1, "any", Bot, Fail, Ok("d"))]),
			[("H1", c1, "any", Fail, ""), ("H2", c1, "any", Pass, "")],
		),
		("the bot row first, then the author row: the bot row", real([], [row("H1", c2, "any", Bot, Hang, Err(None)), row("H1", c2, "any", Author, Pass, Err(None))]), [("H1", c2, "any", Hang, "")]),
		(
			"R-SM6: another target is another key",
			real([lfact("PF", c3, "any", Pass)], [row("PF", c3, "x64musl", Bot, Fail, Ok("link")), row("PF", c3, "any", Bot, Fail, Ok("d"))]),
			[("PF", c3, "any", Pass, ""), ("PF", c3, "x64musl", Fail, "")],
		),
	]
	bad = cases.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

ep = |target, from, to| { target, from, to }

iv = |from, to| { from, to }

check = |hash, nightly, outcome| lfact(hash, nightly, "any", outcome)

# R-EP2 R-EP3 (a) and (b) R-EP4 R-EP5 R-EP13 R-EP15 R-AP19: the epochs of D with the epochs of the answer. Only the target `any`. An epoch of the answer holds the releases of D in its interval. Case (b) splits it only where 2 or more hashes
# have a code result on both releases and the 2 results differ. 2 epochs of the answer are never joined. A release that no epoch holds is an epoch of its own.
expect {
	ivs = |epochs, facts| Matrix.intervals({ domain, epochs, facts })
	own = [iv(c1, c1), iv(c2, c2), iv(c3, c3), iv(c4, c4), iv(c5, c5)]
	flip = |h| [check(h, c2, Pass), check(h, c3, Fail)]
	whole = [ep("any", c1, c5)]
	cases = [
		("R-EP15: no epoch of the answer is the partition of P1", ivs([], flip("H1").concat(flip("H2"))), Epochs.partition(domain)),
		("R-EP4: no epoch, each release its own", ivs([], []), own),
		("R-EP2: an epoch of the answer", ivs([ep("any", c2, c4)], []), [iv(c1, c1), iv(c2, c4), iv(c5, c5)]),
		("R-MX4: an epoch of another target is not read", ivs([ep("x64musl", c2, c4)], []), own),
		("R-EP3: 2 adjacent epochs of the answer are not joined", ivs([ep("any", c1, c2), ep("any", c3, c5)], []), [iv(c1, c2), iv(c3, c5)]),
		("R-AP19: an epoch from a hidden compiler holds the releases of D in it", ivs([ep("any", hidden, c5)], []), [iv(c1, c1), iv(c2, c2), iv(c3, c5)]),
		("R-EP3 (b): 2 hashes change on c2 to c3: a boundary", ivs(whole, flip("H1").concat(flip("H2"))), [iv(c1, c2), iv(c3, c5)]),
		("R-EP3 (b): 2 hashes change in 2 directions: a boundary", ivs(whole, flip("H1").concat([check("H2", c2, Fail), check("H2", c3, Pass)])), [iv(c1, c2), iv(c3, c5)]),
		("R-EP3 (b): 1 hash changes: flat", ivs(whole, flip("H1").concat([check("H2", c2, Pass), check("H2", c3, Pass)])), [iv(c1, c5)]),
		("R-EP5: a hang is not compared", ivs(whole, flip("H1").concat([check("H2", c2, Pass), check("H2", c3, Hang)])), [iv(c1, c5)]),
		("R-EP3 (b): a result on one release only is not compared", ivs(whole, flip("H1").concat([check("H2", c2, Pass), check("H2", c4, Fail)])), [iv(c1, c5)]),
		("R-EP3 (b): build rows are not compared", ivs(whole, [lfact("H1", c2, "x64musl", Pass), lfact("H1", c3, "x64musl", Fail), lfact("H2", c2, "x64musl", Pass), lfact("H2", c3, "x64musl", Fail)]), [iv(c1, c5)]),
		("R-EP3 (b): changes outside the epochs change nothing", ivs([ep("any", c4, c5)], flip("H1").concat(flip("H2"))), [iv(c1, c1), iv(c2, c2), iv(c3, c3), iv(c4, c5)]),
	]
	bad = cases.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# Design Q409 R-AP17: 2 epochs of the answer for the target `any` that overlap (the Worker cannot send it). A release of D that both hold goes to the first epoch in the order of the answer. No stop, no failure.
expect {
	ivs = |epochs| Matrix.intervals({ domain, epochs, facts: [] })
	cases = [
		("the first epoch c1 to c3 keeps c2 and c3", ivs([ep("any", c1, c3), ep("any", c2, c5)]), [iv(c1, c3), iv(c4, c5)]),
		("the first epoch c2 to c5 keeps c2 and c3", ivs([ep("any", c2, c5), ep("any", c1, c3)]), [iv(c1, c1), iv(c2, c5)]),
	]
	bad = cases.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-EP6 R-EP10 R-EP14 R-EP15: `found` is the epochs of `intervals` and `Epochs.infer` with them. With no epoch of the answer it is `Epochs.epochs` (case (b) only). In an epoch of the answer, case (a) gives the result of the hash to the
# other releases of the epoch. A boundary of case (b) stops case (a) at that place.
expect {
	found = |epochs, facts| Matrix.found({ domain, epochs, facts })
	inf = |hash, nightly, outcome, from| { hash, nightly, outcome, modules: [], from }
	ends = [check("H1", c1, Pass), check("H1", c5, Pass)]
	flips = [check("H1", c2, Pass), check("H1", c3, Fail), check("H2", c2, Pass), check("H2", c3, Fail), check("H3", c1, Pass)]
	cases = [
		("R-EP15: no epoch is Epochs.epochs", found([], ends), Epochs.epochs(domain, ends)),
		(
			"R-EP6 (a): a pass on c1 in the epoch c1 to c4",
			found([ep("any", c1, c4)], [check("H1", c1, Pass)]),
			{ epochs: [iv(c1, c4), iv(c5, c5)], inferred: [inf("H1", c2, Pass, [c1]), inf("H1", c3, Pass, [c1]), inf("H1", c4, Pass, [c1])] },
		),
	]
	# R-EP3 (b) stops case (a): H3 is inferred on c2 only (with no split, also on c3, c4, c5).
	split = found([ep("any", c1, c5)], flips).inferred.keep_if(|x| x.hash == "H3")
	dbg split
	bad = cases.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == [] and split == [inf("H3", c2, Pass, [c1])]
}

hint = |hash, nightly, target, p, f, c| { hash, nightly, target, pass_count: p, fail_count: f, crash_count: c }

# R-EF1 rank 6 R-EF3 R-CV1: the hint of a pair. `pass` when the passes are more than the fails and the crashes, `fail` when the fails and the crashes are more, none when they are equal or there is no row of the pair.
expect {
	shared = |hints, nightly, target| Matrix.shared({ hints, hash: "H1", nightly, target })
	cases = [
		("more passes", shared([hint("H1", c1, "any", 5, 1, 0)], c1, "any"), Ok({ result: Pass, pass_count: 5, fail_count: 1, crash_count: 0 })),
		("fails and crashes are more", shared([hint("H1", c1, "any", 1, 1, 1)], c1, "any"), Ok({ result: Fail, pass_count: 1, fail_count: 1, crash_count: 1 })),
		("only crashes", shared([hint("H1", c1, "any", 0, 0, 2)], c1, "any"), Ok({ result: Fail, pass_count: 0, fail_count: 0, crash_count: 2 })),
		("equal: no hint", shared([hint("H1", c1, "any", 2, 1, 1)], c1, "any"), Err(None)),
		("all 0: no hint", shared([hint("H1", c1, "any", 0, 0, 0)], c1, "any"), Err(None)),
		("no row", shared([], c1, "any"), Err(None)),
		("a row of another hash", shared([hint("H2", c1, "any", 5, 0, 0)], c1, "any"), Err(None)),
		("a row of another compiler", shared([hint("H1", c2, "any", 5, 0, 0)], c1, "any"), Err(None)),
		("a row of another target", shared([hint("H1", c1, "x64musl", 5, 0, 0)], c1, "any"), Err(None)),
		("R-CV1: the other tag form", shared([hint("H1", c2_long, "any", 3, 0, 0)], c2, "any"), Ok({ result: Pass, pass_count: 3, fail_count: 0, crash_count: 0 })),
	]
	bad = cases.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

u = |repo| "https://github.com/acme/${repo}/releases/download/1.0.0/${repo}x1x0x0.tar.zst"

hash_of = |url| match Ident.of_url(url) {
	Ok(ident) => ident.hash
	Err(_) => crash "bad test URL"
}

# R-AL4 R-EF1 ranks 4 and 6 R-EF3 R-SE5 R-EF2: the order of the unit probes with the rank 6 hints. The rank 4 hint first, then a rank 6 `pass` hint, then the others. Each group keeps the order of the solver. A hint only orders:
# no pair is added or dropped. Equal counts, another compiler and another target are no hint.
expect {
	pair = |id| { id, nightly: c1, is_platform: Bool.False }
	all = [pair(u("a")), pair(u("b")), pair(u("c")), pair(u("d"))]
	order = |hints, shared| PairOrder.order_shared({ pairs: all, hints, shared }).map(|x| x.id.split_on("/").get(4) ?? "")
	t4 = |repo| { id: u(repo), hint: Ok(c1) }
	h6 = |repo, nightly, target, p, f| hint(hash_of(u(repo)), nightly, target, p, f, 0)
	cases = [
		("no hint: the order of the solver", order([], []), ["a", "b", "c", "d"]),
		("a rank 6 pass hint: first", order([], [h6("c", c1, "any", 4, 1)]), ["c", "a", "b", "d"]),
		("rank 4 before rank 6", order([t4("d")], [h6("b", c1, "any", 4, 1)]), ["d", "b", "a", "c"]),
		("2 rank 6 hints: the order of the pairs", order([], [h6("d", c1, "any", 4, 1), h6("b", c1, "any", 4, 1)]), ["b", "d", "a", "c"]),
		("equal counts: no hint", order([], [h6("c", c1, "any", 1, 1)]), ["a", "b", "c", "d"]),
		("a hint of another compiler: no hint", order([], [h6("c", c2, "any", 4, 0)]), ["a", "b", "c", "d"]),
		("a hint of another target: no hint", order([], [h6("c", c1, "x64musl", 4, 0)]), ["a", "b", "c", "d"]),
		("R-CV1: the other tag form of the compiler", PairOrder.order_shared({ pairs: [pair(u("a")), { id: u("b"), nightly: c2, is_platform: Bool.False }], hints: [], shared: [h6("b", c2_long, "any", 2, 0)] }).map(|x| x.nightly), [c2, c1]),
	]
	bad = cases.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# Design Q393 R-EF3 R-EP8 R-UM1 R-EP7: a rank 2 `fail` has an unknown set of failing modules. Its check becomes an inferred fact with no module: a hard fail that touches each used module, also when the app uses no module of the
# package, and that never decides alone, so the step asks for the local unit probe. A rank 2 `pass`, a fault, a rank 1 row, another target and a fail that loses to a `bot` row stay as they are. The order stays.
expect {
	a = u("a")
	b = u("b")
	ha = hash_of(a)
	hb = hash_of(b)
	chk = |id, nightly, outcome, modules, source| { id, nightly, outcome, modules, source }
	mark = |checks, local, rows| Matrix.unknown_sets({ checks, local, rows })
	cases = [
		("a bot fail: inferred, unknown set", mark([chk(a, c1, Fail, ["Y.roc"], Real)], [], [row(ha, c1, "any", Bot, Fail, Ok("d"))]), [chk(a, c1, Fail, [], Inferred)]),
		("an author fail with no bot row", mark([chk(a, c1, Fail, [], Real)], [], [row(ha, c1, "any", Author, Fail, Ok("d"))]), [chk(a, c1, Fail, [], Inferred)]),
		("a rank 2 pass still decides", mark([chk(a, c1, Pass, [], Real)], [], [row(ha, c1, "any", Bot, Pass, Err(None))]), [chk(a, c1, Pass, [], Real)]),
		("a rank 2 hang stays", mark([chk(a, c1, Hang, [], Real)], [], [row(ha, c1, "any", Bot, Hang, Err(None))]), [chk(a, c1, Hang, [], Real)]),
		("a rank 1 fail wins: its modules stay", mark([chk(a, c1, Fail, ["Y.roc"], Real)], [lfact(ha, c1, "any", Fail)], [row(ha, c1, "any", Bot, Fail, Ok("d"))]), [chk(a, c1, Fail, ["Y.roc"], Real)]),
		("R-EF3: the bot pass wins over the author fail", mark([chk(a, c1, Pass, [], Real)], [], [row(ha, c1, "any", Author, Fail, Ok("d")), row(ha, c1, "any", Bot, Pass, Err(None))]), [chk(a, c1, Pass, [], Real)]),
		("a smoke fail of another target is no unit fail", mark([chk(a, c1, Pass, [], Real)], [], [row(ha, c1, "x64musl", Bot, Fail, Ok("l"))]), [chk(a, c1, Pass, [], Real)]),
		("an inferred check stays", mark([chk(a, c2, Fail, ["Y.roc"], Inferred)], [], []), [chk(a, c2, Fail, ["Y.roc"], Inferred)]),
		(
			"2 checks: only the one of the rank 2 fail, the order stays",
			mark([chk(b, c1, Fail, ["Z.roc"], Real), chk(a, c1, Fail, [], Real)], [lfact(hb, c1, "any", Fail)], [row(ha, c1, "any", Bot, Fail, Err(None))]),
			[chk(b, c1, Fail, ["Z.roc"], Real), chk(a, c1, Fail, [], Inferred)],
		),
	]
	bad = cases.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# Design Q395 R-AL4 R-EF3: a pair with a rank 6 `fail` hint is probed after each pair with no hint. The order: the rank 4 group, the rank 6 `pass` group, no hint, the rank 6 `fail` group.
expect {
	pair = |id| { id, nightly: c1, is_platform: Bool.False }
	pairs = [pair(u("a")), pair(u("b")), pair(u("c")), pair(u("d")), pair(u("e"))]
	h6 = |repo, p, f| hint(hash_of(u(repo)), c1, "any", p, f, 0)
	got = PairOrder.order_shared({ pairs, hints: [{ id: u("e"), hint: Ok(c1) }], shared: [h6("a", 0, 3), h6("c", 3, 0), h6("e", 0, 3)] }).map(|x| x.id.split_on("/").get(4) ?? "")
	dbg got
	got == ["e", "c", "b", "d", "a"]
}

# Slice 209b R-SM6 R-EF3 R-CV1: the `bot` smoke `fail` of one key (platform hash, compiler, real target) for ladder step 3. A `bot` row with the result `fail` gives that row (with its digest). No row, an `author` row only, a `pass`, another hash, another compiler,
# another target (a unit row of the target `any` too) give none. A `bot` `pass` wins over an `author` `fail` (R-EF3). The other tag form of the compiler is the same compiler (R-CV1). A `crash` is a fail (Q558); a `hang` is not used.
expect {
	smoke = |rows, nightly, target| Matrix.smoke_fail({ rows, hash: "PF", nightly, target })
	bot_fail = row("PF", c3, "x64musl", Bot, Fail, Ok("link error"))
	cases = [
		("a bot fail: the row", smoke([bot_fail], c3, "x64musl"), Ok(bot_fail)),
		("a bot fail with a null digest", smoke([row("PF", c3, "x64musl", Bot, Fail, Err(None))], c3, "x64musl"), Ok(row("PF", c3, "x64musl", Bot, Fail, Err(None)))),
		("no row", smoke([], c3, "x64musl"), Err(None)),
		("an author fail only", smoke([row("PF", c3, "x64musl", Author, Fail, Ok("e"))], c3, "x64musl"), Err(None)),
		("a bot pass", smoke([row("PF", c3, "x64musl", Bot, Pass, Err(None))], c3, "x64musl"), Err(None)),
		("R-EF3: the bot pass wins over the author fail", smoke([row("PF", c3, "x64musl", Author, Fail, Ok("e")), row("PF", c3, "x64musl", Bot, Pass, Err(None))], c3, "x64musl"), Err(None)),
		("R-EF3: the bot fail wins over the author pass", smoke([row("PF", c3, "x64musl", Author, Pass, Err(None)), bot_fail], c3, "x64musl"), Ok(bot_fail)),
		("Q558: a bot crash is a fail", smoke([row("PF", c3, "x64musl", Bot, Crash, Err(None))], c3, "x64musl"), Ok(row("PF", c3, "x64musl", Bot, Crash, Err(None)))),
		("Q558: a bot hang is not used", smoke([row("PF", c3, "x64musl", Bot, Hang, Err(None))], c3, "x64musl"), Err(None)),
		("Q558, R-EF3: a bot crash wins over an author pass", smoke([row("PF", c3, "x64musl", Author, Pass, Err(None)), row("PF", c3, "x64musl", Bot, Crash, Err(None))], c3, "x64musl"), Ok(row("PF", c3, "x64musl", Bot, Crash, Err(None)))),
		("Q558, R-EF3: a bot hang wins over an author fail", smoke([row("PF", c3, "x64musl", Author, Fail, Ok("e")), row("PF", c3, "x64musl", Bot, Hang, Err(None))], c3, "x64musl"), Err(None)),
		("another target", smoke([bot_fail], c3, "arm64mac"), Err(None)),
		("the unit target any is no smoke row", smoke([row("PF", c3, "any", Bot, Fail, Ok("e"))], c3, "x64musl"), Err(None)),
		("another compiler", smoke([bot_fail], c4, "x64musl"), Err(None)),
		("another hash", smoke([row("PG", c3, "x64musl", Bot, Fail, Ok("e"))], c3, "x64musl"), Err(None)),
		("R-CV1: the other tag form of the compiler", smoke([row("PF", c2, "x64musl", Bot, Fail, Ok("l"))], c2_long, "x64musl"), Ok(row("PF", c2, "x64musl", Bot, Fail, Ok("l")))),
		("the second of 2 rows of the key: the first bot row decides", smoke([bot_fail, row("PF", c3, "x64musl", Bot, Pass, Err(None))], c3, "x64musl"), Ok(bot_fail)),
	]
	bad = cases.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# Slice 209b R-SM6 R-EP7 R-UM1 R-EF3 R-CV1 Q557 Q558: the checks that step 3 gives to the next search after it dropped the tuple for a smoke fail. One check for each compiler of the rows with a `bot` smoke `fail` (outcome `Fail`) or `crash` (outcome `Crash`) of the key,
# with no module (a fail that touches each module, real), in the order of the rows. A `pass`, a `hang`, an `author` row only, another hash, another target (the unit target `any` too) and a repeat of a compiler give none or no new check.
expect {
	chk = |nightly, outcome| { id: "https://x/pf", nightly, outcome, modules: [], source: Real }
	checks = |rows| Matrix.smoke_checks({ rows, id: "https://x/pf", hash: "PF", target: "x64musl" })
	f = |nightly| row("PF", nightly, "x64musl", Bot, Fail, Ok("l"))
	cases = [
		("no row", checks([]), []),
		("3 compilers with a fail: 3 checks in the order", checks([f(c2), f(c3), f(c4)]), [chk(c2, Fail), chk(c3, Fail), chk(c4, Fail)]),
		("a crash is a Crash check", checks([row("PF", c3, "x64musl", Bot, Crash, Err(None))]), [chk(c3, Crash)]),
		("a pass, a hang: no check; a fail between them: its check", checks([row("PF", c2, "x64musl", Bot, Pass, Err(None)), f(c3), row("PF", c4, "x64musl", Bot, Hang, Err(None))]), [chk(c3, Fail)]),
		("an author fail only: none", checks([row("PF", c3, "x64musl", Author, Fail, Ok("e"))]), []),
		("R-EF3: a bot pass over an author fail: none", checks([row("PF", c3, "x64musl", Author, Fail, Ok("e")), row("PF", c3, "x64musl", Bot, Pass, Err(None))]), []),
		("R-EF3: a bot fail over an author pass: a check", checks([row("PF", c3, "x64musl", Author, Pass, Err(None)), f(c3)]), [chk(c3, Fail)]),
		("another target and the unit target any: none", checks([row("PF", c3, "arm64mac", Bot, Fail, Ok("e")), row("PF", c3, "any", Bot, Fail, Ok("e"))]), []),
		("another hash: none", checks([row("PG", c3, "x64musl", Bot, Fail, Ok("e"))]), []),
		("2 rows of one compiler (2 tag forms, R-CV1): one check", checks([f(c2), f(c2_long)]), [chk(c2, Fail)]),
	]
	bad = cases.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# Slice 209b R-SP16 R-SM6 Design Q562: the second search (the held move) runs after each no-tuple failure of the first search, whatever its text, and only when a variable is movable. Other failure kinds never start it.
expect {
	pf_var = { group: { form: "g", series: "1" }, name: Ok("pf"), is_platform: Bool.True, host: Indexed, patched: Bool.False, uses: [], ranges: [] }
	scoped = |movable| { variable: pf_var, free: Bool.False, movable, any_series: Bool.False, note: Err(None) }
	wanted = |fail, movable| PickMoves.second_wanted(fail, [scoped(movable)])
	cases = [
		("do not fit together", wanted(Fail.of_tuple("no tuple works: acme/json 2.0.0 and acme/pfx 0.1.0 do not fit together", []), Bool.True), Bool.True),
		("the unit check on H fails for the platform", wanted(Fail.of_tuple("no tuple works: the unit check on nightly-2026-10-14-38a3029 fails for the platform acme/pfx 0.1.0", ["h"]), Bool.True), Bool.True),
		("the build for the host target failed (the smoke drop)", wanted(Fail.of_tuple("no tuple works: the build for the host target failed on the platform acme/pfx 0.1.0: link error (bot smoke build)", ["h"]), Bool.True), Bool.True),
		("a no-tuple failure with no movable variable", wanted(Fail.of_tuple("no tuple works: the unit check on H fails for the platform acme/pfx 0.1.0", []), Bool.False), Bool.False),
		("no scoped variable at all", PickMoves.second_wanted(Fail.of_tuple("no tuple works: x", []), []), Bool.False),
		("another kind of failure", wanted(Fail.new(Internal, "the lookup gave no result"), Bool.True), Bool.False),
	]
	bad = cases.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
