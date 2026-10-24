app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Clock
import lib.Compiler
import lib.Fail
import lib.Toolchain

main! = |_args| Ok({})

n1 = "nightly-2026-10-14-38a3029"

n2 = "nightly-2026-10-09-258ab27"

# R-SO7 R-SO9 R-SO10 R-SO11 R-PH6: the id of the compiler on `PATH` is in the stdout of `roc version` (`version_id`). A nightly or a release is an installed compiler (R-SO10),
# another id is a local build (R-SO11). The mapping to `NoCompiler` is tested in `tests/unit/pathroc.roc` (slice 022b: `Compiler.on_path` is dead code).
expect {
	versions = [
		("Roc compiler version ${n1}\n", Ok(n1)),
		("Roc compiler version ${n1}", Ok(n1)),
		("Roc compiler version ${n1}\r\n", Ok(n1)),
		("Roc compiler version 0.1.0\n", Ok("0.1.0")),
		("Roc compiler version debug-3f9a1c2\n", Ok("debug-3f9a1c2")),
		("Roc compiler version \n", Err(BadVersion)),
		("Roc compiler version a b\n", Err(BadVersion)),
		("roc 0.1.0\n", Err(BadVersion)),
		("", Err(BadVersion)),
	]
	bad_versions = versions.keep_if(|(text, want)| Compiler.version_id(text) != want).map(|(text, want)| (text, want, Compiler.version_id(text)))
	dbg bad_versions

	kinds = [(n1, Nightly), ("0.1.0", Release), ("12.30.4", Release), ("debug-3f9a1c2", Local), ("nightly-2026-10-09", Local), ("", Local)]
	bad_kinds = kinds.keep_if(|(id, want)| Compiler.kind(id) != want).map(|(id, want)| (id, want))
	dbg bad_kinds

	bad_versions == [] and bad_kinds == []
}

# R-PH7 R-SO22 R-SO10 R-CV1 R-BL3 R-DL5 R-EC13 (slice 023c): a probe needs a compiler, and an installed compiler is enough. `require` gives the id that runs: the id of `installed` (also the other tag form of one nightly,
# R-CV1) wins over the `roc` on `PATH` (the managed copy runs, D7 of slice 023), then the id of `PATH`. Any other id is a required download, and the consent rules are slice 025, so it is refused with exit code 13 (kind consent).
# The message names the id and `tln roc install`. It does not name `--allow-downloads` or `TALON_AUTO_INSTALL` (no resolve command reads them before slice 025), and it does not say that tln runs only the `roc` on `PATH`.
expect {
	found = |id| Ok({ id, path: "/usr/local/bin/roc" })
	need = |id, installed, path| Compiler.require({ id, installed, path })
	refused = |id| Err(Fail.new(Consent, "the compiler ${id} is not installed. Run: tln roc install ${id}."))
	jul = "nightly-2026-July-23-abc1234"
	num = "nightly-2026-07-23-abc1234"
	rows = [
		("installed, no roc on PATH", need(n2, [n1, n2], Err(NoCompiler)), Ok(n2)),
		("installed, a release", need("0.1.0", ["0.1.0"], Err(NoCompiler)), Ok("0.1.0")),
		("installed, and PATH has the same id: the installed one", need(n1, [n1], found(n1)), Ok(n1)),
		("installed, and PATH has another id", need(n2, [n2], found(n1)), Ok(n2)),
		("the installed id is the other tag form: its id", need(jul, [n1, num], Err(NoCompiler)), Ok(num)),
		("and the other way", need(num, [jul], Err(NoCompiler)), Ok(jul)),
		("a named build", need("git-0123abcd", [n1, "git-0123abcd"], Err(NoCompiler)), Ok("git-0123abcd")),
		("only on PATH", need(n1, [], found(n1)), Ok(n1)),
		("only on PATH, installed has others", need(n1, [n2], found(n1)), Ok(n1)),
		("PATH has the other tag form: the id of PATH", need(jul, [], found(num)), Ok(num)),
		("not installed, PATH has another id", need(n2, [n1], found(n1)), refused(n2)),
		("a release that is not installed", need("0.1.0", [n1], found(n1)), refused("0.1.0")),
		("not installed, no roc on PATH", need(n2, [n1], Err(NoCompiler)), refused(n2)),
		("nothing installed, no roc on PATH", need(n2, [], Err(NoCompiler)), refused(n2)),
		("a named build that is not installed", need("git-0123abcd", [n1], found(n1)), refused("git-0123abcd")),
		("a prefix does not match an id", need("nightly-2026-10-14", [n1], found(n1)), refused("nightly-2026-10-14")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, got, want))
	dbg bad
	no = need(n2, [n1], found(n1))
	text = match no {
		Err(f) => f.message
		Ok(_) => ""
	}
	code = match no {
		Err(f) => f.kind.code()
		Ok(_) => 0
	}
	bad == [] and code == 13 and !text.contains("--allow-downloads") and !text.contains("TALON_AUTO_INSTALL") and !text.contains("P0") and !text.contains("only the roc on PATH")
}

