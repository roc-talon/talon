import Answer
import Args
import Base
import Channel
import Common
import Compiler
import Consent
import DownloadAsk
import Fail
import Fx
import HeldRoc
import Install
import Known
import Ladder
import Launch
import Locked
import ManageUse
import Mode
import Net
import Nightlies
import Out
import Pin
import Project
import Prompt
import ResolveBase
import ResolveLoad
import ResolveSelect
import RocInstall
import Roots
import Text
import Toolchain
import toml.Toml

## The command `tln roc use <ref>` (slice 026b, CLI 6.6: R-CS1, R-U1 to R-U6, R-WS13, R-RP1; Design 7 R-PH8). Direct style over `Fx` (TESTING.md 2.2 part C): `Manage` and `Pin` decide, `Ladder.use!` runs the probes,
## this module orders the calls. `Run.tln!` calls it for the command `["roc", "use"]`. The calls, in order (the L2 cases `roc/us1-use`, `roc/us2-workspace` and the L3 case
## `compilers/us1-use` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `ManageUse.read_use(args)`. A failure is printed with `Common.failed!` (no `Fx` call). `--no-check` never gets here: `Args.parse` stops it (R-U4). | R-CM15, R-U1, R-U4 |
## | 2 | `Install.begin!` (`env_all!`, `clock!`, the project), `Known.record!` (each member that the run reads: R-PD9, R-PD14), `Compiler.toolchain_of`, `Install.compiler!` (the `roc` on `PATH`) | R-PD1 to R-PD8, R-PD14 |
## | 3 | `ResolveLoad.load!` (one `read_files!` of the members, the `talon.toml` files, `config.toml`, `.roc-version`), `ResolveSelect.select!`, `ResolveBase.settings_of` | R-PD6, R-SO4 to R-SO7, R-NS8 to R-NS10 |
## | 4 | `Launch.toolchains!` (one `list_dirs!`). The operand names the compiler: a text that is not a step `@-N`, `@+N`, nor `@latest` goes to `Nightlies.pick` over the installed ids first (`roc default` does the same), then `RocInstall.offer!`. `Present` or `Download`. A step needs the base (`Base.selected!`, R-SL7, called by `offer!`). | R-U2, R-SL7, R-SC10 |
## | 5 | `ManageUse.use_pinnable(id)` (R-U1 for a prefix that named a local build), then `Pin.use_gate` with the range and the switch of step 3 (R-U5) and `times`: one `read_files!` of the `.talon.json` files (`Base.times!`, only with a range) and the `published_at` of the new compiler from the list. A refusal is exit 10 (`NoTuple`). No `talon.toml` is edited. | R-U1, R-U5 |
## | 6 | `ManageUse.use_plan` with the pins of the members and the compiler of a member with no pin (`ROC_TOOLCHAIN`, else the selected compiler). A member whose pin is the id has no edit and no probe. When no member has an edit, the command stops here with the line of `ManageUse.use_report` for no file (question Q7): no download, no probe, no write, exit 0. | R-CS1, R-WS13, R-BL1, R-SO14 |
## | 7 | The downloads: the new compiler (when step 4 gave `Download`) and each baseline compiler that is not installed and not the `roc` on `PATH` (`Compiler.find`; `RocInstall.offer!` for its size). A baseline that is not a nightly is `Compiler.require`. See the table below. | R-U2, R-U3, R-DL1 to R-DL5, R-NI5, R-NI6, Q4 |
## | 8 | `RocInstall.install_offer!` for each download, the new compiler first. | R-CC4 |
## | 9 | `Ladder.use!`: one `Ladder.UseMember` for each member with an edit, with its text and `ops` `[Pin(id)]`. The baseline check runs on the old pin, the candidate check and the build on the new compiler. A new error stops the command with exit 11 or 10 (R-H6): nothing is written. | R-U3, R-BL1, R-BL2, R-LD4, R-LD5, R-H6 |
## | 10 | Under no lock (R-CC7): one `read_files!` of the changed members, `Guard.check_all`, `Locked.edit`, one `write_atomic!` of the members (the writes come after all members passed). | R-H1, R-CC7, R-RP1 |
## | 11 | The output: `ManageUse.use_report` on stdout, and the note of `ManageUse.use_note` when `ROC_TOOLCHAIN` is set (R-U6). With `--json` the human text goes to stderr and stdout is the envelope with `ManageUse.use_data`. | R-OUT2, R-J3, R-U6 |
##
## The downloads of step 7 (answer of the review: Q4):
##
## | New compiler missing | Baseline compilers missing | Result |
## | --- | --- | --- |
## | yes | none | The prompt of `roc install` (`Consent.roc_install`, R-NI6): the command names it. A person: default yes. No person: no prompt, the download starts (R-DL4). `TALON_AUTO_INSTALL=no` does not refuse (answer Q2 of slice 026). |
## | any | 1 or more | One prompt for all (R-DL1): `Consent.use_download` (1 id or more, default Yes: `roc use` names its download, R-DL3). `Consent.required_want` decides as for the first probe of `install`: the answer flags, `--yes` and `TALON_AUTO_INSTALL=yes` answer it, a person is asked (default Yes), else exit 13 with `Consent.download_stop` (count, total size). `TALON_AUTO_INSTALL=no` is `Consent.download_refused` (exit 13). |
## | no | none | No prompt, no list request |
RocUse :: [].{

	## Steps 1 to 11 of `tln roc use`.
	use! : Fx, Args => I32
	use! = |fx, args| match ManageUse.read_use(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(text) => {
			shown = Common.shown_fx(fx, args)
			match flow!(shown, args, text) {
				Ok(done) => {
					print!(fx, shown, args, done)
					0
				}
				Err(fail) => Common.failed!(fx, args, fail)
			}
		}
	}

	## Slice 243 (R-CH15, R-UP6, R-RP1, R-U3, R-H6, R-CH11, R-CH16, user decision of 2026-11-12): `tln upgrade roc` on `[toolchain] roc = "=<user id>"` of the root `talon.toml`. `held` is that id. `start` is the result of `Update.begin!`. The calls, in order:
	##
	## | Step | Does |
	## | --- | --- |
	## | 1 | `Compiler.toolchain_of`, `Install.compiler!`, `ResolveLoad.load!` (as `roc use`) |
	## | 2 | The table of the channel of `held`: `config.toml` has it, else exit 19 (the project only: R-CH11) or exit 2 (R-CH8), before any request |
	## | 3 | `platform!`, `Nightlies.list_channel!` (direct, the `source` of the table: R-CH16). `Toolchain.range_pick` over `>=<held>` with the switch and `min-release-age`. No build, or the build is not later than `held` (`Channel.pin_move`): `Newest(held)`, nothing else is done |
	## | 4 | The offer of the new build, the installed list, `install_all!` (the consent, the download), then `Ladder.use!` for every member: the baseline check on `held`, the candidate check and the build on the new build (R-U3, R-H6: a new error is exit 11 and nothing is written) |
	## | 5 | Under no lock (R-CC7): `write!` of the root `talon.toml` with `Channel.use_edit`. A dry run writes nothing |
	upgrade_user! : Fx, Args, { env : List((Str, Str)), roots : Roots, net : Net.Settings, now : U64, project : Project }, { held : Str, dry_run : Bool } => Try([Newest(Str), Kept({ note : Try(Str, [None]) }), Moved({ id : Str, old : Str, file : Str, written : Bool, probes : U64, downloads : U64, built : Bool, notes : List(Str), skipped : Try(Str, [None]) })], Fail)
	upgrade_user! = |fx, args, start, run| {
		toolchain = Compiler.toolchain_of(start.env)?
		compiler = Install.compiler!(fx, start.roots, Bool.False)
		flag = if args.options.any(|(name, _)| name == "--allow-downloads") Ok(Yes) else Err(NoFlag)
		mode = Mode.from_env({ env: Dict.from_list(start.env), json: args.json })
		auto = Consent.auto_install(start.env)
		request = request_of(args, start, { compiler, toolchain, flag, mode, auto })
		loaded = ResolveLoad.load!(fx, request)?
		table = match user_table(loaded, run.held)? {
			Ok(found) => found
			Err(NotUser) => return Err(Fail.new(Internal, "${run.held} is not a user-channel build"))
		}
		settings = ResolveBase.settings_of(request, loaded)
		system = Toolchain.host(fx.platform!())?
		listed = Nightlies.list_channel!(fx, { net: start.net, roots: start.roots, now: start.now, offline: args.offline, host: system, channel: table })?
		if listed.source == Missing return Err(Toolchain.offline_no_list({}))
		times = listed.releases.map(|r| { id: r.id, published_at: r.published_at })
		picked = Toolchain.range_pick({ releases: listed.releases, req: AtLeast(run.held), now: start.now, min_age: settings.min_age, snapshot: Err(None), nightly: settings.nightly, exclude: settings.exclude })
		_ = match picked {
			Ok(id) => id
			Err(NoneKnown) => if settings.nightly {
				return Ok(Newest(run.held))
			} else {
				return Err(Fail.new(NoTuple, "no build of channel ${table.name} is allowed, and nightly is false (set by ${Pin.source_text(settings.nightly_from)})"))
			}
		}
		# R-SP12 (slice 243, user decision of 2026-11-12): the candidates are the builds of the channel later than `held` that the switch and `min-release-age` allow (`>=<held>`), newest first, at most `max_toolchains` of them.
		# The first one that passes the check loop is the answer. A build that fails with a new error (kind `AppError`) is dropped and the next one is tried; any other failure stops the command.
		allowed = Toolchain.range_allowed({ releases: listed.releases, req: AtLeast(run.held), now: start.now, min_age: settings.min_age, snapshot: Err(None), nightly: settings.nightly, exclude: settings.exclude }).map(|r| r.id)
		later = allowed.keep_if(|each| Channel.user_order(each, run.held, times) == Ok(After))
		by_newest = later.sort_with(
			|a, b| match Channel.user_order(a, b, times) {
				Ok(After) => Before
				Ok(Before) => After
				_ => Same
			},
		)
		candidates = by_newest.take_first(try_limit)
		if candidates.is_empty() return Ok(Newest(run.held))
		root = toml_path(request.project, loaded)
		installed = Launch.toolchains_all!(fx, start.roots)
		rows = loaded.members.map(|m| { file: m.file, baseline: run.held, previous: Err(NoPin), op: Err(Same) })
		ctx = { env: start.env, mode, offline: args.offline, auto, flag, yes: args.yes, quiet: args.quiet, installed, path_roc: compiler, registry: First(args.registry) }
		members = rows.map(|r| use_member(loaded, r))
		var $won = no_win
		var $why = no_why
		var $downloads = 0
		var $probes = 0
		for id in candidates {
			offer = RocInstall.offer_noted!(fx, { id, env: start.env, offline: args.offline, registry: First(args.registry) })?.offer
			installs = install_all!(fx, args, ctx, { target: offer, id, rows, picked: Err(None) })?
			$downloads = $downloads + installs
			match Ladder.use!(fx, { roots: start.roots, now: start.now, path_roc: compiler, held: id, members, owners: [], downloads: ResolveBase.ladder_downloads(request), probe: { max: 100, timeout: 30, slots: 12, max_toolchains: 10 } }) {
				Ok(ran) => {
					$probes = $probes + members.fold(0, |total, m| total + if m.kind == App 3 else 2)
					$won = Ok({ id, notes: ran.notes })
					break
				}
				Err(fail) => if fail.kind.code() == 11 {
					$probes = $probes + members.len() * 2
					# The note comes at once, before the ladder lines of the next candidate (the order of ur4-candidate).
					fx.out!("note: roc ${id} is not used: ${fail.message}\n")
					if $why.is_err() {
						$why = Ok({ id, message: fail.message })
					}
				} else {
					return Err(fail)
				}
			}
		}
		chosen = match $won {
			Ok(found) => found
			Err(None) => {
				return Ok(Kept({ note: Err(None) }))
			}
		}
		toml = match toml_plan(loaded, { path: root, id: chosen.id, user: Ok(table) }) {
			Ok(plan) => plan
			Err(Same) => return Ok(Newest(run.held))
		}
		written = if run.dry_run [] else write!(fx, loaded, { id: chosen.id, rows: [], toml: Ok(toml) })?
		skipped = Err(None)
		Ok(
			Moved({
				id: chosen.id,
				old: toml.old ?? "",
				file: root,
				written: written.contains(root),
				probes: $probes,
				downloads: $downloads,
				built: members.any(|m| m.kind == App),
				notes: chosen.notes,
				skipped,
			}),
		)
	}
}

