import Args
import BuildSkip
import Clock
import Fail
import Fx
import Ident
import Index
import JsonDoc
import Net
import ResolveBase
import ResolveSelect
import RocInstall
import Roots
import Selector
import Setup
import Temp
import Text
import ToolBuild
import ToolFlow
import ToolInstall
import ToolsPlan
import ToolsToml
import XCache
import XCacheIo

## The steps of the project tools that `install`, `update`, `upgrade` and the commands with `--tool` share (slice 056, CLI 6.4: R-PT3 to R-PT7, R-PT12, R-PT15, R-PT16, R-DL7, Resolution R-LF1, R-SO14, R-SO22). Command code over `Fx` (TESTING.md 2.2 part C).
## `ToolsPlan` and `ToolsToml` decide. A tool builds with the path of `tln x` (R-PT6: `ToolFlow` steps, `ToolBuild.built!`, `XCacheIo.write!`) and never touches `tools.json`, the bin dir or the lock of `tools.json` (R-PT12).
##
## The calls of `run!`, in order. Nothing is called when no entry is chosen (so a project with no `[tools]` has the same calls as before this slice):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `platform!` (one call), `BuildSkip.target` | R-X2 |
## | 2 | `XCacheIo.entries!` (its doc table), once | R-B9, R-PT9 |
## | 3 | For each chosen entry, in the order of the file (a failure stops the run, nothing is written): `Frozen`, and `Install` for an entry with a `url`: `ensure!` for the `url`. `Install` for an entry with no `url`, `Update`, `Upgrade`: `pick!`, then (a release that is not the `url` already) `chosen!` and `ensure!` | R-PT4 to R-PT6 |
## | 4 | With a change of `talon.toml` and no `--dry-run`: one `read_files!` of the file, `Guard.check_all`, one `write_atomic!` (`ResolveBase.write_checked!`). One write for all entries | R-CC7, R-CC1, R-PT5 |
## | 5 | The lines on stdout (`lines`) | R-OUT2 |
##
## `pick!` (R-PT4): `ToolFlow.release_list_for!`, `ToolsPlan.visible`, `ToolInstall.pick`, `ToolFlow.notes_for!`. `chosen!`: when the first candidate has an `x` entry (`ToolsPlan.cached`) no more call, else `ToolFlow.first_app_for!` (the fetch of the bundles).
## `ensure!` (R-PT6): a hit of `ToolsPlan.cached` ends it (no fetch, no build). Else `ToolFlow.bundle_for!` (when the bundle was not read), `ToolFlow.platform_for!` (R-PT16), `ToolFlow.choose_for!` (R-X1, R-DL7), `ToolBuild.built!`, `random!`, `XCacheIo.write!`, `delete!` of the temp dir (also after a failure, R-CC2).
ToolsStep :: [].{

	## What a run needs. `home` is the `talon.toml` that holds `[tools]` (`ToolsPlan.home`), `home_text` its text as the command read it (`""` for no file), `tools` the entries of that text.
	Ctx : { args : Args, env : List((Str, Str)), roots : Roots, net : Net.Settings, now : U64, min_age : U64, probe_timeout : U64, snapshot : Try(U64, [None]), dry_run : Bool, allow : Bool, home : Str, home_text : Str, tools : List(ToolsToml.Entry) }

	## One result. `action` is `Added`, `Locked`, `Moved`, `Built`, `Kept` or `Removed`. A `Kept` row has no line. `would_build` is set by `--dry-run` for a release that has no `x` entry: the real run would build it (D8 of the review).
	Row : { key : Str, name : Str, action : [Added, Locked, Moved, Built, Kept, Removed], ref : Try(Str, [None]), url : Try(Str, [None]), version : Try(Str, [None]), previous : Try(Str, [None]), built : Bool, would_build : Bool }

	## One change of `talon.toml`: the entry `key` gets `ref` and `url`, or the entry `key` goes.
	Change : [Put({ key : Str, ref : Str, url : Str }), Drop(Str)]

	## What a run did: the rows, the changes (written, or planned for `--dry-run`).
	Done : { rows : List(ToolsStep.Row), changes : List(ToolsStep.Change) }

	## R-LF1, R-PT7: the check of `--frozen` for the file of the run. No `Fx` call.
	frozen_check : ResolveBase.Request, ResolveBase.Loaded -> Try({}, Fail)
	frozen_check = |request, loaded| {
		home = ToolsPlan.home({ workspace: request.project.workspace, file: request.project.file })?
		ToolsPlan.frozen_check({ path: home, tools: loaded.intent.tools })
	}

	## The `Ctx` of a run of `install`, `update` or `upgrade`: the facts that the flow has already (no `Fx` call).
	ctx_of : Args, ResolveBase.Request, ResolveBase.Loaded -> Try(ToolsStep.Ctx, Fail)
	ctx_of = |args, request, loaded| {
		home = ToolsPlan.home({ workspace: request.project.workspace, file: request.project.file })?
		settings = ResolveBase.settings_of(request, loaded)
		snapshot = ResolveSelect.snapshot_of(request, loaded.intent)?
		Ok({
			args,
			env: request.downloads.env,
			roots: request.roots,
			net: request.net,
			now: request.now,
			min_age: settings.min_age,
			probe_timeout: ToolBuild.probe_timeout(loaded.config),
			snapshot,
			dry_run: request.dry_run,
			allow: request.downloads.allow == Ok(Yes),
			home,
			home_text: ResolveBase.loaded_text(loaded, home),
			tools: loaded.intent.tools,
		})
	}

	## The tools step of `install`, `update` and `upgrade` (R-PT5, R-PT6): `phase` and the `keys` (`[]` is each entry). Prints the lines. `changed` is true when a line was printed (D16 of the review: `InstallFlow` prints `nothing to change` only when the header and the tools both stay as they are).
	after! : Fx, Args, { request : ResolveBase.Request, loaded : ResolveBase.Loaded, phase : ToolsPlan.Phase, keys : List(Str) } => Try({ changed : Bool }, Fail)
	after! = |fx, args, run| {
		if run.loaded.intent.tools.is_empty() return Ok({ changed: Bool.False })
		ctx = ToolsStep.ctx_of(args, run.request, run.loaded)?
		done = ToolsStep.run!(fx, ctx, { phase: run.phase, keys: run.keys })?
		ToolsStep.write!(fx, ctx, done.changes)?
		ToolsStep.print!(fx, ctx, done)
		Ok({ changed: !done.changes.is_empty() or done.rows.any(|row| ToolsStep.line(row).is_ok()) })
	}

	## Steps 1 to 4: the entries `keys` of `ctx.tools` (`[]` is all) in the phase. Nothing is written for `--dry-run`.
	run! : Fx, ToolsStep.Ctx, { phase : ToolsPlan.Phase, keys : List(Str) } => Try(ToolsStep.Done, Fail)
	run! = |fx, ctx, run| {
		chosen = if run.keys.is_empty() ctx.tools else ctx.tools.keep_if(|e| run.keys.contains(e.key))
		if chosen.is_empty() return Ok({ rows: [], changes: [] })
		machine = ToolsStep.machine!(fx)?
		var $found = XCacheIo.entries!(fx, ctx.roots)?
		var $rows = []
		var $changes = []
		for entry in chosen {
			got = one!(fx, ctx, { machine, found: $found }, { phase: run.phase, entry })?
			$rows = $rows.append(got.row)
			$changes = match got.change {
				Ok(change) => $changes.append(change)
				Err(None) => $changes
			}
			$found = $found.concat(got.added)
		}
		Ok({ rows: $rows, changes: $changes })
	}

	## Step 4 (R-CC7, R-CC1, R-PT5): the changes in one write. The file is read again, the spans of the changed keys are compared with the first read, the new text is made from the text that was read again. No change, or `--dry-run`: no call.
	write! : Fx, ToolsStep.Ctx, List(ToolsStep.Change) => Try({}, Fail)
	write! = |fx, ctx, changes| {
		if changes.is_empty() or ctx.dry_run return Ok({})
		keys = changes.map(change_key)
		now = RocInstall.read_text!(fx, ctx.home)?
		new = changes.fold_try(now, |text, change| apply(ctx.home, text, change))?
		files = [{ path: ctx.home, read: ctx.home_text, now, spans_read: ToolsToml.spans({ text: ctx.home_text, keys }), spans_now: ToolsToml.spans({ text: now, keys }) }]
		_ = ResolveBase.write_checked!(fx, { files, edited: [{ path: ctx.home, now, new }] })?
		Ok({})
	}

	## Step 5 (R-OUT2, proposals): the line of each row that changed, then the line of each key that `talon.toml` got (also for `--dry-run`).
	print! : Fx, ToolsStep.Ctx, ToolsStep.Done => {}
	print! = |fx, ctx, done| {
		for row in done.rows {
			match ToolsStep.line(row) {
				Ok(text) => fx.out!("${text}\n")
				Err(None) => {}
			}
			if row.would_build {
				fx.out!("${ToolsPlan.line(WouldBuild({ key: row.key, name: row.name, version: row.version ?? "" }))}\n")
			}
		}
		for change in done.changes {
			fx.out!("${ToolsStep.file_line(ctx.home, change, done.rows)}\n")
		}
	}

	## The line of a row (`ToolsPlan.line`). A `Kept` row has none.
	line : ToolsStep.Row -> Try(Str, [None])
	line = |row| {
		version = row.version ?? ""
		match row.action {
			Added => Ok(ToolsPlan.line(Added({ key: row.key, name: row.name, version })))
			Locked => Ok(ToolsPlan.line(Locked({ key: row.key, name: row.name, version })))
			Moved => Ok(ToolsPlan.line(Moved({ key: row.key, name: row.name, old: row.previous ?? "", version })))
			Built => Ok(ToolsPlan.line(Built({ key: row.key, name: row.name, version })))
			Removed => Ok(ToolsPlan.line(Removed({ key: row.key, name: row.name })))
			Kept => Err(None)
		}
	}

	## The line of the file for a change (`ToolsPlan.file_line`).
	file_line : Str, ToolsStep.Change, List(ToolsStep.Row) -> Str
	file_line = |path, change, _rows| match change {
		Put(p) => ToolsPlan.file_line({ path, key: p.key, entry: Ok({ ref: p.ref, url: p.url }) })
		Drop(key) => ToolsPlan.file_line({ path, key, entry: Err(Removed) })
	}

	## The `data` rows of `--json` (`ToolsPlan.data`).
	data : Str, List(ToolsStep.Row) -> JsonDoc
	data = |path, rows| ToolsPlan.data(
		rows.map(
			|row| {
				key: row.key,
				name: row.name,
				action: action_text(row.action),
				ref: row.ref,
				url: row.url,
				version: row.version,
				previous: row.previous,
				file: path,
				built: row.built,
				would_build: row.would_build,
			},
		),
	)

	## Step 1: the machine facts that the build needs.
	machine! : Fx => Try({ os : Setup.Os, target : Str }, Fail)
	machine! = |fx| {
		host = fx.platform!()
		match BuildSkip.target(host) {
			Ok(target) => Ok({ os: host.os, target })
			Err(Unknown) => Err(Fail.new(Environment, "tln has no build target for this machine"))
		}
	}

	## The `ToolBuild.Facts` of a tool: no bin dir, no `tools.json` entries (R-PT12). `name` is the full name of the app.
	facts_of : ToolsStep.Ctx, { os : Setup.Os, target : Str }, Str -> ToolBuild.Facts
	facts_of = |ctx, machine, name| {
		key = Text.last_segment(name)
		{
			env: ToolsPlan.build_env({ env: ctx.env, allow: ctx.allow }),
			roots: ctx.roots,
			net: ctx.net,
			now: ctx.now,
			os: machine.os,
			bin: "",
			target: machine.target,
			entries: [],
			min_age: ctx.min_age,
			probe_timeout: ctx.probe_timeout,
			name,
			key,
			file: ToolInstall.file_name({ os: machine.os, key }),
		}
	}

	## R-PT4: the list of the releases, the snapshot, the pick and the notes (`ToolFlow.release_list_for!`, `ToolsPlan.visible`, `ToolInstall.pick`, `ToolFlow.notes_for!`). `selector` is `ToolsPlan.selector_for`. No build and no fetch of a bundle.
	pick! : Fx, ToolsStep.Ctx, { machine : { os : Setup.Os, target : Str }, name : Str, selector : Try(Selector, [None]) } => Try({ facts : ToolBuild.Facts, picked : ToolInstall.Picked, newest : Index.Candidate }, Fail)
	pick! = |fx, ctx, run| {
		facts = ToolsStep.facts_of(ctx, run.machine, run.name)
		list = ToolFlow.release_list_for!(fx, ctx.args, facts)?
		shown = ToolsPlan.visible({ list, snapshot: ctx.snapshot })
		picked = ToolInstall.pick({ name: run.name, list: shown, selector: run.selector, now: ctx.now, min_age: ctx.min_age })?
		newest = match picked.order.first() {
			Ok(first) => first
			Err(_) => return Err(Fail.new(Internal, "no release was picked"))
		}
		ToolFlow.notes_for!(fx, facts, picked, newest)
		Ok({ facts, picked, newest })
	}

	## R-PT10 (as `tln tool install`), R-PT9: the release that a pick gives: the newest candidate when its build is in the `x` cache (no fetch) or with `--dry-run` (no fetch), else the first candidate whose bundle is an app (`ToolFlow.first_app_for!`: the fetch of the bundles). `bundle` is `Err(Read)` for the first case.
	chosen! : Fx, ToolsStep.Ctx, { pick : { facts : ToolBuild.Facts, picked : ToolInstall.Picked, newest : Index.Candidate }, found : List(XCache.Found) } => Try({ rel : Release, bundle : Try(ToolBuild.Bundle, [Read]) }, Fail)
	chosen! = |fx, ctx, run| {
		newest = run.pick.newest
		release = { version: newest.ident.version, url: newest.url, hash: newest.ident.hash }
		hit = ToolsPlan.cached({ entries: run.found, bundle: release.hash, target: run.pick.facts.target })
		if hit.is_ok() or ctx.dry_run {
			return Ok({ rel: release, bundle: Err(Read) })
		}
		bundle = ToolFlow.first_app_for!(fx, ctx.args, run.pick.facts, run.pick.picked.order)?
		Ok({ rel: { version: bundle.version, url: bundle.url, hash: bundle.hash }, bundle: Ok(bundle) })
	}

	## R-PT6, R-PT15, R-PT16: the `x` entry of a release. A hit of `ToolsPlan.cached` is done (no fetch, no build). Else the bundle (read when `bundle` is `Err`), the platform, the compiler, the build and the entry. A build that does not pass is the failure of `ToolInstall.build_failed` (nothing is written).
	ensure! : Fx, ToolsStep.Ctx, { facts : ToolBuild.Facts, rel : Release, bundle : Try(ToolBuild.Bundle, [Read]), found : List(XCache.Found) } => Try({ built : Bool, would : Bool, added : List(XCache.Found) }, Fail)
	ensure! = |fx, ctx, run| {
		facts = run.facts
		if ToolsPlan.cached({ entries: run.found, bundle: run.rel.hash, target: facts.target }).is_ok() {
			return Ok({ built: Bool.False, would: Bool.False, added: [] })
		}
		if ctx.dry_run return Ok({ built: Bool.False, would: Bool.True, added: [] })
		bundle = match run.bundle {
			Ok(known) => known
			Err(Read) => match ToolFlow.bundle_for!(fx, ctx.args, facts, run.rel)? {
				Ok(read) => read
				Err(NotApp) => return Err(ToolInstall.no_candidate({ name: facts.name, newest: Ok(run.rel.version), branch: Err(None) }))
			}
		}
		ToolFlow.platform_for!(fx, ctx.args, facts, bundle)?
		chosen = match ToolFlow.choose_for!(fx, ctx.args, { roc: Auto }, facts, bundle) {
			Ok(found) => found
			Err(fail) => return Err(ToolsPlan.compiler_stop(fail))
		}
		attempt = ToolBuild.built!(fx, ctx.args, facts, bundle, chosen)?
		match attempt.class {
			Pass => {
				entry = { name: facts.name, source: bundle.source, hashes: bundle.hashes, nightly: chosen.id, target: facts.target, sha256: "", libs: [], bundle: bundle.hash, last_run: Clock.format_utc(facts.now) }
				stale = run.found.keep_if(|f| !f.has_bin).map(|f| f.dir)
				written = XCacheIo.write!(fx, facts.roots, { entry, output: attempt.layout.output, os: facts.os, hex: Temp.hex(fx.random!()), stale })
				_ = fx.delete!([attempt.layout.temp])
				Ok({ built: Bool.True, would: Bool.False, added: [written?.found] })
			}
			class => Err(ToolInstall.build_failed({ name: facts.name, version: bundle.version, id: chosen.id, class, errors: attempt.errors, output: attempt.layout.output }))
		}
	}
}

