import Item
import Roots
import Setup
import TalonUpdate

## The pure decisions of the `.del` files of Windows (slice 050c, CLI 6.7: R-ST10). Part A (TESTING.md 2.2). The command code is `DelFlow`. `TalonUpdate.is_del`, `TalonUpdate.stale` and `TalonUpdate.del_moves` (slice 050) are the shared parts: this module does not copy them. The bodies are the code agent's job (stubs).
##
## | Rule | Text |
## | --- | --- |
## | R-ST10 | On Windows, Talon renames a `.exe` before it replaces or deletes it: to `<name>.<16hex>.del` in the same dir. Each start of `tln` tries to delete the `*.del` files in the bin dir and the data bin dir. A delete fails while the file runs, and the next start tries again. |
Del :: [].{

	## One entry of a directory list (`Fx.list_dirs!`), and the list of one dir.
	Listing : Try(List({ name : Str, is_dir : Bool, mtime : U64 }), [NotFound, Denied, Other(Str)])

	## The bin dir entry, as `SetupIo.have_of!` gives it.
	Have : [Absent, Dir, Unreadable, Sha(Str)]

	## R-ST10: the dirs that the sweep at the start of `tln` lists, on Windows: the bin dir (`Setup.bin_dir` with `Windows`, so `USERPROFILE`), then the data bin dir (`Roots.item` `Bin`, so `XDG_DATA_HOME` or `HOME`). A dir that cannot be found (its variable is not set, or is empty) is left out, and there is no failure: the command that runs after the sweep reports the variable itself (the sweep never changes an exit code or prints). Both left out: no dir.
	dirs : List((Str, Str)) -> List(Str)
	dirs = |env| {
		bin = Setup.bin_dir({ os: Windows, env }).map_ok(|dir| [dir]) ?? []
		data = Roots.from_env(env).map_ok(|roots| [Roots.item(roots, Item.Bin)]) ?? []
		bin.concat(data)
	}

	## R-ST10: the files that the sweep deletes. `listed` has the result of `list_dirs!` for each dir of `dirs`, in the same order. For each dir that was listed: the `.del` files (`TalonUpdate.stale`: files only, byte order, full paths). A dir that was not listed (`NotFound`, `Denied`, `Other`) gives none, and there is no failure. The dirs are in the order of `dirs`.
	found : { dirs : List(Str), listed : List(Del.Listing) } -> List(Str)
	found = |facts| facts.dirs.map_with_index(|dir, i| (dir, facts.listed.get(i))).join_map(
		|(dir, listing)| match listing {
			Ok(Ok(entries)) => TalonUpdate.stale({ dir, entries })
			_ => []
		},
	)

	## R-ST10, R-S3: the files of a tool that exist and that an install replaces (`tool install` of an installed tool, `tool update`, `tool rebuild`): the data file when `old` (the sha256 of the data file) is read, then the bin dir entry when it is a file (`Sha` or `Unreadable`: not `Absent`, and not a `Dir`, which is never replaced). These are the `files` of `TalonUpdate.del_moves`. A file that is not there is not renamed (no `rename` of a missing file).
	replaced : { data_file : Str, entry : Str, old : Try(Str, [NotFound]), have : Del.Have } -> List(Str)
	replaced = |facts| {
		data = match facts.old {
			Ok(_) => [facts.data_file]
			Err(NotFound) => []
		}
		entry = match facts.have {
			Sha(_) | Unreadable => [facts.entry]
			Absent | Dir => []
		}
		data.concat(entry)
	}

	## R-ST10, R-B6: the files of a tool that `tool remove` renames and then deletes: the bin dir entry when its fate is `Remove` (it is Talon's, `ToolManage.entry_fate`), then the data file when `old` is read. `Gone` and `Keep` give no entry. The order is the one of the delete of `ToolManageFlow` (entry first).
	removed : { data_file : Str, entry : Str, old : Try(Str, [NotFound]), fate : [Remove, Gone, Keep] } -> List(Str)
	removed = |facts| {
		entry = match facts.fate {
			Remove => [facts.entry]
			Gone | Keep => []
		}
		data = match facts.old {
			Ok(_) => [facts.data_file]
			Err(NotFound) => []
		}
		entry.concat(data)
	}
}
