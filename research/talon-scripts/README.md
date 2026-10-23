# Talon scripts, the build target, and a Workers setup with no npm

Date: 2026-10-23. Design study. No change to `DESIGN*.md`, `cli/`, `tests/` or `docs/`. Each rule below is marked PROPOSED. It is input for the human review, not part of the spec.

Goal: a Roc Cloudflare Workers project that has no `package.json` and no `npm install`, with features of the first Talon version. The previous check is `cloudflare-workers/research/talon-fit/README.md` (gaps G1 to G7). The platform transition note is `cloudflare-workers/research/talon-fit/TRANSITION.md`.

Sources, as in the working tree on this date. A path such as `CLI R-T2` is the rule id in `DESIGN-CLI.md`.

| Short name | File |
| --- | --- |
| Design | `DESIGN.md` |
| CLI | `DESIGN-CLI.md` |
| Resolution | `DESIGN-RESOLUTION.md` |
| Registry | `DESIGN-REGISTRY.md` |
| Platform | `cloudflare-workers/` (`js/cli.mjs`, `js/runner.js`, `scripts/bundle.sh`, `examples/`) |

## 1. Summary

| # | Decision or proposal | Status | Section |
| --- | --- | --- | --- |
| 1 | The helper CLI is a separate tool | User decision (fixed) | 6 |
| 2 | `tln run <name>`: a list of commands in `[scripts]` of `talon.toml`. No shell. Explicit call only | PROPOSED, phase P1 | 3 |
| 3 | No hooks. Talon never runs a script by itself, and never runs code of a dependency | PROPOSED | 4 |
| 4 | A `.roc` script is an ordinary app that names its own platform (usually basic-cli). No Talon script platform | PROPOSED | 5 |
| 5 | G1: the build target of a project comes from the platform `targets`, or from `[build] target` | PROPOSED, phase P0 (ladder step 3 runs in P0, R-PH9) | 7 |
| 6 | The JS shim and the version-specific part of `sync` go into the platform bundle. So the hash of the header pins them, and G5 (two pins) goes away | PROPOSED (platform side) | 6, 8 |
| 7 | `tln path <alias>`: print the directory of a header entry. Read-only | PROPOSED, phase P1 | 8 |
| 8 | The helper copies the shim to the project directory `.roc-cfw/`. `worker.js` imports it with a relative path | PROPOSED (platform side). Tested: Wrangler bundles it | 8, 9 |
| 9 | Node and Wrangler stay external prerequisites, as `git` and `curl` are | Fact | 10 |

```mermaid
flowchart LR
    TT["talon.toml<br/>[scripts], [build] target"] --> RUN["tln run build"]
    RUN --> ROC["roc build --target=wasm32<br/>(the proxy)"]
    RUN --> CFW["roc-cfw sync<br/>(separate tool, Roc)"]
    HDR["main.roc header<br/>pf: URL + hash"] --> PATH["tln path pf"]
    PATH --> PKG["packages/&lt;hash&gt;/js/<br/>shim + sync.mjs"]
    CFW --> PATH
    PKG -- copy --> V[".roc-cfw/<br/>(gitignored)"]
    CFW -- "node .roc-cfw/cli.mjs sync" --> W["worker.js<br/>wrangler.toml check"]
    V --> WR["wrangler dev / deploy<br/>(external, Node)"]
    W --> WR
    ROC --> WASM["app.wasm"] --> WR
```

## 2. Use cases with no npm

| # | Use case | How, with this proposal | New Talon part |
| --- | --- | --- | --- |
| U1 | Install and pin the platform and the nightly | `tln add --platform Karakatiza666/roc-cloudflare-workers` (R-AD29 to R-AD31). The ladder builds for `wasm32` | G1 (R-TG1 to R-TG6) |
| U2 | Build `--target=wasm32 --no-cache --output=app.wasm` | A step of a script: `roc build --target=wasm32 --no-cache --output=app.wasm main.roc`. `roc` is the proxy (R-PX2) | `tln run` |
| U3 | `sync` after the build, `sync --check` in CI | Script steps `roc-cfw sync` and `roc-cfw sync --check` | `tln run` |
| U4 | Several Workers in one repository, `sync` reads the wasm of another Worker | One script lists all builds first, then each `sync`. Cross-directory steps use `{ in = "<dir>", run = "..." }` (R-RUN8). `tln run --each` runs a name in each member directory | `tln run` |
| U5 | The shim JS where Wrangler can bundle it, at the platform version | The shim is in the platform bundle. `roc-cfw` copies it from `tln path pf` to `.roc-cfw/` | `tln path` |
| U6 | `init` of a new project from a template | `tln init --platform Karakatiza666/roc-cloudflare-workers` (main.roc, nightly, CI), then `roc-cfw init` (wrangler.toml, talon.toml, .gitignore, the app body) | R-IN8 (template text, question Q-S5) |
| U7 | Get, version and pin the helper CLI | `tln tool install Karakatiza666/roc-cloudflare-workers-cli`. The helper is thin and version-independent. The version-specific part is in the platform bundle | None (CLI 6.4 as it is) |

