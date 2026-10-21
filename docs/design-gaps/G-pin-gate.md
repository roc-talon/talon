# G-pin-gate: the `roc:` pin, the `[toolchain]` intent, the switch and the selection ranks

Source: slice 012 (`docs/slices/012-p0-rule-gaps.md`, Code row "PATH roc, no pin", Verify row G5, review "open for a follow-up": G5, F1, I1). Code: `cli/lib/Pin.roc` (`decide`, `gate`, `outside_failure`), `cli/lib/ResolveBase.roc:204-215` (`check_pin`), `cli/lib/Compiler.roc:56-82` (`select`, `require`), `cli/lib/Install.roc:137-142` (`compiler!`), `cli/lib/Ladder.roc:181,208` (`require` before a probe).

## 1. The gap

Resolution 13 is one list for two different questions. The design does not separate them:

| Question | Who asks | What the answer is |
| --- | --- | --- |
| Q-run: which binary runs this `roc` call? | the proxy, `tln verify`, `tln probe` | a compiler, also a local build |
| Q-lock: which nightly does the command hold, check, and write as the pin? | `install`, `add`, `update`, `remove`, `upgrade` (held nightly), `roc use` | a nightly or a release that the header can carry (R-H6) |

| Rule | Says | Conflict or silence |
| --- | --- | --- |
| Resolution 13 R-SO2, R-SO3 | `ROC_TOOLCHAIN` (rank 2) wins over the pin (rank 3) | For Q-run that is correct. For Q-lock it moves the probe compiler away from the pin, but R-RP1 does not let the pin move. Then R-H6 ("the pin records the nightly that the last probe passed with") is false |
| Resolution 9 R-SP1, R-RP2, R-BL1, R-BL3 | The writing commands hold the nightly at the pin. The baseline runs on the pin | Silent on ranks 1 and 2. Code (`Compiler.select`) stops with exit 13 when `ROC_TOOLCHAIN` is not the `roc` on `PATH`, also when the pin is that `roc` |
| Resolution 1 R-NS4 | The switch does not apply to `ROC_TOOLCHAIN` | With no pin, R-RP3 writes the selected compiler as the pin. A nightly written with the switch off is at once outside (R-NS5). R-U5 already gates `roc use`, a named compiler, so R-NS4 is for Q-run only |
| R-RP2 last sentence | A pin outside the range: exit 10 "in `install`" | Code and tests stop in `add`, `update`, `remove` and `verify` too (`g1-slice009` run 2). R-NS5 and R-SO17 say "`install` reports it" |
| R-SO13, R-NS2, R-NS3 | No pin: rank 4 picks in range, the switch limits rank 4 | Silent when `[toolchain] roc` is not set and rank 6 or 7 gives a nightly with the switch off. Q34 answered exit 10 (R-NS2) |
| R-PH7, R-DL2 | A compiler that is not installed is a required download | Silent on when. `Ladder` checks the pin lazily (at the first probe, `ld-no-check-refuse` run 2 passes with `--no-check`). `Compiler.select` checks `ROC_TOOLCHAIN` eagerly (before the index) |
| `Pin.gate` | Checks the `roc` on `PATH` only when there is no pin | Correct, but no rule says that a pin makes the `roc` on `PATH` irrelevant for the intent check. The revert row G5 (gate also with a pin) is not caught |
| R-LF1, R-SO14 | `--frozen` needs no compiler | Silent on `ROC_TOOLCHAIN` in `--frozen` (F1). Code accepts each id |

## 2. Options

