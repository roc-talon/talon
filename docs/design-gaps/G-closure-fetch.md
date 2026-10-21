# G-closure-fetch: the closure with and without a registry

Status: proposal (design gap). Author: gap agent, 2026-10-21.

## 1. The gap

| Rule | File, section | What it says | Problem |
| --- | --- | --- | --- |
| R-AL2 | Resolution 5 | "Fetch metadata for the full closure in one request (Registry 4)." | Only the registry case. With `direct` (P0, and a supported mode later) there is no such request. Step 2 has no text for that mode. |
| R-FE1 | CLI 7.1 | Registry: all fetches at once. `direct`: "the fetch of a level waits for the level before it". | Says the waterfall exists. Does not say its cost, its bound, or its order. |
| R-DI1 | CLI 7.3 | A transitive group needs no list. A command that resolves nothing makes no index call. | Silent on where such a command (`install --frozen`, `list`) gets the headers of the closure when a registry is on. |
| R-DI7 | CLI 7.3 | Kind, deps, pin come from the archive, "only when the solver asks for them (the lazy oracle)". No second copy. | Names only the solver. The closure walk (slice 010) and the pick (slice 011) are two askers with two loops. |
| R-AP16, R-AP17, R-AP28 | Registry 4.1 | The answer has the records of each candidate and of "their closure (the deps, to the end)". An `unknown` hash falls back to the archive (case 3). | The answer is a superset (all edges, not winners only). No rule says that the client applies the winners rule to it, or that the fallback is the same path as `direct`. |
| Design 2, R-H7, R-C2 | Design 2, 4.2; Resolution 2 | roc follows only the winner of each group. A path entry joins MVS. | The solver needs a closure for R-C2. Nothing says it is the same closure that the walk shows and that roc builds. |
| Slice 010 Q16 | `docs/slices/010-closure-list.md` | Default: winners only, a bad closure is exit 10. | A manager answer, not a rule. It does not say what a bad closure does inside a search (P1). |

Why it matters: the code has two loops and two closure functions that can disagree.

| Asker | Loop | Closure function | Follows path entries |
| --- | --- | --- | --- |
| Pick (R-AL3) | `cli/lib/PickFlow.roc:476` `pick_loop!` with `ResolveBase.read_releases!` | `Pick.closure_of` (`cli/lib/Pick.roc:59-68`) | No (`cli/lib/Pick.roc:66`: "a path value is no edge") |
| Walk (`install`, `update`, `verify`, `--frozen`, `list`, `why`) | `cli/lib/Walk.roc` `walk!` and `level!` | `Closure.step` over `Mvs.select` (`cli/lib/Closure.roc:24-31`) | Yes (R-H7) |

Result: with a path entry that names `json 2.2.0` and a slot `json` that the pick sets to `2.1.0` (for example `strategy = "lowest"`), the pick gives the tuple, and the walk then fails with exit 10 (`VersionConflict`). The pick never saw the edge. (From the doc tables; not run.)

## 2. Prior art (from what is known)

| Tool | Metadata apart from the archive | With no metadata server |
| --- | --- | --- |
| cargo | Sparse index: one file per crate, deps of all versions | Not supported (git index only) |
| npm, bun | Packument per package name, fetched level by level over HTTP/2 | Not supported |
| Go modules | `GOPROXY` serves `.mod` apart from `.zip`. `go.sum` has a separate hash for `go.mod` | `GOPROXY=direct`: VCS fetch, `go.mod` checked against its own `go.sum` hash. Level by level (graph pruning keeps it shallow) |
| uv, pip | PEP 658 `.metadata` file next to the wheel | Download the wheel (or a range request) to read the metadata |

Lesson: every tool reads metadata level by level when it has no index of deps. Go can read `go.mod` alone because it has a hash for it. Talon has a hash for the archive only (Design 2.1), so the archive is the only checked source of a header with no registry. This is the uv case without PEP 658.

## 3. Options

