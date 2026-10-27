import Text

## The member files of a workspace (Design 4.4, R-PD3, R-PD4). `members` is a list of patterns in the root
## `talon.toml`, for example `["apps/*/main.roc", "examples/*.roc"]`.
##
## The glob syntax is not in the design (question Q3 of the slice file). The tests use this default:
##
## | Part | Meaning |
## | --- | --- |
## | A pattern | A relative path with `/` between segments. No `..`, no `**`. |
## | A segment | Literal text, or text with `*`. `*` matches any run of characters (also none) in one name. |
## | The last segment | Names files (not directories). The other segments name directories. |
Members :: [].{

	## Does one segment pattern match one name? `*` matches any run of characters (also none).
	## `matches("*.roc", "hello.roc")` is true. `matches("*.roc", "hello.roc.bak")` is false.
	## `matches("a*c", "abbc")` is true. `matches("main.roc", "main.roc")` is true.
	matches : Str, Str -> Bool
	matches = |pattern, name| match pattern.split_on("*") {
		[] => name == pattern
		[only] => name == only
		[first, .. as rest] => name.starts_with(first) and match_rest(name.drop_prefix(first), rest)
	}

	## One step of the expansion. The command code calls it again with more listings, as the solver step does
	## (TESTING.md 2.2, part B). `root` is the absolute directory of the root `talon.toml`. `listed` has the listing of
	## each directory that the command listed so far (`Fx.list_dirs!`), in any order. A directory that is missing
	## has the entries `[]`.
	##
	## | Result | Meaning |
	## | --- | --- |
	## | `Need(dirs)` | The directories to list next, with no repeat, sorted (absolute). Directories that `listed` already has are not in it. |
	## | `Done(files)` | The member files, absolute, with no repeat, sorted |
	##
	## A pattern with `n` segments needs the directories `root`, then the matching child directories of each level, to
	## the level `n - 1`. `Need` has the first missing level of each pattern, joined for all the patterns.
	## With `listed = []`, `Need([root])`.
	step : { root : Str, patterns : List(Str), listed : List({ dir : Str, entries : List({ name : Str, is_dir : Bool }) }) } -> [Need(List(Str)), Done(List(Str))]
	step = |facts| {
		results = facts.patterns.map(|p| expand({ dirs: [facts.root], segs: segments(p), listed: facts.listed }))
		needs = results.join_map(
			|r| match r {
				Need(dirs) => dirs
				Files(_) => []
			},
		)
		if needs.is_empty() {
			Done(
				Text.sorted_unique(
					results.join_map(
						|r| match r {
							Files(files) => files
							Need(_) => []
						},
					),
				),
			)
		} else {
			Need(Text.sorted_unique(needs))
		}
	}
}

Listed : List({ dir : Str, entries : List({ name : Str, is_dir : Bool }) })

# `rest` are the parts after the first `*`: the last part must end the name, and the parts between must occur in order.
match_rest : Str, List(Str) -> Bool
match_rest = |name, parts| match parts {
	[last] => name.ends_with(last)
	[part, .. as more] => if part.is_empty() {
		match_rest(name, more)
	} else {
		match name.split_first(part) {
			Ok(cut) => match_rest(cut.after, more)
			Err(_) => Bool.False
		}
	}
	[] => Bool.False
}

segments : Str -> List(Str)
segments = |pattern| pattern.split_on("/").keep_if(|s| !s.is_empty() and s != ".")

# One pattern, level by level. `Need` has the directories of the first level that is not listed yet.
expand : { dirs : List(Str), segs : List(Str), listed : Listed } -> [Need(List(Str)), Files(List(Str))]
expand = |facts| {
	missing = facts.dirs.keep_if(|d| entries_of(facts.listed, d) == Err(NotListed))
	if !missing.is_empty() {
		Need(missing)
	} else {
		match facts.segs {
			[] => Files([])
			[last] => Files(facts.dirs.join_map(|d| (entries_of(facts.listed, d) ?? []).keep_if(|e| !e.is_dir and Members.matches(last, e.name)).map(|e| Text.join(d, e.name))))
			[seg, .. as rest] => {
				children = facts.dirs.join_map(|d| (entries_of(facts.listed, d) ?? []).keep_if(|e| e.is_dir and Members.matches(seg, e.name)).map(|e| Text.join(d, e.name)))
				expand({ dirs: children, segs: rest, listed: facts.listed })
			}
		}
	}
}

entries_of : Listed, Str -> Try(List({ name : Str, is_dir : Bool }), [NotListed])
entries_of = |listed, dir| match listed.find_first(|l| l.dir == dir) {
	Ok(l) => Ok(l.entries)
	Err(_) => Err(NotListed)
}
