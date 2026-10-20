import Add
import Alias
import Answer
import Clock
import Consent
import Fail
import Fetch
import Frozen
import Fx
import Github
import Guard
import Ident
import Index
import Intent
import Ladder
import Item
import Locked
import Lookup
import Mode
import Net
import Pick
import Pin
import Project
import Prompt
import Ranges
import Ref
import Release
import Removal
import Report
import Roots
import Scan
import Scope
import Selector
import Text
import Vars
import header.Header
import semver.Semver

## The resolve flow of the P0 commands that resolve, in direct style over `Fx` (TESTING.md 2.2, part C). Slice 007 builds `install` and `update` on it
## (arguments, `--json`, `--dry-run`, `add`, `remove`, the probe ladder of slice 006). This slice tests it through the L2 entry `resolve`.
Resolve :: [].{

	## One run. `names` are the operands of `update` as typed (`json`, `json@^3`, `roc-lang/json`): `Ref.parse` and `Lookup.find` read them (slice 004).
	## `strategy` is `--strategy`. `nightly` is `TALON_NIGHTLY` (R-NS8). `compiler` is the id of the `roc` on `PATH` (R-PH8). `now` is `Clock.now`.
	Request : {
		command : [Install, Update],
		names : List(Str),
		frozen : Bool,
		no_check : Bool,
		project : Project,
		roots : Roots,
		net : Net.Settings,
		now : U64,
		offline : Bool,
		strategy : Try([Highest, Lowest], [Unset]),
		nightly : Try(Bool, [Unset]),
		compiler : Try(Str, [NoCompiler]),
		snapshot : Try(Str, [Unset]),
		dry_run : Bool,
		add : { as_platform : Bool, as_alias : Try(Str, [Unset]), no_pin : Bool },
		prompt : { mode : Mode, yes : Bool, quiet : Bool, rename_keys : Try(Answer, [NoFlag]) },
	}

	## Slice 007: the `install` command of `Install.run!` (also `add` and `i`). The same flow as `run!` with the changes of slice 007, and the facts for `--json`.
	## `run!` is this flow too: it prints the same lines and gives `{}`. The new fields of `Request`:
	##
	## | Field | Holds |
	## | --- | --- |
	## | `snapshot` | `--snapshot` (R-FL9). A flag has priority over `[resolution] snapshot` of `talon.toml` (R-EV1). `Intent.direct_snapshot` checks it: `log:<n>` is a usage failure with `direct`. |
	## | `dry_run` | `--dry-run` (R-LF4): the probes run, the files are not written, the lines are the same and the last line is `dry run: nothing was written` |
	## | `add` | `--platform`, `--as`, `--no-pin` for the names of `install` (R-AD25 to R-AD33) |
	## | `prompt` | The facts for `Prompt.ask!` (R-NI1): the mode (`Mode.from_env`), `--yes`, `--quiet`, `--rename-keys` |
	##
	## `names` of `install` are the refs to add (slice 007, R-SP18: with names the command is `tln add`). `run!` calls `install!` and drops the outcome.
	##
	## The flow of `install!` is the flow of `run!` of slice 005 and 006 (the steps A to J) with these changes, in this order (the L3 cases `add/*` and `install/*` and the L2 cases `install/*` and `resolve/rs-*` fix them):
	##
	## | # | Step | Rule |
	## | --- | --- | --- |
	## | 1 | `--frozen`: the check of slice 005, then an `Outcome` with no change (`probes` 0, `check` and `build` `NotRun`, `at` is `now`). No index call, no write. | R-LF1 |
	## | 2 | Each name of `install` is read with `Ref.parse` (scope `Install`) and `Lookup.find`. A name that is a header alias, or a full name that has exactly one variable in the header (one repo, one entry), is an entry of the header. `Add.decide_alias` decides: no selector or `latest` is `Keep` (the `Outcome.kept` row and the note, no index call, no probe), a selector is `Update` (the named variable is free, as `update X@sel`, and `talon.toml` gets the key of `Add.decide_alias`). With `--platform` the full name is always a new entry (the platform entry is replaced, R-AD31). A full name of a platform entry without `--platform` is the failure of R-AD33. | R-AD1, R-AD2, R-AD6, R-AD20 to R-AD22, R-SL5, R-AD33 |
	## | 3 | A full name that the member does not have, and that other members hold (one variable, no entry in the current member): `Add.check_held` (question Q9: exit 10, nothing is written). With no failure the new entry gets the held version: the range of the index is `=<highest held version>`. | R-WS12, Q9 |
	## | 4 | Another full name is a new entry. `Add.decide` gives the alias, with the key `--as` or `Alias.default` for the want | R-AD8 to R-AD19, R-AD30 |
	## | 5 | A stale key of `talon.toml` (a want that `Vars` marks stale) of `install` and `add`: print `Consent.rename_keys(...).report` on stderr, then `Prompt.ask!` with `flag: request.prompt.rename_keys`. `Yes` makes a rename of the key to the alias of the header (`Intent.rename` at the write). `No` keeps the key. A failure (exit 13) stops the command before the index call. `update` keeps the warning of slice 005. | R-NI1, R-I8, R-I9 |
	## | 6 | The index of each free variable and each new name. A new name needs a candidate that the selector admits: else `Add.no_release` (usage, exit 2) before any pick. | R-SL12, R-SL3, R-SL4 |
	## | 7 | The kind of the newest candidate of a new name (the header of its package is read): `--platform` and a package is `'<name>' is not a platform`, a platform and no `--platform` is `'<name>' is a platform. Use tln add --platform <name>.` (usage, exit 2), before the pick. The pick of the new name is a slot with the range of the selector (`*` for none, `latest`). With `--platform` the platform variable of the header is not a slot. | R-AD32, R-AD33, R-C4 |
	## | 8 | The pick (`Pick.step`, slice 005). The header edits: `Add.decide` of each new name: `Insert` is a new entry (line `+ <alias>: <name> <version>`), `Replace` is the platform entry under its alias (line `~ <alias>: <name> <old> -> <new>` and the note `platform changes: ...`: the notes are printed as `note: <text>` and are `Outcome.notes`). The `talon.toml` writes are the `toml` of `Add.decide` (R-AD23 to R-AD28). | R-AD23 to R-AD31, R-SE7 |
	## | 9 | The ladder (slice 006) when a header changes, and not `--no-check`. `probes` of the `Outcome`: 3 for each app, 2 for each package or platform. `check` and `build` are `Passed`, or `Skipped` with `--no-check`, else `NotRun` (`build` is `NotRun` when no member is an app). | R-LD4, R-LD5, R-LF3 |
	## | 10 | The write (`write!`): the second read, `Guard.check_all` over the header files and the `talon.toml` files (the spans of the renamed keys are compared too), the rename after the key writes, one `write_atomic!` call. With `--dry-run` there is no read and no write: the lines of the plan are the same. "nothing to change" is printed when no file changes and no entry was kept. | R-CC7, R-LF4 |
	##
	## `Outcome.written` are the files that were written (`[]` for `--dry-run` and for no change). `added`, `moved`, `pinned`, `toml` and `renamed` are the planned changes for `--dry-run` and the written changes otherwise, and empty for a run that wrote nothing. The lines of stdout: the notes of the scope, the `note:` lines, the notes of the kept entries, the lines of the ladder, then the file lines (`<path>`, `  + ...`, `  ~ ...`, `<path>: <key> = "<value>"`, `<path>: key <from> -> <to>`).
	install! : Fx, Request => Try(Report.Outcome, Fail)
	install! = |fx, request| {
		loaded = load!(fx, request)?
		built = Vars.build({ members: loaded.members, priority: loaded.intent.resolution.priority })?
		settings = settings_of(request, loaded.intent)
		decision = Pin.decide({
			members: loaded.members.map(|m| { file: m.file, pin: m.locked.roc, changes: Bool.False }),
			compiler: request.compiler,
			req: loaded.intent.toolchain.roc,
			nightly: settings.nightly,
			no_check: request.no_check,
		})?
		if request.frozen {
			frozen!(fx, request, loaded, built, decision)?
			Ok(idle(request, request.now))
		} else {
			resolve!(fx, request, loaded, built, decision)
		}
	}

	## Slice 008: the flow of `remove` (`Remove.run!`, also `rm`: R-CM3, R-RV1 to R-RV5, R-WS12). It resolves nothing: no index call, no pick, no fetch, no `Vars.build`. The `Request` is the one that `install!` takes. The fields that `remove` reads are
	## `project`, `roots`, `now` (not used), `compiler`, `nightly`, `no_check` and `dry_run`. `names` of the `Request` is not used: `facts.names` are the operands of `remove`, `facts.force` is `--force`.
	## The flow changes the one current member (R-WS12). Other members are read (the key rule of step 3) and never written. The steps, in order (the L2 case `remove/rm1-flow` and the L3 cases `remove/*` fix them):
	##
	## | # | Step | Rule |
	## | --- | --- | --- |
	## | 1 | `load!`: one `read_files!` call for the member files and the `talon.toml` candidates (as `install!`) | R-PD6 |
	## | 2 | Each name: `Ref.parse` (scope `Project`), then `Lookup.find` over the entries of the header of the current member. One entity for each row: `alias`, `name` (the full name of a release, else the value of a path or foreign row), `note` (`platform (<alias>)` for the platform row). A failure is returned (its block goes to stderr first), `New(name)` is the usage failure `'<name>' is not in the project`. Names that give one entry count once. | R-SC1, R-SC6 to R-SC8 |
	## | 3 | `Removal.plan` for each entry (all names are checked before the scan, so one platform name stops the run with no other effect). `toml` is the nearest `talon.toml` of the member (path and text) or `Err(NoToml)`. `shared` is true when another member under the dir of that `talon.toml` has the alias in its header (question Q3). | R-RV3, R-RV4, R-RV5, R-WS14 |
	## | 4 | The scan: `Scan.roots` (for a package or a platform file `exposed` is `Header.exposed` of the header), then `Scan.level` for each import level until `next` is empty. A level is one `read_files!` call: the files that are not in the first read (the member file is) and are listed in `next` or `roots`. A file that cannot be read is skipped, no failure (question Q7). No call when there is no file to read. The scan runs also with `--no-check`. `Scan.level` is called once for each alias. | R-RV2, R-LD7 |
	## | 5 | A hit and no `--force`: failure of kind `AppError` (exit 11). The message lists each import line (the text is in the slice file, "Output"). Nothing is written. No ladder call. | R-RV2, R-EC11 |
	## | 6 | `Pin.decide` with `changes` true for the current member only, and `no_check` true for `--no-check` and for a forced run. When the check runs, `check_pin` as in `install!` (not tested for `remove`). | R-RP2, R-RP3, R-H6 |
	## | 7 | With hits (forced): the line `note: <alias> is still imported in <n> line(s). The app cannot check until you change the imports.` for each alias, on `out!`. It is in `Outcome.notes` too. | R-RV2 |
	## | 8 | The ladder, when the check runs (not `--no-check`, not a forced run): `Ladder.run!` with one member (the current member, its text, `ops`: a `Remove(alias)` for each entry, then the `Pin` of the decision), `owners` (the release rows of the header that stay, with `Ident.hash`, name and version), `moved` empty. A `NoTuple` failure has the text of the ladder, then ` tln remove moves no other entry. Pass --no-check to remove <alias>[, <alias>] anyway.` With `--no-check` the line `check: skipped` is printed and `probes` is 0. A forced run prints no check line. `probes` is 3 for an app, 2 for a package or a platform. | R-RV1, R-LD4, R-LD5, R-PH10, R-LF3 |
	## | 9 | The write: with `--dry-run` no read and no write. Else the second read (the `talon.toml` first, then the header), `Guard.check_all` (the spans of `Locked.spans` and of `Intent.table_spans`), `Locked.edit`, `Intent.remove`, and one `write_atomic!` call in the `Guard` order. | R-CC7, R-CC1, R-LF4 |
	## | 10 | The lines, on `out!`: the path of the header, `  - <alias>: <what>` for each entry, `  + roc: <id>` for a pin write, then `<talon.toml path>: - [<table>] <key>` for each key, then `kept: <dir> (the patch files of <alias>)` for each patch dir. They are printed also with `--dry-run`. | R-LF4, R-RV4 |
	##
	## `Outcome.written` is `[]` for `--dry-run` and for a failure. `removed`, `toml`, `patches` and `pinned` are the planned changes for `--dry-run`, and the written changes otherwise.
	remove! : Fx, Request, { names : List(Str), force : Bool } => Try(Report.RemoveOutcome, Fail)
	remove! = |fx, request, facts| {
		loaded = load!(fx, request)?
		current = request.project.file ?? ""
		member = match loaded.members.find_first(|m| m.file == current) {
			Ok(m) => m
			Err(_) => return Err(Fail.new(Usage, "no current member: pass --file <member file>"))
		}
		plans = removal_plans!(fx, loaded, member, facts.names)?
		aliases = plans.map(|p| p.alias)
		imported = import_hits!(fx, loaded, member, aliases)
		if !imported.is_empty() and !facts.force return Err(Fail.new(AppError, imports_text(imported)))
		forced = !imported.is_empty()
		skip_check = request.no_check or forced
		settings = settings_of(request, loaded.intent)
		decision = Pin.decide({
			members: loaded.members.map(|m| { file: m.file, pin: m.locked.roc, changes: m.file == current }),
			compiler: request.compiler,
			req: loaded.intent.toolchain.roc,
			nightly: settings.nightly,
			no_check: skip_check,
		})?
		if !skip_check check_pin(loaded.intent, settings, decision)?
		force_notes = imported.map(|h| still_imported(h))
		for note in force_notes {
			fx.out!("note: ${note}\n")
		}
		pins = decision.writes.keep_if(|w| w.file == current)
		ops : List(Locked.Op)
		ops = aliases.map(|alias| Remove(alias)).concat(pins.map(|w| Pin(w.id)))
		ran = if skip_check {
			if request.no_check fx.out!("check: skipped\n")
			{ probes: 0, check: Skipped, build: Skipped, notes: [] }
		} else {
			removal_ladder!(fx, request, loaded, member, { aliases, ops, decision })?
		}
		keys = plans.join_map(|p| p.plan.keys)
		toml = member_toml(loaded, member)
		written = write_removal!(fx, request, loaded, { file: current, ops, toml, keys })?
		toml_path = match toml {
			Ok(t) => t.path
			Err(NoToml) => ""
		}
		removed_rows = plans.map(|p| removed_of(p.alias, p.plan.what))
		toml_rows = keys.map(|k| { path: toml_path, table: Intent.table_name(k.table), key: k.key })
		patches = plans.keep_oks(|p| p.plan.patch_dir.map_ok(|dir| { alias: p.alias, dir }))
		fx.out!("${current}\n")
		for r in removed_rows {
			fx.out!("  - ${r.alias}: ${removed_text(r)}\n")
		}
		for w in pins {
			fx.out!("  + roc: ${w.id}\n")
		}
		for t in toml_rows {
			fx.out!("${t.path}: - [${t.table}] ${t.key}\n")
		}
		for p in patches {
			fx.out!("kept: ${p.dir} (the patch files of ${p.alias})\n")
		}
		Ok({
			probes: ran.probes,
			dry_run: request.dry_run,
			check: ran.check,
			build: ran.build,
			removed: removed_rows,
			toml: toml_rows,
			patches,
			pinned: match pins {
				[w, ..] => Ok(w.id)
				[] => Err(None)
			},
			notes: force_notes.concat(ran.notes),
			written,
		})
	}

	## See the slice file 005, "The flow of `Resolve.run!`". It is `install!` with the outcome dropped.
	run! : Fx, Request => Try({}, Fail)
	run! = |fx, request| {
		_ = install!(fx, request)?
		Ok({})
	}
}

