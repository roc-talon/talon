# M2 order: the codes 1 and 2 are swapped (poll before webhook). Caught by: CodeTest, ReadsTest (W0), reads case ap1 and the closure case (W2).
import sys; sys.path.insert(0, __file__.rsplit("/", 1)[0]); from common import edit
B = sys.argv[1]
edit(B + "/packages/records/Code.roc", '1 => Ok("webhook")\n\t\t2 => Ok("poll")', '1 => Ok("poll")\n\t\t2 => Ok("webhook")')
