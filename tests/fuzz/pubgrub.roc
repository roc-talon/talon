app [target] {
	fuzz: platform "https://github.com/lukewilliamboswell/roc-fuzz/releases/download/0.4.3/41NK5FShyGC9Z8HNpUdUeXMWwLmLNfFxsfmLvdPL4Fxb.tar.zst",
	resolve: "../../packages/resolve/main.roc",
}

import fuzz.Fuzz
import resolve.Solver

# l1-runs: 8000
# L1 target of slices 034 and 035 (TESTING.md 4, the `pubgrub` row): random small problems against a brute-force search of all tuples. The oracle is written here from the rule text of Resolution 1, 2, 4 and 5
# (integers and index loops, no set of values, no propagation, no conflict resolution), not from the code of `packages/resolve`. One run checks these properties of one input. The first words of a crash text are the rule ids.
#
# | Property | Rule |
# | --- | --- |
# | A step with a random part of the facts equals the oracle with the same facts: `Fail` when no tuple exists, else the best tuple by `priority`, and `Need` (the header facts of the tuple that have none, in the order of the slots, else the probes of the pairs with no real fact) or `Done`. The oracle has the rules of `Allowed` (the best tuple A with all facts, the best tuple B with real facts only) and of `Off` | R-VA6 R-AL3 R-AL8 R-AL5 R-EP7 R-EP8 R-EP9 R-C1 R-C2 R-C3 R-C4 R-C6 R-C7 R-C9 |
# | The loop of a command (step, give the facts that it asks for, step) ends with the oracle result for all facts, in at most one round for each header and each pair. A need is never empty, never repeats an ask, asks for no known header, no pair with a real fact, and no release or compiler that a domain does not have. With `Off` there is no probe | R-AL8 R-AL9 R-AL4 R-EP8 R-EP9 R-VA6 |
# | A `Fail` has an explanation that is a proof (the last step has no term, a `Derived` names 2 earlier steps, and each step follows from its leaves for all tuples), and each leaf is a real reason: a conflict of the caller, a fact, a slot with no value, or a probe interval (a run of D with a fail that touches, a fault alone, the inferred compilers named, the run maximal, the used modules). With `Allowed` a leaf has real facts only | R-EP7 R-EP8 R-EP9 R-AL5 |
# | The lists of the request in another order (the candidates, the facts, the conflicts and their terms, the checks, the used modules) give the same step, with the same explanation | R-DT2 |
#
# The input is 2 numbers of 64 bits (16 bytes). A mixing function (splitmix64) makes 14 words of 64 bits from them. So each input is a full random problem, with no byte of the input unused and no zero padding. A list of random length
# would need hundreds of bytes, and libFuzzer grows its inputs slowly (the first thousands of inputs are short: with 20000 runs that gave few problems with a dep or a conflict, `research/slice-034-revert/mutate2.log`). The bits of the words make the world:
#
# | Word | Bits | Use |
# | --- | --- | --- |
# | 0 | bits 0 and 1, 2 and 3, 8, 9 and 10, 11 to 26, 27 to 38, 39 to 62 | the count of slots (1 to 3), the platform slot (the number of a slot, or 3 for none: so at most one platform slot), the strategy, the snapshot, the known facts (one bit for each release of the world), a header value for each slot, a range for each slot |
# | 1, 2 | 7 bits for each of the 12 releases (3 slots, 4 versions) | present or not, the time of the release (young, after the snapshot, at the limit of each), yanked |
# | 3 to 5 | 16 bits for each of the 12 releases | the fact: its kind (right, wrong, app), a platform (the one slot, none, one that is no value), and one dep (a group of a slot, a transitive group, a version above all values) |
# | 6, 13 | 3 conflicts of 25 bits (the third from the bit 34 of the word 13) | a conflict of 1 to 3 terms, each with a slot (3 is the compiler `roc`, or no slot), a set of versions or of compilers and `In` or `NotIn` |
# | 7 to 12 | 6 bits for each of the 60 pairs (12 releases, 5 compilers), 10 pairs for each word (the bits 60 to 63 of the word 12 choose which checks run, see `verdict`) | the check: none (10 of 16), a pass, a fail of the module Yaml, of the module Other, of both, of no module, a hang or a crash, real or inferred (a fault is always real) |
# | 13 | bit 0, bits 1 and 2, bits 3 to 7, bits 8 and 9, bits 10 to 33, bits 34 to 58 (the bits 59 to 63 choose which checks run) | a compiler slot, its place in the order of the slots, which of the 5 compilers are candidates, `Off` (1 of 4), the modules that the app uses in each release (Yaml, Other), the third conflict |
#
# The 4 versions of a slot are `1.0.0`, `1.9.0`, `1.10.0` and `2.0.0` (the order of a semver is not the order of the text). A release with a fact entry of a fit kind has no platform and no dep. The compilers are `c0` to `c4`, and D is that order.

