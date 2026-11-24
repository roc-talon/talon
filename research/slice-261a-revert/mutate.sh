#!/bin/bash
# Mutation check of roc-ed25519 (Talon slice 261a, the user's order 2026-11-23). Each mutant changes one place of package/Sha512.roc or
# package/Ed25519.roc in a mirror copy under talon/.tmp/ed-mut/, then runs the 3 L0 test files with nightly 03dce41.
# A mutant is killed when at least one test file has a failed test (a warning alone does not count). A mutant has no constant condition, so roc gives no warning for it. Each roc run is capped (16G, no swap), flocked and has a time limit.
# The mutant non-point-a-valid is killed by tests/key.roc (slice 261a, the user's choice of a public decode check).
# Usage: .work/mutate.sh [name ...]   (no name: all). Writes .work/mutate-RESULT.md.
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
TALON=/home/george/dev/Karakatiza666/talon
ROC=${ROC:-$TALON/.tmp/roc-bump/nightlies/nightly-2026-11-13-03dce41/roc}
WORK=$TALON/.tmp/ed-mut
export TMPDIR=$TALON/.tmp/tmp
mkdir -p "$TMPDIR" "$WORK"
# name | file | old text | new text   (the old text must occur exactly once)
# "reference" changes nothing (after the stub fill below): all test files must pass, else the result of the mutants means nothing.
MUTANTS=(
"reference|Ed25519|import Sha512|import Sha512"
"no-s-below-l|Ed25519|		if !sc_below_l(s) {|		if !sc_below_l(s) and sig.len() == 0 {"
"no-length-check|Ed25519|		if pk.len() != 32 or sig.len() != 64 {|		if pk.len() == 1000 and sig.len() == 1000 {"
"non-point-a-valid|Ed25519|			Err(NotAPoint)|			Ok(x0)"
"k-not-reduced|Ed25519|				k = sc_reduce_512(Sha512.hash(r.concat(pk).concat(args.message)))|				k = sc_from_bytes(Sha512.hash(r.concat(pk).concat(args.message)), 0)"
"r-first-31-bytes|Ed25519|				encode_point(double_scalar_mul(s, k, point_neg(a))) == r|				encode_point(double_scalar_mul(s, k, point_neg(a))).take_first(31) == r.take_first(31)"
"plus-a-not-minus-a|Ed25519|				encode_point(double_scalar_mul(s, k, point_neg(a))) == r|				encode_point(double_scalar_mul(s, k, a)) == r"
"x-sign-ignored|Ed25519|			x = if (fe_is_odd(x1) != sign) fe_neg(x1) else x1|			x = x1"
"round-constant|Sha512|	0x6C44198C4A475817,|	0x6C44198C4A475818,"
"length-field-bytes|Sha512|	lo = n.shl_wrap(3)|	lo = n.shl_wrap(2)"
"rotation-41-to-40|Sha512|rotr(e, 41)|rotr(e, 40)"
)
ONLY=("$@")
RESULT=$HERE/.work/mutate-RESULT.md
{
echo "# roc-ed25519 mutation check ($("$ROC" version | head -1), $(date -u +%Y-%m-%dT%H:%MZ))"
echo
echo "| Mutant | File | Result | Failing test files |"
echo "| --- | --- | --- | --- |"
} > "$RESULT"
for m in "${MUTANTS[@]}"; do
	IFS='|' read -r name file old new <<< "$m"
	if [ ${#ONLY[@]} -gt 0 ] && [[ ! " ${ONLY[*]} " =~ " $name " ]]; then continue; fi
	d=$WORK/$name
	rm -rf "$d"; mkdir -p "$d"
	cp -r "$HERE/package" "$HERE/tests" "$d/"
	# The stub of Ed25519.is_valid_public_key (slice 261a, before its code) is filled in the mirror only with a reference body over the
	# decode of verify, so that tests/key.roc runs, and a mutant of decode_point reaches it.
	python3 - "$d/package/Ed25519.roc" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
stub = '\tis_valid_public_key = |_bytes| crash "todo"'
body = ('\tis_valid_public_key = |bytes| if (bytes.len() != 32) Bool.False else match decode_point(bytes) {\n'
        '\t\tOk(_) => Bool.True\n\t\tErr(_) => Bool.False\n\t}')
if stub in s: open(p, "w").write(s.replace(stub, body))
PY
	n=$(OLD="$old" python3 -c 'import os,sys; print(open(sys.argv[1]).read().count(os.environ["OLD"]))' "$d/package/$file.roc")
	if [ "$n" != 1 ]; then echo "| $name | $file | NOT APPLIED (old text found $n times) | |" >> "$RESULT"; continue; fi
	OLD="$old" NEW="$new" python3 -c 'import os,sys; p=sys.argv[1]; s=open(p).read(); open(p,"w").write(s.replace(os.environ["OLD"], os.environ["NEW"]))' "$d/package/$file.roc"
	failing=()
	for t in "$d"/tests/*.roc; do
		out=$(cd "$d" && XDG_CACHE_HOME=$d/xdg ROC_CACHE_DIR=$d/xdg/roc flock "$TALON/.tmp/heavy.lock" systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 300 "$ROC" test "tests/$(basename "$t")" --no-cache 2>&1)
		rc=$?
		# A file passes only when roc prints "All (n) tests passed". A warning alone (a nonzero exit) does not kill a mutant.
		if ! echo "$out" | grep -qE 'All \([0-9]+\) tests passed'; then failing+=("$(basename "$t") ($(echo "$out" | grep -oE '[0-9]+ failed' | head -1)${rc:+, exit $rc})"); fi
	done
	if [ ${#failing[@]} -gt 0 ]; then r=killed; else r=SURVIVED; fi
	if [ "$name" = reference ]; then if [ ${#failing[@]} -eq 0 ]; then r="all pass (good)"; else r="FAILS: the check is not valid"; fi; fi
	echo "| $name | $file | $r | ${failing[*]:-} |" >> "$RESULT"
	echo "$name: $r ${failing[*]:-}"
done
cat "$RESULT"
