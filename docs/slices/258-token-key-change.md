# 258 Planned TOKEN_KEY change

Phase: P2 (ordered by the user on 2026-11-19). Status: code (green), waiting for the verify step (section 11). Plan row: `docs/registry/PLAN.md` follow-up W7 (section G). Design id: Q637. Plan id: G-C267 (reserved). Slice number: 258.
Depends on slice 117 (`LoginRoutes`, `Login`: the JWT, Q300, Q301, Q310) and slice 121 (the settings and secrets, R-WH14).
Model for the code: Sonnet high (a small change in `Login` and `LoginRoutes`).

## 1. Scope

The Worker signs the contributor JWT with one secret, `TOKEN_KEY`. A token with another `kid` gets 401. Today the operator can change the key only after a leak, and each user then logs in again. This slice adds a planned key change: the operator moves the old public key into a second secret, and the Worker accepts a token of that key until the token expires. The leak path stays as it is.

| Part | Who | State |
| --- | --- | --- |
| The questions of section 7 | The user (through the lead) | Open. No test and no code before the answers (TW17) |
| `worker/lib/Login.roc`: the parse of the old set and the select of the key by `kid` (pure) | Test agent (signatures, doc), code agent (bodies) | After the answers |
| `worker/LoginRoutes.roc`: `proof!` reads the old set | Code agent | After the answers |
| `worker/tests/unit/LoginTest.roc`, `worker/tests/oidc.mjs`, new W2 cases (section 4) | Test agent | After the answers |
| `worker/wrangler.toml` comment (the new secret name) | Code agent | After the answers (no test) |
| `DESIGN*.md` | The lead (section 8 is the proposal) | After the answers |

Split: no split. The change is about 60 lines of code and 4 W2 cases.

## 2. Rules

### 2.1 Settled

| Rule | Text (short) | Where |
| --- | --- | --- |
| R-CT9 | The JWT. `alg` `EdDSA`. `kid` is the member `kid` of `TOKEN_KEY`. `exp` is `iat` plus 30 days. The check: the signature with the public key of `kid`, `iss` and `aud` equal to `AUDIENCE`, `exp` after now, `iat` not before `tokens_after`. Leeway 60 s for `exp` and a future `iat`. "The Worker has one key. A token with another `kid` gets 401. The operator changes the key only after a leak, as `CONTRIBUTOR_KEY` (R-CT3)... A planned key change that keeps the old public key until the last token that it signed expires is a later item (`docs/registry/PLAN.md` G, Design Q310)." | `DESIGN-REGISTRY.md` 1246 to 1256 |
| R-CT16 row 3 | The proof: the decode with `alg` `EdDSA` only and the `kid` of `TOKEN_KEY`, the signature, then the claims. Each fault is 401 with no D1 call. A missing or bad `TOKEN_KEY` or `AUDIENCE` is 500 `internal` | `DESIGN-REGISTRY.md` 1316 |
| R-WH14 (row `TOKEN_KEY`) | A private Ed25519 JWK as text: `kty` `OKP`, `crv` `Ed25519`, `x`, `d`, `kid` (not empty). The `kid` of the JWT is this member. A text that is not such a JWK is 500 `internal` | `DESIGN-REGISTRY.md` 1871 |
| Q300 | The form of `TOKEN_KEY` and the source of `kid` (decided 2026-11-02) | `DESIGN.md` 1098 |
| Q301 | `iat` and `exp` in seconds with 3 decimals. Leeway 60 s | `DESIGN.md` 1099 |
| Q310 | "Not in P2... A planned change with a set of old public keys selected by `kid` is a later item (`docs/registry/PLAN.md` G W7). The sentence of R-CT9 is changed." | `DESIGN.md` 1108 |
| W7 | "A secret of old public keys (a JWK Set) and the select of the key by the `kid` of the token, kept until the last token of the old key expires (30 days, plus the leeway). After a leak, the old key must not be kept, so the one-key form of slice 117 is correct for that case." | `docs/registry/PLAN.md` 290 |
| R-AP38, R-RE17 | `DELETE /v1/tokens` sets `tokens_after` to now: each token of the account stops, whatever its key | `DESIGN-REGISTRY.md` 110, 838 |
| R-SH8, R-SH13 | `tln` keeps the JWT as opaque text, uses `expires_at`, and reads a 401 as "log in again". It does not read `kid` | `DESIGN-CLI.md` 234, 286 |

### 2.2 Not settled

| Item | State |
| --- | --- |
| The name and the form of the secret of old keys | Not in the design. W7 says "a JWK Set". Q258-1 |
| The number of old keys, the faults of the set, a missing set | Not in the design. Q258-3 to Q258-5 |
| The order of a change on the Worker (two secrets, one deploy) | Not in the design. Q258-6 |
| The time to keep the old key | W7 gives the rule (30 days plus the leeway). The exact number for the operator is Q258-7 |
| Who removes the old key | Not in the design. Q258-8 |
| R-WH14 has no row for the new secret | Section 8 |

## 3. The current code

### 3.1 Where the key is read and used

