import lib.Help
import lib.Intent

ChannelreadTest :: [].{}

# Slice 238 (docs/slices/238-channel-tables.md), R-CH1 R-CH2 R-CH3 R-CH10 R-CH17 R-TF4 R-TF8 R-WS5, Design Q612 (G-C242).
# The tests call no new name: they call `Intent.read` (talon.toml) and `Intent.read_config` (config.toml) and look at the failure or the warnings.
# The texts of the messages are proposals (TW24).

hint = "A newer tln may know this value. Update tln: tln tool update talon"

lines = |list| "${Str.join_with(list, "\n")}\n"

# A valid channel table (R-CH10: all parameters, no defaults). `name` is the table name.
table = |name| ["[channels.${name}]", "shape = \"github-release\"", "source = \"Karakatiza666/roc-reify-nightlies\"", "tag-prefix = \"nightly-reify-\""]

# The result of a read as a plain value: the failure as (exit code, message), or the warnings.
project = |role, text| match Intent.read({ path: "/p/talon.toml", text, role }) {
	Ok(done) => Ok(done.warnings)
	Err(f) => Err((f.kind.code(), f.message))
}

config = |text| match Intent.read_config({ path: "/c/config.toml", text }) {
	Ok(done) => Ok(done.warnings)
	Err(f) => Err((f.kind.code(), f.message))
}

# R-CH10 R-CH1: a valid table is a known table. No failure, no warning, in talon.toml (Standalone and Root) and in config.toml.
expect {
	text = lines(table("reify"))
	got = [project(Standalone, text), project(Root, "[workspace]\nmembers = []\n\n${text}"), config(text)]
	dbg got
	got == [Ok([]), Ok([]), Ok([])]
}

# R-CH10 R-CH3: two valid tables, and a name with a digit and a `-`, are no fault.
expect {
	text = lines(table("reify").concat([""]).concat(table("my-fork2")))
	got = [project(Standalone, text), config(text)]
	dbg got
	got == [Ok([]), Ok([])]
}

# R-CH10 R-CH1 R-CH2 R-CH3: a reserved name is exit 19, also with the values of the built-in table (a user cannot change a built-in table). No hint line: the name is no value of a known key.
expect {
	names = ["nightly", "stable", "git", "link", "copy", "zig", "debug", "local", "compat"]
	got = names.map(|n| (project(Standalone, lines(table(n))), config(lines(table(n)))))
	want = names.map(|n| (Err((19, "/p/talon.toml:1: channels.${n}: '${n}' is a reserved channel name")), Err((19, "/c/config.toml:1: channels.${n}: '${n}' is a reserved channel name"))))
	dbg got
	got == want
}

# R-CH10 R-CH2: the built-in values do not make `nightly` free.
expect {
	text = lines(["[channels.nightly]", "shape = \"github-release\"", "source = \"roc-lang/nightlies\"", "tag-prefix = \"nightly-\""])
	got = [project(Standalone, text), config(text)]
	dbg got
	got == [Err((19, "/p/talon.toml:1: channels.nightly: 'nightly' is a reserved channel name")), Err((19, "/c/config.toml:1: channels.nightly: 'nightly' is a reserved channel name"))]
}

# R-CH10 R-TF8 R-EC19: an unknown `shape` word is exit 19 with the hint line (a newer tln may know it). The line is the line of the key.
expect {
	text = lines(["", "[channels.reify]", "shape = \"git-build\"", "source = \"a/b\"", "tag-prefix = \"x-\""])
	got = [project(Standalone, text), config(text)]
	dbg got
	got == [
		Err((19, "/p/talon.toml:3: channels.reify.shape: 'git-build' is not a channel shape\n${hint}")),
		Err((19, "/c/config.toml:3: channels.reify.shape: 'git-build' is not a channel shape\n${hint}")),
	]
}

# R-CH10 R-TF4 R-TF8: a `shape` or a `source` that is not a string is exit 19 with the hint line.
expect {
	shape = lines(["[channels.reify]", "shape = 5", "source = \"a/b\"", "tag-prefix = \"x-\""])
	source = lines(["[channels.reify]", "shape = \"github-release\"", "source = 5", "tag-prefix = \"x-\""])
	got = [project(Standalone, shape), project(Standalone, source), config(shape), config(source)]
	dbg got
	got == [
		Err((19, "/p/talon.toml:2: channels.reify.shape: must be a string\n${hint}")),
		Err((19, "/p/talon.toml:3: channels.reify.source: must be a string\n${hint}")),
		Err((19, "/c/config.toml:2: channels.reify.shape: must be a string\n${hint}")),
		Err((19, "/c/config.toml:3: channels.reify.source: must be a string\n${hint}")),
	]
}

