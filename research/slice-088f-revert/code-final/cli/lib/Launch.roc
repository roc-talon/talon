import Clock
import Compiler
import Fail
import Fx
import Link
import Roots
import Text

## How `tln` starts a compiler (slice 023c). The `roc` proxy (CLI 6.2, `Proxy`) and the probes of the other commands (`Ladder`) start the selected compiler the same way, so this module holds what they share.
## It has no import of `Proxy`, `Install` or `Ladder`: `Proxy` imports `Install`, and `Install` leads to `Ladder`, so a shared function in `Proxy` would be an import cycle. The code of slice 023
## (`Proxy.program`, `Proxy.child_env`, `Proxy.last_use` and the private `installed!`, `canonical_at`, `clean`) moves here with the same behavior. `Proxy.run!` calls these functions, and `Ladder` calls them too.
##
## | Function | Part | Used by | Rule |
## | --- | --- | --- | --- |
## | `program` | A | `program!` (the id is not a link) | R-PX2, R-SO10 |
## | `program!` | C | `Proxy.run!` step 9g, `Ladder` step 0c | R-PX2, R-LK4 |
## | `child_env` | A | the same | R-PX6, R-PX7, R-EV17 |
## | `last_use` | A | `touch!` | R-CC9 |
## | `toolchains!` | C | `Proxy.run!` step 7, `Ladder` step 0a | R-LY1 |
## | `touch!` | C | `Proxy.run!` step 10, `Ladder` before each round of probes | R-CC9 |
## | `child_env!` | C | `Proxy.run!` step 11, `Ladder` step 0c | R-PX6 |
Launch :: [].{

	## R-PX2, R-SO10 (moved from `Proxy.program`, slice 023): the program that runs for the selected `id`. An id in `installed` is `<cache>/toolchains/<id>/roc` (`Roots.item` with `ToolchainRoc`): the managed copy wins when the `roc` on
	## `PATH` has the same id. Else the file of `path` (the path as `PATH` wrote it). The name `roc` is never the result (the first `roc` on `PATH` can be the launcher).
	program : { roots : Roots, id : Str, installed : List(Str), path : Try({ id : Str, path : Str }, [NoCompiler]) } -> Str
	program = |run| match run.path {
		Ok(found) if found.id == run.id and !run.installed.contains(run.id) => found.path
		_ => Roots.item(run.roots, ToolchainRoc(run.id))
	}

	## R-LK4, R-PX2, R-R5 (slice 024b): the program that runs for the selected `id`, for the proxy and for each probe. `program` is the answer, except for a link:
	##
	## | Case | Calls | Result |
	## | --- | --- | --- |
	## | `id` starts with `link-` and is in `installed` | One `read_files!` of `<cache>/toolchains/<id>/.talon.json` (`Roots.item(ToolchainMeta(id))`) | `Link.target`: the absolute path that the file records. A failure of it is the failure of the run (exit 18 or 19). |
	## | Any other id (a nightly, a release, `git-<name>`, `copy-<name>`, the `roc` on `PATH`) | None | `Ok(Launch.program(run))`: `copy-<name>` is `toolchains/copy-<name>/roc`, the copy that `roc link --copy` made (R-LK2) |
	##
	## The caller calls it once for a run (the proxy, `Ladder.run!`, `Ladder.verify!`), before `touch!` and `child_env!`, so a broken link ends the run before a write or a start.
	program! : Fx, { roots : Roots, id : Str, installed : List(Str), path : Try({ id : Str, path : Str }, [NoCompiler]) } => Try(Str, Fail)
	program! = |fx, run| if run.id.starts_with("link-") and run.installed.contains(run.id) {
		path = Roots.item(run.roots, ToolchainMeta(run.id))
		text = match fx.read_files!([path]) {
			[one] => one
			_ => Err(Other("no result"))
		}
		Link.target({ id: run.id, path, text })
	} else {
		Ok(Launch.program(run))
	}

	## R-PX6, R-EV17, R-PX7 (moved from `Proxy.child_env`, slice 023): the variables that Talon sets for the compiler. In this order: `XDG_CACHE_HOME` and `ROC_CACHE_DIR`, then `TALON_IN_PROXY=1`. `xdg` is the path of `XDG_CACHE_HOME` (the directory of
	## `Roots.cache`), `build` is `Roots.build`. `canonical` is what `Fx.canonical!` gave for the path. A path that does not exist (`Err(Failed)`) is the path with its `.` and `..` parts removed (`Launch.clean_text`), so a `..` never reaches roc (Q15 of the design).
	## Opted out (R-PX7): only `TALON_IN_PROXY=1`. A probe is never opted out (question Q1 of slice 023c: it sets the same 3 variables as the proxy does, R-PX6 "Probes use the same rule").
	child_env : { opted_out : Bool, windows : Bool, xdg : { path : Str, canonical : Try(Str, [Failed]) }, build : { path : Str, canonical : Try(Str, [Failed]) } } -> List((Str, Str))
	child_env = |facts| {
		inside = ("TALON_IN_PROXY", "1")
		if facts.opted_out {
			[inside]
		} else {
			[("XDG_CACHE_HOME", clean(facts.windows, facts.xdg)), ("ROC_CACHE_DIR", clean(facts.windows, facts.build)), inside]
		}
	}

	## R-CC9 (moved from `Proxy.last_use`, slice 023): the text of `.last-use`: the time of Talon as `Clock.format_utc` and a line end, for example `2026-10-22T12:00:00Z\n`. (The format is a proposal of slice 023, TW24.)
	last_use : U64 -> Str
	last_use = |now| "${Clock.format_utc(now)}\n"

	## R-LY1 (moved from the private `installed!` of `Proxy`, slice 023): the compilers in `<cache>/toolchains`. One `list_dirs!` call, and `Compiler.installed` on the entries. A missing directory is empty.
	toolchains! : Fx, Roots => List(Str)
	toolchains! = |fx, roots| match fx.list_dirs!([Text.join(roots.cache, "toolchains")]) {
		[Ok(found)] => Compiler.installed(found)
		_ => []
	}

	## R-CC9: the `.last-use` of the installed compiler `id`. One `write_atomic!` of `<cache>/toolchains/<id>/.last-use` with `last_use(now)` (R-CC1). A write error is ignored (Q7 of slice 023: a run does not stop for it).
	## The caller calls it before the compiler starts, and only for an id that is in `toolchains!` (the `roc` on `PATH` has no toolchain dir). `now` is the time of Talon (`TALON_NOW`, R-EV22).
	touch! : Fx, Roots, { id : Str, now : U64 } => {}
	touch! = |fx, roots, run| {
		_ = fx.write_atomic!([{ path: Roots.item(roots, ToolchainLastUse(run.id)), content: Launch.last_use(run.now) }])
		{}
	}

	## Slice 088c, R-PX6, R-LY5: the path of `XDG_CACHE_HOME` for the compiler: the directory of the cache root `cache` (`Roots.cache`). On Windows the root is `<dir>\roc` and the dir may have `/` (an `XDG_CACHE_HOME` with `/`), so the cut is at the last `\` or `/`, whichever is later: `C:\u\AppData\Local\roc` gives `C:\u\AppData\Local`. On another system the cut is at the last `/` only (a `\` is a letter of a name): `Text.dir_of`. No separator: the empty text. `child_env!` calls it with `fx.windows!()`.
	xdg_dir : { windows : Bool, cache : Str } -> Str
	xdg_dir = |x| {
		slash = Text.dir_of(x.cache)
		back = Str.join_with(x.cache.split_on("\\").drop_last(1), "\\")
		if x.windows and back.count_utf8_bytes() > slash.count_utf8_bytes() back else slash
	}

	## Slice 088d and 088e, R-PX6, Design Q212 and Q214: the text-only cleanup of a path that does not exist (no file system call, no symlink resolved). `windows` gives the separator: on Windows each `/` becomes `\`, and the parts are split at `\`; on another system only `/` separates (a `\` is a letter of a name).
	## The root stays: `/` (Linux), `\` (Windows with no drive), `<drive>:\` or the UNC prefix `\\server\share` (Windows). A path that is not absolute gets no root. Each `.` part and each empty part is removed, and each `..` part removes the part before it (never a part of the root). The parts are joined with the separator.
	## Rows: `("/h/./a/../b", Linux)` gives `/h/b`. `("C:/a/../b", Windows)` gives `C:\b`. `("\\srv\sh\..\x", Windows)` gives `\\srv\sh\x`. `("x/./y", Windows)` gives `x\y`. Slice 088f, Q216: a UNC root has a `\\` at the end (`\\srv\sh` gives `\\srv\sh\`), `//srv/sh` is UNC on Windows, and a `..` that starts a relative path stays (`..\a` on Windows, `../a` on other systems). A `..` after a root removes nothing.
	clean_text : { windows : Bool, path : Str } -> Str
	clean_text = |x| {
		sep = if x.windows "\\" else "/"
		text = if x.windows x.path.replace_each("/", "\\") else x.path
		all = text.split_on(sep)
		head = all.first() ?? ""
		server = all.get(2) ?? ""
		share = all.get(3) ?? ""
		unc = x.windows and head == "" and all.get(1) == Ok("") and server != "" and share != ""
		drive = x.windows and head.count_utf8_bytes() == 2 and head.ends_with(":")
		rooted = head == "" and all.len() > 1
		skip = if unc 4 else if drive 1 else if rooted 1 else 0
		root = if unc "${sep}${sep}${server}${sep}${share}${sep}" else if drive "${head}${sep}" else if rooted sep else ""
		var $kept = []
		for part in all.drop_first(skip) {
			if part == "" or part == "." {
				{}
			} else if part == ".." {
				$kept = if ($kept == [] and root == "") or $kept.last() == Ok("..") $kept.append("..") else $kept.drop_last(1)
			} else {
				$kept = $kept.append(part)
			}
		}
		"${root}${Str.join_with($kept, sep)}"
	}

	## R-PX6 (the steps 11 of `Proxy.run!`, moved): the variables for the compiler. One `canonical!` call with 2 paths (the directory of `roots.cache`, then `roots.build`), in this order, and `child_env` on the results.
	## With `opted_out`, no call, and `child_env` with the paths as they are.
	child_env! : Fx, Roots, { opted_out : Bool } => List((Str, Str))
	child_env! = |fx, roots, run| {
		xdg = Launch.xdg_dir({ windows: fx.windows!(), cache: roots.cache })
		canonical = if run.opted_out [] else fx.canonical!([xdg, roots.build])
		Launch.child_env({
			opted_out: run.opted_out,
			windows: fx.windows!(),
			xdg: { path: xdg, canonical: canonical_at(canonical, 0) },
			build: { path: roots.build, canonical: canonical_at(canonical, 1) },
		})
	}
}

# R-PX6: a path with no `.` and no `..` part, for a path that `canonical!` could not resolve.
clean : Bool, { path : Str, canonical : Try(Str, [Failed]) } -> Str
clean = |windows, dir| match dir.canonical {
	Ok(real) => real
	Err(Failed) => Launch.clean_text({ windows, path: dir.path })
}

# The result of `canonical!` for the path at `at`.
canonical_at : List(Try(Str, [NotFound, Denied, Other(Str)])), U64 -> Try(Str, [Failed])
canonical_at = |results, at| match results.get(at) {
	Ok(Ok(real)) => Ok(real)
	_ => Err(Failed)
}
