"""Print a help text of texts.py as a Roc list of line literals (for tests/unit/HelpTest.roc)."""
import sys, texts
k = sys.argv[1]
t = texts.GENERAL if k == "" else texts.command(k)
lines = t.split("\n")[:-1]
for l in lines:
    assert '"' not in l and "\\" not in l and "${" not in l
    print(f'\t\t"{l}",')
