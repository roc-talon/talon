import lib.Args
import lib.Fail
import lib.Gc
import lib.Roots
import lib.Temp

GcTest :: [].{}

# The expected value of each row is the design text or the slice file text (docs/slices/028-cache-gc.md), not the code. A wrong row prints with `dbg`.
# Texts and `data` fields that the design does not give are the proposals of the slice file (TW24).

now : U64
now = 100000000

day : U64
day = 86400

age : U64
age = 2592000

# A header with a `roc:` entry (the pin), or none.
header : Try(Str, [NoPin]) -> Str
header = |pin| {
	roc = match pin {
		Ok(id) => "\n\troc: \"${id}\","
		Err(NoPin) => ""
	}
	"app [main!] {\n\tpf: platform \"https://github.com/acme/pf/releases/download/0.1.0/895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw.tar.zst\",${roc}\n}\n\nmain! = |_args| Ok({})\n"
}

# R-GC11 R-CM17: `tln cache gc` takes no operand (exit 2), and has the one flag `--dry-run`. R-GC9: the age is `gc-age`, else 30 days.
expect {
	read = |words| match Args.parse(words) {
		Ok(args) => Gc.read(args)
		Err(_) => Err(Fail.new(Internal, "the test words do not parse"))
	}
	rows = [
		(["cache", "gc"], Ok({ dry_run: Bool.False })),
		(["cache", "gc", "--dry-run"], Ok({ dry_run: Bool.True })),
		(["cache", "gc", "--json", "--dry-run", "--quiet"], Ok({ dry_run: Bool.True })),
		(["cache", "gc", "nightly-2026-10-09-258ab27"], Err(Fail.new(Usage, "tln cache gc takes no operand, got 1"))),
		(["cache", "gc", "--dry-run", "a", "b"], Err(Fail.new(Usage, "tln cache gc takes no operand, got 2"))),
	]
	bad = rows.keep_if(|(words, want)| read(words) != want).map(|(words, want)| (words, want, read(words)))
	dbg bad
	ages = [(Err(Unset), 2592000), (Ok(604800), 604800), (Ok(0), 0)]
	bad_ages = ages.keep_if(|(set, want)| Gc.age(set) != want)
	dbg bad_ages
	bad == [] and bad_ages == []
}

# R-PD12, R-PD13: the known projects that protect something. An entry goes when its file is missing, has no header (a text, a bad header), or was last used more than the GC age ago. Exactly the age stays. A time in the future stays.
# A file that cannot be read (`Denied`) is not judged: the entry stays and pins nothing. `gone` is sorted.
expect {
	entry = |path, last_use| { path, last_use }
	entries = [
		entry("/p/a/main.roc", now - 100),
		entry("/p/b/main.roc", now - age),
		entry("/p/c/main.roc", now - age - 1),
		entry("/p/d/main.roc", now - 100),
		entry("/p/e/main.roc", now - 100),
		entry("/p/f/main.roc", now - 100),
		entry("/p/g/main.roc", now + 500),
		entry("/p/h/main.roc", now - 100),
	]
	reads = [
		Ok(header(Ok("nightly-2026-10-09-258ab27"))),
		Ok(header(Err(NoPin))),
		Ok(header(Err(NoPin))),
		Err(NotFound),
		Ok("just some text\n"),
		Err(Denied),
		Ok(header(Err(NoPin))),
		Ok("app [main!] {\n\tpf: platform"),
	]
	got = Gc.projects({ entries, reads, now, age })
	dbg got
	got.live.map(|p| p.path) == ["/p/a/main.roc", "/p/b/main.roc", "/p/f/main.roc", "/p/g/main.roc"]
		and got.live.map(|p| p.text == Err(Denied)) == [Bool.False, Bool.False, Bool.True, Bool.False]
			and got.gone == ["/p/c/main.roc", "/p/d/main.roc", "/p/e/main.roc", "/p/h/main.roc"]
}

