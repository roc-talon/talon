import lib.Args
import lib.Fail
import lib.JsonDoc
import lib.Locked
import lib.Manage

ManageTest :: [].{}

# The expected value of each row is the design text or the slice file text, not the code. A wrong row prints with `dbg`.
# Texts and `data` fields that the design does not give are the proposals of docs/slices/024-roc-manage.md (TW24).

# One `.talon.json` text. `at` is the `installed_at` field.
meta : Str -> Str
meta = |at| "{\"format\":1,\"id\":\"x\",\"installed_at\":\"${at}\",\"compat\":null}"

# A header with a `roc:` entry (the pin), or none.
header : Try(Str, [NoPin]) -> Str
header = |pin| {
	roc = match pin {
		Ok(id) => "\n\troc: \"${id}\","
		Err(NoPin) => ""
	}
	"app [main!] {\n\tpf: platform \"https://github.com/acme/pf/releases/download/0.1.0/895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw.tar.zst\",${roc}\n}\n\nmain! = |_args| Ok({})\n"
}

# R-CM15, R-CM19: the operand of `roc default` and `roc remove`: one text as typed. No operand and 2 or more are usage failures (exit 2). The text names the long form (`remove`, `list`), also for `rm` and `ls`.
expect {
	read = |verb, words| match Args.parse(words) {
		Ok(args) => Manage.read({ args, verb })
		Err(_) => Err(Fail.new(Internal, "the test words do not parse"))
	}
	rows = [
		(Default, ["roc", "default", "nightly-2026-10-09-258ab27"], Ok("nightly-2026-10-09-258ab27")),
		(Default, ["roc", "default", "git-dd03", "--yes", "--json"], Ok("git-dd03")),
		(Default, ["roc", "default", "--git", "Karakatiza666/roc@my-branch"], Ok("Karakatiza666/roc@my-branch")),
		(Default, ["roc", "default"], Err(Fail.new(Usage, "tln roc default needs one compiler: a full id, a prefix or @latest"))),
		(Default, ["roc", "default", "a", "b"], Err(Fail.new(Usage, "tln roc default takes one compiler, got 2"))),
		(Remove, ["roc", "rm", "nightly-2026-10-09-258ab27"], Ok("nightly-2026-10-09-258ab27")),
		(Remove, ["roc", "remove", "link-dev", "--json"], Ok("link-dev")),
		(Remove, ["roc", "rm"], Err(Fail.new(Usage, "tln roc remove needs one compiler: a full id or a prefix of an installed compiler"))),
		(Remove, ["roc", "rm", "a", "b", "c"], Err(Fail.new(Usage, "tln roc remove takes one compiler, got 3"))),
	]
	bad = rows.keep_if(|(verb, words, want)| read(verb, words) != want).map(|(verb, words, want)| (words, want, read(verb, words)))
	dbg bad
	listed = |words| match Args.parse(words) {
		Ok(args) => Manage.read_list(args)
		Err(_) => Err(Fail.new(Internal, "the test words do not parse"))
	}
	alias_ok = Args.parse(["roc", "ls"]).map_ok(|a| (a.command, a.typed)) == Ok((["roc", "list"], "roc ls"))
		and Args.parse(["roc", "rm", "x"]).map_ok(|a| (a.command, a.typed)) == Ok((["roc", "remove"], "roc rm"))
	bad == []
		and alias_ok
			and listed(["roc", "ls", "--json"]) == Ok({})
				and listed(["roc", "ls", "x"]) == Err(Fail.new(Usage, "tln roc list takes no operand, got 1"))
}

# R-LY1: the kind of an id, and the rows of `roc list`. `default` is `Pin.same_id`, so the other tag form of a nightly is the default too. A missing file, text that is not JSON, a missing field and a bad time give `Err(Unknown)`.
expect {
	kinds = [
		("nightly-2026-10-09-258ab27", Nightly),
		("nightly-2026-July-31-123c5d7", Nightly),
		("0.1.0", Release),
		("git-dd03c09e", Git),
		("link-dev", Link),
		("copy-fix-1", Copy),
	]
	bad_kinds = kinds.keep_if(|(id, want)| Manage.kind_of(id) != want)
	dbg bad_kinds
	texts = [(Nightly, "nightly"), (Release, "release"), (Git, "git"), (Link, "link"), (Copy, "copy")]
	found = [
		{ id: "nightly-2026-10-09-258ab27", meta: Ok(meta("2026-10-20T12:00:00Z")), last_use: Ok("2026-10-22T08:30:00Z\n") },
		{ id: "nightly-2026-10-14-38a3029", meta: Ok("not json"), last_use: Err(NotFound) },
		{ id: "git-dd03c09e", meta: Ok("{\"format\":1}"), last_use: Ok("yesterday\n") },
		{ id: "link-dev", meta: Err(NotFound), last_use: Err(Denied) },
		{ id: "copy-fix-1", meta: Ok(meta("2026-13-40T00:00:00Z")), last_use: Ok("") },
	]
	got = Manage.rows({ found, default: Ok("nightly-2026-October-14-38a3029") })
	want = [
		{ id: "nightly-2026-10-09-258ab27", kind: Nightly, installed_at: Ok(1792497600), last_use: Ok(1792657800), is_default: Bool.False },
		{ id: "nightly-2026-10-14-38a3029", kind: Nightly, installed_at: Err(Unknown), last_use: Err(Unknown), is_default: Bool.False },
		{ id: "git-dd03c09e", kind: Git, installed_at: Err(Unknown), last_use: Err(Unknown), is_default: Bool.False },
		{ id: "link-dev", kind: Link, installed_at: Err(Unknown), last_use: Err(Unknown), is_default: Bool.False },
		{ id: "copy-fix-1", kind: Copy, installed_at: Err(Unknown), last_use: Err(Unknown), is_default: Bool.False },
	]
	none = Manage.rows({ found, default: Err(Unset) }).keep_if(|r| r.is_default)
	bad_kinds == []
		and texts.all(|(kind, text)| Manage.kind_text(kind) == text)
			and got.map(|r| (r.id, r.kind, r.installed_at, r.last_use)) == want.map(|r| (r.id, r.kind, r.installed_at, r.last_use))
				and got.map(|r| r.is_default) == [Bool.False, Bool.True, Bool.False, Bool.False, Bool.False]
					and none == []
}

