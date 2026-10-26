import lib.Clock
import lib.Fail
import lib.Github
import lib.Roots

GithubTest :: [].{}

# R-DI2 R-EV19 R-EV20 R-DI8 R-DI9: the URLs. The list request is `<api>/repos/<owner>/<repo>/releases?per_page=100`, with the API base
# of the test hook when it is set. The hint is `<raw>/<owner>/<repo>/<tag>/.roc-version`. The cache pages of a repository are in
# `talon/index/github/<owner>/<repo>/`, a body `<n>.json` and a meta `<n>.meta` for each page (the form of the cache is a proposal).
expect {
	roots = Roots.{ cache: "/c/roc", pkgs: "/c/roc/packages", build: "/c/roc", config: "/c/cfg/talon", data: "/c/data/talon" }
	dir = Github.index_dir({ roots, owner: "acme", repo: "json" }) ?? ""
	urls = (
		Github.list_url({ api: "https://api.github.com", owner: "acme", repo: "json" }),
		Github.list_url({ api: "http://127.0.0.1:41234/api", owner: "o", repo: "r" }),
		Github.hint_url({ raw: "https://raw.githubusercontent.com", owner: "acme", repo: "json", tag: "2.1.0" }),
		Github.hint_url({ raw: "http://127.0.0.1:41234/raw", owner: "o", repo: "r", tag: "v1.0.0-rc1" }),
	)
	files = (Github.page_files({ dir, n: 1 }), Github.page_files({ dir, n: 12 }))
	want_urls = (
		"https://api.github.com/repos/acme/json/releases?per_page=100",
		"http://127.0.0.1:41234/api/repos/o/r/releases?per_page=100",
		"https://raw.githubusercontent.com/acme/json/2.1.0/.roc-version",
		"http://127.0.0.1:41234/raw/o/r/v1.0.0-rc1/.roc-version",
	)
	want_files = (
		{ body: "/c/roc/talon/index/github/acme/json/1.json", meta: "/c/roc/talon/index/github/acme/json/1.meta" },
		{ body: "/c/roc/talon/index/github/acme/json/12.json", meta: "/c/roc/talon/index/github/acme/json/12.meta" },
	)
	dbg urls
	dbg files
	dir == "/c/roc/talon/index/github/acme/json" and urls == want_urls and files == want_files
}

# R-DI2: the meta file of a cache page holds the ETag and the link to the next page, one line each. The reverse reads them back and
# ignores any other line. The `Link` header names the next page with `rel="next"` (the header name in any case, the links split by commas).
expect {
	metas = [
		("both", { etag: Ok("\"abc\""), next: Ok("https://api.github.com/repos/a/b/releases?per_page=100&page=2") }, "etag \"abc\"\nnext https://api.github.com/repos/a/b/releases?per_page=100&page=2\n"),
		("etag only", { etag: Ok("W/\"x y\""), next: Err(None) }, "etag W/\"x y\"\n"),
		("next only", { etag: Err(None), next: Ok("http://127.0.0.1:1/p?page=3") }, "next http://127.0.0.1:1/p?page=3\n"),
		("nothing", { etag: Err(None), next: Err(None) }, ""),
	]
	bad_text = metas.keep_if(|(_, facts, text)| Github.meta_text(facts) != text).map(|(label, facts, text)| (label, text, Github.meta_text(facts)))
	bad_back = metas.keep_if(|(_, facts, text)| Github.parse_meta(text) != facts).map(|(label, facts, text)| (label, facts, Github.parse_meta(text)))
	ignored = Github.parse_meta("junk\netag \"e\"\n\nnext http://x/y\nother 1\n") == { etag: Ok("\"e\""), next: Ok("http://x/y") }

	u2 = "https://api.github.com/repositories/1/releases?per_page=100&page=2"
	u5 = "https://api.github.com/repositories/1/releases?per_page=100&page=5"
	links = [
		("next and last", [("Link", "<${u2}>; rel=\"next\", <${u5}>; rel=\"last\"")], Ok(u2)),
		("last, then next", [("Link", "<${u5}>; rel=\"last\", <${u2}>; rel=\"next\"")], Ok(u2)),
		("the name in lower case", [("content-type", "x"), ("link", "<${u2}>; rel=\"next\"")], Ok(u2)),
		("the name in any case", [("LINK", "<${u2}>; rel=\"next\"")], Ok(u2)),
		("the last page", [("Link", "<${u2}>; rel=\"prev\", <${u2}>; rel=\"first\"")], Err(None)),
		("no Link header", [("ETag", "\"x\"")], Err(None)),
		("no headers", [], Err(None)),
	]
	bad_links = links.keep_if(|(_, headers, want)| Github.next_link(headers) != want).map(|(label, headers, want)| (label, want, Github.next_link(headers)))
	dbg bad_text
	dbg bad_back
	dbg bad_links
	bad_text == [] and bad_back == [] and ignored and bad_links == []
}

