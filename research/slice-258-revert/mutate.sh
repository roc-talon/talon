#!/bin/bash
# Slice 258 revert check (test agent, TW12): a private reference of the code (reference/Login.roc, reference/LoginRoutes.roc) and mutants of it.
# The reference is NOT the implementation of the slice: the code agent writes worker/lib/Login.roc and worker/LoginRoutes.roc. The reference only shows that the tests can pass
# (`base` must pass all tests) and that each mutant is killed. The verify agent can apply the same mutations (the table in docs/slices/258-token-key-change.md section 10) to the real code.
# Mirror under .tmp/ (never /tmp). Each roc step is capped (16G, no swap, 600 s) and holds the shared heavy lock. One mutant at a time. The W2 steps build app.wasm (about 80 s each): run only the mutants that you need.
# Usage: mutate.sh [names...]     names: base-w0 base-w2 m1 .. m6 (W0 mutants) r1 .. r4 (W2 mutants). No argument: all (do not do that: pass the names).
set -u
ROOT=/home/george/dev/Karakatiza666/talon
M=$ROOT/.tmp/slice-258-mut
. $ROOT/scripts/env.sh
ROC_WORKER=${ROC_WORKER:-$ROOT/cloudflare-workers/.cache/nightlies/$ROC_TAG_WORKER/roc}
export TMPDIR=$ROOT/.tmp/tmp; mkdir -p "$TMPDIR"
cap() { flock $ROOT/.tmp/heavy.lock systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 600 "$@"; }
HERE=$ROOT/research/slice-258-revert
WANT=" $* "
want() { [ $# -eq 0 ] || [ "$WANT" = "  " ] || case "$WANT" in *" $1 "*) return 0;; *) return 1;; esac; }
mirror() { # mirror <dir>: worker/ (no wasm, no cases) and packages/records with the reference files
    rm -rf "$1"; mkdir -p "$1/worker" "$1/packages"
    ( cd $ROOT/worker && tar cf - --exclude=app.wasm --exclude=.roc-cfw --exclude=tests/cases --exclude=tests/selftest . ) | ( cd "$1/worker" && tar xf - )
    cp -r $ROOT/packages/records "$1/packages/"
    cp $HERE/reference/Login.roc "$1/worker/lib/Login.roc"
    cp $HERE/reference/LoginRoutes.roc "$1/worker/LoginRoutes.roc"
}
rep() { # file old new: one literal replacement, it must occur exactly once
    O1="$2" N1="$3" python3 -I -c '
import os,sys
p=sys.argv[1]; s=open(p).read()
o,n=os.environ["O1"],os.environ["N1"]
if s.count(o)!=1: sys.exit(1)
open(p,"w").write(s.replace(o,n))' "$1"
}
w0() { cap "$ROC_WORKER" test "$1/worker/tests/unit/w0.roc" --no-cache 2>&1 | grep -E "passed|failed|compiler errors|All \(" | tr '\n' ' '; echo; }
w2() { # w2 <dir> <filter>: build the Worker of the mirror, run the cases with the filter
    local d=$1 hash out
    mkdir -p "$d/out"
    ( cd "$d/worker" && cap "$ROC_WORKER" build --target=wasm32 --no-cache --opt=speed --output="$d/out/app.wasm" main.roc ) > "$d/build.log" 2>&1
    [ -f "$d/out/app.wasm" ] || { echo "BUILD FAILED"; tail -5 "$d/build.log"; return; }
    hash=$(sed -n 's#.*roc-cloudflare-workers/releases/download/[^/]*/\([A-Za-z0-9]*\)\.tar\.zst.*#\1#p' "$ROOT/worker/main.roc" | head -n 1)
    cp -r "$ROC_CACHE_DIR/packages/$hash/js" "$d/out/.roc-cfw"
    ( cd $ROOT && W2_DIR="$d/out" cap node worker/tests/run.mjs "$2" 2>&1 | grep -E "^FAIL|^w2: " | sed 's/ ([0-9]* ms)//' | tr '\n' ' ' ); echo
}
run() { # run <name> <layer> <file under worker/> <old> <new> <w2 filter>
    local n=$1 layer=$2 f=$3 d=$M/m-$1
    want "$n" || return
    mirror "$d"
    rep "$d/worker/$f" "$4" "$5" || { echo "$n: DID NOT APPLY"; rm -rf "$d"; return; }
    if [ "$layer" = w0 ]; then echo "$n: W0 $(w0 "$d")"; else echo "$n: W2 $(w2 "$d" "$6")"; fi
    rm -rf "$d"
}
if want base-w0; then mirror "$M/base"; echo "base-w0: $(w0 "$M/base")"; rm -rf "$M/base"; fi
if want base-w2; then mirror "$M/base"; echo "base-w2: $(w2 "$M/base" account/ct9)"; rm -rf "$M/base"; fi
L=lib/Login.roc; R=LoginRoutes.roc
# m1 the limit is 5, not 4 (Q258-3): `five` of W0
run m1 w0 $L 'max_old_keys = 4' 'max_old_keys = 5'
# m2 two keys with one kid are accepted (Q258-6)
run m2 w0 $L '			if $out.any(|seen| seen.kid == kid) {
				return Err(BadOldKeys("the kid ${kid} is twice in the set"))
			}
' ''
# m3 a bad entry is left out, as Jwk.parse_set does, not a fault (Q258-4)
run m3 w0 $L '		if parsed.len() != count {
			return Err(BadOldKeys("an entry is not a usable JWK"))
		}
