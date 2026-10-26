import Closure
import Compiler
import Db
import Evidence
import Facts
import Fail
import Fx
import Ident
import Install
import ResolveBase
import ResolveSelect
import Text
import UnitFlow

## Command code (part C) of the evidence of `tln why` (slice 032b, E1 to E3, R-EF1, R-EF3, R-CM7, R-PH12). The pure decisions are in `Evidence`. `Why.run!` calls `blocks!` after the answers (`Why.answers`) and before the output.
## The calls, in order (the L2 cases `evidence/ev1-why` and `ev2-no-compiler` fix them). Nothing is written, nothing is downloaded and no probe runs:
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | The compiler of each member, once for each member file: the `roc:` pin of its header (rank 3, the answer of the user for R-SO20: the pin wins), else `ROC_TOOLCHAIN` (rank 2, `Compiler.toolchain_of`), else `ResolveSelect.peek!` (ranks 4 to 7, with the `roc` on `PATH` from `Install.compiler!`, asked at most once for the run). `Err(None)`: no compiler, so no block for that member and no further call for it. A member with a pin or `ROC_TOOLCHAIN` makes no call for this step | E1, R-SO2, R-SO3, R-SO7, R-PH7 |
## | 2 | A member whose package is not a `Release` row (a path file, a foreign URL) has no hash: it has a compiler in the block, no line and no further call | R-H4 |
## | 3 | One `read_files!` of `<pkgs>/<hash>/main.roc` for each package that is shown with a compiler (none when there is none): `Evidence.pin_of`. An unreadable file is no pin | E3, R-EF1 rank 3 |
## | 4 | One `Facts.load!` (one `db_query!` with `Facts(keys)`) for the keys (hash, compiler, `any`) of the packages that are shown with a compiler (none when there is none). A busy or failing db: the warning of R-CC8 on stderr and no local row. `TooNew` is the failure (exit 19) | E2, R-CC8, R-TF3 |
## | 5 | Slice 068, rank 4 (R-DI8, R-EF1): one `read_files!` of `Github.hint_file` for each package that is shown with a compiler and has a `Github.hint_ref` and a `Github.hint_file` that is `Ok` (the paths in the order of the packages, the same file once). No such package: no call. The text of a file that is there is `Github.hint` of status 200 and that text, so `hint` is `Ok(id)`; a missing, unreadable or empty file, and a text with no id, is `Err(None)`. No request, never: `why` makes no index call (R-DI1, E3) | E3, R-DI8 |
## | 6 | A package with a `Local` fail that has modules: the scan of the used modules of its member (`UnitFlow.scan_in!`: one `read_files!` for each level. The text of the member is the one that the load read, so the member file is not read again) and `Evidence.ignored` with the empty baseline. Each entry is a note (`Evidence.note`). No fail row: no call | E5, R-UM1 |
## | 7 | `Evidence.of_pair` for each package, the block | R-EF3 |
##
## Wiring of the slice (the same table):
##
## | File | Change |
## | --- | --- |
## | `Ls.walk!` | A new public `Ls.walk_full!` that gives `{ closures, request, loaded }` (the `ResolveBase.Request` and the `ResolveBase.Loaded` of the walk). `walk!` calls it and keeps its signature |
## | `ResolveSelect` | A new public `peek!` : `Fx, ResolveBase.Request, ResolveBase.Loaded => Try(Str, [None])`: the steps 2 to 4 of `choose!` (the lists of the installed compilers and `Compiler.select`, one private function that `choose!` calls too) and the id, with no `ranged!` (no download). `NoCompiler` and `NoneInRange` are `Err(None)` |
## | `Why.run!` | `Ls.walk_full!` (with `notes` false), `answers`, `EvidenceFlow.blocks!`, then `Why.show` for the text or `Why.shown_data` for `--json` |
## | `UnitFlow` | A new public `scan_in!` that takes `{ roots, member : { file, kind, text }, walked }`. `scan!` calls it and keeps its signature |
## | `UnitFlow.verdict!` | The result also has `ignored : List(Evidence.Ignored)`: `Evidence.ignored` of the nodes, the facts of the round, the baseline and the scan (`[]` when `used` is `Err(NotScanned)`) |
## | `Ladder` (`probe_in_copy!`, `probe_in_place!`) | After the lines of the check and of the build, one line `note: <Evidence.note>` for each entry of `verdict.ignored` (`compiler` is `ctx.held`). So the summary of `install`, `add`, `update`, `upgrade`, `verify` and `remove` has the notes after the build line, in `data.notes` too (E5) |
EvidenceFlow :: [].{

	## A package that `why` shows: the `file` of its member, the closure of the member and the row of the package.
	Shown : { file : Str, walked : Closure.Walked, target : Closure.Row }

	## The block of each package, in the order of `shown`. See the table above.
	blocks! : Fx, { request : ResolveBase.Request, loaded : ResolveBase.Loaded }, List(EvidenceFlow.Shown) => Try(List(Evidence.Block), Fail)
	blocks! = |fx, ctx, shown| {
		files = unique(shown.map(|s| s.file))
		compilers = compilers_of!(fx, ctx, files)
		items = shown.map(
			|s| {
				compiler = compilers.find_first(|c| c.file == s.file).map_ok(|c| c.compiler) ?? Err(None)
				hash = if s.target.kind == Release Ident.of_url(s.target.id).map_ok(|i| i.hash).map_err(|_| NoHash) else Err(NoHash)
				{ shown: s, compiler, hash }
			},
		)
		active = items.keep_oks(|item| active_of(item))
		pins = pins_of!(fx, ctx.request.roots.pkgs, unique(active.map(|a| a.hash)))
		keys = active.map(|a| { hash: a.hash, nightly: a.compiler, target: "any" }).fold([], |found, key| if found.contains(key) found else found.append(key))
		facts = Facts.load!(fx, { roots: ctx.request.roots, keys })?
		lines_of = |a| Evidence.of_pair({ hash: a.hash, compiler: a.compiler, facts, pin: pins.find_first(|(h, _)| h == a.hash).map_ok(|(_, pin)| pin) ?? Err(NoPin), hint: Err(None) })
		failing = active.keep_if(|a| lines_of(a).any(|l| l.source == Local and l.result == Fail and !l.modules.is_empty()))
		scans = scans_of!(fx, ctx, { failing, shown })
		Ok(
			items.map(
				|item| match (item.compiler, item.hash) {
					(Ok(compiler), Ok(hash)) => {
						a = { file: item.shown.file, hash, compiler }
						used = scans.find_first(|scan| scan.file == a.file).map_ok(|scan| scan.used)
						notes = match used {
							Ok(found) => Evidence.ignored({ hashes: [hash], facts, nightly: compiler, baseline: [], used: found }).map(|e| Evidence.note({ path: e.path, compiler }))
							Err(_) => []
						}
						{ compiler: item.compiler, lines: lines_of(a), notes }
					}
					_ => { compiler: item.compiler, lines: [], notes: [] }
				},
			),
		)
	}
}

