import Args
import Common
import Diff
import Fail
import Fetch
import Fx
import Install
import IntentEdit
import Known
import Ls
import Out
import PatchCmd
import PatchTree
import ResolveBase
import ResolveLoad
import Roots
import Text

## The command `tln patch` (R-CM10, R-PA1 to R-PA3, R-PA8, R-PA14, R-PD14; slice 042). Command code in direct style over `Fx` (TESTING.md 2.2, part C). The pure decisions are in `PatchCmd` and `Diff`.
## `calls.log` of `tests/commands/cases/patch/pa1-flow` is the contract of the order of the calls. The steps:
##
## | Step | Work | Calls and notes |
## | --- | --- | --- |
## | 1 | `PatchCmd.read(args)`. A failure is printed as the other commands print it (exit 2) | no `Fx` call |
## | 2 | The start of `tln install`: `Install.begin!` (the environment, the clock, the project, the record in `projects.json` R-PD9), the member check, the load of the project as `tln list` loads it (`Ls.request_of`, `ResolveLoad.load!`) | the first calls of each run in `calls.log` |
## | 3 | The member is the project file. `PatchCmd.entry` of the name and the rows of the member. A failure: its `block` (if not empty) on stderr, then the failure | no call |
## | 4 | The `talon.toml` of the member, or `<dir of the file>/talon.toml` when there is none | no call |
## | 5a | Without `--diff`: `list_dirs` of the copy dir (`PatchCmd.place`). It answers `Ok`: failure `PatchCmd.exists` (exit 2), nothing else. Then the fetch of the release by hash (`Fetch.packages!`, R-PA13: offline fails as any fetch), `copy_tree!` of `packages/<hash>` to the copy dir, `IntentEdit.add_patch`, one `write_atomic!` of `talon.toml`. Output: `PatchCmd.created` | `list_dirs`, `random` and `list_dirs` of the package dir (the fetch), `copy_tree`, `write_atomic` |
## | 5b | With `--diff`: the entry of `[patch]` (`Intent.patches` of the `talon.toml` of the member) whose key is the alias. None: failure kind `Usage`, `<alias> has no patch. Run tln patch <alias> first.` (answer Q1, run 13). A copy dir that is missing (the answer of `list_dirs` for the dir of the copy): failure kind `Usage`, `<dir>/ is missing. Restore the copy, or remove the entry from [patch].` (run 14). The base is the `base` of the entry: when it is the hash of the header entry the package is fetched as in 5a (it may be missing), else it must be in the cache. The 2 trees are read level by level (one `list_dirs` call for the 2 dirs of a level), then one `read_files` call for all files (a file that is not UTF-8 text: `sha256_file`). `Diff.make`, then `PatchCmd.shown`. Nothing is written | `list_dirs`, `read_files`, `sha256_file` |
## | 6 | Output: without `--diff`, the text goes through `Common.shown_fx` (stderr with `--json`), with `--diff` the diff goes to stdout (`--json`: the envelope only). `--json` prints the envelope with `command` `patch` (`args.typed`) and the `data` of `PatchCmd`. The `note` goes to stderr | `out`, `err` |
##
## A failure of the file system: kind `Environment` (`cannot copy <from> to <dir>`, `cannot write <path>`, `cannot read <path>`): no test (question Q7). Exit codes: R-EC2.
PatchFlow :: [].{

	run! : Fx, Args => I32
	run! = |fx, args| match PatchCmd.read(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(opts) => match flow!(fx, args, opts) {
			Ok({}) => 0
			Err(fail) => Common.failed!(fx, args, fail)
		}
	}
}

# What steps 2 to 4 give: the run, the member file and its `talon.toml` (`created` is true when the file is not there).
Facts : { request : ResolveBase.Request, loaded : ResolveBase.Loaded, target : PatchCmd.Target, toml : { path : Str, text : Str, created : Bool }, patches : List({ key : Str, path : Str, base : Str }) }

flow! : Fx, Args, { name : Str, diff : Bool } => Try({}, Fail)
flow! = |fx, args, opts| {
	start = Install.begin!(fx, args)?
	Install.check_member(Bool.True, start.project)?
	Known.record!(fx, { roots: start.roots, files: Install.canonical_files!(fx, start.project), now: start.now })?
	request = Ls.request_of(args, start)
	loaded = ResolveLoad.load!(fx, request)?
	facts = facts_of!(fx, request, loaded, opts.name)?
	if opts.diff review!(fx, args, facts) else copy!(fx, args, facts)
}

