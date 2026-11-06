import lib.Fail
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

# R-LY5 R-LY6 R-LY7 R-CR1 (slice 088): the Windows roots. The cache is `%LOCALAPPDATA%\roc`, the config is `%APPDATA%\talon`, the data is `%LOCALAPPDATA%\talon`.
# A Windows path has `\` between its parts, and a `\` at the end of a variable is dropped (as `Setup.bin_dir`, R-LY8). `HOME` is not read on Windows: with no HOME the run does not fail.
# `ROC_CACHE_DIR` gives the build root as on Linux, and the packages root ignores it (R-CR1). Another system (Linux, macOS, or a name that is not known) gives the roots of `from_env`.
# Not tested (the design does not say, the questions of the slice file): `XDG_*` on Windows, a missing `LOCALAPPDATA` or `APPDATA`, an empty value.
expect {
	local = "C:\\Users\\u\\AppData\\Local"
	roaming = "C:\\Users\\u\\AppData\\Roaming"
	win = [("LOCALAPPDATA", local), ("APPDATA", roaming), ("USERPROFILE", "C:\\Users\\u")]
	rows = [
		(
			"Windows, no HOME and no XDG",
			Windows,
			win,
			Ok(("${local}\\roc", "${local}\\roc\\packages", "${local}\\roc", "${roaming}\\talon", "${local}\\talon")),
		),
		(
			"Windows, a `\\` at the end of the variables",
			Windows,
			[("LOCALAPPDATA", "${local}\\"), ("APPDATA", "${roaming}\\")],
			Ok(("${local}\\roc", "${local}\\roc\\packages", "${local}\\roc", "${roaming}\\talon", "${local}\\talon")),
		),
		(
			"Windows, ROC_CACHE_DIR: packages ignore it (R-CR1)",
			Windows,
			win.append(("ROC_CACHE_DIR", "D:\\build")),
			Ok(("${local}\\roc", "${local}\\roc\\packages", "D:\\build", "${roaming}\\talon", "${local}\\talon")),
		),
		(
			"Windows, HOME is set (git bash): the Windows form wins",
			Windows,
			win.append(("HOME", "/home/u")),
			Ok(("${local}\\roc", "${local}\\roc\\packages", "${local}\\roc", "${roaming}\\talon", "${local}\\talon")),
		),
		(
			"Windows, XDG_CACHE_HOME is taken as it is, the join is `\\` (R-LY5, as roc)",
			Windows,
			win.append(("XDG_CACHE_HOME", "D:\\cache")),
			Ok(("D:\\cache\\roc", "D:\\cache\\roc\\packages", "D:\\cache\\roc", "${roaming}\\talon", "${local}\\talon")),
		),
		(
			"Linux with the Windows variables set: the form of from_env",
			Linux,
			win.append(("HOME", "/home/u")),
			Ok(("/home/u/.cache/roc", "/home/u/.cache/roc/packages", "/home/u/.cache/roc", "/home/u/.config/talon", "/home/u/.local/share/talon")),
		),
		(
			"macOS and an unknown system have the form of Linux",
			Macos,
			[("HOME", "/Users/u"), ("XDG_DATA_HOME", "/x/data")],
			Ok(("/Users/u/.cache/roc", "/Users/u/.cache/roc/packages", "/Users/u/.cache/roc", "/Users/u/.config/talon", "/x/data/talon")),
		),
		(
			"an unknown system with no HOME is the failure of from_env",
			Other("plan9"),
			win,
			Err(NoRoots),
		),
	]
	bad = rows.keep_if(|(_, os, env, want)| view(Roots.from_env_on(os, env)) != want).map(|(label, os, env, want)| (label, want, view(Roots.from_env_on(os, env))))
	dbg bad
	bad == []
}

# R-LY5 (slice 088, manager answers Q-W1, Q-W3, Q-W4, cache only): the order of the cache root on Windows is as roc (`getRocCacheDir`): `XDG_CACHE_HOME`, then `LOCALAPPDATA`, then `HOME` (`<HOME>\.cache\roc`), else the failure of kind `Environment` with `LOCALAPPDATA is not set`.
# Only the cache root is checked: the config and data roots with these variables missing are open questions of the slice file.
expect {
	cache = |env| match Roots.from_env_on(Windows, env) {
		Ok(roots) => Ok(roots.cache)
		Err(fail) => Err(Fail.line(fail))
	}
	rows = [
		("XDG_CACHE_HOME first", [("XDG_CACHE_HOME", "D:\\c"), ("LOCALAPPDATA", "C:\\L"), ("HOME", "C:\\h")], Ok("D:\\c\\roc")),
		("LOCALAPPDATA before HOME", [("LOCALAPPDATA", "C:\\L"), ("HOME", "C:\\h")], Ok("C:\\L\\roc")),
		("HOME fallback", [("HOME", "C:\\h")], Ok("C:\\h\\.cache\\roc")),
	]
	bad = rows.keep_if(|(_, env, want)| cache(env) != want).map(|(label, env, want)| (label, want, cache(env)))
	dbg bad
	none = match Roots.from_env_on(Windows, [("PATH", "C:\\bin")]) {
		Ok(_) => Bool.False
		Err(fail) => Fail.line(fail).contains("LOCALAPPDATA is not set")
	}
	bad == [] and none
}

