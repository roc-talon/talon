app [main!] { resolve: "../main.roc" }

import resolve.Domain
import resolve.Solver

main! = |_args| Ok({})

# R-SP24 R-SP23 R-PH10 R-VA6 R-DT2 (slice 036): `Solver.step_moves`, the step of the second search of a held move. The expected value of each row is the design text (Resolution 9, R-SP24), not the code:
# the movable variables are first in the search, in the order of `priority`, then the other variables. A movable variable has its current value first, then the nearest values: with `Highest` the higher versions from low to high, then the lower ones
# from high to low. With `Lowest` the lower ones from high to low, then the higher ones from low to high. So a movable variable keeps its value when a tuple exists with it and the earlier movable variables, and else moves the smallest step.
# A slot `a` has the releases `a-<version>` (the id of a release). The slots are in the order of `priority`. A step has `Highest` unless the row says `low`.

cand : Str, Str -> Domain.Candidate
cand = |name, v| { id: "${name}-${v}", version: v, published_at: 0, yanked: Bool.False }

# A free slot. `with` makes it a slot with a header value (the id of its release).
slot : Str, List(Str) -> Solver.Slot
slot = |name, versions| { name, group: name, kind: Package, candidates: versions.map(|v| cand(name, v)), ranges: [], current: Err(None), named: Err(None) }

held : Solver.Slot, Str -> Solver.Slot
held = |s, v| { ..s, current: Ok({ id: "${s.name}-${v}", version: v }) }

known : List(Solver.Slot) -> List(Solver.Fact)
known = |slots| slots.join_map(|s| s.candidates.map(|c| { id: c.id, kind: Package, pf: Err(None), deps: [] }))

# The fact of release `id` gets these deps (a dep is a `group` and the lowest version).
needs : List(Solver.Fact), Str, List((Str, Str)) -> List(Solver.Fact)
needs = |facts, id, deps| facts.map(|f| if f.id == id { ..f, deps: deps.map(|(group, version)| { group, version }) } else f)

req : List(Solver.Slot), List(Solver.Fact) -> Solver.Request
req = |slots, facts| { slots, rules: { now: 1000, min_age: 100, snapshot: Err(None), strategy: Highest }, facts, conflicts: [], compat: { domain: [], checks: [], used: [], probes: Allowed } }

low : Solver.Request -> Solver.Request
low = |r| { ..r, rules: { ..r.rules, strategy: Lowest } }

# A conflict of the caller: these releases (`<name>-<version>`) cannot all be chosen.
without : Solver.Request, List(List((Str, Str))) -> Solver.Request
without = |r, conflicts| { ..r, conflicts: conflicts.map(|terms| terms.map(|(name, v)| { name, ids: ["${name}-${v}"], sign: In })) }

ask_id : Solver.Ask -> Str
ask_id = |a| match a {
	Header(id) => id
	Probe(p) => "${p.id}@${p.nightly}"
}

# A step as text: `done a=1.0.0 b=2.0.0` (in the order of the slots, `a=1.0.0(id)` when the id is not `a-1.0.0`), `need a-1.0.0 b-2.0.0`, or `fail`. A row does not read the reason of a `Fail`.
show : [Need(List(Solver.Ask)), Done(List(Solver.Chosen)), Fail(Solver.Why)] -> Str
show = |r| match r {
	Need(asks) => "need ${Str.join_with(asks.map(ask_id), " ")}"
	Done(chosen) => "done ${Str.join_with(chosen.map(|c| if c.id == "${c.name}-${c.version}" "${c.name}=${c.version}" else "${c.name}=${c.version}(${c.id})"), " ")}"
	Fail(_) => "fail"
}

# The rows: a request, the names of the movable slots, the step as text, a label. A row is wrong when the step differs, or when the step of the flipped request differs (R-DT2).
wrong : List((Solver.Request, List(Str), Str, Str)) -> List(Str)
wrong = |rows| rows.keep_if(|(r, names, want, _)| show(Solver.step_moves(r, names)) != want or show(Solver.step_moves(flipped(r), names)) != want).map(|(_, _, _, label)| label)

