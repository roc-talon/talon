# 103 Schema: triggers

Phase: P2. Status: review (tests changed for the answers of section 8.1, red, 2026-11-01). Model for the code: Sonnet high. Plan row: `docs/registry/PLAN.md` C.1, row 103, gap G11. Depends on slice 102 (`sql/0001_init.sql`) and slice 101 (the W1 runner).

## 1. Scope

This slice makes the triggers of the D1 schema in one new migration, `sql/0002_triggers.sql`. It ports the tested triggers of the prototypes to the integer tables of slice 102.

| Part | Who | State |
| --- | --- | --- |
| `sql/0002_triggers.sql` | Test agent (a stub with a TODO comment), code agent (the triggers) | The stub is in place. The code agent writes the file from section 3. |
| W1 cases `sql/tests/cases/triggers/t1` to `t6` | Test agent | Done. Red (section 8). The code agent does not edit them (TW18). |
| Runner: `-- batch: N` (RR1), the case file `migrations` (RR2), self-tests (RR3) | The manager | Done (section 6). `t6` uses `batch`. `s4` and `s5` of slice 102 list `0001` in `migrations`. |
| Private reference `research/slice-103-revert/reference/0002_triggers.sql` | Test agent | Passes all cases. The code agent does not read it (TW18). Keep until the review is applied. |

No Roc file changes. The rules are SQL.

## 2. Rules

| Rule | Text (short) | Checked by |
| --- | --- | --- |
| Q27, R-RE2 | Label conflict: the label keeps its first artifact. Same label and same artifact is a no-op. | t1, t5, t6 |
| R-SG8, R-SG2, R-SG3, R-SG5 | The Worker writes the leaf (text columns bound, `time` of the write). A trigger only checks it: `leaf-missing` on `releases` and on `toolchains`. A leaf is written only for a new label or a new compiler asset. | t1, t5, t6 |
| R-MX8, R-MX4, R-RE8 | `BEFORE INSERT` and `BEFORE UPDATE` triggers on `sweeps`: `sweep-bound`, `sweep-incomplete`, `sweep-smaller`. Only a `bot` row counts. The insert trigger checks nothing when the row has a bound at least the new bound (Q83). | t2, t5, t6 |
| R-MX11, R-MX16 | The bot set at a bound for a nightly. The window is 548 days back from t of the nightly, the edge included. | t2 |
| R-MX12, R-RE23, R-MX16 | `AFTER` triggers on `sweeps` write the `transitions` row. The order of nightlies is the date, then t, then the id. | t3 |
| R-CT13, R-RE12, R-RE13 row 3, R-RE24, R-CT4 | `AFTER INSERT` trigger on `contributions`: the hint counts, `first_time` once, `last_time` the largest, and the daily limit `hint-quota`. | t4, t5, t6 |
| R-MX9 | The error text that D1 gives for a `RAISE`, which the Worker maps. | t5 |
| R-IK3 | The primary key text of a `names` collision is not a trigger text. | t5 |
| R-IK7, R-RE6, R-RE7, R-RE13 row 1 | The codes in the conditions (hang 2, crash 3), the rows that change, the key of `sweeps`, the first write of a `compat` key wins. | t2, t3, t4, t6 |

Design refs: Registry 5, 5.1, 6, 6.1, R-SG8, R-MX16, Design Q27, Q79 to Q84, `research/d1-sweep/`, `research/bot-set/`, `research/d1-contrib/`, `research/leaf-text/`, `research/d1-remote/`.

## 3. What the code agent writes

One file: `sql/0002_triggers.sql`. It runs on SQLite (`node:sqlite`) and on local D1, after `0001_init.sql`. Write one statement for each `;`: a trigger ends with `END;`. No `PRAGMA`, no `BEGIN TRANSACTION`. SQLite allows no `WITH` clause in a trigger.

Start from the prototypes `research/d1-sweep/`, `research/bot-set/`, `research/d1-contrib/` and `research/leaf-text/`. Port them with the notes of section 3.2.