# R-DI2 R-DI12: what to do for a page. A page younger than 60 s is used with no request. An older page with an ETag is asked again with
# `If-None-Match`. Offline there is no request: a cached page is used, whatever its age. A time in the future is age 0.
expect {
	now = 1000
	etag = Ok("\"e\"")
	rows = [
		("age 1 s", { cached: Ok({ etag, mtime: 999 }), now, offline: Bool.False }, Use),
		("age 0", { cached: Ok({ etag, mtime: 1000 }), now, offline: Bool.False }, Use),
		("age 59 s", { cached: Ok({ etag, mtime: 941 }), now, offline: Bool.False }, Use),
		("age 60 s", { cached: Ok({ etag, mtime: 940 }), now, offline: Bool.False }, Revalidate("\"e\"")),
		("very old, with an ETag", { cached: Ok({ etag, mtime: 0 }), now, offline: Bool.False }, Revalidate("\"e\"")),
		("old, no ETag", { cached: Ok({ etag: Err(None), mtime: 0 }), now, offline: Bool.False }, Fetch),
		("young, no ETag", { cached: Ok({ etag: Err(None), mtime: 990 }), now, offline: Bool.False }, Use),
		("in the future", { cached: Ok({ etag, mtime: 2000 }), now, offline: Bool.False }, Use),
		("no page", { cached: Err(Missing), now, offline: Bool.False }, Fetch),
		("offline, old page", { cached: Ok({ etag, mtime: 0 }), now, offline: Bool.True }, Use),
		("offline, young page", { cached: Ok({ etag, mtime: 999 }), now, offline: Bool.True }, Use),
		("offline, no ETag", { cached: Ok({ etag: Err(None), mtime: 0 }), now, offline: Bool.True }, Use),
		("offline, no page", { cached: Err(Missing), now, offline: Bool.True }, Missing),
	]
	bad = rows.keep_if(|(_, facts, want)| Github.plan(facts) != want).map(|(label, facts, want)| (label, want, Github.plan(facts)))
	dbg bad
	bad == []
}

