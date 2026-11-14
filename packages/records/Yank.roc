import Nullable
import Release

## The wire bodies of the yank routes (Registry R-YK1 to R-YK7, R-YK6, R-AP49, R-AP51; slice 246, `docs/slices/246-yank.md`). Pure. The CLI uses them later (`tln yank`, R-CM21).
## The tests are `packages/records/tests/YankTest.roc`.
## The request of `PUT /v1/releases/{log_index}/yank` is `{"reason": "<text>"}`. `reason` is optional (R-YK6, R-AP51): a missing member and `null` are no reason. `DELETE` has no body.
## The answer of both routes is the release record (R-YK1) in the form of the answer of a publish (R-AP8): `{"release": <Release.encode>}` (TW24 proposal, the slice file section 5).
Yank :: [].{

	## The most bytes of a `reason` (R-YK6). UTF-8 bytes, not characters.
	reason_limit : U64
	reason_limit = 500

	## The request body. `reason` is `Err(None)` for no reason.
	Request : { reason : Try(Str, [None]) }

	## R-YK6: `reason` is at most `reason_limit` bytes of UTF-8 with no control character. `TooLong`: more bytes. `ControlChar`: a character of the Unicode category Cc is in the text:
	## U+0000 to U+001F (a tab and a new line too) and U+007F. The empty text is good. The length is checked first: a text that has both faults is `TooLong`.
	## (Q246-3: U+0080 to U+009F is not checked by the tests.)
	check_reason : Str -> Try({}, [TooLong, ControlChar])
	check_reason = |text| {
		bytes = text.to_utf8()
		if bytes.len() > reason_limit {
			Err(TooLong)
		} else if has_control(bytes) {
			Err(ControlChar)
		} else {
			Ok({})
		}
	}

	## Q246-3: U+0000 to U+001F and U+007F are the bytes below 32 and 127. U+0080 to U+009F are the 2 bytes `C2 80` to `C2 9F` (the byte `C2` is always the first byte of a character).
	has_control : List(U8) -> Bool
	has_control = |bytes| {
		if bytes.any(|b| b < 32 or b == 127) {
			Bool.True
		} else {
			var $found = Bool.False
			var $previous = 0.U8
			for b in bytes {
				if $previous == 194 and b >= 128 and b <= 159 {
					$found = Bool.True
				}
				$previous = b
			}
			$found
		}
	}

	## The wire form of a request: `reason` is left out for none (R-AP51).
	Wire : { reason : Try(Nullable(Str), [Missing]) }

	AnswerWire : { release : Release.Wire }

	## The text of a request: `{"reason":"<text>"}` with the JSON escapes of the other codecs of this package, and `{}` for no reason (R-AP51: the writer leaves out an optional member that has no value).
	encode_request : Yank.Request -> Str
	encode_request = |request| {
		wire : Yank.Wire
		wire = { reason: Nullable.write_opt(request.reason) }
		Json.to_str(wire)
	}

	## R-AP51: a missing `reason`, and `null`, are `Err(None)`. A member that the reader does not know is ignored (R-AP44). A `reason` that is not a text, and a text that is not a JSON object, are `BadJson`.
	## The decode does not check the rule of R-YK6 (`check_reason` does, and the Worker maps it to 400).
	decode_request : Str -> Try(Yank.Request, [BadJson(Str)])
	decode_request = |text| {
		parsed : Try(Yank.Wire, _)
		parsed = Json.parse(text)
		parsed.map_ok(|w| { reason: Nullable.read_opt(w.reason) }).map_err(|e| BadJson(Str.inspect(e)))
	}

	## The body of a 200 answer: `{"release":<Release.encode of the record>}`, no white space.
	encode_answer : Release.Row -> Str
	encode_answer = |release| "{\"release\":${Release.encode(release)}}"

	## The release of an answer. A missing `release` is `BadJson` (R-AP51).
	decode_answer : Str -> Try(Release.Row, [BadJson(Str)])
	decode_answer = |text| {
		parsed : Try(Yank.AnswerWire, _)
		parsed = Json.parse(text)
		parsed.map_ok(|w| Release.from_wire(w.release)).map_err(|e| BadJson(Str.inspect(e)))
	}
}
