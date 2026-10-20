import Add
import Alias
import Consent
import Fail
import Fx
import Github
import Index
import Lookup
import Pick
import Prompt
import Ranges
import Ref
import ResolveBase
import Scope
import Selector
import Vars
import semver.Semver

Fact : ResolveBase.Fact

Loaded : ResolveBase.Loaded

Settings : ResolveBase.Settings

Rename : ResolveBase.Rename

Candidates : ResolveBase.Candidates

Kept : ResolveBase.Kept

Fresh : ResolveBase.Fresh

Asked : ResolveBase.Asked

FreshRow : ResolveBase.FreshRow

Prepared : ResolveBase.Prepared

Picked : ResolveBase.Picked

## The pick of `install`, `update`, `add` and `verify`: the names, the scope, the index and `Pick.step` (steps 2 to 7 of `Resolve.install!`). Split from `Resolve` in slice 010.
PickFlow :: [].{

	# Steps 2 to 7 of the flow: the names, the scope, the index and the pick (shared by `install!` and `verify!`).
	pick! : Fx, ResolveBase.Request, Loaded, { vars : List(Vars.Var), wants : List(Vars.Want) }, Settings, Try(U64, [None]) => Try(Picked, Fail)
	pick! = |fx, request, loaded, built, settings, snapshot| {
		asked = asked!(fx, request, loaded, built.vars)?
		# A named header entry is moved as `update X@sel` does it (R-AD22).
		command = if request.command == Install and asked.names.is_empty() Install else Update
		everyone = Vars.scope({
			command,
			names: asked.names,
			selectors: asked.picks.keep_oks(|p| range_of_selector(p.selector).map_ok(|range| { alias: p.alias, range })),
			vars: built.vars,
		})?
		# `--platform` replaces the platform entry, so the old platform is no variable of the pick (R-AD31).
		scoped = if request.add.as_platform and !asked.fresh.is_empty() everyone.keep_if(|s| !s.variable.is_platform) else everyone
		for s in scoped {
			match s.note {
				Ok(note) => fx.out!("${note}\n")
				Err(None) => {}
			}
		}
		stale = live_wants!(fx, request, built.wants)?
		free_names = scoped.keep_if(|s| s.free).keep_oks(|s| s.variable.name.map_err(|_| None))
		want_names = stale.live.keep_oks(|w| w.name.map_err(|_| None))
		known = built.vars.join_map(|v| v.uses.map(|u| u.url))
		repos = free_names.concat(want_names).concat(asked.fresh.map(|f| f.name)).fold(no_names, |found, name| if found.contains(name) found else found.append(name))
		found = index!(fx, request, repos, known)?
		prepared = prepare!(fx, request, loaded, asked.fresh, found)?
		input = slots_of(scoped, stale.live, found, asked, prepared.rows, settings, snapshot)
		looped = match pick_loop!(fx, request, input, prepared.facts) {
			Ok(c) => c
			Err(fail) => return Err(with_close_versions(fail, { scoped, asked, found }))
		}
		Ok({ facts: { scoped, wants: stale.live, asked, prepared, renames: stale.renames, snapshot, known: looped.facts }, chosen: looped.chosen })
	}
}

PickInput : {
	slots : List(Pick.Slot),
	strategy : [Highest, Lowest],
	min_age : U64,
	snapshot : Try(U64, [None]),
	want_slots : List({ key : Str, name : Str, urls : List(Str) }),
}

# R-SL12, U3 of slice 009: the failure "has no release that satisfies" of a variable with a selector (`update X@sel`) names the close versions of its repository.
with_close_versions : Fail, { scoped : List(Vars.Scoped), asked : Asked, found : List(Candidates) } -> Fail
with_close_versions = |fail, facts| {
	first_alias = |s| s.variable.uses.first().map_ok(|u| u.alias) ?? ""
	hit = facts.scoped.find_first(|s| s.free and fail.message.starts_with("no tuple works: ${first_alias(s)} has no release that satisfies "))
	pick_of = |s| facts.asked.picks.find_first(|p| s.variable.uses.any(|u| u.alias == p.alias))
	match (hit, fail.kind) {
		(Ok(s), NoTuple) => match (pick_of(s), s.variable.name) {
			(Ok(p), Ok(name)) => {
				versions = match facts.found.find_first(|c| c.name == name) {
					Ok(c) => c.list.map(|x| x.ident.version)
					Err(_) => []
				}
				Fail.new(NoTuple, "${fail.message}${Add.close_note({ selector: Ok(p.selector), versions })}")
			}
			_ => fail
		}
		_ => fail
	}
}

