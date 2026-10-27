import lib.Ident
import lib.Index
import lib.Oracle
import lib.Pick

OracleTest :: [].{}

now = 1792065600

day = 86400

# A release URL of the fixture host (as in `pickclosure.roc`).
u = |repo, ver| "https://github.com/acme/${repo}/releases/download/${ver}/${repo}x${ver.replace_each(".", "x")}.tar.zst"

cand = |url, days| match Ident.of_url(url) {
	Ok(ident) => { url, ident, tag: ident.version, published_at: now - days * day, size: 1 }
	Err(_) => crash "bad test URL"
}

fact = |url, deps| { url, release: { kind: Package, pf: Err(None), deps } }

slot = |id, ranges, current, hold, candidates| { id, is_platform: Bool.False, ranges, current: Ok(current), hold, named: Err(None), candidates, files: [] }

input = |slots, facts, strategy, second| { slots, strategy, now, min_age: 2 * day, snapshot: Err(None), facts, unmanaged: [], paths: [], second }

view = |r| match r {
	Need(urls) => Err(Ok(urls))
	Done(chosen) => Ok(chosen.map(|c| (c.id, c.version, c.change, c.note)))
	Fail(fail) => Err(Err(fail.line()))
}

no_fit = |ids| Err(Err("tln: error[no_tuple]: no tuple works: the releases of ${ids} do not fit together (R-C2, R-C3)"))

