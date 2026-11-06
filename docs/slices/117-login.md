# 117 Login, the registry JWT, the tracker and delete

Phase: P2. Status: review (scope and test agent, 2026-11-02). The answers of the design agent (Q300 to Q312, R-CT16) are applied to the tests (section 11). Model for the code: Sonnet high. The code is about 470 lines (TW19), so the code step has two parts: 117a (login, the JWT, the tracker) and 117b (the two delete routes). One slice file and one set of tests: section 1 says which test goes with which part.

This file is the only link between the test agent and the code agent (TW18). The code agent does not read `research/slice-117-revert/reference/` (the private reference).

The routes are `POST /v1/tokens` (R-AP37), `DELETE /v1/tokens` (R-AP38), `GET /v1/contributors/me` (R-AP35) and `DELETE /v1/contributors/me` (R-AP36). The wire types are in `packages/records/Account.roc` (slice 104e, green): use them. Do not change `packages/`.

## 1. Scope

| Part | Who | State |
| --- | --- | --- |
| `worker/lib/Login.roc`: types, constants, signatures, the doc comment of each function is the rule. Every body is `crash "todo"` (except the constants) | Test agent (signatures), code agent (bodies) | Stubs |
| `worker/LoginRoutes.roc`: `post_tokens!`, `delete_tokens!`, `get_me!`, `delete_me!` are `crash "todo"`, the flow is in the doc comment. `limiter` (`RL_LOGIN`) is a constant | Test agent (signatures), code agent (bodies) | Stubs |
| `worker/lib/Route.roc`: the 4 tags of `Route.Id` | Test agent | Done. The lines of `Route.decide` are missing: the code agent writes them (section 3.5) |
| `worker/main.roc`: `import LoginRoutes`, 4 arms in `run!`, `LoginRoutes.limiter.declare()` in `bindings` | Test agent | Done |
| `worker/wrangler.toml`: `[[ratelimits]]` `RL_LOGIN` (10 a minute) | Test agent | Done. `roc-cfw sync --check` needs it |
| `worker/lib/main.roc` (exposes `Login`), `worker/tests/unit/w0.roc` (imports `LoginTest`) | Test agent | Done |
| `worker/tests/run.mjs`, `worker/tests/oidc.mjs`, `worker/tests/oidc/claims-account.json`: Ed25519 test keys, JWT test tokens, `require` in the fake GitHub, the default `RL_LOGIN` and `RL_HINTS` bindings (section 5.3) | Test agent | Done. The copies before are in `research/slice-117-revert/before/` |
| `worker/lib/Client.roc` `is_write`: add `PostTokens`, `DeleteTokens`, `DeleteMe` (Design Q182, slice 116b section 12.1 T6) | Code agent 117b | Missing. `LoginTest` has the check |
| Tests: section 5 | Test agent | Red |

No SQL file and no W1 case: the statements are strings of `Login` (as `Hints`). W0 pins their key words, W2 pins what they do on local D1. The schema and the triggers are slices 102 and 103; this slice does not change them.

Split of the code step (TW19):

| Part | Code | Cases that must pass |
| --- | --- | --- |
| 117a | `POST /v1/tokens`, the JWT (sign, check), `GET /v1/contributors/me`: all of `Login` except `delete_proof`, `revoke_sql`, `forget_*`; `post_tokens!`, `get_me!`; the 2 route lines; about 330 lines | W2 `ct8-login`, `ct8-login-refusals`, `ct9-token-check`, `ct10-tracker`. W0 `LoginTest`, all but `delete_proof`, the SQL words of `revoke`/`forget`, and the route rows of the two delete routes |
| 117b | `DELETE /v1/tokens`, `DELETE /v1/contributors/me`: `delete_proof`, `revoke_sql`, `forget_account_sqls`, `forget_machine_sqls`, `delete_tokens!`, `delete_me!`, `Client.is_write`, the 2 route lines; about 140 lines | W2 `ct7-delete`, `ct9-tokens-after`, and the delete requests of `ct11-login-limit` and `ap45-write-routes`. Then the whole `LoginTest` |

The private reference has 243 code lines in `Login` and 196 in `LoginRoutes`, plus 20 lines in `Route.roc` and 1 in `Client.roc`.

## 2. Rules

| Rule | Text (short) | Checked by |
| --- | --- | --- |
| R-AP37 | `POST /v1/tokens` `{github_token}`, header `Talon-Contributor` optional. 201 `{token, expires_at, account: {id, login}}`. 400, 401, 429, 502 | W0 `login_token`, `github_user`. W2 `ct8-login`, `ct8-login-refusals`, `ct11-login-limit` |
| R-AP38 | `DELETE /v1/tokens`: the JWT. 204. Each token of the account stops | W0 `revoked`, `revoke_sql`. W2 `ct9-tokens-after` |
| R-AP35 | `GET /v1/contributors/me`: the JWT. 200 tracker, `no-store`. 401 | W0 `tracker_of`. W2 `ct9-token-check`, `ct10-tracker` |
| R-AP36 | `DELETE /v1/contributors/me`: the JWT (account) or `Talon-Contributor` with no JWT (one machine). 204, also when nothing was stored | W0 `delete_proof`, `forget_*`. W2 `ct7-delete` |
| R-CT8 | The login: `GET /user` with the token, 401 or 502, upsert of `contributors`, upsert of `links`, the move of the rows of the machine, the totals | W0 `github_user`, the `machine_sqls` words. W2 `ct8-login`, `ct8-login-refusals` |
| R-CT9 | The JWT: `EdDSA`, `kid`, `iss` and `aud` equal to `AUDIENCE`, `sub` the user id as text, `exp` = `iat` + 30 days. The check: signature, `iss`, `aud`, `exp`, and `iat` not before `tokens_after` | W0 `signing_key`, `signing_input`, `decode`, `check`, `revoked`. W2 `ct9-token-check`, `ct9-tokens-after` |
| R-CT10 | The tracker: `machines`, `counted`, `first`, `agreed`, `disagreed`, `unconfirmed`, `first_time`, `last_time`, from the rows when they are read, in one query, plus `contributor_totals` | W0 `tracker_sql` words. W2 `ct10-tracker` |
| R-CT7 | Delete: the machine form and the account form. `compat_hints` never changes | W0 `forget_*`. W2 `ct7-delete` |
| R-CT5 (read part), R-CT6 | No fold: the totals come from the rows. What each table keeps, and what a delete removes | W2 `ct10-tracker`, `ct7-delete` |
| R-CT11 | `POST /v1/tokens` and `DELETE /v1/contributors/me`: 10 a minute for each rate key (`RL_LOGIN`). 429 with `Retry-After`. The key is `Client.rate_key` | W2 `ct11-login-limit` |
| R-RE17, R-RE18, R-RE25 | `contributors`, `links`, `contributor_totals` | W2 `ct8-login`, `ct7-delete`, `ct10-tracker` |
| R-AP41 | D1 calls: 1 for each of the 4 routes (the GitHub read comes first for the login) | W2 `d1-calls` of each case |
| R-AP45 (Q182), R-AP48 | The 3 write routes are checked with `MIN_TLN_WRITE`, the tracker with `MIN_TLN`. The client check comes before the media type and the token | W0 `Client.is_write`. W2 `ap45-write-routes` |
| R-AP21, R-AP23, R-AP46, R-AP50, R-AP51, R-AP73 | Problem form, JSON media, the 256 KB body, times in ms, missing members, the `records` types | W0, W2 |

