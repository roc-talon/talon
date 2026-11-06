# Reference only (slice 117, Q302): adds the column contributor_totals.last_time to the build copy of sql/0001_init.sql. The real file is edited by the code agent.
import sys
p = sys.argv[1]
s = open(p).read()
a = "  unconfirmed INTEGER NOT NULL,\n  first_time INTEGER NOT NULL\n) STRICT;"
if "last_time INTEGER NOT NULL\n) STRICT;\n\n-- R-IK7" in s:
    sys.exit(0)  # the column is there: the real file was edited
if a not in s:
    sys.exit('patch_sql: the table contributor_totals has another form')
open(p, 'w').write(s.replace(a, "  unconfirmed INTEGER NOT NULL,\n  first_time INTEGER NOT NULL,\n  last_time INTEGER NOT NULL\n) STRICT;", 1))
