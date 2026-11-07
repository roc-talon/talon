#!/usr/bin/env bash
# Round-trip check of dump.mjs. Usage: research/d1-dump/check.sh [remote|seed] [--corrupt]
#   remote   source is the remote database of binding DB (read only; needs ../.env at the repo root)
#   seed     source is a local database filled by seed.sql (no network)
#   --corrupt  the import file has its big ids written as floats (a negative test: the check must FAIL)
# Env DUMP_OPTS: options for dump.mjs, for example "--snapshot-rows 0 --page 1" (paged mode).
# Steps: 1 dump the source, 2 make an empty local database with the migrations, 3 import the dump,
#        4 dump it again, 5 compare the two dumps byte for byte, 6 compare 64-bit ids as CAST(x AS TEXT).
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
src=remote
corrupt=0
for a in "$@"; do
  case $a in
    remote | seed) src=$a ;;
    --corrupt) corrupt=1 ;;
    *) echo "usage: check.sh [remote|seed] [--corrupt]" >&2; exit 2 ;;
  esac
done
w="$here/.work/check-$src$([ $corrupt = 1 ] && echo -corrupt)"
rm -rf "$w"
mkdir -p "$w"
cd "$root/worker" || exit 2
fail=0
w_run() { npx wrangler "$@" ; }
# wrangler 4.151 refuses a local file that contains the text "BEGIN TRANSACTION" (src/d1/trimmer.ts). sql/0002_triggers.sql has it in
# a comment, so `migrations apply --local` fails on the original file. The copy below changes only that text, with the same statements.
mkdir -p "$w/cfg/sql"
for f in "$root"/sql/*.sql; do sed 's/BEGIN TRANSACTION/BEGIN-TRANSACTION/g' "$f" >"$w/cfg/sql/$(basename "$f")"; done
cat >"$w/cfg/wrangler.toml" <<TOML
name = "d1-dump-check"
compatibility_date = "2026-10-01"
[[d1_databases]]
binding = "DB"
database_name = "talon-registry-weur"
database_id = "6f2a8b71-8e6b-46c4-9e7d-6adb378fbbb2"
migrations_dir = "sql"
TOML
migrate() { w_run d1 migrations apply DB --local --config "$w/cfg/wrangler.toml" --persist-to "$1"; }

echo "== 1 dump the source ($src)"
if [ $src = remote ]; then
  set -a; . "$root/.env"; set +a
  node "$here/dump.mjs" ${DUMP_OPTS:-} --remote DB "$w/ref.sql" 2>"$w/ref.log" || { tail -5 "$w/ref.log"; echo "FAIL: dump of the source"; exit 1; }
  src_flags=(--remote)
else
  migrate "$w/src" >"$w/src-migrate.log" 2>&1 || { tail -5 "$w/src-migrate.log"; echo "FAIL: migrations (source)"; exit 1; }
  w_run d1 execute DB --local --persist-to "$w/src" --file "$here/seed.sql" >"$w/seed.log" 2>&1 || { tail -5 "$w/seed.log"; echo "FAIL: seed.sql"; exit 1; }
  node "$here/dump.mjs" ${DUMP_OPTS:-} --local --persist-to "$w/src" DB "$w/ref.sql" 2>"$w/ref.log" || { tail -5 "$w/ref.log"; echo "FAIL: dump of the source"; exit 1; }
  src_flags=(--local --persist-to "$w/src")
fi

echo "== 2 empty local database with the migrations"
migrate "$w/dst" >"$w/dst-migrate.log" 2>&1 || { tail -5 "$w/dst-migrate.log"; echo "FAIL: migrations"; exit 1; }

echo "== 3 import"
if [ $corrupt = 1 ]; then node "$here/corrupt.mjs" "$w/ref.sql" "$w/import.sql"; else cp "$w/ref.sql" "$w/import.sql"; fi
if ! w_run d1 execute DB --local --persist-to "$w/dst" --file "$w/import.sql" >"$w/import.log" 2>&1; then
  grep -iE 'error|abort|constraint|leaf|label|sweep' "$w/import.log" | head -5
  echo "FAIL: import"; exit 1
fi

echo "== 4 dump again"
node "$here/dump.mjs" ${DUMP_OPTS:-} --local --persist-to "$w/dst" DB "$w/out.sql" 2>"$w/out.log" || { tail -5 "$w/out.log"; echo "FAIL: second dump"; exit 1; }

echo "== 5 byte compare of the two dumps"
if cmp -s "$w/ref.sql" "$w/out.sql"; then echo "same ($(wc -l <"$w/ref.sql") lines, $(wc -c <"$w/ref.sql") bytes)"; else
  echo "different:"; diff "$w/ref.sql" "$w/out.sql" | head -6 | cut -c1-200; fail=1; fi

echo "== 6 64-bit ids as CAST(x AS TEXT), source and imported"
spot=(
  "SELECT CAST(min(id) AS TEXT) a, CAST(max(id) AS TEXT) b, count(*) n FROM names"
  "SELECT CAST(min(artifact) AS TEXT) a, CAST(max(artifact) AS TEXT) b, count(*) n FROM artifacts"
  "SELECT CAST(form AS TEXT) a, CAST(version AS TEXT) b, CAST(artifact AS TEXT) c, CAST(repo AS TEXT) d FROM releases ORDER BY log_index LIMIT 5"
  "SELECT CAST(min(form) AS TEXT) a, CAST(max(form) AS TEXT) b, CAST(min(version) AS TEXT) c, CAST(max(version) AS TEXT) d, CAST(min(artifact) AS TEXT) e, CAST(max(artifact) AS TEXT) f FROM releases"
  "SELECT CAST(min(nightly) AS TEXT) a, CAST(max(nightly) AS TEXT) b FROM toolchains"
  "SELECT CAST(min(repo) AS TEXT) a, CAST(max(repo) AS TEXT) b FROM repos"
)
rows() { # args: wrangler flags..., sql
  local sql=${*: -1}; local flags=("${@:1:$#-1}")
  npx wrangler d1 execute DB "${flags[@]}" --json --command "$sql" 2>/dev/null | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s.slice(s.indexOf("[")));console.log(JSON.stringify(j[0].results))})'
}
for q in "${spot[@]}"; do
  a=$(rows "${src_flags[@]}" "$q")
  b=$(rows --local --persist-to "$w/dst" "$q")
  if [ -n "$a" ] && [ "$a" = "$b" ]; then echo "same: ${a:0:110}"; else echo "DIFFERENT"; echo "  source:   ${a:0:200}"; echo "  imported: ${b:0:200}"; fail=1; fi
done

echo "== row counts (second dump)"
grep '^-- table' "$w/out.sql" | sed 's/^-- table //'
if [ $fail = 0 ]; then echo "RESULT: PASS"; else echo "RESULT: FAIL"; fi
exit $fail
