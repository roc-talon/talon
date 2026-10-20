# Revert check of slice 008

Each row is one change of the private reference implementation (deleted after the run) and the tests that must fail. `research/slice-008-revert/mutate.py` has the rows (its `old` texts match the reference only). A change that does not compile (a warning counts, `roc build` exits 2) is INVALID, not a catch: 8 rows of the first run were INVALID (a literal `Bool.True` or `Bool.False` in a condition, an unused variable, a pattern that did not match), were rewritten and run again, and all 8 were caught. Four rows (S8, M8, M16, M18) were first not caught: a test row was added for each (S8: a file of this level that `seen` lacks; M8: the platform under another alias; M16: a talon.toml with a key in `[overrides]` and none in `[patch]`; M18: the row was a change of the doc comment, the pattern was made exact). Two rows (F13, F19) were not caught by the first deep cases, and each needed a change of a case: the `--json` envelope in the run of a path entry and a foreign URL, and a 3 level scan (`Inner/Mid.roc` and `Inner/Leaf.roc`, where a file of level 3 imports a file of level 2).

Result: 76 changes, 76 caught.

| Id | Rules | Mutation | Result |
| --- | --- | --- | --- |
| S1 | R-RV2 Q5 | `else facts.project_dir` | caught by l0:scan |
| S2 | R-RV2 Q5 | `facts.name.starts_with("./") or facts.name.starts_` | caught by l0:scan |
| S3 | R-RV2 Q5 | `Text.resolve(base, "${facts.name}.roc")` | caught by l0:scan |
| S4 | R-LD7 | `App => [facts.file]` | caught by l0:scan |
| S5 | R-LD7 | `_ => facts.exposed.map(` | caught by l0:scan |
| S6 | R-RV2 | `if alias == facts.alias {` | caught by l0:scan |
| S7 | R-RV2 | `!facts.seen.contains(file) and` | caught by l0:scan |
| S8 | R-RV2 | `!facts.sources.any(/s/ s.path == file) and` | caught by l0:scan |
| S9 | R-RV2 | `and !$next.contains(file) {` | caught by l0:scan |
| S10 | R-RV2 | `.drop_suffix("\r")` | caught by l0:scan |
| S11 | R-RV2 | `lines.get(found.line - 1)` | caught by l0:scan |
| S12 | R-RV2 | `Local => {       file = Scan.local_file` | caught by l0:scan |
| M1 | R-FL5 | `Ok(value) if value != "direct" =>` | caught by l0:removal |
| M2 | R-FL10 | `if value != "highest" and value != "lowest" =>` | caught by l0:removal |
| M3 | R-FL13 | `if given("--frozen") {` | caught by l0:removal |
| M4 | Q2 | `if args.operands.is_empty() {` | caught by l0:removal |
| M5 | R-CM3 | `force: given("--force")` | caught by l0:removal |
| M6 | R-LF4 | `dry_run: given("--dry-run")` | caught by l0:removal |
| M7 | R-LF3 | `no_check: given("--no-check")` | caught by l0:removal |
| M8 | R-RV3 | `Ok(row) => if row.is_platform {` | caught by l0:removal |
| M9 | R-RV5 | `Path => Path(row.value)     Foreign => Foreign(row` | caught by l0:removal |
| M10 | R-CM3 | `version: ident.version })` | caught by l0:removal |
| M11 | Q3 | `keys = if facts.shared {` | caught by l0:removal |
| M12 | R-RV4 | `"${Text.dir_of(t.path)}/.talon/patches/${facts.ali` | caught by l0:removal |
| M13 | R-RV4 | `"${Text.dir_of(t.path)}/.talon/patches/${facts.ali` | caught by l0:removal |
| M14 | R-OV1 | `[(Dependencies, "dependencies"), (Overrides, "over` | caught by l0:removal |
| M15 | R-OV1 | `(Overrides, "overrides"),` | caught by l0:removal |
| M16 | R-RV4 | `found.any(/k/ k.table == Patch)` | caught by l0:removal |
| M17 | R-WS14 | `Err(NoToml) => Ok([])      Ok(t) => keys_of` | caught by l0:removal |
| M18 | R-RV3 | `An app needs a platform. Use tln add --platform <n` | caught by l0:removal |
| M19 | R-EC2 | `Err(Fail.new(Usage, "${facts.alias} is the platfor` | caught by l0:removal |
| I1 | R-OV1 | `Overrides => "overrides"  Patch => "patch"` | caught by l0:intent |
| I2 | R-RV4 | `Patch => "patch" }  remove_key` | caught by l0:intent |
| I3 | R-CM3 | `Err(NoEntry) => Err(Fail.new(Internal, "${path}: t` | caught by l0:intent |
| I4 | R-CC7 | `Toml.get(doc, [table_name(k.table), k.key])` | caught by l0:intent |
| I5 | R-RV1 | `Ok(doc) => facts.keys.fold_try(doc, /current, k/ r` | caught by l0:intent |
| P1 | R-OUT4 | `("probes", Num(o.probes.to_i64_wrap())),   ("dry_r` | caught by l0:report |
| P2 | R-OUT4 | `Path => "path"` | caught by l0:report |
| P3 | R-OUT4 | `Err(None) => Null        },       ),      ]),` | caught by l0:report |
| P4 | R-RV4 | `("patches", Arr(o.patches.map(/p/ Obj([("alias", T` | caught by l0:report |
| P5 | R-LF3 | `("build", step_doc(o.build)),   (    "removed"` | caught by l0:report |
| P6 | R-OUT4 | `("table", Text(t.table))` | caught by l0:report |
| K1 | R-RV5 | `if !locked.rows.any(/r/ r.alias == alias) return E` | caught by l0:locked |
| K2 | R-RV5 | `if !locked.rows.any(/r/ r.alias == alias) return` | caught by l0:locked |
| F1 | R-RV2 | `if !hits.is_empty() and !facts.force {` | caught by l3:remove/rm1 (remove/rm1-remove-entries) |
| F2 | R-RV2 | `skip = request.no_check or forced` | caught by l3:remove/rm1 (remove/rm1-remove-entries) |
| F3 | Q4 | `skip = request.no_check or forced` | caught by l3:remove/rm1 (remove/rm1-remove-entries) |
| F4 | Q3 | `loaded.members.any(/m/ m.file != current and` | caught by l3:remove/rm1 (remove/rm1-remove-entries) |
| F5 | Q3 | `and m.locked.rows.any(/r/ r.alias == alias))` | caught by l3:remove/rm2 (remove/rm2-workspace) |
| F6 | R-CC1 | `else [plan.toml_path, plan.header]` | caught by l2:remove/rm1-flow (remove/rm1-flow) |
| F7 | R-RV2 | `for note in force_notes {    fx.out!("note: ${note` | caught by l3:remove/rm1 (remove/rm1-remove-entries) |
| F8 | R-RV1 | `. tln remove moves no other entry. Pass --no-check` | caught by l2:remove/rm1-flow (remove/rm1-flow) |
| F9 | R-RV2 | `results = if unknown.is_empty() [] else fx.read_fi` | caught by l2:remove/rm1-flow (remove/rm1-flow) |
| F10 | R-LF4 | `if request.dry_run return Ok(paths)` | caught by l3:remove/rm1 (remove/rm1-remove-entries) |
| F11 | R-LD7 | `probes: if member.locked.kind == App 3 else 2` | caught by l2:remove/rm1-flow (remove/rm1-flow) |
| F12 | R-RV4 | `fx.out!("kept: ${pt.dir} (the patch files of ${pt.` | caught by l3:remove/rm1 (remove/rm1-remove-entries) |
| F13 | R-RV5 | `Path(value) => { alias, kind: Path, name: value, v` | caught by l3:remove/rm1 (remove/rm1-remove-entries) |
| F14 | R-CM3 | `if !$aliases.contains(alias) {` | caught by l3:remove/rm1 (remove/rm1-remove-entries) |
| F15 | R-RV1 | `owners = rows.keep_oks(` | caught by l2:remove/rm1-flow (remove/rm1-flow) |
| F16 | R-RP3 | `no_check: skip,   })?   if !skip {` | caught by l3:remove/rm1 (remove/rm1-remove-entries) |
| F17 | R-RV1 | `check: ran.check,    build: ran.build,    removed,` | caught by l2:remove/rm1-flow (remove/rm1-flow) |
| F18 | R-RV4 | `plans.keep_oks(/(alias, p)/ p.patch_dir.map_ok(/di` | caught by l3:remove/rm1 (remove/rm1-remove-entries) |
| F19 | R-RV2 | `$seen = $seen.concat($next)` | caught by l2:remove/rm1-flow (remove/rm1-flow) |
| F20 | R-CC7 | `spans_now = if is_header Locked.spans({ text: now,` | caught by l2:remove/rm1-flow (remove/rm1-flow) |
| C1 | R-WS12 | `(Ok(ws), Err(NoCurrent)) => Err(` | caught by l3:remove/rm2 (remove/rm2-workspace) |
| C2 | R-J3 | `command: args.typed, data: Report.remove_data(outc` | caught by l3:remove/rm1 (remove/rm1-remove-entries) |
| C3 | R-LF4 | `if opts.dry_run {       shown.out!("dry run: nothi` | caught by l3:remove/rm1 (remove/rm1-remove-entries) |
| C4 | R-FL4 | `if args.quiet {  { ..fx, out!: /_text/ {} }` | caught by l3:remove/rm1 (remove/rm1-remove-entries) |
| C5 | R-J2 | `} else if args.json {  { ..fx, out!: /text/ fx.err` | caught by l3:remove/rm1 (remove/rm1-remove-entries) |
| C6 | R-PD9 | `Known.record!(fx, { roots, files: canonical_files!` | caught by l3:remove/rm2 (remove/rm2-workspace) |
| C7 | R-SO7 | `fx.programs!(["roc"])` | caught by l2:remove/rm1-flow (remove/rm1-flow) |
| C8 | R-LF4 | `dry_run: opts.dry_run,` | caught by l3:remove/rm1 (remove/rm1-remove-entries) |
| C9 | R-LF3 | `no_check: opts.no_check,` | caught by l3:remove/rm1 (remove/rm1-remove-entries) |
| C10 | R-CM3 | `{ names: opts.names, force: opts.force },` | caught by l3:remove/rm1 (remove/rm1-remove-entries) |
| C11 | R-PD9 | `Err(Standalone) => match project.file {    Ok(file` | caught by l3:remove/rm1 (remove/rm1-remove-entries) |
| W1 | R-CM3 | `else if args.command == ["remove"] {        Remove` | caught by l3:remove/rm1 (remove/rm1-remove-entries) |