# The lists of the candidates, the facts and the conflicts reversed (R-DT2: their order does not change the result. The order of the slots does: it is `priority`).
flipped : Solver.Request -> Solver.Request
flipped = |r| { ..r, slots: r.slots.map(|s| { ..s, candidates: s.candidates.rev() }), facts: r.facts.rev(), conflicts: r.conflicts.rev().map(|c| c.rev()) }

# R-SP24 (the order of the values): `x` is held at 1.2.0 and has 1.0.0 to 1.3.0, `y` is free. A movable variable keeps its value when it can, also when `y` has no conflict and would like the newest release. With the value excluded,
# `Highest` takes the nearest higher release before any lower one (1.3.0, not 1.1.0), `Lowest` takes the nearest lower one first. The order goes on: higher from low to high, then lower from high to low (Highest), lower from high to low,
# then higher from low to high (Lowest). The strategy gives no order to a slot that is not movable: `y` is highest or lowest.
expect {
	x = held(slot("x", ["1.0.0", "1.1.0", "1.2.0", "1.3.0", "1.4.0"]), "1.2.0")
	y = slot("y", ["1.0.0", "2.0.0"])
	base = req([x, y], known([x, y]))
	out = |vs| without(base, vs.map(|v| [("x", v)]))
	rows = [
		(base, [], "done x=1.4.0 y=2.0.0", "no movable slot: the plain step, the highest of each slot"),
		(base, ["x"], "done x=1.2.0 y=2.0.0", "the movable x keeps its value, y is highest"),
		(low(base), ["x"], "done x=1.2.0 y=1.0.0", "the same with lowest: y is lowest, x keeps its value"),
		(out(["1.2.0"]), ["x"], "done x=1.3.0 y=2.0.0", "Highest: the nearest higher release first"),
		(low(out(["1.2.0"])), ["x"], "done x=1.1.0 y=1.0.0", "Lowest: the nearest lower release first"),
		(out(["1.2.0", "1.3.0"]), ["x"], "done x=1.4.0 y=2.0.0", "Highest: the higher releases from low to high (1.4.0 after 1.3.0)"),
		(out(["1.2.0", "1.3.0", "1.4.0"]), ["x"], "done x=1.1.0 y=2.0.0", "Highest: the lower releases come after all the higher ones, from high to low"),
		(out(["1.2.0", "1.3.0", "1.4.0", "1.1.0"]), ["x"], "done x=1.0.0 y=2.0.0", "Highest: the last lower release"),
		(low(out(["1.2.0", "1.1.0"])), ["x"], "done x=1.0.0 y=1.0.0", "Lowest: the lower releases from high to low (1.0.0 after 1.1.0)"),
		(low(out(["1.2.0", "1.1.0", "1.0.0"])), ["x"], "done x=1.3.0 y=1.0.0", "Lowest: the higher releases come after all the lower ones, from low to high"),
		(out(["1.0.0", "1.1.0", "1.2.0", "1.3.0", "1.4.0"]), ["x"], "fail", "no value of x is left: no tuple"),
		(out(["1.2.0"]), [], "done x=1.4.0 y=2.0.0", "the plain step ignores the old value: highest"),
	]
	bad = wrong(rows)
	dbg bad
	bad == []
}

