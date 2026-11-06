import Args
import Common
import Facts
import Fail
import Fetch
import Fx
import Ident
import IndexQuery
import Install
import InstallFlow
import Known
import Ls
import Nightlies
import Out
import Outdated
import PickFlow
import PickIndex
import PickLoop
import ResolveBase
import ResolveLoad
import Vars

## The command code of `tln outdated` (slice 040, R-CM6, TESTING.md 2.2 part C). The pure part is `Outdated`. It resolves nothing, runs no probe, downloads no archive and no compiler, and writes no header and no `talon.toml`.
##
## The steps of `run!`, in order (the L2 cases `outdated/od1-table` and `outdated/od2-edges` fix the calls):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `Outdated.read(args)`. A failure is printed with `Common.failed!` (no `Fx` call) | R-FL5, R-FL7, R-CM6 |
## | 2 | `Install.begin!`, then `Known.record!` of the canonical member files (the only write of the run besides the index cache and the compiler list pins) | R-PD1 to R-PD9, R-PD14 |
## | 3 | `ResolveLoad.load!`: the member files and the `talon.toml` files (one `read_files!`). The members are the current member, else all members (as `tln list`) | R-PD5, R-PD6 |
## | 4 | `Vars.build` for each member: the groups, the ranges, the host | R-ID2, R-I2 to R-I4, R-WS1 |
## | 5 | `PickIndex.index!` for the groups of the `Indexed` hosts, one call for all of them (R-DI1: the rows of `tln outdated` are listed). No call when there is no such group. `--offline` uses the cache pages (R-DI12). | R-DI1, R-DI2, R-DI12 |
## | 6 | `Outdated.versions` for each group | R-C1, R-C6, R-C7, R-UP1 |
## | 7 | Only when a row is behind: the compiler list (`PickLoop.releases!`, at most once), then one `Facts.load!` for the keys (hash, release of D, `any`) of the rows. An empty or unread list gives `Unread` and no query | R-EP11, R-EF1 |
## | 8 | The output (below) | R-J1 to R-J6, R-FL4, R-OUT4 |
##
## Slice 206e2 (R-CV1, R-AP16, R-AP74 row 4, R-RG1, R-RG4, R-DI1): with a registry (`--registry`, `TALON_REGISTRY`, `config.toml`: `InstallFlow.setting_of` after step 3), before step 5: the registry compiler list (`PickLoop.first_releases!`, also when no row is behind: the window needs it),
## then the guard and one closure query (`PickFlow.report_query!`) with `IndexQuery.report_groups` of the shown variables and the `Report` window of the list (no `compilers` member when no compiler is allowed: no stop). Step 5 reads the candidates from the answer.
## Step 7 uses that list as D (no second read).
##
## Output. The notes of the index (the offline line, the warnings of `Index.candidates`) go to stderr as in the other commands. stdout is `Outdated.text` of each member, or with `--json` only the envelope
## `Out.json_ok({ command: args.typed, data: Outdated.data(members) })`. The answer is not hidden by `--quiet` (R-FL4). The exit code is 0 when the report was made (question Q3). A failure is printed with `Common.failed!`.
OutdatedFlow :: [].{

	## The exit code of the command (the steps above).
	run! : Fx, Args => I32
	run! = |fx, args| match Outdated.read(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(_) => match flow!(fx, args) {
			Err(fail) => Common.failed!(fx, args, fail)
			Ok(members) => {
				if args.json {
					fx.out!(Out.json_ok({ command: args.typed, data: Outdated.data(members) }))
				} else {
					for member in members {
						fx.out!(Outdated.text(member))
					}
				}
				0
			}
		}
	}
}

# A row with the hash of its current release (the key of its facts), before the range is read.
Pending : { file : Str, rows : List({ row : Outdated.Row, hash : Str }), fixed : List(Str) }

