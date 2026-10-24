import Args
import Clock
import Consent
import Download
import Fail
import Fx
import Install
import Intent
import Item
import Mode
import Net
import Nightlies
import Out
import Pin
import Prompt
import Roots
import Temp
import Text
import Toolchain

## The command `tln roc install <id>` (also `tln roc i`, `tln roc add`: R-CM15, R-CM19, R-R8; slice 021). Direct style over `Fx` (TESTING.md 2.2 part C): `Toolchain` and `Nightlies` decide,
## this module orders the calls. `Run.run!` calls it for the command `["roc", "install"]`. The body is the work of the code agent. The calls, in order (the L2 case `roc/ri1-flow`
## and the L3 cases `compilers/ri1-install-flow`, `ri2-refusals` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `Toolchain.read(args)`. A failure is printed with `Install.failed!` (no `Fx` call). | R-CM15 |
## | 2 | `env_all!`, `Roots.from_env`, `Net.from_env`, `TALON_NOW` (`Clock.now`, one `clock!` call), `platform!`, `Toolchain.host`. `config.toml` is read with one `read_files!` call: `Intent.read_config` gives `min-release-age` (R-C7, default 2 days) and `nightly` (R-NS10). Slice 022: the switch is `Pin.switch` with `TALON_NIGHTLY` (`Install.nightly_of`, R-NS8), no `talon.toml` (R-PD16: no project), and the `nightly` of `config.toml`. | R-EV13, R-EV22, R-CV8, R-C7, R-NS3 |
## | 3 | One `list_dirs!` of `<cache>/toolchains` (a missing dir is empty). The text is an installed dir name (a full id): go to step 12 with `Present`, with no request. | R-CC4 step 1 |
## | 4 | `Nightlies.list!` (one fetch, the cache of R-DI2). `source` is `Missing`: `Toolchain.offline_no_list`. `Toolchain.domain` (with the switch: slice 022, R-NS3), then `Nightlies.pick` with `base: Err(None)` (relative steps need the selection of slice 022). A `PickError` is `Toolchain.pick_failed` (with the switch: `Empty` names it, slice 022, R-NS2; `Nightlies.failure`, and the host in the text for the exact id of a nightly with no asset). | R-SC10, R-SL5, R-NS4, R-C7 |
## | 5 | The picked id is in the listing of step 3: `Present`. | R-CC4 step 1 |
## | 6 | `Toolchain.require_digest` (the asset has a digest, else exit 16, before any download). `--offline`: `Toolchain.offline_missing`. | R-CV4, R-DI12 |
## | 7 | `Prompt.ask!(Consent.roc_install)` with the mode of `Mode.from_env`, `args.yes`, `args.quiet` and no flag. `No`: `Consent.roc_install_declined`. Before the lock (R-CC3 point 5). | R-NI6, R-DL1, R-DL3, R-DL4 |
## | 8 | `Fx.with_lock!` on `Toolchain.Plan.item` with `Wait` (the line `waiting for another tln: <id>` comes from it). Steps 9 to 11 run inside. | R-CC3, R-CC4 step 3, R-CC5 |
## | 9 | One `list_dirs!` of `<cache>/toolchains`. The id is a dir now: `Present`, no more calls. Else `Temp.of_item` gives the stale temps, and one `delete!` removes them (no call when there are none). | R-CC4 steps 4, 5 |
## | 10 | One `random!`. `programs!(["curl", "wget"])` and `Download.choose` (the downloader of `Net.Settings`). `make_dirs!([temp])`. One `spawn_all!` (limit 8): `Download.command` with `dest: archive`, `cwd: Err(Inherit)`. A failure: `Toolchain.download_failed`. | R-DA2, R-DA3, R-DA4, R-HF4 |
## | 11 | `sha256_file!(archive)`, `Toolchain.check_download`. A failure deletes the temp dir. Then one `spawn_all!` (limit 1): `Toolchain.tar_command`, `cwd: Err(Inherit)`. Then `delete!([archive])`. Then one `spawn_all!` with `Toolchain.chmod_command` (no call for `Err(NotNeeded)`). Then the compat check: `list_dirs!([Roots.build])`, `write_atomic!([probe_file ""])`, one `spawn_all!` of `<roc> check <probe_file>` with `cwd: Ok(probe_dir)` (the exit code is not read), `list_dirs!([Roots.build])`, `delete!([probe_dir])`, `Toolchain.learn_compat`. Then `write_atomic!([meta])` (last, with the `published_at` of the picked release: slice 022, Q5), then `rename!({ from: temp, to: item })`. `Err(Exists)` is `Installed` (the other process won, drop the temp, as R-FE3). Each failure after step 10 deletes the temp dir and the probe dir. | R-CV4, R-HF2, R-HF5, R-SE9, R-GC10, R-CV5, R-CC4 step 6 |
## | 12 | The unlock is done by `with_lock!` (R-CC4 step 7). Then the default (R-SO15, only for `Installed`, question Q4): `Fx.with_lock!` on the item `Roots.item(Config)` with `Wait`: `read_files!([config])` (a missing file is the empty text), `Toolchain.default_edit`. `Set(text)`: a second `read_files!`, the bytes must be the first bytes, else `default_edit` runs on the new bytes (R-CC7), then `write_atomic!([config])`. | R-SO15, R-CC6, R-CC7 |
## | 13 | The output: `Toolchain.report`. With `--json`: the human text goes to stderr and stdout is only `Out.json_ok({ command: args.typed, data: Toolchain.data(...) })`. `--quiet` hides the stdout lines (R-FL4, as `Install.shown_fx`). | R-J1 to R-J4, R-FL4 |
##
## The exit code is `Exit.choose` of the failure, as in `Install.run!`. A failure writes no file in the toolchains dir: no `<id>` dir, no temp, no download (R-CC2).
RocInstall :: [].{

	run! : Fx, Args => I32
	run! = |fx, args| match Toolchain.read(args) {
		Err(fail) => Install.failed!(fx, args, fail)
		Ok(typed) => match flow!(fx, args, typed) {
			Ok(done) => {
				print!(fx, Install.shown_fx(fx, args), args, done)
				0
			}
			Err(fail) => Install.failed!(fx, args, fail)
		}
	}
}

