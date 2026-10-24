import Args
import Fx

## `tln cache dir` and `tln cache list` (slice 029b, CLI 6.3, R-CM17, R-GC13, R-LY1, R-FL4, R-J3). Direct style over `Fx` (TESTING.md 2.2 part C): `CacheView` decides, this module orders the calls.
## `Run.tln!` calls `dir!` for the command `["cache", "dir"]` and `list!` for `["cache", "list"]`. Both only read: no lock (also when `cache gc` holds `talon/gc`), no `delete!`, no `clock!`, no `tty!`, no `ask!`, no `make_dirs!`.
## The L2 case `cache/cv1-view` and the L3 case `cache/cv1-real` fix the calls.
##
## `dir!`:
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `CacheView.read(args)`. A failure is printed with `Common.failed!` (no `Fx` call). | R-CM17 |
## | 2 | `env_all!`, `Roots.from_env`. A failure is printed with `Common.failed!`. No other call: the dir is not looked at and not made. | R-LY1 |
## | 3 | The output: `CacheView.dir_report(roots.cache)` on stdout. With `--json`: only the envelope `CacheView.dir_data` on stdout (`command` is `cache dir`), no text. `--quiet` hides nothing (the path is the answer, as `Ls` and `RocManage.list!`). | R-OUT2, R-J3, R-FL4 |
##
## `list!`:
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `CacheView.read(args)`. | R-CM17 |
## | 2 | `env_all!`, `Roots.from_env`. | R-LY1 |
## | 3 | One `list_dirs!` with the one dir `roots.build`, `Gc.entries`: the build-cache dirs, as `clean --all`. | R-GC13 |
## | 4 | `Clean.asks` with `all: true`, one `tree_info!` with the paths, `Clean.found`. A path that is missing is no item. An item that `tree_info!` cannot measure is an item with no size. | R-GC12, R-GC13 |
## | 5 | The output: `CacheView.list_report` on stdout. With `--json`: only the envelope `CacheView.list_data` (`command` is `cache list`), no text. `--quiet` hides nothing. | R-OUT2, R-J3, R-FL4 |
CacheShow :: [].{

	## Steps 1 to 3 of `tln cache dir`.
	dir! : Fx, Args => I32
	dir! = |_fx, _args| crash "todo"

	## Steps 1 to 5 of `tln cache list`.
	list! : Fx, Args => I32
	list! = |_fx, _args| crash "todo"
}
