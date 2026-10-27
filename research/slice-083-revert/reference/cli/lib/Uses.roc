import Closure
import Ident
import Scan
import Text
import header.Imports

## The used modules of the packages (Resolution 4 "A unit fail is per module", R-UM1). Part A (pure). `roc check` on an app checks only the modules that the app imports, so a unit fail of a package is a hard
## incompatibility only when the app uses a failing module. The scan is lexical (`Imports.scan` of the generic package `roc-app-header`, R-GP5: not tested again here): the `import` lines of the app, then the
## `import` lines inside each package that they reach, to the end. The command code (`Ladder.run!`) reads the files and calls `level` once for each level (TESTING.md 2.3 row 8: one `read_files!` call for each level),
## as `RemoveFlow` does for `tln remove` (R-RV2).
##
## ```mermaid
## flowchart LR
##     A["the app files (owner App)"] -->|"import json.Parser"| B["json: Parser.roc (owner Package(hash))"]
##     B -->|"import Helper"| C["json: Helper.roc (the same owner)"]
##     B -->|"import util.Strs"| D["util: Strs.roc (the alias of the header of json)"]
## ```
##
## The alias of `import json.Parser` is read in the header of the file that has the line: the header of the app for an app file, the header of the package for a package file (`edges`).
Uses :: [].{

	## Who owns a file: the app (the project file and its local modules), or the package of this hash.
	Owner : [App, Package(Str)]

	## One entry of a header: in the header of `from`, the alias `alias` names the package `hash`.
	Edge : { from : Owner, alias : Str, hash : Str }

	## The entries of the headers of one closure (`Closure.Walked.links`): a link from the header of the project (`Err(Header)`) is from `App`. A link from the header of a release is from `Package(<hash>)`. A link
	## whose target is not a release (a path file or a foreign URL: no hash) is left out, and so is a link from a path file (its files count as app files, R-LD7). The hash is `Ident.of_url` of the URL.
	edges : Closure.Walked -> List(Edge)
	edges = |walked| walked.links.keep_oks(
		|link| {
			to = Ident.of_url(link.to) ? |_| NoHash
			from = match link.from {
				Err(Header) => Ok(App)
				Ok(id) => Ident.of_url(id).map_ok(|owner| Package(owner.hash))
			}
			match from {
				Ok(owner) => Ok({ from: owner, alias: link.alias, hash: to.hash })
				Err(_) => Err(NoHash)
			}
		},
	)

	## A file that the command read: its owner, its absolute path and its text.
	Source : { owner : Owner, path : Str, text : Str }

	## A file to read for the next level.
	Todo : { owner : Owner, path : Str }

	## One level of the scan (the paths are absolute with no `..`). `project_dir` is the dir of the project file. `pkgs` is the packages dir (`Roots.pkgs`). `sources` are the files of this level. `seen` are the paths that the scan has read
	## already, with the ones of this level. For each import line of each source, in the order of the sources and the lines (`Imports.scan`):
	##
	## | Line | Result |
	## | --- | --- |
	## | `import Foo`, `import ./Foo`, `import ../Foo` (a local module) | The file is `Scan.local_file` with the dir of the owner (`project_dir` for `App`, `<pkgs>/<hash>` for `Package(hash)`). The owner of the file is the owner of the source. A package file gives a `used` row for the module (`path` relative to `<pkgs>/<hash>`). The file is in `next` when it is not in `seen`. |
	## | `import alias.Name` with an `edges` row of the owner and the alias | `used` has `{ hash, path: "<Name>.roc" }`. The file `<pkgs>/<hash>/<Name>.roc` of owner `Package(hash)` is in `next` when it is not in `seen`. |
	## | `import alias.Name` and no `edges` row | Nothing (an alias of a path entry or of a foreign URL, or a bad alias) |
	## | A file import (`import "data.json" as d : Str`) | Nothing (`Imports.scan` does not list it) |
	##
	## `used` and `next` have no repeat. `next` is in the order of the first import. `used` is in the order of the first use.
	level : { project_dir : Str, pkgs : Str, edges : List(Edge), sources : List(Source), seen : List(Str) } -> { used : List({ hash : Str, path : Str }), next : List(Todo) }
	level = |facts| {
		place = { project_dir: facts.project_dir, pkgs: facts.pkgs, edges: facts.edges }
		events = facts.sources.join_map(|source| Imports.scan(source.text).keep_oks(|line| event_of(place, source, line)))
		events.fold({ used: [], next: [] }, |acc, event| step(facts.seen, acc, event))
	}
}

Used : { hash : Str, path : Str }

# What one import line gives: the module that it uses (a package file only) and the file to read next.
Event : { used : Try(Used, [None]), next : Uses.Todo }

# R-UM1, R-LD7: an `import` line of one source.
event_of : { project_dir : Str, pkgs : Str, edges : List(Uses.Edge) }, Uses.Source, { from : [Local, Package(Str)], name : Str, line : U64 } -> Try(Event, [Nothing])
event_of = |facts, source, line| match line.from {
	Local => {
		root = match source.owner {
			App => facts.project_dir
			Package(hash) => Text.join(facts.pkgs, hash)
		}
		file = Scan.local_file({ project_dir: root, file: source.path, name: line.name })
		used = match source.owner {
			App => Err(None)
			Package(hash) => if file.starts_with("${root}/") Ok({ hash, path: file.drop_prefix("${root}/") }) else Err(None)
		}
		Ok({ used, next: { owner: source.owner, path: file } })
	}
	Package(alias) => match facts.edges.find_first(|edge| edge.from == source.owner and edge.alias == alias) {
		Err(_) => Err(Nothing)
		Ok(edge) => {
			path = "${line.name}.roc"
			Ok({ used: Ok({ hash: edge.hash, path }), next: { owner: Package(edge.hash), path: Text.join(Text.join(facts.pkgs, edge.hash), path) } })
		}
	}
}

# One event into the lists: no repeat, the order of the first use, and no file that was read.
step : List(Str), { used : List(Used), next : List(Uses.Todo) }, Event -> { used : List(Used), next : List(Uses.Todo) }
step = |seen, acc, event| {
	used = match event.used {
		Ok(row) => if acc.used.contains(row) acc.used else acc.used.append(row)
		Err(None) => acc.used
	}
	known = seen.contains(event.next.path) or acc.next.any(|todo| todo.path == event.next.path)
	{ used, next: if known acc.next else acc.next.append(event.next) }
}