## 3. What the code agent writes

### 3.1 Files

| File | What |
| --- | --- |
| `worker/lib/Login.roc` | The bodies. The doc comment of each stub is the rule. Reuse `Oidc.bearer`, `Oidc.jwt_detail`, `Hints.machine_id`, `Hints.hmac_message`, `Hints.contributor_id`, `Client.rate_key`, `Compat.body_limit`, `Compat.Reject`, `records.Account` |
| `worker/LoginRoutes.roc` | The bodies of the 4 handlers (section 3.3) |
| `worker/lib/Route.roc` | The lines of `decide` (section 3.5) |
| `worker/lib/Client.roc` | `is_write` (117b) |
| `sql/0001_init.sql` | The column `last_time INTEGER NOT NULL` after `first_time` in `contributor_totals` (Q302; the schema is not deployed, so no new migration). The test agent did not edit this file: the W1 case `schema/s1-tables` and the seeds of `account/` need it. Do it first, in 117a |

Hints:

- `Jwt.decode(text, Jwt.Options.{ algs: [EdDSA] })`, `Jwt.check(claims, Jwt.Rules.{ now_ms, leeway_s: 60, aud: OneOf([audience]), iss: OneOf([audience]), require: [Exp, Iat, Sub] })`, `Jwk.parse`, `Jwk.to_public_json` are in `roc-jwt` 0.0.1. It has no encoder: base64url of the token parts is yours. `roc-base64` 1.0.2 (`Base64.encode_url`) is a dependency of `roc-jwt`, but the app header does not name it. Either add it to `worker/main.roc`, `worker/lib/main.roc` and the `app` line of `worker/tests/unit/w0.roc` (this one line of `w0.roc` is not a test), or write the 15 lines (the reference does).
- `WebCrypto.sign!({ alg: Ed25519, key: Jwk(secret text), data })` and `WebCrypto.verify!({ alg: Ed25519, key: Jwk(public json), signature, data })` (platform 0.0.2, `cloudflare-workers/API.md` RN4). `Env.secret!("TOKEN_KEY")`, `.reveal()`.
- A D1 statement takes as many values as its highest `?n`. A 64-bit id is bound as decimal text with `CAST(?n AS INTEGER)` in the SQL (as `Hints`). A `NULL` column is `Try(.., [Missing])` in a row type.
- `Json.to_str` of a text gives the JSON string with escapes (for the header and the payload of the token). Check that `/` is not escaped: `LoginTest` has a vector with `https://r.example/a\\b`.

### 3.2 The signatures

See `worker/lib/Login.roc`. In short:

| Function | Signature |
| --- | --- |
| `Login.login_token` | `List(U8) -> Try(Str, Compat.Reject)` |
| `Login.github_user` | `U16, Str -> Try(Login.GithubUser, Problem)` |
| `Login.signing_key` | `Str -> Try(Login.SigningKey, [BadKey])` |
| `Login.seconds_text`, `expires_at` | `U64 -> Str`, `U64 -> U64` |
| `Login.signing_input`, `token_text` | `{ kid, sub, now_ms, audience } -> Str`, `Str, List(U8) -> Str` |
| `Login.decode` | `Str, Str -> Try(Login.Decoded, Problem)` (the token, the `kid` of the key) |
| `Login.check`, `revoked` | `Login.Decoded, { audience, now_ms } -> Try(Login.Verified, Problem)`, `{ iat_ms, tokens_after } -> Bool` |
| `Login.jwt_problem` | `Jwt.Error, Str -> Problem` |
| `Login.delete_proof` | `{ authorization, contributor } -> [Account(Str), Machine(Str), Refuse(Problem)]` |
| `Login.tracker_of` | `Login.GithubUser, Login.TrackerRow -> Account.Tracker` |
| SQL | `account_sql`, `account_row_sql`, `tracker_sql`, `revoke_sql : () -> Str`; `machine_sqls`, `forget_account_sqls`, `forget_machine_sqls : () -> List(Str)` |
| Handlers | `LoginRoutes.post_tokens!`, `delete_tokens!`, `get_me!`, `delete_me! : Request => Try(Response, ReadRoutes.Error)` |

### 3.3 The flow of the four handlers

Common steps:

| Step | Rule |
| --- | --- |
| The proof of an account route | `Oidc.bearer(header)`: `NoToken` is `Login.missing_token`, `Refuse(problem)` is its 401. The secret `TOKEN_KEY` through `Login.signing_key` (a missing secret or `Err(BadKey)` is a fault, 500). `Login.decode(token, key.kid)`. `WebCrypto.verify!` with the public JWK of the key (`BadSignature` and `CryptoErr` are `Login.bad_signature`). `Login.check` with the setting `AUDIENCE` and `Time.now_ms!()`. No D1 call before the proof ends |
| The rate limit | `limiter.limit!(Client.rate_key(req.header("cf-connecting-ip")))`. Over the limit: 429 `Login.rate_problem` with `Retry-After: 60`. A fault of the binding is a fault |
| Answers | A body: `content-type: application/json`, `cache-control: no-store`. No body: 204 with `cache-control: no-store`. A `Constraint` error of D1 is a fault (500). The answer never holds the GitHub token |

