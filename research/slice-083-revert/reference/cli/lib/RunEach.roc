import Fail
import Intent
import JsonDoc
import Project
import Release
import TomlKeys
import Text
import toml.Toml
import toml.Value

## The order of `tln run --each` (slice 058, CLI 1: R-RUN13, R-EA1 to R-EA8, Design 4.4 R-WS5, user answers Q-S6, Q-S12, Q-S13, NC4 of the draft D-TS). Part A (pure, TESTING.md 2.2). `RunEachFlow` reads the files and calls these functions.
##
## | Function | Decides | Rule |
## | --- | --- | --- |
## | `paths`, `nodes` | The nodes: the directories of the workspace that have a `talon.toml` and a member file | R-EA1, R-WS5, NC4 |
## | `header_paths`, `edges` | The edges of kind 1 (path entries of the member headers) and of kind 2 (`[run] after`) | R-EA2, R-EA3 |
## | `read_after` | The form of `[run]` | R-EA3 |
## | `order` | The order: the node with the smallest path of those that are ready goes first, a cycle is exit 19 | R-EA4, R-EA5, R-EA6 |
## | `skipped` | With `--keep-going`: the failed node that makes a node skipped | R-EA7 |
## | `label`, `list_text`, `list_data` | The names of the nodes in the output, the output of `tln run --each` with no name | R-EA8 |
##
## An edge `{ from, to, kind }` reads: the node `from` comes after the node `to` (so `to` runs first). The text form is `<from> -<kind>-> <to>` (the example of R-EA5: `workers/web -after-> workers/ledger`).
RunEach :: [].{

	## One node: its directory (absolute), its member files (absolute, sorted: the member files of the workspace whose nearest `talon.toml` is the file of this directory, R-PD6), and the text of its `talon.toml`.
	Node : { dir : Str, members : List(Str), text : Str }

	## One edge: `from` comes after `to`. The two are directories of nodes. `Path`: kind 1 (R-EA2). `After`: kind 2 (R-EA3).
	Edge : { from : Str, to : Str, kind : [Path, After] }

	## R-EA1, R-PD6, NC4: the `talon.toml` paths that tell which directories are nodes: for each member file of the workspace the candidates of `Intent.paths` (the directory of the member file, each parent, up to the root), without the file of the root. Sorted, no repeat.
	## The caller reads them with one `read_files!` (a path that is not there is a missing file). No path: no call.
	paths : { root : Str, members : List(Str) } -> List(Str)
	paths = |facts| Text.sorted_unique(facts.members.join_map(|member| candidates(facts.root, member)))

	## R-EA1, R-WS5, NC4: the nodes, sorted by the byte order of the directory. A node is a directory that is the nearest `talon.toml` (below the root) of at least one member file. The root directory is no node. A `talon.toml` with no member file in its directory,
	## or below it up to the next `talon.toml`, is a standalone file (R-WS5) and no node. `files` is the answer of the reads of `paths`: the text of a file, or `Err(None)` for a file that is not there.
	nodes : { root : Str, members : List(Str), files : List({ path : Str, text : Try(Str, [None]) }) } -> List(RunEach.Node)
	nodes = |facts| {
		owned = facts.members.keep_oks(
			|member| match first_file(facts.files, candidates(facts.root, member)) {
				Ok(found) => Ok({ member, dir: found.dir, text: found.text })
				Err(None) => Err(NoNode)
			},
		)
		Text.sorted_unique(owned.map(|o| o.dir)).map(
			|dir| {
				mine = owned.keep_if(|o| o.dir == dir)
				{ dir, members: Text.sorted(mine.map(|o| o.member)), text: text_of(mine) }
			},
		)
	}

	## R-RUN13, NC2, NC5, R-PD5, R-WS5: is the start directory in a standalone project? `toml_dirs` are the directories of the walk that have a `talon.toml`, nearest first. The walk stops at the nearest `talon.toml` (NC5), and the workspace has no effect on a standalone file (R-PD5):
	## when that directory is neither the root nor a node, `Ok(dir)` is the standalone directory, and `--each` there is as with no workspace (exit 2). `Err(None)`: the nearest file is the root or a node (or there is none): the command works on the workspace.
	standalone : { toml_dirs : List(Str), root : Str, nodes : List(Str) } -> Try(Str, [None])
	standalone = |facts| match facts.toml_dirs {
		[nearest, ..] => if nearest != facts.root and !facts.nodes.contains(nearest) Ok(nearest) else Err(None)
		[] => Err(None)
	}

	## The files that give the edges of kind 1: all member files of all nodes, sorted. The caller reads them with one `read_files!` (no node: no call).
	header_paths : List(RunEach.Node) -> List(Str)
	header_paths = |list| Text.sorted_unique(list.join_map(|node| node.members))

	## R-EA3: the list `after` of the table `[run]` of one `talon.toml`, as written. No table, or no key, gives `[]`. Failures have the kind `Input` (exit 19). The texts are proposals (TW24):
	##
	## | Case | Message |
	## | --- | --- |
	## | Not TOML | `<path>:<line>: not valid TOML` |
	## | `run` is not a table | `<path>:<line>: run: must be a table` |
	## | `after` is not a list of strings | `<path>:<line>: run.after: must be a list of strings (directories, relative to this file)` |
	read_after : { path : Str, text : Str } -> Try(List(Str), Fail)
	read_after = |facts| match Toml.parse(facts.text) {
		Err(TomlErr(e)) => Err(Fail.new(Input, "${facts.path}:${e.line.to_str()}: not valid TOML"))
		Ok(doc) => match Toml.get(doc, ["run"]) {
			Err(NotFound) => Ok([])
			Ok(Value.Table(t)) => match t.get("after") {
				Err(_) => Ok([])
				Ok(Value.Array(items)) => items.map_try(
					|item| match item {
						Value.String(text) => Ok(text)
						_ => Err(bad_after(facts.path, doc))
					},
				)
				Ok(_) => Err(bad_after(facts.path, doc))
			}
			Ok(_) => Err(Fail.new(Input, "${facts.path}:${TomlKeys.key_line(doc, ["run"]).to_str()}: run: must be a table"))
		}
	}

	## R-EA2, R-EA3: all edges, sorted by `from`, then `to`, then the kind (`Path` first), with no repeat. `headers` are the texts of the member files (`header_paths`). The failures have the kind `Input` (exit 19). The texts are proposals (TW24):
	##
	## | Case | Message |
	## | --- | --- |
	## | A member file with no header, or a header that does not parse (R-PD8, review of slice 058: exit 2, kind `Usage`, as for a project file) | `<path> has no app, package or platform header`, or `<path>:<line>: the header is not valid` |
	## | A form of `[run]` that is not valid | the failure of `read_after` |
	## | An entry of `after` that is not a node (R-EA3) | `<dir>/talon.toml: run.after names '<entry>', which is not a node of the workspace (a directory with a talon.toml and a member file)` |
	##
	## Kind 1 (R-EA2): a member file of node A has a path entry (a value with no `://`) that names, relative to the directory of that member file, a member file of node B, or a file in the directory of B (the directory itself, not a subdirectory: question Q1 of the slice file). An entry that names
	## a file of the same node, of the root directory, of a standalone file or of no node gives no edge. A member file that has no text in `headers` gives no edge. Kind 2 (R-EA3): each entry of `after` of node A, relative to the directory of A, is the directory of a node B (the same node A is an edge to itself, a cycle).
	edges : { nodes : List(RunEach.Node), headers : List({ file : Str, text : Str }) } -> Try(List(RunEach.Edge), Fail)
	edges = |facts| {
		by_path = path_edges(facts.nodes, facts.headers)?
		by_after = after_edges(facts.nodes)?
		Ok(tidy(by_path.concat(by_after)))
	}

	## R-EA5, R-EA6, R-EA4: the order of all the nodes (also the nodes that have no script of the name: an edge through them stays). Of the nodes that are ready (all nodes that they come after are done), the one with the smallest path (byte order) goes first.
	## A cycle: failure of kind `Input` (exit 19), `the nodes of tln run --each depend on each other: <cycle>` with one cycle for each group of nodes that are in a cycle, joined with `; `. A cycle is `<from> -<kind>-> <to>` ... back to the first node, with the labels of `label`.
	## It starts at the smallest path of the nodes that are in the cycle, and follows the edges in the order of `edges` (a proposal, TW24: the example of R-EA5 has the order of the files).
	order : { nodes : List(Str), edges : List(RunEach.Edge), root : Str } -> Try(List(Str), Fail)
	order = |facts| {
		links = facts.edges.keep_if(|e| facts.nodes.contains(e.from) and facts.nodes.contains(e.to))
		match ready_first(links, [], Text.sorted_unique(facts.nodes)) {
			Ok(done) => Ok(done)
			Err(left) => Err(Fail.new(Input, "the nodes of tln run --each depend on each other: ${cycle_text(facts.root, links, left)}"))
		}
	}

	## R-EA7: with `--keep-going`, the node `node` is skipped when it comes after a node that failed, directly or through other nodes (also through a node that has no such script). The answer is the failed node: the first of `failed` (in the order of the run) that `node` comes after. `Err(None)`: run it.
	skipped : { edges : List(RunEach.Edge), failed : List(Str), node : Str } -> Try(Str, [None])
	skipped = |facts| {
		behind = reach(facts.edges, facts.node)
		match facts.failed.find_first(|f| behind.contains(f)) {
			Ok(failed) => Ok(failed)
			Err(_) => Err(None)
		}
	}

	## The name of a node in the output: its directory relative to the root (`workers/web`). The root itself is `.`.
	label : { root : Str, dir : Str } -> Str
	label = |facts| {
		prefix = if facts.root.ends_with("/") facts.root else "${facts.root}/"
		if facts.dir == facts.root "." else if facts.dir.starts_with(prefix) facts.dir.drop_prefix(prefix) else facts.dir
	}

	## R-EA8: the text of `tln run --each` with no name (a proposal, TW24): the line `order of <file>:`, one line for each node 2 spaces in (`  none` for no node), then the line `edges:` with one line for each edge 2 spaces in (`<from> -<kind>-> <to>`), or the line `edges: none`.
	## The nodes are named with `label`. A line end after each line.
	list_text : { file : Str, root : Str, order : List(Str), edges : List(RunEach.Edge) } -> Str
	list_text = |facts| {
		lines = if facts.order.is_empty() ["  none\n"] else facts.order.map(|dir| "  ${RunEach.label({ root: facts.root, dir })}\n")
		links = facts.edges.map(|e| "  ${edge_text(facts.root, e)}\n")
		tail = if links.is_empty() "edges: none\n" else "edges:\n${Str.join_with(links, "")}"
		"order of ${facts.file}:\n${Str.join_with(lines, "")}${tail}"
	}

	## R-EA8: the `data` of `--json` with no name: `{ "order": [<label>], "edges": [{ "from": <label>, "to": <label>, "kind": "path" | "after" }] }` (the shape is given by the design, R-OUT2).
	list_data : { root : Str, order : List(Str), edges : List(RunEach.Edge) } -> JsonDoc
	list_data = |facts| {
		name = |dir| JsonDoc.Text(RunEach.label({ root: facts.root, dir }))
		JsonDoc.Obj([
			("order", JsonDoc.Arr(facts.order.map(name))),
			(
				"edges",
				JsonDoc.Arr(
					facts.edges.map(
						|e| JsonDoc.Obj([
							("from", name(e.from)),
							("to", name(e.to)),
							("kind", JsonDoc.Text(kind_name(e.kind))),
						]),
					),
				),
			),
		])
	}
}

