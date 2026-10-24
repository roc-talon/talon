app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Clock
import lib.Compiler
import lib.Fail
import lib.Toolchain

main! = |_args| Ok({})

n1 = "nightly-2026-10-14-38a3029"

n2 = "nightly-2026-10-09-258ab27"

# R-SO7 R-SO9 R-SO10 R-SO11 R-PH6: the compiler on `PATH` is the one installed compiler. Its id is in the stdout of `roc version`. A nightly or a release is an
# installed compiler (R-SO10). Another id is a local build (R-SO11), and with no `roc` there is no compiler: both are `NoCompiler` for the resolve (slice 005).
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

	paths = [
		(Ok("Roc compiler version ${n1}\n"), Ok(n1)),
		(Ok("Roc compiler version 0.1.0\n"), Ok("0.1.0")),
		(Ok("Roc compiler version debug-3f9a1c2\n"), Err(NoCompiler)),
		(Ok("not a version"), Err(NoCompiler)),
		(Err(NoRoc), Err(NoCompiler)),
	]
	bad_paths = paths.keep_if(|(text, want)| Compiler.on_path(text) != want).map(|(text, want)| (text, want))
	dbg bad_paths
	bad_versions == [] and bad_kinds == [] and bad_paths == []
}

# R-PH7 R-PH6 R-BL3 R-DL5 R-EC13: a probe needs a compiler. The only installed compiler is the `roc` on `PATH`. Any other id is a required download, and P0 refuses
# it with exit code 13 (kind consent). The message names the id and says that tln runs only the `roc` on `PATH`. It does not name `--allow-downloads` or
# `TALON_AUTO_INSTALL` (P0 does not read them).
expect {
	refuse = |id, path_roc| Compiler.require({ id, path_roc })
	rows = [
		(refuse(n1, Ok(n1)), Ok({})),
		(refuse("0.1.0", Ok("0.1.0")), Ok({})),
		(
			refuse(n2, Ok(n1)),
			Err(Fail.new(Consent, "the compiler ${n2} is not installed. This version of tln runs only the roc on PATH (${n1}).")),
		),
		(
			refuse("0.1.0", Ok(n1)),
			Err(Fail.new(Consent, "the compiler 0.1.0 is not installed. This version of tln runs only the roc on PATH (${n1}).")),
		),
		(
			refuse(n1, Err(NoCompiler)),
			Err(Fail.new(Consent, "the compiler ${n1} is not installed. This version of tln runs only the roc on PATH, and there is none.")),
		),
	]
	bad = rows.keep_if(|(got, want)| got != want).map(|(got, want)| (got, want))
	dbg bad
	refused = refuse(n2, Ok(n1))
	text = match refused {
		Err(f) => f.message
		Ok(_) => ""
	}
	code = match refused {
		Err(f) => f.kind.code()
		Ok(_) => 0
	}
	bad == [] and code == 13 and !text.contains("--allow-downloads") and !text.contains("TALON_AUTO_INSTALL") and !text.contains("P0")
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

# R-SO14 R-SO13 R-EC18 R-EC13 (slice 022, G2 of the review): the failures of `select`. No rank: exit 18, the text names the 2 commands that fix it. No installed compiler in `[toolchain] roc`: exit 13, the refusal of P0 (a
# download needs the consent of slice 025), and the text names the range.
expect {
	none = Compiler.failure(NoCompiler)
	range = Compiler.failure(NoneInRange(">=${a4}"))
	none.kind.code() == 18 and none.message == "no compiler is selected. Run: tln roc install @latest, then tln roc default <id>" and range.kind.code() == 13 and range.message == "no installed compiler is in [toolchain] roc (>=${a4}). This version of tln does not download a compiler for a run."
}
