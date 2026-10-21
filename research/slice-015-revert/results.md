# Revert check of slice 015 (TW12, test agent)

A private reference of the slice (the code that the tests describe) ran the whole fast set green (`scripts/test.sh`, exit 0). Then `mutate.py` put 26 small changes in it, one by one, and ran the tests that must fail (the ids of the rules are in the table). The reference is deleted: `cli/` equals the stubs again (`cli-stub.sha256`, checked with `sha256sum`). The files before the slice are in `before/`, the stubs in `stub/`.
N25 was first a compile error (an unused parameter), so its change was made smaller and it ran again.

Result: 26 of 26 caught. N26 (added after the manager review, Q1): the pick of a replace with no selector does not read the key of the alias, so run 11 of `rs-unmanaged` gets 3.0.0 in place of 2.1.0 (caught by l2:resolve/rs-unmanaged).

| Id | Rules | Mutation | Result |
| --- | --- | --- | --- |
| N1 | R-H3 Replace: no URL check | `if !locked.rows.any(/r/ r.alias == alias) return E` | caught by l0:locked |
| N2 | R-H9 Replace refuses a path row (as Set) | `if !locked.rows.any(/r/ r.alias == alias) return E` | caught by l0:locked, l2:resolve/rs-unmanaged |
| N3 | Replace: an alias that is not there | `if !locked.rows.any(/r/ r.alias == alias) return E` | caught by l0:locked |
| N4 | R-CC7 spans: Replace names no entry | `Replace({ alias, .. }) => alias` | caught by l0:locked |
| N5 | R-AD38 --as over an unmanaged entry is taken | `if req.as_alias.is_ok() Ok(Unmanaged(alias)) else` | caught by l0:alias, l2:resolve/rs-unmanaged |
| N6 | R-AD18 the default alias replaces | `if req.as_alias.is_ok() Ok(Unmanaged(alias)) else` | caught by l0:alias, l2:resolve/rs-unmanaged |
| N7 | R-AD18 the kind in the text is swapped | `"a foreign URL" else "a path entry"` | caught by l0:alias |
| N8 | R-AD18 the text does not name the replace | `Use --as <alias>, or --as ${alias} to replace tha` | caught by l0:alias, l2:resolve/rs-unmanaged |
| N9 | R-AD38 Replace writes no talon.toml key | `toml: toml_of(alias, req.selector, req.no_pin),` | caught by l0:add |
| N10 | R-AD38 R-AD32 a package over the platform entry | `Ok(old) => if old.is_platform {` | caught by l0:add |
| N11 | R-AD22 R-H9 add X@sel of an unmanaged entry keeps | `Err(Add.never_changes({ alias: req.alias, value: r` | caught by l0:add, l2:resolve/rs-unmanaged |
| N12 | R-AD21 the note names a command | `note: Ok("${req.alias}: ${row.url} is in the heade` | caught by l0:add, l2:resolve/rs-unmanaged, l2:install/in1-flow |
| N13 | R-H9 never_changes: path and foreign swapped | `kind = if facts.value.contains("://") "a foreign U` | caught by l0:add, l2:resolve/rs-unmanaged, l3:update/up1-update-entries |
| N14 | R-H9 never_changes: no --as in the text | `To replace it, run tln add <name> --as ${facts.al` | caught by l0:add, l2:resolve/rs-unmanaged, l3:update/up1-update-entries |
| N15 | R-H9 update X of an unmanaged entry is no refusal | `Ok(row) => return Err(Add.never_changes({ alias, v` | caught by l2:resolve/rs-unmanaged, l3:update/up1-update-entries |
| N16 | R-H9 slice 009 G3: only a path entry is refused | `r.alias == alias and unmanaged(r)` | caught by l2:resolve/rs-unmanaged |
| N17 | R-H9 the lookup has no unmanaged entity | `.concat(rows.keep_if(unmanaged).map(` | caught by l2:resolve/rs-unmanaged, l3:update/up1-update-entries |
| N18 | C25 R-AD19 --as is a lookup of a header entry | `Ok(New(name)) if !request.add.as_platform and requ` | caught by l2:resolve/rs-failures |
| N19 | R-AD38 R-AD31 Replace edit is a Set (exit 1) | `op: if unmanaged Replace({ alias: plan.alias, url:` | caught by l2:resolve/rs-unmanaged |
| N20 | R-AD38 the line names no new name | `"~ ${plan.alias}: ${from.name} -> ${f.name} ${c.ve` | caught by l2:resolve/rs-unmanaged |
| N21 | R-H9 R-I5 a key of an unmanaged alias is a want | `/(_, d)/ !rows.any(/r/ r.alias == d.key))` | caught by l0:vars, l2:resolve/rs-unmanaged |
| N22 | R-RV5 no key goes with an unmanaged entry | `Ok(file) if !facts.shared => keys_of(file, facts.a` | caught by l0:removal |
| N23 | C28 R-SC6 remove: a path entry is a release | `Release(ident) => Release({ name: ident.name ?? id` | caught by l3:remove/rm1-remove-entries |
| N24 | R-SC16 an unmanaged entry matches a selector | `(Ok(range), Ok(version)) => Ranges.admits({ ranges` | caught by l0:lookup, l3:remove/rm1-remove-entries |
| N25 | R-AD21 the json entry of a kept path entry has the alias as name | `Err(_) => { alias, name: value, version: "", note` | caught by l2:install/in1-flow |