| # | Option | P0 cost | P1 and later | Users |
| --- | --- | --- | --- | --- |
| A | Gate the `roc` on `PATH` (or the run compiler) also when there is a pin (G5 as a rule) | Small | Wrong in P1: the run compiler is downloaded to match the pin, so a `PATH` check is noise | `tln update --no-check` stops for a compiler that it does not use |
| B | Ranks rule all commands: `ROC_TOOLCHAIN` is the probe compiler of writing commands too. The pin stays (R-RP1) | Medium | The header carries a pin that no probe used. R-H6 becomes false in normal use | A shell-wide `ROC_TOOLCHAIN` makes `tln add` write unverified headers with no warning |
| C | Two roles. Q-lock: the held nightly is the pin, else the ranks without rank 3. The intent (range, switch) gates each held nightly. Ranks 1 and 2 never change a held pin (note only). Q-run (`verify`, proxy): the ranks as written. A compiler is needed only when a probe runs | Medium: `Pin.decide` gets rank 2, `Compiler.select` loses its eager check, `verify` probes on the override, 1 note | No change in P1: the same rule chooses what to download. `roc use`, `upgrade roc` stay the only pin moves | The header is always verified on its pin. CI can test a header on another nightly with `ROC_TOOLCHAIN=<id> tln verify` |
| D | As C, but rank 1 or 2 that differs from the pin is an error (exit 2) in writing commands | As C | As C | Strict. A shell-wide `ROC_TOOLCHAIN` (R-SO2 "set for a shell") blocks each `tln add` |

Other package managers:

| Tool | Lock or pin | Intent | Override | Override in a lock-writing command |
| --- | --- | --- | --- | --- |
| Go | `toolchain` line in `go.mod` | `go` line (minimum) | `GOTOOLCHAIN` | Runs the override. The `go` minimum is hard: a toolchain below it switches or stops |
| uv | `.python-version` | `requires-python` | `--python`, `UV_PYTHON` | The override must satisfy `requires-python`, else error |
| cargo, rustup | `rust-toolchain.toml` | `rust-version` | `+toolchain`, `RUSTUP_TOOLCHAIN` | Runs the override. `rust-version` is checked against it (`--ignore-rust-version` skips) |

All three make the intent a hard limit for project commands. None writes the override into the pin. Option C has both properties.

## 3. Decision: option C

| Case (header, environment) | `install`, `add`, `update`, `remove`, `upgrade X` | `install --frozen` | `verify` | proxy (P1) |
| --- | --- | --- | --- | --- |
| Pin, intent admits it | hold the pin, probe on it | ok | probe on the pin | run the pin |
| Pin outside the range, or a nightly pin with the switch off | exit 10 before the index (R-RP2) | exit 14 | exit 10 | run the pin (R-NS5) |
| Pin not installed (P0: not the `roc` on `PATH`) | required download at the first probe: P0 exit 13. `--no-check`: no probe, ok | ok | as the left column | required download (R-DL3) |
| Pin, `ROC_TOOLCHAIN` names another id | hold the pin, print a note (R-SO20) | ok, no note | probe on the `ROC_TOOLCHAIN` compiler (R-SO21) | run `ROC_TOOLCHAIN` |
| No pin, `[toolchain] roc` set, no installed compiler in it | required download (R-SO13): P0 exit 13 before the index (`Pin.gate`, as built) | ok | as the left column | as the left column |
| No pin, switch off, a rank selects a nightly | exit 10 (R-NS2), names the switch, its source and the rank | ok | as the left column, except rank 2 (R-NS4) | run it (R-NS4) |
| No pin, `ROC_TOOLCHAIN` names an id outside the range | exit 10, names `ROC_TOOLCHAIN` and the range | ok | run it (R-NS4) | run it |
| No pin, a local build selected (R-SO11) | no intent check, never written (R-H6) | ok | run it | run it |

Why C is the cleanest in the long term:

| Property | How C keeps it |
| --- | --- |
| G1, R-H6: the pin is a true claim | The probes of a writing command always run on the nightly that it writes or keeps |
| R-RP1: one command moves the pin | Ranks 1 and 2 never move the pin and never change its proof. `roc use` and `upgrade roc` stay the only moves |
| One gate | The intent (range and switch) gates each nightly that Talon holds or writes. R-U5 (`roc use`) and R-UP1 (`upgrade`) already do it, so the rule only becomes general |
| R-NS4 keeps its use | A named compiler still runs (proxy, `verify`). It is only not written |
| P0 equals P1 | P0 has only the `roc` on `PATH`. The same rule decides, and R-PH7 refuses what P1 would download |
| R-DL2 is literal | "Required" means a probe needs it. `--no-check` and `--frozen` need no compiler, for the pin and for rank 2 alike |

