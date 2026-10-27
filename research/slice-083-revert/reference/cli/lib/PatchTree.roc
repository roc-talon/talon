import Diff
import Fail
import Fx
import Text

## The files of some trees on disk, for `tln patch --diff` (slice 042) and for the move of a patch (slice 043, `PatchApply`). Command code over `Fx` (part C). `PatchFlow` had these functions in slice 042: the code agent moves them here
## (the calls of `tln patch --diff` do not change).
PatchTree :: [].{

	## The files of each dir of `dirs`, level by level (one `list_dirs!` call for each level, with the dirs of all trees that have it, in the order of `dirs`), then one `read_files!` call for all files (the files of the first tree, then of the second, in byte order of the paths).
	## A file that `read_files!` cannot read as text is `Binary(sha256)` (`sha256_file!`, D11 of slice 042). The result has one list for each dir, in the order of `dirs`. `copy` is one of `dirs`: when its root is missing the failure is of kind `Usage`:
	## `<copy>/ is missing. Restore the copy, or remove the entry from [patch].` Any other dir that cannot be listed or read is a failure of kind `Environment`, `cannot read <path>`.
	read! : Fx, { dirs : List(Str), copy : Str } => Try(List(List(Diff.File)), Fail)
	read! = |fx, x| {
		var $todo = [{ rel: "", sides: x.dirs.map_with_index(|_, i| i) }]
		var $paths = x.dirs.map(|_| [])
		while !$todo.is_empty() {
			step = list_level!(fx, x, $todo)?
			$paths = $paths.map2(step.files, |found, more| found.concat(more))
			$todo = step.next
		}
		sorted = $paths.map(|found| Text.sorted(found))
		full = x.dirs.map2(sorted, |dir, found| found.map(|rel| Text.join(dir, rel)))
		all = full.join_map(|found| found)
		results = fx.read_files!(all)
		var $contents = []
		for (path, result) in all.map2(results, |path, result| (path, result)) {
			$contents = $contents.append(content_of!(fx, path, result)?)
		}
		var $rest = $contents
		var $trees = []
		for found in sorted {
			$trees = $trees.append(found.map2($rest.take_first(found.len()), |path, content| { path, content }))
			$rest = $rest.drop_first(found.len())
		}
		Ok($trees)
	}
}

# A dir that is in some trees, at one level of the walk. `rel` has no `/` at the end, `sides` are the indexes of the trees that have it.
Level : { rel : Str, sides : List(U64) }

# A file that `read_files!` cannot read as text is `Binary(sha256)` (D11).
content_of! : Fx, Str, Try(Str, [NotFound, Denied, Other(Str)]) => Try(Diff.Content, Fail)
content_of! = |fx, path, result| match result {
	Ok(text) => Ok(Utf8(text))
	Err(_) => match fx.sha256_file!(path) {
		Ok(hash) => Ok(Binary(hash))
		Err(_) => Err(Fail.new(Environment, "cannot read ${path}"))
	}
}

# One level: the files of each tree, and the dirs of the next level. The copy dir that is missing is the failure of R-PA3 (answer Q1 of slice 042).
list_level! : Fx, { dirs : List(Str), copy : Str }, List(Level) => Try({ files : List(List(Str)), next : List(Level) }, Fail)
list_level! = |fx, x, level| {
	at = |root, rel| if rel == "" root else Text.join(root, rel)
	asked = level.join_map(|l| l.sides.map(|side| { rel: l.rel, side, path: at(x.dirs.get(side) ?? "", l.rel) }))
	answers = asked.map2(fx.list_dirs!(asked.map(|a| a.path)), |a, answer| (a, answer))
	var $entries = []
	for (a, answer) in answers {
		match answer {
			Ok(found) => {
				$entries = $entries.concat(found.map(|e| { rel: a.rel, side: a.side, name: e.name, is_dir: e.is_dir }))
			}
			Err(NotFound) if a.rel == "" and a.path == x.copy => return Err(Fail.new(Usage, "${x.copy}/ is missing. Restore the copy, or remove the entry from [patch]."))
			Err(_) => return Err(Fail.new(Environment, "cannot read ${a.path}"))
		}
	}
	join = |e| if e.rel == "" e.name else "${e.rel}/${e.name}"
	dirs = $entries.keep_if(|e| e.is_dir)
	names = Text.sorted_unique(dirs.map(join))
	Ok({
		files: x.dirs.map_with_index(|_, side| $entries.keep_if(|e| e.side == side and !e.is_dir).map(join)),
		next: names.map(|rel| { rel, sides: x.dirs.map_with_index(|_, side| side).keep_if(|side| dirs.any(|e| e.side == side and join(e) == rel)) }),
	})
}
