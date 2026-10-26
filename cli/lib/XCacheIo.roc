import Fail
import Fx
import Gc
import Roots
import Setup
import SetupIo
import Text
import ToolInstall
import ToolsJson
import XCache

## The files of the `x` cache (slice 049, CLI 6.4: R-X2, R-B9, R-CC1, R-CC11, R-TF3, R-TF6). Command code over `Fx`. `XCache` decides. `XFlow` (`tln x`) and `XTake` (`tln tool install`) call these steps.
## The calls, in order (the L2 cases `x/x1-run`, `x/x2-offline`, `tool/tk1-takeover` and `gc/gc4-x` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | `entries!` 1 | One `list_dirs!` of `<cache>/talon/x` (a missing dir is empty): `Gc.entries`, `XCache.dirs_of`. | R-X2, R-LY1 |
## | `entries!` 2 | With one entry dir or more: one `read_files!` of `XCache.manifest_of(dir)` for each, in the order of the dirs, then `XCache.entries_of`. No call for no dir. | R-B9 |
## | `entries!` 3 | A warning on stderr (`warning: <text>`) for each manifest that gave `Delete`, then one `delete!` of those entry dirs (R-TF6). The entries that `Use` and `Ignore` give no message. | R-TF3, R-TF6 |
## | `entries!` 4 | With one entry or more (after the deletes of step 3): one `list_dirs!` of the entry dirs, in order. An entry whose dir has not the file that its manifest names (`has_file`, slice 073: the repo name, `.exe` on Windows only) gets `has_bin` false (Q-X3). No call for no entry. | R-B1 |
## | `write!` | `copy_file!` of the build output to `layout.temp_bin` (it makes the temp dir), `sha256_file!` of `temp_bin`, one `write_atomic!` of `layout.temp_manifest`, then, when `layout.dir` is in `stale` (an entry with no binary, Q-X3), `delete!` of it, then `rename!` of `layout.temp` to `layout.dir`. `Exists` (another run made the entry first, R-CC11): `delete!` of the temp dir, the entry that is there stays. Any other error: `SetupIo.dropped!` (`delete!` of the temp dir, a failure of kind `Environment`). | R-X2, R-CC1, R-CC11 |
## | `touch!` | One `write_atomic!` of the manifest with the new `last_run` (R-X2: the time of each run). A failed write is a failure of kind `Environment`. | R-X2, R-GC9 |
XCacheIo :: [].{

	## What `write!` made: the entry and its binary.
	Written : { found : XCache.Found, bin : Str }

	## `entries!` 1 to 3: the entries of `talon/x`. `os` is the system: it fixes the file that a manifest names (`file_of`, R-B10).
	entries! : Fx, Roots, Setup.Os => Try(List(XCache.Found), Fail)
	entries! = |fx, roots, os| {
		x_dir = Text.join(roots.cache, "talon/x")
		entries = Gc.entries({ dirs: [x_dir], listed: fx.list_dirs!([x_dir]) })
		dirs = XCache.dirs_of({ roots, entries })
		if dirs.is_empty() return Ok([])
		got = XCache.entries_of({ dirs, reads: fx.read_files!(dirs.map(XCache.manifest_of)) })
		for warning in got.warnings {
			fx.err!("warning: ${warning}\n")
		}
		if !got.delete.is_empty() {
			_ = fx.delete!(got.delete)
		}
		if got.found.is_empty() return Ok([])
		listings = fx.list_dirs!(got.found.map(|f| f.dir))
		Ok(got.found.map2(listings, |f, listed| { ..f, has_bin: has_file(listed, file_of({ os, name: f.entry.name })) }))
	}

	## `write!`: the new entry of a build that passed. `built` is the attempt (`ToolBuild.built!`): its `layout.output` is the binary. `entry` is the manifest. `hex` is `Temp.hex(Fx.random!())`.
	write! : Fx, Roots, { entry : XCache.Entry, output : Str, os : Setup.Os, hex : Str, stale : List(Str) } => Try(XCacheIo.Written, Fail)
	write! = |fx, roots, facts| {
		entry = facts.entry
		digest = XCache.digest({ name: entry.name, bundle: entry.bundle, hashes: entry.hashes, nightly: entry.nightly, target: entry.target })
		lay = XCache.layout({ roots, digest, hex: facts.hex, file: file_of({ os: facts.os, name: entry.name }) })
		match fx.copy_file!({ from: facts.output, to: lay.temp_bin }) {
			Ok(_) => {}
			Err(NotFound) => return Err(ToolInstall.build_failed({ name: entry.name, version: ToolsJson.source_text(entry.source), id: entry.nightly, class: Pass, errors: [], output: facts.output }))
			Err(err) => return Err(SetupIo.dropped!(fx, lay.temp, "cannot copy ${facts.output} to ${lay.temp_bin}: ${Str.inspect(err)}"))
		}
		sha = match fx.sha256_file!(lay.temp_bin) {
			Ok(got) => got
			Err(err) => return Err(SetupIo.dropped!(fx, lay.temp, "cannot read ${lay.temp_bin}: ${Str.inspect(err)}"))
		}
		match SetupIo.write_file!(fx, lay.temp_manifest, XCache.manifest_text({ ..entry, sha256: sha })) {
			Ok(_) => {}
			Err(fail) => {
				_ = fx.delete!([lay.temp])
				return Err(fail)
			}
		}
		if facts.stale.contains(lay.dir) {
			_ = fx.delete!([lay.dir])
		}
		made = { found: { dir: lay.dir, entry: { ..entry, sha256: sha }, has_bin: Bool.True }, bin: lay.bin }
		match fx.rename!({ from: lay.temp, to: lay.dir }) {
			Ok(_) => Ok(made)
			Err(Exists) => {
				_ = fx.delete!([lay.temp])
				Ok(made)
			}
			Err(err) => Err(SetupIo.dropped!(fx, lay.temp, "cannot make ${lay.dir}: ${Str.inspect(err)}"))
		}
	}

	## `touch!`: the manifest of `found` with `last_run` set to `last_run` (the time of Talon as `Clock.format_utc`).
	touch! : Fx, XCache.Found, Str => Try({}, Fail)
	touch! = |fx, found, last_run| SetupIo.write_file!(fx, XCache.manifest_of(found.dir), XCache.manifest_text({ ..found.entry, last_run }))

	## Q-X3, R-B10 (slice 073): does an entry dir have the binary? It has when it holds the file that the manifest names: a file (not a directory) with exactly the name `file`. `file` is the repo name of the full name, with `.exe` on Windows only (`XCache.layout`, R-X2). So `fmt.exe` is no binary
	## for `fmt` on Linux and `fmt` is no binary for `fmt.exe` on Windows. A dir that cannot be listed has none. `entries!` gives one `list_dirs!` result as `listed`, and the file.
	has_file : Try(List({ name : Str, is_dir : Bool, mtime : U64 }), [NotFound, Denied, Other(Str)]), Str -> Bool
	has_file = |listed, file| match listed {
		Ok(found) => found.any(|e| !e.is_dir and e.name == file)
		Err(_) => Bool.False
	}

	## The binary of an entry: `<dir>/<file>` (`XCache.layout`).
	bin_of : { found : XCache.Found, os : Setup.Os } -> Str
	bin_of = |facts| Text.join(facts.found.dir, file_of({ os: facts.os, name: facts.found.entry.name }))
}

# The file in an entry dir: the repo name of the full name (D2), with `.exe` on Windows.
file_of : { os : Setup.Os, name : Str } -> Str
file_of = |facts| ToolInstall.file_name({ os: facts.os, key: Text.last_segment(facts.name) })
