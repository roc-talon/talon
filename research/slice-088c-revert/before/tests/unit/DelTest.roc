import lib.Del

DelTest :: [].{}

# Slice 050c (docs/slices/050c-windows-del.md): the pure decisions of the `.del` files of Windows (CLI 6.7, R-ST10). The expected value of each row is the design text or the slice file text, not the code. A wrong row prints with `dbg`.
# `TalonUpdate.is_del`, `stale` and `del_moves` (slice 050) have their rows in `TalonUpdateTest` 8: the rows here use them only through `Del`. The `Fx` calls are in the L2 cases `tests/commands/cases/tool/dl1-sweep`, `dl1b-denied`, `dl2-tool-windows`.

# R-ST10: the dirs of the sweep at each start of `tln` on Windows: the bin dir (`%USERPROFILE%\.local\bin`, R-LY8), then the data bin dir (`<data>/bin`, R-T3, with the roots of `Roots.from_env`). A dir whose variable is not set (or is empty) is left out, with no failure: the sweep never stops a command. The sweep is no part of `Del`: the order of the 2 dirs is the order of the files in the L2 `calls.log`.
expect {
	rows = [
		("both", [("USERPROFILE", "C:\\Users\\u"), ("HOME", "/h")], ["C:\\Users\\u\\.local\\bin", "/h/.local/share/talon/bin"]),
		("a `\\` at the end of USERPROFILE", [("USERPROFILE", "C:\\Users\\u\\"), ("HOME", "/h")], ["C:\\Users\\u\\.local\\bin", "/h/.local/share/talon/bin"]),
		("XDG_DATA_HOME wins for the data dir", [("USERPROFILE", "C:\\Users\\u"), ("HOME", "/h"), ("XDG_DATA_HOME", "/xd")], ["C:\\Users\\u\\.local\\bin", "/xd/talon/bin"]),
		("XDG_DATA_HOME that is no absolute path is ignored", [("USERPROFILE", "C:\\Users\\u"), ("HOME", "/h"), ("XDG_DATA_HOME", "xd")], ["C:\\Users\\u\\.local\\bin", "/h/.local/share/talon/bin"]),
		("no HOME, but the 3 XDG dirs", [("USERPROFILE", "C:\\Users\\u"), ("XDG_CACHE_HOME", "/xc"), ("XDG_CONFIG_HOME", "/xf"), ("XDG_DATA_HOME", "/xd")], ["C:\\Users\\u\\.local\\bin", "/xd/talon/bin"]),
		("no HOME and no XDG dirs: only the bin dir", [("USERPROFILE", "C:\\Users\\u")], ["C:\\Users\\u\\.local\\bin"]),
		("no USERPROFILE: only the data bin dir", [("HOME", "/h")], ["/h/.local/share/talon/bin"]),
		("USERPROFILE is empty", [("USERPROFILE", ""), ("HOME", "/h")], ["/h/.local/share/talon/bin"]),
		("HOME is empty", [("USERPROFILE", "C:\\Users\\u"), ("HOME", "")], ["C:\\Users\\u\\.local\\bin"]),
		("no variable", [("PATH", "/bin")], []),
		("both empty", [("USERPROFILE", ""), ("HOME", "")], []),
		("an empty environment", [], []),
	]
	bad = rows.keep_if(|(_, env, want)| Del.dirs(env) != want).map(|(name, _, _)| name)
	dbg bad
	bad == []
}

