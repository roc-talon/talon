import Args
import Closure
import Fail
import JsonDoc
import Opts

## The output of `tln list` (R-CM9, slice 010). Part A (pure). The texts and the `data` fields are a proposal (R-OUT2, TW24): the human accepts or changes them at the review.
##
## The marks of R-CM9 and the text of a row of `Closure.Walked`:
##
## | Mark | When |
## | --- | --- |
## | `direct` | The row is a header entry (`Row.direct`) |
## | `via <alias>` | The row is not direct (`Row.via`). Only in the flat list. |
## | `raised from <version>` | `Row.raised` (question Q9: `Ok(lowest named version)`) |
## | `foreign` | `Row.kind` is `Path` or `Foreign` (R-H4) |
## | `patched` | Slice 042 (R-CM9, R-PA12): the row is a header entry (`Row.direct`) whose alias is in `patched` (the aliases of the `[patch]` table of the `talon.toml` of the member). It is the last mark, after `foreign`. |
##
## `patched` is a fact of the member: the keys of its `[patch]` table (`Intent.patches`). A row is patched when it is direct and its alias is in the list. An alias that no row has is no mark. A package of a header that is not the project header is never patched (R-SC1: its alias is not a name of the project).
##
## The label of a row is `<name> <version>` for a `Release`, else the `name` (the value as written).
##
## The flat list of one member, `text`. A line has 2 spaces, the alias, 2 spaces or more (the aliases are padded to the longest alias, and 2 more), the label (padded to the longest label, and 2 more), and the marks
## in the order above, joined by `; `. The first line is the project file. Each line ends with a line end. A closure with no row is the file line only.
##
## ```text
## /p/main.roc
##   pf     acme/pfx 0.1.1       direct
##   json   acme/json 2.1.0      direct; raised from 2.0.0
##   util   ../util/main.roc     direct; foreign
##   ext    https://x.org/e.zst  direct; foreign
##   lex    acme/lex 1.0.0       via json
##   inner  ./in/main.roc        via util; foreign
## ```
##
## The tree of one member, `tree` (`--tree`). The first line is the project file. Then one line for each link of `Walked.links`, depth first, in the order of the links: the links with `from` = `Err(Header)` are the
## top level, the links with `from` = `Ok(id)` are the children of the row `id`, 2 more spaces for each level. A line is `<indent><alias>: <label>` and then ` (<marks>)` when there is a mark. The marks of the first
## line of a row: `direct`, `raised from <version>`, `foreign`, joined by `; ` (no `via`). A row that an earlier line of the output has shows ` (shown above)` in place of the marks, and has no children.
Listing :: [].{

	## The options of `tln list` (R-CM9, R-FL5, question Q6 style of slice 009): `Opts.read` of the line (its failures: the texts of `Opts.read`), then:
	##
	## | Case | Failure (kind `Usage`, exit 2) |
	## | --- | --- |
	## | One name or more | `tln list takes no name` |
	read : Args -> Try({ tree : Bool }, Fail)
	read = |args| {
		_ = Opts.read(args)?
		if !args.operands.is_empty() {
			return Err(Fail.new(Usage, "tln list takes no name"))
		}
		Ok({ tree: args.options.any(|(name, _)| name == "--tree") })
	}

	## The flat list of one member (the table above).
	text : { file : Str, walked : Closure.Walked, patched : List(Str) } -> Str
	text = |facts| {
		rows = facts.walked.rows
		alias_width = rows.map(|r| r.alias.count_utf8_bytes()).max() ?? 0
		label_width = rows.map(|r| label_of(r).count_utf8_bytes()).max() ?? 0
		lines = rows.map(
			|r| {
				alias = r.alias.concat(" ".repeat(alias_width + 2 - r.alias.count_utf8_bytes()))
				label = label_of(r).concat(" ".repeat(label_width + 2 - label_of(r).count_utf8_bytes()))
				"  ${alias}${label}${Str.join_with(marks_of(r, Bool.True, facts.patched), "; ")}\n"
			},
		)
		"${facts.file}\n${Str.join_with(lines, "")}"
	}

	## The tree of one member (the table above).
	tree : { file : Str, walked : Closure.Walked, patched : List(Str) } -> Str
	tree = |facts| {
		shown = tree_lines(facts.walked, facts.patched, { from: Err(Header), depth: 1, shown: [] })
		"${facts.file}\n${Str.join_with(shown.lines, "")}"
	}

	## The `data` of `--json` (R-J3, R-J4, R-OUT4, R-OUT5). Keys in this order. `--tree` changes the human text only: the `links` have its facts.
	##
	## | Key | Value |
	## | --- | --- |
	## | `members` | A list, one object for each member, in the order of the members: `file`, `packages`, `links`, `series` |
	## | `packages` | A list of objects: `alias`, `name`, `version` (null for a path or foreign row), `kind` (`"release"`, `"path"`, `"foreign"`), `id`, `direct` (true or false), `via` (the alias, or null), `raised` (the version, or null), `foreign` (true or false), `platform` (true or false), and since slice 042 `patched` (true or false, the last key: the mark above). `tln why` has no `patched` key (`object_of` is as before). |
	## | `links` | A list of objects: `from` (the `id`, or null for a header entry), `alias`, `to` |
	## | `series` | The clashes of R-C8: a list of objects `name` and `series` (a list of objects `series` and `via`) |
	data : List({ file : Str, walked : Closure.Walked, patched : List(Str) }) -> JsonDoc
	data = |members| JsonDoc.Obj([("members", Arr(members.map(|m| member_doc(m.file, m.walked, m.patched))))])

	## The object of one package (the entry of `packages` above). `tln why` uses it for `data.members[].package`.
	object_of : Closure.Row -> JsonDoc
	object_of = |row| JsonDoc.Obj(package_fields(row))
}

