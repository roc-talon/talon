| Id | Rules | Mutation | Result |
| --- | --- | --- | --- |
| P8 | R-OV1 | `add_below = /roots, acc, e/ if roots.any(/r/ r.gro` | caught by l0:pickclosure |
| P9 | R-DT2 | `Ok(release) => release.deps.keep_oks(` | caught by l0:pickclosure |
| P9s | R-DT2 | `Ok(release) => release.deps.keep_oks(` | caught by l0:pickclosure |
| LF5 | R-LF5 | `"--frozen" / "--no-probe"` | caught by l3:flags/fl12 (flags/fl12-bad-flags) |
| E1 | R-EV4 | `Ok((_, "0")) / Ok((_, "false")) => Ok(Bool.False)` | caught by l3:verify/vf1 (verify/vf1-verify) |
| E2 | R-NS8 | `Ok(b) => b     Err(Unset) => intent.toolchain.nigh` | caught by l3:verify/vf1 (verify/vf1-verify) |
| O2 | R-OV2 | `Err(_) => match t.intent.overrides.find_first(/d/` | caught by l2:ladder/ld-ladder (ladder/ld-ladder-flow) |
| S16 | R-SO16 | `match fx.write_atomic!(changed.map(/e/ { path: e.p` | caught by l3:add/ad1|tree (add/ad1-add-entries) |
| N11 | R-NM11 | `_ = Add.decide({ selector: f.selector, chosen: { n` | caught by l2:prompt/nm11 (prompt/nm11-alias-stops) |
| SC12 | R-SC12 | `text.starts_with(">=") and is_compiler_id(bound(">` | caught by l0:intent |
| A37 | R-AD37 | `offline: args.offline,` | caught by l3:add/ad1 (the stdout and the stderr differ: the run adds the entry from the page of the fake server). First run of the script: needle `http` was wrong (the request log has the same first line) |

## Second pass (manager answers Q28, Q29, Q32, Q33)

The reference (a private copy of `cli/` and `tests/` with the minimum code) is deleted. The 8 mutations M1 to M8 are in the slice file, section "Second pass". All 8 were caught: M1 to M6 by L3 `verify/vf1-verify`, M7 and M8 by L2 `resolve/rs-no-compiler`. The mutation script was in the scratchpad and is not kept: it needs the reference.
