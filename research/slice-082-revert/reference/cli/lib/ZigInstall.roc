import Clock
import Consent
import Download
import Fail
import Fx
import Item
import Mode
import Net
import Nightlies
import Prompt
import Roots
import Temp
import Text
import Toolchain
import Zig

## The Zig dependency of a source build (slice 044, CLI 6.6, R-D1 to R-D4, R-NI6, R-DL1 to R-DL4). Direct style over `Fx` (TESTING.md 2.2 part C): `Zig` decides, this module orders the calls.
## There is no command in slice 044. Slice 045 (`tln roc install --git`) calls `ensure!` after it has read `build.zig.zon` of the source (`Zig.minimum`). The L2 entry `zig` (`tests/commands/main.roc`) and the test
## tool `flowprobe zig` (`cli/flowprobe.roc`) are the stand-ins for that command. The calls, in order (the L2 cases `zig/zs1-search`, `zig/zi1-install` and the L3 case `compilers/zi1-zig-install` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `Roots.from_env(env)` and `Net.from_env(env)` (no call). `Fx.platform!` and `Toolchain.host`. A failure is kind `Environment` (exit 18) before any other call. | R-CV8 |
## | 2 | One `programs!(["zig"])`. One `list_dirs!([<cache>/toolchains])` (a missing dir is an empty list), and `Zig.installed`. Then the versions, with one `spawn_all!` (limit 2, `cwd: Err(Inherit)`): the job `[<path of ZIG>, "version"]` when `Zig.env_zig` gives a program, and the job `["zig", "version"]` when `programs!` says that `zig` is on `PATH`. No call when there is no job. The version is the first line of the stdout, trimmed, when the child ended with `Exited(0)` and the line is not empty. Any other end: `Err(Unknown)`. | R-D1, R-EV11 |
## | 3 | `Zig.search`, with the candidates `Env`, `Path`, `Installed`. `Failed(fail)` (`ZIG` does not run) is the failure of the run: no dependency list, no more calls (R-D1). Then `fx.err!(Zig.deps(...))` (hidden by `--quiet`, R-FL4). `Found`: the command ends with `how: Found(source)`. No request, no prompt, no lock. `Missing`: one more `fx.err!("\n")` (the empty line before the prompt), also hidden by `--quiet`. | R-D1, R-D3 |
## | 4 | `--offline`: the failure `Toolchain.offline_missing("zig <Zig.wanted(need)>")` (kind `Network`, exit 15). No request. | R-DI12 |
## | 5 | `Clock.now!(fx, env)` (one `clock!` call, `TALON_NOW`: R-EV22). | R-EV22 |
## | 6 | One `http_get!({ url: Zig.index_url(env), headers: [] })`. A transport error, a timeout or a status other than 200 is a failure of kind `Network` (exit 15): `cannot read the Zig index <url>: HTTP <status>`, `... : no answer in 20 s`, `... : <text>`. | R-D2, R-EV16, R-EV21 |
## | 7 | `Zig.pick({ index: <body>, need, host })`. A failure is the failure of the run. | R-D2 |
## | 8 | `Prompt.ask!(Consent.zig_install({ version, size }))` with the mode of `Mode.from_env`, `facts.yes`, `facts.quiet` and no answer flag. `No`: `Consent.zig_install_declined`. Before the lock (R-CC3 point 5). | R-NI6, R-DL1, R-DL3, R-DL4, R-CC4 step 2 |
## | 9 | `Fx.locked!` on `Roots.item(Zig(version))` (the line `waiting for another tln: ...` comes from `with_lock!`). Steps 10 to 12 run inside. | R-CC3, R-CC4 step 3, R-CC5 |
## | 10 | One `list_dirs!` of `<cache>/toolchains`. The dir `zig-<version>` is there now: `Present`, no more calls. Else `Temp.of_item` gives the stale temps, and one `delete!` removes them (no call when there are none). | R-CC4 steps 4, 5 |
## | 11 | One `random!`, `Zig.plan`. One `programs!(["curl", "wget", "xz"])` and `Download.choose` (a failure is kind `Environment`). `Zig.needs_xz` and no `xz`: kind `Environment` (exit 18), `xz is not on PATH: tar needs it to extract <archive name>` (R-EC18). `make_dirs!([temp])`. One `spawn_all!` (limit 8): `Download.command` with `dest: archive`. A failure: `Toolchain.download_failed` with the id `zig-<version>`. | R-DA2, R-DA3, R-DA4, R-HF4 |
## | 12 | `sha256_file!(archive)`, `Toolchain.check_download` with the id `zig-<version>` and the `sha256` of the index. A failure deletes the temp dir (kind `Integrity`, exit 16). Then one `spawn_all!` (limit 1): `Toolchain.tar_command`. A failure: `Toolchain.tar_failed`. Then `delete!([archive])`. Then one `spawn_all!` (limit 1) with `Toolchain.chmod_command` for `Zig.Plan.zig` (no call for a Windows host). Then `write_atomic!([meta])` (`Zig.meta`, last), then `rename!({ from: temp, to: item })`. `Err(Exists)` is `Installed` (the other process won, drop the temp, as R-FE3). Each failure after `make_dirs!` deletes the temp dir. | R-D2, R-CV4, R-HF2, R-HF5, R-SE9, R-CC4 step 6 |
## | 13 | The unlock is done by `with_lock!` (R-CC4 step 7). The result: `how` is `Installed`, or `Present` (step 10), `path` is `<item>/<Zig.exe(host)>`. | R-CC4 step 7 |
##
## The output is on stderr only: the dependency list, the answer line of the prompt (R-NM6) and the wait line. The command prints no line when the install ends. `--json` has no effect on the lines (the caller prints the envelope).
## A failure writes no file in the toolchains dir: no `zig-<version>` dir, no temp, no download (R-CC2).
ZigInstall :: [].{

	## What `ensure!` needs. `need` is the text of `minimum_zig_version` (`Zig.minimum`). `env` is the environment (`Fx.env_all!` of the caller). `yes`, `quiet`, `json` and `offline` are the flags of the command.
	## `llvm` is the LLVM line of the dependency list (question Q4: the caller finds the asset of `roc-lang/roc-bootstrap`).
	Facts : { need : Str, env : List((Str, Str)), yes : Bool, quiet : Bool, json : Bool, offline : Bool, llvm : { target : Str, size : Try(U64, [Unknown]) } }

	## The result. `how` is `Found(source)` (a Zig that was there: no install), `Installed` (this run installed it), or `Present` (another process installed it while this run waited for the lock, step 10).
	Done : { version : Str, path : Str, how : [Found(Zig.Source), Installed, Present] }

	## The steps of the table at the top.
	ensure! : Fx, ZigInstall.Facts => Try(ZigInstall.Done, Fail)
	ensure! = |fx, facts| {
		roots = Roots.from_env(facts.env)?
		host = Toolchain.host(fx.platform!())?
		dir = Text.join(roots.cache, "toolchains")
		found = ZigInstall.search!(fx, { facts, roots, host, dir })
		match found {
			Failed(fail) => Err(fail)
			Found(f) => {
				ZigInstall.show!(fx, facts, found)
				Ok({ version: f.version, path: f.path, how: Found(f.source) })
			}
			Missing(_) => {
				ZigInstall.show!(fx, facts, found)
				if !facts.quiet {
					fx.err!("\n")
				}
				ZigInstall.install_missing!(fx, facts, { roots, host, dir })
			}
		}
	}

	## Steps 2 and 3: the candidates and the search. One `programs!`, one `list_dirs!`, at most one `spawn_all!`.
	search! : Fx, { facts : ZigInstall.Facts, roots : Roots, host : Nightlies.Host, dir : Str } => Zig.Search
	search! = |fx, run| {
		on_path = match fx.programs!(["zig"]) {
			[yes] => yes
			_ => Bool.False
		}
		installed = Zig.installed({ roots: run.roots, host: run.host, entries: toolchain_entries!(fx, run.dir) })
		env_probe : List({ source : Zig.Source, path : Str })
		env_probe = match Zig.env_zig(run.facts.env) {
			Ok(path) => [{ source: Env, path }]
			Err(NotSet) => []
		}
		path_probe : List({ source : Zig.Source, path : Str })
		path_probe = if on_path [{ source: Path, path: "zig" }] else []
		probes = env_probe.concat(path_probe)
		jobs = probes.map(|probe| { argv: [probe.path, "version"], cwd: Err(Inherit) })
		done = if jobs.is_empty() [] else fx.spawn_all!({ jobs, limit: 2 })
		looked = probes.map2(done, |probe, result| { source: probe.source, path: probe.path, version: version_of(result.ended, result.stdout) })
		Zig.search({ need: run.facts.need, candidates: looked.concat(installed) })
	}

	## Step 3: the dependency list on stderr. `--quiet` hides it (R-FL4).
	show! : Fx, ZigInstall.Facts, Zig.Search => {}
	show! = |fx, facts, found| {
		if !facts.quiet {
			fx.err!(Zig.deps({ need: facts.need, search: found, llvm: facts.llvm }))
		}
	}

	## Steps 4 to 9: no Zig fits. `--offline` stops. Else the index, the consent, the lock and the install.
	install_missing! : Fx, ZigInstall.Facts, { roots : Roots, host : Nightlies.Host, dir : Str } => Try(ZigInstall.Done, Fail)
	install_missing! = |fx, facts, run| {
		if facts.offline return Err(Toolchain.offline_missing("zig ${Zig.wanted(facts.need)}"))
		now = Clock.now!(fx, facts.env)?
		entry = Zig.pick({ index: ZigInstall.read_index!(fx, Zig.index_url(facts.env))?, need: facts.need, host: run.host })?
		mode = Mode.from_env({ env: Dict.from_list(facts.env), json: facts.json })
		asked = Prompt.ask!(fx, Consent.zig_install({ version: entry.version, size: entry.size }), { mode, yes: facts.yes, quiet: facts.quiet, flag: Err(NoFlag) })?
		match asked.answer {
			Yes => {}
			_ => return Err(Consent.zig_install_declined(entry.version))
		}
		item = Roots.item(run.roots, Item.Zig(entry.version))
		how = fx.locked!(item, || install!(fx, { roots: run.roots, host: run.host, dir: run.dir, entry, now, env: facts.env }))?
		Ok({ version: entry.version, path: Text.join(item, Zig.exe(run.host)), how })
	}

	## Step 6: the text of the Zig index. A transport error, a timeout or a status other than 200 is a failure of kind `Network`.
	read_index! : Fx, Str => Try(Str, Fail)
	read_index! = |fx, url| match fx.http_get!({ url, headers: [] }) {
		Ok(answer) => if answer.status == 200 Ok(answer.body) else Err(index_failed(url, "HTTP ${answer.status.to_str()}"))
		Err(Timeout) => Err(index_failed(url, "no answer in 20 s"))
		Err(Failed(text)) => Err(index_failed(url, text))
	}
}

