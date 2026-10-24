import Args
import Fx

## `tln cache gc` (slice 028 part 1, CLI 6.3, R-GC5, R-GC6, R-GC9, R-GC11, R-CC2, R-CC10, R-PD12, R-PD13). Direct style over `Fx` (TESTING.md 2.2 part C): `Gc` decides, this module orders the calls.
## `Run.tln!` calls `run!` for the command `["cache", "gc"]`. No new `Fx` call. The calls, in order (the L2 cases `gc/gc1-select` and `gc/gc2-busy` and the L3 case `cache/gc1-real` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `Gc.read(args)`. A failure is printed with `Common.failed!` (no `Fx` call). | R-GC11 |
## | 2 | `env_all!`, `Roots.from_env`, one `clock!` (the real time, for the age of temps). The time of Talon is `TALON_NOW` when it is set, else the same real time (`Clock.now`). A bad `TALON_NOW` is a failure of kind `Usage`: `TALON_NOW is not a UTC time: <text>`. | R-EV22 |
## | 3 | Not a dry run: the lock of the item `Roots.item(roots, Gc)` with `NoWait` (`Fx.with_lock!`). `Busy`: no more calls, the line `another tln cache gc runs`, exit 0. A dry run takes no lock (question Q4). Steps 4 to 11 run in the lock. | R-CC10, R-GC11 |
## | 4 | `RocInstall.read_config!` (one `read_files!` of `config.toml`, the warnings on stderr): `gc-age`, `default-roc` | R-GC9 |
## | 5 | One `list_dirs!` with the 6 dirs of `Gc.scan_dirs`. The first result is the listing of the compilers (`Compiler.installed`). | R-CC2, R-LY1 |
## | 6 | One `read_files!` of `talon/projects.json` (a missing file is no project), `Projects.entries` (a failure is exit 19, R-TF6, and nothing is removed). With one entry or more, one `read_files!` of the project files, in the order of the entries. | R-PD12 |
## | 7 | With one compiler or more, one `read_files!` with 2 paths for each id, in the order of the ids: `.talon.json`, then `.last-use` (as `roc list`). | R-CC9 |
## | 8 | The decisions: `Gc.projects`, `Manage.rows`, `Gc.toolchains`, `Temp.old` of `Gc.entries` (with the real time), `Manage.compat_of`. A dry run stops here and prints. | R-GC5, R-GC6, R-GC3 |
## | 9 | For each toolchain to remove, in the order of the ids: `Fx.with_lock!` on `Roots.item(roots, Toolchain(id))` with `NoWait`. `Busy`: the id is skipped and nothing else is done for it. Held: `random!`, `rename!` of the dir to `Manage.trash_name`, then one `delete!` of the trash dir and the compat dir of the compiler (`Roots.item(roots, Compat(<compat id>))`, none when `compat_of` is `Err`). | R-CC10, R-GC3 |
## | 10 | One `delete!` with the stale paths of step 8 (no call when none). | R-CC2, R-GC6 |
## | 11 | When `Gc.projects` has `gone` entries: `Fx.locked!` on `projects.json`: `read_files!`, `Projects.prune` for the entries of the first pass only (an entry that was added after step 6 stays), `write_atomic!` when something left. | R-PD13, R-CC6 |
## | 12 | The output: `Gc.report` on stdout (`--quiet` hides it, with `--json` it goes to stderr), with `--json` the envelope with `Gc.data` on stdout. | R-OUT2, R-J3 |
CacheGc :: [].{

	## Steps 1 to 12.
	run! : Fx, Args => I32
	run! = |_fx, _args| crash "todo"
}
