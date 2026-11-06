import sys, os
def edit(d, rel, old, new):
    p = os.path.join(d, rel)
    s = open(p).read()
    assert s.count(old) == 1, (rel, old, s.count(old))
    open(p, 'w').write(s.replace(old, new))
