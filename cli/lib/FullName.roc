import records.Index as WireIndex
import Fail
import Fx
import Github
import Index
import Net
import PrivacyGuard
import Ranges
import Registry
import RegistryCache
import Roots
import Selector
import UnknownValues

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
	select = |facts| {
		kept = match facts.selector {
			Ok(Exact(v)) => facts.list.keep_if(|c| c.ident.version == v)
			Ok(Range(text)) => facts.list.keep_if(|c| Ranges.admits({ ranges: [text], version: c.ident.version }))
			_ => facts.list
		}
		numbered = kept.fold([], |acc, c| acc.append((acc.len(), c)))
		numbered
			.sort_with(
				|(i, a), (j, b)| if a.published_at > b.published_at {
					Before
				} else if a.published_at < b.published_at {
					After
				} else if i < j {
					Before
				} else if i > j {
					After
				} else {
					Same
				},
			)
			.map(|(_, c)| c)
	}

	## R-AD35 step 3 (a 409 or 422 answer: Talon skips that release and prints a warning that names it and the error `type`). `Ok(text)` for the status 409 and 422 (any `type`, also no problem details). Any other status: `Err(NotSkipped)`: the caller uses `UnknownValues.ingest_verdict`.
	## The text (proposal, TW24): `warning: <name> <tag>: skipped, the registry answered <status> (<type>).` With no problem details (`Registry.problem` is `NotProblem`): `warning: <name> <tag>: skipped, the registry answered <status>.` `name` is `owner/repo`.
	skip_warning : { name : Str, tag : Str, status : U16, body : Str } -> Try(Str, [NotSkipped])
	skip_warning = |facts| if facts.status == 409 or facts.status == 422 {
		head = "warning: ${facts.name} ${facts.tag}: skipped, the registry answered ${facts.status.to_str()}"
		match Registry.problem({ status: facts.status, body: facts.body }) {
			Ok(problem) => Ok("${head} (${problem.type_text}).")
			Err(NotProblem) => Ok("${head}.")
		}
	} else {
		Err(NotSkipped)
	}

	## R-AD35 step 2 (no release is a candidate: exit 2, as R-T10), and step 4 when each ingest was skipped for a 409 or 422 (Design Q399): kind `Usage`. Only for a name with no usable release and no selector (Design Q430: with a selector, each command has its own text, slice 206b). The text (proposal, TW24):
	## `<name> has no release that Talon can use. A release needs one <hash>.tar.zst asset and must not be a draft or a prerelease.`
	no_candidate : { name : Str } -> Fail
	no_candidate = |facts| Fail.new(Usage, "${facts.name} has no release that Talon can use. A release needs one <hash>.tar.zst asset and must not be a draft or a prerelease.")

	## Slice 206f (R-AD35 step 5, Design Q545): the one item of the closure query for a full name, from the R-AP1 answer. `group` is the `group` of the releases that the selector keeps (the release with the largest `published_at`, then the larger `log_index`, of the kept ones that are not yanked and not withdrawn, else of the kept ones; the first wins a tie).
	## `text` is what the user typed after `@`, `range` is the range of the new entry (`Fresh.range`: `=1.2.3` for a version, `^1` for a range). The members of the item:
	##
	## | Selector | `series` | `range` |
	## | --- | --- | --- |
	## | a version (`Exact`), a range or a series (Design Q555: `^1`, `^1.2`) | none | `range` |
	## | none, `Latest` | none | none |
	##
	## `Err(NoMatch)`: the selector keeps no release of the answer. The versions of all rows are for the close versions of the text of `add` (`Add.no_release`).
	closure_item : { releases : WireIndex.Releases, selector : Try(Selector, [None]), text : Str, range : Str } -> Try({ group : Str, series : Try(Str, [None]), range : Try(Str, [None]) }, [NoMatch])
	closure_item = |facts| {
		kept = facts.releases.releases.keep_if(
			|r| match facts.selector {
				Ok(Exact(v)) => r.version == v
				Ok(Range(text)) => Ranges.admits({ ranges: [text], version: r.version })
				_ => Bool.True
			},
		)
		live = kept.keep_if(|r| !r.yanked and r.withdrawn == Err(None))
		pool = if live.is_empty() kept else live
		newest = pool.fold(
			Err(NoMatch),
			|best, r| match best {
				Ok(b) if b.published_at > r.published_at or (b.published_at == r.published_at and b.log_index >= r.log_index) => Ok(b)
				_ => Ok(r)
			},
		)
		match newest {
			Err(NoMatch) => Err(NoMatch)
			Ok(r) => {
				range = match facts.selector {
					Ok(Exact(_)) | Ok(Range(_)) => Ok(facts.range)
					_ => Err(None)
				}
				Ok({ group: r.group, series: Err(None), range })
			}
		}
	}

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
	way = |selector| match selector {
		Ok(Nightly(_)) | Ok(Step(_)) => Compiler
		Ok(GitSha(_)) | Ok(GitRef(_)) => Source
		_ => Registry
	}

	## Design Q397: kind `Usage` (exit 2) for `Compiler`. `text` is what the user typed after `@`. Text (proposal, TW24): `<name>@<text>: a nightly tag and a relative step name a compiler release. <name> is not a compiler.`
	compiler_only : { name : Str, text : Str } -> Fail
	compiler_only = |facts| Fail.new(Usage, "${facts.name}@${facts.text}: a nightly tag and a relative step name a compiler release. ${facts.name} is not a compiler.")

	## R-AD35 step 3 (Design Q398, Q421): the warning of an ingest that gave a 5xx, a 3xx, a 202 or no answer: the release is skipped. `what` is the status as text or `no answer` (the `Unindexed` verdict of `UnknownValues.ingest_verdict`). Text (proposal, TW24):
	## `warning: <name> <tag>: skipped, the registry did not index this release (<what>).` Another 4xx is skipped with no text.
	unindexed_warning : { name : Str, tag : Str, what : Str } -> Str
	unindexed_warning = |facts| "warning: ${facts.name} ${facts.tag}: skipped, the registry did not index this release (${facts.what})."

	## R-AD35 step 4 (Design Q399, R-AP65): what follows step 3. `indexed` is the count of answers 200 and 201, `skipped` the count of 409 and 422, `other` the count of the answers of Q398 (5xx, 3xx, 202, no answer, another 4xx).
	##
	## | Counts | Result |
	## | --- | --- |
	## | `indexed` 1 or more | `Ask`: R-AP1 again |
	## | `indexed` 0, `other` 1 or more | `NotIndexed`: exit 15 (`not_indexed`), no read |
	## | `indexed` 0, `other` 0 (each ingest skipped, or none) | `NoCandidate`: exit 2 with `no_candidate`, no read |
	after_ingests : { indexed : U64, skipped : U64, other : U64 } -> [Ask, NotIndexed, NoCandidate]
	after_ingests = |counts| if counts.indexed > 0 {
		Ask
	} else if counts.other > 0 {
		NotIndexed
	} else {
		NoCandidate
	}

	## Design Q399: kind `Network` (exit 15). Text (proposal, TW24): `the registry did not index <name> now. Run the command again in a moment.`
	not_indexed : { name : Str } -> Fail
	not_indexed = |facts| Fail.new(Network, "the registry did not index ${facts.name} now. Run the command again in a moment.")

	## R-AD36 (`--snapshot log:N`): kind `Usage` (exit 2). The message says that the name has no release in the log at size N. Text (proposal, TW24): `<name> has no release in the log at size <size>. A snapshot sends no ingest.`
	snapshot_stop : { name : Str, size : U64 } -> Fail
	snapshot_stop = |facts| Fail.new(Usage, "${facts.name} has no release in the log at size ${facts.size.to_str()}. A snapshot sends no ingest.")

	## R-AD35 step 4 (R-AP1 is still 404 after the ingests): kind `Network` (exit 15). The message says that the registry indexes the repository and to run the command again. Text (proposal, TW24): `the registry has no release of <name> yet. The registry is indexing the repository: run the command again in a moment.`
	still_missing : { name : Str } -> Fail
	still_missing = |facts| Fail.new(Network, "the registry has no release of ${facts.name} yet. The registry is indexing the repository: run the command again in a moment.")

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
	## Slice 225 (R-RG9): `read!` with the source of the registry setting (`""` for none). The source goes to the text of a failure with no answer.
	read! : Fx, { net : Net.Settings, roots : Roots, origin : Str, version : Str, now : U64, offline : Bool, name : Str, selector : FullName.Typed, snapshot : Try(U64, [None]), known : List(Str) } => Try([Found(WireIndex.Releases), NoMatch, SourceBuild], Fail)
	read! = |fx, facts| read_via!(fx, { net: facts.net, roots: facts.roots, origin: facts.origin, version: facts.version, now: facts.now, offline: facts.offline, name: facts.name, selector: facts.selector, snapshot: facts.snapshot, known: facts.known, source: "" })

	read_via! : Fx, { net : Net.Settings, roots : Roots, origin : Str, version : Str, now : U64, offline : Bool, name : Str, selector : FullName.Typed, snapshot : Try(U64, [None]), known : List(Str), source : Str } => Try([Found(WireIndex.Releases), NoMatch, SourceBuild], Fail)
	read_via! = |fx, facts| {
		chosen = facts.selector.map_ok(|t| t.selector)
		match FullName.way(chosen) {
			Compiler => return Err(FullName.compiler_only({ name: facts.name, text: facts.selector.map_ok(|t| t.text) ?? "" }))
			Source => return Ok(SourceBuild)
			Registry => {}
		}
		(owner, repo) = match facts.name.split_on("/") {
			[o, r] => (o, r)
			_ => return Err(Fail.new(Usage, "'${facts.name}' is not a full name owner/repo"))
		}
		PrivacyGuard.check!(fx, { net: facts.net, roots: facts.roots, sources: [Repo(facts.name)], offline: facts.offline, frozen: Bool.False })?
		path = Registry.releases_of_repo_url({ origin: facts.origin, owner, repo }).drop_prefix(facts.origin)
		first = RegistryCache.get_via!(fx, { roots: facts.roots, origin: facts.origin, version: facts.version, path, now: facts.now, offline: facts.offline, newest: Bool.False, bookmark: Err(None), source: facts.source })?
		match first {
			NoCopy => return Err(Github.no_page_failure(facts.name))
			Answer(answer) => {
				if answer.status == 200 {
					return decoded(facts, answer.body)
				}
				if answer.status != 404 {
					return Err(refused(facts, answer))
				}
			}
		}
		match facts.snapshot {
			Ok(size) => return Err(FullName.snapshot_stop({ name: facts.name, size }))
			Err(None) => {}
		}
		fetched = Github.releases!(fx, { net: facts.net, roots: facts.roots, owner, repo, now: facts.now, offline: facts.offline })?
		found = match Index.candidates({ owner, repo, pages: fetched.pages, known: facts.known }) {
			Ok(f) => f
			Err(BadPage(n)) => return Err(Fail.new(Network, "the release list of ${facts.name} (page ${n.to_str()}) is not a list of releases"))
		}
		for w in found.warnings {
			fx.err!("warning: ${w}\n")
		}
		list = FullName.select({ list: found.list, selector: chosen })
		if list.is_empty() {
			return match facts.selector {
				Ok(_) => Ok(NoMatch)
				Err(None) => Err(FullName.no_candidate({ name: facts.name }))
			}
		}
		if fx.programs!(["curl"]) != [Bool.True] {
			return Err(Fail.new(Environment, "curl is not on PATH. Talon needs curl to send the ingests at the same time."))
		}
		results = fx.http_all!({ requests: UnknownValues.ingest_requests({ origin: facts.origin, version: facts.version, urls: list.map(|c| c.url) }), limit: 4, tmp_dir: "${facts.roots.cache}/talon/tmp" })
		var $indexed = 0.U64
		var $skipped = 0.U64
		var $other = 0.U64
		var $marks = []
		for (c, result) in list.map2(results, |c, r| (c, r)) {
			body = match result {
				Ok(reply) => reply.body
				Err(_) => ""
			}
			status = match result {
				Ok(reply) => reply.status
				Err(_) => 0
			}
			match FullName.skip_warning({ name: facts.name, tag: c.tag, status, body }) {
				Ok(text) => {
					fx.err!("${text}\n")
					$skipped = $skipped + 1
				}
				Err(NotSkipped) => {
					verdict = UnknownValues.ingest_verdict({ origin: facts.origin, version: facts.version, result })?
					match verdict {
						Indexed({ bookmark }) => {
							$indexed = $indexed + 1
							match bookmark {
								Ok(mark) => {
									$marks = $marks.append(mark)
								}
								Err(None) => {}
							}
						}
						Unindexed({ what }) => {
							fx.err!("${FullName.unindexed_warning({ name: facts.name, tag: c.tag, what })}\n")
							$other = $other + 1
						}
						_ => {
							$other = $other + 1
						}
					}
				}
			}
		}
		match FullName.after_ingests({ indexed: $indexed, skipped: $skipped, other: $other }) {
			NotIndexed => Err(FullName.not_indexed({ name: facts.name }))
			NoCandidate => Err(FullName.no_candidate({ name: facts.name }))
			Ask => {
				again = RegistryCache.get_via!(fx, { roots: facts.roots, origin: facts.origin, version: facts.version, path, now: facts.now, offline: facts.offline, newest: Bool.True, bookmark: UnknownValues.largest($marks), source: facts.source })?
				match again {
					NoCopy => Err(Github.no_page_failure(facts.name))
					Answer(answer) => if answer.status == 200 {
						decoded(facts, answer.body)
					} else if answer.status == 404 {
						Err(FullName.still_missing({ name: facts.name }))
					} else {
						Err(refused(facts, answer))
					}
				}
			}
		}
	}
}

decoded = |facts, body| match WireIndex.decode_releases(body) {
	Ok(releases) => Ok(Found(releases))
	Err(BadJson(why)) => Err(Fail.new(Network, "the answer of ${facts.origin} for ${facts.name} is not a release list: ${why}"))
}

refused = |facts, answer| Registry.refuse({ origin: facts.origin, version: facts.version, method: Get, reply: { status: answer.status, body: answer.body }, retry_after: Registry.retry_after_of(answer.headers) })
