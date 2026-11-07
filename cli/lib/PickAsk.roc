import Add
import Alias
import Closure
import Fail
import Fallback
import Fx
import Help
import Ident
import Lookup
import Ref
import ResolveBase
import Scope
import Selector
import ShortNames
import Vars

## The names step of the pick (slice 031b: split from `PickFlow`): the operands of `install`, `update` and `add` become the asked names, the picks of selectors, the kept entries and the new entries.
PickAsk :: [].{

	# The names of `update` and `install` (slice 004: `Ref.parse`, `Lookup.find`). A name of `update` is an alias of the project. A name of `install` is `tln add`
	# (R-SP18): a header alias, or a full name that has one entry in the current member (D5), or a new entry.
	asked! : Fx, ResolveBase.Request, ResolveBase.Loaded, List(Vars.Var) => Try(ResolveBase.Asked, Fail)
	asked! = |fx, request, loaded, vars| {
		# Slice 225 (R-RG9): the short-name read is the first registry request of the run, so it can fall back to `direct`. A failure after it carries the note.
		current = request.project.file ?? ""
		scope = if request.command != Install Scope.Project else Scope.Install
		entities = if request.command != Install entities_of(vars, loaded.members) else entities_of(in_file(vars, current), loaded.members.keep_if(|m| m.file == current))
		texts = if request.command == Upgrade request.names.keep_if(|name| name != "roc") else request.names
		got = short_names!(fx, request, scope, entities, texts)?
		asked = asked_with!(fx, request, loaded, vars, got.entries).map_err(|fail| Fail.with_fell(fail, got.fell))?
		Ok({ ..asked, fell: got.fell, answered: !got.entries.is_empty() })
	}

	asked_with! : Fx, ResolveBase.Request, ResolveBase.Loaded, List(Vars.Var), List({ ref : Ref, lookup : Lookup, matched : Try(Str, [None]) }) => Try(ResolveBase.Asked, Fail)
	asked_with! = |fx, request, loaded, vars, shorts| {
		current = request.project.file ?? ""
		scope = if request.command != Install Scope.Project else Scope.Install
		rows = ResolveBase.current_rows(loaded.members, current)
		entities = if request.command != Install entities_of(vars, loaded.members) else entities_of(in_file(vars, current), loaded.members.keep_if(|m| m.file == current))
		var $names = ResolveBase.no_names
		var $picks = no_picks
		var $kept = no_kept
		var $fresh = no_fresh
		var $shorted = 0
		texts = if request.command == Upgrade request.names.keep_if(|name| name != "roc") else request.names
		# Slice 206f (R-AD34, R-I8, Design Q223): with a registry, the short names of the command are read with one request, before any other registry call.
		for text in texts {
			parsed = Ref.parse(text, scope, Bool.False)?
			short = if shorts.is_empty() Err(None) else if Lookup.needs_registry(scope, parsed, entities) shorts.get($shorted).map_err(|_| None) else Err(None)
			if short.is_ok() {
				$shorted = $shorted + 1
			}
			ref = match short {
				Ok(entry) => entry.ref
				Err(None) => parsed
			}
			looked = match short {
				Ok(entry) => Ok(entry.lookup)
				Err(None) => if request.command != Install Lookup.find_move(scope, ref, entities) else add_lookup(request, ref, entities)
			}
			found = match looked {
				Ok(f) => f
				Err({ fail, block }) => {
					if !block.is_empty() fx.err!(block)
					return Err(fail)
				}
			}
			target = match found {
				# R-H9: an unmanaged entry has no name. `update X` never moves it.
				Lookup.Existing({ alias: a, name: "", .. }) if request.command != Install => return Err(Add.never_changes({ alias: a, value: unmanaged_value(loaded.members, a) }))
				Lookup.Existing({ alias: a, .. }) => Ok(a)
				Lookup.New(name) => if request.command != Install {
					return Err(Fail.new(Usage, "'${name}' is not in the project"))
				} else {
					entry_of_repo(request, vars, current, name)?
				}
			}
			match target {
				Ok(alias) => if request.command != Install {
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
							$kept = $kept.append(kept_of(vars, current, alias, plan))
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
					$fresh = $fresh.append(fresh_of(request, loaded, current, ref, text)?)
				}
			}
		}
		Ok({ names: $names, picks: $picks, kept: $kept, fresh: $fresh, fell: Err(None), answered: Bool.False })
	}

	# R-SL5, R-AD22: the range that a selector gives to its variable. `Latest` is any version.
	range_of_selector : Selector -> Try(Str, [None])
	range_of_selector = |selector| match selector {
		Exact(version) => Ok("=${version}")
		Range(text) => Ok(text)
		Latest => Ok("*")
		_ => Err(None)
	}

	# R-AL9, D6: for each member, the header entries that no slot owns (a path value or a foreign URL). The entry that the run replaces (`--as`, `--platform`) is no root: the new entry is a slot.
	unmanaged_of : ResolveBase.Loaded, ResolveBase.Asked, Str -> List({ file : Str, entries : List(Closure.Entry) })
	unmanaged_of = |loaded, asked, current| {
		replaced = asked.fresh.map(|f| f.key)
		loaded.members.map(
			|m| {
				file: m.file,
				entries: m.locked.rows
					.keep_if(|r| Ident.of_url(r.value).is_err() and !(m.file == current and replaced.contains(r.alias)))
					.map(|r| { alias: r.alias, value: r.value, is_platform: r.is_platform }),
			},
		)
	}
}

