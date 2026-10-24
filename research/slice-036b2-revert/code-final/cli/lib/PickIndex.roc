import Add
import Closure
import Fail
import Fx
import Github
import Index
import PickLoop
import Ranges
import ResolveBase
import Vars
import semver.Semver

## The index step of the pick (slice 031b: split from `PickFlow`): the release pages of the repos, the slots of `Pick.step`, and the new names of `add`.
PickIndex :: [].{

	# The pages of each repo that a free variable or a want needs (R-SP1: a held variable needs no index call), as candidates (R-DI3 to R-DI5).
	index! : Fx, ResolveBase.Request, List(Str), List(Str) => Try(List(ResolveBase.Candidates), Fail)
	index! = |fx, request, names, known| {
		var $found = no_candidates
		var $oldest = Err(None)
		for name in names {
			(owner, repo) = match name.split_on("/") {
				[o, r] => (o, r)
				_ => return Err(Fail.new(Usage, "'${name}' is not on github.com: an index of other hosts needs a registry (--registry)"))
			}
			fetched = Github.releases!(fx, { net: request.net, roots: request.roots, owner, repo, now: request.now, offline: request.offline })?
			match fetched.source {
				Cached(t) => {
					$oldest = match $oldest {
						Ok(old) if old <= t => Ok(old)
						_ => Ok(t)
					}
				}
				_ => {}
			}
			match Index.candidates({ owner, repo, pages: fetched.pages, known }) {
				Ok({ list, warnings }) => {
					for w in warnings {
						fx.err!("warning: ${w}\n")
					}
					$found = $found.append({ name, list, missing: fetched.source == Missing })
				}
				Err(BadPage(n)) => return Err(Fail.new(Network, "the release list of ${name} (page ${n.to_str()}) is not a list of releases"))
			}
		}
		match $oldest {
			Ok(t) => fx.err!("${Github.offline_line(t)}\n")
			Err(None) => {}
		}
		Ok($found)
	}

	# The slots of `Pick.step`: the variables in order, then the wants (R-VA6), then the new names of `add`.
	slots_of : List(Vars.Scoped), List(Vars.Want), List(ResolveBase.Candidates), ResolveBase.Asked, List(ResolveBase.FreshRow), ResolveBase.Settings, Try(U64, [None]), List({ file : Str, entries : List(Closure.Entry) }), Str -> PickLoop.Input
	slots_of = |scoped, wants, found, asked, fresh, settings, snapshot, unmanaged, current_file| {
		candidates_of = |name| match found.find_first(|c| c.name == name) {
			Ok(c) => c
			Err(_) => { name, list: [], missing: Bool.True }
		}
		var_slots = scoped.map(
			|s| {
				v = s.variable
				cands = match v.name {
					Ok(name) => {
						c = candidates_of(name)
						group = if s.any_series c.list.keep_if(|x| x.ident.group.form == v.group.form) else Index.in_group({ list: c.list, group: v.group })
						{ list: group, missing: c.missing }
					}
					Err(NoName) => { list: [], missing: Bool.True }
				}
				named = asked.picks.find_first(|p| v.uses.any(|u| u.alias == p.alias)) ?? { alias: "", selector: Latest }
				{
					id: match v.uses.first() {
						Ok(u) => u.alias
						Err(_) => ""
					},
					is_platform: v.is_platform,
					ranges: v.ranges.map(|r| r.range),
					current: highest_use(v.uses),
					hold: if s.free and !cands.missing Free else if s.movable Movable else Held,
					named: match named.selector {
						Exact(version) if s.any_series => Ok(version)
						_ => named_by_entry(v, fresh)
					},
					candidates: cands.list,
					files: v.uses.map(|u| u.file).fold([], |found_files, file| if found_files.contains(file) found_files else found_files.append(file)),
				}
			},
		)
		want_slots = wants.map(
			|w| {
				name = w.name ?? w.key
				list = match Index.new_entry({ name, list: candidates_of(name).list }) {
					Ok(entry) => entry.list
					Err(NoCandidate) => []
				}
				{ id: w.key, is_platform: Bool.False, ranges: [w.range], current: Err(None), hold: Free, named: Err(None), candidates: list, files: w.members }
			},
		)
		fresh_slots = fresh.map(
			|row| {
				id: row.fresh.key,
				is_platform: row.fresh.is_platform,
				ranges: [row.fresh.range],
				current: Err(None),
				hold: Free,
				named: match row.fresh.selector {
					Ok(Exact(version)) => Ok(version)
					_ => Err(None)
				},
				candidates: row.list,
				files: [current_file],
			},
		)
		{
			slots: var_slots.concat(want_slots).concat(fresh_slots),
			strategy: settings.strategy,
			min_age: settings.min_age,
			snapshot,
			unmanaged,
			second: Bool.False,
			want_slots: wants.map2(want_slots, |w, slot| { key: w.key, name: w.name ?? w.key, urls: slot.candidates.map(|c| c.url) }),
		}
	}

	# The new names of `add`: the candidates of each (R-SL12: one must admit the selector), then the kind of the newest candidate of its URL form (the highest
	# `published_at`, the first one wins a tie, D6): `--platform` and a package, or a platform and no `--platform`, stop before the pick (R-AD32, R-AD33). The alias is
	# checked here too (R-AD14 to R-AD18). The header of the newest candidate is a fact for the pick.
	prepare! : Fx, ResolveBase.Request, ResolveBase.Loaded, List(ResolveBase.Fresh), List(ResolveBase.Candidates) => Try(ResolveBase.Prepared, Fail)
	prepare! = |fx, request, loaded, fresh, found| {
		header = ResolveBase.current_rows(loaded.members, request.project.file ?? "")
		var $rows = no_rows
		var $facts = ResolveBase.no_facts
		for f in fresh {
			cands = match found.find_first(|c| c.name == f.name) {
				Ok(c) => {
					# R-DI12: a new group with no cached page fails with exit 15, not as "no release".
					if c.missing return Err(Github.no_page_failure(f.name))
					c.list
				}
				Err(_) => []
			}
			list = match Index.new_entry({ name: f.name, list: cands }) {
				Ok(entry) => entry.list
				Err(NoCandidate) => []
			}
			first = match newest(list) {
				Ok(c) if list.any(|x| Ranges.admits({ ranges: [f.range], version: x.ident.version })) => c
				_ => return Err(Add.no_release({ name: f.name, selector: f.selector, text: f.text, versions: cands.map(|c| c.ident.version) }))
			}
			read = ResolveBase.read_releases!(fx, request, [first.url])?
			kind = match read {
				[fact] => if fact.release.kind == Platform Platform else Package
				_ => Package
			}
			_ = Add.decide({ selector: f.selector, chosen: { name: f.name, url: first.url, kind }, platform_flag: f.is_platform, no_pin: request.add.no_pin, as_alias: request.add.as_alias, header })?
			$rows = $rows.append({ fresh: f, list })
			$facts = $facts.concat(read)
		}
		Ok({ rows: $rows, facts: $facts })
	}
}

