import Fail
import Text

## Which `talon.toml` holds the script (slice 057, CLI 1: R-RUN11, R-RUN12, R-PD2, R-PD3, R-PD5, R-PD6, R-PD9, Design 4.4 R-WS5, user answers NC2, NC4, NC5 of the draft D-TS). Part A (pure, TESTING.md 2.2). `RunFlow` collects the facts with `Project.scan!` and calls `find`.
##
## The walk goes up from the current directory (R-PD2), nearest directory first. For each directory that has a `talon.toml`, the file is one of 3 kinds:
##
## | Kind | The file | Rule |
## | --- | --- | --- |
## | `Root` | has a `[workspace]` table: the workspace root (R-PD3), the first one on the walk | R-WS5 |
## | `Member` | is a file of a workspace (a member file is in its directory, or below it up to the next directory with a `talon.toml`) and has no `[workspace]` table | R-WS5, NC4 |
## | `Standalone` | any other `talon.toml`: with no workspace, or inside a workspace directory with no member file of its own (the file of a standalone project, R-PD5, R-PD6) | NC2, NC4 |
##
## The walk stops after a `Root` file and after a `Standalone` file: the scripts of a file above them have no effect (NC5, R-RUN12). A `Member` file that has no such script gives the walk to the directory above it. The first file that has the name holds the script.
## With no name (R-RUN11, answer Q1 of the review of slice 057) the first file on the walk that has at least one script holds the list.
RunFind :: [].{

	## One directory of the walk: its path, and its `talon.toml` as `RunFlow` read it: `names` are the script names of its `[scripts]` table, `bad` is the first failure of the form of that table (`Ok(<path>:<line>: <message>>)`, R-RUN1).
	Dir : { dir : Str, toml : Try({ names : List(Str), bad : Try(Str, [None]) }, [None]) }

	## What the walk and the workspace tell: `walk` (nearest first), `root` (the workspace root directory of the walk, `Err(NoWorkspace)` for none), `members` (the absolute member files of the root, sorted), `probes` (the `talon.toml` files that a `Need` asked about: the path and whether it exists).
	Facts : { name : Try(Str, [None]), walk : List(RunFind.Dir), root : Try(Str, [NoWorkspace]), members : List(Str), probes : List({ path : Str, exists : Bool }) }

	## The file that holds the script: its directory, its kind, the directory whose `talon.toml` has the `[tools]` table (R-RUN3 point 2, OP4: the workspace root for `Root` and `Member`, the directory itself for `Standalone`), the member files of its node
	## (R-PD9: all members for `Root`, the members whose node it is for `Member`, none for `Standalone`), and the directory where the walk stopped (R-RUN8).
	Found : { dir : Str, kind : [Root, Member, Standalone], tools_dir : Str, members : List(Str), stop : Str }

	## R-RUN12: the choice. `Err(Need(<paths>))`: the caller must tell, for each path (a `talon.toml` that may exist), whether it exists (`probes`), and call again. A path is asked only when a member file is below a `talon.toml` directory of the walk and the kind of that file depends on the
	## directories between (NC4). `Err(Fail)`: kind `Usage` (exit 2) when no file has the name, with the files that the walk checked; kind `Input` (exit 19) when a file that the walk examined has a `[scripts]` table with a bad form (R-RUN1). The text is a proposal (TW24):
	##
	## | Case | Message |
	## | --- | --- |
	## | A name that no file has | `no script '<name>' in the talon.toml files that the walk checked: <file>, <file>.` (nearest first, the files that were examined; the text `none` for no file: `no talon.toml found. Checked: <dir>, <dir>.` lists the directories of the walk) |
	## | No name, and no file has a script | `no script in the talon.toml files that the walk checked: <file>, <file>.` or `no talon.toml found. Checked: <dir>, <dir>.` |
	find : RunFind.Facts -> Try(RunFind.Found, [Need(List(Str)), Stop(Fail)])
	find = |facts| {
		stop = match facts.root {
			Ok(dir) => dir
			Err(NoWorkspace) => match facts.walk.last() {
				Ok(last) => last.dir
				Err(_) => ""
			}
		}
		search(facts, stop, facts.walk, [])
	}
}

