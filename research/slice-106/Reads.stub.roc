## The pure part of the read routes (Registry 4: R-AP1, R-AP2, R-AP13, R-AP14, R-AP18, R-AP24, R-AP29, R-AP32, R-AP41, R-AP43; slice 106). No effect, no platform import.
## The effects (the D1 session and its one call, the Cache API, the clock, the headers) are in `worker/ReadRoutes.roc`.
## The tests are in `worker/tests/unit/ReadsTest.roc` (W0) and `worker/tests/cases/reads/` (W2).
## The ETag, the conditional request and the cache rules are design facts: R-AP53 (answers), R-AP54 (ETag, 304, 200), R-AP55 (Cache API, `Talon-Bookmark`), R-AP56 (path and query).
## The texts of the `detail` of a problem are proposals, accepted at the review (TW24): `docs/slices/106-read-routes.md` section 6.
## Every body is built here as text, so that two answers of one state have the same bytes and the same ETag (R-AP24, R-AP49).
import records.Artifact
import records.Closure
import records.Release
import Problem

Reads :: [].{

	## R-AP14: at most this many releases in a page (first guess).
	page_limit : U64
	page_limit = 1000

	## R-AP1, R-AP2, R-AP13, R-AP14: the `Cache-Control` of a 200 answer and of a 304 answer. R-AP43 puts the answer in the Cache API for this time.
	cache_control : Str
	cache_control = "max-age=60"

	# ---- the ids of the request (R-IK2): bound as text by the platform (R-IK2 "Write"), so the type is I64 ----

	## The id of an artifact from its base58 hash: `Base58.decode`, exactly 32 bytes, then `Id.name_id(1, bytes)`. Anything else is `Err(BadHash)`.
	## R-AP56: a text that is no hash is 404 `not-found` with the `detail` of an unknown hash (`no_artifact`) and no D1 call. This function only tells that the text is no hash.
	artifact_id : Str -> Try(I64, [BadHash])
	artifact_id = |_hash| crash "todo"

	## The id of a group from its URL form: `Id.name_id(2, the UTF-8 bytes)`.
	form_id : Str -> I64
	form_id = |_form| crash "todo"

	## The id of a GitHub name from the two path segments (R-AP56): the ASCII letters of `<owner>/<repo>` are made lower case, then `Id.name_id(3, bytes)`.
	## So `Roc-Lang`, `Unicode` and `roc-lang`, `unicode` give one id. Only ASCII letters change.
	repo_id : Str, Str -> I64
	repo_id = |_owner, _repo| crash "todo"

	# ---- the query of GET /v1/releases (R-AP13, R-AP14) ----

	## The three query parameters as the request gives them (`Request.query`, percent-decoded).
	QueryInput : { group : Try(Str, [NotFound]), series : Try(Str, [NotFound]), after : Try(Str, [NotFound]) }

	## `ByGroup`: R-AP13, also with `after` (R-AP14 "`after` and `group` can go together"). `ByAfter`: R-AP14 alone.
	## `series` is checked with `Version.series_bounds`. `after` is decimal digits, no leading zero (only `0` itself), at most 2^63 - 1 (R-AP56).
	Query : [ByGroup({ group : Str, series : Try(Str, [None]), after : Try(U64, [None]) }), ByAfter(U64)]

	## The first rule that fails gives `BadRequest` (R-AP48 row 6, before any D1 call):
	## 1. no `group` and no `after`: `GET /v1/releases needs the query parameter group or after`
	## 2. `group` present and empty: `the query parameter group must not be empty`
	## 3. `after` present and not in the form of R-AP56 (empty, a sign, a point, a letter, a leading zero as in `007` and `00`, above 2^63 - 1):
	##    `the query parameter after must be a log index (decimal digits), got <text>`
	## 4. `series` present and `Version.series_bounds` gives `Err(BadSeries)`: `the query parameter series must be a series (M or 0.m), got <text>`
	## R-AP56: a `series` with no `group` and no `after` is rule 1 (400). With `after` and no `group` the `series` is ignored, also a bad one: `ByAfter`.
	parse_query : Reads.QueryInput -> Try(Reads.Query, Problem)
	parse_query = |_q| crash "todo"

	# ---- the ETag and the conditional request (R-AP24) ----

	## The ETag of a body: a strong ETag, the first 16 bytes of `Crypto.SHA256.hash(body)` as 32 lower-case hex digits, in double quotes.
	etag_of : List(U8) -> Str
	etag_of = |_body| crash "todo"

	## `If-None-Match` against the current ETag (RFC 9110 13.1.2, weak comparison): the value is `*`, or a comma separated list of entity tags.
	## A tag `W/"x"` matches `"x"`. White space around a tag is ignored. A text that is no tag never matches (so `abc` does not match `"abc"`).
	etag_matches : Str, Str -> Bool
	etag_matches = |_if_none_match, _etag| crash "todo"

	# ---- the cache decision and the session (R-AP43, R-AP41 row 5) ----

	## R-AP43: true when the request must not read the Cache API: the `Cache-Control` request header has the directive `no-cache`
	## (comma separated list, no case, white space around a directive ignored, the whole directive: `no-cachex` is not it), or the `Pragma`
	## request header has the directive `no-cache` (same list rule). R-AP55: no other directive counts (`max-age=0`, `no-store`, `private`), and no other header (`Expires`).
	bypass_cache : { cache_control : Try(Str, [NotFound]), pragma : Try(Str, [NotFound]) } -> Bool
	bypass_cache = |_h| crash "todo"

	## R-AP41 row 5: the value of the request header `Talon-Bookmark` gives `After(<the value with white space cut>)`. No header, or an empty value: `Any`.
	session_of : Try(Str, [NotFound]) -> [Any, After(Str)]
	session_of = |_bookmark| crash "todo"

	# ---- checked (R-AP29) and repos (R-AP32) ----

	## R-PU22 (first guesses): 1 hour for a repository with no App installation, 24 hours for one with the App.
	interval_ms : Bool -> U64
	interval_ms = |_app_installed| crash "todo"

	## R-AP29: stale when `checked_at` is `Err(None)` (never read since the first ingest), or `now_ms - checked_at` is more than 2 intervals.
	## Exactly 2 intervals is not stale. A `checked_at` after `now_ms` is not stale.
	stale : { checked_at : Try(U64, [None]), app_installed : Bool, now_ms : U64 } -> Bool
	stale = |_c| crash "todo"

	## The row of `repo_checks` joined with the name of the repo (`names.value`, kind 3).
	CheckRow : { name : Str, checked_at : Try(U64, [Missing]), app_installed : Bool }

	## An item of `checked` (R-AP29): `{name, checked_at, stale}`. It is the type of `records` (slice 104b).
	CheckedItem : Closure.Checked

	checked_of_row : Reads.CheckRow, U64 -> Reads.CheckedItem
	checked_of_row = |_row, _now_ms| crash "todo"

	## The row of `repos` joined with the names of the repo and of the successor (`names.value`, kind 3). `state` is the code 0, 1, 2.
	RepoRow : { name : Str, state : I64, successor : Try(Str, [Missing]), state_at : U64 }

	## An item of `repos` (R-AP32): `{name, state, successor, state_at}`. `state` is `active`, `missing` or `moved` on the wire. It is the type of `records` (slice 104b).
	RepoItem : Closure.Repo

	## A `state` that is not 0, 1 or 2 is `Err(BadRow)`.
	repo_item_of_row : Reads.RepoRow -> Try(Reads.RepoItem, [BadRow(Str)])
	repo_item_of_row = |_row| crash "todo"

	# ---- the rows of releases and artifacts ----

	## One release as a D1 row (the SQL of the route joins `names`): `hash` is `hex(names.value)` of the artifact (64 hex digits, SQLite gives upper case; a BLOB column
	## does not read into `List(U8)` on platform 0.0.2, slice file section 8 P1), `form` is `names.value`
	## of `releases.form`, `version` is `CAST(version AS TEXT)`, `repo` is `names.value` of `releases.repo` (kind 3), `yanked` is 0 or 1.
	ReleaseRow : {
		log_index : U64,
		hash : Str,
		form : Str,
		version : Str,
		version_text : Str,
		url : Str,
		tag : Try(Str, [Missing]),
		roc_version : Try(Str, [Missing]),
		repo : Try(Str, [Missing]),
		published_at : U64,
		yanked : Bool,
		withdrawn : Try(Str, [Missing]),
	}

	## The wire record of R-AP49. `hash`: the hex digits (upper or lower case) become 32 bytes, then `Base58.encode`; another length or a character that is not a hex digit is `BadRow`. `group`: `form`. `version` and `series`: `Version.read`, then
	## `Semver.to_str` and `Version.series_of`. `yank_reason`: always `Err(None)` before P3 (`yanks` is P3). The nullable columns are `Err(None)` when missing.
	## A hash with other than 32 bytes, or a version column that `Version.read` refuses, is `Err(BadRow)` with a text (the handler gives 500 `internal`, R-AP48).
	release_of_row : Reads.ReleaseRow -> Try(Release.Row, [BadRow(Str)])
	release_of_row = |_row| crash "todo"

	## One artifact as D1 rows. `kind` is the code 0, 1, 2. `exposed_json` is `artifacts.exposes`: a JSON array of text in the order of the header (R-RE1). `hash` and `platform_hash` are `hex(names.value)` as for `ReleaseRow`.
	ArtifactRow : { hash : Str, kind : I64, exposed_json : Str, platform_hash : Try(Str, [Missing]), roc_pin : Try(Str, [Missing]), size : U64 }

	## One row of `deps` with `hash` = `hex(names.value)` of `dep`, `form` = `names.value` of `deps.form`, `version` = `CAST(version AS TEXT)`.
	## `form` and `version` are NULL together (R-RE19). R-AP49: a dep with no `form` has `group` made from `url`: no scheme, no last segment (`<hash>.tar.zst`),
	## no `{v}`. Example: `https://example.com/pkg/lib/<hash>.tar.zst` gives `example.com/pkg/lib/`. Its `series` and `version` are `Err(None)`.
	DepRow : { alias : Str, hash : Str, form : Try(Str, [Missing]), version : Try(Str, [Missing]), version_text : Try(Str, [Missing]), url : Str }

	## The artifact record of R-AP49 from its rows. `target_names` are the `targets.name` of `artifact_targets`. `kind` code to `Code.Kind` (an unknown code is `BadRow`).
	## `deps` series and version: as `release_of_row`, `Err(None)` when `version` is missing. The sort of deps and targets is done by `Artifact.encode`.
	artifact_of_rows : { artifact : Reads.ArtifactRow, deps : List(Reads.DepRow), target_names : List(Str) } -> Try(Artifact.Row, [BadRow(Str)])
	artifact_of_rows = |_rows| crash "todo"

	# ---- the bodies (R-AP1, R-AP13, R-AP14, R-AP2) ----

	## R-AP1 and R-AP13 (R-AP53): `{"releases":[<Release.encode each>],"checked":<item or null>,"repos":[<items>]}`. No white space. The items of `repos` are sorted by `name`
	## (bytes). A `checked` item is `Closure.encode_checked`, a repo item is `Closure.encode_repo` (members in alphabetical order, `null` for none).
	releases_body : { releases : List(Release.Row), checked : Try(Reads.CheckedItem, [None]), repos : List(Reads.RepoItem) } -> Str
	releases_body = |_a| crash "todo"

	## R-AP14 without a group: `{"releases":[..],"repos":[..]}`.
	page_body : { releases : List(Release.Row), repos : List(Reads.RepoItem) } -> Str
	page_body = |_a| crash "todo"

	## R-AP2 (R-AP53): `{"artifact":<Artifact.encode>,"releases":[..],"repos":[..]}`.
	artifact_body : { artifact : Artifact.Row, releases : List(Release.Row), repos : List(Reads.RepoItem) } -> Str
	artifact_body = |_a| crash "todo"

	# ---- the problems of the three routes (R-AP21) ----

	## R-AP1, 404: `no indexed release for <owner>/<repo>` (the two path segments as sent).
	no_repo_releases : Str, Str -> Problem
	no_repo_releases = |_owner, _repo| crash "todo"

	## R-AP2, 404: `no artifact <hash>` (the path segment as sent).
	no_artifact : Str -> Problem
	no_artifact = |_hash| crash "todo"
}
