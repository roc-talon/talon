import lib.Answer
import lib.Fail
import lib.FirstRun
import lib.JsonDoc
import lib.Mode
import lib.Prompt
import lib.Share
import lib.ShareJson

ShareTest :: [].{}

full_id = "0123456789abcdeffedcba9876543210"

# R-SH5, R-SH13, R-TF1, R-SH6: the id is 16 random bytes in lower-case hex (2 numbers of `Fx.random!`, 16 digits each, leading zeros kept). A new file has format 1, the id, 3 totals of 0
# and null for the other members, in the order of the design example, in one line with a line end (the form of `TalonFile.render`).
expect {
	ShareJson.id_of({ high: 0x0123456789abcdef, low: 0xfedcba9876543210 }) == full_id
		and ShareJson.id_of({ high: 255, low: 1 }) == "00000000000000ff0000000000000001"
			and ShareJson.id_of({ high: 0, low: 0 }) == "00000000000000000000000000000000"
				and ShareJson.format == 1
					and ShareJson.text(ShareJson.fresh(full_id)) == "{\"format\":1,\"id\":\"${full_id}\",\"sent\":0,\"counted\":0,\"first\":0,\"first_sent_at\":null,\"last_sent_at\":null,\"token\":null,\"token_expires_at\":null,\"account\":null}\n"
}

# R-SH13, R-SH6, R-TF2: a file with totals, times, a JWT and an account is read, and written again with the same bytes. A member that Talon does not know stays, after the known members.
# R-TF1: format 1 is read. Each other read below is a failure of kind Input (exit 19, R-TF3, R-TF6).
expect {
	path = "$DATA/share.json"
	full = "{\"format\":1,\"id\":\"${full_id}\",\"sent\":7,\"counted\":5,\"first\":2,\"first_sent_at\":\"2026-10-01T10:00:00Z\",\"last_sent_at\":\"2026-10-02T11:30:00Z\",\"token\":\"aaa.bbb.ccc\",\"token_expires_at\":\"2026-12-01T00:00:00Z\",\"account\":{\"id\":42,\"login\":\"octo\"},\"newer\":{\"a\":1}}\n"
	garbage = Err(Fail.new(Input, "${path}: the content does not parse"))
	good = match ShareJson.read({ path, text: full }) {
		Ok(doc) => doc.id == full_id and doc.sent == 7 and doc.counted == 5 and doc.first == 2 and doc.first_sent_at == Ok("2026-10-01T10:00:00Z") and doc.last_sent_at == Ok("2026-10-02T11:30:00Z") and doc.token == Ok("aaa.bbb.ccc") and doc.token_expires_at == Ok("2026-12-01T00:00:00Z") and doc.account == Ok({ id: 42, login: "octo" }) and ShareJson.text(doc) == full
		Err(_) => Bool.False
	}
	empty_members = match ShareJson.read({ path, text: ShareJson.text(ShareJson.fresh(full_id)) }) {
		Ok(doc) => doc == ShareJson.fresh(full_id)
		Err(_) => Bool.False
	}
	newer = ShareJson.read({ path, text: "{\"format\":2,\"id\":\"${full_id}\"}" }) == Err(Fail.new(Input, "${path}: format 2 is newer than this tln (format 1). Run: tln tool update talon"))
	# One member is wrong in each text.
	base = |member, value| "{\"format\":1,\"id\":\"${full_id}\",\"sent\":0,\"counted\":0,\"first\":0,\"first_sent_at\":null,\"last_sent_at\":null,\"token\":null,\"token_expires_at\":null,\"account\":null}".replace_each("\"${member}\":${member_value(member)}", "\"${member}\":${value}")
	bad = [
		"",
		"not json",
		"[1]",
		"{\"id\":\"${full_id}\"}",
		base("id", "\"0123\""),
		base("id", "\"0123456789ABCDEFFEDCBA9876543210\""),
		base("sent", "-1"),
		base("counted", "\"3\""),
		base("first", "null"),
		base("first_sent_at", "5"),
		base("token", "true"),
		base("account", "{\"id\":\"42\",\"login\":\"octo\"}"),
		base("account", "{\"id\":42}"),
	].map(|text| ShareJson.read({ path, text }) == garbage)
	good and empty_members and newer and bad.all(|ok| ok)
}

