import lib.Item
import lib.Lock
import lib.Roots
import lib.Setting

RootsTest :: [].{}

view = |r| match r {
	Ok(roots) => Ok((roots.cache, roots.pkgs, roots.build, roots.config, roots.data))
	Err(_) => Err(NoRoots)
}

# R-LY5 R-LY6 R-LY7 R-EV13 R-CR1: the roots come from XDG_CACHE_HOME, XDG_CONFIG_HOME, XDG_DATA_HOME, ROC_CACHE_DIR and HOME.
# The cache root is `<cache home>/roc`. The packages root ignores ROC_CACHE_DIR. The build caches honor it.
expect {
	rows = [
		(
			"HOME only",
			[("HOME", "/home/u")],
			Ok(("/home/u/.cache/roc", "/home/u/.cache/roc/packages", "/home/u/.cache/roc", "/home/u/.config/talon", "/home/u/.local/share/talon")),
		),
		(
			"the three XDG variables",
			[("HOME", "/home/u"), ("XDG_CACHE_HOME", "/x/cache"), ("XDG_CONFIG_HOME", "/x/cfg"), ("XDG_DATA_HOME", "/x/data")],
			Ok(("/x/cache/roc", "/x/cache/roc/packages", "/x/cache/roc", "/x/cfg/talon", "/x/data/talon")),
		),
		(
			"ROC_CACHE_DIR with XDG_CACHE_HOME: packages ignore it (R-CR1)",
			[("HOME", "/home/u"), ("XDG_CACHE_HOME", "/x/cache"), ("ROC_CACHE_DIR", "/y/build")],
			Ok(("/x/cache/roc", "/x/cache/roc/packages", "/y/build", "/home/u/.config/talon", "/home/u/.local/share/talon")),
		),
		(
			"ROC_CACHE_DIR with no XDG_CACHE_HOME",
			[("HOME", "/home/u"), ("ROC_CACHE_DIR", "/y/build")],
			Ok(("/home/u/.cache/roc", "/home/u/.cache/roc/packages", "/y/build", "/home/u/.config/talon", "/home/u/.local/share/talon")),
		),
		(
			"other variables and the order of the list do not matter",
			[("PATH", "/bin"), ("XDG_DATA_HOME", "/x/data"), ("CI", "true"), ("HOME", "/home/u")],
			Ok(("/home/u/.cache/roc", "/home/u/.cache/roc/packages", "/home/u/.cache/roc", "/home/u/.config/talon", "/x/data/talon")),
		),
	]
	bad = rows.keep_if(|(_, env, want)| view(Roots.from_env(env)) != want).map(|(label, env, want)| (label, want, view(Roots.from_env(env))))
	dbg bad
	bad == []
}

# R-LY1 R-LY2 R-LY3 R-CR1 R-CC3: the path of each item of the layout, and the lock directory of an item (`<item>.lock`).
# `Package` uses the packages root and `Compat` uses the build root. All other items of the cache are under the cache root.
expect {
	roots = Roots.{ cache: "/c/roc", pkgs: "/c/roc/packages", build: "/b", config: "/cfg/talon", data: "/d/talon" }
	items = [
		(Item.Package("h1"), "/c/roc/packages/h1"),
		(Item.PackageDeps("h1"), "/c/roc/packages/h1.deps.json"),
		(Item.Compat("c1"), "/b/compat-c1"),
		(Item.Toolchain("nightly-2026-10-13-91fa0c2"), "/c/roc/toolchains/nightly-2026-10-13-91fa0c2"),
		(Item.ToolchainRoc("n1"), "/c/roc/toolchains/n1/roc"),
		(Item.ToolchainMeta("n1"), "/c/roc/toolchains/n1/.talon.json"),
		(Item.ToolchainLastUse("n1"), "/c/roc/toolchains/n1/.last-use"),
		(Item.Zig("0.15.1"), "/c/roc/toolchains/zig-0.15.1"),
		(Item.Index, "/c/roc/talon/index"),
		(Item.CompatDb, "/c/roc/talon/compat.db"),
		(Item.ProjectsJson, "/c/roc/talon/projects.json"),
		(Item.PathRocJson, "/c/roc/talon/path-roc.json"),
		(Item.TalonTmp("0123456789abcdef"), "/c/roc/talon/tmp/0123456789abcdef"),
		(Item.Gc, "/c/roc/talon/gc"),
		(Item.XBuild("d1"), "/c/roc/talon/x/d1"),
		(Item.Config, "/cfg/talon/config.toml"),
		(Item.Bin, "/d/talon/bin"),
		(Item.ToolsJson, "/d/talon/tools.json"),
		(Item.ShareJson, "/d/talon/share.json"),
	]
	bad_items = items.keep_if(|(item, want)| Roots.item(roots, item) != want).map(|(item, want)| (want, Roots.item(roots, item)))
	dbg bad_items
	locks = [
		(Item.ProjectsJson, "/c/roc/talon/projects.json.lock"),
		(Item.Toolchain("n1"), "/c/roc/toolchains/n1.lock"),
		(Item.Zig("0.15.1"), "/c/roc/toolchains/zig-0.15.1.lock"),
		(Item.Gc, "/c/roc/talon/gc.lock"),
		(Item.Config, "/cfg/talon/config.toml.lock"),
		(Item.ToolsJson, "/d/talon/tools.json.lock"),
		(Item.ShareJson, "/d/talon/share.json.lock"),
	]
	bad_locks = locks.keep_if(|(item, want)| Lock.dir(Roots.item(roots, item)) != want).map(|(item, want)| (want, Lock.dir(Roots.item(roots, item))))
	dbg bad_locks
	bad_items == [] and bad_locks == []
}

# R-LY4 R-EV1: a setting is the first value that is set: the flag, then the environment variable, then the project
# `talon.toml`, then `config.toml`.
expect {
	set = |v| Ok(v)
	unset = Err(Unset)
	rows = [
		(Setting.pick({ flag: set("f"), env: set("e"), project: set("p"), user: set("u") }), Ok("f")),
		(Setting.pick({ flag: unset, env: set("e"), project: set("p"), user: set("u") }), Ok("e")),
		(Setting.pick({ flag: unset, env: unset, project: set("p"), user: set("u") }), Ok("p")),
		(Setting.pick({ flag: unset, env: unset, project: unset, user: set("u") }), Ok("u")),
		(Setting.pick({ flag: set("f"), env: unset, project: unset, user: set("u") }), Ok("f")),
		(Setting.pick({ flag: unset, env: unset, project: unset, user: unset }), Err(Unset)),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}
