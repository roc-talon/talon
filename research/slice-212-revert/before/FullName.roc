import records.Index as WireIndex
import Fail
import Fx
import Index
import Net
import Roots
import Selector

## A full name `owner/repo` that the registry does not know (slice 212; CLI 2 R-AD35, R-AD36, R-AD37, 1 R-RG4, 7.3 R-DI2 to R-DI5, 7.5 R-DA8; Registry 4 R-AP1, R-AP9, R-AP41 row 5, R-AP43; Design Q34, Q224 to Q229).
## `tln add` (R-AD2), `tln tool install` and `tln x` (R-SC3, R-SC4) with a full name read `GET /v1/packages/{owner}/{repo}/releases` (R-AP1). A 404 is a repository that the registry did not index yet:
## the guard, the release list of GitHub (the same read as `direct` mode: `Github.releases!`, `Index.candidates`), the selector, the ingest of each candidate newest first (4 at the same time), then R-AP1 again with `no-cache` and the largest bookmark.
## The pure functions are L0 (`tests/unit/FullnameTest.roc`). `read!` is command code over `Fx` (L2: `tests/commands/cases/registry/ad35-*`, the word `fullname`).
## Reused from slice 208 as they are: `UnknownValues.ingest_requests`, `ingest_verdict` (200 and 201 with the bookmark, 429 as exit 15, the 5xx and no-answer verdicts), `largest`, `unindexed_warning`.
## Not reused: `UnknownValues.again_headers` (it is for the closure `POST`: the second read here is a `GET`, so `RegistryCache.get!` with `newest` and `bookmark` gives the headers, R-AP43).
FullName :: [].{

	## The selector of the command: `Err(None)` for none, else the parsed selector and the text that the user typed after `@` (for the messages).
	Typed : Try({ selector : Selector, text : Str }, [None])

	## R-AD35 step 1 (the selector of the command), step 3 (newest first by `published_at`): the candidates to ingest, in the order of the requests. `list` are the candidates that `Index.candidates` gives (R-DI3 to R-DI5).
	##
	## | Selector | Kept |
	## | --- | --- |
	## | none, `Latest` | all |
	## | `Exact(v)` | the candidates whose `ident.version` is `v` |
	## | `Range(text)` | the candidates that `Ranges.admits` for the version |
	## | `Nightly`, `Step`, `GitSha`, `GitRef` | Not here: `way` stops them before any request (Design Q397). `select` is called only for the forms above |
	##
	## Then the order: the larger `published_at` first. Candidates with the same time keep the order of `list` (the order of the GitHub pages). The version number is not used for the order.
	select : { list : List(Index.Candidate), selector : Try(Selector, [None]) } -> List(Index.Candidate)
	select = |_facts| crash "todo: slice 212"

	## R-AD35 step 3 (a 409 or 422 answer: Talon skips that release and prints a warning that names it and the error `type`). `Ok(text)` for the status 409 and 422 (any `type`, also no problem details). Any other status: `Err(NotSkipped)`: the caller uses `UnknownValues.ingest_verdict`.
	## The text (proposal, TW24): `warning: <name> <tag>: skipped, the registry answered <status> (<type>).` With no problem details (`Registry.problem` is `NotProblem`): `warning: <name> <tag>: skipped, the registry answered <status>.` `name` is `owner/repo`.
	skip_warning : { name : Str, tag : Str, status : U16, body : Str } -> Try(Str, [NotSkipped])
	skip_warning = |_facts| crash "todo: slice 212"

	## R-AD35 step 2 (no release is a candidate: exit 2, as R-T10), and step 4 when each ingest was skipped for a 409 or 422 (Design Q399): kind `Usage`. Only for a name with no usable release and no selector (Design Q430: with a selector, each command has its own text, slice 206b). The text (proposal, TW24):
	## `<name> has no release that Talon can use. A release needs one <hash>.tar.zst asset and must not be a draft or a prerelease.`
	no_candidate : { name : Str } -> Fail
	no_candidate = |_facts| crash "todo: slice 212"

	## R-AD35 step 1 (Design Q397): what a selector means for a full name, decided before any request (no guard, no read).
	##
	## | Selector | Way |
	## | --- | --- |
	## | none, `Exact`, `Range`, `Latest` | `Registry`: the path of R-AD35 |
	## | `Nightly`, `Step` (R-SL6, R-SL7: for a compiler only) | `Compiler`: the command stops with exit 2 (`compiler_only`) |
	## | `GitSha`, `GitRef` (R-SL8, R-SL10, R-SL11) | `Source`: a source build, no registry path, no ingest |
	##
	## A sha of digits only is a `Range` (a series) for `Selector.parse` (R-SL9 rule 1), so it is `Registry`.
	way : Try(Selector, [None]) -> [Registry, Compiler, Source]
	way = |_selector| crash "todo: slice 212"

	## Design Q397: kind `Usage` (exit 2) for `Compiler`. `text` is what the user typed after `@`. Text (proposal, TW24): `<name>@<text>: a nightly tag and a relative step name a compiler release. <name> is not a compiler.`
	compiler_only : { name : Str, text : Str } -> Fail
	compiler_only = |_facts| crash "todo: slice 212"

	## R-AD35 step 3 (Design Q398, Q421): the warning of an ingest that gave a 5xx, a 3xx, a 202 or no answer: the release is skipped. `what` is the status as text or `no answer` (the `Unindexed` verdict of `UnknownValues.ingest_verdict`). Text (proposal, TW24):
	## `warning: <name> <tag>: skipped, the registry did not index this release (<what>).` Another 4xx is skipped with no text.
	unindexed_warning : { name : Str, tag : Str, what : Str } -> Str
	unindexed_warning = |_facts| crash "todo: slice 212"

	## R-AD35 step 4 (Design Q399, R-AP65): what follows step 3. `indexed` is the count of answers 200 and 201, `skipped` the count of 409 and 422, `other` the count of the answers of Q398 (5xx, 3xx, 202, no answer, another 4xx).
	##
	## | Counts | Result |
	## | --- | --- |
	## | `indexed` 1 or more | `Ask`: R-AP1 again |
	## | `indexed` 0, `other` 1 or more | `NotIndexed`: exit 15 (`not_indexed`), no read |
	## | `indexed` 0, `other` 0 (each ingest skipped, or none) | `NoCandidate`: exit 2 with `no_candidate`, no read |
	after_ingests : { indexed : U64, skipped : U64, other : U64 } -> [Ask, NotIndexed, NoCandidate]
	after_ingests = |_counts| crash "todo: slice 212"

	## Design Q399: kind `Network` (exit 15). Text (proposal, TW24): `the registry did not index <name> now. Run the command again in a moment.`
	not_indexed : { name : Str } -> Fail
	not_indexed = |_facts| crash "todo: slice 212"

	## R-AD36 (`--snapshot log:N`): kind `Usage` (exit 2). The message says that the name has no release in the log at size N. Text (proposal, TW24): `<name> has no release in the log at size <size>. A snapshot sends no ingest.`
	snapshot_stop : { name : Str, size : U64 } -> Fail
	snapshot_stop = |_facts| crash "todo: slice 212"

	## R-AD35 step 4 (R-AP1 is still 404 after the ingests): kind `Network` (exit 15). The message says that the registry indexes the repository and to run the command again. Text (proposal, TW24): `the registry has no release of <name> yet. The registry is indexing the repository: run the command again in a moment.`
	still_missing : { name : Str } -> Fail
	still_missing = |_facts| crash "todo: slice 212"

	## R-AD35, R-AD36, R-AD37 (the 4 steps). `name` is `<owner>/<repo>`. `snapshot` is `--snapshot log:N`. `known` are the URLs that Talon knows already (R-DI15: header entries). `offline` is `--offline`.
	## The result: `Found(answer)`: the answer of R-AP1 (a 200). `NoMatch`: the selector keeps no candidate (the command gives its own text, Design Q430, slice 206b). `SourceBuild`: the selector is a source build (`way`): no request was made.
	## The calls, in order (the L2 cases `registry/ad35-*`, `ad36-*`, `ad37-*` fix them):
	##
	## | Step | Call |
	## | --- | --- |
	## | 0 | `way` of the selector, before any call: `Compiler` is `Err(compiler_only)`, `Source` is `Ok(SourceBuild)` |
	## | 1 | `PrivacyGuard.check!` with `Repo("<owner>/<repo>")`, `offline`, not `frozen`, before the first request that carries the name (R-RG4). A private or unknown repository: its failure (exit 2, R-RG6), and nothing else is called |
	## | 2 | `RegistryCache.get!` of `Registry.releases_of_repo_url` (the lower-case name), `offline` as given. 200: decode with `WireIndex.decode_releases` (a body that does not decode: kind `Network`, R-E6), and `Found`, no more call. `NoCopy` (offline, no copy): `Github.no_page_failure(name)` (exit 15, R-DI12, R-AD37: no request). 404: step 3. Any other status: `Registry.refuse` with method `Get` (R-E6) |
	## | 3 | `snapshot` is `Ok(n)`: `snapshot_stop` (R-AD36, Design Q396), no more call: no GitHub read, no ingest |
	## | 4 | `Github.releases!` (R-DI2: the cache pages, the token rules of R-RG3), then `Index.candidates` with `known`: each warning of it on stderr as `warning: <text>`, in order. A page that is not a list: kind `Network`, as `PickIndex.index!` |
	## | 5 | `select`. Nothing is left: with a selector `Ok(NoMatch)`, with no selector `Err(no_candidate)`. No more call |
	## | 6 | One `programs!(["curl"])` (Design Q229). No `curl`: kind `Environment` (exit 18) with the text of `UnknownValues.settle!`, and no request. Then one `http_all!` with `UnknownValues.ingest_requests` of the `select` order, `limit` 4, `tmp_dir` `<roots.cache>/talon/tmp` |
	## | 7 | For each result in order: `skip_warning` (409, 422) is on stderr, counted as `skipped`. Else `UnknownValues.ingest_verdict`: `Indexed({ bookmark })` keeps the bookmark and counts `indexed`. `Err` (429): the failure at once (exit 15, `Try again in <n> s.`), no step 8. `Unindexed({ what })`: `unindexed_warning` on stderr, counted as `other`. `Archive` (another 4xx): no text, counted as `other` (Design Q398) |
	## | 8 | `after_ingests`. `NotIndexed`: `Err(not_indexed)`. `NoCandidate`: `Err(no_candidate)`. `Ask`: `RegistryCache.get!` of the same path with `newest` and the `bookmark` of `UnknownValues.largest` of the kept bookmarks (`Err(None)`: `no-cache` only). 200: decoded, `Found`. 404: `still_missing`. Any other status: `Registry.refuse` |
	read! : Fx, { net : Net.Settings, roots : Roots, origin : Str, version : Str, now : U64, offline : Bool, name : Str, selector : FullName.Typed, snapshot : Try(U64, [None]), known : List(Str) } => Try([Found(WireIndex.Releases), NoMatch, SourceBuild], Fail)
	read! = |_fx, _facts| crash "todo: slice 212"
}