# A package that `why` shows with a compiler and a hash (steps 2 to 7).
Active : { file : Str, hash : Str, compiler : Str }

active_of : { shown : EvidenceFlow.Shown, compiler : Try(Str, [None]), hash : Try(Str, [NoHash]) } -> Try(Active, [Skip])
active_of = |item| match (item.compiler, item.hash) {
	(Ok(compiler), Ok(hash)) => Ok({ file: item.shown.file, hash, compiler })
	_ => Err(Skip)
}

unique : List(Str) -> List(Str)
unique = |texts| texts.fold([], |found, text| if found.contains(text) found else found.append(text))

# Step 1: the pin of the header of the member, else `ROC_TOOLCHAIN` (a bad value is no value, Q2), else `ResolveSelect.peek!`. The `roc` on `PATH` is asked at most once.
compilers_of! : Fx, { request : ResolveBase.Request, loaded : ResolveBase.Loaded }, List(Str) => List({ file : Str, compiler : Try(Str, [None]) })
compilers_of! = |fx, ctx, files| {
	toolchain = match Compiler.toolchain_of(ctx.request.downloads.env) {
		Ok(found) => found
		Err(_) => Err(Unset)
	}
	var $request = ctx.request
	var $asked = Bool.False
	var $found = []
	for file in files {
		pin = match ctx.loaded.members.find_first(|m| m.file == file) {
			Ok(member) => member.locked.roc
			Err(_) => Err(NoPin)
		}
		compiler = match (pin, toolchain) {
			(Ok(id), _) => Ok(id)
			(Err(NoPin), Ok(id)) => Ok(id)
			(Err(NoPin), Err(Unset)) => {
				if !$asked {
					$request = { ..$request, compiler: Install.compiler!(fx, ctx.request.roots, Bool.False) }
					$asked = Bool.True
				}
				ResolveSelect.peek!(fx, $request, ctx.loaded)
			}
		}
		$found = $found.append({ file, compiler })
	}
	$found
}

# Step 3: the `roc:` pin of the header of each package (one `read_files!`). An unreadable file is no pin.
pins_of! : Fx, Str, List(Str) => List((Str, Try(Str, [NoPin])))
pins_of! = |fx, pkgs, hashes| if hashes.is_empty() {
	[]
} else {
	paths = hashes.map(|hash| Text.join(Text.join(pkgs, hash), "main.roc"))
	hashes.map2(
		paths.map2(fx.read_files!(paths), |path, read| (path, read)),
		|hash, (path, read)| (
			hash,
			match read {
				Ok(text) => Evidence.pin_of({ path, text })
				Err(_) => Err(NoPin)
			},
		),
	)
}

# Step 6: the used modules of each member that has a package with a fail that names modules (one scan for each member file).
scans_of! : Fx, { request : ResolveBase.Request, loaded : ResolveBase.Loaded }, { failing : List(Active), shown : List(EvidenceFlow.Shown) } => List({ file : Str, used : List({ hash : Str, path : Str }) })
scans_of! = |fx, ctx, run| {
	var $scans = []
	for file in unique(run.failing.map(|a| a.file)) {
		member = ctx.loaded.members.find_first(|m| m.file == file)
		header = ctx.loaded.headers.find_first(|h| h.path == file)
		match (member, header, run.shown.find_first(|s| s.file == file)) {
			(Ok(m), Ok(h), Ok(s)) => {
				walked = s.walked
				$scans = $scans.append({ file, used: UnitFlow.scan_in!(fx, { roots: ctx.request.roots, member: { file, kind: m.locked.kind, text: h.text }, walked }) })
			}
			_ => {}
		}
	}
	$scans
}