Fact : { url : Str, release : Release }

Loaded : {
	members : List(Vars.Member),
	headers : List({ path : Str, text : Str }),
	tomls : List({ path : Str, text : Str }),
	intent : Intent,
}

Settings : { nightly : Bool, strategy : [Highest, Lowest], min_age : U64 }

# What a planned change did, for `Report.Outcome` (the line of a change is in `Edit.line`).
Did : [Added(Report.Entry), Moved({ alias : Str, from : { name : Str, version : Str }, to : { name : Str, version : Str } }), Pinned(Str)]

# One planned change of a header, with its line of output (R-OUT2: the texts are a proposal).
Edit : { file : Str, op : Locked.Op, line : Str, did : Did }

Pair : { path : Str, key : Str, value : Str }

# A stale key of `talon.toml` that the person agreed to rename (R-NI1).
Rename : { path : Str, from : Str, to : Str }

Candidates : { name : Str, list : List(Index.Candidate), missing : Bool }

# An entry of the header that `add` found and keeps (R-AD21).
Kept : { alias : Str, name : Str, version : Str, note : Str }

# A new name of `add`: `range` is what the pick uses (`*` with no selector, the held version for a group that another member holds, Q9).
Fresh : { name : Str, selector : Try(Selector, [None]), text : Str, range : Str, key : Str, is_platform : Bool }

Asked : { names : List(Str), picks : List({ alias : Str, selector : Selector }), kept : List(Kept), fresh : List(Fresh) }

Row : { alias : Str, url : Str, is_platform : Bool }

# A new name with the candidates of its URL form and the kind of its newest candidate (R-AD32, R-AD33).
FreshRow : { fresh : Fresh, list : List(Index.Candidate) }

Prepared : { rows : List(FreshRow), facts : List(Fact) }

# The outcome of a run that changes nothing (`--frozen`, R-LF1).
idle : Request, U64 -> Report.Outcome
idle = |request, at| {
	at: Clock.format_utc(at),
	probes: 0,
	dry_run: request.dry_run,
	check: NotRun,
	build: NotRun,
	added: [],
	moved: [],
	kept: [],
	pinned: Err(None),
	toml: [],
	renamed: [],
	notes: [],
	written: [],
}

# `--frozen` (R-LF1): the pure check, then the hash check of the packages of the header. No index call, no write.
frozen! : Fx, Resolve.Request, Loaded, { vars : List(Vars.Var), wants : List(Vars.Want) }, Pin.Decision => Try({}, Fail)
frozen! = |fx, request, loaded, built, decision| {
	settings = settings_of(request, loaded.intent)
	scoped = Vars.scope({ command: Install, names: [], selectors: [], vars: built.vars })?
	Frozen.check({ scoped, wants: built.wants, outside: decision.outside, req_text: loaded.intent.toolchain.roc_text, nightly: settings.nightly })?
	urls = built.vars.join_map(|v| v.uses.map(|u| u.url)).fold([], |found, url| if found.contains(url) found else found.append(url))
	_ = read_releases!(fx, request, urls, Bool.False)?
	fx.out!("the header satisfies talon.toml\n")
	Ok({})
}

