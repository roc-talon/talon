import Args
import Diff
import Fail
import JsonDoc
import Locked
import Lookup
import Opts
import Ref
import Scope
import Text

## The pure decisions of `tln patch <alias> [--diff]` (R-CM10, R-PA1 to R-PA3, R-PA8, R-PA9, R-PA11, R-PA12, R-PA14; slice 042). Part A (TESTING.md 2.2). `PatchFlow.run!` is the command code.
## The texts and the `data` fields are a proposal (R-OUT2, TW24): the human accepts or changes them at the review.
##
## `tln patch json` copies the cached package of the header entry `json` to `<dir of talon.toml>/.talon/patches/json/` and writes `json = { path = "./.talon/patches/json/main.roc", base = "<hash>" }` in the table `[patch]` of `talon.toml`.
## `tln patch json --diff` prints the diff of that copy against `packages/<base>/` and writes nothing.
PatchCmd :: [].{

	## The entry that a name selects, with its release: `alias`, the full name `owner/repo` (the URL form for another host), the `version`, the `url` as the header has it and the `hash` of that URL.
	Target : { alias : Str, name : Str, version : Str, url : Str, hash : Str }

	## The operands and flags of `tln patch`. `Opts.read` of the line is checked first (its failures are the failures of `tln why`: R-FL5). Each failure has the kind `Usage` (exit 2, R-EC2).
	## `Args.parse` has rejected the flags that `patch` does not take (R-FL7, R-FL12), among them `--commit` (R-PA2: `tln patch` has no `--commit`) and every flag of a resolve.
	##
	## | Case | Result |
	## | --- | --- |
	## | One name | `{ name, diff }`. `diff` is true when `--diff` is given. |
	## | No name, or 2 names or more | Failure: `tln patch takes one name` |
	read : Args -> Try({ name : Str, diff : Bool }, Fail)
	read = |args| {
		_ = Opts.read(args)?
		match args.operands {
			[name] => Ok({ name, diff: args.options.any(|(flag, _)| flag == "--diff") })
			_ => Err(Fail.new(Usage, "tln patch takes one name"))
		}
	}

	## R-SC1, R-SC6 to R-SC8, R-SC16, R-SC14, R-PA8, R-PA14: the header entry that a name selects. `rows` are the entries of the header of the current member. A row that another row repeats counts once. The name is read as `Ref.parse` with the
	## scope `Project` reads it, and found as `Lookup.find` finds it (the alias, then the full name, then the short name, with the filter `@sel`). Only header entries are names here. The failures have the kind `Usage` (exit 2). The texts are the ones
	## of `Lookup.find` for the first 2 rows, and a proposal for the others:
	##
	## | Case | Failure | Block |
	## | --- | --- | --- |
	## | No entry has the name (also a name with a selector that no entry satisfies) | `'<x>' is not in the project` | `""` |
	## | A tie (R-SC14) | `"<name>" matches <n> packages. Use a name from the list.` | The list of `Lookup.find` |
	## | The entry is the platform (R-PA8) | `<alias> is the platform of the app. tln patch does not copy a platform: its archive holds host binaries. Use a fork and its release, or a path entry.` | `""` |
	## | The entry is a path entry (R-PA14) | `<alias> is a path entry. It is local code: edit its file.` | `""` |
	## | The entry is a foreign URL (R-PA14) | `<alias> is a foreign URL. It has no release, so tln patch cannot copy it.` | `""` |
	##
	## A release entry gives the `Target`.
	entry : { text : Str, rows : List(Locked.Row) } -> Try(PatchCmd.Target, { fail : Fail, block : Str })
	entry = |x| {
		ref = Ref.parse(x.text, Scope.Project, Bool.False).map_err(|fail| { fail, block: "" })?
		alias = match Lookup.find(Scope.Project, ref, Lookup.build(x.rows.map(fact_of)))? {
			Lookup.Existing({ alias: found, .. }) => found
			Lookup.New(name) => return Err(refused("'${name}' is not in the project"))
		}
		row = match x.rows.find_first(|r| r.alias == alias) {
			Ok(found) => found
			Err(_) => return Err(refused("'${x.text}' is not in the project"))
		}
		if row.is_platform {
			return Err(refused("${alias} is the platform of the app. tln patch does not copy a platform: its archive holds host binaries. Use a fork and its release, or a path entry."))
		}
		match row.what {
			Release(ident) => Ok({ alias, name: ident.name ?? ident.group.form, version: ident.version, url: row.value, hash: ident.hash })
			Path => Err(refused("${alias} is a path entry. It is local code: edit its file."))
			Foreign => Err(refused("${alias} is a foreign URL. It has no release, so tln patch cannot copy it."))
		}
	}

	## R-PA1, R-PA9, R-PA11: where the copy goes. `toml` is the absolute path of the `talon.toml` (the one that exists, or the one that the command makes). `dir` is `<dir of toml>/.talon/patches/<alias>/`, with a `/` at the end.
	## `entry_path` is the value of `path` in the `[patch]` entry: `./.talon/patches/<alias>/main.roc` (the form of R-PA9, relative to the `talon.toml`).
	place : { toml : Str, alias : Str } -> { dir : Str, entry_path : Str }
	place = |x| {
		dir = Text.join(Text.dir_of(x.toml), ".talon/patches/${x.alias}/")
		{ dir, entry_path: "./.talon/patches/${x.alias}/main.roc" }
	}

	## R-PA3, R-PA12: the dir of the copy that a `[patch]` entry names. `toml` is the absolute path of the `talon.toml`, `path` is the `path` value of the entry (relative to the dir of the `talon.toml`, or absolute). The result is the absolute dir of
	## that file, with a `/` at the end, with no `.` and no `..` part (`Text.resolve`).
	copy_dir : { toml : Str, path : Str } -> Str
	copy_dir = |x| "${Text.dir_of(Text.resolve(Text.dir_of(x.toml), x.path))}/"

	## R-PA1: the failure of a copy dir that exists. Kind `Usage` (exit 2). `dir` is the dir with the `/` at the end. The text names the dir: `<dir> exists already. Edit the copy, or remove it to start again.`
	exists : Str -> Fail
	exists = |dir| Fail.new(Usage, "${dir} exists already. Edit the copy, or remove it to start again.")

	## The output of `tln patch <alias>` (R-PA1, R-PA2, a proposal). `toml_created` is true when the command made the `talon.toml`.
	##
	## | Output | Text |
	## | --- | --- |
	## | The lines | `copied: <dir> (<name> <version>)`, then `<toml>: + [patch] <alias>` (` (new file)` is added to this line when `toml_created`), then `edit the copy, then commit it and talon.toml. Review it with: tln patch <alias> --diff` |
	## | `data` (R-OUT4, keys in this order) | `alias`, `name`, `version`, `base` (the hash), `dir`, `toml`, `toml_created` (true or false) |
	##
	## Each line of `text` ends with a line end.
	created : { target : PatchCmd.Target, dir : Str, toml : Str, toml_created : Bool } -> { text : Str, data : JsonDoc }
	created = |x| {
		new_file = if x.toml_created " (new file)" else ""
		text = "copied: ${x.dir} (${x.target.name} ${x.target.version})\n${x.toml}: + [patch] ${x.target.alias}${new_file}\nedit the copy, then commit it and talon.toml. Review it with: tln patch ${x.target.alias} --diff\n"
		data = JsonDoc.Obj([
			("alias", Text(x.target.alias)),
			("name", Text(x.target.name)),
			("version", Text(x.target.version)),
			("base", Text(x.target.hash)),
			("dir", Text(x.dir)),
			("toml", Text(x.toml)),
			("toml_created", Flag(x.toml_created)),
		])
		{ text, data }
	}

	## The output of `tln patch <alias> --diff` (R-PA3, a proposal). `base` is the hash of the `[patch]` entry, `dir` the dir of the copy (with the `/` at the end).
	##
	## | Output | Text |
	## | --- | --- |
	## | `text` (stdout) | `Diff.render(changes)`: nothing else, so a pipe into `patch -p1` works |
	## | `note` (stderr) | `<alias>: no changes against <base>` and a line end when `changes` is empty, else the empty text |
	## | `data` (R-OUT4, keys in this order) | `alias`, `base`, `dir`, `changes` (a list of `{ "path", "change" }` in the order of `changes`: `change` is `modified` for an `Edit`, `added`, `deleted`, `replaced`), `diff` (the text) |
	shown : { alias : Str, base : Str, dir : Str, changes : List(Diff.Change) } -> { text : Str, note : Str, data : JsonDoc }
	shown = |x| {
		text = Diff.render(x.changes)
		note = if x.changes.is_empty() "${x.alias}: no changes against ${x.base}\n" else ""
		data = JsonDoc.Obj([
			("alias", Text(x.alias)),
			("base", Text(x.base)),
			("dir", Text(x.dir)),
			("changes", Arr(x.changes.map(change_doc))),
			("diff", Text(text)),
		])
		{ text, note, data }
	}
}

# A refusal of kind `Usage` with no block.
refused : Str -> { fail : Fail, block : Str }
refused = |message| { fail: Fail.new(Usage, message), block: "" }

# The fact of a header entry for `Lookup.build`: a release, or an unmanaged entry (a path entry or a foreign URL).
fact_of : Locked.Row -> Lookup.Fact
fact_of = |r| {
	what = match r.what {
		Release(ident) => Release({ name: ident.name ?? ident.group.form, series: ident.series, version: ident.version })
		_ => Unmanaged
	}
	{ alias: r.alias, what, role: if r.is_platform Platform else Direct }
}

# One entry of `data.changes`: the path and the kind of the change.
change_doc : Diff.Change -> JsonDoc
change_doc = |change| {
	(path, kind) = match change {
		Edit({ path: p, .. }) => (p, "modified")
		Add(file) => (file.path, "added")
		Delete(file) => (file.path, "deleted")
		Replace({ path: p, .. }) => (p, "replaced")
	}
	JsonDoc.Obj([("path", Text(path)), ("change", Text(kind))])
}
