# Semver in one 64-bit order key (Registry 5.1, R-IK5; a roc-semver feature, Design 6.1, R-PK2)

Question: can one 64-bit integer hold the version of a release, also with a pre-release (`1.2.3-alpha4`), so that SQL can sort and select ranges? Is there a known scheme?

Answer: yes, as an order key that is never wrong, and exact for the usual versions. The layout is the one of the OpenStack Glance spec (16 bits each for major, minor and patch), and the low 16 bits are a pre-release code. A second text column holds the version only when the key does not give it back.

## Prior art (searched 2026-10-17)

| Scheme | Layout | Pre-release | What Talon takes |
| --- | --- | --- | --- |
| [OpenStack Glance, semver support (kilo)](https://specs.openstack.org/openstack/glance-specs/specs/kilo/semver-support.html) | Unsigned 64 bits: major, minor, patch 16 bits each, then 16 bits for "the release type flag" (a release sorts after its pre-releases), "reserved for future improvement" | The label in a separate string column, with numeric parts padded to 6 digits. One composite index on the integer and the string. | The layout and the second column |
| [CPython `PY_VERSION_HEX`](https://docs.python.org/3.13/c-api/apiabiversion.html) | 32 bits: major, minor, micro in bytes, then a level (0xA alpha, 0xB beta, 0xC candidate, 0xF final) and a serial | Only the 4 levels | Not taken: semver identifiers are free text (see below) |
| [semver issue 516](https://github.com/semver/semver/issues/516), an embedded scheme | 32 bits: 8 each for major, minor, patch, 2 bits type, 6 bits revision. Replies: patch needs 16 bits, "A `uint64_t` would be fine", no float (rounding). Closed as not part of the spec. | Alpha, beta, rc, production | The warning about narrow fields |
| Windows `VS_FIXEDFILEINFO` | `dwFileVersionMS` and `dwFileVersionLS`, used together as one 64-bit value for compares | None | 4 fields of 16 bits as a common form |

No scheme found keeps semver precedence for any pre-release text in the integer. Semver compares an alphanumeric identifier as ASCII text, so `1.2.3-alpha10` comes before `1.2.3-alpha4` (semver 11.4.2). A level and a serial would give the other order.

## The key

| Bits | Field | Value |
| --- | --- | --- |
| 63 to 48 | major | The major, or 0xFFFF when it is 0xFFFF or more |
| 47 to 32 | minor | The minor, or 0xFFFF when it, or a part above it, is 0xFFFF or more |
| 31 to 16 | patch | The same rule |
| 15 to 0 | Pre-release code | 0xFFFF for no pre-release (or after a saturated part). A numeric first identifier n: 0x0001 + min(n, 0x0FFE). An alphanumeric first identifier: 0x1000 + 65 × r(c1) + r(c2), from the ASCII rank of its first 2 characters. |

Two choices that the tests found necessary:

| Choice | Without it |
| --- | --- |
| A part of 0xFFFF or more saturates itself and each field after it | `65536.8.0-b.-` < `4294967295.0.0-99999.beta`, but its key is larger (S1, S4, S5 fail with `MUTATE=nosat`) |
| Numeric first identifiers get codes below the alphanumeric codes (semver 11.4.3) | `0.6.65534-0.0` gets a larger key than `0.6.65534-A` (S1 and S4 fail with `MUTATE=prenum`) |

Talon stores the key with the top bit flipped as a signed INTEGER, so the SQLite order is the key order (S4).

## Run

| Command | What it does |
| --- | --- |
| `node test.mjs [runs]` | S1 to S5, default 200,000 runs. Exit code 1 if one fails. |
| `MUTATE=nosat node test.mjs` | No saturation of the fields after a large part. S1, S4 and S5 must fail. |
| `MUTATE=prenum node test.mjs` | Numeric first identifiers above the alphanumeric ones. S1 and S4 must fail. |

`key.mjs` has the key, a semver 2.0.0 compare (section 11) written for this test, the caret bounds and the caret match (no pre-release match, as roc-semver Q6 and Q12). Needs Node 22 or later (`node:sqlite`).

## Results (2026-10-17)

The first run used a linear congruential generator in floating point: its multiply went above 2^53, so `rnd(n)` lost its low bits and gave few values. The test now uses mulberry32 (32-bit integer steps). The numbers below are from that run.

| Case | What | Result |
| --- | --- | --- |
| S1 | Monotone: a before b gives key(a) ≤ key(b). Half the pairs are near versions (one part or the pre-release changed). | 101,561 ordered pairs, 0 wrong, 10,858 key ties |
| S2 | An exact key gives the version back, and each release with parts below 0xFFFF is exact | Pass |
| S3 | The semver 11.4 chain `1.0.0-alpha` < ... < `1.0.0`; `1.2.3-alpha4` < `1.2.3-beta1` < `1.2.3` | Keys `10002000319d7`, `1000200031a11`, `100020003ffff` |
| S4 | 3000 versions in a `STRICT` SQLite table, `ORDER BY` the stored key | Agrees with precedence. Values from -9223372036854710273 to 9223372036854775807. |
| S5 | `^req` key bounds: each version that matches has its key in the bounds | 109,325 matches, all inside. 124,089 keys inside, so the Worker checks each row with the real match. |

The parts come from a domain with the edges 0, 1, 2, 9, 10, 0xFFFE, 0xFFFF, 0x10000 and 2^32 - 1, and the identifiers `alpha`, `alpha4`, `alpha10`, `beta`, `rc`, `rc1`, `a`, `b`, `A`, `-`, `0`, `1`, `4094`, `4095`, `99999`, `x-y`, `al`.

## What this does not prove

| Item | Status |
| --- | --- |
| The Roc code in roc-semver | Not written. This is the prototype of `Semver.to_key`, `Semver.from_key` and `VersionReq.key_bounds` (R-PK2, from 0.2.0). Its tests are the properties above, for the test agent of that slice. |
| Key bounds of all range forms | Only the caret form. The other forms of roc-semver (`~`, `>=`, comma lists) need the same superset property. |
| The compare | Written for this test from semver 2.0.0 section 11, not roc-semver. The roc-semver tests check its own compare. |
