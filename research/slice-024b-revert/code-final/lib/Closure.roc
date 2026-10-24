import Fail
import Ident
import Text
import header.Mvs
import header.PackageUrl

## The closure of a project file (Design 2, R-H4, R-H7, R-C8, R-CM9; slice 010). Part A (pure). The command code is `Walk`: it reads the headers that `step` asks for.
##
## The closure is what `roc` builds: the entries of the header, and the dependencies of the selected version of each group (R-ID2). It is the result of `Mvs.select` of the
## generic package `roc-app-header` (R-GP5: not tested again here). `step` is the solver step of TESTING.md 2.2 part B: it stops with `Need` when it must read more headers, and the
## command calls it again with them.
##
## The kinds of an entry value:
##
## | Kind | Value | Rule |
## | --- | --- | --- |
## | `Release` | `Ident.of_url` is `Ok` | R-ID2 |
## | `Foreign` | has `://`, and `Ident.of_url` is `Err` (no hash, no version, 2 versions, `0.0.0`). It is listed, never read. | R-H4 |
## | `Path` | has no `://`. The file is `Text.resolve(<dir of the file of the node that names it>, value)`. A path entry is part of the closure (R-H7): its header is read, and its entries are edges. | R-H4, R-H7 |
##
## A path value in the header of a release is ignored (a published package cannot name a local file): no row, no link.
##
## What `step` decides:
##
## | # | Rule |
## | --- | --- |
## | 1 | The root edges are the `entries` (the platform entry too, `roc` is not an entry). The edges of a node are its `entries`. |
## | 2 | The followed edges are the root edges and the edges of the selected URL of each group (Mvs: "winners only"). A path node is selected when a followed edge names it. A path entry is not a root edge to Mvs: its URL entries are edges of a node, so a path entry that names `json 2.0.0` while the header has `json 2.1.0` is a raise (R-C2 allows it), not a `RootConflict`. |
## | 3 | `Need(ids)`: the ids of the nodes that the selection follows and that `nodes` lacks: the release URLs and the absolute files of path entries. In the order of the first followed edge that names them (the order of the rows below). A URL that no followed edge selects is never needed: a lower version that a package names while a higher one wins is not read and not fetched (as `roc` does). |
## | 4 | `Fail(problem)` only when `nodes` has the header of each node that the selection follows. A problem that comes from an incomplete selection is never returned. |
## | 5 | `Done(walked)`: one row for each group (`Release`), each path file and each foreign value, in the order of the first followed edge that names it, level by level (the header entries first, in order). |
##
## `Row`:
##
## | Field | Holds |
## | --- | --- |
## | `id` | The selected URL, the absolute path of the file of a path entry, or the value of a foreign entry |
## | `kind` | `Release`, `Path` or `Foreign` |
## | `alias` | The alias of the first followed edge that names the row (for a header entry: its alias) |
## | `name` | `Release`: `owner/repo` (`Ident.name`), else the URL form with the version in place of `{v}` and no `/` at the end (the text of `Fetch.name_of`). `Path`, `Foreign`: the value as the first edge wrote it. |
## | `form` | `Release`: the URL form of the group (`Ident.group.form`). Else the empty text. |
## | `version`, `series` | `Release`: `X.Y.Z` and its series (R-ID1). Else the empty text. |
## | `direct` | A header entry names the row. For a group, the selected URL is then the URL of the header entry (the root edge is exact). |
## | `via` | `Err(None)` for a direct row. Else `Ok(alias)`: the alias of the header entry at the top of the first followed edge that names the row |
## | `raised` | `Release`: `Ok(version)` when a followed edge names a lower version of the group than the selected one: the lowest version that a followed edge names (question Q9: the mark is of the package). Else `Err(None)`. |
## | `is_platform` | A followed edge that names the row is a platform edge |
##
## `Link`: one followed edge. `from` is `Ok(id)` of the package whose header has the edge, `Err(Header)` for a header entry. `alias` is the alias in that header. `to` is the `id` of the row of the group (the
## selected URL, also when the edge names a lower version). The order is the order of the walk (level by level).
Closure :: [].{

	## An entry of a dependency record as in the source: the alias, the text between the quotes, and whether it is `name: platform "..."`. The `roc:` entry is not one.
	Entry : { alias : Str, value : Str, is_platform : Bool }

	## The header of one package that was read: `id` is the URL, or the absolute file of a path entry. `entries` are its entries in source order (`Release.entries_of`).
	Node : { id : Str, entries : List(Entry) }

	Row : {
		id : Str,
		kind : [Release, Path, Foreign],
		alias : Str,
		name : Str,
		form : Str,
		version : Str,
		series : Str,
		direct : Bool,
		via : Try(Str, [None]),
		raised : Try(Str, [None]),
		is_platform : Bool,
	}

	Link : { from : Try(Str, [Header]), alias : Str, to : Str }

	Walked : { rows : List(Row), links : List(Link) }

	## The failures of `Mvs.select`. The lists are as `Mvs` gives them, as URL texts (the `VersionConflict` rows are `pinned` and `needed` URLs and the package `by` that needs the higher one).
	Problem : [
		Cycle(List(Str)),
		RootConflict(List(Str)),
		ContentConflict(List(Str)),
		VersionConflict(List({ pinned : Str, needed : Str, by : Str })),
		PlatformMismatch(List(Str)),
	]

	## `file` is the project file (the absolute path: a path entry of the header is relative to its directory). `entries` are the header entries. `nodes` are the headers read so far (the rules above).
	step : { file : Str, entries : List(Entry), nodes : List(Node) } -> [Need(List(Str)), Done(Walked), Fail(Problem)]
	step = |facts| {
		root = edges_of({ dir: Text.dir_of(facts.file), from_release: Bool.False, entries: facts.entries })
		all = root.concat(facts.nodes.join_map(|n| node_edges(facts.nodes, n.id)))
		paths = Dict.from_list(all.keep_if(|e| e.shape == Path).keep_oks(|e| e.url.map_ok(|u| (u.to_str(), e.target))))
		restore = |text| paths.get(text) ?? text
		deps = |url| node_edges(facts.nodes, restore(url.to_str())).keep_oks(as_mvs)
		selected = Mvs.select(root.keep_oks(as_mvs), deps)
		chosen = match selected {
			Ok(urls) => urls.map(
				|u| match paths.get(u.to_str()) {
					Ok(path) => ("p:${path}", path)
					Err(_) => (key_of(u), u.to_str())
				},
			)
			Err(_) => settle(root, facts.nodes, [], 20)
		}
		followed = follow({ root, nodes: facts.nodes, chosen })
		if !followed.needs.is_empty() {
			Need(followed.needs)
		} else {
			match selected {
				Ok(_) => Done({ rows: followed.rows.map(row_of), links: followed.links })
				Err(problem) => Fail(problem_of(problem, restore))
			}
		}
	}

	## A problem of the closure as a failure (question Q16: kind `NoTuple`, exit 10, R-EC10, because the header has no tuple that `roc` accepts). The texts are a proposal (TW24).
	## `<label>` is `<name> <version>` (the text of `Fetch.name_of`).
	##
	## | Problem | Message |
	## | --- | --- |
	## | `Cycle` | `the closure has a cycle: <label> -> <label>` (in the order of the list) |
	## | `RootConflict` | `the header names one package at 2 versions or more: <label>, <label>` |
	## | `ContentConflict` | `one release has 2 hashes in the closure: <label> (<hash>), <label> (<hash>)` |
	## | `VersionConflict` | `<by label> needs <needed label>, but the header names <pinned label>`, one clause for each row, joined by `; ` |
	## | `PlatformMismatch` | `the platforms in the closure are not one release: <label> (<hash>), <label> (<hash>)` |
	failure : Problem -> Fail
	failure = |problem| Fail.new(NoTuple, problem_text(problem))

	## R-C8: the packages with 2 series or more among the rows. One entry for each `form` with 2 or more distinct `series` of `Release` rows, in the order of the first row of the form. `name` is the `name` of the
	## first row. `series` has one entry for each series (the order of the rows): `via` is the `alias` of a direct row, else the `via` of the row.
	clashes : List(Row) -> List({ name : Str, series : List({ series : Str, via : Str }) })
	clashes = |rows| {
		releases = rows.keep_if(|r| r.kind == Release)
		forms = releases.map(|r| r.form).fold([], |found, form| if found.contains(form) found else found.append(form))
		forms.keep_oks(
			|form| {
				of_form = releases.keep_if(|r| r.form == form)
				series = of_form.map(|r| r.series).fold([], |found, one| if found.contains(one) found else found.append(one))
				first = of_form.first() ? |_| NoClash
				if series.len() < 2 {
					Err(NoClash)
				} else {
					Ok({ name: first.name, series: of_form.map(|r| { series: r.series, via: if r.direct r.alias else r.via ?? "" }) })
				}
			},
		)
	}

	## R-C8, question Q11: one line for each clash (no line end): `warning: <name> has <n> series in the closure: <series> via <alias>, <series> via <alias>. The types of the <n> series are different types.`
	notes : List(Row) -> List(Str)
	notes = |rows| Closure.clashes(rows).map(
		|c| {
			n = c.series.len().to_str()
			list = Str.join_with(c.series.map(|s| "${s.series} via ${s.via}"), ", ")
			"warning: ${c.name} has ${n} series in the closure: ${list}. The types of the ${n} series are different types."
		},
	)
}

