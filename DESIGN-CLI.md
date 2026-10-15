# Talon design: CLI

Part of the Talon design. This file holds the `tln` commands, references, exit codes, prompts, the toolchain manager and the fetch pipeline. `DESIGN.md` has the goals, the core model and the list of files.

A reference such as CLI 6.2 is section 6.2 of `DESIGN-CLI.md`. Design, Resolution and Registry name `DESIGN.md`, `DESIGN-RESOLUTION.md` and `DESIGN-REGISTRY.md`. A plain number is a section of this file.

## 1. Commands

| Command | Does | Bun equivalent |
| --- | --- | --- |
| `tln init [app\|package] [--platform <name>] [--ci github\|none]` | New app or package, with the nightly as the `roc:` entry of the header (not `.roc-version`, Resolution 13) and a CI file. Rules: section 5. | `bun init`, `bun create` |
| `tln install [name[@sel]...] [--platform] [--as <alias>] [--no-pin] [--no-check]` | With no names: keep the header, change only entries that break `talon.toml`, fetch the closure (Resolution 9). With names: add each one, resolve, write the header. Lookup, alias and `talon.toml` rules: section 2. `add` and `i` are the same command. | `bun install`, `bun add` |
| `tln remove json [--force]` | Remove the entry, its range, its override and its patch entry. Rules: section 2. | `bun remove` |
| `tln update [pkg[@sel]...] [-i] [--no-check]` | Move within ranges. Names limit the scope. `pkg@sel` moves to the selector, also to a new series (Resolution 10). The nightly does not move (RP1). `-i` is an interactive picker. Scope rules: Resolution 9. | `bun update -i` |
| `tln upgrade [pkg...] [roc] [--no-check]` | Move to the newest releases, also to new series, and to the newest nightly. Change the `talon.toml` ranges to match. Names limit the scope. The name `roc` frees the nightly. Rules: Resolution 10, RP1. | `bun update --latest` |
| `tln outdated` | Table: current, wanted, latest, nightly range | `bun outdated` |
| `tln why parser` | Paths from the app to a package, and why this version (evidence) | `bun why` |
| `tln probe [pkg] [--range] [--share]` | Find the nightly range of a release. Optionally share the result | |
| `tln list [--tree]` | Closure with marks: shared, resolved, foreign, patched | `bun pm ls` |
| `tln patch json [--diff]` | Edit a copy of a dependency. The copy is the patch, and it goes in VCS. `--diff` prints it against the original (Resolution 7, PA1 to PA8). | `bun patch` |
| `tln verify [--strategy highest\|lowest]` | Resolve in memory, run the probe ladder (Resolution 4) on the tuple with `--replace-dep`, and print the result. It writes no header and no `talon.toml`. Probes add evidence to `compat.db` as usual. It does not replace `roc check` (N2). Use: Resolution 8. | |
| `tln x owner/app [-- args]` | Build a Roc app and run it once. The binary stays in the cache. Rules: 6.4, X1 to X5. | `bunx` |
| `tln publish` | Register a release (Registry 7) | `bun publish` |
| `tln audit` | Yanked, advisories, scanner hook. With `direct`: header entries whose GitHub release is deleted, and the scanner hook, with a note that there is no yank and advisory data (Resolution 2, C6). | `bun audit` |
| `tln roc install/link/use/list/remove/default/update` | Compiler management. A nightly, a release, or a git ref built from source (6.6). `link --copy` copies a local build (LK2). `use` writes the header `roc:` pin, `default` writes the global default, `update` installs the newest compiler release that the `nightly` switch allows and moves the global default (6.6). | (uv `python`, rustup `toolchain link`) |
| `tln tool install/list/update/rebuild/remove` | Global tools: build a Roc app (a release or a git ref) and put it on `PATH` (6.4). Talon is one of them (6.5). | `bun add -g` (uv `tool`) |
| `tln cache gc/clean/list/dir` | Cache management: `gc` keeps what projects use, `clean [--all]` removes on request (6.3) | `bun pm cache` |
| `tln setup` | Install the `roc` proxy, the `PATH` line and shell completions (6.7) | |

Verb aliases. A long form and its other forms are the same command at every level: top level, `tool`, `roc` and `cache`. Help and error text print the long form.

| Long form | Other forms | Example |
| --- | --- | --- |
| `remove` | `rm` | `tln rm json`, `tln tool rm app`, `tln roc rm <id>` |
| `list` | `ls` | `tln ls`, `tln tool ls`, `tln roc ls`, `tln cache ls` |
| `install` | `i`, `add` | `tln i`, `tln add json`, `tln tool i owner/app`, `tln roc i <ref>` |
| `update` | `up` | `tln up json`, `tln tool up app`, `tln roc up` |

The design files use either form. The command table above uses the long form.

Global flags work for every command:

| Flag | Meaning |
| --- | --- |
| `--json` | Machine-readable output. Turns on non-interactive mode (section 4). `tln x` rejects it with exit code 2, because the app writes to stdout (J1). The `roc` proxy has no Talon flags (6.2). |
| `--yes` | Answer each prompt of the command with no prompt: "yes" to a yes/no prompt, and the default option of a prompt with options. Downloads too (DL5, 6.2). Each Required prompt also has its own answer flag (section 4). |
| `--offline` | Use the cache only (7.1) |
| `--quiet` | Print only errors and the answer lines of section 4. An answer line records an action, so `--quiet` keeps it. |
| `--registry <url\|direct>` | Registry base URL. `direct` uses the GitHub API with no registry (Registry 1). |
| `--file <path>` | The project file (see "The project" below, PD1). Only for a command that uses a project. Other commands reject it with exit code 2. |

Resolve flags work only for commands that resolve: `install` (and `add`), `remove`, `update`, `upgrade`, and `verify` (Resolution 8). Other commands (`roc`, `tool`, `cache`, `x`, `list`, `why`, and the rest) reject them with an error. One exception: `--slots` also works for `probe`, `tool install` and `x`, because they run probes (Resolution 4, PP2).

| Flag | Meaning |
| --- | --- |
| `--frozen`, `--no-probe`, `--no-check`, `--dry-run` | See Resolution 12 |
| `--snapshot <log:N\|time>` | Hide releases added after a registry log size (`log:N`, registry only) or published after a UTC time (RFC 3339, registry or `direct`). See Resolution 11. |
| `--strategy highest\|lowest` | Version choice (Resolution 8). `upgrade` rejects `lowest` (UP8). |
| `--slots <n>` | Size of the probe slot pool (Resolution 4, "Parallel probes"). Default 12: 12 checks or 3 builds at the same time. |

Command flags that other sections define:

| Flag | Commands | Where |
| --- | --- | --- |
| `--force` | `remove` | section 2 |
| `--rename-keys` | `install`, `add` (answers NI1) | Design 4.3 |
| `--allow-moves` | `install`, `add`, `update`, `upgrade` (answers NI3) | Resolution 9 |
| `--probe-downloads` | Commands that resolve, and `probe` (answers NI4) | 6.2 |
| `--roc pinned\|installed`, `--allow-unchecked`, `--resolve` | `tool install`, `x` (answer NI8, NI9) | 6.4 |
| `--remove-tools`, `--keep-all` | `tool rm talon` (answer NI10) | 6.5 |
| `--replace-roc`, `--no-modify-path` | `setup` (answer NI13, NI14) | 6.7 |

`--frozen` works only for `tln install` with no names. The other commands, and `install` with names, exist to change the header, so they reject `--frozen` with exit code 2.

`tln verify` always writes nothing, so it rejects `--dry-run` and `--frozen`. `--git` (section 2) works only where a ref can be a git ref: `tln tool install`, `tln x`, `tln roc install` and `tln roc default`. `tln tool install` and `tln x` have their own flag `--resolve` (T1, X1). `tln cache gc` and `tln cache clean` have their own `--dry-run` (6.3).

Registry precedence, from high to low:

| Priority | Source |
| --- | --- |
| 1 | `--registry <url\|direct>` |
| 2 | `TALON_REGISTRY` (a URL, or `direct`) |
| 3 | `registry` in `config.toml` (6.1) |
| 4 | The built-in default: `direct` |

The built-in default is one constant in the Talon binary, not a file. It stays `direct` until the registry runs (Design 7, P2). Then a Talon release changes the constant to the registry URL. A user who set no registry moves to the registry with `tln tool update talon` (6.5). A user who wants `direct` after that sets it in `config.toml`.

With `direct`, and for the list of nightlies, Talon calls the GitHub API (7.3, CV1). With no token, GitHub allows 60 requests an hour for one IP address. So Talon uses a token when it finds one, in this order: `GITHUB_TOKEN`, `GH_TOKEN`, then the output of `gh auth token` when `gh` is installed and logged in. Talon sends the token only to `api.github.com`, never to a registry or a mirror. With no token, a rate limit error (exit code 15) names these three sources.

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

### The project

A command that uses a project works on one project file: a `.roc` file with an `app`, `package` or `platform` header. Most projects have one project file, `main.roc`. A workspace (Design 4.4) has one for each member.

| Command | Uses a project |
| --- | --- |
| `install` (and `add`), `remove`, `update`, `upgrade`, `outdated`, `why`, `list`, `patch`, `probe`, `verify`, `audit`, `publish`, `roc use` | Yes. Talon finds it with PD1 to PD6. |
| `init` | It creates `main.roc` in the current directory (section 5). It does not search. |
| The other `roc` subcommands, `tool`, `x`, `cache`, `setup` | No. They reject `--file`. A relative selector `@+N` or `@-N` (section 2) uses the target file of the proxy (PD7). |
| The `roc` proxy | Its target file (PD7). It has no Talon flags. |

| # | Rule |
| --- | --- |
| PD1 | The start directory is the current directory. With `--file <path>`, the start directory is the directory of that file, and that file is the project file. The command then acts as if it ran in that directory. |
| PD2 | Talon walks up from the start directory. The walk stops after the first directory that holds `.git` (a directory or a file), or at the home directory, or at the file system root. Talon checks the stop directory too. So a `main.roc` or a `talon.toml` outside the repository has no effect. |
| PD3 | The workspace root is the nearest directory on the walk with a `talon.toml` that has a `[workspace]` table. Its member files are the files that its `members` patterns match (Design 4.4). |
| PD4 | With no `--file`, Talon looks for the project file in each directory of the walk, from the start directory up. It stops at the workspace root, if there is one. In each directory: (1) if it holds member files, the project file is the member file when it is the only one, and with 2 or more Talon stops with exit code 2 and lists them; (2) else, if it holds `main.roc`, that is the project file. At the workspace root, only member files count. Talon finds no other file name by itself: for example, the member `examples/hello.roc` needs `--file`, or a start directory where it is the only member file. |
| PD5 | A member file is part of its workspace: the command works on the workspace, with that file as the current member (Design 4.4). A project file that is not a member file is a standalone project, also inside a workspace directory: the workspace has no effect on it. With no project file and a workspace root, the command works on the workspace with no current member. With neither, the command stops with exit code 2. The error names the directories that the walk checked, and `--file`. |
| PD6 | The `talon.toml` of a standalone project is the `talon.toml` in its own directory, if that file has no `[workspace]` table. A `talon.toml` in a parent directory is the intent of another project and has no effect. The `talon.toml` of a member is the nearest one on the path from the member directory up to the workspace root (Design 4.4). |
| PD7 | The `roc` proxy does not search for a project file. Its target file is the file that roc compiles: the first argument that names a `.roc` file, else `main.roc` in the current directory (Resolution 13). Then PD1, PD3, PD5 and PD6 apply, as for `--file <target file>`, to find its `talon.toml`. With no target file, the proxy uses no header and no `talon.toml`. |
| PD8 | The project file must have an `app`, `package` or `platform` header. Else Talon stops with exit code 2. |

Known projects. GC (6.3) and RR2 (6.6) use the list `talon/projects.json` (6.1):

| # | Rule |
| --- | --- |
| PD9 | Each command that uses a project records each project file that it reads: its canonical absolute path and the last-use time. A workspace command records each member file that it reads. `tln init` records the file that it creates. |
| PD10 | The proxy records its target file when the file has an `app`, `package` or `platform` header. It writes `projects.json` only when the entry is new or its last-use time is older than 1 day, so most runs write nothing (cost target, 6.2). |
| PD11 | Talon never records a temp copy (`talon/tmp/`, 7.4) or a file in `packages/<hash>/`. |
| PD12 | An entry holds only the path and the last-use time. GC and RR2 read the header of each project file again when they run: its `roc:` pin, and its closure from the package headers in the cache. So a hand edit of the header counts. |
| PD13 | An entry leaves the list when GC or RR2 finds that its file is missing or has no `app`, `package` or `platform` header, or when GC finds that its last use is older than the GC age (6.3). Such an entry protects nothing. `tln cache clean` keeps the list (6.3). |

### Environment variables

A flag has priority over a variable (6.1).