member_value : Str -> Str
member_value = |member| match member {
	"id" => "\"${full_id}\""
	"sent" | "counted" | "first" => "0"
	_ => "null"
}

# R-SH2, R-EV26, R-NM1: sharing is on only when the 5 conditions are true. Else the answer is the first false condition, in the order of the table (the same order as the rows).
expect {
	url = Url("https://registry.example.org")
	run = |share, registry, offline, env| Share.state({ share, registry, offline, env })
	on = Ok(Bool.True)
	rows = [
		(run(on, url, Bool.False, []), On),
		(run(Err(Unset), url, Bool.False, []), Off(Share)),
		(run(Ok(Bool.False), url, Bool.False, []), Off(Share)),
		(run(on, Direct, Bool.False, []), Off(Registry)),
		(run(on, url, Bool.True, []), Off(Offline)),
		# DO_NOT_TRACK: set, not empty and not 0 turns it off.
		(run(on, url, Bool.False, [("DO_NOT_TRACK", "1")]), Off(DoNotTrack)),
		(run(on, url, Bool.False, [("DO_NOT_TRACK", "true")]), Off(DoNotTrack)),
		(run(on, url, Bool.False, [("DO_NOT_TRACK", "")]), On),
		(run(on, url, Bool.False, [("DO_NOT_TRACK", "0")]), On),
		# CI: `true` or `1`, any case, as the row CI of R-NM1. The other variables of R-NM1 and TALON_INTERACTIVE change nothing.
		(run(on, url, Bool.False, [("CI", "true")]), Off(Ci)),
		(run(on, url, Bool.False, [("CI", "TRUE")]), Off(Ci)),
		(run(on, url, Bool.False, [("CI", "1")]), Off(Ci)),
		(run(on, url, Bool.False, [("CI", "false")]), On),
		(run(on, url, Bool.False, [("CI", "0")]), On),
		(run(on, url, Bool.False, [("CI", "")]), On),
		(run(on, url, Bool.False, [("CI", "true"), ("TALON_INTERACTIVE", "1")]), Off(Ci)),
		(run(on, url, Bool.False, [("DEBIAN_FRONTEND", "noninteractive"), ("NONINTERACTIVE", "1")]), On),
		# The order: row 1, then 2, 3, 4, 5.
		(run(Err(Unset), Direct, Bool.True, [("DO_NOT_TRACK", "1"), ("CI", "true")]), Off(Share)),
		(run(on, Direct, Bool.True, [("DO_NOT_TRACK", "1"), ("CI", "true")]), Off(Registry)),
		(run(on, url, Bool.True, [("DO_NOT_TRACK", "1"), ("CI", "true")]), Off(Offline)),
		(run(on, url, Bool.False, [("DO_NOT_TRACK", "1"), ("CI", "true")]), Off(DoNotTrack)),
	]
	rows.all(|(got, want)| got == want)
}

