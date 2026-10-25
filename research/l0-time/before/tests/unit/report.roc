app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Report

main! = |_args| Ok({})

# R-DT5 (slice 007, question Q4): the line that a resolve prints. With no registry it names the time. One probe is `1 probe`.
expect {
	line = |probes| Report.resolved_line({ at: "2026-10-15T12:00:00Z", probes })
	rows = [
		(line(4), "resolved at 2026-10-15T12:00:00Z, 4 probes"),
		(line(3), "resolved at 2026-10-15T12:00:00Z, 3 probes"),
		(line(1), "resolved at 2026-10-15T12:00:00Z, 1 probe"),
		(line(0), "resolved at 2026-10-15T12:00:00Z, 0 probes"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-J3 R-J4 R-OUT4 R-OUT5 R-LF4 R-DT5 R-LF3 R-DL1 (slice 007, slice 025: `downloads` is the count of compilers that the command downloaded, answer Q7 of the review): the `data` of `install` and `add`. It holds each fact that the human text prints. The keys come in a fixed order. A step that did not run is null.
expect {
	full = {
		at: "2026-10-15T12:00:00Z",
		probes: 3,
		downloads: 1,
		dry_run: Bool.False,
		check: Passed,
		build: Passed,
		added: [{ alias: "parser", name: "acme/parser", version: "1.2.0" }],
		moved: [{ alias: "json", from: { name: "acme/json", version: "2.0.0" }, to: { name: "acme/json", version: "2.1.0" } }],
		kept: [{ alias: "util", name: "acme/util", version: "1.0.0" }],
		pinned: Ok("nightly-2026-10-14-38a3029"),
		toml: [{ path: "/p/talon.toml", key: "json", value: "=2.1.0" }],
		renamed: [{ path: "/p/talon.toml", from: "js", to: "json" }],
		notes: ["acme/json 2.1.0 is 1d old (min-release-age 2d)"],
		written: ["/p/main.roc", "/p/talon.toml"],
	}
	skipped = {
		at: "2026-10-15T12:00:00Z",
		probes: 0,
		downloads: 0,
		dry_run: Bool.True,
		check: Skipped,
		build: Skipped,
		added: [],
		moved: [],
		kept: [],
		pinned: Err(None),
		toml: [],
		renamed: [],
		notes: [],
		written: [],
	}
	idle = { ..skipped, dry_run: Bool.False, check: NotRun, build: NotRun }
	render = |o| Report.data(o).render()
	rows = [
		(
			render(full),
			"{\"snapshot\":\"2026-10-15T12:00:00Z\",\"probes\":3,\"downloads\":1,\"dry_run\":false,\"check\":\"passed\",\"build\":\"passed\",\"added\":[{\"alias\":\"parser\",\"name\":\"acme/parser\",\"version\":\"1.2.0\"}],\"moved\":[{\"alias\":\"json\",\"from\":{\"name\":\"acme/json\",\"version\":\"2.0.0\"},\"to\":{\"name\":\"acme/json\",\"version\":\"2.1.0\"}}],\"kept\":[{\"alias\":\"util\",\"name\":\"acme/util\",\"version\":\"1.0.0\"}],\"pinned\":\"nightly-2026-10-14-38a3029\",\"toml\":[{\"path\":\"/p/talon.toml\",\"key\":\"json\",\"value\":\"=2.1.0\"}],\"renamed\":[{\"path\":\"/p/talon.toml\",\"from\":\"js\",\"to\":\"json\"}],\"notes\":[\"acme/json 2.1.0 is 1d old (min-release-age 2d)\"],\"written\":[\"/p/main.roc\",\"/p/talon.toml\"]}",
		),
		(
			render(skipped),
			"{\"snapshot\":\"2026-10-15T12:00:00Z\",\"probes\":0,\"downloads\":0,\"dry_run\":true,\"check\":\"skipped\",\"build\":\"skipped\",\"added\":[],\"moved\":[],\"kept\":[],\"pinned\":null,\"toml\":[],\"renamed\":[],\"notes\":[],\"written\":[]}",
		),
		(
			render(idle),
			"{\"snapshot\":\"2026-10-15T12:00:00Z\",\"probes\":0,\"downloads\":0,\"dry_run\":false,\"check\":null,\"build\":null,\"added\":[],\"moved\":[],\"kept\":[],\"pinned\":null,\"toml\":[],\"renamed\":[],\"notes\":[],\"written\":[]}",
		),
	]
	bad = rows.keep_if(|(got, want)| got != want).map(|(got, _)| got)
	dbg bad
	bad == []
}

# R-J3 R-J4 R-OUT4 R-OUT5 R-LF3 R-RV4 R-RV5 R-RV1 (slice 008): the `data` of `remove` and `rm`. It has no `snapshot` (a remove resolves nothing, so no R-DT5 line). Each fact of the human text is a key,
# in a fixed order. An entry has a `kind`: a release has a version, a path entry or a foreign URL has `null` and its value in `name`. A step that did not run is null.
expect {
	full = {
		probes: 3,
		dry_run: Bool.False,
		check: Passed,
		build: Passed,
		removed: [
			{ alias: "json", kind: Release, name: "acme/json", version: Ok("2.0.0") },
			{ alias: "util", kind: Path, name: "../util/main.roc", version: Err(None) },
			{ alias: "odd", kind: Foreign, name: "https://example.com/pkg/latest.tar.gz", version: Err(None) },
		],
		toml: [{ path: "/p/talon.toml", table: "dependencies", key: "json" }, { path: "/p/talon.toml", table: "patch", key: "json" }],
		patches: [{ alias: "json", dir: "/p/.talon/patches/json/" }],
		pinned: Ok("nightly-2026-10-14-38a3029"),
		notes: ["unchanged error: main.roc: type mismatch"],
		written: ["/p/talon.toml", "/p/main.roc"],
	}
	skipped = {
		probes: 0,
		dry_run: Bool.True,
		check: Skipped,
		build: Skipped,
		removed: [{ alias: "json", kind: Release, name: "acme/json", version: Ok("2.0.0") }],
		toml: [],
		patches: [],
		pinned: Err(None),
		notes: [],
		written: [],
	}
	lib_member = { ..skipped, probes: 2, dry_run: Bool.False, check: Passed, build: NotRun }
	render = |o| Report.remove_data(o).render()
	rows = [
		(
			render(full),
			"{\"probes\":3,\"dry_run\":false,\"check\":\"passed\",\"build\":\"passed\",\"removed\":[{\"alias\":\"json\",\"kind\":\"release\",\"name\":\"acme/json\",\"version\":\"2.0.0\"},{\"alias\":\"util\",\"kind\":\"path\",\"name\":\"../util/main.roc\",\"version\":null},{\"alias\":\"odd\",\"kind\":\"foreign\",\"name\":\"https://example.com/pkg/latest.tar.gz\",\"version\":null}],\"toml\":[{\"path\":\"/p/talon.toml\",\"table\":\"dependencies\",\"key\":\"json\"},{\"path\":\"/p/talon.toml\",\"table\":\"patch\",\"key\":\"json\"}],\"patches\":[{\"alias\":\"json\",\"dir\":\"/p/.talon/patches/json/\"}],\"pinned\":\"nightly-2026-10-14-38a3029\",\"notes\":[\"unchanged error: main.roc: type mismatch\"],\"written\":[\"/p/talon.toml\",\"/p/main.roc\"]}",
		),
		(
			render(skipped),
			"{\"probes\":0,\"dry_run\":true,\"check\":\"skipped\",\"build\":\"skipped\",\"removed\":[{\"alias\":\"json\",\"kind\":\"release\",\"name\":\"acme/json\",\"version\":\"2.0.0\"}],\"toml\":[],\"patches\":[],\"pinned\":null,\"notes\":[],\"written\":[]}",
		),
		(
			render(lib_member),
			"{\"probes\":2,\"dry_run\":false,\"check\":\"passed\",\"build\":null,\"removed\":[{\"alias\":\"json\",\"kind\":\"release\",\"name\":\"acme/json\",\"version\":\"2.0.0\"}],\"toml\":[],\"patches\":[],\"pinned\":null,\"notes\":[],\"written\":[]}",
		),
	]
	bad = rows.keep_if(|(got, want)| got != want).map(|(got, _)| got)
	dbg bad
	bad == []
}
