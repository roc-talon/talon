app [target] {
	fuzz: platform "https://github.com/lukewilliamboswell/roc-fuzz/releases/download/0.4.3/41NK5FShyGC9Z8HNpUdUeXMWwLmLNfFxsfmLvdPL4Fxb.tar.zst",
	resolve: "../../packages/resolve/main.roc",
}

import fuzz.Fuzz
import resolve.Solver

# L1 target of slice 034 (TESTING.md 4, the `pubgrub` row): random small problems against a brute-force search of all tuples. The oracle is written here from the rule text of Resolution 1, 2 and 5
# (integers and index loops, no set of values, no propagation), not from the code of `packages/resolve`. One run checks these properties of one input. The first words of a crash text are the rule ids.
#
# | Property | Rule |
# | --- | --- |
# | A step with a random part of the facts equals the oracle with the same facts: `Fail` when no tuple exists, else the best tuple by `priority`, and `Need` (the ids of the tuple that have no fact, in the order of the slots) or `Done` | R-VA6 R-AL3 R-AL8 R-C1 R-C2 R-C3 R-C4 R-C6 R-C7 R-C9 |
# | The loop of a command (step, give the facts that it asks for, step) ends with the oracle result for all facts, in at most one round for each release. A need is never empty, never repeats a release that is known, and names only a release that a domain has (R-AL9: no fact of a release that cannot win) | R-AL8 R-AL9 R-VA6 |
# | The lists of the request in another order (the candidates, the facts, the conflicts and their terms) give the same step | R-DT2 |
#
# The input is 2 numbers of 64 bits (16 bytes). A mixing function (splitmix64) makes 7 words of 64 bits from them. So each input is a full random problem, with no byte of the input unused and no zero padding. A list of random length
# would need hundreds of bytes, and libFuzzer grows its inputs slowly (the first thousands of inputs are short: with 20000 runs that gave few problems with a dep or a conflict, `research/slice-034-revert/mutate2.log`). The bits of the 7 words make the world:
#
# | Word | Bits | Use |
# | --- | --- | --- |
# | 0 | bits 0 and 1, 2 and 3, 8, 9 and 10, 11 to 26, 27 to 38, 39 to 62 | the count of slots (1 to 3), the platform slot (the number of a slot, or 3 for none: so at most one platform slot), the strategy, the snapshot, the known facts (one bit for each release of the world), a header value for each slot, a range for each slot |
# | 1, 2 | 7 bits for each of the 12 releases (3 slots, 4 versions) | present or not, the time of the release (young, after the snapshot, at the limit of each), yanked |
# | 3 to 5 | 16 bits for each of the 12 releases | the fact: its kind (right, wrong, app), a platform (the one slot, none, one that is no value), and one dep (a group of a slot, a transitive group, a version above all values) |
# | 6 | 2 conflicts of 25 bits | a conflict of 1 to 3 terms, each with a slot (3 is a name that is no slot), a set of versions and `In` or `NotIn` |
#
# The 4 versions of a slot are `1.0.0`, `1.9.0`, `1.10.0` and `2.0.0` (the order of a semver is not the order of the text). A release with a fact entry of a fit kind has no platform and no dep.

Raw : { a : U64, b : U64 }

generator : Fuzz.Generator(Raw)
generator = { a: Fuzz.u64, b: Fuzz.u64 }.Fuzz

Words : { w0 : U64, w1 : U64, w2 : U64, w3 : U64, w4 : U64, w5 : U64, w6 : U64 }

