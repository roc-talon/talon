# 108b The OIDC token code on roc-jwt

Phase: P2. Status: green (code, 2026-11-02). Model for the code: Sonnet high. Plan row: `docs/registry/PLAN.md` A.1 (`roc-jwt` 0.0.1) and D, row W2. Follows slice 108 (`docs/slices/108-oidc.md`).

## 1. Scope

The token form, base64url, the JWKS parse, the key select and the registered claim checks of `worker/lib/Oidc.roc` and `worker/Auth.roc` move to the generic package `roc-jwt` 0.0.1 (Design R-PK9). Talon keeps its own rules: `bearer`, the `kid` that Talon requires, the `alg` RS256, the strict claim types of `Oidc.Claims`, the leeway of 60 s, no `iat` check, R-TP7, R-TP3 rows 4 to 8, R-TP16, and each `detail` text of slice 108 (R-AP21, R-AP26).

| Part | Who | State |
| --- | --- | --- |
| `jwt:` release URL in the headers of `worker/main.roc`, `worker/lib/main.roc`, `worker/tests/unit/w0.roc` | Test agent | Done (one line each, R-GP3) |
| New stubs in `worker/lib/Oidc.roc`: `Token`, `KeySet`, `algs`, `decode`, `key_for`, `check_registered`, `jwt_problem` | Test agent (signatures, doc), code agent (bodies) | `crash "todo"`. The old items stay until the code agent switches `Auth.roc`, so the W2 cases of slices 108 and 109 run as before. |
| Switch `worker/Auth.roc`, delete the old items of `Oidc.roc` (section 3.2) | Code agent | To do |
| W0 `OidcTest.roc` (section 4.1), W2 `oidc/tp3-jwt-strict` (new) | Test agent | Red |

The wire result does not change for the 7 W2 cases of slices 108 and 109: they are not changed, and they pass with the private reference.

## 2. Rules

| Rule | Text (short) | Checked by |
| --- | --- | --- |
| R-PK9, R-GP3 | Talon uses `roc-jwt` by its release URL | The headers (`roc check`, W0 build), W2 `tp3-jwt-strict` (it fails until the switch) |
| R-GP5 | Talon does not test `roc-jwt` again. It tests its own use: the options and rules that it gives, the Talon rules around it, the map of each error | W0 rows of section 4.1 |
| R-TP3 row 1 | RS256 only, the `kid`, the JWKS key | W0 `decode`, `key_for`, `jwt_problem`. W2 `tp3-token-form`, `tp3-signature-and-kid`, `tp3-jwt-strict` |
| R-TP3 rows 2, 3 | `aud`, `exp`, `nbf` with 60 s, no `iat` | W0 `check_registered`. W2 `tp3-tp7-claims`, `tp3-jwt-strict` |
| R-TP16 | The kept JWKS: 1 h, 60 s for a key that is not there | W0 `key_for`. W2 `tp3-key-rotation`, `tp3-jwks-max-age` |
| R-AP21, R-AP26 | 401 with the `detail` of slice 108 | W0 `jwt_problem` (each `Jwt.Error`) |
| R-TP1, R-TP4, R-TP6, R-TP7, R-MX5 | Talon rules, not changed | W0 rows of slice 108 (kept) |

## 3. What the code agent writes

### 3.1 Public signatures (in the stubs, fixed)

| Item | Type | Rule (the doc comments have the details) |
| --- | --- | --- |
| `Oidc.Token` | `{ kid : Str, header : Jwt.Header, registered : Jwt.Claims, claims : Oidc.Claims, signing_input : List(U8), signature : List(U8) }` | |
| `Oidc.KeySet` | `{ fetched_ms : U64, jwks : Str }` | The value of the `Memo`: the JWKS text that `Jwk.parse_set` accepted, and the time of the read. Not a `List(Jwk.Key)` (section 9, P1). |
| `Oidc.algs` | `List(Jwt.Alg)` = `[RS256]` | Given |
| `Oidc.decode` | `Str -> Try(Oidc.Token, Problem)` | `Jwt.decode(text, Jwt.Options.{ algs })`, then the `kid`, then `Jwt.claims_as` into `Oidc.Claims` |
| `Oidc.key_for` | `Oidc.KeySet, Jwt.Header, U64 -> [Use(Jwk.Key), Reload, Refuse(Problem)]` | The age rules of R-TP16, with `Jwk.select` over `Jwk.parse_set(keys.jwks)` |
| `Oidc.check_registered` | `Jwt.Claims, { audience : Str, now_ms : U64 } -> Try({}, Problem)` | `Jwt.check` with `aud` `OneOf([audience])`, `iss` `OneOf([issuer])`, `leeway_s` 60, `require` `[Iss, Aud, Exp, Nbf]`, and `iat` set to `Err(Missing)` |
| `Oidc.jwt_problem` | `Jwt.Error, Str -> Problem` | The table of the doc comment (section 5) |