Offered : RocInstall.Offer

# What the output needs. `written` has the files in the order of the write.
Done : { id : Str, written : List({ file : Str, previous : Try(Str, [NoPin]) }), toml : Try({ file : Str, old : Try(Str, [NoPin]), added : Try(Str, [None]), removed : Try(Str, [None]), user : Bool }, [None]), probes : U64, downloads : U64, built : Bool, notes : List(Str), toolchain : Try(Str, [Unset]) }

# The facts that steps 7 and 8 share.
Context : { env : List((Str, Str)), mode : Mode, offline : Bool, auto : [Ask, Yes, No], flag : Try(Answer, [NoFlag]), yes : Bool, quiet : Bool, installed : List(Str), path_roc : Try({ id : Str, path : Str }, [NoCompiler]), registry : [Off, First(Try(Str, [Unset])), Later(Try(Str, [Unset]))] }

# Steps 2 to 10.
flow! : Fx, Args, Str => Try(Done, Fail)
flow! = |fx, args, text| {
	start = Install.begin!(fx, args)?
	Known.record!(fx, { roots: start.roots, files: Install.canonical_files!(fx, start.project), now: start.now })?
	toolchain = Compiler.toolchain_of(start.env)?
	compiler = Install.compiler!(fx, start.roots, Bool.False)
	flag = if args.options.any(|(name, _)| name == "--allow-downloads") Ok(Yes) else Err(NoFlag)
	mode = Mode.from_env({ env: Dict.from_list(start.env), json: args.json })
	auto = Consent.auto_install(start.env)
	request = request_of(args, start, { compiler, toolchain, flag, mode, auto })
	loaded = ResolveLoad.load!(fx, request)?
	# Slice 243 (R-CH14, R-CH8, Design Q619 C1, C4): the id of a user build that the operand names in full: the table and the range come before any list.
	if Channel.user_parts(text).is_ok() {
		_ = user_table(loaded, text)?
		Pin.use_gate({ id: text, req: loaded.intent.toolchain.roc, req_text: loaded.intent.toolchain.roc_text, nightly: ResolveBase.settings_of(request, loaded).nightly, source: ResolveBase.settings_of(request, loaded).nightly_from, times: [] })?
	}
	fallback = fallback!(fx, request, loaded)?
	installed = Launch.toolchains_all!(fx, start.roots)
	noted = named!(fx, { text, installed, env: start.env, offline: args.offline, flag: args.registry })?
	target = noted.offer
	# Slice 206g (R-IX4): the new compiler read the compiler list when it is a download or a step; the baselines then read the kept rows.
	listed = match target {
		Download(_) => Bool.True
		Present(_) => text.starts_with("@")
	}
	id = match target {
		Present({ id: found }) => found
		Download(offer) => offer.id
	}
	ManageUse.use_pinnable(id)?
	user = user_table(loaded, id)?
	gate!(fx, request, loaded, { target, id, installed })?
	rows = ManageUse.use_plan({ id, members: loaded.members.map(|m| { file: m.file, pin: m.locked.roc }), fallback: fallback.id })?
	# Slice 243 (R-CH14): the root `talon.toml` of the run: a user build goes in; a nightly takes a user pin out.
	root = toml_path(request.project, loaded)
	toml = toml_plan(loaded, { path: root, id, user })
	# A user build is a change for every member (the compiler of the project changes), a nightly only for a member with an edit.
	changes = if user.is_ok() rows else rows.keep_if(|r| r.op.is_ok())
	if rows.keep_if(|r| r.op.is_ok()).is_empty() and toml.is_err() {
		return Ok({ id, written: [], toml: Err(None), probes: 0, downloads: 0, built: Bool.False, notes: [], toolchain })
	}
	# R-C16 (slice 084): `roc use` writes a pin, so a young compiler that only a pattern kept is a new choice, also when it is installed. A pin that equals it changes nothing (the return above): no note.
	RocInstall.print_note!(fx, args.quiet, noted.note)
	ctx = { env: start.env, mode, offline: args.offline, auto, flag, yes: args.yes, quiet: args.quiet, installed, path_roc: compiler, registry: if listed Later(args.registry) else First(args.registry) }
	installs = install_all!(fx, args, ctx, { target, id, rows: changes, picked: fallback.picked })?
	members = changes.map(|r| use_member(loaded, r))
	ran = Ladder.use!(fx, { roots: start.roots, now: start.now, path_roc: compiler, held: id, members, owners: [], downloads: ResolveBase.ladder_downloads(request), probe: { max: 100, timeout: 30, slots: 12, max_toolchains: 10 } })?
	written = write!(fx, loaded, { id, rows: changes, toml })?
	moved = written.keep_if(|file| file != root)
	Ok({
		id,
		written: moved.map(|file| { file, previous: changes.find_first(|r| r.file == file).map_ok(|r| r.previous) ?? Err(NoPin) }),
		toml: match toml {
			Ok(plan) if written.contains(root) => Ok({ file: root, old: plan.old, added: plan.added, removed: plan.removed, user: user.is_ok() })
			_ => Err(None)
		},
		probes: members.fold(0, |total, m| total + if m.kind == App 3 else 2),
		downloads: installs,
		built: members.any(|m| m.kind == App),
		notes: ran.notes,
		toolchain,
	})
}

