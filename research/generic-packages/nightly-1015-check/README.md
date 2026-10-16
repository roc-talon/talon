# nightly-1015-check: roc-fuzz on the latest nightly

Question: do roc-fuzz 0.4.3 targets work on `nightly-2026-10-15-38e6c42` (the latest on 2026-10-16)?

Run: `./run.sh <nightly-tag>...`, `TARGETS="selfeq rt"` selects the targets. The nightlies are in `cloudflare-workers/.cache/nightlies/`.

| Target | Property | 10-09 | 10-12 | 10-14 | 10-15 |
| --- | --- | --- | --- | --- | --- |
| `selfeq` | `bytes == bytes` | pass | pass | pass | exit 77 |
| `lenok` | `bytes.len() == bytes.len()` | | | | exit 77: "fuzz target overwrites its const input" |
| `copyeq` | `bytes.append(1) == bytes.append(1)` | | | | exit 77: "1 allocation(s) ... never freed" |
| `strself` | `Str.inspect(bytes) == Str.inspect(bytes)` | | | | exit 77: "deadly signal" |
| `rt` | `Hex.decode(Hex.encode(bytes)) == Ok(bytes)` | pass | pass | pass | exit 77 |

`roc test` of the same `Hex` expects (`t.roc`) passes on 10-09 and 10-15.

Conclusion: on 10-15 a compiled target that reads the host input list corrupts memory. The regression is between roc `38a3029` and `38e6c42`. The range has ownership changes (for example `416f40e` "Demand owned field reads for calls whose owned variant takes a field"). Not bisected. L1 cannot run on 10-15.
