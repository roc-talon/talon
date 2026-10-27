import Args
import Answer
import Clock
import Common
import Fail
import Fetch
import Fx
import Index
import Item
import Lookup
import Mode
import Prompt
import Roots
import Scope
import Temp
import Text
import ToolBuild
import ToolFlow
import ToolInstall
import ToolsJson
import XCache
import XCacheIo
import XCmd
import XProject

## The command `tln x owner/app [-- args]` (slice 049, CLI 6.4: R-CM12, R-X1 to R-X5, R-B1 to R-B3, R-B5, R-B7 to R-B10, R-NI9, R-FL1, R-E1, R-SC4, R-AD7, R-C6). Direct style over `Fx` (TESTING.md 2.2 part C): `XCmd` and `XCache` decide, this module orders the calls. It builds as `tln tool install`
## does (the pieces of `ToolFlow` and `ToolBuild`), but writes an `x` cache entry (R-X2) and runs the binary (R-X4). `Run.run!` calls `run!` for the command `["x"]`. The calls, in order (the L2 cases `x/x1-run` and `x/x2-offline` and the L3 case `tools/x1-run` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `XCmd.read(args)`. A failure is printed with `Common.failed!` (no `Fx` call). | R-CM12, R-FL1 |
## | 1b | `XProject.run!` (slice 059, R-PT11): a project tool runs here. `Miss` (a selector, no `talon.toml`, no entry for the operand) goes on with step 2. | R-PT11, R-PT12 |
## | 2 | `ToolFlow.machine_for!` (the steps 2 and 3 of `ToolFlow`: `args`, `env_all`, `clock`, `platform`, `tools.json`, `config.toml`), then `XCacheIo.entries!`. | R-LY2, R-X2 |
## | 3 | `Lookup.find` with the scope `X` and `XCache.entities` (the installed tools and the entries). A short name with no match: its failure (R-AD7, R-NM11), exit 2. A full name: itself. The binary name is the repo name (`Text.last_segment`). | R-SC4, R-AD7 |
## | 4 | With no `--offline`: `ToolFlow.release_list_for!` (the calls of step 6 of `ToolFlow`). A failure of the kind `Network` (no network) is the offline case of step 7, any other failure ends the command. | R-B3, R-B7 |
## | 5 online | `ToolInstall.pick`, the installed tool of the name (`ToolsJson.manifest` of step 2), `XCache.choose` with `Online`. `Installed(tool)`: step 8. `Cached(hit)`: `XCacheIo.touch!`, then step 8. `NoMatch`: step 6. For a build that is used: `note: <XCmd.no_data>`, then `XCmd.available` when it is older than the newest candidate. | R-B1 to R-B3, R-B5, R-C6 |
## | 6 | A build: `ToolFlow.notes_for!`, `ToolFlow.first_app_for!`, `ToolFlow.platform_for!`, `ToolFlow.choose_for!` (the compiler choice and the consent of slice 047, R-X1), `ToolBuild.built!` (the build, R-SE8: the platform line and the `building` line on stderr), `random!`, `XCacheIo.write!`, `delete!` of the temp dir of the build (also after a failure, R-CC2). No `ToolBuild.entry_verdict!`, no lock, no `tools.json`, no bin dir. | R-X1, R-X2, R-X3, R-CC11 |
## | 7 offline | (`--offline`, or step 4 gave the failure `Network`). `XCache.choose` with `Offline`. `Installed(tool)`: `note: <XCmd.offline_installed>`, step 8, no prompt (R-B8). `Cached(hit)`: `Prompt.ask!` with `XCmd.unchecked_prompt` (`Run`): `flag` `Ok(Yes)` for `--allow-unchecked`, `yes` is `--yes`; `No`: `XCmd.declined`; `Yes`: `XCacheIo.touch!`, step 8. `NoMatch`: the failure of step 4, or `XCmd.offline_no_build` for `--offline`. | R-B7, R-B8, R-NI9 |
## | 8 | `exec!` of `[<binary>] ++ <the words after -->` with no more variables. `Ok(code)`: the exit code of the run is `code`. `Err(NotStarted(text))`: `XCmd.start_failed`. The binary is `<data bin>/<key>` of the installed tool (R-B5: in place, no copy) or `<entry dir>/<file>`. | R-X3, R-X4, R-E1, R-HF6 |
XFlow :: [].{

	## Steps 1 to 8.
	run! : Fx, Args => I32
	run! = |fx, args| match XCmd.read(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(plan) => match XProject.run!(fx, args, plan) {
			Ok(Ok(code)) => code
			Err(fail) => Common.failed!(fx, args, fail)
			Ok(Err(Miss)) => match flow!(fx, args, plan) {
				Ok(code) => code
				Err(fail) => Common.failed!(fx, args, fail)
			}
		}
	}
}

