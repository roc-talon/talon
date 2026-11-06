import records.Release
import semver.Semver

## `tln publish`, the API check (slice 222; Registry R-PU39, R-AP13; Design 2, Q31). Pure decisions. The command code is `PublishFlow` (after the facts, before the token request).
## All texts are proposals for the review (R-OUT2, TW24). Not in this stub: the compiler of the `roc:` pin, the way that Talon runs `roc bump`, and the reading of its answer (the questions of `docs/slices/222-publish-api-check.md`).
PublishCheck :: [].{

	## R-PU39, R-AP13: the previous release. `rows` are the releases of the answer of `GET /v1/releases?group=<URL form>` (no `series`: all series of the URL form), in any order. `version` is the version of the new release.
	## The result is the row with the largest version that is smaller than `version` and is not yanked (`yanked` is false). A row with the same version, or a larger one, or a yanked one (`yanked`), or a withdrawn one (`withdrawn` is `Ok`, Q529), or one whose version has a pre-release part (`2.1.0-rc.1`: `roc bump` refuses it, Q529), is never the result. The order of the versions is the order of `Semver` (the field `version` is its text).
	## The order of the rows, `published_at` and `log_index` do not matter. No row that fits: `Err(NoPrevious)`.
	previous : { version : Str, rows : List(Release.Row) } -> Try(Release.Row, [NoPrevious])
	previous = |facts| match Semver.parse(facts.version) {
		Err(_) => Err(NoPrevious)
		Ok(target) => {
			fits = facts.rows.keep_oks(
				|row| {
					if row.yanked or row.withdrawn.is_ok() or is_pre(row.version) return Err(NoPrevious)
					match Semver.parse(row.version) {
						Ok(found) if found.order_relative_to(target) == Before => Ok((row, found))
						_ => Err(NoPrevious)
					}
				},
			)
			best = fits.sort_with(|(_, a), (_, b)| b.order_relative_to(a)).first()
			match best {
				Ok((row, _)) => Ok(row)
				Err(_) => Err(NoPrevious)
			}
		}
	}

	## R-PU39, Design Q524: the arguments of the compiler for the check, after the program, as one `Fx.probes!` spec: `bump --old <URL> --expect <version> <file>` (6 words). `old` is the `url` of the previous release (the whole URL of the asset, as the row has it). `version` is the version of the new release. `file` is the new package (the project file of the job, `--file`), as it is given.
	bump_args : { old : Str, version : Str, file : Str } -> List(Str)
	bump_args = |facts| ["bump", "--old", facts.old, "--expect", facts.version, facts.file]

	## How `Fx.probes!` ended the run (`Probe.Output.ended`).
	Ended : [Exited(I32), Signaled(I32), TimedOut, NotStarted(Str)]

	## Design Q525, R-PUB4 item 13: the reading of the run. `Pass`: exit 0 (whatever the text). `Less`: exit 1, and the stderr (white space joined, so a wrapped sentence reads) has the headline `insufficient version bump` and the words `must be at least`, and the stdout has a line `This is a <LEVEL> change.` and a line `<old> -> <next>`: `level` is `<LEVEL>` (`PATCH`, `MINOR`, `MAJOR`), `next` is the `<next>` of the line. `Other(headline)`: any other exit 1, or an exit code that is not 0 or 1: `headline` is the text of the last headline `── ✗ <headline> ──` of the stderr (the one before `roc bump failed.`). `TimedOut`, `NotStarted(text)`: as `ended`. `Signaled(n)`: a signal. Q532: exit 1 with no headline line is `Other("")` (no cause words). An exit code that is not 0 or 1 is `Other("exit code <n>")` and the stderr is not read.
	## Match the parts, never one whole line. A text that Talon cannot read is never `Less`.
	Verdict : [Pass, Less({ level : Str, next : Str }), Other(Str), TimedOut, Signaled(I32), NotStarted(Str)]
	verdict : { ended : PublishCheck.Ended, stdout : Str, stderr : Str } -> PublishCheck.Verdict
	verdict = |facts| match facts.ended {
		TimedOut => TimedOut
		Signaled(n) => Signaled(n)
		NotStarted(text) => NotStarted(text)
		Exited(0) => Pass
		Exited(1) => read_one(facts.stdout, facts.stderr)
		Exited(n) => Other("exit code ${n.to_str()}")
	}

	## R-PU39, R-PUB4 item 13 (proposal, R-OUT2): the line for a verdict, with its kind (the flow writes `warning: ` or `note: ` and a new line on stderr). `Pass`: `Err(Silent)` (no line). `old` is the version of the previous release, `timeout` is `probe.timeout` in seconds.
	## | Verdict | Kind | Text |
	## | --- | --- | --- |
	## | `Less` | Warning | `<version> bumps less than the API change of <old> needs: roc bump wants at least <next> (a <LEVEL> change). The publish goes on.` |
	## | `Other` | Note | `roc bump did not compare <old> and <version>: <headline>. The publish goes on.` |
	## | `TimedOut` | Note | `roc bump did not end in <timeout> s: no API check. The publish goes on.` |
	## | `NotStarted` | Note | `roc bump could not start (<text>): no API check.` |
	## | `Signaled(n)` | Note | `roc bump ended with signal <n>: no API check. The publish goes on.` (Q531) |
	## | `Other("")` | Note | `roc bump did not compare <old> and <version>. The publish goes on.` (Q532, no cause words) |
	report : { verdict : PublishCheck.Verdict, old : Str, version : Str, timeout : U64 } -> Try({ kind : [Warning, Note], text : Str }, [Silent])
	report = |facts| {
		old = facts.old
		version = facts.version
		match facts.verdict {
			Pass => Err(Silent)
			Less(wanted) => Ok({ kind: Warning, text: "${version} bumps less than the API change of ${old} needs: roc bump wants at least ${wanted.next} (a ${wanted.level} change). The publish goes on." })
			Other("") => Ok({ kind: Note, text: "roc bump did not compare ${old} and ${version}. The publish goes on." })
			Other(cause) => Ok({ kind: Note, text: "roc bump did not compare ${old} and ${version}: ${cause}. The publish goes on." })
			TimedOut => Ok({ kind: Note, text: "roc bump did not end in ${facts.timeout.to_str()} s: no API check. The publish goes on." })
			Signaled(n) => Ok({ kind: Note, text: "roc bump ended with signal ${n.to_str()}: no API check. The publish goes on." })
			NotStarted(text) => Ok({ kind: Note, text: "roc bump could not start (${text}): no API check." })
		}
	}

	## R-PUB4 item 13 (proposal): the note when no check can run: `no API check: <reason>`. The reasons are given by the flow (`no project file`, `the project file is not a package`, `no compiler`).
	unavailable : { reason : Str } -> Str
	unavailable = |facts| "no API check: ${facts.reason}"

	## R-PUB4 item 13, Design Q527 (proposal): the note for a group read that failed: `the releases of <form> could not be read (<cause>): roc bump did not run`.
	read_failed : { form : Str, cause : Str } -> Str
	read_failed = |facts| "the releases of ${facts.form} could not be read (${facts.cause}): roc bump did not run"

	## R-PU39: the note for a first release (no previous release, no `roc bump` run) (proposal). `form` is the URL form of the group (`Ident.group.form`), `version` the new version.
	## Text: `no earlier release of <form> before <version>: roc bump did not run`. The flow writes it to stderr with the prefix `note: ` and a new line.
	first_note : { form : Str, version : Str } -> Str
	first_note = |facts| "no earlier release of ${facts.form} before ${facts.version}: roc bump did not run"
}

