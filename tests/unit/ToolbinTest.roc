import lib.ConfigToml
import lib.Intent
import lib.ToolBin
import lib.ToolsToml

ToolbinTest :: [].{}

# Slice 091 (docs/slices/091-prebuilt-bin-lock.md): prebuilt binaries of project tools, the pure parts (CLI 6.4: R-PT17, R-PT18, R-PT19, R-PT25, R-LY4). The expected value of each row is the design text or the slice file text, not the code.
# Texts that the design does not give are the proposals of the slice file (TW24).

lines = |list| "${Str.join_with(list, "\n")}\n"

hash = "GTD8yh6ExWViorE8u3JMyK9mC5b6FRuCgpd5xNhd7xtW"

foo10 = "https://github.com/acme/foo/releases/download/1.0.0/${hash}.tar.zst"

foo11 = "https://github.com/acme/foo/releases/download/1.1.0/AL3LZTP3UWR21xDHSrJudR7Cb5ofsXBNqdwip4kv6fVY.tar.zst"

h1 = Str.repeat("a", 64)

h2 = Str.repeat("b", 64)

h3 = Str.repeat("c", 64)

all5 = ["arm64mac", "arm64musl", "x64mac", "x64musl", "x64win"]

# What `Intent.read` gives for `[tools]`: the rows of `tool_bins` and the warnings, or the failure as `<code> <message>`.
read_bins = |text| match Intent.read({ path: "talon.toml", text, role: Standalone }) {
	Ok(r) => Ok((r.intent.tool_bins, r.warnings))
	Err(e) => Err("${e.kind.code().to_str()} ${e.message}")
}

# R-PT17: the 5 targets (R-HF10) in text order, the asset name `<hash>-<target>` (`.exe` for x64win only), and the asset URL: the directory of the release `url` and the name. A URL that is not a release URL (no version, no hash) gives `NotRelease`.
expect {
	dir = "https://github.com/acme/foo/releases/download/1.0.0"
	names = ToolBin.all_targets.map(|t| ToolBin.asset_name({ hash, target: t }))
	urls = ToolBin.all_targets.map(|t| ToolBin.asset_url({ url: foo10, target: t }))
	bad = ToolBin.asset_url({ url: "https://github.com/acme/foo/archive/main.tar.zst", target: "x64musl" })
	ToolBin.all_targets == all5 and names == ["${hash}-arm64mac", "${hash}-arm64musl", "${hash}-x64mac", "${hash}-x64musl", "${hash}-x64win.exe"] and urls == [
		Ok("${dir}/${hash}-arm64mac"),
		Ok("${dir}/${hash}-arm64musl"),
		Ok("${dir}/${hash}-x64mac"),
		Ok("${dir}/${hash}-x64musl"),
		Ok("${dir}/${hash}-x64win.exe"),
	] and bad == Err(NotRelease)
}

# R-PT18: the forms of `bin` that are valid: a table (the targets in text order, whatever the order in the file), the empty table, and `false`. An entry with no `bin` has no row. The key `bin` is no unknown key: no warning.
expect {
	text = lines([
		"[tools]", # 1
		"a = { ref = \"acme/foo\", url = \"${foo10}\", bin = { x64musl = \"${h1}\", arm64mac = \"${h2}\" } }", # 2
		"b = { ref = \"acme/bar\", bin = false }", # 3
		"c = { ref = \"acme/baz\", bin = {} }", # 4
		"d = { ref = \"acme/qux\" }", # 5
	])
	read_bins(text) == Ok((
		[
			{ key: "a", bin: Hashes([{ target: "arm64mac", sha256: h2 }, { target: "x64musl", sha256: h1 }]) },
			{ key: "b", bin: Off },
			{ key: "c", bin: Hashes([]) },
		],
		[],
	))
}

