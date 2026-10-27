import Text

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
	make = |x| {
		base = Dict.from_list(x.base.map(|f| (f.path, f.content)))
		copy = Dict.from_list(x.copy.map(|f| (f.path, f.content)))
		paths = Text.sorted_unique(x.base.map(|f| f.path).concat(x.copy.map(|f| f.path)))
		paths.keep_oks(|path| change_of(path, base, copy))
	}

	## The text of the diff (the tables at the top).
	render : List(Diff.Change) -> Str
	render = |changes| Str.join_with(changes.map(render_change), "")

	## The change of the diff on the files of `target` (the table at the top).
	apply : { changes : List(Diff.Change), target : List(Diff.File) } -> { done : List(Diff.Applied), failed : List(Str) }
	apply = |x| {
		results = x.changes.map(|change| apply_change(change, x.target))
		{ done: results.keep_oks(|r| r), failed: results.keep_errs(|r| r) }
	}
}

# ---- make ----

# The change of one path, or `NoChange` when both trees have the same content (or no file).
change_of : Str, Dict(Str, Diff.Content), Dict(Str, Diff.Content) -> Try(Diff.Change, [NoChange])
change_of = |path, base, copy| match (base.get(path), copy.get(path)) {
	(Ok(b), Ok(c)) => if b == c {
		Err(NoChange)
	} else {
		match (b, c) {
			(Utf8(old), Utf8(new)) => Ok(Edit({ path, hunks: hunks_of(old, new) }))
			_ => Ok(Replace({ path, base: b, copy: c }))
		}
	}
	(Err(_), Ok(c)) => Ok(Add({ path, content: c }))
	(Ok(b), Err(_)) => Ok(Delete({ path, content: b }))
	(Err(_), Err(_)) => Err(NoChange)
}

# The lines of a text, each with its own line end (the top of this file).
lines_of : Str -> List(Str)
lines_of = |text| {
	parts = text.split_on("\n")
	match parts.last() {
		Ok("") => parts.drop_last(1).map(|p| "${p}\n")
		Ok(last) => parts.drop_last(1).map(|p| "${p}\n").append(last)
		Err(_) => []
	}
}

# R-PA7: the hunks of 2 texts. The shortest script, in groups of changes with 3 lines of context.
hunks_of : Str, Str -> List(Diff.Hunk)
hunks_of = |old, new| {
	script = script_of(lines_of(old), lines_of(new))
	groups(script).map(|g| hunk_of(script, g))
}

# The shortest script. The common start and the common end are cut, and the table of the longest common run does the middle.
script_of : List(Str), List(Str) -> List(Diff.Line)
script_of = |a, b| {
	lead = common_lead(a, b)
	rest_a = a.drop_first(lead)
	rest_b = b.drop_first(lead)
	tail = common_tail(rest_a, rest_b)
	mid_a = rest_a.take_first(rest_a.len() - tail)
	mid_b = rest_b.take_first(rest_b.len() - tail)
	keeps = |ls| ls.map(|l| Keep(l))
	keeps(a.take_first(lead)).concat(middle(mid_a, mid_b)).concat(keeps(rest_a.drop_first(rest_a.len() - tail)))
}

common_lead : List(Str), List(Str) -> U64
common_lead = |a, b| {
	var $n = 0.U64
	while $n < a.len() and $n < b.len() and (a.get($n) ?? "") == (b.get($n) ?? "") {
		$n = $n + 1
	}
	$n
}

common_tail : List(Str), List(Str) -> U64
common_tail = |a, b| {
	most = if a.len() < b.len() a.len() else b.len()
	var $n = 0.U64
	while $n < most and (a.get(a.len() - 1 - $n) ?? "") == (b.get(b.len() - 1 - $n) ?? "") {
		$n = $n + 1
	}
	$n
}

# The script of the middle parts. The walk goes from the end to the start and takes an inserted line when the 2 ways are equal, so in a run of changes all deleted lines come before the inserted lines (R-PA7 order).
middle : List(Str), List(Str) -> List(Diff.Line)
middle = |a, b| if a.is_empty() {
	b.map(|l| Ins(l))
} else if b.is_empty() {
	a.map(|l| Del(l))
} else {
	table = lcs_table(a, b)
	cell = |r, c| (table.get(r) ?? []).get(c) ?? 0
	var $i = a.len()
	var $j = b.len()
	var $rev = []
	while $i > 0 or $j > 0 {
		if $j == 0 {
			$rev = $rev.append(Del(a.get($i - 1) ?? ""))
			$i = $i - 1
		} else if $i == 0 {
			$rev = $rev.append(Ins(b.get($j - 1) ?? ""))
			$j = $j - 1
		} else if (a.get($i - 1) ?? "") == (b.get($j - 1) ?? "") {
			$rev = $rev.append(Keep(a.get($i - 1) ?? ""))
			$i = $i - 1
			$j = $j - 1
		} else if cell($i, $j - 1) >= cell($i - 1, $j) {
			$rev = $rev.append(Ins(b.get($j - 1) ?? ""))
			$j = $j - 1
		} else {
			$rev = $rev.append(Del(a.get($i - 1) ?? ""))
			$i = $i - 1
		}
	}
	$rev.rev()
}

