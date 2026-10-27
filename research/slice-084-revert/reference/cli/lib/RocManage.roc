import Args
import Common
import Compiler
import Fail
import Fx
import Known
import Launch
import Manage
import ManageUpdate
import Nightlies
import Out
import Pin
import RocInstall
import Roots
import Toolchain
import Trash

## The commands `tln roc list` (`ls`), `tln roc default <ref>`, `tln roc remove <id>` (`rm`) and `tln roc update` (`up`, slice 026) (slice 024, CLI 6.6: R-CS2, R-RR1 to R-RR3; R-CM15, R-CM19). Direct style over `Fx` (TESTING.md 2.2 part C): `Manage` decides, this module orders
## the calls. `Run.tln!` calls them for the commands `["roc", "list"]`, `["roc", "default"]` and `["roc", "remove"]`. The calls, in order (the L2 cases `roc/ls1-list`, `roc/df1-default`
## and `roc/rm1-remove`, and the L3 case `compilers/mg1-manage` fix them). There is no new `Fx` call in this slice.
##
## `roc list`:
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `Manage.read_list(args)`. A failure is printed with `Common.failed!` (no `Fx` call). | R-CM15 |
## | 2 | `env_all!`, `Roots.from_env`, then one `read_files!` of `config.toml` (a missing file is the empty text), `Intent.read_config` (the warnings go to stderr, one line each, `warning: <text>`). No `clock!`, no `platform!`. | R-LY1 |
## | 3 | `Launch.toolchains!`: one `list_dirs!` of `<cache>/toolchains` | R-LY1 |
## | 4 | One `read_files!` with 2 paths for each installed id, in the order of the ids: `.talon.json`, then `.last-use`. No call when no compiler is installed. | R-CC9 |
## | 5 | `Manage.rows` and `Manage.origins` (slice 071, R-R15: the repo and the typed ref of a `git-*` id, from the same `.talon.json` text: no new `Fx` call), then the table on stdout and the warning on stderr (`Manage.ls_report`). With `--json` stdout is only the envelope (`Manage.ls_data`) and no table is printed. The table is the answer of the command: `--quiet` does not hide it. | R-OUT2, R-J3 |
##
## `roc default`:
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `Manage.read` with `Default`. A failure is printed with `Common.failed!`. | R-CM15 |
## | 2 | `env_all!`, `Roots.from_env`, `Launch.toolchains!` (one `list_dirs!`) | R-LY1 |
## | 3 | The installed compilers first (R-SC9: `git-dd03` is a prefix of an installed id, and no list has it). A text that does not start with `@` goes to `Nightlies.pick` with `named` and `auto` both the installed ids and `base: Err(None)`. `Ok(id)`: go to step 5. `Ambiguous`: `Nightlies.failure`. `NoMatch`, and a text that starts with `@`: step 4. | R-SC5, R-SC10, R-SC13, R-R5 |
## | 4 | The text names a compiler that is not installed: `RocInstall.offer!` (`id` the text, `offline` from `--offline`). `Present(found)`: step 5 with `found.id`. `Download(offer)`: `Prompt.ask!` with `Consent.roc_install` (the prompt of `roc install`, R-DL3: the command names the download, so the default is yes), a decline is `Consent.roc_install_declined` (exit 13, nothing changes). Then `RocInstall.install_offer!`. | R-DL3, R-DL4, R-NI6, R-CC4 |
## | 5 | `Fx.with_lock!` on `Roots.item(Config)` with `Wait`: `read_files!` of `config.toml` (a missing file is the empty text), `Manage.default_set`. `Same`: no more calls. `Set(text)`: a second `read_files!`, the bytes must be the first bytes, else `default_set` runs on the new bytes (R-CC7), then `write_atomic!`. | R-CS2, R-CC6, R-CC7 |
## | 6 | The output: `Manage.default_report` on stdout (with `--json` on stderr, and stdout is only the envelope with `Manage.default_data`). The compat warnings of an install: the `stderr` lines of `Toolchain.report` (`how` `Installed`). | R-OUT2, R-J3 |
##
## `roc remove`:
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `Manage.read` with `Remove`. A failure is printed with `Common.failed!`. | R-CM15 |
## | 2 | `env_all!`, `Roots.from_env`, one `read_files!` of `config.toml`, `Intent.read_config` (warnings as in `list`): `default_roc` and the `nightly` switch (`Pin.switch` with `Common.nightly_of(env)`, no `talon.toml`, R-NS8) | R-RR1, R-NS3 |
## | 3 | `Launch.toolchains!`. `Nightlies.pick` with `named` and `auto` the installed ids and `base: Err(None)`: a full id, or a prefix of an installed id. A failure is `Nightlies.failure` (`no compiler matches <text>`, or the ambiguous list: exit 2). | R-SC5, R-SC10 |
## | 4 | One `read_files!` of `projects.json` (`Missing` is no project), `Projects.entries` (a failure: exit 19, R-TF6). With one project or more: one `read_files!` of the project files, in the order of the entries. Then `Manage.pinned_by`. | R-RR2, R-PD9 |
## | 5 | One `read_files!` of the `.talon.json` of each installed id, in the order of the ids: `Manage.compat_of` for the id, `Compiler.times` for the order of `next_default`. | R-GC3, R-RR1 |
## | 6 | `Fx.with_lock!` on the item `Roots.item(Toolchain(id))` with `Wait` (`Fx.with_lock!` prints `waiting for another tln: <item>` once when the lock is busy, as `roc install`, R-CC5). In the lock: `random!`, `rename!` of the item to `Manage.trash_name`, then one `delete!` of the trash dir and the compat dir `Roots.item(Compat(<compat id>))` (no compat dir when `compat_of` is `Err`). R-CC10: no age rule, the user named it. R-RR3, R-RM2: a `link-*` entry is only the dir in `toolchains/`, so the dir goes and the target of the link is never touched. | R-CC10, R-RR3, R-RM2, R-GC3 |
## | 7 | The compiler was the default (`Pin.same_id` of `default_roc` and the id): `Manage.next_default` (`installed` without the id, the switch, `Compiler.times`). `Fx.with_lock!` on the `config.toml` item with `Wait`: `read_files!`, `Manage.default_set` or `Manage.default_unset` for `Err(None)`, a second `read_files!` and `write_atomic!` as in `default` step 5. | R-RR1, R-CC6, R-CC7 |
## | 8 | The output: `Manage.remove_report` on stdout (with `--json` on stderr, stdout is only the envelope with `Manage.remove_data`). | R-RR2, R-OUT2, R-J3 |
##
## `roc update` (slice 026, R-CS3, R-RU1 to R-RU4). It has no flag of its own and takes no operand. The calls, in order (the L2 case `roc/up1-update` and the L3 case `compilers/ru1-update` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `ManageUpdate.read_update(args)`. A failure is printed with `Common.failed!` (no `Fx` call). | R-CM15 |
## | 2 | `env_all!`, `Roots.from_env`, `RocInstall.read_config!` (one `read_files!` of `config.toml`): `default-roc` is the default before the command. | R-RU2 |
## | 3 | `RocInstall.offer!` with the text `@latest` (the steps 2 to 6 of `roc install`: the list, and `Nightlies.pick` over the compilers that the `nightly` switch and `min-release-age` allow). `Present`: the newest compiler is installed already, so nothing is downloaded and the first line is `<id> is the newest` (answer Q1 of the review). The default is still decided in step 5. A failure is the failure of `roc install @latest` (exit 10 for the switch, exit 15 for `--offline` with no cached list). | R-RU1, R-NS2, R-NS3, R-C7, R-DI12 |
## | 4 | `Download(offer)`: `RocInstall.ask_download!` (the prompt of `roc install`: interactive, the default is yes; non-interactive: no prompt, the answer line on stderr), then `RocInstall.install_offer!` (lock, download, extract: no default, R-SO15). A No is `Consent.roc_install_declined` (exit 13). | R-NI6, R-DL3, R-DL4, R-CC4 |
## | 5 | The default (a user act, R-SO15). The default text is the id already: `Same`, no call, `changed` is false. Else `Manage.update_move({ default: <step 2> })`: `Stay` makes no call. `Move` (also when no default is set): under the lock of `config.toml` (`Wait`), `Manage.default_set` as `roc default` does (two reads, `write_atomic!`: R-CC6, R-CC7). | R-RU2, R-SO15 |
## | 6 | The output: `ManageUpdate.update_report` (stdout, and the compat warnings on stderr), or with `--json` the envelope with `ManageUpdate.update_data` on stdout and the human text on stderr. No project file is read or written, and no known project is recorded (R-RU3). | R-OUT2, R-J3, R-RU3 |
RocManage :: [].{

	## Steps 1 to 5 of `roc list`.
	list! : Fx, Args => I32
	list! = |fx, args| match Manage.read_list(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok({}) => match list_flow!(fx, args) {
			Ok({}) => 0
			Err(fail) => Common.failed!(fx, args, fail)
		}
	}

	## Steps 1 to 6 of `roc default`.
	default! : Fx, Args => I32
	default! = |fx, args| match Manage.read({ args, verb: Default }) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(text) => match default_flow!(fx, args, text) {
			Ok(done) => {
				print_default!(fx, args, done)
				0
			}
			Err(fail) => Common.failed!(fx, args, fail)
		}
	}

	## Steps 1 to 8 of `roc remove`.
	remove! : Fx, Args => I32
	remove! = |fx, args| match Manage.read({ args, verb: Remove }) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(text) => match remove_flow!(fx, text) {
			Ok(done) => {
				print_remove!(fx, args, done)
				0
			}
			Err(fail) => Common.failed!(fx, args, fail)
		}
	}

	## Slice 045 (R-R5): `tln roc default --git <owner/repo@ref>` picked the installed id `run.id`. This sets the default as `roc default <id>` does: the edit of `config.toml` (`Manage.default_set`) and the text of `print_default!` for an id that is installed.
	set_default! : Fx, Args, { roots : Roots, id : Str } => I32
	set_default! = |fx, args, run| {
		path = Roots.item(run.roots, Config)
		match edit_config!(fx, path, |current| Manage.default_set({ path, text: current, id: run.id })) {
			Ok(edited) => {
				print_default!(fx, args, { id: run.id, installed: Bool.False, compat: Err(Unknown), edited })
				0
			}
			Err(fail) => Common.failed!(fx, args, fail)
		}
	}

	## `tln roc update` (`up`, slice 026, R-CS3, R-RU1 to R-RU4). The calls are in the table at the top of this file. The body is the work of the code agent.
	update! : Fx, Args => I32
	update! = |fx, args| match ManageUpdate.read_update(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok({}) => match update_flow!(fx, args) {
			Ok(done) => {
				print_update!(fx, args, done)
				0
			}
			Err(fail) => Common.failed!(fx, args, fail)
		}
	}
}

