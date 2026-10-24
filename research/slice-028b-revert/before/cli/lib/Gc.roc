import Args
import Fail
import JsonDoc
import Locked
import Manage
import Roots
import Text

## The pure decisions of `tln cache gc` (slice 028, CLI 6.3, R-GC5, R-GC6, R-GC9, R-GC11, R-CC2, R-CC10, R-PD12, R-PD13). The command code is `CacheGc`. Texts and `data` fields are a proposal (R-OUT2, TW24).
## This slice is part 1 (toolchains, temps, trash, locks, known projects, `--dry-run`). Part 2 (028b: build-cache dirs, `packages/`, sizes) is in the slice file.
##
## | Decision | Function | Rule |
## | --- | --- | --- |
## | The operand and `--dry-run` | `read` | R-GC11 |
## | The age in seconds | `age` | R-GC9 |
## | Which known projects protect something | `projects` | R-PD12, R-PD13 |
## | Which toolchains go | `toolchains` | R-GC5, R-CC10, R-EV22 |
## | Where stale temps can be, and their full paths | `scan_dirs`, `entries` | R-CC2, R-GC6 |
## | The text and the `data` | `report`, `data` | R-OUT2, R-J3 |
Gc :: [].{

	## What the flags say: `--dry-run` (R-GC11).
	Plan : { dry_run : Bool }

	## A known project that protects what it uses: the path of the project file, and the text that `Fx.read_files!` gave for it.
	Project : { path : Str, text : Manage.Read }

	## Why a toolchain stays. `Hand`: a `link-*` or `copy-*` entry (R-GC5: only `tln roc rm` removes it). `Default`: the global default. `LastDay`: used in the last day (R-CC10). `NoTime`: no time is known. `Pinned`: a live known project pins it, whatever its age. `Used`: used in the GC age.
	Why : [Hand, Default, LastDay, NoTime, Pinned, Used]

	## One toolchain, and what GC does with it.
	Choice : { id : Str, verdict : [Remove, Keep(Gc.Why)] }

	## What a run did, or (`dry_run`) would do. `ran` is false when another GC holds the lock (R-CC10): all lists are then empty. `toolchains` and `skipped` are ids, `compat`, `stale` and `projects` are paths.
	Done : { dry_run : Bool, ran : Bool, toolchains : List(Str), skipped : List(Str), compat : List(Str), stale : List(Str), projects : List(Str) }

	## R-GC11, R-CM15: `tln cache gc` takes no operand. 1 or more is a failure of kind `Usage` (exit 2): `tln cache gc takes no operand, got <n>`. `--dry-run` is the only flag of the command (`Args.allows`).
	read : Args -> Try(Gc.Plan, Fail)
	read = |args| match args.operands {
		[] => Ok({ dry_run: args.options.any(|(name, _)| name == "--dry-run") })
		many => Err(Fail.new(Usage, "tln cache gc takes no operand, got ${many.len().to_str()}"))
	}

	## R-GC9: the GC age in seconds. `gc-age` of `config.toml` (`Intent.Config`), else 30 days: 2592000.
	age : Try(U64, [Unset]) -> U64
	age = |set| set ?? 2592000

	## R-PD12, R-PD13: the known projects that protect something. `entries` are the entries of `projects.json` (`Projects.entries`), `reads` is the result of `Fx.read_files!` for each project file, in the same order. `now` is the time of Talon (`TALON_NOW`), `age` is `Gc.age`.
	##
	## An entry goes (`gone`, sorted) when its file is `NotFound`, when the file has no `app`, `package` or `platform` header (`Locked.read` fails), or when `now - last_use` is more than `age` (a time in the future is not old).
	## A file that cannot be read for another reason (`Denied`, `Other`) is not judged: the entry stays in `live` with that read, and it pins nothing. `live` has the other entries, in the order of `entries`.
	projects : { entries : List({ path : Str, last_use : U64 }), reads : List(Manage.Read), now : U64, age : U64 } -> { live : List(Gc.Project), gone : List(Str) }
	projects = |facts| {
		judged = facts.entries.map2(facts.reads, |entry, got| { entry, got, verdict: judge(entry, got, facts.now, facts.age) })
		{
			live: judged.keep_if(|j| j.verdict == Live).map(|j| { path: j.entry.path, text: j.got }),
			gone: Text.sorted(judged.keep_if(|j| j.verdict == Gone).map(|j| j.entry.path)),
		}
	}

	## R-GC5, R-CC10, R-EV22: what GC does with each toolchain, in the order of `rows` (`Manage.rows`: the kind, `installed_at`, the `.last-use` time, the default flag). `projects` is `live` of `Gc.projects`. `now` is the time of Talon (`TALON_NOW`), `age` is `Gc.age`.
	## The used time of a toolchain is its `.last-use` (R-CC9), else its `installed_at`. The first row that fits gives the verdict:
	##
	## | # | Case | Verdict |
	## | --- | --- | --- |
	## | 1 | The kind is `Link` or `Copy` | `Keep(Hand)` |
	## | 2 | The global default (`row.is_default`) | `Keep(Default)` |
	## | 3 | Both times unknown | `Keep(NoTime)` |
	## | 4 | Used in the last day: `now - used` is not more than 86400, or `used` is in the future | `Keep(LastDay)` |
	## | 5 | A project of `projects` pins it (`Manage.pinned_by`), whatever the age of the toolchain (D17: an old nightly can leave the release list, so it may not download again) | `Keep(Pinned)` |
	## | 6 | `now - used` is not more than `age` | `Keep(Used)` |
	## | 7 | All other toolchains: a `git-*` build, a nightly, a release | `Remove` |
	toolchains : { rows : List(Manage.Row), projects : List(Gc.Project), now : U64, age : U64 } -> List(Gc.Choice)
	toolchains = |facts| facts.rows.map(|row| { id: row.id, verdict: verdict_of(row, facts) })

	## R-CC2, R-GC6: the directories that GC lists for stale temps, `.trash` dirs, stale lock dirs and `talon/tmp/` items, in this order: `<cache>/toolchains`, `<cache>/packages`, `<cache>/talon`, `<cache>/talon/tmp`, `<cache>/talon/index`, `<cache>/talon/x`.
	## The config and data dirs are not in the list (question Q3). The first entry is also the listing of the installed compilers.
	scan_dirs : Roots -> List(Str)
	scan_dirs = |roots| ["toolchains", "packages", "talon", "talon/tmp", "talon/index", "talon/x"].map(|sub| Text.join(roots.cache, sub))

	## R-CC2: the entries of the listing of `dirs` (`Fx.list_dirs!`, the results in the same order) with their full paths `<dir>/<name>`, for `Temp.old`. A dir that gave an error has no entries.
	entries : { dirs : List(Str), listed : List(Try(List({ name : Str, is_dir : Bool, mtime : U64 }), [NotFound, Denied, Other(Str)])) } -> List({ path : Str, is_dir : Bool, mtime : U64 })
	entries = |facts| facts.dirs.map2(
		facts.listed,
		|dir, listed| match listed {
			Ok(found) => found.map(|e| { path: Text.join(dir, e.name), is_dir: e.is_dir, mtime: e.mtime })
			Err(_) => []
		},
	).join()

	## R-OUT2 (a proposal): the lines on stdout, each with its `\n`. `<id>` and `<path>` are as in `Done`. In a dry run the word is `would remove` in place of `removed`.
	##
	## | Case | Lines, in this order |
	## | --- | --- |
	## | `ran` is false | `another tln cache gc runs` (R-CC10) |
	## | Else | `removed toolchain <id>` for each id of `toolchains`, `skipped toolchain <id>: an install holds it` for each id of `skipped`, `removed <path>` for each path of `compat` and then of `stale`, `removed project <path>` for each path of `projects` |
	## | Else, all 5 lists empty | `nothing to remove` |
	## | Else, a dry run | The last line is `dry run: nothing was removed` |
	report : Gc.Done -> List(Str)
	report = |done| {
		verb = if done.dry_run "would remove" else "removed"
		lines = done.toolchains.map(|id| "${verb} toolchain ${id}\n")
			.concat(done.skipped.map(|id| "skipped toolchain ${id}: an install holds it\n"))
			.concat(done.compat.concat(done.stale).map(|path| "${verb} ${path}\n"))
			.concat(done.projects.map(|path| "${verb} project ${path}\n"))
		nothing = if lines.is_empty() ["nothing to remove\n"] else lines
		if !done.ran {
			["another tln cache gc runs\n"]
		} else if done.dry_run {
			nothing.append("dry run: nothing was removed\n")
		} else {
			nothing
		}
	}

	## R-J3, R-J4, R-OUT4 (a proposal): the `data` of `--json`, the keys in this order: `dry_run`, `ran` (booleans), `toolchains`, `skipped`, `compat`, `stale`, `projects` (arrays of text, as in `Done`).
	data : Gc.Done -> JsonDoc
	data = |done| {
		texts = |items| JsonDoc.Arr(items.map(|item| JsonDoc.Text(item)))
		JsonDoc.Obj([
			("dry_run", JsonDoc.Flag(done.dry_run)),
			("ran", JsonDoc.Flag(done.ran)),
			("toolchains", texts(done.toolchains)),
			("skipped", texts(done.skipped)),
			("compat", texts(done.compat)),
			("stale", texts(done.stale)),
			("projects", texts(done.projects)),
		])
	}
}

