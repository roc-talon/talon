import lib.Ident

IdentTest :: [].{}

# R-ID1 R-ID2 R-ID3 R-ID4 R-ID5: the identity of a release from its URL: name, version, series, group, label, content id.
# The name is `owner/repo` for a GitHub release URL. The group is the URL form plus the series, so 1.9.0 and 2.0.0 of one
# repo are two groups with one URL form. A path entry, or a URL with no version, 2 versions or 0.0.0, is foreign (R-H4).
expect {
	cli_hash = "CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA"
	uni_hash = "4W8SHzvwet9hH9qZewJ1J1CVQoH7YKA6zyijWFTB3y1w"
	view = |url| match Ident.of_url(url) {
		Ok(i) => Ok((i.name, i.version, i.series, i.group, i.label, i.hash))
		Err(e) => Err(e)
	}
	rows = [
		(
			"https://github.com/roc-lang/basic-cli/releases/download/0.25.0/${cli_hash}.tar.zst",
			Ok((Ok("roc-lang/basic-cli"), "0.25.0", "0.25", { form: "github.com/roc-lang/basic-cli/releases/download/{v}/", series: "0.25" }, Ok("roc-lang/basic-cli@0.25.0"), cli_hash)),
		),
		(
			"https://github.com/roc-lang/unicode/releases/download/4.2.0/${uni_hash}.tar.zst",
			Ok((Ok("roc-lang/unicode"), "4.2.0", "4", { form: "github.com/roc-lang/unicode/releases/download/{v}/", series: "4" }, Ok("roc-lang/unicode@4.2.0"), uni_hash)),
		),
		(
			"https://github.com/roc-lang/http/releases/download/1.9.0/Aaa.tar.zst",
			Ok((Ok("roc-lang/http"), "1.9.0", "1", { form: "github.com/roc-lang/http/releases/download/{v}/", series: "1" }, Ok("roc-lang/http@1.9.0"), "Aaa")),
		),
		(
			"https://github.com/roc-lang/http/releases/download/2.0.0/Bbb.tar.zst",
			Ok((Ok("roc-lang/http"), "2.0.0", "2", { form: "github.com/roc-lang/http/releases/download/{v}/", series: "2" }, Ok("roc-lang/http@2.0.0"), "Bbb")),
		),
		("../util/main.roc", Err(Foreign)),
		("https://example.com/pkg/Ccc.tar.zst", Err(Foreign)),
		("https://example.com/1.0.0/2.0.0/Ccc.tar.zst", Err(Foreign)),
		("https://example.com/pkg/0.0.0/Ccc.tar.zst", Err(Foreign)),
	]
	bad = rows.keep_if(|(url, want)| view(url) != want).map(|(url, want)| (url, want, view(url)))
	dbg bad
	# A URL on another host has a group, a version and a hash. Its name is question Q6, so the row has no name.
	other = match Ident.of_url("https://example.com/pkgs/json/2.1.0/Ddd.tar.zst") {
		Ok(i) => (i.version, i.series, i.group, i.hash) == ("2.1.0", "2", { form: "example.com/pkgs/json/{v}/", series: "2" }, "Ddd")
		Err(_) => Bool.False
	}
	bad == [] and other
}

# R-ID1: the series is the major, or `0.minor` below 1.0.
expect {
	rows = [
		("4.2.0", Ok("4")),
		("1.0.0", Ok("1")),
		("0.25.1", Ok("0.25")),
		("0.0.3", Ok("0.0")),
		("x", Err(BadVersion)),
		("1.2", Err(BadVersion)),
	]
	bad = rows.keep_if(|(v, want)| Ident.series_of(v) != want).map(|(v, want)| (v, want, Ident.series_of(v)))
	dbg bad
	bad == []
}