# `install`, `update` and `add`: the steps of the flow in the slice file.
resolve! : Fx, Resolve.Request, Loaded, { vars : List(Vars.Var), wants : List(Vars.Want) }, Pin.Decision => Try(Report.Outcome, Fail)
resolve! = |fx, request, loaded, built, decision| {
	settings = settings_of(request, loaded.intent)
	check_pin(loaded.intent, settings, decision)?
	snapshot = snapshot_of(request, loaded.intent)?
	asked = asked!(fx, request, loaded, built.vars)?
	# A named header entry is moved as `update X@sel` does it (R-AD22).
	command = if request.command == Install and asked.names.is_empty() Install else Update
	everyone = Vars.scope({
		command,
		names: asked.names,
		selectors: asked.picks.keep_oks(|p| range_of_selector(p.selector).map_ok(|range| { alias: p.alias, range })),
		vars: built.vars,
	})?
	# `--platform` replaces the platform entry, so the old platform is no variable of the pick (R-AD31).
	scoped = if request.add.as_platform and !asked.fresh.is_empty() everyone.keep_if(|s| !s.variable.is_platform) else everyone
	for s in scoped {
		match s.note {
			Ok(note) => fx.out!("${note}\n")
			Err(None) => {}
		}
	}
	stale = live_wants!(fx, request, built.wants)?
	free_names = scoped.keep_if(|s| s.free).keep_oks(|s| s.variable.name.map_err(|_| None))
	want_names = stale.live.keep_oks(|w| w.name.map_err(|_| None))
	known = built.vars.join_map(|v| v.uses.map(|u| u.url))
	repos = free_names.concat(want_names).concat(asked.fresh.map(|f| f.name)).fold(no_names, |found, name| if found.contains(name) found else found.append(name))
	found = index!(fx, request, repos, known)?
	prepared = prepare!(fx, request, loaded, asked.fresh, found)?
	input = slots_of(scoped, stale.live, found, asked, prepared.rows, settings, snapshot)
	chosen = pick_loop!(fx, request, input, prepared.facts)?
	finish!(fx, request, loaded, { scoped, wants: stale.live, asked, prepared, renames: stale.renames, snapshot }, chosen)
}

settings_of : Resolve.Request, Intent -> Settings
settings_of = |request, intent| {
	strategy = match request.strategy {
		Ok(s) => s
		Err(Unset) => intent.resolution.strategy ?? Highest
	}
	{
		nightly: match request.nightly {
			Ok(b) => b
			Err(Unset) => intent.toolchain.nightly ?? Bool.True
		},
		strategy,
		min_age: intent.resolution.min_release_age ?? 172800,
	}
}

# R-RP2, R-NS5, Q3: a pin that stops the command, and the missing compiler.
check_pin : Intent, Settings, Pin.Decision -> Try({}, Fail)
check_pin = |intent, settings, decision| match decision.outside {
	Ok(pin) => Err(Pin.outside_failure({ pin, req_text: intent.toolchain.roc_text, nightly: settings.nightly }))
	Err(None) => match decision.held {
		Ok(_) => Ok({})
		Err(NoCompiler) => Err(Fail.new(Environment, "cannot select a compiler: there is no roc on PATH that Talon can identify, and the header has no roc pin"))
	}
}

# R-EV1, R-DT3, R-DT4: `--snapshot` wins over `[resolution] snapshot` of `talon.toml`. A `log:<n>` needs a registry: direct has none.
snapshot_of : Resolve.Request, Intent -> Try(Try(U64, [None]), Fail)
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

bad_snapshot : Str -> Fail
bad_snapshot = |text| Fail.new(Usage, "--snapshot '${text}' is not a UTC time or log:<n>. Use a UTC time, for example 2026-10-12T00:00:00Z.")

# Step A of the flow: the member files and the `talon.toml` candidates in one `read_files!` call (R-PD6).
load! : Fx, Resolve.Request => Try(Loaded, Fail)
load! = |fx, request| {
	files = member_files(request.project)?
	root = match request.project.workspace {
		Ok(ws) => ws.root
		Err(Standalone) => files.first().map_ok(|f| Text.dir_of(f)) ?? ""
	}
	candidates = files.map(|f| Intent.paths({ member: f, root }))
	toml_paths = candidates.join_map(|c| c).fold([], |found, path| if found.contains(path) found else found.append(path))
	results = fx.read_files!(files.concat(toml_paths))
	headers = files.map2(results.take_first(files.len()), |path, result| (path, result))
	toml_results = toml_paths.map2(results.drop_first(files.len()), |path, result| (path, result))
	var $texts = no_texts
	for (path, result) in headers {
		match result {
			Ok(text) => {
				$texts = $texts.append({ path, text })
			}
			Err(_) => return Err(Fail.new(Environment, "cannot read ${path}"))
		}
	}
	var $tomls = no_texts
	for (path, result) in toml_results {
		match result {
			Ok(text) => {
				$tomls = $tomls.append({ path, text })
			}
			Err(NotFound) => {}
			Err(_) => return Err(Fail.new(Environment, "cannot read ${path}"))
		}
	}
	root_toml = Text.join(root, "talon.toml")
	var $intents = no_intents
	for t in $tomls {
		role = match request.project.workspace {
			Ok(_) => if t.path == root_toml Root else Member
			Err(Standalone) => Root
		}
		read = Intent.read({ path: t.path, text: t.text, role })?
		for w in read.warnings {
			fx.err!("warning: ${w}\n")
		}
		$intents = $intents.append({ path: t.path, intent: read.intent })
	}
	members = files.map2(
		candidates,
		|file, paths| {
			locked = match $texts.find_first(|t| t.path == file) {
				Ok(t) => Locked.read({ path: file, text: t.text })
				Err(_) => Err(Fail.new(Environment, "cannot read ${file}"))
			}
			toml = match paths.find_first(|p| $intents.any(|i| i.path == p)) {
				Ok(p) => match $intents.find_first(|i| i.path == p) {
					Ok(i) => Ok({ path: i.path, intent: i.intent })
					Err(_) => Err(NoToml)
				}
				Err(_) => Err(NoToml)
			}
			(file, locked, toml)
		},
	)
	checked = members.map_try(|(file, locked, toml)| locked.map_ok(|l| { file, locked: l, toml }))?
	settings_path = match request.project.workspace {
		Ok(_) => root_toml
		Err(Standalone) => files.first().map_ok(|f| Text.join(Text.dir_of(f), "talon.toml")) ?? ""
	}
	intent = match $intents.find_first(|i| i.path == settings_path) {
		Ok(i) => i.intent
		Err(_) => empty_intent({})?
	}
	Ok({ members: checked, headers: $texts, tomls: $tomls, intent })
}

no_texts : List({ path : Str, text : Str })
no_texts = []

no_intents : List({ path : Str, intent : Intent })
no_intents = []

# The intent of a missing `talon.toml`: the read of the empty text.
empty_intent : {} -> Try(Intent, Fail)
empty_intent = |_| Intent.read({ path: "talon.toml", text: "", role: Root }).map_ok(|r| r.intent)

# R-PD5: the members of a workspace, or the current file of a standalone project.
member_files : Project -> Try(List(Str), Fail)
member_files = |project| match project.workspace {
	Ok(ws) => if ws.members.is_empty() Err(Fail.new(Usage, "the workspace at ${ws.root} has no member files")) else Ok(ws.members)
	Err(Standalone) => match project.file {
		Ok(file) => Ok([file])
		Err(NoCurrent) => Err(Fail.new(Usage, "no project file found. Pass --file <path>."))
	}
}

# The names of `update` and `install` (slice 004: `Ref.parse`, `Lookup.find`). A name of `update` is an alias of the project. A name of `install` is `tln add`
# (R-SP18): a header alias, or a full name that has one entry in the current member (D5), or a new entry.
asked! : Fx, Resolve.Request, Loaded, List(Vars.Var) => Try(Asked, Fail)
asked! = |fx, request, loaded, vars| {
	current = request.project.file ?? ""
	scope = if request.command == Update Scope.Project else Scope.Install
	rows = current_rows(loaded.members, current)
	entities = if request.command == Update entities_of(vars) else entities_of(in_file(vars, current))
	var $names = no_names
	var $picks = no_picks
	var $kept = no_kept
	var $fresh = no_fresh
	for text in request.names {
		ref = Ref.parse(text, scope, Bool.False)?
		found = match Lookup.find(scope, ref, entities) {
			Ok(f) => f
			Err({ fail, block }) => {
				if !block.is_empty() fx.err!(block)
				return Err(fail)
			}
		}
		target = match found {
			Lookup.Existing({ alias: a, .. }) => Ok(a)
			Lookup.New(name) => if request.command == Update {
				return Err(Fail.new(Usage, "'${name}' is not in the project"))
			} else {
				entry_of_repo(request, vars, current, name)?
			}
		}
		match target {
			Ok(alias) => if request.command == Update {
				$names = $names.append(alias)
				match ref.selector {
					Ok(selector) => {
						$picks = $picks.append({ alias, selector })
					}
					Err(None) => {}
				}
			} else {
				plan = Add.decide_alias({ alias, selector: ref.selector, no_pin: request.add.no_pin, header: rows })?
				match plan.header {
					Keep => {
						$kept = $kept.append(kept_of(vars, current, alias, plan.note ?? ""))
					}
					_ => {
						$names = $names.append(alias)
						match ref.selector {
							Ok(selector) => {
								$picks = $picks.append({ alias, selector })
							}
							Err(None) => {}
						}
					}
				}
			}
			Err(New) => {
				$fresh = $fresh.append(fresh_of(request, vars, current, ref, text)?)
			}
		}
	}
	Ok({ names: $names, picks: $picks, kept: $kept, fresh: $fresh })
}

