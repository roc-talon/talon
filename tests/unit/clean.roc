app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Args
import lib.Clean
import lib.Fail
import lib.Roots

main! = |_args| Ok({})

# The expected value of each row is the design text or the slice file text (docs/slices/029-cache-clean.md), not the code. A wrong row prints with `dbg`.
# Texts and `data` fields that the design does not give are the proposals of the slice file (TW24).

# R-CM17 R-GC12 R-GC13 R-GC14: `tln cache clean` takes no operand (exit 2) and has the flags `--all` and `--dry-run`. The other global flags change nothing here.
expect {
	read = |words| match Args.parse(words) {
		Ok(args) => Clean.read(args)
		Err(_) => Err(Fail.new(Internal, "the test words do not parse"))
	}
	rows = [
		(["cache", "clean"], Ok({ all: Bool.False, dry_run: Bool.False })),
		(["cache", "clean", "--all"], Ok({ all: Bool.True, dry_run: Bool.False })),
		(["cache", "clean", "--dry-run"], Ok({ all: Bool.False, dry_run: Bool.True })),
		(["cache", "clean", "--dry-run", "--all"], Ok({ all: Bool.True, dry_run: Bool.True })),
		(["cache", "clean", "--json", "--yes", "--quiet", "--all"], Ok({ all: Bool.True, dry_run: Bool.False })),
		(["cache", "clean", "packages"], Err(Fail.new(Usage, "tln cache clean takes no operand, got 1"))),
		(["cache", "clean", "--all", "a", "b"], Err(Fail.new(Usage, "tln cache clean takes no operand, got 2"))),
	]
	bad = rows.keep_if(|(words, want)| read(words) != want).map(|(words, want)| (words, want, read(words)))
	dbg bad
	bad == []
}

# R-GC12 R-GC13 R-GC14: the paths that `tree_info!` is asked for. With no `--all`: `talon/index` and `talon/x`. With `--all`: the packages dir, and each dir of the build root that is named `compat-`, `nightly-` or `debug-` and one more character, sorted.
# No age rule and no `owned` list: the compat dir of an installed compiler is in the list too. No toolchain, no tool, no `talon/compat.db`, no `talon/projects.json` is in any list. When `ROC_CACHE_DIR` is not set, the build root is the cache root:
# its `packages`, `toolchains` and `talon` dirs are no build-cache dir.
expect {
	from = |env| match Roots.from_env(env) {
		Ok(r) => r
		Err(_) => crash "the test roots do not parse"
	}
	split = from([("HOME", "/h"), ("XDG_CACHE_HOME", "/c"), ("ROC_CACHE_DIR", "/b")])
	same = from([("HOME", "/h"), ("XDG_CACHE_HOME", "/c")])
	e = |path, is_dir| { path, is_dir, mtime: 0 }
	builds = [
		e("/b/nightly-2026-01-01-abc1234", Bool.True),
		e("/b/compat-bbbbbbb", Bool.True),
		e("/b/debug-1234567", Bool.True),
		e("/b/compat-aaaaaaa", Bool.True),
		e("/b/compat-", Bool.True),
		e("/b/compat-file", Bool.False),
		e("/b/compat", Bool.True),
		e("/b/other-old", Bool.True),
		e("/b/toolchains", Bool.True),
	]
	root_listing = [
		e("/c/roc/packages", Bool.True),
		e("/c/roc/toolchains", Bool.True),
		e("/c/roc/talon", Bool.True),
		e("/c/roc/compat-ten", Bool.True),
		e("/c/roc/compat-file", Bool.False),
	]
	paths = |facts| Clean.asks(facts).map(|ask| ask.path)
	both = Clean.asks({ roots: split, all: Bool.True, builds })
	dbg (paths({ roots: split, all: Bool.False, builds }), paths({ roots: split, all: Bool.True, builds }), paths({ roots: same, all: Bool.True, builds: root_listing }))
	paths({ roots: split, all: Bool.False, builds }) == ["/c/roc/talon/index", "/c/roc/talon/x"]
		and paths({ roots: split, all: Bool.False, builds: [] }) == ["/c/roc/talon/index", "/c/roc/talon/x"]
			and paths({ roots: split, all: Bool.True, builds })
				== [
					"/c/roc/talon/index",
					"/c/roc/talon/x",
					"/c/roc/packages",
					"/b/compat-aaaaaaa",
					"/b/compat-bbbbbbb",
					"/b/debug-1234567",
					"/b/nightly-2026-01-01-abc1234",
				]
				and both.all(|ask| ask.item == ask.path)
					and paths({ roots: same, all: Bool.True, builds: root_listing }) == ["/c/roc/talon/index", "/c/roc/talon/x", "/c/roc/packages", "/c/roc/compat-ten"]
						and paths({ roots: split, all: Bool.True, builds: [] }) == ["/c/roc/talon/index", "/c/roc/talon/x", "/c/roc/packages"]
}

