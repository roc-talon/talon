import Args
import Common
import Compiler
import Consent
import Db
import Fail
import Fetch
import Fx
import Ident
import Install
import JsonDoc
import Known
import Launch
import Locked
import Lookup
import Mode
import Net
import Opts
import Out
import Pin
import Probe
import ProbeBundle
import ProbeRange
import ProbeSearch
import ProbeShow
import ProbeUnit
import Project
import Ref
import ResolveBase
import ResolveLoad
import Roots
import Scope
import Start
import Text
import Units

## The command `tln probe [alias|<bundle file>] [--range]` (slice 037, R-CM8, R-PB1, R-PB2, R-PB3, R-PB4, R-PB7, R-LB3, R-SC1, R-SC16, R-PD14). It runs probes and prints the facts. It writes no project file (R-PB7). Its facts go in `compat.db` (R-P4).
## Part A (pure) is `read`, `entry`, `bundle_hash`, `stop`, `text` and `data`. `run!` is the command code (TESTING.md 2.2 part C). The slice file `docs/slices/037-probe.md` has the questions and the proposals of the texts (TW24).
##
## The three targets (R-PB1) and what `run!` does for each. The calls are fixed by the L2 cases `probe/pc1-targets` and `probe/pc2-range`.
##
## | Target | No `--range` (R-PB2) | `--range` (R-PB3, R-PB4) |
## | --- | --- | --- |
## | `Alias(text)`: the header entry that `entry` finds | The hash of the entry is fetched when it is not in `packages/` (R-FE1). One unit probe (`roc check main.roc` in `packages/<hash>/`) on the compiler that Resolution 13 selects (the selection of `tln verify`, R-SO21), one fact (R-P4, `existing=replace`) | The search of `ProbeRange`: the compiler list D, the facts of the hash on D (one `db_query`), rounds of unit probes on the installed candidates, the facts written after each round (R-PP4) |
## | `Bundle(path)`: a `<hash>.tar.zst` file | `bundle_hash`, then the file is a package in `packages/<hash>/` (copied to a temp dir, `roc unbundle`, `rename`: R-FE2, R-FE3; no call when the dir exists), then the unit probe as for an alias | The same, then the search |
## | `Project`: the project file (a current member is needed, R-PD5) | Ladder steps 2 and 3 on the selected compiler, with no baseline (each error counts): the check of the file, then the build for an app (a package or a platform has no build, R-LD7). The results are in memory and are printed. No fact is written (R-PB1) | A usage error (question R1 of the slice file) |
##
## The exit code is 0 when the probes gave results (a pass, a fail, a hang and a crash are facts, question E1 of the slice file). A probe with no fact (R-P3: a signal from outside, a start error) is exit 1. `--range`: exit 12 when an end is unknown or the budget is spent (R-PB4, `stop`).
ProbeCmd :: [].{

	## R-PB1: what the operand is. `Bundle` when the operand ends with `.tar.zst`, `Alias` for any other operand (a name, `json`, `acme/json@2`), `Project` for no operand.
	Target : [Alias(Str), Bundle(Str), Project]

	## What `read` gives. `opts` is the result of `Opts.read` of the line (`--slots`, `--allow-downloads`, `--probe-downloads`, `--registry`).
	Plan : { target : ProbeCmd.Target, range : Bool, opts : Opts }

	## The operand and the flags of a `probe` line. `Args.parse` has checked that each flag is allowed for the command (R-FL7, R-FL12). The checks, in this order (kind `Usage`, exit 2; the texts are a proposal, TW24):
	##
	## | # | Case | Message | Rule |
	## | --- | --- | --- | --- |
	## | 1 | The failures of `Opts.read` | the texts of `Opts.read` | R-FL5, R-FL11 |
	## | 2 | `--share` (a registry is needed, and `direct` has none: P1 has only `direct`) | `tln probe --share needs a registry, and this version of tln has only --registry direct` | R-PB6 |
	## | 3 | 2 operands or more | `tln probe takes one name or one bundle file` | R-CM8 |
	## | 4 | `--range` with no operand (question R1) | `tln probe --range needs a header alias or a bundle file: the project file has no hash` | R-PB1 |
	##
	## `--share` is rule 2 before any other rule: R-PB6 gives exit 2 for each of its 3 forms (no registry, no hash, a bundle file).
	read : Args -> Try(ProbeCmd.Plan, Fail)
	read = |args| {
		opts = Opts.read(args)?
		if args.options.any(|(name, _)| name == "--share") {
			return Err(Fail.new(Usage, "tln probe --share needs a registry, and this version of tln has only --registry direct"))
		}
		target = match args.operands {
			[] => Project
			[one] => if one.ends_with(".tar.zst") Bundle(one) else Alias(one)
			_ => return Err(Fail.new(Usage, "tln probe takes one name or one bundle file"))
		}
		range = args.options.any(|(name, _)| name == "--range")
		if range and target == Project {
			return Err(Fail.new(Usage, "tln probe --range needs a header alias or a bundle file: the project file has no hash"))
		}
		Ok({ target, range, opts })
	}

	## R-PB1, R-SC1, R-SC6 to R-SC8, R-SC16, R-SC14, R-WS8: the header entry that a name selects. `rows` are the entries of the header of each member that the command works on (the current member, else all members, as `tln why` does). A row that another row
	## repeats (the same `alias` and `value`: 2 members have the same entry) counts once. The name is read as `Ref.parse` with the scope `Project` reads it, and found as `Lookup.find` finds it (the alias, then the full name, then the short name, with the filter `@sel`: the version of
	## the entry is in `sel`, R-SC16). Only header entries are names here: a package of the closure that no header names is not found. The result is the `Units.Node` of the entry: `hash` is the hash of its URL, `name` is `owner/repo` (the URL form for another host), `version`,
	## `is_platform` is true for a platform entry (R-LD3).
	##
	## | Case | Failure |
	## | --- | --- |
	## | No entry has the name (also a name with a selector that no entry satisfies) | kind `Usage`, `'<x>' is not in the project`, block `""` (the text of `Lookup.find`) |
	## | A tie (R-SC14) | kind `Usage`, the text of `Lookup.find`, and its block (printed on stderr before the failure) |
	## | A path entry or a foreign URL (R-H4: it has no hash, question T1) | kind `Usage`, `'<x>' is a path entry or a foreign URL: it has no hash to probe` |
	entry : { text : Str, rows : List(Locked.Row) } -> Try(Units.Node, { fail : Fail, block : Str })
	entry = |x| {
		ref = Ref.parse(x.text, Scope.Project, Bool.False).map_err(|fail| { fail, block: "" })?
		rows = x.rows.fold([], |found, row| if found.any(|r| r.alias == row.alias and r.value == row.value) found else found.append(row))
		(alias, name, series) = match Lookup.find(Scope.Project, ref, Lookup.build(rows.map(fact_of)))? {
			Existing(e) => (e.alias, e.name, e.series)
			New(n) => ("", n, "")
		}
		picked = rows.find_first(|row| key_of(row) == (alias, name, series))
		match picked {
			Ok({ what: Release(ident), is_platform, .. }) => Ok({ hash: ident.hash, name, version: ident.version, is_platform })
			_ => Err({ fail: Fail.new(Usage, "'${x.text}' is a path entry or a foreign URL: it has no hash to probe"), block: "" })
		}
	}

	## R-PB1: the hash of a bundle file: the file name without `.tar.zst` (the directories of the path, `/` or `\`, are dropped). An empty name is kind `Usage`, `'<path>' is not a package archive: the file name must be <hash>.tar.zst`.
	## `roc unbundle` checks the hash (R-FE2, exit 16): this function does not check the characters of the name.
	bundle_hash : Str -> Try(Str, Fail)
	bundle_hash = |path| {
		name = Text.last_segment(path.replace_each("\\", "/"))
		hash = name.drop_suffix(".tar.zst")
		if name.ends_with(".tar.zst") and !hash.is_empty() {
			Ok(hash)
		} else {
			Err(Fail.new(Usage, "'${path}' is not a package archive: the file name must be <hash>.tar.zst"))
		}
	}

	## R-FE4: the program that runs `roc unbundle` for a bundle file. The format of an archive does not depend on the nightly, so the rows, first match wins (the order of the installed compilers is `Pin.order` with no times: the day of the tag, then the tag text; the newest first):
	##
	## | # | Case | Program |
	## | --- | --- | --- |
	## | 1 | `selected` is in `installed` | the file of that compiler (`Launch.program`) |
	## | 2 | `installed` is not empty | the file of the newest installed compiler |
	## | 3 | `path` is `Ok` | the file of the `roc` on `PATH` (rank 7) |
	## | 4 | none | `Err(NoCompiler)`: the selected compiler is a required download (R-DL2, not tested here: `Start.run!` does it) |
	##
	## `selected` is `""` when the run selects no compiler (`--range`).
	unbundler : { selected : Str, installed : List(Str), path : Try({ id : Str, path : Str }, [NoCompiler]), roots : Roots } -> Try(Str, [NoCompiler])
	unbundler = |x| {
		file = |id| Launch.program({ roots: x.roots, id, installed: x.installed, path: x.path })
		newest = x.installed.sort_with(|a, b| Pin.order({ a, b, times: [] })).last()
		if x.installed.contains(x.selected) {
			Ok(file(x.selected))
		} else {
			match (newest, x.path) {
				(Ok(id), _) => Ok(file(id))
				(Err(_), Ok(found)) => Ok(file(found.id))
				(Err(_), Err(NoCompiler)) => Err(NoCompiler)
			}
		}
	}

	## The end of a probe for the output: the class of the probe (`Probe.classify`) and its errors (`Probe.errors`). `Pass`, `Fail`, `Hang` and `Crash` only: a probe with no fact is a failure of the command (R-P3).
	Done : { class : Probe.Class, errors : List(Probe.Err) }

	## What a run found, for `text` and `data`. `probes` is the number of probes that started (R-PP4).
	##
	## | Tag | Holds |
	## | --- | --- |
	## | `Unit` | An alias or a bundle without `--range`: the node, the compiler id, and the fact that was written (`Db.Fact`: the hash, the compiler, the target `any`, the outcome and the failing modules) |
	## | `Project` | The project file, its kind, the compiler id, the check and the build. `build` is `Err(NotRun)` when the check did not pass, or the file is a package or a platform |
	## | `Range` | The node, and `ProbeRange.Found` |
	Shown : [
		Unit({ node : Units.Node, compiler : Str, fact : Db.Fact, probes : U64 }),
		Project({ file : Str, kind : [App, Package, Platform], compiler : Str, check : ProbeCmd.Done, build : Try(ProbeCmd.Done, [NotRun]), probes : U64 }),
		Range({ node : Units.Node, found : ProbeRange.Found, probes : U64 }),
	]

	## R-PB4, R-UP7, R-EC12: the failure that gives exit 12 (kind `Budget`) for a range, or none. `found` is the result (`ProbeRange.found` for a search that the budget cut). `cut` is the failure of the budget (`Units.spent`) when `probe.max` cut a round.
	## `unseen` is the number of releases of D that have no real fact. The rows, first match wins (the texts are a proposal, TW24):
	##
	## | # | Case | Result |
	## | 1 | `cut` is `Ok(fail)` | `Ok(fail)` as it is |
	## | 2 | `Range` with 2 unknown ends | `Ok`, kind `Budget`: `the range has 2 ends that are not a real fact (unknown): no installed compiler can show them. Run tln roc install for more compilers.` |
	## | 3 | `Range` with 1 unknown end | `Ok`, kind `Budget`: `the range has 1 end that is not a real fact (unknown): no installed compiler can show it. Run tln roc install for more compilers.` |
	## | 4 | `Range` with no unknown end | `Err(None)` |
	## | 5 | `NoPass`, `unseen` above 0 | `Ok`, kind `Budget`: `no installed compiler gave a real pass, and no real fact exists for <unseen> releases of the list. Run tln roc install for more compilers.` (`1 release` for 1) |
	## | 6 | `NoPass`, `unseen` is 0 | `Err(None)` |
	stop : { found : ProbeRange.Found, cut : Try(Fail, [None]), unseen : U64 } -> Try(Fail, [None])
	stop = |x| match x.cut {
		Ok(fail) => Ok(fail)
		Err(None) => match x.found {
			NoPass => if x.unseen > 0 Ok(Fail.new(Budget, "no installed compiler gave a real pass, and no real fact exists for ${ProbeShow.plural(x.unseen, "release")} of the list. Run tln roc install for more compilers.")) else Err(None)
			Range({ from, to }) => match [from, to].count_if(|end| !end.real) {
				0 => Err(None)
				1 => Ok(Fail.new(Budget, "the range has 1 end that is not a real fact (unknown): no installed compiler can show it. Run tln roc install for more compilers."))
				_ => Ok(Fail.new(Budget, "the range has 2 ends that are not a real fact (unknown): no installed compiler can show them. Run tln roc install for more compilers."))
			}
		}
	}

	## The human text of a run, with a line end after each line (a proposal, TW24). `<label>` is `<name> <version>`, `the platform <name> <version>` for a platform, and the hash for a bundle (`name` is the hash and `version` is empty: the label is then the hash).
	##
	## | Shown | Lines |
	## | --- | --- |
	## | `Unit` | `unit check of <label> on <compiler>: pass`, `... : fail (<module>, <module>)` (`fail (no module is named)` when there is none), `... : hang`, `... : crash` |
	## | `Project` | `<file> on <compiler>`, then `check: <end>`, then `build: <end>` when `build` is `Ok`, or `build: not run (a package has no app)` / `(a platform has no app)` when the kind says so and the check passed. Nothing when the check did not pass. `<end>`: `passed`, `failed, <n> error(s)` (`1 error`) and then one line for each error: 2 spaces and `<place>: <title>` (`<path>` of an app file, `package <hash> <path>`, `no file`), `hang`, `crash (<text>)` |
	## | `Range` | `<label> passes on <from> .. <to>`, then `  lower end: <id> (real)` or `(unknown)`, then `  upper end: <id> (real)` or `(unknown)`. `NoPass`: `<label>: no release of the compiler list has a real pass` |
	text : ProbeCmd.Shown -> Str
	text = |shown| match shown {
		Unit({ node, compiler, fact, .. }) => {
			end = match fact.outcome {
				Pass => "pass"
				Fail => if fact.modules.is_empty() "fail (no module is named)" else "fail (${Str.join_with(fact.modules, ", ")})"
				Hang => "hang"
				Crash => "crash"
			}
			"unit check of ${ProbeShow.label_of(node)} on ${compiler}: ${end}\n"
		}
		Project({ file, kind, compiler, check, build, .. }) => {
			tail = match build {
				Ok(done) => "build: ${ProbeShow.end_text(done)}"
				Err(NotRun) => match (check.class, kind) {
					(Pass, Package) => "build: not run (a package has no app)\n"
					(Pass, Platform) => "build: not run (a platform has no app)\n"
					_ => ""
				}
			}
			"${file} on ${compiler}\ncheck: ${ProbeShow.end_text(check)}${tail}"
		}
		Range({ node, found, .. }) => match found {
			NoPass => "${ProbeShow.label_of(node)}: no release of the compiler list has a real pass\n"
			Range({ from, to }) => "${ProbeShow.label_of(node)} passes on ${from.id} .. ${to.id}\n  lower end: ${from.id} (${ProbeShow.real_word(from)})\n  upper end: ${to.id} (${ProbeShow.real_word(to)})\n"
		}
	}

	## The `data` of `--json` (R-J3, R-J4, R-OUT4, R-OUT5, TW24). Keys in this order, a field that a case has not is left out:
	##
	## | Shown | Keys |
	## | --- | --- |
	## | `Unit` | `kind` (`"unit"`), `hash`, `label`, `compiler`, `outcome` (`"pass"`, `"fail"`, `"hang"`, `"crash"`), `modules` (a list of texts), `probes` |
	## | `Project` | `kind` (`"project"`), `file`, `compiler`, `check`, `build` (null when not run), `probes`. `check` and `build` are `{ "outcome", "errors": [{ "place", "title" }] }` with `outcome` as above |
	## | `Range` | `kind` (`"range"`), `hash`, `label`, `range` (null for `NoPass`, else `{ "from": { "id", "real" }, "to": { "id", "real" } }`), `probes` |
	data : ProbeCmd.Shown -> JsonDoc
	data = |shown| match shown {
		Unit({ node, compiler, fact, probes }) => JsonDoc.Obj([
			("kind", Text("unit")),
			("hash", Text(node.hash)),
			("label", Text(ProbeShow.label_of(node))),
			("compiler", Text(compiler)),
			("outcome", Text(Db.outcome_word(fact.outcome))),
			("modules", Arr(fact.modules.map(|m| Text(m)))),
			("probes", Num(probes.to_i64_wrap())),
		])
		Project({ file, compiler, check, build, probes, .. }) => JsonDoc.Obj([
			("kind", Text("project")),
			("file", Text(file)),
			("compiler", Text(compiler)),
			("check", ProbeShow.done_doc(check)),
			(
				"build",
				match build {
					Ok(done) => ProbeShow.done_doc(done)
					Err(NotRun) => Null
				},
			),
			("probes", Num(probes.to_i64_wrap())),
		])
		Range({ node, found, probes }) => JsonDoc.Obj([
			("kind", Text("range")),
			("hash", Text(node.hash)),
			("label", Text(ProbeShow.label_of(node))),
			(
				"range",
				match found {
					NoPass => Null
					Range({ from, to }) => Obj([("from", ProbeShow.end_doc(from)), ("to", ProbeShow.end_doc(to))])
				},
			),
			("probes", Num(probes.to_i64_wrap())),
		])
	}

	## The command (the table at the top). `--json`: with exit 0 the envelope is `Out.json_ok({ command: args.typed, data })`. With exit 12 the envelope is the failure with `error.details` set to `data` (R-J5, as `tln audit` does for exit 21).
	run! : Fx, Args => I32
	run! = |fx, args| match ProbeCmd.read(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(plan) => match flow!(fx, args, plan) {
			Err(fail) => Common.failed!(fx, args, fail)
			Ok(done) => finish!(fx, args, done)
		}
	}
}