# R-SH1, R-TF4: `share` is a boolean of `config.toml`. Not set is off. A wrong form is exit 19 with the line. The key `registry` is read as a text. R-SH8 text of a condition and the word in `--json`.
expect {
	path = "$CONFIG/config.toml"
	read = |text| Share.setting({ path, text })
	rows = [
		(read(""), Ok({ share: Err(Unset), registry: Err(Unset) })),
		(read("share = true\n"), Ok({ share: Ok(Bool.True), registry: Err(Unset) })),
		(read("nightly = true\nshare = false\nregistry = \"https://r.example\"\n"), Ok({ share: Ok(Bool.False), registry: Ok("https://r.example") })),
		(read("registry = \"direct\"\n"), Ok({ share: Err(Unset), registry: Ok("direct") })),
		(read("share = \"yes\"\n"), Err(Fail.new(Input, "${path}:1: share: must be true or false"))),
		(read("nightly = true\nshare = 1\n"), Err(Fail.new(Input, "${path}:2: share: must be true or false"))),
		(read("share = [\n"), Err(Fail.new(Input, "${path}:1: not valid TOML"))),
	]
	reasons = [Share, Registry, Offline, DoNotTrack, Ci]
	rows.all(|(got, want)| got == want)
		and reasons.map(Share.reason_text) == ["share is not true in config.toml", "the registry is direct", "--offline is set", "DO_NOT_TRACK is set", "CI is set"]
			and reasons.map(Share.reason_word) == ["share", "registry", "offline", "do-not-track", "ci"]
}

# R-SH1, R-CC6: the edit of `config.toml` by `share on` and `share off`. The same value: no write. The other value: the span edit, comments and other bytes stay. No key: the line is added
# (the empty text gives one line with a line end). A key that is not a boolean, and text that is not TOML, are exit 19. A new key goes before the first table (else it would be a key of the table).
expect {
	path = "$CONFIG/config.toml"
	edit = |text, value| Share.edit({ path, text, value })
	moved = match edit("nightly = true\n\n[probe]\nmax = 3\n", Bool.False) {
		Ok({ previous: Err(Unset), edit: Set(text) }) => Share.setting({ path, text }) == Ok({ share: Ok(Bool.False), registry: Err(Unset) }) and text.contains("[probe]\nmax = 3\n") and text.starts_with("nightly = true\n")
		_ => Bool.False
	}
	rows = [
		(edit("", Bool.True), Ok({ previous: Err(Unset), edit: Set("share = true\n") })),
		(edit("", Bool.False), Ok({ previous: Err(Unset), edit: Set("share = false\n") })),
		(edit("# my notes\nnightly = true\n", Bool.True), Ok({ previous: Err(Unset), edit: Set("# my notes\nnightly = true\nshare = true\n") })),
		(edit("share = false # keep me\ngc-age = \"30d\"\n", Bool.True), Ok({ previous: Ok(Bool.False), edit: Set("share = true # keep me\ngc-age = \"30d\"\n") })),
		(edit("share = true\n", Bool.True), Ok({ previous: Ok(Bool.True), edit: Same })),
		(edit("share = false\n", Bool.False), Ok({ previous: Ok(Bool.False), edit: Same })),
		(edit("share = \"yes\"\n", Bool.True), Err(Fail.new(Input, "${path}:1: share: must be true or false"))),
		(edit("share = [\n", Bool.True), Err(Fail.new(Input, "${path}:1: not valid TOML"))),
	]
	moved and rows.all(|(got, want)| got == want)
}

# R-SH8, R-SH5, R-SH6, R-SE15, R-OUT2: the local part of `tln share`. Only the first 8 characters of the id are shown (the proposed text). The 2 times are shown when they are set.
# The `--json` data has the same facts. The lines have a line end.
expect {
	totals = { ..ShareJson.fresh(full_id), sent: 7, counted: 5, first: 2, first_sent_at: Ok("2026-10-01T10:00:00Z"), last_sent_at: Ok("2026-10-02T11:30:00Z") }
	on_lines = Share.status_lines({ state: On, doc: totals, queued: 4 })
	off_lines = Share.status_lines({ state: Off(DoNotTrack), doc: ShareJson.fresh(full_id), queued: 0 })
	on_data = JsonDoc.render(Share.status_data({ state: On, doc: totals, queued: 4 }))
	off_data = JsonDoc.render(Share.status_data({ state: Off(Ci), doc: ShareJson.fresh(full_id), queued: 0 }))
	on_lines == ["sharing: on\n", "id: 01234567\n", "sent: 7\n", "counted: 5\n", "first: 2\n", "first sent: 2026-10-01T10:00:00Z\n", "last sent: 2026-10-02T11:30:00Z\n", "queued: 4\n"]
		and off_lines == ["sharing: off (DO_NOT_TRACK is set)\n", "id: 01234567\n", "sent: 0\n", "counted: 0\n", "first: 0\n", "queued: 0\n"]
			and on_data == "{\"on\":true,\"reason\":null,\"id\":\"01234567\",\"sent\":7,\"counted\":5,\"first\":2,\"first_sent_at\":\"2026-10-01T10:00:00Z\",\"last_sent_at\":\"2026-10-02T11:30:00Z\",\"queued\":4}"
				and off_data == "{\"on\":false,\"reason\":\"ci\",\"id\":\"01234567\",\"sent\":0,\"counted\":0,\"first\":0,\"first_sent_at\":null,\"last_sent_at\":null,\"queued\":0}"
}