# The rows of the header of the current member, for `Add.decide`.
current_rows : List(Vars.Member), Str -> List(Row)
current_rows = |members, file| match members.find_first(|m| m.file == file) {
	Ok(m) => m.locked.rows.map(|r| { alias: r.alias, url: r.value, is_platform: r.is_platform })
	Err(_) => []
}

# The variables with their uses in one member file only.
in_file : List(Vars.Var), Str -> List(Vars.Var)
in_file = |vars, file| vars.keep_if(|v| v.uses.any(|u| u.file == file)).map(|v| { ..v, uses: v.uses.keep_if(|u| u.file == file) })

# D5: a full name that has one entry in the current member is that entry. `--platform` and `--as` always make a new entry. A platform entry needs `--platform` (R-AD33).
entry_of_repo : Resolve.Request, List(Vars.Var), Str, Str -> Try(Try(Str, [New]), Fail)
entry_of_repo = |request, vars, current, name| {
	same = in_file(vars, current).keep_if(|v| v.name == Ok(name))
	match same {
		[one] if !request.add.as_platform and request.add.as_alias == Err(Unset) => if one.is_platform {
			Err(Fail.new(Usage, "'${name}' is a platform. Use tln add --platform ${name}."))
		} else {
			match one.uses.first() {
				Ok(u) => Ok(Ok(u.alias))
				Err(_) => Ok(Err(New))
			}
		}
		_ => Ok(Err(New))
	}
}

# The `Kept` row of a header alias: its name and version are those of its entry in the current member.
kept_of : List(Vars.Var), Str, Str, Str -> Kept
kept_of = |vars, current, alias, note| match in_file(vars, current).find_first(|v| v.uses.any(|u| u.alias == alias)) {
	Ok(v) => {
		version = match v.uses.find_first(|u| u.alias == alias) {
			Ok(u) => u.version
			Err(_) => ""
		}
		{ alias, name: v.name ?? v.group.form, version, note }
	}
	Err(_) => { alias, name: alias, version: "", note }
}

# A new name of `add`. Q9: a group that another member holds (one variable, no entry in the current member) must admit the held versions, and then the entry gets the highest of them.
fresh_of : Resolve.Request, List(Vars.Var), Str, Ref, Str -> Try(Fresh, Fail)
fresh_of = |request, vars, current, ref, text| {
	name = ref.name
	typed = match ref.selector {
		Ok(selector) => range_of_selector(selector) ?? "*"
		Err(None) => "*"
	}
	range = match vars.keep_if(|v| v.name == Ok(name)) {
		[one] if !one.uses.any(|u| u.file == current) => {
			held = one.uses.map(|u| { file: u.file, version: u.version })
			Add.check_held({ name, range: typed, held })?
			"=${highest_version(held.map(|h| h.version))}"
		}
		_ => typed
	}
	Ok({
		name,
		selector: ref.selector,
		text: match text.split_first("@") {
			Ok({ after, .. }) => after
			Err(_) => "latest"
		},
		range,
		key: match request.add.as_alias {
			Ok(alias) => alias
			Err(Unset) => if request.add.as_platform "pf" else Alias.default(name)
		},
		is_platform: request.add.as_platform,
	})
}

# The highest of some versions (the first one when none parses).
highest_version : List(Str) -> Str
highest_version = |versions| match versions {
	[first, .. as rest] => rest.fold(
		first,
		|best, v| match (Semver.parse(v), Semver.parse(best)) {
			(Ok(a), Ok(b)) => if a.order_relative_to(b) == After v else best
			_ => best
		},
	)
	[] => ""
}

no_names : List(Str)
no_names = []

no_picks : List({ alias : Str, selector : Selector })
no_picks = []

no_kept : List(Kept)
no_kept = []

no_fresh : List(Fresh)
no_fresh = []

# The entities of the lookup: one for each header alias, the name with its series when 2 variables share a repo (R-SC15).
entities_of : List(Vars.Var) -> List({ alias : Str, name : Str, note : Str })
entities_of = |vars| {
	base = |v| v.name ?? v.group.form
	vars.join_map(
		|v| {
			shared = vars.keep_if(|o| base(o) == base(v)).len() >= 2
			name = if shared "${base(v)}@${v.group.series}" else base(v)
			v.uses
				.map(|u| { alias: u.alias, name, note: if v.is_platform "platform (${u.alias})" else "" })
				.fold([], |found, e| if found.any(|f| f.alias == e.alias) found else found.append(e))
		},
	)
}

# R-SL5, R-AD22: the range that a selector gives to its variable. `Latest` is any version.
range_of_selector : Selector -> Try(Str, [None])
range_of_selector = |selector| match selector {
	Exact(version) => Ok("=${version}")
	Range(text) => Ok(text)
	Latest => Ok("*")
	_ => Err(None)
}

# R-I5, R-I8, R-NI1 (D8): a stale key of `[dependencies]` is the prompt of `install` and `add`: the report, then the question. `Yes` renames the key
# at the write, `No` keeps it. `update` and a stale key of `[overrides]` keep the warning. A key with a short name has no index (R-AD6).
live_wants! : Fx, Resolve.Request, List(Vars.Want) => Try({ live : List(Vars.Want), renames : List(Rename) }, Fail)
live_wants! = |fx, request, wants| {
	var $live = no_wants
	var $ask = no_wants
	for w in wants {
		match w.stale {
			Ok(alias) => if request.command == Install and w.table == Dependencies {
				$ask = $ask.append(w)
			} else {
				fx.err!("warning: ${w.from}: the key \"${w.key}\" names ${w.name ?? w.key}, which the header has as \"${alias}\"\n")
			}
			Err(None) => match w.name {
				Err(Short(text)) => return Err(short_failure(w.from, text))
				Ok(_) => {
					$live = $live.append(w)
				}
			}
		}
	}
	Ok({ live: $live, renames: ask_rename!(fx, request, $ask)? })
}

ask_rename! : Fx, Resolve.Request, List(Vars.Want) => Try(List(Rename), Fail)
ask_rename! = |fx, request, stale| {
	if stale.is_empty() return Ok([])
	consent = Consent.rename_keys(stale.map(|w| { key: w.key, name: w.name ?? w.key, alias: w.stale ?? "" }))
	fx.err!(consent.report)
	done = Prompt.ask!(fx, consent.prompt, { mode: request.prompt.mode, yes: request.prompt.yes, quiet: request.prompt.quiet, flag: request.prompt.rename_keys })?
	if done.answer == Yes {
		Ok(
			stale.map(
				|w| {
					path = match w.from.split_last(":") {
						Ok({ before, .. }) => before
						Err(_) => w.from
					}
					{ path, from: w.key, to: w.stale ?? "" }
				},
			),
		)
	} else {
		Ok([])
	}
}

no_wants : List(Vars.Want)
no_wants = []

short_failure : Str, Str -> Fail
short_failure = |from, text| match Ref.parse(text, Scope.Install, Bool.False) {
	Err(fail) => Fail.new(fail.kind, "${from}: ${fail.message}")
	Ok(ref) => match Lookup.find(Scope.Install, ref, []) {
		Err({ fail, .. }) => Fail.new(fail.kind, "${from}: ${fail.message}")
		Ok(_) => Fail.new(Usage, "${from}: '${text}' is a short name, and GitHub has no index of short names. Use the full name (owner/repo).")
	}
}

# The pages of each repo that a free variable or a want needs (R-SP1: a held variable needs no index call), as candidates (R-DI3 to R-DI5).
index! : Fx, Resolve.Request, List(Str), List(Str) => Try(List(Candidates), Fail)
index! = |fx, request, names, known| {
	var $found = no_candidates
	var $oldest = Err(None)
	for name in names {
		(owner, repo) = match name.split_on("/") {
			[o, r] => (o, r)
			_ => return Err(Fail.new(Usage, "'${name}' is not on github.com: an index of other hosts needs a registry (--registry)"))
		}
		fetched = Github.releases!(fx, { net: request.net, roots: request.roots, owner, repo, now: request.now, offline: request.offline })?
		match fetched.source {
			Cached(t) => {
				$oldest = match $oldest {
					Ok(old) if old <= t => Ok(old)
					_ => Ok(t)
				}
			}
			_ => {}
		}
		match Index.candidates({ owner, repo, pages: fetched.pages, known }) {
			Ok({ list, warnings }) => {
				for w in warnings {
					fx.err!("warning: ${w}\n")
				}
				$found = $found.append({ name, list, missing: fetched.source == Missing })
			}
			Err(BadPage(n)) => return Err(Fail.new(Network, "the release list of ${name} (page ${n.to_str()}) is not a list of releases"))
		}
	}
	match $oldest {
		Ok(t) => fx.err!("${Github.offline_line(t)}\n")
		Err(None) => {}
	}
	Ok($found)
}

no_candidates : List(Candidates)
no_candidates = []

PickInput : {
	slots : List(Pick.Slot),
	strategy : [Highest, Lowest],
	min_age : U64,
	snapshot : Try(U64, [None]),
	want_slots : List({ key : Str, name : Str, urls : List(Str) }),
}

