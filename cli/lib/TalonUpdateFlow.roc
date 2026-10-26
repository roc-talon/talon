import Args
import Common
import Del
import DelFlow
import Download
import Fail
import Fx
import GitRef
import Github
import Help
import Item
import Out
import Roots
import SetupIo
import TalonUpdate
import Temp
import Text
import ToolBuild
import ToolFlow
import ToolGitFlow
import ToolInstall
import ToolManage
import ToolManageFlow
import ToolUpdate
import ToolUpdateFlow
import ToolsJson
import Toolchain

## The command `tln tool update talon [--from-source]` (slice 050, CLI 6.5: R-S2, R-S3, R-S1, R-T9, R-T22, R-ST9, R-ST10, R-SE13, R-DA2 to R-DA4, R-HF2, R-CC1, R-CC2, R-CC6, R-J1 to R-J4). Direct style over `Fx` (TESTING.md 2.2 part C): `TalonUpdate` decides, this module orders the calls.
## `Run.run!` calls `update!` for `["tool", "update"]` when `TalonUpdate.is_target(args)` (one operand, `talon` or `roc-talon/talon`), else `ToolUpdateFlow.update!`. The calls, in order (the L2 cases `tool/ts1-update` to `ts6-source` and the L3 case `tools/ts1-update-talon` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `ToolManage.read(args)` (a failure: `Common.failed!`, no `Fx` call). `ToolManageFlow.machine!`: `env_all!`, `clock!`, `platform!`, one `read_files!` of `tools.json` (the entry `talon` is read from the same text), one `read_files!` of `config.toml`. | R-CM16, R-FL12 |
## | 2 | The release list of `roc-talon/talon`: `Github.releases!` (the cache page of R-DI2: `list_dirs!`, `http_get!`, `write_atomic!`; with `--offline` the cached page, the line `index: cached at <time>`, or `Github.no_page_failure`), then `TalonUpdate.releases` with the asset name (`TalonUpdate.asset_name`). A page that is not a release list: kind `Network`. | R-DI2, R-DI12, R-IS2 |
## | 3 | `TalonUpdate.current` (the entry, else `Help.version`), `TalonUpdate.pick`. A failure ends the command. `Current`: `TalonUpdate.up_to_date_text`, exit 0, nothing is downloaded or changed. | R-T9, R-C7, R-S4 |
## | 4 | `--from-source`: `source!` (part b, steps 4b to 4g below). No flag: steps 5 to 12. | R-S2 |
## | 4b | `--offline`: `GitRef.offline_failure` (exit 15, no call). One `http_get!` of the commit of the tag (`ToolGitFlow.head!`, as `tool update` of a branch). The entry is a source build of that commit: `TalonUpdate.up_to_date_text` with the text of the source, exit 0. | R-T24, R-DI12 |
## | 4c | The entries (step 6): `Foreign` `tln` is exit 2 before the download. | R-ST6, R-ST11 |
## | 4d | `ToolGitFlow.check_curl!` and `ToolGitFlow.source!` (the source archive of the commit, `main.roc` of the dir `cli`: the app). `ToolFlow.platform_for!` (R-T2). | R-S2, R-T23, R-R3, R-R7 |
## | 4e | `ToolUpdateFlow.consent_for!` (one decision for the compiler of the pin of the app: R-DL1 to R-DL5, as step 3 of `tool update`). An app with no pin: `ToolInstall.no_pin`. | R-DL1, R-T11 |
## | 4f | `ToolBuild.finish!` with the key `talon`, the file `tln` and the name `roc-talon/talon`: the build in the source, the install under the lock of `tools.json` (the entry `talon` is a git tool with the `path` `cli`), the entry `tln`. Slice 075 (R-S3): `ToolBuild.finish_checked!` runs `<build output> --version` (`file_started!`) after the build and before the lock. A failed check deletes the build dir and ends the command. | R-S2, R-T4, R-T5 |
## | 4g | The entry `roc` again (if `entries` makes it): on Windows, when the entry `roc` was there before the build (`first.roc_have`), one `random!` and one `rename!` of it to its `.del` name (`DelFlow.rename_away!`, R-ST10), then `ToolBuild.link_entry!`. `delete!` of the scratch dir of the source (also after a failure, R-CC2). The line `TalonUpdate.updated_text` with `TalonUpdate.source_text` of the new entry. | R-ST9, R-CC2 |
## | 5 | `--offline`: `TalonUpdate.offline_failure` (exit 15, no call). A release with no `sha256sums.txt`: `TalonUpdate.missing` (exit 16, no call). | R-DI12, R-S1 |
## | 6 | The entries (`states!`, `TalonUpdate.entries`): `list_dirs!` of the bin dir, `sha256_file!` of the file `tln` in the data bin dir, then `SetupIo.have_of!` for `tln` and for `roc` (one `sha256_file!` for each entry that is there), `ToolInstall.verdict` for each. `Foreign` `tln`: exit 2, before the download. | R-ST6, R-ST11, R-ST9 |
## | 7 | One `random!` (the hex of the temp names and of the `.del` names). `programs!(["curl", "wget"])` and `Download.choose`. `make_dirs!` of the data bin dir and of `<cache>/talon/tmp/<hex>`. One `spawn_all!` (limit 8) with 2 jobs: `Download.command` for the binary to `<data bin>/tln.<hex>.tmp` (`Temp.name`), then for `sha256sums.txt` to `<cache>/talon/tmp/<hex>/sha256sums.txt`. A failed job: `Toolchain.download_failed` with the id `talon <version>`. | R-DA2 to R-DA4, R-HF4 |
## | 8 | `sha256_file!` of the temp file, one `read_files!` of `sha256sums.txt`, `TalonUpdate.expected_sha` (`NotListed`: `TalonUpdate.unlisted`), `TalonUpdate.check_download` (exit 16). | R-S1, R-SE13 |
## | 8b | Slice 074 (R-S2, R-IS3, R-SE13): `programs!(["gh"])`. A `gh` that is there: one `spawn_all!` (limit 1) of `gh auth status`. Logged in (exit 0): one `spawn_all!` (limit 1) of `gh attestation verify <temp> --repo roc-talon/talon`, a failure is exit 16 (`TalonUpdate.attestation_check`), a good check is the line `attestation ok`. Else the note on stderr and no more call. | R-S2, R-IS3, R-SE13 |
## | 9 | `TalonUpdate.chmod_command`: one `spawn_all!` (limit 1) of `chmod 0755 <temp>` (none on Windows). One `spawn_all!` (limit 1) of `<temp> --version`, `TalonUpdate.version_check`. | R-HF2, R-S3 |
## | 10 | `Fx.locked!` on `Roots.item(ToolsJson)` (`Wait`, R-CC3) for the last step only (R-CC6): one `read_files!` of `tools.json`, step 6 again (the entries can change during the download), `TalonUpdate.del_moves` (Windows: one `rename!` of each existing file to its `.del` name), one `rename!` of the temp file over the file `tln` of the data bin dir, then for each name of `make` (`tln`, `roc`): `ToolBuild.link_entry!` (`hard_link!` to a temp name, else `copy_file!`, then `rename!`, R-ST7), then one `write_atomic!` of `tools.json` (`ToolsJson.put_talon`). | R-S3, R-ST9, R-ST10, R-CC1, R-CC6 |
## | 11 | One `delete!` of the temp file and of `<cache>/talon/tmp/<hex>`, after a success and after a failure (R-CC2). | R-CC2 |
## | 12 | The warnings of `TalonUpdate.entries` on stderr. The line `TalonUpdate.updated_text` on stdout (`--quiet` hides it). With `--json` the text goes to stderr and stdout is `Out.json_ok` with `ToolUpdate.data` of `TalonUpdate.outcome`. | R-J1 to R-J4, R-OUT2 |
## Part 050b (this module): the prebuilt path (steps 1 to 3 and 5 to 12) and `--from-source` (steps 4 and 4b to 4g: the private `source!` and `built!`, the public `ToolUpdateFlow.consent_for!`, the layout key of `ToolBuild.attempt!`). Part 050a (`TalonUpdate`, `ToolsJson`, `ToolManage`, `ToolManageFlow`) comes first.
TalonUpdateFlow :: [].{

	## `tln tool update talon`.
	update! : Fx, Args => I32
	update! = |fx, args| match ToolManage.read(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(_) => match run!(fx, args) {
			Ok(outcome) => {
				if args.json {
					fx.out!(Out.json_ok({ command: args.typed, data: ToolUpdate.data([outcome]) }))
				}
				0
			}
			Err(fail) => Common.failed!(fx, args, fail)
		}
	}
}