### 3.2 The switch (code agent)

| File | Change |
| --- | --- |
| `worker/Auth.roc` | `import jwt.Jwk`. `jwks : Memo(Oidc.KeySet)`. `verify!`: `Oidc.decode`, `Oidc.key_for` (both calls, with `jwt.header`), `WebCrypto.verify!` with `Jwk(Jwk.to_public_json(key))` and `signing_input`, `Oidc.check_registered(jwt.registered, ...)`. `load!`: `Jwk.parse_set(text)` must accept the text (else 502 `Oidc.jwks_bad`), then keep `{ fetched_ms: Time.now_ms!(), jwks: text }`. The order of the steps of slice 108 (section 3.3 there) stays. |
| `worker/lib/Oidc.roc` | Delete the items that the new ones replace: `Jwt`, `Key`, `Cached`, `Header`, `Jwk` (the record type), `base64url`, `base64_value`, `base64_group`, `parse`, `parse_parts`, `decode_text`, `parse_jwks`, `rsa_key`, `find_key`, `key_step`, `jwk_text`, `check_token`. Keep `not_jwt` (`decode` uses it). No test uses the deleted items. |

Size: the reference has about 75 lines of new body and deletes about 150 lines.

## 4. Tests

### 4.1 W0 `worker/tests/unit/OidcTest.roc` (18 `expect`s, was 21)

| Row (slice 108) | State | Reason |
| --- | --- | --- |
| `bearer`, `missing_token`, `unknown_kid` and `bad_signature`, `check_bot` (2), `check_publish` (2), `binding_ok` | Kept, not changed | Talon rules |
| `base64url` (2 `expect`s) | Removed | They test `roc-jwt` code only (its D3) |
| `parse_jwks` and `find_key` | Removed | `Jwk.parse_set` is `roc-jwt` code (K1, K2). The Talon use of it is in the new `key_for` row. |
| `jwk_text` | Removed | `Jwk.to_public_json` is `roc-jwt` code (K5) |
| `parse` (4 `expect`s) | Changed to `decode` | The same inputs and the same answers. New inputs: `aud` as a list, `exp` with a fraction (Talon claim types), `crit`, a signature `Zh` that is not canonical, a token of more than 8192 bytes, `alg` RS384. They check the options that Talon gives and the map to the old texts. |
| `key_step` | Changed to `key_for` | The same 13 age rows, now with a `Jwt.Header`. New: keys with the right `kid` that do not fit RS256 (an EC key, an RSA key for RS384, an RSA key for `enc`) are no key: 401, or a read again after 60 s. |
| `check_token` (4 `expect`s) | Changed to `check_registered` | The same rows on `Jwt.Claims` |
| New: `check_registered` and `iat` | New | An `iat` in the future, no `iat`, and an `iat` after the `nbf` bound: all pass (R-TP3 row 3 names `exp` and `nbf` only) |
| New: `jwt_problem` | New | Each `Jwt.Error` (25 rows) to its 401 and `detail` |

### 4.2 W2

| Case | Checks | Rules |
| --- | --- | --- |
| `oidc/tp3-jwt-strict` (new) | A signature `Zh` (not canonical base64url): 401 `the token is not a valid JWT`. A token of more than 8192 bytes: the same 401. A token with an `iat` in the future: 200. A good token: 200. With the code of slice 108 the first gives `the token signature is not valid` and the second 200: so the case shows the switch. | R-TP3, R-PK9, R-AP21, R-AP26 |
| The 7 `oidc/*` cases of slices 108 and 109 | Not changed. They must pass after the switch. | As before |

The case is written by `research/slice-108b-revert/mk_case.py`. Its `seed.sql` and its 200 answer come from `oidc/tp7-bot-token-pass` (slice 109).

### 4.3 Red results (2026-11-02)

| Step | Result |
| --- | --- |
| `scripts/test.sh w0` | `OidcTest`: 10 of 18 fail, each with `todo` (the rows of `decode`, `key_for`, `check_registered`, `jwt_problem`). The 20 failures in `CompatTest` and `CompatReadsTest` are slice 115 (in progress, another agent). |
| `scripts/test.sh w2` | `oidc/tp3-jwt-strict` fails: `request 1: problem.detail: expected "the token is not a valid JWT", got "the token signature is not valid"`, `request 2: status: expected 401, got 200`. The other 7 `oidc/*` cases pass. The 7 `compat/*` failures are slice 115. |
| `scripts/test.sh check fmt` | Pass. `roc check worker/main.roc`: 0 errors. |