## 3. `tln run` and `[scripts]`

### 3.1 Syntax

```toml
[scripts]
build = [
  "roc build --target=wasm32 --no-cache --output=app.wasm main.roc",
  "roc-cfw sync",
]
check = ["@build-wasm", "roc-cfw sync --check"]
build-wasm = "roc build --target=wasm32 --no-cache --output=app.wasm main.roc"
dev = ["@build", "wrangler dev --local"]
deploy = ["@check", "wrangler deploy"]
release-notes = "scripts/notes.roc --since v0.3.0"     # a .roc script (R-RUN6)
all = [
  { in = "workers/ledger", run = "@build" },             # another directory (R-RUN9)
  { in = "workers/web", run = "@build" },
]
```

| # | Rule (PROPOSED) |
| --- | --- |
| R-RUN1 | `[scripts]` is a table of `talon.toml`. A key is a script name: `[a-z0-9][a-z0-9:_-]*`, at most 64 characters. A value is a step, or an array of steps. A step is a string (a command line, or `@<name>`), or an inline table `{ in = "<dir>", run = "<step string>" }`. Another form gives exit code 19 (`input`, CLI 3). |
| R-RUN2 | Talon splits a command line into words. A space or a tab separates two words. `"..."` and `'...'` quote a word, with the escapes `\"` and `\\` in `"..."` only. Talon does no expansion: no `$VAR`, no `~`, no glob, no command substitution. An unquoted word that is `\|`, `&&`, `\|\|`, `;`, `>`, `>>`, `<`, `&`, or a word that starts with `$(` or a backquote, gives exit code 19. The message names the step and says: "a step is one command; use 2 steps, or a .roc script". Reason: the same text runs on Linux, macOS and Windows (section 11, row A3). |
| R-RUN3 | The first word is the program. Talon finds it in `PATH` of the environment of `tln run`, as `Cmd` does. Talon adds no directory to `PATH`. Exception: the words `roc` and `tln` run the `tln` binary that runs `tln run` (proxy mode for `roc`, R-PX1). Reason: the step gets the compiler that Talon selects (Resolution 13), also when `tln setup` did not run. |
| R-RUN4 | A step `@<name>` runs the script `<name>` of the same `talon.toml`, with all its steps. A name that the file does not have gives exit code 19. A cycle (`a` runs `b`, `b` runs `a`) gives exit code 19 before the first step runs. |
| R-RUN5 | `tln run <name>` runs the steps in order. Each step runs as a child with inherited stdin, stdout and stderr (Design R-HF6: a child, not `execve`, because more steps can follow). The next step starts only when the step before it exits with 0. |
| R-RUN6 | A first word that ends with `.roc` is a Roc script: Talon runs `roc <file> -- <other words>` through the proxy (rule R-RUN3). The file is relative to the working directory of the step (R-RUN8). Its header names its own platform (section 5). |
| R-RUN7 | Exit code: the exit code of the first step that fails, else 0 (R-E1). A step that a signal stops gives 128 + the signal number. When Talon itself fails before or between steps (a bad table, a missing program, a cycle), it uses its own codes with the line `tln: error[<kind>]: ...` (R-E4). A program that is not in `PATH` gives exit code 18 (`environment`), and the message names the program and the step. |
| R-RUN8 | The working directory of each step is the directory of the `talon.toml` that holds the script. A step `{ in = "<dir>", run = ... }` runs in `<dir>`, relative to that directory. `<dir>` must be inside the repository (the stop directory of R-PD2); else exit code 19. An `@<name>` step in an `in` table runs the script of the `talon.toml` in `<dir>`; that file must exist and have the name, else exit code 19. |
| R-RUN9 | Environment: the environment of `tln run`, plus `TALON_SCRIPT` (the name of the script that the user named) and `TALON_SCRIPT_DIR` (the absolute working directory of the step). Talon reads no `.env` file and sets no other variable. |
| R-RUN10 | `tln run <name> -- <args>` adds `<args>` as words to the end of the last step. When the last step is `@<name>`, the rule applies to that script. With no `--`, a word after the name gives exit code 2. |
| R-RUN11 | `tln run` with no name prints each script of the `talon.toml` that R-RUN12 finds, with its steps. With `--json`, `data` is `{ file, scripts: [{ name, steps: [...] }] }` (proposal, R-OUT2). `tln run <name> --json` gives exit code 2, as `tln x` (R-FL1): the steps write to stdout. |
| R-RUN12 | Which `talon.toml`: Talon walks up from the current directory as in R-PD2, and stops at the workspace root (R-PD3) when there is one. The first `talon.toml` on the walk that has the name in `[scripts]` holds the script. With none, exit code 2. The message lists the files that the walk checked. `--file` is not a flag of `run` (R-FL12): a script is not for one project file. |
| R-RUN13 | `tln run --each <name>` runs the script in each directory of the workspace whose `talon.toml` has the name, except the root file. The order is the byte order of the directory paths, relative to the root. Talon runs one directory at a time. It stops at the first failure, unless `--keep-going`: then it runs each directory and exits with the code of the first failure. It prints one line for each directory before its steps. With no workspace, exit code 2. Order between directories that need each other is a root script with `in` steps (R-RUN8): Talon finds no order by itself. |
| R-RUN14 | `[scripts]` is allowed in the root `talon.toml` and in each other `talon.toml` of a workspace (a change of Design R-WS5, which lists the tables of each file). Talon never reads `[scripts]` of a `talon.toml` in a package archive (R-I1). |
| R-RUN15 | No other command runs a script. `install`, `add`, `update`, `upgrade`, `remove`, `init`, `tool install`, `x`, the proxy and the probes never read `[scripts]` (section 4). |
| R-RUN16 | `tln run` uses no resolve flag (R-FL7), and does not resolve, fetch or write a project file. A step can be `tln install --frozen` when a script needs it. |
| R-RUN17 | Names of Talon commands are not script names: `tln build` is not `tln run build`. Reason: a new Talon command can never change what an old script name does (section 11, row A7). |

