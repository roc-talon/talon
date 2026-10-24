import Args
import Clean
import Fail
import Gc
import JsonDoc
import Toolchain

## The pure decisions of `tln cache dir` and `tln cache list` (slice 029b, CLI 6.3, R-CM17, R-J3, R-OUT2, R-OUT4, R-LY1). The command code is `CacheShow`. Texts and `data` fields are a proposal (R-OUT2, TW24).
## Both commands only show. They remove nothing, take no lock and have no flag of their own (`--json`, `--quiet` and the other global flags are in `Args`).
##
## | Decision | Function | Rule |
## | --- | --- | --- |
## | The operand of `dir` and `list` | `read` | R-CM17 |
## | The text and the `data` of `dir` | `dir_report`, `dir_data` | R-OUT2, R-J3 |
## | The text and the `data` of `list` | `list_report`, `list_data` | R-OUT2, R-OUT4, R-J3 |
CacheView :: [].{

	## The items that `list` shows: the same value as `Clean.found` gives (the items that exist, in the order of `Clean.asks`, and the sizes of those that `tree_info!` measured).
	Listed : { paths : List(Str), sizes : List(Gc.Sized) }

	## R-CM17: `tln cache dir` and `tln cache list` take no operand. 1 or more is a failure of kind `Usage` (exit 2): `tln <words> takes no operand, got <n>`, where `<words>` are the words of the command (`args.command` joined by one space: `cache dir`, `cache list`).
	## The flags are checked by `Args` (`--all` and `--dry-run` are not flags of these commands, so `Args.parse` stops them).
	read : Args -> Try({}, Fail)
	read = |args| match args.operands {
		[] => Ok({})
		many => Err(Fail.new(Usage, "tln ${Str.join_with(args.command, " ")} takes no operand, got ${many.len().to_str()}"))
	}

	## R-OUT2 (a proposal): the lines on stdout for `tln cache dir`: the cache root `<cache>` (`Roots.cache`: `$XDG_CACHE_HOME/roc`, else `$HOME/.cache/roc`) and `\n`. One line, no other text.
	dir_report : Str -> List(Str)
	dir_report = |cache| ["${cache}\n"]

	## R-J3, R-OUT4 (a proposal): the `data` of `tln cache dir`: `{"path":<cache>}`.
	dir_data : Str -> JsonDoc
	dir_data = |cache| JsonDoc.Obj([("path", JsonDoc.Text(cache))])

	## R-OUT2 (a proposal): the lines on stdout for `tln cache list`, each with its `\n`. `<size>` is `Toolchain.size_text`.
	##
	## | Case | Lines, in this order |
	## | --- | --- |
	## | No item | `nothing to clean` |
	## | One item or more | `<path>[ (<size>)]` for each path in the order of `paths` (an item with no size has no suffix), then `total <size>` (the sum of the sizes) when at least one item has a size |
	list_report : CacheView.Listed -> List(Str)
	list_report = |listed| {
		if listed.paths.is_empty() {
			["nothing to clean\n"]
		} else {
			items = listed.paths.map(|path| "${path}${Clean.size_suffix(listed.sizes, path)}\n")
			if listed.sizes.is_empty() items else items.append("total ${Toolchain.size_text(total(listed.sizes))}\n")
		}
	}

	## R-J3, R-OUT4 (a proposal): the `data` of `tln cache list`, the keys in this order: `items` (an array of `{"path":<text>,"bytes":<number>}` in the order of `paths`, with `"bytes":null` for an item with no size), `total` (the sum of the sizes, 0 with no item).
	list_data : CacheView.Listed -> JsonDoc
	list_data = |listed| JsonDoc.Obj([
		("items", JsonDoc.Arr(listed.paths.map(|path| JsonDoc.Obj([("path", JsonDoc.Text(path)), ("bytes", Clean.bytes_of(listed.sizes, path))])))),
		("total", JsonDoc.Num(total(listed.sizes).to_i64_wrap())),
	])
}

# The sum of the measured sizes.
total : List(Gc.Sized) -> U64
total = |sizes| sizes.fold(0, |sum, one| sum + one.bytes)
