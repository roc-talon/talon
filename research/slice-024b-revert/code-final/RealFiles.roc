import pf.Env
import pf.IOErr
import pf.Path
import lib.Temp
import lib.Text
import RealBase

## The file calls of the real `Fx` (read, write, list, delete, canonical, copy, sha256, `PATH` files). No Talon logic (TW4).
RealFiles :: [].{

	read_files! : List(Str) => List(Try(Str, [NotFound, Denied, Other(Str)]))
	read_files! = |paths| {
		var $results = []
		for p in paths {
			one = match Path.read_utf8!(Path.utf8(p)) {
				Ok(text) => Ok(text)
				Err(PathErr(err, _)) => Err(RealBase.file_err(err))
			}
			$results = $results.append(one)
		}
		$results
	}

	write_atomic! : List({ path : Str, content : Str }) => Try({}, { path : Str, err : [NotFound, Denied, Other(Str)] })
	write_atomic! = |files| {
		var $failure = no_failure
		for file in files {
			if $failure == None {
				$failure = match write_one!(file) {
					Ok(_) => None
					Err(PathErr(err, _)) => Some({ path: file.path, err: RealBase.file_err(err) })
				}
			}
		}
		match $failure {
			None => Ok({})
			Some(failure) => Err(failure)
		}
	}

	## One directory: the name, the kind and the modification time (seconds) of each entry. The order is the order of the
	## file system. No Talon logic: `Project` and `Temp` sort and choose.
	list_dirs! : List(Str) => List(Try(List({ name : Str, is_dir : Bool, mtime : U64 }), [NotFound, Denied, Other(Str)]))
	list_dirs! = |dirs| {
		var $results = []
		for dir in dirs {
			$results = $results.append(list_one!(dir))
		}
		$results
	}

	## A file or a directory with its content. A path that does not exist is not an error.
	delete! : List(Str) => List(Try({}, [NotFound, Denied, Other(Str)]))
	delete! = |paths| {
		var $results = []
		for p in paths {
			path = Path.utf8(p)
			one = match Path.type!(path) {
				Err(PathErr(NotFound, _)) => Ok({})
				Err(PathErr(err, _)) => Err(RealBase.file_err(err))
				Ok(IsDir) => match Path.delete_all!(path) {
					Ok(_) => Ok({})
					Err(PathErr(err, _)) => Err(RealBase.file_err(err))
				}
				Ok(_) => match Path.delete!(path) {
					Ok(_) => Ok({})
					Err(PathErr(err, _)) => Err(RealBase.file_err(err))
				}
			}
			$results = $results.append(one)
		}
		$results
	}

	canonical! : List(Str) => List(Try(Str, [NotFound, Denied, Other(Str)]))
	canonical! = |paths| {
		var $results = []
		for p in paths {
			one = match Path.canonicalize!(Path.utf8(p)) {
				Ok(path) => Ok(path.display())
				Err(PathErr(err, _)) => Err(RealBase.file_err(err))
			}
			$results = $results.append(one)
		}
		$results
	}

	## Slice 006 (`Fx.copy_tree!`): a file or a directory whose name is in `skip` is not copied. `NotFound` and `Exists` are found before anything is made.
	## The L3 case `fx/pr1-real-fx-probes` checks it.
	copy_tree! : { from : Str, to : Str, skip : List(Str) } => Try({}, [NotFound, Exists, Denied, Other(Str)])
	copy_tree! = |move| {
		from = Path.utf8(move.from)
		to = Path.utf8(move.to)
		if !exists!(from) {
			Err(NotFound)
		} else if exists!(to) {
			Err(Exists)
		} else {
			_ = Path.create_all!(Path.utf8(Text.dir_of(move.to)))
			copy_dir!(from, to, move.skip)
		}
	}

	## Slice 024b (`Fx.copy_file!`, R-LK2): one file, with its permission bits (the executable bit of a compiler). The doc of `Fx.copy_file!` has the rules. The L3 case `fx/lk1-real-fx-copy-file` checks it.
	copy_file! : { from : Str, to : Str } => Try({}, [NotFound, Exists, Denied, Other(Str)])
	copy_file! = |move| {
		from = Path.utf8(move.from)
		to = Path.utf8(move.to)
		if !exists!(from) {
			Err(NotFound)
		} else if exists!(to) {
			Err(Exists)
		} else if is_directory!(from) {
			Err(Other("is a directory"))
		} else {
			_ = Path.create_all!(Path.utf8(Text.dir_of(move.to)))
			match Path.copy!(from, to) {
				Ok(_) => Ok({})
				Err(CopyErr({ error, .. })) => Err(copy_err(error))
			}
		}
	}

	# R-CV4: the sha256 of the bytes of a file, as 64 lower case hex digits.
	sha256_file! : Str => Try(Str, [NotFound, Denied, Other(Str)])
	sha256_file! = |path| match Path.read_bytes!(Path.utf8(path)) {
		Ok(bytes) => Ok(Crypto.SHA256.hash(bytes).to_hex())
		Err(PathErr(err, _)) => Err(RealBase.file_err(err))
	}

	## R-SO9: the `roc` files of the directories of `PATH`, in order, and the running program. The doc of `Fx.path_roc!` has the rules.
	path_roc! : () => { exe : Try({ path : Str, size : U64, mtime : U64 }, [Unknown]), found : List({ path : Str, size : U64, mtime : U64 }) }
	path_roc! = || {
		path_var = match RealBase.env_all!().find_first(|(name, _)| name == "PATH") {
			Ok((_, text)) => text
			Err(_) => ""
		}
		dirs = path_var.split_on(":").keep_if(|dir| !dir.is_empty())
		var $found = []
		for dir in dirs {
			path = "${dir}/roc"
			match runnable_file!(path, Path.utf8(path)) {
				Ok(file) => {
					$found = $found.append(file)
				}
				Err(Skip) => {}
			}
		}
		exe = match Env.exe_path!() {
			Ok(here) => {
				real = match Path.canonicalize!(here) {
					Ok(resolved) => resolved
					Err(_) => here
				}
				runnable_facts!(real.display(), real)
			}
			Err(_) => Err(Skip)
		}
		{ exe: exe.map_err(|Skip| Unknown), found: $found }
	}
}