### 3.2 Flow

```text
tln run build -- --verbose
  |
  v
find the talon.toml (R-RUN12) ---- none ----> exit 2
  |
  v
parse [scripts], expand @names, check cycles and words (R-RUN1, R-RUN2, R-RUN4) ---- bad ----> exit 19
  |
  v
for each step, in order (R-RUN5):
   cwd = dir of the file, or `in` (R-RUN8)
   program = roc|tln -> this tln; *.roc -> roc <file> --; else PATH (R-RUN3, R-RUN6) ---- not found ----> exit 18
   run as a child, inherited stdio
   exit != 0 ----> stop, exit with that code (R-RUN7)
  |
  v
exit 0
```

### 3.3 What `tln run` is not

| Feature of other runners | In `tln run` | Reason |
| --- | --- | --- |
| A shell (`sh -c`, `cmd /c`) | No (R-RUN2). A user who wants a shell writes `sh -c "..."` as a step, which shows that the step is not portable | Portable text, no quoting bugs, no injection through `-- <args>` |
| `node_modules/.bin` on `PATH` | No (R-RUN3) | No shadowing of a system program by a dependency |
| Implicit `pre<name>` and `post<name>` | No (section 4) | Explicit steps (`@name`) say the same with no hidden order |
| File dependencies, caching, parallel tasks (make, just, turbo) | No | Design N2 and "Left to others": Talon is not a build system. `make` and `just` stay usable as a step |
| `tln <script>` with no `run` | No (R-RUN17) | A name collision with a future command |
| `.env` loading | No (R-RUN9) | Secrets in files that tools read by themselves |

## 4. Hooks

| Hook kind | In npm, Bun, pnpm, Cargo | Talon v1 | Reason |
| --- | --- | --- | --- |
| Install scripts of a dependency (`preinstall`, `install`, `postinstall`) | npm runs them by default. Bun and pnpm (v10) run them only for packages on an allow list. Cargo `build.rs` runs at build | Never. A package has no way to declare code for Talon to run | Supply-chain attacks use them first. Talon runs no package output (Design R-SE4). A Roc package needs no build step: `roc` compiles it as part of the app |
| Install scripts of the project (`postinstall` in the root) | npm runs them on `npm install` | No | `tln install --frozen` in CI must be a pure fetch. A hook makes the result of `install` depend on the machine. The user adds a script and calls it |
| `pre<name>` and `post<name>` of the project | npm runs them around `npm run <name>` | No | Hidden order. An explicit `@name` step does the same (R-RUN4) |
| A hook on `roc build` (the proxy) | None | No | The proxy passes each command with no change (R-PX3) and has a cost target of 5 ms (R-PX2) |
| A hook after `tln add` or `tln update` (for example `sync` after a platform change) | None | No. The summary of `tln add --platform` and `tln update` already prints a notice when the platform changes (R-SE7). The text of that notice can name `tln run` when the project has `[scripts]` (an output proposal, R-OUT2) | A command that changes the header must not run project code by itself |
| Git hooks | husky (npm `prepare`) | Out of scope | Not a package manager job |

