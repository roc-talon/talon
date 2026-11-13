import AuditTypes
import Clock
import Fail
import JsonDoc

## The words of `tln audit` (slice 244, R-AU2, R-AU3, R-AU8, R-AU10, R-AU11, R-AU5, R-OUT2): the text of a reason, the fix, the human report, the `--json` data and the failure of exit 21.
## All pure. The texts and the `data` fields are a proposal (TW24).
AuditReport :: [].{

	## The text of a reason in the ignore item and in `--json`. An unknown value is its own text.
	reason_text : AuditTypes.Reason -> Str
	reason_text = |reason| match reason {
		Yanked => "yanked"
		AssetReplaced => "asset-replaced"
		RepoMissing => "repo-missing"
		ReleaseMissing => "release-missing"
		Prerelease => "prerelease"
		Moved => "moved"
		Other(text) => text
	}

	## The column "Fails" of R-AU2. An unknown value fails (Q-244-3).
	fails : AuditTypes.Reason -> Bool
	fails = |reason| match reason {
		Yanked | AssetReplaced | RepoMissing | Other(_) => Bool.True
		ReleaseMissing | Prerelease | Moved => Bool.False
	}

	## R-AU8: the fix of a finding. A project tool: `tln update --tool <key>`. A header entry: `tln update <alias>`. A transitive entry: update each header entry that needs it.
	## Before P3 (`from_p3`, Q-244c-4) `tln update` does not follow a successor, so a successor does not change the fix, and `moved` has no fix (""): it does not fail and the old URL works.
	fix : AuditTypes.Finding -> Str
	fix = |f| {
		ask = f.reason == AssetReplaced
		follows = from_p3({}) and f.successor != Err(None)
		if f.reason == Moved and !from_p3({}) return ""
		match place_of(f.entry) {
			Header(alias) => {
				if ask {
					"ask the author to release a new version, then run tln update ${alias}"
				} else if f.reason == RepoMissing and !follows {
					"tln remove ${alias}, then tln add another package, or add the item to [audit] ignore"
				} else {
					"tln update ${alias}"
				}
			}
			Via([]) => {
				base = "update the package that needs it (tln why ${f.entry.why}), or use [overrides]"
				if ask "${base}; ask the author to release a new version" else base
			}
			Via(aliases) => {
				updates = Str.join_with(aliases.map(|a| "tln update ${a}"), " or ")
				base = "${updates} (tln why ${f.entry.why}), or use [overrides]"
				if ask "${base}; ask the author to release a new version" else base
			}
			Tool(key) => "tln update --tool ${key}"
		}
	}

	## The human report (R-AU3, R-AU4, R-AU10, R-AU11). Line 1, the findings that fail (an aligned table), the warnings, `ignored:` and `unused ignore:`, the count line, the `fix:` line, the note of R-AU4.
	text : AuditTypes.Report -> Str
	text = |report| {
		open = report.findings.keep_if(|f| f.ignored == Err(None))
		failing = open.keep_if(|f| AuditReport.fails(f.reason))
		warnings = open.keep_if(|f| !AuditReport.fails(f.reason))
		ignored = report.findings.keep_if(|f| f.ignored != Err(None))
		index_word = match report.index {
			Registry => "registry"
			Direct => "direct"
		}
		head = ["audit: ${report.checked.to_str()} packages checked (${index_word})"]
		rows = table(failing.map(row_cells))
		warn_lines = warnings.map(warning_line)
		ignored_lines = ignored.keep_oks(|f| f.ignored.map_ok(|item| "ignored: ${item}"))
		unused_lines = report.unused.map(|item| "unused ignore: ${item}")
		count = "${plural(failing.len(), "finding")}, ${plural(warnings.len(), "warning")}, ${ignored.len().to_str()} ignored."
		items = open.keep_if(|f| AuditReport.fails(f.reason) or (from_p3({}) and f.successor != Err(None))).keep_if(|f| AuditReport.fix(f) != "").map(|f| "${f.entry.edge}: ${AuditReport.fix(f)}.")
		fix_lines = if items.is_empty() [] else ["fix: ${Str.join_with(items, " ")}"]
		why_not = match report.index {
			Registry => "the registry has no release of it"
			Direct => "no index without a registry"
		}
		not_checked = report.unindexed.map(|u| "note: not checked: ${u.name} ${u.version}: ${why_not}")
		gone_lines = report.gone.map(|g| "note: not checked: the deps of ${g.name} ${g.version}: its archive is gone")
		note = if report.no_yank_data {
			match report.index {
				Direct => ["note: no yank and advisory data without a registry"]
				Registry => ["note: the registry has no yank and advisory data yet"]
			}
		} else {
			[]
		}
		lines = head.concat(rows).concat(warn_lines).concat(ignored_lines).concat(unused_lines).concat([count]).concat(fix_lines).concat(not_checked).concat(gone_lines).concat(note)
		"${Str.join_with(lines, "\n")}\n"
	}

	## R-OUT4: the `data` of `--json`, and the `details` of exit 21 (R-AU5). `notes` are objects with a `kind`.
	data : AuditTypes.Report -> JsonDoc
	data = |report| {
		yank_note = if report.no_yank_data [JsonDoc.Obj([("kind", Text("no-yank-data"))])] else []
		unused = report.unused.map(|item| JsonDoc.Obj([("kind", Text("unused-ignore")), ("item", Text(item))]))
		not_indexed = report.unindexed.map(|u| JsonDoc.Obj([("kind", Text("not-indexed")), ("name", Text(u.name)), ("version", Text(u.version)), ("hash", Text(u.hash))]))
		deps_gone = report.gone.map(|g| JsonDoc.Obj([("kind", Text("deps-not-checked")), ("name", Text(g.name)), ("version", Text(g.version)), ("hash", Text(g.hash))]))
		JsonDoc.Obj([
			(
				"index",
				Text(
					match report.index {
						Registry => "registry"
						Direct => "direct"
					},
				),
			),
			("checked", Num(report.checked.to_i64_wrap())),
			("notes", Arr(yank_note.concat(unused).concat(not_indexed).concat(deps_gone))),
			("findings", Arr(report.findings.map(finding_doc))),
		])
	}

	## Slice 244c (R-AU7, R-AU8, R-AU14, Q-244c-4): the text of one warning of a resolve, with no `warning: ` prefix. `<head>: <name> <version> <state>. Fix: <fix>.` The head is the alias, or `<edge> via <aliases>`.
	## `moved` of a header entry with a successor is the line of R-PU28: `<alias>: moved to <successor>` (from P3 `. Run: tln update <alias>` is added). `moved` has no fix before P3: no `Fix:` part.
	resolve_line : AuditTypes.Finding -> Str
	resolve_line = |f| {
		e = f.entry
		head = match place_of(e) {
			Header(alias) => alias
			Via(aliases) => if aliases.is_empty() e.edge else "${e.edge} via ${Str.join_with(aliases, ", ")}"
			Tool(key) => key
		}
		fixed = AuditReport.fix(f)
		match (f.reason, place_of(e), f.successor, from_p3({})) {
			(Moved, Header(alias), Ok(to), Bool.True) => "${alias}: moved to ${to}. Run: tln update ${alias}"
			(Moved, Header(alias), Ok(to), Bool.False) => "${alias}: moved to ${to}"
			_ => "${head}: ${e.name} ${e.version} ${state_text(f)}.${if fixed == "" "" else " Fix: ${fixed}."}"
		}
	}

	## R-OUT4, R-J6 (TW24): one element of `data.audit_warnings`.
	resolve_doc : AuditTypes.Finding -> JsonDoc
	resolve_doc = |f| {
		e = f.entry
		opt = |t| match t {
			Ok(s) => JsonDoc.Text(s)
			Err(None) => JsonDoc.Null
		}
		JsonDoc.Obj([
			("name", Text(e.name)),
			("group", Text(e.group)),
			("version", Text(e.version)),
			("hash", Text(e.hash)),
			("alias", opt(e.alias)),
			("via", Arr(e.via.map(|v| JsonDoc.Text(v)))),
			("reason", Text(AuditReport.reason_text(f.reason))),
			("successor", opt(f.successor)),
			("text", Text(AuditReport.resolve_line(f))),
		])
	}

	## R-FE10, R-FE6, R-AU6 (TW24): the failure of a download. A 404 with a finding of the reason `asset-replaced`, `repo-missing` or `release-missing` gives the state and the fix as a sentence. Any other case: the text of `Fetch.download_failed`.
	download_failed : { what : Str, status : U16, url : Str, index : [Registry, Direct], finding : Try(AuditTypes.Finding, [None]) } -> Fail
	download_failed = |facts| {
		head = "download of ${facts.what} failed: ${facts.status.to_str()} (${facts.url})."
		plain = Fail.new(Network, "${head} Run tln audit to see why.")
		source = match facts.index {
			Registry => "The registry"
			Direct => "GitHub"
		}
		match facts.finding {
			Ok(f) if facts.status == 404 => {
				state = match f.reason {
					AssetReplaced => Ok("the asset was replaced")
					RepoMissing => Ok("the repository is deleted or private")
					ReleaseMissing => Ok("the release was deleted")
					_ => Err(None)
				}
				match state {
					Ok(said) => Fail.new(Network, "${head} ${source} says: ${said}. ${sentence(AuditReport.fix(f))}.")
					Err(None) => plain
				}
			}
			_ => plain
		}
	}

	## R-AU5, R-EC21: the failure of exit 21. The message lists the items of the findings that fail and are not ignored, in the form of an ignore item.
	failure : AuditTypes.Report -> Fail
	failure = |report| {
		items = report.findings.keep_if(|f| f.ignored == Err(None) and AuditReport.fails(f.reason)).map(item_of)
		message = "findings that fail: ${Str.join_with(items, ", ")}. To accept one, add it to [audit] ignore in talon.toml"
		{ ..Fail.new(Findings, message), details: Ok(AuditReport.data(report)) }
	}
}