| Item | Where |
| --- | --- |
| `TOKEN_KEY` is read with `secret_text!("TOKEN_KEY")` and parsed with `Login.signing_key`. A bad text is `Fault("TOKEN_KEY is not an Ed25519 key with a kid")` (500) | `worker/LoginRoutes.roc` 70 to 71 (the login), 191 to 192 (the proof) |
| The login signs with the whole secret text as the key (`WebCrypto.sign!`, `Jwk(secret)`) and writes `key.kid` in the header | `worker/LoginRoutes.roc` 77 to 78 |
| The proof: `Login.decode(token, key.kid)`, then `WebCrypto.verify!` with `key.public_json`, then `Login.check` | `worker/LoginRoutes.roc` 188 to 199 |
| `secret_text!` is `Env.secret!(name)` with `reveal()`. Any error is a `Fault` | `worker/LoginRoutes.roc` 241 to 242 |
| `signing_key : Str -> Try(SigningKey, [BadKey])`. `SigningKey : { kid, public_json }`. The `kid` is the member `kid` of the JWK. It must not be empty. Only `OKP` `Ed25519` is good. `public_json` is `Jwk.to_public_json` (no `d`) | `worker/lib/Login.roc` 137 to 155 |
| `decode : Str, Str -> Try(Decoded, Problem)`. The `kid` of the header must equal the one `kid`. Texts: `the token kid is missing`, `the token kid "<kid>" is not the key of this registry` | `worker/lib/Login.roc` 209 to 223 |
| `Oidc.bearer` and the GitHub JWKS code (`Auth.roc`, `lib/Oidc.roc`) are for the GitHub OIDC token (R-TP3), not for this JWT. They are not changed | `worker/Auth.roc`, `worker/lib/Oidc.roc` |

### 3.2 How `kid` is made, and the lifetime

| Item | Value | Where |
| --- | --- | --- |
| `kid` | The text that the operator puts in the `kid` member of `TOKEN_KEY`. Nothing derives it. Not empty | `Login.roc` 146 to 150 |
| Lifetime | `token_ttl_ms = 2_592_000_000` (30 days). `exp` is `iat` plus this. `expires_at` of the login answer is `now_ms + token_ttl_ms` | `Login.roc` 17 to 19, 202 to 204 |
| Leeway | `leeway_s: 60` in `Jwt.Rules` for `exp` and `iat` (Q301). A token is good while `now - 60 s < exp` | `Login.roc` 239 to 245 |
| The last good moment of a token | `iat` + 30 days + 60 s = `iat` + 2 592 060 s | derived |
| `jwt_problem` | The 401 texts of a claim error | `Login.roc` 227 to 235 |

### 3.3 The tests that cover it today

| Test | What it checks | Where |
| --- | --- | --- |
| W0 `signing_key` | A good key (RFC 8037 A.1) gives `kid` `key-1` and a public JWK with no `d`. Refused: no `kid`, empty `kid`, no `x`, RSA, EC, `oct`, not JSON | `worker/tests/unit/LoginTest.roc` 98 to 116 |
| W0 `signing_input` | The header with `kid`, the payload | `LoginTest.roc` 125 to 136 |
| W0 `decode` form | `alg` none, HS256, RS256, no `alg`, no `kid`, `other_kid` (`key-2`), bad forms. No crypto | `LoginTest.roc` 148 to 171 |
| W0 leeway | `exp` and `iat` at the edges of the 60 s | `LoginTest.roc` 176 to 200 |
| W0 `revoked` | `iat` against `tokens_after`, equal is good | `LoginTest.roc` 211 to 213 |
| W2 `account/ct9-token-check` | 26 requests. `kid2` (a token with `kid` `key-2`) is 401 with `the token kid "key-2" is not the key of this registry`. `other_key` (the key `t2`, `kid` default) is 401 with a bad signature. Also the edges of `exp`, `iat`, `iss`, `aud`, `sub`, and `old` (`tokens_after`) | `worker/tests/cases/account/ct9-token-check/` (`requests.jsonl`, `tokens.json`, `expect/responses.jsonl` line 6) |
| W2 `account/ct9-tokens-after`, `ct8-login`, `ct8-login-refusals`, `ct7-delete`, `ct10-tracker`, `ct11-login-limit`, `ap45-write-routes`, `cron/ct15-trim` | The routes with the key `{"$edkey":"t1","kid":"key-1"}` in `settings.json` | `worker/tests/cases/*/settings.json` |
| The runner | `edkey(name)` makes a throwaway Ed25519 key for each run. `fillSettings` turns `{"$edkey", "kid"}` into the text of the private JWK. `tokens.json` gives `key` and `kid` of a token | `worker/tests/oidc.mjs` 20 to 60 |

No test has a second key in the settings. No test has an old `kid` that is good.

## 4. Design proposal

### 4.1 Options for the secret of old keys

| Option | Form | For | Against |
| --- | --- | --- | --- |
| A (recommended) | `TOKEN_OLD_KEYS`: the text of a JWK Set (RFC 7517 section 5): `{"keys":[<public JWK>, ...]}`. Each key: `kty` `OKP`, `crv` `Ed25519`, `x`, `kid` (not empty). No `d` | The form that W7 names. `Jwk.parse_set` (roc-jwt) and `Jwk.select` read it. A public key cannot sign: a leak of the secret gives no power to sign | The operator must make the public JWK from the private one (one `jq` line, section 4.5) |
| B | `TOKEN_OLD_KEYS`: a list of old private JWKs | The operator moves the old `TOKEN_KEY` text as it is | A second place with private keys. A leak of the old set lets an attacker sign tokens, and only the old `exp` limit does not stop him |
| C | `TOKEN_KEY` becomes a JWK Set with private and old keys | One secret | Breaks Q300 (the form of `TOKEN_KEY`). A change of an existing secret at a deploy. Rejected |

### 4.2 The rules of A (proposal)

