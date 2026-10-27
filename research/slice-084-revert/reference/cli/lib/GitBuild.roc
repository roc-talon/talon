import Clock
import Download
import Fail
import GitRef
import Item
import JsonDoc
import Manage
import Nightlies
import Roots
import TalonFile
import Temp
import Text

## The pure decisions of a source build (slice 045, CLI 6.6, R-R1, R-R3, R-R5 to R-R7, R-SE12): the paths, the `zig build` command, `.talon.json`, the failures and the choice of `roc default --git`.
## The tests are `tests/unit/GitTest.roc`. Texts that the design does not give are a proposal (TW24): `docs/slices/045-git-install.md`, section "Output".
GitBuild :: [].{

	## The paths of one build. `item` is the toolchain dir (`Roots.item(roots, Toolchain(id))`). `temp` is `Temp.name({ target: item, hex })`. `scratch` is `Roots.item(roots, TalonTmp(hex))`, the dir of the archive and the source.
	## The dir is not in the toolchain dir, so a failed build leaves nothing for `roc list`.
	Plan : { id : Str, item : Str, temp : Str, scratch : Str, archive : Str, src : Str, zon : Str, built : Str, roc : Str, meta : Str, probe_file : Str }

	## The paths. `hex` is the random text of this run (`fx.random!`).
	##
	## | Field | Text |
	## | --- | --- |
	## | `archive` | `<scratch>/source.tar.gz` |
	## | `src` | `<scratch>/src` (tar extracts here, the top dir of the archive is cut) |
	## | `zon` | `<src>/build.zig.zon` |
	## | `built` | `<src>/zig-out/bin/roc` (`roc.exe` on `WindowsX64` and `WindowsArm64`) |
	## | `roc`, `meta` | `<temp>/roc` (`roc.exe`), `<temp>/.talon.json` |
	## | `probe_file` | `<scratch>/empty.roc` (the file for the compat check, R-SE9) |
	plan : { roots : Roots, host : Nightlies.Host, id : Str, hex : Str } -> GitBuild.Plan
	plan = |facts| {
		item = Roots.item(facts.roots, Item.Toolchain(facts.id))
		temp = Temp.name({ target: item, hex: facts.hex })
		scratch = Roots.item(facts.roots, Item.TalonTmp(facts.hex))
		src = Text.join(scratch, "src")
		program = match facts.host {
			WindowsX64 | WindowsArm64 => "roc.exe"
			_ => "roc"
		}
		{
			id: facts.id,
			item,
			temp,
			scratch,
			archive: Text.join(scratch, "source.tar.gz"),
			src,
			zon: Text.join(src, "build.zig.zon"),
			built: Text.join(src, "zig-out/bin/${program}"),
			roc: Text.join(temp, program),
			meta: Text.join(temp, ".talon.json"),
			probe_file: Text.join(scratch, "empty.roc"),
		}
	}

	## R-R3: `[zig, "build", "roc", "-Doptimize=ReleaseFast", "-Dcompiler-version=<id>"]` (`zig` is the path of the Zig binary).
	build_command : { zig : Str, id : Str } -> List(Str)
	build_command = |facts| [facts.zig, "build", "roc", "-Doptimize=ReleaseFast", "-Dcompiler-version=${facts.id}"]

	## R-R1, R-R7: the text of `.talon.json` (`TalonFile.render`, format 1). The fields in this order: `id`, `repo` (`GitRef.repo_url`), `sha` (full), `ref` (as typed), `sha256` (of the archive),
	## `sha256_source` (`"computed"`), `compat` (a text, or null for `Unknown` or `Several`), `installed_at` (`Clock.format_utc`).
	meta : { id : Str, source : GitRef.Source, sha : Str, sha256 : Str, compat : Try(Str, [Unknown, Several(List(Str))]), now : U64 } -> Str
	meta = |facts| {
		compat = match facts.compat {
			Ok(id) => JsonDoc.Text(id)
			Err(_) => JsonDoc.Null
		}
		TalonFile.render({
			format: 1,
			fields: [
				("id", JsonDoc.Text(facts.id)),
				("repo", JsonDoc.Text(GitRef.repo_url(facts.source))),
				("sha", JsonDoc.Text(facts.sha)),
				("ref", JsonDoc.Text(facts.source.ref)),
				("sha256", JsonDoc.Text(facts.sha256)),
				("sha256_source", JsonDoc.Text("computed")),
				("compat", compat),
				("installed_at", JsonDoc.Text(Clock.format_utc(facts.now))),
			],
		})
	}

	## The failure of `zig build`: kind `Internal` (exit 1). Text: `zig build of <id> failed (<how>)` and `: <last line>` when the last line of the output is not empty.
	## `how` is `exit <n>`, `signal <n>`, or `did not start: <why>`.
	build_failed : { id : Str, ended : Download.Ended, last_line : Str } -> Fail
	build_failed = |facts| {
		how = match facts.ended {
			Exited(code) => "exit ${code.to_str()}"
			Signaled(code) => "signal ${code.to_str()}"
			NotStarted(why) => "did not start: ${why}"
		}
		last = facts.last_line.trim()
		tail = if last.is_empty() "" else ": ${last}"
		Fail.new(Internal, "zig build of ${facts.id} failed (${how})${tail}")
	}

	## `zig build` ended with 0 and there is no roc in `zig-out/bin`: kind `Internal`: `zig build of <id> made no roc in zig-out/bin`.
	no_binary : Str -> Fail
	no_binary = |id| Fail.new(Internal, "zig build of ${id} made no roc in zig-out/bin")

	## R-R5, R-R6: the newest installed build of one repo and ref, from the `.talon.json` texts of the `git-*` toolchains. A row counts when the text is JSON with text fields `repo` equal to `GitRef.repo_url(source)`,
	## `ref` equal to the typed ref, and an `installed_at` that `Clock.parse_utc` reads. Review Q6: when the typed ref is 7 to 40 lower case hex digits, a row also counts when its `sha` field starts with the typed ref
	## (so `roc default --git @dd03c09e` finds the build of the branch `main` that was made at that commit). The latest `installed_at` wins by time (not by text). The same time: the last row. A row that is unreadable, not JSON, or has
	## no such field is skipped. No row: `Err(None)`.
	newest : { source : GitRef.Source, rows : List({ id : Str, text : Manage.Read }) } -> Try(Str, [None])
	newest = |facts| {
		found = facts.rows.fold(
			{ id: "", at: 0, any: Bool.False },
			|best, row| match built_at(facts.source, row.text) {
				Ok(at) => if !best.any or at >= best.at { id: row.id, at, any: Bool.True } else best
				Err(NoMatch) => best
			},
		)
		if found.any Ok(found.id) else Err(None)
	}

	## R-R5: no build of that repo and ref: kind `Usage`: `no build of <owner>/<repo>@<ref> is installed. Run: tln roc install --git <owner>/<repo>@<ref>`.
	none_installed : GitRef.Source -> Fail
	none_installed = |source| {
		name = GitRef.name_text(source)
		Fail.new(Usage, "no build of ${name} is installed. Run: tln roc install --git ${name}")
	}
}

