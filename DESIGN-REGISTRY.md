# Talon design: registry

Part of the Talon design. This file holds the registry on Cloudflare and the Worker host that runs it. `DESIGN.md` has the goals, the core model and the list of files.

A reference such as CLI 6.2 is section 6.2 of `DESIGN-CLI.md`. Design, Resolution and Registry name `DESIGN.md`, `DESIGN-RESOLUTION.md` and `DESIGN-REGISTRY.md`. A plain number is a section of this file.

## 1. Role

| # | The registry does | The registry does not |
| --- | --- | --- |
| R-RL1 | Index releases: labels, hash, URL, deps, platform, kind | Store package bytes (v1) |
| R-RL2 | Map hash to labels | Own package names (GitHub does) |
| R-RL3 | Hold the shared compatibility matrix | Run untrusted Roc code inside the Worker |
| R-RL4 | Record publish provenance | Act as a single point of failure: `TALON_REGISTRY=direct` or `--registry direct` uses the GitHub API (precedence in CLI 1, rules in CLI 7.3). `direct` is also the built-in default until the registry runs (P2). |

## 2. Architecture

```mermaid
flowchart LR
    CLI["tln"] --> W["Worker<br/>JS shim + Roc wasm32"]
    W --> CA["Cache API<br/>immutable responses"]
    W --> D1["D1<br/>releases, artifacts,<br/>compat, log leaves"]
    W --> R2["R2<br/>log tiles, checkpoints (P3)"]
    GH["GitHub<br/>OIDC, webhooks, assets"] --> W
    BOT["compat bot<br/>GitHub Actions"] -->|OIDC| W
```

## 3. Storage choice

R-SG1: The registry keeps its data in D1 rows and a log table, not in one Durable Object for each package (Draft 1). The reasons:

| Need | DO per package | D1 rows + log table |
| --- | --- | --- |
| Closure query across many packages | One DO call per package | One SQL query (recursive CTE) |
| Publish = insert version + append log leaf, atomically | Two objects, no shared transaction | One transaction |
| Unique (group, version) | Per object | `UNIQUE` index |
| Write rate | Scales per package. Not needed: Roc has tens of releases per day. | One writer is enough |
| Global reads | Each DO lives in one region | Read replicas (Sessions API) plus the Cache API |
| Backups | Manual | Time Travel (30 days) |
| Size limit | 10 GB per object | 10 GB per database. About 5 M versions at 2 KB each. |

Merkle log:

| # | Part | Where | Why |
| --- | --- | --- | --- |
| R-SG2 | Leaves `(index, group, version, hash, time)` | D1 table, written in the publish transaction | The log and the index cannot disagree |
| R-SG3 | Compiler leaves, from P2 | Same table and form. One leaf for each asset of a compiler release: group `roc-lang/nightlies:<target>` (CLI 6.2, R-CV2), version the tag, hash `sha256:<hex>`. Written in the same transaction as the `toolchains` row (section 5). | `--snapshot log:N` then fixes the set of compilers too (Resolution 11) |
| R-SG4 | Tiles and signed checkpoint (P3, Design Q55) | R2, write-once objects (C2SP tlog-tiles layout) | Tiles are immutable, so object storage plus the edge cache fits. This is how Sunlight serves CT logs. The signing key, its algorithm and its setting name are given when P3 starts. |
| R-SG5 | Sequencing | The D1 transaction (`index = max + 1`) | No separate sequencer at this write rate |

R-SG6: KV is not used: eventual consistency (about 60 s) is wrong for the version list. Package bytes on R2 stay a phase 3 option (hash-keyed mirror).

R-SG7: Tile writer (Q26), P3 (Design Q55). P2 writes the leaves in D1 only (R-SG2, R-SG3, R-SG5). One idempotent step writes the tiles and the checkpoint: "build the tiles and sign up to the largest leaf index in D1". It runs after each publish (in the work after the answer, `Response.after`, `cloudflare-workers/API.md` 10.2, R-PU1) and from the cron job "Tile catch-up" (R-PU35). So 2 publishes in 2 isolates, or an R2 write that fails after the D1 commit, need no other path.

| # | Rule |
| --- | --- |
| 1 | The step reads the size S of the checkpoint in R2 (with its etag) and the leaves above S from D1, in one D1 call |
| 2 | It writes the tiles first, then the checkpoint. So a checkpoint never names a tree whose tiles are not in R2. |
| 3 | A tile is a function of the leaves, which never change (R-RE6). So 2 runs that write one tile write the same bytes, and a second write is harmless. A full tile and each partial tile width have their own path (C2SP tlog-tiles), so no write changes the bytes of a path that a reader can have. |
| 4 | The checkpoint write is an R2 conditional `put` with `onlyIf: { etagMatches }` of the etag from row 1, and only to a larger size. When the etag changed, another run wrote a checkpoint: the step reads it again, and stops if its size is at least the size that the step wanted to write. |
| 5 | A step that fails leaves the work due: the largest leaf index in D1 stays larger than the checkpoint size, so the next catch-up run does it (R-PU35) |

Tests: 2 publishes at the same time in Miniflare give one checkpoint with both leaves and no lost tile. A step that stops after the tiles and before the checkpoint is repaired by the next catch-up run. A checkpoint `put` with an old etag does not write. Revert that must fail: a plain `put` of the checkpoint lets the smaller size win.

R-SG8: Who writes a leaf (Design Q79). The Worker computes the text of each leaf and binds it into the leaf statement. A trigger only checks it. Reasons: a leaf holds text forms (R-IK1), and SQL cannot make the base58 of a hash. One Roc function then makes the leaf of a release and of a compiler asset (R-SG3), and the tile writer (R-SG7) hashes the text columns as they are, with no read of an id.

| # | Rule |
| --- | --- |
| 1 | The text: `grp` is the URL form of the group (R-AP15), the same text as the `names` value of `releases.form`. `version` is `Semver.to_str` of the version (R-IK5), `X.Y.Z` for a release. `hash` is the base58 of the hash. A compiler leaf has the forms of R-SG3. |
| 2 | `time` is the time of the write (`Time.now_ms!`, Design Q64), not `published_at`. Reason: the leaf says when the log took the label. An ingest of an old release has an old `published_at`, and the release row keeps it (R-RE2). |
| 3 | The publish batch (R-PU1) sends the leaf statement before the release statement, and after the `names` rows (R-IK3): `INSERT INTO log (idx, grp, version, hash, time) SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?, ?, ?, ? WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ? AND version = ? AND version_text = ?)`. So the leaf is written only for a new label (Design Q27). |
| 4 | The release statement is `INSERT INTO releases (log_index, ...) SELECT (SELECT MAX(idx) FROM log), ... WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ? AND version = ? AND version_text = ? AND artifact = ?)`, with no `OR IGNORE`. For a new label, `MAX(idx)` is the leaf of row 3. The same label with the same artifact is skipped by the `WHERE`. The same label with another artifact is inserted, and the trigger `label-conflict` (Q27) stops it. Reason for no `OR IGNORE` (Design Q86): `OR IGNORE` also drops a row whose `log_index` is already used (a leaf that row 3 did not write) and a row that fails a `CHECK`, with no error. Then the batch writes nothing and answers as a success. With no `OR IGNORE` each such case is an error, and the batch rolls back. |
| 5 | An `AFTER INSERT` trigger on `releases` calls `RAISE(ABORT, 'leaf-missing')` when no `log` row has `idx = NEW.log_index` and `grp` equal to the `names` value of `NEW.form`. An `AFTER INSERT` trigger on `toolchains` does the same with `grp = 'roc-lang/nightlies:' \|\| NEW.target`, `version = NEW.tag` and `hash = 'sha256:' \|\| NEW.sha256`. A skipped insert (row 4 `WHERE`) fires no `AFTER` trigger. A `BEFORE` trigger would fire for it and stop a publish that is sent again. |
| 6 | Compiler leaves (R-SG3, R-PU9) use the same 2 statements: the leaf `WHERE NOT EXISTS (SELECT 1 FROM toolchains WHERE nightly = ? AND target = ?)`, then `INSERT INTO toolchains (..., log_index) SELECT ..., (SELECT MAX(idx) FROM log) WHERE NOT EXISTS (SELECT 1 FROM toolchains WHERE nightly = ? AND target = ?)`, with no `OR IGNORE` (row 4), one pair for each asset. |
| 7 | The Worker maps `leaf-missing` to 500 `internal` (R-MX9): it is a bug of the batch, not of the request. |

The leaf statement takes `MAX` in a subquery. The form `SELECT COALESCE(MAX(idx), 0) + 1, ... FROM log WHERE NOT EXISTS (...)` is wrong: an aggregate with no `GROUP BY` gives one row also when the `WHERE` is false, so it writes a leaf for a label that exists.

| Option | Why not |
| --- | --- |
| The trigger writes ids (as text or hex), and a later step maps them | A leaf must not depend on an id (R-IK1) |
| The leaf statement after the release, with `WHERE changes() > 0` | The statement then depends on the statement just before it, and nothing in the database checks that a release has its leaf. A Worker bug gives a release with no leaf, and then the next release takes its `log_index` and `INSERT OR IGNORE` drops it with no error. |
| A staging table that the Worker fills and a trigger copies | One more table and one more delete for each publish, for the same result |

Test: `research/leaf-text/` (8 cases and 3 mutations, `node:sqlite`). Revert that must fail: the aggregate form of the leaf statement, and the check as a `BEFORE` trigger.

## 4. HTTP API

The API is plain HTTP with JSON, not full REST. Each resource name is a plural noun, and it is the name of its D1 table (section 5): `artifacts`, `releases`, `compat`, `compat_hints`, `sweeps`, `toolchains`, `contributors`. `packages` is a GitHub name (Design 4.1, R-ID3). `tokens` has no table, because the Worker stores no token (6.1, R-CT9). `me` names the contributor or the account of the request. Paths have no verbs. `POST /v1/closure` is a query with a body, and it changes no state. The log routes are outside `/v1`, because C2SP tlog-tiles sets their layout.

| # | Method and path | Request | Response | Success | Errors (section 4.2) | Caching |
| --- | --- | --- | --- | --- | --- | --- |
| R-AP1 | `GET /v1/packages/{owner}/{repo}/releases` | | `{releases, checked, repos}`: each release (R-RE2) of each group of the repository, in all series and URL forms (CLI 7.3, R-DI6). `checked`: R-AP29, R-AP53. `repos`: R-AP32. The owner and the repo are case-insensitive (R-AP56). | 200, 304 | 404 `not-found`: the repository has no indexed release | `max-age=60`, ETag. No purge across colos: a write drops the entry in its own colo (R-AP43, R-AP69). |
| R-AP2 | `GET /v1/artifacts/{hash}` | | `{artifact, releases, repos}`: the artifact record (R-RE1), all its releases (R-RE2), and `repos` (R-AP32) (R-AP53) | 200, 304 | 404 `not-found`: no artifact has the hash, also when the text is not a hash (R-AP56) | `max-age=60`, ETag. Not immutable: a new label or a yank changes the answer. |
| R-AP3 | `POST /v1/closure` | Body of R-AP16 | Answer of R-AP17 | 200 | 400 `bad-request`, 413 `too-large` (R-AP46) | `no-store`. One round trip per resolve, and at most one more for the second search of a held move (R-AP16). The client keeps the second answer and uses it for each later search of the command (Design Q466). |
| R-AP4 | `GET /v1/artifacts/{hash}/compat` | | `{runs, hints}`: the matrix rows (R-RE3) of the hash on all compilers as runs (R-AP17), and the `compat_hints` rows (R-RE12) of the hash, added up over the Talon versions | 200, 304 | 404 `not-found`: no artifact has the hash, also when the text is not a hash (R-AP56, R-AP67) | `max-age=300`, ETag |
| R-AP5 | `GET /v1/toolchains?after=<log_index>`, optional `&target=<target>` (R-AP47) | | `{toolchains, more}`: the rows of R-RE4 with a larger log index, in log index order, at most 1000 (first guess). With `target`, only the rows of that target. `more` is true when there are more rows after the page. With no `after`, the first page (`after=0`). | 200, 304 | 400 `bad-request` | `max-age=300`, ETag |
| R-AP6 | `PUT /v1/toolchains/{tag}` | No body. The OIDC token of the compat bot (R-PU7). | `{toolchains}`: the rows of the tag (R-AP49), in log index order. The steps: R-AP57. | 201: new rows. 200: the tag has rows (R-PU9, R-PU10). | 401 `unauthenticated`, 403 `forbidden`, 404 `not-found` (GitHub has no such release), 422 `not-a-candidate` (no asset passes R-CV1 and R-CV2), 502 `upstream` | `no-store` |
| R-AP7 | `GET /v1/packages?q=<text>`, or `GET /v1/packages?short=<name>` (section 4.3) | | With `q`: `{packages}`, ranked packages for display only (R-SN5). With `short`: `{matches}`, the exact match set of a short name (R-SN1 to R-SN4). | 200, 304 | 400 `bad-request`, 413 `too-large` (R-AP46) | `q`: `max-age=300`, ETag. `short`: `max-age=60`, ETag. |
| R-AP8 | `POST /v1/releases` with `Authorization: Bearer <GitHub OIDC token>`: a publish (R-PU2) | `{url, compat}`: the asset URL, and the real facts of the released hash (R-PU5, optional; the form: R-AP71) | The release record (R-RE2) and its log index | 201 with `Location: /v1/artifacts/{hash}`: new release. 200: the label exists with the same hash. | 400 `bad-request`, 401 `unauthenticated`, 403 `forbidden` (the token check of R-PU1 fails), 403 `repository-changed` (R-TP3 row 5, R-TP12), 409 `label-conflict`, 409 `id-collision` (R-IK3), 413 `too-large` (R-AP46, R-AP71), 422 `not-a-candidate` (R-PU6), 502 `upstream`. The order and the details: R-AP75. | `no-store` |
| R-AP9 | `POST /v1/releases` with no `Authorization`: an ingest (R-PU4) | `{url}` | As R-AP8 | As R-AP8. An ingest never answers 202 (Design Q62). | As R-AP8, and 401 `unauthenticated` (R-AP26), 429 `rate-limited` (R-PU34). The order and the details: R-AP68. | `no-store` |
| R-AP10 | `POST /v1/compat` | `{rows, sweep}`. `rows`: a list of `{hash, nightly, target, result, error_digest}`. A user hint row has no `error_digest` (R-CT2). `sweep`: `{nightly, target, upto_log_index}`, optional, bot only (R-MX4). The OIDC token of the compat bot, or no token for user hints (R-MX5). A user hint request also has the header `Talon-Contributor` and the body field `talon_version` (6.1, R-CT1, R-CT2). The checks of the bot path and their order: R-AP66. Of the hint path: R-AP70. The types of the hint request and the answers: R-AP72. | `{written}`: the count of new `compat` rows, or of counted hints (R-RE13). For user hints also `first` (R-CT4) and `skipped` (R-CT14). | 201: at least one row is new. 200: each row was there (R-RE13 row 1), or each row was there already for this contributor (R-CT4). | 400 `bad-request`, 401 `unauthenticated`, 403 `forbidden`, 404 `not-found` (a bot row with a hash that is not indexed), 413 `too-large` (R-AP46), 422 `sweep-incomplete` (R-MX4, R-MX9), 429 `rate-limited` (R-CT11, R-CT13) | `no-store` |
| R-AP11 | `GET /log/checkpoint`, `GET /log/tile/...` (hash tiles, entry tiles and partial tiles, in the C2SP tlog-tiles layout). P3 (Design Q55). | | From R2 | 200 | 404 `not-found` | Checkpoint: `max-age=5` (first guess, tune in P2). Tiles, also partial tiles: `max-age=31536000, immutable`. |
| R-AP12 | `POST /v1/webhooks/github` | A GitHub App event, signed with HMAC-SHA256 (`X-Hub-Signature-256`). Rules: R-PU3, R-PU11 to R-PU18, and the order of the checks in R-AP79. | No body | 202 | 401 `unauthenticated`: the signature is bad | `no-store` |
| R-AP13 | `GET /v1/releases?group=<URL form>`, optional `&series=<series>` | | `{releases, checked, repos}`: the releases (R-RE2) of that group. With no `series`, all series of the URL form (CLI 7.3, R-DI6). The group can be on any host, also not `github.com` (CLI 7.3, R-DI11). `checked`: R-AP29, one item or `null` (R-AP53). `repos`: R-AP32. A group with no release is 200 with empty lists. | 200, 304 | 400 `bad-request` (R-AP56) | `max-age=60`, ETag. No purge across colos: a write drops the entry in its own colo (R-AP43, R-AP69). |
| R-AP14 | `GET /v1/releases?after=<log_index>` | | `{releases, repos}`: the releases with a larger log index, in log index order, at most 1000 (first guess, tune in P2). `repos`: R-AP32. For the next page, the client asks again with the last log index of the page. A page after the last release is 200 with empty lists. `after` and `group` can go together: the answer then has the form of R-AP13 (R-AP53). With no `group` and no `after`, the answer is 400 (R-AP56). | 200, 304 | 400 `bad-request` (R-AP56) | `max-age=60`, ETag |
| R-AP35 | `GET /v1/contributors/me` | `Authorization: Bearer <JWT>` (6.1, R-CT9) | The tracker of the account (R-CT10) | 200 | 401 `unauthenticated`: no JWT, or a JWT that fails R-CT9 | `no-store` |
| R-AP36 | `DELETE /v1/contributors/me` | The JWT (the account), or `Talon-Contributor` with no JWT (one machine) (R-CT7) | No body | 204, also when nothing was stored | 400 `bad-request`, 401 `unauthenticated`, 429 `rate-limited` | `no-store` |
| R-AP37 | `POST /v1/tokens` | `{github_token}`: a token of the OAuth App `Talon` (R-CT8). `Talon-Contributor`, optional. | `{token, expires_at, account: {id, login}}`. `token` is the JWT of R-CT9. | 201 | 400 `bad-request`, 401 `unauthenticated` (GitHub refuses the token), 429 `rate-limited`, 502 `upstream` | `no-store` |
| R-AP38 | `DELETE /v1/tokens` | The JWT | No body. Each token of the account stops (R-CT9). | 204 | 401 `unauthenticated` | `no-store` |
| R-AP39 | `GET /v1/sweeps/{tag}`, optional `?target=<target>` (default `any`) | | `{sweep, log_size, members, missing}`: the `sweeps` row of the nightly and target or `null`, the log size now, the count of members of the bot set at that log size (R-MX11, a member is a hash), and the hashes of the members that have no `bot` row. The work list of the bot (R-MX1). `target` is `any` or absent (R-AP67). | 200 | 400 `bad-request`, 404 `not-found` (no such tag in `toolchains`) | `no-store` |
| R-AP40 | `GET /v1/compat_hints?audit=<n>` | | `{pairs}`: at most `n` (at most 1000) pairs `{hash, nightly, target, pass_count, fail_count, crash_count}` that have `compat_hints` rows and no `bot` row, with the largest total count first (the order of equal totals: R-AP67). Only unit checks (target `any`) and platform targets. The work list of the hint audit (R-MX13). `audit` is required (R-AP67). | 200, 304 | 400 `bad-request` | `max-age=300`, ETag |

R-AP15: A group goes on the wire as two fields. `group` is its URL form: the group with no series (CLI 7.3, R-DI6), with `{v}` in place of the version and with no scheme and no hash, as in Design 4.1, R-ID2 (`github.com/roc-lang/unicode/releases/download/{v}/`). `series` is the series of Design 4.1, R-ID1 (`4`, `0.25`).

R-AP53: The answers of the release reads (Design Q87, Q92, Q97). Each list has the order of this table, so that 2 answers of one state have the same bytes and the same ETag (R-AP54):

| Route | Answer | `checked` | Lists |
| --- | --- | --- | --- |
| R-AP1 | `{releases, checked, repos}` | One item `{name, checked_at, stale}` (R-AP29) for the repository | `releases` in rising `log_index`. `repos` sorted by `name` (bytes). |
| R-AP13, and R-AP14 with `group` | `{releases, checked, repos}` | One item for the `github.com` repository of the group. `null` when the group is on another host, or the answer has no release. | As R-AP1 |
| R-AP14 with no `group` | `{releases, repos}` | No member | As R-AP1 |
| R-AP2 | `{artifact, releases, repos}` | No member | As R-AP1 |

`checked` is one item, not a list as in R-AP17, because one group and one path name one repository. `repos` has one item for each GitHub name in `releases` (R-AP32). A group with no release (R-AP13) and a page after the last release (R-AP14) are 200 with `[]` for each list and `null` for `checked`. Only R-AP1 and R-AP2 answer 404.

### 4.1 Closure query

R-AP16: The body of `POST /v1/closure`:

| Field | Value |
| --- | --- |
| `groups` | A list of `{group, series, range}`. `series` and `range` are optional. It holds each group that the resolve must choose a version for (CLI 7.3, R-DI1): each free direct dep, the platform, each `[overrides]` group (Resolution 6), the group of `tln add`, and the rows of `tln outdated`. The first query does not hold the groups of the movable variables of a held move (Resolution 9, R-SP23). Only when the search with the held variables fixed finds no tuple (R-SP16), the client sends a second query for the second search (R-SP24): `groups` holds only these groups, each with the ranges of a moved variable (R-SP23), `hashes` is empty (the first answer has their records), and `compilers` is the same. The client applies the `log_size` of the first answer to the second answer as a `log:N` snapshot (R-AP19, with the smaller N when the user gave one: Design Q404), so the 2 answers show one state of the log, and the command prints the first `log_size` (Resolution 11, R-DT5). "The first answer" is the answer that the first search used: after the second query of R-AP28 case 2 it is that second answer (Design Q460). With no `series`, all series of the URL form. `range` is a range in the form of `talon.toml` (Design 4.3). With a range, the answer has only the candidates in it. With no range, the answer has every release of the group, for example where R-UP1 (Resolution 10) says that the range does not apply. |
| `hashes` | The hashes whose records the client needs: the value of each header entry that has a hash (Design 4.2), for example a hash of a hand edit (Design 4.1, R-ID7), also when the group of the entry is in `groups` (R-AP63). The client sends each hash once (R-AP74 row 5). |
| `compilers` | `{from, to}`: the window W of compilers that the command can choose, as tags of the compiler list (CLI 6.2), in the order of Resolution 1, R-NS1. Optional, and each end is optional: a missing end is the end of the domain. A held nightly (Resolution 9, R-RP2) gives `from` = `to` = the held compiler. A free nightly gives the oldest and the newest compiler that the `nightly` switch, the `[toolchain] roc` range, `min-release-age` and the snapshot allow (R-NS3, R-NS7, R-C7). `tln probe --range` sends no window. An end that the Worker cannot place is a missing end (R-AP60). `from` after `to` is an empty W (R-AP61). |

R-AP17: The answer of `POST /v1/closure`:

| Field | Value |
| --- | --- |
| `artifacts` | The record (R-RE1) of each candidate, of each hash in `hashes`, and of each hash in their closure (the deps, to the end, of each version that an edge names, not only the winners). The client applies the winner rule of Resolution 5, R-AL9. |
| `releases` | The releases (R-RE2) of these hashes |
| `epochs` | For each target of the matrix rows of these hashes: the epochs of the registry that touch W, as `{target, from, to}`, with 2 or more compilers each. An epoch of the registry is a maximal interval of compilers in which each transition has a `transitions` row (R-RE23) with `changed` = 0: it is covered and it is not a boundary of case (a) of Resolution 4, R-EP3. A compiler that no listed epoch holds is an epoch of its own. E, for each target, is W made larger to the ends of these epochs. The epochs of one target never overlap: each compiler has one epoch number for each target, so the Worker cannot send a compiler in 2 epochs of a target (slice 110, `prefix.sql`). If an answer has such an overlap, the client puts the compiler in the first epoch in the order of the answer and does not stop (Design Q409). |
| `runs` | The matrix rows (R-RE3) of these hashes on the compilers of E, as runs `{hash, target, source, result, error_digest, from, to}`. A run is a maximal interval of adjacent compilers (R-EP1) on which one (hash, target, source) has a row with the same result and error digest. A compiler with no row ends a run. `error_digest` is text or null (R-AP58). |
| `nearest` | For each (hash, target): the nearest matrix row before E and the nearest after E with a code result (`pass` or `fail`, R-EP1), `{hash, target, source, result, error_digest, nightly, side}`. The precedence of Resolution 3, R-EF3 chooses the row of a pair before the result is tested: a `bot` row wins over an `author` row. Case (b) of Resolution 4, R-EP6 uses them. |
| `hints` | The `compat_hints` rows (R-RE12) of these hashes on the compilers of W, added up over the Talon versions: `{hash, nightly, target, pass_count, fail_count, crash_count}` |
| `log_size` | The size of the log in the database state that the answer comes from |
| `unknown` | Each hash of `hashes` that the registry does not index (Q33), and each text that is not a hash (R-AP59) |
| `checked` | For each `github.com` repository of a group in `groups`: `{name, checked_at, stale}` (R-AP29, R-AP64) |

R-AP18: All rows of one answer and `log_size` come from one state of the database. So each release in the answer has `log_index` at most `log_size`. `tln` refuses an answer with a release whose `log_index` is greater than `log_size`: it uses nothing of it, and the command stops with exit code 15, as an answer that does not decode (CLI 3, R-E6, last row; Design Q390). Reason: such an answer mixes 2 states, so `log:N` (R-AP19) and the printed log size would be wrong, and a drop of the release would hide a fault of the Worker. For example, the Worker runs the reads in one D1 session (Sessions API) and reads `log_size` last, or runs them in one D1 batch.

R-AP19: The client applies `--snapshot log:N` to the answer. It hides each release with `log_index` greater than N, and each toolchain row of R-AP5 with `log_index` greater than N (Resolution 11, R-DT3). It does not hide `epochs`, `runs`, `nearest` and `hints`: they are evidence, not releases (R-DT5). A run or an epoch that goes past a hidden compiler holds only for the compilers that the client knows. The hide is done by the client on the answer, and the Worker has no snapshot parameter, so the answers and their ETags do not change (Design Q403 to Q405). Four more rules:

| Item | Rule |
| --- | --- |
| Header values stay (Design Q403) | A snapshot never hides the value that a header entry or the `roc:` pin has now (Resolution 2, R-C9, as R-AP63 for the answer). So the client keeps each release whose `hash` is one of the `hashes` of its request, and the toolchain row of the held `roc:` pin, also when their `log_index` is greater than N. It hides the other releases. |
| The second query (Design Q404) | The second answer (R-AP16) is hidden above the smaller of the first `log_size` and the N of the user, when the user gave `--snapshot log:N`. Reason: the first answer is hidden above N, and both answers must show one state of the log. The same keep list applies: the `hashes` of the first request. The printed number is not changed by this: R-DT5. |
| The other members (Design Q405) | The client does not change `artifacts`, `unknown`, `checked`, `repos` and `log_size`. An artifact of a hidden release is not read, because only the records of the edges of a chosen release are read (R-AL9). `unknown`, `checked` and `repos` are facts of the index at the time of the answer, not releases (R-DT5). `log_size` stays the value of the answer. The printed number is N of `--snapshot log:N`, else the `log_size` of the first answer (R-DT5). |

R-AP42: Size. The facts of the closure are runs in a window, not one row for each compiler, so the answer grows with the changes of results, not with the count of nightlies. Measured on a synthetic matrix of 3 years (`research/closure-runs/`, 900 compilers, 26 closure hashes, 11,934 rows): all rows are 1.8 MB of JSON, the answer for a held nightly is 9 KB, and the answer for all compilers is 49 KB. The client gets the same facts in W (real, inferred or unknown, Resolution 4, R-EP2 to R-EP6) as from all rows: 400 random cases on local D1 and SQLite. Reason for E: case (a) of R-EP6 reads each fact of the epoch of a compiler, and the epoch can go past W. With no `--snapshot`, `log_size` is the log size that R-DT5 prints (`resolved at log:<log_size>`).

R-AP20: The closure query changes no state. The client can send it again after a network error.

R-AP28: A hash in `unknown` (R-AP17) is a header value that the registry does not index. The closure query already ran the privacy guard of CLI 1, R-RG4 for each `github.com` group and hash in it, so a private repository never gets here. Talon checks the cases in this order, and the first case that applies is used:

| # | Case | What Talon does |
| --- | --- | --- |
| 1 | The answer has the label (group and version) of the URL with another hash | The R-PU19 case. Talon prints a warning that names the release and both hashes. It sends no ingest, and it reads the facts of the value as in case 3, because the registry's release has another hash and is another artifact (Design Q425). The pick drops the registry's row of that label (same group and version, another hash) and keeps the header URL, so the value is never moved to the other hash (Design Q461). |
| 2 | The URL is a `github.com` release asset URL (CLI 7.3, R-DI5) of a repository that the guard found public (CLI 1, R-RG5), and the command has no `--snapshot log:N` | Talon sends one ingest (R-AP9) for each such URL, at the same time, then sends the closure query again, once, with the largest `Talon-Bookmark` of the ingest answers (R-AP41 row 5), so the second read sees the ingests. This is the rule of CLI 2, R-AD35 for a header value. A 409 `label-conflict` to one of these ingests is case 1 for its URL (R-AP65). The rules of this case are in the table below (Design Q420 to Q424). |
| 3 | Any other URL (another host, a loopback host, an ingest that gave 4xx), or `--snapshot log:N` | Talon sends no ingest. It reads the facts from the archive, as `direct` mode does (CLI 7.3, R-DI7). |

Rules of case 2 (Design Q420 to Q424):

| Item | Rule |
| --- | --- |
| Timeout (Q420) | One ingest request has the timeout of every small request, 20 s for the whole answer (CLI 7.5, R-DA9, R-CC12). The Worker answers an ingest in a few seconds (3 reads of GitHub, an archive of at most 100 MB, 2 D1 calls), and an ingest is idempotent (R-PU14), so one that the client cut is indexed or not, and the second query shows which. |
| Other answers (Q421) | An ingest with no answer, a 5xx, a 3xx or a 202 (the registry never answers 202 to an ingest, Design Q62) gives no index for that URL: it is case 3 for the URL, and Talon prints one warning that names the URL and the status or `no answer`. The command goes on and its exit code does not change. A 429 is exit 15 (R-AP25). A 4xx other than 409 `label-conflict` and 429 is case 3 with no warning, because the archive gives the same facts. The ingest is not sent again (R-AP34). |
| Bookmarks (Q422) | A `Talon-Bookmark` is opaque to the client, except its order. The largest is the longer text, and of two texts of one length the larger in byte order. D1 writes a bookmark as fixed-width lower-case hex parts, so this is the order of the numbers. The header order of a request is not part of the contract (RFC 9110, 5.3). |
| After the second query (Q423) | The second query is sent only when at least one ingest answered 200 or 201. It has `Cache-Control: no-cache` and, when at least one of these answers has a bookmark, the `Talon-Bookmark` of the largest. With no bookmark it has `no-cache` only (R-AP55). A hash that is still in `unknown` after it is case 3, with no more ingest and no third query. |
| 429 (Q424) | A 429 message gives the time from the header `Retry-After` (whole seconds, R-AP25). With no header, or a value that is not a whole number, the message has no time. |

In all cases, the header value stays in the domain of its variable (Resolution 2, R-C9). In case 3, the other candidates of its group come from the registry when the answer has releases of that group. When it has none, the entry acts as an anchor at its header value, as in CLI 7.3, R-DI11, and `tln update`, `tln upgrade` and `tln outdated` print `<alias>: fixed: not in the registry index`, with the alias of the header entry (Design Q462). Reasons: one command uses one index (Q34, CLI 7.3, R-DI14). Talon sends to the registry only a URL on `github.com`. The ingest downloads the asset with no token, so it can index only a public asset, and a URL on a private host never leaves the machine. An ingest adds releases to the log, so a log snapshot must not send one (CLI 2, R-AD36).

R-AP58: `error_digest` on the wire (Design Q114). In each item of `runs` and `nearest` (R-AP17, and the `runs` of R-AP4), `error_digest` is text or null, as "or null" in R-AP49: the error digest of the matrix rows (R-RE3), and `null` when the `compat` column is NULL (for example a `pass`). It is a required member: the writer writes `null` and does not leave it out (R-AP51). For the run rule of R-AP17, 2 rows with no digest have the same digest (SQL `IS`, not `=`). An empty text is a digest, not `null`. Reasons: `""` would be a digest that no row has, and the reader could not tell it from a row with an empty digest. `null` is the form of R-AP49 for a value that can be absent.

R-AP59: A text of `hashes` (R-AP16) that is not base58 of exactly 32 bytes (Design Q115) is not an error. The answer has it in `unknown`, as sent, and the Worker does not put it in the D1 parameter. `unknown` has the order of `hashes`, and each text once, also a text that `hashes` repeats. Reasons: as R-AP56 for R-AP2, the text names no indexed artifact. The client reads each item of `unknown` with R-AP28, so it needs no other error path.

R-AP60: A `compilers` end that the Worker cannot place (Design Q116, Q117) is read as a missing end: the end of the domain on its side (R-AP16). These ends are: a tag with no nightly id (R-IK4), and a nightly id with no `toolchains` row (a nightly that the registry has not recorded, R-MX16). They are not a 400. A member that is not text and not `null` is still 400 (R-AP51). Reasons: the answer then holds the same facts or more (as R-AP44 row 2), so the client computes its facts in W from it (R-AP42). The client can send such an end: a held `roc:` pin that is a compiler release (Resolution 1, R-NS12, R-C9), which the registry does not list (R-AP57 row 1), or a held nightly that the registry has not recorded yet. A 400 would stop that resolve, and would refuse a newer `tln` that names a release (R-AP44, as `target` in R-AP56). A place from the date of the nightly is not used: W then holds no recorded compiler, so the answer has no runs and no nearest rows for it, and the client can infer no fact (Resolution 4, R-EP6).

R-AP61: `from` after `to` in the order of R-MX16 (Design Q118) gives an empty W. Then E is empty, and `epochs`, `runs`, `nearest` and `hints` are `[]`. The other members are as for any request. Reason: a client that has no compiler to ask about needs no fact on a compiler (R-AP42). `tln` sends no empty window (R-AP74 row 4).

R-AP62: The order of the checks of the closure body (Design Q119), in detail for R-AP48 rows 4 and 6. The first check that fails gives the answer, and the Worker makes no D1 call before all checks pass:

| # | Check | Answer |
| --- | --- | --- |
| 1 | The body is larger than 256 KB (R-AP46) | 413 `too-large`, `field` `body` |
| 2 | The body does not decode: not JSON, not an object, a required member is missing, a wrong JSON type (R-AP51) | 400 `bad-request` |
| 3 | More than 300 `groups`, then more than 1000 `hashes` (R-AP46) | 413 `too-large`, `field` `groups`, then `hashes` |
| 4 | A `series` that is not a series, or a `range` that is not a range (Design 4.3) | 400 `bad-request` |

Reason: the counts of check 3 need the decode of check 2. `tln` sends valid JSON and keeps to the limits (R-AP46), so this order changes no answer that `tln` gets. A tag of `compilers` is not a check: R-AP60.

R-AP63: The range filter and the closure (Design Q120). The filter of `series` and `range` in Roc (R-AP41 row 4, `VersionReq.matches`) applies only to `releases`. `artifacts` holds the closure that SQL finds from the key bounds (R-IK5): a candidate that the filter drops still gives its artifact record and its closure. This occurs only for a key that the bounds cannot make exact, for example a key that saturates (R-IK5). A release whose hash is a text of `hashes` stays, also when the filter drops it. Reasons: `hashes` holds the header values (R-AP16), and a header value stays in the domain of its variable also outside the range (Resolution 2, R-C9), so the client needs its release (`yanked` for R-C6, `published_at`). A record that no edge names does no harm: the client reads only the records of the edges (Resolution 5, R-AL9).

R-AP64: `checked` of the closure answer (Design Q121). One item for each distinct `github.com` repository (`releases.repo`) of all releases of the groups in `groups`, also yanked and withdrawn releases. `series` and `range` do not limit it. A group with no release, and a group on another host, give no item. The items are sorted by `name` (bytes). Reasons: the age of the index is a fact of the repository, not of a version (R-AP29). It is the rule of R-AP53 for one group.

R-AP65: The label of an unknown header value (Design Q122). The answer can have no release with the label (group and version) of the URL of a hash in `unknown`, also when the registry has that label with another hash: the group is not in `groups`, or the filter of its group drops the label (R-AP63). So the client uses 2 sources for case 1 of R-AP28, with no new request member and no new round trip:

| # | Source | What the client does |
| --- | --- | --- |
| 1 | The answer has the label with another hash | Case 1 of R-AP28, before any ingest |
| 2 | The ingest of case 2 for that URL answers 409 `label-conflict` (R-PU19) | Case 1 for that URL: the warning of R-PU19 that names the release, the hash of the header value, and that the registry has the label with another hash. No exit code from R-E6 (CLI 3), because R-AP28 handles the answer. That URL is not an ingest that indexed a release. |

The client sends the closure query again (case 2) only when at least one ingest answered 200 or 201. Another error of an ingest (422, 409 `id-collision`, another 4xx) is case 3 for its URL. With case 3 conditions (another host, `--snapshot log:N`) the client sends no ingest, so it sees case 1 only from source 1. Then it applies case 3: the header value stays in its domain (Resolution 2, R-C9), and a download of an asset that is not there fails as CLI 7.3, R-DI15 says. Reasons: the 409 of R-PU19 is the same fact as case 1, from the registry, and it comes from a request that case 2 sends already. A list of labels in the request (a new member, and a lookup of the labels in SQL) would only give the warning one step earlier. The Worker cannot find the label from a hash that it does not index.

### 4.2 Rules for all routes

R-AP21: An error answer is RFC 9457 problem details: `Content-Type: application/problem+json`, with the fields `type`, `title`, `status` and `detail`. `type` is a stable value from the table below, a relative URI. The registry does not serve a page at that URI.

| `type` | Status | When |
| --- | --- | --- |
| `/errors/bad-request` | 400 | The body, the path or the query is not valid |
| `/errors/unauthenticated` | 401 | A token that the route needs is missing or not valid, a webhook signature is bad, or a release body has `compat` and no token (R-AP26) |
| `/errors/forbidden` | 403 | The token is valid, but it does not give this action. The `detail` names the claim that failed (R-TP3, R-TP7, R-TP8, R-YK2). |
| `/errors/repository-changed` | 403 | The repository id and the owner id of the name are both not the recorded ones: another account (R-TP9). The answer has the member `issues_url` (R-TP12). |
| `/errors/not-found` | 404 | The resource does not exist |
| `/errors/method-not-allowed` | 405 | The path is a route, but not for this method. The answer has the header `Allow` with the methods of the path (RFC 9110, 15.5.6). |
| `/errors/label-conflict` | 409 | The label (group, version) exists with another hash (R-PU1) |
| `/errors/id-collision` | 409 | A new hash or name has the id of another name (5.1, R-IK3). The `detail` names the other name. |
| `/errors/unsupported-client` | 400 | The `User-Agent` names a version of `tln` that the registry does not serve (R-AP45). The answer has the member `minimum`. |
| `/errors/too-large` | 413 | The body or a list in the request is larger than its limit (R-AP46). The answer has the members `field` and `limit`. |
| `/errors/unsupported-media-type` | 415 | The request body is not `application/json` |
| `/errors/not-a-candidate` | 422 | The release fails the candidate rules (R-PU6), an ingest names a repository that is not found or not public (R-PU32), or a compiler release has no asset that R-CV1 and R-CV2 select |
| `/errors/successor-mismatch` | 422 | A successor that fails a check of R-AP31. The `detail` names the check, and lists the missing modules for the `exposes` check. |
| `/errors/sweep-incomplete` | 422 | A sweep without a `bot` row for each hash under its bound (R-MX4). The `detail` lists the missing hashes (R-MX9). |
| `/errors/rate-limited` | 429 | The client sent too many requests (R-AP25) |
| `/errors/internal` | 500 | A fault in the Worker |
| `/errors/busy` | 503 | The Worker cannot serve the request now: a memory, CPU or time budget is used up, or the load is shed (R-AP82). The client may send the request again. |
| `/errors/upstream` | 502 | A read from GitHub failed, also the request for the installation token (R-PU43) |