# The slots of `Pick.step`: the variables in order, then the wants (R-VA6), then the new names of `add`.
slots_of : List(Vars.Scoped), List(Vars.Want), List(Candidates), Asked, List(FreshRow), Settings, Try(U64, [None]) -> PickInput
slots_of = |scoped, wants, found, asked, fresh, settings, snapshot| {
	candidates_of = |name| match found.find_first(|c| c.name == name) {
		Ok(c) => c
		Err(_) => { name, list: [], missing: Bool.True }
	}
	var_slots = scoped.map(
		|s| {
			v = s.variable
			cands = match v.name {
				Ok(name) => {
					c = candidates_of(name)
					group = if s.any_series c.list.keep_if(|x| x.ident.group.form == v.group.form) else Index.in_group({ list: c.list, group: v.group })
					{ list: group, missing: c.missing }
				}
				Err(NoName) => { list: [], missing: Bool.True }
			}
			named = asked.picks.find_first(|p| v.uses.any(|u| u.alias == p.alias)) ?? { alias: "", selector: Latest }
			{
				id: match v.uses.first() {
					Ok(u) => u.alias
					Err(_) => ""
				},
				is_platform: v.is_platform,
				ranges: v.ranges.map(|r| r.range),
				current: highest_use(v.uses),
				free: s.free and !cands.missing,
				named: match named.selector {
					Exact(version) if s.any_series => Ok(version)
					_ => Err(None)
				},
				candidates: cands.list,
			}
		},
	)
	want_slots = wants.map(
		|w| {
			name = w.name ?? w.key
			list = match Index.new_entry({ name, list: candidates_of(name).list }) {
				Ok(entry) => entry.list
				Err(NoCandidate) => []
			}
			{ id: w.key, is_platform: Bool.False, ranges: [w.range], current: Err(None), free: Bool.True, named: Err(None), candidates: list }
		},
	)
	fresh_slots = fresh.map(
		|row| {
			id: row.fresh.key,
			is_platform: row.fresh.is_platform,
			ranges: [row.fresh.range],
			current: Err(None),
			free: Bool.True,
			named: match row.fresh.selector {
				Ok(Exact(version)) => Ok(version)
				_ => Err(None)
			},
			candidates: row.list,
		},
	)
	{
		slots: var_slots.concat(want_slots).concat(fresh_slots),
		strategy: settings.strategy,
		min_age: settings.min_age,
		snapshot,
		want_slots: wants.map2(want_slots, |w, slot| { key: w.key, name: w.name ?? w.key, urls: slot.candidates.map(|c| c.url) }),
	}
}

# The use with the highest version: its URL is the value that the header holds now (R-C9).
highest_use : List({ file : Str, alias : Str, url : Str, version : Str }) -> Try(Str, [None])
highest_use = |uses| match uses {
	[] => Err(None)
	[first, .. as rest] => Ok(
		rest.fold(
			first,
			|best, u| match (Semver.parse(u.version), Semver.parse(best.version)) {
				(Ok(a), Ok(b)) => if a.order_relative_to(b) == After u else best
				_ => best
			},
		).url,
	)
}

# Step G of the flow: `Pick.step` until `Done` or `Fail`. A `Need` fetches the packages and reads their headers (`Release.read`).
pick_loop! : Fx, Resolve.Request, PickInput, List(Fact) => Try(List(Pick.Chosen), Fail)
pick_loop! = |fx, request, input, facts| match Pick.step({ slots: input.slots, strategy: input.strategy, now: request.now, min_age: input.min_age, snapshot: input.snapshot, facts }) {
	Done(chosen) => Ok(chosen)
	Fail(fail) => Err(fail)
	Need(urls) => {
		more = read_releases!(fx, request, urls, Bool.True)?
		all = facts.concat(more)
		platform_wants(input.want_slots, all)?
		pick_loop!(fx, request, input, all)
	}
}

# Q2, R-AD33: a key of `talon.toml` whose release is a platform is not added as a package.
platform_wants : List({ key : Str, name : Str, urls : List(Str) }), List(Fact) -> Try({}, Fail)
platform_wants = |wants, facts| {
	found = wants.join_map(|w| facts.keep_if(|f| f.release.kind == Platform and w.urls.contains(f.url)).map(|f| (w, f.url)))
	match found {
		[] => Ok({})
		[(w, url), ..] => match Add.decide({ selector: Err(None), chosen: { name: w.name, url, kind: Platform }, platform_flag: Bool.False, no_pin: Bool.False, as_alias: Ok(w.key), header: [] }) {
			Err(fail) => Err(fail)
			Ok(_) => Ok({})
		}
	}
}

# Fetches the packages of the URLs (R-FE1, the hash check) and, with `read`, reads the header of each `main.roc` (R-DI7).
read_releases! : Fx, Resolve.Request, List(Str), Bool => Try(List(Fact), Fail)
read_releases! = |fx, request, urls, read| {
	results = Fetch.packages!(fx, { roots: request.roots, urls, offline: request.offline, roc: "roc", downloader: request.net.downloader })
	for result in results {
		match result {
			Ok(_) => {}
			Err(fail) => return Err(fail)
		}
	}
	if !read {
		Ok([])
	} else {
		paths = urls.map(|url| main_of(request.roots, url))
		texts = fx.read_files!(paths)
		var $facts = no_facts
		for (url, path, text) in urls.map2(paths.map2(texts, |p, t| (p, t)), |u, (p, t)| (u, p, t)) {
			body = match text {
				Ok(t) => t
				Err(_) => return Err(Fail.new(Environment, "cannot read ${path}"))
			}
			release = Release.read({ path, text: body })?
			$facts = $facts.append({ url, release })
		}
		Ok($facts)
	}
}

no_facts : List(Fact)
no_facts = []

main_of : Roots, Str -> Str
main_of = |roots, url| match Ident.of_url(url) {
	Ok(ident) => "${Roots.item(roots, Item.Package(ident.hash))}/main.roc"
	Err(Foreign) => url
}

# The new names of `add`: the candidates of each (R-SL12: one must admit the selector), then the kind of the newest candidate of its URL form (the highest
# `published_at`, the first one wins a tie, D6): `--platform` and a package, or a platform and no `--platform`, stop before the pick (R-AD32, R-AD33). The alias is
# checked here too (R-AD14 to R-AD18). The header of the newest candidate is a fact for the pick.
prepare! : Fx, Resolve.Request, Loaded, List(Fresh), List(Candidates) => Try(Prepared, Fail)
prepare! = |fx, request, loaded, fresh, found| {
	header = current_rows(loaded.members, request.project.file ?? "")
	var $rows = no_rows
	var $facts = no_facts
	for f in fresh {
		cands = match found.find_first(|c| c.name == f.name) {
			Ok(c) => c.list
			Err(_) => []
		}
		list = match Index.new_entry({ name: f.name, list: cands }) {
			Ok(entry) => entry.list
			Err(NoCandidate) => []
		}
		first = match newest(list) {
			Ok(c) if list.any(|x| Ranges.admits({ ranges: [f.range], version: x.ident.version })) => c
			_ => return Err(Add.no_release({ name: f.name, selector: f.selector, text: f.text, versions: cands.map(|c| c.ident.version) }))
		}
		read = read_releases!(fx, request, [first.url], Bool.True)?
		kind = match read {
			[fact] => if fact.release.kind == Platform Platform else Package
			_ => Package
		}
		_ = Add.decide({ selector: f.selector, chosen: { name: f.name, url: first.url, kind }, platform_flag: f.is_platform, no_pin: request.add.no_pin, as_alias: request.add.as_alias, header })?
		$rows = $rows.append({ fresh: f, list })
		$facts = $facts.concat(read)
	}
	Ok({ rows: $rows, facts: $facts })
}

# The candidate with the highest `published_at`. A tie keeps the first (the rule of `Index.new_entry`).
newest : List(Index.Candidate) -> Try(Index.Candidate, [ListWasEmpty])
newest = |list| match list {
	[] => Err(ListWasEmpty)
	[first, .. as rest] => Ok(rest.fold(first, |best, c| if c.published_at > best.published_at c else best))
}

no_rows : List(FreshRow)
no_rows = []

no_edits : List(Edit)
no_edits = []

no_pairs : List(Pair)
no_pairs = []

# What the new names of `add` do to the header and to `talon.toml`, with the notes and the entries that `add` finds in the header (R-AD21).
Planned : { header : List(Row), edits : List(Edit), pairs : List(Pair), kept : List(Kept), notes : List(Str) }

fresh_plan : Resolve.Request, Loaded, List(FreshRow), List(Pick.Chosen) -> Try(Planned, Fail)
fresh_plan = |request, loaded, rows, chosen| {
	file = request.project.file ?? ""
	start = { header: current_rows(loaded.members, file), edits: no_edits, pairs: no_pairs, kept: no_kept, notes: no_names }
	rows.map2(chosen, |r, c| (r, c)).fold_try(start, |acc, (r, c)| fresh_step(request, loaded, file, acc, r, c))
}