# What GC thinks of one entry of `projects.json`.
Standing : [Live, Gone]

# R-PD12, R-PD13: an old entry or a file that is missing or has no header goes. A file that cannot be read is not judged (D4).
judge : { path : Str, last_use : U64 }, Manage.Read, U64, U64 -> Standing
judge = |entry, got, now, age| if is_over(entry.last_use, now, age) {
	Gone
} else {
	match got {
		Err(NotFound) => Gone
		Err(_) => Live
		Ok(text) => match Locked.read({ path: entry.path, text }) {
			Ok(_) => Live
			Err(_) => Gone
		}
	}
}

# More than `span` seconds ago. A time in the future is not old.
is_over : U64, U64, U64 -> Bool
is_over = |time, now, span| now > time and now - time > span

# R-GC5, D17: the first row of the table in the doc of `toolchains` that fits.
verdict_of : Manage.Row, { rows : List(Manage.Row), projects : List(Gc.Project), now : U64, age : U64 } -> [Remove, Keep(Gc.Why)]
verdict_of = |row, facts| if row.kind == Link or row.kind == Copy {
	Keep(Hand)
} else if row.is_default {
	Keep(Default)
} else {
	match used_time(row) {
		Err(Unknown) => Keep(NoTime)
		Ok(used) => if !is_over(used, facts.now, 86400) {
			Keep(LastDay)
		} else if !Manage.pinned_by({ id: row.id, projects: facts.projects }).is_empty() {
			Keep(Pinned)
		} else if !is_over(used, facts.now, facts.age) {
			Keep(Used)
		} else {
			Remove
		}
	}
}

# R-GC9, D2: `.last-use`, else `installed_at`.
used_time : Manage.Row -> Try(U64, [Unknown])
used_time = |row| match row.last_use {
	Ok(time) => Ok(time)
	Err(Unknown) => row.installed_at
}