R-AP22: In `tln`, CLI 3, R-E6 maps an error answer, a 5xx answer, or no answer to an exit code, when no other CLI rule handles that case: 20 (`rejected`) for a refused write, 15 (`network`) for a fault that a later run can fix. The message gives the `type` and the `detail`, and `--json` gives them in `error.details` (CLI 3, R-J7).

R-AP23: Media types: request bodies and answers are `application/json` in UTF-8. Errors are `application/problem+json`. The checkpoint is `text/plain; charset=utf-8`, and the tiles are `application/octet-stream`, as C2SP tlog-tiles gives. A request body is accepted as `application/json` with no `charset` parameter, or with `charset` equal to `utf-8`, as a token or a quoted string (RFC 9110, 8.3.1), case-insensitive. Another charset gets 415. Other parameters are ignored (R-AP44). A request with no body gets no media check: a route that needs a body answers 400 `bad-request`.

R-AP24: Each 200 answer of a `GET` in `/v1` has an `ETag`, except the tracker (R-AP35): it is the answer of one account, with `no-store`, so no cache keeps it and it has no `ETag` (Design Q312). A request with an `If-None-Match` that is equal to the current ETag gets 304 with no body. `tln` keeps each answer and its ETag in `talon/index/` (CLI 6.1). It uses an answer that is younger than its `max-age` with no request, and sends `If-None-Match` for an older one, as for GitHub (CLI 7.3, R-DI2).

R-AP43: Freshness. The Worker keeps the answers of the `GET` routes in the Cache API of its colo for their `max-age`, and there is no purge across colos (Q25). A request that must see the newest state sends `Cache-Control: no-cache`, the standard request directive (RFC 9111, 5.2.1.4). The Worker then does not read the Cache API: it reads D1 and puts the new answer in the Cache API. `Pragma: no-cache` (RFC 9111, 5.4) has the same effect, for old HTTP/1.0 proxies. `Expires` is a header of a response, not of a request, so the registry ignores it in a request. `tln` sends `Cache-Control: no-cache` and no local copy in these cases:

| # | Case |
| --- | --- |
| 1 | The read after an ingest (CLI 2, R-AD35 step 4, R-AP28 case 2) |
| 2 | Each read with a `Talon-Bookmark` (R-AP41 row 5): a bookmark always comes with `no-cache` |

A 404 answer is not put in the Cache API, so a repository that the registry indexes now is seen at the next request. A publish, an ingest and a yank drop the entries of the release in the colo of the request (`cache.delete`, `cloudflare-workers/API.md` RF1). The keys are the fixed list of R-AP69 (Design Q166). Other colos see the change after at most `max-age` (60 s). This is enough, because the default `min-release-age` of 2 days (Resolution 2, R-C7) hides a new release longer than that. The Cache-Tag purge needs a zone and an API token in the Worker, and it gives nothing that the case table above does not give. Rate limits apply to a `no-cache` request as to any other request (R-AP25).

R-AP54: The ETag and the conditional request of a `GET` in `/v1` (R-AP24, Design Q96). These are facts, not output text: a client keeps an ETag and sends it again, maybe to another colo or to a later Worker.

| Item | Rule |
| --- | --- |
| ETag | A strong entity tag: the first 16 bytes of SHA-256 of the body bytes, as 32 lower-case hex digits, in double quotes (`"ba7816bf8f01cfea414140de5dae2223"`). It is a function of the body only, so each colo and each Worker that writes the same bytes (R-AP49, R-AP53) gives the same ETag. |
| `If-None-Match` | The weak comparison of RFC 9110, 13.1.2: the value `*`, or a comma-separated list of entity tags. `W/` before a tag is ignored, and white space around a tag is ignored. A text that is not an entity tag matches nothing. The Worker compares with the ETag of the answer that it has, also of an answer from the Cache API. |
| 304 | No body and no `Content-Type`. The headers `ETag` and `Cache-Control` have the values of the 200 answer (RFC 9110, 15.4.5). |
| 200 | `Content-Type: application/json` with no `charset` parameter (R-AP23 gives UTF-8), `Cache-Control: max-age=<the max-age of the route>`, `ETag` |

R-AP55: The Cache API of R-AP43, in detail (Design Q90, Q96, Q97):

| Item | Rule |
| --- | --- |
| Key | The whole request URL with its query, as sent |
| Bypass | Only the directive `no-cache` in `Cache-Control` or in `Pragma`: a comma-separated list, case-insensitive, white space around a directive ignored, the whole directive (`no-cachex` is not it). Other directives (`max-age=0`, `no-store`, `private`) do not bypass. Reasons: `tln` sends `no-cache` (R-AP43), and a browser sends `max-age=0` at each reload, which would make the cache useless. |
| A 304 after a miss or a bypass | The Worker read D1 and has the 200 answer: it puts the 200 answer in the Cache API, then answers 304 |
| Not put | A problem answer (400, 404, 405) |
| `Talon-Bookmark` (R-AP41 row 5) | The value with no white space at the ends gives `After(<value>)`. No header, or an empty value, gives `Any`. |

The same rules apply to `GET /v1/toolchains` (R-AP5) with `max-age=300` (Design Q96).

R-AP56: The path and the query of the read routes (Design Q88, Q89, Q91, Q95, Q104). Each check is done before any D1 call.

| Item | Rule |
| --- | --- |
| `{owner}/{repo}` of R-AP1 | ASCII case-insensitive, because GitHub names are case-insensitive (as R-SN1). The Worker makes the ASCII letters lower case, then computes the id of R-IK2. So `Roc-Lang/Unicode` and `roc-lang/unicode` give one answer. The `detail` of a 404 has the two path segments as sent. |
| `group` of R-AP13 | Compared as exact bytes (its id is the id of the UTF-8 bytes, R-IK2). No case change: the group is the URL text that roc compares (Design 2). |
| `{hash}` of R-AP2 and of R-AP4 that is not base58 of exactly 32 bytes (Design Q152) | 404 `not-found`, with the `detail` of an unknown hash, and no D1 call. Reason: R-AP48 row 1, the path names no resource. `tln` sends only a hash of a release URL (Design 4.1, R-ID5), and it reads a 404 as "not indexed" (R-AP28 case 3). |
| No `group` and no `after` on `GET /v1/releases` | 400 `bad-request`, also when `series` is there |
| `series` with `after` and no `group` | Ignored: the answer of R-AP14 holds the same facts or more (as R-AP44 row 2) |
| `after` of R-AP5, R-AP13 and R-AP14 | Decimal digits, with no leading zero (only `0` itself starts with `0`), at most 2^63 - 1 (an SQLite INTEGER, R-IK6). Any other text is 400 `bad-request`. Reasons: a log index has one text form, so one answer has one cache key (R-AP55), and the value binds to a column with no overflow. |
| `target` of R-AP5 | Any text, compared exactly with the `target` of R-RE4. An empty text, or a target that the registry does not know, gives 200 with no rows. Reason: roc can add a target (CLI 6.2, R-CV8), and a 400 would refuse a newer `tln` on an older Worker (R-AP44). |

R-AP57: The steps of `PUT /v1/toolchains/{tag}` (R-AP6, R-PU7 to R-PU10, Design Q98 to Q101, Q103, Q105). After the token check of R-PU7:

| # | Step | Answer |
| --- | --- | --- |
| 1 | The tag has no nightly id (`NotANightly`, R-IK4) | 422 `not-a-candidate`, no D1 call and no GitHub call. R-CV1 lists only nightly tags. |
| 2 | D1 call 1 reads the rows of the nightly id. Reason for this read before GitHub: a recorded row never changes (R-PU9, R-PU10), so a GitHub read cannot change the answer, and the GitHub rate limit is kept. A changed `digest` on GitHub is seen by `tln` with `direct` (R-CV6), not by the Worker. | Rows of this tag: 200 with them, and no GitHub call. Rows of another tag with the same id: 422 `not-a-candidate` (R-IK4). No rows: step 3. |
| 3 | The Worker reads `GET https://api.github.com/repos/roc-lang/nightlies/releases/tags/{tag}` (R-PU8). | 404 from GitHub: 404 `not-found`. Another status, no answer, or an answer that is not a release: 502 `upstream`. |
| 4 | A release with `draft` or `prerelease` true is not a candidate (R-CV1, CLI 7.3, R-DI3) | 422 `not-a-candidate` for the whole tag |
| 5 | `published_at` has the form `YYYY-MM-DDTHH:MM:SSZ`, as GitHub gives it. Another form is an answer that is not a release. | 502 `upstream` |
| 6 | The assets of R-CV2. An asset whose `digest` is missing, `null`, or not `sha256:` and 64 lower-case hex digits, or whose `size` is missing, `null`, not a whole number or 0, is not an asset for its host: the other hosts stay. | No asset left: 422 `not-a-candidate` |
| 7 | D1 call 2: the batch of R-SG8 (a leaf and a row for each asset, in the byte order of the target), and last the read of the rows of the nightly | 201 when a `toolchains` statement of the batch has `changes` above 0. 200 when the batch wrote nothing, because another request wrote the tag between call 1 and call 2. The body has the rows of the last statement. |

R-AP66: The bot path of `POST /v1/compat` (R-AP10, Design Q139 to Q146, Q153). The first check that fails gives the answer. This is R-AP48 and R-AP62 for this route:

| # | Check | Answer | D1 calls |
| --- | --- | --- | --- |
| 1 | The path and the method (R-AP48 rows 1, 2). A body with no `Content-Type`, or another media type (R-AP23). | 404, 405 with `Allow: POST`, 415 | 0 |
| 2 | The body is larger than 256 KB (R-AP46) | 413 `too-large`, `field` `body` | 0 |
| 3 | The request has no `Authorization` and no `Talon-Contributor` (R-CT1) | 400 `bad-request` | 0 |
| 4 | The body does not decode (R-AP51): not UTF-8, not JSON, not an object, `rows` missing or `null`, a row that is not an object, a row without `hash`, `nightly`, `target`, `result` or `error_digest`, a wrong JSON type, a `sweep` that is not an object or `null`, a sweep without `nightly`, `target` or `upto_log_index`, an `upto_log_index` that is negative or not an integer, a member `source` in the body or in a row (R-MX5) | 400 `bad-request`, the `detail` names the member | 0 |
| 5 | More than 500 `rows` (R-AP46) | 413 `too-large`, `field` `rows`, `limit` 500 | 0 |
| 6 | The values, row by row in the order of the body, then the sweep. In a row: `hash`, then `nightly`, then `result`. A `hash` that is not base58 of exactly 32 bytes, a `nightly` or sweep `nightly` that has no nightly id (R-IK4), a `result` that is not `pass`, `fail`, `hang` or `crash`, a sweep `target` that is not `any` (R-MX4), an `upto_log_index` above 2^63 - 1 | 400 `bad-request` | 0 |
| 7 | The token of the compat bot (R-TP3, R-TP7, R-AP26) | 401, 403, 500, 502 | 0 |
| 8 | D1 call 1, a read batch of 3 statements on the primary (`artifacts`, `targets`, `artifact_targets`, with the lists as JSON parameters, R-AP41 row 2). Then the rows in order. For a row: first an `artifact` with no `artifacts` row, then the target. | 404 `not-found`; then 400 `bad-request` for a target that is not `any` and the artifact is not a platform, a name with no code, or a pair that is not in `artifact_targets` (R-MX10) | 1 |
| 9 | D1 call 2, one write batch on the primary: the row statement, then the sweep statement. | 201 or 200 (R-AP10). A `RAISE` text: R-MX9. | 2 |
| 10 | D1 call 3, only after `sweep-incomplete`: the missing members (R-MX9) | 422 `sweep-incomplete` | 3 |

The details:

| Item | Rule |
| --- | --- |
| Request kind (Design Q146) | A request with an `Authorization` header is the bot path, and a `Talon-Contributor` header is then ignored (R-CT1: a request with a token has no id). A request with no `Authorization` and with `Talon-Contributor` is a user hint (R-AP70, slice 116). Until that slice, the Worker answers it with 500 `internal`, so the route is not deployed before slice 116. |
| A `source` member (Design Q139) | 400 at check 4, also in a row (R-MX5) |
| `error_digest` of a row (Design Q140) | A required member (R-AP51): text or `null`. `null` is stored as NULL, and an empty text is a digest (R-AP58). A missing member is 400. Reason: a `pass` has no digest, and the writer writes `null` for none, as R-AP58 does for the answer. |
| A `hash` that is not a hash (Design Q141) | 400 at check 6, with no D1 call. A hash that is a hash and is not indexed is 404 at check 8. Reasons: the body is not a path. A member of the body with a value in no valid form is 400 (R-AP51, as a `series` in R-AP62 check 4 and a `target` with no code in R-IK7). The 404 of R-AP56 is for a path, which names no resource (R-AP48 row 1). And the bot gets 400 for its own fault, and 404 for a hash that the registry may index later. |
| Which row fails first (Design Q142) | The first row of the body that fails. The static checks of all rows (check 6) come before the facts (check 8), because they need no D1 call. In check 8, a row is checked by the order: its 404, then its target 400. Row 1 with a target 400 and row 2 with a 404 gives the 400 of row 1. |
| Limits and values (Design Q143) | The limit of 500 rows (check 5) comes before the value checks (check 6), as R-AP62 puts the counts before the `series` and `range` checks. It needs the decode of check 4. |
| Body and token (Design Q144) | Checks 1 to 6 come before the token check (check 7), as R-AP48 rows 4 to 6 come before row 7. A request with a wrong token and a bad body gets the 400 or 413. The media type is a header, so the Worker reads it before the body: a body that is too large and not JSON gets 415 (the same as `POST /v1/closure`). |
| `written` | The `changes` of the row statement: the rows that were new (R-RE13 row 1). No trigger fires on `compat` (R-MX8), so D1 counts no other row. A request with a sweep only, or with no rows, has `written` 0 and the answer 200. |
| Answer | `{"written":n}`, `content-type: application/json`, `no-store`. 201 when `written` is above 0, else 200. |

R-AP67: The path and the query of the compat reads (R-AP4, R-AP39, R-AP40, Design Q147 to Q152). Each check is done before any D1 call. The cache of R-AP43, R-AP54 and R-AP55 applies to R-AP4 and R-AP40. R-AP39 is `no-store` and has no ETag, because it is the work list of the bot: a copy of it is wrong as soon as a row is written.

| Item | Rule |
| --- | --- |
| `target` of R-AP39 (Design Q147) | Absent, or the text `any`. Another text, also an empty one: 400 `bad-request`. Reasons: a sweep exists only for `any` (R-MX4 refuses another target with 400), so an answer for another target has no fact, and 200 with `sweep: null` would say that the compiler has no sweep. R-AP56 gives 200 for the `target` of R-AP5 because that parameter filters rows that exist for each target, and a newer `tln` can send a target that an older Worker does not know (R-AP44). Here the set of valid values is closed by R-MX4. |
| `{tag}` of R-AP39 | A text with no nightly id (R-IK4): 404 `not-found`, with no D1 call. A nightly id with no `toolchains` row: 404 after the read. Both give the `detail` `no toolchain for the tag <tag>`. |
| `audit` of R-AP40 (Design Q148) | Required: no `audit` is 400. Decimal digits, no leading zero (only `0` itself starts with `0`). Any other text, also an empty one, is 400. Reasons: a missing key that a route needs is 400 (R-AP56, `GET /v1/releases`), and the form is the form of `after` in R-AP56, so one answer has one cache key (R-AP55). |
| `audit` above 1000 (Design Q149) | The Worker uses 1000, for each text of digits that is a number above 1000, also one past 2^63 - 1 (the Worker compares the text, so it does not overflow). `audit=0` gives `{"pairs":[]}`. R-AP40 says "at most `n` (at most 1000)", so a larger `n` is the limit, not an error. This differs from `after` in R-AP56, which is 400 above 2^63 - 1: `after` is a position that binds to a column with no overflow, and `audit` is a count that has a limit in the rule. The answer to `audit=5000` and to `audit=1000` has the same bytes and ETag. |
| `members` of R-AP39 (Design Q150) | The count of distinct hashes of the bot set (R-MX11 row 5) |
| The order of `pairs` (Design Q151) | The total `pass_count + fail_count + crash_count` from large to small. Equal totals: the hash bytes, then the nightly id (it is in date order, R-IK4), then the target code (R-IK7), each from small to large. Reason: 2 answers of one state must have the same bytes and the same ETag (R-AP24, R-AP53). The counts are sums over `talon_version` (R-AP4). |
| `{hash}` of R-AP4 (Design Q152) | Not base58 of exactly 32 bytes: 404 `not-found` with the `detail` `no artifact <hash>`, no D1 call. A hash with no `artifacts` row: the same 404, and it is not put in the Cache API (R-AP55). This is the rule of R-AP2 (R-AP56). |

R-AP68: The ingest path of `POST /v1/releases` (R-AP9, R-PU4, Design Q155 to Q162, Q164, Q165, Q167, Q168). The first check that fails gives the answer. This is R-AP48 for this path. All D1 calls of the request go to one session `with_session!(Primary)`.

| # | Check | Answer | D1 calls |
| --- | --- | --- | --- |
| 1 | The path, the method, the media type and the body size (R-AP48 rows 1, 2, 4, 5). The request has no `Authorization` (R-AP26). | 404, 405 with `Allow: GET, POST`, 415, 413 `too-large` | 0 |
| 2 | The body (R-AP51): a JSON object with the text member `url`. A `compat` member that is not `null` (R-AP26). Then the URL rules (R-PU34 row 4, R-PU40, CLI 7.3, R-DI5). | 400 `bad-request`, 401 `unauthenticated`, 422 `not-a-candidate` | 0 |
| 3 | The IP limit (R-PU34 row 1): `limit!` of the binding `RL_INGEST` with the key of the item "Rate key" | 429 `rate-limited`, `Retry-After: 60` | 0 |
| 4 | D1 call 1, a read batch: the label row (group, version) with its hash and whether it has an `ingest` provenance row. From slice 112b, also the statement of the item "Owner count". | The label with another hash: 409 `label-conflict` (R-PU19), the `detail` names the hash in the index. The same hash with an `ingest` row: 200 with the record (R-PU14). | 1 |
| 5 | The owner limit (R-PU34 row 2): only when the label is not in the index and the name has no `repos` row | 429 `rate-limited`, `Retry-After` the seconds to the next 00:00 UTC, rounded up | 1 |
| 6 | `GET /repos/{owner}/{repo}` (R-PU31, R-PU32), then, for a public repository, the ids against the `repos` row of call 1 (R-TP9, Design Q263) | 404, `private`, `internal`: 422 `not-a-candidate`, `repository not found or not public`. Another status, no answer, or an answer that is not a repository: 502 `upstream`. Both ids different from the row: 403 `repository-changed` (R-TP12), with no D1 call, no more GitHub read and no `Talon-Bookmark`. | 1 |
| 7 | The label with the same hash and no `ingest` row (Design Q157): D1 call 2, the provenance row and the read of row 4. No release read, no download. | 200 with the record | 2 |
| 8 | `GET /repos/{owner}/{repo}/releases/tags/{tag}`, then the candidate rules (R-PU6, CLI 7.3, R-DI3, R-DI4) | 404: 422 `not-a-candidate` (Design Q160). Draft, prerelease, 0 or 2 package assets, another asset, no `published_at`: 422. Another status, no answer, an answer that is not a release: 502. | 1 |
| 9 | The archive read (R-PU38) | 422 `not-a-candidate`. A 404 of the asset, also after row 8 listed it, or another read fault: 502 `upstream` (Design Q162). | 1 |
| 10 | `GET https://raw.githubusercontent.com/{owner}/{repo}/{tag}/.roc-version` (R-AP49 `roc_version`, CLI 7.3, R-DI8) | 200: the text with no white space at the ends, an empty file is the text `""`. 404: `null`. Another status or no answer: 502 `upstream` (Design Q161). | 1 |
| 11 | D1 call 2, the write batch (R-SG8, R-IK3, R-PU15, R-PU26, R-TP5), last the read of row 4 | 201 with `Location` for a new release, 200 when the batch wrote no release. The trigger `label-conflict`: 409 (Design Q164). The `names.id` collision: D1 call 3, then 409 `id-collision` (R-IK3). | 2, or 3 |
| 12 | After the answer (`Response.after`): the cache drop of R-AP69, after a 200 or 201 of rows 7 and 11 | None | Not counted |

The details:

| Item | Rule |
| --- | --- |
| The order of the reads (Design Q156) | D1 first, then GitHub: the repository, the release, the asset, `.roc-version`. Reasons: a label that is in the index answers 200 or 409 with no GitHub read (R-AP41, "a read batch that can stop the request before a GitHub read"), and `tln add` sends one ingest for each candidate (CLI 2, R-AD35), so most ingests of a known repository end at row 4. The visibility comes before each write (R-PU31). |
| The same hash, no `ingest` row (Design Q157) | Only the visibility read (row 6), because R-PU31 needs it before a write, and the provenance row is a write. The release and the bytes are already in the index with their hash (R-PU14), so no other read can change the answer. A repository that is not public now gets the 422 of row 6, and nothing is written. |
| The stored URL (Design Q159) | The `url` of the request as sent, also the case of `owner/repo`. Only the `repo` name of R-IK2 is lower case. The group is the URL text (R-AP56, Design 2), so `Acme/Lib` and `acme/lib` give 2 groups of one repository, as in roc. Reason: the client that sent the ingest reads its own group again (R-AP28 case 2), and that group is the text of its header. The release read checks only the asset name (row 8). |
| The race of the label (Design Q164) | The trigger `label-conflict` stops the batch, and the batch writes nothing. The `detail` says that the label has another hash in the index, and does not name it: R-AP41 gives the 1 more D1 call only to R-IK3 and R-MX9, and the client needs only the fact (R-AP65 row 2). |
| Session and bookmark (Design Q165) | One session `with_session!(Primary)` for all D1 calls, so the read of row 4 sees the newest state. Each 200 and 201 has `Talon-Bookmark`: the bookmark of the session after its last D1 call, also for a 200 of row 4 with no write. A later read with `After(bookmark)` then sees the label. A problem answer has no bookmark: it wrote nothing. |
| Rate key (Design Q168) | The value of the header `cf-connecting-ip` (Cloudflare sets it, a client cannot). A value with a `.` after its last `:`, or with no `:`, is IPv4: the key is the text after the last `:` (an IPv4-mapped IPv6 address is its IPv4 address). Another value with `:` is IPv6: the key is the /64 prefix, the first 4 groups of the full form, each in lower-case hex with no leading zero, joined by `:`, then `::/64` (`2001:db8:0:0::/64`). No header, or a value that does not parse: the key `unknown`, one key for all such requests. The key goes to no table and no log (as R-CT11). The rate limit of user hints uses the same key and the same function (R-CT11, R-AP70 row 9, Design Q185). |
| What the IP limit counts (Design Q168) | Each request that gets to row 3, whatever its later answer: a 200 of row 4, a 409, a 422 and a 502 count. A request refused at rows 1 and 2 does not count. Reasons: rows 1 and 2 cost no D1 call and no GitHub call, and row 3 comes before the first call that costs. The binding has no reset time, so `Retry-After` is its period, 60 s. The binding counts in each Cloudflare location, and its count is not exact (Cloudflare docs, "Rate Limiting"), so 60 is a bound for each location, not for the world. |
| Owner count (Design Q167) | The owner is the owner text of the URL in lower case. The statement is in D1 call 1: the count of `repos` rows whose name (the `names` value of kind repository) is in the byte range from `<owner>/` to `<owner>0` (`/` is 0x2F, `0` is 0x30, so no `LIKE` escape is needed) and whose `time` is at or after 00:00 UTC of the day of the clock, and whether the name of the URL has a `repos` row. At 20 or more, row 5 answers 429. The count holds the rows of each path (webhook, publish, reconcile), because `repos` does not record the path. The write batch does not check the count again, so requests at the same time can pass the limit by a few names. Reasons: before the GitHub read the Worker knows only the owner text, not `repository_owner_id`, and R-AP41 allows no D1 call between the GitHub read and the write batch. The limit is a first guess against cost, not a rule of the data (R-AP41 row 3). |
| The identity (Design Q263) | The visibility comes first, then the ids. A repository that is not public gets the 422 of row 6 with any ids, so an ingest cannot learn from the answer if a private repository exists (R-PU32). The ids check is also before row 7 (the label with the same hash and no `ingest` row) and before row 8. The write batch has the identity statements of R-TP18, R-TP19 (Design Q262). |
| 429 texts | `too many ingests from this address: at most 60 a minute`, and `too many new repositories of the owner <owner> today: at most 20 a day from ingests`. The texts are a proposal (CLI 3, R-OUT2). |

R-AP69: The cache entries that a write drops (R-AP43, Design Q166). The key of the Cache API is the whole request URL (R-AP55), so the set of keys of a group has no bound (other `series`, `after` pages, the case of `owner/repo`, other percent-encodings, other query orders). The Worker drops a fixed list: the URLs that `tln` sends for the release. `<origin>` is the origin of the write request.

| # | Key | Route |
| --- | --- | --- |
| 1 | `<origin>/v1/releases?group=<group>` | R-AP13 with no `series` |
| 2 | `<origin>/v1/releases?group=<group>&series=<series>` | R-AP13 with the series of the release |
| 3 | `<origin>/v1/packages/<owner>/<repo>/releases`, with the lower-case name (R-IK2). Only for a `github.com` release. | R-AP1 |
| 4 | `<origin>/v1/artifacts/<hash>` | R-AP2 |

| Item | Rule |
| --- | --- |
| The query value | `<group>` and `<series>` are the texts of R-AP15, with each byte outside the unreserved set of RFC 3986 (`A-Z`, `a-z`, `0-9`, `-`, `.`, `_`, `~`) as `%` and 2 upper-case hex digits. `tln` builds the URLs of R-AP1, R-AP2 and R-AP13 with this same function, in this member order, so its reads use these keys. |
| Not dropped | The pages of R-AP14 (each release moves the last page, and `after` has no bound), and each other spelling of a key. They keep their entry up to the `max-age` (60 s), as each other colo does. |
| Who drops | The write routes of a client: a publish and an ingest that wrote a row (R-AP68 rows 7 and 11), and a yank (R-YK7). The work runs after the answer (`Response.after`, `cloudflare-workers/API.md` 10.2), so it adds no time to the answer. A failed drop is a log line, not an error. The queue consumer and the cron do not drop: their colo is not the colo of a reader. |
| Reasons | A drop needs the exact key (`cache.delete`, `cloudflare-workers/MODULES.md` 5.4), and the Cache API has no delete by prefix or tag. The Cache-Tag purge needs a zone and an API token (R-AP43). The client that must see the write sends `no-cache` (R-AP43 cases 1 and 2), and the default `min-release-age` hides a new release for 2 days, so an entry that stays for 60 s changes no resolve. |

R-AP70: The hint path of `POST /v1/compat` (R-AP10, R-CT1 to R-CT4, R-CT11 to R-CT14, Design Q170 to Q186). The first check that fails gives the answer. Rows 1, 3 to 8 are the checks 1 to 6 of R-AP66, and row 2 is R-AP48 row 3 (R-AP66 does not list it, and it holds for the bot path too), so the two paths of one route give one answer to one fault. A request with an `Authorization` header is the bot path (R-AP66), also when it has `Talon-Contributor`.

| # | Check | Answer | D1 calls |
| --- | --- | --- | --- |
| 1 | The path and the method (R-AP48 rows 1, 2) | 404, 405 with `Allow: POST` | 0 |
| 2 | The client version (R-AP45, R-AP48 row 3) | 400 `unsupported-client` | 0 |
| 3 | A body with no `Content-Type`, or another media type (R-AP23) | 415 | 0 |
| 4 | The body is larger than 256 KB (R-AP46) | 413 `too-large`, `field` `body` | 0 |
| 5 | The header `Talon-Contributor` is not 32 lower-case hex characters (R-CT1) | 400 `bad-request` | 0 |
| 6 | The body does not decode (R-AP51), or has a member that a hint must not have (`error_digest` in a row, `source` in the body or in a row, `sweep`, with any value, `null` too; R-CT2, R-MX5) | 400 `bad-request`, the `detail` names the member | 0 |
| 7 | More than 500 `rows` (R-AP46) | 413 `too-large`, `field` `rows`, `limit` 500 | 0 |
| 8 | The values, row by row in the order of the body. In a row: `hash`, then `nightly`, then `result` (`hang` is not a hint). | 400 `bad-request` | 0 |
| 9 | The IP limit (R-CT11): `limit!` of the binding `RL_HINTS` with the rate key of R-AP68 | 429 `rate-limited`, `Retry-After: 60` | 0 |
| 10 | The body has no row | 200 `{"written":0,"first":0,"skipped":[]}` | 0 |
| 11 | D1 call 1, a read batch of 3 statements on the primary (as R-AP66 check 8). The rows in order, the target rule of R-CT2. | 400 `bad-request` | 1 |
| 12 | The tag list of `roc-talon/talon` (R-CT12). A fault of this read is not an answer: the key is 0. | None | 1 |
| 13 | D1 call 2, one write batch on the primary (R-CT4). | 201 or 200 (R-AP10). The trigger `hint-quota`: 429 `rate-limited` with `Retry-After` to the next UTC day (R-CT13). | 2 |

| Item | Rule |
| --- | --- |
| Order of 3 and 4 (Design Q171) | As R-AP66: the media type is a header, so a body that is too large and not JSON is 415. The client version comes before both (R-AP48 row 3). |
| The id and the body (Design Q171) | Check 5 comes before check 6, as R-AP66 check 3 comes before check 4. A request with a bad id and a bad body gets the 400 of the id. |
| Where the IP limit is (Design Q186) | After all checks that cost no D1 call and no GitHub call (rows 1 to 8), before the first call that costs (row 11), as R-AP68 row 3. A request refused at rows 1 to 8 does not use the budget. Each request that gets to row 9 counts, whatever its later answer: a request with no row (row 10), a 400 of row 11 and a 429 of row 13 count. |
| A body with no row (Design Q172) | `rows: []` is a valid body. The answer is the 200 of row 10: nothing to write, so no D1 call and no GitHub read. `talon_version` is still required (R-AP51). |
| D1 calls | A good request 2. A body with no row 0. A request refused at rows 1 to 10 has 0, at row 11 has 1. R-AP41 (write budget) holds. |
| The tag list and the secret | Row 12 comes after row 11, so a request that ends at row 11 reads nothing from GitHub. The secret `CONTRIBUTOR_KEY` is read after row 11 too: a request that ends earlier needs no secret. A missing secret is 500 `internal`. |
| `Retry-After` of row 9 | 60 seconds, the period of the binding (Design Q168, Q185). |

R-AP71: The `compat` member of the publish body (R-AP8, R-PU5, R-PU16, Design Q190). The `records` type is `Compat.Publish` (slice 104f).

| Item | Rule |
| --- | --- |
| Member | `compat` is optional (R-AP51). A missing member and `null` mean no facts. |
| Fact | `{nightly, target, result, error_digest}`. Each member is required. `nightly`, `target` and `result` have the values of a bot row (R-AP66 check 6). `error_digest` is text or `null` (R-AP58). |
| No hash | A fact has no `hash`. The facts are of the hash that the Worker reads from the asset (R-PU1), so a client cannot send a fact for another hash. A fact with a member `hash` or `source`, with any value, `null` too, gets 400 `bad-request`, and the `detail` names the member (R-MX5, Design Q176). |
| `target` | `any`. Another value gets 400. Reason: R-PB5 sends unit checks (`tln probe --range`). Smoke builds are bot rows (R-MX10) or hints (R-SM1). A later rule can allow more targets with no change of the wire form. |
| `result` | `pass`, `fail`, `hang` or `crash` |
| `nightly` | A nightly tag (R-IK4). A tag with no `toolchains` row is accepted, as on the bot path (slice 115a). |
| Limit | 500 facts (R-AP46). More: 413 `too-large`, `field` `compat`, `limit` 500. |
| Rows | One `compat` row with the source `author` for each fact, with the hash of the asset and the log index of the release (R-RE13 row 2). The first write of a key wins. A key that is twice in the list, or that an earlier publish wrote, changes nothing and is not an error (R-RE13 row 1, R-PU14, R-PU16). |
| Order | The decode, the limit and the values are static checks. They come before the token check, as the checks 4 to 6 of R-AP66 (Design Q144). The whole order of the publish path: R-AP75. |
| Order of the values (Design Q291) | Fact by fact in the order of the body. In one fact: `nightly`, then `target`, then `result` (the order of the members above, as `hash`, `nightly`, `result` in R-AP66 check 6 and R-AP70 row 8). The first fault is the answer. `error_digest` has no value check (text or `null`). |
| Answer | The answer is the record of R-AP8. The facts add no member. |

R-AP75: The publish path of `POST /v1/releases` (R-AP8, R-PU1, R-PU2, R-PU5, R-PU16, R-TP3, Design Q290 to Q298; slice 114). The first check that fails gives the answer. This is R-AP48 for this path. It shares rows 1 to 4 with R-AP70, the body rules with R-AP66, and the rows after the token with R-AP68. All D1 calls of the request go to one session `with_session!(Primary)`.

| # | Check | Answer | D1 calls |
| --- | --- | --- | --- |
| 1 | The path and the method (R-AP48 rows 1, 2), then the client version (R-AP45), then the media type (R-AP23), in the order of R-AP70 rows 1 to 3. The request has an `Authorization` header (R-AP26): it selects this path. | 404, 405 with `Allow: GET, POST`, 400 `unsupported-client`, 415 | 0 |
| 2 | The body is larger than 256 KB (R-AP46) | 413 `too-large`, `field` `body` | 0 |
| 3 | The body does not decode (R-AP51, R-AP71): not UTF-8, not JSON, not an object, `url` missing or not text, `compat` of a wrong type, a fact with a member missing or of a wrong type, a member `hash` or `source` in a fact (R-MX5) | 400 `bad-request`, the `detail` names the member | 0 |
| 4 | More than 500 facts (R-AP71) | 413 `too-large`, `field` `compat`, `limit` 500 | 0 |
| 5 | The values, fact by fact in the order of the body. In a fact: `nightly`, then `target`, then `result` (Design Q291). | 400 `bad-request` | 0 |
| 6 | The URL rules (R-PU34 row 4, R-PU40, CLI 7.3, R-DI5): a `github.com` release asset URL. This gives `owner/repo` and the tag for rows 7 and 8 (Design Q290, Q292). | 422 `not-a-candidate` | 0 |
| 7 | The token, in this order: more than 8192 bytes, the form `Bearer <token>`, the structure, the signature and `iss`, `aud`, `exp` and `nbf` (R-TP3 rows 1 to 3, R-TP16, R-TP17), with the read of the JWKS. | 401 `unauthenticated`; 502 `upstream` (the JWKS read); 500 `internal` (a missing setting) | 0 |
| 8 | The claims against the URL, in this order: R-TP3 rows 4, 6, 7, 8 (`repository`, `repository_visibility`, `ref_type` and `ref`, `event_name`). Then the form of the ids: `repository_id`, then `repository_owner_id`, each a number (Design Q293). | 403 `forbidden`, the `detail` names the claim | 0 |
| 9 | D1 call 1, one read batch: the label row (group, version) with its hash and whether it has an `oidc` provenance row, and the `repos` row of the name. | | 1 |
| 10 | The ids of the claims against the `repos` row (R-TP3 row 5, R-TP9). The 403 comes before the 409 of row 11 (Design Q294). | 403 `repository-changed` with `issues_url` (R-TP12), no more D1 call, no GitHub read, no `Talon-Bookmark` | 1 |
| 11 | The label (R-PU14, R-PU16, R-PU19). Another hash: 409 `label-conflict`. The same hash with an `oidc` row, and no fact and no identity event to write: 200 with the record, no write. The same hash and something to write: D1 call 2 (row 15) with no GitHub read, 200. No row: row 12. | 409; 200 | 1 |
| 12 | `GET /repos/{owner}/{repo}/releases/tags/{tag}`, then the candidate rules (R-PU6, CLI 7.3, R-DI3, R-DI4). There is no `GET /repos/{owner}/{repo}`: the visibility is the claim (R-PU31, row 8). | 404: 422 `not-a-candidate`, the `detail` names the draft (Design Q297). A draft: 422 `not-a-candidate`, the `detail` says `draft`. Prerelease, 0 or 2 package assets, another asset, no `published_at`: 422. Another status, no answer, an answer that is not a release: 502 `upstream`. | 1 |
| 13 | The archive read (R-PU38) | 422 `not-a-candidate`; 502 `upstream` (as R-AP68 row 9) | 1 |
| 14 | `GET https://raw.githubusercontent.com/{owner}/{repo}/{tag}/.roc-version` (as R-AP68 row 10) | 502 `upstream` | 1 |
| 15 | D1 call 2, the write batch (R-SG8, R-IK3, R-PU15, R-PU26, R-TP5, R-TP13): the release rows only for a new release, the `oidc` provenance row, the identity statements, the facts (R-PU5), last the read of the label | 201 with `Location` for a new release, 200 when the batch wrote no release. The trigger `label-conflict`: 409 (as R-AP68 row 11, Design Q164). The `names.id` collision: D1 call 3, then 409 `id-collision` (R-IK3). | 2, or 3 |
| 16 | After the answer (`Response.after`): the cache drop of R-AP69, after a 201, and after a 200 of row 11 or 15 that wrote | None | Not counted |

The details:

| Item | Rule |
| --- | --- |
| Static checks first (Design Q290) | Rows 2 to 6 cost no D1 call, no GitHub call and no JWKS read, and they show nothing that the registry does not publish (R-AP48 row 7, Design Q144). The URL rules are before the token because row 8 needs `owner/repo` and the tag of the URL, and because R-AP68 row 2 puts them right after the body. A request with a bad body and a bad token gets the 400, and a request with a bad URL and a bad token gets the 422. The values (row 5) come before the URL rules, because the facts are part of the body (R-AP71). |
| Other host (Design Q292) | A URL of another host is 422 at row 6 (R-PU40), never 403. The test of the host in the claim check (R-TP3 row 4) stays in the code of the token check as a guard that no request reaches. |
| Claim rows (Design Q293) | Row 8 runs the claim rows by their number, but the id row of R-TP3 row 5 is in two parts: the form of the two ids here (the claims alone), and the compare with the `repos` row at row 10 (it needs D1). So a token with a bad ref and ids that differ from the row gets the 403 `forbidden` of `ref` (as the visibility before the ids in Design Q263). A missing claim or a claim that is not a number (digits only, at most 2^64 - 1) is 403 `forbidden`, the `detail` names the claim. Both ids must be numbers, also when one of them is equal to the row: the `repos` row keeps both (R-TP5). 403 is the status of the other claim rows 4 to 8. 401 is only for a token that is not valid (R-TP3 rows 1 to 3). |
| 403 and 409 (Design Q294) | `repository-changed` comes before `label-conflict`. R-TP3 row 5 is a check of the token, and R-AP8 lists the 403 as the token check of R-PU1: an account that does not own the name gets no answer about the state of its labels. The ingest differs (R-AP68 row 4 before row 6): it has no ids before its GitHub read, so it cannot compare them at its call 1. A publish has the ids at once, so it compares them at call 1. |
| Limits (Design Q296) | A publish has no IP limit and no owner limit (R-PU34 row 5). |
| Draft (Design Q297) | The Worker reads the release with the installation token when the App is installed on the repository (R-PU25), and then it sees a draft. Else a draft is a 404. So 2 texts, both 422 `not-a-candidate`: a draft that the Worker sees says `draft`, and a 404 says that there is no published release with the tag and that a draft is not published. The text is for the author, who can fix it, so it can name the cause (as R-PU32 for a publish). |
| Recorded claims (Design Q298) | The `claims` of the `oidc` provenance row and of each `repo_events` row that the token caused are one text: the 8 claims of R-TP6, in the order of R-TP6, a missing claim as `null` (R-AP51). The rows of one request have the same text. A repeated publish adds no provenance row (R-PU15) and the events of its own token carry its own claims. The form of the text is a proposal (CLI 3, R-OUT2, TW24). |
| D1 calls | A good request 2. A refusal at rows 1 to 8: 0. At rows 9 to 11: 1. A 409 `id-collision`: 3 (R-AP41). No D1 call before the token check. |
| Texts | The `detail` texts of this path are proposals (TW24), except the names of the member, of the claim and of the problem. They are in the slice file. |

R-AP72: The types of the user hint request and of the answers of `POST /v1/compat` in `records` (R-AP10, R-AP70, Design Q191; slice 104f). They are API types (R-PK7). `tln` sends the hint request (CLI 1, R-SH4) and reads its answer (R-SH6). The Worker keeps its own checks of the hint body (`Hints.parse`, slice 116a) and their 400 texts.

| Type | Members | Rule |
| --- | --- | --- |
| `Compat.HintRow` | `hash`, `nightly`, `target`, `result` | Texts as sent. The type has no `error_digest` and no `source` (R-CT2). The Worker checks the values (R-AP70 row 8). |
| `Compat.HintPost` | `talon_version`, `rows` | Both are required, also for `rows: []` (Design Q172). `talon_version` is any text (R-CT12). The decoder gives `BadJson` for `error_digest` in a row, `sweep`, and `source` in the body or in a row, with any value, `null` too (R-AP70 row 6). So a fake registry in a `tln` test refuses what the Worker refuses. |
| `Compat.HintSkip` | `row`, `reason` | R-CT14. `row` is the index in the request, from 0. `reason` is text. A new reason is an addition that an older client ignores (R-AP44), so `tln` treats a reason that it does not know as a skip. |
| `Compat.HintAnswer` | `written`, `first`, `skipped` | All three are required. The writer writes them in this order, `skipped` as `[]` for none, and an item as `{"row":..,"reason":..}`. These are the bytes of the Worker (Design Q172, slice 116a section 6). The reader ignores the order. |
| `Compat.Written` | `written` | The answer of the bot path (R-AP10). The compat bot reads it (R-MX15). |

R-AP73: The answer types of the read routes and the account routes in `records` (R-PK7, Design Q192; slice 104e). Each answer has a type, a decoder and an encoder. The decoder follows R-AP51: a required member that is missing or `null` is `BadJson`, and an unknown member is ignored (R-AP44). The encoder of an answer that the Worker builds today gives the bytes that the Worker gives today (member order and form as in R-AP53, R-AP49 and R-SN6), so no ETag changes. Then the Worker calls the encoder in place of its own text builder, and its tests stay as they are.

| Route | Module and type | Members | The Worker builds it today |
| --- | --- | --- | --- |
| R-AP1, R-AP13, R-AP14 with `group` | `Index.Releases` | `releases` (rows of R-RE2), `checked` (one item or `null`, R-AP53), `repos` | `Reads.releases_body` |
| R-AP14 with no `group` | `Index.Page` | `releases`, `repos` | `Reads.page_body` |
| R-AP2 | `Index.Detail` | `artifact`, `releases`, `repos` | `Reads.artifact_body` |
| R-AP5 | `Toolchain.Page` | `toolchains` (rows), `more` | `Toolchains.page_body` |
| R-AP6 | `Toolchain.Put` | `toolchains` | `Toolchains.put_body` |
| Row of R-RE4 | `Toolchain.Row` | `tag`, `target`, `asset_name`, `sha256`, `published_at`, `log_index` | `Toolchains.row_text` |
| R-AP7 `short` | `Short.Matches`, `Short.Entry`, `Short.Item` | `matches` of entries `{short, matches}`. An item is `{name, first_log_index, state, moved_from}`, and `moved_from` is optional. | `Shorts.matches_body` |
| R-AP7 `q` | `Short.Packages` | `packages` of items `{name, first_log_index, state}` | `Shorts.search_body` |
| R-AP35 | `Account.Tracker` | `account` `{id, login}`, `machines`, `counted`, `first`, `agreed`, `disagreed`, `unconfirmed`, `first_time`, `last_time` (R-CT10). The counts and `account.id` are integers. The two times are integers in ms (R-AP50), or `null` for an account with no row. | No. Slice 117 uses the type. |
| R-AP37 | `Account.Token`, `Account.Login` | Answer: `token`, `expires_at` (integer ms), `account` `{id, login}`. Request: `github_token`. | No. Slice 117 uses the type. |

Not in this rule: R-AP4 `{runs, hints}`, R-AP39 `{sweep, log_size, members, missing}` and R-AP40 `{pairs}`. Only the compat bot reads them (R-MX15), but the Worker builds them, so their types are in `records` (modules `Work` and `Audit`, slice 104k, Design Q575). The release record of R-AP8, the closure answer (R-AP17), the `checked` and `repos` items and the problem (R-AP21) are in `records` already (slices 104, 104b).

R-AP74: How `tln` builds the closure query and reads its errors (Design Q194 to Q199; CLI plan G-C24 to G-C29).

| # | Item | Rule |
| --- | --- | --- |
| 1 | Exit code of an error answer to `POST /v1/closure` | "A write" in CLI 3, R-E6 means a route of the Write row of R-AP41 (the list in R-AP45). `POST /v1/closure` is a read (section 4). It answers 400 and 413 only (R-AP3): exit 1. Any other 4xx to it is "each other case": exit 15. The table of R-E6 applies to an answer that is problem details (R-AP52). An error answer that is not problem details is exit 15, for any status. |
| 2 | `unsupported-client` with no `minimum` | Exit 1, as with `minimum`. The message is `tln <version> is too old for <registry base URL>: update to the newest version` (a proposal, CLI 3, R-OUT2). With `minimum` it is the text of R-E6. A `minimum` that is not text is read as missing. The same holds for each optional member of a problem body (Design Q250, RFC 9457, 3.1): a `title`, `detail`, `issues_url`, `field` or `limit` that is `null` or not of its type (text; an integer for `limit`) is read as missing, and the body is still problem details. A `type` or `status` that is missing or of a wrong type is `BadJson` (R-AP52). |
| 3 | `range` of a group | A variable has one range for each constraint (CLI 7.3 and Resolution 2, R-C1, R-WS2): a range of `talon.toml` or an implied range, from each member. The client makes one `range` text: the distinct ranges in the order of first appearance (equal text is the same range), joined with `, `. A range text that has commas is one range and is joined as written. A version range is a list of comparators that a version must all match (`roc-semver` `VersionReq`), so the text is the intersection. A range `*` is dropped. If no range is left, `range` is left out. The same function makes the ranges of a moved variable (R-SP23). |
| 4 | No compiler is allowed (R-AP61) | A compiler list that cannot be read (an error answer, or `--offline` with no copy) is not an empty list: it is the case of `direct` (CLI R-CV1, Design Q489), and the same text and exit code hold with a registry. A bare `tln upgrade` keeps the nightly H, prints `note: the compiler list could not be read; roc stays <H>` and goes on; a name `roc` or a command with no held compiler fails with the failure of the list (exit 15). A command that must choose a compiler and has a list that was read, with no compiler left, stops before the query with exit code 10 (`no_tuple`). The message names the first cause that holds, in this order: the compiler list is empty, the nightly switch, the `[toolchain] roc` range, `min-release-age`, the snapshot (the order of R-AP16, `compilers`; Resolution 1, R-NS2). For the causes the nightly switch and the `[toolchain] roc` range, the text is the text of CLI R-SO13 (`Toolchain.range_failed`: `no compiler release is in [toolchain] roc (<range>)`, with `, and nightly is false (set by <source>)` when the switch is off). It is the same text with a registry and with `direct`, and it names the range and the switch together (Design Q468). A command that only reports sends the query with no `compilers` member. A command that has no compiler id when it sends the query (for example `tln update` with no `roc:` pin, no compiler on `PATH` and `--no-check`, so no probe needs one) is the same case: no `compilers` member, and the client uses no fact on a compiler for its choice (Design Q437). The answer then holds more facts than W needs (R-AP60), and the client uses no fact on a compiler. `tln` never sends `compilers` with both ends missing to mean "none": that is the whole domain (R-AP16). |
| 5 | `hashes` | The value of each header entry that has a hash, also when its group is in `groups`, each hash once (equal hash, whatever the URL), in the order of first appearance in the headers that the command reads. A repeated hash is not sent twice, because the Worker lists a repeated unknown hash twice in `unknown` (slice 110). |
| 6 | The compiler list | The registry lists nightlies only (R-AP57 step 1, R-CV1). A compiler release (a tag of `roc-lang/roc`) is not a row of `toolchains` in P2. The domain of releases stays empty (Resolution 1, R-NS2). A held `roc:` pin that is a release is a missing end of `compilers` (R-AP60). A later phase can add release rows with no change of the rows of R-AP5. |
| 7 | Reading of an error (checked, CLI 3, R-E6, R-J7) | The exit code comes from the HTTP status as R-AP52 says. `error.details` has `status` and `type` (the text as read). For an answer that is not problem details, `details` has `status` only. The request has `User-Agent: tln/<version>` (R-AP45), and `Content-Type: application/json` only when it has a body (R-AP23). |

R-AP80: The size and the download URL of a compiler (Design Q340; CLI plan G-C42). A row of R-RE4 on the wire (R-AP5, R-AP6) has these members, in this order: `tag`, `target`, `asset_name`, `sha256`, `size`, `published_at`, `log_index`.

| Item | Rule |
| --- | --- |
| `size` | The `size` of the asset in the GitHub release that R-PU8 reads: bytes, a whole number above 0. The Worker stores it with the row (column `toolchains.size`, `INTEGER NOT NULL`). It is written once, with the row, and never changes (R-PU9, R-PU10). Reason: `tln` shows the total size of the downloads before it asks (CLI 5, R-DL1), and the registry is the source of the compiler list (R-CV1). |
| Not in the leaf | The compiler leaf (R-SG3) keeps its form: group, tag, `sha256`. The size is not evidence of the code, so the log, the tiles and the trigger `toolchains_leaf_check` do not change. A client checks the downloaded bytes with `sha256` (R-CV3), not with `size`. |
| No `url` | The row has no download URL. `tln` builds it: `https://github.com/roc-lang/nightlies/releases/download/<tag>/<asset_name>`. This is the `browser_download_url` of a release asset of GitHub. `tag` and `asset_name` are safe path parts (R-CV2, R-SE18), so they need no encoding. Reason: a stored URL repeats 100 bytes in each of the 5 rows of a nightly, and a client must not take a download host from the registry (Design 8). |
| Schema | `sql/0001_init.sql` gets the column, with `CHECK (size > 0)`. No Worker is deployed yet (Design Q163), so the change is in the first migration and there is no `0003`. |
| Slices | Registry 109b (Worker: schema, `Toolchains` asset read, row text, SQL, W0 and W2 fixtures) and 104h (`records`: `Toolchain.Row.size`, codec). They go together: after 104h, `Toolchains.row_text` calls the records encoder. |

R-AP81: The platform mark of a dep (Design Q251; CLI plan G-C51). A closure answer must give the client the platform edge of a record, for `Release.pf` and for the platform check of CLI R-C3. The record of an app has `platform_hash` only (Design Q128). A package or platform record has its platform entry as a dep. So the dep carries the mark.

| Item | Rule |
| --- | --- |
| Dep member | Each dep of R-AP49 has `is_platform` (boolean, required, R-AP51). The writer writes `true` for the dep that the header names with the keyword `platform`, and `false` for the others. At most one dep of a record is marked, and an app record has none (Design Q400). |
| The decoder | `Artifact.decode` reads the marks as sent and refuses no count: 2 marks, or a mark in an app record, are not `BadJson`. Reason: the decoder is a reader (R-AP51) used by the CLI and the Worker, and the Worker never writes these cases, so a refusal would stop a resolve for a fact that the client can handle. |
| Schema | `deps.platform INTEGER NOT NULL DEFAULT 0 CHECK (platform IN (0, 1))` in `sql/0001_init.sql` (no Worker is deployed, Design Q163). The default keeps the existing `INSERT` of seeds valid. |
| Writers | Ingest and publish write the mark from the header parse (`entry.is_platform`, R-PU38 row 13). The read routes and the closure query give `platform` as `is_platform`. |
| The client | `Release.pf` of a package or a platform record is the `url` of its dep with `is_platform` `true`, and none when no dep has the mark. With 2 or more marks (a registry that breaks this rule), the client takes the first in the order of the answer (sorted by `alias`). A mark in an app record is not read. One function finds the platform dep of a record: the first marked dep of a package or platform record, and none for an app record. `Release.pf` is its `url`, and the entry flag `is_platform` of a dep is true only for that dep. So the flag and `pf` cannot disagree (Design Q401, Q402). An edge to the dep with the flag is a platform edge. An app record gives no `pf` here: R-C3 is about the packages that name a platform, and the platform of the app of the command is a header entry that the client has. The client needs no read of the archive for this. |
| Wire change | A member is added to each dep (R-AP44 row 1). The bytes and the ETag of the answers with deps change once. No Worker is deployed, so no stored copy is stale. |
| Slices | `records` 104i (`Artifact.Dep.is_platform` and its codec) and the Worker slice 125 (schema, ingest, publish, `ArchiveRead`, `Reads`, `deps_sql` of the reads and of the closure, the fixtures). |

R-AP82: The answers of a trap (`Worker.new({ on_trap })`, platform 0.0.3, `cloudflare-workers/API.md` 10.3, Design Q440; slice 123d). When the Worker traps or the shim cancels a request, the shim answers with a fixed response made at load. Every one is problem details (R-AP21), so `tln` reads it with R-AP52 and maps it by its status (R-E6: a 5xx is exit 15).

| Cause (TR2) | Status and `type` | `title` | `detail` | `Retry-After` |
| --- | --- | --- | --- | --- |
| `oom` | 503 `/errors/busy` | Busy | the Worker has no memory for this request | 1 (added by the shim, TR7) |
| `shed` | 503 `/errors/busy` | Busy | the Worker is busy: send the request again | 1 (added by the shim, TR7) |
| `cpu` | 503 `/errors/busy` | Busy | the request used its CPU budget | none |
| `deadline` | 503 `/errors/busy` | Busy | the request used its time budget | none |
| `alarm`, `cancelled` | 503 `/errors/busy` | Busy | the Worker stopped the request | none |
| `crashed`, `event`, `failed`, `default` | 500 `/errors/internal` | Internal error | a fault in the Worker | none |

Each response has `content-type: application/problem+json` and `cache-control: no-store`. The `title` depends only on the type, as for every other answer (the `Problem.title` of the Worker, slice 101): `Busy` and `Internal error` (Design Q463). The trap bodies and the other answers are made by the same code. The `detail` never has the text of the crash (TR8). A `cpu` or `deadline` answer has no `Retry-After`, because the same request would use the same budget again. The Cache API keeps no problem answer (R-AP43). The records type `Problem.Kind` gets the tag `Busy` (type `/errors/busy`, status 503) in a records slice 104j, so `tln` names the type (R-J7). An older `tln` reads it as an unknown type (R-AP52).

R-AP48: The order of the checks of a request. The first check that fails gives the answer:

| # | Check | Answer |
| --- | --- | --- |
| 1 | The path is a route | 404 `not-found` |
| 2 | The method is served on the path | 405 `method-not-allowed`, with `Allow` |
| 3 | The client version (R-AP45) | 400 `unsupported-client` |
| 4 | The size limits (R-AP46) | 413 `too-large` |
| 5 | The media type, when the request has a body (R-AP23) | 415 `unsupported-media-type` |
| 6 | The body and the query parse | 400 `bad-request` |
| 7 | The route | Its own answers. An `Err` that the route does not map gives 500 `internal`. |

Row 7 holds the token check of a route that needs a token (R-TP3, R-TP7, R-AP26). So a body that fails rows 4 to 6 gets its 413, 415 or 400 with no token check (Design Q144, R-AP66). Reasons: these checks cost no D1 call and no JWKS read, and they show nothing that the registry does not publish. A garbage request then does not make the Worker verify a signature. The webhook (R-AP12) is the one route with another order: its signature check is local (an HMAC over the raw bytes, no D1 call, no network call), so it comes before row 6 (R-AP79, Design Q320).

The Worker code never uses `crash` for a fault at run time: a `crash` gives a plain text 500 from the platform, not problem details (R-AP21).

R-AP49: The records on the wire (Design Q70, Q73, Q74, Q94, Q102). A release (R-RE2), an artifact (R-RE1) and a dep (R-RE19) have these JSON members, in each answer that has them (R-AP1, R-AP2, R-AP8, R-AP13, R-AP14, R-AP17, R-YK1). A toolchain row (R-RE4) has them in R-AP5 and R-AP6. The text forms are the forms of R-IK1. "Or null" means that the member is always there, with `null` for none (R-AP51).

| Record | Member | Type | Value |
| --- | --- | --- | --- |
| Release | `log_index` | integer | The log index of the release (R-IK6) |
| Release | `hash` | text | The hash of its artifact, base58 |
| Release | `group` | text | The URL form of the group (R-AP15) |
| Release | `series` | text | The series (R-AP15) |
| Release | `version` | text | `Semver.to_str` of the version (R-IK5) |
| Release | `url` | text | The asset URL, with the scheme (R-IK5). For an ingest, the `url` of the request as sent (R-AP68, Design Q159). For the webhook and the reconcile, the asset URL as the release gives it. |
| Release | `tag` | text or null | The GitHub release tag. `null` on another host. |
| Release | `roc_version` | text or null | The text of the `.roc-version` file at the tag, with no white space at the ends (Resolution 3, rank 4). `null` when the tag has no such file, and on another host. |
| Release | `repo` | text or null | The GitHub name `owner/repo` in lower case (R-IK2, R-RE11), the `name` of its `repos` item (R-AP32). `null` on another host. |
| Release | `published_at` | time (R-AP50) | The time that GitHub gives for the release. On another host, the time that the Worker indexed it. |
| Release | `yanked` | boolean | R-YK4. Always `false` before P3. |
| Release | `yank_reason` | text or null | The `reason` of the last yank (R-YK1, R-YK6). `null` when the release is not yanked or the yank has no reason. |
| Release | `withdrawn` | text or null | The value of R-PU17, R-PU20 or R-PU24: `deleted`, `unpublished`, `prereleased`, `edited`, `asset-replaced`, `repo-missing`. `null` when the release is not withdrawn. This is not a closed set for a reader: a value that the reader does not know is kept as text, and the release is not a candidate (CLI 1, R-AU2). |
| Release | `provenance` | list of text | The `via` of each `provenance` row of the release (R-PU15): `oidc`, `webhook`, `poll`, `ingest`, strongest first in this order (Design 8, R-SE3, Design Q158). Each release has at least one: every write path adds the row in the same D1 batch as the release (R-SG8, R-PU15), so a release with no row cannot be made by the Worker. No trigger guards this (the row follows the release in the batch, so an `AFTER INSERT` trigger on `releases` would always fail). A read of a release with no row (a data fault) gives `[]`, not 500 (Design Q341). Not a closed set for a reader: a value that the reader does not know is kept as text, after the values that it knows (R-AP44). Unknown values go in ascending byte order of their UTF-8 text, so the order is total and does not depend on the query (Design Q342). |
| Artifact | `hash` | text | The hash, base58 |
| Artifact | `kind` | text | The kind of the header of the archive: `app`, `package` or `platform`. A closed set (R-AP44), codes 0, 1 and 2 (R-IK7). An app release is a bundle, as a package release is (Design 2). |
| Artifact | `exposed` | list of text | The module names in `exposes` of the header, in the order of the header. Empty for an app. |
| Artifact | `platform_hash` | text or null | For an app: the hash of the platform that its header names. `null` for a package, a platform, and an app that names no platform (R-PU38 row 16). |
| Artifact | `roc_pin` | text or null | The `roc:` entry of the header, as text (Design 2). `null` when the header has none. |
| Artifact | `size` | integer | The bytes of the `.tar.zst` asset (R-PU38 row 2). It gives the total of the download progress (CLI 7.5, R-DA6). |
| Artifact | `deps` | list of dep | One item for each row of R-RE19, sorted by `alias` |
| Artifact | `target_names` | list of text | The names of the targets of a platform (R-RE20, R-IK7), sorted. Empty for an app and a package. |
| Dep | `alias` | text | The alias in the header |
| Dep | `hash` | text | The hash of the dependency, base58 |
| Dep | `group` | text | The URL form of the group of the dep URL (R-AP15). For a URL with no version (R-RE19): the URL with no scheme and with no last segment (`<hash>.tar.zst`), and with no `{v}`. The Worker makes it from `url`, because `deps.form` is NULL. No release has such a group, because a release URL has a version (Design R-H3). |
| Dep | `series` | text or null | The series. `null` when `version` is `null`. |
| Dep | `version` | text or null | `Semver.to_str` of the version of the URL. `null` when the URL has no version (R-RE19). |
| Dep | `url` | text | The URL in the header |
| Dep | `is_platform` | boolean | `true` when the entry is a platform entry of the header (a `platform` entry of a package or platform header, R-PU38 row 13). `false` for each other dep. The name is not `platform`, which is a reserved word of Roc (as `platform_hash`). R-AP81. |
| Toolchain | `tag` | text | The tag of the nightly, as GitHub gives it |
| Toolchain | `target` | text | The asset target of CLI 6.2, R-CV8 (`linux_x86_64`) |
| Toolchain | `asset_name` | text | The name of the asset |
| Toolchain | `sha256` | text | 64 lower-case hex digits, with no `sha256:` prefix (the prefix is only in the leaf, R-SG3) |
| Toolchain | `published_at` | time (R-AP50) | The `published_at` of the GitHub release (R-MX16) |
| Toolchain | `log_index` | integer | The log index of the compiler leaf of the asset (R-SG8) |

The names `exposed`, `platform_hash` and `target_names` are not the names of R-RE1 and R-RE20 (`exposes`, `platform`, `targets`). Reasons: those 3 words are reserved words of Roc, so a Roc record field cannot have them, and a JSON name that is equal to the field name needs no rename in the codec. The new names are also clearer: `platform_hash` tells that the value is a hash, and `target_names` that the values are names, not codes (R-IK1). The Worker sorts each list as the table says, so that 2 answers of one state have the same bytes and the same ETag (R-AP24). A reader does not depend on the order of the members.

R-AP50: Times on the wire (Design Q71). Each member of the API that holds a point in time is a JSON integer: milliseconds since 1970-01-01 00:00 UTC, the value of its D1 column (R-RE26). These are `published_at` (R-AP49, R-RE4), `checked_at` (R-AP29), `state_at` (R-AP32), `expires_at` (R-AP37), and each later time member. Reasons: one form in D1 and on the wire, so the Worker does no conversion. A number compares with no parse. The values are below 2^53, so a JSON reader keeps all digits. A time from GitHub has whole seconds, so the `published_at` of a GitHub release is a multiple of 1000. A client that keeps seconds (for example `Domain.Candidate.published_at` in `packages/resolve`) divides by 1000 at its edge and loses nothing of a GitHub time. A query parameter that is a time uses the same form.

R-AP51: Missing members and `null` (Design Q76). Each member of a request rule (R-AP16, R-AP10, ...) and of an answer rule (R-AP17, R-AP49, ...) is required, unless the rule calls it optional. The writer writes each required member, with `null` where the rule allows it. It leaves out an optional member that has no value. The reader acts as follows:

| Case | The Worker reads a request | `tln` reads an answer |
| --- | --- | --- |
| A required member is missing | 400 `bad-request` (R-AP48 row 6). The `detail` names the member. | The answer is not used. Exit code 15 (CLI 3, R-E6, last row). The message names the registry URL and the member. |
| An optional member is missing, or is `null` | The member has no value. Its rule gives the effect (for example no `series` in R-AP16: all series). | As for the Worker |
| `null` for a required member that the rule does not allow to be `null` | 400 `bad-request` | As a missing required member |
| A member with the wrong JSON type, or a value that is not in its closed set (R-AP44) | 400 `bad-request` | As a missing required member |
| A member that the reader does not know | Ignored (R-AP44) | Ignored (R-AP44) |

An empty list (`[]`) is a value, not a missing member. Reason for an error, not an empty value: an empty value in place of a missing `artifacts` or `log_size` gives a resolve with no candidates, or a wrong `log:N`, with no message. A member that a later Worker adds to an answer in `/v1` (R-AP44 row 1) is optional for the reader: the rule that adds it says what a missing one means, so a newer `tln` works with an older Worker.

R-AP52: A problem type that the client does not know (Design Q77). A problem body (R-AP21) with a `type` that is not in the table of R-AP21 is still problem details. The decoder keeps the `type` text as read, `status`, `title` and `detail`, and the extra members that it knows (`field`, `limit`, `minimum`, `issues_url`). `tln` maps it by its HTTP status (R-AP44, CLI 3, R-E6), and `--json` gives the `type` text as read in `error.details.type` (CLI 3, R-J7). Reason: a later Worker can add a problem type in `/v1` (R-AP44). A body with no `type`, with no `status`, or that is not JSON, is not problem details (CLI 3, R-E6, last row).

R-AP44: Changes to the API. A change that an older client can ignore stays in `/v1`. Any other change needs `/v2`:

| Change | Where |
| --- | --- |
| A new route, a new answer field, a new problem type | `/v1` |
| A new optional request field or query parameter, when an answer that ignores it holds the same facts or more (as `compilers` of R-AP16) | `/v1` |
| A removed or renamed field, a changed type or meaning, a new required request field | `/v2` |
| A new value in a closed set: `result`, `source`, `side`, `state` (R-AP32), `kind` | `/v2`. Reason: an older client cannot know what a new `result` value means for a resolve. |

| Side | Rule |
| --- | --- |
| `tln` | It ignores an answer field that it does not know, as for its own files (CLI 6.1, R-TF2). It maps a problem type that it does not know by the HTTP status (CLI 3, R-E6). |
| Worker | It ignores a request field and a query parameter that it does not know. So a newer `tln` works with a registry that runs an older Worker (`TALON_REGISTRY`, CLI 1). |
| Both versions | One Worker serves `/v1` and `/v2` for at least 12 months (first guess) after the first Talon release that uses `/v2`. After that, R-AP45 refuses the old clients. |

R-AP45: The client version. `tln` sends `User-Agent: tln/<version>` (RFC 9110, 10.1.5) with each request. The Worker has 2 settings, both empty by default:

| Setting | Routes | Use |
| --- | --- | --- |
| `MIN_TLN_WRITE` | The write routes of R-AP41: the routes of its Write row with their methods (`PUT /v1/toolchains/{tag}`, `POST /v1/releases`, `POST /v1/compat`, the move route of R-AP31, `DELETE /v1/contributors/me`, `POST /v1/tokens`, `DELETE /v1/tokens`, the yank routes of R-YK1). `POST /v1/closure` is a read: it changes no state (section 4). The webhook (R-AP12) has the agent of GitHub, so no setting applies (Design Q182). | A Talon release with a bug that writes bad data: hint rows, ingests |
| `MIN_TLN` | All routes | The end of `/v1` (R-AP44) |

A request whose `User-Agent` is `tln/<v>`, with `v` lower than the setting of its route, gets 400 `unsupported-client` with the member `minimum`. A request with another `User-Agent` (a browser, `curl`, the compat bot) is not checked. The version is compared by semver precedence, not as text, so `tln/0.10.0` is above `0.5.0`, a pre-release is below its release, and a version equal to the setting passes. The Worker reads the first product of the header: the text from the start to the first space, which must be `tln/` and a version (RFC 9110 10.1.5 allows a comment or more products after it, so `tln/0.4.1 (linux)` is the version 0.4.1; Design Q184). A header that starts with another product (`curl/8 tln/0.4.1`), a version that is not a semver (`tln/dev`) and a missing header are not checked. A setting that is empty, missing or not a semver is not applied (Design Q183). Reasons: a client that the Worker cannot place gets no refusal that it cannot act on, and a typo in a setting does not stop all clients. The operator tests a new setting with one request. The Cache API keeps only 200 answers, so a refused request puts nothing in the cache. The hint body keeps `talon_version` (R-CT12), because the Worker keeps it only for a Talon release, and the hint rows count by it. The setting names are a proposal.

R-AP46: Size limits (first guesses). Each list goes to D1 as one JSON parameter (R-AP41 row 2), and one D1 statement has at most 100 KB. 300 groups of about 110 bytes and 1000 hashes of about 50 bytes are about 85 KB in one statement. Without the check, D1 fails and the answer is 500 `internal`.

| Item | Limit |
| --- | --- |
| The request body of each route except the webhook | 256 KB |
| The request body of `POST /v1/webhooks/github` | 1 MiB (1,048,576 bytes), R-AP79 |
| `groups` of R-AP16 | 300 |
| `hashes` of R-AP16 | 1000 |
| `short` values of R-SN1 | 50 |
| `rows` of R-AP10 | 500 (R-CT2) |

A request over a limit gets 413 `too-large`, with the members `field` and `limit`. The Worker checks the limits before it reads D1. `tln` keeps to them: the share queue sends at most 500 rows (CLI 1, R-SH4). A project with more groups or hashes than the limit is past what Talon supports now, and R-E6 gives exit code 1 with the limit in the message.

R-AP78: The limits in `tln` (Design Q204). `tln` checks each limit of R-AP46 before it sends a request, and it never splits a request into 2 or more. With a list over its limit, it sends no request:

| Item | `tln` does |
| --- | --- |
| `groups` (300) or `hashes` (1000) of a closure query, or a closure body over 256 KB | Stops with exit code 1 (`internal`, CLI 3, R-EC1). The message names the item, the count and the limit: the project is past what Talon supports now (R-AP46). |
| More than 50 short names in one command (R-SN1, CLI 2, R-AD34) | Stops with exit code 2 (`usage`). The message names the limit, and says to use full names (`owner/repo`) or 2 commands. |
| `rows` of a user hint request (500) | The share queue sends at most 500 rows in one request (CLI 1, R-SH4), and `tln probe --share` sends the facts of one hash in requests of at most 500 rows each. These are separate writes, so a split changes no fact (R-CT4). |

Reasons for no split of a read: the 2 answers of a split closure query come from 2 states of the database, so the one `log_size` of R-AP18 is lost, and the second search of R-AP16 already uses the one round trip that is left (R-AP3). CLI 2, R-AD34 sends all short names of a command in one request for the same reason. The text of the messages is a proposal (CLI 3, R-OUT2).

R-AP47: The compiler list grows with each nightly: about 5 rows of about 200 bytes, about 365 KB of JSON a year, and the trim (R-CT15) does not remove them. Each new nightly changes the ETag. So `tln` does not read the whole list again. Each row has its own log leaf (R-PU9), so its own log index, and a row never changes (R-PU10). `tln` keeps the rows in `talon/index/` (CLI 6.1), and asks only with `after=<largest log index it has>`, page by page while `more` is true. With `--snapshot log:N`, it hides the rows with a log index greater than N (R-AP19). After `tln cache clean`, it reads the list again from `after=0`. The page limit also keeps each batch far below 1 MiB (R-AP41 row 6).

R-AP25: Any route can answer 429 `rate-limited` with a `Retry-After` header in seconds. Q30 sets the limits of ingests (R-AP9), and R-CT11 sets the limits of user hints. `tln` stops with exit code 15, and the message gives the time when it can try again, as for GitHub (CLI 7.3, R-DI13). The share queue is the exception: a 429 answer keeps its rows and changes no exit code (CLI 1, R-SH4).

R-AP26: A publish and an ingest use one route, `POST /v1/releases`. The `Authorization` header selects the path: a token is a publish (R-AP8), no header is an ingest (R-AP9). A token that fails the check gets 401 or 403, never an ingest. A body with `compat` and no token gets 401 `unauthenticated`, because author facts need the token (R-PU5). The order of the checks of a publish: R-AP75.

R-AP27: `tln publish` sends no request when it has no OIDC token. In GitHub Actions, the token needs `permissions: id-token: write`. Talon stops, and the message names that permission. So a missing permission never gives an ingest with no provenance and no author facts. The exit code is 2 (CLI 3, R-EC2).

R-AP79: The webhook path of `POST /v1/webhooks/github` (R-AP12, R-PU11, Design Q320 to Q322, Q326, Q327; slice 118). The first check that fails gives the answer. The route is not a `tln` route, so it has no client version check (R-AP45) and no D1 call (R-AP41).

| # | Check | Answer |
| --- | --- | --- |
| 1 | The path and the method (R-AP48 rows 1, 2) | 404 `not-found`, 405 `method-not-allowed` with `Allow: POST` |
| 2 | The body is larger than 1,048,576 bytes (R-AP46) | 413 `too-large`, `field` `body`, `limit` 1048576 |
| 3 | The media type is not `application/json` (R-AP23) | 415 `unsupported-media-type` |
| 4 | The secret `GITHUB_WEBHOOK_SECRET` is missing or empty (R-WH14) | 500 `internal`, with the fixed `detail` of R-AP48. Never the empty key. |
| 5 | The header `X-Hub-Signature-256` is missing, is not `sha256=` and 64 hex digits, or is not the HMAC-SHA256 of the raw body bytes with the secret. The compare is constant time. | 401 `unauthenticated`, one `detail` for all causes |
| 6 | The header `X-GitHub-Event` is missing or empty | 400 `bad-request` |
| 7 | The event is not `release`, `repository`, `installation` or `installation_repositories` | 202, no message. The body is not read, so a body that is not JSON is also 202. |
| 8 | The body is not a JSON object with a text `action`, or the ids of the event are not valid (R-PU11) | 400 `bad-request` |
| 9 | The action is not one that the Worker uses (R-PU11) | 202, no message |
| 10 | The message is sent to `INDEX` | 202 with `cache-control: no-store`. A send that fails: 500 `internal`. |

| Decision | Reason |
| --- | --- |
| Signature before the body parse (Design Q320) | The reason of R-AP48 for rows 4 to 6 before the token is that they cost no D1 call, no JWKS read and show nothing. A signature check has the same cost: it is local, and an HMAC of 1 MiB takes about 2 ms. So the reason does not keep the parse before the signature. The signature first keeps bytes that nobody signed away from the JSON parser, which costs more CPU in wasm than the HMAC. GitHub says to verify the signature before the payload is used. The price: a body that is not JSON, with a bad signature, gets 401 and not 400. |
| No `X-GitHub-Event` (Design Q321) | GitHub sends the header with every delivery (GitHub docs). A signed request with no event did not come from GitHub as it is, so it is a fault of the sender, not an event to ignore. 400 shows in the delivery list of GitHub. The check is after the signature, so an unsigned request still gets 401. |
| Missing or empty secret (Design Q327) | A fault of the operator, not of the client: 500 (R-PU43 is the same for the App settings). The check is after rows 1 to 3, which need no secret, and before the signature header, so a deploy without the secret gives 500 for any request that gets past them. |
| 1 MiB (Design Q326) | R-AP46 gives 256 KB for the reason of one D1 statement. The webhook body goes to no D1 statement, so that reason does not apply. A `release` payload that GitHub sent was measured on 2026-11-02 (`GET /repos/{owner}/{repo}/releases` of `roc-lang/basic-cli`, `roc-lang/roc`, `BurntSushi/ripgrep` and `cli/cli`, with the repository object): 20 to 56 KB for a release object, 6 to 7 KB for the repository, 1.5 to 1.7 KB for each asset. So a normal payload is 30 to 70 KB. The `edited` action also holds the old text of the release body (`changes.body.from`), and a release body can have 125,000 characters (GitHub docs), so an `edited` event of a long body is about 260 KB with ASCII text and about 760 KB with 3-byte characters. A release can also have many assets (about 150 assets fill 256 KB). An `installation` event for all repositories of a large account lists each repository. 1 MiB holds these cases. GitHub does not send a payload over 25 MB at all (GitHub docs). A body over 1 MiB gets 413: GitHub shows a failed delivery, and the reconcile finds the change (R-PU18, R-PU21), at the latest after 24 h for a repository with the App (R-PU22). |

R-AP34: `tln publish`, `tln yank` and `tln move` send their request again after a 429 answer, a 5xx answer or no answer: at most 3 more times (first guess). Each wait is the `Retry-After` of the answer when it has one (at most 60 s), else 2 s, 8 s and then 30 s. After a 401 answer, they get a new OIDC token (7.1, R-TP2) and send the request once more, because a token lives a few minutes. These writes are idempotent (R-PU14, R-YK1, R-AP31), so a request that is sent again writes nothing twice. After the last try, R-AP22 applies. The compat bot also sends its reads again, by the same schedule (R-MX18 item 14, Design Q594). Other commands do not send a request again, also a read that gets 503 `/errors/busy` (R-AP82): it is exit 15 at once, and the message says that the registry is busy and gives the `Retry-After` time when the answer has one (Design Q445): an ingest (R-AP9) stops at once (CLI 2, R-AD35). A user hint (R-AP10) is idempotent, because a contributor counts once for a pair (6.1, R-CT4). But the command does not wait for it: the rows that were not sent stay in the queue, and a later command sends them (CLI 1, R-SH4).