Raw : { a : U64, b : U64 }

generator : Fuzz.Generator(Raw)
generator = { a: Fuzz.u64, b: Fuzz.u64 }.Fuzz

Words : { w0 : U64, w1 : U64, w2 : U64, w3 : U64, w4 : U64, w5 : U64, w6 : U64, w7 : U64, w8 : U64, w9 : U64, w10 : U64, w11 : U64, w12 : U64, w13 : U64 }

# splitmix64: the same input always gives the same 14 words, and a change of one bit of the input changes all words.
mix : U64 -> U64
mix = |x| {
	z1 = U64.times_wrap(U64.bitwise_xor(x, x // (2.U64).pow(30)), 0xBF58476D1CE4E5B9)
	z2 = U64.times_wrap(U64.bitwise_xor(z1, z1 // (2.U64).pow(27)), 0x94D049BB133111EB)
	U64.bitwise_xor(z2, z2 // (2.U64).pow(31))
}

draw : Raw, U64 -> U64
draw = |raw, k| mix(U64.plus_wrap(U64.bitwise_xor(raw.a, mix(raw.b)), U64.times_wrap(k + 1, 0x9E3779B97F4A7C15)))

expand : Raw -> Words
expand = |raw| { w0: draw(raw, 0), w1: draw(raw, 1), w2: draw(raw, 2), w3: draw(raw, 3), w4: draw(raw, 4), w5: draw(raw, 5), w6: draw(raw, 6), w7: draw(raw, 7), w8: draw(raw, 8), w9: draw(raw, 9), w10: draw(raw, 10), w11: draw(raw, 11), w12: draw(raw, 12), w13: draw(raw, 13) }

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
	has_roc : Bool,
	rpos : U64,
	rcands : List(U64),
	checks : List(Solver.Check),
	uses : List({ id : Str, modules : List(Str) }),
	off : Bool,
}

versions : List(Str)
versions = ["1.0.0", "1.9.0", "1.10.0", "2.0.0", "3.0.0"]

ver_of : U64 -> Str
ver_of = |v| versions.get(v) ?? "9.9.9"

id_of : U64, U64 -> Str
id_of = |s, v| "s${s.to_str()}-${ver_of(v)}"

# D: the compilers, the oldest first.
nightly : U64 -> Str
nightly = |c| "c${c.to_str()}"

d : List(Str)
d = [0, 1, 2, 3, 4].map(nightly)

# The numbers of the world from the 14 words (the table above).
model_of : Words -> Model
model_of = |raw| {
	n = field(raw.w0, 0, 2) % 3 + 1
	slots = List.repeat(0, n).map_with_index(|_, s| s)
	kinds = slots.map(|s| if field(raw.w0, 2, 2) == s Platform else Package)
	cells = List.repeat(0, 12).map_with_index(|_, c| c).keep_oks(
		|c| {
			x = if c < 9 field(raw.w1, 7 * c, 7) else field(raw.w2, 7 * (c - 9), 7)
			born = field(x, 2, 3)
			if c // 4 < n and (x % 4 != 0 or field(x, 5, 1) == 1) {
				Ok({ s: c // 4, v: c % 4, born: if born > 4 0 else born, yank: field(x, 5, 2) == 0 and field(x, 1, 1) == 0 })
			} else {
				Err(NoCell)
			}
		},
	)
	ranges = slots.keep_oks(
		|s| {
			x = field(raw.w0, 39 + 8 * s, 8)
			if x % 4 == 0 Ok({ s, lo: field(x, 2, 3) % 3, hi: U64.min(field(x, 2, 3) % 3 + 1 + field(x, 5, 3) % 4, 4) }) else Err(NoRange)
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
		has_roc: field(raw.w13, 0, 1) == 1,
		rpos: field(raw.w13, 1, 2) % (n + 1),
		rcands: [0, 1, 2, 3, 4].keep_if(|c| field(raw.w13, 3 + c, 1) == 1),
		checks: [],
		uses: [],
		off: field(raw.w13, 8, 2) == 0,
	}
	with_facts = { ..base, facts: universe(base).map(|(id, s, v)| (id, fact_of(raw, base, s, v))) }
	{ ..with_facts, checks: checks_of(raw), uses: uses_of(raw) }
}

# The check of the pair (release u, compiler c): 6 bits, 10 pairs for each of the words 7 to 12. The code (4 bits): 0 to 9 none, 10 a pass, 11 a fail in the module Yaml, 12 a fail in the module Other, 13 a fail with no module, 15 a fail in both modules, 14 a hang or a crash (bit 5: 0 a hang, 1 a crash).
# Bit 4: an inferred fact (a hang and a crash are always real). The id is `id_of(u // 4, u % 4)` and the compiler is `c` of the place.
checks_of : Words -> List(Solver.Check)
checks_of = |raw| List.repeat(0, 60).map_with_index(|_, k| k).keep_oks(
	|k| {
		word = match k // 10 {
			0 => raw.w7
			1 => raw.w8
			2 => raw.w9
			3 => raw.w10
			4 => raw.w11
			_ => raw.w12
		}
		x = field(word, 6 * (k % 10), 6)
		code = field(x, 0, 4)
		source = if field(x, 4, 1) == 1 Inferred else Real
		id = id_of(k // 5 // 4, k // 5 % 4)
		at = nightly(k % 5)
		if code < 10 {
			Err(NoCheck)
		} else if code == 10 {
			Ok({ id, nightly: at, outcome: Pass, modules: [], source })
		} else if code == 15 {
			Ok({ id, nightly: at, outcome: Fail, modules: ["Other", "Yaml"], source })
		} else if code == 11 {
			Ok({ id, nightly: at, outcome: Fail, modules: ["Yaml"], source })
		} else if code == 12 {
			Ok({ id, nightly: at, outcome: Fail, modules: ["Other"], source })
		} else if code == 13 {
			Ok({ id, nightly: at, outcome: Fail, modules: [], source })
		} else {
			Ok({ id, nightly: at, outcome: if field(x, 5, 1) == 0 Hang else Crash, modules: [], source: Real })
		}
	},
)

# The modules that the app uses in each of the 12 releases: 2 bits (Yaml, Other) each, from the bit 10 of the word 13.
uses_of : Words -> List({ id : Str, modules : List(Str) })
uses_of = |raw| List.repeat(0, 12).map_with_index(|_, u| u).map(
	|u| {
		x = field(raw.w13, 10 + 2 * u, 2)
		{ id: id_of(u // 4, u % 4), modules: (if x % 2 == 1 ["Yaml"] else []).concat(if x // 2 == 1 ["Other"] else []) }
	},
)

# Up to 3 conflicts: 25 bits each, 2 in word 6 and 1 from the bit 34 of word 13. A conflict is there when its 2 first bits are 0. It has 1 to 3 terms of 7 bits: the slot (3 is the compiler, or no slot), a set of the versions 1.0.0 to 1.10.0 and 2.0.0 (4 bits), `In` or `NotIn`.
conflicts_of : Words -> List(List(Term))
conflicts_of = |raw| [field(raw.w6, 0, 25), field(raw.w6, 25, 25), field(raw.w13, 34, 25)].keep_oks(
	|x| if x % 4 == 0 {
		count = field(x, 2, 2) % 3 + 1
		Ok(List.repeat(0, count).map_with_index(|_, t| term_of(field(x, 4 + 7 * t, 7))))
	} else {
		Err(NoConflict)
	},
)

term_of : U64 -> Term
term_of = |x| {
	s = field(x, 0, 2)
	bits = [0, 1, 2, 3].keep_if(|b| field(x, 2 + b, 1) == 1)
	{ s, ids: if s == 3 bits.map(nightly) else bits.map(|b| id_of(s, b)), sign: if field(x, 6, 1) == 0 In else NotIn }
}

# The order of the slots: the slots of the packages 0 to n-1 and the compiler (99) at the place `rpos`.
order : Model -> List(U64)
order = |m| {
	pkgs = List.repeat(0, m.n).map_with_index(|_, s| s)
	if m.has_roc pkgs.take_first(m.rpos).append(99).concat(pkgs.drop_first(m.rpos)) else pkgs
}

name_of : U64 -> Str
name_of = |k| if k == 99 "roc" else "s${k.to_str()}"

names : Model -> List(Str)
names = |m| order(m).map(name_of)

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

# The request for the solver, with the facts of the given releases (the others are not known). The checks, the used modules and D are always there.
request_of : Model, List(Str) -> Solver.Request
request_of = |m, known| {
	pkg_slot = |s| {
		cur = m.curs.find_first(|c| c.s == s)
		{
			name: "s${s.to_str()}",
			group: "g${s.to_str()}",
			kind: match own_kind(m, s) {
				Package => Package
				Platform => Platform
			},
			candidates: m.cells.keep_if(|c| c.s == s).map(|c| cell_candidate(c)),
			ranges: m.ranges.keep_if(|r| r.s == s).map(|r| ">=${ver_of(r.lo)}, <${if r.hi == 4 "99.0.0" else ver_of(r.hi)}"),
			current: match cur {
				Ok(c) => Ok({ id: id_of(s, c.v), version: ver_of(c.v) })
				Err(_) => Err(None)
			},
			named: Err(None),
		}
	}
	roc_slot = {
		name: "roc",
		group: "roc",
		kind: Compiler,
		candidates: m.rcands.map(|c| { id: nightly(c), version: nightly(c), published_at: 0, yanked: Bool.False }),
		ranges: [],
		current: Err(None),
		named: Err(None),
	}
	{
		slots: order(m).map(|k| if k == 99 roc_slot else pkg_slot(k)),
		rules: { now: 1000, min_age: 100, snapshot: if m.snap Ok(500) else Err(None), strategy: if m.low Lowest else Highest },
		facts: m.facts.keep_if(|(id, _)| known.contains(id)).map(|(id, f)| solver_fact(id, f)),
		conflicts: m.conflicts.map(|c| c.map(|t| { name: if t.s == 3 and m.has_roc "roc" else "s${t.s.to_str()}", ids: t.ids, sign: t.sign })),
		compat: { domain: d, checks: m.checks, used: m.uses, probes: if m.off Off else Allowed },
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

# The compilers that are candidates, in the order of D: the newest first (`Highest`) or the oldest first.
roc_domain : Model -> List(Cd)
roc_domain = |m| {
	asc = m.rcands.map(|c| { id: nightly(c), v: c })
	if m.low asc else asc.rev()
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

# The values of each slot, in the order of the slots.
doms_of : Model, List(Str) -> List(List(Cd))
doms_of = |m, known| order(m).map(|k| if k == 99 roc_domain(m) else domain(m, k).keep_if(|c| kind_fits(m, known, k, c)))

# R-EP7, R-UM1: a fail of the pair (release, compiler) that touches (no module, or a module that the app uses). `All`: real or inferred. `Real`: real only.
fail_blocks : Model, [All, Real], Str, Str -> Bool
fail_blocks = |m, mode, id, at| {
	used = m.uses.find_first(|u| u.id == id).map_ok(|u| u.modules) ?? []
	match m.checks.find_first(|c| c.id == id and c.nightly == at) {
		Err(_) => Bool.False
		Ok(c) => c.outcome == Fail and (c.modules.is_empty() or c.modules.any(|x| used.contains(x))) and (mode == All or c.source == Real)
	}
}

# A real hang or crash of the pair (a fault, R-EP5).
fault_at : Model, Str, Str -> Bool
fault_at = |m, id, at| match m.checks.find_first(|c| c.id == id and c.nightly == at) {
	Err(_) => Bool.False
	Ok(c) => (c.outcome == Hang or c.outcome == Crash) and c.source == Real
}

# The pair is excluded by a check: a fail that touches, or a fault.
blocked : Model, [All, Real], Str, Str -> Bool
blocked = |m, mode, id, at| fail_blocks(m, mode, id, at) or fault_at(m, id, at)

# R-C2, R-C3, R-EP7 and the conflicts of the caller, for a whole tuple (one `Cd` for each slot, in the order of the slots).
valid : Model, List(Str), [All, Real], List(Cd) -> Bool
valid = |m, known, mode, tuple| {
	ord = order(m)
	plats = ord.map_with_index(|k, i| (k, i)).keep_if(|(k, _)| k != 99 and own_kind(m, k) == Platform).map(|(_, i)| i)
	at_of = |k| ord.find_first_index(|x| x == k) ?? 0
	roc_at = (tuple.get(at_of(99)) ?? { id: "", v: 0 }).id
	each_ok = tuple.map_with_index(
		|c, i| match ord.get(i) ?? 0 {
			99 => Bool.True
			_ => {
				probe_ok = !(m.has_roc and blocked(m, mode, c.id, roc_at))
				fact_ok = match fact_at(m, known, c.id) {
					Err(_) => Bool.True
					Ok(f) => {
						pf_ok = match (f.pf, plats) {
							(Ok(url), [p]) => i == p or (tuple.get(p) ?? c).id == url
							_ => Bool.True
						}
						deps_ok = f.deps.all(|(g, v)| g >= m.n or at_of(g) == i or (tuple.get(at_of(g)) ?? c).v >= v)
						pf_ok and deps_ok
					}
				}
				probe_ok and fact_ok
			}
		},
	)
	nm = names(m)
	broken = m.conflicts.any(
		|terms| {
			tn = |t| if t.s == 3 and m.has_roc "roc" else "s${t.s.to_str()}"
			terms.all(|t| nm.contains(tn(t))) and terms.all(
				|t| {
					chosen = (tuple.get(nm.find_first_index(|x| x == tn(t)) ?? 0) ?? { id: "", v: 0 }).id
					if t.sign == In t.ids.contains(chosen) else !t.ids.contains(chosen)
				},
			)
		},
	)
	each_ok.all(|ok| ok) and !broken
}

# The best tuple: the first valid one when the values of the first slot, then the second, and so on, are tried in the order of the domains.
best : Model, List(Str), [All, Real] -> Try(List(Cd), [None])
best = |m, known, mode| first_tuple(m, known, mode, doms_of(m, known), [])

first_tuple : Model, List(Str), [All, Real], List(List(Cd)), List(Cd) -> Try(List(Cd), [None])
first_tuple = |m, known, mode, rest, chosen| match rest {
	[] => if valid(m, known, mode, chosen) Ok(chosen) else Err(None)
	[dom, .. as more] => {
		var $found = Err(None)
		for c in dom {
			match $found {
				Ok(_) => {}
				Err(_) => {
					$found = first_tuple(m, known, mode, more, chosen.append(c))
				}
			}
		}
		$found
	}
}

# The text of a step, and of the oracle for the same facts.
show : [Need(List(Solver.Ask)), Done(List(Solver.Chosen)), Fail(Solver.Why)] -> Str
show = |r| match r {
	Need(asks) => "need ${Str.join_with(asks.map(ask_text), " ")}"
	Done(chosen) => "done ${Str.join_with(chosen.map(|c| "${c.name}=${c.version}"), " ")}"
	Fail(_) => "fail"
}

ask_text : Solver.Ask -> Str
ask_text = |a| match a {
	Header(id) => id
	Probe(p) => "${p.id}@${p.nightly}"
}

dedupe : List(Str) -> List(Str)
dedupe = |list| list.fold([], |acc, x| if acc.contains(x) acc else acc.append(x))

# R-AL8, R-AL4: what the tuple lacks. The header facts first, each once, in the order of the slots. Else, with probes allowed, the pairs (release, compiler) with no real check, each once.
need_text : Model, List(Str), List(Cd) -> Str
need_text = |m, known, tuple| {
	ord = order(m)
	rel = tuple.map_with_index(|c, i| (c, i)).keep_if(|(_, i)| (ord.get(i) ?? 0) != 99).map(|(c, _)| c.id)
	headers = dedupe(rel.keep_if(|id| !known.contains(id)))
	roc_at = tuple.get(ord.find_first_index(|k| k == 99) ?? 0).map_ok(|c| c.id) ?? ""
	pairs = dedupe(rel.keep_if(|id| !m.checks.any(|c| c.id == id and c.nightly == roc_at and c.source == Real)))
	if !headers.is_empty() {
		"need ${Str.join_with(headers, " ")}"
	} else if m.off or !m.has_roc or pairs.is_empty() {
		"none"
	} else {
		"need ${Str.join_with(pairs.map(|id| "${id}@${roc_at}"), " ")}"
	}
}

tuple_text : Model, List(Cd) -> Str
tuple_text = |m, tuple| "done ${Str.join_with(tuple.map_with_index(|c, i| "${names(m).get(i) ?? ""}=${if (order(m).get(i) ?? 0) == 99 c.id else ver_of(c.v)}"), " ")}"

# R-EP8, R-EP9: the step of `Allowed` has the best tuple A with all facts (real and inferred) and the best tuple B with the real facts only. No B: `Fail`. A lacks a fact: the need of A. A has all facts and B is A: `Done`. Else the need of B.
# `Off`: A only, with no probe (a header fact is still asked for).
expected : Model, List(Str) -> Str
expected = |m, known| {
	a = best(m, known, All)
	b = best(m, known, Real)
	if m.off {
		match a {
			Err(_) => "fail"
			Ok(ta) => if need_text(m, known, ta) == "none" tuple_text(m, ta) else need_text(m, known, ta)
		}
	} else {
		match b {
			Err(_) => "fail"
			Ok(tb) => match a {
				Err(_) => need_text(m, known, tb)
				Ok(ta) => if need_text(m, known, ta) != "none" need_text(m, known, ta) else if ta == tb tuple_text(m, ta) else need_text(m, known, tb)
			}
		}
	}
}

flipped : Solver.Request -> Solver.Request
flipped = |r| { ..r, slots: r.slots.map(|s| { ..s, candidates: s.candidates.rev() }), facts: r.facts.rev(), conflicts: r.conflicts.rev().map(|c| c.rev()), compat: { ..r.compat, checks: r.compat.checks.rev(), used: r.compat.used.rev() } }

# The loop of a command: step, give the facts of the asks (the world has the header of each release, and the result of each pair: its check as a real fact, or a pass), step again. `Err` is the text of a broken property.
drive : Model, Solver.Request, List(Str), U64 -> Try({ text : Str, last : Solver.Request }, Str)
drive = |m, r, allowed, left| if left == 0 {
	Err("R-AL8: the loop does not end")
} else {
	match Solver.step(r) {
		Need(asks) => {
			texts = asks.map(ask_text)
			if asks.is_empty() {
				Err("R-AL8: a need with no ask")
			} else if texts.any(|t| texts.count_if(|x| x == t) > 1) {
				Err("R-AL8: a need that names an ask twice")
			} else if asks.any(|a| bad_ask(m, r, allowed, a)) {
				Err("R-AL8 R-AL9 R-AL4 R-EP8: a need for a header that is known, a pair with a real check, a release or a compiler that no domain has, or a probe with `Off`: ${Str.join_with(texts, " ")}")
			} else {
				heads = asks.keep_oks(
					|a| match a {
						Header(id) => Ok(id)
						Probe(_) => Err(NotHeader)
					},
				)
				probes = asks.keep_oks(
					|a| match a {
						Probe(p) => Ok(p)
						Header(_) => Err(NotProbe)
					},
				)
				given = probes.map(|p| m.checks.find_first(|c| c.id == p.id and c.nightly == p.nightly).map_ok(|c| { ..c, source: Real }) ?? { id: p.id, nightly: p.nightly, outcome: Pass, modules: [], source: Real })
				kept = r.compat.checks.keep_if(|c| !probes.any(|p| p.id == c.id and p.nightly == c.nightly))
				drive(m, { ..r, facts: r.facts.concat(m.facts.keep_if(|(id, _)| heads.contains(id)).map(|(id, f)| solver_fact(id, f))), compat: { ..r.compat, checks: kept.concat(given) } }, allowed, left - 1)
			}
		}
		other => Ok({ text: show(other), last: r })
	}
}

bad_ask : Model, Solver.Request, List(Str), Solver.Ask -> Bool
bad_ask = |m, r, allowed, a| match a {
	Header(id) => r.facts.any(|f| f.id == id) or !allowed.contains(id)
	Probe(p) => m.off or !m.has_roc or !allowed.contains(p.id) or !m.rcands.map(nightly).contains(p.nightly) or r.compat.checks.any(|c| c.id == p.id and c.nightly == p.nightly and c.source == Real)
}

# ------------------------------------------------------------------------------------------------------------------------------------------
# The explanation of a `Fail`: a proof of real reasons (R-EP7, R-EP8, R-EP9). The tuples are all the tuples of the values (an id for each slot, in the order of the slots).

tuples : List(List(Str)) -> List(List(Str))
tuples = |doms| match doms {
	[] => [[]]
	[first, .. as rest] => first.join_map(|id| tuples(rest).map(|t| [id].concat(t)))
}

holds : List(Str), List(Str), Solver.Term -> Bool
holds = |nm, tuple, t| match nm.find_first_index(|n| n == t.name) {
	Ok(i) => match tuple.get(i) {
		Ok(id) => t.ids.contains(id) == (t.sign == In)
		Err(_) => Bool.False
	}
	Err(_) => Bool.False
}

all_true : List(Str), List(Str), List(Solver.Term) -> Bool
all_true = |nm, tuple, terms| terms.all(|t| holds(nm, tuple, t))

leaves_of : List(Solver.Step), U64 -> List(U64)
leaves_of = |steps, i| match steps.get(i) {
	Ok(s) => match s.cause {
		Derived(a, b) => if a < i and b < i leaves_of(steps, a).concat(leaves_of(steps, b)) else []
		_ => [i]
	}
	Err(_) => []
}

well_formed : List(Solver.Step) -> Bool
well_formed = |steps| match steps.last() {
	Ok(last) => last.terms.is_empty() and steps.map_with_index(|s, i| (s, i)).all(
		|(s, i)| match s.cause {
			Derived(a, b) => a < i and b < i
			_ => Bool.True
		},
	)
	Err(_) => Bool.False
}

# For each step, the numbers of the tuples where all its terms are true (a step follows from its leaves when each such tuple is excluded by a leaf of its cone).
sound : List(Solver.Step), List(List(U64)) -> Bool
sound = |steps, viols| steps.map_with_index(|_, i| i).all(
	|i| (viols.get(i) ?? []).all(|k| leaves_of(steps, i).any(|j| (viols.get(j) ?? []).contains(k))),
)

# The numbers of the tuples (the places in `all`) where the test holds. The tuples that a step excludes are the tuples where all its terms are true.
pick : List(List(Str)), (List(Str) -> Bool) -> List(U64)
pick = |all, test| all.map_with_index(|t, i| (t, i)).keep_if(|(t, _)| test(t)).map(|(_, i)| i)

# The version of a release id (`s2-1.9.0` is `1.9.0`), as a place in `versions`.
id_version : Str -> U64
id_version = |id| ver_index(id.split_on("-").last() ?? "")

# The tuples that the rule of a reason excludes, written from the rule text. `at` is the place of the release `id` in the tuple.
place_of : List(Str), Str -> Try(U64, [None])
place_of = |tuple, id| match tuple.find_first_index(|x| x == id) {
	Ok(i) => Ok(i)
	Err(_) => Err(None)
}

ver_index : Str -> U64
ver_index = |text| versions.find_first_index(|v| v == text) ?? 99

# A leaf is a real reason of the request. `Ok` or the text of the broken rule.
real_leaf : Model, List(Str), List(Str), List(List(Str)), Solver.Step, List(U64) -> Try({}, Str)
real_leaf = |m, known, nm, all, step, got| {
	ord = order(m)
	match step.cause {
		Given => {
			tn = |t| if t.s == 3 and m.has_roc "roc" else "s${t.s.to_str()}"
			exact = m.conflicts.any(
				|c| c.all(|t| nm.contains(tn(t))) and pick(
					all,
					|tup| c.all(
						|t| {
							chosen = tup.get(nm.find_first_index(|x| x == tn(t)) ?? 0) ?? ""
							if t.sign == In t.ids.contains(chosen) else !t.ids.contains(chosen)
						},
					),
				) == got,
			)
			if exact Ok({}) else Err("R-AL3: a reason `Given` that is no conflict of the caller")
		}
		NoValue(name) => match nm.find_first_index(|x| x == name) {
			Ok(i) => if (doms_of(m, known).get(i) ?? [{ id: "x", v: 0 }]).is_empty() Ok({}) else Err("R-AL3: a reason `NoValue` for a slot that has a value")
			Err(_) => Err("R-AL3: a reason `NoValue` for a name that is no slot")
		}
		Dep(dp) => {
			is_fact = match fact_at(m, known, dp.id) {
				Ok(f) => f.deps.any(|(g, v)| "g${g.to_str()}" == dp.group and ver_of(v) == dp.version)
				Err(_) => Bool.False
			}
			want = pick(
				all,
				|tup| match place_of(tup, dp.id) {
					Err(_) => Bool.False
					Ok(i) => tup.map_with_index(|id, j| (id, j)).any(
						|(id, j)| j != i and (ord.get(j) ?? 0) != 99 and "g${(ord.get(j) ?? 0).to_str()}" == dp.group and id_version(id) < ver_index(dp.version),
					)
				},
			)
			if is_fact and want == got Ok({}) else Err("R-C2: a reason `Dep` that is no fact, or excludes other tuples than the rule: ${dp.id} ${dp.group} ${dp.version}")
		}
		Pf(pf) => {
			is_fact = match fact_at(m, known, pf.id) {
				Ok(f) => match f.pf {
					Ok(url) => url == pf.pf
					Err(_) => Bool.False
				}
				Err(_) => Bool.False
			}
			plats = ord.map_with_index(|k, i| (k, i)).keep_if(|(k, _)| k != 99 and own_kind(m, k) == Platform).map(|(_, i)| i)
			want = pick(
				all,
				|tup| match (place_of(tup, pf.id), plats) {
					(Ok(i), [p]) => i != p and (tup.get(p) ?? "") != pf.pf
					_ => Bool.False
				},
			)
			if is_fact and want == got Ok({}) else Err("R-C3: a reason `Pf` that is no fact, or excludes other tuples than the rule")
		}
		Derived(_, _) => Ok({})
		Probe(p) => {
			lo = d.find_first_index(|x| x == p.from) ?? 99
			hi = d.find_first_index(|x| x == p.to) ?? 0
			mode = if m.off All else Real
			members = d.map_with_index(|x, i| (x, i)).keep_if(|(_, i)| lo <= i and i <= hi).map(|(x, _)| x)
			cell = |x| m.checks.find_first(|c| c.id == p.id and c.nightly == x)
			is_fault = |x| match cell(x) {
				Ok(c) => (c.outcome == Hang or c.outcome == Crash) and c.source == Real
				Err(_) => Bool.False
			}
			edge_ok = (lo == 0 or !fail_blocks(m, mode, p.id, d.get(lo - 1) ?? "")) and (hi + 1 >= d.len() or !fail_blocks(m, mode, p.id, d.get(hi + 1) ?? ""))
			used = m.uses.find_first(|u| u.id == p.id).map_ok(|u| u.modules) ?? []
			mods = dedupe(members.join_map(|x| (cell(x).map_ok(|c| c.modules) ?? []).keep_if(|s| used.contains(s))))
			infr = members.keep_if(|x| cell(x).map_ok(|c| c.source == Inferred) ?? Bool.False)
			want = pick(all, |tup| place_of(tup, p.id).is_ok() and tup.any(|id| members.contains(id)))
			shape = if p.kind == Fault {
				lo == hi and is_fault(p.from) and p.modules.is_empty() and p.inferred.is_empty()
			} else {
				lo <= hi and members.all(|x| fail_blocks(m, mode, p.id, x)) and edge_ok and p.modules == mods and p.inferred == infr
			}
			if !m.off and !p.inferred.is_empty() {
				Err("R-EP8: with probes allowed, a reason names an inferred fact")
			} else if shape and want == got {
				Ok({})
			} else {
				Err("R-EP7: a probe reason that is no run of D with a fail (or a fault alone), no maximal run, other modules or inferred compilers than the rule, or excludes other tuples: ${p.id} ${p.from}..${p.to}")
			}
		}
	}
}

# R-EP7 R-EP8 R-EP9 R-AL5: the explanation of a `Fail` is a proof, and each leaf is a real reason.
check_why : Model, List(Str), Solver.Why -> Try({}, Str)
check_why = |m, known, why| {
	nm = names(m)
	doms = doms_of(m, known).map(|dom| dom.map(|c| c.id))
	all = tuples(doms)
	viols = why.steps.map(|st| pick(all, |t| all_true(nm, t, st.terms)))
	if !well_formed(why.steps) {
		Err("R-AL3: the explanation is no proof: the last step has a term, or a `Derived` names a step that is not before it")
	} else if !sound(why.steps, viols) {
		Err("R-AL3: a step of the explanation does not follow from its leaves")
	} else {
		bad = why.steps.map_with_index(|st, i| (st, i)).keep_oks(
			|(st, i)| match real_leaf(m, known, nm, all, st, viols.get(i) ?? []) {
				Ok(_) => Err(Fine)
				Err(text) => Ok(text)
			},
		)
		match bad {
			[text, ..] => Err(text)
			[] => Ok({})
		}
	}
}

# The properties for one input: `Err` is the text of the broken one (its first words are the rule ids). The step of the request runs for each input. TW26: the step costs 0.35 ms in this build (coverage marks), a loop of a command 10 ms, so the
# costly checks run for a part of the inputs only (by bits of the mixed words, so each is 1 input in 4, 32 or 128 whatever the length of the input): the step of the flipped request for 1 in 4 (the bits 60 and 61 of the word 12 are 0), the loop of a command for 1 in 32
# (the bits 59 to 63 of the word 13), the loop with the flipped lists for 1 in 128 (and the bits 62 and 63 of the word 12).
# With 20000 runs the target takes about 25 s of the run budget of the `l1` step.
verdict : Raw -> Try({}, Str)
verdict = |raw| {
	ws = expand(raw)
	m = model_of(ws)
	all_ids = m.facts.map(|(id, _)| id)
	known = all_ids.map_with_index(|id, i| (id, field(m.known_bits, i % 16, 1) == 1)).keep_if(|(_, k)| k).map(|(id, _)| id)
	part = request_of(m, known)
	res = Solver.step(part)
	got = show(res)
	if got != expected(m, known) {
		Err("R-VA6 R-AL3 R-AL8 R-AL5 R-EP7 R-EP8 R-EP9 R-C1 R-C2 R-C3 R-C4 R-C6 R-C7 R-C9: the step differs from the oracle for the same facts. Got ${got}. Want ${expected(m, known)}")
	} else if field(ws.w12, 60, 2) == 0 and render(res) != render(Solver.step(flipped(part))) {
		Err("R-DT2: the order of the candidates, the facts, the conflicts, the checks or the used modules changed the step or its explanation")
	} else {
		why_bad = match res {
			Fail(why) => check_why(m, known, why)
			_ => Ok({})
		}
		match why_bad {
			Err(text) => Err(text)
			Ok(_) => if field(ws.w13, 59, 5) != 0 {
				Ok({})
			} else {
				allowed = order(m).join_map(|k| if k == 99 [] else domain(m, k).map(|c| c.id))
				start = request_of(m, [])
				want = match best(m, all_ids, All) {
					Err(_) => "fail"
					Ok(tuple) => tuple_text(m, tuple)
				}
				match drive(m, start, allowed, all_ids.len() + 61) {
					Err(why) => Err(why)
					Ok(end) => if end.text != want {
						Err("R-VA6 R-AL3 R-AL8 R-EP8 R-EP9: the loop ends with ${end.text}, the oracle for all facts has ${want}")
					} else {
						# the explanation at the end of the loop: all headers are known, the checks are the ones that the loop has
						final_bad = match Solver.step(end.last) {
							Fail(why) => check_why({ ..m, checks: end.last.compat.checks }, all_ids, why)
							_ => Ok({})
						}
						match final_bad {
							Err(text) => Err(text)
							Ok(_) => if field(ws.w12, 62, 2) != 0 {
								Ok({})
							} else {
								match drive(m, flipped(start), allowed, all_ids.len() + 61) {
									Err(why) => Err(why)
									Ok(end2) => if end2.text != end.text Err("R-DT2: the order of the lists changed the end of the loop") else Ok({})
								}
							}
						}
					}
				}
			}
		}
	}
}

test : Raw -> Fuzz.Outcome
test = |raw| match verdict(raw) {
	Err(text) => crash text
	Ok(_) => Fuzz.keep
}

# The text of a step with its explanation (the order of the steps is part of it, R-DT2).
render : [Need(List(Solver.Ask)), Done(List(Solver.Chosen)), Fail(Solver.Why)] -> Str
render = |r| match r {
	Fail(why) => "fail ${Str.inspect(why)}"
	other => show(other)
}

target = Fuzz.target_with({
	name: "pubgrub",
	generator,
	test,
	show: |raw| Str.inspect(raw),
})
