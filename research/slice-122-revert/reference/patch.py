#!/usr/bin/env python3
# Private reference of slice 122 (TW18: the code agent does not read this). Usage: patch.py <refbuild dir with worker/, packages/records/, sql/>
# It turns the stubs of the live tree into the working code, by text replacement, so it still applies when other slices change the same files.
import sys, re
B = sys.argv[1]
def edit(path, pairs):
    s = open(path).read()
    for old, new in pairs:
        if old not in s:
            sys.exit("patch.py: text not found in %s: %s" % (path, old[:70]))
        s = s.replace(old, new, 1)
    open(path, "w").write(s)

R = B + "/packages/records/"
edit(R + "Release.roc", [
    ("\t\twithdrawn: Nullable.write(r.withdrawn),\n\t\tprovenance: [],", "\t\twithdrawn: Nullable.write(r.withdrawn),\n\t\tprovenance: r.provenance,"),
    ("\t\twithdrawn: Nullable.read(w.withdrawn),\n\t\tprovenance: [],", "\t\twithdrawn: Nullable.read(w.withdrawn),\n\t\tprovenance: w.provenance,"),
])
edit(R + "Code.roc", [
    ("\tvia_name = |_code| crash \"todo\"", """\tvia_name = |code| match code {
		0 => Ok("oidc")
		1 => Ok("webhook")
		2 => Ok("poll")
		3 => Ok("ingest")
		_ => Err(NoSuchCode)
	}"""),
    ("\tvia_sort = |_vias| crash \"todo\"", """\tvia_sort = |vias| {
		known = ["oidc", "webhook", "poll", "ingest"]
		known.join_map(|k| vias.keep_if(|v| v == k)).concat(vias.keep_if(|v| !known.contains(v)).sort())
	}"""),
])
W = B + "/worker/"
edit(W + "lib/Reads.roc", [
    ("import records.Artifact\n", "import records.Artifact\nimport records.Code\n"),
    ("\tprovenance_of = |_vias| crash \"todo\"", """\tprovenance_of = |vias| match vias {
		Err(Missing) => Ok([])
		Ok(text) => {
			names = text.split_on(",").map_try(
				|item| match U8.from_str(item) {
					Ok(code) => Code.via_name(code).map_err(|_| BadRow("provenance: the via code ${item} is not known"))
					Err(_) => Err(BadRow("provenance: ${item} is not a via code"))
				},
			)
			names.map_ok(Code.via_sort)
		}
	}"""),
    ("\t\thash = base58_of_bytes(row.hash)?\n\t\tversion = Version.read({ version: row.version", "\t\thash = base58_of_bytes(row.hash)?\n\t\tprovenance = provenance_of(row.vias)?\n\t\tversion = Version.read({ version: row.version"),
    ("\t\t\tprovenance: [],\n\t\t})", "\t\t\tprovenance,\n\t\t})"),
])
VIAS = "(SELECT group_concat(via) FROM (SELECT via FROM provenance WHERE release = r.log_index ORDER BY via)) AS vias"
edit(W + "ReadRoutes.roc", [
    ("r.withdrawn AS withdrawn FROM page r", "r.withdrawn AS withdrawn, " + VIAS + " FROM page r"),
])
edit(W + "IngestRoutes.roc", [
    ("\t\twithdrawn : Try(Str, [Missing]),\n\t\thas_ingest : Bool,", "\t\twithdrawn : Try(Str, [Missing]),\n\t\tvias : Try(Str, [Missing]),\n\t\thas_ingest : Bool,"),
    ("r.withdrawn AS withdrawn, EXISTS (SELECT 1 FROM provenance p", "r.withdrawn AS withdrawn, " + VIAS + ", EXISTS (SELECT 1 FROM provenance p"),
    ("\t\t\t\t\t\tvias: Err(Missing),", "\t\t\t\t\t\tvias: r.vias,"),
])
# the closure SQL (the same text in worker/sql/closure/releases.sql)
edit(W + "sql/closure/releases.sql", [
    ("r.withdrawn AS withdrawn\n", "r.withdrawn AS withdrawn,\n    " + VIAS + "\n"),
])
# Slice 104h (another session) adds toolchains.size to the seeds before the migration exists in the live sql/: the private run adds the column, so the closure case can run.
init = B + "/sql/0001_init.sql"
t = open(init).read()
if "  size INTEGER" not in t.split("CREATE TABLE toolchains")[1].split(")")[0]:
    t = t.replace("  sha256 TEXT NOT NULL,\n  published_at INTEGER NOT NULL,\n  log_index INTEGER NOT NULL,\n  PRIMARY KEY (nightly, target)", "  sha256 TEXT NOT NULL,\n  size INTEGER NOT NULL DEFAULT 0,\n  published_at INTEGER NOT NULL,\n  log_index INTEGER NOT NULL,\n  PRIMARY KEY (nightly, target)", 1)
    open(init, "w").write(t)