# Steps 2 to 8.
flow! : Fx, Args, XCmd.Plan => Try(I32, Fail)
flow! = |fx, args, plan| {
	machine = ToolFlow.machine_for!(fx)?
	found = XCacheIo.entries!(fx, machine.roots, machine.os)?
	name = full_name!(fx, plan, machine, found)?
	key = Text.last_segment(name)
	facts = {
		env: machine.env,
		roots: machine.roots,
		net: machine.net,
		now: machine.now,
		os: machine.os,
		bin: machine.bin,
		target: machine.target,
		entries: machine.tools.map(|t| { key: t.key, name: t.name, source: t.source }),
		min_age: machine.min_age,
		exclude: machine.exclude,
		probe_timeout: machine.probe_timeout,
		name,
		key,
		file: ToolInstall.file_name({ os: machine.os, key }),
		selected: Fetch.selected({ held: "", default: machine.default_roc }),
	}
	installed = match machine.tools.find_first(|t| t.name == name) {
		Ok(tool) => Ok(tool)
		Err(_) => Err(None)
	}
	known = { facts, installed, found }
	if args.offline {
		return offline!(fx, args, plan, { known, why: Err(None) })
	}
	list = match ToolFlow.release_list_for!(fx, args, facts) {
		Ok(got) => got
		Err(fail) => match fail.kind {
			Network => return offline!(fx, args, plan, { known, why: Ok(fail) })
			_ => return Err(fail)
		}
	}
	picked = ToolInstall.pick({ name, list, selector: plan.ref.selector, now: facts.now, min_age: facts.min_age, exclude: facts.exclude })?
	newest = newest_of(picked)?
	check = Online({ first: newest.ident.version, listed: list.map(|c| c.ident.version) })
	match XCache.choose({ name, target: facts.target, selector: plan.ref.selector, check, installed, entries: found }) {
		Installed(tool) => {
			note_reuse!(fx, { via: RunInstalled, key: tool.key, name, have: ToolsJson.source_text(tool.source), newest: newest.ident.version })
			run_binary!(fx, plan, installed_bin(facts, tool))
		}
		Cached(hit) => {
			note_reuse!(fx, { via: RunCached, key, name, have: ToolsJson.source_text(hit.entry.source), newest: newest.ident.version })
			XCacheIo.touch!(fx, hit, Clock.format_utc(facts.now))?
			run_binary!(fx, plan, XCacheIo.bin_of({ found: hit, os: facts.os }))
		}
		NoMatch => {
			stale = found.keep_if(|f| !f.has_bin).map(|f| f.dir)
			bin = build!(fx, args, plan, { facts, picked, newest, stale })?
			run_binary!(fx, plan, bin)
		}
	}
}

# Step 7 (R-B7, R-B8, R-NI9): no check online (`--offline`, or no network). An installed tool runs with a note and no prompt. An entry needs the prompt. No match: the failure of the list, or `XCmd.offline_no_build` for `--offline`.
offline! : Fx, Args, XCmd.Plan, { known : { facts : ToolBuild.Facts, installed : Try(ToolsJson.Tool, [None]), found : List(XCache.Found) }, why : Try(Fail, [None]) } => Try(I32, Fail)
offline! = |fx, args, plan, run| {
	facts = run.known.facts
	choice = XCache.choose({ name: facts.name, target: facts.target, selector: plan.ref.selector, check: Offline, installed: run.known.installed, entries: run.known.found })
	match choice {
		Installed(tool) => {
			fx.err!("note: ${XCmd.offline_installed({ key: tool.key, version: ToolsJson.source_text(tool.source) })}\n")
			run_binary!(fx, plan, installed_bin(facts, tool))
		}
		Cached(hit) => {
			version = ToolsJson.source_text(hit.entry.source)
			key = Text.last_segment(facts.name)
			prompt = XCmd.unchecked_prompt({ via: Run, key, version })
			mode = Mode.from_env({ env: Dict.from_list(facts.env), json: Bool.False })
			asked = Prompt.ask!(fx, prompt, { mode, yes: args.yes, quiet: args.quiet, flag: if plan.unchecked Ok(Yes) else Err(NoFlag) })?
			match asked.answer {
				Yes => {
					XCacheIo.touch!(fx, hit, Clock.format_utc(facts.now))?
					run_binary!(fx, plan, XCacheIo.bin_of({ found: hit, os: facts.os }))
				}
				_ => Err(XCmd.declined({ via: Run, key, version }))
			}
		}
		NoMatch => match run.why {
			Ok(fail) => Err(fail)
			Err(None) => Err(XCmd.offline_no_build(facts.name))
		}
	}
}