R-AP29: `checked` tells how old the index of a GitHub repository is. `checked_at` is the last time that the Worker read the release list of that repository (R-PU21), or `null` when it has not read it since the first ingest. `stale` is true when `checked_at` is `null` or is older than 2 intervals of R-PU22 for that repository. The Worker computes `stale`, because only the Worker knows the interval of each repository.

R-AP30: When an answer has a `stale` repository, `tln update`, `tln upgrade` (each form that sends the closure query), `tln outdated` and `tln add` print one note for each such repository (also after an error of the command, on stderr; `install`, `verify`, `why` and `list` print none; Design Q533, Q537): `index: <owner>/<repo> checked <age> ago`, or `index: <owner>/<repo> not checked since its first ingest`. The note does not change the exit code. The text and the `--json` field are a proposal (CLI 3, R-OUT2), with these rules (Design Q406 to Q408, Q540): the human line has the `note:` prefix, comes after the other notes (`update`, before `check:`) or after the table (`outdated`), and `--quiet` hides it.

| Item | Rule |
| --- | --- |
| `repos` states | Slice 210 shows no `repos` state. R-PU28 to R-PU30 are P3 (client part). The client decodes `repos` and reads nothing from it before P3. |
| Age text | `<n>d` from 86400 s, else `<n>h` from 3600 s, else `<n>m`, rounded down. Under one minute: `0m`. A time after now is `0m`. |
| `--json` | `data.notes` stays a list of texts (CLI 3, R-J6: a change of its type is a new `schema`). The text of each index note is in `notes` as for every note. A command that has at least one index note also has `data.index_notes`: a list of `{kind, name, checked_at, text}`, with `kind` `index-stale`, `checked_at` in ms (R-AP50) or `null`, and `text` equal to the note. With no index note the member is left out, so no existing output changes. |
| Two answers | A held move has 2 answers (R-AP16). One note for each repository: from the stale items of both answers with that `name`, the one with the older `checked_at`, and `null` is older than any time. A fresh item and a stale item: the stale one gives the note. The notes are sorted by `name` (bytes). |

R-AP32: Each answer that has releases of a `github.com` name (R-AP1, R-AP2, R-AP13, R-AP14, R-AP17) also has `repos`: one item for each such name, `{name, state, successor, state_at}` from the `repos` row (R-RE11, section 7.3). `state` is `active`, `missing` or `moved`. `successor` is the name of R-TP14, or `null`.

R-AP41: D1 round trips. Each D1 call is one network round trip from the Worker to a D1 instance: 70 to 98 ms from `TBS` to `EEUR` (section 8, edge results). Rows add less: 200 rows took about 15 ms more than 20 rows. So the time of a route is about the count of D1 calls that run one after the other times the round trip, plus the SQL time, plus the GitHub reads. Each route keeps to this budget:

| Route kind | D1 calls before the answer | How |
| --- | --- | --- |
| Read: R-AP1, R-AP2, R-AP3, R-AP4, R-AP5, R-AP7, R-AP13, R-AP14, R-AP35, R-AP39, R-AP40 | 1 | One statement or one batch |
| Write: R-AP6, R-AP8, R-AP9, R-AP10, R-AP31, R-AP36, R-AP37, R-AP38, R-YK1 | At most 2 | An optional read batch that can stop the request before a GitHub read or a download, then one write batch whose last statement reads the answer |
| Error detail (R-IK3, R-MX9) | 1 more | Only after the write batch failed |
| Work after the answer (`Response.after`, `cloudflare-workers/API.md` 10.2, R-SG7) and in a queue consumer (R-PU11, R-PU13) | Not counted | One batch for each step where it can |

| # | Rule for one call |
| --- | --- |
| 1 | A query that needs the result of an earlier query puts the dependency in SQL: a JOIN, a subquery, or a recursive CTE (the closure, the successor chain of R-AP33). In a batch, each statement can have the same CTE. The Worker computes each id with no read (R-IK2). |
| 2 | A list in a request (the groups and hashes of R-AP16, the names of R-SN1, the rows of R-CT4) goes as one JSON parameter, read with `json_each(?)`. Reason: one D1 statement has at most 100 bound parameters and 100 KB (Cloudflare D1 limits). |
| 3 | A write that must stop on a condition uses a trigger with `RAISE` (R-MX8, Q27) or a `WHERE` clause on the write. A read before the batch is only for a check that can end the request early, or that needs a value from outside D1. The write batch makes that check again, because another request can write between the 2 calls. The owner count of an ingest (R-PU34 row 2, R-AP68 row 5) is an exception: a soft limit, checked only in the read. The ids of an ingest (R-TP9) are the other exception (Design Q262): the batch guards each change of a `repos` row with the ids that the read saw (`UPDATE` with the old ids in `WHERE`, each event with `changes() > 0`), and it does not compare the ids of GitHub with a row that changed after the read. Reason: between the 2 calls a row changes only by a change that R-TP9 accepts, and a request that shares one id with the old row shares one with the new row, unless the row changed twice in about 100 ms. The release is public data with a hash that was checked, and the next write of the name is checked again. |
| 4 | A filter that SQL cannot do (`VersionReq.matches`, R-IK5) reads a superset in SQL and filters in Roc. It does not add a call. |
| 5 | A read route runs its batch in one session, `with_session!(Any)`, so a read replica can answer. A batch is one transaction, so R-AP18 holds. Writes go to the primary. A read after a write of the same client (Q46): each write answer (R-AP8, R-AP9) has the header `Talon-Bookmark` with the D1 bookmark of its batch. `tln` sends the largest bookmark it got with its next read request, in the same header, and the Worker reads with `with_session!(After(bookmark))`. A request with no header reads with `Any`. The header name is a proposal (CLI 3, R-OUT2). Exception: the tracker (R-AP35) reads the primary, as the 3 other account routes (R-AP36 to R-AP38), because its token check reads `tokens_after` and a revoke (R-AP38) must stop a token at once, and because `tln` reads the tracker just after a login (Design Q309). Each of the 4 account routes has 1 D1 call: one batch (R-CT16 row 10). |
| 6 | A batch reads at most 1 MiB of rows (`cloudflare-workers/MODULES.md` MC11). The closure answer is runs (R-AP42): 49 KB for 3 years of all compilers, so the limit stays far. The Worker decodes the rows into typed Roc rows (Q29). |

Tests:

| Rule | Test | Revert that must fail |
| --- | --- | --- |
| R-AP41 budget | Miniflare. A counting proxy on the D1 binding (or the shim op log) counts the `prepare`, `run` and `batch` calls of each route. Each count is at most the budget. | Split the closure batch into 2 calls: count 2 |
| R-AP41 row 2 | A closure with 60 groups (more than 100 parameters if each value were bound) gives 200 | Bind one parameter for each value: `D1Err` |
| R-AP41 row 3 | A publish with the label written by another request between the pre-read and the batch gives 409, and no second leaf | Remove the trigger |
| R-AP46 | A closure with 300 groups and 1000 hashes of the longest form gives 200. With 301 groups, or 1001 hashes, 413 `too-large` and no D1 call. | Remove the check: 500 `internal` on remote D1, or 200 with no limit |
| R-AP47 | 2,500 toolchain rows: the pages from `after=0` while `more` is true hold each row once, in log index order. A page from the largest log index has no rows and `more` false. | Page by nightly, not by log index: a row is lost or seen twice at a page end |
| R-AP45 | `MIN_TLN_WRITE=0.5.0`: `POST /v1/compat` with `User-Agent: tln/0.4.1` gives 400 `unsupported-client` with `minimum`. `GET /v1/toolchains` with the same agent gives 200. `curl/8` is not checked. | Compare the versions as text: `tln/0.10.0` is refused |
| R-AP41 row 5, R-AP18 | A closure that runs at the same time as a publish: each `log_index` is at most `log_size` | Run the reads as separate calls with `log_size` first |

### 4.3 Short-name matches

R-SN1: `GET /v1/packages?short=<name>` gives the match set of a short name (CLI 2, R-SC8). The query can have up to 50 `short` values (first guess). The answer is `{matches}`: for each `short` value, the list of each indexed package whose repo name, or repo name minus a leading `roc-`, is equal to the value. The compare is ASCII case-insensitive, because GitHub names are case-insensitive. Each item is `{name, first_log_index, state}`, with the changes of R-AP33. The wire form is in R-SN6. The list is sorted by `name`. It is not ranked and not cut. An empty list means no match.

| `short` | Indexed packages | `matches` |
| --- | --- | --- |
| `parser` | `lukewilliamboswell/roc-parser` | `lukewilliamboswell/roc-parser` |
| `roc-parser` | `lukewilliamboswell/roc-parser` | `lukewilliamboswell/roc-parser` |
| `Parser` | `lukewilliamboswell/roc-parser`, `someone/parser` | both |
| `pars` | `lukewilliamboswell/roc-parser` | none |

R-SN2: An indexed package is an `owner/repo` name that has at least one release in the index, also a yanked or a withdrawn release (R-YK4, R-PU17), and also a name in the state `missing` (R-TP11). Reason: a match that is too wide only makes Talon stop and ask for the full name (CLI 2, R-AD4). A match that is too narrow can select a package that the user did not mean (typosquat, R-AD7). For example, when `lukewilliamboswell/roc-parser` is deleted and a stranger makes `someone/parser`, `parser` still gives 2 matches, not the new one alone. R-AP33 gives the change for a name in the state `moved`.

R-AP33: In the match set of R-SN1, the Worker replaces a name in the state `moved` with the end of its successor chain (R-TP14). The item then has `moved_from`, the old name. When the end is already in the set, the set has it once. Each item also has `state` (R-AP32). So a moved package does not tie with itself, and a `missing` package still ties with a new name. `tln add` prints `matched "json": acme/roc-json (moved from olduser/roc-json)` (CLI 2, R-AD3). The text is a proposal (CLI 3, R-OUT2).

R-SN3: A package on a host other than `github.com` never matches a short name. It has no `owner/repo` name (Design 4.1, R-ID3). The user types its full name `host/path` (CLI 2, R-SC7).

R-SN4: `first_log_index` is the smallest log index of the releases of that name. With `--snapshot log:N`, the client hides each match with `first_log_index` greater than N. So `tln install` of a short key (Design 4.3, R-I8) gives the same match set at the same snapshot (Design G3). The value of a replaced item is in R-SN9.

R-SN5: The ranked results of `?q=` are at most 20 packages (first guess), ranked by a text match on the name. Talon shows them only in messages, for example as suggestions after "no match" (CLI 2, R-AD5). Talon never selects a package from them (CLI 2, R-AD34). The ranking is in R-SN10.

R-SN6: The wire form of `GET /v1/packages` (Design Q107, Q113). These are facts that a client reads, not output text.

| Item | Rule |
| --- | --- |
| Several `short` values | The repeated parameter: `short=a&short=b`. The Worker reads the whole query, not only the first value of a name. A value is percent-decoded, and `+` is a space, as in any query parameter. The decode is the one of the platform (`Request.query_all`, the URL standard): a byte sequence that is not UTF-8, for example `%FF`, becomes U+FFFD. It is not a 400. The answer repeats the decoded value (`short`), so an entry has U+FFFD and no match. `tln` builds a value from text, so it never sends invalid UTF-8 (R-AP69) (Design Q442). |
| `matches` | A list of entries, one for each `short` parameter, in the order of the URL, also for equal values. An entry is `{short, matches}`. `short` is the value as sent, decoded, not made lower case. The inner `matches` is the list of R-SN1. The client reads entry i for the value i of its request. |
| Item of `matches` | `name` (text), `first_log_index` (integer, R-SN9), `state` (`active`, `missing` or `moved`, R-AP32) and `moved_from` (text). `moved_from` is optional (R-AP51): it is there only for a replaced name (R-AP33). |
| `packages` | `{packages}`: a list of items `{name, first_log_index, state}`. An item has no `moved_from`: a moved name is not replaced. `state` is the state of the name itself. `first_log_index` is as R-SN4 says. The ranking is in R-SN10. |
| An empty list | 200 with the list empty: `{"matches":[{"matches":[],"short":"pars"}]}` and `{"packages":[]}`. It is not an error. |
| Order | Entries in the order of the URL. Items sorted by `name` (bytes) after the replace (R-SN1). One state gives one body (R-AP53). |

R-SN7: The refusals of the query of `GET /v1/packages` (Design Q108). All are 400 `bad-request`, after the checks of 404, 405 and 413 (R-AP48), and before any D1 call (R-AP56):

| Query | Answer |
| --- | --- |
| `short` and `q` together | 400. One request has one form. |
| A `short` value that is empty (`short=`) | 400. The empty value counts for the limit of 50 (R-AP46), and 413 comes first. |
| An empty `q` | 400 |
| `q` more than once | 400. A search has one text. |
| No `short` and no `q` | 400 (R-AP7) |

Reason: a query that cannot be an exact request is a fault in the client. A 200 answer with an empty list would show it as "no match" (R-AD5).

R-SN8: The end of a chain in a match set (Design Q109). The Worker walks from a name in the state `moved` with the same steps that the client uses (R-TP14), so a short name and a full name give one end:

| # | Step |
| --- | --- |
| 1 | The walk starts at the name n0 that is in the state `moved` and has a successor |
| 2 | The walk goes to the successor while the current name is in the state `moved`, fewer than 4 links are taken, and the successor is not yet on the walk |
| 3 | The end is the name where the walk stops. Its `state` is its own state. |

| Chain | End | `state` of the end |
| --- | --- | --- |
| A moved to B, B active | B | `active` |
| A to B, B `missing` | B | `missing` |
| 4 links, the fifth name active | the fifth name | `active` |
| 5 links or more | the name after 4 links | `moved`: the chain is cut |
| A to B to A | B | `moved`: the cycle stops the walk before the name that is on the walk |
| A to B to C to A | C | `moved` |

An end that is the start (a successor equal to the name) is not a replace: the item is the name, with `state` `moved` and no `moved_from`. A client that sees `state` `moved` on an item knows that the chain did not end, and prints the note of R-TP14.

R-SN9: `first_log_index` and `moved_from` of a replaced item (Design Q110, Q111):

| Item | Rule |
| --- | --- |
| `first_log_index` | The smallest log index of the releases of the name of the item and of each name that the item replaces in this entry. A matched name has a release (R-SN2), so a value always exists, also when the end has no release yet. Names on the chain that are not in the match set do not count. Reason: a move is not in the log. With `--snapshot log:N` (R-SN4), the old name that had a release at N keeps the item in the set, as it was before the move. |
| `moved_from` | The item has it for each replaced name, also when the end is itself in the set (R-AP33: the set has the end once). With 2 or more old names for one end, it is the smaller name by bytes. |

R-SN10: The ranking of `?q=` (Design Q112). It is for display only (R-SN5). The text t is the value of `q`, percent-decoded, with the ASCII letters in lower case. A name is the `owner/repo` name in lower case (R-IK2). Its repo part is the text after the first `/`. Its short part is the repo part without a leading `roc-` when the repo part is longer than 4 bytes (as R-SN1). The packages are the indexed packages of R-SN2 on `github.com`, in each state:

| Rank | The name matches when |
| --- | --- |
| 1 exact | The name, the repo part or the short part is equal to t |
| 2 prefix | The name, the repo part or the short part starts with t |
| 3 substring | The name has t inside |
| none | The name is not in the list. There is no fuzzy match. |

The order is the rank, then the name (bytes). The list is cut to 20 after the order. The same state and the same `q` give the same list.

## 5. Records

| # | Table | Key | Fields |
| --- | --- | --- | --- |
| R-RE1 | `artifacts` | artifact (5.1, R-IK2) | kind (`app`, `package`, `platform`, R-AP49), exposes (TEXT: a JSON array of the module names, in the order of the header, Design Q93), platform (an artifact id), `roc:` pin, size (the bytes of the `.tar.zst` asset). The hash is in `names` (R-RE22). The deps are in `deps` (R-RE19), and the targets in `artifact_targets` (R-RE20). |
| R-RE2 | `releases` | log_index (R-IK6) | form, version, version_text (TEXT, empty for an exact key; the label, `UNIQUE` together, R-IK5), artifact, repo (null on another host), url, tag, `.roc-version`, published_at, yanked (R-YK4), withdrawn (R-PU17). Provenance is in its own table (R-PU15). |
| R-RE3 | `compat` | (artifact, nightly, target, source) | result, error digest, time (R-RE26), and for `author` the log index (INTEGER, NULL for `bot`) of the release that sent the row. `source` is `bot` or `author` (R-MX5). |
| R-RE4 | `toolchains` | (nightly, target) | tag, asset name, sha256, size, published_at, log_index. `size` is the byte size of the asset, a whole number above 0 (R-AP80). `target` is the asset target of CLI 6.2, R-CV8 (`linux_x86_64`) as text: a nightly has about 5 rows. `published_at` is the `published_at` of the GitHub release, so each row of one tag has the same value (R-MX16). `log_index` is the compiler leaf of the asset (R-SG8). |
| R-RE5 | `log` | index | group, version and hash as text (R-IK1), time (R-RE26): the time of the write (R-SG8) |
| R-RE7 | `sweeps` | (nightly, target) | upto_log_index (INTEGER), time (R-RE26) |
| R-RE9 | `provenance` | (release, via) | `via` (`oidc`, `webhook`, `poll`, `ingest`), the recorded claims (R-TP6, `oidc` only), the attestation result (Design 8, R-SE10, P3), time (R-PU15). `release` is the log index (R-IK6). |
| R-RE10 | `yanks` | (release, seq) | action (`yank`, `unyank`), by (`author`, `operator`), the recorded claims (R-TP6, `author` only), reason, time (R-YK4, P3) |
| R-RE11 | `repos` | repo (the id of the lower-case `owner/repo`, R-IK2) | repository_id, repository_owner_id, state (`active`, `missing`, `moved`), successor (a repo id), offer (P3), state_at, time (R-TP5, R-TP11, R-TP14) |
| R-RE15 | `repo_events` | (repo, seq) | action (`bind`, `transfer`, `rename`, `recreate`, `missing`, `found`, `successor-set`, `successor-removed`, `offer`, `operator`), the ids before and after, the successor, the recorded claims (R-TP6) for a token, time (R-TP13) |
| R-RE14 | `repo_checks` | repo | etag (of the release list, R-PU23), repo_etag (of the visibility read, R-PU31, Design Q371), checked_at, next_check_at, fail_count (R-PU37), app_installed. The state of the reconcile (R-PU21). Apart from `repos`, so that the binding of R-TP5 and the reconcile do not write the same row. |
| R-RE12 | `compat_hints` | (artifact, nightly, target, talon_version) | pass_count, fail_count, crash_count, first_time, last_time. The user hints of R-MX3 (R-RE13). `talon_version` is the version of the `tln` that sent the hint (R-CT12, R-IK5). It holds no contributor. `first_time` is the `time` of the hint that made the row, and it never changes (R-RE6). `last_time` is the largest `time` of a counted hint: `MAX(last_time, NEW.time)` (Design Q82). |
| R-RE16 | `contributions` | (contributor, artifact, nightly, target) | result, talon_version, time. One user hint: who sent the result for the pair. Kept until the trim of its nightly (R-CT15) or a delete (R-CT7). `contributor` is one 64-bit id (R-CT3). |
| R-RE17 | `contributors` | contributor (a GitHub user id, R-CT3) | login, tokens_after, first_time, last_time. The index of the authors that logged in (R-CT8, R-CT9). A machine that never logged in has no row. A new row has `tokens_after`, `first_time` and `last_time` equal to the time of the login. A later login changes only `login` and `last_time` (R-CT16 row 5, Design Q307). |
| R-RE18 | `links` | machine (the id of a machine, R-CT3) | contributor (the account), time. A machine that logged in (R-CT8). |
| R-RE19 | `deps` | (artifact, alias) | dep (the artifact id of the dependency hash), form, version, version_text (null when the URL has no version, R-IK5), url, platform (1 when the header entry is a platform entry, else 0; default 0, R-AP81). One row for each dependency in the header of the artifact. The closure query (R-AP17) follows `dep`. |
| R-RE20 | `artifact_targets` | (artifact, target) | None. The targets of a platform (R-MX10, R-CT2). |
| R-RE21 | `targets` | target (a code, R-IK7) | name (`UNIQUE`) |
| R-RE22 | `names` | id (R-IK2) | kind, value, `UNIQUE (kind, value)` (R-IK3) |
| R-RE23 | `transitions` | (nightly, target) | previous (the adjacent nightly before it), compared, changed (R-MX12) |
| R-RE24 | `hint_days` | day (days from 1970-01-01, UTC) | counted (R-CT13) |
| R-RE25 | `contributor_totals` | contributor (R-CT3) | counted, first, agreed, disagreed, unconfirmed, first_time, last_time (R-RE26). The totals of the rows that the trim removed (R-CT15). `first_time` is the smallest and `last_time` the largest `time` of these rows, so the tracker keeps both times after a trim (R-CT10, Design Q302). |

R-RE6: Artifact rows never change. Rows of `names`, `targets`, `deps` and `artifact_targets` are only added, never changed or deleted, so a name keeps its id. Release rows change only in `yanked` (R-YK4) and `withdrawn` (R-PU17, R-PU19). Toolchain rows never change. A `compat` row is written once and never changes (R-RE13). A `compat_hints` row changes only in its counts and `last_time`. A daily cron step deletes it when its pair has a `bot` row (R-CT5), and the operator can delete it (R-CT7). A `contributions` row changes only in `contributor`, when a login moves the rows of a machine to its account (R-CT8). A `contributor_totals` row changes only by a trim (R-CT15) or a login. A `contributors` row changes in `login`, `tokens_after` and `last_time`. A `links` row changes when the machine logs in again. The trim (R-CT15) deletes the `contributions` rows of an old compiler. Rows of `contributions`, `contributor_totals`, `contributors` and `links` are deleted by R-CT7. A `sweeps` row changes only to a larger `upto_log_index`. A `transitions` row changes only when a sweep of one of its 2 nightlies is written (R-MX12). A `hint_days` row changes only in `counted`, and the daily cron deletes the rows with a day below today minus 2 (the days of today, yesterday and today minus 2 stay; Design Q343). Rows of `provenance` (R-PU15) and `yanks` (R-YK4) are only added, never changed. A `repo_checks` row (R-RE14) changes at each reconcile of its repository (R-PU21). It is state, not evidence: no rule reads it as a fact. A `repos` row (R-TP5) is never deleted. It changes only by the rules of R-TP9 to R-TP15, and each change adds a `repo_events` row (R-RE15). `repo_events` rows are only added.

R-RE8: The log index of a hash is the smallest `log_index` of its releases. A `sweeps` row says: when the Worker wrote it, the matrix had a `bot` row (R-RE3) on (nightly, target) for each member of the bot set at `upto_log_index` (R-MX11).

R-RE13: Matrix rows of one pair (hash, nightly, target):

| # | Rule |
| --- | --- |
| 1 | One pair has at most one `bot` row and one `author` row. The first write of a key wins. A later write of the same key changes nothing, and it is not an error: the bot can post a run again after a failure. Reason: a probe result for a pair does not change (Resolution 4, R-P4). |
| 2 | Two releases in two repositories can have one hash. Then the first publish writes the `author` row. The row keeps the log index of that release, so a reader can find the publisher. |
| 3 | A user hint never goes into `compat`. It adds 1 to `pass_count`, `fail_count` or `crash_count` of the `compat_hints` row of its pair and its Talon version, once for each contributor (R-CT4). A contributor id costs nothing to make (R-CT1), so a count is not a count of persons. The limits of R-CT11 apply. |
| 4 | The Worker sends the `compat` rows of each source as runs, and the `compat_hints` counts (R-AP4, R-AP17). The client applies the precedence of Resolution 3, R-EF3. The registry merges the sources only for `nearest` (R-AP17). |

R-RE26: Times (Design Q65). Each column in D1 that holds a point in time is an `INTEGER`: milliseconds since 1970-01-01 00:00 UTC. These are `time`, `first_time`, `last_time`, `published_at`, `state_at`, `checked_at`, `next_check_at`, `tokens_after`, the time of `withdrawn` (R-PU17) and the time of a yank (R-YK4). The one exception is `hint_days.day`, a count of days (R-RE24). The Worker converts a time from GitHub (`published_at`, RFC 3339) at the edge, as it converts an id (R-IK1). R-AP50 gives the form of a time in the API: the same integer.

### 5.1 Integer keys

Each key and each reference in D1 is an integer. A hash, a name or a tag is stored once, in `names` (R-RE22) or in its own row, and other rows refer to it by its id. Reason: a text key is repeated in each row that refers to it, and again in each index. Test and measurement: `research/d1-int-keys/` (local D1 and SQLite, 12 cases, 2026-10-16 and 2026-10-17). The D1 module of `cloudflare-workers` has the integer rules and the constraint kinds that this section uses (`cloudflare-workers/MODULES.md` 5.1, `PLAN.md` "Status of step 8c, D1, Sql and Memo").

| `compat`, 1,000,000 rows (`size.mjs`, SQLite in memory) | Text keys | Text keys, `WITHOUT ROWID` | Integer keys | Integer keys, `WITHOUT ROWID` |
| --- | --- | --- | --- | --- |
| Bytes a row | 192 | 98 | 61 | 32 |
| Read the rows of 500 hashes (the closure answer) | 34 ms | 14 ms | 31 ms | 13 ms |
| 10,000 reads of one row | 35 ms | 28 ms | 25 ms | 19 ms |

R-IK1: Ids stay inside D1. The HTTP API (section 4), the log and the tiles (section 3) keep the text forms: a hash in base58, a group as its URL form (R-AP15), a version as `X.Y.Z`, a nightly as its tag. The Worker changes an id to text, and text to an id, at the edge. Reasons: a leaf is evidence that a client checks with no access to D1, so it must not depend on an id. And a change of the id scheme is then a migration of D1 only: `tln` does not change.

R-IK2: The ids:

| Value | Column | Size | Id |
| --- | --- | --- | --- |
| Artifact hash | `artifact` | 64 bits | `name_id(1, the 32 bytes of the BLAKE3 hash)` |
| Group URL form (R-AP15) | `form` | 64 bits | `name_id(2, the UTF-8 bytes of the URL form)` |
| GitHub name, lower case (`roc-lang/unicode`) | `repo` | 64 bits | `name_id(3, the UTF-8 bytes of the name)` |
| Contributor (6.1) | `contributor` | 64 bits | A machine: the first 8 bytes of HMAC-SHA256 with `CONTRIBUTOR_KEY`, with the top bit set (negative). A GitHub account: the GitHub user id (positive) (R-CT3). Not in `names`. |
| Nightly | `nightly` | under 47 bits | From the date and the sha of the tag (R-IK4) |
| Version of a release | `version`, and `version_text` | 64 bits, and a text only when the key is not exact | R-IK5 |
| Version of `tln` | `talon_version` | 64 bits | R-IK5 |
| Release | `log_index` | A sequence | R-IK6 |
| Value of a closed set, Roc target | A code | 1 byte | R-IK7 |
| GitHub user, repository, owner | The GitHub id | As GitHub gives it | GitHub ids are integers already |

