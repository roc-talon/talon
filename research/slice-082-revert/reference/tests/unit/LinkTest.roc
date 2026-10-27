import lib.Args
import lib.Clock
import lib.Fail
import lib.Link

LinkTest :: [].{}

# The expected value of each row is the design text or the slice file text, not the code. A wrong row prints with `dbg`.
# Texts and `data` fields that the design does not give are the proposals of docs/slices/024b-roc-link.md (TW24).

plan = |copy, force, name, path| {
	id = if copy "copy-${name}" else "link-${name}"
	Ok({ copy, force, name, id, path })
}

usage = |text| Err(Fail.new(Usage, text))

# R-CM15, R-R12, R-R13, R-LK2, R-FL12: the operands and flags of `roc link`. `link-<name>` for a link (R-R12), `copy-<name>` for `--copy` (R-R13). The name is used as typed. `--force` only with `--copy` (R-FL12 names it for
# `roc link --copy`, question Q1). Each failure is `Usage` (exit 2). The first failing check wins: the count of operands, then `--force`, then the name. A name must be one path part that `roc list` shows (R-LY1): not empty, no `/`, no `\`, no
# white space, and not `.lock` or `.tmp` at the end. `--json`, `--yes` and `--quiet` do not change the plan.
expect {
	read = |words| match Args.parse(words) {
		Ok(args) => Link.read(args)
		Err(_) => Err(Fail.new(Internal, "the test words do not parse"))
	}
	bad_name = |name| usage("${name} is not a valid compiler name: use one word with no space, no / and no \\")
	rows = [
		("R-R12: a link", ["roc", "link", "dev", "../roc/zig-out/bin/roc"], plan(Bool.False, Bool.False, "dev", "../roc/zig-out/bin/roc")),
		("R-R13: a copy", ["roc", "link", "--copy", "fix-1", "../roc/zig-out/bin/roc"], plan(Bool.True, Bool.False, "fix-1", "../roc/zig-out/bin/roc")),
		("R-LK2: a copy with --force, the flags before and after the operands", ["roc", "link", "--force", "--copy", "fix-1", "/r/roc", "--json", "--yes"], plan(Bool.True, Bool.True, "fix-1", "/r/roc")),
		("the name as typed: case and dots stay, a link- prefix is not special", ["roc", "link", "Dev.2", "p"], plan(Bool.False, Bool.False, "Dev.2", "p")),
		("a name with a dash and digits", ["roc", "link", "--copy", "my-fix_2", "p"], plan(Bool.True, Bool.False, "my-fix_2", "p")),
		("no operand", ["roc", "link"], usage("tln roc link needs a name and a path: tln roc link <name> <path>")),
		("one operand", ["roc", "link", "dev"], usage("tln roc link needs a name and a path: tln roc link <name> <path>")),
		("the count is checked before --force", ["roc", "link", "--force"], usage("tln roc link needs a name and a path: tln roc link <name> <path>")),
		("3 operands", ["roc", "link", "a", "b", "c"], usage("tln roc link takes a name and a path, got 3 operands")),
		("--force with no --copy (R-FL12, Q1)", ["roc", "link", "--force", "dev", "p"], usage("flag '--force' is not for 'roc link' without --copy")),
		("--force with no --copy is checked before the name", ["roc", "link", "--force", "a/b", "p"], usage("flag '--force' is not for 'roc link' without --copy")),
		("a name with a space", ["roc", "link", "a b", "p"], bad_name("a b")),
		("a name with a slash", ["roc", "link", "a/b", "p"], bad_name("a/b")),
		("a name with a backslash", ["roc", "link", "--copy", "a\\b", "p"], bad_name("a\\b")),
		("an empty name", ["roc", "link", "", "p"], bad_name("")),
		("a name that ends in .lock (R-LY1: it would not be listed)", ["roc", "link", "x.lock", "p"], bad_name("x.lock")),
		("a name that ends in .tmp", ["roc", "link", "x.tmp", "p"], bad_name("x.tmp")),
		("a name with a tab", ["roc", "link", "a\tb", "p"], bad_name("a\tb")),
	]
	bad = rows.keep_if(|(_, words, want)| read(words) != want).map(|(label, words, want)| (label, want, read(words)))
	dbg bad
	bad == []
}