| Variable | Value | Effect | Where |
| --- | --- | --- | --- |
| `TALON_REGISTRY` | A URL, or `direct` | The registry | Registry precedence above |
| `GITHUB_TOKEN`, `GH_TOKEN` | A token | GitHub API token | Above |
| `TALON_NIGHTLY` | `0`, `1` | The `nightly` switch | Resolution 1 |
| `ROC_TOOLCHAIN` | A full compiler id | Compiler selection, rank 2 | Resolution 13 |
| `TALON_AUTO_INSTALL` | `ask`, `yes`, `no` | Required compiler and Zig downloads | 6.2, DL5 |
| `TALON_PROXY` | `0` | The proxy does no extra work | 6.2 |
| `TALON_INTERACTIVE`, `CI`, `DEBIAN_FRONTEND`, `NONINTERACTIVE` | See section 4 | Interactive or non-interactive mode | 4 |
| `NO_COLOR` | Any | No color | 4 |
| `TALON_YES` | `1` | The install script does not prompt | 6.5, IS4 |
| `ZIG` | A path | The Zig for source builds | 6.6, D1 |
| `TALON_DOWNLOADER` | `curl`, `wget` | The program for downloads | 7.5, DA2 |
| `XDG_CACHE_HOME`, `ROC_CACHE_DIR`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME` | Paths | Directory roots | 6.1 |
| `TALON_GITHUB_API` | A base URL | Test hook (below) | Below |
| `TALON_NOW` | A UTC time, RFC 3339 | Test hook (below) | Below |

Test hooks. With them, a test (`TESTING.md` 3) needs no network and no real clock. A user does not need them.

| Variable | Rule |
| --- | --- |
| `TALON_GITHUB_API` | The base URL of the GitHub REST API, in place of `https://api.github.com` (7.3, DI2, and the list of compiler releases). When it is set, Talon reads no token source and sends no token. It changes no header URL and no group (H5). Asset URLs come from the API answers, so a fake API can give loopback asset URLs. |
| `TALON_NOW` | The time for each decision of Talon about the age of data: GC ages (6.3), the last-use times that Talon records (PD9, CC9), `min-release-age` (C7), and the time that a resolve prints (Resolution 11). It does not change the age of a lock heartbeat or of a temp (CC2, CC12): these tell if a process is alive, so they use file modification times and the real clock. It does not change the clock of roc: roc expires its build-cache files by itself (Design 2.2). |

Packages in tests. Talon has no fetch map from a header URL to another host: that is a second kind of mirror (7.1, H5). A test gets a package in one of two ways:

| Case | How |
| --- | --- |
| The header URL must keep `github.com`: group keys, lookup, H5 | The case pre-fills `packages/<hash>/` in its cache. Talon and roc accept it with no sidecar (Design 9 Q2, 7.2), and fetch nothing. |
| A test of the fetch path: download, hash check, a slow body, a 404 | The fixture uses a loopback URL, for example `http://127.0.0.1:<port>/x/1.0.0/<hash>.tar.zst`. Talon accepts the package URLs that roc accepts: `https://` to any host, and `http://` only to `127.0.0.1`, `::1` and `localhost` (`roc:src/unbundle/download.zig`, test in `research/roc-http-fetch/`, Design 9 Q24). A loopback URL is its own group (Design 2), so these cases do not test the identity of a `github.com` package. |

## 2. References in the CLI

One grammar names packages, platforms, tools and compiler releases:

```text
ref      = name [ "@" selector ] | "@" selector | nightly-tag
name     = alias | owner/repo | host/path | short
selector = version | range | series | "latest" | nightly-tag | git-ref | ("+" | "-") count
```

The two short forms are valid only in the `tln roc` scope. There the default name is `roc-lang/roc`:

| Short form | Means |
| --- | --- |
| `@sel` | `roc-lang/roc@sel` |
| `nightly-2026-10-09-258ab27` | A nightly tag with no `@`. `roc-lang/roc@nightly-2026-10-09-258ab27` is the same ref. |

| Selector | Example | Meaning |
| --- | --- | --- |
| Release version | `owner/app@1.4.0` | That release |
| Range or series | `roc-lang/http@^2`, `roc-lang/http@2`, `roc-lang/basic-cli@0.25` | The newest match. A series (Design 4.1) is the major, or `0.minor` below 1.0. For an installed entity, it selects among the installed ones. |
| Latest | `owner/app@latest` | The newest release that is not yanked, found online. In `tln tool install` and `tln x`, it turns off the reuse of an older build (6.4, B2). In `tln add`, it is the same as no selector. In `tln update X@latest`, it is the newest release, also in a new series (Resolution 10). |
| Nightly tag | `@nightly-2026-10-09-258ab27` | That nightly (compiler only) |
| Relative step | `@-1`, `@+2` | Compiler only. The compiler release N steps older (`-`) or newer (`+`) than the compiler that Resolution 13 selects in the current directory, in the domain of the `nightly` switch (Resolution 1, NS3). Talon uses the online list of releases. With `--offline`, or with no network, it uses the installed releases and prints a note. Talon stores the full id. Use: `tln roc use @-1` when the newest nightly breaks a project. |
| Git ref | `owner/app@dd03c09e`, `--git owner/app@main` | A source build. A branch or tag is fixed to a commit at install time. |

Talon reads a selector with these rules, in order:

| # | Selector | Result |
| --- | --- | --- |
| 1 | Matches a release, a range, a nightly, a relative step, or the word `latest` | Used. No marker is needed. A branch named `latest` needs `--git` (rule 3). |
| 2 | Looks like a commit sha (hex only, at least 7 characters), and no release matches | Taken as a git ref, with no `--git`. |
| 3 | A branch or tag name | Taken as a git ref only with `--git`. |
| 4 | None of the above, and no `--git` | Error. Talon lists the close release versions and says `use --git for a branch or tag`. |

So a typo such as `owner/app@mian` is an error. It never starts a source build. `--git` skips rules 1 and 2 and takes the selector as a git ref.

No selector means different things in different scopes. In `tln add` and `tln update`, it means the newest release in range. `tln upgrade` ignores package ranges (Resolution 10). In `tln tool install` and `tln x`, it means "this app, at any version": Talon first uses a build that is already on this machine, and builds the newest release only if there is none (6.4, B1 and B2).

The separator is `@`, not `#` as in npm, because the shell reads `#` at the start of a word as a comment. Some shells also read `^` (zsh with `EXTENDED_GLOB`) and `~` as special. Quote a ref that has them: `'roc-lang/http@^2'`. The shell-safe forms `@2`, `@2.x` and `@2.1.x` need no quotes. `@2.x` means the same as `@^2`, and `@2.1.x` means 2.1.0 up to, but not including, 2.2.0. Below 1.0, the series has two parts (Design 4.1): `@0.25` and `@0.25.x` mean the same as `@^0.25`, that is 0.25.0 up to, but not including, 0.26.0. `@0.x` spans many series, so it is a range over many groups, like `*`.

Each command works in one scope, so names of different kinds never collide:

| Command | Scope |
| --- | --- |
| `tln update`, `upgrade`, `remove`, `why`, `patch` | Project: header entries and the closure. In `tln update X@sel`, Talon finds X in the project and the releases that match `sel` in the registry. |
| `tln install` with names (and `add`) | The registry index. With no registry (`TALON_REGISTRY=direct`), GitHub. Never the project. |
| `tln tool ...` | `tools.json` (6.4). `tln tool install` with a full name: the registry index. |
| `tln x` | Installed tools and `x` cache entries (6.4). With a full name: the registry index. |
| `tln roc ...`, `roc +<id>` | Installed compiler releases (6.6) |

In a scope, Talon tries these forms in order and uses the first match:

| # | Form | Example | Rule |
| --- | --- | --- | --- |
| 1 | Header alias | `pf` | Exact. An alias is unique in a header. |
| 2 | Full name | `roc-lang/basic-webserver` | Exact. Non-GitHub hosts use `host/path` (Design 4.1). |
| 3 | Short name | `basic-webserver`, `parser` | The repo name, or the repo name minus a leading `roc-` (the alias rule below, without `-` to `_`). So `parser` and `roc-parser` both match `lukewilliamboswell/roc-parser`. It must match one entity only. |
| 4 | Unique id prefix | `git-dd03`, `nightly-2026-10-09` | Compiler releases only, as a git short sha. Interactive use only (see the prefix rules below). |

Prefix rules. A prefix that is unique today can become ambiguous after a later install. So Talon stores only full ids:

| Place | Prefix allowed? | Behavior |
| --- | --- | --- |
| `tln roc ...` arguments | Yes | Talon expands it to the full id. An ambiguous prefix is an error that lists the full ids. |
| `roc +<id>` typed by hand | Yes | Same expansion and same error. A script must use the full id. |
| `ROC_TOOLCHAIN`, `roc:` pin, `.roc-version`, `talon.toml` | No | The full id only. A prefix is an error. |
| `tln roc default` | Stores the full id | Talon expands the prefix first, then stores the full id. |

On a tie, Talon stops and lists the full names:

```text
error: "basic-webserver" matches 2 packages:
  roc-lang/basic-webserver      platform (pf)
  someone/basic-webserver       via web-utils
Use the full name.
```

The group includes the series (Design 2, 4.1), so one closure can hold `roc-lang/http` 1.x and 2.x. Then the series is part of the name: `roc-lang/http@2`, `roc-lang/basic-cli@0.25`.

### Lookup in `tln add`

`tln install X`, `tln i X` and `tln add X` are one command (section 1). The design files call it `tln add`. It names a package that is not yet in the header, so form 1 does not apply. These rules apply:

| Case | Talon does |
| --- | --- |
| Full name (form 2) | Uses it. No search. |
| Short name, registry on, one indexed package matches | Uses it. Prints the full name it chose, for example `matched "parser": lukewilliamboswell/roc-parser`. |
| Short name, registry on, more than one match | Stops. Lists the full names, as in the tie example above. |
| Short name, no match | Stops. Prints the error. Does not search GitHub. |
| Short name, registry off | Stops. GitHub has no index of short names. Asks for the full name. |

`tln tool install` and `tln x` do not search the registry for a short name. A short name must match an installed tool or an `x` cache entry. For a new app, the user types the full name. Reason: `tln x` runs the app at once, with no prompt (X4). A short-name match in the registry could run a different app with a similar name (typosquat). With no local match, Talon stops with exit code 2 and lists the registry matches as full names.

### Aliases in `tln add`

The default alias comes from the release name. Talon may shorten the name only to its complete unqualified name: the repo name, without the owner. The only exception: Talon drops a leading `roc-`. Talon does not drop other prefixes or suffixes, does not abbreviate and does not guess.

| Full name | Default alias | Why |
| --- | --- | --- |
| `roc-lang/basic-cli` | `basic_cli` | Repo name. `-` becomes `_`. |
| `roc-lang/unicode` | `unicode` | Repo name |
| `lukewilliamboswell/roc-parser` | `parser` | Leading `roc-` dropped |
| `someone/roc-json` | `json` | Leading `roc-` dropped |
| The platform entry | `pf` | A convention, not a name shortening. A header has one platform, and `pf` is the Roc habit. |

An alias is a Roc identifier. Roc names use only ASCII letters, digits and `_`. A package name starts with a lowercase letter. Some words are reserved (for example `app`, `package`, `module`, `import`, `if`, `match`, `for`). So `basic_cli` is valid. Talon applies these checks to the default alias, in order:

| Step | Rule |
| --- | --- |
| 1 | Change each `-` and `.` to `_`. |
| 2 | If the result does not start with a lowercase letter, or has another character that is not a letter, digit or `_`, Talon stops. It asks for `--as <alias>`. |
| 3 | If the result is a reserved word, Talon stops. It asks for `--as <alias>`. |
| 4 | If the alias exists in the header for a different group, Talon stops. It asks for `--as <alias>`. It never adds a suffix. |

`--as <alias>` sets the alias and skips the default rule. Talon still checks that the alias is a valid identifier and is free. If the group is already in the header under another alias, `tln add` adds no entry. It reports that alias (see the group check in Design 4.3).

### What `tln add` writes to `talon.toml`

The key is the header alias. The header always gets the entry.

| Command | Header | `talon.toml` |
| --- | --- | --- |
| `tln add X` (no selector) | New entry, newest version that resolves | Nothing. Talon does not create the file (G2). If the file exists, Talon adds no key: the implied range (Design 4.3) applies. |
| `tln add X@1.2.3` (exact version) | New entry at 1.2.3 | Anchor `X = "=1.2.3"`. Talon creates the file if it is missing, because the user stated intent. |
| `tln add X@^1.2`, `tln add X@1` (range or series) | New entry, newest version in range | Range `X = "^1.2"`, and `X = "^1"` for `@1`. Talon creates the file if it is missing. |
| `tln add X@1.2.3 --no-pin` | New entry at 1.2.3 | Nothing, as for `tln add X`. A later `tln update` can raise the version inside the series (Design 4.1), as the implied range allows. |

An exact version is a hard pin by default. This keeps Resolution 1 consistent: `tln add parser@2.0.0` makes an anchor. `--no-pin` gives an exact start version with no hard pin.

### `tln add --platform`

`tln add --platform owner/repo[@sel]` sets the platform. A header has one platform (C3).

| Case | Talon does |
| --- | --- |
| No platform in the header | Adds it with the alias `pf`, or the `--as` alias |
| A platform is in the header | Replaces it under the same alias, also when the new platform is another repo. The platform is free inside the selector. Other variables are held (Resolution 9). A package that names a platform must name the new one (C3), so it can need a move (prompt NI3). The `talon.toml` key of the old platform gets the new range (table in "What `tln add` writes to `talon.toml`"). |
| The release is not a platform | Error with exit code 2 (C4) |
| `tln add X` with no `--platform`, and X is a platform | Error with exit code 2 that names `--platform` |