# What the steps need: the facts of the machine, the entry `talon`, the asset name and the installed version.
Ctx : { facts : ToolBuild.Facts, talon : Try(ToolsJson.Talon, [None]), asset : Str, current : Str }

# The state of the bin dir for the update (step 6): the verdict of `tln` and `roc`, and what is there.
States : { tln : [Make, Foreign], roc : [Make, Foreign], old : Try(Str, [NotFound]), tln_have : [Absent, Dir, Unreadable, Sha(Str)], roc_have : [Absent, Dir, Unreadable, Sha(Str)] }

# The facts of the prebuilt path after the entries are checked (steps 7 to 11).
Job : { release : TalonUpdate.Release, bin_url : Str, sums_url : Str, sums_path : Str, lay : ToolInstall.Layout, program : Download.Program, hex : Str, shown : Fx }

# Steps 1 to 4: the release list, the pick, the way.
run! : Fx, Args => Try(ToolUpdate.Outcome, Fail)
run! = |fx, args| {
	machine = ToolManageFlow.machine!(fx)?
	facts = machine.facts
	asset = TalonUpdate.asset_name({ os: facts.os, target: facts.target })
	list = release_list!(fx, args, facts, asset)?
	current = TalonUpdate.current({ entry: machine.talon, running: Help.version })
	ctx = { facts, talon: machine.talon, asset, current }
	picked = TalonUpdate.pick({ list, now: facts.now, min_age: facts.min_age, current, asset })?
	from_source = args.options.any(|(flag, _)| flag == "--from-source")
	if from_source {
		release = match picked {
			Newer(found) => found
			Current(found) => found
		}
		built_from_source!(fx, args, ctx, release)
	} else {
		match picked {
			Current(_) => {
				Common.shown_fx(fx, args).out!("${TalonUpdate.up_to_date_text(current)}\n")
				Ok(TalonUpdate.outcome({ old: current, new: current, how: UpToDate }))
			}
			Newer(release) => prebuilt!(fx, args, ctx, release)
		}
	}
}