# R-DI13 R-DI12 R-RG3: the answers that stop a command. A rate limit is status 403 or 429 with `x-ratelimit-remaining: 0` or with
# `retry-after` (the names in any case). The reset time is `x-ratelimit-reset`, or `now + retry-after`. A plain 403 is no rate limit.
# The message gives the reset time and the three token sources. A 404 of the release list is a usage failure (exit 2) that names the repository (Q2). A request with no answer names `--offline`. The time texts are
# `Clock.format_utc`, the reverse of `Clock.parse_utc`.
expect {
	now = 1000
	reset = 1792152000
	rows = [
		("primary limit", { status: 403, headers: [("x-ratelimit-remaining", "0"), ("x-ratelimit-reset", "1792152000")], now }, Ok({ reset: Ok(reset) })),
		("names in any case", { status: 403, headers: [("X-RateLimit-Remaining", "0"), ("X-RateLimit-Reset", "1792152000")], now }, Ok({ reset: Ok(reset) })),
		("status 429", { status: 429, headers: [("x-ratelimit-remaining", "0"), ("x-ratelimit-reset", "1792152000")], now }, Ok({ reset: Ok(reset) })),
		("secondary limit", { status: 429, headers: [("retry-after", "30")], now }, Ok({ reset: Ok(1030) })),
		("403 with retry-after", { status: 403, headers: [("Retry-After", "60")], now }, Ok({ reset: Ok(1060) })),
		("no reset time", { status: 403, headers: [("x-ratelimit-remaining", "0")], now }, Ok({ reset: Err(Unknown) })),
		("a reset that is not a number", { status: 403, headers: [("x-ratelimit-remaining", "0"), ("x-ratelimit-reset", "soon")], now }, Ok({ reset: Err(Unknown) })),
		("remaining is not 0", { status: 403, headers: [("x-ratelimit-remaining", "42")], now }, Err(NotLimited)),
		("a plain 403", { status: 403, headers: [], now }, Err(NotLimited)),
		("status 200 with remaining 0", { status: 200, headers: [("x-ratelimit-remaining", "0")], now }, Err(NotLimited)),
		("status 404", { status: 404, headers: [], now }, Err(NotLimited)),
		("status 304", { status: 304, headers: [("x-ratelimit-remaining", "0")], now }, Err(NotLimited)),
	]
	bad_limit = rows.keep_if(|(_, facts, want)| Github.rate_limit(facts) != want).map(|(label, facts, want)| (label, want, Github.rate_limit(facts)))
	dbg bad_limit

	view = |fail| (fail.kind.code(), fail.message)
	tokens = "Set GITHUB_TOKEN or GH_TOKEN, or log in with gh (gh auth login)."
	failures = (
		view(Github.rate_limit_failure({ reset: Ok(reset) })),
		view(Github.rate_limit_failure({ reset: Err(Unknown) })),
		view(Github.network_failure({ url: "https://api.github.com/repos/a/b/releases?per_page=100", why: Timeout })),
		view(Github.network_failure({ url: "http://127.0.0.1:1/api/repos/a/b/releases?per_page=100", why: Failed("network error") })),
		view(Github.status_failure({ url: "https://api.github.com/repos/a/b/releases?per_page=100", status: 500 })),
		view(Github.missing_repo({ owner: "acme", repo: "nope" })),
	)
	want_failures = (
		(15, "GitHub API rate limit reached. It resets at 2026-10-16T12:00:00Z. ${tokens}"),
		(15, "GitHub API rate limit reached. ${tokens}"),
		(15, "cannot reach https://api.github.com/repos/a/b/releases?per_page=100: no answer in 20 s. Use --offline to work with the cached index."),
		(15, "cannot reach http://127.0.0.1:1/api/repos/a/b/releases?per_page=100: network error. Use --offline to work with the cached index."),
		(15, "GitHub answered 500 for https://api.github.com/repos/a/b/releases?per_page=100"),
		(2, "no GitHub repository acme/nope (a private repository needs a token)"),
	)
	dbg failures

	times = [
		(0, "1970-01-01T00:00:00Z"),
		(reset, "2026-10-16T12:00:00Z"),
		(1709251199, "2024-02-29T23:59:59Z"),
		(951782400, "2000-02-29T00:00:00Z"),
		(4102444800, "2100-01-01T00:00:00Z"),
	]
	bad_times = times.keep_if(|(secs, text)| Clock.format_utc(secs) != text or Clock.parse_utc(text) != Ok(secs)).map(|(secs, text)| (secs, text, Clock.format_utc(secs)))
	dbg bad_times
	offline = Github.offline_line(reset)
	bad_limit == [] and failures == want_failures and bad_times == [] and offline == "index: cached at 2026-10-16T12:00:00Z"
}

# R-DI8: the `.roc-version` hint. The first line that is not empty, with white space cut off. A 404 and an empty file are no hint.
# Any other status is a failure of the request.
expect {
	rows = [
		("a nightly id", { status: 200, body: "nightly-2026-10-09-258ab27\n" }, Ok("nightly-2026-10-09-258ab27")),
		("blank lines and white space first", { status: 200, body: "\n\n  nightly-x  \nignored\n" }, Ok("nightly-x")),
		("empty file", { status: 200, body: "" }, Err(NoHint)),
		("only white space", { status: 200, body: "  \n\t\n" }, Err(NoHint)),
		("404: no hint", { status: 404, body: "404: Not Found" }, Err(NoHint)),
		("500", { status: 500, body: "x" }, Err(Failed(500))),
		("403", { status: 403, body: "x" }, Err(Failed(403))),
	]
	bad = rows.keep_if(|(_, facts, want)| Github.hint(facts) != want).map(|(label, facts, want)| (label, want, Github.hint(facts)))
	dbg bad
	bad == []
}

