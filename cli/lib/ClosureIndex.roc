import records.Closure as Wire
import records.Release as WireRelease
import records.Artifact as WireArtifact
import records.Index as WireIndex
import Closure
import ClosureRequest
import Fail
import Fx
import Github
import Ident
import Index
import Registry
import RegistryCache
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
	candidates = |facts| {
		name = facts.name.with_ascii_lowercased()
		facts.releases.keep_oks(
			|row| {
				mine = match row.repo {
					Ok(repo) => repo.with_ascii_lowercased() == name
					Err(None) => Bool.False
				}
				if !mine or row.withdrawn.is_ok() {
					Err(NoCandidate)
				} else {
					match Ident.of_url(row.url) {
						Err(Foreign) => Err(NoCandidate)
						Ok(ident) => {
							size = match facts.artifacts.find_first(|a| a.hash == row.hash) {
								Ok(a) => a.size
								Err(_) => 0
							}
							Ok({ url: row.url, ident, tag: row.tag ?? "", published_at: row.published_at // 1000, size })
						}
					}
				}
			},
		)
	}

	## Slice 206d, Design Q461 (R-AP28 case 1, R-AP65, R-C9): the candidates of a name after the drop of the registry's release of a `Label` value. A candidate is dropped when a URL of `known` (the header values, `Ident.of_url`)
	## has its group form (`ident.group.form`) and its version, and another hash. So the pick keeps the header URL of that label (the warning says that Talon does not use the registry's release for this value).
	## The other versions of the group, a candidate with the hash of the header URL, and a candidate of another group form stay. The order stays. A `known` text that is no release URL drops nothing.
	drop_labels : { list : List(Index.Candidate), known : List(Str) } -> List(Index.Candidate)
	drop_labels = |facts| {
		labels = facts.known.keep_oks(Ident.of_url)
		facts.list.drop_if(|c| labels.any(|k| k.group.form == c.ident.group.form and k.version == c.ident.version and k.hash != c.ident.hash))
	}

	## R-AL8 source 2, R-AP17 `artifacts`, R-AP49: the header facts of the release URL `id` from the artifact record with the hash of the URL. An id that is no release URL (a path file) or whose hash has no record: `Err(NotInAnswer)`.
	##
	## | Field | From the record |
	## | --- | --- |
	## | `release.kind` | `kind` (`App`, `Package`, `Platform`) |
	## | `release.deps` | the `url` of each item of `deps`, in the order of the record (sorted by alias, R-AP49) |
	## | `release.pf` | the `url` of the platform dep: the first dep with `is_platform` of a package or platform record (R-AP81, Design Q251, Q400). An app record, or no mark: `Err(None)` |
	## | `entries` | `{ alias, value: url, is_platform }` for each item of `deps`, in order. `is_platform` is true only for the platform dep (Design Q401, Q402): none for an app record, and not the second mark |
	## | `target_names` | `target_names` (R-RE20) |
	##
	## The `roc_pin` of the record is not a field: no caller of `Gather` reads the pin of a release header from the text either (rank 3 is out of scope).
	header : Wire.Answer, Str -> Try(Header, [NotInAnswer])
	header = |answer, id| match Ident.of_url(id) {
		Err(Foreign) => Err(NotInAnswer)
		Ok(ident) => match answer.artifacts.find_first(|a| a.hash == ident.hash) {
			Err(_) => Err(NotInAnswer)
			Ok(record) => {
				deps = record.deps.map(|d| d.url)
				edge = platform_dep(record)
				pf = match edge {
					Ok(d) => Ok(d.url)
					Err(_) => Err(None)
				}
				Ok({
					release: { kind: record.kind, pf, deps },
					entries: record.deps.map(
						|d| {
							is_platform = match edge {
								Ok(p) => p.alias == d.alias
								Err(_) => Bool.False
							}
							{ alias: d.alias, value: d.url, is_platform }
						},
					),
					target_names: record.target_names,
				})
			}
		}
	}

	## R-EF1 rank 4, R-AP49 `roc_version`, R-DI14: the hint of the release URL `id`: the release row with this `url`, then its `roc_version` read as the text of a `.roc-version` file (`Github.hint` of status 200: the first line that is not empty, trimmed).
	## No row with this `url`, a `roc_version` that is null, or a text with no line: `Err(None)`.
	hint : Wire.Answer, Str -> Try(Str, [None])
	hint = |answer, id| match answer.releases.find_first(|row| row.url == id) {
		Err(_) => Err(None)
		Ok(row) => match row.roc_version {
			Err(None) => Err(None)
			Ok(text) => match Github.hint({ status: 200, body: text }) {
				Ok(compiler) => Ok(compiler)
				Err(_) => Err(None)
			}
		}
	}

	## R-AP64, R-AP29: the `checked` item of the repository `name` (any case: the items have the lower-case name). None: `Err(None)`. Slice 210 prints the note.
	checked_of : Wire.Answer, Str -> Try(Wire.Checked, [None])
	checked_of = |answer, name| {
		lower = name.with_ascii_lowercased()
		match answer.checked.find_first(|c| c.name.with_ascii_lowercased() == lower) {
			Ok(c) => Ok(c)
			Err(_) => Err(None)
		}
	}

	## The query timeout in seconds (Q2 of the slice file, Design Q392: R-DA9, R-CC12). The one value of `query!` and `LogSnapshot.second!`.
	query_timeout_s : U64
	query_timeout_s = 20

	## R-AP3, R-AP17, R-AP20, R-AP34, R-AP74 row 4, R-AP78, R-IX3, R-E6: the one closure query of a command. The calls, in order (the L2 case `registry/ap20-closure-query` fixes them):
	##
	## | Step | Call |
	## | --- | --- |
	## | 1 | `ClosureRequest.request(facts)`. `Err(NoCompiler)` (a `Free` window with no compiler): the failure `ClosureRequest.no_compiler` of its domain (exit 10), and no call. |
	## | 2 | `ClosureRequest.check` with the counts of `groups` and `hashes` and the bytes of the body (`Wire.encode_request`): its failure (exit 1), and no call. |
	## | 3 | One `http_send!`: `Post`, `Registry.closure_url(origin)`, `Registry.headers({ version, body: Json })`, the body, `timeout_s` 20 (Q2: the time of `RegistryCache.get!`). It is sent once: no second try after an error (R-AP34: only publish, yank and move try again). |
	## | 4 | No answer: `Registry.no_answer` with `no answer in 20 s` for `Timeout` and the text for `Failed` (exit 15). A status other than 200: `Registry.refuse` with method `Query`. Status 200: `Registry.closure_answer` (a body that does not decode: exit 15). |
	##
	## | 5 | R-AP18 (reader, Design Q390): a release with a `log_index` above `log_size` makes the answer unused (`one_state`, exit 15). |
	##
	## No file is written: the answer is `no-store` and Talon keeps no copy of it (R-IX3).
	query! : Fx, { origin : Str, version : Str, facts : ClosureRequest.Facts } => Try(Wire.Answer, Fail)
	query! = |fx, facts| {
		request = match ClosureRequest.request(facts.facts) {
			Ok(r) => r
			Err(NoCompiler) => return Err(
				match facts.facts.window {
					Free(domain) | Report(domain) => ClosureRequest.no_compiler(domain)
					_ => Fail.new(NoTuple, "no compiler is left")
				},
			)
		}
		ClosureIndex.send!(fx, { origin: facts.origin, version: facts.version, request, headers: Registry.headers({ version: facts.version, body: Json }) })
	}

	## The one shared step of a closure query (steps 2 to 5 of `query!`): `ClosureRequest.check` of the body, one `http_send!` (`Post`, `Registry.closure_url`, `headers` as given, `timeout_s` `query_timeout_s`), the errors (no answer, `Registry.refuse` with method `Query` and the `Retry-After` of the answer),
	## the decode and `one_state`. Used by `query!`, `LogSnapshot.second!` and `UnknownValues.settle!`. No second try.
	send! : Fx, { origin : Str, version : Str, request : Wire.Request, headers : List((Str, Str)) } => Try(Wire.Answer, Fail)
	send! = |fx, facts| {
		body = Wire.encode_request(facts.request)
		ClosureRequest.check({ groups: facts.request.groups.len(), hashes: facts.request.hashes.len(), bytes: body.count_utf8_bytes() })?
		sent = fx.http_send!({ method: Post, url: Registry.closure_url(facts.origin), headers: facts.headers, body, timeout_s: ClosureIndex.query_timeout_s })
		reply = match sent {
			Ok(r) => r
			Err(Timeout) => return Err(Registry.no_answer({ origin: facts.origin, why: "no answer in ${ClosureIndex.query_timeout_s.to_str()} s" }))
			Err(Failed(text)) => return Err(Registry.no_answer({ origin: facts.origin, why: text }))
		}
		if reply.status != 200 {
			return Err(Registry.refuse({ origin: facts.origin, version: facts.version, method: Query, reply: { status: reply.status, body: reply.body }, retry_after: Registry.retry_after_of(reply.headers) }))
		}
		answer = Registry.closure_answer({ origin: facts.origin, body: reply.body })?
		ClosureIndex.one_state(facts.origin, answer)
	}

	## R-AP18 (reader), Design Q390: all rows of one answer come from one state, so no release has a `log_index` above `log_size`. Such an answer is not used: kind `Network` (exit 15, R-E6 last row),
	## `the answer of the registry <origin> is not a closure answer: the release <url> has the log index <n>, above the log size <m>` (a proposal, R-OUT2). The first such release in the order of the answer is named.
	one_state : Str, Wire.Answer -> Try(Wire.Answer, Fail)
	one_state = |origin, answer| match answer.releases.find_first(|row| row.log_index > answer.log_size) {
		Err(_) => Ok(answer)
		Ok(row) => Err(Fail.new(Network, "the answer of the registry ${origin} is not a closure answer: the release ${row.url} has the log index ${row.log_index.to_str()}, above the log size ${answer.log_size.to_str()}"))
	}

	## R-IX6, R-AD37, R-DI12 (Design Q205, G-C9): the candidates of the repository `name` with `--offline` and a registry. No request. `forms` are the URL forms of the groups of `name` that the command knows (the header values), in order, each once.
	## The calls, in order (the L2 case `registry/ix6-offline-registry` fixes them):
	##
	## | Step | Call |
	## | --- | --- |
	## | 1 | For each form F: one `RegistryCache.get!` with `offline` of the path `/v1/releases?group=<F>` (`Registry.releases_url` with no `series`). A copy: the candidates (`candidates`) of the rows whose `group` is F. `NoCopy`: F has no copy yet. |
	## | 2 | When `forms` is empty, or a form has no copy: one `RegistryCache.get!` with `offline` of `/v1/packages/<owner>/<repo>/releases` (`Registry.releases_of_repo_url`). A copy: the candidates of the rows of each form with no copy (all rows when `forms` is empty). `NoCopy`: no candidate for them. |
	## | 3 | The result: the candidates (step 1 in the order of `forms`, then step 2). `missing_forms`: the forms with no copy in step 1 and step 2 (per group, Design Q391: each acts as in R-DI11, the other groups use their copies). `missing`: no copy for the name at all (each form is in `missing_forms`, or no form and no copy in step 2). `oldest`: the smallest copy time that it used (`Err(None)` for none). |
	##
	## A copy body is decoded with `records.Index.decode_releases`. A copy that does not decode is as no copy (Design Q392, R-TF6): one `delete!` of its body and meta files (in this order), and the warning
	## `warning: the kept answer <body path> of the registry <origin> does not decode (<reason>); removed` on stderr (a proposal, R-OUT2). Talon reads no GitHub page of `talon/index/github/` (R-IX5).
	offline! : Fx, { roots : Roots, origin : Str, version : Str, now : U64, name : Str, forms : List(Str) } => Try({ list : List(Index.Candidate), missing : Bool, missing_forms : List(Str), oldest : Try(U64, [None]) }, Fail)
	offline! = |fx, facts| {
		var $list = no_candidates
		var $oldest = Err(None)
		var $no_copy = no_names
		for form in facts.forms {
			path = Registry.releases_url({ origin: "", group: form, series: Err(None) })
			match kept!(fx, facts, path)? {
				Ok(copy) => {
					$list = $list.concat(ClosureIndex.candidates({ releases: copy.rows.keep_if(|row| row.group == form), artifacts: [], name: facts.name }))
					$oldest = older($oldest, copy.time)
				}
				Err(NoCopy) => {
					$no_copy = $no_copy.append(form)
				}
			}
		}
		if facts.forms.is_empty() or !$no_copy.is_empty() {
			(owner, repo) = match facts.name.split_first("/") {
				Ok({ before, after }) => (before, after)
				Err(_) => (facts.name, "")
			}
			path = Registry.releases_of_repo_url({ origin: "", owner, repo })
			match kept!(fx, facts, path)? {
				Ok(copy) => {
					rows = if facts.forms.is_empty() copy.rows else copy.rows.keep_if(|row| $no_copy.contains(row.group))
					$list = $list.concat(ClosureIndex.candidates({ releases: rows, artifacts: [], name: facts.name }))
					$oldest = older($oldest, copy.time)
					$no_copy = []
				}
				Err(NoCopy) => {
					if facts.forms.is_empty() {
						return Ok({ list: $list, missing: Bool.True, missing_forms: [], oldest: $oldest })
					}
				}
			}
		}
		missing_forms = $no_copy
		Ok({ list: $list, missing: !facts.forms.is_empty() and missing_forms.len() == facts.forms.len(), missing_forms, oldest: $oldest })
	}
}

# R-AP81, Design Q251, Q400 to Q402: the platform dep of a record. A package or platform record: the first dep with `is_platform`. An app record, or no mark: none.
platform_dep : WireArtifact.Row -> Try(WireArtifact.Dep, [None])
platform_dep = |record| match record.kind {
	App => Err(None)
	Package | Platform => match record.deps.find_first(|d| d.is_platform) {
		Ok(d) => Ok(d)
		Err(_) => Err(None)
	}
}

no_candidates : List(Index.Candidate)
no_candidates = []

no_names : List(Str)
no_names = []

older : Try(U64, [None]), U64 -> Try(U64, [None])
older = |oldest, t| match oldest {
	Ok(old) if old <= t => Ok(old)
	_ => Ok(t)
}

# One kept copy of a read route (R-IX6), with no request: its rows and its time. A copy that does not decode is as no copy (Design Q392, R-TF6): Talon deletes it and prints a warning that names the file.
kept! : Fx, { roots : Roots, origin : Str, version : Str, now : U64, name : Str, forms : List(Str) }, Str => Try(Try({ rows : List(WireRelease.Row), time : U64 }, [NoCopy]), Fail)
kept! = |fx, facts, path| {
	got = RegistryCache.get!(fx, { roots: facts.roots, origin: facts.origin, version: facts.version, path, now: facts.now, offline: Bool.True, newest: Bool.False, bookmark: Err(None) })?
	match got {
		NoCopy => Ok(Err(NoCopy))
		Answer(answer) => {
			time = match answer.source {
				Copy(t) => t
				Live => facts.now
			}
			match WireIndex.decode_releases(answer.body) {
				Ok(decoded) => Ok(Ok({ rows: decoded.releases, time }))
				Err(BadJson(reason)) => {
					files = RegistryCache.files({ roots: facts.roots, origin: facts.origin, url: "${facts.origin}${path}" })
					_ = fx.delete!([files.body, files.meta])
					fx.err!("warning: the kept answer ${files.body} of the registry ${facts.origin} does not decode (${reason}); removed\n")
					Ok(Err(NoCopy))
				}
			}
		}
	}
}