# R-SO22 R-SO10 R-CV1 R-DL2 R-BL3 (slice 025): `find` is `require` with the third row as a value: `Missing` is a required download, which the command asks for before the first probe. It agrees with `require` for each input: the same ids for rows 1 and 2
# (an installed id, also the other tag form, wins over the `roc` on `PATH`), `Missing` where `require` refuses. The refusal of `require` is what a run with `TALON_AUTO_INSTALL=no` prints (R-DL5).
expect {
	found = |id| Ok({ id, path: "/usr/local/bin/roc" })
	jul = "nightly-2026-July-23-abc1234"
	num = "nightly-2026-07-23-abc1234"
	rows = [
		("installed", n2, [n1, n2], Err(NoCompiler), Ok(n2)),
		("installed, and PATH has the same id: the installed one", n1, [n1], found(n1), Ok(n1)),
		("the installed id is the other tag form: its id", jul, [n1, num], Err(NoCompiler), Ok(num)),
		("and the other way", num, [jul], Err(NoCompiler), Ok(jul)),
		("a named build", "git-0123abcd", [n1, "git-0123abcd"], Err(NoCompiler), Ok("git-0123abcd")),
		("only on PATH", n1, [], found(n1), Ok(n1)),
		("PATH has the other tag form: the id of PATH", jul, [], found(num), Ok(num)),
		("not installed, PATH has another id", n2, [n1], found(n1), Err(Missing)),
		("a release that is not installed", "0.1.0", [n1], found(n1), Err(Missing)),
		("not installed, no roc on PATH", n2, [n1], Err(NoCompiler), Err(Missing)),
		("nothing installed, no roc on PATH", n2, [], Err(NoCompiler), Err(Missing)),
		("a prefix does not match an id", "nightly-2026-10-14", [n1], found(n1), Err(Missing)),
	]
	bad = rows.keep_if(|(_, id, installed, path, want)| Compiler.find({ id, installed, path }) != want).map(|(label, _, _, _, _)| label)
	dbg bad
	# `require` agrees: the same id, and a refusal exactly where `find` says `Missing`.
	apart = rows.keep_if(
		|(_, id, installed, path, want)| match (Compiler.require({ id, installed, path }), want) {
			(Ok(got), Ok(wanted)) => got != wanted
			(Err(_), Err(Missing)) => Bool.False
			_ => Bool.True
		},
	).map(|(label, _, _, _, _)| label)
	dbg apart
	bad == [] and apart == []
}

a1 = "nightly-2026-09-01-24e3995"

a2 = "nightly-2026-10-09-258ab27"

a3 = "nightly-2026-10-13-91fa0c2"

a4 = "nightly-2026-10-14-38a3029"

# Same date as a4. Its tag text is before a4, and its `published_at` is later.
a5 = "nightly-2026-10-14-0abcdef"

g1 = "git-0123abcd"

