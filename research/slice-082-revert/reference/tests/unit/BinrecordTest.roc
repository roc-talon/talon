import lib.BinRecord
import lib.Setup
import lib.ToolInstall
import lib.ToolManage

BinrecordTest :: [].{}

# Slice 078 (docs/slices/078-bin-records.md): the record of the bin dir entries that Talon made (`bin` in `tools.json`, R-T4, R-ST11) and the test "is this entry Talon's" (R-ST11, R-ST9, R-ST6). The expected value of each row is the design text or the slice file text, not the code.
# A wrong row prints with `dbg`. The flows (the Fx calls, the files) are in the L2 cases `setup/st9-stale-recorded`, `setup/st10-no-record` and in the changed trees of the tool cases.

path = "/d/talon/tools.json"

s1 = Str.repeat("a", 64)

s2 = Str.repeat("b", 64)

s3 = Str.repeat("c", 64)

foo_fields = "\"name\":\"acme/foo\",\"source\":{\"kind\":\"release\",\"version\":\"1.1.0\",\"url\":\"https://github.com/acme/foo/releases/download/1.1.0/AL3LZTP3UWR21xDHSrJudR7Cb5ofsXBNqdwip4kv6fVY.tar.zst\"},\"build\":{\"hashes\":[\"H1\"],\"nightly\":\"nightly-2026-10-14-38a3029\",\"target\":\"x64musl\"},\"sha256\":\"${s1}\",\"libs\":[],\"installed_at\":\"2026-10-15T12:00:00Z\""

talon_fields = "\"name\":\"roc-talon/talon\",\"source\":{\"kind\":\"prebuilt\",\"version\":\"0.3.2\",\"url\":\"https://github.com/roc-talon/talon/releases/download/v0.3.2/tln-x64musl\"},\"build\":{\"hashes\":[],\"nightly\":\"\",\"target\":\"x64musl\"},\"sha256\":\"${s1}\",\"libs\":[],\"installed_at\":\"2026-10-15T12:00:00Z\""

whole = |tools| "{\"format\":1,\"tools\":{${tools}}}"

pairs_text = |got| match got {
	Ok(pairs) => Str.join_with(pairs.map(|(name, sha)| "${name}=${sha}"), ",")
	Err(fail) => fail.line()
}

text_of = |got| match got {
	Ok(text) => text.trim_end()
	Err(fail) => fail.line()
}

