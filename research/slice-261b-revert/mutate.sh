#!/bin/bash
# Mutation check of the 261b code (Talon slice 261b, TW12, the manager's order 2026-11-24): the Tlog reader functions of packages/records/Tlog.roc
# and cli/lib/LogKey.roc, cli/lib/LogProof.roc. Each mutant changes one place in a mirror copy under talon/.tmp/261b-mut/<name>/ (the repo is not changed).
# A records mutant runs packages/records/tests/w0.roc with BOTH compilers (ROC_TAG and ROC_TAG_WORKER); a cli mutant runs tests/unit/l0-9.roc with ROC_TAG.
# A mutant is killed when a run has a failed test (roc prints no "All (n) tests passed"). Each roc run is capped (16G, no swap), flocked, and has a time limit.
# Usage (repo root): research/slice-261b-revert/mutate.sh [name ...]   (no name: all). Writes .tmp/261b-mut/RESULT.md.
set -u
TALON=$(cd "$(dirname "$0")/../.." && pwd)
. "$TALON/scripts/env.sh"
ROC_WORKER_BIN=$TALON/cloudflare-workers/.cache/nightlies/$ROC_TAG_WORKER/roc
WORK=$TALON/.tmp/261b-mut
export TMPDIR=$TALON/.tmp/tmp
mkdir -p "$TMPDIR" "$WORK"
# name ~ file (from the repo root) ~ old text ~ new text   (the old text must occur exactly once). "reference" changes nothing: every run must pass.
MUTANTS=(
"reference~packages/records/Tlog.roc~	open_note : Str -> Try(Tlog.Note, [BadNote])~	open_note : Str -> Try(Tlog.Note, [BadNote])"
"incl-root-first-byte~packages/records/Tlog.roc~				if root == checkpoint.root {~				if root.take_first(1) == checkpoint.root.take_first(1) {"
"incl-leaf-no-0x00~packages/records/Tlog.roc~			if hs.get(index % 256) != Ok(leaf_hash(entry_bytes)) {~			if hs.get(index % 256) != Ok(sha(entry_bytes)) {"
"chain-stops-early~packages/records/Tlog.roc~			if up_hashes.get(\$cur.index % 256) != Ok(root_of(hs)) {~			if up.width == 256 and up_hashes.get(\$cur.index % 256) != Ok(root_of(hs)) {"
"chain-mth-no-0x01~packages/records/Tlog.roc~			if up_hashes.get(\$cur.index % 256) != Ok(root_of(hs)) {~			if up_hashes.get(\$cur.index % 256) != Ok(sha(hs.join())) {"
"incl-missing-skipped~packages/records/Tlog.roc~		} else if !all_present(proof_tiles(index, size), tiles) {~		} else if !all_present(proof_tiles(index, size).take_first(0), tiles) {"
"cons-new-root-for-old~packages/records/Tlog.roc~			old_root = prefix_root(a, b, tiles).map_err(|_| NotConsistent)?~			old_root = prefix_root(b, b, tiles).map_err(|_| NotConsistent)?"
"cons-chains-skipped~packages/records/Tlog.roc~			_chains = edge_hashes(a).map_try(~			_chains = edge_hashes(a).take_first(0).map_try("
"entry-at-width-skipped~packages/records/Tlog.roc~				Ok(entries) if entries.len() == t.width => entries.get(index % 256).map_err(|_| BadBundle)~				Ok(entries) => entries.get(index % 256).map_err(|_| BadBundle)"
"note-name-only~cli/lib/LogProof.roc~		lines = note.signatures.keep_if(|s| s.name == key.name and s.key_id == key.key_id)~		lines = note.signatures.keep_if(|s| s.name == key.name)"
"note-any-line~cli/lib/LogProof.roc~		} else if !lines.all(|s| Ed25519.verify(~		} else if !lines.any(|s| Ed25519.verify("
"key-id-skipped~cli/lib/LogKey.roc~		if parts.key_id != Tlog.key_id(parts.name, public_key) {~		if parts.key_id.len() != 4 {"
"key-point-skipped~cli/lib/LogKey.roc~		} else if !Ed25519.is_valid_public_key(public_key) {~		} else if public_key.len() != 32 {"
"release-url-skipped~cli/lib/LogProof.roc~		} else if row.url != \"https://\${leaf.grp.replace_each(\"{v}\", leaf.version)}\${leaf.hash}.tar.zst\" {~		} else if row.url.is_empty() {"
)
ONLY=("$@")
RESULT=$WORK/RESULT.md
{
echo "# 261b mutation check ($ROC_TAG and $ROC_TAG_WORKER, $(date -u +%Y-%m-%dT%H:%MZ))"
echo
echo "| Mutant | File | Result | Failing runs |"
echo "| --- | --- | --- | --- |"
} > "$RESULT"
run() { # run <dir> <roc> <test file>: prints a failure note, or nothing when all tests pass
	local out rc
	out=$(cd "$1" && flock "$TALON/.tmp/heavy.lock" systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 300 "$2" test "$3" --no-cache 2>&1)
	rc=$?
	echo "$out" | grep -qE 'All \([0-9]+\) tests passed' || echo "$3 on $(basename "$(dirname "$2")") ($(echo "$out" | grep -oE '[0-9]+ failed' | head -1), exit $rc)"
}
for m in "${MUTANTS[@]}"; do
	IFS='~' read -r name file old new <<< "$m"
	if [ ${#ONLY[@]} -gt 0 ] && [[ ! " ${ONLY[*]} " =~ " $name " ]]; then continue; fi
	d=$WORK/$name
	rm -rf "$d"; mkdir -p "$d/packages" "$d/cli" "$d/bot" "$d/tests"
	cp -r "$TALON/packages/records" "$TALON/packages/resolve" "$d/packages/"
	cp -r "$TALON/cli/lib" "$d/cli/"; cp -r "$TALON/bot/lib" "$d/bot/"; cp -r "$TALON/tests/unit" "$d/tests/"
	n=$(OLD="$old" python3 -c 'import os,sys; print(open(sys.argv[1]).read().count(os.environ["OLD"]))' "$d/$file")
	if [ "$n" != 1 ]; then echo "| $name | $file | NOT APPLIED (old text found $n times) | |" >> "$RESULT"; echo "$name: NOT APPLIED"; continue; fi
	OLD="$old" NEW="$new" python3 -c 'import os,sys; p=sys.argv[1]; s=open(p).read(); open(p,"w").write(s.replace(os.environ["OLD"], os.environ["NEW"]))' "$d/$file"
	failing=()
	case $file in
	packages/records/*)
		for r in "$ROC" "$ROC_WORKER_BIN"; do f=$(run "$d" "$r" packages/records/tests/w0.roc); [ -n "$f" ] && failing+=("$f"); done ;;
	*)
		f=$(run "$d" "$ROC" tests/unit/l0-9.roc); [ -n "$f" ] && failing+=("$f") ;;
	esac
	if [ ${#failing[@]} -gt 0 ]; then r=killed; else r=SURVIVED; fi
	if [ "$name" = reference ]; then
		f=$(run "$d" "$ROC" tests/unit/l0-9.roc); [ -n "$f" ] && failing+=("$f")
		if [ ${#failing[@]} -eq 0 ]; then r="all pass (good)"; else r="FAILS: the check is not valid"; fi
	fi
	echo "| $name | $file | $r | ${failing[*]:-} |" >> "$RESULT"
	echo "$name: $r ${failing[*]:-}"
done
cat "$RESULT"