# `Add.decide` of one new name (R-AD23 to R-AD31): the header edit, the `talon.toml` key and the note.
fresh_step : Resolve.Request, Loaded, Str, Planned, FreshRow, Pick.Chosen -> Try(Planned, Fail)
fresh_step = |request, loaded, file, acc, row, c| {
	f = row.fresh
	plan = Add.decide({
		selector: f.selector,
		chosen: { name: f.name, url: c.url, kind: if f.is_platform Platform else Package },
		platform_flag: f.is_platform,
		no_pin: request.add.no_pin,
		as_alias: request.add.as_alias,
		header: acc.header,
	})?
	path = match loaded.members.find_first(|m| m.file == file) {
		Ok({ toml: Ok(t), .. }) => t.path
		_ => Text.join(Text.dir_of(file), "talon.toml")
	}
	pairs = match plan.toml {
		Ok({ key, value }) => [{ path, key, value }]
		Err(Nothing) => []
	}
	notes = match plan.note {
		Ok(text) => if plan.header == Replace [text] else []
		Err(None) => []
	}
	state = { ..acc, pairs: acc.pairs.concat(pairs), notes: acc.notes.concat(notes) }
	match plan.header {
		Insert => {
			edit = { file, op: Add({ alias: plan.alias, url: c.url, is_platform: f.is_platform }), line: "+ ${plan.alias}: ${f.name} ${c.version}", did: Added({ alias: plan.alias, name: f.name, version: c.version }) }
			Ok({ ..state, header: acc.header.append({ alias: plan.alias, url: c.url, is_platform: f.is_platform }), edits: acc.edits.append(edit) })
		}
		Replace => match acc.header.find_first(|r| r.is_platform) {
			Ok(old) => if old.url == c.url {
				Ok(state)
			} else {
				from = { name: name_of(old.url), version: version_of(old.url) }
				edit = {
					file,
					op: Set({ alias: plan.alias, url: c.url }),
					line: "~ ${plan.alias}: ${from.name} ${from.version} -> ${c.version}",
					did: Moved({ alias: plan.alias, from, to: { name: f.name, version: c.version } }),
				}
				Ok({ ..state, edits: acc.edits.append(edit) })
			}
			Err(_) => Ok(state)
		}
		_ => {
			name = name_of(plan.url)
			note = match plan.note {
				Ok(text) => text
				Err(None) => "${plan.alias}: ${name} ${version_of(plan.url)} is in the header\nRun tln update ${plan.alias} to move it."
			}
			Ok({ ..state, kept: acc.kept.append({ alias: plan.alias, name, version: version_of(plan.url), note }) })
		}
	}
}

# The name and the version of a release URL. A URL that Talon cannot read stands for itself.
name_of : Str -> Str
name_of = |url| match Ident.of_url(url) {
	Ok(ident) => ident.name ?? url
	Err(Foreign) => url
}

version_of : Str -> Str
version_of = |url| match Ident.of_url(url) {
	Ok(ident) => ident.version
	Err(Foreign) => ""
}

no_ran : Ran
no_ran = { probes: 0, check: NotRun, build: NotRun, notes: [] }

# What the ladder did: the number of `roc` runs and the state of the steps (R-DT5, R-LF3).
Ran : { probes : U64, check : [Passed, Skipped, NotRun], build : [Passed, Skipped, NotRun], notes : List(Str) }

# Steps H to J: the plan, the second read, the check of R-CC7, one `write_atomic!` call and the output.
Finish : { scoped : List(Vars.Scoped), wants : List(Vars.Want), asked : Asked, prepared : Prepared, renames : List(Rename), snapshot : Try(U64, [None]) }

finish! : Fx, Resolve.Request, Loaded, Finish, List(Pick.Chosen) => Try(Report.Outcome, Fail)
finish! = |fx, request, loaded, facts, chosen| {
	scoped = facts.scoped
	wants = facts.wants
	count = scoped.len()
	var_chosen = chosen.take_first(count)
	want_chosen = chosen.drop_first(count).take_first(wants.len())
	fresh_chosen = chosen.drop_first(count + wants.len())
	pick_notes = chosen.keep_oks(|c| c.note)
	for note in pick_notes {
		fx.out!("note: ${note}\n")
	}
	sets = scoped.map2(var_chosen, |s, c| (s, c)).join_map(|(s, c)| set_edits(s, c))
	adds = wants.map2(want_chosen, |w, c| (w, c)).map_try(|(w, c)| add_edit(loaded.members, w, c))?
	plan = fresh_plan(request, loaded, facts.prepared.rows, fresh_chosen)?
	changes = sets.concat(adds.join_map(|a| a)).concat(plan.edits)
	decision = Pin.decide({
		members: loaded.members.map(|m| { file: m.file, pin: m.locked.roc, changes: changes.any(|e| e.file == m.file) }),
		compiler: request.compiler,
		req: loaded.intent.toolchain.roc,
		nightly: settings_of(request, loaded.intent).nightly,
		no_check: request.no_check,
	})?
	pins = decision.writes.map(|w| { file: w.file, op: Pin(w.id), line: "+ roc: ${w.id}", did: Pinned(w.id) })
	edits = changes.concat(pins)
	pairs = pairs_of(request, loaded.members, scoped, facts.asked)?.concat(plan.pairs)
	for note in plan.notes {
		fx.out!("note: ${note}\n")
	}
	kept = facts.asked.kept.concat(plan.kept)
	for k in kept {
		fx.out!("${k.note}\n")
	}
	news = wants.map(|w| { name: w.name ?? w.key, is_platform: Bool.False }).concat(facts.prepared.rows.map(|r| { name: r.fresh.name, is_platform: r.fresh.is_platform }))
	ran = if changes.is_empty() no_ran else ladder!(fx, request, loaded, { scoped, news, chosen, changes, decision })?
	touched = write!(fx, request, loaded, edits, pairs, facts.renames)?
	if touched.is_empty() and kept.is_empty() {
		fx.out!("nothing to change\n")
	}
	Ok(
		outcome_of(
			request,
			{
				at: match facts.snapshot {
					Ok(time) => time
					Err(None) => request.now
				},
				touched,
				edits,
				pairs,
				renames: facts.renames,
				kept,
				notes: pick_notes.concat(plan.notes).concat(ran.notes),
				ran,
			},
		),
	)
}

# The facts of a finished run for `Report.Outcome`. `touched` are the files that were written (planned, with `--dry-run`).
Done : { at : U64, touched : List(Str), edits : List(Edit), pairs : List(Pair), renames : List(Rename), kept : List(Kept), notes : List(Str), ran : Ran }

outcome_of : Resolve.Request, Done -> Report.Outcome
outcome_of = |request, done| {
	used = done.edits.keep_if(|e| done.touched.contains(e.file))
	added = used.keep_oks(
		|e| match e.did {
			Added(entry) => Ok(entry)
			_ => Err(NotAdded)
		},
	)
	moved = used.keep_oks(
		|e| match e.did {
			Moved(move) => Ok(move)
			_ => Err(NotMoved)
		},
	)
	pins = used.keep_oks(
		|e| match e.did {
			Pinned(id) => Ok(id)
			_ => Err(NotPinned)
		},
	)
	{
		at: Clock.format_utc(done.at),
		probes: done.ran.probes,
		dry_run: request.dry_run,
		check: done.ran.check,
		build: done.ran.build,
		added,
		moved,
		kept: done.kept.map(|k| { alias: k.alias, name: k.name, version: k.version }),
		pinned: match pins {
			[id, ..] => Ok(id)
			[] => Err(None)
		},
		toml: done.pairs.keep_if(|p| done.touched.contains(p.path)),
		renamed: done.renames.keep_if(|r| done.touched.contains(r.path)),
		notes: done.notes,
		written: if request.dry_run [] else done.touched,
	}
}

# Slice 006: the place of the probe ladder in the flow (Resolution 4, R-LD4, R-LD5, R-PH9, R-PH10): after the choice and before the write, when a header changes (R-AL6).
# `facts.changes` are the planned changes of the headers (the pin write is not a change that makes the ladder run). `facts.decision` is the `Pin.decide` of `finish!`. `facts.news` are the wants
# and the new names, in the order of the slots after `facts.scoped`.
#
# | Case | What the body does |
# | --- | --- |
# | `request.no_check` (R-BL6, R-LF3) | No `Fx` call. Prints `check: skipped` (a proposal, TW24) and gives `Skipped` for both steps. A pin is not written (`Pin.decide`, R-H6). |
# | Else | Builds `Ladder.run!` input: one `Ladder.Member` for each member file in `facts.changes` (its `kind` and its text from `loaded`, its `ops` from the changes and from the pin write of `facts.decision.writes`), the `Ladder.Owner` of each hash of the candidate header (the uses of `facts.scoped` and the chosen URLs, with `Vars` names), `moved` (the chosen values that move: `Pick.Chosen.change` is `Move` and the new ones), `path_roc` is `request.compiler`, `held` is `facts.decision.held`, `roots` is `request.roots`. Calls `Ladder.run!`. The probes are 3 for an app and 2 for a package or a platform (D12). |
ladder! : Fx, Resolve.Request, Loaded, { scoped : List(Vars.Scoped), news : List({ name : Str, is_platform : Bool }), chosen : List(Pick.Chosen), changes : List(Edit), decision : Pin.Decision } => Try(Ran, Fail)
ladder! = |fx, request, loaded, facts| {
	if request.no_check {
		fx.out!("check: skipped\n")
		Ok({ probes: 0, check: Skipped, build: Skipped, notes: [] })
	} else {
		count = facts.scoped.len()
		var_rows = facts.scoped.map2(facts.chosen.take_first(count), |s, c| (s.variable.name ?? s.variable.group.form, s.variable.is_platform, c, is_move(c)))
		new_rows = facts.news.map2(facts.chosen.drop_first(count), |n, c| (n.name, n.is_platform, c, Bool.True))
		rows = var_rows.concat(new_rows).keep_oks(|(name, is_platform, c, moved)| owner_of(name, is_platform, c).map_ok(|owner| { owner, moved }))
		files = facts.changes.map(|e| e.file).fold(no_names, |found, file| if found.contains(file) found else found.append(file))
		members = files.keep_oks(|file| ladder_member(loaded, facts.changes, facts.decision, file))
		notes = Ladder.run!(
			fx,
			{
				roots: request.roots,
				path_roc: request.compiler,
				held: facts.decision.held ?? "",
				members,
				owners: rows.map(|r| r.owner),
				moved: rows.keep_if(|r| r.moved).map(|r| r.owner),
			},
		)?
		Ok({
			probes: members.fold(0, |total, m| total + if m.kind == App 3 else 2),
			check: Passed,
			build: if members.any(|m| m.kind == App) Passed else NotRun,
			notes,
		})
	}
}

