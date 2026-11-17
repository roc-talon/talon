# pyrep.py <file>: env PYE = "<old>@@@<new>" with \n and \t as escapes; replaces the first match; exit 1 when old is absent.
import os, sys
old, new = os.environ["PYE"].split("@@@")
fix = lambda t: t.replace("\\n", "\n").replace("\\t", "\t")
old, new = fix(old), fix(new)
p = sys.argv[1]
t = open(p).read()
if old not in t:
    sys.exit(1)
open(p, "w").write(t.replace(old, new, 1))
