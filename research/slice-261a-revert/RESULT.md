# roc-ed25519 mutation check (Roc compiler version nightly-2026-11-13-03dce41, 2026-11-23T19:28Z)

| Mutant | File | Result | Failing test files |
| --- | --- | --- | --- |
| reference | Ed25519 | all pass (good) |  |
| no-s-below-l | Ed25519 | killed | ed25519.roc (2 failed, exit 1) |
| no-length-check | Ed25519 | killed | ed25519.roc (1 failed, exit 1) |
| non-point-a-valid | Ed25519 | killed | key.roc (4 failed, exit 1) |
| k-not-reduced | Ed25519 | killed | ed25519.roc (2 failed, exit 1) rfc8032.roc (5 failed, exit 1) |
| r-first-31-bytes | Ed25519 | killed | ed25519.roc (1 failed, exit 1) |
| plus-a-not-minus-a | Ed25519 | killed | ed25519.roc (3 failed, exit 1) rfc8032.roc (5 failed, exit 1) |
| x-sign-ignored | Ed25519 | killed | ed25519.roc (1 failed, exit 1) rfc8032.roc (4 failed, exit 1) |
| round-constant | Sha512 | killed | ed25519.roc (1 failed, exit 1) rfc8032.roc (5 failed, exit 1) sha512.roc (16 failed, exit 1) |
| length-field-bytes | Sha512 | killed | ed25519.roc (3 failed, exit 1) rfc8032.roc (5 failed, exit 1) sha512.roc (15 failed, exit 1) |
| rotation-41-to-40 | Sha512 | killed | ed25519.roc (2 failed, exit 1) rfc8032.roc (5 failed, exit 1) sha512.roc (16 failed, exit 1) |

## Notes

- `reference` fills the stub of `Ed25519.is_valid_public_key` (slice 261a, no code yet) in the mirror only, with a body over the decode of
  `verify`: 32 bytes and `decode_point` gives `Ok`. Every mutant gets the same fill. All test files pass with it, so the vectors of
  `tests/key.roc` agree with the decode of the code.
- `r-first-31-bytes`: killed by the test in `tests/ed25519.roc` with the zero key, S = 0, R = 31 zero bytes then 0x80, the message [0]
  (k mod 4 = 3, so the result is A, which equals R in the first 31 bytes only; `find31.py`, `ref.mjs`).
- `non-point-a-valid` (a y with no x is decoded with the wrong root instead of rejected): before `tests/key.roc` it survived. No signature
  test can kill it: no forgery input was found (`search.py`, `find_offcurve.py`: the order-8 construction does not exist for the Ed25519 d).
  The user chose a public decode check (`Ed25519.is_valid_public_key`); `tests/key.roc` kills the mutant (the y values with no x give True).
