import Closure
import Fail
import Ident
import Index
import Ranges
import Release
import Text
import semver.Semver

## The choice of one tuple (Resolution 5 step 3, Design 7 R-PH10, R-PH13): the best tuple by `priority` under R-C1 to R-C4, R-C6, R-C7 and R-C9. P0 has no
## PubGrub loop and no compatibility evidence (R-C5 is the ladder of slice 006). The step is a pure function of data (TESTING.md 2.2, part B): it asks for the
## facts that it needs (`Need`), the command fetches the packages and reads their headers (`Release.read`), and calls `step` again.
##
## The result is deterministic (R-DT2): it does not depend on the order of the slots' candidates or of the facts.
Pick :: [].{

	## One variable of the choice, in the order of `priority` (R-VA6). `Vars` gives the ranges, `Resolve.run!` gives the rest.
	##
	## | Field | Holds |
	## | --- | --- |
	## | `id` | The alias of the first use, or the key of a want. It names the slot in messages. |
	## | `is_platform` | The kind that a release must have (R-C4): `Platform` for true, `Package` for false |
	## | `ranges` | The constraints of R-C1: each range must admit the version |
	## | `current` | The URL that the header has now (R-C9). `Err(None)` for a want. |
	## | `hold` | `Free`: the command may choose. `Held`: the one value `current` (R-SP1), in both searches. `Movable`: the one value `current` in the first search, and a free value in the second search (slice 017: R-SP23, R-SP24). |
	## | `named` | The exact version that the user named (`X@1.2.3`): `min-release-age` and the snapshot do not hide it (R-C7) |
	## | `candidates` | The candidates of the group (or of the URL form, `any_series`), from the index, in any order. `Index.Candidate`. A `Movable` slot has none until the second search needs them. |
	## | `files` | The member files that have an entry of the group (the new entry of `add`: the current member; a key of `talon.toml`: its member). The closure of a member has only the slots that name it (slice 017, Q1 of slice 016). The empty list means every member. |
	Slot : {
		id : Str,
		is_platform : Bool,
		ranges : List(Str),
		current : Try(Str, [None]),
		hold : [Free, Held, Movable],
		named : Try(Str, [None]),
		candidates : List(Index.Candidate),
		files : List(Str),
	}

	## One chosen value. `change` is `Keep` when the URL is `current`, else `Move(<old version>)` (`<old version>` is `""` for a want). `note` is set when
	## the user named a version that `min-release-age` would have hidden (R-C7): `<id> <version> is <n>d old (min-release-age <m>d)`, whole days (a proposal, TW24).
	Chosen : { id : Str, url : Str, version : Str, change : [Keep, Move(Str)], note : Try(Str, [None]) }

	## The rules, applied in this order to the domain of a slot:
	##
	## | # | Rule | Source |
	## | --- | --- | --- |
	## | 1 | A held slot: the domain is `current`. A free slot: the candidates, and `current` (it is added when the list has no candidate with its URL: R-C9). | R-SP1, R-C9 |
	## | 2 | Each range of the slot admits the version (`Ranges.admits`) | R-C1 |
	## | 3 | Hidden: `published_at + min_age > now`, or `published_at > snapshot` when there is a snapshot time. Not hidden: `current` (R-C9), and the candidate with the version `named` (R-C7). | R-C7, R-C9 |
	## | 4 | The kind: the release of the facts must have the kind of the slot (R-C4). A candidate with no fact yet counts as right. | R-C4 |
	## | 5 | The order: `Index.order(strategy)` | R-DI9, R-VA6 |
	##
	## (R-C6: a yanked, draft or prerelease release is not a candidate with `direct`: `Index.candidates` skips it. `Pick` has no yank data in P0.)
	##
	## The tuple is the first one in the lexicographic order of the slots (the first slot has the strongest rank: R-VA6, R-SP11) and of their domains that
	## has no conflict. The conflicts between 2 slots, from the facts that are known:
	##
	## | Conflict | Rule |
	## | --- | --- |
	## | A package release names a platform (`Release.pf`) that is not the URL of the chosen platform slot, when there is exactly one platform slot (question Q8) | R-C3 |
	## | A problem of the closure of the tuple (a followed edge names a higher version of the group of a slot, a cycle, one label with 2 hashes, 2 platforms: slice 016, below) | R-C2, R-AL9 |
	##
	## The closure of a tuple (slice 016, R-AL9; slice 011 for R-C2 over the full closure). It is the closure that `roc` builds (Design 2, `Closure.step`, `Mvs`), and the walk before the ladder (`Walk`), `list` and `why` use the same rule:
	##
	## | # | Rule |
	## | --- | --- |
	## | 1 | The roots are the chosen URLs of the slots, and the entries that no slot owns (`unmanaged`, for each member file: a path entry or a foreign URL, not an entry that the run replaces). A path entry is a node: its file is `Text.resolve(<dir of the member file>, <value>)`. A foreign URL is no edge (R-H4). A group is the URL form and the series (R-ID2), so `core 1.1.0` and `core 2.0.0` are 2 groups (R-C8: no conflict, a warning later). |
	## | 2 | The followed edges are the `Release.deps` of the chosen slot URLs and of the winner of each group that is no slot, and the entries of each path node (`paths`), as far as their facts are known. A release URL is an edge. A path value in the entries of a path file is another path file (relative to the dir of that file), and it is always followed (R-H7). A path value in the `deps` of a release is ignored (a published package cannot name a local file). A foreign URL is no edge. |
	## | 3 | The winner of a group that is no slot is the highest version that a followed edge names. A lower version is not followed (its `deps` have no effect, and its fact is not asked for). A lower version in a path file than the chosen slot is a raise, no conflict. The winners are the fixed point of rules 2 and 3. |
	## | 4 | A problem of the closure is a conflict of the tuple (R-AL9): a followed edge names a version of the group of a slot that is higher than the chosen version of that slot (the header pin is lower than a dependency needs, R-C2), a cycle, one label (name and version) with 2 hashes, 2 platforms. The step then tries the next tuple (R-PH10). `Fail` is only for "no tuple is left". |
	##
	## A node with no fact is taken as fit (optimistic). `step` finds the first tuple that way. When that tuple has a node with no fact, the result is `Need(ids)`. An id is a release URL or the absolute file of a path node. Order: first the chosen slot URLs that have no fact, in the order of the slots, then the other nodes that have no fact, in the order in which the followed edges name them (level by level), with no repeat. So a package or a path file 2 levels or more below the app is asked for before the tuple is `Done`. When all its facts are known and it has no conflict, it is `Done`. A fact can
	## show a conflict, and the next `step` gives another tuple. The commands loop until `Done` or `Fail` (`PickLoop.run!`): the nodes of one `Need` are read together (R-AL8, R-FE1), the release headers into `facts`, the path files into `paths`. The result does not depend on the order of `facts` or `paths` (R-DT2). Tests: `tests/unit/pickclosure.roc`, L2 `closure/cl2-chain`.
	##
	## `Fail` (kind `NoTuple`, exit 10, R-PH10): no tuple. The messages (a proposal, TW24):
	##
	## | Case | Message |
	## | --- | --- |
	## | The domain of a slot is empty after rules 2 and 3 (the first such slot) | `no tuple works: <id> has no release that satisfies <range> and <range> (<n> releases, <a> outside the ranges, <b> too new)`. `<n>` is the number of candidates, `<a>` those that fail rule 2, `<b>` those that pass rule 2 and fail rule 3. With 1 range: `<range>`. |
	## | The domain is empty after rule 4 (known facts show the kind is wrong for each candidate) | `no tuple works: <id> has no release of the kind <package or platform> in <ranges> (R-C4)` with the ranges joined by ` and ` |
	## | Each slot has candidates, and no tuple has no conflict (also a problem of the closure: slice 016, D3) | `no tuple works: the releases of <id>, <id> do not fit together (R-C2, R-C3)` with all the ids of the slots, in order |
	##
	## `unmanaged` and `paths` are new (slice 016): see rules 1 and 2 of the closure. `paths` are `Closure.Node`s: `id` is the absolute file, `entries` are `Release.entries_of` of its text.
	##
	## Slice 017 (held moves, R-SP15 to R-SP17, R-SP23 to R-SP26, R-WS12). The search above is the first search: a `Held` and a `Movable` slot have the one value `current`. With `second: true` the step is the second search (R-SP24, R-PH10):
	##
	## | # | Rule |
	## | --- | --- |
	## | 1 | The order of the search: the `Movable` slots first, in the order of the slots (`priority`), then the other slots in the order of the slots. The result and the `Need` list stay in the order of the slots. |
	## | 2 | The domain of a `Movable` slot is the domain of a `Free` slot (rules 1 to 4 of the table above: the candidates and `current`, R-C1 ranges, R-C7, R-C9, R-C4 kind) |
	## | 3 | The order of the values of a `Movable` slot: `current` first, then the nearest values. `Highest`: the higher versions from low to high, then the lower versions from high to low. `Lowest`: the lower versions from high to low, then the higher versions from low to high. The strategy does not change the order of a `Free` slot (R-DI9) |
	## | 4 | The search is lexicographic in that order (R-VA6), so a `Movable` slot keeps `current` when a tuple exists with it and the earlier `Movable` slots, else it takes the first value that has a tuple (the smallest step) |
	## | 5 | `Fail` for a slot with no value (the messages of the table above) and for no tuple: the same texts. The caller (`PickFlow`) runs the second search only after a first search that gave `Fail` of kind `NoTuple`, and only when a slot is `Movable` |
	##
	## Two slots of one group (the new entry of `add` in a group that other members hold, R-WS2, R-WS3) have one value: a choice whose group (`Ident.group` of its URL) equals the group of another choice and whose URL differs is a conflict, as the conflicts of the table above. So a new entry with no selector gets the held version, and `=2.2.0` with a held 2.0.0 has no first tuple.
	##
	## The closure of a member (Q1 of slice 016, roc builds each member alone): the entries of a member are the chosen URLs of the slots that name it (`Slot.files` has its file, or is empty), then its own entries that no slot owns (`unmanaged`). A path file of a member that does not use a group names no conflict for that group in another member. With no `unmanaged` row the step has one member that has all slots.
	step : {
		slots : List(Slot),
		strategy : [Highest, Lowest],
		now : U64,
		min_age : U64,
		snapshot : Try(U64, [None]),
		facts : List({ url : Str, release : Release }),
		unmanaged : List({ file : Str, entries : List(Closure.Entry) }),
		paths : List(Closure.Node),
		second : Bool,
	} -> [Need(List(Str)), Done(List(Chosen)), Fail(Fail)]
	step = |facts| {
		ctx = {
			known: Dict.from_list(facts.facts.map(|f| (f.url, f.release))),
			single_platform: facts.slots.keep_if(|slot| slot.is_platform).len() == 1,
			nodes: facts.facts.map(|f| Pick.node_of(f)).concat(facts.paths),
			members: if facts.unmanaged.is_empty() [{ file: "", entries: [] }] else facts.unmanaged,
		}
		domains = facts.slots.map(|slot| domain_of(slot, facts, ctx.known))
		match first_failure(facts.slots, domains) {
			Ok(fail) => Fail(fail)
			Err(NoFailure) => match search(search_order(facts, domains), [], ctx) {
				Err(NoFit) => Fail(Fail.new(NoTuple, "no tuple works: the releases of ${Str.join_with(facts.slots.map(|slot| slot.id), ", ")} do not fit together (R-C2, R-C3)"))
				Ok(found) => if found.need.is_empty() {
					Done(facts.slots.map2(found.picked, |slot, p| chosen_of(slot, p.c, facts)))
				} else {
					Need(found.need)
				}
			}
		}
	}

	## Slice 017 (R-SP16): the held variables that the second search moved. One row for each `Movable` slot whose chosen URL is not `current`, in the order of the slots. `from` and `to` are versions. `chosen` is the result of `step` (the order of `slots`),
	## `facts` are the headers that the step knew. `why` is the first conflict that the current value has in the final tuple (a proposal, TW24):
	##
	## | # | Conflict | `why` |
	## | --- | --- | --- |
	## | 1 | R-C1: a range of the slot, or of a slot of the same group (the new entry of `add`, R-WS2), excludes the current version. The first range in the order of the slots. | `<id> <current version> is outside <range>` |
	## | 2 | R-C2: the release of a chosen slot (in the order of the slots) has a dep in the group of the slot with a higher version than the current | `<id of that slot> <its version> needs <id> >= <dep version>` |
	## | 3 | R-C3: the release of a chosen package slot names a platform URL that is not the current value of a platform slot | `<id of that slot> <its version> needs <id> <platform version>` |
	## | 4 | None of these (a problem of the closure, R-AL9) | `<id> <current version> does not fit the closure of the new tuple` |
	moves : { slots : List(Slot), chosen : List(Chosen), facts : List({ url : Str, release : Release }) } -> List({ id : Str, from : Str, to : Str, why : Str })
	moves = |facts| {
		rows = facts.slots.map2(facts.chosen, |slot, c| (slot, c))
		known = Dict.from_list(facts.facts.map(|f| (f.url, f.release)))
		rows.keep_oks(|(slot, c)| moved_row(slot, c, rows, known))
	}

	## A release fact as a node of the closure (the platform entry first, then the dependencies). The aliases are empty: the pick keeps none.
	node_of : { url : Str, release : Release } -> Closure.Node
	node_of = |f| {
		pf = match f.release.pf {
			Ok(value) => [{ alias: "", value, is_platform: Bool.True }]
			Err(None) => []
		}
		{ id: f.url, entries: pf.concat(f.release.deps.map(|value| { alias: "", value, is_platform: Bool.False })) }
	}
}

