import records.Closure as Wire
import records.Release as WireRelease
import ClosureIndex
import Fail
import FullName
import Fx
import Help
import Ident
import IndexQuery
import LogSnapshot
import PickIndex
import ResolveBase
import Successor
import Vars

## Slice 252 (docs/slices/252-successor-follow.md; Registry R-PU28, R-TP14, R-SN8; Resolution R-UP3; Design Q632). Command code over `Fx`: `tln update <alias>` and `tln upgrade <alias>` follow the successor of the repository of the alias.
## The decisions are in `Successor` (pure). `PickFlow.prepare!` calls `follow!` after the index of the first closure query (or of the kept copies with `--offline`), before the slots of the pick.
##
## | # | Step | Rule |
## | --- | --- | --- |
## | 1 | Only `update` and `upgrade`. A scoped variable is followed when it is free, one of its aliases is named, and the `repos` item of its name has a successor (`Successor.decide`). `direct` has no `repos`: no follow | R-PU28, B6, Q252-4 |
## | 2 | The walk (`Successor.walk`) with the `repos` items that the run has. A name of the walk with no item is read with R-AP1 (`FullName.read_via!`, the guard included; `--offline`: the kept copy, else exit 15), then the walk goes on. A cut chain and a cycle print `note: <Successor.chain_note>` on stdout | R-TP14, R-SN8, Q252-1, Q252-5, Q252-8 |
## | 3 | The URL form of the end: the group of the newest release that the selector of the alias keeps (`FullName.closure_item`). No such release: exit 2, `no_release` | Q252-3 |
## | 4 | With a registry answer that has no release of the end: one more closure query with the group of the variable on the new form (`IndexQuery.groups`: its series and range, Q252-2), the `hashes` of the header and the window of the first query. The answer is merged into the index of the run (its releases and its `repos`) | Q252-1 (a), Q252-2 (b) |
## | 5 | The variable gets the name of the end and the new URL form (the series stays). Its candidates are the releases of the end (the answer, or the rows of the kept copy with `--offline`) | R-UP3, Q252-10 |
SuccessorFlow :: [].{

	## One followed entry: `alias` is the id of its slot (the alias of its first use), `name` the end of the walk (lower case).
	Follow : { alias : Str, name : Str }

	## The steps of the table above. `kept` are the `repos` items of the kept copies (`PickIndex.counted!` with `--offline`). `keep` and `user` are the `hashes` of the first request and the N of `--snapshot log:N` (the hide of the answer).
	follow! : Fx, ResolveBase.Request, { scoped : List(Vars.Scoped), asked : ResolveBase.Asked, found : List(ResolveBase.Candidates), known : List(Str), entries : List(Str), kept : List(Wire.Repo), keep : List(Str), user : Try(U64, [None]) } => Try({ request : ResolveBase.Request, scoped : List(Vars.Scoped), found : List(ResolveBase.Candidates), follows : List(SuccessorFlow.Follow) }, Fail)
	follow! = |fx, request, facts| {
		unchanged = { request, scoped: facts.scoped, found: facts.found, follows: [] }
		when = match request.command {
			Update | Upgrade => Bool.True
			Install => Bool.False
		}
		if !when or facts.asked.names.is_empty() return Ok(unchanged)
		source = match (request.registry, request.index) {
			(Read(query), Answer(a)) => Ok({ origin: query.origin, source: query.source, snapshot: snapshot_of(query.snapshot), online: Ok({ query, answer: a.answer }) })
			(_, Offline(origin)) => Ok({ origin, source: "", snapshot: Err(None), online: Err(None) })
			_ => Err(Direct)
		}
		reg = match source {
			Ok(r) => r
			Err(Direct) => return Ok(unchanged)
		}
		var $request = request
		var $repos = match reg.online {
			Ok(o) => o.answer.repos.concat(facts.kept)
			Err(None) => facts.kept
		}
		var $rows = no_rows
		var $read = no_names
		var $scoped = no_scoped
		var $found = facts.found
		var $follows = no_follows
		for s in facts.scoped {
			alias = s.variable.uses.first().map_ok(|u| u.alias) ?? ""
			named = s.free and s.variable.uses.any(|u| facts.asked.names.contains(u.alias))
			start = match s.variable.name {
				Ok(n) if named => Ok(n)
				_ => Err(None)
			}
			wanted = match start {
				Ok(n) => Successor.decide({ named, item: item_of($repos, n) })
				Err(None) => Stay
			}
			match (wanted, start) {
				(Follow(_), Ok(old)) => {
					# Step 2: the walk, with an R-AP1 read of each name that has no `repos` item (each name once; the walk has at most 4 links).
					var $walk = Successor.walk({ start: old, repos: as_moved($repos, old) })
					var $go = $walk.state == Unknown
					while $go {
						end = $walk.end
						got = read!(fx, $request, reg, end, facts.known)?
						$repos = $repos.concat(got.repos)
						$rows = $rows.concat(got.releases)
						$read = $read.append(end)
						$walk = Successor.walk({ start: old, repos: as_moved($repos, old) })
						$go = $walk.state == Unknown and !$read.contains($walk.end)
					}
					walked = $walk
					match Successor.chain_note({ alias, start: old, end: walked.end, stop: walked.stop }) {
						Ok(text) => fx.out!("note: ${text}\n")
						Err(None) => {}
					}
					end = walked.end
					# The release rows of the end: the answer of the run, else the R-AP1 rows (read now when the run has none).
					in_answer = match $request.index {
						Answer(a) => rows_of(a.answer.releases, end)
						_ => no_rows
					}
					if in_answer.is_empty() and rows_of($rows, end).is_empty() and !$read.contains(end) {
						got = read!(fx, $request, reg, end, facts.known)?
						$repos = $repos.concat(got.repos)
						$rows = $rows.concat(got.releases)
						$read = $read.append(end)
					}
					end_rows = if in_answer.is_empty() rows_of($rows, end) else in_answer
					# Step 3: the URL form of the end.
					selector = facts.asked.picks.find_first(|p| s.variable.uses.any(|u| u.alias == p.alias)).map_ok(|p| p.selector).map_err(|_| None)
					form = match FullName.closure_item({ releases: { releases: end_rows, checked: Err(None), repos: [] }, selector, text: "", range: "" }) {
						Ok(item) => item.group
						Err(NoMatch) => return Err(SuccessorFlow.no_release({ alias, name: end }))
					}
					moved = { ..s, variable: { ..s.variable, name: Ok(end), group: { form, series: s.variable.group.series } } }
					# Step 4: the closure query of the end, when the answer has no release of it.
					list = match ($request.index, reg.online) {
						(Answer(a), Ok(o)) => {
							answer = if in_answer.is_empty() {
								second = ClosureIndex.query!(fx, { origin: o.query.origin, version: Help.version, facts: { groups: IndexQuery.groups([moved]), entries: facts.entries, window: o.query.window }, source: o.query.source })?
								shown = match facts.user {
									Ok(n) => LogSnapshot.hide_above(second, { n, keep: facts.keep })
									Err(None) => second
								}
								merged = LogSnapshot.merged({ first: a.answer, second: shown })
								{ ..merged, repos: with_repos(a.answer.repos, shown.repos) }
							} else {
								a.answer
							}
							$request = { ..$request, index: Answer({ origin: a.origin, answer: { ..answer, repos: with_repos(answer.repos, $repos) } }) }
							counted = PickIndex.counted!(fx, $request, [end], facts.known)?
							counted.found.first().map_ok(|c| c.list) ?? []
						}
						_ => ClosureIndex.candidates({ releases: ClosureIndex.live({ releases: end_rows, held: facts.known }), artifacts: [], name: end })
					}
					# Step 5.
					$found = $found.keep_if(|c| c.name != end).append({ name: end, list, missing: Bool.False, missing_forms: [], pages: [] })
					$scoped = $scoped.append(moved)
					$follows = $follows.append({ alias, name: end })
				}
				_ => {
					$scoped = $scoped.append(s)
				}
			}
		}
		Ok({ request: $request, scoped: $scoped, found: $found, follows: $follows })
	}

	## Q252-3 (a) (the text is approved, slice 252 section 7): the successor has no release that Talon can use. Kind `Usage` (exit 2). Nothing is written.
	no_release : SuccessorFlow.Follow -> Fail
	no_release = |f| Fail.new(Usage, "${f.alias}: ${f.name} has no release that Talon can use. The header is not changed.")

	## Q252-3: after the pick, each followed slot must have a release of its successor. A slot that kept its old value (no release of the successor was usable: `min-release-age`, the series, yanked) stops the command.
	check : List(SuccessorFlow.Follow), List({ id : Str, url : Str }) -> Try({}, Fail)
	check = |follows, chosen| {
		bad = follows.find_first(
			|f| match chosen.find_first(|c| c.id == f.alias) {
				Ok(c) => match Ident.of_url(c.url) {
					Ok(ident) => (ident.name.map_ok(|n| n.with_ascii_lowercased()) ?? "") != f.name
					Err(_) => Bool.True
				}
				Err(_) => Bool.False
			},
		)
		match bad {
			Ok(f) => Err(SuccessorFlow.no_release(f))
			Err(_) => Ok({})
		}
	}
}

