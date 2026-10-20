# Revert check of slice 007

Each row is one change of the private reference implementation (deleted after the run) and the tests that must fail. `research/slice-007-revert/mutate.py` has the rows (its `old` texts match the reference only). A change that does not compile (a warning counts, `roc build` exits 2) is INVALID, not a catch: those rows were rewritten and run again.

| Id | Rules | Mutation | Result |
| --- | --- | --- | --- |
| O1 | R-FL13 | `if flag("--frozen") and !args.operands.is_empty()` | caught by l0:opts |
| O2 | R-AD29 | `args.operands.len() != 1 {` | caught by l0:opts |
| O3 | R-FL5 | `Ok(r) if r != "direct" =>` | caught by l0:opts |
| O4 | R-FL10 | `Ok("lowest") => Ok(Lowest)` | caught by l0:opts |
| O5 | R-FL10 | `Ok(other) => return Err(Fail.new(Usage, "--strateg` | caught by l0:opts |
| O6 | R-AD27 | `no_pin: flag("--no-pin"),` | caught by l0:opts |
| O7 | R-NI1 | `rename_keys: if flag("--rename-keys") Ok(Yes) else` | caught by l0:opts |
| O8 | R-AD28 | `as_alias: value("--as"),` | caught by l0:opts |
| O9 | R-FL9 | `snapshot: value("--snapshot"),` | caught by l0:opts |
| O10 | R-FL8 | `dry_run: flag("--dry-run"),` | caught by l0:opts |
| O11 | R-NI3 | `allow_moves: if flag("--allow-moves") Ok(Yes) else` | caught by l0:opts |
| R1 | R-DT5 | `if facts.probes == 1 "probe" else "probes"` | caught by l0:report |
| R2 | R-OUT5 | `("downloads", Num(0)),` | caught by l0:report |
| R3 | R-LF3 | `NotRun => Null` | caught by l0:report |
| R4 | R-OUT4 | `("snapshot", Text(o.at)),     ("probes", Num(o.pro` | caught by l0:report |
| R5 | R-OUT4 | `Ok(id) => Text(id)` | caught by l0:report |
| R6 | R-OUT4 | `("kept", Arr(o.kept.map(entry))),` | caught by l0:report |
| R7 | R-NI1 | `("renamed", Arr(o.renamed.map(/r/ Obj([("path", Te` | caught by l0:report |
| R8 | R-NI1 | `("from", Text(r.from)), ("to", Text(r.to))` | caught by l0:report |
| A1 | R-SL12 | `_ => flip(sorted).take_first(3)` | caught by l0:add |
| A2 | R-SL12 | `picked = [below.get(0), above.get(0), below.get(1)` | caught by l0:add |
| A3 | R-SL12 | `if close.is_empty() usage(` | caught by l0:add |
| A4 | Q9 R-WS12 | `match facts.held.find_first(/h/ !Ranges.admits(` | caught by l0:add |
| A5 | Q9 R-WS12 | `facts.held.keep_if(/h/ h.version == first.version)` | caught by l0:add |
| A6 | R-AD31 | `decide_platform = /req/ match req.header.find_firs` | caught by l0:add |
| A7 | Q9 R-EC10 | `Err(Fail.new(NoTuple, "no tuple works: '${facts.ra` | caught by l0:add |
| I1 | R-NI1 | `KeyExists => Fail.new(Usage,` | caught by l0:intent |
| I2 | R-NI1 | `NoEntry => Fail.new(Internal,` | caught by l0:intent |
| I3 | R-NI1 | `Toml.rename(current, ["dependencies", r.from], r.t` | caught by l0:intent |
| C1 | C6 | `[] => Err(Fail.new(Internal, "the baseline check o` | caught by l0:ladder |
| C2 | C6 | `[] => Err(Fail.new(Internal, "the whole-app check` | caught by l0:ladder |
| C3 | C6 | `[] => Err(Fail.new(Internal, "the build on ${facts` | caught by l0:ladder |
| C4 | C6 | `if n == 1 "error" else "errors"` | caught by l0:ladder |
| D1 | R-LF4 | `if request.dry_run {   show!` | caught by l3:add/ad1 (add/ad1-add-entries) |
| D2 | Q9 R-SL5 | `Ok(Latest) => Bool.True` | caught by l3:add/ad1 (add/ad1-add-entries) |
| D3 | R-SL12 | `if !versions.any(/v/ Ranges.admits` | caught by l3:add/ad1 (add/ad1-add-entries) |
| D4 | R-DT5 | `if changed fx.out!("${Report.resolved_line({ at: o` | caught by l3:add/ad1 (add/ad1-add-entries) |
| D5 | R-LF4 | `if outcome.dry_run fx.out!("dry run: nothing was w` | caught by l3:add/ad1 (add/ad1-add-entries) |
| D6 | R-DT5 | `probes: apps * 3 + (members.len() - apps) * 2` | caught by l3:add/ad1 (add/ad1-add-entries) |
| D7 | R-AD21 | `for k in plan.asked.kept {   fx.out!` | caught by l3:add/ad1 (add/ad1-add-entries) |
| D8 | R-AD22 | `_ => {       $names = $names.append(alias)` | caught by l3:add/ad1 (add/ad1-add-entries) |
| D9 | R-AD27 | `no_pin: request.add.no_pin, as_alias: request.add.` | caught by l3:add/ad1 (add/ad1-add-entries) |
| D10 | R-AD28 | `as_alias: request.add.as_alias, header: rows })?` | caught by l3:add/ad1 (add/ad1-add-entries) |
| D11 | R-AD25 | `pairs = match decided.toml {   Ok({ key, value })` | caught by l3:add/ad1 (add/ad1-add-entries) |
| D12 | R-H3 | `key: request.add.as_alias ?? Alias.default(a.name)` | NOT CAUGHT |
| D13 | R-SL10 | `range = match why {      Held(version) => "=${vers` | caught by l3:add/ad1 (add/ad1-add-entries) |
| D14 | R-RP3 | `info: Pinned(w.id) }))` | caught by l3:add/ad2 (add/ad2-platform-json) |
| P1 | R-AD31 | `[v] => if request.add.as_platform {       Err(Fres` | caught by l3:add/ad2 (add/ad2-platform-json) |
| P2 | R-AD33 | `if !request.add.as_platform and is_platform return` | caught by l3:add/ad2 (add/ad2-platform-json) |
| P3 | R-AD32 | `if request.add.as_platform and !is_platform return` | caught by l3:add/ad2 (add/ad2-platform-json) |
| P4 | R-J2 | `else if args.json fx.err!(text) else fx.out!(text)` | caught by l3:add/ad2 (add/ad2-platform-json) |
| P5 | R-FL4 | `if args.quiet {} else if args.json` | caught by l3:add/ad2 (add/ad2-platform-json) |
| P6 | R-SE7 | `fx.out!("note: ${line}\n")    $notes = $notes.appe` | caught by l3:add/ad2 (add/ad2-platform-json) |
| P7 | R-J3 | `if args.json fx.out!(Out.json_ok({ command: args.t` | caught by l3:add/ad2 (add/ad2-platform-json) |
| P8 | R-OUT4 | `pinned: match pinned { Ok(id) => Ok(id), Err(_) =>` | caught by l3:add/ad2 (add/ad2-platform-json) |
| P9 | R-J5 | `if !text.stdout.is_empty() fx.out!(text.stdout)` | caught by l3:add/ad2 (add/ad2-platform-json) |
| W1 | R-WS12 | `if !opts.names.is_empty() and project.file == Err(` | caught by l3:install/in1 (install/in1-workspace-frozen-rename) |
| W2 | R-PD9 | `Known.record!(fx, { roots, files: known, now })?` | caught by l3:install/in1 (install/in1-workspace-frozen-rename) |
| W3 | R-LF1 | `compiler = if opts.frozen {` | caught by l3:install/in1 (install/in1-workspace-frozen-rename) |
| W4 | Q9 | `Add.check_held({ name, range: range_text(ref.selec` | caught by l3:install/in1 (install/in1-workspace-frozen-rename) |
| W5 | R-WS12 | `Err(Held(highest_version(held)))` | caught by l3:install/in1 (install/in1-workspace-frozen-rename) |
| W6 | R-NI1 | `flag: request.prompt.rename_keys })?` | caught by l2:resolve/rs-stale-key (resolve/rs-stale-key) |
| W7 | R-NM8 | `yes: request.prompt.yes, quiet` | caught by l3:install/in1 (install/in1-workspace-frozen-rename) |
| W8 | R-NI1 | `fx.err!(rename.report)` | caught by l2:resolve/rs-stale-key (resolve/rs-stale-key, resolve/rs-stale-key-ask) |
| W9 | R-NI1 | `renames = if asked.answer == Yes` | caught by l2:resolve/rs-stale-key-ask (resolve/rs-stale-key-ask) |
| W11 | R-I8 | `renames: renames.keep_if(/r/ r.path == path).map(/` | caught by l2:resolve/rs-stale-key (resolve/rs-stale-key, resolve/rs-stale-key-ask) |
| W12 | R-FL13 | `frozen: opts.frozen,` | caught by l3:install/in1 (install/in1-workspace-frozen-rename) |
| W13 | R-NM | `yes: args.yes, quiet` | caught by l3:install/in1 (install/in1-workspace-frozen-rename) |
| W14 | R-AD6 | `scope = if request.command == Update Scope.Project` | caught by l2:resolve/rs-install-names (resolve/rs-install-names) |
| F1 | M22 R-CC2 | `skip: [".git"] }) {` | caught by l2:install/in1-flow (install/in1-flow) |
| F2 | M26 Q4 | `candidate_text(member, dir)?` | caught by l2:install/in1-flow (install/in1-flow) |
| F3 | R-CC7 | `f.read != f.now and f.spans_read != f.spans_now` | caught by l2:install/in1-flow (install/in1-flow) |
| F4 | R-CC7 | `Ok(text) => text    Err(NotFound) => if is_header` | caught by l2:install/in1-flow (install/in1-flow) |
| F5 | R-CC7 | `ordered = Guard.check_all($files)?` | caught by l2:install/in1-flow (install/in1-flow) |
| F6 | R-CC2 R-PD9 | `known = fx.canonical!(files).keep_oks(/r/ r)` | caught by l2:install/in1-flow (install/in1-flow) |
| F7 | R-SO7 | `fx.programs!(["roc"])` | caught by l2:install/in1-flow (install/in1-flow) |

76 rows: 75 caught, 1 not caught.

| Row | Why it is not caught |
| --- | --- |
| D12 | An equivalent change of the reference: the key of the want is only the id of its pick slot, and the alias of the entry comes from `Add.decide` (`--as` is tested by D10). |

Not mutated, because no case can show them (listed in the slice file, "Not covered"): the answer `No` of the stale-key prompt for a run that also has other changes, `update` with a stale key (slice 009: it keeps the warning), 2 or more members that change in one `install` (the ladder of slice 006 tests the members), and `--no-probe`, `--slots` (no unit probe in P0, R-LF2).
