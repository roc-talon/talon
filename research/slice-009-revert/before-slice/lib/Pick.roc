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
	## | `free` | The command may choose. A held slot (`free` false) has the one value `current` (R-SP1). |
	## | `named` | The exact version that the user named (`X@1.2.3`): `min-release-age` and the snapshot do not hide it (R-C7) |
	## | `candidates` | The candidates of the group (or of the URL form, `any_series`), from the index, in any order. `Index.Candidate`. |
	Slot : {
		id : Str,
		is_platform : Bool,
		ranges : List(Str),
		current : Try(Str, [None]),
		free : Bool,
		named : Try(Str, [None]),
		candidates : List(Index.Candidate),
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
	## | The dependency URLs of a chosen release (`Release.deps`) have a version of the group of another slot that is higher than the chosen version of that slot (one level: the closure walk is slice 007, question Q7) | R-C2 |
	##
	## A candidate with no fact is taken as fit (optimistic). `step` finds the first tuple that way. When that tuple has a candidate with no fact, the result is
	## `Need(urls)`: the URLs of these candidates, in the order of the slots, with no repeat. When all its facts are known and it has no conflict, it is `Done`. A fact can
	## show a conflict, and the next `step` gives another tuple. So the commands loop until `Done` or `Fail`.
	##
	## `Fail` (kind `NoTuple`, exit 10, R-PH10): no tuple. The messages (a proposal, TW24):
	##
	## | Case | Message |
	## | --- | --- |
	## | The domain of a slot is empty after rules 2 and 3 (the first such slot) | `no tuple works: <id> has no release that satisfies <range> and <range> (<n> releases, <a> outside the ranges, <b> too new)`. `<n>` is the number of candidates, `<a>` those that fail rule 2, `<b>` those that pass rule 2 and fail rule 3. With 1 range: `<range>`. |
	## | The domain is empty after rule 4 (known facts show the kind is wrong for each candidate) | `no tuple works: <id> has no release of the kind <package or platform> in <ranges> (R-C4)` with the ranges joined by ` and ` |
	## | Each slot has candidates, and no tuple has no conflict | `no tuple works: the releases of <id>, <id> do not fit together (R-C2, R-C3)` with all the ids of the slots, in order |
	step : {
		slots : List(Slot),
		strategy : [Highest, Lowest],
		now : U64,
		min_age : U64,
		snapshot : Try(U64, [None]),
		facts : List({ url : Str, release : Release }),
	} -> [Need(List(Str)), Done(List(Chosen)), Fail(Fail)]
	step = |facts| {
		ctx = {
			known: Dict.from_list(facts.facts.map(|f| (f.url, f.release))),
			single_platform: facts.slots.keep_if(|slot| slot.is_platform).len() == 1,
		}
		domains = facts.slots.map(|slot| domain_of(slot, facts, ctx.known))
		match first_failure(facts.slots, domains) {
			Ok(fail) => Fail(fail)
			Err(NoFailure) => match search(domains.map(|d| { is_platform: d.is_platform, cands: d.ordered }), [], ctx) {
				Err(NoFit) => Fail(Fail.new(NoTuple, "no tuple works: the releases of ${Str.join_with(facts.slots.map(|slot| slot.id), ", ")} do not fit together (R-C2, R-C3)"))
				Ok(picked) => {
					missing = picked.map(|p| p.c.url).keep_if(|url| !ctx.known.contains(url)).fold([], |urls, url| if urls.contains(url) urls else urls.append(url))
					if missing.is_empty() {
						Done(facts.slots.map2(picked, |slot, p| chosen_of(slot, p.c, facts)))
					} else {
						Need(missing)
					}
				}
			}
		}
	}
}

Cand : Index.Candidate

# The domain of one slot after each rule (the table of `step`): `all` after rule 1, `in_range` after rule 2, `visible` after rule 3, `ordered` after rules 4 and 5.
Domain : { is_platform : Bool, all : List(Cand), in_range : List(Cand), visible : List(Cand), ordered : List(Cand) }

Step : { slots : List(Pick.Slot), strategy : [Highest, Lowest], now : U64, min_age : U64, snapshot : Try(U64, [None]), facts : List({ url : Str, release : Release }) }

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
	all = if slot.free {
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
	in_range = if slot.free all.keep_if(|c| Ranges.admits({ ranges: slot.ranges, version: c.ident.version })) else all
	visible = if slot.free in_range.keep_if(|c| !is_hidden(slot, facts, c)) else in_range
	right_kind = |c| match known.get(c.url) {
		Ok(release) => if slot.is_platform release.kind == Platform else release.kind == Package
		Err(_) => Bool.True
	}
	{ is_platform: slot.is_platform, all, in_range, visible, ordered: Index.order(visible.keep_if(right_kind), facts.strategy) }
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

Choice : { is_platform : Bool, c : Cand }

Ctx : { known : Dict(Str, Release), single_platform : Bool }

# The first tuple in the lexicographic order of the domains that has no conflict between 2 slots (R-VA6, R-SP11).
search : List({ is_platform : Bool, cands : List(Cand) }), List(Choice), Ctx -> Try(List(Choice), [NoFit])
search = |domains, picked, ctx| match domains {
	[] => Ok(picked)
	[d, .. as rest] => pick_from(d.cands, d.is_platform, rest, picked, ctx)
}

pick_from : List(Cand), Bool, List({ is_platform : Bool, cands : List(Cand) }), List(Choice), Ctx -> Try(List(Choice), [NoFit])
pick_from = |cands, is_platform, rest, picked, ctx| match cands {
	[] => Err(NoFit)
	[c, .. as more] => {
		choice = { is_platform, c }
		if picked.all(|other| !conflicts(ctx, other, choice)) {
			match search(rest, picked.append(choice), ctx) {
				Ok(done) => Ok(done)
				Err(NoFit) => pick_from(more, is_platform, rest, picked, ctx)
			}
		} else {
			pick_from(more, is_platform, rest, picked, ctx)
		}
	}
}

conflicts : Ctx, Choice, Choice -> Bool
conflicts = |ctx, a, b| conflict_from(ctx, a, b) or conflict_from(ctx, b, a)

# R-C3, R-C2: what the release of `x` says about the choice `y`. A release with no fact has no conflict yet.
conflict_from : Ctx, Choice, Choice -> Bool
conflict_from = |ctx, x, y| match ctx.known.get(x.c.url) {
	Err(_) => Bool.False
	Ok(release) => {
		wrong_platform = ctx.single_platform and !x.is_platform and y.is_platform and release.pf != Err(None) and release.pf != Ok(y.c.url)
		wrong_platform or release.deps.any(|dep| needs_newer(dep, y.c))
	}
}

# R-C2 (one level): a dependency URL in the group of `y` with a version above the one that `y` has.
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
