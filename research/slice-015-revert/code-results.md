# Revert check of the code (slice 015, code agent, TW12)

`code-mutate.py` puts one small change in the code of the slice, runs the tests that must fail, and puts the code back. Each change is of one rule. The code before the changes and the code after them have the same `sha256sum` for each file of `cli/` (checked at the end).
First try INVALID (a compile error or a warning: an unused variable or an unreachable arm): C5, C18 and C20. Their changes were made smaller and they ran again. C21 first changed a path that no command reaches (a release row): it was replaced by the change of the table. C27 was added after the first run.

Result: caught 24 of 27. Not caught: C21, C25, C27 (see the list below the table).

| Id | Rules | Mutation | Result |
| --- | --- | --- | --- |
| C1 | R-H3 Replace: no URL check | `if !locked.rows.any(/r/ r.alias == alias) return E` | caught by l0:locked |
| C2 | R-H9 Replace refuses a path row (as Set) | `if !locked.rows.any(/r/ r.alias == alias) return E` | caught by l0:locked, l2:resolve/rs-unmanaged |
| C3 | Replace: an alias that is not there | `if !locked.rows.any(/r/ r.alias == alias) return E` | caught by l0:locked |
| C4 | R-AD38 --as over an unmanaged entry is taken | `if req.as_alias.is_ok() Ok(Unmanaged(alias)) else` | caught by l0:alias, l2:resolve/rs-unmanaged |
| C5 | R-AD18 the default alias replaces | `Ok(kind) => if req.as_alias.is_ok() Ok(Unmanaged(a` | caught by l0:alias, l2:resolve/rs-unmanaged |
| C6 | R-AD18 the kind in the text is swapped | `Ok("a foreign URL") else Ok("a path entry")` | caught by l0:alias |
| C7 | R-AD18 the text does not name the replace | `, or --as ${alias} to replace that entry.` | caught by l0:alias, l2:resolve/rs-unmanaged |
| C8 | R-AD38 Replace writes no talon.toml key | `toml: toml_of(alias, req.selector, req.no_pin),` | caught by l0:add |
| C9 | R-AD38 R-AD32 a package over the platform entry | `Ok(old) => if old.is_platform {` | caught by l0:add |
| C10 | R-AD22 R-H9 add X@sel of an unmanaged entry keeps | `Err(Add.never_changes({ alias: req.alias, value: r` | caught by l0:add, l2:resolve/rs-unmanaged |
| C11 | R-AD21 the note names a command | `note: Ok("${req.alias}: ${row.url} is in the heade` | caught by l0:add, l2:resolve/rs-unmanaged, l2:install/in1-flow |
| C12 | R-H9 never_changes: path and foreign swapped | `if value.contains("://") "a foreign URL" else "a p` | caught by l0:add, l2:resolve/rs-unmanaged, l3:update/up1-update-entries |
| C13 | R-H9 never_changes: no --as in the text | `To replace it, run tln add <name> --as ${facts.al` | caught by l0:add, l2:resolve/rs-unmanaged, l3:update/up1-update-entries |
| C14 | R-AD38 the note of a replace is not the entry note | `note: Ok("entry changes: ${old.url}` | caught by l0:add, l2:resolve/rs-unmanaged |
| C15 | R-H4 decide_alias: no row is unmanaged | `Err(Foreign) => Bool.True }` | caught by l0:add, l2:resolve/rs-unmanaged |
| C16 | R-H9 update X of an unmanaged entry is no refusal | `Lookup.Existing({ alias: a, name: "", .. }) if req` | caught by l2:resolve/rs-unmanaged, l3:update/up1-update-entries |
| C17 | R-H9 slice 009 G3: only a path entry is an entity | `Release(_) => Err(NotUnmanaged)` | caught by l2:resolve/rs-unmanaged |
| C18 | R-H9 the lookup has no unmanaged entity | `members.join_map(` | caught by l2:resolve/rs-unmanaged, l3:update/up1-update-entries |
| C19 | R-AD21 the json entry of a kept path entry has the alias as name | `Err(_) => { alias, name: plan.url,` | caught by l2:install/in1-flow |
| C20 | Q1 R-AD38 R-I3 the pick ignores the key of the replaced alias | `replaced_key_range(loaded, current, key) ?? "*"` | caught by l2:resolve/rs-unmanaged |
| C21 | Q1 R-AD38 R-I3 the key of [overrides] is ignored | `t.intent.deps.concat(t.intent.overrides).find_firs` | NOT CAUGHT |
| C22 | R-AD38 R-AD31 Replace edit is a Set (exit 1) | `op: Replace({ alias, url: new.url }),` | caught by l2:resolve/rs-unmanaged |
| C23 | R-AD38 the line names no old value | `line: "~ ${alias}: ${old} -> ${new.name} ${new.ver` | caught by l2:resolve/rs-unmanaged |
| C24 | R-AD31 the flow replaces the first platform row, not the alias | `Replace => match acc.header.find_first(/r/ r.alias` | caught by l2:resolve/rs-unmanaged |
| C25 | R-AD38 the json of a replace has no old value | `did: Moved({ alias, from: { name: old, version: ""` | NOT CAUGHT |
| C26 | R-AL2 entries_after ignores Replace | `Replace({ alias, url }) => rows.map(/r/ if r.alias` | caught by l2:resolve/rs-unmanaged |
| C27 | R-SL5 Q1 latest is a selector for the key range | `Ok(Latest) / Err(None) => replaced_key_range` | NOT CAUGHT |

## Not caught

| Id | What the test lacks | Rule |
| --- | --- | --- |
| C21 | No run has a key in `[overrides]` for an unmanaged alias that `--as` replaces. The pick then ignores that key | R-AD38, R-I3, R-OV1 |
| C25 | No `--json` run of a replace. `data.moved[].from` of a replaced entry (the old value as `name`, `version` empty) has no check | R-AD38, R-J3 |
| C27 | No run of `add <name>@latest --as <alias>` with a key in `talon.toml`. `latest` is no selector (R-SL5), so the key range holds | R-SL5, R-AD38 |