R-HK1 (PROPOSED): Talon runs a command of `[scripts]` only in `tln run`, only when the user names the script, and only from the `talon.toml` files of the project or workspace of the current directory (R-RUN12, R-RUN13). No other command, no package, and no file in the cache can make Talon run a program, except the programs of the design: `roc`, the tools that the user installs or names (CLI 6.4), and the child programs of Design 6.2 (`curl`, `tar`, and so on).

Trust: `tln run` in a cloned repository runs the commands of that repository. It is the same trust as `make` or `cargo build` in that repository. The user names the script, so no code runs on `git clone`, `tln install` or `tln add`.

## 5. The platform of a `.roc` script

A script needs files, processes, the environment and the exit code. Options:

| # | Option | Effects | Pin | Cost for Talon | Verdict |
| --- | --- | --- | --- | --- | --- |
| P1 | The app with no platform (`app [main!] {}`) | Probe `probes/no-platform/`: it runs, takes args and gives an exit code (`Err(Exit(3))` gives 3). It has no I/O: `Stdout.line!` "does not exist". Only `dbg` prints | None needed | None | Not enough for any script of this study (copy, spawn, read files) |
| P2 | A Talon-shipped platform for scripts | Any that Talon builds | A Talon release | Talon maintains, releases and tests a platform. The scripts break when Talon moves it. Scope: Talon becomes a platform owner (N2) | No |
| P3 | basic-cli inside `tln` (Talon gives a fixed basic-cli URL to each script) | basic-cli | Hidden: the URL is in the Talon binary, not in the project | An implicit dependency. A Talon update changes the platform of each script. A second lock outside the header (G1) | No |
| P4 | The script names its own platform in its header, as each Roc app does | What its platform has: basic-cli has files, `Cmd`, env, HTTP (R-PL1) | The header of the script: URL and hash, and `roc:` (G1) | None new. The script is a project file (R-PD8): `tln add`, `tln update` and the workspace rules work on it | Yes |

Recommendation: P4. A script is an ordinary app file. Put it in the workspace `members` so that one `tln update` moves its basic-cli, and so that it shares the nightly of the workspace (R-WS4, R-WS9). A member on basic-cli and a member on `cloudflare-workers` are 2 platform variables (R-WS9), so this is allowed. `roc <file>` builds with the dev backend and keeps the build in the roc cache, so a second run is fast.

## 6. The helper CLI as a separate tool

The user decided that the helper CLI is a separate tool. The open part is the language, and where the version-specific logic lives.

What `sync` needs (`js/cli.mjs`, `js/runner.js:401`):

| Part | Depends on the platform version? | Needs execution of the app? |
| --- | --- | --- |
| Read the manifest: `new WebAssembly.Instance`, `init`, `handle(Manifest)`, decode the reply (`manifestOf`) | Yes: event encoding, outcome decoding, the stack-first check | Yes. The manifest is the reply of the app to the `Manifest` event, made by Roc code at run time |
| Write `worker.js` (`entryOf`) | Yes: the names `makeHandler`, `objectClass`, `entrypointClass` | No |
| Check the Wrangler config (`checkConfig`): flags, `MIN_DATE`, binding kinds | Yes: `FLAGS`, `MIN_DATE`, `BINDING_KINDS` change with the platform | No |
| Parse TOML and JSONC | No | No |
| `init`: template files | Yes: the template is the example of that version | No |

Can a tool read the manifest with no execution? Not today. `roc build` has no step that runs app code or writes a custom wasm section, and the manifest comes from `Worker.new` values inside a handler. A static form needs (a) the compiler to fold the manifest into a constant that the host can export, or (b) a build hook in roc. Both are upstream changes (question Q-S7). A third way is a native host target of the platform that only answers `Manifest` (build the app twice). It removes Node from `sync`, but Wrangler still needs Node, so the gain is zero for the user and the platform cost is large.

Options for the helper:

| # | Option | Node needed | Version skew with the platform | Pin and integrity | Verdict |
| --- | --- | --- | --- | --- | --- |
| H1 | Today: npm tarball (shim + `cli.mjs`) | Yes | None (same tarball) | npm URL, second pin (G5) | Not allowed: npm |
| H2 | One `.mjs` file as a release asset, `curl` it, run with `node` | Yes | Possible | None (no hash, no tool) | No |
| H3 | Roc tool with all logic. It spawns `node` with JS that it carries | Yes | Yes: the tool must know each platform version | `tln tool` (hash of the app bundle) | No: each platform release needs a tool release |
| H4 | Roc tool, thin. The version-specific JS (shim, `cli.mjs sync`, template) is in the platform bundle. The tool copies it and runs `node .roc-cfw/cli.mjs` | Yes (already there for Wrangler) | None: the header hash pins the JS | Tool: `tln tool` (CLI 6.4). JS: the header hash | Yes |
| H5 | H4, and the platform gets a native target that answers `Manifest` | No for `sync`, yes for Wrangler | None | As H4 | Later, if ever |

Recommendation: H4. The tool (binary `roc-cfw`, repository `Karakatiza666/roc-cloudflare-workers-cli`) is a Roc app on basic-cli. Its own repository is necessary: a release has one `<hash>.tar.zst` asset (R-DI4), and the platform release already has its bundle; also one group cannot hold a `platform` and an `app` (R-C4).

| `roc-cfw` command | Does |
| --- | --- |
| `roc-cfw shim [--file <app.roc>]` | Reads the header of the app file (default: the project file of R-PD4, through `tln path`). Runs `tln path <platform alias>`. Copies `<dir>/js/` to `.roc-cfw/` next to the Wrangler config, with a stamp file that holds the platform hash. Writes nothing when the stamp is equal |
| `roc-cfw sync [args]` | `shim`, then `node .roc-cfw/cli.mjs sync [args]`. The exit code of `node` passes through |
| `roc-cfw init` | After `tln init --platform ...`: copies `<dir>/js/template/` (the app body, `wrangler.toml`, `talon.toml` with `[scripts]`, `.gitignore`). Writes over no file except a `main.roc` body that is still the stub of R-IN8 |
| Version check | `<dir>/js/cfw.json` has `{ "api": N }`. The tool knows the API numbers that it supports. An unknown `N` stops with a message that names `tln tool update roc-cfw`. `api` changes only when the contract between tool and bundle changes (file names, arguments), not on each platform release |

Pin of the tool: global, in `tools.json` (R-T4), as CLI 6.4 has it. The tool is thin and version-independent, so a project does not need its own pin. A CI job pins it with `tln tool install Karakatiza666/roc-cloudflare-workers-cli@=1.0.0`. A project pin (`[tools]` in `talon.toml`) is question Q-S4: it needs a second lock (a URL and hash outside the header) and offline rules for `tln x` (R-B3, R-B7), so it is not in this proposal.

## 7. G1: the target of a project build

Today R-LD5 builds "for the host target". The platform `cloudflare-workers` has only `wasm32` in `targets`, so step 3 fails on each machine, and Talon blames the platform (R-P4 stores the fail).

| # | Rule (PROPOSED) |
| --- | --- |
| R-TG1 | The build target of an app project file is the first of: (1) `target` in the `[build]` table of its `talon.toml` (R-PD6); (2) the host target, when the `targets` of the platform header has it. The host target is the target that `roc build` uses with no `--target`: the musl target of the host, else its glibc target (R-T8); (3) the one target of the platform, when its `targets` has exactly one. Else Talon stops with exit code 2. The message lists the targets of the platform and names `[build] target`. |
| R-TG2 | Ladder step 3 (R-LD5) runs `roc build --target=<build target> main.roc --output=<tmp>`. The key of R-P4, of the build skip (R-BS1 row 1) and of the smoke build (R-SM3 row 1) has the build target. |
| R-TG3 | `[build] target` is a Roc target name (Registry R-IK7 list). Another value gives exit code 19. A platform release whose `targets` does not have the build target is not a candidate (a hard constraint, as R-C4). Reason: the release cannot build the app, and Talon knows it from the header with no probe. |
| R-TG4 | A package or platform project file has no build (R-LD7). `[build]` in its `talon.toml` has no effect. |
| R-TG5 | In a workspace, each member has its own build target (R-TG1 with the member `talon.toml`). A Worker member builds `wasm32` and a script member on basic-cli builds the host target. `[build]` is allowed where `[dependencies]` is allowed (a change of R-WS5). |
| R-TG6 | The proxy does not use the build target: roc flags pass with no change (R-PX3). The build of a tool (R-T8) does not use it. `tln init --platform` uses R-TG1 rules 2 and 3 for the ladder of R-IN2, because there is no `talon.toml` yet (R-IN5). |

