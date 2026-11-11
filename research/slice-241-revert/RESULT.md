# Slice 241 mutation check

Script: mutate.sh, log: run.log. Mirror in .tmp/slice-241-mut (deleted at the end). Each run capped (16G, no swap, 600 s); L2 binary built with --opt=dev. No cap hit. Never the working tree, never /tmp.
Baseline: l0-9 113 of 113 pass; L2 `channels/` 36 of 36 pass.
Each mutant ran the l0-9 driver and the L2 cases of `channels/ch06`, `ch07` and/or `ch08` (m13: all `channels/`). No full sweep.

| Mutant | Place | Result |
| --- | --- | --- |
| m1 `*` admits a user build (`Any => True`) | Pin.roc admits | caught: L0 (ChannelrangeTest 2). L2 not caught (the `Compiler.select` of ch07-no-user still has the `Pin.is_id` side, so the L0 row is the guard). |
| m2 a semver range admits a user build (the `user_parts` check removed) | Pin.roc admits | NOT caught, EQUIVALENT: `Ranges.admits` parses the id as a version, and a user id (`reify-2026-11-03-1708298`) is no semver, so it is never admitted. The check is a guard that cannot change a result. |
| m3 `>=<user id>` orders across channels (the name check of `user_order` removed) | Channel.roc user_order | caught: L0 (admits rows "another channel", "my-fork against my"). |
| m4 the switch ignored for a user build in rank 4 (`counts_as_nightly` to `is_nightly`) | Compiler.roc in_range | caught: L0 (ChannelrangeTest 4, the rows with `nightly` false). |
| m5 a named step counts from the selected compiler (`named_step` false) | RocInstall.roc offer_noted! | caught: ch08-step-name, ch08-step. |
| m6 bare `nightly` is not `nightly@latest` | Channel.roc named_ref | caught: L0 (ChannelrefTest 9), ch08-bare-nightly. |
| m7 any selector after a name is valid (bad selector) | Channel.roc named_ref | caught: L0, ch08-bad-selector. |
| m8 the config-only pin warning always shown | Channel.roc pin_warning | caught: L0 (ChannelrefTest 13), ch07-pin-exact, ch07-pin-atleast, ch07-pin-download, ch07-pin-download-atleast (stderr). |
| m9 `Free` for an installed build with a project-only table removed | Channel.roc pin_trust | caught: L0 (ChannelrefTest 10, rows 12, 16, 17). No L2 case has this state (see Gaps). |
| m10 the roc proxy does not call `Base.pin_trust!` | Proxy.roc | caught: ch07-proxy-trust, ch07-proxy-warn. |
| m11 the resolver does not call `pin_trust!` (no stop, no warning) | ResolveSelect.roc | caught: ch06-pin-trust, ch07-pin-warn. |
| m12 a pinned user build lists the nightlies, not its channel | RocInstall.roc range_id! | caught: ch07-pin-download, ch07-pin-download-atleast. |
| m13 a user build sets the default (install path of a pinned download) | RocInstall.roc install! | caught: ch07-pin-download, ch07-pin-download-atleast, and the 240 cases (ch11-install, ch11-no-default, ch11-switch-off, ch11-young, ch16-registry-set, ch08-*). |
| m14 `@<user id>` accepted as a ref (UserTag check off) | Nightlies.roc pick | caught: L0 (ChannelrangeTest 8). L2 not caught (no L2 case uses `@<user id>`). |

Result: 13 of 14 caught, 1 equivalent (m2). No gap was left, so no test was added.

## Gaps and notes

- m1, m3, m4, m9 and m14 are caught by L0 only. The L2 cases do not reach those decisions with a state that differs. This is acceptable: they are pure decisions (TW1).
- Not mutated: the order of the stop against `--offline` and against the switch exit 10. The stop is one call (`pin_trust!`) before the range, so m11 covers its absence; ch06-pin-trust runs 3 and 5 check the order but a move of the call was not mutated (no safe one-line edit).
- Not mutated: the project search from a sub dir for the pin (the code uses `loaded.tomls`).
