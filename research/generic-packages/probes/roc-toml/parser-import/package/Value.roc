## A TOML 1.0.0 value.
##
## A table is a `Dict(Str, Value)`. Two tables are equal when they have the
## same keys with equal values, in any order.
##
## A date is `{ year, month, day }`. A time is `{ hour, minute, second,
## nanosecond }`: a fraction of a second with more than 9 digits is truncated,
## not rounded (TOML 1.0.0, "Offset Date-Time"). An offset is in minutes east
## of UTC: `Z` is 0, `-07:00` is -420.
Value := [
	String(Str),
	Integer(I64),
	Float(F64),
	Boolean(Bool),
	OffsetDateTime(
		{
			date : { year : U16, month : U8, day : U8 },
			time : { hour : U8, minute : U8, second : U8, nanosecond : U32 },
			offset_minutes : I16,
		},
	),
	LocalDateTime(
		{
			date : { year : U16, month : U8, day : U8 },
			time : { hour : U8, minute : U8, second : U8, nanosecond : U32 },
		},
	),
	LocalDate({ year : U16, month : U8, day : U8 }),
	LocalTime({ hour : U8, minute : U8, second : U8, nanosecond : U32 }),
	Array(List(Value)),
	Table(Dict(Str, Value)),
].{

	## Structural equality, with one change: two `Float` NaN values are equal.
	## TOML has one value `nan` (TOML 1.0.0, "Float"), so a round trip of
	## `nan` gives an equal value.
	is_eq : Value, Value -> Bool
	is_eq = |_a, _b| crash "todo"

	## The value as TOML text on one line, as it is after `key = `.
	##
	## | Value | Text |
	## | --- | --- |
	## | String | A basic string. `"` and `\` get a backslash. U+0008, U+0009, U+000A, U+000C, U+000D are `\b \t \n \f \r`. Each other control character (U+0000 to U+001F, U+007F) is `\uXXXX`, uppercase hex. Other characters stay as they are. |
	## | Integer | Decimal |
	## | Float | `inf`, `-inf`, `nan`. Else `F64.to_str`, with `.0` added when that text has no `.` and no `e`: `1.0`, `-0.0`, `1e300` |
	## | Boolean | `true`, `false` |
	## | Dates and times | `1979-05-27T07:32:00.5-07:00`: `T`, the fraction only when it is not 0 and with no trailing zeros, `Z` for offset 0 |
	## | Array | `[1, "a"]`, `[]` |
	## | Table | An inline table: `{ a = 1, b = 2 }`, `{}`, keys in the order of the `Dict` |
	##
	## A key is bare when it is not empty and has only `A-Z a-z 0-9 _ -`. Else
	## it is a basic string, as a String value.
	print : Value -> Str
	print = |_value| crash "todo"
}
