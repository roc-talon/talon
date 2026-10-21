# G-tie-names: how a user names a package

Status: proposal for the human review. No design file, code or test is changed by this file.

## 1. The gap

| Rule | File, section | What it says | Problem |
| --- | --- | --- | --- |
| R-SC14 | CLI 2 | On a tie, list the full names, then `Use the full name.` | With 2 series of one repo in the scope (R-C8), the full name matches both. The user must add the series. Slice 011 Q27 prints `acme/text@1` in the list, but the text still says "full name". |
| R-SC14 | CLI 2 | Example note `via web-utils` | Not a valid alias (R-AD16: `-` is not allowed). The note is a header alias, so it is `web_utils`. |
| R-SC15 | CLI 2 | "Then the series is part of the name: `roc-lang/http@2`" | Silent on: which forms take the series (full name only, or also a short name `text@1`), what scope "then" is, and how `@2` as a name part differs from `@2` as a selector (R-SL4) in `update X@sel` (R-SP5). Slice 004 Q11 and Q12 decided part of it. The design does not hold those answers. |
| R-SC1 | CLI 2 | One scope "header entries and the closure" for `update`, `upgrade`, `remove`, `why`, `patch`, `probe` | `update`, `remove`, `patch`, `probe` act on header entries only (R-SP3, R-RV1, R-PA1, R-PB1). Only `why` needs the closure. The code already uses 2 different sets. |
| R-SC6 | CLI 2 | A header alias is exact | Silent on path entries and foreign URLs (R-H4, R-H7): they have no full name, so the alias is their only name. A transitive path entry has no name. |
| R-WS8 | Design 4.4 | A workspace alias tie "lists the full names" | A third tie text. The code (`cli/lib/Vars.roc:244`) always adds `@series`, also when the repos differ. |
| R-AU8 | CLI 1 | Fix text `tln why <name>` | Which name, when 2 series of the repo are in the closure? |

What the P0 code does today (3 entity builders, 3 behaviors):

| Place | Entity name | Series pick | Note in tie list |
| --- | --- | --- | --- |
| `cli/lib/Why.roc:63-76` (`why`) | `name@series` when 2 closure rows share a repo | Selector series, full name only | `platform`, `direct`, `via` |
| `cli/lib/PickFlow.roc:266-279` (`add`, `update`) | `name@series` when 2 variables share a repo | Same | `platform (<alias>)`, else empty |
| `cli/lib/RemoveFlow.roc:114-125` (`remove`) | Plain name, never `@series` | Never matches (bug: `tln remove roc-lang/http@2` with 2 entries is always a tie) | `platform (<alias>)`, else empty |
| `cli/lib/Lookup.roc:136-148` | The pick compares `"${ref.name}@${series}"` | A short name with a series (`text@1`) is always a tie | |
| `cli/lib/Lookup.roc:116-125` | One match is used, the selector is not checked | `tln remove json@3` removes the series-2 entry | |

How other tools do it:

| Tool | Rule | Ambiguity |
| --- | --- | --- |
| cargo | Package id spec: `name`, `name@version` (partial version allowed), `url#name@version` | Error that lists the specs to type: `foo@0.1.0`, `foo@0.2.0` |
| Go modules | Major 2 and up is part of the module path (`/v2`) | Not possible: 2 majors are 2 names |
| npm, bun | `npm why x`, `npm ls x` show all copies; `npm update x` changes all | No tie for queries |
| uv | One version per name in the lock | None |

## 2. Options

| # | Option | P0 cost | P1 and later | Users |
| --- | --- | --- | --- | --- |
| A | Text fix only: "Use the full name, with the series when 2 series match." Fix the alias. | 1 text in `Lookup.roc`, 4 test files | The 3 builders stay different. The `remove` bug and `text@1` tie stay. Each new command (`patch`, `probe`, `outdated`) adds a fourth variant. | 2 texts for 1 situation. `remove` fails where `why` works. |
| B | One name model (cargo spec plus the Go major rule): a scope gives each package one unique printed name; `X@sel` filters by version or series in every form; the tie says "use a name from the list". | One shared entity builder, a `series` and `version` field in the entity, the pick rule, 2 texts. Tests: 4 L0 files, 1 L3 expect, new L0 rows. | The registry adds a source of matches (R-AD34), not a new rule. `patch`, `probe`, `outdated`, `audit` reuse the builder. | What Talon prints is what the user types. One text. |
| C | Always print and require the series: `roc-lang/http@2` in every list and every tie, also with one series. | As B, plus each `list`, `why`, R-C8 and tie text changes | Stable names, but `@0.25` moves at each upgrade, so scripts break more often | Noise in the common case (one series). |
| D | npm style for queries: `why` shows all matches, no tie; ties only in commands that write | As B for writers, new output for `why` | 2 rules for one name | `tln why text` is easier; `tln remove text` still needs the tie |

## 3. Decision