# R-OUT2 (proposal): the table of `roc list`. The columns are padded to the widest cell, 2 spaces between them, `* ` marks the default, a date has no time, `-` is an unknown time, no trailing space. No row: one line. A default that is not
# in the rows: the warning on stderr, and the table stays.
expect {
	a = { id: "nightly-2026-10-09-258ab27", kind: Nightly, installed_at: Ok(1792497600), last_use: Ok(1792657800), is_default: Bool.False }
	b = { id: "nightly-2026-10-14-38a3029", kind: Nightly, installed_at: Ok(1792497600), last_use: Err(Unknown), is_default: Bool.True }
	c = { id: "link-dev", kind: Link, installed_at: Err(Unknown), last_use: Err(Unknown), is_default: Bool.False }
	full = Manage.ls_report({ rows: [a, b, c], origins: [], default: Ok("nightly-2026-10-14-38a3029") })
	missing = Manage.ls_report({ rows: [a], origins: [], default: Ok("nightly-2026-10-01-aaaaaaa") })
	empty = Manage.ls_report({ rows: [], origins: [], default: Err(Unset) })
	empty_warn = Manage.ls_report({ rows: [], origins: [], default: Ok("nightly-2026-10-01-aaaaaaa") })
	full.stdout
		== [
			"  ID                          KIND     INSTALLED   LAST USE\n",
			"  nightly-2026-10-09-258ab27  nightly  2026-10-20  2026-10-22\n",
			"* nightly-2026-10-14-38a3029  nightly  2026-10-20  -\n",
			"  link-dev                    link     -           -\n",
		]
		and full.stderr == []
			and missing.stdout
				== [
					"  ID                          KIND     INSTALLED   LAST USE\n",
					"  nightly-2026-10-09-258ab27  nightly  2026-10-20  2026-10-22\n",
				]
				and missing.stderr == ["warning: the default compiler nightly-2026-10-01-aaaaaaa is not installed\n"]
					and empty.stdout == ["no compiler is installed. Run: tln roc install @latest\n"]
						and empty.stderr == []
							and empty_warn.stderr == ["warning: the default compiler nightly-2026-10-01-aaaaaaa is not installed\n"]
}

# R-J3, R-J4, R-OUT4 (proposal): the `data` of `roc list --json`. A time is the UTC text or `null`.
expect {
	a = { id: "nightly-2026-10-09-258ab27", kind: Nightly, installed_at: Ok(1792497600), last_use: Ok(1792657800), is_default: Bool.True }
	c = { id: "link-dev", kind: Link, installed_at: Err(Unknown), last_use: Err(Unknown), is_default: Bool.False }
	shown = Manage.ls_data({ rows: [a, c], origins: [], default: Ok("nightly-2026-10-09-258ab27") }).render()
	none = Manage.ls_data({ rows: [], origins: [], default: Err(Unset) }).render()
	shown
		== "{\"default\":\"nightly-2026-10-09-258ab27\",\"compilers\":[{\"id\":\"nightly-2026-10-09-258ab27\",\"kind\":\"nightly\",\"installed_at\":\"2026-10-20T12:00:00Z\",\"last_use\":\"2026-10-22T08:30:00Z\",\"default\":true},{\"id\":\"link-dev\",\"kind\":\"link\",\"installed_at\":null,\"last_use\":null,\"default\":false}]}"
		and none == "{\"default\":null,\"compilers\":[]}"
}

# R-R15 R-R1 (slice 071): the origins of the `git-*` ids, from their `.talon.json`: `repo` (the URL, as it is) and `ref` (the text that the user typed). One `Origin` with the id for each item that has both, in the order of the items. The list is shorter for the others:
# only the kind `Git` has an origin. A text that is not JSON, a missing file, a field that is missing or not a text: nothing.
expect {
	git_meta = |fields| "{\"format\":1,\"id\":\"git-dd03c09e\",${fields},\"installed_at\":\"2026-10-20T12:00:00Z\"}"
	item = |id, text| { id, meta: text, last_use: Err(NotFound) }
	found = [
		item("git-dd03c09e", Ok(git_meta("\"repo\":\"https://github.com/roc-lang/roc\",\"sha\":\"dd03c09e00000000000000000000000000000000\",\"ref\":\"main\""))),
		item("git-5a5a5a5a", Ok(git_meta("\"ref\":\"my-branch\",\"repo\":\"https://github.com/Karakatiza666/roc\""))),
		item("git-7e7e7e7e", Ok(git_meta("\"repo\":\"https://github.com/roc-lang/roc\",\"ref\":\"7e7e7e7\""))),
		item("git-0a1b2c3d", Ok(git_meta("\"repo\":\"https://example.com/a/b\",\"ref\":\"v1\""))),
		item("git-11111111", Ok(git_meta("\"repo\":\"https://github.com/roc-lang/roc\""))),
		item("git-22222222", Ok(git_meta("\"ref\":\"main\""))),
		item("git-33333333", Ok(git_meta("\"repo\":\"https://github.com/roc-lang/roc\",\"ref\":5"))),
		item("git-44444444", Ok("not json")),
		item("git-55555555", Err(NotFound)),
		item("nightly-2026-10-09-258ab27", Ok(git_meta("\"repo\":\"https://github.com/roc-lang/roc\",\"ref\":\"main\""))),
		item("link-dev", Ok(git_meta("\"repo\":\"https://github.com/roc-lang/roc\",\"ref\":\"main\""))),
	]
	Manage.origins(found)
		== [
			{ id: "git-dd03c09e", repo: "https://github.com/roc-lang/roc", ref: "main" },
			{ id: "git-5a5a5a5a", repo: "https://github.com/Karakatiza666/roc", ref: "my-branch" },
			{ id: "git-7e7e7e7e", repo: "https://github.com/roc-lang/roc", ref: "7e7e7e7" },
			{ id: "git-0a1b2c3d", repo: "https://example.com/a/b", ref: "v1" },
		]
}

