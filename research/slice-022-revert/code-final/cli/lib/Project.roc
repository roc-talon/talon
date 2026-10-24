import Fail
import Fx
import Members
import Text
import header.Header
import toml.Toml
import toml.Value

## The project file, the workspace and the `talon.toml` of one command (CLI 1 "The project", R-PD1 to R-PD8, R-TF4,
## R-TF5). The search is a walk up from the start directory. The decisions are pure functions over facts that the
## command code collects with `Fx` (`Project.find!`, TESTING.md 2.2). Paths are absolute, with `/` and no `..`.
##
## | Field | Holds | Rule |
## | --- | --- | --- |
## | `file` | The current project file, or `NoCurrent` (a workspace with no current member) | R-PD1, R-PD4, R-PD5 |
## | `workspace` | `Ok({ root, members })`: the root directory and the member files, sorted. `Standalone` otherwise. | R-PD3, R-PD5 |
## | `toml` | The `talon.toml` of the project, or `NoToml` | R-PD6 |
## | `roc_version` | Slice 022: the path of the nearest `.roc-version`, or `None`. The walk starts at the directory of the project file (`file`, G4 of the review of slice 022: so `--file` and the walk agree), or at the first directory of the walk when there is no current member, and goes up to the stop of R-PD2 (the stop directory is checked too). | R-SO5, R-SO18, R-PD2 |
Project := {
	file : Try(Str, [NoCurrent]),
	workspace : Try({ root : Str, members : List(Str) }, [Standalone]),
	toml : Try(Str, [NoToml]),
	roc_version : Try(Str, [None]),
}.{
	is_eq : _

	## The parent directory. `/a/b` gives `/a`. `/a` gives `/`. `/` is `Err(AtRoot)`. No `/` at the end of a result
	## except for `/`.
	parent : Str -> Try(Str, [AtRoot])
	parent = |dir| {
		segments = dir.split_on("/")
		if dir == "/" or dir.is_empty() {
			Err(AtRoot)
		} else {
			up = Str.join_with(segments.drop_last(1), "/")
			Ok(if up.is_empty() "/" else up)
		}
	}

	## The absolute path of `path` for the base directory `base`. A path that starts with `/` stays. Else it is joined to
	## `base`. The result has no `.` segment, no `..` segment (it removes the segment before), no empty segment and no `/`
	## at the end. `..` at the root stays at the root. R-PD1 (`--file` is relative to the current directory).
	absolute : { base : Str, path : Str } -> Str
	absolute = |facts| {
		full = if facts.path.starts_with("/") facts.path else "${facts.base}/${facts.path}"
		kept = full.split_on("/").fold(
			[],
			|segments, segment| if segment.is_empty() or segment == "." {
				segments
			} else if segment == ".." {
				segments.drop_last(1)
			} else {
				segments.append(segment)
			},
		)
		"/${Str.join_with(kept, "/")}"
	}

	## R-PD2: does the walk stop at this directory (after it is checked)? True when the entry names have `.git` (a
	## directory or a file, no difference), or when `dir` is `home`. The file system root is not here: it has no parent
	## (`Project.parent`).
	stops : { dir : Str, names : List(Str), home : Str } -> Bool
	stops = |facts| facts.names.contains(".git") or facts.dir == facts.home

	## Reads the text of a `talon.toml` for a `[workspace]` table (R-PD3). Gives `Err(NoWorkspace)` when the file has no
	## `[workspace]` table, else the `members` patterns (a `[workspace]` with no `members` key gives `[]`: question Q4).
	## Text that is not TOML, or a `members` that is not a list of strings, is `Err({ line, message })` (R-TF4):
	## the line is 1-based (the line of the TOML error, or of the key `members`). The message is fixed text, so that no
	## expected file depends on the text of `roc-toml`: `not valid TOML` for text that does not parse, and
	## `the key workspace.members must be a list of strings` for a `members` of another form.
	## The code uses `roc-toml` (`Toml.parse`, `Toml.get`, `Toml.line`).
	workspace_of : Str -> Try(Try(List(Str), [NoWorkspace]), { line : U64, message : Str })
	workspace_of = |text| match Toml.parse(text) {
		Err(TomlErr(e)) => Err({ line: e.line, message: "not valid TOML" })
		Ok(doc) => match Toml.get(doc, ["workspace"]) {
			Ok(Value.Table(_)) => match Toml.get(doc, ["workspace", "members"]) {
				Err(NotFound) => Ok(Ok([]))
				Ok(Value.Array(values)) => match values.map_try(
					|v| match v {
						Value.String(pattern) => Ok(pattern)
						_ => Err(NotText)
					},
				) {
					Ok(patterns) => Ok(Ok(patterns))
					Err(NotText) => Err(bad_members(doc))
				}
				Ok(_) => Err(bad_members(doc))
			}
			_ => Ok(Err(NoWorkspace))
		}
	}

	## The workspace root of a walk (R-PD3): the nearest directory with a `talon.toml` that has a `[workspace]` table.
	## `walk` is the directories from the start directory up to the stop (R-PD2), nearest first. Each has the entry names
	## and the text of its `talon.toml` (`Err(None)` when it has none). The files are read nearest first, and the read
	## stops at the root: a `talon.toml` above it is never read. A `talon.toml` that does not parse before the root is
	## found is a failure (kind `Input`, exit 19, R-TF4). The message is `<dir>/talon.toml:<line>: <message>` with the message
	## of `workspace_of`.
	root_of : { walk : List({ dir : Str, names : List(Str), toml : Try(Str, [None]) }) } -> Try(Try({ dir : Str, patterns : List(Str) }, [NoWorkspace]), Fail)
	root_of = |facts| root_search(facts.walk)

	## The choice of the project (R-PD1, R-PD4, R-PD5, R-PD6). The rules are in the slice file, "Rules for the code
	## agent". `file` is the absolute path of `--file`, or `Unset`. `walk` is as in `root_of`. `members` is the member
	## files of the root of `root_of` (`Members.step`), or `[]` with no root. A failure has the kind `Usage`
	## (exit 2) or `Input` (R-TF4).
	find : { file : Try(Str, [Unset]), walk : List({ dir : Str, names : List(Str), toml : Try(Str, [None]) }), members : List(Str) } -> Try(Project, Fail)
	find = |facts| {
		root = Project.root_of({ walk: facts.walk })?
		root_dir = match root {
			Ok(r) => Ok(r.dir)
			Err(NoWorkspace) => Err(NoRoot)
		}
		chosen = match facts.file {
			Ok(file) => Ok(file)
			Err(Unset) => pick_file(facts.walk, facts.members, root_dir)?
		}
		workspace = match root_dir {
			Ok(dir) => Ok({ root: dir, members: facts.members })
			Err(NoRoot) => Err(Standalone)
		}
		match chosen {
			Err(NoFile) => match root_dir {
				Ok(dir) => Ok({ file: Err(NoCurrent), workspace, toml: nearest_toml(facts.walk, first_dir(facts.walk), dir), roc_version: nearest_version(facts.walk, first_dir(facts.walk)) })
				Err(NoRoot) => Err(Fail.new(Usage, "no project file found. Checked: ${Str.join_with(facts.walk.map(|d| d.dir), ", ")}. Pass --file <path>."))
			}
			Ok(file) => match (root_dir, facts.members.contains(file)) {
				(Ok(dir), Bool.True) => Ok({ file: Ok(file), workspace, toml: nearest_toml(facts.walk, Text.dir_of(file), dir), roc_version: nearest_version(facts.walk, Text.dir_of(file)) })
				_ => Ok({ file: Ok(file), workspace: Err(Standalone), toml: own_toml(facts.walk, Text.dir_of(file), root_dir), roc_version: nearest_version(facts.walk, Text.dir_of(file)) })
			}
		}
	}

	## R-PD8 and R-TF5: the header of a project file. `NoHeader` (the file has no app, package or platform header):
	## kind `Usage` (exit 2), message `<path> has no app, package or platform header`. A header that the parser cannot
	## read: kind `Input` (exit 19), message `<path>:<line>: the header is not valid`. The line is 1-based, the line of
	## the byte offset that `Header.parse` gives. The code uses `roc-app-header` (`Header.parse`).
	check_header : { path : Str, text : Str } -> Try([App, Package, Platform], Fail)
	check_header = |facts| match Header.parse(facts.text) {
		Ok(header) => match Header.kind(header) {
			App => Ok(App)
			Package => Ok(Package)
			Platform(_) => Ok(Platform)
		}
		Err(NoHeader) => Err(Fail.new(Usage, "${facts.path} has no app, package or platform header"))
		Err(BadHeader({ offset })) => {
			line = 1 + facts.text.to_utf8().sublist({ start: 0, len: offset }).keep_if(|b| b == 10).len()
			Err(Fail.new(Input, "${facts.path}:${line.to_str()}: the header is not valid"))
		}
	}

	## The search with effects (R-PD1 to R-PD8). `start` is the current directory. `file` is `--file` (relative to
	## `start`). `home` is `$HOME`. The calls, in order (the L2 case `project/pd-search` fixes them):
	##
	## | Step | Call |
	## | --- | --- |
	## | 1 | With `file`: `canonical!` of `Project.absolute` of it (one call). A failure is `Usage` (question Q5). The directory of the file is the start directory. |
	## | 2 | `list_dirs!` of one directory for each call: the start directory, then each parent until `Project.stops` or `Project.parent` ends the walk |
	## | 3 | `read_files!` of the `talon.toml` of all the directories of the walk that have one (one call, nearest first), when there is one |
	## | 4 | With a workspace root: `list_dirs!` for each `Need` of `Members.step`, until `Done` |
	## | 5 | `read_files!` of the project file, then `Project.check_header` |
	##
	## With no project file (no current member), step 5 does not run.
	find! : Fx, { start : Str, file : Try(Str, [Unset]), home : Str } => Try(Project, Fail)
	find! = |fx, facts| {
		start_and_file = match facts.file {
			Ok(typed) => match fx.canonical!([Project.absolute({ base: facts.start, path: typed })]) {
				[Ok(real)] => Ok((Text.dir_of(real), Ok(real)))
				_ => Err(Fail.new(Usage, "${typed}: no such file"))
			}
			Err(Unset) => Ok((facts.start, Err(Unset)))
		}
		(start, file) = start_and_file?
		listed_walk = walk!(fx, start, facts.home, [])
		walk = read_tomls!(fx, listed_walk)?
		members = match Project.root_of({ walk: walk })? {
			Ok(root) => expand_members!(fx, root, listed_walk)
			Err(NoWorkspace) => []
		}
		project = Project.find({ file, walk, members })?
		match project.file {
			Ok(path) => {
				text = read_text!(fx, path)?
				_ = Project.check_header({ path, text })?
				Ok(project)
			}
			Err(NoCurrent) => Ok(project)
		}
	}
}

