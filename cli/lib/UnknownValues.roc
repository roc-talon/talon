import records.Closure as Wire
import records.Release as WireRelease
import ClosureRequest
import Fail
import Fx
import Roots
import Ident
import JsonDoc
import PrivacyGuard
import Registry
import ClosureIndex

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
	classify = |facts| {
		var $seen = no_hashes
		var $out = no_values
		for hash in facts.unknown {
			if !$seen.contains(hash) {
				$seen = $seen.append(hash)
				match entry_of(facts.urls, hash) {
					Err(NoEntry) => {}
					Ok(entry) => {
						$out = $out.append({ hash, url: entry.url, case: case_of(facts, entry) })
					}
				}
			}
		}
		$out
	}

	## R-AP28 case 1, R-AP65 (proposal, TW24): the warning for a `Label` value, with the name and version of the URL (`Ident.of_url`), the hash of the header, and the hash of the registry when `other` is `Ok`.
	##
	## | `other` | Text |
	## | --- | --- |
	## | `Ok(h)` | `warning: <name> <version>: the registry has this release with the hash <h>, the header has <hash>. Talon does not use the registry's release for this value. Ask the author to release a new version.` |
	## | `Err(None)` | `warning: <name> <version>: the registry has this release with another hash, the header has <hash>. Talon does not use the registry's release for this value. Ask the author to release a new version.` |
	label_warning : { url : Str, hash : Str, other : Try(Str, [None]) } -> Str
	label_warning = |facts| {
		who = match Ident.of_url(facts.url) {
			Ok(ident) => "${ident.name ?? facts.url} ${ident.version}"
			Err(Foreign) => facts.url
		}
		registry = match facts.other {
			Ok(h) => "the hash ${h}"
			Err(None) => "another hash"
		}
		"warning: ${who}: the registry has this release with ${registry}, the header has ${facts.hash}. Talon does not use the registry's release for this value. Ask the author to release a new version."
	}

	## R-AP9, R-AP28 case 2, R-DA8 rule 1, R-AP45, R-AP23: the requests of the ingests, one for each URL, in the order of `urls`. Each is `Post`, `Registry`-form `<origin>/v1/releases`, the headers of `Registry.headers({ version, body: Json })` (no `Authorization`, no `Talon-Contributor`),
	## the body `{"url":"<url>"}` (the URL as JSON text), and `timeout_s` 20 (Design Q420: the value of `ClosureIndex.query_timeout_s`).
	ingest_requests : { origin : Str, version : Str, urls : List(Str) } -> List({ method : [Get, Post, Put, Delete], url : Str, headers : List((Str, Str)), body : Str, timeout_s : U64 })
	ingest_requests = |facts| facts.urls.map(
		|url| {
			method: Post,
			url: "${facts.origin}/v1/releases",
			headers: Registry.headers({ version: facts.version, body: Json }),
			body: JsonDoc.render(Obj([("url", Text(url))])),
			timeout_s: ClosureIndex.query_timeout_s,
		},
	)

	## R-AP28 case 2, R-AP65 source 2, R-AP25, R-AD35 step 3, Design Q421, Q424: what one ingest result means for its URL. `result` is the result of the request of `http_all!` (the headers are the ones of the answer).
	##
	## | Result | Verdict |
	## | --- | --- |
	## | 200 or 201 | `Ok(Indexed({ bookmark }))`: `bookmark` is the value of the header `Talon-Bookmark` (the name in any case, white space cut, an empty value is none) |
	## | 409 with the problem type `/errors/label-conflict` | `Ok(Label)` (R-AP65 source 2) |
	## | 409 with another type or no problem details, 422, any other 4xx except 429 | `Ok(Archive)` (R-AP28 case 3, no warning) |
	## | `Timeout`, `Failed(_)` | `Ok(Unindexed({ what: "no answer" }))` (Q421) |
	## | 202, 3xx, 5xx | `Ok(Unindexed({ what: "<status>" }))`, the status as text (Q421) |
	## | 429 | `Err(Registry.refuse(..))` with `retry_after` of the header `Retry-After`: kind `Network` (exit 15), the message gives the time (R-AP25, Q424) |
	ingest_verdict : { origin : Str, version : Str, result : Try({ status : U16, headers : List((Str, Str)), body : Str }, [Timeout, Failed(Str)]) } -> Try([Indexed({ bookmark : Try(Str, [None]) }), Label, Archive, Unindexed({ what : Str })], Fail)
	ingest_verdict = |facts| match facts.result {
		Err(Timeout) => Ok(Unindexed({ what: "no answer" }))
		Err(Failed(_)) => Ok(Unindexed({ what: "no answer" }))
		Ok(reply) => {
			status = reply.status
			if status == 200 or status == 201 {
				Ok(Indexed({ bookmark: bookmark_of(reply.headers) }))
			} else if status == 429 {
				Err(Registry.refuse({ origin: facts.origin, version: facts.version, method: Post, reply: { status, body: reply.body }, retry_after: Registry.retry_after_of(reply.headers) }))
			} else if status == 409 and is_label_conflict(reply.body) {
				Ok(Label)
			} else if status >= 400 and status < 500 {
				Ok(Archive)
			} else {
				Ok(Unindexed({ what: status.to_str() }))
			}
		}
	}

	## Design Q421 (proposal, TW24): the one warning of an `Unindexed` ingest: `warning: <url>: the registry did not index this release (<what>). Talon reads the archive.`
	unindexed_warning : { url : Str, what : Str } -> Str
	unindexed_warning = |facts| "warning: ${facts.url}: the registry did not index this release (${facts.what}). Talon reads the archive."

	## R-AP41 row 5, R-AP28 case 2, Design Q422: the largest of some bookmarks. None: `Err(None)`. The longer text is larger, and of two texts of one length the larger in byte order (D1 bookmarks are fixed-width lower-case hex, so this is the order of the numbers).
	largest : List(Str) -> Try(Str, [None])
	largest = |marks| match marks.first() {
		Err(_) => Err(None)
		Ok(head) => Ok(marks.fold(head, |best, m| if bigger(m, best) m else best))
	}

	## R-AP28 case 2, R-AP43 case 1 and 2, R-AP41 row 5, R-AP45, Design Q422, Q423: the headers of the second closure query: `User-Agent: tln/<version>`, `Content-Type: application/json`, `Cache-Control: no-cache`, and `Talon-Bookmark: <bookmark>` only when `bookmark` is `Ok`.
	## The order is not a contract (Q422): the tests use this one.
	again_headers : { version : Str, bookmark : Try(Str, [None]) } -> List((Str, Str))
	again_headers = |facts| {
		base = [("User-Agent", "tln/${facts.version}"), ("Content-Type", "application/json"), ("Cache-Control", "no-cache")]
		match facts.bookmark {
			Ok(mark) => base.append(("Talon-Bookmark", mark))
			Err(None) => base
		}
	}

	## R-AP28 (after the 3 cases), R-DI11 (registry), R-C9: the note of a value of case 3. In case 3 the other candidates of its group come from the registry when the answer has releases of that group, and the value stays in its domain (R-C9). When the answer has none (no row whose `group` is the group of the URL, `Ident.of_url`),
	## the entry acts as an anchor and `tln update`, `tln upgrade` and `tln outdated` print `fixed: not in the registry index` (the text of R-AP28, no host in it). `releases` are the rows of the answer that `settle!` gives.
	##
	## | `end` | Rows of the group of the URL | Result |
	## | --- | --- | --- |
	## | `Archive` | none | `Ok("fixed: not in the registry index")` |
	## | `Archive` | one or more (any version, any hash) | `Err(None)` |
	## | `Label` (Design Q425) | none | `Ok("fixed: not in the registry index")`, as `Archive` |
	## | `Label` | one or more | `Err(None)` |
	## | `Indexed` | any | `Err(None)` |
	##
	## Which command prints the note is a flow of slice 206b and slice 210.
	anchor_note : { end : UnknownValues.End, url : Str, releases : List(WireRelease.Row) } -> Try(Str, [None])
	anchor_note = |facts| match facts.end {
		Indexed => Err(None)
		Archive | Label(_) => match Ident.of_url(facts.url) {
			Err(Foreign) => Err(None)
			Ok(ident) => if facts.releases.any(|r| r.group == ident.group.form) Err(None) else Ok("fixed: not in the registry index")
		}
	}

	## R-AP28 cases 1 to 3 in order, R-AP65, R-DA8, R-AP34 (an ingest is sent once). The calls, in order (the L2 cases `registry/ap28-*` fix them):
	##
	## | Step | Call |
	## | --- | --- |
	## | 1 | `classify` on `first.unknown`, `urls`, `first.releases`, `snapshot`. The warning of each `Label` value on stderr (`label_warning`), in order, before any request. |
	## | 2 | No `Ingest` value: no more call, the result is `first`. |
	## | 3 | One `programs!(["curl"])` (Design Q229). No `curl`: `Err` of kind `Environment` (exit 18) with the text `curl is not on PATH. Talon needs curl to send the ingests at the same time.` (proposal), and no request. |
	## | 4 | One `http_all!` with `ingest_requests`, `limit` 4, `tmp_dir` `<roots.cache>/talon/tmp`. |
	## | 5 | `ingest_verdict` of each result in order. `Err` (429): the failure at once (the message has the time of `Retry-After`, Q424), no second query. `Label`: the warning (`label_warning` with `other` none) on stderr, the value ends as `Label`. `Archive`: ends as `Archive`, no warning. `Unindexed`: one `unindexed_warning` on stderr, ends as `Archive` (Q421). `Indexed`: ends as `Indexed`. |
	## | 6 | At least one `Indexed`: one more query, as `ClosureIndex.query!` (same body, the checks, `ClosureIndex.one_state`, no second try) with `again_headers` and the `largest` bookmark of the `Indexed` answers (`Err(None)` when none has one: `no-cache` only, Q423). No `Indexed`: no second query, the result is `first`. |
	## | 7 | After the second query, an `Indexed` value whose hash is still in `unknown` of that answer ends as `Archive`. No third query (Q423). |
	##
	## The result: `answer` is the answer of the second query, or `first`. `values` are the values in the order of `classify` with their end.
	settle! : Fx, { origin : Str, version : Str, roots : Roots, facts : ClosureRequest.Facts, first : Wire.Answer, urls : List(Str), snapshot : Bool } => Try({ answer : Wire.Answer, values : List({ hash : Str, url : Str, end : UnknownValues.End }) }, Fail)
	settle! = |fx, facts| {
		values = UnknownValues.classify({ unknown: facts.first.unknown, urls: facts.urls, releases: facts.first.releases, snapshot: facts.snapshot })
		for v in values {
			match v.case {
				Label({ other }) => fx.err!("${UnknownValues.label_warning({ url: v.url, hash: v.hash, other })}\n")
				_ => {}
			}
		}
		ingests = values.keep_if(|v| v.case == Ingest)
		if ingests.is_empty() {
			return Ok({ answer: facts.first, values: values.map(|v| { hash: v.hash, url: v.url, end: end_of_case(v.case) }) })
		}
		present = fx.programs!(["curl"])
		if present != [Bool.True] {
			return Err(Fail.new(Environment, "curl is not on PATH. Talon needs curl to send the ingests at the same time."))
		}
		results = fx.http_all!({ requests: UnknownValues.ingest_requests({ origin: facts.origin, version: facts.version, urls: ingests.map(|v| v.url) }), limit: 4, tmp_dir: "${facts.roots.cache}/talon/tmp" })
		var $verdicts = no_verdicts
		var $marks = no_hashes
		for (v, result) in ingests.map2(results, |v, r| (v, r)) {
			verdict = UnknownValues.ingest_verdict({ origin: facts.origin, version: facts.version, result })?
			end = match verdict {
				Indexed({ bookmark }) => {
					match bookmark {
						Ok(mark) => {
							$marks = $marks.append(mark)
						}
						Err(None) => {}
					}
					Indexed
				}
				Label => {
					fx.err!("${UnknownValues.label_warning({ url: v.url, hash: v.hash, other: Err(None) })}\n")
					Label({ other: Err(None) })
				}
				Archive => Archive
				Unindexed({ what }) => {
					fx.err!("${UnknownValues.unindexed_warning({ url: v.url, what })}\n")
					Archive
				}
			}
			$verdicts = $verdicts.append((v.hash, end))
		}
		ends = values.map(
			|v| {
				end = match v.case {
					Ingest => match $verdicts.find_first(|(h, _)| h == v.hash) {
						Ok((_, e)) => e
						Err(_) => Archive
					}
					other => end_of_case(other)
				}
				{ hash: v.hash, url: v.url, end }
			},
		)
		if !ends.any(|e| e.end == Indexed) {
			return Ok({ answer: facts.first, values: ends })
		}
		request = match ClosureRequest.request(facts.facts) {
			Ok(r) => r
			Err(NoCompiler) => return Err(Fail.new(NoTuple, "no compiler is left"))
		}
		answer = ClosureIndex.send!(fx, { origin: facts.origin, version: facts.version, request, headers: UnknownValues.again_headers({ version: facts.version, bookmark: UnknownValues.largest($marks) }) })?
		final = ends.map(|e| if e.end == Indexed and answer.unknown.contains(e.hash) { ..e, end: Archive } else e)
		Ok({ answer, values: final })
	}
}

