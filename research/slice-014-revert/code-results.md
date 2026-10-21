# Revert check of slice 014 (TW12, code agent)

The code of the slice is green (`scripts/test.sh` exit 0). `code-mutate.py` put 32 small changes in the code, one by one, and ran the tests that must fail (the ids of the rules are in the table).
A copy of `cli/` was made before the run: `cli-code.sha256` is its hash list. After the run `cli/` equals it (checked with `sha256sum`).
C25 was first a compile error (an unused parameter), so its change was made smaller and it ran again.

| Id | Rules | Mutation | Result |
| --- | --- | --- | --- |
| C1 | R-SC16 P0 bugs 1,2,3: find has no version filter | `matches = if scope == Project all.keep_if(/e/ in_s` | caught by l0:lookup, l0:why, l2:remove/rm1-flow, l3:why/wy1-why |
| C2 | R-SC16 an unmanaged entry matches a selector | `(Ok(range), Ok(version)) => Ranges.admits({ ranges` | caught by l0:lookup, l0:why, l3:why/wy1-why |
| C3 | R-SC16 find_move: one match is not used | `[one] => Ok(existing(one))   _ => match ref.sele` | caught by l0:lookup |
| C4 | R-SC16 find_move: the series filter keeps the wrong ones | `all.keep_if(/e/ e.series == series)` | caught by l0:lookup, l2:resolve/rs-failures |
| C5 | R-AU8 alias line needs distinct aliases | `a != "" and aliases.keep_if(/b/ b == a).len() == 1` | caught by l0:lookup |
| C6 | R-AU8 alias line keeps the caret | `Range(text) => text.drop_prefix("^")` | caught by l0:lookup, l2:resolve/rs-failures |
| C7 | R-SC16 a range of series has no series | `if parts.all(is_number) {` | caught by l0:lookup |
| C8 | R-SC14 last line of find | `_ => Err(tie(ref.name, entities, matches, "Use a n` | caught by l0:lookup, l0:why, l2:remove/rm1-flow, l3:why/wy1-why |
| C9 | R-SC15 printed names use only the matches | `matches.map(/e/ Lookup.printed(entities, e))` | caught by l0:lookup |
| C10 | R-WS8 build drops a fact with no alias | `repeat = fact.alias != "" and built.any(` | caught by l0:lookup |
| C11 | R-WS8 build dedups by alias only | `o.alias == entity.alias and o.name == entity.name` | caught by l0:lookup, l2:resolve/rs-failures |
| C12 | R-SC14 note of a direct entry | `Direct => "direct (${fact.alias})"` | caught by l0:lookup (not by l0:why) |
| C13 | R-SC16 an unmanaged entity has a version | `Unmanaged => { alias: fact.alias, name: "", series` | caught by l0:lookup, l0:why, l3:why/wy1-why |
| C14 | R-SC16 text of not in the project has no selector | `Ok(selector) => "${ref.name}@${selector_text(selec` | caught by l0:lookup, l0:why, l3:why/wy1-why, l2:remove/rm1-flow |
| C15 | R-WS8 alias form takes the first entity | `by_alias = if ref.form == Bare entities.keep_if(/e` | caught by l0:lookup, l2:resolve/rs-failures |
| C16 | R-SC15 printed name of an unmanaged entry | `printed = /entities, entity/ if entity.name == ""` | caught by l0:lookup |
| C17 | R-SC6 install find_move: no full name form | `} else {  entities.keep_if(/e/ e.name == ref.name)` | caught by l0:lookup |
| C18 | R-SC6 row_facts: alias of a non-direct row | `{ alias: if r.direct r.alias else "", what, role }` | caught by l0:why |
| C19 | R-SC15 why row key has no series | `if r.kind == Release r.series else "")` | caught by l0:why, l3:why/wy1-why |
| C20 | R-SC14 row_facts: role of a transitive row | `Via(r.via ?? "")` | caught by l0:why |
| C21 | R-SC6 row_facts: a path entry is a release | `Release => Release({ name: r.name, series: r.serie` | caught by l0:why, l3:why/wy1-why |
| C22 | R-SC16 update reads the name as a filter | `if request.command == Update Lookup.find_move(scop` | caught by l2:resolve/rs-failures |
| C23 | R-SC14 platform note in update | `role: if v.is_platform Platform else Direct,` | caught by l2:resolve/rs-failures |
| C24 | R-SC16 add never moves (Q1) | `entities.keep_if(/e/ e.name == name).len() >= 2` | caught by l2:resolve/rs-failures |
| C25 | R-SC16 add moves with --as (guard, no test) | `Ok(New(name)) if !request.add.as_platform and requ` | NOT CAUGHT (run again after the first try was a compile error: an unused `request`) |
| C26 | R-SC15 remove has no series | `series: ident.series, version: ident.version })` | caught by l2:remove/rm1-flow |
| C27 | R-SC16 remove moves | `Lookup.find(Scope.Project, ref, entities)` | caught by l2:remove/rm1-flow |
| C28 | R-SC6 remove: a path entry is a release | `Release(ident) => Release({ name: ident.name ?? id` | NOT CAUGHT |
| C29 | R-WS8 text of Vars | `Use a name from the list."` | caught by l0:vars |
| C30 | R-SO20 json note of install and update | `Ok({ ..outcome, notes: pin_notes.concat(outcome.no` | caught by l3:update/up1-update-entries |
| C31 | R-SO20 note order of install and update | `notes: pin_notes.concat(outcome.notes)` | caught by l3:update/up1-update-entries |
| C32 | R-SO20 json note of remove | `notes: pin_notes.concat(force_notes).concat(ran.no` | caught by l3:remove/rm2-workspace |

Caught 30 of 32. Not caught:

| Id | Why |
| --- | --- |
| C25 | The guard of D7 (`--as`) has no case (accepted in the review of the Q1 follow-up) |
| C28 | A path entry of a header as a release fact in `RemoveFlow.row_fact`: no L2 case removes a path entry with a selector or a name that the fake release would match. Rule R-SC6 is tested at L0 (`Why.row_facts`, `Lookup.find`) |