# R-ST11 (2), R-T4, R-TF2, R-TF3: `BinRecord.read` gives the pairs (name, sha256) of the field `bin` of all entries, in the order of the text. A missing file, no `tools` field, an entry with no `bin`, a `bin` that is no object and a value that is no text give no pair:
# a bad record is no record, so the entry is foreign and R-ST6 keeps it. The failures are those of `ToolsJson.read` (exit 19).
expect {
	read = |text| pairs_text(BinRecord.read({ path, text }))
	two = whole("\"foo\":{${foo_fields},\"bin\":{\"foo\":\"${s1}\"}},\"talon\":{${talon_fields},\"bin\":{\"tln\":\"${s2}\",\"roc\":\"${s3}\"}}")
	rows = [
		("a missing file", read(Err(NotFound)), ""),
		("no tools field", read(Ok("{\"format\":1}")), ""),
		("no tool", read(Ok(whole(""))), ""),
		("a tool with no bin (an older Talon)", read(Ok(whole("\"foo\":{${foo_fields}}"))), ""),
		("an empty entry", read(Ok(whole("\"foo\":{}"))), ""),
		("one tool", read(Ok(whole("\"foo\":{${foo_fields},\"bin\":{\"foo\":\"${s1}\"}}"))), "foo=${s1}"),
		("a tool and the entry talon: the order of the text", read(Ok(two)), "foo=${s1},tln=${s2},roc=${s3}"),
		("bin is not the last field", read(Ok(whole("\"foo\":{\"bin\":{\"foo\":\"${s1}\"},${foo_fields}}"))), "foo=${s1}"),
		("a bin that is a number, a text, a list", read(Ok(whole("\"a\":{\"bin\":5},\"b\":{\"bin\":\"x\"},\"c\":{\"bin\":[\"${s1}\"]}"))), ""),
		("a value that is a number or null: no pair, the other names stay", read(Ok(whole("\"foo\":{\"bin\":{\"a\":5,\"b\":\"${s1}\",\"c\":null}}"))), "b=${s1}"),
		("a field that Talon does not know stays out of the way", read(Ok("{\"format\":1,\"note\":1,\"tools\":{\"foo\":{\"later\":7,\"bin\":{\"foo\":\"${s1}\"}}}}")), "foo=${s1}"),
		("a text that does not parse", read(Ok("not json")), "tln: error[input]: ${path}: the content does not parse"),
		("a newer format", read(Ok("{\"format\":2,\"tools\":{}}")), "tln: error[input]: ${path}: format 2 is newer than this tln (format 1). Run: tln tool update talon"),
		("tools is not an object", read(Ok("{\"format\":1,\"tools\":5}")), "tln: error[input]: ${path}: tools is not an object"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-T4 R-ST9 R-ST11 R-TF2 (slice 078): `BinRecord.set` writes the names of `bin` in the entry `key`. A name that is there gets the new sha256 in its place, a new name is the last of `bin`, `bin` is a new last field. Everything else stays, in its place (R-TF2).
# A missing file gives the empty text. Nothing to change gives the text byte for byte (the flow writes no file then). A bad text and a newer format are the failures of `read`.
expect {
	set = |text, key, bin| text_of(BinRecord.set({ path, text, key, bin }))
	foo_bin = |inner| whole("\"foo\":{${foo_fields},\"bin\":{${inner}}}")
	talon_bin = |inner| whole("\"talon\":{${talon_fields},\"bin\":{${inner}}}")
	plain = whole("\"foo\":{${foo_fields}}")
	later = "{\"format\":1,\"note\":\"keep\",\"tools\":{\"foo\":{\"later\":7,\"name\":\"x\"},\"bar\":{\"name\":\"y\"}}}"
	rows = [
		("a new bin is the last field of the entry", set(Ok(plain), "foo", [("foo", s1)]), foo_bin("\"foo\":\"${s1}\"")),
		("an empty entry gets only bin", set(Ok(whole("\"baz\":{}")), "baz", [("baz", s2)]), whole("\"baz\":{\"bin\":{\"baz\":\"${s2}\"}}")),
		("a name that is there: the new sha256 in its place", set(Ok(foo_bin("\"foo\":\"${s1}\"")), "foo", [("foo", s2)]), foo_bin("\"foo\":\"${s2}\"")),
		("the other names stay", set(Ok(talon_bin("\"tln\":\"${s1}\",\"roc\":\"${s1}\"")), "talon", [("tln", s2)]), talon_bin("\"tln\":\"${s2}\",\"roc\":\"${s1}\"")),
		("a name in place, a new name last", set(Ok(talon_bin("\"tln\":\"${s1}\"")), "talon", [("roc", s2), ("tln", s2)]), talon_bin("\"tln\":\"${s2}\",\"roc\":\"${s2}\"")),
		("2 new names, in the order of the list", set(Ok(whole("\"talon\":{${talon_fields}}")), "talon", [("tln", s1), ("roc", s2)]), talon_bin("\"tln\":\"${s1}\",\"roc\":\"${s2}\"")),
		("only the entry of the key changes: the other entry, the top-level field and the unknown field stay", set(Ok(later), "bar", [("bar", s1)]), "{\"format\":1,\"note\":\"keep\",\"tools\":{\"foo\":{\"later\":7,\"name\":\"x\"},\"bar\":{\"name\":\"y\",\"bin\":{\"bar\":\"${s1}\"}}}}"),
		("the unknown field of the entry stays before the new bin", set(Ok(later), "foo", [("foo", s1)]), "{\"format\":1,\"note\":\"keep\",\"tools\":{\"foo\":{\"later\":7,\"name\":\"x\",\"bin\":{\"foo\":\"${s1}\"}},\"bar\":{\"name\":\"y\"}}}"),
		("a bin that is not the last field stays in its place", set(Ok(whole("\"foo\":{\"bin\":{\"foo\":\"${s1}\"},\"name\":\"x\"}")), "foo", [("foo", s2)]), whole("\"foo\":{\"bin\":{\"foo\":\"${s2}\"},\"name\":\"x\"}")),
		("a name with a value that is no text: the new sha256 in its place", set(Ok(foo_bin("\"foo\":5")), "foo", [("foo", s1)]), foo_bin("\"foo\":\"${s1}\"")),
		# Review 2026-10-26 (Q2): `tools.json` is Talon's file, so a `bin` that is no object is replaced by an object (the same fail-safe as "a bad record is no record").
		("a bin that is no object is replaced by an object", set(Ok(whole("\"foo\":{${foo_fields},\"bin\":5}")), "foo", [("foo", s1)]), foo_bin("\"foo\":\"${s1}\"")),
		("a missing file", set(Err(NotFound), "foo", [("foo", s1)]), ""),
		("a text that does not parse", set(Ok("not json"), "foo", [("foo", s1)]), "tln: error[input]: ${path}: the content does not parse"),
		("a newer format", set(Ok("{\"format\":2,\"tools\":{}}"), "foo", [("foo", s1)]), "tln: error[input]: ${path}: format 2 is newer than this tln (format 1). Run: tln tool update talon"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	# The text as it is, with its line end (byte for byte).
	text_bin = foo_bin("\"foo\":\"${s1}\"").concat("\n")
	text_plain = plain.concat("\n")
	same = |text, key, bin| BinRecord.set({ path, text: Ok(text), key, bin }) == Ok(text)
	unchanged = [
		("the same sha256", same(text_bin, "foo", [("foo", s1)])),
		("2 names, both the same", same(talon_bin("\"tln\":\"${s1}\",\"roc\":\"${s2}\"").concat("\n"), "talon", [("roc", s2), ("tln", s1)])),
		("an empty list", same(text_plain, "foo", [])),
		("a key that is not in tools", same(text_plain, "zzz", [("zzz", s1)])),
		("no tools field", same("{\"format\":1}\n", "foo", [("foo", s1)])),
	]
	bad_same = unchanged.keep_if(|(_, ok)| !ok).map(|(label, _)| label)
	dbg bad_same
	bad == [] and bad_same == []
}

# R-ST9 R-ST11 R-S6 (slice 078): `BinRecord.record_all` is `set` for the entries that setup made: `tln` and `roc` are in the entry `talon`, any other name is in the entry of its key. On Windows the name of the entry has `.exe`, the record has none (one `.exe` is cut). The pairs of one entry are set together,
# in the order of `made`. An entry that is not in `tools` is left out. Nothing to change gives the text as it is.
expect {
	record = |text, made| text_of(BinRecord.record_all({ path, text, made: made.map(|(entry, sha256)| { entry, sha256 }) }))
	both = whole("\"foo\":{${foo_fields}},\"talon\":{${talon_fields}},\"baz\":{}")
	with_bin = |talon, foo, baz| whole("\"foo\":{${foo_fields}${foo}},\"talon\":{${talon_fields}${talon}},\"baz\":{${baz}}")
	talon_both = ",\"bin\":{\"tln\":\"${s1}\",\"roc\":\"${s1}\"}"
	rows = [
		("tln and roc: the entry talon", record(Ok(both), [("tln", s1), ("roc", s1)]), with_bin(talon_both, "", "")),
		("on Windows: the names have no .exe", record(Ok(both), [("tln.exe", s1), ("roc.exe", s1)]), with_bin(talon_both, "", "")),
		("a tool", record(Ok(both), [("foo", s2)]), with_bin("", ",\"bin\":{\"foo\":\"${s2}\"}", "")),
		("a tool on Windows", record(Ok(both), [("foo.exe", s2)]), with_bin("", ",\"bin\":{\"foo\":\"${s2}\"}", "")),
		("an empty entry of a tool", record(Ok(both), [("baz", s3)]), with_bin("", "", "\"bin\":{\"baz\":\"${s3}\"}")),
		("tln, a tool and an entry that is not in tools", record(Ok(both), [("tln", s1), ("qux", s2), ("foo", s3)]), with_bin(",\"bin\":{\"tln\":\"${s1}\"}", ",\"bin\":{\"foo\":\"${s3}\"}", "")),
		("one name of the entry talon: the other stays", record(Ok(whole("\"talon\":{${talon_fields},\"bin\":{\"tln\":\"${s1}\",\"roc\":\"${s1}\"}}")), [("roc", s2)]), whole("\"talon\":{${talon_fields},\"bin\":{\"tln\":\"${s1}\",\"roc\":\"${s2}\"}}")),
		("a missing file", record(Err(NotFound), [("tln", s1)]), ""),
		("a text that does not parse", record(Ok("not json"), [("tln", s1)]), "tln: error[input]: ${path}: the content does not parse"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	text = whole("\"talon\":{${talon_fields},\"bin\":{\"tln\":\"${s1}\",\"roc\":\"${s1}\"}},\"foo\":{${foo_fields}}").concat("\n")
	same = |made| BinRecord.record_all({ path, text: Ok(text), made }) == Ok(text)
	unchanged = [
		("no entry made", same([])),
		("the same sha256", same([{ entry: "tln", sha256: s1 }, { entry: "roc.exe", sha256: s1 }])),
		("an entry that is not in tools", same([{ entry: "qux", sha256: s2 }])),
	]
	bad_same = unchanged.keep_if(|(_, ok)| !ok).map(|(label, _)| label)
	dbg bad_same
	bad == [] and bad_same == []
}

# R-ST11 R-ST9 R-ST6 R-ST7 R-T4 (slice 078): setup, one entry. The entry is Talon's when its sha256 is the one of its source (1) or the recorded one (2). A stale entry that is recorded is `Repair` (made again, no prompt, also `roc`); any other file is `Foreign`; the record of a name
# does not count for `Dir` and `Unreadable`.
expect {
	judge = |source, recorded, have| Setup.judge_bin({ source, recorded, have })
	rows = [
		("no source, no entry", judge(Missing, Err(None), Absent), NoSource),
		("no source: the record does not matter", judge(Missing, Ok(s1), Sha(s1)), NoSource),
		("no entry: make it", judge(Sha(s1), Err(None), Absent), Make),
		("no entry, a record: make it", judge(Sha(s1), Ok(s2), Absent), Make),
		("the sha256 of the source: up to date", judge(Sha(s1), Err(None), Sha(s1)), Keep),
		("the sha256 of the source and another record: up to date", judge(Sha(s1), Ok(s2), Sha(s1)), Keep),
		("the sha256 of the record: stale, Talon's (R-ST9)", judge(Sha(s1), Ok(s2), Sha(s2)), Repair),
		("no record, other content (an older Talon, or a file of the user)", judge(Sha(s1), Err(None), Sha(s2)), Foreign),
		("another record than the sha256 of the entry", judge(Sha(s1), Ok(s3), Sha(s2)), Foreign),
		("a directory, with a record", judge(Sha(s1), Ok(s2), Dir), Foreign),
		("a file that cannot be read, with a record", judge(Sha(s1), Ok(s2), Unreadable), Foreign),
		("a directory", judge(Sha(s1), Err(None), Dir), Foreign),
		("a file that cannot be read", judge(Sha(s1), Err(None), Unreadable), Foreign),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-ST11 R-ST9 R-ST6 R-T4 R-T5 (slice 078): the install, update, rebuild and take-over of a tool. `old` is the sha256 of the file in the data bin dir (`Err(NotFound)`: it is gone). A stale entry that is recorded is Talon's, so the install replaces it (R-ST9: no failure `foreign`),
# also when the data file is gone. Any other file, a directory and an unreadable file are foreign (R-ST6).
expect {
	verdict = |old, recorded, have| ToolInstall.verdict_bin({ old, recorded, have })
	rows = [
		("no entry, a first install", verdict(Err(NotFound), Err(None), Absent), Make),
		("no entry", verdict(Ok(s1), Err(None), Absent), Make),
		("the sha256 of the data file", verdict(Ok(s1), Err(None), Sha(s1)), Make),
		("the sha256 of the data file, and the same record", verdict(Ok(s1), Ok(s1), Sha(s1)), Make),
		("other content, no record", verdict(Ok(s1), Err(None), Sha(s2)), Foreign),
		("the sha256 of the record: stale (R-ST9)", verdict(Ok(s1), Ok(s2), Sha(s2)), Make),
		("the data file is gone, the sha256 of the record", verdict(Err(NotFound), Ok(s2), Sha(s2)), Make),
		("the data file is gone, no record", verdict(Err(NotFound), Err(None), Sha(s2)), Foreign),
		("another record than the sha256 of the entry", verdict(Ok(s1), Ok(s3), Sha(s2)), Foreign),
		("a directory, with a record", verdict(Ok(s1), Ok(s2), Dir), Foreign),
		("a file that cannot be read, with a record", verdict(Ok(s1), Ok(s2), Unreadable), Foreign),
		("a directory, the data file is gone", verdict(Err(NotFound), Err(None), Dir), Foreign),
		("a file that cannot be read", verdict(Ok(s1), Err(None), Unreadable), Foreign),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-ST11 R-RM6 R-RM11 R-ST6 R-B6 (slice 078): `tln tool remove` and the removal of Talon. A stale entry that is recorded is Talon's: it is removed. Any other file is kept (R-ST6), with a warning.
expect {
	fate = |old, recorded, have| ToolManage.fate_bin({ old, recorded, have })
	rows = [
		("no entry", fate(Ok(s1), Err(None), Absent), Gone),
		("no entry, the data file is gone", fate(Err(NotFound), Ok(s1), Absent), Gone),
		("the sha256 of the data file", fate(Ok(s1), Err(None), Sha(s1)), Remove),
		("the sha256 of the data file and another record", fate(Ok(s1), Ok(s2), Sha(s1)), Remove),
		("the sha256 of the record: stale, Talon's", fate(Ok(s1), Ok(s2), Sha(s2)), Remove),
		("the data file is gone, the sha256 of the record", fate(Err(NotFound), Ok(s2), Sha(s2)), Remove),
		("other content, no record", fate(Ok(s1), Err(None), Sha(s2)), Keep),
		("the data file is gone, no record", fate(Err(NotFound), Err(None), Sha(s2)), Keep),
		("another record than the sha256 of the entry", fate(Ok(s1), Ok(s3), Sha(s2)), Keep),
		("a directory, with a record", fate(Ok(s1), Ok(s2), Dir), Keep),
		("a file that cannot be read, with a record", fate(Ok(s1), Ok(s2), Unreadable), Keep),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
