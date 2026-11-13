import records.Closure as Wire
import records.Release as WireRelease
import Args
import AuditDirect
import AuditReport
import AuditTypes
import Closure
import Fail
import Ident
import JsonDoc
import Opts
import TomlKeys
import toml.Toml
import toml.Value

## The decisions of `tln audit` (slice 244a, R-CM14, R-AU1 to R-AU3, R-AU8 to R-AU13, R-AU15, R-PT8). Part A: pure, tested by `tests/unit/AuditcheckTest.roc`.
## The command code is `AuditFlow`. The words (text, `--json`, fix) are in `AuditReport`; the types are in `AuditTypes`.
##
## | Step | Function | Rule |
## | --- | --- | --- |
## | 1 | `entries`: the hashes to check, one entry for each hash | R-AU1, R-AU15, R-PT8 |
## | 2 | `state_of`: the release row and the `repos` item of an entry | R-AU1, R-AP17 |
## | 3 | `reason_of`, `finding`, `of_answer`: the first reason in the order of R-AU13 | R-AU2, R-AU13 |
## | 4 | `read`, `toml_items`, `parse_item`, `ignore`: the ignore items | R-AU9 to R-AU12 |
## | 5 | `code`: exit 21 or 0 | R-AU3 |
AuditCheck :: [].{

	Reason : AuditTypes.Reason

	Entry : AuditTypes.Entry

	Finding : AuditTypes.Finding

	Report : AuditTypes.Report

	repos_of : List(AuditTypes.Entry) -> List({ owner : Str, repo : Str })
	repos_of = AuditDirect.repos_of

	direct_finding : { entry : AuditTypes.Entry, list : AuditDirect.Fetched } -> Try(AuditTypes.Finding, [None, BadPage(U64)])
	direct_finding = AuditDirect.direct_finding

	of_lists : { entries : List(AuditTypes.Entry), lists : List({ owner : Str, repo : Str, list : AuditDirect.Fetched }) } -> Try({ checked : U64, findings : List(AuditTypes.Finding), unindexed : List(AuditTypes.Entry) }, Fail)
	of_lists = AuditDirect.of_lists

	## Design Q620 item 9: `of_answer` for a run where the privacy guard refused some repositories (`refused`: `owner/repo`, lower case). An entry of a refused repository is a `repo-missing` finding (counted, never `unindexed`), in the order of the entries.
	of_guarded : { answer : Wire.Answer, entries : List(AuditTypes.Entry), refused : List(Str) } -> { checked : U64, findings : List(AuditTypes.Finding), unindexed : List(AuditTypes.Entry) }
	of_guarded = |facts| facts.entries.fold(
		{ checked: 0, findings: [], unindexed: [] },
		|acc, entry| {
			gone = match AuditDirect.repo_of(entry.url) {
				Ok(r) => facts.refused.contains("${r.owner}/${r.repo}")
				Err(None) => Bool.False
			}
			if gone {
				missing = { entry, reason: RepoMissing, ignored: Err(None), since: Err(None), yank_reason: Err(None), new_hash: Err(None), successor: Err(None) }
				{ ..acc, checked: acc.checked + 1, findings: acc.findings.append(missing) }
			} else {
				one = AuditCheck.of_answer({ answer: facts.answer, entries: [entry] })
				{ checked: acc.checked + one.checked, findings: acc.findings.concat(one.findings), unindexed: acc.unindexed.concat(one.unindexed) }
			}
		},
	)

	resolve_line : AuditTypes.Finding -> Str
	resolve_line = AuditReport.resolve_line

	resolve_doc : AuditTypes.Finding -> JsonDoc
	resolve_doc = AuditReport.resolve_doc

	download_failed : { what : Str, status : U16, url : Str, index : [Registry, Direct], finding : Try(AuditTypes.Finding, [None]) } -> Fail
	download_failed = AuditReport.download_failed

	## R-AU7 (Q-244c-2, Q-244c-3): the findings of a resolve with a registry, in the order of the entries. The first answer of `answers` that has the release row of an entry gives its state. An entry with no row gives nothing.
	## An ignored finding is dropped. An item that does not parse is skipped.
	resolve_findings : { answers : List(Wire.Answer), entries : List(AuditTypes.Entry), items : List(Str) } -> List(AuditTypes.Finding)
	resolve_findings = |facts| {
		found = facts.entries.keep_oks(
			|entry| match facts.answers.keep_oks(|answer| AuditCheck.state_of({ answer, entry })).first() {
				Ok(s) => AuditCheck.finding({ entry, row: s.row, repo: s.repo })
				Err(_) => Err(None)
			},
		)
		AuditCheck.ignore({ findings: found, items: facts.items }).findings.keep_if(|f| f.ignored == Err(None))
	}

	## R-AU7, R-DI15 (Q-244c-5): the findings of a resolve with `direct`, from the release lists that it read. `asset-replaced` with a new hash gives nothing: `Index.candidates` printed the R-DI15 warning already.
	resolve_direct : { lists : List({ owner : Str, repo : Str, list : AuditDirect.Fetched }), entries : List(AuditTypes.Entry), items : List(Str) } -> List(AuditTypes.Finding)
	resolve_direct = |facts| {
		found = facts.entries.keep_oks(
			|entry| {
				listed = AuditDirect.repo_of(entry.url)?
				l = facts.lists.find_first(|x| x.owner == listed.owner and x.repo == listed.repo).map_err(|_| None)?
				f = AuditDirect.direct_finding({ entry, list: l.list }).map_err(|_| None)?
				if f.new_hash != Err(None) Err(None) else Ok(f)
			},
		)
		AuditCheck.ignore({ findings: found, items: facts.items }).findings.keep_if(|f| f.ignored == Err(None))
	}

	reason_text : AuditTypes.Reason -> Str
	reason_text = AuditReport.reason_text

	fails : AuditTypes.Reason -> Bool
	fails = AuditReport.fails

	fix : AuditTypes.Finding -> Str
	fix = AuditReport.fix

	text : AuditTypes.Report -> Str
	text = AuditReport.text

	data : AuditTypes.Report -> JsonDoc
	data = AuditReport.data

	failure : AuditTypes.Report -> Fail
	failure = AuditReport.failure

	## R-AU1, R-AU15, R-PT8: the hashes to check. First each `Release` row of each member, in the order of the walk (a path and a foreign row have no hash). One hash that more than one member has is one entry (Q-244-5).
	## Then the hash of the URL of each project tool, in the order of `tools`. A tool URL that is a closure hash only sets `tool` of its entry. A URL with no hash is left out.
	entries : { members : List({ file : Str, walked : Closure.Walked }), tools : List({ key : Str, url : Str }) } -> List(AuditTypes.Entry)
	entries = |facts| {
		var $found = []
		for m in facts.members {
			for r in m.walked.rows {
				if r.kind == Release {
					match Ident.of_url(r.id) {
						Ok(ident) => {
							$found = $found.append({ hash: ident.hash, file: m.file, row: r, walked: m.walked })
						}
						Err(Foreign) => {}
					}
				}
			}
		}
		hashes = $found.fold([], |acc, f| if acc.contains(f.hash) acc else acc.append(f.hash))
		closure = hashes.map(|hash| closure_entry(hash, $found.keep_if(|f| f.hash == hash)))
		tool_rows = facts.tools.keep_oks(|t| Ident.of_url(t.url).map_ok(|ident| { key: t.key, url: t.url, ident }))
		var $tooled = closure.map(|e| { ..e, tool: tool_rows.find_first(|t| t.ident.hash == e.hash).map_ok(|t| t.key).map_err(|_| None) })
		var $seen = hashes
		for t in tool_rows {
			if !$seen.contains(t.ident.hash) {
				$seen = $seen.append(t.ident.hash)
				name = t.ident.name ?? t.ident.group.form.replace_each("{v}", t.ident.version).drop_suffix("/")
				$tooled = $tooled.append({ url: t.url, name, group: t.ident.group.form, version: t.ident.version, hash: t.ident.hash, alias: Err(None), edge: t.key, via: [], tool: Ok(t.key), members: [], why: name })
			}
		}
		with_series(facts, $tooled)
	}

	## R-AU1, R-AP17, R-AP32: the release row of an entry is the row with its hash, its group (the URL form) and its version. Its `repos` item is the item whose `name` is the `repo` of the row (any case).
	state_of : { answer : Wire.Answer, entry : AuditTypes.Entry } -> Try({ row : WireRelease.Row, repo : Try(Wire.Repo, [None]) }, [NotIndexed])
	state_of = |facts| {
		e = facts.entry
		match facts.answer.releases.find_first(|r| r.hash == e.hash and r.group == e.group and r.version == e.version) {
			Err(_) => Err(NotIndexed)
			Ok(row) => {
				repo = match row.repo {
					Ok(name) => facts.answer.repos.find_first(|p| p.name.with_ascii_lowercased() == name.with_ascii_lowercased()).map_err(|_| None)
					Err(None) => Err(None)
				}
				Ok({ row, repo })
			}
		}
	}

	## R-AU2, R-AU13: the first reason in the order `yanked`, `asset-replaced`, `repo-missing`, an unknown `withdrawn` value (Q-244-3), `release-missing`, `prerelease`, `moved`.
	reason_of : { row : WireRelease.Row, repo : Try(Wire.Repo, [None]) } -> Try(AuditTypes.Reason, [None])
	reason_of = |facts| {
		withdrawn = facts.row.withdrawn
		state = facts.repo.map_ok(|p| p.state)
		if facts.row.yanked {
			Ok(Yanked)
		} else if withdrawn == Ok("asset-replaced") {
			Ok(AssetReplaced)
		} else if withdrawn == Ok("repo-missing") or state == Ok(Missing) {
			Ok(RepoMissing)
		} else {
			match withdrawn {
				Ok("deleted") | Ok("unpublished") => Ok(ReleaseMissing)
				Ok("prereleased") | Ok("edited") => Ok(Prerelease)
				Ok(other) => Ok(Other(other))
				Err(None) => if state == Ok(Moved) Ok(Moved) else Err(None)
			}
		}
	}

	## R-AU2, R-AU13: the finding of a release row, or none. `since` is the `state_at` of the `repos` item for `repo-missing` and `moved` (the answer has no time of a yank or a withdraw). `new_hash` is none with a registry.
	finding : { entry : AuditTypes.Entry, row : WireRelease.Row, repo : Try(Wire.Repo, [None]) } -> Try(AuditTypes.Finding, [None])
	finding = |facts| {
		reason = AuditCheck.reason_of({ row: facts.row, repo: facts.repo })?
		since = match (reason, facts.repo) {
			(RepoMissing, Ok(p)) if p.state == Missing => Ok(p.state_at)
			(Moved, Ok(p)) => Ok(p.state_at)
			_ => Err(None)
		}
		Ok({
			entry: facts.entry,
			reason,
			ignored: Err(None),
			since,
			yank_reason: if reason == Yanked facts.row.yank_reason else Err(None),
			new_hash: Err(None),
			successor: facts.repo.map_ok(|p| p.successor) ?? Err(None),
		})
	}

	## R-AU1, Q-244-4: the findings of a closure answer, in the order of the entries. An entry with no release in the answer is in `unindexed`, is not counted and gives no finding.
	of_answer : { answer : Wire.Answer, entries : List(AuditTypes.Entry) } -> { checked : U64, findings : List(AuditTypes.Finding), unindexed : List(AuditTypes.Entry) }
	of_answer = |facts| facts.entries.fold(
		{ checked: 0, findings: [], unindexed: [] },
		|acc, entry| match AuditCheck.state_of({ answer: facts.answer, entry }) {
			Err(NotIndexed) => { ..acc, unindexed: acc.unindexed.append(entry) }
			Ok(state) => match AuditCheck.finding({ entry, row: state.row, repo: state.repo }) {
				Ok(f) => { ..acc, checked: acc.checked + 1, findings: acc.findings.append(f) }
				Err(None) => { ..acc, checked: acc.checked + 1 }
			}
		},
	)

	## R-AU9, R-AU12, Q-244-3: an item is `<full name>@<version>:<reason>`. The name has a `/` and no empty part. The version is `X.Y.Z`. The reason is `a-z`, `0-9` and `-`, and starts with a letter. The name is kept as written.
	parse_item : Str -> Try({ name : Str, version : Str, reason : Str }, [BadItem])
	parse_item = |item| {
		{ before: name, after: rest } = item.split_first("@").map_err(|_| BadItem)?
		{ before: version, after: reason } = rest.split_first(":").map_err(|_| BadItem)?
		parts = name.split_on("/")
		name_ok = parts.len() >= 2 and parts.all(|p| !p.is_empty() and p.to_utf8().all(|b| b > 32 and b < 127 and b != '@' and b != ':'))
		numbers = version.split_on(".")
		version_ok = numbers.len() == 3 and numbers.all(|n| !n.is_empty() and n.to_utf8().all(|b| b >= '0' and b <= '9'))
		reason_ok = match reason.to_utf8() {
			[first, .. as tail] => is_lower(first) and tail.all(|b| is_lower(b) or (b >= '0' and b <= '9') or b == '-')
			[] => Bool.False
		}
		if name_ok and version_ok and reason_ok Ok({ name, version, reason }) else Err(BadItem)
	}

	## R-CM14, R-AU12: the line of `tln audit`. No operand. The `--ignore` items in the order of the line; an item that does not parse is exit 2. The flags of `Opts.read` are checked first.
	read : Args -> Try({ items : List(Str) }, Fail)
	read = |args| {
		_ = Opts.read(args)?
		if !args.operands.is_empty() return Err(Fail.new(Usage, "tln audit takes no operand"))
		items = args.options.keep_oks(|(name, value)| if name == "--ignore" value.map_err(|_| None) else Err(None))
		for item in items {
			if AuditCheck.parse_item(item).is_err() {
				return Err(Fail.new(Usage, "--ignore: ${not_item(item)}"))
			}
		}
		Ok({ items: items })
	}

	## R-AU9, R-AU12, Q-244-6: the items of the key `ignore` of `[audit]` in the root talon.toml. No table or no key: no item. Not a list of strings, or an item that does not parse: exit 19, with the path and the line of the key.
	toml_items : { path : Str, text : Str } -> Try(List(Str), Fail)
	toml_items = |facts| match Toml.parse(facts.text) {
		Err(TomlErr(e)) => Err(Fail.new(Input, "${facts.path}:${e.line.to_str()}: not valid TOML"))
		Ok(doc) => match Toml.get(doc, ["audit", "ignore"]) {
			Err(NotFound) => Ok([])
			Ok(found) => {
				line = TomlKeys.key_line(doc, ["audit", "ignore"]).to_str()
				bad = |why| Err(Fail.new(Input, "${facts.path}:${line}: audit.ignore: ${why}"))
				match found {
					Value.Array(values) => {
						items = values.map_try(
							|v| match v {
								Value.String(s) => Ok(s)
								_ => Err(NotList)
							},
						)
						match items {
							Err(NotList) => bad("must be a list of strings")
							Ok(list) => match list.find_first(|i| AuditCheck.parse_item(i).is_err()) {
								Ok(item) => bad(not_item(item))
								Err(_) => Ok(list)
							}
						}
					}
					_ => bad("must be a list of strings")
				}
			}
		}
	}

	## R-AU9 to R-AU11: an item ignores the findings with the same full name (any case, R-AP56), version and reason. The finding keeps the item as written. `unused` are the items that match no finding, once each, in the order of the items.
	ignore : { findings : List(AuditTypes.Finding), items : List(Str) } -> { findings : List(AuditTypes.Finding), unused : List(Str) }
	ignore = |facts| {
		items = facts.items.fold([], |acc, i| if acc.contains(i) acc else acc.append(i))
		parsed = items.map(|i| (i, AuditCheck.parse_item(i)))
		matches = |f, p| p.name.with_ascii_lowercased() == f.entry.name.with_ascii_lowercased() and p.version == f.entry.version and p.reason == AuditReport.reason_text(f.reason)
		item_for = |f| parsed.find_first(
			|(_, p)| match p {
				Ok(x) => matches(f, x)
				Err(_) => Bool.False
			},
		)
		findings = facts.findings.map(
			|f| match item_for(f) {
				Ok((item, _)) => { ..f, ignored: Ok(item) }
				Err(_) => f
			},
		)
		used = findings.keep_oks(|f| f.ignored)
		{ findings, unused: items.keep_if(|i| !used.contains(i)) }
	}

	## R-AU3, R-AU10, R-EC21: exit code 21 when a finding that is not ignored fails, else 0.
	code : List(AuditTypes.Finding) -> I32
	code = |findings| if findings.any(|f| f.ignored == Err(None) and AuditReport.fails(f.reason)) 21 else 0
}