# R-R15 R-OUT2 (slice 071, proposal): `roc list` shows the repo and the typed ref of a `git-*` id. A row takes its origin by id (the list is in another order than the rows, and has an id that is no row). When a row has an origin, the table has a column `SOURCE`
# (`owner/repo@ref`; a `repo` that is not `https://github.com/<owner>/<repo>` shows in full; `-` for the other rows) and `LAST USE` is padded. With no row that has an origin the table has no such column, so the table of a store with no `git-*` build is as before.
expect {
	a = { id: "nightly-2026-10-09-258ab27", kind: Nightly, installed_at: Ok(1792497600), last_use: Ok(1792657800), is_default: Bool.False }
	g1 = { id: "git-dd03c09e", kind: Git, installed_at: Ok(1792497600), last_use: Err(Unknown), is_default: Bool.True }
	g2 = { id: "git-5a5a5a5a", kind: Git, installed_at: Err(Unknown), last_use: Ok(1792411200), is_default: Bool.False }
	g3 = { id: "git-7e7e7e7e", kind: Git, installed_at: Err(Unknown), last_use: Err(Unknown), is_default: Bool.False }
	g4 = { id: "git-0a1b2c3d", kind: Git, installed_at: Err(Unknown), last_use: Err(Unknown), is_default: Bool.False }
	c = { id: "link-dev", kind: Link, installed_at: Err(Unknown), last_use: Err(Unknown), is_default: Bool.False }
	o1 = { id: "git-dd03c09e", repo: "https://github.com/roc-lang/roc", ref: "main" }
	o2 = { id: "git-5a5a5a5a", repo: "https://github.com/Karakatiza666/roc", ref: "my-branch" }
	o4 = { id: "git-0a1b2c3d", repo: "https://example.com/a/b", ref: "v1" }
	o5 = { id: "git-99999999", repo: "https://github.com/roc-lang/roc", ref: "gone" }
	o6 = { id: "git-7e7e7e7e", repo: "https://github.com/roc-lang/roc/tree/x", ref: "deep" }
	shown = Manage.ls_report({ rows: [a, g1, g2, g3, g4, c], origins: [o4, o5, o2, o1], default: Ok("git-dd03c09e") })
	deep = Manage.ls_report({ rows: [g3], origins: [o6], default: Err(Unset) })
	plain = Manage.ls_report({ rows: [a, g3, c], origins: [], default: Err(Unset) })
	unmatched = Manage.ls_report({ rows: [a, g3, c], origins: [o5], default: Err(Unset) })
	shown.stdout
		== [
			"  ID                          KIND     INSTALLED   LAST USE    SOURCE\n",
			"  nightly-2026-10-09-258ab27  nightly  2026-10-20  2026-10-22  -\n",
			"* git-dd03c09e                git      2026-10-20  -           roc-lang/roc@main\n",
			"  git-5a5a5a5a                git      -           2026-10-19  Karakatiza666/roc@my-branch\n",
			"  git-7e7e7e7e                git      -           -           -\n",
			"  git-0a1b2c3d                git      -           -           https://example.com/a/b@v1\n",
			"  link-dev                    link     -           -           -\n",
		]
		and shown.stderr == []
			and deep.stdout == ["  ID            KIND  INSTALLED  LAST USE  SOURCE\n", "  git-7e7e7e7e  git   -          -         https://github.com/roc-lang/roc/tree/x@deep\n"]
				and plain.stdout
					== [
						"  ID                          KIND     INSTALLED   LAST USE\n",
						"  nightly-2026-10-09-258ab27  nightly  2026-10-20  2026-10-22\n",
						"  git-7e7e7e7e                git      -           -\n",
						"  link-dev                    link     -           -\n",
					]
					and unmatched.stdout == plain.stdout
}

# R-R15 R-J3 R-OUT4 (slice 071, proposal): the `data` of `roc list --json`. A row of the kind `git` has the keys `repo` and `ref` after `default`: the origin of its id as it is (the stored URL, raw), or `null` for both. A row of another kind has no such key, also when an origin has its id.
expect {
	a = { id: "nightly-2026-10-09-258ab27", kind: Nightly, installed_at: Ok(1792497600), last_use: Err(Unknown), is_default: Bool.False }
	g1 = { id: "git-dd03c09e", kind: Git, installed_at: Ok(1792497600), last_use: Err(Unknown), is_default: Bool.True }
	g2 = { id: "git-7e7e7e7e", kind: Git, installed_at: Err(Unknown), last_use: Err(Unknown), is_default: Bool.False }
	o1 = { id: "git-dd03c09e", repo: "https://github.com/roc-lang/roc", ref: "main" }
	oa = { id: "nightly-2026-10-09-258ab27", repo: "https://github.com/roc-lang/roc", ref: "main" }
	shown = Manage.ls_data({ rows: [a, g1, g2], origins: [oa, o1], default: Ok("git-dd03c09e") }).render()
	shown
		== "{\"default\":\"git-dd03c09e\",\"compilers\":[{\"id\":\"nightly-2026-10-09-258ab27\",\"kind\":\"nightly\",\"installed_at\":\"2026-10-20T12:00:00Z\",\"last_use\":null,\"default\":false},{\"id\":\"git-dd03c09e\",\"kind\":\"git\",\"installed_at\":\"2026-10-20T12:00:00Z\",\"last_use\":null,\"default\":true,\"repo\":\"https://github.com/roc-lang/roc\",\"ref\":\"main\"},{\"id\":\"git-7e7e7e7e\",\"kind\":\"git\",\"installed_at\":null,\"last_use\":null,\"default\":false,\"repo\":null,\"ref\":null}]}"
}