For `cloudflare-workers`, rule 3 selects `wasm32` with no `talon.toml` key. The `--no-cache` flag of the platform build (a warm build cache gave other code) does not matter for step 3: Talon does not use the output.

## 8. The shim at a stable project path

### 8.1 What Wrangler accepts

Probe `probes/wrangler-resolve/run.sh`, Wrangler 4.151.0, `wrangler deploy --dry-run --outdir`. The fake shim is outside the project (as `packages/<hash>/js/`), and imports a second file.

| Case | `worker.js` import | Other setup | Result |
| --- | --- | --- | --- |
| a-copy | `./.roc-cfw/index.js` | A copy in the project | Pass |
| b-symlink | `./.roc-cfw/index.js` | A symlink to the cache directory | Pass |
| c-alias | `roc-cloudflare-workers` | `[alias]` in `wrangler.toml` to `./.roc-cfw/index.js` | Pass |
| d-alias-abs | `roc-cloudflare-workers` | `[alias]` to an absolute cache path | Pass |
| e-flag | `roc-cloudflare-workers` | `wrangler deploy --alias name:<cache path>` | Pass |
| f-abs | An absolute cache path | None | Pass |
| g-bare | `roc-cloudflare-workers` | None (control) | Fail, as expected |
| h-nm-link | `roc-cloudflare-workers` | `node_modules/roc-cloudflare-workers` as a symlink, made with no npm | Pass |

Not tested: `wrangler dev` file watch through a symlink, and Windows symlinks.

### 8.2 Choice

| Option | Machine-independent files | Survives `tln cache clean --all` | Windows | Wrangler config change | Verdict |
| --- | --- | --- | --- | --- | --- |
| Copy to `.roc-cfw/` (gitignored), relative import | Yes | Yes | Yes | None | Yes |
| Symlink `.roc-cfw/` to the cache | Yes (the link is not committed) | No: the link breaks until the next fetch | Symlinks need a privilege | None | No |
| `[alias]` or `--alias` to the cache path | No: the path has the home directory and the hash | No | Yes | Yes | No |
| `node_modules/` link | Yes | No | As symlink | None | No: it brings back the `node_modules` convention with no npm |
| Committed copy (vendored) | Yes | Yes | Yes | None | Possible. Big diffs on each platform update. The hash of the header already pins it, so a commit adds nothing |

`.roc-cfw/` is a build output, as `app.wasm` is. `roc-cfw sync --check` also writes it (it writes no committed file), so a CI job can deploy after the check.

### 8.3 `tln path`

| # | Rule (PROPOSED) |
| --- | --- |
| R-PTH1 | `tln path <alias>` prints the absolute directory of the header entry `<alias>` of the project file (R-PD4, `--file`): `packages/<hash>/` under the packages root (Design R-CR1) for a release URL, and the directory of the file for a path entry (R-H7). One line on stdout. With `--json`, `data` is `{ alias, kind: "url" \| "path", dir }` (proposal, R-OUT2). |
| R-PTH2 | When `packages/<hash>/` is missing, Talon fetches the entry first, as `tln install --frozen` fetches (CLI 7.1, R-FE2, R-FE3). It resolves nothing and writes no project file. `--offline` and a missing directory give exit code 15. |
| R-PTH3 | An alias that is not in the header gives exit code 2. A foreign URL (R-H4) gives exit code 2: roc keeps it under another cache rule. |
| R-PTH4 | The command uses a project (add `path` to R-PD14), so it records the project file (R-PD9). So GC keeps the directory while the project is in use (R-GC4). |
| R-PTH5 | Talon reads and runs no file in the directory. A caller must not write in it: roc and Talon treat `packages/<hash>/` as fixed by the hash. |

Without `tln path`, the helper must compute the cache path by itself (R-CR1) and run `roc check` to fetch. That puts the cache rule in a second program (question Q-S3).

### 8.4 Template text of `tln init --platform`

R-IN8 (PROPOSED): with `--platform <name>` (R-IN1), the body of `main.roc` is the R-SM2 app for that platform: each `requires` value is a stub with the body `crash "write the app"`. The ladder of R-IN2 builds it (R-TG6). Reason: Talon knows no example of another platform, and the stub needs no file other than `main.roc` (R-DI7). The platform helper then puts in a real body (`roc-cfw init`). The stub text is question Q-S5.

## 9. The example project after the change

```text
hello/
  main.roc          header: pf URL + hash, roc: pin (tln add --platform, tln init)
  talon.toml        [scripts]
  worker.js         made by roc-cfw sync, committed
  wrangler.toml     committed
  .gitignore        app.wasm, .roc-cfw/, .wrangler/
```