# The phase constant of Design Q620 item 1: false in a P2 `tln` (no yank data, `tln update` does not follow a successor). The P3 release sets it.
from_p3 : {} -> Bool
from_p3 = |_| Bool.False

# Where a hash is in the project: a header entry, a transitive entry (the header aliases that need it), or a tool.
Place : [Header(Str), Via(List(Str)), Tool(Str)]

place_of : AuditTypes.Entry -> Place
place_of = |entry| match entry.alias {
	Ok(alias) => Header(alias)
	Err(None) => match entry.tool {
		Ok(key) if entry.via.is_empty() => Tool(key)
		_ => Via(entry.via)
	}
}

place_text : AuditTypes.Entry -> Str
place_text = |entry| match place_of(entry) {
	Header(alias) => "header: ${alias}"
	Via(aliases) => "via ${Str.join_with(aliases, ", ")}"
	Tool(key) => "tool: ${key}"
}

words : AuditTypes.Reason -> Str
words = |reason| match reason {
	Other(text) => text
	_ => AuditReport.reason_text(reason).replace_each("-", " ")
}

plural : U64, Str -> Str
plural = |n, word| if n == 1 "1 ${word}" else "${n.to_str()} ${word}s"

item_of : AuditTypes.Finding -> Str
item_of = |f| "${f.entry.name}@${f.entry.version}:${AuditReport.reason_text(f.reason)}"