# splitmix64: the same input always gives the same 7 words, and a change of one bit of the input changes all words.
mix : U64 -> U64
mix = |x| {
	z1 = U64.times_wrap(U64.bitwise_xor(x, x // (2.U64).pow(30)), 0xBF58476D1CE4E5B9)
	z2 = U64.times_wrap(U64.bitwise_xor(z1, z1 // (2.U64).pow(27)), 0x94D049BB133111EB)
	U64.bitwise_xor(z2, z2 // (2.U64).pow(31))
}

draw : Raw, U64 -> U64
draw = |raw, k| mix(U64.plus_wrap(U64.bitwise_xor(raw.a, mix(raw.b)), U64.times_wrap(k + 1, 0x9E3779B97F4A7C15)))

expand : Raw -> Words
expand = |raw| { w0: draw(raw, 0), w1: draw(raw, 1), w2: draw(raw, 2), w3: draw(raw, 3), w4: draw(raw, 4), w5: draw(raw, 5), w6: draw(raw, 6) }

# The bits of a word: `width` bits from the bit `shift`.
field : U64, U64, U64 -> U64
field = |word, shift, width| (word // (2.U64).pow(shift)) % (2.U64).pow(width)

# The world, as numbers. A release is the slot `s` and the version number `v` (an index in `versions`).
Cell : { s : U64, v : U64, born : U64, yank : Bool }

Fact : { kind : [Package, Platform, App], pf : Try(Str, [None]), deps : List((U64, U64)) }

Term : { s : U64, ids : List(Str), sign : [In, NotIn] }

Model : {
	n : U64,
	kinds : List([Package, Platform]),
	cells : List(Cell),
	ranges : List({ s : U64, lo : U64, hi : U64 }),
	curs : List({ s : U64, v : U64 }),
	low : Bool,
	snap : Bool,
	facts : List((Str, Fact)),
	conflicts : List(List(Term)),
	known_bits : U64,
}

versions : List(Str)
versions = ["1.0.0", "1.9.0", "1.10.0", "2.0.0", "3.0.0"]

ver_of : U64 -> Str
ver_of = |v| versions.get(v) ?? "9.9.9"

id_of : U64, U64 -> Str
id_of = |s, v| "s${s.to_str()}-${ver_of(v)}"

# The numbers of the world from the 7 words (the table above).
model_of : Words -> Model
model_of = |raw| {
	n = field(raw.w0, 0, 2) % 3 + 1
	slots = List.repeat(0, n).map_with_index(|_, s| s)
	kinds = slots.map(|s| if field(raw.w0, 2, 2) == s Platform else Package)
	cells = List.repeat(0, 12).map_with_index(|_, c| c).keep_oks(
		|c| {
			x = if c < 9 field(raw.w1, 7 * c, 7) else field(raw.w2, 7 * (c - 9), 7)
			born = field(x, 2, 3)
			if c // 4 < n and x % 4 != 0 {
				Ok({ s: c // 4, v: c % 4, born: if born > 4 0 else born, yank: field(x, 5, 2) == 0 })
			} else {
				Err(NoCell)
			}
		},
	)
	ranges = slots.keep_oks(
		|s| {
			x = field(raw.w0, 39 + 8 * s, 8)
			if x % 4 == 0 Ok({ s, lo: field(x, 2, 3) % 4, hi: field(x, 5, 3) % 5 }) else Err(NoRange)
		},
	)
	curs = slots.keep_oks(
		|s| {
			x = field(raw.w0, 27 + 4 * s, 4)
			if x % 2 == 1 Ok({ s, v: field(x, 1, 3) % 4 }) else Err(NoCur)
		},
	)
	base = {
		n,
		kinds,
		cells,
		ranges,
		curs,
		low: field(raw.w0, 8, 1) == 1,
		snap: field(raw.w0, 9, 2) == 0,
		facts: [],
		conflicts: conflicts_of(raw),
		known_bits: field(raw.w0, 11, 16),
	}
	{ ..base, facts: universe(base).map(|(id, s, v)| (id, fact_of(raw, base, s, v))) }
}

# Up to 2 conflicts in word 6: 25 bits each. A conflict is there when its 2 first bits are 0. It has 1 to 3 terms of 7 bits: the slot (3 is no slot), a set of the versions 1.0.0 to 1.10.0 and 2.0.0 (4 bits), `In` or `NotIn`.
conflicts_of : Words -> List(List(Term))
conflicts_of = |raw| [0, 1].keep_oks(
	|k| {
		x = field(raw.w6, 25 * k, 25)
		if x % 4 == 0 {
			count = field(x, 2, 2) % 3 + 1
			Ok(List.repeat(0, count).map_with_index(|_, t| term_of(field(x, 4 + 7 * t, 7))))
		} else {
			Err(NoConflict)
		}
	},
)

term_of : U64 -> Term
term_of = |x| {
	s = field(x, 0, 2)
	{ s, ids: [0, 1, 2, 3].keep_if(|b| field(x, 2 + b, 1) == 1).map(|b| id_of(s, b)), sign: if field(x, 6, 1) == 0 In else NotIn }
}

# Each release of each slot: the listed ones in the order of the slot, then the header value when the list has no such release.
universe : Model -> List((Str, U64, U64))
universe = |m| List.repeat(0, m.n).map_with_index(|_, s| s).join_map(
	|s| {
		listed = m.cells.keep_if(|c| c.s == s).map(|c| (id_of(s, c.v), s, c.v))
		match m.curs.find_first(|c| c.s == s) {
			Ok(c) => if listed.any(|(_, _, v)| v == c.v) listed else listed.append((id_of(s, c.v), s, c.v))
			Err(_) => listed
		}
	},
)

own_kind : Model, U64 -> [Package, Platform]
own_kind = |m, s| m.kinds.get(s) ?? Package

fit_kind : Model, U64 -> [Package, Platform, App]
fit_kind = |m, s| if (m.kinds.get(s) ?? Package) == Platform Platform else Package

platform_slot : Model -> U64
platform_slot = |m| m.kinds.find_first_index(|k| k == Platform) ?? 0

# The fact of the release (slot `s`, version `v`) from the 16 bits of its place in words 3 to 5: the kind (4 bits: 0 a platform, 1 a package, 2 an app, else the kind of the slot), the platform (3 bits: 0 the platform slot,
# with the version of the next 2 bits, 1 a platform that is no value, else none; a release of the platform slot has none), and a dep (2 bits, 0 for a dep: a group of 2 bits, 3 is a group that no slot has, and a version of 3 bits, 4 and above are the version 3.0.0).
fact_of : Words, Model, U64, U64 -> Fact
fact_of = |raw, m, s, v| {
	c = s * 4 + v
	word = if c < 4 raw.w3 else if c < 8 raw.w4 else raw.w5
	x = field(word, 16 * (c % 4), 16)
	kind_bits = field(x, 0, 4)
	kind = if kind_bits == 0 Platform else if kind_bits == 1 Package else if kind_bits == 2 App else fit_kind(m, s)
	pf_bits = field(x, 4, 3)
	pf_v = field(x, 7, 2)
	pf = if own_kind(m, s) == Platform Err(None) else if pf_bits == 0 Ok(id_of(platform_slot(m), pf_v)) else if pf_bits == 1 Ok("s9-${ver_of(pf_v)}") else Err(None)
	deps = if field(x, 9, 2) == 0 [(if field(x, 11, 2) == 3 99 else field(x, 11, 2), field(x, 13, 3) % 5)] else []
	{ kind, pf, deps }
}

# The request for the solver, with the facts of the given releases (the others are not known).
request_of : Model, List(Str) -> Solver.Request
request_of = |m, known| {
	slots = List.repeat(0, m.n).map_with_index(|_, s| s).map(
		|s| {
			cur = m.curs.find_first(|c| c.s == s)
			{
				name: "s${s.to_str()}",
				group: "g${s.to_str()}",
				kind: m.kinds.get(s) ?? Package,
				candidates: m.cells.keep_if(|c| c.s == s).map(|c| cell_candidate(c)),
				ranges: m.ranges.keep_if(|r| r.s == s).map(|r| ">=${ver_of(r.lo)}, <${if r.hi == 4 "99.0.0" else ver_of(r.hi)}"),
				current: match cur {
					Ok(c) => Ok({ id: id_of(s, c.v), version: ver_of(c.v) })
					Err(_) => Err(None)
				},
				named: Err(None),
			}
		},
	)
	{
		slots,
		rules: { now: 1000, min_age: 100, snapshot: if m.snap Ok(500) else Err(None), strategy: if m.low Lowest else Highest },
		facts: m.facts.keep_if(|(id, _)| known.contains(id)).map(|(id, f)| solver_fact(id, f)),
		conflicts: m.conflicts.map(|c| c.map(|t| { name: "s${t.s.to_str()}", ids: t.ids, sign: t.sign })),
	}
}

# The time of a release: 0 old, 1 young (950, with `min-release-age` 100 at the time 1000), 2 600, 3 exactly old enough (900), 4 exactly at the snapshot time (500).
cell_candidate : Cell -> { id : Str, version : Str, published_at : U64, yanked : Bool }
cell_candidate = |c| {
	published_at = if c.born == 1 950 else if c.born == 2 600 else if c.born == 3 900 else if c.born == 4 500 else 0
	{ id: id_of(c.s, c.v), version: ver_of(c.v), published_at, yanked: c.yank }
}

solver_fact : Str, Fact -> Solver.Fact
solver_fact = |id, f| { id, kind: f.kind, pf: f.pf, deps: f.deps.map(|(g, v)| { group: if g == 99 "t" else "g${g.to_str()}", version: ver_of(v) }) }

# The oracle. R-C1, R-C6, R-C7, R-C9: the domain of a slot, best first, from the numbers (young: published at 950 with `min-release-age` 100 at the time 1000, late: published after the snapshot 500).
Cd : { id : Str, v : U64 }

domain : Model, U64 -> List(Cd)
domain = |m, s| {
	cur = m.curs.find_first(|c| c.s == s)
	listed = m.cells.keep_if(|c| c.s == s)
	all = match cur {
		Ok(c) => if listed.any(|x| x.v == c.v) listed else listed.append({ s, v: c.v, born: 0, yank: Bool.False })
		Err(_) => listed
	}
	ranges = m.ranges.keep_if(|r| r.s == s)
	kept = all.keep_if(
		|c| {
			in_ranges = ranges.all(|r| r.lo <= c.v and c.v < r.hi)
			is_cur = match cur {
				Ok(x) => x.v == c.v
				Err(_) => Bool.False
			}
			young = c.born == 1
			late = m.snap and c.born >= 1 and c.born <= 3
			in_ranges and (is_cur or (!c.yank and !young and !late))
		},
	)
	ordered = kept.sort_with(|a, b| if a.v == b.v Same else if (a.v < b.v) == m.low Before else After)
	ordered.map(|c| { id: id_of(s, c.v), v: c.v })
}

fact_at : Model, List(Str), Str -> Try(Fact, [None])
fact_at = |m, known, id| if known.contains(id) {
	match m.facts.find_first(|(x, _)| x == id) {
		Ok((_, f)) => Ok(f)
		Err(_) => Err(None)
	}
} else {
	Err(None)
}

# R-C4: no fact is fit. A fact has to give the kind of the slot.
kind_fits : Model, List(Str), U64, Cd -> Bool
kind_fits = |m, known, s, c| match fact_at(m, known, c.id) {
	Ok(f) => match (f.kind, m.kinds.get(s) ?? Package) {
		(Package, Package) => Bool.True
		(Platform, Platform) => Bool.True
		_ => Bool.False
	}
	Err(_) => Bool.True
}

# R-C2, R-C3 and the conflicts of the caller, for a whole tuple (one `Cd` for each slot, in the order of the slots).
valid : Model, List(Str), List(Cd) -> Bool
valid = |m, known, tuple| {
	plats = m.kinds.map_with_index(|k, i| (k, i)).keep_if(|(k, _)| k == Platform).map(|(_, i)| i)
	each_ok = tuple.map_with_index(
		|c, i| match fact_at(m, known, c.id) {
			Err(_) => Bool.True
			Ok(f) => {
				pf_ok = match (f.pf, plats) {
					(Ok(url), [p]) => i == p or (tuple.get(p) ?? c).id == url
					_ => Bool.True
				}
				deps_ok = f.deps.all(|(g, v)| g >= m.n or g == i or (tuple.get(g) ?? c).v >= v)
				pf_ok and deps_ok
			}
		},
	)
	broken = m.conflicts.any(
		|terms| !terms.any(|t| t.s >= m.n) and terms.all(
			|t| {
				chosen = (tuple.get(t.s) ?? { id: "", v: 0 }).id
				if t.sign == In t.ids.contains(chosen) else !t.ids.contains(chosen)
			},
		),
	)
	each_ok.all(|ok| ok) and !broken
}

# The best tuple: the first valid one when the values of the first slot, then the second, and so on, are tried in the order of the domains.
best : Model, List(Str) -> Try(List(Cd), [None])
best = |m, known| {
	doms = List.repeat(0, m.n).map_with_index(|_, s| s).map(|s| domain(m, s).keep_if(|c| kind_fits(m, known, s, c)))
	first_tuple(m, known, doms, [])
}

first_tuple : Model, List(Str), List(List(Cd)), List(Cd) -> Try(List(Cd), [None])
first_tuple = |m, known, rest, chosen| match rest {
	[] => if valid(m, known, chosen) Ok(chosen) else Err(None)
	[d, .. as more] => {
		var $found = Err(None)
		for c in d {
			match $found {
				Ok(_) => {}
				Err(_) => {
					$found = first_tuple(m, known, more, chosen.append(c))
				}
			}
		}
		$found
	}
}

# The text of a step, and of the oracle for the same facts.
show : [Need(List(Solver.Ask)), Done(List(Solver.Chosen)), Fail(Solver.Why)] -> Str
show = |r| match r {
	Need(asks) => "need ${Str.join_with(asks.map(ask_id), " ")}"
	Done(chosen) => "done ${Str.join_with(chosen.map(|c| "${c.name}=${c.version}"), " ")}"
	Fail(_) => "fail"
}

ask_id : Solver.Ask -> Str
ask_id = |a| match a {
	Header(id) => id
}

expected : Model, List(Str) -> Str
expected = |m, known| match best(m, known) {
	Err(_) => "fail"
	Ok(tuple) => {
		missing = tuple.keep_if(|c| !known.contains(c.id))
		if missing.is_empty() {
			"done ${Str.join_with(tuple.map_with_index(|c, i| "s${i.to_str()}=${ver_of(c.v)}"), " ")}"
		} else {
			"need ${Str.join_with(missing.map(|c| c.id), " ")}"
		}
	}
}

flipped : Solver.Request -> Solver.Request
flipped = |r| { ..r, slots: r.slots.map(|s| { ..s, candidates: s.candidates.rev() }), facts: r.facts.rev(), conflicts: r.conflicts.rev().map(|c| c.rev()) }

# The loop of a command: step, give the facts of the releases that it asks for (the world has one for each release of the universe), step again. `Err` is the text of a broken property.
drive : Model, Solver.Request, List(Str), U64 -> Try(Str, Str)
drive = |m, r, allowed, left| if left == 0 {
	Err("R-AL8: the loop does not end")
} else {
	match Solver.step(r) {
		Need(asks) => {
			ids = asks.map(ask_id)
			if ids.is_empty() {
				Err("R-AL8: a need with no release")
			} else if ids.any(|id| r.facts.any(|f| f.id == id)) {
				Err("R-AL8: a need for a release that is known")
			} else if ids.any(|id| ids.count_if(|x| x == id) > 1) {
				Err("R-AL8: a need that names a release twice")
			} else if ids.any(|id| !allowed.contains(id)) {
				Err("R-AL9: a need for a release that no domain has")
			} else {
				drive(m, { ..r, facts: r.facts.concat(m.facts.keep_if(|(id, _)| ids.contains(id)).map(|(id, f)| solver_fact(id, f))) }, allowed, left - 1)
			}
		}
		other => Ok(show(other))
	}
}

test : Raw -> Fuzz.Outcome
test = |raw| {
	m = model_of(expand(raw))
	all_ids = m.facts.map(|(id, _)| id)
	known = all_ids.map_with_index(|id, i| (id, field(m.known_bits, i % 16, 1) == 1)).keep_if(|(_, k)| k).map(|(id, _)| id)
	part = request_of(m, known)
	got = show(Solver.step(part))
	if got != expected(m, known) {
		crash "R-VA6 R-AL3 R-AL8 R-C1 R-C2 R-C3 R-C4 R-C6 R-C7 R-C9: the step differs from the oracle for the same facts. Got ${got}. Want ${expected(m, known)}"
	} else if show(Solver.step(flipped(part))) != got {
		crash "R-DT2: the order of the candidates, the facts or the conflicts changed the step"
	} else {
		allowed = List.repeat(0, m.n).map_with_index(|_, s| s).join_map(|s| domain(m, s).map(|c| c.id))
		start = request_of(m, [])
		want = expected(m, all_ids)
		match drive(m, start, allowed, all_ids.len() + 1) {
			Err(why) => crash why
			Ok(end) => if end != want {
				crash "R-VA6 R-AL3 R-AL8: the loop ends with ${end}, the oracle for all facts has ${want}"
			} else {
				match drive(m, flipped(start), allowed, all_ids.len() + 1) {
					Err(why) => crash why
					Ok(end2) => if end2 != end crash "R-DT2: the order of the lists changed the end of the loop" else Fuzz.keep
				}
			}
		}
	}
}

target = Fuzz.target_with({
	name: "pubgrub",
	generator,
	test,
	show: |raw| Str.inspect(raw),
})
