import Clock
import Download
import Fail
import Fx
import Item
import Net
import Roots
import Setup
import SetupIo
import TalonUpdate
import Temp
import Text
import ToolBin
import ToolBinCheck
import ToolBinUse
import ToolInstall
import ToolsPlan
import XCache

## The flow of prebuilt project tool binaries (slices 092 and 093, CLI 6.4: R-PT9, R-PT19 to R-PT23, R-PT25, R-DA4, R-DA5; Design Q9, Q231 to Q239). Command code over `Fx` (TESTING.md 2.2 part C). `ToolBin`, `ToolBinCheck` and `ToolBinUse` decide.
## `ToolsStep` calls `check!` when a command writes a `url` (or keeps a `url`, R-PT19), and `use!` in `ensure!` (step 2 of R-PT9). `hit` is step 1 of R-PT9.
##
## The calls of `check!`, in order (the L2 cases `ptool/pt6` to `ptool/pt10` and `ptool/pt14` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 0 | No call when R-PT25 does not allow binaries, or the `url` is not on `github.com` (`ToolBinCheck.source`): the check does not run | R-PT25, Q234 |
## | 1 | `ToolBinCheck.list_assets` of the pages of the R-DI2 list that the command read (no call, Q9), `ToolBinCheck.found`. `--dry-run`: only this step (`would_check`). No target: the end, `bin = {}` | R-PT20 step 1, Q233, Q239 |
## | 2 | Once for the command (the result is given back as `gate`): `programs!(["gh"])`, one `spawn_all!` (limit 1) of `ToolBinCheck.help_argv`, then (exit 0) one of `gh auth status`. `NoGh`, `GhOld`: the note of R-PT23, no download | R-PT20 step 2, Q169, Q231 |
## | 3 | `programs!(["curl", "wget"])`, `random!`, `make_dirs!` of `<cache>/talon/tmp/<hex>`, one `spawn_all!` (limit 8) of the bundle download, one `spawn_all!` (limit 1) of `gh attestation verify` on it. A failure: the bundle note, `delete!` of the temp dir, `bin = {}` | R-PT20 step 3, Q232, Q235 |
## | 4 | One `spawn_all!` (limit 8) of the downloads of the targets of step 1, one `sha256_file!` each, `ToolBinCheck.digest_check` (exit 16: `delete!` of the temp dir) | R-PT20 step 4, R-DA4, R-DA5 |
## | 5 | One `spawn_all!` (limit 8) of `gh attestation verify` on each binary, `ToolBinCheck.judge`. The summary line, then the note of each target that failed. The file of the host target goes to its `talon/x/` entry (`enter!`). `delete!` of the temp dir | R-PT20 step 5, R-PT22, R-PT23 |
##
## `use!` (R-PT21): `programs!(["curl", "wget"])`, `random!`, `make_dirs!` of the temp dir, one `spawn_all!` (limit 8) of the download, `sha256_file!`, `ToolBinUse.verify` (exit 16), `enter!`, `delete!` of the temp dir, the use line on stderr. A download error: the warning, `delete!` of the temp dir, and the source build.
## `enter!` (R-PT22): `random!`, `make_dirs!` of `<dir>.<hex>.tmp`, `rename!` of the file into it, `chmod 0755` (none on Windows), `write_atomic!` of the manifest, `rename!` to `talon/x/<digest>`.
ToolBinFlow :: [].{

	## What the flow needs of the run: the roots, the network settings, the clock, the machine, and `--dry-run`.
	Env : { roots : Roots, net : Net.Settings, now : U64, os : Setup.Os, target : Str, dry_run : Bool }

	## The state of `gh` for the command: `NotAsked` until step 2 ran once.
	Gate : Try(ToolBinCheck.Gate, [NotAsked])

	## One check: the key of `[tools]` (the name in the texts), the full name, the release (`version`, `url`, `hash` of the bundle), the pages of the release list, the targets to try, and `ToolBin.allowed`.
	Check : { key : Str, name : Str, version : Str, url : Str, hash : Str, pages : List(Str), want : List(Str), allowed : Bool }

	## What a check gave: `ran` for `ToolBin.write`, the skip of step 2, `would_check` (`--dry-run`), the `x` entry of the host target, and the state of `gh`.
	Checked : { ran : Try(List(ToolBin.Hash), [NotRun]), skip : Try(ToolBinCheck.Skip, [None]), would_check : List(Str), added : List(XCache.Found), gate : ToolBinFlow.Gate }

	## One use: the key, the full name, the release, and the `bin` value of the host target.
	Use : { key : Str, name : Str, version : Str, url : Str, hash : Str, sha256 : Str }

	## The check of R-PT20 (see the table above).
	check! : Fx, ToolBinFlow.Env, ToolBinFlow.Gate, ToolBinFlow.Check => Try(ToolBinFlow.Checked, Fail)
	check! = |fx, env, gate, run| {
		none = { ran: Err(NotRun), skip: Err(None), would_check: [], added: [], gate }
		if !run.allowed {
			return Ok(none)
		}
		src = match ToolBinCheck.source(run.url) {
			Ok(s) => s
			Err(NotGithub) => return Ok(none)
		}
		assets = ToolBinCheck.list_assets({ pages: run.pages, tag: src.tag })
		found = ToolBinCheck.found({ hash: run.hash, want: run.want, assets })
		if env.dry_run {
			return Ok({ ..none, would_check: found.map(|f| f.target) })
		}
		if found.is_empty() {
			return Ok({ ..none, ran: Ok([]) })
		}
		state = match gate {
			Ok(known) => known
			Err(NotAsked) => gate_of!(fx, src)
		}
		with_gate = { ..none, gate: Ok(state) }
		match state {
			NoGh => skipped!(fx, run, with_gate, NoGh)
			GhOld => skipped!(fx, run, with_gate, GhOld)
			Ready => ready!(fx, env, run, with_gate, { src, found })
		}
	}

	## The use of R-PT21 (see the text above): `Ok(Ok(entry))`, `Ok(Err(Failed))` after a download error (the warning is printed: build from source), or the failure of `ToolBinUse.verify` (exit 16).
	use! : Fx, ToolBinFlow.Env, ToolBinFlow.Use => Try(Try(XCache.Found, [Failed]), Fail)
	use! = |fx, env, run| {
		program = match downloader!(fx, env.net) {
			Ok(p) => p
			Err(fail) => {
				warn!(fx, env, run, fail.message)
				return Ok(Err(Failed))
			}
		}
		tmp = temp_dir!(fx, env)?
		file = Text.join(tmp, ToolBin.asset_name({ hash: run.hash, target: env.target }))
		match download!(fx, program, asset_url(run.url, run.hash, env.target), file) {
			Ok(_) => {}
			Err(reason) => {
				_ = fx.delete!([tmp])
				warn!(fx, env, run, reason)
				return Ok(Err(Failed))
			}
		}
		got = match fx.sha256_file!(file) {
			Ok(sha) => sha
			Err(err) => {
				_ = fx.delete!([tmp])
				warn!(fx, env, run, "cannot read ${file}: ${Str.inspect(err)}")
				return Ok(Err(Failed))
			}
		}
		match ToolBinUse.verify({ key: run.key, version: run.version, target: env.target, got, want: run.sha256 }) {
			Ok(_) => {}
			Err(fail) => {
				_ = fx.delete!([tmp])
				return Err(fail)
			}
		}
		made = match ToolBinFlow.enter!(fx, env, { file, name: run.name, version: run.version, url: asset_url(run.url, run.hash, env.target), bundle: run.hash, sha256: got }) {
			Ok(found) => found
			Err(fail) => {
				_ = fx.delete!([tmp])
				return Err(fail)
			}
		}
		_ = fx.delete!([tmp])
		fx.err!("${ToolBinUse.use_line({ key: run.key, version: run.version, target: env.target, sha256: got })}\n")
		Ok(Ok(made))
	}

	## R-PT22: the `talon/x/` entry of a prebuilt binary of the host target (see the text above). `file` is the checked temp file, `url` the asset URL.
	enter! : Fx, ToolBinFlow.Env, { file : Str, name : Str, version : Str, url : Str, bundle : Str, sha256 : Str } => Try(XCache.Found, Fail)
	enter! = |fx, env, facts| {
		digest = ToolBinUse.digest({ bundle: facts.bundle, target: env.target, sha256: facts.sha256 })
		lay = XCache.layout({ roots: env.roots, digest, hex: Temp.hex(fx.random!()), file: ToolInstall.file_name({ os: env.os, key: Text.last_segment(facts.name) }) })
		match fx.make_dirs!([lay.temp]) {
			Ok(_) => {}
			Err(err) => return Err(SetupIo.dropped!(fx, lay.temp, "cannot make ${lay.temp}: ${Str.inspect(err)}"))
		}
		match fx.rename!({ from: facts.file, to: lay.temp_bin }) {
			Ok(_) => {}
			Err(err) => return Err(SetupIo.dropped!(fx, lay.temp, "cannot move ${facts.file} to ${lay.temp_bin}: ${Str.inspect(err)}"))
		}
		match TalonUpdate.chmod_command({ os: env.os, file: lay.temp_bin }) {
			Err(NotNeeded) => {}
			Ok(argv) => {
				# The end of `chmod` is not read (as the reference of the L2 cases: their `fx/jobs` have no rule for it).
				_ = one!(fx, argv)
			}
		}
		entry = { name: facts.name, version: facts.version, bundle: facts.bundle, target: env.target, sha256: facts.sha256, url: facts.url, last_run: Clock.format_utc(env.now) }
		match SetupIo.write_file!(fx, lay.temp_manifest, ToolBinUse.manifest_text(entry)) {
			Ok(_) => {}
			Err(fail) => {
				_ = fx.delete!([lay.temp])
				return Err(fail)
			}
		}
		made = { dir: lay.dir, entry: XCache.prebuilt_entry(entry), has_bin: Bool.True }
		match fx.rename!({ from: lay.temp, to: lay.dir }) {
			Ok(_) => Ok(made)
			Err(Exists) => {
				_ = fx.delete!([lay.temp])
				Ok(made)
			}
			Err(err) => Err(SetupIo.dropped!(fx, lay.temp, "cannot make ${lay.dir}: ${Str.inspect(err)}"))
		}
	}

	## R-PT9 step 1, R-PT22, R-PT25, Q237: the `x` entry that a project run takes for the bundle and the target: a prebuilt entry when `ToolBinUse.pick` gives it (it wins), else the source build entry of `ToolsPlan.cached` (a prebuilt entry never counts there).
	hit : { found : List(XCache.Found), bundle : Str, target : Str, bin : Try(ToolBin.Lock, [Unset]), machine : Try(Bool, [Unset]) } -> Try(XCache.Found, [None])
	hit = |facts| {
		entries = facts.found.keep_if(|f| f.has_bin).map(
			|f| {
				dir: f.dir,
				bundle: f.entry.bundle,
				target: f.entry.target,
				kind: if XCache.is_prebuilt(f.entry) Prebuilt({ sha256: f.entry.sha256 }) else Built,
			},
		)
		match ToolBinUse.pick({ scope: Project, bundle: facts.bundle, target: facts.target, bin: facts.bin, machine: facts.machine, entries }) {
			Prebuilt(dir) => match facts.found.find_first(|f| f.dir == dir) {
				Ok(f) => Ok(f)
				Err(_) => Err(None)
			}
			_ => ToolsPlan.cached({ entries: ToolBinFlow.source_only(facts.found), bundle: facts.bundle, target: facts.target })
		}
	}

	## Is there a prebuilt entry whose sha256 is the `bin` value of the target (so step 1 of R-PT9 needs `tool-binaries`)?
	prebuilt_there : { found : List(XCache.Found), bundle : Str, target : Str, bin : Try(ToolBin.Lock, [Unset]) } -> Bool
	prebuilt_there = |facts| match facts.bin {
		Ok(Hashes(have)) => match have.find_first(|h| h.target == facts.target) {
			Ok(h) => facts.found.any(|f| f.has_bin and XCache.is_prebuilt(f.entry) and f.entry.bundle == facts.bundle and f.entry.target == facts.target and f.entry.sha256 == h.sha256)
			Err(_) => Bool.False
		}
		_ => Bool.False
	}

	## The source build entries of a list (no prebuilt entry).
	source_only : List(XCache.Found) -> List(XCache.Found)
	source_only = |found| found.keep_if(|f| !XCache.is_prebuilt(f.entry))
}