# What the step knows of one entry: where it points and how Mvs sees it. `target` is the release URL, the absolute file of a path entry, or the foreign value.
# `key` is the group of a release, else the file or the value. `url` is the release URL, the made-up URL of a path file, or `Err(None)` for a foreign value (Mvs never sees it).
Edge : { alias : Str, value : Str, shape : [Release, Path, Foreign], key : Str, target : Str, is_platform : Bool, url : Try(PackageUrl, [None]) }

Version : { major : U64, minor : U64, patch : U64 }

# One row while the walk runs.
Seen : { key : Str, id : Str, shape : [Release, Path, Foreign], alias : Str, name : Str, direct : Bool, top : Str, is_pf : Bool, lowest : Try(Version, [None]) }

# An edge that waits in the queue of the walk: `from` is the node that has it, `top` is the alias of the header entry that led to that node.
Queued : { edge : Edge, from : Try(Str, [Header]), top : Str }

shape_of : Str -> [Release, Path, Foreign]
shape_of = |value| match Ident.of_url(value) {
	Ok(_) => Release
	Err(Foreign) => if value.contains("://") Foreign else Path
}

key_of : PackageUrl -> Str
key_of = |url| {
	group = url.group()
	"r:${group.form}#${group.series}"
}

# A path file needs a URL for Mvs. The URL has the bytes of the path as digits, so it has no second version number and 2 files never share a group.
made_up : Str -> Str
made_up = |path| {
	code = Str.join_with(path.to_utf8().map(|b| if b < 10 "00${b.to_str()}" else if b < 100 "0${b.to_str()}" else b.to_str()), "")
	"https://talon.path/x${code}/1.0.0/x${code}.tar.zst"
}

