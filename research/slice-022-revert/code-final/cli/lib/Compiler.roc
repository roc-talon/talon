import Clock
import Fail
import JsonDoc
import Pin
import Text
import semver.Semver

## The compiler of P0 (Design 7, R-PH6 to R-PH8; Resolution 13, R-SO7, R-SO9 to R-SO11). The only installed compiler is the `roc` on `PATH`.
## `Resolve.Request.compiler` is its id. This module reads the id from `roc version` and decides when a compiler is not usable.
Compiler :: [].{

	## R-SO9: the id from the stdout of `roc version`. The text is `Roc compiler version <id>`, with a line end. A text of another form is
	## `Err(BadVersion)`. Command code runs `roc version` with `Fx.spawn_all!` (P0 keeps no `path-roc.json`: that file is for the launcher check of P1).
	version_id : Str -> Try(Str, [BadVersion])
	version_id = |text| {
		prefix = "Roc compiler version "
		id = text.trim().drop_prefix(prefix)
		if text.trim().starts_with(prefix) and !id.is_empty() and !id.contains(" ") Ok(id) else Err(BadVersion)
	}

	## R-SO10, R-SO11: `Nightly` for a nightly tag (`Pin.is_nightly`), `Release` for a release version (`X.Y.Z`, no pre-release part), else `Local`
	## (`debug-<sha>`: a local build, Talon never writes it as a `roc:` pin).
	kind : Str -> [Nightly, Release, Local]
	kind = |id| {
		if Pin.is_nightly(id) {
			Nightly
		} else {
			match Semver.parse(id) {
				Ok(v) if v.pre_release().is_empty() => Release
				_ => Local
			}
		}
	}

	## R-SO7, R-PH6: the compiler on `PATH`. `version_text` is the stdout of `roc version`, or `Err(NoRoc)` when no `roc` is on `PATH` (`Fx.programs!`).
	## A nightly or a release is `Ok(id)` (R-SO10). No `roc`, a text that is not a version, and a local build are `Err(NoCompiler)`: the same value as
	## `Resolve.Request.compiler` and `Pin.decide` take (R-SO11, slice 005).
	on_path : Try(Str, [NoRoc]) -> Try(Str, [NoCompiler])
	on_path = |version_text| match version_text {
		Err(NoRoc) => Err(NoCompiler)
		Ok(text) => match Compiler.version_id(text) {
			Ok(id) if Compiler.kind(id) != Local => Ok(id)
			_ => Err(NoCompiler)
		}
	}

	## R-SO2, R-EV5, R-SC12: `ROC_TOOLCHAIN` (rank 2) from the environment. An empty value is the same as no value. A text that is not a full compiler id
	## (`Compiler.kind` is `Local`: a prefix such as `nightly-2026-10`) is a failure of kind `Usage` (exit 2, as a bad `TALON_NOW`): `ROC_TOOLCHAIN is not a full compiler id: <text>`.
	toolchain_of : List((Str, Str)) -> Try(Try(Str, [Unset]), Fail)
	toolchain_of = |env| match env.find_first(|(name, _)| name == "ROC_TOOLCHAIN") {
		Ok((_, text)) if !text.is_empty() => if Compiler.kind(text) == Local {
			Err(Fail.new(Usage, "ROC_TOOLCHAIN is not a full compiler id: ${text}"))
		} else {
			Ok(Ok(text))
		}
		_ => Ok(Err(Unset))
	}

	## The rank that selected a compiler (Resolution 13). Rank 3 (the header pin) is a decision of `Pin.decide`, so it is not here.
	##
	## | Tag | Rank | Source | Rule |
	## | --- | --- | --- | --- |
	## | `Argument` | 1 | `roc +<id>` (the proxy, slice 023) | R-SO1 |
	## | `Env` | 2 | `ROC_TOOLCHAIN` | R-SO2 |
	## | `Range` | 4 | `[toolchain] roc` of `talon.toml`: the newest installed compiler in the range | R-SO4 |
	## | `VersionFile` | 5 | `.roc-version`, only for a project with no `talon.toml` | R-SO5 |
	## | `Default` | 6 | `default-roc` of `config.toml` | R-SO6 |
	## | `Path` | 7 | The `roc` on `PATH` | R-SO7 |
	Rank : [Argument, Env, Range, VersionFile, Default, Path]

	## The facts of `select`. A rank that has no value is `Err(Unset)`, `Err(None)` or `Err(NoCompiler)`.
	##
	## | Field | Holds |
	## | --- | --- |
	## | `argument` | Rank 1: the full id of `roc +<id>`. A `tln` command has none (R-SO19). |
	## | `env` | Rank 2: `ROC_TOOLCHAIN`, read by `toolchain_of` |
	## | `req` | Rank 4: `[toolchain] roc` of the project (`Err(Unset)` when the key is not set) |
	## | `nightly` | The `nightly` switch (R-NS8 to R-NS11). Off: rank 4 does not choose a nightly (R-NS3). |
	## | `has_toml` | The project has a `talon.toml` (`Project.toml` is `Ok`). Rank 5 is used only when it is false (R-SO5, R-PD6). |
	## | `version_file` | Rank 5: the id of the nearest `.roc-version` (`version_file`) |
	## | `default` | Rank 6: `default-roc` of `config.toml` |
	## | `path` | Rank 7: `on_path` |
	## | `installed` | The ids of `toolchains/` (`installed`). The id of `path` counts as installed too (R-SO10). |
	## | `times` | The `published_at` of the ids that are known (`times`), for the order of rank 4 (`Pin.order`) |
	Facts : {
		argument : Try(Str, [Unset]),
		env : Try(Str, [Unset]),
		req : Try(Pin.Req, [Unset]),
		nightly : Bool,
		has_toml : Bool,
		version_file : Try(Str, [None]),
		default : Try(Str, [Unset]),
		path : Try(Str, [NoCompiler]),
		installed : List(Str),
		times : List({ id : Str, published_at : U64 }),
	}

	## R-SO1 to R-SO7, R-SO10, R-SO12 to R-SO14, R-NS3, R-NS6 (slice 022): the compiler that the ranks select. The first rank that has a value wins, in the order 1, 2, 4, 5, 6, 7:
	##
	## | Rank | Rule | Result |
	## | --- | --- | --- |
	## | 1, 2 | The id as it is | `state` is `Installed` when the id is in `installed` (or is the id of `path`: R-SO10), else `Missing` (R-SO12: a required download, slice 025) |
	## | 4 | `req` is set. The candidates are the ids of `installed` and the id of `path` that are a nightly or a release (not `git-`, `link-`, `copy-`: R-NS6, they are chosen by name only), that `Pin.admits` with `times`, and, with `nightly` false, that are no nightly (R-NS3). The newest by `Pin.order` wins. | `state` is `Installed`. No candidate: `Err(NoneInRange)` (R-SO13: slice 025 downloads the newest in range). It does not go on to rank 5. |
	## | 5 | `has_toml` is false and `version_file` is set | The id, as ranks 1 and 2 |
	## | 6 | `default` is set | The id, as ranks 1 and 2. A `git-` id is allowed (the user named it). |
	## | 7 | `path` is `Ok(id)` | `state` is `Installed` |
	## | none | | `Err(NoCompiler)` (R-SO14) |
	select : Compiler.Facts -> Try({ id : Str, rank : Compiler.Rank, state : [Installed, Missing] }, [NoCompiler, NoneInRange])
	select = |facts| match (facts.argument, facts.env) {
		(Ok(id), _) => Ok(chosen(id, Argument, facts))
		(_, Ok(id)) => Ok(chosen(id, Env, facts))
		_ => match facts.req {
			Ok(req) => in_range(req, facts)
			Err(Unset) => match (facts.version_file, facts.default, facts.path) {
				(Ok(id), _, _) if !facts.has_toml => Ok(chosen(id, VersionFile, facts))
				(_, Ok(id), _) => Ok(chosen(id, Default, facts))
				(_, _, Ok(id)) => Ok({ id, rank: Path, state: Installed })
				_ => Err(NoCompiler)
			}
		}
	}

	## R-LY1, R-NS6 (slice 022): the compilers in the listing of `<cache>/toolchains` (`Fx.list_dirs!`). A compiler is a directory whose name is a nightly tag, a release version, or starts with `git-`, `link-` or `copy-`.
	## Not a file, not `<id>.lock`, not a temp dir `<id>.<hex>.tmp`, not `zig-<version>`. The ids are sorted (`Text.sorted`: the listing has no order, TW2).
	installed : List({ name : Str, is_dir : Bool, mtime : U64 }) -> List(Str)
	installed = |entries| Text.sorted(entries.keep_if(|e| e.is_dir and is_compiler_dir(e.name)).map(|e| e.name))

	## R-NS1, R-LY1 (slice 022, Q5 of the review): the `published_at` of the installed compilers. Each row is an id and the result of reading `toolchains/<id>/.talon.json`. The text is a JSON object with the string
	## `published_at` (a UTC time, `Clock.format_utc`: `2026-10-14T12:00:00Z`). A row with no file, with text that is not JSON, with no `published_at` (an install of slice 021 before it had the field) or with a bad
	## time has no result: the order then falls back to the tag text (`Pin.order`). The order of the result is the order of the rows.
	times : List({ id : Str, text : Try(Str, [NotFound, Denied, Other(Str)]) }) -> List({ id : Str, published_at : U64 })
	times = |rows| rows.keep_oks(|row| published_at_of(row.text).map_ok(|published_at| { id: row.id, published_at }))

	## R-SO5, R-SC12 (slice 022, Q6 of the review): the text of a `.roc-version` file. The trimmed text is the id:
	##
	## | Text | Result |
	## | --- | --- |
	## | A full id (`Pin.is_id`), with or without a line end | `Ok(Ok(id))` |
	## | Empty, or only white space | `Ok(Err(Empty))`: an empty file is no file |
	## | Any other text (a prefix, two words, two lines) | Failure, kind `Input` (exit 19): `<path>: .roc-version is not a full compiler id: <text>` (`<text>` is the trimmed text) |
	version_file : { path : Str, text : Str } -> Try(Try(Str, [Empty]), Fail)
	version_file = |facts| {
		id = facts.text.trim()
		if id.is_empty() {
			Ok(Err(Empty))
		} else if Pin.is_id(id) {
			Ok(Ok(id))
		} else {
			Err(Fail.new(Input, "${facts.path}: .roc-version is not a full compiler id: ${id}"))
		}
	}

	## R-SO18 (slice 022): the warning when the header pin and the `.roc-version` name 2 compilers. `pin` is the `roc:` entry of the header. The text has no `warning: ` and no line end (the command adds them):
	## `.roc-version names <version file id>, the header names <pin>`. `Pin.same_id` decides: the same nightly in the other tag form is no disagreement. No pin, or no `.roc-version`: `Err(None)`.
	roc_version_note : { pin : Try(Str, [NoPin]), version_file : Try(Str, [None]) } -> Try(Str, [None])
	roc_version_note = |facts| match (facts.pin, facts.version_file) {
		(Ok(pin), Ok(id)) if !Pin.same_id(pin, id) => Ok(".roc-version names ${id}, the header names ${pin}")
		_ => Err(None)
	}

	## R-SO14, R-SO13 (slice 022, G2 of the review): the failures of `select`.
	##
	## | Case | Kind | Text |
	## | --- | --- | --- |
	## | `NoCompiler` | `Environment` (exit 18) | `no compiler is selected. Run: tln roc install @latest, then tln roc default <id>` |
	## | `NoneInRange(<req text>)` | `Consent` (exit 13) | `no installed compiler is in [toolchain] roc (<req text>). This version of tln does not download a compiler for a run.` |
	failure : [NoCompiler, NoneInRange(Str)] -> Fail
	failure = |why| match why {
		NoCompiler => Fail.new(Environment, "no compiler is selected. Run: tln roc install @latest, then tln roc default <id>")
		NoneInRange(text) => Fail.new(Consent, "no installed compiler is in [toolchain] roc (${text}). This version of tln does not download a compiler for a run.")
	}

	## R-PH7, R-PH6, R-BL3: a probe needs the compiler `id` (the held `roc:` pin, or the selected compiler). The only installed compiler is the one on `PATH`
	## (`path_roc`). When `id` is that compiler: `Ok({})`. Else the compiler is a required download (R-DL2), and P0 refuses it as `TALON_AUTO_INSTALL=no` does
	## (R-DL5): a failure of kind `Consent` (exit 13, R-EC13). The message (a proposal, TW24) names the id and says that this version of `tln` runs only
	## the `roc` on `PATH`. It does not name `--allow-downloads` or `TALON_AUTO_INSTALL` (P0 does not read them).
	##
	## | `path_roc` | Message |
	## | --- | --- |
	## | `Ok(path id)` | `the compiler <id> is not installed. This version of tln runs only the roc on PATH (<path id>).` |
	## | `Err(NoCompiler)` | `the compiler <id> is not installed. This version of tln runs only the roc on PATH, and there is none.` |
	require : { id : Str, path_roc : Try(Str, [NoCompiler]) } -> Try({}, Fail)
	require = |facts| match facts.path_roc {
		Ok(found) if found == facts.id => Ok({})
		Ok(found) => Err(not_installed(facts.id, " (${found})"))
		Err(NoCompiler) => Err(not_installed(facts.id, ", and there is none"))
	}
}

