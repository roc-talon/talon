#!/bin/bash
# Slice 249 mutation check (test agent, TW12). Mirror under .tmp/ (not /tmp). Each run is capped (16G, no swap, 600 s) and holds the shared heavy lock. One mutant at a time.
# Usage: mutate.sh [mutant names...]   (no argument: all). Tests: the l0-6 and l0-9 drivers, L2 `yank/ audit/ registry/au7 update/au7 verify/au7 publish/`. L0F restricts the L0 files; L2=0 skips L2.
set -u
ROOT=/home/george/dev/Karakatiza666/talon
M=$ROOT/.tmp/slice-249-mut
. $ROOT/scripts/env.sh   # ROC: the CLI compiler (ROC_TAG)
ROC=${ROC249:-$ROC}
export TMPDIR=$ROOT/.tmp/tmp; mkdir -p $TMPDIR
cap() { flock $ROOT/.tmp/heavy.lock systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 600 "$@"; }
rm -rf $M && mkdir -p $M/mut/cli $M/mut/tests $M/mut/worker
cp -r $ROOT/cli/lib $M/mut/cli/ && cp -r $ROOT/bot $M/mut/ && cp -r $ROOT/packages $M/mut/
cp -r $ROOT/tests/commands $M/mut/tests/ && rm -rf $M/mut/tests/commands/cases && cp -r $ROOT/tests/unit $M/mut/tests/ && cp $ROOT/worker/wrangler.toml $M/mut/worker/ && cp -r $ROOT/tests/fixtures $M/mut/tests/
WANT=" $* "
want() { [ $# -eq 0 ] || [ "$WANT" = "  " ] || case "$WANT" in *" $1 "*) return 0;; *) return 1;; esac; }
T="yank/ audit/ registry/au7 update/au7 verify/au7 publish/"
l0() { # dir: runs l0-6 and l0-9; prints one summary
  local d=$1 out="" f
  # L0F: the files to run (default all). exit=124 is the 600 s limit (a loop counts as caught).
  for f in ${L0F:-tests/unit/l0-6.roc tests/unit/l0-9.roc}; do
    cap "$ROC" test $d/$f > $d/l0-$(basename $f).log 2>&1
    rc=$?
    out="$out $(basename $f .roc): exit=$rc $(grep -E 'passed|failed|errors' $d/l0-$(basename $f).log | tail -1 | sed 's/ in .*//')$([ $rc -ge 124 ] && tail -2 $d/l0-$(basename $f).log | tr '\n' ' ')."
  done
  echo "$out"
}
run() { # name file sed-expr
  n=$1; f=$2; e=$3
  want $n || return
  d=$M/m-$n; rm -rf $d; cp -r $M/mut $d
  sed -i "$e" $d/$f
  [ -n "${4:-}" ] && { sed -i "$5" $d/$4; cmp -s $M/mut/$4 $d/$4 && { echo "$n: SED2 DID NOT APPLY"; return; }; }
  if cmp -s $M/mut/$f $d/$f; then echo "$n: SED DID NOT APPLY"; return; fi
  echo "$n: L0$(l0 $d)"
  [ "${L2:-1}" = 1 ] || { rm -rf $d; return; }
  cap "$ROC" build $d/tests/commands/main.roc --no-cache --opt=dev --output=$d/l2 > $d/build.log 2>&1
  [ -x $d/l2 ] || { echo "$n: L2 BUILD FAILED"; rm -rf $d; return; }
  echo "$n: L2 $(cd $ROOT && L2BIN=$d/l2 cap tests/commands/run.sh $T 2>&1 | grep -E '^(FAIL|commands:)' | tr '\n' ' ')"
  rm -rf $d
}
if want base && [ "${L2:-1}" = 1 ]; then
  echo "base: L0$(l0 $M/mut)"
  cap "$ROC" build $M/mut/tests/commands/main.roc --no-cache --opt=dev --output=$M/base-l2 > $M/base-build.log 2>&1
  echo "base L2: $(cd $ROOT && L2BIN=$M/base-l2 cap tests/commands/run.sh $T 2>&1 | grep -E '^(FAIL|commands:)' | tr '\n' ' ')"
fi
YC=cli/lib/YankCheck.roc; YF=cli/lib/YankFlow.roc; RY=packages/records/Yank.roc; AR=cli/lib/AuditReport.roc; AF=cli/lib/AuditFlow.roc
# y1 B4: undo_reason after the reason check (Q629-2)
run y1 $YF '/YankCheck.undo_reason({ undo, reason })?/{h;d};/YankCheck.reason(reason)?/{G}'
# y2 B4: GITHUB_REPOSITORY before undo_reason
run y2 $YF '/YankCheck.undo_reason({ undo, reason })?/{h;d};/job = YankCheck.job(env)?/{G}'
# y3 reason limit: 500 bytes is too long (off by one)
run y3 $RY 's/if bytes.len() > reason_limit {/if bytes.len() >= reason_limit {/'
# y3b reason limit: 501 bytes is good
run y3b $RY 's/if bytes.len() > reason_limit {/if bytes.len() > reason_limit + 1 {/'
# y4 Cc: U+007F is not a control character
run y4 $RY 's/bytes.any(|b| b < 32 or b == 127)/bytes.any(|b| b < 32)/'
# y5 the tag match ignores case
run y5 $YC 's/row.tag == Ok(input.tag)/row.tag.map_ok(|t| t.with_ascii_lowercased()) == Ok(input.tag.with_ascii_lowercased())/'
# y6 two rows with one tag: the first is taken (no exit 1)
run y6 $YC 's/\[first, second, \.\.\] => Err(.*/[first, ..] => Ok(first)/'
# y7 PUT with no reason sends {} always
run y7 $YC 's/body: WireYank.encode_request({ reason: input.reason })/body: WireYank.encode_request({ reason: Err(None) })/'
# y7b DELETE with a JSON content type
run y7b $YC 's/Registry.headers({ version: input.version, body: None }).append(auth), body: ""/Registry.headers({ version: input.version, body: Json }).append(auth), body: ""/'
# y8 the R-AP1 read may come from the cache (no fresh read)
run y8 $YF 's/newest: Bool.True, bookmark/newest: Bool.False, bookmark/'
# y9 a 401 repeats the old token (no new token)
run y9 $YF 's/new_token = token!(fx, run)?/new_token = state.token/'
# y10 the no-answer text of an undo says "yank"
run y10 $YC 's/done = if input.undo "undo" else "yank"/done = "yank"/'
# y11 the R-AP1 stop gives direct advice (needs false), in release
run y11a $YC 's/source: input.?source ?? "", needs: Bool.True }))/source: input.?source ?? "", needs: Bool.False }))/'
# y11b the same in the read of R-AP1 (get_needs!)
run y11b $YF 's/source: setting, needs: Bool.True })/source: setting, needs: Bool.False })/'
# y12 audit: a registry prints the no-yank note (text)
run y12 $AR 's/Registry => \[\]$/Registry => if report.no_yank_data ["note: no yank and advisory data without a registry"] else []/' $AF 's/no_yank_data: state.index == Direct/no_yank_data: Bool.True/'
# y12j audit: a registry has no-yank-data in --json notes
run y12j $AR 's/report.no_yank_data and report.index == Direct/report.no_yank_data/' $AF 's/no_yank_data: state.index == Direct/no_yank_data: Bool.True/'
# y13 the successor fix text is off (a successor does not change the fix)
run y13 $AR 's/follows = f.successor != Err(None)/follows = Bool.False/'
rm -rf $M
