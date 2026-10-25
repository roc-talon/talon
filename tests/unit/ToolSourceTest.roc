import lib.Args
import lib.Fail
import lib.JsonDoc
import lib.Mode
import lib.Roots
import lib.ToolGit
import lib.ToolInstall
import lib.ToolUpdate
import lib.ToolsJson

ToolSourceTest :: [].{}

# Slice 048 (docs/slices/048-tool-manage.md): `tln tool install --git`, `tln tool update` and `tln tool rebuild`. The expected value of each row is the design text or the slice file text, not the code. A wrong row prints with `dbg`. Texts that the design does not give are the proposals of the slice file (TW24).
# The Fx calls and the files are in the L2 cases `tests/commands/cases/tool/tg1-git`, `tu1-update` and `tr1-rebuild`.

commit : Str
commit = "dd03c09e5f1a2b3c4d5e6f708192a3b4c5d6e7f8"

foo_url : Str
foo_url = "https://github.com/acme/foo/releases/download/1.1.0/J3fdXfd44AGuuqZMdge6UxcjrCJBwHzF2uiQxbu2ZCnr.tar.zst"

t_foo : ToolsJson.Tool
t_foo = { key: "foo", name: "acme/foo", source: Release({ version: "1.1.0", url: foo_url }), path: Err(None), hashes: ["H1"], nightly: "nightly-2026-10-14-38a3029", target: "x64musl", sha256: "S1", libs: [], installed_at: "2026-10-15T12:00:00Z" }

t_g : ToolsJson.Tool
t_g = { key: "g", name: "acme/g", source: Git({ commit, ref: "main" }), path: Ok("apps/cli"), hashes: ["H2"], nightly: "nightly-2026-09-01-abcdef0", target: "x64musl", sha256: "S2", libs: [], installed_at: "2026-09-02T08:00:00Z" }

with_ref : Str -> ToolsJson.Tool
with_ref = |ref| { ..t_g, source: Git({ commit, ref }) }