# R-GC5, R-CC10, R-EV22, R-GC9 (D17, the answer of the manager to Q1): the verdict for each toolchain. The first row that fits wins: a `link-*` or `copy-*` entry stays (only `tln roc rm` removes it), the default stays, no known time stays,
# a toolchain used in the last day stays (exactly 1 day stays, a time in the future stays: the floor of R-CC10), a toolchain that a live known project pins stays whatever its age, a toolchain used in the GC age stays (exactly the age stays).
# All other toolchains go: a nightly, a release, a `git-*` build (it follows the rule of a nightly, R-GC5, and no header pins it, R-R4).
# The used time is `.last-use`, else `installed_at`. A pin in the other tag form counts (`Pin.same_id`). A project that is not in `projects` (it is gone, R-PD13) pins nothing.
expect {
	row = |id, kind, installed_at, last_use, is_default| { id, kind, installed_at, last_use, is_default }
	old = Ok(now - 40 * day)
	pa = { path: "/p/a/main.roc", text: Ok(header(Ok("nightly-2026-10-02-bbbbbbb"))) }
	pb = { path: "/p/b/main.roc", text: Ok(header(Ok("nightly-2026-October-03-ccccccc"))) }
	pd = { path: "/p/d/main.roc", text: Err(Denied) }
	rows = [
		row("nightly-2026-08-01-aaaaaaa", Nightly, Err(Unknown), old, Bool.False),
		row("nightly-2026-10-02-bbbbbbb", Nightly, Err(Unknown), Ok(now - 10 * day), Bool.False),
		row("nightly-2026-10-03-ccccccc", Nightly, Err(Unknown), old, Bool.False),
		row("nightly-2026-09-10-ddddddd", Nightly, Err(Unknown), Ok(now - 10 * day), Bool.False),
		row("nightly-2026-10-14-38a3029", Nightly, Err(Unknown), old, Bool.True),
		row("nightly-2026-08-20-fffffff", Nightly, Err(Unknown), Ok(now - 3600), Bool.False),
		row("nightly-2026-08-21-1111111", Nightly, Err(Unknown), Ok(now - day), Bool.False),
		row("nightly-2026-08-22-2222222", Nightly, Err(Unknown), Ok(now - age), Bool.False),
		row("nightly-2026-08-23-3333333", Nightly, Err(Unknown), Ok(now - age - 1), Bool.False),
		row("nightly-2026-08-24-9999999", Nightly, Err(Unknown), Ok(now + 5000), Bool.False),
		row("link-dev", Link, Err(Unknown), old, Bool.False),
		row("copy-fix-1", Copy, Ok(now - 90 * day), old, Bool.False),
		row("git-dd03c09e", Git, Err(Unknown), Ok(now - 5 * day), Bool.False),
		row("git-0badc0de", Git, Err(Unknown), old, Bool.False),
		row("nightly-2026-09-01-4444444", Nightly, Ok(now - 40 * day), Err(Unknown), Bool.False),
		row("nightly-2026-10-21-5555555", Nightly, Ok(now - 3600), Err(Unknown), Bool.False),
		row("nightly-2026-06-01-6666666", Nightly, Err(Unknown), Err(Unknown), Bool.False),
		row("nightly-2026-10-21-7777777", Nightly, Ok(now - 40 * day), Ok(now - 3600), Bool.False),
		row("nightly-2026-06-02-8888888", Nightly, Err(Unknown), Err(Unknown), Bool.True),
		row("0.0.5", Release, Err(Unknown), old, Bool.False),
	]
	got = Gc.toolchains({ rows, projects: [pa, pb, pd], now, age }).map(|c| (c.id, c.verdict))
	want = [
		("nightly-2026-08-01-aaaaaaa", Remove),
		("nightly-2026-10-02-bbbbbbb", Keep(Pinned)),
		("nightly-2026-10-03-ccccccc", Keep(Pinned)),
		("nightly-2026-09-10-ddddddd", Keep(Used)),
		("nightly-2026-10-14-38a3029", Keep(Default)),
		("nightly-2026-08-20-fffffff", Keep(LastDay)),
		("nightly-2026-08-21-1111111", Keep(LastDay)),
		("nightly-2026-08-22-2222222", Keep(Used)),
		("nightly-2026-08-23-3333333", Remove),
		("nightly-2026-08-24-9999999", Keep(LastDay)),
		("link-dev", Keep(Hand)),
		("copy-fix-1", Keep(Hand)),
		("git-dd03c09e", Keep(Used)),
		("git-0badc0de", Remove),
		("nightly-2026-09-01-4444444", Remove),
		("nightly-2026-10-21-5555555", Keep(LastDay)),
		("nightly-2026-06-01-6666666", Keep(NoTime)),
		("nightly-2026-10-21-7777777", Keep(LastDay)),
		("nightly-2026-06-02-8888888", Keep(Default)),
		("0.0.5", Remove),
	]
	bad = got.map2(want, |g, w| (g, w)).keep_if(|(g, w)| g != w)
	dbg bad
	# A short age (60 s): the last day is the floor. Exactly 1 day and 1 hour stay, 1 s more goes. A pinned toolchain stays at any age. A project that is gone pins nothing.
	short_rows = [
		row("nightly-2026-08-01-aaaaaaa", Nightly, Err(Unknown), Ok(now - 3600), Bool.False),
		row("nightly-2026-08-02-bbbbbbb", Nightly, Err(Unknown), Ok(now - day), Bool.False),
		row("nightly-2026-08-03-ccccccc", Nightly, Err(Unknown), Ok(now - day - 1), Bool.False),
		row("nightly-2026-10-02-bbbbbbb", Nightly, Err(Unknown), Ok(now - day - 1), Bool.False),
		row("nightly-2026-08-04-ddddddd", Nightly, Err(Unknown), Ok(now - 30), Bool.False),
	]
	short = Gc.toolchains({ rows: short_rows, projects: [pa], now, age: 60 }).map(|c| c.verdict)
	unpinned = Gc.toolchains({ rows: [row("nightly-2026-10-02-bbbbbbb", Nightly, Err(Unknown), old, Bool.False)], projects: [], now, age }).map(|c| c.verdict)
	no_rows = Gc.toolchains({ rows: [], projects: [pa], now, age })
	dbg (short, unpinned)
	bad == [] and short == [Keep(LastDay), Keep(LastDay), Remove, Keep(Pinned), Keep(LastDay)] and unpinned == [Remove] and no_rows == []
}