| # | Rule | Reason |
| --- | --- | --- |
| 1 | The login signs only with `TOKEN_KEY`. `TOKEN_OLD_KEYS` is read only by the proof | A key in the old set never signs again |
| 2 | `kid` is not derived. It is the member `kid` of each JWK, as Q300. The operator gives a new key a new `kid` that is not in the old set | Q300 is settled. A thumbprint would change R-CT9 and the tests |
| 3 | The proof: the `kid` of the header is the `kid` of `TOKEN_KEY`: as today. Else it is looked for in `TOKEN_OLD_KEYS`. Found: the same checks as today (`alg`, signature with that public key, the claims, `tokens_after`). Not found: 401 `the token kid "<kid>" is not the key of this registry` (the text does not change) | One path for the checks. No new text |
| 4 | A token of an old key is good until its own `exp` plus 60 s. The Worker adds no limit of its own | W7: "kept until the last token of the old key expires" |
| 5 | `TOKEN_OLD_KEYS` is read only when the `kid` of the header is not the `kid` of `TOKEN_KEY` (Q258-5) | No extra work on the common path. A bad set does not stop tokens of the current key |
| 6 | At most 4 keys (Q258-3). A text that is not a JWK Set, a key that is not Ed25519 or has no `kid`, a duplicate `kid`, a `kid` equal to the `kid` of `TOKEN_KEY` (Q258-6), or more than the maximum: 500 `internal`, as a bad `TOKEN_KEY` | A bad set must show at once, not drop a key and log users out (`Jwk.parse_set` leaves a bad key out with no error, so the code agent must count) |
| 7 | A missing or empty `TOKEN_OLD_KEYS` is an empty set. It is not a fault | The leak path: no old set (section 4.4) |
| 8 | The 401 for a token of an old key whose signature is wrong is `Login.bad_signature`, as today | No new text |

### 4.3 The shape of the code (pure first, TESTING.md 2)

| Item | Signature (proposal) | Note |
| --- | --- | --- |
| `Login.old_keys` | `Str -> Try(List(SigningKey), [BadOldKeys(Str)])` | Rule 6. The text of the tag says why, for the 500 `detail` |
| `Login.verify_key` | `SigningKey, List(SigningKey), Str -> Try(SigningKey, [NoKey])` | The current key, the old keys, the `kid`. The current key wins |
| `Login.decode` | `Str -> Try(Decoded, Problem)`, with `kid` read from the header by the caller, or the same function with the key list | The form checks of `decode` stay. The compare of `kid` moves to `verify_key`. Test agent fixes the exact form |
| `LoginRoutes.proof!` | After `decode`: if `kid != key.kid`, `secret_text!("TOKEN_OLD_KEYS")`, `Login.old_keys`, `Login.verify_key`; then `WebCrypto.verify!` with the selected `public_json` | `Env.secret!` of a name that is not set must give an empty set, not a `Fault` (the code agent checks the platform call; Q258-5) |

If `roc-jwt` needs a strict `parse_set` for rule 6, that is a change of a generic package (own repository, Design 6.1, R-GP1 to R-GP7). Then the code agent writes a question and stops that part (TW17). The count of `keys` in the text against the length of `parse_set` is the workaround and needs no change of the package.

### 4.4 The leak path

| Step | Action |
| --- | --- |
| 1 | Make a new key with a new `kid` (4.5 step 1) |
| 2 | Delete `TOKEN_OLD_KEYS` (`wrangler secret delete TOKEN_OLD_KEYS`) or never set it. Put the new `TOKEN_KEY` in the same deploy |
| 3 | Each token of the old key gets 401 at once. Each user logs in again (R-SH8). The old key is not kept anywhere |
| Rule | After a leak the operator must also remove the leaked key from `TOKEN_OLD_KEYS` if it is there. A key in the old set that leaked can sign a new token with a future `exp`, and the Worker would accept it. This is why the old set must not stay after the 30 days |

This is the one-key path of slice 117. It does not change.

### 4.5 The runbook for a planned change (proposal)

| # | Step | Note |
| --- | --- | --- |
| 1 | Make a new Ed25519 key with WebCrypto `generateKey` and `exportKey("jwk")` (Node, as the deploy note of slice 121). Add a new `kid` that is not in the old set. Keep the file in `<working directory>/.tmp/`, mode 600. Never commit it | The private key is a secret |
| 2 | Make the public JWK of the current `TOKEN_KEY`: the members `kty`, `crv`, `x`, `kid` only (no `d`). Put it in a JWK Set with the keys that are already in `TOKEN_OLD_KEYS` (at most 4 in all) | Read the current set first if there is one |
| 3 | Set `TOKEN_OLD_KEYS` and the new `TOKEN_KEY` in one deploy (Q258-6). Record the time of this deploy, T | Not two `wrangler secret put` calls: between them, the Worker has a new `kid` with no old set, or the same `kid` in both |
| 4 | Check: a login gives a token with the new `kid`. A token that was made before T still works (`GET /v1/contributors/me` gives 200) | |
| 5 | After T + 30 days + 60 s (use 31 days, Q258-7), remove the old key from `TOKEN_OLD_KEYS`. With no old key left, delete the secret | The last token of the old key has expired |
| 6 | If a second change comes before step 5, the set holds both old keys. Each leaves at its own T + 31 days | |

The CLI needs no change: `tln` keeps the JWT as opaque text and uses `expires_at`. A token of the old key keeps working, so no user logs in again for a planned change. A user whose token the Worker refuses gets 401 and logs in again (R-SH8), as after a leak.

## 5. Output (proposed, TW24)

| Item | Proposal |
| --- | --- |
| 500 `internal` for a bad `TOKEN_OLD_KEYS` | The fixed `detail` of slice 101 for a fault (as for a bad `TOKEN_KEY`). The reason goes only in the log, `Fault("TOKEN_OLD_KEYS is not a JWK Set of at most 4 Ed25519 keys with different kids: <why>")` |
| 401 for a `kid` that is in no set | The text that exists: `the token kid "<kid>" is not the key of this registry` |
| The answers of the 4 account routes and the login | Do not change |

No change of the CLI text, `--json`, or the wire records.

## 6. Out of scope

| Item | Reason |
| --- | --- |
| The CLI | It does not read the token (R-SH13) |
| A script for the runbook | The operator does it by hand. A script can come later |
| `CONTRIBUTOR_KEY` change | A different secret (R-CT3) |
| Key change for the GitHub OIDC JWKS (R-TP16) | Another party signs it |
| A deploy or a change of the real secrets | Not part of a slice. The operator does it |
| An automatic end of an old key by time (a member in the JWK) | Q258-8 option (b), later |

## 7. Questions (answered by the user 2026-11-19: all recommendations accepted (Design Q637))