### 3.1 The triggers

The names are a proposal (TW24, section 5). The cases do not check a trigger name.

| Trigger | Event | Behavior | RAISE text |
| --- | --- | --- | --- |
| `releases_label_conflict` | `BEFORE INSERT ON releases` | Stop when a row with the same `(form, version, version_text)` and another `artifact` exists. It fires also for `INSERT OR IGNORE` and is not hidden by it. | `label-conflict` |
| `releases_leaf_check` | `AFTER INSERT ON releases` | Stop when no `log` row has `idx = NEW.log_index` and `grp` equal to the `names` value (kind 2) of `NEW.form`. It must be an `AFTER` trigger: an ignored insert fires none, and a `BEFORE` trigger would stop a publish that is sent again (R-SG8 row 5). | `leaf-missing` |
| `toolchains_leaf_check` | `AFTER INSERT ON toolchains` | The same with `grp = 'roc-lang/nightlies:' \|\| NEW.target`, `version = NEW.tag`, `hash = 'sha256:' \|\| NEW.sha256`. | `leaf-missing` |
| `sweeps_guard_insert` | `BEFORE INSERT ON sweeps` | Nothing, when the row of (nightly, target) has a bound at least `NEW.upto_log_index` (Q83). Else `sweep-bound` when the bound is above `MAX(log.idx)` (0 for an empty log), and `sweep-incomplete` when a member of the bot set at the bound (R-MX11) has no `bot` row on (nightly, target). | `sweep-bound`, `sweep-incomplete` |
| `sweeps_guard_update` | `BEFORE UPDATE ON sweeps` | The same two checks (with no skip), and `sweep-smaller` when the new bound is below the old. | `sweep-smaller`, `sweep-bound`, `sweep-incomplete` |
| `sweeps_transitions_insert`, `sweeps_transitions_update` | `AFTER INSERT`, `AFTER UPDATE ON sweeps` | For the swept nightly N and each of its two adjacent nightlies that is swept on the same target: write the `transitions` row with the key of the later nightly, with `INSERT ... ON CONFLICT (nightly, target) DO UPDATE` (R-MX12, Q84). | none |
| `contributions_count` | `AFTER INSERT ON contributions` | Upsert the `compat_hints` row (+1 in `pass_count` for result 0, `fail_count` for 1, `crash_count` for 3). A new row has `first_time` and `last_time` = `NEW.time`. An existing row keeps `first_time`, and `last_time = MAX(last_time, NEW.time)` (Q82). Add 1 to `hint_days.counted` of day `NEW.time / 86400000`. Stop when `counted` is above 200000 (first guess, R-CT13). | `hint-quota` |

There is no trigger that writes a leaf. The Worker sends the leaf statement of R-SG8 row 3 before the release statement. The release statement is `INSERT INTO releases ... SELECT (SELECT MAX(idx) FROM log), ... WHERE NOT EXISTS (same label and artifact)` with no `OR IGNORE` (R-SG8 row 4, Q86); the toolchains statement is the same with `WHERE NOT EXISTS (nightly, target)` (row 6). The cases use these statements. The mutation `or-ignore` (a change of the case statements) fails `t1` and `t6`. The leaf statement takes `MAX` in a subquery (`SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ...`). The aggregate form is wrong (R-SG8): `t1` and `t6` fail with it (mutation `leaf-agg`).

When both `sweep-bound` and `sweep-incomplete` are true, the cases do not check which text comes first. The prototype `research/d1-sweep/` raises `sweep-bound` first.

### 3.2 Port notes