Cand : Index.Candidate

# The domain of one slot after each rule (the table of `step`): `all` after rule 1, `in_range` after rule 2, `visible` after rule 3, `ordered` after rules 4 and 5.
Domain : { is_platform : Bool, all : List(Cand), in_range : List(Cand), visible : List(Cand), ordered : List(Cand) }

Step : {
	slots : List(Pick.Slot),
	strategy : [Highest, Lowest],
	now : U64,
	min_age : U64,
	snapshot : Try(U64, [None]),
	facts : List({ url : Str, release : Release }),
	unmanaged : List({ file : Str, entries : List(Closure.Entry) }),
	paths : List(Closure.Node),
	second : Bool,
}

# R-DT2: the candidates are in the byte order of their URLs first, so the result does not depend on the order of the index.
domain_of : Pick.Slot, Step, Dict(Str, Release) -> Domain
domain_of = |slot, facts, known| {
	listed = slot.candidates.sort_with(|a, b| Text.compare(a.url, b.url))
	current = match slot.current {
		Ok(url) => match listed.find_first(|c| c.url == url) {
			Ok(c) => Ok(c)
			Err(_) => Ident.of_url(url).map_ok(|ident| { url, ident, tag: ident.version, published_at: 0, size: 0 }).map_err(|_| None)
		}
		Err(None) => Err(None)
	}
	open = slot.hold == Free or (slot.hold == Movable and facts.second)
	all = if open {
		match current {
			Ok(c) if !listed.any(|x| x.url == c.url) => listed.append(c)
			_ => listed
		}
	} else {
		match current {
			Ok(c) => [c]
			Err(None) => []
		}
	}
	in_range = if open all.keep_if(|c| Ranges.admits({ ranges: slot.ranges, version: c.ident.version })) else all
	visible = if open in_range.keep_if(|c| !is_hidden(slot, facts, c)) else in_range
	right_kind = |c| match known.get(c.url) {
		Ok(release) => if slot.is_platform release.kind == Platform else release.kind == Package
		Err(_) => Bool.True
	}
	fits = visible.keep_if(right_kind)
	ordered = if slot.hold == Movable and facts.second nearest(fits, slot, facts.strategy) else Index.order(fits, facts.strategy)
	{ is_platform: slot.is_platform, all, in_range, visible, ordered }
}

