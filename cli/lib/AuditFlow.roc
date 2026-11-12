import records.Closure as Wire
import Args
import AuditCheck
import AuditTypes
import ClosureIndex
import ClosureRequest
import Common
import Fail
import Fx
import Help
import IndexQuery
import InstallFlow
import Ls
import Out
import Pin
import Project
import PrivacyGuard
import ResolveBase
import Text

## The command `tln audit` with a registry (slice 244a, R-CM14, R-AU1 to R-AU5, R-AU9 to R-AU13, R-AU15, R-PT8). Command code over `Fx` (TESTING.md 2.2 part C): `AuditCheck` decides, `AuditReport` has the words.
## The calls, in order (the L2 cases `audit/` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `AuditCheck.read`: the flags and the operand. A failure is exit 2, before any read. `--offline` is exit 2 (Q-244-8). | R-AU12, R-FL7 |
## | 2 | `Ls.load_full!`: the start, the record of the project, the load of the members. | R-PD1 to R-PD9 |
## | 3 | `AuditCheck.toml_items` of the root talon.toml. A bad item is exit 19, before the query (Q-244-6). | R-AU12, R-WS5 |
## | 4 | One closure query as `tln why` (Q-244-10): no `groups`, the header hashes, then the hash of each project tool, the held nightly as the window. The guard first. No snapshot, no settle (Q-244-4): `audit` writes nothing to the registry. | R-AU1, R-PT8, R-YK5, R-RG4 |
## | 5 | The walk of each member from the records of the answer. | R-AU1 |
## | 6 | `entries`, `of_answer`, `ignore`: the report. Human text on stdout, or with `--json` the envelope only. Exit 21 is the failure of `AuditCheck.failure`. | R-AU3, R-AU5, R-J4 |
##
## `direct` is part 244b: a temporary exit 1.
AuditFlow :: [].{

	run! : Fx, Args => I32
	run! = |fx, args| match go!(fx, args) {
		Ok(code) => code
		Err(fail) => Common.failed!(fx, args, fail)
	}
}

go! : Fx, Args => Try(I32, Fail)
go! = |fx, args| {
	opts = AuditCheck.read(args)?
	if args.offline return Err(Fail.new(Usage, "tln audit reads the index of now, so it does not take --offline"))
	read = Ls.load_full!(fx, args)?
	from_toml = root_items(read)?
	set = InstallFlow.setting_of({ ..read.request, registry: Setting(args.registry) }, read.loaded)?
	query = match set.registry {
		Read(q) => q
		_ => return Err(Fail.new(Internal, "tln audit with direct is not built yet"))
	}
	tools = read.loaded.intent.tools.keep_oks(|t| t.url.map_ok(|u| { key: t.key, url: u }))
	entries = read.loaded.members.join_map(|m| m.locked.rows.map(|r| r.value)).concat(tools.map(|t| t.url))
	sources = IndexQuery.sources({ groups: [], entries })
	answer = if sources.is_empty() {
		empty_answer
	} else {
		PrivacyGuard.check!(fx, { net: set.net, roots: set.roots, sources, offline: Bool.False, frozen: Bool.False })?
		window = pin_window(read.loaded.members.keep_oks(|m| m.locked.roc))
		ClosureIndex.query!(fx, { origin: query.origin, version: Help.version, facts: { groups: [], entries, window }, source: query.source })?
	}
	request = { ..read.request, registry: Read(query), index: Answer({ origin: query.origin, answer }) }
	walk = Ls.walk_loaded!(fx, { ..read, request }, Bool.False)?
	checked = AuditCheck.of_answer({ answer, entries: AuditCheck.entries({ members: walk.closures, tools }) })
	ignoring = AuditCheck.ignore({ findings: checked.findings, items: from_toml.concat(opts.items) })
	report : AuditTypes.Report
	report = { index: Registry, checked: checked.checked, findings: ignoring.findings, unused: ignoring.unused, no_yank_data: Bool.True, unindexed: checked.unindexed.map(|e| { name: e.name, version: e.version, hash: e.hash }) }
	if !args.json {
		fx.out!(AuditCheck.text(report))
	}
	if AuditCheck.code(report.findings) == 21 {
		Err(AuditCheck.failure(report))
	} else {
		if args.json fx.out!(Out.json_ok({ command: args.typed, data: AuditCheck.data(report) }))
		Ok(0)
	}
}

# R-AU12, R-WS5: the items of `[audit] ignore` of the root talon.toml (the workspace root, else the file of the project). No file: no item.
root_items : { project : Project, loaded : ResolveBase.Loaded, request : ResolveBase.Request } -> Try(List(Str), Fail)
root_items = |read| {
	path = match read.project.workspace {
		Ok(w) => Text.join(w.root, "talon.toml")
		Err(Standalone) => Text.join(Text.dir_of(read.loaded.members.first().map_ok(|m| m.file) ?? ""), "talon.toml")
	}
	match read.loaded.tomls.find_first(|t| t.path == path) {
		Ok(t) => AuditCheck.toml_items({ path, text: t.text })
		Err(_) => Ok([])
	}
}

# Q502 as `tln why`: the nightly of the workspace is the window when the pins of the members agree.
pin_window : List(Str) -> ClosureRequest.Window
pin_window = |pins| match pins {
	[first, .. as rest] => if rest.all(|id| Pin.same_id(id, first)) Held(first) else None
	[] => None
}

empty_answer : Wire.Answer
empty_answer = { artifacts: [], releases: [], epochs: [], runs: [], nearest: [], hints: [], log_size: 0, unknown: [], checked: [], repos: [] }
