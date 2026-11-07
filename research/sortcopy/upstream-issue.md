Filed as https://github.com/roc-lang/roc/issues/12905 on 2026-11-07.

Title: List.sort_with: each element type adds a full copy of the sort (20 to 90 KB of code each)

## Summary

Each element type that `List.sort_with` is called with gets its own full copy of the sort code. In the repro, each new tuple type adds about 86 KB of x86-64 code, and each new record type with the same layout (`{ a1 : U64, b1 : U64 }`, `{ a2 : U64, b2 : U64 }`, ...) adds about 20 KB. More call sites with the same element type and the same comparator do not add a copy. In a wasm32 app (`--opt=speed`) with 12 sort call sites on different record types, the sorts are about 1.9 MB of a 5.2 MB code section, and each copy is 140 to 250 KB.

## Compiler

`nightly-2026-10-31-f7bef6b` and `nightly-2026-11-07-ad3a5d2`, Linux x86-64:

```
roc build --opt=speed main.roc
```

## Repro

`main.roc` (no header). Call site i sorts tuples of i + 1 `U64`. This is N = 4; for other N, add or remove lines of the same form.

```roc
main! = |args| {
	rows : List(U64)
	rows = args.map(|s| s.count_utf8_bytes())
	var $total = rows.len()
	$total = $total + (rows.map(|x| (x, x + 1)).sort_with(|x, y| x.0.order_relative_to(y.0)).first().map_ok(|r| r.1) ?? 0)
	$total = $total + (rows.map(|x| (x, x + 1, x + 2)).sort_with(|x, y| x.0.order_relative_to(y.0)).first().map_ok(|r| r.1) ?? 0)
	$total = $total + (rows.map(|x| (x, x + 1, x + 2, x + 3)).sort_with(|x, y| x.0.order_relative_to(y.0)).first().map_ok(|r| r.1) ?? 0)
	$total = $total + (rows.map(|x| (x, x + 1, x + 2, x + 3, x + 4)).sort_with(|x, y| x.0.order_relative_to(y.0)).first().map_ok(|r| r.1) ?? 0)
	echo!(Str.inspect($total))
	Ok({})
}
```

For the same-layout records, line i is:

```roc
	$total = $total + (rows.map(|x| { ai: x, bi: i }).sort_with(|x, y| x.ai.order_relative_to(y.ai)).first().map_ok(|r| r.bi) ?? 0)
```

For one element type, every line is `$total = $total + (rows.append(i).sort_with(cmp).first() ?? 0)` with `cmp = |x, y| x.order_relative_to(y)` at the top level.

## Sizes

`.text` bytes (`size`), N call sites. With N = 0 (no sort) the text is 13,632 bytes.

| N | tuples of N different sizes | records, same layout, N types | `U64`, one comparator |
| --- | --- | --- | --- |
| 1 | 152,328 | 84,592 | 188,736 |
| 2 | 248,032 | 105,528 | 189,336 |
| 4 | 418,240 | 145,960 | 189,784 |
| 8 | 764,364 | 226,856 | 190,712 |

`nightly-2026-11-07-ad3a5d2` gives sizes within 6 KB of these with `--opt=speed`. Other `--opt` values (`nightly-2026-11-07-ad3a5d2`):

| N | `--opt` | tuples | records, same layout | `U64`, one comparator |
| --- | --- | --- | --- | --- |
| 1 | dev | 254,942 | 254,830 | 279,710 |
| 8 | dev | 1,983,230 | 1,785,342 | 284,110 |
| 1 | size | 113,118 | 60,030 | 101,442 |
| 8 | size | 494,414 | 155,342 | 102,618 |

## Expected

The sort code is shared, or each copy is small. The size added by one more element type is a few KB, not 20 to 90 KB.
