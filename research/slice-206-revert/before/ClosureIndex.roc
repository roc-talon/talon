import records.Closure as Wire
import records.Release as WireRelease
import records.Artifact as WireArtifact
import Closure
import ClosureRequest
import Fail
import Fx
import Index
import Release
import Roots

## The closure answer as the index of one command (slice 206; Registry 4.1 R-AP17, R-AP18, R-AP20, R-AP42, R-AP49, R-AP63, R-AP64; CLI 7.3 R-DI14, 6.1 R-IX6; Resolution 5 R-AL8, R-AL9).
## One command uses one index (R-DI14): `Source` says which. With `Answer`, the candidates, the kinds, the deps and the `roc_version` hints come from the one closure answer (R-AL8 source 2), and Talon reads no GitHub page, no `.roc-version`
## file and no archive for a hash that the answer has. With `Offline`, the candidates come from the kept copies of the registry reads (R-IX6) and the facts from the archives (R-DI7).
## The pure functions are L0 (`tests/unit/ClosureindexTest.roc`). `query!` and `offline!` are command code over `Fx` (L2: `tests/commands/cases/registry/`).
ClosureIndex :: [].{

	## The index of one command. `Direct`: GitHub Releases (CLI 7.3). `Answer`: the closure answer of `origin` (the base URL form of R-RG7). `Offline(origin)`: `--offline` with the registry `origin` (R-IX6).
	## Every constructor of `ResolveBase.Request` gives `Direct`. The flow that sends the query (R-AL2 step 2) sets `Answer` (out of scope of slice 206: it needs the registry setting, slice 224).
	Source : [Direct, Answer({ origin : Str, answer : Wire.Answer }), Offline(Str)]

	## The header facts of one release from its artifact record (R-AL8 source 2, R-AP49): `release` as `Release.read` gives it, `entries` as `Release.entries_of` gives them, `target_names` as `BuildTarget.targets_of` gives them (a platform).
	Header : { release : Release, entries : List(Closure.Entry), target_names : List(Str) }

	## R-AP17, R-AP49 (reader), R-AP50, R-AP63, R-DI14: the candidates of the repository `name` (`owner/repo`, any case) from the release rows of an answer or of a kept copy.
	##
	## | # | Rule |
	## | --- | --- |
	## | 1 | A row is of `name` when its `repo` is `Ok(name)` in lower case (R-AP49 `repo`, R-IK2). A row with `repo` null (another host) is of no name. |
	## | 2 | A row with `withdrawn` set (any text, also one that Talon does not know) is not a candidate (R-AP49, CLI 1 R-AU2, Resolution R-C6). |
	## | 3 | A row whose `url` is not a release URL (`Ident.of_url` is `Err`) is not a candidate. |
	## | 4 | The rows are not filtered by a range or a series: the answer has only what the request asked for, and the release of a header value stays also outside the range (R-AP63, Resolution R-C9). The solver applies the range. |
	## | 5 | A candidate: `url` as in the row, `ident` of the URL, `tag` (null gives `""`), `published_at` in seconds (the milliseconds of R-AP50 divided by 1000), `size` of the artifact record with the hash of the row (no record: 0, for example a kept copy of R-AP13 that has no artifacts). |
	## | 6 | The order of the rows stays (R-AP53: rising `log_index`). |
	candidates : { releases : List(WireRelease.Row), artifacts : List(WireArtifact.Row), name : Str } -> List(Index.Candidate)
	candidates = |_facts| crash "todo: slice 206"

	## R-AL8 source 2, R-AP17 `artifacts`, R-AP49: the header facts of the release URL `id` from the artifact record with the hash of the URL. An id that is no release URL (a path file) or whose hash has no record: `Err(NotInAnswer)`.
	##
	## | Field | From the record |
	## | --- | --- |
	## | `release.kind` | `kind` (`App`, `Package`, `Platform`) |
	## | `release.deps` | the `url` of each item of `deps`, in the order of the record (sorted by alias, R-AP49) |
	## | `release.pf` | `Err(None)`. See Q1 of the slice file: the record does not mark a platform entry |
	## | `entries` | `{ alias, value: url, is_platform: Bool.False }` for each item of `deps`, in order (Q1) |
	## | `target_names` | `target_names` (R-RE20) |
	##
	## The `roc_pin` of the record is not a field: no caller of `Gather` reads the pin of a release header from the text either (rank 3 is out of scope).
	header : Wire.Answer, Str -> Try(Header, [NotInAnswer])
	header = |_answer, _id| crash "todo: slice 206"

	## R-EF1 rank 4, R-AP49 `roc_version`, R-DI14: the hint of the release URL `id`: the release row with this `url`, then its `roc_version` read as the text of a `.roc-version` file (`Github.hint` of status 200: the first line that is not empty, trimmed).
	## No row with this `url`, a `roc_version` that is null, or a text with no line: `Err(None)`.
	hint : Wire.Answer, Str -> Try(Str, [None])
	hint = |_answer, _id| crash "todo: slice 206"

	## R-AP64, R-AP29: the `checked` item of the repository `name` (any case: the items have the lower-case name). None: `Err(None)`. Slice 210 prints the note.
	checked_of : Wire.Answer, Str -> Try(Wire.Checked, [None])
	checked_of = |_answer, _name| crash "todo: slice 206"

	## R-AP3, R-AP17, R-AP20, R-AP34, R-AP74 row 4, R-AP78, R-IX3, R-E6: the one closure query of a command. The calls, in order (the L2 case `registry/ap20-closure-query` fixes them):
	##
	## | Step | Call |
	## | --- | --- |
	## | 1 | `ClosureRequest.request(facts)`. `Err(NoCompiler)` (a `Free` window with no compiler): the failure `ClosureRequest.no_compiler` of its domain (exit 10), and no call. |
	## | 2 | `ClosureRequest.check` with the counts of `groups` and `hashes` and the bytes of the body (`Wire.encode_request`): its failure (exit 1), and no call. |
	## | 3 | One `http_send!`: `Post`, `Registry.closure_url(origin)`, `Registry.headers({ version, body: Json })`, the body, `timeout_s` 20 (Q2: the time of `RegistryCache.get!`). It is sent once: no second try after an error (R-AP34: only publish, yank and move try again). |
	## | 4 | No answer: `Registry.no_answer` with `no answer in 20 s` for `Timeout` and the text for `Failed` (exit 15). A status other than 200: `Registry.refuse` with method `Query`. Status 200: `Registry.closure_answer` (a body that does not decode: exit 15). |
	##
	## No file is written: the answer is `no-store` and Talon keeps no copy of it (R-IX3).
	query! : Fx, { origin : Str, version : Str, facts : ClosureRequest.Facts } => Try(Wire.Answer, Fail)
	query! = |_fx, _facts| crash "todo: slice 206"

	## R-IX6, R-AD37, R-DI12 (Design Q205, G-C9): the candidates of the repository `name` with `--offline` and a registry. No request. `forms` are the URL forms of the groups of `name` that the command knows (the header values), in order, each once.
	## The calls, in order (the L2 case `registry/ix6-offline-registry` fixes them):
	##
	## | Step | Call |
	## | --- | --- |
	## | 1 | For each form F: one `RegistryCache.get!` with `offline` of the path `/v1/releases?group=<F>` (`Registry.releases_url` with no `series`). A copy: the candidates (`candidates`) of the rows whose `group` is F. `NoCopy`: F has no copy yet. |
	## | 2 | When `forms` is empty, or a form has no copy: one `RegistryCache.get!` with `offline` of `/v1/packages/<owner>/<repo>/releases` (`Registry.releases_of_repo_url`). A copy: the candidates of the rows of each form with no copy (all rows when `forms` is empty). `NoCopy`: no candidate for them. |
	## | 3 | The result: the candidates (step 1 in the order of `forms`, then step 2), `missing` when a form (or the name with no form) got no copy (the group acts as in R-DI11), and `oldest`: the smallest copy time that it used (`Err(None)` for none). |
	##
	## A copy body is decoded with `records.Index.decode_releases`. Talon reads no GitHub page of `talon/index/github/` (R-IX5).
	offline! : Fx, { roots : Roots, origin : Str, version : Str, now : U64, name : Str, forms : List(Str) } => Try({ list : List(Index.Candidate), missing : Bool, oldest : Try(U64, [None]) }, Fail)
	offline! = |_fx, _facts| crash "todo: slice 206"
}