# What the edit of `config.toml` gives: the old default, and whether a write happened.
Edited : { previous : Try(Str, [Unset]), changed : Bool }

# Steps 2 to 5 of `roc list`, and the output.
list_flow! : Fx, Args => Try({}, Fail)
list_flow! = |fx, args| {
	roots = Roots.from_env(fx.env_all!())?
	config = RocInstall.read_config!(fx, roots)?
	ids = Launch.toolchains!(fx, roots)
	paths = ids.join_map(|id| [Roots.item(roots, ToolchainMeta(id)), Roots.item(roots, ToolchainLastUse(id))])
	reads = if ids.is_empty() [] else fx.read_files!(paths)
	found = Manage.found_of(ids, reads)
	facts = { rows: Manage.rows({ found, default: config.default_roc }), origins: Manage.origins(found), default: config.default_roc }
	report = Manage.ls_report(facts)
	if args.json {
		fx.out!(Out.json_ok({ command: args.typed, data: Manage.ls_data(facts) }))
	} else {
		for line in report.stdout {
			fx.out!(line)
		}
	}
	for line in report.stderr {
		fx.err!(line)
	}
	Ok({})
}

# What `default!` prints: the id, the 2 flags of `Manage.default_data`, the compat lines of a download.
Defaulted : { id : Str, installed : Bool, compat : Try(Str, [Unknown, Several(List(Str))]), edited : Edited }