```toml
# talon.toml
[scripts]
build = ["roc build --target=wasm32 --no-cache --output=app.wasm main.roc", "roc-cfw sync"]
check = ["roc build --target=wasm32 --no-cache --output=app.wasm main.roc", "roc-cfw sync --check"]
dev = ["@build", "wrangler dev --local"]
deploy = ["@check", "wrangler deploy"]
```

```js
// Made by roc-cloudflare-workers sync from the manifest of the app. Run it again after a change of the classes in Roc.
import app from './app.wasm';
import { makeHandler } from './.roc-cfw/index.js';

export default makeHandler(app);
```

CI (the file of R-IN6, with the steps that the user adds):

```yaml
- run: curl -fsSL https://github.com/roc-talon/talon/releases/download/v0.1.0/install.sh | sh -s -- --yes --version 0.1.0
- run: tln install --frozen
- run: tln tool install Karakatiza666/roc-cloudflare-workers-cli@=1.0.0
- uses: actions/setup-node@v4
  with: { node-version: '26' }
- run: npm install -g wrangler@4.151.0     # external prerequisite, not a project file
- run: tln run check
```

## 10. What stays external

| Program | Needed for | Why it stays | Alternative studied |
| --- | --- | --- | --- |
| Node (a version with JSPI, `WebAssembly.Suspending`) | Wrangler. `cli.mjs sync` (the manifest) | Wrangler is a Node program. The manifest needs the app to run | H5 (native manifest host) removes Node from `sync` only |
| Wrangler | Bundle, `dev`, `deploy`, D1, R2, secrets | It is the Cloudflare tool. Its only distribution is npm, as a global or CI install, never a project file | A deploy through the Cloudflare API with the module files (no bundle) is possible, but `dev`, migrations and secrets stay in Wrangler. Not in scope |
| npm | Only to install Wrangler on a machine | As above | None |

The project has no `package.json`, no `node_modules/` and no lockfile of npm.

## 11. Anti-patterns of npm and the JS ecosystem

| # | Anti-pattern | Why it is bad | How this design avoids it |
| --- | --- | --- | --- |
| A1 | Install scripts of dependencies (`postinstall`) | Code of any transitive package runs on `npm install`, with the rights of the user. The main path of supply-chain attacks | No install hooks (section 4, R-HK1). A package cannot declare a command. Talon runs no package output (R-SE4) |
| A2 | Lifecycle hooks of the project (`prepare`, `postinstall`, `pre<name>`, `post<name>`) | Hidden order. `install` does more than install. CI is not a pure fetch | No hooks. Explicit `@name` steps (R-RUN4) |
| A3 | Scripts run in a shell | `&&`, quotes, `$VAR`, `rm -rf` differ between `sh` and `cmd`. Helper packages (`cross-env`, `rimraf`, `shx`) exist only for this. Arguments can inject shell code | No shell, words only, shell operators refused (R-RUN2). Logic goes in a `.roc` script (R-RUN6) |
| A4 | `node_modules/.bin` on `PATH` | A dependency can shadow a system program in each script | Talon adds nothing to `PATH` (R-RUN3) |
| A5 | Two pins for one thing (the platform URL and the shim tarball, G5) | They can disagree. A silent mismatch at run time | The shim is in the platform bundle: the header hash pins both (section 6, H4) |
| A6 | Global installs that use the `node` on `PATH` (`npm i -g`) | The tool runs with another Node than the one it was tested with (CLI 6.4) | The helper is a native Roc tool (CLI 6.4). The JS that it runs is pinned by the header, and Node is only the runtime of that JS and of Wrangler |
| A7 | Script names that are also commands (`bun <script>`, `npm test`) | A new command changes the meaning of an old script | Only `tln run <name>` (R-RUN17) |
| A8 | `.env` files read by the runner | Secrets go into files and logs | No `.env` (R-RUN9). Wrangler secrets stay in Wrangler |
| A9 | `npx <pkg>` with no version | Runs the newest release of a name on each run, with no age rule | Tools come from `tln tool install` with `min-release-age` and a hash (R-T9, R-T10). A CI job pins `@=X.Y.Z` |
| A10 | Task runners that grow into build systems (implicit graphs, caches) | Hard to read. Two sources of truth for order | Steps in order, and explicit `in` steps for order between directories (R-RUN8, R-RUN13). `make` or `just` can be a step |
| A11 | Files fetched from a URL with no hash (`curl ... \| node`) | No integrity, no pin | Each fetched file has a hash: the platform bundle (header), the tool bundle (R-T10) |
| A12 | Huge transitive trees for small tasks | Each package is an attack surface | The project has 2 external programs (Node, Wrangler) and the Roc closure that the header locks |