# Slice 243 (R-CH14, R-CH8, R-CH11, Design Q619 C4): the table of the channel of a user build. `Err(NotUser)` for any other id. A table of `config.toml` is the answer; a table of the project only is exit 19 (R-CH11); no table is exit 2.
user_table : ResolveBase.Loaded, Str -> Try(Try(Channel.Entry, [NotUser]), Fail)
user_table = |loaded, id| match Channel.user_parts(id) {
	Err(_) => Ok(Err(NotUser))
	Ok(parts) => {
		project = loaded.tomls.join_map(
			|t| match Toml.parse(t.text) {
				Ok(doc) => Channel.entries(Channel.read(doc, t.text).tables)
				Err(_) => []
			},
		)
		match Channel.table_for({ name: parts.name, config: loaded.config.channels, project }) {
			Config(t) => Ok(Ok(t))
			Project(t) => {
				said = Channel.trust_text(t)
				Err(Fail.new(Input, "${said.message}\n${said.hint}"))
			}
			Neither => Err(Fail.new(Usage, Channel.unknown_name_text(parts.name)))
		}
	}
}

# The root `talon.toml`: the workspace root, else the directory of the first member.
toml_path : Project, ResolveBase.Loaded -> Str
toml_path = |project, loaded| {
	root = match project.workspace {
		Ok(ws) => ws.root
		Err(Standalone) => loaded.members.first().map_ok(|m| Text.dir_of(m.file)) ?? ""
	}
	Text.join(root, "talon.toml")
}

