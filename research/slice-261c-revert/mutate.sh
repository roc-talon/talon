#!/bin/bash
# Mutation check of the 261c code (Talon slice 261c, TW12, the coordinator's order 2026-11-24): the log check of the header path in cli/lib/LogCheck.roc,
# LogProof.roc, LogKey.roc and the hook in InstallFlow.roc. Each mutant changes one or more places in a mirror copy under talon/.tmp/261c-mut-<stamp>/<name>/
# (the repo is not changed; each run makes a new stamp dir, nothing is deleted).
# Runs for each mutant: `roc test tests/unit/l0-9.roc` and the L2 cases logproof/ and registry/rg2-{config-direct,default-registry,example-add-short}
# (the L2 app is built in the mirror with --opt=dev). A mutant is killed when l0-9 has a failed test or an L2 case fails; a build that fails is reported apart.
# Each roc run and the L2 run are capped (16G, no swap), flocked, and have a time limit (300 s).
# Usage (repo root): research/slice-261c-revert/mutate.sh [name ...]   (no name: all). Writes <stamp dir>/RESULT.md and prints it.
set -u
TALON=$(cd "$(dirname "$0")/../.." && pwd)
export WORK=$TALON/.work # the shared roc package cache (scripts/env.sh: XDG_CACHE_HOME=$WORK/cache)
. "$TALON/scripts/env.sh"
export TMPDIR=$TALON/.tmp/tmp
STAMP=$TALON/.tmp/261c-mut-$(date +%s)
mkdir -p "$TMPDIR" "$STAMP"
CAP=(flock "$TALON/.tmp/heavy.lock" systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 300)
# name ~ file ~ old text ~ new text [~ file ~ old ~ new ...]   (each old text must occur exactly once). "reference" changes nothing: every run must pass.
# In the texts, \t is a tab and \n a new line. A mutant must build with no warning (roc build fails on a warning), so a skipped step keeps a run-time condition.
MUTANTS=(
"reference~cli/lib/LogCheck.roc~	run! : Fx, LogCheck.Facts => Try({}, Fail)~	run! : Fx, LogCheck.Facts => Try({}, Fail)"
"skip-no-check~cli/lib/InstallFlow.roc~	match log_check!(fx, request, loaded, scoped, edits, ran, after.found) {~	match (if (request.no_check) Ok({}) else log_check!(fx, request, loaded, scoped, edits, ran, after.found)) {"
"skip-dry-run~cli/lib/InstallFlow.roc~	match log_check!(fx, request, loaded, scoped, edits, ran, after.found) {~	match (if (request.dry_run) Ok({}) else log_check!(fx, request, loaded, scoped, edits, ran, after.found)) {"
"check-after-settle~cli/lib/InstallFlow.roc~	match log_check!(fx, request, loaded, scoped, edits, ran, after.found) {~	match (if (edits.len() > 1000000) log_check!(fx, request, loaded, scoped, edits, ran, after.found) else Ok({})) {~cli/lib/InstallFlow.roc~	done = settled?\n~	done = settled?\n\tlog_check!(fx, request, loaded, scoped, edits, ran, after.found)?\n"
"kept-no-cover~cli/lib/LogCheck.roc~		Ok(found) if found.cp.size >= run.need => { cp: found.cp, text: Err(None) }~		Ok(found) => { cp: found.cp, text: Err(None) }"
"no-consistency~cli/lib/LogCheck.roc~			Ok(found) => match Tlog.check_consistency(found.cp, current.cp, have) {~			Ok(found) => match Tlog.check_consistency(found.cp, found.cp, have) {"
"one-read~cli/lib/LogProof.roc~				1 => Again(2000)~				1 => Behind"
"no-sleep~cli/lib/LogCheck.roc~			fx.sleep!(ms)\n~			_ = ms\n"
"config-wins~cli/lib/LogKey.roc~		set = match setting.env {~		set = match (if (setting.config.is_ok()) Err(Unset) else setting.env) {"
"no-trim~cli/lib/LogKey.roc~Ok({ text: text.trim(), source: Env,~Ok({ text: text, source: Env,~cli/lib/LogKey.roc~Ok({ text: found.text.trim(), source: Config(found.path),~Ok({ text: found.text, source: Config(found.path),"
"copies-on-fail~cli/lib/LogCheck.roc~			Err(why) => return Err(stop(run, why, Ok(c), Ok(size)))~			Err(why) => {\n\t\t\t\t_ = fx.write_atomic!(\$new_tiles.keep_oks(|t| LogProof.copy_text(t).map_ok(|text| { path: tile_path(run, t.tile), content: text })))\n\t\t\t\treturn Err(stop(run, why, Ok(c), Ok(size)))\n\t\t\t}"
"no-copies~cli/lib/LogCheck.roc~	if writes.is_empty() {~	if writes.is_empty() or writes.len() > 0 {"
"offline-no-proof-passes~cli/lib/LogCheck.roc~				return Err(stop(run, Offline, Ok(open), Err(None)))~				_ = open\n\t\t\t\treturn Ok({})"
"offline-rows-unchecked~cli/lib/InstallFlow.roc~			rows = answered.concat(found.join_map(|c| c.rows))~			rows = answered.concat(found.join_map(|c| c.rows).take_first(0))"
)
ONLY=("$@")
RESULT=$STAMP/RESULT.md
{
echo "# 261c mutation check ($ROC_TAG, $(date -u +%Y-%m-%dT%H:%MZ))"
echo
echo "| Mutant | Result | Failing runs |"
echo "| --- | --- | --- |"
} > "$RESULT"
for m in "${MUTANTS[@]}"; do
	IFS='~' read -r -a parts <<< "$m"
	name=${parts[0]}
	if [ ${#ONLY[@]} -gt 0 ] && [[ ! " ${ONLY[*]} " =~ " $name " ]]; then continue; fi
	d=$STAMP/$name
	mkdir -p "$d/packages" "$d/cli" "$d/bot" "$d/tests/commands/cases/registry"
	cp -r "$TALON/packages/records" "$TALON/packages/resolve" "$d/packages/"
	cp -r "$TALON/cli/lib" "$d/cli/"; cp -r "$TALON/bot/lib" "$d/bot/"; cp -r "$TALON/scripts" "$d/"
	cp -r "$TALON/tests/unit" "$TALON/tests/fixtures" "$TALON/tests/lib.sh" "$d/tests/"
	cp "$TALON"/tests/commands/*.roc "$TALON/tests/commands/run.sh" "$d/tests/commands/"
	cp -r "$TALON/tests/commands/cases/logproof" "$d/tests/commands/cases/"
	for c in rg2-config-direct rg2-default-registry rg2-example-add-short; do cp -r "$TALON/tests/commands/cases/registry/$c" "$d/tests/commands/cases/registry/"; done
	applied=yes
	for ((i = 1; i < ${#parts[@]}; i += 3)); do
		file=${parts[i]}; old=$(printf '%b' "${parts[i+1]}"); new=$(printf '%b' "${parts[i+2]}")
		n=$(OLD="$old" python3 -c 'import os,sys; print(open(sys.argv[1]).read().count(os.environ["OLD"]))' "$d/$file")
		if [ "$n" != 1 ]; then applied="no ($file: old text found $n times)"; break; fi
		OLD="$old" NEW="$new" python3 -c 'import os,sys; p=sys.argv[1]; s=open(p).read(); open(p,"w").write(s.replace(os.environ["OLD"], os.environ["NEW"]))' "$d/$file"
	done
	if [ "$applied" != yes ]; then echo "| $name | NOT APPLIED: $applied | |" >> "$RESULT"; echo "$name: NOT APPLIED $applied"; continue; fi
	failing=()
	out=$(cd "$d/tests/unit" && "${CAP[@]}" "$ROC" test l0-9.roc 2>&1)
	echo "$out" | grep -qE 'All \([0-9]+\) tests passed' || failing+=("l0-9 ($(echo "$out" | grep -oE '[0-9]+ failed' | head -1))")
	if "${CAP[@]}" "$ROC" build "$d/tests/commands/main.roc" --no-cache --opt=dev --output="$d/l2" > "$d/build.log" 2>&1; then
		l2=$(L2BIN=$d/l2 "${CAP[@]}" "$d/tests/commands/run.sh" logproof/ registry/rg2- 2>&1)
		echo "$l2" > "$d/l2.log"
		fails=$(echo "$l2" | grep '^FAIL ' | sed 's/^FAIL //' | tr '\n' ' ')
		[ -n "$fails" ] && failing+=("L2: $fails")
		echo "$l2" | grep -q '^commands: ' || failing+=("L2: no summary (see $d/l2.log)")
	else
		failing+=("L2 build failed (see $d/build.log)")
	fi
	if [ ${#failing[@]} -gt 0 ]; then r=killed; else r=SURVIVED; fi
	if [ "$name" = reference ]; then
		if [ ${#failing[@]} -eq 0 ]; then r="all pass (good)"; else r="FAILS: the check is not valid"; fi
	fi
	echo "| $name | $r | ${failing[*]:-} |" >> "$RESULT"
	echo "$name: $r ${failing[*]:-}"
done
cat "$RESULT"