# R-PT18, R-PT1, R-TF4: the other forms of `bin` are exit code 19: `true`, a string, and a value of a known target that is not a sha256 (a key that is not a target is a warning since slice 233, see below) (upper case, short, not a string, with the prefix `sha256:`).
expect {
	msg = "talon.toml:2: tools.a.bin"
	rows = [
		("true", "19 ${msg}: must be a table of target hashes, or false\nA newer tln may know this value. Update tln: tln tool update talon"),
		("\"x\"", "19 ${msg}: must be a table of target hashes, or false\nA newer tln may know this value. Update tln: tln tool update talon"),
		("{ x64musl = \"${Str.repeat("A", 64)}\" }", "19 ${msg}.x64musl: must be 64 lower case hex digits\nA newer tln may know this value. Update tln: tln tool update talon"),
		("{ x64musl = \"abc\" }", "19 ${msg}.x64musl: must be 64 lower case hex digits\nA newer tln may know this value. Update tln: tln tool update talon"),
		("{ x64musl = 1 }", "19 ${msg}.x64musl: must be 64 lower case hex digits\nA newer tln may know this value. Update tln: tln tool update talon"),
		("{ x64musl = \"sha256:${h1}\" }", "19 ${msg}.x64musl: must be 64 lower case hex digits\nA newer tln may know this value. Update tln: tln tool update talon"),
	]
	rows.all(|(value, want)| read_bins(lines(["[tools]", "a = { ref = \"acme/foo\", bin = ${value} }"])) == Err(want))
}

# R-PT18, R-PT19: `put_bin` writes the table in the entry (the list order, one inline table, the other bytes stay, also the comment). The empty list gives `bin = {}`. `drop_bin` removes the table (nothing to remove: the text as it is). A key that is not there: failure of kind `Internal` (code 1).
expect {
	base = lines(["[tools]", "a = { ref = \"acme/a\", url = \"${foo10}\" }  # keep", "b = { ref = \"acme/b\" }"])
	two = [{ target: "x64musl", sha256: h1 }, { target: "x64win", sha256: h2 }]
	put = |text, key, bin| ToolsToml.put_bin({ path: "talon.toml", text, key, bin })
	drop = |text, key| ToolsToml.drop_bin({ path: "talon.toml", text, key })
	set = put(base, "a", two)
	line_a = "a = { ref = \"acme/a\", url = \"${foo10}\", bin = { x64musl = \"${h1}\", x64win = \"${h2}\" } }  # keep"
	empty = put(base, "b", [])
	again = put(set ?? "", "a", [{ target: "x64musl", sha256: h3 }])
	missing = match put(base, "z", two) {
		Ok(_) => "ok"
		Err(e) => "${e.kind.code().to_str()} ${e.message}"
	}
	set == Ok(lines(["[tools]", line_a, "b = { ref = \"acme/b\" }"])) and empty == Ok(lines(["[tools]", "a = { ref = \"acme/a\", url = \"${foo10}\" }  # keep", "b = { ref = \"acme/b\", bin = {} }"])) and again == Ok(lines(["[tools]", "a = { ref = \"acme/a\", url = \"${foo10}\", bin = { x64musl = \"${h3}\" } }  # keep", "b = { ref = \"acme/b\" }"])) and drop(set ?? "", "a") == Ok(base) and drop(base, "a") == Ok(base) and missing == "1 talon.toml: the key 'z' is not there"
}

# R-PT19, R-PT25: `put` (the write of a new `url`) keeps `bin = false` of the entry that it replaces (no command changes it), and drops a `bin` table (it belongs to the old `url`).
expect {
	text = lines(["[tools]", "a = { ref = \"acme/a\", url = \"${foo10}\", bin = false }", "b = { ref = \"acme/b\", url = \"${foo10}\", bin = { x64musl = \"${h1}\" } }"])
	put = |key| ToolsToml.put({ path: "talon.toml", text, key, ref: "acme/foo@^1.1.0", url: foo11 })
	new_a = "a = { ref = \"acme/foo@^1.1.0\", url = \"${foo11}\", bin = false }"
	new_b = "b = { ref = \"acme/foo@^1.1.0\", url = \"${foo11}\" }"
	put("a") == Ok(lines(["[tools]", new_a, "b = { ref = \"acme/b\", url = \"${foo10}\", bin = { x64musl = \"${h1}\" } }"])) and put("b") == Ok(lines(["[tools]", "a = { ref = \"acme/a\", url = \"${foo10}\", bin = false }", new_b]))
}

# R-PT25, R-LY4, R-SE20: the allow decision. The machine key `tool-binaries` (default true) and `bin = false` each switch binaries off. A `bin` table never switches them on against the machine.
expect {
	table = Ok(Hashes([{ target: "x64musl", sha256: h1 }]))
	rows = [
		(Err(Unset), Err(Unset), Bool.True),
		(Ok(Bool.True), table, Bool.True),
		(Ok(Bool.True), Ok(Hashes([])), Bool.True),
		(Ok(Bool.False), Err(Unset), Bool.False),
		(Ok(Bool.False), table, Bool.False),
		(Err(Unset), Ok(Off), Bool.False),
		(Ok(Bool.True), Ok(Off), Bool.False),
		(Ok(Bool.False), Ok(Off), Bool.False),
	]
	rows.all(|(machine, bin, want)| ToolBin.allowed({ machine, bin }) == want)
}