# R-SO1 R-SO2 R-SO4 R-SO5 R-SO6 R-SO7 R-SO10 R-SO12 R-SO13 R-SO14 R-NS3 R-NS6 R-NS1 (slice 022): the compiler that the ranks select. The first rank with a value wins: 1 argument, 2 `ROC_TOOLCHAIN`, 4 the newest installed
# compiler in `[toolchain] roc`, 5 `.roc-version` (only with no `talon.toml`), 6 `default-roc`, 7 the `roc` on `PATH`. Rank 4 never goes on to rank 5 when no installed compiler is in the range (R-SO13: a download of slice 025).
# The `roc` on `PATH` counts as installed (R-SO10). With the switch off no nightly is a candidate of rank 4 (R-NS3). `git-`, `link-` and `copy-` builds are chosen by name only (R-NS6), so never by rank 4. Two nightlies of
# one date are in the order of their `published_at` (R-NS1), which is the reverse of the tag text for a4 and a5.
expect {
	t = |text| Clock.parse_utc(text) ?? 0
	base = { argument: Err(Unset), env: Err(Unset), req: Err(Unset), nightly: Bool.True, has_toml: Bool.False, version_file: Err(None), default: Err(Unset), path: Err(NoCompiler), installed: [], times: [] }
	shown = |r| match r {
		Ok(sel) => Ok((sel.id, sel.rank, sel.state))
		Err(e) => Err(e)
	}
	all = Ok(Any)
	late_times = [{ id: a4, published_at: t("2026-10-14T09:00:00Z") }, { id: a5, published_at: t("2026-10-14T13:00:00Z") }]
	rows = [
		("no rank has a value (R-SO14)", Compiler.select(base), Err(NoCompiler)),
		("rank 7, the roc on PATH (R-SO7)", Compiler.select({ ..base, path: Ok(a4) }), Ok((a4, Path, Installed))),
		("rank 6 over rank 7, installed", Compiler.select({ ..base, path: Ok(a4), default: Ok(a2), installed: [a2] }), Ok((a2, Default, Installed))),
		("rank 6, not installed: Missing (R-SO12)", Compiler.select({ ..base, default: Ok(a2) }), Ok((a2, Default, Missing))),
		("rank 5 over rank 6", Compiler.select({ ..base, version_file: Ok(a3), default: Ok(a2), installed: [a2, a3] }), Ok((a3, VersionFile, Installed))),
		("rank 5 is off with a talon.toml (R-SO5, R-PD6): rank 6", Compiler.select({ ..base, has_toml: Bool.True, version_file: Ok(a3), default: Ok(a2), installed: [a2, a3] }), Ok((a2, Default, Installed))),
		("rank 5 is off with a talon.toml, nothing else: rank 7", Compiler.select({ ..base, has_toml: Bool.True, version_file: Ok(a3), path: Ok(a4) }), Ok((a4, Path, Installed))),
		("rank 4 over ranks 5 to 7: the newest installed in the range", Compiler.select({ ..base, req: all, version_file: Ok(a2), default: Ok(a2), path: Ok(a2), installed: [a2, a4, a3] }), Ok((a4, Range, Installed))),
		("rank 2 over rank 4", Compiler.select({ ..base, env: Ok(a2), req: all, installed: [a2, a4] }), Ok((a2, Env, Installed))),
		("rank 1 over rank 2", Compiler.select({ ..base, argument: Ok(a3), env: Ok(a2), installed: [a2, a3] }), Ok((a3, Argument, Installed))),
		("rank 2, not installed: Missing, and no check of the range (R-SO12)", Compiler.select({ ..base, env: Ok(a2), req: Ok(AtLeast(a4)) }), Ok((a2, Env, Missing))),
		("the id of the roc on PATH is installed for rank 1 (R-SO10)", Compiler.select({ ..base, argument: Ok(a4), path: Ok(a4) }), Ok((a4, Argument, Installed))),
		("the id of the roc on PATH is a candidate of rank 4 (R-SO10)", Compiler.select({ ..base, req: all, path: Ok(a4), installed: [a2] }), Ok((a4, Range, Installed))),
		("a lower bound", Compiler.select({ ..base, req: Ok(AtLeast(a3)), installed: [a2, a3, a4] }), Ok((a4, Range, Installed))),
		("a lower bound, only older ones installed: no fall through to rank 6 (R-SO13)", Compiler.select({ ..base, req: Ok(AtLeast(a3)), default: Ok(a2), installed: [a2] }), Err(NoneInRange)),
		("an exact range", Compiler.select({ ..base, req: Ok(Exactly(a2)), installed: [a2, a3] }), Ok((a2, Range, Installed))),
		("an exact range, not installed (R-SO13)", Compiler.select({ ..base, req: Ok(Exactly(a3)), installed: [a2] }), Err(NoneInRange)),
		("a semver range takes releases only (R-NS7)", Compiler.select({ ..base, req: Ok(Semver("0.1.*")), installed: [a4, "0.1.0", "0.1.3", "0.2.0"] }), Ok(("0.1.3", Range, Installed))),
		("the switch is off: no nightly (R-NS3)", Compiler.select({ ..base, req: all, nightly: Bool.False, installed: [a2, a4, "0.1.0"] }), Ok(("0.1.0", Range, Installed))),
		("the switch is off, only nightlies installed (R-NS2, R-SO13)", Compiler.select({ ..base, req: all, nightly: Bool.False, installed: [a2, a4] }), Err(NoneInRange)),
		("rank 4 never chooses a git build (R-NS6)", Compiler.select({ ..base, req: all, installed: [g1, a2] }), Ok((a2, Range, Installed))),
		("only a git build is installed (R-NS6, R-SO13)", Compiler.select({ ..base, req: all, installed: [g1] }), Err(NoneInRange)),
		("rank 6 may name a git build (R-NS6)", Compiler.select({ ..base, default: Ok(g1), installed: [g1] }), Ok((g1, Default, Installed))),
		("rank 2 may name a link build", Compiler.select({ ..base, env: Ok("link-dev"), installed: ["link-dev"] }), Ok(("link-dev", Env, Installed))),
		("2 nightlies of one date, no times: the tag text (R-NS1)", Compiler.select({ ..base, req: all, installed: [a4, a5] }), Ok((a4, Range, Installed))),
		("2 nightlies of one date: `published_at` (R-NS1)", Compiler.select({ ..base, req: all, installed: [a4, a5], times: late_times }), Ok((a5, Range, Installed))),
		("a release of the same day is newer than a nightly (R-NS1)", Compiler.select({ ..base, req: all, installed: [a4, "0.1.0"], times: [{ id: "0.1.0", published_at: t("2026-10-14T20:00:00Z") }] }), Ok(("0.1.0", Range, Installed))),
		("a release of an earlier day is older", Compiler.select({ ..base, req: all, installed: [a4, "0.1.0"], times: [{ id: "0.1.0", published_at: t("2026-10-13T20:00:00Z") }] }), Ok((a4, Range, Installed))),
		("an older nightly (a1) and a newer one", Compiler.select({ ..base, req: all, installed: [a1, a3] }), Ok((a3, Range, Installed))),
	]
	bad = rows.keep_if(|(_, got, want)| shown(got) != want).map(|(label, got, want)| (label, want, shown(got)))
	dbg bad
	bad == []
}