# R-SP24 R-VA6 (the order of the variables): the movable variables are first in the search, in the order of `priority`, then the others. `a` is a free slot, listed first. `b` is movable. In the plain step `a` is decided first: it takes
# a-2.0.0 and then `b` has to take b-2.0.0. In the second search `b` is decided first and keeps b-1.0.0, so `a` has to take a-1.0.0. The result, and the `Need` list, are in the order of the slots of the request, not of the search.
expect {
	a = slot("a", ["1.0.0", "2.0.0"])
	b = held(slot("b", ["1.0.0", "2.0.0"]), "1.0.0")
	c = held(slot("c", ["1.0.0", "2.0.0"]), "1.0.0")
	facts = needs(known([a, b, c]), "a-2.0.0", [("b", "2.0.0")])
	both = needs(needs(facts, "b-1.0.0", [("c", "2.0.0")]), "b-2.0.0", [("c", "2.0.0")])
	one_of = |slots| without(req(slots, known([b, c])), [[("b", "1.0.0"), ("c", "1.0.0")]])
	rows = [
		(req([a, b], facts), [], "done a=2.0.0 b=2.0.0", "the plain step: a is first, so a is highest and b follows"),
		(req([a, b], facts), ["b"], "done a=1.0.0 b=1.0.0", "b is movable: it is decided first and keeps its value, a gives way"),
		(req([a, b], []), [], "need a-2.0.0 b-2.0.0", "the plain Need list"),
		(req([a, b], []), ["b"], "need a-2.0.0 b-1.0.0", "the Need list is in the order of the slots: a before b, though b is decided first"),
		(req([a, b], []), ["x", "b"], "need a-2.0.0 b-1.0.0", "a name that is no slot is ignored"),
		(req([a, b, c], both), ["b", "c"], "done a=1.0.0 b=1.0.0 c=2.0.0", "b is before c: b keeps its value (a tuple exists with b-1.0.0), c moves to c-2.0.0 (b-1.0.0 needs it), a gives way"),
		(one_of([b, c]), ["b", "c"], "done b=1.0.0 c=2.0.0", "b and c cannot both keep their values: the first movable slot keeps it, the second moves"),
		(one_of([c, b]), ["b", "c"], "done c=1.0.0 b=2.0.0", "the order of the slots is the order of the movable slots: now c keeps its value and b moves (the result is in the order of the slots)"),
		(one_of([b, c]), ["c"], "done b=2.0.0 c=1.0.0", "only c is movable: it is first in the search and keeps its value, b (not movable) gives way"),
	]
	bad = wrong(rows)
	dbg bad
	bad == []
}