# R-ST10: the files that the sweep deletes, from the lists of the dirs in the order of the dirs. A `.del` name is `<name>.<16 lower case hex digits>.del` with a name that is not empty, and the entry must be a file (a dir with such a name stays). Each dir gives its files in byte order. A dir that could not be listed gives none (no failure: the next start tries again).
expect {
	file = |name| { name, is_dir: Bool.False, mtime: 0 }
	dir = |name| { name, is_dir: Bool.True, mtime: 0 }
	bin : Del.Listing
	bin = Ok([
		file("tln.exe"),
		file("roc.0123456789abcdef.del"),
		file("foo.0123456789abcdef.del"),
		dir("sub.0123456789abcdef.del"),
		file("up.0123456789ABCDEF.del"),
		file("short.0123456789abcde.del"),
		file("long.00123456789abcdef.del"),
		file("plain.del"),
		file("foo.0123456789abcdef.del.tmp"),
		file("a.b.fedcba9876543210.del"),
		file(".0123456789abcdef.del"),
	])
	data : Del.Listing
	data = Ok([file("tln.exe"), file("tln.1111111111111111.del")])
	missing : Del.Listing
	missing = Err(NotFound)
	denied : Del.Listing
	denied = Err(Denied)
	other : Del.Listing
	other = Err(Other("disk"))
	rows = [
		("2 dirs, byte order in each dir", ["B", "D"], [bin, data], ["B/a.b.fedcba9876543210.del", "B/foo.0123456789abcdef.del", "B/roc.0123456789abcdef.del", "D/tln.1111111111111111.del"]),
		("the bin dir is not there", ["B", "D"], [missing, data], ["D/tln.1111111111111111.del"]),
		("the data bin dir is denied", ["B", "D"], [bin, denied], ["B/a.b.fedcba9876543210.del", "B/foo.0123456789abcdef.del", "B/roc.0123456789abcdef.del"]),
		("no dir can be listed", ["B", "D"], [other, missing], []),
		("one dir", ["D"], [data], ["D/tln.1111111111111111.del"]),
		("no dir", [], [], []),
	]
	bad = rows.keep_if(|(_, dirs, listed, want)| Del.found({ dirs, listed }) != want).map(|(name, _, _, _)| name)
	dbg bad
	bad == []
}

# R-ST10 R-S3: the files that an install of a tool replaces (`tool install` of an installed tool, `tool update`, `tool rebuild`) and that are renamed to `.del` files first: the data file when its sha256 was read, then the bin dir entry when it is a file (`Sha`, `Unreadable`). A file that is not there is not renamed. A dir is never replaced.
expect {
	got = |old, have| Del.replaced({ data_file: "D/foo.exe", entry: "B/foo.exe", old, have })
	rows = [
		("both", got(Ok("aa"), Sha("aa")), ["D/foo.exe", "B/foo.exe"]),
		("an entry of another file (the verdict of the install decides, not this)", got(Ok("aa"), Sha("bb")), ["D/foo.exe", "B/foo.exe"]),
		("an entry that cannot be read", got(Ok("aa"), Unreadable), ["D/foo.exe", "B/foo.exe"]),
		("no entry", got(Ok("aa"), Absent), ["D/foo.exe"]),
		("the entry is a dir", got(Ok("aa"), Dir), ["D/foo.exe"]),
		("no data file, an entry", got(Err(NotFound), Sha("aa")), ["B/foo.exe"]),
		("no data file, no entry (a first install)", got(Err(NotFound), Absent), []),
		("no data file, a dir", got(Err(NotFound), Dir), []),
	]
	bad = rows.keep_if(|(_, have, want)| have != want).map(|(name, _, _)| name)
	dbg bad
	bad == []
}

# R-ST10 R-B6: the files that `tool remove` renames to `.del` files and then deletes: the bin dir entry when its fate is `Remove` (the entry is the file that tln wrote, R-ST11), then the data file when it is there. `Gone` and `Keep` give no entry (a foreign entry stays, R-ST6).
expect {
	got = |old, fate| Del.removed({ data_file: "D/foo.exe", entry: "B/foo.exe", old, fate })
	rows = [
		("Remove, the data file is there", got(Ok("aa"), Remove), ["B/foo.exe", "D/foo.exe"]),
		("Gone (no entry)", got(Ok("aa"), Gone), ["D/foo.exe"]),
		("Keep (a foreign entry)", got(Ok("aa"), Keep), ["D/foo.exe"]),
		("Remove, no data file", got(Err(NotFound), Remove), ["B/foo.exe"]),
		("Gone, no data file", got(Err(NotFound), Gone), []),
		("Keep, no data file", got(Err(NotFound), Keep), []),
	]
	bad = rows.keep_if(|(_, have, want)| have != want).map(|(name, _, _)| name)
	dbg bad
	bad == []
}
