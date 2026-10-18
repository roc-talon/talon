# Verify probe (roc-toml slice 6, 0.2.0 not released): the behavior that the
# not-caught mutation M119 changes, and the L0 gap of M87 (only F-DATE
# catches it). Run with `roc test` from this directory. PKG is the local
# roc-toml package; change the path in the header for another checkout.
app [main!] { pkg: "../../../../../../roc-toml/package/main.roc" }

import pkg.Toml
import pkg.Value

main! = |_args| Ok({})

col : Str -> U64
col = |text|
	match Toml.parse(text) {
		Err(TomlErr(e)) => e.column
		Ok(_) => 0
	}

# M119 (C2, syntax): a bad hex digit in a \u escape. The first byte that no
# valid document can have there is `G` (column 10), not the first digit.
expect col("a = \"\\u12G4\"") == 10

# M119: the same in a \U escape, `x` at column 14
expect col("a = \"\\U0001F6x0\"") == 14

# M87 (C1 and the parse): November has 30 days
expect col("d = 2023-11-31") == 5
expect Toml.parse("d = 1\n").map_ok(|d| d.replace(["d"], Value.LocalDate({ year: 2023, month: 11, day: 31 })).is_err()) == Ok(Bool.True)
