import Opts
import Answer
import Args
import Fx
import HeldRoc
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
import NoRank
import JsonDoc
import Out
import ProbeBundle
import ProbeCmd
import ProbeShare
import ProbeShareFlow
import ProbeShow
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
		Ok(plan) => match share_origin!(fx, args, plan) {
			Err(fail) => Common.failed!(fx, args, fail)
			Ok(origin) => match flow!(fx, args, plan) {
				Err(fail) => Common.failed!(fx, args, fail)
				Ok(done) => finish!(fx, args, done, origin)
			}
		}
	}

	## The request of `tln verify` (R-SO21: the compiler choice is the one of `verify`). `tln probe` and `tln publish` (slice 222) share it. `flags` has `--allow-downloads`, `--probe-downloads` (the answers), `--slots` and the fallback when no compiler is held (`none`).
	request_of : Args, { allow : Try(Answer, [NoFlag]), probe : Try(Answer, [NoFlag]), slots : Try(U64, [Unset]), none : NoRank.Fallback }, Begun, { toolchain : Try(Str, [Unset]), compiler : Try({ id : Str, path : Str }, [NoCompiler]) } -> ResolveBase.Request
	request_of = |args, flags, start, picked| {
		command: Update,
		names: [],
		fixed: [],
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
		none: flags.none,
		index: Direct,
		registry: Off,
		toolchain: picked.toolchain,
		snapshot: Err(Unset),
		dry_run: Bool.False,
		add: { as_platform: Bool.False, as_alias: Err(Unset), no_pin: Bool.False },
		prompt: { mode: Mode.from_env({ env: Dict.from_list(start.env), json: args.json }), yes: args.yes, quiet: args.quiet, rename_keys: Err(NoFlag), allow_moves: Err(NoFlag) },
		downloads: { auto: Consent.auto_install(start.env), allow: flags.allow, probe: flags.probe, env: start.env },
		probe: { no_probe: Bool.False, slots: flags.slots },
	}
}

# `share` is what the share step of `--share` needs (slice 217): none for a run that has no alias or bundle node.
Finished : { shown : ProbeCmd.Shown, stop : Try(Fail, [None]), share : Try({ roots : Roots, net : Net.Settings, env : List((Str, Str)), source : Str, node : Units.Node }, [None]) }

# Slice 217, R-PB6: the registry of `--share`, read before any other work (`Err(None)`: no `--share`).
share_origin! : Fx, Args, ProbeCmd.Plan => Try(Try(Str, [None]), Fail)
share_origin! = |fx, args, plan| if plan.share Ok(Ok(ProbeShareFlow.check!(fx, args)?)) else Ok(Err(None))

Begun : { env : List((Str, Str)), roots : Roots, net : Net.Settings, now : U64, project : Project }

# The answer, then the exit code. With `--json` the answer text is on stderr. A stop (exit 12) prints the failure with the `data` in `error.details` (R-J5).
finish! : Fx, Args, Finished, Try(Str, [None]) => I32
finish! = |fx, args, done, origin| {
	answer = ProbeCmd.text(done.shown)
	if args.json fx.err!(answer) else fx.out!(answer)
	doc = ProbeCmd.data(done.shown)
	# Q506: the send runs after a probe of exit 0 or of exit 12 (budget). The non-zero code of the probe stays.
	runs = match done.stop {
		Ok(fail) => fail.kind == Budget
		Err(None) => Bool.True
	}
	match (origin, done.share) {
		(Ok(registry), Ok(share)) if runs => shared!(fx, args, { doc, origin: registry, share, probe: done.stop })
		_ => match done.stop {
			Ok(fail) => Common.failed!(fx, args, { ..fail, details: Ok(doc) })
			Err(None) => {
				if args.json {
					fx.out!(Out.json_ok({ command: args.typed, data: doc }))
				}
				0
			}
		}
	}
}