# The fact of a header row for `Lookup.build`: a release is a direct entry or the platform, a path or a foreign URL is unmanaged (R-SC6).
fact_of : Locked.Row -> Lookup.Fact
fact_of = |row| match row.what {
	Release(ident) => { alias: row.alias, what: Release({ name: name_of(ident), series: ident.series, version: ident.version }), role: if row.is_platform Platform else Direct }
	_ => { alias: row.alias, what: Unmanaged, role: Direct }
}

key_of : Locked.Row -> (Str, Str, Str)
key_of = |row| match row.what {
	Release(ident) => (row.alias, name_of(ident), ident.series)
	_ => (row.alias, "", "")
}

# `owner/repo`, else the URL form with the version (the text of `Closure.Row.name`).
name_of : Ident -> Str
name_of = |ident| ident.name ?? ident.group.form.replace_each("{v}", ident.version).drop_suffix("/")

Finished : { shown : ProbeCmd.Shown, stop : Try(Fail, [None]) }

Begun : { env : List((Str, Str)), roots : Roots, net : Net.Settings, now : U64, project : Project }

# The answer, then the exit code. With `--json` the answer text is on stderr. A stop (exit 12) prints the failure with the `data` in `error.details` (R-J5).
finish! : Fx, Args, Finished => I32
finish! = |fx, args, done| {
	answer = ProbeCmd.text(done.shown)
	if args.json fx.err!(answer) else fx.out!(answer)
	doc = ProbeCmd.data(done.shown)
	match done.stop {
		Ok(fail) => Common.failed!(fx, args, { ..fail, details: Ok(doc) })
		Err(None) => {
			if args.json {
				fx.out!(Out.json_ok({ command: args.typed, data: doc }))
			}
			0
		}
	}
}