not_installed : Str, Str -> Fail
not_installed = |id, found| Fail.new(Consent, "the compiler ${id} is not installed. This version of tln runs only the roc on PATH${found}.")

# R-SO10, R-SO12: an id named by rank 1, 2, 5 or 6 is installed when it is in the listing, or is the `roc` on `PATH`.
chosen : Str, Compiler.Rank, Compiler.Facts -> { id : Str, rank : Compiler.Rank, state : [Installed, Missing] }
chosen = |id, rank, facts| {
	known = facts.installed.contains(id) or facts.path == Ok(id)
	{ id, rank, state: if known Installed else Missing }
}

# R-SO4, R-SO13, R-NS3, R-NS6: the newest candidate in the range. No candidate is `NoneInRange`: the ranks below do not run.
in_range : Pin.Req, Compiler.Facts -> Try({ id : Str, rank : Compiler.Rank, state : [Installed, Missing] }, [NoCompiler, NoneInRange])
in_range = |req, facts| {
	on_path = match facts.path {
		Ok(id) if !facts.installed.contains(id) => [id]
		_ => []
	}
	fits = |id| Pin.is_id(id) and Pin.admits({ req, id, times: facts.times }) and (facts.nightly or !Pin.is_nightly(id))
	newest = |best, id| if Pin.order({ a: id, b: best, times: facts.times }) == After id else best
	match facts.installed.concat(on_path).keep_if(fits) {
		[first, .. as rest] => Ok({ id: rest.fold(first, newest), rank: Range, state: Installed })
		[] => Err(NoneInRange)
	}
}

# R-LY1, R-NS6: a nightly, a release, or a named local build. Not a lock, a temp dir or a Zig dir.
is_compiler_dir : Str -> Bool
is_compiler_dir = |name| {
	named = ["git-", "link-", "copy-"].any(|prefix| name.starts_with(prefix) and !name.drop_prefix(prefix).is_empty())
	!name.ends_with(".lock") and !name.ends_with(".tmp") and (Pin.is_id(name) or named)
}

# R-NS1: the `published_at` of a `.talon.json` text. A file that is missing or does not read, text that is not JSON, and a missing or bad time have none.
published_at_of : Try(Str, [NotFound, Denied, Other(Str)]) -> Try(U64, [NoTime])
published_at_of = |text| match text {
	Ok(body) => match JsonDoc.parse(body) {
		Ok(Obj(pairs)) => match pairs.find_first(|(key, _)| key == "published_at") {
			Ok((_, Text(when))) => Clock.parse_utc(when).map_err(|BadTime| NoTime)
			_ => Err(NoTime)
		}
		_ => Err(NoTime)
	}
	Err(_) => Err(NoTime)
}
