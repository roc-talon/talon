import lib.Args
import lib.Fail
import lib.GitBuild
import lib.GitRef
import lib.Github
import lib.Help
import lib.JsonDoc
import lib.Nightlies
import lib.Roots

GitTest :: [].{}

# Slice 045 (docs/slices/045-git-install.md): `tln roc install --git`, `tln roc install @<sha>` and `tln roc default --git`. The expected value of each row is the design text or the
# slice file text, not the code. A wrong row prints with `dbg`. Texts that the design does not give are the proposals of the slice file (TW24). The shas are made up, except
# `cf42a741...` (the real head of roc-lang/roc on 2026-10-24, read from the GitHub API).

sha_a : Str
sha_a = "dd03c09e5f0a3b6c7d8e9f001122334455667788"

sha_b : Str
sha_b = "cf42a741e8eaec6f953ca361e66d59a5d3c9ff45"

fork : GitRef.Source
fork = { owner: "Karakatiza666", repo: "roc", ref: "my-branch" }

main_ref : GitRef.Source
main_ref = { owner: "roc-lang", repo: "roc", ref: "main" }

roots : Roots
roots = Roots.{ cache: "/c/roc", pkgs: "/c/roc/packages", build: "/c/roc", config: "/f/talon", data: "/d/talon" }

