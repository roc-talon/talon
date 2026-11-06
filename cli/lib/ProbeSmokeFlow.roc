import Args
import Clock
import Common
import Compiler
import Consent
import Db
import Fail
import Fetch
import Fx
import Ident
import Install
import Item
import JsonDoc
import Launch
import Mode
import Net
import NoRank
import Out
import Probe
import ProbeFlow
import ProbeShow
import ProbeSmoke
import RocInstall
import Roots
import Smoke
import Start
import Temp
import Units

## The command code of `tln probe --smoke` (slice 218b, R-PB10, Design Q579). Command code over `Fx` (TESTING.md 2.2 part C). The L2 cases `probe/sm1` to `sm5` fix the calls. The decisions are `ProbeSmoke` (part A) and `Smoke` (slice 218: `result`, `app_text`).
##
## | # | Step | Calls (`calls.log`) | Rule |
## | --- | --- | --- | --- |
## | 1 | `ProbeSmoke.read`: a failure is `Common.failed!`, no call after the prelude | `args`, `env_all`, `tty` | R-PB10, R-FL12 |
## | 2 | An alias operand: the prelude and the compiler of `tln probe` with no `--range` (`ProbeFlow.flow!`, `single!`): the project, `Known.record!`, the run compiler (`ROC_TOOLCHAIN` first), `ResolveLoad.prepared!`, the pin check, `HeldRoc.held!`, `Start.run!`; the calls are those of `probe/pc1-targets` up to `canonical <cache> <roc cache>`. A URL operand uses no project (Design Q591): `env_all`, `clock`, `RocInstall.read_config!` (one `read_files` of `config.toml`), `Compiler.toolchain_of`, `path_roc`, `Launch.toolchains!`, `Compiler.select` with no project (ranks 2, 6, 7), `Start.run!`: no `cwd`, no project search, no `projects.json` record (`probe/sm1`) | as `probe/pc1-targets` (alias), `probe/sm1` (URL) | R-PB10 (section 13), R-SO21, R-PD16 |
## | 3 | The platform: an alias is `ProbeCmd.entry` (a node that is not a platform is exit 2 here: no more call; the URL form was checked by `read`), a URL is `Ident.of_url` (read made sure that it works) | none | R-PB10 |
## | 4 | The platform is in `packages/<hash>/`: `Fetch.packages!` of the URL (the calls of `probe/pc1-targets` and `probe/sm3`: `random`, `list_dirs`, and with no dir `programs`, `make_dirs`, the download, the unbundle, `rename`, `delete`). The unbundle program is the held compiler. A failure is its code (16 for a wrong hash, R-FE2) | `random`, `list_dirs <pkgs>`, ... | R-PB10, R-FE1, R-FE2 |
## | 5 | One `read_files` of `<pkgs>/<hash>/main.roc`, then `ProbeSmoke.pick`: exit 2 in the order of Design Q586: not a platform, no target to build, a target that is not of the platform | `read_files` | R-PB10 |
## | 6 | For each target, in order: `Smoke.app_text` (the URL of step 3), `random`, `make_dirs` of `<cache>/talon/tmp/<hex>`, `write_atomic` of `<tmp>/main.roc` | `random`, `make_dirs`, `write_atomic` | R-SM1, R-SM2 |
## | 7 | One `probes!` round for all targets: `roc build --target=<t> main.roc --output=<tmp>/tln-probe.out --no-cache`, `timeout` of `probe.timeout`, the cwd is the temp dir. No budget, no `Smoke` query (the build always runs) | `probes <n>` | R-PB10, R-SM4, R-LD8 |
## | 8 | `Smoke.result` of each output. One `db_write!` `Smoke` with the rows of the `Row` results (any outcome, `hang` too; `Machine` and a result with no fact give none). No queue call. Then one `delete!` of the temp dirs | `db_write ... smoke=<n>`, `delete` | R-SM4, R-SM7 |
## | 9 | The text (stdout, or stderr with `--json`) and, with `--json`, the envelope with `ProbeSmoke.data`. Exit 0, or exit 1 with `data` null and `error.details.smoke` when an item is `no-fact` (Q590) | none | R-PB8, R-OUT4 |
ProbeSmokeFlow :: [].{

	## The command. Called by `Run.dispatch!` for a `probe` line that has `--smoke` or `--target`.
	run! : Fx, Args => I32
	run! = |fx, args| match ProbeSmoke.read(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(plan) => match built!(fx, args, plan) {
			Err(fail) => Common.failed!(fx, args, fail)
			Ok(done) => finish!(fx, args, done)
		}
	}
}