# R-SP24: the order of the values of a movable slot in the second search. `current` first, then the nearest values: `Highest` the higher versions from low to high and then the lower ones
# from high to low, `Lowest` the lower ones from high to low and then the higher ones from low to high.
nearest : List(Cand), Pick.Slot, [Highest, Lowest] -> List(Cand)
nearest = |cands, slot, strategy| {
	current = slot.current ?? ""
	old = Ident.of_url(current).map_ok(|ident| ident.version) ?? ""
	own = cands.keep_if(|c| c.url == current)
	rest = Index.order(cands.keep_if(|c| c.url != current), Lowest)
	higher = rest.keep_if(|c| is_newer(c.ident.version, old))
	lower = rest.keep_if(|c| !is_newer(c.ident.version, old)).rev()
	match strategy {
		Highest => own.concat(higher).concat(lower)
		Lowest => own.concat(lower).concat(higher)
	}
}

SearchRow : { slot : U64, files : List(Str), is_platform : Bool, cands : List(Cand) }

# R-SP24: the movable slots come first in the second search, then the others. Each in the order of the slots.
search_order : Step, List(Domain) -> List(SearchRow)
search_order = |facts, domains| {
	rows = facts.slots.map2(domains, |slot, d| (slot, d)).map_with_index(|(slot, d), i| { slot: i, files: slot.files, is_platform: d.is_platform, cands: d.ordered, first: slot.hold == Movable })
	front = if facts.second rows.keep_if(|r| r.first) else []
	back = if facts.second rows.keep_if(|r| !r.first) else rows
	front.concat(back).map(|r| { slot: r.slot, files: r.files, is_platform: r.is_platform, cands: r.cands })
}

