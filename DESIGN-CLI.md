# Talon design: CLI

Part of the Talon design. This file holds the `tln` commands, references, exit codes, prompts, the toolchain manager and the fetch pipeline. `DESIGN.md` has the goals, the core model and the list of files.

A reference such as CLI 6.2 is section 6.2 of `DESIGN-CLI.md`. Design, Resolution and Registry name `DESIGN.md`, `DESIGN-RESOLUTION.md` and `DESIGN-REGISTRY.md`. A plain number is a section of this file.

## 1. Commands

| # | Command | Does | Bun equivalent |
| --- | --- | --- | --- |
| R-CM1 | `tln init [app\|package] [--platform <name>] [--ci github\|none]` | New app or package, with the nightly as the `roc:` entry of the header (not `.roc-version`, Resolution 13) and a CI file. Rules: section 5. | `bun init`, `bun create` |
| R-CM2 | `tln install [name[@sel]...] [--platform] [--tool] [--as <alias>] [--no-pin] [--no-check]` | With no names: keep the header, change only entries that break `talon.toml`, fetch the closure (Resolution 9), and build each project tool that has no binary (6.4, R-PT6). `--tool` adds a project tool (6.4, R-PT3). With names: add each one, resolve, write the header. Lookup, alias and `talon.toml` rules: section 2. `add` and `i` are the same command. | `bun install`, `bun add` |
| R-CM3 | `tln remove json [--force]`, `tln remove --tool <key>` | Remove the entry, its range, its override and its patch entry. Rules: section 2. `--tool` removes a `[tools]` entry (6.4, R-PT3). | `bun remove` |
| R-CM4 | `tln update [pkg[@sel]...] [-i] [--no-pin] [--no-check] [--tool]` | Move within ranges. Project tools move too (6.4, R-PT5). Names limit the scope. `pkg@sel` moves to the selector, also to a new series (Resolution 10). `--no-pin` as in `tln add` (section 2). The nightly does not move (R-RP1). `-i` is an interactive picker. Scope rules: Resolution 9. | `bun update -i` |
| R-CM5 | `tln upgrade [pkg...] [roc] [--no-check] [--tool]` | Move to the newest releases, also to new series, and to the newest nightly. Project tools move too (6.4, R-PT5). Change the `talon.toml` ranges to match. Names limit the scope. The name `roc` frees the nightly. Rules: Resolution 10, R-RP1. | `bun update --latest` |
| R-CM6 | `tln outdated` | Table: current, wanted, latest, nightly range. Also a row for each project tool, with its yank state (6.4, R-PT8) | `bun outdated` |
| R-CM7 | `tln why parser` | Paths from the app to a package, and why this version (evidence) | `bun why` |
| R-CM8 | `tln probe [alias\|<bundle file>] [--range] [--share]` | Probe a header entry, a bundle file or the project file on the selected compiler. `--range` finds its compiler range. `--share` sends the facts of a header entry to the registry once, also when sharing is off. Rules: Resolution 4, R-PB1 to R-PB6. | |
| R-CM9 | `tln list [--tree]` | Closure with marks: `direct` (a header entry), `raised` (Roc MVS selects a higher version than a package header names, Design 2), `foreign` (R-H4), `patched` (Resolution 7) | `bun pm ls` |
| R-CM10 | `tln patch json [--diff]` | Edit a copy of a dependency. The copy is the patch, and it goes in VCS. `--diff` prints it against the original (Resolution 7, R-PA1 to R-PA8). | `bun patch` |
| R-CM11 | `tln verify [--strategy highest\|lowest]` | Resolve in memory, run the probe ladder (Resolution 4) on the tuple with `--replace-dep`, and print the result. It writes no header and no `talon.toml`. Probes add evidence to `compat.db` as usual. It does not replace `roc check` (N2). Use: Resolution 8. | |
| R-CM12 | `tln x owner/app [-- args]`, `tln x <key> [-- args]` | Build a Roc app and run it once. The binary stays in the cache. Rules: 6.4, R-X1 to R-X5. In a project, a `[tools]` key or the app of a `[tools]` entry runs the project tool (6.4, R-PT11). | `bunx` |
| R-CM13 | `tln publish` | Register a release (Registry 7) | `bun publish` |
| R-CM14 | `tln audit [--ignore <item>]... [--json]` | Report the closure hashes whose release is yanked, withdrawn on GitHub, or has a replaced asset, then the advisories and the scanner hook. With `direct`, or before P3, there is no yank and advisory data, and Talon prints a note (Resolution 2, R-C6). Rules: R-AU1 to R-AU12. Phase P3. | `bun audit`, `cargo audit` |
| R-CM15 | `tln roc install/link/use/list/remove/default/update` | Compiler management. A nightly, a release, or a git ref built from source (6.6). `link --copy` copies a local build (R-LK2). `use` writes the header `roc:` pin, `default` writes the global default, `update` installs the newest compiler release that the `nightly` switch allows and moves the global default (6.6). | (uv `python`, rustup `toolchain link`) |
| R-CM16 | `tln tool install/list/update/rebuild/remove` | Global tools: build a Roc app (a release or a git ref) and put it on `PATH` (6.4). Talon is one of them (6.5). | `bun add -g` (uv `tool`) |
| R-CM17 | `tln cache gc/clean/list/dir` | Cache management: `gc` keeps what projects use, `clean [--all]` removes on request (6.3) | `bun pm cache` |
| R-CM18 | `tln setup` | Install the `roc` proxy, the `PATH` line and shell completions (6.7) | |
| R-CM21 | `tln yank <tag> [--reason <text>] [--undo]` | Yank a release of the current GitHub repository, or remove the yank with `--undo`. It runs only in a GitHub Actions `workflow_dispatch` job, and it gets the repository from `$GITHUB_REPOSITORY`. A tag with no indexed release gives exit code 2. Rules: Registry 7.2, R-YK1 to R-YK7. Phase P3. | (`cargo yank`, `npm deprecate`) |
| R-CM22 | `tln move <old-name> [--to <new-name>] [--undo]` | Set, offer or remove the successor of a package name (Registry 7.3, R-TP14, R-AP31). It runs only in a GitHub Actions `workflow_dispatch` job. It changes no header: a user follows a successor with `tln update <alias>` (Registry R-PU28). Rules: R-MV1 to R-MV5. Phase P3. | (Packagist "abandoned, use X", `npm deprecate`) |
| R-CM23 | `tln share [on\|off\|login\|logout\|forget]` | Show or change the sharing of probe results with the registry, and the tracker of contributions. Rules: R-SH1 to R-SH10. Phase P2. | (`go telemetry on\|off`) |
| R-CM24 | `tln run [<name>] [--each] [--keep-going] [-- args]` | Run the steps of a script of `[scripts]` in `talon.toml`, in order, with no shell. With `--each`, run it in each workspace directory, in dependency order. With no name, list the scripts or the order. Rules: R-RUN1 to R-RUN17, R-EA1 to R-EA8, R-HK1. Phase P1. | `bun run`, `npm run` |
| R-CM25 | `tln path <alias>` | Print the directory of a header entry: `packages/<hash>/` for a release URL, fetched when missing. Read-only. Rules: R-PTH1 to R-PTH5. Phase P1. | |

R-CM19: Verb aliases. A long form and its other forms are the same command at every level: top level, `tool`, `roc` and `cache`. Help and error text print the long form.

| Long form | Other forms | Example |
| --- | --- | --- |
| `remove` | `rm` | `tln rm json`, `tln tool rm app`, `tln roc rm <id>` |
| `list` | `ls` | `tln ls`, `tln tool ls`, `tln roc ls`, `tln cache ls` |
| `install` | `i`, `add` | `tln i`, `tln add json`, `tln tool i owner/app`, `tln roc i <ref>` |
| `update` | `up` | `tln up json`, `tln tool up app`, `tln roc up` |

R-CM20: The design files use either form. The command table above uses the long form. `add` and `i` are only other spellings of `install`. Each rule of `install` applies to them, and no rule applies to one spelling only.

Global flags work for every command:

| # | Flag | Meaning |
| --- | --- | --- |
| R-FL1 | `--json` | Machine-readable output. Turns on non-interactive mode (section 4). `tln x` and `tln run <name>` reject it with exit code 2, because the app or the steps write to stdout (R-J1, R-RUN11). The `roc` proxy has no Talon flags (6.2). |
| R-FL2 | `--yes` | Answer each prompt of the command with no prompt: "yes" to a yes/no prompt, and the default option of a prompt with options. Downloads too (R-DL5, 6.2). Each Required prompt also has its own answer flag (section 4). |
| R-FL3 | `--offline` | Use the cache only (7.1) |
| R-FL4 | `--quiet` | Print only errors and the answer lines of section 4. An answer line records an action, so `--quiet` keeps it. |
| R-FL5 | `--registry <url\|direct>` | Registry base URL. `direct` uses the GitHub API with no registry (Registry 1). |
| R-FL6 | `--file <path>` | The project file (see "The project" below, R-PD1). Only for a command that uses a project. Other commands reject it with exit code 2. |

R-FL7: Resolve flags work only for commands that resolve: `install` (and `add`), `remove`, `update`, `upgrade`, and `verify` (Resolution 8). Other commands (`roc`, `tool`, `cache`, `x`, `list`, `why`, and the rest) reject them with an error. One exception: `--slots` also works for `probe`, `tool install` and `x`, because they run probes (Resolution 4, R-PP2).

| # | Flag | Meaning |
| --- | --- | --- |
| R-FL8 | `--frozen`, `--no-probe`, `--no-check`, `--dry-run` | See Resolution 12 |
| R-FL9 | `--snapshot <log:N\|time>` | Hide releases added after a registry log size (`log:N`, registry only) or published after a UTC time (RFC 3339, registry or `direct`). See Resolution 11. |
| R-FL10 | `--strategy highest\|lowest` | Version choice (Resolution 8). `upgrade` rejects `lowest` (R-UP8). |
| R-FL11 | `--slots <n>` | Size of the probe slot pool (Resolution 4, "Parallel probes"). Default 12: 12 checks or 3 builds at the same time. |

R-FL12: Command flags. A flag on a command that this table does not name for it stops with exit code 2.

| Flag | Commands | Where |
| --- | --- | --- |
| `--as <alias>` | `install`, `add` with one name (2 or more names: exit code 2), `tool install` (the binary name) | section 2, 6.4 |
| `--no-pin` | `install`, `add`, `update` with an exact version | section 2 |
| `--platform` | `install`, `add` (the ref is the platform), `init` (the platform of the template) | sections 2, 5 |
| `--ci github\|none` | `init` | section 5 |
| `--git` | `tool install`, `x`, `roc install`, `roc default` | section 2 |
| `--path <dir>` | `tool install`, `x`, with a git ref | 6.4 |
| `--from-source` | `tool update talon` | 6.5, R-S2 |
| `-i` | `update` (answers nothing: a picker, R-NI2) | Resolution 9 |
| `--diff` | `patch` | Resolution 7 |
| `--tree` | `list` | section 1 |
| `--range`, `--share` | `probe` | Resolution 4, R-PB1 to R-PB6 |
| `--all` | `cache clean` | 6.3 |
| `--dry-run` (own meaning) | `cache gc`, `cache clean`, `tool rm talon` | 6.3, 6.5 R-RM4 |
| `--force` | `remove`, `roc link --copy` | section 2, 6.6 R-LK2 |
| `--rename-keys` | `install`, `add` (answers R-NI1) | Design 4.3 |
| `--allow-moves` | `install`, `add`, `update`, `upgrade` (answers R-NI3) | Resolution 9 |
| `--probe-downloads` | Commands that resolve, and `probe` (answers R-NI4) | 6.2 |
| `--allow-downloads` | Commands that resolve, and `probe` (answers R-NI5) | 6.2, R-DL5 |
| `--roc pinned\|installed`, `--allow-unchecked`, `--resolve` | `tool install`, `x` (answer R-NI8, R-NI9) | 6.4 |
| `--remove-tools`, `--keep-all` | `tool rm talon` (answer R-NI10) | 6.5 |
| `--replace-roc`, `--no-modify-path` | `setup` (answer R-NI13, R-NI14) | 6.7 |
| `--each` | `run` | section 1, R-RUN13, R-EA1 to R-EA8 |
| `--keep-going` | `run` with `--each` | section 1, R-EA7 |
| `--tool` | `install`, `add` (with one name), `remove`, `update`, `upgrade` | 6.4, R-PT3, R-PT5 |

R-FL13: `--frozen` works only for `tln install` with no names. The other commands, and `install` with names, exist to change the header, so they reject `--frozen` with exit code 2.

R-FL14: `tln verify` always writes nothing, so it rejects `--dry-run` and `--frozen`. `--git` (section 2) works only where a ref can be a git ref: `tln tool install`, `tln x`, `tln roc install` and `tln roc default`. `tln tool install` and `tln x` have their own flag `--resolve` (R-T1, R-X1). `tln cache gc` and `tln cache clean` have their own `--dry-run` (6.3).

R-RG1: Registry precedence, from high to low:

| Priority | Source |
| --- | --- |
| 1 | `--registry <url\|direct>` |
| 2 | `TALON_REGISTRY` (a URL, or `direct`) |
| 3 | `registry` in `config.toml` (6.1) |
| 4 | The built-in default: `direct` |

R-RG2: The built-in default is one constant in the Talon binary, not a file. It stays `direct` until the registry runs (Design 7, P2). Then a Talon release changes the constant to the registry URL. A user who set no registry moves to the registry with `tln tool update talon` (6.5). A user who wants `direct` after that sets it in `config.toml`.

R-RG3: With `direct`, and for the list of nightlies, Talon calls the GitHub API (7.3, R-CV1). With no token, GitHub allows 60 requests an hour for one IP address. So Talon uses a token when it finds one, in this order: `GITHUB_TOKEN`, `GH_TOKEN`, then the output of `gh auth token` when `gh` is installed and logged in. Talon sends the token only to `api.github.com`, never to a registry or a mirror. The one token that goes to the registry is not one of these: `tln share login` gets it from the OAuth App `Talon` for that use, and sends it once (R-SH7). With no token, a rate limit error (exit code 15) names these three sources.

R-RG4: Privacy guard. Talon sends a `github.com` repository to a registry only after GitHub says that it is public. Before the first request that carries its name, its group, a URL of it or a hash of its releases, Talon reads `GET /repos/{owner}/{repo}` with the token rules of R-RG3. These requests are the release list (Registry 4, R-AP1, R-AP13), the closure query (R-AP16: its groups and its hashes), an ingest (R-AP9, from R-AD35 or Registry R-AP28), and `tln probe --share` of a header entry (Resolution 4, R-PB6). The share queue (R-SH4) holds only hashes that came in an answer of the registry (R-SH3 filter 4), so the guard already ran for each of them. `?short=` (R-AD34) carries only the short name that the user typed, so it needs no check.

| # | GitHub answer | Talon does |
| --- | --- | --- |
| R-RG5 | `private` is false | Talon keeps the answer in `talon/index/github/<owner>/<repo>/` with no end, and it does not read it again for that repository. Reason: a name that was public once is not a secret. |
| R-RG6 | `private` is true, or 404 | Talon sends nothing to the registry, and stops with exit code 2. The message says that private packages are not supported (Design N4), and names the full name. With no token, GitHub answers 404 for a private repository, as for a repository that does not exist. So with no token, the message says "not found, or private", and names the three token sources of R-RG3. Talon never keeps this answer. Reason: the owner can make the repository public later, and the next command then reads GitHub again and goes on. |

R-RG4 costs one GitHub API call for each new repository on each machine, only in a command that sends a request to a registry. A rate limit error is R-DI13 (7.3). With `--offline`, Talon sends no request, so R-RG4 does not apply. `tln install --frozen` makes no index call (R-DI1), so it does not run R-RG4.

Example. It needs phase P2 (Design 7): the short name, the `log:` snapshot and the unit-probe note need the registry and unit probes.

```text
$ tln add parser@2.0.0
resolved 4 packages in 41ms (log:184467)
probed 3 times on 1 nightly (0 downloads)

  main.roc
  + parser: lukewilliamboswell/roc-parser 2.0.0
    matched "parser" to lukewilliamboswell/roc-parser
    talon.toml: parser = "=2.0.0"
    note: module Yaml fails on nightly-2026-10-09-258ab27 (redundant expose). Your app does not import it.
```

### Sharing probe results

Phase P2. With sharing on, `tln` sends its probe results of public packages to the registry by itself (Registry 6.1). Reads of compatibility data do not depend on sharing: each user gets all of the matrix (Registry 4, R-AP4, R-AP17).

R-SH1: Sharing is the setting `share` in `config.toml` (6.1): `true` or `false`. When it is not set, sharing is off. `tln share on` and `tln share off` write it (R-CM23). The prompt R-NI16 writes it once, on the first run (R-SH11).

R-SH2: Talon shares by itself only when all of these are true. Talon checks them when a fact goes into the queue, and again before it sends.

| # | Condition | Reason |
| --- | --- | --- |
| 1 | `share = true` | Consent |
| 2 | The registry is a URL, not `direct` (R-RG1) | |
| 3 | No `--offline` | |
| 4 | `DO_NOT_TRACK` is not set, is empty, or is `0` (R-EV26) | `DO_NOT_TRACK=1` is the proposed common opt-out of console tools (consoledonottrack.com). It is not a standard, but to obey it costs nothing. |
| 5 | `CI` does not turn on non-interactive mode (section 4, R-NM1, the row `CI`). `TALON_INTERACTIVE` does not change this. | A CI job never shares by itself. The person who set `share = true` on a runner is often not the owner of the jobs that run on it. |

`tln probe --share` is the one exception: the command names the send (Resolution 4, R-PB6).

R-SH3: A fact goes into the queue only when it passes each filter:

| # | Filter | It stops |
| --- | --- | --- |
| 1 | It is the result of a probe that this command ran while R-SH2 was true | Old facts of `compat.db`, facts that came from the registry, inferred facts (Resolution 4, R-EP14) |
| 2 | The probe is a unit check of a package or a platform (Resolution 4, R-LD2, R-LD3), a smoke build of a platform (Resolution 4, R-SM1 to R-SM5), or the build of a tool app (the table below) | The baseline check, the whole-app check, an app build, the project file and a bundle file. These hold the code of the user, or a hash before its release. |
| 3 | The compiler is an official nightly, with the recorded sha256 (6.2, R-CV6) | Source builds, links and copies (6.6) |
| 4 | The hash came in an answer of the registry in this command (Registry 4, R-AP1, R-AP2, R-AP13, R-AP17) | A patched package (Resolution 7), and a hash on another host that the registry does not index. So the request tells the registry no new name and no new hash, and the privacy guard (R-RG4) already ran for it. |
| 5 | No answer of this command had a `bot` row for the pair | A fact that a rank 2 row already gives (Resolution 3, R-EF3) |
| 6 | The result is `pass`, `fail` or `crash` (Resolution 4, R-RC1, R-RC2, R-RC4), and a `fail` is not a machine error (Resolution 4, R-SM7) | A hang (R-RC3), which a slow or busy machine can cause, a download error, which is no fact (R-P3), and an error that comes from the machine, not the platform |

The build of a tool app (6.4, R-T21) passes filter 2 only when all of these are true:

| # | Condition |
| --- | --- |
| 1 | The app is a `github.com` release bundle that the registry indexes with the kind `app` (Registry 5, R-RE1) |
| 2 | The build uses the header of the bundle with no change: no `--resolve` (R-T1) and no override |
| 3 | It is not a build from a git ref (`--git`, section 2) |

Then each input of the build is public, and the app hash fixes all of them. The fact has the key (app hash, nightly, target), with the real target of the build. A smoke build has the key (platform hash, nightly, target). A queued fact holds no error text: the registry does not take one from a user (Registry 6.1, R-CT2).

R-SH4: The queue. Facts wait in the table `share_queue` of `compat.db` (6.1). A command that sent a request to the registry sends the queue at its end, after its output: at most 2 requests (Registry 4, R-AP10) of at most 500 rows, oldest rows first, in at most 5 s in total (first guesses). The rest waits for a later command. Reason: the send must not hold the end of a command for long when the registry is slow. A row leaves the queue after a 200 or 201 answer, also when the answer lists it in `skipped` (Registry 6.1, R-CT14), or after a 4xx answer other than 429: the registry will not take that row. After a 429 answer, a 5xx answer or no answer, the rows stay, and a later command sends them again. A row that the registry got twice counts once (Registry 6.1, R-CT4). The send never changes the exit code, the output or the `--json` of the command. At most 10,000 rows wait (first guess). Beyond that, Talon drops the oldest rows. `tln share off` empties the queue.

R-SH5: The contributor id is 16 random bytes in lowercase hex. Talon makes it the first time that sharing turns on, and keeps it in `share.json` in the data dir (6.1, R-LY2). It stays when sharing turns off and on again. Only `tln share forget` (R-SH9) makes a new one, and `tln tool rm talon` removes it with the Talon data (6.5, R-RM10). It is not in `config.toml`: people often publish their config files, and the id is a bearer value (Design 8, R-SE15). On Unix, `share.json` has the mode `0600`. Talon prints only the first 8 characters of the id. Talon sends the id only to the registry, in the header `Talon-Contributor`, with user hints (R-AP10), `POST /v1/tokens` (R-AP37) and `DELETE /v1/contributors/me` (R-AP36).

R-SH6: The tracker on the machine. `share.json` also holds the totals of this machine: `sent` (the rows sent), `counted` (the sum of `written` of the answers), `first` (the sum of `first` of the answers), and the times of the first and the last send. Talon changes them under the lock of the file (7.4, R-CC6). They stay when sharing turns off. A user who has not logged in has only these totals: the registry keeps the rows of each id (Registry 6.1, R-CT6), but it shows totals only to an account (R-CT10).

R-SH7: `tln share login` uses the GitHub device flow with the OAuth App `Talon` (Registry 6.1, R-CT8). Before the code, Talon says that a login ties this machine to the GitHub account: the results that it sent before move to the account, the next ones count for it, and the registry keeps them until `tln share forget`, or until their compiler is 12 months old, when it keeps only the totals (Registry 6.1, R-CT6, R-CT8, R-CT15). Then Talon prints `https://github.com/login/device` and the code, and waits for the person. Talon sends the GitHub token once, to `POST /v1/tokens` (R-AP37) with the id, and keeps the JWT of the answer in `share.json`. It never writes the GitHub token to a file. A login does not turn sharing on. The person declines, or the code expires: exit code 13 (`consent`). GitHub or the registry does not answer: exit code 15.

R-SH8: `tln share` with no word prints: on or off, and the condition of R-SH2 that turns it off; the first 8 characters of the id; the totals of R-SH6; the count of queued rows; and, with a JWT, the GitHub login and the totals of the account (`GET /v1/contributors/me`, R-AP35). A 401 answer means that the JWT expired or stopped: Talon removes it and prints `run tln share login`. The text and the `--json` fields are a proposal (CLI 3, R-OUT2).

R-SH9: `tln share logout` sends `DELETE /v1/tokens` (R-AP38), so each token of the account stops, and removes the JWT from `share.json`. `tln share forget` sends `DELETE /v1/contributors/me` (R-AP36), with the JWT when Talon has one: then the registry removes the account, its results and the links of each machine to it. With no JWT, it removes the results that this machine sent before a login. Then Talon removes the JWT, makes a new id, and sets the totals of R-SH6 to 0. The counts that went into `compat_hints` stay, because they hold no id (Registry 6.1, R-CT7). The message says so. `forget` does not change `share`.

R-SH10: `tln share login`, `logout` and `forget` need a registry: with `direct`, Talon stops with exit code 2. `tln share on` with `direct` writes the setting and prints that Talon shares nothing while the registry is `direct`.

R-SH11: The first-run prompt. When `share` is not set, the first command that runs in interactive mode (section 4, R-NM1) asks R-NI16 before it does its work. Talon writes the answer, `true` or `false`, so it asks once. Talon does not ask in these cases:

| Case | Reason |
| --- | --- |
| `tln share` and its words | The command sets or shows the value |
| `tln setup` | The install scripts run it (6.5, R-IS6). The installers do not manage consent. |
| The `roc` proxy (6.2) | It runs `roc` for the user, and it has no prompts of its own |
| `--help`, `--version` | |
| The conditions 2, 4 or 5 of R-SH2 turn sharing off | The answer would change nothing now. Talon asks on a later run, when the condition is gone. |

With no answer (end of input), Talon writes nothing, and the command goes on with sharing off.

### The project

A command that uses a project works on one project file: a `.roc` file with an `app`, `package` or `platform` header. Most projects have one project file, `main.roc`. A workspace (Design 4.4) has one for each member.

| # | Command | Uses a project |
| --- | --- | --- |
| R-PD14 | `install` (and `add`), `remove`, `update`, `upgrade`, `outdated`, `why`, `list`, `patch`, `probe`, `verify`, `audit`, `publish`, `roc use`, `path` (R-PTH4) | Yes. Talon finds it with R-PD1 to R-PD6. |
| R-PD15 | `init` | It creates `main.roc` in the current directory (section 5). It does not search. |
| R-PD16 | The other `roc` subcommands, `tool`, `x`, `cache`, `setup`, `yank`, `move`, `run` | No. They reject `--file`. `run` and `tln x <key>` find a `talon.toml` with the walk of R-RUN12, not a project file (R-RUN12, 6.4 R-PT11). They still record project files (R-PD9). A relative selector `@+N` or `@-N` (section 2) uses the target file of the proxy (R-PD7). |
| R-PD17 | The `roc` proxy | Its target file (R-PD7). It has no Talon flags. |

| # | Rule |
| --- | --- |
| R-PD1 | The start directory is the current directory. With `--file <path>`, the start directory is the directory of that file, and that file is the project file. The command then acts as if it ran in that directory. |
| R-PD2 | Talon walks up from the start directory. The walk stops after the first directory that holds `.git` (a directory or a file), or at the home directory, or at the file system root. Talon checks the stop directory too. So a `main.roc` or a `talon.toml` outside the repository has no effect. |
| R-PD3 | The workspace root is the nearest directory on the walk with a `talon.toml` that has a `[workspace]` table. Its member files are the files that its `members` patterns match (Design 4.4). |
| R-PD4 | With no `--file`, Talon looks for the project file in each directory of the walk, from the start directory up. It stops at the workspace root, if there is one. In each directory: (1) if it holds member files, the project file is the member file when it is the only one, and with 2 or more Talon stops with exit code 2 and lists them; (2) else, if it holds `main.roc`, that is the project file. At the workspace root, only member files count. Talon finds no other file name by itself: for example, the member `examples/hello.roc` needs `--file`, or a start directory where it is the only member file. |
| R-PD5 | A member file is part of its workspace: the command works on the workspace, with that file as the current member (Design 4.4). A project file that is not a member file is a standalone project, also inside a workspace directory: the workspace has no effect on it. With no project file and a workspace root, the command works on the workspace with no current member. With neither, the command stops with exit code 2. The error names the directories that the walk checked, and `--file`. |
| R-PD6 | The `talon.toml` of a standalone project is the `talon.toml` in its own directory, if that file has no `[workspace]` table. A `talon.toml` in a parent directory is the intent of another project and has no effect. The `talon.toml` of a member is the nearest one on the path from the member directory up to the workspace root (Design 4.4). |
| R-PD7 | The `roc` proxy does not search for a project file. Its target file is the file that roc compiles: the first argument that names a `.roc` file, else `main.roc` in the current directory (Resolution 13). Then R-PD1, R-PD3, R-PD5 and R-PD6 apply, as for `--file <target file>`, to find its `talon.toml`. With no target file, the proxy uses no header and no `talon.toml`. |
| R-PD8 | The project file must have an `app`, `package` or `platform` header. Else Talon stops with exit code 2. |

Known projects. GC (6.3) and R-RR2 (6.6) use the list `talon/projects.json` (6.1):

| # | Rule |
| --- | --- |
| R-PD9 | Each command that uses a project records each project file that it reads: its canonical absolute path and the last-use time. A workspace command records each member file that it reads. `tln init` records the file that it creates. `tln run` and `tln x <key>` (6.4, R-PT11) use no project file (R-PD16), but they record the project files under each `talon.toml` that they read: the member files of R-EA1 for a workspace file (each member file for the root file), else the project file of R-PD4 in its directory. With no app file there, they record the path of that `talon.toml` itself. So GC keeps their project tools (6.4, R-PT14). |
| R-PD10 | The proxy records its target file when the file has an `app`, `package` or `platform` header. It writes `projects.json` only when the entry is new or its last-use time is older than 1 day, so most runs write nothing (cost target, 6.2). |
| R-PD11 | Talon never records a temp copy (`talon/tmp/`, 7.4) or a file in `packages/<hash>/`. |
| R-PD12 | An entry holds only the path and the last-use time. GC and R-RR2 read the header of each project file again when they run: its `roc:` pin, and its closure from the package headers in the cache. So a hand edit of the header counts. An entry whose path is a `talon.toml` (R-PD9, `tln run`, `tln x <key>`) has no header: GC reads only its `[tools]` (6.4, R-PT14), and R-RR2 ignores it. |
| R-PD13 | An entry leaves the list when GC or R-RR2 finds that its file is missing or has no `app`, `package` or `platform` header (for a `talon.toml` entry: that the file is missing), or when GC finds that its last use is older than the GC age (6.3). Such an entry protects nothing. `tln cache clean` keeps the list (6.3). |

### Environment variables

R-EV1: A flag has priority over a variable (6.1).

| # | Variable | Value | Effect | Where |
| --- | --- | --- | --- | --- |
| R-EV2 | `TALON_REGISTRY` | A URL, or `direct` | The registry | Registry precedence above |
| R-EV3 | `GITHUB_TOKEN`, `GH_TOKEN` | A token | GitHub API token | Above |
| R-EV4 | `TALON_NIGHTLY` | `0`, `1` | The `nightly` switch | Resolution 1 |
| R-EV5 | `ROC_TOOLCHAIN` | A full compiler id | Compiler selection, rank 2 | Resolution 13 |
| R-EV6 | `TALON_AUTO_INSTALL` | `ask`, `yes`, `no` | Required compiler and Zig downloads | 6.2, R-DL5 |
| R-EV7 | `TALON_PROXY` | `0` | The proxy does no extra work | 6.2 |
| R-EV8 | `TALON_INTERACTIVE`, `CI`, `DEBIAN_FRONTEND`, `NONINTERACTIVE` | See section 4 | Interactive or non-interactive mode | 4 |
| R-EV9 | `NO_COLOR` | Any | No color | 4 |
| R-EV10 | `TALON_YES` | `1` | The install script does not prompt | 6.5, R-IS4 |
| R-EV11 | `ZIG` | A path | The Zig for source builds | 6.6, R-D1 |
| R-EV12 | `TALON_DOWNLOADER` | `curl`, `wget` | The program for downloads | 7.5, R-DA2 |
| R-EV13 | `XDG_CACHE_HOME`, `ROC_CACHE_DIR`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME` | Paths | Directory roots | 6.1 |
| R-EV14 | `TALON_GITHUB_API` | A base URL | Test hook (below) | Below |
| R-EV15 | `TALON_GITHUB_RAW` | A base URL | Test hook (below) | Below |
| R-EV16 | `TALON_ZIG_INDEX` | A URL | Test hook (below) | Below |
| R-EV17 | `TALON_IN_PROXY` | `1` | Set by the proxy for the compiler that it runs. A proxy that sees it does not use rank 7. | Resolution 13 |
| R-EV18 | `TALON_NOW` | A UTC time, RFC 3339 | Test hook (below) | Below |
| R-EV26 | `DO_NOT_TRACK` | Set, not empty and not `0` | Talon shares nothing by itself. `tln probe --share` still sends. | 1, R-SH2 |

Test hooks. With them, a test (`TESTING.md` 3) needs no network and no real clock. A user does not need them.

| # | Variable | Rule |
| --- | --- | --- |
| R-EV19 | `TALON_GITHUB_API` | The base URL of the GitHub REST API, in place of `https://api.github.com` (7.3, R-DI2, the list of compiler releases, and the source archive of a git ref, 6.6, R-R3). When it is set, Talon reads no token source and sends no token. It changes no header URL and no group (R-H5). Asset URLs come from the API answers, so a fake API can give loopback asset URLs. |
| R-EV20 | `TALON_GITHUB_RAW` | The base URL in place of `https://raw.githubusercontent.com`, for the `.roc-version` hint (7.3, R-DI8). Talon sends no token there. |
| R-EV21 | `TALON_ZIG_INDEX` | The URL in place of `https://ziglang.org/download/index.json` (6.6, R-D2). The Zig archive URLs come from its answer. |
| R-EV22 | `TALON_NOW` | The time for each decision of Talon about the age of data: GC ages (6.3), the last-use times that Talon records (R-PD9, R-CC9), `min-release-age` (R-C7), and the time that a resolve prints (Resolution 11). It does not change the age of a lock heartbeat or of a temp (R-CC2, R-CC12): these tell if a process is alive, so they use file modification times and the real clock. It does not change the clock of roc: roc expires its build-cache files by itself (Design 2.2). |

R-EV23: Packages in tests. Talon has no fetch map from a header URL to another host: that is a second kind of mirror (7.1, R-H5). A test gets a package in one of two ways:

| # | Case | How |
| --- | --- | --- |
| R-EV24 | The header URL must keep `github.com`: group keys, lookup, R-H5 | The case pre-fills `packages/<hash>/` in its cache. Talon and roc accept it with no sidecar (Design 9 Q2, 7.2), and fetch nothing. |
| R-EV25 | A test of the fetch path: download, hash check, a slow body, a 404 | The fixture uses a loopback URL, for example `http://127.0.0.1:<port>/x/1.0.0/<hash>.tar.zst`. Talon accepts the package URLs that roc accepts: `https://` to any host, and `http://` only to `127.0.0.1`, `::1` and `localhost` (`roc:src/unbundle/download.zig`, test in `research/roc-http-fetch/`, Design 9 Q24). A loopback URL is its own group (Design 2), so these cases do not test the identity of a `github.com` package. |

### `tln audit`

`tln audit` is P3 (Design 7, R-PH5). R-AU7 gives the warnings of the phases before it.

R-AU1: `tln audit` checks each hash in the closure of the project file: the header entries (Design 4.2) and the deps of each package header, to the end (7.3, R-DI7). It also checks the hash of the `url` of each project tool of the project (6.4, R-PT8), and only that hash: the closure of a tool is in its own header (R-PT4). It reads the release state of each hash from the index of the command: with a registry, the closure answer (Registry 4.1, R-AP17); with `direct`, the release list of R-DI2 for each group of the closure. So in `direct` mode, `audit` also lists transitive groups, which R-DI1 does not do for a resolve. It uses the state of now, with no snapshot (Registry 7.2, R-YK5).

R-AU2: A finding has one `reason`. Both modes use these values. A new `withdrawn` value of the registry (Registry 7, for example R-PU24) gets its own row in this table:

| `reason` | Registry source | `direct` source | Fails (R-AU3) |
| --- | --- | --- | --- |
| `yanked` | `releases.yanked` (Registry 7.2, R-YK4, P3) | None (R-AU4) | Yes |
| `release-missing` | `withdrawn` = `deleted` or `unpublished` (Registry 7, R-PU17) | The tag is not in the release list. `direct` cannot tell a deleted release from a draft. | No |
| `prerelease` | `withdrawn` = `prereleased` or `edited` (R-PU17) | `prerelease` is true | No |
| `asset-replaced` | `withdrawn` = `asset-replaced` (Registry 7, R-PU20) | The tag has another package asset (7.3, R-DI15) | Yes |
| `repo-missing` | `withdrawn` = `repo-missing`, and the `repos` state `missing` (Registry R-PU24, R-TP11) | The release list call (R-DI2) answers 404: the repository is deleted, or it is private (Design N4) | Yes |
| `moved` | The `repos` state `moved`, with the successor of R-AP32 (Registry R-TP14) | The release list answer comes from another name, because GitHub redirects a renamed repository. A move to a new repository (R-AP31) has no `direct` source. | No |

| # | Rule |
| --- | --- |
| R-AU3 | Exit code 21 (`findings`, section 3) when a finding that is not ignored (R-AU9) has "Yes" in the column "Fails" of R-AU2. Else exit code 0, and the other findings print as warnings. Reasons: a yank is the decision of the maintainer. A replaced asset breaks a build on a new machine (7.1, R-FE6). A missing repository also breaks it: the asset of a deleted repository is gone, and the asset of a private repository needs a token (Design N4). A missing release still downloads until GitHub removes the asset, a prerelease is a label, not a defect, and a moved name still has the same bytes at its old URL. |
| R-AU4 | With `direct`, or with a registry before P3, Talon also prints the note of Resolution 2, R-C6. The note is not a finding. |
| R-AU5 | With `--json`, a run with exit code 21 has `ok` false, `error.kind` `findings`, and the report in `error.details`, in the same form as `data` of a run with exit code 0 (R-J4, R-J5). |
| R-AU6 | `tln install --frozen` (Resolution 12, R-LF1) makes no index call (R-DI1), so it does not see findings. A CI job runs `tln audit` as its own step (section 5, R-IN6). A download 404 of a URL in the closure (7.1, R-FE6) gives a message that names `tln audit`. |
| R-AU7 | Before P3, a command that resolves prints one warning for each closure hash whose release state it already has and that has a reason of R-AU2: with a registry from the closure answer (R-AP17), with `direct` from the release lists that it read (R-DI1). It sends no extra request, and the warning does not change the exit code. The warning gives the reason and the fix of R-AU8. |
| R-AU8 | The fix text. For a header entry: `tln update <alias>`. For a transitive entry: update the package that needs it (`tln why <name>`, with the name of R-SC15), or use `[overrides]` (Resolution 6). For `asset-replaced`, Talon also asks the author to release a new version. For `moved`, and for each other reason when the name has a successor: `tln update <alias>`, which follows the successor (Registry R-PU28). For `repo-missing` with no successor: replace the package (`tln remove <alias>`, then `tln add` of another package), or accept the finding with an ignore item (R-AU9). |

R-AU9: Ignore a finding. Two sources, joined: the key `ignore` of the table `[audit]` in `talon.toml` (a list, shared by the team, Design 4.3), and the flag `--ignore <item>`, which can occur more than once (one run). An item is `<full name>@<version>:<reason>`, for example `roc-lang/json@2.1.0:yanked`. The full name is the form of R-SC7 (section 2). The reason is required, so an ignore covers one finding, and a new finding of the same release with another reason still counts. This is the model of `bun audit --ignore` and of `cargo audit --ignore`.

| # | Rule |
| --- | --- |
| R-AU10 | An ignored finding prints as a note (`ignored: <item>`), and does not count for R-AU3. In `--json`, the finding has `ignored` true. |
| R-AU11 | An item that matches no finding prints a note `unused ignore: <item>`, so that a team sees a stale item. It does not change the exit code. |
| R-AU12 | An item that does not parse: exit code 19 in `talon.toml` (`input`, section 3), exit code 2 for the flag. In a workspace, `[audit]` is a table of the root `talon.toml` only (Design 4.4, R-WS5). An advisory (P3) gets its own item form when the design adds advisories. |
| R-AU13 | One hash gives at most one finding. When more than one reason of R-AU2 applies, the finding has the first reason in this order: `yanked`, `asset-replaced`, `repo-missing`, `release-missing`, `prerelease`, `moved`. So a reason that fails comes before a reason that does not fail. The finding also has the successor when its name has one, so that the fix of R-AU8 can name it. |
| R-AU14 | For the reason `moved`, the R-AU7 warning of a resolve is the note of Registry R-PU28 (`json: moved to acme/roc-json. Run: tln update json`). Talon prints one line for each entry, not a second warning. `repo-missing` is P2 (Registry R-PU24), so its R-AU7 warning starts in P2. `moved` starts in P2 for a rename (R-TP10), and in P3 for a move (R-AP31). |
| R-AU15 | In a workspace (Design 4.4), `tln audit` works on the workspace (1, R-PD5): it checks the closure of each member. One hash that two members use gives one finding, with the members in `via`. The `[audit]` table is in the root `talon.toml` only (R-AU12, Design 4.4 R-WS5), and R-AU11 counts an item as unused only when it matches no finding of any member. Reason: an ignore item names a release, not a member, so it is one decision for the workspace, as `[resolution]` is. |

### `tln move`

`tln move` is P3 (Design 7, R-PH5). It is the client of the move route (Registry 7.3, R-AP31, R-TP15). It runs in a `workflow_dispatch` job, because a move is a manual act, as a yank is (R-CM21).

R-MV1: `<old-name>` and `<new-name>` are full names of `github.com` (section 2, R-SC7). The repository of the job (`$GITHUB_REPOSITORY`) selects the request:

| Job repository | Flags | Request | Result (Registry R-TP15) |
| --- | --- | --- | --- |
| Not `<old-name>` | No `--to`, or `--to` equal to `$GITHUB_REPOSITORY` | `PUT /v1/packages/<old-name>/successor` with `{"name": "$GITHUB_REPOSITORY"}` | The move is done when the owner id of the job repository is the owner id of the old name, or when the old name has an offer that names the job repository. Else 403. |
| `<old-name>` | `--to <new-name>` (required) | `PUT /v1/packages/<old-name>/successor` with `{"name": "<new-name>"}` | An offer (202). The owner of `<new-name>` accepts it with `tln move <old-name>` in a job of `<new-name>`. |
| `<old-name>` or the successor | `--undo` | `DELETE /v1/packages/<old-name>/successor` | The successor is removed |

| # | Rule |
| --- | --- |
| R-MV2 | Talon checks these before it sends a request. Each failed check stops with exit code 2 (section 3, R-EC2), and the message names the check: no GitHub Actions OIDC variables (Registry R-TP2); `GITHUB_EVENT_NAME` is not `workflow_dispatch` (the registry refuses other events, R-TP15); `GITHUB_SERVER_URL` is not `https://github.com`; the registry is `direct` (section 1); a name is not a full `github.com` name; `--to` with `--undo`; no `--to` in a job of `<old-name>`; `<old-name>` is equal to the successor; the job repository is neither `<old-name>` nor the successor. |
| R-MV3 | The privacy guard (R-RG6) checks the successor only. It does not check `<old-name>`: that name is already in the index, and its repository is often deleted (state `missing`, Registry R-TP11), so the guard would stop the main case of a move. The registry answers 404 for an old name that it does not index. |
| R-MV4 | The token is the token of R-TP2 (Registry 7.1), for the job repository. A refused request gives exit code 20 (`rejected`, R-E6). The message gives the problem `detail`: for 422 `successor-mismatch`, the check that failed (Registry R-AP31: index, kind, `exposes`, chain). After a 429, a 5xx or no answer, Talon sends the request again as in Registry R-AP34, because R-AP31 is idempotent. |
| R-MV5 | `tln move` uses no project (R-PD16) and writes no file. It changes no header. A user sees the successor in `tln outdated`, and follows it with `tln update <alias>` (Registry R-PU28). The output is in the catalog (section 3, a proposal, R-OUT2). |

### `tln run`

`tln run` is P1 (Design 7, R-PH3). It runs a named list of commands from `[scripts]` of `talon.toml`. It has no shell, and only the user starts it: no other command and no package runs a script (R-HK1). Source: `research/talon-scripts/` 3, 4, 11.

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
  { in = "workers/ledger", run = "@build" },             # another directory (R-RUN8)
  { in = "workers/web", run = "@build" },
]
```

| # | Rule |
| --- | --- |
| R-RUN1 | `[scripts]` is a table of `talon.toml`. A key is a script name: `[a-z0-9][a-z0-9:_-]*`, at most 64 characters. A value is a step, or an array of steps. A step is a string (a command line, or `@<name>`), or an inline table `{ in = "<dir>", run = "<step string>" }`. Another form gives exit code 19 (`input`, section 3). |
| R-RUN2 | Talon splits a command line into words. A space or a tab separates two words. `"..."` and `'...'` quote a word, with the escapes `\"` and `\\` in `"..."` only. Talon does no expansion: no `$VAR`, no `~`, no glob, no command substitution. An unquoted word that is `\|`, `&&`, `\|\|`, `;`, `>`, `>>`, `<`, `&`, or a word that starts with `$(` or a backquote, gives exit code 19. The message names the step and says: "a step is one command; use 2 steps, or a .roc script". Reason: the same text runs on Linux, macOS and Windows (`research/talon-scripts/` 11, A3). |
| R-RUN3 | The first word is the program. Talon finds it in this order: (1) the words `roc` and `tln` run the `tln` binary that runs `tln run` (proxy mode for `roc`, 6.2, R-PX1), so the step gets the compiler that Talon selects (Resolution 13), also when `tln setup` did not run; (2) a key of `[tools]` (6.4, R-PT1) runs the binary of the locked release of that key (R-PT9). The table is the `[tools]` of the workspace root (R-PD3) of the `talon.toml` that holds the script. When that file is the `talon.toml` of a standalone project (R-PD5, R-PD6), also inside a workspace directory, it is its own root and the table is its own (R-PT2). An `in` step (R-RUN8) uses the same table; (3) else `PATH` of the environment of `tln run`, as `Cmd` does. Talon adds no directory to `PATH`, so a child of a step does not see the project tools (R-PT10). |
| R-RUN4 | A step `@<name>` runs the script `<name>` of the same `talon.toml`, with all its steps. A name that the file does not have gives exit code 19. A cycle (`a` runs `b`, `b` runs `a`) gives exit code 19 before the first step runs. |
| R-RUN5 | `tln run <name>` runs the steps in order. Each step runs as a child with inherited stdin, stdout and stderr (Design 6.2, R-HF6: a child, not `execve`, because more steps can follow). The next step starts only when the step before it exits with 0. |
| R-RUN6 | A first word that ends with `.roc` is a Roc script: Talon runs `roc <file> -- <other words>` through the proxy (R-RUN3). The file is relative to the working directory of the step (R-RUN8). Its header names its own platform, as each Roc app does. Talon has no script platform. |
| R-RUN7 | Exit code: the exit code of the first step that fails, else 0 (R-E1). A step that a signal stops gives 128 + the signal number. When Talon itself fails before or between steps (a bad table, a missing program, a cycle), it uses its own codes with the line `tln: error[<kind>]: ...` (R-E4). A program that is not in `PATH` gives exit code 18 (`environment`), and the message names the program and the step. |
| R-RUN8 | The working directory of each step is the directory of the `talon.toml` that holds the script. A step `{ in = "<dir>", run = ... }` runs in `<dir>`, relative to that directory. `<dir>` must be inside the repository (the stop directory of R-PD2); else exit code 19. An `@<name>` step in an `in` table runs the script of the `talon.toml` in `<dir>`; that file must exist and have the name, else exit code 19. The `in` steps of a script run in the order of the script: `[run] after` (R-EA3) does not change it. |
| R-RUN9 | Environment: the environment of `tln run`, plus `TALON_SCRIPT` (the name of the script that the user named) and `TALON_SCRIPT_DIR` (the absolute working directory of the step). Talon reads no `.env` file and sets no other variable. |
| R-RUN10 | `tln run <name> -- <args>` adds `<args>` as words to the end of the last step. When the last step is `@<name>`, the rule applies to that script. With `--each` (R-RUN13), the args go to the last step of the script in each node. With no `--`, a word after the name gives exit code 2. |
| R-RUN11 | `tln run` with no name prints each script of the `talon.toml` that R-RUN12 finds, with its steps. It also prints a note for each `[tools]` key that is also a program on `PATH`: inside `tln run` the key wins (R-RUN3). With `--json`, `data` is `{ file, scripts: [{ name, steps: [...] }] }` (a proposal, R-OUT2, as the text of the note). `tln run <name> --json` gives exit code 2, as `tln x` (R-FL1): the steps write to stdout. |
| R-RUN12 | Which `talon.toml`: Talon walks up from the current directory as in R-PD2, and stops at the workspace root (R-PD3) when there is one. The walk also stops at the `talon.toml` of a standalone project (R-PD5, R-PD6, Design 4.4 R-WS5): the scripts of a `talon.toml` above it have no effect there. The first `talon.toml` on the walk that has the name in `[scripts]` holds the script. With none, exit code 2. The message lists the files that the walk checked. `--file` is not a flag of `run` (R-FL6, R-PD16): a script is not for one project file. |
| R-RUN13 | `tln run --each <name>` runs the script in each directory of the workspace whose `talon.toml` has the name, except the root file, in the dependency order of R-EA1 to R-EA8. With no workspace, exit code 2. A root script with `in` steps (R-RUN8) is the other way to give an order. |
| R-RUN14 | `[scripts]` is allowed in the root `talon.toml` and in each other `talon.toml` of a workspace (Design 4.4, R-WS5). Talon never reads `[scripts]` of a `talon.toml` in a package archive (Design 4.3, R-I1). |
| R-RUN15 | No other command runs a script. `install`, `add`, `update`, `upgrade`, `remove`, `init`, `tool install`, `x`, the proxy and the probes never read `[scripts]` (R-HK1). |
| R-RUN16 | `tln run` uses no resolve flag (R-FL7), and does not resolve, fetch or write a project file. A step can be `tln install --frozen` when a script needs it. One exception: a project tool with no binary is fetched and built from its locked `url` (6.4, R-PT9). That is no resolve. |
| R-RUN17 | Names of Talon commands are not script names: `tln build` is not `tln run build`. Reason: a new Talon command can never change what an old script name does (`research/talon-scripts/` 11, A7). |

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
   program = roc|tln -> this tln; [tools] key -> locked tool; *.roc -> roc <file> --; else PATH (R-RUN3, R-RUN6) ---- not found ----> exit 18
   run as a child, inherited stdio
   exit != 0 ----> stop, exit with that code (R-RUN7)
  |
  v
