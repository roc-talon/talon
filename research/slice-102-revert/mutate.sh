#!/usr/bin/env bash
# The revert check of slice 102: 14 hand mutations of reference/0001_init.sql. Each must make at least one W1 case fail.
#   research/slice-102-revert/mutate.sh
set -u
here="$(cd "$(dirname "$0")" && pwd)"
ref="$here/reference/0001_init.sql"
tmp="$(mktemp -d)"
run() { # name, python replace (old, new)
  local name="$1" old="$2" new="$3"
  python3 - "$ref" "$tmp/m.sql" "$old" "$new" <<'PY'
import sys
s = open(sys.argv[1]).read()
old, new = sys.argv[3], sys.argv[4]
if old not in s: sys.exit('mutation text not found: ' + old)
open(sys.argv[2], 'w').write(s.replace(old, new, 1))
PY
  [ $? -eq 0 ] || { echo "ERR  $name"; return; }
  out=$("$here/run-ref.sh" "$tmp/m.sql" schema 2>&1 | grep '^FAIL' | awk '{print $3}' | sort -u | tr '\n' ' ')
  if [ -n "$out" ]; then echo "CAUGHT  $name -> $out"; else echo "MISSED  $name"; fi
}
run "no STRICT on compat_hints"            "  PRIMARY KEY (artifact, nightly, target, talon_version)
) STRICT, WITHOUT ROWID;" "  PRIMARY KEY (artifact, nightly, target, talon_version)
) WITHOUT ROWID;"
run "no WITHOUT ROWID on transitions"       "  changed INTEGER NOT NULL,
  PRIMARY KEY (nightly, target)
) STRICT, WITHOUT ROWID;" "  changed INTEGER NOT NULL,
  PRIMARY KEY (nightly, target)
) STRICT;"
run "names without the typeof CHECK"        "  CHECK (typeof(value) = CASE kind WHEN 1 THEN 'blob' ELSE 'text' END),
" ""
run "names without UNIQUE (kind, value)"    "  value ANY NOT NULL,
  CHECK (typeof(value) = CASE kind WHEN 1 THEN 'blob' ELSE 'text' END),
  UNIQUE (kind, value)" "  value ANY NOT NULL,
  CHECK (typeof(value) = CASE kind WHEN 1 THEN 'blob' ELSE 'text' END)"
run "targets 21 and 22 swapped"             "(21, 'arm64mac'), (22, 'arm64win')" "(21, 'arm64win'), (22, 'arm64mac')"
run "toolchains keyed by nightly only"      "  PRIMARY KEY (nightly, target)
) STRICT, WITHOUT ROWID;

-- R-RE5" "  PRIMARY KEY (nightly)
) STRICT, WITHOUT ROWID;

-- R-RE5"
run "contributions crash code 2"            "CHECK (result IN (0, 1, 3))" "CHECK (result IN (0, 1, 2))"
run "releases label without version_text"   "UNIQUE (form, version, version_text)" "UNIQUE (form, version)"
run "log.time as TEXT"                      "  hash TEXT NOT NULL,
  time INTEGER NOT NULL
) STRICT;" "  hash TEXT NOT NULL,
  time TEXT NOT NULL
) STRICT;"
run "a foreign key on compat.artifact"      "  artifact INTEGER NOT NULL,
  nightly INTEGER NOT NULL,
  target INTEGER NOT NULL,
  source INTEGER NOT NULL CHECK (source IN (0, 1))," "  artifact INTEGER NOT NULL REFERENCES names (id),
  nightly INTEGER NOT NULL,
  target INTEGER NOT NULL,
  source INTEGER NOT NULL CHECK (source IN (0, 1)),"
run "no compat_nightly index"               "CREATE INDEX compat_nightly ON compat (nightly, target, source, artifact);" ""
run "withdrawn without the CHECK"          "  withdrawn TEXT CHECK (withdrawn IN ('deleted', 'unpublished', 'prereleased', 'edited', 'asset-replaced', 'repo-missing'))," "  withdrawn TEXT,"
run "artifacts.kind check app 2 (old code)" "CHECK (kind IN (0, 1, 2)),
  exposes" "CHECK (kind IN (1, 2, 3)),
  exposes"
run "repos.state without CHECK"             "state INTEGER NOT NULL CHECK (state IN (0, 1, 2))," "state INTEGER NOT NULL,"
rm -rf "$tmp"
