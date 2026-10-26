import Closure
import Fail
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
	## The result has `nodes`: `known` and every node that this call read, so a second member does not read them again.
	run! : Fx, { roots : Roots, net : Net.Settings, offline : Bool, selected : Str, none : NoRank.Fallback, file : Str, entries : List(Closure.Entry), known : List(Closure.Node) } => Try({ walked : Closure.Walked, nodes : List(Closure.Node) }, Fail)
	run! = |fx, facts| walk!(fx, facts, facts.known)
}

Facts : { roots : Roots, net : Net.Settings, offline : Bool, selected : Str, none : NoRank.Fallback, file : Str, entries : List(Closure.Entry), known : List(Closure.Node) }

# Steps 1 to 4: `Closure.step`, then the levels that it asks for, until it is done.
walk! : Fx, Facts, List(Closure.Node) => Try({ walked : Closure.Walked, nodes : List(Closure.Node) }, Fail)
walk! = |fx, facts, nodes| match Closure.step({ file: facts.file, entries: facts.entries, nodes }) {
	Done(walked) => Ok({ walked, nodes })
	Fail(problem) => Err(Closure.failure(problem))
	Need(ids) => {
		more = level!(fx, facts, ids)?
		walk!(fx, facts, nodes.concat(more))
	}
}

# One level: `Gather.get!` for the ids, then the entries of each header.
level! : Fx, Facts, List(Str) => Try(List(Closure.Node), Fail)
level! = |fx, facts, ids| {
	got = Gather.get!(fx, { roots: facts.roots, net: facts.net, offline: facts.offline, selected: facts.selected, none: facts.none }, ids)?
	var $nodes = no_nodes
	for g in got {
		$nodes = $nodes.append({ id: g.id, entries: Release.entries_of({ path: g.path, text: g.text })? })
	}
	Ok($nodes)
}

no_nodes : List(Closure.Node)
no_nodes = []