### `tln remove`

| Case | Talon does |
| --- | --- |
| An entry that no app module imports | Removes the header entry, its `talon.toml` key and its `[overrides]` entry. Moves no other entry. Runs the whole-app check and the build (Resolution 4) on the new header, because the removed entry can have raised a shared version (Resolution 6). `--no-check` skips them. |
| An entry that an app module imports (the lexical scan of Resolution 4) | Stops with exit code 11 (`app_error`) and lists the `import` lines. `--force` removes it anyway and skips the check, because the app cannot check until the user changes the imports. |
| The platform entry | Error with exit code 2. An app needs a platform. `tln add --platform` changes it. |
| An entry with a `[patch]` entry (Resolution 7) | Also removes the `[patch]` entry. Keeps the files in `.talon/patches/<alias>/` and prints their path. |
| A path entry or a foreign URL (H4) | Removes the entry. It has no `talon.toml` key. |

## 3. Exit codes and JSON output

Exit codes and the `--json` schema are part of the public interface. A change needs a new `schema` version (see below). A new failure kind gets a new code. Talon never reuses a code.

| Code | Kind | Meaning | Source |
| --- | --- | --- | --- |
| 0 | `ok` | The command did its work | |
| 1 | `internal` | A Talon fault, or a compiler fault with no result | P7 (Resolution 4) |
| 2 | `usage` | Bad flag, bad ref, ambiguous name, invalid alias, a resolve flag on a command that does not resolve, a `log:` snapshot with no registry, an interactive-only flag (`update -i`) in non-interactive mode, `--frozen` on a command that changes the header, `--json` with `tln x`, no selected compiler (Resolution 13), no project file or no single current member (PD4, PD5, PD8), `--file` on a command that uses no project, a workspace rule (Design 4.4: members with different `roc:` pins, a key in the wrong `talon.toml`, an alias that names two groups), `tln remove` of the platform, or `tln patch` of the platform (Resolution 7, PA8) | Sections 1, 2 and 4, Design 4.4, Resolution 11 and 13 |
| 10 | `no_tuple` | No tuple works. Talon prints the explanation. | Resolution 5 |
| 11 | `app_error` | A new error in an app file, or `tln remove` of an alias that the app imports. Talon stops and reports. | Resolution 4 ladder step 2, section 2 |
| 12 | `budget` | A probe budget is spent before a tuple was found | Resolution 4, P5 |
| 13 | `consent` | A required prompt (section 4) has no answer: Talon is in non-interactive mode, and there is no `--yes` and no flag that gives the answer | section 4 |
| 14 | `frozen` | The header or a patch does not match `talon.toml`: `--frozen` found a mismatch or a needed resolve, or the proxy found a stale patch | Resolution 12, PA6 |
| 15 | `network` | A registry, GitHub or download error | 7.1, 7.3 |
| 16 | `integrity` | A hash or checksum does not match | 7.1, 6.2 CV4 and CV6, Design 8 |
| 17 | `conflict` | Another process changed or uses what the command must change: a project file (the header, `talon.toml`) changed while the command ran (CC7), or a compiler to remove runs on Windows (CC10). Talon wrote nothing. Run the command again. | 7.4, CC7, CC10 |
| 18 | `environment` | A program that Talon needs is not on `PATH`: `curl` or `wget`, `tar`, `xz` for a Zig archive, `sh` on Unix, or `powershell` on Windows (Design 6.2, HF11). The message names the program. | Design 6.2, 7.5 |

| Rule | Text |
| --- | --- |
| E1 | A command that runs a child process (`roc` proxy, `tln x`) exits with the exit code of that process. Talon codes apply only to failures that Talon finds before or after the child runs. |
| E2 | A command that fails for two reasons exits with the lower code in the table above, except `ok`. |
| E3 | `--quiet` and `--json` do not change an exit code. |
| E4 | The exit code alone cannot tell a Talon failure in E1 from a child failure with the same code (for example 13). So when Talon fails before or after the child runs, its last line on stderr is `tln: error[<kind>]: <message>`. A script that must tell them apart reads that line. |

The `--json` contract:

| # | Rule |
| --- | --- |
| J1 | stdout holds exactly one JSON document, written when the command ends. There are no JSON lines. |
| J2 | Human text, progress and warnings go to stderr. With `--json`, stderr stays human text. A program reads stdout only. |
| J3 | The document has a fixed envelope: `schema` (integer, the version of the envelope and of all command data), `command`, `ok`, `data`, `error`. |
| J4 | `data` is a command object when `ok` is true, and `null` when `ok` is false. |
| J5 | `error` is `null` when `ok` is true. Otherwise it has `kind` (a name from the table above), `code` (its exit code) and `message`. It may have `details`. |
| J6 | A new field in `data` does not change `schema`. A removed field, a renamed field or a changed meaning gives a new `schema` number. |

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
  "error": { "kind": "consent", "code": 13, "message": "1 compiler download (70 MB) needs consent. Pass --yes or set TALON_AUTO_INSTALL=yes." }
}
```

### Who decides the output

The design fixes the facts that a command decides. Most commands have no output example. These rules say who writes the output of such a command:

| # | Rule |
| --- | --- |
| OUT1 | The design fixes the exit codes, the `--json` envelope (J1 to J5), the facts that each command decides, and the design examples (`TESTING.md` TW16). It does not fix the exact human text of other output. |
| OUT2 | When the design gives no output for a command or a case, the slice proposes it: the human text (stdout and stderr) and the `data` fields (`TESTING.md` 7). The human accepts or changes the proposal at the test review. A missing output is not an open question (TW17), so the agent does not stop for it. A missing fact (what the command decides) is still a question. |
| OUT3 | The accepted `data` fields go in the catalog below, in the same commit as the slice. The L3 expected files (`TESTING.md` 3.1) fix the human text. The human text is not a contract: a program reads `--json`. |
| OUT4 | `data` holds each fact that the human text prints. A program never needs to parse human text. |
| OUT5 | J6 applies to each catalog row from the first Talon release (6.5). Before that release, a slice can change a row with no new `schema` number. `schema` is 1 at the first release. |

Output catalog. One row for each command, or each case with its own `data`. A slice adds or changes rows (OUT3).

| Command | `data` fields | Human text | Status |
| --- | --- | --- | --- |
| `install` with names (and `add`) | `snapshot`, `probes`, `downloads`, `added[]` (`alias`, `name`, `version`). The example above shortens the list. | Example in section 1 | Partial: the first slice of `add` completes it |
| `upgrade` | Not yet | Example in Resolution 10 | Partial |
| A resolve with no tuple (exit 10) | `error.details`: not yet | Example in Resolution 5 | Partial |

## 4. Prompts and non-interactive mode

Talon is in non-interactive mode when one of these is true. Otherwise it is in interactive mode.

| Source | Value that turns it on |
| --- | --- |
| `CI` | `true` or `1` (any case). GitHub Actions, GitLab CI and most other CI systems set it. |
| `DEBIAN_FRONTEND` | `noninteractive` |
| `NONINTERACTIVE` | `1` or `true` |
| Terminal | stdin or stderr is not a TTY |
| Flag | `--json` |

`TALON_INTERACTIVE` overrides the three variables above. `1` turns on interactive mode, also when `CI` is set. `0` turns on non-interactive mode. It does not override the terminal row or `--json`: with no TTY, or with `--json`, Talon never prompts (NR1).

Non-interactive mode changes one thing: a prompt does not show, and Talon uses a fixed answer instead. All other behavior is the same in both modes: what the command does, what it writes, its output and its exit codes. Color and progress output follow the TTY of stderr and `NO_COLOR`, not this mode.

Each prompt is one of two kinds:

| Kind | When it applies | Non-interactive answer |
| --- | --- | --- |
| Default | The default is safe with no person to read it: it confirms what the command names, or it declines extra work | The interactive default |
| Required | The prompt chooses something that the user did not name: a compiler, a move of a held variable, a file edit that the command does not name, or a build that was not checked online | None. Talon stops with exit code 13 (`consent`, section 3). The error names `--yes` and each flag that gives an answer. It writes nothing. |

So a non-interactive run does what an interactive run does when the user presses Enter at each "Default" prompt. It never takes an answer that the interactive default does not give.

When Talon answers a prompt without a prompt (non-interactive mode, `--yes` or an answer flag), it prints the answer to stderr, for example `kept 3 tools, removed 5 compilers (1.2 GB)`. The text is the same in both modes.

A picker (`tln update -i`) is not a prompt: it is the whole command. In non-interactive mode it stops with exit code 2 (`usage`).

`--yes` works the same in both modes:

| Prompt | `--yes` gives |
| --- | --- |
| Yes/no | Yes. For a prompt with the default No (NI3, NI4, NI9), this is not the answer of Enter. |
| Options | The default option (NI8 option 1, NI10 option 1) |

So `--yes` answers every prompt of the command at once. Each Required prompt also has its own answer flag, which answers only that prompt. A script should use these flags, not `--yes`. An answer flag has priority over `--yes`.

Each prompt in the design files has an id `NIn`. Search for the id to find the place. Each new prompt must get an id and a row in this table.

| Id | Command | Prompt | Interactive default | Kind | Non-interactive result | Answer flags | Where |
| --- | --- | --- | --- | --- | --- | --- | --- |
| NI1 | `install`, `add` | Rename a stale key in `talon.toml` | Yes | Required | Exit 13, writes nothing | `--rename-keys`, `--yes` | Design 4.3 |
| NI2 | `update -i` | Pick the packages to update | None | Picker | Exit 2 | Name the packages: `tln update X Y` | Resolution 9 |
| NI3 | `add`, `update`, `upgrade`, `install` | Move a held variable | No | Required | Exit 13, writes nothing | `--allow-moves`, `--yes` | Resolution 9 |
| NI4 | `add`, `update`, `upgrade`, `install`, `probe`, `verify` | Optional compiler downloads for probes | No | Default | No download. Uses installed compilers only. | `--probe-downloads`, `--yes` (inside the cap, DL6) | 6.2, DL4 |
| NI5 | `add`, `update`, `upgrade`, `install`, `remove`, `probe`, `verify`, the `roc` proxy | A required compiler download that the command does not name, also the baseline compiler (Resolution 4) | No (yes for the proxy, DL3) | Required | Exit 13 | `--yes`, `TALON_AUTO_INSTALL=yes` | 6.2, DL4 |
| NI6 | `roc install`, `roc use`, `roc default`, `roc update` | Download the compiler that the command names, and Zig for a source build | Yes | Default | Downloads | None needed | 6.2, 6.6 |
| NI7 | `cache clean` | Confirm the removal and its size | Yes | Default | Removes | `--dry-run` shows it first | 6.3 |
| NI8 | `tool install`, `x` | Select a compiler release: download the pin, try installed releases, or cancel | Download the pin | Required | Exit 13 | `--roc pinned`, `--roc installed`, `TALON_AUTO_INSTALL=yes` (option 1), `--yes` | 6.4 |
| NI9 | `tool install`, `x` | Use a cached build that was not checked online (B7) | No | Required | Exit 13 | `--allow-unchecked`, `--yes` | 6.4 |
| NI10 | `tool rm talon` | What to remove with Talon | Keep the tools, remove the rest | Default | Keeps the tools, removes the rest (RM3) | `--remove-tools`, `--keep-all`, `--dry-run` | 6.5 |
| NI11 | Removed in round 2. R2 prints a note and does not prompt, because `--yes` would change the result id. | | | | | | 6.6, R2 |
| NI12 | `upgrade` with the nightly free, `init` | Download the newest nightly | Yes | Default | Downloads | `--yes` | Resolution 10, UP6, section 5 |
| NI13 | `setup` | Replace a `roc` in the bin dir that Talon did not write | No | Default | Keeps the old `roc`. Does not install the launcher. | `--replace-roc`, `--yes` | 6.7, ST2 |
| NI14 | `setup` | Add the bin dir to `PATH` in the shell profile | Yes | Default | Adds the line | `--no-modify-path`, `--yes` | 6.7, ST4 |
| NI15 | `install.sh`, `install.ps1` | Confirm the install | Yes | Default | Installs | `--yes`, `-Yes`, `TALON_YES=1` | 6.5, IS4 |

Not prompts: an invalid alias, an ambiguous name, a short name in `tln x` or `tln tool install` with no local match, and a binary name clash stop the command in both modes with exit code 2 and name the flag to use (`--as`, a full name).

Rules for a new prompt:

| # | Rule |
| --- | --- |
| NR1 | A prompt writes to stderr and reads from stdin. It never prompts when stdin or stderr is not a TTY, even if no variable is set. Exception: on Windows, until basic-cli has the TTY test (Design 6.2, HF1), Talon cannot see the TTY state. It prompts, and the end of input gives the non-interactive answer. |
| NR2 | A prompt shows its default and what the default costs (size, count). |
| NR3 | A destructive prompt (removal, overwrite) is "Default" only if the command names what it removes. Otherwise it is "Required". NI10 counts as "Default": besides Talon, it removes only the compilers and Talon data, which nothing uses without Talon (RM3). |
| NR4 | Each picker has a command form that names the choice. |
| NR5 | A prompt must not change behavior outside its answer. A new mode-specific behavior is a design error. |
| NR6 | Each Required prompt has its own answer flag. `--yes` alone is not enough. |

## 5. `tln init`

| Item | Rule |
| --- | --- |
| Template | `app` (default) or `package`. An app uses the newest `roc-lang/basic-cli` release. `--platform <name>` selects another platform. |
| Nightly | Talon resolves the new header as `tln upgrade` does (Resolution 10). An app gets the newest platform release and the newest nightly that pass the ladder (Resolution 4) on the template. A package gets the newest nightly that passes `roc check`. |
| Downloads | The consent rules DL1 to DL6. The newest nightly is a download that the command names (prompt NI12). |
| Pin | The nightly goes in the `roc:` entry of the header. Talon writes no `.roc-version` (Resolution 13). |
| `talon.toml` | Not created (G2) |
| CI file | `.github/workflows/ci.yml` for GitHub Actions. It sets `TALON_AUTO_INSTALL=yes` (required downloads only, DL5), runs `tln install --frozen`, then `roc check` and `roc test`. `--ci none` writes no CI file. |
| Existing files | Talon never overwrites a file. If `main.roc` exists, it stops with exit code 2. |

## 6. Toolchain manager

How Talon selects the compiler for one run is in Resolution 13.

### 6.1 Directory layout

```text
$XDG_CACHE_HOME/roc/          (else ~/.cache/roc/)
  packages/<hash>/              roc      unpacked package (Talon may pre-fill it, 7.2)
  packages/<hash>.deps.json     roc      sidecar, rebuilt by roc if missing
  compat-<id>/                  roc      build cache per compiler build ($ROC_CACHE_DIR if set)
  nightly-<tag>/, debug-<sha>/  roc      build caches of older compilers (seen up to nightly 10-09)
  toolchains/<id>/roc           talon    installed compilers (<id>: nightly tag, release, git-<sha8>, link-<name>, copy-<name>)
  toolchains/<id>/.talon.json   talon    source URL, sha256 or commit, ref typed, compat id, install time. Written last (CC4).
  toolchains/<id>/.last-use     talon    the time of the last use (CC9)
  toolchains/<id>.lock          talon    install lock of <id> (7.4, CC3, CC4)
  toolchains/zig-<version>/     talon    Zig for source builds (6.6), with the lock zig-<version>.lock
  talon/index/                  talon    cached registry and GitHub index responses (ETag, 7.3)
  talon/compat.db               talon    probe results, first-seen compiler sha256 (CV6)
  talon/projects.json           talon    known projects, for GC (PD9 to PD13). Lock: projects.json.lock (CC6).
  talon/path-roc.json           talon    id of the roc on PATH, keyed by path, size and modification time (Resolution 13, rank 7)
  talon/tmp/<16hex>/            talon    temp copies of an app for probes (CC2)
  talon/gc.lock                 talon    lock of tln cache gc (CC10)
  talon/x/<build digest>/       talon    binary and manifest built by tln x (6.4, B1 to B8)
