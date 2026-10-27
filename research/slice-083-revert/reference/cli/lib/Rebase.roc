import Locked
import Text
import header.Header

## The path rewrite of a probe copy (slice 006b, Q4 of slice 006, R-LD4, R-H7). The whole-app check runs on a copy of the app dir (R-LD4). A path that a file
## holds as a relative path can point out of the app dir (`../lib/main.roc`, `import "../data.json" as d : Str`), and in the copy it would point to another place.
## `Rebase` changes the path prefix: in the files of the copy that match a glob, a path that leaves the app dir gets the prefix of the original place. The pure part
## is here (part A). The command code (`Ladder.run!`) walks the copy, reads the files and writes the result, so this module makes no `Fx` call.
##
## The strings that `Rebase.files` changes, in each file that the glob matches (answer Q1 of slice 006b: the user wants all `.roc` files, not only the header):
##
## | Strings | Rule |
## | --- | --- |
## | The path entries of a header (`Locked.Row` with `what` = `Path`, R-H7: a platform entry too) | `Rebase.path` |
## | The file of a line `import "<file>" as <name> : <Type>` (`Rebase.embeds`) | `Rebase.path` |
##
## It never changes a URL entry, the `roc:` entry, a comment or any other byte of a file (R-H1). A file that has no header keeps its text, except the import strings.
##
## The names of the arguments:
##
## | Name | Holds |
## | --- | --- |
## | `from` | The absolute dir of the app in the project (the dir of the member file) |
## | `to` | The absolute dir of the copy |
## | `file_dir` | The absolute dir of a file in the original tree (`from` for a file at the top, `<from>/sub` for `sub/x.roc`) |
Rebase :: [].{

	## A file of the copy: `path` is relative to the root of the copy (no `./`, with `/`), `text` is its content.
	File : { path : Str, text : Str }

	## Does `glob` match the whole `path` (relative to the root of the copy)? The rules, with no other special character:
	##
	## | Glob part | Matches |
	## | --- | --- |
	## | `*` | Any run of characters that are not `/`, also the empty run. Also a name that starts with `.`. |
	## | `?` | One character that is not `/` |
	## | `**` | Any run of characters, also `/` and the empty run |
	## | `**/` | Zero or more whole segments: `**/main.roc` matches `main.roc` and `a/b/main.roc`, and not `xmain.roc` |
	## | Another character | Itself |
	##
	## A path that has more characters than the glob is not a match (`*.roc` does not match `main.roc.bak` or `sub/main.roc`).
	glob_match : { glob : Str, path : Str } -> Bool
	glob_match = |facts| glob_at(facts.glob.to_utf8(), facts.path.to_utf8(), 0, 0)

	## The text of one path string of a file in `file_dir` (the string as it stands in the file). The target is `Text.resolve(file_dir, path)`. The rules, first match wins:
	##
	## | # | Case | Result |
	## | --- | --- | --- |
	## | 1 | `path` starts with `/` | `path` |
	## | 2 | The walk of the segments of `path` from `file_dir` never goes above `from` (the copy has the target at the same relative place) | `path` |
	## | 3 | The walk goes above `from`, and the target is `from` or under `from` (the path leaves the app dir and comes back) | the target with the prefix `from` changed to `to` |
	## | 4 | The walk goes above `from`, and the target is not under `from` | the target (an absolute path in the original tree) |
	##
	## A prefix is a whole path segment: `/p/app` is not a prefix of `/p/app-two/x.roc`.
	path : { path : Str, file_dir : Str, from : Str, to : Str } -> Str
	path = |facts| {
		if facts.path.starts_with("/") {
			facts.path
		} else {
			target = Text.resolve(facts.file_dir, facts.path)
			start = depth_of(facts.file_dir, facts.from)
			if !leaves_above(facts.path, start) {
				facts.path
			} else if target == facts.from {
				facts.to
			} else if target.starts_with(with_slash(facts.from)) {
				"${facts.to}/${target.drop_prefix(with_slash(facts.from))}"
			} else {
				target
			}
		}
	}

	## The text of a file with the file of each import line changed by `Rebase.path` (`file_dir` is the dir of the file in the original tree). An import line is a line that starts
	## with `import "` (column 0: an indented line and a comment are not). The file is the text up to the next `"`. A line `import pf.Stdout` has no quote and stays. All other bytes stay.
	embeds : { text : Str, file_dir : Str, from : Str, to : Str } -> Str
	embeds = |facts| Str.join_with(facts.text.split_on("\n").map(|line| embed_line(facts, line)), "\n")

	## The files of the copy that `glob` matches, with each path entry of their header and each import string changed (`Rebase.path`, `Rebase.embeds`). `file_dir` is `from` plus
	## the dir part of the `path` of the file. The result has only the files whose text changed, in the order of `files`. The bytes outside of the changed values stay the same.
	## A matching file with no change (a header with no path entry and no import file, or a module with no import file) is not in the result.
	files : { files : List(File), glob : Str, from : Str, to : Str } -> List(File)
	files = |facts| facts.files.keep_if(|f| glob_match({ glob: facts.glob, path: f.path })).keep_oks(|f| changed(facts, f))
}

