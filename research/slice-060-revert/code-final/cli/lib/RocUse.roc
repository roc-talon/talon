import Answer
import Args
import Base
import Common
import Compiler
import Consent
import DownloadAsk
import Fail
import Fx
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
}

Offered : RocInstall.Offer

# What the output needs. `written` has the files in the order of the write.
Done : { id : Str, written : List({ file : Str, previous : Try(Str, [NoPin]) }), probes : U64, downloads : U64, built : Bool, notes : List(Str), toolchain : Try(Str, [Unset]) }

# The facts that steps 7 and 8 share.
Context : { env : List((Str, Str)), mode : Mode, offline : Bool, auto : [Ask, Yes, No], flag : Try(Answer, [NoFlag]), yes : Bool, quiet : Bool, installed : List(Str), path_roc : Try({ id : Str, path : Str }, [NoCompiler]) }

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
	fallback = fallback!(fx, request, loaded)?
	installed = Launch.toolchains!(fx, start.roots)
	target = named!(fx, { text, installed, env: start.env, offline: args.offline })?
	id = match target {
		Present({ id: found }) => found
		Download(offer) => offer.id
	}
	ManageUse.use_pinnable(id)?
	gate!(fx, request, loaded, { target, id, installed })?
	rows = ManageUse.use_plan({ id, members: loaded.members.map(|m| { file: m.file, pin: m.locked.roc }), fallback })?
	changes = rows.keep_if(|r| r.op.is_ok())
	if changes.is_empty() {
		return Ok({ id, written: [], probes: 0, downloads: 0, built: Bool.False, notes: [], toolchain })
	}
	ctx = { env: start.env, mode, offline: args.offline, auto, flag, yes: args.yes, quiet: args.quiet, installed, path_roc: compiler }
	installs = install_all!(fx, args, ctx, { target, id, rows: changes })?
	members = changes.map(|r| use_member(loaded, r, id))
	ran = Ladder.use!(fx, { roots: start.roots, now: start.now, path_roc: compiler, held: id, members, owners: [], downloads: ResolveBase.ladder_downloads(request), probe: { max: 100, timeout: 30, slots: 12, max_toolchains: 10 } })?
	written = write!(fx, loaded, { id, rows: changes })?
	Ok({
		id,
		written: written.map(|file| { file, previous: changes.find_first(|r| r.file == file).map_ok(|r| r.previous) ?? Err(NoPin) }),
		probes: members.fold(0, |total, m| total + if m.kind == App 3 else 2),
		downloads: installs,
		built: members.any(|m| m.kind == App),
		notes: ran.notes,
		toolchain,
	})
}

# The `ResolveBase.Request` that `load!`, `select!` and `ladder_downloads` read.
request_of : Args, { env : List((Str, Str)), roots : Roots, net : Net.Settings, now : U64, project : Project }, { compiler : Try({ id : Str, path : Str }, [NoCompiler]), toolchain : Try(Str, [Unset]), flag : Try(Answer, [NoFlag]), mode : Mode, auto : [Ask, Yes, No] } -> ResolveBase.Request
request_of = |args, start, facts| {
	command: Update,
	names: [],
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
	toolchain: facts.toolchain,
	snapshot: Err(Unset),
	dry_run: Bool.False,
	add: { as_platform: Bool.False, as_alias: Err(Unset), no_pin: Bool.False },
	prompt: { mode: facts.mode, yes: args.yes, quiet: args.quiet, rename_keys: Err(NoFlag), allow_moves: Err(NoFlag) },
	downloads: { auto: facts.auto, allow: facts.flag, probe: Err(NoFlag), env: start.env },
	probe: { no_probe: Bool.False, slots: Err(Unset) },
}

# Step 3, R-BL1, R-SO14: the compiler of a member with no pin: `ROC_TOOLCHAIN`, else rank 4 to 7 (`select!` looks at the members with no pin only, R-SO6).
fallback! : Fx, ResolveBase.Request, ResolveBase.Loaded => Try(Try(Str, [NoCompiler]), Fail)
fallback! = |fx, request, loaded| {
	unpinned = loaded.members.keep_if(|m| m.locked.roc.is_err())
	if unpinned.is_empty() {
		Ok(Err(NoCompiler))
	} else {
		match request.toolchain {
			Ok(id) => Ok(Ok(id))
			Err(Unset) => Ok(ResolveSelect.select!(fx, request, { ..loaded, members: unpinned })?.selected.id)
		}
	}
}