# R-EA1, R-PD6: the `talon.toml` files that can be the nearest one of a member file: the candidates of `Intent.paths` with no file of the root, nearest first.
candidates : Str, Str -> List(Str)
candidates = |root, member| Intent.paths({ member, root }).keep_if(|path| path != Text.join(root, "talon.toml"))

# The nearest candidate that exists (its text is `Ok`).
first_file : List({ path : Str, text : Try(Str, [None]) }), List(Str) -> Try({ dir : Str, text : Str }, [None])
first_file = |files, paths| match paths {
	[] => Err(None)
	[path, .. as rest] => match files.find_first(|f| f.path == path) {
		Ok(file) => match file.text {
			Ok(text) => Ok({ dir: Text.dir_of(path), text })
			Err(None) => first_file(files, rest)
		}
		Err(_) => first_file(files, rest)
	}
}

# The text of the `talon.toml` of a node: all its member files have the same one.
text_of : List({ member : Str, dir : Str, text : Str }) -> Str
text_of = |owned| match owned {
	[first, ..] => first.text
	[] => ""
}

bad_after : Str, Toml -> Fail
bad_after = |path, doc| Fail.new(Input, "${path}:${TomlKeys.key_line(doc, ["run", "after"]).to_str()}: run.after: must be a list of strings (directories, relative to this file)")