# R-SP23 R-C1 R-C4 R-C6 R-C7 R-C9: a movable variable keeps the constraints of a free variable, and only the order of its values differs. A range (R-C1): 2.0.0 is not a value of `x` with the range `^1`, also when it is the nearest higher
# release. A release that is too young (R-C7) and a yanked release (R-C6) are no value, a release with the wrong kind (R-C4) is no value. The header value is a value also when the candidates lack it (R-C9). The compiler slot is movable only when it is named and has a header value (slice 039c, the next expect).
expect {
	versions = ["1.0.0", "1.1.0", "1.2.0", "1.3.0", "2.0.0"]
	x = held({ ..slot("x", versions), ranges: ["^1"] }, "1.2.0")
	base = |s| req([s], known([s]))
	out = |r, vs| without(r, vs.map(|v| [("x", v)]))
	young = { ..x, candidates: x.candidates.map(|c| if c.id == "x-1.3.0" { ..c, published_at: 950 } else c) }
	yanked = { ..x, candidates: x.candidates.map(|c| if c.id == "x-1.3.0" { ..c, yanked: Bool.True } else c) }
	app_kind = known([x]).map(|f| if f.id == "x-1.3.0" { ..f, kind: App } else f)
	no_list = held({ ..slot("x", ["1.0.0", "1.3.0"]), ranges: ["^1"] }, "1.2.0")
	no_list_facts = known([no_list]).append({ id: "x-1.2.0", kind: Package, pf: Err(None), deps: [] })
	roc = { name: "roc", group: "roc", kind: Compiler, candidates: [cand("n", "1"), cand("m", "2")], ranges: [], current: Ok({ id: "n-1", version: "1" }), named: Err(None) }
	with_roc = { ..req([x, roc], known([x])), compat: { domain: ["n-1", "m-2"], checks: [], used: [], probes: Off } }
	rows = [
		(out(base(x), ["1.2.0"]), ["x"], "done x=1.3.0", "Highest: the nearest higher release, inside the range"),
		(out(base(x), ["1.2.0", "1.3.0"]), ["x"], "done x=1.1.0", "R-C1: 2.0.0 is out of the range, so after 1.3.0 come the lower releases"),
		(out(base(young), ["1.2.0"]), ["x"], "done x=1.1.0", "R-C7: 1.3.0 is too young, so the nearest higher release is gone"),
		(out(base(yanked), ["1.2.0"]), ["x"], "done x=1.1.0", "R-C6: 1.3.0 is yanked"),
		(out(req([x], app_kind), ["1.2.0"]), ["x"], "done x=1.1.0", "R-C4: the fact of 1.3.0 has the kind App"),
		(out(req([no_list], no_list_facts), ["1.0.0"]), ["x"], "done x=1.2.0", "R-C9: the header value 1.2.0 is not in the list of candidates, and it keeps its place first"),
		(low(out(req([no_list], no_list_facts), ["1.2.0"])), ["x"], "done x=1.0.0", "R-C9, Lowest: with the header value out, the lower release"),
		(with_roc, ["roc", "x"], "done x=1.2.0 roc=1(n-1)", "slice 039c (R-RP4): a compiler slot with a header value is movable when it is named: its value n-1 comes first, though D (Highest) would give the newest m-2 first"),
		(with_roc, ["x"], "done x=1.2.0 roc=2(m-2)", "the compiler slot is not named: it is free, its order is the order of D (Highest: the newest first)"),
	]
	bad = wrong(rows)
	dbg bad
	bad == []
}

