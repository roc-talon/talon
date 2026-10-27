import lib.Age

AgeTest :: [].{}

# Slice 081. The expected value of each row is the design text (Resolution 2, R-C7, R-C11 to R-C16), not the code.
# A wrong row prints with `dbg`. Times are seconds. `now` is 100 days after the epoch, so a release can be older than `now`.

day : U64
day = 86400

now : U64
now = 100 * day

# R-C12 (points 3 and 4): the pattern forms. `owner/repo` and `owner/*` are good. A part has only ASCII letters, digits, `-`, `_` and `.`, and it is not empty, `.` or `..`. `*` is allowed as the whole repo part only.
# To skip the age for everything, the user writes `min-release-age = "0d"`, so `*/*` is bad.
expect {
	good = ["acme/platform", "acme/*", "Acme/Platform", "a.b/c_d-e", "roc-lang/roc", "ROC-LANG/*", "a/b", "9/9"]
	bad = ["*", "*/repo", "*/*", "ow*/repo", "owner/re*", "owner/**", "owner/repo@1.0.0", "github.com/owner/repo", "acme/", "/repo", "a/b/c", "acme/..", "../repo", "./repo", "acme/.", "acme/re po", " acme/repo", "acme/repo ", "acme/re\npo", "acme/ré", "", "/", "acme", "acme*", "owner/*x", "*acme/x"]
	wrongly_bad = good.keep_if(|p| Age.check(p) != Ok({})).map(|p| (p, "should be Ok"))
	wrongly_good = bad.keep_if(|p| Age.check(p) != Err(BadPattern)).map(|p| (p, "should be BadPattern"))
	dbg wrongly_bad
	dbg wrongly_good
	wrongly_bad == [] and wrongly_good == []
}

# R-C12 (points 1 and 2): the compare is ASCII case-insensitive on both parts. `acme/*` matches each repository of that owner. There is no prefix match
# (`acme/plat` against `acme/platform`, `acme/*` against `acme-x/y`). A release with no name (`NoName`) matches no pattern, also not `acme/*`. A bad pattern matches nothing, also a name that it seems to match.
expect {
	name = |text| Ok(text)
	rows = [
		("same text", "acme/platform", name("acme/platform"), Bool.True),
		("owner in another case", "ACME/platform", name("acme/platform"), Bool.True),
		("repo in another case", "acme/PLATFORM", name("acme/platform"), Bool.True),
		("name in upper case", "acme/platform", name("Acme/Platform"), Bool.True),
		("wildcard", "acme/*", name("acme/platform"), Bool.True),
		("wildcard, upper case owner in the name", "acme/*", name("Acme/x"), Bool.True),
		("wildcard, upper case owner in the pattern", "ACME/*", name("acme/x"), Bool.True),
		("another repo of the same owner", "acme/other", name("acme/platform"), Bool.False),
		("a prefix of the repo is not a match", "acme/plat", name("acme/platform"), Bool.False),
		("the repo is a prefix of the pattern", "acme/platform", name("acme/plat"), Bool.False),
		("a prefix of the owner is not a match", "acme/*", name("acme-x/y"), Bool.False),
		("the owner is a prefix of the pattern owner", "acme-x/*", name("acme/y"), Bool.False),
		("another owner", "other/*", name("acme/platform"), Bool.False),
		("the same repo of another owner", "acme/lib", name("other/lib"), Bool.False),
		("no name", "acme/platform", Err(NoName), Bool.False),
		("no name and a wildcard", "acme/*", Err(NoName), Bool.False),
		("a bad pattern: star for the owner", "*/platform", name("acme/platform"), Bool.False),
		("a bad pattern: all", "*/*", name("acme/platform"), Bool.False),
		("a bad pattern: star in a part", "acme/plat*", name("acme/platform"), Bool.False),
		("a bad pattern: the owner only", "acme", name("acme"), Bool.False),
		("a bad pattern: an empty text", "", name(""), Bool.False),
		("a bad pattern: a version", "acme/platform@1.0.0", name("acme/platform"), Bool.False),
	]
	bad = rows.keep_if(|(_, pattern, n, want)| Age.matches({ pattern, name: n }) != want).map(|(label, _, _, want)| (label, want))
	dbg bad
	bad == []
}

