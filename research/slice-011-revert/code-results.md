# Revert check of the code of slice 011 (TW12, code agent)

Script: `code-mutate.py` (its old texts match `cli/lib`). Each row is one small change of the new code, put back after the run. A compile error or a warning is INVALID, not a catch.
Run on 2026-10-20 with the pinned roc. W12 and P9 gave INVALID at first (`reverse` is `rev` in this List): the table has the second result.
`cli/` after the run equals `code-green/cli` (`diff -r`) and `code-before.sha256`.

| Id | Rules | Mutation | Result |
| --- | --- | --- | --- |
| W1 | R-CM7 R-EC2 | `[name] => Ok({ name: name })` | caught by l0:why |
| W2 | R-FL5 | `_ = Opts.read(args)?` | caught by l0:why |
| W3 | R-SC6 | `alias: if r.direct r.alias else "",` | caught by l0:why |
| W4 | R-SC15 | `o.series != r.series` | caught by l0:why |
| W5 | R-SC14 | `"platform (${row.alias})"` | caught by l0:why |
| W6 | R-SC14 | `"via ${row.via ?? ""}"` | caught by l0:why |
| W7 | R-SC15 | `x.alias == e.alias and x.name == e.name` | caught by l0:why |
| W8 | R-SC8 | `'${name}' is not in the project` | NOT CAUGHT (`Why.not_in` has no test: `Lookup.find` with the scope `Project` never gives `New`, so the text of `Lookup` is the one that the tests see. Dead branch, kept for the exhaustive `match`.) |
| W9 | R-CM7 | `if l.to == target {` | caught by l0:why |
| W10 | R-H7 | `} else if seen.contains(l.to) {` | NOT CAUGHT (Equivalent: `Closure.step` rejects a cycle, so no link list has a loop. The `seen` guard is a safety net.) |
| W11 | R-H7 | `Path => "${step.alias} (path)"` | caught by l0:why |
| W12 | R-CM7 | `walked.links.keep_if(/l/ l.from == from)` (reversed with `.rev()`) | caught by l0:why |
| W13 | R-C2 | `"raised from ${version}"` | caught by l0:why |
| W14 | R-CM7 | `if row.direct ["direct"] else []` | caught by l0:why |
| W15 | R-PH12 | `if row.kind == Release "${row.name} ${row.version}` | caught by l0:why |
| W16 | R-OUT4 | `("package", Listing.object_of(found.target))` | caught by l0:why |
| W17 | R-OUT5 | `("paths", Arr(Why.paths` | caught by l0:why |
| W18 | R-J4 | `Path => "path"` | caught by l0:why |
| W19 | R-OUT4 | `object_of = /row/ package_doc(row)` | caught by l0:why |
| R1 | R-E4 | `if !block.is_empty() fx.err!(block)` | caught by l3:why/wy1-why (why/wy1-why) |
| R2 | R-J1 | `if args.json {` | caught by l3:why/wy1-why (why/wy1-why) |
| R3 | Q24 | `Ls.walk!(fx, args, Bool.False)` | caught by l3:why/wy1-why (why/wy1-why) |
| R4 | Q23 | `if found.is_empty() {` | caught by l3:why/wy1-why (why/wy1-why) |
| R5 | R-CM7 | `args.command == ["why"]` | caught by l3:why/wy1-why (why/wy1-why) |
| R6 | R-C8 | `if notes {` | caught by l3:list/ls1-list (list/ls1-list) |
| R7 | R-C8 | `walk!(fx, args, Bool.True)` | caught by l3:list/ls1-list (list/ls1-list) |
| P1 | R-C2 | `[] => if closure_of(ctx, picked).conflict Err(NoFi` | caught by l0:pickclosure |
| P2 | R-C2 | `is_newer(e.version, r.version)` | caught by l0:pickclosure |
| P3 | R-C8 | `roots.any(/r/ r.group == e.group and is_newer` | caught by l0:pickclosure |
| P4 | R-C2 | `Ok(w) if is_newer(e.version, w.version) => acc.set` | caught by l0:pickclosure |
| P5 | R-C2 | `below = settle_below(ctx, roots, [], 20)` | caught by l0:pickclosure |
| P6 | R-FE1 | `missing = picked.map(/p/ p.c.url).concat(below).ke` | caught by l0:pickclosure |
| P7 | R-FE1 | `missing = picked.map(/p/ p.c.url).concat(below).ke` | caught by l0:pickclosure |
| P8 | R-OV1 | `add_below = /roots, acc, e/ if roots.any(/r/ r.gro` | NOT CAUGHT (No L0 case has a followed edge that names a LOWER version of a slot group. The mutation asks for the header of that lower version, which `roc` never reads. Gap of the tests.) |
| P9 | R-DT2 | `Ok(release) => release.deps.keep_oks(` (reversed with `.rev()`) | NOT CAUGHT (The order of the dependencies of one release: no L0 fact has 2 release URLs that become winners, so the order of the `Need` among them is not seen. Gap of the tests.) |
| P10 | R-C2 | `wrong_platform or release.deps.any(/dep/ needs_new` | NOT CAUGHT (Equivalent: the pairwise cut of `conflict_from` is a speed cut of the search. `closure_of` finds the same conflicts at the end of the tuple.) |

Caught 31 of 36.