# Step 2: `gh` found, the help run, `gh auth status`.
gate_of! : Fx, { repo : Str, tag : Str } => ToolBinCheck.Gate
gate_of! = |fx, src| {
	have = match fx.programs!(["gh"]) {
		[b] => b
		_ => Bool.False
	}
	help = if have Ok(one!(fx, ToolBinCheck.help_argv(src)).ended) else Err(NotAsked)
	auth = if help == Ok(Exited(0)) Ok(one!(fx, TalonUpdate.gh_auth_argv).ended) else Err(NotAsked)
	ToolBinCheck.gate({ found: have, help, auth })
}

# Step 2 failed: the note, no download, no `bin` key.
skipped! : Fx, ToolBinFlow.Check, ToolBinFlow.Checked, ToolBinCheck.Skip => Try(ToolBinFlow.Checked, Fail)
skipped! = |fx, run, base, skip| {
	fx.err!("${ToolBinCheck.skip_note({ key: run.key, version: run.version, skip })}\n")
	Ok({ ..base, skip: Ok(skip) })
}

# Steps 3 to 5.
ready! : Fx, ToolBinFlow.Env, ToolBinFlow.Check, ToolBinFlow.Checked, { src : { repo : Str, tag : Str }, found : List({ target : Str, digest : Str }) } => Try(ToolBinFlow.Checked, Fail)
ready! = |fx, env, run, base, facts| {
	src = facts.src
	program = match downloader!(fx, env.net) {
		Ok(p) => p
		Err(fail) => {
			fx.err!("${ToolBinCheck.bundle_note({ key: run.key, version: run.version, reason: fail.message })}\n")
			return Ok({ ..base, ran: Ok([]) })
		}
	}
	tmp = temp_dir!(fx, env)?
	bundle_file = Text.join(tmp, "${run.hash}.tar.zst")
	signer = match download!(fx, program, run.url, bundle_file) {
		Err(_) => Err("download failed")
		Ok(_) => {
			done = one!(fx, ToolBinCheck.verify_argv({ file: bundle_file, repo: src.repo, tag: src.tag }))
			match ToolBinCheck.signers({ ended: done.ended, stdout: done.stdout, last_line: done.stderr_last }) {
				Ok(list) => ToolBinCheck.bundle_signer(list)
				Err(reason) => Err(reason)
			}
		}
	}
	bundle = match signer {
		Ok(s) => s
		Err(reason) => {
			fx.err!("${ToolBinCheck.bundle_note({ key: run.key, version: run.version, reason })}\n")
			_ = fx.delete!([tmp])
			return Ok({ ..base, ran: Ok([]) })
		}
	}
	file_of = |target| Text.join(tmp, ToolBin.asset_name({ hash: run.hash, target }))
	jobs = facts.found.map(|f| { argv: Download.command({ program, url: asset_url(run.url, run.hash, f.target), dest: file_of(f.target) }), cwd: Err(Inherit) })
	results = fx.spawn_all!({ jobs, limit: 8 })
	var $ok = []
	var $failed = []
	for pair in facts.found.map2(results, |f, done| (f, done)) {
		(f, done) = pair
		file = file_of(f.target)
		match Download.outcome({ program, ended: done.ended, last_line: done.stderr_last }) {
			Done => match fx.sha256_file!(file) {
				Ok(sha) => match ToolBinCheck.digest_check({ key: run.key, version: run.version, target: f.target, digest: f.digest, sha256: sha }) {
					Ok(_) => {
						$ok = $ok.append({ target: f.target, file, sha256: sha })
					}
					Err(fail) => {
						_ = fx.delete!([tmp])
						return Err(fail)
					}
				}
				Err(err) => {
					$failed = $failed.append({ target: f.target, reason: "cannot read the download: ${Str.inspect(err)}" })
				}
			}
			_ => {
				$failed = $failed.append({ target: f.target, reason: "download failed" })
			}
		}
	}
	checked = $ok
	verified = if checked.is_empty() [] else fx.spawn_all!({ jobs: checked.map(|o| { argv: ToolBinCheck.verify_argv({ file: o.file, repo: src.repo, tag: src.tag }), cwd: Err(Inherit) }), limit: 8 })
	var $passed = []
	for pair in checked.map2(verified, |o, done| (o, done)) {
		(o, done) = pair
		judged = match ToolBinCheck.signers({ ended: done.ended, stdout: done.stdout, last_line: done.stderr_last }) {
			Ok(list) => ToolBinCheck.judge({ bundle, binary: list })
			Err(reason) => Err(reason)
		}
		match judged {
			Ok(_) => {
				$passed = $passed.append(o)
			}
			Err(reason) => {
				$failed = $failed.append({ target: o.target, reason })
			}
		}
	}
	passed = $passed
	if !passed.is_empty() {
		fx.err!("${ToolBinCheck.summary({ key: run.key, version: run.version, names: passed.map(|p| p.target), commit: bundle.commit, workflow: bundle.workflow })}\n")
	}
	for note in $failed.sort_with(|a, b| Text.compare(a.target, b.target)) {
		fx.err!("${ToolBinCheck.target_note({ key: run.key, version: run.version, target: note.target, reason: note.reason })}\n")
	}
	added = match passed.find_first(|p| p.target == env.target) {
		Ok(host) => match ToolBinFlow.enter!(fx, env, { file: host.file, name: run.name, version: run.version, url: asset_url(run.url, run.hash, env.target), bundle: run.hash, sha256: host.sha256 }) {
			Ok(made) => [made]
			Err(fail) => {
				_ = fx.delete!([tmp])
				return Err(fail)
			}
		}
		Err(_) => []
	}
	_ = fx.delete!([tmp])
	Ok({ ..base, ran: Ok(passed.map(|p| { target: p.target, sha256: p.sha256 })), added })
}