# R-EA2: the edges of kind 1. The header of each member file must be valid (R-PD8: exit 2).
path_edges : List(RunEach.Node), List({ file : Str, text : Str }) -> Try(List(RunEach.Edge), Fail)
path_edges = |list, headers| headers.fold_try(
	[],
	|found, header| {
		_kind = Project.check_header({ path: header.file, text: header.text }).map_err(|f| Fail.new(Usage, f.message))?
		entries = Release.entries_of({ path: header.file, text: header.text })?
		Ok(found.concat(header_edges(list, header.file, entries.map(|e| e.value))))
	},
)

# The edges of one member file: each path entry that names a file of another node.
header_edges : List(RunEach.Node), Str, List(Str) -> List(RunEach.Edge)
header_edges = |list, file, values| match list.find_first(|n| n.members.contains(file)) {
	Err(_) => []
	Ok(own) => values.keep_oks(
		|value| if value.contains("://") {
			Err(NoPath)
		} else {
			match node_of(list, Text.resolve(Text.dir_of(file), value)) {
				Ok(dir) if dir != own.dir => Ok({ from: own.dir, to: dir, kind: Path })
				_ => Err(NoEdge)
			}
		},
	)
}

# R-EA2: the node that a path names: the node that has the file as a member, else the node whose directory is the directory of the file.
node_of : List(RunEach.Node), Str -> Try(Str, [NoNode])
node_of = |list, path| match list.find_first(|n| n.members.contains(path)) {
	Ok(n) => Ok(n.dir)
	Err(_) => match list.find_first(|n| n.dir == Text.dir_of(path)) {
		Ok(n) => Ok(n.dir)
		Err(_) => Err(NoNode)
	}
}