| # | `POST /v1/tokens` (117a) |
| --- | --- |
| 1 | The body: `req.bytes_with!({ max_bytes: Compat.body_limit })`. Too large: 413 field `body` (`Login.too_large`). `Route.decide` gives the 415 before |
| 2 | The header `Talon-Contributor`, when there is one: `Hints.machine_id`, 400. (As R-AP70: the id check comes before the body decode) |
| 3 | `Login.login_token(bytes)`: 400 |
| 4 | The rate limit. No D1 call and no GitHub read yet |
| 5 | `Http.send!` of `GET Login.user_url` with `authorization: Bearer <github_token>`, `accept: application/vnd.github+json`, `user-agent: talon-registry`. No answer: `Login.user_no_answer`. Else `Login.github_user(status, body)` (the body only for status 200) |
| 6 | `Time.now_ms!()` once. `TOKEN_KEY`, `AUDIENCE`, and with the header `CONTRIBUTOR_KEY` (the machine id as in `HintRoutes`). A fault here is 500, before any write |
| 7 | `Login.signing_input`, `WebCrypto.sign!`, `Login.token_text` |
| 8 | D1 call 1, the only one: one `batch!` on the primary of `Login.account_sql` (bound `id`, `login`, `now`) and, with the header, the 5 statements of `Login.machine_sqls` |
| 9 | 201, `Account.encode_token({ token, expires_at: Login.expires_at(now), account: { id, login } })` |

| # | `GET /v1/contributors/me` (117a) |
| --- | --- |
| 1 | The proof. No rate limit |
| 2 | D1 call 1, the only one: one `batch!` on the primary of `Login.account_row_sql` and `Login.tracker_sql` (bound: the id as text). No account row: 401 `Login.no_account`. `Login.revoked`: 401 `Login.revoked_problem`. Else 200, `Account.encode_tracker(Login.tracker_of(..))`, no `etag` |

| # | `DELETE /v1/tokens` (117b) |
| --- | --- |
| 1 | The proof. No rate limit |
| 2 | D1 call 1, the only one: `Login.revoke_sql` bound (id text, `now`, `iat_ms`). No row returned: 401 `Login.not_good`. Else 204 |

| # | `DELETE /v1/contributors/me` (117b) |
| --- | --- |
| 1 | `Login.delete_proof`: `Refuse(problem)` is the answer (400 or 401) |
| 2 | `Account(text)`: the proof of the text (steps as above, with no header read), then the rate limit, then D1 call 1, the only one: the batch of `Login.forget_account_sqls` bound (id text, `iat_ms`). The first result has a row: 401 `Login.not_good` (the guards of the other statements did nothing). Else 204. An account with no row is not an error (Q117-6) |
| 3 | `Machine(id)`: the rate limit, `CONTRIBUTOR_KEY`, the machine id, D1 call 1, the only one: the batch of `Login.forget_machine_sqls` bound (the machine id as text). 204 |

### 3.4 The SQL (the contract between `Login` and W2)

| Statement | Result and rule |
| --- | --- |
| `account_sql` (?1 id text, ?2 login, ?3 now) | A new row: `tokens_after`, `first_time`, `last_time` are ?3 (Q117-8). An existing row: only `login` and `last_time` change |
| `machine_sqls` (?1 account, ?2 machine, ?3 now) | 1 the upsert of `links` (a later login moves the link). 2 `UPDATE OR IGNORE contributions` to the account. 3 `DELETE` the rows that stayed. 4 the totals of the machine added to the totals of the account (a row is made when the account has none; `first_time` is the smaller, `last_time` is the larger, Q302). 5 `DELETE` the totals of the machine. No statement writes `compat_hints` or `contributions` rows |
| `account_row_sql` | `login`, `tokens_after` of the account. 0 or 1 row |
| `tracker_sql` (?1 id) | One row. `first`: no `compat` row (any source) with a smaller `time`, and no row of another contributor with a smaller `time`, or the same `time` and a smaller id. `agreed`, `disagreed`, `unconfirmed`: the `bot` row (`source` 0) of the pair has the same result, another result, or there is none. A bot `hang` is another result than a hint `crash`. One `bot` row and one `author` row on a pair count the row once. The totals row is added; `first_time` is the smaller; `last_time` is the larger of the rows and the totals row (Q302), so a totals-only account has the `last_time` of its totals |
| `revoke_sql` (?1 id, ?2 now, ?3 `iat_ms`) | `UPDATE contributors SET tokens_after = ?2 ... AND tokens_after <= ?3 RETURNING`: 1 row for a good token |
| `forget_account_sqls` (?1 id, ?2 `iat_ms`) | 1 `SELECT 1 AS revoked`: a row when `tokens_after` is above ?2. 2 to 5 `DELETE` of the rows of the account, its `links`, its totals and its `contributors` row, each with `NOT EXISTS (.. tokens_after > ?2)` |
| `forget_machine_sqls` (?1 machine) | `DELETE` the `contributions` rows, the totals row and the `links` row of the machine. Never the rows of the account that it is linked to |

### 3.5 Edits of files that other slices own

| File | Edit |
| --- | --- |
| `worker/lib/Route.roc` | In `decide`: `["v1", "tokens"]`: `POST` is `decide_post(input, path, PostTokens)`, `DELETE` is `Handle(DeleteTokens)` (no media check), another method is `NotAllowed(.., ["DELETE", "POST"])`. `["v1", "contributors", "me"]`: `GET` is `Handle(GetMe)`, `DELETE` is `Handle(DeleteMe)`, another method is `NotAllowed(.., ["DELETE", "GET"])`. The 405 `detail` is `<method> is not allowed on <path>` as the other routes. Re-read the file before the edit |
| `worker/lib/Client.roc` | `is_write`: the three write routes (117b) |
| `worker/main.roc`, `worker/wrangler.toml` | Done by the test agent. The code agent adds a header line only if it adds `roc-base64` |

## 4. Output (proposed, TW24)

