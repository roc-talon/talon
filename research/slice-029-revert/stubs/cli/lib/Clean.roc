import Args
import Fail
import Gc
import JsonDoc
import Roots

## The pure decisions of `tln cache clean` (slice 029, CLI 6.3, R-GC12 to R-GC14, R-NI7, R-NR3). The command code is `CacheClean`. Texts and `data` fields are a proposal (R-OUT2, TW24).
## `clean` has no age rule. It takes the GC lock with `Wait` around the `delete!` (answer of the manager to Q2, `CacheClean`). Question Q3 of the slice file is about the dir or its content. The sizes come from `Fx.tree_info!` (slice 028b) and `Gc.Measured`, `Gc.Ask` and `Gc.Sized` are the types of `Gc`.
##
## | Decision | Function | Rule |
## | --- | --- | --- |
## | The operand and the flags `--all`, `--dry-run` | `read` | R-CM17, R-GC12, R-GC13, R-GC14 |
## | Which paths `tree_info!` is asked for | `asks` | R-GC12, R-GC13 |
## | Which of them exist, and their sizes | `found` | R-GC14 |
## | The bytes that a run frees | `freed` | R-GC14 |
## | The text and the `data` | `report`, `data` | R-OUT2, R-J3 |
## | What a failed `delete!` means | `check` | R-GC14 (question Q4) |
Clean :: [].{

	## What the flags say: `--all` (R-GC13) and `--dry-run` (R-GC14).
	Plan : { all : Bool, dry_run : Bool }

	## How a run ended. `Nothing`: no item exists. `DryRun`: `--dry-run`, nothing was removed. `Declined`: the answer to the prompt was No, nothing was removed. `Removed`: the items were removed.
	Outcome : [Nothing, DryRun, Declined, Removed]

	## What a run did, or would do. `paths` are the items that exist, in the order of `asks`. `sizes` has one row (`item` is the path) for each item that `tree_info!` measured. `all` is the flag.
	Done : { all : Bool, outcome : Clean.Outcome, paths : List(Str), sizes : List(Gc.Sized) }

	## R-CM17, R-GC12, R-GC13, R-GC14: `tln cache clean [--all] [--dry-run]` takes no operand. 1 or more is a failure of kind `Usage` (exit 2): `tln cache clean takes no operand, got <n>`.
	## `--all` and `--dry-run` are the only flags of the command (`Args.allows` has them already). The other global flags are in `Args`.
	read : Args -> Try(Clean.Plan, Fail)
	read = |_args| crash "todo"

	## R-GC12, R-GC13: the paths for the one `Fx.tree_info!` call, each as `{ item: <path>, path: <path> }`, in this order:
	##
	## | # | Path | When |
	## | --- | --- | --- |
	## | 1 | `Roots.item(roots, Index)`: `<cache>/talon/index` | always (R-GC12) |
	## | 2 | `<cache>/talon/x` | always (R-GC12) |
	## | 3 | `roots.pkgs` (the whole `packages/` dir, with the sidecars) | `all` (R-GC13) |
	## | 4 | Each directory of `builds` (`Gc.entries` of the listing of `roots.build`) whose name starts with `compat-`, `nightly-` or `debug-` and has one more character, sorted by path, each path once (the rule of `Gc.candidates`: a file with such a name is not a dir and is left out) | `all` (R-GC13) |
	##
	## No toolchain, no tool, no `talon/compat.db`, no `talon/projects.json` is ever in the list (R-GC13, R-GC14), also the compat dir of an installed compiler is in row 4 (the design says `clean --all` keeps toolchains, not their build caches).
	## `builds` is ignored when `all` is false (the command makes no listing then).
	asks : { roots : Roots, all : Bool, builds : List({ path : Str, is_dir : Bool, mtime : U64 }) } -> List(Gc.Ask)
	asks = |_facts| crash "todo"

	## R-GC14: the items that exist, from the rows of `Fx.tree_info!` (`Gc.Measured`, the asks with the answers). A row with `Err(NotFound)` is no item (nothing to remove). A row with `Ok` is an item with a size.
	## A row with `Err(Denied)` or `Err(Other(_))` is an item with no size: `clean` removes on request, so it still tries (question Q5). `paths` keeps the order of the rows. `sizes` has the rows with an `Ok` info (`Gc.sizes`).
	found : Gc.Measured -> { paths : List(Str), sizes : List(Gc.Sized) }
	found = |_measured| crash "todo"

	## R-GC14: the bytes that a run frees, or a dry run would free: the sum of `sizes`, an item that has no size counts 0. It is 0 for the outcomes `Nothing` and `Declined`.
	freed : Clean.Done -> U64
	freed = |_done| crash "todo"

	## R-OUT2 (a proposal): the lines on stdout, each with its `\n`. `<size>` is `Toolchain.size_text`. An item with a size gets the suffix ` (<size>)`, an item with no size gets none.
	##
	## | Outcome | Lines, in this order |
	## | --- | --- |
	## | `Nothing` | `nothing to remove` |
	## | `Declined` | `nothing was removed` |
	## | `Removed` | `removed <path>[ (<size>)]` for each path, then `freed <size>` when at least one item has a size |
	## | `DryRun` | `would remove <path>[ (<size>)]` for each path, then `would free <size>` when at least one item has a size, then `dry run: nothing was removed` |
	report : Clean.Done -> List(Str)
	report = |_done| crash "todo"

	## R-J3, R-OUT4 (a proposal): the `data` of `--json`, the keys in this order: `dry_run` (true for the outcome `DryRun`), `all`, `removed` (true for the outcome `Removed`), `items`, `freed`.
	## `items` is an array of `{"path":<text>,"bytes":<number>}` in the order of `paths`, with `"bytes":null` for an item with no size. `freed` is the number `Clean.freed`. The outcome `Nothing` has `items: []`.
	data : Clean.Done -> JsonDoc
	data = |_done| crash "todo"

	## R-GC14 (question Q4): the result of the one `Fx.delete!` call. `results` are in the order of `paths`. `NotFound` is not a failure (the item went since the measure). The first other error is a failure of kind `Environment` (exit 18):
	## `cannot remove <path>: <error>`, with `<error>` as `Str.inspect` writes it (`Denied`, `Other("text")`). The other items were tried already (one call), so a failure does not undo a removal.
	check : { paths : List(Str), results : List(Try({}, [NotFound, Denied, Other(Str)])) } -> Try({}, Fail)
	check = |_facts| crash "todo"
}
