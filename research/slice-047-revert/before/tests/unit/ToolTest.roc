import lib.Args
import lib.Clock
import lib.Fail
import lib.Index
import lib.JsonDoc
import lib.Probe
import lib.Roots
import lib.Selector
import lib.ToolInstall
import lib.ToolsJson

ToolTest :: [].{}

# Slice 046 (docs/slices/046-tool-install.md): `tln tool install` of a release. The expected value of each row is the design text or the slice file text, not the code. A wrong row prints with
# `dbg`. Texts that the design does not give are the proposals of the slice file (TW24). The Fx calls and the files are in the L2 cases `tests/commands/cases/tool/`.

# Real hashes (base58 of 32 bytes).
h1 = "9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17"

h2 = "J3fdXfd44AGuuqZMdge6UxcjrCJBwHzF2uiQxbu2ZCnr"

h3 = "CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA"

h4 = "4W8SHzvwet9hH9qZewJ1J1CVQoH7YKA6zyijWFTB3y1w"

h5 = "6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS"

now : U64
now = Clock.parse_utc("2026-10-15T12:00:00Z") ?? 0

two_days : U64
two_days = 172800

# One release of the GitHub answer: a candidate (one package asset), with the time of the release.
release : { tag : Str, hash : Str, published : Str } -> Str
release = |r| "{\"tag_name\":\"${r.tag}\",\"draft\":false,\"prerelease\":false,\"published_at\":\"${r.published}\",\"assets\":[{\"name\":\"${r.hash}.tar.zst\",\"size\":1000,\"browser_download_url\":\"https://github.com/acme/foo/releases/download/${r.tag}/${r.hash}.tar.zst\"}]}"

candidates : List({ tag : Str, hash : Str, published : Str }) -> List(Index.Candidate)
candidates = |rows| match Index.candidates({ owner: "acme", repo: "foo", pages: ["[${Str.join_with(rows.map(release), ",")}]"], known: [] }) {
	Ok(found) => found.list
	Err(_) => []
}

# 1.2.0 is 1 hour old at `now`: younger than the 2 days of `min-release-age` (R-C7). The others are older.
main_list : List(Index.Candidate)
main_list = candidates([
	{ tag: "1.0.0", hash: h1, published: "2026-08-01T12:00:00Z" },
	{ tag: "1.1.0", hash: h2, published: "2026-09-01T12:00:00Z" },
	{ tag: "1.2.0", hash: h3, published: "2026-10-15T11:00:00Z" },
	{ tag: "2.0.0", hash: h4, published: "2026-10-01T12:00:00Z" },
])

plan_of : List(Str) -> Try(ToolInstall.Plan, Str)
plan_of = |words| match Args.parse(words) {
	Ok(args) => match ToolInstall.read(args) {
		Ok(plan) => Ok(plan)
		Err(fail) => Err(fail.line())
	}
	Err(stop) => Err("parse: ${stop.fail.line()}")
}

sel_text : Try(Selector, [None]) -> Str
sel_text = |sel| match sel {
	Ok(Exact(v)) => "=${v}"
	Ok(Range(v)) => "range ${v}"
	Ok(Latest) => "latest"
	Ok(GitSha(v)) => "sha ${v}"
	Ok(_) => "other"
	Err(None) => ""
}