The answers Q258-1 to Q258-9 are the recommendations of the last column. The tests of section 10 follow them.

| Id | Question | Options | Recommendation and reason |
| --- | --- | --- | --- |
| Q258-1 | The name and the form of the secret of old keys (R-WH14, R-CT9)? | (a) `TOKEN_OLD_KEYS`, a JWK Set of public keys. (b) the same name with old private keys. (c) one `TOKEN_KEY` set (section 4.1, C) | (a). W7 says a JWK Set of public keys. A leak of the old set gives no power to sign. The name pairs with `TOKEN_KEY`. A member `d` in an entry is ignored, not refused |
| Q258-2 | How is `kid` made for a new key (R-CT9, Q300)? | (a) As today: the operator chooses it, a text that is not empty. (b) The RFC 7638 thumbprint of the public key | (a). Q300 is settled, and (b) changes the login, the tests, and R-CT9. The Worker checks that the new `kid` is not in the old set (Q258-6) |
| Q258-3 | The maximum count of old keys? | (a) 1. (b) 4. (c) no limit | (b) 4. Two changes inside 31 days need 2. A limit keeps the secret small (a secret has a size limit) and a mistake (a set that grows each time) shows as a 500. Above 4 is a fault |
| Q258-4 | A fault of the set: a bad entry, a duplicate `kid`, a text that is not a JWK Set? | (a) 500 `internal` for the proof that needs the set. (b) leave the bad entry out (as `Jwk.parse_set`) and go on | (a). Rule 6 of 4.2. Option (b) logs users out with no sign of the cause. A bad `TOKEN_KEY` is 500 for the same reason (Q300) |
| Q258-5 | A missing or empty `TOKEN_OLD_KEYS`; and when does the Worker read it? | (a) Missing or empty is an empty set; read only when the `kid` of the token is not the `kid` of `TOKEN_KEY`. (b) A missing set is 500, read for each proof | (a). No work for the common path. A bad set stops only tokens of old keys. The leak path (4.4) needs "no set" to be valid |
| Q258-6 | The same `kid` in `TOKEN_KEY` and in the old set, and the order of the two secret changes? | (a) 500 `internal`, and the runbook sets both secrets in one deploy (`wrangler secret bulk`, check the command with the version of `wrangler` of the operator). (b) The current key wins and the old entry is ignored, so two `secret put` calls in any order work | (a). A duplicate is a mistake of the operator (the old key was not given a new `kid`) and (b) hides it: the old tokens then fail the signature. With (a) the one-deploy step costs nothing. The check of the code agent: does `wrangler` deploy a bulk set as one version? If not, take (b) |
| Q258-7 | The time to keep an old key (W7: 30 days plus the leeway)? | (a) 31 days after the deploy of the new key, in the runbook. (b) exactly 30 days + 60 s | (a). The last token that the old key signed is at the time of the deploy T, so it ends at T + 30 days + 60 s. A day of margin covers a deploy that takes time and a clock error. The Worker does not enforce it |
| Q258-8 | Who removes the old key: the operator only, or the Worker by a time? | (a) The operator only (runbook step 5). (b) Each entry has a member (for example `not_after`, ms) and the Worker ignores the key after it plus the leeway | (a) for this slice. (b) is safer if the operator forgets (an old key that leaked can sign new tokens, 4.4), but it needs our own parse of the entry (`Jwk.Key` has no such member) and a test of the clock. Ask again if a key is ever forgotten |
| Q258-9 | Phase and place of the text: W7 says "later"; the user ordered it on 2026-11-19. Does the text go in P2 R-CT9 and R-WH14? | (a) Yes, P2. R-CT9 changes the sentence, R-WH14 gets a row, Q310 is answered by Q637. (b) Keep it as a note of R-CT9 only | (a). Section 8 has the table. The change is small, and the 500 rule must be in R-WH14 with the secret |

## 8. Proposed design text (after the answers; the lead edits)

Numbers in the new text follow the recommendations.

