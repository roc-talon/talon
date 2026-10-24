app [target] {
	fuzz: platform "https://github.com/lukewilliamboswell/roc-fuzz/releases/download/0.4.3/41NK5FShyGC9Z8HNpUdUeXMWwLmLNfFxsfmLvdPL4Fxb.tar.zst",
	lib: "../../cli/lib/main.roc",
}

import fuzz.Fuzz
import lib.Db
import lib.Epochs
import lib.Text

# L1 target of slice 033 (TESTING.md 4): random domains, random epochs, random facts (check rows, faults, build rows) against the rules of Resolution 4.
# One run checks these properties of one input. The first word of a crash text is the rule id.
#
# | Property | Rule |
# | --- | --- |
# | `Epochs.partition` and the `epochs` of `Epochs.epochs` are one interval for each release, in the order of D | R-EP4, R-EP11, R-EP13 |
# | The facts in another order (reversed, rotated) give the same output | R-EP10 |
# | `Epochs.epochs` is `partition` and `infer` with it | R-EP10 |
# | `infer` equals an oracle written here from the rule text (index loops, no fold over facts), for random epochs (some releases are held by no interval, some intervals have one id that is not in D): the same pairs, outcomes and `from`, in the order hash then D | R-EP6, R-EP1, R-EP14, R-EP4 |
# | An inferred pair has no real check fact, `Pass` has no module, `Fail` has the sorted union of the modules of its sources | R-EP14, R-EP6 |
# | Removing the faults from the facts changes no inferred fact, except that the pairs with a fault (which have no inferred fact) become gaps | R-EP5 |

hashes : List(Str)
hashes = ["9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17", "Bz7g9mTqU2oV4tG3a1kKfWm5cD8xNqL6RrPjYsHe2vZu", "Gm4Wc7nPq2YkR8vTb5Jd3XaF6sHeZu9LtNw1VoCxEzKy"]

host = "linux_x86_64"

# `kind`: 0 pass, 1 fail, 2 hang, 3 crash (unit checks), 4 build pass, 5 build fail (not unit checks). `mods`: bit 0 is A.roc, bit 1 is B.roc (a fail only).
Raw : { size : U8, cuts : List(U8), cells : List({ hash : U8, at : U8, kind : U8, mods : U8 }) }

generator : Fuzz.Generator(Raw)
generator = {
	size: Fuzz.u8_in(1, 8),
	cuts: Fuzz.list(Fuzz.u8_in(0, 3), 7),
	cells: Fuzz.list({ hash: Fuzz.u8_in(0, 2), at: Fuzz.u8_in(0, 7), kind: Fuzz.u8_in(0, 5), mods: Fuzz.u8_in(0, 3) }.Fuzz, 24),
}.Fuzz

# A cell with its release and its hash as numbers. `at` is a place in D.
Cell : { h : U64, at : U64, kind : U8, mods : List(Str) }

