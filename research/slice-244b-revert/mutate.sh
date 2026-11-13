#!/bin/bash
# Slice 244b mutation check (test agent, TW12). Mirror under .tmp/ (not /tmp). Each run is capped (16G, no swap, 600 s). One mutant at a time.
# Usage: mutate.sh [mutant names...]   (no argument: all). L0=0 skips the l0-9 driver.
set -u
ROOT=/home/george/dev/Karakatiza666/talon
M=$ROOT/.tmp/slice-244b-mut
. $ROOT/scripts/env.sh
ROC=${ROC244:-$HOME/.cache/roc/toolchains/nightly-2026-11-06-34f137a/roc}
export TMPDIR=$ROOT/.tmp/tmp; mkdir -p $TMPDIR
cap() { systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 600 "$@"; }
rm -rf $M && mkdir -p $M/mut/cli $M/mut/tests $M/mut/worker
cp -r $ROOT/cli/lib $M/mut/cli/ && cp -r $ROOT/bot $M/mut/ && cp -r $ROOT/packages $M/mut/
cp -r $ROOT/tests/commands $M/mut/tests/ && rm -rf $M/mut/tests/commands/cases && cp -r $ROOT/tests/unit $M/mut/tests/ && cp $ROOT/worker/wrangler.toml $M/mut/worker/ && cp -r $ROOT/tests/fixtures $M/mut/tests/
WANT=" $* "
want() { [ $# -eq 0 ] || [ "$WANT" = "  " ] || case "$WANT" in *" $1 "*) return 0;; *) return 1;; esac; }
T="audit/"
TX="audit/ index/ registry/"
run() { # name file sed-expr
  n=$1; f=$2; e=$3
  want $n || return
  d=$M/m-$n; rm -rf $d; cp -r $M/mut $d
  sed -i "$e" $d/$f
  if cmp -s $M/mut/$f $d/$f; then echo "$n: SED DID NOT APPLY"; return; fi
  if [ "${L0:-1}" = 1 ]; then
    cap "$ROC" test $d/tests/unit/l0-9.roc > $d/l0.log 2>&1
    echo "$n: L0 exit=$? $(grep -E 'passed|failed|errors' $d/l0.log | tail -2 | tr '\n' ' ')"
  fi
  cap "$ROC" build $d/tests/commands/main.roc --no-cache --opt=dev --output=$d/l2 > $d/build.log 2>&1
  [ -x $d/l2 ] || { echo "$n: L2 BUILD FAILED"; rm -rf $d; return; }
  echo "$n: L2 $(cd $ROOT && L2BIN=$d/l2 cap tests/commands/run.sh ${TT:-$T} 2>&1 | grep -E '^(FAIL|commands:)' | tr '\n' ' ')"
  rm -rf $d
}
if want base; then
  [ "${L0:-1}" = 1 ] && { cap "$ROC" test $M/mut/tests/unit/l0-9.roc > $M/base.log 2>&1; echo "base l0-9: exit=$? $(grep -E 'passed|failed|errors' $M/base.log | tail -2 | tr '\n' ' ')"; }
  cap "$ROC" build $M/mut/tests/commands/main.roc --no-cache --opt=dev --output=$M/base-l2 > $M/base-build.log 2>&1
  echo "base L2: $(cd $ROOT && L2BIN=$M/base-l2 cap tests/commands/run.sh $TX 2>&1 | grep -E '^(FAIL|commands:)' | tr '\n' ' ')"
fi
AD=cli/lib/AuditDirect.roc; AC=cli/lib/AuditCheck.roc; AF=cli/lib/AuditFlow.roc; GH=cli/lib/Github.roc; PG=cli/lib/PrivacyGuard.roc
# d1 R-AU13 order: prerelease wins over asset-replaced
run d1 $AD 's/if !r.assets.contains(e.hash) {/if !r.assets.contains(e.hash) and !r.prerelease {/'
# d2 a draft is the release
run d2 $AD 's/r.tag == tag and !r.draft/r.tag == tag/'
# d3 v2.1.0 is the tag 2.1.0 (a prefix v is dropped)
run d3 $AD 's/r.tag == tag and/r.tag.drop_prefix("v") == tag.drop_prefix("v") and/'
# d4 new_hash with 1 or more other assets (R-DI4: exactly one)
run d4 $AD 's/if others.len() == 1 others.first()/if others.len() >= 1 others.first()/'
# d5 the header asset and another asset: asset-replaced
run d5 $AD 's/if !r.assets.contains(e.hash) {/if others.len() > 0 {/'
# d6 moved successor: same name in another case is a successor
run d6 $AD 's/name.with_ascii_lowercased() == old.with_ascii_lowercased() Err(None)/name == old Err(None)/'
# d7 repos_of: a repository listed twice
run d7 $AD 's/if acc.contains(r) acc else acc.append(r)/acc.append(r)/'
# d8 of_guarded: a refused repository is not counted in checked
run d8 $AC 's/missing = \(.*\)$/missing = \1/; s/{ ..acc, checked: acc.checked + 1, findings: acc.findings.append(missing) }/{ ..acc, findings: acc.findings.append(missing) }/'
# d9 registry!: the hashes of a refused repository stay in the query
run d9 $AF 's/kept = entries.keep_if(.*$/kept = entries/'
# d10 guard collect: a refused repository stops the audit
TT="$TX" run d10a $PG 's/Refused => if collect {/Refused => if Bool.False {/'
# d10b guard check!: a refused repository does not stop other commands (leak)
TT="$TX" run d10b $PG 's/Refused => if collect {/Refused => if Bool.True {/'
# d11 audit_list: a 404 of any page is gone (leak into other commands)
TT="$TX" run d11 $GH 's/(404, _) if run.audit and n == 1 =>/(404, _) if n == 1 =>/'
# d12 a redirect to any location is followed (not only the same API base)
TT="$TX" run d12 $GH 's/Ok(there) if there.starts_with(run.net.api) =>/Ok(there) =>/'
# d13 the pages of a redirected list are written to the cache
TT="$TX" run d13 $GH 's/if is_list(answer.body) and !state.moved \[/if is_list(answer.body) [/'
rm -rf $M
