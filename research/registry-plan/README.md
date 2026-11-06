# Registry plan probes (2026-11-01)

Probes for `docs/registry/PLAN.md` section A. Nothing here is registry code.

| Dir or file | What it shows |
| --- | --- |
| `hello-worker/worker/main.roc` | A Worker app with the 0.0.2 release URL, `roc-semver`, `roc-base58`, `roc-app-header` 0.1.0 and a local path package (`hello-worker/records/`, a stand-in for `packages/records`). Routes: `/`, `/semver/<v>`, `/b58` (BLAKE3 + base58), `/url?u=` (PackageUrl), `/d1` (a 64-bit id read with `CAST(id AS TEXT)`), `/gh` (an outbound fetch), and a 404 in problem form. |
| `hello-worker/worker/Route.roc` | A pure module in the app dir. `roc test main.roc` runs its `expect`s and the ones of the path package. |
| `hello-worker/worker/talon.toml` | `[tools] roc-cfw` (made by `tln add --tool`) and `[scripts] build` (R-WH12) |
| `hello-worker/worker/worker-count.js`, `wrangler-count.toml` | A test entry: a subclass of the shim class that wraps `env.DB`, and counts each D1 call (R-AP41 test). `GET /__d1count` gives the list. |
| `hello-worker/harness.mjs` | The W2 form: Miniflare from the global wrangler, local D1 from `schema.sql`, a fake GitHub (`outboundService`), the D1 count |
| `hello-worker/env.sh` | Isolated Talon state in `.state/` (gitignored, about 330 MB: a compiler and the package cache) |
| `json-extra/Extra.roc` | The derived `Json.parse` ignores unknown keys (R-AP44 holds), so a forbidden key such as `source` (R-MX5) needs its own check |

Commands (from `hello-worker/`):

```sh
ROC=../../../cloudflare-workers/.cache/nightlies/nightly-2026-10-31-f7bef6b/roc   # use the absolute path
(cd worker && $ROC build --target=wasm32 --no-cache --output=app.wasm main.roc)
(cd worker && cp -r ~/.cache/roc/packages/f352LLRKJCZ4JJVEocp3H9e4e6Sxa6Ym5CxZ1GZCpfd/js .roc-cfw && node .roc-cfw/cli.mjs sync --file main.roc)
node harness.mjs
(cd worker && wrangler d1 execute DB --local --file ../schema.sql && wrangler dev --local --port 8799)
. ./env.sh && (cd worker && tln run build)          # the R-WH12 path: roc build, then roc-cfw sync
```

Results are in `docs/registry/PLAN.md` section A.
