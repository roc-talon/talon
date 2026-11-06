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
import ToolBin
import ToolBinCheck
import ToolBinFlow
import ToolBinUse
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
## Slice 092: a new `url` (and a `url` that stays) gets the check of R-PT20 after `chosen!` and before `ensure!` (`locks!`, `ToolBinFlow.check!`); its `bin` table is in the same write (`Put` with `bin`, or `Bin`). Slice 093: `ensure!` takes a prebuilt entry with the `bin` value first (`ToolBinFlow.hit`), then the download of `ToolBinFlow.use!`, then the build.
ToolsStep :: [].{

	## What a run needs. `home` is the `talon.toml` that holds `[tools]` (`ToolsPlan.home`), `home_text` its text as the command read it (`""` for no file), `tools` the entries of that text.
	## Slice 092: `machine_bins` is `tool-binaries` of `config.toml` (R-PT25), `bins` the `bin` keys of the entries (R-PT18).
	Ctx : { args : Args, env : List((Str, Str)), roots : Roots, net : Net.Settings, now : U64, min_age : U64, exclude : List(Str), probe_timeout : U64, snapshot : Try(U64, [None]), dry_run : Bool, allow : Bool, home : Str, home_text : Str, tools : List(ToolsToml.Entry), selected : Str, machine_bins : Try(Bool, [Unset]), bins : List({ key : Str, bin : ToolBin.Lock }) }

	## One result. `action` is `Added`, `Locked`, `Moved`, `Built`, `Kept` or `Removed`. A `Kept` row has no line. `would_build` is set by `--dry-run` for a release that has no `x` entry: the real run would build it (D8 of the review).
	## Slice 092 (R-PT23): `bin` is `bin` after the command (`Off` for `bin = false`), `binary` what the command got (`NoBinary`: no binary was made), `bin_skip` the name of the skip of step 2 of R-PT20, `would_check` the targets of `--dry-run` (Q233).
	Row : { key : Str, name : Str, action : [Added, Locked, Moved, Built, Kept, Removed], ref : Try(Str, [None]), url : Try(Str, [None]), version : Try(Str, [None]), previous : Try(Str, [None]), built : Bool, would_build : Bool, bin : ToolsStep.BinView, binary : ToolsStep.Got, bin_skip : Try(Str, [None]), would_check : List(Str) }

	## Slice 092: the `bin` of a row: `Off` (`bin = false`) or the targets with a value.
	BinView : [Off, Targets(List(Str))]

	## Slice 093: the binary that a command got: a prebuilt one, a source build, or none.
	Got : [Prebuilt, Built, NoBinary]

	## One change of `talon.toml`: the entry `key` gets `ref` and `url`, or the entry `key` goes.
	## Slice 092 (R-PT19): `Put` has the `bin` table of a new `url` (`Err(None)`: no `bin` key, a `bin = false` stays). `Bin` adds values to the `bin` of a `url` that stays.
	Change : [Put({ key : Str, ref : Str, url : Str, bin : Try(List(ToolBin.Hash), [None]) }), Bin({ key : Str, ref : Str, url : Str, bin : List(ToolBin.Hash) }), Drop(Str)]

	## Slice 073: a row as `ToolsPlan.data` and `ToolsPlan.with_tools` take it (the row with the file, the action as text).
	JsonRow : { key : Str, name : Str, action : Str, ref : Try(Str, [None]), url : Try(Str, [None]), version : Try(Str, [None]), previous : Try(Str, [None]), file : Str, built : Bool, would_build : Bool, bin : ToolsStep.BinView, binary : ToolsStep.Got, bin_skip : Try(Str, [None]), would_check : List(Str) }

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
			exclude: settings.exclude,
			probe_timeout: ToolBuild.probe_timeout(loaded.config),
			snapshot,
			dry_run: request.dry_run,
			allow: request.downloads.allow == Ok(Yes),
			home,
			home_text: ResolveBase.loaded_text(loaded, home),
			tools: loaded.intent.tools,
			selected: request.selected,
			machine_bins: loaded.config.tool_binaries,
			bins: loaded.intent.tool_bins,
		})
	}

	## The tools step of `install`, `update` and `upgrade` (R-PT5, R-PT6): `phase` and the `keys` (`[]` is each entry). Prints the lines. `changed` is true when a line was printed (D16 of the review: `InstallFlow` prints `nothing to change` only when the header and the tools both stay as they are).
	after! : Fx, Args, { request : ResolveBase.Request, loaded : ResolveBase.Loaded, phase : ToolsPlan.Phase, keys : List(Str) } => Try({ changed : Bool, rows : List(ToolsStep.JsonRow) }, Fail)
	after! = |fx, args, run| {
		if run.loaded.intent.tools.is_empty() return Ok({ changed: Bool.False, rows: [] })
		ctx = ToolsStep.ctx_of(args, run.request, run.loaded)?
		done = ToolsStep.run!(fx, ctx, { phase: run.phase, keys: run.keys })?
		ToolsStep.write!(fx, ctx, done.changes)?
		ToolsStep.print!(fx, ctx, done)
		Ok({ changed: !done.changes.is_empty() or done.rows.any(|row| ToolsStep.line(row).is_ok()), rows: ToolsStep.json_rows(ctx.home, done.rows) })
	}

	## Steps 1 to 4: the entries `keys` of `ctx.tools` (`[]` is all) in the phase. Nothing is written for `--dry-run`.
	run! : Fx, ToolsStep.Ctx, { phase : ToolsPlan.Phase, keys : List(Str) } => Try(ToolsStep.Done, Fail)
	run! = |fx, ctx, run| {
		chosen = if run.keys.is_empty() ctx.tools else ctx.tools.keep_if(|e| run.keys.contains(e.key))
		if chosen.is_empty() return Ok({ rows: [], changes: [] })
		machine = ToolsStep.machine!(fx)?
		var $found = XCacheIo.entries!(fx, ctx.roots, machine.os)?
		var $gate = Err(NotAsked)
		var $rows = []
		var $changes = []
		for entry in chosen {
			got = one!(fx, ctx, { machine, found: $found, gate: $gate }, { phase: run.phase, entry })?
			$gate = got.gate
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
		Bin(b) => ToolsPlan.file_line({ path, key: b.key, entry: Ok({ ref: b.ref, url: b.url }) })
		Drop(key) => ToolsPlan.file_line({ path, key, entry: Err(Removed) })
	}

	## The `data` rows of `--json` (`ToolsPlan.data`).
	data : Str, List(ToolsStep.Row) -> JsonDoc
	data = |path, rows| {
		json = ToolsStep.json_rows(path, rows)
		with_bins(ToolsPlan.data(json.map(plain)), json)
	}

	## Slice 092 (R-PT23, R-OUT4, Q11 of slice 092, a proposal): `ToolsPlan.with_tools` with the keys `bin`, `binary`, `bin_skip` and `would_check` at the end of each row (after `would_build`).
	with_tools : { base : JsonDoc, rows : List(ToolsStep.JsonRow) } -> JsonDoc
	with_tools = |facts| with_bins(ToolsPlan.with_tools({ base: facts.base, rows: facts.rows.map(plain) }), facts.rows)

	## Slice 073: the rows as the `--json` code wants them. `path` is the `talon.toml` of the run.
	json_rows : Str, List(ToolsStep.Row) -> List(ToolsStep.JsonRow)
	json_rows = |path, rows| rows.map(
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
			bin: row.bin,
			binary: row.binary,
			bin_skip: row.bin_skip,
			would_check: row.would_check,
		},
	)

	## Slice 092: the `bin` of the entry `key` (`Unset`: no `bin` key).
	bin_of : ToolsStep.Ctx, Str -> Try(ToolBin.Lock, [Unset])
	bin_of = |ctx, key| match ctx.bins.find_first(|b| b.key == key) {
		Ok(b) => Ok(b.bin)
		Err(_) => Err(Unset)
	}

	## Slice 092: the `BinView` of a `bin`.
	bin_view : Try(ToolBin.Lock, [Unset]) -> ToolsStep.BinView
	bin_view = |bin| match bin {
		Ok(Off) => Off
		Ok(Hashes(have)) => Targets(have.map(|h| h.target))
		Err(Unset) => Targets([])
	}

	## Slice 092: the facts of `ToolBinFlow` for a run.
	env_of : ToolsStep.Ctx, { os : Setup.Os, target : Str } -> ToolBinFlow.Env
	env_of = |ctx, machine| { roots: ctx.roots, net: ctx.net, now: ctx.now, os: machine.os, target: machine.target, dry_run: ctx.dry_run }

	## Slice 092 (R-PT19, R-PT20, R-PT25): the check for the release `rel` of the entry `key` (`ToolBinFlow.check!`), and what the command writes for `bin` (`ToolBin.write`). `url_changed` is true for a new `url`: all targets are tried, else the targets with no value (`ToolBin.to_check`).
	## `bin` is the `bin` of the entry after the command (for `ensure!` and `--json`).
	locks! : Fx, ToolsStep.Ctx, { machine : { os : Setup.Os, target : Str }, gate : ToolBinFlow.Gate }, { command : ToolBin.Command, key : Str, name : Str, rel : Release, pages : List(Str), url_changed : Bool } => Try({ checked : ToolBinFlow.Checked, write : ToolBin.Write, bin : Try(ToolBin.Lock, [Unset]) }, Fail)
	locks! = |fx, ctx, state, run| {
		old = ToolsStep.bin_of(ctx, run.key)
		allowed = ToolBin.allowed({ machine: ctx.machine_bins, bin: old })
		want = if run.url_changed ToolBin.all_targets else ToolBin.to_check(old)
		checked = ToolBinFlow.check!(fx, ToolsStep.env_of(ctx, state.machine), state.gate, { key: run.key, name: run.name, version: run.rel.version, url: run.rel.url, hash: run.rel.hash, pages: run.pages, want, allowed })?
		write = ToolBin.write({ command: run.command, url_changed: run.url_changed, allowed, old, ran: checked.ran })
		bin = match write {
			Set(list) => Ok(Hashes(list))
			Drop => Err(Unset)
			Keep => old
		}
		Ok({ checked, write, bin })
	}

	## Slice 092: the `bin_skip` text of a check.
	skip_text : Try(ToolBinCheck.Skip, [None]) -> Try(Str, [None])
	skip_text = |skip| match skip {
		Ok(s) => Ok(ToolBinCheck.skip_name(s))
		Err(None) => Err(None)
	}

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
			exclude: ctx.exclude,
			probe_timeout: ctx.probe_timeout,
			name,
			key,
			file: ToolInstall.file_name({ os: machine.os, key }),
			selected: ctx.selected,
		}
	}

	## R-PT4: the list of the releases, the snapshot, the pick and the notes (`ToolFlow.release_list_for!`, `ToolsPlan.visible`, `ToolInstall.pick`, `ToolFlow.notes_for!`). `selector` is `ToolsPlan.selector_for`. No build and no fetch of a bundle.
	pick! : Fx, ToolsStep.Ctx, { machine : { os : Setup.Os, target : Str }, name : Str, selector : Try(Selector, [None]) } => Try({ facts : ToolBuild.Facts, picked : ToolInstall.Picked, newest : Index.Candidate, pages : List(Str) }, Fail)
	pick! = |fx, ctx, run| {
		facts = ToolsStep.facts_of(ctx, run.machine, run.name)
		read = ToolFlow.release_pages_for!(fx, ctx.args, facts)?
		list = read.list
		shown = ToolsPlan.visible({ list, snapshot: ctx.snapshot })
		picked = ToolInstall.pick({ name: run.name, list: shown, selector: run.selector, now: ctx.now, min_age: ctx.min_age, exclude: ctx.exclude })?
		newest = match picked.order.first() {
			Ok(first) => first
			Err(_) => return Err(Fail.new(Internal, "no release was picked"))
		}
		ToolFlow.notes_for!(fx, ctx.args, facts, picked, newest)
		Ok({ facts, picked, newest, pages: read.pages })
	}

	## R-PT10 (as `tln tool install`), R-PT9: the release that a pick gives: the newest candidate when its build is in the `x` cache (no fetch) or with `--dry-run` (no fetch), else the first candidate whose bundle is an app (`ToolFlow.first_app_for!`: the fetch of the bundles). `bundle` is `Err(Read)` for the first case.
	chosen! : Fx, ToolsStep.Ctx, { pick : { facts : ToolBuild.Facts, picked : ToolInstall.Picked, newest : Index.Candidate, pages : List(Str) }, found : List(XCache.Found) } => Try({ rel : Release, bundle : Try(ToolBuild.Bundle, [Read]) }, Fail)
	chosen! = |fx, ctx, run| {
		newest = run.pick.newest
		release = { version: newest.ident.version, url: newest.url, hash: newest.ident.hash }
		hit = ToolsPlan.cached({ entries: ToolBinFlow.source_only(run.found), bundle: release.hash, target: run.pick.facts.target })
		if hit.is_ok() or ctx.dry_run {
			return Ok({ rel: release, bundle: Err(Read) })
		}
		bundle = ToolFlow.first_app_for!(fx, ctx.args, run.pick.facts, run.pick.picked.order)?
		Ok({ rel: { version: bundle.version, url: bundle.url, hash: bundle.hash }, bundle: Ok(bundle) })
	}

	## R-PT6, R-PT15, R-PT16: the `x` entry of a release. A hit of `ToolsPlan.cached` is done (no fetch, no build). Else the bundle (read when `bundle` is `Err`), the platform, the compiler, the build and the entry. A build that does not pass is the failure of `ToolInstall.build_failed` (nothing is written).
	## Slice 093 (R-PT9, R-PT21, R-PT22): step 1 is `ToolBinFlow.hit` (a prebuilt entry with the `bin` value wins, Q237). Step 2: `ToolBinUse.use` gives `Download`: `ToolBinFlow.use!` (exit 16 stops; a download error is the warning and the build). `key` is the key of `[tools]`, `bin` the `bin` of the entry.
	ensure! : Fx, ToolsStep.Ctx, { key : Str, facts : ToolBuild.Facts, rel : Release, bundle : Try(ToolBuild.Bundle, [Read]), found : List(XCache.Found), bin : Try(ToolBin.Lock, [Unset]) } => Try({ built : Bool, would : Bool, added : List(XCache.Found), binary : ToolsStep.Got }, Fail)
	ensure! = |fx, ctx, run| {
		facts = run.facts
		none = { built: Bool.False, would: Bool.False, added: [], binary: NoBinary }
		if ToolBinFlow.hit({ found: run.found, bundle: run.rel.hash, target: facts.target, bin: run.bin, machine: ctx.machine_bins }).is_ok() {
			return Ok(none)
		}
		if ctx.dry_run return Ok({ ..none, would: Bool.True })
		match ToolBinUse.use({ machine: ctx.machine_bins, bin: run.bin, target: facts.target, offline: ctx.args.offline }) {
			Download(sha256) => match ToolBinFlow.use!(fx, ToolsStep.env_of(ctx, { os: facts.os, target: facts.target }), { key: run.key, name: facts.name, version: run.rel.version, url: run.rel.url, hash: run.rel.hash, sha256 })? {
				Ok(made) => return Ok({ ..none, added: [made], binary: Prebuilt })
				Err(Failed) => {}
			}
			Build => {}
		}
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
				Ok({ built: Bool.True, would: Bool.False, added: [written?.found], binary: Built })
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
	Bin(b) => b.key
	Drop(key) => key
}

