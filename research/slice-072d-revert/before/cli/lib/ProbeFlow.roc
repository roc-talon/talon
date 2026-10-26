import Opts
import Args
import Fx
import Roots
import Common
import Compiler
import Consent
import Fail
import Fetch
import Install
import Known
import Launch
import Locked
import Mode
import Net
import Out
import ProbeBundle
import ProbeCmd
import ProbeSearch
import ProbeUnit
import Project
import ResolveBase
import ResolveLoad
import Start
import Units

## The command code of `tln probe` (slice 037, slice 039s: split from `ProbeCmd`, module size). `ProbeCmd` has the pure part (`read`, `entry`, `bundle_hash`, `stop`, `text`, `data`) and the table of the targets. Command code over `Fx` (TESTING.md 2.2 part C).
ProbeFlow :: [].{

	## The command (the table of `ProbeCmd`). `--json`: with exit 0 the envelope is `Out.json_ok({ command: args.typed, data })`. With exit 12 the envelope is the failure with `error.details` set to `data` (R-J5, as `tln audit` does for exit 21).
	run! : Fx, Args => I32
	run! = |fx, args| match ProbeCmd.read(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(plan) => match flow!(fx, args, plan) {
			Err(fail) => Common.failed!(fx, args, fail)
			Ok(done) => finish!(fx, args, done)
		}
	}
}

Finished : { shown : ProbeCmd.Shown, stop : Try(Fail, [None]) }

Begun : { env : List((Str, Str)), roots : Roots, net : Net.Settings, now : U64, project : Project }

# The answer, then the exit code. With `--json` the answer text is on stderr. A stop (exit 12) prints the failure with the `data` in `error.details` (R-J5).
finish! : Fx, Args, Finished => I32
finish! = |fx, args, done| {
	answer = ProbeCmd.text(done.shown)
	if args.json fx.err!(answer) else fx.out!(answer)
	doc = ProbeCmd.data(done.shown)
	match done.stop {
		Ok(fail) => Common.failed!(fx, args, { ..fail, details: Ok(doc) })
		Err(None) => {
			if args.json {
				fx.out!(Out.json_ok({ command: args.typed, data: doc }))
			}
			0
		}
	}
}

# The steps of `Verify.flow!` up to the compiler, then the target.
flow! : Fx, Args, ProbeCmd.Plan => Try(Finished, Fail)
flow! = |fx, args, plan| {
	start = Install.begin!(fx, args)?
	Install.check_member(is_project(plan.target), start.project)?
	Known.record!(fx, { roots: start.roots, files: Install.canonical_files!(fx, start.project), now: start.now })?
	toolchain = Compiler.toolchain_of(start.env)?
	compiler = Install.compiler!(fx, start.roots, Bool.False)
	request = request_of(args, plan.opts, start, { toolchain, compiler })
	if plan.range ranged!(fx, request, plan.target) else single!(fx, request, plan.target)
}

is_project : ProbeCmd.Target -> Bool
is_project = |target| match target {
	Project => Bool.True
	_ => Bool.False
}

# The request of `tln verify` (R-SO21: the compiler choice is the one of `verify`).
request_of : Args, Opts, Begun, { toolchain : Try(Str, [Unset]), compiler : Try({ id : Str, path : Str }, [NoCompiler]) } -> ResolveBase.Request
request_of = |args, opts, start, picked| {
	command: Update,
	names: [],
	frozen: Bool.False,
	no_check: Bool.False,
	project: start.project,
	roots: start.roots,
	net: start.net,
	now: start.now,
	offline: args.offline,
	strategy: Err(Unset),
	nightly: Common.nightly_of(start.env),
	compiler: picked.compiler,
	selected: "",
	none: Stop,
	toolchain: picked.toolchain,
	snapshot: Err(Unset),
	dry_run: Bool.False,
	add: { as_platform: Bool.False, as_alias: Err(Unset), no_pin: Bool.False },
	prompt: { mode: Mode.from_env({ env: Dict.from_list(start.env), json: args.json }), yes: args.yes, quiet: args.quiet, rename_keys: Err(NoFlag), allow_moves: Err(NoFlag) },
	downloads: { auto: Consent.auto_install(start.env), allow: opts.allow_downloads, probe: opts.probe_downloads, env: start.env },
	probe: { no_probe: Bool.False, slots: opts.slots },
}

# R-R12: the header entries of the current member, else of all members (as `tln why`).
rows_of : ResolveBase.Loaded, Project -> List(Locked.Row)
rows_of = |loaded, project| {
	named = loaded.members.keep_if(|m| m.file == (project.file ?? ""))
	(if named.is_empty() loaded.members else named).join_map(|m| m.locked.rows)
}