# R-LY10 R-LY5 R-LY6 R-LY7 (slice 088e, Design Q214): on Windows, a root variable that is not absolute counts as not set, as `XDG_CACHE_HOME` on Linux.
# The variables are `XDG_CACHE_HOME`, `LOCALAPPDATA`, `APPDATA` and `HOME`. Absolute on Windows: a drive letter, `:`, and `\` or `/` (any case of the letter), or a UNC prefix `\\server\share`.
# A value that is not absolute is skipped, and the next rule of R-LY5 to R-LY7 applies. The row shows (cache, config, data); `Err` is the failure of `from_env_on`.
# Not tested (questions of the slice file): `ROC_CACHE_DIR` that is not absolute, a UNC prefix with `/`, a value `C:\` with the `\` dropped, `XDG_CONFIG_HOME` and `XDG_DATA_HOME` on Windows.
expect {
	local = "C:\\Users\\u\\AppData\\Local"
	roaming = "C:\\Users\\u\\AppData\\Roaming"
	three = |env| match Roots.from_env_on(Windows, env) {
		Ok(roots) => Ok((roots.cache, roots.config, roots.data))
		Err(fail) => Err(Fail.line(fail))
	}
	ok_all = Ok(("${local}\\roc", "${roaming}\\talon", "${local}\\talon"))
	base = [("LOCALAPPDATA", local), ("APPDATA", roaming)]
	rows = [
		("XDG_CACHE_HOME `D:cache` (drive-relative) is not set", base.append(("XDG_CACHE_HOME", "D:cache")), ok_all),
		("XDG_CACHE_HOME `cache\\x` (relative) is not set", base.append(("XDG_CACHE_HOME", "cache\\x")), ok_all),
		("XDG_CACHE_HOME `/x/cache` (no drive) is not set", base.append(("XDG_CACHE_HOME", "/x/cache")), ok_all),
		("XDG_CACHE_HOME with a lower case drive and `/` is absolute: it is kept", base.append(("XDG_CACHE_HOME", "d:/cache")), Ok(("d:/cache\\roc", "${roaming}\\talon", "${local}\\talon"))),
		(
			"LOCALAPPDATA `x\\y` is not set: HOME gives the cache and the data (R-LY5, R-LY7)",
			[("LOCALAPPDATA", "x\\y"), ("APPDATA", roaming), ("HOME", "C:\\h")],
			Ok(("C:\\h\\.cache\\roc", "${roaming}\\talon", "C:\\h\\.local\\share\\talon")),
		),
		(
			"APPDATA `C:x` is not set: HOME gives the config (R-LY6)",
			[("LOCALAPPDATA", local), ("APPDATA", "C:x"), ("HOME", "C:\\h")],
			Ok(("${local}\\roc", "C:\\h\\.config\\talon", "${local}\\talon")),
		),
		(
			"HOME `/home/u` (git bash, no drive) is not set: LOCALAPPDATA and APPDATA are used",
			[("HOME", "/home/u"), ("LOCALAPPDATA", local), ("APPDATA", roaming)],
			ok_all,
		),
		("HOME `C:h` is not set, and no other variable: the failure", [("HOME", "C:h")], Err("tln: error[environment]: LOCALAPPDATA is not set")),
		(
			"a UNC prefix is absolute",
			[("LOCALAPPDATA", "\\\\srv\\share\\L"), ("APPDATA", "\\\\srv\\share\\R")],
			Ok(("\\\\srv\\share\\L\\roc", "\\\\srv\\share\\R\\talon", "\\\\srv\\share\\L\\talon")),
		),
	]
	bad = rows.keep_if(|(_, env, want)| three(env) != want).map(|(label, env, want)| (label, want, three(env)))
	dbg bad
	# On Linux the rule of `from_env` is unchanged: a value must start with `/`.
	linux = match Roots.from_env_on(Linux, [("HOME", "/home/u"), ("XDG_CACHE_HOME", "D:\\cache")]) {
		Ok(roots) => roots.cache == "/home/u/.cache/roc"
		Err(_) => Bool.False
	}
	bad == [] and linux
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