# One change on a text of `talon.toml`. A `Put` with a `bin` table writes the table after the entry (R-PT19: the same write as the `url`).
apply : Str, Str, ToolsStep.Change -> Try(Str, Fail)
apply = |path, text, change| match change {
	Put(p) => {
		put = ToolsToml.put({ path, text, key: p.key, ref: p.ref, url: p.url })?
		match p.bin {
			Ok(bin) => ToolsToml.put_bin({ path, text: put, key: p.key, bin })
			Err(None) => Ok(put)
		}
	}
	Bin(b) => ToolsToml.put_bin({ path, text, key: b.key, bin: b.bin })
	Drop(key) => ToolsToml.drop({ path, text, keys: [key] })
}

# Slice 073, 092: a row as `ToolsPlan.data` takes it (no `bin` fields).
plain : ToolsStep.JsonRow -> { key : Str, name : Str, action : Str, ref : Try(Str, [None]), url : Try(Str, [None]), version : Try(Str, [None]), previous : Try(Str, [None]), file : Str, built : Bool, would_build : Bool }
plain = |r| { key: r.key, name: r.name, action: r.action, ref: r.ref, url: r.url, version: r.version, previous: r.previous, file: r.file, built: r.built, would_build: r.would_build }

# Slice 092 (Q11 of slice 092): the keys `bin`, `binary`, `bin_skip`, `would_check` at the end of each row of `tools` of an object.
with_bins : JsonDoc, List(ToolsStep.JsonRow) -> JsonDoc
with_bins = |doc, rows| match doc {
	Obj(pairs) => Obj(
		pairs.map(
			|(k, v)| match (k, v) {
				("tools", Arr(items)) => (k, Arr(items.map2(rows, |item, row| extra(item, row))))
				_ => (k, v)
			},
		),
	)
	other => other
}