no_hashes : List(Str)
no_hashes = []

no_values : List(UnknownValues.Value)
no_values = []

no_verdicts : List((Str, UnknownValues.End))
no_verdicts = []

end_of_case : UnknownValues.Case -> UnknownValues.End
end_of_case = |case| match case {
	Label(l) => Label(l)
	Ingest => Indexed
	Archive => Archive
}

entry_of : List(Str), Str -> Try({ url : Str, ident : Ident }, [NoEntry])
entry_of = |urls, hash| {
	found = urls.keep_oks(
		|url| match Ident.of_url(url) {
			Ok(ident) => if ident.hash == hash Ok({ url, ident }) else Err(NoEntry)
			Err(Foreign) => Err(NoEntry)
		},
	)
	match found.first() {
		Ok(e) => Ok(e)
		Err(_) => Err(NoEntry)
	}
}

case_of : { unknown : List(Str), urls : List(Str), releases : List(WireRelease.Row), snapshot : Bool }, { url : Str, ident : Ident } -> UnknownValues.Case
case_of = |facts, entry| {
	other = facts.releases.find_first(|r| r.group == entry.ident.group.form and r.version == entry.ident.version and r.hash != entry.ident.hash)
	match other {
		Ok(r) => Label({ other: Ok(r.hash) })
		Err(_) => if !facts.snapshot and is_checked_repo(entry.url) Ingest else Archive
	}
}