# One child: one `spawn_all!` with limit 1.
one! : Fx, List(Str) => { ended : [Exited(I32), Signaled(I32), NotStarted(Str)], stdout : Str, stderr_last : Str }
one! = |fx, argv| match fx.spawn_all!({ jobs: [{ argv, cwd: Err(Inherit) }], limit: 1 }) {
	[done] => done
	_ => { ended: NotStarted("spawn_all! gave no result"), stdout: "", stderr_last: "" }
}

# R-DA2: the program of the downloads.
downloader! : Fx, Net.Settings => Try(Download.Program, Fail)
downloader! = |fx, net| {
	found = match fx.programs!(["curl", "wget"]) {
		[c, w] => { curl: c, wget: w }
		_ => { curl: Bool.False, wget: Bool.False }
	}
	Download.choose({ want: net.downloader, curl: found.curl, wget: found.wget })
}

# `random!`, `make_dirs!` of `<cache>/talon/tmp/<hex>`.
temp_dir! : Fx, ToolBinFlow.Env => Try(Str, Fail)
temp_dir! = |fx, env| {
	tmp = Roots.item(env.roots, Item.TalonTmp(Temp.hex(fx.random!())))
	match fx.make_dirs!([tmp]) {
		Ok(_) => Ok(tmp)
		Err(err) => Err(Fail.new(Environment, "cannot make ${tmp}: ${Str.inspect(err)}"))
	}
}

