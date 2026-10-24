import Answer
import Args
import Fail
import Intent
import Locked
import Opts as FlagOpts
import Text
import toml.Toml

## The pure decisions of `tln remove` (CLI 1 R-CM3, CLI 2 "tln remove" R-RV1 to R-RV5, Design 4.4 R-WS12). Part A. `Remove.run!` is the command
## code (it gets the `Fx`), `Resolve.remove!` is its flow, `Scan` is the import scan.
Removal :: [].{

	## The flags of `tln remove` (also `rm`): `Args.parse` has checked that each flag is allowed (R-FL12). `names` are the operands.
	## `allow_downloads` is `--allow-downloads` (slice 025, R-NI5: `remove` runs the ladder, which can need a compiler download): `Ok(Yes)` when set. `--probe-downloads` is read and changes nothing (R-NI4 does not list `remove`).
	Opts : { names : List(Str), force : Bool, dry_run : Bool, no_check : Bool, allow_downloads : Try(Answer, [NoFlag]) }

	## Reads the options of a `remove` line. Each failure has the kind `Usage` (exit 2). The texts are a proposal (TW24). The checks, in this order:
	##
	## | # | Case | Message | Rule |
	## | --- | --- | --- | --- |
	## | 1 | `--registry` with a value other than `direct` | `--registry '<value>': no registry exists in this version of tln. Use --registry direct.` | R-FL5, R-RG2 |
	## | 2 | `--strategy` with a value other than `highest` or `lowest` | `--strategy must be highest or lowest, not '<value>'` | R-FL10 |
	## | 3 | `--frozen` (`remove` changes the header) | `flag '--frozen' works only for tln install with no names` | R-FL13, R-EC2 |
	## | 4 | No operand (question Q2) | `tln remove needs one name or more` | |
	##
	## `--no-probe`, `--slots`, `--snapshot`, `--probe-downloads` and `--allow-downloads` are resolve flags (R-FL7): they are read and change nothing
	## (`remove` resolves nothing, and P0 has no unit probe), except `--allow-downloads`, which is `Opts.allow_downloads` (slice 025). `--force`, `--dry-run`, `--no-check` are the fields of `Opts`.
	opts : Args -> Try(Opts, Fail)
	opts = |args| {
		read = FlagOpts.read(args)?
		if read.frozen {
			return Err(Fail.new(Usage, "flag '--frozen' works only for tln install with no names"))
		}
		if read.names.is_empty() {
			return Err(Fail.new(Usage, "tln remove needs one name or more"))
		}
		Ok({ names: read.names, force: has_flag(args, "--force"), dry_run: read.dry_run, no_check: read.no_check, allow_downloads: if has_flag(args, "--allow-downloads") Ok(Yes) else Err(NoFlag) })
	}

	## The kind of the table in `talon.toml` that holds a key of the entry: `[dependencies]`, `[overrides]` (R-OV1), `[patch]` (R-PA12).
	Table : Intent.Table

	## What the entry was, for the output: a release (`name` and `version` of its URL), a path entry (its path), a foreign URL (its URL).
	What : [Release({ name : Str, version : Str }), Path(Str), Foreign(Str)]

	## The decision for one entry. `alias` is the entry that `Lookup.find` gave. `rows` are the entries of the header of the current member. `toml` is the
	## nearest `talon.toml` of that member (R-WS14: path and text), or `Err(NoToml)`. `shared` is true when another member that is under the dir of that
	## `talon.toml` has an entry with the same alias (question Q3).
	##
	## | Case | Result | Rule |
	## | --- | --- | --- |
	## | The entry is the platform (`is_platform`) | Failure, kind `Usage` (exit 2): `<alias> is the platform of the app. An app needs a platform. Use tln add --platform <name> to change it.` | R-RV3, R-EC2 |
	## | `alias` is not in `rows` | Failure, kind `Internal`: `<alias> is not in the header` (the lookup must not ask for it) | |
	## | A release row | `what` is `Release({ name, version })` (`Ident.of_url`: `name` is the full name, or the URL when it has none) | R-CM3 |
	## | A path row or a foreign row | `what` is `Path(<value>)` or `Foreign(<value>)`. It is removed like a release: the user names the alias, and an unmanaged entry changes only as a whole (R-H4, R-H9). Its keys in `talon.toml` go too (the next row). The file that a path entry names is never edited. | R-RV5, R-H4, R-H9 |
	## | `toml` has the key `alias` in `[dependencies]`, `[overrides]` or `[patch]`, and `shared` is false | `keys` has one `{ table, key }` for each table that has it, in the order `Dependencies`, `Overrides`, `Patch` | R-CM3, R-RV1, R-RV4 |
	## | `shared` is true, or `toml` is `Err(NoToml)` | `keys` is `[]` | question Q3 |
	## | `keys` has a `Patch` row | `patch_dir` is `Ok("<dir of the talon.toml>/.talon/patches/<alias>/")`, with the `/` at the end (the files stay) | R-RV4, R-PA11 |
	## | Else | `patch_dir` is `Err(None)` | |
	##
	## The text of `toml` that is not TOML gives the failure of `Intent.read` (kind `Input`).
	Plan : { what : What, keys : List({ table : Table, key : Str }), patch_dir : Try(Str, [None]) }

	plan : { alias : Str, rows : List(Locked.Row), toml : Try({ path : Str, text : Str }, [NoToml]), shared : Bool } -> Try(Plan, Fail)
	plan = |facts| {
		row = match facts.rows.find_first(|r| r.alias == facts.alias) {
			Ok(found) => found
			Err(_) => return Err(Fail.new(Internal, "${facts.alias} is not in the header"))
		}
		if row.is_platform {
			return Err(Fail.new(Usage, "${facts.alias} is the platform of the app. An app needs a platform. Use tln add --platform <name> to change it."))
		}
		what = match row.what {
			Release(ident) => Release({ name: ident.name ?? row.value, version: ident.version })
			Path => Path(row.value)
			Foreign => Foreign(row.value)
		}
		keys = match facts.toml {
			Ok(file) if !facts.shared => keys_of(file, facts.alias)?
			_ => []
		}
		patch_dir = match (keys.any(|k| k.table == Patch), facts.toml) {
			(Bool.True, Ok(file)) => Ok(Text.join(Text.dir_of(file.path), ".talon/patches/${facts.alias}/"))
			_ => Err(None)
		}
		Ok({ what, keys, patch_dir })
	}
}

has_flag : Args, Str -> Bool
has_flag = |args, flag| args.options.any(|(name, _)| name == flag)

# The keys of the alias in the 3 tables, in the order `[dependencies]`, `[overrides]`, `[patch]`.
keys_of : { path : Str, text : Str }, Str -> Try(List({ table : Intent.Table, key : Str }), Fail)
keys_of = |file, alias| match Toml.parse(file.text) {
	Err(TomlErr(e)) => Err(Fail.new(Input, "${file.path}:${e.line.to_str()}: not valid TOML"))
	Ok(doc) => {
		tables = [(Dependencies, "dependencies"), (Overrides, "overrides"), (Patch, "patch")]
		Ok(tables.keep_oks(|(table, name)| Toml.get(doc, [name, alias]).map_ok(|_| { table, key: alias })))
	}
}
