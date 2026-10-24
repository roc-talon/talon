import Args
import Clock
import Common
import Compiler
import Fail
import Fx
import Gc
import Known
import Manage
import Out
import Projects
import RocInstall
import Roots
import Temp
import Trash

## `tln cache gc` (slice 028 part 1, CLI 6.3, R-GC5, R-GC6, R-GC9, R-GC11, R-CC2, R-CC10, R-PD12, R-PD13). Direct style over `Fx` (TESTING.md 2.2 part C): `Gc` decides, this module orders the calls.
## `Run.tln!` calls `run!` for the command `["cache", "gc"]`. Slice 028b adds the new `Fx` call `tree_info!` and the steps 5b, 6b, 8 (more decisions) and 10 (more paths): the L2 cases `gc/gc1-select` and `gc/gc3-caches` and the L3 case `cache/gc1-real` fix them. The calls, in order (the L2 cases `gc/gc1-select` and `gc/gc2-busy` and the L3 case `cache/gc1-real` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `Gc.read(args)`. A failure is printed with `Common.failed!` (no `Fx` call). | R-GC11 |
## | 2 | `env_all!`, `Roots.from_env`, one `clock!` (the real time, for the age of temps). The time of Talon is `TALON_NOW` when it is set, else the same real time (`Clock.now`). A bad `TALON_NOW` is a failure of kind `Usage`: `TALON_NOW is not a UTC time: <text>`. | R-EV22 |
## | 3 | Not a dry run: the lock of the item `Roots.item(roots, Gc)` with `NoWait` (`Fx.with_lock!`). `Busy`: no more calls, the line `another tln cache gc runs`, exit 0. A dry run takes no lock (question Q4). Steps 4 to 11 run in the lock. | R-CC10, R-GC11 |
## | 4 | `RocInstall.read_config!` (one `read_files!` of `config.toml`, the warnings on stderr): `gc-age`, `default-roc` | R-GC9 |
## | 5 | One `list_dirs!` with the 6 dirs of `Gc.scan_dirs`. The first result is the listing of the compilers (`Compiler.installed`). | R-CC2, R-LY1 |
## | 5b | (028b) One `list_dirs!` with the one dir `roots.build` (`ROC_CACHE_DIR`, else the cache root): the build-cache dirs. `Gc.entries` makes its entries. A missing dir has no entry. | R-GC2, R-GC3 |
## | 6 | One `read_files!` of `talon/projects.json` (a missing file is no project), `Projects.entries` (a failure is exit 19, R-TF6, and nothing is removed). With one entry or more, one `read_files!` of the project files, in the order of the entries. | R-PD12 |
## | 6b | (028b) The walk of `Gc.protected` over the live projects (`known.live`), only when the listing of `roots.pkgs` has a package dir (`Gc.candidates` with no protected hash has a package). Each `Need(ids)` is one `read_files!` of `Gather.file_of(roots, id)` for the ids, in the order of the ids, and its answers are the new `Gc.Node`s. Never a fetch. No call when no package dir exists or `Need` is empty. | R-GC4 |
## | 7 | With one compiler or more, one `read_files!` with 2 paths for each id, in the order of the ids: `.talon.json`, then `.last-use` (as `roc list`). | R-CC9 |
## | 8 | The decisions: `Gc.projects`, `Manage.rows`, `Gc.toolchains`, `Temp.old` of `Gc.entries` (with the real time), `Manage.compat_of`. Then (028b) `Gc.candidates`, `Gc.asks` and one `tree_info!` with all the asks (no call when `asks` is empty; a dry run calls it too), `Gc.expired` (builds: span `gc-age`, packages: span 86400, both with the real time) and `Gc.sizes`. A dry run stops here and prints. | R-GC5, R-GC6, R-GC3, R-GC2, R-GC4, R-GC11 |
## | 9 | For each toolchain to remove, in the order of the ids: `Fx.with_lock!` on `Roots.item(roots, Toolchain(id))` with `NoWait`. `Busy`: the id is skipped and nothing else is done for it. Held: `random!`, `rename!` of the dir to `Manage.trash_name`, then one `delete!` of the trash dir and the compat dir of the compiler (`Roots.item(roots, Compat(<compat id>))`, none when `compat_of` is `Err`). | R-CC10, R-GC3 |
## | 10 | One `delete!` with the stale paths of step 8, then (028b) the expired build dirs, then for each expired package its dir and `<dir>.deps.json` (no call when all are empty). | R-CC2, R-GC6, R-GC2, R-GC4 |
## | 11 | When `Gc.projects` has `gone` entries: `Fx.locked!` on `projects.json`: `read_files!`, `Projects.prune` for the entries of the first pass only (an entry that was added after step 6 stays), `write_atomic!` when something left. | R-PD13, R-CC6 |
## | 12 | The output: `Gc.report` on stdout (`--quiet` hides it, with `--json` it goes to stderr), with `--json` the envelope with `Gc.data` on stdout. | R-OUT2, R-J3 |
CacheGc :: [].{

	## Steps 1 to 12.
	run! : Fx, Args => I32
	run! = |fx, args| match Gc.read(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(plan) => match gc_flow!(fx, plan) {
			Ok(done) => {
				print!(fx, args, done)
				0
			}
			Err(fail) => Common.failed!(fx, args, fail)
		}
	}

	## R-EV22, step 2: the real time (for the temps) and the time of Talon (`TALON_NOW`, else the real time) for the ages of toolchains and projects. A bad `TALON_NOW` is a failure of kind `Usage`.
	clocks_of : { env : List((Str, Str)), real : U64 } -> Try({ real : U64, now : U64 }, Fail)
	clocks_of = |facts| {
		talon_now = match facts.env.find_first(|(name, _)| name == "TALON_NOW") {
			Ok((_, text)) => Ok(text)
			Err(_) => Err(NotSet)
		}
		match Clock.now({ talon_now, real: facts.real }) {
			Ok(now) => Ok({ real: facts.real, now })
			Err(BadTime(text)) => Err(Fail.new(Usage, "TALON_NOW is not a UTC time: ${text}"))
		}
	}
}