# Step 5 (R-C6, R-B3): the note for a build that is used, and the line when it is older than the newest release.
note_reuse! : Fx, { via : [TakeOver, RunCached, RunInstalled], key : Str, name : Str, have : Str, newest : Str } => {}
note_reuse! = |fx, run| {
	fx.err!("note: ${XCmd.no_data}\n")
	if XCache.is_older({ have: run.have, newest: run.newest }) {
		fx.err!("${XCmd.available(run)}\n")
	}
}

# The binary of an installed tool, in place (R-B5): `<data>/bin/<file>`.
installed_bin : ToolBuild.Facts, ToolsJson.Tool -> Str
installed_bin = |facts, tool| Text.join(Roots.item(facts.roots, Item.Bin), ToolInstall.file_name({ os: facts.os, key: tool.key }))

# Step 3 (R-SC4, R-AD7, R-NM11): an installed tool or an entry by its name or short name, else the name as typed. A failure prints its block first.
full_name! : Fx, XCmd.Plan, ToolFlow.Machine, List(XCache.Found) => Try(Str, Fail)
full_name! = |fx, plan, machine, found| {
	tools = machine.tools.map(|t| { key: t.key, name: t.name, source: t.source })
	match Lookup.find(Scope.X, plan.ref, XCache.entities({ tools, entries: found })) {
		Ok(Lookup.Existing(hit)) => Ok(hit.name)
		Ok(Lookup.New(typed)) => Ok(typed)
		Err({ fail, block }) => {
			if !block.is_empty() fx.err!(block)
			Err(fail)
		}
	}
}

# The first candidate of `ToolInstall.pick`.
newest_of : ToolInstall.Picked -> Try(Index.Candidate, Fail)
newest_of = |picked| match picked.order.first() {
	Ok(first) => Ok(first)
	Err(_) => Err(Fail.new(Internal, "no release was picked"))
}

# Step 6 (R-X1 to R-X3, R-CC2, R-CC11): the notes, the first app bundle, the platform, the compiler, the build, then the entry. No lock, no `tools.json`, no bin dir. The temp dir of the build goes also after a failure. The result is the binary of the new entry.
build! : Fx, Args, XCmd.Plan, { facts : ToolBuild.Facts, picked : ToolInstall.Picked, newest : Index.Candidate, stale : List(Str) } => Try(Str, Fail)
build! = |fx, args, plan, run| {
	facts = run.facts
	ToolFlow.notes_for!(fx, args, facts, run.picked, run.newest)
	bundle = ToolFlow.first_app_for!(fx, args, facts, run.picked.order)?
	ToolFlow.platform_for!(fx, args, facts, bundle)?
	chosen = ToolFlow.choose_for!(fx, args, { roc: plan.roc }, facts, bundle)?
	attempt = ToolBuild.built!(fx, args, facts, bundle, chosen)?
	match attempt.class {
		Pass => {
			entry = { name: facts.name, source: bundle.source, hashes: bundle.hashes, nightly: chosen.id, target: facts.target, sha256: "", libs: [], bundle: bundle.hash, last_run: Clock.format_utc(facts.now) }
			written = XCacheIo.write!(fx, facts.roots, { entry, output: attempt.layout.output, os: facts.os, hex: Temp.hex(fx.random!()), stale: run.stale })
			_ = fx.delete!([attempt.layout.temp])
			Ok(written?.bin)
		}
		class => Err(ToolInstall.build_failed({ name: facts.name, version: bundle.version, id: chosen.id, class, errors: attempt.errors, output: attempt.layout.output }))
	}
}

# Step 8 (R-X3, R-X4, R-E1, R-HF6): the binary runs with the words after `--` and no more variables. The exit code of the run is the exit code of the app.
run_binary! : Fx, XCmd.Plan, Str => Try(I32, Fail)
run_binary! = |fx, plan, bin| match fx.exec!({ argv: [bin].concat(plan.args), env: [] }) {
	Ok(code) => Ok(code)
	Err(NotStarted(text)) => Err(XCmd.start_failed({ program: bin, text }))
}