# R-R9 R-R10 R-R11 R-SL8 R-SL10 R-SL13 R-FL14 R-R5: the ref of the operand. `--git` is a flag, the ref is the operand: `@main` is `roc-lang/roc@main` (R-SL2), a fork is `owner/repo@ref`.
# `roc install` takes a sha with no `--git` (R-R11: hex only, 7 or more digits, R-SL10), also in the form `owner/repo@<sha>`. With `--git` each selector is a ref, also `latest` (R-SL13).
# A compiler selector (a nightly, `@latest`, a step, a release version) and a prefix are not a git ref: `Ok(Err(NotGit))`, and the old command reads them. `roc default` needs `--git`.
# A failure of `--git` that the design does not give is a proposal (TW24): no operand, 2 operands, a name that is not `owner/repo`, no `@ref` (question Q2: the design does not say, so the command refuses and does not guess; slice 045 gap rows C3).
expect {
	read = |words, bare| match Args.parse(words) {
		Ok(args) => match GitRef.read({ args, bare_sha: bare }) {
			Ok(found) => Ok(found)
			Err(fail) => Err(fail.line())
		}
		Err(stop) => Err("parse: ${stop.fail.line()}")
	}
	src = |owner, repo, ref| Ok(Ok({ owner, repo, ref }))
	not_git = Ok(Err(NotGit))
	rows = [
		(read(["roc", "install", "--git", "@main"], Bool.True), src("roc-lang", "roc", "main")),
		(read(["roc", "install", "--git", "Karakatiza666/roc@my-branch"], Bool.True), src("Karakatiza666", "roc", "my-branch")),
		(read(["roc", "install", "@dd03c09e"], Bool.True), src("roc-lang", "roc", "dd03c09e")),
		(read(["roc", "install", "Karakatiza666/roc@dd03c09e"], Bool.True), src("Karakatiza666", "roc", "dd03c09e")),
		(read(["roc", "install", "@${sha_a}"], Bool.True), src("roc-lang", "roc", sha_a)),
		(read(["roc", "add", "--git", "@dd03c09e"], Bool.True), src("roc-lang", "roc", "dd03c09e")),
		(read(["roc", "install", "--git", "roc-lang/roc@v0.1.0"], Bool.True), src("roc-lang", "roc", "v0.1.0")),
		(read(["roc", "install", "--git", "@latest"], Bool.True), src("roc-lang", "roc", "latest")),
		(read(["roc", "install", "--git", "@feature/x"], Bool.True), src("roc-lang", "roc", "feature/x")),
		(read(["--git", "roc", "i", "@main"], Bool.True), src("roc-lang", "roc", "main")),
		(read(["roc", "install", "nightly-2026-10-09-258ab27"], Bool.True), not_git),
		(read(["roc", "install", "@nightly-2026-10-09-258ab27"], Bool.True), not_git),
		(read(["roc", "install", "@latest"], Bool.True), not_git),
		(read(["roc", "install", "@-1"], Bool.True), not_git),
		(read(["roc", "install", "nightly-2026-10"], Bool.True), not_git),
		(read(["roc", "install", "Karakatiza666/roc@1.2.3"], Bool.True), not_git),
		(read(["roc", "install"], Bool.True), not_git),
		(read(["roc", "install", "a", "b"], Bool.True), not_git),
		(read(["roc", "default", "@dd03c09e"], Bool.False), not_git),
		(read(["roc", "default", "Karakatiza666/roc@dd03c09e"], Bool.False), not_git),
		(read(["roc", "default", "git-dd03c09e"], Bool.False), not_git),
		(read(["roc", "default", "--git", "Karakatiza666/roc@my-branch"], Bool.False), src("Karakatiza666", "roc", "my-branch")),
		(read(["roc", "default", "--git", "@main"], Bool.False), src("roc-lang", "roc", "main")),
		(read(["roc", "install", "--git"], Bool.True), Err("tln: error[usage]: tln roc install --git needs one ref: owner/repo@ref or @ref")),
		(read(["roc", "i", "--git"], Bool.True), Err("tln: error[usage]: tln roc i --git needs one ref: owner/repo@ref or @ref")),
		(read(["roc", "default", "--git"], Bool.False), Err("tln: error[usage]: tln roc default --git needs one ref: owner/repo@ref or @ref")),
		(read(["roc", "install", "--git", "@a", "@b"], Bool.True), Err("tln: error[usage]: tln roc install --git takes one ref, got 2")),
		(read(["roc", "install", "--git", "foo@main"], Bool.True), Err("tln: error[usage]: --git takes a GitHub repository as owner/repo, not 'foo'")),
		(read(["roc", "install", "--git", "foo"], Bool.True), Err("tln: error[usage]: --git takes a GitHub repository as owner/repo, not 'foo'")),
		(read(["roc", "install", "--git", "a/b/c@main"], Bool.True), Err("tln: error[usage]: 'a/b/c' is not a package name: use a short name, owner/repo or host/path")),
		(read(["roc", "install", "--git", "Karakatiza666/roc"], Bool.True), Err("tln: error[usage]: 'Karakatiza666/roc' has no ref: use owner/repo@ref or @ref")),
		(read(["roc", "install", "--git", "Karakatiza666/roc@"], Bool.True), Err("tln: error[usage]: 'Karakatiza666/roc@' has an empty selector after '@'")),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-R3 R-R1 R-R9 R-EV19 R-DA3 R-DI9: the names and the requests. The archive is `GET <api>/repos/<owner>/<repo>/tarball/<sha>` with the full sha (R-R3). `<api>` is `Net.Settings.api`
# (`https://api.github.com`, or `TALON_GITHUB_API`: R-EV19). The id is `git-` and the first 8 characters of the full sha (R-R1). The repo URL of `.talon.json` is the GitHub URL of the repo whatever `<api>` is.
# The commit of a ref is found with `GET <api>/repos/<owner>/<repo>/commits/<ref>` and the media type that gives the sha as text (question Q1: the design does not name this request). It has
# no token and no ETag (R-DA3, R-DI9: only the list call sends the token). The header line is the first line of the design example of R-D4: `Build roc from <owner>/<repo>@<ref> (<sha8>)`.
expect {
	api = "https://api.github.com"
	loop = "http://127.0.0.1:41234/api"
	rows = [
		(GitRef.sha_id(sha_a), "git-dd03c09e"),
		(GitRef.sha_id(sha_b), "git-cf42a741"),
		(GitRef.archive_url({ api, source: fork, sha: sha_a }), "https://api.github.com/repos/Karakatiza666/roc/tarball/${sha_a}"),
		(GitRef.archive_url({ api: loop, source: main_ref, sha: sha_b }), "http://127.0.0.1:41234/api/repos/roc-lang/roc/tarball/${sha_b}"),
		(GitRef.commit_url({ api, source: fork }), "https://api.github.com/repos/Karakatiza666/roc/commits/my-branch"),
		(GitRef.commit_url({ api: loop, source: { ..main_ref, ref: "dd03c09e" } }), "http://127.0.0.1:41234/api/repos/roc-lang/roc/commits/dd03c09e"),
		(GitRef.repo_url(fork), "https://github.com/Karakatiza666/roc"),
		(GitRef.repo_url(main_ref), "https://github.com/roc-lang/roc"),
		(GitRef.name_text(fork), "Karakatiza666/roc@my-branch"),
		(GitRef.header_line({ source: fork, sha: sha_a }), "Build roc from Karakatiza666/roc@my-branch (dd03c09e)"),
		(GitRef.header_line({ source: main_ref, sha: sha_b }), "Build roc from roc-lang/roc@main (cf42a741)"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	headers = GitRef.commit_headers({ token: Err(None) })
	with_token = GitRef.commit_headers({ token: Ok("ghp_fake") })
	dbg bad
	dbg headers
	dbg with_token
	bad == []
		and headers == [("User-Agent", "tln/${Help.version}"), ("Accept", "application/vnd.github.sha")]
			and with_token == [("User-Agent", "tln/${Help.version}"), ("Authorization", "Bearer ghp_fake"), ("Accept", "application/vnd.github.sha")]
}

# R-SE12 R-R3 R-DI13 (the commit answer): a 200 answer with 40 lower case hex digits (the body can end with a line end) is the sha. Any other 200 body (short, upper case, 41 digits, JSON,
# empty) is a failure of kind `Network` (exit 15): GitHub did not give a commit. 404 (no repository) and 422 (no commit for the ref, the answer of the real API) are kind `Usage`
# (exit 2). A rate limit is the failure of R-DI13 (`Github.rate_limit_failure`). Any other status is `Github.status_failure`. The texts are proposals (TW24).
expect {
	url = "https://api.github.com/repos/Karakatiza666/roc/commits/my-branch"
	of = |status, headers, body| GitRef.commit_of({ source: fork, url, now: 1792065600, status, headers, body })
	no_commit = Err(Fail.new(Network, "GitHub gave no commit sha for Karakatiza666/roc@my-branch at ${url}"))
	missing = Err(Fail.new(Usage, "no commit my-branch in Karakatiza666/roc"))
	limited = [("X-RateLimit-Remaining", "0"), ("X-RateLimit-Reset", "1792069200")]
	rows = [
		(of(200, [], sha_a), Ok(sha_a)),
		(of(200, [], "${sha_a}\n"), Ok(sha_a)),
		(of(200, [], "dd03c09"), no_commit),
		(of(200, [], sha_a.with_ascii_uppercased()), no_commit),
		(of(200, [], "${sha_a}0"), no_commit),
		(of(200, [], "{\"sha\":\"${sha_a}\"}"), no_commit),
		(of(200, [], ""), no_commit),
		(of(404, [], "{\"message\":\"Not Found\"}"), missing),
		(of(422, [], "{\"message\":\"Not Found\"}"), missing),
		(of(403, limited, "{}"), Err(Github.rate_limit_failure({ reset: Ok(1792069200) }))),
		(of(429, [("Retry-After", "60")], "{}"), Err(Github.rate_limit_failure({ reset: Ok(1792065660) }))),
		(of(403, [], "{}"), Err(Github.status_failure({ url, status: 403 }))),
		(of(500, [], "oops"), Err(Github.status_failure({ url, status: 500 }))),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-R2: the note when the commit is the commit of a nightly. The tag of a nightly ends with the first 7 or more digits of the commit, so a nightly is the commit when the sha starts with the sha of the
# tag. The note is the design text: `<sha8> is <tag>. tln roc install <tag> downloads it.` The tag is named as the list gives it (the month as a name stays). Only a nightly that the host can download
# is named (a release with no asset, or with 2, gives no note: "downloads it" would be false). A tag with 8 digits needs all 8 to match. The first nightly of the list wins.
# (The tags are real, the commits are made up: `5349569...`, `f5556d8...`.)
expect {
	asset = Ok({ name: "roc_nightly-linux_x86_64-x.tar.gz", url: "http://127.0.0.1:1/x", size: 1, sha256: Err(None) })
	rel = |id| { id, published_at: 1, asset }
	releases = [
		rel("nightly-2026-07-31-f5556d8"),
		rel("nightly-2026-10-21-5349569"),
		{ id: "nightly-2026-10-22-aaaaaaa", published_at: 2, asset: Err(NoAsset) },
		{ id: "nightly-2026-10-23-bbbbbbb", published_at: 3, asset: Err(Several(2)) },
		rel("nightly-2026-10-24-12345678"),
		rel("nightly-2026-10-25-cf42a74"),
		rel("nightly-2026-10-26-cf42a74"),
		rel("v0.1.0"),
	]
	note = |sha| GitRef.nightly_note({ sha, releases })
	rows = [
		(note("5349569a1b2c3d4e5f60718293a4b5c6d7e8f901"), Ok("5349569a is nightly-2026-10-21-5349569. tln roc install nightly-2026-10-21-5349569 downloads it.")),
		(note("f5556d8000000000000000000000000000000000"), Ok("f5556d80 is nightly-2026-07-31-f5556d8. tln roc install nightly-2026-07-31-f5556d8 downloads it.")),
		(note("aaaaaaa000000000000000000000000000000000"), Err(None)),
		(note("bbbbbbb000000000000000000000000000000000"), Err(None)),
		(note("1234567800000000000000000000000000000000"), Ok("12345678 is nightly-2026-10-24-12345678. tln roc install nightly-2026-10-24-12345678 downloads it.")),
		(note("1234567900000000000000000000000000000000"), Err(None)),
		(note(sha_b), Ok("cf42a741 is nightly-2026-10-25-cf42a74. tln roc install nightly-2026-10-25-cf42a74 downloads it.")),
		(note(sha_a), Err(None)),
		(note("5349568a1b2c3d4e5f60718293a4b5c6d7e8f901"), Err(None)),
		(note("00053495690000000000000000000000000000cf"), Err(None)),
	]
	none = GitRef.nightly_note({ sha: sha_a, releases: [] })
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == [] and none == Err(None)
}

# R-D3 (slice 044 Q4): the name of the LLVM bundle target of each host in the dependency list. The design gives `x86_64-linux-musl` (R-D4 example). The other 5 are proposals (TW24): the Linux
# targets have `-musl` (roc-lang/roc-bootstrap builds musl), the others are the Zig target.
expect {
	rows = [
		(GitRef.llvm_target(LinuxX64), "x86_64-linux-musl"),
		(GitRef.llvm_target(LinuxArm64), "aarch64-linux-musl"),
		(GitRef.llvm_target(MacosApple), "aarch64-macos"),
		(GitRef.llvm_target(MacosX64), "x86_64-macos"),
		(GitRef.llvm_target(WindowsX64), "x86_64-windows"),
		(GitRef.llvm_target(WindowsArm64), "aarch64-windows"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-R1 R-R3 R-R7 R-CC1 R-CC4 R-LY1: the paths of one install and the build command. `<item>` is `toolchains/git-<sha8>` (the lock item). The source is extracted before the lock (the dependency prompt needs
# `build.zig.zon`, and a prompt must not be under a lock, R-CC3 point 5), so it is in a scratch dir `talon/tmp/<hex>/` and not in the temp dir of the item: the archive `source.tar.gz`, the tree
# `src/`, and the program that `zig build` makes at `src/zig-out/bin/roc` (`roc.exe` on Windows). `roc` and `.talon.json` are in the temp dir `<item>.<hex>.tmp/` (the temp dir has no source).
# The command is the design text (R-R3): `zig build roc -Doptimize=ReleaseFast -Dcompiler-version=git-<sha8>`, with the program that the Zig search found.
expect {
	linux = GitBuild.plan({ roots, host: LinuxX64, id: "git-dd03c09e", hex: "0123456789abcdef" })
	windows = GitBuild.plan({ roots, host: WindowsArm64, id: "git-dd03c09e", hex: "0123456789abcdef" })
	want_linux = {
		id: "git-dd03c09e",
		item: "/c/roc/toolchains/git-dd03c09e",
		temp: "/c/roc/toolchains/git-dd03c09e.0123456789abcdef.tmp",
		scratch: "/c/roc/talon/tmp/0123456789abcdef",
		archive: "/c/roc/talon/tmp/0123456789abcdef/source.tar.gz",
		src: "/c/roc/talon/tmp/0123456789abcdef/src",
		zon: "/c/roc/talon/tmp/0123456789abcdef/src/build.zig.zon",
		built: "/c/roc/talon/tmp/0123456789abcdef/src/zig-out/bin/roc",
		roc: "/c/roc/toolchains/git-dd03c09e.0123456789abcdef.tmp/roc",
		meta: "/c/roc/toolchains/git-dd03c09e.0123456789abcdef.tmp/.talon.json",
		probe_file: "/c/roc/talon/tmp/0123456789abcdef/empty.roc",
	}
	command = GitBuild.build_command({ zig: "zig", id: "git-dd03c09e" })
	installed = GitBuild.build_command({ zig: "/c/roc/toolchains/zig-0.17.0/zig", id: "git-cf42a741" })
	dbg linux
	dbg windows
	linux == want_linux
		and windows == { ..want_linux, built: "/c/roc/talon/tmp/0123456789abcdef/src/zig-out/bin/roc.exe", roc: "/c/roc/toolchains/git-dd03c09e.0123456789abcdef.tmp/roc.exe" }
			and command == ["zig", "build", "roc", "-Doptimize=ReleaseFast", "-Dcompiler-version=git-dd03c09e"]
				and installed == ["/c/roc/toolchains/zig-0.17.0/zig", "build", "roc", "-Doptimize=ReleaseFast", "-Dcompiler-version=git-cf42a741"]
}

# R-R1 R-R7 R-TF1 R-CV5 R-LY1: `.talon.json` of a source build: one line, `format` 1 first, then `id`, `repo` (the URL on GitHub), `sha` (the full sha), `ref` (the ref as the user typed it: a branch, a tag
# or a sha), `sha256` (of the archive, as Talon computed it: R-R7), `sha256_source` (`computed`), `compat` (a text, or `null` for an unknown id and for several), `installed_at` (the time of Talon).
# The field names and their order are a proposal (TW24); R-R1 names the three facts, R-R7 the sha256. The text is valid JSON.
expect {
	base = { id: "git-dd03c09e", source: fork, sha: sha_a, sha256: "9f".repeat(32), compat: Ok("c0ffee"), now: 1792670400 }
	ok = GitBuild.meta(base)
	unknown = GitBuild.meta({ ..base, compat: Err(Unknown) })
	several = GitBuild.meta({ ..base, compat: Err(Several(["a", "b"])) })
	short = GitBuild.meta({ ..base, source: { ..main_ref, ref: "dd03c09e" } })
	dbg ok
	ok == "{\"format\":1,\"id\":\"git-dd03c09e\",\"repo\":\"https://github.com/Karakatiza666/roc\",\"sha\":\"${sha_a}\",\"ref\":\"my-branch\",\"sha256\":\"${"9f".repeat(32)}\",\"sha256_source\":\"computed\",\"compat\":\"c0ffee\",\"installed_at\":\"2026-10-22T12:00:00Z\"}\n"
		and unknown == ok.replace_each("\"compat\":\"c0ffee\"", "\"compat\":null")
			and several == unknown
				and short == ok.replace_each("Karakatiza666/roc", "roc-lang/roc").replace_each("my-branch", "dd03c09e")
					and JsonDoc.parse(ok.trim()).is_ok()
}

# R-DA3 R-SE12 R-R3 R-CC2 R-NI6: the failures of the command. The build failure is kind `Internal` (question Q5: the design has no code for a failed source build). The text has the id, how the
# child ended and its last stderr line. The other texts are proposals (TW24): no curl (the design says "exit code 18 and names curl", R-DA3), `--offline` (exit 15, as R-DI12), no installed build for
# `roc default --git` (question Q8, not decided by the design: not in a deep test).
expect {
	build = |ended, last_line| GitBuild.build_failed({ id: "git-dd03c09e", ended, last_line })
	rows = [
		(build(Exited(1), "error: unable to find 'build.zig'"), Fail.new(Internal, "zig build of git-dd03c09e failed (exit 1): error: unable to find 'build.zig'")),
		(build(Exited(2), ""), Fail.new(Internal, "zig build of git-dd03c09e failed (exit 2)")),
		(build(Signaled(9), "Killed"), Fail.new(Internal, "zig build of git-dd03c09e failed (signal 9): Killed")),
		(build(NotStarted("no such file"), ""), Fail.new(Internal, "zig build of git-dd03c09e failed (did not start: no such file)")),
		(GitBuild.no_binary("git-dd03c09e"), Fail.new(Internal, "zig build of git-dd03c09e made no roc in zig-out/bin")),
		(GitRef.offline_failure(fork), Fail.new(Network, "Karakatiza666/roc@my-branch needs a request to find its commit, and --offline is set")),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	curl = GitRef.needs_curl({})
	none = GitBuild.none_installed(fork)
	dbg bad
	bad == []
		and curl.kind == Environment
			and curl.message.contains("curl")
				and none.kind == Usage
					and none.message.contains("Karakatiza666/roc@my-branch")
}

# R-R5 R-R1 R-R6: `tln roc default --git <owner/repo@ref>` picks the newest installed build of that ref: the `.talon.json` of a `git-*` dir that has the same repo URL and the same ref text, and the
# latest `installed_at` (the time, not the text; the order of the rows does not matter). A build of another repo with the same ref, another ref of the same repo (`my-branch2` is not `my-branch`),
# a file that is missing or not JSON, a `.talon.json` of a nightly (no `repo`), and a row with no `installed_at` are not picked. No such build: `Err(None)`.
# Review Q6: a typed sha (7 to 40 lower case hex digits) also matches a build whose full `sha` starts with it (the build of `main` made at that commit), also with a newer build of the same typed text. Fewer than 7 digits, upper case, a non-hex text, another repo and a row with no `sha` do not match by sha.
expect {
	meta = |repo, ref, at| "{\"format\":1,\"id\":\"x\",\"repo\":\"${repo}\",\"sha\":\"${sha_a}\",\"ref\":\"${ref}\",\"sha256\":\"${"1".repeat(64)}\",\"sha256_source\":\"computed\",\"compat\":null,\"installed_at\":\"${at}\"}\n"
	mine = "https://github.com/Karakatiza666/roc"
	row = |id, text| { id, text }
	old = row("git-1111aaaa", Ok(meta(mine, "my-branch", "2026-10-09T23:59:59Z")))
	new = row("git-2222bbbb", Ok(meta(mine, "my-branch", "2026-10-10T00:00:00Z")))
	older_text = row("git-3333cccc", Ok(meta(mine, "my-branch", "2025-12-31T23:59:59Z")))
	other_repo = row("git-4444dddd", Ok(meta("https://github.com/roc-lang/roc", "my-branch", "2026-10-30T00:00:00Z")))
	other_ref = row("git-5555eeee", Ok(meta(mine, "my-branch2", "2026-10-30T00:00:00Z")))
	prefix_ref = row("git-6666ffff", Ok(meta(mine, "my-bran", "2026-10-30T00:00:00Z")))
	lost = row("git-7777aaaa", Err(NotFound))
	junk = row("git-8888bbbb", Ok("not json"))
	nightly = row("git-9999cccc", Ok("{\"format\":1,\"id\":\"nightly-2026-10-09-258ab27\",\"installed_at\":\"2026-10-31T00:00:00Z\"}\n"))
	no_time = row("git-aaaa0000", Ok("{\"format\":1,\"repo\":\"${mine}\",\"ref\":\"my-branch\"}\n"))
	bad_time = row("git-bbbb0000", Ok(meta(mine, "my-branch", "yesterday")))
	meta_without_sha = |repo, ref, at| "{\"format\":1,\"repo\":\"${repo}\",\"ref\":\"${ref}\",\"installed_at\":\"${at}\"}\n"
	pick = |rows| GitBuild.newest({ source: fork, rows })
	with_sha = |id, repo, ref, sha, at| row(id, Ok("{\"format\":1,\"id\":\"${id}\",\"repo\":\"${repo}\",\"sha\":\"${sha}\",\"ref\":\"${ref}\",\"installed_at\":\"${at}\"}\n"))
	by_branch = with_sha("git-dd03c09e", mine, "main", sha_a, "2026-10-11T00:00:00Z")
	by_text = with_sha("git-dd03c09f", mine, "dd03c09e", sha_a, "2026-10-12T00:00:00Z")
	other_sha = with_sha("git-cf42a741", mine, "dev", sha_b, "2026-10-30T00:00:00Z")
	foreign = with_sha("git-dd03c0aa", "https://github.com/roc-lang/roc", "main", sha_a, "2026-10-30T00:00:00Z")
	no_sha = row("git-dd03c0bb", Ok(meta_without_sha(mine, "main", "2026-10-30T00:00:00Z")))
	by_hex = |typed, rows| GitBuild.newest({ source: { ..fork, ref: typed }, rows })
	rows = [
		(pick([old, new]), Ok("git-2222bbbb")),
		(pick([new, old]), Ok("git-2222bbbb")),
		(pick([older_text, old]), Ok("git-1111aaaa")),
		(pick([old, other_repo, other_ref, prefix_ref, lost, junk, nightly, no_time, bad_time]), Ok("git-1111aaaa")),
		(pick([other_repo, other_ref, prefix_ref, lost, junk, nightly, no_time, bad_time]), Err(None)),
		(pick([]), Err(None)),
		(GitBuild.newest({ source: { ..fork, repo: "roc2" }, rows: [old, new] }), Err(None)),
		(GitBuild.newest({ source: { owner: "roc-lang", repo: "roc", ref: "my-branch" }, rows: [old, new, other_repo] }), Ok("git-4444dddd")),
		# Review Q6: a typed sha (7 to 40 lower case hex digits) also matches the full sha of a build, not only the typed ref text.
		(by_hex("dd03c09e", [by_branch, other_sha]), Ok("git-dd03c09e")),
		(by_hex("dd03c09", [other_sha, by_branch]), Ok("git-dd03c09e")),
		(by_hex(sha_a, [by_branch, other_sha]), Ok("git-dd03c09e")),
		(by_hex("dd03c09e", [by_branch, by_text]), Ok("git-dd03c09f")),
		(by_hex("dd03c09e", [by_text, by_branch]), Ok("git-dd03c09f")),
		(by_hex("dd03c0", [by_branch, other_sha]), Err(None)),
		(by_hex("dd03c0a", [by_branch, other_sha]), Err(None)),
		(by_hex("DD03C09E", [by_branch, other_sha]), Err(None)),
		(by_hex("dd03c09ex", [by_branch, other_sha]), Err(None)),
		(by_hex("dd03c09e", [foreign, no_sha, junk, lost]), Err(None)),
		(by_hex("main", [by_branch, other_sha]), Ok("git-dd03c09e")),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}