```

User settings and tools are not in the cache, so a cache cleanup cannot remove them:

```text
$XDG_CONFIG_HOME/talon/config.toml   (else ~/.config/talon/)        user settings, see below
$XDG_DATA_HOME/talon/bin/            (else ~/.local/share/talon/)   tool binaries (6.4, T3)
$XDG_DATA_HOME/talon/tools.json                                     tool manifests (6.4, T4)
```

`config.toml` and `tools.json` also have a lock file next to them: `config.toml.lock`, `tools.json.lock` (CC6).

```toml
# config.toml
default-roc = "nightly-2026-10-09-258ab27"   # tln roc default writes it. A full id only (section 2).
registry = "direct"                          # or a URL (section 1, registry precedence)
nightly = true                               # the nightly switch (Resolution 1, NS1). talon.toml has priority.
min-release-age = "2d"                       # the default (Resolution 2, C7). talon.toml [resolution] has priority.
gc-age = "30d"                               # the default GC age (6.3)

[probe]                                      # same keys as [resolution] probe in talon.toml
slots = 12
max-toolchains = 10
```

A value in a project `talon.toml` has priority over `config.toml`. A flag or an environment variable has priority over both.

The paths above are for Linux and macOS. On Windows:

| Item | Linux, macOS | Windows |
| --- | --- | --- |
| Cache root (packages, build caches, `toolchains/`, `talon/`) | `$XDG_CACHE_HOME/roc`, else `~/.cache/roc` | `%LOCALAPPDATA%\roc`, as roc (`roc:src/compile/compile_build.zig:1602-1608`). roc reads `XDG_CACHE_HOME` first on Windows too, and so does Talon. |
| Config | `$XDG_CONFIG_HOME/talon`, else `~/.config/talon` | `%APPDATA%\talon` |
| Data (tool binaries, `tools.json`) | `$XDG_DATA_HOME/talon`, else `~/.local/share/talon` | `%LOCALAPPDATA%\talon` |
| Bin dir (6.7, ST1) | `~/.local/bin` | `%USERPROFILE%\.local\bin`, as uv |
| `PATH` (6.7, ST4) | One line in the shell profile | The user `Path` value of the environment |

### 6.2 The `roc` proxy

| Item | Behavior |
| --- | --- |
| Install | `tln setup` puts the `roc` launcher in the bin dir: a hard link or a copy of `tln`. `tln` runs in proxy mode when its program name is `roc` (6.7, ST7, ST8). |
| Dispatch | Talon selects the compiler (Resolution 13), writes its `.last-use` (CC9), and runs it in place of itself (Design 6.2, HF6: `execve` on Unix, a child with inherited stdio on Windows and until the upstream PR). The exit code passes through (E1). Cost target: under 5 ms. |
| Missing compiler | Follows `TALON_AUTO_INSTALL` and the consent rules DL1 to DL5 (see "Download consent" below). Default `ask`. Modeled on Go `GOTOOLCHAIN`. There is no `--no-auto-install` flag: `roc` flags go to the compiler. Use `TALON_AUTO_INSTALL=no`. |
| Patches | Adds `--replace-dep` for each `[patch]` entry. A stale patch (Resolution 7, PA6) stops the proxy before the compiler runs, with exit code 14. |
| Cache paths | Sets `XDG_CACHE_HOME` and `ROC_CACHE_DIR` to canonical absolute paths. With `..` in `XDG_CACHE_HOME`, `roc check` prints "No errors found" for any app (Q15). Probes use the same rule. |
| Opt out | `TALON_PROXY=0` runs the selected compiler with no extra work. |

Compiler sources: release assets of `roc-lang/nightlies`. Archives are `.tar.gz` (Linux, macOS) and `.zip` (Windows), about 70 MB each.

| # | Rule |
| --- | --- |
| CV1 | With a registry, Talon lists the compiler releases with `GET /v1/toolchains` (Registry 4). With `direct`, it lists the releases of `roc-lang/nightlies` with the list call of DI2 (7.3). A release is a nightly when its tag has the form `nightly-YYYY-MM-DD-<sha7>`. DI3 applies: Talon skips a draft and a prerelease. |
| CV2 | The asset for a host is `roc_nightly-<target>-YYYY-MM-DD-<sha7>.tar.gz`, or `.zip` for Windows, with `<target>` from the table below. Other assets are not compilers, for example `roc_nightly-source-*` and `*.wasm.zst`. A nightly with no asset for the host is not a candidate on that host. A source build (6.6) is the other way to get it. |
| CV3 | The sha256 of the asset comes from one source. With `direct`: the `digest` field (`sha256:<hex>`) of the asset in the answer of CV1. GitHub computes it at upload (Design Q20). With a registry: the sha256 of `GET /v1/toolchains`. The registry copies it from the same `digest` the first time it sees the nightly, and never changes it. So a later swap of the asset on GitHub gives a mismatch for registry users. |
| CV4 | Talon computes the sha256 of the download before it extracts it. A mismatch, or an asset with no sha256, stops the install with exit code 16 (`integrity`). Talon deletes the download. There is no override. |
| CV5 | `.talon.json` (6.1) records the sha256 and its source: `github-digest` or `registry`. |
| CV6 | Trust on first use. The first time Talon sees a sha256 for a compiler asset (tag and target), from either source in CV3, it records it in `talon/compat.db`. That file stays after `tln cache clean --all` and `tln roc rm` (6.3), and the index cache does not. When a later list gives another sha256 for the same tag and target, Talon stops with exit code 16. The error names the tag, both values and their sources. There is no override: that tag is not a candidate on this machine, and the user selects another compiler. An installed compiler with that tag stays in use, because its bytes match the first value. |

Asset targets, as in the nightly `nightly-2026-10-14-38a3029`:

| Host | `<target>` | Archive |
| --- | --- | --- |
| Linux x86_64 | `linux_x86_64` | `.tar.gz` |
| Linux arm64 | `linux_arm64` | `.tar.gz` |
| macOS arm64 | `macos_apple_silicon` | `.tar.gz` |
| macOS x86_64 | `macos_x86_64` | `.tar.gz` |
| Windows x86_64 | `windows_x86_64` | `.zip` |

Windows arm64 has no asset in these nightlies (CV2).

#### Download consent

One rule set covers each command that downloads a compiler or Zig: `add`, `update`, `upgrade`, `install`, `probe`, `roc install`, `roc update`, `tool install`, `x`, the `roc` proxy, and the Zig install of 6.6. Other sections refer to these rules and do not repeat them.

| # | Rule |
| --- | --- |
| DL1 | Talon asks once for each command, not once for each download. The prompt shows how many downloads can happen and their total size. A download that is not in the prompt does not start. |
| DL2 | A required download is one without which the command cannot finish. Examples: the `roc:` pin that the proxy must run, the compiler of `tool install`, Zig for a source build, the compiler of the baseline check when it is not installed (Resolution 4, "Baseline check"). An optional download only widens a probe search (Resolution 4, P5). |
| DL3 | In interactive mode (section 4), Talon prompts. Default answer: yes for a command that names the download (`roc install`, `roc use`, `roc default`, `roc update`, `tool install`, `x`, the Zig of `roc install`, the newest nightly of `upgrade` and `init`). Yes for the `roc` proxy, because it cannot run without the compiler. No for all other commands. Prompts NI4 to NI6 and NI12 (section 4). |
| DL4 | In non-interactive mode (section 4), Talon never prompts. A download that a `tln roc` command names (`roc install`, `roc use`, `roc default`, `roc update`, and the Zig that the build needs) starts: the command is the consent (NI6). The newest nightly of `tln upgrade` and `tln init` also starts (NI12). Any other required download fails with exit code 13 and an error that names `--yes` and `TALON_AUTO_INSTALL=yes` (NI5). An optional download does not start. Talon prints `skipped N compiler downloads (<size>), pass --probe-downloads` and uses the installed compilers only (NI4). |
| DL5 | `--yes` (global, section 1) accepts every prompt of the command, downloads included. `TALON_AUTO_INSTALL=yes` accepts only required compiler and Zig downloads (NI5, and option 1 of NI8), in the proxy and in every other command. It answers no other prompt: not optional probe downloads (NI4), not a key rename (NI1), not a move (NI3), not a build that was not checked online (NI9). `TALON_AUTO_INSTALL=no` refuses each required download with no prompt, with exit code 13, in both modes. |
| DL6 | Consent never goes past the cap `probe.max-toolchains` (Resolution 4, P5) for optional downloads. With `probe.max-toolchains = 0`, Talon does not offer an optional download, and prompt NI4 does not show. |

The proxy runs inside build scripts, and `roc` flags go to the compiler. So the proxy has no Talon flag. `TALON_AUTO_INSTALL` sets its behavior:

| Value | Missing compiler, interactive | Missing compiler, non-interactive (section 4) |
| --- | --- | --- |
| `ask` (default) | Prompt NI5 (DL3), then install and run | Error that names `TALON_AUTO_INSTALL=yes` and `tln roc install <id>`. Exit code 13 before the compiler runs. |
| `yes` | Install and run, no prompt. For CI. | Same |
| `no` | Error, no prompt | Same |

### 6.3 Garbage collection

| Item | roc today | `tln cache gc` |
| --- | --- | --- |
| Files inside build caches | Expires after 30 days, in the background | Leaves to roc |
| `nightly-<tag>/`, `debug-<sha>/` dirs | Never removed | Removes a dir when no file in it changed in the GC age. Compilers from 2026-10-05 do not write them. (3.1 GB here.) |
| `compat-<id>/` dirs | Never removed | Removes the dir of each compiler that GC or `tln roc rm` removes. Removes another dir only when no file in it changed in the GC age. So the dir of a compiler that Talon did not install (the `roc` on `PATH`, Resolution 13 rank 7) stays while that compiler is in use. |
| `packages/<hash>/` | Never removed | Removes it if no known project used it in the GC age |
| Toolchains | n/a | Keeps the default, and the toolchains that a known project pins and used in the GC age. Never removes a toolchain that an install holds or that a run used in the last day (CC10). |
| Temps and `.trash` dirs that a crash left (CC2) | n/a | Removes them when they are older than 1 day |
| `talon/x/<build digest>/` (binaries of `tln x`, 6.4) | n/a | Removes an entry that no `tln x` run used in the GC age |

The GC age is `gc-age` in `config.toml` (6.1). The default is `30d`, the same as the expiry of roc build-cache files (Design 2.2). Last uses are the times that Talon records (PD9, CC9, X2), compared with the clock of Talon (`TALON_NOW`, section 1). The age of a file in a build-cache dir is its modification time, compared with the real clock.

The compat id is a build-time hash that `roc` does not print. Talon learns it at install: it runs one `roc check` on an empty file and records which `compat-<id>/` dir the run touched. Upstream request: print the id in `roc version --verbose`.

`tln cache gc --dry-run` prints what it would free. GC can run while builds and other `tln` commands run: the rules are in 7.4 (CC10).

`tln cache clean` removes cache content on request, with no age rule. `gc` keeps what a known project uses. `clean` does not.

| Command | Removes | Keeps |
| --- | --- | --- |
| `tln cache clean` | `talon/index/` and `talon/x/` | Everything else |
| `tln cache clean --all` | The above, and `packages/`, `compat-<id>/`, `nightly-<tag>/`, `debug-<sha>/` | Toolchains, tools, `talon/compat.db`, `talon/projects.json` |

`tln cache clean` never removes a toolchain or a tool: use `tln roc rm` (6.6) or `tln tool rm` (6.4). It shows the size to free and asks for confirmation (prompt NI7, section 4, default yes). In non-interactive mode it removes with no prompt: the command names what it removes, and Talon can fetch all of it again. `--dry-run` prints what it would remove and removes nothing.

### 6.4 Global tools

`tln tool install owner/app` builds a Roc app from source and puts the binary on `PATH`, as `cargo install --locked` and `uv tool install` do.

`npm i -g` has a known problem: a global script runs with the `node` that is on `PATH` now, and that can be a different version from the one used at install. A Roc tool does not have this problem, because the nightly is used only at build time:

| | `npm i -g` | `tln tool install` |
| --- | --- | --- |
| What is installed | Scripts | A native binary with the platform host linked in |
| Toolchain needed at run time | Yes, the shared `node` | No |
| Two tools that need different versions | They share one `node` | Each binary is self-contained |

Install flow:

```text
tln tool install owner/app
  |
  v