# R-C12 R-C16: `first_match` gives the first pattern of the list that matches, in the order of the list, as written (not folded to lower case).
# No match, an empty list and `NoName` give `Err(None)`.
expect {
	rows = [
		("the first of two that match", Age.first_match({ patterns: ["acme/*", "acme/lib"], name: Ok("acme/lib") }), Ok("acme/*")),
		("the second one matches, the first not", Age.first_match({ patterns: ["other/*", "acme/lib"], name: Ok("acme/lib") }), Ok("acme/lib")),
		("as written", Age.first_match({ patterns: ["Acme/*"], name: Ok("acme/x") }), Ok("Acme/*")),
		("as written, upper case repo", Age.first_match({ patterns: ["x/y", "ACME/LIB"], name: Ok("acme/lib") }), Ok("ACME/LIB")),
		("none", Age.first_match({ patterns: ["other/*", "acme/other"], name: Ok("acme/lib") }), Err(None)),
		("an empty list", Age.first_match({ patterns: [], name: Ok("acme/lib") }), Err(None)),
		("no name", Age.first_match({ patterns: ["acme/*"], name: Err(NoName) }), Err(None)),
		("a bad pattern is skipped", Age.first_match({ patterns: ["*/*", "acme/lib"], name: Ok("acme/lib") }), Ok("acme/lib")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-C14: the list that applies is the union of the list of `talon.toml` (`project`) and the list of `config.toml` (`user`). The project list is first. A text in both lists counts once, at its first place. Equal means equal text.
expect {
	rows = [
		("project first", Age.join({ project: ["a/x"], user: ["b/y"] }), ["a/x", "b/y"]),
		("a text in both lists counts once", Age.join({ project: ["a/x", "c/*"], user: ["c/*", "b/y"] }), ["a/x", "c/*", "b/y"]),
		("the first place is kept", Age.join({ project: ["c/*"], user: ["b/y", "c/*"] }), ["c/*", "b/y"]),
		("both empty", Age.join({ project: [], user: [] }), []),
		("an empty project list removes nothing", Age.join({ project: [], user: ["b/y", "c/*"] }), ["b/y", "c/*"]),
		("an empty user list", Age.join({ project: ["a/x"], user: [] }), ["a/x"]),
		("the same list in both", Age.join({ project: ["a/x", "b/y"], user: ["a/x", "b/y"] }), ["a/x", "b/y"]),
		("a text twice in one list", Age.join({ project: ["a/x", "a/x"], user: [] }), ["a/x"]),
		("another case is another text", Age.join({ project: ["a/x"], user: ["A/X"] }), ["a/x", "A/X"]),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-C7 R-C12 R-C15: the one age test. A release is hidden when `published_at + min_age > now` and no pattern matches its name. A release at exactly `min_age` seconds is visible.
# `min_age` 0 hides nothing. A release that is after `now` (clock skew) is young. A release with no name is hidden when it is young: no pattern can match it.
expect {
	hides = |published_at, min_age, exclude, name| Age.hides({ now, min_age, published_at, exclude, name })
	young = now - day
	rows = [
		("young, no pattern", hides(young, 2 * day, [], Ok("acme/lib")), Bool.True),
		("young, the pattern matches", hides(young, 2 * day, ["acme/lib"], Ok("acme/lib")), Bool.False),
		("young, an owner pattern matches", hides(young, 2 * day, ["acme/*"], Ok("acme/lib")), Bool.False),
		("young, the pattern is in another case", hides(young, 2 * day, ["ACME/LIB"], Ok("acme/lib")), Bool.False),
		("young, another repo of the owner", hides(young, 2 * day, ["acme/other"], Ok("acme/lib")), Bool.True),
		("young, another owner", hides(young, 2 * day, ["other/*"], Ok("acme/lib")), Bool.True),
		("young, the second pattern matches", hides(young, 2 * day, ["other/*", "acme/*"], Ok("acme/lib")), Bool.False),
		("old, no pattern", hides(now - 3 * day, 2 * day, [], Ok("acme/lib")), Bool.False),
		("old, a pattern", hides(now - 3 * day, 2 * day, ["acme/*"], Ok("acme/lib")), Bool.False),
		("exactly min_age old is visible", hides(now - 2 * day, 2 * day, [], Ok("acme/lib")), Bool.False),
		("one second younger is hidden", hides(now - 2 * day + 1, 2 * day, [], Ok("acme/lib")), Bool.True),
		("one second younger, a pattern", hides(now - 2 * day + 1, 2 * day, ["acme/lib"], Ok("acme/lib")), Bool.False),
		("min_age 0 hides nothing", hides(now, 0, [], Ok("acme/lib")), Bool.False),
		("min_age 0 and a release of now", hides(now, 0, ["acme/lib"], Ok("acme/lib")), Bool.False),
		("published after now (clock skew), min_age > 0", hides(now + day, 2 * day, [], Ok("acme/lib")), Bool.True),
		("published after now, a pattern", hides(now + day, 2 * day, ["acme/*"], Ok("acme/lib")), Bool.False),
		("published after now, min_age 0: nothing is hidden", hides(now + day, 0, [], Ok("acme/lib")), Bool.False),
		("no name, young", hides(young, 2 * day, [], Err(NoName)), Bool.True),
		("no name, young, a wildcard", hides(young, 2 * day, ["acme/*"], Err(NoName)), Bool.True),
		("no name, old", hides(now - 3 * day, 2 * day, ["acme/*"], Err(NoName)), Bool.False),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-C16: the note. `Ok(text)` only when the release is younger than `min_age` and a pattern matches. The text is
# `<id> <version> is <n>d old (min-release-age <m>d), not hidden by min-release-age-exclude: <pattern>`. `<n>` and `<m>` are whole days (the floor).
# An empty `version` (a compiler) leaves out the version and its space. The pattern is the first match, as written.
expect {
	note = |id, version, age, min_age, exclude, name| Age.note({ id, version, now, min_age, published_at: now - age, exclude, name })
	hours = |n| n * 3600
	rows = [
		("3 hours old: 0d", note("acme/lib", "2.3.0", hours(3), 2 * day, ["acme/*"], Ok("acme/lib")), Ok("acme/lib 2.3.0 is 0d old (min-release-age 2d), not hidden by min-release-age-exclude: acme/*")),
		("36 hours old: 1d", note("acme/lib", "2.3.0", hours(36), 2 * day, ["acme/*"], Ok("acme/lib")), Ok("acme/lib 2.3.0 is 1d old (min-release-age 2d), not hidden by min-release-age-exclude: acme/*")),
		("1 day old, the alias as id", note("json", "2.3.0", day, 2 * day, ["acme/json"], Ok("acme/json")), Ok("json 2.3.0 is 1d old (min-release-age 2d), not hidden by min-release-age-exclude: acme/json")),
		("the first matching pattern", note("acme/lib", "1.0.0", day, 2 * day, ["other/*", "Acme/*", "acme/lib"], Ok("acme/lib")), Ok("acme/lib 1.0.0 is 1d old (min-release-age 2d), not hidden by min-release-age-exclude: Acme/*")),
		("min_age of 5 days", note("acme/lib", "1.0.0", 4 * day, 5 * day, ["acme/*"], Ok("acme/lib")), Ok("acme/lib 1.0.0 is 4d old (min-release-age 5d), not hidden by min-release-age-exclude: acme/*")),
		("an empty version: one space", note("nightly-2026-10-09-258ab27", "", hours(3), 2 * day, ["roc-lang/*"], Ok("roc-lang/nightlies")), Ok("nightly-2026-10-09-258ab27 is 0d old (min-release-age 2d), not hidden by min-release-age-exclude: roc-lang/*")),
		("an empty version, 1 day", note("nightly-2026-10-13-91fa0c2", "", day, 2 * day, ["roc-lang/nightlies"], Ok("roc-lang/nightlies")), Ok("nightly-2026-10-13-91fa0c2 is 1d old (min-release-age 2d), not hidden by min-release-age-exclude: roc-lang/nightlies")),
		("old enough: no note", note("acme/lib", "2.3.0", 3 * day, 2 * day, ["acme/*"], Ok("acme/lib")), Err(None)),
		("exactly min_age old: no note", note("acme/lib", "2.3.0", 2 * day, 2 * day, ["acme/*"], Ok("acme/lib")), Err(None)),
		("young and no pattern: no note", note("acme/lib", "2.3.0", day, 2 * day, [], Ok("acme/lib")), Err(None)),
		("young and no match: no note", note("acme/lib", "2.3.0", day, 2 * day, ["other/*"], Ok("acme/lib")), Err(None)),
		("min_age 0: no note", note("acme/lib", "2.3.0", 0, 0, ["acme/*"], Ok("acme/lib")), Err(None)),
		("no name: no note", note("acme/lib", "2.3.0", day, 2 * day, ["acme/*"], Err(NoName)), Err(None)),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-C15 R-DT4 (slice 081, used by slice 082): the time that the solver sees. The solver (`packages/resolve`, rule 4) has its own age test and stays unchanged,
# so a release that a pattern matches is given the time 0 and looks old. A release that is after the snapshot keeps its real time, so the snapshot still hides it.
# A release exactly at the snapshot is not after it. No match and `NoName` keep the real time.
expect {
	seen = |published_at, snapshot, exclude, name| Age.seen({ published_at, snapshot, exclude, name })
	t = now - day
	rows = [
		("a match and no snapshot: 0", seen(t, Err(None), ["acme/*"], Ok("acme/lib")), 0),
		("a match and a snapshot after the release: 0", seen(t, Ok(now), ["acme/lib"], Ok("acme/lib")), 0),
		("a match and the release after the snapshot: the real time", seen(t, Ok(t - 1), ["acme/*"], Ok("acme/lib")), t),
		("a match and the release exactly at the snapshot: 0", seen(t, Ok(t), ["acme/*"], Ok("acme/lib")), 0),
		("no match: the real time", seen(t, Err(None), ["other/*"], Ok("acme/lib")), t),
		("no match and a snapshot: the real time", seen(t, Ok(now), ["other/*"], Ok("acme/lib")), t),
		("an empty list: the real time", seen(t, Err(None), [], Ok("acme/lib")), t),
		("no name: the real time", seen(t, Err(None), ["acme/*"], Err(NoName)), t),
		("the pattern in another case", seen(t, Err(None), ["ACME/LIB"], Ok("acme/lib")), 0),
		("an old release that matches: 0 too", seen(1000, Err(None), ["acme/lib"], Ok("acme/lib")), 0),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