# Slice 243 (R-CH14): the edit of the root `talon.toml`. `Err(Same)`: no edit. A user build sets `[toolchain] roc = "=<id>"` (and the table); a nightly takes out a pin of a user build.
# `old` is the text of `[toolchain] roc` before, `added` and `removed` are the channel tables that the edit adds and removes (for the output).
TomlPlan : { old : Try(Str, [NoPin]), added : Try(Str, [None]), removed : Try(Str, [None]), table : Try(Channel.Entry, [NotUser]), path : Str }

toml_plan : ResolveBase.Loaded, { path : Str, id : Str, user : Try(Channel.Entry, [NotUser]) } -> Try(TomlPlan, [Same])
toml_plan = |loaded, run| {
	text = ResolveBase.loaded_text(loaded, run.path)
	old = Channel.pin_text(text).map_err(|None| NoPin)
	tables = match Toml.parse(text) {
		Ok(doc) => Channel.read(doc, text).tables.map(|t| t.name)
		Err(_) => []
	}
	old_channel = match old {
		Ok(value) => match Channel.user_range(value) {
			Ok(Exactly(bound)) | Ok(AtLeast(bound)) => Channel.user_parts(bound).map_ok(|p| p.name).map_err(|_| None)
			Err(_) => Err(None)
		}
		Err(_) => Err(None)
	}
	dropped = match old_channel {
		Ok(name) if tables.contains(name) => Ok(name)
		_ => Err(None)
	}
	match run.user {
		Ok(table) => {
			edited = Channel.use_edit({ path: run.path, text, id: run.id, table })
			removed = match dropped {
				Ok(name) if name != table.name => Ok(name)
				_ => Err(None)
			}
			match edited {
				Ok(new) if new != text => Ok({ old, added: if tables.contains(table.name) Err(None) else Ok(table.name), removed, table: run.user, path: run.path })
				_ => Err(Same)
			}
		}
		Err(NotUser) => match Channel.unuse_edit({ path: run.path, text }) {
			Ok(Set(_)) => Ok({ old, added: Err(None), removed: dropped, table: run.user, path: run.path })
			_ => Err(Same)
		}
	}
}