# Steps 2 to 5 of `roc default`.
default_flow! : Fx, Args, Str => Try(Defaulted, Fail)
default_flow! = |fx, args, text| {
	env = fx.env_all!()
	roots = Roots.from_env(env)?
	installed = Launch.toolchains!(fx, roots)
	got = fetched!(fx, args, { env, installed, text })?
	path = Roots.item(roots, Config)
	# R-SO24: an install that set the default made the edit already. The output keeps `Set`.
	edited = if got.defaulted {
		{ previous: Err(Unset), changed: Bool.True }
	} else {
		edit_config!(fx, path, |current| Manage.default_set({ path, text: current, id: got.id }))?
	}
	Ok({ id: got.id, installed: got.installed, compat: got.compat, edited })
}

# What a fetch gives. `defaulted` is true when the install set `default-roc` (R-SO24: under the lock of the item, before the rename).
Fetched : { id : Str, installed : Bool, compat : Try(Str, [Unknown, Several(List(Str))]), defaulted : Bool }

# Steps 3 and 4: an installed compiler (a unique prefix is expanded), else the download of `roc install`.
fetched! : Fx, Args, { env : List((Str, Str)), installed : List(Str), text : Str } => Try(Fetched, Fail)
fetched! = |fx, args, facts| {
	present = |id| Ok({ id, installed: Bool.False, compat: Err(Unknown), defaulted: Bool.False })
	if facts.text.starts_with("@") {
		download!(fx, args, facts)
	} else {
		match Nightlies.pick({ text: facts.text, named: facts.installed, auto: facts.installed, base: Err(None) }) {
			Ok(id) => present(id)
			Err(NoMatch(_)) => download!(fx, args, facts)
			Err(error) => Err(Nightlies.failure(error))
		}
	}
}

