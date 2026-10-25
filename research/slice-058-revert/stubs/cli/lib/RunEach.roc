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
	paths = |_facts| crash "todo: slice 058"

	## R-EA1, R-WS5, NC4: the nodes, sorted by the byte order of the directory. A node is a directory that is the nearest `talon.toml` (below the root) of at least one member file. The root directory is no node. A `talon.toml` with no member file in its directory,
	## or below it up to the next `talon.toml`, is a standalone file (R-WS5) and no node. `files` is the answer of the reads of `paths`: the text of a file, or `Err(None)` for a file that is not there.
	nodes : { root : Str, members : List(Str), files : List({ path : Str, text : Try(Str, [None]) }) } -> List(RunEach.Node)
	nodes = |_facts| crash "todo: slice 058"

	## R-RUN13, NC2, NC5, R-PD5, R-WS5: is the start directory in a standalone project? `toml_dirs` are the directories of the walk that have a `talon.toml`, nearest first. The walk stops at the nearest `talon.toml` (NC5), and the workspace has no effect on a standalone file (R-PD5):
	## when that directory is neither the root nor a node, `Ok(dir)` is the standalone directory, and `--each` there is as with no workspace (exit 2). `Err(None)`: the nearest file is the root or a node (or there is none): the command works on the workspace.
	standalone : { toml_dirs : List(Str), root : Str, nodes : List(Str) } -> Try(Str, [None])
	standalone = |_facts| crash "todo: slice 058"

	## The files that give the edges of kind 1: all member files of all nodes, sorted. The caller reads them with one `read_files!` (no node: no call).
	header_paths : List(RunEach.Node) -> List(Str)
	header_paths = |_list| crash "todo: slice 058"

	## R-EA3: the list `after` of the table `[run]` of one `talon.toml`, as written. No table, or no key, gives `[]`. Failures have the kind `Input` (exit 19). The texts are proposals (TW24):
	##
	## | Case | Message |
	## | --- | --- |
	## | Not TOML | `<path>:<line>: not valid TOML` |
	## | `run` is not a table | `<path>:<line>: run: must be a table` |
	## | `after` is not a list of strings | `<path>:<line>: run.after: must be a list of strings (directories, relative to this file)` |
	read_after : { path : Str, text : Str } -> Try(List(Str), Fail)
	read_after = |_facts| crash "todo: slice 058"

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
	edges = |_facts| crash "todo: slice 058"

	## R-EA5, R-EA6, R-EA4: the order of all the nodes (also the nodes that have no script of the name: an edge through them stays). Of the nodes that are ready (all nodes that they come after are done), the one with the smallest path (byte order) goes first.
	## A cycle: failure of kind `Input` (exit 19), `the nodes of tln run --each depend on each other: <cycle>` with one cycle for each group of nodes that are in a cycle, joined with `; `. A cycle is `<from> -<kind>-> <to>` ... back to the first node, with the labels of `label`.
	## It starts at the smallest path of the nodes that are in the cycle, and follows the edges in the order of `edges` (a proposal, TW24: the example of R-EA5 has the order of the files).
	order : { nodes : List(Str), edges : List(RunEach.Edge), root : Str } -> Try(List(Str), Fail)
	order = |_facts| crash "todo: slice 058"

	## R-EA7: with `--keep-going`, the node `node` is skipped when it comes after a node that failed, directly or through other nodes (also through a node that has no such script). The answer is the failed node: the first of `failed` (in the order of the run) that `node` comes after. `Err(None)`: run it.
	skipped : { edges : List(RunEach.Edge), failed : List(Str), node : Str } -> Try(Str, [None])
	skipped = |_facts| crash "todo: slice 058"

	## The name of a node in the output: its directory relative to the root (`workers/web`). The root itself is `.`.
	label : { root : Str, dir : Str } -> Str
	label = |_facts| crash "todo: slice 058"

	## R-EA8: the text of `tln run --each` with no name (a proposal, TW24): the line `order of <file>:`, one line for each node 2 spaces in (`  none` for no node), then the line `edges:` with one line for each edge 2 spaces in (`<from> -<kind>-> <to>`), or the line `edges: none`.
	## The nodes are named with `label`. A line end after each line.
	list_text : { file : Str, root : Str, order : List(Str), edges : List(RunEach.Edge) } -> Str
	list_text = |_facts| crash "todo: slice 058"

	## R-EA8: the `data` of `--json` with no name: `{ "order": [<label>], "edges": [{ "from": <label>, "to": <label>, "kind": "path" | "after" }] }` (the shape is given by the design, R-OUT2).
	list_data : { root : Str, order : List(Str), edges : List(RunEach.Edge) } -> JsonDoc
	list_data = |_facts| crash "todo: slice 058"
}