# The `ResolveBase.Request` that `load!`, `select!` and `ladder_downloads` read.
request_of : Args, { env : List((Str, Str)), roots : Roots, net : Net.Settings, now : U64, project : Project }, { compiler : Try({ id : Str, path : Str }, [NoCompiler]), toolchain : Try(Str, [Unset]), flag : Try(Answer, [NoFlag]), mode : Mode, auto : [Ask, Yes, No] } -> ResolveBase.Request
request_of = |args, start, facts| {
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
	compiler: facts.compiler,
	selected: "",
	none: Stop,
	index: Direct,
	registry: Off,
	toolchain: facts.toolchain,
	snapshot: Err(Unset),
	dry_run: Bool.False,
	add: { as_platform: Bool.False, as_alias: Err(Unset), no_pin: Bool.False },
	prompt: { mode: facts.mode, yes: args.yes, quiet: args.quiet, rename_keys: Err(NoFlag), allow_moves: Err(NoFlag) },
	downloads: { auto: facts.auto, allow: facts.flag, probe: Err(NoFlag), env: start.env },
	probe: { no_probe: Bool.False, slots: Err(Unset) },
}

# Step 3, R-BL1, R-SO14: the compiler of a member with no pin: `ROC_TOOLCHAIN`, else rank 4 to 7 (`select!` looks at the members with no pin only, R-SO6). Slice 072e (R-SO14, R-SO23, R-U3): when no rank gives a compiler,
# Talon picks one as an id (`HeldRoc.picked!`, no download). `picked` is that id. It is a baseline that is not installed, so it is in the one prompt of step 7 and it becomes the default after its download.
fallback! : Fx, ResolveBase.Request, ResolveBase.Loaded => Try({ id : Try(Str, [NoCompiler]), picked : Try(Str, [None]) }, Fail)
fallback! = |fx, request, loaded| {
	unpinned = loaded.members.keep_if(|m| m.locked.roc.is_err())
	if unpinned.is_empty() {
		Ok({ id: Err(NoCompiler), picked: Err(None) })
	} else {
		match request.toolchain {
			Ok(id) => Ok({ id: Ok(id), picked: Err(None) })
			Err(Unset) => {
				members = { ..loaded, members: unpinned }
				match ResolveSelect.select!(fx, request, members)?.selected.id {
					Ok(id) => Ok({ id: Ok(id), picked: Err(None) })
					Err(NoCompiler) => {
						id = HeldRoc.picked!(fx, request, members)?
						Ok({ id: Ok(id), picked: Ok(id) })
					}
				}
			}
		}
	}
}

