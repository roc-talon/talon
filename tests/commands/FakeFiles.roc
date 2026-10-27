import pf.Path
import lib.Text
import FakeBase

## The file calls of the fake `Fx` (read, write, list, tree info, delete, canonical, rename, make dirs, copy, hard link, sha256). They read and write real files in the case dir `<w>`.
## The table of the `fx/` files and the log lines is in the doc of `FakeFx`. Each call gets the case dir `w` first.
FakeFiles :: [].{

	read_files! : Str, List(Str) => List(Try(Str, [NotFound, Denied, Other(Str)]))
	read_files! = |w, paths| {
		FakeBase.log!(w, "read_files ${Str.join_with(paths, " ")}")
		var $results = []
		for p in paths {
			one = match Path.read_utf8!(Path.utf8(p)) {
				Ok(text) => Ok(text)
				Err(PathErr(NotFound, _)) => Err(NotFound)
				Err(PathErr(PermissionDenied, _)) => Err(Denied)
				Err(PathErr(other, _)) => Err(Other(Str.inspect(other)))
			}
			$results = $results.append(one)
		}
		$results
	}

	write_atomic! : Str, List({ path : Str, content : Str }) => Try({}, { path : Str, err : [NotFound, Denied, Other(Str)] })
	write_atomic! = |w, files| {
		FakeBase.log!(w, "write_atomic ${Str.join_with(files.map(|f| f.path), " ")}")
		var $failed = Err(NotYet)
		for file in files {
			match $failed {
				Err(NotYet) => match FakeBase.write_with_parents!(file.path, file.content) {
					Ok(_) => {}
					Err(PathErr(NotFound, _)) => {
						$failed = Ok({ path: file.path, err: NotFound })
					}
					Err(PathErr(PermissionDenied, _)) => {
						$failed = Ok({ path: file.path, err: Denied })
					}
					Err(PathErr(other, _)) => {
						$failed = Ok({ path: file.path, err: Other(Str.inspect(other)) })
					}
				}
				Ok(_) => {}
			}
		}
		match $failed {
			Err(NotYet) => Ok({})
			Ok(failure) => Err(failure)
		}
	}

	list_dirs! : Str, List(Str) => List(Try(List({ name : Str, is_dir : Bool, mtime : U64 }), [NotFound, Denied, Other(Str)]))
	list_dirs! = |w, dirs| {
		FakeBase.log!(w, "list_dirs ${Str.join_with(dirs, " ")}")
		overrides = FakeBase.lines(FakeBase.read_or_empty!("${w}/fx/mtimes")).map(split_time)
		var $results = []
		for dir in dirs {
			$results = $results.append(list_one!(dir, overrides))
		}
		$results
	}

	tree_info! : Str, List(Str) => List(Try({ newest : U64, size : U64 }, [NotFound, Denied, Other(Str)]))
	tree_info! = |w, paths| {
		FakeBase.log!(w, "tree_info ${Str.join_with(paths, " ")}")
		overrides = FakeBase.lines(FakeBase.read_or_empty!("${w}/fx/mtimes")).map(split_time)
		unreadable = FakeBase.lines(FakeBase.read_or_empty!("${w}/fx/treeinfo")).keep_if(|l| l.starts_with("denied ")).map(|l| l.drop_prefix("denied "))
		var $results = []
		for p in paths {
			one = if unreadable.any(|suffix| p.ends_with(suffix)) Err(Denied) else tree_one!(p, overrides)
			$results = $results.append(one)
		}
		$results
	}

	delete! : Str, List(Str) => List(Try({}, [NotFound, Denied, Other(Str)]))
	delete! = |w, paths| {
		FakeBase.log!(w, "delete ${Str.join_with(paths, " ")}")
		refused = FakeBase.lines(FakeBase.read_or_empty!("${w}/fx/delete")).keep_if(|l| l.starts_with("denied ")).map(|l| l.drop_prefix("denied "))
		var $results = []
		for p in paths {
			one = if refused.any(|suffix| p.ends_with(suffix)) {
				Err(Denied)
			} else {
				match Path.type!(Path.utf8(p)) {
					Err(PathErr(NotFound, _)) => Ok({})
					Err(PathErr(PermissionDenied, _)) => Err(Denied)
					Err(PathErr(other, _)) => Err(Other(Str.inspect(other)))
					Ok(IsDir) => match Path.delete_all!(Path.utf8(p)) {
						Ok(_) => Ok({})
						Err(PathErr(err, _)) => Err(Other(Str.inspect(err)))
					}
					Ok(_) => match Path.delete!(Path.utf8(p)) {
						Ok(_) => Ok({})
						Err(PathErr(err, _)) => Err(Other(Str.inspect(err)))
					}
				}
			}
			$results = $results.append(one)
		}
		$results
	}

	canonical! : Str, List(Str) => List(Try(Str, [NotFound, Denied, Other(Str)]))
	canonical! = |w, paths| {
		FakeBase.log!(w, "canonical ${Str.join_with(paths, " ")}")
		var $results = []
		for p in paths {
			one = match Path.exists!(Path.utf8(p)) {
				Ok(Bool.True) => Ok(p)
				Ok(Bool.False) => Err(NotFound)
				Err(PathErr(PermissionDenied, _)) => Err(Denied)
				Err(PathErr(other, _)) => Err(Other(Str.inspect(other)))
			}
			$results = $results.append(one)
		}
		$results
	}

	rename! : Str, { from : Str, to : Str } => Try({}, [NotFound, Exists, Denied, Other(Str)])
	rename! = |w, move| {
		FakeBase.log!(w, "rename ${move.from} ${move.to}")
		refused = FakeBase.lines(FakeBase.read_or_empty!("${w}/fx/rename")).keep_if(|l| l.starts_with("exists ")).map(|l| l.drop_prefix("exists "))
		if refused.any(|suffix| move.to.ends_with(suffix)) {
			Err(Exists)
		} else {
			match Path.rename!(Path.utf8(move.from), Path.utf8(move.to)) {
				Ok(_) => Ok({})
				Err(PathErr(AlreadyExists, _)) => Err(Exists)
				Err(PathErr(NotFound, _)) => Err(NotFound)
				Err(PathErr(PermissionDenied, _)) => Err(Denied)
				Err(PathErr(Other(text), _)) => if text.contains("not empty") Err(Exists) else Err(Other(text))
				Err(PathErr(other, _)) => Err(Other(Str.inspect(other)))
			}
		}
	}

	make_dirs! : Str, List(Str) => Try({}, [Denied, Other(Str)])
	make_dirs! = |w, dirs| {
		FakeBase.log!(w, "make_dirs ${Str.join_with(dirs, " ")}")
		var $failure = Ok({})
		for dir in dirs {
			if $failure == Ok({}) {
				$failure = match Path.create_all!(Path.utf8(dir)) {
					Ok(_) => Ok({})
					Err(PathErr(PermissionDenied, _)) => Err(Denied)
					Err(PathErr(err, _)) => Err(Other(Str.inspect(err)))
				}
			}
		}
		$failure
	}

	sha256_file! : Str, Str => Try(Str, [NotFound, Denied, Other(Str)])
	sha256_file! = |w, path| {
		FakeBase.log!(w, "sha256_file ${path}")
		match Path.read_bytes!(Path.utf8(path)) {
			Ok(bytes) => Ok(Crypto.SHA256.hash(bytes).to_hex())
			Err(PathErr(NotFound, _)) => Err(NotFound)
			Err(PathErr(PermissionDenied, _)) => Err(Denied)
			Err(PathErr(other, _)) => Err(Other(Str.inspect(other)))
		}
	}

	## The answer of the fake `copy_tree!` (see the table in `FakeFx.roc`).
	copy_tree! : Str, { from : Str, to : Str, skip : List(Str) } => Try({}, [NotFound, Exists, Denied, Other(Str)])
	copy_tree! = |w, move| {
		FakeBase.log!(w, "copy_tree ${move.from} ${move.to}")
		if FakeBase.exists!(move.to) {
			Err(Exists)
		} else if !FakeBase.exists!(move.from) {
			Err(NotFound)
		} else {
			copy_dir!(move.from, move.to, move.skip)
			Ok({})
		}
	}

	## The answer of the fake `copy_file!` (see the table in `FakeFx.roc`).
	copy_file! : Str, { from : Str, to : Str } => Try({}, [NotFound, Exists, Denied, Other(Str)])
	copy_file! = |w, move| {
		FakeBase.log!(w, "copy_file ${move.from} ${move.to}")
		if FakeBase.exists!(move.to) {
			Err(Exists)
		} else if !FakeBase.exists!(move.from) {
			Err(NotFound)
		} else {
			match Path.is_dir!(Path.utf8(move.from)) {
				Ok(Bool.True) => Err(Other("is a directory"))
				_ => match Path.read_bytes!(Path.utf8(move.from)) {
					Ok(bytes) => {
						_ = Path.create_all!(Path.utf8(Text.dir_of(move.to)))
						match Path.write_bytes!(Path.utf8(move.to), bytes) {
							Ok(_) => Ok({})
							Err(PathErr(PermissionDenied, _)) => Err(Denied)
							Err(PathErr(other, _)) => Err(Other(Str.inspect(other)))
						}
					}
					Err(PathErr(PermissionDenied, _)) => Err(Denied)
					Err(PathErr(other, _)) => Err(Other(Str.inspect(other)))
				}
			}
		}
	}

	## The answer of the fake `hard_link!` (see the table in `FakeFx.roc`).
	hard_link! : Str, { from : Str, to : Str } => Try({}, [NotFound, Exists, Denied, Other(Str)])
	hard_link! = |w, move| {
		FakeBase.log!(w, "hard_link ${move.from} ${move.to}")
		refused = FakeBase.lines(FakeBase.read_or_empty!("${w}/fx/hardlink")).keep_if(|l| l.starts_with("fail ")).map(|l| l.drop_prefix("fail "))
		if refused.any(|suffix| move.to.ends_with(suffix)) {
			Err(Other("cross-device link"))
		} else if FakeBase.exists!(move.to) {
			Err(Exists)
		} else if !FakeBase.exists!(move.from) {
			Err(NotFound)
		} else {
			match Path.is_dir!(Path.utf8(move.from)) {
				Ok(Bool.True) => Err(Other("is a directory"))
				_ => match Path.hard_link!(Path.utf8(move.from), Path.utf8(move.to)) {
					Ok(_) => Ok({})
					Err(PathErr(NotFound, _)) => Err(NotFound)
					Err(PathErr(PermissionDenied, _)) => Err(Denied)
					Err(PathErr(other, _)) => Err(Other(Str.inspect(other)))
				}
			}
		}
	}
}

