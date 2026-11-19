# Log key tool (slice 257e)

`log-key.mjs` makes the signing key of the registry log. It uses `node:crypto` only. Go is not installed on this machine.

## Commands

Run all commands in the talon root.

| Command | Does |
| --- | --- |
| `node research/log-key/log-key.mjs make --signer-out <file> --verifier-out <file> [--origin <origin>]` | Makes a new Ed25519 key. Writes the secret signer key text to `<file>` and the public verifier key text to the other file. Prints the origin, the key id and the verifier key text. It never prints the signer key text. |
| `node research/log-key/log-key.mjs verify --verifier-file <file> --checkpoint-file <file>` | Checks a signed checkpoint (the answer of `GET /log/checkpoint`) against a verifier key text. Prints the origin, the size and the root hash. Exit code 2 when the check fails. |
| `node research/log-key/log-key.mjs self-test` | Makes a throwaway key in `.tmp/`, runs the checks, deletes the key. Exit code 0 when all pass. |

## Rules

| Rule | Reason |
| --- | --- |
| The signer file is mode 600 and has no newline. | It is a secret. A newline at the end would be part of the secret value. |
| The tool never overwrites a file. | A lost key cannot be made again: the key id and the tiles depend on it. |
| Write the signer file outside the repository (for example in `~/.config/talon-log/`). Never commit it, never print it. | R-WH14: `LOG_KEY` is a secret. |
| Default origin: `registry.roc-talon.org/log`. Bench origin: set with `--origin`. | Design Q636 (5). The origin has no space, no `+`, no control character, at most 255 bytes. |
| Make one prod key for the life of the log. | The design has no key rotation (slice 257, section 6). |

## Key text forms

| Text | Form | Secret |
| --- | --- | --- |
| Signer key (`LOG_KEY`) | `PRIVATE+KEY+<origin>+<key id, 8 hex digits>+<base64(0x01 ‖ 32-byte seed)>` | Yes |
| Verifier key | `<origin>+<key id>+<base64(0x01 ‖ 32-byte public key)>` | No |

The key id is the first 4 bytes of `SHA-256(origin ‖ 0x0A ‖ 0x01 ‖ public key)`. The base64 part can hold `+`, so a parser splits only at the first 4 `+`.

## What the self-test checks

| Check | Source |
| --- | --- |
| The published Go example key `PeterNeumann` (key id `c74f20a3`): the key id, the verifier text and the signer text come out as published. | `golang.org/x/mod/sumdb/note`, as in `research/slice-257a-vectors/vectors.mjs` |
| The files have mode 600 and no newline. A second write to the same file fails. | R-WH14 |
| Signer text and verifier text have one origin and one key id, and the seed gives the public key. | R-WH14 |
| A checkpoint signed with `node:crypto` verifies with the verifier text. A changed size, another key and another origin do not. | R-SG4 |
| The `make` command does not print the secret and refuses to overwrite. | R-WH14 |

The tool also verifies the signed note of `research/slice-257a-vectors/vectors.json` (the 257a test key, size 257).