Release : { version : Str, url : Str, hash : Str }

action_text : [Added, Locked, Moved, Built, Kept, Removed] -> Str
action_text = |action| match action {
	Added => "added"
	Locked => "locked"
	Moved => "moved"
	Built => "built"
	Kept => "kept"
	Removed => "removed"
}

change_key : ToolsStep.Change -> Str
change_key = |change| match change {
	Put(p) => p.key
	Drop(key) => key
}

# One change on a text of `talon.toml`.
apply : Str, Str, ToolsStep.Change -> Try(Str, Fail)
apply = |path, text, change| match change {
	Put(p) => ToolsToml.put({ path, text, key: p.key, ref: p.ref, url: p.url })
	Drop(key) => ToolsToml.drop({ path, text, keys: [key] })
}

# What one entry did in a phase.
One : { row : ToolsStep.Row, change : Try(ToolsStep.Change, [None]), added : List(XCache.Found) }

# What the entries of a run share: the machine and the `x` entries that are there now.
State : { machine : { os : Setup.Os, target : Str }, found : List(XCache.Found) }

# One entry in a phase (R-PT5, D6).
one! : Fx, ToolsStep.Ctx, State, { phase : ToolsPlan.Phase, entry : ToolsToml.Entry } => Try(One, Fail)
one! = |fx, ctx, state, run| match run.phase {
	Frozen => locked!(fx, ctx, state, run.entry)
	Install => match run.entry.url {
		Ok(_) => locked!(fx, ctx, state, run.entry)
		Err(Unset) => moved!(fx, ctx, state, run)
	}
	Update | Upgrade => moved!(fx, ctx, state, run)
}

