"""Makes talon/compat.db for the case exit/ex3-no-tuple-yaml (slice 053). Usage: python3 -I mkdb.py <db file> <facts.tsv>

The schema is the one of cli/RealDb.roc (format 1). The rows are in given/facts.tsv: hash, nightly, target, outcome, modules, closure (tab separated).
They are the real results of conformance/compat-sweep (run 2026-10-13) for roc-parser 2.0.0, basic-cli 0.25.0 and basic-cli 0.24.0 on 22 nightlies.
"""
import sqlite3
import sys

c = sqlite3.connect(sys.argv[1])
c.execute("CREATE TABLE facts (hash TEXT NOT NULL, nightly TEXT NOT NULL, target TEXT NOT NULL, outcome TEXT NOT NULL, modules TEXT NOT NULL, closure TEXT NOT NULL, PRIMARY KEY (hash, nightly, target, closure)) WITHOUT ROWID")
for line in open(sys.argv[2]):
    c.execute("INSERT INTO facts VALUES (?, ?, ?, ?, ?, ?)", line.rstrip("\n").split("\t"))
c.execute("CREATE TABLE pinned (tag TEXT NOT NULL, target TEXT NOT NULL, sha256 TEXT NOT NULL, source TEXT NOT NULL, PRIMARY KEY (tag, target)) WITHOUT ROWID")
c.execute("PRAGMA user_version = 1")
c.commit()