# Steps 3 and 4: the member, the entry that the name selects, and the `talon.toml` of the member.
facts_of! : Fx, ResolveBase.Request, ResolveBase.Loaded, Str => Try(Facts, Fail)
facts_of! = |fx, request, loaded, name| {
	current = request.project.file ?? ""
	member = match loaded.members.find_first(|m| m.file == current) {
		Ok(m) => m
		Err(_) => return Err(Fail.new(Usage, "no current member: pass --file <member file>"))
	}
	target = match PatchCmd.entry({ text: name, rows: member.locked.rows }) {
		Ok(t) => t
		Err({ fail, block }) => {
			if !block.is_empty() fx.err!(block)
			return Err(fail)
		}
	}
	found = match member.toml {
		Ok(t) => Ok({ path: t.path, text: loaded.tomls.find_first(|f| f.path == t.path).map_ok(|f| f.text) ?? "", patches: t.intent.patches })
		Err(NoToml) => Err(NoToml)
	}
	toml = match found {
		Ok(f) => { path: f.path, text: f.text, created: Bool.False }
		Err(NoToml) => { path: Text.join(Text.dir_of(current), "talon.toml"), text: "", created: Bool.True }
	}
	patches = match found {
		Ok(f) => f.patches
		Err(NoToml) => []
	}
	Ok({ request, loaded, target, toml, patches })
}

# Step 5a: the copy of the package, and the `[patch]` entry.
copy! : Fx, Args, Facts => Try({}, Fail)
copy! = |fx, args, facts| {
	place = PatchCmd.place({ toml: facts.toml.path, alias: facts.target.alias })
	dir = place.dir.drop_suffix("/")
	match fx.list_dirs!([dir]) {
		[Err(NotFound)] => {}
		[Err(_)] => return Err(Fail.new(Environment, "cannot read ${dir}"))
		_ => return Err(PatchCmd.exists(place.dir))
	}
	fetch!(fx, facts)?
	edited = IntentEdit.add_patch({ path: facts.toml.path, text: facts.toml.text, alias: facts.target.alias, entry: place.entry_path, base: facts.target.hash })?
	from = package_dir(facts, facts.target.hash)
	match fx.copy_tree!({ from, to: dir, skip: [] }) {
		Ok(_) => {}
		Err(_) => return Err(Fail.new(Environment, "cannot copy ${from} to ${dir}"))
	}
	match fx.write_atomic!([{ path: facts.toml.path, content: edited }]) {
		Ok(_) => {}
		Err(_) => return Err(Fail.new(Environment, "cannot write ${facts.toml.path}"))
	}
	made = PatchCmd.created({ target: facts.target, dir: place.dir, toml: facts.toml.path, toml_created: facts.toml.created })
	Common.shown_fx(fx, args).out!(made.text)
	if args.json {
		fx.out!(Out.json_ok({ command: args.typed, data: made.data }))
	}
	Ok({})
}

# Step 5b: the diff of the copy against the base package. Nothing is written.
review! : Fx, Args, Facts => Try({}, Fail)
review! = |fx, args, facts| {
	alias = facts.target.alias
	entry = match facts.patches.find_first(|p| p.key == alias) {
		Ok(found) => found
		Err(_) => return Err(Fail.new(Usage, "${alias} has no patch. Run tln patch ${alias} first."))
	}
	copy = PatchCmd.copy_dir({ toml: facts.toml.path, path: entry.path })
	fetch!(fx, facts)?
	trees = read_trees!(fx, package_dir(facts, entry.base), copy.drop_suffix("/"))?
	shown = PatchCmd.shown({ alias, base: entry.base, dir: copy, changes: Diff.make(trees) })
	if args.json {
		fx.out!(Out.json_ok({ command: args.typed, data: shown.data }))
	} else {
		fx.out!(shown.text)
	}
	if !shown.note.is_empty() fx.err!(shown.note)
	Ok({})
}

package_dir : Facts, Str -> Str
package_dir = |facts, hash| Roots.item(facts.request.roots, Package(hash))

# R-PA13: the release of the header entry is fetched by its hash (a package that is in the cache is not fetched again).
fetch! : Fx, Facts => Try({}, Fail)
fetch! = |fx, facts| match Fetch.packages!(fx, { roots: facts.request.roots, urls: [facts.target.url], offline: facts.request.offline, roc: "roc", downloader: facts.request.net.downloader }) {
	[Err(fail)] => Err(fail)
	_ => Ok({})
}

# The files of the base and of the copy (`PatchTree.read!`).
read_trees! : Fx, Str, Str => Try({ base : List(Diff.File), copy : List(Diff.File) }, Fail)
read_trees! = |fx, base_dir, copy_dir| match PatchTree.read!(fx, { dirs: [base_dir, copy_dir], copy: copy_dir })? {
	[base, copy] => Ok({ base, copy })
	_ => Err(Fail.new(Internal, "PatchTree.read! gave a wrong number of trees"))
}
