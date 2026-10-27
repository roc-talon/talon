import Args
import Fail
import JsonDoc
import Locked
import Item
import Roots
import Text

## `tln path <alias>` (slice 055, R-CM25, R-PTH1 to R-PTH5, CLI 1): the pure decisions. `PathFlow` is the command code.
## The texts of the failures and the `--json` `data` fields are a proposal (TW24, R-OUT2).
PathCmd :: [].{

	## The directory of one header entry. `source` is `Release(url)` for a release URL (the directory is `<pkgs>/<hash>`, and the command fetches it when it is missing) or `Dir` for a path entry.
	Entry : { alias : Str, source : [Release(Str), Dir], dir : Str }

	## R-PTH1: the operands of the command. One alias. No alias, or 2 or more, is a failure of kind `Usage` (exit 2, R-EC2):
	##
	## | Operands | Message |
	## | --- | --- |
	## | none | `tln path needs an alias: a name in the header of the project file` |
	## | 2 or more | `tln path takes one alias, got <n> names` |
	read : Args -> Try({ alias : Str }, Fail)
	read = |args| match args.operands {
		[alias] => Ok({ alias: alias })
		[] => Err(Fail.new(Usage, "tln path needs an alias: a name in the header of the project file"))
		names => Err(Fail.new(Usage, "tln path takes one alias, got ${names.len().to_str()} names"))
	}

	## R-PTH1, R-PTH3: the entry `alias` of the header rows of the project file `file` (`Locked.read`). The `roc:` pin is not a row (question Q2).
	##
	## | Row | Result |
	## | --- | --- |
	## | A release URL | `Release(url)`, `dir` is `<pkgs>/<hash>` (`Roots.item`, R-CR1) |
	## | A path entry | `Dir`, `dir` is the directory of the file that the value names, from the directory of `file` (no `.`, no `..`) |
	## | A foreign URL (R-H4) | exit 2: `'<alias>' is a foreign URL (<url>): roc keeps it under another cache rule, so it has no directory in packages/ (R-PTH3)` |
	## | No such alias | exit 2: `no entry '<alias>' in the header of <file>. Entries: <alias>, <alias>.` (`none` for no entry) |
	pick : { alias : Str, rows : List(Locked.Row), file : Str, roots : Roots } -> Try(PathCmd.Entry, Fail)
	pick = |x| match x.rows.find_first(|row| row.alias == x.alias) {
		Err(_) => {
			names = if x.rows.is_empty() "none" else Str.join_with(x.rows.map(|row| row.alias), ", ")
			Err(Fail.new(Usage, "no entry '${x.alias}' in the header of ${x.file}. Entries: ${names}."))
		}
		Ok(row) => match row.what {
			Release(ident) => Ok({ alias: x.alias, source: Release(row.value), dir: Roots.item(x.roots, Item.Package(ident.hash)) })
			Path => Ok({ alias: x.alias, source: Dir, dir: Text.dir_of(Text.resolve(Text.dir_of(x.file), row.value)) })
			Foreign => Err(Fail.new(Usage, "'${x.alias}' is a foreign URL (${row.value}): roc keeps it under another cache rule, so it has no directory in packages/ (R-PTH3)"))
		}
	}

	## R-PTH1: stdout, one line: the directory.
	text : PathCmd.Entry -> Str
	text = |entry| "${entry.dir}\n"

	## R-PTH1: `data` of `--json`: `{ alias, kind, dir }`, `kind` is `url` or `path`.
	data : PathCmd.Entry -> JsonDoc
	data = |entry| {
		kind = match entry.source {
			Release(_) => "url"
			Dir => "path"
		}
		JsonDoc.Obj([("alias", JsonDoc.Text(entry.alias)), ("kind", JsonDoc.Text(kind)), ("dir", JsonDoc.Text(entry.dir))])
	}
}