# The steps of `Verify.flow!` up to the compiler, then the target.
flow! : Fx, Args, ProbeCmd.Plan => Try(Finished, Fail)
flow! = |fx, args, plan| {
	start = Install.begin!(fx, args)?
	Install.check_member(is_project(plan.target), start.project)?
	Known.record!(fx, { roots: start.roots, files: Install.canonical_files!(fx, start.project), now: start.now })?
	toolchain = Compiler.toolchain_of(start.env)?
	compiler = Install.compiler!(fx, start.roots, Bool.False)
	request = request_of(args, plan.opts, start, { toolchain, compiler })
	if plan.range ranged!(fx, request, plan.target) else single!(fx, request, plan.target)
}

is_project : ProbeCmd.Target -> Bool
is_project = |target| match target {
	Project => Bool.True
	_ => Bool.False
}

# The request of `tln verify` (R-SO21: the compiler choice is the one of `verify`).
request_of : Args, Opts, Begun, { toolchain : Try(Str, [Unset]), compiler : Try({ id : Str, path : Str }, [NoCompiler]) } -> ResolveBase.Request
request_of = |args, opts, start, picked| {
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
	compiler: picked.compiler,
	toolchain: picked.toolchain,
	snapshot: Err(Unset),
	dry_run: Bool.False,
	add: { as_platform: Bool.False, as_alias: Err(Unset), no_pin: Bool.False },
	prompt: { mode: Mode.from_env({ env: Dict.from_list(start.env), json: args.json }), yes: args.yes, quiet: args.quiet, rename_keys: Err(NoFlag), allow_moves: Err(NoFlag) },
	downloads: { auto: Consent.auto_install(start.env), allow: opts.allow_downloads, probe: opts.probe_downloads, env: start.env },
	probe: { no_probe: Bool.False, slots: opts.slots },
}

