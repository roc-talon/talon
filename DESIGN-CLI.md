# Talon design: CLI

Part of the Talon design. This file holds the `tln` commands, references, exit codes, prompts, the toolchain manager and the fetch pipeline. `DESIGN.md` has the goals, the core model and the list of files.

A reference such as CLI 6.2 is section 6.2 of `DESIGN-CLI.md`. Design, Resolution and Registry name `DESIGN.md`, `DESIGN-RESOLUTION.md` and `DESIGN-REGISTRY.md`. A plain number is a section of this file.

## 1. Commands

| Command | Does | Bun equivalent |
| --- | --- | --- |
| `tln init [app\|package] [--platform <name>] [--ci github\|none]` | New app or package, with the nightly as the `roc:` entry of the header (not `.roc-version`, Resolution 13) and a CI file. Rules: section 5. | `bun init`, `bun create` |
| `tln install [name[@sel]...] [--platform] [--as <alias>] [--no-pin] [--no-check]` | With no names: keep the header, change only entries that break `talon.toml`, fetch the closure (Resolution 9). With names: add each one, resolve, write the header. Lookup, alias and `talon.toml` rules: section 2. `add` and `i` are the same command. | `bun install`, `bun add` |
| `tln remove json [--force]` | Remove the entry, its range, its override and its patch entry. Rules: section 2. | `bun remove` |
| `tln update [pkg[@sel]...] [-i] [--no-check]` | Move within ranges. Names limit the scope. `pkg@sel` moves to the selector, also to a new major (Resolution 10). The nightly does not move (RP1). `-i` is an interactive picker. Scope rules: Resolution 9. | `bun update -i` |
| `tln upgrade [pkg...] [roc] [--no-check]` | Move to the newest releases, also to new majors, and to the newest nightly. Change the `talon.toml` ranges to match. Names limit the scope. The name `roc` frees the nightly. Rules: Resolution 10, RP1. | `bun update --latest` |
| `tln outdated` | Table: current, wanted, latest, nightly range | `bun outdated` |
| `tln why parser` | Paths from the app to a package, and why this version (evidence) | `bun why` |
| `tln probe [pkg] [--range] [--share]` | Find the nightly range of a release. Optionally share the result | |
| `tln list [--tree]` | Closure with marks: shared, resolved, foreign, patched | `bun pm ls` |
| `tln patch json` | Edit a copy of a dependency (Resolution 7) | `bun patch` |
| `tln verify [--strategy highest\|lowest]` | Resolve in memory, run the probe ladder (Resolution 4) on the tuple with `--replace-dep`, and print the result. It writes no header and no `talon.toml`. Probes add evidence to `compat.db` as usual. It does not replace `roc check` (N2). Use: Resolution 8. | |
| `tln x owner/app [-- args]` | Build a Roc app and run it once. The binary stays in the cache. Rules: 6.4, X1 to X5. | `bunx` |
| `tln publish` | Register a release (Registry 7) | `bun publish` |
| `tln audit` | Yanked, advisories, scanner hook | `bun audit` |
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

Resolve flags work only for commands that resolve: `install` (and `add`), `remove`, `update`, `upgrade`, and `verify` (Resolution 8). Other commands (`roc`, `tool`, `cache`, `x`, `list`, `why`, and the rest) reject them with an error.

| Flag | Meaning |
| --- | --- |
| `--frozen`, `--no-probe`, `--no-check`, `--dry-run` | See Resolution 12 |
| `--snapshot <log:N\|time>` | Hide releases added after a registry log size (`log:N`, registry only) or published after a UTC time (RFC 3339, registry or `direct`). See Resolution 11. |
| `--strategy highest\|lowest` | Version choice (Resolution 8). `upgrade` rejects `lowest` (UP8). |
| `--slots <n>` | Size of the probe slot pool (Resolution 4, "Parallel probes"). Default 12: 12 checks or 3 builds at the same time. |

Command flags that other sections define:

| Flag | Commands | Where |
| --- | --- | --- |
| `--member <path>` | `install` with names (and `add`), `remove`, in a workspace | Design 4.4 |
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
| 4 | The default registry URL |

With `direct`, and for the list of nightlies, Talon calls the GitHub API. With no token, GitHub allows 60 requests an hour for one IP address. So Talon uses a token when it finds one, in this order: `GITHUB_TOKEN`, `GH_TOKEN`, then the output of `gh auth token` when `gh` is installed and logged in. Talon sends the token only to `api.github.com`, never to a registry or a mirror. With no token, a rate limit error (exit code 15) names these three sources.

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

## 2. References in the CLI

One grammar names packages, platforms, tools and compiler releases:

```text
ref      = name [ "@" selector ] | "@" selector | nightly-tag
name     = alias | owner/repo | host/path | short
selector = version | range | major | "latest" | nightly-tag | git-ref | ("+" | "-") count
```

The two short forms are valid only in the `tln roc` scope. There the default name is `roc-lang/roc`:

| Short form | Means |
| --- | --- |
| `@sel` | `roc-lang/roc@sel` |
| `nightly-2026-10-09-258ab27` | A nightly tag with no `@`. `roc-lang/roc@nightly-2026-10-09-258ab27` is the same ref. |

| Selector | Example | Meaning |
| --- | --- | --- |
| Release version | `owner/app@1.4.0` | That release |
| Range or major | `roc-lang/http@^2`, `roc-lang/http@2` | The newest match. For an installed entity, it selects among the installed ones. |
| Latest | `owner/app@latest` | The newest release that is not yanked, found online. In `tln tool install` and `tln x`, it turns off the reuse of an older build (6.4, B2). In `tln add`, it is the same as no selector. In `tln update X@latest`, it is the newest release, also in a new major (Resolution 10). |
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

The separator is `@`, not `#` as in npm, because the shell reads `#` at the start of a word as a comment. Some shells also read `^` (zsh with `EXTENDED_GLOB`) and `~` as special. Quote a ref that has them: `'roc-lang/http@^2'`. The shell-safe forms `@2`, `@2.x` and `@2.1.x` need no quotes. `@2.x` means the same as `@^2`, and `@2.1.x` means 2.1.0 up to, but not including, 2.2.0.

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

The group includes the major (Design 2), so one closure can hold `roc-lang/http` 1.x and 2.x. Then the major is part of the name: `roc-lang/http@2`.

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
| `tln add X@^1.2`, `tln add X@1` (range or major) | New entry, newest version in range | Range `X = "^1.2"`, and `X = "^1"` for `@1`. Talon creates the file if it is missing. |
| `tln add X@1.2.3 --no-pin` | New entry at 1.2.3 | Nothing, as for `tln add X`. A later `tln update` can raise the version inside the major. |

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
| 2 | `usage` | Bad flag, bad ref, ambiguous name, invalid alias, a resolve flag on a command that does not resolve, a `log:` snapshot with no registry, an interactive-only flag (`update -i`) in non-interactive mode, `--frozen` on a command that changes the header, `--json` with `tln x`, no selected compiler (Resolution 13), no `--member` where one is needed (Design 4.4), or `tln remove` of the platform | Sections 1, 2 and 4, Design 4.4, Resolution 11 and 13 |
| 10 | `no_tuple` | No tuple works. Talon prints the explanation. | Resolution 5 |
| 11 | `app_error` | A new error in an app file, or `tln remove` of an alias that the app imports. Talon stops and reports. | Resolution 4 ladder step 2, section 2 |
| 12 | `budget` | A probe budget is spent before a tuple was found | Resolution 4, P5 |
| 13 | `consent` | A required prompt (section 4) has no answer: Talon is in non-interactive mode, and there is no `--yes` and no flag that gives the answer | section 4 |
| 14 | `frozen` | `--frozen` found a mismatch: the header does not satisfy `talon.toml`, or a resolve is needed | Resolution 12 |
| 15 | `network` | A registry, GitHub or download error | 7.1 |
| 16 | `integrity` | A hash or checksum does not match | 7.1, Design 8 |

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

Example, for `tln add parser@2.0.0` (data fields are shortened):

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

Example of a failure, for `tln add parser --json` (non-interactive) with a required compiler download:

```json
{
  "schema": 1,
  "command": "add",
  "ok": false,
  "data": null,
  "error": { "kind": "consent", "code": 13, "message": "1 compiler download (70 MB) needs consent. Pass --yes or set TALON_AUTO_INSTALL=yes." }
}
```

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
| NI5 | `add`, `update`, `upgrade`, `install`, `probe`, `verify`, the `roc` proxy | A required compiler download that the command does not name | No (yes for the proxy, DL3) | Required | Exit 13 | `--yes`, `TALON_AUTO_INSTALL=yes` | 6.2, DL4 |
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
| NR1 | A prompt writes to stderr and reads from stdin. It never prompts when stdin or stderr is not a TTY, even if no variable is set. |
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
  toolchains/<id>/.talon.json   talon    source URL, sha256 or commit, ref typed, compat id, install time, last use
  toolchains/zig-<version>/     talon    Zig for source builds (6.6)
  talon/index/                  talon    cached registry responses (ETag)
  talon/compat.db               talon    probe results
  talon/projects.json           talon    known projects, for GC
  talon/x/<build digest>/       talon    binary and manifest built by tln x (6.4, B1 to B8)