Smoked : { target : Str, result : [Row(Db.Outcome), Machine, NoFact, NoSmokeApp] }

Done : { label : Str, compiler : Str, items : List(Smoked) }

# What steps 1 to 4 give: the compiler, the settings and the platform (its node and its release URL).
Ready : { roots : Roots, net : Net.Settings, offline : Bool, started : Start.Started, probe : Probe.Settings, node : Units.Node, url : Str, what : Str }

# Step 2 to 4: the prelude and the compiler of the operand.
ready! : Fx, Args, ProbeSmoke.Plan => Try(Ready, Fail)
ready! = |fx, args, plan| match plan.operand {
	Alias(name) => {
		request = ProbeFlow.begin!(fx, args, plan.opts, Bool.False)?
		got = ProbeFlow.started!(fx, request)?
		node = ProbeFlow.node_of!(fx, Alias(name), got.rows)?
		if !node.is_platform {
			return Err(Fail.new(Usage, "'${name}' is not a platform: tln probe --smoke builds the smoke app of a platform"))
		}
		Ok({ roots: request.roots, net: request.net, offline: request.offline, started: got.started, probe: got.run.probe, node, url: ProbeFlow.source_of(got.rows, node), what: name })
	}
	Url(link) => {
		ident = Ident.of_url(link).map_err(|_| Fail.new(Usage, "'${link}' is not a release URL: it needs one version X.Y.Z (R-DI5)"))?
		env = fx.env_all!()
		roots = Roots.of_run!(fx, env)?
		net = Net.from_env(env)
		_ = Clock.now!(fx, env)?
		config = RocInstall.read_config!(fx, roots)?
		toolchain = Compiler.toolchain_of(env)?
		on_path = Install.compiler!(fx, roots, Bool.False)
		installed = Launch.toolchains!(fx, roots)
		picked = Compiler.select({ argument: Err(Unset), env: toolchain, req: Err(Unset), nightly: Bool.True, has_toml: Bool.False, version_file: Err(None), default: config.default_roc, path: on_path.map_ok(|found| found.id), installed, times: [] })
		downloads = { auto: Consent.auto_install(env), allow: plan.opts.allow_downloads, yes: args.yes, mode: Mode.from_env({ env: Dict.from_list(env), json: args.json }), quiet: args.quiet, offline: args.offline, env }
		held = match picked {
			Ok(sel) => sel.id
			Err(_) => NoRank.ensure!(fx, { roots, run: { scope: Project([ident.hash]), exclude: [], downloads }, listed: installed })?.id
		}
		started = Start.run!(fx, { roots, path_roc: on_path, held, downloads })?
		none = { max: Err(Unset), timeout: Err(Unset), slots: Err(Unset), max_toolchains: Err(Unset) }
		probe = Probe.settings({ flag_slots: plan.opts.slots, project: none, user: config.probe })
		node = { hash: ident.hash, name: ident.name ?? link, version: ident.version, is_platform: Bool.True }
		Ok({ roots, net, offline: args.offline, started, probe, node, url: link, what: link })
	}
}

