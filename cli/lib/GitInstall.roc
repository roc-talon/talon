import Args
import Clock
import Common
import Download
import Fail
import Fx
import GitBuild
import GitRef
import Github
import Item
import Launch
import Net
import Nightlies
import Out
import RocInstall
import Roots
import Temp
import Text
import Toolchain
import Zig
import ZigInstall

## `tln roc install --git <ref>` and `tln roc install @<sha>` (slice 045, CLI 6.6, R-R1 to R-R3, R-R5 to R-R7, R-R9 to R-R11, R-SE12, R-DA3, R-SO15). Direct style over `Fx`: it calls the pure functions of `GitRef` and
## `GitBuild`, and `Toolchain` for the output. A word that is not a git ref (`GitRef.read` gives `NotGit`) goes to `RocInstall.run!`. The compat check is a copy of `RocInstall` (its probe dir is the scratch dir, which the run deletes at its end: no `delete!` between the check and the `.talon.json`). The contract (the order of the calls is checked by `calls.log` of
## `tests/commands/cases/roc/gi1-install` and `gi2-zig`):
##
## | Step | Rule | What |
## | --- | --- | --- |
## | 1 | R-R11 | `GitRef.read({ args, bare_sha: True })`. `NotGit`: `RocInstall.run!(fx, args)`, no other call. A failure: `Common.failed!`. |
## | 2 | R-EV19 | `env_all!`, `Roots.from_env`, `Net.settings` (`TALON_GITHUB_API`, `--offline`), one `clock!`, `platform!` for the host. |
## | 3 | R-DI12 | `--offline`: `GitRef.offline_failure`, no request. |
## | 4 | R-R1, R-R3 | one `http_get!` of `GitRef.commit_url` with `GitRef.commit_headers({ token })`, `GitRef.commit_of`. The token is resolved as `Github.releases!` does (review Q1): `Net.token` of `net.token` and, for `AskGh`, one `programs!(["gh"])` before the request (and `gh auth token` when `gh` is there). The id is `GitRef.sha_id`. |
## | 5 | R-SE12 | `list_dirs!` of the toolchains: the id is there: report as already installed (`Toolchain.report`), exit 0, no download. |
## | 6 | R-DA3 | `programs!(["curl", "wget"])`, `Download.choose`. Wget: `GitRef.needs_curl`, exit 18. |
## | 7 | R-R2 | best effort `Nightlies.list!`, `GitRef.nightly_note`: the note is on stderr with no prompt. A failed list gives no note. |
## | 8 | R-D4 | `GitRef.header_line`, a blank line, to stderr (hidden by `--quiet`). |
## | 9 | R-R3, R-R7 | scratch dir, curl job to the archive (limit 8) with the full sha, `sha256_file!`, tar job (limit 1), delete the archive. |
## | 10 | R-D1 to R-D4 | `Zig.minimum` of `build.zig.zon`, `ZigInstall.ensure!` (may ask before the lock). |
## | 10b | R-CC9 | `Launch.touch!` of a Zig of Talon (061), before the lock. |
## | 11 | R-SE12 | `locked!`: check again, `zig build` (`GitBuild.build_command`), move the binary, compat check, `.talon.json` (`GitBuild.meta`), rename to the id. |
## | 12 | R-SO15 | a user act: the default is set when none is set, also for `Present` (`RocInstall.first_default!`). |
## | 13 | R-R6 | delete the scratch dir (and the temp dir after a failure). |
GitInstall :: [].{

	run! : Fx, Args => I32
	run! = |fx, args| match GitRef.read({ args, bare_sha: Bool.True }) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(Err(NotGit)) => RocInstall.run!(fx, args)
		Ok(Ok(source)) => match flow!(fx, args, source) {
			Ok(done) => {
				print!(fx, args, done)
				0
			}
			Err(fail) => Common.failed!(fx, args, fail)
		}
	}
}

Compat : Try(Str, [Unknown, Several(List(Str))])

