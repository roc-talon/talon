## Small text helpers of the pure decisions: the byte order of paths and the segments of a path.
## `Str` has no default order, so every sorted list in Talon uses `Text.compare` (TW2: sorted output).
Text :: [].{

	## The byte order of two texts.
	compare : Str, Str -> [Before, Same, After]
	compare = |a, b| compare_bytes(a.to_utf8(), b.to_utf8(), 0)

	## The list in byte order.
	sorted : List(Str) -> List(Str)
	sorted = |items| items.sort_with(Text.compare)

	## The list in byte order, with no repeated text.
	sorted_unique : List(Str) -> List(Str)
	sorted_unique = |items| Text.sorted(items).fold(
		[],
		|kept, item| if kept.last() == Ok(item) kept else kept.append(item),
	)

	## The last segment of a path: `/a/b/c` gives `c`.
	last_segment : Str -> Str
	last_segment = |path| match path.split_on("/").last() {
		Ok(name) => name
		Err(_) => path
	}

	## The directory part of a path: `/a/b/c` gives `/a/b`. A name with no `/` gives the empty text.
	dir_of : Str -> Str
	dir_of = |path| Str.join_with(path.split_on("/").drop_last(1), "/")

	## The 1-based line of a byte offset in a text.
	line_of : Str, U64 -> U64
	line_of = |text, offset| 1 + text.to_utf8().sublist({ start: 0, len: offset }).keep_if(|b| b == 10).len()

	## The absolute path of `path` seen from the absolute directory `dir`, with the `.` and `..` parts and the double `/` removed. A `path` that starts with `/` ignores `dir`.
	resolve : Str, Str -> Str
	resolve = |dir, path| {
		full = if path.starts_with("/") path else "${dir}/${path}"
		parts = full.split_on("/").fold(
			[],
			|kept, part| match part {
				"" | "." => kept
				".." => kept.drop_last(1)
				_ => kept.append(part)
			},
		)
		"/${Str.join_with(parts, "/")}"
	}

	## A directory and a name. The root `/` gives `/name`.
	join : Str, Str -> Str
	join = |dir, name| if dir.ends_with("/") "${dir}${name}" else "${dir}/${name}"
}

compare_bytes : List(U8), List(U8), U64 -> [Before, Same, After]
compare_bytes = |a, b, i| match (a.get(i), b.get(i)) {
	(Err(_), Err(_)) => Same
	(Err(_), Ok(_)) => Before
	(Ok(_), Err(_)) => After
	(Ok(x), Ok(y)) => if x < y Before else if x > y After else compare_bytes(a, b, i + 1)
}