Dir : { dir : Str, names : List(Str), toml : Try(Str, [None]) }

# A directory of the walk with its listing (step 2 of `find!`).
Listing : { dir : Str, names : List(Str), entries : List({ name : Str, is_dir : Bool }) }

bad_members : Toml -> { line : U64, message : Str }
bad_members = |doc| {
	line = match Toml.line(doc, ["workspace", "members"]) {
		Ok(n) => n
		Err(NoEntry) => 1
	}
	{ line, message: "the key workspace.members must be a list of strings" }
}

# Nearest first. A file above the root is never parsed (R-PD2, R-PD3).
root_search : List(Dir) -> Try(Try({ dir : Str, patterns : List(Str) }, [NoWorkspace]), Fail)
root_search = |walk| match walk {
	[] => Ok(Err(NoWorkspace))
	[d, .. as above] => match d.toml {
		Err(None) => root_search(above)
		Ok(text) => match Project.workspace_of(text) {
			Err(e) => Err(Fail.new(Input, "${d.dir}/talon.toml:${e.line.to_str()}: ${e.message}"))
			Ok(Ok(patterns)) => Ok(Ok({ dir: d.dir, patterns }))
			Ok(Err(NoWorkspace)) => root_search(above)
		}
	}
}

# R-PD4: the project file of a walk with no `--file`. In each directory, nearest first: 2 member files or more is a
# usage failure, 1 is the file, and none gives the `main.roc` of the directory when it is not the root.
pick_file : List(Dir), List(Str), Try(Str, [NoRoot]) -> Try(Try(Str, [NoFile]), Fail)
pick_file = |walk, members, root_dir| match walk {
	[] => Ok(Err(NoFile))
	[d, .. as above] => {
		own = members.keep_if(|m| Text.dir_of(m) == d.dir)
		is_root = root_dir == Ok(d.dir)
		match own {
			[only] => Ok(Ok(only))
			[] => if !is_root and d.names.contains("main.roc") Ok(Ok(Text.join(d.dir, "main.roc"))) else pick_file(above, members, root_dir)
			_ => Err(Fail.new(Usage, "${d.dir} has ${own.len().to_str()} member files: ${Str.join_with(own, ", ")}. Pass --file <path>."))
		}
	}
}

