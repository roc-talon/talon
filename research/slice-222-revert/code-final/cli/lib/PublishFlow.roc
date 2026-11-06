import records.Index as WireIndex
import records.Release
import Args
import Common
import Compiler
import Db
import Fail
import Fx
import Github
import HeldRoc
import Help
import Ident
import Install
import Item
import JsonDoc
import Launch
import Net
import Out
import Probe
import ProbeFlow
import Publish
import PublishCheck
import Registry
import RegistryCache
import ResolveBase
import ResolveLoad
import RocInstall
import Roots
import Share
import Start
import Text
import UnitFlow

## `tln publish` (slice 221; CLI 1 R-CM13; Registry R-AP8, R-AP27, R-AP34, R-TP2). Direct style over `Fx`. The decisions are in `Publish`. The L2 cases are `tests/commands/cases/publish/pu1` to `pu8`.
## Calls in order (the `calls.log` of the cases fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `env_all!`, `Roots.of_run!`, `read_files!` of `config.toml`, `Share.setting`, `Net.registry` (the flag `--registry`, `TALON_REGISTRY`, the key `registry`): as `ShareAccountFlow.start!`. `Direct`: `Publish.direct` (exit 2). Then `--offline`: `Publish.offline` (exit 15). Then `Publish.operand(args.operands)` (exit 2). `--file` is accepted, no effect. | Q32, Q507, Q508, R-PUB4 items 1, 2 |
## | 2 | `Publish.job(env)` (repository, ref, form of both, safe tag), then `Publish.oidc(env)`: no call, exit 2 on a failure. Both come before any request, and before the release read (R-AP27, Q507). | R-PUB1, R-AP27, R-TP2 |
## | 3 | `http_get!` of `Publish.release_url` with `Net.headers` (the GitHub token: R-RG3, `GITHUB_TOKEN` in the cases), `Publish.asset`. A failure ends the command: no token request. | R-PUB2 |
## | 4 | `db_query!` `FactsOf(hash)` (the hash of `Ident.of_url(asset URL)`). `Err(TooNew)`: exit 19 (`Db.on_err`), no token request. `Busy`, `Failed`: one `warning: ` with `Publish.unread(cause)` and no `compat` member (Q517). | R-PB5, R-TF3 |
## | 5 | `Publish.facts`; its `warning` on stderr (more than 500: Q510). No fact (and no read failure): `warning: ` and `Publish.no_facts(hash)` on stderr. | R-PUB3 |
## | 5b | The API check (slice 222, `check!`, R-PU39, R-PUB4 item 13): never stops. The group read (`newest`, no token), `PublishCheck.previous`, then the compiler of `tln probe` and one `Fx.probes!` spec `roc bump`. | R-PU39 |
## | 6 | The token: `http_send!` of `Publish.token_request`, `Publish.token` (401, 403: exit 2). | R-TP2, Q515 |
## | 7 | The request: `http_send!` of `Publish.request`, `Publish.next`: `Wait(ms)` is `sleep!(ms)` and the same request; `Renew` is steps 6 and 7 again (a new token); `Stop` is `Publish.failure` (with `tries` and `renewed`); `Done` is `Publish.answer`. | R-AP8, R-AP34 |
## | 8 | Output: `Publish.lines` on stdout, or with `--json` the envelope with `Publish.data` (`Out.json_ok`). A failure: `Common.failed!`. `tln publish` does not send the share queue (Q518). | R-OUT2, R-J1, R-SH4 |
PublishFlow :: [].{

	## Returns the exit code.
	run! : Fx, Args => I32
	run! = |fx, args| match flow!(fx, args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(done) => {
			if args.json {
				fx.out!(Out.json_ok({ command: args.typed, data: Publish.data(done.report) }))
			} else {
				for line in Publish.lines(done.report) {
					fx.out!(line)
				}
			}
			0
		}
	}
}

Report : { owner : Str, repo : Str, tag : Str, hash : Str, created : Bool, facts : U64 }

Run : { origin : Str, net : Net.Settings, oidc : Publish.Oidc }

