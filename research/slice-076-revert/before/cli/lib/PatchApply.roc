import Diff
import Fail
import Fx
import Github
import Ident
import IntentEdit
import LadderPlan
import Patched
import PatchTree
import Pick
import PickIndex
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
## | 2a | Slice 070 (R-PA13), for each entry that needs a rebase, before step 2: one `list_dirs!` of `[packages/<base>]`. The dir is there: step 2. Missing: the group of the header URL of the entry (`Ident.of_url(entry.url)`: `name` and `group`) gives the repository, and `PickIndex.index!` reads its release list (the calls of `Github.releases!`, with the warnings and the line `index: cached at <time>` on stderr). A list that is `missing` (`--offline` with no cached page): `Github.no_page_failure(<name>)` (exit 15). Else `Patched.base_release` of the URLs of the candidates: `Err(NoRelease)` is `Patched.base_missing` (exit 14, not a `NoTuple`: no other release helps). A release that has the hash: the base is to be fetched by hash (R-PA13); that fetch is not in slice 070 (question Q1 of its file): step 2 goes on and fails with `cannot read <dir>` as before | R-PA13, R-DI12 |
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
	entries = |m| match m.toml {
		Ok(t) => Patched.entries({ rows: m.locked.rows, patches: t.intent.patches, toml: t.path })
		Err(NoToml) => []
	}

	## The pairs of one member file. A file that `run!` has no pairs for (no patch) has empty lists.
	member : PatchApply.Done, Str -> { base : List(LadderPlan.Replace), candidate : List(LadderPlan.Replace) }
	member = |done, file| match done.members.find_first(|m| m.file == file) {
		Ok(m) => { base: m.base, candidate: m.candidate }
		Err(_) => { base: [], candidate: [] }
	}

	## Steps 1 to 4. `scoped` and `chosen` are the variables of the command and the values that the pick chose for them (the first `scoped.len()` values of the pick).
	run! : Fx, ResolveBase.Request, ResolveBase.Loaded, { scoped : List(Vars.Scoped), chosen : List(Pick.Chosen) } => Try(PatchApply.Done, Fail)
	run! = |fx, request, loaded, x| {
		wanted = loaded.members.map(|m| { member: m, entries: PatchApply.entries(m) }).keep_if(|w| !w.entries.is_empty())
		if wanted.is_empty() return Ok(PatchApply.none)
		install = request.command == Install and request.names.is_empty()
		needs = wanted.join_map(
			|w| Patched.need({ entries: w.entries, chosen: chosen_of(w.member, x), install }).map(|n| { toml: toml_of(w.member), file: w.member.file, entry: n.entry, url: n.url, hash: n.hash }),
		)
		applied = read_all!(fx, request, needs)?
		if applied.is_empty() {
			pairs = wanted.map(|w| { file: w.member.file, base: Patched.replaces(w.entries), candidate: Patched.replaces(w.entries) })
			return Ok({ members: pairs, rebased: [], root: Err(None) })
		}
		root = Roots.item(request.roots, TalonTmp("patch-${Temp.hex(fx.random!())}"))
		rebased = build_all!(fx, request, root, applied)?
		moved = applied.map2(rebased, |a, r| { found: a.found, temp: r.temp })
		members = wanted.map(|w| member_of(w.member.file, w.entries, moved))
		Ok({ members, rebased, root: Ok(root) })
	}

	## Step 5. It gives the paths of the `talon.toml` files that have a rebased entry.
	finish! : Fx, ResolveBase.Request, PatchApply.Done => Try(List(Str), Fail)
	finish! = |fx, request, done| {
		var $touched = []
		for r in done.rebased {
			if !request.dry_run {
				_ = fx.delete!([r.entry.dir])
				match fx.copy_tree!({ from: r.temp, to: r.entry.dir, skip: [] }) {
					Ok(_) => {}
					Err(_) => return Err(Fail.new(Environment, "cannot copy ${r.temp} to ${r.entry.dir}"))
				}
			}
			fx.out!("rebased: ${r.entry.dir}/ (the patch of ${r.entry.alias}, now on ${r.name} ${r.version})\n")
			fx.out!("${r.toml}: ~ [patch] ${r.entry.alias} (base ${r.hash})\n")
			if !$touched.contains(r.toml) {
				$touched = $touched.append(r.toml)
			}
		}
		Ok($touched)
	}

	## Step 6.
	clean! : Fx, PatchApply.Done => {}
	clean! = |fx, done| match done.root {
		Ok(root) => {
			_ = fx.delete!([root])
		}
		Err(None) => {}
	}
}

