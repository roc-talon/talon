import Diff
import Fail
import Intent
import LadderPlan
import Locked

## The pure decisions of the patches in the commands that resolve and in the `roc` proxy (R-PA4 to R-PA6, R-PA10, R-PX5; slice 043). Part A (TESTING.md 2.2). `tln patch` is slice 042 (`PatchCmd`).
## `PatchApply` is the command code of the move. The proxy (`Proxy`, `Base.load!`) and the ladder (`Ladder`) call the functions here.
## The texts are a proposal (R-OUT2, TW24): the human accepts or changes them at the review.
##
## A patch entry is a `[patch]` entry whose alias is a header entry that Talon manages (a release). The facts of one entry are in `Patched.Entry`.
## The copy is the dir that the `path` of the entry is in (`PatchCmd.copy_dir`). `base` is the hash of the package that the copy came from, and `hash` is the hash of the header entry now.
## The patch is stale (R-PA6) when `base` is not `hash`.
Patched :: [].{

	## One patch of a header: `alias` is the header entry and the key of `[patch]`. `url` is the value of the header entry and `hash` its hash (`Ident.hash`). `base` is the `base` of the `[patch]` entry.
	## `path` is the `path` of the entry as written in `talon.toml`. `file` is the absolute path of that file (relative to the dir of the `talon.toml`), and `dir` is the absolute dir of the copy: the dir of `file`, with no `/` at the end.
	Entry : { alias : Str, url : Str, hash : Str, base : Str, path : Str, file : Str, dir : Str }

	## R-PA12, R-PX5, R-PA14: the patches of one header. `rows` are the entries of the header, `patches` are the `[patch]` entries of the `talon.toml` of the member (`Intent.patches`), `toml` is the absolute path of that file.
	## An entry gives a `Patched.Entry` when its key is the alias of a header row that is a release and not the platform. The order is the order of the `[patch]` lines. An entry whose key is no alias of the header, or is the alias of
	## the platform, of a path entry or of a foreign URL is not a patch of this header: no entry, no failure (question Q5).
	entries : { rows : List(Locked.Row), patches : List(Intent.PatchEntry), toml : Str } -> List(Patched.Entry)
	entries = |_x| crash "todo: slice 043"

	## R-PA10, R-PX5: the `--replace-dep` pairs of the entries, in the order of the entries: the URL of the header entry and the absolute path of the main file of the copy.
	replaces : List(Patched.Entry) -> List(LadderPlan.Replace)
	replaces = |list| if list.is_empty() [] else crash "todo: slice 043"

	## R-PA6: the entries with a stale patch (`base` is not `hash`), in the order of the entries.
	stale : List(Patched.Entry) -> List(Patched.Entry)
	stale = |list| if list.is_empty() [] else crash "todo: slice 043"

	## R-PA6, R-EC14: the failure for stale patches. Kind `Frozen` (exit 14). `entries` are the stale entries (not empty). `by` is the command that stops: the proxy, or `tln install --frozen`.
	##
	## | `by` | Text |
	## | --- | --- |
	## | `Proxy` | `stale patch: <alias> (base <base>, the header has <hash>), <alias> (...). Run: tln install` |
	## | `Frozen` | `stale patch: <alias> (base <base>, the header has <hash>), <alias> (...). tln install --frozen does not rebase a patch. Run: tln install` |
	stale_fail : { entries : List(Patched.Entry), by : [Proxy, Frozen] } -> Fail
	stale_fail = |_x| crash "todo: slice 043"

	## R-PX5, R-PX7: the arguments that the proxy gives to the compiler. `target` is `Proxy.target` of the arguments. `replace` are the pairs of `replaces`.
	## `--replace-dep <old> <new>` is added for each pair, in order, at the end of the arguments that come before the first `--` (the arguments after `--` are for the app). The arguments are as they are (R-PX3) when:
	##
	## | Case | Why |
	## | --- | --- |
	## | `replace` is empty | nothing to add |
	## | `target` is `NoFile` (`version`, `help`, `install`, `run <name or bundle URL>`, `--help`) | no project file |
	## | The first argument is a word that is not `check`, `build`, `run`, `test`, `docs` or `deps` (for example `fmt`, `bundle`, `repl`): these commands have no `--replace-dep` flag (question Q4) | roc would refuse the flag |
	##
	## A first argument that starts with `-`, a first argument that ends in `.roc`, and no argument are the form `roc [options] [file]`: they get the flags.
	proxy_args : { args : List(Str), target : [File(Str), Main, NoFile], replace : List(LadderPlan.Replace) } -> List(Str)
	proxy_args = |x| if x.replace.is_empty() x.args else crash "todo: slice 043"

	## R-PA4, R-PA5, R-PA6: the patches that a command moves to a release, for the entries of one member. `chosen` has the URL that each header entry of the member has after the command (an entry that is not in the list keeps its URL).
	## An entry needs a rebase (`need`) when the hash of its URL after the command is not its `base`, and the entry moves (the URL changes), or `install` is true: this is `tln install` with no names, which applies a stale patch to the header release (R-PA6).
	## A stale patch in another command stays as it is (question Q6). A URL that is no release (`Ident.of_url` fails) needs nothing. `url` and `hash` are the new ones. The order is the order of the entries.
	need : { entries : List(Patched.Entry), chosen : List({ alias : Str, url : Str }), install : Bool } -> List({ entry : Patched.Entry, url : Str, hash : Str })
	need = |_x| crash "todo: slice 043"

	## R-PA5, R-PA7: the diff of the copy against the base package, applied to the files of the new release. `Diff.make` and `Diff.apply`. `Ok` has what `Diff.apply` does with each file (`done`). `Err` has the paths that do not apply (`failed`, not empty), in the order of the changes.
	rebase : { base : List(Diff.File), copy : List(Diff.File), target : List(Diff.File) } -> Try(List(Diff.Applied), List(Str))
	rebase = |_x| crash "todo: slice 043"

	## R-PA5, R-AL6: the failure for a release on which the diff does not apply: it is not a candidate for the entry. Kind `NoTuple` (exit 10), with `again` (`Fail.of_tuple`): the oracle loop drops the release (`hash`) and tries another tuple.
	## `name` and `version` are the new release. `dir` is the dir of the copy. `files` are the paths that do not apply. Text: `no tuple works: the patch of <alias> does not apply to <name> <version>: <file>, <file>. Edit the copy <dir>/, or remove the [patch] entry <alias>.`
	## (the explanation lists the files and names the 2 fixes, R-PA5).
	not_applied : { alias : Str, name : Str, version : Str, hash : Str, dir : Str, files : List(Str) } -> Fail
	not_applied = |_x| crash "todo: slice 043"
}