# A version with a pre-release part (`roc bump` refuses it, Q529). Build metadata after `+` is not read.
is_pre : Str -> Bool
is_pre = |version| (version.split_on("+").first() ?? version).contains("-")

# Exit 1 (Q525, Q532): `Less` only with the headline, `must be at least` and both stdout lines. Else `Other` with the last headline.
read_one : Str, Str -> PublishCheck.Verdict
read_one = |stdout, stderr| {
	joined = Str.join_with(stderr.split_on("\n").map(|line| line.trim()).keep_if(|line| !line.is_empty()), " ")
	headline = last_headline(stderr)
	level = stdout_level(stdout)
	next = stdout_next(stdout)
	match (level, next) {
		(Ok(lv), Ok(nx)) if headline == Ok("insufficient version bump") and joined.contains("must be at least") => Less({ level: lv, next: nx })
		_ => Other(headline ?? "")
	}
}

# The text of the last line `── ✗ <name> ──` of the stderr.
last_headline : Str -> Try(Str, [None])
last_headline = |stderr| {
	names = stderr.split_on("\n").keep_oks(
		|line| {
			text = line.trim()
			if text.starts_with("── ✗ ") {
				inner = text.drop_prefix("── ✗ ")
				name = (inner.split_on(" ─").first() ?? inner).trim()
				if name.is_empty() Err(None) else Ok(name)
			} else {
				Err(None)
			}
		},
	)
	names.last().map_err(|_| None)
}

# `This is a <LEVEL> change.` of the stdout.
stdout_level : Str -> Try(Str, [None])
stdout_level = |stdout| {
	found = stdout.split_on("\n").keep_oks(
		|line| {
			text = line.trim()
			if text.starts_with("This is a ") and text.ends_with(" change.") {
				level = text.drop_prefix("This is a ").drop_suffix(" change.")
				if level == "PATCH" or level == "MINOR" or level == "MAJOR" Ok(level) else Err(None)
			} else {
				Err(None)
			}
		},
	)
	found.first().map_err(|_| None)
}

# `<old> -> <next>` of the stdout.
stdout_next : Str -> Try(Str, [None])
stdout_next = |stdout| {
	found = stdout.split_on("\n").keep_oks(
		|line| match line.trim().split_on(" -> ") {
			[old, next] if !old.is_empty() and !next.is_empty() and !old.contains(" ") and !next.contains(" ") => Ok(next)
			_ => Err(None)
		},
	)
	found.first().map_err(|_| None)
}
