import Args
import Clock
import Del
import DelFlow
import Fail
import Fx
import Index
import Item
import Mode
import Prompt
import Roots
import Selector
import SetupIo
import Temp
import Text
import ToolBuild
import ToolInstall
import ToolsHeld
import ToolsJson
import XCache
import XCacheIo
import XCmd

## The take-over of an `x` cache entry by `tln tool install` (slice 049, CLI 6.4: R-B1 to R-B4, R-B7, R-B10, R-NI9, R-CC6, R-ST6, R-ST7, R-ST9, R-T3, R-T26, R-PT13). Command code over `Fx`. `XCache` decides, `XCacheIo` reads the entries.
## `ToolFlow.flow!` calls `online!` after the answer `Build` of `ToolInstall.reuse` (step 7), and `offline!` at its start (with `--offline`) and after a release list that failed with the kind `Network` (no network). The calls, in order (the L2 case `tool/tk1-takeover` fixes them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `XCacheIo.entries!` (the calls of its doc table). | R-B9 |
## | 2 | `XCache.choose` with `installed` `Err(None)` (an installed tool of the same name was decided before: `ToolInstall.reuse`), the target of the machine, and `check`: `Online({ first: <the version of the newest candidate of pick>, listed: <the versions of all candidates> })` for `online!`, `Offline` for `offline!`. `NoMatch`: the result is `Err(NoMatch)` and the flow goes on as before. | R-B1, R-B2, R-B3, R-B10 |
## | 3 online | `Cached(hit)`: on stderr `note: <XCmd.no_data>` (R-C6), then, when `XCache.is_older` of the version of `hit` and the newest candidate, `XCmd.available` with `via` `TakeOver`. | R-B3, R-C6 |
## | 3 offline | `Cached(hit)`: `Mode.from_env`, `Prompt.ask!` with `XCmd.unchecked_prompt` (`TakeOver`): `flag` `Ok(Yes)` for `--allow-unchecked`, `yes` is `--yes`. The prompt is asked before the lock (R-CC3 point 5). `No`: `XCmd.declined`. With no person and no answer: exit 13 (`Prompt.decide`). | R-B7, R-NI9, R-NM5 |
## | 4 | `take!`: `ToolBuild.entry_verdict!` (R-ST6: the bin dir entry before the move, as before the download of a build), one `random!`, `ToolInstall.layout`, then under the lock of `tools.json` (`Fx.locked!`, `Wait`, R-CC6) the steps of the table below. | R-B4, R-ST6 |
##
## `take!` under the lock:
##
## | # | Does | Rule |
## | --- | --- | --- |
## | 1 | `read_files!` of `tools.json`, `ToolsJson.read`, `ToolsJson.clash` again (`Taken`, `Elsewhere`: the failures of `ToolInstall`; `Same(old)`: `Replaced`; `Free`: `Installed`), `ToolBuild.entry_read!` again (the calls of `entry_verdict!`, with the data file and the entry that it read). | R-CC6, R-T28, R-ST6 |
## | 2 | `sha256_file!` of the binary of the entry. It must be the `sha256` of the manifest, else a failure of kind `Integrity` (exit 16, nothing changed; question Q-T3: the design does not say what follows). The check is before the move, so a bad file never replaces an installed binary. Then `ToolsHeld.all!` and `XCache.take_how`. Windows (slice 050d, R-ST10): `DelFlow.rename_away!` of the files that `Del.replaced` gives for the data file and the entry that exist (one `random!`, one `rename!` of each to its `.del` name; no call for a first install). | R-B4, R-ST10 |
## | 3 | `make_dirs!` of the data bin dir and the bin dir. `XCache.take_how` (`project_uses` is `Bool.False` until slice 056). `Move`: `rename!` of the binary to `layout.data_tmp`; when it fails, `copy_file!` to the same name. `Copy`: `copy_file!`. Then `rename!` of `data_tmp` to `layout.data_file`. A failed copy: `SetupIo.dropped!`. | R-B4, R-T3, R-CC1 |
## | 4 | `ToolBuild.link_entry!` (the bin dir entry, R-ST7), then `ToolsJson.put` with the tool of the manifest (`installed_at` is the time of Talon) and `write_atomic!` of `tools.json`. | R-ST7, R-ST9, R-T4 |
## | 5 | `Move`: one `delete!` of the entry dir (also after a copy that replaced a failed `rename`). `Copy`: nothing (R-PT13). | R-B4 |
XTake :: [].{

	## What a take-over gives. `Err(NoMatch)`: no entry matches.
	Taken : Try(ToolBuild.Done, [NoMatch])

	## Steps 1 to 4 online. `list` are the candidates of the release list, `newest` is the first candidate of `ToolInstall.pick`.
	online! : Fx, Args, { facts : ToolBuild.Facts, selector : Try(Selector, [None]), list : List(Index.Candidate), newest : Index.Candidate } => Try(Taken, Fail)
	online! = |fx, _args, run| {
		facts = run.facts
		found = XCacheIo.entries!(fx, facts.roots, facts.os)?
		check = Online({ first: run.newest.ident.version, listed: run.list.map(|c| c.ident.version) })
		match XCache.choose({ name: facts.name, target: facts.target, selector: run.selector, check, installed: Err(None), entries: found }) {
			Cached(hit) => {
				version = ToolsJson.source_text(hit.entry.source)
				fx.err!("note: ${XCmd.no_data}\n")
				if XCache.is_older({ have: version, newest: run.newest.ident.version }) {
					fx.err!("${XCmd.available({ via: TakeOver, key: facts.key, name: facts.name, have: version, newest: run.newest.ident.version })}\n")
				}
				Ok(Ok(take!(fx, facts, hit)?))
			}
			_ => Ok(Err(NoMatch))
		}
	}

	## Steps 1 to 4 offline (R-B7): no resolve and no check. `offline!` asks the prompt R-NI9 for a matching entry.
	offline! : Fx, Args, { facts : ToolBuild.Facts, selector : Try(Selector, [None]) } => Try(Taken, Fail)
	offline! = |fx, args, run| {
		facts = run.facts
		found = XCacheIo.entries!(fx, facts.roots, facts.os)?
		match XCache.choose({ name: facts.name, target: facts.target, selector: run.selector, check: Offline, installed: Err(None), entries: found }) {
			Cached(hit) => {
				version = ToolsJson.source_text(hit.entry.source)
				prompt = XCmd.unchecked_prompt({ via: TakeOver, key: facts.key, version })
				mode = Mode.from_env({ env: Dict.from_list(facts.env), json: Bool.False })
				flag = if args.options.any(|(name, _)| name == "--allow-unchecked") Ok(Yes) else Err(NoFlag)
				asked = Prompt.ask!(fx, prompt, { mode, yes: args.yes, quiet: args.quiet, flag })?
				match asked.answer {
					Yes => Ok(Ok(take!(fx, facts, hit)?))
					_ => Err(XCmd.declined({ via: TakeOver, key: facts.key, version }))
				}
			}
			_ => Ok(Err(NoMatch))
		}
	}
}