# R-ID3 R-H4 R-DI1 (slice 076): the one guard for a path part that comes from outside. A safe part is not empty, not `.` or `..`, and has no `/`, no backslash and no NUL
# byte. A dot inside a name is safe (`v1..2`, `a.b`, `.hidden`, `...`). A part with a `/` anywhere is not safe, also when it does not climb (`a/b`, `/a`, `a/`).
expect {
	rows = [
		("a name", "acme", Bool.True),
		("a hash", "9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17", Bool.True),
		("2 dots inside", "v1..2", Bool.True),
		("a dot inside", "a.b", Bool.True),
		("a hidden name", ".hidden", Bool.True),
		("3 dots", "...", Bool.True),
		("a hyphen first", "-x", Bool.True),
		("a space", "a b", Bool.True),
		("empty", "", Bool.False),
		("one dot", ".", Bool.False),
		("2 dots", "..", Bool.False),
		("a slash inside", "a/b", Bool.False),
		("a slash first", "/a", Bool.False),
		("a slash last", "a/", Bool.False),
		("a climb", "../x", Bool.False),
		("a climb last", "x/..", Bool.False),
		("a backslash inside", "a\\b", Bool.False),
		("a backslash only", "\\", Bool.False),
		("a climb with backslashes", "..\\x", Bool.False),
		("a NUL byte inside", "a\u(0)b", Bool.False),
		("a NUL byte only", "\u(0)", Bool.False),
	]
	bad = rows.keep_if(|(_, text, want)| Ident.safe_part(text) != want).map(|(label, text, want)| (label, text, want))
	dbg bad
	bad == []
}

# R-ID3 R-H4 R-ID5 R-DI1 (slice 076): the path parts of a release URL. The hash is the name of `packages/<hash>` (R-LY1): a hash that is not a safe part makes the URL foreign (R-H4: a URL that
# has no hash in the form of 4.1), so no command makes a path from it. `owner` and `repo` are the name `owner/repo` and the dir of the index (`talon/index/github/<owner>/<repo>`): an unsafe one gives
# no name (R-ID3, as the other hosts: `Err(NoName)`, so no index call), and the URL keeps its hash, version and group. A dot inside a part is safe.
expect {
	h = "9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17"
	gh = |owner, repo, hash| "https://github.com/${owner}/${repo}/releases/download/2.1.0/${hash}.tar.zst"
	view = |url| match Ident.of_url(url) {
		Ok(i) => Ok((i.name, i.label, i.hash, i.version))
		Err(e) => Err(e)
	}
	no_name = |hash| Ok((Err(NoName), Err(NoName), hash, "2.1.0"))
	rows = [
		("a safe URL", gh("acme", "json", h), Ok((Ok("acme/json"), Ok("acme/json@2.1.0"), h, "2.1.0"))),
		("dots inside owner, repo and hash", gh("a..b", "j.s", "x..y"), Ok((Ok("a..b/j.s"), Ok("a..b/j.s@2.1.0"), "x..y", "2.1.0"))),
		("an owner that is ..", gh("..", "json", h), no_name(h)),
		("an owner that is .", gh(".", "json", h), no_name(h)),
		("a repo that is ..", gh("acme", "..", h), no_name(h)),
		("a repo that is .", gh("acme", ".", h), no_name(h)),
		("owner and repo that are ..", gh("..", "..", h), no_name(h)),
		("an owner with a backslash", gh("a\\b", "json", h), no_name(h)),
		("a repo with a backslash", gh("acme", "a\\..\\b", h), no_name(h)),
		("an owner with a NUL byte", gh("a\u(0)b", "json", h), no_name(h)),
		("a hash that is ..", gh("acme", "json", ".."), Err(Foreign)),
		("a hash that is .", gh("acme", "json", "."), Err(Foreign)),
		("a hash with a backslash", gh("acme", "json", "a\\b"), Err(Foreign)),
		("a hash with a NUL byte", gh("acme", "json", "a\u(0)b"), Err(Foreign)),
		("a hash that is .. on another host", "https://example.com/pkgs/json/2.1.0/...tar.zst", Err(Foreign)),
	]
	bad = rows.keep_if(|(_, url, want)| view(url) != want).map(|(label, url, want)| (label, want, view(url)))
	dbg bad
	bad == []
}
