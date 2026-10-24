import Args
import Clock
import Common
import Fail
import JsonDoc
import TalonFile

## The pure decisions of `tln roc link <name> <path>` and `tln roc link --copy <name> <path>` (slice 024b, CLI 6.6: R-R12, R-R13, R-LK1 to R-LK4). The command code is `RocLink`.
## The contract is in the doc comments (tables). Texts and `data` fields are a proposal (R-OUT2, TW24).
##
## What the two commands make (R-LK4, R-LK2, R-CC4 step 6). `<item>` is `<cache>/toolchains/<id>`, `<hex>` is 16 hex digits (`Temp.hex(Fx.random!())`):
##
## | Command | Id | Files of the item |
## | --- | --- | --- |
## | `roc link dev <path>` | `link-dev` | Only `.talon.json`: `format`, `id`, `path` (the absolute path of the target), `installed_at`. No copy and no link of the file system (R-R12, R-LK4). Talon runs the path. |
## | `roc link --copy fix-1 <path>` | `copy-fix-1` | `roc` (a copy of the binary, `Fx.copy_file!`) and `.talon.json`: `format`, `id`, `source` (the absolute path that it was copied from), `installed_at` (R-R13, R-LK2) |
##
## Both are made in `<item>.<hex>.tmp/` and the dir is renamed to `<item>` (R-CC1), with `.talon.json` written last (R-CC4 step 6).
Link :: [].{

	## The operands and flags of one `roc link` line. `id` is `link-<name>` or `copy-<name>`. `path` is the text as typed (relative to the current directory).
	Plan : { copy : Bool, force : Bool, name : Str, id : Str, path : Str }

	## R-CM15, R-R12, R-R13, R-LK2, R-FL12: the operands and flags of `roc link`. Each failure has the kind `Usage` (exit 2). The checks, in this order (the texts are a proposal, TW24):
	##
	## | # | Case | Message |
	## | --- | --- | --- |
	## | 1 | No operand, or one | `tln roc link needs a name and a path: tln roc link <name> <path>` |
	## | 2 | 3 operands or more | `tln roc link takes a name and a path, got <n> operands` |
	## | 3 | `--force` with no `--copy` (R-FL12 names `--force` only for `roc link --copy`: question Q1) | `flag '--force' is not for 'roc link' without --copy` |
	## | 4 | The name is empty, has a `/`, a `\`, a white space character, or ends in `.lock` or `.tmp` (it must be one path part that `Compiler.installed` lists: R-LY1) | `<name> is not a valid compiler name: use one word with no space, no / and no \` |
	##
	## `--copy` makes `copy-<name>` (R-R13), else `link-<name>` (R-R12). The name is used as typed (no case change).
	read : Args -> Try(Link.Plan, Fail)
	read = |args| {
		copy = has_flag(args, "--copy")
		force = has_flag(args, "--force")
		match args.operands {
			[name, path] => {
				if force and !copy return Err(Fail.new(Usage, "flag '--force' is not for 'roc link' without --copy"))
				if !valid_name(name) return Err(Fail.new(Usage, "${name} is not a valid compiler name: use one word with no space, no / and no \\"))
				Ok({ copy, force, name, id: if copy "copy-${name}" else "link-${name}", path })
			}
			[] | [_] => Err(Fail.new(Usage, "tln roc link needs a name and a path: tln roc link <name> <path>"))
			many => Err(Fail.new(Usage, "tln roc link takes a name and a path, got ${many.len().to_str()} operands"))
		}
	}

	## R-R12, R-R13, R-LK4 (the path of the operand): `full` is the typed path made absolute from the current directory, with the `.` and `..` parts removed by `Text.resolve` (no symbolic link is resolved). It is the path
	## that the command uses: the target of a link and the source of a copy. `result` is what `canonical!` gave for `full`. Talon uses it only to check that the file exists. `Ok(_)` gives `Ok(full)`, even when the canonical path is
	## another one (`full` is a symbolic link that a rebuild replaces: the link must follow it).
	##
	## | Result of `canonical!` | Result |
	## | --- | --- |
	## | `Ok(_)` | `Ok(full)` |
	## | --- | --- |
	## | `Err(NotFound)` | Kind `Usage` (exit 2): `no such file: <typed>` |
	## | `Err(Denied)` | Kind `Environment` (exit 18): `cannot read <typed>: permission denied` |
	## | `Err(Other(text))` | Kind `Environment`: `cannot read <typed>: <text>` |
	source : { typed : Str, full : Str, result : Try(Str, [NotFound, Denied, Other(Str)]) } -> Try(Str, Fail)
	source = |facts| match facts.result {
		Ok(_) => Ok(facts.full)
		Err(NotFound) => Err(Fail.new(Usage, "no such file: ${facts.typed}"))
		Err(Denied) => Err(Fail.new(Environment, "cannot read ${facts.typed}: permission denied"))
		Err(Other(text)) => Err(Fail.new(Environment, "cannot read ${facts.typed}: ${text}"))
	}

	## R-LK2: what to do with the id. `installed` is `Launch.toolchains!` (read under the lock of the item). The name is compared as it is (not `Pin.same_id`).
	##
	## | Case | Result |
	## | --- | --- |
	## | `id` is not in `installed` | `Ok(Create)` |
	## | `id` is in `installed`, `copy` and `force` | `Ok(Replace)`: the old dir goes to the trash name (`Manage.trash_name`) and is deleted after the new dir is in place |
	## | `id` is in `installed`, `copy` and not `force` | Kind `Usage` (exit 2, question Q2): `copy-<name> exists. Use --force to replace it.` |
	## | `id` is in `installed`, not `copy` | Kind `Usage` (exit 2, question Q2): `link-<name> exists. Run: tln roc remove link-<name>` |
	decide : { id : Str, copy : Bool, force : Bool, installed : List(Str) } -> Try([Create, Replace], Fail)
	decide = |facts| if !facts.installed.contains(facts.id) {
		Ok(Create)
	} else if !facts.copy {
		Err(Fail.new(Usage, "${facts.id} exists. Run: tln roc remove ${facts.id}"))
	} else if facts.force {
		Ok(Replace)
	} else {
		Err(Fail.new(Usage, "${facts.id} exists. Use --force to replace it."))
	}

	## R-LK4, R-LK2, R-CV5 (the form of R-TF1), R-TF1: the text of `.talon.json`: `TalonFile.render` with `format` 1 and these fields, in this order (a proposal):
	##
	## | `kind` | Fields |
	## | --- | --- |
	## | `Link` | `id`, `path` (the absolute path of the target, no symbolic link resolved), `installed_at` (`Clock.format_utc(now)`) |
	## | `Copy` | `id`, `source` (the absolute path that was copied), `installed_at` |
	##
	## `path` of the argument is the absolute path of `source` in both rows. `Manage.rows` reads `installed_at` of this file (slice 024).
	meta : { id : Str, kind : [Link, Copy], path : Str, now : U64 } -> Str
	meta = |facts| {
		key = match facts.kind {
			Link => "path"
			Copy => "source"
		}
		TalonFile.render({
			format: 1,
			fields: [("id", JsonDoc.Text(facts.id)), (key, JsonDoc.Text(facts.path)), ("installed_at", JsonDoc.Text(Clock.format_utc(facts.now)))],
		})
	}

	## R-LK4, R-R5 (the proxy and the probes): the program that runs for a `link-*` id. `text` is the result of reading `.talon.json` of the item (`path` is its path, for the messages). The text is read with `TalonFile.open`
	## (`format` 1, `can_recreate` false: R-TF1, R-TF3). The field `path` must be a text that starts with `/` (an absolute path). The result is that path, as it is (no check of the file: a target that was deleted is a failure of the start, R-E1).
	##
	## | Case | Failure |
	## | --- | --- |
	## | `Err(NotFound)` | Kind `Environment` (exit 18): `<path>: the link <id> has no .talon.json. Run: tln roc remove <id>, then tln roc link <name> <path>.` `<name>` is the id without `link-`. |
	## | `Err(Denied)`, `Err(Other(text))` | Kind `Environment`: `cannot read <path>: permission denied` or `cannot read <path>: <text>` |
	## | Text that does not parse, a `format` that is too new | The failure of `TalonFile.open` (kind `Input`, exit 19: R-TF3, R-TF6, R-EC19) |
	## | A `path` that is missing, is not a text, or is not absolute | Kind `Input` (exit 19): `<path>: the link <id> has no absolute target path` |
	target : { id : Str, path : Str, text : Try(Str, [NotFound, Denied, Other(Str)]) } -> Try(Str, Fail)
	target = |facts| match facts.text {
		Err(NotFound) => Err(Fail.new(Environment, "${facts.path}: the link ${facts.id} has no .talon.json. Run: tln roc remove ${facts.id}, then tln roc link ${facts.id.drop_prefix("link-")} <path>."))
		Err(Denied) => Err(Fail.new(Environment, "cannot read ${facts.path}: permission denied"))
		Err(Other(text)) => Err(Fail.new(Environment, "cannot read ${facts.path}: ${text}"))
		Ok(text) => {
			no_path = Fail.new(Input, "${facts.path}: the link ${facts.id} has no absolute target path")
			match TalonFile.open({ path: facts.path, text, newest: 1, can_recreate: Bool.False })? {
				Use(file) => match file.fields.find_first(|(key, _)| key == "path") {
					Ok((_, JsonDoc.Text(target))) if target.starts_with("/") => Ok(target)
					_ => Err(no_path)
				}
				_ => Err(no_path)
			}
		}
	}

	## R-OUT2 (a proposal): the line on stdout, with a line end. `Link`: `linked <id> -> <path>`. `Copy`: `copied <path> to <id>`. With `--json` the line goes to stderr (`Common.shown_fx`) and stdout is the envelope.
	report : { id : Str, kind : [Link, Copy], path : Str } -> List(Str)
	report = |facts| match facts.kind {
		Link => ["linked ${facts.id} -> ${facts.path}\n"]
		Copy => ["copied ${facts.path} to ${facts.id}\n"]
	}

	## R-J3, R-J4, R-OUT4 (a proposal): the `data` of `--json`, the keys in this order: `id`, `kind` (`link` or `copy`), `source` (the absolute path: the target of a link, the file that was copied), `replaced` (true when `--force` replaced a copy).
	data : { id : Str, kind : [Link, Copy], path : Str, replaced : Bool } -> JsonDoc
	data = |facts| {
		kind = match facts.kind {
			Link => "link"
			Copy => "copy"
		}
		JsonDoc.Obj([("id", JsonDoc.Text(facts.id)), ("kind", JsonDoc.Text(kind)), ("source", JsonDoc.Text(facts.path)), ("replaced", JsonDoc.Flag(facts.replaced))])
	}
}

has_flag : Args, Str -> Bool
has_flag = |args, flag| args.options.any(|(name, _)| name == flag)

# R-LY1: one path part that `Compiler.installed` lists.
valid_name : Str -> Bool
valid_name = |name| !name.is_empty()
	and !name.ends_with(".lock")
		and !name.ends_with(".tmp")
			and name.to_utf8().all(|b| b != 47 and b != 92 and b != 32 and !(b >= 9 and b <= 13))