# R-LY1 R-NS6 R-NS1 R-SO5 R-SC12 R-SO18 (slice 022): the facts that `select` reads. `installed`: the dirs of `toolchains/` that are a compiler (a nightly, a release, `git-`, `link-`, `copy-`), sorted. `times`: the
# `published_at` of the `.talon.json` of each installed compiler (`Toolchain.meta` writes it). `version_file`: the trimmed text of `.roc-version` is a full id (a prefix is an error, R-SC12: exit 19), an empty file is no file.
# `roc_version_note`: the one warning when the header pin and `.roc-version` name 2 compilers (the same nightly in the other tag form is one compiler).
expect {
	t = |text| Clock.parse_utc(text) ?? 0
	dir = |name| { name, is_dir: Bool.True, mtime: 1 }
	file = |name| { name, is_dir: Bool.False, mtime: 1 }
	entries = [
		dir(a4),
		file(a3),
		dir("link-dev"),
		dir("${a2}.lock"),
		dir("0.1.0"),
		dir("${a2}.0123456789abcdef.tmp"),
		dir("zig-0.13.0"),
		dir(g1),
		dir("debug-3f9a1c2"),
		dir("nightly-2026-10"),
		dir(a2),
		file("README"),
		dir("copy-dev"),
		dir("link-dev.tmp"),
		dir("${g1}.0123456789abcdef.tmp"),
		dir("copy-dev.lock"),
	]
	installed = Compiler.installed(entries)
	installed_ok = installed == ["0.1.0", "copy-dev", g1, "link-dev", a2, a4]
	dbg installed

	meta = |published_at| Toolchain.meta({ id: a2, url: "https://example.com/roc.tar.gz", sha256: "ab", typed: a2, compat: Ok("c"), now: t("2026-10-22T10:00:00Z"), published_at })
	ok_text = |id, published| "{\"format\":1,\"id\":\"${id}\",\"installed_at\":\"2026-10-22T10:00:00Z\",\"published_at\":\"${published}\"}"
	rows_times = [
		{ id: a2, text: Ok(ok_text(a2, "2026-10-09T15:01:06Z")) },
		{ id: a3, text: Err(NotFound) },
		{ id: a4, text: Ok("{\"format\":1,\"id\":\"${a4}\"}") },
		{ id: a5, text: Ok("not json") },
		{ id: a1, text: Ok(ok_text(a1, "yesterday")) },
		{ id: "0.1.0", text: Ok("{\"format\":1,\"published_at\":5}") },
		{ id: "0.2.0", text: Ok(ok_text("0.2.0", "2026-10-20T15:06:18Z")) },
		{ id: g1, text: Err(Denied) },
		{ id: "0.3.0", text: Ok(meta(t("2026-10-21T15:01:06Z"))) },
	]
	times = Compiler.times(rows_times)
	times_ok = times == [{ id: a2, published_at: t("2026-10-09T15:01:06Z") }, { id: "0.2.0", published_at: t("2026-10-20T15:06:18Z") }, { id: "0.3.0", published_at: t("2026-10-21T15:01:06Z") }]
	dbg times

	shown = |r| match r {
		Ok(Ok(id)) => "id ${id}"
		Ok(Err(Empty)) => "empty"
		Err(fail) => "${fail.kind.code().to_str()} ${fail.message}"
	}
	version = |text| shown(Compiler.version_file({ path: "/p/.roc-version", text }))
	rows_version = [
		(version("${a2}\n"), "id ${a2}"),
		(version("  ${a2}  \r\n"), "id ${a2}"),
		(version("nightly-2026-July-23-fdd77c3"), "id nightly-2026-July-23-fdd77c3"),
		(version("0.1.0\n"), "id 0.1.0"),
		(version(""), "empty"),
		(version("\n  \n"), "empty"),
		(version("nightly-2026-10\n"), "19 /p/.roc-version: .roc-version is not a full compiler id: nightly-2026-10"),
		(version("${a2} ${a3}"), "19 /p/.roc-version: .roc-version is not a full compiler id: ${a2} ${a3}"),
		(version("${a2}\n${a3}\n"), "19 /p/.roc-version: .roc-version is not a full compiler id: ${a2}\n${a3}"),
		(version("latest"), "19 /p/.roc-version: .roc-version is not a full compiler id: latest"),
	]
	bad_version = rows_version.keep_if(|(got, want)| got != want).map(|(got, want)| (want, got))
	dbg bad_version

	note = |pin, version_file| Compiler.roc_version_note({ pin, version_file })
	rows_note = [
		(note(Ok(a2), Ok(a3)), Ok(".roc-version names ${a3}, the header names ${a2}")),
		(note(Ok(a2), Ok(a2)), Err(None)),
		(note(Ok("nightly-2026-July-23-fdd77c3"), Ok("nightly-2026-07-23-fdd77c3")), Err(None)),
		(note(Ok("nightly-2026-07-23-fdd77c3"), Ok("nightly-2026-07-23-306abd6")), Ok(".roc-version names nightly-2026-07-23-306abd6, the header names nightly-2026-07-23-fdd77c3")),
		(note(Ok("0.1.0"), Ok(a2)), Ok(".roc-version names ${a2}, the header names 0.1.0")),
		(note(Err(NoPin), Ok(a2)), Err(None)),
		(note(Ok(a2), Err(None)), Err(None)),
	]
	bad_note = rows_note.keep_if(|(got, want)| got != want).map(|(got, want)| (want, got))
	dbg bad_note
	installed_ok and times_ok and bad_version == [] and bad_note == []
}