# R-SH10, R-SH1, R-SH4, R-OUT2: `share on` with the registry `direct` writes the setting and says that nothing is sent. The texts of `on`, `off` and the data (proposal).
expect {
	Share.on_lines({ sends: Bool.True }) == ["sharing: on\n"]
		and Share.on_lines({ sends: Bool.False }) == ["sharing: on\n", "Talon shares nothing while the registry is direct.\n"]
			and Share.off_lines({}) == ["sharing: off\n"]
				and JsonDoc.render(Share.on_data({ sends: Bool.True })) == "{\"share\":true,\"sends\":true}"
					and JsonDoc.render(Share.on_data({ sends: Bool.False })) == "{\"share\":true,\"sends\":false}"
						and JsonDoc.render(Share.off_data({})) == "{\"share\":false}"
}

# R-SH5, R-SE15: share.json gets the mode 0600 with `chmod 0600 <file>` (as R-HF2 does for the compiler). A Windows host needs none.
# D7 (proposal, TW24): the warning of a failed `ClearQueue` names the share queue, and a too new file is exit 19.
expect {
	Share.chmod_command({ windows: Bool.False, file: "/d/share.json" }) == Ok(["chmod", "0600", "/d/share.json"])
		and Share.chmod_command({ windows: Bool.True, file: "C:\\d\\share.json" }) == Err(NotNeeded)
			and Share.clear_err({ err: Busy, path: "/c/compat.db" }) == Warn("compat.db is busy: the share queue is not emptied")
				and Share.clear_err({ err: Failed("disk full"), path: "/c/compat.db" }) == Warn("cannot use /c/compat.db (disk full): the share queue is not emptied")
					and match Share.clear_err({ err: TooNew(2), path: "/c/compat.db" }) {
						Stop(fail) => fail.kind == Input
						Warn(_) => Bool.False
					}
}

