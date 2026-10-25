import Diff
import Fail
import Fx
import Ident
import IntentEdit
import LadderPlan
import Patched
import PatchTree
import Pick
import ResolveBase
import Roots
import Temp
import Text
import Vars

## The move of a patch in the commands that resolve (R-PA4 to R-PA6, R-PA10; slice 043). Command code in direct style over `Fx` (TESTING.md 2.2, part C). The decisions are in `Patched` and `Diff`.
## `InstallFlow.finish!` calls `run!` after the pick and before the ladder, `finish!` after the write of the header, and `clean!` at the end (also after a failure, R-CC2).
## `calls.log` of `tests/commands/cases/patch/pa2-resolve` is the contract of the order of the calls.
##
## A patch needs a rebase (`Patched.need`) when the new header has another hash than the `base` of the entry, and the entry moves, or the command is `tln install` with no names (R-PA6).
## A command that has no `[patch]` entry for a header entry makes no call here (the old calls of all other cases do not change).
##
## | Step | Work | Calls and notes |
## | --- | --- | --- |
## | 1 | `run!`: for each member, `Patched.entries` of its header and the `[patch]` table of its `talon.toml`. No entry in any member: `PatchApply.none`, no call. The URL of each entry after the command is the URL that the pick chose for its variable, else the header URL. `Patched.need` | no call |
## | 2 | For each entry that needs a rebase, in the order of the members and of the `[patch]` lines: `PatchTree.read!` of 3 dirs in this order: `packages/<base>`, the copy, `packages/<new hash>` (R-PA13: a package is in the cache after the pick; a `packages/<base>` that is not in the cache is a failure `cannot read <dir>`, question Q2). Then `Patched.rebase`. A failure of one entry: `Patched.not_applied` for that entry (the first one), kind `NoTuple` with `again`: `InstallFlow.attempts!` drops the release and tries another tuple. No file is made yet | `list_dirs`, `read_files`, `sha256_file` |
## | 3 | All entries applied: `random!`, then the temp root `Roots.item(roots, TalonTmp(<hex>))`. For each entry: `copy_tree!` of `packages/<new hash>` to `<root>/<alias>`, one `write_atomic!` with the `Write` files, one `delete!` with the `Remove` paths (each call only when it has a path), one `make_dirs!` with the parent dirs of the `FromCopy` files, and one `copy_file!` for each `FromCopy` file (from the copy). | `random`, `copy_tree`, `write_atomic`, `delete`, `make_dirs`, `copy_file` |
## | 4 | The ladder gets `PatchApply.member(done, file)` for each member (`Ladder.Member.patch`): `base` are the pairs of `Patched.replaces` (the copies), `candidate` are the same, except that an entry that is rebased has the new header URL and the main file in its temp dir (R-PA10) | |
## | 5 | `finish!`, after the write of the headers, the keys and the new `base` of each patch (`InstallWrite.write!`, in the same read, check (R-CC7) and write as the keys of `talon.toml`; not with `--dry-run`, which writes nothing and prints the same lines): for each rebased entry `delete!` of the copy dir and `copy_tree!` of the temp dir to it (R-PA5: Talon replaces the copy). It gives the paths of the `talon.toml` files | `delete`, `copy_tree` |
## | 6 | `clean!`: one `delete!` of the temp root, when `run!` made it | `delete` |
##
## Output of `finish!` (a proposal, TW24), on `out!`, for each rebased entry: `rebased: <dir>/ (the patch of <alias>, now on <name> <version>)` and `<talon.toml>: ~ [patch] <alias> (base <hash>)`.
PatchApply :: [].{

	## What a ladder needs for one member file: the `--replace-dep` pairs of the baseline check and of the candidate (`LadderPlan.with_patches`).
	Member : { file : Str, base : List(LadderPlan.Replace), candidate : List(LadderPlan.Replace) }

	## A patch that moves to a new release: the `talon.toml` that has the entry, the entry, the new release (`name`, `version`, `hash`) and the temp dir with the patched tree.
	Rebased : { toml : Str, entry : Patched.Entry, name : Str, version : Str, hash : Str, temp : Str }

	## The result of `run!`. `root` is the temp root (`Ok` when `run!` made it).
	Done : { members : List(PatchApply.Member), rebased : List(PatchApply.Rebased), root : Try(Str, [None]) }

	## No patch: no pair, nothing rebased.
	none : PatchApply.Done
	none = { members: [], rebased: [], root: Err(None) }

	## The patches of one member: `Patched.entries` of its header and the `[patch]` table of its `talon.toml`. No `talon.toml`, no patch.
	entries : Vars.Member -> List(Patched.Entry)
	entries = |_m| []

	## The pairs of one member file. A file that `run!` has no pairs for (no patch) has empty lists.
	member : PatchApply.Done, Str -> { base : List(LadderPlan.Replace), candidate : List(LadderPlan.Replace) }
	member = |done, file| match done.members.find_first(|m| m.file == file) {
		Ok(m) => { base: m.base, candidate: m.candidate }
		Err(_) => { base: [], candidate: [] }
	}

	## Steps 1 to 4. `scoped` and `chosen` are the variables of the command and the values that the pick chose for them (the first `scoped.len()` values of the pick).
	run! : Fx, ResolveBase.Request, ResolveBase.Loaded, { scoped : List(Vars.Scoped), chosen : List(Pick.Chosen) } => Try(PatchApply.Done, Fail)
	run! = |_fx, _request, loaded, _x| if loaded.members.any(|m| has_patch(m)) crash "todo: slice 043" else Ok(PatchApply.none)

	## Step 5. It gives the paths of the `talon.toml` files that have a rebased entry.
	finish! : Fx, ResolveBase.Request, PatchApply.Done => Try(List(Str), Fail)
	finish! = |_fx, _request, done| if done.rebased.is_empty() Ok([]) else crash "todo: slice 043"

	## Step 6.
	clean! : Fx, PatchApply.Done => {}
	clean! = |_fx, _done| {}
}

# A member that has a `[patch]` entry in its `talon.toml`.
has_patch : Vars.Member -> Bool
has_patch = |m| match m.toml {
	Ok(t) => !t.intent.patches.is_empty()
	Err(NoToml) => Bool.False
}
