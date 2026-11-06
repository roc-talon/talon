# 119a GitHub read token: the installation token for all GitHub reads of the Worker

Phase: P2. Status: review (scope and test agent, 2026-11-02). Model for the code: Sonnet high. Slice 119 (reconcile) needs this slice (PLAN row 119a, Design Q170).

This file is the only link between the test agent and the code agent (TW18). The code agent does not read `research/slice-119a-revert/reference/` (the private reference).

## 1. Scope

Slices 109, 112 and 116a read GitHub with no `Authorization` header (Design Q170). This slice adds one function, `GithubRead.send!`, that adds `user-agent`, `accept` and `authorization` to a GitHub read, and moves the three callers to it. The answers of the three routes do not change: the old W2 cases stay as they are and must pass.

| Part | Who | State |
| --- | --- | --- |
| `worker/lib/GithubApp.roc`: types, constants, signatures. Every function body is `crash "todo"` (the constants have values) | Test agent (signatures), code agent (bodies) | Stubs |
| `worker/GithubRead.roc`: `send!` is `crash "todo"` | Test agent (signature), code agent (body) | Stub |
| `worker/main.roc` (`import GithubRead`), `worker/lib/main.roc` (exposes `GithubApp`), `worker/tests/unit/w0.roc` (`import GithubAppTest`) | Test agent | Done (one line each) |
| `worker/ToolchainRoutes.roc`, `worker/IngestRoutes.roc`, `worker/HintRoutes.roc`: the plain request becomes `GithubRead.send!` (section 3.4) | Code agent | Not done. The test agent does not edit these files: the old cases stay green until the code agent switches them |
| `worker/tests/run.mjs`, `worker/tests/githubapp.mjs`: the settings of the App, the fake token endpoint, `tokens.log`, `auth.log` (section 4) | Test agent | Done |
| Tests: section 5 | Test agent | Red |

Size (TW19): the private reference is about 75 lines of `GithubApp`, 55 lines of `GithubRead` and 14 changed lines in the three callers. One slice.

## 2. Rules

| Rule | Text (short) | Checked by |
| --- | --- | --- |
| R-PU25 (token) | An installation token of the App `Talon Indexer`. The Worker signs an App JWT (RS256, `iat` now - 60, `exp` now + 540, `iss` the app id), asks `POST /app/installations/<id>/access_tokens`, and keeps the token until 5 min before its end (a token lives 1 h). The Worker never uses the token of a user | W0 `jwt_input`, `jwt_text`, `token_url`, `parse_token`, `usable`. W2 `pu25-token-kept`, `pu25-three-routes` |
| R-PU25 (real check) | PASS, 2026-11-02: the App id 5572595 is installed on `roc-talon` with `roc-talon/talon` only (installation id 177657685), contents read and metadata read. The JWT and the token call of `research/github-app-check/check.sh` are the model of the wire form: header `{"alg":"RS256","typ":"JWT"}`, payload `{"iat":..,"exp":..,"iss":<number>}`, `Authorization: Bearer <token>` | W0 `jwt_input`, `read_headers`. W2 (the fake checks the JWT) |
| R-CT12 | The tag list of `roc-talon/talon` is read with the installation token. A failed read gives no tags (key 0, Design Q178) and keeps nothing | W2 `pu25-three-routes`, `pu25-token-faults`, `pu25-missing-key` (and the old `hints/ct12-*`) |
| R-WH14 | The settings `GITHUB_APP_ID` and `GITHUB_APP_KEY` (proposal names), and `GITHUB_APP_INSTALLATION_ID` (Q1, new). `GITHUB_READ_TOKEN` (the fallback) is not used: the check passed | W0 `jwt_input` (BadAppId). W2 `pu25-missing-key` |
| R-AP57 step 3, R-AP68 rows 6 and 10 (reads) | The release read of `PUT /v1/toolchains`, and the repository, release and `.roc-version` reads of the ingest, answer as before. A token fault is a 502 `upstream` (Q4) | W2 `pu25-three-routes`, `pu25-token-faults`, and the old `toolchains/*`, `ingest/*` |
| R-AP48 | A fault of the Worker (a missing setting) is the problem `internal` with the fixed `detail`, no inner state | W2 `pu25-missing-key` |

