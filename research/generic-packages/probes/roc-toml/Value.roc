# Compiler facts for roc-toml on nightly-2026-10-09-258ab27: a recursive nominal
# with Dict(Str, Value) and derived is_eq works, Dict equality ignores order.
Value := [
	String(Str),
	Integer(I64),
	Float(F64),
	Boolean(Bool),
	LocalDate({ year : U16, month : U8, day : U8 }),
	Array(List(Value)),
	Table(Dict(Str, Value)),
].{
	is_eq : _

	get : Value, Str -> Try(Value, [NotFound])
	get = |v, k| match v {
		Table(d) => d.get(k).map_err(|_| NotFound)
		_ => Err(NotFound)
	}
}

expect Value.Integer(1) == Value.Integer(1)
expect Value.Table(Dict.from_list([("a", Value.Integer(1)), ("b", Value.Boolean(True))])) == Value.Table(Dict.from_list([("b", Value.Boolean(True)), ("a", Value.Integer(1))]))
expect Value.Table(Dict.from_list([("a", Value.Array([Value.Float(1.5)]))])).get("a") == Ok(Value.Array([Value.Float(1.5)]))
# Fact: derived == on F64 is IEEE: NaN is not equal to NaN
expect F64.nan != F64.nan
expect 0.0.F64 == -0.0.F64
expect F64.to_str(0.1) == "0.1"
expect F64.to_str(1.0) == "1"
expect F64.to_str(1e300) == "1e300"
expect F64.to_str(5e-324) == "5e-324"
expect F64.to_str(-0.0) == "-0"
expect F64.from_str("1e300") == Ok(1e300)
# Fact: F64.from_str accepts "inf", which TOML grammar alone does not decide
expect F64.from_str("inf").is_ok()