# Step 4, R-U2: the operand names an installed compiler (a unique prefix is expanded), else the compiler of `roc install` (`@latest`, a step, a new id).
named! : Fx, { text : Str, installed : List(Str), env : List((Str, Str)), offline : Bool } => Try(Offered, Fail)
named! = |fx, run| {
	offer = { id: run.text, env: run.env, offline: run.offline }
	if run.text.starts_with("@") {
		RocInstall.offer!(fx, offer)
	} else {
		match Nightlies.pick({ text: run.text, named: run.installed, auto: run.installed, base: Err(None) }) {
			Ok(id) => Ok(Present({ id: id }))
			Err(NoMatch(_)) => RocInstall.offer!(fx, offer)
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
use_member : ResolveBase.Loaded, ManageUse.UseRow, Str -> Ladder.UseMember
use_member = |loaded, row, id| {
	kind = match loaded.members.find_first(|m| m.file == row.file) {
		Ok(m) => m.locked.kind
		Err(_) => App
	}
	{ file: row.file, kind, text: ResolveBase.loaded_text(loaded, row.file), ops: [Pin(id)], baseline: row.baseline }
}

# Steps 7 and 8: the downloads, then the installs, the new compiler first. It gives the number of compilers that this run installed.
install_all! : Fx, Args, Context, { target : Offered, id : Str, rows : List(ManageUse.UseRow) } => Try(U64, Fail)
install_all! = |fx, args, ctx, run| {
	baselines = missing_baselines(ctx, run)?
	var $offers = no_offers
	for id in baselines {
		match RocInstall.offer!(fx, { id, env: ctx.env, offline: ctx.offline })? {
			Download(offer) => {
				$offers = $offers.append(Download(offer))
			}
			Present(_) => {}
		}
	}
	new = match run.target {
		Download(offer) => [Download(offer)]
		Present(_) => []
	}
	all = new.concat($offers)
	sum = DownloadAsk.totals(all)
	if $offers.is_empty() {
		match sum.ids {
			[id] => RocInstall.ask_download!(fx, args, ctx.env, { id, size: sum.size })?
			_ => {}
		}
	} else {
		DownloadAsk.required!(fx, { auto: ctx.auto, mode: ctx.mode, yes: ctx.yes, quiet: ctx.quiet, flag: ctx.flag }, { all, first: DownloadAsk.totals($offers).ids.first() ?? "" })?
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
missing_baselines : Context, { target : Offered, id : Str, rows : List(ManageUse.UseRow) } -> Try(List(Str), Fail)
missing_baselines = |ctx, run| {
	distinct = run.rows.map(|r| r.baseline).fold([], |found, id| if found.any(|seen| Pin.same_id(seen, id)) found else found.append(id))
	missing = distinct.keep_if(|id| !Pin.same_id(id, run.id) and Compiler.find({ id, installed: ctx.installed, path: ctx.path_roc }).is_err())
	match missing.find_first(|id| !Pin.is_nightly(id)) {
		Ok(id) => Compiler.require({ id, installed: ctx.installed, path: ctx.path_roc }).map_ok(|_| missing)
		Err(_) => Ok(missing)
	}
}

# Step 10, R-CC7, R-WS13: no lock. Each changed header is read again, checked against the first read, and all of them are written with one `write_atomic!` call. It gives the files that were written.
write! : Fx, ResolveBase.Loaded, { id : Str, rows : List(ManageUse.UseRow) } => Try(List(Str), Fail)
write! = |fx, loaded, run| {
	paths = run.rows.map(|r| r.file)
	ops = [Pin(run.id)]
	var $files = no_files
	var $edited = no_edited
	for (path, result) in paths.map2(fx.read_files!(paths), |path, result| (path, result)) {
		now = match result {
			Ok(text) => text
			Err(_) => return Err(Fail.new(Environment, "cannot read ${path}"))
		}
		read = ResolveBase.loaded_text(loaded, path)
		$files = $files.append({ path, read, now, spans_read: Locked.spans({ text: read, ops }), spans_now: Locked.spans({ text: now, ops }) })
		$edited = $edited.append({ path, now, new: Locked.edit({ path, text: now, ops })? })
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
	for line in ManageUse.use_report({ id: done.id, files: done.written }) {
		shown.out!(line)
	}
	note = match done.toolchain {
		Ok(toolchain) if !done.written.is_empty() => [ManageUse.use_note({ toolchain, id: done.id })]
		_ => []
	}
	for text in note {
		shown.out!("note: ${text}\n")
	}
	if args.json {
		data = ManageUse.use_data({ id: done.id, files: done.written, probes: done.probes, downloads: done.downloads, built: done.built, notes: done.notes.concat(note) })
		fx.out!(Out.json_ok({ command: args.typed, data }))
	}
}
