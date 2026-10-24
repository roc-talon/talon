import Fail
import Fx
import ResolveBase
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
	unify = |_request, _members| crash "todo: slice 039"

	## R-RP1: `NightlyPlan.moved_to` for a request (same `free`). `differ` is `unify(...).differ`.
	moved_to : ResolveBase.Request, Bool, Try(Str, [NoCompiler]), Try(Str, [None]) -> Try(Str, [Same])
	moved_to = |_request, _differ, _held, _nightly| crash "todo: slice 039"

	## R-RP1: the pin edit of one member for the new id, with its line (`NightlyPlan.pin_line({ old: member.locked.roc, id })`): `{ file: member.file, op: Pin(id), line, did: Pinned(id) }`. `Err(Same)` when the member has the pin.
	pin_edit : Vars.Member, Str -> Try(ResolveBase.Edit, [Same])
	pin_edit = |_member, _id| crash "todo: slice 039"

	## `held` is H, the compiler of the header (`Pin.Decision.held`). `snapshot` is the time of `--snapshot` (R-C7). The steps and the prompt table are in the comment above.
	plan! : Fx, ResolveBase.Request, ResolveBase.Loaded, ResolveBase.Settings, { held : Str, snapshot : Try(U64, [None]) } => Try(NightlyFlow.Plan, Fail)
	plan! = |_fx, _request, _loaded, _settings, _facts| Err(Fail.new(Internal, "todo: slice 039"))
}