Compat : Try(Str, [Unknown, Several(List(Str))])

Entries : List({ name : Str, is_dir : Bool, mtime : U64 })

# The result of a run. `how` and `default` are the words of `Toolchain.report`.
Done : { id : Str, item : Str, how : [Installed, Present], default : [Set, Kept], compat : Compat }

# What the steps after the pick need.
Ctx : { roots : Roots, net : Net.Settings, now : U64, published_at : U64, typed : Str, id : Str, item : Str, asset : Nightlies.Asset, sha : Str, system : Nightlies.Host }

# Steps 2 to 8 and 12.
flow! : Fx, Args, Str => Try(Done, Fail)
flow! = |fx, args, typed| {
	env = fx.env_all!()
	roots = Roots.from_env(env)?
	real = fx.clock!()
	now = match Clock.now({ talon_now: env_var(env, "TALON_NOW"), real }) {
		Ok(t) => t
		Err(BadTime(text)) => return Err(Fail.new(Usage, "TALON_NOW is not a UTC time: ${text}"))
	}
	system = Toolchain.host(fx.platform!())?
	config = read_config!(fx, roots)?
	min_age = config.min_release_age ?? 172800
	switch = Pin.switch({ env: Install.nightly_of(env), toml: Err(Unset), config: config.nightly })
	dir = Text.join(roots.cache, "toolchains")
	entries = toolchain_entries!(fx, dir)
	if has_dir(entries, typed) return Ok(present(roots, typed))
	found = Nightlies.list!(fx, { net: Net.from_env(env), roots, now: real, offline: args.offline, host: system })?
	if found.source == Missing return Err(Toolchain.offline_no_list({}))
	lists = Toolchain.domain({ releases: found.releases, now, min_age, nightly: switch.nightly })
	id = match Nightlies.pick({ text: typed, named: lists.named, auto: lists.auto, base: Err(None) }) {
		Ok(picked) => picked
		Err(error) => return Err(Toolchain.pick_failed({ error, releases: found.releases, host: system, switch }))
	}
	if has_dir(entries, id) return Ok(present(roots, id))
	asset = asset_of(found.releases, id)?
	sha = Toolchain.require_digest({ id, asset })?
	if args.offline return Err(Toolchain.offline_missing(id))
	ask_download!(fx, args, env, { id, size: asset.size })?
	item = Roots.item(roots, Item.Toolchain(id))
	ctx = { roots, net: Net.from_env(env), now, published_at: published_of(found.releases, id), typed, id, item, asset, sha, system }
	locked = match fx.with_lock!(item, Wait, || install!(fx, ctx, dir)) {
		Ok(result) => result
		Err(Failed(fail)) => return Err(fail)
		Err(Busy) => return Err(Fail.new(Internal, "the lock of ${item} was not taken"))
	}
	default = match locked.how {
		Installed => set_default!(fx, roots, id)?
		Present => Kept
	}
	Ok({ id, item, how: locked.how, default, compat: locked.compat })
}