not_item : Str -> Str
not_item = |item| "'${item}' is not <full name>@<version>:<reason>, for example roc-lang/json@2.1.0:yanked"

is_lower : U8 -> Bool
is_lower = |b| b >= 'a' and b <= 'z'

# One entry of a hash that the rows `rows` (one for each member that has it) name.
closure_entry = |hash, rows| {
	first = rows.first().map_err(|_| crash "no row")
	direct = rows.find_first(|f| f.row.direct)
	row = match (direct, first) {
		(Ok(d), _) => d.row
		(Err(_), Ok(f)) => f.row
		(Err(_), Err(_)) => crash "no row"
	}
	members = rows.fold([], |acc, f| if acc.contains(f.file) acc else acc.append(f.file))
	via = rows.fold([], |acc, f| if f.row.direct acc else header_aliases(f.walked, f.row.id).fold(acc, |a, x| if a.contains(x) a else a.append(x)))
	{
		url: row.id,
		name: row.name,
		group: row.form,
		version: row.version,
		hash,
		alias: if row.direct Ok(row.alias) else Err(None),
		edge: row.alias,
		via,
		tool: Err(None),
		members,
		why: row.name,
	}
}

# The aliases of the header entries whose paths reach the row `target`, in the order of the header links.
header_aliases : Closure.Walked, Str -> List(Str)
header_aliases = |walked, target| walked.links
	.keep_if(|l| l.from == Err(Header) and (l.to == target or reaches(walked, l.to, target, [l.to])))
	.map(|l| l.alias)
	.fold([], |acc, a| if acc.contains(a) acc else acc.append(a))

reaches : Closure.Walked, Str, Str, List(Str) -> Bool
reaches = |walked, from, target, seen| walked.links.keep_if(|l| l.from == Ok(from)).any(
	|l| l.to == target or (!seen.contains(l.to) and reaches(walked, l.to, target, seen.append(l.to))),
)

# R-SC15: when the checked hashes have 2 or more series of one full name, `why` adds the series (`acme/http@1`).
with_series : { members : List({ file : Str, walked : Closure.Walked }), tools : List({ key : Str, url : Str }) }, List(AuditTypes.Entry) -> List(AuditTypes.Entry)
with_series = |facts, list| {
	series_of = |e| {
		from_rows = facts.members.join_map(|m| m.walked.rows).find_first(|r| r.id == e.url).map_ok(|r| r.series)
		match from_rows {
			Ok(s) => s
			Err(_) => Ident.of_url(e.url).map_ok(|i| i.series) ?? ""
		}
	}
	names = list.map(|e| (e.name, series_of(e)))
	list.map(
		|e| {
			many = names.keep_if(|(n, s)| n == e.name and s != series_of(e)).len() > 0
			if many { ..e, why: "${e.name}@${series_of(e)}" } else e
		},
	)
}