# Step 2 (R-DI2, R-DI12): the cache page, the line of an offline run, `TalonUpdate.releases`.
release_list! : Fx, Args, ToolBuild.Facts, Str => Try(List(TalonUpdate.Release), Fail)
release_list! = |fx, args, facts, asset| {
	fetched = Github.releases!(fx, { net: facts.net, roots: facts.roots, owner: "roc-talon", repo: "talon", now: facts.now, offline: args.offline })?
	match fetched.source {
		Missing => return Err(Github.no_page_failure(TalonUpdate.name))
		Cached(time) => fx.err!("${Github.offline_line(time)}\n")
		Live => {}
	}
	match TalonUpdate.releases({ pages: fetched.pages, asset }) {
		Ok(list) => Ok(list)
		Err(BadPage(n)) => Err(Fail.new(Network, "the release list of ${TalonUpdate.name} (page ${n.to_str()}) is not a list of releases"))
	}
}

# Steps 5 to 12, the prebuilt file. The temp file and the scratch dir are deleted after a success and after a failure (R-CC2).
prebuilt! : Fx, Args, Ctx, TalonUpdate.Release => Try(ToolUpdate.Outcome, Fail)
prebuilt! = |fx, args, ctx, release| {
	if args.offline return Err(TalonUpdate.offline_failure(release.version))
	sums_url = match release.sums {
		Ok(url) => url
		Err(NoSums) => return Err(TalonUpdate.missing({ tag: release.tag, name: ctx.asset }))
	}
	bin_url = match release.bin {
		Ok(found) => found.url
		Err(NoAsset) => return Err(Fail.new(Internal, "${TalonUpdate.name} ${release.tag} has no ${ctx.asset}"))
	}
	facts = ctx.facts
	first = states!(fx, facts)?
	_ = TalonUpdate.entries({ os: facts.os, bin: facts.bin, tln: first.tln, roc: first.roc })?
	hex = Temp.hex(fx.random!())
	lay = layout_of(facts, hex)
	program = downloader!(fx, facts)?
	match fx.make_dirs!([lay.data_bin, lay.temp]) {
		Ok(_) => {}
		Err(err) => return Err(Fail.new(Environment, "cannot make ${lay.temp}: ${Str.inspect(err)}"))
	}
	job = { release, bin_url, sums_url, sums_path: Text.join(lay.temp, "sha256sums.txt"), lay, program, hex, shown: Common.shown_fx(fx, args) }
	staged = staged!(fx, ctx, job)
	_ = fx.delete!([lay.data_tmp, lay.temp])
	warnings = staged?
	for line in warnings {
		fx.err!("${line}\n")
	}
	entry = TalonUpdate.source_text(Prebuilt({ version: release.version, url: bin_url }))
	Common.shown_fx(fx, args).out!("${TalonUpdate.updated_text({ old: ctx.current, new: entry })}\n")
	Ok(TalonUpdate.outcome({ old: ctx.current, new: entry, how: Updated }))
}