# R-SH11, R-NM1, R-NM2, R-NM12, R-SH2 rows 4 and 5: steps 0 and 1 of the first-run prompt. `tln share` (any word) and `tln setup` never ask (step 0, from the arguments only). A non-interactive mode never asks (`--json`, `CI`, `DEBIAN_FRONTEND`, `NONINTERACTIVE`,
# `TALON_INTERACTIVE=0`). `DO_NOT_TRACK` (set, not empty, not `0`) and `CI` (with `TALON_INTERACTIVE=1`) turn the prompt off. `--offline` and `TALON_REGISTRY` are not in step 1. The order of step 1: mode, `DO_NOT_TRACK`, `CI`.
expect {
	g = |env, json| FirstRun.gate({ env, json })
	commands_ok = FirstRun.of_command(["cache", "dir"]) == Check
		and FirstRun.of_command(["install"]) == Check
			and FirstRun.of_command(["roc", "install"]) == Check
				and FirstRun.of_command(["x"]) == Check
					and FirstRun.of_command(["tool", "install"]) == Check
	commands_skip = FirstRun.of_command(["share"]) == Skip(Command)
		and FirstRun.of_command(["share", "on"]) == Skip(Command)
			and FirstRun.of_command(["share", "login"]) == Skip(Command)
				and FirstRun.of_command(["setup"]) == Skip(Command)
	modes = g([], Bool.True) == Skip(NonInteractive)
		and g([("CI", "true")], Bool.False) == Skip(NonInteractive)
			and g([("CI", "TRUE")], Bool.False) == Skip(NonInteractive)
				and g([("CI", "1")], Bool.False) == Skip(NonInteractive)
					and g([("DEBIAN_FRONTEND", "noninteractive")], Bool.False) == Skip(NonInteractive)
						and g([("NONINTERACTIVE", "1")], Bool.False) == Skip(NonInteractive)
							and g([("TALON_INTERACTIVE", "0")], Bool.False) == Skip(NonInteractive)
								and g([("CI", "false")], Bool.False) == NeedTty
									and g([("CI", "0")], Bool.False) == NeedTty
										and g([("NONINTERACTIVE", "1"), ("TALON_INTERACTIVE", "1")], Bool.False) == NeedTty
											and g([("TALON_INTERACTIVE", "1")], Bool.True) == Skip(NonInteractive)
	conditions = g([], Bool.False) == NeedTty
		and g([("DO_NOT_TRACK", "1")], Bool.False) == Skip(DoNotTrack)
			and g([("DO_NOT_TRACK", "true")], Bool.False) == Skip(DoNotTrack)
				and g([("DO_NOT_TRACK", "")], Bool.False) == NeedTty
					and g([("DO_NOT_TRACK", "0")], Bool.False) == NeedTty
						and g([("CI", "true"), ("TALON_INTERACTIVE", "1")], Bool.False) == Skip(Ci)
							and g([("CI", "1"), ("TALON_INTERACTIVE", "1")], Bool.False) == Skip(Ci)
								and g([("DO_NOT_TRACK", "1"), ("CI", "true"), ("TALON_INTERACTIVE", "1")], Bool.False) == Skip(DoNotTrack)
									and g([("DO_NOT_TRACK", "1"), ("CI", "true")], Bool.False) == Skip(NonInteractive)
										and g([("TALON_REGISTRY", "direct"), ("TALON_INTERACTIVE", "1")], Bool.False) == NeedTty
	commands_ok and commands_skip and modes and conditions
}

# R-SH11, R-SH1, R-RG1: step 2 of the first-run prompt. A set `share` (true or false) means that Talon asked already. With `share` not set, a `direct` registry does not ask (condition 2 of R-SH2). Else Talon asks.
# R-NM12, R-SH11: what Talon writes after the prompt. The end of input (the returned mode is `NonInteractive`) writes nothing, so `share` stays not set. A typed answer writes `true` or `false`.
expect {
	url = Url("https://registry.example.org")
	need_ok = FirstRun.need({ share: Err(Unset), registry: url }) == Ask
		and FirstRun.need({ share: Ok(Bool.True), registry: url }) == Skip(Set)
			and FirstRun.need({ share: Ok(Bool.False), registry: url }) == Skip(Set)
				and FirstRun.need({ share: Err(Unset), registry: Direct }) == Skip(Direct)
					and FirstRun.need({ share: Ok(Bool.False), registry: Direct }) == Skip(Set)
	written_ok = FirstRun.written({ answer: Yes, mode: Interactive }) == Write(Bool.True)
		and FirstRun.written({ answer: No, mode: Interactive }) == Write(Bool.False)
			and FirstRun.written({ answer: No, mode: NonInteractive }) == Nothing
				and FirstRun.written({ answer: Yes, mode: NonInteractive }) == Nothing
					and FirstRun.written({ answer: Option(1), mode: Interactive }) == Nothing
	need_ok and written_ok
}