| File and place | Old | New |
| --- | --- | --- |
| `DESIGN-REGISTRY.md` R-CT9, the part `kid` of the table (1251) | The id of the signing key: the member `kid` of `TOKEN_KEY` (R-WH14, Design Q300) | The id of the signing key: the member `kid` of `TOKEN_KEY` (R-WH14, Design Q300). A token that an old key signed has the `kid` of that key (`TOKEN_OLD_KEYS`) |
| `DESIGN-REGISTRY.md` R-CT9, the check (1256) | The check: the signature with the public key of `kid`, ... | The check: the signature with the public key of `kid`: `TOKEN_KEY`, or an entry of `TOKEN_OLD_KEYS` with that `kid`. The other checks are the same |
| `DESIGN-REGISTRY.md` R-CT9 (1256) | The Worker has one key. A token with another `kid` gets 401. The operator changes the key only after a leak, as `CONTRIBUTOR_KEY` (R-CT3): then each token of the old key stops at once, and each user logs in again (CLI 1, R-SH8). A planned key change that keeps the old public key until the last token that it signed expires is a later item (`docs/registry/PLAN.md` G, Design Q310). | The Worker signs with one key, `TOKEN_KEY`. A token with a `kid` that is in no set gets 401. A planned key change: the operator moves the old public key to `TOKEN_OLD_KEYS` and sets a new `TOKEN_KEY` with a new `kid`, in one deploy. A token of the old key stays good until its own `exp` plus the leeway, so no user logs in again. The operator removes the old key 31 days after the deploy (the 30 days of `exp`, the 60 s leeway, and a margin). After a leak the operator does not keep the old key: no `TOKEN_OLD_KEYS`, a new `TOKEN_KEY`; each token of the old key stops at once, and each user logs in again (CLI 1, R-SH8). The runbook is in `docs/slices/258-token-key-change.md` (Design Q637) |
| `DESIGN-REGISTRY.md` R-CT16 row 3 (1316) | ... the `kid` of `TOKEN_KEY` ... A missing or bad `TOKEN_KEY` or `AUDIENCE` is 500 `internal` | ... the `kid` of `TOKEN_KEY` or of `TOKEN_OLD_KEYS` ... A missing or bad `TOKEN_KEY` or `AUDIENCE` is 500 `internal`. `TOKEN_OLD_KEYS` is read only for a `kid` that is not the `kid` of `TOKEN_KEY`. A missing or empty `TOKEN_OLD_KEYS` is an empty set. A bad one is 500 `internal` |
| `DESIGN-REGISTRY.md` R-WH14 secrets table, after `TOKEN_KEY` (1871) | (no row) | `TOKEN_OLD_KEYS` / Secret / The public keys of the old `TOKEN_KEY` keys, as the text of a JWK Set (RFC 7517): `{"keys":[...]}`, at most 4 keys, each `kty` `OKP`, `crv` `Ed25519`, `x`, `kid` (not empty, different from the others and from the `kid` of `TOKEN_KEY`). Optional. The Worker never signs with it. A text that is not such a set is 500 `internal` / R-CT9 / Named. The form is decided (Q637) |
| `DESIGN.md` Q310 (1108) | Not in P2... is a later item (`docs/registry/PLAN.md` G W7). The sentence of R-CT9 is changed (decided 2026-11-02, Registry R-CT9). | Add: "Done in slice 258 (Q637)." |
| `DESIGN.md`, new row | (none) | Q637: slice 258, G-C267: the planned change of `TOKEN_KEY` (the secret `TOKEN_OLD_KEYS`, the select by `kid`, the leak path, the runbook), with the answers to Q258-1 to Q258-9 |
| `docs/registry/PLAN.md` W7 (290) | A need for a planned change of `TOKEN_KEY`: none in P2 | Done: slice 258 (Q637, G-C267) |
| `docs/registry/PLAN.md` G9 (244) | Not named: ... | Add `TOKEN_OLD_KEYS` to the named secrets |
| `worker/wrangler.toml` (38) | The secrets ... `TOKEN_KEY` ... | Add `TOKEN_OLD_KEYS` (optional) to the list |

## 9. Test plan (after the answers; the test agent writes)

Tests name rule ids (TESTING.md). New rule ids: none. The tests check R-CT9, R-CT16 row 3 and R-WH14. `MISSING=1 scripts/rules.sh R-CT R-WH` lists the rules with no test.

### 9.1 W0 (pure, `roc test`), `worker/tests/unit/LoginTest.roc`

| Function | Cases | Rule |
| --- | --- | --- |
| `Login.old_keys` | One good key; 4 keys; 5 keys (fault); empty `keys` list (empty set); an empty text (empty set); not JSON; no `keys`; one key with RSA, EC, `oct`; no `kid`; empty `kid`; two keys with one `kid`; an entry with `d` (ignored, no `d` in `public_json`); the public JWK of RFC 8037 A.1 for the good case | R-CT9, R-WH14 |
| `Login.verify_key` | `kid` of the current key gives the current key; `kid` of an old key gives it; a `kid` in no set is `NoKey`; the current key wins when it is first; a `kid` that differs by case is `NoKey` | R-CT9 |
| `Login.decode` or its new form | The existing form cases do not change (`other_kid`, no `kid`). The text for a `kid` in no set is the old text | R-CT16 row 3 |
| Leeway for an old token | Not new. `exp` edge is the same function. One case with the 2 592 060 s bound: a token with `iat` = T is good at T + 30 days + 59.999 s and refused at T + 30 days + 60 s | R-CT9, Q301 |

### 9.2 W2 (cases with two keys), `worker/tests/cases/account/`

The runner needs one change (test agent): `fillSettings` turns `{"$edset":[{"edkey":"t2","kid":"key-0"}]}` into the text of a JWK Set of the public keys (no `d`). `tokens.json` already has `key` and `kid` for a token.

| Case | Settings | Requests | Expect |
| --- | --- | --- | --- |
| `ct9-old-key` | `TOKEN_KEY` `t1`/`key-1`; `TOKEN_OLD_KEYS` set with `t2`/`key-0` and a second key `t3`/`key-00` | `GET /v1/contributors/me` with: a token of `t2`/`key-0` (200); a token of `t3`/`key-00` (200); a token of `t1`/`key-1` (200); a token with `kid` `key-0` signed by `t1` (401, bad signature); a token `kid` `key-9` (401, not the key of this registry); the `exp` edge of an old token (200 at the edge, 401 after); an old token before `tokens_after` (401); `DELETE /v1/tokens` with an old token (204) then the old token again (401) | 200, 401 as listed. `d1-calls`: 1 for each 200, 0 for each 401 |
| `ct9-old-key-login` | as `ct9-old-key` | `POST /v1/tokens` | The new token has the header `kid` `key-1`, never `key-0` (the login signs with `TOKEN_KEY` only) |
| `ct9-old-key-none` (the leak path) | `TOKEN_KEY` `t1`/`key-1`, no `TOKEN_OLD_KEYS` | A token of `t2`/`key-0` | 401 `the token kid "key-0" is not the key of this registry`, 0 D1 calls. Also `TOKEN_OLD_KEYS` set to `""`: 401 |
| `ct9-old-key-bad` | One case for each of: not JSON; a key with no `kid`; two keys with one `kid`; a `kid` equal to the `kid` of `TOKEN_KEY`; 5 keys (settings in one file each, so 5 small cases or one case with `settings` variants if the runner has them) | A token of `key-0` (500 `internal`, 0 D1 calls); a token of the current key `key-1` (200: the set is not read, Q258-5) | 500 and 200 |

### 9.3 Revert checks (the most tricky behaviors, memory: about 5 to 10)