# R-DI8 (slice 068): the cache file of a hint is `<index>/github/<owner>/<repo>/<tag>.roc-version`, next to the pages of the release list. The
# repository and the tag of a header entry come from its release URL: only the form `https://github.com/<owner>/<repo>/releases/download/<tag>/<asset>`
# has a hint. A tag with dots and a `v` is kept as it is. Another host, `http://`, a path, a URL with 2 tag segments or an empty part has none.
# Manager answer (2026-10-25): an owner, a repo or a tag that is empty, `.`, `..`, or has a `/`, a backslash or a NUL byte gives no path (`hint_file` is `Err(BadPart)`) and no ref: no cache path outside the repo dir.
expect {
	roots = Roots.{ cache: "/c/roc", pkgs: "/c/roc/packages", build: "/c/roc", config: "/c/cfg/talon", data: "/c/data/talon" }
	file = |owner, repo, tag| Github.hint_file({ roots, owner, repo, tag })
	files = [
		("the index dir", file("acme", "json", "2.1.0"), Ok("/c/roc/talon/index/github/acme/json/2.1.0.roc-version")),
		("a tag with v and a pre-release part", file("o", "r", "v1.0.0-rc1"), Ok("/c/roc/talon/index/github/o/r/v1.0.0-rc1.roc-version")),
		("dots inside a tag are safe", file("o", "r", "v1..2"), Ok("/c/roc/talon/index/github/o/r/v1..2.roc-version")),
		("a tag that is ..", file("acme", "json", ".."), Err(BadPart)),
		("a tag that is .", file("acme", "json", "."), Err(BadPart)),
		("a tag with /..", file("acme", "json", "a/../../x"), Err(BadPart)),
		("a tag with a /", file("acme", "json", "a/b"), Err(BadPart)),
		("a tag with a backslash", file("acme", "json", "a\\b"), Err(BadPart)),
		("a tag with a NUL byte", file("acme", "json", "a\u(0)b"), Err(BadPart)),
		("an empty tag", file("acme", "json", ""), Err(BadPart)),
		("an owner that is ..", file("..", "json", "2.1.0"), Err(BadPart)),
		("a repo that is ..", file("acme", "..", "2.1.0"), Err(BadPart)),
		("an owner with a /", file("a/b", "json", "2.1.0"), Err(BadPart)),
		("an empty repo", file("acme", "", "2.1.0"), Err(BadPart)),
	]
	bad_files = files.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad_files
	asset = "9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17.tar.zst"
	refs = [
		("a release URL", "https://github.com/acme/json/releases/download/2.1.0/${asset}", Ok({ owner: "acme", repo: "json", tag: "2.1.0" })),
		("a tag with v and a pre-release part", "https://github.com/o/r/releases/download/v1.0.0-rc1/${asset}", Ok({ owner: "o", repo: "r", tag: "v1.0.0-rc1" })),
		("another host", "https://example.com/acme/json/releases/download/2.1.0/${asset}", Err(NoRef)),
		("http", "http://github.com/acme/json/releases/download/2.1.0/${asset}", Err(NoRef)),
		("2 tag segments", "https://github.com/acme/json/releases/download/a/2.1.0/${asset}", Err(NoRef)),
		("no asset", "https://github.com/acme/json/releases/download/2.1.0", Err(NoRef)),
		("an empty tag", "https://github.com/acme/json/releases/download//${asset}", Err(NoRef)),
		("an empty owner", "https://github.com//json/releases/download/2.1.0/${asset}", Err(NoRef)),
		("not a download", "https://github.com/acme/json/archive/2.1.0/${asset}", Err(NoRef)),
		("a path", "./util/main.roc", Err(NoRef)),
		("empty", "", Err(NoRef)),
		("a tag that is ..", "https://github.com/acme/json/releases/download/../${asset}", Err(NoRef)),
		("an owner that is ..", "https://github.com/../json/releases/download/2.1.0/${asset}", Err(NoRef)),
		("a repo that is .", "https://github.com/acme/./releases/download/2.1.0/${asset}", Err(NoRef)),
		("a tag with a backslash", "https://github.com/acme/json/releases/download/a\\b/${asset}", Err(NoRef)),
		("a tag with a NUL byte", "https://github.com/acme/json/releases/download/a\u(0)b/${asset}", Err(NoRef)),
	]
	bad = refs.keep_if(|(_, url, want)| Github.hint_ref(url) != want).map(|(label, url, want)| (label, want, Github.hint_ref(url)))
	dbg bad
	bad_files == [] and bad == []
}

