import Db
import Ident
import Intent
import Pick
import Ranges
import Release
import Vars

## The pure decisions of `tln upgrade` that follow the pick (slice 038, Resolution 10): the variables that did not get their newest release (R-UP2), and the keys of `talon.toml` that move with a version (R-UP5).
## Split from `Upgrade` so that `PickFlow` can call it: `Upgrade` imports `Resolve`, which imports `PickFlow`.
Lags :: [].{

	## One free variable that did not get its newest release (R-UP2). `alias` is the first alias of the slot, `newest` and `got` are versions. `why` is the first reason, by the table of `of`.
	Lag : { alias : Str, newest : Str, got : Str, why : Str }

	## R-UP2: the free variables (`hold: Free`) whose chosen release is not the newest release of their domain, in the order of the slots. The domain is the one of `Pick.step` (R-C6, R-C7, R-C9: a young release is no candidate, the header value stays),
	## and in `upgrade` it has no range (R-UP1). `facts` are the headers that the command read, `checks` and `used` are the facts of the probe rounds for the held compiler `compiler` (`Err(None)`: no probe).
	## The newest release `n` of the slot `a`, the chosen release `c`, and the reason, the first that holds in this order (the text is a proposal, TW24):
	##
	## | # | Reason | `why` |
	## | --- | --- | --- |
	## | 1 | The db has a real row of `n` on the compiler that touches the app: a hang, a crash, a fail with no module, a fail with `main.roc`, or a fail with a module that `used` lists for `n` (R-UM1, R-EP7) | `fails the unit check on <compiler>`, `hangs the unit check on <compiler>`, `crashes the unit check on <compiler>` |
	## | 2 | The header of `n` names a platform URL that is not the chosen URL of the platform slot (R-C3). `n` is a package. | `needs <alias of the platform slot> <version of the platform that it names>` |
	## | 3 | The header of `n` has a dep in the group of another slot, with a version above the chosen version of that slot (R-C2). The first such dep, in the order of the header, then of the slots. | `needs <alias of that slot> >= <dep version>` |
	## | 4 | `n` is a platform, and the header of a chosen package names another platform URL (R-C3). The first such slot. | `<alias of that slot> <its chosen version> needs <alias of n> <version of the platform that it names>` |
	## | 5 | None of these | `it does not fit the closure of the tuple` |
	##
	## A release with no header fact skips the reasons 2 and 3.
	of : Input -> List(Lags.Lag)
	of = |input| input.slots.map2(input.chosen, |slot, c| (slot, c)).keep_oks(|(slot, c)| lag_of(input, slot, c))

	## The text of a lag, for the line `note: <text>` (a proposal, TW24): `<alias> <newest> is not used, <got> is chosen: <why>`.
	note : Lags.Lag -> Str
	note = |lag| "${lag.alias} ${lag.newest} is not used, ${lag.got} is chosen: ${lag.why}"

	## R-UP5: the keys of `talon.toml` that move with a version. A move is a use of a moved variable (`file` is the member file, `alias` its header alias, `version` the new version). For each move whose member has the key `alias` in `[dependencies]`:
	## `Ranges.rewrite` of its range. A key that is not there gets no pair (Talon adds no key and does not create the file). A range that admits the version, and a range with no form (`Err(NoForm)`), get no pair (the second gets a note: `Lags.stuck`).
	## The value keeps the name of a value in the form `<name>@<range>` (R-I2). A key of `[overrides]` is not read (question Q3). One pair for each (file, key), in the order of the moves.
	rewrites : { members : List(Vars.Member), moves : List({ file : Str, alias : Str, version : Str }) } -> List({ path : Str, key : Str, value : Str })
	rewrites = |facts| changes_of(facts.members, facts.moves).keep_oks(
		|c| match c.new {
			Ok(range) if range != c.dep.range => Ok({ path: c.path, key: c.key, value: with_name(c.dep, range) })
			_ => Err(Stays)
		},
	)

	## Q1 (b) of slice 038: the notes for the keys that stay. A key of `[dependencies]` of a moved alias whose range has no form (`Ranges.rewrite` is `Err(NoForm)`) and does not admit the new version.
	## The text (TW24): `talon.toml: <key>: the range does not admit <version>, change it by hand`. One note for each (file, key), in the order of the moves. A key that is not there, and a range that admits the version, give no note.
	stuck : { members : List(Vars.Member), moves : List({ file : Str, alias : Str, version : Str }) } -> List(Str)
	stuck = |facts| changes_of(facts.members, facts.moves).keep_oks(
		|c| match c.new {
			Err(NoForm) => Ok("talon.toml: ${c.key}: the range does not admit ${c.version}, change it by hand")
			Ok(_) => Err(Fine)
		},
	)

	## Q6 (a) of slice 038: the value that a key of `[dependencies]` has now, in the form of `Lags.rewrites` (`<name>@<range>` or `<range>`), for `(was "<old>")` on the line of the key. `Err(None)` when the file has no such key.
	was : { members : List(Vars.Member), path : Str, key : Str } -> Try(Str, [None])
	was = |facts| match facts.members.join_map(|m| deps_under(m, facts.path)).find_first(|d| d.key == facts.key) {
		Ok(d) => Ok(with_name(d, d.range))
		Err(_) => Err(None)
	}
}