# The `installed_at` of a build that is of the repo and the ref (R-R5, R-R6). A row that is not readable, or has no such field, does not match.
built_at : GitRef.Source, Manage.Read -> Try(U64, [NoMatch])
built_at = |source, read| match read {
	Ok(text) => match JsonDoc.parse(text) {
		Ok(Obj(fields)) => {
			repo = text_field(fields, "repo")
			ref = text_field(fields, "ref")
			sha = text_field(fields, "sha")
			at = text_field(fields, "installed_at")
			same_repo = repo == Ok(GitRef.repo_url(source))
			same_ref = ref == Ok(source.ref) or (is_sha_text(source.ref) and sha_starts(sha, source.ref))
			if same_repo and same_ref {
				match at {
					Ok(when) => Clock.parse_utc(when).map_err(|_| NoMatch)
					Err(_) => Err(NoMatch)
				}
			} else {
				Err(NoMatch)
			}
		}
		_ => Err(NoMatch)
	}
	Err(_) => Err(NoMatch)
}

text_field : List((Str, JsonDoc)), Str -> Try(Str, [NoField])
text_field = |fields, name| match fields.find_first(|(key, _)| key == name) {
	Ok((_, Text(value))) => Ok(value)
	_ => Err(NoField)
}

sha_starts : Try(Str, [NoField]), Str -> Bool
sha_starts = |sha, prefix| match sha {
	Ok(full) => full.starts_with(prefix)
	Err(_) => Bool.False
}

# Review Q6: 7 to 40 lower case hex digits can be the start of a full sha.
is_sha_text : Str -> Bool
is_sha_text = |text| {
	size = text.count_utf8_bytes()
	size >= 7 and size <= 40 and text.to_utf8().all(|byte| (byte >= '0' and byte <= '9') or (byte >= 'a' and byte <= 'f'))
}
