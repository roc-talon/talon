# Slice 240 mutation check

Script: mutate.sh, log: run.log. Mirror in .tmp/slice-240-mut (deleted). Each run capped (16G, no swap, 600 s); L2 binary built with --opt=dev. No cap hit.
Baseline: l0-9 100 of 100 pass; L2 channels + roc 54 of 54 pass.
Mutant ids follow docs/slices/240-install-from-channel.md; m15 and m16 are new.

| Mutant | Place | Layer | Result |
| --- | --- | --- | --- |
| m1 `source_for` returns the registry source for a user channel | Nightlies.roc source_for | L2 channels | NOT caught (20 pass). Equivalent: `list_of!` sends a user channel to `list_channel!`, which never reads `source`. ch16-registry-set cannot see it. `source_for` is dead code today; only a change in `list_of!` would be seen. |
| m3 project tables never read (ProjectOnly never happens) | RocInstall.roc channel_ref! | L2 channels | caught: ch11-project-only, ch11-unknown |
| m4 an installed id prefix does not win over unknown_text | RocInstall.roc channel_ref! | L2 channels | caught: ch13-default-by-id |
| m5 a user build sets the default (install!) | RocInstall.roc install! | L2 channels | caught: ch11-install, ch11-no-default, ch11-switch-off, ch11-young, ch16-registry-set |
| m5b an already installed user build sets the default (flow!) | RocInstall.roc flow! | L2 channels | caught: ch11-install (run on an installed build) |
| m6 `.talon.json` has no `channel` and `source` | Toolchain.roc meta_from | L2 channels | caught: ch11-install, ch11-no-default, ch11-switch-off, ch11-young, ch16-registry-set |
| m8 guard: a nightly install records `channel` and `source` | RocInstall.roc build! | L2 channels + roc | caught: ch11-builtin-free, roc/cv1-pins, df1-default, ri1-flow, up1-update, up2-exclude, registry/cv1-roc-default, registry/cv1-roc-use, share/sh58, sh62 (x2), upgrade/ur1-roc (12 cases) |
| m9 switch not applied to a bare name | RocInstall.roc channel_domain | L2 channels | caught: ch11-switch-off |
| m10 min-release-age not applied | RocInstall.roc channel_domain | L2 channels | caught: ch11-young |
| m15 R-NS2 text with the channel name dropped | RocInstall.roc pick_failed_in | L2 channels | caught: ch11-switch-off |
| m13 `unknown_text` treats an all-hex text as a channel name | Channel.roc unknown_text | L0 | NOT caught (100 pass). The 9 unknown_text expects (ChannelinstallTest lines 110 to 118) have no all-hex text such as `abcdef1`. Rule: Design Q615 item 7 (a sha prefix is not a name). No L2 case has an unknown all-hex operand with no table either. |
| m16 install_ref match order (Project arm first) | Channel.roc install_ref | L0 | NOT caught, but equivalent: `found` looks in `config` first, so the first arm is never reached with a config table. |

Gaps: (1) m13, add `unknown_text("abcdef1")` = Err(NotChannelText). (2) m1 is an equivalent mutant; the R-CH16 "never the registry" rule is tested by ch16-registry-set only through `list_channel!`.
Not mutated: the "trust stop after the list request / after --offline" order, `--yes` and TALON_AUTO_INSTALL (channel_ref! has no code for them: the stop is always first), the project search from the run dir only, the pinned row key (tag vs id).

## Update: re-run of m1 and m13 after the fixes (mutate2.sh, run2.log)

Baseline: l0-9 100 of 100, L2 channels + roc 54 of 54.
- m1 (source_for returns the registry for a user channel): now CAUGHT by channels/ch16-registry-set (19 pass, 1 fail). The gap is closed.
- m13 (unknown_text takes an all-hex text as a name): now CAUGHT by l0-9 (99 pass, 1 fail, the ChannelinstallTest all-hex row). The gap is closed.
