import parser.Parser
import parser.Utf8

## Leak probe: the recursion through `Parser.lazy` with named thunk functions.
P :: [].{
	check : Str -> Bool
	check = |text| Utf8.parse_str(p, text).is_ok()
}

p : Parser(Utf8.Bytes, List(U8))
p = Parser.lazy(p_thunk)

p_thunk : {} -> Parser(Utf8.Bytes, List(U8))
p_thunk = |_| p_rule

p_rule : Parser(Utf8.Bytes, List(U8))
p_rule = Parser.const(|x| x).skip(Utf8.codeunit('[')).keep(q.many()).skip(Utf8.codeunit(']'))

q : Parser(Utf8.Bytes, U8)
q = Parser.lazy(q_thunk)

q_thunk : {} -> Parser(Utf8.Bytes, U8)
q_thunk = |_| q_rule

q_rule : Parser(Utf8.Bytes, U8)
q_rule = p.map(|l| l.len().to_u8_wrap())