# Step 4: the check of the bin dir entry, then the steps under the lock of `tools.json`.
take! : Fx, ToolBuild.Facts, XCache.Found => Try(ToolBuild.Done, Fail)
take! = |fx, facts, hit| {
	ToolBuild.entry_verdict!(fx, facts)?
	hex = Temp.hex(fx.random!())
	layout = ToolInstall.layout({ roots: facts.roots, bin: facts.bin, os: facts.os, key: facts.key, hash: hit.entry.bundle, hex })
	fx.locked!(Roots.item(facts.roots, Item.ToolsJson), || taken!(fx, { facts, hit, layout }))
}

# Steps 1 to 5 under the lock (D4: the sha256 check is before the move).
taken! : Fx, { facts : ToolBuild.Facts, hit : XCache.Found, layout : ToolInstall.Layout } => Try(ToolBuild.Done, Fail)
taken! = |fx, run| {
	facts = run.facts
	entry = run.hit.entry
	tools_file = Roots.item(facts.roots, Item.ToolsJson)
	text = SetupIo.read_text!(fx, tools_file)?
	tools = ToolsJson.read({ path: tools_file, text })?
	how = match ToolsJson.clash({ entries: tools, key: facts.key, name: facts.name }) {
		Taken(other) => return Err(ToolInstall.clash_failure({ key: facts.key, taken: other.name, name: facts.name }))
		Elsewhere(other) => return Err(ToolInstall.elsewhere_failure({ key: other.key, name: facts.name }))
		Same(old) => Replaced(ToolsJson.source_text(old.source))
		Free => Installed
	}
	read = ToolBuild.entry_read!(fx, facts)?
	match read.verdict {
		Make => {}
		Foreign => return Err(ToolInstall.foreign_failure(Text.join(facts.bin, facts.file)))
	}
	binary = XCacheIo.bin_of({ found: run.hit, os: facts.os })
	match fx.sha256_file!(binary) {
		Ok(sha) if sha == entry.sha256 => {}
		Ok(_) => return Err(Fail.new(Integrity, "${binary} does not match the sha256 of its manifest (${entry.sha256}). tln did not install it."))
		Err(err) => return Err(Fail.new(Environment, "cannot read ${binary}: ${Str.inspect(err)}"))
	}
	held = ToolsHeld.all!(fx, facts.roots)?
	how_to = XCache.take_how({ project_uses: held.contains(entry.bundle) })
	# Slice 050d (R-ST10): on Windows the files of an installed tool of the same name go to `.del` names, so the new files can go in.
	_ = DelFlow.rename_away!(fx, { os: facts.os, files: Del.replaced({ data_file: run.layout.data_file, entry: run.layout.entry, old: read.old, have: read.have }) })?
	place!(fx, run.layout, { binary, how: how_to })?
	_ = ToolBuild.link_entry!(fx, run.layout)?
	tool = {
		key: facts.key,
		name: facts.name,
		source: entry.source,
		path: Err(None),
		hashes: entry.hashes,
		nightly: entry.nightly,
		target: entry.target,
		sha256: entry.sha256,
		libs: entry.libs,
		installed_at: Clock.format_utc(facts.now),
	}
	SetupIo.write_file!(fx, tools_file, ToolsJson.put({ path: tools_file, text, tool })?)?
	match how_to {
		Move => {
			_ = fx.delete!([run.hit.dir])
		}
		Copy => {}
	}
	Ok({ how, key: facts.key, name: facts.name, version: ToolsJson.source_text(entry.source), bin: run.layout.entry, built: Err(None) })
}

