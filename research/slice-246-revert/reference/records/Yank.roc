import Release
import Nullable

## PRIVATE REFERENCE of slice 246 (not for the code agent, TW18). Bodies for the stubs of packages/records/Yank.roc.
Yank :: [].{

	reason_limit : U64
	reason_limit = 500

	Request : { reason : Try(Str, [None]) }

	check_reason : Str -> Try({}, [TooLong, ControlChar])
	check_reason = |text| {
		if text.count_utf8_bytes() > reason_limit {
			Err(TooLong)
		} else if text.to_utf8().keep_if(|b| b < 32 or b == 127).len() > 0 {
			Err(ControlChar)
		} else {
			Ok({})
		}
	}

	ReqWire : { reason : Nullable(Str) }

	encode_request : Yank.Request -> Str
	encode_request = |request| match request.reason {
		Ok(text) => {
			w : Yank.ReqWire
			w = { reason: Nullable.write(Ok(text)) }
			Json.to_str(w)
		}
		Err(None) => "{}"
	}

	Empty : {}

	decode_request : Str -> Try(Yank.Request, [BadJson(Str)])
	decode_request = |text| {
		parsed : Try(Yank.ReqWire, _)
		parsed = Json.parse(text)
		match parsed {
			Ok(w) => Ok({ reason: Nullable.read(w.reason) })
			Err(e) => {
				none : Try(Yank.Empty, _)
				none = Json.parse(text)
				match none {
					Ok(_) if !text.contains("\"reason\"") => Ok({ reason: Err(None) })
					Ok(_) => Err(BadJson(Str.inspect(e)))
					Err(_) => Err(BadJson(Str.inspect(e)))
				}
			}
		}
	}

	encode_answer : Release.Row -> Str
	encode_answer = |release| "{\"release\":${Release.encode(release)}}"

	AnsWire : { release : Release.Wire }

	decode_answer : Str -> Try(Release.Row, [BadJson(Str)])
	decode_answer = |text| {
		parsed : Try(Yank.AnsWire, _)
		parsed = Json.parse(text)
		parsed.map_ok(|w| Release.from_wire(w.release)).map_err(|e| BadJson(Str.inspect(e)))
	}
}