# Steps 7 to 10: download, check, attestation, chmod, `--version`, then the install under the lock.
staged! : Fx, Ctx, Job => Try(List(Str), Fail)
staged! = |fx, ctx, job| {
	downloaded!(fx, job)?
	got = match fx.sha256_file!(job.lay.data_tmp) {
		Ok(sha) => sha
		Err(err) => return Err(Fail.new(Environment, "cannot read ${job.lay.data_tmp}: ${Str.inspect(err)}"))
	}
	sums = match fx.read_files!([job.sums_path]) {
		[Ok(text)] => text
		other => return Err(Fail.new(Environment, "cannot read ${job.sums_path}: ${Str.inspect(other)}"))
	}
	want = match TalonUpdate.expected_sha({ sums, name: ctx.asset }) {
		Ok(sha) => sha
		Err(NotListed) => return Err(TalonUpdate.unlisted({ tag: job.release.tag, name: ctx.asset }))
	}
	TalonUpdate.check_download({ tag: job.release.tag, name: ctx.asset, want, got })?
	attested!(fx, ctx, job)?
	made_executable!(fx, ctx.facts, job)?
	started!(fx, job)?
	fx.locked!(Roots.item(ctx.facts.roots, Item.ToolsJson), || installed!(fx, ctx, job, got))
}

# Step 8b (R-S2, R-IS3, R-SE13): the attestation of the temp file, before its first use. `gh` must be on `PATH` and logged in (`gh auth status`), else the note and no failure. A failed `gh attestation verify` is exit 16.
attested! : Fx, Ctx, Job => Try({}, Fail)
attested! = |fx, ctx, job| {
	found = match fx.programs!(["gh"]) {
		[there] => there
		_ => Bool.False
	}
	auth = if found {
		match gh!(fx, TalonUpdate.gh_auth_argv) {
			Ok(done) => Ok(done.ended)
			Err(fail) => return Err(fail)
		}
	} else {
		Err(NotAsked)
	}
	match TalonUpdate.gh_state({ found, auth }) {
		Ready => {
			done = gh!(fx, TalonUpdate.attest_argv({ file: job.lay.data_tmp }))?
			TalonUpdate.attestation_check({ tag: job.release.tag, asset: ctx.asset, ended: done.ended, last_line: done.stderr_last })?
			job.shown.out!("${TalonUpdate.attestation_ok}\n")
			Ok({})
		}
		_ => {
			fx.err!("${TalonUpdate.attestation_note}\n")
			Ok({})
		}
	}
}