# R-CC2, R-GC6, R-LY1: the dirs that GC lists, and the entries of their listing with full paths. A dir that gave an error has no entries. With `Temp.old` and the real time: a temp, a `.trash` dir, a stale lock dir, a probe copy
# `talon/tmp/<16hex>` and the registry `talon/tmp/<16hex>.locks` that are older than 1 day go. A younger one stays. A package, a compiler dir, `projects.json` and a lock dir stay.
expect {
	roots = match Roots.from_env([("HOME", "/h"), ("XDG_CACHE_HOME", "/c")]) {
		Ok(r) => r
		Err(_) => crash "the test roots do not parse"
	}
	dirs = Gc.scan_dirs(roots)
	e = |name, is_dir, mtime| { name, is_dir, mtime }
	young = now - 3600
	listed = [
		Ok([
			e("nightly-2026-10-09-258ab27", Bool.True, 0),
			e("nightly-2026-10-09-258ab27.0123456789abcdef.trash", Bool.True, 5),
			e("nightly-2026-10-11-1a2b3c4.fedcba9876543210.tmp", Bool.True, 5),
			e("nightly-2026-10-12-2664a27.1123456789abcdef.trash", Bool.True, young),
			e("nightly-2026-10-14-38a3029.lock", Bool.True, 0),
			e("nightly-2026-10-14-38a3029.lock.2123456789abcdef.stale", Bool.True, 7),
		]),
		Ok([e("h1.0123456789abcdef.tmp", Bool.False, 9), e("CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA", Bool.True, 0)]),
		Ok([e("projects.json", Bool.False, 0), e("projects.json.3123456789abcdef.tmp", Bool.False, 11), e("gc.lock", Bool.True, 0)]),
		Ok([e("4123456789abcdef", Bool.True, 3), e("5123456789abcdef", Bool.True, young), e("6123456789abcdef.locks", Bool.False, 4), e("7123456789abcdef.locks", Bool.False, young)]),
		Err(NotFound),
		Err(Denied),
	]
	entries = Gc.entries({ dirs, listed })
	stale = Temp.old({ entries, now })
	dbg (dirs, stale)
	dirs == ["/c/roc/toolchains", "/c/roc/packages", "/c/roc/talon", "/c/roc/talon/tmp", "/c/roc/talon/index", "/c/roc/talon/x"]
		and entries.len() == 15
			and entries.map(|x| x.path).first() == Ok("/c/roc/toolchains/nightly-2026-10-09-258ab27")
				and stale
					== [
						"/c/roc/packages/h1.0123456789abcdef.tmp",
						"/c/roc/talon/projects.json.3123456789abcdef.tmp",
						"/c/roc/talon/tmp/4123456789abcdef",
						"/c/roc/talon/tmp/6123456789abcdef.locks",
						"/c/roc/toolchains/nightly-2026-10-09-258ab27.0123456789abcdef.trash",
						"/c/roc/toolchains/nightly-2026-10-11-1a2b3c4.fedcba9876543210.tmp",
						"/c/roc/toolchains/nightly-2026-10-14-38a3029.lock.2123456789abcdef.stale",
					]
}