# R-RP4 R-SP24 R-SP23 R-SP13 (slice 039c): a movable compiler. `tln upgrade X` holds the nightly, and a held move can include it. The compiler `roc` has 5 releases in D (roc-1 oldest to roc-5), the held one is roc-3.
# Its values: `current` first, then the nearest in the order of D (not a semver): `Highest` the compilers after it from old to new, then the ones before it from new to old. `Lowest` the ones before it from new to old, then the ones after it from old to new.
# A fail is a real check with no module (a hard fail), as the oracle gives it for a unit probe. The pair has no check on the other compilers: `Off` takes it as fit. The compiler is the last slot, so it is decided after the movable packages and before the free ones.
expect {
	ds = ["roc-1", "roc-2", "roc-3", "roc-4", "roc-5"]
	roc = { name: "roc", group: "roc", kind: Compiler, candidates: ["1", "2", "3", "4", "5"].map(|v| cand("roc", v)), ranges: [], current: Ok({ id: "roc-3", version: "3" }), named: Err(None) }
	# `x` is a held package with its header value x-1.0.0 only (no candidate), `y` is a free package.
	x = { ..slot("x", []), current: Ok({ id: "x-1.0.0", version: "1.0.0" }) }
	y = slot("y", ["1.0.0", "2.0.0"])
	z = held(slot("z", ["1.0.0", "1.1.0"]), "1.0.0")
	fx = [{ id: "x-1.0.0", kind: Package, pf: Err(None), deps: [] }]
	check = |id, nightly, outcome| { id, nightly, outcome, modules: [], source: Real }
	fails = |id, ns| ns.map(|n| check(id, "roc-${n}", Fail))
	world = |slots, facts, checks| { ..req(slots, facts), compat: { domain: ds, checks, used: [], probes: Off } }
	names = ["roc"]
	rows = [
		(world([x, roc], fx, []), names, "done x=1.0.0 roc=3", "no fact: the movable compiler keeps H (roc-3, in the middle of D), the newest roc-5 is not taken"),
		(world([x, roc], fx, fails("x-1.0.0", ["3"])), names, "done x=1.0.0 roc=4", "x fails on H: Highest takes the nearest higher compiler roc-4, not the newest roc-5"),
		(world([x, roc], fx, fails("x-1.0.0", ["3", "4"])), names, "done x=1.0.0 roc=5", "roc-3 and roc-4 fail: the higher compilers go from old to new, so roc-5"),
		(world([x, roc], fx, fails("x-1.0.0", ["3", "4", "5"])), names, "done x=1.0.0 roc=2", "no higher compiler works: the lower ones come after, from new to old (roc-2 first)"),
		(world([x, roc], fx, fails("x-1.0.0", ["3", "4", "5", "2"])), names, "done x=1.0.0 roc=1", "the lower ones from new to old: roc-1 after roc-2"),
		(low(world([x, roc], fx, fails("x-1.0.0", ["3"]))), names, "done x=1.0.0 roc=2", "Lowest: the nearest lower compiler first"),
		(low(world([x, roc], fx, fails("x-1.0.0", ["3", "2", "1"]))), names, "done x=1.0.0 roc=4", "Lowest: the lower ones from new to old, then the higher ones from old to new (roc-4 first)"),
		(world([x, roc], fx, fails("x-1.0.0", ["3", "4", "5", "2", "1"])), names, "fail", "no compiler works: no tuple"),
		(world([x, { ..roc, current: Err(None) }], fx, fails("x-1.0.0", ["3"])), names, "done x=1.0.0 roc=5", "a compiler slot with no header value is not movable (a name in the list has no effect): the order of D, the newest first"),
		(low(world([x, { ..roc, current: Err(None) }], fx, fails("x-1.0.0", ["3"]))), names, "done x=1.0.0 roc=1", "Lowest, no header value: the compiler is not movable, so the order of D is kept (oldest first, roc-1). A movable compiler with no `current` would start at the end and give roc-5 (B2 of the gap test)"),
		(world([x, roc], fx, fails("x-1.0.0", ["3"])), [], "done x=1.0.0 roc=5", "the compiler is not named: it is free, the newest compiler that works is roc-5 (the control row of the one above)"),
		(world([x, { ..roc, current: Ok({ id: "roc-9", version: "9" }) }], fx, fails("x-1.0.0", ["5"])), names, "done x=1.0.0 roc=4", "a header value that is not in D is no value: each value is a lower one, the newest first (roc-5 fails, so roc-4)"),
		(world([z, roc], known([z]), fails("z-1.0.0", ["3"])), ["z", "roc"], "done z=1.0.0 roc=4", "a movable package and a movable compiler: z is decided first and keeps z-1.0.0, so the compiler moves to roc-4"),
		(world([y, roc], known([y]), fails("y-2.0.0", ["3", "4"])), names, "done y=1.0.0 roc=3", "the compiler is decided before a free package: it keeps H, and y gives way to y-1.0.0 (the nightly moves only when no tuple has H, R-UP13)"),
		(world([y, roc], known([y]), fails("y-2.0.0", ["3", "4"]).concat(fails("y-1.0.0", ["3", "4"]))), names, "done y=2.0.0 roc=5", "no release of y works on roc-3 or roc-4: now the compiler moves to roc-5, and y keeps its best release"),
	]
	bad = wrong(rows)
	dbg bad
	bad == []
}