# R-GC14: which asked paths are items. A path that is missing (`NotFound`) is no item: nothing to remove. A path that cannot be read (`Denied`, `Other`) is an item with no size (question Q5). `sizes` has a row for each `Ok` row, the `item` is the path.
expect {
	row = |path, info| { item: path, path, info }
	measured = [
		row("/c/roc/talon/index", Ok({ newest: 5, size: 1500000 })),
		row("/c/roc/talon/x", Err(NotFound)),
		row("/c/roc/packages", Err(Denied)),
		row("/b/compat-aaaaaaa", Ok({ newest: 0, size: 0 })),
		row("/b/compat-bbbbbbb", Err(Other("io"))),
	]
	got = Clean.found(measured)
	dbg got
	got
		== {
			paths: ["/c/roc/talon/index", "/c/roc/packages", "/b/compat-aaaaaaa", "/b/compat-bbbbbbb"],
			sizes: [{ item: "/c/roc/talon/index", bytes: 1500000 }, { item: "/b/compat-aaaaaaa", bytes: 0 }],
		}
		and Clean.found([row("/c/roc/talon/index", Err(NotFound)), row("/c/roc/talon/x", Err(NotFound))]) == { paths: [], sizes: [] }
			and Clean.found([]) == { paths: [], sizes: [] }
}

# R-GC14 R-OUT2 (proposal): the report and the bytes. The size is `Toolchain.size_text`. An item with no size has no suffix. The total line is there when one item has a size at least. A dry run has `would` and the last line. A declined run says that nothing was removed.
# `freed` is the sum of the sizes (an item with no size counts 0) for a run and a dry run, and 0 for `Nothing` and `Declined`.
expect {
	paths = ["/c/roc/talon/index", "/c/roc/talon/x", "/c/roc/packages", "/b/compat-aaaaaaa"]
	sizes = [
		{ item: "/c/roc/talon/index", bytes: 1500000 },
		{ item: "/c/roc/talon/x", bytes: 999 },
		{ item: "/b/compat-aaaaaaa", bytes: 3100000000 },
	]
	run = { all: Bool.True, outcome: Removed, paths, sizes }
	dry = { ..run, outcome: DryRun }
	declined = { ..run, outcome: Declined }
	blind = { all: Bool.False, outcome: Removed, paths: ["/c/roc/talon/index"], sizes: [] }
	blind_dry = { ..blind, outcome: DryRun }
	nothing = { all: Bool.False, outcome: Nothing, paths: [], sizes: [] }
	dbg (Clean.report(run), Clean.report(dry), Clean.report(blind), Clean.report(blind_dry), Clean.report(declined), Clean.report(nothing))
	Clean.report(run)
		== [
			"removed /c/roc/talon/index (1.5 MB)\n",
			"removed /c/roc/talon/x (999 B)\n",
			"removed /c/roc/packages\n",
			"removed /b/compat-aaaaaaa (3.1 GB)\n",
			"freed 3.1 GB\n",
		]
		and Clean.report(dry)
			== [
				"would remove /c/roc/talon/index (1.5 MB)\n",
				"would remove /c/roc/talon/x (999 B)\n",
				"would remove /c/roc/packages\n",
				"would remove /b/compat-aaaaaaa (3.1 GB)\n",
				"would free 3.1 GB\n",
				"dry run: nothing was removed\n",
			]
			and Clean.report(blind) == ["removed /c/roc/talon/index\n"]
				and Clean.report(blind_dry) == ["would remove /c/roc/talon/index\n", "dry run: nothing was removed\n"]
					and Clean.report(declined) == ["nothing was removed\n"]
						and Clean.report(nothing) == ["nothing to remove\n"]
							and Clean.freed(run) == 3101500999
								and Clean.freed(dry) == 3101500999
									and Clean.freed(blind) == 0
										and Clean.freed(declined) == 0
											and Clean.freed(nothing) == 0
}