## 12. Open questions (TW17)

Each question is for the human review. The study does not choose.

| # | Question | Options | Lean of the study |
| --- | --- | --- | --- |
| Q-S1 | Does Talon v1 get `tln run` and `[scripts]` at all? The previous check (talon-fit 3, G2) said no, because of Design N2 and "Left to others" | (a) Yes, as section 3, phase P1. (b) No, keep a Makefile or `just` | (a), because the use cases need a per-project command list with no npm, and section 3.3 keeps it small. It needs a new row in "Left to others" and in the command table (R-CM24) |
| Q-S2 | Shell or no shell in a step (R-RUN2)? | (a) No shell, words only. (b) `sh -c` on Unix and `cmd /c` on Windows, as npm | (a) |
| Q-S3 | Does Talon v1 get `tln path` (section 8.3)? | (a) Yes. (b) No: the helper computes the R-CR1 path itself and runs `roc check` to fetch | (a): one owner for the cache rule |
| Q-S4 | Does a project pin its tools (`[tools]` in `talon.toml`, as Go 1.24 `tool` lines in `go.mod`)? | (a) No in v1: global tools, CI pins `@=X.Y.Z`. (b) Yes: a URL with a hash per tool, built through the `tln x` path with no online check | (a). (b) is a second lock outside the header and needs new offline rules (R-B3, R-B7) |
| Q-S5 | The text of `main.roc` for `tln init --platform` (R-IN8) | (a) The R-SM2 stub. (b) A file in the platform bundle, for example `init/main.roc` (a new exception to R-DI7: Talon reads a file other than `main.roc`). (c) Talon refuses `--platform` for a platform other than basic-cli | (a) |
| Q-S6 | The order of `tln run --each` (R-RUN13) | (a) Byte order of paths, one at a time. (b) The order of `members` in `[workspace]`. (c) An order from header path entries between members | (a). Real order goes in a root script |
| Q-S7 | Can a later roc write the manifest to a custom wasm section, or fold it into an exported constant, so that `sync` needs no execution? | An upstream question to roc-lang/roc | Not needed for v1 |
| Q-S8 | `[build] target` (R-TG1): only one target per project file, or a list (build and check each)? | (a) One. (b) A list | (a) |
| Q-S9 | Does `tln run` need a `--dry-run` that prints the steps (programs and directories) and runs nothing? | (a) Yes. (b) No: `tln run` with no name prints the table | Either. Output is a proposal (R-OUT2) |
| Q-S10 | Is a `{ in = ..., run = ... }` step (R-RUN8) in scope for v1, or only `--each`? | (a) Both. (b) `--each` only | (a): the case "sync reads the wasm of another Worker" needs an order |

## 13. Changes to the design files, if accepted

| File | Section | Change |
| --- | --- | --- |
| `DESIGN.md` | 4.3 | `[scripts]` and `[build]` in the `talon.toml` example |
| `DESIGN.md` | 4.4, R-WS5 | `[scripts]` and `[build]` in the tables of each file |
| `DESIGN.md` | 5 | Rows for R-RUN, R-TG, R-PTH, R-HK |
| `DESIGN.md` | 7, R-PH3 | `run`, `path` in P1. R-TG1 to R-TG6 in P0 (ladder step 3 runs in P0) |
| `DESIGN.md` | 8 | R-SE row: `tln run` runs project commands; trust as `make` (R-HK1) |
| `DESIGN_OVERVIEW.md` | Left to others | Build graphs and caches: `make`, `just` |
| `DESIGN-CLI.md` | 1 | R-CM24 `tln run`, R-CM25 `tln path`. R-FL12 rows `--each`, `--keep-going`. R-PD14 adds `path` |
| `DESIGN-CLI.md` | 5 | R-IN8 |
| `DESIGN-RESOLUTION.md` | 4 | R-LD5 text, diagram at line 337, R-TG1 to R-TG6, a constraint row for R-TG3 in section 2 |

## 14. Probes

| Directory | Question | Result |
| --- | --- | --- |
| `probes/no-platform/` | What can an app with no platform do? (option P1 of section 5) | Args and an exit code only. No I/O |
| `probes/wrangler-resolve/` | Which import forms does Wrangler bundle? | Section 8.1: all forms pass except a bare name with no alias |
| `probes/bundle-js/` | Do `roc bundle` and `roc unbundle` keep `.js`, `.mjs` and `.json` files? (the shim in the platform bundle) | Yes, on `nightly-2026-10-21-5349569`: the files come back at their paths |
