# Check R-PU25: an installation token reads a public repository outside the installation

Question (DESIGN-REGISTRY.md R-PU25, "P2 check for R-PU25", PLAN.md G14): can an installation token of the GitHub App `Talon Indexer` read a public repository that is not in the installation? The registry needs these reads for the reconcile (R-PU21 to R-PU25) and for the visibility check (R-PU31).

If every read passes, R-PU25 stands. If a read fails, the fallback of R-PU25 applies: a fine-grained token of a bot account (secret `GITHUB_READ_TOKEN`).

## Steps for the user

| Step | Command or action | What happens |
| --- | --- | --- |
| 1 | `research/github-app-check/create.sh`, then open the printed `http://127.0.0.1:<port>/` URL | The page sends the manifest to GitHub. Click "Create GitHub App" (one click). GitHub goes back to the local server. The script saves the keys in `~/.config/talon-indexer/` (mode 600) and prints the install URL. It prints no secret. |
| 2 | Open the printed URL `https://github.com/apps/<slug>/installations/new`. Choose `roc-talon`, then "Only select repositories", then `roc-talon/talon` only | The App is installed. The probe repositories are not in the installation. This is the point of the check. |
| 3 | `research/github-app-check/check.sh` | The script reads the probe repositories with the installation token and writes `RESULT.md`. Exit code 0: all reads pass. Exit code 1: a read of a public repository outside the installation failed. Exit code 2: a setup fault (no keys, no installation). |

Tools: `node` and `gh` (logged in as an owner of `roc-talon`) for step 1. `bash`, `curl`, `openssl` and `jq` for step 3.

After the check, put the result in the design: the table in `RESULT.md`, and the decision for R-PU25 (App token, or the fallback).

## The manifest (choices)

The design does not list the App settings in one place. The choice below comes from these rules.

| Setting | Value | Reason |
| --- | --- | --- |
| name | `Talon Indexer` | R-PU25, RN18 |
| url | `https://github.com/roc-talon/talon` | The home of the project |
| public | false | Only `roc-talon` installs it (R-PU25: owned by and installed on `roc-talon`) |
| Permission `metadata` | read | GitHub gives it to every App. Reads of `GET /repos/{owner}/{repo}` and `GET /repositories/{id}` (R-PU31). Needed by the event `repository`. |
| Permission `contents` | read | Release list, release by tag, asset download, `.roc-version` and file reads (R-PU4, R-PU8, R-PU20, R-PU21, R-PU38). Needed by the event `release`. |
| No other permission | - | The Worker only reads (R-PU25, CLI 1, R-RG3). No write, no `issues`, no `actions`. |
| Event `release` | on | R-PU11 |
| Event `repository` | on | R-PU11: the actions `privatized` and `publicized` (R-PU33) |
| Events `installation` and `installation_repositories` | not in the manifest | GitHub sends them to every App with no setting. R-PU11 and R-PU26 use them. |
| Webhook | URL `https://example.com/v1/webhooks/github`, `active: false` | The Worker is not deployed. The URL is a placeholder. In slice 118, set the real URL (`<AUDIENCE>/v1/webhooks/github`, R-AP12) and turn the hook on in the App settings. GitHub makes the webhook secret now. The script saves it. |
| redirect_url | `http://127.0.0.1:<port>/done` | The local server of `create.sh` |

Open question for the human (not decided here): GitHub makes the webhook secret itself. The design (R-AP12) needs it as a Worker secret in slice 118. It is in `~/.config/talon-indexer/webhook_secret`.

## Files

| File | Use |
| --- | --- |
| `create.sh`, `create.mjs` | Manifest flow. A local server on 127.0.0.1. Checks the `state` value. Calls `gh api -X POST /app-manifests/<code>/conversions`. Saves `id`, `slug`, `client_id`, `client_secret`, `webhook_secret` and `private-key.pem` in `~/.config/talon-indexer/` (directory mode 700, files mode 600). Env `TALON_INDEXER_DIR` changes the directory. |
| `check.sh` | The check. Makes the RS256 app JWT with openssl (`iat` now - 60, `exp` now + 540, `iss` the app id). Finds the installation of `roc-talon` (`GET /app/installations`). Gets the token (`POST /app/installations/<id>/access_tokens`). Never prints the token. The token is in a variable and in a mode 600 header file in a temporary directory. |
| `check.sh --selftest` | Tests the JWT code with a throwaway key: three parts, base64url, header, payload, signature. No network. |
| `check.sh --try-with-gh-token` | Dry run of the read code with the token of `gh`. It is not evidence for R-PU25. It prints the table and writes no `RESULT.md`. |
| `check.sh owner/repo ...` | Other probe repositories. Default: `roc-lang/basic-cli` and `Karakatiza666/roc-semver`. |
| `.gitignore` | A guard: no key and no secret in the repository. The keys are outside the repository anyway. |
| `RESULT.md` | The output of the real check, with the date. |

## Reads in the check

For each probe repository, with the installation token:

| Read | Pass condition |
| --- | --- |
| `GET /repos/{owner}/{repo}` | 200, `visibility` is `public` |
| The same with `If-None-Match` | 304, and `x-ratelimit-remaining` is the same as before (the 304 is free) |
| `GET /repos/{owner}/{repo}/releases` | 200, no draft in the list |
| The same with `If-None-Match` | 304, and the remaining count is the same |
| `GET /repos/{owner}/{repo}/releases/tags/{tag}` | 200 |
| The `browser_download_url` of the smallest asset | 200 or 206 (first 100 bytes, no token) |
| `GET /repos/{owner}/{repo}/releases/assets/{id}` with `Accept: application/octet-stream` | 302 to a signed URL, which also gives 200 or 206 with no token |
| `GET /repositories/{id}` and the same with `If-None-Match` | 200, the same `full_name`, then 304 |
| `GET /repos/{owner}/{repo}/contents/` and a file in it, also with `Accept: application/vnd.github.raw+json` | 200 |

Also recorded: `x-ratelimit-limit` with no token (expect 60) and with the token (expect 5000 or more). The script stops with a failure if a probe repository is in the installation (`GET /installation/repositories`).

## Limits of the check

| Limit | Note |
| --- | --- |
| Drafts (R-PU23) | The probe repositories are not in the installation and the App has no write access to them. So a draft is not in the lists, and this is true with or with no App. The check cannot test the R-PU23 claim about drafts. To test it: make a draft release in `roc-talon/talon` and read the release list with the token. |
| The 304 count | The count of the 302 answer of the asset API can come from another counter at GitHub (the dry run shows a jump). The script does not use it. The 304 rows compare only two answers of the same kind. |
| The token of the App | Its limit can be higher than 5000 for a large organization (GitHub docs, "Rate limits for the REST API"). A value of 5000 or more is a pass. |

## Tests done without the App (2026-11-01)

| Test | Result |
| --- | --- |
| `check.sh --selftest` | JWT: 3 parts, base64url, header `{"alg":"RS256","typ":"JWT"}`, payload `iat`, `exp`, `iss`, signature verifies with the public key |
| `create.sh` with a stub `gh` and a temporary directory | The server starts and serves the form with the manifest. A bad `state` gives 400. A good `/done` saves 6 files (mode 600, directory mode 700), prints no secret, prints the install URL, and the server stops |
| `check.sh --try-with-gh-token` | All reads pass for both probe repositories. Limit 60 with no token and 5000 with the token. The 304 answers do not use the limit. |
| `check.sh` with no keys, and with a bad key | Exit code 2 with a clear message |
| `check.sh --try-with-gh-token` with a repository that does not exist | Exit code 1 |
