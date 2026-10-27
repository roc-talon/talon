import lib.Fail
import lib.JsonDoc
import lib.TalonFile

TalonfileTest :: [].{}

# R-TF1 R-TF2: `JsonDoc.parse` reads a Talon file and keeps the order of the keys and every key (an unknown field stays).
# G2 (slice 003): every valid JSON number is read. An integer that fits `I64` is `Num`, any other number is `Real` with its text. A text that is not a valid JSON number is an error. Text after the value, a missing comma and a trailing comma are errors.
expect {
	ok = [
		(
			"{\"format\":1,\"projects\":[{\"path\":\"/a/b\",\"last_use\":5}]}",
			Ok(JsonDoc.Obj([("format", JsonDoc.Num(1)), ("projects", JsonDoc.Arr([JsonDoc.Obj([("path", JsonDoc.Text("/a/b")), ("last_use", JsonDoc.Num(5))])]))])),
		),
		(
			" {\n \"a\" : [ 1 , -2 , true , false , null ] }\n",
			Ok(JsonDoc.Obj([("a", JsonDoc.Arr([JsonDoc.Num(1), JsonDoc.Num(-2), JsonDoc.Flag(Bool.True), JsonDoc.Flag(Bool.False), JsonDoc.Null]))])),
		),
		("{\"z\":1,\"a\":2}", Ok(JsonDoc.Obj([("z", JsonDoc.Num(1)), ("a", JsonDoc.Num(2))]))),
		("\"a\\\"b\\\\c\\nd\\u0041\\/\"", Ok(JsonDoc.Text("a\"b\\c\ndA/"))),
		("{}", Ok(JsonDoc.Obj([]))),
		("[]", Ok(JsonDoc.Arr([]))),
		("0", Ok(JsonDoc.Num(0))),
		("{\"a\":1.5}", Ok(JsonDoc.Obj([("a", JsonDoc.Real("1.5"))]))),
		(
			"[1e3,-0.25E+2,0.0,12345678901234567890,-9223372036854775808]",
			Ok(JsonDoc.Arr([JsonDoc.Real("1e3"), JsonDoc.Real("-0.25E+2"), JsonDoc.Real("0.0"), JsonDoc.Real("12345678901234567890"), JsonDoc.Num(-9223372036854775808)])),
		),
	]
	errors = ["", "{", "{\"a\":1} x", "{'a':1}", "[1,]", "tru", "{\"a\":1,}", "{\"a\" 1}", "[1 2]", "[01]", "[1.]", "[.5]", "[1e]", "[1e+]", "[-]", "[+1]", "[1.5.5]"]
	bad_ok = ok.keep_if(|(text, want)| JsonDoc.parse(text) != want)
	bad_errors = errors.keep_if(|text| JsonDoc.parse(text) != Err(BadJson))
	round = "{\"format\":1,\"projects\":[{\"path\":\"/a/b\",\"last_use\":5}],\"extra\":null,\"f\":[1.5,2e10]}"
	round_ok = JsonDoc.parse(round).map_ok(|doc| doc.render()) == Ok(round)
	dbg (bad_ok, bad_errors)
	bad_ok == [] and bad_errors == [] and round_ok
}

# R-TF1 R-TF2 R-TF3 R-TF6: the read of a Talon file. `format` is a top-level integer, and the other fields stay in order.
# A newer format stops the command (exit 19), and the message names the file and `tln tool update talon`, unless the file
# can be made again: then it is ignored. Content that does not parse stops the command (exit 19) and names the file,
# unless the file can be made again: then Talon deletes it, warns and makes it again.
expect {
	path = "/h/f.json"
	newer = "tln: error[input]: /h/f.json: format 2 is newer than this tln (format 1). Run: tln tool update talon"
	garbage = "tln: error[input]: /h/f.json: the content does not parse"
	warning = "/h/f.json: the content does not parse. Talon deletes it and makes it again."
	open = |text, newest, can_recreate| match TalonFile.open({ path, text, newest, can_recreate }) {
		Ok(read) => Ok(read)
		Err(f) => Err(Fail.line(f))
	}
	extra = [("projects", JsonDoc.Arr([])), ("extra", JsonDoc.Obj([("k", JsonDoc.Flag(Bool.True))]))]
	rows = [
		("known and unknown fields", open("{\"format\":1,\"projects\":[],\"extra\":{\"k\":true}}", 1, Bool.False), Ok(Use({ format: 1, fields: extra }))),
		("an older format is read as it is", open("{\"format\":1,\"a\":1}", 2, Bool.False), Ok(Use({ format: 1, fields: [("a", JsonDoc.Num(1))] }))),
		("format is not first", open("{\"a\":1,\"format\":1}", 1, Bool.False), Ok(Use({ format: 1, fields: [("a", JsonDoc.Num(1))] }))),
		("newer format", open("{\"format\":2,\"a\":1}", 1, Bool.False), Err(newer)),
		("newer format, can be made again", open("{\"format\":2,\"a\":1}", 1, Bool.True), Ok(Ignore)),
		("not JSON", open("garbage{", 1, Bool.False), Err(garbage)),
		("not JSON, can be made again", open("garbage{", 1, Bool.True), Ok(Recreate(warning))),
		("not an object", open("[1,2]", 1, Bool.False), Err(garbage)),
		("no format", open("{\"a\":1}", 1, Bool.False), Err(garbage)),
		("format is text", open("{\"format\":\"1\"}", 1, Bool.False), Err(garbage)),
		("format is not an integer", open("{\"format\":1.5}", 1, Bool.False), Err(garbage)),
		("empty file", open("", 1, Bool.False), Err(garbage)),
		("empty file, can be made again", open("", 1, Bool.True), Ok(Recreate(warning))),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-TF1 R-TF2 R-TF3: the text of a write. `format` first, then the fields in order, as one line, and one newline. Writing
# the read fields keeps unknown fields. The form is a proposal.
expect {
	fields = [("projects", JsonDoc.Arr([JsonDoc.Obj([("path", JsonDoc.Text("/a")), ("last_use", JsonDoc.Num(1))])])), ("extra", JsonDoc.Null)]
	text = TalonFile.render({ format: 1, fields })
	empty = TalonFile.render({ format: 3, fields: [] })
	again = match TalonFile.open({ path: "/h/f.json", text, newest: 1, can_recreate: Bool.False }) {
		Ok(Use(read)) => read.fields == fields and read.format == 1
		_ => Bool.False
	}
	dbg (text, empty)
	text == "{\"format\":1,\"projects\":[{\"path\":\"/a\",\"last_use\":1}],\"extra\":null}\n" and empty == "{\"format\":3}\n" and again
}