exit 0
```

What `tln run` does not have. These are explanations, not rules:

| Feature of other runners | In `tln run` | Reason |
| --- | --- | --- |
| A shell (`sh -c`, `cmd /c`) | No (R-RUN2). A user who wants a shell writes `sh -c "..."` as a step, which shows that the step is not portable | Portable text, no quoting bugs, no injection through `-- <args>` |
| `node_modules/.bin` on `PATH` | No (R-RUN3) | No shadowing of a system program by a dependency |
| Implicit `pre<name>` and `post<name>` | No (R-HK1) | Explicit steps (`@name`) say the same with no hidden order |
| File dependencies, caching, parallel tasks (make, just, turbo) | No | Design N2: Talon is not a build system. `make` and `just` stay usable as a step |
| `tln <script>` with no `run` | No (R-RUN17) | A name collision with a future command |
| `.env` loading | No (R-RUN9) | Secrets in files that tools read by themselves |
| `tln run --dry-run` | No. `tln run` with no name prints the scripts, and `tln run --each` with no name prints the order (R-RUN11, R-EA8) | |

Order of `tln run --each`. The nodes are directories, not files: a script is in a `talon.toml`, and `--each` runs one script in each directory.

```toml
# workers/web/talon.toml
[run]
after = ["../ledger"]      # web reads ledger.wasm in its sync, so ledger runs first

[scripts]
build = ["roc build --target=wasm32 --no-cache --output=web.wasm main.roc", "roc-cfw sync"]
```

| # | Rule |
| --- | --- |
| R-EA1 | A node is a directory with a `talon.toml` of the workspace (Design 4.4, R-WS5), except the root directory. A directory with a standalone `talon.toml` is not a node. Its member files are the member files (R-PD3) in that directory or below it, up to the next directory with a `talon.toml`. |
| R-EA2 | Edge kind 1, from the headers: node A comes after node B when a member file of A has a path entry (Design 4.2, R-H7) that names a member file of B, or a file in the directory of B. Talon reads only the project headers, as for R-H7: no import, no build. |
| R-EA3 | Edge kind 2, declared: `after` in the `[run]` table of a `talon.toml` is an array of directories, relative to that file. Node A comes after each of them. Use it for an order that is not a Roc dependency, for example a Worker whose `sync` reads the wasm of another Worker. Each entry must be a node of R-EA1; else exit code 19, and the message names the file and the entry. `[run]` is allowed in each `talon.toml` of the workspace except the root file (Design 4.4, R-WS5). `after` orders the nodes of `--each` only: it has no effect on the `in` steps of a script (R-RUN8). |
| R-EA4 | The edges apply to all scripts. When a node in the middle of a path has no script of that name, the order of the other nodes stays: if A is after B and B is after C, A runs after C also when B has no such script. |
| R-EA5 | A cycle stops the command with exit code 19 (`input`) before the first step runs. The message prints each cycle as a list of directories with the kind of each edge, for example `workers/web -after-> workers/ledger -path-> workers/web`. |
| R-EA6 | Ties: of the nodes that are ready, Talon runs the one with the smallest path (byte order of the path relative to the root). So the order is a function of the files only (Design G3). |
| R-EA7 | One node at a time: no parallel runs. Talon prints one line for each node before its steps. Without `--keep-going`, the first failure stops the command, and Talon exits with that code (R-RUN7). With `--keep-going`, Talon skips each node that comes after a failed node (direct or not), prints `skipped <dir> (after <failed dir>)`, runs all other nodes, and exits with the code of the first failure. |
| R-EA8 | `tln run --each` with no name prints the order and the edges (with `--json`: `data` is `{ order: [dir], edges: [{ from, to, kind }] }`, a proposal, R-OUT2), and runs nothing. |

Limits. These keep `--each` a list in order, not a build system:

| Not in `--each` | Reason |
| --- | --- |
| Parallel runs | Output of two nodes would mix, `roc` and other tools use shared caches, and Windows process groups differ. A later `--jobs` needs output rules first |
| File-change detection, skip of an up-to-date node | Needs inputs and outputs of each step: a build system. Each run runs each step |
| A cache of results | Same reason. `roc` has its own build cache |
| Edges from `import` lines, from service bindings of a platform, or from file names in steps | Talon does not read them. An order that the headers do not give is one `after` line |
| An order between scripts of one node, or other script names in the graph | The steps of a script are already in order (R-RUN5, R-RUN4) |

No hooks. Talon runs no script by itself, and never runs code of a dependency:

| Hook kind | In npm, Bun, pnpm, Cargo | Talon | Reason |
| --- | --- | --- | --- |
| Install scripts of a dependency (`preinstall`, `install`, `postinstall`) | npm runs them by default. Bun and pnpm (v10) run them only for packages on an allow list. Cargo `build.rs` runs at build | Never. A package has no way to declare code for Talon to run | Supply-chain attacks use them first. Talon runs no package output (Design 8, R-SE4). A Roc package needs no build step: `roc` compiles it as part of the app |
| Install scripts of the project (`postinstall` in the root) | npm runs them on `npm install` | No | `tln install --frozen` in CI must be a pure fetch. The user adds a script and calls it |
| `pre<name>` and `post<name>` of the project | npm runs them around `npm run <name>` | No | Hidden order. An explicit `@name` step does the same (R-RUN4) |
| A hook on `roc build` (the proxy) | None | No | The proxy passes each command with no change (R-PX3) and has a cost target of 5 ms (R-PX2) |
| A hook after `tln add` or `tln update` | None | No. The summary already prints a notice when the platform changes (Design 8, R-SE7). The text of that notice can name `tln run` when the project has `[scripts]` (a proposal, R-OUT2) | A command that changes the header must not run project code by itself |
| Git hooks | husky (npm `prepare`) | Out of scope | Not a package manager job |

R-HK1: Talon runs a command of `[scripts]` only in `tln run`, only when the user names the script, and only from the `talon.toml` files of the project or workspace of the current directory (R-RUN12, R-RUN13). No other command, no package, and no file in the cache can make Talon run a program, except the programs of the design: `roc`, the tools that the user installs or names (6.4), the project tools of `[tools]` when a step or `tln x` names them (R-PT9, R-PT11), and the child programs of Design 6.2 (`curl`, `tar`, and so on). A build of a project tool (`tln install`, R-PT6) does not run the tool. Trust: Design 8, R-SE17.

### `tln path`

`tln path <alias>` is P1 (Design 7, R-PH3). It prints the directory of a header entry, so that a tool of a platform (for example the helper of `cloudflare-workers`) can read files of the platform bundle without the cache rule of Design 2.2.

| # | Rule |
| --- | --- |
| R-PTH1 | `tln path <alias>` prints the absolute directory of the header entry `<alias>` of the project file (R-PD4, `--file`): `packages/<hash>/` under the packages root (Design 2.2, R-CR1) for a release URL, and the directory of the file for a path entry (Design 4.2, R-H7). One line on stdout. With `--json`, `data` is `{ alias, kind: "url" \| "path", dir }` (a proposal, R-OUT2). |
| R-PTH2 | When `packages/<hash>/` is missing, Talon fetches the entry first, as `tln install --frozen` fetches (7.1, R-FE2, R-FE3). It resolves nothing and writes no project file. `--offline` and a missing directory give exit code 15. |
| R-PTH3 | An alias that is not in the header gives exit code 2. A foreign URL (Design 4.2, R-H4) gives exit code 2: roc keeps it under another cache rule. |
| R-PTH4 | The command uses a project (R-PD14), so it records the project file (R-PD9). So GC keeps the directory while the project is in use (6.3, R-GC4). |
| R-PTH5 | Talon reads and runs no file in the directory. A caller must not write in it: roc and Talon treat `packages/<hash>/` as fixed by the hash. |

## 2. References in the CLI

R-SL1: One grammar names packages, platforms, tools and compiler releases:

```text
ref      = name [ "@" selector ] | "@" selector | nightly-tag
name     = alias | owner/repo | host/path | short
selector = version | range | series | "latest" | nightly-tag | git-ref | ("+" | "-") count
```

R-SL2: The two short forms are valid only in the `tln roc` scope. There the default name is `roc-lang/roc`:

| Short form | Means |
| --- | --- |
| `@sel` | `roc-lang/roc@sel` |
| `nightly-2026-10-09-258ab27` | A nightly tag with no `@`. `roc-lang/roc@nightly-2026-10-09-258ab27` is the same ref. |

| # | Selector | Example | Meaning |
| --- | --- | --- | --- |
| R-SL3 | Release version | `owner/app@1.4.0` | That release |
| R-SL4 | Range or series | `roc-lang/http@^2`, `roc-lang/http@2`, `roc-lang/basic-cli@0.25` | The newest match. A series (Design 4.1) is the major, or `0.minor` below 1.0. For an installed entity, it selects among the installed ones. |
| R-SL5 | Latest | `owner/app@latest` | The newest release that is not yanked, found online. In `tln tool install` and `tln x`, it turns off the reuse of an older build (6.4, R-B2). In `tln add`, it is the same as no selector. In `tln update X@latest`, it is the newest release, also in a new series (Resolution 10). |
| R-SL6 | Nightly tag | `@nightly-2026-10-09-258ab27` | That nightly (compiler only) |
| R-SL7 | Relative step | `@-1`, `@+2` | Compiler only. The compiler release N steps older (`-`) or newer (`+`) than the compiler that Resolution 13 selects in the current directory, in the domain of the `nightly` switch (Resolution 1, R-NS3). Talon uses the online list of releases. With `--offline`, or with no network, it uses the installed releases and prints a note. Talon stores the full id. Use: `tln roc use @-1` when the newest nightly breaks a project. |
| R-SL8 | Git ref | `owner/app@dd03c09e`, `--git owner/app@main` | A source build. A branch or tag is fixed to a commit at install time. |

Talon reads a selector with these rules, in order:

| Id | # | Selector | Result |
| --- | --- | --- | --- |
| R-SL9 | 1 | Matches a release, a range, a nightly, a relative step, or the word `latest` | Used. No marker is needed. A branch named `latest` needs `--git` (rule 3). |
| R-SL10 | 2 | Looks like a commit sha (hex only, at least 7 characters), and no release matches | Taken as a git ref, with no `--git`. |
| R-SL11 | 3 | A branch or tag name | Taken as a git ref only with `--git`. |
| R-SL12 | 4 | None of the above, and no `--git` | Error. Talon lists the close release versions and says `use --git for a branch or tag`. |

R-SL13: So a typo such as `owner/app@mian` is an error. It never starts a source build. `--git` skips rules 1 and 2 and takes the selector as a git ref.

R-SL14: No selector means different things in different scopes. In `tln add` and `tln update`, it means the release in range that `strategy` selects (Resolution 8): the newest with `highest` (the default), the lowest that resolves with `lowest`. For a new entry of `tln add`, the range is the newest series (Design 4.1) that has a candidate, so `lowest` gives the lowest release of that series that resolves. `tln upgrade` ignores package ranges (Resolution 10). In `tln tool install` and `tln x`, it means "this app, at any version": Talon first uses a build that is already on this machine, and builds the newest release only if there is none (6.4, R-B1 and R-B2).

R-SL15: The separator is `@`, not `#` as in npm, because the shell reads `#` at the start of a word as a comment. Some shells also read `^` (zsh with `EXTENDED_GLOB`) and `~` as special. Quote a ref that has them: `'roc-lang/http@^2'`. The shell-safe forms `@2`, `@2.x` and `@2.1.x` need no quotes. `@2.x` means the same as `@^2`, and `@2.1.x` means 2.1.0 up to, but not including, 2.2.0. Below 1.0, the series has two parts (Design 4.1): `@0.25` and `@0.25.x` mean the same as `@^0.25`, that is 0.25.0 up to, but not including, 0.26.0. `@0.x` spans many series, so it is a range over many groups, like `*`. A version with fewer than 3 parts is a caret range, as in Cargo: `@1.2` means `^1.2` (1.2.0 up to, but not including, 2.0.0), `@2` means `^2`, and `@0.25` means `^0.25`. A version with 3 parts is an exact version.

Each command works in one scope, so names of different kinds never collide:

| # | Command | Scope |
| --- | --- | --- |
| R-SC1 | `tln update`, `upgrade`, `remove`, `why`, `patch`, `probe` | Project. `tln why`: the packages of the closure. The other commands: the header entries of the members (Design 4.4, R-WS8). A transitive package is not a name there. In `tln update X@sel`, Talon finds X in the project and the releases that match `sel` in the registry. `tln probe` with no name probes the project file itself, and a path to a bundle file probes that bundle (Resolution 4, R-PB1). `tln list` takes no name (R-CM9). |
| R-SC2 | `tln install` with names (and `add`) | First the project: a header alias (form 1) names that entry ("An entry that is in the header" below). Else the registry index, and with no registry (`TALON_REGISTRY=direct`), GitHub. |
| R-SC3 | `tln tool ...` | `tools.json` (6.4). `tln tool install` with a full name: the registry index. |
| R-SC4 | `tln x` | Installed tools and `x` cache entries (6.4). With a full name: the registry index. |
| R-SC5 | `tln roc ...`, `roc +<id>` | Installed compiler releases (6.6) |

In a scope, Talon tries these forms in order and uses the first match:

| Id | # | Form | Example | Rule |
| --- | --- | --- | --- | --- |
| R-SC6 | 1 | Header alias | `pf` | Exact. An alias is unique in a header. A path entry and a foreign URL (Design 4.2, R-H4) have no full name: the alias is their only name. A path entry or foreign URL of a package header has no name; `tln why` of the package that needs it shows it. |
| R-SC7 | 2 | Full name | `roc-lang/basic-webserver` | Exact. Non-GitHub hosts use `host/path` (Design 4.1). |
| R-SC8 | 3 | Short name | `basic-webserver`, `parser` | The repo name, or the repo name minus a leading `roc-` (the alias rule below, without `-` to `_`). So `parser` and `roc-parser` both match `lukewilliamboswell/roc-parser`. It must match one entity only. |
| R-SC9 | 4 | Unique id prefix | `git-dd03`, `nightly-2026-10-09` | Compiler releases only, as a git short sha. Interactive use only (see the prefix rules below). |

Prefix rules. A prefix that is unique today can become ambiguous after a later install. So Talon stores only full ids:

| # | Place | Prefix allowed? | Behavior |
| --- | --- | --- | --- |
| R-SC10 | `tln roc ...` arguments | Yes | Talon expands it to the full id. An ambiguous prefix is an error that lists the full ids. |
| R-SC11 | `roc +<id>` typed by hand | Yes | Same expansion and same error. A script must use the full id. |
| R-SC12 | `ROC_TOOLCHAIN`, `roc:` pin, `.roc-version`, `talon.toml` | No | The full id only. A prefix is an error. |
| R-SC13 | `tln roc default` | Stores the full id | Talon expands the prefix first, then stores the full id. |

R-SC14: On a tie, Talon stops with exit code 2 (R-EC2). It lists each match by its name in the scope (R-SC15), with a note: `platform (<alias>)`, `direct (<alias>)`, or `via <alias>` (the header alias of the entry that needs the package). Each name in the list names one package, so the user types one of them, or the alias of a direct match. The same list reports an alias that names 2 groups in a workspace (Design 4.4, R-WS8). In a command that moves an entry (R-SC16), when no match has the series of the selector, the last line asks for the alias of the entry to move. The texts are a proposal (R-OUT2).

```text
"basic-webserver" matches 2 packages:
  roc-lang/basic-webserver      platform (pf)
  someone/basic-webserver       via web_utils
tln: error[usage]: "basic-webserver" matches 2 packages. Use a name from the list.
```

The output of `tln update roc-lang/http@3`:

```text
"roc-lang/http" matches 2 packages:
  roc-lang/http@1      direct (http1)
  roc-lang/http@2      direct (http2)
tln: error[usage]: "roc-lang/http" matches 2 packages. Use the alias of the entry to move: tln update http1@3
```

R-SC15: The group includes the series (Design 2, 4.1), so one closure can hold `roc-lang/http` 1.x and 2.x. The name of a package in a scope (R-SC1 to R-SC5) is its full name (R-SC7). When the scope has 2 or more series of one full name, the name of each of them adds its series in the ref form (R-SL1): `roc-lang/http@1`, `roc-lang/http@2`, `roc-lang/basic-cli@0.25`. This is the Go rule of the major in the module path (`/v2`). Talon prints this name wherever it tells the user what to type: the tie list (R-SC14), and the fix texts (R-AU8). The `--json` field `name` stays the full name, next to `version`.

R-SC16: A selector after a name (`X@sel`) narrows the matches of each form (R-SC6 to R-SC8), as a cargo package id spec does. A command that does not move an entry (`why`, `remove`, `patch`, `probe`) keeps the matches whose version is in `sel` (R-SL4: `@2` is `^2`). No match left is `'<x>' is not in the project`. An unmanaged entry (a path entry or a foreign URL, Design 4.2, R-H4) has no version, so it never matches a name with a selector. A command that moves an entry (`update X@sel`, and `add X@sel` of a header entry, R-AD22) reads `sel` as the target (Resolution 9, R-SP5). With one match it uses that match, also for a new series. With 2 or more matches, it keeps the matches in the series of `sel`. A selector with no single series (`latest`, `0.x`, `*`) keeps all matches. So `text@1`, `acme/text@1` and `acme/text@^1.2` all name series 1, and `tln update http1@3` moves one of 2 entries to series 3. When the one match is an unmanaged entry, Design 4.2, R-H9 applies (exit code 2).

### Lookup in `tln add`

R-AD1: `tln install X`, `tln i X` and `tln add X` are one command (section 1). The design files call it `tln add`. Talon tries form 1 first: when X is a header alias, it names that entry, and the table "An entry that is in the header" below applies. Else X names a package that is not yet in the header, and these rules apply:

| # | Case | Talon does |
| --- | --- | --- |
| R-AD2 | Full name (form 2) | Uses it. No search. |
| R-AD3 | Short name, registry on, one indexed package matches | Uses it. Prints the full name it chose, for example `matched "parser": lukewilliamboswell/roc-parser`. |
| R-AD4 | Short name, registry on, more than one match | Stops. Lists the full names, as in the tie example above. |
| R-AD5 | Short name, no match | Stops. Prints the error. Does not search GitHub. |
| R-AD6 | Short name, registry off | Stops. GitHub has no index of short names. Asks for the full name. |

R-AD7: `tln tool install` and `tln x` do not search the registry for a short name. A short name must match an installed tool or an `x` cache entry. For a new app, the user types the full name. Reason: `tln x` runs the app at once, with no prompt (R-X4). A short-name match in the registry could run a different app with a similar name (typosquat). With no local match, Talon stops with exit code 2 and lists the registry matches as full names.

R-AD34: With a registry, the match set of a short name in R-AD3 to R-AD5, R-AD7 and Design 4.3 R-I8 is the `matches` list of `GET /v1/packages?short=<name>` (Registry 4.3, R-SN1 to R-SN4). One request holds all short names of one command. Talon never selects a package from the ranked results of `?q=` (R-SN5). With `--snapshot log:N`, Talon hides each match above N (R-SN4).

R-AD35: With a registry, a full name `owner/repo` that `GET /v1/packages/{owner}/{repo}/releases` (Registry 4, R-AP1) answers with 404 is a repository that the registry did not index yet. Talon runs the privacy guard of section 1 (R-RG4) before it sends that first request. `tln add` (R-AD2), `tln tool install` and `tln x` (R-SC3, R-SC4) then ask the registry to index its releases, and ask again with the largest `Talon-Bookmark` of the ingest answers (Registry 4, R-AP41 row 5):

| Step | Name | Talon does |
| --- | --- | --- |
| 1 | Read GitHub | The release list of R-DI2, with the token rules of section 1 (R-RG3). The guard (R-RG4) already read `GET /repos/{owner}/{repo}`. Talon selects the candidates with R-DI3 to R-DI5, and with the selector of the command (section 2) when it has one. |
| 2 | Stop cases | A 404 or a private repository: the guard stopped the command before this step (R-RG6, exit code 2, private packages are not supported, Design N4). No release is a candidate: exit code 2, as R-T10 (6.4). |
| 3 | Ingest | For each candidate, newest first by `published_at`, `POST /v1/releases` with no token and the body `{url}` (Registry 4, R-AP9). Up to 4 requests run at the same time (first guess). A 200 or 201 answer indexed the release. A 409 or 422 answer: Talon skips that release and prints a warning that names it and the error `type`. A 429 answer: Talon stops with exit code 15, as R-AP25. The releases that the registry indexed stay indexed. |
| 4 | Ask again | `GET /v1/packages/{owner}/{repo}/releases` again, with no local copy and with `Cache-Control: no-cache` (Registry 4, R-AP43). Then the command goes on as for a repository that the registry knows. When the answer is still 404 (each ingest answered 202, a queue of Q30), Talon stops with exit code 15, and the message says that the registry indexes the repository and to run the command again. |

R-AD36: With `--snapshot log:N`, Talon sends no ingest: a new release has a log index greater than N, so the snapshot hides it (R-AP19). The command stops with exit code 2, and the message says that the name has no release in the log at size N.

R-AD37: With `--offline`, Talon sends no request, and R-DI12 applies (7.3).

Reason for the ingest: one command uses one index (R-DI14), so `--snapshot log:N` (Resolution 11, R-DT3), the matrix and the compat bot (Registry 6, R-MX7) cover the new releases. The next user of the name gets the index with no GitHub calls. Go modules have the same model: the module proxy fetches a module that it does not have on the first request.

### Aliases in `tln add`

R-AD8: The default alias comes from the release name. Talon may shorten the name only to its complete unqualified name: the repo name, without the owner. The only exception: Talon drops a leading `roc-`. Talon does not drop other prefixes or suffixes, does not abbreviate and does not guess.