# R-OUT2, R-GC11, R-CC10 (proposal): the text of the run, in the order toolchains, skipped, compat dirs, stale paths, project entries. A dry run says `would remove` and ends with a line. Nothing to do: one line.
# Another GC that runs: one line, and nothing else.
expect {
	empty = { dry_run: Bool.False, ran: Bool.True, toolchains: [], skipped: [], compat: [], stale: [], builds: [], pkgs: [], projects: [], sizes: [] }
	full = {
		dry_run: Bool.False,
		ran: Bool.True,
		toolchains: ["nightly-2026-08-01-aaaaaaa", "git-0badc0de"],
		skipped: ["nightly-2026-05-01-6666666"],
		compat: ["/c/roc/compat-aaaaaaa"],
		stale: ["/c/roc/talon/tmp/4123456789abcdef", "/c/roc/toolchains/n1.0123456789abcdef.trash"],
		builds: [],
		pkgs: [],
		projects: ["/p/old/main.roc"],
		sizes: [],
	}
	busy = { dry_run: Bool.False, ran: Bool.False, toolchains: [], skipped: [], compat: [], stale: [], builds: [], pkgs: [], projects: [], sizes: [] }
	dry_busy = { ..busy, dry_run: Bool.True, ran: Bool.True }
	dry_full = { ..full, dry_run: Bool.True, skipped: [] }
	Gc.report(busy) == ["another tln cache gc runs\n"]
		and Gc.report(empty) == ["nothing to remove\n"]
			and Gc.report(dry_busy) == ["nothing to remove\n", "dry run: nothing was removed\n"]
				and Gc.report(full)
					== [
						"removed toolchain nightly-2026-08-01-aaaaaaa\n",
						"removed toolchain git-0badc0de\n",
						"skipped toolchain nightly-2026-05-01-6666666: an install holds it\n",
						"removed /c/roc/compat-aaaaaaa\n",
						"removed /c/roc/talon/tmp/4123456789abcdef\n",
						"removed /c/roc/toolchains/n1.0123456789abcdef.trash\n",
						"removed project /p/old/main.roc\n",
					]
					and Gc.report(dry_full)
						== [
							"would remove toolchain nightly-2026-08-01-aaaaaaa\n",
							"would remove toolchain git-0badc0de\n",
							"would remove /c/roc/compat-aaaaaaa\n",
							"would remove /c/roc/talon/tmp/4123456789abcdef\n",
							"would remove /c/roc/toolchains/n1.0123456789abcdef.trash\n",
							"would remove project /p/old/main.roc\n",
							"dry run: nothing was removed\n",
						]
}