| Item | Proposal |
| --- | --- |
| 201 body | `Account.encode_token`: the members `account`, `expires_at`, `token` (the derived order of the record). `expires_at` is `now` + 30 days in ms (R-AP50). Headers `content-type: application/json`, `cache-control: no-store` |
| 200 body of the tracker | `Account.encode_tracker`. Headers as above. No `etag` (Q117-13, Q312) |
| 204 | No body. Header `cache-control: no-store` |
| The JWT header | `{"alg":"EdDSA","kid":"<kid>","typ":"JWT"}` |
| The JWT payload | `{"aud":A,"exp":E,"iat":I,"iss":A,"sub":"<id>"}`. `A` is the setting `AUDIENCE`. `I` is the request time in seconds with 3 decimals (`1767225601.234`), `E` is `I` + 2592000 (Q117-2) |
| 400 login body | `the login request body is not valid: <why>`. `<why>`: `github_token is missing`, `github_token is empty`, `github_token is longer than 512 bytes`, `github_token has a byte that is not allowed in a token`, `it is not UTF-8`, `it is not a JSON object with the member github_token` |
| 400 id | `the header Talon-Contributor must be 32 characters, each one of 0 to 9 and a to f` (`Hints.machine_id`) |
| 400 delete | `the request needs the header Authorization (an account) or the header Talon-Contributor (one machine)` |
| 413 | `the body of the login request is larger than its limit of 262144`, field `body`, limit 262144 |
| 401 | `the request has no Authorization header: this route needs a registry token`; `the Authorization header must be "Bearer <token>"`; `the token is not a valid JWT`; `the token alg is "<alg>", expected "EdDSA"`; `the token alg is missing`; `the token kid is missing`; `the token kid "<kid>" is not the key of this registry`; `the token signature is not valid`; `token claim iss is "<iss>", expected "<AUDIENCE>"`; the texts of `Oidc.jwt_detail` for `aud`, `exp`, `iat` (a time error says `leeway 60 s`, Q301: `token claim exp is <exp>: the token expired (now is <now>, leeway 60 s)`); `token claim sub is "<sub>", expected a GitHub user id`; `the account of the token has no data in this registry: log in again`; `the token was issued before the last revoke of the tokens of its account: log in again`; `the token is revoked or its account has no data in this registry: log in again`; `GitHub refused the token` |
| 429 | `too many login requests from this address: try again in a minute`, `Retry-After: 60` |
| 502 | `the GitHub user read failed with status <n>`; `the GitHub user read failed: no answer`; `the GitHub user read gave an answer that is not a user` |

## 5. Tests

| Layer | Case | Rules |
| --- | --- | --- |
| W0 | `worker/tests/unit/LoginTest.roc`, 11 `expect`s: `login_token` (20 forms: good, extra members, JSON escape, the length edge 512 and 513, missing, null, empty, a space, CR LF, a byte above 126, wrong types, not UTF-8, the body edge 262,144 and 262,145 bytes); `github_user` (all statuses 200, 401, 403, 404, 429, 500, 302 and 12 bad bodies); `signing_key` (a good RFC 8037 key, no `kid`, empty `kid`, no `x`, RSA, EC, oct, not JSON); `seconds_text`, `expires_at`, `signing_input` (2 exact vectors from node), `token_text` (an exact signed token from node), decode of that token; `decode` (10 forms); `check` (23 claim forms at the clock 1767225601000); `revoked` (edges); `delete_proof` (10 rows); `tracker_of`; the key words of the 7 SQL texts; the routes (`Route.decide` 4 routes, 405 `Allow`, 415, 404, `Client.is_write`) | R-AP35 to R-AP38, R-AP21, R-AP23, R-AP45, R-AP46, R-AP48, R-AP51, R-CT7 to R-CT11, R-RE17, R-RE18, R-RE25 |
| W2 | `account/ct8-login`: 4 logins. Machine m1 to account 4242 (3 rows move, totals move); machine m2 to the same account with a new login name (a pair that the account has stays once, one row moves, totals add, `first_time` is the smaller, `last_time` is the larger: the account has totals of its own; `last_time` of the account is 300, m1 brings 500 (m1 merges first), m2 brings 400, the result is 500, so "keep", "incoming" and "smaller" all fail, Q302); no header (no link); m1 again to account 99 (the link moves, no totals row is made). The runner checks the token (signature, header, claims) and `expires_at`. The GitHub request has the headers. DB: `contributors`, `links`, `contributions`, `contributor_totals`, and `compat_hints` unchanged. 1 D1 call each | R-AP37, R-AP41, R-AP50, R-CT3, R-CT8, R-CT9, R-RE17, R-RE18, R-RE25 |
| W2 | `account/ct8-login-refusals`: 11 requests. 415, 413, a bad id with a good body and with a body that is no JSON (the id first), no body, `{}`, a token with a space, GitHub 401, 500, a 200 without `id`, then a good login. 0 D1 calls and no GitHub read for the first 7 | R-AP37, R-AP46, R-AP48, R-AP51, R-AP23, R-CT1, R-CT8, R-AP21, R-AP41 |
| W2 | `account/ct9-token-check`: 20 requests of `GET /v1/contributors/me`: no header, `Basic`, garbage, an RS256 token with the right claims, `alg` none, another `kid`, a changed signature, a changed payload, another Ed25519 key, wrong `iss`, wrong `aud`, `exp` = clock - 60 s, `iat` = clock + 60.001 s (the leeway is 60 s, Q301), `sub` that is not an id (`abc`, `0`, `-5`, `+7`, `12.5`, empty; R-CT16 row 6): each 401 with 0 D1 calls. An account with no row: 401, 1 call. A revoked token (1 ms before `tokens_after`): 401. A good token, `exp` = clock - 59.999 s, `iat` at the clock, `iat` = clock + 60 s, `iat` equal to `tokens_after`: 200. The header `Talon-Contributor` is ignored | R-AP35, R-AP41, R-AP48, R-CT9, R-CT16, R-RE17, R-AP21, R-AP50 |
| W2 | `account/ct9-tokens-after`: 21 requests. A login makes `tokens_after`; `DELETE /v1/tokens` sets it; a revoked token cannot revoke; a login in the same ms as the revoke gives a token that works; a token from between the revoke and the next login works, one from 1 ms before the revoke does not (so a login changes no `tokens_after`); `DELETE` of the account, then GET (no row), then a new login: a token from before the delete does not live again | R-AP35 to R-AP38, R-AP41, R-CT7 to R-CT9, R-RE17 |
| W2 | `account/ct10-tracker`: 4 requests from a seeded state (7 hints of the account against `bot`, `author` and other rows, 3 other contributors, 2 machines, a totals row whose `last_time` is above the largest `time` of the rows; a totals-only account, which has the `last_time` of its totals; an account whose totals are older than its rows; an empty account). The expected numbers come from a JS model of R-CT10 (`research/slice-117-revert/gen/gen_117.mjs`). Edges: a `bot` hang against a hint crash, a bot row and an author row on one pair, a `compat` row at the same time as the hint, a tie on `time` with a smaller and with a larger id | R-AP35, R-AP41, R-AP73, R-CT5, R-CT6, R-CT10, R-CT15, R-CT16, R-RE16 to R-RE18, R-RE25, R-RC1, R-RC3, R-RC4 |
| W2 | `account/ct7-delete`: 12 requests. Machine form: unlinked machine (rows, totals gone), again (204), a linked machine (its link and own rows go, the account rows stay). No proof (400), a bad id (400), a bad token with a good id (401, nothing deleted). Account form: all rows, links, totals and the `contributors` row go, `compat_hints` stays; again (204); a revoked token (401, and a GET shows that nothing was deleted); a good token of the other account; a token of an account that never existed (204) | R-AP36, R-AP41, R-AP48, R-CT1, R-CT3, R-CT6, R-CT7, R-CT9, R-CT16, R-RE12, R-RE16 to R-RE18, R-RE25 |
| W2 | `account/ct11-login-limit`: `RL_LOGIN` 3 a minute. Refusals before the limit cost nothing (a body without the member, no proof, a bad token, a machine-form delete with a bad id: Q308). 2 logins and 1 delete use 3; then login and delete are 429 with `Retry-After: 60` and no GitHub read; a valid token is checked before the limit; the tracker and `DELETE /v1/tokens` have no limit; another address passes; a mapped IPv6 address shares the IPv4 budget; an IPv6 /64 shares one budget | R-CT11, R-CT16, R-AP25, R-AP35 to R-AP38, R-AP68, R-WH14 |
| W2 | `account/ap45-write-routes`: `MIN_TLN_WRITE` 0.5.0 and `MIN_TLN` 0.3.0. `tln/0.4.1` is 400 `unsupported-client` (with `minimum`) on the three write routes, before the media type and the token; the tracker passes for 0.4.1 and is refused for 0.2.9; `tln/0.5.0` and `curl` pass; 405 and 404 come before the check | R-AP45, R-AP48, R-AP35 to R-AP38, R-AP21 |

