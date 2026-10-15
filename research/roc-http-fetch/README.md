# roc-http-fetch: does roc fetch a package from an http:// URL? (TQ4)

Question: can an L4 test case serve packages to the real `roc` from a local fake HTTP server?

| File | Content |
| --- | --- |
| `run.sh` | Bundles a small package with `roc bundle`, serves it with `python3 -m http.server` on `127.0.0.1`, and runs `roc check` on a package that depends on it through 5 URL forms. Each case has its own `XDG_CACHE_HOME`. |

Run: `./run.sh [ROC]`. It prints one line for each case: the exit code of `roc check`, and if the package is in `packages/<hash>/`. The default `ROC` is the 10-09 nightly in `cloudflare-workers/.cache/nightlies/`. `PORT` sets the port (default 18765).

## Result (2026-10-15, `nightly-2026-10-09-258ab27`)

| Case | URL | `roc check` | Fetched into `packages/<hash>/` |
| --- | --- | --- | --- |
| loopback | `http://127.0.0.1:PORT/1.0.0/<hash>.tar.zst` | 0 errors (2 warnings: deprecated `module` header) | Yes |
| localhost | `http://localhost:PORT/1.0.0/<hash>.tar.zst` | 0 errors | Yes |
| prefixed | `http://127.0.0.1:PORT/greet-1.0.0/<hash>.tar.zst` (a tag prefix) | 0 errors | Yes |
| lan | `http://10.255.255.1:PORT/...` | Error "insecure package url", no connect | No |
| name | `http://github.com/x/y/releases/download/1.0.0/...` | Error "insecure package url" | No |

The server got 3 requests (loopback, localhost and prefixed only). The roc source (`roc:src/base/url.zig`, `parseUrlPath`) takes the `X.Y.Z` run inside a path segment, and the text around it (`greet-`) stays in the group.

Source agrees: `roc:src/unbundle/download.zig` (`validateUrl`, `base.url.isSafeUrl`) allows `https://` to any host, and `http://` only to `127.0.0.1`, `::1` and `localhost` (verified to resolve to loopback).

## Effect on Talon

| Item | Result |
| --- | --- |
| A fixture with a loopback URL in the header | roc fetches it. But the host is part of the group (Design 2), so this is a different package from the `github.com` one. |
| A fixture that must keep a `github.com` URL in the header | roc cannot fetch it from the fake server. The case pre-fills `packages/<hash>/` (Q2, CLI 7.2). The decision is in CLI 1, "Test hooks". |
