import lib.Db
import lib.Fail

DbTest :: [].{}

h1 = "9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17"

h2 = "Bz7g9mTqU2oV4tG3a1kKfWm5cD8xNqL6RrPjYsHe2vZu"

nt = "nightly-2026-10-14-38a3029"

sha_a = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

sha_b = "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210"

pass_row : Db.Fact
pass_row = { hash: h1, nightly: nt, target: "any", outcome: Pass, modules: [], closure: "" }

fail_row : Db.Fact
fail_row = { hash: h2, nightly: nt, target: "any", outcome: Fail, modules: ["Yaml.roc", "Json.roc"], closure: "" }

build_row : Db.Fact
build_row = { hash: h1, nightly: nt, target: "linux_x86_64", outcome: Pass, modules: [], closure: "c0ffee" }

# R-NS12: a release is a compiler id in the same column.
release_row : Db.Fact
release_row = { hash: h1, nightly: "0.1.0", target: "any", outcome: Hang, modules: [], closure: "" }

pin_row : Db.Pinned
pin_row = { tag: nt, target: "linux_x86_64", sha256: sha_a, source: GithubDigest }

# R-TF1 R-CC8: the format that this Talon writes is 1 (`PRAGMA user_version`), the busy timeout is 5000 ms.
expect Db.format == 1 and Db.busy_ms == 5000

# R-P4 R-CV6 R-PK7: the words of the text columns. All 4 outcomes and both sources. Any other word is `BadWord` (the case counts: `Pass` is not `pass`).
expect {
	outcomes = [Pass, Fail, Hang, Crash]
	words = outcomes.map(Db.outcome_word)
	back = words.map(Db.outcome_of)
	sources = [GithubDigest, Registry]
	swords = sources.map(Db.source_word)
	sback = swords.map(Db.source_of)
	bad = [
		(words == ["pass", "fail", "hang", "crash"], "outcome words"),
		(back == [Ok(Pass), Ok(Fail), Ok(Hang), Ok(Crash)], "outcome round trip"),
		(Db.outcome_of("Pass") == Err(BadWord), "outcome case"),
		(Db.outcome_of("") == Err(BadWord), "outcome empty"),
		(Db.outcome_of("passed") == Err(BadWord), "outcome other"),
		(swords == ["github-digest", "registry"], "source words"),
		(sback == [Ok(GithubDigest), Ok(Registry)], "source round trip"),
		(Db.source_of("github") == Err(BadWord), "source other"),
		(Db.source_of("") == Err(BadWord), "source empty"),
	].keep_if(|(holds, _)| !holds).map(|(_, label)| label)
	dbg bad
	bad == []
}

# R-P4: the column `modules` is a set: sorted by byte order, no repeat, joined with `,`. The reverse splits at `,`, and the empty text is no module.
expect {
	rows = [
		(Db.modules_text([]), ""),
		(Db.modules_text(["Yaml.roc"]), "Yaml.roc"),
		(Db.modules_text(["Yaml.roc", "Json.roc"]), "Json.roc,Yaml.roc"),
		(Db.modules_text(["b.roc", "B.roc", "a/c.roc", "B.roc"]), "B.roc,a/c.roc,b.roc"),
		(Db.modules_text(["Z.roc", "Z.roc"]), "Z.roc"),
		(Str.inspect(Db.modules_of("")), "[]"),
		(Str.inspect(Db.modules_of("Json.roc,Yaml.roc")), "[\"Json.roc\", \"Yaml.roc\"]"),
		(Str.inspect(Db.modules_of("Only.roc")), "[\"Only.roc\"]"),
	]
	bad = rows.keep_if(|(got, want)| got != want).map(|(got, want)| (got, want))
	dbg bad
	bad == []
}

# R-PK7 R-P4 R-NS12 R-CV6: the line of a row (`fact` with 6 fields, `pinned` with 4), the reverse, and the lines that are not rows. The `modules` field is the sorted set. A release is a compiler id (R-NS12).
expect {
	lines = [
		(Db.fact_line(pass_row), "fact\t${h1}\t${nt}\tany\tpass\t\t"),
		(Db.fact_line(fail_row), "fact\t${h2}\t${nt}\tany\tfail\tJson.roc,Yaml.roc\t"),
		(Db.fact_line(build_row), "fact\t${h1}\t${nt}\tlinux_x86_64\tpass\t\tc0ffee"),
		(Db.fact_line(release_row), "fact\t${h1}\t0.1.0\tany\thang\t\t"),
		(Db.fact_line({ ..pass_row, outcome: Crash }), "fact\t${h1}\t${nt}\tany\tcrash\t\t"),
		(Db.pinned_line(pin_row), "pinned\t${nt}\tlinux_x86_64\t${sha_a}\tgithub-digest"),
		(Db.pinned_line({ ..pin_row, source: Registry }), "pinned\t${nt}\tlinux_x86_64\t${sha_a}\tregistry"),
	]
	bad_lines = lines.keep_if(|(got, want)| got != want).map(|(got, want)| (got, want))
	# A row with its modules in another order comes back sorted.
	back = [
		(Db.parse_line(Db.fact_line(pass_row)) == Ok(Fact(pass_row)), "pass"),
		(Db.parse_line(Db.fact_line(fail_row)) == Ok(Fact({ ..fail_row, modules: ["Json.roc", "Yaml.roc"] })), "fail, sorted"),
		(Db.parse_line(Db.fact_line(build_row)) == Ok(Fact(build_row)), "build"),
		(Db.parse_line(Db.fact_line(release_row)) == Ok(Fact(release_row)), "release"),
		(Db.parse_line(Db.pinned_line(pin_row)) == Ok(Pinned(pin_row)), "pinned"),
		(Db.parse_line(Db.pinned_line({ ..pin_row, source: Registry })) == Ok(Pinned({ ..pin_row, source: Registry })), "pinned registry"),
	]
	bad_back = back.keep_if(|(holds, _)| !holds).map(|(_, label)| label)
	not_rows = [
		"",
		"fact",
		"fact\t${h1}\t${nt}\tany\tpass\t",
		"fact\t${h1}\t${nt}\tany\tpass\t\t\textra",
		"fact\t${h1}\t${nt}\tany\tPass\t\t",
		"pinned\t${nt}\tlinux_x86_64\t${sha_a}",
		"pinned\t${nt}\tlinux_x86_64\t${sha_a}\tgithub",
		"format\t1",
		"other\ta\tb\tc\td",
	]
	bad_rows = not_rows.keep_if(|line| Db.parse_line(line) != Err(BadLine))
	dbg (bad_lines, bad_back, bad_rows)
	bad_lines == [] and bad_back == [] and bad_rows == []
}

