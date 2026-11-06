import lib.Fail
import lib.JsonDoc
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
