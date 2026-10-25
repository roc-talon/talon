## The unified diff of a patch and its apply (Resolution 7, R-PA3, R-PA5, R-PA7; slice 042). Part A (pure, TESTING.md 2.2). No `Fx` call is here.
## `PatchFlow` reads the two trees (`--diff`), `tln install` and `tln upgrade` apply a diff to a new release (slice 043).
##
## A file is a path and its content. The path is relative to the root of the tree, with `/` and no `./`. The content is `Utf8(text)` for a file that is UTF-8 text,
## else `Binary(sha256)` (64 lower case hex digits: the caller reads the file as text first, and takes the sha256 when that fails).
##
## Lines. A text is a list of lines. A line has its own line end `\n`, except the last line of a text that has no `\n` at its end. So `"a\nb"` has the lines `"a\n"` and `"b"`,
## `"a\nb\n"` has `"a\n"` and `"b\n"`, and the empty text has no line. Two lines are equal only when they have the same bytes, also the line end. So a file that gains
## or loses its final line end has a changed last line.
##
## `make` gives one `Change` for each path that differs, in the byte order of the paths (`Text.compare`):
##
## | Base file | Copy file | Change |
## | --- | --- | --- |
## | `Utf8(a)` | `Utf8(b)`, `a != b` | `Edit({ path, hunks })` |
## | `Utf8(a)` or `Binary(h)` | `Binary` or `Utf8`, not the same content | `Replace({ path, base, copy })`: the whole file (R-PA7: a file that is not UTF-8 text is replaced whole) |
## | none | any | `Add(file)` |
## | any | none | `Delete(file)` (the file of the base) |
## | the same content on both sides | | no change |
##
## The hunks of an `Edit` are the changed lines with 3 lines of context (R-PA7). The rules (the tests fix them with texts that have one shortest script):
##
## | Rule | Text |
## | --- | --- |
## | Shortest | The number of `Del` and `Ins` lines is the smallest that exists (the old lines and the new lines, less 2 times the longest common run of lines). 2 scripts of that length are both right. |
## | Order | Lines of the old text are `Keep` or `Del`, lines of the new text are `Keep` or `Ins`, in text order. In one run of changed lines all `Del` come first, then all `Ins`. |
## | Context | A hunk has 3 `Keep` lines before its first changed line and 3 after its last (fewer at the start or at the end of the text). |
## | Merge | 2 runs of changes are one hunk when 6 `Keep` lines or fewer are between them. With 7 `Keep` lines they are 2 hunks. |
## | Numbers | `old_start` and `new_start` are 1-based line numbers of the first line of the hunk on that side. A side that has no line in the hunk (`old_len` or `new_len` is 0, the text was or becomes empty) has the number of the line before: `0` at the top of the text. |
## | Counts | `old_len` is the number of `Keep` and `Del` lines of the hunk. `new_len` is the number of `Keep` and `Ins` lines. |
##
## `render` is the text that `tln patch <alias> --diff` prints (a proposal, TW24: the headers are the ones of `diff -u` with the prefixes `a/` and `b/`, so `patch -p1` can read the output).
## The changes are in the order of the list. A text file:
##
## ```text
## --- a/Json.roc
## +++ b/Json.roc
## @@ -1,4 +1,4 @@
##  one
## -two
## +three
##  four
## \ No newline at end of file
## ```
##
## | Change | Text |
## | --- | --- |
## | `Edit` | The 2 header lines, then each hunk: `@@ -<old_start>,<old_len> +<new_start>,<new_len> @@` (the count is always written, also when it is 1), then one line for each hunk line with the prefix ` `, `-` or `+` and the line. A line that has no `\n` at its end is followed by a line end and the line `\ No newline at end of file`. |
## | `Add` of a text | `--- /dev/null`, `+++ b/<path>`, and one hunk `@@ -0,0 +1,<n> @@` with `+` lines. An empty file has no hunk: only the 2 header lines. |
## | `Delete` of a text | `--- a/<path>`, `+++ /dev/null`, and one hunk `@@ -1,<n> +0,0 @@` with `-` lines. An empty file has no hunk. |
## | `Add`, `Delete`, `Replace` with a binary side | One line: `Binary files a/<path> and b/<path> differ`. `/dev/null` and no prefix take the place of the side that has no file: `Binary files /dev/null and b/<path> differ`, `Binary files a/<path> and /dev/null differ`. |
## | No change | The empty text |
##
## `apply` puts a diff on a target tree (R-PA5, R-PA7). It looks at each change and never stops at the first failure, so `failed` lists all files that do not apply (R-PA5: the explanation lists them).
## `done` and `failed` are in the order of the changes. A file is in one of them, never in both: a file with one hunk that does not apply is not partly written.
##
## | Change | Applies when | Gives in `done` |
## | --- | --- | --- |
## | `Edit` | The target has the path as `Utf8`, and each hunk applies (below) | `Write(<the new text>)` |
## | `Replace` | The target has the path, with the same content as `base` (the same text, or the same sha256) | `Write(text)` when `copy` is a text, else `FromCopy` (the caller takes the bytes from the copy) |
## | `Add` | The target has no file with this path (a target that has it: the change fails, answer Q4) | `Write(text)` for a text, `FromCopy` for a binary file |
## | `Delete` | The target has the path with the same content as the file of the change (other content or no path: the change fails, answer Q4) | `Remove` |
##
## A hunk applies when its old side (its `Keep` and `Del` lines, in order) is in the text exactly: same lines, same line ends, no fuzz (R-PA7). One changed context line makes the hunk fail.
## The place of the hunk can be any number of lines away from `old_start`. The hunks are applied in order, and a hunk starts after the end of the one before it. A hunk with no old line
## (the base file was empty) applies only to an empty text. A hunk replaces its old side with its new side (its `Keep` and `Ins` lines).
## A hunk that fits at 2 places or more goes to the place that is the nearest to its line number (answer Q2). The line number of a hunk moves with the hunks before it: it is `old_start` plus the lines that the places of the hunks before it moved, plus the lines that they added or removed. 2 places at the same distance: the first one. `Add` on a path that the target has, and `Delete` on a path that the target has not or has with other content, fail for that file (answer Q4): it is in `failed`, nothing is written.
Diff :: [].{

	## The content of a file. `Binary` holds the sha256 of the bytes (64 hex digits).
	Content : [Utf8(Str), Binary(Str)]

	## A file of a tree. `path` is relative to the root of the tree.
	File : { path : Str, content : Content }

	## A line of a hunk: kept, deleted from the old text, inserted in the new text. The text of the line has its own line end (the top of this file).
	Line : [Keep(Str), Del(Str), Ins(Str)]

	## One hunk (the table of numbers above).
	Hunk : { old_start : U64, old_len : U64, new_start : U64, new_len : U64, lines : List(Line) }

	## One changed file.
	Change : [
		Edit({ path : Str, hunks : List(Hunk) }),
		Add(File),
		Delete(File),
		Replace({ path : Str, base : Content, copy : Content }),
	]

	## What `apply` does with one file of the target.
	Applied : { path : Str, what : [Write(Str), FromCopy, Remove] }

	## The changes from the files of `base` to the files of `copy` (the table at the top). Each path is in a list once.
	make : { base : List(Diff.File), copy : List(Diff.File) } -> List(Diff.Change)
	make = |_x| crash "todo: slice 042"

	## The text of the diff (the tables at the top).
	render : List(Diff.Change) -> Str
	render = |_changes| crash "todo: slice 042"

	## The change of the diff on the files of `target` (the table at the top).
	apply : { changes : List(Diff.Change), target : List(Diff.File) } -> { done : List(Diff.Applied), failed : List(Str) }
	apply = |_x| crash "todo: slice 042"
}
