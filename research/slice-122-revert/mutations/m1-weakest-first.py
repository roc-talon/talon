# M1 order: the strength order is reversed (weakest first). Caught by: CodeTest, ReadsTest (W0), reads and closure and publish cases (W2).
import sys; sys.path.insert(0, __file__.rsplit("/", 1)[0]); from common import edit
B = sys.argv[1]
edit(B + "/packages/records/Code.roc", 'known = ["oidc", "webhook", "poll", "ingest"]', 'known = ["ingest", "poll", "webhook", "oidc"]')
