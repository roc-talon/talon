# Smoke app: does a platform build for a target? (Q42, Resolution 4, R-SM1 to R-SM5)

Question: can Talon make one small app from a platform header alone, so that `roc build` of it tells whether (platform hash, nightly, target) builds, with no code of the user?

Answer: yes. The app gives the platform each value of its `requires` clause, with function bodies that only `crash`. On 34 targets of 6 platforms, its build gives the same result as a real app of that platform, and the same first error line.

## Run

| Command | What it does |
| --- | --- |
| `python3 -I gen.py <platform main.roc> <platform URL>` | Prints the smoke app of that platform |
| `./run.sh` | Makes the app of each platform of `conformance/host-link/` and builds it for each target in the platform `targets/` dir. It prints the result next to the result of the real app in `conformance/host-link/results.tsv`. |

`run.sh` uses the compilers in `conformance/host-link/bin/` and the packages in its cache. The binaries go to `out/` (about 37 MB, not for VCS). The cache path must be canonical: with `..` in it, each build fails with `PathOutsideWorkspace` (the first run here hit this, Design Q15).

## Generated apps

| Platform | `requires` | App |
| --- | --- | --- |
| basic-cli 0.25.0, 0.29.0 | `main! : List([...]) => Try({}, [Exit(I32), ..])` | `main! = \|_\| crash "talon smoke test"` |
| roc-platform-template-zig 1.0.0 | `requires {} { main! : List(Str) => ... }` | The same |
| basic-webserver 0.17.0 | `[Context : context] for program : { init! : () => ..., respond! : a, b => ..., shutdown! : a, b => ... }` | `Context : {}`, `program = { init!: \|\| crash ..., respond!: \|_, _\| crash ..., shutdown!: \|_, _\| crash ... }` |
| roc-ray 0.10.0 | `[Model : model, Msg : msg] for program : { init! : { config : ..., run! : ... }, update! : 3 args, render! : 2 args }` | `Model : {}`, `Msg : {}`, a nested record of lambdas |

## Results (2026-10-16, Linux x86_64)

`results.tsv` has each row. Summary:

| Platform | Nightly | Smoke build ok | Smoke build fails | Same as the real app |
| --- | --- | --- | --- | --- |
| basic-cli 0.29.0, 0.25.0 | 10-12 | `x64musl`, `arm64musl` | `arm64mac`, `x64mac` (`-lSystem` not found), `x64win` (`mainCRTStartup`) | 10 of 10 |
| template-zig 1.0.0 | 10-12 | `x64musl`, `arm64musl` | mac, win | 6 of 6 |
| template `ABFg` | 10-12 | 4 musl targets | mac, win | 8 of 8 |
| basic-webserver 0.17.0 | 10-06 | `x64musl`, `arm64musl`, `x64mac`, `arm64mac` | `x64win` (`WindowsSDKNotFound`) | 5 of 5 |
| roc-ray 0.10.0 | 10-06 | `x64v1glibc`, `x64mac`, `arm64mac` | `x64win` (`WindowsSDKNotFound`) | 5 of 5 |

Cost of one build, warm cache: 0.11 to 0.40 s, 150 to 220 MB peak memory (`/usr/bin/time`).

## Findings

| Finding | Effect on the design |
| --- | --- |
| Each build ran on one Linux machine, also for macOS and Windows targets. roc links with its own linker and the files of the platform (the `platforms` topic of the Roc reference). | A smoke result does not depend on the machine, except where roc looks outside the platform: `WindowsSDKNotFound` on 10-06. So one Linux runner can build each target: the compat bot does (Design Q43, Registry R-MX10). |
| A top-level constant that only crashes would crash at compile time | The generator makes no app when a required value is not a function or a record (R-SM2) |
| The smoke app compiles no code of the user, and only the platform code that the host calls | It finds a missing or broken host file, a link error, and a compile error in that code. It does not find a code generation bug in a function that only an app calls. |

## What this does not prove

| Item | Status |
| --- | --- |
| A real macOS or Windows machine | Not tested. The result of `x64win` on a Windows machine with an SDK can differ from Linux: R-SM7 treats `WindowsSDKNotFound` as a machine error. |
| Other `requires` forms | Only the 4 forms above. A `requires` form that the generator does not know gives no smoke build, not a wrong one. |
| The generator in Roc | Not written. `gen.py` is the prototype of R-SM2. |
