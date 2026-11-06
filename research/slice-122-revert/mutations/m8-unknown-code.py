# M8 a code outside the list: every code above 3 is `ingest`. Caught by: CodeTest, ReadsTest (W0).
import sys; sys.path.insert(0, __file__.rsplit("/", 1)[0]); from common import edit
B = sys.argv[1]
edit(B + "/packages/records/Code.roc", '3 => Ok("ingest")\n\t\t_ => Err(NoSuchCode)\n\t}\n\n\t## R-AP49 `provenance`', '_ => Ok("ingest")\n\t}\n\n\t## R-AP49 `provenance`')
