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
	fix : AuditTypes.Finding -> Str
	fix = |f| {
		ask = f.reason == AssetReplaced
		match place_of(f.entry) {
			Header(alias) => {
				if ask {
					"ask the author to release a new version, then run tln update ${alias}"
				} else if f.reason == RepoMissing and f.successor == Err(None) {
					"tln remove ${alias}, then tln add another package, or add the item to [audit] ignore"
				} else {
					"tln update ${alias}"
				}
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
		items = open.keep_if(|f| AuditReport.fails(f.reason) or f.successor != Err(None)).map(|f| "${f.entry.edge}: ${AuditReport.fix(f)}.")
		fix_lines = if items.is_empty() [] else ["fix: ${Str.join_with(items, " ")}"]
		not_checked = report.unindexed.map(|u| "note: not checked: ${u.name} ${u.version}: the registry has no release of it")
		note = if report.no_yank_data {
			match report.index {
				Direct => ["note: no yank and advisory data without a registry"]
				Registry => ["note: the registry has no yank and advisory data yet"]
			}
		} else {
			[]
		}
		lines = head.concat(rows).concat(warn_lines).concat(ignored_lines).concat(unused_lines).concat([count]).concat(fix_lines).concat(not_checked).concat(note)
		"${Str.join_with(lines, "\n")}\n"
	}

	## R-OUT4: the `data` of `--json`, and the `details` of exit 21 (R-AU5). `notes` are objects with a `kind`.
	data : AuditTypes.Report -> JsonDoc
	data = |report| {
		yank_note = if report.no_yank_data [JsonDoc.Obj([("kind", Text("no-yank-data"))])] else []
		unused = report.unused.map(|item| JsonDoc.Obj([("kind", Text("unused-ignore")), ("item", Text(item))]))
		not_indexed = report.unindexed.map(|u| JsonDoc.Obj([("kind", Text("not-indexed")), ("name", Text(u.name)), ("version", Text(u.version)), ("hash", Text(u.hash))]))
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
			("notes", Arr(yank_note.concat(unused).concat(not_indexed))),
			("findings", Arr(report.findings.map(finding_doc))),
		])
	}

	## R-AU5, R-EC21: the failure of exit 21. The message lists the items of the findings that fail and are not ignored, in the form of an ignore item.
	failure : AuditTypes.Report -> Fail
	failure = |report| {
		items = report.findings.keep_if(|f| f.ignored == Err(None) and AuditReport.fails(f.reason)).map(item_of)
		message = "findings that fail: ${Str.join_with(items, ", ")}. To accept one, add it to [audit] ignore in talon.toml"
		{ ..Fail.new(Findings, message), details: Ok(AuditReport.data(report)) }
	}
}

# Where a hash is in the project: a header entry, a transitive entry (the header aliases that need it), or a tool.
Place : [Header(Str), Via(List(Str)), Tool(Str)]

place_of : AuditTypes.Entry -> Place
place_of = |entry| match entry.alias {
	Ok(alias) => Header(alias)
	Err(None) => if entry.via.is_empty() Tool(entry.tool ?? entry.edge) else Via(entry.via)
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
		("fix", Text(AuditReport.fix(f))),
	])
}
