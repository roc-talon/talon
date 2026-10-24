# Revert check of the code, slice 025b (48 mutations, see code-mutate.py)

Rule: a mutation is CAUGHT when a listed test fails. Only the tests that should catch it were run (no full sweep). Before each mutation the 6 code files were copied from `code-final/`, and again at the end. The compare at the end: all 6 files are the same as `code-final/` (`cmp`), and `scripts/test.sh` exits 0 after it.
Four mutations did not compile or did not match at the first run (C5, B12: the old text was not unique; P1: a warning for a constant condition). They were written again. The final text is in `code-mutate.py`.

Caught 44 of 48. Not caught: B7 (equivalent), P8, P9, P11 (test gaps).

| Id | Result | Test that failed | Mutation |
| --- | --- | --- | --- |
| T1 | CAUGHT | l0:toolchain | min-release-age does not limit the compiler |
| T2 | CAUGHT | l0:toolchain | the snapshot does not limit the compiler |
| T3 | CAUGHT | l0:toolchain | the switch off still picks a nightly |
| T4 | CAUGHT | l0:toolchain | the range is not checked |
| T5 | CAUGHT | l0:toolchain | the oldest release, not the newest |
| T6 | CAUGHT | l0:toolchain | the order of 2 nightlies of one day ignores published_at |
| T7 | CAUGHT | l0:toolchain | a release with no asset for the host is a candidate |
| T8 | CAUGHT | l0:toolchain | the kind of `range_failed` |
| T9 | CAUGHT | l0:toolchain | `range_failed` does not name the switch |
| C1 | CAUGHT | l0:consent | `--yes` does not answer |
| C2 | CAUGHT | l0:consent | `--allow-downloads` does not answer |
| C3 | CAUGHT | l0:consent | the variable wins over the flags |
| C4 | CAUGHT | l0:consent | a run with no variable is refused |
| C5 | CAUGHT | l0:consent | the refusal does not name the flag |
| C6 | CAUGHT | l0:consent | the kind of the refusal |
| K1 | CAUGHT | l0:compiler | the old text of `Compiler.failure(NoneInRange)` |
| R1 | CAUGHT | l2:consent/dl3 | `--offline` with no cached list |
| R2 | CAUGHT | l2:consent/dl3 proxy/px2 | `range_id!` failure has no range text |
| R3 | CAUGHT | l2:consent/dl3 proxy/px2 | the snapshot is not passed to the pick |
| R4 | CAUGHT | l2:consent/dl3 proxy/px2 | min-release-age is not passed to the pick |
| R5 | CAUGHT | l2:consent/dl3 proxy/px2 | the switch is not passed to the pick |
| R6 | CAUGHT | l2:consent/dl3 | `--offline` is not passed to the list |
| B1 | CAUGHT | l2:consent/dl3 | no refusal for `no` |
| B2 | CAUGHT | l2:consent/dl3 | `--allow-downloads` does not win over the variable |
| B3 | CAUGHT | l2:consent/dl3 | `--yes` does not win over the variable |
| B4 | CAUGHT | l2:consent/dl3 | the snapshot is not passed |
| B5 | CAUGHT | l2:consent/dl3 | min-release-age is not passed |
| B6 | CAUGHT | l2:consent/dl3 | the source of the switch |
| B7 | NOT CAUGHT | none | `from: Range` becomes `from: Path` (equivalent, see below) |
| B8 | CAUGHT | l2:consent/dl3 | the failure has no range text |
| B9 | CAUGHT | l2:consent/dl3 | `--offline` is not passed |
| B10 | CAUGHT | l2:consent/dl3 | the picked compiler is not held |
| B11 | CAUGHT | l2:consent/dl3 | the refusal has no range text |
| B12 | CAUGHT | l2:consent/dl3 | the switch value is not passed |
| N1 | CAUGHT | l2:consent/dl3 | `--no-check` is refused by `TALON_AUTO_INSTALL=no` |
| N2 | CAUGHT | l2:consent/dl3 | `--no-check` keeps exit 13 |
| N3 | CAUGHT | l2:consent/dl3 | `--no-check` holds no compiler (exit 10) |
| P1 | CAUGHT | l2:proxy/px2 proxy/px1 | the proxy downloads with `no` |
| P2 | CAUGHT | l2:proxy/px2 | `TALON_PROXY=0` has no time |
| P3 | CAUGHT | l3:dl3-rank4 | the proxy ignores min-release-age |
| P4 | CAUGHT | l2:proxy/px2 | the proxy ignores the switch |
| P5 | CAUGHT | l2:proxy/px2 | the source text of the prompt and the refusal |
| P6 | CAUGHT | l2:proxy/px2 | the failure has no range text |
| P7 | CAUGHT | l2:proxy/px2 | the proxy does not read min-release-age of `config.toml` |
| P8 | NOT CAUGHT | none | the proxy ignores `[toolchain] nightly` of `talon.toml` (test gap) |
| P9 | NOT CAUGHT | none | the proxy ignores `nightly` of `config.toml` (test gap) |
| P10 | CAUGHT | l2:proxy/px2 | the refusal of the proxy is another failure |
| P11 | NOT CAUGHT | none | the proxy reads the list with `offline: true` (test gap) |

## Mutations that no test caught

| Id | Kind | Reason |
| --- | --- | --- |
| B7 | Equivalent | The held compiler is `Range` or `Path`. `Pin.gate` for `Range` is `Ok`, and for `Path` it checks the range and the switch, which `Toolchain.range_pick` already holds for the id. `Pin.decide` gives `held_from` to `check_pin` only. No output differs. (Same finding as the test agent, `mutate.py` B7.) |
| P8, P9 | Test gap | `px2-install` run 16 turns the switch off with `TALON_NIGHTLY=0` (the env source) only. No proxy run with a range sets `nightly = false` in `talon.toml` or `config.toml`, so the 2 other sources of `Pin.switch` in `Proxy.ranged!` are not shown. Proposal: one run of `px2-install` with `[toolchain] nightly = false` and one with `config.toml` `nightly = false`, range `*`, exit 10 naming the source. |
| P11 | Test gap | In every `px2-install` run and in L3 part 6 the list is cached before the proxy reads it (the state of runs 12 to 18), so `offline: true` in place of `false` shows nothing. Proposal: one proxy run with a range and no cached list (a fresh cache dir), which must read the list (one `http_get`). |
