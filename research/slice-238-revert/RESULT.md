# Slice 238 mutation check

Script: mutate.sh (m1 to m11), mutate12.sh (m12, m13). Logs: run1-l0.log, run2-l2.log. Mirror in .tmp/slice-238-mut (deleted). Each run capped (16G, no swap, 600 s).
Baseline: l0-9 67/67 pass; `run.sh channels` 10/10 pass. No run hit the cap.

| Mutant | Place | Layer | Result |
| --- | --- | --- | --- |
| m1 name max 24 -> 25 | Channel.roc name_check `bytes.len() <= 24` | L0 | caught (2 expects fail; ChannelTest name_check and ChannelreadTest 12) |
| m2 trailing `-` allowed | Channel.roc `b != '-'` | L0 | caught (2 fail) |
| m3 reserved `compat` dropped | Channel.roc `reserved` | L0 | caught (2 fail) |
| m4 equality ignores `source` | Channel.roc `same` | L0 | caught (1 fail, ChannelTest compare) |
| m4b same, L2 | same | L2 channels | caught: ch10-both-differ |
| m5 no hint rule for "is not a channel name" | Channel.roc `hintless` | L0 | caught (1 fail) |
| m6 no hint rule for "missing key" | Channel.roc `hintless` | L0 | caught (1 fail) |
| m7 member file accepts `[channels]` | Intent.roc `member_tables` | L0 | caught (1 fail, ChannelreadTest 13) |
| m8 `not_tables` removed | Channel.roc `read` | L0 | caught (1 fail, ChannelreadTest 14) |
| m9 unknown-key warning dropped | Channel.roc `read_one` | L0 | caught (1 fail, ChannelreadTest 7) |
| m10 min name length 2 -> 1 | Channel.roc name_check | L0 | caught (2 fail) |
| m11 Base `channels_equal` never compares | Base.roc `(Read, [path])` | L2 channels | NOT caught |
| m12 ResolveLoad compare inverted | ResolveLoad.roc `if config_result.is_ok()` | L2 channels | caught: ch10-both-differ |
| m13 ConfigToml always adds the hint | ConfigToml.roc `Channel.hintless` | L2 + L0 | caught: ch10-config-reserved; L0 4 fail |

Not caught: m11. R-CH10 compare in the Base load has no test. All L2 cases use `install --frozen`, and the ResolveLoad compare already stops there. A case with a project command that uses only the Base load (for example `tln path` or `tln run`) and two different tables would cover it. Also, the "config.toml fault first" order (Q613 item 10) was not mutated: it is not a one-line change.

## Update: m11 re-run with ch10-proxy-differ

Baseline `run.sh channels`: 11 of 11 pass. m11 (Base `channels_equal` never compares): now CAUGHT by channels/ch10-proxy-differ (10 pass, 1 fail). The gap above is closed. Script: mutate11.sh, log: run3-m11.log.

m12 (ResolveLoad compare inverted): caught by channels/ch10-both-differ (9 pass, 1 fail).
m13 (ConfigToml always adds the hint): caught by channels/ch10-config-reserved (L2, 9 pass, 1 fail); L0 63 pass, 4 fail.
