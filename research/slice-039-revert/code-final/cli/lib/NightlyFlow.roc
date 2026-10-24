import Compiler
import Consent
import DownloadAsk
import Fail
import Fx
import Launch
import Nightlies
import NightlyPlan
import Pin
import Prompt
import ResolveBase
import RocInstall
import Toolchain
import Vars

## Command code (TESTING.md 2.2, part C) of the free nightly of `tln upgrade` (slice 039: R-SP8, R-SP9, R-SP12, R-UP6, R-BL3, R-NI12, R-DL1, R-DL3 to R-DL5, R-NI5). `InstallFlow.resolve!` calls `plan!` after the pin of the header is known and before the oracle loop.
## The calls, in order (the L2 cases `upgrade/ur1-roc` and `upgrade/ur2-consent` fix them):
##
## | Step | Call | Rule |
## | --- | --- | --- |
## | 1 | `fx.platform!`, `Toolchain.host`, `Nightlies.list!` (the cache of the list, R-DI2, then `compat.db`, slice 030b). A list that cannot be read (the failure of `Nightlies.list!`, or `Toolchain.offline_no_list` for `--offline` with no cached page) is the failure of the command when the name `roc` is given. With no names the nightly stays H: `Plan.free` is `Err(Held)`, `Plan.note` is `the compiler list could not be read; roc stays <H>` (Q1 answer, TW24 text), and the packages upgrade as usual. `Toolchain.range_failed` (exit 10) when no compiler is allowed (R-NS2) | R-UP6, R-NS2, R-DI12 |
## | 2 | `Launch.toolchains!` (one `list_dirs!` of `<cache>/toolchains`), `NightlyPlan.pick` | R-SP12, R-C7, R-UP1 |
## | 3 | The downloads that the command needs: the newest compiler N (it names it, R-UP6) when it is not installed, and the compiler H that the header holds when it is not installed (the baseline, R-BL3). `RocInstall.offer!` for each, N first | R-UP6, R-BL3 |
## | 4 | One prompt for the run (R-DL1), the table below. Then `RocInstall.install_offer!` for each download, N first | R-NI12, R-NI5, R-DL1 |
##
## The prompt (U5, reading (c): it asks for the required downloads only. A compiler that is not N and is not installed is not askable: no download, no question):
##
## | N | H | Prompt | Rule |
## | --- | --- | --- | --- |
## | installed | installed | none | |
## | missing | installed | `Consent.roc_install` (default Yes, the command names the download). No person: no prompt, the download starts (R-DL4). `TALON_AUTO_INSTALL=no` does not refuse (the command names it) | R-NI12, R-DL3, R-DL4 |
## | any | missing | `Consent.use_download` for the missing ones, default Yes, one prompt (R-DL1). `Consent.required_want` for H decides (as `roc use`): flags answer, a person is asked, no person exits 13 (`Consent.download_stop`), `TALON_AUTO_INSTALL=no` is `Consent.download_refused` | R-NI5, R-DL1, R-DL5, R-BL3 |
NightlyFlow :: [].{

	## `free` are the values of the compiler slot (`NightlyPlan.pick.askable`), `Err(Held)` when the slot is not free (also when only H can be asked, or when the list could not be read: Q1). `downloads` is the number of compilers that this command installed. `note` is a line
	## for stdout and `data.notes` (the list could not be read).
	Plan : { free : Try(List(Str), [Held]), downloads : U64, note : Try(Str, [None]) }

	## R-WS4, Q3: `NightlyPlan.unify` for a request (`free` is `request.command == Upgrade` and `NightlyPlan.scope(request.names).nightly == Free`): the rows for `Pin.decide` and `differ`.
	unify : ResolveBase.Request, List({ file : Str, pin : Try(Str, [NoPin]), changes : Bool }) -> { members : List({ file : Str, pin : Try(Str, [NoPin]), changes : Bool }), differ : Bool }
	unify = |request, members| NightlyPlan.unify({ members, free: is_free(request) })

	## R-RP1: `NightlyPlan.moved_to` for a request (same `free`). `differ` is `unify(...).differ`.
	moved_to : ResolveBase.Request, Bool, Try(Str, [NoCompiler]), Try(Str, [None]) -> Try(Str, [Same])
	moved_to = |request, differ, held, nightly| NightlyPlan.moved_to({ free: is_free(request), unify: differ, held, nightly })

	## R-RP1: the pin edit of one member for the new id, with its line (`NightlyPlan.pin_line({ old: member.locked.roc, id })`): `{ file: member.file, op: Pin(id), line, did: Pinned(id) }`. `Err(Same)` when the member has the pin.
	pin_edit : Vars.Member, Str -> Try(ResolveBase.Edit, [Same])
	pin_edit = |member, id| NightlyPlan.pin_line({ old: member.locked.roc, id }).map_ok(|line| { file: member.file, op: Pin(id), line, did: Pinned(id) })

	## `held` is H, the compiler of the header (`Pin.Decision.held`). `snapshot` is the time of `--snapshot` (R-C7). The steps and the prompt table are in the comment above.
	plan! : Fx, ResolveBase.Request, ResolveBase.Loaded, ResolveBase.Settings, { held : Str, snapshot : Try(U64, [None]) } => Try(NightlyFlow.Plan, Fail)
	plan! = |fx, request, loaded, settings, facts| match listed!(fx, request) {
		Ok(releases) => known!(fx, request, { loaded, settings }, { held: facts.held, snapshot: facts.snapshot, releases })
		Err(fail) => if request.names.contains("roc") Err(fail) else Ok({ free: Err(Held), downloads: 0, note: Ok("the compiler list could not be read; roc stays ${facts.held}") })
	}
}