edge_of : Str, Bool, Closure.Entry -> Try(Edge, [Skip])
edge_of = |dir, from_release, e| match shape_of(e.value) {
	Release => match PackageUrl.parse(e.value) {
		Ok(url) => Ok({ alias: e.alias, value: e.value, shape: Release, key: key_of(url), target: e.value, is_platform: e.is_platform, url: Ok(url) })
		Err(_) => Err(Skip)
	}
	# A published package cannot name a local file (R-H7).
	Path => if from_release {
		Err(Skip)
	} else {
		file = Text.resolve(dir, e.value)
		Ok({ alias: e.alias, value: e.value, shape: Path, key: "p:${file}", target: file, is_platform: e.is_platform, url: PackageUrl.parse(made_up(file)).map_err(|_| None) })
	}
	Foreign => Ok({ alias: e.alias, value: e.value, shape: Foreign, key: "f:${e.value}", target: e.value, is_platform: e.is_platform, url: Err(None) })
}

edges_of : { dir : Str, from_release : Bool, entries : List(Closure.Entry) } -> List(Edge)
edges_of = |facts| facts.entries.keep_oks(|e| edge_of(facts.dir, facts.from_release, e))

# The edges of the node with this id. A node that is not read yet has none.
node_edges : List(Closure.Node), Str -> List(Edge)
node_edges = |nodes, id| match nodes.find_first(|n| n.id == id) {
	Ok(n) => {
		from_release = Ident.of_url(id).is_ok()
		edges_of({ dir: Text.dir_of(id), from_release, entries: n.entries })
	}
	Err(_) => []
}