extra : JsonDoc, ToolsStep.JsonRow -> JsonDoc
extra = |item, row| match item {
	Obj(fields) => {
		bin = match row.bin {
			Off => Flag(Bool.False)
			Targets(names) => Arr(names.map(|n| Text(n)))
		}
		binary = match row.binary {
			Prebuilt => Text("prebuilt")
			Built => Text("built")
			NoBinary => Null
		}
		skip = match row.bin_skip {
			Ok(name) => Text(name)
			Err(None) => Null
		}
		Obj(fields.concat([("bin", bin), ("binary", binary), ("bin_skip", skip), ("would_check", Arr(row.would_check.map(|n| Text(n))))]))
	}
	other => other
}

# What one entry did in a phase.
One : { row : ToolsStep.Row, change : Try(ToolsStep.Change, [None]), added : List(XCache.Found), gate : ToolBinFlow.Gate }

# What the entries of a run share: the machine, the `x` entries that are there now, and the state of `gh` (R-PT20 step 2: once for the command).
State : { machine : { os : Setup.Os, target : Str }, found : List(XCache.Found), gate : ToolBinFlow.Gate }

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

# R-PT19: the command of a phase that writes a `url`.
command_of : ToolsPlan.Phase -> ToolBin.Command
command_of = |phase| match phase {
	Update => Update
	Upgrade => Upgrade
	Install => InstallNoUrl
	Frozen => Frozen
}