# Slice 217, Q493: the share step after a probe with exit 0. The share lines come after the probe lines (with `--json`, on stderr as the probe lines). The `data` of the share is added to the `data` of the probe. A failed send, or a send that did not finish, is its code (15).
shared! : Fx, Args, { doc : JsonDoc, origin : Str, probe : Try(Fail, [None]), share : { roots : Roots, net : Net.Settings, env : List((Str, Str)), source : Str, node : Units.Node } } => I32
shared! = |fx, args, run| match ProbeShareFlow.send!(fx, { roots: run.share.roots, net: run.share.net, origin: run.origin, source: run.share.source, hash: run.share.node.hash, env: run.share.env }) {
	Err(fail) => match run.probe {
		Ok(kept) => Common.failed!(fx, args, { ..kept, details: Ok(run.doc) })
		Err(None) => Common.failed!(fx, args, fail)
	}
	Ok(sent) => {
		label = ProbeShow.label_of(run.share.node)
		for line in ProbeShare.lines({ label, shared: sent.shared, kept_back: sent.kept_back, unsent: sent.unsent }) {
			if args.json fx.err!(line) else fx.out!(line)
		}
		extra = match ProbeShare.data({ shared: sent.shared, kept_back: sent.kept_back, unsent: sent.unsent }) {
			Obj(pairs) => pairs
			_ => []
		}
		doc = match run.doc {
			Obj(pairs) => JsonDoc.Obj(pairs.concat(extra))
			other => other
		}
		stop = match run.probe {
			Ok(kept) => Ok(kept)
			Err(None) => sent.stop
		}
		match stop {
			Ok(fail) => Common.failed!(fx, args, { ..fail, details: Ok(doc) })
			Err(None) => {
				if args.json {
					fx.out!(Out.json_ok({ command: args.typed, data: doc }))
				}
				0
			}
		}
	}
}

# The release URL of the header entry of the node (the source of the privacy guard), or none.
source_of : List(Locked.Row), Units.Node -> Str
source_of = |rows, node| match rows.find_first(
	|row| match row.what {
		Release(ident) => ident.hash == node.hash
		_ => Bool.False
	},
) {
	Ok(row) => row.value
	Err(_) => ""
}

# The steps of `Verify.flow!` up to the compiler, then the target.
flow! : Fx, Args, ProbeCmd.Plan => Try(Finished, Fail)
flow! = |fx, args, plan| {
	start = Install.begin!(fx, args)?
	Install.check_member(is_project(plan.target), start.project)?
	Known.record!(fx, { roots: start.roots, files: Install.canonical_files!(fx, start.project), now: start.now })?
	toolchain = Compiler.toolchain_of(start.env)?
	compiler = Install.compiler!(fx, start.roots, Bool.False)
	request = ProbeFlow.request_of(args, { allow: plan.opts.allow_downloads, probe: plan.opts.probe_downloads, slots: plan.opts.slots, none: Stop }, start, { toolchain, compiler })
	if plan.range ranged!(fx, request, plan.target) else single!(fx, request, plan.target)
}

is_project : ProbeCmd.Target -> Bool
is_project = |target| match target {
	Project => Bool.True
	_ => Bool.False
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
	held = HeldRoc.held!(fx, request, prepared.loaded, prepared.decision.held)?
	started = Start.run!(fx, { roots: request.roots, path_roc: request.compiler, held, downloads: ResolveBase.ladder_downloads(request) })?
	run = { roots: request.roots, now: request.now, started, probe: ResolveBase.probe_settings(request, prepared.loaded) }
	rows = rows_of(prepared.loaded, request.project)
	match target {
		Project => {
			file = request.project.file.map_err(|_| Fail.new(Usage, "tln probe needs a project file"))?
			kind = prepared.loaded.members.find_first(|m| m.file == file).map_ok(|m| m.locked.kind) ?? App
			done = ProbeUnit.project!(fx, run, { file, kind })?
			Ok({ shown: Project({ file, kind, compiler: started.id, check: done.check, build: done.build, probes: done.probes }), stop: Err(None), share: Err(None) })
		}
		_ => {
			node = node_of!(fx, target, rows)?
			program = match target {
				Bundle(_) => unbundle_program!(fx, request, { selected: started.id, installed: started.installed })?
				_ => started.program
			}
			materialise!(fx, request, { target, rows, node, program })?
			fact = ProbeUnit.node!(fx, run, node)?
			Ok({ shown: Unit({ node, compiler: started.id, fact, probes: 1 }), stop: Err(None), share: Ok({ roots: request.roots, net: request.net, env: request.downloads.env, source: source_of(rows, node), node }) })
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
			exclude: settings.exclude,
			probe: ResolveBase.probe_settings(request, loaded),
			env: request.downloads.env,
			flag: request.downloads.probe,
			yes: request.prompt.yes,
			mode: request.prompt.mode,
		},
	)?
	Ok({
		shown: Range({ node, found: found.found, probes: found.probes, downloads: found.downloads, facts: found.facts }),
		stop: ProbeCmd.stop({ found: found.found, cut: found.cut, unseen: found.unseen }),
		share: Ok({ roots: request.roots, net: request.net, env: request.downloads.env, source: source_of(rows, node), node }),
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