is_move : Pick.Chosen -> Bool
is_move = |c| match c.change {
	Move(_) => Bool.True
	Keep => Bool.False
}

# The owner of the hash of a chosen URL (R-PH13: the blame names `<name> <version>`).
owner_of : Str, Bool, Pick.Chosen -> Try(Ladder.Owner, [Foreign])
owner_of = |name, is_platform, c| Ident.of_url(c.url).map_ok(|ident| { hash: ident.hash, name, version: c.version, is_platform })

# A member file with its header text and the edits for the candidate: the planned changes, and the pin that the command writes after the check (R-RP3).
ladder_member : Loaded, List(Edit), Pin.Decision, Str -> Try(Ladder.Member, [NoMember])
ladder_member = |loaded, changes, decision, file| match loaded.members.find_first(|m| m.file == file) {
	Ok(m) => Ok({
		file,
		kind: m.locked.kind,
		text: loaded_text(loaded, file),
		ops: changes.keep_if(|e| e.file == file).map(|e| e.op).concat(decision.writes.keep_if(|w| w.file == file).map(|w| Pin(w.id))),
	})
	Err(_) => Err(NoMember)
}

# R-H1: a header entry moves to the URL that was chosen, for each use of the variable.
set_edits : Vars.Scoped, Pick.Chosen -> List(Edit)
set_edits = |s, c| {
	name = s.variable.name ?? s.variable.group.form
	s.variable.uses
		.keep_if(|u| u.url != c.url)
		.map(
			|u| {
				file: u.file,
				op: Set({ alias: u.alias, url: c.url }),
				line: "~ ${u.alias}: ${name} ${u.version} -> ${c.version}",
				did: Moved({ alias: u.alias, from: { name, version: u.version }, to: { name, version: c.version } }),
			},
		)
}

# R-I5, R-I6: a key that no header has is added to the header of the one member under its `talon.toml` (the decision of `tln add`).
add_edit : List(Vars.Member), Vars.Want, Pick.Chosen -> Try(List(Edit), Fail)
add_edit = |members, w, c| match w.members {
	[file, ..] => {
		rows = match members.find_first(|m| m.file == file) {
			Ok(m) => m.locked.rows.map(|r| { alias: r.alias, url: r.value, is_platform: r.is_platform })
			Err(_) => []
		}
		name = w.name ?? w.key
		plan = Add.decide({ selector: Err(None), chosen: { name, url: c.url, kind: Package }, platform_flag: Bool.False, no_pin: Bool.False, as_alias: Ok(w.key), header: rows })?
		match plan.header {
			Insert => Ok([{ file, op: Add({ alias: plan.alias, url: c.url, is_platform: Bool.False }), line: "+ ${plan.alias}: ${name} ${c.version}", did: Added({ alias: plan.alias, name, version: c.version }) }])
			_ => Ok([])
		}
	}
	[] => Ok([])
}

# R-AD22, R-AD26, D10: the `talon.toml` key of an alias that `update X@sel` or `add X@sel` names, in the nearest `talon.toml` of its first use. Q1: a new file next to the member.
pairs_of : Resolve.Request, List(Vars.Member), List(Vars.Scoped), Asked -> Try(List(Pair), Fail)
pairs_of = |request, members, scoped, asked| asked.picks
	.keep_oks(
		|p| match scoped.find_first(|s| s.free and s.variable.uses.any(|u| u.alias == p.alias)) {
			Ok(s) => match s.variable.uses.find_first(|u| u.alias == p.alias) {
				Ok(u) => Ok((p, s, u))
				Err(_) => Err(NoPair)
			}
			Err(_) => Err(NoPair)
		},
	)
	.map_try(
		|(p, s, u)| {
			plan = Add.decide_alias({ alias: p.alias, selector: Ok(p.selector), no_pin: request.add.no_pin, header: [{ alias: u.alias, url: u.url, is_platform: s.variable.is_platform }] })?
			path = match members.find_first(|m| m.file == u.file) {
				Ok({ toml: Ok(t), .. }) => t.path
				_ => Text.join(Text.dir_of(u.file), "talon.toml")
			}
			match plan.toml {
				Ok({ key, value }) => Ok([{ path, key, value }])
				Err(Nothing) => Ok([])
			}
		},
	)
	.map_ok(|lists| lists.join_map(|l| l))

# The second read, the check of R-CC7 and the write, in the order of `Guard.check_all` (Talon first). It gives the files that changed, in the order of the write.
# With `--dry-run` there is no read and no write: it gives each file of the plan. The lines of the files are printed in both cases (R-LF4).
write! : Fx, Resolve.Request, Loaded, List(Edit), List(Pair), List(Rename) => Try(List(Str), Fail)
write! = |fx, request, loaded, edits, pairs, renames| {
	header_files = loaded.members.keep_if(|m| edits.any(|e| e.file == m.file)).map(|m| m.file)
	toml_files = pairs.map(|p| p.path).concat(renames.map(|r| r.path)).fold([], |found, path| if found.contains(path) found else found.append(path))
	paths = header_files.concat(toml_files)
	if paths.is_empty() return Ok([])
	touched = if request.dry_run paths else changed_files!(fx, loaded, { header_files, paths, edits, pairs, renames })?
	for path in header_files {
		if touched.contains(path) {
			fx.out!("${path}\n")
			for e in edits.keep_if(|e| e.file == path) {
				fx.out!("  ${e.line}\n")
			}
		}
	}
	for p in pairs {
		if touched.contains(p.path) {
			fx.out!("${p.path}: ${p.key} = \"${p.value}\"\n")
		}
	}
	for r in renames {
		if touched.contains(r.path) {
			fx.out!("${r.path}: key ${r.from} -> ${r.to}\n")
		}
	}
	Ok(touched)
}

# Reads each file again, checks it (R-CC7), and writes the files that change with one `write_atomic!` call. The rename of the keys is after the key writes.
changed_files! : Fx, Loaded, { header_files : List(Str), paths : List(Str), edits : List(Edit), pairs : List(Pair), renames : List(Rename) } => Try(List(Str), Fail)
changed_files! = |fx, loaded, plan| {
	now_texts = plan.paths.map2(fx.read_files!(plan.paths), |path, result| (path, result))
	var $files = no_files
	var $edited = no_edited
	for (path, result) in now_texts {
		is_header = plan.header_files.contains(path)
		read = loaded_text(loaded, path)
		now = match result {
			Ok(text) => text
			Err(NotFound) => if is_header return Err(Fail.new(Environment, "cannot read ${path}")) else ""
			Err(_) => return Err(Fail.new(Environment, "cannot read ${path}"))
		}
		ops = plan.edits.keep_if(|e| e.file == path).map(|e| e.op)
		mine = plan.pairs.keep_if(|p| p.path == path)
		renames = plan.renames.keep_if(|r| r.path == path)
		keys = mine.map(|p| p.key).concat(renames.map(|r| r.from))
		writes = mine.map(|p| { key: p.key, value: p.value })
		spans_read = if is_header Locked.spans({ text: read, ops }) else Intent.spans({ text: read, keys })
		spans_now = if is_header Locked.spans({ text: now, ops }) else Intent.spans({ text: now, keys })
		new = if is_header Locked.edit({ path, text: now, ops })? else Intent.rename({ path, text: Intent.apply({ path, text: now, writes })?, renames: renames.map(|r| { from: r.from, to: r.to }) })?
		$files = $files.append({ path, read, now, spans_read, spans_now })
		$edited = $edited.append({ path, now, new })
	}
	ordered = Guard.check_all($files)?
	changed = ordered.keep_oks(|o| $edited.find_first(|e| e.path == o.path)).keep_if(|e| e.new != e.now)
	if changed.is_empty() return Ok([])
	match fx.write_atomic!(changed.map(|e| { path: e.path, content: e.new })) {
		Ok(_) => Ok(changed.map(|e| e.path))
		Err(failed) => Err(Fail.new(Environment, "cannot write ${failed.path}"))
	}
}

no_files : List({ path : Str, read : Str, now : Str, spans_read : List(Str), spans_now : List(Str) })
no_files = []

no_edited : List({ path : Str, now : Str, new : Str })
no_edited = []

# The text that the first read gave (`""` for a `talon.toml` that was not there).
loaded_text : Loaded, Str -> Str
loaded_text = |loaded, path| match loaded.headers.find_first(|t| t.path == path) {
	Ok(t) => t.text
	Err(_) => match loaded.tomls.find_first(|t| t.path == path) {
		Ok(t) => t.text
		Err(_) => ""
	}
}