resolve the release online (yank and advisory check)
  |
  v
a build of this app is already on this machine (B1, B2)? --yes--> take it over (B4), done
  |
  no
  v
fetch the release, read the app header (hashes + roc: pin)
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

| Case | Behavior |
| --- | --- |
| The pinned release is installed | Build with it. No prompt. |
| An installed release has a recorded pass for this closure (Resolution 3) | Build with it. Print `built with nightly-2026-10-12-2664a27 (pin: nightly-2026-10-09-258ab27)`. No prompt. |
| Other releases are installed, with no evidence | Prompt NI8 (section 4) with options 1, 2 and 3 |
| No release is installed | Prompt NI8 (section 4) with options 1 and 3 |
| Non-interactive mode (section 4) | No prompt (DL4). `--roc pinned` selects option 1, `--roc installed` selects option 2, and `--yes` or `TALON_AUTO_INSTALL=yes` selects option 1 (the default). With none of them, Talon stops with exit code 13 and an error that names these flags. |

The prompt:

```text
owner/app 1.4.0 was tested with compiler release nightly-2026-10-09-258ab27. It is not installed.

  1) Download nightly-2026-10-09-258ab27 (70 MB, 228 MB unpacked)    [default]
  2) Try the 4 installed compiler releases
  3) Cancel
```

The prompt shows only what the user needs to decide: why it asks, the cost of the download, and how many releases option 2 tries. The download is the default because the user runs the binary, and the author tested only the output of the pinned release.

Option 2, inside Talon:

| Step | Behavior |
| --- | --- |
| Order | Releases in the same epoch as the pin first (Resolution 4, EP4: no result changed inside an epoch), then newer before older |
| Each release | `roc check` on the app, with `probe.timeout`. On a fail, go to the next release. |
| First pass | `roc build` with that release. On a fail, go to the next release. |
| All fail | Show the prompt again with options 1 and 3, and a list of each release with the first error line |
| Record | Each pass and fail goes in `compat.db`. The next install of this closure finds the evidence and shows no prompt. |

| # | Rule | Reason |
| --- | --- | --- |
| T1 | Build from the app header as it is (hashes and `roc:` pin). Do not resolve again. `--resolve` allows a new resolution. | The header is the lock (G1). A new resolution can select packages that the author did not test. |
| T2 | Only an app whose platform makes a native executable can be installed. | A `package` has no entry point. A wasm platform, such as `cloudflare-workers`, makes no CLI. |
| T3 | Binaries go in `$XDG_DATA_HOME/talon/bin/` (else `~/.local/share/talon/bin/`), not in the cache. The bin dir `~/.local/bin/` gets a hard link or a copy of each (ST7, ST9). The final step of an install (move the binary, the bin dir entry, `tools.json`) runs under the lock of `tools.json` (CC6). | The cache has a 30-day expiry and GC (6.3). A cleanup must not delete a tool. |
| T4 | `$XDG_DATA_HOME/talon/tools.json` records, for each tool: source, build id (hashes, nightly, target), binary sha256, run-time libraries (T8), install time. The sha256 identifies the installed file only. Talon does not compare it with the sha256 of another build. | `tln tool ls`, `update` and `rebuild` read it. A build of the same build id can give other bytes: a build on a warm cache differs from a build on an empty cache (Q18). |
| T5 | A tool does not keep its nightly. GC (6.3) can remove the nightly after the build. | The binary does not need it. A rebuild installs it again. |
| T6 | A download follows the consent rules DL1 to DL6 (6.2). `--roc pinned` also counts as consent for the pinned download. An installed release is used without a prompt only when evidence supports it. | No surprise download of 228 MB, and no silent build with a release that nobody tested. |
| T7 | `tln tool rebuild` builds again from the manifest, with the same build id. | Repair after an OS upgrade breaks a dynamic link (T8). |
| T8 | Talon builds a tool with no `--target`. roc then uses the musl target of the platform, else its glibc target. For a glibc build, `tools.json` records the libraries in the ELF `NEEDED` list, and `tln tool ls` shows them. | A musl build is static and has no run-time dependency. A glibc build needs system libraries: roc-ray needs `libX11.so.6` (Q16). |

Prebuilt binaries: a release can attach a binary for each target, as `cargo-binstall` expects. Then an install needs no compiler release, and the source build is the fallback. P1 builds this path for Talon itself (6.5). In P2 the registry lists prebuilt binaries for other tools too.

Tools from a git ref (section 2):

| Command | Effect |
| --- | --- |
| `tln tool install --git owner/app@main` | Get the commit as a source archive (6.6, R3, R7), read `main.roc`, then build as above. `--path apps/cli` selects an app in a subdirectory. `tools.json` records the commit and the ref that the user typed. |
| `tln tool update app` | Installed from a branch: build the new head. From a commit: no change, and Talon prints `pinned to commit dd03c09e`. From a release: the newest release, as `tln tool install app@latest` (B2). |
| `tln tool update` with no name | Updates each tool with the rule of its source (row above). One prompt covers the downloads of all tools (DL1). |
| `tln tool install foo` when foo is installed | With no selector, or with a selector that the installed version satisfies (B1, B2): no build. Talon prints `foo 1.2.0 is installed`. Else it builds and replaces the tool. |
| `tln tool install owner/app` | One install for each name. It replaces a git install of the same tool. |
| Binary name clash | When a second tool has the same binary name, the install stops. `--as <name>` sets another name. |

Project dependencies from git are out of scope. A header holds only hash URLs (H3), so use `[patch]` (Resolution 7) or a path entry.

#### Run once: `tln x`

`tln x owner/app [-- args]` builds a Roc app and runs it once. It is the same build as `tln tool install`, with a different place for the binary.

| # | Rule | Reason |
| --- | --- | --- |
| X1 | Compiler choice, T1 (no new resolution, `--resolve` allows it), T6 and the DL1 to DL6 consent rules are the same as for `tln tool install`. The compiler release selection table and the prompt above apply. `--roc pinned`, `--roc installed` and `--yes` work the same. | One build path. One set of consent rules. |
| X2 | Talon keeps the built binary and its manifest in `talon/x/<build digest>/` (6.1). The digest is a hash of the build id. A later run reuses an installed tool or this cache entry, with the rules of "Build reuse" below. | A repeat run is fast, as with `bunx`. |
| X3 | Talon puts nothing on `PATH`, writes nothing in the bin dir (T3) and writes nothing in `tools.json` (T4). A run of an installed tool uses the tool binary in place, with no copy (B5). | `x` leaves no install behind. |
| X4 | `tln x` runs the output. Probes do not (P1). Talon prints the platform URL and hash before the build. It does not ask again before the run: the user named the app. The app runs in place of `tln` (Design 6.2, HF6), so the exit code of `tln x` is the exit code of the app (E1). | The run is the purpose of the command. |
| X5 | `tln cache gc` and `tln cache clean` (6.3) can remove the binary. The next run builds it again. | The cache is not a store (T3). |

#### Build reuse between `tln x` and `tln tool install`

A build of an app is expensive: a `roc build --opt`, and maybe a compiler download. So Talon reuses a build that is already on this machine. Each binary has one owner at a time: the `x` cache or the tool list. Talon moves a binary between them. It never keeps two copies.

Each `tln x` cache entry has a manifest, with the same fields as a `tools.json` entry (T4): full name, source kind (release, or the commit and ref of a git build), version, build id, binary sha256, last run.

Talon finds a reusable build by its manifest, not by its build id. A build matches a request when all of these are equal:

| Field | Must be equal | Reason |
| --- | --- | --- |
| Full name (host and owner/repo, Design 4.1) | Yes | `alice/foo` and `bob/foo` are different programs with the same binary name |
| Source kind | Yes | A git build from `tln x --git owner/app@main` does not satisfy a release request, and the reverse |
| Target | Yes | The binary must run on this machine |
| Version | Only if the selector asks for it (B2) | The user did not ask for a new build when a newer version exists |
| Nightly | No | `tools.json` records the real build id, so `tln tool rebuild` (T7) builds the same thing again |

| # | Rule | Reason |
| --- | --- | --- |
| B1 | With no selector, any matching build is used. When there are more than one, the newest version wins. An installed tool wins over an `x` cache entry of the same version. | No rebuild only because a newer version was released |
| B2 | With a selector, a matching build is used only if its version satisfies the selector. `@latest`: the version is the newest release. `@1.3.0`: the version is 1.3.0. A range or series (`@1`, `@^1.2`): the version is the newest release in that range. | The user asked for a version, so an older build is not enough |
| B3 | Online, Talon always resolves the request first. It checks that the version of the matching build is not yanked and has no advisory. If it is, Talon does not use the build and builds the newest release that is not yanked. There is no override. With no yank or advisory data (`direct`, or a registry before P3), Talon checks only that the release is still a candidate (DI3) and prints the note of C6. When the matching build is older than the newest release, Talon prints `installed cached 1.2.0 (1.4.0 is available: tln tool install foo@latest)`. | Reuse skips the build, not the safety checks (C6, `tln audit`) |
| B4 | `tln tool install` takes over a matching `x` cache entry. It moves the binary to the bin dir (T3), checks the sha256, writes the `tools.json` entry from the manifest, makes the bin dir entry (ST7), and removes the cache entry. If a `rename` is not possible (another filesystem, or a running `.exe` on Windows), it copies, checks the sha256, then deletes the cache entry. | One owner, no second copy. The tool now has the lifetime of a tool, not of a cache entry. |
| B5 | `tln x` with a matching installed tool runs the tool binary in place. It writes no cache entry. | No copy, no build |
| B6 | `tln tool rm` deletes the binary. Nothing goes back to the `x` cache. | The user asked for it to go |
| B7 | With no network, or with `--offline`, Talon cannot resolve the request or check yanks. A matching `x` cache entry is then offered in a prompt: `foo 1.2.0 is in the cache. It was not checked online for yanks and advisories. Install it? [y/N]` (prompt NI9, section 4). In non-interactive mode, Talon stops with exit code 13 (`consent`, section 3). `--allow-unchecked` or `--yes` accepts. With no matching build, the command fails with exit code 15 (`network`). | A build that nobody checked online needs a choice from the user |
| B8 | With no network, `tln x` runs a matching installed tool with a note and no prompt. A matching `x` cache entry needs the B7 prompt. | The user installed the tool on purpose. A cache entry is only a leftover. |

Lifecycle of one binary:

```text
tln x foo ───────────── build ──▶ x cache entry (manifest + binary)
                                     │
tln tool install foo ── B1/B2 match ─┴─▶ move to bin dir, write tools.json (B4)
                        no match ──────▶ normal build. The old cache entry waits for GC.

tln x foo ───────────── installed tool matches ──▶ run it in place (B5)
tln tool rm foo ─────── binary deleted, nothing goes back to the cache (B6)
offline install ─────── match? prompt, "not checked online" (B7). Non-interactive: exit 13.
```

### 6.5 Talon as a tool

Talon manages itself as one more entry in `tools.json`. Only a few rules are different, because a broken `tln` cannot repair itself, and it also breaks the `roc` proxy (6.2).

```text
first install:  curl -fsSL <releases>/latest/download/install.sh | sh             (Linux, macOS)
                irm <releases>/latest/download/install.ps1 | iex                    (Windows)
                  -> download the prebuilt tln for this target, verify it
                  -> put it in the bin dir (T3)
                  -> run tln setup: it writes the tools.json entry of tln (source: install script)
later:          tln tool update talon
repair:         curl -fsSL <releases>/latest/download/install.sh | sh -s -- --version 0.3.1
                & ([scriptblock]::Create((irm <releases>/latest/download/install.ps1))) -Version 0.3.1
```