is_checked_repo : Str -> Bool
is_checked_repo = |url| match PrivacyGuard.repos_to_check({ sources: [Url(url)], offline: Bool.False, frozen: Bool.False }) {
	Ok(repos) => repos.len() == 1
	Err(_) => Bool.False
}

is_label_conflict : Str -> Bool
is_label_conflict = |body| match Registry.problem({ status: 409, body }) {
	Ok(p) => p.type_text == "/errors/label-conflict"
	Err(NotProblem) => Bool.False
}

# Design Q422: the longer text is larger, then the byte order.
bigger : Str, Str -> Bool
bigger = |a, b| {
	x = a.to_utf8()
	y = b.to_utf8()
	if x.len() != y.len() {
		x.len() > y.len()
	} else {
		var $result = Bool.False
		var $decided = Bool.False
		for (p, q) in x.map2(y, |p, q| (p, q)) {
			if !$decided and p != q {
				$decided = Bool.True
				$result = p > q
			}
		}
		$result
	}
}

bookmark_of : List((Str, Str)) -> Try(Str, [None])
bookmark_of = |list| match list.find_first(|(name, _)| name.with_ascii_lowercased() == "talon-bookmark") {
	Ok((_, value)) => if value.trim().is_empty() Err(None) else Ok(value.trim())
	Err(_) => Err(None)
}
