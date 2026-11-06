import lib.Clock
import lib.Launch
import lib.Roots

LaunchTest :: [].{}

a1 = "nightly-2026-10-09-258ab27"

a2 = "nightly-2026-10-14-38a3029"

a3 = "nightly-2026-10-14-0abcdef"

# R-PX2 R-SO10 R-PX6 R-PX7 R-EV17 R-CC9 (slice 023c, moved from `tests/unit/proxy.roc` of slice 023): how a compiler is started, for the proxy and for each probe. The program: an installed id runs from `toolchains/` also when the `roc` on `PATH`
# has the same id, and a compiler that is only on `PATH` runs by the file that `PATH` gave, never by the name `roc` (the first `roc` on `PATH` can be the launcher). The cache variables are canonical paths with no `..` (R-PX6: "Probes use
# the same rule"), then `TALON_IN_PROXY=1` (R-EV17, question Q1 of slice 023c: a probe sets it too). The text of `.last-use` is the time of Talon.
expect {
	roots = Roots.{ cache: "/h/.cache/roc", pkgs: "/h/.cache/roc/packages", build: "/h/.cache/roc", config: "/h/.config/talon", data: "/h/.local/share/talon" }
	found = |id| Ok({ id, path: "/usr/local/bin/roc" })
	prog = |id, installed, path| Launch.program({ roots, id, installed, path })
	canon = |xdg, build, opted_out| Launch.child_env({ opted_out, windows: Bool.False, xdg, build })
	win = |xdg, build| Launch.child_env({ opted_out: Bool.False, windows: Bool.True, xdg, build })
	now = Clock.parse_utc("2026-10-22T12:00:00Z") ?? 0
	program_rows = [
		("installed", prog(a2, [a1, a2], Err(NoCompiler)), "/h/.cache/roc/toolchains/${a2}/roc"),
		("installed, and the same id on PATH: the managed copy", prog(a2, [a2], found(a2)), "/h/.cache/roc/toolchains/${a2}/roc"),
		("installed, and another id on PATH", prog(a1, [a1], found(a2)), "/h/.cache/roc/toolchains/${a1}/roc"),
		("only on PATH: the file as PATH wrote it", prog(a3, [a2], found(a3)), "/usr/local/bin/roc"),
		("only on PATH, nothing installed", prog(a3, [], found(a3)), "/usr/local/bin/roc"),
		("a link build", prog("link-dev", ["link-dev"], Err(NoCompiler)), "/h/.cache/roc/toolchains/link-dev/roc"),
	]
	env_rows = [
		(
			"canonical paths",
			canon({ path: "/h/.cache", canonical: Ok("/real/cache") }, { path: "/h/.cache/roc", canonical: Ok("/real/cache/roc") }, Bool.False),
			[("XDG_CACHE_HOME", "/real/cache"), ("ROC_CACHE_DIR", "/real/cache/roc"), ("TALON_IN_PROXY", "1")],
		),
		(
			"a `..` that cannot be made canonical: the parts are removed",
			canon({ path: "/h/x/../.cache", canonical: Err(Failed) }, { path: "/h/./b//c/../d", canonical: Err(Failed) }, Bool.False),
			[("XDG_CACHE_HOME", "/h/.cache"), ("ROC_CACHE_DIR", "/h/b/d"), ("TALON_IN_PROXY", "1")],
		),
		(
			"a path that is clean stays",
			canon({ path: "/h/.cache", canonical: Err(Failed) }, { path: "/h/.cache/roc", canonical: Err(Failed) }, Bool.False),
			[("XDG_CACHE_HOME", "/h/.cache"), ("ROC_CACHE_DIR", "/h/.cache/roc"), ("TALON_IN_PROXY", "1")],
		),
		(
			"Windows, a dir that does not exist: the text cleanup with `\\` (Q212)",
			win({ path: "C:/Users/u/./x/../AppData/Local", canonical: Err(Failed) }, { path: "C:/Users/u/AppData/Local\\roc", canonical: Err(Failed) }),
			[("XDG_CACHE_HOME", "C:\\Users\\u\\AppData\\Local"), ("ROC_CACHE_DIR", "C:\\Users\\u\\AppData\\Local\\roc"), ("TALON_IN_PROXY", "1")],
		),
		(
			"Windows, a dir that exists: the canonical path as it is",
			win({ path: "C:/a/../b", canonical: Ok("C:\\b") }, { path: "C:/a/../b\\roc", canonical: Ok("C:\\b\\roc") }),
			[("XDG_CACHE_HOME", "C:\\b"), ("ROC_CACHE_DIR", "C:\\b\\roc"), ("TALON_IN_PROXY", "1")],
		),
		(
			"opted out: only TALON_IN_PROXY (R-PX7, Q1 of slice 023)",
			canon({ path: "/h/.cache", canonical: Ok("/real/cache") }, { path: "/h/.cache/roc", canonical: Ok("/real/cache/roc") }, Bool.True),
			[("TALON_IN_PROXY", "1")],
		),
	]
	text_rows = [
		("last use", Launch.last_use(now), "2026-10-22T12:00:00Z\n"),
		("last use, the epoch", Launch.last_use(0), "1970-01-01T00:00:00Z\n"),
	]
	bad_programs = program_rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	bad_env = env_rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	bad_text = text_rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad_programs
	dbg bad_env
	dbg bad_text
	bad_programs == [] and bad_env == [] and bad_text == []
}