# Step 4: `roc install` for the text. The consent comes before the lock.
download! : Fx, Args, { env : List((Str, Str)), text : Str, installed : List(Str) } => Try(Fetched, Fail)
download! = |fx, args, facts| match RocInstall.offer!(fx, { id: facts.text, env: facts.env, offline: args.offline })? {
	Present(found) => Ok({ id: found.id, installed: Bool.False, compat: Err(Unknown), defaulted: Bool.False })
	Download(offer) => {
		RocInstall.print_note!(fx, args.quiet, offer.note)
		RocInstall.ask_download!(fx, args, facts.env, { id: offer.id, size: offer.size })?
		done = RocInstall.install_offer!(fx, offer)?
		Ok({ id: done.id, installed: done.how == Installed, compat: done.compat, defaulted: done.default == Set })
	}
}

# Step 5, R-CC6, R-CC7: the edit of `config.toml` under its lock. `decide` makes the edit from the text. When it gives `Set`, the file is read again, and
# `decide` runs again on new bytes before the write.
edit_config! : Fx, Str, (Str -> Try({ previous : Try(Str, [Unset]), edit : [Same, Set(Str)] }, Fail)) => Try(Edited, Fail)
edit_config! = |fx, path, decide| fx.locked!(path, || write_config!(fx, path, decide))

write_config! : Fx, Str, (Str -> Try({ previous : Try(Str, [Unset]), edit : [Same, Set(Str)] }, Fail)) => Try(Edited, Fail)
write_config! = |fx, path, decide| {
	first = RocInstall.read_text!(fx, path)?
	done = decide(first)?
	match done.edit {
		Same => Ok({ previous: done.previous, changed: Bool.False })
		Set(_) => {
			second = RocInstall.read_text!(fx, path)?
			last = if second == first done else decide(second)?
			match last.edit {
				Same => Ok({ previous: last.previous, changed: Bool.False })
				Set(content) => match fx.write_atomic!([{ path, content }]) {
					Ok(_) => Ok({ previous: last.previous, changed: Bool.True })
					Err({ path: failed, err }) => Err(Fail.new(Environment, "cannot write ${failed}: ${Str.inspect(err)}"))
				}
			}
		}
	}
}