# One download (R-DA3, R-DA7): `Err(reason)` with the last stderr line of the child.
download! : Fx, Download.Program, Str, Str => Try({}, Str)
download! = |fx, program, url, dest| match fx.spawn_all!({ jobs: [{ argv: Download.command({ program, url, dest }), cwd: Err(Inherit) }], limit: 8 }) {
	[done] => match Download.outcome({ program, ended: done.ended, last_line: done.stderr_last }) {
		Done => Ok({})
		_ => Err(if done.stderr_last.is_empty() Str.inspect(done.ended) else done.stderr_last)
	}
	_ => Err("spawn_all! gave no result")
}

# R-PT21, R-PT23: the warning of a download error.
warn! : Fx, ToolBinFlow.Env, ToolBinFlow.Use, Str => {}
warn! = |fx, env, run, reason| fx.err!("${ToolBinUse.download_warning({ key: run.key, version: run.version, target: env.target, reason })}\n")

# R-PT17: the URL of the asset of a target: the dir of the release `url` and the asset name.
asset_url : Str, Str, Str -> Str
asset_url = |url, hash, target| {
	name = ToolBin.asset_name({ hash, target })
	match url.split_last("/") {
		Ok({ before, .. }) => "${before}/${name}"
		Err(_) => name
	}
}