`<releases>` is `https://github.com/<owner>/talon/releases`. The scripts are in `install/` (Design 6.3), and `install/test.sh` tests them against a fake release. Their structure follows the rocup installers (Design 3).

| # | Rule | Reason |
| --- | --- | --- |
| S1 | `install.sh` downloads a prebuilt binary from the GitHub Release assets of Talon. It checks the sha256 from the release, and the attestation when there is one (Design 8). | `install.sh` cannot build from source: that needs a compiler release (228 MB) before the user has `tln`. |
| S2 | `tln tool update talon` uses the prebuilt binary. `--from-source` builds it as in 6.4. | Same reason as S1, and a download is faster |
| S3 | An update writes the new binary to a temp file, sets it executable (Design 6.2, HF2), runs `tln --version` on it, then does a `rename` over the old one. On Windows, it renames the running `.exe` first (ST10). Then it makes the bin dir entries `tln` and `roc` again (ST9). | A binary that does not start never replaces the working one. A running `.exe` cannot be overwritten. |
| S4 | No rollback command, and no copy of the old binary. The repair path is `install.sh --version <v>`. | A broken binary cannot run a rollback command. `install.sh` does not need a working `tln`. |
| S5 | `tln tool rm talon` asks what to remove (prompt NI10, section 4), then removes it. See "Remove Talon" below. | One namespace for all tools. Removing Talon also removes the proxy, so the user must confirm. |

The install scripts follow these rules:

| # | Rule |
| --- | --- |
| IS1 | Two scripts: `install.sh` for Linux and macOS (POSIX `sh`: tested with dash, bash and busybox), and `install.ps1` for Windows (PowerShell 5.1 and later). Each Talon release has both as assets, so `latest/download/install.sh` is the script of the newest release. |
| IS2 | A release has one binary for each Roc target: `tln-x64musl`, `tln-arm64musl`, `tln-x64mac`, `tln-arm64mac`, `tln-x64win.exe`, and `sha256sums.txt`. These are the targets of basic-cli (Design 6.2, HF10). The Linux binaries are static musl, so one binary works on each distribution (Design Q16). On macOS, a shell under Rosetta gets the arm64 binary. basic-cli has no `arm64win` target, so on Windows on ARM64, `install.ps1` installs `tln-x64win.exe`. Windows 11 on ARM64 runs it by emulation, and Talon then selects `windows_x86_64` compilers (CV2), which also run by emulation. Other systems stop with an error that lists the targets. |
| IS3 | The script checks the sha256 from `sha256sums.txt` (exit code 16), and the attestation when `gh` is installed and logged in (S1). It uses `latest/download/` URLs, so it needs no GitHub API call and no token. |
| IS4 | The script asks `Proceed? [Y/n]` (prompt NI15, kind Default). It uses the non-interactive rules of section 4, with one difference: with `curl \| sh`, stdin is the script, so `install.sh` reads the answer from `/dev/tty`. In non-interactive mode, the install goes on with no prompt, because the command names it. `--yes` (`-Yes`, or `TALON_YES=1` for `irm \| iex`) skips the prompt. |
| IS5 | The download goes to a temp file in the bin dir. The script runs `--version` on it, then renames it over the old binary (S3). On Windows it first renames the old `tln.exe` to `tln.<16hex>.del` (ST10). A failed check keeps the old binary and leaves no temp file. |
| IS6 | Then the script runs `tln setup`, with `--yes` and `--no-modify-path` when the user gave them. `tln setup` writes the `talon` entry of `tools.json` when it is missing, then applies ST1 to ST6. With a terminal, `install.sh` connects `/dev/tty` to `tln setup`, so its prompts (NI13, NI14) work under `curl \| sh`. |
| IS7 | Exit codes as in section 3: 2 for a bad argument, 15 for a download error, 16 for a checksum or attestation error, 1 for the rest. `install.ps1` under `irm \| iex` runs in the shell of the user, so it throws an error and does not exit: an exit would close that shell. |
| IS8 | There is no uninstall script. `tln tool rm talon` removes Talon (S5). If `tln` does not start, `install.sh --version <v>` repairs it first (S4). |

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

| Group | Paths (6.1, 6.4) | Option 1 (default) | Option 2 (`--remove-tools`) | Option 3 (`--keep-all`) |
| --- | --- | --- | --- | --- |
| Talon | The `tln` binary, the `roc` launcher, the `talon` entry of `tools.json` | Removed | Removed | Removed |
| Tools | Each other tool binary, its link in `~/.local/bin/`, `tools.json`, the `PATH` line of `tln setup` (6.7, ST4) | Kept | Removed | Kept |
| Compilers | `toolchains/<id>/`, `toolchains/zig-<version>/`, and the `compat-<id>/` dir of each removed compiler | Removed | Removed | Kept |
| Talon data | `talon/` in the cache (index, `x`, `compat.db`, `projects.json`), and `config.toml` (6.1) | Removed | Removed | Kept |

| # | Rule |
| --- | --- |
| RM1 | Talon never removes what roc owns and uses without Talon: `packages/`, and the build caches of compilers that Talon did not install. `tln cache clean --all` before the removal removes them (6.3). |
| RM2 | `tln roc link` entries (`link-<name>`) are links. Talon removes the link and never the target. |
| RM3 | The default (option 1) keeps the tools, because they still run without Talon. It removes the compilers and the Talon data, because nothing uses them without Talon. In non-interactive mode (section 4), Talon uses option 1 with no prompt. `--remove-tools` and `--keep-all` select options 2 and 3 in both modes. `--yes` selects option 1. |
| RM4 | `--dry-run` prints the table above with sizes and removes nothing. |
| RM5 | Talon removes its own binary last, and the bin dir entries `tln` and `roc` with it. On Windows, it renames each running `.exe` (ST10). No later `tln` start deletes them, so Talon starts a detached `cmd.exe /d /c` that waits until Talon ends, then deletes them. If that fails, the renamed files stay. A later install of Talon deletes them (ST10). |
| RM6 | The `roc` launcher always goes with Talon. Talon prints the path of each compiler that stays (option 3), so the user can put one on `PATH`. If `tln setup` moved an old `roc` to `roc.old` (6.7, ST2), Talon moves it back. |

### 6.6 Compilers from source

| Command | Result id |
| --- | --- |
| `tln roc install nightly-2026-10-09-258ab27` | `nightly-2026-10-09-258ab27` |
| `tln roc install --git @main` (short for `roc-lang/roc@main`, see section 2) | `git-<sha8>` |
| `tln roc install --git Karakatiza666/roc@my-branch` | `git-<sha8>`. A fork works the same way. |
| `tln roc install @dd03c09e` | `git-dd03c09e`. A sha needs no `--git`. |
| `tln roc link dev ../roc/zig-out/bin/roc` | `link-dev`. No build, no copy, as `rustup toolchain link`. |
| `tln roc link --copy fix-1 ../roc/zig-out/bin/roc` | `copy-fix-1`. A copy of the binary, as `rocup freeze`. |

| # | Rule | Reason |
| --- | --- | --- |
| R1 | The id is `git-<sha8>`. `.talon.json` records the repo URL, the full sha and the ref that the user typed. | A commit sha is unique across forks. 8 characters match the local form `debug-c6dfe61b` of roc (`roc:src/base/roc_version.zig:21-22`). |
| R2 | If the commit is the commit of a nightly, Talon builds the ref that the user typed and prints a note, for example `dd03c09e is nightly-2026-10-09-258ab27. tln roc install nightly-2026-10-09-258ab27 downloads it.` It does not prompt (NI11 is removed). | Same code, and a download is much faster than a build. A script that typed a git ref can expect the id `git-<sha8>`. |
| R3 | Talon gets the source as a GitHub archive (`/archive/<sha>.tar.gz`), not with git. It builds with `zig build roc -Doptimize=ReleaseFast -Dcompiler-version=git-<sha8>`, as roc CI does (`roc:.github/workflows/ci_zig.yml:268`). | With no `.git`, roc reports the version `no-git` (`roc:build.zig`, `getCompilerVersionGit`). The flag gives the id instead (Q17). |
| R4 | Talon never writes `git-*` or `link-*` into a `roc:` pin. H6 keeps the old pin. Probe results for these ids stay local. | roc does not accept a local build as a pin, by design (`roc_version.zig:21-23`). Other users cannot reproduce such a result. |
| R5 | Selection uses the same rules as a nightly (Resolution 13): `roc +git-dd03c09e check`, `ROC_TOOLCHAIN=git-dd03c09e`, or `tln roc default --git Karakatiza666/roc@my-branch`. The last command picks the newest installed build of that branch, and stores its full id. Prefixes follow the rules in section 2. | A stored value must not change meaning after a later install |
| R6 | When the user installs a branch again, Talon builds the new head as a new id. The old id stays until GC. | An id never changes meaning |
| R7 | GitHub publishes no hash for a source archive. Talon downloads it over `https://` only (7.5), computes its sha256, and records it in `.talon.json` (R1), or for a tool in `tools.json` (T4). `tar` extracts it into a temp dir (Design 6.2, HF5). | The commit sha in the URL names the source. GitHub makes the archive again on request, so its bytes are not fixed, and Talon does not compare the sha256 with an earlier one. The trust is TLS to `github.com`, the same as a `git clone` (Design 8). |

Links and copies of a local build:

| # | Rule | Reason |
| --- | --- | --- |
| LK1 | A `link-<name>` follows its target, so a rebuild changes the compiler under the same id. Talon keys the local probe results of a link by the sha256 of the binary, not by the id. | Old evidence must not apply to a new build |
| LK2 | `tln roc link --copy <name> <path>` copies the binary (it follows symlinks) into `toolchains/copy-<name>/`. A later rebuild of the source tree does not change it. A name that exists is an error. `--force` replaces it. | A fixed local build to compare against, or to keep while the tree changes |
| LK3 | `copy-*` follows R4 and R5, as `git-*` does: it is never a `roc:` pin, and its probe results stay local | roc does not accept a local build as a pin |
| LK4 | A `link-<name>` is not a file system link. `toolchains/link-<name>/.talon.json` records the absolute path of the target, and Talon runs that path. | Same on all systems. A symlink on Windows needs developer mode or admin rights, and a hard link does not follow a rebuild (Design 6.2, HF7). |

The commands that select a compiler differ in where they store the choice:

| Command | Writes | Scope |
| --- | --- | --- |
| `tln roc use <ref>` | The `roc:` entry of the app header in the current project (selection priority 3, Resolution 13). In a workspace, each member (Design 4.4). | This project |
| `tln roc default <ref>` | The global default (priority 6) | This user |
| `tln roc update` | Installs the newest nightly. Moves the global default to it (RU2). | This user |

`tln roc use` follows these rules. It keeps the header as the lock (G1), so it writes no `talon.toml` key and no `.roc-version`:

| # | Rule |
| --- | --- |
| U1 | The ref must be a nightly or a release. `git-*`, `link-*` and `copy-*` ids are an error (R4, LK3). Talon says to use `tln roc default` or `ROC_TOOLCHAIN`. |
| U2 | A missing nightly follows the consent rules DL1 to DL6 (6.2). It is a required download (DL2). |
| U3 | Talon runs the baseline check and the final ladder (Resolution 4) on the current header with that nightly. It writes `roc:` only if there are no new errors (H6). It uses a span-based edit (H1). |
| U4 | `--no-check` is an error for this command: H6 allows no pin move without the check. |
| U5 | If `talon.toml` has `[toolchain] roc` and the nightly is out of range, or the `nightly` switch is off and the ref is a nightly (Resolution 1, NS5), Talon stops and names the range or the switch. It does not edit `talon.toml`. |
| U6 | A command argument or `ROC_TOOLCHAIN` still has higher priority than the new pin (Resolution 13). Talon prints a note when one of them is set. |

`tln roc update` (alias `tln roc up`) gets the newest compiler release, also when a project does not work with it yet:

| # | Rule |
| --- | --- |
| RU1 | Talon finds the newest compiler release online that the `nightly` switch (Resolution 1, NS3) and `min-release-age` (C7) allow, and installs it. With the defaults, that is the newest nightly that is at least 2 days old. The command names the download (NI6). If the newest nightly is already installed, Talon prints `nightly-2026-10-13-91fa0c2 is the newest` and does nothing. |
| RU2 | Talon moves the global default (Resolution 13, priority 6) to the new release when the default is a nightly, a release, or is not set. A `git-*`, `link-*` or `copy-*` default does not change. Talon prints a note. |
| RU3 | Talon runs no check and writes no project file. A project with a `roc:` pin keeps it. A project with no pin selects with priority 4 to 6 (Resolution 13), so it uses the new nightly at once. That can break it. To move a project pin with a check, use `tln upgrade roc` or `tln roc use` (RP1). |
| RU4 | Older nightlies stay until GC (6.3). |

`tln roc remove <id>` (alias `tln roc rm`) removes one compiler:

| # | Rule |
| --- | --- |
| RR1 | If the compiler is the global default, Talon moves the default to the newest installed nightly or release that the `nightly` switch allows, and prints a note. With none, the default is not set (Resolution 13). |
| RR2 | If a known project (`talon/projects.json`) pins the compiler, Talon prints the projects and removes it. The command names the removal, so there is no prompt. The proxy downloads it again when a project needs it (DL1 to DL6). |
| RR3 | For `link-*`, Talon removes the link and never the target (RM2). |

