import lib.PublishCheck

PublishCheckTest :: [].{}

# Slice 222 (docs/slices/222-publish-api-check.md; Registry R-PU39, R-AP13; Design Q31): the pure part of the API check of `tln publish`. The flow is the L2 cases `publish/pu16` and the changed `pu1` to `pu15`.
# The texts are proposals for the review (R-OUT2, TW24).

form = "github.com/acme/json/releases/download/{v}/"

# A release row of the answer of R-AP13 (R-AP49). `yanked` is the only member that the check reads, with `version` and `url`.
row = |version, yanked| {
	log_index: 1,
	hash: "h${version}",
	group: form,
	series: "1",
	version,
	url: "https://github.com/acme/json/releases/download/${version}/h${version}.tar.zst",
	tag: Ok(version),
	roc_version: Err(None),
	repo: Ok("acme/json"),
	published_at: 1000,
	yanked,
	yank_reason: if yanked Ok("bad") else Err(None),
	withdrawn: Err(None),
	provenance: ["oidc"],
}

# The version of the previous release, or `none`.
prev = |version, rows| match PublishCheck.previous({ version, rows }) {
	Ok(found) => found.version
	Err(NoPrevious) => "none"
}

# R-PU39, R-AP13: the previous release is the row with the largest version that is smaller than the new version and not yanked. The order of the rows does not matter. A version of another series (1.9.0 for 2.1.0) counts: the answer has all series of the URL form.
expect {
	rows = [row("1.0.0", Bool.False), row("2.0.0", Bool.False), row("1.9.0", Bool.False), row("2.0.5", Bool.False), row("3.0.0", Bool.False)]
	prev("2.1.0", rows) == "2.0.5"
		and prev("2.1.0", rows.rev()) == "2.0.5"
			and prev("2.0.5", rows) == "2.0.0"
				and prev("2.0.0", rows) == "1.9.0"
					and prev("10.0.0", rows) == "3.0.0"
						# the order of versions is by number, not by text (1.10.0 is larger than 1.9.0)
						and prev("2.0.0", [row("1.9.0", Bool.False), row("1.10.0", Bool.False)]) == "1.10.0"
}

# R-PU39: a yanked release is never the previous release. The check goes to the newest release below that is not yanked.
expect {
	rows = [row("2.0.5", Bool.True), row("2.0.0", Bool.False), row("1.9.0", Bool.False)]
	prev("2.1.0", rows) == "2.0.0"
		and prev("2.1.0", [row("2.0.5", Bool.True), row("2.0.0", Bool.True)]) == "none"
}

# R-PU39: the same version (a publish again of the same label, another hash) and larger versions are never the previous release. An empty answer (R-AP13: a group with no release) and the first release have none.
expect {
	prev("2.1.0", []) == "none"
		and prev("2.1.0", [row("2.1.0", Bool.False)]) == "none"
			and prev("2.1.0", [row("3.0.0", Bool.False), row("2.1.1", Bool.False), row("2.1.0", Bool.False)]) == "none"
				and prev("1.0.0", [row("1.0.0", Bool.False), row("1.0.1", Bool.False)]) == "none"
}

# R-PU39: the result is the whole row, so the flow has its `url` (the `--old` argument).
expect {
	PublishCheck.previous({ version: "2.1.0", rows: [row("2.0.0", Bool.False), row("3.0.0", Bool.False)] }).map_ok(|found| found.url)
		== Ok("https://github.com/acme/json/releases/download/2.0.0/h2.0.0.tar.zst")
}

# R-PU39, Q524: the command line is `roc bump --old <URL> --expect <version> <file>`: the arguments after the program, 6 words, with the values as they are given (no quote, no change).
expect {
	PublishCheck.bump_args({ old: "https://github.com/acme/json/releases/download/2.0.0/h2.0.0.tar.zst", version: "2.1.0", file: "/w/p/main.roc" })
		== ["bump", "--old", "https://github.com/acme/json/releases/download/2.0.0/h2.0.0.tar.zst", "--expect", "2.1.0", "/w/p/main.roc"]
		and PublishCheck.bump_args({ old: "u", version: "v", file: "f" }) == ["bump", "--old", "u", "--expect", "v", "f"]
}