# R-R12, R-R13, R-LK4: the path of the operand. The caller makes the typed path absolute from the current directory (`Text.resolve`: `.` and `..` removed, no symbolic link resolved) and calls `canonical!` with it, only to check that
# the file exists. A good result gives `full` as it is, also when the canonical path is another one (a symbolic link that a rebuild replaces: the link must follow it). No such file is a usage failure (exit 2), another failure of the
# call is `Environment` (exit 18). The same check serves the link and the copy.
expect {
	got = |result| Link.source({ typed: "../roc/zig-out/bin/roc", full: "/w/roc/zig-out/bin/roc", result }).map_err(|f| (f.kind.code(), f.message))
	link = Link.source({ typed: "roc-src/lnk-roc", full: "/w/roc-src/lnk-roc", result: Ok("/w/roc-src/zig-out/bin/roc") })
	got(Ok("/w/roc/zig-out/bin/roc")) == Ok("/w/roc/zig-out/bin/roc")
		and link == Ok("/w/roc-src/lnk-roc")
			and got(Err(NotFound)) == Err((2, "no such file: ../roc/zig-out/bin/roc"))
				and got(Err(Denied)) == Err((18, "cannot read ../roc/zig-out/bin/roc: permission denied"))
					and got(Err(Other("Is a directory"))) == Err((18, "cannot read ../roc/zig-out/bin/roc: Is a directory"))
}

# R-LK2: a name that exists is an error, and `--force` replaces it for a copy. For a link the error says how to start again. The name is compared as it is: `link-dev` and `copy-dev` are 2 ids. The other tag form of a nightly is no part of this.
expect {
	decide = |id, copy, force, installed| Link.decide({ id, copy, force, installed }).map_err(|f| (f.kind.code(), f.message))
	have = ["copy-fix-1", "link-dev", "nightly-2026-10-14-38a3029"]
	decide("link-new", Bool.False, Bool.False, have) == Ok(Create)
		and decide("copy-new", Bool.True, Bool.True, have) == Ok(Create)
			and decide("copy-fix-1", Bool.True, Bool.True, have) == Ok(Replace)
				and decide("copy-fix-1", Bool.True, Bool.False, have) == Err((2, "copy-fix-1 exists. Use --force to replace it."))
					and decide("link-dev", Bool.False, Bool.False, have) == Err((2, "link-dev exists. Run: tln roc remove link-dev"))
						and decide("copy-dev", Bool.True, Bool.False, have) == Ok(Create)
							and decide("link-fix-1", Bool.False, Bool.False, have) == Ok(Create)
								and decide("link-dev", Bool.False, Bool.False, []) == Ok(Create)
}

# R-LK4, R-LK2, R-TF1, R-TF2: the text of `.talon.json`. A link records the absolute path of the target (`path`), a copy records where it was copied from (`source`). The keys are in this order, with `format` first, one line and a line end.
# `installed_at` is the time of Talon (`Manage.rows` reads it for `roc list`). A text of a path is escaped as JSON.
expect {
	now = Clock.parse_utc("2026-10-22T12:00:00Z") ?? 0
	link = Link.meta({ id: "link-dev", kind: Link, path: "/w/roc-src/zig-out/bin/roc", now })
	copy = Link.meta({ id: "copy-fix-1", kind: Copy, path: "/w/roc-src/zig-out/bin/roc", now })
	quoted = Link.meta({ id: "link-q", kind: Link, path: "/w/a \"b\"/roc", now })
	link == "{\"format\":1,\"id\":\"link-dev\",\"path\":\"/w/roc-src/zig-out/bin/roc\",\"installed_at\":\"2026-10-22T12:00:00Z\"}\n"
		and copy == "{\"format\":1,\"id\":\"copy-fix-1\",\"source\":\"/w/roc-src/zig-out/bin/roc\",\"installed_at\":\"2026-10-22T12:00:00Z\"}\n"
			and quoted == "{\"format\":1,\"id\":\"link-q\",\"path\":\"/w/a \\\"b\\\"/roc\",\"installed_at\":\"2026-10-22T12:00:00Z\"}\n"
}