# R-J3, R-J4, R-OUT4 (proposal, slice 028b): the `data` of `cache gc --json`. The keys are always the same, in this order (the new keys `builds`, `packages`, `sizes` and `freed`).
# `sizes` has the removed items that have a size, in the order of the lines of the report (toolchains, compat, stale, builds, packages), each once. `freed` is the total.
expect {
	full = {
		dry_run: Bool.False,
		ran: Bool.True,
		toolchains: ["nightly-2026-08-01-aaaaaaa"],
		skipped: ["nightly-2026-05-01-6666666"],
		compat: ["/c/roc/compat-aaaaaaa"],
		stale: ["/c/roc/talon/tmp/4123456789abcdef"],
		builds: ["/c/roc/nightly-2025-01-01-abc1234"],
		pkgs: ["/c/roc/packages/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA"],
		projects: ["/p/old/main.roc"],
		sizes: [{ item: "nightly-2026-08-01-aaaaaaa", bytes: 1500000 }, { item: "/c/roc/nightly-2025-01-01-abc1234", bytes: 7 }, { item: "/c/roc/talon/tmp/4123456789abcdef", bytes: 999 }],
	}
	busy = { dry_run: Bool.False, ran: Bool.False, toolchains: [], skipped: [], compat: [], stale: [], builds: [], pkgs: [], projects: [], sizes: [] }
	dry = { ..busy, dry_run: Bool.True, ran: Bool.True }
	dbg (Gc.data(full).render(), Gc.data(busy).render(), Gc.data(dry).render())
	Gc.data(full).render()
		== "{\"dry_run\":false,\"ran\":true,\"toolchains\":[\"nightly-2026-08-01-aaaaaaa\"],\"skipped\":[\"nightly-2026-05-01-6666666\"],\"compat\":[\"/c/roc/compat-aaaaaaa\"],\"stale\":[\"/c/roc/talon/tmp/4123456789abcdef\"],\"builds\":[\"/c/roc/nightly-2025-01-01-abc1234\"],\"packages\":[\"/c/roc/packages/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA\"],\"projects\":[\"/p/old/main.roc\"],\"sizes\":[{\"item\":\"nightly-2026-08-01-aaaaaaa\",\"bytes\":1500000},{\"item\":\"/c/roc/talon/tmp/4123456789abcdef\",\"bytes\":999},{\"item\":\"/c/roc/nightly-2025-01-01-abc1234\",\"bytes\":7}],\"freed\":1501006}"
		and Gc.data(busy).render()
			== "{\"dry_run\":false,\"ran\":false,\"toolchains\":[],\"skipped\":[],\"compat\":[],\"stale\":[],\"builds\":[],\"packages\":[],\"projects\":[],\"sizes\":[],\"freed\":0}"
			and Gc.data(dry).render()
				== "{\"dry_run\":true,\"ran\":true,\"toolchains\":[],\"skipped\":[],\"compat\":[],\"stale\":[],\"builds\":[],\"packages\":[],\"projects\":[],\"sizes\":[],\"freed\":0}"
}

