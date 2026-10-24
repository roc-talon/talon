import Args
import Fail
import Gc
import JsonDoc
import Roots
import Text
import Toolchain

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
	read = |args| match args.operands {
		[] => Ok({ all: flag_set(args, "--all"), dry_run: flag_set(args, "--dry-run") })
		many => Err(Fail.new(Usage, "tln cache clean takes no operand, got ${many.len().to_str()}"))
	}

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
	asks = |facts| {
		always = [Roots.item(facts.roots, Index), Text.join(facts.roots.cache, "talon/x")]
		dirs = facts.builds.keep_if(|one| one.is_dir and Gc.is_build_name(Text.last_segment(one.path))).map(|one| one.path)
		paths = if facts.all always.append(facts.roots.pkgs).concat(Text.sorted_unique(dirs)) else always
		paths.map(|path| { item: path, path })
	}

	## R-GC14: the items that exist, from the rows of `Fx.tree_info!` (`Gc.Measured`, the asks with the answers). A row with `Err(NotFound)` is no item (nothing to remove). A row with `Ok` is an item with a size.
	## A row with `Err(Denied)` or `Err(Other(_))` is an item with no size: `clean` removes on request, so it still tries (question Q5). `paths` keeps the order of the rows. `sizes` has the rows with an `Ok` info (`Gc.sizes`).
	found : Gc.Measured -> { paths : List(Str), sizes : List(Gc.Sized) }
	found = |measured| {
		there = measured.keep_if(
			|row| match row.info {
				Err(NotFound) => Bool.False
				_ => Bool.True
			},
		)
		{ paths: there.map(|row| row.path), sizes: Gc.sizes(there) }
	}

	## R-GC14: the bytes that a run frees, or a dry run would free: the sum of `sizes`, an item that has no size counts 0. It is 0 for the outcomes `Nothing` and `Declined`.
	freed : Clean.Done -> U64
	freed = |done| match done.outcome {
		Nothing | Declined => 0
		DryRun | Removed => done.sizes.fold(0, |total, one| total + one.bytes)
	}

	## R-OUT2 (a proposal): the lines on stdout, each with its `\n`. `<size>` is `Toolchain.size_text`. An item with a size gets the suffix ` (<size>)`, an item with no size gets none.
	##
	## | Outcome | Lines, in this order |
	## | --- | --- |
	## | `Nothing` | `nothing to remove` |
	## | `Declined` | `nothing was removed` |
	## | `Removed` | `removed <path>[ (<size>)]` for each path, then `freed <size>` when at least one item has a size |
	## | `DryRun` | `would remove <path>[ (<size>)]` for each path, then `would free <size>` when at least one item has a size, then `dry run: nothing was removed` |
	report : Clean.Done -> List(Str)
	report = |done| match done.outcome {
		Nothing => ["nothing to remove\n"]
		Declined => ["nothing was removed\n"]
		Removed => lines(done, "removed", "freed")
		DryRun => lines(done, "would remove", "would free").append("dry run: nothing was removed\n")
	}

	## R-J3, R-OUT4 (a proposal): the `data` of `--json`, the keys in this order: `dry_run` (true for the outcome `DryRun`), `all`, `removed` (true for the outcome `Removed`), `items`, `freed`.
	## `items` is an array of `{"path":<text>,"bytes":<number>}` in the order of `paths`, with `"bytes":null` for an item with no size. `freed` is the number `Clean.freed`. The outcome `Nothing` has `items: []`.
	data : Clean.Done -> JsonDoc
	data = |done| JsonDoc.Obj([
		("dry_run", JsonDoc.Flag(done.outcome == DryRun)),
		("all", JsonDoc.Flag(done.all)),
		("removed", JsonDoc.Flag(done.outcome == Removed)),
		("items", JsonDoc.Arr(done.paths.map(|path| JsonDoc.Obj([("path", JsonDoc.Text(path)), ("bytes", Clean.bytes_of(done.sizes, path))])))),
		("freed", JsonDoc.Num(Clean.freed(done).to_i64_wrap())),
	])

	## R-GC14 (question Q4): the result of the one `Fx.delete!` call. `results` are in the order of `paths`. `NotFound` is not a failure (the item went since the measure). The first other error is a failure of kind `Environment` (exit 18):
	## `cannot remove <path>: <error>`, with `<error>` as `Str.inspect` writes it (`Denied`, `Other("text")`). The other items were tried already (one call), so a failure does not undo a removal.
	check : { paths : List(Str), results : List(Try({}, [NotFound, Denied, Other(Str)])) } -> Try({}, Fail)
	check = |facts| {
		failures = facts.paths.map2(
			facts.results,
			|path, result| match result {
				Err(NotFound) => Err(Skip)
				Err(err) => Ok("cannot remove ${path}: ${Str.inspect(err)}")
				Ok(_) => Err(Skip)
			},
		).keep_oks(|failure| failure)
		match failures {
			[first, ..] => Err(Fail.new(Environment, first))
			[] => Ok({})
		}
	}

	## R-OUT2: the suffix ` (<size>)` of the item `path` (`Toolchain.size_text`), or the empty text for an item that has no row in `sizes`. `CacheView.list_report` uses it too.
	size_suffix : List(Gc.Sized), Str -> Str
	size_suffix = |sizes, path| match sizes.find_first(|one| one.item == path) {
		Ok(one) => " (${Toolchain.size_text(one.bytes)})"
		Err(_) => ""
	}

	## R-OUT4: the `bytes` of the item `path` as a number, or null for an item that has no row in `sizes`. `CacheView.list_data` uses it too.
	bytes_of : List(Gc.Sized), Str -> JsonDoc
	bytes_of = |sizes, path| match sizes.find_first(|one| one.item == path) {
		Ok(one) => JsonDoc.Num(one.bytes.to_i64_wrap())
		Err(_) => JsonDoc.Null
	}
}

flag_set : Args, Str -> Bool
flag_set = |args, name| args.options.any(|(each, _)| each == name)

# The item lines, then the total line when one item has a size.
lines : Clean.Done, Str, Str -> List(Str)
lines = |done, verb, total| {
	items = done.paths.map(|path| "${verb} ${path}${Clean.size_suffix(done.sizes, path)}\n")
	if done.sizes.is_empty() items else items.append("${total} ${Toolchain.size_text(Clean.freed(done))}\n")
}
