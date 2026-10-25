#!/usr/bin/env bash
# Count the top-level `expect` of the unit files, the rule-id comment lines, and two checksums:
# rule-ids-sorted-md5: all rule ids in the files, sorted. expect-body-lines-md5: all lines except the header, the imports, `main!`, the type line of a unit module and blank lines, sorted.
# Usage: count-expects.sh [dir ...] (paths from the repo root; default: tests/unit packages/*/tests)
export LC_ALL=C
cd "$(dirname "$0")/../.." || exit 1
dirs=("$@"); [ ${#dirs[@]} -eq 0 ] && dirs=(tests/unit packages/*/tests)
all() { cat $(find "${dirs[@]}" -name '*.roc' | sort); }
echo "expect $(all | grep -c '^expect')"
echo "rule-comments $(all | grep -cE '^# .*R-[A-Z]+[0-9]')"
echo "rule-ids-sorted-md5 $(all | grep -oE 'R-[A-Z]+[0-9]+[a-z]?' | sort | md5sum | cut -c1-12)"
echo "expect-body-lines-md5 $(all | grep -vE '^(app |import |main!|[A-Za-z]+Test :: \[\]\.\{\}$|$)' | sort | md5sum | cut -c1-12)"
