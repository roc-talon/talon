#!/usr/bin/env python3
"""The rows of `talon/compat.db` as text (slice 030, TESTING.md 3.1 `expect/facts.tsv`). No third-party module.

Usage: python3 -I dumpdb.py <db file>
The lines are the form of `Db.file_text` (cli/lib/Db.roc): `format<TAB><user_version>`, then a `fact` line for each row of `facts` sorted by
(hash, nightly, target, closure), then a `pinned` line for each row of `pinned` sorted by (tag, target), then (slice 215) a `queue` line for each row of `share_queue` in the order of `seq`: the word `queue` and the 7 columns of R-TF7. Only the columns that Talon knows are printed
(R-TF2: a column that a later Talon added is ignored). A file that does not exist gives no output at all. A file that is not a database gives the
one line `error<TAB><text>`, so that a comparison shows it.
"""
import os
import sqlite3
import sys


def rows(con, sql):
    try:
        return con.execute(sql).fetchall()
    except sqlite3.OperationalError:
        return []  # no such table: a new file with no schema yet


def main(path):
    if not os.path.exists(path):
        return
    try:
        con = sqlite3.connect(path)
        print("format\t%d" % con.execute("PRAGMA user_version").fetchone()[0])
        for r in sorted(rows(con, "SELECT hash, nightly, target, outcome, modules, closure FROM facts"), key=lambda r: (r[0], r[1], r[2], r[5], r[3], r[4])):
            print("fact\t" + "\t".join(r))
        for r in sorted(rows(con, "SELECT tag, target, sha256, source FROM pinned")):
            print("pinned\t" + "\t".join(r))
        # Slice 215 (R-TF7): the rows of `share_queue` in the order of `seq`, as the word `queue` and the line of `Db.queue_line` (the 7 columns, `seq` first). No table: no line.
        for r in rows(con, "SELECT seq, hash, nightly, target, result, talon_version, queued_at FROM share_queue ORDER BY seq"):
            print("queue\t" + "\t".join(str(c) for c in r))
    except sqlite3.DatabaseError as e:
        print("error\t%s" % e)


main(sys.argv[1])