# Slice 008: the helpers of `Resolve.remove!`.

# One entry to remove: its alias and the decision of `Removal.plan`.
RemovePlan : { alias : Str, plan : Removal.Plan }

# The aliases that a scan found imported, with their import lines.
Imported : { alias : Str, hits : List(Scan.Hit) }

# Steps 2 and 3: the names are looked up in the header of the member (R-SC1, R-SC6 to R-SC8) and planned. One entry counts once.
removal_plans! : Fx, Loaded, Vars.Member, List(Str) => Try(List(RemovePlan), Fail)
removal_plans! = |fx, loaded, member, names| {
	entities = member.locked.rows.map(
		|r| {
			alias: r.alias,
			name: match r.what {
				Release(ident) => ident.name ?? r.value
				_ => r.value
			},
			note: if r.is_platform "platform (${r.alias})" else "",
		},
	)
	var $aliases = no_names
	for text in names {
		ref = Ref.parse(text, Scope.Project, Bool.False)?
		found = match Lookup.find(Scope.Project, ref, entities) {
			Ok(f) => f
			Err({ fail, block }) => {
				if !block.is_empty() fx.err!(block)
				return Err(fail)
			}
		}
		alias = match found {
			Lookup.Existing({ alias: a, .. }) => a
			Lookup.New(name) => return Err(Fail.new(Usage, "'${name}' is not in the project"))
		}
		if !$aliases.contains(alias) {
			$aliases = $aliases.append(alias)
		}
	}
	toml = member_toml(loaded, member)
	$aliases.map_try(
		|alias| Removal.plan({ alias, rows: member.locked.rows, toml, shared: shared_alias(loaded, member, toml, alias) }).map_ok(|plan| { alias, plan }),
	)
}

# R-WS14: the nearest `talon.toml` of the member, with its text.
member_toml : Loaded, Vars.Member -> Try({ path : Str, text : Str }, [NoToml])
member_toml = |loaded, member| match member.toml {
	Ok(found) => loaded.tomls.find_first(|t| t.path == found.path).map_err(|_| NoToml)
	Err(NoToml) => Err(NoToml)
}

# Question Q3: another member under the dir of that `talon.toml` has the alias, so its key stays.
shared_alias : Loaded, Vars.Member, Try({ path : Str, text : Str }, [NoToml]), Str -> Bool
shared_alias = |loaded, member, toml, alias| match toml {
	Ok(file) => {
		dir = Text.dir_of(file.path)
		prefix = if dir.ends_with("/") dir else "${dir}/"
		loaded.members.any(|m| m.file != member.file and m.file.starts_with(prefix) and m.locked.rows.any(|r| r.alias == alias))
	}
	Err(NoToml) => Bool.False
}

# Step 4, R-RV2, R-LD7: the lexical scan. It starts at the roots and reads one level of local modules with each `read_files!` call. A file that cannot be read is skipped (question Q7).
import_hits! : Fx, Loaded, Vars.Member, List(Str) => List(Imported)
import_hits! = |fx, loaded, member, aliases| {
	text = loaded_text(loaded, member.file)
	exposed = match Header.parse(text) {
		Ok(header) => header.exposed()
		Err(_) => []
	}
	roots = Scan.roots({ kind: member.locked.kind, file: member.file, exposed })
	is_app = member.locked.kind == App
	var $sources = if is_app [{ path: member.file, text }] else []
	var $todo = if is_app [] else roots.keep_if(|file| file != member.file)
	var $seen = [member.file]
	var $found = aliases.map(|alias| { alias, hits: [] })
	while !$sources.is_empty() or !$todo.is_empty() {
		seen = $seen.concat($todo)
		sources = $sources.concat(read_sources!(fx, $todo))
		levels = aliases.map(|alias| Scan.level({ alias, project_dir: Text.dir_of(member.file), sources, seen }))
		$found = $found.map2(levels, |f, level| { alias: f.alias, hits: f.hits.concat(level.hits) })
		$todo = match levels.first() {
			Ok(level) => level.next
			Err(_) => []
		}
		$seen = seen
		$sources = []
	}
	$found.keep_if(|f| !f.hits.is_empty())
}

# The files of one level that can be read, with their text. No call when there is no file.
read_sources! : Fx, List(Str) => List(Scan.Source)
read_sources! = |fx, paths| if paths.is_empty() {
	[]
} else {
	paths.map2(fx.read_files!(paths), |path, result| (path, result)).keep_oks(|(path, result)| result.map_ok(|text| { path, text }))
}

# R-RV2, R-EC11 (proposal, TW24): the message of the failure. The import lines are in the message, so the `--json` error has them too.
imports_text : List(Imported) -> Str
imports_text = |imported| {
	aliases = Str.join_with(imported.map(|i| i.alias), ", ")
	lines = imported.join_map(|i| i.hits).map(|h| "${h.file}:${h.line.to_str()}: ${h.text}")
	"the app imports ${aliases}: ${Str.join_with(lines, "; ")}. Change these imports first, or pass --force to remove it anyway."
}

# R-RV2: the note of a forced run.
still_imported : Imported -> Str
still_imported = |i| {
	count = i.hits.len()
	lines = if count == 1 "1 line" else "${count.to_str()} lines"
	"${i.alias} is still imported in ${lines}. The app cannot check until you change the imports."
}

# Step 8, R-RV1, R-LD4, R-LD5: the ladder for the one member. A candidate with a new error stops the run (no tuple: `remove` moves no other entry).
removal_ladder! : Fx, Resolve.Request, Loaded, Vars.Member, { aliases : List(Str), ops : List(Locked.Op), decision : Pin.Decision } => Try(Ran, Fail)
removal_ladder! = |fx, request, loaded, member, facts| {
	owners = member.locked.rows
		.keep_if(|r| !facts.aliases.contains(r.alias))
		.keep_oks(
			|r| match r.what {
				Release(ident) => Ok({ hash: ident.hash, name: ident.name ?? r.value, version: ident.version, is_platform: r.is_platform })
				_ => Err(NotRelease)
			},
		)
	candidate = { file: member.file, kind: member.locked.kind, text: loaded_text(loaded, member.file), ops: facts.ops }
	result = Ladder.run!(
		fx,
		{ roots: request.roots, path_roc: request.compiler, held: facts.decision.held ?? "", members: [candidate], owners, moved: [] },
	)
	match result {
		Ok(notes) => Ok({
			probes: if member.locked.kind == App 3 else 2,
			check: Passed,
			build: if member.locked.kind == App Passed else NotRun,
			notes,
		})
		Err(fail) => if fail.kind == NoTuple {
			Err(Fail.new(NoTuple, "${fail.message}. tln remove moves no other entry. Pass --no-check to remove ${Str.join_with(facts.aliases, ", ")} anyway."))
		} else {
			Err(fail)
		}
	}
}

# Step 9, R-CC7, R-CC1: the second read, the check, and one `write_atomic!` call (the `talon.toml` first). With `--dry-run` there is no read and no write.
write_removal! : Fx, Resolve.Request, Loaded, { file : Str, ops : List(Locked.Op), toml : Try({ path : Str, text : Str }, [NoToml]), keys : List({ table : Intent.Table, key : Str }) } => Try(List(Str), Fail)
write_removal! = |fx, request, loaded, facts| {
	if request.dry_run return Ok([])
	toml_paths = match facts.toml {
		Ok(t) if !facts.keys.is_empty() => [t.path]
		_ => []
	}
	paths = toml_paths.concat([facts.file])
	var $now = no_edited
	for (path, result) in paths.map2(fx.read_files!(paths), |path, result| (path, result)) {
		match result {
			Ok(text) => {
				$now = $now.append({ path, now: text, new: text })
			}
			Err(_) => return Err(Fail.new(Environment, "cannot read ${path}"))
		}
	}
	edited = $now.map_try(
		|f| {
			is_header = f.path == facts.file
			new = if is_header {
				Locked.edit({ path: f.path, text: f.now, ops: facts.ops })?
			} else {
				Intent.remove({ path: f.path, text: f.now, keys: facts.keys })?
			}
			Ok({ path: f.path, now: f.now, new })
		},
	)?
	checked = edited.map(
		|f| {
			is_header = f.path == facts.file
			read = loaded_text(loaded, f.path)
			spans = |text| if is_header Locked.spans({ text, ops: facts.ops }) else Intent.table_spans({ text, keys: facts.keys })
			{ path: f.path, read, now: f.now, spans_read: spans(read), spans_now: spans(f.now) }
		},
	)
	ordered = Guard.check_all(checked)?
	changed = ordered.keep_oks(|o| edited.find_first(|e| e.path == o.path)).keep_if(|e| e.new != e.now)
	match fx.write_atomic!(changed.map(|e| { path: e.path, content: e.new })) {
		Ok(_) => Ok(changed.map(|e| e.path))
		Err(failed) => Err(Fail.new(Environment, "cannot write ${failed.path}"))
	}
}

# One entry of the outcome and its line (`- <alias>: <what>`).
removed_of : Str, Removal.What -> Report.Removed
removed_of = |alias, what| match what {
	Release({ name, version }) => { alias, kind: Release, name, version: Ok(version) }
	Path(path) => { alias, kind: Path, name: path, version: Err(None) }
	Foreign(url) => { alias, kind: Foreign, name: url, version: Err(None) }
}

removed_text : Report.Removed -> Str
removed_text = |r| match r.version {
	Ok(version) => "${r.name} ${version}"
	Err(None) => r.name
}