# `<name> <version>` for a release, else the value as written.
label_of : Closure.Row -> Str
label_of = |row| if row.kind == Release "${row.name} ${row.version}" else row.name

# The marks of a row (R-CM9): `direct` or, in the flat list only, `via <alias>`; `raised from <version>`; `foreign` for a path entry and a foreign URL (R-H4).
marks_of : Closure.Row, Bool, List(Str) -> List(Str)
marks_of = |row, with_via, patched| {
	origin = match row.via {
		Ok(alias) if with_via => ["via ${alias}"]
		Ok(_) => []
		Err(None) => ["direct"]
	}
	raised = match row.raised {
		Ok(version) => ["raised from ${version}"]
		Err(None) => []
	}
	foreign = if row.kind == Release [] else ["foreign"]
	mark = if is_patched(row, patched) ["patched"] else []
	origin.concat(raised).concat(foreign).concat(mark)
}

# R-CM9, R-PA12: a header entry whose alias is a key of the `[patch]` table of the member.
is_patched : Closure.Row, List(Str) -> Bool
is_patched = |row, patched| row.direct and patched.contains(row.alias)

# The lines of the links that leave `from`, depth first. A row that an earlier line has is `shown above` and has no children.
tree_lines : Closure.Walked, List(Str), { from : Try(Str, [Header]), depth : U64, shown : List(Str) } -> { lines : List(Str), shown : List(Str) }
tree_lines = |walked, patched, at| walked.links.keep_if(|l| l.from == at.from).fold(
	{ lines: [], shown: at.shown },
	|acc, link| {
		row = walked.rows.find_first(|r| r.id == link.to)
		label = match row {
			Ok(r) => label_of(r)
			Err(_) => link.to
		}
		indent = "  ".repeat(at.depth)
		if acc.shown.contains(link.to) {
			{ lines: acc.lines.append("${indent}${link.alias}: ${label} (shown above)\n"), shown: acc.shown }
		} else {
			marks = match row {
				Ok(r) => marks_of(r, Bool.False, patched)
				Err(_) => []
			}
			suffix = if marks.is_empty() "" else " (${Str.join_with(marks, "; ")})"
			inner = tree_lines(walked, patched, { from: Ok(link.to), depth: at.depth + 1, shown: acc.shown.append(link.to) })
			{ lines: acc.lines.append("${indent}${link.alias}: ${label}${suffix}\n").concat(inner.lines), shown: inner.shown }
		}
	},
)

member_doc : Str, Closure.Walked, List(Str) -> JsonDoc
member_doc = |file, walked, patched| JsonDoc.Obj([
	("file", Text(file)),
	("packages", Arr(walked.rows.map(|row| JsonDoc.Obj(package_fields(row).append(("patched", Flag(is_patched(row, patched)))))))),
	("links", Arr(walked.links.map(link_doc))),
	("series", Arr(Closure.clashes(walked.rows).map(series_doc))),
])

package_fields : Closure.Row -> List((Str, JsonDoc))
package_fields = |row| [
	("alias", Text(row.alias)),
	("name", Text(row.name)),
	("version", if row.kind == Release Text(row.version) else Null),
	(
		"kind",
		Text(
			match row.kind {
				Release => "release"
				Path => "path"
				Foreign => "foreign"
			},
		),
	),
	("id", Text(row.id)),
	("direct", Flag(row.direct)),
	("via", optional_text(row.via)),
	("raised", optional_text(row.raised)),
	("foreign", Flag(row.kind != Release)),
	("platform", Flag(row.is_platform)),
]

optional_text : Try(Str, [None]) -> JsonDoc
optional_text = |value| match value {
	Ok(text) => JsonDoc.Text(text)
	Err(None) => JsonDoc.Null
}

link_doc : Closure.Link -> JsonDoc
link_doc = |link| JsonDoc.Obj([
	(
		"from",
		match link.from {
			Ok(id) => Text(id)
			Err(Header) => Null
		},
	),
	("alias", Text(link.alias)),
	("to", Text(link.to)),
])

series_doc : { name : Str, series : List({ series : Str, via : Str }) } -> JsonDoc
series_doc = |clash| JsonDoc.Obj([
	("name", Text(clash.name)),
	("series", Arr(clash.series.map(|s| JsonDoc.Obj([("series", Text(s.series)), ("via", Text(s.via))])))),
])