```

User settings and tools are not in the cache, so a cache cleanup cannot remove them:

```text
$XDG_CONFIG_HOME/talon/config.toml   (else ~/.config/talon/)        user settings, see below
$XDG_DATA_HOME/talon/bin/            (else ~/.local/share/talon/)   tool binaries (6.4, T3)
$XDG_DATA_HOME/talon/tools.json                                     tool manifests (6.4, T4)
```

```toml
# config.toml
default-roc = "nightly-2026-10-09-258ab27"   # tln roc default writes it. A full id only (section 2).
registry = "direct"                          # or a URL (section 1, registry precedence)
nightly = true                               # the nightly switch (Resolution 1, NS1). talon.toml has priority.

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
| Install | `tln setup` puts a `roc` launcher on `PATH` that runs `tln` in proxy mode (6.7). |
| Dispatch | Talon selects the compiler (Resolution 13), runs it, forwards stdio and the exit code. Cost target: under 5 ms. |
| Missing compiler | Follows `TALON_AUTO_INSTALL` and the consent rules DL1 to DL5 (see "Download consent" below). Default `ask`. Modeled on Go `GOTOOLCHAIN`. There is no `--no-auto-install` flag: `roc` flags go to the compiler. Use `TALON_AUTO_INSTALL=no`. |
| Patches | Adds `--replace-dep` for each `[patch]` entry. |
| Cache paths | Sets `XDG_CACHE_HOME` and `ROC_CACHE_DIR` to canonical absolute paths. With `..` in `XDG_CACHE_HOME`, `roc check` prints "No errors found" for any app (Q15). Probes use the same rule. |
| Opt out | `TALON_PROXY=0` runs the selected compiler with no extra work. |

Compiler sources: release assets of `roc-lang/nightlies`. Archives are `.tar.gz` (Linux, macOS) and `.zip` (Windows), about 70 MB each. The registry keeps a sha256 list for them.

#### Download consent

One rule set covers each command that downloads a compiler or Zig: `add`, `update`, `upgrade`, `install`, `probe`, `roc install`, `roc update`, `tool install`, `x`, the `roc` proxy, and the Zig install of 6.6. Other sections refer to these rules and do not repeat them.

| # | Rule |
| --- | --- |
| DL1 | Talon asks once for each command, not once for each download. The prompt shows how many downloads can happen and their total size. A download that is not in the prompt does not start. |
| DL2 | A required download is one without which the command cannot finish. Examples: the `roc:` pin that the proxy must run, the compiler of `tool install`, Zig for a source build. An optional download only widens a probe search (Resolution 4, P5). |
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
| `nightly-<tag>/`, `debug-<sha>/` dirs | Never removed | Removes them. No current compiler writes them. (3.1 GB here.) |
| `compat-<id>/` dirs | Never removed | Removes a dir whose id belongs to no installed toolchain |
| `packages/<hash>/` | Never removed | Removes it if no known project used it in N days |
| Toolchains | n/a | Keeps the default and toolchains pinned by a known project in N days |
| `talon/x/<build digest>/` (binaries of `tln x`, 6.4) | n/a | Removes an entry that no `tln x` run used in N days |

The compat id is a build-time hash that `roc` does not print. Talon learns it at install: it runs one `roc check` on an empty file and records which `compat-<id>/` dir the run touched. Upstream request: print the id in `roc version --verbose`.

`tln cache gc --dry-run` prints what it would free.

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
| Order | Releases in the same epoch as the pin first (Resolution 4: no result changed inside an epoch), then newer before older |
| Each release | `roc check` on the app, with `probe.timeout`. On a fail, go to the next release. |
| First pass | `roc build` with that release. On a fail, go to the next release. |
| All fail | Show the prompt again with options 1 and 3, and a list of each release with the first error line |
| Record | Each pass and fail goes in `compat.db`. The next install of this closure finds the evidence and shows no prompt. |

