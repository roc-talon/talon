import sys
def edit(root, path, old, new, count=1):
    p = f"{root}/{path}"
    s = open(p).read()
    if old not in s:
        sys.exit(f"mutation: anchor not found in {path}: {old[:70]}")
    open(p, "w").write(s.replace(old, new) if count == 0 else s.replace(old, new, count))
