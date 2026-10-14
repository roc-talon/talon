# CLI design audit

Audit of the `tln` CLI in `DESIGN.md` (Draft 2, 2026-10-13). Line numbers point to Draft 2 before the fixes.

Each group is one work item. A group changes `DESIGN.md` only. Status: all 24 points are fixed in Draft 3 (2026-10-14).

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