# R-GC4 (slice 028b): the hashes that the live projects use, found by a walk over the header files in the cache. `protected` is a step: `Need` names the files to read, `Done` has the sorted hashes.
# The walk follows every entry (not only the winning version), reads a path entry of a project and of a path file, ignores a path value in a release header, names a `Foreign` URL nothing, and keeps the hash of a file that cannot be read (its URL still names it).
# A project with no text (`Denied`) or a text that is not a header uses nothing. A hash that 2 projects name is asked once. A cycle ends.
expect {
	base = "https://github.com/acme"
	pf = "${base}/pf/releases/download/0.1.0/895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw.tar.zst"
	core = "${base}/core/releases/download/1.0.0/8bp2yxDtY2ayou722hzyv51Ts1yBaFshmVGtLXpkDy8r.tar.zst"
	text = "${base}/text/releases/download/1.0.0/4DQvwn8UDgjnLQbitjpB7euqpnQKzr4amMFM6oThgRyN.tar.zst"
	text2 = "${base}/text/releases/download/1.1.0/HEG5xNs69thgVmqan8u7odZNyn1r8hiuGuYjNo7emYHm.tar.zst"
	lex = "${base}/lex/releases/download/1.0.0/ETHqKvPfSpgiJzvkfaLumTGq3KhTvan7meq82W7wz73L.tar.zst"
	rows = |deps| Str.join_with(deps.map(|(alias, value)| "\t${alias}: \"${value}\",\n"), "")
	proj = |deps| "app [main!] {\n\tpf: platform \"${pf}\",\n${rows(deps)}}\n\nmain! = |_args| Ok({})\n"
	pkg = |deps| if deps.is_empty() "package [Lib] {}\n" else "package [Lib] {\n${rows(deps)}}\n"
	p1 = { path: "/p/one/main.roc", text: Ok(proj([("core", core), ("util", "../lib/main.roc"), ("odd", "https://example.com/x/abc.tar.zst")])) }
	p2 = { path: "/p/two/main.roc", text: Ok(proj([("core", core)])) }
	p3 = { path: "/p/three/main.roc", text: Err(Denied) }
	p4 = { path: "/p/four/main.roc", text: Ok("just some text\n") }
	projects = [p1, p2, p3, p4]
	step0 = Gc.protected({ projects, nodes: [] })
	level1 = [
		{ id: pf, read: Ok(pkg([("t", text), ("plug", "../up.roc")])) },
		{ id: core, read: Err(NotFound) },
		{ id: "/p/lib/main.roc", read: Ok(pkg([("lex", lex), ("local", "other.roc")])) },
	]
	step1 = Gc.protected({ projects, nodes: level1 })
	level2 = level1.concat([
		{ id: text, read: Ok(pkg([("again", text2), ("back", pf)])) },
		{ id: lex, read: Ok(pkg([])) },
		{ id: "/p/lib/other.roc", read: Err(Denied) },
	])
	step2 = Gc.protected({ projects, nodes: level2 })
	level3 = level2.append({ id: text2, read: Ok(pkg([])) })
	step3 = Gc.protected({ projects, nodes: level3 })
	none = Gc.protected({ projects: [p3, p4], nodes: [] })
	nobody = Gc.protected({ projects: [], nodes: [] })
	dbg (step0, step1, step2, step3)
	step0 == Need([pf, core, "/p/lib/main.roc"])
		and step1 == Need([text, lex, "/p/lib/other.roc"])
			and step2 == Need([text2])
				and step3
					== Done([
						"4DQvwn8UDgjnLQbitjpB7euqpnQKzr4amMFM6oThgRyN",
						"895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw",
						"8bp2yxDtY2ayou722hzyv51Ts1yBaFshmVGtLXpkDy8r",
						"ETHqKvPfSpgiJzvkfaLumTGq3KhTvan7meq82W7wz73L",
						"HEG5xNs69thgVmqan8u7odZNyn1r8hiuGuYjNo7emYHm",
					])
					and none == Done([])
						and nobody == Done([])
}