first_dir : List(Dir) -> Str
first_dir = |walk| match walk {
	[d, ..] => d.dir
	[] => "/"
}

# R-PD6: the nearest `talon.toml` from `from` up to the root, the root included.
nearest_toml : List(Dir), Str, Str -> Try(Str, [NoToml])
nearest_toml = |walk, from, root_dir| match walk {
	[] => Err(NoToml)
	[d, .. as above] => if d.dir != from {
		nearest_toml(above, from, root_dir)
	} else {
		climb_toml(walk, root_dir)
	}
}

climb_toml : List(Dir), Str -> Try(Str, [NoToml])
climb_toml = |walk, root_dir| match walk {
	[] => Err(NoToml)
	[d, .. as above] => match d.toml {
		Ok(_) => Ok(Text.join(d.dir, "talon.toml"))
		Err(None) => if d.dir == root_dir Err(NoToml) else climb_toml(above, root_dir)
	}
}

# R-SO5, R-PD2: the nearest `.roc-version` from `from` up to the stop of the walk (the stop directory is in the walk).
nearest_version : List(Dir), Str -> Try(Str, [None])
nearest_version = |walk, from| match walk {
	[] => Err(None)
	[d, .. as above] => if d.dir != from {
		nearest_version(above, from)
	} else {
		climb_version(walk)
	}
}

