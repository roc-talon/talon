import lib.ManageUpdate

RocUpdateHintTest :: [].{}

# Slice 262b (R-RU5, R-RU3, R-SO2 to R-SO6, Q262-6, Design Q642, UX3): the project hint of `tln roc update`.
# A header pin that is not the new id: line A, uses `Pin`. A pin that is the new id: no line, uses `Pin`.
# No pin and no source of priority 2, 4 or 5, and the default is now the new id (`Set`, `Moved`, `Same`): line B, uses `New`.
# No pin and another source, or the default stays (`Stay`, `NoDefault`): no line, uses `Other`.
expect {
	new = "nightly-2026-10-18-5349569"
	old = "nightly-2026-10-09-258ab27"
	file = "/p/main.roc"
	a = Ok("note: the project /p/main.roc pins ${old}, so it stays on that compiler. To move it with a check, run: tln upgrade roc\n")
	b = Ok("note: the project /p/main.roc has no roc: pin, so it uses ${new} now, with no check. To check it and pin it, run: tln roc use ${new}\n")
	hint = |pin, other, default| ManageUpdate.project_hint({ file, pin, other, default, id: new })
	rows = [
		("an older pin: line A", hint(Ok(old), Bool.False, Moved(old)), { uses: Pin, line: a }),
		("an older pin, the default stays: still line A", hint(Ok(old), Bool.False, Stay("link-dev")), { uses: Pin, line: a }),
		("the pin is the new id: no line", hint(Ok(new), Bool.False, Same), { uses: Pin, line: Err(None) }),
		("no pin, the default moved to the new id: line B", hint(Err(NoPin), Bool.False, Moved(old)), { uses: New, line: b }),
		("no pin, the default was set to the new id: line B", hint(Err(NoPin), Bool.False, Set), { uses: New, line: b }),
		("no pin, the default is the new id already: line B", hint(Err(NoPin), Bool.False, Same), { uses: New, line: b }),
		("no pin, another source selects: no line", hint(Err(NoPin), Bool.True, Same), { uses: Other, line: Err(None) }),
		("no pin, the default is a local build that stays: no line", hint(Err(NoPin), Bool.False, Stay("link-dev")), { uses: Other, line: Err(None) }),
		("no pin, no default (a user-channel build): no line", hint(Err(NoPin), Bool.False, NoDefault), { uses: Other, line: Err(None) }),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
