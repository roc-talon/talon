import records.Index as WireIndex
import lib.FullName
import lib.Index
import lib.Selector

FullnameTest :: [].{}

# Slice 212 (docs/slices/212-full-names.md). Pure: which GitHub candidates a full name ingests and in which order (R-AD35 steps 1 and 3), the warning of a skipped 409 or 422 (step 3), the failures of the stop cases (steps 2 and 4, R-AD36).

h1 = "F2uojbw8Z1W8LEjqfqePSQ2ednxYYBsCFB4fX6BAkZ1n"

h2 = "9h4nsRG1qGiGW9gC8Newrxf2RCkXdBokefenYAGQU442"

h3 = "22gWCNuGan7puGi2skkrFoo97hJ81kL3zX57fPbxqCAX"

h4 = "DkSWmeYfEsnJEVMZnXzfLpjkphazX5m8crUoTBRSSsZz"

# One release of the GitHub answer (R-DI3 to R-DI5): a candidate with one package asset.
release : { tag : Str, hash : Str, published : Str } -> Str
release = |r| "{\"tag_name\":\"${r.tag}\",\"draft\":false,\"prerelease\":false,\"published_at\":\"${r.published}\",\"assets\":[{\"name\":\"${r.hash}.tar.zst\",\"size\":1000,\"browser_download_url\":\"https://github.com/acme/lib/releases/download/${r.tag}/${r.hash}.tar.zst\"}]}"

candidates : List({ tag : Str, hash : Str, published : Str }) -> List(Index.Candidate)
candidates = |rows| match Index.candidates({ owner: "acme", repo: "lib", pages: ["[${Str.join_with(rows.map(release), ",")}]"], known: [] }) {
	Ok(found) => found.list
	Err(_) => []
}

# The order of the GitHub page: 1.0.0 (June), 2.0.0 (August), 1.5.0 (July), 1.6.0 (July, the same time as 1.5.0 and after it on the page).
page : List(Index.Candidate)
page = candidates([
	{ tag: "1.0.0", hash: h1, published: "2026-06-01T12:00:00Z" },
	{ tag: "2.0.0", hash: h2, published: "2026-08-01T12:00:00Z" },
	{ tag: "1.5.0", hash: h3, published: "2026-07-01T12:00:00Z" },
	{ tag: "1.6.0", hash: h4, published: "2026-07-01T12:00:00Z" },
])

versions = |list| list.map(|c| c.ident.version)

chosen = |selector| versions(FullName.select({ list: page, selector }))

# R-AD35 step 3: newest first by `published_at` (the release time, R-DI10), not by version and not by the order of the page. 1.5.0 and 1.6.0 have one time: they keep the order of the page.
expect chosen(Err(None)) == ["2.0.0", "1.5.0", "1.6.0", "1.0.0"]

# R-AD35 step 1, R-SL5: `latest` is the same as no selector.
expect chosen(Ok(Latest)) == ["2.0.0", "1.5.0", "1.6.0", "1.0.0"]

# R-AD35 step 1 (the selector of the command), R-SL3: an exact version keeps that release only.
expect chosen(Ok(Exact("1.5.0"))) == ["1.5.0"]

# R-AD35 step 1, R-SL4: a range keeps the releases that it admits, newest first by time.
expect chosen(Ok(Range("^1"))) == ["1.5.0", "1.6.0", "1.0.0"]

# R-AD35 step 2: the selector keeps nothing: the list is empty (the caller stops with `no_candidate`).
expect chosen(Ok(Exact("9.9.9"))) == []

# R-AD35 step 2: no candidate at all.
expect FullName.select({ list: [], selector: Err(None) }) == []

# R-AD35 step 3: a 409 or a 422 skips the release, with a warning that names the release and the error type.
conflict = "{\"type\":\"/errors/label-conflict\",\"title\":\"Conflict\",\"status\":409,\"detail\":\"x\"}"

unprocessable = "{\"type\":\"/errors/not-a-candidate\",\"title\":\"Unprocessable\",\"status\":422,\"detail\":\"x\"}"

expect FullName.skip_warning({ name: "acme/lib", tag: "v1.2.0", status: 409, body: conflict }) == Ok("warning: acme/lib v1.2.0: skipped, the registry answered 409 (/errors/label-conflict).")

expect FullName.skip_warning({ name: "acme/lib", tag: "1.3.0", status: 422, body: unprocessable }) == Ok("warning: acme/lib 1.3.0: skipped, the registry answered 422 (/errors/not-a-candidate).")

