# Slice 243 mutation check (TW12)

Script: `research/slice-243-revert/mutate.sh [mutant names]`. Log: `run.log`. Each mutant is a `sed` edit of a mirror of `cli/lib` under `.tmp/slice-243-mut/` (the working tree is not changed; the mirror is deleted at the end). Each run is capped (`MemoryMax=16G`, no swap, `timeout 600`), `TMPDIR` in `.tmp/tmp`, one mutant at a time. The L2 binary is built with `--opt=dev`. Tests run for each mutant: the l0-9 driver and `tests/commands/run.sh channels/ gc/ upgrade/ roc/`. Baseline: l0-9 151 passed, L2 121 passed (124 after the 3 cases added below).

Result: 21 of 21 non-equivalent mutants caught (18 at the first run, 3 after a new test); 1 equivalent mutant (up4b). 22 mutants in all.

`norm.sh` (in this directory) turns a `calls.log` baked with `UPDATE=1` outside `/tmp/talon-l2` into the committed `/tmp/talon-l2` form (it takes out the ancestor `list_dirs` lines and the ancestor words of the `read_files` talon.toml lines). Use it after each re-bake of a case: `research/slice-243-revert/norm.sh tests/commands/cases/<group>/<case>/expect/calls.log`. The runner compares both files through `anc_filter`, so a baked but not normalized file also passes here, but it would have machine paths.

| # | Mutant (place) | Rule | Caught by |
| --- | --- | --- | --- |
| c1a | `Pin.use_gate`: an existing `=`/`>=` user pin stops | C1 | L0 ChannelusepinTest (use_gate), L2 ch14-use |
| c1b | `Pin.use_gate`: another range does not stop | C1 | L0 use_gate, L2 ch14-use-stop, roc/us1-use |
| c2 | `Channel.unuse_edit`: an empty `[toolchain]` stays | C2 | L0 unuse_edit rows. L2 does not see it (ch14-use run 4 keeps `nightly = true`, so the table is not empty) |
| c3a | `Channel.use_edit`: `[channels.<old>]` stays | C3 | L0 use_edit rows. L2 needs a second installed channel (not made) |
| c3b | `Channel.unuse_edit`: `[channels.<name>]` stays | C3 | L0 unuse_edit, L2 ch14-use run 4 |
| c5 | `RocUse.write!`: a missing talon.toml is an error | C5 | L2 ch14-use run 6 (L0 does not see it: it is the command) |
| u1a | `Manage.update_move_to`: an unset default moves | U1 | L0 update_move_to, L2 ch15-update run 6 |
| u1b | same: a nightly or release default moves | U1 | L0, L2 ch15-update run 5 |
| ru2 | same: the default moves to a build of another channel | R-RU2 | L0 update_move_to. L2 not (needs a second installed channel) |
| ru2b | same: a user default moves to a nightly | R-RU2 | L0, L2 ch15-update run 4, roc/up1-update, roc/up2-exclude |
| r1a | `Manage.next_default`: any other build takes the default of a removed user default | R1 | L0 next_default, L2 ch15-remove |
| r1b | `RocManage.remove_flow!`: no note for the unset default | R1 | L2 ch15-remove run 4 (L0 tests the text only) |
| u4 | `RocInstall.install_ref`: the project tables are not read for a named channel | U4 | L2 ch15-update-errors, ch08-named-latest |
| g1a | `Gc.verdict_of`: the `pinned` ids do not keep | G1 | L0 Gc.toolchains, L2 ch17-gc-pin |
| g1b | `CacheGc.toml_pins!`: no pin is read | G1 | L2 ch17-gc-pin |
| g1c | `RocInstall.root_toml!`: the nearest talon.toml, not the workspace root | G1 | NOT caught at first (no test had a member with its own talon.toml). New case L2 ch17-gc-ws; caught |
| up1 | `RocUse.upgrade_user!`: a candidate with a new error stops the command | upgrade fallback | L2 ch15-upgrade-fallback |
| up2 | same: with no passing candidate the output is "is the newest" | upgrade fallback | L2 ch15-upgrade-fallback run 2 |
| up3 | same: min-release-age does not hide a young build | R-C7 | NOT caught at first. New case L2 ch15-upgrade-young; caught |
| up4 | same: the nightly switch is ignored for the user builds (`picked`) | R-CH9 | NOT caught at first. New case L2 ch15-upgrade-switch; caught |
| up4b | same, in the `allowed` list only | R-CH9 | EQUIVALENT: `picked` runs first and stops with exit 10 when the switch is off, so the `allowed` list never sees a false switch |
| up5 | `RocUse.user_table`: a project-only table is accepted | trust stop before any request | L2 ch15-upgrade-errors |

Tests added by this check (red on the mutant, green on the real code, baked from the real run): `channels/ch17-gc-ws` (a workspace member; the root talon.toml pins the build), `channels/ch15-upgrade-young` (a build younger than min-release-age is no candidate), `channels/ch15-upgrade-switch` (TALON_NIGHTLY=0: exit 10).

Notes. c2, c3a and ru2 are caught at L0 only, by design: an L2 case for them needs a second installed channel or a pin that leaves an empty table. The mutant for "the trust stop comes before any request" is up5 (the stop and the request are one decision in `user_table`, which `upgrade_user!` calls before `Nightlies.list_channel!`); a mutant that moves the call itself needs a code edit, not a `sed`.
