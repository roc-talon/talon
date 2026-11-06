import lib.Db
import lib.Epochs
import lib.ProbeRange

ProberangeTest :: [].{}

# The compiler list D of these rows (R-EP11, oldest first): 9 releases, `n1` to `n9`. The target is one hash, `H`.
d9 = ["n1", "n2", "n3", "n4", "n5", "n6", "n7", "n8", "n9"]

fact = |id, outcome| { hash: "H", nightly: id, target: "any", outcome, modules: [], closure: "" }

pass = |id| fact(id, Pass)

fail = |id| fact(id, Fail)

step = |askable, facts| ProbeRange.step({ hash: "H", domain: d9, askable, facts })

found = |facts| ProbeRange.found({ hash: "H", domain: d9, askable: d9, facts })

view = |round| match round {
	Need(ids) => "need ${Str.join_with(ids, " ")}"
	Done(NoPass) => "done no pass"
	Done(Range({ from, to })) => "done ${end_text(from)} .. ${end_text(to)}"
}

end_text = |end| "${end.id}${if end.real "" else "?"}"

view_found = |result| match result {
	NoPass => "no pass"
	Range({ from, to }) => "${end_text(from)} .. ${end_text(to)}"
}

# R-PB3 R-PP2 R-AL4 R-PP4 R-EP5 R-EP6 R-EP8 (slice 037, questions S1 and S2 of the slice file: the tested reading): `ProbeRange.step`, the rounds of the search for the range of one hash. The expected text of each row is the table in the doc of `ProbeRange`, not the code.
# `need <ids>`: the releases to probe in this round (at most 3, the order of the list is the order of the results). `done <from> .. <to>`: the range, an end that is not a real fact has a `?` after its id.
# The search first looks for the newest real pass p, newest candidate first, 3 for each round. Then it cuts the open range below the oldest pass in 4 parts (the releases at the places m/4, m/2 and 3m/4 of the m candidates that are left).
expect {
	rows = [
		("no fact: the newest 3 candidates, the newest first", view(step(d9, [])), "need n9 n8 n7"),
		("the candidates are a few releases: they are asked, the newest first", view(step(["n2", "n5"], [])), "need n5 n2"),
		("no candidate and no fact: no pass", view(step([], [])), "done no pass"),
		("a real fail is a fact: the release is not asked again", view(step(d9, [fail("n9")])), "need n8 n7 n6"),
		("a fault (a hang) is a fact too: the release is not asked again", view(step(d9, [fact("n9", Hang)])), "need n8 n7 n6"),
		("a crash is a fact too", view(step(d9, [fact("n9", Crash)])), "need n8 n7 n6"),
		("a pass on n9: the open range below it has 8 candidates: the places 2, 4 and 6", view(step(d9, [pass("n9")])), "need n3 n5 n7"),
		("2 real passes: the release between them has an inferred pass, so the range starts at n7 (6 left: the places 1, 3 and 4)", view(step(d9, [pass("n9"), pass("n7")])), "need n2 n4 n5"),
		("a pass on n5 and unknown releases above it: they come first (the newest 3 of n6 to n9)", view(step(d9, [pass("n5")])), "need n9 n8 n7"),
		("a pass on n5, real fails n7, n8, n9: only n6 is left above", view(step(d9, [pass("n5"), fail("n7"), fail("n8"), fail("n9")])), "need n6"),
		("a pass on n5, real fails above: 4 candidates below (the places 1, 2 and 3)", view(step(d9, [pass("n5"), fail("n6"), fail("n7"), fail("n8"), fail("n9")])), "need n2 n3 n4"),
		("a real fail on n3 bounds the open range: only n4 is between", view(step(d9, [pass("n5"), fail("n6"), fail("n7"), fail("n8"), fail("n9"), fail("n3")])), "need n4"),
		("a real fail right below the pass: nothing is left, the range is n5 and both ends are real", view(step(d9, [pass("n5"), fail("n4"), fail("n6"), fail("n7"), fail("n8"), fail("n9")])), "done n5 .. n5"),
		("3 candidates below p: all of them", view(step(d9, [pass("n4"), fail("n5"), fail("n6"), fail("n7"), fail("n8"), fail("n9")])), "need n1 n2 n3"),
		("5 candidates below p: the places 1, 2 and 3", view(step(d9, [pass("n6"), fail("n7"), fail("n8"), fail("n9")])), "need n2 n3 n4"),
		("7 candidates below p: the places 1, 3 and 5", view(step(d9, [pass("n8"), fail("n9")])), "need n2 n4 n6"),
		("only some releases can be asked: the open range has 2 of them, both are asked", view(step(["n2", "n3"], [pass("n5"), fail("n6"), fail("n7"), fail("n8"), fail("n9")])), "need n2 n3"),
		("an island: a pass on n2, a fail on n4, a pass on n6. The pass on n2 is not part of the range of n6, and the search does not go below the fail on n4", view(step(d9, [pass("n2"), fail("n4"), pass("n6"), fail("n7"), fail("n8"), fail("n9")])), "need n5"),
		("the inferred passes between 2 real passes are in the range: n3 and n7 pass, so the open range is n1 and n2", view(step(d9, [pass("n3"), pass("n7"), fail("n8"), fail("n9")])), "need n1 n2"),
		("a row of another target is no fact (a build, R-LD2: the range uses unit checks)", view(step(d9, [{ ..pass("n9"), target: "x64musl" }])), "need n9 n8 n7"),
		("a row of a release that D does not have is not read", view(step(d9, [pass("zz")])), "need n9 n8 n7"),
		("a row of another hash is not read", view(step(d9, [{ ..pass("n9"), hash: "other" }])), "need n9 n8 n7"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-PB3 R-PB4 R-EP5 R-EP6 (slice 037, question S3 of the slice file): `ProbeRange.found`, the range for the facts that are known. An end is real when the release outside the range next to it has a real fail, or the end is the end of D (R-PB3).
# Else the end is unknown (R-PB4): the release next to it has no fact, or a fault. The range is also given when the search is not done (the budget is spent): then an end is unknown unless a real fact shows it.
expect {
	rows = [
		("a pass between 2 real fails: both ends are real", view_found(found([fail("n4"), pass("n5"), fail("n6")])), "n5 .. n5"),
		("the oldest release of D is a pass: the lower end is the end of D, the upper end has an unknown neighbor", view_found(found([pass("n1")])), "n1 .. n1?"),
		("the newest release is a pass: the upper end is the end of D", view_found(found([pass("n9")])), "n9? .. n9"),
		("a pass alone: both ends are unknown", view_found(found([pass("n5")])), "n5? .. n5?"),
		("the passes of n3 and n7 and the fails of n2 and n8: the inferred releases between are in the range, both ends are real", view_found(found([fail("n2"), pass("n3"), pass("n7"), fail("n8")])), "n3 .. n7"),
		("the same without the fails: both ends are unknown", view_found(found([pass("n3"), pass("n7")])), "n3? .. n7?"),
		("a hang next to the lower end is no real fail: the end is unknown (question S3)", view_found(found([fact("n4", Hang), pass("n5"), fail("n6")])), "n5? .. n5"),
		("a crash next to the upper end: unknown", view_found(found([fail("n4"), pass("n5"), fact("n6", Crash)])), "n5 .. n5?"),
		("an inferred pass is a pass for the range, an inferred fail is not: fails on n2 and n4 make n3 an inferred fail, so a pass on n5 starts the range at n5", view_found(found([fail("n2"), fail("n4"), pass("n5"), fail("n6")])), "n5 .. n5"),
		("an island of passes: the range is the one that has the newest pass", view_found(found([pass("n1"), fail("n2"), fail("n3"), pass("n6"), fail("n7")])), "n6? .. n6"),
		("no fact: no pass", view_found(found([])), "no pass"),
		("only fails: no pass", view_found(found([fail("n1"), fail("n9")])), "no pass"),
		("only a fault: no pass", view_found(found([fact("n5", Hang)])), "no pass"),
		("a pass of the whole list: both ends are the ends of D", view_found(found(d9.map(pass))), "n1 .. n9"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# The world of the simulation: bit i of `truth` says that release i+1 passes. `ask` answers the probes of a round with the facts.
pow2 = |n| List.repeat(0, n).fold(1.U64, |acc, _| acc * 2)

passes = |truth, i| (truth // pow2(i)) % 2 == 1

ids_of = |n| List.repeat(0, n).map_with_index(|_, i| "n${(i + 1).to_str()}")

index_of = |ids, id| ids.find_first_index(|x| x == id) ?? 0

# The loop of the command: `step`, the probes of the round (the truth), and again. A round that breaks a rule of the table makes `Err(<what>)`. `fuel` ends a search that does not end.
simulate : { n : U64, truth : U64, askable : List(Str) }, List(Db.Fact), U64 -> Try({ result : ProbeRange.Found, rounds : U64, facts : List(Db.Fact) }, Str)
simulate = |world, facts, fuel| {
	ids = ids_of(world.n)
	input = { hash: "H", domain: ids, askable: world.askable, facts }
	if fuel == 0 {
		Err("no end")
	} else {
		match ProbeRange.step(input) {
			Done(result) => Ok({ result, rounds: 0, facts })
			Need(asked) => {
				known = facts.map(|f| f.nightly)
				bad = if asked.len() > 3 or asked.is_empty() {
					Err("round size ${asked.len().to_str()}")
				} else if asked.any(|id| !world.askable.contains(id)) {
					Err("not askable")
				} else if asked.any(|id| known.contains(id)) {
					Err("known again")
				} else if asked.any(|id| asked.count_if(|x| x == id) > 1) {
					Err("twice")
				} else {
					Ok({})
				}
				match bad {
					Err(what) => Err(what)
					Ok(_) => {
						made = asked.map(|id| fact(id, if passes(world.truth, index_of(ids, id)) Pass else Fail))
						match simulate(world, facts.concat(made), fuel - 1) {
							Ok(done) => Ok({ ..done, rounds: done.rounds + 1 })
							Err(what) => Err(what)
						}
					}
				}
			}
		}
	}
}

# The range by its definition (R-PB3), from the facts that the search made and the inferred facts of `Epochs`: the maximal interval around the newest real pass in which each release has a pass.
# `Epochs` is the function of R-EP6. The rest is written here from the rule text.
by_definition : List(Str), List(Db.Fact) -> Try({ from : ProbeRange.End, to : ProbeRange.End }, [NoPass])
by_definition = |ids, facts| {
	releases = ids.map(|id| { id, published_at: 0, asset: Err(NoAsset) })
	inferred = Epochs.epochs(releases, facts).inferred
	cell = |id| match facts.find_first(|f| f.nightly == id) {
		Ok(f) => if f.outcome == Pass "pass" else if f.outcome == Fail "fail" else "fault"
		Err(_) => match inferred.find_first(|i| i.nightly == id) {
			Ok(i) => if i.outcome == Pass "pass" else "ifail"
			Err(_) => "unknown"
		}
	}
	is_pass = |i| match ids.get(i) {
		Ok(id) => cell(id) == "pass"
		Err(_) => Bool.False
	}
	real_passes = ids.map_with_index(|id, i| (id, i)).keep_if(|(id, _)| facts.any(|f| f.nightly == id and f.outcome == Pass))
	match real_passes.last() {
		Err(_) => Err(NoPass)
		Ok((_, p)) => {
			places : List(U64)
			places = ids.map_with_index(|_, i| i)
			low = places.keep_if(|i| i <= p).rev().fold_until(p, |at, i| if is_pass(i) Continue(i) else Break(at))
			high = places.keep_if(|i| i >= p).fold_until(p, |at, i| if is_pass(i) Continue(i) else Break(at))
			real_end = |next| match ids.get(next) {
				Ok(id) => cell(id) == "fail"
				Err(_) => Bool.True
			}
			Ok({
				from: { id: ids.get(low) ?? "", real: low == 0 or real_end(low - 1) },
				to: { id: ids.get(high) ?? "", real: real_end(high + 1) },
			})
		}
	}
}

# R-PB3 R-PB4 R-PP2 R-AL4 R-PP4 R-EP5 R-EP6 R-EP8 (slice 037): the search against a world, for all 256 truth tables of 8 releases and 3 sets of askable releases (all, the odd ones, a few). The loop is the loop of the command: `step`, the probes of the round, `step`.
# In each world: every round has 1 to 3 releases, each is askable, new and once in the round (R-AL4, R-PP2); the search ends in at most 8 rounds; the result is the range by its definition (written in this file from the rule text); and when the truth is one run of passes and every release can be asked,
# the range is that run, and both ends are real (the search finds the whole run: R-PB3). `found` of the final facts is the result of the last step (R-PB4).
expect {
	n = 8
	ids = ids_of(n)
	askables = [ids, ids.keep_if(|id| (index_of(ids, id) % 2) == 0), ["n2", "n3", "n6"]]
	truths = List.repeat(0, 256).map_with_index(|_, i| i)
	problems = askables.join_map(
		|askable| truths.join_map(
			|truth| match simulate({ n, truth, askable }, [], 12) {
				Err(what) => ["truth ${truth.to_str()} askable ${Str.join_with(askable, ",")}: ${what}"]
				Ok(done) => {
					want = by_definition(ids, done.facts)
					got = match done.result {
						NoPass => Err(NoPass)
						Range(r) => Ok(r)
					}
					same = Str.inspect(got) == Str.inspect(want)
					same_found = Str.inspect(ProbeRange.found({ hash: "H", domain: ids, askable, facts: done.facts })) == Str.inspect(done.result)
					places = ids.keep_if(|id| passes(truth, index_of(ids, id)))
					run_from = places.first() ?? ""
					run_to = places.last() ?? ""
					contiguous = places.len() > 0 and (index_of(ids, run_to) - index_of(ids, run_from) + 1 == places.len())
					whole = if contiguous and askable == ids {
						Str.inspect(got) == Str.inspect(Ok({ from: { id: run_from, real: Bool.True }, to: { id: run_to, real: Bool.True } }))
					} else {
						Bool.True
					}
					if done.rounds > 8 {
						["truth ${truth.to_str()} askable ${Str.join_with(askable, ",")}: ${done.rounds.to_str()} rounds"]
					} else if !same {
						["truth ${truth.to_str()} askable ${Str.join_with(askable, ",")}: result ${Str.inspect(got)} is not the definition ${Str.inspect(want)}"]
					} else if !same_found {
						["truth ${truth.to_str()}: found differs from the last step"]
					} else if !whole {
						["truth ${truth.to_str()}: the run of passes is not found whole: ${Str.inspect(got)}"]
					} else {
						[]
					}
				}
			},
		),
	)
	dbg problems.take_first(5)
	problems == []
}