# R-CH10 R-TF4: an unknown key in a channel table is a warning that names the key and its line. The table is read as before.
expect {
	text = lines(table("reify").concat(["color = \"red\""]))
	got = [project(Standalone, text), config(text)]
	dbg got
	got == [Ok(["/p/talon.toml:5: unknown key channels.reify.color"]), Ok(["/c/config.toml:5: unknown key channels.reify.color"])]
}

# R-CH10: the first fault by line wins (the order of the file), also when a reserved name comes after a bad shape.
expect {
	text = lines(["[channels.reify]", "shape = \"nope\"", "source = \"a/b\"", "tag-prefix = \"x-\"", "", "[channels.git]", "shape = \"github-release\"", "source = \"a/b\"", "tag-prefix = \"x-\""])
	got = project(Standalone, text)
	dbg got
	got == Err((19, "/p/talon.toml:2: channels.reify.shape: 'nope' is not a channel shape\n${hint}"))
}

# R-CH17 R-TF4 (guard, green): the other tables and keys of a file with no `[channels]` read as before. An unknown table is still a warning.
expect {
	text = lines(["[toolchain]", "nightly = true", "", "[mystery]", "a = 1"])
	got = project(Standalone, text)
	dbg got
	got == Ok(["/p/talon.toml:4: unknown table [mystery]"])
}

# R-CH17 R-TF4 (guard, green): an unknown top-level key of config.toml is still a warning.
expect {
	got = config("mystery = 1\n")
	dbg got
	got == Ok(["/c/config.toml:1: unknown key mystery"])
}

# Design Q613 item 1 (R-CH10): a table with a missing key is exit 19, `channels.<name>: missing key <key>`, on the line of the header, with no hint line. Both files.
expect {
	no_shape = lines(["", "[channels.reify]", "source = \"a/b\"", "tag-prefix = \"x-\""])
	no_source = lines(["[channels.reify]", "shape = \"github-release\"", "tag-prefix = \"x-\""])
	no_prefix = lines(["[channels.reify]", "shape = \"github-release\"", "source = \"a/b\""])
	got = [project(Standalone, no_shape), project(Standalone, no_source), project(Root, "[workspace]\nmembers = []\n\n${no_prefix}"), config(no_shape), config(no_source), config(no_prefix)]
	dbg got
	got == [
		Err((19, "/p/talon.toml:2: channels.reify: missing key shape")),
		Err((19, "/p/talon.toml:1: channels.reify: missing key source")),
		Err((19, "/p/talon.toml:4: channels.reify: missing key tag-prefix")),
		Err((19, "/c/config.toml:2: channels.reify: missing key shape")),
		Err((19, "/c/config.toml:1: channels.reify: missing key source")),
		Err((19, "/c/config.toml:1: channels.reify: missing key tag-prefix")),
	]
}

# Design Q613 item 2 (R-CH3, R-CH10): a table name that R-CH3 refuses is exit 19 like a reserved name (no hint line). The text is a proposal (TW24).
expect {
	names = ["Reify", "a", "abcdefghijklmnopqrstuvwxy", "ab-", "1ab"]
	got = names.map(|n| (project(Standalone, lines(table(n))), config(lines(table(n)))))
	want = names.map(|n| (Err((19, "/p/talon.toml:1: channels.${n}: '${n}' is not a channel name")), Err((19, "/c/config.toml:1: channels.${n}: '${n}' is not a channel name"))))
	dbg got
	got == want
}

# Design Q613 item 3 (R-WS5, R-CH10): `[channels]` in a member file is exit 19 like `[toolchain]`: the table is not allowed (no hint line). A Standalone and a Root file take it (expect 1).
expect {
	got = project(Member, lines(table("reify")))
	dbg got
	got == Err((19, "/p/talon.toml:1: the table [channels] is not allowed in a workspace member file (it has only dependencies, overrides, patch and build)"))
}

# Design Q613 item 7 (R-TF4, R-TF8): `channels` that is not a table, or an item that is not a table: exit 19 with the hint line. Both files. The text is a proposal (TW24).
expect {
	five = "channels = 5\n"
	item = lines(["[channels]", "reify = \"x\""])
	got = [project(Standalone, five), project(Standalone, item), config(five), config(item)]
	dbg got
	got == [
		Err((19, "/p/talon.toml:1: channels: must be a table\n${hint}")),
		Err((19, "/p/talon.toml:2: channels.reify: must be a table\n${hint}")),
		Err((19, "/c/config.toml:1: channels: must be a table\n${hint}")),
		Err((19, "/c/config.toml:2: channels.reify: must be a table\n${hint}")),
	]
}

# Design Q613 item 9 (R-TF10): the version gate wins over a channel fault in the same talon.toml, also when the channel fault has the earlier line.
expect {
	text = lines(table("git").concat(["", "[toolchain]", "tln = \">=999.0.0\""]))
	got = project(Standalone, text)
	dbg got
	got == Err((19, "/p/talon.toml:7: this project needs tln >=999.0.0, this is tln ${Help.version}. Run: tln tool update talon"))
}