| # | Full name | Default alias | Why |
| --- | --- | --- | --- |
| R-AD9 | `roc-lang/basic-cli` | `basic_cli` | Repo name. `-` becomes `_`. |
| R-AD10 | `roc-lang/unicode` | `unicode` | Repo name |
| R-AD11 | `lukewilliamboswell/roc-parser` | `parser` | Leading `roc-` dropped |
| R-AD12 | `someone/roc-json` | `json` | Leading `roc-` dropped |
| R-AD13 | The platform entry | `pf` | A convention, not a name shortening. A header has one platform, and `pf` is the Roc habit. |

R-AD14: An alias is a Roc identifier. Roc names use only ASCII letters, digits and `_`. A package name starts with a lowercase letter. Some words are reserved (for example `app`, `package`, `module`, `import`, `if`, `match`, `for`). So `basic_cli` is valid. Talon applies these checks to the default alias, in order:

| # | Step | Rule |
| --- | --- | --- |
| R-AD15 | 1 | Change each `-` and `.` to `_`. |
| R-AD16 | 2 | If the result does not start with a lowercase letter, or has another character that is not a letter, digit or `_`, Talon stops. It asks for `--as <alias>`. |
| R-AD17 | 3 | If the result is a reserved word, Talon stops. It asks for `--as <alias>`. |
| R-AD18 | 4 | If the alias exists in the header for a different group or for an unmanaged entry (Design 4.2, R-H4), Talon stops. It asks for `--as <alias>`. It never adds a suffix. For an unmanaged entry, the message also says that `--as <that alias>` replaces it (R-AD38). |

R-AD19: `--as <alias>` sets the alias and skips the default rule. Talon still checks that the alias is a valid identifier, and that it is free or names an unmanaged entry (R-AD38). If the group is already in the header under another alias, `tln add` adds no entry. It reports that alias (see the group check in Design 4.3).

### An entry that is in the header

R-AD20: `tln add X` adds no entry when X is a header alias (form 1), or names a group that the header already has under the same alias:

| # | Case | Talon does |
| --- | --- | --- |
| R-AD21 | No selector (`tln add json`) | Changes nothing. Prints `json: someone/roc-json 2.1.0 is in the header` and names `tln update json`. Exit code 0. For an unmanaged entry (Design 4.2, R-H4), it prints the value as written and names no command. |
| R-AD22 | A selector (`tln add json@^3`) | The same as `tln update json@^3` (Resolution 9, 10): the entry moves inside the selector, also to a new series. Talon writes `talon.toml` as the table below gives for that selector. For an unmanaged entry, exit code 2, as `tln update` (Design 4.2, R-H9). |

R-AD38: `tln add <name>[@sel] --as <alias>`, where `<alias>` is an unmanaged entry (Design 4.2, R-H4), replaces that whole entry under the same alias with the release that `<name>[@sel]` selects (R-H3). The resolve, the check and the build run as for a new entry. The keyword `platform` of the entry stays, and R-C4 and R-AD32 apply to it. `talon.toml` gets what the table "What `tln add` writes to `talon.toml`" gives. A key that the alias already has stays and is the range of the new entry (R-I3). The output names the old value, as the platform note of R-AD31 does.

### What `tln add` writes to `talon.toml`

R-AD23: The key is the header alias. The header always gets the entry.

| # | Command | Header | `talon.toml` |
| --- | --- | --- | --- |
| R-AD24 | `tln add X` (no selector) | New entry, at the version that `strategy` selects (no selector, above) | Nothing. Talon does not create the file (G2). If the file exists, Talon adds no key: the implied range (Design 4.3) applies. |
| R-AD25 | `tln add X@1.2.3` (exact version) | New entry at 1.2.3 | Anchor `X = "=1.2.3"`. Talon creates the file if it is missing, because the user stated intent. |
| R-AD26 | `tln add X@^1.2`, `tln add X@1` (range or series) | New entry, at the version in range that `strategy` selects | Range `X = "^1.2"`, and `X = "^1"` for `@1`. Talon creates the file if it is missing. |
| R-AD27 | `tln add X@1.2.3 --no-pin` | New entry at 1.2.3 | Nothing, as for `tln add X`. A later `tln update` can raise the version inside the series (Design 4.1), as the implied range allows. |

R-AD28: An exact version is a hard pin by default. This keeps Resolution 1 consistent: `tln add parser@2.0.0` makes an anchor. `--no-pin` gives an exact start version with no hard pin. `tln update X@1.2.3 --no-pin` does the same for an entry that moves (Resolution 10). `--as` names one entry, so `tln add` with `--as` and 2 or more names stops with exit code 2.

### `tln add --platform`

R-AD29: `tln add --platform owner/repo[@sel]` sets the platform. A header has one platform (R-C3).

| # | Case | Talon does |
| --- | --- | --- |
| R-AD30 | No platform in the header | Adds it with the alias `pf`, or the `--as` alias |
| R-AD31 | A platform is in the header | Replaces it under the same alias, also when the new platform is another repo, and also when the old entry is unmanaged (Design 4.2, R-H4). The platform is free inside the selector. Other variables are held (Resolution 9). A package that names a platform must name the new one (R-C3), so it can need a move (prompt R-NI3). The `talon.toml` key of the old platform gets the new range (table in "What `tln add` writes to `talon.toml`"). |
| R-AD32 | The release is not a platform | Error with exit code 2 (R-C4) |
| R-AD33 | `tln add X` with no `--platform`, and X is a platform | Error with exit code 2 that names `--platform` |

### `tln remove`

| # | Case | Talon does |
| --- | --- | --- |
| R-RV1 | An entry that no app module imports | Removes the header entry, its `talon.toml` key and its `[overrides]` entry. Moves no other entry. Runs the whole-app check and the build (Resolution 4) on the new header, because the removed entry can have raised a shared version (Resolution 6). `--no-check` skips them. When the check finds a new error, Talon writes nothing. A new error in an app file gives exit code 11. A new error that blames a package gives exit code 10 (`no_tuple`), because `tln remove` moves no other entry. The error names the package and `--no-check`. |
| R-RV2 | An entry that an app module imports (the lexical scan of Resolution 4) | Stops with exit code 11 (`app_error`) and lists the `import` lines. `--force` removes it anyway and skips the check, because the app cannot check until the user changes the imports. |
| R-RV3 | The platform entry | Error with exit code 2. An app needs a platform. `tln add --platform` changes it. |
| R-RV4 | An entry with a `[patch]` entry (Resolution 7) | Also removes the `[patch]` entry. Keeps the files in `.talon/patches/<alias>/` and prints their path. |
| R-RV5 | An unmanaged entry: a path entry or a foreign URL (Design 4.2, R-H4) | Removes the whole entry as R-RV1 and R-RV2 give (the import scan and the check apply). Removes a `talon.toml` key and an `[overrides]` key of the alias when there is one. Never edits the file that a path entry names. |

## 3. Exit codes and JSON output

R-E5: Exit codes and the `--json` schema are part of the public interface. A change needs a new `schema` version (see below). A new failure kind gets a new code. Talon never reuses a code.

| # | Code | Kind | Meaning | Source |
| --- | --- | --- | --- | --- |
| R-EC0 | 0 | `ok` | The command did its work | |
| R-EC1 | 1 | `internal` | A Talon fault, or a compiler fault with no result | R-P7 (Resolution 4) |
| R-EC2 | 2 | `usage` | Bad flag, bad ref, ambiguous name, invalid alias, a resolve flag on a command that does not resolve, a `log:` snapshot with no registry, an interactive-only flag (`update -i`) in non-interactive mode, `--frozen` on a command that changes the header, `--json` with `tln x` or `tln run <name>`, no project file or no single current member (R-PD4, R-PD5, R-PD8), `--file` on a command that uses no project, a workspace rule (Design 4.4: members with different `roc:` pins, an alias that names two groups), `tln remove` of the platform, `tln patch` of the platform (Resolution 7, R-PA8), `--as` with 2 or more names (section 2), `--no-check` with a free nightly (Resolution 10, R-UP9) or in `tln roc use` (R-U4), `tln probe --share` with no registry, with no hash or with a bundle file (Resolution 4, R-PB6), `tln share login`, `logout` or `forget` with no registry (R-SH10), `tln publish` or `tln yank` with no registry or with no GitHub Actions OIDC token (Registry 4, R-AP27, Registry 7.2, R-YK3), `tln yank` of a tag with no indexed release (R-CM21), a check of `tln move` before it sends (R-MV2), a `github.com` repository that GitHub does not know or that is private, before a registry request (R-RG6), or `tln add`, `tln tool install` and `tln x` of a repo with no release that is a candidate (6.4, R-T10, R-AD35) | Sections 1, 2 and 4, Design 4.4, Resolution 4, 10, 11 and 13, 6.6 |
| R-EC10 | 10 | `no_tuple` | No tuple works. Talon prints the explanation. | Resolution 5 |
| R-EC11 | 11 | `app_error` | A new error in an app file, or `tln remove` of an alias that the app imports. Talon stops and reports. | Resolution 4 ladder step 2, section 2 |
| R-EC12 | 12 | `budget` | A probe budget is spent before a tuple was found | Resolution 4, R-P5 |
| R-EC13 | 13 | `consent` | A required prompt (section 4) has no answer: Talon is in non-interactive mode, and there is no `--yes` and no flag that gives the answer. Also: the person declined the GitHub login of `tln share login`, or its code expired (R-SH7), or the person answered No to a move of a held variable (R-NI3, Resolution 9, R-SP16). | section 4, section 1 |
| R-EC14 | 14 | `frozen` | The header or a patch does not match `talon.toml`: `--frozen` found a mismatch or a needed resolve, or the proxy found a stale patch | Resolution 12, R-PA6 |
| R-EC15 | 15 | `network` | A registry, GitHub or download error that a later run can fix (R-E6 for the registry) | 7.1, 7.3, R-E6 |
| R-EC16 | 16 | `integrity` | A hash or checksum does not match | 7.1, 6.2 R-CV4 and R-CV6, Design 8 |
| R-EC17 | 17 | `conflict` | Another process changed or uses what the command must change: a project file (the header, `talon.toml`) changed while the command ran (R-CC7), or a compiler to remove runs on Windows (R-CC10). Talon wrote nothing. Run the command again. | 7.4, R-CC7, R-CC10 |
| R-EC18 | 18 | `environment` | A program that Talon needs is not on `PATH`: `curl` or `wget`, `tar`, `xz` for a Zig archive, `sh` on Unix, or `powershell` on Windows (Design 6.2, R-HF11), or the program of a `tln run` step (R-RUN7). The message names the program. No selected compiler (Resolution 13, R-SO14). | Design 6.2, 7.5 |
| R-EC19 | 19 | `input` | A file that Talon reads is not valid: a TOML syntax error, or a known key with a value of the wrong type or form, in `talon.toml` or `config.toml` (for example a range that does not parse); a project header that does not parse; a table in a workspace `talon.toml` that Design 4.4 R-WS5 does not allow; a Talon file with a newer format or with bad content. The message names the file, and the line when there is one. | 6.1, R-TF1 to R-TF6, Design 4.4 |
| R-EC20 | 20 | `rejected` | The registry refused a write, and the same request gets the same answer: a token claim, a repository binding, a label with another hash, a release that is not a candidate, or a hash that the registry does not index. Fix the release or the workflow, then run the command again. The message gives the problem `type` and `detail`. | R-E6, Registry 4.2, R-AP21 |
| R-EC21 | 21 | `findings` | `tln audit` found a finding that fails (R-AU3): a yanked release, or a release whose asset was replaced | R-AU3 |

| Rule | Text |
| --- | --- |
| R-E1 | A command that runs a child process (`roc` proxy, `tln x`, `tln run`) exits with the exit code of that process (for `tln run`, the first step that fails, R-RUN7). Talon codes apply only to failures that Talon finds before or after the child runs. |
| R-E2 | A command that fails for two reasons exits with the lower code in the table above, except `ok`. |
| R-E3 | `--quiet` and `--json` do not change an exit code. |
| R-E4 | The exit code alone cannot tell a Talon failure in R-E1 from a child failure with the same code (for example 13). So when Talon fails before or after the child runs, its last line on stderr is `tln: error[<kind>]: <message>`. A script that must tell them apart reads that line. |
| R-E6 | Talon maps an answer of the registry (Registry 4.2, R-AP21) to an exit code with the table below, when no other rule handles that case (for example R-AD35 for ingests, Registry R-AP28). Reason: a CI release job must tell "fix the release" (20) from "try again later" (15). |

R-E6 mapping:

| Answer | Exit code |
| --- | --- |
| 400 `bad-request`, 415 `unsupported-media-type` | 1 (`internal`): a Talon fault or a version skew. The message names the registry URL and the Talon version. |
| 400 `unsupported-client` (Registry R-AP45) | 1 (`internal`). The message names the `minimum` of the answer: `tln <version> is too old for <registry URL>: update to <minimum> or later`. The text is a proposal (R-OUT2). |
| 413 `too-large` (Registry R-AP46) | 1 (`internal`). The message names the `field` and the `limit` of the answer. |
| 401, 403, 404, 409 or 422 to a write (`POST`, `PUT`, `DELETE`) | 20 (`rejected`) |
| 429, a 5xx answer, no answer, or an answer that is not problem details (for example a URL that is not a registry), and each other case | 15 (`network`) |

The `--json` contract:

| # | Rule |
| --- | --- |
| R-J1 | stdout holds exactly one JSON document, written when the command ends. There are no JSON lines. |
| R-J2 | Human text, progress and warnings go to stderr. With `--json`, stderr stays human text. A program reads stdout only. |
| R-J3 | The document has a fixed envelope: `schema` (integer, the version of the envelope and of all command data), `command`, `ok`, `data`, `error`. |
| R-J4 | `data` is a command object when `ok` is true, and `null` when `ok` is false. |
| R-J5 | `error` is `null` when `ok` is true. Otherwise it has `kind` (a name from the table above), `code` (its exit code) and `message`. It may have `details`. |
| R-J6 | A new field in `data` does not change `schema`. A removed field, a renamed field or a changed meaning gives a new `schema` number. |
| R-J7 | For an error answer of the registry (R-E6), `error.details` has `status` (the HTTP status) and `type` (the problem type of Registry R-AP21, for example `/errors/label-conflict`). A program reads `details.type`, not the message. |

Example, for `tln add parser@2.0.0` (data fields are shortened). Phase P2, as the example in section 1:

```json
{
  "schema": 1,
  "command": "add",
  "ok": true,
  "data": {
    "snapshot": "log:184467",
    "probes": 3,
    "downloads": 0,
    "added": [{ "alias": "parser", "name": "lukewilliamboswell/roc-parser", "version": "2.0.0" }]
  },
  "error": null
}
```

Example of a failure, for `tln add parser --json` (non-interactive) with a required compiler download. Phase P2: a short name needs the registry:

```json
{
  "schema": 1,
  "command": "add",
  "ok": false,
  "data": null,
  "error": { "kind": "consent", "code": 13, "message": "1 compiler download (70 MB) needs consent. Pass --allow-downloads or set TALON_AUTO_INSTALL=yes." }
}
```

### Who decides the output

The design fixes the facts that a command decides. Most commands have no output example. These rules say who writes the output of such a command:

| # | Rule |
| --- | --- |
| R-OUT1 | The design fixes the exit codes, the `--json` envelope (R-J1 to R-J5), the facts that each command decides, and the design examples (`TESTING.md` TW16). It does not fix the exact human text of other output. |
| R-OUT2 | When the design gives no output for a command or a case, the slice proposes it: the human text (stdout and stderr) and the `data` fields (`TESTING.md` 7). The human accepts or changes the proposal at the test review. A missing output is not an open question (TW17), so the agent does not stop for it. A missing fact (what the command decides) is still a question. |
| R-OUT3 | The accepted `data` fields go in the catalog below, in the same commit as the slice. The L3 expected files (`TESTING.md` 3.1) fix the human text. The human text is not a contract: a program reads `--json`. |
| R-OUT4 | `data` holds each fact that the human text prints. A program never needs to parse human text. |
| R-OUT5 | R-J6 applies to each catalog row from the first Talon release (6.5). Before that release, a slice can change a row with no new `schema` number. `schema` is 1 at the first release. |

Output catalog. One row for each command, or each case with its own `data`. A slice adds or changes rows (R-OUT3).

| Command | `data` fields | Human text | Status |
| --- | --- | --- | --- |
| `install` with names (and `add`) | `snapshot`, `probes`, `downloads`, `added[]` (`alias`, `name`, `version`). The example above shortens the list. | Example in section 1 | Partial: the first slice of `add` completes it |
| `upgrade` | Not yet | Example in Resolution 10 | Partial |
| A resolve with no tuple (exit 10) | `error.details`: not yet | Example in Resolution 5 | Partial |
| `audit` (R-CM14) | `index` (`registry` or `direct`), `checked` (the count of hashes), `notes[]` (for example `no-yank-data`, `unused-ignore`), `findings[]`: `name`, `group`, `version`, `hash`, `alias` (`null` for a transitive entry), `via` (the header aliases that need it, `[]` for a header entry), `reason` (R-AU2), `fails` (R-AU3), `ignored` (R-AU10), `since` (a time, or `null`), `yank` (`{reason, by}`, or `null`), `new_hash` (the new asset hash, or `null` when the index does not know it), `successor` (a full name, or `null`, R-AU13), `fix` (R-AU8). With exit code 21, the same object is in `error.details` (R-AU5). | Below the table | Proposal (R-OUT2), P3 |
| A registry write that the registry refused (exit 20) | `error.details`: `status`, `type` (R-J7) | `tln: error[rejected]: <detail> (<type>). <what to fix>` | Proposal (R-OUT2) |
| `move` (R-CM22) | `name` (the old name), `result` (`moved`, `offered`, `removed` or `unchanged`), `successor` (a full name, or `null`), `offer` (a full name, or `null`), `state` (the `repos` state, Registry R-TP11) | `moved: <old-name> to <successor>. Users see it in tln outdated, and follow it with tln update <alias>.` For an offer: `offered: <old-name> to <new-name>. To accept, run tln move <old-name> in a workflow_dispatch job of <new-name>.` For `--undo`: `removed: the successor of <old-name>` | Proposal (R-OUT2), P3 |
| `yank` (R-CM21) | `name`, `tag`, `version`, `log_index`, `yanked` (true or false), `reason` (or `null`), `changed` (false when the release was already in that state, Registry R-YK1) | `yanked owner/repo 1.2.0 (tag 1.2.0): <reason>`, or `unyanked owner/repo 1.2.0 (tag 1.2.0)` | Proposal (R-OUT2), P3 |

Human text of `tln audit` (a proposal, R-OUT2, P3):

```text
audit: 14 packages checked (registry)
yanked          json 2.1.0     roc-lang/json                   "parse bug, use 2.1.1"                         header: json
asset replaced  parser 1.0.2   lukewilliamboswell/roc-parser   GitHub has 9fK3..., the header has FrnJ4R...   via json
repo missing    csv 1.1.0      someone/roc-csv                 the repository is deleted or private           header: csv
warning: release missing  util 0.3.0  someone/roc-util  header: util
warning: moved  xml 0.4.0  someone/roc-xml  successor: acme/roc-xml  header: xml
ignored: someone/roc-old@1.0.0:yanked
3 findings, 2 warnings, 1 ignored.
fix: tln update json. parser: update json (tln why parser), or use [overrides]. csv: replace the package, or ignore it. xml: tln update xml.
```

With `direct`, the last line is `note: no yank and advisory data without a registry` (R-AU4).

Warning of a resolve before P3 (R-AU7), and of the R-DI15 case (a proposal, R-OUT2):

```text
warning: roc-lang/json 2.1.0 (tag 2.1.0) has a new asset 9fK3... on GitHub. The header has FrnJ4R.... Talon does not use the new asset. Ask the author to release a new version.
```

Error of a refused registry write (exit code 20, R-E6, a proposal, R-OUT2):

```text
tln: error[rejected]: the registry has roc-lang/json 2.1.0 with another hash (/errors/label-conflict). The tag was released again. Release a new version.
tln: error[rejected]: token claim ref is refs/heads/main, the asset URL has the tag 2.1.0 (/errors/forbidden). Run tln publish in a job for the tag.
tln: error[network]: the registry answered 502 (/errors/upstream) 4 times. Try again later.
```

## 4. Prompts and non-interactive mode

R-NM1: Talon is in non-interactive mode when one of these is true. Otherwise it is in interactive mode.

| Source | Value that turns it on |
| --- | --- |
| `CI` | `true` or `1` (any case). GitHub Actions, GitLab CI and most other CI systems set it. |
| `DEBIAN_FRONTEND` | `noninteractive` |
| `NONINTERACTIVE` | `1` or `true` |
| Terminal | stdin or stderr is not a TTY |
| Flag | `--json` |

R-NM2: `TALON_INTERACTIVE` overrides the three variables above. `1` turns on interactive mode, also when `CI` is set. `0` turns on non-interactive mode. It does not override the terminal row or `--json`: with no TTY, or with `--json`, Talon never prompts (R-NR1).

R-NM3: Non-interactive mode changes one thing: a prompt does not show, and Talon uses a fixed answer instead. All other behavior is the same in both modes: what the command does, what it writes, its output and its exit codes. Color and progress output follow the TTY of stderr and `NO_COLOR`, not this mode.

Each prompt is one of three kinds:

| # | Kind | When it applies | Non-interactive answer |
| --- | --- | --- | --- |
| R-NM4 | Default | The default is safe with no person to read it: it confirms what the command names, or it declines extra work | The interactive default |
| R-NM5 | Required | The prompt chooses something that the user did not name: a compiler, a move of a held variable, a file edit that the command does not name, or a build that was not checked online | None. Talon stops with exit code 13 (`consent`, section 3). The error names `--yes` and each flag that gives an answer. It writes nothing. |
| R-NM12 | Consent | The prompt asks to send data that the command does not need (R-NI16) | No, and Talon writes no answer. `--yes` does not answer it. Only the person answers it. A setting can make the prompt not needed: `tln share on` and `tln share off` (section 1, R-SH11). |

So a non-interactive run does what an interactive run does when the user presses Enter at each "Default" prompt. It never takes an answer that the interactive default does not give.

R-NM6: When Talon answers a prompt without a prompt (non-interactive mode, `--yes` or an answer flag), it prints the answer to stderr, for example `kept 3 tools, removed 5 compilers (1.2 GB)`. The text is the same in both modes.

R-NM7: A picker (`tln update -i`) is not a prompt: it is the whole command. In non-interactive mode it stops with exit code 2 (`usage`).

`--yes` works the same in both modes:

| # | Prompt | `--yes` gives |
| --- | --- | --- |
| R-NM8 | Yes/no | Yes. For a prompt with the default No (R-NI3, R-NI4, R-NI9), this is not the answer of Enter. A Consent prompt (R-NM12) is not answered: its answer stays No. |
| R-NM9 | Options | The default option (R-NI8 option 1, R-NI10 option 1) |

R-NM10: So `--yes` answers every prompt of the command at once, except a Consent prompt (R-NM12). Reason: `curl | sh -s -- --yes` must not give consent that nobody read. Each Required prompt also has its own answer flag, which answers only that prompt. A script should use these flags, not `--yes`. An answer flag has priority over `--yes`.

Each prompt in the design files has an id `R-NIn`. Search for the id to find the place. Each new prompt must get an id and a row in this table.