Entries : List({ name : Str, is_dir : Bool, mtime : U64 })

# What the steps under the lock need.
Run : { roots : Roots, host : Nightlies.Host, dir : Str, entry : Zig.Entry, now : U64, env : List((Str, Str)) }

index_failed : Str, Str -> Fail
index_failed = |url, why| Fail.new(Network, "cannot read the Zig index ${url}: ${why}")

# The version is the first line of the output of `zig version`, when the program ended with 0.
version_of : Download.Ended, Str -> Try(Str, [Unknown])
version_of = |ended, stdout| match ended {
	Exited(0) => match stdout.split_on("\n").first() {
		Ok(line) => if line.trim().is_empty() Err(Unknown) else Ok(line.trim())
		Err(_) => Err(Unknown)
	}
	_ => Err(Unknown)
}

toolchain_entries! : Fx, Str => Entries
toolchain_entries! = |fx, dir| match fx.list_dirs!([dir]) {
	[Ok(entries)] => entries
	_ => []
}

# One child process. The result is `NotStarted` when the call gives none.
spawn_one! : Fx, { argv : List(Str), cwd : Try(Str, [Inherit]) }, U64 => { ended : Download.Ended, stdout : Str, stderr_last : Str }
spawn_one! = |fx, job, limit| match fx.spawn_all!({ jobs: [job], limit }) {
	[done] => done
	_ => { ended: NotStarted("no result"), stdout: "", stderr_last: "" }
}

