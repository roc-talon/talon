app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Clock
import lib.Launch
import lib.Roots

main! = |_args| Ok({})

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
	canon = |xdg, build, opted_out| Launch.child_env({ opted_out, xdg, build })
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
