import Diff
import Fail
import Intent
import LadderPlan
import Ident
import Locked
import Text

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
	entries = |x| x.patches.keep_oks(|p| entry_of(x.rows, x.toml, p))

	## R-PA10, R-PX5: the `--replace-dep` pairs of the entries, in the order of the entries: the URL of the header entry and the absolute path of the main file of the copy.
	replaces : List(Patched.Entry) -> List(LadderPlan.Replace)
	replaces = |list| list.map(|e| { old: e.url, new: e.file })

	## R-PA6: the entries with a stale patch (`base` is not `hash`), in the order of the entries.
	stale : List(Patched.Entry) -> List(Patched.Entry)
	stale = |list| list.keep_if(|e| e.base != e.hash)

	## R-PA6, R-EC14: the failure for stale patches. Kind `Frozen` (exit 14). `entries` are the stale entries (not empty). `by` is the command that stops: the proxy, or `tln install --frozen`.
	##
	## | `by` | Text |
	## | --- | --- |
	## | `Proxy` | `stale patch: <alias> (base <base>, the header has <hash>), <alias> (...). Run: tln install` |
	## | `Frozen` | `stale patch: <alias> (base <base>, the header has <hash>), <alias> (...). tln install --frozen does not rebase a patch. Run: tln install` |
	stale_fail : { entries : List(Patched.Entry), by : [Proxy, Frozen] } -> Fail
	stale_fail = |x| {
		named = Str.join_with(x.entries.map(|e| "${e.alias} (base ${e.base}, the header has ${e.hash})"), ", ")
		ending = match x.by {
			Proxy => "Run: tln install"
			Frozen => "tln install --frozen does not rebase a patch. Run: tln install"
		}
		Fail.new(Frozen, "stale patch: ${named}. ${ending}")
	}

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
	proxy_args = |x| {
		takes_flag = match x.target {
			NoFile => Bool.False
			File(_) | Main => flag_form(x.args)
		}
		if x.replace.is_empty() or !takes_flag {
			x.args
		} else {
			flags = x.replace.join_map(|r| ["--replace-dep", r.old, r.new])
			match x.args.find_first_index(|a| a == "--") {
				Ok(i) => x.args.take_first(i).concat(flags).concat(x.args.drop_first(i))
				Err(_) => x.args.concat(flags)
			}
		}
	}

	## Slice 070, R-PA13: the release of the group of an entry that has the hash `base`. `urls` are the asset URLs of the candidates of the release list of the repository (`Index.Candidate.url`, any order), `group` is the group
	## of the header URL of the entry (`Ident.group`: the URL form and the series). A URL is a release of the group when `Ident.of_url` is `Ok` and its group and its `hash` are the ones of the arguments. The first such URL in the
	## order of `urls` is the answer. A hash that a release of another group (another series) has does not count. No such URL, an empty list and a URL that is no release are `Err(NoRelease)`.
	base_release : { urls : List(Str), group : { form : Str, series : Str }, base : Str } -> Try(Str, [NoRelease])
	base_release = |_x| crash "todo: slice 070"

	## Slice 070, R-PA13, R-PA5, R-EC14: the failure for an entry whose `base` no release of its group has. Kind `Frozen` (exit 14, as the stale patch of R-PA6: the machine is fine, the patch is not). `name` is `owner/repo` of the group,
	## `dir` is the dir of the copy (`Patched.Entry.dir`). The text names the base, the alias and the 2 fixes of R-PA5 (a proposal, TW24):
	## `the patch of <alias> has the base <base>, and no release of <name> has that hash, so Talon cannot take the diff of the copy. Edit the copy <dir>/, or remove the [patch] entry <alias>.`
	base_missing : { alias : Str, name : Str, base : Str, dir : Str } -> Fail
	base_missing = |_x| crash "todo: slice 070"

	## R-PA4, R-PA5, R-PA6: the patches that a command moves to a release, for the entries of one member. `chosen` has the URL that each header entry of the member has after the command (an entry that is not in the list keeps its URL).
	## An entry needs a rebase (`need`) when the hash of its URL after the command is not its `base`, and the entry moves (the URL changes), or `install` is true: this is `tln install` with no names, which applies a stale patch to the header release (R-PA6).
	## A stale patch in another command stays as it is (question Q6). A URL that is no release (`Ident.of_url` fails) needs nothing. `url` and `hash` are the new ones. The order is the order of the entries.
	need : { entries : List(Patched.Entry), chosen : List({ alias : Str, url : Str }), install : Bool } -> List({ entry : Patched.Entry, url : Str, hash : Str })
	need = |x| x.entries.keep_oks(|e| need_of(e, x.chosen, x.install))

	## R-PA5, R-PA7: the diff of the copy against the base package, applied to the files of the new release. `Diff.make` and `Diff.apply`. `Ok` has what `Diff.apply` does with each file (`done`). `Err` has the paths that do not apply (`failed`, not empty), in the order of the changes.
	rebase : { base : List(Diff.File), copy : List(Diff.File), target : List(Diff.File) } -> Try(List(Diff.Applied), List(Str))
	rebase = |x| {
		applied = Diff.apply({ changes: Diff.make({ base: x.base, copy: x.copy }), target: x.target })
		if applied.failed.is_empty() Ok(applied.done) else Err(applied.failed)
	}

	## R-PA5, R-AL6: the failure for a release on which the diff does not apply: it is not a candidate for the entry. Kind `NoTuple` (exit 10), with `again` (`Fail.of_tuple`): the oracle loop drops the release (`hash`) and tries another tuple.
	## `name` and `version` are the new release. `dir` is the dir of the copy. `files` are the paths that do not apply. Text: `no tuple works: the patch of <alias> does not apply to <name> <version>: <file>, <file>. Edit the copy <dir>/, or remove the [patch] entry <alias>.`
	## (the explanation lists the files and names the 2 fixes, R-PA5).
	not_applied : { alias : Str, name : Str, version : Str, hash : Str, dir : Str, files : List(Str) } -> Fail
	not_applied = |x| Fail.of_tuple(
		"no tuple works: the patch of ${x.alias} does not apply to ${x.name} ${x.version}: ${Str.join_with(x.files, ", ")}. Edit the copy ${x.dir}/, or remove the [patch] entry ${x.alias}.",
		[x.hash],
	)
}