| # | Prototype | Port |
| --- | --- | --- |
| 1 | `withdrawn = 0` (`research/bot-set/`) | `withdrawn IS NULL`. `withdrawn` is TEXT or NULL (slice 102). With `= 0` no release is live and each sweep passes. |
| 2 | `kind` in `bot-set`: package 0, platform 1, app 2 | R-IK7: app 0, package 1, platform 2. A member has `kind IN (1, 2)`. |
| 3 | `result` in `bot-set`: crash 2, hang 3 | R-IK7: hang 2, crash 3. A transition compares only `IN (0, 1)`, so the text does not change. `contributions.result` is 0, 1 or 3. |
| 4 | Times in seconds | Times are ms (R-RE26). The hint day is `NEW.time / 86400000`. The window is `published_at >= t - 47347200000` (548 days; the edge is in; a release after t is in; Q80). |
| 5 | `toolchains` keyed by the nightly alone | One row for each (nightly, target) (R-RE4). t of a nightly is `MIN(published_at)` of its rows. The order is over the distinct nightlies: the date `nightly >> 28`, then t, then the id (R-MX16, Q81). A nightly with no row has no t: no window time, no transition. |
| 6 | `bot-set` has no `sweep-bound` | Add it from `research/d1-sweep/` (R-MX8 lists it). |
| 7 | `INSERT OR REPLACE INTO transitions` in the trigger body | Use `INSERT ... ON CONFLICT (nightly, target) DO UPDATE SET ...` (Q84, finding F1). |
| 8 | Text keys (`hash`, `grp`) | Integer keys (`artifact`, `form`). The label is `(form, version, version_text)`. The key of the series is the `version` bits as in `research/bot-set/schema.mjs` (`>> 48`, `>> 32 & 65535`). |
| 9 | `source = 'bot'` | `source = 0` (R-IK7). |
| 10 | The leaf trigger of `research/d1-sweep/` | None. A check trigger only (`research/leaf-text/`). |

### 3.3 Findings from the test work

| # | Finding | Effect |
| --- | --- | --- |
| F1 | A trigger body `INSERT OR REPLACE INTO transitions` fails with `UNIQUE constraint failed: transitions.nightly, transitions.target` when the sweep statement is an upsert that raises an old bound (the conflict mode of the outer statement overrides the one in the trigger body). | Settled by Q84. `t3` raises a bound (the last two steps). The mutation `or-replace` fails `t3`. |
| F2 | A `BEFORE INSERT` trigger of `sweeps` also fires for the insert part of an upsert, so the guard runs twice for a raise. A direct `UPDATE` reaches only the update trigger. | `t2` has a direct `UPDATE` that needs the check of the update trigger. |
| F3 | After `0002` exists, the cases `s4` and `s5` of slice 102 break: they insert rows by hand. The case `versions/v1-order-bounds-filter` (slice 105) breaks the same way: it inserts `releases` rows with no leaf (`leaf-missing`). | `s4`, `s5` and `v1` list `0001` in `migrations` (done; noted in `docs/slices/105-version-columns.md`). |
| F4 | Local D1 writes a trigger error as `D1_ERROR: <text>: SQLITE_CONSTRAINT (extended: SQLITE_CONSTRAINT_TRIGGER)`. A primary key failure is `D1_ERROR: UNIQUE constraint failed: names.id: SQLITE_CONSTRAINT (extended: SQLITE_CONSTRAINT_PRIMARYKEY)`. On `node:sqlite` the message is the text alone. | `t5` (D1 only) checks both forms. |
| F5 | A release statement `INSERT OR IGNORE ... log_index = (SELECT MAX(idx) FROM log)` is dropped with no error and no trigger when `MAX(idx)` is the `log_index` of an existing release (the primary key conflict), and `OR IGNORE` also drops a row that fails a `CHECK`. | Settled by Q86: no `OR IGNORE`. `t1` has a release with no leaf (`UNIQUE constraint failed: releases.log_index`) and a toolchains row with no leaf (`leaf-missing`). `t6` has a batch with a `CHECK` failure that writes no leaf. `t1` and `t5` also test `leaf-missing` when the newest leaf is a compiler leaf, or with an explicit `log_index`. |

## 4. Tests

