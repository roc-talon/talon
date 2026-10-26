import Compiler
import Fail
import Fetch
import Fx
import Launch
import Locked
import NoRank
import Pin
import ProbeUnit
import ResolveBase
import Start
import Units

## Slice 072d (R-SO14, R-SO23, R-SO15, R-P5, R-PP4): the compiler of a command that runs a probe (`verify`, `probe`, `roc use`) when no rank selects one. Command code over `Fx` (TESTING.md 2.2 part C).
## A held compiler (a pin, `ROC_TOOLCHAIN`, `default-roc`, `PATH`) is the answer and no call is made. With no held compiler `NoRank.ensure!` picks one: (a) the newest installed compiler with a recorded pass,
## (b) a probe of the installed compilers, newest first (`probe_one!`), (c) and (d) a download that becomes `default-roc`.
HeldRoc :: [].{

	## `Ok(id)` for a held compiler (no call). `Err(NoCompiler)`: `ResolveBase.no_rank`. `Stop` is the failure of exit code 18. `Download` runs `NoRank.ensure!` with the installed compilers of `Launch.toolchains!` and step (b) as `probe_one!`.
	held! : Fx, ResolveBase.Request, ResolveBase.Loaded, Try(Str, [NoCompiler]) => Try(Str, Fail)
	held! = |fx, request, loaded, held| match held {
		Ok(id) => Ok(id)
		Err(NoCompiler) => match ResolveBase.no_rank(request, loaded) {
			Stop => Err(Compiler.failure(NoCompiler))
			Download(run) => ensured!(fx, request, loaded, { run, listed: Launch.toolchains!(fx, request.roots) })
		}
	}

	## Slice 072e (R-SO19, R-SO23, R-SL7): the compiler of a command that holds a nightly (`install`, `update`, `add`, `remove`, `upgrade`, `roc use`) when no compiler is selected, as an id only: no gate, no download, no default
	## (`NoRank.pick_id!`). The download is at the first probe (R-SO22), and it makes the default (R-SO24, `Start.run_picked!`). The caller calls it only when a probe will run: a run with nothing to check picks nothing.
	picked! : Fx, ResolveBase.Request, ResolveBase.Loaded => Try(Str, Fail)
	picked! = |fx, request, loaded| match ResolveBase.no_rank(request, loaded) {
		Stop => Err(Compiler.failure(NoCompiler))
		Download(run) => {
			listed = Launch.toolchains!(fx, request.roots)
			# Slice 080 removes this branch: R-SO24 allows no installed compiler without a selected one. Until then the steps (a) and (b) of R-SO14 apply, as for `held!`.
			if listed.any(Pin.is_id) {
				ensured!(fx, request, loaded, { run, listed })
			} else {
				NoRank.pick_id!(fx, { roots: request.roots, env: run.downloads.env, offline: run.downloads.offline, scope: run.scope, listed })
			}
		}
	}
}

# The steps (a) to (d) of `NoRank.ensure!` with the installed compilers `listed` and the probe of step (b) as `probe_one!`.
ensured! : Fx, ResolveBase.Request, ResolveBase.Loaded, { run : NoRank.Run, listed : List(Str) } => Try(Str, Fail)
ensured! = |fx, request, loaded, facts| {
	max = ResolveBase.probe_settings(request, loaded).max
	got = NoRank.ensure!(fx, { roots: request.roots, run: { ..facts.run, probe: Run({ max, one!: |req| probe_one!(fx, request, loaded, req) }) }, listed: facts.listed })?
	Ok(got.id)
}

# Step (b) for one installed compiler (R-SO14 (b), R-PB2): the ladder of `tln probe` with no baseline. The packages of the release entries, then one unit check for each hash in the order of the header (the first non-pass stops the compiler), then the check and the build of the project.
# No probe starts when `req.left` probes are spent: a ladder that the budget stops before its end is `passed: False`. The facts of the probes are written by `ProbeUnit` (R-PP4).
probe_one! : Fx, ResolveBase.Request, ResolveBase.Loaded, { id : Str, left : U64 } => Try(NoRank.Probed, Fail)
probe_one! = |fx, request, loaded, req| {
	started = Start.run!(fx, { roots: request.roots, path_roc: request.compiler, held: req.id, downloads: ResolveBase.ladder_downloads(request) })?
	rows = loaded.members.join_map(|m| m.locked.rows)
	fetch!(fx, request, started, rows)?
	run = { roots: request.roots, now: request.now, started, probe: ResolveBase.probe_settings(request, loaded) }
	var $count = 0.U64
	for node in nodes_of(rows) {
		if $count >= req.left return Ok({ passed: Bool.False, probes: $count })
		fact = ProbeUnit.node!(fx, run, node)?
		$count = $count + 1
		if fact.outcome != Pass return Ok({ passed: Bool.False, probes: $count })
	}
	match request.project.file {
		Err(_) => Ok({ passed: Bool.True, probes: $count })
		Ok(file) => {
			if $count >= req.left return Ok({ passed: Bool.False, probes: $count })
			kind = loaded.members.find_first(|m| m.file == file).map_ok(|m| m.locked.kind) ?? App
			done = ProbeUnit.project!(fx, run, { file, kind })?
			passed = match (done.check.class, done.build) {
				(Pass, Ok(built)) => built.class == Pass
				(Pass, Err(NotRun)) => Bool.True
				_ => Bool.False
			}
			Ok({ passed, probes: $count + done.probes })
		}
	}
}

# The packages of the release entries of all members, fetched with the compiler that was started (R-FE1, R-FE4). A failed fetch is the failure.
fetch! : Fx, ResolveBase.Request, Start.Started, List(Locked.Row) => Try({}, Fail)
fetch! = |fx, request, started, rows| {
	urls = rows
		.keep_oks(
			|row| match row.what {
				Release(_) => Ok(row.value)
				_ => Err(NotRelease)
			},
		)
		.fold([], |found, url| if found.contains(url) found else found.append(url))
	if urls.is_empty() return Ok({})
	for result in Fetch.packages!(fx, { roots: request.roots, urls, offline: request.offline, unbundler: Program(started.program), downloader: request.net.downloader }) {
		match result {
			Ok(_) => {}
			Err(fail) => return Err(fail)
		}
	}
	Ok({})
}

# One node for each hash of a release entry, in the order of the header rows (the repeats stay out).
nodes_of : List(Locked.Row) -> List(Units.Node)
nodes_of = |rows| rows
	.keep_oks(
		|row| match row.what {
			Release(ident) => Ok({ hash: ident.hash, name: ident.hash, version: ident.version, is_platform: row.is_platform })
			_ => Err(NotRelease)
		},
	)
	.fold([], |found, node| if found.any(|seen| seen.hash == node.hash) found else found.append(node))
