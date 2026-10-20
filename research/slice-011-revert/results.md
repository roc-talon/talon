# Revert check of slice 011 (TW12)

Each row changes one place of a private reference implementation (deleted after the run). A compile error is INVALID, not a catch. The script is `mutate.py` (its old texts do not match the final code: the reference was deleted). Run on 2026-10-20 with the reference of the test agent. 34 rows: 29 caught (P10 and W13 first were not caught: a test row was added for each), 3 equivalent (W7, W8, R6), 1 needs 2 members (R4, G3), 1 invalid (R5). L2 `closure/cl2-chain` alone catches P1 and P2 (checked with a separate run: the mutation of the pick makes the update runs and the call log differ).

| Id | Rules | Mutation | Result |
| --- | --- | --- | --- |
| P1 | R-C2 | `conflict = $edges.any(/(_, i)/ picked.any(/p/ p.c.` | caught by l0:pickclosure |
| P2 | R-C2 R-FE1 | `missing: $winners.keep_if(/url/ !ctx.known.contain` | caught by l0:pickclosure |
| P3 | R-C2 R-OV1 | `Ok(b) if is_newer(i.version, b.ident.version) => a` | caught by l0:pickclosure |
| P4 | R-C2 Q16 | `Ok(k) => match acc.get(k) {      Ok(b) if is_newer` | caught by l0:pickclosure |
| P5 | R-C8 | `conflict = $edges.any(/(_, i)/ picked.any(/p/ p.c.` | caught by l0:pickclosure |
| P6 | R-C2 | `var $left = 20` | caught by l0:pickclosure |
| P7 | R-C2 | `and is_newer(i.version, p.c.ident.version)))` | caught by l0:pickclosure |
| P8 | R-C2 R-VA6 | `[] => if closure_check(ctx, picked).conflict Err(N` | caught by l0:pickclosure |
| P9 | R-C8 | `next = $edges.keep_if(/(_, i)/ !slot_groups.contai` | caught by l0:pickclosure |
| P10 | R-C2 R-DT2 | `missing = picked.map(/p/ p.c.url).concat(deeper)` | caught by l0:pickclosure (row 2b added after a first run that did not catch it) |
| W1 | R-CM7 | `[one] => Ok({ name: one })` | caught by l0:why |
| W2 | R-SC6 | `alias: if r.direct r.alias else ""` | caught by l0:why |
| W3 | R-SC15 | `.len() >= 2` | caught by l0:why |
| W4 | R-SC14 | `"platform (${r.alias})"` | caught by l0:why |
| W5 | R-SC14 | `Ok(a) => "via ${a}"` | caught by l0:why |
| W6 | R-SC14 | `"direct (${r.alias})"` | caught by l0:why |
| W7 | R-SC1 Q7 | `Lookup.New(name) => Err({ fail: Fail.new(Usage, "'` | NOT CAUGHT (equivalent: for the scope `Project`, `Lookup.find` gives the text `'<x>' is not in the project` itself, the `New` branch of the reference is dead code) |
| W8 | R-SC1 | `ref = Ref.parse(facts.text, Scope.Project, Bool.Fa` | NOT CAUGHT (equivalent: `Ref.parse` checks the selector for `Install` and `Project` in the same way) |
| W9 | Q15 | `if st.kind == Path "${st.alias} (path)" else st.al` | caught by l0:why |
| W10 | R-PH12 | `Str.join_with(p.map(/st/ if st.kind == Path "${st.` | caught by l0:why |
| W11 | R-CM9 | `marks_of = /row/ marks_of_row(row, Bool.False)` | caught by l0:why |
| W12 | R-OUT4 | `("package", Listing.package_doc(f.target))` | caught by l0:why |
| W13 | R-OUT4 | `Foreign => "foreign"` | caught by l0:why (the third member of the data expect was added after a first run that did not catch it) |
| W14 | R-PH12 | `walked.links.keep_if(/l/ l.from == from).join_map(` | caught by l0:why |
| W15 | R-OUT4 | `("alias", Text(st.alias)),` | caught by l0:why |
| W16 | R-CM7 | `head = "${Listing.label_of(found.target)}${if mark` | caught by l0:why |
| R1 | R-PD9 | `files: Install.canonical_files!(fx, start.project)` | caught by l3:why/ (why/wy1-why) |
| R2 | R-SC14 R-E4 | `if !block.is_empty() fx.err!(block)` | caught by l3:why/ (why/wy1-why) |
| R3 | R-J3 | `if args.json {` | caught by l3:why/ (why/wy1-why) |
| R4 | R-FL6 | `members = if named.is_empty() loaded.members else` | INVALID (compile error). The row needs 2 members: G3 (no workspace case in P0) |
| R5 | R-EC10 | `closures = ResolveBase.closure!(fx, request, { mem` | INVALID (compile error). No other row for a failure of the walk: L3 `why core --file conflict/main.roc` shows exit 10 |
| R6 | R-SC1 | `(_, []) => match results {    [(_, Err(e)), ..] =>` | NOT CAUGHT (equivalent: a tie always has a block, so the first branch of `flow!` returns it) |
| X4 | R-C2 | `Err(_) => settle(root, facts.nodes, [], 20)` | caught by l0:closuregaps |
| X19 | R-C3 | `{ ..r, is_pf: r.is_pf or e.is_platform, lowest }` | caught by l0:closuregaps |
