# M7 a stale record: the answer of the path that adds a provenance row (R-PU14, R-PU16) is the release of the first read, before the write. Caught by: W2 ingest/pu14-pu19-labels (lines 1 and 2).
import sys; sys.path.insert(0, __file__.rsplit("/", 1)[0]); from common import edit
B = sys.argv[1]
edit(B + "/worker/IngestRoutes.roc", "dropping(answer!(session, 200, last_release(results)?), req, target, 200)\n\t\t\t}\n\t\t\tIndex", "dropping(answer!(session, 200, match rows { [r, ..] => Reads.release_of_row(r.release).map_err(bad_row)?\n\t\t\t\t[] => last_release(results)? }), req, target, 200)\n\t\t\t}\n\t\t\tIndex")