# R-UP6, R-UP12: `tln upgrade` with no names, or with the name `roc`, frees the nightly.
is_free : ResolveBase.Request -> Bool
is_free = |request| request.command == Upgrade and NightlyPlan.scope(request.names).nightly == Free

# Step 1: the list of the host. `--offline` with no cached page is a failure.
listed! : Fx, ResolveBase.Request => Try(List(Nightlies.Release), Fail)
listed! = |fx, request| {
	host = Toolchain.host(fx.platform!())?
	found = Nightlies.list!(fx, { net: request.net, roots: request.roots, now: request.now, offline: request.offline, host })?
	if found.source == Missing return Err(Toolchain.offline_no_list({}))
	Ok(found.releases)
}

# Steps 2 to 4 with a list of compilers.
known! : Fx, ResolveBase.Request, { loaded : ResolveBase.Loaded, settings : ResolveBase.Settings }, { held : Str, snapshot : Try(U64, [None]), releases : List(Nightlies.Release) } => Try(NightlyFlow.Plan, Fail)
known! = |fx, request, ctx, run| {
	toolchains = Launch.toolchains!(fx, request.roots)
	intent = ctx.loaded.intent.toolchain
	on_path = match request.compiler {
		Ok(found) => [found.id]
		Err(NoCompiler) => []
	}
	picked = NightlyPlan.pick({ releases: run.releases, req: intent.roc ?? Any, now: request.now, min_age: ctx.settings.min_age, snapshot: run.snapshot, nightly: ctx.settings.nightly, held: run.held, installed: toolchains.concat(on_path) })
	newest = match picked.newest {
		Ok(id) => id
		Err(NoneKnown) => return Err(Toolchain.range_failed({ req_text: intent.roc_text ?? "*", switch: { nightly: ctx.settings.nightly, source: ctx.settings.nightly_from } }))
	}
	missing = |id| Compiler.find({ id, installed: toolchains, path: request.compiler }).is_err()
	baselines = if missing(run.held) and !Pin.same_id(run.held, newest) [run.held] else []
	if !baselines.is_empty() and !Pin.is_nightly(run.held) {
		_ = Compiler.require({ id: run.held, installed: toolchains, path: request.compiler })?
	}
	new_offers = offers!(fx, request, if missing(newest) [newest] else [])?
	base_offers = offers!(fx, request, baselines)?
	all = new_offers.concat(base_offers)
	asked!(fx, request, { new: new_offers, base: base_offers, held: run.held })?
	var $installed = 0
	for offer in all {
		match offer {
			Download(d) => {
				done = RocInstall.install_offer!(fx, d)?
				if done.how == Installed {
					$installed = $installed + 1
				}
			}
			Present(_) => {}
		}
	}
	only_held = picked.askable.all(|id| Pin.same_id(id, run.held))
	Ok({ free: if only_held Err(Held) else Ok(picked.askable), downloads: $installed, note: Err(None) })
}

# Step 3: `RocInstall.offer!` for each id, in order. An id that is installed after all (`Present`) is no download.
offers! : Fx, ResolveBase.Request, List(Str) => Try(List(RocInstall.Offer), Fail)
offers! = |fx, request, ids| {
	var $found = no_offers
	for id in ids {
		match RocInstall.offer!(fx, { id, env: request.downloads.env, offline: request.offline })? {
			Download(offer) => {
				$found = $found.append(Download(offer))
			}
			Present(_) => {}
		}
	}
	Ok($found)
}

no_offers : List(RocInstall.Offer)
no_offers = []

# Step 4: the prompt of the table in the doc of `NightlyFlow`. With no baseline to download, the compiler that the command names is asked alone (`Consent.roc_install`, no flag: R-DL4).
asked! : Fx, ResolveBase.Request, { new : List(RocInstall.Offer), base : List(RocInstall.Offer), held : Str } => Try({}, Fail)
asked! = |fx, request, run| {
	ctx = { auto: request.downloads.auto, mode: request.prompt.mode, yes: request.prompt.yes, quiet: request.prompt.quiet, flag: request.downloads.allow }
	if !run.base.is_empty() {
		DownloadAsk.required!(fx, ctx, { all: run.new.concat(run.base), first: run.held })
	} else {
		match DownloadAsk.totals(run.new).ids {
			[id] => {
				size = DownloadAsk.totals(run.new).size
				asked = Prompt.ask!(fx, Consent.roc_install({ id, size }), { mode: ctx.mode, yes: ctx.yes, quiet: ctx.quiet, flag: Err(NoFlag) })?
				if asked.answer == Yes Ok({}) else Err(Consent.roc_install_declined(id))
			}
			_ => Ok({})
		}
	}
}
