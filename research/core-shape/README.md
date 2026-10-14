# core-shape: can a Talon command be data that a shell runs?

Question: can the logic of a complex command (`tln upgrade`) be a pure value that a small interpreter runs? Can `roc test` test it with no files, processes or network?

| File | Content |
| --- | --- |
| `Inject.roc` | The other shape: direct-style logic that gets its effects as a record of functions (`{ read! }`) |
| `InjectExpect.roc` | `Inject` with a pure fake in an `expect` |
| `inject_test.roc` | `Inject` with a fake, in a compiled basic-cli test app |
| `fz/` | `Inject` with a fake, in a roc-fuzz target (a copy of `Inject.roc`, because a target imports from its own dir) |
| `Program.roc` | `Program(a)`: a command plus a continuation (`Read`, `Write`, `Probes` (a round), `Ask`, `Done`), `then`, and a pure interpreter `run_fake` |
| `Upgrade.roc` | A small model of `upgrade`: read the header, ask before a download, probe in rounds of 2 (PP3), write the first pass. 2 `expect`s. |
| `Deep.roc` | 100,000 rounds, as direct recursion and through `then` |
| `shell.roc` | The real interpreter on basic-cli 0.29.0: `Read` and `Write` are real file effects |

Run (nightly `2026-10-09`): `roc test InjectExpect.roc` (fails, see below), `roc build inject_test.roc && ./inject_test`, `cd fz && roc build --fuzz main.roc && ./main run --runs=50000`, `roc test Upgrade.roc`, `roc test Deep.roc`, `roc build shell.roc && ./shell` (needs a file `f`).

## Result (2026-10-15)

| Check | Result |
| --- | --- |
| Effects as a record, pure fake, in `expect` | Not possible. `roc test`: "This expect performs an effect while evaluating its condition." A function with `!` cannot run in an `expect`, also when its argument is pure. |
| Effects as a record, fake, in a compiled basic-cli test app | Works (`pass`) |
| Effects as a record, fake, in a roc-fuzz target | Works. 50,000 inputs pass. Revert check: a wrong property fails. |
| A fake that records calls or writes | Not possible in memory: a lambda cannot change a `var` that it captured (a rule of the language reference, not tested here). The fake must write to a real place (a file on tmpfs in a basic-cli test app). roc-fuzz has no such place. |
| Recursive `Program(a)` with closures in the tags | Compiles. `then` and `run_fake` work. |
| `Upgrade.roc` | 2 of 2 pass. Revert check: rounds of 3 in place of 2 make the log test fail. |
| 100,000 rounds in `roc test` | Pass, 66 to 77 ms, both shapes |
| 100,000 rounds in the compiled shell, with a real file read each round | Pass, both shapes: 200,000 reads in 0.31 s. No stack overflow. |

## Conclusion

Both shapes are testable. A Program is testable with `roc test`, and its writes and call log are data. Direct style with an effect record is testable in a compiled test app or a fuzz target, but a fake can see writes and calls only through a real file.

Decision (2026-10-15): Talon uses direct style with an `Fx` record (`TESTING.md` 2). `Program` is dropped: it is harder to read, and it needs a second interpreter. Its files stay here as the record of the test.