# R-NI16, R-NM12: the prompt is a Consent prompt with the default No and no answer flag. Its text names what Talon sends, how long the registry keeps it, that reads do not need it, and `tln share off` (proposal, TW24).
expect {
	prompt = FirstRun.prompt({})
	text = "Talon can share the results of its probes with the registry.\nFor a public package it sends the hash of the package, the compiler, the target, the Talon version and the result (pass, fail or crash). It sends no code, no path and no error text.\nThe registry keeps each result with a random id of this machine until you run tln share forget, or until its compiler is 12 months old.\nReading compatibility data does not need sharing.\nYou can turn sharing off at any time with tln share off.\nShare the probe results of public packages? [y/N] "
	prompt.id == "share"
		and prompt.kind == Consent
			and prompt.shape == YesNo
				and prompt.default == No
					and prompt.subject == "sharing probe results"
						and Prompt.text(prompt) == text
							and Prompt.decide(prompt, { mode: Interactive, yes: Bool.True, flag: Err(NoFlag) }) == Ask
								and Prompt.decide(prompt, { mode: NonInteractive, yes: Bool.True, flag: Err(NoFlag) }) == Use(No)
}

# Q213 (G-C32), R-SH8, R-SH13, R-OUT2, slice 213b: `tln share` when `share.json` does not exist. The `Doc` for it has the id `none` and 3 totals of 0. It is shown as `id: none` and in `--json` `"id":null` (Design Q217).
# R-SH13: the same `Doc` is never a file: its id is not 32 hex digits, so `ShareJson.read` of its text is a failure of kind Input (so a bug that writes it is found when it is read).
expect {
	doc = ShareJson.absent({})
	lines = Share.status_lines({ state: Off(Share), doc, queued: 0 })
	data = JsonDoc.render(Share.status_data({ state: On, doc, queued: 3 }))
	lines == ["sharing: off (share is not true in config.toml)\n", "id: none\n", "sent: 0\n", "counted: 0\n", "first: 0\n", "queued: 0\n"]
		and data == "{\"on\":true,\"reason\":null,\"id\":null,\"sent\":0,\"counted\":0,\"first\":0,\"first_sent_at\":null,\"last_sent_at\":null,\"queued\":3}"
			and doc == { ..ShareJson.fresh("none"), extra: [] }
				and match ShareJson.read({ path: "$DATA/share.json", text: ShareJson.text(doc) }) {
					Err(fail) => fail.kind == Input
					Ok(_) => Bool.False
				}
}

# R-SH11, R-EV29, Design Q215, slice 213b: a `tln` that sees `TALON_SHARE_ASKED=1` does not ask (`Skip(Asked)`). Unset, and other names, do not skip. The check is in the env of step 1, so it needs no more call.
# The env of a child (and of the `Fx` of the command) has the name once, with the value `1`, at the end. The other entries keep their order. An old value of the name is replaced.
expect {
	g = |env| FirstRun.gate({ env, json: Bool.False })
	asked = g([("TALON_SHARE_ASKED", "1")]) == Skip(Asked)
		and g([("HOME", "/h"), ("TALON_SHARE_ASKED", "1"), ("TALON_INTERACTIVE", "1")]) == Skip(Asked)
			and g([("TALON_SHARE_ASKED_X", "1")]) == NeedTty
				and g([("TALON_INTERACTIVE", "1")]) == NeedTty
	child = FirstRun.child_env([]) == [("TALON_SHARE_ASKED", "1")]
		and FirstRun.child_env([("A", "1"), ("B", "2")]) == [("A", "1"), ("B", "2"), ("TALON_SHARE_ASKED", "1")]
			and FirstRun.child_env([("TALON_SHARE_ASKED", "0"), ("A", "1")]) == [("A", "1"), ("TALON_SHARE_ASKED", "1")]
				and FirstRun.child_env([("A", "1"), ("TALON_SHARE_ASKED", "1"), ("B", "2")]) == [("A", "1"), ("B", "2"), ("TALON_SHARE_ASKED", "1")]
					and FirstRun.child_env(FirstRun.child_env([("A", "1")])) == [("A", "1"), ("TALON_SHARE_ASKED", "1")]
	asked and child
}