### 5.1 Red results (2026-11-02, the stubs)

| Step | Result |
| --- | --- |
| W0 (`roc test` of `LoginTest`) | 11 `expect`s, 0 pass (`todo`, and the route rows: `NotFound`). 0 compiler errors. `roc fmt --check` passes |
| W2 `account` (stub build, `research/slice-117-revert/ref.sh` with `NOREF=1`) | 0 of 8 pass. Status 404 for the 4 routes (the lines of `Route.decide` are missing) |
| Old W2 with the stubs | `scripts/test.sh wbuild w2`: 123 passed, 4 failed. The 4 are `githubtoken/*` (slice 119a, in work). No old case fails because of `RL_LOGIN` |

### 5.2 Private reference and revert check

`research/slice-117-revert/reference/` and `ref.sh [w0|w2|all]`. With the reference: W0 `LoginTest` 11 of 11, W2 `account` 8 of 8 (the first run).

| Mutation | What | Caught by |
| --- | --- | --- |
| `tokens-after-zero` | A new `contributors` row has `tokens_after` 0 (Q117-8) | W2 `ct8-login`, `ct8-login-refusals`, `ct9-tokens-after` |
| `or-replace` | The account upsert is `INSERT OR REPLACE`: a login resets `tokens_after` | W0 `SQL words`, W2 `ct8-login`, `ct9-tokens-after` |
| `kid-unchecked` | The `kid` of the token is not compared | W0 `decode`, W2 `ct9-token-check` (request 6) |
| `iat-whole-seconds` | `iat` and `exp` in whole seconds (Q301) | W0 `seconds_text`, W2 `ct9-tokens-after` |
| `revoked-le` | `iat` equal to `tokens_after` is revoked | W0 `revoked`, W2 `ct9-token-check`, `ct9-tokens-after` |
| `delete-no-guard` | The guard of the account delete never stops (a revoked token deletes the data) | W2 `ct7-delete` only (the GET after the revoked delete) |
| `totals-first-time-keep` | The totals of a second machine keep the old `first_time` | W2 `ct8-login` |
| `totals-last-time-rows-only` | The tracker takes `last_time` from the rows only (Q302) | W2 `ct10-tracker` (the account whose totals are above its rows, and the totals-only account) |
| `totals-last-time-keep` | The login move keeps the `last_time` of the account | W2 `ct8-login` |
| `totals-last-time-incoming` | The login move takes the `last_time` of the machine, not the larger | W2 `ct8-login` |
| `leeway-0` | `exp` and `iat` have no leeway (Q301) | W0 `check`, W2 `ct9-token-check` |
| `limit-before-id` | The machine form of the delete counts before its id check (Q308) | W2 `ct11-login-limit` (request 4) |
| `tracker-first-le` | A `compat` row at the same time as the hint removes `first` | W2 `ct10-tracker` |
| `limit-before-proof` | `DELETE /v1/contributors/me` (account): the limit before the token proof | W2 `ct11-login-limit` |
| `limit-after-github` | The login limit after the GitHub read | W2 `ct11-login-limit` |

The mutations are in `research/slice-117-revert/mutations/roc.py`; the results are in `mutations/w2-results-run1.txt`, `w2-results-run2.txt` and `w2-results.txt` (the build of `kid-unchecked` and `iat-whole-seconds` has a warning, so run 1 did not run W2 for them; `ref.sh` was changed and run 2 did). Not mutated: the rows that W0 pins with an exact vector (`github_user`, `login_token`, `check`), and `move-no-ignore` (a plain `UPDATE` makes the batch fail: any W2 login with a pair that the account has fails).

### 5.3 Changes of the test tools

| File | Change |
| --- | --- |
| `worker/tests/oidc.mjs` | `edkey(name)`: a throwaway Ed25519 key for each run. `fillSettings`: a setting `{"$edkey": "t1", "kid": "key-1"}` becomes the text of the private JWK (the secret `TOKEN_KEY`). A token spec with `"alg": "EdDSA"` is signed with the key `key` (default `t1`) and has the `kid` `key-1`. `verifyJwt` checks a token of the Worker |
| `worker/tests/run.mjs` | `fillSettings` for the settings. In `expect/responses.jsonl`: `"jwt":{"at","key","header","claims"}`. In a fake GitHub meta file: `"require":{header: value}`. The default bindings `RL_HINTS` and `RL_LOGIN` (limit 1000) for each case |
| `worker/tests/oidc/claims-account.json` | The claims of `"base": "account"` |
| `research/slice-117-revert/gen/` | `gen_117.mjs` makes the 8 cases with a JS model; `vectors.mjs` and `mk_logintest.mjs` make `LoginTest.roc` (node only) |