# R-PT25, R-TF4, R-LY4: `tool-binaries` in `config.toml`: a boolean, no unknown-key warning, `Unset` when missing. Another type is exit code 19.
expect {
	read = |text| match ConfigToml.read({ path: "config.toml", text }) {
		Ok(r) => Ok((r.config.tool_binaries, r.warnings))
		Err(e) => Err("${e.kind.code().to_str()} ${e.message}")
	}
	read("tool-binaries = false\n") == Ok((Ok(Bool.False), [])) and read("tool-binaries = true\n") == Ok((Ok(Bool.True), [])) and read("nightly = true\n") == Ok((Err(Unset), [])) and read("tool-binaries = \"no\"\n") == Err("19 config.toml:1: tool-binaries: must be true or false\nA newer tln may know this value. Update tln: tln tool update talon")
}

# R-PT19: the targets that the check tries for an entry whose `url` stays: the ones with no value in `bin` (all 5 with no `bin`, none for `false`). `merge` keeps each old value as it is and adds the found values of the other targets, in text order.
expect {
	have = Ok(Hashes([{ target: "x64musl", sha256: h1 }, { target: "arm64mac", sha256: h1 }]))
	old = [{ target: "arm64mac", sha256: h1 }, { target: "x64musl", sha256: h1 }]
	found = [{ target: "x64win", sha256: h3 }, { target: "x64musl", sha256: h2 }, { target: "arm64musl", sha256: h2 }]
	merged = ToolBin.merge({ old, found })
	ToolBin.to_check(Err(Unset)) == all5 and ToolBin.to_check(Ok(Off)) == [] and ToolBin.to_check(Ok(Hashes([]))) == all5 and ToolBin.to_check(have) == ["arm64musl", "x64mac", "x64win"] and merged == [
		{ target: "arm64mac", sha256: h1 },
		{ target: "arm64musl", sha256: h2 },
		{ target: "x64musl", sha256: h1 },
		{ target: "x64win", sha256: h3 },
	]
}

# R-PT19, R-PT25: which command writes what for `bin`. Only `add --tool`, `update`, `upgrade` and `install` of an entry with only `ref` write. A new `url` gets the new values (also `bin = {}`), or loses the old table when the check did not run (no gh, not allowed). A `url` that stays only gains values. `bin = false` is never changed.
expect {
	old = Ok(Hashes([{ target: "x64musl", sha256: h1 }]))
	set = [{ target: "x64musl", sha256: h2 }]
	more = [{ target: "x64musl", sha256: h2 }, { target: "x64win", sha256: h3 }]
	w = |command, url_changed, allowed, o, ran| ToolBin.write({ command, url_changed, allowed, old: o, ran })
	rows = [
		(w(AddTool, Bool.True, Bool.True, Err(Unset), Ok(set)), Set(set)),
		(w(AddTool, Bool.True, Bool.True, Err(Unset), Ok([])), Set([])),
		(w(Upgrade, Bool.True, Bool.True, old, Ok(more)), Set(more)),
		(w(Update, Bool.True, Bool.True, old, Err(NotRun)), Drop),
		(w(Update, Bool.True, Bool.False, old, Err(NotRun)), Drop),
		(w(Update, Bool.True, Bool.True, Err(Unset), Err(NotRun)), Keep),
		(w(InstallNoUrl, Bool.True, Bool.True, Err(Unset), Ok(set)), Set(set)),
		(w(Update, Bool.False, Bool.True, old, Ok(more)), Set([{ target: "x64musl", sha256: h1 }, { target: "x64win", sha256: h3 }])),
		(w(Update, Bool.False, Bool.True, Err(Unset), Ok(set)), Set(set)),
		(w(Update, Bool.False, Bool.True, old, Ok(set)), Keep),
		(w(Update, Bool.False, Bool.True, Err(Unset), Ok([])), Keep),
		(w(Update, Bool.False, Bool.False, old, Err(NotRun)), Keep),
		(w(Upgrade, Bool.True, Bool.True, Ok(Off), Ok(set)), Keep),
		(w(Upgrade, Bool.True, Bool.False, Ok(Off), Err(NotRun)), Keep),
		(w(InstallUrl, Bool.False, Bool.True, Err(Unset), Ok(set)), Keep),
		(w(Frozen, Bool.False, Bool.True, Err(Unset), Ok(set)), Keep),
		(w(Run, Bool.True, Bool.True, old, Ok(set)), Keep),
		(w(X, Bool.True, Bool.True, old, Ok(set)), Keep),
	]
	rows.all(|(got, want)| got == want)
}