# No `--range` (R-PB2): the compiler that `verify` selects, then one unit check or the project probes.
single! : Fx, ResolveBase.Request, ProbeCmd.Target => Try(Finished, Fail)
single! = |fx, request, target| {
	prepared = ResolveLoad.prepared!(fx, request, Verify)?
	settings = ResolveBase.settings_of(request, prepared.loaded)
	ResolveBase.check_pin(prepared.loaded, settings, prepared.decision, Verify)?
	started = Start.run!(fx, { roots: request.roots, path_roc: request.compiler, held: prepared.decision.held ?? "", downloads: ResolveBase.ladder_downloads(request) })?
	run = { roots: request.roots, now: request.now, started, probe: ResolveBase.probe_settings(request, prepared.loaded) }
	rows = rows_of(prepared.loaded, request.project)
	match target {
		Project => {
			file = request.project.file.map_err(|_| Fail.new(Usage, "tln probe needs a project file"))?
			kind = prepared.loaded.members.find_first(|m| m.file == file).map_ok(|m| m.locked.kind) ?? App
			done = ProbeUnit.project!(fx, run, { file, kind })?
			Ok({ shown: Project({ file, kind, compiler: started.id, check: done.check, build: done.build, probes: done.probes }), stop: Err(None) })
		}
		_ => {
			node = node_of!(fx, target, rows)?
			program = match target {
				Bundle(_) => unbundle_program!(fx, request, { selected: started.id, installed: started.installed })?
				_ => started.program
			}
			materialise!(fx, request, { target, rows, node, program })?
			fact = ProbeUnit.node!(fx, run, node)?
			Ok({ shown: Unit({ node, compiler: started.id, fact, probes: 1 }), stop: Err(None) })
		}
	}
}

# `--range` (R-PB3): no pin decision and no required download. Phase 1 uses the installed compilers. Phase 2 downloads more only with the opt-in (R-NI4, slice 037c).
ranged! : Fx, ResolveBase.Request, ProbeCmd.Target => Try(Finished, Fail)
ranged! = |fx, request, target| {
	loaded = ResolveLoad.load!(fx, request)?
	settings = ResolveBase.settings_of(request, loaded)
	rows = rows_of(loaded, request.project)
	node = node_of!(fx, target, rows)?
	installed = Launch.toolchains!(fx, request.roots)
	program = unbundle_program!(fx, request, { selected: Fetch.selected({ held: "", default: loaded.config.default_roc ?? "" }), installed })?
	materialise!(fx, request, { target, rows, node, program })?
	found = ProbeSearch.run!(
		fx,
		{
			roots: request.roots,
			net: request.net,
			now: request.now,
			offline: request.offline,
			node,
			installed,
			path: request.compiler,
			nightly: settings.nightly,
			min_age: settings.min_age,
			probe: ResolveBase.probe_settings(request, loaded),
			env: request.downloads.env,
			flag: request.downloads.probe,
			yes: request.prompt.yes,
			mode: request.prompt.mode,
		},
	)?
	Ok({
		shown: Range({ node, found: found.found, probes: found.probes, downloads: found.downloads }),
		stop: ProbeCmd.stop({ found: found.found, cut: found.cut, unseen: found.unseen }),
	})
}

# The node of the target: the header entry of an alias (the tie list goes to stderr first), or the hash of a bundle file.
node_of! : Fx, ProbeCmd.Target, List(Locked.Row) => Try(Units.Node, Fail)
node_of! = |fx, target, rows| match target {
	Alias(name) => match ProbeCmd.entry({ text: name, rows }) {
		Ok(node) => Ok(node)
		Err({ fail, block }) => {
			if !block.is_empty() {
				fx.err!(block)
			}
			Err(fail)
		}
	}
	Bundle(path) => {
		hash = ProbeCmd.bundle_hash(path)?
		Ok({ hash, name: hash, version: "", is_platform: Bool.False })
	}
	Project => Err(Fail.new(Internal, "the project file has no hash"))
}

# R-FE4: the program that runs `roc unbundle`. No installed compiler and no `roc` on `PATH` is a required download that this command does not ask for (the failure of `Compiler.failure`).
unbundle_program! : Fx, ResolveBase.Request, { selected : Str, installed : List(Str) } => Try(Str, Fail)
unbundle_program! = |fx, request, chosen| match Fetch.unbundler({ selected: chosen.selected, installed: chosen.installed, path: request.compiler }) {
	Ok(id) => Launch.program!(fx, { roots: request.roots, id, installed: chosen.installed, path: request.compiler })
	Err(NoCompiler) => Err(Compiler.failure(NoCompiler))
}

# R-FE1, R-FE2: the package of the target is in `packages/<hash>/`: fetched for an alias, unbundled for a bundle file.
materialise! : Fx, ResolveBase.Request, { target : ProbeCmd.Target, rows : List(Locked.Row), node : Units.Node, program : Str } => Try({}, Fail)
materialise! = |fx, request, what| match what.target {
	Bundle(path) => ProbeBundle.ensure!(fx, { roots: request.roots, path, hash: what.node.hash, program: what.program })
	_ => {
		urls = what.rows.keep_oks(
			|row| match row.what {
				Release(ident) if ident.hash == what.node.hash => Ok(row.value)
				_ => Err(NotThis)
			},
		)
		match Fetch.packages!(fx, { roots: request.roots, urls: urls.take_first(1), offline: request.offline, unbundler: Program(what.program), downloader: request.net.downloader }) {
			[Err(fail)] => Err(fail)
			_ => Ok({})
		}
	}
}
