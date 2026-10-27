import Text
import header.Imports

## The lexical scan of the `import` lines of an app (Resolution 4, R-LD7, R-UM1; CLI 2, R-RV2). Part A (pure). The command reads the files
## and calls `level` once for each import level (TESTING.md 2.3, row 8: `read_files!` for each level).
##
## The scan of one text is `Imports.scan` of the generic package `roc-app-header` (R-GP5: it is not tested again here). This module decides
## which files are read, and which lines name one alias.
##
## The file of a local import (`name` of `Imports.scan`, the answer of the manager to Q5 of slice 008):
##
## | `name` | File |
## | --- | --- |
## | `Foo` | `<project dir>/Foo.roc` |
## | `A/B` | `<project dir>/A/B.roc` |
## | `./X` | `<dir of the importing file>/X.roc` |
## | `../X` | `<dir of the importing file>/../X.roc`, as a path with no `..` (`<parent dir>/X.roc`) |
## | `/X` | `<project dir>/X.roc` (question Q6 of slice 008: not tested) |
##
## The project dir is the dir of the project file. All paths are absolute and have no `..` and no `./`.
Scan :: [].{

	## One file of the scan: its absolute path and its text.
	Source : { path : Str, text : Str }

	## One line that imports the alias: the file, the line number (from 1, as `Imports.scan` gives it) and the text of the line, with no line end.
	Hit : { file : Str, line : U64, text : Str }

	## The files where the scan starts (R-LD7). An app starts at its project file. A package or a platform has no app: it starts at each
	## module that its header exposes. The module `Name` is the file `<dir of the project file>/Name.roc` (the rule of `local_file` for `import Name`).
	## `exposed` is `Header.exposed` of the project header. It is not used for an app.
	roots : { kind : [App, Package, Platform], file : Str, exposed : List(Str) } -> List(Str)
	roots = |facts| match facts.kind {
		App => [facts.file]
		Package | Platform => {
			dir = Text.dir_of(facts.file)
			facts.exposed.map(|name| Scan.local_file({ project_dir: dir, file: facts.file, name }))
		}
	}

	## The absolute path of the file of a local import, by the table above. `file` is the importing file.
	local_file : { project_dir : Str, file : Str, name : Str } -> Str
	local_file = |facts| {
		name = facts.name
		path = if name.starts_with("./") or name.starts_with("../") {
			Text.resolve(Text.dir_of(facts.file), name)
		} else {
			Text.resolve(facts.project_dir, name.drop_prefix("/"))
		}
		"${path}.roc"
	}

	## One level of the scan. `sources` are the files of this level. `seen` are the paths that the scan has read already, with the ones of this level.
	## The result:
	##
	## | Field | Holds |
	## | --- | --- |
	## | `hits` | The import lines of `sources` that name a package alias equal to `alias` (`Package(alias)` of `Imports.scan`, an exact match). In the order of `sources`, then of the lines. |
	## | `next` | The files of the local imports of `sources` (`local_file`) that are not in `seen` and not a path of `sources`, with no repeat, in the order of the first import. The command reads them for the next level. |
	##
	## A file import (`import "data.json" as d : Str`) is no hit and no next file. A package import of another alias is no hit.
	level : { alias : Str, project_dir : Str, sources : List(Source), seen : List(Str) } -> { hits : List(Hit), next : List(Str) }
	level = |facts| {
		scanned = facts.sources.map(|source| (source, Imports.scan(source.text)))
		hits = scanned.join_map(|(source, lines)| lines.keep_oks(|i| hit_of(facts.alias, source, i)))
		here = facts.sources.map(|source| source.path)
		next = scanned
			.join_map(
				|(source, lines)| lines.keep_oks(
					|i| match i.from {
						Local => Ok(Scan.local_file({ project_dir: facts.project_dir, file: source.path, name: i.name }))
						Package(_) => Err(NotLocal)
					},
				),
			)
			.fold([], |found, file| if found.contains(file) or here.contains(file) or facts.seen.contains(file) found else found.append(file))
		{ hits, next }
	}
}

# A hit is an import line of the alias (an exact match). The text of the line has no line end.
hit_of : Str, Scan.Source, { from : [Local, Package(Str)], name : Str, line : U64 } -> Try(Scan.Hit, [NotHit])
hit_of = |alias, source, i| match i.from {
	Package(found) if found == alias => {
		line = source.text.split_on("\n").get(i.line - 1) ?? ""
		Ok({ file: source.path, line: i.line, text: line.trim_end() })
	}
	_ => Err(NotHit)
}