## 6. Requests to other slices

| # | To | Request |
| --- | --- | --- |
| RQ1 | Slice 120 (daily crons) | The trim (R-CT15) writes `contributor_totals` that this slice reads. the column `last_time` is new (Q302): the trim writes the larger `last_time` of the old totals and the trimmed rows (R-CT15 step 1), so the tracker is the same after a trim |
| RQ2 | The manager | `docs/registry/PLAN.md` row 117 becomes 117a and 117b (section 1). `DESIGN-REGISTRY.md` R-WH14: the format of `TOKEN_KEY` (Q117-1) |
| RQ3 | Slice 113 and 119a | None. `worker/main.roc` has the 4 arms and `bindings` of this slice; the shared files were edited with narrow edits |
| RQ4 | The CLI track (`tln share`) | The wire is `records.Account`. A 401 on `GET /v1/contributors/me` means: log in again. `DELETE /v1/contributors/me` is 204 for an account that has no data |

## 7. Out of scope

| Item | Reason |
| --- | --- |
| R-CT9 "After a key change, the Worker keeps the old public key until the last token that it signed expires" | Out of scope, PLAN G W7 (Q310). The slice supports one key: another `kid` is 401 |
| A missing or bad `TOKEN_KEY`, `CONTRIBUTOR_KEY` or `AUDIENCE`: 500 | The code gives a fault. No W2 case: a case has one set of settings |
| R-CT5 (the cleanup cron), R-CT15 (the trim) | Slice 120 |
| The edge: real D1 error texts, the Ed25519 `sign` on the real edge | W3 |
| The age of `Memo` or a key cache | None is used |

## 8. Questions (TW17)

The design agent answered all 13 questions: section 11 (Q300 to Q312). Two answers changed a proposal (Q117-2, Q117-3). The tests are changed to match.

| Id | Question | Proposal | Pinned by |
| --- | --- | --- | --- |
| Q117-1 | R-CT9, R-WH14: what is the form of the secret `TOKEN_KEY`, and where does the `kid` come from? | The private JWK of an Ed25519 key as JSON text (`kty`, `crv`, `x`, `d`, `kid`). The `kid` is its member. The token header `kid` must be equal. The Worker takes the public key from the same text. Rejected: PKCS#8 in base64 (the `kid` would need a second setting) | W0 `signing_key`, `decode`; W2 all |
| Q117-2 | R-CT9: `iat` and `exp` are NumericDate in seconds, but `tokens_after` is in ms. A token and a revoke in one second? | `iat` and `exp` are seconds with 3 decimals (`1767225601.234`); the compare is in ms; `iat` equal to `tokens_after` is good. Rejected: whole seconds (a login in the second of a revoke gives a token that is refused, or a revoke that does not stop a token of that second) | W0 `seconds_text`, `signing_input`, `check`, `revoked`; W2 `ct9-tokens-after` |
| Q117-3 | R-CT10, R-CT15: `contributor_totals` has `first_time` and no `last_time` (R-RE25). `last_time` of the tracker? | Answer Q302: a new column `last_time`; the tracker takes the larger of the rows and the totals. (The proposal was: the largest `time` of the rows only.) | W2 `ct10-tracker` (a totals-only account) |
| Q117-4 | R-AP37, R-AP51, R-AP46: the form of `github_token` | A text, not empty, at most 512 bytes, each byte `!` to `~` (a CR LF or a space could not go in a header). Else 400. The id of `Talon-Contributor` is checked before the body decode (R-AP70 rows 5, 6) | W0 `login_token`; W2 `ct8-login-refusals` |
| Q117-5 | R-CT8 row 4: which GitHub answers are "GitHub refuses the token" (401) and which are "does not answer" (502)? | Only status 401 is the 401. Every other status (also 403 and 429: a limit is not a refusal of the token), no answer, and a 200 whose body has no `id` above 0 and no `login` are 502 | W0 `github_user`; W2 `ct8-login-refusals` |
| Q117-6 | R-CT9, R-RE17: a good signature, and the account has no `contributors` row (a delete, or never)? | `GET /v1/contributors/me`: 401 (no login to show). `DELETE /v1/tokens`: 401. `DELETE /v1/contributors/me`: 204 (R-AP36: also when nothing was stored; a client may send it again) | W2 `ct9-token-check`, `ct9-tokens-after`, `ct7-delete` |
| Q117-7 | R-AP36, R-CT7: a request with both an `Authorization` header and `Talon-Contributor`, or with neither? | A header `Authorization` is the account form, and the other header is ignored (as R-CT1: a token wins); a bad token is 401 and deletes nothing. Neither header: 400 | W0 `delete_proof`; W2 `ct7-delete` |
| Q117-8 | R-CT8 row 3, R-CT9, R-CT7: what is `tokens_after` of a new row? | The time of the login (not 0). A delete (R-CT7) removes the row; with 0 a later login would make the tokens from before the delete good again. A login never changes `tokens_after` of an existing row | W0 `account_sql` words; W2 `ct8-login`, `ct9-tokens-after` |
| Q117-9 | R-CT11: where is `RL_LOGIN` in the order of the checks, and is the budget shared? | One binding, one budget for `POST /v1/tokens` and `DELETE /v1/contributors/me` (both forms). After every check that needs no D1 call and no GitHub read (the body decode; for the account form the token proof), before the first of them (as Q186). `Retry-After: 60`. The tracker and `DELETE /v1/tokens` have no limit | W2 `ct11-login-limit` |
| Q117-10 | R-AP41, R-AP35: a read session or the primary for the tracker and the token check? | The primary: a revoke must stop a token at once, and the tracker is read just after a login. One batch, 1 D1 call, for each of the 4 routes (the login: after the GitHub read) | W2 `d1-calls` |
| Q117-11 | R-CT9: how does the Worker "keep the old public key until the last token that it signed expires" after a key change? | Not in the design (no setting in R-WH14). This slice supports one key; a token with another `kid` is 401. The manager chooses a setting (for example a JWK Set of old public keys) | None (out of scope) |
| Q117-12 | R-AP37: `Talon-Contributor` is optional. What does a login without it do? | It upserts the account only: no link, no move | W2 `ct8-login` (login 3) |
| Q117-13 | R-AP35, R-AP24: R-AP35 says `no-store`; R-AP24 says each 200 of a `GET` in `/v1` has an `ETag`. | No `ETag`: the answer is personal and not cached | W2 `ct9-token-check`, `ct10-tracker` (`etag` is null) |

