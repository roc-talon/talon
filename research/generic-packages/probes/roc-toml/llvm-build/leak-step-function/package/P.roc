import parser.Parser
import parser.Utf8

## Leak probe: the same recursion through a named step function.
P :: [].{
	check : Str -> Bool
	check = |text| Utf8.parse_str(p, text).is_ok()
}

p : Parser(Utf8.Bytes, List(U8))
p = Parser.const(|x| x).skip(Utf8.codeunit('[')).keep(q.many()).skip(Utf8.codeunit(']'))

q : Parser(Utf8.Bytes, U8)
q = Parser.custom(q_step)

q_step : Utf8.Bytes -> Parser.ParseResult(Utf8.Bytes, U8)
q_step = |input| Parser.run(p.map(|l| l.len().to_u8_wrap()), input)
