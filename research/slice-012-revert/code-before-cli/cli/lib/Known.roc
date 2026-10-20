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
	record! = |fx, facts| {
		if facts.files.is_empty() return Ok({})
		item = Roots.item(facts.roots, Item.ProjectsJson)
		match fx.with_lock!(item, Wait, || update!(fx, item, facts)) {
			Ok({}) => Ok({})
			Err(Failed(fail)) => Err(fail)
			Err(Busy) => Err(Fail.new(Internal, "the lock of ${item} was not taken"))
		}
	}
}

# The body of the lock (steps 2 to 5).
update! : Fx, Str, { roots : Roots, files : List(Str), now : U64 } => Try({}, Fail)
update! = |fx, item, facts| {
	delete_temps!(fx, item)
	text = match fx.read_files!([item]) {
		[Ok(found)] => Ok(found)
		[Err(NotFound)] => Err(Missing)
		other => return Err(Fail.new(Environment, "cannot read ${item}: ${Str.inspect(other)}"))
	}
	changed = Projects.record({ path: item, text, cache: facts.roots.cache, files: facts.files, now: facts.now, refresh: Always })?
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