# The names of `update` and `install` (slice 004: `Ref.parse`, `Lookup.find`). A name of `update` is an alias of the project. A name of `install` is `tln add`
# (R-SP18): a header alias, or a full name that has one entry in the current member (D5), or a new entry.
asked! : Fx, ResolveBase.Request, Loaded, List(Vars.Var) => Try(Asked, Fail)
asked! = |fx, request, loaded, vars| {
	current = request.project.file ?? ""
	scope = if request.command == Update Scope.Project else Scope.Install
	rows = ResolveBase.current_rows(loaded.members, current)
	entities = if request.command == Update entities_of(vars) else entities_of(in_file(vars, current))
	var $names = no_names
	var $picks = no_picks
	var $kept = no_kept
	var $fresh = no_fresh
	for text in request.names {
		ref = Ref.parse(text, scope, Bool.False)?
		found = match Lookup.find(scope, ref, entities) {
			Ok(f) => f
			Err({ fail, block }) => {
				if request.command == Update and loaded.members.any(|m| m.locked.rows.any(|r| r.alias == ref.name and r.what == Path)) {
					return Err(Fail.new(Usage, "'${ref.name}' is a path entry: Talon never changes it"))
				}
				if !block.is_empty() fx.err!(block)
				return Err(fail)
			}
		}
		target = match found {
			Lookup.Existing({ alias: a, .. }) => Ok(a)
			Lookup.New(name) => if request.command == Update {
				return Err(Fail.new(Usage, "'${name}' is not in the project"))
			} else {
				entry_of_repo(request, vars, current, name)?
			}
		}
		match target {
			Ok(alias) => if request.command == Update {
				$names = $names.append(alias)
				match ref.selector {
					Ok(selector) => {
						$picks = $picks.append({ alias, selector })
					}
					Err(None) => {}
				}
			} else {
				plan = Add.decide_alias({ alias, selector: ref.selector, no_pin: request.add.no_pin, header: rows })?
				match plan.header {
					Keep => {
						$kept = $kept.append(kept_of(vars, current, alias, plan.note ?? ""))
					}
					_ => {
						$names = $names.append(alias)
						match ref.selector {
							Ok(selector) => {
								$picks = $picks.append({ alias, selector })
							}
							Err(None) => {}
						}
					}
				}
			}
			Err(New) => {
				$fresh = $fresh.append(fresh_of(request, vars, current, ref, text)?)
			}
		}
	}
	Ok({ names: $names, picks: $picks, kept: $kept, fresh: $fresh })
}

# The variables with their uses in one member file only.
in_file : List(Vars.Var), Str -> List(Vars.Var)
in_file = |vars, file| vars.keep_if(|v| v.uses.any(|u| u.file == file)).map(|v| { ..v, uses: v.uses.keep_if(|u| u.file == file) })

# D5: a full name that has one entry in the current member is that entry. `--platform` and `--as` always make a new entry. A platform entry needs `--platform` (R-AD33).
entry_of_repo : ResolveBase.Request, List(Vars.Var), Str, Str -> Try(Try(Str, [New]), Fail)
entry_of_repo = |request, vars, current, name| {
	same = in_file(vars, current).keep_if(|v| v.name == Ok(name))
	match same {
		[one] if !request.add.as_platform and request.add.as_alias == Err(Unset) => if one.is_platform {
			Err(Fail.new(Usage, "'${name}' is a platform. Use tln add --platform ${name}."))
		} else {
			match one.uses.first() {
				Ok(u) => Ok(Ok(u.alias))
				Err(_) => Ok(Err(New))
			}
		}
		_ => Ok(Err(New))
	}
}

# The `Kept` row of a header alias: its name and version are those of its entry in the current member.
kept_of : List(Vars.Var), Str, Str, Str -> Kept
kept_of = |vars, current, alias, note| match in_file(vars, current).find_first(|v| v.uses.any(|u| u.alias == alias)) {
	Ok(v) => {
		version = match v.uses.find_first(|u| u.alias == alias) {
			Ok(u) => u.version
			Err(_) => ""
		}
		{ alias, name: v.name ?? v.group.form, version, note }
	}
	Err(_) => { alias, name: alias, version: "", note }
}

# A new name of `add`. Q9: a group that another member holds (one variable, no entry in the current member) must admit the held versions, and then the entry gets the highest of them.
fresh_of : ResolveBase.Request, List(Vars.Var), Str, Ref, Str -> Try(Fresh, Fail)
fresh_of = |request, vars, current, ref, text| {
	name = ref.name
	typed = match ref.selector {
		Ok(selector) => range_of_selector(selector) ?? "*"
		Err(None) => "*"
	}
	range = match vars.keep_if(|v| v.name == Ok(name)) {
		[one] if !one.uses.any(|u| u.file == current) => {
			held = one.uses.map(|u| { file: u.file, version: u.version })
			Add.check_held({ name, range: typed, held })?
			"=${highest_version(held.map(|h| h.version))}"
		}
		_ => typed
	}
	Ok({
		name,
		selector: ref.selector,
		text: match text.split_first("@") {
			Ok({ after, .. }) => after
			Err(_) => "latest"
		},
		range,
		key: match request.add.as_alias {
			Ok(alias) => alias
			Err(Unset) => if request.add.as_platform "pf" else Alias.default(name)
		},
		is_platform: request.add.as_platform,
	})
}