# The first 6 characters of a hash.
short : Str -> Str
short = |hash| Str.from_utf8_lossy(hash.to_utf8().take_first(6))

detail_of : AuditTypes.Finding -> Str
detail_of = |f| match f.reason {
	Yanked => match f.yank_reason {
		Ok(text) => "\"${text}\""
		Err(None) => "no reason given"
	}
	AssetReplaced => match f.new_hash {
		Ok(new) => "GitHub has ${short(new)}..., the header has ${short(f.entry.hash)}..."
		Err(None) => "the asset of the header is gone"
	}
	RepoMissing => "the repository is deleted or private"
	Other(text) => "withdrawn: ${text}"
	_ => ""
}

row_cells : AuditTypes.Finding -> List(Str)
row_cells = |f| [words(f.reason), "${f.entry.edge} ${f.entry.version}", f.entry.name, detail_of(f), place_text(f.entry)]

warning_line : AuditTypes.Finding -> Str
warning_line = |f| {
	successor = match f.successor {
		Ok(name) => ["successor: ${name}"]
		Err(None) => []
	}
	cells = [words(f.reason), "${f.entry.edge} ${f.entry.version}", f.entry.name].concat(successor).append(place_text(f.entry))
	"warning: ${Str.join_with(cells, "  ")}"
}