# Step 4, R-U2: the operand names an installed compiler (a unique prefix is expanded), else the compiler of `roc install` (`@latest`, a step, a new id).
# R-C16: `note` is the note of `RocInstall.offer_noted!` (a step or `@latest` only).
named! : Fx, { text : Str, installed : List(Str), env : List((Str, Str)), offline : Bool, flag : Try(Str, [Unset]) } => Try({ offer : Offered, note : Try(Str, [None]) }, Fail)
named! = |fx, run| {
	if run.text.starts_with("@") {
		RocInstall.offer_noted!(fx, { id: run.text, env: run.env, offline: run.offline, registry: First(run.flag) })
	} else {
		match Nightlies.pick({ text: run.text, named: run.installed, auto: run.installed, base: Err(None) }) {
			Ok(id) => Ok({ offer: Present({ id: id }), note: Err(None) })
			Err(NoMatch(_)) => RocInstall.offer_noted!(fx, { id: run.text, env: run.env, offline: run.offline, registry: First(run.flag) })
			Err(error) => Err(Nightlies.failure(error))
		}
	}
}

# Step 5, R-U5, R-NS1: the switch and the range. The order of nightlies is by `published_at`: the installed ones (`.talon.json`, only with a range) and the new one (the list).
gate! : Fx, ResolveBase.Request, ResolveBase.Loaded, { target : Offered, id : Str, installed : List(Str) } => Try({}, Fail)
gate! = |fx, request, loaded, run| {
	toolchain = loaded.intent.toolchain
	settings = ResolveBase.settings_of(request, loaded)
	known = if toolchain.roc.is_ok() and !run.installed.is_empty() Base.times!(fx, request.roots, run.installed) else []
	times = match run.target {
		Download(offer) => known.append({ id: offer.id, published_at: offer.ctx.published_at })
		Present(_) => known
	}
	Pin.use_gate({ id: run.id, req: toolchain.roc, req_text: toolchain.roc_text, nightly: settings.nightly, source: settings.nightly_from, times })
}

