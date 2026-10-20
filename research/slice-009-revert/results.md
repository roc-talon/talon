# Revert check of slice 009 (TW12)

Each row changes one place of a private reference implementation (deleted after the run). A compile error is INVALID, not a catch. The script is `mutate.py` (its old texts do not match the final code: the reference is gone).

| Id | Rules | Mutation | Result |
| --- | --- | --- | --- |
| U1 | R-FL13 | `if given("--frozen") return Err(Fail.new(Usage, "f` | caught by l0:update |
| U2 | Q1 R-NR4 | `if pick and !opts.names.is_empty() return` | caught by l0:update |
| U3 | R-SP4 | `pick = given("-i")` | caught by l0:update |
| U5 | R-FL5 | `opts = Opts.read(without)?` | NOT CAUGHT |
| U6 | Q1 | `update -i picks the packages: do not name packages` | caught by l0:update |
| V1 | R-FL14 | `if given("--frozen") return Err(Fail.new(Usage, "t` | caught by l0:update |
| V2 | R-FL14 | `if given("--dry-run") return` | caught by l0:update |
| V3 | Q6 | `if !opts.names.is_empty() return` | caught by l0:update |
| V4 | R-FL14 | `opts = Opts.read(without)?` | caught by l0:update |
| V5 | R-FL14 | `given("--dry-run") return Err(Fail.new(Usage, "tln` | caught by l0:update |
| K1 | R-SP14 | `.count_utf8_bytes()).max() ?? 0) + 2` | caught by l0:picker |
| K2 | R-SP14 | `"  ${(i + 1).to_str()}) ${item.alias}` | caught by l0:picker |
| K3 | R-SP14 | `update can move these packages:` | caught by l0:picker |
| K4 | Q2 | `facts.line.replace_each(",", " ")` | caught by l0:picker |
| K5 | Q2 | `Ok(n) => if n >= 1 and n <= items.len() {` | caught by l0:picker |
| K6 | Q2 | `n >= 1 and n <= items.len() {` | caught by l0:picker |
| K7 | R-SP11 | `Ok(aliases) => Ok(facts.items.map(/i/ i.alias).kee` | caught by l0:picker |
| K8 | Q2 | `Ok(aliases) => Ok(facts.items.map(/i/ i.alias).kee` | caught by l0:picker |
| K9 | Q2 | `Err(_) => match items.find_first(/i/ i.alias == wo` | caught by l0:picker (row `js` added) |
| K10 | Q2 | `Err(_) => Err(Invalid)    Ok(aliases)` | caught by l0:picker |
| K11 | Q2 | `split_on(" ").keep_if(/w/ w != "")` | caught by l0:picker |
| K12 | R-SP14 | `${item.name} ${item.version}` | caught by l0:picker |
| R1 | R-CM11 | `["--replace-dep", r.old, r.new]` | caught by l0:verify |
| R2 | R-CM11 | `["--replace-dep", r.old, r.new]` | caught by l0:verify |
| R3 | R-CM11 | `Probe.args({ command: facts.command, file: facts.f` | caught by l0:verify |
| R4 | R-CM11 | `facts.replace.join_map(/r/ [` | caught by l0:verify |
| P1 | R-LB2 | `spec(Probe.replace_args({ command: Check, file: fa` | caught by l0:verify |
| P2 | R-LB2 | `App => Ok(spec(Probe.replace_args({ command: Build` | caught by l0:verify |
| P3 | R-LD7 | `Package / Platform => Err(None)   }   {    first:` | caught by l0:verify |
| P4 | R-LD6 | `output = Text.join(facts.tmp, "tln-probe.out")   b` | caught by l0:verify |
| P5 | R-BL1 | `first: [spec(Probe.args({ command: Check, file: fa` | caught by l0:verify |
| N1 | R-SE7 | `platform changes: ${facts.from.name} ${facts.from.` | caught by l0:add |
| N2 | R-SE7 | `${facts.from.version} -> ${facts.to.name} ${facts.` | caught by l0:add |
| N3 | R-SL12 | `" Close versions: ${Str.join_with(close, ", ")}."` | caught by l0:add |
| N4 | R-SL12 | `[] => ""   close => " Close` | caught by l0:add |
| L1 | R-CC2 | `result = verify_in!(fx, request, member, tmp)  _` | caught by l2:verify/vf1-flow (verify/vf1-flow) |
| L2 | R-LD6 | `match fx.make_dirs!([tmp]) {   Ok(_) => {}   Err(` | caught by l2:verify/vf1-flow (verify/vf1-flow) |
| L3 | R-BL1 | `checked = Ladder.check({ output: first.1, dir, pkg` | caught by l2:verify/vf1-flow (verify/vf1-flow) |
| L4 | R-LD7 | `built = Ladder.build({ output, dir, pkgs, baseline` | caught by l2:verify/vf1-flow |
| L5 | R-PP3 | `[base, candidate] => (base, candidate)   _ => retu` | caught by l2:verify/vf1-flow |
| L6 | R-PH7 | `Compiler.require({ id: request.held, path_roc: req` | NOT CAUGHT |
| F1 | Q3 R-I5 | `Err(None) => if request.command == Update {     {}` | caught by l2:update/up1-flow (update/up1-flow) |
| F2 | R-SE7 | `for note in platform_notes {   fx.out!("note: ${n` | caught by l2:update/up1-flow (update/up1-flow) |
| F3 | R-SE7 | `/(s, c)/ if s.variable.is_platform {     set_edits` | caught by l2:update/up1-flow (update/up1-flow) |
| F4 | R-SE7 | `notes: pick_notes.concat(platform_notes).concat(pl` | caught by l3:update/up1 (update/up1-update-entries) |
| F5 | R-SE7 | `.fold([], /found, text/ if found.contains(text) fo` | NOT CAUGHT |
| F6 | Q5 R-SL12 | `{ ..fail, message: "${fail.message}${Add.close_not` | caught by l3:update/up1 (and the old L2 cases) |
| F7 | Q5 | `[pick, ..] if fail.message.contains("has no releas` | NOT CAUGHT |
| F8 | Q8 R-H4 | `if request.command == Update and loaded.members.an` | caught by l3:update/up1 |
| F9 | R-SP14 | `.keep_if(/v/ v.host == Indexed)     .keep_oks(` | NOT CAUGHT |
| F10 | R-CM11 | `pins = if facts.verify [] else decision.writes` | caught by l2:verify/vf1-flow |
| F11 | R-CM11 | `written: if request.dry_run or done.verify [] else` | caught by l3:verify/vf1 (verify/vf1-verify) |
| F12 | R-CM11 | `if touched.is_empty() and kept.is_empty() and !fac` | caught by l2:verify/vf1-flow (verify/vf1-flow) |
| F13 | R-CM11 Q4 | `ran = if facts.verify {   verify_ladder!(fx, reque` | caught by l2:verify/vf1-flow (verify/vf1-flow) |
| F14 | R-LF3 | `if request.no_check {   fx.out!("check: skipped\n"` | caught by l3:verify/vf1 |
| F15 | R-CM11 | `replace = pairs    .join_map(/(s, c)/ s.variable.u` | caught by l2:verify/vf1-flow (verify/vf1-flow) |
| F16 | R-CM11 | `.fold([], /found, r/ if found.any(/f/ f.old == r.o` | NOT CAUGHT |
| F17 | R-LD7 | `probes: members.fold(0, /total, m/ total + if m.ki` | NOT CAUGHT |
| F18 | R-CM11 | `decision = Pin.decide({    members: loaded.members` | caught by l2:verify/vf1-flow (verify/vf1-flow) |
| W1 | R-NM7 | `json: args.json })` | caught by l2:update/up1-flow (update/up1-flow) |
| W2 | R-SP4 | `fx.err!(Picker.text(items))` | caught by l2:update/up1-flow (update/up1-flow) |
| W3 | Q2 | `Err(Invalid) => ask_again!(fx, items)` | caught by l2:update/up1-flow (update/up1-flow) |
| W4 | Q2 | `[] => return Ok(NothingPicked)` | caught by l2:update/up1-flow (update/up1-flow) |
| W5 | R-PD9 | `Known.record!(fx, { roots, files: Install.canonica` | caught by l2:update/up1-flow (update/up1-flow) |
| W6 | R-CM4 | `command: Update,   names,` | caught by l2:update/up1-flow (update/up1-flow) |
| W7 | R-AD28 | `add: { as_platform: Bool.False, as_alias: Err(Unse` | caught by l3:update/up1 (update/up1-update-entries) |
| W8 | R-DT5 | `shown.out!("${Report.resolved_line({ at: outcome.a` | caught by l2:update/up1-flow (update/up1-flow) |
| W9 | R-LF4 | `shown.out!("dry run: nothing was written\n")` | caught by l3:update/up1 (update/up1-update-entries) |
| W10 | R-CM19 | `fx.out!(Out.json_ok({ command: args.typed, data: R` | caught by l3:update/up1 (update/up1-update-entries) |
| W11 | R-NI2 | `shown.out!("nothing picked\n")` | caught by l2:update/up1-flow (update/up1-flow) |
| W12 | R-SO7 | `[] => return Ok(NothingPicked)    names => names` | caught by l2:update/up1-flow (update/up1-flow) |
| W13 | R-NM7 | `Err(EndOfInput) => Err(Fail.new(Usage, "update -i` | caught by l2:update/up1-flow (update/up1-flow) |
| W14 | R-SP4 | `match pick_names!(fx, mode, request([], Err(NoComp` | caught by l2:update/up1-flow (update/up1-flow) |
| X1 | R-CM11 | `shown.out!("verified: the tuple passes. Nothing wa` | caught by l2:verify/vf1-flow (verify/vf1-flow) |
| X2 | R-J3 | `fx.out!(Out.json_ok({ command: args.typed, data: R` | caught by l3:verify/vf1 (verify/vf1-verify) |
| X3 | R-FL4 | `shown = Install.shown_fx(fx, args)` | caught by l3:verify/vf1 (verify/vf1-verify) |
| X4 | R-PD9 | `Known.record!(fx, { roots: start.roots, files: Ins` | caught by l2:verify/vf1-flow (verify/vf1-flow) |
| X5 | R-CM11 | `dry_run: Bool.False,    add:` | caught by l3:verify/vf1 (verify/vf1-verify) |
| X6 | R-LB2 | `strategy: opts.strategy,` | caught by l3:verify/vf1 (verify/vf1-verify) |
| X7 | R-SO7 | `compiler = Install.on_path!(fx)  Resolve.verify!` | caught by l2:verify/vf1-flow (verify/vf1-flow) |
| Z1 | R-CM4 | `args.command == ["update"]` | caught by l3:update/up1 (update/up1-update-entries) |
| Z2 | R-CM11 | `args.command == ["verify"]` | caught by l3:verify/vf1 (verify/vf1-verify) |

## Rows that no test catches

| Id | Reason |
| --- | --- |
| U5 | Equivalent change: `Opts.read(args)` and `Opts.read(without)` give the same text for `--frozen` with names, so no test can tell them apart. |
| F5 | Gap: the platform note dedupe needs a workspace with 2 members that use the platform. No workspace case for update. |
| F7 | Gap: the guard on the close versions (only the 'has no release' failure) has no case with another no_tuple failure after a named update. |
| F9 | Gap: no picker case with an entry that has a Fixed host (not indexed). |
| F16 | Gap: the dedupe of the replacements needs 2 members with the same package. No workspace case for verify. |
| F17 | Gap: the count of probes of verify is not shown in a test output. |
| L6 | Gap: no L2 case where the held compiler is missing for verify (Compiler.require). |

Rows: 82. Caught: 75.