# `table[i][j]` is the length of the longest common run of the first `i` lines of `a` and the first `j` lines of `b`.
lcs_table : List(Str), List(Str) -> List(List(U32))
lcs_table = |a, b| {
	var $rows = [List.repeat(0.U32, b.len() + 1)]
	for line in a {
		prev = $rows.last() ?? []
		var $row = [0.U32]
		var $j = 0.U64
		while $j < b.len() {
			cell = if line == (b.get($j) ?? "") {
				(prev.get($j) ?? 0) + 1
			} else {
				up = prev.get($j + 1) ?? 0
				left = $row.last() ?? 0
				if up >= left up else left
			}
			$row = $row.append(cell)
			$j = $j + 1
		}
		$rows = $rows.append($row)
	}
	$rows
}

# The groups of changes: the first and the last index of each. 6 kept lines or fewer between 2 changes keep them in one group (R-PA7 merge).
groups : List(Diff.Line) -> List({ first : U64, last : U64 })
groups = |script| script.map_with_index(|line, i| (line, i)).fold(
	[],
	|acc, (line, i)| match line {
		Keep(_) => acc
		_ => match acc.last() {
			Ok(g) if i - g.last <= 7 => acc.drop_last(1).append({ first: g.first, last: i })
			_ => acc.append({ first: i, last: i })
		}
	},
)

# One hunk: the lines of the group with 3 lines of context on each side, and the numbers (R-PA7 numbers and counts).
hunk_of : List(Diff.Line), { first : U64, last : U64 } -> Diff.Hunk
hunk_of = |script, g| {
	start = if g.first > 3 g.first - 3 else 0
	lines = script.sublist({ start, len: g.last + 4 - start })
	before = script.take_first(start)
	old_before = before.count_if(|l| !is_ins(l))
	new_before = before.count_if(|l| !is_del(l))
	old_len = lines.count_if(|l| !is_ins(l))
	new_len = lines.count_if(|l| !is_del(l))
	{
		old_start: if old_len == 0 old_before else old_before + 1,
		old_len,
		new_start: if new_len == 0 new_before else new_before + 1,
		new_len,
		lines,
	}
}

is_ins : Diff.Line -> Bool
is_ins = |line| match line {
	Ins(_) => Bool.True
	_ => Bool.False
}

is_del : Diff.Line -> Bool
is_del = |line| match line {
	Del(_) => Bool.True
	_ => Bool.False
}

# ---- render ----

render_change : Diff.Change -> Str
render_change = |change| match change {
	Edit({ path, hunks }) => "--- a/${path}\n+++ b/${path}\n${Str.join_with(hunks.map(render_hunk), "")}"
	Add({ path, content: Utf8(text) }) => {
		lines = lines_of(text)
		hunk = if lines.is_empty() "" else "@@ -0,0 +1,${lines.len().to_str()} @@\n${Str.join_with(lines.map(|l| render_line("+", l)), "")}"
		"--- /dev/null\n+++ b/${path}\n${hunk}"
	}
	Delete({ path, content: Utf8(text) }) => {
		lines = lines_of(text)
		hunk = if lines.is_empty() "" else "@@ -1,${lines.len().to_str()} +0,0 @@\n${Str.join_with(lines.map(|l| render_line("-", l)), "")}"
		"--- a/${path}\n+++ /dev/null\n${hunk}"
	}
	Add({ path, content: Binary(_) }) => "Binary files /dev/null and b/${path} differ\n"
	Delete({ path, content: Binary(_) }) => "Binary files a/${path} and /dev/null differ\n"
	Replace({ path, .. }) => "Binary files a/${path} and b/${path} differ\n"
}

render_hunk : Diff.Hunk -> Str
render_hunk = |h| {
	head = "@@ -${h.old_start.to_str()},${h.old_len.to_str()} +${h.new_start.to_str()},${h.new_len.to_str()} @@\n"
	body = h.lines.map(
		|line| match line {
			Keep(t) => render_line(" ", t)
			Del(t) => render_line("-", t)
			Ins(t) => render_line("+", t)
		},
	)
	"${head}${Str.join_with(body, "")}"
}

