import Args
import Common
import Download
import Fail
import Fx
import GitRef
import Github
import Net
import Out
import RocInstall
import Temp
import Text
import Toolchain
import ToolBuild
import ToolFlow
import ToolGit
import ToolInstall

## The command `tln tool install --git owner/app@ref [--path <dir>]` and `tln tool install owner/app@<sha>` (slice 048, CLI 6.4: R-T23, R-T26, R-T27, R-T28, R-T2, R-SL8, R-SL10, R-SE12, R-DA3, R-CC6). Direct style over `Fx` (TESTING.md 2.2 part C): `ToolGit` decides, `GitRef` gives the commit requests (slice 045), `ToolBuild`
## builds and installs (the lock of `tools.json`, slice 046). `Run.run!` calls `run!` for the command `["tool", "install"]`: a line that is not a git source (`ToolGit.read` gives `NotGit`) goes to `ToolFlow.run!`, with no other call. `head!`, `check_curl!` and `source!` are also used by `ToolUpdateFlow`.
## The calls, in order (the L2 case `tool/tg1-git` and the L3 case `tools/ti3-tool-git` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `ToolGit.read(args)`. A failure is printed with `Common.failed!` (no `Fx` call). `NotGit`: `ToolFlow.run!(fx, args)`. | R-T23, R-SL10, R-FL12 |
## | 2 | `ToolFlow.gather_for!` (steps 2 to 5 of `ToolFlow`: the environment, the roots, the network settings, one `clock!`, `platform!`, `tools.json`, `config.toml`, the lookup of the name in `tools.json`, the key, the clash). | R-T28, R-SC3, R-LY2 |
## | 3 | `--offline`: `GitRef.offline_failure` (exit 15), no request. | R-DI12 |
## | 4 | One `http_get!` of `GitRef.commit_url` with `GitRef.commit_headers({ token })`, `GitRef.commit_of`. The token is resolved as in `GitInstall` (`Net.token`, and for `AskGh` one `programs!(["gh"])` before the request). | R-T23, R-R3, R-RG3 |
## | 5 | `ToolGit.reuse`: `Keep` ends the command (no build): the answer `Present`. | R-T26 |
## | 6 | `ToolBuild.entry_verdict!` (the check of the bin dir entry before the download, as `ToolFlow` step 7b). | R-ST6, R-ST11 |
## | 7 | `check_curl!`: `programs!(["curl", "wget"])`, `Download.choose`. Wget: `ToolGit.needs_curl` (exit 18). | R-DA3, R-SE12 |
## | 8 | `source!`: `random!` (the hex of the temp dir), `ToolGit.layout`, `make_dirs!` of `src`, the curl job to the archive (`GitRef.archive_url`, limit 8), the tar job (`Toolchain.tar_command`, limit 1), `delete!` of the archive, one `read_files!` of `<dir>/main.roc`, `Release.read` (an app), `Locked.read`. | R-T23, R-R3, R-R7, R-SE12 |
## | 9 | `ToolFlow.platform_for!` (R-T2), then `ToolFlow.compile_for!` (the compiler choice and the build of slice 047, the lock and the install of `ToolBuild`: the source of the tool in `tools.json` is `Git({ commit, ref })` and `path`). | R-T2, R-T11 to R-T21, R-T3, R-T4 |
## | 10 | `delete!` of the temp dir of `source!`, after a success and after a failure (R-CC2). The answer: `ToolInstall.report` with the version text `ToolGit.source_text`, or with `--json` the text on stderr and `ToolGit.data` on stdout. | R-J1 to R-J4, R-OUT2 |
ToolGitFlow :: [].{

	## `tln tool install` with a git source.
	run! : Fx, Args => I32
	run! = |fx, args| match ToolGit.read(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(Err(NotGit)) => ToolFlow.run!(fx, args)
		Ok(Ok(plan)) => match flow!(fx, args, plan) {
			Ok(done) => {
				print!(fx, args, plan, done)
				0
			}
			Err(fail) => Common.failed!(fx, args, fail)
		}
	}

	## Step 4 (R-T23, R-R3, R-RG3): the commit of the ref now. The token is resolved before the request, as `GitInstall` does.
	head! : Fx, Net.Settings, GitRef.Source, U64 => Try(Str, Fail)
	head! = |fx, net, source, now| {
		gh = match net.token {
			AskGh => Github.ask_gh!(fx)
			_ => Err(None)
		}
		url = GitRef.commit_url({ api: net.api, source })
		headers = GitRef.commit_headers({ token: Net.token({ plan: net.token, gh }) })
		match fx.http_get!({ url, headers }) {
			Ok(answer) => GitRef.commit_of({ source, url, now, status: answer.status, headers: answer.headers, body: answer.body })
			Err(why) => Err(Github.network_failure({ url, why }))
		}
	}

	## Step 7 (R-DA3, R-SE12): only curl refuses a redirect to http (a source archive has no published hash).
	check_curl! : Fx, Net.Settings => Try({}, Fail)
	check_curl! = |fx, net| {
		found = match fx.programs!(["curl", "wget"]) {
			[curl, wget] => { curl, wget }
			_ => { curl: Bool.False, wget: Bool.False }
		}
		match Download.choose({ want: net.downloader, curl: found.curl, wget: found.wget })? {
			Curl => Ok({})
			Wget => Err(ToolGit.needs_curl({}))
		}
	}

	## Step 8 (R-T23, R-R3, R-R7, R-SE12): the source of the commit in a temp dir, and the app that `main.roc` of the app dir is. `temp` is the dir that the caller deletes (R-CC2). A failure after the dir is made deletes it here.
	source! : Fx, ToolBuild.Facts, { source : GitRef.Source, sha : Str, path : Try(Str, [None]) } => Try({ bundle : ToolBuild.Bundle, temp : Str }, Fail)
	source! = |fx, facts, want| {
		lay = ToolGit.layout({ roots: facts.roots, hex: Temp.hex(fx.random!()), path: want.path })
		match fx.make_dirs!([lay.src]) {
			Ok(_) => {}
			Err(err) => return Err(Fail.new(Environment, "cannot make ${lay.src}: ${Str.inspect(err)}"))
		}
		match fetch_and_read!(fx, facts, lay, want) {
			Ok(bundle) => Ok({ bundle, temp: lay.temp })
			Err(fail) => {
				_ = fx.delete!([lay.temp])
				Err(fail)
			}
		}
	}
}