# One step of the walk, nearest directory first. `seen` are the files that were examined.
search : RunFind.Facts, Str, List(RunFind.Dir), List(Str) -> Try(RunFind.Found, [Need(List(Str)), Stop(Fail)])
search = |facts, stop, walk, seen| match walk {
	[] => Err(Stop(not_found(facts, seen)))
	[d, .. as above] => match d.toml {
		Err(None) => search(facts, stop, above, seen)
		Ok(file) => {
			checked = seen.append(Text.join(d.dir, "talon.toml"))
			match file.bad {
				Ok(message) => Err(Stop(Fail.new(Input, message)))
				Err(None) => {
					kind = kind_of(facts, d.dir)?
					holds = match facts.name {
						Ok(name) => file.names.contains(name)
						Err(None) => !file.names.is_empty()
					}
					if holds {
						Ok(found(facts, stop, d.dir, kind))
					} else {
						match kind {
							Member(_) => search(facts, stop, above, checked)
							_ => Err(Stop(not_found(facts, checked)))
						}
					}
				}
			}
		}
	}
}

# The kind of the file in `dir`. `Member(files)` carries the member files of its node.
Kind : [Root, Member(List(Str)), Standalone]

# R-WS5, NC2, NC4: the root is the root. In a workspace, a file with a member file in its directory is a member file. A member file below it makes it a member file too, unless a `talon.toml` is between (the answer of a probe). Else it is a standalone file.
kind_of : RunFind.Facts, Str -> Try(Kind, [Need(List(Str))])
kind_of = |facts, dir| match facts.root {
	Ok(root) => if root == dir Ok(Root) else member_kind(facts, dir)
	Err(NoWorkspace) => Ok(Standalone)
}

# A file in a workspace that is not the root.
member_kind : RunFind.Facts, Str -> Try(Kind, [Need(List(Str))])
member_kind = |facts, dir| {
	own = facts.members.keep_if(|m| Text.dir_of(m) == dir)
	below = facts.members.keep_if(|m| Text.dir_of(m).starts_with("${dir}/"))
	asked = Text.sorted_unique(below.join_map(|m| unknown_between(facts, dir, Text.dir_of(m))))
	if !asked.is_empty() {
		Err(Need(asked))
	} else {
		node = own.concat(below.keep_if(|m| open_to(facts, dir, Text.dir_of(m))))
		if node.is_empty() Ok(Standalone) else Ok(Member(node))
	}
}

# The `talon.toml` path of a directory strictly under `top`, up to `from` (nearest first): the paths between a member file and the file in `top`.
between : Str, Str -> List(Str)
between = |top, from| if from == top or !from.starts_with("${top}/") [] else between(top, Text.dir_of(from)).prepend(Text.join(from, "talon.toml"))

# The path of `between` to ask: the nearest one that is not known to be absent, when it is not known to exist.
unknown_between : RunFind.Facts, Str, Str -> List(Str)
unknown_between = |facts, top, from| {
	match between(top, from).find_first(|p| answer(facts, p) != No) {
		Ok(path) => match answer(facts, path) {
			Unknown => [path]
			_ => []
		}
		Err(_) => []
	}
}

# Does the member file in `from` have no `talon.toml` between it and `top`?
open_to : RunFind.Facts, Str, Str -> Bool
open_to = |facts, top, from| between(top, from).all(|p| answer(facts, p) == No)

answer : RunFind.Facts, Str -> [Yes, No, Unknown]
answer = |facts, path| match facts.probes.find_first(|p| p.path == path) {
	Ok(probe) => if probe.exists Yes else No
	Err(_) => Unknown
}

found : RunFind.Facts, Str, Str, Kind -> RunFind.Found
found = |facts, stop, dir, kind| match kind {
	Root => { dir, kind: Root, tools_dir: dir, members: facts.members, stop }
	Member(node) => { dir, kind: Member, tools_dir: stop, members: node, stop }
	Standalone => { dir, kind: Standalone, tools_dir: dir, members: [], stop }
}

# R-RUN12: no file has the script. The text lists the files that the walk checked, or the directories when it found no `talon.toml`.
not_found : RunFind.Facts, List(Str) -> Fail
not_found = |facts, seen| if seen.is_empty() {
	Fail.new(Usage, "no talon.toml found. Checked: ${Str.join_with(facts.walk.map(|d| d.dir), ", ")}.")
} else {
	what = match facts.name {
		Ok(name) => "script '${name}'"
		Err(None) => "script"
	}
	Fail.new(Usage, "no ${what} in the talon.toml files that the walk checked: ${Str.join_with(seen, ", ")}.")
}
