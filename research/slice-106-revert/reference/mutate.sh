#!/usr/bin/env bash
# Revert check of slice 106: each mutation changes the private reference (overlay/), runs the W0 tests and the reads W2 cases, and must fail one of them.
#   research/slice-106-revert/reference/mutate.sh [name ...]
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
. "$root/scripts/env.sh"
ROCW=$root/cloudflare-workers/.cache/nightlies/$ROC_TAG_WORKER/roc
cp -r "$here/overlay" "$here/overlay.orig"
mutate() { # mutate <file> <old> <new>
  python3 - "$1" "$2" "$3" <<'PY'
import sys
p,old,new=sys.argv[1:4]
s=open(p).read()
assert old in s, 'pattern not found: '+old
open(p,'w').write(s.replace(old,new,1))
PY
}
run_one() {
  name=$1; shift
  rm -rf "$here/overlay"; cp -r "$here/overlay.orig" "$here/overlay"
  case $name in
    no-pragma)      mutate "$here/overlay/lib/Reads.roc" "has_no_cache(h.cache_control) or has_no_cache(h.pragma)" "has_no_cache(h.cache_control)" ;;
    no-put-bypass)  mutate "$here/overlay/ReadRoutes.roc" "Cache.default.put!(key, fresh).map_err(fault)?" "(if (bypass) fresh else Cache.default.put!(key, fresh).map_err(fault)?)" ;;
    etag-exact)     mutate "$here/overlay/lib/Reads.roc" 'v.split_on(",").any(' 'v.split_on("~").any(' ;;
    session-any)    mutate "$here/overlay/lib/Reads.roc" 'Ok(v) => if (v.trim() == "") Any else After(v.trim())' 'Ok(_) => Any' ;;
    page-1001)      mutate "$here/overlay/lib/Reads.roc" 'page_limit = 1000' 'page_limit = 1001' ;;
    key-no-query)   mutate "$here/overlay/ReadRoutes.roc" 'key = req.url()' 'key = req.url().split_on("?").first() ?? ""' ;;
    stale-ge)       mutate "$here/overlay/lib/Reads.roc" 'c.now_ms - at > 2 * interval_ms' 'c.now_ms - at >= 2 * interval_ms' ;;
    after-ge)       mutate "$here/overlay/ReadRoutes.roc" 'WHERE log_index > ? ORDER BY' 'WHERE log_index >= ? ORDER BY' ;;
    two-calls)      mutate "$here/overlay/ReadRoutes.roc" 'session.batch!(stmts).map_err(fault)' 'session.batch!(stmts.take_first(1)).map_err(fault)?.concat(session.batch!(stmts.drop_first(1)).map_err(fault)?) |> Ok' ;;
    no-fold)        mutate "$here/overlay/lib/Reads.roc" '"${owner}/${repo}".with_ascii_lowercased().to_utf8()' '"${owner}/${repo}".to_utf8()' ;;
    maxage-bypass)  mutate "$here/overlay/lib/Reads.roc" 'd.trim().caseless_ascii_equals("no-cache"))' 'd.trim().caseless_ascii_equals("no-cache") or d.trim() == "max-age=0")' ;;
    after-zero)     mutate "$here/overlay/lib/Reads.roc" ' and (t == "0" or !t.starts_with("0"))' '' ;;
    nofold-group)   mutate "$here/overlay/lib/Reads.roc" 'form_id = |form| Id.name_id(2, form.to_utf8())' 'form_id = |form| Id.name_id(2, form.with_ascii_lowercased().to_utf8())' ;;
    order-desc)     mutate "$here/overlay/ReadRoutes.roc" 'WHERE r.repo = ? ORDER BY r.log_index"' 'WHERE r.repo = ? ORDER BY r.log_index DESC"' ;;
  esac
  rm -rf "$here/worker"
  out=$("$here/run-ref.sh" reads 2>&1; true)
  w2=$(echo "$out" | grep -a "^w2:" | tail -1)
  mkdir -p "$here/w0tmp"
  w0=$(cd "$here/worker" && "$ROCW" test tests/unit/w0.roc --no-cache 2>&1 | grep -a "ReadsTest" | wc -l)
  echo "$name: W2 [$w2] W0 ReadsTest failures: $w0"
}
names=${*:-no-pragma no-put-bypass etag-exact session-any page-1001 key-no-query stale-ge after-ge two-calls order-desc}
for n in $names; do run_one "$n"; done
rm -rf "$here/overlay"; mv "$here/overlay.orig" "$here/overlay"; rm -rf "$here/w0tmp"