# Steps 2 to 8 of the table above.
flow! : Fx, Args => Try(List(Outdated.Member), Fail)
flow! = |fx, args| {
	start = Install.begin!(fx, args)?
	Known.record!(fx, { roots: start.roots, files: Install.canonical_files!(fx, start.project), now: start.now })?
	asked = { ..Ls.request_of(args, start), command: Update, registry: Setting(args.registry) }
	loaded = ResolveLoad.load!(fx, asked)?
	set = { ..InstallFlow.setting_of(asked, loaded)?, selected: Fetch.selected({ held: "", default: loaded.config.default_roc ?? "" }), none: ResolveBase.no_rank(asked, loaded) }
	# R-WS7: one `Vars.build` over all members, as `ResolveLoad.prepared!`, so a key of one member limits the group for every member.
	built = Vars.build({ members: loaded.members, priority: loaded.intent.resolution.priority })?
	settings = ResolveBase.settings_of(set, loaded)
	current = start.project.file ?? ""
	named = loaded.members.keep_if(|m| m.file == current)
	shown = (if named.is_empty() loaded.members else named).map(|m| m.file)
	vars = built.vars.keep_if(|v| v.uses.any(|u| shown.contains(u.file)))
	names = vars.keep_oks(|v| indexed_name(v)).fold([], |found, name| if found.contains(name) found else found.append(name))
	# Slice 206e2: with a registry the list comes first, then the query with the `Report` window.
	(listed, request) = match set.registry {
		Read(query) => {
			list = PickLoop.first_releases!(fx, set)
			window = Report(ResolveBase.compiler_domain(set, loaded, settings, { releases: list, snapshot: query.snapshot }))
			queried = PickFlow.report_query!(fx, { ..set, registry: Read({ ..query, window, listed: Bool.True }) }, loaded, IndexQuery.report_groups(vars))?
			(Ok(list), queried)
		}
		_ => (Err(NotRead), set)
	}
	found = PickIndex.index!(fx, request, names, built.vars.join_map(|v| v.uses.map(|u| u.url)))?
	pending = shown.map(|file| pending_of(file, vars, found, { now: request.now, min_age: settings.min_age, exclude: settings.exclude }))
	behind = pending.join_map(|p| p.rows)
	# R-DI1, D8: the compiler list and the facts are read only when a row is behind.
	releases = match listed {
		Ok(list) => list
		Err(NotRead) => if behind.is_empty() [] else PickLoop.releases!(fx, request)
	}
	domain = Nightlies.candidates(releases).map(|r| r.id)
	hashes = behind.map(|r| r.hash).fold([], |found_hashes, hash| if found_hashes.contains(hash) found_hashes else found_hashes.append(hash))
	facts = Facts.load!(fx, { roots: request.roots, keys: hashes.join_map(|hash| domain.map(|id| { hash, nightly: id, target: "any" })) })?
	Ok(pending.map(|p| { file: p.file, rows: p.rows.map(|r| { ..r.row, range: Outdated.range_of({ hash: r.hash, domain, facts }) }), fixed: p.fixed }))
}

# The repository of a group with an index (R-DI11: a `Fixed` host has none).
indexed_name : Vars.Var -> Try(Str, [NoIndex])
indexed_name = |v| match (v.host, v.name) {
	(Indexed, Ok(name)) => Ok(name)
	_ => Err(NoIndex)
}

# One member: a row for each group that it uses and that is behind, and the `Fixed` hosts (R-DI11), each once.
pending_of : Str, List(Vars.Var), List(ResolveBase.Candidates), { now : U64, min_age : U64, exclude : List(Str) } -> Pending
pending_of = |file, vars, found, ctx| {
	mine = vars.keep_if(|v| v.uses.any(|u| u.file == file))
	hosts = mine.keep_oks(
		|v| match v.host {
			Fixed(host) => Ok(host)
			Indexed => Err(NoHost)
		},
	)
	{
		file,
		rows: mine.keep_oks(|v| row_of(file, v, found, ctx)),
		fixed: hosts.fold([], |seen, host| if seen.contains(host) seen else seen.append(host)),
	}
}

# R-WS1: the alias and `current` are of the first use in the member. A group that is not behind has no row.
row_of : Str, Vars.Var, List(ResolveBase.Candidates), { now : U64, min_age : U64, exclude : List(Str) } -> Try({ row : Outdated.Row, hash : Str }, [NoRow])
row_of = |file, v, found, ctx| match (indexed_name(v), v.uses.find_first(|u| u.file == file)) {
	(Ok(name), Ok(first)) => {
		list = found.find_first(|c| c.name == name).map_ok(|c| c.list) ?? []
		got = Outdated.versions({ current: first.url, ranges: v.ranges.map(|r| r.range), list, now: ctx.now, min_age: ctx.min_age, exclude: ctx.exclude, snapshot: Err(None) })
		row = { alias: first.alias, name, current: first.version, wanted: got.wanted, latest: got.latest, new_series: got.new_series, range: Unread }
		if Outdated.behind(row) Ok({ row, hash: Ident.of_url(first.url).map_ok(|ident| ident.hash) ?? "" }) else Err(NoRow)
	}
	_ => Err(NoRow)
}
