# generic-packages-check: use each generic package by its release URL

Question: does each released generic package work from a new app, with an empty cache, by its release URL (R-GP3)?

Run: `./run.sh [ROC] [app.roc...]`. The default `ROC` is `nightly-2026-10-14-38a3029` in `cloudflare-workers/.cache/nightlies/`. It needs the network.

| App | Package release | Result (2026-10-16) |
| --- | --- | --- |
| `app-header.roc` | roc-app-header 0.1.0, `HDQnwrX2Bcm8Jsf8RMC9ZdbVGwPiqD2nCLP7Zf1osfgU` | `roc check` exit 0, 3 of 3 tests pass |
| `semver.roc` | roc-semver 0.1.0, `KFKmXaroJeaPkQmAaqm83fTP9yhnEkTQwE97a5BtFSX` | `roc check` exit 0, 3 of 3 tests pass |
| `base58.roc` | roc-base58 0.1.0, `BgUuQGqWY94NikfEx4rBkWkgxYhngMim3ZEnD8wpM4NS` | `roc check` exit 0, 3 of 3 tests pass |
| `toml.roc` | roc-toml 0.1.0, `3icmtKz6XQUyHqu5JftcoJJT6a9YTND1B8z1UAmtqJpN` | `roc check` exit 0, 3 of 3 tests pass |

The tests are the usage examples of each package README.