# R-PX6 R-LY5 (slice 088c): the path of `XDG_CACHE_HOME` for roc is the directory of the cache root. On Windows the cut is at the last `\` or `/` (the root is `<dir>\roc`, and a `<dir>` from `XDG_CACHE_HOME` can have `/`). On Linux and macOS only `/` cuts: a `\` is a letter of a name.
expect {
	rows = [
		("Windows, LOCALAPPDATA", Launch.xdg_dir({ windows: Bool.True, cache: "C:\\Users\\u\\AppData\\Local\\roc" }), "C:\\Users\\u\\AppData\\Local"),
		("Windows, the fake host: `/` before the last `\\`", Launch.xdg_dir({ windows: Bool.True, cache: "/w/home/AppData/Local\\roc" }), "/w/home/AppData/Local"),
		("Windows, XDG_CACHE_HOME with `/`", Launch.xdg_dir({ windows: Bool.True, cache: "D:/c\\roc" }), "D:/c"),
		("Windows, a `/` after the last `\\`", Launch.xdg_dir({ windows: Bool.True, cache: "D:\\c/roc" }), "D:\\c"),
		("Windows, no separator", Launch.xdg_dir({ windows: Bool.True, cache: "roc" }), ""),
		("Linux", Launch.xdg_dir({ windows: Bool.False, cache: "/h/.cache/roc" }), "/h/.cache"),
		("Linux, a `\\` in a name stays", Launch.xdg_dir({ windows: Bool.False, cache: "/h/a\\b/roc" }), "/h/a\\b"),
		("Linux, no `/`", Launch.xdg_dir({ windows: Bool.False, cache: "a\\roc" }), ""),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(name, _, _)| name)
	dbg bad
	bad == []
}

