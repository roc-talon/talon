import Fail
import Ident
import Index
import Intent
import Locked
import Ranges
import Text

## The variables of one resolve (Resolution 1, R-VA1 to R-VA6, Design 4.3 R-I2 to R-I9, Design 4.4 R-WS1 to R-WS10) and the scope of a command
## (Resolution 9, R-SP1 to R-SP14). All functions are pure. The command code (`Resolve.run!`) reads the files and gives the members.
##
## One variable for each group (R-ID2, Design 4.1): the URL form and the series. A member entry belongs to the variable of its group,
## whatever its alias (R-WS1). Two series of one package are 2 variables (R-WS10). A platform group is a variable like a package group (R-WS9).
## The nightly is not a variable in P0: it is held (`Pin`). A package that is not in a header is not a variable (R-I6, MVS).
Vars :: [].{

	## A member of the project: a workspace member, or the project file of a standalone project (one member). `toml` is the nearest `talon.toml`
	## (`Project.toml`, R-PD6) with its text read (`Intent.read`), or `NoToml`.
	Member : { file : Str, locked : Locked, toml : Try({ path : Str, intent : Intent }, [NoToml]) }

	## One variable. `uses` are the member entries of the group (`alias`, `url`, `version` as in the header, in the order of the members).
	## `ranges` are the constraints of R-C1 and R-WS2: for each use, the range of the key of its alias in `[dependencies]` or `[overrides]` of the
	## `talon.toml` of its member (R-I3, R-WS7: this range limits the variable of all members), else the implied range of its version (R-I4).
	## A range text that an earlier row has is not repeated. `from` is `<path>:<line>` for a `talon.toml` key, `implied by <file>` for an implied
	## range, and `selector` for the range of `update X@sel`. `host` is `Index.host_kind` of the first use (R-DI11).
	Var : {
		group : { form : Str, series : Str },
		name : Try(Str, [NoName]),
		is_platform : Bool,
		host : [Indexed, Fixed(Str)],
		uses : List({ file : Str, alias : Str, url : Str, version : Str }),
		ranges : List({ range : Str, from : Str }),
	}

	## A key of `talon.toml` that no member under that file has as an alias (Design 4.3 row "no, yes", R-I5, R-WS6). `table` is where the key is.
	## `name` is `Ok(full name)` when the value names `owner/repo` or `host/path`, else `Err(Short(text))` with the name that was typed, or the key. `range` is the range
	## of the value (`^1` for `"^1"` and for `"roc-lang/http@^1"`). `from` is `<path>:<line>`. `members` are the member files under the file whose nearest
	## `talon.toml` it is. `stale` is `Ok(alias)` when a header of these members has an entry with the same full name whose version the range admits: the key is
	## the group under another alias (R-I8, R-I9). `Err(None)` for a short name.
	Want : {
		key : Str,
		table : [Dependencies, Overrides],
		name : Try(Str, [Short(Str)]),
		range : Str,
		from : Str,
		members : List(Str),
		stale : Try(Str, [None]),
	}

	## The variables in the order of `priority` (R-VA6), and the wants in the order of the files and keys.
	##
	## Order of the variables: first the packages, then the platform groups, each in the order of the first use (members in order, header order); then the
	## `priority` names (aliases, `Intent.resolution.priority`) go to the front in their order. A name that matches no variable is ignored. `roc` is ignored
	## (the nightly is held in P0). R-VA6.
	##
	## Failure (kind `Usage`, exit 2, R-WS6): a want that no header has, with 2 or more members: `<from>: the key '<key>' is in no header, and <n> members are under
	## <dir of the file>: <file>, <file>. Run tln add --file <member file> <name> for one of them.` unless `stale` is `Ok` (then it is no failure).
	## `<name>` is the full name or the key. Text: a proposal (TW24).
	build : { members : List(Member), priority : Try(List(Str), [Unset]) } -> Try({ vars : List(Var), wants : List(Want) }, Fail)
	build = |facts| {
		uses = uses_of(facts.members)
		groups = ordered_groups(uses)
		vars = groups.map(|group| variable_of(facts.members, uses.keep_if(|u| u.group == group), group))
		wants = wants_of(facts.members)?
		Ok({ vars: with_priority(vars, facts.priority), wants })
	}

	## A variable with its state for one command. `free`: the command may choose its value (R-SP1). `any_series`: the domain is the releases of the URL form in any
	## series (`update X@sel`, R-SP5). `note` is a line for the command to print.
	Scoped : { variable : Var, free : Bool, any_series : Bool, note : Try(Str, [None]) }

	## The free and held variables of a command (R-SP1 to R-SP3, R-SP5, R-SP10, R-SP11, R-SP19 to R-SP21, R-WS8, R-DI11). `names` are the aliases that the user named (the
	## command resolved them with `Lookup.find` first). `selectors` are the ranges of `X@sel` (`Selector.Range` text, `Exact` as `=<v>`, `Latest` as `*`).
	##
	## | Command | Free | Held |
	## | --- | --- | --- |
	## | `Install`, no names | A variable with an entry that is outside the intersection of its ranges (R-SP20). A key that no header has is a want, not a variable. With no `talon.toml` and one member nothing is outside (R-SP21). | All others (R-SP19) |
	## | `Update`, no names | Each variable with a `host` that is `Indexed` (R-SP2) | A `Fixed` host (R-VA5, R-DI11) |
	## | `Update`, names | The named variables (R-SP3) | All others |
	##
	## A named variable with a selector: its `ranges` are the one range of the selector (`from` is `selector`), and `any_series` is true (R-SP5). A named variable
	## with a `Fixed` host is held, with the note `Index.fixed_line(host)` (R-DI11: no command frees it, also when named).
	## The order of the result is the order of `vars`.
	##
	## Failures (kind `Usage`, exit 2): a name that is no alias of a variable: `'<x>' is not in the project` (slice 004, Q7). A name that is the alias of 2 or more
	## variables (R-WS8: members use one alias for 2 groups): `"<x>" matches <n> packages. Use a name from the list.` (the line of the tie of R-SC14: `Lookup.find` prints the list before it, so
	## this line is a backstop).
	scope : {
		command : [Install, Update],
		names : List(Str),
		selectors : List({ alias : Str, range : Str }),
		vars : List(Var),
	} -> Try(List(Scoped), Fail)
	scope = |facts| {
		named = named_indexes(facts.vars, facts.names)?
		selected = facts.selectors.map_try(|sel| named_indexes(facts.vars, [sel.alias]).map_ok(|idx| (idx, sel.range)))?
		Ok(facts.vars.map_with_index(|variable, i| scoped_one(facts.command, facts.names.is_empty(), named.contains(i), selected.find_first(|(idx, _)| idx.contains(i)), variable)))
	}

	## The names that the picker of `tln update -i` lists (R-SP14, prompt R-NI2): the first alias of each variable that `Update` with no names frees, in the order of `vars`. The nightly
	## is not in the list (R-RP1).
	picker : List(Var) -> List(Str)
	picker = |vars| vars.keep_if(|v| v.host == Indexed).keep_oks(|v| v.uses.first().map_ok(|u| u.alias))
}

