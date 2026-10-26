import lib.Args
import lib.Clock
import lib.JsonDoc
import lib.TalonUpdate
import lib.ToolUpdate
import lib.ToolsJson

TalonUpdateTest :: [].{}

# Slice 050 (docs/slices/050-tool-update-talon.md): `tln tool update talon`, the pure decisions and the entry `talon` of `tools.json`. The expected value of each row is the design text (CLI 6.5, 6.7) or the slice file text, not the code. A wrong row prints with `dbg`.
# Texts that the design does not give are the proposals of the slice file (TW24). The `Fx` calls and the files are in the L2 cases `tests/commands/cases/tool/ts1-update` to `ts6-source` and the L3 case `tests/scenarios/tools/ts1-update-talon`.

pub : Str -> U64
pub = |text| Clock.parse_utc(text) ?? 0

# A release of the list: a binary and a sha256sums.txt, published at `at`.
mk : Str, Str -> TalonUpdate.Release
mk = |version, at| { version, tag: "v${version}", published_at: pub(at), bin: Ok({ url: "https://h/v${version}/tln-x64musl", size: 100 }), sums: Ok("https://h/v${version}/sha256sums.txt") }

# R-IS2 R-S2: the name of the release asset for this machine (the targets of basic-cli, `BuildSkip.target`): `tln-<target>`, with `.exe` on Windows.
expect {
	name = |os, target| TalonUpdate.asset_name({ os, target })
	rows = [
		(name(Linux, "x64musl"), "tln-x64musl"),
		(name(Linux, "arm64musl"), "tln-arm64musl"),
		(name(Macos, "x64mac"), "tln-x64mac"),
		(name(Macos, "arm64mac"), "tln-arm64mac"),
		(name(Windows, "x64win"), "tln-x64win.exe"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-DI3 R-DI10 R-IS2: the releases of the pages of the GitHub list. A draft, a prerelease and a tag that is not `v` and 3 numbers (`nightly`, `v0.3.2-rc1`, `0.3.2`, `v1.2`) are left out, with no check of their other fields. A release with no asset of this machine, or no sha256sums.txt, is in the list
# (`pick` and the command decide). Only an asset with exactly the name counts. The order of the pages and of the releases stays. A page that is not an array of objects, a release with no text `tag_name`, and a release that is kept and has no readable `published_at` are `BadPage(n)` with `n` 1-based.
expect {
	asset = |tag, name| "{\"name\":\"${name}\",\"size\":10,\"browser_download_url\":\"https://h/${tag}/${name}\"}"
	rel_text = |tag, at, assets| "{\"tag_name\":\"${tag}\",\"draft\":false,\"prerelease\":false,\"published_at\":\"${at}\",\"assets\":[${Str.join_with(assets, ",")}]}"
	both = |tag| [asset(tag, "tln-x64musl"), asset(tag, "tln-arm64musl"), asset(tag, "sha256sums.txt")]
	list = |pages| match TalonUpdate.releases({ pages, asset: "tln-x64musl" }) {
		Ok(found) => Ok(found.map(|r| "${r.tag} ${r.version} ${r.published_at.to_str()} ${Str.inspect(r.bin)} ${Str.inspect(r.sums)}"))
		Err(BadPage(n)) => Err(n)
	}
	bin_of = |tag| Str.inspect(Ok({ url: "https://h/${tag}/tln-x64musl", size: 10.U64 }))
	sums_of = |tag| Str.inspect(Ok("https://h/${tag}/sha256sums.txt"))
	full = |tag, at| "${tag} ${tag.drop_prefix("v")} ${pub(at).to_str()} ${bin_of(tag)} ${sums_of(tag)}"
	skipped = "{\"tag_name\":\"v0.9.0\",\"draft\":true,\"published_at\":\"x\"},{\"tag_name\":\"v0.9.1\",\"prerelease\":true},{\"tag_name\":\"nightly\"},{\"tag_name\":\"v0.3.2-rc1\"},{\"tag_name\":\"0.3.2\"},{\"tag_name\":\"v1.2\"}"
	rows = [
		(list(["[${rel_text("v0.3.4", "2026-10-01T12:00:00Z", both("v0.3.4"))},${skipped},${rel_text("v0.3.1", "2026-09-01T00:00:00Z", both("v0.3.1"))}]"]), Ok([full("v0.3.4", "2026-10-01T12:00:00Z"), full("v0.3.1", "2026-09-01T00:00:00Z")])),
		(list(["[${rel_text("v0.3.4", "2026-10-01T12:00:00Z", both("v0.3.4"))}]", "[${rel_text("v0.3.1", "2026-09-01T00:00:00Z", both("v0.3.1"))}]"]), Ok([full("v0.3.4", "2026-10-01T12:00:00Z"), full("v0.3.1", "2026-09-01T00:00:00Z")])),
		(list(["[${rel_text("v0.3.4", "2026-10-01T12:00:00Z", [asset("v0.3.4", "tln-arm64musl"), asset("v0.3.4", "tln-x64musl.sig")])}]"]), Ok(["v0.3.4 0.3.4 ${pub("2026-10-01T12:00:00Z").to_str()} Err(NoAsset) Err(NoSums)"])),
		(list(["[${rel_text("v0.3.4", "2026-10-01T12:00:00Z", [asset("v0.3.4", "tln-x64musl")])}]"]), Ok(["v0.3.4 0.3.4 ${pub("2026-10-01T12:00:00Z").to_str()} ${bin_of("v0.3.4")} Err(NoSums)"])),
		(list(["[]"]), Ok([])),
		(list([]), Ok([])),
		(list(["{\"tag_name\":\"v0.3.4\"}"]), Err(1)),
		(list(["[]", "not json"]), Err(2)),
		(list(["[1]"]), Err(1)),
		(list(["[{\"draft\":false}]"]), Err(1)),
		(list(["[{\"tag_name\":\"v0.3.4\",\"published_at\":\"yesterday\",\"assets\":[]}]"]), Err(1)),
		(list(["[{\"tag_name\":\"v0.3.4\",\"assets\":[]}]"]), Err(1)),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-T9 R-C7 R-S2 R-S4: the release to install. A release that has no asset of this machine is not a candidate. The ones that are not old enough (`published_at + min_age <= now`) are not candidates. The highest version of the others, by numbers (`0.10.0` is above `0.9.0`) and not by the time, is `Newer` when it is above the installed version.
# The same or a lower version is `Current(<the newest candidate>)`: no downgrade. No release with the asset is a usage failure, and so is no release that is old enough (the text of `tool install`). A tie of 2 releases with one version gives the first.
expect {
	now = pub("2026-10-15T12:00:00Z")
	day = 86400
	show = |list, current| match TalonUpdate.pick({ list, now, min_age: 2 * day, current, asset: "tln-x64musl" }) {
		Ok(Newer(r)) => "newer ${r.version}"
		Ok(Current(r)) => "current ${r.version}"
		Err(fail) => fail.line()
	}
	no_asset = |version, at| { ..mk(version, at), bin: Err(NoAsset) }
	a = mk("0.3.1", "2026-09-01T00:00:00Z")
	b = mk("0.3.4", "2026-10-01T12:00:00Z")
	young = mk("0.3.5", "2026-10-14T12:00:00Z")
	edge = mk("0.3.6", "2026-10-13T12:00:00Z")
	rows = [
		(show([a, b], "0.3.1"), "newer 0.3.4"),
		(show([young, b, a], "0.3.1"), "newer 0.3.4"),
		(show([a, b, young], "0.3.4"), "current 0.3.4"),
		(show([a, b, edge], "0.3.4"), "newer 0.3.6"),
		(show([a, b], "0.3.9"), "current 0.3.4"),
		(show([a, b], "0.0.0"), "newer 0.3.4"),
		(show([mk("0.9.0", "2026-01-01T00:00:00Z"), mk("0.10.0", "2026-02-01T00:00:00Z"), mk("0.2.0", "2026-03-01T00:00:00Z")], "0.1.0"), "newer 0.10.0"),
		(show([mk("0.9.0", "2026-03-01T00:00:00Z"), mk("0.10.0", "2026-01-01T00:00:00Z")], "0.1.0"), "newer 0.10.0"),
		(show([b, mk("0.4.0", "2026-09-01T00:00:00Z")], "0.3.0"), "newer 0.4.0"),
		(show([mk("1.0.0", "2026-09-01T00:00:00Z"), mk("0.9.9", "2026-09-02T00:00:00Z")], "0.9.0"), "newer 1.0.0"),
		(show([a, b], "0.4.0"), "current 0.3.4"),
		(show([a, no_asset("0.3.7", "2026-09-20T00:00:00Z")], "0.3.0"), "newer 0.3.1"),
		(show([no_asset("0.3.7", "2026-09-20T00:00:00Z")], "0.3.0"), "tln: error[usage]: roc-talon/talon has no release with tln-x64musl"),
		(show([], "0.3.0"), "tln: error[usage]: roc-talon/talon has no release with tln-x64musl"),
		(show([young], "0.3.0"), "tln: error[usage]: no release of roc-talon/talon is old enough for min-release-age"),
		(show([young, no_asset("0.3.7", "2026-09-20T00:00:00Z")], "0.3.0"), "tln: error[usage]: no release of roc-talon/talon is old enough for min-release-age"),
		(show([{ ..mk("0.3.4", "2026-10-01T12:00:00Z"), sums: Err(NoSums) }], "0.3.0"), "newer 0.3.4"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-S2 R-T4: the installed version: a prebuilt entry gives its version, a source build gives the version of its tag ref (`v0.3.2` is `0.3.2`), any other ref (a branch) and no entry give the version of the running tln.
expect {
	talon = |source| Ok({ source, hashes: [], nightly: "", target: "x64musl", sha256: "S", libs: [], installed_at: "2026-10-15T12:00:00Z" })
	cur = |entry| TalonUpdate.current({ entry, running: "0.0.0" })
	rows = [
		(cur(talon(Prebuilt({ version: "0.3.1", url: "u" }))), "0.3.1"),
		(cur(talon(Git({ commit: "c", ref: "v0.3.2", path: Ok("cli") }))), "0.3.2"),
		(cur(talon(Git({ commit: "c", ref: "main", path: Ok("cli") }))), "0.0.0"),
		(cur(talon(Git({ commit: "c", ref: "v1.2", path: Err(None) }))), "0.0.0"),
		(cur(Err(None)), "0.0.0"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-S1 R-SE13 R-DA4: the sha256 of a file in sha256sums.txt, and the check of the download. A line is 64 lower case hex digits, white space, then the name (`*` before the name is the binary mode of `sha256sum`; `\r\n` ends a line is read as a line end). The first line with the name wins. A line in another
# form (a short digest, upper case digits, no space, an other name, a name that only starts like it) is not a line of that file. A difference is kind integrity (exit 16): the text names the file, the release, both sha256 and says that tln is not changed. The 2 failures of the checksum file are integrity too.
expect {
	h1 = Str.repeat("a", 64)
	h2 = Str.repeat("b", 64)
	h3 = Str.repeat("c", 64)
	want = |sums| match TalonUpdate.expected_sha({ sums, name: "tln-x64musl" }) {
		Ok(sha) => sha
		Err(NotListed) => "none"
	}
	check = |got| match TalonUpdate.check_download({ tag: "v0.3.4", name: "tln-x64musl", want: h1, got }) {
		Ok(_) => "ok"
		Err(fail) => fail.line()
	}
	rows = [
		(want("${h1}  tln-x64musl\n${h2}  tln-arm64musl\n"), h1),
		(want("${h2}  tln-arm64musl\n${h1}  tln-x64musl\n"), h1),
		(want("${h1} *tln-x64musl\n"), h1),
		(want("${h1}  tln-x64musl"), h1),
		(want("${h1}  tln-x64musl\r\n${h2}  tln-arm64musl\r\n"), h1),
		(want("${h1}\ttln-x64musl\n"), h1),
		(want("${h1}  tln-x64musl\n${h2}  tln-x64musl\n"), h1),
		(want("${h2}  tln-arm64musl\n${h3}  tln-x64musl.sig\n${h3}  tln-x64musl-old\n"), "none"),
		(want("${Str.repeat("a", 63)}  tln-x64musl\n"), "none"),
		(want("${Str.repeat("A", 64)}  tln-x64musl\n"), "none"),
		(want("${h1}tln-x64musl\n"), "none"),
		(want(""), "none"),
		(check(h1), "ok"),
		(check(h2), "tln: error[integrity]: tln-x64musl of roc-talon/talon v0.3.4: the sha256 is ${h2}, but sha256sums.txt says ${h1}. tln is not changed."),
		(TalonUpdate.unlisted({ tag: "v0.3.4", name: "tln-x64musl" }).line(), "tln: error[integrity]: sha256sums.txt of v0.3.4 does not list tln-x64musl, so tln cannot check it. tln is not changed."),
		(TalonUpdate.missing({ tag: "v0.3.4", name: "tln-x64musl" }).line(), "tln: error[integrity]: the release v0.3.4 of roc-talon/talon has no sha256sums.txt, so tln cannot check tln-x64musl. tln is not changed."),
	]
	bad = rows.keep_if(|(got, want_text)| got != want_text)
	dbg bad
	bad == []
}

# R-S3 R-HF2: `tln --version` on the new file. A file that starts and exits with 0 is `Ok` (the output is not read, question Q-V1). Any other end is kind internal (exit 1) with the cause (`exit <n>`, `signal <n>`, `not started: <text>`) and the words that the old tln stays. The executable bit is `chmod 0755 <file>` on Linux and macOS, and not needed on Windows.
expect {
	check = |ended| match TalonUpdate.version_check({ version: "0.3.4", ended }) {
		Ok(_) => "ok"
		Err(fail) => fail.line()
	}
	chmod = |os| Str.inspect(TalonUpdate.chmod_command({ os, file: "/d/bin/tln.0123456789abcdef.tmp" }))
	rows = [
		(check(Exited(0)), "ok"),
		(check(Exited(3)), "tln: error[internal]: the new tln 0.3.4 does not start (exit 3). The old tln stays."),
		(check(Signaled(11)), "tln: error[internal]: the new tln 0.3.4 does not start (signal 11). The old tln stays."),
		(check(NotStarted("exec format error")), "tln: error[internal]: the new tln 0.3.4 does not start (not started: exec format error). The old tln stays."),
		(chmod(Linux), "Ok([\"chmod\", \"0755\", \"/d/bin/tln.0123456789abcdef.tmp\"])"),
		(chmod(Macos), "Ok([\"chmod\", \"0755\", \"/d/bin/tln.0123456789abcdef.tmp\"])"),
		(chmod(Windows), "Err(NotNeeded)"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-ST9 R-ST6 R-ST11 R-ST13 R-ST14: the entries that the update makes again. `tln` and `roc` are 2 names of one file (with `.exe` on Windows). A `tln` that is not Talon's is exit 2 before the download (the path is named). A `roc` that is not Talon's stays (R-ST6) with a warning that names `tln setup --replace-roc`
# (question Q-E1). Two entries of Talon give both names, `tln` first.
expect {
	plan = |os, tln, roc| match TalonUpdate.entries({ os, bin: "/h/.local/bin", tln, roc }) {
		Ok(done) => "make ${Str.join_with(done.make, ",")} warnings ${Str.join_with(done.warnings, "|")}"
		Err(fail) => fail.line()
	}
	rows = [
		(plan(Linux, Make, Make), "make tln,roc warnings "),
		(plan(Macos, Make, Make), "make tln,roc warnings "),
		(plan(Windows, Make, Make), "make tln.exe,roc.exe warnings "),
		(plan(Linux, Make, Foreign), "make tln warnings warning: /h/.local/bin/roc is not a file that tln wrote, so tln keeps it. Run: tln setup --replace-roc"),
		(plan(Windows, Make, Foreign), "make tln.exe warnings warning: /h/.local/bin/roc.exe is not a file that tln wrote, so tln keeps it. Run: tln setup --replace-roc"),
		(plan(Linux, Foreign, Make), "tln: error[usage]: /h/.local/bin/tln is not a file that tln wrote, so tln does not replace it. Move or remove that file, then run the command again."),
		(plan(Linux, Foreign, Foreign), "tln: error[usage]: /h/.local/bin/tln is not a file that tln wrote, so tln does not replace it. Move or remove that file, then run the command again."),
		(plan(Windows, Foreign, Make), "tln: error[usage]: /h/.local/bin/tln.exe is not a file that tln wrote, so tln does not replace it. Move or remove that file, then run the command again."),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-ST10 R-S3 R-IS5 R-RM5: the Windows rule. A `.exe` is renamed to `<name>.<16hex>.del` in its dir before it is replaced (`tln.exe` is `tln.<hex>.del`, the path can have `/` or `\`). The renames are for Windows only, in the order of the files. Linux and macOS rename over a running file, so they have none.
# A `.del` file is `<name>.<16 lower case hex digits>.del` with a name: `tln.0123456789abcdef.del` is one, `tln.exe`, `x.del`, `tln.0123456789abcde.del` (15 digits), `tln.0123456789ABCDEF.del` and `.0123456789abcdef.del` are not. The sweep gives the full paths of the files that are `.del` files, in byte order (a directory with such a name is not one).
expect {
	hex = "0123456789abcdef"
	moves = |os, files| Str.join_with(TalonUpdate.del_moves({ os, hex, files }).map(|m| Str.concat(m.from, Str.concat(" -> ", m.to))), " | ")
	del = |names| Str.join_with(names.map(|n| if TalonUpdate.is_del(n) "1" else "0"), "")
	entries = [{ name: "tln.${hex}.del", is_dir: Bool.False, mtime: 1 }, { name: "a.${hex}.del", is_dir: Bool.False, mtime: 1 }, { name: "tln.exe", is_dir: Bool.False, mtime: 1 }, { name: "roc.${hex}.del", is_dir: Bool.True, mtime: 1 }, { name: "tln.1.del", is_dir: Bool.False, mtime: 1 }]
	rows = [
		(TalonUpdate.del_name({ path: "/d/bin/tln.exe", hex }), "/d/bin/tln.${hex}.del"),
		(TalonUpdate.del_name({ path: "C:\\Users\\u\\.local\\bin\\roc.exe", hex }), "C:\\Users\\u\\.local\\bin\\roc.${hex}.del"),
		(TalonUpdate.del_name({ path: "/d/bin/tln", hex }), "/d/bin/tln.${hex}.del"),
		(moves(Windows, ["/d/bin/tln.exe", "/h/bin/tln.exe", "/h/bin/roc.exe"]), "/d/bin/tln.exe -> /d/bin/tln.${hex}.del | /h/bin/tln.exe -> /h/bin/tln.${hex}.del | /h/bin/roc.exe -> /h/bin/roc.${hex}.del"),
		(moves(Windows, []), ""),
		(moves(Linux, ["/d/bin/tln", "/h/bin/tln", "/h/bin/roc"]), ""),
		(moves(Macos, ["/d/bin/tln"]), ""),
		(del(["tln.${hex}.del", "roc.old.${hex}.del", "tln.exe", "x.del", "tln.0123456789abcde.del", "tln.0123456789ABCDEF.del", ".${hex}.del", "tln.${hex}.del.bak", "tln.${hex}.tmp", ""]), "1100000000"),
		(Str.join_with(TalonUpdate.stale({ dir: "/d/bin", entries }), "|"), "/d/bin/a.${hex}.del|/d/bin/tln.${hex}.del"),
		(Str.join_with(TalonUpdate.stale({ dir: "/d/bin", entries: [] }), "|"), ""),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-S3 R-J3 R-J4 R-OUT2 R-OUT4 R-DI12 (proposals, TW24): the lines of the command and its `data`. The outcome is the one of `tool update` (`ToolUpdate.data`): `how` is `updated` or `up_to_date`, `from` is the installed version for `updated` and `null` for `up_to_date`, `to` is the source text of the new entry
# (`0.3.4`, or `git v0.3.4@dd03c09e` for a source build). The `--offline` failure is kind network (exit 15). The prebuilt entry has the version and the URL of the asset, no hashes, no compiler, the target and the time of the run. The source of `--from-source` is the tag of the release in `roc-talon/talon`, in the dir `cli`.
expect {
	out = |how, old, new| JsonDoc.render(ToolUpdate.data([TalonUpdate.outcome({ old, new, how })]))
	release = mk("0.3.4", "2026-10-01T12:00:00Z")
	entry = TalonUpdate.prebuilt_entry({ release, url: "https://h/v0.3.4/tln-x64musl", sha256: "S", target: "x64musl", now: pub("2026-10-15T12:00:00Z") })
	plan = TalonUpdate.source_of(release)
	rows = [
		(TalonUpdate.up_to_date_text("0.3.4"), "talon 0.3.4 is up to date"),
		(TalonUpdate.up_to_date_text("git v0.3.4@d0d0d0d0"), "talon git v0.3.4@d0d0d0d0 is up to date"),
		(TalonUpdate.updated_text({ old: "0.3.1", new: "0.3.4" }), "updated talon 0.3.1 to 0.3.4 (roc-talon/talon)"),
		(TalonUpdate.updated_text({ old: "0.3.1", new: "git v0.3.4@d0d0d0d0" }), "updated talon 0.3.1 to git v0.3.4@d0d0d0d0 (roc-talon/talon)"),
		(out(Updated, "0.3.1", "0.3.4"), "{\"tools\":[{\"tool\":\"talon\",\"name\":\"roc-talon/talon\",\"how\":\"updated\",\"from\":\"0.3.1\",\"to\":\"0.3.4\"}]}"),
		(out(UpToDate, "0.3.4", "0.3.4"), "{\"tools\":[{\"tool\":\"talon\",\"name\":\"roc-talon/talon\",\"how\":\"up_to_date\",\"from\":null,\"to\":\"0.3.4\"}]}"),
		(TalonUpdate.offline_failure("0.3.4").line(), "tln: error[network]: tln 0.3.4 is not downloaded and --offline is set. Run the command without --offline."),
		(Str.inspect(entry), Str.inspect({ source: Prebuilt({ version: "0.3.4", url: "https://h/v0.3.4/tln-x64musl" }), hashes: [], nightly: "", target: "x64musl", sha256: "S", libs: [], installed_at: "2026-10-15T12:00:00Z" })),
		(Str.inspect(plan), Str.inspect({ source: { owner: "roc-talon", repo: "talon", ref: "v0.3.4" }, path: Ok("cli") })),
		(TalonUpdate.source_text(Prebuilt({ version: "0.3.4", url: "u" })), "0.3.4"),
		(TalonUpdate.source_text(Git({ commit: "d0d0d0d05e8a2f4b", ref: "v0.3.4", path: Ok("cli") })), "git v0.3.4@d0d0d0d0"),
		(TalonUpdate.name, "roc-talon/talon"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-S2 R-FL12 R-CM16 R-CM19: which command line is `tool update talon`: exactly one operand, `talon` or `roc-talon/talon`. No operand (all tools), a tool name, a name with a selector (a failure of `ToolManage.read`) and 2 operands are not.
expect {
	target = |words| match Args.parse(words) {
		Ok(args) => TalonUpdate.is_target(args)
		Err(_) => Bool.False
	}
	rows = [
		(target(["tool", "update", "talon"]), Bool.True),
		(target(["tool", "update", "roc-talon/talon"]), Bool.True),
		(target(["tool", "update", "talon", "--from-source"]), Bool.True),
		(target(["tool", "update"]), Bool.False),
		(target(["tool", "update", "foo"]), Bool.False),
		(target(["tool", "update", "talon@1"]), Bool.False),
		(target(["tool", "update", "talon", "foo"]), Bool.False),
		(target(["tool", "update", "acme/talon"]), Bool.False),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

prebuilt_doc : Str -> Str
prebuilt_doc = |version| "{\"name\":\"roc-talon/talon\",\"source\":{\"kind\":\"prebuilt\",\"version\":\"${version}\",\"url\":\"https://h/v${version}/tln-x64musl\"},\"build\":{\"hashes\":[],\"nightly\":\"\",\"target\":\"x64musl\"},\"sha256\":\"S\",\"libs\":[],\"installed_at\":\"2026-10-15T12:00:00Z\"}"

git_doc : Str
git_doc = "{\"name\":\"roc-talon/talon\",\"source\":{\"kind\":\"git\",\"commit\":\"d0d0d0d0\",\"ref\":\"v0.3.4\",\"path\":\"cli\"},\"build\":{\"hashes\":[\"H1\"],\"nightly\":\"nightly-2026-10-14-38a3029\",\"target\":\"x64musl\"},\"sha256\":\"S2\",\"libs\":[],\"installed_at\":\"2026-10-16T08:00:00Z\"}"

tool_doc : Str
tool_doc = "{\"name\":\"acme/foo\",\"source\":{\"kind\":\"release\",\"version\":\"1.1.0\",\"url\":\"u\"}}"

# R-IS6 R-T4 R-TF2 (question Q-S1, Q-S2): the entry `talon` of `tools.json`. `read` and `manifest` leave the key `talon` out (the entry has its own source kinds, and it is no tool of the list), also when its source is a kind that tln does not know (slice 048, Q-T1: exit 19 for it before). Every other
# failure of `read` stays. The reader of the entry gives `Ok(Err(None))` for a missing file, no `tools` field and no key `talon`. The prebuilt entry has the version and the URL; a source build has the git fields with the optional `path`; a field that is missing from `build` or from the entry gives the empty text or list (as `manifest`).
# The failures are kind input (exit 19) and name the file and the tool `talon`.
expect {
	path = "/d/talon/tools.json"
	whole = |tools| "{\"format\":1,\"tools\":{${tools}}}"
	read = |text| match ToolsJson.read({ path, text }) {
		Ok(entries) => "keys ${Str.join_with(entries.map(|e| e.key), ",")}"
		Err(fail) => fail.line()
	}
	manifest = |text| match ToolsJson.manifest({ path, text }) {
		Ok(tools) => "keys ${Str.join_with(tools.map(|t| t.key), ",")}"
		Err(fail) => fail.line()
	}
	talon = |text| match ToolsJson.talon({ path, text }) {
		Ok(Ok(found)) => Str.inspect(found)
		Ok(Err(None)) => "none"
		Err(fail) => fail.line()
	}
	input = |what| "tln: error[input]: ${path}: ${what}"
	odd = "{\"name\":\"roc-talon/talon\",\"source\":{\"kind\":\"install\"}}"
	rows = [
		(read(Ok(whole("\"talon\":${prebuilt_doc("0.3.4")},\"foo\":${tool_doc}"))), "keys foo"),
		(manifest(Ok(whole("\"foo\":${tool_doc},\"talon\":${prebuilt_doc("0.3.4")}"))), "keys foo"),
		(read(Ok(whole("\"talon\":${odd}"))), "keys "),
		(manifest(Ok(whole("\"talon\":${odd}"))), "keys "),
		(read(Ok(whole("\"talon\":${git_doc}"))), "keys "),
		(read(Ok(whole("\"foo\":{\"name\":\"acme/foo\"},\"talon\":${prebuilt_doc("0.3.4")}"))), input("tool foo: has no source that tln knows")),
		(talon(Err(NotFound)), "none"),
		(talon(Ok("{\"format\":1}")), "none"),
		(talon(Ok(whole("\"foo\":${tool_doc}"))), "none"),
		(talon(Ok(whole("\"talon\":${prebuilt_doc("0.3.4")}"))), Str.inspect({ source: Prebuilt({ version: "0.3.4", url: "https://h/v0.3.4/tln-x64musl" }), hashes: [], nightly: "", target: "x64musl", sha256: "S", libs: [], installed_at: "2026-10-15T12:00:00Z" })),
		(talon(Ok(whole("\"foo\":${tool_doc},\"talon\":${git_doc}"))), Str.inspect({ source: Git({ commit: "d0d0d0d0", ref: "v0.3.4", path: Ok("cli") }), hashes: ["H1"], nightly: "nightly-2026-10-14-38a3029", target: "x64musl", sha256: "S2", libs: [], installed_at: "2026-10-16T08:00:00Z" })),
		(talon(Ok(whole("\"talon\":{\"source\":{\"kind\":\"git\",\"commit\":\"c\",\"ref\":\"main\"}}"))), Str.inspect({ source: Git({ commit: "c", ref: "main", path: Err(None) }), hashes: [], nightly: "", target: "", sha256: "", libs: [], installed_at: "" })),
		(talon(Ok(whole("\"talon\":${odd}"))), input("tool talon: has no source that tln knows")),
		(talon(Ok(whole("\"talon\":{\"source\":{\"kind\":\"prebuilt\",\"version\":\"0.3.4\"}}"))), input("tool talon: has no source that tln knows")),
		(talon(Ok(whole("\"talon\":{\"name\":\"roc-talon/talon\"}"))), input("tool talon: has no source that tln knows")),
		(talon(Ok(whole("\"talon\":5"))), input("tool talon: is not an object")),
		(talon(Ok("not json")), input("the content does not parse")),
		(talon(Ok("{\"format\":2,\"tools\":{}}")), input("format 2 is newer than this tln (format 1). Run: tln tool update talon")),
		(talon(Ok("{\"format\":1,\"tools\":5}")), input("tools is not an object")),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-IS6 R-T4 R-TF2 R-CC1 R-CC6: the text of `tools.json` after the entry `talon` is put. The entry is replaced in its place, with the fields that Talon does not know (R-TF2); a new entry is the last of `tools`; a file with no `tools` field gets the field at the end; a missing file gives a new file with `format` 1. The other tools and the
# other top-level fields stay as they are. The text of the prebuilt entry is the one of the tools (`name`, `source` with `kind` `prebuilt`, `version` and `url`, `build`, `sha256`, `libs`, `installed_at`). A source build has the git source with `path` only when the entry has one, and its `build`. A newer `format` is a failure of kind input.
expect {
	path = "/d/talon/tools.json"
	pre = |version| { source: Prebuilt({ version, url: "https://h/v${version}/tln-x64musl" }), hashes: [], nightly: "", target: "x64musl", sha256: "S", libs: [], installed_at: "2026-10-15T12:00:00Z" }
	src = { source: Git({ commit: "d0d0d0d0", ref: "v0.3.4", path: Ok("cli") }), hashes: ["H1"], nightly: "nightly-2026-10-14-38a3029", target: "x64musl", sha256: "S2", libs: [], installed_at: "2026-10-16T08:00:00Z" }
	put = |text, talon| match ToolsJson.put_talon({ path, text, talon }) {
		Ok(out) => out.trim_end()
		Err(fail) => fail.line()
	}
	whole = |tools| "{\"format\":1,\"tools\":{${tools}}}"
	rows = [
		(put(Err(NotFound), pre("0.3.4")), whole("\"talon\":${prebuilt_doc("0.3.4")}")),
		(put(Ok(whole("\"foo\":${tool_doc}")), pre("0.3.4")), whole("\"foo\":${tool_doc},\"talon\":${prebuilt_doc("0.3.4")}")),
		(put(Ok(whole("\"talon\":${prebuilt_doc("0.3.1")},\"foo\":${tool_doc}")), pre("0.3.4")), whole("\"talon\":${prebuilt_doc("0.3.4")},\"foo\":${tool_doc}")),
		(put(Ok("{\"format\":1,\"note\":\"keep\"}"), pre("0.3.4")), "{\"format\":1,\"note\":\"keep\",\"tools\":{\"talon\":${prebuilt_doc("0.3.4")}}}"),
		(put(Ok("{\"format\":1,\"note\":\"keep\",\"tools\":{\"talon\":{\"later\":7,\"name\":\"x\"}}}"), pre("0.3.4")), "{\"format\":1,\"note\":\"keep\",\"tools\":{\"talon\":{\"later\":7,\"name\":\"roc-talon/talon\",\"source\":{\"kind\":\"prebuilt\",\"version\":\"0.3.4\",\"url\":\"https://h/v0.3.4/tln-x64musl\"},\"build\":{\"hashes\":[],\"nightly\":\"\",\"target\":\"x64musl\"},\"sha256\":\"S\",\"libs\":[],\"installed_at\":\"2026-10-15T12:00:00Z\"}}}"),
		(put(Ok(whole("\"talon\":${odd_doc}")), src), whole("\"talon\":${git_doc}")),
		(put(Ok(whole("\"talon\":${prebuilt_doc("0.3.1")}")), { ..src, source: Git({ commit: "d0d0d0d0", ref: "v0.3.4", path: Err(None) }) }), whole("\"talon\":{\"name\":\"roc-talon/talon\",\"source\":{\"kind\":\"git\",\"commit\":\"d0d0d0d0\",\"ref\":\"v0.3.4\"},\"build\":{\"hashes\":[\"H1\"],\"nightly\":\"nightly-2026-10-14-38a3029\",\"target\":\"x64musl\"},\"sha256\":\"S2\",\"libs\":[],\"installed_at\":\"2026-10-16T08:00:00Z\"}")),
		(put(Ok("{\"format\":2,\"tools\":{}}"), pre("0.3.4")), "tln: error[input]: ${path}: format 2 is newer than this tln (format 1). Run: tln tool update talon"),
		(put(Ok("not json"), pre("0.3.4")), "tln: error[input]: ${path}: the content does not parse"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-IS6 R-IS2 R-S2 R-S4 (slice 052 and 063, docs/slices/052-release-install.md): the URL that `tln setup` records for the running binary, the entry that it writes when `talon` is missing, and its line. The URL is the one of the install script for an exact version
# (`<releases>/download/v<version>/<asset>`, CLI 6.5 R-IS3: no API call). The entry has the form of Q-S1 of slice 050: the kind `prebuilt` with `version` and `url`, no compiler (`hashes` `[]`, `nightly` `""`), the target of this machine, the sha256 of the file `tln`, `libs` `[]` and the time of
# the run. Slice 063 (docs/slices/063-talon-entry-repair.md, R-IS6, R-S4): an entry that exists stays only when its version and its sha256 are those of the running tln (the version of a prebuilt entry, or of the tag ref of a git entry, R-S6). Any other field (the URL, the target, the time, the kind) does
# not count. An entry that differs is written again as a prebuilt entry of the running tln, whether it is older or newer (the repair `install.sh --version <older>`, R-S4, goes back). The asset of Windows has `.exe` and Windows on ARM64 has the target `x64win` (R-IS2, R-HF10).
expect {
	url = |version, os, target| TalonUpdate.release_url({ version, asset: TalonUpdate.asset_name({ os, target }) })
	now = pub("2026-10-22T12:00:00Z")
	entry = |have, version, os, target| TalonUpdate.setup_entry({ have, version, os, target, sha256: "S0", now })
	pre = |version, os, target| {
		source: Prebuilt({ version, url: url(version, os, target) }),
		hashes: [],
		nightly: "",
		target,
		sha256: "S0",
		libs: [],
		installed_at: "2026-10-22T12:00:00Z",
	}
	old = { source: Prebuilt({ version: "0.3.1", url: "https://h/v0.3.1/tln-x64musl" }), hashes: [], nightly: "", target: "x64musl", sha256: "S1", libs: [], installed_at: "2026-10-15T12:00:00Z" }
	src = { source: Git({ commit: "d0d0d0d0", ref: "v0.3.4", path: Ok("cli") }), hashes: ["H1"], nightly: "nightly-2026-10-14-38a3029", target: "x64musl", sha256: "S2", libs: [], installed_at: "2026-10-16T08:00:00Z" }
	# the entries of the running tln (version 0.3.4, sha256 S0) in each form; `mirror` and `git_same` differ in every other field
	same = pre("0.3.4", Linux, "x64musl")
	mirror = { ..same, source: Prebuilt({ version: "0.3.4", url: "https://mirror/v0.3.4/tln" }), hashes: ["H1"], target: "arm64musl", installed_at: "2026-10-01T00:00:00Z" }
	git_same = { ..src, sha256: "S0" }
	with_version = |version| { ..same, source: Prebuilt({ version, url: url(version, Linux, "x64musl") }) }
	rows = [
		(url("0.3.4", Linux, "x64musl"), "https://github.com/roc-talon/talon/releases/download/v0.3.4/tln-x64musl"),
		(url("0.3.4", Linux, "arm64musl"), "https://github.com/roc-talon/talon/releases/download/v0.3.4/tln-arm64musl"),
		(url("0.3.4", Macos, "x64mac"), "https://github.com/roc-talon/talon/releases/download/v0.3.4/tln-x64mac"),
		(url("0.3.4", Macos, "arm64mac"), "https://github.com/roc-talon/talon/releases/download/v0.3.4/tln-arm64mac"),
		(url("0.3.4", Windows, "x64win"), "https://github.com/roc-talon/talon/releases/download/v0.3.4/tln-x64win.exe"),
		(Str.inspect(entry(Err(None), "0.3.4", Linux, "x64musl")), Str.inspect(Put(pre("0.3.4", Linux, "x64musl")))),
		(Str.inspect(entry(Err(None), "0.3.4", Macos, "arm64mac")), Str.inspect(Put(pre("0.3.4", Macos, "arm64mac")))),
		(Str.inspect(entry(Err(None), "0.3.4", Windows, "x64win")), Str.inspect(Put(pre("0.3.4", Windows, "x64win")))),
		(Str.inspect(entry(Ok(old), "0.3.4", Linux, "x64musl")), Str.inspect(Put(pre("0.3.4", Linux, "x64musl")))),
		(Str.inspect(entry(Ok(src), "0.3.4", Linux, "x64musl")), Str.inspect(Put(pre("0.3.4", Linux, "x64musl")))),
		(Str.inspect(entry(Ok(same), "0.3.4", Linux, "x64musl")), Str.inspect(Keep)),
		(Str.inspect(entry(Ok(mirror), "0.3.4", Linux, "x64musl")), Str.inspect(Keep)),
		(Str.inspect(entry(Ok(git_same), "0.3.4", Linux, "x64musl")), Str.inspect(Keep)),
		(Str.inspect(entry(Ok({ ..same, sha256: "S9" }), "0.3.4", Linux, "x64musl")), Str.inspect(Put(pre("0.3.4", Linux, "x64musl")))),
		(Str.inspect(entry(Ok(with_version("0.3.1")), "0.3.4", Linux, "x64musl")), Str.inspect(Put(pre("0.3.4", Linux, "x64musl")))),
		(Str.inspect(entry(Ok(with_version("0.3.9")), "0.3.4", Linux, "x64musl")), Str.inspect(Put(pre("0.3.4", Linux, "x64musl")))),
		(Str.inspect(entry(Ok(with_version("0.3.9")), "0.3.1", Linux, "x64musl")), Str.inspect(Put(pre("0.3.1", Linux, "x64musl")))),
		(Str.inspect(entry(Ok({ ..git_same, sha256: "S9" }), "0.3.4", Linux, "x64musl")), Str.inspect(Put(pre("0.3.4", Linux, "x64musl")))),
		(Str.inspect(entry(Ok({ ..git_same, source: Git({ commit: "d0d0d0d0", ref: "v0.3.1", path: Ok("cli") }) }), "0.3.4", Linux, "x64musl")), Str.inspect(Put(pre("0.3.4", Linux, "x64musl")))),
		(TalonUpdate.recorded_text({ version: "0.3.4", path: "/h/.local/share/talon/tools.json" }), "recorded talon 0.3.4 in /h/.local/share/talon/tools.json"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

odd_doc : Str
odd_doc = "{\"name\":\"roc-talon/talon\",\"source\":{\"kind\":\"install\"}}"
