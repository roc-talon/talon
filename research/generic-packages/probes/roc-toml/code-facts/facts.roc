# Builtin facts for the roc-toml code agent on nightly-2026-10-14-38a3029.
expect I64.from_str("+99") == Ok(99)
expect I64.from_str("-9223372036854775808") == Ok(I64.lowest)
expect I64.from_str("9223372036854775808").is_err()
expect F64.from_str("5e+22") == Ok(5e22)
expect F64.from_str("1e06") == Ok(1e6)
expect F64.from_str("-2E-2") == Ok(-0.02)
expect F64.from_str("+1.0") == Ok(1.0)
expect F64.from_str("6.626e-34") == Ok(6.626e-34)
expect F64.to_str(5e22) == "5e22"
expect F64.to_str(1e-7) == "1e-7"
expect F64.to_str(123456789012345680000.0) == "123456789012345680000"
expect Dict.from_list([("b", 1), ("a", 2)]).keys() == ["b", "a"]
