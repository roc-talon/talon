import parser.Parser
import parser.Utf8

## A `name=number` pair, read with roc-parser.
Pair :: { name : Str, value : U64 }.{

	## Reads `name=number`. The name is lowercase ASCII letters.
	parse : Str -> Try(Pair, [BadPair])
	parse = |text| Utf8.parse_str(pair_parser, text).map_err(|_| BadPair)

	name : Pair -> Str
	name = |p| p.name

	value : Pair -> U64
	value = |p| p.value
}

pair_parser : Parser(Utf8.Bytes, Pair)
pair_parser = Parser.const(|name| |value| { name, value }).keep(word).skip(Utf8.codeunit('=')).keep(Utf8.digits)

word : Parser(Utf8.Bytes, Str)
word = Parser.one_or_more(Utf8.codeunit_satisfies(|c| c >= 'a' and c <= 'z')).map(|cs| Str.from_utf8(cs) ?? "")