# What `update!` prints: the compiler, what the default did, and the facts of `ManageUpdate.update_data`.
Updated : { id : Str, item : Str, installed : Bool, compat : Try(Str, [Unknown, Several(List(Str))]), default : [Set, Moved(Str), Stay(Str), Same], previous : Try(Str, [Unset]), changed : Bool }

# Steps 2 to 5 of `roc update`.
update_flow! : Fx, Args => Try(Updated, Fail)
update_flow! = |fx, args| {
	env = fx.env_all!()
	roots = Roots.from_env(env)?
	before = RocInstall.read_config!(fx, roots)?.default_roc
	got = download!(fx, args, { env, text: "@latest", installed: [] })?
	moved = if got.defaulted {
		{ default: Set, previous: Err(Unset), changed: Bool.True }
	} else {
		moved_default!(fx, roots, { id: got.id, before })?
	}
	Ok({ id: got.id, item: Roots.item(roots, Toolchain(got.id)), installed: got.installed, compat: got.compat, default: moved.default, previous: moved.previous, changed: moved.changed })
}

# Step 5, R-RU2: the default is the id already (no lock), a local build (stays), or moves under the lock of `config.toml`.
moved_default! : Fx, Roots, { id : Str, before : Try(Str, [Unset]) } => Try({ default : [Set, Moved(Str), Stay(Str), Same], previous : Try(Str, [Unset]), changed : Bool }, Fail)
moved_default! = |fx, roots, facts| match facts.before {
	Ok(current) if current == facts.id => Ok({ default: Same, previous: facts.before, changed: Bool.False })
	Ok(current) if Manage.update_move({ default: facts.before }) == Stay => Ok({ default: Stay(current), previous: facts.before, changed: Bool.False })
	_ => {
		path = Roots.item(roots, Config)
		edited = edit_config!(fx, path, |text| Manage.default_set({ path, text, id: facts.id }))?
		default : [Set, Moved(Str), Stay(Str), Same]
		default = match (edited.changed, edited.previous) {
			(Bool.False, _) => Same
			(Bool.True, Ok(old)) => Moved(old)
			(Bool.True, Err(Unset)) => Set
		}
		Ok({ default, previous: edited.previous, changed: edited.changed })
	}
}

# Step 6: the text of `roc update`, or the envelope.
print_update! : Fx, Args, Updated => {}
print_update! = |fx, args, done| {
	shown = Common.shown_fx(fx, args)
	lines = ManageUpdate.update_report({ id: done.id, installed: done.installed, default: done.default, compat: done.compat })
	for line in lines.stdout {
		shown.out!(line)
	}
	for line in lines.stderr {
		fx.err!(line)
	}
	if args.json {
		fx.out!(Out.json_ok({ command: args.typed, data: ManageUpdate.update_data({ id: done.id, item: done.item, installed: done.installed, previous: done.previous, changed: done.changed }) }))
	}
}

# Step 6: the text of `roc default`.
print_default! : Fx, Args, Defaulted => {}
print_default! = |fx, args, done| {
	shown = Common.shown_fx(fx, args)
	edit : [Same, Set]
	edit = if done.edited.changed Set else Same
	for line in Manage.default_report({ id: done.id, installed: done.installed, edit }) {
		shown.out!(line)
	}
	if done.installed {
		for line in Toolchain.report({ id: done.id, how: Installed, default: Kept, compat: done.compat }).stderr {
			fx.err!(line)
		}
	}
	if args.json {
		fx.out!(Out.json_ok({ command: args.typed, data: Manage.default_data({ id: done.id, previous: done.edited.previous, edit, installed: done.installed }) }))
	}
}

# What `remove!` prints.
Removed : { id : Str, item : Str, was_default : Bool, default : Try(Str, [None]), projects : List(Str) }