# One `gh` run: one `spawn_all!` with limit 1.
gh! : Fx, List(Str) => Try({ ended : [Exited(I32), Signaled(I32), NotStarted(Str)], stdout : Str, stderr_last : Str }, Fail)
gh! = |fx, argv| match fx.spawn_all!({ jobs: [{ argv, cwd: Err(Inherit) }], limit: 1 }) {
	[done] => Ok(done)
	_ => Err(Fail.new(Internal, "spawn_all! gave no result"))
}

# Step 7 (R-DA2 to R-DA4): one `spawn_all!` with the binary and `sha256sums.txt`. The binary is checked first.
downloaded! : Fx, Job => Try({}, Fail)
downloaded! = |fx, job| {
	jobs = [
		{ argv: Download.command({ program: job.program, url: job.bin_url, dest: job.lay.data_tmp }), cwd: Err(Inherit) },
		{ argv: Download.command({ program: job.program, url: job.sums_url, dest: job.sums_path }), cwd: Err(Inherit) },
	]
	id = "talon ${job.release.version}"
	match fx.spawn_all!({ jobs, limit: 8 }) {
		[bin, sums] => {
			download_result(job.program, id, job.bin_url, bin)?
			download_result(job.program, id, job.sums_url, sums)
		}
		_ => Err(Fail.new(Internal, "spawn_all! gave no result"))
	}
}

download_result : Download.Program, Str, Str, { ended : Download.Ended, stdout : Str, stderr_last : Str } -> Try({}, Fail)
download_result = |program, id, url, done| {
	failed = |outcome| Toolchain.download_failed({ id, url, program, ended: done.ended, outcome, last_line: done.stderr_last })
	match Download.outcome({ program, ended: done.ended, last_line: done.stderr_last }) {
		Done => Ok({})
		Http(status) => Err(failed(Http(status)))
		Failed => Err(failed(Failed))
	}
}

# Step 9 (R-HF2): `chmod 0755` of the temp file. None on Windows.
made_executable! : Fx, ToolBuild.Facts, Job => Try({}, Fail)
made_executable! = |fx, facts, job| match TalonUpdate.chmod_command({ os: facts.os, file: job.lay.data_tmp }) {
	Err(NotNeeded) => Ok({})
	Ok(argv) => match fx.spawn_all!({ jobs: [{ argv, cwd: Err(Inherit) }], limit: 1 }) {
		[done] => match done.ended {
			Exited(0) => Ok({})
			other => Err(Fail.new(Environment, "cannot make ${job.lay.data_tmp} executable: ${Str.inspect(other)}"))
		}
		_ => Err(Fail.new(Internal, "spawn_all! gave no result"))
	}
}

# Step 9 (R-S3, R-T22): `<temp> --version`. Only the end of the child counts.
started! : Fx, Job => Try({}, Fail)
started! = |fx, job| file_started!(fx, job.lay.data_tmp, job.release.version)

# Step 9 and step 4f (R-S3): `<file> --version` of a prebuilt file, and of a source build before its install.
file_started! : Fx, Str, Str => Try({}, Fail)
file_started! = |fx, file, version| match fx.spawn_all!({ jobs: [{ argv: [file, "--version"], cwd: Err(Inherit) }], limit: 1 }) {
	[done] => TalonUpdate.version_check({ version, ended: done.ended })
	_ => Err(Fail.new(Internal, "spawn_all! gave no result"))
}