# Steps 10 to 12, inside the lock of the item.
install! : Fx, Run => Try([Installed, Present], Fail)
install! = |fx, run| {
	entries = toolchain_entries!(fx, run.dir)
	item = Roots.item(run.roots, Item.Zig(run.entry.version))
	if entries.any(|e| e.is_dir and e.name == Text.last_segment(item)) return Ok(Present)
	stale = Temp.of_item({ item, entries })
	if !stale.is_empty() {
		_ = fx.delete!(stale)
	}
	p = Zig.plan({ roots: run.roots, host: run.host, version: run.entry.version, archive: run.entry.archive, hex: Temp.hex(fx.random!()) })
	found = match fx.programs!(["curl", "wget", "xz"]) {
		[curl, wget, xz] => { curl, wget, xz }
		_ => { curl: Bool.False, wget: Bool.False, xz: Bool.False }
	}
	program = Download.choose({ want: Net.from_env(run.env).downloader, curl: found.curl, wget: found.wget })?
	if Zig.needs_xz({ host: run.host, archive: run.entry.archive }) and !found.xz {
		return Err(Fail.new(Environment, "xz is not on PATH: tar needs it to extract ${run.entry.archive}"))
	}
	match fx.make_dirs!([p.temp]) {
		Ok(_) => {}
		Err(err) => return Err(Fail.new(Environment, "cannot make ${p.temp}: ${Str.inspect(err)}"))
	}
	match build!(fx, run, p, program) {
		Err(fail) => {
			_ = fx.delete!([p.temp])
			Err(fail)
		}
		Ok(_) => match fx.rename!({ from: p.temp, to: p.item }) {
			Ok(_) => Ok(Installed)
			Err(Exists) => {
				_ = fx.delete!([p.temp])
				Ok(Installed)
			}
			Err(err) => {
				_ = fx.delete!([p.temp])
				Err(Fail.new(Environment, "cannot move ${p.temp} to ${p.item}: ${Str.inspect(err)}"))
			}
		}
	}
}