Clocks : { real : U64, now : U64 }

# What GC did, for the output. No lock for a dry run (Q4).
gc_flow! : Fx, Gc.Plan => Try(Gc.Done, Fail)
gc_flow! = |fx, plan| {
	env = fx.env_all!()
	roots = Roots.from_env(env)?
	clocks = CacheGc.clocks_of({ env, real: fx.clock!() })?
	if plan.dry_run {
		work!(fx, roots, clocks, plan)
	} else {
		match fx.with_lock!(Roots.item(roots, Gc), NoWait, || work!(fx, roots, clocks, plan)) {
			Ok(done) => Ok(done)
			Err(Busy) => Ok({ dry_run: Bool.False, ran: Bool.False, toolchains: [], skipped: [], compat: [], stale: [], builds: [], pkgs: [], projects: [], sizes: [] })
			Err(Failed(fail)) => Err(fail)
		}
	}
}

# Steps 4 to 11, in the GC lock. All reads come first: a failure there ends the run with nothing removed (D7).
work! : Fx, Roots, Clocks, Gc.Plan => Try(Gc.Done, Fail)
work! = |fx, roots, clocks, plan| {
	config = RocInstall.read_config!(fx, roots)?
	age = Gc.age(config.gc_age)
	dirs = Gc.scan_dirs(roots)
	listed = fx.list_dirs!(dirs)
	ids = match listed {
		[Ok(found), ..] => Compiler.installed(found)
		_ => []
	}
	known = known_projects!(fx, roots, { now: clocks.now, age })?
	paths = ids.join_map(|id| [Roots.item(roots, ToolchainMeta(id)), Roots.item(roots, ToolchainLastUse(id))])
	reads = if ids.is_empty() [] else fx.read_files!(paths)
	found = Manage.found_of(ids, reads)
	rows = Manage.rows({ found, default: config.default_roc })
	choices = Gc.toolchains({ rows, projects: known.live, now: clocks.now, age })
	going = choices.keep_if(|choice| choice.verdict == Remove).map(|choice| choice.id)
	compat_of = |id| match found.find_first(|each| each.id == id) {
		Ok(each) => Manage.compat_of(each.meta)
		Err(_) => Err(None)
	}
	stale = Temp.old({ entries: Gc.entries({ dirs, listed }), now: clocks.real })
	if plan.dry_run {
		compat = going.keep_oks(|id| compat_of(id).map_ok(|c| Roots.item(roots, Compat(c))))
		return Ok({ dry_run: Bool.True, ran: Bool.True, toolchains: going, skipped: [], compat, stale, builds: [], pkgs: [], projects: known.gone, sizes: [] })
	}
	removed = remove_all!(fx, roots, going.map(|id| { id, compat: compat_of(id) }))?
	if !stale.is_empty() {
		_ = fx.delete!(stale)
	}
	prune!(fx, roots, { now: clocks.now, gone: known.gone })?
	Ok({ dry_run: Bool.False, ran: Bool.True, toolchains: removed.held, skipped: removed.busy, compat: removed.compat, stale, builds: [], pkgs: [], projects: known.gone, sizes: [] })
}