| Id | Command | Prompt | Interactive default | Kind | Non-interactive result | Answer flags | Where |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R-NI1 | `install`, `add` | Rename a stale key in `talon.toml` | Yes | Required | Exit 13, writes nothing | `--rename-keys`, `--yes` | Design 4.3 |
| R-NI2 | `update -i` | Pick the packages to update | None | Picker | Exit 2 | Name the packages: `tln update X Y` | Resolution 9 |
| R-NI3 | `add`, `update`, `upgrade`, `install` | Move a held variable | No | Required | Exit 13, writes nothing | `--allow-moves`, `--yes` | Resolution 9 |
| R-NI4 | `add`, `update`, `upgrade`, `install`, `probe`, `verify` | Optional compiler downloads for probes | No | Default | No download. Uses installed compilers only. | `--probe-downloads`, `--yes` (inside the cap, R-DL6) | 6.2, R-DL4 |
| R-NI5 | `add`, `update`, `upgrade`, `install`, `remove`, `probe`, `verify`, `roc use` (the baseline compiler, R-U3), the `roc` proxy | A required compiler download that the command does not name, also the baseline compiler (Resolution 4) | No (yes for the proxy, R-DL3) | Required | Exit 13 | `--allow-downloads`, `--yes`, `TALON_AUTO_INSTALL=yes` | 6.2, R-DL4 |
| R-NI6 | `roc install`, `roc use`, `roc default`, `roc update` | Download the compiler that the command names, and Zig for a source build | Yes | Default | Downloads | None needed | 6.2, 6.6 |
| R-NI7 | `cache clean` | Confirm the removal and its size | Yes | Default | Removes | `--dry-run` shows it first | 6.3 |
| R-NI8 | `tool install`, `x` | Select a compiler release: download the pin, try installed releases, or cancel | Download the pin | Required | Exit 13 | `--roc pinned`, `--roc installed`, `TALON_AUTO_INSTALL=yes` (option 1), `--yes` | 6.4 |
| R-NI9 | `tool install`, `x` | Use a cached build that was not checked online (R-B7) | No | Required | Exit 13 | `--allow-unchecked`, `--yes` | 6.4 |
| R-NI10 | `tool rm talon` | What to remove with Talon | Keep the tools, remove the rest | Default | Keeps the tools, removes the rest (R-RM3) | `--remove-tools`, `--keep-all`, `--dry-run` | 6.5 |
| R-NI11 | Removed in round 2. R-R2 prints a note and does not prompt, because `--yes` would change the result id. | | | | | | 6.6, R-R2 |
| R-NI12 | `upgrade` with the nightly free, `init` | Download the newest nightly | Yes | Default | Downloads | `--yes` | Resolution 10, R-UP6, section 5 |
| R-NI13 | `setup` | Replace a `roc` in the bin dir that Talon did not write | No | Default | Keeps the old `roc`. Does not install the launcher. | `--replace-roc`, `--yes` | 6.7, R-ST2 |
| R-NI14 | `setup` | Add the bin dir to `PATH` in the shell profile | Yes | Default | Adds the line | `--no-modify-path`, `--yes` | 6.7, R-ST4 |
| R-NI15 | `install.sh`, `install.ps1` | Confirm the install | Yes | Default | Installs | `--yes`, `-Yes`, `TALON_YES=1` | 6.5, R-IS4 |
| R-NI16 | The first interactive run (R-SH11) | Share the probe results of public packages with the registry (R-SH1). The prompt names what Talon sends (R-SH3), says that the registry keeps each result with a random id of this machine until `tln share forget` or until its compiler is 12 months old (Registry 6.1, R-CT6, R-CT15), says that reads do not need it, and names `tln share off`. | No | Consent | No prompt, and `share` stays not set (off). The next interactive run asks. | None: `tln share on` or `tln share off` sets `share` first | 1, R-SH11 |

R-NM11: Not prompts: an invalid alias, an ambiguous name, a short name in `tln x` or `tln tool install` with no local match, and a binary name clash stop the command in both modes with exit code 2 and name the flag to use (`--as`, a full name).

Rules for a new prompt:

| # | Rule |
| --- | --- |
| R-NR1 | A prompt writes to stderr and reads from stdin. It never prompts when stdin or stderr is not a TTY, even if no variable is set. Exception: on Windows, until basic-cli has the TTY test (Design 6.2, R-HF1), Talon cannot see the TTY state. It prompts, and the end of input gives the non-interactive answer. |
| R-NR2 | A prompt shows its default and what the default costs (size, count). |
| R-NR3 | A destructive prompt (removal, overwrite) is "Default" only if the command names what it removes. Otherwise it is "Required". R-NI10 counts as "Default": besides Talon, it removes only the compilers and Talon data, which nothing uses without Talon (R-RM3). |
| R-NR4 | Each picker has a command form that names the choice. |
| R-NR5 | A prompt must not change behavior outside its answer. A new mode-specific behavior is a design error. |
| R-NR6 | Each Required prompt has its own answer flag. `--yes` alone is not enough. |

## 5. `tln init`

| # | Item | Rule |
| --- | --- | --- |
| R-IN1 | Template | `app` (default) or `package`. An app uses the newest `roc-lang/basic-cli` release. `--platform <name>` selects another platform. |
| R-IN2 | Nightly | Talon resolves the new header as `tln upgrade` does (Resolution 10). An app gets the newest platform release and the newest nightly that pass the ladder (Resolution 4) on the template. A package gets the newest nightly that passes `roc check`. |
| R-IN3 | Downloads | The consent rules R-DL1 to R-DL6. The newest nightly is a download that the command names (prompt R-NI12). |
| R-IN4 | Pin | The nightly goes in the `roc:` entry of the header. Talon writes no `.roc-version` (Resolution 13). |
| R-IN5 | `talon.toml` | Not created (G2) |
| R-IN6 | CI file | `.github/workflows/ci.yml` for GitHub Actions, on `ubuntu-latest`. Steps: (1) install Talon with `curl -fsSL <releases>/download/v<version>/install.sh \| sh -s -- --yes --version <version>` (6.5), where `<version>` is the version of the `tln` that ran `init`. So a CI job does not take a new Talon release before a person changes this line: R-T9 does not apply to the install scripts. `tln setup` finds `GITHUB_PATH` and adds the bin dir there (R-ST4), so the later steps find `tln` and the `roc` launcher. (2) `tln install --frozen`. (3) `roc check`, then `roc test`. From P3, (4) `tln audit` (section 1, R-AU1). A finding that fails (R-AU3, exit code 21) fails the job, and `[audit] ignore` (R-AU9) is the way to accept one. Reason: `--frozen` sees no yank (R-AU6), and the job is the place where a team sees a yank of a dependency. The job sets `TALON_AUTO_INSTALL=yes` (required downloads only, R-DL5). `--ci none` writes no CI file. |
| R-IN7 | Existing files | Talon never overwrites a file. If `main.roc` exists, it stops with exit code 2. |
| R-IN8 | Template text with `--platform` | With `--platform <name>` (R-IN1), the body of `main.roc` is the smoke app of Resolution 4, R-SM2 for that platform, with one change: the body of each stub is `crash "write the app"`. The ladder of R-IN2 builds it for the target of Resolution 4, R-TG6. Reason: Talon knows no example of another platform, and the stub needs no file other than `main.roc` (7.3, R-DI7). A tool of the platform then writes a real body (for example `roc-cfw init`). When the `requires` of the platform has a type that R-SM2 cannot fill (its row "Any other type"), Talon writes nothing and stops with exit code 2. The message names the type. A `--platform` ref that names `roc-lang/basic-cli` gives the basic-cli template of R-IN1, not the stub. |

## 6. Toolchain manager

How Talon selects the compiler for one run is in Resolution 13.

### 6.1 Directory layout

R-LY1: The cache root holds these items. The second column names the program that writes each one:

```text
$XDG_CACHE_HOME/roc/          (else ~/.cache/roc/)
  packages/<hash>/              roc      unpacked package (Talon may pre-fill it, 7.2)
  packages/<hash>.deps.json     roc      sidecar, rebuilt by roc if missing
  compat-<id>/                  roc      build cache per compiler build ($ROC_CACHE_DIR if set)
  nightly-<tag>/, debug-<sha>/  roc      build caches of older compilers (seen up to nightly 10-09)
  toolchains/<id>/roc           talon    installed compilers (<id>: nightly tag, release, git-<sha8>, link-<name>, copy-<name>)
  toolchains/<id>/.talon.json   talon    source URL, sha256 or commit, ref typed, compat id, install time. Written last (R-CC4).
  toolchains/<id>/.last-use     talon    the time of the last use (R-CC9)
  toolchains/<id>.lock          talon    install lock of <id> (7.4, R-CC3, R-CC4)
  toolchains/zig-<version>/     talon    Zig for source builds (6.6), with the lock zig-<version>.lock
  talon/index/                  talon    cached registry and GitHub index responses (ETag, 7.3)
  talon/compat.db               talon    probe results, first-seen compiler sha256 (R-CV6), the share queue (R-SH4)
  talon/projects.json           talon    known projects, for GC (R-PD9 to R-PD13). Lock: projects.json.lock (R-CC6).
  talon/path-roc.json           talon    id of the roc on PATH, keyed by path, size and modification time (Resolution 13, rank 7)
  talon/tmp/<16hex>/            talon    temp copies of an app for probes (R-CC2)
  talon/gc.lock                 talon    lock of tln cache gc (R-CC10)
  talon/x/<build digest>/       talon    binary and manifest built by tln x (6.4, R-B1 to R-B8)
```

R-LY2: User settings and tools are not in the cache, so a cache cleanup cannot remove them:

```text
$XDG_CONFIG_HOME/talon/config.toml   (else ~/.config/talon/)        user settings, see below
$XDG_DATA_HOME/talon/bin/            (else ~/.local/share/talon/)   tool binaries (6.4, R-T3)
$XDG_DATA_HOME/talon/tools.json                                     tool manifests (6.4, R-T4)
$XDG_DATA_HOME/talon/share.json                                     contributor id, totals, JWT (1, R-SH5 to R-SH7)
```

R-LY3: `config.toml`, `tools.json` and `share.json` also have a lock file next to them: `config.toml.lock`, `tools.json.lock`, `share.json.lock` (R-CC6).

```toml
# config.toml
default-roc = "nightly-2026-10-09-258ab27"   # tln roc default writes it. A full id only (section 2).
registry = "direct"                          # or a URL (section 1, registry precedence)
nightly = true                               # the nightly switch (Resolution 1, R-NS1). talon.toml has priority.
min-release-age = "2d"                       # the default (Resolution 2, R-C7). talon.toml [resolution] has priority.
gc-age = "30d"                               # the default GC age (6.3)
share = true                                 # share probe results (section 1, R-SH1). Not set: off.

[probe]                                      # same keys as [resolution] probe in talon.toml
slots = 12
max-toolchains = 10
```

R-LY4: A value in a project `talon.toml` has priority over `config.toml`. A flag or an environment variable has priority over both.

The paths above are for Linux and macOS. On Windows:

| # | Item | Linux, macOS | Windows |
| --- | --- | --- | --- |
| R-LY5 | Cache root (packages, build caches, `toolchains/`, `talon/`) | `$XDG_CACHE_HOME/roc`, else `~/.cache/roc` | `%LOCALAPPDATA%\roc`, as roc (`roc:src/compile/compile_build.zig:1602-1608`). roc reads `XDG_CACHE_HOME` first on Windows too, and so does Talon. |
| R-LY6 | Config | `$XDG_CONFIG_HOME/talon`, else `~/.config/talon` | `%APPDATA%\talon` |
| R-LY7 | Data (tool binaries, `tools.json`, `share.json`) | `$XDG_DATA_HOME/talon`, else `~/.local/share/talon` | `%LOCALAPPDATA%\talon` |
| R-LY8 | Bin dir (6.7, R-ST1) | `~/.local/bin` | `%USERPROFILE%\.local\bin`, as uv |
| R-LY9 | `PATH` (6.7, R-ST4) | One line in the shell profile | The user `Path` value of the environment |

#### Talon files: formats and errors

| # | Rule |
| --- | --- |
| R-TF1 | Each JSON file that Talon writes has a top-level integer `format`: `tools.json`, `projects.json`, `share.json`, `path-roc.json`, `.talon.json`, and the manifests in `talon/x/`. `compat.db` keeps it in `PRAGMA user_version`. The pages in `talon/index/` are API answers and have no format of their own. |
| R-TF2 | A new field does not change `format`. Talon ignores a field that it does not know, and keeps it when it writes the file. A removed field, a renamed field or a changed meaning gives a new `format` number, as R-J6 does for `--json`. |
| R-TF3 | Talon migrates a file with an older `format` when it writes it next (R-CC1). Talon never writes a file with a newer `format`. A file that Talon can make again (`path-roc.json`, a manifest in `talon/x/`) it then ignores: it works with no cache. For each other file, it stops with exit code 19 (`input`) and names the file and `tln tool update talon`. So a repair to an older Talon (6.5, R-S4) works when no format changed between the two releases. The release notes of Talon name each format change. |
| R-TF4 | A `talon.toml` or `config.toml` that is not valid TOML, or a known key with a value of the wrong type or form (a range that does not parse, an unknown `strategy`), stops the command with exit code 19. The message names the file, the line and the key. An unknown key or table gives a warning that names it, and the command goes on, as in Cargo: a newer Talon can know the key. |
| R-TF5 | A project header that the header parser cannot read stops a command that uses a project with exit code 19, with the file and the line. The `roc` proxy does not stop: it uses no `roc:` pin (Resolution 13, rank 3), and roc reports the error itself. |
| R-TF6 | A Talon file with content that does not parse (for example after a disk fault) stops the command with exit code 19 and names the file. A file that Talon can make again (R-TF3) is the exception: Talon deletes it, prints a warning and makes it again. |

### 6.2 The `roc` proxy

| # | Item | Behavior |
| --- | --- | --- |
| R-PX1 | Install | `tln setup` puts the `roc` launcher in the bin dir: a hard link or a copy of `tln`. `tln` runs in proxy mode when its program name is `roc` (6.7, R-ST7, R-ST8). |
| R-PX2 | Dispatch | Talon selects the compiler (Resolution 13), writes its `.last-use` (R-CC9), and runs it in place of itself (Design 6.2, R-HF6: `execve` on Unix, a child with inherited stdio on Windows and until the upstream PR). The exit code passes through (R-E1). Cost target: under 5 ms. |
| R-PX3 | roc commands | The proxy passes each roc command to the selected compiler with no change, also `roc install` and `roc run <name or bundle URL>`. roc keeps such an install for one compiler version (Design 2). After the selected compiler changes, `roc run <name>` does not find the install, and the user runs `roc install` again. This is roc behavior: Talon does not track, move or remove roc installs. |
| R-PX4 | Missing compiler | Follows `TALON_AUTO_INSTALL` and the consent rules R-DL1 to R-DL5 (see "Download consent" below). Default `ask`. Modeled on Go `GOTOOLCHAIN`. There is no `--no-auto-install` flag: `roc` flags go to the compiler. Use `TALON_AUTO_INSTALL=no`. |
| R-PX5 | Patches | Adds `--replace-dep` for each `[patch]` entry. A stale patch (Resolution 7, R-PA6) stops the proxy before the compiler runs, with exit code 14. |
| R-PX6 | Cache paths | Sets `XDG_CACHE_HOME` and `ROC_CACHE_DIR` to canonical absolute paths. With `..` in `XDG_CACHE_HOME`, `roc check` prints "No errors found" for any app (Q15). Probes use the same rule. |
| R-PX7 | Opt out | `TALON_PROXY=0` runs the selected compiler with no extra work. |

R-CV7: Compiler sources: release assets of `roc-lang/nightlies`. Archives are `.tar.gz` (Linux, macOS) and `.zip` (Windows), about 70 MB each.

| # | Rule |
| --- | --- |
| R-CV1 | With a registry, Talon lists the compiler releases with `GET /v1/toolchains` (Registry 4). It keeps the rows in `talon/index/` and asks only for the rows after the largest log index that it has (Registry R-AP47). With `direct`, it lists the releases of `roc-lang/nightlies` with the list call of R-DI2 (7.3). A release is a nightly when its tag is a nightly tag in one of the two forms that roc reads (Design 2): `nightly-YYYY-MM-DD-<sha>`, or with the month as an English name, `nightly-2026-July-31-123c5d7`. The id of a nightly is its tag text. A pin in the other form names the same nightly when the date and the sha are equal. Talon does not rewrite such a pin (R-H1), and writes the tag text in a new pin. R-DI3 applies: Talon skips a draft and a prerelease. Talon knows no source of compiler releases yet (Resolution 1, R-NS2), so the list has no release. A design change names the source when roc publishes its first release. |
| R-CV2 | The asset for a host is the one asset whose name starts with `roc_nightly-<target>-` and ends with `.tar.gz`, or `.zip` for Windows, with `<target>` from the table below. Talon does not compare the date or the sha in the asset name with the tag: 3 releases have another sha there, for example `nightly-2026-February-10-c95f04d` has `roc_nightly-linux_x86_64-2026-02-10-ea7058b.tar.gz`. A release with 2 or more such assets for a host is not a candidate on that host. Other assets are not compilers, for example `roc_nightly-source-*` and `*.wasm.zst`. A nightly with no asset for the host is not a candidate on that host. A source build (6.6) is the other way to get it. |
| R-CV3 | The sha256 of the asset comes from one source. With `direct`: the `digest` field (`sha256:<hex>`) of the asset in the answer of R-CV1. GitHub computes it at upload (Design Q20). With a registry: the sha256 of `GET /v1/toolchains`. The registry copies it from the same `digest` the first time it sees the nightly, and never changes it. So a later swap of the asset on GitHub gives a mismatch for registry users. |
| R-CV4 | Talon computes the sha256 of the download before it extracts it. A mismatch, or an asset with no sha256, stops the install with exit code 16 (`integrity`). Talon deletes the download. There is no override. |
| R-CV5 | `.talon.json` (6.1) records the sha256 and its source: `github-digest` or `registry`. |
| R-CV6 | Trust on first use. The first time Talon sees a sha256 for a compiler asset (tag and target), from either source in R-CV3, it records it in `talon/compat.db`. That file stays after `tln cache clean --all` and `tln roc rm` (6.3), and the index cache does not. When a later list gives another sha256 for the same tag and target, Talon stops with exit code 16. The error names the tag, both values and their sources. There is no override: that tag is not a candidate on this machine, and the user selects another compiler. An installed compiler with that tag stays in use, because its bytes match the first value. |

R-CV8: Asset targets, as in the nightly `nightly-2026-10-14-38a3029`:

| Host | `<target>` | Archive |
| --- | --- | --- |
| Linux x86_64 | `linux_x86_64` | `.tar.gz` |
| Linux arm64 | `linux_arm64` | `.tar.gz` |
| macOS arm64 | `macos_apple_silicon` | `.tar.gz` |
| macOS x86_64 | `macos_x86_64` | `.tar.gz` |
| Windows x86_64 | `windows_x86_64` | `.zip` |
| Windows arm64 | `windows_arm64` | `.zip` |

A nightly can lack the asset of a host: for example `nightly-2026-10-14-38a3029` has no `windows_arm64` asset, and older nightlies have one. Such a nightly is not a candidate on that host (R-CV2).

#### Download consent

R-DL7: One rule set covers each command that downloads a compiler or Zig: `add`, `update`, `upgrade`, `install`, `remove`, `verify`, `probe`, `roc install`, `roc use`, `roc default`, `roc update`, `tool install`, `x`, `run` (the build of a project tool, 6.4 R-PT9), the build of a project tool in `install` and `install --frozen` (6.4, R-PT6), the `roc` proxy, and the Zig install of 6.6. Other sections refer to these rules and do not repeat them.

| # | Rule |
| --- | --- |
| R-DL1 | Talon asks once for each command, not once for each download. The prompt shows how many downloads can happen and their total size. A download that is not in the prompt does not start. |
| R-DL2 | A required download is one without which the command cannot finish. Examples: the `roc:` pin that the proxy must run, the compiler of `tool install`, Zig for a source build, the compiler of the baseline check when it is not installed (Resolution 4, "Baseline check"). An optional download only widens a probe search (Resolution 4, R-P5). |
| R-DL3 | In interactive mode (section 4), Talon prompts. Default answer: yes for a command that names the download (`roc install`, `roc use`, `roc default`, `roc update`, `tool install`, `x`, the Zig of `roc install`, the newest nightly of `upgrade` and `init`). Yes for the `roc` proxy, because it cannot run without the compiler. No for all other commands. Prompts R-NI4 to R-NI6 and R-NI12 (section 4). |
| R-DL4 | In non-interactive mode (section 4), Talon never prompts. A download that a `tln roc` command names (`roc install`, `roc use`, `roc default`, `roc update`, and the Zig that the build needs) starts: the command is the consent (R-NI6). The newest nightly of `tln upgrade` and `tln init` also starts (R-NI12). Any other required download fails with exit code 13 and an error that names `--allow-downloads` and `TALON_AUTO_INSTALL=yes` (R-NI5). An optional download does not start. Talon prints `skipped N compiler downloads (<size>), pass --probe-downloads` and uses the installed compilers only (R-NI4). |
| R-DL5 | `--yes` (global, section 1) accepts every prompt of the command, downloads included. `TALON_AUTO_INSTALL=yes` accepts only required compiler and Zig downloads (R-NI5, and option 1 of R-NI8), in the proxy and in every other command. `--allow-downloads` gives the same answer for one command. The proxy has no Talon flags, so it uses the variable. It answers no other prompt: not optional probe downloads (R-NI4), not a key rename (R-NI1), not a move (R-NI3), not a build that was not checked online (R-NI9). `TALON_AUTO_INSTALL=no` refuses each required download with no prompt, with exit code 13, in both modes. |
| R-DL6 | Consent never goes past the cap `probe.max-toolchains` (Resolution 4, R-P5) for optional downloads. With `probe.max-toolchains = 0`, Talon does not offer an optional download, and prompt R-NI4 does not show. |

The proxy runs inside build scripts, and `roc` flags go to the compiler. So the proxy has no Talon flag. `TALON_AUTO_INSTALL` sets its behavior:

| # | Value | Missing compiler, interactive | Missing compiler, non-interactive (section 4) |
| --- | --- | --- | --- |
| R-DL8 | `ask` (default) | Prompt R-NI5 (R-DL3), then install and run | Error that names `TALON_AUTO_INSTALL=yes` and `tln roc install <id>`. Exit code 13 before the compiler runs. |
| R-DL9 | `yes` | Install and run, no prompt. For CI. | Same |
| R-DL10 | `no` | Error, no prompt | Same |

### 6.3 Garbage collection

| # | Item | roc today | `tln cache gc` |
| --- | --- | --- | --- |
| R-GC1 | Files inside build caches | Expires after 30 days, in the background | Leaves to roc |
| R-GC2 | `nightly-<tag>/`, `debug-<sha>/` dirs | Never removed | Removes a dir when no file in it changed in the GC age. Compilers from 2026-10-05 do not write them. (3.1 GB here.) |
| R-GC3 | `compat-<id>/` dirs | Never removed | Removes the dir of each compiler that GC or `tln roc rm` removes. Removes another dir only when no file in it changed in the GC age. So the dir of a compiler that Talon did not install (the `roc` on `PATH`, Resolution 13 rank 7) stays while that compiler is in use. |
| R-GC4 | `packages/<hash>/` | Never removed | Removes it if no known project used it in the GC age, and nothing in it changed in the last day: a resolve can read a new candidate that is in no closure yet (7.3, R-DI7). The bundle of a `[tools]` URL of a known project counts as used by that project (6.4, R-PT14) |
| R-GC5 | Toolchains | n/a | Keeps the default, and the toolchains that a known project pins and used in the GC age. Never removes a toolchain that an install holds or that a run used in the last day (R-CC10). Never removes a `link-*` or `copy-*` entry: the user made it by hand (6.6, R-LK2), so only `tln roc rm` removes it. A `git-*` build follows the rule of a nightly (R-R6). |
| R-GC6 | Temps and `.trash` dirs that a crash left (R-CC2) | n/a | Removes them when they are older than 1 day |
| R-GC7 | `talon/x/<build digest>/` (binaries of `tln x` and of project tools, 6.4) | n/a | Removes an entry that no `tln x` run used in the GC age, except an entry whose bundle hash is a `[tools]` URL of a known project that was used in the GC age (6.4, R-PT14) |
| R-GC8 | App installs of `roc install` (Design 2) | Never removed. They are outside the cache root. | Leaves to roc |

R-GC9: The GC age is `gc-age` in `config.toml` (6.1). The default is `30d`, the same as the expiry of roc build-cache files (Design 2.2). Last uses are the times that Talon records (R-PD9, R-CC9, R-X2), compared with the clock of Talon (`TALON_NOW`, section 1). The age of a file in a build-cache dir is its modification time, compared with the real clock.

