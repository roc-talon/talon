# CLI design audit

Audit of the `tln` CLI in `DESIGN.md` (Draft 2, 2026-10-13). Line numbers point to Draft 2 before the fixes.

Each group is one work item. A group changes `DESIGN.md` only. Status: all 24 points are fixed in Draft 3 (2026-10-14).

Section numbers in this file point to `DESIGN.md` before the split of 2026-10-15. The split moved the sections into 4 files and changed their numbers:

| Old | New |
| --- | --- |
| 1 to 3, 2.1, 2.2, 4, 4.1 to 4.3 | `DESIGN.md`, same numbers |
| 4.4 Determinism | `DESIGN-RESOLUTION.md` 11 |
| 4.5 Workspaces | `DESIGN.md` 4.4 |
| 4.6 References in the CLI | `DESIGN-CLI.md` 2 |
| 5.1 to 5.10 | `DESIGN-RESOLUTION.md` 1 to 10 |
| 6.1 Selection order | `DESIGN-RESOLUTION.md` 13 |
| 6.2 to 6.8 | `DESIGN-CLI.md` 6.1 to 6.7 |
| 7.1, 7.2 | `DESIGN-CLI.md` 7.1, 7.2 |
| 7.3 Lock and frozen modes | `DESIGN-RESOLUTION.md` 12 |
| 8, 8.1, 8.2, 8.3 | `DESIGN-CLI.md` 1, 3, 4, 5 |
| 9.1 to 9.7 | `DESIGN-REGISTRY.md` 1 to 7 |
| 10.1, 10.3, 10.4 | `DESIGN.md` 6.1, 6.2, 6.3 |
| 10.2 Worker host: JSPI | `DESIGN-REGISTRY.md` 8 |
| 11, 12, 13 | `DESIGN.md` 7, 8, 9 |

| Group | Points | Subject |
| --- | --- | --- |
| A | 1, 14 | Consent for downloads, prompts with no TTY, `--yes` |
| B | 2, 3, 22, 23 | Resolve flags, CI reproduction |
| C | 4, 24 | Whole-app check with a broken app, build cost |
| D | 5, 11 | Scope of `update` and `install` |
| E | 6 | `.roc-version` as a second lock |
| F | 7, 8, 9, 10 | `tln add`: alias, name lookup, `talon.toml` writes, alias rename |
| G | 12, 13, 21 | Missing commands, `tln x`, verb aliases |
| H | 15, 16 | Exit codes, `--json` schema, snapshot with no registry |
| I | 17, 18, 19, 20 | Reference grammar |

## High

| # | Finding | Where | Fix |
| --- | --- | --- | --- |
| 1 | Download consent is not consistent. `tln tool install` asks before one compiler download (T6). `tln add` can download up to 6 nightlies with no prompt (P5 default `max-toolchains = 6`, about 1.4 GB unpacked). The `roc` proxy installs with no prompt. | `:333`, `:499`, `:589` | One consent rule for all commands: prompt on a TTY, fail with no TTY, `--yes` accepts. Default `max-toolchains` is 0 new downloads unless the user agrees. |
| 2 | `--no-probe` conflicts with "the final tuple always gets a local check". | `:191`, `:301`, `:687` | `--no-probe` stops new unit probes only. The final ladder always runs. A separate flag skips it. |
| 3 | CI reproduction does not work: local probe facts (rank 1) are never shared as trusted data, so CI with `--no-probe` lacks the evidence that picked the tuple. | `:191`, `:299`, `:805` | CI uses `--frozen` (verify the header). It does not resolve again. |
| 4 | `tln add` and `tln update` fail when the app already has a compile error, because the whole-app check is mandatory and app errors stop Talon. | `:301`, `:311` | Check before and after the change. Blame only new errors. Add `--no-check`. |
| 5 | `tln update json` can move `pf` and `roc` because of the default `priority`. `--roc` is not defined. | `:273`, `:698` | `update X` frees only X and what must move with it. `--roc` frees the nightly. |
| 6 | `.roc-version` is a second lock (against G1). `tln init` writes it, and it has priority over `talon.toml` in 6.1. | `:18`, `:474`, `:694` | `init` writes the header `roc:` only. Talon reads `.roc-version` but never writes it. |

## Medium

| # | Finding | Where | Fix |
| --- | --- | --- | --- |
| 7 | `tln add` has no alias rule and no clash rule. No `--as`. | `:695`, `:715` | See "Rule for point 7" below. |
| 8 | `add` is not in the scope table, so a short name matches the whole registry (typosquat risk). | `:227`, `:239` | Define the `add` scope and its lookup rules. |
| 9 | Not clear what `add` writes to `talon.toml`. `add X@2.0.0` is a hard pin. Does `add X` create `talon.toml`? | `:19`, `:265` | State the rule for each form. |
| 10 | A rename of a header alias breaks the link to `talon.toml`. `tln install` then adds a duplicate entry. | `:153`, `:181` | Detect a group that is already in the header under a different alias. |
| 11 | `tln install` does not say if it keeps header entries that satisfy their ranges. | `:181`, `:697` | Install keeps the lock. It changes only entries that break intent. |
| 12 | `tln check` (5.8), `tln roc use`, and cache removal are used but not defined. | `:461`, `:707`, `:624`, `:709` | Define or remove each. |
| 13 | `tln x` has no rules for compiler choice, consent or cache. | `:704` | Same rules as `tln tool install`. |
| 14 | Non-TTY rules exist only for `tool install`. Zig `[Y/n]` prompt and `--json` have none. `--yes` is not global. | `:558`, `:654`, `:712` | Covered by point 1. |
| 15 | No exit codes, no `--json` schema or version. | `:408`, `:712` | Add an exit code table and a versioned JSON envelope. |
| 16 | `snapshot` needs the registry log. With `TALON_REGISTRY=direct` there is no snapshot. | `:173`, `:733` | Accept a time snapshot (as uv `exclude-newer`). |