# The member of the ladder for one row of the plan (the text that the first read gave).
use_member : ResolveBase.Loaded, ManageUse.UseRow -> Ladder.UseMember
use_member = |loaded, row| {
	kind = match loaded.members.find_first(|m| m.file == row.file) {
		Ok(m) => m.locked.kind
		Err(_) => App
	}
	{ file: row.file, kind, text: ResolveBase.loaded_text(loaded, row.file), ops: ops_of(row), baseline: row.baseline }
}

# The header edit of a row: its op, or none for a member that the plan leaves as it is.
ops_of : ManageUse.UseRow -> List(Locked.Op)
ops_of = |row| match row.op {
	Ok(op) => [op]
	Err(Same) => []
}

# Steps 7 and 8: the downloads, then the installs, the new compiler first. It gives the number of compilers that this run installed.
# Slice 072e (R-U3, R-SO15): the pick (`run.picked`) is a baseline. It is first in the prompt and in the installs, and it becomes `default-roc` after its download.
install_all! : Fx, Args, Context, { target : Offered, id : Str, rows : List(ManageUse.UseRow), picked : Try(Str, [None]) } => Try(U64, Fail)
install_all! = |fx, args, ctx, run| {
	baselines = missing_baselines(ctx, run)?
	var $offers = no_offers
	for id in baselines {
		match RocInstall.offer!(fx, { id, env: ctx.env, offline: ctx.offline, registry: ctx.registry })? {
			Download(offer) => {
				$offers = $offers.append(Download(offer))
			}
			Present(_) => {}
		}
	}
	is_pick = |offer| match offer {
		Download(d) => run.picked == Ok(d.id)
		Present(_) => Bool.False
	}
	picks = $offers.keep_if(is_pick)
	bases = picks.concat($offers.keep_if(|offer| !is_pick(offer)))
	new = match run.target {
		Download(offer) => [Download(offer)]
		Present(_) => []
	}
	all = picks.concat(new).concat(bases.drop_first(picks.len()))
	sum = DownloadAsk.totals(all)
	if $offers.is_empty() {
		match sum.ids {
			[id] => RocInstall.ask_download!(fx, args, ctx.env, { id, size: sum.size })?
			_ => {}
		}
	} else {
		DownloadAsk.required!(fx, { auto: ctx.auto, mode: ctx.mode, yes: ctx.yes, quiet: ctx.quiet, flag: ctx.flag }, { all, first: DownloadAsk.totals(bases).ids.first() ?? "" })?
	}
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
	Ok($installed)
}

no_offers : List(Offered)
no_offers = []

# R-U3, R-BL1, R-DL2: the baseline compilers that are not installed, in member order with no repeat (the other tag form of one nightly counts as one). The new compiler is not one. A baseline that is not a nightly
# has no source: the failure of `Compiler.require` (R-NS2).
missing_baselines : Context, { target : Offered, id : Str, rows : List(ManageUse.UseRow), picked : Try(Str, [None]) } -> Try(List(Str), Fail)
missing_baselines = |ctx, run| {
	distinct = run.rows.map(|r| r.baseline).fold([], |found, id| if found.any(|seen| Pin.same_id(seen, id)) found else found.append(id))
	missing = distinct.keep_if(|id| !Pin.same_id(id, run.id) and Compiler.find({ id, installed: ctx.installed, path: ctx.path_roc }).is_err())
	match missing.find_first(|id| !Pin.is_nightly(id)) {
		Ok(id) => Compiler.require({ id, installed: ctx.installed, path: ctx.path_roc }).map_ok(|_| missing)
		Err(_) => Ok(missing)
	}
}