# The release of the pick: a `url` that is the newest one stays, else the tool moves to it (`Moved`), or is locked when it had no `url`.
moved! : Fx, ToolsStep.Ctx, State, { phase : ToolsPlan.Phase, entry : ToolsToml.Entry } => Try(One, Fail)
moved! = |fx, ctx, state, run| {
	entry = run.entry
	name = ToolsToml.app_of(entry.ref)
	selector = ToolsPlan.selector_for({ phase: run.phase, ref: entry.ref })
	picked = ToolsStep.pick!(fx, ctx, { machine: state.machine, name, selector })?
	command = command_of(run.phase)
	if entry.url == Ok(picked.newest.url) {
		return stays!(fx, ctx, state, { entry, name, command, pages: picked.pages })
	}
	# R-UP5: `upgrade` moves the range of the `ref` to the new version. A range with no form is a note and the tool stays.
	ref = match run.phase {
		Upgrade => match ToolsPlan.upgrade_ref({ ref: entry.ref, version: picked.newest.ident.version }) {
			Ok(moved) => moved
			Err(NoForm) => {
				fx.err!("note: ${ToolsPlan.stuck_note({ key: entry.key, ref: entry.ref, version: picked.newest.ident.version })}\n")
				return stays!(fx, ctx, state, { entry, name, command, pages: picked.pages })
			}
		}
		_ => entry.ref
	}
	chosen = ToolsStep.chosen!(fx, ctx, { pick: picked, found: state.found })?
	locked = ToolsStep.locks!(fx, ctx, { machine: state.machine, gate: state.gate }, { command, key: entry.key, name, rel: chosen.rel, pages: picked.pages, url_changed: Bool.True })?
	ensured = ToolsStep.ensure!(fx, ctx, { key: entry.key, facts: picked.facts, rel: chosen.rel, bundle: chosen.bundle, found: state.found.concat(locked.checked.added), bin: locked.bin })?
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
		bin: ToolsStep.bin_view(locked.bin),
		binary: if locked.checked.added.is_empty() ensured.binary else Prebuilt,
		bin_skip: ToolsStep.skip_text(locked.checked.skip),
		would_check: locked.checked.would_check,
	}
	bin = match locked.write {
		Set(list) => Ok(list)
		_ => Err(None)
	}
	Ok({ row, change: Ok(Put({ key: entry.key, ref, url: chosen.rel.url, bin })), added: locked.checked.added.concat(ensured.added), gate: locked.checked.gate })
}

