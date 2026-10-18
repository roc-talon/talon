# What Value.print and Toml.print give for values that TOML cannot write
# (roc-toml 0.1.0, slice 6 question). Run: roc test p.roc (prints with dbg).
app [main!] { pkg: "https://github.com/Karakatiza666/roc-toml/releases/download/0.1.0/3icmtKz6XQUyHqu5JftcoJJT6a9YTND1B8z1UAmtqJpN.tar.zst" }

import pkg.Toml
import pkg.Value

main! = |_args| Ok({})

show : Value -> Bool
show = |v| {
	text = Value.print(v)
	doc = Toml.print(Dict.from_list([("k", v)]))
	back = Toml.parse(doc).map_ok(|d| d.table() == Dict.from_list([("k", v)]))
	dbg (text, back)
	Bool.False
}

d : U16, U8, U8 -> { year : U16, month : U8, day : U8 }
d = |year, month, day| { year, month, day }

t : U8, U8, U8, U32 -> { hour : U8, minute : U8, second : U8, nanosecond : U32 }
t = |hour, minute, second, nanosecond| { hour, minute, second, nanosecond }

expect show(Value.LocalDate(d(10000, 1, 1)))
expect show(Value.LocalDate(d(2023, 2, 30)))
expect show(Value.LocalDate(d(2023, 0, 0)))
expect show(Value.LocalTime(t(99, 0, 0, 0)))
expect show(Value.LocalTime(t(100, 0, 0, 0)))
expect show(Value.LocalTime(t(1, 2, 3, 1000000000)))
expect show(Value.LocalTime(t(1, 2, 3, 4000000000)))
expect show(Value.OffsetDateTime({ date: d(2023, 1, 1), time: t(0, 0, 0, 0), offset_minutes: 1440 }))
expect show(Value.OffsetDateTime({ date: d(2023, 1, 1), time: t(0, 0, 0, 0), offset_minutes: 6000 }))
expect show(Value.OffsetDateTime({ date: d(2023, 1, 1), time: t(0, 0, 0, 0), offset_minutes: -32768 }))
