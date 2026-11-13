import Closure
import ClosureIndex
import Fail
import Fetch
import Fx
import Gather
import Net
import NoRank
import Release
import Roots

## The closure walk (slice 010; R-H7, R-FE1, R-AL2, R-CM2, R-CM9). Command code over `Fx` (TESTING.md 2.2 part C): it calls `Closure.step` and reads what it needs, level by level, until it is done.
## `Install`, `Update`, `Verify` (the tuple, before the ladder) and `Ls` call it. The pure decisions are in `Closure`.
##
## The calls of one level, in order (the L2 case `closure/cl1-flow` fixes them):
##
## | Step | Call |
## | --- | --- |
## | 1 | `Closure.step` with the nodes read so far (`known` and the levels before). `Done(walked)` is the result. `Fail(problem)` is the failure `Closure.failure`. No `Fx` call. |
## | 2 | `Need(ids)`: `Gather.get!` for the ids, the same call as the pick makes (R-AL8, R-FE1): `Fetch.packages!` for the URLs, then one `read_files!` for all ids, in the order of the ids. The failure of an id is the failure of the walk (the first one in the order of the ids: an offline run for a package that is not in the cache is `Fetch.offline_missing`, exit 15, R-FE7). |
## | 3 | `Release.entries_of` of each text (its failures: kind `Input`). Each gives a `Closure.Node` with `entries`. Then step 1 again. |
##
## A node that is in `known` is never read again. A path file is an app, a package or a platform file: `Release.entries_of` reads the three. The walk never writes a file.
Walk :: [].{

	## `file` and `entries` are the project file (absolute) and its header entries (`Locked.rows` without the `roc` entry, as `Closure.Entry`). `known` are nodes that the command read already (the facts of the pick), or `[]`.
	## Slice 206 (R-AL8 source 2, R-AL9): `index` is the index of the run. With `Answer`, a level reads the facts of an id whose hash has a record in the answer from the record (`Gather.facts!`): no fetch and no read for it. The walk asks only for the winners (R-AL9), so a record of a version that does not win is never read.
	## The result has `nodes`: `known` and every node that this call read, so a second member does not read them again.
	run! : Fx, { roots : Roots, net : Net.Settings, offline : Bool, selected : Str, none : NoRank.Fallback, index : ClosureIndex.Source, file : Str, entries : List(Closure.Entry), known : List(Closure.Node), leaf ?: Bool } => Try({ walked : Closure.Walked, nodes : List(Closure.Node), gone : List(Str) }, Fail)
	run! = |fx, facts| walk!(fx, { roots: facts.roots, net: facts.net, offline: facts.offline, selected: facts.selected, none: facts.none, index: facts.index, file: facts.file, entries: facts.entries, known: facts.known, leaf: facts.?leaf ?? Bool.False }, facts.known, [])
}

Facts : { roots : Roots, net : Net.Settings, offline : Bool, selected : Str, none : NoRank.Fallback, index : ClosureIndex.Source, file : Str, entries : List(Closure.Entry), known : List(Closure.Node), leaf : Bool }

# Steps 1 to 4: `Closure.step`, then the levels that it asks for, until it is done.
walk! : Fx, Facts, List(Closure.Node), List(Str) => Try({ walked : Closure.Walked, nodes : List(Closure.Node), gone : List(Str) }, Fail)
walk! = |fx, facts, nodes, gone| match Closure.step({ file: facts.file, entries: facts.entries, nodes }) {
	Done(walked) => Ok({ walked, nodes, gone })
	Fail(problem) => Err(Closure.failure(problem))
	Need(ids) => {
		more = level!(fx, facts, ids, [])?
		walk!(fx, facts, nodes.concat(more.nodes), gone.concat(more.gone))
	}
}

# One level: `Gather.facts!` for the ids (slice 206: a record of the closure answer gives its entries, no read), then the entries of each header text.
# Slice 244d (Q621 item 3): with `leaf` (`tln audit` only) a download that answers 404 makes its id a leaf: a node with no entries, listed in `gone`. Any other failure stops the walk. The level is read again without the gone id.
level! : Fx, Facts, List(Str), List(Str) => Try({ nodes : List(Closure.Node), gone : List(Str) }, Fail)
level! = |fx, facts, ids, gone| {
	asked = ids.keep_if(|id| !gone.contains(id))
	attempt = Gather.facts!(fx, { roots: facts.roots, net: facts.net, offline: facts.offline, selected: facts.selected, none: facts.none, index: facts.index }, asked)
	got = match attempt {
		Ok(found) => found
		Err(fail) => match Fetch.gone_url(fail) {
			Ok(url) if facts.leaf and asked.contains(url) => return level!(fx, facts, ids, gone.append(url))
			_ => return Err(fail)
		}
	}
	var $nodes = no_nodes
	for g in got {
		match g {
			Record(r) => {
				$nodes = $nodes.append({ id: r.id, entries: r.header.entries })
			}
			Text(t) => {
				$nodes = $nodes.append({ id: t.id, entries: Release.entries_of({ path: t.path, text: t.text })? })
			}
		}
	}
	Ok({ nodes: $nodes.concat(gone.map(|id| { id, entries: [] })), gone })
}

no_nodes : List(Closure.Node)
no_nodes = []
