# Revert check of the code of slice 008 (code agent)

The script is `research/slice-008-revert/code-mutate.py`. Each row is one small change of the real code in `cli/lib/`, and the tests that must fail (L0 `roc test` of one file, L2 and L3 with a binary that is built for the change, the cases `remove/`). A change that does not compile is INVALID. The file is put back after each row. `cli/` after the run is the same as the copy before it (`diff -r`: no difference).

Result: 39 changes, 38 caught, 1 not caught.

First run: F2, F3 and F4 were INVALID (the change left an unused variable, a warning stops `roc build`), and C2 was NOT CAUGHT because the pattern matched the doc comment first (not the code). The 4 rows were rewritten with exact patterns and run again: all 4 were caught. The rows below are the final ones.

Not caught: G1 (the text of a hang or a crash with no moved entry has no ` with `). The manager decided: no new test (G1 of the slice). A direct check, a scratch `expect` that was run once and deleted, gave `no tuple works: the whole-app check hangs on c (no result in 30 s)` and `... crashes on c (signal 11)` with `moved` empty.

| Id | Rules | Mutation | Result |
| --- | --- | --- | --- |
| S1 | R-RV2 Q5 | `Text.resolve(facts.project_dir, name.drop_prefix("` | caught by l0:scan |
| S3 | R-LD7 | `App => [facts.file]` | caught by l0:scan |
| S5 | R-RV2 | `Package(found) if found == alias` | caught by l0:scan |
| S6 | R-RV2 | `or facts.seen.contains(file)` | caught by l0:scan |
| S8 | R-RV2 | `if found.contains(file) or` | caught by l0:scan |
| S9 | R-RV2 | `text: line.trim_end()` | caught by l0:scan |
| S10 | R-RV2 | `.get(i.line - 1)` | caught by l0:scan |
| M1 | Q3 | `Ok(file) if !facts.shared =>` | caught by l0:removal |
| M2 | R-FL13 | `if read.frozen {` | caught by l0:removal |
| M3 | Q2 | `if read.names.is_empty() {` | caught by l0:removal |
| M5 | R-RV3 | `if row.is_platform {` | caught by l0:removal |
| M6 | R-RV5 | `Path => Path(row.value)` | caught by l0:removal |
| M8 | R-RV4 | `".talon/patches/${facts.alias}/"` | caught by l0:removal |
| M10 | R-RV4 | `keys.any(/k/ k.table == Patch)` | caught by l0:removal |
| I1 | R-CM3 | `Err(NoEntry) => Err(Fail.new(Internal, "${path}: t` | caught by l0:intent |
| I2 | R-OV1 | `Overrides => "overrides"` | caught by l0:intent |
| I3 | R-CC7 | `Toml.get(doc, [Intent.table_name(k.table), k.key])` | caught by l0:intent |
| P1 | R-OUT4 | `("removed", Arr(o.removed.map(removed_doc))),` | caught by l0:report |
| P3 | R-OUT4 | `version = match r.version {   Ok(v) => Text(v)   E` | caught by l0:report |
| K1 | R-RV5 | `if !locked.rows.any(/r/ r.alias == alias) return E` | caught by l0:locked |
| G1 | G1 | `moved_text = /owners/ if owners.is_empty() ""` | NOT CAUGHT |
| F1 | R-RV2 | `if !imported.is_empty() and !facts.force return` | caught by l3:remove/ (remove/rm1-remove-entries) |
| F2 | Q4 | `skip_check = request.no_check or forced` | caught by l3:remove/ (remove/rm1-remove-entries) |
| F3 | R-RV2 | `skip_check = request.no_check or forced` | caught by l3:remove/ (remove/rm1-remove-entries) |
| F4 | Q3 | `m.file != member.file and` | caught by l3:remove/ (remove/rm1-remove-entries, remove/rm2-workspace) |
| F6 | R-CC1 | `paths = toml_paths.concat([facts.file])` | caught by l2:remove/ (remove/rm1-flow) |
| F8 | R-RV1 | `. tln remove moves no other entry. Pass --no-check` | caught by l2:remove/ (remove/rm1-flow) |
| F11 | R-LD7 | `probes: if member.locked.kind == App 3 else 2` | caught by l2:remove/ (remove/rm1-flow) |
| F13 | R-RV5 | `Path(path) => { alias, kind: Path,` | caught by l3:remove/ (remove/rm1-remove-entries) |
| F16 | R-RP3 | `no_check: skip_check,   })?` | caught by l3:remove/ (remove/rm1-remove-entries) |
| F19 | R-RV2 | `$seen = seen` | caught by l2:remove/ (remove/rm1-flow) |
| F20 | R-CC7 | `spans_now: spans(f.now)` | caught by l2:remove/ (remove/rm1-flow) |
| F23 | R-RV1 | `if fail.kind == NoTuple {` | caught by l2:remove/ (remove/rm1-flow) |
| C1 | R-WS12 | `Install.check_member(Bool.True, start.project)?` | caught by l3:remove/ (remove/rm2-workspace) |
| C2 | R-J3 | `fx.out!(Out.json_ok({ command: args.typed,` | caught by l3:remove/ (remove/rm1-remove-entries) |
| C6 | R-CM3 | `{ names: opts.names, force: opts.force },` | caught by l3:remove/ (remove/rm1-remove-entries) |
| C8 | R-SO7 | `compiler = Install.on_path!(fx)` | caught by l2:remove/ (remove/rm1-flow) |
| C9 | R-FL4 | `if args.quiet {   { ..fx, out!: /_text/ {} }` | caught by l3:remove/ (remove/rm1-remove-entries) |
| W1 | R-CM3 | `args.command == ["remove"]` | caught by l3:remove/ (remove/rm1-remove-entries, remove/rm2-workspace) |