## 3. What the code agent writes

### 3.1 Files

| File | What |
| --- | --- |
| `worker/lib/GithubApp.roc` | The bodies. The doc comment of each stub is the rule. Reuse `Toolchains.parse_time` for `expires_at` (the same `YYYY-MM-DDTHH:MM:SSZ` form) |
| `worker/GithubRead.roc` | The body of `send!` (section 3.3) |
| `worker/ToolchainRoutes.roc`, `worker/IngestRoutes.roc`, `worker/HintRoutes.roc` | The switch (section 3.4) |
| `worker/lib/main.roc` | Base64: `GithubApp` needs base64url encode (JWT) and standard decode (PEM). Either add the package `base64: "https://github.com/niclas-ahden/roc-base64/releases/download/1.0.2/DQBxATK6BtaCWe56bCmkMgdKJR2Ym8NiZZLhYCAgtLac.tar.zst"` (the URL that roc-jwt uses; `Base64.encode_url`, `Base64.decode`) or write the 40 lines. roc-jwt 0.0.1 has no builder: it gives the signing input of a token that it decodes, not of a new one (its README, "Left out"). So the Worker builds the two parts itself |

### 3.2 The signatures

See `worker/lib/GithubApp.roc` and `worker/GithubRead.roc`. In short:

| Function | Signature |
| --- | --- |
| `GithubApp.jwt_input` | `{ app_id : Str, now_ms : U64 } -> Try(Str, [BadAppId])` |
| `GithubApp.jwt_text` | `{ input : Str, signature : List(U8) } -> Str` |
| `GithubApp.token_url` | `Str -> Str` |
| `GithubApp.parse_token` | `Str -> Try(GithubApp.Token, [BadAnswer])` |
| `GithubApp.usable` | `GithubApp.Token, U64 -> Bool` |
| `GithubApp.pkcs8_of_pem` | `Str -> Try(List(U8), [NotPem, Pkcs1])` (Q2) |
| `GithubApp.uses_token`, `read_headers` | `Str -> Bool`, `{ url : Str, token : Str } -> List((Str, Str))` (Q3) |
| `GithubApp.failure_class` | `GithubApp.Failure -> [Upstream(Str), Fault(Str)]` (Q4) |
| `GithubRead.send!` | `Request => Try(Response, [NoAnswer, Token(GithubApp.Failure)])` |

`GithubApp.Failure` is `[NoSetting(Str), BadSetting(Str), SignFailed, TokenStatus(U16), TokenNoAnswer, TokenBad]`.

### 3.3 The flow of `GithubRead.send!`

| # | Step |
| --- | --- |
| 1 | `url = request.url()`. When `GithubApp.uses_token(url)` is false: add `GithubApp.read_headers({ url, token: "" })` (the user agent only), send with `Http.send!`, and map a send fault to `NoAnswer`. No token is read or asked |
| 2 | The token: a `Memo` of the type `GithubApp.Token` (suggested name `github-read-token`, `max_age_ms` 3,600,000: the life of a token). Platform 0.0.2 checks the age of a `Memo` entry on the shim clock, which is the real clock in W2 (`worker/tests/worker-test.js`), not the clock of the case. So the 5 min rule must be checked in Roc: `GithubApp.usable(held, Time.now_ms!())`. When the held token is not usable: `cache.clear!()` and load again. The test `pu25-token-kept` pins this with the clock of the case |
| 3 | The loader, in this order. (a) `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID` (`Env.var!`), `GITHUB_APP_KEY` (`Env.secret!`): a missing one is `NoSetting(<name>)`. (b) `GithubApp.pkcs8_of_pem` (an error is `BadSetting("GITHUB_APP_KEY")`), `GithubApp.jwt_input` with `Time.now_ms!()` (`BadAppId` is `BadSetting("GITHUB_APP_ID")`). (c) `WebCrypto.sign!({ alg: RsaPkcs1(Sha256), key: Pkcs8(der), data: input.to_utf8() })` (an error is `SignFailed`), `GithubApp.jwt_text`. (d) `POST GithubApp.token_url(installation)` with an empty body and the headers `user-agent`, `accept` (`GithubApp.user_agent`, `GithubApp.accept`) and `authorization: Bearer <jwt>`. A send fault is `TokenNoAnswer`. A status other than 201 is `TokenStatus(status)` (401, 403, 404, 500 and the others; GitHub answers 201). A body that `parse_token` refuses is `TokenBad` |
| 4 | A failed load keeps nothing: the next read asks again. There is no negative cache (Q5 asks if there should be) |
| 5 | The headers of the read: `GithubApp.read_headers({ url, token })`, then `Http.send!`. The status is not checked here |

