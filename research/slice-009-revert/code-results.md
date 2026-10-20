# Revert check of the code of slice 009 (TW12, code agent)

Script: `code-mutate.py` (its old texts match `cli/lib`). Each row is one small change of the code, put back after the run. A compile error is INVALID, not a catch.
Run 1 gave INVALID (a compile warning of a constant condition or an unused name) for L5, F1, F6, F9, F13, F14, F16, W4, W11 and F18. The patterns of the 9 first were changed (no constant condition) and run again: the rows below are the second result. F18 (`Resolve.checked_members` gives all members) has no test: it needs a workspace with `--file` (G3 of the slice), so the row was dropped.

| Id | Rules | Mutation | Result |
| --- | --- | --- | --- |
| U1 | R-FL13 | `if given("--frozen") {` | caught by l0:update |
| U2 | R-NR4 Q1 | `if given("-i") and !opts.names.is_empty() {` | caught by l0:update |
| U3 | R-SP4 | `Ok({ opts, pick: given("-i") })` | caught by l0:update |
| V1 | R-FL14 | `if given("--frozen") {` | caught by l0:update |
| V2 | R-FL14 | `if given("--dry-run") {` | caught by l0:update |
| V3 | Q6 | `if !opts.names.is_empty() {` | caught by l0:update |
| V4 | R-FL14 order | `opts = Opts.read({ ..args, options: args.options.k` | caught by l0:update |
| K1 | R-SP14 | `item.alias.count_utf8_bytes() else most) + 2` | caught by l0:picker |
| K2 | R-SP14 | `"  ${(i + 1).to_str()})` | caught by l0:picker |
| K3 | Q2 | `.replace_each(",", " ")` | caught by l0:picker |
| K4 | Q2 | `items.get(n.minus_wrap(1))` | caught by l0:picker |
| K5 | Q2 | `match items.find_first(/item/ item.alias == word)` | caught by l0:picker |
| K6 | R-SP11 | `Ok(facts.items.keep_if(/item/ picked.contains(item` | caught by l0:picker |
| R1 | R-CM11 | `["--replace-dep", r.old, r.new]` | caught by l0:verify |
| R2 | R-CM11 | `["--replace-dep", r.old, r.new]` | caught by l0:verify |
| P1 | R-LB2 | `spec(flagged(Check))]` | caught by l0:verify |
| P2 | R-LB2 | `App => Ok(spec(flagged(Build({ output: output })))` | caught by l0:verify |
| P3 | R-LD7 | `Package / Platform => Err(None)   }   { first: [sp` | caught by l0:verify |
| P4 | R-LD6 | `output = Text.join(facts.tmp, "tln-probe.out")` | caught by l0:verify |
| N1 | R-SE7 | `"platform changes: ${facts.from.name} ${facts.from` | caught by l0:add |
| N2 | R-SL12 | `close => " Close versions:` | caught by l0:add |
| L1 | R-CC2 | `result = probe_in_place!(fx, request, member, tmp)` | caught by l2:verify/vf1-flow (verify/vf1-flow) |
| L2 | R-LD6 | `match fx.make_dirs!([tmp]) {   Ok(_) => {}   Err(_` | caught by l2:verify/vf1-flow (verify/vf1-flow) |
| L3 | R-BL1 | `Ladder.check({ output: first.1, dir, pkgs` | caught by l2:verify/vf1-flow (verify/vf1-flow) |
| L4 | R-PH7 | `Compiler.require({ id: request.held, path_roc: req` | NOT CAUGHT |
| L5 | R-LD7 | `built = Ladder.build({ output, dir, pkgs, baseline` | caught by l2:verify/vf1-flow (verify/vf1-flow) |
| F1 | R-I5 Q3 | `Err(None) => if request.command == Install {` | caught by l2:update/up1-flow (update/up1-flow) |
| F2 | R-SE7 | `platform_notes = moved_platform_notes(scoped, var` | caught by l2:update/up1-flow (update/up1-flow) |
| F3 | R-SE7 | `.keep_if(/(s, _)/ s.variable.is_platform)` | caught by l2:update/up1-flow (update/up1-flow) |
| F4 | R-SE7 R-J4 | `notes: pick_notes.concat(platform_notes).concat(pl` | caught by l3:update/up1 (update/up1-update-entries) |
| F5 | R-SE7 | `.fold(no_names, /found, text/ if found.contains(te` | NOT CAUGHT |
| F6 | R-SL12 Q5 | `Add.close_note({ selector: Ok(p.selector), version` | caught by l3:update/up1 (update/up1-update-entries) |
| F7 | R-SL12 Q5 | `versions = match facts.found.find_first(/c/ c.name` | caught by l2:resolve/rs-failures (resolve/rs-failures) |
| F8 | R-H4 Q8 | `r.alias == ref.name and r.what == Path` | caught by l3:update/up1 (update/up1-update-entries) |
| F9 | R-SP14 | `Ok(u) => Ok({ alias, name: v.name ?? v.group.form,` | caught by l2:update/up1-flow (update/up1-flow) |
| F10 | R-RP2 | `check_pin(start.loaded.intent, settings, start.d` | NOT CAUGHT |
| F11 | R-CM11 | `.keep_if(/u/ u.url != c.url and files.contains(u.f` | caught by l2:verify/vf1-flow (verify/vf1-flow) |
| F12 | R-CM11 | `.fold(no_replace, /found, r/ if found.contains(r)` | NOT CAUGHT |
| F13 | R-LF3 | `ran = if request.no_check {   fx.out!("check: skip` | caught by l3:verify/vf1 (verify/vf1-verify) |
| F14 | R-LD7 | `probes: checked.fold(0, /total, m/ total + if m.ki` | caught by l3:verify/vf1 (verify/vf1-verify) |
| F15 | R-CM11 | `notes: pick_notes.concat(platform_notes).concat(ra` | caught by l3:verify/vf1 (verify/vf1-verify) |
| F16 | R-OUT2 | `if edits.any(/e/ e.file == file) {    fx.out!("$` | caught by l2:verify/vf1-flow (verify/vf1-flow) |
| F17 | R-LD7 | `build: if checked.any(/m/ m.kind == App) Passed el` | NOT CAUGHT |
| W1 | R-NM7 | `Err(EndOfInput) => Err(Consent.no_person)` | caught by l2:update/up1-flow (update/up1-flow) |
| W2 | R-SP4 | `fx.err!(Picker.text(items))` | caught by l2:update/up1-flow (update/up1-flow) |
| W3 | Q2 | `Err(Invalid) => ask_again!(fx, items)` | caught by l2:update/up1-flow (update/up1-flow) |
| W4 | Q2 | `if pick and names.is_empty() {` | caught by l2:update/up1-flow (update/up1-flow) |
| W5 | R-NI2 | `shown.out!("nothing picked\n")` | caught by l2:update/up1-flow (update/up1-flow) |
| W6 | R-PD9 | `files: Install.canonical_files!(fx, start.project)` | caught by l2:update/up1-flow (update/up1-flow) |
| W7 | R-CM4 | `command: Update,  names,` | caught by l2:update/up1-flow (update/up1-flow) |
| W8 | R-AD28 | `add: { as_platform: Bool.False, as_alias: Err(Unse` | caught by l3:update/up1 (update/up1-update-entries) |
| W9 | R-DT5 | `shown.out!("${Report.resolved_line({ at: outcome.a` | caught by l2:update/up1-flow (update/up1-flow) |
| W10 | R-CM19 | `fx.out!(Out.json_ok({ command: args.typed, data: R` | caught by l3:update/up1 (update/up1-update-entries) |
| W11 | R-HF1 | `NeedTty => match Consent.picker(Mode.with_tty(mode` | caught by l2:update/up1-flow (update/up1-flow) |
| W12 | R-SO7 | `compiler = Install.on_path!(fx)` | caught by l2:update/up1-flow (update/up1-flow) |
| W13 | R-NM7 | `if items.is_empty() Ok([]) else ask_names!(fx, ite` | NOT CAUGHT |
| X1 | R-CM11 | `shown.out!("verified: the tuple passes. Nothing wa` | caught by l2:verify/vf1-flow (verify/vf1-flow) |
| X2 | R-J3 | `fx.out!(Out.json_ok({ command: args.typed, data: R` | caught by l3:verify/vf1 (verify/vf1-verify) |
| X3 | R-CM11 | `dry_run: Bool.False,` | NOT CAUGHT |
| X4 | R-LB4 | `strategy: opts.strategy,` | caught by l3:verify/vf1 (verify/vf1-verify) |
| X5 | R-PD9 | `files: Install.canonical_files!(fx, start.project)` | caught by l2:verify/vf1-flow (verify/vf1-flow) |
| X6 | R-SO7 | `compiler = Install.on_path!(fx)` | caught by l2:verify/vf1-flow (verify/vf1-flow) |
| Z1 | R-CM4 | `args.command == ["update"]` | caught by l3:update/up1 (update/up1-update-entries) |
| Z2 | R-CM11 | `args.command == ["verify"]` | caught by l3:verify/vf1 (verify/vf1-verify) |

Caught 57 of 64. Not caught: L4, F5, F10, F12, F17, W13, X3 (the reasons are in the slice file, "Verify results").
The sha256 of each file of `cli/` before the run is in `code-before.sha256`. After the run `diff -r cli <copy before>` shows no difference.
