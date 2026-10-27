import Fx
import PathRoc
import Roots

## The `roc` on `PATH` (rank 7, R-SO9, slice 026): a leaf module, so that `Install` (the commands that resolve), `Base` (the base of a relative step) and the proxy share one body.
## `Install.on_path_file!` calls it. The calls are those of slice 022b (`path_roc!`, the cache `path-roc.json`, `sha256_file!`, one `spawn_all!` of `<roc> version`).
OnPath :: [].{

	## Slice 023: the id of the `roc` on `PATH` and the path of its file, as `PATH` wrote it. The loop does what `PathRoc.step` says. The cache `path-roc.json` is read when a `roc` file is on `PATH`,
	## and written when `PathRoc.save` says so (R-CC1, no lock: D7). A hash that fails ends the walk with no compiler. A job that cannot start leaves no row (N6).
	file! : Fx, Roots => Try({ id : Str, path : Str }, [NoCompiler])
	file! = |fx, roots| {
		facts = fx.path_roc!()
		if facts.found.is_empty() return Err(NoCompiler)
		cache = Roots.item(roots, PathRocJson)
		read = PathRoc.read(
			match fx.read_files!([cache]) {
				[one] => one
				_ => Err(NotFound)
			},
		)
		match PathRoc.warning({ path: cache, state: read.state }) {
			Ok(text) => fx.err!("warning: ${text}\n")
			Err(None) => {}
		}
		var $entries = read.entries
		var $result = Err(NoCompiler)
		var $done = Bool.False
		for _ in (0.U64).until(3 * facts.found.len() + 2) {
			if !$done {
				match PathRoc.step({ exe: facts.exe, found: facts.found, entries: $entries }) {
					Hash(file) => match fx.sha256_file!(file.path) {
						Ok(sha256) => {
							$entries = PathRoc.add_sha($entries, file, sha256)
						}
						Err(_) => {
							$done = Bool.True
						}
					}
					Version(file) => {
						$done = Bool.True
						match fx.spawn_all!({ jobs: [{ argv: [file.path, "version"], cwd: Err(Inherit) }], limit: 1 }) {
							[ran] => match ran.ended {
								NotStarted(_) => {}
								_ => {
									finished = PathRoc.finish({ entries: $entries, file, text: ran.stdout })
									$entries = finished.entries
									$result = finished.id.map_ok(|id| { id, path: file.path })
								}
							}
							_ => {}
						}
					}
					Done(id) => {
						$done = Bool.True
						$result = match id {
							Ok(found) => cached_path(facts.found, $entries, found).map_ok(|path| { id: found, path })
							Err(NoCompiler) => Err(NoCompiler)
						}
					}
				}
			}
		}
		match PathRoc.save({ state: read.state, before: read.entries, after: $entries, extra: read.extra }) {
			Write(content) => {
				_ = fx.write_atomic!([{ path: cache, content }])
			}
			Skip => {}
		}
		$result
	}
}

# R-SO9: the file of a cache hit is the first file of `PATH` whose valid row has this id.
cached_path : List(PathRoc.File), List(PathRoc.Entry), Str -> Try(Str, [NoCompiler])
cached_path = |found, entries, id| {
	hit = |file| entries.any(|e| e.path == file.path and e.size == file.size and e.mtime == file.mtime and e.id == Id(id))
	match found.find_first(hit) {
		Ok(file) => Ok(file.path)
		Err(NotFound) => Err(NoCompiler)
	}
}
