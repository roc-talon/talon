import lib.Members

MembersTest :: [].{}

# R-PD3: one segment of a `members` pattern. `*` matches any run of characters (also none) in one name.
# Other characters are literal (a `.` is not "any character"). Question Q3: the design has no glob syntax.
expect {
	rows = [
		("*.roc", "hello.roc", Bool.True),
		("*.roc", "hello.roc.bak", Bool.False),
		("*.roc", ".roc", Bool.True),
		("main.roc", "main.roc", Bool.True),
		("main.roc", "Main.roc", Bool.False),
		("a*c", "abbc", Bool.True),
		("a*c", "ac", Bool.True),
		("a*c", "abcd", Bool.False),
		("a*c", "xac", Bool.False),
		("a*c", "xabbc", Bool.False),
		("*", "x", Bool.True),
		("a*b*c", "aXbYc", Bool.True),
		("*x*", "abc", Bool.False),
		("a.c", "abc", Bool.False),
		("apps", "apps", Bool.True),
		("apps", "apps2", Bool.False),
	]
	bad = rows.keep_if(|(p, n, want)| Members.matches(p, n) != want)
	dbg bad
	bad == []
}

# R-PD3 R-PD4: the expansion of `members` is a step function. The command lists the directories that `Need` names and calls
# again, until `Done`. A pattern with n segments needs the directories of its levels 0 to n - 1.
expect {
	file = |name| { name, is_dir: Bool.False }
	sub = |name| { name, is_dir: Bool.True }
	patterns = ["apps/*/main.roc", "examples/*.roc"]
	root_listing = { dir: "/r", entries: [sub("apps"), sub("examples"), sub("tools"), file("main.roc"), file("talon.toml")] }
	apps_listing = { dir: "/r/apps", entries: [sub("a"), sub("b"), file("c"), file("README.md")] }
	examples_listing = { dir: "/r/examples", entries: [file("hello.roc"), file("other.roc"), file("notes.txt"), sub("x.roc"), file("hello.roc.bak")] }
	a_listing = { dir: "/r/apps/a", entries: [file("main.roc"), file("talon.toml")] }
	b_listing = { dir: "/r/apps/b", entries: [file("lib.roc"), sub("src"), sub("main.roc")] }
	all2 = [root_listing, apps_listing, examples_listing]
	all3 = [root_listing, apps_listing, examples_listing, a_listing, b_listing]
	members = ["/r/apps/a/main.roc", "/r/examples/hello.roc", "/r/examples/other.roc"]
	step = |ps, listed| Members.step({ root: "/r", patterns: ps, listed })
	steps = [
		("nothing listed", step(patterns, []), Need(["/r"])),
		("root listed", step(patterns, [root_listing]), Need(["/r/apps", "/r/examples"])),
		("2 levels: only the longer pattern needs more", step(patterns, all2), Need(["/r/apps/a", "/r/apps/b"])),
		("all listed: files only, sorted", step(patterns, all3), Done(members)),
		("the order of the listings does not matter", step(patterns, [b_listing, a_listing, examples_listing, apps_listing, root_listing]), Done(members)),
		("no matching directory", step(patterns, [{ dir: "/r", entries: [file("main.roc"), file("apps")] }]), Done([])),
		("two patterns for one file: no repeat", step(["apps/*/main.roc", "apps/a/main.roc"], [root_listing, apps_listing, a_listing, b_listing]), Done(["/r/apps/a/main.roc"])),
	]
	bad = steps.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