# R-R12: the header entries of the current member, else of all members (as `tln why`).
rows_of : ResolveBase.Loaded, Project -> List(Locked.Row)
rows_of = |loaded, project| {
	named = loaded.members.keep_if(|m| m.file == (project.file ?? ""))
	(if named.is_empty() loaded.members else named).join_map(|m| m.locked.rows)
}

# No `--range` (R-PB2): the compiler that `verify` selects, then one unit check or the project probes.
single! : Fx, ResolveBase.Request, ProbeCmd.Target => Try(Finished, Fail)
single! = |fx, request, target| {
	prepared = ResolveLoad.prepared!(fx, request, Verify)?
	settings = ResolveBase.settings_of(request, prepared.loaded)
	ResolveBase.check_pin(prepared.loaded, settings, prepared.decision, Verify)?
	started = Start.run!(fx, { roots: request.roots, path_roc: request.compiler, held: prepared.decision.held ?? "", downloads: ResolveBase.ladder_downloads(request) })?
	run = { roots: request.roots, now: request.now, started, probe: ResolveBase.probe_settings(request, prepared.loaded) }
	rows = rows_of(prepared.loaded, request.project)
	match target {
		Project => {
			file = request.project.file.map_err(|_| Fail.new(Usage, "tln probe needs a project file"))?
			kind = prepared.loaded.members.find_first(|m| m.file == file).map_ok(|m| m.locked.kind) ?? App
			done = ProbeUnit.project!(fx, run, { file, kind })?
			Ok({ shown: Project({ file, kind, compiler: started.id, check: done.check, build: done.build, probes: done.probes }), stop: Err(None) })
		}
		_ => {
			node = node_of!(fx, target, rows)?
			program = match target {
				Bundle(_) => unbundle_program(request, { selected: started.id, installed: started.installed })?
				_ => started.program
			}
			materialise!(fx, request, { target, rows, node, program })?
			fact = ProbeUnit.node!(fx, run, node)?
			Ok({ shown: Unit({ node, compiler: started.id, fact, probes: 1 }), stop: Err(None) })
		}
	}
}