# A patch that moves: the member, its `talon.toml`, the entry and the new release.
Found : { toml : Str, file : Str, entry : Patched.Entry, url : Str, hash : Str }

# The path of the `talon.toml` of a member that has patch entries.
toml_of : Vars.Member -> Str
toml_of = |m| match m.toml {
	Ok(t) => t.path
	Err(NoToml) => ""
}

# The URL that each header entry of the member has after the command: the value that the pick chose for its variable. A variable that stays keeps the URL of each entry.
chosen_of : Vars.Member, { scoped : List(Vars.Scoped), chosen : List(Pick.Chosen) } -> List({ alias : Str, url : Str })
chosen_of = |m, x| x.scoped.map2(x.chosen, |s, c| (s, c)).join_map(
	|(s, c)| s.variable.uses.keep_if(|u| u.file == m.file).map(
		|u| match c.change {
			Keep => { alias: u.alias, url: u.url }
			Move(_) => { alias: u.alias, url: c.url }
		},
	),
)

# R-PA5, R-PA13: for each entry that moves, the apply of its diff to the new release (no file is made). The first release that does not apply gives the failure that drops the release.
read_all! : Fx, ResolveBase.Request, List(Found) => Try(List({ found : Found, done : List(Diff.Applied) }), Fail)
read_all! = |fx, request, needs| {
	var $applied = []
	for found in needs {
		$applied = $applied.append({ found, done: rebase_one!(fx, request, found)? })
	}
	Ok($applied)
}

rebase_one! : Fx, ResolveBase.Request, Found => Try(List(Diff.Applied), Fail)
rebase_one! = |fx, request, found| {
	cached = |hash| Roots.item(request.roots, Package(hash))
	entry = found.entry
	base_check!(fx, request, entry)?
	trees = PatchTree.read!(fx, { dirs: [cached(entry.base), entry.dir, cached(found.hash)], copy: entry.dir })?
	match trees {
		[base, copy, target] => match Patched.rebase({ base, copy, target }) {
			Ok(done) => Ok(done)
			Err(files) => {
				(name, version) = release_of(found.url)
				Err(Patched.not_applied({ alias: entry.alias, name, version, hash: found.hash, dir: entry.dir, files }))
			}
		}
		_ => Err(Fail.new(Internal, "PatchTree.read! gave a wrong number of trees"))
	}
}

# Step 2a, R-PA13: a `packages/<base>` that is not in the cache. The release list of the group of the entry must have a release with the hash. No such release: exit 14. A release that has it: step 2 goes on (the fetch is not in slice 070).
base_check! : Fx, ResolveBase.Request, Patched.Entry => Try({}, Fail)
base_check! = |fx, request, entry| match fx.list_dirs!([Roots.item(request.roots, Package(entry.base))]) {
	[Ok(_)] => Ok({})
	_ => match Ident.of_url(entry.url) {
		Ok({ name: Ok(name), group, .. }) => {
			found = PickIndex.index!(fx, request, [name], [])?
			match found {
				[candidates] => if candidates.missing {
					Err(Github.no_page_failure(name))
				} else {
					match Patched.base_release({ urls: candidates.list.map(|c| c.url), group, base: entry.base }) {
						Ok(_) => Ok({})
						Err(NoRelease) => Err(Patched.base_missing({ alias: entry.alias, name, base: entry.base, dir: entry.dir }))
					}
				}
				_ => Ok({})
			}
		}
		_ => Ok({})
	}
}

