import Fail
import Fx
import Text

## The small file helpers of `tln setup` (slice 027, split from `Setup`): reads, the listings and the writes that need no decision of `Setup`. The callers are the steps of `Setup.run!`.
SetupIo :: [].{

	# The directory listings (step 4): the files of `<data bin>` and the entries of `<bin>`.
	Listed : { data : List(Str), bin : List({ name : Str, is_dir : Bool }) }

	# A file as text. A file that is not there is `Ok(Err(NotFound))`.
	read_text! : Fx, Str => Try(Try(Str, [NotFound]), Fail)
	read_text! = |fx, path| match fx.read_files!([path]) {
		[Ok(text)] => Ok(Ok(text))
		[Err(NotFound)] => Ok(Err(NotFound))
		[Err(Denied)] => Err(Fail.new(Environment, "cannot read ${path}: permission denied"))
		[Err(Other(text))] => Err(Fail.new(Environment, "cannot read ${path}: ${text}"))
		_ => Err(Fail.new(Internal, "read_files! gave no result"))
	}

	# Step 4: one `list_dirs!` call. A missing dir is empty.
	listings! : Fx, { data_bin : Str, bin : Str } => Try(SetupIo.Listed, Fail)
	listings! = |fx, dirs| match fx.list_dirs!([dirs.data_bin, dirs.bin]) {
		[data, bin] => {
			in_data = entries_of(data, dirs.data_bin)?
			Ok({ data: in_data.keep_if(|e| !e.is_dir).map(|e| e.name), bin: entries_of(bin, dirs.bin)? })
		}
		_ => Err(Fail.new(Internal, "list_dirs! gave no result"))
	}

	entries_of : Try(List({ name : Str, is_dir : Bool, mtime : U64 }), [NotFound, Denied, Other(Str)]), Str -> Try(List({ name : Str, is_dir : Bool }), Fail)
	entries_of = |result, dir| match result {
		Ok(found) => Ok(found.map(|e| { name: e.name, is_dir: e.is_dir }))
		Err(NotFound) => Ok([])
		Err(Denied) => Err(Fail.new(Environment, "cannot read ${dir}: permission denied"))
		Err(Other(text)) => Err(Fail.new(Environment, "cannot read ${dir}: ${text}"))
	}

	# The entry in `<bin>`: not there, a directory, a file that cannot be read, or the sha256 of a file.
	have_of! : Fx, Str, List({ name : Str, is_dir : Bool }), Str => [Absent, Dir, Unreadable, Sha(Str)]
	have_of! = |fx, bin, listed, name| match listed.find_first(|e| e.name == name) {
		Err(_) => Absent
		Ok(found) => if found.is_dir {
			Dir
		} else {
			match fx.sha256_file!(Text.join(bin, name)) {
				Ok(sha) => Sha(sha)
				Err(_) => Unreadable
			}
		}
	}

	# The failure, after the delete of the temp file or dir.
	dropped! : Fx, Str, Str => Fail
	dropped! = |fx, temp, text| {
		_ = fx.delete!([temp])
		Fail.new(Environment, text)
	}

	# One file, with a temp and a rename (R-CC1).
	write_file! : Fx, Str, Str => Try({}, Fail)
	write_file! = |fx, path, content| match fx.write_atomic!([{ path, content }]) {
		Ok(_) => Ok({})
		Err(failure) => Err(Fail.new(Environment, "cannot write ${failure.path}: ${Str.inspect(failure.err)}"))
	}

}