# The R-AP1 read of one name of the walk (`FullName.read_via!`). `--offline`: the kept copy (no copy: exit 15, `Github.no_page_failure`).
read! : Fx, ResolveBase.Request, { origin : Str, source : Str, snapshot : Try(U64, [None]), online : a }, Str, List(Str) => Try({ releases : List(WireRelease.Row), repos : List(Wire.Repo) }, Fail)
read! = |fx, request, reg, name, known| {
	got = FullName.read_via!(fx, { net: request.net, roots: request.roots, origin: reg.origin, version: Help.version, now: request.now, offline: request.offline, name, selector: Err(None), snapshot: reg.snapshot, known, source: reg.source })?
	match got {
		Found(r) => Ok({ releases: r.releases, repos: r.repos })
		NoMatch | SourceBuild => Ok({ releases: no_rows, repos: [] })
	}
}

snapshot_of : [None, Time(U64), Log(U64)] -> Try(U64, [None])
snapshot_of = |snapshot| match snapshot {
	Log(n) => Ok(n)
	_ => Err(None)
}

# The `repos` item of a name (any case), as `AuditCheck.state_of` finds it.
item_of : List(Wire.Repo), Str -> Try(Wire.Repo, [None])
item_of = |repos, name| repos.find_first(|p| p.name.with_ascii_lowercased() == name.with_ascii_lowercased()).map_err(|_| None)