| Mutation | Test that must fail |
| --- | --- |
| The old key is looked up by position, not by `kid` | `ct9-old-key` (token of `t3`) |
| The old key accepted with the key of `TOKEN_KEY` (signature not checked with the old public key) | `ct9-old-key` (`key-0` signed by `t1`) |
| The login signs with the first old key | `ct9-old-key-login` |
| A token of an old key skips `tokens_after` | `ct9-old-key` (old before `tokens_after`) |
| The old set is used when it is missing (leak path) | `ct9-old-key-none` |
| A bad entry is left out, not a 500 | `ct9-old-key-bad` |
| The set is read for each proof | `ct9-old-key-bad` (the `key-1` request is 200) |
| The count limit is 5 | W0 `old_keys`, `ct9-old-key-bad` |

The tests run with the capped scope and the shared lock (machine rules). No heavy job is needed for this scope step.

## 10. Tests (red) (test agent, 2026-11-19)

Status: the tests are written and fail red for the right reason. They wait for the human review (TESTING.md 7). The answers of section 7 are the recommendations (Design Q637). No question is open.

### 10.1 What the code agent writes (the signatures that the test agent fixed)

The stubs are in `worker/lib/Login.roc` (4 new functions, `crash "todo"`). `decode`, `check`, `signing_key`, `SigningKey`, `revoked` do not change. A different form from section 4.3: `old_keys` takes the `kid` of `TOKEN_KEY` (rule 6 needs it, and a pure function has no other way to know it), and the compare of the `kid` stays in `decode`, so the old W0 tests of `decode` stay as they are.

| Function (in `Login`) | Signature | Rule of the body |
| --- | --- | --- |
| `old_keys` | `Str, Str -> Try(List(Login.SigningKey), [BadOldKeys(Str)])` | `old_keys(text, current_kid)`. The empty text and `{"keys":[]}` are `Ok([])`. Else a JWK Set of at most 4 entries, each an OKP Ed25519 key with a `kid` that is not empty, no `kid` twice, no `kid` equal to `current_kid`. A member `d` or any other member is ignored. `public_json` has no `d`. The list has the order of the text. Any other case is `Err(BadOldKeys(why))`. A bad entry is never left out (`Jwk.parse_set` leaves it out: count the `keys` of the text and compare with the length of the parse, or parse the entries yourself). The `kid` compare is exact text |
| `verify_key` | `Login.SigningKey, List(Login.SigningKey), Str -> Try(Login.SigningKey, [NoKey])` | The current key when its `kid` is the `kid`, else the first old key with that `kid`, else `Err(NoKey)`. The current key wins. Exact text compare (no case fold, no prefix) |
| `token_kid` | `Str -> Try(Str, Problem)` | The `kid` of the header: `Jwt.Options.{ algs }` decode, then the `kid`. Faults as `decode` before its `kid` compare: `jwt_problem(err, "")`, and `the token kid is missing`. No crypto, no D1 |
| `no_key` | `Str -> Problem` | 401 `unauthenticated`, `the token kid "<kid>" is not the key of this registry` (the text that `decode` gives for another `kid`) |

`LoginRoutes.proof!` (code agent, no new W0 test of its own; W2 checks it): `kid = Login.token_kid(token)`; when `kid == key.kid`, go on as today (the set is not read); else read `TOKEN_OLD_KEYS` (`Env.secret!`; a missing secret and the empty text are an empty set, so any `Err` of that read is the empty set), `Login.old_keys(text, key.kid)` (`Err(BadOldKeys(why))` is `Fault("TOKEN_OLD_KEYS is not a JWK Set of at most 4 Ed25519 keys with different kids: <why>")`, 500), `Login.verify_key` (`NoKey` is `Refuse(Login.no_key(kid))`); then `Login.decode(token, used.kid)`, `WebCrypto.verify!` with `used.public_json`, `Login.check`. The login signs with `TOKEN_KEY` only (no change). `worker/wrangler.toml` comment: add `TOKEN_OLD_KEYS` (optional).

### 10.2 Files

| File | What |
| --- | --- |
| `worker/tests/unit/LoginKeysTest.roc` (new), `worker/tests/unit/w0.roc` (one `import`) | W0: 7 `expect` blocks: `old_keys` (3 blocks, 40 checks), `verify_key`, `token_kid`, `no_key`, and the last good moment of an old token (the 30 days plus 60 s bound, Q301). A new file, so the generated `LoginTest.roc` is not changed. The test keys are public `x` values of throwaway keys (and RFC 8037 A.1) |
| `worker/tests/oidc.mjs` | `fillSettings`: a value `{"$edset":[{"edkey":"t2","kid":"key-0"}, ...]}` is the text of a JWK Set of public keys. An entry can have `"kid": null` (no `kid`), `"kid": ""`, `"d": true` (a member `d`), `"set": {"kty":"EC"}` (replace a member) |
| `worker/tests/cases/account/ct9-old-key*` (16 new cases) | W2, table 10.3. Each has `settings.json`, `tokens.json`, `seed.sql` (one `contributors` row, `tokens_after` 1767225600000), `requests.jsonl`, `expect/`, `rules` |
| `research/slice-258-revert/` | `reference/` (a private reference, not the implementation: it only shows that the tests can pass), `mutate.sh`, the mutants (10.5) |

### 10.3 W2 cases (rules: R-CT9, R-CT16, R-WH14, R-AP41, R-AP35 in each; more in the table)

Settings: `TOKEN_KEY` `t1`/`key-1`. Set A is `t2`/`key-0` and `t3`/`key-00`. The clock is 1767226600000 (as `ct9-token-check`). The 401 and 500 texts are the ones of the design and of the existing cases.