Entries : List({ name : Str, is_dir : Bool, mtime : U64 })

# The result of a run: the words of `Toolchain.report`.
Done : { id : Str, item : Str, how : [Installed, Present], default : [Set, Kept], compat : Compat }

# What the steps after the commit need. `url` is the archive.
Run : { args : Args, env : List((Str, Str)), roots : Roots, host : Nightlies.Host, now : U64, source : GitRef.Source, sha : Str, id : Str, url : Str, p : GitBuild.Plan }

# Steps 2 to 13.
flow! : Fx, Args, GitRef.Source => Try(Done, Fail)
flow! = |fx, args, source| {
	env = fx.env_all!()
	roots = Roots.from_env(env)?
	net = Net.from_env(env)
	real = fx.clock!()
	now = match Clock.now({ talon_now: env_var(env, "TALON_NOW"), real }) {
		Ok(t) => t
		Err(BadTime(text)) => return Err(Fail.new(Usage, "TALON_NOW is not a UTC time: ${text}"))
	}
	host = Toolchain.host(fx.platform!())?
	if args.offline return Err(GitRef.offline_failure(source))
	sha = commit!(fx, net, source, real)?
	id = GitRef.sha_id(sha)
	if has_dir(toolchain_entries!(fx, Text.join(roots.cache, "toolchains")), id) {
		return Ok({ id, item: Roots.item(roots, Item.Toolchain(id)), how: Present, default: Kept, compat: Err(Unknown) })
	}
	check_curl!(fx, net)?
	note!(fx, args, { net, roots, real, host, sha })
	if !args.quiet {
		fx.err!("${GitRef.header_line({ source, sha })}\n\n")
	}
	p = GitBuild.plan({ roots, host, id, hex: Temp.hex(fx.random!()) })
	run = { args, env, roots, host, now, source, sha, id, url: GitRef.archive_url({ api: net.api, source, sha }), p }
	match build!(fx, run) {
		Ok(done) => {
			_ = fx.delete!([p.scratch])
			Ok(done)
		}
		Err(fail) => {
			_ = fx.delete!([p.temp, p.scratch])
			Err(fail)
		}
	}
}

env_var : List((Str, Str)), Str -> Try(Str, [NotSet])
env_var = |env, name| match env.find_first(|(key, _)| key == name) {
	Ok((_, value)) => Ok(value)
	Err(_) => Err(NotSet)
}

toolchain_entries! : Fx, Str => Entries
toolchain_entries! = |fx, dir| match fx.list_dirs!([dir]) {
	[Ok(entries)] => entries
	_ => []
}

has_dir : Entries, Str -> Bool
has_dir = |entries, name| entries.any(|e| e.is_dir and e.name == name)

# Step 4, R-R1, R-R3: the commit of the ref. The token is resolved before the request, as `Github.releases!` does (review Q1).
commit! : Fx, Net.Settings, GitRef.Source, U64 => Try(Str, Fail)
commit! = |fx, net, source, real| {
	gh = match net.token {
		AskGh => Github.ask_gh!(fx)
		_ => Err(None)
	}
	url = GitRef.commit_url({ api: net.api, source })
	headers = GitRef.commit_headers({ token: Net.token({ plan: net.token, gh }) })
	match fx.http_get!({ url, headers }) {
		Ok(answer) => GitRef.commit_of({ source, url, now: real, status: answer.status, headers: answer.headers, body: answer.body })
		Err(why) => Err(Github.network_failure({ url, why }))
	}
}

# Step 6, R-DA3: only curl refuses a redirect to http (a source archive has no published hash).
check_curl! : Fx, Net.Settings => Try({}, Fail)
check_curl! = |fx, net| {
	found = match fx.programs!(["curl", "wget"]) {
		[curl, wget] => { curl, wget }
		_ => { curl: Bool.False, wget: Bool.False }
	}
	match Download.choose({ want: net.downloader, curl: found.curl, wget: found.wget })? {
		Curl => Ok({})
		Wget => Err(GitRef.needs_curl({}))
	}
}