# The release of the pick: a `url` that is the newest one stays, else the tool moves to it (`Moved`), or is locked when it had no `url`.
moved! : Fx, ToolsStep.Ctx, State, { phase : ToolsPlan.Phase, entry : ToolsToml.Entry } => Try(One, Fail)
moved! = |fx, ctx, state, run| {
	entry = run.entry
	name = ToolsToml.app_of(entry.ref)
	selector = ToolsPlan.selector_for({ phase: run.phase, ref: entry.ref })
	picked = ToolsStep.pick!(fx, ctx, { machine: state.machine, name, selector })?
	kept = { row: { key: entry.key, name, action: Kept, ref: Ok(entry.ref), url: entry.url.map_err(|_| None), version: Err(None), previous: Err(None), built: Bool.False, would_build: Bool.False }, change: Err(None), added: [] }
	if entry.url == Ok(picked.newest.url) return Ok(kept)
	# R-UP5: `upgrade` moves the range of the `ref` to the new version. A range with no form is a note and the tool stays.
	ref = match run.phase {
		Upgrade => match ToolsPlan.upgrade_ref({ ref: entry.ref, version: picked.newest.ident.version }) {
			Ok(moved) => moved
			Err(NoForm) => {
				fx.err!("note: ${ToolsPlan.stuck_note({ key: entry.key, ref: entry.ref, version: picked.newest.ident.version })}\n")
				return Ok(kept)
			}
		}
		_ => entry.ref
	}
	chosen = ToolsStep.chosen!(fx, ctx, { pick: picked, found: state.found })?
	ensured = ToolsStep.ensure!(fx, ctx, { facts: picked.facts, rel: chosen.rel, bundle: chosen.bundle, found: state.found })?
	previous = match entry.url {
		Ok(url) => match Ident.of_url(url) {
			Ok(ident) => Ok(ident.version)
			Err(Foreign) => Err(None)
		}
		Err(Unset) => Err(None)
	}
	row = {
		key: entry.key,
		name,
		action: match previous {
			Ok(_) => Moved
			Err(None) => Locked
		},
		ref: Ok(ref),
		url: Ok(chosen.rel.url),
		version: Ok(chosen.rel.version),
		previous,
		built: ensured.built,
		would_build: ensured.would,
	}
	Ok({ row, change: Ok(Put({ key: entry.key, ref, url: chosen.rel.url })), added: ensured.added })
}