# `--range` (R-PB3): no pin decision and no required download. The compilers are the installed ones (R-NI4).
ranged! : Fx, ResolveBase.Request, ProbeCmd.Target => Try(Finished, Fail)
ranged! = |fx, request, target| {
	loaded = ResolveLoad.load!(fx, request)?
	settings = ResolveBase.settings_of(request, loaded)
	rows = rows_of(loaded, request.project)
	node = node_of!(fx, target, rows)?
	installed = Launch.toolchains!(fx, request.roots)
	program = unbundle_program(request, { selected: "", installed })?
	materialise!(fx, request, { target, rows, node, program })?
	found = ProbeSearch.run!(
		fx,
		{
			roots: request.roots,
			net: request.net,
			now: request.now,
			offline: request.offline,
			node,
			installed,
			path: request.compiler,
			nightly: settings.nightly,
			min_age: settings.min_age,
			probe: ResolveBase.probe_settings(request, loaded),
		},
	)?
	Ok({
		shown: Range({ node, found: found.found, probes: found.probes }),
		stop: ProbeCmd.stop({ found: found.found, cut: found.cut, unseen: found.unseen }),
	})
}

# The node of the target: the header entry of an alias (the tie list goes to stderr first), or the hash of a bundle file.
node_of! : Fx, ProbeCmd.Target, List(Locked.Row) => Try(Units.Node, Fail)
node_of! = |fx, target, rows| match target {
	Alias(name) => match ProbeCmd.entry({ text: name, rows }) {
		Ok(node) => Ok(node)
		Err({ fail, block }) => {
			if !block.is_empty() {
				fx.err!(block)
			}
			Err(fail)
		}
	}
	Bundle(path) => {
		hash = ProbeCmd.bundle_hash(path)?
		Ok({ hash, name: hash, version: "", is_platform: Bool.False })
	}
	Project => Err(Fail.new(Internal, "the project file has no hash"))
}