# Step 7, R-R2: the note is best effort. A failed list gives no note.
note! : Fx, Args, { net : Net.Settings, roots : Roots, real : U64, host : Nightlies.Host, sha : Str } => {}
note! = |fx, args, run| match Nightlies.list!(fx, { net: run.net, roots: run.roots, now: run.real, offline: Bool.False, host: run.host }) {
	Ok(found) => match GitRef.nightly_note({ sha: run.sha, releases: found.releases }) {
		Ok(text) => if !args.quiet fx.err!("${text}\n")
		Err(None) => {}
	}
	Err(_) => {}
}

# Steps 9 to 12: the source, the Zig, the build under the lock, the first default.
build! : Fx, Run => Try(Done, Fail)
build! = |fx, run| {
	p = run.p
	match fx.make_dirs!([p.src]) {
		Ok(_) => {}
		Err(err) => return Err(Fail.new(Environment, "cannot make ${p.src}: ${Str.inspect(err)}"))
	}
	sha256 = fetch!(fx, run)?
	zig = ZigInstall.ensure!(
		fx,
		{
			need: need!(fx, run)?,
			env: run.env,
			yes: run.args.yes,
			quiet: run.args.quiet,
			json: run.args.json,
			offline: run.args.offline,
			llvm: { target: GitRef.llvm_target(run.host), size: Err(Unknown) },
		},
	)?
	mark_zig!(fx, run, zig)
	locked = fx.locked!(p.item, || install!(fx, run, { zig: zig.path, sha256 }))?
	default = RocInstall.first_default!(fx, run.roots, run.id)?
	Ok({ id: run.id, item: p.item, how: locked.how, default, compat: locked.compat })
}

# Step 10b, R-CC9, R-CC10: a Zig of Talon (a dir of `toolchains/`) gets a `.last-use`, so that `tln cache gc` keeps it while this build runs. A Zig from `ZIG` or `PATH` has no dir there.
mark_zig! : Fx, Run, ZigInstall.Done => {}
mark_zig! = |fx, run, zig| match zig.how {
	Found(Env) | Found(Path) => {}
	_ => Launch.touch!(fx, run.roots, { id: "zig-${zig.version}", now: run.now })
}

# Step 9, R-R3, R-R7: curl, the sha256 of the archive, tar into `src`. A failure is the failure of `Toolchain`.
fetch! : Fx, Run => Try(Str, Fail)
fetch! = |fx, run| {
	p = run.p
	done = RocInstall.spawn_one!(fx, { argv: Download.command({ program: Curl, url: run.url, dest: p.archive }), cwd: Err(Inherit) }, 8)
	failed = |outcome| Toolchain.download_failed({ id: run.id, url: run.url, program: Curl, ended: done.ended, outcome, last_line: done.stderr_last })
	match Download.outcome({ program: Curl, ended: done.ended, last_line: done.stderr_last }) {
		Done => {}
		Http(status) => return Err(failed(Http(status)))
		Failed => return Err(failed(Failed))
	}
	sha256 = match fx.sha256_file!(p.archive) {
		Ok(digits) => digits
		Err(err) => return Err(Fail.new(Environment, "cannot read ${p.archive}: ${Str.inspect(err)}"))
	}
	untar = RocInstall.spawn_one!(fx, { argv: Toolchain.tar_command({ archive: p.archive, dir: p.src }), cwd: Err(Inherit) }, 1)
	match untar.ended {
		Exited(0) => {
			_ = fx.delete!([p.archive])
			Ok(sha256)
		}
		ended => Err(Toolchain.tar_failed({ id: run.id, url: run.url, ended, last_line: untar.stderr_last }))
	}
}