R-GC10: The compat id is a build-time hash that `roc` does not print. Talon learns it at install: it runs one `roc check` on an empty file and records which `compat-<id>/` dir the run touched. Upstream request: print the id in `roc version --verbose`.

R-GC11: `tln cache gc --dry-run` prints what it would free. GC can run while builds and other `tln` commands run: the rules are in 7.4 (R-CC10).

`tln cache clean` removes cache content on request, with no age rule. `gc` keeps what a known project uses. `clean` does not.

| # | Command | Removes | Keeps |
| --- | --- | --- | --- |
| R-GC12 | `tln cache clean` | `talon/index/` and `talon/x/` | Everything else |
| R-GC13 | `tln cache clean --all` | The above, and `packages/`, `compat-<id>/`, `nightly-<tag>/`, `debug-<sha>/` | Toolchains, tools, `talon/compat.db`, `talon/projects.json` |

R-GC14: `tln cache clean` never removes a toolchain or a tool: use `tln roc rm` (6.6) or `tln tool rm` (6.4). It shows the size to free and asks for confirmation (prompt R-NI7, section 4, default yes). In non-interactive mode it removes with no prompt: the command names what it removes, and Talon can fetch all of it again. `--dry-run` prints what it would remove and removes nothing.

### 6.4 Global tools

`tln tool install owner/app` builds a Roc app from source and puts the binary on `PATH`, as `cargo install --locked` and `uv tool install` do.

`npm i -g` has a known problem: a global script runs with the `node` that is on `PATH` now, and that can be a different version from the one used at install. A Roc tool does not have this problem, because the nightly is used only at build time:

| | `npm i -g` | `tln tool install` |
| --- | --- | --- |
| What is installed | Scripts | A native binary with the platform host linked in |
| Toolchain needed at run time | Yes, the shared `node` | No |
| Two tools that need different versions | They share one `node` | Each binary is self-contained |

roc has its own `roc install <name> <bundle URL>` and `roc run <name>` (Design 2). It keeps one install for each compiler version, so a change of the selected compiler hides the install. `tln tool install` keeps the binary apart from any compiler (R-T5) and puts it on `PATH` (R-T3). Both build the same source: the app bundle of the release (R-T10).

R-T11: Install flow:

```text
tln tool install owner/app
  |
  v
resolve the release online (yank and advisory check)
  |
  v
a build of this app is already on this machine (R-B1, R-B2)? --yes--> take it over (R-B4), done
  |
  no
  v
fetch the app bundle of the release (R-T10), read the app header (hashes + roc: pin)
  |
  v
select a compiler release (table below)
  |
  v
print the platform URL and hash, then roc build --opt
  |
  v
copy the binary to the bin dir, write the manifest
```

Compiler release selection:

| # | Case | Behavior |
| --- | --- | --- |
| R-T12 | The pinned release is installed | Build with it. No prompt. |
| R-T13 | An installed release has a recorded pass for this closure (Resolution 3) | Build with it. Print `built with nightly-2026-10-12-2664a27 (pin: nightly-2026-10-09-258ab27)`. No prompt. |
| R-T14 | Other releases are installed, with no evidence | Prompt R-NI8 (section 4) with options 1, 2 and 3 |
| R-T15 | No release is installed | Prompt R-NI8 (section 4) with options 1 and 3 |
| R-T16 | Non-interactive mode (section 4) | No prompt (R-DL4). `--roc pinned` selects option 1, `--roc installed` selects option 2, and `--yes` or `TALON_AUTO_INSTALL=yes` selects option 1 (the default). With none of them, Talon stops with exit code 13 and an error that names these flags. |

The prompt:

```text
owner/app 1.4.0 was tested with compiler release nightly-2026-10-09-258ab27. It is not installed.

  1) Download nightly-2026-10-09-258ab27 (70 MB, 228 MB unpacked)    [default]
  2) Try the 4 installed compiler releases
  3) Cancel
```

The prompt shows only what the user needs to decide: why it asks, the cost of the download, and how many releases option 2 tries. The download is the default because the user runs the binary, and the author tested only the output of the pinned release.

Option 2, inside Talon:

| # | Step | Behavior |
| --- | --- | --- |
| R-T17 | Order | Releases in the same epoch as the pin first (Resolution 4, R-EP4: no result changed inside an epoch), then newer before older |
| R-T18 | Each release | `roc check` on the app, with `probe.timeout`. On a fail, go to the next release. |
| R-T19 | First pass | `roc build` with that release. On a fail, go to the next release. |
| R-T20 | All fail | Show the prompt again with options 1 and 3, and a list of each release with the first error line |
| R-T21 | Record | Each pass and fail goes in `compat.db`. The next install of this closure finds the evidence and shows no prompt. |

| # | Rule | Reason |
| --- | --- | --- |
| R-T1 | Build from the app header as it is (hashes and `roc:` pin). Do not resolve again. `--resolve` allows a new resolution. | The header is the lock (G1). A new resolution can select packages that the author did not test. |
| R-T2 | Only an app whose platform makes a native executable can be installed. | A `package` has no entry point. A wasm platform, such as `cloudflare-workers`, makes no CLI. |
| R-T3 | Binaries go in `$XDG_DATA_HOME/talon/bin/` (else `~/.local/share/talon/bin/`), not in the cache. The bin dir `~/.local/bin/` gets a hard link or a copy of each (R-ST7, R-ST9). The final step of an install (move the binary, the bin dir entry, `tools.json`) runs under the lock of `tools.json` (R-CC6). | The cache has a 30-day expiry and GC (6.3). A cleanup must not delete a tool. |
| R-T4 | `$XDG_DATA_HOME/talon/tools.json` records, for each tool: source, build id (hashes, nightly, target), binary sha256, run-time libraries (R-T8), install time. The sha256 identifies the installed file only. Talon does not compare it with the sha256 of another build. | `tln tool ls`, `update` and `rebuild` read it. A build of the same build id can give other bytes: a build on a warm cache differs from a build on an empty cache (Q18). |
| R-T5 | A tool does not keep its nightly. GC (6.3) can remove the nightly after the build. | The binary does not need it. A rebuild installs it again. |
| R-T6 | A download follows the consent rules R-DL1 to R-DL6 (6.2). `--roc pinned` also counts as consent for the pinned download. An installed release is used without a prompt only when evidence supports it. | No surprise download of 228 MB, and no silent build with a release that nobody tested. |
| R-T7 | `tln tool rebuild` builds again from the manifest, with the same build id. | Repair after an OS upgrade breaks a dynamic link (R-T8). |
| R-T8 | Talon builds a tool with no `--target`. roc then uses the musl target of the platform, else its glibc target. For a glibc build, `tools.json` records the libraries in the ELF `NEEDED` list, and `tln tool ls` shows them. | A musl build is static and has no run-time dependency. A glibc build needs system libraries: roc-ray needs `libX11.so.6` (Q16). |
| R-T9 | `min-release-age` (Resolution 2, R-C7) applies to the release that `tln tool install`, `tln x` and `tln tool update` select: with no selector, `@latest`, a range or a series. `tln tool update talon` is one of them (6.5, R-S2). An exact version is a release that the user names: Talon installs it and prints its age. The install scripts make no API call, so they do not know the release time and do not apply it: `install.sh` with no `--version` installs the newest release. | A compromised maintainer account can push a release. The age gives others time to find it (Design 8). |
| R-T10 | The source of a release is its app bundle: the one `<hash>.tar.zst` asset (7.3, R-DI4) whose header has the kind `app` (R-DI7). Talon checks the hash and extracts it as a package (7.1). A release with no app bundle is not a candidate. When no release of the repo is a candidate (the repo has no release, or no release has an app bundle), `tln tool install` and `tln x` stop with exit code 2. The error names `--git owner/app@<tag>` with the newest release tag, or `--git owner/app@<default branch>` when the repo has no release. Talon does not start a source build by itself (section 2, selector rule 3). A git ref uses the source archive (6.6, R-R3). | The same form as `roc install <name> <bundle URL>` and `roc run <bundle URL>` (Design 2). The hash fixes the source, as for a package. |

R-T22: Prebuilt binaries: a release can attach a binary for each target, as `cargo-binstall` expects. Then an install needs no compiler release, and the source build is the fallback. P1 builds this path for Talon itself (6.5). Prebuilt binaries of other tools are P3 (Design 7, Q38): Talon uses one only when it has a GitHub artifact attestation from a workflow of the same repository at the release tag. Before P3, `tln tool install` builds other tools from source.

Tools from a git ref (section 2):

| # | Command | Effect |
| --- | --- | --- |
| R-T23 | `tln tool install --git owner/app@main` | Get the commit as a source archive (6.6, R-R3, R-R7), read `main.roc`, then build as above. `--path apps/cli` selects an app in a subdirectory. `tools.json` records the commit and the ref that the user typed. |
| R-T24 | `tln tool update app` | Installed from a branch: build the new head. From a commit: no change, and Talon prints `pinned to commit dd03c09e`. From a release: the newest release, as `tln tool install app@latest` (R-B2). |
| R-T25 | `tln tool update` with no name | Updates each tool with the rule of its source (row above). One prompt covers the downloads of all tools (R-DL1). |
| R-T26 | `tln tool install foo` when foo is installed | With no selector, or with a selector that the installed version satisfies (R-B1, R-B2): no build. Talon prints `foo 1.2.0 is installed`. Else it builds and replaces the tool. |
| R-T27 | `tln tool install owner/app` | One install for each name. It replaces a git install of the same tool. |
| R-T28 | Binary name clash | When a second tool has the same binary name, the install stops. `--as <name>` sets another name. |

Project dependencies from git are out of scope. A header holds only hash URLs (R-H3), so use `[patch]` (Resolution 7) or a path entry.

#### Run once: `tln x`

`tln x owner/app [-- args]` builds a Roc app and runs it once. It is the same build as `tln tool install`, with a different place for the binary.

| # | Rule | Reason |
| --- | --- | --- |
| R-X1 | Compiler choice, R-T1 (no new resolution, `--resolve` allows it), R-T6 and the R-DL1 to R-DL6 consent rules are the same as for `tln tool install`. The compiler release selection table and the prompt above apply. `--roc pinned`, `--roc installed` and `--yes` work the same. | One build path. One set of consent rules. |
| R-X2 | Talon keeps the built binary and its manifest in `talon/x/<build digest>/` (6.1). The digest is a hash of the build id. A later run reuses an installed tool or this cache entry, with the rules of "Build reuse" below. | A repeat run is fast, as with `bunx`. |
| R-X3 | Talon puts nothing on `PATH`, writes nothing in the bin dir (R-T3) and writes nothing in `tools.json` (R-T4). A run of an installed tool uses the tool binary in place, with no copy (R-B5). | `x` leaves no install behind. |
| R-X4 | `tln x` runs the output. Probes do not (R-P1). Talon prints the platform URL and hash before the build. It does not ask again before the run: the user named the app. The app runs in place of `tln` (Design 6.2, R-HF6), so the exit code of `tln x` is the exit code of the app (R-E1). | The run is the purpose of the command. |
| R-X5 | `tln cache gc` and `tln cache clean` (6.3) can remove the binary. The next run builds it again. | The cache is not a store (R-T3). |

In a project, `tln x <key>` and `tln x owner/app` with no selector run the project tool of `[tools]` (R-PT11 below). The rules above apply outside a project, and to `tln x owner/app@<sel>`.

#### Build reuse between `tln x` and `tln tool install`

A build of an app is expensive: a `roc build --opt`, and maybe a compiler download. So Talon reuses a build that is already on this machine. Each binary has one owner at a time: the `x` cache or the tool list. Talon moves a binary between them. It never keeps two copies, except in one case of R-B4: an entry that a project tool uses.

R-B9: Each `tln x` cache entry has a manifest, with the same fields as a `tools.json` entry (R-T4): full name, source kind (release, or the commit and ref of a git build), version, build id, binary sha256, last run. The manifest also holds the hash of the app bundle that the build used (R-T10), so that a project tool finds the entry by its `url` (R-PT9).

R-B10: Talon finds a reusable build by its manifest, not by its build id. A build matches a request when all of these are equal:

| Field | Must be equal | Reason |
| --- | --- | --- |
| Full name (host and owner/repo, Design 4.1) | Yes | `alice/foo` and `bob/foo` are different programs with the same binary name |
| Source kind | Yes | A git build from `tln x --git owner/app@main` does not satisfy a release request, and the reverse |
| Target | Yes | The binary must run on this machine |
| Version | Only if the selector asks for it (R-B2) | The user did not ask for a new build when a newer version exists |
| Nightly | No | `tools.json` records the real build id, so `tln tool rebuild` (R-T7) builds the same thing again |

| # | Rule | Reason |
| --- | --- | --- |
| R-B1 | With no selector, any matching build is used. When there are more than one, the newest version wins. An installed tool wins over an `x` cache entry of the same version. | No rebuild only because a newer version was released |
| R-B2 | With a selector, a matching build is used only if its version satisfies the selector. `@latest`: the version is the newest release. `@1.3.0`: the version is 1.3.0. A range or series (`@1`, `@^1.2`): the version is the newest release in that range. | The user asked for a version, so an older build is not enough |
| R-B3 | Online, Talon always resolves the request first. It checks that the version of the matching build is not yanked and has no advisory. If it is, Talon does not use the build and builds the newest release that is not yanked. There is no override. With no yank or advisory data (`direct`, or a registry before P3), Talon checks only that the release is still a candidate (R-DI3) and prints the note of R-C6. When the matching build is older than the newest release, Talon prints `installed cached 1.2.0 (1.4.0 is available: tln tool install foo@latest)`. | Reuse skips the build, not the safety checks (R-C6, `tln audit`) |
| R-B4 | `tln tool install` takes over a matching `x` cache entry. It moves the binary to the bin dir (R-T3), checks the sha256, writes the `tools.json` entry from the manifest, makes the bin dir entry (R-ST7), and removes the cache entry. If a `rename` is not possible (another filesystem, or a running `.exe` on Windows), it copies, checks the sha256, then deletes the cache entry. When the `[tools]` of a known project (R-PD9) uses the entry (its bundle hash is a `[tools]` URL, R-PT14), Talon copies the binary, checks the sha256, and keeps the cache entry. | One owner, no second copy. The tool now has the lifetime of a tool, not of a cache entry. The exception keeps the build of a project tool, which never runs a global binary (R-PT12). |
| R-B5 | `tln x` with a matching installed tool runs the tool binary in place. It writes no cache entry. | No copy, no build |
| R-B6 | `tln tool rm` deletes the binary. Nothing goes back to the `x` cache. | The user asked for it to go |
| R-B7 | With no network, or with `--offline`, Talon cannot resolve the request or check yanks. A matching `x` cache entry is then offered in a prompt: `foo 1.2.0 is in the cache. It was not checked online for yanks and advisories. Install it? [y/N]` (prompt R-NI9, section 4). In non-interactive mode, Talon stops with exit code 13 (`consent`, section 3). `--allow-unchecked` or `--yes` accepts. With no matching build, the command fails with exit code 15 (`network`). | A build that nobody checked online needs a choice from the user |
| R-B8 | With no network, `tln x` runs a matching installed tool with a note and no prompt. A matching `x` cache entry needs the R-B7 prompt. | The user installed the tool on purpose. A cache entry is only a leftover. |

Lifecycle of one binary:

```text
tln x foo ───────────── build ──▶ x cache entry (manifest + binary)
                                     │
tln tool install foo ── R-B1/R-B2 match ─┴─▶ move to bin dir, write tools.json (R-B4)
                        no match ──────▶ normal build. The old cache entry waits for GC.

tln x foo ───────────── installed tool matches ──▶ run it in place (R-B5)
tln tool rm foo ─────── binary deleted, nothing goes back to the cache (R-B6)
offline install ─────── match? prompt, "not checked online" (R-B7). Non-interactive: exit 13.
```

#### Project tools: `[tools]`

A project tool is a tool app that a project pins in `[tools]` of its `talon.toml`, with a range (`ref`) and the locked release URL (`url`). `tln run` and `tln x` run the project version before a global one. Prior art: Go 1.24 `tool` lines in `go.mod`, `uv tool run` with a version. Phase P1 (Design 7, R-PH3). Source: `research/talon-scripts/` 6.2.

```toml
# talon.toml (the root file of a workspace, or the file of a standalone project)
[tools]
roc-cfw = { ref = "Karakatiza666/roc-cloudflare-workers-cli@^1", url = "https://github.com/Karakatiza666/roc-cloudflare-workers-cli/releases/download/1.0.3/<hash>.tar.zst" }
```

A tool is an app, so it cannot be an entry of the project header (Resolution 2, R-C4: an `app` release is never a candidate, and an unused header entry joins MVS, Design 2). So the lock of a tool is the `url` next to its intent (`ref`). This is the only lock value in `talon.toml` (Design G1, G2). There is no lock file.

```text
[tools] key ──ref──▶ intent: owner/app + range       (the human writes it, or tln add --tool)
            └─url──▶ lock: release URL + hash          (Talon writes it; the tool's own header locks its closure and roc:)
```

| # | Rule |
| --- | --- |
| R-PT1 | `[tools]` is a table of `talon.toml`. A key is the name of the program in a step: `[a-z0-9][a-z0-9._-]*`. A value is an inline table with `ref` (required: a ref of section 2, `owner/app` and a selector; no selector is `@latest`, as R-T26) and `url` (a release URL of Design 4.1 with a version and a hash, Design 4.2, R-H3). Another form gives exit code 19. |
| R-PT2 | Where: a standalone project has `[tools]` in its own `talon.toml` (R-PD6). In a workspace, only the root `talon.toml` has `[tools]` (Design 4.4, R-WS5, as `[toolchain]`). A `[tools]` table in another file of the workspace gives exit code 19. So a workspace has one version of each tool, as it has one nightly (R-WS4). The `talon.toml` of a standalone project (R-PD5, R-PD6, Design 4.4 R-WS5) is its own root, also inside a workspace directory: its `[tools]` is allowed, and its steps use it (R-RUN3). |
| R-PT3 | `tln add --tool owner/app[@sel] [--as <key>]` selects a release (R-PT4), builds it (R-PT6), and only then writes the entry: `ref` with the selector, or `^<version>` when there is none (as Design 4.3, R-I4), and `url`. Talon creates `talon.toml` when it is missing. The default key is the binary name of the app (R-T28 form). A key that exists gives exit code 2 unless the `ref` names the same app: then the command acts as `tln update <key>`. `tln remove --tool <key>` removes the entry. `--tool` takes no project resolve flag except `--snapshot`, `--dry-run` and `--allow-downloads` (R-FL7). |
| R-PT4 | Selection of a release, in `add --tool`, `update`, `upgrade` and `install` of an entry with no `url`: the rules of `tln tool install` for one release: candidates of R-T10 (one app bundle), R-DI3 (no draft, no prerelease), `min-release-age` (R-T9, Resolution 2, R-C7) for a range, no yanked release (R-B3), and `--snapshot` (Resolution 11). The newest candidate in the range wins. A tool is not a variable of the project resolve: its closure, its platform and its nightly come from its own header (R-T1), and no probe runs against the project. |
| R-PT5 | Which commands move a `url`. `tln update` and `tln upgrade` with no names move each tool, as each header entry: `update` inside the `ref` range, `upgrade` to the newest release, with the `ref` range changed to match (Resolution 10, R-UP5). With names, a name that is a `[tools]` key moves that tool. A name that is a header alias and a `[tools]` key gives exit code 2 and names `--tool` (as Design 4.4, R-WS8). With `--tool`, each name of `update` and `upgrade` is a `[tools]` key. With `--tool` and no names, `update` and `upgrade` move only the tools, and no header entry. `tln install` with no names writes the `url` of an entry that has only `ref` (as Design 4.3, R-I5). As in R-PT3, Talon builds the new release (R-PT6) before it writes the `url`. No other command writes `url`. A hand edit of `url` is accepted, as a hand edit of the header (Design 4.1, R-ID7). |
| R-PT6 | Build. A project tool builds with the path of `tln x` (R-X1, R-T1, R-T8, R-T12 to R-T21) from its app bundle at `url`. The hash of the bundle is checked (7.1, R-FE2). Talon prints the platform URL and hash before the build (Design 8, R-SE8). The binary goes in `talon/x/<build digest>/` with its manifest (R-X2, R-B9), and the manifest also holds the bundle hash. `tln install` (with or without `--frozen`) builds each tool that has no binary, after the fetch of the closure. So a CI job that runs `tln install --frozen` runs no build in `tln run`. |
| R-PT7 | `--frozen` (Resolution 12, R-LF1). `tln install --frozen` fails with exit code 14 when an entry has no `url`, or when the version of `url` is not in the range of `ref`, or when the app of `url` is not the app of `ref` (its group, Design 4.1). It makes no index call (7.3, R-DI1): it fetches the bundle at `url` and builds. So it does not see a yank (R-AU6). |
| R-PT8 | No online check at run time. A run of a project tool (R-PT9, R-PT11) uses the `url` as the lock, as a build uses the header: no resolve, no yank check, no R-B3 request and no R-B7 prompt. Reason: the project chose the hash, as it chose the header hashes. A cache entry is not a leftover here. Yanks and advisories of tool URLs are findings of `tln audit` (R-AU1 to R-AU12: the `[tools]` URLs join the list of hashes) and rows of `tln outdated` (R-CM6). |
| R-PT9 | `tln run`: a step whose first word is a `[tools]` key (R-RUN3) runs the binary of that `url`. Talon finds it in this order: (1) a `talon/x/` entry with the same bundle hash and target (R-B9); (2) else Talon builds it (R-PT6) and then runs it. A project tool never runs the binary of a global tool (R-PT12). A build in `tln run` follows the consent rules R-DL1 to R-DL6 (R-DL7 names `run`): a compiler download is a required download (R-DL2). In non-interactive mode it needs `TALON_AUTO_INSTALL=yes`, else exit code 13. |
| R-PT10 | Talon adds no directory to `PATH` (R-RUN3). A program that a step starts does not find a project tool by its key. A step that needs it in a child names it as a step of its own. |
| R-PT11 | `tln x <key> [-- args]`, in a directory where the walk of R-RUN12 finds a `talon.toml` whose `[tools]` table (the table of R-RUN3: the workspace root, or the file of a standalone project) has that key, runs the project tool as R-PT9. `tln x owner/app` with no selector, when a `[tools]` entry has the same app (group), also runs the project version, and prints `project tool <key> <version> (talon.toml)`. `tln x owner/app@<sel>` with a selector keeps the rules of R-X1 to R-X5: the user asked for a version. Outside a project, `tln x` is as before. |
| R-PT12 | Global and project tools are independent. `tln tool install`, `update`, `rebuild` and `rm` never read or write `[tools]`. `tln add --tool` and `tln update` never change `tools.json`. A project tool never runs the binary of a global tool, also when the bundle hash is equal: its builds are only in `talon/x/` (R-B9), and no data of a project tool goes in `tools.json`. A global tool does not change what a step runs: inside `tln run`, the project version wins. Outside `tln run` and `tln x`, a shell finds the global tool on `PATH` (R-T3), not the project version. |
| R-PT13 | `tln tool install` of a `talon/x/` entry that a project tool also uses: R-B4 copies the binary to the bin dir and keeps the entry, so the project tool keeps its build (R-PT9). `tln tool rm` deletes only the global copy (R-B6). |
| R-PT14 | GC (6.3). R-GC7 keeps a `talon/x/` entry whose bundle hash is a `[tools]` URL of a known project (R-PD9, which `tln run` and `tln x <key>` also update) that was used in the GC age, also when no `tln x` run used the entry. R-GC4 keeps the extracted bundle `packages/<hash>/` of such a URL in the same way. GC reads the `talon.toml` of each known project file, and each known `talon.toml` entry, again when it runs (as R-PD12). `tln cache clean` removes them (R-GC12, R-GC13): the next run builds again. |
| R-PT15 | `--offline` (R-FL3): a run needs the binary or the cache. With no binary, Talon builds from `packages/<hash>/` and an installed compiler. With neither, exit code 15. |
| R-PT16 | A tool of `[tools]` must be an app with a native platform (R-T2). Talon checks the platform header of the bundle before the build. A wasm platform gives exit code 2. |

