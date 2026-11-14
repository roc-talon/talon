# Mutation m1 of slice 247 (revert check): worker/lib/Move.roc: the text below is replaced. Usage: m1.py <copy root>
import sys
root = sys.argv[1]
p = f'{root}/worker/lib/Move.roc'
s = open(p).read()
old = '\t\t\t\tif o.kind != candidate.kind {\n\t\t\t\t\treturn fail(Kind)\n\t\t\t\t}\n\t\t\t\tmissing = o.modules.fold([], |acc, m| if candidate.modules.contains(m) or acc.contains(m) acc else acc.append(m))\n\t\t\t\tif !missing.is_empty() {\n\t\t\t\t\treturn fail(Exposes(missing))\n\t\t\t\t}\n'
new = '\t\t\t\tmissing = o.modules.fold([], |acc, m| if candidate.modules.contains(m) or acc.contains(m) acc else acc.append(m))\n\t\t\t\tif !missing.is_empty() {\n\t\t\t\t\treturn fail(Exposes(missing))\n\t\t\t\t}\n\t\t\t\tif o.kind != candidate.kind {\n\t\t\t\t\treturn fail(Kind)\n\t\t\t\t}\n'
assert old in s, 'anchor not found: ' + old[:50]
open(p, 'w').write(s.replace(old, new, 1))
