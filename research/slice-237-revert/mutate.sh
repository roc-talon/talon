#!/bin/bash
# Slice 237 mutation check (manager). Each mutation gets its own mirror, a private L2 build, and the named L2 cases, or `roc test` of an l0 driver.
set -u
ROOT=/home/george/dev/Karakatiza666/talon
R=$ROOT/research/slice-237-revert
. $ROOT/scripts/env.sh
rm -rf $R/mut && mkdir -p $R/mut/cli $R/mut/tests $R/mut/packages $R/mut/worker
cp -r $ROOT/cli/lib $R/mut/cli/ && cp -r $ROOT/bot $R/mut/ && cp -r $ROOT/packages/records $ROOT/packages/resolve $R/mut/packages/
cp -r $ROOT/tests/commands $R/mut/tests/ && rm -rf $R/mut/tests/commands/cases && cp -r $ROOT/tests/unit $R/mut/tests/ && cp $ROOT/worker/wrangler.toml $R/mut/worker/ && cp -r $ROOT/tests/fixtures $R/mut/tests/
l2() { # name file sed-expr cases...
  n=$1; f=$2; e=$3; shift 3
  d=$R/m-$n; rm -rf $d; cp -r $R/mut $d
  sed -i "$e" $d/$f
  if cmp -s $R/mut/$f $d/$f; then echo "$n: SED DID NOT APPLY"; return; fi
  "$ROC" build $d/tests/commands/main.roc --no-cache --output=$d/l2 > $d/build.log 2>&1
  [ -x $d/l2 ] || { echo "$n: BUILD FAILED"; return; }
  echo "$n: $(cd $ROOT && L2BIN=$d/l2 tests/commands/run.sh "$@" 2>&1 | grep -E '^(FAIL|commands:)' | tr '\n' ' ')"
}
l0() { # name file sed-expr driver
  n=$1; f=$2; e=$3; drv=$4
  d=$R/m-$n; rm -rf $d; cp -r $R/mut $d
  sed -i "$e" $d/$f
  if cmp -s $R/mut/$f $d/$f; then echo "$n: SED DID NOT APPLY"; return; fi
  echo "$n: $("$ROC" test $d/tests/unit/$drv 2>&1 | grep -E 'passed|failed|errors' | tail -3 | tr '\n' ' ')"
}
echo "base l0-9: $("$ROC" test $R/mut/tests/unit/l0-9.roc 2>&1 | grep -E 'passed|failed|errors' | tail -3 | tr '\n' ' ')"
# m1: the dir of the registry of the run is also a candidate
l0 m1 cli/lib/Gc.roc 's/e.is_dir and e.path != own).map/e.is_dir).map/' l0-9.roc
l2 m1b cli/lib/Gc.roc 's/e.is_dir and e.path != own).map/e.is_dir).map/' gc/gc15-registry-copies
# m2: a page is aged by its body, not by its meta
l0 m2 cli/lib/Gc.roc 's/Ok(meta) => meta.mtime/Ok(_) => e.mtime/' l0-9.roc
# m3: a bad registry value does not stop GC (it acts as direct)
l2 m3 cli/lib/CacheGc.roc 's/current = IndexQuery.setting({ flag: registry.flag, env: registry.env, config: config.registry })?/current = IndexQuery.setting({ flag: registry.flag, env: registry.env, config: config.registry }) ?? Direct/' gc/gc15-registry-copies
# m4: other registry dirs go with no age check
l2 m4 cli/lib/CacheGc.roc 's/builds: Gc.expired({ dirs: candidates.builds.concat(facts.index.dirs), measured,/builds: facts.index.dirs.concat(Gc.expired({ dirs: candidates.builds, measured,/; s/span: facts.age }).concat(x_dirs).concat(pages),/span: facts.age })).concat(x_dirs).concat(pages),/' gc/gc15-registry-copies
# m5: the pages are not removed
l2 m5 cli/lib/CacheGc.roc 's/span: facts.age }).concat(x_dirs).concat(pages),/span: facts.age }).concat(x_dirs),/' gc/gc15-registry-copies
rm -rf $R/mut $R/m-*