# R-C7, R-C9: hidden by the age or by the snapshot. The header value and the version that the user named are never hidden.
is_hidden : Pick.Slot, Step, Cand -> Bool
is_hidden = |slot, facts, c| {
	exempt = slot.current == Ok(c.url) or slot.named == Ok(c.ident.version)
	!exempt and (too_young(facts, c) or after_snapshot(facts, c))
}

too_young : Step, Cand -> Bool
too_young = |facts, c| c.published_at + facts.min_age > facts.now

after_snapshot : Step, Cand -> Bool
after_snapshot = |facts, c| match facts.snapshot {
	Ok(time) => c.published_at > time
	Err(None) => Bool.False
}

# The first slot with no release left: the failure of rules 2 and 3, then of rule 4.
first_failure : List(Pick.Slot), List(Domain) -> Try(Fail, [NoFailure])
first_failure = |slots, domains| {
	rows = slots.map2(domains, |slot, d| (slot, d))
	ranges_text = |slot| if slot.ranges.is_empty() "any range" else Str.join_with(slot.ranges, " and ")
	match rows.find_first(|(_, d)| d.visible.is_empty()) {
		Ok((slot, d)) => {
			total = d.all.len()
			outside = total - d.in_range.len()
			young = d.in_range.len() - d.visible.len()
			Ok(Fail.new(NoTuple, "no tuple works: ${slot.id} has no release that satisfies ${ranges_text(slot)} (${total.to_str()} releases, ${outside.to_str()} outside the ranges, ${young.to_str()} too new)"))
		}
		Err(_) => match rows.find_first(|(_, d)| d.ordered.is_empty()) {
			Ok((slot, _)) => Ok(Fail.new(NoTuple, "no tuple works: ${slot.id} has no release of the kind ${if slot.is_platform "platform" else "package"} in ${Str.join_with(slot.ranges, " and ")} (R-C4)"))
			Err(_) => Err(NoFailure)
		}
	}
}