### 3.4 The switch of the three callers

| File | Plain request today | Change |
| --- | --- | --- |
| `ToolchainRoutes.read_release!` | `Request.get(release_url).with_header("user-agent", ..).with_header("accept", ..)`, `Http.send!` | `GithubRead.send!(Request.get(release_url))`. `NoAnswer` is `Refuse(Toolchains.github_no_answer)`. `Token(f)`: `GithubApp.failure_class(f)`: `Upstream(d)` is `Refuse(Problem.new(Upstream, d))`, `Fault(t)` is `Fault(t)` |
| `IngestRoutes.github!` (3 reads: repository, release, `.roc-version`) | `Request.get(url).with_header("user-agent", ..)`, with `accept` for the API | `GithubRead.send!(Request.get(url))`. The parameter `api` is not needed any more (the headers come from the URL). `NoAnswer` is `Refuse(Ingest.github_no_answer(what))`. `Token(f)`: as above |
| `HintRoutes.load_tags!` | `Http.send!(Request.get(Hints.tags_url).with_header("user-agent", ..))` | `GithubRead.send!(Request.get(Hints.tags_url))`. `NoAnswer` and `Token(_)` are `NoTags` (no tags, key 0, nothing kept in the tag `Memo`) |

The asset download of the ingest (`github.com/.../releases/download/...`, `Archive`) is not a call of this slice and does not change.

## 4. The W2 runner (done by the test agent)

`worker/tests/run.mjs` and `worker/tests/githubapp.mjs`. The key is a throwaway RSA 2048 key made at the start of each run with Node `crypto`; the real key in `~/.config/talon-indexer/` is never read.

| Item | How |
| --- | --- |
| Settings of each case | `GITHUB_APP_ID` 123456, `GITHUB_APP_INSTALLATION_ID` 654321, `GITHUB_APP_KEY` the PKCS#8 PEM of the test key. `settings.json` of a case can change one; the value `null` removes it |
| Fake token endpoint | `POST https://api.github.com/app/installations/<id>/access_tokens`. A wrong installation id is a 404 and a failure of the case. It checks the JWT: `Bearer` form, RS256 header exactly `alg` and `typ`, payload exactly `iat`, `exp`, `iss`, `iss` the id as a number, `iat` now - 60, `exp` now + 540 (`now` is the clock of the request), and the signature with the public key. A bad JWT is a 401 and a failure of the case. A good request gets the n-th token `ghs_test<n>` valid for 1 h from the clock of the request (status 201). A file `github/api.github.com/app/installations/<id>/access_tokens` in a case (with `.meta.json` and `.<n>`) gives the answer in its place, after the JWT check |
| `expect/github.log` | The token request is not in it. The old cases do not change |
| `expect/tokens.log` (optional) | One line for each token request: `POST <url> now=<s> ua=<user-agent> accept=<accept>` |
| `expect/auth.log` (optional) | One line for each other request to `api.github.com`: `METHOD <url> token=<none or n or bad> ua=<user-agent> accept=<accept>` (`n`: exactly `Bearer ghs_test<n>`). Other hosts are not in it (Q3) |
| Key form | One constant, `KEY_FORM`, in `githubapp.mjs` (Q2) |