# Step 10, under the lock: `tools.json`, the entries again, the `.del` renames (Windows), the rename over the file, the entries `tln` and `roc`, then `tools.json`. The result is the warnings.
installed! : Fx, Ctx, Job, Str => Try(List(Str), Fail)
installed! = |fx, ctx, job, sha| {
	facts = ctx.facts
	tools_file = Roots.item(facts.roots, Item.ToolsJson)
	text = SetupIo.read_text!(fx, tools_file)?
	now = states!(fx, facts)?
	made = TalonUpdate.entries({ os: facts.os, bin: facts.bin, tln: now.tln, roc: now.roc })?
	data = match now.old {
		Ok(_) => [job.lay.data_file]
		Err(NotFound) => []
	}
	there = made.make.keep_if(|name| exists(now, name)).map(|name| Text.join(facts.bin, name))
	for move in TalonUpdate.del_moves({ os: facts.os, hex: job.hex, files: data.concat(there) }) {
		moved!(fx, move)?
	}
	moved!(fx, { from: job.lay.data_tmp, to: job.lay.data_file })?
	for name in made.make {
		_ = ToolBuild.link_entry!(fx, entry_layout(job.lay, facts.bin, name, job.hex))?
	}
	talon = TalonUpdate.prebuilt_entry({ release: job.release, url: job.bin_url, sha256: sha, target: facts.target, now: facts.now })
	SetupIo.write_file!(fx, tools_file, ToolsJson.put_talon({ path: tools_file, text, talon })?)?
	Ok(made.warnings)
}

moved! : Fx, { from : Str, to : Str } => Try({}, Fail)
moved! = |fx, move| match fx.rename!(move) {
	Ok(_) => Ok({})
	Err(err) => Err(Fail.new(Environment, "cannot move ${move.from} to ${move.to}: ${Str.inspect(err)}"))
}

# Does the bin dir entry `name` (`tln` or `roc`, with `.exe` on Windows) exist as a file?
exists : States, Str -> Bool
exists = |now, name| {
	have = if name.starts_with("tln") now.tln_have else now.roc_have
	match have {
		Absent => Bool.False
		_ => Bool.True
	}
}

# Step 6 (R-ST6, R-ST11): the bin dir, the file `tln` of the data bin dir, then the entries `tln` and `roc`.
states! : Fx, ToolBuild.Facts => Try(States, Fail)
states! = |fx, facts| {
	tln = ToolInstall.file_name({ os: facts.os, key: "tln" })
	roc = ToolInstall.file_name({ os: facts.os, key: "roc" })
	listed = match fx.list_dirs!([facts.bin]) {
		[one] => SetupIo.entries_of(one, facts.bin)?
		_ => return Err(Fail.new(Internal, "list_dirs! gave no result"))
	}
	data_file = Text.join(Roots.item(facts.roots, Item.Bin), tln)
	old = match fx.sha256_file!(data_file) {
		Ok(sha) => Ok(sha)
		Err(NotFound) => Err(NotFound)
		Err(err) => return Err(Fail.new(Environment, "cannot read ${data_file}: ${Str.inspect(err)}"))
	}
	tln_have = SetupIo.have_of!(fx, facts.bin, listed, tln)
	roc_have = SetupIo.have_of!(fx, facts.bin, listed, roc)
	Ok({ tln: ToolInstall.verdict({ old, have: tln_have }), roc: ToolInstall.verdict({ old, have: roc_have }), old, tln_have, roc_have })
}

# The paths of the file `tln` (the data file, the temp names) for one hex.
layout_of : ToolBuild.Facts, Str -> ToolInstall.Layout
layout_of = |facts, hex| ToolInstall.layout({ roots: facts.roots, bin: facts.bin, os: facts.os, key: "tln", hash: "", hex })

# The layout of one bin dir entry: it is a link to the data file `tln`.
entry_layout : ToolInstall.Layout, Str, Str, Str -> ToolInstall.Layout
entry_layout = |lay, bin, name, hex| {
	entry = Text.join(bin, name)
	{ ..lay, entry, entry_tmp: Temp.name({ target: entry, hex }) }
}

# R-DA2: `curl`, or `wget` (`TALON_DOWNLOADER`).
downloader! : Fx, ToolBuild.Facts => Try(Download.Program, Fail)
downloader! = |fx, facts| {
	found = match fx.programs!(["curl", "wget"]) {
		[curl, wget] => { curl, wget }
		_ => { curl: Bool.False, wget: Bool.False }
	}
	Download.choose({ want: facts.net.downloader, curl: found.curl, wget: found.wget })
}

