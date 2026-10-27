import Fail
import Fx
import Item
import Projects
import Roots
import Temp
import Text

## The command code that records the project files that a command read (R-PD9). It is direct-style code over `Fx`
## (TESTING.md 2.2, part C). Slice 007 calls it at the end of each command that uses a project.
Known :: [].{

	## Records `files` (canonical absolute paths of the project files that the command read, R-PD9: a workspace command
	## has each member file that it read) in `projects.json`. `now` is `Clock.now` (`TALON_NOW`, R-EV22). With no
	## `files`: no `Fx` call. The calls, in order (the L2 case `files/cc-locked-update` fixes them):
	##
	## | Step | Call |
	## | --- | --- |
	## | 1 | `with_lock!` of the item `Roots.item(roots, ProjectsJson)`, mode `Wait` (R-CC6) |
	## | 2 | In the lock: `list_dirs!` of the directory of the item, then `delete!` of `Temp.of_item` when the list is not empty (R-CC2) |
	## | 3 | `read_files!` of the item. `NotFound` is `Missing`. Another failure is a failure of kind `Environment`. |
	## | 4 | `Projects.record` with `refresh: Always` |
	## | 5 | When the result is `Write(text)`: `write_atomic!` of the item (R-CC1). A failure is of kind `Environment`. |
	##
	## No `ask!` call in the lock (R-CC3 point 5). A failure of `Projects.record` is returned as it is (exit 19, R-TF6).
	record! : Fx, { roots : Roots, files : List(Str), now : U64 } => Try({}, Fail)
	record! = |fx, facts| record_with!(fx, facts, Always)

	## Slice 023, R-PD10: the same as `record!` for the `roc` proxy. An entry that is already there is written only when its last-use time is older than 1 day (`Projects.record` with `refresh: After(86400)`),
	## so most proxy runs write nothing. An entry that is new is written. The calls are those of `record!` (the lock, the list, the read, and the write only when the text changes).
	record_recent! : Fx, { roots : Roots, files : List(Str), now : U64 } => Try({}, Fail)
	record_recent! = |fx, facts| record_with!(fx, facts, After(86400))

	## R-PD12, R-RR2, R-GC5 (shared by `roc remove` and `cache gc`): the entries of `projects.json`, sorted by path. One `read_files!` of the item. A missing file has no entry. A text that does not parse is a failure of kind `Input` (exit 19, R-TF6).
	## Another read error is a failure of kind `Environment`. No lock: a reader sees the file before or after an atomic write (R-CC1).
	entries! : Fx, Roots => Try(List({ path : Str, last_use : U64 }), Fail)
	entries! = |fx, roots| {
		path = Roots.item(roots, Item.ProjectsJson)
		match fx.read_files!([path]) {
			[Ok(text)] => Projects.entries({ path, text })
			[Err(NotFound)] => Ok([])
			other => Err(Fail.new(Environment, "cannot read ${path}: ${Str.inspect(other)}"))
		}
	}
}

# R-PD9, R-PD10: the lock, the read and the write of `projects.json`. `refresh` is the rule for an entry that is already there.
record_with! : Fx, { roots : Roots, files : List(Str), now : U64 }, [Always, After(U64)] => Try({}, Fail)
record_with! = |fx, facts, refresh| {
	if facts.files.is_empty() return Ok({})
	item = Roots.item(facts.roots, Item.ProjectsJson)
	fx.locked!(item, || update!(fx, item, facts, refresh))
}

# The body of the lock (steps 2 to 5).
update! : Fx, Str, { roots : Roots, files : List(Str), now : U64 }, [Always, After(U64)] => Try({}, Fail)
update! = |fx, item, facts, refresh| {
	delete_temps!(fx, item)
	text = match fx.read_files!([item]) {
		[Ok(found)] => Ok(found)
		[Err(NotFound)] => Err(Missing)
		other => return Err(Fail.new(Environment, "cannot read ${item}: ${Str.inspect(other)}"))
	}
	changed = Projects.record({ path: item, text, cache: facts.roots.cache, files: facts.files, now: facts.now, refresh })?
	match changed {
		Unchanged => Ok({})
		Write(content) => match fx.write_atomic!([{ path: item, content }]) {
			Ok({}) => Ok({})
			Err({ path, err }) => Err(Fail.new(Environment, "cannot write ${path}: ${Str.inspect(err)}"))
		}
	}
}

# R-CC2: the holder of the lock deletes each temp of the item.
delete_temps! : Fx, Str => {}
delete_temps! = |fx, item| match fx.list_dirs!([Text.dir_of(item)]) {
	[Ok(entries)] => {
		temps = Temp.of_item({ item, entries })
		if !temps.is_empty() {
			_ = fx.delete!(temps)
		}
	}
	_ => {}
}