# R-PK7 R-TF1: the text of a store. The `format` line first, the `fact` lines sorted by (hash, nightly, target), then the `pinned` lines sorted by (tag, target), each with a line end. The input order does not change the text.
# The empty text is a new file (format 0). A text that does not start with a `format` line, or has a bad line, is `BadLine`.
expect {
	facts = [fail_row, release_row, build_row, pass_row]
	more = { ..pin_row, tag: "0.1.0" }
	pinned = [pin_row, more, { ..pin_row, target: "linux_arm64" }]
	text = Db.file_text({ format: 1, facts, pinned })
	want = Str.join_with(
		[
			"format\t1",
			Db.fact_line(release_row),
			Db.fact_line(pass_row),
			Db.fact_line(build_row),
			Db.fact_line({ ..fail_row, modules: ["Json.roc", "Yaml.roc"] }),
			Db.pinned_line(more),
			Db.pinned_line({ ..pin_row, target: "linux_arm64" }),
			Db.pinned_line(pin_row),
			"",
		],
		"\n",
	)
	same = Db.file_text({ format: 1, facts: facts.rev(), pinned: pinned.rev() }) == text
	parsed = Db.parse_file(text)
	back_ok = match parsed {
		Ok(store) => store.format == 1 and store.facts.len() == 4 and store.pinned.len() == 3 and Db.file_text(store) == text
		Err(_) => Bool.False
	}
	empty = Db.parse_file("") == Ok({ format: 0, facts: [], pinned: [] })
	only_format = Db.file_text({ format: 1, facts: [], pinned: [] }) == "format\t1\n"
	bad_text = [
		"fact\t${h1}\t${nt}\tany\tpass\t\t\n",
		"format\tx\n",
		"format\t1\nnonsense\n",
		"format\t1\nfact\tshort\n",
	].keep_if(|t| Db.parse_file(t) != Err(BadLine))
	dbg (text == want, same, back_ok, empty, only_format, bad_text)
	text == want and same and back_ok and empty and only_format and bad_text == []
}

# R-TF3 R-CC8: what a command does with a failed db call. `TooNew(n)` stops with kind Input (exit 19) and the message names the file, both numbers and `tln tool update talon`.
# `Busy` and `Failed` are warnings (the facts of the command stay in memory): a write says that the facts are not saved, a read says that Talon goes on with no saved facts. Both name `compat.db`.
expect {
	path = "/c/roc/talon/compat.db"
	too_new = Db.on_err({ err: TooNew(2), what: Write, path })
	same_for_read = Db.on_err({ err: TooNew(7), what: Read, path })
	want_new = Fail.new(Input, "${path} has format 2. This tln writes format 1. Run: tln tool update talon")
	want_read = Fail.new(Input, "${path} has format 7. This tln writes format 1. Run: tln tool update talon")
	busy_write = Db.on_err({ err: Busy, what: Write, path })
	busy_read = Db.on_err({ err: Busy, what: Read, path })
	failed_write = Db.on_err({ err: Failed("file is not a database"), what: Write, path })
	failed_read = Db.on_err({ err: Failed("file is not a database"), what: Read, path })
	rows = [
		(too_new == Stop(want_new), "too new, write"),
		(same_for_read == Stop(want_read), "too new, read"),
		(busy_write == Warn("compat.db is busy: the facts of this command are not saved"), "busy write"),
		(busy_read == Warn("compat.db is busy: Talon goes on with no saved facts"), "busy read"),
		(failed_write == Warn("cannot use ${path} (file is not a database): the facts of this command are not saved. Removing the file resets the stored facts and the first-seen sha256 of compilers."), "failed write"),
		(failed_read == Warn("cannot use ${path} (file is not a database): Talon goes on with no saved facts. Removing the file resets the stored facts and the first-seen sha256 of compilers."), "failed read"),
	]
	bad = rows.keep_if(|(holds, _)| !holds).map(|(_, label)| label)
	dbg bad
	bad == []
}

# R-P4 R-BS2 (slice 032): the primary key of `facts` has the digest, so one key can have more than one row. The `fact` lines are sorted by (hash, nightly, target, closure): the input order does not change the text.
expect {
	low = { ..build_row, closure: "a1" }
	high = { ..build_row, outcome: Fail, closure: "b2" }
	check = { ..build_row, target: "any", closure: "" }
	text = |facts| Db.file_text({ format: 1, facts, pinned: [] })
	want = Str.join_with(["format\t1", Db.fact_line(check), Db.fact_line(low), Db.fact_line(high), ""], "\n")
	dbg (text([high, check, low]) == want, text([low, high, check]) == want)
	text([high, check, low]) == want and text([low, high, check]) == want
}