# What the command gave: the `Done` of `ToolBuild` and the commit of the ref.
Run : { done : ToolBuild.Done, commit : Str }

# Steps 2 to 10.
flow! : Fx, Args, ToolGit.Plan => Try(Run, Fail)
flow! = |fx, args, plan| {
	facts = ToolFlow.gather_for!(fx, { ref: plan.ref, as_name: plan.as_name, roc: plan.roc })?
	if args.offline return Err(GitRef.offline_failure(plan.source))
	sha = ToolGitFlow.head!(fx, facts.net, plan.source, facts.now)?
	installed = match facts.entries.find_first(|e| e.key == facts.key) {
		Ok(entry) => Ok(entry)
		Err(_) => Err(None)
	}
	match ToolGit.reuse({ installed, sha }) {
		Keep(version) => return Ok({ commit: sha, done: { how: Present, key: facts.key, name: facts.name, version, bin: Text.join(facts.bin, facts.file), built: Err(None) } })
		Build => {}
	}
	ToolBuild.entry_verdict!(fx, facts)?
	ToolGitFlow.check_curl!(fx, facts.net)?
	made = ToolGitFlow.source!(fx, facts, { source: plan.source, sha, path: plan.path })?
	result = build!(fx, args, plan, facts, made.bundle)
	_ = fx.delete!([made.temp])
	Ok({ commit: sha, done: result? })
}

# Step 9 (R-T2, R-T11 to R-T21): the platform, then the compiler and the build of slice 047.
build! : Fx, Args, ToolGit.Plan, ToolBuild.Facts, ToolBuild.Bundle => Try(ToolBuild.Done, Fail)
build! = |fx, args, plan, facts, bundle| {
	ToolFlow.platform_for!(fx, args, facts, bundle)?
	ToolFlow.compile_for!(fx, args, { ref: plan.ref, as_name: plan.as_name, roc: plan.roc }, facts, bundle)
}

# Step 8 (R-T23, R-R3, R-R7, R-SE12): curl to the archive (the full commit), tar into `src`, then `main.roc` of the app dir.
fetch_and_read! : Fx, ToolBuild.Facts, { archive : Str, dir : Str, file : Str, src : Str, temp : Str }, { source : GitRef.Source, sha : Str, path : Try(Str, [None]) } => Try(ToolBuild.Bundle, Fail)
fetch_and_read! = |fx, facts, lay, want| {
	url = GitRef.archive_url({ api: facts.net.api, source: want.source, sha: want.sha })
	id = GitRef.name_text(want.source)
	done = RocInstall.spawn_one!(fx, { argv: Download.command({ program: Curl, url, dest: lay.archive }), cwd: Err(Inherit) }, 8)
	failed = |outcome| Toolchain.download_failed({ id, url, program: Curl, ended: done.ended, outcome, last_line: done.stderr_last })
	match Download.outcome({ program: Curl, ended: done.ended, last_line: done.stderr_last }) {
		Done => {}
		Http(status) => return Err(failed(Http(status)))
		Failed => return Err(failed(Failed))
	}
	untar = RocInstall.spawn_one!(fx, { argv: Toolchain.tar_command({ archive: lay.archive, dir: lay.src }), cwd: Err(Inherit) }, 1)
	match untar.ended {
		Exited(0) => {
			_ = fx.delete!([lay.archive])
		}
		ended => return Err(Toolchain.tar_failed({ id, url, ended, last_line: untar.stderr_last }))
	}
	text = match fx.read_files!([lay.file]) {
		[Ok(found)] => found
		[Err(NotFound)] => return Err(ToolGit.no_main({ source: want.source, path: want.path }))
		other => return Err(Fail.new(Environment, "cannot read ${lay.file}: ${Str.inspect(other)}"))
	}
	header = match ToolBuild.app_header({ path: lay.file, text })? {
		Ok(found) => found
		Err(NotApp) => return Err(ToolGit.not_app(want.source))
	}
	Ok({
		version: ToolGit.source_text({ ref: want.source.ref, sha: want.sha }),
		url,
		hash: want.sha,
		dir: lay.dir,
		source: Git({ commit: want.sha, ref: want.source.ref }),
		path: want.path,
		pin: header.pin,
		pf: header.pf,
		hashes: header.hashes,
	})
}

# Step 10: the line on stdout (`--quiet` hides it), or with `--json` the line on stderr and the envelope on stdout.
print! : Fx, Args, ToolGit.Plan, Run => {}
print! = |fx, args, plan, run| {
	done = run.done
	shown = Common.shown_fx(fx, args)
	shown.out!(ToolInstall.report({ how: done.how, key: done.key, name: done.name, version: done.version }))
	if args.json {
		built = match done.built {
			Ok(b) => Ok({ nightly: b.nightly, target: b.target, sha256: b.sha256, entry: b.entry })
			Err(None) => Err(None)
		}
		data = ToolGit.data({ how: done.how, key: done.key, name: done.name, ref: plan.source.ref, commit: run.commit, path: plan.path, bin: done.bin, built })
		fx.out!(Out.json_ok({ command: args.typed, data }))
	}
}