# Steps 4 and 4b to 4g (R-S2, Q-F1, R-S3): the source archive of the tag, built as `tool install --git`, then `--version` of the build output. The scratch dir of the source is deleted after a success and after a failure (R-CC2).
built_from_source! : Fx, Args, Ctx, TalonUpdate.Release => Try(ToolUpdate.Outcome, Fail)
built_from_source! = |fx, args, ctx, release| {
	plan = TalonUpdate.source_of(release)
	if args.offline return Err(GitRef.offline_failure(plan.source))
	facts = ctx.facts
	shown = Common.shown_fx(fx, args)
	sha = ToolGitFlow.head!(fx, facts.net, plan.source, facts.now)?
	match same_commit(ctx.talon, sha) {
		Ok(text) => {
			shown.out!("${TalonUpdate.up_to_date_text(text)}\n")
			return Ok(TalonUpdate.outcome({ old: text, new: text, how: UpToDate }))
		}
		Err(None) => {}
	}
	first = states!(fx, facts)?
	made = TalonUpdate.entries({ os: facts.os, bin: facts.bin, tln: first.tln, roc: first.roc })?
	ToolGitFlow.check_curl!(fx, facts.net)?
	source_facts = { ..facts, name: TalonUpdate.name, key: "talon", file: ToolInstall.file_name({ os: facts.os, key: "tln" }) }
	src = ToolGitFlow.source!(fx, source_facts, { source: plan.source, sha, path: plan.path })?
	built = installed_from!(fx, args, source_facts, src.bundle, { make: made.make, roc_have: first.roc_have, version: release.version })
	_ = fx.delete!([src.temp])
	version = built?
	for line in made.warnings {
		fx.err!("${line}\n")
	}
	shown.out!("${TalonUpdate.updated_text({ old: ctx.current, new: version })}\n")
	Ok(TalonUpdate.outcome({ old: ctx.current, new: version, how: Updated }))
}

# The entry is a source build of this commit: the text of its source.
same_commit : Try(ToolsJson.Talon, [None]), Str -> Try(Str, [None])
same_commit = |talon, sha| match talon {
	Ok(found) => match found.source {
		Git(git) => if git.commit == sha Ok(TalonUpdate.source_text(found.source)) else Err(None)
		Prebuilt(_) => Err(None)
	}
	Err(None) => Err(None)
}

# Steps 4d to 4g: the platform, the compiler, the build and the install under the lock (the entry `tln`), then the entry `roc` again. `again.roc_have` is the entry `roc` that `states!` read before the build. The result is the version text of the new entry.
installed_from! : Fx, Args, ToolBuild.Facts, ToolBuild.Bundle, { make : List(Str), roc_have : Del.Have, version : Str } => Try(Str, Fail)
installed_from! = |fx, args, facts, bundle, again| {
	ToolFlow.platform_for!(fx, args, facts, bundle)?
	id = match bundle.pin {
		Ok(pin) => pin
		Err(NoPin) => return Err(ToolInstall.no_pin({ name: facts.name, version: bundle.version }))
	}
	ToolUpdateFlow.consent_for!(fx, args, facts, [id])?
	done = ToolBuild.finish_checked!(fx, args, facts, bundle, { id, passed: Err(None), first: Bool.True }, |file| file_started!(fx, file, again.version))?
	roc = ToolInstall.file_name({ os: facts.os, key: "roc" })
	if again.make.contains(roc) {
		hex = Temp.hex(fx.random!())
		# Slice 050d (R-ST10): on Windows an entry `roc` that exists goes to a `.del` name first. The data file was done by `ToolBuild.finish!`.
		layout = entry_layout(layout_of(facts, hex), facts.bin, roc, hex)
		_ = DelFlow.rename_away!(fx, { os: facts.os, files: Del.replaced({ data_file: layout.data_file, entry: layout.entry, old: Err(NotFound), have: again.roc_have }) })?
		_ = ToolBuild.link_entry!(fx, layout)?
	}
	Ok(done.version)
}