## R-CC1: a temp file `<target>.<16hex>.tmp` in the directory of the target, then `rename` over the target. The
## missing parent directories of the target are made first. It stops at the first error.
WriteFailure : [None, Some({ path : Str, err : [NotFound, Denied, Other(Str)] })]

no_failure : WriteFailure
no_failure = None

write_one! : { path : Str, content : Str } => Try({}, [PathErr(IOErr, Path)])
write_one! = |file| {
	parent = Text.dir_of(file.path)
	if !parent.is_empty() {
		_ = Path.create_all!(Path.utf8(parent))
	}
	tmp = Path.utf8(Temp.name({ target: file.path, hex: Temp.hex(RealBase.draw!()) }))
	match Path.write_utf8!(tmp, file.content) {
		Err(e) => Err(e)
		Ok(_) => match Path.rename!(tmp, Path.utf8(file.path)) {
			Ok(_) => Ok({})
			Err(e) => {
				_ = Path.delete!(tmp)
				Err(e)
			}
		}
	}
}

list_one! : Str => Try(List({ name : Str, is_dir : Bool, mtime : U64 }), [NotFound, Denied, Other(Str)])
list_one! = |dir| match Path.list!(Path.utf8(dir)) {
	Err(PathErr(err, _)) => Err(RealBase.file_err(err))
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
			mtime = match Path.time_modified!(p) {
				Ok(ns) => (ns // 1_000_000_000).to_u64_wrap()
				Err(_) => 0
			}
			$entries = $entries.append({ name, is_dir, mtime })
		}
		Ok($entries)
	}
}

exists! : Path => Bool
exists! = |path| match Path.exists!(path) {
	Ok(found) => found
	Err(_) => Bool.False
}

# A directory, or a link that points to one (`Path.is_dir!` does not follow a link).
is_directory! : Path => Bool
is_directory! = |path| match Path.canonicalize!(path) {
	Ok(real) => match Path.is_dir!(real) {
		Ok(found) => found
		Err(_) => Bool.False
	}
	Err(_) => Bool.False
}

copy_dir! : Path, Path, List(Str) => Try({}, [NotFound, Exists, Denied, Other(Str)])
copy_dir! = |from, to, skip| {
	match Path.create_all!(to) {
		Ok(_) => {}
		Err(PathErr(err, _)) => return Err(copy_err(err))
	}
	entries = match Path.list!(from) {
		Ok(list) => list
		Err(PathErr(err, _)) => return Err(copy_err(err))
	}
	for entry in entries {
		name = match Path.filename(entry) {
			Ok(f) => f.display()
			Err(_) => entry.display()
		}
		if !skip.contains(name) {
			target = Path.join(to, name)
			# A link is copied as the file or the directory that it points to.
			result = match Path.is_dir!(entry) {
				Ok(Bool.True) => copy_dir!(entry, target, skip)
				_ => match Path.copy!(entry, target) {
					Ok(_) => Ok({})
					Err(CopyErr({ error, .. })) => Err(copy_err(error))
				}
			}
			match result {
				Ok(_) => {}
				Err(failure) => return Err(failure)
			}
		}
	}
	Ok({})
}

copy_err : IOErr -> [NotFound, Exists, Denied, Other(Str)]
copy_err = |err| match err {
	NotFound => NotFound
	AlreadyExists => Exists
	PermissionDenied => Denied
	other => Other(Str.inspect(other))
}

# A file of `PATH`: a link is resolved first (`Path.is_file!` is false for a link). The file must be one that the user can run.
runnable_file! : Str, Path => Try({ path : Str, size : U64, mtime : U64 }, [Skip])
runnable_file! = |text, path| match Path.canonicalize!(path) {
	Ok(real) => match (Path.is_file!(real), Path.is_executable!(real)) {
		(Ok(Bool.True), Ok(Bool.True)) => runnable_facts!(text, real)
		_ => Err(Skip)
	}
	Err(_) => Err(Skip)
}

# The size in bytes and the modification time (seconds) of `real`, with the name `text`.
runnable_facts! : Str, Path => Try({ path : Str, size : U64, mtime : U64 }, [Skip])
runnable_facts! = |text, real| match (Path.size_in_bytes!(real), Path.time_modified!(real)) {
	(Ok(size), Ok(ns)) => Ok({ path: text, size, mtime: (ns // 1_000_000_000).to_u64_wrap() })
	_ => Err(Skip)
}
