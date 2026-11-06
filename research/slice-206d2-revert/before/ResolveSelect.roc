import Clock
import Compiler
import Consent
import Fail
import Fx
import Intent
import ResolveBase
import RocInstall
import Text

## The compiler of a run (slice 031b: split from `ResolveBase`): the choice of the held compiler, and the snapshot that a range of compilers needs.
ResolveSelect :: [].{

	## R-SO4 to R-SO7, R-SO13, R-SO14, R-SO19, R-SO22 (slice 022): the selected compiler for a command that holds the nightly. It replaces `ResolveBase.Loaded.selected`. The steps:
	##
	## | Step | Does |
	## | --- | --- |
	## | 1 | `request.frozen`, a header pin in a member, or `request.toolchain` set: no call. `loaded` stays (the pin and rank 2 are decisions of `Pin.decide`, and `--frozen` needs no compiler, R-SO22). |
	## | 2 | One `list_dirs!` of `<cache>/toolchains` (a missing dir is empty), `Compiler.installed`. Always (R-SO24 case 3: rank 6 can take the newest installed compiler). |
	## | 3 | `req` set (rank 4): one `read_files!` of `<cache>/toolchains/<id>/.talon.json` for each installed id, `Compiler.times`. Else no call. |
	## | 4 | `Compiler.select` with `argument` and `env` unset (a `tln` command has no rank 1, R-SO19), `has_toml` true when `request.project.toml` is `Ok`, the switch of `settings_of`. `Ok(sel)`: `selected` is `sel.id` and its rank (`Range`, `VersionFile`, `Default`, `Path`). Rank `Newest` (no `default-roc`): one line `note: <Compiler.newest_note>` on stderr, no file write. `Err(NoCompiler)`: `selected.id` is `Err(NoCompiler)` (`check_pin` fails with `Compiler.failure(NoCompiler)`, R-SO14). `Err(NoneInRange)`: the failure `Compiler.failure(NoneInRange(<range text>))` (R-SO13, exit 13). |
	select! : Fx, ResolveBase.Request, ResolveBase.Loaded => Try(ResolveBase.Loaded, Fail)
	select! = |fx, request, loaded| Ok(ResolveSelect.select_noted!(fx, request, loaded)?.loaded)

	## R-C16 (slice 084): `select!` with the note of a new rank 4 pick (`ranged!`) of a young compiler that only a pattern of `min-release-age-exclude` keeps visible. The flow prints it with the notes of the pin.
	select_noted! : Fx, ResolveBase.Request, ResolveBase.Loaded => Try({ loaded : ResolveBase.Loaded, note : Try(Str, [None]) }, Fail)
	select_noted! = |fx, request, loaded| {
		pinned = loaded.members.any(|m| m.locked.roc.is_ok())
		if request.frozen or pinned or request.toolchain.is_ok() {
			Ok({ loaded, note: Err(None) })
		} else {
			choose!(fx, request, loaded)
		}
	}

	## Slice 032b (E1, R-SO7, R-SO14): the compiler that ranks 4 to 7 select for a read-only command (`tln why`), with no download and no `ranged!`. It is steps 2 to 4 of `choose!`: the same calls and the same `Compiler.select`.
	## `request.compiler` is the `roc` on `PATH`. `NoCompiler` and `NoneInRange` (no installed compiler in the range) are `Err(None)`.
	peek! : Fx, ResolveBase.Request, ResolveBase.Loaded => Try(Str, [None])
	peek! = |fx, request, loaded| match picked!(fx, request, loaded, ResolveBase.settings_of(request, loaded)) {
		Ok(sel) => Ok(sel.id)
		Err(_) => Err(None)
	}

	# R-EV1, R-DT3, R-DT4: `--snapshot` wins over `[resolution] snapshot` of `talon.toml`. A `log:<n>` needs a registry: direct has none.
	snapshot_of : ResolveBase.Request, Intent -> Try(Try(U64, [None]), Fail)
	snapshot_of = |request, intent| match request.snapshot {
		Err(Unset) => Intent.direct_snapshot(intent.resolution.snapshot)
		Ok(text) => if text.starts_with("log:") {
			match U64.from_str(text.drop_prefix("log:")) {
				Ok(n) => Intent.direct_snapshot(Ok(Log(n)))
				Err(_) => Err(bad_snapshot(text))
			}
		} else {
			match Clock.parse_utc(text) {
				Ok(seconds) => Ok(Ok(seconds))
				Err(BadTime) => Err(bad_snapshot(text))
			}
		}
	}
}