mods_of : U8 -> List(Str)
mods_of = |bits| (if bits % 2 == 1 ["A.roc"] else []).concat(if bits // 2 == 1 ["B.roc"] else [])

is_check : U8 -> Bool
is_check = |kind| kind < 4

# The first cell of a key (hash, place, unit or build) stays: the caller of `Epochs` applies R-EF3, so there is one row for each key.
cells_of : Raw -> List(Cell)
cells_of = |raw| raw.cells
	.map(|c| { h: c.hash.to_u64(), at: c.at.to_u64() % raw.size.to_u64(), kind: c.kind, mods: if c.kind == 1 mods_of(c.mods) else [] })
	.fold(
		[],
		|kept, c| if kept.any(|k| k.h == c.h and k.at == c.at and is_check(k.kind) == is_check(c.kind)) kept else kept.append(c),
	)

ids_of : U64 -> List(Str)
ids_of = |n| List.repeat("", n).map_with_index(|_, i| "n${i.to_str()}")

# R-EP13: a 1 at place `i` of `cuts` ends an epoch after release `i`. A 2 ends it too, but no interval is made for it. A 3 ends it too, with an interval that has the first release and an id that is not in D (it holds nothing, D5).
# In both cases the releases are held by no interval (an epoch of their own). The last release always ends the last group.
groups_of : { n : U64, cuts : List(U8) } -> List({ from : U64, to : U64, kind : [Held, Missing, Mixed] })
groups_of = |run| {
	var $out = []
	var $start = 0
	for i in U64.until(0, run.n) {
		cut = match run.cuts.get(i) {
			Ok(c) => c
			Err(_) => 0
		}
		if cut > 0 or i + 1 == run.n {
			kind = if cut == 2 Missing else if cut == 3 Mixed else Held
			$out = $out.append({ from: $start, to: i, kind })
			$start = i + 1
		}
	}
	$out
}

fact_of : Cell, List(Str) -> Db.Fact
fact_of = |c, ids| {
	hash = hashes.get(c.h) ?? ""
	nightly = ids.get(c.at) ?? ""
	check = |outcome| { hash, nightly, target: "any", outcome, modules: c.mods, closure: "" }
	build = |outcome| { hash, nightly, target: host, outcome, modules: [], closure: "c0ffee" }
	match c.kind {
		0 => check(Pass)
		1 => check(Fail)
		2 => check(Hang)
		3 => check(Crash)
		4 => build(Pass)
		_ => build(Fail)
	}
}

Brief : { hash : Str, nightly : Str, outcome : [Pass, Fail], from : List(Str) }

brief : Epochs.Inferred -> Brief
brief = |x| { hash: x.hash, nightly: x.nightly, outcome: x.outcome, from: x.from }

# The oracle (R-EP6, from the rule text): for each hash and each place with no real unit fact, the set of the code results of case (a) and case (b).
code_of : List(Cell), U64, U64 -> Try([Pass, Fail], [None])
code_of = |checks, h, at| match checks.find_first(|c| c.h == h and c.at == at and c.kind < 2) {
	Ok(c) => if c.kind == 0 Ok(Pass) else Ok(Fail)
	Err(_) => Err(None)
}

oracle : { checks : List(Cell), ids : List(Str), groups : List({ from : U64, to : U64 }) } -> List(Brief)
oracle = |run| {
	n = run.ids.len()
	idx = run.ids.map_with_index(|_, i| i)
	var $out = []
	for h in U64.until(0, 3) {
		for at in U64.until(0, n) {
			if !run.checks.any(|c| c.h == h and c.at == at) {
				span = run.groups.find_first(|g| g.from <= at and at <= g.to) ?? { from: at, to: at }
				seen = |places| places.keep_oks(|j| code_of(run.checks, h, j).map_ok(|x| (j, x)))
				same_epoch = seen(idx.keep_if(|j| span.from <= j and j <= span.to))
				before = seen(idx.keep_if(|j| j < at)).last()
				after = seen(idx.keep_if(|j| j > at)).first()
				between = match before {
					Ok((jb, xb)) => match after {
						Ok((ja, xa)) => if xb == xa [(jb, xb), (ja, xa)] else []
						Err(_) => []
					}
					Err(_) => []
				}
				all = same_epoch.concat(between)
				has_pass = all.any(|(_, x)| x == Pass)
				has_fail = all.any(|(_, x)| x == Fail)
				if has_pass != has_fail {
					x = if has_pass Pass else Fail
					from = idx.keep_if(|j| all.any(|(jj, xx)| jj == j and xx == x)).map(|j| run.ids.get(j) ?? "")
					$out = $out.append({ hash: hashes.get(h) ?? "", nightly: run.ids.get(at) ?? "", outcome: x, from })
				}
			}
		}
	}
	$out
}

# The modules of a fail copy (Q1, answered by the manager): the sorted union of the modules of the sources, with no repeat.
modules_ok : List(Db.Fact), Epochs.Inferred -> Bool
modules_ok = |facts, x| match x.outcome {
	Pass => x.modules == []
	Fail => {
		sets = x.from.map(|id| (facts.find_first(|f| f.hash == x.hash and f.nightly == id and f.target == "any").map_ok(|f| f.modules)) ?? [])
		x.modules == Text.sorted_unique(sets.join_map(|set| set))
	}
}

test : Raw -> Fuzz.Outcome
test = |raw| {
	n = raw.size.to_u64()
	ids = ids_of(n)
	domain = ids.map(|id| { id, published_at: 0, asset: Err(NoAsset) })
	cells = cells_of(raw)
	facts = cells.map(|c| fact_of(c, ids))
	checks = cells.keep_if(|c| is_check(c.kind))
	groups = groups_of({ n, cuts: raw.cuts })
	held = groups.keep_if(|g| g.kind == Held).map(|g| { from: g.from, to: g.to })
	epochs = groups.keep_oks(
		|g| match g.kind {
			Held => Ok({ from: ids.get(g.from) ?? "", to: ids.get(g.to) ?? "" })
			Missing => Err(NoInterval)
			Mixed => if g.to % 2 == 0 Ok({ from: ids.get(g.from) ?? "", to: "zz" }) else Ok({ from: "zz", to: ids.get(g.to) ?? "" })
		},
	)
	singles = ids.map(|id| { from: id, to: id })
	found = Epochs.epochs(domain, facts)
	if Epochs.partition(domain) != singles or found.epochs != singles {
		crash "R-EP4 R-EP11 R-EP13: the epochs are not one interval for each release"
	} else if Epochs.epochs(domain, facts.rev()) != found or Epochs.epochs(domain, facts.drop_first(3).concat(facts.take_first(3))) != found {
		crash "R-EP10: the order of the facts changed the output"
	} else if found.inferred != Epochs.infer({ domain, epochs: singles, facts }) {
		crash "R-EP10: epochs is not infer with the partition"
	} else {
		got = Epochs.infer({ domain, epochs, facts })
		want = oracle({ checks, ids, groups: held })
		if got.map(brief) != want {
			crash "R-EP6 R-EP14: infer differs from the oracle"
		} else if got.any(|x| !modules_ok(facts, x)) {
			crash "R-EP6 R-EP14: the modules of an inferred fail"
		} else {
			no_faults = facts.keep_if(|f| f.outcome == Pass or f.outcome == Fail)
			faulty = |x| facts.any(|f| f.hash == x.hash and f.nightly == x.nightly and f.target == "any" and f.outcome != Pass and f.outcome != Fail)
			if got != Epochs.infer({ domain, epochs, facts: no_faults }).keep_if(|x| !faulty(x)) {
				crash "R-EP5: a fault changed an inferred fact, or has one"
			} else {
				Fuzz.keep
			}
		}
	}
}

target = Fuzz.target_with({
	name: "epochs",
	generator,
	test,
	show: |raw| Str.inspect(raw),
})