# R-PX6 (slice 088d, Design Q212): the text-only cleanup of a path that does not exist. The separator of the system (on Windows each `/` becomes `\`, on Linux a `\` is a letter of a name), each `.` part removed, each `..` part removes the part
# before it, no symlink resolved, the root and the drive stay. The rows for a `..` at the root, empty parts, UNC and a relative path are in the next `expect` (slice 088e).
expect {
	c = |windows, path| Launch.clean_text({ windows, path })
	rows = [
		("Linux, `.` and `..`", c(Bool.False, "/h/./a/../b"), "/h/b"),
		("Linux, a clean path stays", c(Bool.False, "/h/.cache/roc"), "/h/.cache/roc"),
		("Linux, `..` back to the root", c(Bool.False, "/h/a/../.."), "/"),
		("Linux, `\\` is a letter: it stays, and is not a separator", c(Bool.False, "/h/a\\b/../c\\d/./e"), "/h/c\\d/e"),
		("Windows, drive, `..` (backslash)", c(Bool.True, "C:\\a\\..\\b"), "C:\\b"),
		("Windows, drive, `.`", c(Bool.True, "C:\\a\\.\\b"), "C:\\a\\b"),
		("Windows, a clean path stays", c(Bool.True, "C:\\Users\\u\\AppData\\Local\\roc"), "C:\\Users\\u\\AppData\\Local\\roc"),
		("Windows, mixed separators", c(Bool.True, "C:/Users\\u/./x\\..\\AppData/Local\\roc"), "C:\\Users\\u\\AppData\\Local\\roc"),
		("Windows, `/` only", c(Bool.True, "D:/c/d/../e"), "D:\\c\\e"),
		("Windows, lower case drive", c(Bool.True, "d:/x/../y"), "d:\\y"),
		("Windows, no drive (the fake host): the root `\\`", c(Bool.True, "/w/home/../x/AppData/Local\\roc"), "\\w\\x\\AppData\\Local\\roc"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(name, got, want)| (name, want, got))
	dbg bad
	bad == []
}

# R-PX6 (slice 088e, Design Q214, G-C34): the rest of the text cleanup. A `..` at the root is dropped. Empty parts and a separator at the end are removed.
# The Windows root is `C:\` or the UNC prefix `\\server\share`, and a `..` never removes a part of the root. A path that is not absolute is kept after the `.` and `..` steps, with no root added.
# Not tested (questions of the slice file): a UNC root with no part after it, a `..` that starts a relative path.
expect {
	c = |windows, path| Launch.clean_text({ windows, path })
	rows = [
		("Linux, `..` at the root is dropped", c(Bool.False, "/../a"), "/a"),
		("Linux, `..` only", c(Bool.False, "/.."), "/"),
		("Linux, empty parts and a trailing `/`", c(Bool.False, "/h//a/./b/"), "/h/a/b"),
		("Linux, the root alone", c(Bool.False, "/"), "/"),
		("Linux, a relative path has no root added", c(Bool.False, "a/./b/../c"), "a/c"),
		("Linux, `\\` names are not UNC: a relative name", c(Bool.False, "\\\\srv\\sh\\x"), "\\\\srv\\sh\\x"),
		("Windows, drive, `..` at the root is dropped", c(Bool.True, "C:\\..\\a"), "C:\\a"),
		("Windows, drive, `..` back to the root keeps `C:\\`", c(Bool.True, "C:\\a\\..\\.."), "C:\\"),
		("Windows, drive root alone", c(Bool.True, "C:\\"), "C:\\"),
		("Windows, drive, empty parts and a trailing `\\`", c(Bool.True, "C:\\a\\\\b\\"), "C:\\a\\b"),
		("Windows, UNC keeps both `\\`", c(Bool.True, "\\\\srv\\sh\\a\\.\\b"), "\\\\srv\\sh\\a\\b"),
		("Windows, UNC, `..` never removes the share or the server", c(Bool.True, "\\\\srv\\sh\\..\\..\\x"), "\\\\srv\\sh\\x"),
		("Windows, UNC, `..` removes a part after the share", c(Bool.True, "\\\\srv\\sh\\a\\b\\..\\c\\"), "\\\\srv\\sh\\a\\c"),
		("Windows, UNC with `/`", c(Bool.True, "//srv/sh/a/../b"), "\\\\srv\\sh\\b"),
		("Windows, relative: no root added", c(Bool.True, "x\\y\\..\\z"), "x\\z"),
		("Windows, relative with `/` and `.`", c(Bool.True, "./x/./y"), "x\\y"),
		("Windows, drive-relative `C:x` is not a drive root", c(Bool.True, "C:x\\.\\y"), "C:x\\y"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(name, got, want)| (name, want, got))
	dbg bad
	bad == []
}

# R-PX6 (slice 088f, Design Q216, G-C36): the Windows details of the cleanup. A UNC root with no part after it has a `\` at the end (`\\srv\sh\`), as the drive root `C:\`; `//srv/sh` is the same UNC prefix. A `..` at the start of a relative path stays (it has no root to stop at): `..\a` on Windows, and `../a` on Linux and macOS, where the `/` stays. The absolute check of `C:\` is a rule of `Roots` (the row in `RootsTest`).
expect {
	c = |windows, path| Launch.clean_text({ windows, path })
	rows = [
		("Windows, a bare UNC root has a `\\` at the end", c(Bool.True, "\\\\srv\\sh"), "\\\\srv\\sh\\"),
		("Windows, a bare UNC root with a `\\` at the end", c(Bool.True, "\\\\srv\\sh\\"), "\\\\srv\\sh\\"),
		("Windows, UNC root, `..` only", c(Bool.True, "\\\\srv\\sh\\.."), "\\\\srv\\sh\\"),
		("Windows, `//srv/sh` is UNC", c(Bool.True, "//srv/sh"), "\\\\srv\\sh\\"),
		("Windows, `//srv/sh/a` is UNC", c(Bool.True, "//srv/sh/a"), "\\\\srv\\sh\\a"),
		("Windows, a leading `..` stays (backslash)", c(Bool.True, "..\\a"), "..\\a"),
		("Windows, a leading `..` stays (slash)", c(Bool.True, "../a"), "..\\a"),
		("Windows, `..` past the start of a relative path stays", c(Bool.True, "a\\..\\..\\b"), "..\\b"),
		("Linux, a leading `..` stays", c(Bool.False, "../a"), "../a"),
		("Linux, `..` past the start of a relative path stays", c(Bool.False, "a/../../b"), "../b"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(name, got, want)| (name, want, got))
	dbg bad
	bad == []
}