Choice : { slot : U64, files : List(Str), is_platform : Bool, c : Cand }

Ctx : { known : Dict(Str, Release), single_platform : Bool, nodes : List(Closure.Node), members : List({ file : Str, entries : List(Closure.Entry) }) }

Found : { picked : List(Choice), need : List(Str) }

# The first tuple in the lexicographic order of the domains that has no conflict between 2 slots (R-VA6, R-SP11), and no problem of the closure (R-AL9).
# The domains are in the order of the search. The tuple is in the order of the slots.
search : List(SearchRow), List(Choice), Ctx -> Try(Found, [NoFit])
search = |domains, picked, ctx| match domains {
	[] => {
		in_order = picked.sort_with(|a, b| if a.slot < b.slot Before else if a.slot > b.slot After else Same)
		match closure_of(ctx, in_order) {
			Problem => Err(NoFit)
			Fine(need) => Ok({ picked: in_order, need })
		}
	}
	[d, .. as rest] => pick_from(d.cands, d, rest, picked, ctx)
}

pick_from : List(Cand), SearchRow, List(SearchRow), List(Choice), Ctx -> Try(Found, [NoFit])
pick_from = |cands, row, rest, picked, ctx| match cands {
	[] => Err(NoFit)
	[c, .. as more] => {
		choice = { slot: row.slot, files: row.files, is_platform: row.is_platform, c }
		if picked.all(|other| !conflicts(ctx, other, choice)) {
			match search(rest, picked.append(choice), ctx) {
				Ok(done) => Ok(done)
				Err(NoFit) => pick_from(more, row, rest, picked, ctx)
			}
		} else {
			pick_from(more, row, rest, picked, ctx)
		}
	}
}