# Step 3 (R-B4, R-T3, R-CC1): the binary goes to a temp name in the data bin dir, then a rename. `Move`: a `rename`, and a copy when the `rename` fails. `Copy`: a copy.
place! : Fx, ToolInstall.Layout, { binary : Str, how : [Move, Copy] } => Try({}, Fail)
place! = |fx, lay, run| {
	match fx.make_dirs!([lay.data_bin, lay.bin]) {
		Ok(_) => {}
		Err(err) => return Err(Fail.new(Environment, "cannot make ${lay.data_bin}: ${Str.inspect(err)}"))
	}
	moved = match run.how {
		Move => fx.rename!({ from: run.binary, to: lay.data_tmp }).is_ok()
		Copy => Bool.False
	}
	if !moved {
		match fx.copy_file!({ from: run.binary, to: lay.data_tmp }) {
			Ok(_) => {}
			Err(err) => return Err(SetupIo.dropped!(fx, lay.data_tmp, "cannot copy ${run.binary} to ${lay.data_tmp}: ${Str.inspect(err)}"))
		}
	}
	match fx.rename!({ from: lay.data_tmp, to: lay.data_file }) {
		Ok(_) => Ok({})
		Err(err) => Err(SetupIo.dropped!(fx, lay.data_tmp, "cannot make ${lay.data_file}: ${Str.inspect(err)}"))
	}
}