flow! : Fx, Args => Try({ report : Report }, Fail)
flow! = |fx, args| {
	env = fx.env_all!()
	roots = Roots.of_run!(fx, env)?
	config_path = Roots.item(roots, Item.Config)
	config = Share.setting({ path: config_path, text: RocInstall.read_text!(fx, config_path)? })?
	net = Net.from_env(env)
	origin = match Net.registry({ flag: args.registry, env: net.registry, config: config.registry }) {
		Direct => return Err(Publish.direct({}))
		Url(url) => url
	}
	if args.offline {
		return Err(Publish.offline({}))
	}
	Publish.operand(args.operands)?
	job = Publish.job(env)?
	oidc = Publish.oidc(env)?
	url = release!(fx, net, job)?
	hash = match Ident.of_url(url) {
		Ok(ident) => ident.hash
		Err(Foreign) => return Err(Fail.new(Internal, "the asset URL ${url} is not a package URL"))
	}
	found = facts!(fx, roots, hash)?
	check!(fx, args, { roots, origin, url })
	run = { origin, net, oidc }
	token = token!(fx, run)?
	sent = post!(fx, run, { url, facts: found.list }, { token, retries: 0, tries: 0, renewed: Bool.False })?
	Ok({ report: { owner: job.owner, repo: job.repo, tag: job.tag, hash, created: sent.created, facts: found.list.len() } })
}

# Step 3: the release of the tag, and the asset URL.
release! : Fx, Net.Settings, Publish.Job => Try(Str, Fail)
release! = |fx, net, job| {
	url = Publish.release_url({ api: net.api, owner: job.owner, repo: job.repo, tag: job.tag })
	gh = match net.token {
		AskGh => Github.ask_gh!(fx)
		_ => Err(None)
	}
	reply = fx.http_get!({ url, headers: Net.headers({ token: Net.token({ plan: net.token, gh }), etag: Err(None) }) })
	# The clock is read only for a rate limit answer.
	now = match reply {
		Ok(answer) => if answer.status == 403 or answer.status == 429 fx.clock!() else 0
		Err(_) => 0
	}
	Publish.asset({ api: net.api, owner: job.owner, repo: job.repo, tag: job.tag, now, reply })
}

# Steps 4 and 5: the facts of the hash. A `compat.db` that is busy or cannot be read is one warning and no facts (Q517).
facts! : Fx, Roots, Str => Try({ list : List(Publish.Fact) }, Fail)
facts! = |fx, roots, hash| {
	open = { path: Roots.item(roots, Item.CompatDb), busy_ms: Db.busy_ms, format: Db.format }
	read = match fx.db_query!(open, FactsOf(hash)) {
		Ok(Facts(rows)) => Ok(rows)
		Ok(_) => Ok([])
		Err(TooNew(found)) => match Db.on_err({ err: TooNew(found), what: Read, path: open.path }) {
			Stop(fail) => return Err(fail)
			Warn(_) => Ok([])
		}
		Err(Busy) => Err("busy")
		Err(Failed(why)) => Err(why)
	}
	match read {
		Err(cause) => {
			fx.err!("warning: ${Publish.unread(cause)}\n")
			Ok({ list: [] })
		}
		Ok(stored) => {
			chosen = Publish.facts({ hash, stored })
			match chosen.warning {
				Ok(text) => fx.err!("warning: ${text}\n")
				Err(None) => {}
			}
			if chosen.list.is_empty() {
				fx.err!("warning: ${Publish.no_facts(hash)}\n")
			}
			Ok({ list: chosen.list })
		}
	}
}

# Step 5b (slice 222): the API check. It never stops and never changes the exit code (R-PU39). Notes and the warning go to stderr.
check! : Fx, Args, { roots : Roots, origin : Str, url : Str } => {}
check! = |fx, args, run| match Ident.of_url(run.url) {
	Err(Foreign) => {}
	Ok(ident) => {
		form = ident.group.form
		match group!(fx, run, form) {
			Err(why) => fx.err!("note: ${PublishCheck.read_failed({ form, cause: why })}\n")
			Ok(rows) => match PublishCheck.previous({ version: ident.version, rows }) {
				Err(NoPrevious) => fx.err!("note: ${PublishCheck.first_note({ form, version: ident.version })}\n")
				Ok(prev) => match bump!(fx, args, { old: prev.url, version: ident.version, roots: run.roots }) {
					Err(why) => fx.err!("note: ${PublishCheck.unavailable({ reason: why })}\n")
					Ok(done) => match PublishCheck.report({ verdict: done.verdict, old: prev.version, version: ident.version, timeout: done.timeout }) {
						Err(Silent) => {}
						Ok(line) => match line.kind {
							Warning => fx.err!("warning: ${line.text}\n")
							Note => fx.err!("note: ${line.text}\n")
						}
					}
				}
			}
		}
	}
}

