# Slice 239 mutation check

Script: mutate.sh, log: run.log. Mirror in .tmp/slice-239-mut (deleted). Each run capped (16G, no swap, 600 s); L2 binary built with --opt=dev. No cap hit.
Baseline: l0-9 95 of 95 pass; L2 groups install, roc, tool, channels: 151 of 151 pass.

| Mutant | Place | Layer | Result |
| --- | --- | --- | --- |
| m1 user ids read month names (`names: Bool.True` in parse_id) | Channel.roc parse_id | L0 | caught (2 fail) |
| m2 reserved start matched with no `-` (`gitfork` refused) | Channel.roc name_check | L0 | caught (4 fail) |
| m3 tag-prefix limit 41 | Channel.roc tag_prefix_check | L0 | caught (1 fail) |
| m4 source part may start with `.` | Channel.roc good_part | L0 | caught (2 fail) |
| m5 source may end with `.git` | Channel.roc source_check | L0 | caught (2 fail) |
| m6 tag-prefix needs no final `-` | Channel.roc tag_prefix_check | L0 | caught (2 fail) |
| m7 counts_as_nightly = is_nightly (user ids not nightly) | Pin.roc counts_as_nightly | L0 | caught (6 fail) |
| m8 ClosureRequest keeps user rows | ClosureRequest.roc | L0 | caught (1 fail) |
| m9 recorded source wins over the table | Age.roc compiler_name_in | L0 | caught (1 fail) |
| m10 asset prefix wrong for every table (`roc_x<prefix>`, built-in nightly too) | Nightlies.roc asset_prefix | L2 install, roc, tool, channels | caught: 18 cases fail (install/in2-nocompiler, proxy/px2-install, roc/bs1-base, bs2-no-pin, bs3-range, cv1-pins, df1-default, gi1-install, gi2-zig, gi3-nozon, ri1-flow, up1-update, up2-exclude, us1-use, us3-step, us5-both-missing, us6-exclude-steps, upgrade/ur1-roc) |
| m11 user id keeps the tag text | Nightlies.roc id_of | L0 | caught (2 fail) |
| m12 Manage.kind_of uses is_nightly | Manage.roc | L0 | caught (1 fail) |
| m13 TalonRemove.kind_of drops counts_as_nightly | TalonRemove.roc | L0 | caught (1 fail) |
| m13b same, L2 `tool` and `remove` groups | TalonRemove.roc | L2 | not caught (94 pass). No L2 case has a user-channel id, which fits the scope: no command installs a user channel before 240. L0 covers it. |
| m14 Toolchain.range_allowed uses is_nightly | Toolchain.roc | L0 | caught (1 fail) |
| m15 Pin.use_gate uses is_nightly | Pin.roc | L0 | caught (1 fail) |

Not caught: m13b at L2 only (a user-channel id in `tool remove`), until slice 240 or 243 gives a command that has such a build. No rule is without an L0 test.