# R-AL9 R-AL3 R-PH10 R-DT2 (slice 036, 034 Q3): after the solver gives a tuple, the closure of the tuple is walked, and a problem of the closure is fed back as a conflict, as many times as it takes. `json` has 3 releases. `json 3.0.0` names
# `mid 1.0.0`, and `mid 1.0.0` names `core 1.1.0`. `json 2.0.0` names `mid 2.0.0`, which names `core 1.2.0`. `core` is held at 1.0.0 (a slot), `mid` is no slot. A closure that names a higher version of the group of a slot is a problem (R-C2): so
# the first 2 tuples have a problem that no fact of the slots shows, and the third tuple (`json 1.0.0`, no dep) is the result. The 2 problems come one after the other in one call, because all the facts are known. The result, and the `Need` list when a
# fact is missing, do not depend on the order of the facts or of the candidates (R-DT2).
expect {
	json = |v| u("json", v)
	json_slot = slot("json", [], json("1.0.0"), Free, [cand(json("1.0.0"), 30), cand(json("2.0.0"), 30), cand(json("3.0.0"), 30)])
	core_slot = slot("core", [], u("core", "1.0.0"), Held, [])
	facts = [
		fact(json("3.0.0"), [u("mid", "1.0.0")]),
		fact(json("2.0.0"), [u("mid", "2.0.0")]),
		fact(json("1.0.0"), []),
		fact(u("mid", "1.0.0"), [u("core", "1.1.0")]),
		fact(u("mid", "2.0.0"), [u("core", "1.2.0")]),
		fact(u("core", "1.0.0"), []),
	]
	run = |slots, fs, strategy, second| view(Oracle.step(input(slots, fs, strategy, second)))
	third = Ok([("json", "1.0.0", Keep, Err(None)), ("core", "1.0.0", Keep, Err(None))])
	flipped = { ..json_slot, candidates: json_slot.candidates.rev() }
	rows = [
		("two problems in a row: the third tuple", run([json_slot, core_slot], facts, Highest, Bool.False), third),
		("the same with the facts and the candidates in another order (R-DT2)", run([flipped, core_slot], facts.rev(), Highest, Bool.False), third),
		("the same in the second search (no movable slot: the same tuple)", run([json_slot, core_slot], facts, Highest, Bool.True), third),
		("the header of mid 2.0.0 is missing: the step asks for it with the tuple that it can see (json 3.0.0 has a problem, json 2.0.0 is the next tuple)", run([json_slot, core_slot], facts.keep_if(|f| f.url != u("mid", "2.0.0")), Highest, Bool.False), Err(Ok([u("mid", "2.0.0")]))),
		("every tuple has a problem: no tuple, the text of Pick.step", run([{ ..json_slot, candidates: [cand(json("3.0.0"), 30), cand(json("2.0.0"), 30)], current: Ok(json("2.0.0")) }, core_slot], facts, Highest, Bool.False), no_fit("json, core")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-WS8 R-WS2 R-AL3 (slice 036): the solver names its slots by place, not by the alias of the slot (`id`). One alias can name 2 groups in 2 members (R-WS8), and then 2 slots have the same `id`. Two slots `core` with the groups
# `acme/core` series 1 and `acme/core` series 2 are 2 variables with 2 values each. The slot `core` that names a series has one value for the group (R-WS2): 2 slots of one group (the new entry of `add`) have the same value.
expect {
	core1 = slot("core", ["^1"], u("core", "1.0.0"), Free, [cand(u("core", "1.0.0"), 30), cand(u("core", "1.1.0"), 30)])
	core2 = slot("core", ["^2"], u("core", "2.0.0"), Free, [cand(u("core", "2.0.0"), 30), cand(u("core", "2.1.0"), 30)])
	same = slot("also", ["<=1.0.0"], u("core", "1.0.0"), Free, [cand(u("core", "1.0.0"), 30), cand(u("core", "1.1.0"), 30)])
	held = slot("core", [], u("core", "1.0.0"), Held, [])
	free = slot("also", ["^1"], u("core", "1.0.0"), Free, [cand(u("core", "1.0.0"), 30), cand(u("core", "1.1.0"), 30)])
	facts = [fact(u("core", "1.0.0"), []), fact(u("core", "1.1.0"), []), fact(u("core", "2.0.0"), []), fact(u("core", "2.1.0"), [])]
	run = |slots, strategy| view(Oracle.step(input(slots, facts, strategy, Bool.False)))
	rows = [
		("2 slots with one alias and 2 groups: each has its best value", run([core1, core2], Highest), Ok([("core", "1.1.0", Move("1.0.0"), Err(None)), ("core", "2.1.0", Move("2.0.0"), Err(None))])),
		("the same with Lowest", run([core1, core2], Lowest), Ok([("core", "1.0.0", Keep, Err(None)), ("core", "2.0.0", Keep, Err(None))])),
		("2 slots of one group have one value (R-WS2): the second has the range <=1.0.0, so both get 1.0.0", run([core1, same], Highest), Ok([("core", "1.0.0", Keep, Err(None)), ("also", "1.0.0", Keep, Err(None))])),
		("the same, the slot with the range first: the first slot has its value, the second follows", run([same, core1], Highest), Ok([("also", "1.0.0", Keep, Err(None)), ("core", "1.0.0", Keep, Err(None))])),
		("a held slot and a free slot of one group: no range says it, the conflict does (R-WS2): the free slot keeps the held value, not the best one", run([held, free], Highest), Ok([("core", "1.0.0", Keep, Err(None)), ("also", "1.0.0", Keep, Err(None))])),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-AL3 (the learning does not repeat work): 16 free slots `f0` to `f15` with 2 releases each come first, then `x` and `y` with 2 releases each. No release of `y` fits a release of `x` (the facts of `y` name a version of `x` that no release has).
# A search that goes back one decision at a time tries the 2^16 tuples of the free slots before it finds that `x` and `y` have no pair. The search of the oracle learns that no value of the free slots matters, so it ends at once. Same text as `Pick.step`.
expect {
	free = List.repeat(0, 16).map_with_index(|_, i| { name: "f${i.to_str()}", i })
	fslots = free.map(|f| slot(f.name, [], u(f.name, "1.0.0"), Free, [cand(u(f.name, "1.0.0"), 30), cand(u(f.name, "1.1.0"), 30)]))
	x = slot("x", [], u("x", "1.0.0"), Free, [cand(u("x", "1.0.0"), 30), cand(u("x", "1.1.0"), 30)])
	y = slot("y", [], u("y", "1.0.0"), Free, [cand(u("y", "1.0.0"), 30), cand(u("y", "1.1.0"), 30)])
	facts = fslots.join_map(|s| s.candidates.map(|c| fact(c.url, []))).concat([fact(u("x", "1.0.0"), []), fact(u("x", "1.1.0"), []), fact(u("y", "1.0.0"), [u("x", "1.2.0")]), fact(u("y", "1.1.0"), [u("x", "1.2.0")])])
	ids = Str.join_with(free.map(|f| f.name).concat(["x", "y"]), ", ")
	got = view(Oracle.step(input(fslots.concat([x, y]), facts, Highest, Bool.False)))
	got == no_fit(ids)
}

# R-WS2 R-AL3 (the conflict of 2 slots of one group is a pair, not a tuple): `a` (range ^1) and `b` (range <=1.0.0) are 2 slots of one group, and they come first. 16 free slots `f0` to `f15` follow. The best tuple has `a` 1.1.0 and `b` 1.0.0 (2 values for one group).
# If the step finds this only when it walks the closure, its conflict has the 18 slots, and it tries the 2^16 tuples of the free slots. The conflict of the step is the pair, so the next tuple is `a` 1.0.0 at once. The answer is the same as in the row of the closure walk, but the time is not.
expect {
	a = slot("a", ["^1"], u("core", "1.0.0"), Free, [cand(u("core", "1.0.0"), 30), cand(u("core", "1.1.0"), 30)])
	b = slot("b", ["<=1.0.0"], u("core", "1.0.0"), Free, [cand(u("core", "1.0.0"), 30), cand(u("core", "1.1.0"), 30)])
	free = List.repeat(0, 16).map_with_index(|_, i| "f${i.to_str()}")
	fslots = free.map(|name| slot(name, ["^1"], u(name, "1.0.0"), Free, [cand(u(name, "1.0.0"), 30), cand(u(name, "1.1.0"), 30)]))
	facts = fslots.join_map(|s| s.candidates.map(|c| fact(c.url, []))).concat([fact(u("core", "1.0.0"), []), fact(u("core", "1.1.0"), [])])
	got = Oracle.step(input([a, b].concat(fslots), facts, Highest, Bool.False))
	versions = match got {
		Done(chosen) => chosen.map(|c| c.version)
		_ => []
	}
	versions == ["1.0.0", "1.0.0"].concat(List.repeat("1.1.0", 16))
}

# R-PH13 R-PH10 R-C1 R-C2 R-C3 R-C4 R-C6 R-C7 R-C9 R-VA6 R-SP1 R-SP24 R-DT2 (slice 036): the oracle step gives the same answer as `Pick.step` (the pick of P0) for 480 worlds that are made by whole-number arithmetic from a seed. A world has 1 to 3 slots (the first can be the
# platform), each `Free`, `Held` or `Movable`, with 2 to 4 releases, a range, a header value (it can be missing from the list), a named version, the facts of most releases (the kind, a platform, a dep on a release of another slot, a dep on
# a package that is no slot), `Highest` or `Lowest`, a snapshot, and the first or the second search. The answer is the result of `Oracle.step` as text: `Need`, `Done` with each change and note, or the failure line. The lists in the other order give
# the same answer. `Pick.step` is the oracle for this row: it is the P0 rule that the rows of `pick.roc`, `pickclosure.roc` and `pickmoves.roc` fix (they run on `Oracle.step` too).
expect {
	repos = ["p0", "p1", "p2"]
	minors = [0.U64, 1, 2, 3]
	ver = |m| "1.${m.to_str()}.0"
	url = |i, m| u(repos.get(i) ?? "p", ver(m))
	world = |seed| {
		n = 1 + seed % 3
		platform_first = seed % 5 == 0
		slots = List.repeat(0, n).map_with_index(
			|_, i| {
				hold = match (seed // 3 + i) % 3 {
					0 => Free
					1 => Held
					_ => Movable
				}
				at = (seed + i * 2) % 3
				ranges = match (seed // 7 + i) % 4 {
					0 => ["^1"]
					1 => [">=1.1.0"]
					2 => ["<1.3.0"]
					_ => []
				}
				listed = minors.keep_if(|m| (seed // 11 + i * 3 + m) % 5 != 0)
				days = |m| if m == 3 and seed % 2 == 0 1 else 30
				has_current = hold != Free or (seed + i) % 4 != 0
				{
					id: repos.get(i) ?? "p",
					is_platform: platform_first and i == 0,
					ranges,
					current: if has_current Ok(url(i, at)) else Err(None),
					hold,
					named: if i == 0 and seed % 6 == 1 Ok("1.3.0") else Err(None),
					candidates: listed.map(|m| cand(url(i, m), days(m))),
					files: [],
				}
			},
		)
		facts = slots.map_with_index(|s, i| (s, i)).join_map(
			|(s, i)| minors.keep_oks(
				|m| if (seed + i + m) % 6 == 5 {
					Err(NoFact)
				} else {
					kind = if s.is_platform Platform else if (seed + i + m) % 13 == 0 App else Package
					pf = if !s.is_platform and platform_first and (seed + m) % 4 == 0 Ok(url(0, (m + seed) % 4)) else Err(None)
					other = (i + 1) % n
					dep_other = if n > 1 and (seed + m + i) % 3 == 0 [url(other, (seed + m) % 4)] else []
					dep_z = if (seed + i + m) % 7 == 0 [u("z", "1.0.0")] else []
					Ok({ url: url(i, m), release: { kind, pf, deps: dep_other.concat(dep_z) } })
				},
			),
		)
		z_fact = if seed % 2 == 0 [fact(u("z", "1.0.0"), [])] else []
		{
			slots,
			strategy: if seed % 2 == 0 Highest else Lowest,
			now,
			min_age: 2 * day,
			snapshot: if seed % 9 == 4 Ok(now - 10 * day) else Err(None),
			facts: facts.concat(z_fact),
			unmanaged: [],
			paths: [],
			second: seed % 4 == 0,
		}
	}
	flip = |w| { ..w, slots: w.slots.map(|s| { ..s, candidates: s.candidates.rev() }), facts: w.facts.rev() }
	seeds = List.repeat(0, 480).map_with_index(|_, i| i)
	rows = seeds.keep_oks(
		|seed| {
			w = world(seed)
			want = view(Pick.step(w))
			got = view(Oracle.step(w))
			again = view(Oracle.step(flip(w)))
			if got == want and again == want Err(Same) else Ok((seed, want, got, again))
		},
	)
	dbg rows.take_first(3)
	rows == []
}