## Low

| # | Finding | Where | Fix |
| --- | --- | --- | --- |
| 17 | The ref grammar requires `name`, but `tln roc install @main` and `tln roc install nightly-...` do not fit. | `:211`, `:630` | State the default name in the `roc` scope and allow a bare tag. |
| 18 | A selector falls back to a git ref without a marker. A typo like `@mian` starts a source build. | `:223` | Git fallback only for sha-like selectors. Branch and tag need `--git`. |
| 19 | Id prefixes like `git-dd03` in `ROC_TOOLCHAIN` break when a later install makes them ambiguous. | `:240`, `:641` | Prefixes only in interactive commands. Full ids in env, pins, files. |
| 20 | `@^2` breaks in zsh with `EXTENDED_GLOB`. | `:219` | Document quoting. Also accept `@2.x`. |
| 21 | Verb names are mixed: `remove` and `tool rm`, `ls` and no `list`. | `:696`, `:707` | Define the aliases. |
| 22 | `--frozen` and `--locked` mean different things in Cargo and uv. | `:685` | Rename or remove `--locked`. |
| 23 | `--frozen` and `--no-probe` are global but mean nothing for `roc`, `tool`, `cache`. `--registry` and `TALON_REGISTRY` have no precedence. | `:712`, `:733` | Scope the flags. State precedence. |
| 24 | `roc build` on each `add` and `update` conflicts with G5. | `:24`, `:314` | Skip the build when a build pass is recorded for (platform hash, nightly, target). |

## Rule for point 7

The default alias comes from the release name. Talon may shorten a name only to its full unqualified name: the repo name, without the owner.

| Full name | Default alias | Why |
| --- | --- | --- |
| `roc-lang/basic-cli` | `basic_cli` | Repo name. `-` becomes `_`, because an alias is a Roc identifier. |
| `roc-lang/unicode` | `unicode` | Repo name |
| `lukewilliamboswell/roc-parser` | `parser` | Exception: a leading `roc-` is dropped |
| `someone/roc-json` | `json` | Same exception |

No other shortening is allowed. Talon does not drop other prefixes or suffixes, does not abbreviate, and does not guess. The `roc-` prefix is the only exception. The same rule gives the short name in name lookup (4.6, form 3).

## Round 2

Audit of Draft 3 (2026-10-14). Line numbers point to Draft 3 before the round 2 fixes.

| # | Sev | Finding | Status |
| --- | --- | --- | --- |
| 1 | High | `--yes` gives "the interactive default", but NI3, NI4 and NI9 (default No) say that `--yes` accepts | Fixed: `--yes` is "yes" or the default option (8.2). NI11 is now a note (R2). |
| 2 | High | `TALON_AUTO_INSTALL=yes` has "the same effect" as `--yes` for every command. The CI file of `tln init` sets it. | Fixed: required compiler and Zig downloads only (DL5) |
| 3 | High | No command moves a dependency to a new major | Fixed: `tln update X@sel` and `tln upgrade` (5.10) |
| 4 | Medium | `--yes` answers all prompts or none | Fixed: an answer flag for each Required prompt (NR6, flag table in section 8) |
| 5 | Medium | Workspaces: which member header `add`, `update` and `roc use` write | Fixed: member table and `--member` (4.5) |
| 6 | Medium | The proxy: how it finds the target file, and what it does when nothing is selected | Fixed: target file rule, no-selection error, first install is the default (6.1) |
| 7 | Medium | `--json` with `tln x`: the app also writes to stdout | Fixed: `tln x --json` is exit 2 (section 8) |
| 8 | Medium | `tln x` with a short name runs code with no confirmation | Fixed: short names in `x` and `tool install` match local entries only (4.6) |
| 9 | Medium | `tln setup` is not defined (PATH, shell files, an existing `roc`) | Fixed: 6.8 Setup, ST1 to ST6, NI13, NI14 |
| 10 | Medium | `tln remove`: the platform, imported aliases, overrides, patches | Fixed: `tln remove` table (4.6) |
| 11 | Medium | `--platform` of `add` is not defined | Fixed: `tln add --platform` table (4.6) |
| 12 | Medium | Where the global default and user settings are stored | Fixed: `config.toml` (6.2), registry precedence |
| 13 | Medium | `--dry-run` writes probe results and can download | Fixed: `--dry-run` row (7.3) |
| 14 | Low | The proxy and `tln x` exit codes look the same as the child exit codes | Fixed: E4, last stderr line `tln: error[<kind>]` |
| 15 | Low | `--quiet` and the answer lines of 8.2 | Fixed: `--quiet` keeps answer lines |
| 16 | Low | No way to force interactive mode when `CI` is set | Fixed: `TALON_INTERACTIVE` (8.2) |
| 17 | Low | `tln install json` is not defined | Fixed: `install`, `i` and `add` are one command (section 8) |
| 18 | Low | `tln tool update` with no name, and a second `tool install` | Fixed: rows in the 6.5 tool table |
| 19 | Low | NI10 option 1 removes every `roc`, and the prompt does not say so | Fixed: prompt line and RM6 |
| 20 | Low | `tln init`: which nightly, consent, which CI system | Fixed: 8.3 `tln init` |
| 21 | Low | `--frozen` has a meaning only for `install` | Fixed: only `tln install` with no names accepts it |
| 22 | Low | DL6 wording | Fixed: DL6 wording |