`name_id(kind, bytes)` is the first 8 bytes of SHA-256(the kind byte, then the bytes), read as a big-endian signed integer (two's complement), so it uses all 64 bits of an SQLite INTEGER. The kind byte keeps the kinds apart. Example: `printf '\x02github.com/roc-lang/unicode/releases/download/{v}/' | sha256sum` starts with `dab544ab6661c1b9`, so the form id is -2687166099708853831 (case K8). Each id is a function of its name, so the Worker computes it with no read, and a D1 batch, which cannot branch (`cloudflare-workers/API.md` RF4), can use it.

A 64-bit id has a size of 2^53 or more in almost all cases (all but 1 in 1024). D1 takes no `BigInt` parameter (`D1_TYPE_ERROR`), and it gives an INTEGER of size 2^53 or more back as a rounded JS number with no error (`cloudflare-workers/MODULES.md` 5.1, "Integers in rows"). Case K3: the id 2^53 + 1 came back as 2^53, and a lookup with that value found another row. So these rules apply to each column of this table with 64 bits:

| Use | Rule | Case |
| --- | --- | --- |
| Write | The Worker binds the id as decimal text. The INTEGER affinity of the column stores it as an integer. The D1 module of the platform does this for each `Int` outside ±(2^53 - 1) (`cloudflare-workers/MODULES.md` 5.1, "Parameters"). | K3, K10 |
| Read | Each query that gives an id back has `CAST(id AS TEXT)`, also in `RETURNING`. Most queries give names and hashes back, not ids (R-IK1). | K10, K11 |
| Guard | The typed row of a query gives each id column the type `I64`. The D1 module reads the text of `CAST(id AS TEXT)` into the `I64` field. A read with no cast gives `BadData("column <name>: integer above 2^53, use CAST(<name> AS TEXT)")` for each id of size 2^53 or more, and an id below that size is exact (`cloudflare-workers/MODULES.md` 5.1, "Integers in rows"). A rounded id cannot get into the Worker. | K11, and the `d1` checks of `cloudflare-workers/conformance/` (`all! with no cast`, `all! of CAST(id AS TEXT)`) |
| Compare | A bound id is compared with a column: `WHERE id = ?`, a join of `json_each(?)` or of a `VALUES (?)` CTE to a column. `id = ? + 0` and `id = CAST(? AS INTEGER)` also convert the text. Never with another parameter or an expression only: `? = ? + 0` is false. | K10 |
| Store | Each table is `STRICT` (R-IK8). Then a text id that is not an integer in the i64 range is an error (`Constraint` of kind `Datatype`), not a TEXT or REAL value in an id column. | K12 |
| JSON parameter | The Worker writes an id as a JSON number. SQLite reads a 64-bit JSON integer exactly. | K10 |

The other integers (nightly, versions, codes, `log_index`, GitHub ids) are below 2^53, and they need no cast. `Sql.Info.last_row_id` is `Err(Rounded)` for a 64-bit rowid, so the Worker never reads the id of `names` from it: it computes the id (`name_id`).

R-IK3: `names` holds each name that has a `name_id`: `(id, kind, value)`, with `id` the primary key and `UNIQUE (kind, value)`. `value` is the 32 hash bytes for kind 1 and the UTF-8 text for kinds 2 and 3. The Worker inserts the names in the same batch as the rows that refer to them, with `INSERT INTO names ... ON CONFLICT (kind, value) DO NOTHING`:

| Case | Result |
| --- | --- |
| The name is in `names` | No change (case K4) |
| A new name | A new row |
| A new name with the id of another name: a collision | The primary key stops the batch, and nothing of the request is written (case K5). The D1 module gives `Constraint({ kind: PrimaryKey, message: "UNIQUE constraint failed: names.id" })` (`cloudflare-workers/MODULES.md` 5.1, "Constraint kinds"). The answer is 409 `id-collision`. |

The Worker compares the kind and the whole `message`, as in R-MX9. A `PrimaryKey` failure of another table is not a collision: it gives 500 `internal`. The message does not name the id, so for the `detail` the Worker then reads `SELECT CAST(id AS TEXT) AS id, kind, value FROM names WHERE id IN (...)` with the ids of the request. A row whose `(kind, value)` is not the name of the request with that id is the other name, and the `detail` names both. A batch that a collision stopped wrote nothing, so this read sees only the names from before.

The conflict target `(kind, value)` is necessary. A plain `ON CONFLICT DO NOTHING` also skips a collision with no error, and the other rows of the batch then refer to the other name (case K5 with `MUTATE=notarget`).

The registry cannot index a name with a collision, and the package still works: `tln` reads the facts from the archive, as for an ingest that gave a 4xx answer (R-AP28 case 3). For N names, a collision comes by chance with a probability of about N^2 / 2^65: 2.7 × 10^-8 at 1,000,000 names. To block one name that is not indexed yet, an attacker must find a second name with the same id: about 2^64 SHA-256 calls. The operator sees each collision in the logs of the Worker. Two machines with one id share their rows: a hint of one counts for both, and a delete of one deletes both (R-CT7). Nobody can make that on purpose without `CONTRIBUTOR_KEY`. A machine id and an account id cannot be equal: one is negative, the other positive (R-CT3).

R-IK4: The id of a nightly is `days × 2^28 + sha`. `days` is the count of days from 1970-01-01 to the date of the tag. `sha` is the first 7 hex digits of the sha of the tag (28 bits). So:

| Property | Reason |
| --- | --- |
| Both tag forms of CLI 6.2, R-CV1 (`nightly-2026-10-09-258ab27`, `nightly-2026-October-09-258ab27`) give one id | R-CV1 says that they name one nightly |
| The ids are in date order | A range of nightlies is a range of ids |
| Each id is under 2^47 until the year 3405 | 6 bytes in a row |

The tag form that has an id (Design Q75). A text that does not have this form has no id (`NotANightly`):

| Part | Form |
| --- | --- |
| Prefix | `nightly-` |
| Year | 4 digits |
| Month | 2 digits `01` to `12`, or the English name with an upper-case first letter and the other letters in lower case (`July`) |
| Day | 2 digits. The date must exist in the Gregorian calendar (`2026-02-30` has no id, `2028-02-29` has one). |
| Sha | Exactly 7 hex digits, lower case |
| Date range | From 1970-01-01 to 3405-06-14, so that the id is under 2^47 |

Facts: each of the 348 tags of `roc-lang/nightlies` on 2026-11-01 has this form: a sha of 7 lower-case hex digits, a day of 2 digits, a month of 2 digits (79 tags) or a name (269 tags), and a date that exists. roc reads more in a `roc:` pin: a sha of any length and case, a day or a month of 1 digit, a day up to 31 in each month (`roc:src/base/roc_version.zig:142-175`, nightly `258ab27`). Talon gives no id to these, because no real tag has them, and the id needs exactly 28 bits of sha. Such a pin has no registry facts.

`toolchains` keeps the tag text (R-RE4). `PUT /v1/toolchains/{tag}` (R-AP6) for a tag with the id of another recorded tag gets 422 `not-a-candidate`. A tag that is not a nightly tag has no id: when roc publishes its first release that is not a nightly (R-CV1), a design change gives its id.

R-IK5: Versions. A version is one 64-bit order key in the column `version`, and a text in `version_text`. The key is a function of `roc-semver` (Design 6.1, R-PK2: `Semver.to_key`). Prior art: the OpenStack Glance spec for semver in a database packs major, minor and patch in 16 bits each, keeps 16 bits for a release flag, and keeps the pre-release label in a second column with one composite index. CPython `PY_VERSION_HEX` puts a release level (alpha, beta, candidate, final) and a serial in its low bits. Talon uses the Glance layout, and the low 16 bits are a pre-release code, so the key alone gives the order of most pre-releases too.

| Bits | Field | Value |
| --- | --- | --- |
| 63 to 48 | major | The major, or 0xFFFF when it is 0xFFFF or more |
| 47 to 32 | minor | The minor, or 0xFFFF when it, or a part above it, is 0xFFFF or more |
| 31 to 16 | patch | The same rule |
| 15 to 0 | Pre-release code | 0xFFFF: no pre-release, or a part above is 0xFFFF or more. A numeric first identifier n: 0x0001 + min(n, 0x0FFE). An alphanumeric first identifier: 0x1000 + 65 × r(c1) + r(c2), from its first 2 characters in ASCII order: r is 0 for no character, 1 for `-`, 2 to 11 for `0` to `9`, 12 to 37 for `A` to `Z`, 38 to 63 for `a` to `z`. The codes 0x0000 and 0x203F to 0xFFFE are not used. |

| # | Property | Use |
| --- | --- | --- |
| 1 | Monotone: when a comes before b by semver precedence, key(a) ≤ key(b). A key never gives the wrong order. | `ORDER BY` and ranges in SQL |
| 2 | Exact: when each part is below 0xFFFF and the version has no pre-release and no build metadata, the key gives the version back (`Semver.from_key`) | `version_text` is empty |
| 3 | Two versions with one key are compared with `Semver.order_relative_to` | The rest of the order |

Examples (hex): `1.2.3` is `100020003ffff`, `1.2.3-beta1` is `1000200031a11`, `1.2.3-alpha4` is `10002000319d7`. Semver compares `alpha4` and `alpha10` as one text identifier, so `1.2.3-alpha10` comes before `1.2.3-alpha4` (semver 11.4.2). A release level and a serial, as in CPython, would give the other order, so Talon does not read a number out of an identifier: both get the code of `al`, and property 3 orders them. The dotted form `alpha.4` < `alpha.10` compares numbers.

| Column | Rule |
| --- | --- |
| `version` | The key with the top bit flipped (`key XOR 2^63`), as a signed INTEGER. SQLite compares signed integers, so the order of the column is then the order of the keys. Most values have a size of 2^53 or more, so the rules of R-IK2 apply: bind as text, read with `CAST(version AS TEXT)`. |
| `version_text` | Empty for an exact key, else `Semver.to_str` of the version. `releases` has `UNIQUE (form, version, version_text)` (R-IK6). |

A release version has no pre-release. roc reads only the `X.Y.Z` run of a URL, each part a `u32` (`roc:src/base/url.zig:183-203`), and the text after the run is part of the group: the tag `0.26.0-rc1` gives the version 0.26.0 in another group (CLI 7.3, R-DI5). So the key of a release is exact, unless a part is 65535 or more. Such a release is still a candidate: its key saturates, `version_text` keeps the version, and the order is right by property 1 and 3. Two URLs whose versions are equal as numbers (`01.2.3` and `1.2.3`) have one label, because roc compares the numbers. The API gives `Semver.to_str` of the version, and `url` keeps the text of the URL.

| Query | SQL |
| --- | --- |
| `?series=` (R-AP13, Design 4.1, R-ID1) | Series `M`: keys from `M × 2^48` to `(M + 1) × 2^48 - 1`. Series `0.m`: keys from `m × 2^32` to `(m + 1) × 2^32 - 1`. For a series with a part of 65535 or more, the interval goes to the largest key, and the Worker checks the series of each row. |
| `range` of the closure query (R-AP16) | `version BETWEEN lo AND hi`, with the stored values of `VersionReq.key_bounds`. Each version that matches has its key in the bounds, but not each key in the bounds matches, so the Worker checks each row with `VersionReq.matches` (case S5). |

The version of `tln` (R-CT12) is the key of its version, so a pre-release of `tln` (`0.5.0-rc.1`) has its own value. The column `talon_version` holds the key as a signed 64-bit integer (the bits of the key, `to_i64_wrap`), with no flip: it is compared for equality only, never ordered, and `unknown` is 0 (Design Q177). `0.4.1` is 17180000255. `unknown` is the key 0: no version has the pre-release code 0x0000. Test: `research/semver-key/` (5 properties over 200,000 pairs of versions with the edge values 0xFFFE, 0xFFFF, 0x10000 and 2^32 - 1, and 2 mutations).

R-IK6: A release is named by its `log_index` (R-RE2). It never changes, and the API uses it already (R-YK1). `provenance` and `yanks` refer to it. The label is `UNIQUE (form, version, version_text)` in `releases`.

R-IK7: Codes. A column with a closed set of values holds the position of the value in the list of the rule that gives the set, from 0. For example, `source`: `bot` 0, `author` 1 (R-RE3). `kind`: `app` 0, `package` 1, `platform` 2 (R-AP49). `result`: `pass` 0, `fail` 1, `hang` 2, `crash` 3 (Resolution 4, R-RC1 to R-RC4). A new value goes at the end of its list, so a code never changes. The Roc targets are not a closed set, so `targets` (R-RE21) gives each one a code:

| Code | Target |
| --- | --- |
| 0 | `any` (the unit check, Resolution 4, R-P4) |
| 1 to 35 | The values of `RocTarget` in `roc:src/target/mod.zig:405-454` (nightly `258ab27`), in that order. The list is the same on `38a3029` and `f7bef6b` (`mod.zig:420-469`, Design Q72): 1 `x64mac`, 2 `x64win`, 3 `x64mingw`, 4 `x64freebsd`, 5 `x64openbsd`, 6 `x64netbsd`, 7 `x64musl`, 8 `x64glibc`, 9 `x64linux`, 10 `x64elf`, 11 `x64v1mac`, 12 `x64v1win`, 13 `x64v1mingw`, 14 `x64v1freebsd`, 15 `x64v1openbsd`, 16 `x64v1netbsd`, 17 `x64v1musl`, 18 `x64v1glibc`, 19 `x64v1linux`, 20 `x64v1elf`, 21 `arm64mac`, 22 `arm64win`, 23 `arm64mingw`, 24 `arm64linux`, 25 `arm64musl`, 26 `arm64glibc`, 27 `arm64v1win`, 28 `arm64v1mingw`, 29 `arm64v1linux`, 30 `arm64v1musl`, 31 `arm64v1glibc`, 32 `arm32linux`, 33 `arm32musl`, 34 `wasm32`, 35 `wasm32v1` |
| 36 and up | A new target name in the `targets/` dir of a platform that the Worker indexes, in the order that the Worker sees them. Only a name that matches `[a-z0-9]{1,32}`. |

A row of `POST /v1/compat` (R-AP10) with a target that has no code gets 400 `bad-request`. A code takes 1 byte in place of 8 in each matrix row.

R-IK8: Each table is `STRICT`, with the column types `INTEGER`, `TEXT`, `BLOB` and, for `names.value`, `ANY` with `CHECK (typeof(value) = CASE kind WHEN 1 THEN 'blob' ELSE 'text' END)`. Reason: an INTEGER column of a table that is not `STRICT` stores a text parameter that is not an integer as TEXT, and an integer out of the i64 range as REAL, with no error (case K12: `abc` and `9223372036854775808`). In a `STRICT` table both are `Constraint` of kind `Datatype`. A 64-bit id as decimal text still goes in as an integer. Local D1 accepts `STRICT, WITHOUT ROWID` (K12).

A table with a composite key whose rows are small is `WITHOUT ROWID`: `compat`, `compat_hints`, `contributions`, `sweeps`, `transitions`, `deps`, `artifact_targets` and `toolchains` (Design Q61). Reason: a table with a rowid stores the composite key two times, in the table and in its index: 61 in place of 32 bytes a row (`size.mjs`). The other tables have a rowid. A table with one integer key uses it as the `INTEGER PRIMARY KEY`. A table with a large field (`provenance`, `yanks`, `repo_events`: the recorded claims) keeps its rowid, because SQLite advises `WITHOUT ROWID` only for rows under about 1/20 of a page (sqlite.org, "The WITHOUT ROWID Optimization", section 4). Case K9: local D1 accepts a `WITHOUT ROWID` table.

## 6. Compatibility matrix

The matrix makes probes rare. A user who adds a common package gets a known answer.

| # | Producer | Runs | Trust |
| --- | --- | --- | --- |
| R-MX1 | Talon compat bot | A scheduled GitHub Actions workflow. For each new nightly, it runs unit probes on each member of the bot set (R-MX11), not on each indexed hash. It gets the work list from `GET /v1/sweeps/{tag}` (R-AP39). For each new release, it searches the nightly range (Resolution 4). It also runs the smoke builds of the platforms in the set for each of their targets (R-MX10), and checks the pairs with the most user hints (R-MX13). Posts results with an OIDC token. The workflow: R-MX15. | Full |
| R-MX2 | Release workflow | `tln probe --range <bundle file>`, then `tln publish` sends the facts (Resolution 4, R-PB5) | Full, tied to the publisher |
| R-MX3 | Users | `tln` with sharing on, and `tln probe --share` (6.1, CLI 1, R-SH1) | Hint only (rank 6) |

R-MX4: The bot sends a sweep with its matrix rows (R-AP10): `(nightly, target, upto_log_index)`. `upto_log_index` is a log size that the bot read before its run. The Worker writes the `sweeps` row (R-RE7, R-RE8), or raises it, only when the matrix then has a `bot` row on (nightly, target) for each member of the bot set at `upto_log_index` (R-MX11). An `author` row does not count. Reason: a sweep is a claim of the bot about its own runs, in one environment. Epochs (Resolution 4, R-EP4) spread the facts of a covered transition to other releases, so a wrong `author` row must not make a transition covered. Else the Worker writes nothing from the request and answers 422 `sweep-incomplete` (R-MX8, R-MX9). `upto_log_index` must be at most the log size, else the answer is 400 `bad-request`. The `target` of a sweep must be `any`, else 400 `bad-request`: smoke rows (R-MX10) have no sweep, and epochs use unit checks only (Resolution 4, R-EP2). A sweep never makes a row smaller: a sweep with a bound that is not larger than the row is complete by R-RE8 and changes nothing, with no error. The same batch writes the `transitions` rows of the nightly (R-MX12). The closure answer carries all `sweeps` and `transitions` rows (R-AP17). The resolver finds epochs only between swept releases (Resolution 4, R-EP2).

R-MX5: The Worker sets the `source` of each matrix row from the auth of the request, not from the body. A body that has a `source` field gets 400. This holds also for a `source` member inside a row of `rows` (Design Q139), with any value, `null` too. A key written with a JSON escape (`"\u0073ource"`) is the member `source`. A text that holds the word `source` as a value (for example in `error_digest`) is not a member.

| Request | Auth | `source` |
| --- | --- | --- |
| `POST /v1/compat` (R-AP10) | The OIDC token of the compat bot (R-MX1) | `bot` |
| `POST /v1/releases` (R-AP8, R-PU5) | The publish token | `author` |
| `POST /v1/compat` (R-AP10) | No token, and the header `Talon-Contributor` (R-CT1) | None: a user hint goes to `compat_hints` (R-RE12, R-RE13) |
| `POST /v1/compat` (R-AP10) | Another token | None: 403 `forbidden` |

R-MX6: User hints (`POST /v1/compat` with no token) have the rate limit of R-CT11. A user hint is never a `compat` row, so it never goes into a sweep (R-MX4).

R-MX7: The bot finds new releases and new hashes with `GET /v1/releases?after=<log_index>` (R-AP14). It starts from the largest log index of its last run. The log entry tiles (R-AP11) give the same leaves, so the bot can also read them.

R-MX8: The database enforces R-MX4, not the Worker code. A `BEFORE INSERT` trigger and a `BEFORE UPDATE` trigger on `sweeps` stop the statement with `RAISE(ABORT, ...)` in these cases:

| Case | `RAISE` text |
| --- | --- |
| The bound is larger than the log size | `sweep-bound` |
| A member of the bot set at the bound (R-MX11) has no `bot` row on (nightly, target) (R-RE8) | `sweep-incomplete` |
| An `UPDATE` makes the bound smaller (R-RE6) | `sweep-smaller` |

The Worker sends one D1 batch for each request: first the matrix rows (`INSERT ... SELECT ... FROM json_each(?1) WHERE true ON CONFLICT DO NOTHING`, R-RE13 row 1, Design Q86, Q153), then the sweep as an upsert that changes the row only to a larger bound. The batch is one transaction, so a `RAISE` rolls back the rows of the request too. Reasons: D1 has no interactive transaction and a batch cannot branch (`cloudflare-workers/API.md` RF4). The check runs in the same transaction as the write, so a publish or a second bot run cannot come between the check and the write. A new leaf gets a larger log index than each accepted bound, so a new release never joins the set of an accepted bound. A later yank or withdrawal can change the set at that bound, but the row stays: it is a claim about the set when the Worker wrote it, and no reader computes the set again. A yank between the read of the bot and its write gives `sweep-incomplete`, and the bot gets the new member from R-AP39. The `BEFORE INSERT` trigger checks nothing when the `sweeps` row of (nightly, target) has a bound that is at least `NEW.upto_log_index` (Design Q83). Reason: this trigger fires also for the insert part of the upsert. Without the skip, a sweep that the bot sends again with the same bound after a yank gets `sweep-incomplete`, but R-MX4 says that such a sweep changes nothing, with no error. A raise of the bound still gets all checks, in both triggers. The matrix rows never use `INSERT OR IGNORE`, and never `INSERT OR REPLACE` (Design Q153). `OR IGNORE` also skips, with no error, a row that fails a `CHECK`: a bad row is lost, and the rest of the request is written (R-CT4, Design Q86). `ON CONFLICT DO NOTHING` without a conflict target skips only a row that breaks a uniqueness constraint, here the key of R-RE13 row 1. Any other failure of a row stops the whole batch. `WHERE true` is part of the row statement: SQLite reads `ON CONFLICT` after a `SELECT` with no `WHERE` as a part of a join. A key that the request holds 2 times is written once, with the first row (the second row conflicts with the first one in the same statement). No trigger fires on `compat`, so `changes` of the row statement is `written` (R-AP66), unlike R-CT4 where a trigger writes `compat_hints`. The Worker never writes `sweeps` with `INSERT OR REPLACE`: a replace is a delete and an insert, so no `UPDATE` trigger stops a smaller bound. SQLite allows no `WITH` clause in a trigger, so the member condition of R-MX11 is correlated `NOT EXISTS` subqueries. One SQL text serves the triggers and R-AP39. Tests: `research/d1-sweep/` (the mechanism, 12 cases) and `research/bot-set/` (the set, the guard and the transitions, 13 cases, local D1 and SQLite). The guard costs 14 ms at 20,000 releases and 55 ms at 100,000 on plain SQLite, with the `UNIQUE (form, version, version_text)` index of R-IK6.

R-MX9: The Worker maps a batch error to an answer by its kind and `RAISE` text. A trigger `RAISE` gives `Constraint({ kind: Trigger, message })`, with `message` equal to the `RAISE` text (`cloudflare-workers/MODULES.md` 5.1, "Constraint kinds"). The Worker compares the whole `message`, not a substring: `sweep-incomplete` gives 422 `sweep-incomplete`, and `sweep-bound` gives 400 `bad-request`. Then the Worker reads the members of the set at the bound that have no `bot` row, and the `detail` of the 422 answer lists up to 100 of them, so the bot knows what to probe. That read is a third D1 call on the primary, after the batch failed (R-AP41), with the SQL text of the `missing` list of R-AP39. It sees the database state after the rollback (Design Q145): a member whose row was in the failed request has no row, so the list holds it. The list can be shorter than the trigger saw, or empty, when another request wrote rows between the 2 calls. The answer stays 422 (the request wrote nothing), and the bot reads R-AP39 for the work list. A `Trigger` with another text, another kind of `Constraint`, or a `D1Err` gives 500 `internal`. A user hint request (R-MX6) has no sweep, so it never gets these errors.

R-MX10: Smoke builds of the bot (Resolution 4, R-SM1). The bot runs the smoke build of a platform hash for each target in the `targets` of its artifact record (R-RE1), on one Linux runner: roc links with the files of the platform only, so one machine builds each target (`research/smoke-app/`, 34 of 34 targets as a real app). It builds a pair (platform hash, nightly) only when the unit check of that pair passed, because a build after a failed check fails too.

| Event | Smoke builds |
| --- | --- |
| A new nightly | Each platform in the bot set (R-MX11), each of its targets, on that nightly |
| A new platform release | Each target, on each nightly where the range search of R-MX1 found a passing unit check |

The rows have the key (platform hash, nightly, target) and the source `bot`. The Worker accepts a real target only for an artifact of kind `platform` whose `targets` has that target, else 400 `bad-request`. A result whose error depends on the build machine, not on the platform (Resolution 4, R-SM7), gives no row.

Cost for each day, at under 2 s for each check:

| Work | Count | Time |
| --- | --- | --- |
| Unit checks on the new nightly | The members of the bot set (R-MX11): 30 in `conformance/compat-sweep/`, or 1,000 | 1 minute, or about 35 minutes |
| Smoke builds | About 10 platforms times 6 targets, at under 0.5 s | Under 1 minute |
| Range search of each new release (R-PB3) | About 10 to 20 checks | Some on older nightlies that the runner downloads (70 MB packed each) |
| Hint audit (R-MX13) | At most 200 checks | Grouped by nightly, so each older nightly downloads once |

The cost grows with the groups and their active series, not with the count of releases.

R-MX11: The bot set. On each new nightly, the bot checks the members of this set, not each indexed hash: the index only grows, and most old releases are in no new resolve. The set at log index L for nightly N:

| # | Rule |
| --- | --- |
| 1 | A release is live when its `log_index` is at most L, and it is not yanked (R-YK4) and not withdrawn (R-PU17) |
| 2 | For each group (URL form, R-AP15) and series (Design 4.1, R-ID1), the live release with the largest version (R-IK5) is a candidate. The candidate is chosen over all live releases of the group. |
| 3 | A candidate is a member when its release was published at most 548 days (47,347,200,000 ms, about 18 months, first guess) before the `published_at` of N (R-MX16), or when it is the newest live release of its group. In SQL: `releases.published_at >= t - 47347200000`, with t the time of N. A release at the edge is in the window, and a release published after N is in the window. A fixed count of days, not calendar months: the edge is one subtraction, and SQLite date arithmetic with months moves the 31st of a month to another day (Design Q80). |
| 4 | Only the hash of a package or a platform is a member (R-RE1). The bot runs no unit check of an app (R-CT5). |
| 5 | A member is a hash, not a release (Design Q150): 2 candidates with one hash (R-RE13 row 2) are one member. `members` of R-AP39 counts distinct hashes, and `missing` lists each hash once. Reason: a `bot` row is the fact of a hash (R-RE3), so a member is complete or not by its hash. |

Reasons:

| Choice | Reason |
| --- | --- |
| The newest release of each series, not each release | A resolve takes the newest release that works (Resolution 5, R-AL3). An older patch stays in old headers. It gets facts from epochs and from users (R-MX14). |
| Each series, not only the newest of the group | Below 1.0 each minor is a series (basic-cli 0.22 to 0.29), and an app can hold an old series for a long time |
| The age window | Without it, the set grows with each new series, for ever |
| Row 3, second case | A group with no release in the window still has one member, so its users keep real facts on new nightlies |
| The time of N, not the time of the run | The set of one nightly does not change when the bot runs late |

The size of the set is about the count of groups, plus the series that had a release in the window. In `conformance/compat-sweep/` (46 hashes), the set has 30. Test: `research/bot-set/` (B0 to B7).

R-MX12: Transitions. When the Worker writes a `sweeps` row of nightly N (R-MX4), an `AFTER` trigger writes one `transitions` row (R-RE23) for each nightly that is adjacent to N in the order of R-NS1 (Resolution 1) and is also swept. The row has the key of the later nightly:

| Field | Value |
| --- | --- |
| `previous` | The earlier nightly of the two |
| `compared` | The count of hashes with a `bot` code result (`pass` or `fail`, Resolution 4, R-EP1) on both. A hang or a crash is not compared (R-EP5). |
| `changed` | The count of these hashes with different results on the two nightlies |

The trigger writes the row with `INSERT ... ON CONFLICT (nightly, target) DO UPDATE SET previous = excluded.previous, compared = excluded.compared, changed = excluded.changed`, not with `INSERT OR REPLACE` (Design Q84). Reason: when the outer statement is the update part of the sweep upsert (a raise of the bound), SQLite uses the conflict mode of the outer statement in place of the `OR REPLACE` of the trigger body, so the insert of a row that exists fails with `UNIQUE constraint failed: transitions.nightly, transitions.target` (slice 103, F1). The counts include each `bot` row, also of hashes outside the set. A row changes only when a sweep of one of its 2 nightlies is written again, so later rows from a range search or from the audit do not change it. The closure answer gives the client the epochs that these rows make (R-AP17 `epochs`), for the boundaries of R-EP3 case (a). Reason: the closure answer has the matrix rows of the closure only, so a client with few hashes saw few changes. Measured on `conformance/compat-sweep/` (`research/bot-set/boundaries.mjs`): with 1 changed hash or more as the threshold, the set of 30 finds the same 5 boundaries as all 46 hashes. With 2 or more, it misses the boundary of 2026-09-24, where roc-parser 2.0.0 is the one member that changed. Test: `research/bot-set/` (T0 to T4).

R-MX13: The hint audit. Each run, the bot also checks at most 200 pairs (first guess) that have user hints and no `bot` row, from `GET /v1/compat_hints?audit=200` (R-AP40): unit checks and smoke builds of platforms. The pairs with the largest total count come first. Reasons: user hints come mostly from hashes outside the set (R-MX14), so their counts show which old hashes people still use, with no log of who asked. A `bot` row then replaces the hints (Resolution 3, R-EF3), and the tracker can compare the hints with it (R-CT10). The bot builds no tool app, so it audits no app build. A false hint can make the bot check a pair that nobody uses. This costs at most 200 checks a run.

R-MX14: A hash outside the set has these facts on a new nightly:

| Source | Rank (Resolution 3) |
| --- | --- |
| The local probes of the user (Resolution 5, R-AL4) | 1 |
| The hint audit (R-MX13), and the `author` rows of its release (R-PB5) | 2 |
| Its `bot` rows from the time when it was a member, spread over flat transitions by epochs (Resolution 4, R-EP6) | Inferred |
| User hints (6.1) | 6 |

An inferred fact never decides (R-EP8), so a hash outside the set can cost a user a probe, never a wrong header.

R-MX15: The compat bot workflow (P2, Design Q66). The bot of R-MX1 is the workflow `.github/workflows/compat-bot.yml` in the Talon repository `roc-talon/talon`:

| Item | Value |
| --- | --- |
| Triggers | `schedule` and `workflow_dispatch` (R-TP7) |
| Runner | One Linux runner (R-MX10) |
| Probes | `tln probe` (Resolution 4, R-PB1 to R-PB4, R-PB7) for the unit checks and the range searches. `tln` downloads each compiler that a probe needs (CLI 6.2). |
| Registry calls | A small bot script beside the workflow: the work lists (R-AP39, R-AP40, R-MX7), `PUT /v1/toolchains/{tag}` (R-PU7), and `POST /v1/compat` with the rows and the sweep (R-AP10, R-MX4). It gets the OIDC token as R-TP2 does. |
| Worker settings | `BOT_REPOSITORY_ID` is the GitHub id of `roc-talon/talon`. `BOT_WORKFLOW_REF` is `roc-talon/talon/.github/workflows/compat-bot.yml@refs/heads/<default branch>` (R-TP7, R-WH14). |

R-MX17: The bot script (Design Q209). It is a Roc app in the Talon repository, `bot/main.roc`, on basic-cli, with the code shape of the CLI (TESTING.md 2): a pure decision for each rule, and command code that gets an `Fx` record.

| Item | Rule |
| --- | --- |
| Language | Roc. It uses the API types of `packages/records` (Design R-PK7) to read the answers of R-AP39, R-AP40 and R-AP14 and to write the bodies of R-AP6 and R-AP10. Not a shell script: the decisions (the rows from the probe results, the sweep bound of R-MX4, the work lists) need tests. Not a hidden `tln` subcommand: the bot token and the bot routes are not a part of the user binary. |
| Probe results | The `data` of `tln probe --json` (CLI 3, R-J1 to R-J6), one run for each work item. Not `compat.db`: its tables are a private file of `tln` (CLI 6.1, R-TF7), and `--json` is the public interface (CLI 3, R-E5). |
| Token | As R-TP2, with the base URL form of the registry (CLI 1, R-RG7) as the `audience` |
| Tests | L0 (`roc test`) for the pure decisions, and L2 (TESTING.md 2.4) with a fake `Fx` for the order of the calls, the answers of the Worker and the errors. The Worker side of the bot routes is W2 (TESTING.md 9) with the bodies that the L2 cases expect. No test runs the bot against Miniflare: the 2 layers meet at the request and answer bodies. |

R-MX18: The details of the bot script (Design Q566 to Q578). They hold for slice 223.

| # | Item | Rule |
| --- | --- | --- |
| 1 | One unit probe (Q566) | The archive from the first release of R-AP2 with `withdrawn` `null`, a `curl` job to `<RUNNER_TEMP>/<hash>.tar.zst`, then `env ROC_TOOLCHAIN=<tag> tln probe --json --yes <path>`; `TALON_AUTO_INSTALL=yes`; batches of 4. No release or no file: no row, a warning, a probe with no fact. An empty batch makes no `spawn_all!` call (Q584). |
| 2 | The nightlies (Q567) | The operands, else the newest 7 nightly tags of `roc-lang/nightlies` (GitHub, no token), oldest first. No state. A failed list is exit 15: one request, no retry (Q582). A 422 of the `PUT` skips the tag with a warning. |
| 3 | Smoke builds (Q568) | Not run: `tln` has no command for one. The audit leaves out each pair with a target that is not `any`. A CLI question. |
| 4 | `error_digest` (Q569) | `null`. |
| 5 | A wrong probe (Q570) | No row when the compiler (by nightly id), the hash or the kind (`unit`) is not the asked one, or `ok` is false. |
| 6 | The token (Q571) | One for each write; a 401 gets one new token and one more try. |
| 7 | The sweep (Q572) | At most 2 sweep requests for a tag. After a 422 `sweep-incomplete`: read R-AP39 again, probe the new `missing`, send all rows again with the new bound. Done (bound at least `log_size`, no `missing`): no request. Chunks of 500 rows, the sweep in the last. No row and no sweep to send: no token, no post (Q583). |
| 8 | The exit codes (Q573) | 0, 1 (a probe with no fact or an incomplete sweep: reported at the end), 2 usage, 15 no answer, 20 refusal; 2, 15 and 20 stop at once. The `Fail` values of `tln publish`. |
| 9 | The range search (Q574) | A later slice: `data.facts` of `tln probe --range --json` (`error.details.facts` for an exit-12 run; Design Q581), and `after` is the `upto_log_index` of the newest swept nightly. |
| 10 | The registry (Q576) | `TALON_REGISTRY` only, read with CLI R-RG7. `direct`, empty or bad is exit 2. The audience is its origin form. |
| 11 | The workflow (Q577) | Cron `43 4 * * *`, input `tags`, `if: github.repository == 'roc-talon/talon'`, job rights `contents: read` and `id-token: write`, 120 minutes, `concurrency` `compat-bot` with no cancel, `vars.TALON_REGISTRY`, `TALON_AUTO_INSTALL: yes`, no secret, `tln` and `bot` built from the commit. |
| 12 | The harness (Q578) | `bot/main.roc` and `bot/lib/main.roc` in the `check` apps, `bot` in `step_fmt`, 9 L0 drivers, a selftest row for `ciscan.py compatbot`. |
| 13 | The failure texts (Q585) | `Bot.failure`, the lines `tln: error[<kind>]: <text>`, proposals (R-OUT2). `rejected` for a 401 or 403 of a write: `the registry <origin> refused the OIDC token of this run (<type>): <detail>. Check that the run is the workflow of BOT_WORKFLOW_REF on the default branch of BOT_REPOSITORY_ID (R-TP7) and that the job has permissions: id-token: write.` `rejected` for a 400, 404, 409 or 422 of a write: `the registry <origin> refused the <step> (<type>): <detail>. The bot stops. This is a fault of the bot or of the registry data, not of the run.` `network` for no answer, 429, 5xx or 503 `busy` after the retries: `the registry <origin> did not take the <step> after 4 requests (<status or no answer>). The bot stops, and the next run starts again.` `network` for the GitHub list: `the list of nightlies at api.github.com did not answer (<status or no answer>). The bot stops, and the next run starts again.` `<step>` is `put <tag>`, `post <tag>` or `post audit <tag>`. |
| 14 | The reads (Q594 to Q596) | The reads of R-AP39, R-AP40 and R-AP2 are sent again by R-AP34 (2, 8, 30 s, `Retry-After` at most 60 s, also after 503 `busy`). Texts: `Bot.failure` with the steps `get sweeps <tag>`, `get audit` and `get artifact <hash>`. A read of R-AP2 that gets a 4xx other than 429 is a warning for that hash, no row, exit 1 at the end; other failures of a read are exit 15 (no answer, 429, 5xx) or 20 (another 4xx) at once. A GitHub list of 200 with no nightly tag is exit 15: `the list of nightlies at api.github.com has no nightly tag (<n> releases read). The bot stops, and the next run starts again.` |

R-MX16: The time and the order of a nightly in SQL (Design Q81). `toolchains` has one row for each (nightly, target) (R-RE4), and the rows of one tag come from one GitHub release in one transaction (R-PU8, R-PU9), so they have one `published_at`.

| Use | Rule |
| --- | --- |
| The time t of nightly N (the window of R-MX11 row 3) | `(SELECT MIN(published_at) FROM toolchains WHERE nightly = N)`. The rows are equal. `MIN` makes one value for each nightly. |
| A nightly with no `toolchains` row | It has no time, so no candidate is a member by the window. The newest live release of each group is still a member. The bot does not sweep it: R-AP39 gives 404 for its tag. It has no place in the order, so it has no `transitions` row. |
| The order of nightlies (R-MX12, R-NS1) | Over the distinct nightlies: the date (`nightly >> 28`, R-IK4), then t, then the id. The id of 2 nightlies of one date differs only in the sha, so for 2 tags of one form the last key is the order of the tag text of R-NS1. It is not the order of the ids alone, and not t alone. |

### 6.1 Shared probe results

A user who turns sharing on (CLI 1, R-SH1) sends to `POST /v1/compat` the unit checks of public hashes, the smoke builds of public platforms (Resolution 4, R-SM1) and the builds of public tool apps (CLI 1, R-SH3). They are user hints: rank 6, search order only (Resolution 3). Most of them are for hashes outside the bot set (R-MX14): older patches in headers, old series, and tool apps. Their counts also select the pairs of the hint audit (R-MX13). Reads do not need sharing: each client gets all of the matrix (R-AP4, R-AP17). This section holds what the Worker keeps, for how long, and who can delete it.

```mermaid
flowchart LR
    T["tln<br/>(sharing on)"] -->|"POST /v1/compat<br/>Talon-Contributor"| W["Worker"]
    W --> H["compat_hints<br/>counts, no contributor"]
    W --> P["contributions<br/>one row for each contributor and pair"]
    L["tln share login"] -->|"POST /v1/tokens<br/>GitHub token"| W
    W -->|"JWT"| L
    W --> K["links<br/>machine to account"]
    W --> C["contributors<br/>GitHub accounts"]
```

R-CT1: A user hint request has no `Authorization` header, and it has the header `Talon-Contributor: <id>`. The id is 32 lowercase hex characters (16 random bytes, CLI 1, R-SH5). A request with no token and with no valid id gets 400 `bad-request`. A request with a token has no id: the token selects `bot` (R-MX5).

R-CT2: The Worker checks the body and each user hint row. A row that is not valid (a missing field, a field of the wrong form, a value that the table does not allow) makes the whole request 400 `bad-request`, and the Worker writes nothing. A valid row that names a hash, a nightly or a target that the registry does not have is skipped (R-CT14).

| Field | Rule |
| --- | --- |
| `hash` | Indexed (R-RE1). Else the row is skipped. |
| `nightly` | A tag in `toolchains` (R-RE4). Else the row is skipped. |
| `target` | `any` for a unit check (Resolution 4, R-P4), for each kind. A real target only when the artifact kind is `app` (the build of a tool app, CLI 1, R-SH3) or `platform` (a smoke build, Resolution 4, R-SM1). A package with a real target gets 400. An `app` takes any target name that has a code (an app has no `artifact_targets` row). A `platform` takes only a target of its `artifact_targets` (R-RE20), else 400, as R-MX10 for the bot (Design Q173). A target with no code in `targets` is skipped (5.1, R-IK7), also for a package. A row whose hash is not indexed is skipped before its target is read, so it is never a 400 of the target. The 400 is from the first row of the body that fails (as R-AP66 check 8). |
| `result` | `pass`, `fail` or `crash`. A hang is not a hint (CLI 1, R-SH3). |
| `error_digest` | Not allowed in a row, with any value (text, `null`, a number): 400. No table keeps the error of a user hint (R-RE12, R-RE16), and the first error line of a build can name a local path. |
| `source` | Not allowed in the body or in a row, with any value, `null` too: 400 (R-MX5). |
| `sweep` | Not allowed, with any value, `null` too: 400. A sweep is a claim of the bot (R-MX4), and a client that sends one to a hint path has mixed the two paths (Design Q176). |
| `talon_version` | The version of `tln` (R-CT12) |
| `rows` | At most 500 (first guess). More: 413 `too-large` (R-AP46). |

R-CT3: A contributor is one signed 64-bit integer (5.1, R-IK2). Its sign tells the kind, so the two kinds never have the same id:

| Kind | Id | Row |
| --- | --- | --- |
| A machine (anonymous) | The first 8 bytes of HMAC-SHA256 of the id of the header (CLI 1, R-SH5) with the Worker secret `CONTRIBUTOR_KEY`, with the top bit set: a negative value | None. The Worker never stores the id of the header. |
| A GitHub account | The GitHub user id: a positive value | `contributors` (R-RE17), the index of the authors that logged in |

The message of the HMAC is the 32 characters of the id as UTF-8 bytes (Design Q175). The id is lower-case (R-CT1), so one id has one message. A change of this form unlinks every machine, as a new `CONTRIBUTOR_KEY` does, so it never changes. The contributor of a hint is the account of the machine when the machine logged in (`links`, R-RE18), else the machine. A new `CONTRIBUTOR_KEY` unlinks the rows of each machine from its id, so the stable id of CLI 1, R-SH5 stops working for them. The rows that moved to an account stay with it. The operator changes the key only after a leak of the key.

R-CT4: The Worker writes one user hint request as one D1 batch, in this order. The batch is one transaction (`cloudflare-workers/API.md` RF4).

| Step | Statement |
| --- | --- |
| 1 | `SELECT` the count of the distinct pairs (hash, nightly, target) of the rows that R-CT14 does not skip, that have no `compat` row and no `compat_hints` row. This is `first`. A skipped row is never `first` (`research/d1-contrib/` X2 found it). |
| 2 | `SELECT` the rows that R-CT14 skips: `skipped` |
| 3 | `INSERT ... SELECT COALESCE((SELECT contributor FROM links WHERE machine = ?), ?), ... ON CONFLICT (contributor, artifact, nightly, target) DO NOTHING RETURNING artifact` into `contributions` (R-RE16), with the rows that R-CT14 does not skip. The `COALESCE` gives the contributor of R-CT3. An `AFTER INSERT` trigger adds 1 to the count of the result in the `compat_hints` row of (artifact, nightly, target, talon_version), and enforces R-CT13. A row that the conflict skips fires no trigger, so a contributor counts once for a pair, and a request that `tln` sends again counts nothing twice (CLI 1, R-SH4). `written` is the count of returned rows. |

The answer is 201 when `written` is larger than 0, else 200. Two details that the test found (`research/d1-contrib/`, local D1 and SQLite, 22 cases):

| Detail | Reason |
| --- | --- |
| `ON CONFLICT DO NOTHING`, not `INSERT OR IGNORE` | `OR IGNORE` also skips a row that fails a `CHECK`, with no error. Then a bad row is lost and the rest of the request is written. With `DO NOTHING`, a `CHECK` failure stops the whole batch. |
| `written` from `RETURNING`, not from `meta.changes` | On D1, `meta.changes` also counts the rows that the trigger writes (9 in place of 3 for 3 new rows). Plain SQLite does not. |
| A pair twice in one request (Design Q180) | The first row of the body wins: the insert reads the rows in the order of their index, so the second row conflicts with the first one and counts nothing. The two rows may have two results. `first` counts the pair once. |
| Rows that write nothing (Design Q181) | A row that the conflict skips (the contributor sent the pair before) is not written and not listed in `skipped`: it is not a fault, and a request that `tln` sends again must give 200. A request whose rows are all skipped or all conflict has `written` 0 and the answer 200. `first` is read before the insert in the same batch, so it sees the state before: the same request sent again has `first` 0. |

R-CT5: There is no fold. A `contributions` row is the attribution of one result to one contributor, and it stays until its compiler is old (R-CT15), so the tracker computes each total from the rows when it is read (R-CT10). A daily cron step deletes each `compat_hints` row whose pair has a `bot` row: the hint has no use after it (Resolution 3, R-EF3), and the `contributions` rows keep the history. The hint audit (R-MX13) gives `bot` rows for the pairs with the most hints, so many hints get a `bot` row to compare with. The bot builds no tool app, so these builds stay `unconfirmed`. A smoke build of a user compares with the smoke row of the bot (R-MX10).

R-CT6: Retention:

| Data | Holds | Kept for |
| --- | --- | --- |
| `compat_hints` | Counts, with no contributor | Until its pair has a `bot` row (R-CT5), or until the trim of its nightly (R-CT15). The operator can delete the rows of one `talon_version` (R-CT7). |
| `contributions` | A contributor, a pair and its result | Until its compiler is older than 12 months (R-CT15), or R-CT7 deletes it. Then the totals of the contributor keep its class. |
| `contributor_totals` | A contributor and the totals of its trimmed rows, with no pair | Until R-CT7 deletes it |
| `contributors` | A GitHub user id and login | Until R-CT7 deletes it |
| `links` | A machine and its account | Until R-CT7 deletes it. A later login of the machine changes it. |
| The IP address | The key of the rate limit only (R-CT11) | Not written to D1 or to a log |
| D1 Time Travel (section 3) | Copies of each table | 30 days. So a deletion is complete 30 days after the request. |

Size: a `contributions` row is about 45 bytes (WITHOUT ROWID, R-IK8). The trim keeps the rows of 12 months of compilers, so the size stops growing. 1,000 users that send 20 new pairs a day hold about 330 MB. The daily limit of R-CT13 bounds a flood to 9 MB a day, and to about 3.3 GB at most, because the Worker skips rows of old compilers (R-CT14). D1 holds 10 GB (section 3). A `contributor_totals` row is about 50 bytes for each contributor.

R-CT7: Deletion. `DELETE /v1/contributors/me` (R-AP36) removes the linked data:

| Proof in the request | The Worker deletes |
| --- | --- |
| `Talon-Contributor`, with no JWT | The `contributions` and `contributor_totals` rows of that machine (the rows from before a login, R-CT8), and its `links` row |
| `Authorization: Bearer <JWT>` (R-CT9) | The `contributions` and `contributor_totals` rows of the account, the `links` rows to it, and its `contributors` row |

The Worker never changes `compat_hints` for a user. A count holds no contributor, so nothing ties a count to a person, and the Worker cannot find the counts of one contributor. This is the meaning of "a shared result cannot be retracted". The operator deletes the `compat_hints` rows of one `talon_version` when that version of `tln` sent wrong results.

R-CT8: Login (`POST /v1/tokens`, R-AP37). The account is a GitHub account:

```mermaid
sequenceDiagram
    participant T as tln share login
    participant G as GitHub
    participant W as Worker
    T->>G: POST /login/device/code (client id of the OAuth App "Talon")
    G-->>T: user_code, device_code
    Note over T: prints the URL and the code
    T->>G: poll POST /login/oauth/access_token
    G-->>T: GitHub token, no scope
    T->>W: POST /v1/tokens {github_token}, Talon-Contributor
    W->>G: GET /user
    G-->>W: id, login
    W-->>T: 201 {token: JWT, expires_at, account}
```

| # | Rule |
| --- | --- |
| 1 | The OAuth App `Talon` belongs to the org `roc-talon`, with the client id `Ov23li2sxWgMaAvjaUbQ`. The client id is public: it is a constant in the `tln` binary. The app has the device flow on and asks for no scope, so the token can read only public data. It is not the GitHub App `Talon Indexer` (R-PU25). Test: `research/oauth-device-flow/check.sh`. |
| 2 | The Worker reads `GET /user` with the token, and keeps no GitHub token. It does not revoke the token: the token has no scope, so it can read only public data, and `tln` does not write it to a file (CLI 1, R-SH7). The device flow needs no client secret, so the Worker has none. The Worker does not check which app made the token: any token of the account proves the account. So a party that has a GitHub token of the user can get a JWT of that user (Design 8, R-SE16). |
| 3 | The Worker upserts the `contributors` row of the account, and upserts the `links` row of the machine of the header to the account. Then it moves the rows of the machine to the account: `UPDATE OR IGNORE ... SET contributor = <account> WHERE contributor = <machine>`, then `DELETE` the rows of the machine that stayed (pairs that the account has already). The `contributor_totals` of the machine are added to the totals of the account (the counts are summed, `first_time` is the smaller, `last_time` the larger; a totals row of the account is made when it has none), then deleted. A login with no header `Talon-Contributor` upserts the `contributors` row only (Design Q311). The new row and the later login: R-RE17. Accepted: two machines of one person have two anonymous ids (R-CT3), so a pair that both sent and that the trim (R-CT15) removed before the login counts twice in the totals of the account. The rows are gone, so nothing can find the copy, and the totals are for display only. One account can have many machines. Before a login, nothing ties a machine to a person. A later login of the machine with another account moves the link, so new rows go to the new account, and the old rows stay with the old one. Test: `research/d1-contrib/` (L1 to L4). |
| 4 | GitHub refuses the token: 401 `unauthenticated`. GitHub does not answer: 502 `upstream`. Only status 401 is a refusal. Each other status (also 403 and 429: a GitHub limit is not a refusal of the token), no answer, and a 200 whose body has no integer `id` above 0 or no `login` that is not empty, is 502 (Design Q304). |

R-CT9: The JWT. The Worker signs it and the Worker checks it. No other party reads it.

| Part | Value |
| --- | --- |
| `alg` | `EdDSA` (Ed25519, WebCrypto) |
| `kid` | The id of the signing key: the member `kid` of `TOKEN_KEY` (R-WH14, Design Q300) |
| `iss`, `aud` | The base URL of the registry: the setting `AUDIENCE` (R-TP3 row 2, R-WH14) |
| `sub` | The GitHub user id, as a string. Not the login: a login can change (R-TP10). |
| `iat`, `exp` | `exp` is `iat` plus 30 days. Both are NumericDate (RFC 7519, 2) in seconds with 3 decimals: the request time in ms divided by 1000, for example `1767225601.234` (Design Q301). RFC 7519 allows a fraction. Only the Worker reads the token: `tln` keeps it as opaque text and uses `expires_at` of R-AP37 (CLI 1, R-SH13). |

The check: the signature with the public key of `kid`, `iss` and `aud` equal to `AUDIENCE`, `exp` after now, and `iat` not before `tokens_after` of the account (R-RE17). The compare of `iat` and `tokens_after` is in ms: `iat` times 1000, rounded down, equal to `tokens_after` is good, so a login in the same ms as a revoke gives a token that works (Design Q301). `exp` and an `iat` in the future have a leeway of 60 s, as R-TP3 row 3: the login and the next request can run on two machines whose clocks differ, and only the Worker signs, so an `iat` in the future proves nothing (Design Q301). `sub` must be digits only, an integer above 0 (R-CT16 row 6). The private key is the Worker secret `TOKEN_KEY`. The Worker has one key. A token with another `kid` gets 401. The operator changes the key only after a leak, as `CONTRIBUTOR_KEY` (R-CT3): then each token of the old key stops at once, and each user logs in again (CLI 1, R-SH8). A planned key change that keeps the old public key until the last token that it signed expires is a later item (`docs/registry/PLAN.md` G, Design Q310). `DELETE /v1/tokens` (R-AP38) sets `tokens_after` to now, so each token of the account stops. Reason for a JWT and not a session table: the check is one signature and the `contributors` read that the route does anyway.

R-CT10: The tracker. `GET /v1/contributors/me` (R-AP35) answers `{account: {id, login}, machines, counted, first, agreed, disagreed, unconfirmed, first_time, last_time}`. The Worker computes each total from the `contributions` rows of the account when it reads them, in one query (R-CT5), and adds the `contributor_totals` of the account (R-CT15):

| Total | Rows of the account |
| --- | --- |
| `machines` | The count of `links` rows to the account |
| `counted` | All |
| `first` | The pair has no `compat` row from before the row, and no row of another contributor from before it (on the same time, the smaller id is first) |
| `agreed` | The pair has a `bot` row with the same result class (R-RC1 to R-RC4 of Resolution 4) |
| `disagreed` | The pair has a `bot` row with another result class |
| `unconfirmed` | The pair has no `bot` row yet |
| `first_time`, `last_time` | The smallest and the largest `time`. Both also from `contributor_totals` (R-RE25): the smaller `first_time` and the larger `last_time`. `null` when the account has no row and no totals (Design Q302). |

A request with no JWT gets 401: a user who has not logged in has only the tracker on the machine (CLI 1, R-SH6).

R-CT11: The rate limit of user hints is per IP address. The key is the IPv4 address, or the IPv6 /64 prefix, from the header `cf-connecting-ip`: the rule "Rate key" of R-AP68 (Design Q168), with the same function. So an IPv4-mapped IPv6 address is its IPv4 address, and a missing or unreadable address is the key `unknown`, one key for all such requests (Design Q185). At most 30 requests a minute (first guess), with the rate limiting binding (`cloudflare-workers/API.md` RN10). The check is row 9 of R-AP70 (Design Q186). `Retry-After` is 60, the period of the binding (Design Q185). `POST /v1/tokens` and `DELETE /v1/contributors/me` have at most 10 requests a minute for one key (first guess), with one binding `RL_LOGIN` and one budget for both routes and both forms of the delete. Its place in the order: R-CT16 row 9 (Design Q308). `GET /v1/contributors/me` and `DELETE /v1/tokens` have no rate limit. Over the limit: 429 with `Retry-After` (R-AP25). The binding counts requests, not rows, and an id costs nothing, so R-CT13 also limits the rows of all users. The IP address is only the key of the binding: the Worker writes it to no table and no log.

R-CT12: `talon_version` is the version of `tln`, for example `0.4.1`. The Worker keeps it only when it is a release of Talon: a tag `v<version>` of `roc-talon/talon`, from the GitHub tag list that the Worker reads at most once an hour (`Memo`, `cloudflare-workers/API.md` 7.1; the hour is on the clock of the shim, so a test clock that jumps more than an hour gives a new read, Design Q443), with the installation token of R-PU25 (Design Q67). The App is installed on `roc-talon`, so the token reads `roc-talon/talon` also when the check of R-PU25 fails. Reason: a read with no token has 60 requests an hour for each IP address, and the Worker shares its IP addresses with other Workers. The token code is slice 119a (PLAN). A fault of the token gives the key 0 (R-PU43). Until then the read has no `Authorization` header, as the other GitHub reads of the Worker (R-AP57, R-AP68), so the Worker is not deployed before slice 119a (Design Q170). Any other value, also a build from source, is stored as `unknown` (the key 0, R-IK5). Reasons: the operator can delete the counts of one version after a fault of that version (R-CT7). And `talon_version` is part of the key of `compat_hints` (R-RE12), so a free value would let one client make a new row for each request, kept until a `bot` row comes.

| Item (Design Q178) | Rule |
| --- | --- |
| Read | `GET https://api.github.com/repos/roc-talon/talon/tags?per_page=100`, one page, with the headers `user-agent: talon-registry` and `accept: application/vnd.github+json`. The names are the `name` members of the array. |
| Memo | The names of a good read are kept for 1 h in the `Memo` of the isolate (the clock of the shim). Each isolate reads for itself. |
| A read that fails | A status other than 200, no answer, or a body that is not an array of objects with a text `name`: nothing is kept, the tags are `[]`, the request is written with the key 0, and the next request reads again. Reason: a kept failure would give the key 0 to all hints of the next hour. The reads after a fault are bounded by the limit of R-CT11. |
| More than 100 tags | A known limit (first guess): a version that is not on the first page is stored as `unknown`. Paging with the `Link` header comes when the repository has about 80 tags. |
| The key | The key of the version with no flip (R-IK5, Design Q177). |

R-CT13: A daily limit for all user hints. An `AFTER INSERT` trigger on `contributions` adds 1 to `counted` of the `hint_days` row (R-RE24) of the day of the row, and calls `RAISE(ABORT, 'hint-quota')` when `counted` is then above 200,000 (first guess). The abort stops the whole batch (R-CT4). The Worker maps `Constraint({ kind: Trigger, message: "hint-quota" })` to 429 `rate-limited` with `Retry-After` to the next UTC day (R-AP25): the seconds from the time of the request to 00:00:00.000 UTC of the next day, rounded up to a whole second (at 00:00:00.000 it is 86400; Design Q179). `tln` keeps the rows and sends them later (CLI 1, R-SH4). Reasons: a contributor id costs nothing and an IPv6 /48 has 65,536 keys of R-CT11, so the limit of R-CT11 alone allows about 21.6 million rows a day for each key (30 requests of 500 rows a minute). The daily limit bounds the growth of `contributions` and `compat_hints` to at most 200,000 rows a day in total. The trim removes old rows (R-CT15), so the limit also bounds the size that a flood can hold (R-CT6). A flood can use up the limit of one day. Then honest hints wait one day: they are rank 6, so no resolve depends on them. Test: `research/d1-contrib/` (Q1, Q2).

R-CT14: Skipped rows. The Worker does not count a valid row in these cases, and the answer lists it in `skipped`, as `{row, reason}` with the index of the row in the request:

| `reason` | Case |
| --- | --- |
| `unknown-hash` | The hash is not indexed |
| `unknown-nightly` | The nightly is not in `toolchains` |
| `unknown-target` | The target has no code (5.1, R-IK7) |
| `bot-row` | The pair has a `bot` row. `tln` does not send such a pair (CLI 1, R-SH3 filter 5), but its answer can be older than the row. Test: `research/d1-contrib/` (W6). |
| `old-nightly` | The `published_at` of the compiler is older than the age of R-CT15: below the request time minus 365 days (31,536,000,000 ms). A compiler at exactly 365 days is not old. A nightly has one `toolchains` row for each target, and the Worker takes the smallest `published_at`. The next trim would remove the row (Design Q174). Test: X2. |

The other rows of the request are written. Reasons: an old `tln` and a newer registry can disagree on one row, and with all or nothing, `tln` would drop the good rows of each request with that row (CLI 1, R-SH4). A pair with a `bot` row gets no use from a hint (Resolution 3, R-EF3).

R-CT15: The trim. The age of a pair is the age of its compiler: the `published_at` of its `toolchains` row (R-RE4), for a nightly and for a release. A daily cron step trims each compiler whose `published_at` is older than 12 months (first guess; in the Worker 365 days, 31,536,000,000 ms, as the `old-nightly` skip of R-CT14), the oldest first. One D1 batch for each compiler. When the batch of one compiler fails, the step writes a log line and goes on with the next compiler (R-PU35):

| Step | Statement |
| --- | --- |
| 1 | Upsert `contributor_totals` (R-RE25): for each contributor with rows on that compiler, add the classes of R-CT10 of these rows, and set `first_time` to the smaller and `last_time` to the larger of the row value and the `time` of these rows (Design Q302). The step runs before step 2, so the other rows of each pair are still there for `first`. |
| 2 | `DELETE` the `contributions` rows of that compiler |
| 3 | `DELETE` the `compat_hints` rows of that compiler |

The tracker of each contributor is the same before and after a trim (`research/d1-contrib/` X1). A class is fixed at the trim: a row with no `bot` row then stays `unconfirmed`.

Reasons for the time of the compiler, not the time of the first report of the pair: it needs no new column, because `toolchains` has it, and a nightly id is in date order (5.1, R-IK4). And a hint is old when its compiler is old: a report that comes today about a nightly of 2 years ago is a fact about an old compiler, which few resolves select (Resolution 2, R-C7). The `compat` rows are not trimmed: a sweep (R-MX4, R-MX8) and the epochs (Resolution 4, R-EP2) need the `bot` rows of old nightlies, and the bot set bounds their count (R-MX11). Not measured: the time of one batch for a compiler with many rows. If it is too long, the step runs for a range of contributors at a time.

R-CT16: The account routes (R-AP35 to R-AP38): the forms, the order of the checks and the edge cases (slice 117, Design Q300 to Q312). The first check that fails gives the answer. The client check of R-AP45 and the media type check come first (R-AP48): the write routes are `POST /v1/tokens`, `DELETE /v1/tokens`, `DELETE /v1/contributors/me` (Design Q182), and the tracker is checked with `MIN_TLN`.

| # | Item | Rule |
| --- | --- | --- |
| 1 | `github_token` (R-AP37, R-AP51) | A JSON text, not empty, at most 512 bytes, each byte from `!` to `~` (a space, a control byte or a byte above 126 cannot go in the header of the GitHub read). Else 400 `bad-request`. The `detail` never holds the token. Other members are ignored (R-AP44) (Design Q303) |
| 2 | Order of `POST /v1/tokens` | The body size (413, R-AP46), the header `Talon-Contributor` when there is one (400, before the body decode, as R-AP70 rows 5 and 6), the body (row 1), the rate limit (row 9), the GitHub read (R-CT8 row 4), the settings and the sign (a fault is 500 `internal`, before any write), D1 call 1 (R-CT8 row 3), 201 |
| 3 | The token proof | `Authorization: Bearer <token>`, then the decode with `alg` `EdDSA` only and the `kid` of `TOKEN_KEY`, the signature, then the claims of R-CT9. Each fault is 401 `unauthenticated` with no D1 call. A missing or bad `TOKEN_KEY` or `AUDIENCE` is 500 `internal` |
| 4 | A good token whose account has no `contributors` row (never here, or deleted by R-CT7) | `GET /v1/contributors/me`: 401 (no login to show). `DELETE /v1/tokens`: 401. `DELETE /v1/contributors/me`: 204 (R-AP36: also when nothing was stored, so `tln` can send it again). `tln` reads the 401 as "log in again" (CLI 1, R-SH8) (Design Q305) |
| 5 | `tokens_after` of a new `contributors` row | The time of the login, never 0. A delete (R-CT7) removes the row, so with 0 a later login would make the tokens from before the delete good again. A login never changes `tokens_after` of a row that exists: `ON CONFLICT DO UPDATE`, never `INSERT OR REPLACE` (Design Q307) |
| 6 | `sub` | The text of an integer above 0, digits only (`0`, `-5`, `+7`, `12.5` and an empty text are 401) |
| 7 | The proof of `DELETE /v1/contributors/me` (R-AP36, R-CT7) | A header `Authorization` (any value) is the account form, and the header `Talon-Contributor` is then ignored, as R-CT1 (a token wins). A bad token is 401 and deletes nothing. No `Authorization` and a valid `Talon-Contributor`: the machine form. A bad id: 400. Neither header: 400 `bad-request` (Design Q306) |
| 8 | A revoked token on a write | `DELETE /v1/tokens` and the account form of the delete check `tokens_after` in the guard of their one batch (`WHERE tokens_after <= iat`, `NOT EXISTS`), so a revoked token changes and deletes nothing, with 1 D1 call (R-AP41 row 3) |
| 9 | `RL_LOGIN` (R-CT11) | After each check that needs no D1 call and no GitHub read: for the login after row 1, for the account form of the delete after the token proof, for the machine form after the id check. Before the first D1 call or GitHub read, as R-AP68 row 3 (Design Q168, Q186). A request that gets there counts. `Retry-After: 60` (Design Q308) |
| 10 | D1 calls | 1 for each of the 4 routes, one batch on the primary (R-AP41 row 5). The login makes its call after the GitHub read (Design Q309) |
| 11 | Answers | A body: `content-type: application/json`, `cache-control: no-store`. 204: no body, `cache-control: no-store`. The tracker has no `ETag` (R-AP24, Design Q312). No answer holds the GitHub token |

## 7. Publish flow

R-PU1: A publish runs these steps:

```mermaid
sequenceDiagram
    participant CI as GitHub Actions (release)
    participant W as Worker
    participant GH as GitHub
    participant D as D1
    participant R as R2
    CI->>W: tln publish: POST /v1/releases (OIDC token, asset URL)
    W->>W: check the token claims (R-TP3) and the repository ids (R-TP5)
    W->>GH: GET asset, GET .roc-version at tag
    W->>W: hash, unpack, parse header (Roc)
    W->>D: one transaction: artifact, release, log leaf
    D-->>W: ok, or reject if label exists with other hash
    W->>R: write new tiles, sign checkpoint (P3, R-SG7)
    W->>W: drop the cache entries of the group in this colo (R-AP43)
    W-->>CI: 201 or 200: log index, record. 409 if the label has another hash.
```

| # | Path | Trigger | Auth |
| --- | --- | --- | --- |
| R-PU2 | `tln publish` in the release workflow | Author | GitHub OIDC (trusted publishing, section 7.1) |
| R-PU3 | GitHub App webhook (`POST /v1/webhooks/github`, R-AP12) | The `release` events of R-PU11 | App installation on the repo |
| R-PU4 | `POST /v1/releases` with no token (R-AP9) | Anyone, with a public URL | None. The bytes and the tag are public, and the hash checks them. The Worker checks that the repository is public (R-PU31, R-PU32). |

R-PU5: `tln publish` also sends the real facts of the released hash (Resolution 4, R-PB5). The Worker writes them as `compat` rows with the source `author`, with the release. The form of the facts: R-AP71.

R-PU6: For a GitHub release, each path selects the package asset and reads the version and the group with the rules of `direct` mode (CLI 7.3, R-DI3 to R-DI5). So the registry does not index a draft, a prerelease, or a release with 0 or 2 package assets, and `tln` sees the same candidates in both modes. A URL on another host is not indexed by a P2 path (R-PU40). When a later path indexes one, it gets the version and group from the roc rule (Design 2), as in R-DI5.

R-PU38: Archive read (Q28). Each path (R-PU2 to R-PU4) downloads the package asset, computes its BLAKE3 (the roc hash, Design 2), and reads its header. The registry runs on Workers Paid (30 s of CPU for a request by default, up to 5 min with `limits.cpu_ms`), so CPU does not limit the size: BLAKE3, zstd decode and the tar read of basic-cli 0.26.0 (a 21 MB platform archive, 70 MB unpacked) take 1.4 s in Node and 4.6 s in workerd, measured by `roc-tar` (`bench/results/`, 2026-11-01). zstd is most of it, and the tar read adds under 1 %. WebCrypto has no BLAKE3, so the hash runs in wasm (Design R-GA3), and its CPU time counts. Memory is the limit that matters: the isolate has 128 MB (section 8, R-WH9). So:

| # | Rule |
| --- | --- |
| 1 | The Worker reads the asset as a stream. Each chunk goes to BLAKE3 and to the zstd decoder (`Native.Blake3`, `Native.ZstdStream`), then to the tar reader `roc-tar` (Design 6.1, R-PK8, 6.2, R-GA2). The Worker keeps only the header file, the list of paths (the targets of a platform, R-RE20) and the packed size (R-RE1). It never holds the whole archive or the unpacked tree. |
| 2 | The packed size is at most 100 MB (first guess, 5 times basic-cli). The Worker checks `Content-Length` before it reads, and counts the bytes while it reads. Over the limit: 422 `not-a-candidate`, with the size in the `detail`. Reason: an ingest needs no login (R-PU34), and GitHub allows assets up to 2 GiB. |
| 3 | A zstd frame whose window is larger than 8 MiB is refused in the same way, because the window sets the memory of the decoder. 8 MiB is the hard limit of `Native.ZstdStream` (`WindowTooLarge`). Real bundles use 2 MiB (basic-cli 0.26.0, Design Q57). |
| 4 | The hash of the whole stream must be equal to the hash in the URL before any write. The header read can end early, but the hash reads to the end. |
| 5 | The tar reader is `roc-tar` (Design R-PK8) with these limits: the unpacked total at most 256 MiB (about 17 s of CPU in workerd at the measured speed, inside 30 s), at most 10,000 members, a path at most 255 bytes (as `roc unbundle`), and the header file collected up to 1 MiB. Over a limit: 422 `not-a-candidate`, with the limit in the `detail`. The read counts all decoded bytes: members, headers, padding and any zeros after the end of the tar. The limit is 256 MiB plus 16 MiB for headers and padding (285,212,672 bytes; 10,000 members take at most about 10 MB of headers and padding). Over it, the decoding stops at once and the refusal is `the unpacked archive has more than 285212672 bytes`. The hash of the packed stream (row 4) still reads to the end, and the order of refusals is row 9 (Design Q441). |
| 6 | The Worker refuses each path that `roc unbundle` refuses: an empty path, a leading `/`, a `..` or `.` part, a backslash, a drive letter (`C:`), a Windows reserved name, and a path over 255 bytes. It also refuses a symlink, a hard link, a device, a duplicate path, and the strict errors of `roc-tar` (a lone zero block, data after the end, data on a link or a dir). Reason: a release that roc cannot unbundle is not a candidate (R-PU6). Any end form of the archive (two, one or no zero blocks) is accepted, because the hash of row 4 already finds a cut stream. |
| 7 | The header file is the member `main.roc` at the archive root. `roc bundle` writes it first. |
| 8 | A hash that is not the hash of the URL (row 4) gives 422 `not-a-candidate`, and the `detail` names the 2 hashes. Reason: roc refuses the archive too (`HashMismatch`, `roc:src/unbundle/unbundle.zig:676`, roc `338f10a`), so the bytes at the URL are not the release (Design Q123). |
| 9 | When a read has more than one refusal, the answer gives the first of: (1) the hash of row 4, (2) the first refusal of the read in stream order (zstd, tar, kind, path, duplicate), (3) an error at the end of the tar (a cut in a header, data or padding), (4) no header file, (5) an error of the header file. A size over the limit of row 2 stops the read at once and gives row 2, because the stream can have no end. Reason: a wrong hash says that the bytes are not the release, so a refusal of those bytes says nothing about the release (Design Q124). |
| 10 | Each other error of the zstd decoder also gives 422 `not-a-candidate`: a damaged frame, a stream that ends inside a frame, a frame that needs a dictionary, and the output limit of one push. The Worker opens `Native.ZstdStream` with its default limits (8 MiB window, 16 MiB of output from one push). The output limit is a limit of the platform, not of roc: first guess, and the platform request is in slice file 111, issue P2 (Design Q125). |
| 11 | Targets (R-RE20, R-IK7). A target name is the `<name>` of a member `targets/<name>/<more>` of a platform, when it matches `[a-z0-9]{1,32}`. A dir under `targets/` whose name does not match (`targets/macos-sysroot/` of basic-cli), and a file directly in `targets/`, are skipped: they are not targets, and the archive stays a candidate. Reason: roc looks only in the dirs of the targets that the platform header declares (`roc:src/compile/targets_config.zig:316`), and the linker reads `targets/macos-sysroot/` as files for the link (`roc:src/cli/linker.zig:372-374`) (Design Q126). |
| 12 | Member kinds (row 6). A file (tar type `0` or NUL) and a dir (type `5`) are accepted. Each other type is refused: a symbolic link (row 6), a hard link, a device, a FIFO (`6`), a contiguous file (`7`), a sparse file, and an unknown type. The prefix headers (pax `x` and `g`, GNU `L` and `K`) are not members. Reason: roc reads only a file, a dir and a symbolic link, and refuses each other type (Zig 0.17 `lib/std/tar.zig:403-474` gives `TarUnsupportedHeader`, which `roc:src/unbundle/unbundle.zig:724-745` makes `InvalidTarHeader`) (Design Q127). |
| 13 | The platform entry and `roc` (R-RE1, R-RE19, R-AP49). The platform entry of an app (`pf: platform "<url>"`) gives `platform_hash` only, not a `deps` row. The entry `roc` gives `roc_pin` only, not a `deps` row: roc reads it as a compiler version, not a package (`roc:src/parse/Parser.zig:1718-1757`). Each other entry is a `deps` row, in header order. roc also reads a platform entry in a package or platform header (`Parser.zig:1529-1547`, `1563-1627`). There it is a `deps` row, because `platform_hash` is `null` for these kinds (R-AP49) (Design Q128). That row has `platform` 1 and every other row has 0 (R-AP81, Design Q251). A header with 2 or more platform entries is refused by roc (`multiple_platforms`, `Parser.zig:1595`), so the Worker gives 422 `not-a-candidate` for it, as for any header that roc refuses (row 7). If the header parse of the Worker accepts it, the Worker checks the count itself and gives the same answer (Design Q400). |
| 14 | Dep URLs (R-RE19). Each `deps` entry must start with `https://`, `PackageUrl.parse` must give `Ok` or `NoVersion`, and the hash (the text of the last segment before `.tar.zst`) must be base58 of 32 bytes. Else: 422 `not-a-candidate`, and the `detail` names the alias and the URL. So a path entry (`../util/main.roc`), `http://`, no hash, 2 versions and `0.0.0` are refused. A URL with no version is accepted (R-RE19). Reasons: roc downloads only `https://` (or `http://` to a loopback host, which no other user can reach) (`roc:src/unbundle/download.zig:102-108`). roc refuses 2 versions and `0.0.0` (`roc:src/base/url.zig:175`, `268`), and a hash that is not base58 of 32 bytes (`unbundle.zig:813-839`). A path entry has no hash, so it cannot have a `deps` row, and the closure query (R-AP17) cannot follow it. The dep id of R-IK2 needs the 32 bytes (Design Q129). |
| 15 | The limit of row 2 is 100 MB = 100,000,000 bytes (10^8, decimal). 100,000,000 bytes pass, 100,000,001 bytes are refused. The limits of rows 3 and 5 are in MiB (2^20 bytes): 8 MiB is 8,388,608 bytes, 256 MiB is 268,435,456 bytes, 1 MiB is 1,048,576 bytes (Design Q130). |
| 16 | The header file (row 7, Design R-PK5). `main.roc` that is not UTF-8 gives 422 `not-a-candidate`: roc refuses it (`roc:src/parse/tokenize.zig:1159-1189`, `InvalidUtf8InSource`). `main.roc` with no `app`, `package` or `platform` header (no header, or a `module` header) gives 422: roc reads it as a module, not as an app, package or platform (`Parser.zig:1366-1371`), and `kind` is a closed set (R-AP49). An app that names no platform is accepted, with `platform_hash` `null`: roc gives it the built-in Echo platform (`Parser.zig:1772-1775`) (Design Q131). |
| 17 | Duplicates (row 6). The Worker compares member paths by a key: the parts of the path between `/`, with no empty part, joined by `/`, with each ASCII letter `A` to `Z` as `a` to `z`. 2 members (of any kind) with one key are a duplicate: 422 `not-a-candidate`. A member below a file member (the file `a` and the member `a/b`) is also refused. The header file of row 7 is the file member whose key, with no change of case, is `main.roc`. Reasons: roc splits a path at `/` (`unbundle.zig:160-176`), so `a//b`, `a/b/` and `a/b` are one file, and it writes a second member over the first one (`unbundle.zig:194-218`). So the header that the registry reads can be another text than the `main.roc` that roc reads. A case-insensitive file system (macOS, Windows) does the same with `main.roc` and `MAIN.ROC`. roc refuses a member below a file (`unbundle.zig:175`, `NotDir`). Only ASCII letters are folded (first guess) (Design Q132). |
| 18 | The platform URL of an app (row 13). It must pass the checks of row 14 (`https://`, `PackageUrl.parse` gives `Ok` or `NoVersion`, the hash is base58 of 32 bytes). Else: 422 `not-a-candidate`, and the `detail` names the alias and the URL, as for a dep. So a URL with no `<hash>.tar.zst` segment and a path platform (`"../pf/main.roc"`) are refused. Reasons: roc refuses a platform URL that is not `https://` or that has no hash (`roc:src/compile/package_resolution.zig:984-1000`), and an absolute path (`952-966`). roc accepts a relative path only when the file is in the unbundled tree (`968-980`), but such a platform has no hash, so `platform_hash` cannot name an artifact (R-RE1), and the matrix and the closure cannot key it (Design Q136). |

R-PU39: API check (Q31). `tln publish` runs `roc bump --old <URL> --expect <version>` (Design 2) before it sends the request. `<URL>` is the newest indexed release of the same group with a smaller version that is not yanked (R-AP13). `<version>` is the version of the label. roc runs with the compiler of the `roc:` pin of the release header. When roc says that the label bumps less than the API change needs, Talon prints a warning that names both versions and the bump that roc wants, then sends the publish. It does not stop. Reason: the asset is already public on GitHub, and the webhook, the reconcile and an ingest index it anyway (R-PU3, R-PU4), so a stop would lose only the author facts and the provenance of R-PU2. A workflow that wants to stop the release runs `roc bump --expect` itself before the upload. A first release (no earlier version), or a `roc bump` that fails for another reason (the old version does not compile with this compiler), gives a note and no warning. The exit code does not change. The registry does not run `roc bump`: it runs no Roc compiler (R-RL3). The texts are a proposal (CLI 3, R-OUT2). The details are in CLI R-PUB4 item 13 (Design Q523 to Q530): the previous release is not a withdrawn release and not a pre-release (none exists, R-IK5); the compiler of the pin is the one that is installed (an optional download, R-DL2); the new package is the project file of the job; `roc bump` exits 0 or 1 only, so the text of roc tells the causes (`research/roc-bump`).

Compiler releases, from P2:

| # | Step | What happens |
| --- | --- | --- |
| R-PU7 | 1 | The compat bot (section 6) finds a new compiler release and calls `PUT /v1/toolchains/{tag}` (R-AP6) with an OIDC token. |
| R-PU8 | 2 | The Worker reads the release from the GitHub API itself. It does not trust the body of the bot for the sha256. It selects the assets with R-CV1 and R-CV2 (CLI 6.2) and takes each sha256 from the `digest` field and each size from the `size` field (R-AP80). |
| R-PU9 | 3 | One D1 transaction writes a `toolchains` row and a compiler log leaf (section 3) for each asset, with the statements of R-SG8. A tag that already has rows is not written again. |
| R-PU10 | 4 | If GitHub later shows another `digest` for a recorded asset, the Worker keeps the recorded row (also its `size`) and returns it. `tln` then stops at R-CV4 with exit code 16. |

Webhook, idempotency and provenance:

One release can come in on 3 paths (R-PU2 to R-PU4), in any order. GitHub sends no event when an asset is uploaded. Evidence, checked on 2026-10-16:

| Source | Result |
| --- | --- |
| GitHub OpenAPI description (`github/rest-api-description`, commit `51a4657888cc`, `x-webhooks`) | 275 webhooks. The release webhooks are `release-created`, `-deleted`, `-edited`, `-prereleased`, `-published`, `-released`, `-unpublished`. No webhook has `asset` in its name. The `changes` object of `release-edited` has only `body`, `make_latest`, `name` and `tag_name`. |
| `octokit/webhooks` payload schemas (commit `aa80c24a3f55`) | The same 7 actions of `release`, and no event for assets |
| GitHub docs, "Webhook events and payloads" | No asset event |

A schema shows the events that GitHub documents, not the events that it sends. A live test (`research/github-release-events/README.md`) confirms the result. Until then, R-PU13 does not depend on it: the retries also find an asset that comes with no event. So a release that gets its asset after it is published gives one event with 0 assets.

| # | Rule |
| --- | --- |
| R-PU11 | The GitHub App subscribes to the `release` event, to the `installation` and `installation_repositories` events for R-PU26, and to the `repository` event with the actions `privatized` and `publicized` for R-PU33. The Worker uses the actions `published`, `released`, `edited`, `prereleased`, `unpublished` and `deleted` of `release`, and ignores `created` (a draft). It uses `privatized` and `publicized` of `repository`, `created`, `deleted`, `suspend` and `unsuspend` of `installation`, and `added` and `removed` of `installation_repositories`. Every other event or action (for example `new_permissions_accepted`, `archived`, `ping`) is ignored: 202 and no message. GitHub Apps do not receive the action `deleted` of `repository` (GitHub docs), so a deleted repository is found by the reconcile (R-PU24). The order of the checks is in R-AP79 (Design Q320 to Q322). It checks the signature (R-AP12), sends one message for each event that it uses to the index queue (R-PU13, binding `INDEX`, R-WH14), and answers 202. The queue consumer does the work of R-PU12 to R-PU20, R-PU26 and R-PU33. The message holds the event, the action and the GitHub ids of the repository, the installation and the release, not a name (R-PU32). Reasons: GitHub stops a delivery after 10 s. The work (a download of up to 100 MB, BLAKE3, zstd, the D1 batch, Q28) can take longer than the 30 s that `Response.after` gives after the answer (`cloudflare-workers/API.md` 10.2), and a queue consumer has 15 min. So the webhook releases and the retries of R-PU13 use one code path (Design Q56). |
| R-PU12 | The Worker does not use the release in the event body. It reads the release again from the GitHub API, as R-PU8 does for a compiler release: `GET /repos/{full_name}/releases/{release_id}`, with the `full_name` of the answer of `GET /repositories/{repository_id}` that the same job read (R-PU31) and the `release_id` of the message. The message holds no name (R-PU32). A 404 for the release: the job stops (R-PU13) (Design Q328). A job `deleted` does no release read: the read of a deleted release always gives 404 (R-PU17, Design Q336). Reason: GitHub can send an event again later (redelivery), and its body can be old. |
| R-PU13 | For `published`, `released` and `edited`: when the release passes R-PU6, the Worker indexes it as an ingest of its asset URL (R-PU4), with the provenance `webhook` (R-PU15). When the release has no package asset, the Worker reads it again after 1, 5, 15 and 60 minutes (first guess), and indexes it when the asset is there. Each delay counts from the read that failed (R-PU45), so the reads come at 0, 1, 6, 21 and 81 minutes after the event. A release that has no asset at the fifth read is not a fault: the job ends with an info log line, and no dead letter (R-PU45, Design Q323, Q334). It stops early when the release is deleted. A release with 2 or more package assets is not a candidate (CLI 7.3, R-DI4), so the Worker does not read it again. |
| R-PU14 | Each path is idempotent for a label. When the label (group, version) exists with the same hash, the path writes no artifact, release or log row, and the answer is the existing record (200, R-AP8). The path adds only its own provenance row (R-PU15), and a publish also adds its author facts (R-PU16). When the label exists with another hash, a publish and an ingest get 409 `label-conflict`. The webhook path writes nothing and logs the conflict. |
| R-PU15 | The `provenance` table holds how each release came in. Key: (release, via), with the log index of the release (R-IK6, R-RE9, Design Q60). `via` is `oidc` (a publish), `webhook`, `poll` (a reconcile, R-PU21) or `ingest`. Fields: the recorded claims (R-TP6) for `oidc`, the attestation result (Design 8, R-SE10), time. A row is only added (`INSERT OR IGNORE`), never changed. When the row of that `via` exists, the path writes no new row. The release record in an answer lists the `via` of all its provenance rows (R-AP49 `provenance`, Design Q158). `tln add` shows the strongest one: `oidc`, then `webhook`, then `poll`, then `ingest` (Design 8, R-SE3). |
| R-PU16 | A publish of a label that the webhook or an ingest indexed first, with the same hash: the Worker adds the `oidc` provenance row and the author facts (`compat` rows with the source `author`, R-PU5, R-MX5), and answers 200. The author facts are rows of `compat`, not of `releases`, so R-RE6 holds. A publish of a draft gets 422 `not-a-candidate`. The `detail` says `draft` when the Worker sees the draft. When the Worker gets a 404 for it (a draft is a 404 to a read with no right to see it), the `detail` says that the repository has no published release with the tag and that a draft is not published (R-AP75 row 12, Design Q297). So the release workflow publishes the GitHub release before `tln publish` (Resolution 4, R-PB5). |
| R-PU17 | A release that stops being a candidate on GitHub is withdrawn: the action `deleted`, `unpublished` (back to a draft), `prereleased`, or `edited` when the release is now a prerelease. The Worker sets `releases.withdrawn` to the action and the time. For `deleted` the webhook job cannot find the label (the release read gives 404, and the message has no tag), so it sets `next_check_at` to now for each `repo_checks` row of the repository id whose state is not `moved` (as `publicized`, R-PU33), and the next reconcile sets `deleted` (R-PU23, Design Q336). The state that the release read shows governs, not the action (R-PU12, Design Q338): a `published` or `released` event for a release that is not final now writes nothing, and an `unpublished` or `prereleased` event for a release that is final now is the same as `published`. A row that has a `withdrawn` value keeps that value and its time (Design Q339). A reconcile also sets it (R-PU23), and R-PU24 adds the value `repo-missing`. A withdrawn release is not a candidate, as a deleted release in `direct` mode (CLI 7.3, R-DI3, R-DI14, Resolution 2, R-C6). It stays in the index and in the log, and its label keeps its hash (R-PU14). When the release is a candidate again with the same asset hash (`published`, `released` or `edited`), the Worker clears `withdrawn`. A release with 2 or more package assets is not a candidate (R-PU6), so it clears nothing. Only the reconcile clears `repo-missing` (R-PU24): a webhook job keeps it (Design Q360). `tln audit` reports a withdrawn header value as it reports a yanked one. |
| R-PU18 | Without the App on a repository, the registry learns of a new release or a deletion only at the next reconcile of that repository (R-PU21). Until then, a new release is not in the index, and a deleted release stays a candidate whose download fails with a 404 (CLI 7.1, R-FE6). Answers show the age of the index (R-AP29). |
| R-PU19 | A label keeps its first hash. When a release shows a new package asset for a label that the index has with another hash (a tag that is released again), each path gets 409 `label-conflict`, and the registry indexes nothing new. The `detail` says to release a new version. Reasons: the log proves that a label has one hash (Design 8, R-SE2), roc rejects one label with two hashes in one build (Design 2, "Conflicting Package Contents"), and a changed asset for an old label is the attack that the log finds. Go checksum database and crates.io have the same rule. |
| R-PU20 | Each path that reads a release from GitHub (R-PU12, R-PU17, a 409 of R-PU19) also checks that the recorded asset `<hash>.tar.zst` of each indexed label of that release is still there. When it is not there, the Worker sets `releases.withdrawn` to `asset-replaced` and the time (R-PU17). A withdrawn release is not a candidate. When the recorded asset is there again and the release is a candidate (R-PU6, R-PU17), the Worker clears `withdrawn`. A release with no package asset whose recorded asset is gone gets `asset-replaced`, and the job also reads it again (R-PU13, Design Q363). So after a tag is released again, the registry gives no candidate for that label, and `direct` mode gives the new hash only where R-DI15 (CLI 7.3) does not stop it. |

Reconcile, from P2:

R-PU21: The Worker reads each indexed GitHub repository again on a schedule (a reconcile). For each release in the list, the work is the same as an ingest (R-PU4), so R-PU6, R-PU14, R-PU17, R-PU19 and R-PU20 apply. The provenance is `poll` (R-PU15). Only a new candidate gets the `poll` row, through the index job (R-PU13, R-PU14). A release that is indexed already gets no new provenance row from a reconcile: the reconcile does not run the index flow for it, only the checks of R-PU17, R-PU19 and R-PU20 (Design Q373). Reasons: a repository with no App and no `tln publish` sends no signal (R-PU18), and GitHub does not send a failed webhook delivery again by itself (GitHub docs, "Handling failed webhook deliveries"). So a repository with the App can also miss a release.

| # | Rule |
| --- | --- |
| R-PU22 | Interval: 1 h for a repository with no App installation, 24 h for a repository with the App (`repo_checks.app_installed`, R-RE14). First guesses, tune in P2. The default `min-release-age` of 2 days (Resolution 2, R-C7) hides a new release for longer than each interval, so most users do not see the lag. |
| R-PU23 | Steps. A cron trigger (every 5 min, first guess) selects the `repo_checks` rows with `next_check_at` at or before now, oldest first, at most 500 rows (first guess). A run of R rows uses 1 + R D1 calls (the claim of R-PU37, then 1 batch for each row) and about 2R `fetch()` subrequests (the visibility read of R-PU31 and the list, more for a list of more pages), so R is at most 1,000 minus the other D1 calls of the run, and at most the subrequest limit minus the other fetches (Q47). The run handles the claimed rows in the order of `repo` (R-PU37 row 1, Design Q370). A row in the state `moved` is checked as any other row (Design Q375). For each row, the Worker reads the release list of CLI 7.3, R-DI2 with `If-None-Match` and the stored `etag` (no header when the row has no `etag`). A 304 answer is a pass: it changes only `checked_at`, `next_check_at` and `fail_count` (0, R-PU37 row 3), and no `etag` and no release (Design Q374). For a 200 answer, the Worker stores the new `etag`. Pages (Design Q372): while an answer has a `Link` header with `rel="next"`, the Worker reads the next page, `?per_page=100&page=<n>` (it makes the URL itself and does not use the URL of the `Link` header), at most 10 pages (first guess). More pages: the row fails. A list of more than one page is one list, and a release id that comes 2 times is kept once. A row whose list has more than one page stores `etag` NULL, because a 304 for page 1 does not show a change on a later page. Each new candidate goes to the index job of R-PU13 (`cloudflare-workers/API.md` RN16). Each indexed release that is not in the list gets `withdrawn` = `deleted`, and each one that is now a prerelease gets `withdrawn` = `prereleased` (R-PU17). The token of R-PU25 does not show drafts, so a release that is a draft again is also `deleted`. Then the Worker sets `checked_at` to now and `next_check_at` to now plus the interval. The cron only reads lists. It does not hash or unpack an archive, so it stays in the CPU limit of a cron (RN17). |
| R-PU24 | When GitHub answers 404 for the repository (it is deleted, or it is private and the App is not installed on it), or the visibility read of R-PU31 shows that it is not public (R-PU33), the Worker sets `withdrawn` = `repo-missing` on each release of that repository that is not withdrawn yet. The withdraw does not change the binding ids of the `repos` row (R-TP5). It sets the state `missing` (section 7.3, R-TP11). In the same batch, it sets `etag` and `repo_etag` to NULL on each `repo_checks` row of the repository id, so the first read that shows the repository public again gets a 200 list (Design Q376). The job `privatized` does the same (R-PU33). When a later reconcile reads the list again (200) and the binding of section 7.1 allows it, R-PU17 clears `repo-missing` for each release that is a candidate again with the same asset hash. The binding check is R-TP9 with the ids of the read by id against the claimed row. The read by id always has the recorded `repository_id`, so only R-TP9 rows 1 and 2 apply, and both allow the clear (row 2 writes the new owner id and the event `transfer` first, Design Q379). In the same batch, a `missing` row of the current name gets `active` and the event `found` (R-TP11, Design Q378), and a new `full_name` gives the rows of R-TP18 (Design Q380). |
| R-PU25 | Token: an installation token of the GitHub App `Talon Indexer`, which the organization `roc-talon` owns and on which it is installed (RN18). The Worker never uses the token of a user (CLI 1, R-RG3). A token lives 1 h (GitHub docs, "Generating an installation access token"), and the Worker keeps it until 5 min before its end. The installation can send 5,000 requests per hour (GitHub docs, "Rate limits for the REST API"). A 304 answer to a request with a token does not count (CLI 7.3, R-DI2). When `x-ratelimit-remaining` is under 10 % of the limit, the Worker moves `next_check_at` of the rest of the batch to the reset time (`x-ratelimit-reset`). The row that gets that answer does all its work first (its list read and all its pages too), so a row never stops in the middle. The rest of the batch is the claimed rows after it in the order of R-PU23 (Design Q377). |
| R-PU26 | The `repo_checks` row of a name is added with the first indexed release of that name, in the same write as the binding of R-TP5, with `next_check_at` = now plus the interval. The App events set `app_installed` (R-PU11) of each row of each repository id in the event (a row that is `moved` too, Design Q324, R-TP19): to 1 for `installation` `created` and `unsuspend`, and for `installation_repositories` `added`; to 0 for `installation` `deleted` and `suspend`, and for `installation_repositories` `removed`. Reason for `suspend`: GitHub does not say that a suspended installation gets events, and a wrong 0 costs only a read every hour (R-PU22), where a wrong 1 leaves the index old for up to a day (Design Q322). A repository with no `repos` row gets no write (R-PU32). So a job `Release` (R-PU13) of a message with an installation id of 1 or more also sets `app_installed` to 1: for the rows of that repository, and for the row that it adds with a new name (Design Q335). Reason: GitHub does not send a failed delivery again, and an event for a repository with no row is lost. The job sets it when the repository read shows public (R-PU31), whatever the release read gives (also a conflict, no asset, a 404 or a refusal), and it does not change `next_check_at` of a row that exists (Design Q362). |
| R-PU27 | A host other than `github.com` has no release list. The Worker does not read it again, and its releases change only through the path that indexes them (R-PU40: no P2 path does). This is the same as CLI 7.3, R-DI11. Answers give `checked` only for `github.com` repositories (R-AP29). |

P2 check for R-PU25: the GitHub docs say that an installation token "cannot be granted access to repositories that the installation was not granted access to". They do not say if it can read a public repository that is not in the installation. Test this before the P2 reconcile code. If it cannot, the Worker uses a fine-grained token of a bot account with read access to public repositories only, with the same rules (the secret `GITHUB_READ_TOKEN`, R-WH14). The user runs this check with the real GitHub App `Talon Indexer` (a probe in `research/`) before the slice of the reconcile code. If the check fails, this fallback applies. Result (2026-11-02, `research/github-app-check/RESULT.md`): PASS. The App `Talon Indexer` (id 5572595) is installed on `roc-talon` with `roc-talon/talon` only, with contents read and metadata read. Its installation token reads the repository, the release list, a release by tag, the assets, `/repositories/{id}` and file contents of `roc-lang/basic-cli` and `Karakatiza666/roc-semver`, which are not in the installation. The limit is 5000 an hour, and a 304 does not count. So R-PU25 stands, and the fallback `GITHUB_READ_TOKEN` is not needed.

The token code of the Worker (slice 119a, Design Q280 to Q285):

| Rule | Text |
| --- | --- |
| R-PU41 | Settings and JWT. The installation id is the setting `GITHUB_APP_INSTALLATION_ID` (R-WH14). The Worker makes no call to find it. The App JWT is RS256 with the header `{"alg":"RS256","typ":"JWT"}` and the payload `{"iat":<now - 60>,"exp":<now + 540>,"iss":<app id>}`, `iss` as a JSON number. `GITHUB_APP_ID` is digits only. A client id (`Iv23...`) is not a valid value. The GitHub docs ("Generating a JSON Web Token (JWT) for a GitHub App") say that `iss` is the client id or the app id and that `exp` is at most 10 min ahead. The app id is the form that the real check used (`research/github-app-check/check.sh`). The key setting `GITHUB_APP_KEY` is a PKCS#8 PEM (`-----BEGIN PRIVATE KEY-----`), because WebCrypto `importKey` takes PKCS#8 or JWK only. GitHub gives a PKCS#1 PEM (`-----BEGIN RSA PRIVATE KEY-----`). A PKCS#1 PEM is a bad setting (R-PU43). |
| R-PU42 | Hosts. The Worker sends the installation token only to a URL that starts with `https://api.github.com/` (the whole prefix, with the final `/`). Each GitHub read adds `user-agent`. A read of the REST API adds `accept` and `authorization: Bearer <token>`. The read of `.roc-version` (`raw.githubusercontent.com`) and the download of an asset (`github.com`) get the user agent only. Reasons: a public repository needs no token on the raw host, so the token gives nothing there and a leak of it would cost more than the read is worth. The 5,000 requests an hour of R-PU25 are for the REST API. A look-alike host (`api.github.com.example`, `api.github.com@example`) gets no token. |
| R-PU43 | Failures of the token. A setting that is missing or not valid (`GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`, `GITHUB_APP_KEY`, a key that is not PKCS#8 PEM) or a fault in the RS256 sign is a fault of the Worker: 500 `internal` with the fixed `detail` of R-AP48, and the inner text only in the log. A token request that fails (a status other than 201, no answer, or a body that is not a token) is a read from GitHub that failed: 502 `upstream`, with the `detail` `the GitHub installation token request failed with status <s>`, `the GitHub installation token request failed: no answer` or `the GitHub installation token answer is not valid` (the text is a proposal, CLI 3, R-OUT2). The hint path (R-CT12) gives the key 0 (Design Q178) for every kind and keeps nothing. A failed load keeps nothing. Reason: the operator fixes a setting with a deploy, and a client cannot. A token request that fails is a state of GitHub or of the installation, and a later request can pass. |
| R-PU44 | A dead token and no negative cache. A read that gets 401 with a held token is not special: it answers by its own rule (502 `upstream` with `status 401`), and the Worker keeps the token until 5 min before its end (at most 55 min). Reason: a held token dies before its end only when the installation is removed or suspended, and then no read can pass. A key change does not stop a token that GitHub already gave. A token request that fails is asked again by the next read. Reason: the 5,000 requests an hour are for the installation token, not for the JWT call, and the rate limits of R-PU34 and R-CT11 bound the rate of requests. Later, a slice can add a `clear` on 401 or a short negative cache if the edge shows a need. |

R-PU45: The index queue (R-PU11, R-PU13, R-PU35, Design Q323, Q329 to Q331; slice 118).

| Item | Rule |
| --- | --- |
| Queues | `talon-index` (binding `INDEX`) and its dead letter queue `talon-index-dlq` (binding `INDEX_DLQ`). The names are a proposal (CLI 3, R-OUT2) and R-WH14 lists them. The operator makes both with `wrangler queues create` before the first deploy. |
| Config | The consumer of `talon-index` has `max_retries = 4` and `dead_letter_queue = "talon-index-dlq"`. A second consumer reads `talon-index-dlq`. The code has no producer for `INDEX_DLQ` (Design Q329). |
| Attempts | 5: the first delivery and 4 retries. |
| Delays | After a failed attempt n, the consumer calls `retry` with a delay: 1 min after attempt 1, 5 min after 2, 15 min after 3, 60 min after 4 (first guess). Each delay counts from the failed attempt, not from the event, so a job runs at 0, 1, 6, 21 and 81 min after the event (Design Q323). Reason: the delay of `retry` is a delay from now. A time since the event needs the event time in the message, and it does not give a longer or a surer wait. Cloudflare allows a delay of up to 24 h. |
| Last attempt | After attempt 5 the consumer calls `retry` with no delay. The retries are used up, so the platform moves the message to the dead letter queue (Cloudflare docs: a message goes to the dead letter queue when it reaches the retry limit). |
| Dead letter consumer | One error log line for each message, with the event, the action and the ids, never a name (R-PU32). It acks the message. A dead letter queue with no consumer deletes a message after 4 days (Cloudflare docs). |
| No asset | A release with no package asset at the fifth read is not a fault (R-PU13). The consumer acks it and writes an info log line, so the dead letter queue holds faults only. The reconcile can still find it (R-PU21). |
| Refusals | A refusal of the shared index flow (`IngestRoutes.index!` and the identity check) with a 4xx problem is final: for example 403 `repository-changed` (R-TP9 row 4), 404 for the release by tag, 409 `label-conflict` (the conflict of R-PU14), 422 of the archive read. The consumer writes one warn log line with the ids and the problem `type`, never a name (R-PU32), and acks the message. A retry gives the same answer. A 5xx problem (for example 502 `upstream`) or a fault is a failed job, and the queue retries it (Design Q361). |
| Edge check | A local run cannot show the move to the dead letter queue: the broker does it. The first deploy checks it once (W3): a test Worker with a throwaway pair of queues, `max_retries = 1`, and a consumer that always calls `retry` with no delay. One message must reach the dead letter consumer after its second attempt. If it does not, a `retry` at the last attempt is not a failed delivery. Then the consumer at attempt 5 sends the message to `INDEX_DLQ` itself and acks it (the code gets a producer binding, and the tests get `queue_sent` checks for it). |

Public repositories only:

R-PU31: The registry indexes a release only when its repository is public (Design 1, N4). Each path gets the visibility from GitHub itself, before it writes anything. Reason: the App installation token of R-PU25 can read a private repository where the App is installed, so a read that succeeds does not prove that the repository is public.

| Path | Source of the visibility |
| --- | --- |
| Publish (R-AP8) | The claim `repository_visibility` of the token (R-TP3 row 6) |
| Webhook (R-PU11 to R-PU13) | `GET /repositories/{repository_id}` in the queue consumer, read again as in R-PU12. The event body is not used. |
| Ingest (R-PU4, R-AP9) | `GET /repos/{owner}/{repo}`, the same read that gives the ids of R-TP5 |
| Reconcile (R-PU21 to R-PU24) | `GET /repositories/{repository_id}` with `If-None-Match` and `repo_checks.repo_etag` (R-RE14), before the release list. The pass batch stores `repo_etag` only when the read is public and its `full_name` in lower case is the name of the row, else it stores NULL. A failed row does not change it. So a 304 answer means: public, the name of the row, the same ids. A row with no `repo_etag` sends no `If-None-Match`, and a `moved` row never has one (Design Q371). This is also the read of R-TP10. |
| Move (R-AP31) | The claim `repository_visibility` of the token (R-TP15), and the successor must be `active` (R-AP31, check "Index"), so it is public by R-PU33 |

R-PU32: A repository is public when the read gives `visibility` = `public`. The values `private` and `internal` (GitHub Enterprise) are not public. For a name with no `repos` row, a repository that is not public makes the path write nothing: no `repos`, `repo_checks`, `repo_events`, `provenance`, `releases` or `artifacts` row, no log leaf, and no queue job that holds the name. The Workers log line of the refusal (RN13) has the problem `type`, not the name or the URL. So the server never stores the name of a private repository that it did not have before. CLI 1, R-RG4 to R-RG6 is the same guard on the client.

| Path | Answer for a repository that is not public |
| --- | --- |
| Publish | 403 `forbidden`, and the `detail` names the claim `repository_visibility` (R-TP3). The caller owns the repository, so the answer can name the cause. |
| Ingest | 422 `not-a-candidate`, with the `detail` `repository not found or not public`. A release that users cannot download is not a candidate (R-PU6, N4). The answer is the same for a private and a missing repository, so an ingest with no token cannot test if a private repository exists. |
| Webhook, reconcile | No answer to a client. The Worker writes nothing for a new name, and applies R-PU33 for a known name. |

R-PU33: An indexed repository that becomes private gets the state `missing` (R-TP11), and each of its releases gets `withdrawn` = `repo-missing` (R-PU24). The `repos` row stays, so the name stays bound (R-TP9 row 4). Rows that the registry wrote while the repository was public stay, because they were public data and the log is append-only (Design 8, R-SE2). The Worker finds the change in two ways: the App event `repository` with the action `privatized` (R-PU11), and the visibility read of each reconcile (R-PU31). The action `publicized` sets `next_check_at` of the row to now, so the next reconcile clears `repo-missing` (R-PU24). While a repository is not public, the Worker ignores its `release` events. The action `privatized` is only a hint (Design Q325): the job reads `GET /repositories/{repository_id}` (R-PU31) and does not use the event body. A 404, `private` or `internal` withdraws, with the etag reset of R-PU24 (Design Q376). `public` is an old event (GitHub sends an event again, or the owner made the repository public again): nothing changes. A read that fails is a failed job, and the queue retries it (R-PU45). The action `publicized` needs no read: it sets `next_check_at` to now for each row of the repository id whose state is not `moved` (Design Q324, R-TP19).

R-PU34: Ingest limits (Q30). An ingest (R-AP9) needs no login. These limits apply:

| # | Limit |
| --- | --- |
| 1 | For each IP address (the IPv4 address, or the IPv6 /64 prefix): at most 60 ingests a minute (first guess), with the rate limiting binding (`cloudflare-workers/API.md` RN10). The key, the place in the order of the checks and the `Retry-After`: R-AP68 row 3 and the item "Rate key". `tln add` of a new repository sends one ingest for each candidate (CLI 2, R-AD35), so the limit must allow the releases of one repository. |
| 2 | For each owner: at most 20 new names a day from ingests (first guess). The Worker counts the `repos` rows of the owner whose `time` is after 00:00 UTC. Over the limit: 429 `rate-limited`, with `Retry-After` until 00:00 UTC. The owner is the owner text of the URL, the count is in D1 call 1, and the limit is soft: R-AP68 row 5 and the item "Owner count". |
| 3 | The archive size limit of R-PU38 |
| 4 | The rules that exist: `github.com` release asset URLs only (R-PU40), public repositories only (R-PU31, R-PU32), one release for each label (R-PU14), the candidate rules (R-PU6) |
| 5 | A publish (R-AP8) has no IP limit and no owner limit (Design Q296). It has the rules of row 4 and the archive size of row 3. |

Reasons for no login: ordinary commands send an ingest (CLI 2, R-AD35, 4.1 R-AP28), also in CI, where nobody can log in. The webhook, the reconcile and `tln publish` index most releases, so an ingest is only the first sight of a repository. A login moves the abuse to free GitHub accounts, and the attacker still needs repositories with releases. A later option: a JWT of 6.1, R-CT9 gives a larger limit in row 1.

Reasons for no limit on a publish (row 5, Design Q296). A publish needs a token that GitHub signed for this registry (R-TP3 rows 1 to 3), from a public repository (row 6) whose name and tag are those of the asset URL (rows 4, 7). So one token can publish one tag of its own repository, and a repeat of it is idempotent (R-PU14): it costs 2 D1 calls and no GitHub read, and the facts have a key, so their rows are bounded (R-RE13). The attacker needs a new tag and a new workflow run for each new release, at the cost of GitHub. An ingest (row 1) of the same repository needs no proof at all and has the IP limit, so a publish gives the attacker no reach that an ingest does not give. An IP limit would hurt the real caller: a CI job that publishes the packages of a monorepo in one run sends several publishes in a minute from a shared address, there is no person to wait, and `tln publish` sends a request again only 3 times (R-AP34). A publish writes names without the owner count of row 2, so an owner with many repositories can bind them faster than an ingest allows. The cost to the owner is a repository, a tag and a run for each name, and the operator can yank a release (R-YK2). A later option, if the edge shows abuse: `limit!` with the claim `repository_id` as the key, and not the IP address. The key is a proven identity, so it fits a CI job where an IP address does not.

R-PU40: Other hosts (Design Q155). In P2 no path indexes a URL whose host is not `github.com`. An ingest of such a URL gets 422 `not-a-candidate` with no D1 call and no GitHub call (R-PU34 row 4, R-AP68 row 2), and the publish, the webhook and the reconcile read only GitHub. A publish with such a URL gets the same 422 at its URL rules, before its token check (R-AP75 row 6, Design Q292). Reasons:

| Need of an ingest | On `github.com` | On another host |
| --- | --- | --- |
| The visibility before a write (R-PU31, R-PU32) | `GET /repos/{owner}/{repo}` | No API. The registry cannot tell a public URL from a private one that answers with a token in the URL or a cookie. |
| The release rules (R-PU6, CLI 7.3, R-DI3, R-DI4) | The release read: draft, prerelease, the package asset | No release, so any URL with a hash is a "release" |
| A reconcile and a withdraw (R-PU17, R-PU21) | The release list | None (R-PU27): a deleted asset stays a candidate |
| The ids of the name (R-TP5) | `repository_id`, `repository_owner_id` | None |
| Abuse (R-PU34) | One owner, a count of names | Any domain, at no cost to the attacker |

The client sends no ingest for such a URL (R-AP28 case 3), so the URL stays in the domain of its header value (CLI 7.3, R-DI11), with a registry too. The read shapes for another host stay: `repo`, `tag` and `roc_version` `null` and `published_at` the index time (R-AP49, R-RE2), `checked` `null` (R-AP53), and a yank by the operator only (R-YK2). A later path can index another host. It is a new path, for example an ingest with the operator key (R-YK2), so the ingest with no token keeps this rule (Design R-PH1). No phase has that path yet.

Cost, for 1,000 repositories with no App (first estimate):

| Item | Value | Limit or price |
| --- | --- | --- |
| GitHub visibility reads (R-PU31) | 24,000 a day, most of them 304 answers with `repo_etag` (Design Q371). A `moved` row and a list of more than one page cost 1 counted request for each read (Design Q372, Q375). | The same 5,000 counted requests per hour |
| GitHub list reads | 24,000 a day, most of them 304 answers | 5,000 counted requests per hour for the installation. The worst case, 1,000 answers of 200 per hour, is under it. |
| Cron runs | 288 a day, at most 500 reads each | Workers Paid: 30 s of CPU for a cron with an interval under 1 h, 10,000 subrequests per run (Cloudflare Workers limits) |
| Queue operations | Only for new candidates and retries (R-PU13) | Workers Paid includes 1,000,000 operations a month, then USD 0.40 per million (Cloudflare Queues pricing) |

### Scheduled jobs

R-PU35: Each scheduled job selects its work from the state of D1 or R2, not from the time of the last run. So when a run fails, or a planned time does not run, the work stays due, and a later run does it.

| Job | Cron | Due when | Unit | When one unit fails |
| --- | --- | --- | --- | --- |
| Reconcile (R-PU23) | 5 min | `next_check_at` is at or before now | One repository | R-PU37 |
| Index retries (R-PU13), a Queue (Q48, `cloudflare-workers/API.md` RN16) | none: the queue | The message comes back after its delay (1, 5, 15, 60 min, R-PU45) | One release | The queue retries the message. After the last attempt the message goes to the dead-letter queue, and its consumer writes a log line (R-PU45). |
| Tile catch-up (Q26, `cloudflare-workers/API.md` RN11), P3 (Design Q55) | 5 min | The largest leaf index in D1 is larger than the size of the checkpoint | The tiles and the checkpoint | The next run tries again |
| Hint cleanup (R-CT5), `hint_days` (R-RE6) | daily | A `compat_hints` row whose pair has a `bot` row. A `hint_days` row with a day below today minus 2 (strict, Design Q343). | One DELETE | Write a log line, go on with the next step, the run is `Ok` (Design Q344). The next run does it |
| Trim (R-CT15) | daily | A compiler older than 12 months that has `contributions` or `compat_hints` rows | One compiler, one batch | Write a log line, then go on with the next compiler. When the read of the due compilers fails: a log line, no trim in that run, the run is `Ok` (Design Q344) |

R-PU36: Each job is safe when 2 runs overlap, and when 1 planned time runs 2 times. Reasons: production did not run a failed cron again in 1 hour (section 8, edge results), but the Cloudflare docs give no delivery promise for a cron (`cloudflare-workers/API.md` AQ12), and workerd keeps a retry flag (`cloudflare-workers/MODULES.md` 3). A run can last 15 min, and the reconcile runs every 5 min. A publish, a webhook or an ingest can write the same rows during a run.

The clock of each job is `Time.now_ms!()`, read once at the start of the run, not the planned time `time_ms` of the `Scheduled` event (Design Q345). A job selects by the state of D1 and the time now, so a late run, or a run that comes again, does the work that is due.

| Job | How |
| --- | --- |
| Reconcile | The claim of R-PU37 row 1 |
| Index retries | A message that comes 2 times indexes the release 2 times, and the second time is a no-op (R-PU14) |
| Tile catch-up (P3) | R2 compare and swap on the etag, only to a larger size (Q26) |
| Hint cleanup, trim | Each statement or batch selects by state in one transaction. A second run finds no rows. |

R-PU37: Failures in the reconcile (R-PU23):

| # | Rule |
| --- | --- |
| 1 | Claim. One statement selects the due rows and sets their `next_check_at` to now plus 15 min (the wall time of a scheduled run), with `RETURNING`. D1 runs one write at a time, so 2 runs never get the same row. A row of a run that stops is due again after 15 min. `RETURNING` gives the rows in no promised order and with the new `next_check_at` only, so "oldest first" (R-PU23) is a rule of the selection. The run handles the claimed rows in the order of `repo` as a signed 64-bit integer (Design Q370). |
| 2 | One row at a time. An error of one row (a GitHub answer that is not valid, a D1 error in the batch of that row) does not stop the run. The run goes on with the next row, and the outcome of the run is `Done`. A trap (CPU, memory) stops the whole run. Row 1 then makes the rows that were not done due again. |
| 3 | Backoff. A failed row gets `fail_count` + 1 and `next_check_at` = now + min(interval, 5 min × 2^(`fail_count` − 1)). A row that passes gets `fail_count` = 0. So a row that always fails costs at most as much as a row that passes, and it does not stay at the start of the order. There is no dead-letter state: the cause can go away. |
| 4 | Log. Each failed row writes one log line (`cloudflare-workers/API.md` RN13) with the job, the repo id, `fail_count` and the error kind. The line does not have the name (R-PU32). The text is a proposal (CLI 3, R-OUT2). |
| 5 | Effects with the etag. The new `etag`, `checked_at`, `next_check_at` and `fail_count` of a row go in the same D1 batch as the `withdrawn` changes and the pending index rows of that row. When the index job is a queue, the Worker sends the messages first, then writes the batch. Reason: a stored etag makes the next read a 304, which changes nothing (R-PU23). So an effect that is not written with the etag is lost until the list changes. A message that is sent 2 times is not a fault (R-PU14). |

Tests (Miniflare handler tests, R-WH4, except the first):

| Rule | Test | Revert that must fail |
| --- | --- | --- |
| R-PU37 row 3 | `roc test` of the pure function `next_check(now, interval, fail_count)`: the cap at the interval, and 0 after a pass | Remove the cap |
| R-PU37 rows 2, 3 | Fake GitHub answers 500 for the oldest repo A and 200 for B and C. After one run: B and C are updated, A has `fail_count` 1 and is no longer first, and the outcome is `ok` | Stop the run at the first error: B and C are not updated |
| R-PU37 row 5 | A list with a new candidate, and the pending-row write (or the queue send) fails. The etag is not stored, the row stays due, and the next run indexes the candidate | Store the etag first: the candidate is never indexed |
| R-PU36, R-PU37 row 1 | Two `GET /cdn-cgi/local/scheduled` calls at once, and 2 calls with the same `time`. Fake GitHub counts 1 read for each repo, and the D1 state is the same as after 1 run | Select with no claim: 2 reads |
| R-PU35 trim | A `RAISE` for one compiler: the other compilers are still trimmed. 2 runs give the same `contributor_totals` | Stop at the first failure |
| R-PU35 index retries | Miniflare queue. A release with no asset: the message comes back after each delay, and the asset that comes later is indexed. A job that always fails goes to the dead-letter queue after the last attempt, with a log line. | No `delay_ms` on the retry: the message comes back at once |

### 7.1 Trusted publishing

R-TP1: P2 has no per-repository publisher config. A fixed rule (R-TP3) selects the tokens that can publish. A person who can push a tag of the repository can publish its release. Reasons: GitHub owns the names (R-RL2), and the registry has no accounts. A tag push already needs write access to the repository. A config needs a place to keep it and an owner check for its writer, and that check is the same GitHub write access.

R-TP2: `tln publish` gets the token from GitHub Actions: a `GET` of `$ACTIONS_ID_TOKEN_REQUEST_URL` with `&audience=<registry base URL>` (the text B of R-TP17), and the header `Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN`. With no such variables, it sends no request (R-AP27). P2 supports no other CI.

R-TP3: The Worker checks these claims of a publish token. Each failed check gives 401 `unauthenticated` (rows 1 to 3) or 403 `forbidden`, and the `detail` names the claim. The one exception is row 5: it gives 403 `repository-changed` (Design Q267).

| # | Claim | Check |
| --- | --- | --- |
| 1 | Signature, `iss` | RS256 with a key of the GitHub JWKS (`kid`), API.md RN6. `iss` is `https://token.actions.githubusercontent.com`. |
| 2 | `aud` | Equal to the base URL of the registry, with no trailing `/` (the Worker setting `AUDIENCE`, the text in R-TP17). Reason: a token for another service cannot publish here. |
| 3 | `exp`, `nbf` | The time is between `nbf` and `exp`, with 60 s of leeway |
| 4 | `repository` | Equal to `owner/repo` of the asset URL, ASCII case-insensitive. The host of the URL is `github.com`: a URL of another host is 422 at the URL rules before the token check (R-AP75 row 6, R-PU40, Design Q292), so this test is a guard that no request reaches. |
| 5 | `repository_id`, `repository_owner_id` | At least one of the two is equal to the `repos` row of that name, when it has one (R-TP5, R-TP9). Else 403 `repository-changed` with `issues_url` (R-TP9 row 4, R-TP12), not `forbidden` (Design Q267). Reason: this is the check of R-TP9 row 4, so each path gives one answer for it, and the publisher needs the `issues_url` of R-TP12. Both claims must be numbers: a claim that is missing or not a number is 403 `forbidden` and the `detail` names it, also when the other id is equal to the row (Design Q293). The form of the ids is checked with rows 4, 6, 7 and 8, before the D1 read. The compare with the row is after the read, and it comes before the 409 `label-conflict` of the same request (Design Q294). The order of the whole path: R-AP75. |
| 6 | `repository_visibility` | `public`. Reason: users fetch the asset with no token (CLI 7.1). |
| 7 | `ref_type`, `ref` | `ref_type` is `tag`, and `ref` is `refs/tags/<tag>` with the tag of the asset URL |
| 8 | `event_name` | `release`, `push` or `workflow_dispatch` |

R-TP16: The JWKS of GitHub and the token form. The Worker keeps the JWKS in `Memo`, with its fetch time from `Time.now_ms!` (R-WH4). It reads the JWKS again when the copy is older than 1 h, and for a token with an unknown `kid` only when the copy is older than 60 s (first guesses). Else an unknown `kid` gets 401 at once. So a made-up `kid` costs at most one read of GitHub a minute for each isolate. A failed read gives 502 `upstream`. The scheme `Bearer` of the `Authorization` header is case-insensitive (RFC 9110, 11.1). The time claims allow 60 s of clock skew (row 2). The Worker refuses a token of more than 8192 bytes with 401 `unauthenticated`, before any other check (Design Q137). It reads `aud` only as one text (R-TP3 row 2): a list gets 401 `unauthenticated` (Design Q138).

R-TP17: The text of `AUDIENCE` (Design Q193, Q207). The registry base URL has one text B, the base URL form of CLI 1, R-RG7 row 3: the RFC 6454 origin, with the scheme and the host in lower case, the port only when it is not the default, no path and no trailing `/` (`https://registry.example.org`). B is in 4 places: the setting `AUDIENCE` (R-WH14), the `audience` of the token request of `tln` (R-TP2), the `aud` claim of the OIDC token (R-TP3 row 2), and the `iss` and `aud` of the JWT (R-CT9). The Worker compares the text byte for byte and does not change it.

| Item | Rule |
| --- | --- |
| `AUDIENCE` | B of the registry, written by the operator in the form of R-RG7 row 3. For the default registry (CLI 1, R-RG2), B is the default URL in this form (R-RG8). |
| `tln` | Makes B from the setting by R-RG7 and uses B as the `audience` (R-RG7 row 4). It percent-encodes B in the query of the token request. The `aud` claim has the text before the encoding. A request URL is B and the route path (R-RG7 row 5). A path in the setting is not valid (R-RG7 row 2), so B never has a path. |
| Check | The test of `tln` (slice 221) checks that the `audience` is B for `https://r.example`, `https://r.example/` and `HTTPS://R.Example:443/`. The deploy step of the operator checks that `AUDIENCE` is B of the default URL. |
| Failure | A token with another `aud` gets 401 `unauthenticated`, and the `detail` names the claim `aud` (R-TP3). |
| A change of the default URL | It changes B. A `tln` that sends the old B cannot publish until the user updates it or sets the registry (R-RG1). `AUDIENCE` is one text, not a list (Design Q138). |

R-TP4: Why rows 7 and 8 stop the known attacks:

| Event | Result | Why |
| --- | --- | --- |
| `pull_request` from a fork | No token | GitHub gives a fork pull request read-only permissions, so no `id-token: write` |
| `pull_request_target`, `workflow_run`, `issue_comment`, `schedule` | 403 | The ref is a branch of the base repository (row 7). Row 8 also refuses the event. |
| `push` of the tag, `release`, `workflow_dispatch` on the tag | Accepted | The workflow file comes from the commit of the tag, so the code that publishes is the code of the release |

R-TP5: The `repos` table binds a name to GitHub ids. Key: `name` (`owner/repo`, lower case). Fields: `repository_id`, `repository_owner_id`, the state and the successor of section 7.3, time. The first write of a release of that name adds the row. A publish takes the ids from the claims. The webhook and an ingest read them with `GET /repos/{owner}/{repo}` of the GitHub API. Each later write of that name follows R-TP9. Reason: when a repository is deleted, or its owner is renamed, another person can create a repository with the old name (repo-jacking). PyPI checks the owner id for the same reason. The registry trusts the owner of the recorded repository (R-TP9), and refuses only another account. Section 7.3 gives the states of a row, renames and moves.

R-TP6: The `oidc` provenance row (R-PU15) records these claims: `workflow_ref`, `workflow_sha`, `job_workflow_ref`, `event_name`, `run_id`, `run_attempt`, `actor_id`, `runner_environment`. The Worker does not check them. `tln add` shows the workflow and the commit (Design 8, R-SE3). The recorded text is one for each request, and it is also the `claims` of each `repo_events` row that the token caused (R-TP13, Design Q298). A claim that the token does not have is recorded as `null`, so the text always has the 8 members (R-AP51).

R-TP7: A compat bot token (R-MX1, R-AP6, R-AP10) passes rows 1 to 3 of R-TP3, and its `repository_id` and `workflow_ref` are equal to the Worker settings `BOT_REPOSITORY_ID` and `BOT_WORKFLOW_REF` (the bot workflow on the default branch). `event_name` is `schedule` or `workflow_dispatch`. Any other valid token on these routes gets 403 (R-MX5).

R-TP8: A yank token (R-YK2) passes rows 1 to 6 of R-TP3, for the repository of the release. Rows 7 and 8 do not apply. `event_name` is `workflow_dispatch`. Reason: a yank is a manual act. A person needs write access to start a `workflow_dispatch` run.

### 7.2 Yank (P3)

A yank stops new resolutions from choosing a release. It deletes nothing (Design 3, Cargo).

| # | Rule |
| --- | --- |
| R-YK1 | Routes: `PUT /v1/releases/{log_index}/yank` with the body `{reason}`, and `DELETE /v1/releases/{log_index}/yank`. The log index names one release on any host, and it never changes (R-RE2). Both routes are idempotent: a `PUT` on a yanked release and a `DELETE` on a release that is not yanked change nothing. The answer is the release record (200). Errors: 400 `bad-request`, 401 `unauthenticated`, 403 `forbidden`, 404 `not-found` (no release has that log index, for example a compiler leaf). Caching: `no-store`. |
| R-YK2 | Auth: a GitHub OIDC token of the repository of the release (R-TP8), or the operator key (the Worker secret `OPERATOR_KEY`, as `Authorization: Bearer`). A release on a host other than `github.com` has no GitHub identity, so only the operator can yank it. An author cannot remove a yank of the operator. |
| R-YK3 | `tln yank <tag> [--reason <text>]` and `tln yank <tag> --undo` (CLI 1, R-CM21) run in a `workflow_dispatch` job. The repository is `$GITHUB_REPOSITORY`. Talon finds the release of that tag with R-AP1, then sends R-YK1 with the token of R-TP2. A tag names one release, so one label (CLI 7.3, R-DI4, R-DI5). Outside GitHub Actions, Talon stops, as `tln publish` does (R-AP27). |
| R-YK4 | A yank sets `releases.yanked`, and adds a row to the `yanks` table: (release, seq), with the log index of the release (R-IK6, R-RE10, Design Q60), with the action (`yank` or `unyank`), `by` (`author` or `operator`), the claims of R-TP6 for `author`, the reason, and the time. Rows are only added. A yank adds no log leaf: the log proves which hash a label has (Design 8, R-SE2), and a yank does not change that. |
| R-YK5 | The current yank state applies to each resolve, also with `--snapshot log:N` (Resolution 2, R-C6). So a yank can change the result of a resolve at a snapshot. That is the purpose of a yank. A yank never hides the value that a header has now (Resolution 2, R-C9). `tln audit` reports it with its reason. |
| R-YK6 | `reason` is at most 500 bytes of UTF-8 with no control characters. Else the answer is 400. A yank with no reason is valid. |
| R-YK7 | A yank changes the answers of R-AP1, R-AP2, R-AP13, R-AP14 and R-AP17. It drops the same cache entries as a publish of the release (R-AP43, R-AP69). Other colos see the yank after at most the `max-age` of these routes (60 s), plus the age of the local copy of the client (R-AP24). |

### 7.3 Repository identity and moves

The `repos` row of a name (R-TP5) records which GitHub repository owns the name. A rename, a transfer, a deleted repository and a move to another repository change that row. The rules trust the owner of the recorded repository, and refuse only another account. Roc names a package by its URL (Design 2), so no rule here changes a URL, a label or a log leaf.

R-TP9: A write of a release, or a read of the repository, compares its GitHub ids with the `repos` row of the name (P2):

| Ids against the row | Case | Result |
| --- | --- | --- |
| The same `repository_id` and `repository_owner_id` | The same repository | Accept |
| The same `repository_id`, another `repository_owner_id` | A transfer to another account. Only an admin of the repository can transfer it. | Accept. The row gets the new owner id. Event `transfer`. |
| The same `repository_owner_id`, another `repository_id` | The owner made the repository again, for example after a delete | Accept. The row gets the new repository id and the state `active`, and its successor is cleared. Event `recreate`. |
| Both ids are different | Another account has the name | 403 `repository-changed` (R-TP12). The webhook and the reconcile write nothing for that name (Design Q361). |

R-TP10: A rename keeps the `repository_id` (GitHub docs, "Renaming a repository"). GitHub answers a read of the old name with a 301 to `/repositories/{id}`. The Worker `fetch` follows redirects (`cloudflare-workers/MODULES.md` section 4), so the Worker never sees the 301: it gets the 200 answer of the new location. A rename is a 200 answer whose `id` is the recorded `repository_id` and whose `full_name` is another name. When the Worker has only the id (the reconcile of R-PU31, R-TP11), it reads `GET /repositories/{repository_id}`, and the `full_name` of the answer gives the current name. When a write or a read finds a name with no `repos` row, and a row of another name has the same `repository_id`, the Worker adds the row of the new name with the same ids, and sets the old row to the state `moved` with the new name as `successor`. Events `rename` on both names. An owner account rename is a rename of each of its repositories. P2. R-TP18 gives what an ingest writes when the URL has an old name, and when a repository gets an old name again.

R-TP11: The states of a `repos` row:

| State | Set when | Effect |
| --- | --- | --- |
| `active` | The first release (R-TP5). A read of the repository succeeds again. | Normal |
| `missing` | GitHub answers 404 for `GET /repositories/{repository_id}` (the repository is deleted, or it is private), or the read shows that it is not public (R-PU33). Private packages are not supported (Design 1, N4). R-PU24 sets each release to `withdrawn` = `repo-missing`. | No release of the name is a candidate (Resolution 2, R-C6). A header value stays in its domain (Resolution 2, R-C9). The name stays in the short-name set (R-SN2). The binding stays, so another account cannot take the name (R-TP9 row 4). |
| `moved` | A rename (R-TP10) or a move (R-AP31) | The releases of the old name keep their own state. New releases come under the successor. `tln` shows the successor (R-PU28, R-PU29). |

A `missing` row gets `active` again (event `found`) when a read of the same `repository_id` succeeds, or by R-TP9 row 3 when the owner makes the repository again. R-PU24 then clears `repo-missing` for each release whose asset is there again.

R-TP12: An answer 403 `repository-changed` has the problem member `issues_url`: the Worker setting `ISSUES_URL`. For the Talon registry, its value is `https://github.com/roc-talon/talon/issues`, the issues page of the Talon repository, and ownership issues are handled there. Another registry sets its own value, because its operator is the person who can help. The URL is in this one setting only, and not in the Talon binary. `tln` prints it: `roc-lang/json is bound to another GitHub account (repository id 812345). Only the registry operator can change this. Open an issue: <issues_url>`. The text is a proposal (CLI 3, R-OUT2). The exit code is 20 `rejected` (CLI 3, R-E6). The operator can bind the name to the new account by hand, after a check. This adds the event `operator`.

R-TP13: The `repo_events` table (R-RE15) records each change of a `repos` row: the action, the ids before and after, the successor, the claims of R-TP6 when a token caused it, and the time. Rows are only added. With the log, it shows each change of owner of a name after the fact. The `claims` of an event is the same text as the `claims` of the `oidc` provenance row of the same request (R-TP6, Design Q298).

R-TP18: What an ingest writes for the name of its URL (Design Q260, Q261, Q262). `U` is the lower-case `owner/repo` of the URL. `F` is the `full_name` of the answer of `GET /repos/{owner}/{repo}`, in lower case. `F` is not `U` when GitHub followed the 301 of an old name (R-TP10). The release is always under `U`: `releases.repo` is the id of `U` (R-RE2), also when `F` is another name. R-TP9 compares the ids with the row of `U`. Then these rows are written. A write never marks a row `moved` with an old name as its successor.

| # | Case | Rows written |
| --- | --- | --- |
| 1 | `F` is `U`. `U` has no row. A row of another name has the same `repository_id`. | R-TP10: the row of `U` (`active`, event `rename`, no `bind`). Each row with that `repository_id` whose state is not `moved` gets the state `moved`, the successor `U` and `state_at` = now, and the event `rename`. A row that is `moved` stays. |
| 2 | `F` is `U`. `U` has no row. No row has the `repository_id`. | R-TP5: the row of `U`, the event `bind`, the `repo_checks` row. |
| 3 | `F` is `U`. The row of `U` is `moved` and has the same `repository_id` (the repository has its old name again). | The row of `U` gets the state `active`, no successor and `state_at` = now, and the event `rename` (ids before and after equal, no successor). Each other row with that `repository_id` whose state is not `moved` gets `moved` with the successor `U`, and the event `rename`. A row that is `moved` stays, so a chain `A` to `B` to `C` becomes `B` to `C` to `A`. |
| 4 | `F` is `U`. Any other row of `U`. | R-TP9 only. |
| 5 | `F` is not `U`. `U` has a row (also `moved`). | R-TP9 only. No row changes. |
| 6 | `F` is not `U`. `U` has no row. | R-TP5: the row of `U` (event `bind`, `repo_checks` row). No other row changes. |

Reasons: in rows 5 and 6 `U` is an old name, and the row of the current name `F` is not known to the ingest (R-AP41 allows no D1 call between the GitHub read and the write batch). A mark `moved` with the successor `U` would reverse the rename. Row 6 can leave 2 `active` rows for one `repository_id`. The path that reads by id (the reconcile, slice 119, and the webhook, slice 118) sets the old row `moved` (R-TP10), and the ingest of `F` with no row does it by row 1. The reconcile writes the rows of rows 1, 3 and 4 with `U` = `F`, where `F` is the `full_name` of its read by id, in the batch of the claimed row. A row of `F` with another `repository_id` gets no write from it, and the claimed row does not become `moved`. The claimed row still gets R-TP9 row 2 when the read has another owner id: R-TP9 compares the read with the claimed row, and the row of `F` does not change that (Design Q381). Row 1 also adds the `repo_checks` row of `F` (R-PU26, with `app_installed` of the claimed row), because an ingest of `F` then finds a `repos` row and adds none (Design Q380). When the read also has another owner id (a rename and a transfer in one read), R-TP9 row 2 applies to the claimed row first (the new owner id, the event `transfer`), then the row becomes `moved` (the event `rename`). A new row of `F` gets the ids of the read and the event `rename` only. A row of `F` that exists gets R-TP9 with its own ids (Design Q381). Row 3 is needed because the reconcile of an old name does not see a repository that has this name again: the name is the current name now. A `full_name` that is missing or not a text is 502 `upstream`.

R-TP19: States and events of an ingest (Design Q264, Q265, Q266).

| Item | Rule |
| --- | --- |
| Found | An ingest that reads a public repository with the same `repository_id` as a `missing` row sets the row `active` (event `found`). It does not change `releases.withdrawn`. It sets `repo_checks.next_check_at` of the name to the smaller of its value and now, so the next reconcile (R-PU23) clears `repo-missing` after the asset check (R-PU20, R-PU24). This is the `publicized` of R-PU33, for an ingest. |
| Webhook jobs (Design Q324) | `privatized`: as the next row. `publicized`: `next_check_at` of each row of the repository id whose state is not `moved` (R-PU33). `installation` and `installation_repositories`: `app_installed` of every row of the repository id, also a `moved` row (R-PU26). |
| `missing` for a `moved` row | No change and no event. A `moved` row keeps its successor (R-TP14). The state `missing` is for the row of the current name: the row with that `repository_id` that is not `moved`. R-PU24 withdraws the releases of each name of the repository (slice 119). |
| `seq` | The first event of a name has `seq` 1 (`bind`, or `rename` for a name that is made by a rename). Each next event has the largest `seq` of the name plus 1. |
| Order | The events of one row follow the order of the rules: R-TP9 first (`transfer` or `recreate`), then R-TP11 (`found`) or R-TP10 (`rename`, Design Q381). Events of different names have no common order. |
| No change | The same ids and the same state add no event. An event statement runs only when the statement before it changed a row, so a request that lost a race adds no event. |
| `claims` | `NULL` for an ingest (R-TP6 is for a token). |

R-TP14: A successor is a link from an old name to another `github.com` name: "new releases of this package are there". It changes no URL in a header and no release of the old name. A rename gives it automatically (R-TP10). An owner sets it with R-AP31. The client follows a chain of successors up to 4 links. A cycle stops the chain, and the client prints a note. The Worker walks a chain in the same way for a short name (R-SN8).

R-AP31: The move route (P3). The client command is `tln move` (CLI 1, R-CM22, R-MV1 to R-MV5). `PUT /v1/packages/{owner}/{repo}/successor` with the body `{name}` sets the successor of the old name `{owner}/{repo}`. `DELETE` on the same path removes it. Both are idempotent: a `PUT` with the current successor and a `DELETE` with no successor change nothing (200). A `PUT` that sets a new successor answers 201, and one that changes it answers 200. The answer is the `repos` item of R-AP32. Errors: 400, 401, 403 `forbidden` (R-TP15), 404 (the old name has no `repos` row), 422 `successor-mismatch`. Caching: `no-store`. The Worker checks the successor:

| Check | Fails when |
| --- | --- |
| Index | The successor is not a `github.com` name with a `repos` row in the state `active` and at least one release that is a candidate |
| Kind | The newest candidate of the successor is not the same kind (`app`, `package` or `platform`, R-RE1) as the newest release of the old name |
| `exposes` | The `exposes` list (R-RE1) of the newest candidate of the successor does not have each module of the newest release of the old name |
| Chain | The successor chain from the successor comes back to the old name (R-TP14) |

R-TP15: Auth of R-AP31: a GitHub OIDC token with rows 1 to 3 and 6 of R-TP3, and `event_name` = `workflow_dispatch`, as for a yank (R-TP8), because a move is a manual act. Or the operator key (R-YK2).

| Token of | Condition | Result |
| --- | --- | --- |
| The successor repository | Its `repository_owner_id` is the owner id of the old row | The move is done |
| The old repository (state `active`) | | An offer: the row gets `offer` = the successor name, event `offer`, answer 202. Nothing else changes. |
| The successor repository | The old row has an offer that names it | The move is done, and the offer is cleared |
| Any other repository | | 403 `forbidden` |

The offer is for an owner who moves to another account with a new repository, not with a transfer. When the old repository is deleted and the owner account is also different, only the operator can set the successor (R-TP12). `DELETE` takes a token of the old repository, a token of the successor, or the operator key.

Why the check uses module names and not symbols. A Roc package header lists its modules (`package [Json, Decode] {...}`), and a type module exposes one type with the name of the module (`roc-syntax` reference). The Worker does not run the compiler (section 1, R-RL3), so it cannot compare types and functions. A missing module is a sure sign of another package. A missing function that an app uses is found by the client: `tln update` runs the whole-app check before it writes the header (R-PU28, Resolution 5, step 6). A `roc bump` check (Q31) can give a stronger check later.

| # | Rule |
| --- | --- |
| R-PU28 | `tln outdated` shows `moved to <successor>` in the row of each header entry whose name has a successor (R-AP32). `tln update` and `tln upgrade` with no names do not follow a successor: they print one note for each such entry, `json: moved to acme/roc-json. Run: tln update json`. `tln update <alias>` and `tln upgrade <alias>` follow it: Talon replaces the entry under the same alias with a release of the successor, as for a new series (Resolution 10, R-UP3), and runs the full resolve with its checks (Resolution 5). `min-release-age` (Resolution 2, R-C7) applies to the successor release. The text is a proposal (CLI 3, R-OUT2). |
| R-PU29 | `tln add <owner>/<repo>` of a name with a successor does not follow it. When the old name has a candidate, Talon adds it and prints the note of R-PU28. When it has none (state `missing`, or each release withdrawn), Talon stops with exit code 2, and the message names the successor. A short name gives the successor already (R-AP33). |
| R-PU30 | When the `repos` row of a header entry had a `transfer` or `recreate` event (R-TP13) after the release of the header value, `tln update` and `tln outdated` print one note: `json: the repository was made again by the same owner on <date>`, or `transferred to <owner> on <date>`. Reason: a person can see an owner change before an update takes a new release (Design 8, R-SE14). |

## 8. Worker host: JSPI

JSPI (JavaScript Promise Integration) lets a synchronous wasm import wait for a JS promise. So Roc code calls `fetch!` as a normal effect, and the Roc compiler needs no async support. The host is in Zig.

State of 2026-11-01: the platform is built (`cloudflare-workers/PLAN.md`, order of work rows 1 to 11) and released (0.0.1, and 0.0.2 on 2026-11-01). This section describes it as built. The first plan had a pool of instances (16 requests each, retire at 32 MB). `cloudflare-workers/PLAN.md` problem 12 replaced it with one instance for each isolate. The facts of the platform are in Design 6.1. The app API is `cloudflare-workers/API.md`, and the signatures are in `cloudflare-workers/MODULES.md`.

Evidence:

| Evidence | Result |
| --- | --- |
| Local test (`scratchpad/jspi/`, workerd `2026-10-12`, no compatibility flag) | An import wrapped in `WebAssembly.Suspending` waits on a timer and a subrequest. 3 parallel calls through `WebAssembly.promising` return correct values. |
| Edge run (2026-10-17, Free plan, colo `TBS`, `cloudflare-workers/PLAN.md` "Status of the edge run") | The conformance checks of the platform run on the Cloudflare network. Run 1: 213 pass, 69 fail. Each fail is a check that cannot run on the edge, run data, or a real difference with its own row (E1 to E53). No row stops JSPI. |
| Community | workers-zig and Almide report JSPI on the Cloudflare edge (see Sources). |

Patterns of the Worker host:

| # | Pattern | Talon Worker |
| --- | --- | --- |
| R-WH1 | App API | `cloudflare-workers/API.md`. One entry `event! : Event => Outcome` for all Workers handler kinds. The app gives its handlers to `Worker.new` (`worker = Worker.new({ fetch!, scheduled!, ... })`, `event! = \|e\| worker.event!(e)`, `cloudflare-workers/MODULES.md` 2, 3). Typed modules (`Http`, `D1`, `R2`, `Kv`, `Cache`, `Queue`, `Object`, `WebCrypto`, `Memo`, ..., signatures in `cloudflare-workers/MODULES.md`) build programs of JS ops, and one JSPI wait runs one program (`Js.await!`). Sync JS APIs use `Js.call!` with no wait. Zig code with no Workers API (zstd, BLAKE3) uses `Native`. `Js`, `Io`, `Native` and `Cbor` are the low-level modules, for an API with no typed module yet (`cloudflare-workers/MODULES.md` 1). The app takes the platform by release URL, and the platform brings the `http` and `cbor` packages (`cloudflare-workers/README.md` "What a release has"). API.md 1 is the audit of what the registry needs (RN1 to RN19). |
| R-WH2 | Arguments | JS reads them before its first `await`, because they can be on the stack. |
| R-WH3 | Results and bodies | JS writes the result bytes of a program with `js_alloc` into a heap block, not the stack. The host decodes them into values that the task owns (`cloudflare-workers/API.md` 9, RS4). A body stays in JS as `Stream(Ref)` (a request body, a fetch response body, an R2 body). Bytes go into wasm only when Roc asks, with a limit (`Body.bytes_with!`, `Body.chunk!`). A stream given to a `Response` or an R2 put goes back to JS with no copy (RS3, `cloudflare-workers/PLAN.md` 10). So the ingest reads `main.roc` from a large archive and wasm memory does not grow by the archive size. |
| R-WH4 | Tests | Pure logic: `roc test`. Handlers: in Miniflare with local D1 and R2 and a fake GitHub service (API.md 11). Not a scripted record in `roc test`: an `expect` cannot run an effect (`research/core-shape/`). The clock (Design Q64): the Worker reads the time only with `Time.now_ms!` (`Date.now()`), and a pure decision gets the time as an argument. The test entry of the Worker sets `Date.now` to the time of the case before the shim loads, so a test fixes each time (`next_check_at`, `exp`, the hint day, `stale`, `TESTING.md` TW2). The shim option `now` is not this clock: it is the clock of the task deadlines and the memory budget only. The test layers are in `TESTING.md` 9. |
| R-WH5 | Shadow stack | JSPI keeps the wasm stack, not the shadow stack (`__stack_pointer`) in linear memory. The host copies the used stack to the heap at a wait and back at resume, so many tasks share one instance (`cloudflare-workers/host/host.zig:213`, `:246`). Only one task is in wasm at a time: a new run and a resume wait until the task that owns the stack leaves wasm (at its wait, or after the catch of its trap), so a trap never leaves its stack state to another task (`cloudflare-workers/js/wait.js:33`, `:46`). One instance for each isolate takes all tasks (R-WH6). After a trap, the host frees the heap of the dead task (owner tags, see below). |

The host in one picture:

```
isolate (Cloudflare limit: 128 MB for JS and wasm together)
├─ JS shim (makeHandler): task table, deadlines, memory budget, global check
└─ ONE wasm instance (Zig host + Roc app)
   ├─ task 1: runs. Stack at the bottom of linear memory. Heap in its own 4 KB pages.
   ├─ task 2: waits (JSPI). Stack copied to its pages. Sum of its pages saved.
   └─ up to 254 tasks. Request 255: 503, the instance stays.
```

### Measurement: stack copy vs instance per request (Q12)

Code, reproduce commands and all tables: `cloudflare-workers/bench/README.md`. Setup: Roc wasm32 app on the Zig host in `cloudflare-workers/host/`, nightly 2026-10-09, local workerd 2026-10-12. Each request builds about 45 KB of JSON, recurses N levels, and waits twice on a service binding (5 ms). 0 wrong bodies in about 445,000 requests.

| Item | B: shared instance, stack copy | A: instance per request |
| --- | --- | --- |
| Copy cost per wait | 0.05 µs (2 KB), 0.2 µs (16 KB), 1.4 to 1.8 µs (64 KB), 5 to 7 µs (256 KB) | none |
| Instantiate per request | none | 28 to 36 µs (49 KB module), 516 to 639 µs (2.1 MB module) |
| CPU per request, full workload | 205 to 283 µs | 306 to 502 µs |
| req/s at concurrency 64, stack 63 KB | 1660 | 1278 |
| p50 at concurrency 64, stack 63 KB | 36.4 ms | 45.6 ms |
| Memory held by copies | concurrency × stack depth (4 MB at 64 × 63 KB) | 1.3 MB per live instance |
| wasm memory | Grows to the peak and never shrinks (50 MB at 64 × 250 KB) | Freed with the instance |
| Trap | Without owner tags: leaks the heap of that request, 61 KB per trap. With owner tags: 0 leak. Other waiting requests stay correct. | Nothing leaks |

The stack copy costs less than the noise up to 64 KB. Instantiation is the real cost, and it grows with module size: the registry app will be larger than 49 KB.

Later measure with the final host (v7 allocator, check at each resume, 64 requests at once, full app, `cloudflare-workers/PLAN.md` problem 1, "Cost of variant A", and problem 12, "Costs"). Memory is the wasm memory of all 64 requests:

| Items | A: instance per request | B: one instance, check at each resume (as built) |
| --- | --- | --- |
| 200 | 377 µs for each request, 152 MB | 221 µs (-41 %), 7.8 MB |
| 2,000 | 2,468 µs, 232 MB (over the limit of 128 MB) | 2,110 µs (-15 %), 52.9 MB |

Decision (Q12): B, with one instance for each isolate. On the edge A costs about 6 ms of CPU for each request, and most requests fail at concurrency 16 and 64 (Q13).

### Owner tags: free the heap of a task that trapped

A trap stops the task at once, so its refcount decrements never run. The stack is not the problem: a task traps only while it runs, so it has no saved copy, and `task_abort` moves the stack pointer back. The heap blocks of the task stay. Owner tags find them. The v7 allocator keeps the heap of each task in its own pages, so one list gives all of them:

| # | Step | Code (`cloudflare-workers/`) |
| --- | --- | --- |
| R-OT1 | Each 4 KB page, and each run of pages of a large block, belongs to one task. The tables of the allocator (about 26 bytes for each unit, outside the units) hold the owner. No block has a header word. | `hostlib/alloc.zig:38` (`U_SLOT`) |
| R-OT2 | The host sets `OWNER` at `handle` (the task id comes from JS), clears it at a wait, sets it again at the resume | `host/host.zig:489` (`handle`), `:213` (`waitBegin`), `:246` (`waitEnd`) |
| R-OT3 | Blocks that JS fills (`js_alloc`) belong to the JS slot until the task adopts them. JS can call `js_alloc` after a trap, before the abort. | `hostlib/alloc.zig:929` (`js_alloc`), `:763` (`adopt`) |
| R-OT4 | At the end of a task, and after a trap, `freeOwner` frees all pages and runs of the task. It takes time in proportion to the pages of the task, and does not walk the whole heap. | `hostlib/alloc.zig:812` (`taskEnd`), `:853` (`freeOwner`), `host/host.zig:565` (`task_abort`) |
| R-OT5 | `task_abort` sets the stack pointer to the top of the task before it calls anything, because after an overflow the stack pointer is wrapped. | `host/host.zig:565`, `:583` (`abortFree`) |

Test: `cloudflare-workers/bench/node-test.mjs` and the leak test (10,000 requests with a trap rate of 0.01): 0 bad bodies and live bytes 0 after the traps. A free of a block of another task is counted and not done (`dealloc_miss`), so a late double free cannot free a live block of another task.

Cost: no header word. The cost of freeing is in the cost of the checks (see "Checks at resume").

R-OT6: Tasks must share no heap. Roc values are immutable and top-level constants are static data. When `freeOwner` cannot walk a list (a damaged table), `task_abort` gives -1. That is an alarm (R-WH8): the global check runs, and the instance is replaced when it fails.

R-WH6: The host runs one wasm instance for each isolate, with owner tags and checks at resume. This keeps the speed of B and the clean memory of A. There is no pool and no draining instance.

| # | Rule | As built |
| --- | --- | --- |
| R-WH7 | Tasks at one time | Up to 254, one slot for each task (`cloudflare-workers/hostlib/alloc.zig:342`). A request that finds no free slot gets a 503 (shed) and the instance stays. Slot 0 is the host and slot 255 is JS. |
| R-WH8 | After a trap | A clean trap (Roc `crash`, stack overflow, out of memory, CPU signal, cancel): free the pages of the task, keep the instance, the request gets a 503. Any other trap (an engine fault, a trap in host code, a failed sum) is an alarm: the task gets a 503, its pages and slot are freed, and the global check runs before the next task enters. The instance stays when the check passes. When it fails, all tasks get a 503 and a new instance starts (`cloudflare-workers/PLAN.md` problem 4, M1). |
| R-WH9 | Memory | No retire at a size. The budget for wasm is `isolateBytes` less `jsReserveBytes` (defaults: 128 MB less 48 MB, so 80 MB). Each grow asks JS first (`js_grow`). A refused grow is a clean out-of-memory trap for that task. While memory is under pressure, new requests get a 503 for `graceMs` (1 s). A dropped instance counts in the budget until the runtime collects it. The allocator also has a cap of 128 MiB (`hostlib/alloc.zig:24`). A developer cap is the option `maxInstanceBytes`. See `cloudflare-workers/js/budget.js:10`. |
| R-WH10 | Stack | The stack of a task is at most 1 MB (`initial_stack_size` in the platform header, `cloudflare-workers/platform/main.roc:20`), and the layout is stack first, so an overflow does not write over data. A module that is not stack-first throws at the first event. There is no fallback (`cloudflare-workers/PLAN.md` problem 1). A task that goes past it gets a clean trap (canary or out-of-bounds) and a 503. The copy at a wait is the used part only. The first plan had a log line for a copy over 256 KB. It is not built. |

### Checks at resume

```
task T waits:    copy stack ─> sum(T pages + Wait fields) ─> saved sum
other code runs in the instance (one of it may write a wrong address)
task T resumes:  other code ran since T waited?
                   no  ─> resume
                   yes ─> sum again ─ same ─> resume
                                     └ different ─> ALARM
unclean trap of a task ────────────────────────> ALARM

ALARM: the task gets a 503, its pages are freed (freeOwner)
       global check (check_heap) before the next task enters
       also: when the instance is idle, and every heapCheckEvery requests
       pass ─> the instance stays        fail ─> all tasks get a 503, new instance (M1)
```

The global check reads the allocator tables, the constant data and the host globals (`cloudflare-workers/host/host.zig:698`). The sum is Fletcher with SIMD.

| Item | Value | Source |
| --- | --- | --- |
| `resumeCheck` default | `"always"`: check at each resume after other code ran. `"afterAlarm"` is the cheaper option. The production host refuses `"off"`. | `cloudflare-workers/PLAN.md` problem 4, "Shim options" |
| `heapCheckEvery` default | 100 requests (the cost stays under 0.1 % of the CPU). It is set from the median request time of the app. | `cloudflare-workers/js/host.js:85` |
| Cost of `"always"` against no sums, full app, 64 at once | +3.3 % at 200 items, +4.9 % at 2,000 items (8 and 114 µs for each request) | `cloudflare-workers/PLAN.md` "Status of step 12f" |
| Time of the global check | 0.02 ms (5.8 MB of heap), 0.04 ms (47.9 MB). Cost with N = 100: 0.07 % and 0.02 %. | `cloudflare-workers/PLAN.md` "Status of step 12f" |
| Wild writes (20,000 requests, 0.5 % write 16 to 4,096 random words, then trap) | With sums: 0 wrong bodies with status 200. With no sums: 4 to 620. | `cloudflare-workers/PLAN.md` problem 12, "Costs" |

Not found by the checks: a wild write into the memory of the task that writes it, and a change in a block that JS writes during a wait (the owner word and the length of the response block are checked).

### Cancel, CPU limit and memory limit

| Case | What the platform does | Source |
| --- | --- | --- |
| A wait that never settles | The shim cancels the task at its deadline. One wait of a `Fetch` task before the response: 120 s. A `Scheduled`, `Queue` or `Alarm` task: 15 min for the whole task. After the response: 30 s. A wait on a socket: no deadline. The request gets a 503 and the pages and refs of the task go back at once. | `cloudflare-workers/API.md` 10.2, `cloudflare-workers/js/tasks.js:15` |
| The client goes away | `request.signal` cancels the task before the response (needs the flag `enable_request_signal`). The edge also cancels an open response stream. | `cloudflare-workers/API.md` 10.2, `cloudflare-workers/PLAN.md` "Status of the edge run" (E9, E11, E12) |
| CPU limit | Near the limit, workerd writes 24 to `__instance_signal`. The host checks it at each allocation and wait. The task gets a clean trap (503, cause `cpu`) and the instance stays. If the isolate is stopped (`__instance_terminated`), the next request replaces the instance. | `cloudflare-workers/hostlib/cpu.zig:31`, `cloudflare-workers/PLAN.md` problem 5 |
| Memory limit | The budget (R-WH9) keeps wasm under the isolate limit, and a refused grow is a 503 for one request only. | `cloudflare-workers/PLAN.md` problem 4 |

### Release, shim and project setup

```
platform release X.Y.Z: <hash>.tar.zst  (one file, CI builds it with compat/last-stack-first-nightly)
├─ Roc modules (exposed in main.roc) + packages http, cbor by release URL
├─ targets/wasm32/host.wasm          (production host: no bench exports)
└─ js/                                (the shim: same version as the host)
   ├─ index.js ...                    makeHandler, objectClass, entrypointClass
   ├─ cli.mjs                         sync: writes worker.js, checks wrangler.toml
   ├─ cfw.json                        { "api": N }: the contract with roc-cfw
   └─ template/                       files for roc-cfw init

Worker project
├─ main.roc       header: platform URL (its hash pins the host and the shim)
├─ talon.toml     [tools] roc-cfw (ref + locked url), [scripts]
├─ .roc-cfw/      copy of js/ (gitignored), made by roc-cfw sync
├─ worker.js      written by sync, imports ./.roc-cfw/index.js
└─ wrangler.toml
```

| Item | State (2026-11-01) | Source |
| --- | --- | --- |
| Platform release | 0.0.1 is released (roc-cbor 0.2.1). 0.0.2 is released (2026-11-01, tag on the submodule commit `241182c`), built with `nightly-2026-10-31-f7bef6b`: `https://github.com/Karakatiza666/roc-cloudflare-workers/releases/download/0.0.2/f352LLRKJCZ4JJVEocp3H9e4e6Sxa6Ym5CxZ1GZCpfd.tar.zst`. Changes: `R2.Range` is `R2.ByteRange`, roc-cbor 0.2.2 (a NULL in a record row is no key, a `Bool` reads 0 and 1), `Memo(a)` with the loader at `get!`. The registry uses 0.0.2 (R-WH12). The `dist/` of the submodule is a local build with another hash: not for the registry. | `cloudflare-workers/README.md` "Changes in 0.0.2", the GitHub release list, `docs/registry/PLAN.md` A.1 |
| Shim | In the bundle (`js/`). There is no npm package and no `package.json` in a project. | `cloudflare-workers/README.md` "What a release has" |
| `roc-cfw` | 0.0.1 is released: a basic-cli app, released as an app bundle, so Talon builds it from the locked `url` (CLI 6.4, R-PT6). Commands: `shim`, `sync`, `init`. `sync` finds the bundle with `tln path pf`, copies `js/` to `.roc-cfw/` when the platform hash changed, then runs `node .roc-cfw/cli.mjs sync`. It refuses a `cfw.json` `api` number that it does not support (exit 2). | `cloudflare-workers/research/talon-fit/TRANSITION.md` 1, 5 |

R-WH12: The registry Worker (`worker/`) pins `roc-cfw` in its `talon.toml` `[tools]` (CLI 6.4, R-PT1). Its build script runs `roc build` and then `roc-cfw sync`. Its `worker.js` imports the shim from `.roc-cfw/`. No global install of `roc-cfw`, and no npm package. The header names the platform by its release URL, from 0.0.2 (Design Q54). A platform fix waits for a platform release. The submodule `cloudflare-workers/` is for platform work, not for the registry build.

R-WH13: The compiler of `worker/` (Design Q59). It is the nightly that the platform release was built with: `nightly-2026-10-31-f7bef6b` for 0.0.2 (`cloudflare-workers/compat/last-stack-first-nightly`). The `roc:` pin of the `worker/` header names it, and `ROC_TAG_WORKER` of `scripts/env.sh` holds the tag (`TESTING.md` TW28). The CLI keeps its own nightly (`ROC_TAG`). `packages/records` (Design 6.1, R-PK7) builds and passes its tests on both nightlies. A move to a new platform release moves `ROC_TAG_WORKER` and the pin in the same change.

### Settings, secrets and bindings

R-WH14: The Worker reads these settings (`[vars]` of `wrangler.toml`), secrets (`wrangler secret put`) and bindings, and no other (Design Q63). The names marked "proposal" are a proposal, as in CLI 3, R-OUT2: the human accepts or changes them at the review of the first registry slice. A change of a name changes this table and each rule that names it, in one change.

| Name | Kind | Value or use | Rules | Name state |
| --- | --- | --- | --- | --- |
| `AUDIENCE` | Setting | The base URL of the registry, with no trailing `/` (the text: R-TP17). The `aud` of each OIDC token, and the `iss` and `aud` of the JWT. | R-TP3 row 2, R-TP17, R-CT9 | Named. The use for the JWT is a proposal. |
| `BOT_REPOSITORY_ID` | Setting | The GitHub id of `roc-talon/talon` | R-TP7, R-MX15 | Named |
| `BOT_WORKFLOW_REF` | Setting | The `workflow_ref` of the bot workflow on the default branch | R-TP7, R-MX15 | Named |
| `ISSUES_URL` | Setting | `https://github.com/roc-talon/talon/issues` | R-TP12 | Named |
| `MIN_TLN_WRITE`, `MIN_TLN` | Setting | Empty by default | R-AP45 | Proposal (R-AP45) |
| `GITHUB_APP_ID` | Setting | The id of the GitHub App `Talon Indexer`, digits only (5572595). The `iss` of the JWT, as a number. | R-PU25, R-PU41 | Proposal |
| `GITHUB_APP_INSTALLATION_ID` | Setting | The installation id of the App on `roc-talon` (177657685), digits only. The path of the token request. | R-PU41 | Proposal |
| `CONTRIBUTOR_KEY` | Secret | The HMAC key of a machine id | R-CT3 | Named |
| `TOKEN_KEY` | Secret | The Ed25519 private key of the JWT, as the text of a private JWK (RFC 8037): `kty` `OKP`, `crv` `Ed25519`, `x`, `d`, and `kid`, a text that is not empty. The `kid` of the JWT is this member, and the Worker takes the public key from the same text (Design Q300). A text that is not such a JWK is 500 `internal`. Deploy note (slice 121): make the key with WebCrypto `generateKey` and `exportKey("jwk")` (Node), add a `kid`, then `wrangler secret put TOKEN_KEY` | R-CT9 | Named. The form is decided (Q300) |
| `GITHUB_WEBHOOK_SECRET` | Secret | The HMAC-SHA256 key of `X-Hub-Signature-256` | R-AP12 | Proposal |
| `GITHUB_APP_KEY` | Secret | The private key of the App, as a PKCS#8 PEM, for the RS256 JWT that gets an installation token. Deploy note (slice 121): GitHub gives a PKCS#1 PEM, so convert it once before `wrangler secret put`: `openssl pkcs8 -topk8 -nocrypt -in app.pem -out app.pkcs8.pem`. The first line must be `-----BEGIN PRIVATE KEY-----`. | R-PU25, R-PU41 | Proposal |
| `GITHUB_READ_TOKEN` | Secret | Only when the P2 check of R-PU25 fails: the token of the fallback | R-PU25 | Proposal |
| `OPERATOR_KEY` | Secret | The operator key (P3) | R-YK2, R-TP15 | Named |
| The log signing key | Secret | P3 | R-SG4, R-SG7 | Not named (Design Q55) |
| `DB` | D1 | The registry database. Migrations: `sql/` (Design 6.3). | Section 5 | Proposal |
| `LOG` | R2 | The tiles and the checkpoint (P3). P2 does not use it. | R-SG4, R-SG7 | Proposal |
| `INDEX` | Queue (producer and consumer) | The queue `talon-index`: the index jobs, with the delays 1, 5, 15 and 60 min. The consumer has `max_retries = 4` and the dead letter queue `talon-index-dlq`. | R-PU11, R-PU13, R-PU35, R-PU45 | Proposal (the binding and the queue name) |
| `INDEX_DLQ` | Queue (consumer only) | The queue `talon-index-dlq`, the dead letter queue of `INDEX`. Its consumer writes a log line. The code has no producer for it, so only `wrangler.toml` names it. | R-PU35, R-PU45 | Proposal (the binding and the queue name) |
| `RL_INGEST` | Rate limit | 60 a minute for each key: `simple = { limit = 60, period = 60 }` in `[[ratelimits]]` | R-PU34 row 1, R-AP68 | Proposal |
| `RL_HINTS` | Rate limit | 30 a minute for each key | R-CT11 | Proposal |
| `RL_LOGIN` | Rate limit | 10 a minute for each key: `POST /v1/tokens`, `DELETE /v1/contributors/me`, one budget for both (Design Q308) | R-CT11, R-CT16 row 9 | Proposal |
| Cron triggers | Not a binding | Every 5 min (R-PU23) and once a day (R-PU35) | R-PU35 | |

The key of each rate limit is the IPv4 address, or the IPv6 /64 prefix (R-CT11, R-PU34). A test sets each value with test keys only (`TESTING.md` 9).

### Edge results that matter to the registry

Run on 2026-10-17, Workers Free plan, client in Tbilisi (colo `TBS`), D1 in `EEUR`. Source: `cloudflare-workers/PLAN.md` "Status of the edge run" (E1 to E53), `cloudflare-workers/edge/results/`.

| Item | Result on the edge | Effect for the registry |
| --- | --- | --- |
| 128 MB (E7, E8) | Wasm memory of 113 MB worked, and the isolate stayed. A grow over the allocator cap of 128 MiB is a clean out-of-memory 503 before JS is asked. Over the isolate limit (2 tries, 160 MB of JS, and 113 MB of wasm with 64 MB of JS): the request that went over finished, a request in flight finished, and the next request came to a new isolate. No request failed. | The budget of 80 MB for wasm keeps the clean 503. The edge did not fail the requests in flight in 2 tries: the old claim "all requests in flight fail" is not confirmed. Q28 (the largest archive) still needs a test with a real archive. |
| CPU signal (E2 to E5) | A wasm loop past the limit: 503 `trap cpu limit` after 0.9 to 2.0 s of wall time, live bytes 0. The same isolate served the next request, and the signal read 0 there. The Free plan refuses `limits.cpu_ms`. A request of about 1 s of CPU passed on the Free plan. | A request that uses too much CPU gets a 503 and does not stop the other requests. A paid plan is needed to set `cpu_ms` (Q14, Q28). |
| Cron, no retry (E13, AQ12) | A cron run that gives `Err` is not run again. 74 planned times in 61 minutes, 1 run for each time. `no_retry!` changes nothing that shows. | A failed run is not run again. The work stays due by the state of D1 (R-PU35), and each job is safe for 2 runs at once (R-PU36). |
| D1 BLOB (E34) | A BLOB comes to JS as an array of numbers (`[object Array]`), not as a `Uint8Array`. | The Worker reads each BLOB column as `List(U8)`: the 32 hash bytes of `names.value` (R-IK3, R-IK8). |
| D1 integers (E32) | An INTEGER of 2^53 or more as text, and a 64-bit rowid, pass. | The id rules of R-IK2 hold on the edge. |
| D1 query time (8g edge) | One query takes 70 to 98 ms from the Worker in `TBS` to D1 in `EEUR` (20 rows: 70 to 74 ms, 200 rows: 85 to 98 ms). The typed read of 200 rows is about 0.3 ms, under 1 % of a query. | Each D1 call that runs after another adds one round trip. Rows add less. R-AP41 gives the budget of each route. |
| One client, many isolates (E35) | 40 requests in a row from one client came to 2 isolates. | No state in memory is shared. `Memo` is for each isolate. This is the case of Q26. |
| JSPI crossing (8g edge) | A crossing costs about 2 times the local time (3 µs for `call!` of 1 op, 4 to 6 µs for `await!`). The check at resume adds 1 to 1.5 µs for an `await!` of 0 or 1 op. | A wait costs microseconds. A D1 round trip costs tens of milliseconds, so the wait cost is not the limit. |

Open for the registry app:

| Item | State | Where |
| --- | --- | --- |
| 12g: record the allocator calls of the registry app, replay them against the allocator, measure the heap waste (H7, H8), and set `heapCheckEvery` from the median request time | Waits for the registry app on the platform | `cloudflare-workers/PLAN.md` problem 12 (step 12g), order of work row 13, Design Q14 |
| A load test of the registry app on the paid plan with `cpu_ms` | Not done. The Free plan refuses `cpu_ms`. | Design Q14, Q28 |
| The example app deployed by the CI of the platform (11c) | Not done | `cloudflare-workers/PLAN.md` order of work row 11 |

R-WH11: If JSPI is ever removed, Talon returns effects as data, as Joy does. The Roc API (the modules of `cloudflare-workers/API.md`) does not change. Only the platform changes.

### D1 call limit and placement (edge, 2026-10-17)

Measured on the edge from 5 colos, with a D1 primary in `EEUR` (colo `PRG`). Scripts and raw data: `research/edge-q47-q49/`. These facts settle Q47 and Q49.

D1 calls in one invocation (Q47):

| Case (one invocation) | Result |
| --- | --- |
| Single `run()` calls, one after the other (fetch handler and cron handler) | 1,000 pass. Call 1,001 fails: `Too many API requests by single Worker invocation.` |
| 1,100 `run()` calls at the same time | 1,000 pass, 100 fail with the same error |
| One `batch()` of 60, 200, 1,000 or 5,000 `SELECT` statements | 1 call each. All pass: 74, 106, 281 and 666 ms. |
| One `batch()` of 200 `INSERT` and 1 `DELETE` | 1 call, passes |
| Batches of 20 statements, one after the other | 1,000 batches pass (20,000 statements). Batch 1,001 fails. |
| One `exec()` of 60 statements | 1 call, passes |
| 30 D1 calls, then `fetch()` calls | The `fetch()` subrequest count is separate from the D1 count: `fetch()` fails only at the subrequest limit (`Too many subrequests by single Worker invocation.`) |

D1 time for each call, measured inside the Worker (Q49):

| Worker colo | D1 instance | ms for each call |
| --- | --- | --- |
| `FRA` | primary `PRG` | 24 |
| `LHR` | primary `PRG` | 30 |
| `TBS` | primary `PRG` | 70 |
| `DFW` | primary `PRG` | 152 |
| `KIX` | primary `PRG` | 245 |
| `DFW` | replica in `DFW` | 12 to 14 |
| `KIX` | replica in `ICN` | 49 |

Client time in ms, median, by route and placement (Q49). Clients: Durable Objects with the location hints `wnam` (ran in `DFW`), `weur` (`LHR`), `apac` (`KIX`), and one machine in `TBS`. 4 to 18 samples for each cell.

| Route | Placement | DFW | LHR | KIX | TBS |
| --- | --- | --- | --- | --- | --- |
| Closure, 1 batch of 200 rows | default | 161 | 38 | 250 | 89 |
| Closure | Smart Placement (stayed local) | 164 | 41 | 252 | 89 |
| Closure | `placement.region` near `FRA` | 184 | 59 | 271 | 117 |
| Closure | default, read session | 22 | 38 | 54 | 87 |
| Closure | `FRA`, read session | 186 | 68 | 275 | 125 |
| 3 dependent calls | default | 465 | 104 | 741 | 229 |
| 3 dependent calls | `FRA` | 241 | 109 | 334 | 176 |
| 3 dependent calls | default, read session | 48 | 104 | 157 | 228 |
| Publish-like, 1 read then 1 write batch | default | 334 | 96 | 514 | 184 |
| Publish-like | `FRA` | 235 | 104 | 322 | 161 |

| Placement fact | Result |
| --- | --- |
| Smart Placement | It did not move the Worker in 1 hour with about 1,800 requests from 4 colos: the status stayed `INSUFFICIENT_INVOCATIONS`, and each answer had `cf-placement: local-<client colo>`. |
| `placement.region` | Applied from the first request (`cf-placement: remote-FRA`). It adds one hop from the client to the Worker: 35 ms (`LHR`) to 246 ms (`KIX`), about one D1 round trip. |
| Read replication | Turned on by the API (`read_replication.mode = auto`). A replica answered after about 1 min. Replicas seen: `WNAM` (`DFW`) and `APAC` (`ICN`). Sessions from `LHR`, `TBS` and `FRA` went to the primary. |
| Effect | A remote placement makes a 1-call route 21 to 28 ms slower, makes a route with 2 or more calls in a row faster from far colos, and removes the replica gain. |