## 9. Disputes (from the code agent)

None.

## 10. Verify results

| Step | Result (2026-11-02) |
| --- | --- |
| `roc check` and `roc fmt --check` of `worker/lib/Login.roc`, `worker/LoginRoutes.roc`, `worker/tests/unit/LoginTest.roc`, `worker/lib/Route.roc`, `worker/main.roc` | 0 errors, formatted |
| `MISSING=1 scripts/rules.sh R-CT R-RE17 R-RE18 R-RE25 R-AP35 R-AP36 R-AP37 R-AP38` | No rule is missing |
| `scripts/test.sh wbuild w2` with the stubs | 123 passed, 4 failed (`githubtoken/*`, slice 119a). The 8 `account/` cases did not exist at that run; with the cases and the stubs, `ref.sh` with `NOREF=1` shows 0 of 8 |
| `scripts/test.sh w0` | `LoginTest` 11 of 11 red. The other red tests are `IdentityTest` (slice 113). `unit_modules_check` passes |
| `scripts/test.sh check selftest` | Fail in this tree for `cli/lib/RegistryCache.roc` (the CLI track, not this slice) |
| The reference (`ref.sh all`, after the answers) | W0 11 of 11, W2 `account` 8 of 8. The reference build copy gets the column `contributor_totals.last_time` from `research/slice-117-revert/patch_sql.py` (not in `sql/0001_init.sql`) |
| The stubs (`NOREF=1`, after the answers) | W0 0 of 11, W2 0 of 8 |
| W1 `schema/s1-tables` | Red until the code agent adds the column (8 columns, the row `last_time`). With the column added in a copy: green |
| `MISSING=1 scripts/rules.sh R-CT ...` | No rule is missing. R-CT16 is named in 9 test files |
| The 15 mutations (section 5.2) | All caught. The 5 new ones of the answers: `totals-last-time-rows-only` (`ct10-tracker`), `totals-last-time-keep` and `totals-last-time-incoming` (`ct8-login`), `leeway-0` (W0 `check`, `ct9-token-check`), `limit-before-id` (`ct11-login-limit`). `totals-last-time-incoming` first passed all 8 cases: the order of the `last_time` values in `ct8-login` was changed so that the last merge decides |

## 11. Answers (design agent, 2026-11-02)

The answers are in `DESIGN.md` 9 (Q300 to Q312, "decided 2026-11-02") and in `DESIGN-REGISTRY.md`: the new rule R-CT16 (the account routes: forms, order, edge cases) and edits of R-AP24, R-AP41 row 5, R-RE17, R-RE25, R-CT8 rows 3 and 4, R-CT9, R-CT10, R-CT11, R-CT15 step 1, R-WH14 (`TOKEN_KEY`, `RL_LOGIN`). `docs/registry/PLAN.md` G has the new row W7 (a planned key change). No answer changes the wire form of `records.Account` (`Tracker`, `Token`, `Login`): RQ4 stays as it is. Open: none.

| Id | Design | Answer | Test changes |
| --- | --- | --- | --- |
| Q117-1 | Q300, R-WH14, R-CT9 | Proposal taken: the private Ed25519 JWK text, the `kid` is its member | None |
| Q117-2 | Q301, R-CT9 | Proposal taken (3 decimals, compare in ms, equal is good), with one change: `exp` and an `iat` in the future have a leeway of 60 s (`leeway_s: 60`, as R-TP3 row 3). Reason: the login and the next request can run on two edge machines whose clocks differ, and only the Worker signs, so an `iat` in the future proves nothing. The leeway does not touch the compare with `tokens_after` | `Login.check` doc comment: `leeway_s` 60, so a token is good when `now - 60 < exp` and `iat <= now + 60`. W0 `check`: the edge forms move: `exp` = clock - 60 s is 401, `exp` = clock - 59.999 s is 200; `iat` = clock + 60.001 s is 401, `iat` = clock + 60 s is 200; the `detail` texts say `leeway 60 s`. W2 `ct9-token-check`: "`exp` at the clock" becomes `exp` = clock - 60 s (401); "`exp` 1 ms after the clock" becomes clock - 59.999 s (200); "`iat` 1 ms in the future" becomes clock + 60.001 s (401); add `iat` = clock + 60 s (200). Section 4: the 401 texts of `Oidc.jwt_detail` with `leeway 60 s`. Optional mutation: `leeway-0` |
| Q117-3 | Q302, R-RE25, R-CT10, R-CT15, R-CT8 row 3 | Proposal changed: `contributor_totals` gets `last_time INTEGER NOT NULL` (the largest `time` of the trimmed rows). The tracker takes the larger of the rows and the totals; the login move takes the larger of the two totals rows; the trim (slice 120) sets the larger. So R-CT15 holds. The schema is not deployed: edit `sql/0001_init.sql`, no new migration | `sql/0001_init.sql`: the column after `first_time` (a narrow edit, before the code step, by the test agent with the seeds). W1 `sql/tests/cases/schema/s1-tables/expect.tsv`: 8 columns and the row `contributor_totals last_time INTEGER 1 0 0`. W2 seeds of `ct8-login`, `ct7-delete`, `ct10-tracker`: each `contributor_totals` row gets a `last_time` (at least its `first_time`); `expect/db.tsv` of `ct8-login`, `ct7-delete`, `ct8-login-refusals`: the column. `ct8-login`: the moved totals have the larger `last_time` (make one machine total larger than the account total, so a "keep" or "smaller" mutation fails). `ct10-tracker`: the totals-only account has `last_time` of its totals (not `null`); one account has a totals `last_time` above the largest row `time`. `gen_117.mjs` model and `LoginTest` (the SQL words of `machine_sqls` and `tracker_sql` name `last_time`). Doc comments of `machine_sqls` row 4 and `tracker_sql`. Mutation: `totals-last-time-rows-only`. RQ1 (slice 120): the trim writes `last_time` (R-CT15 step 1) |
| Q117-4 | Q303, R-CT16 rows 1, 2 | Proposal taken | None |
| Q117-5 | Q304, R-CT8 row 4 | Proposal taken | None |
| Q117-6 | Q305, R-CT16 row 4 | Proposal taken | None |
| Q117-7 | Q306, R-CT16 row 7 | Proposal taken | None |
| Q117-8 | Q307, R-RE17, R-CT16 row 5 | Proposal taken | None |
| Q117-9 | Q308, R-CT11, R-CT16 row 9 | Proposal taken. The machine form of the delete counts after its id check | None, if `ct11-login-limit` has a machine-form delete with a bad id that costs nothing; else add one request |
| Q117-10 | Q309, R-AP41 row 5, R-CT16 row 10 | Proposal taken. R-AP41 row 5 now names the exception | None |
| Q117-11 | Q310, R-CT9, PLAN G W7 | Not a gap for P2: one key, another `kid` is 401. A key change is only after a leak, and then the old tokens must stop, so the old key is not kept. The R-CT9 sentence is replaced. A planned change with old public keys by `kid` is PLAN G W7 | None. Section 7 row 1: "out of scope, PLAN G W7" |
| Q117-12 | Q311, R-CT8 row 3 | Proposal taken | None |
| Q117-13 | Q312, R-AP24 | Proposal taken. R-AP24 names the exception. Section 4 says "Q117-14": it is Q117-13 | Section 4 row "200 body of the tracker": `(Q117-13)` |