| Case | Network | Prompt | Exit code |
| --- | --- | --- | --- |
| `tln run` with the binary present | None | None | The code of the step |
| `tln run` with no binary, bundle and compiler in cache | None | None | The code of the step |
| `tln run` with no binary, compiler missing, interactive | Bundle, compiler | R-NI5 (required download) | 13 on No |
| Same, CI with `TALON_AUTO_INSTALL=yes` | Bundle, compiler | None | The code of the step |
| `tln install --frozen` with an entry with no `url` | None | None | 14 |
| `--offline` with no binary and no cache | None | None | 15 |

### 6.5 Talon as a tool

Talon manages itself as one more entry in `tools.json`. Only a few rules are different, because a broken `tln` cannot repair itself, and it also breaks the `roc` proxy (6.2).

```text
first install:  curl -fsSL <releases>/latest/download/install.sh | sh             (Linux, macOS)
                irm <releases>/latest/download/install.ps1 | iex                    (Windows)
                  -> download the prebuilt tln for this target, verify it
                  -> put it in the bin dir (R-T3)
                  -> run tln setup: it writes the tools.json entry of tln (source: install script)
later:          tln tool update talon
repair:         curl -fsSL <releases>/latest/download/install.sh | sh -s -- --version 0.3.1
                & ([scriptblock]::Create((irm <releases>/latest/download/install.ps1))) -Version 0.3.1
```

`<releases>` is `https://github.com/roc-talon/talon/releases`. The scripts are in `install/` (Design 6.3), and `install/test.sh` tests them against a fake release. Their structure follows the rocup installers (Design 3).

| # | Rule | Reason |
| --- | --- | --- |
| R-S1 | `install.sh` downloads a prebuilt binary from the GitHub Release assets of Talon. It checks the sha256 from the release, and the attestation when there is one (Design 8). | `install.sh` cannot build from source: that needs a compiler release (228 MB) before the user has `tln`. |
| R-S2 | `tln tool update talon` uses the prebuilt binary. `--from-source` builds it as in 6.4. | Same reason as R-S1, and a download is faster |
| R-S3 | An update writes the new binary to a temp file, sets it executable (Design 6.2, R-HF2), runs `tln --version` on it, then does a `rename` over the old one. On Windows, it renames the running `.exe` first (R-ST10). Then it makes the bin dir entries `tln` and `roc` again (R-ST9). | A binary that does not start never replaces the working one. A running `.exe` cannot be overwritten. |
| R-S4 | No rollback command, and no copy of the old binary. The repair path is `install.sh --version <v>`. | A broken binary cannot run a rollback command. `install.sh` does not need a working `tln`. |
| R-S5 | `tln tool rm talon` asks what to remove (prompt R-NI10, section 4), then removes it. See "Remove Talon" below. | One namespace for all tools. Removing Talon also removes the proxy, so the user must confirm. |

The install scripts follow these rules:

| # | Rule |
| --- | --- |
| R-IS1 | Two scripts: `install.sh` for Linux and macOS (POSIX `sh`: tested with dash, bash and busybox), and `install.ps1` for Windows (PowerShell 5.1 and later). Each Talon release has both as assets, so `latest/download/install.sh` is the script of the newest release. |
| R-IS2 | A release has one binary for each Roc target: `tln-x64musl`, `tln-arm64musl`, `tln-x64mac`, `tln-arm64mac`, `tln-x64win.exe`, and `sha256sums.txt`. These are the targets of basic-cli (Design 6.2, R-HF10). The Linux binaries are static musl, so one binary works on each distribution (Design Q16). On macOS, a shell under Rosetta gets the arm64 binary. basic-cli has no `arm64win` target, so on Windows on ARM64, `install.ps1` installs `tln-x64win.exe`. Windows 11 on ARM64 runs it by emulation, and Talon then selects `windows_x86_64` compilers (R-CV2), which also run by emulation. Other systems stop with an error that lists the targets. |
| R-IS3 | The script checks the sha256 from `sha256sums.txt` (exit code 16), and the attestation when `gh` is installed and logged in (R-S1). It uses `latest/download/` URLs, so it needs no GitHub API call and no token. |
| R-IS4 | The script asks `Proceed? [Y/n]` (prompt R-NI15, kind Default). It uses the non-interactive rules of section 4, with one difference: with `curl \| sh`, stdin is the script, so `install.sh` reads the answer from `/dev/tty`. In non-interactive mode, the install goes on with no prompt, because the command names it. `--yes` (`-Yes`, or `TALON_YES=1` for `irm \| iex`) skips the prompt. |
| R-IS5 | The download goes to a temp file in the bin dir. The script runs `--version` on it, then renames it over the old binary (R-S3). On Windows it first renames the old `tln.exe` to `tln.<16hex>.del` (R-ST10). A failed check keeps the old binary and leaves no temp file. |
| R-IS6 | Then the script runs `tln setup`, with `--yes` and `--no-modify-path` when the user gave them. `tln setup` writes the `talon` entry of `tools.json` when it is missing, then applies R-ST1 to R-ST6. With a terminal, `install.sh` connects `/dev/tty` to `tln setup`, so its prompts (R-NI13, R-NI14) work under `curl \| sh`. |
| R-IS7 | Exit codes as in section 3: 2 for a bad argument, 15 for a download error, 16 for a checksum or attestation error, 1 for the rest. `install.ps1` under `irm \| iex` runs in the shell of the user, so it throws an error and does not exit: an exit would close that shell. |
| R-IS8 | There is no uninstall script. `tln tool rm talon` removes Talon (R-S5). If `tln` does not start, `install.sh --version <v>` repairs it first (R-S4). |

#### Remove Talon

Talon manages more than its own binary. Without Talon, compilers and Talon data are not used, so they are leftovers. Tools still run, because each binary is self-contained (6.4), but nothing can update them.

```text
$ tln tool rm talon
Remove Talon 0.3.1 (tln and the roc proxy)?

Talon also manages:
  tools        3 (foo, bar, baz)                      42 MB   they run without Talon
  compilers    4 nightlies, 1 git build, zig 0.17.0   1.2 GB
  Talon data   index, x cache, compat.db, config     310 MB

The roc command goes with Talon. A kept compiler stays in toolchains/<id>/roc.

  1) Remove Talon, the compilers and the data. Keep the tools.   [default]
  2) Remove Talon and all of the above
  3) Remove Talon only
  4) Cancel
```

| # | Group | Paths (6.1, 6.4) | Option 1 (default) | Option 2 (`--remove-tools`) | Option 3 (`--keep-all`) |
| --- | --- | --- | --- | --- | --- |
| R-RM7 | Talon | The `tln` binary, the `roc` launcher, the `talon` entry of `tools.json` | Removed | Removed | Removed |
| R-RM8 | Tools | Each other tool binary, its link in `~/.local/bin/`, `tools.json`, the `PATH` line of `tln setup` (6.7, R-ST4) | Kept | Removed | Kept |
| R-RM9 | Compilers | `toolchains/<id>/`, `toolchains/zig-<version>/`, and the `compat-<id>/` dir of each removed compiler | Removed | Removed | Kept |
| R-RM10 | Talon data | `talon/` in the cache (index, `x`, `compat.db`, `projects.json`), `config.toml` and `share.json` (6.1) | Removed | Removed | Kept |

| # | Rule |
| --- | --- |
| R-RM1 | Talon never removes what roc owns and uses without Talon: `packages/`, the build caches of compilers that Talon did not install, and the app installs of `roc install` (Design 2). `tln cache clean --all` before the removal removes the first two (6.3). |
| R-RM2 | `tln roc link` entries (`link-<name>`) are links. Talon removes the link and never the target. |
| R-RM3 | The default (option 1) keeps the tools, because they still run without Talon. It removes the compilers and the Talon data, because nothing uses them without Talon. In non-interactive mode (section 4), Talon uses option 1 with no prompt. `--remove-tools` and `--keep-all` select options 2 and 3 in both modes. `--yes` selects option 1. |
| R-RM4 | `--dry-run` prints the table above with sizes and removes nothing. |
| R-RM5 | Talon removes its own binary last, and the bin dir entries `tln` and `roc` with it. On Windows, it renames each running `.exe` (R-ST10). No later `tln` start deletes them, so Talon starts a detached `cmd.exe /d /c` that waits until Talon ends, then deletes them. If that fails, the renamed files stay. A later install of Talon deletes them (R-ST10). |
| R-RM6 | The `roc` launcher always goes with Talon. Talon prints the path of each compiler that stays (option 3), so the user can put one on `PATH`. If `tln setup` moved an old `roc` to `roc.old` (6.7, R-ST2), Talon moves it back. |

### 6.6 Compilers from source

| # | Command | Result id |
| --- | --- | --- |
| R-R8 | `tln roc install nightly-2026-10-09-258ab27` | `nightly-2026-10-09-258ab27` |
| R-R9 | `tln roc install --git @main` (short for `roc-lang/roc@main`, see section 2) | `git-<sha8>` |
| R-R10 | `tln roc install --git Karakatiza666/roc@my-branch` | `git-<sha8>`. A fork works the same way. |
| R-R11 | `tln roc install @dd03c09e` | `git-dd03c09e`. A sha needs no `--git`. |
| R-R12 | `tln roc link dev ../roc/zig-out/bin/roc` | `link-dev`. No build, no copy, as `rustup toolchain link`. |
| R-R13 | `tln roc link --copy fix-1 ../roc/zig-out/bin/roc` | `copy-fix-1`. A copy of the binary, as `rocup freeze`. |

| # | Rule | Reason |
| --- | --- | --- |
| R-R1 | The id is `git-<sha8>`. `.talon.json` records the repo URL, the full sha and the ref that the user typed. | A commit sha is unique across forks. 8 characters match the local form `debug-c6dfe61b` of roc (`roc:src/base/roc_version.zig:21-22`). |
| R-R2 | If the commit is the commit of a nightly, Talon builds the ref that the user typed and prints a note, for example `dd03c09e is nightly-2026-10-09-258ab27. tln roc install nightly-2026-10-09-258ab27 downloads it.` It does not prompt (R-NI11 is removed). | Same code, and a download is much faster than a build. A script that typed a git ref can expect the id `git-<sha8>`. |
| R-R3 | Talon gets the source as a GitHub archive, not with git: `GET <api>/repos/<owner>/<repo>/tarball/<sha>`, which redirects to `codeload.github.com`. `<api>` is `https://api.github.com`, or `TALON_GITHUB_API` (section 1). It builds with `zig build roc -Doptimize=ReleaseFast -Dcompiler-version=git-<sha8>`, as roc CI does (`roc:.github/workflows/ci_zig.yml:268`). | With no `.git`, roc reports the version `no-git` (`roc:build.zig`, `getCompilerVersionGit`). The flag gives the id instead (Q17). |
| R-R4 | Talon never writes `git-*` or `link-*` into a `roc:` pin. R-H6 keeps the old pin. Probe results for these ids stay local. | roc does not accept a local build as a pin, by design (`roc_version.zig:21-23`). Other users cannot reproduce such a result. |
| R-R5 | Selection uses the same rules as a nightly (Resolution 13): `roc +git-dd03c09e check`, `ROC_TOOLCHAIN=git-dd03c09e`, or `tln roc default --git Karakatiza666/roc@my-branch`. The last command picks the newest installed build of that branch, and stores its full id. Prefixes follow the rules in section 2. | A stored value must not change meaning after a later install |
| R-R6 | When the user installs a branch again, Talon builds the new head as a new id. The old id stays until GC. | An id never changes meaning |
| R-R7 | GitHub publishes no hash for a source archive. Talon downloads it with `curl` over `https://` only, also after a redirect (7.5, R-DA3), computes its sha256, and records it in `.talon.json` (R-R1), or for a tool in `tools.json` (R-T4). `tar` extracts it into a temp dir (Design 6.2, R-HF5). | The commit sha in the URL names the source. GitHub makes the archive again on request, so its bytes are not fixed, and Talon does not compare the sha256 with an earlier one. The trust is TLS to `github.com`, the same as a `git clone` (Design 8). |

Links and copies of a local build:

| # | Rule | Reason |
| --- | --- | --- |
| R-LK1 | A `link-<name>` follows its target, so a rebuild changes the compiler under the same id. Talon keys the local probe results of a link by the sha256 of the binary, not by the id. | Old evidence must not apply to a new build |
| R-LK2 | `tln roc link --copy <name> <path>` copies the binary (it follows symlinks) into `toolchains/copy-<name>/`. A later rebuild of the source tree does not change it. A name that exists is an error. `--force` replaces it. | A fixed local build to compare against, or to keep while the tree changes |
| R-LK3 | `copy-*` follows R-R4 and R-R5, as `git-*` does: it is never a `roc:` pin, and its probe results stay local | roc does not accept a local build as a pin |
| R-LK4 | A `link-<name>` is not a file system link. `toolchains/link-<name>/.talon.json` records the absolute path of the target, and Talon runs that path. | Same on all systems. A symlink on Windows needs developer mode or admin rights, and a hard link does not follow a rebuild (Design 6.2, R-HF7). |

The commands that select a compiler differ in where they store the choice:

| # | Command | Writes | Scope |
| --- | --- | --- | --- |
| R-CS1 | `tln roc use <ref>` | The `roc:` entry of the app header in the current project (selection priority 3, Resolution 13). In a workspace, each member (Design 4.4). | This project |
| R-CS2 | `tln roc default <ref>` | The global default (priority 6) | This user |
| R-CS3 | `tln roc update` | Installs the newest nightly. Moves the global default to it (R-RU2). | This user |

`tln roc use` follows these rules. It keeps the header as the lock (G1), so it writes no `talon.toml` key and no `.roc-version`:

| # | Rule |
| --- | --- |
| R-U1 | The ref must be a nightly or a release. `git-*`, `link-*` and `copy-*` ids are an error (R-R4, R-LK3). Talon says to use `tln roc default` or `ROC_TOOLCHAIN`. |
| R-U2 | A missing nightly follows the consent rules R-DL1 to R-DL6 (6.2). It is a required download (R-DL2). |
| R-U3 | Talon runs the baseline check and the final ladder (Resolution 4) on the current header with that nightly. The baseline runs with the current pin. When that compiler is not installed, it is a required download (R-DL2, prompt R-NI5), in the same prompt as the new nightly (R-DL1). It writes `roc:` only if there are no new errors (R-H6). It uses a span-based edit (R-H1). |
| R-U4 | `--no-check` is an error for this command: R-H6 allows no pin move without the check. |
| R-U5 | If `talon.toml` has `[toolchain] roc` and the nightly is out of range, or the `nightly` switch is off and the ref is a nightly (Resolution 1, R-NS5), Talon stops and names the range or the switch. It does not edit `talon.toml`. |
| R-U6 | A command argument or `ROC_TOOLCHAIN` still has higher priority than the new pin (Resolution 13). Talon prints a note when one of them is set. |

`tln roc update` (alias `tln roc up`) gets the newest compiler release, also when a project does not work with it yet:

| # | Rule |
| --- | --- |
| R-RU1 | Talon finds the newest compiler release online that the `nightly` switch (Resolution 1, R-NS3) and `min-release-age` (R-C7) allow, and installs it. With the defaults, that is the newest nightly that is at least 2 days old. The command names the download (R-NI6). If the newest nightly is already installed, Talon prints `nightly-2026-10-13-91fa0c2 is the newest` and does nothing. |
| R-RU2 | Talon moves the global default (Resolution 13, priority 6) to the new release when the default is a nightly, a release, or is not set. A `git-*`, `link-*` or `copy-*` default does not change. Talon prints a note. |
| R-RU3 | Talon runs no check and writes no project file. A project with a `roc:` pin keeps it. A project with no pin selects with priority 4 to 6 (Resolution 13), so it uses the new nightly at once. That can break it. To move a project pin with a check, use `tln upgrade roc` or `tln roc use` (R-RP1). An app that `roc install` installed stays with the old compiler version, so `roc run <name>` does not find it with the new one (6.2, Design 2). |
| R-RU4 | Older nightlies stay until GC (6.3). |

`tln roc remove <id>` (alias `tln roc rm`) removes one compiler:

| # | Rule |
| --- | --- |
| R-RR1 | If the compiler is the global default, Talon moves the default to the newest installed nightly or release that the `nightly` switch allows, and prints a note. With none, the default is not set (Resolution 13). |
| R-RR2 | If a known project (`talon/projects.json`) pins the compiler, Talon prints the projects and removes it. The command names the removal, so there is no prompt. The proxy downloads it again when a project needs it (R-DL1 to R-DL6). |
| R-RR3 | For `link-*`, Talon removes the link and never the target (R-RM2). |

R-D4: Build dependencies. The commit names its Zig version: `minimum_zig_version` in `build.zig.zon` (`roc:build.zig.zon:4`). Zig changes its API between minor versions, so Talon needs the same `major.minor`.

```text
$ tln roc install --git Karakatiza666/roc@my-branch
Build roc from Karakatiza666/roc@my-branch (dd03c09e)

Dependencies:
  [ ] zig 0.17.x            found zig 0.16.0 on PATH
  [ ] LLVM bundle           x86_64-linux-musl, 45 MB, zig gets it during the build

Install zig 0.17.0 (54 MB) for Talon builds? [Y/n]
```

This prompt (R-NI6, section 4) follows the consent rules R-DL1 to R-DL6 (6.2). The Zig download is required for the build. The command names the build, so in non-interactive mode Talon installs Zig with no prompt (R-DL4).

| # | Rule |
| --- | --- |
| R-D1 | Zig search order: `$ZIG`, then `zig` on `PATH` with a matching version, then a Zig that Talon installed. |
| R-D2 | Talon installs Zig from `ziglang.org/download/index.json` (it gives the sha256) into `toolchains/zig-<version>/`. GC removes it when no source build needs it. |
| R-D3 | `[x]` is found. `[ ]` with a reason is missing. The LLVM bundle line gives the size of the `roc-lang/roc-bootstrap` asset for the host target. |

### 6.7 Setup

R-ST12: `tln setup` connects Talon to the shell. `install.sh` runs it (6.5). It can run again: it changes only what is missing or out of date.

| # | Rule |
| --- | --- |
| R-ST1 | Talon writes into the bin dir `~/.local/bin/` one entry (R-ST7) for each of: `tln`, the `roc` launcher (6.2, R-ST8) and each tool (R-T3). On Windows each name has `.exe`. |
| R-ST2 | If a `roc` that Talon did not write is in the bin dir, Talon asks to replace it (prompt R-NI13, default no). Yes: Talon moves it to `~/.local/bin/roc.old` (`roc.old.exe` on Windows) and links it as the compiler `link-system` (6.6), so `roc +link-system` still runs it. No: Talon does not install the launcher, and prints `tln setup --replace-roc`. |
| R-ST3 | If a `roc` comes before the bin dir on `PATH` (for example `/usr/local/bin/roc`), Talon prints a warning with its path. It changes nothing there. |
| R-ST4 | If the bin dir is not on `PATH`, Talon asks to add one line to the profile of the current shell (prompt R-NI14, default yes): `~/.bashrc`, `~/.zshrc`, or `~/.config/fish/conf.d/talon.fish`. The line has a marker comment, so `tln tool rm talon` can find it (6.5). On Windows, Talon adds the bin dir to the user `Path` value of the environment once (6.1, Design 6.2 R-HF11), and `tln tool rm talon` removes exactly that entry. `--no-modify-path` skips it and prints the line or the entry. When `GITHUB_PATH` is set (GitHub Actions), Talon appends the bin dir to the file that it names, in place of a profile line: a CI job reads no shell profile. |
| R-ST5 | Shell completions go in the user completion dir of the shell, with no prompt. |
| R-ST6 | Talon never deletes or overwrites a file that it did not write, except with the R-ST2 consent. |

Bin dir entries and launchers. One form on Linux, macOS and Windows, so one code path, and the Linux CI tests the Windows form too:

| # | Entry in the bin dir | Points to | Form |
| --- | --- | --- | --- |
| R-ST13 | `tln`, `tln.exe` | `tln` in the data bin dir (R-T3) | Hard link, else a copy |
| R-ST14 | `roc`, `roc.exe` | The same `tln` file | Hard link, else a copy. `tln` runs as the proxy (R-ST8). |
| R-ST15 | `<tool>`, `<tool>.exe` | The tool binary in the data bin dir | Hard link, else a copy |

| # | Rule | Reason |
| --- | --- | --- |
| R-ST7 | Each bin dir entry is a hard link (`Path.hard_link!`) to its file in the data bin dir (R-T3). When the hard link fails (another file system or volume), Talon copies the file and sets it executable (Design 6.2, R-HF2). Talon writes the entry as a temp and a `rename` (R-CC1). | basic-cli has no symlink function (R-HF7), and a symlink on Windows needs developer mode or admin rights. A hard link costs no disk space. |
| R-ST8 | The `roc` entry is the `tln` binary with another name. At start, `tln` reads its program name (`Env.program_name!`, R-HF9) and takes the base name without `.exe`. When it is `roc`, `tln` runs as the proxy (6.2). Else it runs as `tln`. There is no `.cmd`, `.bat` or `.ps1` launcher, and no separate launcher `.exe`. | `cmd.exe` parses the arguments of a `.cmd` file again (`%`, `^`, `&`, `"`), asks `Terminate batch job (Y/N)?` after Ctrl-C, and can lose the exit code (R-E1). A separate launcher is one more binary to build and to verify. |
| R-ST9 | When Talon replaces a file in the data bin dir (`tln tool update talon` R-S3, `tool update`, `tool rebuild`, the R-B4 take-over), it makes each bin dir entry of that file again. When a step fails or the process stops before it, `tln setup` repairs the entries, because it changes what is out of date. | After a `rename` over the file, a hard link still points to the old file |
| R-ST10 | On Windows, Talon renames a `.exe` before it replaces or deletes it: to `<name>.<16hex>.del` in the same dir. Each start of `tln` tries to delete the `*.del` files in the bin dir and the data bin dir. A delete fails while the file runs, and the next start tries again. On Linux and macOS a `rename` over a running binary works, so there is no `.del` file. | Windows does not let a process delete or overwrite a running `.exe`, but it lets it rename one |
| R-ST11 | A bin dir entry is Talon's when its name is `tln`, `roc` or a tool name in `tools.json`, and its content is equal to the file that it points to in the data bin dir (the same sha256). R-ST2, R-ST6 and R-RM6 use this test. | A hard link or a copy has no link target to read |

## 7. Store and fetch

### 7.1 Pipeline