# Step 10, R-D4: the Zig version of the commit. No key is a failure (question Q3: the design does not say what to do).
need! : Fx, Run => Try(Str, Fail)
need! = |fx, run| {
	name = GitRef.name_text(run.source)
	match fx.read_files!([run.p.zon]) {
		[Ok(text)] => Zig.minimum(text).map_err(|_| Fail.new(Input, "build.zig.zon of ${name} has no minimum_zig_version"))
		other => Err(Fail.new(Input, "cannot read build.zig.zon of ${name}: ${Str.inspect(other)}"))
	}
}

# Step 11, R-CC4: inside the lock of the item. The dir may be there already (the other process won).
install! : Fx, Run, { zig : Str, sha256 : Str } => Try({ how : [Installed, Present], compat : Compat }, Fail)
install! = |fx, run, made| {
	p = run.p
	entries = toolchain_entries!(fx, Text.join(run.roots.cache, "toolchains"))
	if has_dir(entries, run.id) return Ok({ how: Present, compat: Err(Unknown) })
	stale = Temp.of_item({ item: p.item, entries })
	if !stale.is_empty() {
		_ = fx.delete!(stale)
	}
	match fx.make_dirs!([p.temp]) {
		Ok(_) => {}
		Err(err) => return Err(Fail.new(Environment, "cannot make ${p.temp}: ${Str.inspect(err)}"))
	}
	build_roc!(fx, run, made.zig)?
	compat = learn_compat!(fx, run)?
	meta = GitBuild.meta({ id: run.id, source: run.source, sha: run.sha, sha256: made.sha256, compat, now: run.now })
	match fx.write_atomic!([{ path: p.meta, content: meta }]) {
		Ok(_) => {}
		Err({ path, err }) => return Err(Fail.new(Environment, "cannot write ${path}: ${Str.inspect(err)}"))
	}
	match fx.rename!({ from: p.temp, to: p.item }) {
		Ok(_) => Ok({ how: Installed, compat })
		Err(Exists) => {
			_ = fx.delete!([p.temp])
			Ok({ how: Installed, compat })
		}
		Err(err) => Err(Fail.new(Environment, "cannot move ${p.temp} to ${p.item}: ${Str.inspect(err)}"))
	}
}

# R-R3: `zig build` in the source tree, then the program moves to the temp dir.
build_roc! : Fx, Run, Str => Try({}, Fail)
build_roc! = |fx, run, zig| {
	p = run.p
	done = RocInstall.spawn_one!(fx, { argv: GitBuild.build_command({ zig, id: run.id }), cwd: Ok(p.src) }, 1)
	match done.ended {
		Exited(0) => {}
		ended => return Err(GitBuild.build_failed({ id: run.id, ended, last_line: done.stderr_last }))
	}
	match fx.rename!({ from: p.built, to: p.roc }) {
		Ok(_) => Ok({})
		Err(NotFound) => Err(GitBuild.no_binary(run.id))
		Err(err) => Err(Fail.new(Environment, "cannot move ${p.built} to ${p.roc}: ${Str.inspect(err)}"))
	}
}

# R-GC10: `roc check` of an empty file, and the compat dir that it touched. The scratch dir has the file, and the end of the run deletes it.
learn_compat! : Fx, Run => Try(Compat, Fail)
learn_compat! = |fx, run| {
	p = run.p
	before = toolchain_entries!(fx, run.roots.build)
	match fx.write_atomic!([{ path: p.probe_file, content: "" }]) {
		Ok(_) => {}
		Err({ path, err }) => return Err(Fail.new(Environment, "cannot write ${path}: ${Str.inspect(err)}"))
	}
	_ = RocInstall.spawn_one!(fx, { argv: [p.roc, "check", p.probe_file], cwd: Ok(p.scratch) }, 1)
	after = toolchain_entries!(fx, run.roots.build)
	Ok(Toolchain.learn_compat({ before, after }))
}

# Step 13: the text, or the envelope (as `roc install`).
print! : Fx, Args, Done => {}
print! = |fx, args, done| {
	shown = Common.shown_fx(fx, args)
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
