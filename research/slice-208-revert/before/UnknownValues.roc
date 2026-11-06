import records.Closure as Wire
import records.Release as WireRelease
import ClosureRequest
import Fail
import Fx
import Roots

## The unknown header values of a closure answer (slice 208; Registry 4.1 R-AP28, R-AP65, R-AP9, R-AP41 row 5, R-AP43, R-AP59; CLI 7.3 R-DI7, R-DI11; CLI 7.5 R-DA8, Design Q122, Q224 to Q229).
## `unknown` of the answer (R-AP17) lists the hashes of header entries that the registry does not index. The 3 cases of R-AP28, in order, first match:
## case 1 the label with another hash (warning, no ingest), case 2 the ingest of each public `github.com` URL, then the closure query again once with the largest bookmark, case 3 the archive (R-DI7).
## The pure functions are L0 (`tests/unit/UnknownvaluesTest.roc`). `settle!` is command code over `Fx` (L2: `tests/commands/cases/registry/`, the word `settle`).
UnknownValues :: [].{

	## What R-AP28 says about one unknown value. `Label`: case 1 (`other`: the hash that the answer has for the label, `Err(None)` when the source is a 409 of an ingest, R-AP65 source 2, Q164: the 409 does not name it). `Ingest`: case 2. `Archive`: case 3.
	Case : [Label({ other : Try(Str, [None]) }), Ingest, Archive]

	## One unknown value: the hash, the URL of the entry with this hash, and its case.
	Value : { hash : Str, url : Str, case : Case }

	## The end of a value after `settle!`: `Indexed` (the ingest answered 200 or 201), `Label`, `Archive` (the facts come from the archive, R-DI7).
	End : [Label({ other : Try(Str, [None]) }), Indexed, Archive]

	## R-AP28, R-AP65 source 1, R-AP59, R-RG4, R-PU40: the case of each hash of `unknown`, in the order of `unknown` (each once). `urls` are the header values that are URLs (the entries). The URL of a hash is the entry whose `Ident.of_url` has this hash. A hash with no such entry gives no value.
	## `releases` are the release rows of the answer. `snapshot` is true with `--snapshot log:N`.
	##
	## | # | Condition (first that applies) | Case |
	## | --- | --- | --- |
	## | 1 | A row of `releases` has the label of the URL (the `group` of `Ident.of_url` equal to the row `group`, and the same `version`) and another hash | `Label({ other: Ok(<that hash>) })`. Also with `snapshot` and for any host. |
	## | 2 | The URL is a `github.com` release asset URL of a repository that the guard checks (`PrivacyGuard.repos_to_check` of `Url(<url>)` is one repository), and not `snapshot` | `Ingest` |
	## | 3 | Any other URL (another host, a loopback host, `raw.githubusercontent.com`, an unsafe part), or `snapshot` | `Archive` |
	classify : { unknown : List(Str), urls : List(Str), releases : List(WireRelease.Row), snapshot : Bool } -> List(UnknownValues.Value)
	classify = |_facts| crash "todo: slice 208"

	## R-AP28 case 1, R-AP65 (proposal, TW24): the warning for a `Label` value, with the name and version of the URL (`Ident.of_url`), the hash of the header, and the hash of the registry when `other` is `Ok`.
	##
	## | `other` | Text |
	## | --- | --- |
	## | `Ok(h)` | `warning: <name> <version>: the registry has this release with the hash <h>, the header has <hash>. Talon does not use the registry's release for this value. Ask the author to release a new version.` |
	## | `Err(None)` | `warning: <name> <version>: the registry has this release with another hash, the header has <hash>. Talon does not use the registry's release for this value. Ask the author to release a new version.` |
	label_warning : { url : Str, hash : Str, other : Try(Str, [None]) } -> Str
	label_warning = |_facts| crash "todo: slice 208"

	## R-AP9, R-AP28 case 2, R-DA8 rule 1, R-AP45, R-AP23: the requests of the ingests, one for each URL, in the order of `urls`. Each is `Post`, `Registry`-form `<origin>/v1/releases`, the headers of `Registry.headers({ version, body: Json })` (no `Authorization`, no `Talon-Contributor`),
	## the body `{"url":"<url>"}` (the URL as JSON text), and `timeout_s` 20 (question Q1: the value of `ClosureIndex.query_timeout_s`).
	ingest_requests : { origin : Str, version : Str, urls : List(Str) } -> List({ method : [Get, Post, Put, Delete], url : Str, headers : List((Str, Str)), body : Str, timeout_s : U64 })
	ingest_requests = |_facts| crash "todo: slice 208"

	## R-AP28 case 2, R-AP65 source 2, R-AP25, R-AD35 step 3: what one ingest answer means for its URL. `reply` is the answer (the headers are the ones of the answer).
	##
	## | Answer | Result |
	## | --- | --- |
	## | 200 or 201 | `Ok(Indexed({ bookmark }))`: `bookmark` is the value of the header `Talon-Bookmark` (the name in any case, white space cut, an empty value is none) |
	## | 409 with the problem type `/errors/label-conflict` | `Ok(Label)` (R-AP65 source 2) |
	## | 409 with another type or no problem details, 422, any other 4xx except 429 | `Ok(Archive)` (R-AP28 case 3) |
	## | 429 | `Err(Registry.refuse(..))`: kind `Network` (exit 15, R-AP25) |
	##
	## 5xx, no answer and a body that is no problem details with 409: question Q2 (not tested).
	ingest_verdict : { origin : Str, version : Str, reply : { status : U16, headers : List((Str, Str)), body : Str } } -> Try([Indexed({ bookmark : Try(Str, [None]) }), Label, Archive], Fail)
	ingest_verdict = |_facts| crash "todo: slice 208"

	## R-AP41 row 5, R-AP28 case 2: the largest of some bookmarks. None: `Err(None)`. The order is question Q3: the tests use bookmarks of one width in lower-case hex segments, where the byte order and the order of the numbers are the same.
	largest : List(Str) -> Try(Str, [None])
	largest = |_marks| crash "todo: slice 208"

	## R-AP28 case 2, R-AP43 case 1 and 2, R-AP41 row 5, R-AP45: the headers of the second closure query, in this order (question Q3): `User-Agent: tln/<version>`, `Content-Type: application/json`, `Cache-Control: no-cache`, `Talon-Bookmark: <bookmark>`.
	again_headers : { version : Str, bookmark : Str } -> List((Str, Str))
	again_headers = |_facts| crash "todo: slice 208"

	## R-AP28 cases 1 to 3 in order, R-AP65, R-DA8, R-AP34 (an ingest is sent once). The calls, in order (the L2 cases `registry/ap28-*` fix them):
	##
	## | Step | Call |
	## | --- | --- |
	## | 1 | `classify` on `first.unknown`, `urls`, `first.releases`, `snapshot`. The warning of each `Label` value on stderr (`label_warning`), in order, before any request. |
	## | 2 | No `Ingest` value: no more call, the result is `first`. |
	## | 3 | One `programs!(["curl"])` (Design Q229). No `curl`: `Err` of kind `Environment` (exit 18) with the text `curl is not on PATH. Talon needs curl to send the ingests at the same time.` (proposal), and no request. |
	## | 4 | One `http_all!` with `ingest_requests`, `limit` 4, `tmp_dir` `<roots.cache>/talon/tmp`. |
	## | 5 | `ingest_verdict` of each result in order. A result that is `Timeout` or `Failed`: question Q2. `Err` (429): the failure at once, no second query. `Label`: the warning (`label_warning` with `other` none) on stderr, the value ends as `Label`. `Archive`: the value ends as `Archive`. `Indexed`: the value ends as `Indexed`. |
	## | 6 | At least one `Indexed`: one more query, as `ClosureIndex.query!` (same body, the checks, `ClosureIndex.one_state`, no second try) with `again_headers` and the `largest` bookmark of the `Indexed` answers. No `Indexed`: no second query, the result is `first`. |
	##
	## The result: `answer` is the answer of the second query, or `first`. `values` are the values in the order of `classify` with their end.
	settle! : Fx, { origin : Str, version : Str, roots : Roots, facts : ClosureRequest.Facts, first : Wire.Answer, urls : List(Str), snapshot : Bool } => Try({ answer : Wire.Answer, values : List({ hash : Str, url : Str, end : UnknownValues.End }) }, Fail)
	settle! = |_fx, _facts| crash "todo: slice 208"
}