Rule ids for the tests: the new R-CT16 rows go in the `# R-..` marks of the tests that pin them (`LoginTest` `login_token`, `delete_proof`, `account_sql` words; W2 `ct8-login-refusals`, `ct9-token-check`, `ct7-delete`, `ct11-login-limit`, `d1-calls`). Then `MISSING=1 scripts/rules.sh R-CT` must list no R-CT16.

## 12. Code (green, code agent, 2026-11-02)

Both parts (117a and 117b) are done in one run. No test, no fixture and no design file was changed. Section 9 stays "None".

| File | What | Code lines (no comment, no blank) |
| --- | --- | --- |
| `sql/0001_init.sql` | `last_time INTEGER NOT NULL` after `first_time` in `contributor_totals` (Q302, section 3.1). No new migration | 1 |
| `worker/lib/Login.roc` | All bodies. Extra pure helpers: `RawLogin`, `refused_login`, `base64url` (15 lines, no `roc-base64` in the app header), `user_id` (R-CT16 row 6), `sql_text`, `arity` and `leading_number` (the highest `?n` of a statement: D1 takes as many values as that) | 287 |
| `worker/LoginRoutes.roc` | The 4 handlers and the helpers: `request_proof!`, `proof!`, `limit!`, `limited_response`, `rejected_answer`, `github_user!`, `machine_text!`, `bind`, `run!`, `json_answer`, `no_content`, `forget_account!`, `forget_machine!` | 194 |
| `worker/lib/Route.roc` | 2 lines in `decide` and the helpers `decide_tokens` and `decide_me` (4 routes) | 16 |
| `worker/lib/Client.roc` | `is_write`: `PostTokens`, `DeleteTokens`, `DeleteMe` | 1 |

Decisions that the slice does not fix:

| Item | Choice | Rejected |
| --- | --- | --- |
| The login update of `contributors.last_time` | `MAX(old, new)` (a clock that goes back does not lower it) | `excluded.last_time` |
| Bind of a statement | `bind(sql, values)` takes the first `Login.arity(sql)` values (a `List(Sql)`) | One tuple of 3 values for all (D1 refuses it for a statement with `?1` and `?2` only) |
| `RETURNING` of `revoke_sql` | `CAST(contributor AS TEXT) AS contributor` | `RETURNING *` |
| The GitHub read | `Http.send!` with the token of the user (not `GithubRead.send!`) | `GithubRead.send!` (App token, slice 119a) |
| Base64url | Own 15 lines in `Login.base64url` | A `roc-base64` entry in 3 app headers |

Green results:

| Step | Result |
| --- | --- |
| `node sql/tests/run.mjs` (W1) | 53 passed, 0 failed (`schema/s1-tables` included) |
| `scripts/test.sh w0` | `LoginTest` 11 of 11 pass. 416 of 420 `expect`s pass. The 4 red ones are `WebhookTest` (slice 118b, not mine) |
| `scripts/test.sh wbuild w2` | The 8 `account/*` cases pass. 158 passed, 8 failed: the 8 are `webhook/*` (slice 118b, `queue: trap: todo`). No old case fails |
| `scripts/test.sh check fmt w1` | All pass |
| Revert check (TW12) | Not done in this run (the test agent made the 15 mutations, section 5.2) |

## 12. Revert check (TW12, 2026-11-02)

The code step is green (W0 `LoginTest`, W2 `account/` 8 of 8, the baseline run `none`). Each mutation edits a build copy of `worker/` only (`research/slice-117-revert/run_code_mutations.sh`, `mutations/code.py`, `ref.sh` with `NOREF=1`, `--opt=speed`). `worker/` is not changed. Results: `research/slice-117-revert/mutations/code-results.txt`. Only 10 tricky behaviours; no full sweep.

| Mutation | Change in the copy | Red tests |
| --- | --- | --- |
| `leeway-0` | `leeway_s: 60` to 0 (Q301) | W0 `check`, W2 `ct9-token-check` |
| `revoked-le` | `iat_ms < tokens_after` to `<=` (equal is good) | W0 `revoked`, W2 `ct9-token-check`, `ct9-tokens-after` |
| `tokens-after-zero` | A new account row has `tokens_after` 0 (Q307) | W2 `ct8-login`, `ct8-login-refusals`, `ct9-tokens-after` |
| `login-resets-tokens-after` | The upsert also sets `tokens_after` | W2 `ct8-login`, `ct9-tokens-after` (and a W0 SQL word) |
| `move-last-time-keep` | The login move keeps the `last_time` of the account (Q302) | W2 `ct8-login` |
| `tracker-last-time-rows-only` | The tracker takes `last_time` from the rows only | W2 `ct10-tracker` |
| `github-403-refused` | GitHub 403 and 429 give 401 `GitHub refused the token` (Q304) | W0 `github_user` only (W2 has no 403 case: the 500 case does not reach this) |
| `limit-before-proof` | `DELETE /v1/contributors/me` (account form) counts before the token proof (Q308) | W2 `ct11-login-limit` |
| `kid-unchecked` | The `kid` of the token is not compared with the `kid` of `TOKEN_KEY` (Q300) | W0 `decode`, W2 `ct9-token-check` |
| `is-write-no-deleteme` | `DELETE /v1/contributors/me` is not a write route (`Client.is_write`, Q182) | W2 `ap45-write-routes` |

All 10 caught; none survived. Not checked here: the larger-`last_time` rule of the trim (R-CT15 step 1) is slice 120, not this code.