# Each column is as wide as its longest cell and 2 spaces. The last column is not padded.
table : List(List(Str)) -> List(Str)
table = |rows| {
	widths = [0, 1, 2, 3].map(|i| rows.fold(0, |w, r| U64.max(w, (r.get(i) ?? "").count_utf8_bytes())))
	rows.map(
		|r| {
			padded = widths.map_with_index(
				|w, i| {
					cell = r.get(i) ?? ""
					"${cell}${Str.repeat(" ", w - cell.count_utf8_bytes())}"
				},
			)
			"${Str.join_with(padded, "  ")}  ${r.get(4) ?? ""}"
		},
	)
}

finding_doc : AuditTypes.Finding -> JsonDoc
finding_doc = |f| {
	e = f.entry
	text_or_null = |t| match t {
		Ok(s) => JsonDoc.Text(s)
		Err(None) => JsonDoc.Null
	}
	since = match f.since {
		Ok(ms) => JsonDoc.Text(Clock.format_utc(ms // 1000))
		Err(None) => JsonDoc.Null
	}
	yank = if f.reason == Yanked JsonDoc.Obj([("reason", text_or_null(f.yank_reason))]) else JsonDoc.Null
	JsonDoc.Obj([
		("name", Text(e.name)),
		("group", Text(e.group)),
		("version", Text(e.version)),
		("hash", Text(e.hash)),
		("alias", text_or_null(e.alias)),
		("via", Arr(e.via.map(|v| JsonDoc.Text(v)))),
		("tool", text_or_null(e.tool)),
		("members", Arr(e.members.map(|m| JsonDoc.Text(m)))),
		("reason", Text(AuditReport.reason_text(f.reason))),
		("fails", Flag(AuditReport.fails(f.reason))),
		("ignored", Flag(f.ignored != Err(None))),
		("since", since),
		("yank", yank),
		("new_hash", text_or_null(f.new_hash)),
		("successor", text_or_null(f.successor)),
		("fix", if AuditReport.fix(f) == "" JsonDoc.Null else JsonDoc.Text(AuditReport.fix(f))),
	])
}

# The state of a finding in a warning line.
state_text : AuditTypes.Finding -> Str
state_text = |f| match f.reason {
	Yanked => match f.yank_reason {
		Ok(text) => "is yanked (\"${text}\")"
		Err(None) => "is yanked (no reason given)"
	}
	AssetReplaced => "has a replaced asset (the asset of the header is gone)"
	RepoMissing => "is in a deleted or private repository"
	ReleaseMissing => "has a deleted release"
	Prerelease => "is a prerelease"
	Other(text) => "is withdrawn (${text})"
	Moved => match f.successor {
		Ok(to) => "is in a repository that moved to ${to}"
		Err(None) => "is in a repository that moved"
	}
}

# A fix as a sentence: `tln ...` gets `Run `, else the first letter is a capital.
sentence : Str -> Str
sentence = |fix| if fix.starts_with("tln ") {
	"Run ${fix}"
} else {
	match fix.to_utf8() {
		[first, .. as rest] => Str.from_utf8_lossy([if first >= 'a' and first <= 'z' first - 32 else first].concat(rest))
		[] => fix
	}
}