# A line with its prefix. A line with no line end is followed by the marker (D1).
render_line : Str, Str -> Str
render_line = |prefix, text| if text.ends_with("\n") "${prefix}${text}" else "${prefix}${text}\n\\ No newline at end of file\n"

# ---- apply ----

apply_change : Diff.Change, List(Diff.File) -> Try(Diff.Applied, Str)
apply_change = |change, target| match change {
	Edit({ path, hunks }) => match content_of(target, path) {
		Ok(Utf8(text)) => match apply_hunks(text, hunks) {
			Ok(new) => Ok({ path, what: Write(new) })
			Err(NoFit) => Err(path)
		}
		_ => Err(path)
	}
	Replace({ path, base, copy }) => match content_of(target, path) {
		Ok(now) if now == base => Ok(written(path, copy))
		_ => Err(path)
	}
	Add(file) => match content_of(target, file.path) {
		Ok(_) => Err(file.path)
		Err(_) => Ok(written(file.path, file.content))
	}
	Delete(file) => match content_of(target, file.path) {
		Ok(now) if now == file.content => Ok({ path: file.path, what: Remove })
		_ => Err(file.path)
	}
}

content_of : List(Diff.File), Str -> Try(Diff.Content, [NoFile])
content_of = |target, path| match target.find_first(|f| f.path == path) {
	Ok(file) => Ok(file.content)
	Err(_) => Err(NoFile)
}

# A text is written, the bytes of a binary file come from the copy.
written : Str, Diff.Content -> Diff.Applied
written = |path, content| match content {
	Utf8(text) => { path, what: Write(text) }
	Binary(_) => { path, what: FromCopy }
}

Cursor : { out : List(Str), pos : U64, shift : I64 }

# R-PA7: the hunks one by one from the top. Each hunk goes to its place (`place_hunk`), and the text is the result only when all hunks fit.
apply_hunks : Str, List(Diff.Hunk) -> Try(Str, [NoFit])
apply_hunks = |text, hunks| {
	lines = lines_of(text)
	end = hunks.fold_try({ out: [], pos: 0, shift: 0 }, |cur, h| place_hunk(lines, cur, h))?
	Ok(Str.join_with(end.out.concat(lines.drop_first(end.pos)), ""))
}

# One hunk. `cur.pos` is the first line after the hunk before. `cur.shift` is how far that hunk moved from its number.
place_hunk : List(Str), Cursor, Diff.Hunk -> Try(Cursor, [NoFit])
place_hunk = |lines, cur, h| {
	old = h.lines.keep_oks(
		|l| match l {
			Keep(t) | Del(t) => Ok(t)
			Ins(_) => Err(NotOld)
		},
	)
	new = h.lines.keep_oks(
		|l| match l {
			Keep(t) | Ins(t) => Ok(t)
			Del(_) => Err(NotNew)
		},
	)
	if old.is_empty() {
		# The base file was empty: the hunk applies to an empty text only.
		if lines.is_empty() Ok({ out: cur.out.concat(new), pos: 0, shift: cur.shift }) else Err(NoFit)
	} else if old.len() > lines.len() {
		Err(NoFit)
	} else {
		number = if h.old_start > 0 h.old_start - 1 else 0
		wanted = number.to_i64_wrap() + cur.shift
		at = nearest(lines, old, { from: cur.pos, last: lines.len() - old.len(), wanted })?
		Ok({
			out: cur.out.concat(lines.sublist({ start: cur.pos, len: at - cur.pos })).concat(new),
			pos: at + old.len(),
			shift: at.to_i64_wrap() - number.to_i64_wrap(),
		})
	}
}

# Q2: the place of `old` in `lines` (from `from` to `last`) that is the nearest to `wanted`. 2 places at the same distance: the first.
nearest : List(Str), List(Str), { from : U64, last : U64, wanted : I64 } -> Try(U64, [NoFit])
nearest = |lines, old, spot| {
	var $found = Bool.False
	var $at = 0.U64
	var $dist = 0.I64
	var $p = spot.from
	while $p <= spot.last {
		if fits(lines, old, $p) {
			d = ($p.to_i64_wrap() - spot.wanted).abs()
			if !$found or d < $dist {
				$found = Bool.True
				$at = $p
				$dist = d
			}
			# The places after this one are farther from `wanted`.
			if $p.to_i64_wrap() >= spot.wanted {
				break
			}
		}
		$p = $p + 1
	}
	if $found Ok($at) else Err(NoFit)
}

fits : List(Str), List(Str), U64 -> Bool
fits = |lines, old, p| match old {
	[first, ..] => (lines.get(p) ?? "") == first and lines.sublist({ start: p, len: old.len() }) == old
	[] => Bool.False
}
