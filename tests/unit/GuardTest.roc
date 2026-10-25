import lib.Fail
import lib.Guard

GuardTest :: [].{}

# R-CC7: the check before a write of project files. Same text: write. Other text with the same spans (an editor changed a
# line outside the header): apply the span edit to the new text. A changed span: a conflict (exit 17, nothing written).
# With many files: each `talon.toml` is written first, then the `.roc` files, each group in the order of the list.
expect {
	file = |path, read, now, spans_read, spans_now| { path, read, now, spans_read, spans_now }
	same = |path| file(path, "a\nb\n", "a\nb\n", ["a"], ["a"])
	moved = |path| file(path, "# x\nheader\nbody\n", "# x\n# new comment\nheader\nbody\nmore\n", ["header"], ["header"])
	changed = |path| file(path, "header\nbody\n", "header2\nbody\n", ["header"], ["header2"])
	gone = |path| file(path, "[dependencies]\nj = 1\n", "other\n", ["[dependencies]\nj = 1\n"], [])
	view = |r| match r {
		Ok(order) => Ok(order)
		Err(f) => Err(Fail.line(f))
	}
	rows = [
		("same text", [same("/p/main.roc")], Ok([{ path: "/p/main.roc", how: Same }])),
		("other text, same span", [moved("/p/main.roc")], Ok([{ path: "/p/main.roc", how: Reapply }])),
		(
			"changed span",
			[changed("/p/main.roc")],
			Err("tln: error[conflict]: /p/main.roc changed while tln ran. Nothing was written. Run the command again."),
		),
		(
			"a span that is gone",
			[gone("/p/talon.toml")],
			Err("tln: error[conflict]: /p/talon.toml changed while tln ran. Nothing was written. Run the command again."),
		),
		("no file", [], Ok([])),
		(
			"order: each talon.toml first, then the others, each group in list order",
			[same("/p/main.roc"), same("/p/talon.toml"), moved("/p/lib/main.roc"), same("/p/lib/talon.toml")],
			Ok([
				{ path: "/p/talon.toml", how: Same },
				{ path: "/p/lib/talon.toml", how: Same },
				{ path: "/p/main.roc", how: Same },
				{ path: "/p/lib/main.roc", how: Reapply },
			]),
		),
		(
			"one conflict stops all writes, and the message names each conflict in list order",
			[changed("/p/main.roc"), same("/p/lib/main.roc"), gone("/p/talon.toml")],
			Err("tln: error[conflict]: /p/main.roc, /p/talon.toml changed while tln ran. Nothing was written. Run the command again."),
		),
		(
			"a name that only ends like talon.toml is not a talon.toml",
			[same("/p/x.roc"), same("/p/my-talon.toml")],
			Ok([{ path: "/p/x.roc", how: Same }, { path: "/p/my-talon.toml", how: Same }]),
		),
	]
	bad = rows.keep_if(|(_, files, want)| view(Guard.check_all(files)) != want).map(|(label, files, want)| (label, want, view(Guard.check_all(files))))
	dbg bad
	bad == []
}