# R-PU39, Q529: a withdrawn row and a row with a pre-release version are never the previous release (`roc bump` refuses a pre-release version). The row below them is the result.
expect {
	wrow = |version| { ..row(version, Bool.False), withdrawn: Ok("gone") }
	prev("2.1.0", [wrow("2.0.5"), row("2.0.0", Bool.False)]) == "2.0.0"
		and prev("2.1.0", [row("2.0.5-rc.1", Bool.False), row("2.0.0", Bool.False)]) == "2.0.0"
			and prev("2.1.0", [wrow("2.0.5"), row("2.0.0-rc.1", Bool.False)]) == "none"
}

# The texts of `roc bump` (research/roc-bump/results.txt, nightly 2026-10-14). The stdout of the 5 nightlies is the same. The two parts of a text are joined with a new line.
join = |parts| Str.join_with(parts, "\n")

head = |name| "── ✗ ${name} ─────────────────────────────────────────────────────────────────"

minor_out = join(["Comparing v1 (old, 1.0.0) with v2minor/main.roc (new)...", "", "---- Greet - MINOR ----", "", "    + Greet.bye : Str -> Str", "", "This is a MINOR change.", "", "1.0.0 -> 1.1.0"])

minor_err = join([head("insufficient version bump"), "", "roc bump failed.", "", "This is a MINOR change, so the next version must be at least 1.1.0, but --expect was 1.0.1.", "", ""])

# The nightly of 2026-10-31 wraps the sentence (results-worker-nightly.txt).
minor_err_wrapped = join([head("insufficient version bump"), "", "roc bump failed.", "", "This is a MINOR change, so the next version must be at least 1.1.0, but", "--expect was 1.0.1.", "", ""])

major_out = join(["Comparing v1 (old, 1.0.0) with v2major/main.roc (new)...", "", "---- Greet - MAJOR ----", "", "    - Greet.hello : Str -> Str", "    + Greet.hello : Str, Str -> Str", "", "This is a MAJOR change.", "", "1.0.0 -> 2.0.0"])

major_err = join([head("insufficient version bump"), "", "roc bump failed.", "", "This is a MAJOR change, so the next version must be at least 2.0.0, but --expect was 1.9.0.", "", ""])

pass_out = join(["Comparing v1 (old, 1.0.0) with v2minor/main.roc (new)...", "", "This is a MINOR change.", "", "1.0.0 -> 1.1.0", "", "1.1.0 satisfies the required MINOR bump."])

back_out = join(["Comparing v1 (old, 1.0.0) with v2patch/main.roc (new)...", "", "No API changes detected.", "", "This is a PATCH change.", "", "1.0.0 -> 1.0.1"])

back_err = join([head("insufficient version bump"), "", "roc bump failed.", "", "The expected version 1.0.0 does not move forward from 1.0.0.", "", ""])

bad_err = join([head("name not in scope"), "", "Nothing is named nope in this scope.", "", "hello = |name| nope(name)", "               ^^^^", "", head("package does not compile"), "", "roc bump failed.", "", "The new package (bad/main.roc) does not compile with this compiler. roc bump needs both packages to compile so their public APIs can be compared.", "", ""])

# Q525: exit 0 passes. Exit 1 with the headline, `must be at least` and the 2 stdout lines is `Less` (LEVEL and next). The wrapped sentence reads the same.
expect {
	PublishCheck.verdict({ ended: Exited(0), stdout: pass_out, stderr: "" }) == Pass
		and PublishCheck.verdict({ ended: Exited(0), stdout: "", stderr: "" }) == Pass
			and PublishCheck.verdict({ ended: Exited(1), stdout: minor_out, stderr: minor_err }) == Less({ level: "MINOR", next: "1.1.0" })
				and PublishCheck.verdict({ ended: Exited(1), stdout: minor_out, stderr: minor_err_wrapped }) == Less({ level: "MINOR", next: "1.1.0" })
					and PublishCheck.verdict({ ended: Exited(1), stdout: major_out, stderr: major_err }) == Less({ level: "MAJOR", next: "2.0.0" })
}

