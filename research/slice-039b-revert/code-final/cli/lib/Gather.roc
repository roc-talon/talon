import Fail
import Fetch
import Fx
import Ident
import Item
import Net
import Roots

## The one fetch of header facts (R-AL8, R-FE1, R-DI7). The pick (`PickLoop.run!`) and the closure walk (`Walk.level!`) both call `get!` for a list of ids.
## The facts that the command has (R-AL8, source 1) are not asked for: the caller gives only the ids that it lacks.
##
## | Step | Call | Source (R-AL8) |
## | --- | --- | --- |
## | 1 | `Fetch.packages!` for the release URLs of the list, in the order of the ids. It downloads only the archives that are not in `packages/`. No call when no id is a URL. The first failure, in the order of the ids, is the failure. | 4 |
## | 2 | One `read_files!` for `packages/<hash>/main.roc` of each URL and the file of each path id, in the order of the ids. A file that cannot be read: kind `Environment`, `cannot read <path>`. | 3 |
##
## The caller reads the text: `Release.read` for a URL, `Release.entries_of` for a path file.
Gather :: [].{

	## `id` is a release URL, or the absolute file of a path node. `path` is the file that was read.
	Got : { id : Str, path : Str, text : Str }

	get! : Fx, { roots : Roots, net : Net.Settings, offline : Bool }, List(Str) => Try(List(Got), Fail)
	get! = |fx, facts, ids| {
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
		var $got = no_got
		for (id, path, text) in ids.map2(paths.map2(texts, |p, t| (p, t)), |i, (p, t)| (i, p, t)) {
			match text {
				Ok(body) => {
					$got = $got.append({ id, path, text: body })
				}
				Err(_) => return Err(Fail.new(Environment, "cannot read ${path}"))
			}
		}
		Ok($got)
	}

	## The header file of an id: `main.roc` of a release in the package cache, else the path file itself.
	file_of : Roots, Str -> Str
	file_of = |roots, id| match Ident.of_url(id) {
		Ok(ident) => "${Roots.item(roots, Item.Package(ident.hash))}/main.roc"
		Err(Foreign) => id
	}
}

no_got : List(Gather.Got)
no_got = []