## 5. Tests

| Layer | Case | Rules |
| --- | --- | --- |
| W0 | `worker/tests/unit/GithubAppTest.roc`, 30 `expect`s: `jwt_input` (6 vectors from python: ids of 1, 2, 6 and 7 digits for the 4 base64 padding classes, a time with ms, a later time; 8 ids refused); `jwt_text` (4 signatures, the `-_` alphabet, no padding); `token_url`; `parse_token` (the real answer shape, order of members, 12 bad answers); `usable` (7 times around the 5 min edge, 1 s each side; 3 edge values of the sum); `uses_token` (11 URLs: the API, the raw host, the download host, 4 look-alike hosts, `http`, an upper-case host); `read_headers` (3); `failure_class` (7); `pkcs8_of_pem` (Q2: a real 1024-bit key by length, head, tail and a weighted sum; CR LF; no final end of line; PKCS#1; 5 texts that are not PEM) | R-PU25, R-WH14, R-CT12 |
| W2 | `githubtoken/pu25-three-routes`: `PUT /v1/toolchains/<tag>`, `POST /v1/releases` (an ingest) and `POST /v1/compat` (a hint) in one isolate. One token request (`tokens.log` has 1 line, at the first request), and the 4 API reads (release, repository, release of the repository, tag list) carry `token=1` with the user agent and `accept`. The answers are those of the old cases (201, 201, 201 with the DB row of the hint with key 17180000255) | R-PU25, R-CT12, R-WH14, R-AP57, R-AP68, R-AP10 |
| W2 | `githubtoken/pu25-token-kept`: 5 `PUT`s of 5 tags at 30 s, 54 min, 56 min, 86 min and 112 min. The token is asked at 30 s, 56 min and 112 min (the 5 min mark of token 1 is at 55 min 30 s, of token 2 at 111 min), and reads at 54 min and 86 min use the held token. Each JWT is checked with its own clock | R-PU25 |
| W2 | `githubtoken/pu25-token-faults`: a hint, 2 `PUT`s, an ingest and a `PUT` with token answers 401, 403, a 201 with a body that is not a token, 500 and a good token; then a hint. The first hint is stored with the key 0, the 3 routes answer 502 `upstream` with the detail of Q4, nothing is kept after a failure (a token request for each of the first 5 requests), the good token is kept (the last hint has no token request and gets the key of `0.4.1`) | R-PU25, R-CT12, R-AP57, R-AP68 |
| W2 | `githubtoken/pu25-missing-key`: `GITHUB_APP_KEY` is not set. `PUT` and ingest answer 500 `internal` with the fixed detail and no GitHub call after the OIDC key read; the hint is stored with key 0 and reads no tag list. No token request | R-WH14, R-PU25, R-AP48, R-CT12 |
| W2 runner | `runner/r-pu25-auth-log` (the `auth.log` form with no token), `selftest/wrong-auth-log`, `selftest/wrong-tokens-log` (the two logs are compared) | R-PU25 |
| W2 old | All old cases stay as they are. After the switch they must pass: `toolchains/*`, `ingest/*`, `hints/*`. They now run with the settings of the App and a fake token endpoint | R-AP57, R-AP68, R-CT12 |

The case files are made by `research/slice-119a-revert/gen-cases.py` (the expected answers of the old routes are copied from the old cases, not from the reference).

### 5.1 Red results (2026-11-02, the stubs)

| Step | Result |
| --- | --- |
| W0 (`roc test` of `GithubAppTest`) | 30 `expect`s, 0 pass, all `todo`. 0 compiler errors. `roc check main.roc`, `roc fmt --check`: pass |
| W2 `githubtoken` (stub build, the callers still plain) | 0 of 4 pass. `pu25-three-routes`, `pu25-token-kept`: `tokens.log` is empty and every API read is `token=none`. `pu25-token-faults`: 200/201 in place of 502, `tokens.log` empty. `pu25-missing-key`: 201 in place of 500 |
| W2 `runner` | The new case passes. The 2 new selftests fail as they must (checked by the runner) |
| Old W2 | Not changed by the stubs. With the private reference, 116 of 127 cases pass; the 11 failures are `archive/*` (6, the copy has no `archive-test.wasm`) and `identity/*` (5, slice 113 in work) |

### 5.2 Private reference and revert check

`research/slice-119a-revert/reference/` and `ref.sh [w0|w2|all]` (`KEEP=1` reuses the last build; `MUTATE=mutations/mN.py`). With the reference: W0 30 of 30, W2 `githubtoken` 4 of 4. The build is `--opt=speed`.

| Mutation | What | Caught by |
| --- | --- | --- |
| m1 | `usable` ignores the 5 min | W0 `usable` (2 expects); W2 `pu25-token-kept` also |
| m2 | `exp` is now + 600 | W0 `jwt_input`; the fake of W2 in every case that asks a token |
| m3 | `iat` is now (not now - 60) | W0 `jwt_input`; the same fake check |
| m4 | `authorization: token <t>` in place of `Bearer` | W0 `read_headers`; W2 `auth.log` (`token=bad`) |
| m5 | A token request on each read (no `Memo`) | W2 `pu25-three-routes`, `pu25-token-kept`, `pu25-token-faults` |
| m6 | The expired token is not cleared (the `Memo` keeps it) | W2 `pu25-token-kept` only |
| m7 | `HintRoutes` stays plain | W2 `pu25-three-routes`, `pu25-token-faults`, `pu25-missing-key` |
| m8 | A missing setting is `Upstream` (502) in place of `Fault` (500) | W0 `failure_class` (the text of Q4); W2 `pu25-missing-key` would also |
| m9 | The token URL uses the app id | W2 (3 of 4 cases: the installation id is wrong) |
| m10 | The token status is not checked | W2 `pu25-token-faults` (detail `status 403` becomes `answer is not valid`) |
| m11 | `uses_token` is true for any `https://` URL (the token goes to the raw host) | W0 `uses_token`, `read_headers` only. W2 does not log the raw host (Q3) |

All 11 are caught. The scripts are in `research/slice-119a-revert/mutations/`, the logs of the W2 runs in `research/slice-119a-revert/red/`.

## 6. Output (proposed, TW24)

| Item | Proposal |
| --- | --- |
| 502 `upstream` `detail`, token status | `the GitHub installation token request failed with status <s>` |
| 502 `upstream` `detail`, no answer | `the GitHub installation token request failed: no answer` |
| 502 `upstream` `detail`, bad answer | `the GitHub installation token answer is not valid` |
| `GithubApp.Fault` texts (log only; the route answers the fixed `internal` text of R-AP48) | `the setting <name> is not set`, `the setting <name> is not valid`, `the JWT of the App cannot be signed` |
| Headers of an API read | `user-agent: talon-registry`, `accept: application/vnd.github+json`, `authorization: Bearer <token>`, in this order. Another GitHub host: `user-agent` only |
| Header names of the settings | `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID` (new), `GITHUB_APP_KEY`. The table of R-WH14 needs the new row |

## 7. Questions (answered, see 7.1)

The tests above are written for the proposal of each question, so the code agent can start. If the human answers another way, the listed files change. Nothing here is a new fact in a design file.

| # | Question | Proposal | If another answer |
| --- | --- | --- | --- |
| Q1 | The source of the installation id is not in R-PU25. | A setting `GITHUB_APP_INSTALLATION_ID` (the real value is 177657685). `cloudflare-workers/API.md` RN18 already says "Settings: the App id and the installation id". No extra GitHub call, no second `Memo`, and no org name in the code. R-WH14 needs the row | Option B: `GET /orgs/roc-talon/installation` with the App JWT at first use, kept in `Memo`. One more request, one more fake route, `auth.log` unchanged. `githubapp.mjs` settings, `GithubRead` step 3, and the 4 cases (`tokens.log` would hold the lookup) change |
| Q2 | The form of the secret `GITHUB_APP_KEY`. GitHub gives a PKCS#1 PEM (`BEGIN RSA PRIVATE KEY`). WebCrypto imports PKCS#8 only (`API.md` RN9 says "PKCS#8 key"). The design does not say what the secret holds | The secret is a PKCS#8 PEM (`BEGIN PRIVATE KEY`). The operator converts the key once: `openssl pkcs8 -topk8 -nocrypt -in app.pem`. A PKCS#1 PEM is `BadSetting("GITHUB_APP_KEY")` (500, the log text names the setting) | Option B: accept both; the Worker wraps PKCS#1 in a PKCS#8 header (a fixed prefix and two length fields, about 25 lines, one more vector from `openssl`). Option C: a JWK text. W0 `pkcs8_of_pem` (the last 4 expects) and `KEY_FORM` of the runner change |
| Q3 | Which reads get the token? R-PU25 counts the 5000 an hour for the REST API. The `.roc-version` read is `raw.githubusercontent.com`, and the asset is `github.com` | Only a URL that starts with `https://api.github.com/` (`uses_token`). The raw read keeps the user agent only, as today. The token is never sent to another host, also by a typing trick (`api.github.com.evil.example`, `api.github.com@evil.example`) | The raw read with the token: `uses_token` and `read_headers` (W0). W2 does not pin it (the raw host is not in `auth.log`) |
| Q4 | What a missing token does to a route. R-AP48 gives 500 for a fault of the Worker and R-AP21 gives 502 `upstream` for "a read from GitHub failed". Q178 gives key 0 for a failed tag read | A missing or bad setting, or a sign fault: `Fault` (500 `internal`, fixed detail). A token request that fails (401, 403, 404, 5xx, no answer, a body that is not a token): 502 `upstream` with the detail of section 6. The hint path: key 0 for every kind | One class for all: `failure_class` (W0, 7 expects) and `pu25-missing-key` (2 answers), `pu25-token-faults` (details) change |
| Q5 | A read with a held token that GitHub refuses (401: the App was uninstalled or the key was rotated, so the token is dead before its end), and a token request that fails each time | No special handling in this slice. The read answers as today (502 with `status 401`), the dead token stays until 5 min before its end (at most 55 min), and a failed token request is asked again by the next read (no negative cache; the 5000 an hour is not at risk at this rate) | A `clear!` on 401 of a read (one branch, one case), or a short negative cache (a `Memo` of the failure). Not tested now |
| Q6 | `iss` of the JWT: GitHub accepts the app id or the client id | The app id as a JSON number, the form of `check.sh` that GitHub accepted (R-PU25 result). `GITHUB_APP_ID` is digits only; a client id (`Iv23...`) is `BadSetting` | The client id as a text: `jwt_input` and the check of the fake change |

### 7.1 Answers (design agent, 2026-11-02)

All 6 proposals are taken. No test, stub or runner file changes. Design: Registry R-PU41 to R-PU44, R-WH14 (new row and deploy note), R-AP21 (`upstream` row), R-CT12; Design Q280 to Q285.

| # | Answer | Reason | Design |
| --- | --- | --- | --- |
| Q1 | Setting `GITHUB_APP_INSTALLATION_ID` | No extra call, no second `Memo`, no org name in code. RN18 already names it | Q280, R-PU41, R-WH14 |
| Q2 | PKCS#8 PEM. A PKCS#1 PEM is `BadSetting("GITHUB_APP_KEY")`. The operator converts once: `openssl pkcs8 -topk8 -nocrypt -in app.pem -out app.pkcs8.pem` (deploy note for slice 121, in R-WH14) | GitHub gives PKCS#1 and WebCrypto `importKey` takes PKCS#8 or JWK only. A wrap in the Worker is code for a step that runs once | Q281, R-PU41, R-WH14 |
| Q3 | Only `https://api.github.com/`. The raw read and the asset download get the user agent only | A public repository needs no token on the raw host. A token there only adds leak risk. The 5,000 an hour are for the REST API | Q282, R-PU42 |
| Q4 | Setting or sign fault: 500 `internal`. Failed token request: 502 `upstream` with the 3 details of section 6. Hint: key 0 for all | The operator fixes a setting, a client cannot. A failed token request is a read from GitHub that failed (R-AP21) | Q283, R-PU43 |
| Q5 | No special handling and no negative cache | An early dead token needs an uninstall, and then no read can pass. The rate limits bound the retries | Q284, R-PU44 |
| Q6 | `iss` is the app id as a JSON number, digits only | The GitHub docs accept the client id or the app id (the client id is the recommended one). The real check passed with the app id | Q285, R-PU41 |

Facts checked: the GitHub JWT page says `iss` is "the client ID or application ID", `exp` is at most 10 min ahead, and `iat` should be 60 s in the past. It does not name the key format.

## 8. Out of scope

| Item | Reason |
| --- | --- |
| The `x-ratelimit-*` reserve (10 %, move `next_check_at`) | PLAN row 119a: it can stay in 119 (the reconcile owns `next_check_at`) |
| The exact edge `now + 5 min == expires_at` | The design does not fix it ("until 5 min before its end"). The tests use 1 s on each side |
| Two requests at the same time that both load a token | `Memo` allows it (`MODULES.md` 9): both tokens are valid. No test |
| The expiry of the entry by the `Memo` clock | W2 has the real clock for `Memo`. The Roc check of `usable` is the rule; the `max_age_ms` of the `Memo` is an upper bound only |
| A real GitHub call and the real key | W3 (the user), not W2. The real check is `research/github-app-check/` |
| The asset download of the ingest and any new GitHub read | Not a call of the three plain requests |
| `GITHUB_READ_TOKEN` (the fallback of R-PU25) | The P2 check passed; the secret stays unused |

## 9. Disputes (from the code agent)

None. No test, case or runner file was changed.

## 10. Code and green results (code agent, 2026-11-02)

| Item | Result |
| --- | --- |
| `worker/lib/GithubApp.roc` | 180 lines (stubs were 76). All 10 bodies. Own base64url encode and standard decode (about 45 lines): no new package, so `lib/main.roc` is not changed. `parse_token` reads `Json.parse` into `{ token, expires_at }` and uses `Toolchains.parse_time` |
| `worker/GithubRead.roc` | 65 lines (stub was 15). `Memo` `github-read-token` (3,600,000 ms); the 5 min rule is `GithubApp.usable(held, Time.now_ms!())`, else `clear!` and load again. The loader follows section 3.3 |
| Callers | `ToolchainRoutes.read_release!`, `IngestRoutes.github!` (parameter `api` removed), `HintRoutes.load_tags!` use `GithubRead.send!`. `token_error` in the first two maps `failure_class` (`Upstream` to `Refuse`, `Fault` to `Fault`). The hint path maps any fault to `NoTags`. About 30 lines changed. The `pf.Http` import is removed from the three files |
| W0 | All 30 `expect`s of `GithubAppTest` pass. Other W0 failures are the red tests of slices 114, 117 and 118 |
| W2 | `githubtoken` 4 of 4 pass. `toolchains/*`, `ingest/*`, `ingest-limits/*`, `identity/*`, `hints/*`, `archive/*`, runner and selftest cases pass: 134 pass. 12 fail: `account/*` (8, slice 117) and `publish/*` (4, slice 114), not this slice |
| `check`, `fmt`, `w1` | pass |
| `wbuild` | The `--opt=speed` build of `app.wasm` succeeded (125 s). The step reports FAIL only for the `wrangler.toml` check: `[[queues.producers]] INDEX` is missing (slice 118, not this slice) |

Decision not fixed by the slice: `jwt_input` parses the id with `U64.from_str` and writes it back, so a very long id (over 20 digits) is `BadAppId`. A negative `iat` is not possible: `iat` is 0 when `now_ms` is under 60 s. `usable` is written as a subtraction, because the test `now_ms = U64.highest` overflows the sum. Revert check: not done (the test agent holds the 11 mutations, section 5.2).
