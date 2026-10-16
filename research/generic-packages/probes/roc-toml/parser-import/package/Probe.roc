import parser.Parser
import parser.Utf8

## Probe: a module that imports roc-parser Parser and Utf8.
Probe :: [].{

	## The bare key at the start of the text.
	bare_key : Str -> Try(Str, [BadKey])
	bare_key = |text| Utf8.parse_str(key_parser, text).map_err(|_| BadKey)
}

key_parser : Parser(Utf8.Bytes, Str)
key_parser = Parser.one_or_more(Utf8.codeunit_satisfies(|c| (c >= 'a' and c <= 'z') or c == '_')).map(|cs| Str.from_utf8(cs) ?? "")

expect Probe.bare_key("abc") == Ok("abc")