# R-EA3: the edges of kind 2. An entry that is no node is exit 19.
after_edges : List(RunEach.Node) -> Try(List(RunEach.Edge), Fail)
after_edges = |list| list.fold_try(
	[],
	|found, n| {
		file = Text.join(n.dir, "talon.toml")
		entries = RunEach.read_after({ path: file, text: n.text })?
		links = entries.map_try(
			|entry| {
				to = Text.resolve(n.dir, entry)
				if list.any(|m| m.dir == to) {
					Ok({ from: n.dir, to, kind: After })
				} else {
					Err(Fail.new(Input, "${file}: run.after names '${entry}', which is not a node of the workspace (a directory with a talon.toml and a member file)"))
				}
			},
		)?
		Ok(found.concat(links))
	},
)

# The edges sorted by `from`, `to` and the kind (`Path` first), with no repeat.
tidy : List(RunEach.Edge) -> List(RunEach.Edge)
tidy = |list| list.sort_with(edge_order).fold(
	[],
	|kept, e| match kept.last() {
		Ok(previous) if previous == e => kept
		_ => kept.append(e)
	},
)

edge_order : RunEach.Edge, RunEach.Edge -> [Before, Same, After]
edge_order = |a, b| match Text.compare(a.from, b.from) {
	Same => match Text.compare(a.to, b.to) {
		Same => match (a.kind, b.kind) {
			(Path, After) => Before
			(After, Path) => After
			_ => Same
		}
		other => other
	}
	other => other
}

