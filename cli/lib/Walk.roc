import Closure
import Fail
import Fetch
import Fx
import Ident
import Item
import Net
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
## | 2 | `Need(ids)`: when some ids are release URLs, `Fetch.packages!` for them, in the order of the ids (R-FE1: the fetch of a level waits for the level before it). The failure of an id is the failure of the walk (the first one in the order of the ids: an offline run for a package that is not in the cache is `Fetch.offline_missing`, exit 15, R-FE7). `roc` is `"roc"`, `downloader` is `net.downloader`. No call when no id is a URL. |
## | 3 | One `read_files!` for the `main.roc` of each URL (`<pkgs>/<hash>/main.roc`) and the file of each path id, in the order of the ids. A file that cannot be read is a failure of kind `Environment`, `cannot read <path>` |
## | 4 | `Release.entries_of` of each text (its failures: kind `Input`). Each gives a `Closure.Node` with `entries`. Then step 1 again. |
##
## A node that is in `known` is never read again. A path file is an app, a package or a platform file: `Release.entries_of` reads the three. The walk never writes a file.
Walk :: [].{

	## `file` and `entries` are the project file (absolute) and its header entries (`Locked.rows` without the `roc` entry, as `Closure.Entry`). `known` are nodes that the command read already (the facts of the pick), or `[]`.
	## The result has `nodes`: `known` and every node that this call read, so a second member does not read them again.
	run! : Fx, { roots : Roots, net : Net.Settings, offline : Bool, file : Str, entries : List(Closure.Entry), known : List(Closure.Node) } => Try({ walked : Closure.Walked, nodes : List(Closure.Node) }, Fail)
	run! = |fx, facts| walk!(fx, facts, facts.known)
}

Facts : { roots : Roots, net : Net.Settings, offline : Bool, file : Str, entries : List(Closure.Entry), known : List(Closure.Node) }

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

# One level: the fetch of the release URLs, one read of the files, and the entries of each header.
level! : Fx, Facts, List(Str) => Try(List(Closure.Node), Fail)
level! = |fx, facts, ids| {
	urls = ids.keep_if(|id| Ident.of_url(id).is_ok())
	if !urls.is_empty() {
		results = Fetch.packages!(fx, { roots: facts.roots, urls, offline: facts.offline, roc: "roc", downloader: facts.net.downloader })
		for result in results {
			match result {
				Ok(_) => {}
				Err(fail) => return Err(fail)
			}
		}
	}
	paths = ids.map(|id| file_of(facts.roots, id))
	texts = fx.read_files!(paths)
	var $nodes = no_nodes
	for (id, path, text) in ids.map2(paths.map2(texts, |p, t| (p, t)), |i, (p, t)| (i, p, t)) {
		body = match text {
			Ok(t) => t
			Err(_) => return Err(Fail.new(Environment, "cannot read ${path}"))
		}
		$nodes = $nodes.append({ id, entries: Release.entries_of({ path, text: body })? })
	}
	Ok($nodes)
}

no_nodes : List(Closure.Node)
no_nodes = []

# The header file of a node: `main.roc` of a release in the package cache, else the path file itself.
file_of : Roots, Str -> Str
file_of = |roots, id| match Ident.of_url(id) {
	Ok(ident) => "${Roots.item(roots, Item.Package(ident.hash))}/main.roc"
	Err(Foreign) => id
}