climb_version : List(Dir) -> Try(Str, [None])
climb_version = |walk| match walk {
	[] => Err(None)
	[d, .. as above] => if d.names.contains(".roc-version") Ok(Text.join(d.dir, ".roc-version")) else climb_version(above)
}

# A project file that is not a member: the `talon.toml` of its own directory, when that is not the root file.
own_toml : List(Dir), Str, Try(Str, [NoRoot]) -> Try(Str, [NoToml])
own_toml = |walk, dir, root_dir| match walk.find_first(|d| d.dir == dir) {
	Ok(d) => match d.toml {
		Ok(_) => if root_dir == Ok(dir) Err(NoToml) else Ok(Text.join(dir, "talon.toml"))
		Err(None) => Err(NoToml)
	}
	Err(_) => Err(NoToml)
}

# Step 2 of `find!`: one `list_dirs!` for each directory, up to the first stop.
walk! : Fx, Str, Str, List(Listing) => List(Listing)
walk! = |fx, dir, home, walked| {
	entries = match fx.list_dirs!([dir]) {
		[Ok(found)] => found.map(|e| { name: e.name, is_dir: e.is_dir })
		_ => []
	}
	names = entries.map(|e| e.name)
	more = walked.append({ dir, names, entries })
	if Project.stops({ dir, names, home }) {
		more
	} else {
		match Project.parent(dir) {
			Ok(up) => walk!(fx, up, home, more)
			Err(AtRoot) => more
		}
	}
}

# Step 3 of `find!`: one `read_files!` for the `talon.toml` of the directories that have one.
read_tomls! : Fx, List(Listing) => Try(List(Dir), Fail)
read_tomls! = |fx, listed| {
	paths = listed.keep_if(|l| l.names.contains("talon.toml")).map(|l| Text.join(l.dir, "talon.toml"))
	texts = if paths.is_empty() [] else fx.read_files!(paths)
	var $texts = texts
	var $dirs = []
	for l in listed {
		toml = if l.names.contains("talon.toml") {
			match $texts {
				[first, .. as rest] => {
					$texts = rest
					match first {
						Ok(text) => Ok(text)
						Err(_) => return Err(Fail.new(Environment, "cannot read ${Text.join(l.dir, "talon.toml")}"))
					}
				}
				[] => Err(None)
			}
		} else {
			Err(None)
		}
		$dirs = $dirs.append({ dir: l.dir, names: l.names, toml })
	}
	Ok($dirs)
}

# Step 4 of `find!`: `Members.step` again with the listings that it needs.
expand_members! : Fx, { dir : Str, patterns : List(Str) }, List(Listing) => List(Str)
expand_members! = |fx, root, listed| match Members.step({ root: root.dir, patterns: root.patterns, listed: listed.map(|l| { dir: l.dir, entries: l.entries }) }) {
	Done(files) => files
	Need(dirs) => {
		more = fx.list_dirs!(dirs).map2(
			dirs,
			|result, dir| match result {
				Ok(found) => { dir, names: found.map(|e| e.name), entries: found.map(|e| { name: e.name, is_dir: e.is_dir }) }
				Err(_) => { dir, names: [], entries: [] }
			},
		)
		expand_members!(fx, root, listed.concat(more))
	}
}

read_text! : Fx, Str => Try(Str, Fail)
read_text! = |fx, path| match fx.read_files!([path]) {
	[Ok(text)] => Ok(text)
	_ => Err(Fail.new(Environment, "cannot read ${path}"))
}