Use : { file : Str, alias : Str, url : Str, version : Str, group : { form : Str, series : Str }, is_platform : Bool, name : Try(Str, [NoName]) }

# The release entries of all members, in the order of the members and of each header.
uses_of : List(Vars.Member) -> List(Use)
uses_of = |members| members.join_map(
	|m| m.locked.rows.keep_oks(
		|row| match row.what {
			Release(ident) => Ok({ file: m.file, alias: row.alias, url: row.value, version: ident.version, group: ident.group, is_platform: row.is_platform, name: ident.name })
			_ => Err(NotRelease)
		},
	),
)

# R-VA6: the groups in the order of the first use, the packages first, then the platforms.
ordered_groups : List(Use) -> List({ form : Str, series : Str })
ordered_groups = |uses| {
	firsts = uses.fold([], |found, u| if found.any(|f| f.group == u.group) found else found.append(u))
	firsts.keep_if(|u| !u.is_platform).concat(firsts.keep_if(|u| u.is_platform)).map(|u| u.group)
}

variable_of : List(Vars.Member), List(Use), { form : Str, series : Str } -> Vars.Var
variable_of = |members, uses, group| {
	first = match uses {
		[u, ..] => u
		[] => crash "a group has a use"
	}
	{
		group,
		name: first.name,
		is_platform: first.is_platform,
		host: Index.host_kind(first.url),
		uses: uses.map(|u| { file: u.file, alias: u.alias, url: u.url, version: u.version }),
		ranges: uses.fold([], |found, u| add_range(found, range_of(members, u))),
	}
}

add_range : List({ range : Str, from : Str }), { range : Str, from : Str } -> List({ range : Str, from : Str })
add_range = |found, r| if found.any(|f| f.range == r.range) found else found.append(r)

# R-I3, R-I4: the range of the key of the alias in the `talon.toml` of the member, else the implied range of the version.
range_of : List(Vars.Member), Use -> { range : Str, from : Str }
range_of = |members, u| {
	keyed = match members.find_first(|m| m.file == u.file) {
		Ok({ toml: Ok(t), .. }) => match t.intent.deps.find_first(|d| d.key == u.alias) {
			Ok(d) => Ok({ range: d.range, from: "${t.path}:${d.line.to_str()}" })
			Err(_) => match t.intent.overrides.find_first(|d| d.key == u.alias) {
				Ok(d) => Ok({ range: d.range, from: "${t.path}:${d.line.to_str()}" })
				Err(_) => Err(NoKey)
			}
		}
		_ => Err(NoKey)
	}
	match keyed {
		Ok(r) => r
		Err(NoKey) => { range: Ranges.implied(u.version) ?? "*", from: "implied by ${u.file}" }
	}
}