Input : {
	slots : List(Pick.Slot),
	chosen : List(Pick.Chosen),
	facts : List({ url : Str, release : Release }),
	now : U64,
	min_age : U64,
	snapshot : Try(U64, [None]),
	compiler : Try(Str, [None]),
	checks : List(Db.Fact),
	used : List({ id : Str, modules : List(Str) }),
}

Change : { path : Str, key : Str, dep : Intent.Dep, version : Str, new : Try(Str, [NoForm]) }

Pair : { slot : Pick.Slot, chosen : Pick.Chosen }

# The keys of `[dependencies]` that the moves touch: one row for each (file, key), in the order of the moves, with the rewritten range (R-UP5). A key of `[overrides]` is not read (Q3).
changes_of : List(Vars.Member), List({ file : Str, alias : Str, version : Str }) -> List(Change)
changes_of = |members, moves| moves.fold(
	[],
	|found, mv| match key_of(members, mv.file, mv.alias) {
		Err(_) => found
		Ok(hit) => if found.any(|f| f.path == hit.path and f.key == mv.alias) {
			found
		} else {
			found.append({ path: hit.path, key: mv.alias, dep: hit.dep, version: mv.version, new: Ranges.rewrite({ range: hit.dep.range, version: mv.version }) })
		}
	},
)

# The key of `alias` in the `[dependencies]` of the `talon.toml` of the member `file`.
key_of : List(Vars.Member), Str, Str -> Try({ path : Str, dep : Intent.Dep }, [None])
key_of = |members, file, alias| match members.find_first(|m| m.file == file) {
	Err(_) => Err(None)
	Ok(m) => match m.toml {
		Err(NoToml) => Err(None)
		Ok(t) => match t.intent.deps.find_first(|d| d.key == alias) {
			Ok(d) => Ok({ path: t.path, dep: d })
			Err(_) => Err(None)
		}
	}
}

# The keys of `[dependencies]` of a member whose `talon.toml` is `path`.
deps_under : Vars.Member, Str -> List(Intent.Dep)
deps_under = |m, path| match m.toml {
	Ok(t) => if t.path == path t.intent.deps else []
	Err(NoToml) => []
}

# R-I2: the value of a key keeps its `<name>@` with a new range.
with_name : Intent.Dep, Str -> Str
with_name = |dep, range| match dep.name {
	Ok(name) => "${name}@${range}"
	Err(None) => range
}

# The first `Ok` of the list (nested `match`: a `keep_oks(...).first()` of a list of `Try` crashed the app, slice 038 section 8, C2).
first_ok : List(Try(Str, [None])) -> Try(Str, [None])
first_ok = |list| match list {
	[] => Err(None)
	[r, .. as rest] => match r {
		Ok(text) => Ok(text)
		Err(_) => first_ok(rest)
	}
}