### 4.4 Revert check (private reference)

`research/slice-108b-revert/reference/` has the switched `Auth.roc` and `Oidc.roc`. `ref.sh all` runs `OidcTest` and the `oidc` W2 cases on a copy: 18 of 18 and 8 of 8 pass. `ref.sh w2 router runner toolchains selftest oidc`: 58 of 58 pass. `MUTATE=mutations/<m>.py ref.sh all` runs one mutation.

| Mutation | Caught by |
| --- | --- |
| m1 the `alg` allowlist also has RS384 | W0 |
| m2 no leeway in `Jwt.check` | W0, W2 `tp3-tp7-claims` |
| m3 the `iat` of the token goes to `Jwt.check` | W0, W2 `tp3-jwt-strict`, `tp3-tp7-claims` |
| m4 `aud` `Any` | W0, W2 `tp3-tp7-claims` |
| m5 the key by `kid` only (a key of the wrong `kty` with the right `kid` is used) | W0 |
| m6 an expired token gets the text of `Jwt.err_to_str` | W0, W2 `tp3-tp7-claims` |
| m7 `nbf` not required | W0 |
| m8 a token with no `kid` accepted | W0, W2 `tp3-token-form` |
| m9 `max_token_bytes` 100000 | W2 `tp3-jwt-strict` |
| m10 a fault of `Jwt.claims_as` ignored (`aud` as a list passes) | W0 |

## 5. Output (proposed, TW24)

The texts of slice 108 stay. The errors that `roc-jwt` adds get the texts below. All are 401 `unauthenticated`.

| `Jwt.Error` | `detail` |
| --- | --- |
| `TooLong`, `NotCompact`, `BadBase64`, `BadUtf8`, `BadJson`, `CritUnsupported`, `EmptySignature`, `BadSignatureLength` | `the token is not a valid JWT` (as slice 108 for a bad form) |
| `AlgMissing`, `AlgNone`, `AlgNotAllowed` | The texts of slice 108 |
| `MissingClaim`, `WrongIssuer`, `Expired`, `NotYetValid` | The texts of slice 108. `exp` and `nbf` are whole seconds, rounded down. |
| `WrongAudience(values)` | `token claim aud is "<v>", expected "<AUDIENCE>"`. More values (no path gives them now): each quoted, joined with `, ` |
| `WrongSubject(sub)` | `token claim sub is "<sub>"` (no path gives it: Talon gives `sub` `Any`) |
| `IssuedInFuture` | `token claim iat is <iat>: the token is issued in the future (now is <now>, leeway <leeway> s)` (no path gives it) |

## 6. Wire changes (only for tokens or JWKS that GitHub does not send)

| Input | Before (slice 108) | After |
| --- | --- | --- |
| A token of more than 8192 bytes | Accepted | 401 `the token is not a valid JWT` (Q108b-1) |
| A header with `crit` | Accepted | 401 `the token is not a valid JWT` |
| A part that is not canonical base64url (`Zh`) | Read | 401 `the token is not a valid JWT`, with no JWKS read |
| A JWKS key with the `kid` of the token and an `alg` other than RS256, or `use` other than `sig` | Used for the verify | No key: 401 `the token kid "<kid>" is not in the GitHub JWKS`, or a read again after 60 s |
| An `exp` or `nbf` with a fraction | 401 `the token is not a valid JWT` | The same (the Talon claim type `U64`) |
| `aud` as a list | 401 `the token is not a valid JWT` | The same (the Talon claim type `Str`, Q108b-2) |

## 7. Out of scope

| Item | Reason |
| --- | --- |
| The tests of `roc-jwt` itself (D1 to D11, C1 to C9, K1 to K6) | R-GP5: in its own repository |
| `Jwt.Error` values that no Talon path gives (`WrongSubject`, `IssuedInFuture`, `WrongAudience` with 2 values) | Only the map row in W0 |
| The JWT of the registry (R-CT9, EdDSA) | Slice 117 can use `roc-jwt` too |

## 8. Questions (stop until answered)

| Id | Question | Options | Effect now |
| --- | --- | --- | --- |
| Q108b-1 | The Worker now refuses a token of more than 8192 bytes (the default `max_token_bytes` of `roc-jwt`). The design has no limit. GitHub OIDC tokens are about 1 to 2 KB. | (a) 8192 (the default, as tested); (b) another limit | W0 `decode` row, W2 `tp3-jwt-strict` request 2 |
| Q108b-2 | `roc-jwt` reads `aud` as a text or a list (RFC 7519). Slice 108 refuses a list (401). Keep that? | (a) Keep: no wire change (as tested); (b) accept a list that has `AUDIENCE` | W0 `decode` row (`aud_list`) |