# Slice 233 (docs/slices/233-keep-tools-keys.md, Design Q607): unknown keys of a `[tools]` entry stay. The warning texts are proposals (TW24).
unknown_hint = "A newer tln may know this value. Update tln: tln tool update talon"

# R-PT18, R-TF4, R-TF8: a key of `bin` that is not a target is a warning, not exit code 19. Talon does not check its value (a string that is no sha256, a number). The row of `tool_bins` has the known targets only. The warning names the key and is on the line of the entry.
expect {
	text = lines([
		"[tools]", # 1
		"a = { ref = \"acme/foo\", bin = { x64musl = \"${h1}\", x64glibc = \"${h2}\" } }", # 2
		"b = { ref = \"acme/foo\", bin = { x64glibc = 1 } }", # 3
		"c = { ref = \"acme/foo\", bin = { wasm32 = \"not a hash\", X64MUSL = \"${h1}\" } }", # 4
	])
	read_bins(text) == Ok((
		[
			{ key: "a", bin: Hashes([{ target: "x64musl", sha256: h1 }]) },
			{ key: "b", bin: Hashes([]) },
			{ key: "c", bin: Hashes([]) },
		],
		[
			"talon.toml:2: unknown key tools.a.bin.x64glibc",
			"talon.toml:3: unknown key tools.b.bin.x64glibc",
			"talon.toml:4: unknown key tools.c.bin.wasm32",
			"talon.toml:4: unknown key tools.c.bin.X64MUSL",
		],
	))
}

# R-PT18, R-TF8: a known target with a bad value is still exit code 19, also when an unknown target is in the table (the message is about the known target, with the hint line). A bad `bin` form is exit code 19 as before.
expect {
	msg = "19 talon.toml:2: tools.a.bin"
	rows = [
		("{ x64glibc = \"${h1}\", x64musl = \"abc\" }", "${msg}.x64musl: must be 64 lower case hex digits\n${unknown_hint}"),
		("{ x64musl = 1, x64glibc = 1 }", "${msg}.x64musl: must be 64 lower case hex digits\n${unknown_hint}"),
		("{ x64glibc = \"x\", arm64mac = \"${Str.repeat("A", 64)}\" }", "${msg}.arm64mac: must be 64 lower case hex digits\n${unknown_hint}"),
	]
	rows.all(|(value, want)| read_bins(lines(["[tools]", "a = { ref = \"acme/foo\", bin = ${value} }"])) == Err(want))
}

# R-TF4, R-PT1: an unknown key of an entry is a warning (it is today), not an issue. Subkey warnings come first (sorted by name), then the warnings of unknown `bin` targets (in file order, not sorted), also when all are on one line. The table form `[tools.a]` gives each warning its own line.
expect {
	one_line = lines(["[tools]", "a = { ref = \"acme/foo\", zed = 1, note = \"x\", bin = { x64musl = \"${h1}\", x64glibc = \"${h2}\", wasm32 = \"${h2}\" } }"])
	table = lines(["[tools.a]", "ref = \"acme/foo\"", "note = \"x\"", "[tools.a.bin]", "x64glibc = \"${h2}\""])
	only_note = lines(["[tools]", "a = { ref = \"acme/foo\", note = \"x\" }"])
	read_bins(one_line) == Ok((
		[{ key: "a", bin: Hashes([{ target: "x64musl", sha256: h1 }]) }],
		["talon.toml:2: unknown key tools.a.note", "talon.toml:2: unknown key tools.a.zed", "talon.toml:2: unknown key tools.a.bin.x64glibc", "talon.toml:2: unknown key tools.a.bin.wasm32"],
	)) and read_bins(table) == Ok(([{ key: "a", bin: Hashes([]) }], ["talon.toml:3: unknown key tools.a.note", "talon.toml:5: unknown key tools.a.bin.x64glibc"])) and read_bins(only_note) == Ok(([], ["talon.toml:2: unknown key tools.a.note"]))
}

