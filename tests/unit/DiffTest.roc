import lib.Diff

DiffTest :: [].{}

utf8 = |path, text| { path, content: Utf8(text) }

bin = |path, hash| { path, content: Binary(hash) }

lines = |list| "${Str.join_with(list, "\n")}\n"

# The text of the lines `l<from>` to `l<to>`. Each pair of `edits` is a line number and the text that replaces that line.
span : U64, U64, List((U64, Str)) -> Str
span = |from, to, edits| {
	var $out = ""
	var $k = from
	while $k <= to {
		$out = match edits.find_first(|(n, _)| n == $k) {
			Ok((_, text)) => "${$out}${text}\n"
			Err(_) => "${$out}l${$k.to_str()}\n"
		}
		$k = $k + 1
	}
	$out
}

numbered : U64, List((U64, Str)) -> Str
numbered = |n, edits| span(1, n, edits)

# The context lines ` l<from>` to ` l<to>` of a hunk.
kept : U64, U64 -> List(Str)
kept = |from, to| {
	var $out = []
	var $k = from
	while $k <= to {
		$out = $out.append(" l${$k.to_str()}")
		$k = $k + 1
	}
	$out
}

shown = |base, copy| Diff.render(Diff.make({ base, copy }))

# R-PA7 R-PA3: the unified diff of one text file. 3 lines of context, runs of changes with 6 kept lines or fewer between them are one hunk, and the first and the last hunk stop at the ends of the text. The deleted lines of a run come before the
# inserted lines. An empty text has the hunk number 0 on its side. A line has its own line end, so a file that gains or loses its final line end has a changed last line, and the line `\ No newline at end of file` follows each line that has none
# (also a kept line). 2 texts that are the same give no change. The cases have one shortest script each.
expect {
	one = |a, b| shown([utf8("f.txt", a)], [utf8("f.txt", b)])
	head = "--- a/f.txt\n+++ b/f.txt\n"
	two_hunks = head
		.concat(lines(["@@ -1,4 +1,4 @@", "-l1", "+X1", " l2", " l3", " l4", "@@ -6,7 +6,7 @@", " l6", " l7", " l8", "-l9", "+X9", " l10", " l11", " l12"]))
	one_hunk = head
		.concat(lines(["@@ -1,11 +1,11 @@", "-l1", "+X1"]))
		.concat(lines(kept(2, 7)))
		.concat(lines(["-l8", "+X8", " l9", " l10", " l11"]))
	rows = [
		("one changed line, 3 lines of context", one("one\ntwo\nthree\nfour\n", "one\n2\nthree\nfour\n"), head.concat(lines(["@@ -1,4 +1,4 @@", " one", "-two", "+2", " three", " four"]))),
		("a line is added at the top: the context is 3 lines", one("a\nb\nc\nd\ne\n", "z\na\nb\nc\nd\ne\n"), head.concat(lines(["@@ -1,3 +1,4 @@", "+z", " a", " b", " c"]))),
		("the final line end is added: the old last line has no line end", one("a\nb", "a\nb\n"), head.concat("@@ -1,2 +1,2 @@\n a\n-b\n\\ No newline at end of file\n+b\n")),
		("the final line end is removed", one("a\nb\n", "a\nb"), head.concat("@@ -1,2 +1,2 @@\n a\n-b\n+b\n\\ No newline at end of file\n")),
		("no final line end on both sides: a kept last line has the marker", one("a\nb\nc", "a\nX\nc"), head.concat("@@ -1,3 +1,3 @@\n a\n-b\n+X\n c\n\\ No newline at end of file\n")),
		("one line with no line end changes", one("a", "b"), head.concat("@@ -1,1 +1,1 @@\n-a\n\\ No newline at end of file\n+b\n\\ No newline at end of file\n")),
		("an empty file gets lines: the old side has the number 0", one("", "x\ny\n"), head.concat(lines(["@@ -0,0 +1,2 @@", "+x", "+y"]))),
		("a file becomes empty: the new side has the number 0", one("x\ny\n", ""), head.concat(lines(["@@ -1,2 +0,0 @@", "-x", "-y"]))),
		("an empty file gets one line with no line end", one("", "x"), head.concat("@@ -0,0 +1,1 @@\n+x\n\\ No newline at end of file\n")),
		("6 kept lines between 2 changes: one hunk", one(numbered(20, []), numbered(20, [(1, "X1"), (8, "X8")])), one_hunk),
		("7 kept lines between 2 changes: 2 hunks", one(numbered(20, []), numbered(20, [(1, "X1"), (9, "X9")])), two_hunks),
		("the change on the last line: the hunk stops at the end", one(numbered(20, []), numbered(20, [(20, "X20")])), head.concat(lines(["@@ -17,4 +17,4 @@", " l17", " l18", " l19", "-l20", "+X20"]))),
		("a run of 2 changed lines: both deleted lines come first", one("a\nb\nc\nd\n", "a\nX\nY\nd\n"), head.concat(lines(["@@ -1,4 +1,4 @@", " a", "-b", "-c", "+X", "+Y", " d"]))),
		("2 texts that are the same", one("a\nb\n", "a\nb\n"), ""),
		("2 empty texts", one("", ""), ""),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-PA7 R-PA3: the files of a diff. The paths are in byte order (`B.txt` before `a.txt`, `dir.txt` before `dir/x.txt`). A file in the copy only is added, a file in the base only is deleted (with its lines), a file that is
# in both with the same content has no change. An empty file that is added or deleted has the 2 header lines and no hunk. A file that is not UTF-8 text is replaced whole (one line), when its sha256 differs. The same hash gives no change.
expect {
	order = shown([], [utf8("dir/x.txt", ""), utf8("dir.txt", ""), utf8("a.txt", ""), utf8("B.txt", "")])
	mixed = shown(
		[utf8("keep.txt", "k\n"), utf8("gone.txt", "g1\ng2"), utf8("empty.txt", ""), utf8("edit.txt", "a\n"), bin("same.bin", "h1"), bin("data.bin", "h1"), utf8("was_text", "t\n"), bin("old.bin", "h9")],
		[utf8("keep.txt", "k\n"), utf8("new.txt", "n1\nn2\n"), utf8("edit.txt", "b\n"), bin("same.bin", "h1"), bin("data.bin", "h2"), bin("was_text", "h3"), bin("fresh.bin", "h4")],
	)
	want_order = "--- /dev/null\n+++ b/B.txt\n--- /dev/null\n+++ b/a.txt\n--- /dev/null\n+++ b/dir.txt\n--- /dev/null\n+++ b/dir/x.txt\n"
	want_mixed = Str.join_with(
		[
			"Binary files a/data.bin and b/data.bin differ\n",
			"--- a/edit.txt\n+++ b/edit.txt\n@@ -1,1 +1,1 @@\n-a\n+b\n",
			"--- a/empty.txt\n+++ /dev/null\n",
			"Binary files /dev/null and b/fresh.bin differ\n",
			"--- a/gone.txt\n+++ /dev/null\n@@ -1,2 +0,0 @@\n-g1\n-g2\n\\ No newline at end of file\n",
			"--- /dev/null\n+++ b/new.txt\n@@ -0,0 +1,2 @@\n+n1\n+n2\n",
			"Binary files a/old.bin and /dev/null differ\n",
			"Binary files a/was_text and b/was_text differ\n",
		],
		"",
	)
	rows = [
		("the paths are in byte order", order, want_order),
		("add, delete, edit, binary, no change", mixed, want_mixed),
		("no file on both sides", shown([], []), ""),
		("the same trees", shown([utf8("a", "x\n"), bin("b", "h")], [bin("b", "h"), utf8("a", "x\n")]), ""),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-PA7 R-PA5: `apply` of the diff of 2 trees on a target. `done` and `failed` are in the order of the changes. A diff on the tree that it came from gives the copy (the first rows: also the empty text, a final line end that
# comes or goes). The place of a hunk can be any number of lines away from its number, each hunk after the one before it. A hunk has no fuzz: one changed context line, one changed old line or a final line end that is not
# there makes the hunk fail, and a file with one failed hunk is not written at all (the hunks before it are not in `done`). A failed file does not stop the others. The other kinds of change: an `Add` on a target with no such
# file, a `Delete` of the same content, a binary file that is replaced when the target has the bytes of the base (the bytes come from the copy: `FromCopy`).
expect {
	f = |a, b| {
		made = Diff.make({ base: [utf8("f.txt", a)], copy: [utf8("f.txt", b)] })
		Diff.apply({ changes: made, target: [utf8("f.txt", a)] })
	}
	wrote = |text| { done: [{ path: "f.txt", what: Write(text) }], failed: [] }
	round = [
		("a text and its edit", f("one\ntwo\nthree\n", "one\n2\nthree\n"), wrote("one\n2\nthree\n")),
		("an empty text gets lines", f("", "x\ny\n"), wrote("x\ny\n")),
		("a text becomes empty", f("x\ny\n", ""), wrote("")),
		("the final line end comes", f("a\nb", "a\nb\n"), wrote("a\nb\n")),
		("the final line end goes", f("a\nb\n", "a\nb"), wrote("a\nb")),
		("one line with no line end", f("a", "b"), wrote("b")),
		("2 hunks far apart", f(numbered(30, []), numbered(30, [(2, "X2"), (28, "X28")])), wrote(numbered(30, [(2, "X2"), (28, "X28")]))),
		("the same texts: no change", f("a\n", "a\n"), { done: [], failed: [] }),
		("lines move: a block goes to the end", f("a\nb\nc\nd\n", "a\nd\nb\nc\n"), wrote("a\nd\nb\nc\n")),
	]
	# The hunks of `numbered(20, [(3, "X3"), (15, "X15")])` have the contexts l1 to l6 and l12 to l18.
	base = numbered(20, [])
	copy = numbered(20, [(3, "X3"), (15, "X15")])
	up = |target| Diff.apply({ changes: Diff.make({ base: [utf8("f.txt", base)], copy: [utf8("f.txt", copy)] }), target: [utf8("f.txt", target)] })
	top = "n1\nn2\nn3\nn4\nn5\n"
	moved_target = "${top}${span(1, 8, [])}m1\nm2\n${span(9, 20, [])}"
	moved = "${top}${span(1, 8, [(3, "X3")])}m1\nm2\n${span(9, 20, [(15, "X15")])}"
	far = numbered(20, [(10, "mine")])
	target_rows = [
		("5 lines at the top and 2 between the hunks: both hunks move", up(moved_target), wrote(moved)),
		("a changed line that no hunk touches stays", up(far), wrote(numbered(20, [(3, "X3"), (10, "mine"), (15, "X15")]))),
		("a changed context line of the first hunk", up(numbered(20, [(5, "other")])), { done: [], failed: ["f.txt"] }),
		("a changed context line of the second hunk only: the first hunk is not written", up(numbered(20, [(17, "other")])), { done: [], failed: ["f.txt"] }),
		("a changed old line", up(numbered(20, [(3, "other")])), { done: [], failed: ["f.txt"] }),
		("a line that no hunk touches has no line end in the target", up("${span(1, 19, [])}l20"), wrote("${span(1, 19, [(3, "X3"), (15, "X15")])}l20")),
		("an empty file that is not empty any more", Diff.apply({ changes: Diff.make({ base: [utf8("f.txt", "")], copy: [utf8("f.txt", "x\n")] }), target: [utf8("f.txt", "z\n")] }), { done: [], failed: ["f.txt"] }),
		("the final line end of the old line is gone", Diff.apply({ changes: Diff.make({ base: [utf8("f.txt", "a\nb\n")], copy: [utf8("f.txt", "a\nB\n")] }), target: [utf8("f.txt", "a\nb")] }), { done: [], failed: ["f.txt"] }),
	]
	# The kinds of change, on a target that is another release.
	changes = Diff.make({
		base: [utf8("edit.txt", "a\nb\nc\n"), utf8("gone.txt", "g\n"), bin("data.bin", "h1"), bin("moved.bin", "h5"), utf8("was_text", "t\n"), utf8("lost.txt", "z\n")],
		copy: [utf8("edit.txt", "a\nB\nc\n"), utf8("new.txt", "n\n"), bin("data.bin", "h2"), bin("moved.bin", "h6"), bin("was_text", "h3"), bin("fresh.bin", "h4"), utf8("lost.txt", "z\n")],
	})
	target = [utf8("edit.txt", "pre\na\nb\nc\n"), utf8("gone.txt", "g\n"), bin("data.bin", "h1"), bin("moved.bin", "hX"), utf8("was_text", "t\n"), utf8("lost.txt", "z\n")]
	kinds = Diff.apply({ changes, target })
	want_kinds = {
		done: [
			{ path: "data.bin", what: FromCopy },
			{ path: "edit.txt", what: Write("pre\na\nB\nc\n") },
			{ path: "fresh.bin", what: FromCopy },
			{ path: "gone.txt", what: Remove },
			{ path: "new.txt", what: Write("n\n") },
			{ path: "was_text", what: FromCopy },
		],
		failed: ["moved.bin"],
	}
	# Edit of a path that the target has not, or has as a binary file.
	edit_missing = Diff.apply({ changes: Diff.make({ base: [utf8("f.txt", "a\n")], copy: [utf8("f.txt", "b\n")] }), target: [] })
	edit_binary = Diff.apply({ changes: Diff.make({ base: [utf8("f.txt", "a\n")], copy: [utf8("f.txt", "b\n")] }), target: [bin("f.txt", "h")] })
	# 2 files: the first fails, the second applies, the order is the one of the paths.
	two = Diff.apply({
		changes: Diff.make({ base: [utf8("b.txt", "1\n2\n"), utf8("a.txt", "x\ny\n")], copy: [utf8("b.txt", "1\n3\n"), utf8("a.txt", "x\nz\n")] }),
		target: [utf8("b.txt", "1\n2\n"), utf8("a.txt", "x\nq\n")],
	})
	# R-PA7 (answer Q2): a hunk that fits at 2 places or more goes to the place nearest to its number. A tie takes the first place.
	at = |start, text| Diff.apply({
		changes: [Edit({ path: "f.txt", hunks: [{ old_start: start, old_len: 1, new_start: start, new_len: 1, lines: [Del("a\n"), Ins("b\n")] }] })],
		target: [utf8("f.txt", text)],
	})
	places = "a\nx\nx\nx\na\nx\nx\nx\nx\na\n"
	# R-PA7 (answer Q4): `Add` on a path that the target has, and `Delete` on a path that the target has not or has with other content, fail for that file.
	add_over = Diff.apply({ changes: Diff.make({ base: [], copy: [utf8("n.txt", "n\n")] }), target: [utf8("n.txt", "old\n")] })
	delete_with = |files| Diff.apply({ changes: Diff.make({ base: [utf8("g.txt", "g\n")], copy: [] }), target: files })
	delete_binary = Diff.apply({ changes: Diff.make({ base: [bin("g.bin", "h1")], copy: [] }), target: [bin("g.bin", "h2")] })
	rows = round.concat(target_rows).concat([
		("the kinds of change on another release (Add, Delete, Replace, a failed Replace)", kinds, want_kinds),
		("an Edit of a path that the target has not", edit_missing, { done: [], failed: ["f.txt"] }),
		("an Edit of a path that the target has as a binary file", edit_binary, { done: [], failed: ["f.txt"] }),
		("2 files: a failed one does not stop the other", two, { done: [{ path: "b.txt", what: Write("1\n3\n") }], failed: ["a.txt"] }),
		("2 places: the one that is the number of the hunk", at(5, places), { done: [{ path: "f.txt", what: Write("a\nx\nx\nx\nb\nx\nx\nx\nx\na\n") }], failed: [] }),
		("2 places: the nearer one, after the number", at(7, "a\nx\nx\nx\nx\nx\nx\nx\nx\na\n"), { done: [{ path: "f.txt", what: Write("a\nx\nx\nx\nx\nx\nx\nx\nx\nb\n") }], failed: [] }),
		("2 places: the nearer one is before the number, the far one after it", at(7, "x\nx\nx\nx\na\nx\nx\nx\nx\na\n"), { done: [{ path: "f.txt", what: Write("x\nx\nx\nx\nb\nx\nx\nx\nx\na\n") }], failed: [] }),
		("2 places: one before the number, a nearer one after it", at(7, "x\nx\nx\na\nx\nx\nx\nx\na\nx\n"), { done: [{ path: "f.txt", what: Write("x\nx\nx\na\nx\nx\nx\nx\nb\nx\n") }], failed: [] }),
		("2 places at the same distance: the first", at(3, "a\nx\nx\nx\na\n"), { done: [{ path: "f.txt", what: Write("b\nx\nx\nx\na\n") }], failed: [] }),
		("an Add on a path that the target has", add_over, { done: [], failed: ["n.txt"] }),
		("a Delete on a path that the target has not", delete_with([]), { done: [], failed: ["g.txt"] }),
		("a Delete on a text that is not the one of the base", delete_with([utf8("g.txt", "other\n")]), { done: [], failed: ["g.txt"] }),
		("a Delete on a binary file with other bytes", delete_binary, { done: [], failed: ["g.bin"] }),
		("no change on no target", Diff.apply({ changes: [], target: [] }), { done: [], failed: [] }),
	])
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