Answers (decided 2026-11-02): Q108b-1 is (a), Design Q137, Registry R-TP16. Q108b-2 is (a), Design Q138, Registry R-TP16. No test row changes. The wire table in section 6 stays as it is.

## 9. Platform issues

| # | Issue | Evidence |
| --- | --- | --- |
| P1 | A `Memo` of a value that does not come back from its CBOR form reads again on each `get!`, with no error and no log line. A first reference kept `List(Jwk.Key)` (records with `Try` fields and the tag union `Jwk.Material` with `List(U8)` payloads). Each request read the JWKS again: `oidc/tp7-bot-token-pass` had 3 JWKS reads for 5 requests (expected 1), `tp3-tp7-claims` had 12 (expected 1). `MODULES.md` 9 says that a pinned value that does not parse loads again: this is for an older type, but it also hides a type that never round-trips. Request: a log line, or a compile-time check, when a `Memo` value does not parse back. | The first reference run, 2026-11-02. The fix in this slice: keep the JWKS text (`KeySet.jwks : Str`). Cause found by the platform session (2026-11-02): not the `Memo` or the type. The reference script built with `--opt=dev`, and roc-lang/roc#12782 (wasm32 `--opt=dev` narrows I128 to U8 wrongly) breaks each `List(U8)` that roc-cbor reads back. With `--opt=speed` (as `scripts/test.sh`), `List(Jwk.Key)` round-trips: oidc W2 8 of 8. `ref.sh` of slices 108, 108b and 109 now builds with `--opt=speed`. The text form stays (it is correct and simple). roc-cbor 0.2.3 avoids the bug, and the platform logs one line when a value does not parse back. |

## 10. Files

| File | Kind |
| --- | --- |
| `docs/slices/108b-roc-jwt.md` | New |
| `worker/lib/Oidc.roc` | Changed: `import jwt.Jwt`, `import jwt.Jwk`, the new stubs (65 lines in) |
| `worker/lib/main.roc`, `worker/main.roc`, `worker/tests/unit/w0.roc` | Changed: the `jwt:` URL, one line each |
| `worker/tests/unit/OidcTest.roc` | Changed (section 4.1) |
| `worker/tests/cases/oidc/tp3-jwt-strict/` | New |
| `research/slice-108b-revert/` | `before/` (copies, `NEW.txt`), `reference/`, `mutations/`, `ref.sh`, `mk_case.py`, `vectors/vectors.py` |

## 11. Disputes (from the code agent)

None yet.

## 12. Code and verify results

### 12.1 Code (2026-11-02)

| File | Change | Lines before | Lines after | Removed | Added |
| --- | --- | --- | --- | --- | --- |
| `worker/lib/Oidc.roc` | The bodies of `decode`, `key_for`, `check_registered`, `jwt_problem`, with the helpers `jwt_detail`, `seconds`, `clock`. The old items of section 3.2 are deleted. Doc texts that named the old items now name the new ones. | 399 | 265 | 188 | 54 |
| `worker/Auth.roc` | `import jwt.Jwk`, `jwks : Memo(Oidc.KeySet)`, `verify!` and `load!` as section 3.2. The order of slice 108 section 3.3 stays. | 92 | 94 | 20 | 22 |

Decisions that the slice does not fix (none change a wire result):

| Item | Choice |
| --- | --- |
| `key_for`: a JWKS text that `Jwk.parse_set` refuses | No key (`?? []`), as the doc comment says. `load!` keeps only a text that parses, so no path gives it. |
| `key_for`: `ManyKeys` | As `NoKey` (step 3 of the doc comment). With a `kid` in the header, `Jwk.select` does not give it. |
| `load!` | `Jwk.parse_set(text)` only as a check (`_keys`): the `Memo` keeps the text (section 9, P1). Each `key_for` parses the text again. |

### 12.2 Green results

| Step | Result |
| --- | --- |
| `roc check worker/main.roc` (nightly-2026-10-31-f7bef6b) | 0 errors, 0 warnings |
| `scripts/test.sh w0` | `OidcTest`: 18 of 18 pass. 261 of 281 pass in all: the 20 failures are `CompatTest` (13) and `CompatReadsTest` (7), slice 115. |
| `scripts/test.sh w2` | 85 of 95 pass, 130 s (cold build). All 8 `oidc/*` pass (also `tp3-jwt-strict`), all `toolchains/*` pass. The 10 failures are `compat/*`: each is `no route for ...` (slice 115 routes, not built yet). |
| `scripts/test.sh check fmt w1` | `check` pass, `fmt` pass. `w1`: 47 of 53 pass. The 6 failures are `compat/*` with `the compat SQL is missing` (slice 115). |

The revert check is in section 4.4 (the test agent, 10 mutations). The code agent did no new one.
