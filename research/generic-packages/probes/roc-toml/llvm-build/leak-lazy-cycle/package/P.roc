import parser.Parser
import parser.Utf8

## Leak probe: a cycle of top-level parsers through `Parser.lazy` and a lambda.
P :: [].{
	check : Str -> Bool
	check = |text| Utf8.parse_str(p, text).is_ok()
}

p : Parser(Utf8.Bytes, List(U8))
p = Parser.const(|x| x).skip(Utf8.codeunit('[')).keep(Parser.lazy(|_| q).many()).skip(Utf8.codeunit(']'))

q : Parser(Utf8.Bytes, U8)
q = Parser.custom(|input| Parser.run(p.map(|l| l.len().to_u8_wrap()), input))