| # | Option | P0 cost | P1 and later | Users |
| --- | --- | --- | --- | --- |
| A | Keep the code. Add one sentence to R-AL2: "with `direct`, level by level". | None | Two loops and two closure rules stay. PubGrub (P1) adds a third asker. The path-entry difference stays. | Rare wrong exit 10 after a pick with a path entry |
| B | One model: header facts are a function of the hash. One "need" interface with ordered sources (known, registry answer, `packages/<hash>/`, archive download). One closure rule (roc MVS, winners only, path entries) for the solver and the walk. The registry is a prefetch of the same facts. | One new slice: merge the two loops, make `Pick` use the closure rule of `Closure`, new L0 rows | PubGrub, the registry (P2) and the `unknown` fallback (R-AP28 case 3) plug into one place. No mode has its own solver path. | Same results in both modes. `direct` costs d rounds for a closure of depth d |
| C | B, plus a local cache of header facts by hash (`talon/index/headers/<hash>`) | B, plus a cache file format, GC rules, R-DI7 changes | Saves a download only for a candidate that the pick rejects, or after GC. roc needs the archive of each winner anyway. | Small gain, one more store to explain and clean |
| D | B, but read `main.roc` at the tag (`raw.githubusercontent.com`) or a publisher sidecar asset, not the archive | B, plus a second fetch path | The file has no hash. The tag can move, and the archive can come from another tree. A fact from it can differ from what roc builds. | Wrong closures that no check catches |

## 4. Decision: option B

| Reason | Detail |
| --- | --- |
| One truth | The hash fixes kind, deps, platform and pin (Design 2.1). So "where a fact comes from" is a cost choice, never a semantic choice. Both modes give the same tuple for the same facts (R-DI14 already asks this of the candidates). |
| The archive is needed anyway | Each winner of the chosen closure goes to `packages/<hash>/` for the ladder (R-AL6) and the build. So in `direct` mode the walk adds no download for a winner. It adds only latency (rounds) and the archives of rejected candidates. |
| Registry is an optimization | The closure answer fills source 2 before the solver starts. The `unknown` fallback and `direct` are the same source 4. No second code path in P2. |
| One closure rule | R-C2 in the solver and the rows of `list` and `why` come from one function, so the solver never picks a tuple that the walk (or roc) rejects. |
| A, C, D rejected | A keeps the divergence. C adds a store for a small gain and breaks R-DI7 for no semantic reason. D reads facts that the hash does not check. |

Cost of one command (d is the depth of the chosen closure in levels, w the count of winners that are not in `packages/`):

| Command | With a registry | `direct` |
| --- | --- | --- |
| Resolve (`add`, `install` with work, `update`, `verify`) | 1 closure request (R-AL2). 0 rounds for facts in the answer. w archives, all at once (R-FE1). | R-DI2 lists for the groups of R-DI1. Up to d rounds. Each round fetches its nodes at the same time (R-DA5, 8 at once). w archives plus the rejected candidates that the solver read (R-DI9). |
| Resolve nothing (`install --frozen`, `list`, `why` in P0) | 0 index calls (R-DI1). Up to d rounds from `packages/` and archives | Same |
| Cache | `packages/<hash>/` only. The closure answer is `no-store` (R-AP3) and lives for one command. | `packages/<hash>/` only. Release lists in `talon/index/github/` (R-DI2). |

R-DI1 keeps "resolves nothing, no index call" in both modes: the closure of `--frozen` and `list` is what roc builds from the archives, the archives are needed for the build, and `--frozen` sends no request about the project.

Q16 becomes a rule (R-AL9 below): winners only. A problem of the roc closure rule (cycle, two hashes for one label, a pin lower than a dep needs, two platforms) is a conflict of the tuple in a search, and exit 10 only when nothing is free.

## 5. Design edits

E1. `DESIGN-RESOLUTION.md`, section 5, R-AL2 (rule changes, id kept).

Old: `| R-AL2 | 2 | Fetch metadata for the full closure in one request (Registry 4). It includes the shared matrix for these hashes. |`