# Q252-4, B7: the first link is taken whatever the state of the start (a `missing` item with a successor follows too), so the walk sees the start as `moved`. The other names keep their state (R-SN8).
as_moved : List(Wire.Repo), Str -> List(Wire.Repo)
as_moved = |repos, start| repos.map(|p| if p.name.with_ascii_lowercased() == start.with_ascii_lowercased() { ..p, state: Moved } else p)

# The release rows of a repository (any case).
rows_of : List(WireRelease.Row), Str -> List(WireRelease.Row)
rows_of = |rows, name| rows.keep_if(
	|r| match r.repo {
		Ok(repo) => repo.with_ascii_lowercased() == name.with_ascii_lowercased()
		Err(_) => Bool.False
	},
)

# The `repos` items of both lists, each name once (the first list wins).
with_repos : List(Wire.Repo), List(Wire.Repo) -> List(Wire.Repo)
with_repos = |first, more| more.fold(first, |list, p| if list.any(|q| q.name.with_ascii_lowercased() == p.name.with_ascii_lowercased()) list else list.append(p))

no_rows : List(WireRelease.Row)
no_rows = []

no_names : List(Str)
no_names = []

no_scoped : List(Vars.Scoped)
no_scoped = []

no_follows : List(SuccessorFlow.Follow)
no_follows = []