# A 409 with no problem details (a proxy page): still skipped, no type in the text.
expect FullName.skip_warning({ name: "acme/lib", tag: "1.3.0", status: 409, body: "<html>" }) == Ok("warning: acme/lib 1.3.0: skipped, the registry answered 409.")

# Any other status is not a skip: 200, 201 (indexed), 429 (exit 15), 500, 404.
expect [200, 201, 429, 500, 404].map(|status| FullName.skip_warning({ name: "acme/lib", tag: "1.0.0", status, body: conflict })) == [Err(NotSkipped), Err(NotSkipped), Err(NotSkipped), Err(NotSkipped), Err(NotSkipped)]

# R-AD35 step 2, R-T10, Design Q430: no candidate and no selector is exit code 2 (kind `usage`). The message says what a candidate is (R-DI3, R-DI4). With a selector each command has its own text (slice 206b).
expect FullName.no_candidate({ name: "acme/lib" }).kind.code() == 2

expect FullName.no_candidate({ name: "acme/lib" }).message == "acme/lib has no release that Talon can use. A release needs one <hash>.tar.zst asset and must not be a draft or a prerelease."

# R-AD35 step 1, Design Q397, R-SL3 to R-SL11: the way of each selector form, decided before any request.
way = |text, git| match Selector.parse(text, git) {
	Ok(parsed) => FullName.way(Ok(parsed))
	Err(_) => FullName.way(Err(None))
}

expect FullName.way(Err(None)) == Registry

expect [way("1.4.0", Bool.False), way("^2", Bool.False), way("2", Bool.False), way("0.25", Bool.False), way("latest", Bool.False)] == [Registry, Registry, Registry, Registry, Registry]

# A nightly tag and a relative step are for a compiler only.
expect [way("nightly-2026-10-09-258ab27", Bool.False), way("-1", Bool.False), way("+2", Bool.False)] == [Compiler, Compiler, Compiler]

# `--git` and a sha that is not a version, a range or a series: a source build.
expect [way("main", Bool.True), way("latest", Bool.True), way("dd03c09e", Bool.False)] == [Source, Source, Source]

# A sha of digits only reads as a series first (R-SL9 rule 1): the registry path.
expect way("1234567", Bool.False) == Registry

expect FullName.compiler_only({ name: "acme/lib", text: "-1" }).kind.code() == 2

expect FullName.compiler_only({ name: "acme/lib", text: "-1" }).message == "acme/lib@-1: a nightly tag and a relative step name a compiler release. acme/lib is not a compiler."

# R-AD35 step 3, Design Q398: an ingest with a 5xx, a 3xx, a 202 or no answer is skipped with a warning that names the release and the status or `no answer`.
expect FullName.unindexed_warning({ name: "acme/lib", tag: "1.3.0", what: "502" }) == "warning: acme/lib 1.3.0: skipped, the registry did not index this release (502)."

expect FullName.unindexed_warning({ name: "acme/lib", tag: "v2", what: "no answer" }) == "warning: acme/lib v2: skipped, the registry did not index this release (no answer)."

# R-AD35 step 4, Design Q399, R-AP65: R-AP1 is read again only after a 200 or 201.
expect FullName.after_ingests({ indexed: 1, skipped: 0, other: 0 }) == Ask

expect FullName.after_ingests({ indexed: 1, skipped: 2, other: 3 }) == Ask

# Only 409 and 422 skips: no candidate (exit 2).
expect FullName.after_ingests({ indexed: 0, skipped: 3, other: 0 }) == NoCandidate

# One or more other answers and no 200 or 201: not indexed now (exit 15), also with 409 skips.
expect FullName.after_ingests({ indexed: 0, skipped: 0, other: 1 }) == NotIndexed

expect FullName.after_ingests({ indexed: 0, skipped: 2, other: 1 }) == NotIndexed

expect FullName.not_indexed({ name: "acme/lib" }).kind.code() == 15

expect FullName.not_indexed({ name: "acme/lib" }).message == "the registry did not index acme/lib now. Run the command again in a moment."

# R-AD36: `--snapshot log:N` is exit code 2, and the message says that the name has no release in the log at size N.
expect FullName.snapshot_stop({ name: "acme/lib", size: 40 }).kind.code() == 2

expect FullName.snapshot_stop({ name: "acme/lib", size: 40 }).message == "acme/lib has no release in the log at size 40. A snapshot sends no ingest."