# Step 5b (a): the releases of the group, `newest`, no token, no series (R-AP13, R-RG3, Q527). `Err` has the cause for `PublishCheck.read_failed`. The clock is not read: `now` is 0 (`newest` has no age).
group! : Fx, { roots : Roots, origin : Str, url : Str }, Str => Try(List(Release.Row), Str)
group! = |fx, run, form| {
	path = Registry.releases_url({ origin: "", group: form, series: Err(None) })
	got = RegistryCache.get!(fx, { roots: run.roots, origin: run.origin, version: Help.version, path, now: 0, offline: Bool.False, newest: Bool.True, bookmark: Err(None) })
	match got {
		Err(fail) => Err(fail.message)
		Ok(NoCopy) => Err("no answer")
		Ok(Answer(answer)) => if answer.status == 200 {
			match WireIndex.decode_releases(answer.body) {
				Ok(decoded) => Ok(decoded.releases)
				Err(BadJson(_)) => Err("the answer does not decode")
			}
		} else {
			Err("HTTP ${answer.status.to_str()}")
		}
	}
}

# Step 5b (c) to (e): the project file, the compiler of `tln probe` (`Install.begin!`, `Install.compiler!`, `ResolveLoad.prepared!`, `ResolveBase.check_pin`, `HeldRoc.held!`), one `roc bump` probe. `Err(reason)` is a reason of `PublishCheck.unavailable`.
# A pin that is not installed is an optional download: `Start.run!` only with `--probe-downloads` or `--yes` (Q523). `publish` never prompts. No `Known.record!`: `publish` does not write `projects.json`.
bump! : Fx, Args, { old : Str, version : Str, roots : Roots } => Try({ verdict : PublishCheck.Verdict, timeout : U64 }, Str)
bump! = |fx, args, run| {
	start = Install.begin!(fx, args).map_err(|_| "no project file")?
	file = start.project.file.map_err(|_| "no project file")?
	toolchain = Compiler.toolchain_of(start.env).map_err(|fail| first_line(fail.message))?
	compiler = Install.compiler!(fx, start.roots, Bool.False)
	wanted = args.yes or args.options.any(|(name, _)| name == "--probe-downloads")
	flagged = ProbeFlow.request_of(args, { allow: if wanted Ok(Yes) else Err(NoFlag), probe: Err(NoFlag), slots: Err(Unset), none: Stop }, start, { toolchain, compiler })
	# Q542: with no flag the consent is `No` for the whole run, so a range with no installed compiler is refused before any request (`ResolveSelect.ranged!`), and the refusal is read as the note of Q542.
	request = if wanted flagged else { ..flagged, downloads: { ..flagged.downloads, auto: No } }
	prepared = ResolveLoad.prepared!(fx, request, Verify).map_err(|fail| prepared_reason(fail))?
	kind = prepared.loaded.members.find_first(|m| m.file == file).map_ok(|m| m.locked.kind) ?? App
	if kind != Package return Err("the project file is not a package")
	settings = ResolveBase.settings_of(request, prepared.loaded)
	ResolveBase.check_pin(prepared.loaded, settings, prepared.decision, Verify).map_err(|fail| first_line(fail.message))?
	# Q542: no required-download consent. With no flag `Start.run!` runs only for a compiler that is installed (or on `PATH`). A flag starts the download with no prompt.
	held = match prepared.decision.held {
		Ok(id) => id
		Err(NoCompiler) => if wanted {
			HeldRoc.held!(fx, request, prepared.loaded, prepared.decision.held).map_err(|fail| first_line(fail.message))?
		} else {
			return Err(no_compiler(prepared.decision.held_from, prepared.loaded.intent.toolchain.roc_text))
		}
	}
	# `Path` and the newest installed compiler (rank 6: `default-roc` is not set, `ResolveSelect` listed the toolchains) are installed by definition.
	rank6 = prepared.decision.held_from == Default and prepared.loaded.config.default_roc == Err(Unset)
	if !wanted and prepared.decision.held_from != Path and !rank6 {
		installed = Launch.toolchains!(fx, request.roots)
		if Compiler.find({ id: held, installed, path: request.compiler }) == Err(Missing) {
			return Err("the compiler ${held} is not installed (pass --probe-downloads to install it)")
		}
	}
	started = Start.run!(fx, { roots: request.roots, path_roc: request.compiler, held, downloads: ResolveBase.ladder_downloads(request) }).map_err(|fail| first_line(fail.message))?
	probe = ResolveBase.probe_settings(request, prepared.loaded)
	spec = {
		compiler: started.id,
		program: started.program,
		args: PublishCheck.bump_args({ old: run.old, version: run.version, file }),
		dir: Text.dir_of(file),
		env: started.env,
		timeout: probe.timeout,
		weight: Probe.weight(Check),
	}
	match UnitFlow.probes!(fx, { roots: request.roots, now: request.now, pool: probe.slots, started, base: started, specs: [spec] }) {
		[output] => Ok({ verdict: PublishCheck.verdict({ ended: output.ended, stdout: output.stdout, stderr: output.stderr }), timeout: probe.timeout })
		_ => Err("the probes gave no result")
	}
}