# R-SP24 R-VA6 R-DT2: `step_moves` equals a brute-force search that is written from the rule text. The oracle gives each slot its order of values (a movable slot: its value, then the nearest by the rule above, a free slot: highest or lowest),
# puts the movable slots first, makes all tuples in lexicographic order, and takes the first tuple that no conflict forbids. The world has 3 slots of 4 releases (a and c are held, b is free) and 3 conflicts of 2 releases each for each of 24 seeds, and for 5 of 6 seeds more conflicts that exclude the held value of a or of c (with each value of b, or alone), a, or both together, or all values of a,
# the sets `[a]`, `[a, c]`, `[c]` and none of the movable slots, `Highest` and `Lowest`: 192 requests. A seed makes its conflicts from `seed` with whole-number arithmetic, so the rows do not depend on the order of any list.
expect {
	names = ["a", "b", "c"]
	minors = [0.U64, 1, 2, 3]
	slots_of = names.map(|n| slot(n, minors.map(|m| "1.${m.to_str()}.0")))
	a = held(slots_of.get(0) ?? slot("a", []), "1.1.0")
	b = slots_of.get(1) ?? slot("b", [])
	c = held(slots_of.get(2) ?? slot("c", []), "1.2.0")
	start = req([a, b, c], known([a, b, c]))
	currents = [("a", 1.U64), ("c", 2)]
	# The order of the minors of one slot (the rule text). `up`: Highest.
	order_of = |name, movable, up| {
		cur = currents.find_first(|(n, _)| n == name)
		if movable {
			at = match cur {
				Ok((_, m)) => m
				Err(_) => 0
			}
			higher = minors.keep_if(|m| m > at)
			lower = minors.keep_if(|m| m < at).rev()
			own = minors.keep_if(|m| m == at)
			if up own.concat(higher).concat(lower) else own.concat(lower).concat(higher)
		} else {
			if up minors.rev() else minors
		}
	}
	# All tuples in lexicographic order. A tuple is a list of (name, minor) in the order of the search.
	tuples = |orders| match orders {
		[] => [[]]
		[(n, ms), .. as rest] => ms.join_map(|m| tuples(rest).map(|t| [(n, m)].concat(t)))
	}
	seeds = List.repeat(0, 24).map_with_index(|_, i| i)
	conflicts_of = |seed| {
		pairs = List.repeat(0, 3).map_with_index(
			|_, k| {
				i = (seed + k) % 3
				j = (i + 1 + (seed // 3 + k) % 2) % 3
				[(names.get(i) ?? "", (seed * 7 + k * 3 + seed // 5) % 4), (names.get(j) ?? "", (seed * 5 + k + seed // 2) % 4)]
			},
		)
		kill = |n, m| minors.map(|v| [(n, m), ("b", v)])
		extra = match seed % 6 {
			1 => kill("a", 1)
			2 => kill("c", 2)
			3 => [[("a", 1)], [("a", 2)]]
			4 => minors.map(|v| [("a", v)])
			5 => [[("a", 1), ("c", 2)]]
			_ => []
		}
		pairs.concat(extra)
	}
	forbidden = |t, conflicts| conflicts.any(|terms| terms.all(|(n, m)| t.contains((n, m))))
	oracle = |seed, moved, up| {
		search_order = moved.concat(names.keep_if(|n| !moved.contains(n)))
		orders = search_order.map(|n| (n, order_of(n, moved.contains(n), up)))
		found = tuples(orders).find_first(|t| !forbidden(t, conflicts_of(seed)))
		match found {
			Ok(t) => "done ${Str.join_with(names.map(|n| "${n}=1.${(t.find_first(|(x, _)| x == n).map_ok(|(_, m)| m) ?? 9).to_str()}.0"), " ")}"
			Err(_) => "fail"
		}
	}
	sets = [["a"], ["a", "c"], ["c"], []]
	rows = seeds.join_map(
		|seed| sets.join_map(
			|moved| [Bool.True, Bool.False].map(
				|up| {
					r = without(start, conflicts_of(seed).map(|terms| terms.map(|(n, m)| (n, "1.${m.to_str()}.0"))))
					((if up r else low(r)), moved, oracle(seed, moved, up), "seed ${seed.to_str()}, movable ${Str.join_with(moved, ",")}, ${if up "Highest" else "Lowest"}")
				},
			),
		),
	)
	bad = wrong(rows)
	dbg bad
	bad == []
}
