| Id | Rules | Mutation | Result |
| --- | --- | --- | --- |
| M01 | R-RC4 | `[4, 6, 7, 8, 11].contains(n)` | caught by l0:probe |
| M02 | R-RC4 Q1 | `code > 128 and is_fault(code - 128)` | caught by l0:probe |
| M03 | R-RC1 R-P2 | `[n, ..] => if n == 0 Pass else Fail(n)` | caught by l0:probe |
| M04 | R-RC3 | `TimedOut => Hang` | caught by l0:probe |
| M05 | R-RC2 | `if code != 0 and headers > 0 Fail(headers)` | caught by l0:probe |
| M06 | R-P3 | `NotStarted(text) => NoFact("not started: ${text}")` | caught by l0:probe |
| M07 | R-BL4 | `strip_positions(line).trim_end()` | caught by l0:probe |
| M08 | R-BL4 | `and !is_caret(body.get(i + 1) ?? "")` | caught by l0:probe |
| M09 | R-BL4 | `if full.starts_with(under_pkgs) {` | caught by l0:probe |
| M10 | R-BL5 Q2 | `candidate = without_repeats(facts.candidate)` | caught by l0:probe |
| M11 | R-PH7 | `Ok(found) if found == facts.id => Ok({})` | caught by l0:compiler |
| M12 | R-SO11 | `if Pin.is_nightly(id) {` | caught by l0:compiler |
| M13 | R-SO9 | `!id.contains(" ")` | caught by l0:compiler |
| M14 | R-LD7 | `Package / Platform => Err(None)` | caught by l0:ladder |
| M15 | R-BL1 | `[spec(facts.dir, check_args), spec(facts.copy, che` | caught by l0:ladder |
| M16 | R-LD5 | `} else if !no_file.is_empty() {` | caught by l0:ladder |
| M17 | R-EC11 | `in_app = compared.new.keep_if(/e/ !is_package(e))` | caught by l0:ladder |
| M18 | R-P7 R-EC1 | `Hang => Err(Fail.new(Internal, "the baseline check` | caught by l0:ladder |
| M19 | R-BL5 | `.concat(compared.removed.map(/e/ line("removed", e` | caught by l0:ladder |
| M20 | R-NI3 | `default: No,` | caught by l0:consent |
| M21 | R-CC2 | `_ = fx.delete!([copy])` | caught by l2:ladder/ld-ladder-flow (ladder/ld-ladder-flow) |
| M22 | R-CC2 | `skip: [".git"] }) {` | NOT CAUGHT |
| M23 | R-PH7 | `Compiler.require({ id: request.held, path_roc: req` | caught by l2:ladder/ld-no-check-refuse (ladder/ld-no-check-refuse) |
| M24 | R-BL6 | `if request.no_check {   fx.out!` | caught by l2:ladder/ld-no-check-refuse (ladder/ld-no-check-refuse) |
| M25 | R-AL6 | `if !changes.is_empty() {   ladder!` | caught by l2:ladder/ld-no-check-refuse (ladder/ld-no-check-refuse) |
| M26 | R-LD4 | `content: text }` | NOT CAUGHT |
| M27 | R-PP3 | `if request.members.len() >= 2` | caught by l2:ladder/ld-ladder-flow (ladder/ld-ladder-flow) |
| M28 | R-PH13 | `moved: rows.keep_if(/r/ r.moved)` | caught by l2:ladder/ld-ladder-flow (ladder/ld-ladder-flow) |
| M29 | R-LD6 | `Ok(spec) => match fx.probes!([spec]) {` | caught by l2:ladder/ld-ladder-flow (ladder/ld-ladder-flow) |
| L3-1 | R-CC2 | `if !skip.contains(name) {` | caught by l3:pr1-real (fx/pr1-real-fx-probes) |
| L3-2 | R-RC3 | `Ok(_) => if now >= entry.deadline {` | caught by l3:pr1-real (fx/pr1-real-fx-probes) |
| L3-3 | R-PP3 | `specs.map_with_index(   /_, i/ match finished.fin` | caught by l3:pr1-real (fx/pr1-real-fx-probes) |
| L3-4 | R-CC2 | `} else if exists!(to) {` | caught by l3:pr1-real (fx/pr1-real-fx-probes) |
| L3-5 | R-LD1 | `.cwd(Path.utf8(spec.dir))` | caught by l3:pr1-real (fx/pr1-real-fx-probes) |
| L3-6 | R-P3 | `{ ended: NotStarted(text), stdout: "", stderr: ""` | caught by l3:pr1-real (fx/pr1-real-fx-probes) |

Code after the run equals the copy in before/: yes