# Slice 206f (R-AD3 to R-AD5, R-AD34, R-I8, Design Q223): the short names of `add` and `install <names>` with a registry. A name that `Lookup.needs_registry` selects is a short name; all of them go in one `ShortNames.lookup!`, then `Lookup.registry_all`.
# The `matched "<short>": <name>` lines are printed at once, in the order of the names (R-AD3). A failure prints its block on stderr and stops the command (exit 2, or 15 for `--offline` with no copy). No registry (`direct`), or a command other than `Install`: `[]`, no call.
# The result has one entry for each short name, in the order of the command.
short_names! : Fx, ResolveBase.Request, Scope, List(Lookup.Entity), List(Str) => Try({ entries : List({ ref : Ref, lookup : Lookup, matched : Try(Str, [None]) }), fell : Try({ registry : Str, cause : Str }, [None]) }, Fail)
short_names! = |fx, request, scope, entities, texts| {
	source = match (request.registry, request.index) {
		(Read(query), _) => Ok({
			origin: query.origin,
			snapshot: match query.snapshot {
				Log(n) => Ok(n)
				_ => Err(None)
			},
			source: query.source,
		})
		(_, Offline(origin)) => Ok({ origin, snapshot: Err(None), source: "" })
		_ => Err(Direct)
	}
	if request.command != Install {
		return Ok({ entries: [], fell: Err(None) })
	}
	match source {
		Err(Direct) => Ok({ entries: [], fell: Err(None) })
		Ok(registry) => {
			refs = texts.keep_oks(|text| Ref.parse(text, scope, Bool.False)).keep_if(|ref| Lookup.needs_registry(scope, ref, entities))
			if refs.is_empty() {
				return Ok({ entries: [], fell: Err(None) })
			}
			looked = ShortNames.lookup_via!(fx, { roots: request.roots, origin: registry.origin, version: Help.version, now: request.now, offline: request.offline, snapshot: registry.snapshot, shorts: refs.map(|ref| ref.name), source: registry.source })
			# R-RG9 (Design Q601): no answer from the built-in default at this first request: the run goes on as `direct`, which has no short names.
			found = match looked {
				Ok(list) => list
				Err(fail) => return Ok({ entries: [], fell: Ok(Fallback.decide!(fx, fail, registry.origin)?) })
			}
			match Lookup.registry_all(scope, refs.map2(found, |ref, one| { ref, found: one })) {
				Ok(entries) => {
					for entry in entries {
						match entry.matched {
							Ok(line) => fx.out!("${line}\n")
							Err(None) => {}
						}
					}
					Ok({ entries, fell: Err(None) })
				}
				Err({ fail, block }) => {
					if !block.is_empty() fx.err!(block)
					Err(fail)
				}
			}
		}
	}
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

# The value of the entry of an alias, as written (the first member that has it).
unmanaged_value : List(Vars.Member), Str -> Str
unmanaged_value = |members, alias| match members.join_map(|m| m.locked.rows).find_first(|r| r.alias == alias) {
	Ok(row) => row.value
	Err(_) => alias
}

# The `ResolveBase.Kept` row of a header alias: its name and version are those of its entry in the current member. An unmanaged entry has no name: its value as written is the name (R-AD21).
kept_of : List(Vars.Var), Str, Str, Add -> ResolveBase.Kept
kept_of = |vars, current, alias, plan| match in_file(vars, current).find_first(|v| v.uses.any(|u| u.alias == alias)) {
	Ok(v) => {
		version = match v.uses.find_first(|u| u.alias == alias) {
			Ok(u) => u.version
			Err(_) => ""
		}
		{ alias, name: v.name ?? v.group.form, version, note: plan.note ?? "" }
	}
	Err(_) => { alias, name: plan.url, version: "", note: plan.note ?? "" }
}

# A new name of `add`. R-WS12: a group that another member holds is held. The new entry is a free slot of that group with its own range: the pick gives it the held version (R-WS2, R-WS3), or the second search moves the group.
fresh_of : ResolveBase.Request, ResolveBase.Loaded, Str, Ref, Str -> Try(ResolveBase.Fresh, Fail)
fresh_of = |request, loaded, current, ref, text| {
	name = ref.name
	key = match request.add.as_alias {
		Ok(alias) => alias
		Err(Unset) => if request.add.as_platform platform_alias(loaded, current) else Alias.default(name)
	}
	typed = match ref.selector {
		Ok(Latest) | Err(None) => replaced_key_range(loaded, current, key) ?? "*"
		Ok(selector) => PickAsk.range_of_selector(selector) ?? "*"
	}
	Ok({
		name,
		selector: ref.selector,
		text: match text.split_first("@") {
			Ok({ after, .. }) => after
			Err(_) => "latest"
		},
		range: typed,
		key,
		is_platform: request.add.as_platform,
	})
}

# C3, R-AD31, R-AD38: `--platform` with no `--as` replaces the platform entry of the current member, so the new entry has its alias (else `pf`).
platform_alias : ResolveBase.Loaded, Str -> Str
platform_alias = |loaded, current| ResolveBase.current_rows(loaded.members, current).find_first(|r| r.is_platform).map_ok(|r| r.alias) ?? "pf"

# Q1, R-AD38, R-I3: `--as <alias>` over an unmanaged entry with no selector. The key of that alias in the `talon.toml` of the member stays, so it is the range of the new entry.
# It is no constraint before the replace (R-H9), so `Vars` does not give it.
replaced_key_range : ResolveBase.Loaded, Str, Str -> Try(Str, [NoKey])
replaced_key_range = |loaded, file, alias| match loaded.members.find_first(|m| m.file == file) {
	Ok({ locked, toml: Ok(t), .. }) => match locked.rows.find_first(|r| r.alias == alias) {
		Ok({ what: Release(_), .. }) | Err(_) => Err(NoKey)
		Ok(_) => match t.intent.deps.concat(t.intent.overrides).find_first(|d| d.key == alias) {
			Ok(d) => Ok(d.range)
			Err(_) => Err(NoKey)
		}
	}
	_ => Err(NoKey)
}

no_picks : List({ alias : Str, selector : Selector })
no_picks = []

no_kept : List(ResolveBase.Kept)
no_kept = []

no_fresh : List(ResolveBase.Fresh)
no_fresh = []

# The entities of the lookup: one for each header alias (`Lookup.build`: one entity builder). A path entry and a foreign URL are entities with no name (R-SC6, R-H4).
entities_of : List(Vars.Var), List(Vars.Member) -> List(Lookup.Entity)
entities_of = |vars, members| Lookup.build(
	vars.join_map(
		|v| v.uses.map(
			|u| {
				alias: u.alias,
				what: Release({ name: v.name ?? v.group.form, series: v.group.series, version: u.version }),
				role: if v.is_platform Platform else Direct,
			},
		),
	).concat(
		members.join_map(
			|m| m.locked.rows.keep_oks(
				|r| match r.what {
					Release(_) => Err(NotUnmanaged)
					_ => Ok({ alias: r.alias, what: Unmanaged, role: if r.is_platform Platform else Direct })
				},
			),
		),
	),
)

# `add` of a header alias or a new name is `Lookup.find`. A full name that 2 or more entries of the member have moves one of them (slice 014 Q1, R-SC16),
# unless `--as` or `--platform` makes a new entry. One entry is `entry_of_repo`.
add_lookup : ResolveBase.Request, Ref, List(Lookup.Entity) -> Try(Lookup, { fail : Fail, block : Str })
add_lookup = |request, ref, entities| match Lookup.find(Scope.Install, ref, entities) {
	Ok(New(name)) if !request.add.as_platform and request.add.as_alias == Err(Unset) and entities.keep_if(|e| e.name == name).len() >= 2 => Lookup.find_move(Scope.Install, ref, entities)
	other => other
}