# Steps 2 to 7 of `roc remove`.
remove_flow! : Fx, Str => Try(Removed, Fail)
remove_flow! = |fx, text| {
	env = fx.env_all!()
	roots = Roots.from_env(env)?
	config = RocInstall.read_config!(fx, roots)?
	switch = Pin.switch({ env: Common.nightly_of(env), toml: Err(Unset), config: config.nightly })
	installed = Launch.toolchains!(fx, roots)
	id = Nightlies.pick({ text, named: installed, auto: installed, base: Err(None) }).map_err(|error| Nightlies.failure(error))?
	projects = pinned!(fx, roots, id)?
	metas = fx.read_files!(installed.map(|each| Roots.item(roots, ToolchainMeta(each))))
	rows = installed.map2(metas, |each, meta| { id: each, text: meta })
	own = rows.find_first(|row| row.id == id)
	compat = match own {
		Ok(row) => Manage.compat_of(row.text)
		Err(_) => Err(None)
	}
	item = Roots.item(roots, Toolchain(id))
	trash!(fx, roots, { id, item, compat })?
	was_default = match config.default_roc {
		Ok(default) => Pin.same_id(default, id)
		Err(Unset) => Bool.False
	}
	next = if was_default {
		Manage.next_default({ installed: installed.keep_if(|each| each != id), removed: id, nightly: switch.nightly, times: Compiler.times(rows) })
	} else {
		Err(None)
	}
	if was_default {
		move_default!(fx, roots, next)?
		# R-RR1: a note when the switch rejects the new default.
		match next {
			Ok(moved_to) => match Manage.move_note({ next: moved_to, nightly: switch.nightly }) {
				Ok(note) => fx.err!("note: ${note}\n")
				Err(None) => {}
			}
			Err(None) => {}
		}
	}
	after = if was_default next else config.default_roc.map_err(|Unset| None)
	Ok({ id, item, was_default, default: after, projects })
}

# Step 4, R-RR2: `projects.json` (a missing file has no project), then the project files in one call.
pinned! : Fx, Roots, Str => Try(List(Str), Fail)
pinned! = |fx, roots, id| {
	entries = Known.entries!(fx, roots)?
	if entries.is_empty() {
		Ok([])
	} else {
		reads = fx.read_files!(entries.map(|entry| entry.path))
		Ok(Manage.pinned_by({ id, projects: entries.map2(reads, |entry, read| { path: entry.path, text: read }) }))
	}
}

# Step 6, R-CC10, R-RR3, R-RM2: under the lock of the item, the dir is renamed to the trash name, then the trash dir and the compat dir are deleted.
# A `link-*` dir holds no target: the dir goes, the target stays. A failed delete is ignored: the trash dir is stale and GC removes it (R-CC2).
trash! : Fx, Roots, { id : Str, item : Str, compat : Try(Str, [None]) } => Try({}, Fail)
trash! = |fx, roots, facts| fx.locked!(facts.item, || Trash.move!(fx, roots, { item: facts.item, compat: facts.compat }))

# Step 7, R-RR1: the default goes to the next compiler, or is unset.
move_default! : Fx, Roots, Try(Str, [None]) => Try({}, Fail)
move_default! = |fx, roots, next| {
	path = Roots.item(roots, Config)
	decide = |current| match next {
		Ok(id) => Manage.default_set({ path, text: current, id })
		Err(None) => Manage.default_unset({ path, text: current }).map_ok(|edit| { previous: Err(Unset), edit })
	}
	_ = edit_config!(fx, path, decide)?
	Ok({})
}

# Step 8: the text of `roc remove`.
print_remove! : Fx, Args, Removed => {}
print_remove! = |fx, args, done| {
	shown = Common.shown_fx(fx, args)
	for line in Manage.remove_report({ id: done.id, was_default: done.was_default, next: done.default, projects: done.projects }) {
		shown.out!(line)
	}
	if args.json {
		fx.out!(Out.json_ok({ command: args.typed, data: Manage.remove_data(done) }))
	}
}