# R-PT6, R-PT9: an entry with a `url` needs its build only: it is made when the `x` cache has none for the bundle of the `url` (no release list, no change of `talon.toml`).
locked! : Fx, ToolsStep.Ctx, State, ToolsToml.Entry => Try(One, Fail)
locked! = |fx, ctx, state, entry| {
	name = ToolsToml.app_of(entry.ref)
	url = match entry.url {
		Ok(found) => found
		Err(Unset) => return Err(Fail.new(Internal, "tools.${entry.key} has no url"))
	}
	ident = match Ident.of_url(url) {
		Ok(found) => found
		Err(Foreign) => return Err(Fail.new(Input, "tools.${entry.key}.url: '${url}' is not a release URL with a version and a hash"))
	}
	facts = ToolsStep.facts_of(ctx, state.machine, name)
	ensured = ToolsStep.ensure!(fx, ctx, { facts, rel: { version: ident.version, url, hash: ident.hash }, bundle: Err(Read), found: state.found })?
	row = {
		key: entry.key,
		name,
		action: if ensured.built Built else Kept,
		ref: Ok(entry.ref),
		url: Ok(url),
		version: Ok(ident.version),
		previous: Err(None),
		built: ensured.built,
		would_build: ensured.would,
	}
	Ok({ row, change: Err(None), added: ensured.added })
}