# R-DI8 (slice 068): what `hint!` writes for an answer. A 200 keeps the body as it came, also when it has no hint line (a tag is fixed, so the answer stays).
# A 404 keeps the empty text. Any other status is a failure of the request: nothing is kept, the next run asks again. `hint` reads the kept text back as a 200.
expect {
	rows = [
		("200 with an id", { status: 200, body: "nightly-2026-10-09-258ab27\n" }, Ok("nightly-2026-10-09-258ab27\n")),
		("200 with white space only", { status: 200, body: "  \n" }, Ok("  \n")),
		("200 empty", { status: 200, body: "" }, Ok("")),
		("404", { status: 404, body: "404: Not Found" }, Ok("")),
		("500", { status: 500, body: "x" }, Err(NotKept)),
		("403", { status: 403, body: "x" }, Err(NotKept)),
		("304", { status: 304, body: "" }, Err(NotKept)),
	]
	bad = rows.keep_if(|(_, facts, want)| Github.hint_keep(facts) != want).map(|(label, facts, want)| (label, want, Github.hint_keep(facts)))
	dbg bad
	back = [
		("an id comes back", Github.hint_keep({ status: 200, body: "nightly-x\n" }).map_ok(|text| Github.hint({ status: 200, body: text })), Ok(Ok("nightly-x"))),
		("the 404 file is no hint", Github.hint_keep({ status: 404, body: "gone" }).map_ok(|text| Github.hint({ status: 200, body: text })), Ok(Err(NoHint))),
	]
	bad_back = back.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad_back
	bad == [] and bad_back == []
}

# R-DI2 R-ID3 R-DI1 (slice 076): the cache dir of a repository, `<index>/github/<owner>/<repo>`, is made only from parts that are safe (`Ident.safe_part`). `owner` and `repo` come from a release URL in a header
# or from a typed name (`tln add ../..`), so a part that is empty, `.`, `..`, or has a `/`, a backslash or a NUL byte gives no path: `Err(BadPart)`. Without the guard, `releases!` writes `1.json` and `1.meta`
# in `talon/index/` (owner `..`), in `talon/index/github/` (repo `..`) or in `talon/` (both). The failure of `releases!` for it is a usage failure (exit 2, R-EC2 bad ref), and the text names `owner/repo`.
expect {
	roots = Roots.{ cache: "/c/roc", pkgs: "/c/roc/packages", build: "/c/roc", config: "/c/cfg/talon", data: "/c/data/talon" }
	dir = |owner, repo| Github.index_dir({ roots, owner, repo })
	rows = [
		("a repository", dir("acme", "json"), Ok("/c/roc/talon/index/github/acme/json")),
		("dots and hyphens inside", dir("a-b.c", "r_x..y"), Ok("/c/roc/talon/index/github/a-b.c/r_x..y")),
		("an owner that is ..", dir("..", "json"), Err(BadPart)),
		("an owner that is .", dir(".", "json"), Err(BadPart)),
		("a repo that is ..", dir("acme", ".."), Err(BadPart)),
		("a repo that is .", dir("acme", "."), Err(BadPart)),
		("both are ..", dir("..", ".."), Err(BadPart)),
		("an empty owner", dir("", "json"), Err(BadPart)),
		("an empty repo", dir("acme", ""), Err(BadPart)),
		("an owner with a /", dir("a/b", "json"), Err(BadPart)),
		("a repo with a /", dir("acme", "a/b"), Err(BadPart)),
		("an owner that climbs", dir("../x", "json"), Err(BadPart)),
		("a repo that climbs", dir("acme", "x/.."), Err(BadPart)),
		("an owner with a backslash", dir("a\\b", "json"), Err(BadPart)),
		("a repo with a backslash", dir("acme", "..\\x"), Err(BadPart)),
		("an owner with a NUL byte", dir("a\u(0)b", "json"), Err(BadPart)),
		("a repo with a NUL byte", dir("acme", "a\u(0)b"), Err(BadPart)),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	failure = Github.bad_repo({ owner: "..", repo: "x" })
	bad == [] and failure == Fail.new(Usage, "'../x' is not a GitHub repository name") and failure.kind.code() == 2
}