# R-WS2, R-WS3: 2 slots of one group have one value.
conflicts : Ctx, Choice, Choice -> Bool
conflicts = |ctx, a, b| (a.c.ident.group == b.c.ident.group and a.c.url != b.c.url) or conflict_from(ctx, a, b) or conflict_from(ctx, b, a)

# R-C3, R-C2: what the release of `x` says about the choice `y`. A release with no fact has no conflict yet.
conflict_from : Ctx, Choice, Choice -> Bool
conflict_from = |ctx, x, y| match ctx.known.get(x.c.url) {
	Err(_) => Bool.False
	Ok(release) => {
		wrong_platform = ctx.single_platform and !x.is_platform and y.is_platform and release.pf != Err(None) and release.pf != Ok(y.c.url)
		wrong_platform or release.deps.any(|dep| needs_newer(dep, y.c))
	}
}

# R-C2, one level: a dependency URL in the group of `y` with a version above the one that `y` has. It is an early cut of the search. The check of the whole tuple is `closure_of`, which finds it too.
needs_newer : Str, Cand -> Bool
needs_newer = |dep, y| match Ident.of_url(dep) {
	Ok(ident) => ident.group == y.ident.group and is_newer(ident.version, y.ident.version)
	Err(Foreign) => Bool.False
}

is_newer : Str, Str -> Bool
is_newer = |a, b| match (Semver.parse(a), Semver.parse(b)) {
	(Ok(x), Ok(y)) => x.order_relative_to(y) == After
	_ => Bool.False
}

