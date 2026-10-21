# Brief: close one design gap

You decide how to close one gap in the Talon design. The spec is `DESIGN.md` and the files it lists (`DESIGN-CLI.md`, `DESIGN-RESOLUTION.md`, `DESIGN-REGISTRY.md`). `TESTING.md` is the test method. The P0 implementation is in `cli/` and `tests/`, and the slice files in `docs/slices/` record each decision and question.

## Goal

The cleanest design for the long term: P0, P1 and later phases, with the registry and without it. It is not the shortest path to finish P0. If the cleanest design needs more P0 work, say so. If the gap shows that an existing rule is wrong, say so and change it.

## Limits

| Do | Do not |
| --- | --- |
| Read the design, the slice files, the code and the tests | Edit a design file, code or a test |
| Write one file: `docs/design-gaps/<your gap id>.md` | Commit, or touch `cloudflare-workers/` (read it only if the registry needs it) |
| Look at how other package managers solve the same problem (cargo, npm, bun, Go modules, uv), from what you know | Run long builds or tests |

## The file you write

1. The gap: the rules involved, with ids and file sections, and why they conflict or are silent.
2. Options (2 to 4), each with its cost in P0, its effect on P1 and later, and its effect on users.
3. The decision, and why it is the cleanest in the long term.
4. The design edits: for each, the file, the rule id, the exact old text and the exact new text. Reuse rule ids where a rule changes. New rules get new ids in the same group (check that the id is free with `grep`).
5. The work that follows: the code and tests to change, and the slice (an existing slice number, or "new slice").
6. Questions that only the human can answer, if any (TW17). Keep them few.

Style: ASD-STE100 Simplified Technical English, tables over text, no em-dashes, no bold or stars. Under 200 lines.

Final reply to the manager: under 25 lines, with the decision, the rule ids that change, the work that follows, and any questions.