| Case | `TOKEN_OLD_KEYS` | Requests (all `GET /v1/contributors/me`, except the DELETE) | Expect |
| --- | --- | --- | --- |
| `ct9-old-key` (+R-AP38, R-RE17) | A | 1 current token. 2 `key-0`. 3 `key-00`. 4 `key-0` signed by `t1` (bad signature). 5 `key-00` signed by `t2` (a key looked up by position would accept). 6 `kid` `key-9`. 7 old token, `exp` at the 60 s edge. 8 old token, `exp` 1 ms inside the edge. 9 old token with `iat` before `tokens_after`. 10 `DELETE /v1/tokens` with the `key-0` token, 11 to 13 the `key-0`, `key-00` and current tokens again | 200, 200, 200, 401 `the token signature is not valid` (D1 0), 401 same, 401 `the token kid "key-9" is not the key of this registry`, 401 `exp` text, 200, 401 revoked text (D1 1), 204, 401, 401, 401 (revoked text, D1 1 each). 200 has 1 D1 call, each other 401 has 0 |
| `ct9-old-key-login` (+R-AP37, R-CT8) | A | `POST /v1/tokens`, then the new token, then the `key-0` token | 201 with a JWT of `t1`, header `kid` `key-1` (never `key-0`); 200; 200. One GitHub call |
| `ct9-old-key-none` (the leak path) | not set | current token; `key-0`; `key-9` | 200; 401 `kid "key-0"`; 401 `kid "key-9"`. D1 1, 0, 0 |
| `ct9-old-key-empty` | `""` | as `none` | as `none` |
| `ct9-old-key-emptyset` | `{"keys":[]}` | as `none` | as `none` |
| `ct9-old-key-d` | one entry with a member `d` | `key-0`; current; `key-0` signed by `t1` | 200; 200; 401 bad signature |
| `ct9-old-key-four` | 4 keys (`key-0`, `key-00`, `key-2`, `key-3`) | `key-0`; `key-3`; `key-9` | 200; 200; 401 |
| `ct9-old-key-bad-notjson`, `-notset` (a single JWK, no `keys`), `-nokid`, `-emptykid`, `-dupkid`, `-samekid` (an entry has the `kid` of `TOKEN_KEY`), `-five` (5 keys), `-kty` (an `EC` entry), `-crv` (an `Ed448` entry) | the bad set (R-AP21 added) | 1 current token. 2 `key-1` signed by `t2` (a bad signature of the current `kid`). 3 `key-0`. 4 `key-9` | 200 (D1 1: the set is not read); 401 bad signature (D1 0: the set is not read); 500 `internal`, `the Worker failed to handle the request` (D1 0); 500 same (D1 0) |

### 10.4 Red results (run 2026-11-19, `scripts/test.sh w0 wbuild w2 wtrap`, Worker compiler `nightly-2026-11-06-34f137a`)

| Step | Result |
| --- | --- |
| fmt (`scripts/test.sh fmt`, and the `fmt --check` of `w0`: the worker compiler; and the pinned `nightly-2026-10-14` compiler on the 3 changed Roc files) | pass, both compilers |
| W0 `worker/tests/unit/w0.roc` | 578 expect blocks: 572 pass, 6 fail. The 571 old blocks pass, and 1 new block passes (the bound of the old token: `decode` and `check` already do it, it is a guard). The 6 red blocks are the 3 of `old_keys`, `verify_key`, `token_kid`, `no_key`: each crashes with `todo` |
| W2 | 228 cases: 215 pass, 13 fail. The 212 old cases pass. The 16 new cases: 13 fail with the wrong values of the old code (`key-0` gets 401 `not the key of this registry`, a bad set gets 401 and not 500), 3 pass: `ct9-old-key-none`, `-empty`, `-emptyset` (the old code already refuses an old `kid`: they guard the leak path, and the mutant r3 makes them red) |
| wbuild, wtrap | pass |

The run also shows 33 red tests in `packages/records/tests/TlogTest.roc`: they are new files of another slice (slice 257, `Tlog`), not of this slice.

### 10.5 Revert check (10 mutants, `research/slice-258-revert/mutate.sh <names>`)

The private reference passes all tests (W0: 578 of 578; W2: all 24 cases of `account/`). Each mutant is one literal change of the reference. The verify agent applies the same changes to the real code (each is a behavior, so the text differs) and runs only these: the W0 of `LoginKeysTest` and `scripts/test.sh w2` with the filter `account/ct9-old-key`. Never the full sweep.

| Mutant | Change | Killed by (result with the reference) |
| --- | --- | --- |
| m1 | The limit of old keys is 5, not 4 | W0 `old_keys` (`five`). Killed |
| m2 | Two keys with one `kid` are accepted | W0 `old_keys`. Killed |
| m3 | A bad entry is left out, not a fault (`Jwk.parse_set` as it is) | W0 `old_keys`. Killed |
| m4 | The `kid` of `TOKEN_KEY` is accepted in the old set | W0 `old_keys`. Killed |
| m5 | An old key wins over the current key with one `kid` | W0 `verify_key` (`current_wins`). Killed |
| m6 | An entry that is not an Ed25519 key is accepted (`EC`, `RSA`, `Ed448`) | W0 `old_keys`. Killed |
| r1 | `TOKEN_OLD_KEYS` is read for each proof, also for a token of the current key | W2 the 9 `-bad-` cases (the current-key request gets 500). Killed |
| r2 | A token of an old key is checked with the public key of `TOKEN_KEY` | W2 `ct9-old-key`, `-login`, `-d`, `-four`. Killed |
| r3 | A missing `TOKEN_OLD_KEYS` is a fault, not an empty set | W2 `ct9-old-key-none` (401 expected, 500 given). Killed |
| r4 | A bad set is dropped (an empty set), not a 500 | W2 the 9 `-bad-` cases. Killed |

The 4 W2 mutants were run twice. In the first run `ct9-old-key-four` and `-bad-five` had a `kid` `key-1` in the set (the `kid` of `TOKEN_KEY`: a test error, found with the reference and fixed). The results above are from the second run: the reference passes 18 of 18 cases of `account/ct9`, and each mutant fails the cases named.
Not mutated (no code in the reference, so the verify agent adds them): the login signs with an old key (killed by `ct9-old-key-login`, the `jwt` check of `t1` and `kid` `key-1`), and an old token that skips `tokens_after` (killed by `ct9-old-key` request 9).

