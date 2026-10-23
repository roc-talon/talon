#!/usr/bin/env bash
# Which import forms of worker.js does Wrangler (esbuild) bundle? Each case writes a project in .work/<case>,
# with a fake shim outside the project (.work/cache/pkg/js, as the roc package cache), then runs
# `wrangler deploy --dry-run --outdir` and looks for the marker of the shim in the bundle.
# Usage: research/talon-scripts/probes/wrangler-resolve/run.sh   (needs wrangler on PATH, no network, no login)
set -uo pipefail
cd "$(dirname "$0")"
rm -rf .work && mkdir -p .work/cache/pkg/js
cat > .work/cache/pkg/js/index.js <<'JS'
import { helper } from './helpers.js';
export function makeHandler(m) { return { fetch() { return new Response(helper() + String(m)); } }; }
JS
echo "export const helper = () => 'SHIM_MARKER_42';" > .work/cache/pkg/js/helpers.js
cache=$PWD/.work/cache/pkg/js

mk() { # case, import specifier, extra wrangler.toml lines
  local d=.work/$1; mkdir -p "$d"
  printf "import { makeHandler } from '%s';\nexport default makeHandler(1);\n" "$2" > "$d/worker.js"
  printf 'name = "probe"\nmain = "worker.js"\ncompatibility_date = "2026-10-01"\n%b' "${3:-}" > "$d/wrangler.toml"
}
run() { # case, extra wrangler flags
  local d=.work/$1; shift
  if (cd "$d" && wrangler deploy --dry-run --outdir out "$@" > log.txt 2>&1) && grep -q SHIM_MARKER_42 "$d"/out/*.js; then
    echo "PASS $(basename "$d")"
  else
    echo "FAIL $(basename "$d"): $(grep -m1 -iE 'error|could not' "$d/log.txt")"
  fi
}

# A: a copy of the shim in a project directory, relative import.
mk a-copy './.roc-cfw/index.js'; cp -r "$cache" .work/a-copy/.roc-cfw; run a-copy
# B: a symlink in the project to the cache directory, relative import.
mk b-symlink './.roc-cfw/index.js'; ln -s "$cache" .work/b-symlink/.roc-cfw; run b-symlink
# C: bare specifier and [alias] in wrangler.toml to a project copy.
mk c-alias 'roc-cloudflare-workers' '[alias]\n"roc-cloudflare-workers" = "./.roc-cfw/index.js"\n'; cp -r "$cache" .work/c-alias/.roc-cfw; run c-alias
# D: bare specifier and [alias] to an absolute path outside the project (the cache).
mk d-alias-abs 'roc-cloudflare-workers' "[alias]\n\"roc-cloudflare-workers\" = \"$cache/index.js\"\n"; run d-alias-abs
# E: bare specifier and the --alias flag to the cache path (the path is not in a committed file).
mk e-flag 'roc-cloudflare-workers'; run e-flag --alias "roc-cloudflare-workers:$cache/index.js"
# F: an absolute import path in worker.js.
mk f-abs "$cache/index.js"; run f-abs
# G: bare specifier with no alias and no node_modules (the control: must fail).
mk g-bare 'roc-cloudflare-workers'; run g-bare
# H: bare specifier, node_modules/roc-cloudflare-workers as a symlink to the cache (no npm: a link that a tool makes).
mk h-nm-link 'roc-cloudflare-workers'; mkdir -p .work/h-nm-link/node_modules
printf '{"name":"roc-cloudflare-workers","type":"module","exports":{".":"./index.js"}}\n' > "$cache/package.json"
ln -s "$cache" .work/h-nm-link/node_modules/roc-cloudflare-workers; run h-nm-link