# R-SO14 R-SO13 R-EC18 R-EC13 R-DL10 (slice 022, G2 of the review; slice 025b, the text fix of 023b Q5): the failures of `select`. No rank: exit 18, the text names the 2 commands that fix it. No installed compiler in
# `[toolchain] roc`: exit 13, and the text says that `TALON_AUTO_INSTALL=no` refuses the download (the proxy shows it only for that value: with any other value rank 4 downloads, R-SO13) and names the 2 ways that the proxy has
# (the proxy has no flag). The text does not say that tln never downloads a compiler for a run.
expect {
	none = Compiler.failure(NoCompiler)
	range = Compiler.failure(NoneInRange(">=${a4}"))
	want = "no installed compiler is in [toolchain] roc (>=${a4}). TALON_AUTO_INSTALL=no refuses the download. Run: tln roc install <id> for an id in the range, or set TALON_AUTO_INSTALL=yes."
	dbg range
	none.kind.code() == 18
		and none.message == "no compiler is selected. Run: tln roc install @latest, then tln roc default <id>"
			and range.kind.code() == 13
				and range.message == want
}

# R-SO2 R-NS6 R-SC12 (slice 023, G1 of the review): `ROC_TOOLCHAIN` is a full compiler id of any kind: a nightly, a release, or a named build (`git-<name>`, `link-<name>`, `copy-<name>`, R-NS6). An empty value
# or no variable is `Unset`. A text that is not a full id (a prefix, a word, a name prefix with no name) is a failure of kind `Usage` (exit 2). Only the first `ROC_TOOLCHAIN` variable counts.
expect {
	shown = |r| match r {
		Ok(Ok(id)) => "id ${id}"
		Ok(Err(Unset)) => "unset"
		Err(fail) => "${fail.kind.code().to_str()} ${fail.message}"
	}
	toolchain = |text| shown(Compiler.toolchain_of([("PATH", "/bin"), ("ROC_TOOLCHAIN", text)]))
	refused = |text| "2 ROC_TOOLCHAIN is not a full compiler id: ${text}"
	rows = [
		(toolchain(n1), "id ${n1}"),
		(toolchain("nightly-2026-July-23-fdd77c3"), "id nightly-2026-July-23-fdd77c3"),
		(toolchain("0.1.0"), "id 0.1.0"),
		(toolchain("link-dev"), "id link-dev"),
		(toolchain("git-0123abcd"), "id git-0123abcd"),
		(toolchain("copy-dev"), "id copy-dev"),
		(toolchain(""), "unset"),
		(shown(Compiler.toolchain_of([("PATH", "/bin")])), "unset"),
		(shown(Compiler.toolchain_of([])), "unset"),
		(shown(Compiler.toolchain_of([("ROC_TOOLCHAIN", "link-dev"), ("ROC_TOOLCHAIN", "latest")])), "id link-dev"),
		(toolchain("nightly-2026-10"), refused("nightly-2026-10")),
		(toolchain("latest"), refused("latest")),
		(toolchain("link-"), refused("link-")),
		(toolchain("git-"), refused("git-")),
		(toolchain("copy-"), refused("copy-")),
		(toolchain("link-dev x"), refused("link-dev x")),
		(toolchain("link-../x"), refused("link-../x")),
		(toolchain("copy-a\\b"), refused("copy-a\\b")),
	]
	bad = rows.keep_if(|(got, want)| got != want).map(|(got, want)| (want, got))
	dbg bad
	bad == []
}
