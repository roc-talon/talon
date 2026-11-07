Filed as https://github.com/roc-lang/roc/issues/12903 on 2026-11-07. The text below is the current body.

## Summary

A `match` arm with an or-pattern of N tags is compiled as N copies of the arm body. The size of the function that has the match grows with N (see the table). The output is the same as when each tag has its own arm with the same body. In a Cloudflare Worker app (wasm32, `--opt=speed`) this made one function 1,246,912 bytes.

## Compiler

`nightly-2026-10-31-f7bef6b` and `nightly-2026-11-06-34f137a`, Linux x86-64:

```
roc build --opt=dev main.roc
roc build --opt=speed main.roc
```

## Repro

`main.roc` (no header):

```roc
main! = |args| {
	s = args.first().map_ok(|a| a.to_str()) ?? ""
	e = match args.len() {
		0 => A
		1 => B
		2 => C
		3 => D
		4 => E
		5 => F
		_ => Z
	}
	match e {
		A | B | C | D | E | F => match s {
			"k0" => echo!("line 00 of the arm body")
			"k1" => echo!("line 01 of the arm body")
			"k2" => echo!("line 02 of the arm body")
			"k3" => echo!("line 03 of the arm body")
			"k4" => echo!("line 04 of the arm body")
			"k5" => echo!("line 05 of the arm body")
			"k6" => echo!("line 06 of the arm body")
			"k7" => echo!("line 07 of the arm body")
			"k8" => echo!("line 08 of the arm body")
			"k9" => echo!("line 09 of the arm body")
			"k10" => echo!("line 10 of the arm body")
			"k11" => echo!("line 11 of the arm body")
			"k12" => echo!("line 12 of the arm body")
			"k13" => echo!("line 13 of the arm body")
			"k14" => echo!("line 14 of the arm body")
			"k15" => echo!("line 15 of the arm body")
			"k16" => echo!("line 16 of the arm body")
			"k17" => echo!("line 17 of the arm body")
			"k18" => echo!("line 18 of the arm body")
			"k19" => echo!("line 19 of the arm body")
			_ => {}
		}
		Z => {}
	}
	Ok({})
}
```

The `_` form for the comparison has the same body; only the arms of `match e` change:

```roc
	match e {
		Z => {}
		_ => match s {
			# the same 21 arms
		}
	}
```

## Sizes

Size of the function of `main!` (`nm -S`). "Copies" is the number of times the 8 bytes `line 07 ` occur in it (the string is built from immediates). N is the number of tags in the or-pattern (`A | B` for N = 2, ...).

| N | `--opt` | or-pattern: bytes | copies | `_` arm: bytes | copies |
| --- | --- | --- | --- | --- | --- |
| 2 | dev | 16,447 | 2 | 8,587 | 1 |
| 4 | dev | 32,245 | 4 | 8,665 | 1 |
| 6 | dev | 48,043 | 6 | 8,743 | 1 |
| 8 | dev | 63,841 | 8 | 8,821 | 1 |
| 2 | speed | 2,488 | 1 | 2,496 | 1 |
| 4 | speed | 7,560 | 3 | 2,496 | 1 |
| 6 | speed | 12,471 | 5 | 2,496 | 1 |
| 8 | speed | 21,649 | 8 | 2,496 | 1 |

`--opt=size` gives the same sizes as `--opt=speed`.

## Expected

The arm body is emitted once, and each tag of the or-pattern jumps to it. The size of the function does not change with N.