Six W1 cases in `sql/tests/cases/triggers/`. Each runs on `node:sqlite` and on local D1 (`t5`: D1 only). The rule ids are in the file `rules` of each case (TW36). Each case ends with `SELECT` blocks that give the rows after all steps. `setup.sql` and `steps.sql` are made by `research/slice-103-revert/gen-cases.py` (the `expect.tsv` files are by hand).

Every hand insert into `releases` and `toolchains` has its `names` row and its leaf first (R-SG8).

| Layer | Case | Checks | Rules |
| --- | --- | --- | --- |
| W1 | `t1-publish` | The publish pair (leaf statement, release statement). 3 new labels. The same label and artifact sent again: no error, no row, no leaf. The same label and another artifact: `label-conflict` (also with `INSERT OR IGNORE`), no leaf. One artifact with two labels. Another `version_text` is another label, and the same text with another artifact is a conflict. A release with no leaf when the newest leaf is a release's leaf: a primary key error, nothing written (no `OR IGNORE`, Q86). A release that names the leaf of another group: `leaf-missing`. A leaf of the right group passes. A compiler leaf and its `toolchains` row; the same tag again writes nothing; a row with no leaf, another hash or another tag gives `leaf-missing`. The next release gets the next index. All leaf columns are checked. | Q27, R-SG8, R-SG2, R-SG3, R-SG5, R-RE2, R-IK5, R-RE8 |
| W1 | `t2-sweep-guard` | The index of `bot-set` B0 (8 releases, a platform, an app, 8 nightlies with 2 `toolchains` rows each, compiler leaves 1 to 16). `sweep-incomplete` for a missing member of a second series, of a group out of the window, of a series after a yank, of a window that reaches back, of a release after a withdrawal, with an author row only, at the edge of the window (a member), after t (a member). A release 1 ms before the edge needs no row. `sweep-bound` on insert and on `UPDATE`. A raise by upsert (the update part). `sweep-smaller` on a direct `UPDATE`. A smaller or equal bound by upsert after a yank adds a member: no error, the row keeps its bound, and the rows of the batch are written (batch). `sweep-incomplete` on a direct `UPDATE`. | R-MX8, R-MX4, R-MX11, R-MX16, R-RE8, R-RE6, R-RE7, R-IK7 |
| W1 | `t3-transitions` | 7 nightlies in an order that is not the order of ids (one `published_at` shared by two; two nightlies of two dates whose t is in the other order). A nightly swept before its neighbour writes no row, and the later sweep writes both rows. `compared` ignores a hang, a crash, a missing row and an author row, and counts hashes outside the bot set. A second target has its own row. A nightly with no `toolchains` row: no row. A bot row that comes later changes no row. A same bound sweep changes nothing. A raise of the bound computes the rows again. | R-MX12, R-RE23, R-MX16, R-MX11, R-IK7, R-RE7 |
| W1 | `t4-hint-quota` | The day 20000 has counted 199996. 4 rows pass. The next is `hint-quota` and writes nothing. A two-row statement with one row on the next day and one over the limit: all undone. The last millisecond of the day is still the day. The first millisecond of the next day passes. `ON CONFLICT DO NOTHING` skips a row and counts nothing. Another `talon_version` is another `compat_hints` row. A crash counts in `crash_count`. A hint with a `time` below the stored `first_time`: `first_time` and `last_time` do not change. | R-CT13, R-RE12, R-RE13 row 3, R-CT4, R-RE24, R-IK7, R-RE6 |
| W1 (D1) | `t5-d1-error-text` | The whole D1 error text of `label-conflict`, `leaf-missing` (release and toolchains), `sweep-incomplete`, `sweep-bound`, `sweep-smaller`, `hint-quota`, and of a `names.id` collision. | R-MX9, R-MX8, R-SG8, R-CT13, R-IK3 |
| W1 | `t6-batch-rollback` | Batches (`-- batch: N`): names, leaf, release of a new label with a conflicting label: nothing written, no names row, no leaf. The same batch with the new label: written. Bot rows and an incomplete sweep (no row written), then with the missing row (rows and sweep written). A used `compat` key in a batch: the first write wins, no error. A batch with a release that fails a `CHECK`: nothing written, no leaf. A hint batch over the limit (nothing written). | R-MX8, Q27, R-SG8, R-CT13, R-CT4, R-RE13 row 1 |

