# Revert check of the code of slice 010 (TW12, code agent)

Script: `code-mutate.py` (its old texts match `cli/lib`). Each row is one small change of the new code (not of the code that moved out of `Resolve`), put back after the run. A compile error or a warning is INVALID, not a catch.
Run on 2026-10-20 with the pinned roc. Rows that gave INVALID in a first run (L5, L6, R4, R5, R6: an unused name or a bad pattern) and S4 (the pattern was in a doc comment) were changed and run again: the table has the second result.
The mutations run in the order l0 first, then the L2 and L3 cases that run the walk. `cli/` after the run equals `code-green/cli` (`diff -r`) and `code-before.sha256`.

| Id | Rules | Mutation | Result |
| --- | --- | --- | --- |
| X1 | R-H7 | `Path => if from_release {` | caught by l0:closure |
| X2 | R-H7 | `file = Text.resolve(dir, e.value)` | caught by l0:closure |
| X3 | R-ID2 | `"r:${group.form}#${group.series}"` | caught by l0:closure |
| X4 | R-C2 | `Err(_) => settle(root, facts.nodes, [], 20)` | NOT CAUGHT (The branch of a problem while a winner is not read (`settle`) has no test: every L0 problem case has all the nodes it needs. It is a gap of the tests.) |
| X5 | R-AL2 | `if !followed.needs.is_empty() {` | caught by l0:closure |
| X6 | R-EC10 | `Err(problem) => Fail(problem_of(problem, restore))` | caught by l0:closure |
| X7 | R-OV1 | `Ok(low) if newer(url.version(), low) => Ok(version` | caught by l0:closure |
| X8 | R-OV1 | `(Ok(have), Ok(v)) => if newer(have, v) Ok(v) else` | caught by l0:closure |
| X9 | R-CM9 | `direct: q.from == Err(Header),` | caught by l0:closure |
| X10 | R-CM9 | `from: Ok(id), top: q.top }` | caught by l0:closure |
| X11 | R-H4 | `r.shape != Foreign and !facts.nodes.any` | caught by l0:closure |
| X12 | R-C8 | `if series.len() < 2 {` | caught by l0:closure |
| X13 | R-C8 | `via: if r.direct r.alias else r.via ?? "" }` | caught by l0:closure |
| X14 | R-EC10 | `Fail.new(NoTuple, problem_text(problem))` | caught by l0:closure |
| X15 | R-EC10 | `urls.map(label_of), " -> ")` | caught by l0:closure |
| X16 | R-EC10 | `RootConflict(urls) => RootConflict(Text.sorted(tex` | NOT CAUGHT (The order of the `RootConflict` list: Mvs gives the list in byte order already for the test input, so the sort is not seen.) |
| X17 | R-H4 | `Err(Foreign) => if value.contains("://") Foreign e` | caught by l0:closure |
| X18 | R-H7 | `"https://talon.path/x${code}/1.0.0/x${code}.tar.zs` | caught by l0:closure |
| X19 | R-C3 | `is_pf: r.is_pf or e.is_platform, lowest }` | NOT CAUGHT (The platform mark from a later edge: no case has a package that is first named by a plain edge and then by a platform edge.) |
| E1 | R-H7 | `keep_if(/e/ e.name != "roc").map(/e/ { alias: e.na` | caught by l0:closure |
| S1 | R-OUT2 | `alias_width + 2 -` | caught by l0:listing |
| S2 | R-OUT2 | `if row.kind == Release "${row.name} ${row.version}` | caught by l0:listing |
| S3 | R-CM9 | `origin.concat(raised).concat(if row.kind == Releas` | NOT CAUGHT (Equivalent: a `foreign` row is never `raised` (only a release row has `raised`), so the order of these 2 marks cannot show.) |
| S4 | R-CM9 | `${label} (shown above)` | caught by l0:listing |
| S5 | R-CM9 | `marks_of(r, Bool.False)` | caught by l0:listing |
| S6 | R-OUT4 | `("series", Arr(Closure.clashes` | caught by l0:listing |
| S7 | R-H4 | `("foreign", Flag(row.kind != Release))` | caught by l0:listing |
| S8 | R-OUT4 | `Err(Header) => Null` | caught by l0:listing |
| S9 | R-CM9 | `if !args.operands.is_empty() {` | caught by l0:listing |
| S10 | R-CM9 | `name == "--tree"` | caught by l0:listing |
| W1 | R-CM2 | `if !urls.is_empty() {` | caught by l2:install/in1-flow (install/in1-flow) |
| W2 | R-FE7 | `offline: facts.offline,` | caught by l3:list/ls1-list (list/ls1-list) |
| W3 | R-EC18 | `Err(_) => return Err(Fail.new(Environment, "cannot` | caught by l3:list/ls1-list (list/ls1-list) |
| W4 | R-EC10 | `Fail(problem) => Err(Closure.failure(problem))` | caught by l3:list/ls1-list (list/ls1-list) |
| W5 | D3 | `run! = /fx, facts/ walk!(fx, facts, facts.known)` | caught by l2:closure/cl1-flow (closure/cl1-flow) |
| L1 | R-PD9 | `files: Install.canonical_files!(fx, start.project)` | caught by l3:list/ls1-list (list/ls1-list) |
| L2 | R-J1 | `if args.json {` | caught by l3:list/ls1-list (list/ls1-list) |
| L3 | R-CM9 | `if opts.tree Listing.tree(c) else Listing.text(c)` | caught by l3:list/ls1-list (list/ls1-list) |
| L4 | R-C8 | `fx.err!("${line}\n")` | caught by l2:closure/cl1-flow (closure/cl1-flow) |
| L5 | R-C8 | `if found.contains(line) found else found.append(li` | NOT CAUGHT (Needs 2 members in one project (G3 of the slice): the repeat of a note comes from the second member.) |
| L6 | R-FL6 | `members = if named.is_empty() loaded.members else` | NOT CAUGHT (Needs 2 members and `--file` (G3 of the slice): the L3 case has one member, so all members and the current member are the same list.) |
| L7 | R-CM9 | `args.command == ["list"]` | caught by l3:list/ls1-list (list/ls1-list) |
| R1 | R-AL2 | `ResolveBase.entries_after(m, changes)` | caught by l2:closure/cl1-flow (closure/cl1-flow) |
| R2 | D3 | `known: ResolveBase.known_nodes(facts.known),` | caught by l2:closure/cl1-flow (closure/cl1-flow) |
| R3 | D3 | `known: ResolveBase.known_nodes(facts.known) }` | caught by l2:closure/cl1-flow (closure/cl1-flow) |
| R4 | R-CM2 | `ResolveBase.closure_notes!(fx, request, closures)` | caught by l2:closure/cl1-flow (closure/cl1-flow) |
| R5 | R-AL2 | `Set({ alias, url }) => rows.map(/r/ if r.alias ==` | caught by l2:closure/cl1-flow (closure/cl1-flow) |
| R6 | R-AL2 | `Add({ alias, url, is_platform }) => rows.append({` | NOT CAUGHT (`entries_after` of an `Add`: the header of an added package is in the facts of the pick, so the walk reads the same files with or without the new entry.) |
| R7 | D3 | `entries: pf.concat(f.release.deps.map(/value/ { al` | caught by l2:closure/cl1-flow (closure/cl1-flow) |
| R8 | R-CM2 | `$nodes = run.nodes` | NOT CAUGHT (Needs 2 members (G3): the nodes that one member read are used by the second member.) |
| R9 | R-FL4 | `if !request.prompt.quiet {` | caught by l2:closure/cl1-flow (closure/cl1-flow) |
| R10 | R-CM2 | `closures = ResolveBase.closure!(fx, request, { mem` | caught by l2:resolve/rs-frozen (resolve/rs-frozen) |

Caught 44 of 52.