# The entry of one `[patch]` line: its key is the alias of a release row that is not the platform. Another key gives no entry.
entry_of : List(Locked.Row), Str, Intent.PatchEntry -> Try(Patched.Entry, [NotManaged])
entry_of = |rows, toml, p| match rows.find_first(|r| r.alias == p.key and !r.is_platform) {
	Ok({ what: Release(ident), value, .. }) => {
		file = Text.resolve(Text.dir_of(toml), p.path)
		Ok({ alias: p.key, url: value, hash: ident.hash, base: p.base, path: p.path, file, dir: Text.dir_of(file) })
	}
	_ => Err(NotManaged)
}

# A first argument that is a flag, a `.roc` file or one of the commands that take `--replace-dep`, or no argument: the form `roc [options] [file]`, or a command with the flag (question Q4).
flag_form : List(Str) -> Bool
flag_form = |args| match args {
	[] => Bool.True
	[first, ..] => first.starts_with("-") or first.ends_with(".roc") or ["check", "build", "run", "test", "docs", "deps"].contains(first)
}

# R-PA5, R-PA6: the new release of one entry, when the entry needs a rebase.
need_of : Patched.Entry, List({ alias : Str, url : Str }), Bool -> Try({ entry : Patched.Entry, url : Str, hash : Str }, [NoRebase])
need_of = |e, chosen, install| {
	url = match chosen.find_first(|c| c.alias == e.alias) {
		Ok(c) => c.url
		Err(_) => e.url
	}
	match Ident.of_url(url) {
		Ok(ident) => if ident.hash != e.base and (url != e.url or install) Ok({ entry: e, url, hash: ident.hash }) else Err(NoRebase)
		Err(Foreign) => Err(NoRebase)
	}
}