env_var : List((Str, Str)), Str -> Try(Str, [NotSet])
env_var = |env, name| match env.find_first(|(key, _)| key == name) {
	Ok((_, value)) => Ok(value)
	Err(_) => Err(NotSet)
}

present : Roots, Str -> Done
present = |roots, id| { id, item: Roots.item(roots, Item.Toolchain(id)), how: Present, default: Kept, compat: Err(Unknown) }

# One text of a file. A missing file is the empty text.
read_text! : Fx, Str => Try(Str, Fail)
read_text! = |fx, path| match fx.read_files!([path]) {
	[Ok(text)] => Ok(text)
	[Err(NotFound)] => Ok("")
	other => Err(Fail.new(Environment, "cannot read ${path}: ${Str.inspect(other)}"))
}

# Step 2, R-C7, R-NS10: `config.toml`. `min-release-age` is 2 days when it is not set.
read_config! : Fx, Roots => Try(Intent.Config, Fail)
read_config! = |fx, roots| {
	path = Roots.item(roots, Item.Config)
	read = Intent.read_config({ path, text: read_text!(fx, path)? })?
	for w in read.warnings {
		fx.err!("warning: ${w}\n")
	}
	Ok(read.config)
}

toolchain_entries! : Fx, Str => Entries
toolchain_entries! = |fx, dir| match fx.list_dirs!([dir]) {
	[Ok(entries)] => entries
	_ => []
}

has_dir : Entries, Str -> Bool
has_dir = |entries, name| entries.any(|e| e.is_dir and e.name == name)

asset_of : List(Nightlies.Release), Str -> Try(Nightlies.Asset, Fail)
asset_of = |releases, id| match releases.find_first(|r| r.id == id) {
	Ok(release) => release.asset.map_err(|_| Fail.new(Internal, "${id} has no asset for this host"))
	Err(NotFound) => Err(Fail.new(Internal, "${id} is not in the list"))
}

# Q5 of slice 022: the GitHub `published_at` of the picked release, for `.talon.json`.
published_of : List(Nightlies.Release), Str -> U64
published_of = |releases, id| match releases.find_first(|r| r.id == id) {
	Ok(release) => release.published_at
	Err(NotFound) => 0
}

# Step 7, R-NI6: the person (or the flags) agrees to the download. It runs before the lock (R-CC3 point 5).
ask_download! : Fx, Args, List((Str, Str)), { id : Str, size : U64 } => Try({}, Fail)
ask_download! = |fx, args, env, facts| {
	mode = Mode.from_env({ env: Dict.from_list(env), json: args.json })
	asked = Prompt.ask!(fx, Consent.roc_install(facts), { mode, yes: args.yes, quiet: args.quiet, flag: Err(NoFlag) })?
	if asked.answer == Yes Ok({}) else Err(Consent.roc_install_declined(facts.id))
}

