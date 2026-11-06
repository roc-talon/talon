import sys
def mutate(worker, path, old, new):
    p = f"{worker}/{path}"; s = open(p).read()
    assert s.count(old) == 1, (path, old[:80]); open(p, 'w').write(s.replace(old, new))