# R-GC2, R-GC3 (second sentence), R-GC4, R-GC1, R-GC11 (slice 028b): the dirs that the age rule can remove, the one list for `tree_info!`, the dirs that expire, and the sizes.
# `candidates`: a package dir that no live project uses (a name with no `.`: not `<hash>.deps.json`, not a temp, not a file), and a build-cache dir `compat-`, `nightly-` or `debug-` (not a file, not `compat-` alone, not the compat dir of a toolchain that goes: it goes with it).
# The compat dir of a toolchain that stays is a candidate (R-GC3: "another dir"). The build dirs are in `roots.build` (`ROC_CACHE_DIR`), the package dirs in `roots.pkgs`.
# `expired`: more than the span goes, exactly the span stays, a time in the future stays, an `Err` info stays, a dir with no row stays. The order of `dirs` is kept.
expect {
	roots = match Roots.from_env([("HOME", "/h"), ("XDG_CACHE_HOME", "/c"), ("ROC_CACHE_DIR", "/b")]) {
		Ok(r) => r
		Err(_) => crash "the test roots do not parse"
	}
	e = |path, is_dir| { path, is_dir, mtime: 0 }
	entries = [
		e("/c/roc/toolchains/nightly-2026-10-09-258ab27", Bool.True),
		e("/c/roc/packages/895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw", Bool.True),
		e("/c/roc/packages/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA", Bool.True),
		e("/c/roc/packages/4DQvwn8UDgjnLQbitjpB7euqpnQKzr4amMFM6oThgRyN", Bool.True),
		e("/c/roc/packages/4DQvwn8UDgjnLQbitjpB7euqpnQKzr4amMFM6oThgRyN.deps.json", Bool.False),
		e("/c/roc/packages/h1.0123456789abcdef.tmp", Bool.True),
		e("/c/roc/packages/stray-file", Bool.False),
		e("/c/roc/talon/packages/inside-talon", Bool.True),
	]
	builds = [
		e("/b/compat-aaaaaaa", Bool.True),
		e("/b/compat-bbbbbbb", Bool.True),
		e("/b/nightly-2026-01-01-abc1234", Bool.True),
		e("/b/debug-1234567", Bool.True),
		e("/b/compat-", Bool.True),
		e("/b/compat-file", Bool.False),
		e("/b/compat", Bool.True),
		e("/b/toolchains", Bool.True),
		e("/b/talon", Bool.True),
	]
	found = Gc.candidates({ roots, entries, builds, protected: ["895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw"], owned: ["/b/compat-aaaaaaa"] })
	asks = Gc.asks({ roots, toolchains: ["nightly-2026-08-01-aaaaaaa", "git-0badc0de"], compat: ["/b/compat-aaaaaaa"], stale: ["/c/roc/talon/tmp/4123456789abcdef"], builds: found.builds, pkgs: found.pkgs })
	dbg (found, asks)
	ok = |newest, size| Ok({ newest, size })
	span = 2592000
	measured = [
		{ item: "/b/d1", path: "/b/d1", info: ok(now - span - 1, 10) },
		{ item: "/b/d2", path: "/b/d2", info: ok(now - span, 20) },
		{ item: "/b/d3", path: "/b/d3", info: ok(now - 5, 30) },
		{ item: "/b/d4", path: "/b/d4", info: ok(now + 10, 40) },
		{ item: "/b/d5", path: "/b/d5", info: Err(Denied) },
		{ item: "/b/d6", path: "/b/d6", info: ok(0, 60) },
		{ item: "toolchain-id", path: "/c/roc/toolchains/toolchain-id", info: ok(5, 70) },
		{ item: "/b/d7", path: "/b/d7", info: Err(NotFound) },
	]
	dirs = ["/b/d6", "/b/d1", "/b/d2", "/b/d3", "/b/d4", "/b/d5", "/b/d7", "/b/d8"]
	short = Gc.expired({ dirs, measured, now, span: 4 })
	dbg (Gc.expired({ dirs, measured, now, span }), short, Gc.sizes(measured))
	found
		== {
			pkgs: ["/c/roc/packages/4DQvwn8UDgjnLQbitjpB7euqpnQKzr4amMFM6oThgRyN", "/c/roc/packages/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA"],
			builds: ["/b/compat-bbbbbbb", "/b/debug-1234567", "/b/nightly-2026-01-01-abc1234"],
		}
		and asks
			== [
				{ item: "nightly-2026-08-01-aaaaaaa", path: "/c/roc/toolchains/nightly-2026-08-01-aaaaaaa" },
				{ item: "git-0badc0de", path: "/c/roc/toolchains/git-0badc0de" },
				{ item: "/b/compat-aaaaaaa", path: "/b/compat-aaaaaaa" },
				{ item: "/c/roc/talon/tmp/4123456789abcdef", path: "/c/roc/talon/tmp/4123456789abcdef" },
				{ item: "/b/compat-bbbbbbb", path: "/b/compat-bbbbbbb" },
				{ item: "/b/debug-1234567", path: "/b/debug-1234567" },
				{ item: "/b/nightly-2026-01-01-abc1234", path: "/b/nightly-2026-01-01-abc1234" },
				{ item: "/c/roc/packages/4DQvwn8UDgjnLQbitjpB7euqpnQKzr4amMFM6oThgRyN", path: "/c/roc/packages/4DQvwn8UDgjnLQbitjpB7euqpnQKzr4amMFM6oThgRyN" },
				{ item: "/c/roc/packages/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA", path: "/c/roc/packages/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA" },
			]
			and Gc.expired({ dirs, measured, now, span }) == ["/b/d6", "/b/d1"]
				and short == ["/b/d6", "/b/d1", "/b/d2", "/b/d3"]
					and Gc.sizes(measured)
						== [
							{ item: "/b/d1", bytes: 10 },
							{ item: "/b/d2", bytes: 20 },
							{ item: "/b/d3", bytes: 30 },
							{ item: "/b/d4", bytes: 40 },
							{ item: "/b/d6", bytes: 60 },
							{ item: "toolchain-id", bytes: 70 },
						]
}