Coverage: `MISSING=1 scripts/rules.sh R-MX R-RE R-CT R-SG R-IK` shows no id of section 2 as missing (R-SG8 is named in `t1`, `t5`, `t6`).

W1 time with the reference: 41 runs in about 6 s. The budget is 15 s.

## 5. Output (proposed, TW24)

No human text. The trigger names and the RAISE texts:

| Item | Proposal | Source |
| --- | --- | --- |
| RAISE texts | `label-conflict`, `leaf-missing`, `sweep-bound`, `sweep-incomplete`, `sweep-smaller`, `hint-quota` | The design gives all six (Q27, R-SG8, R-MX8, R-CT13) |
| Trigger names | `releases_label_conflict`, `releases_leaf_check`, `toolchains_leaf_check`, `sweeps_guard_insert`, `sweeps_guard_update`, `sweeps_transitions_insert`, `sweeps_transitions_update`, `contributions_count` | The prototypes. The design names none. |
| Text priority | When `sweep-bound` and `sweep-incomplete` are both true: `sweep-bound` first | `research/d1-sweep/`. Not tested. |

## 6. Runner requests

Done by the manager: `-- batch: N` (RR1), the case file `migrations` (RR2), and the self-tests (RR3: `selftest/batch-*`, `selftest/migrations-*`). `t6` uses `batch`. `s4` and `s5` of slice 102 have a file `migrations` with `0001`. No new request.

## 7. Out of scope

| Item | Reason |
| --- | --- |
| The Worker statements (the publish batch, the sweep upsert, the hint batch) | Slices 112, 115, 116. The cases use the statement forms of R-SG8, R-MX8, R-CT4 and Q27, but the Worker text is not fixed here. |
| The member query and the missing list (`GET /v1/sweeps/{tag}`, 100 hashes) | Slice 115. One SQL text should serve the trigger and the route (R-MX8). This slice has only the trigger. |
| `sweep-bound` as 400, `sweep-incomplete` as 422, `leaf-missing` as 500 | The mapping is Worker code (R-MX9, slice 115). `t5` checks the text the mapping reads. |
| Remote D1 (the same error text) | W3, only when the user asks. `research/d1-remote/` measured it. |
| The base58 of a hash, `Semver.to_str` | The Worker makes the leaf text (R-SG8). The cases use stand-in texts. |
| The trim, the login move, the daily cron delete of `hint_days` | Slices 116 and 119. They are statements, not triggers. |
| `yanks` table and its trigger | P3 (Design Q55) |
| The W2 runner `worker/tests/run.mjs` | It applies the migration files too. A later W2 case that writes `releases`, `toolchains`, `sweeps` or `contributions` sees the triggers and needs leaves. |
| Speed of the guard (14 ms at 20,000 releases) | Measured in `research/bot-set/bench.mjs`. No W1 case. |

## 8. Questions (answered 2026-11-01; the tests follow 8.1)