# R-AD35 step 4: R-AP1 is still 404 after the ingests: exit code 15, and the message says that the registry indexes the repository and to run the command again.
expect FullName.still_missing({ name: "acme/lib" }).kind.code() == 15

expect FullName.still_missing({ name: "acme/lib" }).message == "the registry has no release of acme/lib yet. The registry is indexing the repository: run the command again in a moment."

# Slice 206f (R-AD35 step 5, Design Q545, Q555): `FullName.closure_item`, the one item of the closure query of `add`. Two groups: group A has 1.2.3 and 1.3.0, group B has 2.0.0 (the newest, but withdrawn) and 2.1.0.
two_groups = "{\"releases\":[{\"log_index\":1,\"hash\":\"5UVYbRk4zTJP7MLG5AAaTwK2TmX3U1bdndvNzddMyTaV\",\"group\":\"github.com/acme/k/releases/download/{v}/\",\"series\":\"1\",\"version\":\"1.2.3\",\"url\":\"https://github.com/acme/k/releases/download/1.2.3/h.tar.zst\",\"tag\":\"1.2.3\",\"roc_version\":null,\"repo\":\"acme/k\",\"published_at\":1000,\"yanked\":false,\"yank_reason\":null,\"withdrawn\":null,\"provenance\":[\"ingest\"]},{\"log_index\":2,\"hash\":\"5UVYbRk4zTJP7MLG5AAaTwK2TmX3U1bdndvNzddMyTaV\",\"group\":\"example.org/k/{v}/\",\"series\":\"2\",\"version\":\"2.0.0\",\"url\":\"https://github.com/acme/k/releases/download/2.0.0/h.tar.zst\",\"tag\":\"2.0.0\",\"roc_version\":null,\"repo\":\"acme/k\",\"published_at\":3000,\"yanked\":false,\"yank_reason\":null,\"withdrawn\":\"prereleased\",\"provenance\":[\"ingest\"]},{\"log_index\":3,\"hash\":\"5UVYbRk4zTJP7MLG5AAaTwK2TmX3U1bdndvNzddMyTaV\",\"group\":\"example.org/k/{v}/\",\"series\":\"2\",\"version\":\"2.1.0\",\"url\":\"https://github.com/acme/k/releases/download/2.1.0/h.tar.zst\",\"tag\":\"2.1.0\",\"roc_version\":null,\"repo\":\"acme/k\",\"published_at\":2000,\"yanked\":false,\"yank_reason\":null,\"withdrawn\":null,\"provenance\":[\"ingest\"]},{\"log_index\":4,\"hash\":\"5UVYbRk4zTJP7MLG5AAaTwK2TmX3U1bdndvNzddMyTaV\",\"group\":\"github.com/acme/k/releases/download/{v}/\",\"series\":\"1\",\"version\":\"1.3.0\",\"url\":\"https://github.com/acme/k/releases/download/1.3.0/h.tar.zst\",\"tag\":\"1.3.0\",\"roc_version\":null,\"repo\":\"acme/k\",\"published_at\":1500,\"yanked\":false,\"yank_reason\":null,\"withdrawn\":null,\"provenance\":[\"ingest\"]}],\"checked\":null,\"repos\":[]}"

item = |body, text, range| match WireIndex.decode_releases(body) {
	Ok(releases) => {
		selector = match Selector.parse(text, Bool.False) {
			Ok(parsed) => Ok(parsed)
			Err(_) => Err(None)
		}
		FullName.closure_item({ releases, selector, text, range })
	}
	Err(_) => Err(NoMatch)
}

# No selector: the group of the newest release that is not withdrawn (2.1.0 of B, not the withdrawn 2.0.0), no `range`.
expect item(two_groups, "", "") == Ok({ group: "example.org/k/{v}/", series: Err(None), range: Err(None) })

# A version selector 1.2.3: the group A, `range` is the range of the new entry (Q555: `=1.2.3`).
expect item(two_groups, "1.2.3", "=1.2.3") == Ok({ group: "github.com/acme/k/releases/download/{v}/", series: Err(None), range: Ok("=1.2.3") })

# A series selector `1` keeps group A only: `range` `^1`, never `series` (Q555).
expect item(two_groups, "1", "^1") == Ok({ group: "github.com/acme/k/releases/download/{v}/", series: Err(None), range: Ok("^1") })

# A selector that keeps nothing.
expect item(two_groups, "9.9.9", "=9.9.9") == Err(NoMatch)