# R-PT19: a `url` that stays: the check of the targets with no value in `bin`, and the values that pass are added (`Bin`). Nothing else changes.
stays! : Fx, ToolsStep.Ctx, State, { entry : ToolsToml.Entry, name : Str, command : ToolBin.Command, pages : List(Str) } => Try(One, Fail)
stays! = |fx, ctx, state, run| {
	entry = run.entry
	old = ToolsStep.bin_of(ctx, entry.key)
	kept = { key: entry.key, name: run.name, action: Kept, ref: Ok(entry.ref), url: entry.url.map_err(|_| None), version: Err(None), previous: Err(None), built: Bool.False, would_build: Bool.False, bin: ToolsStep.bin_view(old), binary: NoBinary, bin_skip: Err(None), would_check: [] }
	(url, ident) = match entry.url {
		Ok(u) => match Ident.of_url(u) {
			Ok(i) => (u, i)
			Err(Foreign) => return Ok({ row: kept, change: Err(None), added: [], gate: state.gate })
		}
		Err(Unset) => return Ok({ row: kept, change: Err(None), added: [], gate: state.gate })
	}
	locked = ToolsStep.locks!(fx, ctx, { machine: state.machine, gate: state.gate }, { command: run.command, key: entry.key, name: run.name, rel: { version: ident.version, url, hash: ident.hash }, pages: run.pages, url_changed: Bool.False })?
	change = match locked.write {
		Set(list) => Ok(Bin({ key: entry.key, ref: entry.ref, url, bin: list }))
		_ => Err(None)
	}
	row = { ..kept, bin: ToolsStep.bin_view(locked.bin), binary: if locked.checked.added.is_empty() NoBinary else Prebuilt, bin_skip: ToolsStep.skip_text(locked.checked.skip), would_check: locked.checked.would_check }
	Ok({ row, change, added: locked.checked.added, gate: locked.checked.gate })
}

# R-PT6, R-PT9: an entry with a `url` needs its build only: it is made when the `x` cache has none for the bundle of the `url` (no release list, no change of `talon.toml`). Slice 093: a prebuilt binary of `bin` first (R-PT21). `bin` is never written (R-PT19).
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
	bin = ToolsStep.bin_of(ctx, entry.key)
	ensured = ToolsStep.ensure!(fx, ctx, { key: entry.key, facts, rel: { version: ident.version, url, hash: ident.hash }, bundle: Err(Read), found: state.found, bin })?
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
		bin: ToolsStep.bin_view(bin),
		binary: ensured.binary,
		bin_skip: Err(None),
		would_check: [],
	}
	Ok({ row, change: Err(None), added: ensured.added, gate: state.gate })
}