### 10.6 Questions

None. Two choices of the test agent for the human review (TW24, not design questions): (1) `old_keys` takes `current_kid` as a second argument (10.1). (2) A bad set with a token of an unknown `kid` is 500 too (the set is read for each `kid` that is not the current one, rule 5 of 4.2); a token with a bad form (the `alg`, no `kid`) is 401 before the set is read.

## 11. Code notes (code agent, 2026-11-19)

| Item | Note |
| --- | --- |
| Files | `worker/lib/Login.roc` (the 4 stubs, and `old_keys_max` = 4), `worker/LoginRoutes.roc` (`proof!` and the new `old_key!`), `worker/wrangler.toml` (comment: `TOKEN_OLD_KEYS`, optional), `docs/registry/PLAN.md` (W7 done, G9 names `TOKEN_OLD_KEYS`) |
| `Env.secret!` of a secret that is not set | The platform gives `Err(Infra(MissingEnv(name)))`, so `old_key!` reads any `Err` as the empty text, and the empty set (not a `Fault`) |
| `old_keys` | Empty text (after `trim`) is `Ok([])`. Else it parses the text as `{ keys : List({ kty }) }` to count the entries (not JSON, or no `keys`: `BadOldKeys`). More than 4: fault. Then `Jwk.parse_set`; a shorter list than the count means that an entry was dropped: fault. Then, for each key: `kid` not empty, OKP Ed25519 (so RSA and EC fail), `kid` is not `current_kid`, no `kid` twice. `public_json` is `Jwk.to_public_json` (no `d`). The generic package is not changed |
| `verify_key` | The current key when its `kid` is equal; else `find_first` in the old list; else `NoKey` |
| `token_kid` | `Jwt.decode` with `algs`, then the `kid` of the header (faults as `decode`) |
| `proof!` | `token_kid`, then the current key when the `kid` is equal (the set is not read), else `old_key!` (read the secret, `old_keys`, `verify_key`). `decode` and `WebCrypto.verify!` use the selected key. `Login.check` is unchanged, so `tokens_after`, `exp` and the leeway work the same for an old token. The login is not changed (it signs with `TOKEN_KEY` only) |

## 12. Code results (2026-11-19)

| Step | Result |
| --- | --- |
| W0 `worker/tests/unit/w0.roc` (worker compiler) | 578 of 578 pass (the 6 red blocks are green) |
| `scripts/test.sh fmt wbuild w2 wtrap` | all pass. W2: 228 passed, 0 failed (the 13 red cases are green) |
| `scripts/test.sh w0` as a step | FAIL only for `packages/records/tests/TlogTest.roc` (slice 257, another agent: a stack overflow and one other block). The Worker part passes, and `fmt --check` of the Worker files passes |

Disputes: none.

## 11. Verify results (test agent, 2026-11-19)

### 11.1 Fix of the test file

`scripts/test.sh w0` failed with the warning "unconditional condition" at `LoginKeysTest.roc` 177 (the `match` of `late` on a literal token). `late` now takes the token text as an argument (`late(old_token, now_ms)`), with the same 4 checks. `scripts/test.sh w0`: pass (578 of 578, no warning). `roc fmt --check` passes with the pinned `nightly-2026-10-14` compiler and with the worker compiler.

### 11.2 Revert check on the real code

`research/slice-258-revert/mutate-real.sh <names>` applies one literal change at a time to a MIRROR of `worker/` under `.tmp/slice-258-mut-real/` (the repo files are never edited, so no other agent can build a mutant by chance). It uses the capped scope, the shared lock and a 600 s limit for each step, and runs only the W0 driver (m) or the W2 cases `account/ct9` (r). `sha256sum` of `worker/lib/Login.roc` and `worker/LoginRoutes.roc` was the same before and after (the script checks it; `8c941fbc...` and `07b3d237...`).

Base on the real code: W0 578 of 578 pass. W2 `account/ct9`: 18 of 18 pass.

| Mutant | Change on the real code | Result |
| --- | --- | --- |
| m1 | `old_keys_max = 5` | W0 577 pass, 1 fail (`old_keys`, 5 keys). Killed |
| m2 | the duplicate check is `if Bool.False` | W0 1 fail (`old_keys`). Killed |
| m3 | the count check (`parsed.len() != entries`) is `if Bool.False` | W0 1 fail (`old_keys`). Killed |
| m4 | the check `kid == current_kid` is `if Bool.False` | W0 1 fail (`old_keys`). Killed |
| m5 | `verify_key` looks in the old list first | W0 1 fail (`verify_key`, `current_wins`). Killed |
| m6 | a key that is not Ed25519 is accepted (`_ => Jwk.to_public_json(key)`) | W0 1 fail (`old_keys`). Killed |
| r1 | `used = old_key!(key, kid)?` (the set is read for each proof) | W2 the 9 `ct9-old-key-bad-*` cases fail. Killed |
| r2 | the signature of an old token is checked with `key.public_json` | W2 `ct9-old-key`, `-login`, `-d`, `-four` fail. Killed |
| r3 | a missing `TOKEN_OLD_KEYS` is a `Fault` | W2 `ct9-old-key-none` and `ct9-token-check` fail. Killed |
| r4 | a bad set gives `?? []` (dropped, not a 500) | W2 the 9 `ct9-old-key-bad-*` cases fail. Killed |
| r5 | the login writes the `kid` of the first old key | W2 `ct9-old-key-login` fails (the header `kid` must be `key-1`). Killed |
| r6 | the `iat` of a token of an old key is taken as now (skips `tokens_after`) | W2 `ct9-old-key` fails (request 9). Killed |

Result: 12 mutants, 12 killed, no equivalent mutant, no survivor. No test was changed except the fix of 11.1.
