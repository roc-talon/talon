# Revert check of slice 014 (TW12, test agent)

A private reference of the slice (the minimum code in `cli/`, built from the stubs) ran the whole fast set green: `scripts/test.sh` passed with all new and changed tests.
Then `research/slice-014-revert/mutate.py` put 30 small changes in it, one by one. A row of M1 to M30 is one change of one reference line and the tests that must fail
(L0 `lookup`, `why`, `vars`, L2 `remove/rm1-flow`, `resolve/rs-failures`, L3 `why/wy1-why`, `update/up1-update-entries`, `remove/rm2-workspace`). M14 and M19 were first
invalid (a compile warning, and a mutation that the tests could not see), so they were changed and run again. The two rows `roc-lang/http@0.x` and `@*` of the `find_move` expect
were added after the run (the reference passes them, and M8 changes the code that they check).
The reference is deleted: `cli/` equals the stubs again (`cli-stub.sha256`, checked with `sha256sum`).

| Id | Rules | Mutation | Result |
| --- | --- | --- | --- |
| M1 | R-SC16 P0 bugs 1,2,3 | `narrowed = if scope == Project narrow(how, ref, ma` | caught by l0:lookup, l0:why, l2:remove/rm1-flow, l3:why/wy1-why |
| M2 | R-SC16 unmanaged has no version | `Err(None) => Bool.False     },    )    Err(No` | caught by l0:lookup, l0:why, l3:why/wy1-why |
| M3 | R-SC16 version, not series | `Stay => match ref.selector {   Err(None) => match` | caught by l0:lookup, l0:why, l3:why/wy1-why |
| M4 | R-SC16 moving: series filter | `Ok(series) => matched.keep_if(/e/ e.series == seri` | caught by l0:lookup, l2:resolve/rs-failures |
| M5 | R-SC16 moving: 1 match is used | `Move => if matched.len() <= 1 {` | caught by l0:lookup |
| M6 | R-SC14 no alias line | `Move => Err(tie(ref, matched, entities, alias_hint` | caught by l0:lookup, l2:resolve/rs-failures |
| M7 | R-SC14 alias line needs distinct aliases | `distinct = aliases.all(/a/ a != "" and aliases.kee` | caught by l0:lookup |
| M8 | R-SC16 a range of series has no series | `if text.starts_with("^") {` | caught by l0:lookup |
| M9 | R-SC14 last line | `Err(None) => "Use a name from the list."` | caught by l0:lookup, l0:why, l2:remove/rm1-flow, l2:resolve/rs-failures, l3:why/wy1-why |
| M10 | R-SC15 printed over the whole scope | `Lookup.printed(scope_entities, e)` | caught by l0:lookup |
| M11 | R-WS8 build keeps repeated facts | `if e.alias != "" and found.any(/o/ o.alias == e.al` | caught by l0:lookup |
| M12 | R-WS8 dedup by alias only | `found.any(/o/ o.alias == e.alias and o.name == e.n` | caught by l0:lookup, l2:resolve/rs-failures |
| M13 | R-SC14 note of a direct entry | `Direct => "direct (${f.alias})"` | caught by l0:lookup (not by l0:why) |
| M14 | R-SC16 unmanaged entity with a version | `Unmanaged => { alias: f.alias, name: "", series: "", version: Ok("1.0.0")...` | caught by l0:lookup, l0:why, l3:why/wy1-why |
| M15 | R-WS8 alias form takes the first entity | `Bare => entities.keep_if(/e/ e.alias == ref.name)` | caught by l0:lookup, l2:resolve/rs-failures |
| M16 | R-SC16 text of not in the project | `Ok(sel) => "${ref.name}@${sel_text(sel)}"` | caught by l0:lookup, l0:why, l3:why/wy1-why, l2:remove/rm1-flow |
| M17 | R-SC15 printed unmanaged | `if e.name == "" {    e.alias` | caught by l0:lookup |
| M18 | R-SC6 alias of a non-direct row | `row_facts = /rows/ rows.map(   /r/ {    alias: if` | caught by l0:why |
| M19 | R-SC15 why row key has no series | `x.alias == alias and x.name == name` | caught by l0:why, l3:why/wy1-why |
| M20 | R-SC16 update reads the name as a filter | `(if request.command == Update Lookup.find_move(sco` | caught by l2:resolve/rs-failures |
| M21 | R-SC14 platform note in update | `role: if v.is_platform Platform else Direct,` | caught by l2:resolve/rs-failures |
| M22 | R-SC15 remove series | `series: ident.group.series, version: ident.version` | caught by l2:remove/rm1-flow |
| M23 | R-SC16 remove moves | `Lookup.find(Scope.Project, ref, entities)` | caught by l2:remove/rm1-flow |
| M24 | R-WS8 text | `Use a name from the list."))` | caught by l0:vars |
| M25 | R-SO20 json note of install and update | `Ok({ ..outcome, notes: ResolveBase.pin_notes(decis` | caught by l3:update/up1-update-entries |
| M26 | R-SO20 json note of remove | `notes: ResolveBase.pin_notes(decision).concat(forc` | caught by l3:remove/rm2-workspace |
| M27 | R-SO20 note order | `Ok({ ..outcome, notes: ResolveBase.pin_notes(decis` | caught by l3:update/up1-update-entries |
| M28 | R-WS8 transitive facts are never merged | `if e.alias != "" and found.any(` | caught by l0:lookup |
| M29 | R-SC14 note of a transitive row | `else Via(r.via ?? ""),` | caught by l0:why |
| M30 | R-SC6 path entry is a release | `what: if r.kind == Release Release(` | caught by l0:why |

## Q1 follow-up (runs 13 and 14 of `rs-failures`, `find_move` with the scope `Install`)

| Id | Mutation | Result |
| --- | --- | --- |
| N1 | `PickFlow`: an `install` name that matches 2 or more entries is not read with `find_move` | caught by l2:resolve/rs-failures (not by l0:lookup) |
| N2 | `Lookup`: no narrowing in the scope `Install` | caught by l2:resolve/rs-failures, l0:lookup |
| N3 | `PickFlow`: the rule needs 3 entities | caught by l2:resolve/rs-failures (not by l0:lookup) |