# R-VA6: the names of `priority` (aliases) go to the front, in their order. A name that matches nothing is ignored.
with_priority : List(Vars.Var), Try(List(Str), [Unset]) -> List(Vars.Var)
with_priority = |vars, priority| match priority {
	Err(Unset) => vars
	Ok(names) => {
		front = names.fold(
			[],
			|picked, name| match vars.find_first(|v| v.uses.any(|u| u.alias == name) and !picked.contains(v)) {
				Ok(v) => picked.append(v)
				Err(_) => picked
			},
		)
		front.concat(vars.keep_if(|v| !front.contains(v)))
	}
}

# R-I5, R-I8, R-WS6: the keys of each `talon.toml` that no member under it has as an alias.
wants_of : List(Vars.Member) -> Try(List(Vars.Want), Fail)
wants_of = |members| {
	paths = members.keep_oks(|m| m.toml.map_ok(|t| t.path)).fold([], |found, path| if found.contains(path) found else found.append(path))
	found = paths.join_map(|path| wants_in(members, path))
	match found.find_first(|f| f.want.members.len() >= 2 and f.want.stale == Err(None)) {
		Ok({ want, dir }) => Err(Fail.new(Usage, "${want.from}: the key '${want.key}' is in no header, and ${want.members.len().to_str()} members are under ${dir}: ${Str.join_with(want.members, ", ")}. Run tln add --file <member file> ${want.name ?? want.key} for one of them."))
		Err(_) => Ok(found.map(|f| f.want))
	}
}

# The wants of one `talon.toml`: the keys of `[dependencies]`, then of `[overrides]`.
wants_in : List(Vars.Member), Str -> List({ want : Vars.Want, dir : Str })
wants_in = |members, path| {
	under = members.keep_if(|m| m.toml.map_ok(|t| t.path) == Ok(path))
	files = under.map(|m| m.file)
	rows = under.join_map(|m| m.locked.rows)
	intent = match under {
		[{ toml: Ok(t), .. }, ..] => Ok(t.intent)
		_ => Err(NoToml)
	}
	keys = match intent {
		Ok(i) => i.deps.map(|d| (Dependencies, d)).concat(i.overrides.map(|d| (Overrides, d)))
		Err(NoToml) => []
	}
	keys
		.keep_if(|(_, d)| !rows.any(|r| r.alias == d.key))
		.map(|(table, d)| { want: want_of(table, d, path, files, rows), dir: Text.dir_of(path) })
}

want_of : [Dependencies, Overrides], Intent.Dep, Str, List(Str), List(Locked.Row) -> Vars.Want
want_of = |table, d, path, files, rows| {
	name = match d.name {
		Ok(n) => if n.contains("/") Ok(n) else Err(Short(n))
		Err(None) => Err(Short(d.key))
	}
	stale = match name {
		Ok(full) => stale_alias(rows, full, d.range)
		Err(_) => Err(None)
	}
	{ key: d.key, table, name, range: d.range, from: "${path}:${d.line.to_str()}", members: files, stale }
}

# R-I8: a header entry with the same full name whose version the range admits.
stale_alias : List(Locked.Row), Str, Str -> Try(Str, [None])
stale_alias = |rows, full, range| match rows.find_first(
	|r| match r.what {
		Release(ident) => ident.name == Ok(full) and Ranges.admits({ ranges: [range], version: ident.version })
		_ => Bool.False
	},
) {
	Ok(r) => Ok(r.alias)
	Err(_) => Err(None)
}

# The indexes of the variables that the names (aliases) mean. A name that means none or 2 or more variables is a usage failure (R-WS8).
named_indexes : List(Vars.Var), List(Str) -> Try(List(U64), Fail)
named_indexes = |vars, names| names.fold_try(
	[],
	|found, name| {
		matches = vars.map_with_index(|v, i| (i, v)).keep_if(|(_, v)| v.uses.any(|u| u.alias == name))
		match matches {
			[] => Err(Fail.new(Usage, "'${name}' is not in the project"))
			[(i, _)] => Ok(found.append(i))
			_ => Err(Fail.new(Usage, "\"${name}\" matches ${matches.len().to_str()} packages. Use a name from the list."))
		}
	},
)

# R-SP1 to R-SP5, R-SP20, R-DI11: the state of one variable for the command.
scoped_one : [Install, Update], Bool, Bool, Try((List(U64), Str), [NotFound]), Vars.Var -> Vars.Scoped
scoped_one = |command, all, is_named, selector, variable| {
	indexed = variable.host == Indexed
	fixed_note = match variable.host {
		Fixed(host) => Ok(Index.fixed_line(host))
		Indexed => Err(None)
	}
	match command {
		Install => { variable, free: outside_range(variable), any_series: Bool.False, note: Err(None) }
		Update => {
			free = indexed and (all or is_named)
			note = if all or is_named fixed_note else Err(None)
			match selector {
				Ok((_, range)) if free => { variable: { ..variable, ranges: [{ range, from: "selector" }] }, free, any_series: Bool.True, note }
				_ => { variable, free, any_series: Bool.False, note }
			}
		}
	}
}

# R-SP20, R-WS3: a use that is outside the intersection of the ranges of its variable.
outside_range : Vars.Var -> Bool
outside_range = |variable| variable.uses.any(|u| !Ranges.admits({ ranges: variable.ranges.map(|r| r.range), version: u.version }))