# The highest of some versions (the first one when none parses).
highest_version : List(Str) -> Str
highest_version = |versions| match versions {
	[first, .. as rest] => rest.fold(
		first,
		|best, v| match (Semver.parse(v), Semver.parse(best)) {
			(Ok(a), Ok(b)) => if a.order_relative_to(b) == After v else best
			_ => best
		},
	)
	[] => ""
}

no_names : List(Str)
no_names = []

no_picks : List({ alias : Str, selector : Selector })
no_picks = []

no_kept : List(Kept)
no_kept = []

no_fresh : List(Fresh)
no_fresh = []

# The entities of the lookup: one for each header alias, the name with its series when 2 variables share a repo (R-SC15).
entities_of : List(Vars.Var) -> List({ alias : Str, name : Str, note : Str })
entities_of = |vars| {
	base = |v| v.name ?? v.group.form
	vars.join_map(
		|v| {
			shared = vars.keep_if(|o| base(o) == base(v)).len() >= 2
			name = if shared "${base(v)}@${v.group.series}" else base(v)
			v.uses
				.map(|u| { alias: u.alias, name, note: if v.is_platform "platform (${u.alias})" else "" })
				.fold([], |found, e| if found.any(|f| f.alias == e.alias) found else found.append(e))
		},
	)
}

# R-SL5, R-AD22: the range that a selector gives to its variable. `Latest` is any version.
range_of_selector : Selector -> Try(Str, [None])
range_of_selector = |selector| match selector {
	Exact(version) => Ok("=${version}")
	Range(text) => Ok(text)
	Latest => Ok("*")
	_ => Err(None)
}

# R-I5, R-I8, R-NI1 (D8): a stale key of `[dependencies]` is the prompt of `install` and `add`: the report, then the question. `Yes` renames the key
# at the write, `No` keeps it. `update` and a stale key of `[overrides]` keep the warning. A key with a short name has no index (R-AD6).
live_wants! : Fx, ResolveBase.Request, List(Vars.Want) => Try({ live : List(Vars.Want), renames : List(Rename) }, Fail)
live_wants! = |fx, request, wants| {
	var $live = no_wants
	var $ask = no_wants
	for w in wants {
		match w.stale {
			Ok(alias) => if request.command == Install and w.table == Dependencies {
				$ask = $ask.append(w)
			} else {
				fx.err!("warning: ${w.from}: the key \"${w.key}\" names ${w.name ?? w.key}, which the header has as \"${alias}\"\n")
			}
			Err(None) => if request.command == Install {
				match w.name {
					Err(Short(text)) => return Err(short_failure(w.from, text))
					Ok(_) => {
						$live = $live.append(w)
					}
				}
			}
		}
	}
	Ok({ live: $live, renames: ask_rename!(fx, request, $ask)? })
}

ask_rename! : Fx, ResolveBase.Request, List(Vars.Want) => Try(List(Rename), Fail)
ask_rename! = |fx, request, stale| {
	if stale.is_empty() return Ok([])
	consent = Consent.rename_keys(stale.map(|w| { key: w.key, name: w.name ?? w.key, alias: w.stale ?? "" }))
	fx.err!(consent.report)
	done = Prompt.ask!(fx, consent.prompt, { mode: request.prompt.mode, yes: request.prompt.yes, quiet: request.prompt.quiet, flag: request.prompt.rename_keys })?
	if done.answer == Yes {
		Ok(
			stale.map(
				|w| {
					path = match w.from.split_last(":") {
						Ok({ before, .. }) => before
						Err(_) => w.from
					}
					{ path, from: w.key, to: w.stale ?? "" }
				},
			),
		)
	} else {
		Ok([])
	}
}

no_wants : List(Vars.Want)
no_wants = []

short_failure : Str, Str -> Fail
short_failure = |from, text| match Ref.parse(text, Scope.Install, Bool.False) {
	Err(fail) => Fail.new(fail.kind, "${from}: ${fail.message}")
	Ok(ref) => match Lookup.find(Scope.Install, ref, []) {
		Err({ fail, .. }) => Fail.new(fail.kind, "${from}: ${fail.message}")
		Ok(_) => Fail.new(Usage, "${from}: '${text}' is a short name, and GitHub has no index of short names. Use the full name (owner/repo).")
	}
}

