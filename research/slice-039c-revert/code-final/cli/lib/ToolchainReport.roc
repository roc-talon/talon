import JsonDoc

## The texts and the `--json` data of the end of `tln roc install` (slice 039s: split from `Toolchain`, R-OUT2, R-J3, R-J4, R-OUT4, TW24). `Toolchain` keeps the names that the unit tests call. Pure.
ToolchainReport :: [].{

	## R-DA6, R-NR2, R-GC2: a size for a person: below 1000 `<n> B`, below 1000000 `<x.y> KB`, below 1000000000 `<x.y> MB`, else `<x.y> GB` (decimal, one digit after the point, rounded to the nearest tenth).
	## Each step starts where the rounding of the step before gives 1000.0 (999_950, 999_950_000).
	## 999 is `999 B`, 1000 is `1.0 KB`, 1500000 is `1.5 MB`, 73861067 is `73.9 MB`, 3100000000 is `3.1 GB`.
	size_text : U64 -> Str
	size_text = |bytes| if bytes < 1000 {
		"${bytes.to_str()} B"
	} else if bytes < 999_950 {
		"${tenths_text((bytes + 50) // 100)} KB"
	} else if bytes < 999_950_000 {
		"${tenths_text((bytes + 50_000) // 100_000)} MB"
	} else {
		"${tenths_text((bytes + 50_000_000) // 100_000_000)} GB"
	}

	## The text of a finished run (R-OUT2, a proposal). `how` is `Installed` (this run put the compiler there) or `Present` (it was there, step 1 or step 4 of R-CC4). `default` is `Set` when this run
	## wrote `default-roc` (R-SO15), else `Kept`. `compat` is the answer of `learn_compat` for an install, and `Err(Unknown)` for `Present`, which has no warning.
	##
	## | Line | Stream | When |
	## | --- | --- | --- |
	## | `installed <id>` | stdout | `Installed` |
	## | `<id> is already installed` | stdout | `Present` |
	## | `<id> is now the default compiler` | stdout | `Set` |
	## | `warning: the compat id of <id> is not known: roc check touched no compat dir` | stderr | `Installed` and `Unknown` |
	## | `warning: the compat id of <id> is not known: roc check touched <n> compat dirs (<a>, <b>)` | stderr | `Installed` and `Several` |
	##
	## Each line ends with `\n`. The stdout lines are `Info` for `--quiet` (R-FL4), the warning is not.
	report : { id : Str, how : [Installed, Present], default : [Set, Kept], compat : Try(Str, [Unknown, Several(List(Str))]) } -> { stdout : List(Str), stderr : List(Str) }
	report = |facts| {
		first = match facts.how {
			Installed => "installed ${facts.id}\n"
			Present => "${facts.id} is already installed\n"
		}
		now_default = match facts.default {
			Set => ["${facts.id} is now the default compiler\n"]
			Kept => []
		}
		warning = |why| "warning: the compat id of ${facts.id} is not known: ${why}\n"
		warnings = match (facts.how, facts.compat) {
			(Installed, Err(Unknown)) => [warning("roc check touched no compat dir")]
			(Installed, Err(Several(names))) => [warning("roc check touched ${names.len().to_str()} compat dirs (${Str.join_with(names, ", ")})")]
			_ => []
		}
		{ stdout: [first].concat(now_default), stderr: warnings }
	}

	## R-J3, R-J4, R-OUT4: the `data` of `--json`, the keys in this order: `id` (text), `path` (the install dir `item`), `installed` (true when this run installed it), `default` (true when this run set the default).
	data : { id : Str, item : Str, how : [Installed, Present], default : [Set, Kept] } -> JsonDoc
	data = |facts| JsonDoc.Obj([
		("id", JsonDoc.Text(facts.id)),
		("path", JsonDoc.Text(facts.item)),
		("installed", JsonDoc.Flag(facts.how == Installed)),
		("default", JsonDoc.Flag(facts.default == Set)),
	])
}

# `<x>.<y>` for a number of tenths.
tenths_text : U64 -> Str
tenths_text = |tenths| "${(tenths // 10).to_str()}.${(tenths % 10).to_str()}"