Build dependencies. The commit names its Zig version: `minimum_zig_version` in `build.zig.zon` (`roc:build.zig.zon:4`). Zig changes its API between minor versions, so Talon needs the same `major.minor`.

```text
$ tln roc install --git Karakatiza666/roc@my-branch
Build roc from Karakatiza666/roc@my-branch (dd03c09e)

Dependencies:
  [ ] zig 0.17.x            found zig 0.16.0 on PATH
  [ ] LLVM bundle           x86_64-linux-musl, 45 MB, zig gets it during the build

Install zig 0.17.0 (54 MB) for Talon builds? [Y/n]
```

This prompt (NI6, section 4) follows the consent rules DL1 to DL6 (6.2). The Zig download is required for the build. The command names the build, so in non-interactive mode Talon installs Zig with no prompt (DL4).

| # | Rule |
| --- | --- |
| D1 | Zig search order: `$ZIG`, then `zig` on `PATH` with a matching version, then a Zig that Talon installed. |
| D2 | Talon installs Zig from `ziglang.org/download/index.json` (it gives the sha256) into `toolchains/zig-<version>/`. GC removes it when no source build needs it. |
| D3 | `[x]` is found. `[ ]` with a reason is missing. The LLVM bundle line gives the size of the `roc-lang/roc-bootstrap` asset for the host target. |

### 6.7 Setup

`tln setup` connects Talon to the shell. `install.sh` runs it (6.5). It can run again: it changes only what is missing or out of date.

| # | Rule |
| --- | --- |
| ST1 | Talon writes into the bin dir `~/.local/bin/` one entry (ST7) for each of: `tln`, the `roc` launcher (6.2, ST8) and each tool (T3). On Windows each name has `.exe`. |
| ST2 | If a `roc` that Talon did not write is in the bin dir, Talon asks to replace it (prompt NI13, default no). Yes: Talon moves it to `~/.local/bin/roc.old` (`roc.old.exe` on Windows) and links it as the compiler `link-system` (6.6), so `roc +link-system` still runs it. No: Talon does not install the launcher, and prints `tln setup --replace-roc`. |
| ST3 | If a `roc` comes before the bin dir on `PATH` (for example `/usr/local/bin/roc`), Talon prints a warning with its path. It changes nothing there. |
| ST4 | If the bin dir is not on `PATH`, Talon asks to add one line to the profile of the current shell (prompt NI14, default yes): `~/.bashrc`, `~/.zshrc`, or `~/.config/fish/conf.d/talon.fish`. The line has a marker comment, so `tln tool rm talon` can find it (6.5). On Windows, Talon adds the bin dir to the user `Path` value of the environment once (6.1, Design 6.2 HF11), and `tln tool rm talon` removes exactly that entry. `--no-modify-path` skips it and prints the line or the entry. |
| ST5 | Shell completions go in the user completion dir of the shell, with no prompt. |
| ST6 | Talon never deletes or overwrites a file that it did not write, except with the ST2 consent. |

Bin dir entries and launchers. One form on Linux, macOS and Windows, so one code path, and the Linux CI tests the Windows form too:

| Entry in the bin dir | Points to | Form |
| --- | --- | --- |
| `tln`, `tln.exe` | `tln` in the data bin dir (T3) | Hard link, else a copy |
| `roc`, `roc.exe` | The same `tln` file | Hard link, else a copy. `tln` runs as the proxy (ST8). |
| `<tool>`, `<tool>.exe` | The tool binary in the data bin dir | Hard link, else a copy |

| # | Rule | Reason |
| --- | --- | --- |
| ST7 | Each bin dir entry is a hard link (`Path.hard_link!`) to its file in the data bin dir (T3). When the hard link fails (another file system or volume), Talon copies the file and sets it executable (Design 6.2, HF2). Talon writes the entry as a temp and a `rename` (CC1). | basic-cli has no symlink function (HF7), and a symlink on Windows needs developer mode or admin rights. A hard link costs no disk space. |
| ST8 | The `roc` entry is the `tln` binary with another name. At start, `tln` reads its program name (`Env.program_name!`, HF9) and takes the base name without `.exe`. When it is `roc`, `tln` runs as the proxy (6.2). Else it runs as `tln`. There is no `.cmd`, `.bat` or `.ps1` launcher, and no separate launcher `.exe`. | `cmd.exe` parses the arguments of a `.cmd` file again (`%`, `^`, `&`, `"`), asks `Terminate batch job (Y/N)?` after Ctrl-C, and can lose the exit code (E1). A separate launcher is one more binary to build and to verify. |
| ST9 | When Talon replaces a file in the data bin dir (`tln tool update talon` S3, `tool update`, `tool rebuild`, the B4 take-over), it makes each bin dir entry of that file again. When a step fails or the process stops before it, `tln setup` repairs the entries, because it changes what is out of date. | After a `rename` over the file, a hard link still points to the old file |
| ST10 | On Windows, Talon renames a `.exe` before it replaces or deletes it: to `<name>.<16hex>.del` in the same dir. Each start of `tln` tries to delete the `*.del` files in the bin dir and the data bin dir. A delete fails while the file runs, and the next start tries again. On Linux and macOS a `rename` over a running binary works, so there is no `.del` file. | Windows does not let a process delete or overwrite a running `.exe`, but it lets it rename one |
| ST11 | A bin dir entry is Talon's when its name is `tln`, `roc` or a tool name in `tools.json`, and its content is equal to the file that it points to in the data bin dir (the same sha256). ST2, ST6 and RM6 use this test. | A hard link or a copy has no link target to read |

## 7. Store and fetch

### 7.1 Pipeline

| Property | How |
| --- | --- |
| No waterfall | The registry returns the full closure up front. All fetches start at once (7.5). With `direct`, the solver fetches lazily (7.3, DI7), so the fetch of a level waits for the level before it. |
| Verify | Talon downloads the archive as `<hash>.tar.zst` into a temp dir (7.5), and runs `roc unbundle <hash>.tar.zst` there (Design 6.2, HF5). roc computes the BLAKE3 of the file, compares its base58 form to the name (`roc:src/unbundle/unbundle.zig:557-680`), and checks the paths and the size limits. A failure gives exit code 16. Measured: `research/roc-unbundle/`. |
| Atomic | Same protocol as roc: the temp dir is `packages/<hash>.<16hex>.tmp/`, and Talon renames its `<hash>/` dir to `packages/<hash>/` (`package_resolution.zig:2188-2306`). If the rename loses to roc or to another `tln`, Talon drops its copy. No lock is needed (7.4, CC11). |
| Compiler for `roc unbundle` | The format of a package archive does not depend on the nightly. So Talon uses the selected compiler (Resolution 13) when it is installed, else the newest installed compiler, else the `roc` on `PATH` (rank 7). With none, the selected compiler is a required download (DL2). |
| Sidecar | Talon does not write `<hash>.deps.json`. roc rebuilds it from `main.roc` on first use. |
| Mirrors | On a 404, Talon tries mirrors. The hash proves the bytes. The header URL does not change (H5). The registry gives the mirror list, from P3 (Design 7). Before P3, and with `direct`, the list is empty, and a 404 gives exit code 15. There is no user setting for mirrors. |
| Offline | `--offline` uses the cache only. |
| URL schemes | Talon accepts the package URLs that roc accepts: `https://` to any host, and `http://` to loopback only (`127.0.0.1`, `::1`, `localhost`). Measured: `research/roc-http-fetch/`. |

### 7.2 Cache contract with the compiler

Option B from draft 1 is now confirmed in the source: when `packages/<hash>/main.roc` exists without a sidecar, roc rescans it and writes the sidecar (`package_resolution.zig:2160-2183`). A conformance test runs this check against each new nightly.

### 7.3 Index with no registry (`direct`)

With `direct` (section 1, registry precedence), GitHub Releases are the index. Talon makes the same candidate facts as a registry record (Registry 5): version, group, hash, URL, kind, deps, `roc:` pin, `published_at`. The registry uses DI3 to DI5 when it indexes a release (Registry 7), so both modes see the same candidates.

```text
group to resolve ──▶ list releases (DI2, cached with ETag)
                        │  skip draft, prerelease (DI3)
                        │  select the <hash>.tar.zst asset (DI4)
                        │  version and group from the URL (DI5, DI6)
                        ▼
                     candidates, newest first
                        │  solver asks for one candidate
                        ▼
                     download, check hash, extract to packages/<hash>/ (DI7)
                        │
                        ▼
                     kind, deps, roc: pin from main.roc
```

| # | Rule |
| --- | --- |
| DI1 | Talon lists releases only for a group that it must resolve or show: a free direct dep, the platform, an `[overrides]` group (Resolution 6), the group of `tln add`, and the rows of `tln outdated`. A transitive group needs no list, because package headers set its version (MVS, Design 2). A command that resolves nothing (`tln install --frozen`, the `roc` proxy) makes no index call. |
| DI2 | The list call is `GET https://api.github.com/repos/<owner>/<repo>/releases?per_page=100`. `TALON_GITHUB_API` replaces the base `https://api.github.com` when it is set (section 1). Talon follows the `Link: rel="next"` header to the last page. It keeps each page and its `ETag` in `talon/index/github/<owner>/<repo>/` (6.1). A page younger than 60 s is used with no request, as `GET /v1/pkg` (Registry 4). For an older page, Talon sends `If-None-Match`. A `304` answer keeps the page. GitHub does not count a `304` answer against the rate limit when the request has a token. |
| DI3 | Only a published release is a candidate. Talon skips a draft and a release that GitHub marks `prerelease`. A deleted release is not in the list, so it is not a candidate (C6). |
| DI4 | The package asset is the one asset with the name `<hash>.tar.zst`, where `<hash>` is the base58 form of 32 bytes (Design 2). Other assets are not packages, for example `docs.tar.gz` and `<hash>.tar.zst.intoto.jsonl`. A release with no such asset is not a candidate. A release with 2 or more is not a candidate, because roc rejects one label with two hashes (Design 2, "Conflicting Package Contents"). Talon prints a warning that names the release. |
| DI5 | The candidate URL is `https://github.com/<owner>/<repo>/releases/download/<tag>/<hash>.tar.zst`. Talon gets the version and the group from this URL with the roc rule (Design 2): the one `X.Y.Z` run in the URL. A URL with no such run, with two runs, or with `0.0.0` is not a candidate (H3). The tag text around the run is part of the group. So the tags `v1.2.0` and `1.2.0` give two groups, and the tag `0.26.0-rc1` is not in the group of `0.26.0`. |
| DI6 | A candidate is in the group of a header entry only when its group key is equal. For a new entry (`tln add`), Talon uses the URL form (the group without the series, Design 4.1) of the newest candidate by `published_at`. All series in that URL form are candidates. When the repo has candidates in another URL form, Talon prints a note. |
| DI7 | Kind, deps and the `roc:` pin come from the archive, only when the solver asks for them (the lazy oracle, Resolution 5). Talon downloads the asset, checks the hash, and extracts it into `packages/<hash>/` (7.1, 7.2). Then it reads the header of `packages/<hash>/main.roc`: the first keyword gives the kind (`app`, `package` or `platform`), the URL entries give the deps, and the `roc:` entry gives the pin (Resolution 3, rank 3). Talon keeps no second copy of these facts. After GC removes the package, Talon downloads it again. |
| DI8 | The `.roc-version` hint (Resolution 3, rank 4) comes from `https://raw.githubusercontent.com/<owner>/<repo>/<tag>/.roc-version`, only when the solver needs a hint for that candidate. A `404` answer means no hint. |
| DI9 | The solver asks for candidates in the order of the strategy: newest first for `highest`. So a resolve usually downloads one or two archives for each free variable. Archive and `.roc-version` downloads do not go to `api.github.com`, so they do not use the API rate limit, and Talon sends no token with them (section 1). |
| DI10 | The release time is the GitHub `published_at` of the release. `min-release-age` and `--snapshot <time>` use it (C7, Resolution 11). |
| DI11 | A URL whose host is not `github.com` has no index in `direct` mode. The entry acts as an anchor at its header value: its domain is that one value, and no command frees it. Talon still fetches it, reads its deps (DI7) and probes it. `tln update`, `tln upgrade` and `tln outdated` print `fixed: <host> has no index without a registry`. `tln add` of a name on such a host stops with exit code 2 and names `--registry`. With a registry, the registry index gives the candidates (Registry 7, `POST /v1/ingest`). |
| DI12 | With `--offline`, Talon sends no request. It uses the cached pages and prints `index: cached at <time>` once. A candidate whose archive is not in `packages/` is skipped. A group with no cached page acts as in DI11. A new group with no cached page (`tln add`) fails with exit code 15. Without `--offline`, a network error stops the command with exit code 15, and the message names `--offline`. |
| DI13 | When GitHub answers with a rate limit error, Talon stops with exit code 15 and writes nothing. The message gives the reset time and the three token sources (section 1). |

Cost of one command in `direct` mode:

| Action | REST API calls | Other downloads |
| --- | --- | --- |
| List one repo (DI2) | 1 for each 100 releases. Most repos need 1 (basic-cli has 46 releases). | 0 |
| List one repo again after 60 s | 1 for each page. A `304` answer is free with a token. | 0 |
| Kind, deps and pin of one candidate (DI7) | 0 | 1 archive, at most 10 MB |
| `.roc-version` hint (DI8) | 0 | 1 small file |
| List the compiler releases (CV1, 6.2) | 1 for each 100 nightlies | 0 |
| `tln add` in an app with 3 direct deps and a platform | About 5 | About 4 to 8 archives |

With no token, the limit is 60 API calls an hour (section 1). That is about 10 such commands an hour.

### 7.4 Concurrent Talon processes

Many `tln` processes can run at the same time: 3 `roc` builds through the proxy, a CI matrix on one machine, an editor plugin, `tln cache gc` in a second terminal. This section has all the rules for them. Other sections refer to it.

| Item | Writers | Mechanism | Rule |
| --- | --- | --- | --- |
| `packages/<hash>/` | roc, `tln` | Temp and `rename`. The loser drops its copy. | CC11 |
| `toolchains/<id>/`, `toolchains/zig-<version>/` | `tln` | Lock of the id, then temp and `rename` | CC4 |
| `toolchains/<id>/.last-use` | proxy, probes | Write with no read | CC9 |
| `tools.json`, `projects.json`, `config.toml` | `tln` | Lock of the file around read, change, write | CC6 |
| App header, `talon.toml` | `tln`, people, editors | No lock. Compare the bytes before the `rename`. | CC7 |
| `talon/compat.db` | `tln` | SQLite WAL and a busy timeout | CC8 |
| `talon/x/<build digest>/`, `talon/index/` | `tln` | Temp and `rename` | CC11 |
| All of the above | `tln cache gc`, `tln roc rm` | GC lock, toolchain lock, age rule, rename to `.trash` | CC10 |

| # | Rule | Reason |
| --- | --- | --- |
| CC1 | Each write of a file or a dir goes to a temp `<target>.<16hex>.tmp` in the same dir, then a `rename` to the target. Talon writes no file in place. | A reader sees the old or the new item, never a part of one. The same dir gives the same file system, so the `rename` is atomic. |
| CC2 | Talon has no signal handler (Design 6.2, HF8). A crash, a kill or Ctrl-C can leave a temp, or a `.trash` dir (CC10). No command reads a temp. The lock holder of an item deletes the temps of that item (CC4). `tln cache gc` deletes the other temps, the `.trash` dirs and `talon/tmp/<16hex>/` (probe copies of an app) when they are older than 1 day (6.3). This age is the file modification time, compared with the real clock (section 1, `TALON_NOW`). A command deletes its own `talon/tmp/` dir when it ends. | One rule covers Ctrl-C, a kill and a power loss. A signal handler covers only Ctrl-C. A temp younger than 1 day can belong to a running process. |
| CC3 | Locks have one interface, in the `Fx` record (`TESTING.md` 2.3): `lock!(item, Wait \| NoWait)` gives `Held(lock)` or `Busy`, and `unlock!(lock)`. Command code takes a lock only with `with_lock!(fx, item, mode, body!)`, which calls `unlock!` also when `body!` returns an error. The contract: (1) an item has one holder at a time, across all processes on the machine; (2) a lock ends when the holder releases it, or at most 30 s after the holder process ends (a crash or a kill); (3) a lock stays held during all other `Fx` calls of the holder, also a long download or probe round; (4) the lock of the item `X` is at the path `X.lock` (6.1). No other rule and no command says how a lock is made. CC12 is the implementation, and only the real `Fx` contains it. | A change of the lock mechanism (for example an OS file lock, when basic-cli has one, Design 6.2, HF3) changes CC12 and the real `Fx` only. The rules that take locks, the command code and the L2 tests stay the same. |
| CC4 | A toolchain install (a compiler or Zig) follows the steps in the table below. | Only one process downloads a missing compiler. The others wait for it. |
| CC5 | A process that waits for a lock prints `waiting for another tln: <item>` once to stderr. It waits until the lock ends (CC3, point 2). Ctrl-C stops the wait. | A wait needs no other timeout: a live holder releases the lock, and the lock of a dead holder ends. |
| CC6 | `tools.json`, `projects.json` and `config.toml` change only under the lock of the file (the item `tools.json`, and so on, CC3). Talon takes the lock, reads the file, changes it, writes it (CC1), and releases the lock. It holds the lock for this step only, not during a build or a download. A command that builds first (`tln tool install`) takes the lock for its final step, and checks again for a binary name clash under the lock (6.4). | Last writer wins loses data: a lost `tools.json` entry leaves a binary that no command manages (T4), a lost `projects.json` entry lets GC remove a compiler that a project pins (6.3), and a lost `config.toml` change undoes `tln roc default`. The lock is held for milliseconds, so a wait is short. |
| CC7 | Project files (the app header, member files, `talon.toml`) get no lock: people and editors write them, and they do not take Talon locks. Talon keeps the bytes that it read. Just before the `rename` (CC1), it reads the file again. Same bytes: Talon writes. Other bytes, but each span that Talon edits has the same text (in a `.roc` file the header, in `talon.toml` each table that Talon changes): Talon applies its span edit (H1, `roc-toml`) to the new bytes, then writes. Else Talon writes no project file, names the file, and stops with exit code 17 (`conflict`, section 3). For more than one file, Talon checks all of them first, then writes each. | A probe run can take minutes. Talon must not overwrite an edit that a person made in that time. The second of two `tln` commands in one project gets exit code 17 and runs again. |
| CC8 | `compat.db` uses the SQLite WAL journal (`PRAGMA journal_mode=WAL`) and `PRAGMA busy_timeout=5000`. Each write round of probe facts (PP4) is one transaction. If the database stays busy past the timeout, Talon keeps the facts in memory for this command, prints a warning, and goes on. When the file system does not support WAL, SQLite keeps its default journal, and the busy timeout still applies. | Readers do not block the writer in WAL mode. A fact is evidence: a lost write costs a probe later, not a wrong result. |
| CC9 | The last use of a toolchain is the time in `toolchains/<id>/.last-use`. The proxy and each probe write the time of Talon (`TALON_NOW`, section 1) to this file (CC1) before the compiler starts. | A write with no read needs no lock, so parallel builds do not wait for each other. `.talon.json` stays unchanged after the install. |
| CC10 | `tln cache gc` takes the lock of the item `talon/gc` with `NoWait`. When another GC holds it, GC prints `another tln cache gc runs` and exits with code 0. For each toolchain to remove, GC takes its lock with no wait, and skips it when an install holds the lock. It also skips a toolchain with a last use (CC9) in the last day: a running build wrote it when it started. Then GC renames `toolchains/<id>/` to `toolchains/<id>.<16hex>.trash` and deletes that dir. `tln roc rm` (6.6) does the same with no age rule, because the user named the compiler. On Linux and macOS, a running compiler keeps its open file. On Windows, the `rename` fails while the compiler runs: Talon reports the compiler as in use, removes nothing, and exits with code 17 (`conflict`, section 3). GC removes `packages/<hash>/` with the age rule of 6.3 only. | GC never removes a compiler while an install writes it, or a compiler that a build uses. A build of a project that is not known can lose a package while it runs. That build fails once, and the next `roc` run fetches the package again. |
| CC11 | `packages/<hash>/`, `talon/x/<build digest>/` and the pages in `talon/index/` get no lock. Two processes can write the same item. Each writes a temp (CC1). The first `rename` wins. The second drops its copy (a dir), or replaces the file with equal content (an index page). | The content of each item is fixed by its name (a hash, a digest) or is a full answer. Any copy is correct. roc takes no lock for `packages/`, so a Talon lock cannot exclude roc. |
| CC12 | The implementation of CC3. The lock is the directory `<item>.lock/`. `lock!` takes it with `Path.create_dir!`, which fails when the directory exists. The holder writes a random token (16 hex digits from `Random`) and its start time to `owner` in that directory: basic-cli gives no process id and no host name. `unlock!` deletes the directory only when `owner` holds its own token. The real `Fx` writes the file `beat` again every 2 s for each lock that it holds. It does this inside its own waits (the poll loop of 7.5 and PP1, and the wait of `lock!`), so command code does nothing for it. `unlock!` deletes the directory. A lock whose `beat` is older than 30 s is stale: `lock!` renames it to `<item>.lock.<16hex>.stale`, deletes that, and tries again. With `Wait`, `lock!` checks every 200 ms. The age of `beat` is its modification time, compared with the real clock, not `TALON_NOW` (section 1). Each step of the real `Fx` that is not a wait ends in under 25 s, so a beat is never 30 s late: the real `Fx` starts each child process (`tar`, `roc unbundle`, `curl`, `wget`, probes) with `spawn!` and polls it, gives each `Http.send!` a timeout of 20 s, and a hash of an archive (at most 512 MB, Design 2) takes a few seconds. | basic-cli has no OS file lock (Design 6.2, HF3). A lock in a child process does not work: a child that lives on after a crash of `tln` keeps the lock, and the `flock` command exists on Linux only. Cargo, Go and uv use an OS lock. npm tools (`proper-lockfile`) use this directory form. `mkdir` is atomic also on NFS. Limit: two processes that find the same stale lock in the same moment can both take it. This needs a crash first, and the temp and `rename` of CC1 keep each file whole. An OS lock has no such limit. |

Steps of a toolchain install (CC4). The same steps apply to `toolchains/zig-<version>/`:

| Step | Action |
| --- | --- |
| 1 | If `toolchains/<id>/` exists, use it. Take no lock. |
| 2 | Take the lock of the item `toolchains/<id>` with `NoWait`. If the answer is `Busy`, print the CC5 line and take it with `Wait`. |
| 3 | With the lock: if `toolchains/<id>/` exists now, release the lock and use it. A process that waited downloads nothing and asks for no consent. |
| 4 | Apply the consent rules DL1 to DL6 (6.2). With no consent, release the lock and stop (exit code 13). |
| 5 | Delete each `toolchains/<id>.*.tmp`. Only the lock holder writes them, so each one is stale. |
| 6 | Download (7.5), check the sha256 (CV4), and extract with `tar` (Design 6.2, HF5) into `toolchains/<id>.<16hex>.tmp/`. Write `.talon.json` last. `rename` the dir to `toolchains/<id>/`. |
| 7 | Release the lock. A process that waits gets it and goes to step 3. If the dir is still missing (the first process failed or had no consent), that process goes on at step 4 itself. |

Example: 3 `roc build` runs start at the same time through the proxy. Each needs `nightly-2026-10-13-91fa0c2`, which is not installed. `TALON_AUTO_INSTALL=yes` is set.

```text
run A  step 2: lock ── download 70 MB, extract, rename ── release ── build
run B  step 2: waiting for another tln: nightly-2026-10-13-91fa0c2 ── step 3: dir exists ── build
run C  step 2: waiting for another tln: nightly-2026-10-13-91fa0c2 ── step 3: dir exists ── build
```

### 7.5 Download adapter

basic-cli `Http.send!` blocks and keeps the whole body in memory (Design 6.2, HF4). A nightly is 70 MB. So Talon downloads each file with a child process, `curl` or `wget`. One child writes one file, and many children run at the same time. `curl` is part of macOS, Windows 10 (1803 or later) and most Linux systems. `wget` covers most of the others. The install scripts use the same pair (6.5).

| # | Rule |
| --- | --- |
| DA1 | The adapter downloads package archives (7.1), compiler and Zig archives (6.2, 6.6), prebuilt binaries (6.4, 6.5) and nothing else. Small API answers (DI2, DI8, CV1, the registry API) use `Http.send!`. |
| DA2 | Talon uses `curl` when it is on `PATH`, else `wget`. `TALON_DOWNLOADER=curl` or `wget` selects one (section 1, environment variables). With none of them, the command stops with exit code 18 (`environment`). |
| DA3 | Command lines. `curl`: `curl --fail --location --silent --show-error --proto =https,http --retry 2 --connect-timeout 30 --output <temp> <url>`. `wget`: `wget --quiet --tries=3 --timeout=30 --output-document=<temp> <url>`. Talon checks the URL scheme first (7.1, URL schemes). Talon passes no token and no header, so a download carries no credentials (section 1, DI9). Both programs read the proxy variables (`HTTPS_PROXY`, `NO_PROXY`) and the CA store of the system, so Talon reaches the network as other tools on that machine do. |
| DA4 | The output goes to a temp file in the target dir (7.4, CC1). Talon checks the hash before any other use: BLAKE3 for a package (`roc unbundle`, 7.1), sha256 for a compiler (CV4), for Zig (D2) and for `tln` (S1). A source archive has no published hash (6.6, R7). Then it renames or extracts the file. |
| DA5 | Talon runs up to 8 downloads at the same time. It polls them with `try_wait!` in the same loop as the probes. A download takes no probe slot (Resolution 4, PP1). The same item is downloaded once, also by many processes (7.4, CC4 for toolchains, CC11 for packages). |
| DA6 | Progress is the size of the temp file, read in the poll loop. The total comes from the asset size in the release list (DI2, CV1), when it is known. |
| DA7 | A child that exits with an error gives exit code 15 (`network`). The message names the URL and the last stderr line of the program. An HTTP error answer (`curl` exit 22, `wget` exit 8) makes Talon try the mirrors first (7.1). Ctrl-C also stops the children, because they share the process group (Unix) or the console (Windows). A temp file that stays is removed as in CC2. |