' ''
# m4 the kid of TOKEN_KEY is accepted in the old set (Q258-6)
run m4 w0 $L '			if kid == current_kid {
				return Err(BadOldKeys("the kid ${kid} is the kid of TOKEN_KEY"))
			}
' ''
# m5 an old key wins over the current key with one kid
run m5 w0 $L '		if current.kid == kid {
			Ok(current)
		} else {
			old.find_first(|k| k.kid == kid).map_err(|NotFound| NoKey)
		}' '		match old.find_first(|k| k.kid == kid) {
			Ok(k) => Ok(k)
			Err(NotFound) => if (current.kid == kid) Ok(current) else Err(NoKey)
		}'
# m6 an entry that is not an Ed25519 key is accepted (Ed448, EC, RSA)
run m6 w0 $L '				_ => return Err(BadOldKeys("an entry is not an Ed25519 key"))' '				_ => {}'
# r1 the old set is read for each proof, also for a token of the current key (Q258-5)
run r1 w2 $R 'used = if (kid == key.kid) {' 'used = if (Bool.False) {' 'account/ct9-old-key'
# r2 an old token is checked with the public key of TOKEN_KEY, not with the key of its kid
run r2 w2 $R 'key: Jwk(used.public_json)' 'key: Jwk(key.public_json)' 'account/ct9-old-key'
# r3 a missing TOKEN_OLD_KEYS is a fault, not an empty set (Q258-5, the leak path)
run r3 w2 $R 'Env.secret!("TOKEN_OLD_KEYS").map_ok(|s| s.reveal()) ?? ""' 'Env.secret!("TOKEN_OLD_KEYS").map_ok(|s| s.reveal()).map_err(|e| Fault(Str.inspect(e)))?' 'account/ct9-old-key'
# r4 a bad set is dropped (an empty set) and not a 500 (Q258-4)
run r4 w2 $R 'olds = Login.old_keys(old_text, key.kid).map_err(|BadOldKeys(why)| Fault("TOKEN_OLD_KEYS is not a JWK Set of at most 4 Ed25519 keys with different kids: ${why}"))?' 'olds = Login.old_keys(old_text, key.kid) ?? []' 'account/ct9-old-key'
rm -rf "$M"