| # | Question | Options | Effect |
| --- | --- | --- | --- |
| Q103-1 | What does the leaf trigger write in `log.grp`, `log.version`, `log.hash` and `log.time`? R-IK1 says the log keeps the text forms: the URL form of the group, the version as `X.Y.Z`, the hash in base58. `releases` has only ids, a version key and a `version_text` that is empty for an exact key. A trigger cannot make base58, and the `X.Y.Z` of a key only with long SQL. | (a) The trigger writes ids as text or hex, and the Worker or the tile writer (R-SG7) maps them. This breaks R-IK1 ("a leaf must not depend on an id"). (b) No trigger. The Worker sends a second statement `INSERT INTO log ... SELECT ... WHERE changes() > 0` after the release insert, with the texts as parameters. The leaf is still written only with a new release. (c) A staging table that the Worker fills. | The code agent cannot write `releases_leaf` until the human chooses. `t1` checks only `idx` and the count of the leaves, so it holds for (a), and for (b) the case needs the statement of (b) in `steps.sql`. `time`: `published_at` of the release or the time of the write? The same question. The reference uses a stand-in and the cases insert no `names` row. |
| Q103-2 | What is "18 months" in ms? The prototype uses 548 days. | 548 days, or 18 calendar months from the `published_at` of the nightly | The cases keep each release that matters at least 250 days from the edge of the window (`t2`: A4 is 252 days outside for the nightly 1). Add one case at the edge when the human decides. |
| Q103-3 | The order of nightlies uses one `published_at` for each nightly (R-NS1), but `toolchains` has a `published_at` for each (nightly, target) row (R-RE4). Do all rows of a nightly have the same `published_at`? A nightly with no row in `toolchains` has no window. | Assume equal (the rows come from one GitHub release), and take `MIN`. | The cases give equal values. The reference takes `MIN(published_at)` for each nightly. |
| Q103-4 | `compat_hints.first_time` and `last_time` for a row that is older than the stored `first_time`: `MIN` and `MAX`, or the first and the last write? | `MIN` and `MAX`, or first write and last write (the prototype) | The cases write the rows in time order, so both give the same rows. |
| Q103-5 | A sweep upsert with a bound that is not larger than the row, after a yank has changed the set at that bound. R-MX4 says such a sweep "changes nothing, with no error". The `BEFORE INSERT` guard (the insert part of the upsert) would raise `sweep-incomplete`. | Keep the guard (the prototype): a retry with an old bound can fail after a yank. Or skip the check when a row exists with a bound at least the new bound. | `t2` sends a smaller bound only when the set did not change. |

These five are settled in section 8.1.

### 8.1 Answers (design agent, 2026-11-01)

| # | Answer | Rule |
| --- | --- | --- |
| Q103-1 | No leaf trigger. The Worker binds the leaf text and sends the leaf statement before the release statement. The release takes `(SELECT MAX(idx) FROM log)`. An `AFTER INSERT` trigger on `releases` and on `toolchains` raises `leaf-missing` when the leaf of `NEW.log_index` is not there. `time` is the time of the write. | Registry R-SG8, Design Q79 |
| Q103-2 | 548 days = 47,347,200,000 ms, back from t of the nightly. `published_at >= t - 47347200000` is in the window (the edge too, and a release after t). | Registry R-MX11 row 3, Design Q80 |
| Q103-3 | Yes, equal. Take `MIN(published_at)`. The order is `nightly >> 28` (the date), then t, then the id. Port note 5 ("t, then the id") changes to this. A nightly with no row: no window time, no transition. | Registry R-MX16, Design Q81 |
| Q103-4 | `first_time` is set once, at the insert of the row. `last_time = MAX(last_time, NEW.time)`. | Registry R-RE12, Design Q82 |
| Q103-5 | No error. The `BEFORE INSERT` trigger checks nothing when the row has a bound at least `NEW.upto_log_index`. | Registry R-MX8, Design Q83 |
| F1 | The design named no `INSERT OR REPLACE`. R-MX12 now names `ON CONFLICT (nightly, target) DO UPDATE`, and R-MX8 forbids `INSERT OR REPLACE` on `sweeps`. | Registry R-MX12, R-MX8, Design Q84 |

### 8.2 Test changes (test agent). TC1 to TC9 are applied: see section 4 and section 10.3