as_mvs : Edge -> Try({ url : PackageUrl, is_platform : Bool }, [None])
as_mvs = |e| e.url.map_ok(|url| { url, is_platform: e.is_platform })

newer : Version, Version -> Bool
newer = |a, b| if a.major != b.major {
	a.major > b.major
} else if a.minor != b.minor {
	a.minor > b.minor
} else {
	a.patch > b.patch
}

version_text : Version -> Str
version_text = |v| "${v.major.to_str()}.${v.minor.to_str()}.${v.patch.to_str()}"

# The winner of each group when Mvs has failed, from the nodes that are read: the version of the header, else the highest. It repeats until the winners stay the same.
settle : List(Edge), List(Closure.Node), List((Str, Str)), U64 -> List((Str, Str))
settle = |root, nodes, chosen, left| {
	followed = chosen.join_map(|(_, id)| node_edges(nodes, id))
	next = winners(root, followed)
	if left == 0 or next == chosen chosen else settle(root, nodes, next, left - 1)
}

winners : List(Edge), List(Edge) -> List((Str, Str))
winners = |root, followed| {
	first = root.fold([], |acc, e| add_winner(acc, e, Bool.True))
	followed.fold(first, |acc, e| add_winner(acc, e, Bool.False)).map(|w| (w.key, w.id))
}

add_winner : List({ key : Str, id : Str, url : PackageUrl, fixed : Bool }), Edge, Bool -> List({ key : Str, id : Str, url : PackageUrl, fixed : Bool })
add_winner = |acc, e, fixed| match e.url {
	Err(_) => acc
	Ok(url) => match acc.find_first_index(|w| w.key == e.key) {
		Err(_) => acc.append({ key: e.key, id: e.target, url, fixed })
		Ok(i) => match acc.get(i) {
			Ok(w) if !w.fixed and newer(url.version(), w.url.version()) => acc.set(i, { key: e.key, id: e.target, url, fixed: Bool.False }) ?? acc
			_ => acc
		}
	}
}

# The walk over the followed edges (rules 1, 2 and 5): the rows, the links and the ids that have no node yet. The edges of a row are queued when the row is new.
follow : { root : List(Edge), nodes : List(Closure.Node), chosen : List((Str, Str)) } -> { rows : List(Seen), links : List(Closure.Link), needs : List(Str) }
follow = |facts| {
	picks = Dict.from_list(facts.chosen)
	var $queue = facts.root.map(|e| { edge: e, from: Err(Header), top: e.alias })
	var $rows = no_seen
	var $links = no_links
	var $at = 0
	while $at < $queue.len() {
		match $queue.get($at) {
			Ok(q) => {
				e = q.edge
				id = picks.get(e.key) ?? e.target
				$links = $links.append({ from: q.from, alias: e.alias, to: id })
				if $rows.any(|r| r.key == e.key) {
					$rows = $rows.map(|r| if r.key == e.key lowered(r, e) else r)
				} else {
					$rows = $rows.append({ key: e.key, id, shape: e.shape, alias: e.alias, name: e.value, direct: q.from == Err(Header), top: q.top, is_pf: e.is_platform, lowest: e.url.map_ok(|u| u.version()) })
					if e.shape != Foreign {
						$queue = $queue.concat(node_edges(facts.nodes, id).map(|c| { edge: c, from: Ok(id), top: q.top }))
					}
				}
				$at = $at + 1
			}
			Err(_) => break
		}
	}
	needs = $rows.keep_if(|r| r.shape != Foreign and !facts.nodes.any(|n| n.id == r.id)).map(|r| r.id)
	{ rows: $rows, links: $links, needs }
}

no_seen : List(Seen)
no_seen = []

no_links : List(Closure.Link)
no_links = []