# R-FE4: the program that runs `roc unbundle`. No installed compiler and no `roc` on `PATH` is a required download that this command does not ask for (the failure of `Compiler.failure`).
unbundle_program : ResolveBase.Request, { selected : Str, installed : List(Str) } -> Try(Str, Fail)
unbundle_program = |request, chosen| ProbeCmd.unbundler({ selected: chosen.selected, installed: chosen.installed, path: request.compiler, roots: request.roots }).map_err(|_| Compiler.failure(NoCompiler))

# R-FE1, R-FE2: the package of the target is in `packages/<hash>/`: fetched for an alias, unbundled for a bundle file.
materialise! : Fx, ResolveBase.Request, { target : ProbeCmd.Target, rows : List(Locked.Row), node : Units.Node, program : Str } => Try({}, Fail)
materialise! = |fx, request, what| match what.target {
	Bundle(path) => ProbeBundle.ensure!(fx, { roots: request.roots, path, hash: what.node.hash, program: what.program })
	_ => {
		urls = what.rows.keep_oks(
			|row| match row.what {
				Release(ident) if ident.hash == what.node.hash => Ok(row.value)
				_ => Err(NotThis)
			},
		)
		match Fetch.packages!(fx, { roots: request.roots, urls: urls.take_first(1), offline: request.offline, roc: what.program, downloader: request.net.downloader }) {
			[Err(fail)] => Err(fail)
			_ => Ok({})
		}
	}
}