The answer to G5: `Pin.gate` must not run when there is a pin. The pin check is R-RP2 (`outside_pin`), and the pin compiler is checked by `Compiler.require` at the first probe. With a pin, the `roc` on `PATH` has no role in the intent check.

## 4. Design edits

| # | File | Rule | Old text | New text |
| --- | --- | --- | --- | --- |
| E1 | DESIGN-RESOLUTION.md section 9 | R-SP1 | "The nightly is held at the `roc:` pin, or at the selected compiler (section 13) if there is no pin." | "The nightly is held at the `roc:` pin, or at the selected compiler (section 13) if there is no pin. Section 13, R-SO19 to R-SO22, tells how ranks 1 and 2 and the intent apply to the held nightly." |
| E2 | DESIGN-RESOLUTION.md section 9 | R-RP2 | "A `roc:` pin outside the `[toolchain] roc` range gives the same error in `install`." | "A `roc:` pin that the `[toolchain] roc` range or the `nightly` switch does not admit (R-NS5) gives the same error, before the index and before any write, in each command that holds the nightly: `install`, `add`, `update`, `remove`, `verify`, and `upgrade` when the nightly is not free. The error names the range, or the switch and its source. `tln roc use` and `tln upgrade roc` do not stop for it: they are the fix." |
| E3 | DESIGN-RESOLUTION.md section 1 | R-NS4 | "A global default that is a nightly (rank 6) stays in use." | "A global default that is a nightly (rank 6) stays in use. This is for runs only: a compiler that Talon holds as the nightly or writes as the `roc:` pin is checked against the switch and the range (R-SO19, R-U5)." |
| E4 | DESIGN-RESOLUTION.md section 1 | R-NS5 | "`tln install` reports it, and `--frozen` fails with exit code 14." | "The commands of R-RP2 stop with exit code 10, and `--frozen` fails with exit code 14." |
| E5 | DESIGN-RESOLUTION.md section 13 | R-SO17 | "`tln install` and `tln install --frozen` report that the header does not satisfy `talon.toml`. `--frozen` fails (section 12)." | "The commands of R-RP2 stop with exit code 10. `tln install --frozen` fails with exit code 14 (section 12)." |
| E6 | DESIGN.md section 7 | R-PH7 | "None. A rank that selects another compiler is a required download (R-DL2)." | "None. A held `roc:` pin, or a rank that selects another compiler, is a required download (R-DL2) when a probe needs it (Resolution 13, R-SO22)." |
| E7 | DESIGN-RESOLUTION.md section 13, after the R-SO17 table | R-SO19 to R-SO22 (new, ids checked free with `grep`) | "none" | "the text below" |

E7, new text:

```text
Sections 9 and 13 answer two questions. The held nightly (R-SP1) is what a command checks, probes and writes as the
`roc:` pin. The run compiler is what runs a `roc` call. The ranks above give the run compiler. These rules give the held nightly.

| # | Case | Talon does |
| --- | --- | --- |
| R-SO19 | A command holds the nightly (R-RP2) | The held nightly is the `roc:` pin (rank 3). With no pin, it is the compiler that ranks 2, 4, 5, 6 and 7 select (a `tln` command has no rank 1). Before the index and before any write, Talon checks it against the `[toolchain] roc` range and the `nightly` switch (R-NS7). A pin that fails: R-RP2. No pin, and rank 4 finds no installed compiler in the range: R-SO13. No pin, and another rank selects a compiler that the switch or the range does not admit: exit code 10 (`no_tuple`, R-NS2). The error names the compiler, the rank that selected it (`ROC_TOOLCHAIN`, `.roc-version`, the global default or the `roc` on `PATH`), and the range or the switch and its source. A local build (R-SO11, R-NS6) is not checked: Talon never writes it. |
| R-SO20 | A command holds the nightly, the header has a pin, and `ROC_TOOLCHAIN` names another compiler | The held nightly stays the pin, and the probes run on it (R-BL1). Talon prints one note that names both ids and `tln roc use <id>`. `ROC_TOOLCHAIN` still selects the compiler of the proxy (R-U6). |
| R-SO21 | `tln verify` | It writes nothing, so its probes run on the run compiler: rank 2, then the held nightly of R-SO19. R-RP2 still checks the pin, because the pin is part of the header. Use: `ROC_TOOLCHAIN=<id> tln verify` tests the header on another compiler. |
| R-SO22 | The held nightly or the run compiler is not installed | It is a required download (R-DL2) at the first probe, not before. `--no-check` and `--frozen` run no probe, so they need no compiler, and `ROC_TOOLCHAIN` does not stop them. |
```