# R-AL9, Q1 of slice 016: the closure of a tuple, with the rule of `Closure.step` (one call for each member file). The roots are the chosen URLs of the slots that name the member (`files`), then the entries of the member that no slot owns.
# A `Fail` of any member is a problem of the tuple. Else `need` has the nodes that no fact is known for (the first member that asks, no repeat). An unknown node is taken as fit.
closure_of : Ctx, List(Choice) -> [Problem, Fine(List(Str))]
closure_of = |ctx, picked| {
	slot_entries = |m| picked.keep_if(|p| p.files.is_empty() or m.file == "" or p.files.contains(m.file)).map(|p| { alias: "", value: p.c.url, is_platform: p.is_platform })
	results = ctx.members.map(|m| Closure.step({ file: m.file, entries: slot_entries(m).concat(m.entries), nodes: ctx.nodes }))
	if results.any(
		|r| match r {
			Fail(_) => Bool.True
			_ => Bool.False
		},
	) {
		Problem
	} else {
		ids = results.join_map(
			|r| match r {
				Need(need) => need
				_ => []
			},
		)
		Fine(ids.fold([], |found, id| if found.contains(id) found else found.append(id)))
	}
}

chosen_of : Pick.Slot, Cand, Step -> Pick.Chosen
chosen_of = |slot, c, facts| {
	old = match slot.current {
		Ok(url) => Ident.of_url(url).map_ok(|ident| ident.version) ?? ""
		Err(None) => ""
	}
	days = |seconds| (seconds // 86400).to_str()
	hidden_by_age = slot.named == Ok(c.ident.version) and slot.current != Ok(c.url) and too_young(facts, c)
	{
		id: slot.id,
		url: c.url,
		version: c.ident.version,
		change: if slot.current == Ok(c.url) Keep else Move(old),
		note: if hidden_by_age Ok("${slot.id} ${c.ident.version} is ${days(if facts.now > c.published_at facts.now - c.published_at else 0)}d old (min-release-age ${days(facts.min_age)}d)") else Err(None),
	}
}

# R-SP16: the row of a movable slot whose value moved, with the first conflict that its old value has in the final tuple.
moved_row : Pick.Slot, Pick.Chosen, List((Pick.Slot, Pick.Chosen)), Dict(Str, Release) -> Try({ id : Str, from : Str, to : Str, why : Str }, [Stays])
moved_row = |slot, c, rows, known| match slot.current {
	Ok(current) if slot.hold == Movable and current != c.url => match Ident.of_url(current) {
		Ok(old) => Ok({ id: slot.id, from: old.version, to: c.version, why: why_of(slot, old.version, c, rows, known) })
		Err(_) => Err(Stays)
	}
	_ => Err(Stays)
}

# The order: R-C1 (a range of the slot or of its group), R-C2, R-C3, else a problem of the closure (R-AL9).
why_of : Pick.Slot, Str, Pick.Chosen, List((Pick.Slot, Pick.Chosen)), Dict(Str, Release) -> Str
why_of = |slot, old, c, rows, known| {
	group = Ident.of_url(c.url).map_ok(|ident| ident.group)
	outside = rows.keep_if(|(_, x)| Ident.of_url(x.url).map_ok(|ident| ident.group) == group).join_map(|(s, _)| s.ranges).find_first(|r| !Ranges.admits({ ranges: [r], version: old }))
	older_dep = |release| release.deps.keep_oks(
		|dep| match Ident.of_url(dep) {
			Ok(ident) if Ok(ident.group) == group and is_newer(ident.version, old) => Ok(ident.version)
			_ => Err(NoDep)
		},
	)
	by_dep = rows.keep_oks(
		|(s, x)| match known.get(x.url) {
			Ok(release) => older_dep(release).first().map_ok(|v| "${s.id} ${x.version} needs ${slot.id} >= ${v}")
			Err(_) => Err(NoFact)
		},
	)
	by_platform = rows.keep_if(|(s, x)| slot.is_platform and !s.is_platform and known.get(x.url).map_ok(|release| release.pf) == Ok(Ok(c.url))).map(|(s, x)| "${s.id} ${x.version} needs ${slot.id} ${c.version}")
	match outside {
		Ok(range) => "${slot.id} ${old} is outside ${range}"
		Err(_) => match by_dep.concat(by_platform).first() {
			Ok(text) => text
			Err(_) => "${slot.id} ${old} does not fit the closure of the new tuple"
		}
	}
}