# R-T23 R-SL8 R-SL10 R-SL11 R-SL13 R-FL12 R-FL14 R-SE12 R-T28 R-T6: the line of `tool install` with a git source. `--git owner/app@ref` (every selector is a git ref, also `latest` and `1.4.0`: R-SL13); `--path` is a directory of the source; a sha selector (7 digits or more, hex) needs no `--git` (R-SL10). A line that is no git source goes to the
# release install (`NotGit`). A `--path` with no git source, a short name, a name that is not owner/repo, no ref, and `--resolve` (a later slice) are failures of kind usage (exit 2). A `--path` is a relative dir with no `..`; a `/` at its end goes (R-SE12).
expect {
	read = |words| match Args.parse(words) {
		Ok(args) => match ToolGit.read(args) {
			Ok(Ok(plan)) => {
				path = match plan.path {
					Ok(p) => p
					Err(None) => "-"
				}
				as_name = match plan.as_name {
					Ok(n) => n
					Err(Unset) => "-"
				}
				roc = match plan.roc {
					Auto => "auto"
					Pinned => "pinned"
					Installed => "installed"
				}
				"${plan.source.owner}/${plan.source.repo}@${plan.source.ref} path=${path} as=${as_name} roc=${roc}"
			}
			Ok(Err(NotGit)) => "not git"
			Err(fail) => fail.line()
		}
		Err(stop) => "parse: ${stop.fail.line()}"
	}
	line = |text| "tln: error[usage]: ${text}"
	bad_path = |text| line("--path '${text}' must be a directory inside the repository: a relative path with no '..'")
	rows = [
		(read(["tool", "install", "--git", "acme/foo@main"]), "acme/foo@main path=- as=- roc=auto"),
		(read(["tool", "install", "--git", "acme/foo@v1.2-beta"]), "acme/foo@v1.2-beta path=- as=- roc=auto"),
		(read(["tool", "install", "--git", "acme/foo@1.4.0"]), "acme/foo@1.4.0 path=- as=- roc=auto"),
		(read(["tool", "install", "--git", "acme/foo@latest"]), "acme/foo@latest path=- as=- roc=auto"),
		(read(["tool", "install", "--git", "acme/foo@dd03c09e"]), "acme/foo@dd03c09e path=- as=- roc=auto"),
		(read(["tool", "install", "--git", "acme/foo@main", "--path", "apps/cli"]), "acme/foo@main path=apps/cli as=- roc=auto"),
		(read(["tool", "install", "--git", "acme/foo@main", "--path", "apps/cli/"]), "acme/foo@main path=apps/cli as=- roc=auto"),
		(read(["tool", "install", "--git", "acme/foo@main", "--as", "q", "--roc", "pinned"]), "acme/foo@main path=- as=q roc=pinned"),
		(read(["tool", "install", "acme/foo@dd03c09e"]), "acme/foo@dd03c09e path=- as=- roc=auto"),
		(read(["tool", "install", "acme/foo@dd03c09e", "--path", "sub", "--roc", "installed"]), "acme/foo@dd03c09e path=sub as=- roc=installed"),
		(read(["tool", "install", "acme/foo"]), "not git"),
		(read(["tool", "install", "acme/foo@1.1.0"]), "not git"),
		(read(["tool", "install", "acme/foo@1"]), "not git"),
		(read(["tool", "install", "foo"]), "not git"),
		(read(["tool", "install"]), "not git"),
		(read(["tool", "install", "acme/foo", "acme/bar"]), "not git"),
		(read(["tool", "install", "--git"]), line("tln tool install --git needs one app: owner/app@ref")),
		(read(["tool", "install", "--git", "acme/foo@main", "acme/bar@main"]), line("tln tool install --git takes one app, got 2")),
		(read(["tool", "install", "--git", "acme/foo"]), line("'acme/foo' has no ref: use owner/repo@ref")),
		(read(["tool", "install", "--git", "foo@main"]), line("--git takes a GitHub repository as owner/repo, not 'foo'")),
		(read(["tool", "install", "--git", "git.example.com/a/b@main"]), line("--git takes a GitHub repository as owner/repo, not 'git.example.com/a/b'")),
		(read(["tool", "install", "--git", "acme/foo@main", "--resolve"]), line("tln tool install --resolve is not built yet")),
		(read(["tool", "install", "acme/foo", "--path", "sub"]), line("tln tool install --path needs a git ref: --git owner/app@ref")),
		(read(["tool", "install", "--git", "acme/foo@main", "--path", "../x"]), bad_path("../x")),
		(read(["tool", "install", "--git", "acme/foo@main", "--path", "/abs"]), bad_path("/abs")),
		(read(["tool", "install", "--git", "acme/foo@main", "--path", "a/../b"]), bad_path("a/../b")),
		(read(["tool", "install", "--git", "acme/foo@main", "--path", "/"]), bad_path("/")),
		(read(["tool", "install", "--git", "acme/foo@main", "--roc", "fast"]), line("--roc must be pinned or installed, not 'fast'")),
		(read(["tool", "install", "--git", "acme/foo@main", "--as", "_x"]), line("'_x' is not a binary name: use letters, digits, '.', '_' and '-', and start with a letter or a digit")),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-T28 R-T26 R-T27 R-ST15: the binary name of a git install: `--as`, else the key that the app has already (R-T27: a git install replaces a release tool under its key), else the repo name.
expect {
	plan_of = |words| match Args.parse(words) {
		Ok(args) => match ToolGit.read(args) {
			Ok(Ok(plan)) => Ok(plan)
			_ => Err(Bad)
		}
		Err(_) => Err(Bad)
	}
	key = |words, installed| match plan_of(words) {
		Ok(plan) => ToolGit.key({ plan, installed })
		Err(Bad) => "bad"
	}
	rows = [
		(key(["tool", "install", "--git", "acme/foo@main"], Err(None)), "foo"),
		(key(["tool", "install", "--git", "acme/foo@main"], Ok("q")), "q"),
		(key(["tool", "install", "--git", "acme/foo@main", "--as", "z"], Ok("q")), "z"),
		(key(["tool", "install", "--git", "acme/foo@main", "--as", "z"], Err(None)), "z"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-T26 R-T27 R-B10 R-T4 (D-G3, the choice of the slice file): is the installed tool enough for a git install? A git tool with the commit of the ref now: keep it (no build, the text is its source text). A git tool with another commit, a release tool (R-T27: the source kind must be equal) and no tool: build.
# `source_text` is `git <ref>@<8 digits of the commit>` (the design shows `dd03c09e`, R-T24).
expect {
	entry = |source| Ok({ key: "g", name: "acme/g", source })
	other = "1111111111111111111111111111111111111111"
	rows = [
		(ToolGit.reuse({ installed: entry(Git({ commit, ref: "main" })), sha: commit }), Keep("git main@dd03c09e")),
		(ToolGit.reuse({ installed: entry(Git({ commit, ref: "v1" })), sha: commit }), Keep("git v1@dd03c09e")),
		(ToolGit.reuse({ installed: entry(Git({ commit: other, ref: "main" })), sha: commit }), Build),
		(ToolGit.reuse({ installed: entry(Release({ version: "1.1.0", url: "u" })), sha: commit }), Build),
		(ToolGit.reuse({ installed: Err(None), sha: commit }), Build),
	]
	text_rows = [
		(ToolGit.source_text({ ref: "main", sha: commit }), "git main@dd03c09e"),
		(ToolGit.source_text({ ref: "v1.2", sha: "abc" }), "git v1.2@abc"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == [] and text_rows.all(|(got, want)| got == want)
}

# R-T23 R-CC1 R-CC2 R-R3 R-R7 R-SE12: the paths of one git source. The temp dir is `<cache>/talon/tmp/<hex>`; the archive, the extracted source (no top dir) and the build output are in it, so one `delete!` of the temp dir cleans all (R-CC2). `--path` selects the app dir inside the source. The file that the command reads is `<dir>/main.roc`.
expect {
	roots = Roots.{ cache: "/c/roc", pkgs: "/c/roc/packages", build: "/c/roc", config: "/f/talon", data: "/d/talon" }
	plain = ToolGit.layout({ roots, hex: "0123456789abcdef", path: Err(None) })
	sub = ToolGit.layout({ roots, hex: "0123456789abcdef", path: Ok("apps/cli") })
	rows = [
		(plain.temp, "/c/roc/talon/tmp/0123456789abcdef"),
		(plain.archive, "/c/roc/talon/tmp/0123456789abcdef/source.tar.gz"),
		(plain.src, "/c/roc/talon/tmp/0123456789abcdef/src"),
		(plain.dir, "/c/roc/talon/tmp/0123456789abcdef/src"),
		(plain.file, "/c/roc/talon/tmp/0123456789abcdef/src/main.roc"),
		(sub.temp, "/c/roc/talon/tmp/0123456789abcdef"),
		(sub.src, "/c/roc/talon/tmp/0123456789abcdef/src"),
		(sub.dir, "/c/roc/talon/tmp/0123456789abcdef/src/apps/cli"),
		(sub.file, "/c/roc/talon/tmp/0123456789abcdef/src/apps/cli/main.roc"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-DA3 R-SE12 R-T23 R-T10 (the texts are proposals, TW24): the failures of a git install. wget is exit 18 (kind environment): a source archive has no published hash, and only curl refuses a redirect to http://. No `main.roc` in the app dir and a `main.roc` that is no app are kind usage (exit 2).
expect {
	source = { owner: "acme", repo: "foo", ref: "main" }
	rows = [
		(ToolGit.needs_curl({}).line(), "tln: error[environment]: tln tool install --git needs curl, but the download program is wget: a source archive has no published hash, and only curl refuses a redirect to http:// (R-DA3)"),
		(ToolGit.no_main({ source, path: Err(None) }).line(), "tln: error[usage]: acme/foo@main has no main.roc at its top. Use --path <dir> for an app in a subdirectory."),
		(ToolGit.no_main({ source, path: Ok("apps/cli") }).line(), "tln: error[usage]: acme/foo@main has no main.roc in apps/cli"),
		(ToolGit.not_app(source).line(), "tln: error[usage]: main.roc of acme/foo@main is not an app, so tln tool install cannot build it"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-J3 R-J4 R-OUT4 (the `data` is a proposal, TW24): the `data` of `tool install --git --json`: tool, name, source `git`, commit, ref, path (only with `--path`), how, previous (the old source text for `replaced`), bin, then for a build nightly, target, sha256, entry. A present tool has no build keys.
expect {
	built = Ok({ nightly: "nightly-2026-10-14-38a3029", target: "x64musl", sha256: "aa", entry: HardLink })
	data = |how, path, b| JsonDoc.render(ToolGit.data({ how, key: "foo", name: "acme/foo", ref: "main", commit, path, bin: "/h/.local/bin/foo", built: b }))
	head = "\"tool\":\"foo\",\"name\":\"acme/foo\",\"source\":\"git\",\"commit\":\"${commit}\",\"ref\":\"main\""
	rows = [
		(data(Installed, Err(None), built), "{${head},\"how\":\"installed\",\"previous\":null,\"bin\":\"/h/.local/bin/foo\",\"nightly\":\"nightly-2026-10-14-38a3029\",\"target\":\"x64musl\",\"sha256\":\"aa\",\"entry\":\"hard_link\"}"),
		(data(Replaced("1.0.0"), Ok("apps/cli"), built), "{${head},\"path\":\"apps/cli\",\"how\":\"replaced\",\"previous\":\"1.0.0\",\"bin\":\"/h/.local/bin/foo\",\"nightly\":\"nightly-2026-10-14-38a3029\",\"target\":\"x64musl\",\"sha256\":\"aa\",\"entry\":\"hard_link\"}"),
		(data(Present, Err(None), Err(None)), "{${head},\"how\":\"present\",\"previous\":null,\"bin\":\"/h/.local/bin/foo\"}"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-T24 R-SL10 R-B2: how `tool update` treats a tool. A release tool: the newest release (as `tool install app@latest`). A git tool whose typed ref is a sha (7 hex digits or more, R-SL10): a commit, no change. Any other git ref (a branch, a tag): the head of the ref now (D-U1, a tag behaves like a branch).
# `moved`: the commit now against the commit of the tool.
expect {
	way = |ref| ToolUpdate.way(with_ref(ref))
	other = "1111111111111111111111111111111111111111"
	rows = [
		(ToolUpdate.way(t_foo), Release),
		(way("main"), Branch),
		(way("v1.2"), Branch),
		(way("1.4.0"), Branch),
		(way("dd03c09"), Commit),
		(way("dd03c09e"), Commit),
		(way("DD03C09E"), Commit),
		(way("1234567"), Commit),
		(way("dd03c0"), Branch),
		(way("decade"), Branch),
		(way("dd03c09g"), Branch),
		(ToolUpdate.moved({ tool: t_g, sha: commit }), Same),
		(ToolUpdate.moved({ tool: t_g, sha: other }), Moved),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-T24 R-T7 R-T5 R-OUT2 R-J3 R-J4 R-OUT4 (the texts and the `data` are proposals, TW24, except `pinned to commit dd03c09e` of the design, R-T24): the lines of `tool update` and `tool rebuild` (one line for each tool, the `<key>: ` prefix of the pinned line is the proposal), and the `data` of `--json`: `tools`, one object for each tool in the order of the processing.
expect {
	outcomes = [
		{ tool: "foo", name: "acme/foo", how: Updated, from: Ok("1.1.0"), to: "1.2.0" },
		{ tool: "g", name: "acme/g", how: Pinned, from: Err(None), to: "git main@dd03c09e" },
		{ tool: "h", name: "acme/h", how: UpToDate, from: Err(None), to: "0.3.0" },
		{ tool: "foo", name: "acme/foo", how: Rebuilt, from: Err(None), to: "1.1.0" },
	]
	rows = [
		(ToolUpdate.pinned_text({ key: "g", commit }), "g: pinned to commit dd03c09e"),
		(ToolUpdate.up_to_date_text(t_foo), "foo 1.1.0 is up to date"),
		(ToolUpdate.up_to_date_text(t_g), "g git main@dd03c09e is up to date"),
		(ToolUpdate.updated_text({ tool: t_foo, new: "1.2.0" }), "updated foo 1.1.0 to 1.2.0 (acme/foo)"),
		(ToolUpdate.updated_text({ tool: t_g, new: "git main@1a2b3c4d" }), "updated g git main@dd03c09e to git main@1a2b3c4d (acme/g)"),
		(ToolUpdate.rebuilt_text({ tool: t_foo }), "rebuilt foo 1.1.0 (acme/foo) with nightly-2026-10-14-38a3029"),
		(ToolUpdate.rebuilt_text({ tool: t_g }), "rebuilt g git main@dd03c09e (acme/g) with nightly-2026-09-01-abcdef0"),
		(JsonDoc.render(ToolUpdate.data([])), "{\"tools\":[]}"),
		(JsonDoc.render(ToolUpdate.data(outcomes)), "{\"tools\":[{\"tool\":\"foo\",\"name\":\"acme/foo\",\"how\":\"updated\",\"from\":\"1.1.0\",\"to\":\"1.2.0\"},{\"tool\":\"g\",\"name\":\"acme/g\",\"how\":\"pinned\",\"from\":null,\"to\":\"git main@dd03c09e\"},{\"tool\":\"h\",\"name\":\"acme/h\",\"how\":\"up_to_date\",\"from\":null,\"to\":\"0.3.0\"},{\"tool\":\"foo\",\"name\":\"acme/foo\",\"how\":\"rebuilt\",\"from\":null,\"to\":\"1.1.0\"}]}"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-T7 R-T5 R-T23 R-SE12 (the texts are proposals, TW24): where `tool rebuild` gets the source, as the manifest has it. A release tool: the bundle at `source.url` (its hash is the last part of the URL). A git tool: the archive of the commit of the repo (`owner/repo` is the full name), with the `--path` of the tool. A URL that is no release URL and a git name that is not
# owner/repo are failures of kind input (exit 19) that name the tool.
expect {
	show = |tool| match ToolUpdate.origin(tool) {
		Ok(Bundle({ url, hash })) => "bundle ${url} ${hash}"
		Ok(Archive({ owner, repo, commit: sha, path })) => "archive ${owner} ${repo} ${sha} ${Str.inspect(path)}"
		Err(fail) => fail.line()
	}
	rows = [
		(show(t_foo), "bundle ${foo_url} J3fdXfd44AGuuqZMdge6UxcjrCJBwHzF2uiQxbu2ZCnr"),
		(show(t_g), "archive acme g ${commit} Ok(\"apps/cli\")"),
		(show({ ..t_g, path: Err(None) }), "archive acme g ${commit} Err(None)"),
		(show({ ..t_foo, source: Release({ version: "1.1.0", url: "https://x/foo.tar.zst" }) }), "tln: error[input]: foo: the source url https://x/foo.tar.zst is not a release url"),
		(show({ ..t_g, name: "host/a/b" }), "tln: error[input]: g: the name host/a/b is not owner/repo, so the source archive is not known"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-T25 R-DL1 R-DL2 R-T5: the compilers that the command may have to download: the distinct ids of the compilers of the tools that are built (the pin of the new header for `update`, the recorded compiler for `rebuild`) that are not installed, in the order of the tools. A compiler that is installed is not counted. Evidence is not counted (it
# can happen that the pin is not needed, R-DL1: the count is the most that can be downloaded).
expect {
	a = "nightly-2026-10-14-38a3029"
	b = "nightly-2026-09-01-abcdef0"
	rows = [
		(ToolUpdate.downloads({ pins: [a, b, a], installed: [] }), [a, b]),
		(ToolUpdate.downloads({ pins: [a, b, a], installed: [a] }), [b]),
		(ToolUpdate.downloads({ pins: [b, a], installed: [a] }), [b]),
		(ToolUpdate.downloads({ pins: [a, b], installed: [b, a] }), []),
		(ToolUpdate.downloads({ pins: [], installed: [a] }), []),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-T25 R-DL1 R-DL2 R-DL3 R-DL4 R-DL5 R-NM5 R-NM9 R-HF1 (one decision for the whole command; the texts are proposals, TW24): what the command does for the downloads of all tools. A compiler that is no nightly id cannot be downloaded: `the compiler <id> is not installed. Run: tln roc install <id>.` (exit 13). `TALON_AUTO_INSTALL=no` with no `--yes`: refused (exit 13).
# `--yes` or `TALON_AUTO_INSTALL=yes`: download, no prompt. A person at a terminal: one prompt for all downloads. No terminal known yet: `NeedTty` (one `tty!` call). No person and no answer: exit 13, the text names `--yes` (`tool update` has no `--allow-downloads`, R-FL12).
expect {
	a = "nightly-2026-10-14-38a3029"
	b = "nightly-2026-09-01-abcdef0"
	want = |ids, auto, yes, mode| match ToolUpdate.want({ ids, auto, yes, mode }) {
		Download => "download"
		Ask => "ask"
		NeedTty => "need-tty"
		Stop(fail) => fail.line()
	}
	consent = |text| "tln: error[consent]: ${text}"
	rows = [
		(want([a], Ask, Bool.False, Interactive), "ask"),
		(want([a, b], Ask, Bool.False, Interactive), "ask"),
		(want([a], Ask, Bool.False, NeedsTty), "need-tty"),
		(want([a], Ask, Bool.False, NonInteractive), consent("1 compiler download is needed (${a}). Pass --yes or set TALON_AUTO_INSTALL=yes.")),
		(want([a, b], Ask, Bool.False, NonInteractive), consent("2 compiler downloads are needed (${a}, ${b}). Pass --yes or set TALON_AUTO_INSTALL=yes.")),
		(want([a, b], Ask, Bool.True, NonInteractive), "download"),
		(want([a], Yes, Bool.False, NonInteractive), "download"),
		(want([a], Yes, Bool.False, Interactive), "download"),
		(want([a], No, Bool.False, Interactive), consent("the compiler ${a} is not installed. TALON_AUTO_INSTALL=no refuses the download. Run: tln roc install ${a}, pass --yes, or set TALON_AUTO_INSTALL=yes.")),
		(want([a], No, Bool.True, NonInteractive), "download"),
		(want(["git-abc123"], Ask, Bool.True, Interactive), consent("the compiler git-abc123 is not installed. Run: tln roc install git-abc123.")),
		(want([a, "link-mine"], Yes, Bool.False, NonInteractive), consent("the compiler link-mine is not installed. Run: tln roc install link-mine.")),
	]
	bad = rows.keep_if(|(got, want_row)| got != want_row)
	dbg bad
	bad == []
}

# R-ST6 R-ST11 (the text is a proposal, TW24): the failure of `update` and `rebuild` for a bin dir entry that tln did not write names the file and says to move or remove it. It does not name `--as` (these commands have no such flag).
# R-T25 R-DL1 R-NR2 R-NR6 R-NM5 R-NM6 (the texts are proposals, TW24): the one prompt of the command for the downloads of all tools: yes/no, default yes, `Required` (a non-interactive run needs `--yes` or `TALON_AUTO_INSTALL=yes`). The question has the count of the compilers, the sum of the sizes and the ids. A No answer is a failure of kind consent (exit 13) and no tool is changed.
expect {
	a = "nightly-2026-10-14-38a3029"
	b = "nightly-2026-09-01-abcdef0"
	one = ToolUpdate.prompt({ ids: [a], size: 73900000 })
	two = ToolUpdate.prompt({ ids: [a, b], size: 147400000 })
	rows = [
		(one.id, "tool-download"),
		(one.question, "Download 1 compiler, 73.9 MB: ${a}?"),
		(two.question, "Download 2 compilers, 147.4 MB: ${a}, ${b}?"),
		(one.subject, "the download of 1 compiler"),
		(two.subject, "the download of 2 compilers"),
		((one.answer_line)(Yes), "downloading 1 compiler (73.9 MB)"),
		((two.answer_line)(No), "no download of 2 compilers"),
		(Str.inspect(one.kind), "Required([\"TALON_AUTO_INSTALL=yes\"])"),
		(Str.inspect(one.shape), "YesNo"),
		(Str.inspect(one.default), "Yes"),
		(ToolUpdate.foreign_failure("/h/.local/bin/fe").line(), "tln: error[usage]: /h/.local/bin/fe is not a file that tln wrote, so tln does not replace it. Move or remove that file, then run the command again."),
		(ToolUpdate.declined([a]).line(), "tln: error[consent]: the download of ${a} was declined. No tool was changed."),
		(ToolUpdate.declined([a, b]).line(), "tln: error[consent]: the download of ${a}, ${b} was declined. No tool was changed."),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}