# Steps 1 to 8: the platform, the builds and the rows.
built! : Fx, Args, ProbeSmoke.Plan => Try(Done, Fail)
built! = |fx, args, plan| {
	ready = ready!(fx, args, plan)?
	started = ready.started
	match Fetch.packages!(fx, { roots: ready.roots, urls: [ready.url], offline: ready.offline, unbundler: Program(started.program), downloader: ready.net.downloader }) {
		[Err(fail)] => return Err(fail)
		_ => {}
	}
	text = RocInstall.read_text!(fx, "${Roots.item(ready.roots, Item.Package(ready.node.hash))}/main.roc")?
	names = ProbeSmoke.pick({ text, given: plan.wanted, what: ready.what })?
	label = ProbeShow.label_of(ready.node)
	if Smoke.app_text({ url: ready.url, text }).is_err() {
		return Ok({ label, compiler: started.id, items: names.map(|each| { target: each, result: NoSmokeApp }) })
	}
	apps = names.map(
		|each| {
			source = match Smoke.app_text({ url: ready.url, text }) {
				Ok(found) => found
				Err(NoSmoke) => ""
			}
			{ target: each, source }
		},
	)
	var $jobs = []
	var $tmps = []
	var $stop = []
	for one in apps {
		tmp = Roots.item(ready.roots, Item.TalonTmp(Temp.hex(fx.random!())))
		$tmps = $tmps.append(tmp)
		wrote = match fx.make_dirs!([tmp]) {
			Ok(_) => fx.write_atomic!([{ path: "${tmp}/main.roc", content: one.source }]).map_err(|_| Bool.False)
			Err(_) => Err(Bool.False)
		}
		match wrote {
			Ok(_) => {
				out_file = "${tmp}/tln-probe.out"
				spec = {
					compiler: started.id,
					program: started.program,
					args: ["build", "--target=${one.target}"].concat(Probe.build_args({ file: "main.roc", options: [], output: out_file }).drop_first(1)),
					dir: tmp,
					env: started.env,
					timeout: ready.probe.timeout,
					weight: Probe.weight(Build({ output: out_file })),
				}
				$jobs = $jobs.append({ target: one.target, spec })
			}
			Err(_) => {
				$stop = [Fail.new(Environment, "cannot make the temp dir ${tmp}")]
				break
			}
		}
	}
	tmps = $tmps
	match $stop.first() {
		Ok(fail) => {
			_ = fx.delete!(tmps)
			return Err(fail)
		}
		Err(_) => {}
	}
	outputs = fx.probes!({ pool: ready.probe.slots, specs: $jobs.map(|j| j.spec) })
	items = $jobs.map2(outputs, |j, out| { target: j.target, result: Smoke.result(out) })
	rows = items.keep_oks(
		|item| match item.result {
			Row(outcome) => Ok({ hash: ready.node.hash, nightly: started.id, target: item.target, outcome })
			_ => Err(NoRow)
		},
	)
	saved = save!(fx, ready.roots, rows)
	_ = fx.delete!(tmps)
	saved?
	Ok({ label, compiler: started.id, items })
}

# Step 8: one `db_write!` `Smoke` with the rows (no row: no call). A failed write is the warning or the stop of `Db.on_err` (R-CC8).
save! : Fx, Roots, List(Db.SmokeRow) => Try({}, Fail)
save! = |fx, roots, rows| {
	if rows.is_empty() return Ok({})
	open = { path: Roots.item(roots, CompatDb), busy_ms: Db.busy_ms, format: Db.format }
	match fx.db_write!(open, Smoke(rows)) {
		Ok(_) => Ok({})
		Err(err) => match Db.on_err({ err, what: Write, path: open.path }) {
			Stop(fail) => Err(fail)
			Warn(text) => {
				fx.err!("warning: ${text}\n")
				Ok({})
			}
		}
	}
}

# Step 9: the text, the envelope, the exit code. An item with no fact makes exit 1 with `data` null and the list in `error.details.smoke` (Q590).
finish! : Fx, Args, Done => I32
finish! = |fx, args, done| {
	answer = ProbeSmoke.text({ label: done.label, compiler: done.compiler, items: done.items })
	if args.json fx.err!(answer) else fx.out!(answer)
	doc = ProbeSmoke.data(done.items)
	no_fact = done.items.any(
		|item| match item.result {
			NoFact => Bool.True
			_ => Bool.False
		},
	)
	if no_fact {
		fail = Fail.new(Internal, "a smoke build gave no result: run the command again")
		Common.failed!(fx, args, { ..fail, details: Ok(doc) })
	} else {
		if args.json {
			fx.out!(Out.json_ok({ command: args.typed, data: doc }))
		}
		0
	}
}