# R-LK4, R-R5, R-TF1 to R-TF3, R-TF6: the program of a link is the absolute path in its `.talon.json`. The file is read as a Talon file: a `format` above 1 and text that does not parse are `Input` (exit 19), a field that Talon does not
# know is ignored (R-TF2). No file, or a file that cannot be read, is `Environment` (exit 18). A `path` that is missing, is not a text or is not absolute is `Input`. The file of the target is not looked at (a target that was deleted is
# a failure of the start, R-E1).
expect {
	file = "/c/roc/toolchains/link-dev/.talon.json"
	got = |text| Link.target({ id: "link-dev", path: file, text }).map_err(|f| (f.kind.code(), f.message))
	no_path = Err((19, "${file}: the link link-dev has no absolute target path"))
	rows = [
		("the path", got(Ok("{\"format\":1,\"id\":\"link-dev\",\"path\":\"/w/roc-src/zig-out/bin/roc\",\"installed_at\":\"2026-10-21T09:30:00Z\"}\n")), Ok("/w/roc-src/zig-out/bin/roc")),
		("a path with a space and a field that Talon does not know (R-TF2)", got(Ok("{\"format\":1,\"later\":[1,2],\"path\":\"/w x/roc\"}")), Ok("/w x/roc")),
		("the file of an older format 0 is read", got(Ok("{\"format\":0,\"path\":\"/a/roc\"}")), Ok("/a/roc")),
		("no file", got(Err(NotFound)), Err((18, "${file}: the link link-dev has no .talon.json. Run: tln roc remove link-dev, then tln roc link dev <path>."))),
		("no permission", got(Err(Denied)), Err((18, "cannot read ${file}: permission denied"))),
		("another read error", got(Err(Other("Is a directory"))), Err((18, "cannot read ${file}: Is a directory"))),
		("not JSON", got(Ok("link-dev runs /a/roc")), Err((19, "${file}: the content does not parse"))),
		("no format", got(Ok("{\"path\":\"/a/roc\"}")), Err((19, "${file}: the content does not parse"))),
		("a format that is too new (R-TF3)", got(Ok("{\"format\":2,\"path\":\"/a/roc\"}")), Err((19, "${file}: format 2 is newer than this tln (format 1). Run: tln tool update talon"))),
		("no path", got(Ok("{\"format\":1,\"id\":\"link-dev\"}")), no_path),
		("a path that is a number", got(Ok("{\"format\":1,\"path\":5}")), no_path),
		("a path that is null", got(Ok("{\"format\":1,\"path\":null}")), no_path),
		("a path that is not absolute", got(Ok("{\"format\":1,\"path\":\"../roc/zig-out/bin/roc\"}")), no_path),
		("an empty path", got(Ok("{\"format\":1,\"path\":\"\"}")), no_path),
	]
	bad = rows.keep_if(|(_, g, want)| g != want).map(|(label, g, want)| (label, want, g))
	dbg bad
	bad == []
}

# R-OUT2, R-J3, R-J4, R-OUT4: the text and the `data` of the 2 commands. The `data` keys are in this order: `id`, `kind`, `source`, `replaced`. Each stdout line ends with a line end.
expect {
	linked = Link.report({ id: "link-dev", kind: Link, path: "/w/roc-src/zig-out/bin/roc" })
	copied = Link.report({ id: "copy-fix-1", kind: Copy, path: "/w/roc-src/zig-out/bin/roc" })
	link_data = Link.data({ id: "link-dev", kind: Link, path: "/w/roc-src/zig-out/bin/roc", replaced: Bool.False }).render()
	copy_data = Link.data({ id: "copy-fix-1", kind: Copy, path: "/w/roc-src/zig-out/bin/roc", replaced: Bool.True }).render()
	linked == ["linked link-dev -> /w/roc-src/zig-out/bin/roc\n"]
		and copied == ["copied /w/roc-src/zig-out/bin/roc to copy-fix-1\n"]
			and link_data == "{\"id\":\"link-dev\",\"kind\":\"link\",\"source\":\"/w/roc-src/zig-out/bin/roc\",\"replaced\":false}"
				and copy_data == "{\"id\":\"copy-fix-1\",\"kind\":\"copy\",\"source\":\"/w/roc-src/zig-out/bin/roc\",\"replaced\":true}"
}