| # | Case | Change | Rule |
| --- | --- | --- | --- |
| TC1 | `t1-publish` | Insert a `names` row (kind 2) for each form. Before each release statement, send the leaf statement of R-SG8 row 3 with the texts as parameters, and give the release `(SELECT MAX(idx) FROM log)`. Check all leaf columns (`grp`, `version`, `hash`, `time`), not only `idx` and the count. Add: a release with no leaf statement gets `leaf-missing` and writes nothing. The step "a used `log.idx`" becomes a release whose `log_index` names a leaf of another group: `leaf-missing`. | R-SG8, R-SG2, R-SG5, Q27 |
| TC2 | `t1-publish` or a new case | A `toolchains` row with its compiler leaf (R-SG8 row 6) passes. A row whose leaf has another `hash` or `version` gets `leaf-missing`. The same tag sent again writes no leaf and no row. | R-SG8, R-SG3, R-PU9 |
| TC3 | `t2`, `t3`, `t5`, `t6` setups | Each hand insert into `releases` or `toolchains` now needs its `names` row and its leaf first, with the check texts (R-SG8 row 5). | R-SG8 |
| TC4 | `t6-batch-rollback` | The publish batch is names, leaf, release. A batch with a new label and a conflicting label writes no leaf. | R-SG8, Q27 |
| TC5 | `t2-sweep-guard` | Add a window edge: a release with `published_at` exactly t - 47347200000 is a member, and one at t - 47347200001 is not (only when it is not the newest of its group). Add a release published after t: a member. | R-MX11, R-MX16 |
| TC6 | `t2-sweep-guard` | Add: a complete sweep at bound B, then a yank that adds a member at B, then the same upsert with bound B and with a smaller bound. No error, the row keeps B, and the matrix rows of the request are written. | R-MX8, R-MX4 |
| TC7 | `t3-transitions` | Add 2 nightlies of 2 dates whose t is in the other order (the earlier date has the larger t). The order is by the date. Optional: a nightly with no `toolchains` row gets no transition. | R-MX16, R-MX12 |
| TC8 | `t4-hint-quota` | Add a hint with a `time` below the stored `first_time` and `last_time`: `first_time` and `last_time` do not change. | R-RE12 |
| TC9 | Mutations | Add: the aggregate form of the leaf statement (R-SG8), the check as a `BEFORE` trigger (fails a publish sent again), no skip in the insert guard (TC6), the window in calendar months or with `>` (TC5), order by t then id (TC7), `MIN(first_time, NEW.time)` (TC8). Keep the total near the user rule of 5 to 10 tricky ones. | |

Section 3.1 changes: `releases_leaf` is now a check (`AFTER INSERT ON releases`, RAISE `leaf-missing`), and a new `toolchains_leaf` check. Section 5 adds the RAISE text `leaf-missing` (the design gives it, R-SG8).

## 9. Disputes (from the code agent)

None.

## 10. Verify results

### 10.1 Red (the stub `sql/0002_triggers.sql`, the runner of `sql/tests/`)

`node sql/tests/run.mjs`: 30 passed, 11 failed. The 11 are the new runs (`t1` to `t4` and `t6` on both backends, `t5` on D1). All old cases pass (`example`, `schema/s1` to `s5`, `versions/v1`, `selftest`). Failure texts:

| Case | Failure |
| --- | --- |
| `t1-publish` | `expected an error with "label-conflict", got none` (2 steps), `"leaf-missing", got none` (3 steps), rows of `releases`, `log` and `toolchains` differ |
| `t2-sweep-guard` | `expected an error with "sweep-incomplete", got none` (many), `sweep-bound`, `sweep-smaller`; the rows of `sweeps` differ |
| `t3-transitions` | `transitions` has no row; the rows of `sweeps` differ |
| `t4-hint-quota` | 3 steps with no `hint-quota`. `compat_hints` is empty. `hint_days` has 199996. |
| `t5-d1-error-text` (D1) | 8 steps with no error, or an error of another text (the `names.id` step passes: the table gives it) |
| `t6-batch-rollback` | `label-conflict`, `sweep-incomplete` and `hint-quota` batches do not fail, and rows differ |

### 10.2 Reference (private)

`research/slice-103-revert/reference/0002_triggers.sql` (made by `gen-ref.mjs`): all 11 runs of `triggers/` pass, and the old cases pass, except `versions/v1-order-bounds-filter` (F3): 39 passed, 2 failed (`v1` on both backends). Run it with `research/slice-103-revert/run-ref.sh`.