# R-GC14 R-J3 R-OUT4 (proposal): the `data` of `--json`. The keys are `dry_run`, `all`, `removed`, `items`, `freed`. An item with no size has `"bytes":null`. A declined run lists the items and has `removed` false and `freed` 0.
expect {
	paths = ["/c/roc/talon/index", "/c/roc/packages"]
	sizes = [{ item: "/c/roc/talon/index", bytes: 1500000 }]
	run = { all: Bool.True, outcome: Removed, paths, sizes }
	dbg (Clean.data(run).render(), Clean.data({ ..run, outcome: DryRun }).render(), Clean.data({ ..run, outcome: Declined }).render())
	Clean.data(run).render()
		== "{\"dry_run\":false,\"all\":true,\"removed\":true,\"items\":[{\"path\":\"/c/roc/talon/index\",\"bytes\":1500000},{\"path\":\"/c/roc/packages\",\"bytes\":null}],\"freed\":1500000}"
		and Clean.data({ ..run, outcome: DryRun }).render()
			== "{\"dry_run\":true,\"all\":true,\"removed\":false,\"items\":[{\"path\":\"/c/roc/talon/index\",\"bytes\":1500000},{\"path\":\"/c/roc/packages\",\"bytes\":null}],\"freed\":1500000}"
			and Clean.data({ ..run, outcome: Declined }).render()
				== "{\"dry_run\":false,\"all\":true,\"removed\":false,\"items\":[{\"path\":\"/c/roc/talon/index\",\"bytes\":1500000},{\"path\":\"/c/roc/packages\",\"bytes\":null}],\"freed\":0}"
				and Clean.data({ all: Bool.False, outcome: Nothing, paths: [], sizes: [] }).render()
					== "{\"dry_run\":false,\"all\":false,\"removed\":false,\"items\":[],\"freed\":0}"
}

# R-GC14 (question Q4): the result of the one `delete!` call. `NotFound` is not a failure (the item went since the measure). The first other error is a failure of kind Environment (exit 18) that names the path and the error. A result list that is all `Ok` is `Ok`.
expect {
	paths = ["/c/roc/talon/index", "/c/roc/talon/x", "/c/roc/packages"]
	check = |results| Clean.check({ paths, results })
	rows = [
		(check([Ok({}), Ok({}), Ok({})]), Ok({})),
		(check([Err(NotFound), Ok({}), Err(NotFound)]), Ok({})),
		(check([Ok({}), Err(Denied), Err(Other("busy"))]), Err(Fail.new(Environment, "cannot remove /c/roc/talon/x: Denied"))),
		(check([Err(Other("busy")), Err(Denied), Ok({})]), Err(Fail.new(Environment, "cannot remove /c/roc/talon/index: Other(\"busy\")"))),
		(Clean.check({ paths: [], results: [] }), Ok({})),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}