# Download, check, extract, chmod, `.talon.json` last.
build! : Fx, Run, Zig.Plan, Download.Program => Try({}, Fail)
build! = |fx, run, p, program| {
	id = "zig-${run.entry.version}"
	download!(fx, run, id, p, program)?
	got = match fx.sha256_file!(p.archive) {
		Ok(digits) => digits
		Err(err) => return Err(Fail.new(Environment, "cannot read ${p.archive}: ${Str.inspect(err)}"))
	}
	Toolchain.check_download({ id, want: run.entry.sha256, got })?
	extract!(fx, run, id, p)?
	set_executable!(fx, run, p)?
	meta = Zig.meta({ version: run.entry.version, url: run.entry.url, sha256: run.entry.sha256, now: run.now })
	match fx.write_atomic!([{ path: p.meta, content: meta }]) {
		Ok(_) => Ok({})
		Err({ path, err }) => Err(Fail.new(Environment, "cannot write ${path}: ${Str.inspect(err)}"))
	}
}

download! : Fx, Run, Str, Zig.Plan, Download.Program => Try({}, Fail)
download! = |fx, run, id, p, program| {
	url = run.entry.url
	done = spawn_one!(fx, { argv: Download.command({ program, url, dest: p.archive }), cwd: Err(Inherit) }, 8)
	failed = |outcome| Toolchain.download_failed({ id, url, program, ended: done.ended, outcome, last_line: done.stderr_last })
	match Download.outcome({ program, ended: done.ended, last_line: done.stderr_last }) {
		Done => Ok({})
		Http(status) => Err(failed(Http(status)))
		Failed => Err(failed(Failed))
	}
}

# R-HF5: `tar` runs, then the archive is deleted.
extract! : Fx, Run, Str, Zig.Plan => Try({}, Fail)
extract! = |fx, run, id, p| {
	done = spawn_one!(fx, { argv: Toolchain.tar_command({ archive: p.archive, dir: p.temp }), cwd: Err(Inherit) }, 1)
	match done.ended {
		Exited(0) => {
			_ = fx.delete!([p.archive])
			Ok({})
		}
		ended => Err(Toolchain.tar_failed({ id, url: run.entry.url, ended, last_line: done.stderr_last }))
	}
}

# R-HF2
set_executable! : Fx, Run, Zig.Plan => Try({}, Fail)
set_executable! = |fx, run, p| match Toolchain.chmod_command({ host: run.host, file: p.zig }) {
	Err(NotNeeded) => Ok({})
	Ok(argv) => match spawn_one!(fx, { argv, cwd: Err(Inherit) }, 1).ended {
		Exited(0) => Ok({})
		ended => Err(Fail.new(Environment, "cannot set the executable bit of ${p.zig}: ${Str.inspect(ended)}"))
	}
}