New: `| R-AL2 | 2 | With a registry, send one closure query (Registry 4.1). Its answer gives the header facts (R-AL8) of each candidate and of their closures, and the shared matrix for these hashes. With direct, this step sends nothing: steps 3 to 6 get each fact when they need it (R-AL8, source 4). |`

E2. `DESIGN-RESOLUTION.md`, section 5, after the step table and before "Example failure output". New rules R-AL8 and R-AL9 (both ids are free: `grep -rn "R-AL8\|R-AL9"` finds nothing).

New text:

```text
R-AL8: Header facts. The header facts of a node are its kind, its deps (the URL entries and the path entries), its platform and its `roc:` pin. A node is a release (by hash) or a path file (R-H7). The hash fixes the facts of a release (Design 2.1), so each source gives the same value, and a fact never expires. The solver (steps 3 to 5) and the closure walk (CLI R-CM2, R-CM9, R-CM7) ask for facts in one form: the list of the nodes whose facts they lack. Talon gets the facts of all nodes of one list at the same time (CLI 7.5, R-DA5). For each node, the first source that has the facts is used:

| Source | Node | Cost |
| --- | --- | --- |
| 1 | The facts that this command has already | none |
| 2 | The closure answer of step 2, when the command sent one | none (one request in step 2) |
| 3 | `packages/<hash>/main.roc` when it exists, or the path file | one file read |
| 4 | A download of the archive (CLI 7.1, R-DI7), then source 3 | one archive, at most 10 MB |

A closure of depth d takes at most d lists. The registry makes it 1 request (step 2), unless the answer lacks a hash (Registry R-AP28 case 3).

R-AL9: The closure of a tuple is the closure that roc builds (Design 2): the header entries, the path entries and their entries (R-H7), and the deps of the winner of each group, to the end. The winner of a group is the highest version that an edge names. Talon never asks for the facts of a version that does not win, also when the registry answer has them. Each user of a closure applies this one rule: the solver for R-C2 and R-C3, `tln list`, `tln why`, and the walk before the ladder. A problem of the rule (a cycle, one label with two hashes, a header pin lower than a dep needs, two platforms) is a conflict of the tuple in steps 3 to 5: the solver tries the next tuple (P0: R-PH10). When no variable is free (`install --frozen`, `list`, `why`), it stops with exit code 10 (`no_tuple`) and names the problem.
```

E3. `DESIGN.md`, section 5 rule groups. Old: `| R-AL1 to R-AL7 | Algorithm steps | Resolution 5 |` New: `| R-AL1 to R-AL9 | Algorithm steps, header facts, the closure rule | Resolution 5 |`

E4. `DESIGN-CLI.md`, 7.1, R-FE1 (id kept). Old:

```text
| R-FE1 | No waterfall | The registry returns the full closure up front. All fetches start at once (7.5). With `direct`, the solver fetches lazily (7.3, R-DI7), so the fetch of a level waits for the level before it. |
```

New:

```text
| R-FE1 | No waterfall | The registry returns the header facts of the full closure up front (Resolution 5, R-AL2). All fetches of the chosen closure start at once (7.5). With `direct`, the facts of a node come from its archive (Resolution 5, R-AL8, source 4), so the fetch of a level waits for the level before it: a closure of depth d takes at most d rounds, and the nodes of one round download at the same time. |
```

E5. `DESIGN-CLI.md`, 7.3, R-DI7 (id kept). Only the first sentence changes. Old:

```text
Kind, deps and the `roc:` pin come from the archive, only when the solver asks for them (the lazy oracle, Resolution 5).
```

New:

```text
Kind, deps and the `roc:` pin come from the archive, only when the solver or the closure walk asks for them (Resolution 5, R-AL8, sources 3 and 4). A registry answer that lacks a hash uses the same rule (Registry 4.1, R-AP28, case 3).
```

E6. `DESIGN-CLI.md`, 7.3, R-DI1 (id kept). Only the last sentence changes. Old:

```text
A command that resolves nothing (`tln install --frozen`, the `roc` proxy) makes no index call.
```

New:

```text
A command that resolves nothing (`tln install --frozen`, `tln list`, the `roc` proxy) makes no index call, also with a registry. It reads the closure from `packages/` and the archives (Resolution 5, R-AL8, sources 3 and 4).
```

E7. `DESIGN-CLI.md`, 7.3, the cost table. New row after the row "Kind, deps and pin of one candidate (R-DI7)":

```text
| The closure of one tuple (Resolution 5, R-AL8, R-AL9) | 0 | 1 archive for each winner that is not in `packages/`, in at most d rounds (d: the depth of the closure) |
```

E8. `DESIGN-REGISTRY.md`, 4.1, R-AP17, row `artifacts` (id kept). Old:

```text
| `artifacts` | The record (R-RE1) of each candidate, of each hash in `hashes`, and of each hash in their closure (the deps, to the end) |
```

New:

```text
| `artifacts` | The record (R-RE1) of each candidate, of each hash in `hashes`, and of each hash in their closure (the deps, to the end, of each version that an edge names, not only the winners). The client applies the winner rule of Resolution 5, R-AL9. |
```

## 6. Work that follows

New slice (after 012): "one closure model".

| # | Change | Where | Test (red first) | Rule ids |
| --- | --- | --- | --- | --- |
| 1 | One need loop: `pick_loop!` and `Walk.level!` call one command function that gets the facts of a list of nodes from sources 1, 3, 4 (source 2 comes in P2). One fact type for a release and a path file (today `Fact` with `Release` and `Closure.Node`) | `cli/lib/PickFlow.roc:476`, `cli/lib/Walk.roc`, `cli/lib/ResolveBase.roc:251` | L2 `closure/cl1-flow` and `cl2-chain` keep their calls.log (no new call). A case where a winner is in `packages/` already: no download | R-AL8 R-FE1 R-DI7 |
| 2 | `Pick.step` checks R-C2 and R-C3 with the closure rule of `Closure` (path entries are nodes and their edges count) | `cli/lib/Pick.roc:59-68`, `:251` | L0 `pickclosure`: a path file names `json 2.2.0`, the slot `json` with `strategy lowest` must give `2.2.0` (or `Need` of the path file first), not `2.1.0`. Revert check: drop path edges in the pick | R-AL9 R-C2 R-H7 |
| 3 | A problem of the closure rule inside the pick is a conflict of that tuple (next tuple), not a `Fail` | `cli/lib/Pick.roc` | L0 `pickclosure`: two candidates, the first gives one label with two hashes, the second is clean: `Done` with the second | R-AL9 R-C2 |
| 4 | `--frozen` and `list` with a registry set: no index call | L2, when P2 adds the registry `Fx` calls | P2 slice | R-DI1 R-AL9 |
| 5 | Registry answer as source 2, `unknown` hash to source 4 | P2 slice | L2: a closure fully in the answer gives 0 archive downloads before the pick ends | R-AL2 R-AL8 R-AP28 |
| 6 | Slice 010 Q16: mark it answered by R-AL9. Retag the L0 `closure` rows of the 5 `Mvs` failures with R-AL9 | `docs/slices/010-closure-list.md`, `tests/unit/closure.roc` (test agent) | none new | R-AL9 |
| 7 | `scripts/rules.sh` reads the new group range R-AL1 to R-AL9 | DESIGN.md group table (E3) | `MISSING=1 scripts/rules.sh R-AL` lists R-AL8, R-AL9 until rows 1 to 3 land | |

Rows 1 to 3 are P0 work. Rows 4 and 5 wait for P2.

## 7. Questions for the human (TW17)

| # | Question | Proposal |
| --- | --- | --- |
| Q1 | With a registry, should `tln list` (no resolve) send the closure query to save the archive downloads on a fresh clone, instead of R-DI1 "no index call"? | No. The build needs the archives anyway, the archives are what roc builds, and one rule for both modes is simpler (E6). |