# R-CS2, R-CC6, R-LY4: the edit that makes `id` the default. The same value is `Same`. Another value is replaced in place and every other byte stays (comments, order, the quote style of other lines). A missing key is added at the end of the
# top-level keys, before the first table. The empty text gives one line. A text that is not TOML and a key that is not a text are failures of kind `Input` (exit 19).
expect {
	new_id = "nightly-2026-10-14-38a3029"
	old_id = "nightly-2026-10-09-258ab27"
	set = |text| Manage.default_set({ path: "/c/config.toml", text, id: new_id })
	same = set("default-roc = \"${new_id}\"\n")
	replaced = set("# mine\nnightly = true\ndefault-roc = \"${old_id}\"   # tln roc default writes it\nmin-release-age = \"2d\"\n")
	inserted = set("nightly = true\n[probe]\nslots = 12\n")
	created = set("")
	bad_toml = set("default-roc = \n")
	not_text = set("default-roc = 5\n")
	same == Ok({ previous: Ok(new_id), edit: Same })
		and replaced == Ok({ previous: Ok(old_id), edit: Set("# mine\nnightly = true\ndefault-roc = \"${new_id}\"   # tln roc default writes it\nmin-release-age = \"2d\"\n") })
			and inserted == Ok({ previous: Err(Unset), edit: Set("nightly = true\ndefault-roc = \"${new_id}\"\n[probe]\nslots = 12\n") })
				and created == Ok({ previous: Err(Unset), edit: Set("default-roc = \"${new_id}\"\n") })
					and bad_toml.map_err(|f| (f.kind.code(), f.message)) == Err((19, "/c/config.toml:1: not valid TOML"))
						and not_text.map_err(|f| (f.kind.code(), f.message)) == Err((19, "/c/config.toml: default-roc is not a text"))
}

# R-RR1, R-CC6: the edit that unsets the default. The line goes, every other byte stays. No key: `Same`. Not TOML: kind `Input`.
expect {
	unset = |text| Manage.default_unset({ path: "/c/config.toml", text })
	unset("# mine\nnightly = true\ndefault-roc = \"nightly-2026-10-09-258ab27\"   # c\nmin-release-age = \"2d\"\n")
		== Ok(Set("# mine\nnightly = true\nmin-release-age = \"2d\"\n"))
		and unset("default-roc = \"nightly-2026-10-09-258ab27\"\n") == Ok(Set(""))
			and unset("nightly = true\n") == Ok(Same)
				and unset("") == Ok(Same)
					and unset("default-roc = \n").map_err(|f| f.kind.code()) == Err(19)
}