### 10.3 Revert check (hand mutations of the reference, `research/slice-103-revert/mutate.sh`)

16 mutations of the reference (and of the leaf statement in the cases for `leaf-agg`). All are caught. Each name is a `MUTATE` value of `gen-ref.mjs`.

| Mutation | What | Caught by |
| --- | --- | --- |
| `leaf-agg` | The aggregate form of the leaf statement (R-SG8; a change of the case statements) | t1, t6 |
| `or-ignore` | `INSERT OR IGNORE` in the release statement (Q86; a change of the case statements) | t1, t6 |
| `leaf-check-before` | The leaf check as a `BEFORE` trigger (fails a publish sent again) | t1, t6 |
| `no-skip` | No skip in the insert guard (Q83, TC6) | t2 |
| `window-gt` | The window with `>` (the edge is out) | t2 |
| `window-edge-1` | The window 1 ms longer (A13 becomes a member) | t2 |
| `order-t-id` | The order of nightlies by t then id, with no date | t3 |
| `first-min` | `first_time = MIN(first_time, NEW.time)` | t4 |
| `last-new` | `last_time = NEW.time` | t4 |
| `withdrawn-eq0` | The prototype form `withdrawn = 0` | t2, t5, t6 |
| `or-replace` | F1 | t3 |
| `author-counts` | An `author` row completes a sweep | t2 |
| `crash-is-2` | The prototype code for a crash | t3, t4 |
| `day-seconds` | `time / 86400` | t4, t5, t6 |
| `cap-ge` | `counted >= 200000` | t4 |
| `label-no-text` | The label conflict ignores `version_text` | t1 |

A second run of 14 more (run again after the answers of section 8.1) also caught all: `noseries`, `nowindow`, `allhash`, `no-newest-of-form`, `apps-count`, `no-bound`, `no-smaller`, `no-update-guard`, `no-next`, `faults`, `order-by-id`, `no-quota`, `no-label-trigger`, `no-leaf-check`.

### 10.4 Green (code agent, 2026-11-01)

File: `sql/0002_triggers.sql` (8 triggers, the names of section 3.1). It uses `ON CONFLICT ... DO UPDATE` (Q84) and no `INSERT OR REPLACE`. The code agent did not read the private reference and did not edit a test or a case.

| Check | Result |
| --- | --- |
| `node sql/tests/run.mjs` | 41 passed, 0 failed (first run) |
| `scripts/test.sh w0 w1 w2 check` | w0 pass 1.7 s (budget 10), w1 pass 6.8 s (15), w2 pass 11.6 s (45), check pass 2.3 s (10) |
| `MISSING=1 scripts/rules.sh R-SG R-MX R-RE R-CT` | No id of section 2 is missing. The ids with 0 tests are outside this slice: R-CT1, R-CT2, R-CT5 to R-CT12, R-CT14, R-CT15, R-MX1 to R-MX3, R-MX6, R-MX7, R-MX10, R-MX13, R-MX14, R-RE10, R-SG4, R-SG7 |

Decisions that the slice does not fix:

| Decision | Choice | Rejected |
| --- | --- | --- |
| Text priority when `sweep-bound` and `sweep-incomplete` are both true | `sweep-bound` first (the prototype, section 5) | none |
| Transition SQL | The same two statements in the insert trigger and in the update trigger (SQL has no shared text) | A view (slice 102 says no view) |
| Previous and next nightly | A `GROUP BY nightly` subquery in `FROM` with `ORDER BY` date, t, id and `LIMIT 1` | `WITH` (not allowed in a trigger) |
| Series test | The `>> 48` and `>> 32 & 65535` bits of `research/bot-set/schema.mjs`, major 0 as -32768 | none |

Revert check: not run by the code agent. The test agent ran 30 mutations of the reference (section 10.3), all caught. No dispute.