no_candidates : List(ResolveBase.Candidates)
no_candidates = []

# D7, R-C7: a version that `add X@1.2.3` names for a new entry is named for the variable of that group too: it may move to it, and `min-release-age` does not hide it.
named_by_entry : Vars.Var, List(ResolveBase.FreshRow) -> Try(Str, [None])
named_by_entry = |v, rows| match rows.find_first(|row| v.name == Ok(row.fresh.name) and v.is_platform == row.fresh.is_platform) {
	Ok({ fresh: { selector: Ok(Exact(version)), .. }, .. }) => Ok(version)
	_ => Err(None)
}

# The use with the highest version: its URL is the value that the header holds now (R-C9).
highest_use : List({ file : Str, alias : Str, url : Str, version : Str }) -> Try(Str, [None])
highest_use = |uses| match uses {
	[] => Err(None)
	[first, .. as rest] => Ok(
		rest.fold(
			first,
			|best, u| match (Semver.parse(u.version), Semver.parse(best.version)) {
				(Ok(a), Ok(b)) => if a.order_relative_to(b) == After u else best
				_ => best
			},
		).url,
	)
}

# The candidate with the highest `published_at`. A tie keeps the first (the rule of `Index.new_entry`).
newest : List(Index.Candidate) -> Try(Index.Candidate, [ListWasEmpty])
newest = |list| match list {
	[] => Err(ListWasEmpty)
	[first, .. as rest] => Ok(rest.fold(first, |best, c| if c.published_at > best.published_at c else best))
}

no_rows : List(ResolveBase.FreshRow)
no_rows = []