# Q542: the reason of a failure of `ResolveLoad.prepared!`. The refusal of `Consent.range_refused` (no installed compiler in the range, no request) carries the range (`refused_range`): the words of Q542 replace its text. Else the first line.
prepared_reason : Fail -> Str
prepared_reason = |fail| match fail.refused_range {
	Ok(range) => "no installed compiler is in the range ${range} (pass --probe-downloads to install it)"
	Err(None) => first_line(fail.message)
}

# Q542: the first line of the message of a failure (its exit code is not used).
first_line : Str -> Str
first_line = |text| text.split_on("\n").first() ?? text

# Q542: no held compiler, and no flag. A range that no installed compiler fits has its own words.
no_compiler : [Pin, Env, Range, VersionFile, Default, Path], Try(Str, [Unset]) -> Str
no_compiler = |from, text| match (from, text) {
	(Range, Ok(range)) => "no installed compiler is in the range ${range} (pass --probe-downloads to install it)"
	_ => "no compiler"
}

# Step 6: the OIDC token.
token! : Fx, Run => Try(Str, Fail)
token! = |fx, run| Publish.token(fx.http_send!(Publish.token_request({ oidc: run.oidc, origin: run.origin })))

State : { token : Str, retries : U64, tries : U64, renewed : Bool }

# Step 7: the request, with the waits and the new token (R-AP34).
post! : Fx, Run, { url : Str, facts : List(Publish.Fact) }, State => Try({ created : Bool, hash : Str, version : Str }, Fail)
post! = |fx, run, body, state| {
	reply = fx.http_send!(Publish.request({ origin: run.origin, version: Help.version, token: state.token, url: body.url, facts: body.facts }))
	tries = state.tries + 1
	match Publish.next({ retries: state.retries, renewed: state.renewed, reply }) {
		Done => match reply {
			Ok(answer) => Publish.answer({ origin: run.origin, status: answer.status, body: answer.body })
			Err(_) => Err(Fail.new(Internal, "no answer after a good answer"))
		}
		Renew => {
			new_token = token!(fx, run)?
			post!(fx, run, body, { ..state, token: new_token, tries, renewed: Bool.True })
		}
		Wait(ms) => {
			fx.sleep!(ms)
			post!(fx, run, body, { ..state, retries: state.retries + 1, tries })
		}
		Stop => Err(Publish.failure({ origin: run.origin, version: Help.version, tries, renewed: state.renewed, reply }))
	}
}