## 5. Work that follows (new slice, 013)

| # | Code | Change | Rules |
| --- | --- | --- | --- |
| W1 | `cli/lib/Compiler.roc` `select` | No `require` for `ROC_TOOLCHAIN`. Return the rank-2 id and the `roc` on `PATH` apart | R-SO22 |
| W2 | `cli/lib/Install.roc` `compiler!`, the request of `Resolve` | Pass `toolchain` to `Pin.decide` | R-SO19, R-SO20 |
| W3 | `cli/lib/Pin.roc` `decide` | New inputs `toolchain` and `role : [Lock, Verify]`. New output `held_from : [Pin, Env, Path]` and `note`. With a pin and `Lock`: `held` is the pin, `note` names the other id. With `Verify`: `held` is `toolchain` when set | R-SO19 to R-SO21 |
| W4 | `cli/lib/Pin.roc` `gate` | Takes `held_from`. A range fail from `Env` is exit 10, from `Path` stays exit 13 (R-SO13). The texts name the rank. `gate` stays only for `pinned` false (G5) | R-SO19 |
| W5 | `cli/lib/VerifyFlow.roc`, `cli/lib/Verify.roc` | Probe on `held` of W3 (role `Verify`) | R-SO21 |
| W6 | `Ladder` | No change: `Compiler.require` at the first probe is already R-SO22 | R-SO22 |

Tests (test agent first, TW18):

| Level | Test | Expect | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/pin.roc`, `decide` | pin + other `toolchain`, `Lock`: `held` is the pin, a note. Same, `Verify`: `held` is `toolchain`. No pin + `toolchain`: `held_from` is `Env` | R-SO19 to R-SO21 |
| L0 | `tests/unit/pin.roc`, `gate` | `Env` out of range: exit 10, text names `ROC_TOOLCHAIN`. `Path` out of range: exit 13 (as now) | R-SO19 R-SO13 |
| L2 | `resolve/rs-no-compiler`, new run (G5) | pin inside the range, the `roc` on `PATH` below it, `update --no-check`: exit 0, pin kept. Without `--no-check`: exit 13 with the `Compiler.require` text, not the `gate` text | R-SO19 R-SO22 R-PH7 |
| L2 | new run (I1) | `install` with a pin and `ROC_TOOLCHAIN=<other id>`: exit 0, the note, probes on the pin | R-SO20 |
| L2 | `rs-frozen`, new run (F1) | `--frozen` with `ROC_TOOLCHAIN=<other id>`: exit 0, no note, no compiler call | R-SO22 R-LF1 |
| L3 | `vf1-verify` line 32 | Today `ROC_TOOLCHAIN=<other id> tln verify --no-check` expects exit 13. R-SO22 makes it exit 0. Change the run to no `--no-check` (exit 13 at the first probe), and add the `--no-check` run (exit 0) | R-SO21 R-SO22 R-PH7 |
| L0 or L2 | rule names | Add R-RP2 for `add`, `update`, `remove` where the outside-pin rows run (code already stops) | R-RP2 R-NS5 R-SO17 |

No code change for the outside pin in `add`, `update`, `remove`, `verify`: it is built and tested (`g1-slice009` run 2). E2, E4 and E5 make the design match it.

## 6. Questions for the human (TW17)

| # | Question | Default if no answer |
| --- | --- | --- |
| H1 | R-SO20: with a pin, `ROC_TOOLCHAIN` set to another id gives a note and the pin is held (option C). Option D makes it exit 2. Is a shell-wide `ROC_TOOLCHAIN` (R-SO2 "set for a shell") a workflow to keep smooth, or is a hard stop better? | C (note) |
