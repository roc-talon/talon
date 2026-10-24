import Args
import Fx

## The commands `tln roc link <name> <path>` and `tln roc link --copy [--force] <name> <path>` (slice 024b, CLI 6.6: R-R12, R-R13, R-LK1 to R-LK4; R-CM15). Direct style over `Fx` (TESTING.md 2.2 part C): `Link` decides,
## this module orders the calls. `Run.tln!` calls `RocLink.link!` for the command `["roc", "link"]`. The calls, in order (the L2 case `link/lk1-link` and the L3 case `compilers/lk1-link-real` fix them).
## The one new `Fx` call is `copy_file!`.
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `Link.read(args)`. A failure is printed with `Install.failed!` (no `Fx` call). | R-CM15, R-FL12 |
## | 2 | `env_all!`, `Roots.from_env`, `cwd!`. The path of the operand is made absolute with `Text.resolve(cwd, typed)`. | R-LK4 |
## | 3 | One `canonical!` call with `full` (step 2 made it with `Text.resolve`), only to check that the file exists. `Link.source` gives `full` (no symbolic link is resolved), or the failure (no such file: exit 2). It is the same check for `link` and `link --copy`. | R-R12, R-R13 |
## | 4 | `Fx.with_lock!` on the item `Roots.item(Toolchain(id))` with `Wait` (the lock of `roc install` and of `roc remove`: `waiting for another tln: <item>` once when it is busy, R-CC5). | R-CC3, R-CC4 |
## | 5 | In the lock: `Launch.toolchains!` (one `list_dirs!`), then `Link.decide`. A failure ends the command (no write). | R-LK2 |
## | 6 | `random!`, then the temp dir `Temp.name({ target: item, hex })`. A link: one `write_atomic!` of `<temp>/.talon.json` (`Link.meta`). A copy: `copy_file!` from `full` to `<temp>/roc`, then `write_atomic!` of `<temp>/.talon.json` last. A failure of a step: `delete!` of the temp dir, then the failure (kind `Environment`: `cannot copy <path>: <error>` or `cannot write <path>`). | R-CC1, R-CC4 step 6, R-LK2 |
## | 7 | `Replace` only: `rename!` of the item to `Manage.trash_name({ item, hex })`. Then `rename!` of the temp dir to the item. Then (`Replace`) `delete!` of the trash dir; a failed delete is ignored (GC removes it, R-CC2). A failed `rename!` of the temp dir deletes the temp dir. | R-CC10, R-LK2 |
## | 8 | The output: `Link.report` on stdout (with `--json` on stderr, and stdout is only the envelope with `Link.data`). `--quiet` hides the stdout line (`Install.shown_fx`). | R-OUT2, R-J3 |
##
## `link` and `link --copy` never write `config.toml` (R-SO15 is for an install), never write `.last-use` (no compiler ran), and never run the target.
RocLink :: [].{

	## Steps 1 to 8.
	link! : Fx, Args => I32
	link! = |_fx, _args| crash "todo"
}