# Step 10, R-CC7, R-WS13: no lock. Each changed header and the root `talon.toml` (slice 243) are read again, checked against the first read, and all of them are written with one `write_atomic!` call. It gives the files that were written.
write! : Fx, ResolveBase.Loaded, { id : Str, rows : List(ManageUse.UseRow), toml : Try(TomlPlan, [Same]) } => Try(List(Str), Fail)
write! = |fx, loaded, run| {
	paths = run.rows.map(|r| r.file)
	toml_files = match run.toml {
		Ok(plan) => [plan.path]
		Err(Same) => []
	}
	var $files = no_files
	var $edited = no_edited
	for (path, result) in paths.concat(toml_files).map2(fx.read_files!(paths.concat(toml_files)), |path, result| (path, result)) {
		is_toml = toml_files.contains(path)
		now = match result {
			Ok(text) => text
			Err(NotFound) if is_toml => ""
			Err(_) => return Err(Fail.new(Environment, "cannot read ${path}"))
		}
		read = ResolveBase.loaded_text(loaded, path)
		if is_toml {
			plan = match run.toml {
				Ok(p) => p
				Err(Same) => return Err(Fail.new(Internal, "${path}: no edit"))
			}
			new = match plan.table {
				Ok(table) => Channel.use_edit({ path, text: now, id: run.id, table })?
				Err(NotUser) => match Channel.unuse_edit({ path, text: now })? {
					Set(text) => text
					Same => now
				}
			}
			$files = $files.append({ path, read, now, spans_read: Channel.use_spans(read), spans_now: Channel.use_spans(now) })
			$edited = $edited.append({ path, now, new })
		} else {
			ops = match run.rows.find_first(|r| r.file == path) {
				Ok(row) => ops_of(row)
				Err(_) => []
			}
			$files = $files.append({ path, read, now, spans_read: Locked.spans({ text: read, ops }), spans_now: Locked.spans({ text: now, ops }) })
			$edited = $edited.append({ path, now, new: Locked.edit({ path, text: now, ops })? })
		}
	}
	ResolveBase.write_checked!(fx, { files: $files, edited: $edited })
}

no_files : List({ path : Str, read : Str, now : Str, spans_read : List(Str), spans_now : List(Str) })
no_files = []

no_edited : List({ path : Str, now : Str, new : Str })
no_edited = []

# Step 11, R-OUT2, R-J3, R-U6: the lines of `ManageUse.use_report` and the note, or the envelope (the human text is on stderr with `--json`).
print! : Fx, Fx, Args, Done => {}
print! = |fx, shown, args, done| {
	lines = match done.toml {
		Ok(toml) => ManageUse.use_toml_report({ id: done.id, user: toml.user, toml: { file: toml.file, old: toml.old, added: toml.added, removed: toml.removed }, files: done.written })
		Err(None) => ManageUse.use_report({ id: done.id, files: done.written })
	}
	for line in lines {
		shown.out!(line)
	}
	note = match done.toolchain {
		Ok(toolchain) if !done.written.is_empty() or done.toml.is_ok() => [ManageUse.use_note({ toolchain, id: done.id })]
		_ => []
	}
	for text in note {
		shown.out!("note: ${text}\n")
	}
	if args.json {
		listed = match done.toml {
			Ok(toml) => [{ file: toml.file, previous: toml.old }].concat(done.written)
			Err(None) => done.written
		}
		data = ManageUse.use_data({ id: done.id, files: listed, probes: done.probes, downloads: done.downloads, built: done.built, notes: done.notes.concat(note) })
		fx.out!(Out.json_ok({ command: args.typed, data }))
	}
}

# R-SP12 (slice 243): the most candidates that `upgrade roc` on a user pin tries (the `max_toolchains` of the probe settings, as the ladder run).
try_limit : U64
try_limit = 10

no_win : Try({ id : Str, notes : List(Str) }, [None])
no_win = Err(None)

no_why : Try({ id : Str, message : Str }, [None])
no_why = Err(None)