| # | Rule | Reason |
| --- | --- | --- |
| T1 | Build from the app header as it is (hashes and `roc:` pin). Do not resolve again. `--resolve` allows a new resolution. | The header is the lock (G1). A new resolution can select packages that the author did not test. |
| T2 | Only an app whose platform makes a native executable can be installed. | A `package` has no entry point. A wasm platform, such as `cloudflare-workers`, makes no CLI. |
| T3 | Binaries go in `$XDG_DATA_HOME/talon/bin/` (else `~/.local/share/talon/bin/`), not in the cache. `tln setup` links them into `~/.local/bin/`. | The cache has a 30-day expiry and GC (6.3). A cleanup must not delete a tool. |
| T4 | `$XDG_DATA_HOME/talon/tools.json` records, for each tool: source, build id (hashes, nightly, target), binary sha256, run-time libraries (T8), install time. The sha256 identifies the installed file only. Talon does not compare it with the sha256 of another build. | `tln tool ls`, `update` and `rebuild` read it. A build of the same build id can give other bytes: a build on a warm cache differs from a build on an empty cache (Q18). |
| T5 | A tool does not keep its nightly. GC (6.3) can remove the nightly after the build. | The binary does not need it. A rebuild installs it again. |
| T6 | A download follows the consent rules DL1 to DL6 (6.2). `--roc pinned` also counts as consent for the pinned download. An installed release is used without a prompt only when evidence supports it. | No surprise download of 228 MB, and no silent build with a release that nobody tested. |
| T7 | `tln tool rebuild` builds again from the manifest, with the same build id. | Repair after an OS upgrade breaks a dynamic link (T8). |
| T8 | Talon builds a tool with no `--target`. roc then uses the musl target of the platform, else its glibc target. For a glibc build, `tools.json` records the libraries in the ELF `NEEDED` list, and `tln tool ls` shows them. | A musl build is static and has no run-time dependency. A glibc build needs system libraries: roc-ray needs `libX11.so.6` (Q16). |

Prebuilt binaries: a release can attach a binary for each target, as `cargo-binstall` expects. Then an install needs no compiler release, and the source build is the fallback. P1 builds this path for Talon itself (6.5). In P2 the registry lists prebuilt binaries for other tools too.

Tools from a git ref (section 2):

| Command | Effect |
| --- | --- |
| `tln tool install --git owner/app@main` | Get the commit, read `main.roc`, then build as above. `--path apps/cli` selects an app in a subdirectory. `tools.json` records the commit and the ref that the user typed. |
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
| X4 | `tln x` runs the output. Probes do not (P1). Talon prints the platform URL and hash before the build. It does not ask again before the run: the user named the app. The exit code of `tln x` is the exit code of the app. | The run is the purpose of the command. |
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
| B2 | With a selector, a matching build is used only if its version satisfies the selector. `@latest`: the version is the newest release. `@1.3.0`: the version is 1.3.0. A range or major (`@1`, `@^1.2`): the version is the newest release in that range. | The user asked for a version, so an older build is not enough |
| B3 | Online, Talon always resolves the request first. It checks that the version of the matching build is not yanked and has no advisory. If it is, Talon does not use the build and builds the newest release that is not yanked. There is no override. When the matching build is older than the newest release, Talon prints `installed cached 1.2.0 (1.4.0 is available: tln tool install foo@latest)`. | Reuse skips the build, not the safety checks (C6, `tln audit`) |
| B4 | `tln tool install` takes over a matching `x` cache entry. It moves the binary to the bin dir (T3), checks the sha256, writes the `tools.json` entry from the manifest, and removes the cache entry. If a `rename` is not possible (another filesystem, or a running `.exe` on Windows), it copies, checks the sha256, then deletes the cache entry. | One owner, no second copy. The tool now has the lifetime of a tool, not of a cache entry. |
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
| S3 | An update writes the new binary to a temp file, runs `tln --version` on it, then does a `rename` over the old one. On Windows, it renames the running `.exe` first. | A binary that does not start never replaces the working one. A running `.exe` cannot be overwritten. |
| S4 | No rollback command, and no copy of the old binary. The repair path is `install.sh --version <v>`. | A broken binary cannot run a rollback command. `install.sh` does not need a working `tln`. |
| S5 | `tln tool rm talon` asks what to remove (prompt NI10, section 4), then removes it. See "Remove Talon" below. | One namespace for all tools. Removing Talon also removes the proxy, so the user must confirm. |

The install scripts follow these rules:

| # | Rule |
| --- | --- |
| IS1 | Two scripts: `install.sh` for Linux and macOS (POSIX `sh`: tested with dash, bash and busybox), and `install.ps1` for Windows (PowerShell 5.1 and later). Each Talon release has both as assets, so `latest/download/install.sh` is the script of the newest release. |
| IS2 | A release has one binary for each Roc target: `tln-x64musl`, `tln-arm64musl`, `tln-x64mac`, `tln-arm64mac`, `tln-x64win.exe`, `tln-arm64win.exe`, and `sha256sums.txt`. The Linux binaries are static musl, so one binary works on each distribution (Design Q16). On macOS, a shell under Rosetta gets the arm64 binary. Other systems stop with an error that lists the targets. |
| IS3 | The script checks the sha256 from `sha256sums.txt` (exit code 16), and the attestation when `gh` is installed and logged in (S1). It uses `latest/download/` URLs, so it needs no GitHub API call and no token. |
| IS4 | The script asks `Proceed? [Y/n]` (prompt NI15, kind Default). It uses the non-interactive rules of section 4, with one difference: with `curl \| sh`, stdin is the script, so `install.sh` reads the answer from `/dev/tty`. In non-interactive mode, the install goes on with no prompt, because the command names it. `--yes` (`-Yes`, or `TALON_YES=1` for `irm \| iex`) skips the prompt. |
| IS5 | The download goes to a temp file in the bin dir. The script runs `--version` on it, then renames it over the old binary (S3). On Windows it first renames the old `tln.exe`. A failed check keeps the old binary and leaves no temp file. |
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
| RM5 | Talon removes its own binary last. On Windows, it renames the running `.exe` and deletes it at the next start of the system (S3). |
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

Links and copies of a local build:

| # | Rule | Reason |
| --- | --- | --- |
| LK1 | A `link-<name>` follows its target, so a rebuild changes the compiler under the same id. Talon keys the local probe results of a link by the sha256 of the binary, not by the id. | Old evidence must not apply to a new build |
| LK2 | `tln roc link --copy <name> <path>` copies the binary (it follows symlinks) into `toolchains/copy-<name>/`. A later rebuild of the source tree does not change it. A name that exists is an error. `--force` replaces it. | A fixed local build to compare against, or to keep while the tree changes |
| LK3 | `copy-*` follows R4 and R5, as `git-*` does: it is never a `roc:` pin, and its probe results stay local | roc does not accept a local build as a pin |

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
| RU1 | Talon finds the newest compiler release online that the `nightly` switch allows (Resolution 1, NS3), and installs it. With the switch on (the default), that is the newest nightly. The command names the download (NI6). If the newest nightly is already installed, Talon prints `nightly-2026-10-13-91fa0c2 is the newest` and does nothing. |
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
| ST1 | Talon writes into the bin dir `~/.local/bin/`: a link to `tln`, the `roc` launcher (6.2) and the links of tools (T3). |
| ST2 | If a `roc` that Talon did not write is in the bin dir, Talon asks to replace it (prompt NI13, default no). Yes: Talon moves it to `~/.local/bin/roc.old` and links it as the compiler `link-system` (6.6), so `roc +link-system` still runs it. No: Talon does not install the launcher, and prints `tln setup --replace-roc`. |
| ST3 | If a `roc` comes before the bin dir on `PATH` (for example `/usr/local/bin/roc`), Talon prints a warning with its path. It changes nothing there. |
| ST4 | If the bin dir is not on `PATH`, Talon asks to add one line to the profile of the current shell (prompt NI14, default yes): `~/.bashrc`, `~/.zshrc`, or `~/.config/fish/conf.d/talon.fish`. The line has a marker comment, so `tln tool rm talon` can find it (6.5). On Windows, Talon adds the bin dir to the user `Path` value of the environment once (6.1), and `tln tool rm talon` removes exactly that entry. `--no-modify-path` skips it and prints the line or the entry. |
| ST5 | Shell completions go in the user completion dir of the shell, with no prompt. |
| ST6 | Talon never deletes or overwrites a file that it did not write, except with the ST2 consent. |

## 7. Store and fetch

### 7.1 Pipeline

| Property | How |
| --- | --- |
| No waterfall | The registry returns the full closure up front. All fetches start at once. |
| Verify | BLAKE3 over the compressed stream, then base58, then compare to the URL hash. Same scheme as `roc:src/unbundle/unbundle.zig:557-680`. |
| Atomic | Same protocol as roc: extract into `packages/<hash>.<16hex>.tmp`, then `rename` to `packages/<hash>/` (`package_resolution.zig:2188-2306`). If the rename loses to roc, Talon drops its copy. No lock file is needed. |
| Sidecar | Talon does not write `<hash>.deps.json`. roc rebuilds it from `main.roc` on first use. |
| Mirrors | On a 404, Talon tries mirrors. The hash proves the bytes. The header URL does not change (H5). |
| Offline | `--offline` uses the cache only. |
| Fallback | If a host feature is missing, Talon runs `roc check` on a stub app with the closure and lets roc fetch. |

### 7.2 Cache contract with the compiler

Option B from draft 1 is now confirmed in the source: when `packages/<hash>/main.roc` exists without a sidecar, roc rescans it and writes the sidecar (`package_resolution.zig:2160-2183`). A conformance test runs this check against each new nightly.

