import lib.Selector

SelectorTest :: [].{}

# The expected value of each row is the design text, not the code. A wrong row prints with `dbg`.

# R-SL3 R-SL4 R-SL5 R-SL6 R-SL7 R-SL9 R-SL10 R-SL12 R-SL13 R-SL15: the selector as typed after `@`, with no `--git`.
# A release version, a range, a series (a bare version with 1 or 2 parts is a caret range), `latest`, a nightly tag
# in both forms, a relative step, a commit sha (hex only, 7 or more characters), and the errors.
# `mian` is a typo, not a branch: it is an error, so it never starts a source build.
expect {
	rows = [
		("1.4.0", Ok(Selector.Exact("1.4.0"))),
		("0.25.1", Ok(Selector.Exact("0.25.1"))),
		("^2", Ok(Selector.Range("^2"))),
		("^1.2", Ok(Selector.Range("^1.2"))),
		("2", Ok(Selector.Range("^2"))),
		("1.2", Ok(Selector.Range("^1.2"))),
		("0.25", Ok(Selector.Range("^0.25"))),
		("latest", Ok(Selector.Latest)),
		("nightly-2026-10-09-258ab27", Ok(Selector.Nightly("nightly-2026-10-09-258ab27"))),
		("nightly-2026-July-31-123c5d7", Ok(Selector.Nightly("nightly-2026-July-31-123c5d7"))),
		("-1", Ok(Selector.Step(-1))),
		("+2", Ok(Selector.Step(2))),
		("dd03c09e", Ok(Selector.GitSha("dd03c09e"))),
		("dd03c0", Err(Unknown)),
		("beef", Err(Unknown)),
		("mian", Err(Unknown)),
		("main", Err(Unknown)),
		("", Err(Empty)),
	]
	bad = rows.keep_if(|(text, want)| Selector.parse(text, Bool.False) != want).map(|(text, want)| (text, want, Selector.parse(text, Bool.False)))
	dbg bad
	bad == []
}

# R-SL8 R-SL11 R-SL13 R-SL9: with `--git` a text is a git ref. `--git` skips the rules for releases and shas,
# so `latest` and a version are git refs too (a branch named `latest` needs `--git`). An empty text is still an error.
expect {
	rows = [
		("main", Ok(Selector.GitRef("main"))),
		("mian", Ok(Selector.GitRef("mian"))),
		("latest", Ok(Selector.GitRef("latest"))),
		("1.4.0", Ok(Selector.GitRef("1.4.0"))),
		("dd03c09e", Ok(Selector.GitRef("dd03c09e"))),
		("", Err(Empty)),
	]
	bad = rows.keep_if(|(text, want)| Selector.parse(text, Bool.True) != want).map(|(text, want)| (text, want, Selector.parse(text, Bool.True)))
	dbg bad
	bad == []
}