# The name and the version of a release URL, for the texts.
release_of : Str -> (Str, Str)
release_of = |url| match Ident.of_url(url) {
	Ok(ident) => (ident.name ?? ident.group.form, ident.version)
	Err(Foreign) => (url, "")
}

# The temp dir of each patch (one dir for each alias, D6: a second patch of the same alias gets a number) with the patched tree of the new release.
build_all! : Fx, ResolveBase.Request, Str, List({ found : Found, done : List(Diff.Applied) }) => Try(List(PatchApply.Rebased), Fail)
build_all! = |fx, request, root, applied| {
	var $rebased = []
	for (i, a) in applied.map_with_index(|a, i| (i, a)) {
		alias = a.found.entry.alias
		earlier = applied.take_first(i).count_if(|b| b.found.entry.alias == alias)
		temp = Text.join(root, if earlier == 0 alias else "${alias}-${earlier.to_str()}")
		match build!(fx, request, temp, a) {
			Ok({}) => {}
			Err(fail) => {
				_ = fx.delete!([root])
				return Err(fail)
			}
		}
		(name, version) = release_of(a.found.url)
		$rebased = $rebased.append({ toml: a.found.toml, entry: a.found.entry, name, version, hash: a.found.hash, temp })
	}
	Ok($rebased)
}

# Step 3: the new release in the temp dir, the files that the diff writes, the files that it deletes and the files that come from the copy.
build! : Fx, ResolveBase.Request, Str, { found : Found, done : List(Diff.Applied) } => Try({}, Fail)
build! = |fx, request, temp, a| {
	at = |rel| Text.join(temp, rel)
	from = Roots.item(request.roots, Package(a.found.hash))
	match fx.copy_tree!({ from, to: temp, skip: [] }) {
		Ok(_) => {}
		Err(_) => return Err(Fail.new(Environment, "cannot copy ${from} to ${temp}"))
	}
	writes = a.done.keep_oks(
		|d| match d.what {
			Write(text) => Ok({ path: at(d.path), content: text })
			_ => Err(NoWrite)
		},
	)
	gone = a.done.keep_oks(
		|d| match d.what {
			Remove | FromCopy => Ok(at(d.path))
			Write(_) => Err(NoDelete)
		},
	)
	copied = a.done.keep_oks(
		|d| match d.what {
			FromCopy => Ok(d.path)
			_ => Err(NoCopy)
		},
	)
	if !writes.is_empty() {
		match fx.write_atomic!(writes) {
			Ok(_) => {}
			Err(failed) => return Err(Fail.new(Environment, "cannot write ${failed.path}"))
		}
	}
	if !gone.is_empty() {
		_ = fx.delete!(gone)
	}
	if !copied.is_empty() {
		match fx.make_dirs!(Text.sorted_unique(copied.map(|rel| Text.dir_of(at(rel))))) {
			Ok(_) => {}
			Err(_) => return Err(Fail.new(Environment, "cannot make a dir in ${temp}"))
		}
	}
	for rel in copied {
		match fx.copy_file!({ from: Text.join(a.found.entry.dir, rel), to: at(rel) }) {
			Ok(_) => {}
			Err(_) => return Err(Fail.new(Environment, "cannot copy ${Text.join(a.found.entry.dir, rel)} to ${at(rel)}"))
		}
	}
	Ok({})
}

# R-PA10: the pairs of one member file. The baseline has the copies. The candidate has the temp tree and the new URL for an entry that moves.
member_of : Str, List(Patched.Entry), List({ found : Found, temp : Str }) -> PatchApply.Member
member_of = |file, entries, moved| {
	candidate = entries.map(
		|e| match moved.find_first(|m| m.found.file == file and m.found.entry.alias == e.alias) {
			Ok(m) => { old: m.found.url, new: Text.join(m.temp, Text.last_segment(e.file)) }
			Err(_) => { old: e.url, new: e.file }
		},
	)
	{ file, base: Patched.replaces(entries), candidate }
}