# `Ok(file)` with the new text, or `Err` when the text does not change.
changed : { files : List(File), glob : Str, from : Str, to : Str }, File -> Try(File, [Same])
changed = |facts, file| {
	dir = Text.dir_of(file.path)
	file_dir = if dir == "" facts.from else "${facts.from}/${dir}"
	edited = header_paths({ text: file.text, file_dir, from: facts.from, to: facts.to })
	text = Rebase.embeds({ text: edited, file_dir, from: facts.from, to: facts.to })
	if text == file.text Err(Same) else Ok({ path: file.path, text })
}

# The text with each path entry of its header changed. A file with no readable header stays.
header_paths : { text : Str, file_dir : Str, from : Str, to : Str } -> Str
header_paths = |facts| match Locked.read({ path: "", text: facts.text }) {
	Ok(locked) => locked.rows.fold(
		facts.text,
		|text, row| match row.what {
			Path => {
				value = Rebase.path({ path: row.value, file_dir: facts.file_dir, from: facts.from, to: facts.to })
				if value == row.value text else Header.set_value(text, row.alias, value) ?? text
			}
			_ => text
		},
	)
	Err(_) => facts.text
}

# One line of a text: an import line (column 0) gets its file changed.
embed_line : { text : Str, file_dir : Str, from : Str, to : Str }, Str -> Str
embed_line = |facts, line| {
	prefix = "import \""
	if line.starts_with(prefix) {
		match line.drop_prefix(prefix).split_first("\"") {
			Ok({ before, after }) => "${prefix}${Rebase.path({ path: before, file_dir: facts.file_dir, from: facts.from, to: facts.to })}\"${after}"
			Err(_) => line
		}
	} else {
		line
	}
}

# The `..` steps above `from`: does the walk of `path` from a dir that is `depth` segments under `from` go above `from`?
leaves_above : Str, U64 -> Bool
leaves_above = |path, depth| {
	var $depth = depth
	var $above = Bool.False
	for part in path.split_on("/") {
		match part {
			"" | "." => {}
			".." => {
				if $depth == 0 {
					$above = Bool.True
				} else {
					$depth = $depth - 1
				}
			}
			_ => {
				$depth = $depth + 1
			}
		}
	}
	$above
}

# The number of segments of `dir` under `from` (0 for `from` itself).
depth_of : Str, Str -> U64
depth_of = |dir, from| {
	rest = dir.drop_prefix(with_slash(from))
	if dir == from or rest == dir 0 else rest.split_on("/").keep_if(|s| s != "").len()
}

with_slash : Str -> Str
with_slash = |dir| if dir.ends_with("/") dir else "${dir}/"

# The glob from byte `g` and the path from byte `i`: the whole rest of the path must match.
glob_at : List(U8), List(U8), U64, U64 -> Bool
glob_at = |glob, path, g, i| match glob.get(g) {
	Err(_) => i == path.len()
	Ok(42) => if glob.get(g + 1) == Ok(42) glob_stars(glob, path, g, i) else glob_star(glob, path, g + 1, i)
	Ok(63) => match path.get(i) {
		Ok(b) if b != 47 => glob_at(glob, path, g + 1, skip_char(path, i + 1))
		_ => Bool.False
	}
	Ok(c) => path.get(i) == Ok(c) and glob_at(glob, path, g + 1, i + 1)
}

# `*`: a run of bytes with no `/` (also empty), then the rest of the glob from `g`.
glob_star : List(U8), List(U8), U64, U64 -> Bool
glob_star = |glob, path, g, i| glob_at(glob, path, g, i) or match path.get(i) {
	Ok(b) if b != 47 => glob_star(glob, path, g, i + 1)
	_ => Bool.False
}

# `**`: with a `/` after it, whole segments (also none). Else any run of bytes.
glob_stars : List(U8), List(U8), U64, U64 -> Bool
glob_stars = |glob, path, g, i| {
	at_start = i == 0 or path.get(i - 1) == Ok(47)
	if glob.get(g + 2) == Ok(47) and at_start {
		glob_at(glob, path, g + 3, i) or any_from(path, i + 1, |j| path.get(j - 1) == Ok(47) and glob_at(glob, path, g + 3, j))
	} else {
		any_from(path, i, |j| glob_at(glob, path, g + 2, j))
	}
}

# Is there a position `j` from `from` to the end of the path (included) with `ok(j)`?
any_from : List(U8), U64, (U64 -> Bool) -> Bool
any_from = |path, from, ok| if from > path.len() Bool.False else ok(from) or any_from(path, from + 1, ok)

# The position after the bytes of the same character (a UTF-8 continuation byte is 10xxxxxx).
skip_char : List(U8), U64 -> U64
skip_char = |path, i| match path.get(i) {
	Ok(b) if b >= 128 and b < 192 => skip_char(path, i + 1)
	_ => i
}
