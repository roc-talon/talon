app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Args
import lib.Fail
import lib.JsonDoc
import lib.Manage

main! = |_args| Ok({})

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
	full = Manage.ls_report({ rows: [a, b, c], default: Ok("nightly-2026-10-14-38a3029") })
	missing = Manage.ls_report({ rows: [a], default: Ok("nightly-2026-10-01-aaaaaaa") })
	empty = Manage.ls_report({ rows: [], default: Err(Unset) })
	empty_warn = Manage.ls_report({ rows: [], default: Ok("nightly-2026-10-01-aaaaaaa") })
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
	shown = Manage.ls_data({ rows: [a, c], default: Ok("nightly-2026-10-09-258ab27") }).render()
	none = Manage.ls_data({ rows: [], default: Err(Unset) }).render()
	shown
		== "{\"default\":\"nightly-2026-10-09-258ab27\",\"compilers\":[{\"id\":\"nightly-2026-10-09-258ab27\",\"kind\":\"nightly\",\"installed_at\":\"2026-10-20T12:00:00Z\",\"last_use\":\"2026-10-22T08:30:00Z\",\"default\":true},{\"id\":\"link-dev\",\"kind\":\"link\",\"installed_at\":null,\"last_use\":null,\"default\":false}]}"
		and none == "{\"default\":null,\"compilers\":[]}"
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

# R-RR1, R-NS3, R-NS6: the compiler that takes the default. The newest nightly or release by `Pin.order` (with `published_at`), never the removed one, never a `git-`, `link-` or `copy-` build. With the `nightly` switch off: a release only. None: `Err(None)`.
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
	next("nightly-2026-10-09-258ab27", Bool.True, installed) == Ok("nightly-2026-10-14-38a3029")
		and next("nightly-2026-10-14-38a3029", Bool.True, installed) == Ok("nightly-2026-10-14-0abcdef")
			and next("nightly-2026-10-14-0abcdef", Bool.False, installed) == Ok("0.1.0")
				and next("0.1.0", Bool.False, installed) == Err(None)
					and next("nightly-2026-10-14-38a3029", Bool.True, ["git-dd03c09e", "link-dev", "copy-fix-1", "nightly-2026-10-14-38a3029"]) == Err(None)
						and next("nightly-2026-10-09-258ab27", Bool.True, ["nightly-2026-10-09-258ab27"]) == Err(None)
							and next("link-dev", Bool.True, ["link-dev", "nightly-2026-10-09-258ab27"]) == Ok("nightly-2026-10-09-258ab27")
								and dated(installed, newer) == Ok("0.1.0")
									and dated(installed, older) == Ok("nightly-2026-10-14-38a3029")
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