# R-GC11, R-OUT2, R-OUT4 (slice 028b, proposal): the sizes in the report, the total, and the `data`. `Toolchain.size_text` writes a size (`999 B`, `2.0 KB`, `1.5 MB`, `3.1 GB`).
# An item with no size has no suffix. A skipped toolchain and a project have no size, and a skipped toolchain is not in the total. The total is on the line before the dry run line, and is not there when no removed item has a size.
# `freed` counts an item once (2 compilers with one compat id list one path twice) and an item with no size 0.
expect {
	sized = {
		dry_run: Bool.False,
		ran: Bool.True,
		toolchains: ["t1", "t2"],
		skipped: ["s1"],
		compat: ["/c/c1", "/c/c1"],
		stale: ["/c/x1"],
		builds: ["/b/b1"],
		pkgs: ["/c/roc/packages/p1"],
		projects: ["/p/old/main.roc"],
		sizes: [
			{ item: "t1", bytes: 1500000 },
			{ item: "s1", bytes: 7 },
			{ item: "/c/c1", bytes: 2000 },
			{ item: "/c/x1", bytes: 999 },
			{ item: "/b/b1", bytes: 3100000000 },
			{ item: "/c/roc/packages/p1", bytes: 50 },
		],
	}
	dry = { ..sized, dry_run: Bool.True, skipped: [] }
	only_projects = { ..sized, toolchains: [], skipped: [], compat: [], stale: [], builds: [], pkgs: [], sizes: [] }
	dry_projects = { ..only_projects, dry_run: Bool.True }
	dbg (Gc.report(sized), Gc.report(dry), Gc.data(sized).render(), Gc.freed(sized))
	Gc.report(sized)
		== [
			"removed toolchain t1 (1.5 MB)\n",
			"removed toolchain t2\n",
			"skipped toolchain s1: an install holds it\n",
			"removed /c/c1 (2.0 KB)\n",
			"removed /c/c1 (2.0 KB)\n",
			"removed /c/x1 (999 B)\n",
			"removed /b/b1 (3.1 GB)\n",
			"removed /c/roc/packages/p1 (50 B)\n",
			"removed project /p/old/main.roc\n",
			"freed 3.1 GB\n",
		]
		and Gc.report(dry)
			== [
				"would remove toolchain t1 (1.5 MB)\n",
				"would remove toolchain t2\n",
				"would remove /c/c1 (2.0 KB)\n",
				"would remove /c/c1 (2.0 KB)\n",
				"would remove /c/x1 (999 B)\n",
				"would remove /b/b1 (3.1 GB)\n",
				"would remove /c/roc/packages/p1 (50 B)\n",
				"would remove project /p/old/main.roc\n",
				"would free 3.1 GB\n",
				"dry run: nothing was removed\n",
			]
			and Gc.report(only_projects) == ["removed project /p/old/main.roc\n"]
				and Gc.report(dry_projects) == ["would remove project /p/old/main.roc\n", "dry run: nothing was removed\n"]
					and Gc.freed(sized) == 3101503049
						and Gc.freed(only_projects) == 0
							and Gc.data(sized).render()
								== "{\"dry_run\":false,\"ran\":true,\"toolchains\":[\"t1\",\"t2\"],\"skipped\":[\"s1\"],\"compat\":[\"/c/c1\",\"/c/c1\"],\"stale\":[\"/c/x1\"],\"builds\":[\"/b/b1\"],\"packages\":[\"/c/roc/packages/p1\"],\"projects\":[\"/p/old/main.roc\"],\"sizes\":[{\"item\":\"t1\",\"bytes\":1500000},{\"item\":\"/c/c1\",\"bytes\":2000},{\"item\":\"/c/x1\",\"bytes\":999},{\"item\":\"/b/b1\",\"bytes\":3100000000},{\"item\":\"/c/roc/packages/p1\",\"bytes\":50}],\"freed\":3101503049}"
}