# The pages of each repo that a free variable or a want needs (R-SP1: a held variable needs no index call), as candidates (R-DI3 to R-DI5).
index! : Fx, ResolveBase.Request, List(Str), List(Str) => Try(List(Candidates), Fail)
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

no_candidates : List(Candidates)
no_candidates = []

# The slots of `Pick.step`: the variables in order, then the wants (R-VA6), then the new names of `add`.
slots_of : List(Vars.Scoped), List(Vars.Want), List(Candidates), Asked, List(FreshRow), Settings, Try(U64, [None]) -> PickInput
slots_of = |scoped, wants, found, asked, fresh, settings, snapshot| {
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
				free: s.free and !cands.missing,
				named: match named.selector {
					Exact(version) if s.any_series => Ok(version)
					_ => Err(None)
				},
				candidates: cands.list,
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
			{ id: w.key, is_platform: Bool.False, ranges: [w.range], current: Err(None), free: Bool.True, named: Err(None), candidates: list }
		},
	)
	fresh_slots = fresh.map(
		|row| {
			id: row.fresh.key,
			is_platform: row.fresh.is_platform,
			ranges: [row.fresh.range],
			current: Err(None),
			free: Bool.True,
			named: match row.fresh.selector {
				Ok(Exact(version)) => Ok(version)
				_ => Err(None)
			},
			candidates: row.list,
		},
	)
	{
		slots: var_slots.concat(want_slots).concat(fresh_slots),
		strategy: settings.strategy,
		min_age: settings.min_age,
		snapshot,
		want_slots: wants.map2(want_slots, |w, slot| { key: w.key, name: w.name ?? w.key, urls: slot.candidates.map(|c| c.url) }),
	}
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

# Step G of the flow: `Pick.step` until `Done` or `Fail`. A `Need` fetches the packages and reads their headers (`Release.read`).
pick_loop! : Fx, ResolveBase.Request, PickInput, List(Fact) => Try({ chosen : List(Pick.Chosen), facts : List(Fact) }, Fail)
pick_loop! = |fx, request, input, facts| match Pick.step({ slots: input.slots, strategy: input.strategy, now: request.now, min_age: input.min_age, snapshot: input.snapshot, facts }) {
	Done(chosen) => Ok({ chosen, facts })
	Fail(fail) => Err(fail)
	Need(urls) => {
		more = ResolveBase.read_releases!(fx, request, urls, Bool.True)?
		all = facts.concat(more)
		platform_wants(input.want_slots, all)?
		pick_loop!(fx, request, input, all)
	}
}

# Q2, R-AD33: a key of `talon.toml` whose release is a platform is not added as a package.
platform_wants : List({ key : Str, name : Str, urls : List(Str) }), List(Fact) -> Try({}, Fail)
platform_wants = |wants, facts| {
	found = wants.join_map(|w| facts.keep_if(|f| f.release.kind == Platform and w.urls.contains(f.url)).map(|f| (w, f.url)))
	match found {
		[] => Ok({})
		[(w, url), ..] => match Add.decide({ selector: Err(None), chosen: { name: w.name, url, kind: Platform }, platform_flag: Bool.False, no_pin: Bool.False, as_alias: Ok(w.key), header: [] }) {
			Err(fail) => Err(fail)
			Ok(_) => Ok({})
		}
	}
}

# The new names of `add`: the candidates of each (R-SL12: one must admit the selector), then the kind of the newest candidate of its URL form (the highest
# `published_at`, the first one wins a tie, D6): `--platform` and a package, or a platform and no `--platform`, stop before the pick (R-AD32, R-AD33). The alias is
# checked here too (R-AD14 to R-AD18). The header of the newest candidate is a fact for the pick.
prepare! : Fx, ResolveBase.Request, Loaded, List(Fresh), List(Candidates) => Try(Prepared, Fail)
prepare! = |fx, request, loaded, fresh, found| {
	header = ResolveBase.current_rows(loaded.members, request.project.file ?? "")
	var $rows = no_rows
	var $facts = no_facts
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
		read = ResolveBase.read_releases!(fx, request, [first.url], Bool.True)?
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

# The candidate with the highest `published_at`. A tie keeps the first (the rule of `Index.new_entry`).
newest : List(Index.Candidate) -> Try(Index.Candidate, [ListWasEmpty])
newest = |list| match list {
	[] => Err(ListWasEmpty)
	[first, .. as rest] => Ok(rest.fold(first, |best, c| if c.published_at > best.published_at c else best))
}

no_rows : List(FreshRow)
no_rows = []

no_facts : List(Fact)
no_facts = []