kind_name : [Path, After] -> Str
kind_name = |kind| match kind {
	Path => "path"
	After => "after"
}

edge_text : Str, RunEach.Edge -> Str
edge_text = |root, e| "${RunEach.label({ root, dir: e.from })} -${kind_name(e.kind)}-> ${RunEach.label({ root, dir: e.to })}"

# R-EA6: Kahn. Of the nodes that are ready the smallest goes first (`left` is sorted). `Err(left)`: the nodes that are left when none is ready.
ready_first : List(RunEach.Edge), List(Str), List(Str) -> Try(List(Str), List(Str))
ready_first = |links, done, left| match left {
	[] => Ok(done)
	_ => match left.keep_if(|n| links.all(|e| e.from != n or done.contains(e.to))) {
		[first, ..] => ready_first(links, done.append(first), left.keep_if(|n| n != first))
		[] => Err(left)
	}
}

# The nodes that `start` comes after, directly or not (at least one edge).
reach : List(RunEach.Edge), Str -> List(Str)
reach = |links, start| grow(links, links.keep_if(|e| e.from == start).map(|e| e.to), [])

grow : List(RunEach.Edge), List(Str), List(Str) -> List(Str)
grow = |links, frontier, seen| match frontier {
	[] => seen
	[n, .. as rest] => if seen.contains(n) {
		grow(links, rest, seen)
	} else {
		grow(links, rest.concat(links.keep_if(|e| e.from == n).map(|e| e.to)), seen.append(n))
	}
}

# R-EA5: one loop for each group of nodes in a cycle, joined with `; `. `left` is sorted, so a group starts at its smallest node.
cycle_text : Str, List(RunEach.Edge), List(Str) -> Str
cycle_text = |root, links, left| {
	on_cycle = left.keep_if(|n| reach(links, n).contains(n))
	groups = on_cycle.fold(
		[],
		|found, n| if found.any(|g| g.contains(n)) {
			found
		} else {
			found.append(on_cycle.keep_if(|m| reach(links, n).contains(m) and reach(links, m).contains(n)))
		},
	)
	Str.join_with(groups.map(|g| loop_text(root, links, g)), "; ")
}

loop_text : Str, List(RunEach.Edge), List(Str) -> Str
loop_text = |root, links, group| match group {
	[start, ..] => {
		path = loop_from(links, start, [{ at: start, via: [] }], [])
		path.fold(RunEach.label({ root, dir: start }), |text, e| "${text} -${kind_name(e.kind)}-> ${RunEach.label({ root, dir: e.to })}")
	}
	[] => ""
}

# The shortest loop from `start` back to `start`; of equal ones, the first edge in the order of `links`.
loop_from : List(RunEach.Edge), Str, List({ at : Str, via : List(RunEach.Edge) }), List(Str) -> List(RunEach.Edge)
loop_from = |links, start, frontier, seen| {
	steps = frontier.join_map(|item| links.keep_if(|e| e.from == item.at).map(|e| { at: e.to, via: item.via.append(e) }))
	match steps.find_first(|s| s.at == start) {
		Ok(done) => done.via
		Err(_) => {
			fresh = steps.fold([], |kept, s| if seen.contains(s.at) or kept.any(|k| k.at == s.at) kept else kept.append(s))
			if fresh.is_empty() [] else loop_from(links, start, fresh, seen.concat(fresh.map(|s| s.at)))
		}
	}
}
