import lib.TlnGate

TlngatepureTest :: [].{}

# Slice 236 (docs/slices/236-tln-version-gate.md), R-TF10, Design Q607, Q610 (G-C240, user decision 2026-11-08: the gate compares major.minor.patch only).
# `TlnGate.check` is a new name (a proposal): until the code agent adds it, this file does not compile (red on purpose).
# `TlnGate.check : { range : Str, version : Str } -> Try({}, [BadRange, Outside])`

# R-TF10: a pre-release tln counts as its major.minor.patch. `0.4.0-rc.1` is `0.4.0`.
expect {
	rows = [
		("0.4.0-rc.1", ">=0.4.0", Ok({})),
		("0.4.0-rc.1", ">=0.4.1", Err(Outside)),
		("0.4.0-rc.1", "^0.4", Ok({})),
		("0.4.0-rc.1", "<0.4.0", Err(Outside)),
		("0.4.0-rc.1", "=0.4.0", Ok({})),
		("0.4.0-rc.1+build.5", ">=0.4.0", Ok({})),
	]
	got = rows.map(|(version, range, _)| TlnGate.check({ range, version }))
	want = rows.map(|(_, _, w)| w)
	dbg got
	got == want
}

# R-TF10: a release version, the edges of a range, and a range that does not parse.
expect {
	rows = [
		("0.4.0", ">=0.4.0", Ok({})),
		("0.4.0", ">=0.4.1", Err(Outside)),
		("1.2.3", "*", Ok({})),
		("1.2.3", ">=1.0.0, <1.2.3", Err(Outside)),
		("1.2.3", "banana", Err(BadRange)),
		("1.2.3", "", Err(BadRange)),
		("0.0.1", "^0.0.1", Ok({})),
	]
	got = rows.map(|(version, range, _)| TlnGate.check({ range, version }))
	want = rows.map(|(_, _, w)| w)
	dbg got
	got == want
}