list_one! : Str, List((Str, U64)) => Try(List({ name : Str, is_dir : Bool, mtime : U64 }), [NotFound, Denied, Other(Str)])
list_one! = |dir, overrides| match Path.list!(Path.utf8(dir)) {
	Err(PathErr(NotFound, _)) => Err(NotFound)
	Err(PathErr(PermissionDenied, _)) => Err(Denied)
	Err(PathErr(other, _)) => Err(Other(Str.inspect(other)))
	Ok(paths) => {
		var $entries = []
		for p in paths {
			name = match Path.filename(p) {
				Ok(f) => f.display()
				Err(_) => p.display()
			}
			is_dir = match Path.is_dir!(p) {
				Ok(b) => b
				Err(_) => Bool.False
			}
			real = match Path.time_modified!(p) {
				Ok(time) => (time.to_nanos_since_epoch() // 1_000_000_000).to_u64_try() ?? 0
				Err(_) => 0
			}
			mtime = match overrides.find_first(|(suffix, _)| "${dir}/${name}".ends_with(suffix)) {
				Ok((_, seconds)) => seconds
				Err(_) => real
			}
			$entries = $entries.append({ name, is_dir, mtime })
		}
		Ok($entries)
	}
}

## The answer of the fake `tree_info!` for one path (see the table in `FakeFx.roc`).
tree_one! : Str, List((Str, U64)) => Try({ newest : U64, size : U64 }, [NotFound, Denied, Other(Str)])
tree_one! = |path, overrides| match tree_files!(path, overrides) {
	Err(err) => Err(err)
	Ok([]) => match Path.type!(Path.utf8(path)) {
		Ok(IsDir) => Ok({ newest: time_of!(path, overrides), size: 0 })
		_ => Ok({ newest: 0, size: 0 })
	}
	Ok(files) => Ok({ newest: files.fold(0, |top, f| if f.time > top f.time else top), size: files.fold(0, |sum, f| sum + f.size) })
}

## The files below a path, with their time and size. A link and any other kind of entry gives no file.
tree_files! : Str, List((Str, U64)) => Try(List({ time : U64, size : U64 }), [NotFound, Denied, Other(Str)])
tree_files! = |path, overrides| match Path.type!(Path.utf8(path)) {
	Err(PathErr(NotFound, _)) => Err(NotFound)
	Err(PathErr(PermissionDenied, _)) => Err(Denied)
	Err(PathErr(other, _)) => Err(Other(Str.inspect(other)))
	Ok(IsFile) => Ok([{ time: time_of!(path, overrides), size: size_of!(path) }])
	Ok(IsDir) => match Path.list!(Path.utf8(path)) {
		Err(PathErr(NotFound, _)) => Err(NotFound)
		Err(PathErr(PermissionDenied, _)) => Err(Denied)
		Err(PathErr(other, _)) => Err(Other(Str.inspect(other)))
		Ok(children) => {
			var $files = []
			for child in children {
				name = match Path.filename(child) {
					Ok(f) => f.display()
					Err(_) => child.display()
				}
				match tree_files!("${path}/${name}", overrides) {
					Ok(more) => {
						$files = $files.concat(more)
					}
					Err(err) => return Err(err)
				}
			}
			Ok($files)
		}
	}
	Ok(_) => Ok([])
}

time_of! : Str, List((Str, U64)) => U64
time_of! = |path, overrides| match overrides.find_first(|(suffix, _)| path.ends_with(suffix)) {
	Ok((_, seconds)) => seconds
	Err(_) => match Path.time_modified!(Path.utf8(path)) {
		Ok(time) => (time.to_nanos_since_epoch() // 1_000_000_000).to_u64_try() ?? 0
		Err(_) => 0
	}
}

size_of! : Str => U64
size_of! = |path| match Path.size_in_bytes!(Path.utf8(path)) {
	Ok(bytes) => bytes
	Err(_) => 0
}

## `<suffix> <seconds>`
split_time : Str -> (Str, U64)
split_time = |line| match line.split_on(" ") {
	[suffix, seconds] => (suffix, U64.from_str(seconds) ?? 0)
	_ => ("", 0)
}

copy_dir! : Str, Str, List(Str) => {}
copy_dir! = |from, to, skip| {
	_ = Path.create_all!(Path.utf8(to))
	match Path.list!(Path.utf8(from)) {
		Err(_) => {}
		Ok(paths) => for p in paths {
			name = match Path.filename(p) {
				Ok(f) => f.display()
				Err(_) => p.display()
			}
			if !skip.contains(name) {
				match Path.is_dir!(p) {
					Ok(Bool.True) => copy_dir!("${from}/${name}", "${to}/${name}", skip)
					_ => match Path.read_bytes!(p) {
						Ok(bytes) => {
							_ = Path.write_bytes!(Path.utf8("${to}/${name}"), bytes)
						}
						Err(_) => {}
					}
				}
			}
		}
	}
}
