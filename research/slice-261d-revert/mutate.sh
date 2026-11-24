#!/bin/bash
# Mutation check of the 261d code (Talon slice 261d, TW12, the coordinator's order 2026-11-24): the log check of tools and compilers in cli/lib/LogCheck.roc
# (tool!, compiler!), LogProof.roc (check_leaf), RocInstall.roc (offer_noted!), ToolFlow.roc, XFlow.roc, XTake.roc. Each mutant changes one or more places in a mirror copy under talon/.tmp/261d-mut-<stamp>/<name>/
# (the repo is not changed; each run makes a new stamp dir, nothing is deleted).
# Runs for each mutant: `roc test tests/unit/l0-9.roc` and the L2 cases logproof/ and the old cases of the touched flows (OLD below)
# (the L2 app is built in the mirror with --opt=dev). A mutant is killed when l0-9 has a failed test or an L2 case fails; a build that fails is reported apart.
# Each roc run and the L2 run are capped (16G, no swap), flocked, and have a time limit (300 s).
# Usage (repo root): research/slice-261d-revert/mutate.sh [name ...]   (no name: all). Writes <stamp dir>/RESULT.md and prints it.
set -u
TALON=$(cd "$(dirname "$0")/../.." && pwd)
export WORK=$TALON/.work # the shared roc package cache (scripts/env.sh: XDG_CACHE_HOME=$WORK/cache)
. "$TALON/scripts/env.sh"
export TMPDIR=$TALON/.tmp/tmp
STAMP=$TALON/.tmp/261d-mut-$(date +%s)
mkdir -p "$TMPDIR" "$STAMP"
CAP=(flock "$TALON/.tmp/heavy.lock" systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 300)
# name ~ file ~ old text ~ new text [~ file ~ old ~ new ...]   (each old text must occur exactly once). "reference" changes nothing: every run must pass.
# In the texts, \t is a tab and \n a new line. A mutant must build with no warning (roc build fails on a warning), so a skipped step keeps a run-time condition.
OLD=(registry/sc3-tool-install registry/sc4-x-registry registry/cv1-roc-default tool/tk1-takeover roc/up1-update x/x1-run)
MUTANTS=(
"reference~cli/lib/LogCheck.roc~	tool! : Fx, LogCheck.Tool => Try({}, Fail)~	tool! : Fx, LogCheck.Tool => Try({}, Fail)"
"tool-never-match~cli/lib/LogCheck.roc~t.rows.find_first(|r| r.url == t.url)~t.rows.find_first(|r| r.url == t.url and r.url == \"\")"
"tool-group-only~cli/lib/LogCheck.roc~t.rows.find_first(|r| r.url == t.url)~t.rows.find_first(|r| t.url.starts_with(\"https://\${r.group.drop_suffix(\"{v}/\")}\"))"
"tool-registry-skipped~cli/lib/ToolFlow.roc~	Ok(Registry(origin)) => Ok(origin)~	Ok(Registry(origin)) => if (origin.is_empty()) Ok(origin) else Err(None)"
"tool-after-build~cli/lib/ToolFlow.roc~	ToolFlow.log_check_for!(fx, args, facts, { registry: gathered.registry, log_key: gathered.log_key, rows: listed.rows }, bundle.url)?\n	check_platform!~	check_platform!~cli/lib/ToolFlow.roc~	compile!(fx, args, plan, facts, bundle)\n}~	done = compile!(fx, args, plan, facts, bundle)?\n	ToolFlow.log_check_for!(fx, args, facts, { registry: gathered.registry, log_key: gathered.log_key, rows: listed.rows }, bundle.url)?\n	Ok(done)\n}"
"x-not-checked~cli/lib/XFlow.roc~	ToolFlow.log_check_for!(fx, args, facts, run.log, bundle.url)?~	_ = run.log"
"takeover-not-checked~cli/lib/XTake.roc~Release(rel) => LogCheck.tool!(fx, { roots: facts.roots, base: run.log.base, offline: args.offline, env: facts.env, config: run.log.config, name: facts.name, url: rel.url, rows: run.log.rows })?~Release(_) => if (args.offline) {} else {}"
"compiler-tag-only~cli/lib/RocInstall.roc~row.tag == id and row.target == target)~row.tag == id and (row.target == target or Bool.True))"
"compiler-largest-index~cli/lib/RocInstall.roc~(a.log_index > b.log_index) After else Same).first()~(a.log_index > b.log_index) After else Same).last()"
"compiler-no-row-skips~cli/lib/RocInstall.roc~row.tag == id and row.target == target)~row.tag == id and row.target == target and row.size == 0)"
"compiler-registry-skipped~cli/lib/RocInstall.roc~			Registry(r) => {\n				target = Nightlies.target(system)~			Registry(r) if r.origin.is_empty() => {\n				target = Nightlies.target(system)~cli/lib/RocInstall.roc~			Direct => {}\n		}\n		item = ~			_ => {}\n		}\n		item = "
"compiler-install-only~cli/lib/RocInstall.roc~			Registry(r) => {\n				target = Nightlies.target(system)~			Registry(r) if !run.id.starts_with(\"@\") => {\n				target = Nightlies.target(system)~cli/lib/RocInstall.roc~			Direct => {}\n		}\n		item = ~			_ => {}\n		}\n		item = "
"leaf-no-sha256~cli/lib/LogProof.roc~sha256: c.hash.drop_prefix(\"sha256:\") }, leaf)~sha256: leaf.hash.drop_prefix(\"sha256:\") }, leaf)"
"leaf-release-compare~cli/lib/LogProof.roc~		if c.group.starts_with(\"roc-lang/nightlies:\") {~		if c.group.starts_with(\"roc-lang/nightlies:#\") {"
)
ONLY=("$@")
RESULT=$STAMP/RESULT.md
{
echo "# 261d mutation check ($ROC_TAG, $(date -u +%Y-%m-%dT%H:%MZ))"
echo
echo "| Mutant | Result | Failing runs |"
echo "| --- | --- | --- |"
} > "$RESULT"
for m in "${MUTANTS[@]}"; do
	IFS='~' read -r -a parts <<< "$m"
	name=${parts[0]}
	if [ ${#ONLY[@]} -gt 0 ] && [[ ! " ${ONLY[*]} " =~ " $name " ]]; then continue; fi
	d=$STAMP/$name
	mkdir -p "$d/packages" "$d/cli" "$d/bot" "$d/tests/commands/cases"
	cp -r "$TALON/packages/records" "$TALON/packages/resolve" "$d/packages/"
	cp -r "$TALON/cli/lib" "$d/cli/"; cp -r "$TALON/bot/lib" "$d/bot/"; cp -r "$TALON/scripts" "$d/"
	cp -r "$TALON/tests/unit" "$TALON/tests/fixtures" "$TALON/tests/lib.sh" "$d/tests/"
	cp "$TALON"/tests/commands/*.roc "$TALON/tests/commands/run.sh" "$d/tests/commands/"
	cp -r "$TALON/tests/commands/cases/logproof" "$d/tests/commands/cases/"
	for c in "${OLD[@]}"; do mkdir -p "$d/tests/commands/cases/$(dirname "$c")"; cp -r "$TALON/tests/commands/cases/$c" "$d/tests/commands/cases/$c"; done
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
		l2=$(L2BIN=$d/l2 "${CAP[@]}" "$d/tests/commands/run.sh" logproof/ "${OLD[@]}" 2>&1)
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
