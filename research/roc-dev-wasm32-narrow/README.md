# roc: wrong I128 narrowing with wasm32 `--opt=dev` (TW25, to report upstream)

| Item | Value |
| --- | --- |
| Compiler | roc `nightly-2026-10-31-f7bef6b` (`cloudflare-workers/compat/last-stack-first-nightly`). Other nightlies are not tested. |
| Target and mode | `--target=wasm32` with `--opt=dev`. `--opt=speed` is correct. Native x64 `dev`, `speed` and `interpreter` are correct. |
| Repro | `cloudflare-workers/research/blob-002/narrow2.roc` (the platform is `cloudflare-workers`, run in Miniflare with `run.mjs`). `cloudflare-workers/research/blob-002/i128_try.roc` is the same code with no platform, for the native targets. |
| Build | `roc build --target=wasm32 --no-cache --opt=dev --output=narrow2.wasm narrow2.roc`, from that directory. |
| Fault | For an `I128` with the value 3, `to_u8_try`, `to_u16_try`, `to_i8_try` and `to_i16_try` give `Err(OutOfRange)`. `to_u32_try`, `to_u64_try`, `to_i32_try`, `to_i64_try` give `Ok(3)`. `I64.to_u8_try` is correct. |
| Effect | roc-cbor 0.2.2 reads each integer as an `I128` and narrows it, so a D1 BLOB (`List(U8)`) and a small integer field (`U8`, `U16`, `I8`, `I16`) fail to read: `BadData("column bl: the value does not fit the type")`. |
| Rule in Talon | The Worker is built with `--opt=speed`, never dev: `WORKER_OPT=speed` in `scripts/test.sh`, `--opt=speed` in `worker/talon.toml`, checked by `worker/tests/frame.sh`. |
| Full report | `cloudflare-workers/research/blob-002/README.md` |

To report: the repro needs no Worker code. A minimal Roc app for the wasm32 target, with `n : I128` taken from a value that the compiler cannot fold, shows the fault with `Str.inspect(n.to_u8_try())`.
