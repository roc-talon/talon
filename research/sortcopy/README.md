# List.sort_with: one copy of the sort per element type

Upstream issue: https://github.com/roc-lang/roc/issues/12905 (text in `upstream-issue.md`).

## Result

| Question | Answer (measured) |
| --- | --- |
| A copy for each call site? | No. N sites with the same element type and the same comparator: +0.3 KB per site. |
| A copy for each comparator? | No full copy. N comparators on `U64`: the text size changes by a few KB, not monotonic. |
| A copy for each element type? | Yes. New tuple size: about +86 KB per site. New record type with the same layout: about +20 KB per site. |

## Steps

```
./measure.sh                                  # nightly-2026-10-31-f7bef6b, --opt=speed
ROC=.work/n1107/roc_nightly-linux_x86_64-2026-11-07-ad3a5d2/roc ./measure.sh
OPT=dev ./measure.sh                          # or OPT=size
```

`gen.sh <kind> <N>` writes the repro (no header, Echo platform). `measure.sh` builds each file, runs it, and prints `.text` bytes (`size`) and the count of text symbols (`nm`).

| kind | Call site i sorts |
| --- | --- |
| named | `List(U64)`, one top-level comparator `cmp` |
| inline | `List(U64)`, the same comparator written inline |
| distinct | `List(U64)`, comparator on `x % (i + 1)` |
| samesize | `List({ a<i> : U64, b<i> : U64 })` |
| types | `List` of tuples of i + 1 `U64` |

The newest nightly is in `.work/` (gitignored): `gh release download nightly-2026-11-07-ad3a5d2 --repo roc-lang/nightlies -p 'roc_nightly-linux_x86_64-*'`.

## Sizes, nightly-2026-10-31-f7bef6b, --opt=speed, x86-64 Linux

`.text` bytes / text symbols. N = 0: 13,632 / 25.

| N | named | inline | distinct | samesize | types |
| --- | --- | --- | --- | --- | --- |
| 1 | 188,736 / 112 | 188,736 / 112 | 138,308 / 112 | 84,592 / 78 | 152,328 / 121 |
| 2 | 189,336 / 112 | 139,196 / 112 | 161,212 / 115 | 105,528 / 109 | 248,032 / 172 |
| 4 | 189,784 / 112 | 147,740 / 113 | 150,036 / 119 | 145,960 / 161 | 418,240 / 269 |
| 8 | 190,712 / 112 | 135,188 / 115 | 176,388 / 123 | 226,856 / 265 | 764,364 / 463 |

The function names are hashes (`roc__p<hash>.fast`), so `nm` does not show which function is the sort. The text symbol count grows by about 26 per site (samesize) and 49 per site (types).

## Sizes, nightly-2026-11-07-ad3a5d2, x86-64 Linux

`.text` bytes. N = 0: speed 10,738, size 9,846, dev 17,054.

| N | `--opt` | named | inline | distinct | samesize | types |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | speed | 189,110 | 189,110 | 161,898 | 81,058 | 149,162 |
| 2 | speed | 189,678 | 139,390 | 147,466 | 101,946 | 246,706 |
| 4 | speed | 190,158 | 142,330 | 160,234 | 142,026 | 415,774 |
| 8 | speed | 191,086 | 143,978 | 185,514 | 222,058 | 758,526 |
| 1 | size | 101,442 | | 101,690 | 60,030 | 113,118 |
| 2 | size | 101,690 | | 104,850 | 73,902 | 169,214 |
| 4 | size | 102,010 | | 112,114 | 101,070 | 273,742 |
| 8 | size | 102,618 | | 124,882 | 155,342 | 494,414 |
| 1 | dev | 279,710 | | 279,918 | 254,830 | 254,942 |
| 2 | dev | 280,350 | | 283,566 | 473,566 | 495,118 |
| 4 | dev | 281,598 | | 290,846 | 910,830 | 987,758 |
| 8 | dev | 284,110 | | 305,422 | 1,785,342 | 1,983,230 |

Per new element type: speed about +86 KB (types) and +20 KB (samesize); size about +54 KB and +14 KB; dev about +247 KB and +219 KB.
