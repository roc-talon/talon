app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Temp

main! = |_args| Ok({})

# R-CC1: a temp is `<target>.<16hex>.tmp` in the directory of the target. The 16 hex digits come from a random number
# (TW2: the real Fx draws it).
expect {
	hexes = [
		(Temp.hex(255), "00000000000000ff"),
		(Temp.hex(0), "0000000000000000"),
		(Temp.hex(U64.highest), "ffffffffffffffff"),
		(Temp.hex(0x0123456789abcdef), "0123456789abcdef"),
	]
	names = [
		(Temp.name({ target: "/a/b/main.roc", hex: "0123456789abcdef" }), "/a/b/main.roc.0123456789abcdef.tmp"),
		(Temp.name({ target: "/c/roc/toolchains/n1", hex: "fedcba9876543210" }), "/c/roc/toolchains/n1.fedcba9876543210.tmp"),
	]
	bad = hexes.concat(names).keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-CC2 R-CC4: the lock holder of an item deletes the temps of that item, with no age rule. An entry is a temp of the item
# when its name is `<last segment of the item>.<16hex>.tmp`, a file or a directory. The result is full paths, sorted.
expect {
	e = |name, is_dir| { name, is_dir, mtime: 1000000 }
	projects = [
		e("projects.json.0123456789abcdef.tmp", Bool.False),
		e("projects.json.fedcba9876543210.tmp", Bool.True),
		e("projects.json", Bool.False),
		e("projects.json.lock", Bool.True),
		e("projects.json.bak.tmp", Bool.False),
		e("projects.json.0123456789abcde.tmp", Bool.False),
		e("projects.json.0123456789abcdef0.tmp", Bool.False),
		e("xprojects.json.0123456789abcdef.tmp", Bool.False),
		e("tools.json.0123456789abcdef.tmp", Bool.False),
	]
	toolchains = [
		e("nightly-1.0123456789abcdef.tmp", Bool.True),
		e("nightly-1", Bool.True),
		e("nightly-10.0123456789abcdef.tmp", Bool.True),
	]
	got_projects = Temp.of_item({ item: "/c/roc/talon/projects.json", entries: projects })
	got_toolchains = Temp.of_item({ item: "/c/roc/toolchains/nightly-1", entries: toolchains })
	got_none = Temp.of_item({ item: "/c/roc/talon/projects.json", entries: [] })
	dbg (got_projects, got_toolchains, got_none)
	got_projects == ["/c/roc/talon/projects.json.0123456789abcdef.tmp", "/c/roc/talon/projects.json.fedcba9876543210.tmp"]
		and got_toolchains == ["/c/roc/toolchains/nightly-1.0123456789abcdef.tmp"]
			and got_none == []
}

# R-CC2 R-GC6 R-LY1 R-EV22: `tln cache gc` deletes the temps, the `.trash` directories and the probe copies
# `talon/tmp/<16hex>/` that are older than 1 day. The age is `now - mtime` with the real clock. Exactly 1 day is not old.
# A package, a file of Talon and a lock directory are never chosen. A time in the future is not old (no U64 underflow).
expect {
	now = 2000000
	day = 86400
	e = |path, is_dir, mtime| { path, is_dir, mtime }
	entries = [
		e("/c/roc/packages/h1.0123456789abcdef.tmp", Bool.False, now - day - 1),
		e("/c/roc/packages/h2.0123456789abcdef.tmp", Bool.False, now - day),
		e("/c/roc/toolchains/n1.fedcba9876543210.trash", Bool.True, 0),
		e("/c/roc/talon/tmp/0123456789abcdef", Bool.True, 0),
		e("/c/roc/talon/tmp/fedcba9876543210", Bool.True, now - day),
		e("/c/roc/talon/tmp/0123456789abcdef.txt", Bool.False, 0),
		e("/c/roc/talon/tmp/aaaaaaaaaaaaaaaa", Bool.False, 0),
		e("/c/roc/talon/tmp/short", Bool.True, 0),
		e("/x/tmp/0123456789abcdef", Bool.True, 0),
		e("/c/roc/packages/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA", Bool.True, 0),
		e("/c/roc/talon/projects.json", Bool.False, 0),
		e("/c/roc/talon/projects.json.lock", Bool.True, 0),
		e("/c/roc/talon/projects.json.1123456789abcdef.tmp", Bool.False, now + 500),
		e("/c/roc/talon/x/d1.1123456789abcdef.tmp", Bool.True, 5),
	]
	got = Temp.old({ entries, now })
	dbg got
	got == [
		"/c/roc/packages/h1.0123456789abcdef.tmp",
		"/c/roc/talon/tmp/0123456789abcdef",
		"/c/roc/talon/x/d1.1123456789abcdef.tmp",
		"/c/roc/toolchains/n1.fedcba9876543210.trash",
	]
}