# R-PT3, R-TF8: `put` (the write of an entry at a new `url`) keeps each key that Talon does not know, with its value, in the order of the file, after `ref` and `url`. `ref` and `url` take the new values. Three rows: one unknown key; two unknown keys of other types around a `bin = false` (it stays where it is, R-PT25); the entry with `ref` only.
expect {
	put = |text, key| ToolsToml.put({ path: "talon.toml", text, key, ref: "acme/foo@^1.1.0", url: foo11 })
	new = "ref = \"acme/foo@^1.1.0\", url = \"${foo11}\""
	text = lines([
		"[tools]",
		"a = { ref = \"acme/a\", url = \"${foo10}\", note = \"keep\" }  # c1",
		"b = { ref = \"acme/b\", n = 5, bin = false, flags = [1, 2] }",
		"c = { ref = \"acme/c\", extra = true }",
	])
	put(text, "a") == Ok(lines(["[tools]", "a = { ${new}, note = \"keep\" }  # c1", "b = { ref = \"acme/b\", n = 5, bin = false, flags = [1, 2] }", "c = { ref = \"acme/c\", extra = true }"])) and put(text, "b") == Ok(lines(["[tools]", "a = { ref = \"acme/a\", url = \"${foo10}\", note = \"keep\" }  # c1", "b = { ${new}, n = 5, bin = false, flags = [1, 2] }", "c = { ref = \"acme/c\", extra = true }"])) and put(text, "c") == Ok(lines(["[tools]", "a = { ref = \"acme/a\", url = \"${foo10}\", note = \"keep\" }  # c1", "b = { ref = \"acme/b\", n = 5, bin = false, flags = [1, 2] }", "c = { ${new}, extra = true }"]))
}

# R-PT19, R-PT18, R-TF8: `put` at a new `url` drops the whole `bin` table, with a target that Talon does not know, and keeps the unknown subkeys. The write of the new table after it (`put_bin`, as `apply` does) has the known targets only.
expect {
	text = lines(["[tools]", "a = { ref = \"acme/a\", url = \"${foo10}\", note = \"keep\", bin = { x64musl = \"${h1}\", x64glibc = \"${h2}\" } }"])
	put = ToolsToml.put({ path: "talon.toml", text, key: "a", ref: "acme/foo@^1.1.0", url: foo11 })
	both = match put {
		Ok(t) => ToolsToml.put_bin({ path: "talon.toml", text: t, key: "a", bin: [{ target: "x64win", sha256: h3 }] })
		Err(e) => Err(e)
	}
	put == Ok(lines(["[tools]", "a = { ref = \"acme/foo@^1.1.0\", url = \"${foo11}\", note = \"keep\" }"])) and both == Ok(lines(["[tools]", "a = { ref = \"acme/foo@^1.1.0\", url = \"${foo11}\", note = \"keep\", bin = { x64win = \"${h3}\" } }"]))
}

# R-PT18, R-PT19, R-TF8: `put_bin` (a `url` that stays gains values) keeps a `bin` key that is not a target, with its value as written (a string that is no sha256, a number). The known targets come first, in the order of the list, then the unknown keys in the order of the old table. An empty list with an unknown key gives a table with that key. The unknown subkeys of the entry stay. `drop_bin` (a new `url` and no check) removes the whole table.
expect {
	base = lines(["[tools]", "a = { ref = \"acme/a\", url = \"${foo10}\", note = \"keep\", bin = { x64glibc = \"${h2}\", x64musl = \"${h1}\", wasm32 = 7 } }"])
	put = |bin| ToolsToml.put_bin({ path: "talon.toml", text: base, key: "a", bin })
	head = "a = { ref = \"acme/a\", url = \"${foo10}\", note = \"keep\", bin = "
	put([{ target: "x64musl", sha256: h3 }, { target: "x64win", sha256: h2 }]) == Ok(lines(["[tools]", "${head}{ x64musl = \"${h3}\", x64win = \"${h2}\", x64glibc = \"${h2}\", wasm32 = 7 } }"])) and put([]) == Ok(lines(["[tools]", "${head}{ x64glibc = \"${h2}\", wasm32 = 7 } }"])) and ToolsToml.drop_bin({ path: "talon.toml", text: base, key: "a" }) == Ok(lines(["[tools]", "a = { ref = \"acme/a\", url = \"${foo10}\", note = \"keep\" }"]))
}