# A later edge to a known row: the platform mark and the lowest named version (R-C2, question Q9).
lowered : Seen, Edge -> Seen
lowered = |r, e| {
	named = e.url.map_ok(|u| u.version())
	lowest = match (r.lowest, named) {
		(Ok(have), Ok(v)) => if newer(have, v) Ok(v) else Ok(have)
		(Err(_), Ok(v)) => Ok(v)
		(_, Err(_)) => r.lowest
	}
	{ ..r, is_pf: r.is_pf or e.is_platform, lowest }
}

row_of : Seen -> Closure.Row
row_of = |r| {
	via = if r.direct Err(None) else Ok(r.top)
	plain = { id: r.id, kind: r.shape, alias: r.alias, name: r.name, form: "", version: "", series: "", direct: r.direct, via, raised: Err(None), is_platform: r.is_pf }
	match (r.shape, Ident.of_url(r.id), PackageUrl.parse(r.id)) {
		(Release, Ok(ident), Ok(url)) => {
			raised = match r.lowest {
				Ok(low) if newer(url.version(), low) => Ok(version_text(low))
				_ => Err(None)
			}
			{ ..plain, name: name_of(ident), form: ident.group.form, version: ident.version, series: ident.series, raised }
		}
		_ => plain
	}
}

# `<owner>/<repo>` for GitHub, else the URL form with the version, no scheme and no `/` at the end (the text of `Fetch.name_of` without the version).
name_of : Ident -> Str
name_of = |ident| ident.name ?? ident.group.form.replace_each("{v}", ident.version).drop_suffix("/")

# `<name> <version>` of a URL text. A text that is no release URL (a path file) stands for itself.
label_of : Str -> Str
label_of = |text| match Ident.of_url(text) {
	Ok(ident) => "${ident.name ?? ident.group.form.replace_each("{v}", ident.version).drop_suffix("/")} ${ident.version}"
	Err(Foreign) => text
}

hash_label : Str -> Str
hash_label = |text| match Ident.of_url(text) {
	Ok(ident) => "${label_of(text)} (${ident.hash})"
	Err(Foreign) => text
}

# The lists of a problem are in byte order (Mvs gives no order). A made-up URL of a path file is the file again.
problem_of : [Cycle(List(PackageUrl)), RootConflict(List(PackageUrl)), ContentConflict(List(PackageUrl)), VersionConflict(List({ pinned : PackageUrl, needed : PackageUrl, by : PackageUrl })), PlatformMismatch(List(PackageUrl))], (Str -> Str) -> Closure.Problem
problem_of = |problem, restore| {
	texts = |urls| urls.map(|u| restore(u.to_str()))
	match problem {
		Cycle(urls) => Cycle(texts(urls))
		RootConflict(urls) => RootConflict(Text.sorted(texts(urls)))
		ContentConflict(urls) => ContentConflict(Text.sorted(texts(urls)))
		PlatformMismatch(urls) => PlatformMismatch(Text.sorted(texts(urls)))
		VersionConflict(rows) => VersionConflict(
			rows
				.map(|r| { pinned: restore(r.pinned.to_str()), needed: restore(r.needed.to_str()), by: restore(r.by.to_str()) })
				.sort_with(|a, b| Text.compare("${a.by}\n${a.needed}\n${a.pinned}", "${b.by}\n${b.needed}\n${b.pinned}")),
		)
	}
}

problem_text : Closure.Problem -> Str
problem_text = |problem| match problem {
	Cycle(urls) => "the closure has a cycle: ${Str.join_with(urls.map(label_of), " -> ")}"
	RootConflict(urls) => "the header names one package at 2 versions or more: ${Str.join_with(urls.map(label_of), ", ")}"
	ContentConflict(urls) => "one release has 2 hashes in the closure: ${Str.join_with(urls.map(hash_label), ", ")}"
	VersionConflict(rows) => Str.join_with(rows.map(|r| "${label_of(r.by)} needs ${label_of(r.needed)}, but the header names ${label_of(r.pinned)}"), "; ")
	PlatformMismatch(urls) => "the platforms in the closure are not one release: ${Str.join_with(urls.map(hash_label), ", ")}"
}