Added in round 2 at the request of the user: parallel probes (5.4, PP1 to PP5: a pool of 12 slots, a check takes 1 slot and a build takes 4), `tln roc update` (6.7, RU1 to RU4), prompt NI12, open question Q18.

Measured on 2026-10-14: Q16 (`conformance/host-link/`, new rule T8) and Q18 (`conformance/build-share/`) are settled. Q13 is settled by a short edge test (`cloudflare-workers/bench/edge.mjs`). Q14 stays open: it needs the registry app (P2).

Changed on 2026-10-15: the `--roc` flag of `update` (fix of point 5) is removed. Only `tln upgrade` (no names, or the name `roc`) and `tln roc use` change the `roc:` pin (RP1 to RP4 in 5.9).

## Round 4: readiness audit (2026-10-15)

Question: is the design ready to implement? Answer before this round: the generic packages yes, the command layer no. All points below are fixed.

| # | Level | Gap | Fix |
| --- | --- | --- | --- |
| 1 | Blocker | No rules for the `direct` index | CLI 7.3, DI1 to DI13 |
| 2 | Blocker | P0 needs P1 parts, and some commands have no phase | Design 7 (P0 limits, command phases), Resolution 13 rank 7 |
| 3 | Blocker | No rule to find the project, and no writer of `projects.json` | CLI 1, PD1 to PD13, `--file` replaces `--member` |
| 4 | Blocker | basic-cli gaps not listed, no `arm64win` target | Design 6.2, HF1 to HF10, IS2 |
| 5 | Blocker | Output text and `data` fields have no owner, TQ1 to TQ4 open | CLI 3, OUT1 to OUT5, CLI 1 environment variables, Q24 |
| 6 | Serious | "Epoch" has no definition for code | Resolution 4, EP1 to EP9 |
| 7 | Serious | No compiler sha256 before P2 | CLI 6.2, CV1 to CV6 |
| 8 | Serious | Implied range wrong for `0.x` | Design 4.1 "series", Design 4.3 |
| 9 | Serious | Workspace "shared variable" not defined | Design 4.4, WS1 to WS8 |
| 10 | Serious | Two Talon processes at the same time | CLI 7.4, CC1 to CC11, exit code 17 |
| 11 | Serious | Yanks and advisories with no registry | C6, B3, `tln audit` row |
| 12 | Serious | Default registry URL points to nothing before P2 | CLI 1: default `direct` |
| 13 | Minor | `min-release-age` default only in Design 8 | C7 |
| 14 | Minor | `install` with no `talon.toml` against RP3 | RP3 |
| 15 | Minor | Baseline compiler not installed | Resolution 4, DL2 |
| 16 | Minor | `tln patch --commit` diff has no reader | Resolution 7, PA1 to PA6 |
| 17 | Minor | Windows bin dir links | ST1, ST7 to ST11: hard links, no `.cmd` |
| 18 | Minor | No lower bound for nightlies | NS7: `>=<compiler id>` |

Also in round 4: the generic packages move to their own repositories (Design 6.1, GP1 to GP6, Q23), and the registry log records compiler releases from P2 (Registry 3, 7).

Changed after round 4 (2026-10-15), at the request of the user: no fork of basic-cli. Child processes give the effects that basic-cli does not have (Design 6.2, HF1 to HF10): the download adapter for `curl` and `wget` (CLI 7.5, DA1 to DA7), `roc unbundle` for packages (`research/roc-unbundle/`), `tar` for compilers, and lock directories with a heartbeat (CLI 7.4, CC3). Many processes that need one missing compiler still download it once (CC4). New exit code 18 (`environment`). The TTY test is an upstream PR. `min-release-age` defaults to 2 days.
Then: locks have one interface in `Fx` (CC3: `lock!`, `unlock!`, `with_lock!`, a 4-point contract). The lock directory with a heartbeat is its only implementation (CC12), inside the real `Fx`.
Then: the process replacement (`Cmd.exec_replace!`, `execve` on Unix) joins the TTY test in one upstream PR to basic-cli (HF6). Until it is in, the proxy runs roc as a child.
