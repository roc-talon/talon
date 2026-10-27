import Ident
import Args
import Db
import Fail
import JsonDoc
import Locked
import Lookup
import Opts
import Probe
import ProbeRange
import ProbeShow
import Project
import Ref
import Scope
import Text
import Units

## The command `tln probe [alias|<bundle file>] [--range]` (slice 037, R-CM8, R-PB1, R-PB2, R-PB3, R-PB4, R-PB7, R-LB3, R-SC1, R-SC16, R-PD14). It runs probes and prints the facts. It writes no project file (R-PB7). Its facts go in `compat.db` (R-P4).
## Part A (pure) is `read`, `entry`, `bundle_hash`, `stop`, `text` and `data`. `ProbeFlow.run!` is the command code (TESTING.md 2.2 part C, slice 039s). The slice file `docs/slices/037-probe.md` has the questions and the proposals of the texts (TW24).
##
## The three targets (R-PB1) and what `ProbeFlow.run!` does for each. The calls are fixed by the L2 cases `probe/pc1-targets` and `probe/pc2-range`.
##
## | Target | No `--range` (R-PB2) | `--range` (R-PB3, R-PB4) |
## | --- | --- | --- |
## | `Alias(text)`: the header entry that `entry` finds | The hash of the entry is fetched when it is not in `packages/` (R-FE1). One unit probe (`roc check main.roc` in `packages/<hash>/`) on the compiler that Resolution 13 selects (the selection of `tln verify`, R-SO21), one fact (R-P4, `existing=replace`) | The search of `ProbeRange`: the compiler list D, the facts of the hash on D (one `db_query`), rounds of unit probes on the installed candidates, the facts written after each round (R-PP4). With the opt-in (`--probe-downloads` or `--yes`, R-NI4) more rounds on compilers that are downloaded, inside the cap `probe.max-toolchains` (slice 037c, the doc of `ProbeSearch`) |
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

	## The end of a probe for the output: the class of the probe (`Probe.classify`) and its errors (`Probe.errors`). `Pass`, `Fail`, `Hang` and `Crash` only: a probe with no fact is a failure of the command (R-P3).
	Done : { class : Probe.Class, errors : List(Probe.Err) }

	## What a run found, for `text` and `data`. `probes` is the number of probes that started (R-PP4).
	##
	## | Tag | Holds |
	## | --- | --- |
	## | `Unit` | An alias or a bundle without `--range`: the node, the compiler id, and the fact that was written (`Db.Fact`: the hash, the compiler, the target `any`, the outcome and the failing modules) |
	## | `Project` | The project file, its kind, the compiler id, the check and the build. `build` is `Err(NotRun)` when the check did not pass, or the file is a package or a platform |
	## | `Range` | The node, `ProbeRange.Found`, the number of probes, and the number of compilers that the search downloaded (slice 037c) |
	Shown : [
		Unit({ node : Units.Node, compiler : Str, fact : Db.Fact, probes : U64 }),
		Project({ file : Str, kind : [App, Package, Platform], compiler : Str, check : ProbeCmd.Done, build : Try(ProbeCmd.Done, [NotRun]), probes : U64 }),
		Range({ node : Units.Node, found : ProbeRange.Found, probes : U64, downloads : U64 }),
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
	## | `Range` | `kind` (`"range"`), `hash`, `label`, `range` (null for `NoPass`, else `{ "from": { "id", "real" }, "to": { "id", "real" } }`), `probes`, `downloads` (slice 037c: the number of compilers that the search downloaded, as `data.downloads` of slice 025) |
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
		Range({ node, found, probes, downloads }) => JsonDoc.Obj([
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
			("downloads", Num(downloads.to_i64_wrap())),
		])
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