Option B. Reasons:

| Reason | Detail |
| --- | --- |
| One rule | Each command that takes a name uses one builder and one pick. The tie list and the R-WS8 list are the same block. |
| Printed name is typed name | Every name in a tie list names exactly one package in that scope, so "use a name from the list" is always correct. Q27 is closed with no case split. |
| Cheap common case | The series appears only when the scope has 2 or more series of one repo (Option C rejected). |
| Matches prior art | The series as a name part is the Go `/v2` rule. `X@sel` as a version filter in a command that does not move is the cargo spec rule. |
| No registry dependency | The rule works on the entities of the scope. The registry (R-AD34) only gives the match set of a short name in `add`. |
| Scope per command | Commands that act on header entries look only at header entries, as `cargo remove` reads the manifest and `cargo update -p` reads the lock. `tln remove roc-lang/http` works when the header has 1 series, also when the closure has 2. |

The 2 roles of `X@sel` (the series rule of R-SC15 and the target rule of R-SP5) are separated by the command:

| Command kind | `X@sel` means | 1 match | 2 or more matches |
| --- | --- | --- | --- |
| Does not move (`why`, `remove`, `patch`, `probe`) | The packages whose version is in `sel` (R-SL4: `@2` is `^2`) | Must be in `sel`, else `'<x>' is not in the project` | Keep those in `sel`. 1 left: used. Else a tie. |
| Moves (`update`, `add` of a header entry, R-AD22) | The target (R-SP5) | Used. `sel` can name a new series. | Keep those in the series of `sel`. 1 left: used. Else a tie, and the text asks for the alias of the entry to move. |

## 4. Design edits

E1. DESIGN-CLI.md, R-SC1 (row). Old:

> `| R-SC1 | \`tln update\`, \`upgrade\`, \`remove\`, \`why\`, \`patch\`, \`probe\` | Project: header entries and the closure. In \`tln update X@sel\`, Talon finds X in the project and the releases that match \`sel\` in the registry. \`tln probe\` with no name probes the project file itself, and a path to a bundle file probes that bundle (Resolution 4, R-PB1). |`

New:

> `| R-SC1 | \`tln update\`, \`upgrade\`, \`remove\`, \`why\`, \`patch\`, \`probe\` | Project. \`tln why\`: the packages of the closure. The other commands: the header entries of the members (Design 4.4, R-WS8). A transitive package is not a name there. In \`tln update X@sel\`, Talon finds X in the project and the releases that match \`sel\` in the registry. \`tln probe\` with no name probes the project file itself, and a path to a bundle file probes that bundle (Resolution 4, R-PB1). \`tln list\` takes no name (R-CM9). |`

E2. DESIGN-CLI.md, R-SC6 (row). Old:

> `| R-SC6 | 1 | Header alias | \`pf\` | Exact. An alias is unique in a header. |`

New:

> `| R-SC6 | 1 | Header alias | \`pf\` | Exact. An alias is unique in a header. A path entry and a foreign URL (Design 4.2, R-H4) have no full name: the alias is their only name. A path entry or foreign URL of a package header has no name; \`tln why\` of the package that needs it shows it. |`

E3. DESIGN-CLI.md, R-SC14. Old (the paragraph and its code block):

> `R-SC14: On a tie, Talon stops and lists the full names:` then the block with `error: "basic-webserver" matches 2 packages:`, `roc-lang/basic-webserver      platform (pf)`, `someone/basic-webserver       via web-utils`, `Use the full name.`

New:

> `R-SC14: On a tie, Talon stops with exit code 2 (R-EC2). It lists each match by its name in the scope (R-SC15), with a note: \`platform (<alias>)\`, \`direct (<alias>)\`, or \`via <alias>\` (the header alias of the entry that needs the package). Each name in the list names one package, so the user types one of them, or the alias of a direct match. The same list reports an alias that names 2 groups in a workspace (Design 4.4, R-WS8). In a command that moves an entry (R-SC16), when no match has the series of the selector, the last line asks for the alias of the entry to move. The texts are a proposal (R-OUT2).`
>
> ```text
> "basic-webserver" matches 2 packages:
>   roc-lang/basic-webserver      platform (pf)
>   someone/basic-webserver       via web_utils
> tln: error[usage]: "basic-webserver" matches 2 packages. Use a name from the list.
>
> "roc-lang/http" matches 2 packages:
>   roc-lang/http@1      direct (http1)
>   roc-lang/http@2      direct (http2)
> tln: error[usage]: "roc-lang/http" matches 2 packages. Use the alias of the entry to move: tln update http1@3
> ```

(The second block is the output of `tln update roc-lang/http@3`.)

E4. DESIGN-CLI.md, R-SC15. Old:

> `R-SC15: The group includes the series (Design 2, 4.1), so one closure can hold \`roc-lang/http\` 1.x and 2.x. Then the series is part of the name: \`roc-lang/http@2\`, \`roc-lang/basic-cli@0.25\`.`