# Q525: every other result is not `Less`. `does not move forward` has the headline and no `must be at least`. A compile error is `package does not compile` (the last headline). The headline without the stdout lines is not read (no guess).
expect {
	PublishCheck.verdict({ ended: Exited(1), stdout: back_out, stderr: back_err }) == Other("insufficient version bump")
		and PublishCheck.verdict({ ended: Exited(1), stdout: "", stderr: bad_err }) == Other("package does not compile")
			and PublishCheck.verdict({ ended: Exited(1), stdout: "", stderr: minor_err }) == Other("insufficient version bump")
				and PublishCheck.verdict({ ended: Exited(1), stdout: "Comparing...\n", stderr: minor_err }) == Other("insufficient version bump")
					# the stdout lines with no headline: a note, never a warning
					and PublishCheck.verdict({ ended: Exited(1), stdout: minor_out, stderr: join([head("download failed"), "", "roc bump failed.", ""]) }) == Other("download failed")
}

# Q525, Q526: the run that Talon cut, a signal and a program that did not start.
expect {
	PublishCheck.verdict({ ended: TimedOut, stdout: minor_out, stderr: minor_err }) == TimedOut
		and PublishCheck.verdict({ ended: Signaled(9), stdout: "", stderr: "" }) == Signaled(9)
			and PublishCheck.verdict({ ended: NotStarted("no such file"), stdout: "", stderr: "" }) == NotStarted("no such file")
}

# R-PU39, R-PUB4 item 13 (proposals, R-OUT2): the warning for `Less`, no line for a pass, the notes for the other results.
expect {
	lined = |verdict| PublishCheck.report({ verdict, old: "2.0.0", version: "2.0.1", timeout: 30 })
	lined(Less({ level: "MINOR", next: "2.1.0" }))
		== Ok({ kind: Warning, text: "2.0.1 bumps less than the API change of 2.0.0 needs: roc bump wants at least 2.1.0 (a MINOR change). The publish goes on." })
		and lined(Pass) == Err(Silent)
			and lined(Other("package does not compile"))
				== Ok({ kind: Note, text: "roc bump did not compare 2.0.0 and 2.0.1: package does not compile. The publish goes on." })
				and lined(TimedOut) == Ok({ kind: Note, text: "roc bump did not end in 30 s: no API check. The publish goes on." })
					and lined(NotStarted("no such file")) == Ok({ kind: Note, text: "roc bump could not start (no such file): no API check." })
}

# R-PUB4 item 13 (proposals): the note when no check can run, and the note for a group read that failed.
expect {
	PublishCheck.unavailable({ reason: "no project file" }) == "no API check: no project file"
		and PublishCheck.read_failed({ form, cause: "HTTP 503" })
			== "the releases of github.com/acme/json/releases/download/{v}/ could not be read (HTTP 503): roc bump did not run"
}

# R-PU39: the note of a first release (proposal).
expect {
	PublishCheck.first_note({ form, version: "2.1.0" })
		== "no earlier release of github.com/acme/json/releases/download/{v}/ before 2.1.0: roc bump did not run"
}

# Q532: exit 1 with no headline line gives `Other` with no cause. An exit code that is not 0 or 1 gives `exit code <n>`, and the stderr is not read (also with a headline and the stdout lines of a `Less`).
expect {
	PublishCheck.verdict({ ended: Exited(1), stdout: "", stderr: "Error: no value was supplied for --old\n" }) == Other("")
		and PublishCheck.verdict({ ended: Exited(2), stdout: minor_out, stderr: minor_err }) == Other("exit code 2")
			and PublishCheck.verdict({ ended: Exited(127), stdout: "", stderr: "" }) == Other("exit code 127")
}

# Q531, Q532 (proposals): the notes for a signal, for no cause, and for an exit code.
expect {
	lined = |verdict| PublishCheck.report({ verdict, old: "2.0.0", version: "2.0.1", timeout: 30 })
	lined(Signaled(9)) == Ok({ kind: Note, text: "roc bump ended with signal 9: no API check. The publish goes on." })
		and lined(Other("")) == Ok({ kind: Note, text: "roc bump did not compare 2.0.0 and 2.0.1. The publish goes on." })
			and lined(Other("exit code 2")) == Ok({ kind: Note, text: "roc bump did not compare 2.0.0 and 2.0.1: exit code 2. The publish goes on." })
}
