# Revert check of slice 010 (TW12)

Each row changes one place of a private reference implementation (deleted after the run). A compile error is INVALID, not a catch. The script is `mutate.py` (its old texts do not match the final code: the reference was deleted). Run on 2026-10-20 with the reference of the test agent. The rows L1, L3, L4, R4, R6, R7, R8, S5, W1 were changed after a first run that gave INVALID (a warning of the compiler) or an equivalent change.

| Id | Rules | Mutation | Result |
| --- | --- | --- | --- |
| C1 | R-C2 | `Text.compare(e.target.url, cur.url) == Before` | NOT CAUGHT (equivalent: 2 root entries of one group with 2 different URLs are a failure of Mvs anyway) |
| C2 | R-C2 | `} else if before(cur.version, e.target.version) {` | caught by l0:closure |
| C3 | R-CM9 | `raised = if before(low, sel)` | caught by l0:closure |
| C4 | R-CM9 | `direct = $heads.contains(f.group)` | caught by l0:closure |
| C5 | R-CM9 | `via = if direct Err(None) else Ok(f.edge.top)` | caught by l0:closure |
| C6 | R-C3 | `$plat = $plat.insert(g)` | caught by l0:closure |
| C7 | R-H7 Q16 | `Release => facts.chosen.get(g) ?? edge.target.url` | caught by l0:closure |
| C8 | R-H7 | `dir: node_dir(selected) })` | caught by l0:closure |
| C9 | R-H4 | `if edge.target.kind != Foreign {` | caught by l0:closure |
| C10 | R-H7 | `Err(problem) => Fail(normalize(problem, facts.node` | caught by l0:closure |
| C11 | R-CM2 | `if !walked.unknown.is_empty() {` | caught by l0:closure |
| C12 | R-C8 | `if series.len() >= 2 Ok` | caught by l0:closure |
| C13 | R-C8 | `via: if r.direct r.alias else r.via ?? r.alias` | caught by l0:closure |
| C14 | R-C8 | `The types of the ${n} series are different types.` | caught by l0:closure |
| C15 | R-EC10 | `Fail.new(NoTuple, message)` | caught by l0:closure |
| C16 | R-C2 | `, but the header names ${label(r.pinned)}` | caught by l0:closure |
| C17 | R-H7 | `urls.map(label), " -> ")` | caught by l0:closure |
| C18 | R-CM9 | `$links = $links.append({ from: edge.owner, alias:` | caught by l0:closure |
| C19 | R-H4 | `Err(Foreign) => Ok({ id: value, value, kind: Forei` | caught by l0:closure |
| C20 | R-H7 | `id = Text.resolve(d, value)` | caught by l0:closure |
| C21 | R-CM9 | `Ok(v) => Ok(if before(edge.target.version, v) edge` | caught by l0:closure |
| C22 | R-C8 | `same = releases.keep_if(/r/ r.form == form)` | caught by l0:closure |
| C23 | R-H7 | `Err(Release) => Err(Ignore)` | caught by l0:closure |
| E1 | R-H7 | `keep_if(/e/ e.name != "roc").map(/e/ { alias: e.na` | caught by l0:closure |
| E2 | R-H7 | `Ok(header) => Ok(header.entries().keep_if` | caught by l0:closure |
| E3 | R-H7 | `entries_of = /facts/ match Header.parse(facts.text` | caught by l0:closure |
| S1 | R-OUT2 | `r.alias.count_utf8_bytes() > most r.alias.count_ut` | caught by l0:listing |
| S2 | R-OUT2 | `if r.kind == Release "${r.name} ${r.version}" else` | caught by l0:listing |
| S3 | R-CM9 | `first.concat(raised).concat(foreign)` | NOT CAUGHT (equivalent: a raised row is never foreign) |
| S4 | R-CM9 | `["via ${alias}"]` | caught by l0:listing |
| S5 | R-CM9 | `${label(r)} (shown above)\n"` | caught by l0:listing |
| S6 | R-CM9 | `tail = if ms.is_empty() "" else " (${Str.join_with` | caught by l0:listing |
| S7 | R-CM9 | `ms = marks(r, Bool.False)` | caught by l0:listing |
| S8 | R-OUT4 | `("series", Arr(Closure.clashes` | caught by l0:listing |
| S9 | R-H4 | `("foreign", Flag(r.kind != Release))` | caught by l0:listing |
| S10 | R-OUT4 | `("platform", Flag(r.is_platform))` | caught by l0:listing |
| S11 | R-OUT4 | `Err(Header) => Null` | caught by l0:listing |
| S12 | R-CM9 | `if !args.operands.is_empty() {` | caught by l0:listing |
| S13 | R-CM9 | `name == "--tree"` | caught by l0:listing |
| S14 | R-CM9 | `Str.join_with(marks(r, Bool.True), "; ")` | caught by l0:listing |
| W1 | R-CM2 | `if !urls.is_empty() {` | caught by l2 (install/in1-flow, resolve/rs-install-add-key) |
| W2 | R-PD1 | `offline: facts.offline,` | caught by l3:list/ (list/ls1-list) |
| W3 | R-H7 | `urls = ids.keep_if(/id/ id.contains("://"))` | caught by l2 (install/in1-flow, resolve/rs-install-add-key) |
| W4 | R-EC18 | `Fail.new(Environment, "cannot read ${path}")` | caught by l3:list/ (list/ls1-list) |
| W5 | R-EC18 | `Fail.new(Environment, "cannot read ${path}")` | caught by l3:list/ (list/ls1-list) |
| L1 | R-PD9 | `files: Install.canonical_files!(fx, start.project)` | caught by l3:list/ (list/ls1-list) |
| L2 | R-C8 | `fx.err!("${note}\n")` | caught by l3:list/ (list/ls1-list) |
| L3 | R-J3 | `if args.json {` | caught by l3:list/ (list/ls1-list) |
| L4 | R-CM9 | `if opts.tree Listing.tree(m) else Listing.text(m)` | caught by l3:list/ (list/ls1-list) |
| L5 | R-C8 | `if found.contains(note) found else found.append(no` | NOT CAUGHT (G3: no case has 2 members) |
| R1 | R-CM2 | `walk_closure!(fx, request, loaded, changes, facts` | caught by l2 (closure/cl1-flow, install/in1-flow, resolve/rs-install-add-key) |
| R2 | R-CM2 | `walk_closure!(fx, request, loaded, edits, facts.k` | caught by l2 (closure/cl1-flow) |
| R3 | R-FL4 | `walk_closure!(fx, request, loaded, [], [])?` | caught by l2 (closure/cl1-flow, resolve/rs-frozen, resolve/rs-no-compiler) |
| R4 | R-CM2 | `var $nodes = known.map(/f/ { id: f.url, entries: f` | caught by l2:closure (closure/cl1-flow, gaps/g1-slice009, install/in1-flow, resolve/rs-install-add-key) |
| R5 | R-AL2 | `Pin(_) => Bool.False     _ => Bool.True` | NOT CAUGHT (equivalent: a pin edit changes only the roc entry, and the walk has no roc entry) |
| R6 | R-AL2 | `rows = if ops.is_empty() {    m.locked.rows` | caught by l2:closure (closure/cl1-flow, gaps/g1-slice009, install/in1-flow) |
| R7 | R-FL6 | `members = if named.is_empty() loaded.members else` | NOT CAUGHT (G3: no case has 2 members) |
| R8 | R-C8 | `if !$notes.contains(note) {` | NOT CAUGHT (G3: no case has 2 members) |
| GL4 | R-PH7 | `Compiler.require({ id: request.held, path_roc: req` | caught by l2 (gaps/g1-slice009) |
| GF10 | R-RP2 | `check_pin(start.loaded.intent, settings, start.d` | caught by l2 (gaps/g1-slice009) |
| GF17 | R-LD7 | `build: if checked.any(/m/ m.kind == App) Passed el` | caught by l2 (gaps/g1-slice009) |
| GW13 | R-NM7 | `if items.is_empty() Ok([]) else ask_names!(fx, ite` | caught by l2 (gaps/g1-slice009) |

Rows not run: W6 (the walk calls itself with `$read` only: it never ends, the run hangs).

Counts: see the end of the slice file.
