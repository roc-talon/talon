import pf.Path

## Small helpers that the other `Fake*` modules share (the call log, reading a file, the text lines, the files that a fake call makes). No Talon logic (TW4).
FakeBase :: [].{

	## One line in `<w>/out/calls.log`.
	log! : Str, Str => {}
	log! = |w, line| append!("${w}/out/calls.log", "${line}\n")

	## The text of a file, or the empty text when it cannot be read.
	read_or_empty! : Str => Str
	read_or_empty! = |path| match Path.read_utf8!(Path.utf8(path)) {
		Ok(text) => text
		Err(_) => ""
	}

	## The text is added at the end of the file.
	append! : Str, Str => {}
	append! = |path, text| {
		_ = Path.write_utf8!(Path.utf8(path), "${read_or_empty!(path)}${text}")
	}

	## The lines of a text, with the empty ones (an empty line is an answer: Enter). A last newline ends the last line.
	keep_empty : Str -> List(Str)
	keep_empty = |text| {
		parts = text.split_on("\n")
		if parts.last() == Ok("") parts.drop_last(1) else parts
	}

	## The lines of a text, without the empty ones.
	lines : Str -> List(Str)
	lines = |text| text.split_on("\n").keep_if(|l| !l.is_empty())

	exists! : Str => Bool
	exists! = |path| match Path.exists!(Path.utf8(path)) {
		Ok(b) => b
		Err(_) => Bool.False
	}

	## A write that creates the missing parent directories first (a decision of slice 002).
	write_with_parents! : Str, Str => Try({}, [PathErr(_, Path)])
	write_with_parents! = |file_path, content| {
		parent = Str.join_with(file_path.split_on("/").drop_last(1), "/")
		if !parent.is_empty() {
			_ = Path.create_all!(Path.utf8(parent))
		}
		Path.write_utf8!(Path.utf8(file_path), content)
	}

	## `file:<path>`, `dir:<path>` or `copy:<dest>=<source>`
	create_item! : Str => {}
	create_item! = |item| {
		if item.starts_with("dir:") {
			_ = Path.create_all!(Path.utf8(item.drop_prefix("dir:")))
		} else if item.starts_with("file:") {
			_ = write_with_parents!(item.drop_prefix("file:"), "fake")
		} else if item.starts_with("copy:") {
			match item.drop_prefix("copy:").split_on("=") {
				[dest, source] => {
					_ = write_with_parents!(dest, read_or_empty!(source))
				}
				_ => {}
			}
		}
	}
}