# R-CM16 R-T28 R-T6 R-SL1 R-SL2 R-SL3: the operand and the flags of `tool install`. The app is `Ref.parse` in the scope Tool: `acme/foo`, a short name (an installed tool), `@1.1.0` is exact, `@1` is `^1`, `@latest`. `--as` is the binary name, `--roc pinned`
# is the consent for the pinned compiler (R-T6). `--git`, `--path`, `--resolve`, `--roc installed` and a git sha selector are later slices (R-T1, R-T16, R-T23): the command refuses them and says that they are not built yet (proposal, TW24). A binary name starts with a letter or
# a digit and has letters, digits, '.', '_' and '-' (R-ST15: it is a file name).
expect {
	read = |words| match plan_of(words) {
		Ok(plan) => Ok((plan.ref.name, sel_text(plan.ref.selector), plan.as_name, plan.roc))
		Err(line) => Err(line)
	}
	line = |text| Err("tln: error[usage]: ${text}")
	rows = [
		(read(["tool", "install", "acme/foo"]), Ok(("acme/foo", "", Err(Unset), Auto))),
		(read(["tool", "install", "foo"]), Ok(("foo", "", Err(Unset), Auto))),
		(read(["tool", "install", "acme/foo@1.1.0"]), Ok(("acme/foo", "=1.1.0", Err(Unset), Auto))),
		(read(["tool", "install", "acme/foo@1"]), Ok(("acme/foo", "range ^1", Err(Unset), Auto))),
		(read(["tool", "install", "acme/foo@latest"]), Ok(("acme/foo", "latest", Err(Unset), Auto))),
		(read(["tool", "install", "acme/foo", "--as", "q"]), Ok(("acme/foo", "", Ok("q"), Auto))),
		(read(["tool", "install", "acme/foo", "--as", "foo-2.x_y"]), Ok(("acme/foo", "", Ok("foo-2.x_y"), Auto))),
		(read(["tool", "install", "acme/foo", "--roc", "pinned"]), Ok(("acme/foo", "", Err(Unset), Pinned))),
		(read(["tool", "install", "acme/foo", "--roc", "pinned", "--as", "7z"]), Ok(("acme/foo", "", Ok("7z"), Pinned))),
		(read(["tool", "install", "--git", "acme/foo@main"]), line("tln tool install --git is not built yet")),
		(read(["tool", "install", "--path", "../foo"]), line("tln tool install --path is not built yet")),
		(read(["tool", "install", "acme/foo", "--resolve"]), line("tln tool install --resolve is not built yet")),
		(read(["tool", "install"]), line("tln tool install needs one app: owner/app")),
		(read(["tool", "install", "acme/foo", "acme/bar"]), line("tln tool install takes one app, got 2")),
		(read(["tool", "install", "acme/foo@dd03c09e"]), line("'dd03c09e' in 'acme/foo@dd03c09e' is a git ref: a git ref needs --git (not built yet)")),
		(read(["tool", "install", "acme/foo", "--roc", "installed"]), line("--roc installed is not built yet")),
		(read(["tool", "install", "acme/foo", "--roc", "fast"]), line("--roc must be pinned or installed, not 'fast'")),
		(read(["tool", "install", "acme/foo", "--as", "_x"]), line("'_x' is not a binary name: use letters, digits, '.', '_' and '-', and start with a letter or a digit")),
		(read(["tool", "install", "acme/foo", "--as", "a/b"]), line("'a/b' is not a binary name: use letters, digits, '.', '_' and '-', and start with a letter or a digit")),
		(read(["tool", "install", "acme/foo", "--as", "a b"]), line("'a b' is not a binary name: use letters, digits, '.', '_' and '-', and start with a letter or a digit")),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-T28 R-ST15 R-LY7 (question Q1: the design does not give the default name): the binary name is `--as`, else the repo name (the text after the last `/` of the full name). The file is the name, with `.exe` on Windows.
expect {
	key = |extra, name| match plan_of(["tool", "install", "acme/foo"].concat(extra)) {
		Ok(plan) => ToolInstall.key({ plan, name })
		Err(_) => "no plan"
	}
	rows = [
		(key([], "acme/foo"), "foo"),
		(key(["--as", "q"], "acme/foo"), "q"),
		(key([], "example.com/pkgs/json"), "json"),
		(key([], "foo"), "foo"),
		(ToolInstall.file_name({ os: Linux, key: "foo" }), "foo"),
		(ToolInstall.file_name({ os: Macos, key: "foo" }), "foo"),
		(ToolInstall.file_name({ os: Windows, key: "foo" }), "foo.exe"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-T9 R-T10 R-C7 R-DI3 R-DI6 R-B2: the releases to try. With no selector, `@latest` or a range, a release that is younger than `min-release-age` is hidden (here 2 days, 1.2.0 is 1 hour old), and the newest of the others is first. A named version
# (`@1.2.0`) is installed whatever its age: `young` is true when the first release is younger (the command prints the age, R-T9). A release that is exactly `min-release-age` old is visible (`published_at + min_age <= now`).
# Nothing in the selector: `<name> has no release <v>` or `<name> has no release in <range>`. Nothing visible: `no release of <name> is old enough for min-release-age` (the texts are proposals, TW24).
expect {
	pick = |list, selector| match ToolInstall.pick({ name: "acme/foo", list, selector, now, min_age: two_days }) {
		Ok(picked) => Ok((picked.order.map(|c| c.tag), picked.young))
		Err(fail) => Err(fail.line())
	}
	one = |published| candidates([{ tag: "1.0.0", hash: h5, published }])
	usage = |text| Err("tln: error[usage]: ${text}")
	rows = [
		(pick(main_list, Err(None)), Ok((["2.0.0", "1.1.0", "1.0.0"], Bool.False))),
		(pick(main_list, Ok(Latest)), Ok((["2.0.0", "1.1.0", "1.0.0"], Bool.False))),
		(pick(main_list, Ok(Range("^1"))), Ok((["1.1.0", "1.0.0"], Bool.False))),
		(pick(main_list, Ok(Exact("1.1.0"))), Ok((["1.1.0"], Bool.False))),
		(pick(main_list, Ok(Exact("1.2.0"))), Ok((["1.2.0"], Bool.True))),
		(pick(main_list, Ok(Exact("9.9.9"))), usage("acme/foo has no release 9.9.9")),
		(pick(main_list, Ok(Range("^3"))), usage("acme/foo has no release in ^3")),
		(pick(main_list, Ok(Range("^1.2"))), usage("no release of acme/foo is old enough for min-release-age")),
		(pick(one("2026-10-13T12:00:00Z"), Err(None)), Ok((["1.0.0"], Bool.False))),
		(pick(one("2026-10-13T12:00:01Z"), Err(None)), usage("no release of acme/foo is old enough for min-release-age")),
		(pick(one("2026-10-13T12:00:01Z"), Ok(Exact("1.0.0"))), Ok((["1.0.0"], Bool.True))),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-T26 R-B1 R-B2 R-T27: is the installed tool enough? No tool, or a git tool (R-T27: a release install replaces it): build. A release tool and no selector: keep, even if a newer release exists (R-B1). A named version: keep when it is the installed
# one. `@latest` or a range: keep when the newest release of the selector (`first`) is the installed version, else build (R-B2).
expect {
	release_tool = |version| Ok({ key: "foo", name: "acme/foo", source: Release({ version, url: "u" }) })
	git_tool = Ok({ key: "foo", name: "acme/foo", source: Git({ commit: "abc", ref: "main" }) })
	reuse = |installed, selector, first| ToolInstall.reuse({ installed, selector, first })
	rows = [
		(reuse(Err(None), Err(None), "1.1.0"), Build),
		(reuse(git_tool, Err(None), "1.1.0"), Build),
		(reuse(git_tool, Ok(Exact("1.1.0")), "1.1.0"), Build),
		(reuse(release_tool("1.1.0"), Err(None), "2.0.0"), Keep("1.1.0")),
		(reuse(release_tool("1.1.0"), Ok(Exact("1.1.0")), "1.1.0"), Keep("1.1.0")),
		(reuse(release_tool("1.1.0"), Ok(Exact("1.0.0")), "1.0.0"), Build),
		(reuse(release_tool("1.1.0"), Ok(Latest), "1.1.0"), Keep("1.1.0")),
		(reuse(release_tool("1.1.0"), Ok(Latest), "2.0.0"), Build),
		(reuse(release_tool("1.1.0"), Ok(Range("^1")), "1.1.0"), Keep("1.1.0")),
		(reuse(release_tool("1.0.0"), Ok(Range("^1")), "1.1.0"), Build),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-T11 R-T12 R-T6 R-T16 R-DL1 R-DL4 R-DL5 R-NM5 (question Q3: no pin; question Q5: no prompt in this slice): the compiler is the `roc:` pin of the app header (R-T11). The pin is installed: use it. Not installed: R-T6 decides. `--roc pinned`, `--yes` and
# `TALON_AUTO_INSTALL=yes` are Yes: download. `TALON_AUTO_INSTALL=no` with no flag is `download_refused` (R-DL5). No answer is the stop of exit 13 that names the flags (R-NM5). A pin that is no nightly tag (a release version) has no source: `tln roc install <id>` text
# (`Consent.required_want`, R-NS2). No pin: a failure of kind usage (proposal).
expect {
	compiler = |pin, installed| ToolInstall.compiler({ pin, installed })
	want = |id, roc, auto, yes| match ToolInstall.want({ id, roc, auto, yes }) {
		Install => "install"
		Stop(fail) => fail.line()
	}
	pin = "nightly-2026-10-11-1a2b3c4"
	stop = "tln: error[consent]: the compiler ${pin} is not installed. Pass --roc pinned or --yes, or set TALON_AUTO_INSTALL=yes. (--roc installed tries the installed compilers.)"
	compilers = [
		(compiler(Ok(pin), [pin, "nightly-2026-10-14-38a3029"]), Use(pin)),
		(compiler(Ok(pin), ["nightly-2026-10-14-38a3029"]), Missing(pin)),
		(compiler(Ok(pin), []), Missing(pin)),
		(compiler(Err(NoPin), [pin]), NoPin),
	]
	rows = [
		(want(pin, Pinned, Ask, Bool.False), "install"),
		(want(pin, Auto, Yes, Bool.False), "install"),
		(want(pin, Auto, Ask, Bool.True), "install"),
		(want(pin, Pinned, No, Bool.False), "install"),
		(want(pin, Auto, Ask, Bool.False), stop),
		(want(pin, Auto, No, Bool.False), "tln: error[consent]: the compiler ${pin} is not installed. TALON_AUTO_INSTALL=no refuses the download. Run: tln roc install ${pin}, pass --allow-downloads, or set TALON_AUTO_INSTALL=yes."),
		(want("0.1.0", Pinned, Yes, Bool.True), "tln: error[consent]: the compiler 0.1.0 is not installed. Run: tln roc install 0.1.0."),
	]
	bad = rows.keep_if(|(got, want_row)| got != want_row)
	dbg bad
	bad == [] and compilers.all(|(got, want_row)| got == want_row)
}

# R-T3 R-T5 R-T8 R-T11 R-LY2 R-CC1 R-CC2 R-ST15 R-ST7: the paths of one install, and the probe of the build. The app bundle is in the package cache (`<cache>/packages/<hash>`); the build writes into `<cache>/talon/tmp/<hex>/<file>`; the binary is in `<data>/bin/<file>` and the
# bin dir entry in the bin dir, each with a temp name `<file>.<hex>.tmp` for the rename. `.exe` on Windows. The build is `roc build main.roc --opt=speed --output=<out>` with no `--target` (R-T8), in the bundle dir, with the long timeout of a build (question Q6).
expect {
	roots = Roots.{ cache: "/c/roc", pkgs: "/c/roc/packages", build: "/c/roc", config: "/f/talon", data: "/d/talon" }
	lay = |os| ToolInstall.layout({ roots, bin: "/h/.local/bin", os, key: "foo", hash: h1, hex: "0123456789abcdef" })
	spec = ToolInstall.build_spec({ id: "nightly-2026-10-14-38a3029", program: "/c/roc/toolchains/nightly-2026-10-14-38a3029/roc", env: [("ROC_CACHE_DIR", "/c/roc")], dir: "/c/roc/packages/${h1}", output: "/c/roc/talon/tmp/0123456789abcdef/foo" })
	linux = lay(Linux)
	windows = lay(Windows)
	rows = [
		(linux.dir, "/c/roc/packages/${h1}"),
		(linux.temp, "/c/roc/talon/tmp/0123456789abcdef"),
		(linux.output, "/c/roc/talon/tmp/0123456789abcdef/foo"),
		(linux.data_bin, "/d/talon/bin"),
		(linux.data_file, "/d/talon/bin/foo"),
		(linux.data_tmp, "/d/talon/bin/foo.0123456789abcdef.tmp"),
		(linux.bin, "/h/.local/bin"),
		(linux.entry, "/h/.local/bin/foo"),
		(linux.entry_tmp, "/h/.local/bin/foo.0123456789abcdef.tmp"),
		(windows.output, "/c/roc/talon/tmp/0123456789abcdef/foo.exe"),
		(windows.data_file, "/d/talon/bin/foo.exe"),
		(windows.entry, "/h/.local/bin/foo.exe"),
		(Str.join_with(spec.args, " "), "build main.roc --opt=speed --output=/c/roc/talon/tmp/0123456789abcdef/foo"),
		(spec.dir, "/c/roc/packages/${h1}"),
		(spec.compiler, "nightly-2026-10-14-38a3029"),
		(spec.program, "/c/roc/toolchains/nightly-2026-10-14-38a3029/roc"),
		(Str.inspect(spec.env), "[(\"ROC_CACHE_DIR\", \"/c/roc\")]"),
		(spec.timeout.to_str(), "3600"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == [] and !spec.args.any(|a| a.starts_with("--target"))
}

# R-ST6 R-ST11 R-ST7 R-ST12: may the install write the bin dir entry? `old` is the sha256 of the binary in the data bin dir now. No entry: write. An entry with the sha256 of the old binary is Talon's (also a stale link of a binary that a
# earlier install replaced): write. Any other file, a dir, or a file that cannot be read is foreign: never overwritten. A first install (no old binary) writes only to an empty place.
expect {
	rows = [
		(ToolInstall.verdict({ old: Err(NotFound), have: Absent }), Make),
		(ToolInstall.verdict({ old: Ok("aa"), have: Absent }), Make),
		(ToolInstall.verdict({ old: Ok("aa"), have: Sha("aa") }), Make),
		(ToolInstall.verdict({ old: Ok("aa"), have: Sha("bb") }), Foreign),
		(ToolInstall.verdict({ old: Ok("aa"), have: Dir }), Foreign),
		(ToolInstall.verdict({ old: Ok("aa"), have: Unreadable }), Foreign),
		(ToolInstall.verdict({ old: Err(NotFound), have: Sha("aa") }), Foreign),
		(ToolInstall.verdict({ old: Err(NotFound), have: Dir }), Foreign),
		(ToolInstall.verdict({ old: Err(NotFound), have: Unreadable }), Foreign),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-T11 R-T5 R-EC1 R-EC11 (question Q7: the design gives no exit code for a failed build; the proposal follows R-EC11): a build with errors is `app_error` (exit 11) and shows the count and the title of the first error. A hang, a crash, a missing
# fact and a build that passed but made no file are internal errors (exit 1).
expect {
	err = |title| { file: NoFile, title, message: "m" }
	failed = |class, errors| ToolInstall.build_failed({ name: "acme/foo", version: "1.1.0", id: "nightly-2026-10-14-38a3029", class, errors, output: "/t/foo" }).line()
	what = "the build of acme/foo 1.1.0 with nightly-2026-10-14-38a3029"
	rows = [
		(failed(Fail(5), [err("type mismatch"), err("other")]), "tln: error[app_error]: ${what} failed: 5 errors: type mismatch"),
		(failed(Fail(1), [err("unused")]), "tln: error[app_error]: ${what} failed: 1 error: unused"),
		(failed(Fail(2), []), "tln: error[app_error]: ${what} failed: 2 errors"),
		(failed(Hang, []), "tln: error[internal]: ${what} did not end in 3600 s"),
		(failed(Crash("signal 11"), []), "tln: error[internal]: ${what} gave no result: signal 11"),
		(failed(NoFact("no stderr"), []), "tln: error[internal]: ${what} gave no result: no stderr"),
		(failed(Pass, []), "tln: error[internal]: ${what} made no file /t/foo"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-T28 R-NM11 R-CC6 R-T27 R-ST6 R-T10 R-T11: the failures of an install (kind usage, exit 2; the texts are proposals, TW24). A binary name that another tool has names the flag `--as` (R-NM11). The same app under another name (question Q2) says
# how to remove it. A bin dir entry that Talon did not write is not replaced (question Q8). No release with an app bundle (R-T10) names the `--git` form: the tag of the newest release, else the default branch of the repo, else a placeholder.
# The tag of the newest release is the one with the latest `published_at`, the first of two with the same time. The default branch is read from the answer of the repo call: status 200, and a text `default_branch` that is not empty.
expect {
	usage = |text| "tln: error[usage]: ${text}"
	cand = |tag, published| { tag, hash: h1, published }
	listed = candidates([cand("1.0.0", "2026-08-01T12:00:00Z"), cand("1.1.0", "2026-09-01T12:00:00Z"), cand("0.9.0", "2026-07-01T12:00:00Z")])
	tie = candidates([cand("1.0.0", "2026-08-01T12:00:00Z"), { tag: "1.1.0", hash: h2, published: "2026-08-01T12:00:00Z" }])
	rows = [
		(ToolInstall.clash_failure({ key: "foo", taken: "acme/foo", name: "other/foo" }).line(), usage("foo is the binary name of acme/foo already. Use --as <name> to install other/foo under another binary name.")),
		(ToolInstall.elsewhere_failure({ key: "q", name: "acme/qux" }).line(), usage("acme/qux is installed as q already. Remove it first: tln tool remove q")),
		(ToolInstall.foreign_failure("/h/.local/bin/qux").line(), usage("/h/.local/bin/qux is not a file that tln wrote, so tln does not replace it. Use --as <name> to install under another binary name.")),
		(ToolInstall.no_pin({ name: "acme/foo", version: "1.0.0" }).line(), usage("acme/foo 1.0.0 has no roc: pin in its app header, so tln cannot tell which compiler to build with")),
		(ToolInstall.no_candidate({ name: "acme/foo", newest: Ok("1.1.0"), branch: Ok("main") }).line(), usage("acme/foo has no release with an app bundle. tln does not build from source by itself. Run: tln tool install --git acme/foo@1.1.0")),
		(ToolInstall.no_candidate({ name: "acme/foo", newest: Err(None), branch: Ok("trunk") }).line(), usage("acme/foo has no release. tln does not build from source by itself. Run: tln tool install --git acme/foo@trunk")),
		(ToolInstall.no_candidate({ name: "acme/foo", newest: Err(None), branch: Err(None) }).line(), usage("acme/foo has no release, and its default branch is not known. tln does not build from source by itself. Run: tln tool install --git acme/foo@<branch>")),
		(Str.inspect(ToolInstall.newest_tag(listed)), "Ok(\"1.1.0\")"),
		(Str.inspect(ToolInstall.newest_tag(tie)), "Ok(\"1.0.0\")"),
		(Str.inspect(ToolInstall.newest_tag([])), "Err(None)"),
		(Str.inspect(ToolInstall.branch_of({ status: 200, body: "{\"id\":1,\"default_branch\":\"trunk\",\"private\":false}" })), "Ok(\"trunk\")"),
		(Str.inspect(ToolInstall.branch_of({ status: 404, body: "{\"default_branch\":\"trunk\"}" })), "Err(None)"),
		(Str.inspect(ToolInstall.branch_of({ status: 200, body: "{\"default_branch\":\"\"}" })), "Err(None)"),
		(Str.inspect(ToolInstall.branch_of({ status: 200, body: "{\"name\":\"x\"}" })), "Err(None)"),
		(Str.inspect(ToolInstall.branch_of({ status: 200, body: "not json" })), "Err(None)"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-SE8 R-T9 R-OUT2 R-J3 R-J4 R-OUT4 (the texts and the `data` are proposals, TW24): the stderr lines before the build (the platform line has the URL and its hash, and a platform that is no release URL only the value), the age note of a named
# young version (the time is `Clock.format_utc`), the line on stdout (installed, replaced, present), and the `data` of `--json` (the keys in this order; a present tool has no build keys).
expect {
	url = "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/${h3}.tar.zst"
	built = Ok({ url: "https://github.com/acme/foo/releases/download/1.1.0/${h2}.tar.zst", nightly: "nightly-2026-10-14-38a3029", target: "x64musl", sha256: "aa", entry: HardLink })
	data = |how, b| JsonDoc.render(ToolInstall.data({ how, key: "foo", name: "acme/foo", version: "1.1.0", bin: "/h/.local/bin/foo", built: b }))
	head = "\"tool\":\"foo\",\"name\":\"acme/foo\",\"version\":\"1.1.0\""
	rows = [
		(Str.join_with(ToolInstall.header_lines({ name: "acme/foo", version: "1.1.0", id: "nightly-x", pf: Ok(url), hash: Ok(h3) }), "|"), "platform ${url} (hash ${h3})|building acme/foo 1.1.0 with nightly-x"),
		(Str.join_with(ToolInstall.header_lines({ name: "acme/foo", version: "1.1.0", id: "nightly-x", pf: Ok("../pf/main.roc"), hash: Err(None) }), "|"), "platform ../pf/main.roc|building acme/foo 1.1.0 with nightly-x"),
		(Str.join_with(ToolInstall.header_lines({ name: "acme/foo", version: "1.1.0", id: "nightly-x", pf: Err(None), hash: Err(None) }), "|"), "building acme/foo 1.1.0 with nightly-x"),
		(ToolInstall.age_note({ name: "acme/foo", version: "1.2.0", published_at: now - 3600 }), "acme/foo 1.2.0 was released at 2026-10-15T11:00:00Z, less than min-release-age ago. It is installed because the version is named."),
		(ToolInstall.report({ how: Installed, key: "foo", name: "acme/foo", version: "1.1.0" }), "installed foo 1.1.0 (acme/foo)\n"),
		(ToolInstall.report({ how: Replaced("1.0.0"), key: "foo", name: "acme/foo", version: "1.1.0" }), "replaced foo 1.0.0 with 1.1.0 (acme/foo)\n"),
		(ToolInstall.report({ how: Present, key: "foo", name: "acme/foo", version: "1.1.0" }), "foo 1.1.0 is installed\n"),
		(data(Installed, built), "{${head},\"how\":\"installed\",\"previous\":null,\"bin\":\"/h/.local/bin/foo\",\"url\":\"https://github.com/acme/foo/releases/download/1.1.0/${h2}.tar.zst\",\"nightly\":\"nightly-2026-10-14-38a3029\",\"target\":\"x64musl\",\"sha256\":\"aa\",\"entry\":\"hard_link\"}"),
		(data(Replaced("1.0.0"), Ok({ url: "u", nightly: "n", target: "t", sha256: "s", entry: Copy })), "{${head},\"how\":\"replaced\",\"previous\":\"1.0.0\",\"bin\":\"/h/.local/bin/foo\",\"url\":\"u\",\"nightly\":\"n\",\"target\":\"t\",\"sha256\":\"s\",\"entry\":\"copy\"}"),
		(data(Present, Err(None)), "{${head},\"how\":\"present\",\"previous\":null,\"bin\":\"/h/.local/bin/foo\"}"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

foo_json : Str
foo_json = "{\"name\":\"acme/foo\",\"source\":{\"kind\":\"release\",\"version\":\"1.1.0\",\"url\":\"https://x/foo.tar.zst\"}}"

git_json : Str
git_json = "{\"name\":\"acme/g\",\"source\":{\"kind\":\"git\",\"commit\":\"abc\",\"ref\":\"main\"}}"

# R-T4 R-T27 R-LY2 R-LY3 R-TF1 R-TF3 R-ST15: `tools.json` as the command reads it. The key of `tools` is the binary name. A missing file, or a file with no `tools` field, is no tool. A release tool and a git tool (slice 048 writes it; R-T27) are read, in the order
# of the text. Not JSON, a `tools` that is no object, a tool with no name or no source that Talon knows, and a newer `format` (R-TF3, `tln tool update talon`) are failures of kind input (exit 19) that name the file (the texts are proposals, TW24).
expect {
	path = "/d/talon/tools.json"
	read = |text| match ToolsJson.read({ path, text }) {
		Ok(entries) => Ok(
			entries.map(
				|e| match e.source {
					Release({ version, url }) => "${e.key} ${e.name} release ${version} ${url}"
					Git({ commit, ref }) => "${e.key} ${e.name} git ${commit} ${ref}"
				},
			),
		)
		Err(fail) => Err(fail.line())
	}
	input = |text| Err("tln: error[input]: ${path}: ${text}")
	rows = [
		(read(Err(NotFound)), Ok([])),
		(read(Ok("{\"format\":1}")), Ok([])),
		(read(Ok("{\"format\":1,\"tools\":{}}")), Ok([])),
		(read(Ok("{\"format\":1,\"tools\":{\"foo\":${foo_json},\"g\":${git_json}}}")), Ok(["foo acme/foo release 1.1.0 https://x/foo.tar.zst", "g acme/g git abc main"])),
		(read(Ok("{\"format\":1,\"extra\":[1],\"tools\":{\"foo\":{\"name\":\"acme/foo\",\"source\":{\"kind\":\"release\",\"version\":\"1.1.0\",\"url\":\"u\"},\"later\":true}}}")), Ok(["foo acme/foo release 1.1.0 u"])),
		(read(Ok("not json")), input("the content does not parse")),
		(read(Ok("{\"format\":1,\"tools\":[]}")), input("tools is not an object")),
		(read(Ok("{\"format\":1,\"tools\":{\"foo\":3}}")), input("tool foo: is not an object")),
		(read(Ok("{\"format\":1,\"tools\":{\"foo\":{\"source\":{\"kind\":\"git\",\"commit\":\"a\",\"ref\":\"b\"}}}}")), input("tool foo: has no name")),
		(read(Ok("{\"format\":1,\"tools\":{\"foo\":{\"name\":\"acme/foo\"}}}")), input("tool foo: has no source that tln knows")),
		(read(Ok("{\"format\":1,\"tools\":{\"foo\":{\"name\":\"acme/foo\",\"source\":{\"kind\":\"zip\"}}}}")), input("tool foo: has no source that tln knows")),
		(read(Ok("{\"format\":2,\"tools\":{}}")), input("format 2 is newer than this tln (format 1). Run: tln tool update talon")),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

built : ToolsJson.Built
built = { key: "foo", name: "acme/foo", version: "1.2.0", url: "https://x/foo2.tar.zst", hashes: ["H1", "H2"], nightly: "nightly-2026-10-14-38a3029", target: "x64musl", sha256: "S", libs: [], installed_at: "2026-10-15T12:00:00Z" }

built_json : Str
built_json = "{\"name\":\"acme/foo\",\"source\":{\"kind\":\"release\",\"version\":\"1.2.0\",\"url\":\"https://x/foo2.tar.zst\"},\"build\":{\"hashes\":[\"H1\",\"H2\"],\"nightly\":\"nightly-2026-10-14-38a3029\",\"target\":\"x64musl\"},\"sha256\":\"S\",\"libs\":[],\"installed_at\":\"2026-10-15T12:00:00Z\"}"

# R-T4 R-T26 R-T27 R-TF1 R-TF2 R-TF3 R-CC6 R-LY2: the text of `tools.json` after an install. A missing file or no `tools` field: the file has `format` 1 and the tool (R-TF1). A new tool is the last. A tool with the same key is replaced in its place (R-T26), also a git tool
# (R-T27: the source is the release). The other tools and the other fields of the file stay (R-TF2), also the fields of the replaced tool that Talon does not know. A newer `format` is exit 19 and writes nothing (R-TF3).
expect {
	path = "/d/talon/tools.json"
	add = |text| match ToolsJson.add({ path, text, built }) {
		Ok(out) => out.trim_end()
		Err(fail) => fail.line()
	}
	other = "\"bar\":${git_json}"
	ends_with_line = match ToolsJson.add({ path, text: Err(NotFound), built }) {
		Ok(out) => out.ends_with("}\n") and !out.trim_end().contains("\n")
		Err(_) => Bool.False
	}
	rows = [
		(add(Err(NotFound)), "{\"format\":1,\"tools\":{\"foo\":${built_json}}}"),
		(add(Ok("{\"format\":1}")), "{\"format\":1,\"tools\":{\"foo\":${built_json}}}"),
		(add(Ok("{\"format\":1,\"tools\":{${other}}}")), "{\"format\":1,\"tools\":{${other},\"foo\":${built_json}}}"),
		(add(Ok("{\"format\":1,\"tools\":{\"foo\":${foo_json},${other}}}")), "{\"format\":1,\"tools\":{\"foo\":${built_json},${other}}}"),
		(add(Ok("{\"format\":1,\"tools\":{${other},\"foo\":{\"name\":\"acme/foo\",\"source\":{\"kind\":\"git\",\"commit\":\"a\",\"ref\":\"b\"}}}}")), "{\"format\":1,\"tools\":{${other},\"foo\":${built_json}}}"),
		(add(Ok("{\"format\":1,\"note\":\"keep\",\"tools\":{\"foo\":{\"later\":7,\"name\":\"old\"}}}")), "{\"format\":1,\"note\":\"keep\",\"tools\":{\"foo\":{\"later\":7,\"name\":\"acme/foo\",\"source\":{\"kind\":\"release\",\"version\":\"1.2.0\",\"url\":\"https://x/foo2.tar.zst\"},\"build\":{\"hashes\":[\"H1\",\"H2\"],\"nightly\":\"nightly-2026-10-14-38a3029\",\"target\":\"x64musl\"},\"sha256\":\"S\",\"libs\":[],\"installed_at\":\"2026-10-15T12:00:00Z\"}}}"),
		(add(Ok("{\"format\":2,\"tools\":{}}")), "tln: error[input]: ${path}: format 2 is newer than this tln (format 1). Run: tln tool update talon"),
		(add(Ok("not json")), "tln: error[input]: ${path}: the content does not parse"),
		(add(Ok("{\"format\":1,\"tools\":3}")), "tln: error[input]: ${path}: tools is not an object"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == [] and ends_with_line
}

# R-T28 R-T26 R-T27 R-CC6 R-SC3 R-ST15: the binary name and the full name against the tools that are installed. The key is looked at first: the same full name is the same tool (a build replaces it, R-T26, R-T27), another full name is the binary name clash
# (R-T28). No tool with the key and a tool with the full name under another key is `Elsewhere` (question Q2). The tools are the entities of a name lookup (R-SC3): the alias is the key, a release tool has its version and its series, a git tool none.
expect {
	entries = [
		{ key: "foo", name: "acme/foo", source: Release({ version: "1.1.0", url: "u" }) },
		{ key: "q", name: "acme/qux", source: Release({ version: "2.0.0", url: "v" }) },
		{ key: "g", name: "acme/g", source: Git({ commit: "abc", ref: "main" }) },
	]
	clash = |key, name| match ToolsJson.clash({ entries, key, name }) {
		Free => "free"
		Same(e) => "same ${e.key}"
		Taken(e) => "taken ${e.key} ${e.name}"
		Elsewhere(e) => "elsewhere ${e.key}"
	}
	rows = [
		(clash("bar", "acme/bar"), "free"),
		(clash("foo", "acme/foo"), "same foo"),
		(clash("g", "acme/g"), "same g"),
		(clash("foo", "other/foo"), "taken foo acme/foo"),
		(clash("q", "acme/foo"), "taken q acme/qux"),
		(clash("qux", "acme/qux"), "elsewhere q"),
		(Str.inspect(ToolsJson.entities(entries).map(|e| (e.alias, e.name, e.series, e.version))), "[(\"foo\", \"acme/foo\", \"1\", Ok(\"1.1.0\")), (\"q\", \"acme/qux\", \"2\", Ok(\"2.0.0\")), (\"g\", \"acme/g\", \"\", Err(None))]"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-T2 (review of Q9, slice 054 `BuildTarget.targets_of`): only an app whose platform makes a native executable can be installed. A platform whose `targets` has names and only wasm names is refused (exit 2). A header with no readable `targets` is admitted (question Q1 of
# slice 054), also `targets: {}`. One native name is enough. The text is a proposal (TW24).
expect {
	rows = [
		(ToolInstall.native(Err(NoSection)), Native),
		(ToolInstall.native(Ok([])), Native),
		(ToolInstall.native(Ok(["wasm32"])), WasmOnly(["wasm32"])),
		(ToolInstall.native(Ok(["wasm32", "wasm32v1"])), WasmOnly(["wasm32", "wasm32v1"])),
		(ToolInstall.native(Ok(["wasm32", "x64musl"])), Native),
		(ToolInstall.native(Ok(["x64mac"])), Native),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	text = ToolInstall.not_native({ name: "acme/wasm", version: "1.0.0", hash: h1, names: ["wasm32", "wasm32v1"] }).line()
	bad == [] and text == "tln: error[usage]: acme/wasm 1.0.0 needs the platform ${h1}, which has no native target (targets: wasm32, wasm32v1). tln tool install makes a command line tool, so it needs a native platform."
}

# R-T26 R-T27 R-T28 (review 2: the same source under another key): the key under which a tool with the full name is installed. A tool that was installed with `--as q` and is named again by its full name (`acme/qux`, no `--as`) is the same tool: the command works on the
# key `q` (R-T26: keep or replace there). A git tool counts too (R-T27). A name that no tool has: `Err(None)` (the key is then the repo name, `ToolInstall.key`). A short name is not a full name: `Err(None)`. With `--as` that differs, the flow uses `--as` and
# `ToolsJson.clash` is `Elsewhere` (expect 13: exit 2, D2). The code agent adds `ToolInstall.installed_key`: `{ entries : List(ToolsJson.Entry), name : Str } -> Try(Str, [None])`.
expect {
	entries = [
		{ key: "foo", name: "acme/foo", source: Release({ version: "1.1.0", url: "u" }) },
		{ key: "q", name: "acme/qux", source: Release({ version: "2.0.0", url: "v" }) },
		{ key: "g", name: "acme/g", source: Git({ commit: "abc", ref: "main" }) },
	]
	rows = [
		(Str.inspect(ToolInstall.installed_key({ entries, name: "acme/qux" })), "Ok(\"q\")"),
		(Str.inspect(ToolInstall.installed_key({ entries, name: "acme/foo" })), "Ok(\"foo\")"),
		(Str.inspect(ToolInstall.installed_key({ entries, name: "acme/g" })), "Ok(\"g\")"),
		(Str.inspect(ToolInstall.installed_key({ entries, name: "acme/new" })), "Err(None)"),
		(Str.inspect(ToolInstall.installed_key({ entries, name: "q" })), "Err(None)"),
		(Str.inspect(ToolInstall.installed_key({ entries: [], name: "acme/qux" })), "Err(None)"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}
