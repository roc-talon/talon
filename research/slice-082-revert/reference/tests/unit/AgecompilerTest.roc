import lib.Age

AgecompilerTest :: [].{}

# R-C15 (slice 084): `Age.compiler_name` is the name that a pattern of `min-release-age-exclude` compares for a compiler. A nightly (either tag form, R-CV1) is `roc-lang/nightlies`.
# A release is `roc-lang/roc`. The expected values are the design text (Resolution 2, R-C15, table row "compilers").
expect {
	rows = [
		("a nightly, the number form", Age.compiler_name("nightly-2026-10-09-258ab27"), "roc-lang/nightlies"),
		("a nightly, the month name form (R-CV1)", Age.compiler_name("nightly-2026-July-31-123c5d7"), "roc-lang/nightlies"),
		("a release", Age.compiler_name("0.1.0"), "roc-lang/roc"),
		("another release", Age.compiler_name("0.12.3"), "roc-lang/roc"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-C15 R-C12 (slice 084, decision Q1 of 2026-10-27): a pattern matches the name of a compiler as it matches any name. So `roc-lang/nightlies`, `roc-lang/*` and `ROC-LANG/NIGHTLIES` match a nightly.
# `roc-lang/roc` matches a release and not a nightly. `acme/*` matches no compiler. A wildcard is no special case for compilers.
expect {
	hit = |pattern, id| Age.matches({ pattern, name: Ok(Age.compiler_name(id)) })
	nightly = "nightly-2026-10-09-258ab27"
	release = "0.1.0"
	rows = [
		("nightly: the exact name", hit("roc-lang/nightlies", nightly), Bool.True),
		("nightly: the owner wildcard (Q1)", hit("roc-lang/*", nightly), Bool.True),
		("nightly: other case", hit("ROC-LANG/NIGHTLIES", nightly), Bool.True),
		("nightly: the name of the releases", hit("roc-lang/roc", nightly), Bool.False),
		("nightly: another owner", hit("acme/*", nightly), Bool.False),
		("nightly: no prefix match", hit("roc-lang/night", nightly), Bool.False),
		("release: the exact name", hit("roc-lang/roc", release), Bool.True),
		("release: the owner wildcard (Q1)", hit("roc-lang/*", release), Bool.True),
		("release: the name of the nightlies", hit("roc-lang/nightlies", release), Bool.False),
		("release: another owner", hit("acme/*", release), Bool.False),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