New:

> `R-SC15: The group includes the series (Design 2, 4.1), so one closure can hold \`roc-lang/http\` 1.x and 2.x. The name of a package in a scope (R-SC1 to R-SC5) is its full name (R-SC7). When the scope has 2 or more series of one full name, the name of each of them adds its series in the ref form (R-SL1): \`roc-lang/http@1\`, \`roc-lang/http@2\`, \`roc-lang/basic-cli@0.25\`. This is the Go rule of the major in the module path (\`/v2\`). Talon prints this name wherever it tells the user what to type: the tie list (R-SC14), and the fix texts (R-AU8). The \`--json\` field \`name\` stays the full name, next to \`version\`.`

E5. DESIGN-CLI.md, new paragraph after R-SC15 (id R-SC16 is free: `grep -rn "R-SC1[6-9]"` finds nothing):

> `R-SC16: A selector after a name (\`X@sel\`) narrows the matches of each form (R-SC6 to R-SC8), as a cargo package id spec does. A command that does not move an entry (\`why\`, \`remove\`, \`patch\`, \`probe\`) keeps the matches whose version is in \`sel\` (R-SL4: \`@2\` is \`^2\`). No match left is \`'<x>' is not in the project\`. A path entry has no version, so it never matches a name with a selector. A command that moves an entry (\`update X@sel\`, and \`add X@sel\` of a header entry, R-AD22) reads \`sel\` as the target (Resolution 9, R-SP5). With one match it uses that match, also for a new series. With 2 or more matches, it keeps the matches in the series of \`sel\`. A selector with no single series (\`latest\`, \`0.x\`, \`*\`) keeps all matches. So \`text@1\`, \`acme/text@1\` and \`acme/text@^1.2\` all name series 1, and \`tln update http1@3\` moves one of 2 entries to series 3.`

E6. DESIGN.md, Design 4.4, R-WS8. Old:

> `A command that takes names stops with exit code 2 and lists the full names. |`

New:

> `A command that takes names stops with exit code 2 and lists the groups as in the tie of CLI 2, R-SC14. |`

E7. DESIGN.md, rule index (line 302). Old: `| R-SL1 to R-SL15, R-SC1 to R-SC15 |` New: `| R-SL1 to R-SL15, R-SC1 to R-SC16 |`

E8. DESIGN-CLI.md, R-AU8. Old: `For a transitive entry: update the package that needs it (\`tln why <name>\`)` New: `For a transitive entry: update the package that needs it (\`tln why <name>\`, with the name of R-SC15)`

## 5. Work that follows

New slice (013, "one name model"). Test agent first (TW18), then code agent.

| Item | Change | Rules |
| --- | --- | --- |
| `cli/lib/Lookup.roc` | Entity gets `series : Str` and `version : Try(Str, [None])`. The pick of R-SC16 compares fields, not `"${name}@${series}"`. A new parameter says if the command moves. One shared function prints the names of R-SC15 over the whole scope (not only the matches). New tie texts. Doc text `via web-utils` becomes `via web_utils`. | R-SC14 to R-SC16 |
| One entity builder | Replaces `Why.entities`, `PickFlow.entities_of` and the builder in `RemoveFlow.removal_plans!`. Notes `direct (<alias>)` in all 3. | R-SC1, R-SC14 |
| `cli/lib/Vars.roc:244` | R-WS8 uses the R-SC14 block and line. | R-WS8 |
| `tests/unit/lookup.roc` | Entity records with the new fields; rows: `text@1` (short name with series), `json@3` with one match in a non-moving scope (not in the project), `http@3` with one match in a moving scope (used), `roc-lang/http@3` with 2 matches (alias text) | R-SC14 to R-SC16 |
| `tests/unit/why.roc`, `tests/unit/vars.roc` | New texts; `acme/text@2.0.0` picks, `acme/text@2.5.0` is not in the project | R-SC14, R-SC16, R-WS8 |
| `tests/scenarios/why/wy1-why/expect/stderr` | New tie line | R-SC14 |
| New L2 run in `remove/rm1-flow` | 2 header entries of one repo: `tln remove roc-lang/http@2` removes the series-2 entry (red today) | R-SC16, R-RV1 |

Revert check: each new row must fail with the old `Lookup.pick` and with the old `RemoveFlow` builder.

## 6. Questions for the human (TW17)

| # | Question | Proposal |
| --- | --- | --- |
| Q1 | In a command that does not move, R-SC16 reads `sel` as a version filter (`tln why json@2.0.0` with 2.1.0 in the closure: not in the project). Accept this, or read only the series of `sel` (2.1.0 is found)? | Version filter (cargo). It never shows a package that the user did not name. |
| Q2 | The tie text of a moving command names `tln update <alias>@<sel>` with the first direct match. Accept, or a text with no example? | Accept (R-OUT2 proposal). |