# Steps 9 to 11, inside the lock of the item.
install! : Fx, Ctx, Str => Try({ how : [Installed, Present], compat : Compat }, Fail)
install! = |fx, ctx, dir| {
	entries = toolchain_entries!(fx, dir)
	if has_dir(entries, ctx.id) return Ok({ how: Present, compat: Err(Unknown) })
	stale = Temp.of_item({ item: ctx.item, entries })
	if !stale.is_empty() {
		_ = fx.delete!(stale)
	}
	p = Toolchain.plan({ roots: ctx.roots, host: ctx.system, id: ctx.id, asset: ctx.asset.name, hex: Temp.hex(fx.random!()) })
	found = match fx.programs!(["curl", "wget"]) {
		[curl, wget] => { curl, wget }
		_ => { curl: Bool.False, wget: Bool.False }
	}
	program = Download.choose({ want: ctx.net.downloader, curl: found.curl, wget: found.wget })?
	match fx.make_dirs!([p.temp]) {
		Ok(_) => {}
		Err(err) => return Err(Fail.new(Environment, "cannot make ${p.temp}: ${Str.inspect(err)}"))
	}
	match build!(fx, ctx, p, program) {
		Err(fail) => {
			_ = fx.delete!([p.temp, p.probe_dir])
			Err(fail)
		}
		Ok(compat) => match fx.rename!({ from: p.temp, to: ctx.item }) {
			Ok(_) => Ok({ how: Installed, compat })
			Err(Exists) => {
				_ = fx.delete!([p.temp])
				Ok({ how: Installed, compat })
			}
			Err(err) => {
				_ = fx.delete!([p.temp, p.probe_dir])
				Err(Fail.new(Environment, "cannot move ${p.temp} to ${ctx.item}: ${Str.inspect(err)}"))
			}
		}
	}
}

# Step 11: download, check, extract, chmod, compat id, `.talon.json` last.
build! : Fx, Ctx, Toolchain.Plan, Download.Program => Try(Compat, Fail)
build! = |fx, ctx, p, program| {
	download!(fx, ctx, p, program)?
	got = match fx.sha256_file!(p.archive) {
		Ok(digits) => digits
		Err(err) => return Err(Fail.new(Environment, "cannot read ${p.archive}: ${Str.inspect(err)}"))
	}
	Toolchain.check_download({ id: ctx.id, want: ctx.sha, got })?
	extract!(fx, ctx, p)?
	set_executable!(fx, ctx, p)?
	compat = learn_compat!(fx, ctx, p)?
	meta = Toolchain.meta({ id: ctx.id, url: ctx.asset.url, sha256: ctx.sha, typed: ctx.typed, compat, now: ctx.now, published_at: ctx.published_at })
	match fx.write_atomic!([{ path: p.meta, content: meta }]) {
		Ok(_) => Ok(compat)
		Err({ path, err }) => Err(Fail.new(Environment, "cannot write ${path}: ${Str.inspect(err)}"))
	}
}

# One child process. The result is `NotStarted` when the call gives none.
spawn_one! : Fx, { argv : List(Str), cwd : Try(Str, [Inherit]) }, U64 => { ended : Download.Ended, stdout : Str, stderr_last : Str }
spawn_one! = |fx, job, limit| match fx.spawn_all!({ jobs: [job], limit }) {
	[done] => done
	_ => { ended: NotStarted("no result"), stdout: "", stderr_last: "" }
}

download! : Fx, Ctx, Toolchain.Plan, Download.Program => Try({}, Fail)
download! = |fx, ctx, p, program| {
	done = spawn_one!(fx, { argv: Download.command({ program, url: ctx.asset.url, dest: p.archive }), cwd: Err(Inherit) }, 8)
	failed = |outcome| Toolchain.download_failed({ id: ctx.id, url: ctx.asset.url, program, ended: done.ended, outcome, last_line: done.stderr_last })
	match Download.outcome({ program, ended: done.ended, last_line: done.stderr_last }) {
		Done => Ok({})
		Http(status) => Err(failed(Http(status)))
		Failed => Err(failed(Failed))
	}
}