# R-UP2: the lag of one slot. Only a free slot has one.
lag_of : Input, Pick.Slot, Pick.Chosen -> Try(Lags.Lag, [NoLag])
lag_of = |input, slot, c| match slot.hold {
	Free => match Pick.newest(slot, { now: input.now, min_age: input.min_age, snapshot: input.snapshot, facts: input.facts }) {
		Ok(n) => if n.url == c.url {
			Err(NoLag)
		} else {
			Ok({ alias: slot.id, newest: n.ident.version, got: c.version, why: why_of(input, slot, n.url) })
		}
		Err(None) => Err(NoLag)
	}
	_ => Err(NoLag)
}

# The first reason that holds, in the order of the table of `Lags.of`.
why_of : Input, Pick.Slot, Str -> Str
why_of = |input, slot, url| {
	pairs = input.slots.map2(input.chosen, |s, c| { slot: s, chosen: c })
	by_header = match input.facts.find_first(|f| f.url == url) {
		Ok(f) => [pf_reason(pairs, slot, f.release), dep_reason(pairs, f.release)]
		Err(_) => []
	}
	first_ok([probe_reason(input, url)].concat(by_header).append(platform_reason(input, pairs, slot, url))) ?? "it does not fit the closure of the tuple"
}

# Reason 1 (R-UM1, R-EP7): a real row of the release on the held compiler that touches the app.
probe_reason : Input, Str -> Try(Str, [None])
probe_reason = |input, url| match (input.compiler, Ident.of_url(url)) {
	(Ok(held), Ok(ident)) => {
		modules = input.used.find_first(|u| u.id == url).map_ok(|u| u.modules) ?? []
		touches = |r| match r.outcome {
			Pass => Bool.False
			Fail => r.modules.is_empty() or r.modules.any(|m| m == "main.roc" or modules.contains(m))
			_ => Bool.True
		}
		match input.checks.find_first(|r| r.hash == ident.hash and r.nightly == held and r.target == "any" and touches(r)) {
			Ok(r) => Ok("${outcome_word(r.outcome)} the unit check on ${held}")
			Err(_) => Err(None)
		}
	}
	_ => Err(None)
}

outcome_word : Db.Outcome -> Str
outcome_word = |outcome| match outcome {
	Hang => "hangs"
	Crash => "crashes"
	_ => "fails"
}

# The version that a platform URL has.
version_of : Str -> Try(Str, [None])
version_of = |url| Ident.of_url(url).map_ok(|ident| ident.version).map_err(|_| None)

# Reason 2 (R-C3): the newest package names another platform than the chosen one.
pf_reason : List(Pair), Pick.Slot, Release -> Try(Str, [None])
pf_reason = |pairs, slot, release| match (slot.is_platform, release.pf, pairs.find_first(|p| p.slot.is_platform)) {
	(Bool.False, Ok(pf), Ok(p)) if pf != p.chosen.url => version_of(pf).map_ok(|v| "needs ${p.slot.id} ${v}")
	_ => Err(None)
}

# Reason 3 (R-C2): the newest release has a dep in the group of another slot, above the chosen version. The first dep, then the first slot.
dep_reason : List(Pair), Release -> Try(Str, [None])
dep_reason = |pairs, release| first_ok(
	release.deps.map(
		|dep| match Ident.of_url(dep) {
			Ok(d) => first_ok(
				pairs.map(
					|p| match Ident.of_url(p.chosen.url) {
						Ok(c) if c.group == d.group and Pick.newer(d.version, c.version) => Ok("needs ${p.slot.id} >= ${d.version}")
						_ => Err(None)
					},
				),
			)
			Err(_) => Err(None)
		},
	),
)

# Reason 4 (R-C3): the newest release is a platform that a chosen package does not name. The first such slot.
platform_reason : Input, List(Pair), Pick.Slot, Str -> Try(Str, [None])
platform_reason = |input, pairs, slot, url| if slot.is_platform {
	first_ok(
		pairs.map(
			|p| if p.slot.is_platform {
				Err(None)
			} else {
				match input.facts.find_first(|f| f.url == p.chosen.url) {
					Ok(f) => match f.release.pf {
						Ok(pf) if pf != url => version_of(pf).map_ok(|v| "${p.slot.id} ${p.chosen.version} needs ${slot.id} ${v}")
						_ => Err(None)
					}
					Err(_) => Err(None)
				}
			},
		),
	)
} else {
	Err(None)
}
