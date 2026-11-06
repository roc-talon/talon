import sys
def edit(path, old, new):
    s = open(path).read()
    if old not in s:
        sys.exit("mutation: text not found in %s: %s" % (path, old[:80]))
    open(path, "w").write(s.replace(old, new, 1))