# R-HF5: `tar` runs, then the archive is deleted.
extract! : Fx, Ctx, Toolchain.Plan => Try({}, Fail)
extract! = |fx, ctx, p| {
	done = spawn_one!(fx, { argv: Toolchain.tar_command({ archive: p.archive, dir: p.temp }), cwd: Err(Inherit) }, 1)
	match done.ended {
		Exited(0) => {
			_ = fx.delete!([p.archive])
			Ok({})
		}
		ended => Err(Toolchain.tar_failed({ id: ctx.id, url: ctx.asset.url, ended, last_line: done.stderr_last }))
	}
}

# R-HF2
set_executable! : Fx, Ctx, Toolchain.Plan => Try({}, Fail)
set_executable! = |fx, ctx, p| match Toolchain.chmod_command({ host: ctx.system, file: p.roc }) {
	Err(NotNeeded) => Ok({})
	Ok(argv) => match spawn_one!(fx, { argv, cwd: Err(Inherit) }, 1).ended {
		Exited(0) => Ok({})
		ended => Err(Fail.new(Environment, "cannot set the executable bit of ${p.roc}: ${Str.inspect(ended)}"))
	}
}

# R-GC10: `roc check` of an empty file, and the compat dir that it touched. The exit code of `roc check` is not read (D10).
learn_compat! : Fx, Ctx, Toolchain.Plan => Try(Compat, Fail)
learn_compat! = |fx, ctx, p| {
	before = build_entries!(fx, ctx.roots)
	match fx.write_atomic!([{ path: p.probe_file, content: "" }]) {
		Ok(_) => {}
		Err({ path, err }) => return Err(Fail.new(Environment, "cannot write ${path}: ${Str.inspect(err)}"))
	}
	_ = spawn_one!(fx, { argv: [p.roc, "check", p.probe_file], cwd: Ok(p.probe_dir) }, 1)
	after = build_entries!(fx, ctx.roots)
	_ = fx.delete!([p.probe_dir])
	Ok(Toolchain.learn_compat({ before, after }))
}

build_entries! : Fx, Roots => Entries
build_entries! = |fx, roots| toolchain_entries!(fx, roots.build)

# Step 12, R-SO15, R-CC6: the first compiler is the default, under the lock of `config.toml`.
set_default! : Fx, Roots, Str => Try([Set, Kept], Fail)
set_default! = |fx, roots, id| {
	path = Roots.item(roots, Item.Config)
	match fx.with_lock!(path, Wait, || edit_config!(fx, path, id)) {
		Ok(result) => Ok(result)
		Err(Failed(fail)) => Err(fail)
		Err(Busy) => Err(Fail.new(Internal, "the lock of ${path} was not taken"))
	}
}

# R-CC7: the file is read again before the write, and the edit runs again when it changed.
edit_config! : Fx, Str, Str => Try([Set, Kept], Fail)
edit_config! = |fx, path, id| {
	first = read_text!(fx, path)?
	match Toolchain.default_edit({ path, text: first, id })? {
		Keep => Ok(Kept)
		Set(edited) => {
			second = read_text!(fx, path)?
			again = if second == first Ok(Set(edited)) else Toolchain.default_edit({ path, text: second, id })
			match again? {
				Keep => Ok(Kept)
				Set(content) => match fx.write_atomic!([{ path, content }]) {
					Ok(_) => Ok(Set)
					Err({ path: failed, err }) => Err(Fail.new(Environment, "cannot write ${failed}: ${Str.inspect(err)}"))
				}
			}
		}
	}
}

# Step 13: the text, or the envelope. `shown` has the `out!` of `--json` and `--quiet`.
print! : Fx, Fx, Args, Done => {}
print! = |fx, shown, args, done| {
	lines = Toolchain.report({ id: done.id, how: done.how, default: done.default, compat: done.compat })
	for line in lines.stdout {
		shown.out!(line)
	}
	for line in lines.stderr {
		fx.err!(line)
	}
	if args.json {
		fx.out!(Out.json_ok({ command: args.typed, data: Toolchain.data({ id: done.id, item: done.item, how: done.how, default: done.default }) }))
	}
}