# Steps 2 to 4 of `select!`.
choose! : Fx, ResolveBase.Request, ResolveBase.Loaded => Try({ loaded : ResolveBase.Loaded, note : Try(Str, [None]) }, Fail)
choose! = |fx, request, loaded| {
	settings = ResolveBase.settings_of(request, loaded)
	match picked!(fx, request, loaded, settings) {
		Ok(sel) => {
			if sel.rank == Newest {
				fx.err!("note: ${Compiler.newest_note(sel.id)}\n")
			}
			Ok({ loaded: { ..loaded, selected: { id: Ok(sel.id), from: rank_from(sel.rank) } }, note: Err(None) })
		}
		Err(NoCompiler) => Ok({ loaded: { ..loaded, selected: { id: Err(NoCompiler), from: Path } }, note: Err(None) })
		Err(NoneInRange) => ranged!(fx, request, loaded, settings)
	}
}

# The lists of the installed compilers (steps 2 and 3) and `Compiler.select` (step 4). `choose!` and `peek!` call it.
picked! : Fx, ResolveBase.Request, ResolveBase.Loaded, ResolveBase.Settings => Try({ id : Str, rank : Compiler.Rank, state : [Installed, Missing] }, [NoCompiler, NoneInRange])
picked! = |fx, request, loaded, settings| {
	req = loaded.intent.toolchain.roc
	has_toml = request.project.toml.is_ok()
	default = loaded.config.default_roc
	dir = Text.join(request.roots.cache, "toolchains")
	# R-SO24 case 3: the list is always read, as rank 6 may take the newest installed compiler.
	installed = match fx.list_dirs!([dir]) {
		[Ok(found)] => Compiler.installed(found)
		_ => []
	}
	times = if req.is_ok() and !installed.is_empty() {
		paths = installed.map(|id| Text.join(Text.join(dir, id), ".talon.json"))
		Compiler.times(installed.map2(fx.read_files!(paths), |id, text| { id, text }))
	} else {
		[]
	}
	Compiler.select({ argument: Err(Unset), env: Err(Unset), req, nightly: settings.nightly, has_toml, version_file: loaded.version_file, default, path: request.compiler.map_ok(|found| found.id), installed, times })
}

# R-SO13, R-DL5, R-DL10, R-SO19 (slice 025b): no installed compiler is in the range. The refusal comes first (no request). Then the list gives the newest compiler that the range allows,
# and it is held for the index. The download is the first probe (R-SO22). With `--no-check` no probe runs, so nothing is refused or downloaded.
ranged! : Fx, ResolveBase.Request, ResolveBase.Loaded, ResolveBase.Settings => Try({ loaded : ResolveBase.Loaded, note : Try(Str, [None]) }, Fail)
ranged! = |fx, request, loaded, settings| {
	text = loaded.intent.toolchain.roc_text ?? ""
	refused = Consent.auto_refuses({ auto: request.downloads.auto, yes: request.prompt.yes, flag: request.downloads.allow })
	if refused and !request.no_check return Err(Consent.range_refused(text))
	snapshot = ResolveSelect.snapshot_of(request, loaded.intent)?
	req = match loaded.intent.toolchain.roc {
		Ok(found) => found
		Err(Unset) => Any
	}
	switch = { nightly: settings.nightly, source: settings.nightly_from }
	picked = RocInstall.range_id!(fx, { roots: request.roots, net: request.net, now: request.now, offline: request.offline, req, req_text: text, min_age: settings.min_age, exclude: settings.exclude, snapshot, switch })?
	Ok({ loaded: { ..loaded, selected: { id: Ok(picked.id), from: Range } }, note: picked.note })
}

# A command has no rank 1 and rank 2 is a decision of `Pin.decide`, so `select` gives only these ranks.
rank_from : Compiler.Rank -> [Range, VersionFile, Default, Path]
rank_from = |rank| match rank {
	Range => Range
	VersionFile => VersionFile
	Default => Default
	Newest => Default
	_ => Path
}

bad_snapshot : Str -> Fail
bad_snapshot = |text| Fail.new(Usage, "--snapshot '${text}' is not a UTC time or log:<n>. Use a UTC time, for example 2026-10-12T00:00:00Z.")