| # | Property | How |
| --- | --- | --- |
| R-FE1 | No waterfall | The registry returns the header facts of the full closure up front (Resolution 5, R-AL2). All fetches of the chosen closure start at once (7.5). With `direct`, the facts of a node come from its archive (Resolution 5, R-AL8, source 4), so the fetch of a level waits for the level before it: a closure of depth d takes at most d rounds, and the nodes of one round download at the same time. |
| R-FE2 | Verify | Talon downloads the archive as `<hash>.tar.zst` into a temp dir (7.5), and runs `roc unbundle <hash>.tar.zst` there (Design 6.2, R-HF5). roc computes the BLAKE3 of the file, compares its base58 form to the name (`roc:src/unbundle/unbundle.zig:557-680`), and checks the paths and the size limits. A failure gives exit code 16. Measured: `research/roc-unbundle/`. |
| R-FE3 | Atomic | Same protocol as roc: the temp dir is `packages/<hash>.<16hex>.tmp/`, and Talon renames its `<hash>/` dir to `packages/<hash>/` (`package_resolution.zig:2188-2306`). If the rename loses to roc or to another `tln`, Talon drops its copy. No lock is needed (7.4, R-CC11). |
| R-FE4 | Compiler for `roc unbundle` | The format of a package archive does not depend on the nightly. So Talon uses the selected compiler (Resolution 13) when it is installed, else the newest installed compiler, else the `roc` on `PATH` (rank 7). With none, the selected compiler is a required download (R-DL2). |
| R-FE5 | Sidecar | Talon does not write `<hash>.deps.json`. roc rebuilds it from `main.roc` on first use. |
| R-FE6 | Mirrors | On a 404, Talon tries mirrors. The hash proves the bytes. The header URL does not change (R-H5). The registry gives the mirror list, from P3 (Design 7). Before P3, and with `direct`, the list is empty, and a 404 gives exit code 15. There is no user setting for mirrors. The message: R-FE10. |
| R-FE10 | 404 message | When a closure URL gives 404 and no mirror has it (R-FE6), the message names the package, the version and the URL. When the command already has the release state of that hash (the closure answer, Registry R-AP17, or the release lists of 7.3), and that state has a reason of R-AU2 (`asset-replaced`, `repo-missing`, `release-missing`), the message gives the reason and its fix (R-AU8). Else it names `tln audit` (R-AU6). `tln install --frozen` makes no index call (R-DI1), so its message always names `tln audit`. Talon sends no extra request for the message. The exit code stays 15. Text (a proposal, R-OUT2): `tln: error[network]: download of roc-lang/json 2.1.0 failed: 404 (<url>). The registry says: the asset was replaced. Ask the author to release a new version, then run tln update json.` With no state: `tln: error[network]: download of roc-lang/json 2.1.0 failed: 404 (<url>). Run tln audit to see why.` |
| R-FE7 | Offline | `--offline` uses the cache only. |
| R-FE8 | URL schemes | Talon accepts the package URLs that roc accepts: `https://` to any host, and `http://` to loopback only (`127.0.0.1`, `::1`, `localhost`). Measured: `research/roc-http-fetch/`. |

### 7.2 Cache contract with the compiler

R-FE9: Option B from draft 1 is now confirmed in the source: when `packages/<hash>/main.roc` exists without a sidecar, roc rescans it and writes the sidecar (`package_resolution.zig:2160-2183`). A conformance test runs this check against each new nightly.

### 7.3 Index with no registry (`direct`)

R-DI14: With `direct` (section 1, registry precedence), GitHub Releases are the index. Talon makes the same candidate facts as a registry record (Registry 5): version, group, hash, URL, kind, deps, `roc:` pin, `published_at`. The registry uses R-DI3 to R-DI5 when it indexes a release (Registry 7), so both modes see the same candidates. There is one exception: a tag that is released again with a new asset hash (R-DI15).

```text
group to resolve ──▶ list releases (R-DI2, cached with ETag)
                        │  skip draft, prerelease (R-DI3)
                        │  select the <hash>.tar.zst asset (R-DI4)
                        │  version and group from the URL (R-DI5, R-DI6)
                        ▼
                     candidates, newest first
                        │  solver asks for one candidate
                        ▼
                     download, check hash, extract to packages/<hash>/ (R-DI7)
                        │
                        ▼
                     kind, deps, roc: pin from main.roc
```

| # | Rule |
| --- | --- |
| R-DI1 | Talon lists releases only for a group that it must resolve or show: a free direct dep, the platform, an `[overrides]` group (Resolution 6), the group of `tln add`, the group of a movable variable in the second search of a held move (Resolution 9, R-SP24, only when the search with the held variables fixed finds no tuple), and the rows of `tln outdated`. A transitive group needs no list, because package headers set its version (MVS, Design 2). With a registry, the closure query gives the lists (Registry 4.1, R-AP16), and the groups of the movable variables come in a second query. A command that resolves nothing (`tln install --frozen`, `tln list`, the `roc` proxy) makes no index call, also with a registry. It reads the closure from `packages/` and the archives (Resolution 5, R-AL8, sources 3 and 4). |
| R-DI2 | The list call is `GET https://api.github.com/repos/<owner>/<repo>/releases?per_page=100`. `TALON_GITHUB_API` replaces the base `https://api.github.com` when it is set (section 1). Talon follows the `Link: rel="next"` header to the last page. It keeps each page and its `ETag` in `talon/index/github/<owner>/<repo>/` (6.1). A page younger than 60 s is used with no request, as `GET /v1/packages/{owner}/{repo}/releases` (Registry 4, R-AP1, R-AP24). For an older page, Talon sends `If-None-Match`. A `304` answer keeps the page. GitHub does not count a `304` answer against the rate limit when the request has a token. |
| R-DI3 | Only a published release is a candidate. Talon skips a draft and a release that GitHub marks `prerelease`. A deleted release is not in the list, so it is not a candidate (R-C6). |
| R-DI4 | The package asset is the one asset with the name `<hash>.tar.zst`, where `<hash>` is the base58 form of 32 bytes (Design 2). Other assets are not packages, for example `docs.tar.gz` and `<hash>.tar.zst.intoto.jsonl`. A release with no such asset is not a candidate. A release with 2 or more is not a candidate, because roc rejects one label with two hashes (Design 2, "Conflicting Package Contents"). Talon prints a warning that names the release. |
| R-DI5 | The candidate URL is `https://github.com/<owner>/<repo>/releases/download/<tag>/<hash>.tar.zst`. Talon gets the version and the group from this URL with the roc rule (Design 2): the one `X.Y.Z` run in the URL. A URL with no such run, with two runs, or with `0.0.0` is not a candidate (R-H3). The tag text around the run is part of the group. So the tags `v1.2.0` and `1.2.0` give two groups, and the tag `0.26.0-rc1` is not in the group of `0.26.0`. |
| R-DI6 | A candidate is in the group of a header entry only when its group key is equal. For a new entry (`tln add`), Talon uses the URL form (the group without the series, Design 4.1) of the newest candidate by `published_at`. All series in that URL form are candidates. When the repo has candidates in another URL form, Talon prints a note. |
| R-DI7 | Kind, deps and the `roc:` pin come from the archive, only when the solver or the closure walk asks for them (Resolution 5, R-AL8, sources 3 and 4). A registry answer that lacks a hash uses the same rule (Registry 4.1, R-AP28, case 3). Talon downloads the asset, checks the hash, and extracts it into `packages/<hash>/` (7.1, 7.2). Then it reads the header of `packages/<hash>/main.roc`: the first keyword gives the kind (`app`, `package` or `platform`), the URL entries give the deps, and the `roc:` entry gives the pin (Resolution 3, rank 3). Talon keeps no second copy of these facts. After GC removes the package, Talon downloads it again. |
| R-DI8 | The `.roc-version` hint (Resolution 3, rank 4) comes from `https://raw.githubusercontent.com/<owner>/<repo>/<tag>/.roc-version`, only when the solver needs a hint for that candidate. A `404` answer means no hint. |
| R-DI9 | The solver asks for candidates in the order of the strategy: newest first for `highest`, oldest first for `lowest`. So a resolve usually downloads one or two archives for each free variable. Archive and `.roc-version` downloads do not go to `api.github.com`, so they do not use the API rate limit, and Talon sends no token with them (section 1). |
| R-DI10 | The release time is the GitHub `published_at` of the release. `min-release-age` and `--snapshot <time>` use it (R-C7, Resolution 11). |
| R-DI11 | A URL whose host is not `github.com` has no index in `direct` mode. The entry acts as an anchor at its header value: its domain is that one value, and no command frees it. Talon still fetches it, reads its deps (R-DI7) and probes it. `tln update`, `tln upgrade` and `tln outdated` print `fixed: <host> has no index without a registry`. `tln add` of a name on such a host stops with exit code 2 and names `--registry`. With a registry, the registry index gives the candidates (Registry 4, R-AP13). An ingest adds a release of such a host to the index (Registry 4, R-AP9, Registry 7). |
| R-DI12 | With `--offline`, Talon sends no request. It uses the cached pages and prints `index: cached at <time>` once. A candidate whose archive is not in `packages/` is skipped. A group with no cached page acts as in R-DI11. A new group with no cached page (`tln add`) fails with exit code 15. Without `--offline`, a network error stops the command with exit code 15, and the message names `--offline`. |
| R-DI13 | When GitHub answers with a rate limit error, Talon stops with exit code 15 and writes nothing. The message gives the reset time and the three token sources (section 1). |
| R-DI15 | A tag that is released again with a new asset hash. When a candidate has the label (group and version) of a URL that Talon already knows with another hash, the candidate is not a candidate. Talon knows a URL from a header entry (Design 4.2), and from the deps of each package header in the closure that it has read (R-DI7). Talon prints a warning that names the release and both hashes, as for R-DI4. The header value keeps its old hash (Resolution 2, R-C9). Its download fails with a 404 when the old asset is not in `packages/` (7.1, R-FE6). With no such URL, the new hash is a candidate, and here `direct` mode and the registry differ (R-DI14, Registry 7, R-PU19 and R-PU20). Reason: `direct` mode has no log, and Talon keeps no second copy of index facts (R-DI7). |

Cost of one command in `direct` mode:

| Action | REST API calls | Other downloads |
| --- | --- | --- |
| List one repo (R-DI2) | 1 for each 100 releases. Most repos need 1 (basic-cli has 46 releases). | 0 |
| List one repo again after 60 s | 1 for each page. A `304` answer is free with a token. | 0 |
| Kind, deps and pin of one candidate (R-DI7) | 0 | 1 archive, at most 10 MB |
| The closure of one tuple (Resolution 5, R-AL8, R-AL9) | 0 | 1 archive for each winner that is not in `packages/`, in at most d rounds (d: the depth of the closure) |
| `.roc-version` hint (R-DI8) | 0 | 1 small file |
| List the compiler releases (R-CV1, 6.2) | 1 for each 100 nightlies | 0 |
| `tln add` in an app with 3 direct deps and a platform | About 5 | About 4 to 8 archives |

With no token, the limit is 60 API calls an hour (section 1). That is about 10 such commands an hour.

### 7.4 Concurrent Talon processes

Many `tln` processes can run at the same time: 3 `roc` builds through the proxy, a CI matrix on one machine, an editor plugin, `tln cache gc` in a second terminal. This section has all the rules for them. Other sections refer to it.

| Item | Writers | Mechanism | Rule |
| --- | --- | --- | --- |
| `packages/<hash>/` | roc, `tln` | Temp and `rename`. The loser drops its copy. | R-CC11 |
| `toolchains/<id>/`, `toolchains/zig-<version>/` | `tln` | Lock of the id, then temp and `rename` | R-CC4 |
| `toolchains/<id>/.last-use` | proxy, probes | Write with no read | R-CC9 |
| `tools.json`, `projects.json`, `config.toml` | `tln` | Lock of the file around read, change, write | R-CC6 |
| App header, `talon.toml` | `tln`, people, editors | No lock. Compare the bytes before the `rename`. | R-CC7 |
| `talon/compat.db` | `tln` | SQLite WAL and a busy timeout | R-CC8 |
| `talon/x/<build digest>/`, `talon/index/` | `tln` | Temp and `rename` | R-CC11 |
| All of the above | `tln cache gc`, `tln roc rm` | GC lock, toolchain lock, age rule, rename to `.trash` | R-CC10 |

| # | Rule | Reason |
| --- | --- | --- |
| R-CC1 | Each write of a file or a dir goes to a temp `<target>.<16hex>.tmp` in the same dir, then a `rename` to the target. Talon writes no file in place. | A reader sees the old or the new item, never a part of one. The same dir gives the same file system, so the `rename` is atomic. |
| R-CC2 | Talon has no signal handler (Design 6.2, R-HF8). A crash, a kill or Ctrl-C can leave a temp, or a `.trash` dir (R-CC10). No command reads a temp. The lock holder of an item deletes the temps of that item (R-CC4). `tln cache gc` deletes the other temps, the `.trash` dirs and `talon/tmp/<16hex>/` (probe copies of an app) when they are older than 1 day (6.3). This age is the file modification time, compared with the real clock (section 1, `TALON_NOW`). A command deletes its own `talon/tmp/` dir when it ends. | One rule covers Ctrl-C, a kill and a power loss. A signal handler covers only Ctrl-C. A temp younger than 1 day can belong to a running process. |
| R-CC3 | Locks have one interface, in the `Fx` record (`TESTING.md` 2.3): `lock!(item, Wait \| NoWait)` gives `Held(lock)` or `Busy`, and `unlock!(lock)`. Command code takes a lock only with `with_lock!(fx, item, mode, body!)`, which calls `unlock!` also when `body!` returns an error. The contract: (1) an item has one holder at a time, across all processes on the machine; (2) a lock ends when the holder releases it, or at most 30 s after the holder process ends (a crash or a kill); (3) a lock stays held during all other `Fx` calls of the holder, also a long download or probe round; (4) the lock of the item `X` is at the path `X.lock` (6.1); (5) no `ask!` call (a prompt, section 4) runs while the command holds a lock, because a blocking read of stdin cannot keep a lock alive (R-CC12). A command asks before it takes a lock (R-CC4, step 2). No other rule and no command says how a lock is made. R-CC12 is the implementation, and only the real `Fx` contains it. | A change of the lock mechanism (for example an OS file lock, when basic-cli has one, Design 6.2, R-HF3) changes R-CC12 and the real `Fx` only. The rules that take locks, the command code and the L2 tests stay the same. |
| R-CC4 | A toolchain install (a compiler or Zig) follows the steps in the table below. | Only one process downloads a missing compiler. The others wait for it. |
| R-CC5 | A process that waits for a lock prints `waiting for another tln: <item>` once to stderr. It waits until the lock ends (R-CC3, point 2). Ctrl-C stops the wait. | A wait needs no other timeout: a live holder releases the lock, and the lock of a dead holder ends. |
| R-CC6 | `tools.json`, `projects.json`, `share.json` and `config.toml` change only under the lock of the file (the item `tools.json`, and so on, R-CC3). Talon takes the lock, reads the file, changes it, writes it (R-CC1), and releases the lock. A person can edit `config.toml` too, so Talon changes it with the span edit of `roc-toml` (comments and order stay, as R-H1) and the byte compare of R-CC7 before the `rename`. It holds the lock for this step only, not during a build or a download. A command that builds first (`tln tool install`) takes the lock for its final step, and checks again for a binary name clash under the lock (6.4). | Last writer wins loses data: a lost `tools.json` entry leaves a binary that no command manages (R-T4), a lost `projects.json` entry lets GC remove a compiler that a project pins (6.3), and a lost `config.toml` change undoes `tln roc default`. The lock is held for milliseconds, so a wait is short. |
| R-CC7 | Project files (the app header, member files, `talon.toml`) get no lock: people and editors write them, and they do not take Talon locks. Talon keeps the bytes that it read. Just before the `rename` (R-CC1), it reads the file again. Same bytes: Talon writes. Other bytes, but each span that Talon edits has the same text (in a `.roc` file the header, in `talon.toml` each table that Talon changes): Talon applies its span edit (R-H1, `roc-toml`) to the new bytes, then writes. Else Talon writes no project file, names the file, and stops with exit code 17 (`conflict`, section 3). For more than one file, Talon checks all of them first, then writes each: each `talon.toml` first, the `.roc` files last. | A probe run can take minutes. Talon must not overwrite an edit that a person made in that time. The second of two `tln` commands in one project gets exit code 17 and runs again. A crash between two writes leaves new ranges and an old header, and the next `tln install` finishes the move (Resolution 9). The other order would leave a new header out of the old range, and `tln install` would move it back. |
| R-CC8 | `compat.db` uses the SQLite WAL journal (`PRAGMA journal_mode=WAL`) and `PRAGMA busy_timeout=5000`. Each write round of probe facts (R-PP4) is one transaction. If the database stays busy past the timeout, Talon keeps the facts in memory for this command, prints a warning, and goes on. When the file system does not support WAL, SQLite keeps its default journal, and the busy timeout still applies. | Readers do not block the writer in WAL mode. A fact is evidence: a lost write costs a probe later, not a wrong result. |
| R-CC9 | The last use of a toolchain is the time in `toolchains/<id>/.last-use`. The proxy and each probe write the time of Talon (`TALON_NOW`, section 1) to this file (R-CC1) before the compiler starts. | A write with no read needs no lock, so parallel builds do not wait for each other. `.talon.json` stays unchanged after the install. |
| R-CC10 | `tln cache gc` takes the lock of the item `talon/gc` with `NoWait`. When another GC holds it, GC prints `another tln cache gc runs` and exits with code 0. For each toolchain to remove, GC takes its lock with no wait, and skips it when an install holds the lock. It also skips a toolchain with a last use (R-CC9) in the last day: a running build wrote it when it started. Then GC renames `toolchains/<id>/` to `toolchains/<id>.<16hex>.trash` and deletes that dir. `tln roc rm` (6.6) does the same with no age rule, because the user named the compiler. On Linux and macOS, a running compiler keeps its open file. On Windows, the `rename` fails while the compiler runs: Talon reports the compiler as in use, removes nothing, and exits with code 17 (`conflict`, section 3). GC removes `packages/<hash>/` with the age rule of 6.3 only. | GC never removes a compiler while an install writes it, or a compiler that a build uses. A build of a project that is not known can lose a package while it runs. That build fails once, and the next `roc` run fetches the package again. |
| R-CC11 | `packages/<hash>/`, `talon/x/<build digest>/` and the pages in `talon/index/` get no lock. Two processes can write the same item. Each writes a temp (R-CC1). The first `rename` wins. The second drops its copy (a dir), or replaces the file with equal content (an index page). | The content of each item is fixed by its name (a hash, a digest) or is a full answer. Any copy is correct. roc takes no lock for `packages/`, so a Talon lock cannot exclude roc. |
| R-CC12 | The implementation of R-CC3. The lock is the directory `<item>.lock/`. `lock!` takes it with `Path.create_dir!`, which fails when the directory exists. The holder writes a random token (16 hex digits from `Random`) and its start time to `owner` in that directory: basic-cli gives no process id and no host name. `unlock!` deletes the directory only when `owner` holds its own token. A lock directory with no `beat` file (a crash between `create_dir!` and the first write of `beat`) has the age of the directory: its modification time. The real `Fx` writes the file `beat` again every 2 s for each lock that it holds. It does this inside its own waits (the poll loop of 7.5 and R-PP1, and the wait of `lock!`), so command code does nothing for it. `unlock!` deletes the directory. A lock whose `beat` is older than 30 s is stale: `lock!` renames it to `<item>.lock.<16hex>.stale`, deletes that, and tries again. With `Wait`, `lock!` checks every 200 ms. The age of `beat` is its modification time, compared with the real clock, not `TALON_NOW` (section 1). Each step of the real `Fx` that is not a wait ends in under 25 s, so a beat is never 30 s late: the real `Fx` starts each child process (for example `tar`, `roc unbundle`, `curl`, `wget`, `zig build`, probes) with `spawn!` and polls it, gives each `Http.send!` a timeout of 20 s, and a hash of an archive (at most 512 MB, Design 2) takes a few seconds. | basic-cli has no OS file lock (Design 6.2, R-HF3). A lock in a child process does not work: a child that lives on after a crash of `tln` keeps the lock, and the `flock` command exists on Linux only. Cargo, Go and uv use an OS lock. npm tools (`proper-lockfile`) use this directory form. `mkdir` is atomic also on NFS. Limit: two processes that find the same stale lock in the same moment can both take it. This needs a crash first, and the temp and `rename` of R-CC1 keep each file whole. An OS lock has no such limit. |

Steps of a toolchain install (R-CC4). The same steps apply to `toolchains/zig-<version>/`:

| Step | Action |
| --- | --- |
| 1 | If `toolchains/<id>/` exists, use it. Take no lock. |
| 2 | Apply the consent rules R-DL1 to R-DL6 (6.2). The one prompt of the command (R-DL1) shows here, before Talon takes a lock (R-CC3, point 5). With no consent, stop (exit code 13). |
| 3 | Take the lock of the item `toolchains/<id>` with `NoWait`. If the answer is `Busy`, print the R-CC5 line and take it with `Wait`. |
| 4 | With the lock: if `toolchains/<id>/` exists now, release the lock and use it. A process that waited downloads nothing. |
| 5 | Delete each `toolchains/<id>.*.tmp`. Only the lock holder writes them, so each one is stale. |
| 6 | Download (7.5), check the sha256 (R-CV4), and extract with `tar` (Design 6.2, R-HF5) into `toolchains/<id>.<16hex>.tmp/`. Write `.talon.json` last. `rename` the dir to `toolchains/<id>/`. |
| 7 | Release the lock. A process that waits gets it and goes to step 4. If the dir is still missing (the first process failed), that process goes on at step 5 itself, with the consent of its own step 2. |

Example: 3 `roc build` runs start at the same time through the proxy. Each needs `nightly-2026-10-13-91fa0c2`, which is not installed. `TALON_AUTO_INSTALL=yes` is set.

```text
run A  step 3: lock ── download 70 MB, extract, rename ── release ── build
run B  step 3: waiting for another tln: nightly-2026-10-13-91fa0c2 ── step 4: dir exists ── build
run C  step 3: waiting for another tln: nightly-2026-10-13-91fa0c2 ── step 4: dir exists ── build
```

### 7.5 Download adapter

basic-cli `Http.send!` blocks and keeps the whole body in memory (Design 6.2, R-HF4). A nightly is 70 MB. So Talon downloads each file with a child process, `curl` or `wget`. One child writes one file, and many children run at the same time. `curl` is part of macOS, Windows 10 (1803 or later) and most Linux systems. `wget` covers most of the others. The install scripts use the same pair (6.5).

| # | Rule |
| --- | --- |
| R-DA1 | The adapter downloads package archives (7.1), compiler and Zig archives (6.2, 6.6), prebuilt binaries (6.4, 6.5) and nothing else. Small API answers (R-DI2, R-DI8, R-CV1, the registry API) use `Http.send!`. |
| R-DA2 | Talon uses `curl` when it is on `PATH`, else `wget`. `TALON_DOWNLOADER=curl` or `wget` selects one (section 1, environment variables). With none of them, the command stops with exit code 18 (`environment`). |
| R-DA3 | Command lines. `curl`: `curl --fail --location --silent --show-error --proto =https,http --proto-redir =https --retry 2 --connect-timeout 30 --output <temp> <url>`. `wget`: `wget --quiet --tries=3 --timeout=30 --output-document=<temp> <url>`. Talon checks the URL scheme first (7.1, URL schemes). With `curl`, a redirect never goes to `http://` (`--proto-redir`). `wget` has no such option, so a download with no published hash (a source archive, 6.6, R-R7) needs `curl`: with only `wget`, it stops with exit code 18 and names `curl`. Talon passes no token and no header, so a download carries no credentials (section 1, R-DI9). Both programs read the proxy variables (`HTTPS_PROXY`, `NO_PROXY`) and the CA store of the system, so Talon reaches the network as other tools on that machine do. |
| R-DA4 | The output goes to a temp file in the target dir (7.4, R-CC1). Talon checks the hash before any other use: BLAKE3 for a package (`roc unbundle`, 7.1), sha256 for a compiler (R-CV4), for Zig (R-D2) and for `tln` (R-S1). A source archive has no published hash (6.6, R-R7). Then it renames or extracts the file. |
| R-DA5 | Talon runs up to 8 downloads at the same time. It polls them with `try_wait!` in the same loop as the probes. A download takes no probe slot (Resolution 4, R-PP1). The same item is downloaded once, also by many processes (7.4, R-CC4 for toolchains, R-CC11 for packages). |
| R-DA6 | Progress is the size of the temp file, read in the poll loop. The total comes from the asset size in the release list (R-DI2, R-CV1), when it is known. |
| R-DA7 | A child that exits with an error gives exit code 15 (`network`). The message names the URL and the last stderr line of the program. An HTTP error answer (`curl` exit 22, `wget` exit 8) makes Talon try the mirrors first (7.1). Ctrl-C also stops the children, because they share the process group (Unix) or the console (Windows). A temp file that stays is removed as in R-CC2. |

