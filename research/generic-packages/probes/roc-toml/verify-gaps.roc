# Verify probe (roc-toml): the behavior that the not-caught mutations M30, M31,
# M33, M61, M82 change. Run with `roc test`. It uses the roc-toml 0.1.0 release.
app [main!] { pkg: "https://github.com/Karakatiza666/roc-toml/releases/download/0.1.0/3icmtKz6XQUyHqu5JftcoJJT6a9YTND1B8z1UAmtqJpN.tar.zst" }

import pkg.Toml

main! = |_args| Ok({})

col : Str -> U64
col = |text|
	match Toml.parse(text) {
		Err(TomlErr(e)) => e.column
		Ok(_) => 0
	}

# M30: the column of an error on line 1 is 1-based (the parse stops at the line start)
expect col("a = ?") == 1

# M31: the column of an error on line 2 is 1-based
expect col("a = 1\nb = ?") == 1

# M33: a BOM at the start counts in the column (bytes)
expect col("\u(FEFF)a = ?") == 4

# M61: the line of a key whose value has more than one line
expect Toml.parse("a = [\n1,\n]\n").map_ok(|d| d.line(["a"])) == Ok(Ok(1))

# M82: remove of the first entry keeps the BOM
expect Toml.parse("\u(FEFF)a = 1\nb = 2\n").map_ok(|d| d.remove(["a"]).map_ok(|e| e.to_str())) == Ok(Ok("\u(FEFF)b = 2\n"))
