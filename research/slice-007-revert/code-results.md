# Revert check of the code of slice 007 (code agent, 2026-10-20)

`research/slice-007-revert/code-mutate.py` makes one small change of the code in `cli/lib`, runs the tests that must fail, and puts the file back. A change that does not compile (a warning counts, `roc build` exits 2) is INVALID, not a catch: D14, P1, P2 and F6 were rewritten and run again (the rows below are the second run). The L2 app and `tln` are built for each row. The old file `mutate.py` and `results.md` are the record of the test agent (private reference code, deleted).

Caught 54 of 57. Not caught: D12, M1, F6 (see the table "Not caught" in the slice file). After the run the dir `cli/` equals the copy that was made before the first change (`diff -r`: no difference).

| Id | Rules | Mutation | Result |
| --- | --- | --- | --- |
| O1 | R-FL13 | `if given("--frozen") and count > 0 {` | caught by l0:opts |
| O2 | R-AD29 | `if given("--platform") and count != 1 {` | caught by l0:opts |
| O3 | R-FL5 | `Ok(value) if value != "direct" =>` | caught by l0:opts |
| O4 | R-FL10 | `Ok("lowest") => Ok(Ok(Lowest))` | caught by l0:opts |
| O6 | R-AD27 | `no_pin: given("--no-pin"),` | caught by l0:opts |
| O7 | R-NI1 | `rename_keys: if given("--rename-keys") Ok(Yes) els` | caught by l0:opts |
| O10 | R-FL8 | `dry_run: given("--dry-run"),` | caught by l0:opts |
| R1 | R-DT5 | `if facts.probes == 1 "1 probe"` | caught by l0:report |
| R2 | R-OUT5 | `("downloads", Num(0)),` | caught by l0:report |
| R3 | R-LF3 | `NotRun => Null` | caught by l0:report |
| R4 | R-OUT4 | `("snapshot", Text(o.at)),   ("probes", Num(o.probe` | caught by l0:report |
| R5 | R-OUT4 | `Ok(id) => Text(id)` | caught by l0:report |
| A1 | R-SL12 | `_ => newest_first.take_first(3)` | caught by l0:add |
| A2 | R-SL12 | `nearest(below, above, 3)` | caught by l0:add |
| A4 | Q9 R-WS12 | `match facts.held.find_first(/h/ !Ranges.admits(` | caught by l0:add |
| A5 | Q9 R-WS12 | `files = facts.held.keep_if(/h/ h.version == first.` | caught by l0:add |
| I1 | R-NI1 | `Err(KeyExists) => Err(Fail.new(Usage,` | caught by l0:intent |
| I3 | R-NI1 | `Toml.rename(doc, ["dependencies", r.from], r.to)` | caught by l0:intent |
| C1 | C6 | `[] => Err(unreadable("the baseline check on ${fact` | caught by l0:ladder |
| C2 | C6 | `[] => Err(unreadable("the whole-app check on ${fac` | caught by l0:ladder |
| C3 | C6 | `[] => Err(unreadable("the build on ${facts.compile` | caught by l0:ladder |
| C4 | C6 | `count = if n == 1 "1 error" else` | caught by l0:ladder |
| D1 | R-LF4 | `touched = if request.dry_run paths else` | caught by l3:add/ad1 (add/ad1-add-entries) |
| D2 | Q9 R-SL5 | `Ok(Latest) => Bool.True` | caught by l3:add/ad1 (add/ad1-add-entries) |
| D3 | R-SL12 | `Ok(c) if list.any(/x/ Ranges.admits({ ranges: [f.r` | caught by l3:add/ad1 (add/ad1-add-entries) |
| D4 | R-DT5 | `if planned {` | caught by l3:add/ad1 (add/ad1-add-entries) |
| D5 | R-LF4 | `if opts.dry_run {` | caught by l3:add/ad1 (add/ad1-add-entries) |
| D6 | R-DT5 | `total + if m.kind == App 3 else 2` | caught by l3:add/ad1 (add/ad1-add-entries) |
| D7 | R-AD21 | `for k in kept {` | caught by l3:add/ad1 (add/ad1-add-entries) |
| D8 | R-AD22 | `Keep => {       $kept = $kept.append(kept_of(` | caught by l3:add/ad1 (add/ad1-add-entries) |
| D11 | R-AD25 | `pairs = match plan.toml {   Ok({ key, value }) =>` | caught by l3:add/ad1 (add/ad1-add-entries) |
| K1 | D11 | `if touched.is_empty() and kept.is_empty() {` | caught by l3:add/ad1 (add/ad1-add-entries) |
| D12 | R-H3 | `Err(Unset) => if request.add.as_platform "pf" else` | NOT CAUGHT |
| D14 | R-RP3 R-OUT4 | `[id, ..] => Ok(id)` | caught by l3:add/ad2 (add/ad2-platform-json) |
| P1 | R-AD31 | `Ok(old) => if old.url == c.url {` | caught by l3:add/ad2 (add/ad2-platform-json) |
| P2 | R-AD33 | `request.add.as_alias == Err(Unset) => if one.is_pl` | caught by l3:add/ad2 (add/ad2-platform-json) |
| P4 | R-J2 | `} else if args.json {` | caught by l3:add/ad2 (add/ad2-platform-json) |
| P5 | R-FL4 | `shown_fx = /fx, args/ if args.quiet {` | caught by l3:add/ad2 (add/ad2-platform-json) |
| P6 | R-SE7 | `for note in plan.notes {   fx.out!(` | caught by l3:add/ad2 (add/ad2-platform-json) |
| P7 | R-J3 | `fx.out!(Out.json_ok({ command: args.typed,` | caught by l3:add/ad2 (add/ad2-platform-json) |
| P9 | R-J5 | `if !shown.stdout.is_empty() fx.out!(shown.stdout)` | caught by l3:add/ad2 (add/ad2-platform-json) |
| M1 | R-LF3 | `Ok({ probes: 0, check: Skipped, build: Skipped, no` | NOT CAUGHT |
| W1 | R-WS12 | `(Ok(ws), Err(NoCurrent)) if !opts.names.is_empty()` | caught by l3:install/in1 (install/in1-workspace-frozen-rename) |
| W2 | R-PD9 | `files: canonical_files!(fx, project), now })?` | caught by l3:install/in1 (install/in1-workspace-frozen-rename) |
| W3 | R-LF1 | `compiler = if opts.frozen Err(NoCompiler)` | caught by l3:install/in1 (install/in1-workspace-frozen-rename) |
| W4 | Q9 | `Add.check_held({ name, range: typed, held })?` | caught by l3:install/in1 (install/in1-workspace-frozen-rename) |
| W5 | R-WS12 Q9 | `"=${highest_version(held.map(/h/ h.version))}"` | caught by l3:install/in1 (install/in1-workspace-frozen-rename) |
| W7 | R-NM8 | `yes: request.prompt.yes, quiet: request.prompt.qui` | caught by l3:install/in1 (install/in1-workspace-frozen-rename) |
| W6 | R-NI1 | `flag: request.prompt.rename_keys })?` | caught by l2:resolve/rs-stale-key (resolve/rs-stale-key) |
| W9 | R-NI1 | `if done.answer == Yes {` | caught by l2:resolve/rs-stale-key-ask (resolve/rs-stale-key-ask) |
| W11 | R-I8 | `renames: renames.map(/r/ { from: r.from, to: r.to` | caught by l2:resolve/rs-stale-key (resolve/rs-stale-key, resolve/rs-stale-key-ask) |
| W14 | R-AD6 | `scope = if request.command == Update Scope.Project` | caught by l2:resolve/rs-install-names (resolve/rs-install-names) |
| F1 | M22 R-CC2 | `skip: [".git"] }) {` | caught by l2:install/in1-flow (install/in1-flow) |
| F3 | R-CC7 | `files.keep_if(/f/ f.read != f.now and f.spans_read` | caught by l2:install/in1-flow (install/in1-flow) |
| F4 | R-CC7 | `Ok(text) => text    Err(NotFound) => if is_header` | caught by l2:install/in1-flow (install/in1-flow) |
| F6 | R-PD9 | `files.map2(fx.canonical!(files), /file, result/ re` | NOT CAUGHT |
| F7 | R-SO7 | `fx.programs!(["roc"])` | caught by l2:install/in1-flow (install/in1-flow) |
