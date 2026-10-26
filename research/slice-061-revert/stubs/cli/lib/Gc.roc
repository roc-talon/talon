import Args
import Fail
import Ident
import JsonDoc
import Locked
import Manage
import Release
import Roots
import Text
import Toolchain

## The pure decisions of `tln cache gc` (slice 028, CLI 6.3, R-GC5, R-GC6, R-GC9, R-GC11, R-CC2, R-CC10, R-PD12, R-PD13). The command code is `CacheGc`. Texts and `data` fields are a proposal (R-OUT2, TW24).
## Slice 028 is part 1 (toolchains, temps, trash, locks, known projects, `--dry-run`). Slice 028b is part 2 (CLI 6.3, R-GC1, R-GC2, R-GC3 second sentence, R-GC4, R-GC11): the build-cache dirs, `packages/`, and the sizes. The slice file `docs/slices/028b-gc-caches.md` has the rules and the decisions.
##
## | Decision | Function | Rule |
## | --- | --- | --- |
## | The operand and `--dry-run` | `read` | R-GC11 |
## | The age in seconds | `age` | R-GC9 |
## | Which known projects protect something | `projects` | R-PD12, R-PD13 |
## | Which toolchains go | `toolchains` | R-GC5, R-CC10, R-EV22 |
## | Where stale temps can be, and their full paths | `scan_dirs`, `entries` | R-CC2, R-GC6 |
## | The text and the `data` | `report`, `data` | R-OUT2, R-J3 |
## | The Zig installs in the store, and the ones that go (061) | `zig_dirs`, `zigs` | R-D2, R-GC5, R-CC10 |
## | The packages that a live project uses (028b) | `protected` | R-GC4 |
## | The package dirs and the build-cache dirs that the age rule can remove (028b) | `candidates` | R-GC2, R-GC3, R-GC4 |
## | What `Fx.tree_info!` is asked, and what its answer means (028b) | `asks`, `expired`, `sizes`, `freed` | R-GC1, R-GC3, R-GC4, R-GC11 |
Gc :: [].{

	## What the flags say: `--dry-run` (R-GC11).
	Plan : { dry_run : Bool }

	## A known project that protects what it uses: the path of the project file, and the text that `Fx.read_files!` gave for it.
	Project : { path : Str, text : Manage.Read }

	## Why a toolchain stays. `Hand`: a `link-*` or `copy-*` entry (R-GC5: only `tln roc rm` removes it). `Default`: the global default. `LastDay`: used in the last day (R-CC10). `NoTime`: no time is known. `Pinned`: a live known project pins it, whatever its age. `Used`: used in the GC age.
	Why : [Hand, Default, LastDay, NoTime, Pinned, Used]

	## One toolchain, and what GC does with it.
	Choice : { id : Str, verdict : [Remove, Keep(Gc.Why)] }

	## The answer of `Fx.tree_info!` for one path: the newest file time and the size in bytes.
	Tree : { newest : U64, size : U64 }

	## `Fx.tree_info!` gives this for each path.
	Info : Try(Gc.Tree, [NotFound, Denied, Other(Str)])

	## One path that `tree_info!` is asked for. `item` is the name that the report prints for it: the id of a toolchain, else the path.
	Ask : { item : Str, path : Str }

	## The `Ask`s with the answers, in the same order (the command makes it with `map2` of the asks and the answers of `tree_info!`).
	Measured : List({ item : Str, path : Str, info : Gc.Info })

	## The size in bytes of one item of the report.
	Sized : { item : Str, bytes : U64 }

	## One header file that the walk of `protected` has read: `id` is a release URL or the absolute file of a path entry, `read` is the answer of `Fx.read_files!` for its file.
	Node : { id : Str, read : Manage.Read }

	## What a run did, or (`dry_run`) would do. `ran` is false when another GC holds the lock (R-CC10): all lists are then empty. `toolchains` and `skipped` are ids, `compat`, `stale`, `builds`, `pkgs` and `projects` are paths.
	## `builds` are the build-cache dirs and `pkgs` the package dirs that the age rule removes (028b; the word `packages` is reserved in Roc, so the field is `pkgs`, and the `--json` key is `packages`). `sizes` has the size of each item that was measured (028b), also of an item that was skipped.
	Done : { dry_run : Bool, ran : Bool, toolchains : List(Str), skipped : List(Str), compat : List(Str), stale : List(Str), builds : List(Str), pkgs : List(Str), projects : List(Str), sizes : List(Gc.Sized) }

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

	## R-D2, R-D1 (slice 061): the Zig installs in the store. `entries` is the listing of `<cache>/toolchains` (`Fx.list_dirs!`, the first result of the 6 dirs of `scan_dirs`, as `Compiler.installed` gets it).
	## The result is the ids `zig-<X.Y.Z>` of the entries that are a directory with a name `zig-` and a release version of 3 numbers (the dirs that `Zig.installed` finds), in byte order of the names, each once.
	## A file, a dev version (`zig-0.18.0-dev.31+abc1234`), a version with 2 numbers, a temp (`zig-0.17.0.<16hex>.tmp`), a lock dir, a trash dir, and a compiler are not in it. The time of an entry is not read.
	## The name decides (Q4 of the slice file): a dir `zig-<X.Y.Z>` that a person made by hand is a Zig install too.
	zig_dirs : List({ name : Str, is_dir : Bool, mtime : U64 }) -> List(Str)
	zig_dirs = |_entries| crash "todo: slice 061"

	## R-D2, R-GC5, R-CC10, R-CC9 (slice 061): the Zig installs that GC removes. `ids` are the ids of `zig_dirs`, `reads` has the result of `Fx.read_files!` for `Roots.item(roots, ToolchainLastUse(<id>))` of each id, in the same order (one read for each id). `now` is the time of Talon (`TALON_NOW`).
	## A source build writes the `.last-use` of the Zig that it uses before it starts (R-CC9, R-CC10: "a running build wrote it when it started"; `Launch.last_use`: the UTC time and a line end). A source build "needs" a Zig only while it runs (R-D2): the last-use rule is the only rule. There is no GC age for a Zig (no project pins one) and no `git-*` toolchain keeps one.
	## The result is the ids that go, in the order of `ids`:
	##
	## | `reads` of an id | Result |
	## | --- | --- |
	## | `Ok(text)` with a UTC time (`Clock.parse_utc` of the trimmed text) that is not more than 86400 s before `now` (exactly one day stays, a time in the future stays) | Stays: used in the last day |
	## | `Ok(text)` with a UTC time more than 86400 s before `now` | Goes |
	## | `Err(NotFound)`: no `.last-use`, so no source build used this Zig since this slice | Goes |
	## | `Err(Denied)`, `Err(Other(_))`, or `Ok(text)` that is no UTC time | Stays: GC does not judge what it cannot read (the same as an unreadable project file, D4 of slice 028) |
	zigs : { ids : List(Str), reads : List(Manage.Read), now : U64 } -> List(Str)
	zigs = |_facts| crash "todo: slice 061"

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
	## Slice 028b: an item that has a row in `Done.sizes` gets the suffix ` (<size>)` (`Toolchain.size_text`: `999 B`, `1.0 KB`, `1.5 MB`, `3.1 GB`). The suffix is on `removed toolchain` lines and on `removed <path>` lines, never on `skipped` and `project` lines.
	##
	## | Case | Lines, in this order |
	## | --- | --- |
	## | `ran` is false | `another tln cache gc runs` (R-CC10) |
	## | Else | `removed toolchain <id>` for each id of `toolchains`, `skipped toolchain <id>: an install holds it` for each id of `skipped`, `removed <path>` for each path of `compat`, `stale`, `builds` and `pkgs` (in this order; `pkgs` is the field of the package dirs), `removed project <path>` for each path of `projects` |
	## | Else, all 7 lists empty | `nothing to remove` |
	## | Else, at least one removed item has a size | Before the dry run line: `freed <size>` (`would free <size>` in a dry run). The size is `Gc.freed`. |
	## | Else, a dry run | The last line is `dry run: nothing was removed` |
	report : Gc.Done -> List(Str)
	report = |done| {
		verb = if done.dry_run "would remove" else "removed"
		lines = done.toolchains.map(|id| "${verb} toolchain ${id}${size_suffix(done.sizes, id)}\n")
			.concat(done.skipped.map(|id| "skipped toolchain ${id}: an install holds it\n"))
			.concat(paths_of(done).map(|path| "${verb} ${path}${size_suffix(done.sizes, path)}\n"))
			.concat(done.projects.map(|path| "${verb} project ${path}\n"))
		nothing = if lines.is_empty() ["nothing to remove\n"] else lines
		total = if counted(done).is_empty() {
			[]
		} else {
			[if done.dry_run "would free ${Toolchain.size_text(Gc.freed(done))}\n" else "freed ${Toolchain.size_text(Gc.freed(done))}\n"]
		}
		if !done.ran {
			["another tln cache gc runs\n"]
		} else if done.dry_run {
			nothing.concat(total).append("dry run: nothing was removed\n")
		} else {
			nothing.concat(total)
		}
	}

	## R-J3, R-J4, R-OUT4 (a proposal): the `data` of `--json`, the keys in this order: `dry_run`, `ran` (booleans), `toolchains`, `skipped`, `compat`, `stale`, `builds`, `packages` (the field `pkgs`), `projects` (arrays of text, as in `Done`), `sizes`, `freed`.
	## Slice 028b: `sizes` is an array of `{"item":<text>,"bytes":<number>}`, one for each removed item that has a size, in the order of the lines of `report` (each item once). `freed` is the number `Gc.freed`. A busy run has `sizes: []` and `freed: 0`.
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
			("builds", texts(done.builds)),
			("packages", texts(done.pkgs)),
			("projects", texts(done.projects)),
			("sizes", JsonDoc.Arr(counted(done).map(|one| JsonDoc.Obj([("item", JsonDoc.Text(one.item)), ("bytes", JsonDoc.Num(one.bytes.to_i64_wrap()))])))),
			("freed", JsonDoc.Num(Gc.freed(done).to_i64_wrap())),
		])
	}

	## R-GC4 (slice 028b): the hashes of the packages that the live known projects use. It is the step of a walk, as `Closure.step` is (TESTING.md 2.2 part B): `Need` asks for header files, `Done` has the result.
	## The command reads the files that `Need` names (`Gather.file_of`, never a fetch) and calls `protected` again with the new `nodes`.
	##
	## | # | Rule |
	## | --- | --- |
	## | 1 | The roots are the entries of the header of each project of `projects` whose `text` is `Ok` (`Release.entries_of`). A text that does not parse, and a project with an `Err` text, have no entry. |
	## | 2 | An entry value that is a release URL (`Ident.of_url` is `Ok`) names the hash of the URL. A value that has `://` and is not a release URL (`Foreign`) names nothing. A value with no `://` is a path to a `.roc` file: `Text.resolve(<dir of the file that names it>, value)`, an absolute file. |
	## | 3 | The walk follows every entry of every header that it has, not only the version that wins (a superset of the closure of `Closure.step`: no failure for a conflict). A path value in the header of a release is ignored (a published package names no local file, as in `Closure`). |
	## | 4 | `Need(ids)`: the ids (release URLs and absolute files) that an entry names and that `nodes` has no `Node` for, no id twice, in the order of the first entry that names it, level by level (the entries of the projects first). |
	## | 5 | `Done(hashes)`: only when `Need` would be empty. The hash of each release URL that an entry of the projects or of a read node names, sorted, each once. A node with an `Err` read has no entry (its URL still names its hash). |
	protected : { projects : List(Gc.Project), nodes : List(Gc.Node) } -> [Need(List(Str)), Done(List(Str))]
	protected = |facts| {
		from_projects = facts.projects.join_map(|one| named({ file: one.path, read: one.text, release: Bool.False }))
		from_nodes = facts.nodes.join_map(|node| named({ file: node.id, read: node.read, release: Ident.of_url(node.id).is_ok() }))
		edges = from_projects.concat(from_nodes)
		known = facts.nodes.map(|node| node.id)
		need = once(edges.keep_if(|id| !known.contains(id)))
		if need.is_empty() {
			Done(Text.sorted_unique(edges.keep_oks(|id| Ident.of_url(id).map_ok(|ident| ident.hash))))
		} else {
			Need(need)
		}
	}

	## R-GC2, R-GC3 (second sentence), R-GC4 (slice 028b): the dirs that the age rule can remove. `entries` is `Gc.entries` of the 6 dirs of `scan_dirs`. `builds` is `Gc.entries` of the one listing of `roots.build` (`Roots.build`: `ROC_CACHE_DIR`, else the cache root).
	## `protected` is the result of `Gc.protected`. `owned` are the paths of the compat dirs of the toolchains that GC removes (`Roots.item(roots, Compat(id))`: R-GC3 first sentence, they are removed whatever their age). Both lists are sorted by path, each path once.
	##
	## | List | A path is in it when |
	## | --- | --- |
	## | `pkgs` | It is an entry of `entries` with the parent dir `roots.pkgs`, a directory, and a name with no `.` (so not `<hash>.deps.json` and not a temp). Its name is not in `protected`. |
	## | `builds` | It is a directory of `builds` with a name that starts with `compat-`, `nightly-` or `debug-` and has one more character (R-GC2, R-GC3), and it is not in `owned`. A compat dir of a toolchain that GC keeps is in the list (R-GC3: "another dir"). |
	candidates : { roots : Roots, entries : List({ path : Str, is_dir : Bool, mtime : U64 }), builds : List({ path : Str, is_dir : Bool, mtime : U64 }), protected : List(Str), owned : List(Str) } -> { pkgs : List(Str), builds : List(Str) }
	candidates = |facts| {
		in_pkgs = facts.entries.keep_if(|one| one.is_dir and Text.dir_of(one.path) == facts.roots.pkgs)
		pkgs = in_pkgs.keep_if(
			|one| {
				name = Text.last_segment(one.path)
				!name.contains(".") and !facts.protected.contains(name)
			},
		)
		builds = facts.builds.keep_if(|one| one.is_dir and Gc.is_build_name(Text.last_segment(one.path)) and !facts.owned.contains(one.path))
		{ pkgs: Text.sorted_unique(pkgs.map(|one| one.path)), builds: Text.sorted_unique(builds.map(|one| one.path)) }
	}

	## R-GC2, R-GC3, R-GC13: a name of a build-cache dir: `compat-`, `nightly-` or `debug-` and one more character. `Clean.asks` uses it too.
	is_build_name : Str -> Bool
	is_build_name = |name| ["compat-", "nightly-", "debug-"].any(|prefix| name.starts_with(prefix) and name.count_utf8_bytes() > prefix.count_utf8_bytes())

	## R-GC11 (slice 028b): the one list of paths for the one `Fx.tree_info!` call, in this order: the toolchains that go (`item` is the id, `path` is `Roots.item(roots, Toolchain(id))`), `compat`, `stale`, `builds`, `pkgs`.
	## For all but a toolchain, `item` and `path` are the same text. A dry run asks too. No call when the list is empty.
	asks : { roots : Roots, toolchains : List(Str), compat : List(Str), stale : List(Str), builds : List(Str), pkgs : List(Str) } -> List(Gc.Ask)
	asks = |facts| facts.toolchains.map(|id| { item: id, path: Roots.item(facts.roots, Toolchain(id)) })
		.concat(facts.compat.concat(facts.stale).concat(facts.builds).concat(facts.pkgs).map(|path| { item: path, path }))

	## R-GC1, R-GC3, R-GC4, R-GC9 (slice 028b): the `dirs` that the age rule removes. A dir goes when its `info` in `measured` is `Ok` and `now - newest` is more than `span` seconds (exactly `span` stays, a time in the future stays: the same test as `Temp.old` and D3).
	## `now` is the real clock (`clocks.real`), because `newest` is a file time. The span of a build-cache dir is the GC age, the span of a package is 1 day (86400). A dir with `Err` info (`NotFound`, `Denied`, `Other`), and a dir that `measured` has no row for, stays: GC does not judge what it cannot read.
	## The result is in the order of `dirs`. GC never removes a file in a dir that stays, and never a part of a dir (R-GC1).
	expired : { dirs : List(Str), measured : Gc.Measured, now : U64, span : U64 } -> List(Str)
	expired = |facts| facts.dirs.keep_if(
		|dir| match facts.measured.find_first(|row| row.path == dir) {
			Ok(row) => match row.info {
				Ok(tree) => is_over(tree.newest, facts.now, facts.span)
				Err(_) => Bool.False
			}
			Err(_) => Bool.False
		},
	)

	## R-GC11 (slice 028b): the size of each row of `measured` with an `Ok` info, in the order of the rows: `{ item, bytes }`. A row with an `Err` info has no size.
	sizes : Gc.Measured -> List(Gc.Sized)
	sizes = |measured| measured.keep_oks(|row| row.info.map_ok(|tree| { item: row.item, bytes: tree.size }))

	## R-GC11 (slice 028b): the total in bytes that a run frees, or a dry run would free. The sum of the sizes of the items of `toolchains`, `compat`, `stale`, `builds` and `pkgs` (not `skipped`, not `projects`).
	## An item that has no row in `sizes` counts 0. An item that is in the lists twice (2 compilers with one compat id, D13 of slice 028) counts once.
	freed : Gc.Done -> U64
	freed = |done| counted(done).fold(0, |total, one| total + one.bytes)
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
		# Slice 056 (R-PD9, R-PT14): a `talon.toml` that `tln run` or `tln add --tool` recorded has no header. It is live while the file is there.
		Ok(text) => if entry.path == "talon.toml" or entry.path.ends_with("/talon.toml") {
			Live
		} else {
			match Locked.read({ path: entry.path, text }) {
				Ok(_) => Live
				Err(_) => Gone
			}
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

# R-GC11: the paths of the removed items that are no toolchain, in the order of the lines.
paths_of : Gc.Done -> List(Str)
paths_of = |done| done.compat.concat(done.stale).concat(done.builds).concat(done.pkgs)

# R-GC11: the size of each removed item that has one, each item once, in the order of the lines. `skipped` and `projects` are not removed items.
counted : Gc.Done -> List(Gc.Sized)
counted = |done| once(done.toolchains.concat(paths_of(done))).keep_oks(|item| done.sizes.find_first(|one| one.item == item))

# The suffix ` (<size>)` of an item line, or nothing when the item has no size.
size_suffix : List(Gc.Sized), Str -> Str
size_suffix = |all, item| match all.find_first(|one| one.item == item) {
	Ok(one) => " (${Toolchain.size_text(one.bytes)})"
	Err(_) => ""
}

# The texts of a list with no repeat, in the order of the first one.
once : List(Str) -> List(Str)
once = |items| items.fold([], |kept, item| if kept.contains(item) kept else kept.append(item))

# R-GC4, D7: the ids that one header names, in source order. An id is a release URL, or the absolute file of a path entry. A `Foreign` URL names nothing. The header of a release (`release`) names no path.
# A text that is not a header, and a file that cannot be read, name nothing.
named : { file : Str, read : Manage.Read, release : Bool } -> List(Str)
named = |facts| match facts.read {
	Err(_) => []
	Ok(text) => match Release.entries_of({ path: facts.file, text }) {
		Err(_) => []
		Ok(found) => found.keep_oks(|one| id_of({ dir: Text.dir_of(facts.file), value: one.value, release: facts.release }))
	}
}

id_of : { dir : Str, value : Str, release : Bool } -> Try(Str, [Nothing])
id_of = |facts| if Ident.of_url(facts.value).is_ok() {
	Ok(facts.value)
} else if facts.value.contains("://") or facts.release {
	Err(Nothing)
} else {
	Ok(Text.resolve(facts.dir, facts.value))
}