# Step 6, R-PD12: the entries of `projects.json` and the project files. A text that does not parse ends the run (exit 19, R-TF6).
known_projects! : Fx, Roots, { now : U64, age : U64 } => Try({ live : List(Gc.Project), gone : List(Str) }, Fail)
known_projects! = |fx, roots, facts| {
	entries = Known.entries!(fx, roots)?
	reads = if entries.is_empty() [] else fx.read_files!(entries.map(|entry| entry.path))
	Ok(Gc.projects({ entries, reads, now: facts.now, age: facts.age }))
}

# Step 9, R-CC10: each compiler under its own lock with `NoWait`. A busy lock skips it. The result lists are in the order of `ids`.
remove_all! : Fx, Roots, List({ id : Str, compat : Try(Str, [None]) }) => Try({ held : List(Str), busy : List(Str), compat : List(Str) }, Fail)
remove_all! = |fx, roots, going| {
	var $held = []
	var $busy = []
	var $compat = []
	for each in going {
		item = Roots.item(roots, Toolchain(each.id))
		match fx.with_lock!(item, NoWait, || Trash.move!(fx, roots, { item, compat: each.compat })) {
			Ok({}) => {
				$held = $held.append(each.id)
				$compat = $compat.concat(each.compat.map_ok(|c| [Roots.item(roots, Compat(c))]) ?? [])
			}
			Err(Busy) => {
				$busy = $busy.append(each.id)
			}
			Err(Failed(fail)) => return Err(fail)
		}
	}
	Ok({ held: $held, busy: $busy, compat: $compat })
}

# Step 11, R-PD13, R-CC6: under the lock of `projects.json`, the entries of the first read that left are removed from the new text. An entry that was added since stays (D12).
prune! : Fx, Roots, { now : U64, gone : List(Str) } => Try({}, Fail)
prune! = |fx, roots, facts| if facts.gone.is_empty() {
	Ok({})
} else {
	item = Roots.item(roots, ProjectsJson)
	fx.locked!(item, || prune_text!(fx, item, facts))
}

prune_text! : Fx, Str, { now : U64, gone : List(Str) } => Try({}, Fail)
prune_text! = |fx, item, facts| match fx.read_files!([item]) {
	[Ok(text)] => {
		current = Projects.entries({ path: item, text })?
		valid = current.map(|entry| entry.path).keep_if(|path| !facts.gone.contains(path))
		pruned = Projects.prune({ path: item, text, now: facts.now, max_age: Err(NoLimit), valid })?
		if pruned.removed.is_empty() {
			Ok({})
		} else {
			match fx.write_atomic!([{ path: item, content: pruned.text }]) {
				Ok(_) => Ok({})
				Err({ path, err }) => Err(Fail.new(Environment, "cannot write ${path}: ${Str.inspect(err)}"))
			}
		}
	}
	_ => Ok({})
}

# Step 12: the text (hidden by `--quiet`, on stderr with `--json`), and with `--json` the envelope.
print! : Fx, Args, Gc.Done => {}
print! = |fx, args, done| {
	shown = Common.shown_fx(fx, args)
	for line in Gc.report(done) {
		shown.out!(line)
	}
	if args.json {
		fx.out!(Out.json_ok({ command: args.typed, data: Gc.data(done) }))
	}
}