# R-RR1, R-NS3, R-NS6, R-SO24 (slice 080): the compiler that takes the default. The newest nightly or release by `Pin.order` (with `published_at`), never the removed one, never a `git-`, `link-` or `copy-` build. With the `nightly` switch off: a release first.
# Only when the switch admits none: the newest installed nightly or release of any kind, so the default stays set (R-SO24). `Err(None)` only when no nightly or release is left.
expect {
	times = [
		{ id: "nightly-2026-10-14-0abcdef", published_at: 1791968400 },
		{ id: "nightly-2026-10-14-38a3029", published_at: 1791982800 },
	]
	installed = ["0.1.0", "copy-fix-1", "git-dd03c09e", "link-dev", "nightly-2026-10-09-258ab27", "nightly-2026-10-14-0abcdef", "nightly-2026-10-14-38a3029"]
	next = |removed, nightly, list| Manage.next_default({ installed: list, removed, nightly, times })
	# R-RR1 (review, G2): a release with a date (the `published_at` of its `.talon.json`) is ordered by its date, as in rank 4. A newer release wins over the nightlies, an older one loses.
	newer = times.append({ id: "0.1.0", published_at: 1792022400 })
	older = times.append({ id: "0.1.0", published_at: 1790812800 })
	dated = |list, at| Manage.next_default({ installed: list, removed: "nightly-2026-10-09-258ab27", nightly: Bool.True, times: at })
	rows = [
		("the newest nightly by `published_at`", next("nightly-2026-10-09-258ab27", Bool.True, installed), Ok("nightly-2026-10-14-38a3029")),
		("the removed one is never chosen", next("nightly-2026-10-14-38a3029", Bool.True, installed), Ok("nightly-2026-10-14-0abcdef")),
		("the switch is off: a release is admitted", next("nightly-2026-10-14-0abcdef", Bool.False, installed), Ok("0.1.0")),
		("R-SO24: the switch is off and no release is installed: the newest nightly of any kind", next("0.1.0", Bool.False, installed), Ok("nightly-2026-10-14-38a3029")),
		("R-SO24: the switch is off, only nightlies: the newest nightly, never a build", next("nightly-2026-10-14-38a3029", Bool.False, ["git-dd03c09e", "nightly-2026-10-09-258ab27", "nightly-2026-10-14-38a3029"]), Ok("nightly-2026-10-09-258ab27")),
		("R-SO24: the switch is off, the other nightlies by `published_at`", next("nightly-2026-10-09-258ab27", Bool.False, ["nightly-2026-10-09-258ab27", "nightly-2026-10-14-0abcdef", "nightly-2026-10-14-38a3029"]), Ok("nightly-2026-10-14-38a3029")),
		("only builds are left (R-NS6)", next("nightly-2026-10-14-38a3029", Bool.True, ["git-dd03c09e", "link-dev", "copy-fix-1", "nightly-2026-10-14-38a3029"]), Err(None)),
		("nothing is left", next("nightly-2026-10-09-258ab27", Bool.True, ["nightly-2026-10-09-258ab27"]), Err(None)),
		("the removed id is a build", next("link-dev", Bool.True, ["link-dev", "nightly-2026-10-09-258ab27"]), Ok("nightly-2026-10-09-258ab27")),
		("a newer release wins over the nightlies", dated(installed, newer), Ok("0.1.0")),
		("an older release loses", dated(installed, older), Ok("nightly-2026-10-14-38a3029")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-RR1, R-SO19, R-NS3 (slice 080, a proposal, TW24): the note of a move of the default to a compiler that the switch does not admit. Only a nightly with the switch off gets it: the next use of the default is exit code 10 (R-SO19).
expect {
	note = |next, nightly| Manage.move_note({ next, nightly })
	text = "nightly-2026-10-14-38a3029 is a nightly and the nightly switch is off, so commands that use the default stop with exit code 10 until you change the switch or install an admitted compiler"
	note("nightly-2026-10-14-38a3029", Bool.False) == Ok(text)
		and note("nightly-2026-10-14-38a3029", Bool.True) == Err(None)
			and note("0.1.0", Bool.False) == Err(None)
				and note("0.1.0", Bool.True) == Err(None)
}

# R-RR2, R-PD9: the known projects that pin the compiler. The other tag form of a nightly counts. A missing file, an unreadable file, a header that does not parse and a header with no pin pin nothing. The paths are in byte order.
expect {
	pinned = |id, projects| Manage.pinned_by({ id, projects })
	projects = [
		{ path: "/p/b/main.roc", text: Ok(header(Ok("nightly-2026-October-14-38a3029"))) },
		{ path: "/p/a/main.roc", text: Ok(header(Ok("nightly-2026-10-14-38a3029"))) },
		{ path: "/p/c/main.roc", text: Ok(header(Ok("nightly-2026-10-09-258ab27"))) },
		{ path: "/p/d/main.roc", text: Ok("app [main!] { pf: platform \"") },
		{ path: "/p/e/main.roc", text: Ok(header(Err(NoPin))) },
		{ path: "/p/f/main.roc", text: Err(NotFound) },
		{ path: "/p/g/main.roc", text: Err(Denied) },
	]
	pinned("nightly-2026-10-14-38a3029", projects) == ["/p/a/main.roc", "/p/b/main.roc"]
		and pinned("nightly-2026-10-09-258ab27", projects) == ["/p/c/main.roc"]
			and pinned("link-dev", projects) == []
				and pinned("nightly-2026-10-14-38a3029", []) == []
}

# R-GC3, R-CC10: the compat id of `.talon.json` (the compat dir goes with the compiler), and the name of the trash dir.
expect {
	ok = "{\"format\":1,\"id\":\"x\",\"compat\":\"258ab27\",\"installed_at\":\"2026-10-20T12:00:00Z\"}"
	Manage.compat_of(Ok(ok)) == Ok("258ab27")
		and Manage.compat_of(Ok(meta("2026-10-20T12:00:00Z"))) == Err(None)
			and Manage.compat_of(Ok("{\"format\":1}")) == Err(None)
				and Manage.compat_of(Ok("{\"compat\":5}")) == Err(None)
					and Manage.compat_of(Ok("not json")) == Err(None)
						and Manage.compat_of(Err(NotFound)) == Err(None)
							and Manage.trash_name({ item: "/c/roc/toolchains/nightly-2026-10-09-258ab27", hex: "0123456789abcdef" }) == "/c/roc/toolchains/nightly-2026-10-09-258ab27.0123456789abcdef.trash"
}

# R-CS2, R-OUT2, R-J3, R-OUT4 (proposal): the text and the `data` of `roc default`.
expect {
	id = "nightly-2026-10-14-38a3029"
	set = Manage.default_report({ id, installed: Bool.False, edit: Set })
	same = Manage.default_report({ id, installed: Bool.False, edit: Same })
	fetched = Manage.default_report({ id, installed: Bool.True, edit: Set })
	data = Manage.default_data({ id, previous: Ok("link-dev"), edit: Set, installed: Bool.True }).render()
	data_none = Manage.default_data({ id, previous: Err(Unset), edit: Same, installed: Bool.False }).render()
	set == ["${id} is now the default compiler\n"]
		and same == ["${id} is already the default compiler\n"]
			and fetched == ["installed ${id}\n", "${id} is now the default compiler\n"]
				and data == "{\"id\":\"${id}\",\"previous\":\"link-dev\",\"changed\":true,\"installed\":true}"
					and data_none == "{\"id\":\"${id}\",\"previous\":null,\"changed\":false,\"installed\":false}"
}

# R-RR1, R-RR2, R-OUT2, R-J3, R-OUT4 (proposal): the text and the `data` of `roc remove`. The projects are listed, the default move is named only when the compiler was the default.
expect {
	id = "nightly-2026-10-14-38a3029"
	plain = Manage.remove_report({ id, was_default: Bool.False, next: Ok("ignored"), projects: [] })
	moved = Manage.remove_report({ id, was_default: Bool.True, next: Ok("nightly-2026-10-12-2664a27"), projects: ["/p/a/main.roc", "/p/b/main.roc"] })
	unset = Manage.remove_report({ id, was_default: Bool.True, next: Err(None), projects: [] })
	data = Manage.remove_data({ id, item: "/c/roc/toolchains/${id}", was_default: Bool.True, default: Ok("nightly-2026-10-12-2664a27"), projects: ["/p/a/main.roc"] }).render()
	data_none = Manage.remove_data({ id, item: "/c/roc/toolchains/${id}", was_default: Bool.False, default: Err(None), projects: [] }).render()
	plain == ["removed ${id}\n"]
		and moved
			== [
				"removed ${id}\n",
				"the default compiler is now nightly-2026-10-12-2664a27\n",
				"known projects that pin ${id} (the proxy installs it again when one runs):\n",
				"  /p/a/main.roc\n",
				"  /p/b/main.roc\n",
			]
			and unset == ["removed ${id}\n", "no default compiler is set now\n"]
				and data == "{\"id\":\"${id}\",\"path\":\"/c/roc/toolchains/${id}\",\"was_default\":true,\"default\":\"nightly-2026-10-12-2664a27\",\"projects\":[\"/p/a/main.roc\"]}"
					and data_none == "{\"id\":\"${id}\",\"path\":\"/c/roc/toolchains/${id}\",\"was_default\":false,\"default\":null,\"projects\":[]}"
}

# R-CM15, R-CM19 (slice 026): `roc update` takes no operand. 1 or more is a usage failure (exit 2). The text names the long form, also for `up`. The global flags are accepted.
expect {
	updated = |words| match Args.parse(words) {
		Ok(args) => Manage.read_update(args)
		Err(_) => Err(Fail.new(Internal, "the test words do not parse"))
	}
	alias_ok = Args.parse(["roc", "up"]).map_ok(|a| (a.command, a.typed)) == Ok((["roc", "update"], "roc up"))
	alias_ok
		and updated(["roc", "update"]) == Ok({})
			and updated(["roc", "up", "--json", "--yes", "--offline", "--quiet"]) == Ok({})
				and updated(["roc", "up", "@latest"]) == Err(Fail.new(Usage, "tln roc update takes no operand, got 1"))
					and updated(["roc", "update", "nightly-2026-10-14-38a3029", "x"]) == Err(Fail.new(Usage, "tln roc update takes no operand, got 2"))
}

# R-RU2 (slice 026): the global default moves when it is not set, a nightly or a release (also the other tag form of a nightly). A `git-`, `link-` or `copy-` default stays (R-NS6). The text of the id decides, not the file.
expect {
	moves = |default| Manage.update_move({ default: default })
	moves(Err(Unset)) == Move
		and moves(Ok("nightly-2026-10-09-258ab27")) == Move
			and moves(Ok("nightly-2026-October-14-38a3029")) == Move
				and moves(Ok("0.1.0")) == Move
					and moves(Ok("git-dd03c09e")) == Stay
						and moves(Ok("link-dev")) == Stay
							and moves(Ok("copy-fix-1")) == Stay
}

# R-RU1, R-RU2, R-OUT2, R-J3, R-OUT4 (slice 026, proposal): the text and the `data` of `roc update`. A compiler that is not new is named, and the default can still move (answer Q1 of the review): then the compat warning is not shown (no install). The compat warnings of an install are on stderr. `changed` is true for the first default too.
expect {
	id = "nightly-2026-10-18-5349569"
	old = "nightly-2026-10-09-258ab27"
	known = Ok("nightly-2026-10-18-aaaaaaa")
	newest = Manage.update_report({ id, installed: Bool.False, default: Same, compat: Err(Unknown) })
	first = Manage.update_report({ id, installed: Bool.True, default: Set, compat: Ok("5349569a") })
	moved = Manage.update_report({ id, installed: Bool.True, default: Moved(old), compat: Ok("5349569a") })
	stays = Manage.update_report({ id, installed: Bool.True, default: Stay("link-dev"), compat: Ok("5349569a") })
	same = Manage.update_report({ id, installed: Bool.True, default: Same, compat: Ok("5349569a") })
	warned = Manage.update_report({ id, installed: Bool.True, default: Moved(old), compat: Err(Unknown) })
	several = Manage.update_report({ id, installed: Bool.True, default: Set, compat: Err(Several(["compat-a", "compat-b"])) })
	there_moved = Manage.update_report({ id, installed: Bool.False, default: Moved(old), compat: Err(Unknown) })
	there_set = Manage.update_report({ id, installed: Bool.False, default: Set, compat: Err(Unknown) })
	there_stays = Manage.update_report({ id, installed: Bool.False, default: Stay("link-dev"), compat: Err(Unknown) })
	data_there = Manage.update_data({ id, item: "/c/roc/toolchains/${id}", installed: Bool.False, previous: Ok(old), changed: Bool.True }).render()
	data = Manage.update_data({ id, item: "/c/roc/toolchains/${id}", installed: Bool.True, previous: Ok(old), changed: Bool.True }).render()
	data_first = Manage.update_data({ id, item: "/c/roc/toolchains/${id}", installed: Bool.True, previous: Err(Unset), changed: Bool.True }).render()
	data_stay = Manage.update_data({ id, item: "/c/roc/toolchains/${id}", installed: Bool.True, previous: Ok("link-dev"), changed: Bool.False }).render()
	data_newest = Manage.update_data({ id, item: "/c/roc/toolchains/${id}", installed: Bool.False, previous: known, changed: Bool.False }).render()
	newest == { stdout: ["${id} is the newest\n"], stderr: [] }
		and there_moved == { stdout: ["${id} is the newest\n", "the default compiler moved from ${old} to ${id}\n"], stderr: [] }
			and there_set == { stdout: ["${id} is the newest\n", "${id} is now the default compiler\n"], stderr: [] }
				and there_stays == { stdout: ["${id} is the newest\n", "note: the default compiler link-dev is a git, link or copy build, so it stays. To change it, run: tln roc default ${id}\n"], stderr: [] }
					and data_there == "{\"id\":\"${id}\",\"path\":\"/c/roc/toolchains/${id}\",\"installed\":false,\"previous\":\"${old}\",\"changed\":true}"
						and first == { stdout: ["installed ${id}\n", "${id} is now the default compiler\n"], stderr: [] }
							and moved == { stdout: ["installed ${id}\n", "the default compiler moved from ${old} to ${id}\n"], stderr: [] }
								and stays == { stdout: ["installed ${id}\n", "note: the default compiler link-dev is a git, link or copy build, so it stays. To change it, run: tln roc default ${id}\n"], stderr: [] }
									and same == { stdout: ["installed ${id}\n"], stderr: [] }
										and warned == { stdout: ["installed ${id}\n", "the default compiler moved from ${old} to ${id}\n"], stderr: ["warning: the compat id of ${id} is not known: roc check touched no compat dir\n"] }
											and several.stderr == ["warning: the compat id of ${id} is not known: roc check touched 2 compat dirs (compat-a, compat-b)\n"]
												and data == "{\"id\":\"${id}\",\"path\":\"/c/roc/toolchains/${id}\",\"installed\":true,\"previous\":\"${old}\",\"changed\":true}"
													and data_first == "{\"id\":\"${id}\",\"path\":\"/c/roc/toolchains/${id}\",\"installed\":true,\"previous\":null,\"changed\":true}"
														and data_stay == "{\"id\":\"${id}\",\"path\":\"/c/roc/toolchains/${id}\",\"installed\":true,\"previous\":\"link-dev\",\"changed\":false}"
															and data_newest == "{\"id\":\"${id}\",\"path\":\"/c/roc/toolchains/${id}\",\"installed\":false,\"previous\":\"nightly-2026-10-18-aaaaaaa\",\"changed\":false}"
}

# R-CS1, R-U1, R-U4 (slice 026b): the operand of `roc use`. One text, as typed: a full id, a prefix, `@latest`, a step, a release. No operand and 2 or more are usage failures. A text that starts with `git-`, `link-` or `copy-` is refused with the
# text of the design (R-U1: say to use `tln roc default` or `ROC_TOOLCHAIN`). `--file` and `--allow-downloads` are the flags of the command. `--no-check` never gets here: `Args.parse` stops it (R-U4, `args.roc`).
expect {
	used = |words| match Args.parse(words) {
		Ok(args) => Manage.read_use(args)
		Err(_) => Err(Fail.new(Internal, "the test words do not parse"))
	}
	n = "nightly-2026-10-14-38a3029"
	refused = |ref| Err(Fail.new(Usage, "tln roc use does not take ${ref}: a git, link or copy build cannot be a pin. Use ROC_TOOLCHAIN or tln roc default for it."))
	rows = [
		("a full id", used(["roc", "use", n]), Ok(n)),
		("the flags of the command", used(["roc", "use", n, "--file", "p/main.roc", "--allow-downloads", "--json", "--yes", "--quiet", "--offline"]), Ok(n)),
		("a prefix", used(["roc", "use", "nightly-2026-10"]), Ok("nightly-2026-10")),
		("a step back", used(["roc", "use", "@-1"]), Ok("@-1")),
		("a step on", used(["roc", "use", "@+2"]), Ok("@+2")),
		("@latest", used(["roc", "use", "@latest"]), Ok("@latest")),
		("a release", used(["roc", "use", "0.1.0"]), Ok("0.1.0")),
		("no operand", used(["roc", "use"]), Err(Fail.new(Usage, "tln roc use needs one compiler: a full id, a prefix, @latest or a step like @-1"))),
		("2 operands", used(["roc", "use", n, "0.1.0"]), Err(Fail.new(Usage, "tln roc use takes one compiler, got 2"))),
		("3 operands", used(["roc", "use", n, "0.1.0", "x"]), Err(Fail.new(Usage, "tln roc use takes one compiler, got 3"))),
		("a link build", used(["roc", "use", "link-dev"]), refused("link-dev")),
		("a copy build", used(["roc", "use", "copy-fix-1"]), refused("copy-fix-1")),
		("a git build", used(["roc", "use", "git-dd03c09e"]), refused("git-dd03c09e")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-U1 (slice 026b): the check of the id that the operand named. An installed prefix can name a local build (`link` is a prefix of `link-dev`), so the full id is checked too. A pin is a nightly (both tag forms) or a release.
# Any other id is refused with the same text as the operand (`debug-<sha>` is a local build id too: R-SO11).
expect {
	check = |id| Manage.use_pinnable(id)
	refused = |ref| Err(Fail.new(Usage, "tln roc use does not take ${ref}: a git, link or copy build cannot be a pin. Use ROC_TOOLCHAIN or tln roc default for it."))
	rows = [
		("a nightly", check("nightly-2026-10-14-38a3029"), Ok({})),
		("a nightly, the month as a name", check("nightly-2026-October-14-38a3029"), Ok({})),
		("a release", check("0.1.0"), Ok({})),
		("a link build", check("link-dev"), refused("link-dev")),
		("a copy build", check("copy-fix-1"), refused("copy-fix-1")),
		("a git build", check("git-dd03c09e"), refused("git-dd03c09e")),
		("a debug build", check("debug-1a2b3c4"), refused("debug-1a2b3c4")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-CS1, R-U3, R-BL1, R-RP1, R-RP3, R-WS13, R-WS4, R-SO14, R-H1 (slice 026b): what `roc use` does for each member. The baseline of a member is its own pin, else the fallback (`ROC_TOOLCHAIN`, else the compiler of Resolution 13). Members can have
# different pins (the case R-WS4 sends the user to `roc use` for), so the baselines can differ. A pin that is the new id (also in the other tag form of a nightly: R-H1, no rewrite) needs no edit. A member with no pin and no fallback is exit 18.
expect {
	new = "nightly-2026-10-14-38a3029"
	old = "nightly-2026-10-09-258ab27"
	mid = "nightly-2026-10-13-91fa0c2"
	plan = |members, fallback| Manage.use_plan({ id: new, members, fallback })
	one = plan([{ file: "/p/main.roc", pin: Ok(old) }], Err(NoCompiler))
	mixed = plan([{ file: "/w/a/main.roc", pin: Ok(old) }, { file: "/w/b/main.roc", pin: Ok(mid) }, { file: "/w/c/main.roc", pin: Err(NoPin) }, { file: "/w/d/main.roc", pin: Ok(new) }], Ok(old))
	other_form = plan([{ file: "/w/a/main.roc", pin: Ok("nightly-2026-October-14-38a3029") }], Ok(old))
	none = plan([{ file: "/w/a/main.roc", pin: Err(NoPin) }], Err(NoCompiler))
	local = plan([{ file: "/w/a/main.roc", pin: Err(NoPin) }], Ok("link-dev"))
	one == Ok([{ file: "/p/main.roc", baseline: old, previous: Ok(old), op: Ok(Pin(new)) }])
		and mixed == Ok([
			{ file: "/w/a/main.roc", baseline: old, previous: Ok(old), op: Ok(Pin(new)) },
			{ file: "/w/b/main.roc", baseline: mid, previous: Ok(mid), op: Ok(Pin(new)) },
			{ file: "/w/c/main.roc", baseline: old, previous: Err(NoPin), op: Ok(Pin(new)) },
			{ file: "/w/d/main.roc", baseline: new, previous: Ok(new), op: Err(Same) },
		])
			and other_form == Ok([{ file: "/w/a/main.roc", baseline: "nightly-2026-October-14-38a3029", previous: Ok("nightly-2026-October-14-38a3029"), op: Err(Same) }])
				and local == Ok([{ file: "/w/a/main.roc", baseline: "link-dev", previous: Err(NoPin), op: Ok(Pin(new)) }])
					and none == Err(Fail.new(Environment, "no compiler is selected. Run: tln roc install @latest, then tln roc default <id>"))
}

# R-U6, R-CS1, R-OUT2, R-J3, R-OUT4 (slice 026b, proposal): the note when `ROC_TOOLCHAIN` is set, the lines of `roc use`, and its `data`. A member with no pin has the line `+ roc:`, a member with a pin has `~ roc: <old> -> <new>`. The keys of `data` are in this order:
# `id`, `files` (`path`, `previous`: the old pin or null), `probes`, `downloads`, `check`, `build` (null when no member is an app), `notes`.
expect {
	new = "nightly-2026-10-14-38a3029"
	old = "nightly-2026-10-09-258ab27"
	note = Manage.use_note({ toolchain: old, id: new })
	one = Manage.use_report({ id: new, files: [{ file: "/p/main.roc", previous: Ok(old) }] })
	added = Manage.use_report({ id: new, files: [{ file: "/p/main.roc", previous: Err(NoPin) }] })
	none = Manage.use_report({ id: new, files: [] })
	many = Manage.use_report({ id: new, files: [{ file: "/w/a/main.roc", previous: Ok(old) }, { file: "/w/b/main.roc", previous: Err(NoPin) }] })
	data = Manage.use_data({ id: new, files: [{ file: "/w/a/main.roc", previous: Ok(old) }, { file: "/w/b/main.roc", previous: Err(NoPin) }], probes: 6, downloads: 2, built: Bool.True, notes: ["unchanged error: main.roc: type mismatch"] }).render()
	lib_only = Manage.use_data({ id: new, files: [{ file: "/p/main.roc", previous: Ok(old) }], probes: 2, downloads: 0, built: Bool.False, notes: [] }).render()
	note == "ROC_TOOLCHAIN is ${old}. It has a higher priority than the new pin ${new}, so it still selects the compiler. The pin is used when ROC_TOOLCHAIN is not set."
		and one == ["/p/main.roc\n", "  ~ roc: ${old} -> ${new}\n", "the roc pin is now ${new}\n"]
			and added == ["/p/main.roc\n", "  + roc: ${new}\n", "the roc pin is now ${new}\n"]
				and none == ["the roc pin is already ${new} in every member. Nothing was written.\n"]
					and many == ["/w/a/main.roc\n", "  ~ roc: ${old} -> ${new}\n", "/w/b/main.roc\n", "  + roc: ${new}\n", "the roc pin is now ${new}\n"]
						and data == "{\"id\":\"${new}\",\"files\":[{\"path\":\"/w/a/main.roc\",\"previous\":\"${old}\"},{\"path\":\"/w/b/main.roc\",\"previous\":null}],\"probes\":6,\"downloads\":2,\"check\":\"passed\",\"build\":\"passed\",\"notes\":[\"unchanged error: main.roc: type mismatch\"]}"
							and lib_only == "{\"id\":\"${new}\",\"files\":[{\"path\":\"/p/main.roc\",\"previous\":\"${old}\"}],\"probes\":2,\"downloads\":0,\"check\":\"passed\",\"build\":null,\"notes\":[]}"
}
