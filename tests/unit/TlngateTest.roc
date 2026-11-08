import lib.Help
import lib.Intent

TlngateTest :: [].{}

# Slice 236 (docs/slices/236-tln-version-gate.md), R-TF10 R-TF4 R-TF8 R-EC19 R-WS5, Design Q607, Q609, Q610 (G-C240).
# The tests name no new function: they call `Intent.read` (the one reader of `talon.toml`) and read the version from `Help.version`.
# The range text of a test is chosen so that it holds for each tln version below 999.0.0.

hint = "A newer tln may know this value. Update tln: tln tool update talon"

lines = |list| "${Str.join_with(list, "\n")}\n"

tln_file = |range| lines(["[toolchain]", "tln = ${range}"])

# The result of a read as a plain value: the failure as (exit code, message), or the warnings.
shown = |role, text| match Intent.read({ path: "/p/talon.toml", text, role }) {
	Ok(done) => Ok(done.warnings)
	Err(f) => Err((f.kind.code(), f.message))
}

needs = |range| "/p/talon.toml:2: this project needs tln ${range}, this is tln ${Help.version}. Run: tln tool update talon"

# R-TF10 R-TF4: a range that admits this tln gives no failure and no warning. The key is a known key of `[toolchain]` (it was an unknown key before this slice).
expect {
	rows = [
		("any", "\"*\""),
		("at least", "\">=0.0.1\""),
		("two bounds", "\">=0.0.1, <999.0.0\""),
		("upper bound", "\"<999.0.0\""),
	]
	got = rows.map(|(label, range)| (label, shown(Standalone, tln_file(range))))
	want = rows.map(|(label, _)| (label, Ok([])))
	dbg got
	got == want
}

# R-TF10: a range that does not admit this tln: exit 19 and the text of the design. The text has the path and the line of the key (a proposal, TW24). Standalone and Root file alike.
expect {
	rows = [
		(">=999.0.0", Standalone),
		(">=999.0.0", Root),
		("<0.0.1", Standalone),
		("^999.1", Root),
		("=999.0.0", Root),
	]
	got = rows.map(|(range, role)| shown(role, tln_file("\"${range}\"")))
	want = rows.map(|(range, _)| Err((19, needs(range))))
	dbg got
	got == want
}

# R-TF10 R-TF4 R-TF8 R-EC19 (Q609): a range that does not parse is exit 19, as each bad range of `talon.toml`, with the hint line. The message names the key.
expect {
	rows = ["banana", "", "^", "1.2.3.4", "latest"]
	got = rows.map(|range| shown(Standalone, tln_file("\"${range}\"")))
	want = rows.map(|range| Err((19, "/p/talon.toml:2: toolchain.tln: '${range}' is not a version range\n${hint}")))
	dbg got
	got == want
}

# R-TF10 R-TF4 R-TF8: a value that is not a string is a wrong type: exit 19 with the hint line.
expect {
	shown(Standalone, tln_file("5")) == Err((19, "/p/talon.toml:2: toolchain.tln: must be a string\n${hint}"))
}

# R-TF10: no key, no check. Also with a `[toolchain]` table that has other keys, and with no `[toolchain]` table.
expect {
	a = shown(Standalone, lines(["[toolchain]", "roc = \"*\""]))
	b = shown(Root, lines(["[toolchain]", "nightly = true"]))
	c = shown(Standalone, lines(["[dependencies]", "json = \"^2\""]))
	d = shown(Standalone, "")
	dbg [a, b, c, d]
	[a, b, c, d] == [Ok([]), Ok([]), Ok([]), Ok([])]
}

# R-TF10: the key lives next to `roc` and `nightly`. The read of those keys does not change.
expect {
	text = lines(["[toolchain]", "roc = \"*\"", "nightly = false", "tln = \">=0.0.1\""])
	match Intent.read({ path: "/p/talon.toml", text, role: Root }) {
		Ok(done) => done.warnings == [] and done.intent.toolchain.roc == Ok(Any) and done.intent.toolchain.nightly == Ok(Bool.False)
		Err(_) => Bool.False
	}
}

# R-TF10 ("checks it first"): when the range fails and the file has another fault, the gate message is the one that the person sees. A newer tln can make that other fault valid.
expect {
	strategy = lines(["[toolchain]", "tln = \">=999.0.0\"", "", "[resolution]", "strategy = \"middle\""])
	dep = lines(["[dependencies]", "json = \"banana\"", "", "[toolchain]", "tln = \">=999.0.0\""])
	table = lines(["[toolchain]", "tln = \">=999.0.0\"", "", "[run]", "after = []"])
	a = shown(Root, strategy)
	b = shown(Standalone, dep)
	c = shown(Root, table)
	dbg [a, b, c]
	a == Err((19, needs(">=999.0.0"))) and b == Err((19, "/p/talon.toml:5: this project needs tln >=999.0.0, this is tln ${Help.version}. Run: tln tool update talon")) and c == Err((19, needs(">=999.0.0")))
}

# R-TF10 R-WS5: only the root file counts. A member file may not have a `[toolchain]` table at all, so the failure is the one of R-WS5 (no word of the gate). This holds with a range that this tln is outside of, and with one that it is inside of.
expect {
	out = shown(Member, tln_file("\">=999.0.0\""))
	inside = shown(Member, tln_file("\">=0.0.1\""))
	want = Err((19, "/p/talon.toml:1: the table [toolchain] is not allowed in a workspace member file (it has only dependencies, overrides, patch and build)"))
	dbg [out, inside]
	out == want and inside == want
}

# R-TF10 ("Talon never writes it"): the edits of `talon.toml` keep the key as it is, and add it to no file.
expect {
	text = lines(["[toolchain]", "tln = \">=0.0.1\"  # the gate", "", "[dependencies]", "json = \"^2.1\""])
	apply = |t, writes| match Intent.apply({ path: "/p/talon.toml", text: t, writes }) {
		Ok(done) => Ok(done)
		Err(e) => Err(e.line())
	}
	edited = apply(text, [{ key: "json", value: "^3" }, { key: "http", value: "^1" }])
	want = Ok(lines(["[toolchain]", "tln = \">=0.0.1\"  # the gate", "", "[dependencies]", "json = \"^3\"", "http = \"^1\""]))
	plain = apply(lines(["[dependencies]", "json = \"^2.1\""]), [{ key: "http", value: "^1" }])
	new_file = apply("", [{ key: "json", value: "^2" }])
	renamed = Intent.rename({ path: "/p/talon.toml", text, renames: [{ from: "json", to: "js" }] }).map_err(|e| e.line())
	removed = Intent.remove({ path: "/p/talon.toml", text, keys: [{ table: Dependencies, key: "json" }] }).map_err(|e| e.line())
	dbg [edited, plain, new_file, renamed, removed]
	no_gate = |r| match r {
		Ok(t) => !t.contains("tln")
		Err(_) => Bool.False
	}
	keeps = |r| match r {
		Ok(t) => t.contains("tln = \">=0.0.1\"  # the gate")
		Err(_) => Bool.False
	}
	edited == want and no_gate(plain) and no_gate(new_file) and keeps(renamed) and keeps(removed)
}
